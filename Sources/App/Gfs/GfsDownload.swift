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

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Flag(name: "second-flush", help: "For GFS05 ensemble to download hours 390-840")
        var secondFlush: Bool
        
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
        
        if signature.onlyVariables != nil && signature.upperLevel {
            fatalError("Parameter 'onlyVariables' and 'upperLevel' must not be used simultaneously")
        }
        
        /// 18z run is available the day after starting 05:26
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        switch domain {
        case .gfs025_ensemble:
            try await downloadPrecipitationProbability(application: context.application, run: run, skipFilesIfExisting: signature.skipExisting)
            try convertGfs(logger: logger, domain: domain, variables: [GfsSurfaceVariable.precipitation_probability], run: run, createNetcdf: signature.createNetcdf, secondFlush: signature.secondFlush)
        case .gfs05_ens:
            fallthrough
        case .gfs025_ens:
            fallthrough
        case .gfs013:
            fallthrough
        case .hrrr_conus_15min:
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
            
            try await downloadGfs(application: context.application, domain: domain, run: run, variables: variables, skipFilesIfExisting: signature.skipExisting, secondFlush: signature.secondFlush)
            try convertGfs(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf, secondFlush: signature.secondFlush)
        }
        
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    func downloadNcepElevation(application: Application, url: [String], surfaceElevationFileOm: String, grid: Gridable, isGlobal: Bool) async throws {
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
        }
        
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] == 1 ? height.data[i] : -999
        }
        
        //try height.writeNetcdf(filename: surfaceElevationFileOm.replacingOccurrences(of: ".om", with: ".nc"))
        
        try OmFileWriter(dim0: grid.ny, dim1: grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: height.data)
    }
    
    /// download GFS025 and NAM CONUS
    func downloadGfs(application: Application, domain: GfsDomain, run: Timestamp, variables: [GfsVariableDownloadable], skipFilesIfExisting: Bool, secondFlush: Bool) async throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let logger = application.logger
        
        // GFS025 ensemble does not have elevation information, use non-ensemble version
        let elevationUrl = (domain == .gfs025_ens ? GfsDomain.gfs025 : domain).getGribUrl(run: run, forecastHour: 0, member: 0)
        if domain != .hrrr_conus_15min {
            // 15min hrrr data uses hrrr domain elevation files
            try await downloadNcepElevation(application: application, url: elevationUrl, surfaceElevationFileOm: domain.surfaceElevationFileOm, grid: domain.grid, isGlobal: domain.isGlobal)
        }
        
        let deadLineHours: Double
        switch domain {
        case .gfs013:
            deadLineHours = 5 // 6 hours interval so we let 1 hour for data conversion
        case .gfs025:
            deadLineHours = 5
        case .hrrr_conus_15min:
            deadLineHours = 2
        case .hrrr_conus:
            deadLineHours = 2
        case .gfs025_ensemble:
            deadLineHours = 5
        case .gfs025_ens:
            deadLineHours = 5
        case .gfs05_ens:
            deadLineHours = secondFlush ? 10 : 5
        }
        let waitAfterLastModified: TimeInterval = domain == .gfs025 ? 180 : 120
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: waitAfterLastModified)
        let forecastHours = domain.forecastHours(run: run.hour, secondFlush: secondFlush)
        
        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)

        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        // Download HRRR 15 minutes data
        if domain == .hrrr_conus_15min {
            for forecastHour in 0...18 {
                logger.info("Downloading forecastHour \(forecastHour)")
                let prefix = run.hour % 3 == 0 ? "" : "_run\(run.hour % 3)"
                
                let variables: [GfsVariableAndDomain] = (variables.flatMap({ v in
                    return forecastHour == 0 ? [GfsVariableAndDomain(variable: v, domain: domain, timestep: 0)] : (0..<4).map {
                        GfsVariableAndDomain(variable: v, domain: domain, timestep: (forecastHour-1) * 60 + ($0+1) * 15)
                    }
                })).filter { variable in
                    guard let timestep = variable.timestep else {
                        return false
                    }
                    let fileDest = "\(domain.downloadDirectory)\(variable.variable.omFileName.file)_\(timestep/15)\(prefix).fpg"
                    return !skipFilesIfExisting || !FileManager.default.fileExists(atPath: fileDest)
                }
                
                let url = domain.getGribUrl(run: run, forecastHour: forecastHour, member: 0)
                for (variable, message) in try await curl.downloadIndexedGrib(url: url, variables: variables) {
                    try grib2d.load(message: message)
                    guard let timestep = variable.timestep else {
                        return
                    }
                    if let fma = variable.variable.multiplyAdd(domain: domain) {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    let file = "\(domain.downloadDirectory)\(variable.variable.omFileName.file)_\(timestep/15)\(prefix).fpg"
                    try FileManager.default.removeItemIfExists(at: file)
                    try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.variable.scalefactor, all: grib2d.array.data)
                }
            }
            curl.printStatistics()
            return
        }
        
        let variables: [GfsVariableAndDomain] = variables.map {
            GfsVariableAndDomain(variable: $0, domain: domain, timestep: nil)
        }
        //let variables = variablesAll.filter({ !$0.variable.isLeastCommonlyUsedParameter })
        
        let variablesHour0 = variables.filter({!$0.variable.skipHour0(for: domain)})
        
        /// Keep data from previous timestep in memory to deaverage the next timestep
        var previousData = [String: (step: Int, data: [Float])]()
        
        /// Variables that are kept in memory
        /// For GFS013, keep pressure and temperature in memory to convert specific humidity to relative
        let keepVariableInMemory: [GfsSurfaceVariable] = domain == .gfs013 ? [.temperature_2m, .pressure_msl] : []
        /// Keep pressure level temperature in memory to convert pressure vertical velocity (Pa/s) to geometric velocity (m/s)
        let keepVariableInMemoryPressure: [GfsPressureVariableType] = (domain == .hrrr_conus || domain == .gfs05_ens) ? [.temperature] : []
        
        for forecastHour in forecastHours {
            logger.info("Downloading forecastHour \(forecastHour)")
            /// HRRR has overlapping downloads of multiple runs. Make sure not to overwrite files.
            let prefix = run.hour % 3 == 0 ? "" : "_run\(run.hour % 3)"
            
            for member in 0..<nMembers {
                let memberStr = member > 0 ? "_\(member)" : ""
                let variables = (forecastHour == 0 ? variablesHour0 : variables).filter { variable in
                    let fileDest = "\(domain.downloadDirectory)\(variable.variable.omFileName.file)_\(forecastHour)\(memberStr)\(prefix).fpg"
                    return !skipFilesIfExisting || !FileManager.default.fileExists(atPath: fileDest)
                }
                let url = domain.getGribUrl(run: run, forecastHour: forecastHour, member: member)
                               
                /// Keep data from previous timestep in memory to deaverage the next timestep
                var inMemorySurface = [GfsSurfaceVariable: [Float]]()
                var inMemoryPressure = [GfsPressureVariable: [Float]]()
                
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
                        let previous = previousData["\(variable.variable.rawValue)\(memberStr)"]
                        // Store data for averaging in next run
                        previousData["\(variable.variable.rawValue)\(memberStr)"] = (currentStep, grib2d.array.data)
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
                        guard let temperature = inMemorySurface[.temperature_2m] else {
                            fatalError("Could not get temperature 2m to convert specific humidity")
                        }
                        // gfs013 loads surface pressure instead of msl, however we do not use it, because it is not corrected
                        guard let surfacePressure = inMemorySurface[.pressure_msl] else {
                            fatalError("Could not get surface_pressure to convert specific humidity")
                        }
                        grib2d.array.data.multiplyAdd(multiply: 1000, add: 0) // kg/kg to g/kg
                        grib2d.array.data = Meteorology.specificToRelativeHumidity(specificHumidity: grib2d.array.data, temperature: temperature, pressure: surfacePressure)
                    }
                    
                    // Convert pressure vertical velocity to geometric velocity in HRRR
                    if let variable = variable.variable as? GfsPressureVariable,
                       variable.variable == .vertical_velocity,
                       shortName == "w"
                    {
                        guard let temperature = inMemoryPressure[.init(variable: .temperature, level: variable.level)] else {
                            fatalError("Could not get temperature 2m to convert pressure vertical velocity to geometric velocity")
                        }
                        grib2d.array.data = Meteorology.verticalVelocityPressureToGeometric(omega: grib2d.array.data, temperature: temperature, pressureLevel: Float(variable.level))
                    }
                    
                    //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.variable.rawValue)_\(forecastHour).nc")
                    let file = "\(domain.downloadDirectory)\(variable.variable.omFileName.file)_\(forecastHour)\(memberStr)\(prefix).fpg"
                    try FileManager.default.removeItemIfExists(at: file)
                    
                    // Scaling before compression with scalefactor
                    if let fma = variable.variable.multiplyAdd(domain: domain) {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    // Keep temperature and pressure in memory to relative humidity conversion
                    if let variable = variable.variable as? GfsSurfaceVariable,
                        keepVariableInMemory.contains(variable) {
                        inMemorySurface[variable] = grib2d.array.data
                    }
                    if let variable = variable.variable as? GfsPressureVariable,
                        keepVariableInMemoryPressure.contains(variable.variable) {
                        inMemoryPressure[variable] = grib2d.array.data
                    }
                    
                    if domain == .gfs013 && variable.variable as? GfsSurfaceVariable == .pressure_msl {
                        // do not write pressure to disk
                        continue
                    }
                    
                    try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.variable.scalefactor, all: grib2d.array.data)
                }
            }
        }
        curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convertGfs(logger: Logger, domain: GfsDomain, variables: [GfsVariableDownloadable], run: Timestamp, createNetcdf: Bool, secondFlush: Bool) throws {
        let nMembers = domain.ensembleMembers
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count * nMembers, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil, chunknLocations: nMembers > 1 ? nMembers : nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let forecastHours = domain.forecastHours(run: run.hour, secondFlush: secondFlush)
        let nTime = forecastHours.max()! / max(domain.dtHours, 1) + 1
        let time = TimerangeDt(start: run, nTime: nTime, dtSeconds: domain.dtSeconds)
        
        let grid = domain.grid
        let nLocations = grid.count
                
        var data3d = Array3DFastTime(nLocations: nLocationsPerChunk, nLevel: nMembers, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        for variable in variables {            
            if GfsVariableAndDomain(variable: variable, domain: domain, timestep: 0).gribIndexName == nil {
                continue
            }
            if domain == .gfs013 && variable as? GfsSurfaceVariable == .pressure_msl {
                // do not write pressure to disk
                continue
            }
            
            let skip = variable.skipHour0(for: domain) ? 1 : 0
            let progress = ProgressTracker(logger: logger, total: nLocations * nMembers, label: "Convert \(variable.rawValue)")
            
            let readers: [(hour: Int, reader: [OmFileReader<MmapFile>])] = try forecastHours.compactMap({ hour in
                if hour == 0 && variable.skipHour0(for: domain) {
                    return nil
                }
                /// HRRR has overlapping downloads of multiple runs. Make sure not to overwrite files.
                let prefix = run.hour % 3 == 0 ? "" : "_run\(run.hour % 3)"
                let readers = try (0..<nMembers).map { member in
                    let memberStr = member > 0 ? "_\(member)" : ""
                    let file = "\(domain.downloadDirectory)\(variable.omFileName.file)_\(hour)\(memberStr)\(prefix).fpg"
                    return try OmFileReader(file: file)
                }
                //try reader.willNeed()
                return (hour, readers)
            })
            
            // Create netcdf file for debugging
            if createNetcdf {
                let ncFile = try NetCDF.create(path: "\(domain.downloadDirectory)\(variable.omFileName.file).nc", overwriteExisting: true)
                try ncFile.setAttribute("TITLE", "\(domain) \(variable)")
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "time", length: nTime),
                    try ncFile.createDimension(name: "LAT", length: grid.ny),
                    try ncFile.createDimension(name: "LON", length: grid.nx)
                ])
                for reader in readers {
                    let data = try reader.reader[0].readAll()
                    try ncVariable.write(data, offset: [reader.hour/max(domain.dtHours,1), 0, 0], count: [1, grid.ny, grid.nx])
                }
            }
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, indexTime: time.toIndexTime(), skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { offset in
                let d0offset = offset / nMembers
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data3d.data.fillWithNaNs()
                for reader in readers {
                    for (i, memberReader) in reader.reader.enumerated() {
                        try memberReader.read(into: &readTemp, arrayDim1Range: (0..<locationRange.count), arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                        data3d[0..<locationRange.count, i, reader.hour / max(domain.dtHours,1)] = readTemp
                    }
                }
                
                // HRRR contains instantanous values for solar flux. Convert it to backwards averaged.
                // HRRR_15min data has backwards averaged radiation, but diffuse radiation is still instantanous
                if let variable = variable as? GfsSurfaceVariable {
                    if  (domain == .hrrr_conus && [.shortwave_radiation, .diffuse_radiation].contains(variable) ||
                        (domain == .hrrr_conus_15min && variable == .diffuse_radiation)
                    ) {
                        let factor = Zensun.backwardsAveragedToInstantFactor(grid: domain.grid, locationRange: locationRange, timerange: time)
                        for i in data3d.data.indices {
                            if factor.data[i] < 0.05 {
                                continue
                            }
                            data3d.data[i] /= factor.data[i]
                        }
                    }
                }
                
                // Interpolate all missing values
                data3d.interpolateInplace(
                    type: variable.interpolation,
                    skipFirst: skip,
                    time: time,
                    grid: domain.grid,
                    locationRange: locationRange
                )
                
                progress.add(locationRange.count * nMembers)
                return data3d.data[0..<locationRange.count * nMembers * nTime]
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
        let forecastHours = domain.forecastHours(run: run.hour, secondFlush: false)
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
                let url = domain.getGribUrl(run: run, forecastHour: forecastHour, member: member)
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
    let timestep: Int?
    
    var gribIndexName: String? {
        return variable.gribIndexName(for: domain, timestep: timestep)
    }
}
