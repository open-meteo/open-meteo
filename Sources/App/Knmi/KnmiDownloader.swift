import Foundation
import Vapor
import OmFileFormat
@preconcurrency import SwiftEccodes

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

        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket)

        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Temporarily keep those varibles to derive others
    enum KnmiVariableTemporary: String {
        case landmask
        case elevation

        static func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String, indicatorOfParameter: Int) -> Self? {
            switch (indicatorOfParameter, typeOfLevel, levelStr) {
            case (6, "heightAboveGround", "0"):
                return .elevation
            case (81, "heightAboveGround", "0"):
                return .landmask
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
    func download(application: Application, domain: KnmiDomain, run: Timestamp, concurrent: Int, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        guard let apikey = Environment.get("KNMI_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'KNMI_API_KEY'")
        }
        let logger = application.logger
        let deadLineHours = Double(2)
        Process.alarm(seconds: Int(deadLineHours + 0.5) * 3600)
        defer { Process.alarm(seconds: 0) }

        let grid = domain.grid
        let nx = grid.nx
        let ny = grid.ny

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2 * 60))

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
            let deaverager = GribDeaverager()
            let inMemory = VariablePerMemberStorage<KnmiVariableTemporary>()
            /// Single GRIB files contains multiple time-steps in mixed order
            let inMemoryAccumulated = VariablePerMemberStorage<KnmiSurfaceVariable>()
            let windSpeedCalculator = WindSpeedCalculator<KnmiSurfaceVariable>(trueNorth: trueNorth)
            let windSpeedCalculatorPressure = WindSpeedCalculator<KnmiPressureVariable>(trueNorth: trueNorth)
            let writerMultistep = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: true, realm: nil)

            // process sequentialy, as precipitation need to be in order for deaveraging
            try await stream.foreachConcurrent(nConcurrent: concurrent) { message in
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
                      let paramId = message.getLong(attribute: "paramId"),
                      /// GRIB1 paramId
                      let indicatorOfParameter = message.getLong(attribute: "indicatorOfParameter")
                      // let parameterCategory = message.getLong(attribute: "parameterCategory"),
                      // let parameterNumber = message.getLong(attribute: "parameterNumber")
                else {
                    logger.warning("could not get attributes")
                    return
                }
                /// NOTE: KNMI does not seem to set this field. Only way to decode member number would be file name which is not accessible while streaming
                let member = message.getLong(attribute: "perturbationNumber") ?? 0
                let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
                let writer = try await writerMultistep.getWriter(time: timestamp)

                /// NL nest has 100,200,300 hPa levels.... not sure what the point is with those levels
                if domain == .harmonie_arome_netherlands && typeOfLevel == "isobaricInhPa" {
                    return
                }

                if [181, 184].contains(indicatorOfParameter) && stepType == "instant" {
                    // Rain and snow snowfall are twice inside the GRIB file.
                    // One instant and accumulation. Make sure to only use accumulation
                    return
                }
                
                switch indicatorOfParameter {
                /*case "10u":
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_speed_10m, outDirection: .wind_direction_10m, writer: writer)
                case "10v":
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_speed_10m, outDirection: .wind_direction_10m, writer: writer)
                case "100u":
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_speed_100m, outDirection: .wind_direction_100m, writer: writer)
                case "100v":
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_speed_100m, outDirection: .wind_direction_100m, writer: writer)*/
                case 162:
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_gusts_10m, outDirection: nil, writer: writer)
                case 163:
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_gusts_10m, outDirection: nil, writer: writer)
                case 33:
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    let level = Int(levelStr)!
                    if typeOfLevel == "heightAboveGround" {
                        switch level {
                        case 10:
                            return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_speed_10m, outDirection: .wind_direction_10m, writer: writer)
                        case 50:
                            return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_speed_50m, outDirection: .wind_direction_50m, writer: writer)
                        case 100:
                            return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_speed_100m, outDirection: .wind_direction_100m, writer: writer)
                        case 200:
                            return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_speed_200m, outDirection: .wind_direction_200m, writer: writer)
                        case 300:
                            return try await windSpeedCalculator.ingest(.u(array), member: member, outSpeed: .wind_speed_300m, outDirection: .wind_direction_300m, writer: writer)
                        default:
                            logger.info("Level not defined for wind speed: \(levelStr)")
                        }
                    } else {
                        return try await windSpeedCalculatorPressure.ingest(.u(array), member: member, outSpeed: .init(variable: .wind_speed, level: level), outDirection: .init(variable: .wind_direction, level: level), writer: writer)
                    }
                case 34:
                    let array = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                    let level = Int(levelStr)!
                    if typeOfLevel == "heightAboveGround" {
                        switch level {
                        case 10:
                            return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_speed_10m, outDirection: .wind_direction_10m, writer: writer)
                        case 50:
                            return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_speed_50m, outDirection: .wind_direction_50m, writer: writer)
                        case 100:
                            return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_speed_100m, outDirection: .wind_direction_100m, writer: writer)
                        case 200:
                            return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_speed_200m, outDirection: .wind_direction_200m, writer: writer)
                        case 300:
                            return try await windSpeedCalculator.ingest(.v(array), member: member, outSpeed: .wind_speed_300m, outDirection: .wind_direction_300m, writer: writer)
                        default:
                            logger.info("Level not defined for wind speed: \(levelStr)")
                        }
                    } else {
                        return try await windSpeedCalculatorPressure.ingest(.v(array), member: member, outSpeed: .init(variable: .wind_speed, level: level), outDirection: .init(variable: .wind_direction, level: level), writer: writer)
                    }
                default:
                    break
                }

                if let temporary = KnmiVariableTemporary.getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel, indicatorOfParameter: indicatorOfParameter) {
                    if !generateElevationFile && [KnmiVariableTemporary.elevation, .landmask].contains(temporary) {
                        return
                    }
                    logger.info("Keep in memory: \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member)")
                    var grib2d = GribArray2D(nx: nx, ny: ny)
                    try grib2d.load(message: message)
                    switch indicatorOfParameter {
                    case 6: // gph to metre
                        grib2d.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0)
                    default:
                        break
                    }
                    await inMemory.set(variable: temporary, timestamp: timestamp, member: member, data: grib2d.array)
                    return
                }

                guard let variable = getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel, indicatorOfParameter: indicatorOfParameter) else {
                    let table2Version = message.getLong(attribute: "table2Version") ?? 0
                    let levelType = message.get(attribute: "levelType") ?? "-"
                    let centre = message.get(attribute: "centre") ?? "-"
                    let edition = message.get(attribute: "edition") ?? "-"
                    logger.warning("Unmapped GRIB message \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member) indicatorOfParameter=\(indicatorOfParameter) table2Version=\(table2Version) levelType=\(levelType) centre=\(centre) edition=\(edition)")
                    return
                }

                if stepType == "accum" && timestamp == run {
                    return // skip precipitation at timestep 0
                }
                logger.info("Processing \(timestamp.format_YYYYMMddHH) \(variable) [\(unit)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)")

                var grib2d = GribArray2D(nx: nx, ny: ny)
                try grib2d.load(message: message)

                // try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)

                switch indicatorOfParameter {
                case 11: // temperature
                    grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                case 6: // gph to metre
                    grib2d.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0)
                case 73, 74, 75: // low/mid/high clouds (but not total!)
                    if variable.unit == .percentage {
                        grib2d.array.data.multiplyAdd(multiply: 100, add: 0)
                    }
                case 2: // pressure
                    grib2d.array.data.multiplyAdd(multiply: 1 / 100, add: 0) // to hPa
                case 117: // shortwave radiation
                    grib2d.array.data.multiplyAdd(multiply: 1 / 3600, add: 0) // to W/m2
                default:
                    break
                }
                
                if stepType == "accum", let variable: KnmiSurfaceVariable = variable as? KnmiSurfaceVariable {
                    // Collect all accumulated variables and process them as soon as they are in sequential order
                    await inMemoryAccumulated.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                    while true {
                        let step = (await deaverager.lastStep(variable, member) ?? 0) + domain.dtHours
                        let time = run.add(hours: step)
                        guard var data = await inMemoryAccumulated.remove(variable: variable, timestamp: time, member: member) else {
                            break
                        }
                        guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: "accum", stepRange: "0-\(step)", array2d: &data) else {
                            continue
                        }
                        let count = await inMemoryAccumulated.data.count
                        logger.debug("Writing accumulated variable \(variable) member \(member) unit=\(unit) timestamp \(time.format_YYYYMMddHH) backlog \(count)")
                        try await writerMultistep.write(time: time, member: member, variable: variable, data: data.data)
                    }
                    return
                }

                try await writer.write(member: member, variable: variable, data: grib2d.array.data)
            }

            if generateElevationFile {
                try await inMemory.generateElevationFile(elevation: .elevation, landmask: .landmask, domain: domain)
            }
            return try await writerMultistep.finalise(completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
        }
        await curl.printStatistics()
        return handles
    }

    func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String, indicatorOfParameter: Int) -> GenericVariable? {
        if typeOfLevel == "isobaricInhPa" {
            guard let level = Int(levelStr) else {
                fatalError("Could not parse level str \(levelStr)")
            }
            if level < 10 {
                return nil
            }
            switch indicatorOfParameter {
            case 11:
                return KnmiPressureVariable(variable: .temperature, level: level)
            /*case "u": Wind is converted in a separate step to speed and direction with true north correction
                return KnmiPressureVariable(variable: .wind_u_component, level: level)
            case "v":
                return KnmiPressureVariable(variable: .wind_v_component, level: level)*/
            case 52:
                return KnmiPressureVariable(variable: .relative_humidity, level: level)
            case 6:
                return KnmiPressureVariable(variable: .geopotential_height, level: level)
            default:
                break
            }
        }

        switch (indicatorOfParameter, typeOfLevel, levelStr) {
        case (20, "heightAboveGround", "0"):
            return KnmiSurfaceVariable.visibility
        case (11, "heightAboveGround", "0"):
            return KnmiSurfaceVariable.surface_temperature
        case (11, "heightAboveGround", "2"):
            return KnmiSurfaceVariable.temperature_2m
        case (52, "heightAboveGround", "2"):
            return KnmiSurfaceVariable.relative_humidity_2m
        case (2, "heightAboveSea", "0"):
            return KnmiSurfaceVariable.pressure_msl
        case (11, "heightAboveGround", "50"):
            return KnmiSurfaceVariable.temperature_50m
        case (11, "heightAboveGround", "100"):
            return KnmiSurfaceVariable.temperature_100m
        case (11, "heightAboveGround", "200"):
            return KnmiSurfaceVariable.temperature_200m
        case (11, "heightAboveGround", "300"):
            return KnmiSurfaceVariable.temperature_300m
        case (65, "heightAboveGround", "0"):
            return KnmiSurfaceVariable.snow_depth_water_equivalent
        default:
            break
        }

        switch (indicatorOfParameter, levelStr) {
        case (181, "0"):
            return KnmiSurfaceVariable.rain
        case (61, "0"):
            return KnmiSurfaceVariable.precipitation
        case (184, "0"):
            return KnmiSurfaceVariable.snowfall_water_equivalent
        case (11, "2"):
            return KnmiSurfaceVariable.temperature_2m
        case (52, "2"):
            return KnmiSurfaceVariable.relative_humidity_2m
        case (1, "0"):
              return KnmiSurfaceVariable.pressure_msl
        case (117, "0"):
            return KnmiSurfaceVariable.shortwave_radiation
        case (71, "0"):
            return KnmiSurfaceVariable.cloud_cover
        case (73, "0"):
            return KnmiSurfaceVariable.cloud_cover_low
        case (74, "0"):
            return KnmiSurfaceVariable.cloud_cover_mid
        case (75, "0"):
            return KnmiSurfaceVariable.cloud_cover_high
        default: return nil
        }
    }
}
