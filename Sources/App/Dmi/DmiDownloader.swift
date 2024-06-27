import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

struct DmiDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download Dmi models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try DmiDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? System.coreCount
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        //try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }

    /// Temporarily keep those varibles to derive others
    enum DmiVariableTemporary: String {
        case ugst
        case vgst
        
        static func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> Self? {
            switch (shortName, typeOfLevel, levelStr) {
            case ("ugst", "heightAboveGround", "10"):
                return .ugst
            case ("vgst", "heightAboveGround", "10"):
                return .vgst
            default:
                return nil
            }
        }
    }
    
    struct MetaUrlResponse: Decodable {
        let size: String
        let temporaryDownloadUrl: String
        let lastModified: String
        let contentType: String
    }
    
    /**
     TODO:
     - model elevation and land/sea mask
     - check if wind direction needs to be corrected for projection
     */
    func download(application: Application, domain: DmiDomain, run: Timestamp, concurrent: Int, maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        guard let apikey = Environment.get("DMI_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'DMI_API_KEY'")
        }
        let logger = application.logger
        let deadLineHours = Double(2)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2*60))
        
        let dataset: String
        switch domain {
        case .harmonie_arome_europe:
            dataset = "HARMONIE_DINI_SF"
        }
        
        var previous = GribDeaverager()
        let timerange = TimerangeDt(start: run, nTime: maxForecastHour ?? 60, dtSeconds: 3600)
        
        let handles = try await timerange.asyncFlatMap { t -> [GenericVariableHandle] in
            let url = "https://dmigw.govcloud.dk/v1/forecastdata/download/\(dataset)_\(run.iso8601_YYYY_MM_dd_HHmm)00Z_\(t.iso8601_YYYY_MM_dd_HHmm)00Z.grib"
            
            return try await curl.withGribStream(url: url, bzip2Decode: false, headers: [("X-Gravitee-Api-Key", apikey.randomElement() ?? "")]) { stream in
                /// In case the stream is restarted, keep the old version the deaverager
                let previousScoped = await previous.copy()
                let inMemory = VariablePerMemberStorage<DmiVariableTemporary>()
                
                // process sequentialy, as precipitation need to be in order for deaveraging
                let h = try await stream.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                    guard let shortName = message.get(attribute: "shortName"),
                          let stepRange = message.get(attribute: "stepRange"),
                          let stepType = message.get(attribute: "stepType"),
                          let levelStr = message.get(attribute: "level"),
                          let typeOfLevel = message.get(attribute: "typeOfLevel"),
                          let parameterName = message.get(attribute: "parameterName"),
                          let parameterUnits = message.get(attribute: "parameterUnits"),
                          let validityTime = message.get(attribute: "validityTime"),
                          let validityDate = message.get(attribute: "validityDate"),
                          let unit = message.get(attribute: "units"),
                          let paramId = message.getLong(attribute: "paramId")
                          //let parameterCategory = message.getLong(attribute: "parameterCategory"),
                          //let parameterNumber = message.getLong(attribute: "parameterNumber")
                    else {
                        logger.warning("could not get attributes")
                        return nil
                    }
                    let member = message.getLong(attribute: "perturbationNumber") ?? 0
                    let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
                    
                    
                    if let temporary = DmiVariableTemporary.getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) {
                        var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                        try grib2d.load(message: message)
                        await inMemory.set(variable: temporary, timestamp: timestamp, member: member, data: grib2d.array)
                        return nil
                    }
                    
                    guard let variable = getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) else {
                        logger.warning("Unmapped GRIB message \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member)")
                        return nil
                    }

                    if stepType == "accum" && timestamp == run {
                        return nil // skip precipitation at timestep 0
                    }
                    
                    let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                    var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                    try grib2d.load(message: message)
                    
                    //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                    //fatalError()
                    
                    switch unit {
                    case "K":
                        grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                    case "m**2 s**-2": // gph to metre
                        grib2d.array.data.multiplyAdd(multiply: 1/9.80665, add: 0)
                    case "(0 - 1)":
                        if variable.unit == .percentage {
                            grib2d.array.data.multiplyAdd(multiply: 100, add: 0)
                        }
                    case "Pa":
                        grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0) // to hPa
                    case "J m**-2":
                        grib2d.array.data.multiplyAdd(multiply: 1/3600, add: 0) // to W/m2
                    default:
                        break
                    }
                    
                    // Deaccumulate precipitation
                    guard await previousScoped.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                        return nil
                    }
                    
                    logger.info("Compressing and writing data to \(timestamp.format_YYYYMMddHH) \(variable)")
                    let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    return GenericVariableHandle(variable: variable, time: timestamp, member: member, fn: fn, skipHour0: stepType == "accum" || stepType == "avg")
                }.collect().compactMap({$0})
                
                previous = previousScoped
                
                let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                let gustHandles = try await inMemory.calculateWindSpeed(u: .ugst, v: .vgst, outSpeedVariable: DmiSurfaceVariable.wind_gusts_10m, writer: writer)
                
                return h + gustHandles
            }
        }
        
        await curl.printStatistics()
        return handles
    }
    
    func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> GenericVariable? {
        if typeOfLevel == "isobaricInhPa" {
            guard let level = Int(levelStr) else {
                fatalError("Could not parse level str \(levelStr)")
            }
            if level < 10 {
                return nil
            }
            switch shortName {
            case "t":
                return DmiPressureVariable(variable: .temperature, level: level)
            case "u":
                return DmiPressureVariable(variable: .wind_u_component, level: level)
            case "v":
                return DmiPressureVariable(variable: .wind_v_component, level: level)
            case "r":
                return DmiPressureVariable(variable: .relative_humidity, level: level)
            case "z":
                return DmiPressureVariable(variable: .geopotential_height, level: level)
            default:
                break
            }
        }
        
        switch (shortName, typeOfLevel, levelStr) {
        case ("vis", "heightAboveGround", "0"):
            return GfsSurfaceVariable.visibility
        case ("t", "heightAboveGround", "0"):
            return GfsSurfaceVariable.surface_temperature
        case ("t", "heightAboveGround", "2"):
            return DmiSurfaceVariable.temperature_2m
        case ("u", "heightAboveGround", "10"):
            return DmiSurfaceVariable.wind_u_component_10m
        case ("v", "heightAboveGround", "10"):
            return DmiSurfaceVariable.wind_v_component_10m
        case ("r", "heightAboveGround", "2"):
            return DmiSurfaceVariable.relative_humidity_2m
        case ("pres", "heightAboveSea", "0"):
            return DmiSurfaceVariable.pressure_msl
        case ("t", "heightAboveGround", "50"):
            return DmiSurfaceVariable.temperature_50m
        case ("t", "heightAboveGround", "100"):
            return DmiSurfaceVariable.temperature_100m
        case ("t", "heightAboveGround", "200"):
            return DmiSurfaceVariable.temperature_200m
        case ("t", "heightAboveGround", "300"):
            return DmiSurfaceVariable.temperature_300m
        case ("u", "heightAboveGround", "50"):
            return DmiSurfaceVariable.wind_u_component_50m
        case ("u", "heightAboveGround", "100"):
            return DmiSurfaceVariable.wind_u_component_100m
        case ("u", "heightAboveGround", "200"):
            return DmiSurfaceVariable.wind_u_component_200m
        case ("u", "heightAboveGround", "300"):
            return DmiSurfaceVariable.wind_u_component_300m
        case ("v", "heightAboveGround", "50"):
            return DmiSurfaceVariable.wind_v_component_50m
        case ("v", "heightAboveGround", "100"):
            return DmiSurfaceVariable.wind_v_component_100m
        case ("v", "heightAboveGround", "200"):
            return DmiSurfaceVariable.wind_v_component_200m
        case ("v", "heightAboveGround", "300"):
            return DmiSurfaceVariable.wind_v_component_200m
            
        case ("t", "heightAboveGround", "50"):
            return DmiSurfaceVariable.temperature_50m
        case ("t", "heightAboveGround", "100"):
            return DmiSurfaceVariable.temperature_100m
        case ("t", "heightAboveGround", "200"):
            return DmiSurfaceVariable.temperature_200m
        case ("t", "heightAboveGround", "300"):
            return DmiSurfaceVariable.temperature_200m
            
        case ("sdwe", "heightAboveGround", "0"):
            return DmiSurfaceVariable.snow_depth_water_equivalent
            
        default:
            break
        }
        
        switch (shortName, levelStr) {
        case ("rain", "0"):
            return DmiSurfaceVariable.rain
        case ("snow", "0"):
            return DmiSurfaceVariable.snowfall_water_equivalent
        case ("2t", "2"):
            return DmiSurfaceVariable.temperature_2m
        case ("2r", "2"):
            return DmiSurfaceVariable.relative_humidity_2m
        case ("prmsl", "0"):
              return DmiSurfaceVariable.pressure_msl
        case ("clct", "0"):
              return DmiSurfaceVariable.cloud_cover
        case ("grad", "0"):
            return DmiSurfaceVariable.shortwave_radiation
        case ("tcc", "0"), ("cc", "0"):
            return DmiSurfaceVariable.cloud_cover
        case ("lcc", "0"):
            return DmiSurfaceVariable.cloud_cover_low
        case ("mcc", "0"):
            return DmiSurfaceVariable.cloud_cover_mid
        case ("hcc", "0"):
            return DmiSurfaceVariable.cloud_cover_high
        case ("tsnowp", "0"):
            return DmiSurfaceVariable.snowfall_water_equivalent
        default: return nil
        }
    }
}
