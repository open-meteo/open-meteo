import Foundation
import Vapor
import SwiftPFor2D
import SwiftNetCDF


/**
NCEP GFS downloader
 */
struct GfsDownload: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
    }

    var help: String {
        "Download GFS from NOAA NCEP"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try GfsDomain.load(rawValue: signature.domain)
        disableIdleSleep()
        
        /// 18z run is available the day after starting 05:26
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        switch domain {
        case .gfs025_ensemble:
            try await downloadPrecipitationProbability(application: context.application, run: run, skipFilesIfExisting: signature.skipExisting)
            try convertGfs(logger: logger, domain: domain, variables: [GfsSurfaceVariable.precipitation_probability], run: run, createNetcdf: signature.createNetcdf)
        case .gfs013:
            fallthrough
        case .hrrr_conus:
            fallthrough
        //case .nam_conus:
        //    fallthrough
        case .gfs025:
            let onlyVariables: [GfsVariableDownloadable]? = try signature.onlyVariables.map {
                try $0.split(separator: ",").map {
                    if let variable = GfsPressureVariable(rawValue: String($0)) {
                        return variable
                    }
                    return try GfsSurfaceVariable.load(rawValue: String($0))
                }
            }
            
            let pressureVariables = domain.levels.reversed().flatMap { level in
                GfsPressureVariableType.allCases.map { variable in
                    GfsPressureVariable(variable: variable, level: level)
                }
            }
            let surfaceVariables = GfsSurfaceVariable.allCases
            
            let variables = onlyVariables ?? (signature.upperLevel ? pressureVariables : surfaceVariables)
            
            try await downloadGfs(application: context.application, domain: domain, run: run, variables: variables, skipFilesIfExisting: signature.skipExisting)
            try convertGfs(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        }
        
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    func downloadNcepElevation(application: Application, url: String, surfaceElevationFileOm: String, grid: Gridable, isGlobal: Bool) async throws {
        let logger = application.logger
        
        /// download seamask and height
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        
        logger.info("Downloading height and elevation data")
        
        enum ElevationVariable: String, CurlIndexedVariable, CaseIterable {
            case height
            case landmask
            
            var gribIndexName: String? {
                switch self {
                case .height:
                    return ":HGT:surface:"
                case .landmask:
                    return ":LAND:surface:"
                }
            }
        }
        
        var height: Array2D? = nil
        var landmask: Array2D? = nil
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
        for (variable, message) in try await curl.downloadIndexedGrib(url: url, variables: ElevationVariable.allCases) {
            try grib2d.load(message: message)
            if isGlobal {
                grib2d.array.shift180LongitudeAndFlipLatitude()
            }
            switch variable {
            case .height:
                height = grib2d.array
            case .landmask:
                landmask = grib2d.array
            }
            //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue).nc")
        }
        
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] == 1 ? height.data[i] : -999
        }
        try OmFileWriter(dim0: grid.ny, dim1: grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: height.data)
    }
    
    /// download GFS025 and NAM CONUS
    func downloadGfs(application: Application, domain: GfsDomain, run: Timestamp, variables: [GfsVariableDownloadable], skipFilesIfExisting: Bool) async throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let logger = application.logger
        let elevationUrl = domain.getGribUrl(run: run, forecastHour: 0)
        try await downloadNcepElevation(application: application, url: elevationUrl, surfaceElevationFileOm: domain.surfaceElevationFileOm, grid: domain.grid, isGlobal: domain.isGlobal)
        
        let deadLineHours = domain == .gfs025 ? 4 : 2
        let waitAfterLastModified: TimeInterval = domain == .gfs025 ? 180 : 120
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: waitAfterLastModified)
        let forecastHours = domain.forecastHours(run: run.hour)
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)

        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let variables: [GfsVariableAndDomain] = variables.map {
            GfsVariableAndDomain(variable: $0, domain: domain)
        }
        //let variables = variablesAll.filter({ !$0.variable.isLeastCommonlyUsedParameter })
        
        let variablesHour0 = variables.filter({!$0.variable.skipHour0(for: domain)})
        
        /// Keep data from previous timestep in memory to deaverage the next timestep
        var previousData = [String: (step: Int, data: [Float])]()
        
        /// Variables that are kept in memory
        /// For GFS013, keep ressure and temperature in memory to convert specific humidity to relative
        let keepVariableInMemory: [GfsSurfaceVariable] = domain == .gfs013 ? [.temperature_2m, .surface_pressure] : []
        /// Keep pressure level temperature in memory to convert pressure vertical velocity (Pa/s) to geometric velocity (m/s)
        let keepVariableInMemoryPressure: [GfsPressureVariableType] = domain == .hrrr_conus ? [.temperature] : []
        
        for forecastHour in forecastHours {
            logger.info("Downloading forecastHour \(forecastHour)")
            /// HRRR has overlapping downloads of multiple runs. Make sure not to overwrite files.
            let prefix = run.hour % 3 == 0 ? "" : "_run\(run.hour % 3)"
            let variables = (forecastHour == 0 ? variablesHour0 : variables).filter { variable in
                let fileDest = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(forecastHour)\(prefix).fpg"
                return !skipFilesIfExisting || !FileManager.default.fileExists(atPath: fileDest)
            }
            let url = domain.getGribUrl(run: run, forecastHour: forecastHour)
            
            for (variable, message) in try await curl.downloadIndexedGrib(url: url, variables: variables) {
                try grib2d.load(message: message)
                if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                }
                //try message.debugGrid(grid: domain.grid, flipLatidude: domain.isGlobal, shift180Longitude: domain.isGlobal)
                
                guard let shortName = message.get(attribute: "shortName"),
                      let stepRange = message.get(attribute: "stepRange"),
                        let stepType = message.get(attribute: "stepType") else {
                    fatalError("could not get step range or type")
                }
                
                // Deaverage data
                if stepType == "avg" {
                    let startStep = Int(stepRange.split(separator: "-")[0])!
                    let currentStep = Int(stepRange.split(separator: "-")[1])!
                    let previous = previousData[variable.variable.rawValue]
                    // Store data for averaging in next run
                    previousData[variable.variable.rawValue] = (currentStep, grib2d.array.data)
                    // For the overall first timestep or the first step of each repeating section, deaveraging is not required
                    if let previous, previous.step != startStep {
                        let deltaHours = Float(currentStep - startStep)
                        let deltaHoursPrevious = Float(previous.step - startStep)
                        for l in previous.data.indices {
                            grib2d.array.data[l] = (grib2d.array.data[l] * deltaHours - previous.data[l] * deltaHoursPrevious) / (deltaHours - deltaHoursPrevious)
                        }
                    }
                }
                
                if stepType == "acc" {
                    fatalError("stepType=acc not supported")
                }
                
                // Convert specific humidity to relative humidity
                if let variable = variable.variable as? GfsSurfaceVariable,
                    variable == .relativehumidity_2m,
                    shortName == "2sh"
                {
                    guard let temperature = previousData[GfsSurfaceVariable.temperature_2m.rawValue],
                            temperature.step == forecastHour else {
                        fatalError("Could not get temperature 2m to convert specific humidity")
                    }
                    guard let surfacePressure = previousData[GfsSurfaceVariable.surface_pressure.rawValue],
                            surfacePressure.step == forecastHour else {
                        fatalError("Could not get surface_pressure to convert specific humidity")
                    }
                    grib2d.array.data.multiplyAdd(multiply: 1000, add: 0) // kg/kg to g/kg
                    grib2d.array.data = Meteorology.specificToRelativeHumidity(specificHumidity: grib2d.array.data, temperature: temperature.data, pressure: surfacePressure.data)
                }
                
                // Convert pressure vertical velocity to geometric velocity in HRRR
                if let variable = variable.variable as? GfsPressureVariable,
                    variable.variable == .vertical_velocity,
                    shortName == "w"
                {
                    guard let temperature = previousData[GfsPressureVariable(variable: .temperature, level: variable.level).rawValue], temperature.step == forecastHour else {
                        fatalError("Could not get temperature 2m to convert pressure vertical velocity to geometric velocity")
                    }
                    grib2d.array.data = Meteorology.verticalVelocityPressureToGeometric(omega: grib2d.array.data, temperature: temperature.data, pressureLevel: Float(variable.level))
                }
                
                //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.variable.rawValue)_\(forecastHour).nc")
                let file = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(forecastHour)\(prefix).fpg"
                try FileManager.default.removeItemIfExists(at: file)
                
                // Scaling before compression with scalefactor
                if let fma = variable.variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                // Keep temperature and pressure in memory to relative humidity conversion
                if let variable = variable.variable as? GfsSurfaceVariable, keepVariableInMemory.contains(variable) {
                    previousData[variable.rawValue] = (forecastHour, grib2d.array.data)
                }
                if let variable = variable.variable as? GfsPressureVariable, keepVariableInMemoryPressure.contains(variable.variable) {
                    previousData[variable.rawValue] = (forecastHour, grib2d.array.data)
                }
                
                try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.variable.scalefactor, all: grib2d.array.data)
            }
        }
        curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convertGfs(logger: Logger, domain: GfsDomain, variables: [GfsVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let forecastHours = domain.forecastHours(run: run.hour)
        let nTime = forecastHours.max()! / domain.dtHours + 1
        
        let grid = domain.grid
        let nLocations = grid.count
        
        let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nTime
        
        var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        for variable in variables {            
            if GfsVariableAndDomain(variable: variable, domain: domain).gribIndexName == nil {
                continue
            }
            
            let skip = variable.skipHour0(for: domain) ? 1 : 0
            let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)")
            
            let readers: [(hour: Int, reader: OmFileReader<MmapFile>)] = try forecastHours.compactMap({ hour in
                if hour == 0 && variable.skipHour0(for: domain) {
                    return nil
                }
                /// HRRR has overlapping downloads of multiple runs. Make sure not to overwrite files.
                let prefix = run.hour % 3 == 0 ? "" : "_run\(run.hour % 3)"
                let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(hour)\(prefix).fpg"
                let reader = try OmFileReader(file: file)
                try reader.willNeed()
                return (hour, reader)
            })
            
            // Create netcdf file for debugging
            if createNetcdf {
                let ncFile = try NetCDF.create(path: "\(domain.downloadDirectory)\(variable.omFileName).nc", overwriteExisting: true)
                try ncFile.setAttribute("TITLE", "\(domain) \(variable)")
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "time", length: nTime),
                    try ncFile.createDimension(name: "LAT", length: grid.ny),
                    try ncFile.createDimension(name: "LON", length: grid.nx)
                ])
                for reader in readers {
                    let data = try reader.reader.readAll()
                    try ncVariable.write(data, offset: [reader.hour/domain.dtHours, 0, 0], count: [1, grid.ny, grid.nx])
                }
            }
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { d0offset in
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data2d.data.fillWithNaNs()
                for reader in readers {
                    try reader.reader.read(into: &readTemp, arrayDim1Range: 0..<locationRange.count, arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                    data2d[0..<data2d.nLocations, reader.hour / domain.dtHours] = readTemp
                }
                
                // interpolate missing timesteps. We always fill 2 timesteps at once
                // data looks like: DDDDDDDDDD--D--D--D--D--D
                let forecastStepsToInterpolate = (0..<nTime).compactMap { hour -> Int? in
                    let forecastHour = hour * domain.dtHours
                    if forecastHours.contains(forecastHour) || forecastHour % 3 != 1 {
                        // process 2 timesteps at once
                        return nil
                    }
                    return forecastHour
                }
                
                // Fill in missing hourly values after switching to 3h
                data2d.interpolate2Steps(type: variable.interpolationType, positions: forecastStepsToInterpolate, grid: domain.grid, locationRange: locationRange, run: run, dtSeconds: domain.dtSeconds)
                
                progress.add(locationRange.count)
                return data2d.data[0..<locationRange.count * nTime]
            }
            progress.finish()
        }
    }
    
    /// Download precipitation members from GFS ensemble and calculate probability
    func downloadPrecipitationProbability(application: Application, run: Timestamp, skipFilesIfExisting: Bool) async throws {
        let domain = GfsDomain.gfs025_ensemble
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let grid = domain.grid
        var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4, waitAfterLastModified: 90)
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        enum EnsembleVariable: CurlIndexedVariable, CaseIterable {
            var gribIndexName: String? {
                return "APCP:surface"
            }
            case precipitation
        }
        let members = 0...30
        let forecastHours = domain.forecastHours(run: run.hour)
        var previous = [Int: [Float]]()
        previous.reserveCapacity(members.count)
        let threshold = Float(0.3)
        
        for forecastHour in forecastHours {
            if forecastHour == 0 {
                continue
            }
            let file = "\(domain.downloadDirectory)precipitation_probability_\(forecastHour).fpg"
            if skipFilesIfExisting && FileManager.default.fileExists(atPath: file) {
                continue
            }
            /// Probability 0-100
            var greater01 = [Float](repeating: 0, count: grid.count)
            // Download all members, and increase precipitation probability
            for member in members {
                let memberString = member == 0 ? "gec00" : "gep\(member.zeroPadded(len: 2))"
                let url = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/gefs.\(run.format_YYYYMMdd)/\(run.hh)/atmos/pgrb2sp25/\(memberString).t\(run.hh)z.pgrb2s.0p25.f\(forecastHour.zeroPadded(len: 3))"
                let grib = try await curl.downloadIndexedGrib(url: url, variables: EnsembleVariable.allCases)[0]
                try grib2d.load(message: grib.message)
                grib2d.array.shift180LongitudeAndFlipLatitude()
                let startStep = Int(grib.message.get(attribute: "stepRange")!.split(separator: "-")[0])!
                
                // deaccumlate on the fly
                if startStep != forecastHour - 3, let previousData = previous[member] {
                    for i in 0..<grib2d.array.data.count {
                        if grib2d.array.data[i] - previousData[i] >= threshold {
                            greater01[i] += 100 / Float(members.count)
                        }
                    }
                } else {
                    for i in 0..<grib2d.array.data.count {
                        if grib2d.array.data[i] >= threshold {
                            greater01[i] += 100 / Float(members.count)
                        }
                    }
                }
                previous[member] = grib2d.array.data
            }
            //try Array2D(data: greater01, nx: grid.nx, ny: grid.ny).writeNetcdf(filename: "\(domain.downloadDirectory)precipitation_probability_\(forecastHour).nc")
            try FileManager.default.removeItemIfExists(at: file)
            try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: 1, all: greater01)
        }
        curl.printStatistics()
    }
}

/// Small helper structure to fuse domain and variable for more control in the gribindex selection
struct GfsVariableAndDomain: CurlIndexedVariable {
    let variable: GfsVariableDownloadable
    let domain: GfsDomain
    
    var gribIndexName: String? {
        return variable.gribIndexName(for: domain)
    }
}
