import Foundation
import Vapor
import OmFileFormat
import SwiftNetCDF

/// Download GeoSphere Austria AROME model
/// URL: https://public.hub.geosphere.at/datahub/resources/nwp-v1-1h-2500m/filelisting/nwp_{YYYYMMDDHH}.nc
/// DEM: https://public.hub.geosphere.at/public/resources/misc/NWP_DEM.nc
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
    }

    var help: String {
        "Download GeoSphere Austria models"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try GeoSphereDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let onlyVariables = try GeoSphereVariable.load(commaSeparatedOptional: signature.onlyVariables)

        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let handles = try await download(application: context.application, domain: domain, run: run, onlyVariables: onlyVariables, uploadS3Bucket: signature.uploadS3Bucket)
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)

        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// Download elevation data from GeoSphere DEM file
    func downloadElevation(application: Application, domain: GeoSphereDomain) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()
        logger.info("Downloading elevation data from GeoSphere DEM")

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
        try elevation.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid)
    }

    /// Download forecast data and return variable handles
    func download(application: Application, domain: GeoSphereDomain, run: Timestamp, onlyVariables: [GeoSphereVariable]?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 4
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer { Process.alarm(seconds: 0) }

        try await downloadElevation(application: application, domain: domain)

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)

        // Download bulk NetCDF file directly from the public data hub
        let runStr = run.format_YYYYMMddHH
        let url = "https://public.hub.geosphere.at/datahub/resources/nwp-v1-1h-2500m/filelisting/nwp_\(runStr).nc"
//        let url = "file:///Users/patrick/Downloads/nwp_2026032106.nc"

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
        /// https://github.com/Geosphere-Austria/dataset-api-docs/issues/30
        let symbolToWmo = [Float.nan ,0,1,2,3,3,45,45,61,63,65,66,66,66,71,73,75,81,81,82,85,85,85,85,85,86,95,95,95,96,99,96,99]
        guard let symbol = try ncFile.getVariable(name: "SYMBOL")?.readAndScale() else {
            fatalError("Could not read U10M")
        }
        let spatial = Array2DFastSpace(
            data: symbol.map({symbolToWmo[Int(round($0))]}),
            nLocations: nLocations,
            nTime: nTime
        )
        for t in 0..<nTime {
            try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.weather_code, data: Array(spatial[t, 0..<nLocations]))
        }

        await curl.printStatistics()
        return try await writer.finalise(completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }
}
