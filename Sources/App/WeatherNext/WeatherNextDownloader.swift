import Foundation
import Vapor
import OmFileFormat
import SwiftZarr

/**
 Downloader for Google DeepMind WeatherNext-2 ensemble data.

 Reads directly from the raw Zarr archive on GCS, transforms variables
 (K→°C, Pa→hPa, m→mm, geopotential→height), derives relative humidity
 from specific humidity + temperature, derives cloud cover from RH
 pressure levels, and writes per-timestep spatial OM files.

 Source layout:
 `gs://weathernext/{server}{YYYYMMDD}_{HH}hr_01_preds/predictions.zarr/`
 */
struct DownloadWeatherNextCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Option(name: "server", help: "Root path. Default: weathernext_2_0_0/zarr/2025_to_present/")
        var server: String?

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool

        @Flag(name: "process-local-only", help: "Only process files already downloaded to the local directory")
        var processLocalOnly: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }

    var help: String {
        "Download a specified WeatherNext-2 model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        let domain = try WeatherNextDomain.load(rawValue: signature.domain)
        guard domain.ensembleMeanDomain != nil else {
            throw WeatherNextDownloaderError.notImplemented("Direct download of \(domain.rawValue) is not supported. Download \(WeatherNextDomain.weathernext_global.rawValue) to generate ensemble mean output.")
        }
        let logger = context.application.logger
        let run: Timestamp
        if let runArg = signature.run {
            run = try Timestamp.fromRunHourOrYYYYMMDD(runArg)
        } else {
            let targetRun = domain.lastRun
            let deadline = Date().addingTimeInterval(TimeInterval(6 * 3600))
            let server = signature.server ?? "weathernext_2_0_0/zarr/2025_to_present/"
            try await waitForZarrMarker(
                client: context.application.dedicatedHttpClient,
                logger: logger,
                targetRun: targetRun,
                deadline: deadline,
                server: server
            )
            run = targetRun
        }

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let server = signature.server ?? "weathernext_2_0_0/zarr/2025_to_present/"
        let nConcurrent = signature.concurrent ?? 1

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)

        try await download(
            application: context.application,
            domain: domain,
            run: run,
            server: server,
            concurrent: nConcurrent,
            skipFilesIfExisting: signature.skipExisting,
            processLocalOnly: signature.processLocalOnly,
            uploadS3Bucket: signature.uploadS3Bucket,
            uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities,
            createNetcdf: signature.createNetcdf
        )
    }

    // MARK: – Main download / Zarr → spatial OM pass

    func download(
        application: Application,
        domain: WeatherNextDomain,
        run: Timestamp,
        server: String,
        concurrent: Int,
        skipFilesIfExisting: Bool,
        processLocalOnly: Bool,
        uploadS3Bucket: String?,
        uploadS3OnlyProbabilities: Bool,
        createNetcdf: Bool
    ) async throws {
        let logger = application.logger
        let timestamps = domain.forecastTimestamps(for: run)
        logger.info("Processing \(timestamps.count) WeatherNext timesteps from Zarr")

        let surfaceZarrNames: [(zarr: String, surfaceVar: WeatherNextSurfaceVariable, transform: @Sendable ([Float]) -> [Float])] = [
            ("2m_temperature", .temperature_2m, { $0.map { $0 - 273.15 } }),
            ("mean_sea_level_pressure", .pressure_msl, { $0.map { $0 * 0.01 } }),
            ("sea_surface_temperature", .sea_surface_temperature, { $0.map { $0 - 273.15 } }),
            ("total_precipitation_6hr", .total_precipitation_6hr, { $0.map { $0 * 1000.0 } }),
            ("100m_u_component_of_wind", .wind_u_component_100m, { $0 }),
            ("100m_v_component_of_wind", .wind_v_component_100m, { $0 }),
            ("10m_u_component_of_wind", .wind_u_component_10m, { $0 }),
            ("10m_v_component_of_wind", .wind_v_component_10m, { $0 }),
        ]

        let pressureZarrNames: [(zarr: String, type: WeatherNextPressureVariableType)] = [
            ("geopotential", .geopotential_height),
            ("specific_humidity", .specific_humidity),
            ("temperature", .temperature),
            ("u_component_of_wind", .wind_u_component),
            ("v_component_of_wind", .wind_v_component),
            ("vertical_velocity", .vertical_velocity),
        ]

        let zarrRootPath = WeatherNextDomain.zarrRunPath(server: server, run: run)
        let nLocations = domain.grid.ny * domain.grid.nx

        var allHandles = [GenericVariableHandle]()
        allHandles.reserveCapacity(timestamps.count * domain.countEnsembleMember * (surfaceZarrNames.count + pressureZarrNames.count * WeatherNextPressureLevel.allCases.count + 4 + 1))

        for (timeIdx, timestamp) in timestamps.enumerated() {
            logger.info("Processing timestep \(timeIdx) / \(timestamps.count): \(timestamp.iso8601_YYYY_MM_dd_HH_mm)")

            // Fresh token + storage + Zarr group per timestep so the OAuth token
            // never expires mid-run (token lifetime is 1 hour).
            let googleToken = try await GoogleCloudStorageAuth(
                client: application.dedicatedHttpClient,
                logger: application.logger
            ).getAccessToken()
            let storage = try S3CompatibleStorage(
                baseURL: "https://storage.googleapis.com/weathernext",
                additionalHeaders: ["Authorization": "Bearer \(googleToken)"]
            )
            let root = try await ZarrGroup(storage: storage, path: zarrRootPath)

            // Read the level coordinate array to map hPa → Zarr level index
            let levelArray = try await root.openArray(name: "level")
            let zarrLevelValuesRaw: [Int32] = try await levelArray.retrieveArraySubset([0..<levelArray.shape[0]])
            let zarrLevelValues = zarrLevelValuesRaw.map(Int.init)
            let levelIndexMap = zarrLevelValues.enumerated().reduce(into: [Int: Int]()) { $0[$1.element] = $1.offset }

            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: false, realm: nil, logger: logger, ensembleMeanDomain: domain.ensembleMeanDomain)
            let precipStorage = VariablePerMemberStorage<WeatherNextSurfaceVariable>()

            // Pre-open Zarr arrays for this timestep
            let zarrSurfaceArrays = try await surfaceZarrNames.asyncMap {
                (try await root.openArray(name: $0.zarr), $0.surfaceVar, $0.transform)
            }
            let pressureZarrArrays = try await pressureZarrNames.asyncMap {
                (try await root.openArray(name: $0.zarr), $0.type)
            }

            // Build a flat list of all pressure (array, type, level) reads with their level index
            let allPressureReads: [(ZarrArray, WeatherNextPressureVariableType, WeatherNextPressureLevel, Int)] = pressureZarrArrays.flatMap { (zarrArray, pType) in
                WeatherNextPressureLevel.allCases.compactMap { level in
                    levelIndexMap[level.level].map { (zarrArray, pType, level, $0) }
                }
            }

            // Phase 1: members — reads, RH derivation, cloud cover.
            // rhStorage is scoped tightly so its ~10 GB is freed before
            // precipitation probability and finalise run.
            let totalConcurrency = max(8, concurrent * 4)
            do {
                let rhStorage = VariablePerMemberStorage<WeatherNextPressureVariable>()

                var allTasks = [@Sendable () async throws -> Void]()
                allTasks.reserveCapacity(domain.countEnsembleMember * (zarrSurfaceArrays.count + allPressureReads.count + WeatherNextPressureLevel.allCases.count + 4))

                for member in 0..<domain.countEnsembleMember {
                    // Surface variable reads for this member
                    for (zarrArray, surfaceVar, transform) in zarrSurfaceArrays {
                        allTasks.append {
                            let raw = try await zarrArray.retrieveArraySubset(
                                [member..<member+1, timeIdx..<timeIdx+1, 0..<domain.grid.ny, 0..<domain.grid.nx]
                            ) as [Float]
                            var data = transform(raw)
                            data.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)

                            if surfaceVar == .total_precipitation_6hr && domain.countEnsembleMember > 1 {
                                await precipStorage.set(variable: surfaceVar, timestamp: timestamp, member: member, data: Array2D(data: data, nx: domain.grid.nx, ny: domain.grid.ny))
                            }
                            try await writer.write(member: member, variable: surfaceVar, data: data)
                        }
                    }

                    // Pressure level variable reads for this member
                    for (zarrArray, pType, level, levelIdx) in allPressureReads {
                        allTasks.append {
                            var data: [Float] = try await zarrArray.retrieveArraySubset(
                                [member..<member+1, timeIdx..<timeIdx+1, levelIdx..<levelIdx+1, 0..<domain.grid.ny, 0..<domain.grid.nx]
                            )
                            data.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)

                            let pVar = WeatherNextPressureVariable(variable: pType, level: level)
                            let wnVar = WeatherNextVariable.pressure(pVar)

                            switch pType {
                            case .specific_humidity:
                                await rhStorage.set(variable: pVar, timestamp: timestamp, member: member, data: Array2D(data: data, nx: domain.grid.nx, ny: domain.grid.ny))
                            case .temperature:
                                let celsiusData = data.map { $0 - 273.15 }
                                await rhStorage.set(variable: pVar, timestamp: timestamp, member: member, data: Array2D(data: celsiusData, nx: domain.grid.nx, ny: domain.grid.ny))
                            case .geopotential_height:
                                let heightData = data.map { $0 / 9.80665 }
                                try await writer.write(member: member, variable: wnVar, data: heightData)
                            case .wind_u_component, .wind_v_component, .vertical_velocity:
                                try await writer.write(member: member, variable: wnVar, data: data)
                            case .relative_humidity:
                                throw WeatherNextDownloaderError.notImplemented("relative humidity should not be fetched directly")
                            }
                        }
                    }

                    // RH derivation for this member — deletes SH + temp after use
                    for level in WeatherNextPressureLevel.allCases {
                        let shVar = WeatherNextPressureVariable(variable: .specific_humidity, level: level)
                        let tempVar = WeatherNextPressureVariable(variable: .temperature, level: level)

                        allTasks.append {
                            guard let (shData, tempData, _, _) = await rhStorage.getTwoRemoving(first: shVar, second: tempVar, timestamp: timestamp, member: member) else {
                                return
                            }

                            let rhVar = WeatherNextPressureVariable(variable: .relative_humidity, level: level)
                            let pressure = Float(level.level)
                            let rh = Meteorology.specificToRelativeHumidity(
                                specificHumidity: shData.data,
                                temperature: tempData.data,
                                pressure: pressure
                            )
                            try await writer.write(member: member, variable: WeatherNextVariable.pressure(rhVar), data: rh)
                            await rhStorage.set(variable: rhVar, timestamp: timestamp, member: member, data: Array2D(data: rh, nx: domain.grid.nx, ny: domain.grid.ny))
                        }
                    }

                    // Cloud cover derivation for this member — deletes RH after use
                    allTasks.append {
                        guard await !writer.contains(member: member, variable: WeatherNextVariable.cloud_cover_low) else { return }
                        guard let rh1000 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa1000), timestamp: timestamp, member: member)?.data,
                              let rh925 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa925), timestamp: timestamp, member: member)?.data,
                              let rh850 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa850), timestamp: timestamp, member: member)?.data,
                              let rh700 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa700), timestamp: timestamp, member: member)?.data,
                              let rh600 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa600), timestamp: timestamp, member: member)?.data,
                              let rh500 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa500), timestamp: timestamp, member: member)?.data,
                              let rh400 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa400), timestamp: timestamp, member: member)?.data,
                              let rh300 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa300), timestamp: timestamp, member: member)?.data,
                              let rh250 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa250), timestamp: timestamp, member: member)?.data,
                              let rh200 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa200), timestamp: timestamp, member: member)?.data,
                              let rh150 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa150), timestamp: timestamp, member: member)?.data,
                              let rh100 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa100), timestamp: timestamp, member: member)?.data,
                              let rh50 = await rhStorage.remove(variable: .init(variable: .relative_humidity, level: .hPa50), timestamp: timestamp, member: member)?.data else {
                            logger.warning("Pressure level RH unavailable for cloud cover, member \(member)")
                            return
                        }

                        let lowCC = Meteorology.cloudCoverFromRH([
                            (rh: rh1000, rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 1000)),
                            (rh: rh925,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 925)),
                            (rh: rh850,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 850))
                        ])
                        let midCC = Meteorology.cloudCoverFromRH([
                            (rh: rh700,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 700)),
                            (rh: rh600,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 600)),
                            (rh: rh500,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 500)),
                            (rh: rh400,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 400))
                        ])
                        let highCC = Meteorology.cloudCoverFromRH([
                            (rh: rh300,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 300)),
                            (rh: rh250,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 250)),
                            (rh: rh200,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 200)),
                            (rh: rh150,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 150)),
                            (rh: rh100,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 100)),
                            (rh: rh50,   rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 50))
                        ])
                        try await writer.write(member: member, variable: WeatherNextVariable.cloud_cover_low, data: lowCC)
                        try await writer.write(member: member, variable: WeatherNextVariable.cloud_cover_mid, data: midCC)
                        try await writer.write(member: member, variable: WeatherNextVariable.cloud_cover_high, data: highCC)
                        if await !writer.contains(member: member, variable: WeatherNextVariable.cloud_cover) {
                            let cloudcover = Meteorology.cloudCoverTotal(low: lowCC, mid: midCC, high: highCC)
                            try await writer.write(member: member, variable: WeatherNextVariable.cloud_cover, data: cloudcover)
                        }
                    }
                }

                logger.info("Processing \(allTasks.count) tasks with concurrency \(totalConcurrency)")
                try await allTasks.foreachConcurrent(nConcurrent: totalConcurrency) { task in
                    try await task()
                }
                // rhStorage released here
            }

            // ---- Derive precipitation probability ----
            if domain.countEnsembleMember > 1 {
                logger.info("Calculating precipitation probability for timestep \(timeIdx)")
                let threshold = Float(0.1) * Float(domain.dtHours)
                var probability = [Float](repeating: 0, count: nLocations)

                for member in 0..<domain.countEnsembleMember {
                    guard let precip = await precipStorage.get(variable: .total_precipitation_6hr, timestamp: timestamp, member: member)?.data else {
                        continue
                    }
                    for i in precip.indices where precip[i] >= threshold {
                        probability[i] += 1
                    }
                }
                probability.multiplyAdd(multiply: 100 / Float(domain.countEnsembleMember), add: 0)
                try await writer.write(member: 1, variable: ProbabilityVariable.precipitation_probability, data: probability)
            }

            let handles = try await writer.finalise()
            allHandles.append(contentsOf: handles)
            logger.info("Completed timestep \(timeIdx): \(handles.count) variable handles")
        }

        guard !allHandles.isEmpty else {
            logger.warning("No WeatherNext data produced")
            return
        }

        try await GenericVariableHandle.convert(
            logger: logger,
            client: application.http1Client,
            domain: domain,
            createNetcdf: createNetcdf,
            run: run,
            handles: allHandles,
            concurrent: concurrent,
            writeUpdateJson: true,
            uploadS3Bucket: uploadS3Bucket,
            uploadS3OnlyProbabilities: uploadS3OnlyProbabilities,
            generateFullRun: false,
            generateTimeSeries: true
        )
    }

    // MARK: – Marker polling

    /// Poll the Zarr `success` marker file instead of the old OM marker.
    func waitForZarrMarker(
        client: HTTPClient,
        logger: Logger,
        targetRun: Timestamp,
        deadline: Date,
        server: String
    ) async throws {
        let baseInterval: TimeInterval = 60
        let maxInterval: TimeInterval = 300
        var attempt = 0

        while true {
            attempt += 1
            let successPath = WeatherNextDomain.zarrSuccessPath(server: server, run: targetRun)
            // Strip gs://weathernext/ prefix to get the object path for S3CompatibleStorage
            let objectPath = String(successPath.dropFirst("gs://weathernext/".count))
            logger.info("Checking Zarr success marker: \(successPath)")

            do {
                let token = try await GoogleCloudStorageAuth(
                    client: client,
                    logger: logger
                ).getAccessToken()
                let storage = try S3CompatibleStorage(
                    baseURL: "https://storage.googleapis.com/weathernext",
                    additionalHeaders: ["Authorization": "Bearer \(token)"]
                )
                if try await storage.exists(path: objectPath) {
                    logger.info("Zarr success marker found for run \(targetRun.iso8601_YYYY_MM_dd_HH_mm). Proceeding.")
                    return
                }
            } catch {
                logger.warning("Error checking Zarr marker (attempt \(attempt)): \(error)")
            }

            let wait = min(baseInterval * Double(attempt), maxInterval)
            if Date().addingTimeInterval(wait) > deadline {
                throw WeatherNextDownloaderError.notImplemented(
                    "Timed out waiting for Zarr run \(targetRun.iso8601_YYYY_MM_dd_HH_mm) to appear"
                )
            }
            logger.info("Zarr marker not yet present. Waiting \(wait.rounded())s for target \(targetRun.iso8601_YYYY_MM_dd_HH_mm)...")
            try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
    }
}

// MARK: – Error type

enum WeatherNextDownloaderError: Error {
    case notImplemented(String)
    case missingVariable(String)
    case unexpectedDimensions(String)
}
