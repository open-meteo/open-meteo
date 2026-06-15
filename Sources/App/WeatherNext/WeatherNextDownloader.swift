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
        uploadS3Bucket: String?,
        uploadS3OnlyProbabilities: Bool,
        createNetcdf: Bool
    ) async throws {
        let logger = application.logger
        let timestamps = domain.forecastTimestamps(for: run)
        logger.info("Processing \(timestamps.count) WeatherNext timesteps from Zarr")

        // Units are specified in https://developers.google.com/weathernext/guides/model-specs-vmg#data_at_6hr_forecast_granularity
        let surfaceZarrNames: [(zarr: String, surfaceVar: WeatherNextSurfaceVariable, transform: @Sendable ([Float]) -> [Float])] = [
            ("2m_temperature", .temperature_2m, { $0.map { $0 - 273.15 } }),
            ("mean_sea_level_pressure", .pressure_msl, { $0.map { $0 * 0.01 } }),
            ("sea_surface_temperature", .sea_surface_temperature, { $0.map { $0 - 273.15 } }),
            ("total_precipitation_6hr", .precipitation, { $0.map { $0 * 1000.0 } }),
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
        let httpClient = application.dedicatedHttpClient

        let allHandles: [GenericVariableHandle] = try await timestamps.enumerated().mapConcurrent(nConcurrent: concurrent) { (timeIdx, timestamp) in
            logger.info("Processing timestep \(timeIdx) / \(timestamps.count): \(timestamp.iso8601_YYYY_MM_dd_HH_mm)")
            do {

            // Fresh token + storage + Zarr group per timestep so the OAuth token
            // never expires mid-run (token lifetime is 1 hour).
            let googleToken = try await GoogleCloudStorageAuth(
                client: httpClient,
                logger: logger
            ).getAccessToken()
            let storage = try S3CompatibleStorage(
                baseURL: "https://storage.googleapis.com/weathernext",
                retryingClient: .init(
                    httpClient: httpClient, 
                    config: .init(
                        maxAttempts: 5, 
                        baseDelay: .milliseconds(500), 
                        maxDelay: .seconds(60), 
                        jitter: 0.2, 
                        timeout: .seconds(180)
                    ),
                ),
                additionalHeaders: ["Authorization": "Bearer \(googleToken)"]
            )
            let root = try await ZarrGroup(storage: storage, path: zarrRootPath)

            // Read the level coordinate array to map hPa → Zarr level index
            let levelArray = try await root.openArray(name: "level")
            let zarrLevelValuesRaw: [Int32] = try await levelArray.retrieveArraySubset([0..<levelArray.shape[0]])
            let zarrLevelValues = zarrLevelValuesRaw.map(Int.init)
            let levelIndexMap = zarrLevelValues.enumerated().reduce(into: [Int: Int]()) { $0[$1.element] = $1.offset }

            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: false, realm: nil, logger: logger, ensembleMeanDomain: domain.ensembleMeanDomain)
            let writerProbabilities = domain.countEnsembleMember > 1 ? OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: true, realm: nil, logger: logger) : nil
            
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

            // Phase 1: flat task pool — reads, RH derivation, cloud cover.
            // All tasks for all members flow through a single foreachConcurrent
            // with no barriers.  Deadline tasks read SH + temp from Zarr,
            // compute RH, store it, and when the last RH level for a member
            // arrives they push cloud cover inline.  No CC task in the pool.
            // rhStorage is scoped tightly so its memory is freed before
            // precipitation probability and finalise run.
            let totalConcurrency = max(4, concurrent * 8)
            do {
                let rhStorage = VariablePerMemberStorage<WeatherNextPressureVariable>()
                // Look up SH and temp arrays once — deadline tasks read both per level
                let shArray = pressureZarrArrays.first(where: { $0.1 == .specific_humidity })!.0
                let tempArray = pressureZarrArrays.first(where: { $0.1 == .temperature })!.0
                let verticalVelocityArray = pressureZarrArrays.first(where: { $0.1 == .vertical_velocity })!.0

                // Surface + other pressure reads + deadline tasks — single flat list
                var allTasks = [@Sendable () async throws -> Void]()
                allTasks.reserveCapacity(domain.countEnsembleMember * (zarrSurfaceArrays.count + allPressureReads.count + WeatherNextPressureLevel.allCases.count))

                for member in 0..<domain.countEnsembleMember {
                    // Surface variable reads
                    for (zarrArray, surfaceVar, transform) in zarrSurfaceArrays {
                        allTasks.append {
                            let raw = try await zarrArray.retrieveArraySubset(
                                [member..<member+1, timeIdx..<timeIdx+1, 0..<domain.grid.ny, 0..<domain.grid.nx]
                            ) as [Float]
                            var data = transform(raw)
                            data.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)

                            if surfaceVar == .precipitation && domain.countEnsembleMember > 1 {
                                await precipStorage.set(variable: surfaceVar, timestamp: timestamp, member: member, data: Array2D(data: data, nx: domain.grid.nx, ny: domain.grid.ny))
                            }
                            try await writer.write(member: member, variable: surfaceVar, data: data)
                        }
                    }

                    // Other pressure variable reads (everything except SH and temp)
                    for (zarrArray, pType, level, levelIdx) in allPressureReads where pType != .specific_humidity && pType != .temperature && pType != .vertical_velocity {
                        allTasks.append {
                            var data: [Float] = try await zarrArray.retrieveArraySubset(
                                [member..<member+1, timeIdx..<timeIdx+1, levelIdx..<levelIdx+1, 0..<domain.grid.ny, 0..<domain.grid.nx]
                            )
                            data.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)

                            let pVar = WeatherNextPressureVariable(variable: pType, level: level)
                            let wnVar = WeatherNextVariable.pressure(pVar)

                            switch pType {
                            case .geopotential_height:
                                let heightData = data.map { $0 / 9.80665 }
                                try await writer.write(member: member, variable: wnVar, data: heightData)
                            case .wind_u_component, .wind_v_component:
                                try await writer.write(member: member, variable: wnVar, data: data)
                            default:
                                try await writer.write(member: member, variable: wnVar, data: data)
                            }
                        }
                    }

                    // Deadline tasks: read SH + temp from Zarr for one level,
                    // compute RH, store it.  When all 13 levels are present
                    // the last task pushes cloud cover inline — no barrier.
                    for level in WeatherNextPressureLevel.allCases {
                        guard let levelIdx = levelIndexMap[level.level] else { continue }

                        let rhVar = WeatherNextPressureVariable(variable: .relative_humidity, level: level)
                        let tempVar = WeatherNextPressureVariable(variable: .temperature, level: level)
                        let verticalVelocityVar = WeatherNextPressureVariable(variable: .vertical_velocity, level: level)
                        let pressure = Float(level.level)

                        allTasks.append {
                            // Read SH, temp and vertical velocity for this level
                            var tempData: [Float] = try await tempArray.retrieveArraySubset(
                                [member..<member+1, timeIdx..<timeIdx+1, levelIdx..<levelIdx+1, 0..<domain.grid.ny, 0..<domain.grid.nx]
                            ).map { $0 - 273.15 } // convert from K to C
                            tempData.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)
                            
                            var verticalVelocityData: [Float] = try await verticalVelocityArray.retrieveArraySubset(
                                 [member..<member+1, timeIdx..<timeIdx+1, levelIdx..<levelIdx+1, 0..<domain.grid.ny, 0..<domain.grid.nx]
                            )
                            verticalVelocityData.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)

                            verticalVelocityData = Meteorology.verticalVelocityPressureToGeometric(omega: verticalVelocityData, temperature: tempData, pressureLevel: pressure)
                            try await writer.write(member: member, variable: WeatherNextVariable.pressure(verticalVelocityVar), data: verticalVelocityData)
                            _ = consume verticalVelocityData

                            var shData: [Float] = try await shArray.retrieveArraySubset(
                                [member..<member+1, timeIdx..<timeIdx+1, levelIdx..<levelIdx+1, 0..<domain.grid.ny, 0..<domain.grid.nx]
                            ).map { $0 * 1000 } // convert from kg/kg to g/kg
                            shData.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)
                            let rh = Meteorology.specificToRelativeHumidity(
                                specificHumidity: shData,
                                temperature: tempData,
                                pressure: pressure
                            )
                            _ = consume shData
                            
                            try await writer.write(member: member, variable: WeatherNextVariable.pressure(tempVar), data: tempData)

                            try await writer.write(member: member, variable: WeatherNextVariable.pressure(rhVar), data: rh)
                            
                            await rhStorage.set(variable: rhVar, timestamp: timestamp, member: member, data: Array2D(data: rh, nx: domain.grid.nx, ny: domain.grid.ny))

                            // If all 13 RH levels are now stored, push cloud cover.
                            // Double-execution is safe: the first CC removes the data,
                            // the second CC's `remove` returns nil → guard fails.
                            guard await !writer.contains(member: member, variable: WeatherNextSurfaceVariable.cloud_cover_low) else { return }
                            guard let rhData = await rhStorage.getAllRemoving(variables: [
                                .init(variable: .relative_humidity, level: .hPa1000),
                                .init(variable: .relative_humidity, level: .hPa925),
                                .init(variable: .relative_humidity, level: .hPa850),
                                .init(variable: .relative_humidity, level: .hPa700),
                                .init(variable: .relative_humidity, level: .hPa600),
                                .init(variable: .relative_humidity, level: .hPa500),
                                .init(variable: .relative_humidity, level: .hPa400),
                                .init(variable: .relative_humidity, level: .hPa300),
                                .init(variable: .relative_humidity, level: .hPa250),
                                .init(variable: .relative_humidity, level: .hPa200),
                                .init(variable: .relative_humidity, level: .hPa150),
                                .init(variable: .relative_humidity, level: .hPa100),
                                .init(variable: .relative_humidity, level: .hPa50),
                            ], timestamp: timestamp, member: member) else {
                                return
                            }

                            let lowCC = Meteorology.cloudCoverFromRH([
                                (rh: rhData[0].data, rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 1000)),
                                (rh: rhData[1].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 925)),
                                (rh: rhData[2].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 850))
                            ])
                            let midCC = Meteorology.cloudCoverFromRH([
                                (rh: rhData[3].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 700)),
                                (rh: rhData[4].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 600)),
                                (rh: rhData[5].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 500)),
                                (rh: rhData[6].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 400))
                            ])
                            let highCC = Meteorology.cloudCoverFromRH([
                                (rh: rhData[7].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 300)),
                                (rh: rhData[8].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 250)),
                                (rh: rhData[9].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 200)),
                                (rh: rhData[10].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 150)),
                                (rh: rhData[11].data,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 100)),
                                (rh: rhData[12].data,   rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 50))
                            ])
                            try await writer.write(member: member, variable: WeatherNextSurfaceVariable.cloud_cover_low, data: lowCC)
                            try await writer.write(member: member, variable: WeatherNextSurfaceVariable.cloud_cover_mid, data: midCC)
                            try await writer.write(member: member, variable: WeatherNextSurfaceVariable.cloud_cover_high, data: highCC)
                            let cloudcover = Meteorology.cloudCoverTotal(low: lowCC, mid: midCC, high: highCC)
                            try await writer.write(member: member, variable: WeatherNextSurfaceVariable.cloud_cover, data: cloudcover)
                        }
                    }
                }

                logger.info("Processing \(allTasks.count) tasks with concurrency \(totalConcurrency)")
                try await allTasks.foreachConcurrent(nConcurrent: totalConcurrency) { task in
                    do {
                        try await task()
                    } catch {
                        logger.error("Task failed in timestep \(timeIdx) (root cause): \(error)")
                        throw error
                    }
                }
                // rhStorage released here
            }

            // ---- Derive precipitation probability ----
            if let writerProbabilities {
                logger.info("Calculating precipitation probability for timestep \(timeIdx)")
                try await precipStorage.calculatePrecipitationProbability(precipitationVariable: .precipitation, dtHoursOfCurrentStep: domain.dtHours, writer: writerProbabilities)
            }

            let handles = try await writer.finalise() + (writerProbabilities?.finalise() ?? [])
            logger.info("Completed timestep \(timeIdx): \(handles.count) variable handles")
            return handles
            } catch {
                logger.error("Timestep \(timeIdx) (\(timestamp.iso8601_YYYY_MM_dd_HH_mm)) failed (root cause): \(error)")
                throw error
            }
        }.flatMap { $0 }

        guard !allHandles.isEmpty else {
            logger.warning("No WeatherNext data produced")
            return
        }

        try await GenericVariableHandle.convert(
            application: application,
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

    /// Poll the Zarr `success` marker file.
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
        let authProvider = GoogleCloudStorageAuth(
            client: client,
            logger: logger
        )

        while true {
            attempt += 1
            let successPath = WeatherNextDomain.zarrSuccessPath(server: server, run: targetRun)
            // Strip gs://weathernext/ prefix to get the object path for S3CompatibleStorage
            let objectPath = String(successPath.dropFirst("gs://weathernext/".count))
            logger.info("Checking Zarr success marker: \(successPath)")

            do {
                let token = try await authProvider.getAccessToken()
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
