import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
Gem regional and global Downloader
 - Regional https://dd.weather.gc.ca/model_gem_regional/10km/grib2/
 - Global https://dd.weather.gc.ca/model_gem_global/15km/grib2/lat_lon/
 
 High perf server
 - Global https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_global/15km/grib2/lat_lon/00/
 - Regional https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_regional/10km/grib2/00/
 */
struct GemDownload: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?
        
        @Option(name: "past-days")
        var pastDays: Int?
        
        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "server", help: "Server base URL. Default 'https://hpfx.collab.science.gc.ca/YYYYMMDD/WXO-DD/'. Alternative 'https://dd.weather.gc.ca/'")
        var server: String?
    }
    
    var help: String {
        "Download Gem models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try GemDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        if signature.onlyVariables != nil && signature.upperLevel {
            fatalError("Parameter 'onlyVariables' and 'upperLevel' must not be used simultaneously")
        }
        
        let onlyVariables: [GemVariableDownloadable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                if let variable = GemPressureVariable(rawValue: String($0)) {
                    return variable
                }
                guard let variable = GemSurfaceVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let variablesSurface: [GemVariableDownloadable] = GemSurfaceVariable.allCases
        
        let variablesPressure: [GemVariableDownloadable] = domain.levels.flatMap {
            level in GemPressureVariableType.allCases.compactMap { variable in
                return GemPressureVariable(variable: variable, level: level)
            }
        }
        
        /// For GEM ensemble, only download pressure levels if `--upper-level` is set
        let variablesDefault = domain == .gem_global_ensemble ? (signature.upperLevel ? variablesPressure : variablesSurface) : (variablesSurface+variablesPressure)
        
        let variables = onlyVariables ?? variablesDefault
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        try await downloadElevation(application: context.application, domain: domain, run: run, server: signature.server)
        try await download(application: context.application, domain: domain, variables: variables, run: run, skipFilesIfExisting: signature.skipExisting, server: signature.server)
        try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    // download seamask and height
    func downloadElevation(application: Application, domain: GemDomain, run: Timestamp, server: String?) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        logger.info("Downloading height and elevation data")
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        var height: [Float]
        if domain == .gem_hrdps_continental {
            // HRDPS has no HGT_SFC_0 file
            // Download temperature, pressure and calculate it manually
            try grib2d.load(message: try await curl.downloadGrib(url: domain.getUrl(run: run, hour: 0, gribName: "TMP_AGL-2m", server: server), bzip2Decode: false)[0])
            grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
            let temperature_2m = grib2d.array.data
            try grib2d.load(message: try await curl.downloadGrib(url: domain.getUrl(run: run, hour: 0, gribName: "PRES_Sfc", server: server), bzip2Decode: false)[0])
            grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
            let surfacePressure = grib2d.array.data
            try grib2d.load(message: try await curl.downloadGrib(url: domain.getUrl(run: run, hour: 0, gribName: "PRMSL_MSL", server: server), bzip2Decode: false)[0])
            grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
            let sealevelPressure = grib2d.array.data
            height = zip(zip(surfacePressure, sealevelPressure), temperature_2m).map {
                let ((surfacePressure, sealevelPressure), temperature_2m) = $0
                return Meteorology.elevation(sealevelPressure: sealevelPressure, surfacePressure: surfacePressure, temperature_2m: temperature_2m)
            }
        } else {
            let terrainUrl = domain.getUrl(run: run, hour: 0, gribName: "HGT_SFC_0", server: server)
            let message = try await curl.downloadGrib(url: terrainUrl, bzip2Decode: false)[0]
            try grib2d.load(message: message)
            if domain == .gem_global_ensemble {
                // Only ensemble model is shifted by 180° and uses geopotential
                grib2d.array.shift180Longitudee()
                grib2d.array.data.multiplyAdd(multiply: 9.80665, add: 0)
            }
            height = grib2d.array.data
        }
        
        if domain != .gem_global_ensemble {
            let gribName = domain == .gem_hrdps_continental ? "LAND_Sfc" : "LAND_SFC_0"
            let landmaskUrl = domain.getUrl(run: run, hour: 0, gribName: gribName, server: server)
            var landmask: Array2D? = nil
            for message in try await curl.downloadGrib(url: landmaskUrl, bzip2Decode: false) {
                try grib2d.load(message: message)
                landmask = grib2d.array
                //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)landmask.nc")
            }
            if let landmask {
                for i in landmask.data.indices {
                    // landmask: 0=sea, 1=land
                    height[i] = landmask.data[i] >= 0.5 ? height[i] : -999
                }
            }
        }
        
        //try Array2D(data: height, nx: domain.grid.nx, ny: domain.grid.ny).writeNetcdf(filename: "\(domain.downloadDirectory)terrain.nc")
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: height)
    }
    
    /// Download data and store as compressed files for each timestep
    func download(application: Application, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, skipFilesIfExisting: Bool, server: String?) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: (domain == .gem_global_ensemble || domain == .gem_global) ? 11 : 5) // 12 hours and 6 hours interval so we let 1 hour for data conversion
        let downloadDirectory = domain.downloadDirectory
        let nMembers = domain.ensembleMembers
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        /// Keep data from previous timestep in memory to deaccumulate the next timestep
        var previousData = [String: (step: Int, data: [Float])]()
                
        let forecastHours = domain.getForecastHours(run: run)
        for hour in forecastHours {
            logger.info("Downloading hour \(hour)")
            let h3 = hour.zeroPadded(len: 3)
            
            /// Keep wind vectors in memory to calculate wind speed / direction for ensemble
            var inMemory = [VariableAndMemberAndControl<GemSurfaceVariable>: [Float]]()
            
            for variable in variables {
                guard let gribName = variable.gribName(domain: domain) else {
                    continue
                }
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                if !variable.includedFor(hour: hour, domain: domain) {
                    continue
                }
                let filenameDest = "\(downloadDirectory)\(variable.omFileName.file)_\(h3).om"
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: filenameDest) {
                    continue
                }
                
                let url = domain.getUrl(run: run, hour: hour, gribName: gribName, server: server)
                
                for message in try await curl.downloadGrib(url: url, bzip2Decode: false) {
                    let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                    let memberStr = member > 0 ? "_\(member)" : ""
                    let filenameDest = "\(downloadDirectory)\(variable.omFileName.file)_\(h3)\(memberStr).om"
                    //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: true)
                    //fatalError()
                    try grib2d.load(message: message)
                    if domain == .gem_global_ensemble {
                        // Only ensemble model is shifted by 180°
                        grib2d.array.shift180Longitudee()
                    }
                    
                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd(dtSeconds: domain.dtSeconds) {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    guard let stepRange = message.get(attribute: "stepRange") else {
                        fatalError("could not get step range")
                    }
                    if stepRange.contains("-") {
                        // data is accumulated since model start
                        let startStep = Int(stepRange.split(separator: "-")[0])!
                        let currentStep = Int(stepRange.split(separator: "-")[1])!
                        let previous = previousData["\(variable.rawValue)\(memberStr)"]
                        // Store data for the next run
                        previousData["\(variable.rawValue)\(memberStr)"] = (currentStep, grib2d.array.data)
                        if let previous, previous.step != startStep {
                            /// For 6 hourly, divide it by 2, so interpolation does not need to care about precip sums
                            let deltaHours = Float((currentStep - previous.step) / domain.dtHours)
                            for l in previous.data.indices {
                                grib2d.array.data[l] = (grib2d.array.data[l] - previous.data[l]) / deltaHours
                            }
                        }
                    }
                    // GEM ensemble does not have wind speed and direction directly, calculate from u/v components
                    if domain == .gem_global_ensemble, let variable = variable as? GemSurfaceVariable {
                        // keep wind speed in memory, which actually contains wind U-component
                        if [.windspeed_10m, .windspeed_40m, .windspeed_80m, .windspeed_120m].contains(variable) {
                            inMemory[.init(variable, member)] = grib2d.array.data
                            continue
                        }
                        if let windspeedVariable = variable.winddirectionCounterPartVariable {
                            guard let u = inMemory[.init(windspeedVariable, member)] else {
                                fatalError("Wind speed calculation requires \(windspeedVariable) to download")
                            }
                            let windspeed = zip(u, grib2d.array.data).map(Meteorology.windspeed)
                            try writer.write(file: "\(downloadDirectory)\(windspeedVariable.omFileName.file)_\(h3)\(memberStr).om", compressionType: .p4nzdec256, scalefactor: windspeedVariable.scalefactor, all: windspeed, overwrite: true)
                            grib2d.array.data = Meteorology.windirectionFast(u: u, v: grib2d.array.data)
                        }
                    }
                    
                    //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName.file)_\(h3)\(memberStr).nc")
                    try writer.write(file: filenameDest, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data, overwrite: true)
                }
            }
        }
        curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let downloadDirectory = domain.downloadDirectory
        let grid = domain.grid
        let nMembers = domain.ensembleMembers
        
        let forecastHours = domain.getForecastHours(run: run)
        let nTime = forecastHours.max()! / domain.dtHours + 1
        let time = TimerangeDt(start: run, nTime: nTime, dtSeconds: domain.dtSeconds)
        let nLocations = grid.nx * grid.ny
        
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: nLocations * nMembers, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil, chunknLocations: nMembers > 1 ? nMembers : nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        
        var data3d = Array3DFastTime(nLocations: nLocationsPerChunk, nLevel: nMembers, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)

        for variable in variables {
            guard variable.gribName(domain: domain) != nil else {
                continue
            }
            let skip = variable.skipHour0 ? 1 : 0

            let progress = ProgressTracker(logger: logger, total: nLocations * nMembers, label: "Convert \(variable.rawValue)")
            let readers: [(hour: Int, reader: [OmFileReader<MmapFile>])] = try forecastHours.compactMap({ hour in
                if hour == 0 && variable.skipHour0 {
                    return nil
                }
                if !variable.includedFor(hour: hour, domain: domain) {
                    return nil
                }
                let h3 = hour.zeroPadded(len: 3)
                let readers = try (0..<nMembers).map { member in
                    let memberStr = member > 0 ? "_\(member)" : ""
                    return try OmFileReader(file: "\(downloadDirectory)\(variable.omFileName.file)_\(h3)\(memberStr).om")
                }
                return (hour, readers)
            })
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, indexTime: time.toIndexTime(), skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { offset in
                let d0offset = offset / nMembers
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data3d.data.fillWithNaNs()
                for reader in readers {
                    for (i, memberReader) in reader.reader.enumerated() {
                        try memberReader.read(into: &readTemp, arrayDim1Range: 0..<locationRange.count, arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                        data3d[0..<locationRange.count, i, reader.hour / domain.dtHours] = readTemp
                    }
                }
                
                if domain.dtHours == 3 {
                    /// interpolate 6 to 3 hours for ensemble 0.5°
                    data3d.interpolateInplace(
                        type: variable.interpolation,
                        skipFirst: skip,
                        time: time,
                        grid: domain.grid,
                        locationRange: locationRange
                    )
                }
                
                progress.add(locationRange.count * nMembers)
                return data3d.data[0..<locationRange.count * nMembers * nTime]
            }
            progress.finish()
        }
    }
}


