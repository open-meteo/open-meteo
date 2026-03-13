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

        _ = try await curl.downloadNetCdf(
            url: demUrl,
            file: demFile,
            ncVariable: "oro",
            bzip2Decode: false
        )

        guard let nc = try NetCDF.open(path: demFile, allowUpdate: false) else {
            fatalError("Could not open DEM file")
        }

        // Variable is "oro" with shape (time=1, lat, lon)
        guard var elevation = try nc.getVariable(name: "oro")?.asType(Float.self)?.read() else {
            fatalError("Could not read oro (elevation) variable from DEM")
        }

        // Mask sea/invalid points to -999
        for i in elevation.indices {
            if elevation[i].isNaN || elevation[i] < -100 {
                elevation[i] = -999
            }
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

        logger.info("Downloading forecast from \(url)")

        let forecastFile = "\(domain.downloadDirectory)nwp_\(runStr).nc"
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)

        _ = try await curl.downloadNetCdf(
            url: url,
            file: forecastFile,
            ncVariable: "T2M",
            bzip2Decode: false
        )

        guard let ncFile = try NetCDF.open(path: forecastFile, allowUpdate: false) else {
            fatalError("Could not open forecast NetCDF file")
        }

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

        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: true, realm: nil)

        let simpleVariables: [(ncName: String, omVar: GeoSphereVariable, multiplyAdd: (multiply: Float, add: Float)?, isAccumulated: Bool)] = [
            ("T2M", .temperature_2m, nil, false),
            ("RH2M", .relative_humidity_2m, nil, false),
            ("SP", .surface_pressure, (1.0 / 100.0, 0), false),      // Pa -> hPa
            ("TCC", .cloud_cover, (100, 0), false),                    // fraction -> percent
            ("GRAD", .shortwave_radiation, (1.0 / 3600.0, 0), true),  // Ws/m² -> W/m²
            ("CAPE", .cape, nil, false),
            ("SNOWLMT", .snowfall_height, nil, false),
            ("TP", .precipitation, nil, true),
            ("RAIN", .rain, nil, true),
            ("SNOW", .snowfall_water_equivalent, nil, true),
            ("SUNDUR", .sunshine_duration, nil, true),
        ]

        // Retain processed arrays for TCC, TP, SNOW to reuse in weather code calculation
        var cloudCoverSpatial: Array2DFastSpace? = nil
        var precipSpatial: Array2DFastSpace? = nil
        var snowSpatial: Array2DFastSpace? = nil

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

            // Retain for weather code calculation
            switch ncName {
            case "TCC": cloudCoverSpatial = spatial
            case "TP": precipSpatial = spatial
            case "SNOW": snowSpatial = spatial
            default: break
            }

            for t in 0..<nTime {
                let slice = Array(spatial[t, 0..<nLocations])
                try await writer.write(time: run.add(hours: t), member: 0, variable: omVar, data: slice)
            }
        }

        let needsWind = onlyVariables == nil || onlyVariables!.contains(.wind_speed_10m) || onlyVariables!.contains(.wind_direction_10m)
        let needsGusts = onlyVariables == nil || onlyVariables!.contains(.wind_gusts_10m)
        let needsWeatherCode = onlyVariables == nil || onlyVariables!.contains(.weather_code)

        // Process wind from u/v components
        var ugustSpatial: Array2DFastSpace? = nil
        var vgustSpatial: Array2DFastSpace? = nil

        if needsWind {
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
        }

        if needsGusts || needsWeatherCode {
            logger.info("Processing wind gusts")
            guard let ugustData = try ncFile.getVariable(name: "UGUST")?.readAndScale() else {
                fatalError("Could not read UGUST")
            }
            guard let vgustData = try ncFile.getVariable(name: "VGUST")?.readAndScale() else {
                fatalError("Could not read VGUST")
            }
            ugustSpatial = Array2DFastSpace(data: ugustData, nLocations: nLocations, nTime: nTime)
            vgustSpatial = Array2DFastSpace(data: vgustData, nLocations: nLocations, nTime: nTime)

            if needsGusts {
                for t in 0..<nTime {
                    let u = Array(ugustSpatial![t, 0..<nLocations])
                    let v = Array(vgustSpatial![t, 0..<nLocations])
                    let gustSpeed = zip(u, v).map(Meteorology.windspeed)
                    try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.wind_gusts_10m, data: gustSpeed)
                }
            }
        }

        // Weather code derived from raw fields (SYMBOL uses GeoSphere-specific codes, not WMO)
        if needsWeatherCode {
            logger.info("Calculating weather code")

            // Read TCC/TP/SNOW from retained arrays if available, otherwise read from NetCDF
            if cloudCoverSpatial == nil {
                guard let data = try ncFile.getVariable(name: "TCC")?.readAndScale() else {
                    fatalError("Could not read TCC for weather code")
                }
                var spatial = Array2DFastSpace(data: data, nLocations: nLocations, nTime: nTime)
                spatial.data.multiplyAdd(multiply: 100, add: 0)
                cloudCoverSpatial = spatial
            }
            if precipSpatial == nil {
                guard let data = try ncFile.getVariable(name: "TP")?.readAndScale() else {
                    fatalError("Could not read TP for weather code")
                }
                var spatial = Array2DFastSpace(data: data, nLocations: nLocations, nTime: nTime)
                spatial.data.deaccumulateOverTimeSpatial(nTime: nTime)
                for i in 0..<nLocations { spatial.data[i] = .nan }
                precipSpatial = spatial
            }
            if snowSpatial == nil {
                guard let data = try ncFile.getVariable(name: "SNOW")?.readAndScale() else {
                    fatalError("Could not read SNOW for weather code")
                }
                var spatial = Array2DFastSpace(data: data, nLocations: nLocations, nTime: nTime)
                spatial.data.deaccumulateOverTimeSpatial(nTime: nTime)
                for i in 0..<nLocations { spatial.data[i] = .nan }
                snowSpatial = spatial
            }

            // Read CAPE once before the loop
            let capeSpatial: Array2DFastSpace?
            if let capeVar = ncFile.getVariable(name: "CAPE"),
               let capeData = try capeVar.readAndScale() {
                capeSpatial = Array2DFastSpace(data: capeData, nLocations: nLocations, nTime: nTime)
            } else {
                capeSpatial = nil
            }

            for t in 0..<nTime {
                let cloudcover = Array(cloudCoverSpatial![t, 0..<nLocations])
                let precipitation = Array(precipSpatial![t, 0..<nLocations])
                let snowfallCm = Array(snowSpatial![t, 0..<nLocations]).map({ $0 * 0.7 })

                let uGust = Array(ugustSpatial![t, 0..<nLocations])
                let vGust = Array(vgustSpatial![t, 0..<nLocations])
                let gusts = zip(uGust, vGust).map(Meteorology.windspeed)

                let capeSpatialData = capeSpatial.map { Array($0[t, 0..<nLocations]) }

                let weatherCode = WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: nil,
                    snowfallCentimeters: snowfallCm,
                    gusts: gusts,
                    cape: capeSpatialData,
                    liftedIndex: nil,
                    visibilityMeters: nil,
                    categoricalFreezingRain: nil,
                    modelDtSeconds: domain.dtSeconds
                )
                try await writer.write(time: run.add(hours: t), member: 0, variable: GeoSphereVariable.weather_code, data: weatherCode)
            }
        }

        await curl.printStatistics()
        return try await writer.finalise(completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }
}
