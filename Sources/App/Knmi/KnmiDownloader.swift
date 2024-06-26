import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

struct KnmiDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download KNMI models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try KnmiDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? 1
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        //try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            //try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }

    /// Temporarily keep those varibles to derive others
    enum KnmiVariableTemporary: String {
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

     */
    func download(application: Application, domain: KnmiDomain, run: Timestamp, concurrent: Int) async throws -> [GenericVariableHandle] {
        guard let apikey = Environment.get("KNMI_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'KNMI_API_KEY'")
        }
        let logger = application.logger
        let deadLineHours = Double(2)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2*60))
        
        // https://english.knmidata.nl/latest/newsletters/open-data-newsletter/2024/open-data-june-2024
        // det EU surface: harmonie_arome_cy43_p3/versions/1.0/files/HARM43_V1_P3_2024062607.tar (2.8 GB surface, radiation, some pressure)
        // det EU model:   harmonie_arome_cy43_p5/versions/1.0/files/HARM43_V1_P5_2024062607.tar (16.7 GB only hybrid levels)
        // eps EU surface: harmonie_arome_cy43_p4a/versions/1.0/files/harm43_v1_P4a_2024062607.tar (5,3 GB, varying members???, surface, clouds
        // eps EU renew:   harmonie_arome_cy43_p4b/versions/1.0/files/harm43_v1_P4b_2024062607.tar (2.8 GB, varying members???, 10, 100, 200, 300 wind, tcc + radiation)
        // det NL surface: harmonie_arome_cy43_p1/versions/1.0/files/HARM43_V1_P1_2024062607.tar (900 MB, )
        // eps NL surface: harmonie_arome_cy43_p2a/versions/1.0/files/harm43_v1_P2a_2024062607.tar
        // eps NL renew:   harmonie_arome_cy43_p2b/versions/1.0/files/harm43_v1_P2b_2024062607.tar
        // det DK avaiation:  uwcw_extra_lv_ha43_nl_2km/versions/1.0/files/*.nc
        
        let dataset: String
        switch domain {
        case .harmonie_arome_europe:
            dataset = "harmonie_arome_cy43_p3/versions/1.0/files/HARM43_V1_P3"
        case .harmonie_arome_netherlands:
            dataset = "harmonie_arome_cy43_p1/versions/1.0/files/HARM43_V1_P1"
        }
        
        let metaUrl = "https://api.dataplatform.knmi.nl/open-data/v1/datasets/\(dataset)_\(run.format_YYYYMMddHH).tar/url"
        
        
        guard let metaData = try await curl.downloadInMemoryAsync(url: metaUrl, minSize: nil, headers: [("Authorization", "Bearer \(apikey.randomElement() ?? "")")]).readJSONDecodable(MetaUrlResponse.self) else {
            fatalError("Could not decode meta response")
        }
        
        let handles = try await curl.withGribStream(url: metaData.temporaryDownloadUrl, bzip2Decode: false) { stream in
            
            let previous = GribDeaverager()
            let inMemory = VariablePerMemberStorage<KnmiVariableTemporary>()
            
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
                /// NOTE: KNMI does not ssem to set this field. Only way to decode member number would be file name which is not accessible while streaming
                let member = message.getLong(attribute: "perturbationNumber") ?? 0
                let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
                
                
                if let temporary = KnmiVariableTemporary.getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) {
                    var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                    try grib2d.load(message: message)
                    await inMemory.set(variable: temporary, timestamp: timestamp, member: member, data: grib2d.array)
                    return nil
                }
                
                guard let variable = getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) else {
                    logger.warning("Unmapped GRIB message \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member)")
                    return nil
                }
                logger.info("GRIB message \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member)")
                
                if stepType == "accum" && timestamp == run {
                    return nil // skip precipitation at timestep 0
                }
                
                let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                //message.dumpAttributes()
                try grib2d.load(message: message)
                /*if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }*/
                
                // Scaling before compression with scalefactor
                /*if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }*/
                
                //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                
                // keep lsm and gph/z surface
                

                
                switch unit {
                case "K":
                    grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                case "m**2 s**-2": // gph to metre
                    grib2d.array.data.multiplyAdd(multiply: 1/9.80665, add: 0)
                case "(0-1)":
                    grib2d.array.data.multiplyAdd(multiply: 100, add: 0)
                case "Pa":
                    grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0) // to hPa
                case "J m**-2":
                    grib2d.array.data.multiplyAdd(multiply: 3600/10_000_000, add: 0) // to W/m2
                default:
                    break
                }
                
                // Deaccumulate precipitation
                guard await previous.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                    return nil
                }
                
                logger.info("Compressing and writing data to \(timestamp.format_YYYYMMddHH) \(variable)")
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                return GenericVariableHandle(variable: variable, time: timestamp, member: member, fn: fn, skipHour0: stepType == "accum" || stepType == "avg")
            }.collect().compactMap({$0})
            
            let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
            let gustHandles = try await inMemory.calculateWindSpeed(u: .ugst, v: .vgst, outSpeedVariable: IconSurfaceVariable.wind_gusts_10m, writer: writer)
            
            return h + gustHandles
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
        case ("vis", "heightAboveGround", "0"):
            return GfsSurfaceVariable.visibility
        case ("t", "heightAboveGround", "0"):
            return GfsSurfaceVariable.surface_temperature
        case ("t", "heightAboveGround", "2"):
            return MeteoFranceSurfaceVariable.temperature_2m
        case ("u", "heightAboveGround", "10"):
            return MeteoFranceSurfaceVariable.wind_u_component_10m
        case ("v", "heightAboveGround", "10"):
            return MeteoFranceSurfaceVariable.wind_v_component_10m
        case ("r", "heightAboveGround", "2"):
            return MeteoFranceSurfaceVariable.relative_humidity_2m
        case ("pres", "heightAboveSea", "0"):
            return MeteoFranceSurfaceVariable.pressure_msl
            
            
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
        case ("rain", "0"):
            return IconSurfaceVariable.rain
        case ("snow", "0"):
            return IconSurfaceVariable.snowfall_water_equivalent
            
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
        case ("grad", "0"):
            return MeteoFranceSurfaceVariable.shortwave_radiation
        case ("tcc", "0"):
            return MeteoFranceSurfaceVariable.cloud_cover
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
}
