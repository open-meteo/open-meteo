import Foundation
import Vapor
import SwiftPFor2D


/**
Meteofrance Arome, Arpge downloader
 */
struct MeteoFranceDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download MeteoFrance models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try MeteoFranceDomain.load(rawValue: signature.domain)
        
        if signature.onlyVariables != nil && signature.upperLevel {
            fatalError("Parameter 'onlyVariables' and 'upperLevel' must not be used simultaneously")
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let onlyVariables: [MeteoFranceVariableDownloadable]? = try signature.onlyVariables.map {
            try $0.split(separator: ",").map {
                if let variable = MeteoFrancePressureVariable(rawValue: String($0)) {
                    return variable
                }
                return try MeteoFranceSurfaceVariable.load(rawValue: String($0))
            }
        }
        
        let pressureVariables = domain.levels.reversed().flatMap { level in
            MeteoFrancePressureVariableType.allCases.map { variable -> MeteoFrancePressureVariable in
                return MeteoFrancePressureVariable(variable: variable, level: level)
            }
        }
        let surfaceVariables = MeteoFranceSurfaceVariable.allCases
        
        let variablesAll = onlyVariables ?? (signature.upperLevel ? pressureVariables : surfaceVariables)
        
        let variables = variablesAll.filter({ $0.availableFor(domain: domain, forecastSecond: 0) })
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                
        try await downloadElevation2(application: context.application, domain: domain, run: run)
        let handles = try await download2(application: context.application, domain: domain, run: run, variables: variables)
        try GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles)
        //try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    func downloadElevation2(application: Application, domain: MeteoFranceDomain, run: Timestamp) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if domain == .arome_france_15min || domain == .arome_france_hd_15min {
            return
        }
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()
        guard let apikey = Environment.get("METEOFRANCE_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'METEOFRANCE_API_KEY'")
        }
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, headers: [("apikey", apikey.randomElement() ?? "")])
        let runTime = "\(run.iso8601_YYYY_MM_dd)T\(run.hour.zeroPadded(len: 2)).00.00Z"
        let subsetGrid = domain.mfSubsetGrid
        let url = "https://public-api.meteofrance.fr/public/\(domain.family.rawValue)/1.0/wcs/\(domain.mfApiName)-WCS/GetCoverage?service=WCS&version=2.0.1&coverageid=GEOMETRIC_HEIGHT__GROUND_OR_WATER_SURFACE___\(runTime)\(subsetGrid)&subset=time(0)&format=application%2Fwmo-grib"
        
        let message = try await curl.downloadGrib(url: url, bzip2Decode: false)[0]
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        try grib2d.load(message: message)
        if domain.isGlobal {
            grib2d.array.shift180LongitudeAndFlipLatitude()
        } else {
            grib2d.array.flipLatitude()
        }
        //try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)elevation.nc")
        //try message.debugGrid(grid: domain.grid, flipLatidude: true, shift180Longitude: true)
        //message.dumpAttributes()
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: grib2d.array.data)
    }
    
    func download3(application: Application, domain: MeteoFranceDomain, run: Timestamp, variables: [MeteoFranceVariableDownloadable], concurrent: Int) async throws -> [GenericVariableHandle] {
        guard let apikey = Environment.get("METEOFRANCE_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'METEOFRANCE_API_KEY'")
        }
        let logger = application.logger
        let deadLineHours: Double = 5.5
        Process.alarm(seconds: Int(deadLineHours+1) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
        
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        var handles = [GenericVariableHandle]()
        
        let previous = GribDeaverager()
        
        let packages = ["IP1"]//"SP1", "SP2", "SP3", "HP1"]
        let packageTimes = ["00H06H","07H12H","13H18H","19H24H","25H30H","31H36H","37H42H","43H48H","49H51H"]
        //https://public-api.meteofrance.fr/previnum/DPPaquetAROME/v1/models/AROME/grids/0.025/packages/SP2/productARO?referencetime=2024-06-20T21%3A00%3A00Z&time=00H06H&format=grib2
        
        for packageTime in packageTimes {
            for package in packages {
                let url = "https://public-api.meteofrance.fr/previnum/DPPaquetAROME/v1/models/AROME/grids/0.025/packages/\(package)/productARO?referencetime=\(run.iso8601_YYYY_MM_dd_HH_mm):00Z&time=\(packageTime)&format=grib2"
                
                /// MeteoFrance servers close the HTTP connection unclean, resulting in `connection reset by peer` errors
                /// Use a new HTTP client with new connections for every request
                let client = application.makeNewHttpClient()
                let curl = Curl(logger: logger, client: client, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2*60))
                let h = try await curl.withGribStream(url: url, bzip2Decode: false, headers: [("apikey", apikey.randomElement() ?? "")]) { stream in
                    return stream.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                        guard let shortName = message.get(attribute: "shortName"),
                              let stepRange = message.get(attribute: "stepRange"),
                              let stepType = message.get(attribute: "stepType"),
                              let levelStr = message.get(attribute: "level"),
                              let typeOfLevel = message.get(attribute: "typeOfLevel"),
                              let parameterName = message.get(attribute: "parameterName"),
                              let parameterUnits = message.get(attribute: "parameterUnits"),
                              let validityTime = message.get(attribute: "validityTime"),
                              let validityDate = message.get(attribute: "validityDate")
                        else {
                            fatalError("could not get attributes")
                        }
                        let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
                        guard let variable = getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) else {
                            logger.warning("Unmapped GRIB message \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)")
                            return nil
                        }
                        
                        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                        //message.dumpAttributes()
                        try grib2d.load(message: message)
                        if domain.isGlobal {
                            grib2d.array.shift180LongitudeAndFlipLatitude()
                        } else {
                            grib2d.array.flipLatitude()
                        }
                        
                        // Scaling before compression with scalefactor
                        if let fma = variable.multiplyAdd {
                            grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                        }
                        
                        // Deaccumulate precipitation
                        guard await previous.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                            return nil
                        }
                        
                        logger.info("Compressing and writing data to \(timestamp.format_YYYYMMddHH) \(variable)")
                        let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                        return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: stepType == "accum" || stepType == "avg")
                    }
                }.collect().compactMap({$0})
                handles.append(contentsOf: h)
            }
        }
        //await curl.printStatistics()
        return handles
    }
    
    func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> MeteoFranceVariableDownloadable? {
        
        switch (parameterName, levelStr) {
        case ("Total cloud cover", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover
        default:
            break
        }
        
        if typeOfLevel == "isobaricInhPa" {
            guard let level = Int(levelStr) else {
                fatalError("Could not parse level str \(levelStr)")
            }
            switch shortName {
            case "t":
                return MeteoFrancePressureVariable(variable: .temperature, level: level)
            case "u":
                return MeteoFrancePressureVariable(variable: .wind_u_component, level: level)
            case "v":
                return MeteoFrancePressureVariable(variable: .wind_v_component, level: level)
            case "r":
                return MeteoFrancePressureVariable(variable: .relative_humidity, level: level)
            case "z":
                return MeteoFrancePressureVariable(variable: .geopotential_height, level: level)
            default:
                break
            }
        }
        
        switch (shortName, typeOfLevel, levelStr) {
        case ("t", "heightAboveGround", "20"):
            return MeteoFranceSurfaceVariable.temperature_20m
        case ("t", "heightAboveGround", "50"):
            return MeteoFranceSurfaceVariable.temperature_50m
        case ("t", "heightAboveGround", "100"):
            return MeteoFranceSurfaceVariable.temperature_100m
        case ("t", "heightAboveGround", "150"):
            return MeteoFranceSurfaceVariable.temperature_150m
        case ("t", "heightAboveGround", "200"):
            return MeteoFranceSurfaceVariable.temperature_200m
        case ("u", "heightAboveGround", "20"):
            return MeteoFranceSurfaceVariable.wind_u_component_20m
        case ("u", "heightAboveGround", "50"):
            return MeteoFranceSurfaceVariable.wind_u_component_50m
        case ("100u", "heightAboveGround", "100"):
            return MeteoFranceSurfaceVariable.wind_u_component_100m
        case ("u", "heightAboveGround", "150"):
            return MeteoFranceSurfaceVariable.wind_u_component_150m
        case ("200u", "heightAboveGround", "200"):
            return MeteoFranceSurfaceVariable.wind_u_component_200m
        case ("v", "heightAboveGround", "20"):
            return MeteoFranceSurfaceVariable.wind_v_component_20m
        case ("v", "heightAboveGround", "50"):
            return MeteoFranceSurfaceVariable.wind_v_component_50m
        case ("100v", "heightAboveGround", "100"):
            return MeteoFranceSurfaceVariable.wind_v_component_100m
        case ("v", "heightAboveGround", "150"):
            return MeteoFranceSurfaceVariable.wind_v_component_150m
        case ("200v", "heightAboveGround", "200"):
            return MeteoFranceSurfaceVariable.wind_v_component_200m
            
        default:
            break
        }
        
        switch (shortName, levelStr) {
        case ("2t", "2"):
            return MeteoFranceSurfaceVariable.temperature_2m
        case ("2r", "2"):
            return MeteoFranceSurfaceVariable.relative_humidity_2m
        case ("tp", "0"):
            return MeteoFranceSurfaceVariable.precipitation
        case ("prmsl", "0"):
              return MeteoFranceSurfaceVariable.pressure_msl
        case ("10v", "10"):
              return MeteoFranceSurfaceVariable.wind_v_component_10m
        case ("10u", "10"):
              return MeteoFranceSurfaceVariable.wind_u_component_10m
        case ("clct", "0"):
              return MeteoFranceSurfaceVariable.cloud_cover
        case ("snow_gsp", "0"):
              return MeteoFranceSurfaceVariable.snowfall_water_equivalent
        case ("10fg", "10"):
            return MeteoFranceSurfaceVariable.wind_gusts_10m
        case ("ssrd", "0"):
            return MeteoFranceSurfaceVariable.shortwave_radiation
        case ("lcc", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover_low
        case ("mcc", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover_mid
        case ("hcc", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover_high
        case ("CAPE_INS", "0"):
            return MeteoFranceSurfaceVariable.cape
        case ("tsnowp", "0"):
            return MeteoFranceSurfaceVariable.snowfall_water_equivalent
        default: return nil
        }
    }
    
    func download2(application: Application, domain: MeteoFranceDomain, run: Timestamp, variables: [MeteoFranceVariableDownloadable]) async throws -> [GenericVariableHandle] {
        if [MeteoFranceDomain.arome_france].contains(domain) {
            return try await download3(application: application, domain: domain, run: run, variables: variables, concurrent: 4)
        }
        
        guard let apikey = Environment.get("METEOFRANCE_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'METEOFRANCE_API_KEY'")
        }
        let logger = application.logger
        let deadLineHours: Double = 5.5
        Process.alarm(seconds: Int(deadLineHours+1) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        
        let grid = domain.grid
        var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
        let subsetGrid = domain.mfSubsetGrid
        
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        var handles = [GenericVariableHandle]()
        
        for seconds in domain.forecastSeconds(run: run.hour, hourlyForArpegeEurope: true) {
            let timestamp = run.add(seconds)
            for variable in variables {
                guard variable.availableFor(domain: domain, forecastSecond: seconds) else {
                    continue
                }
                if seconds == 0 && variable.skipHour0(domain: domain) {
                    continue
                }
                let coverage = variable.getCoverageId()
                let subsetHeight = coverage.height.map { "&subset=height(\($0))" } ?? ""
                let subsetPressure = coverage.pressure.map { "&subset=pressure(\($0))" } ?? ""
                let subsetTime = "&subset=time(\(seconds))"
                let runTime = "\(run.iso8601_YYYY_MM_dd)T\(run.hour.zeroPadded(len: 2)).00.00Z"
                let is3H = domain == .arpege_world && (seconds/3600) >= 51
                let period = coverage.isPeriod ? domain.dtSeconds == 900 ? "_PT15M" : is3H ? "_PT3H" : "_PT1H" : ""
                
                let url = "https://public-api.meteofrance.fr/public/\(domain.family.rawValue)/1.0/wcs/\(domain.mfApiName)-WCS/GetCoverage?service=WCS&version=2.0.1&coverageid=\(coverage.variable)___\(runTime)\(period)\(subsetGrid)\(subsetHeight)\(subsetPressure)\(subsetTime)&format=application%2Fwmo-grib"
                
                /// MeteoFrance servers close the HTTP connection unclean, resulting in `connection reset by peer` errors
                /// Use a new HTTP client with new connections for every request
                let client = application.makeNewHttpClient()
                let curl = Curl(logger: logger, client: client, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2*60))
                let message = try await curl.downloadGrib(url: url, bzip2Decode: false, headers: [("apikey", apikey.randomElement() ?? "")])[0]
                
                //try message.debugGrid(grid: grid, flipLatidude: true, shift180Longitude: true)
                //message.dumpAttributes()
                
                try grib2d.load(message: message)
                try await client.shutdown()
                if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                handles.append(GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: 0,
                    fn: fn,
                    skipHour0: variable.skipHour0(domain: domain)
                ))
                
            }
        }
        //await curl.printStatistics()
        return handles
    }
}
