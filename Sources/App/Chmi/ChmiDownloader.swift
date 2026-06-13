import Foundation
import Vapor
import OmFileFormat
@preconcurrency import SwiftEccodes

/// Download ČHMÚ ALADIN CZ 1km model.
///
/// Unlike most GRIB sources, ČHMÚ publishes ONE bzip2-compressed GRIB1 file per
/// parameter, each containing every forecast timestep for that single variable:
///   https://opendata.chmi.cz/meteorology/weather/nwp_aladin/CZ_1km/{HH}/ALADCZ1K4opendata_{YYYYMMDDHH}_{TOKEN}.grb.bz2
///
/// Accumulated fields (precipitation, radiation, sunshine) are accumulated from run
/// start and are de-accumulated to hourly values here. The grid is a plain regular
/// lat/lon grid, so wind speed/direction are used directly with no true-north rotation.
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

    /// Mapping from the ČHMÚ file token to an Open-Meteo variable + unit conversion.
    static let parameters: [ChmiParameter] = [
        .init(token: "CLSTEMPERATURE", variable: .temperature_2m, multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "SURFTEMPERATURE", variable: .surface_temperature, multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "CLSDEW_P_TEMPER", variable: .dew_point_2m, multiplyAdd: (1, -273.15), isAccumulated: false),
        .init(token: "CLSHUMI_RELATIVE", variable: .relative_humidity_2m, multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "CLSWIND_SPEED", variable: .wind_speed_10m, multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLSWIND_DIREC", variable: .wind_direction_10m, multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLSRAFAL_MOD_XFU", variable: .wind_gusts_10m, multiplyAdd: nil, isAccumulated: false),
        .init(token: "MSLPRESSURE", variable: .pressure_msl, multiplyAdd: (1.0 / 100.0, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_TOTALE", variable: .cloud_cover, multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_BASSE", variable: .cloud_cover_low, multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_MOYENN", variable: .cloud_cover_mid, multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFNEBUL_HAUTE", variable: .cloud_cover_high, multiplyAdd: (100, 0), isAccumulated: false),
        .init(token: "SURFPREC_TOTAL", variable: .precipitation, multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFRAINFALL", variable: .rain, multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFSNOWFALL", variable: .snowfall_water_equivalent, multiplyAdd: nil, isAccumulated: true),
        .init(token: "SURFRESERV_NEIGE", variable: .snow_depth_water_equivalent, multiplyAdd: nil, isAccumulated: false),
        .init(token: "SURFRF_SHORT_DO", variable: .shortwave_radiation, multiplyAdd: (1.0 / 3600.0, 0), isAccumulated: true),
        .init(token: "SURF_RAYT_DIR", variable: .direct_radiation, multiplyAdd: (1.0 / 3600.0, 0), isAccumulated: true),
        .init(token: "SURFCAPE_POS_F00", variable: .cape, multiplyAdd: nil, isAccumulated: false),
        .init(token: "CLS_VISICLD", variable: .visibility, multiplyAdd: nil, isAccumulated: false),
        .init(token: "SUNSHINE_DUR", variable: .sunshine_duration, multiplyAdd: nil, isAccumulated: true),
    ]

    /// Number of forecast hours (steps 0...72 inclusive).
    static let nForecastHours = 73

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try ChmiDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let onlyVariables = try ChmiVariable.load(commaSeparatedOptional: signature.onlyVariables)

        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let handles = try await download(application: context.application, domain: domain, run: run, onlyVariables: onlyVariables, uploadS3Bucket: signature.uploadS3Bucket)
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(application: context.application, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)

        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Base URL for a run, e.g. .../CZ_1km/18/
    private func baseUrl(run: Timestamp) -> String {
        let hourStr = run.hour.zeroPadded(len: 2)
        return "https://opendata.chmi.cz/meteorology/weather/nwp_aladin/CZ_1km/\(hourStr)/"
    }

    private func fileUrl(run: Timestamp, token: String) -> String {
        return "\(baseUrl(run: run))ALADCZ1K4opendata_\(run.format_YYYYMMddHH)_\(token).grb.bz2"
    }

    /// Static geopotential field -> elevation in metre. Single GRIB message.
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
        let url = fileUrl(run: run, token: "SURFGEOPOTENTIEL")

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

        for parameter in Self.parameters {
            if let onlyVariables, !onlyVariables.contains(parameter.variable) {
                continue
            }
            logger.info("Processing \(parameter.variable)")
            let url = fileUrl(run: run, token: parameter.token)

            // Decode every timestep of this single variable into one spatial buffer (time-major).
            let data: [Float] = try await curl.withGribStream(url: url, bzip2Decode: true) { stream in
                var buffer = [Float](repeating: .nan, count: nLocations * nTime)
                for try await message in stream {
                    guard let validityTime = message.get(attribute: "validityTime"),
                          let validityDate = message.get(attribute: "validityDate"),
                          let validityTimeInt = Int(validityTime) else {
                        logger.warning("Could not read validity for \(parameter.token)")
                        continue
                    }
                    let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(validityTimeInt.zeroPadded(len: 4))")
                    let step = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
                    guard step >= 0, step < nTime else {
                        continue
                    }
                    var grib2d = GribArray2D(nx: nx, ny: ny)
                    try grib2d.load(message: message)
                    for i in 0..<nLocations {
                        buffer[step * nLocations + i] = grib2d.array.data[i]
                    }
                }
                return buffer
            }

            var spatial = Array2DFastSpace(data: data, nLocations: nLocations, nTime: nTime)
            if let fma = parameter.multiplyAdd {
                spatial.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
            }
            if parameter.isAccumulated {
                // Hour 0 has no message (stays NaN); de-accumulation yields hourly increments.
                spatial.data.deaccumulateOverTimeSpatial(nTime: nTime)
            }

            for t in 0..<nTime {
                let slice = Array(spatial[t, 0..<nLocations])
                try await writer.write(time: run.add(hours: t), member: 0, variable: parameter.variable, data: slice)
            }
        }

        await curl.printStatistics()
        return try await writer.finalise(application: application, completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }
}
