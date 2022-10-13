import Foundation
import Vapor
import SwiftPFor2D


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
        guard let domain = GfsDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        switch domain {
        case .hrrr_conus:
            fallthrough
        //case .nam_conus:
        //    fallthrough
        case .gfs025:
            let run = signature.run.map {
                guard let run = Int($0) else {
                    fatalError("Invalid run '\($0)'")
                }
                return run
            } ?? domain.lastRun
            
            let onlyVariables: [GfsVariableDownloadable]? = signature.onlyVariables.map {
                $0.split(separator: ",").map {
                    if let variable = GfsPressureVariable(rawValue: String($0)) {
                        return variable
                    }
                    guard let variable = GfsSurfaceVariable(rawValue: String($0)) else {
                        fatalError("Invalid variable '\($0)'")
                    }
                    return variable
                }
            }
            
            let pressureVariables = domain.levels.reversed().flatMap { level in
                GfsPressureVariableType.allCases.map { variable in
                    GfsPressureVariable(variable: variable, level: level)
                }
            }
            let surfaceVariables = GfsSurfaceVariable.allCases
            
            let variables = onlyVariables ?? (signature.upperLevel ? pressureVariables : surfaceVariables)
            
            /// 18z run is available the day after starting 05:26
            let date = Timestamp.now().with(hour: run)
            
            try await downloadGfs(application: context.application, domain: domain, run: date, variables: variables, skipFilesIfExisting: signature.skipExisting)
            try convertGfs(logger: logger, domain: domain, variables: variables, run: date, createNetcdf: signature.createNetcdf)
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
        let curl = Curl(logger: logger)
        for (variable, message) in try await curl.downloadIndexedGrib(url: url, variables: ElevationVariable.allCases, client: application.http.client.shared) {
            var data = message.toArray2d()
            if isGlobal {
                data.shift180LongitudeAndFlipLatitude()
            }
            data.ensureDimensions(of: grid)
            switch variable {
            case .height:
                height = data
            case .landmask:
                landmask = data
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
        try OmFileWriter.write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: grid.ny, dim1: grid.nx, chunk0: 20, chunk1: 20, all: height.data)
    }
    
    /// download GFS025 and NAM CONUS
    func downloadGfs(application: Application, domain: GfsDomain, run: Timestamp, variables: [GfsVariableDownloadable], skipFilesIfExisting: Bool) async throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let logger = application.logger
        let elevationUrl = domain.getGribUrl(run: run, forecastHour: 0)
        try await downloadNcepElevation(application: application, url: elevationUrl, surfaceElevationFileOm: domain.surfaceElevationFileOm, grid: domain.grid, isGlobal: domain.isGlobal)
        
        let deadLineHours = domain == .gfs025 ? 4 : 2
        let curl = Curl(logger: logger, deadLineHours: deadLineHours)
        let forecastHours = domain.forecastHours(run: run.hour)
        
        let variables: [GfsVariableAndDomain] = variables.map {
            GfsVariableAndDomain(variable: $0, domain: domain)
        }
        //let variables = variablesAll.filter({ !$0.variable.isLeastCommonlyUsedParameter })
        
        let variablesHour0 = variables.filter({!$0.variable.skipHour0})
        
        for forecastHour in forecastHours {
            logger.info("Downloading forecastHour \(forecastHour)")
            /// HRRR has overlapping downloads of multiple runs. Make sure not to overwrite files.
            let prefix = run.hour % 3 == 0 ? "" : "_run\(run.hour % 3)"
            let variables = (forecastHour == 0 ? variablesHour0 : variables).filter { variable in
                let fileDest = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(forecastHour)\(prefix).fpg"
                return !skipFilesIfExisting || !FileManager.default.fileExists(atPath: fileDest)
            }
            let url = domain.getGribUrl(run: run, forecastHour: forecastHour)
            // NOTE: 2022-09-07: Async grib downloads are leaking in release build on linux.
            // couldn't figure it out after 2 days, so lets stick to sync code.
            // Either returned data is not released or something in eccodes
            for (variable, message) in try await curl.downloadIndexedGrib(url: url, variables: variables, client: application.http.client.shared) {
                var data = message.toArray2d()
                /*for (i,(latitude, longitude,value)) in try message.iterateCoordinatesAndValues().enumerated() {
                    if i % 10_000 == 0 {
                        print("grid \(i) lat \(latitude) lon \(longitude)")
                    }
                }
                fatalError("OK")*/
                if domain.isGlobal {
                    data.shift180LongitudeAndFlipLatitude()
                }
                data.ensureDimensions(of: domain.grid)
                //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName)_\(forecastHour).nc")
                let file = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(forecastHour)\(prefix).fpg"
                try FileManager.default.removeItemIfExists(at: file)
                
                // Scaling before compression with scalefactor
                if let fma = variable.variable.multiplyAdd {
                    data.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                curl.logger.info("Compressing and writing data to \(variable.variable.omFileName)_\(forecastHour)\(prefix).fpg")
                let compression = variable.variable.isAveragedOverForecastTime || variable.variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                try OmFileWriter.write(file: file, compressionType: compression, scalefactor: variable.variable.scalefactor, dim0: 1, dim1: data.count, chunk0: 1, chunk1: 8*1024, all: data.data)
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convertGfs(logger: Logger, domain: GfsDomain, variables: [GfsVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let forecastHours = domain.forecastHours(run: run.hour)
        let nForecastHours = forecastHours.max()!+1
        
        let grid = domain.grid
        let nLocation = grid.count
        
        
        for variable in variables {
            let startConvert = DispatchTime.now()
            
            if GfsVariableAndDomain(variable: variable, domain: domain).gribIndexName == nil {
                continue
            }
            
            logger.info("Converting \(variable)")
            
            var data2d = Array2DFastTime(nLocations: nLocation, nTime: nForecastHours)

            for forecastHour in forecastHours {
                if forecastHour == 0 && variable.skipHour0 {
                    continue
                }
                /// HRRR has overlapping downloads of multiple runs. Make sure not to overwrite files.
                let prefix = run.hour % 3 == 0 ? "" : "_run\(run.hour % 3)"
                let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(forecastHour)\(prefix).fpg"
                data2d[0..<nLocation, forecastHour] = try OmFileReader(file: file).readAll()
            }
            
            let skip = variable.skipHour0 ? 1 : 0
            
            // Deaverage radiation. Not really correct for 3h data after 120 hours, but solar interpolation will correct it afterwards
            if variable.isAveragedOverForecastTime {
                switch domain {
                case .gfs025:
                    data2d.deavergeOverTime(slidingWidth: 6, slidingOffset: skip)
                //case .nam_conus:
                //    data2d.deavergeOverTime(slidingWidth: 3, slidingOffset: skip)
                case .hrrr_conus:
                    break
                }
            }
            
            // interpolate missing timesteps. We always fill 2 timesteps at once
            // data looks like: DDDDDDDDDD--D--D--D--D--D
            let forecastStepsToInterpolate = (0..<nForecastHours).compactMap { hour -> Int? in
                if forecastHours.contains(hour) || hour % 3 != 1 {
                    // process 2 timesteps at once
                    return nil
                }
                return hour
            }
            
            // Fill in missing hourly values after switching to 3h
            data2d.interpolate2Steps(type: variable.interpolationType, positions: forecastStepsToInterpolate, grid: domain.grid, run: run, dtSeconds: domain.dtSeconds)
            
            // De-accumulate precipitation
            if variable.isAccumulatedSinceModelStart {
                //data2d.deaccumulateOverTime(slidingWidth: domain == .nam_conus ? 3 : data2d.nTime, slidingOffset: skip)
                data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: skip)
            }
            
            let ringtime = run.timeIntervalSince1970 / 3600 ..< run.timeIntervalSince1970 / 3600 + nForecastHours
            
            if createNetcdf {
                try data2d.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName).nc", nx: grid.nx, ny: grid.ny)
            }
            
            logger.info("Reading and interpolation done in \(startConvert.timeElapsedPretty()). Starting om file update")
            let startOm = DispatchTime.now()
            try om.updateFromTimeOriented(variable: variable.omFileName, array2d: data2d, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
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
