import Foundation
import Vapor
import OmFileFormat
import SwiftNetCDF

/// Download GeoSphere Austria models
/// AROME: https://public.hub.geosphere.at/datahub/resources/nwp-v1-1h-2500m/filelisting/nwp_{YYYYMMDDHH}.nc
/// AROME DEM: https://public.hub.geosphere.at/public/resources/misc/NWP_DEM.nc
/// C-LAEF: https://public.hub.geosphere.at/datahub/resources/nwp-v2-1h-1km/filelisting/nwp_{YYYYMMDDHH}.nc
struct GeoSphereDownloader: AsyncCommand {
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
        
        @Flag(name: "skip-timeseries")
        var skipTimeseries: Bool
    }

    var help: String {
        "Download GeoSphere Austria models"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try GeoSphereDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun

        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let handles: [GenericVariableHandle]
        switch domain {
        case .arome_austria:
            let onlyVariables = try GeoSphereVariable.load(commaSeparatedOptional: signature.onlyVariables)
            handles = try await downloadArome(application: context.application, domain: domain, run: run, onlyVariables: onlyVariables, uploadS3Bucket: signature.uploadS3Bucket)
        case .claef_austria:
            let onlyVariables = try GeoSphereClaefVariable.load(commaSeparatedOptional: signature.onlyVariables.map { [$0] })
            handles = try await downloadClaef(application: context.application, domain: domain, run: run, onlyVariables: onlyVariables, uploadS3Bucket: signature.uploadS3Bucket)
        }
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(application: context.application, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false, generateTimeSeries: !signature.skipTimeseries)

        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Download AROME elevation from its DEM file. C-LAEF uses forecast surface geopotential instead.
    func downloadAromeElevation(application: Application, uploadS3Bucket: String?) async throws {
        let domain = GeoSphereDomain.arome_austria
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()
        logger.info("Downloading AROME elevation data from GeoSphere DEM")

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4)
        let demUrl = "https://public.hub.geosphere.at/public/resources/misc/NWP_DEM.nc"
        let demFile = "\(domain.downloadDirectory)NWP_DEM.nc"

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItemIfExists(at: demFile)
        }

        let nc = try await curl.downloadNetCdf(
            url: demUrl,
            file: demFile,
            ncVariable: "oro",
            bzip2Decode: false
        )

        // Variable is "oro" with shape (time=1, lat, lon)
        guard let elevation = try nc.getVariable(name: "oro")?.asType(Float.self)?.read() else {
            fatalError("Could not read oro (elevation) variable from DEM")
        }

        logger.info("Writing elevation file (\(elevation.count) grid points)")
        try await elevation.writeStaticOmFile(file: domain.surfaceElevationFileOm, grid: domain.grid, application: application, uploadS3Bucket: uploadS3Bucket)
    }

    /// GeoSphere weather symbol codes 1-32 mapped to WMO weather codes
    /// https://github.com/Geosphere-Austria/dataset-api-docs/issues/30
    private static let symbolToWmo: InlineArray<33, Float> = [
        .nan,                     // 0: missing
        0, 1, 2, 3, 3,            // 1–5: cloud cover
        45, 45,                   // 6–7: fog
        61, 63, 65,               // 8–10: rain
        66, 66, 66,               // 11–13: freezing rain
        71, 73, 75,               // 14–16: snowfall
        81, 81, 82,               // 17–19: rain showers
        85, 85, 85, 85, 85, 86,   // 20–25: snow showers
        95, 95, 95, 96, 99, 96, 99 // 26–32: thunderstorms
    ]

    static func weatherCode(symbol: Float) -> Float {
        guard symbol.isFinite, let index = Int(exactly: symbol.rounded()), symbolToWmo.indices.contains(index) else {
            return .nan
        }
        return symbolToWmo[index]
    }

    func downloadArome(application: Application, domain: GeoSphereDomain, run: Timestamp, onlyVariables: [GeoSphereVariable]?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 4
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer { Process.alarm(seconds: 0) }

        try await downloadAromeElevation(application: application, uploadS3Bucket: uploadS3Bucket)

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)

        // Download bulk NetCDF file directly from the public data hub
        let runStr = run.format_YYYYMMddHH
        let url = "https://public.hub.geosphere.at/datahub/resources/nwp-v1-1h-2500m/filelisting/nwp_\(runStr).nc"

        logger.info("Downloading forecast from \(url)")

        let forecastFile = "\(domain.downloadDirectory)nwp_\(runStr).nc"
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItemIfExists(at: forecastFile)
        }

        let ncFile = try await curl.downloadNetCdf(
            url: url,
            file: forecastFile,
            ncVariable: "T2M",
            bzip2Decode: false
        )
        
        let dimensions = ncFile.getDimensions()
        for d in dimensions {
            logger.debug("Forecast dimension: \(d.name) = \(d.length)")
        }
        let ncVariables = ncFile.getVariables()
        logger.debug("NetCDF variables: \(ncVariables.map { $0.name }.joined(separator: ", "))")

        // Verify grid dimensions match expected domain
        // Bulk files use "longitude"/"latitude" (API uses "lon"/"lat")
        let ncNx = dimensions.first(where: { $0.name == "longitude" })?.length ?? 0
        let ncNy = dimensions.first(where: { $0.name == "latitude" })?.length ?? 0
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        guard ncNx == nx, ncNy == ny else {
            fatalError("Grid dimension mismatch: NetCDF has \(ncNx)x\(ncNy), expected \(nx)x\(ny)")
        }
        let nLocations = nx * ny

        guard let nTime = dimensions.first(where: { $0.name == "time" })?.length, nTime > 0 else {
            fatalError("Could not determine time dimension")
        }

        logger.info("Forecast has \(nTime) timesteps, grid \(nx)x\(ny) = \(nLocations) locations")

        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: true, realm: nil, logger: logger)

        let simpleVariables: [(ncName: String, omVar: GeoSphereVariable, multiplyAdd: (multiply: Float, add: Float)?, isAccumulated: Bool)] = [
            ("T2M", .temperature_2m, nil, false),
            ("MNT2M", .temperature_2m_min, nil, false),
            ("MXT2M", .temperature_2m_max, nil, false),
            ("TSURF", .surface_temperature, nil, false),
            ("RH2M", .relative_humidity_2m, nil, false),
            ("TCC", .cloud_cover, (100, 0), false),                    // fraction -> percent
            ("LCC", .cloud_cover_low, (100, 0), false),                    // fraction -> percent
            ("MCC", .cloud_cover_mid, (100, 0), false),                    // fraction -> percent
            ("HCC", .cloud_cover_high, (100, 0), false),                    // fraction -> percent
            ("GRAD", .shortwave_radiation, (1.0 / 3600.0, 0), true),  // Ws/m² -> W/m²
            ("CAPE", .cape, nil, false),
            ("CIN", .convective_inhibition, nil, false),
            ("TP", .precipitation, nil, true),
            ("RAIN", .rain, nil, true),
            ("SNOW", .snowfall_water_equivalent, nil, true),
            ("SSNOW", .snow_depth_water_equivalent, nil, false),
            ("SUNDUR", .sunshine_duration, nil, true),
        ]
        
        for (ncName, omVar, fma, isAccumulated) in simpleVariables {
            if let onlyVariables, !onlyVariables.contains(omVar) {
                continue
            }
            logger.info("Processing \(omVar)")
            guard let ncVar = ncFile.getVariable(name: ncName) else {
                logger.warning("Could not find variable \(ncName) in NetCDF, skipping")
                continue
            }
            guard let data = try ncVar.readAndScale() else {
                fatalError("Could not read data from \(ncName)")
            }

            var spatial = Array2DFastSpace(data: data, nLocations: nLocations, nTime: nTime)

            if let fma {
                spatial.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
            }

            if isAccumulated {
                spatial.data.deaccumulateOverTimeSpatial(nTime: nTime)
                for i in 0..<nLocations {
                    spatial.data[i] = .nan
                }
            }

            for t in 0..<nTime {
                let slice = Array(spatial[t, 0..<nLocations])
                try await writer.write(time: run.add(hours: t), member: 0, variable: omVar, data: slice)
            }
        }
        
        logger.info("Converting surface pressure to MSL pressure")
        guard let t2m = try ncFile.getVariable(name: "T2M")?.readAndScale() else {
            fatalError("Could not read T2M")
        }
        guard let surfacePressure = try ncFile.getVariable(name: "SP")?.readAndScale() else {
            fatalError("Could not read SP")
        }
        guard let z = try ncFile.getVariable(name: "ZSURF")?.readAndScale() else {
            fatalError("Could not read ZSURF")
        }
        
        let msl = Array2DFastSpace(data: zip(surfacePressure, zip(t2m, z)).map {
            return $0 / 100 * Meteorology.sealevelPressureFactor(temperature: $1.0, elevation: $1.1 / 9.80665)
        }, nLocations: nLocations, nTime: nTime)

        for t in 0..<nTime {
            try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.pressure_msl, data: Array(msl[t, 0..<nLocations]))
        }
        
        /// Lower snowfall level height below grid-cell elevation to adjust data to mixed terrain
        /// Use temperature to estimate freezing level height below ground. This is consistent with GFS
        logger.info("Correct snowfall height from metre above ground to metre above sea level")
        guard var snowlmt = try ncFile.getVariable(name: "SNOWLMT")?.readAndScale() else {
            fatalError("Could not read SNOWLMT")
        }
        for i in snowlmt.indices {
            let elevation = z[i] / 9.80665
            let snowheight = snowlmt[i] + elevation
            let temperature_2m = t2m[i]
            snowlmt[i] = snowheight + (snowlmt[i] < 20 && temperature_2m < 0 ? temperature_2m * 0.7 * 100 : 0)
        }
        for t in 0..<nTime {
            try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.snowfall_height, data: Array(snowlmt[nLocations*t ..< nLocations*(t+1)]))
        }


        logger.info("Processing wind speed and direction")
        guard let uData = try ncFile.getVariable(name: "U10M")?.readAndScale() else {
            fatalError("Could not read U10M")
        }
        guard let vData = try ncFile.getVariable(name: "V10M")?.readAndScale() else {
            fatalError("Could not read V10M")
        }
        let uSpatial = Array2DFastSpace(data: uData, nLocations: nLocations, nTime: nTime)
        let vSpatial = Array2DFastSpace(data: vData, nLocations: nLocations, nTime: nTime)

        for t in 0..<nTime {
            let u = Array(uSpatial[t, 0..<nLocations])
            let v = Array(vSpatial[t, 0..<nLocations])
            let speed = zip(u, v).map(Meteorology.windspeed)
            let direction = Meteorology.windirectionFast(u: u, v: v)
            try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.wind_speed_10m, data: speed)
            try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.wind_direction_10m, data: direction)
        }

        logger.info("Processing wind gusts")
        guard let ugustData = try ncFile.getVariable(name: "UGUST")?.readAndScale() else {
            fatalError("Could not read UGUST")
        }
        guard let vgustData = try ncFile.getVariable(name: "VGUST")?.readAndScale() else {
            fatalError("Could not read VGUST")
        }
        let ugustSpatial = Array2DFastSpace(data: ugustData, nLocations: nLocations, nTime: nTime)
        let vgustSpatial = Array2DFastSpace(data: vgustData, nLocations: nLocations, nTime: nTime)

        for t in 0..<nTime {
            let u = Array(ugustSpatial[t, 0..<nLocations])
            let v = Array(vgustSpatial[t, 0..<nLocations])
            let gustSpeed = zip(u, v).map(Meteorology.windspeed)
            try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.wind_gusts_10m, data: gustSpeed)
        }

        // Weather code converted from SYMBOL GeoSphere-specific codes, not WMO
        logger.info("Converting weather code")
        guard let symbol = try ncFile.getVariable(name: "SYMBOL")?.readAndScale() else {
            fatalError("Could not read SYMBOL")
        }
        let spatial = Array2DFastSpace(
            data: symbol.map(Self.weatherCode),
            nLocations: nLocations,
            nTime: nTime
        )
        for t in 0..<nTime {
            try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.weather_code, data: Array(spatial[t, 0..<nLocations]))
        }

        await curl.printStatistics()
        return try await writer.finalise(application: application, completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }

    /// Download C-LAEF AlpeAdria. Amounts are per hour and radiation is an hourly mean, so nothing is deaccumulated.
    /// Values of the first step are missing for all interval variables.
    func downloadClaef(application: Application, domain: GeoSphereDomain, run: Timestamp, onlyVariables: [GeoSphereClaefVariable]?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 4
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer { Process.alarm(seconds: 0) }

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)

        // About 9.4 GB per run, most of it pressure levels
        let runStr = run.format_YYYYMMddHH
        let url = "https://public.hub.geosphere.at/datahub/resources/nwp-v2-1h-1km/filelisting/nwp_\(runStr).nc"
        logger.info("Downloading forecast from \(url)")

        let forecastFile = "\(domain.downloadDirectory)nwp_\(runStr).nc"
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItemIfExists(at: forecastFile)
        }

        let ncFile = try await curl.downloadNetCdf(
            url: url,
            file: forecastFile,
            ncVariable: "2t",
            bzip2Decode: false
        )

        let dimensions = ncFile.getDimensions()
        let ncNx = dimensions.first(where: { $0.name == "longitude" })?.length ?? 0
        let ncNy = dimensions.first(where: { $0.name == "latitude" })?.length ?? 0
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        guard ncNx == nx, ncNy == ny else {
            fatalError("Grid dimension mismatch: NetCDF has \(ncNx)x\(ncNy), expected \(nx)x\(ny)")
        }
        let nLocations = nx * ny
        guard let nTime = dimensions.first(where: { $0.name == "time" })?.length, nTime > 0 else {
            fatalError("Could not determine time dimension")
        }
        logger.info("Forecast has \(nTime) timesteps, grid \(nx)x\(ny) = \(nLocations) locations")

        /// Read a float32 surface variable and flip it from north-to-south to the south-to-north grid
        func read(_ ncName: String) throws -> Array2DFastSpace {
            guard let data = try ncFile.getVariable(name: ncName)?.asType(Float.self)?.read() else {
                fatalError("Could not read \(ncName)")
            }
            var spatial = Array2DFastSpace(data: data, nLocations: nLocations, nTime: nTime)
            spatial.data.flipLatitude(nt: nTime, ny: ny, nx: nx)
            return spatial
        }

        if !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
            logger.info("Writing elevation from surface geopotential")
            try domain.surfaceElevationFileOm.createDirectory()
            guard var elevation = try ncFile.getVariable(name: "zsurf")?.asType(Float.self)?.read(offset: [0, 0, 0], count: [1, ny, nx]) else {
                fatalError("Could not read zsurf")
            }
            elevation.flipLatitude(nt: 1, ny: ny, nx: nx)
            elevation.multiplyAdd(multiply: 1 / 9.80665, add: 0)
            try await elevation.writeStaticOmFile(file: domain.surfaceElevationFileOm, grid: domain.grid, application: application, uploadS3Bucket: uploadS3Bucket)
        }

        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: true, realm: nil, logger: logger)

        func write(_ variable: GeoSphereVariable, _ spatial: Array2DFastSpace) async throws {
            for t in 0..<nTime {
                try await writer.write(time: run.add(hours: t), member: 0, variable: variable, data: Array(spatial[t, 0..<nLocations]))
            }
        }

        let simpleVariables: [(ncName: String, omVar: GeoSphereVariable, multiply: Float?)] = [
            ("2t", .temperature_2m, nil),
            ("min_2t", .temperature_2m_min, nil),
            ("max_2t", .temperature_2m_max, nil),
            ("tsurf", .surface_temperature, nil),
            ("2r", .relative_humidity_2m, nil),
            ("tcc", .cloud_cover, nil),
            ("lcc", .cloud_cover_low, nil),
            ("mcc", .cloud_cover_mid, nil),
            ("hcc", .cloud_cover_high, nil),
            ("ssrd", .shortwave_radiation, nil),
            ("cape", .cape, nil),
            ("cin", .convective_inhibition, nil),
            ("tp", .precipitation, nil),
            ("rain", .rain, nil),
            ("sf", .snowfall_water_equivalent, nil),
            ("sd", .snow_depth_water_equivalent, nil),
            ("sund", .sunshine_duration, nil),
            ("10fg", .wind_gusts_10m, nil),
            ("msl", .pressure_msl, 0.01), // Pa -> hPa
        ]

        for (ncName, omVar, multiply) in simpleVariables {
            if let onlyVariables, !onlyVariables.contains(.surface(omVar)) {
                continue
            }
            logger.info("Processing \(omVar)")
            var spatial = try read(ncName)
            if let multiply {
                spatial.data.multiplyAdd(multiply: multiply, add: 0)
            }
            try await write(omVar, spatial)
        }

        if onlyVariables?.contains(.surface(.snowfall_height)) ?? true {
            logger.info("Lowering snowfall height below grid-cell elevation")
            var snowfallHeight = try read("snowlmt")
            let temperature = try read("2t")
            let geopotential = try read("zsurf")
            for i in snowfallHeight.data.indices {
                let elevation = geopotential.data[i] / 9.80665
                // `snowlmt` is already above sea level, although its description says above ground.
                // Use subzero temperature to extend the snowfall limit below grid-cell elevation.
                if snowfallHeight.data[i] - elevation < 20 && temperature.data[i] < 0 {
                    snowfallHeight.data[i] += temperature.data[i] * 0.7 * 100
                }
            }
            try await write(.snowfall_height, snowfallHeight)
        }

        let writeWindSpeed = onlyVariables?.contains(.surface(.wind_speed_10m)) ?? true
        let writeWindDirection = onlyVariables?.contains(.surface(.wind_direction_10m)) ?? true
        if writeWindSpeed || writeWindDirection {
            logger.info("Processing wind speed and direction")
            let u = try read("10u")
            let v = try read("10v")
            for t in 0..<nTime {
                let uStep = Array(u[t, 0..<nLocations])
                let vStep = Array(v[t, 0..<nLocations])
                if writeWindSpeed {
                    try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.wind_speed_10m, data: zip(uStep, vStep).map(Meteorology.windspeed))
                }
                if writeWindDirection {
                    try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.wind_direction_10m, data: Meteorology.windirectionFast(u: uStep, v: vStep))
                }
            }
        }

        if onlyVariables?.contains(.surface(.weather_code)) ?? true {
            logger.info("Converting weather code")
            var symbol = try read("sy")
            symbol.data = symbol.data.map(Self.weatherCode)
            try await write(.weather_code, symbol)
        }

        let onlyPressureVariables = onlyVariables?.compactMap { variable -> GeoSpherePressureVariable? in
            guard case .pressure(let pressure) = variable else { return nil }
            return pressure
        }
        if onlyPressureVariables?.isEmpty != true {
            guard let levels = try ncFile.getVariable(name: "plev")?.asType(Double.self)?.read(),
                  levels.allSatisfy({ Int(exactly: $0) != nil }) else {
                throw Abort(.internalServerError, reason: "Could not read C-LAEF pressure levels")
            }
            for variable in onlyPressureVariables ?? [] where !levels.contains(Double(variable.level)) {
                throw Abort(.internalServerError, reason: "Missing C-LAEF pressure level \(variable.level) hPa")
            }
            let pressureFields: [(ncName: String, variable: GeoSpherePressureVariableType, multiply: Float)] = [
                ("t", .temperature, 1),
                ("u", .wind_u_component, 1),
                ("v", .wind_v_component, 1),
                ("z", .geopotential_height, 1 / 9.80665),
                ("r", .relative_humidity, 1),
                ("w", .vertical_velocity, 1) // Convert omega to m/s using temperature below.
            ]
            for (ncName, kind, multiply) in pressureFields {
                let selectedLevels = levels.enumerated().filter { _, level in
                    guard let onlyPressureVariables else { return true }
                    let variable = GeoSpherePressureVariable(variable: kind, level: Int(level))
                    return onlyPressureVariables.contains(variable)
                }
                guard !selectedLevels.isEmpty else { continue }
                guard let field = ncFile.getVariable(name: ncName),
                      field.dimensions.map({ $0.name }) == ["time", "plev", "latitude", "longitude"],
                      field.dimensions.map({ $0.length }) == [nTime, levels.count, ny, nx],
                      let values = field.asType(Float.self) else {
                    throw Abort(.internalServerError, reason: "Invalid C-LAEF pressure variable \(ncName)")
                }
                let temperatureField = kind == .vertical_velocity ? ncFile.getVariable(name: "t") : nil
                let temperatureValues = temperatureField?.asType(Float.self)
                if kind == .vertical_velocity {
                    guard let temperatureField, temperatureValues != nil,
                          temperatureField.dimensions.map({ $0.name }) == field.dimensions.map({ $0.name }),
                          temperatureField.dimensions.map({ $0.length }) == field.dimensions.map({ $0.length }) else {
                        throw Abort(.internalServerError, reason: "Invalid C-LAEF temperature for omega conversion")
                    }
                }
                for (levelIndex, level) in selectedLevels {
                    let variable = GeoSpherePressureVariable(variable: kind, level: Int(level))
                    logger.info("Processing \(variable.rawValue)")
                    for t in 0..<nTime {
                        var data = try values.read(offset: [t, levelIndex, 0, 0], count: [1, 1, ny, nx])
                        if let temperatureValues {
                            let temperature = try temperatureValues.read(offset: [t, levelIndex, 0, 0], count: [1, 1, ny, nx])
                            data = Meteorology.verticalVelocityPressureToGeometric(omega: data, temperature: temperature, pressureLevel: Float(level))
                        }
                        data.flipLatitude(nt: 1, ny: ny, nx: nx)
                        if multiply != 1 {
                            data.multiplyAdd(multiply: multiply, add: 0)
                        }
                        try await writer.write(time: run.add(hours: t), member: 0, variable: variable, data: data)
                    }
                }
            }
        }

        await curl.printStatistics()
        return try await writer.finalise(application: application, completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }
}
