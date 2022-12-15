import Foundation
import Vapor
import SwiftPFor2D


/**
Meteofrance Arome, Arpge downloader
 */
struct MeteoFranceDownload: AsyncCommandFix {
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
    
    func run(using context: CommandContext, signature: Signature) async throws {
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
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        try await downloadElevation(application: context.application, domain: domain)
        try await download(application: context.application, domain: domain, run: date, variables: variables, skipFilesIfExisting: signature.skipExisting)
        try convert(logger: logger, domain: domain, variables: variables, run: date, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }
    
    // download seamask and height
    func downloadElevation(application: Application, domain: MeteoFranceDomain) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        logger.info("Downloading height and elevation data")
        
        var height: Array2D? = nil
        var landmask: Array2D? = nil
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        let dmn = domain.rawValue.replacingOccurrences(of: "_", with: "-")
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let terrainUrl = "http://mf-nwp-models.s3.amazonaws.com/\(dmn)/static/terrain.grib2"
        for message in try await curl.downloadGrib(url: terrainUrl, bzip2Decode: false) {
            try grib2d.load(message: message)
            if domain.isGlobal {
                grib2d.array.shift180LongitudeAndFlipLatitude()
            } else {
                grib2d.array.flipLatitude()
            }
            height = grib2d.array
            //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)terrain.nc")
        }
        
        let landmaskUrl = "http://mf-nwp-models.s3.amazonaws.com/\(dmn)/static/landmask.grib2"
        for message in try await curl.downloadGrib(url: landmaskUrl, bzip2Decode: false) {
            try grib2d.load(message: message)
            if domain.isGlobal {
                grib2d.array.shift180LongitudeAndFlipLatitude()
            } else {
                grib2d.array.flipLatitude()
            }
            landmask = grib2d.array
            //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)landmask.nc")
        }
        
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] == 1 ? height.data[i] : -999
        }
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: height.data)
    }
    
    /// download MeteoFrance
    func download(application: Application, domain: MeteoFranceDomain, run: Timestamp, variables: [MeteoFranceVariableDownloadable], skipFilesIfExisting: Bool) async throws {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4)
                
        /// world 0-24, 27-48, 51-72, 75-102
        let fileTimes = domain.getForecastHoursPerFile(run: run.hour, hourlyForArpegeEurope: false)
        let fileTimesHourly = domain.getForecastHoursPerFile(run: run.hour, hourlyForArpegeEurope: true)
        
        let nLocationsPerChunk = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
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
                let url = "http://mf-nwp-models.s3.amazonaws.com/\(dmn)/v1/\(run.iso8601_YYYY_MM_dd)/\(run.hour.zeroPadded(len: 2))/\(package)/\(fileTime.file).grib2"
                
                for (variable, message) in try await curl.downloadIndexedGribSequential(url: url, variables: vars, extension: ".inv") { 
                    try grib2d.load(message: message)
                    if domain.isGlobal {
                        grib2d.array.shift180LongitudeAndFlipLatitude()
                    } else {
                        grib2d.array.flipLatitude()
                    }
                    // Scaling before compression with scalefactor
                    if let fma = variable.variable.multiplyAdd {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(variable.hour).nc")
                    let file = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(variable.hour).om"
                    try FileManager.default.removeItemIfExists(at: file)
                    
                    logger.info("Compressing and writing data to \(variable.variable.omFileName)_\(variable.hour).om")
                    let compression = variable.variable.isAveragedOverForecastTime || variable.variable.isAccumulatedSinceModelStart ? CompressionType.fpxdec32 : .p4nzdec256
                    try writer.write(file: file, compressionType: compression, scalefactor: variable.variable.scalefactor, all: grib2d.array.data)
                }
            }
        }
        curl.printStatistics()
    }
    
    /// Process each variable and update time-series optimised files
    func convert(logger: Logger, domain: MeteoFranceDomain, variables: [MeteoFranceVariableDownloadable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let forecastHours = domain.forecastHours(run: run.hour, hourlyForArpegeEurope: false)
        let forecastHoursHourly = domain.forecastHours(run: run.hour, hourlyForArpegeEurope: true)
        let dtHours = domain.dtHours
        
        let nTime = forecastHours.max()! / dtHours + 1
        
        let ringtime = run.timeIntervalSince1970 / domain.dtSeconds ..< run.timeIntervalSince1970 / domain.dtSeconds + nTime
        
        let time = TimerangeDt(start: run, nTime: nTime * domain.dtHours, dtSeconds: domain.dtSeconds)
        
        let grid = domain.grid
        let nLocations = grid.count
        
        var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        for variable in variables {
            let forecastHours = (variable.isAlwaysHourlyInArgegeEurope && domain == .arpege_europe) ? forecastHoursHourly : forecastHours
            
            let skipHour0 = variable.skipHour0(domain: domain)
            let skip = skipHour0 ? 1 : 0
            let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)")
            
            let readers: [(hour: Int, reader: OmFileReader<MmapFile>)] = try forecastHours.compactMap({ hour in
                if hour == 0 && skipHour0 {
                    return nil
                }
                let reader = try OmFileReader(file: "\(domain.downloadDirectory)\(variable.omFileName)_\(hour).om")
                try reader.willNeed()
                return (hour, reader)
            })
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { d0offset in
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data2d.data.fillWithNaNs()
                for reader in readers {
                    try reader.reader.read(into: &readTemp, arrayRange: 0..<locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                    data2d[0..<data2d.nLocations, reader.hour / domain.dtHours] = readTemp
                }
                
                // Deaverage radiation. Not really correct for 3h or 6h data, but solar interpolation will correct it afterwards
                // radiation in meteofrance is aggregated and not averaged!
                if variable.interpolation.isSolarInterpolation {
                    data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: skip)
                }
                
                /// somehow radiation for ARPEGE EUROPE and AROME FRANCE is stored with a factor of 3... Maybe to be compatible with ARPEGE WORLD?
                if let variable = variable as? MeteoFranceSurfaceVariable, variable == .shortwave_radiation, domain != .arpege_world {
                    data2d.data.multiplyAdd(multiply: 3, add: 0)
                }
                
                if dtHours == 1 {
                    // Interpolate 6h steps to 3h steps before 1h
                    let forecastStepsToInterpolate6h = (0..<nTime).compactMap { hour -> Int? in
                        if forecastHours.contains(hour) || hour % 3 != 0 {
                            return nil
                        }
                        return hour
                    }
                    data2d.interpolate1Step(interpolation: variable.interpolation, interpolationHours: forecastStepsToInterpolate6h, width: 3, time: time, grid: grid, locationRange: locationRange)
                    
                    // interpolate missing timesteps. We always fill 2 timesteps at once
                    // data looks like: DDDDDDDDDD--D--D--D--D--D
                    let forecastStepsToInterpolate = (0..<nTime).compactMap { hour -> Int? in
                        if forecastHours.contains(hour) || hour % 3 != 1 {
                            // process 2 timesteps at once
                            return nil
                        }
                        return hour
                    }
                    
                    // Fill in missing hourly values after switching to 3h
                    data2d.interpolate2Steps(type: variable.interpolationType, positions: forecastStepsToInterpolate, grid: domain.grid, locationRange: locationRange, run: run, dtSeconds: domain.dtSeconds)
                } else {
                    // Arpege world with dtHours=3. Interpolate 6h to 3h values (actually only the last timestep)
                    let forecastStepsToInterpolate6h = stride(from: 0, to: nTime * dtHours, by: dtHours).compactMap { hour -> Int? in
                        return forecastHours.contains(hour) ? nil : hour / dtHours
                    }

                    data2d.interpolate1Step(interpolation: variable.interpolation, interpolationHours: forecastStepsToInterpolate6h, width: 1, time: time, grid: grid, locationRange: locationRange)
                }
                
                // De-accumulate precipitation
                if variable.isAccumulatedSinceModelStart, !variable.interpolation.isSolarInterpolation {
                    data2d.deaccumulateOverTime(slidingWidth: data2d.nTime, slidingOffset: skip)
                }
                
                progress.add(locationRange.count)
                return data2d.data[0..<locationRange.count * nTime]
            }
            progress.finish()
        }
    }
}

fileprivate struct MfGribVariable: CurlIndexedVariable {
    /// 0 = anl
    let hour: Int
    
    /// :PRMSL:mean sea level:1 hour fcst:
    let gribIndexName: String?
    
    /// Pressure or surface variable
    let variable: MeteoFranceVariableDownloadable
}
