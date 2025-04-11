import Foundation
import Vapor
import OmFileFormat
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
        
        let nConcurrent = signature.concurrent ?? System.coreCount
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        //try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Temporarily keep those varibles to derive others
    enum KnmiVariableTemporary: String {
        case ugst
        case vgst
        case landmask
        case elevation
        
        static func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> Self? {
            switch (shortName, typeOfLevel, levelStr) {
            case ("ugst", "heightAboveGround", "10"):
                return .ugst
            case ("vgst", "heightAboveGround", "10"):
                return .vgst
            case ("z", "heightAboveGround", "0"):
                return .elevation
            case ("lsm", "heightAboveGround", "0"):
                return .landmask
            default:
                return nil
            }
        }
    }
    
    struct KnmiWindVariableTemporary: Hashable {
        enum Variable: Hashable {
            case u
            case v
        }
        enum Level: Hashable {
            case isobaricInhPa(Int)
            case heightAboveGround(Int)
            
            var asIsobaricInhPa: Int? {
                switch self {
                case .isobaricInhPa(let int):
                    return int
                case .heightAboveGround(_):
                    return nil
                }
            }
        }
        let variable: Variable
        let level: Level
        
        static func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> Self? {
            guard let levelInt = Int(levelStr) else {
                return nil
            }
            let level: Level
            switch typeOfLevel {
            case "isobaricInhPa":
                level = .isobaricInhPa(levelInt)
            case "heightAboveGround":
                level = .heightAboveGround(levelInt)
            default:
                return nil
            }
            switch (shortName) {
            case "u", "10u", "100u":
                return KnmiWindVariableTemporary(variable: .u, level: level)
            case "v", "10v", "100v":
                return KnmiWindVariableTemporary(variable: .v, level: level)
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
     - model elevation and land/sea mask for European model configuration
     - support ensemble models
     - Europe domain does not have total precipitation. Only rain, snow and graupel. Showers are entirely missing!!! NL nest has total precipitation
     
     Important: Wind U/V components are defined on a Rotated LatLon  projection. They need to be corrected for true north.
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
        let trueNorth = (grid as? ProjectionGrid<RotatedLatLonProjection>)?.getTrueNorthDirection()
        let generateElevationFile = !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath())
        
        guard let metaData = try await curl.downloadInMemoryAsync(url: metaUrl, minSize: nil, headers: [("Authorization", "Bearer \(apikey.randomElement() ?? "")")]).readJSONDecodable(MetaUrlResponse.self) else {
            fatalError("Could not decode meta response")
        }
        
        let handles = try await curl.withGribStream(url: metaData.temporaryDownloadUrl, bzip2Decode: false) { stream in
            let previous = GribDeaverager()
            let inMemory = VariablePerMemberStorage<KnmiVariableTemporary>()
            let winds = VariablePerMemberStorage<KnmiWindVariableTemporary>()
            
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
                /// NOTE: KNMI does not seem to set this field. Only way to decode member number would be file name which is not accessible while streaming
                let member = message.getLong(attribute: "perturbationNumber") ?? 0
                let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
                
                /// NL nest has 100,200,300 hPa levels.... not sure what the point is with those levels
                if domain == .harmonie_arome_netherlands && typeOfLevel == "isobaricInhPa" {
                    return nil
                }
                
                if ["rain", "tsnowp"].contains(shortName) && stepType == "instant" {
                    // Rain and snow snowfall are twice inside the GRIB file.
                    // One instant and accumulation. Make sure to only use accumulation
                    return nil
                }
                
                /// Keep wind u/v in memory
                if let temporary = KnmiWindVariableTemporary.getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) {
                    logger.info("Keep in memory: \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member)")
                    var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                    try grib2d.load(message: message)
                    await winds.set(variable: temporary, timestamp: timestamp, member: member, data: grib2d.array)
                    return nil
                }
                
                if let temporary = KnmiVariableTemporary.getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) {
                    if !generateElevationFile && [KnmiVariableTemporary.elevation, .landmask].contains(temporary) {
                        return nil
                    }
                    logger.info("Keep in memory: \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member)")
                    var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                    try grib2d.load(message: message)
                    switch unit {
                    case "m**2 s**-2": // gph to metre
                        grib2d.array.data.multiplyAdd(multiply: 1/9.80665, add: 0)
                    default:
                        break
                    }
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
                logger.info("Processing \(timestamp.format_YYYYMMddHH) \(variable) [\(unit)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)")
                
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
                var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                try grib2d.load(message: message)
                
                //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                
                switch unit {
                case "K":
                    grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                case "m**2 s**-2": // gph to metre
                    grib2d.array.data.multiplyAdd(multiply: 1/9.80665, add: 0)
                case "(0 - 1)", "(0-1)":
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
                guard await previous.deaccumulateIfRequired(variable: "\(variable)", member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                    return nil
                }
                
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: grib2d.array.data)
                return GenericVariableHandle(variable: variable, time: timestamp, member: member, fn: fn)
            }.collect().compactMap({$0})
            
            if generateElevationFile {
                try await inMemory.generateElevationFile(elevation: .elevation, landmask: .landmask, domain: domain)
            }
            
            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
            let gustHandles = try await inMemory.calculateWindSpeed(u: .ugst, v: .vgst, outSpeedVariable: KnmiSurfaceVariable.wind_gusts_10m, outDirectionVariable: nil, writer: writer)
            
            let windHandles = [
                try await winds.calculateWindSpeed(
                    u: .init(variable: .u, level: .heightAboveGround(10)),
                    v: .init(variable: .v, level: .heightAboveGround(10)),
                    outSpeedVariable: KnmiSurfaceVariable.wind_speed_10m,
                    outDirectionVariable: KnmiSurfaceVariable.wind_direction_10m,
                    writer: writer,
                    trueNorth: trueNorth
                ),
                try await winds.calculateWindSpeed(
                    u: .init(variable: .u, level: .heightAboveGround(50)),
                    v: .init(variable: .v, level: .heightAboveGround(50)),
                    outSpeedVariable: KnmiSurfaceVariable.wind_speed_50m,
                    outDirectionVariable: KnmiSurfaceVariable.wind_direction_50m,
                    writer: writer,
                    trueNorth: trueNorth
                ),
                try await winds.calculateWindSpeed(
                    u: .init(variable: .u, level: .heightAboveGround(100)),
                    v: .init(variable: .v, level: .heightAboveGround(100)),
                    outSpeedVariable: KnmiSurfaceVariable.wind_speed_100m,
                    outDirectionVariable: KnmiSurfaceVariable.wind_direction_100m,
                    writer: writer,
                    trueNorth: trueNorth
                ),
                try await winds.calculateWindSpeed(
                    u: .init(variable: .u, level: .heightAboveGround(200)),
                    v: .init(variable: .v, level: .heightAboveGround(200)),
                    outSpeedVariable: KnmiSurfaceVariable.wind_speed_200m,
                    outDirectionVariable: KnmiSurfaceVariable.wind_direction_200m,
                    writer: writer,
                    trueNorth: trueNorth
                ),
                try await winds.calculateWindSpeed(
                    u: .init(variable: .u, level: .heightAboveGround(300)),
                    v: .init(variable: .v, level: .heightAboveGround(300)),
                    outSpeedVariable: KnmiSurfaceVariable.wind_speed_300m,
                    outDirectionVariable: KnmiSurfaceVariable.wind_direction_300m,
                    writer: writer,
                    trueNorth: trueNorth
                ),
            ].flatMap({$0})            
            let windPressureHandles = try await Set(winds.data.compactMap({ $0.key.variable.level.asIsobaricInhPa })).asyncFlatMap({hPa in
                try await winds.calculateWindSpeed(
                    u: .init(variable: .u, level: .isobaricInhPa(hPa)),
                    v: .init(variable: .v, level: .isobaricInhPa(hPa)),
                    outSpeedVariable: KnmiPressureVariable(variable: .wind_speed, level: hPa),
                    outDirectionVariable: KnmiPressureVariable(variable: .wind_direction, level: hPa),
                    writer: writer,
                    trueNorth: trueNorth
                )
            })
            return h + gustHandles + windHandles + windPressureHandles
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
                return KnmiPressureVariable(variable: .temperature, level: level)
            /*case "u": Wind is converted in a separate step to speed and direction with true north correction
                return KnmiPressureVariable(variable: .wind_u_component, level: level)
            case "v":
                return KnmiPressureVariable(variable: .wind_v_component, level: level)*/
            case "r":
                return KnmiPressureVariable(variable: .relative_humidity, level: level)
            case "z":
                return KnmiPressureVariable(variable: .geopotential_height, level: level)
            default:
                break
            }
        }
        
        switch (shortName, typeOfLevel, levelStr) {
        case ("vis", "heightAboveGround", "0"):
            return KnmiSurfaceVariable.visibility
        case ("t", "heightAboveGround", "0"):
            return KnmiSurfaceVariable.surface_temperature
        case ("t", "heightAboveGround", "2"):
            return KnmiSurfaceVariable.temperature_2m
        case ("r", "heightAboveGround", "2"):
            return KnmiSurfaceVariable.relative_humidity_2m
        case ("pres", "heightAboveSea", "0"):
            return KnmiSurfaceVariable.pressure_msl
        case ("t", "heightAboveGround", "50"):
            return KnmiSurfaceVariable.temperature_50m
        case ("t", "heightAboveGround", "100"):
            return KnmiSurfaceVariable.temperature_100m
        case ("t", "heightAboveGround", "200"):
            return KnmiSurfaceVariable.temperature_200m
        case ("t", "heightAboveGround", "300"):
            return KnmiSurfaceVariable.temperature_300m
        case ("sdwe", "heightAboveGround", "0"):
            return KnmiSurfaceVariable.snow_depth_water_equivalent
        default:
            break
        }
        
        switch (shortName, levelStr) {
        case ("rain", "0"):
            return KnmiSurfaceVariable.rain
        case ("tp", "0"):
            return KnmiSurfaceVariable.precipitation
        case ("snow", "0"):
            return KnmiSurfaceVariable.snowfall_water_equivalent
        case ("2t", "2"):
            return KnmiSurfaceVariable.temperature_2m
        case ("2r", "2"):
            return KnmiSurfaceVariable.relative_humidity_2m
        case ("prmsl", "0"):
              return KnmiSurfaceVariable.pressure_msl
        case ("clct", "0"):
              return KnmiSurfaceVariable.cloud_cover
        case ("grad", "0"):
            return KnmiSurfaceVariable.shortwave_radiation
        case ("tcc", "0"):
            return KnmiSurfaceVariable.cloud_cover
        case ("lcc", "0"):
            return KnmiSurfaceVariable.cloud_cover_low
        case ("mcc", "0"):
            return KnmiSurfaceVariable.cloud_cover_mid
        case ("hcc", "0"):
            return KnmiSurfaceVariable.cloud_cover_high
        case ("tsnowp", "0"):
            return KnmiSurfaceVariable.snowfall_water_equivalent
        default: return nil
        }
    }
}
