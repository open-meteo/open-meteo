import Foundation
import Vapor
import SwiftPFor2D


/**
Meteofrance Arome, Arpge downloader
 */
struct MeteoFranceDownload: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Option(name: "past-days")
        var pastDays: Int?

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
        "Download MeteoFrance models"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        guard let domain = MeteoFranceDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        let run = signature.run.map {
            guard let run = Int($0) else {
                fatalError("Invalid run '\($0)'")
            }
            return run
        } ?? domain.lastRun
        
        let onlyVariables: [MeteoFranceVariableDownloadable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                if let variable = MeteoFrancePressureVariable(rawValue: String($0)) {
                    return variable
                }
                guard let variable = MeteoFranceSurfaceVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let pressureVariables = domain.levels.reversed().flatMap { level in
            MeteoFrancePressureVariableType.allCases.compactMap { variable -> MeteoFrancePressureVariable? in
                if variable == .cloudcover && level < 100 {
                    return nil
                }
                return MeteoFrancePressureVariable(variable: variable, level: level)
            }
        }
        let surfaceVariables = MeteoFranceSurfaceVariable.allCases
        
        let variablesAll = onlyVariables ?? (signature.upperLevel ? pressureVariables : surfaceVariables)
        
        let variables = variablesAll.filter({ $0.availableFor(domain: domain) })
        
        let date = Timestamp.now().add(-24*3600 * (signature.pastDays ?? 0)).with(hour: run)
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(date.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try download(logger: logger, domain: domain, run: date, variables: variables, skipFilesIfExisting: signature.skipExisting)
        try convert(logger: logger, domain: domain, variables: variables, run: date, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    func downloadElevation(logger: Logger, url: String, surfaceElevationFileOm: String, grid: Gridable, isGlobal: Bool) throws {
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
        for (variable, message) in try curl.downloadIndexedGrib(url: url, variables: ElevationVariable.allCases) {
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
    
    /// download MeteoFrance
    func download(logger: Logger, domain: MeteoFranceDomain, run: Timestamp, variables: [MeteoFranceVariableDownloadable], skipFilesIfExisting: Bool) throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger, deadLineHours: 4)
                
        /// world 0-24, 27-48, 51-72, 75-102
        let fileTimes = domain.getForecastHoursPerFile(run: run.hour, hourlyForArpegeEurope: false)
        let fileTimesHourly = domain.getForecastHoursPerFile(run: run.hour, hourlyForArpegeEurope: true)
        
        // loop over time files... every file has 6,12 or 24 hour of data
        for (fileTime, fileTimeHourly) in zip(fileTimes, fileTimesHourly) {
            // loop over packages for variables, like SP1 or IP1
            for package in MfVariablePackages.allCases {
                logger.info("Downloading forecast hour \(fileTime.file) package \(package)")
                
                let vars = variables.flatMap { variable -> [MfGribVariable] in
                    guard variable.inPackage == package else {
                        return []
                    }
                    // Some varibales are hourly although the rest is 3/6 h
                    let time = (variable.isAlwaysHourlyInArgegeEurope && domain == .arpege_europe) ? fileTimeHourly.steps : fileTime.steps
                    return time.compactMap { h in
                        if h == 0 && variable.skipHour0(domain: domain) {
                            return nil
                        }
                        let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(h).om"
                        if skipFilesIfExisting && FileManager.default.fileExists(atPath: file) {
                            return nil
                        }
                        return MfGribVariable(hour: h, gribIndexName: variable.toGribIndexName(hour: h), variable: variable)
                    }
                }
                                
                //https://mf-nwp-models.s3.amazonaws.com/arpege-world/v1/2022-08-21/00/SP1/00H24H.grib2.inv
                //https://mf-nwp-models.s3.amazonaws.com/arome-france/v1/2022-09-14/00/SP1/00H24H.grib2.inv
                let dmn = domain.rawValue.replacingOccurrences(of: "_", with: "-")
                let url = "https://mf-nwp-models.s3.amazonaws.com/\(dmn)/v1/\(run.iso8601_YYYY_MM_dd)/\(run.hour.zeroPadded(len: 2))/\(package)/\(fileTime.file).grib2"
                
                for (variable, data) in try curl.downloadIndexedGribSequential(url: url, variables: vars, extension: ".inv") {
                    var data = data
                    if domain.isGlobal {
                        data.shift180LongitudeAndFlipLatitude()
                    } else {
                        data.flipLatitude()
                    }
                    data.ensureDimensions(of: domain.grid)
                    // Scaling before compression with scalefactor
                    if let fma = variable.variable.multiplyAdd {
                        data.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(variable.hour).nc")
                    let file = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(variable.hour).om"
                    try FileManager.default.removeItemIfExists(at: file)
                    
                    curl.logger.info("Compressing and writing data to \(variable.variable.omFileName)_\(variable.hour).om")
                    let compression = variable.variable.isAveragedOverForecastTime || variable.variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                    try OmFileWriter.write(file: file, compressionType: compression, scalefactor: variable.variable.scalefactor, dim0: 1, dim1: data.count, chunk0: 1, chunk1: 8*1024, all: data.data)
                }
            }
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: MeteoFranceDomain, variables: [MeteoFranceVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let forecastHours = domain.forecastHours(run: run.hour, hourlyForArpegeEurope: false)
        let forecastHoursHourly = domain.forecastHours(run: run.hour, hourlyForArpegeEurope: true)
        let dtHours = domain.dtHours
        
        let nForecastHours = forecastHours.max()! / dtHours + 1
        
        let grid = domain.grid
        let nLocation = grid.count
        
        for variable in variables {
            let startConvert = DispatchTime.now()
            let forecastHours = (variable.isAlwaysHourlyInArgegeEurope && domain == .arpege_europe) ? forecastHoursHourly : forecastHours
            
            logger.info("Converting \(variable)")
            
            var data2d = Array2DFastTime(nLocations: nLocation, nTime: nForecastHours)
            let skipHour0 = variable.skipHour0(domain: domain)

            for forecastHour in forecastHours {
                if forecastHour == 0 && skipHour0 {
                    continue
                }
                let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(forecastHour).om"
                data2d[0..<nLocation, forecastHour / dtHours] = try OmFileReader(file: file).readAll()
            }
            
            let skip = skipHour0 ? 1 : 0
            
            // Deaverage radiation. Not really correct for 3h data after 120 hours, but solar interpolation will correct it afterwards
            //if variable.isAveragedOverForecastTime {
                //data2d.deavergeOverTime(slidingWidth: data2d.nTime, slidingOffset: skip)
                //data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: skip)
            //}
            // radiation in meteofrance is aggregated and not averaged!
            
            /// somehow radiation for ARPEGE EUROPE and AROME FRANCE is stored with a factor of 3... Maybe to be compatible with ARPEGE WORLD?
            if let variable = variable as? MeteoFranceSurfaceVariable, variable == .shortwave_radiation {
                data2d.data.multiplyAdd(multiply: 3, add: 0)
            }
            
            // Fill in missing hourly values after switching to 3h
            //data2d.interpolate2Steps(type: variable.interpolationType, positions: forecastStepsToInterpolate, grid: domain.grid, run: run, dtSeconds: domain.dtSeconds)
            
            if dtHours == 1 {
                // Interpolate 6h steps to 3h steps before 1h
                let forecastStepsToInterpolate6h = (0..<nForecastHours).compactMap { hour -> Int? in
                    if forecastHours.contains(hour) || hour % 3 != 0 {
                        return nil
                    }
                    return hour
                }
                data2d.interpolate1Step(interpolation: variable.interpolation, interpolationHours: forecastStepsToInterpolate6h, dt: 3)
                
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
            } else {
                // Arpege world with dtHours=3. Interpolate 6h to 3h values
                // TODO: shortwave radiation is not correct for the last hours
                let forecastStepsToInterpolate6h = (0 ..< nForecastHours * dtHours).compactMap { hour -> Int? in
                    return forecastHours.contains(hour) || hour % 3 != 0 ? nil : hour / dtHours
                }
                data2d.interpolate1Step(interpolation: variable.interpolation, interpolationHours: forecastStepsToInterpolate6h, dt: 1)
            }
            
            // De-accumulate precipitation
            if variable.isAccumulatedSinceModelStart {
                //data2d.deaccumulateOverTime(slidingWidth: domain == .nam_conus ? 3 : data2d.nTime, slidingOffset: skip)
                data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: skip)
            }
            
            let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nForecastHours
            
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

struct MfGribVariable: CurlIndexedVariable {
    //var gribIndexName: String?
    
    let hour: Int // 0 = anl
    let gribIndexName: String? // :PRMSL:mean sea level:1 hour fcst:
    //let backwardsDtHours: Int? // 10 m above ground:0-1 hour max fcst
    //let isAccumulatedModelStart: Bool // TPRATE:surface:0-1 hour acc fcst
    let variable: MeteoFranceVariableDownloadable
    
}

enum MfVariablePackages: String, CaseIterable {
    case SP1
    case SP2
    case IP1
    case IP2
    case IP3
}
