import Foundation
import Vapor
import OmFileFormat
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

        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Temporarily keep those varibles to derive others
    enum DmiVariableTemporary: String {
        case ugst
        case vgst
        case u50
        case v50
        case u100
        case v100
        case u150
        case v150
        case u250
        case v250
        case u350
        case v350
        case u450
        case v450
        case landmask
        case elevation

        static func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> Self? {
            if parameterName == "Land cover (0 = sea, 1 = land)" {
                return .landmask
            }
            switch (shortName, typeOfLevel, levelStr) {
            case ("ugst", "heightAboveGround", "10"):
                return .ugst
            case ("vgst", "heightAboveGround", "10"):
                return .vgst
            case ("u", "heightAboveGround", "50"):
                return .u50
            case ("v", "heightAboveGround", "50"):
                return .v50
            case ("100u", "heightAboveGround", "100"):
                return .u100
            case ("100v", "heightAboveGround", "100"):
                return .v100
            case ("u", "heightAboveGround", "150"):
                return .u150
            case ("v", "heightAboveGround", "150"):
                return .v150
            case ("u", "heightAboveGround", "250"):
                return .u250
            case ("v", "heightAboveGround", "250"):
                return .v250
            case ("u", "heightAboveGround", "350"):
                return .u350
            case ("v", "heightAboveGround", "350"):
                return .v350
            case ("u", "heightAboveGround", "450"):
                return .u450
            case ("v", "heightAboveGround", "450"):
                return .v450
            case ("z", "heightAboveGround", "0"):
                return .elevation
            default:
                return nil
            }
        }
    }

    /**
     Download GRIB file for each timestamp, decode, generate some derived variables.
     Important: Wind U/V components are defined on a Lambert CC projection. They need to be corrected for true north.
     */
    func download(application: Application, domain: DmiDomain, run: Timestamp, concurrent: Int, maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        /*guard let apikey = Environment.get("DMI_API_KEY")?.split(separator: ",").map(String.init) else {
            fatalError("Please specify environment variable 'DMI_API_KEY'")
        }*/
        let logger = application.logger
        let deadLineHours = Double(4)
        Process.alarm(seconds: Int(deadLineHours + 0.5) * 3600)
        defer { Process.alarm(seconds: 0) }

        guard let grid = domain.grid as? ProjectionGrid<LambertConformalConicProjection> else {
            fatalError("Wrong grid")
        }

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2 * 60))

        let dataset: String
        switch domain {
        case .harmonie_arome_europe:
            dataset = "HARMONIE_DINI_SF"
        }

        let generateElevationFile = !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath())
        // Important: Wind U/V components are defined on a Lambert CC projection. They need to be corrected for true north.
        let trueNorth = grid.getTrueNorthDirection()
        var previous = GribDeaverager()
        let timerange = TimerangeDt(start: run, nTime: maxForecastHour ?? 60, dtSeconds: 3600)

        let handles = try await timerange.asyncFlatMap { t -> [GenericVariableHandle] in
            // https://dmigw.govcloud.dk/v1/forecastdata/collections/harmonie_dini_sf/items/HARMONIE_DINI_SF_2025-01-15T090000Z_2025-01-17T210000Z.grib -> assets
            // https://download.dmi.dk/public/opendata/HARMONIE_DINI_SF_2025-01-15T090000Z_2025-01-17T210000Z.grib
            // let url = "https://dmigw.govcloud.dk/v1/forecastdata/download/\(dataset)_\(run.iso8601_YYYY_MM_dd_HHmm)00Z_\(t.iso8601_YYYY_MM_dd_HHmm)00Z.grib"
            // let url = "https://download.dmi.dk/public/opendata/\(dataset)_\(run.iso8601_YYYY_MM_dd_HHmm)00Z_\(t.iso8601_YYYY_MM_dd_HHmm)00Z.grib"
            let url = "https://dmi-opendata.s3-eu-north-1.amazonaws.com/forecastdata/\(dataset)/\(dataset)_\(run.iso8601_YYYY_MM_dd_HHmm)00Z_\(t.iso8601_YYYY_MM_dd_HHmm)00Z.grib"

            return try await curl.withGribStream(url: url, bzip2Decode: false/*, headers: [("X-Gravitee-Api-Key", apikey.randomElement() ?? "")]*/) { stream in
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
                          // let parameterCategory = message.getLong(attribute: "parameterCategory"),
                          // let parameterNumber = message.getLong(attribute: "parameterNumber")
                    else {
                        logger.warning("could not get attributes")
                        return nil
                    }
                    let member = message.getLong(attribute: "perturbationNumber") ?? 0
                    let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")

                    if let temporary = DmiVariableTemporary.getVariable(shortName: shortName, levelStr: levelStr, parameterName: parameterName, typeOfLevel: typeOfLevel) {
                        if !generateElevationFile && [DmiVariableTemporary.elevation, .landmask].contains(temporary) {
                            return nil
                        }
                        logger.info("Keep in memory: \(shortName) level=\(levelStr) [\(typeOfLevel)] \(stepRange) \(stepType) '\(parameterName)' \(parameterUnits)  id=\(paramId) unit=\(unit) member=\(member)")
                        var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                        try grib2d.load(message: message)
                        switch unit {
                        case "m**2 s**-2": // gph to metre
                            grib2d.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0)
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
                    logger.info("Processing \(timestamp.format_YYYYMMddHH) \(variable) [\(unit)]")

                    if stepType == "accum" && timestamp == run {
                        return nil // skip precipitation at timestep 0
                    }

                    let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
                    var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
                    try grib2d.load(message: message)

                    // try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                    // fatalError()

                    if let variable = variable as? DmiSurfaceVariable {
                        switch variable {
                        case .shortwave_radiation, .direct_radiation:
                            // GRIB unit says W/m2, but it's J/s
                            grib2d.array.data.multiplyAdd(multiply: 1 / 3600, add: 0)
                        case .cloud_top, .cloud_base:
                            // Cloud base and top mark "no clouds" as NaN
                            // Set it to 0 to work with conversion
                            for i in grib2d.array.data.indices {
                                if grib2d.array.data[i].isNaN {
                                    grib2d.array.data[i] = 0
                                }
                            }
                        default:
                            break
                        }
                    }

                    switch unit {
                    case "K":
                        grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                    case "m**2 s**-2": // gph to metre
                        grib2d.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0)
                    case "(0 - 1)", "(0-1)":
                        if variable.unit == .percentage {
                            grib2d.array.data.multiplyAdd(multiply: 100, add: 0)
                        }
                    case "Pa":
                        grib2d.array.data.multiplyAdd(multiply: 1 / 100, add: 0) // to hPa
                    // case "J m**-2":
                        // grib2d.array.data.multiplyAdd(multiply: 1/3600, add: 0) // to W/m2
                    default:
                        break
                    }

                    // Deaccumulate precipitation
                    guard await previousScoped.deaccumulateIfRequired(variable: "\(variable)", member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                        return nil
                    }

                    let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    return GenericVariableHandle(variable: variable, time: timestamp, member: member, fn: fn)
                }.collect().compactMap({ $0 })

                previous = previousScoped

                logger.info("Calculating wind speed and direction from U/V components and correcting for true north")
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
                let windHandles = [
                    try await inMemory.calculateWindSpeed(u: .u50, v: .v50, outSpeedVariable: DmiSurfaceVariable.wind_speed_50m, outDirectionVariable: DmiSurfaceVariable.wind_direction_50m, writer: writer, trueNorth: trueNorth),
                    try await inMemory.calculateWindSpeed(u: .u100, v: .v100, outSpeedVariable: DmiSurfaceVariable.wind_speed_100m, outDirectionVariable: DmiSurfaceVariable.wind_direction_100m, writer: writer, trueNorth: trueNorth),
                    try await inMemory.calculateWindSpeed(u: .u150, v: .v150, outSpeedVariable: DmiSurfaceVariable.wind_speed_150m, outDirectionVariable: DmiSurfaceVariable.wind_direction_150m, writer: writer, trueNorth: trueNorth),
                    try await inMemory.calculateWindSpeed(u: .u250, v: .v250, outSpeedVariable: DmiSurfaceVariable.wind_speed_250m, outDirectionVariable: DmiSurfaceVariable.wind_direction_250m, writer: writer, trueNorth: trueNorth),
                    try await inMemory.calculateWindSpeed(u: .u350, v: .v350, outSpeedVariable: DmiSurfaceVariable.wind_speed_350m, outDirectionVariable: DmiSurfaceVariable.wind_direction_350m, writer: writer, trueNorth: trueNorth),
                    try await inMemory.calculateWindSpeed(u: .u450, v: .v450, outSpeedVariable: DmiSurfaceVariable.wind_speed_450m, outDirectionVariable: DmiSurfaceVariable.wind_direction_450m, writer: writer, trueNorth: trueNorth)
                ].flatMap({ $0 })

                if generateElevationFile {
                    try await inMemory.generateElevationFile(elevation: .elevation, landmask: .landmask, domain: domain)
                }
                return h + windHandles
            }
        }

        await curl.printStatistics()
        return handles
    }

    /// https://opendatadocs.dmi.govcloud.dk/Data/Forecast_Data_Weather_Model_HARMONIE_DINI_EDR
    func getVariable(shortName: String, levelStr: String, parameterName: String, typeOfLevel: String) -> GenericVariable? {
        // if parameterName == "Direct solar exposure" {
            // This contains DNI
            // return DmiSurfaceVariable.shortwave_radiation
        // }

        switch parameterName {
        case "Cloud base":
            return DmiSurfaceVariable.cloud_base
        case "Cloud top":
            return DmiSurfaceVariable.cloud_top
        default:
            break
        }

        // Note: Pressure level wind requires U/V projection direction correction
        /*if typeOfLevel == "isobaricInhPa" {
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
        }*/

        switch (shortName, typeOfLevel, levelStr) {
        case ("tp", "surface", "0"):
            return DmiSurfaceVariable.precipitation
        case ("vis", "heightAboveGround", "0"):
            return DmiSurfaceVariable.visibility
        case ("t", "heightAboveGround", "0"):
            return DmiSurfaceVariable.surface_temperature
        case ("2t", "heightAboveGround", "2"):
            return DmiSurfaceVariable.temperature_2m // ok
        case ("10fg", "heightAboveGround", "10"):
            return DmiSurfaceVariable.wind_gusts_10m // ok
        case ("10wdir", "heightAboveGround", "10"): // testing wdir
            return DmiSurfaceVariable.wind_direction_10m // ok
        case ("10si", "heightAboveGround", "10"): // testing wdir
            return DmiSurfaceVariable.wind_speed_10m // ok
        case ("2r", "heightAboveGround", "2"):
            return DmiSurfaceVariable.relative_humidity_2m // ok
        case ("pres", "heightAboveSea", "0"):
            return DmiSurfaceVariable.pressure_msl // ok
        case ("t", "heightAboveGround", "50"):
            return DmiSurfaceVariable.temperature_50m // ok
        case ("t", "heightAboveGround", "100"):
            return DmiSurfaceVariable.temperature_100m // ok
        case ("t", "heightAboveGround", "150"):
            return DmiSurfaceVariable.temperature_150m
        case ("t", "heightAboveGround", "250"):
            return DmiSurfaceVariable.temperature_250m
        // case ("sd", "heightAboveGround", "0"):
            // return DmiSurfaceVariable.snow_depth_water_equivalent // ok
        case ("grad", "heightAboveGround", "0"):
            return DmiSurfaceVariable.shortwave_radiation // ok
        case ("dswrf", "heightAboveGround", "0"):
            return DmiSurfaceVariable.direct_radiation
        case ("h", "isothermZero", "0"):
            return DmiSurfaceVariable.freezing_level_height
        case ("cape", "entireAtmosphere", "0"):
            return DmiSurfaceVariable.cape
        case ("cin", "entireAtmosphere", "0"):
            return DmiSurfaceVariable.convective_inhibition
        case ("cc", "heightAboveGround", "2"):
            return DmiSurfaceVariable.cloud_cover_2m
        case ("cc", "heightAboveGround", "0"):
            return DmiSurfaceVariable.cloud_cover
        case ("lcc", "heightAboveGround", "0"):
            return DmiSurfaceVariable.cloud_cover_low // ok
        case ("mcc", "heightAboveGround", "0"):
            return DmiSurfaceVariable.cloud_cover_mid // ok
        case ("hcc", "heightAboveGround", "0"):
            return DmiSurfaceVariable.cloud_cover_high // ok
        default:
            break
        }

        switch (shortName, levelStr) {
        case ("rain", "0"):
            return DmiSurfaceVariable.precipitation
        case ("tsrwe", "0"):
            return DmiSurfaceVariable.snowfall_water_equivalent // ok
        default: return nil
        }
    }
}
