import Foundation
import Vapor
import OmFileFormat

/**
 Downloader for Google DeepMind WeatherNext-2 ensemble data.

 Source layout:
 `gs://om-weathernext/output/{modelrun-in-iso8601}/{timestamp-in-iso8601}.om`

 Notes:
 - Input files are preprocessed `.om` files.
 - Each source file contains one valid time.
 - Each raw variable has dimensions `[member, lat, lon]`.
 - Processing is intentionally stream-like to avoid loading the full source file into memory.
 */
struct DownloadWeatherNextCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Option(name: "server", help: "Root path. Default: gs://om-weathernext/output/")
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
            // Determine the expected run from the domain's delay-based lastRun, then
            // wait for the marker file to confirm that run is actually available.
            let targetRun = domain.lastRun
            let deadline = Date().addingTimeInterval(TimeInterval(6 * 3600)) // 6-hour hard deadline
            try await waitForMarker(
                client: context.application.dedicatedHttpClient,
                logger: logger,
                targetRun: targetRun,
                deadline: deadline
            )
            run = targetRun
        }

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let server = signature.server ?? "gs://om-weathernext/output/"
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
        logger.info("Processing \(timestamps.count) WeatherNext timesteps")

        var localFiles = [String]()
        localFiles.reserveCapacity(timestamps.count)
        for timestamp in timestamps {
            let source = WeatherNextSourcePath(server: server, run: run, validTime: timestamp)
            let localFile = "\(domain.downloadDirectory)\(timestamp.iso8601_YYYY_MM_dd_HHmm).om"

            logger.info("Processing \(source.remotePath)")

            if !processLocalOnly {
                if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: localFile) {
                    try await GoogleCloudStorage.download(
                        client: application.dedicatedHttpClient,
                        logger: application.logger,
                        remotePath: source.remotePath,
                        localFile: localFile
                    )
                }
            } else if !FileManager.default.fileExists(atPath: localFile) {
                logger.info("Skipping missing local file: \(localFile)")
            }
            localFiles.append(localFile)
        }

        var available = [(time: Timestamp, path: String, source: WeatherNextSourceFile)]()
        available.reserveCapacity(localFiles.count)
        for (timestamp, localFile) in zip(timestamps, localFiles) {
            guard FileManager.default.fileExists(atPath: localFile) else {
                continue
            }
            available.append((timestamp, localFile, try await WeatherNextSourceFile(path: localFile, domain: domain)))
        }

        guard !available.isEmpty else {
            logger.warning("No WeatherNext files available for conversion")
            return
        }

        try await convertAndWrite(
            application: application,
            domain: domain,
            run: run,
            available: available,
            concurrent: concurrent,
            createNetcdf: createNetcdf,
            uploadS3Bucket: uploadS3Bucket,
            uploadS3OnlyProbabilities: uploadS3OnlyProbabilities,
        )
    }

    // MARK: – Main conversion entry point

    func convertAndWrite(
        application: Application,
        domain: WeatherNextDomain,
        run: Timestamp,
        available: [(time: Timestamp, path: String, source: WeatherNextSourceFile)],
        concurrent: Int,
        createNetcdf: Bool,
        uploadS3Bucket: String?,
        uploadS3OnlyProbabilities: Bool,
    ) async throws {
        let logger = application.logger
        let sourceHandles = makeSourceHandles(domain: domain, available: available)
        let ensembleMeanHandles = try await calculateEnsembleMean(
            logger: logger, 
            domain: domain, 
            run: run,
            sourceHandles: sourceHandles,
            concurrent: concurrent
        )
        let cloudCoverHandles = try await preprocessCloudCover(
            logger: logger, 
            domain: domain, 
            available: available, 
            concurrent: concurrent
        )

        let probabilityHandles = try await makeProbabilityHandles(
            logger: logger, 
            domain: domain,
            run: run,
            available: available
        )
        let allHandles = sourceHandles + cloudCoverHandles + ensembleMeanHandles + probabilityHandles 

        try await GenericVariableHandle.convert(
            logger: logger,
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

    /// For each `(entry, member)` triplet, read every RH pressure level once over the
    /// full spatial grid, derive the three cloud-cover tiers and total, and store them in
    /// temporary spatial OM files.  Returns a flat list of `GenericVariableHandle`s – one
    /// per `(time, member, cloudCoverVariable)` – backed by those temp files so that the
    /// downstream tile-read path never has to re-derive cloud cover from raw RH data.
    func preprocessCloudCover(
        logger: Logger,
        domain: WeatherNextDomain,
        available: [(time: Timestamp, path: String, source: WeatherNextSourceFile)],
        concurrent: Int
    ) async throws -> [GenericVariableHandle] {
        let fullY = 0..<UInt64(domain.grid.ny)
        let fullX = 0..<UInt64(domain.grid.nx)
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: 1, nTime: 1)

        var handles = [GenericVariableHandle]()
        handles.reserveCapacity(
            available.count * domain.countEnsembleMember * 4 // low + mid + high + total
        )

        for entry in available {
            let source = entry.source

            for member in 0..<domain.countEnsembleMember {
                let memberRange = UInt64(member)..<UInt64(member+1)  
                // Helper that reads one full-grid RH level for this member.
                func readRH(_ level: WeatherNextPressureLevel) async throws -> [Float] {
                    try await source.arrays[.pressure(.init(variable: .relative_humidity, level: level))]!.read(
                        range: [memberRange, fullY, fullX]
                    )
                }

                // Low cloud cover: 1000 / 925 / 850 hPa
                let lowCC = Meteorology.cloudCoverFromRH([
                    (rh: try await readRH(.hPa1000), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 1000)),
                    (rh: try await readRH(.hPa925),  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 925)),
                    (rh: try await readRH(.hPa850),  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 850))
                ])

                // Mid cloud cover: 700 / 600 / 500 / 400 hPa
                let midCC = Meteorology.cloudCoverFromRH([
                    (rh: try await readRH(.hPa700), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 700)),
                    (rh: try await readRH(.hPa600), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 600)),
                    (rh: try await readRH(.hPa500), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 500)),
                    (rh: try await readRH(.hPa400), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 400))
                ])

                // High cloud cover: 300 / 250 / 200 / 150 / 100 / 50 hPa
                let highCC = Meteorology.cloudCoverFromRH([
                    (rh: try await readRH(.hPa300), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 300)),
                    (rh: try await readRH(.hPa250), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 250)),
                    (rh: try await readRH(.hPa200), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 200)),
                    (rh: try await readRH(.hPa150), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 150)),
                    (rh: try await readRH(.hPa100), rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 100)),
                    (rh: try await readRH(.hPa50),  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 50))
                ])

                let totalCC = Meteorology.cloudCoverTotal(low: lowCC, mid: midCC, high: highCC)

                let ccByVariable: [(variable: WeatherNextVariable, data: [Float])] = [
                    (.cloud_cover_low,  lowCC),
                    (.cloud_cover_mid,  midCC),
                    (.cloud_cover_high, highCC),
                    (.cloud_cover,      totalCC)
                ]

                for (variable, data) in ccByVariable {
                    let fn = try writer.writeTemporary(
                        compressionType: .pfor_delta2d_int16,
                        scalefactor: 10,
                        all: data
                    )
                    try await handles.append(
                        GenericVariableHandle(
                            variable: variable,
                            time: entry.time,
                            member: member,
                            fn: fn,
                            domain: domain
                        )
                    )
                }
            }
        }
        return handles
    }

    func calculateEnsembleMean(
        logger: Logger,
        domain: WeatherNextDomain,
        run: Timestamp,
        sourceHandles: [GenericVariableHandle],
        concurrent: Int
    ) async throws -> [GenericVariableHandle] {
        logger.info("Calculating ensemble mean")
        logger.info("Iterating over \(sourceHandles.count) source handles")

        guard let ensembleMeanDomain = domain.ensembleMeanDomain else {
            fatalError("ensembleMeanDomain not defined")
        }
        
        var handles: [GenericVariableHandle] = []
        for (_, timestepHandles) in sourceHandles.groupedPreservedOrder(by: { "\($0.time)" }) {
            let time = timestepHandles.first!.time.range.first!
            logger.info("Processing time step \(time.iso8601_YYYY_MM_dd_HH_mm)")
            logger.info("File \(timestepHandles.first!.variable.omFileName.file)")
            logger.info("Count \(timestepHandles.count)")

            let writer = OmSpatialTimestepWriter(domain: ensembleMeanDomain, run: run, time: time, storeOnDisk: false, realm: nil, logger: logger) 
            let calculator = EnsembleMeanCalculator()
            
            for (_, variableHandles) in timestepHandles.groupedPreservedOrder(by: { "\($0.variable)" }) {
                logger.info("Processing variable \(variableHandles.first!.variable)")
                logger.info("Count \(variableHandles.count)")
                for handle in variableHandles {
                    guard handle.time.count == 1 else {
                        fatalError("Ensemble stats currently require single-timestep handles")
                    }
                    let fullY = 0..<UInt64(domain.grid.ny)
                    let fullX = 0..<UInt64(domain.grid.nx)
                    let memberRange = UInt64(handle.member)..<UInt64(handle.member+1)
                    let data = try await handle.reader.read(range: [memberRange, fullY, fullX])
                    await calculator.ingest(
                        variable: handle.variable,
                        spreadVariable: handle.variable.asSpreadVariableGeneric,
                        data: data
                    )
                }
            }
            try await calculator.calculateAndWrite(to: writer)
            handles += try await writer.finalise()
            logger.info("handles.count \(handles.count)")
        }
  
        return handles
    }

    func makeSourceHandles(
        domain: WeatherNextDomain,
        available: [(time: Timestamp, path: String, source: WeatherNextSourceFile)],
    ) -> [GenericVariableHandle] {
        // Start empty
        var handles: [GenericVariableHandle] = []
        let nonCloudVariables = WeatherNextVariable.allOutputVariables.filter { !$0.isCloudCoverDerived }
        handles.reserveCapacity(
            handles.count + available.count * nonCloudVariables.count * domain.countEnsembleMember
        )

        for entry in available {
            let time = TimerangeDt(start: entry.time, nTime: 1, dtSeconds: domain.dtSeconds)
            for variable in nonCloudVariables {
                for member in 0..<domain.countEnsembleMember {
                    let source = entry.source
                    handles.append(GenericVariableHandle(
                        variable: variable,
                        time: time,
                        member: member,
                        reader: source.arrays[variable]!,
                        domain: domain,
                    ))
                }
            }
        }
        return handles
    }

    func makeProbabilityHandles(
        logger: Logger, 
        domain: WeatherNextDomain,
        run: Timestamp,
        available: [(time: Timestamp, path: String, source: WeatherNextSourceFile)]
    ) async throws -> [GenericVariableHandle] {
        guard domain.countEnsembleMember > 1,
              WeatherNextVariable.allOutputVariables.contains(.total_precipitation_6hr)
        else {
            return []
        }

        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil, logger: logger)

        let threshold = Float(0.1) * Float(domain.dtHours)
        for entry in available {
            let source = entry.source

            let fullY = 0..<UInt64(domain.grid.ny)
            let fullX = 0..<UInt64(domain.grid.nx)
            let nLoc = Int(fullY.count * fullX.count)
            var probability = [Float](repeating: 0, count: nLoc)

            for member in 0..<domain.countEnsembleMember {
                let memberRange = UInt64(member)..<UInt64(member+1)  
                let precip = try await source.arrays[.total_precipitation_6hr]!.read(range: [memberRange, fullY, fullX])
                for i in precip.indices where precip[i] >= threshold {
                    probability[i] += 1
                }
            }

            probability.multiplyAdd(multiply: 100 / Float(domain.countEnsembleMember), add: 0)
            try await writer.write(
                time: entry.time, 
                member: 1, 
                variable: ProbabilityVariable.precipitation_probability, 
                data: probability
            )
        }
        return try await writer.finalise()
    }

    // MARK: – Marker polling

    func waitForMarker(
        client: HTTPClient,
        logger: Logger,
        targetRun: Timestamp,
        deadline: Date
    ) async throws {
        let baseInterval: TimeInterval = 60
        let maxInterval: TimeInterval = 300
        var attempt = 0

        struct MarkerJson: Decodable {
            let data: String
        }

        while true {
            attempt += 1
            let marker = try await GoogleCloudStorage.readAndDecode(
                MarkerJson.self,
                client: client,
                logger: logger,
                remotePath: WeatherNextDomain.markerFilePath
            )
            let currentRun = try WeatherNextDomain.parseTimestampFromMarker(marker.data)
            if currentRun >= targetRun {
                logger.info("Marker reports run \(currentRun.iso8601_YYYY_MM_dd_HH_mm) (target: \(targetRun.iso8601_YYYY_MM_dd_HH_mm)). Proceeding.")
                return
            }

            let wait = min(baseInterval * Double(attempt), maxInterval)
            if Date().addingTimeInterval(wait) > deadline {
                throw WeatherNextDownloaderError.notImplemented(
                    "Timed out waiting for run \(targetRun.iso8601_YYYY_MM_dd_HH_mm) to appear in marker file"
                )
            }
            logger.info("Marker still at \(currentRun.iso8601_YYYY_MM_dd_HH_mm). Waiting \(wait.rounded())s for target \(targetRun.iso8601_YYYY_MM_dd_HH_mm)...")
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

// MARK: – Source path helper

struct WeatherNextSourcePath {
    let server: String
    let run: Timestamp
    let validTime: Timestamp

    var remotePath: String {
        "\(server)\(run.iso8601_YYYY_MM_dd_HH_mm_ssZ)/\(validTime.iso8601_YYYY_MM_dd_HH_mm_ssZ).om"
    }
}

// MARK: – Source file adapter

final class WeatherNextSourceFile: Sendable {
    let domain: WeatherNextDomain
    let arrays: [WeatherNextVariable: OmFileReaderArray<MmapFile, Float>]

    init(path: String, domain: WeatherNextDomain) async throws {
        self.domain = domain
        let root = try await OmFileReader(mmapFile: path)
        self.arrays = try await Self.openVariableArrays(
            root: root,
            variables: Self.requiredSourceVariables(for: WeatherNextVariable.allOutputVariables),
            domain: domain
        )
    }

    static func requiredSourceVariables(for outputVariables: [WeatherNextVariable]) -> [WeatherNextVariable] {
        var required = Set(outputVariables.filter { !$0.isCloudCoverDerived })
        if outputVariables.contains(where: \.isCloudCoverDerived) {
            for level in WeatherNextPressureLevel.allCases {
                required.insert(.pressure(.init(variable: .relative_humidity, level: level)))
            }
        }
        return Array(required)
    }

    static func openVariableArrays<Backend>(
        root: OmFileReader<Backend>,
        variables: [WeatherNextVariable],
        domain: WeatherNextDomain
    ) async throws -> [WeatherNextVariable: OmFileReaderArray<Backend, Float>] {
        var result = [WeatherNextVariable: OmFileReaderArray<Backend, Float>]()
        result.reserveCapacity(variables.count)

        for variable in variables {
            let sourceName = variable.rawValue
            guard let child = try await root.getChild(name: sourceName),
                  let array = child.asArray(of: Float.self) else {
                throw WeatherNextDownloaderError.notImplemented("Could not open source variable \(sourceName)")
            }

            let dims = Array(array.getDimensions())
            guard dims.count == 3 else {
                throw WeatherNextDownloaderError.unexpectedDimensions("Unexpected dimensions for \(sourceName): \(dims)")
            }
            guard dims[0] == UInt64(domain.countEnsembleMember),
                  dims[1] == UInt64(domain.grid.ny),
                  dims[2] == UInt64(domain.grid.nx) else {
                throw WeatherNextDownloaderError.unexpectedDimensions("Unexpected shape for \(sourceName): \(dims)")
            }
            result[variable] = array
        }
        return result
    }
}
