import Foundation
import Vapor
import OmFileFormat
@preconcurrency import SwiftEccodes

/// Download ČHMÚ ALADIN models.
///
/// Unlike most GRIB sources, ČHMÚ publishes ONE bzip2-compressed GRIB1 file per
/// parameter, each containing every forecast timestep for that single variable:
///   https://opendata.chmi.cz/meteorology/weather/nwp_aladin/{domain}/{HH}/{prefix}_{YYYYMMDDHH}_{TOKEN}.grb.bz2
///
/// Accumulated fields (precipitation, radiation, sunshine) are accumulated from run
/// start and are de-accumulated to hourly values here.
struct ChmiDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "only-variables")
        var onlyVariables: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download ČHMÚ ALADIN Czech model"
    }

    /// One parameter file = one variable, all timesteps.
    struct ChmiParameter {
        let token: String
        let variable: ChmiVariable
        let multiplyAdd: (multiply: Float, add: Float)?
        let isAccumulated: Bool
    }

    /// CZ_1km surface parameters.
    static let cz1kmParameters: [ChmiParameter] = [
        .init(token: "CLSTEMPERATURE", variable: .surface(.temperature_2m), multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "SURFTEMPERATURE", variable: .surface(.surface_temperature), multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "CLSDEW_P_TEMPER", variable: .surface(.dew_point_2m), multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "CLSHUMI_RELATIVE", variable: .surface(.relative_humidity_2m), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "CLSWIND_SPEED", variable: .surface(.wind_speed_10m), multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLSWIND_DIREC", variable: .surface(.wind_direction_10m), multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLSRAFAL_MOD_XFU", variable: .surface(.wind_gusts_10m), multiplyAdd: nil, isAccumulated: false),
        .init(token: "MSLPRESSURE", variable: .surface(.pressure_msl), multiplyAdd: (1.0 / 100.0, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_TOTALE", variable: .surface(.cloud_cover), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_BASSE", variable: .surface(.cloud_cover_low), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_MOYENN", variable: .surface(.cloud_cover_mid), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_HAUTE", variable: .surface(.cloud_cover_high), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFPREC_TOTAL", variable: .surface(.precipitation), multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFRAINFALL", variable: .surface(.rain), multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFSNOWFALL", variable: .surface(.snowfall_water_equivalent), multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFRESERV_NEIGE", variable: .surface(.snow_depth_water_equivalent), multiplyAdd: nil, isAccumulated: false),
        .init(token: "SURFRF_SHORT_DO", variable: .surface(.shortwave_radiation), multiplyAdd: (1.0 / 3600.0, 0), isAccumulated: true),
        .init(token: "SURF_RAYT_DIR", variable: .surface(.direct_radiation), multiplyAdd: (1.0 / 3600.0, 0), isAccumulated: true),
        .init(token: "SURFCAPE_POS_F00", variable: .surface(.cape), multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLS_VISICLD", variable: .surface(.visibility), multiplyAdd: nil, isAccumulated: false),
        .init(token: "SUNSHINE_DUR", variable: .surface(.sunshine_duration), multiplyAdd: nil, isAccumulated: true),
    ]

    /// Lambert 2.3km surface parameters. Gusts are handled separately (U/V components combined into speed).
    static let lambert23kmSurfaceParameters: [ChmiParameter] = [
        .init(token: "CLSTEMPERATURE", variable: .surface(.temperature_2m), multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "SURFTEMPERATURE", variable: .surface(.surface_temperature), multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "CLSDEW_P_TEMPER", variable: .surface(.dew_point_2m), multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "CLSHUMI_RELATIVE", variable: .surface(.relative_humidity_2m), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "CLSWIND_SPEED", variable: .surface(.wind_speed_10m), multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLSWIND_DIREC", variable: .surface(.wind_direction_10m), multiplyAdd: nil, isAccumulated: false),
        .init(token: "MSLPRESSURE", variable: .surface(.pressure_msl), multiplyAdd: (1.0 / 100.0, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_TOTALE", variable: .surface(.cloud_cover), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_BASSE", variable: .surface(.cloud_cover_low), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_MOYENN", variable: .surface(.cloud_cover_mid), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_HAUTE", variable: .surface(.cloud_cover_high), multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFPREC_TOTAL", variable: .surface(.precipitation), multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFRAINFALL", variable: .surface(.rain), multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFSNOWFALL", variable: .surface(.snowfall_water_equivalent), multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFRESERV_NEIGE", variable: .surface(.snow_depth_water_equivalent), multiplyAdd: nil, isAccumulated: false),
        .init(token: "SURFRF_SHORT_DO", variable: .surface(.shortwave_radiation), multiplyAdd: (1.0 / 3600.0, 0), isAccumulated: true),
        .init(token: "SURF_RAYT_DIR", variable: .surface(.direct_radiation), multiplyAdd: (1.0 / 3600.0, 0), isAccumulated: true),
        .init(token: "SURFCAPE_POS_F00", variable: .surface(.cape), multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLS_VISICLD", variable: .surface(.visibility), multiplyAdd: nil, isAccumulated: false),
        .init(token: "SUNSHINE_DUR", variable: .surface(.sunshine_duration), multiplyAdd: nil, isAccumulated: true),
    ]

    /// Pressure levels available in the Lambert 2.3km model.
    static let pressureLevels = [100, 150, 200, 250, 275, 300, 350, 400, 450, 500, 600, 700, 800, 850, 925, 950, 1000]

    /// Generate pressure level parameters for the Lambert 2.3km model.
    static let lambert23kmPressureParameters: [ChmiParameter] = {
        var params: [ChmiParameter] = []
        for level in pressureLevels {
            let code = levelCode(for: level)
            params.append(.init(token: "P\(code)TEMPERATUR", variable: .pressure(.init(variable: .temperature, level: level)), multiplyAdd: (1, -273.15), isAccumulated: false))
            params.append(.init(token: "P\(code)GEOPOTENTI", variable: .pressure(.init(variable: .geopotential_height, level: level)), multiplyAdd: (1 / 9.80665, 0), isAccumulated: false))
            params.append(.init(token: "P\(code)HUMI_RELAT", variable: .pressure(.init(variable: .relative_humidity, level: level)), multiplyAdd: (100, 0), isAccumulated: false))
        }
        return params
    }()

    static func levelCode(for pressureLevel: Int) -> String {
        return String(format: "%05d", (pressureLevel * 100) % 100000)
    }

    static func parameters(for domain: ChmiDomain) -> [ChmiParameter] {
        switch domain {
        case .aladin_cz_1km:
            return Self.cz1kmParameters
        case .aladin_lambert_2_3km:
            return Self.lambert23kmSurfaceParameters + Self.lambert23kmPressureParameters
        }
    }

    /// Number of forecast hours (steps 0...72 inclusive).
    static let nForecastHours = 73

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try ChmiDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let onlyVariables = try ChmiVariable.load(commaSeparatedOptional: signature.onlyVariables.map { [$0] })

        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let handles = try await download(application: context.application, domain: domain, run: run, onlyVariables: onlyVariables, uploadS3Bucket: signature.uploadS3Bucket)
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(application: context.application, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)

        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Base URL for a run
    private func baseUrl(domain: ChmiDomain, run: Timestamp) -> String {
        let hourStr = run.hour.zeroPadded(len: 2)
        let dir: String
        switch domain {
        case .aladin_cz_1km:
            dir = "CZ_1km"
        case .aladin_lambert_2_3km:
            dir = "Lambert_2.3km"
        }
        return "https://opendata.chmi.cz/meteorology/weather/nwp_aladin/\(dir)/\(hourStr)/"
    }

    private func fileUrl(domain: ChmiDomain, run: Timestamp, token: String) -> String {
        let prefix: String
        switch domain {
        case .aladin_cz_1km:
            prefix = "ALADCZ1K4opendata"
        case .aladin_lambert_2_3km:
            prefix = "ALADLAMB4opendata"
        }
        return "\(baseUrl(domain: domain, run: run))\(prefix)_\(run.format_YYYYMMddHH)_\(token).grb.bz2"
    }

    /// Static geopotential field -> elevation in metre. Single GRIB message.
    /// TODO: This currently does not encode sea-points as -999
    /// -> There is a separate GRIB land-sea mask variable `SURFIND_TERREMER` (land=1, sea=0) which should be processed as well!
    func downloadElevation(application: Application, domain: ChmiDomain, run: Timestamp, curl: Curl) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()
        logger.info("Downloading elevation from geopotential")

        let nx = domain.grid.nx
        let ny = domain.grid.ny
        let url = fileUrl(domain: domain, run: run, token: "SURFGEOPOTENTIEL")

        let elevation: [Float]? = try await curl.withGribStream(url: url, bzip2Decode: true) { stream in
            var result: [Float]?
            for try await message in stream {
                var grib2d = GribArray2D(nx: nx, ny: ny)
                try grib2d.load(message: message)
                grib2d.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0) // m²/s² -> m
                result = grib2d.array.data
            }
            return result
        }
        guard let elevation else {
            fatalError("Could not read geopotential for elevation")
        }
        logger.info("Writing elevation file (\(elevation.count) grid points)")
        try elevation.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid)
    }

    /// Read a single GRIB file containing all timesteps into a time-major buffer.
    private func readGribFile(domain: ChmiDomain, run: Timestamp, token: String, nx: Int, ny: Int, nTime: Int, curl: Curl, logger: Logger) async throws -> [Float] {
        let url = fileUrl(domain: domain, run: run, token: token)
        return try await curl.withGribStream(url: url, bzip2Decode: true) { stream in
            var buffer = [Float](repeating: .nan, count: nx * ny * nTime)
            for try await message in stream {
                guard let validityTime = message.get(attribute: "validityTime"),
                      let validityDate = message.get(attribute: "validityDate"),
                      let validityTimeInt = Int(validityTime) else {
                    logger.warning("Could not read validity for \(token)")
                    continue
                }
                let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(validityTimeInt.zeroPadded(len: 4))")
                let step = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
                guard step >= 0, step < nTime else {
                    continue
                }
                var grib2d = GribArray2D(nx: nx, ny: ny)
                try grib2d.load(message: message)
                for i in 0..<nx * ny {
                    buffer[step * nx * ny + i] = grib2d.array.data[i]
                }
            }
            return buffer
        }
    }

    /// Process a single parameter: download, decode, convert units, de-accumulate, write.
    private func processParameter(parameter: ChmiParameter, domain: ChmiDomain, run: Timestamp, nx: Int, ny: Int, nTime: Int, curl: Curl, writer: OmSpatialMultistepWriter, logger: Logger) async throws {
        logger.info("Processing \(parameter.variable)")
        let raw = try await readGribFile(domain: domain, run: run, token: parameter.token, nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)

        var spatial = Array2DFastSpace(data: raw, nLocations: nx * ny, nTime: nTime)
        if let fma = parameter.multiplyAdd {
            spatial.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
        }
        if parameter.isAccumulated {
            spatial.data.deaccumulateOverTimeSpatial(nTime: nTime)
        }

        for t in 0..<nTime {
            let slice = Array(spatial[t, 0..<nx * ny])
            try await writer.write(time: run.add(hours: t), member: 0, variable: parameter.variable, data: slice)
        }
    }

    /// Process pressure level wind for Lambert 2.3km: download U/V components and combine into speed/direction
    /// with true north correction.
    private func processPressureWind(domain: ChmiDomain, run: Timestamp, nx: Int, ny: Int, nTime: Int, curl: Curl, writer: OmSpatialMultistepWriter, logger: Logger) async throws {
        guard case .aladin_lambert_2_3km = domain else { return }

        let trueNorth: [Float]? = (domain.grid as? ProjectionGrid<LambertConformalConicProjection>)?.getTrueNorthDirection()

        for level in Self.pressureLevels {
            let code = Self.levelCode(for: level)
            let uToken = "P\(code)WIND_U_COM"
            let vToken = "P\(code)WIND_V_COM"

            logger.info("Processing pressure wind at \(level) hPa")
            let uData = try await readGribFile(domain: domain, run: run, token: uToken, nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)
            let vData = try await readGribFile(domain: domain, run: run, token: vToken, nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)

            for t in 0..<nTime {
                var speed = [Float](repeating: .nan, count: nx * ny)
                var direction = [Float](repeating: .nan, count: nx * ny)
                let base = t * nx * ny

                if let trueNorth {
                    for i in 0..<nx * ny {
                        let u = uData[base + i]
                        let v = vData[base + i]
                        let rot = trueNorth[i].degreesToRadians
                        let uTrue = u * cos(rot) - v * sin(rot)
                        let vTrue = u * sin(rot) + v * cos(rot)
                        speed[i] = sqrt(uTrue * uTrue + vTrue * vTrue)
                        direction[i] = (atan2(-uTrue, -vTrue).radiansToDegrees + 180).truncatingRemainder(dividingBy: 360)
                    }
                } else {
                    for i in 0..<nx * ny {
                        let u = uData[base + i]
                        let v = vData[base + i]
                        speed[i] = sqrt(u * u + v * v)
                        direction[i] = (atan2(-u, -v).radiansToDegrees + 180).truncatingRemainder(dividingBy: 360)
                    }
                }

                let tstamp = run.add(hours: t)
                try await writer.write(time: tstamp, member: 0, variable: ChmiVariable.pressure(ChmiPressureVariable(variable: .wind_speed, level: level)), data: speed)
                try await writer.write(time: tstamp, member: 0, variable: ChmiVariable.pressure(ChmiPressureVariable(variable: .wind_direction, level: level)), data: direction)
            }
        }
    }

    /// Process pressure level vertical velocity: convert VITESSE_VE (Pa/s) → m/s
    /// using temperature at the same level for the hydrostatic conversion.
    private func processPressureVerticalVelocity(domain: ChmiDomain, run: Timestamp, nx: Int, ny: Int, nTime: Int, curl: Curl, writer: OmSpatialMultistepWriter, logger: Logger) async throws {
        guard case .aladin_lambert_2_3km = domain else { return }

        for level in Self.pressureLevels {
            let code = Self.levelCode(for: level)
            let vvToken = "P\(code)VITESSE_VE"
            let tempToken = "P\(code)TEMPERATUR"

            logger.info("Processing vertical velocity at \(level) hPa")
            let omega = try await readGribFile(domain: domain, run: run, token: vvToken, nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)
            let temperature = try await readGribFile(domain: domain, run: run, token: tempToken, nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)

            for t in 0..<nTime {
                let base = t * nx * ny
                let omegaSlice = Array(omega[base..<base + nx * ny])
                let tempSlice = Array(temperature[base..<base + nx * ny])
                let tempCelsius = tempSlice.map { $0 - 273.15 }
                let w = Meteorology.verticalVelocityPressureToGeometric(omega: omegaSlice, temperature: tempCelsius, pressureLevel: Float(level))

                try await writer.write(time: run.add(hours: t), member: 0, variable: ChmiVariable.pressure(ChmiPressureVariable(variable: .vertical_velocity, level: level)), data: w)
            }
        }
    }

    func download(application: Application, domain: ChmiDomain, run: Timestamp, onlyVariables: [ChmiVariable]?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 4
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer { Process.alarm(seconds: 0) }

        let nx = domain.grid.nx
        let ny = domain.grid.ny
        let nLocations = nx * ny
        let nTime = Self.nForecastHours

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)

        try await downloadElevation(application: application, domain: domain, run: run, curl: curl)

        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: true, realm: nil, logger: logger)

        // For Lambert 2.3km, surface gusts are provided as U/V components and must be combined into speed.
        if case .aladin_lambert_2_3km = domain {
            if onlyVariables?.contains(ChmiVariable.surface(.wind_gusts_10m)) ?? true {
                logger.info("Processing wind_gusts_10m (U/V combination)")
                let uData = try await readGribFile(domain: domain, run: run, token: "CLSU_RAF_MOD_XFU", nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)
                let vData = try await readGribFile(domain: domain, run: run, token: "CLSV_RAF_MOD_XFU", nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)

                var spatial = Array2DFastSpace(data: [Float](repeating: .nan, count: nLocations * nTime), nLocations: nLocations, nTime: nTime)
                for i in 0..<nLocations * nTime {
                    spatial.data[i] = sqrt(uData[i] * uData[i] + vData[i] * vData[i])
                }

                for t in 0..<nTime {
                    let slice = Array(spatial[t, 0..<nLocations])
                    try await writer.write(time: run.add(hours: t), member: 0, variable: ChmiVariable.surface(.wind_gusts_10m), data: slice)
                }
            }

            // Pressure level wind (U/V components → speed + direction with true north correction)
            try await processPressureWind(domain: domain, run: run, nx: nx, ny: ny, nTime: nTime, curl: curl, writer: writer, logger: logger)

            // Pressure level vertical velocity (Pa/s → m/s using temperature)
            try await processPressureVerticalVelocity(domain: domain, run: run, nx: nx, ny: ny, nTime: nTime, curl: curl, writer: writer, logger: logger)
        }

        for parameter in Self.parameters(for: domain) {
            // Skip U/V wind tokens — they are handled by processPressureWind
            if case .pressure(let pv) = parameter.variable, pv.variable == .wind_u_component || pv.variable == .wind_v_component {
                continue
            }
            // Skip vertical velocity tokens — handled by processPressureVerticalVelocity
            if case .pressure(let pv) = parameter.variable, pv.variable == .vertical_velocity {
                continue
            }
            if let onlyVariables, !onlyVariables.contains(parameter.variable) {
                continue
            }
            try await processParameter(parameter: parameter, domain: domain, run: run, nx: nx, ny: ny, nTime: nTime, curl: curl, writer: writer, logger: logger)
        }

        await curl.printStatistics()
        return try await writer.finalise(application: application, completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }
}
