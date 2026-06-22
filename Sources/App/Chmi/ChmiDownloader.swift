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

    /// Surface parameters shared by both domains. Wind gusts are handled separately (U/V components for Lambert).
    static let surfaceParameters: [ChmiParameter] = [
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

    /// Pressure levels available in the Lambert 2.3km model.
    static let pressureLevels = [100, 150, 200, 250, 275, 300, 350, 400, 450, 500, 600, 700, 800, 850, 925, 950, 1000]

    /// Generate pressure level parameters for the Lambert 2.3km model.
    /// TEMPERATUR and VITESSE_VE are adjacent per level so the temperature
    /// cache is consumed within the same level iteration.
    static let lambert23kmPressureParameters: [ChmiParameter] = {
        var params: [ChmiParameter] = []
        for level in pressureLevels {
            let code = levelCode(for: level)
            params.append(.init(token: "P\(code)TEMPERATUR", variable: .pressure(.init(variable: .temperature, level: level)), multiplyAdd: (1, -273.15), isAccumulated: false))
            params.append(.init(token: "P\(code)VITESSE_VE", variable: .pressure(.init(variable: .vertical_velocity, level: level)), multiplyAdd: nil, isAccumulated: false))
            params.append(.init(token: "P\(code)GEOPOTENTI", variable: .pressure(.init(variable: .geopotential_height, level: level)), multiplyAdd: (1 / 9.80665, 0), isAccumulated: false))
            params.append(.init(token: "P\(code)HUMI_RELAT", variable: .pressure(.init(variable: .relative_humidity, level: level)), multiplyAdd: (100, 0), isAccumulated: false))
            params.append(.init(token: "P\(code)WIND_U_COM", variable: .pressure(.init(variable: .wind_u_component, level: level)), multiplyAdd: nil, isAccumulated: false))
            params.append(.init(token: "P\(code)WIND_V_COM", variable: .pressure(.init(variable: .wind_v_component, level: level)), multiplyAdd: nil, isAccumulated: false))
        }
        return params
    }()

    static func levelCode(for pressureLevel: Int) -> String {
        return String(format: "%05d", (pressureLevel * 100) % 100000)
    }

    static func parameters(for domain: ChmiDomain) -> [ChmiParameter] {
        switch domain {
        case .aladin_cz_1km:
            return Self.surfaceParameters
        case .aladin_lambert_2_3km:
            // For Lambert, gusts are read as U/V components and combined separately.
            // Filter out CLSRAFAL_MOD_XFU to avoid double-processing.
            return Self.surfaceParameters.filter { $0.variable != .surface(.wind_gusts_10m) } + Self.lambert23kmPressureParameters
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

    /// Download + decode + convert units + de-accumulate a single parameter.
    private func readAndDecode(parameter: ChmiParameter, domain: ChmiDomain, run: Timestamp, nx: Int, ny: Int, nTime: Int, curl: Curl, logger: Logger) async throws -> Array2DFastSpace {
        logger.info("Reading \(parameter.variable)")
        let raw = try await readGribFile(domain: domain, run: run, token: parameter.token, nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)
        var spatial = Array2DFastSpace(data: raw, nLocations: nx * ny, nTime: nTime)
        if let fma = parameter.multiplyAdd {
            spatial.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
        }
        if parameter.isAccumulated {
            spatial.data.deaccumulateOverTimeSpatial(nTime: nTime)
        }
        return spatial
    }

    /// Write processed data to the output store.
    private func writeParameter(parameter: ChmiParameter, spatial: Array2DFastSpace, nx: Int, ny: Int, nTime: Int, run: Timestamp, writer: OmSpatialMultistepWriter) async throws {
        for t in 0..<nTime {
            let slice = Array(spatial[t, 0..<nx * ny])
            try await writer.write(time: run.add(hours: t), member: 0, variable: parameter.variable, data: slice)
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
        }

        var temperatureCache: (level: Int, data: [Float])?

        for parameter in Self.parameters(for: domain) {
            if let onlyVariables, !onlyVariables.contains(parameter.variable) {
                continue
            }

            let raw = try await readAndDecode(parameter: parameter, domain: domain, run: run, nx: nx, ny: ny, nTime: nTime, curl: curl, logger: logger)

            let spatial: Array2DFastSpace

            if case .pressure(let pv) = parameter.variable, pv.variable == .temperature {
                temperatureCache = (pv.level, raw.data)
                spatial = consume raw
            } else if case .pressure(let pv) = parameter.variable, pv.variable == .vertical_velocity {
                guard let temperature = temperatureCache, temperature.level == pv.level else {
                    logger.warning("No cached temperature for vertical velocity at \(pv.level) hPa")
                    continue
                }
                logger.info("Processing vertical velocity at \(pv.level) hPa")
                spatial = Array2DFastSpace(data: Meteorology.verticalVelocityPressureToGeometric(omega: raw.data, temperature: temperature.data, pressureLevel: Float(pv.level)), nLocations: nLocations, nTime: nTime)
                temperatureCache = nil
            } else {
                spatial = consume raw
            }

            try await writeParameter(parameter: parameter, spatial: spatial, nx: nx, ny: ny, nTime: nTime, run: run, writer: writer)
        }

        await curl.printStatistics()
        return try await writer.finalise(application: application, completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }
}
