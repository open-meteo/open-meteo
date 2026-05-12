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
            uploadS3OnlyProbabilities: uploadS3OnlyProbabilities
        )
    }

    // MARK: – Main conversion entry point

    func convertAndWrite(
        application: Application,
        domain: WeatherNextDomain,
        run: Timestamp,
        available: [(time: Timestamp, path: String, source: WeatherNextSourceFile)],
        concurrent _: Int,
        createNetcdf: Bool,
        uploadS3Bucket: String?,
        uploadS3OnlyProbabilities: Bool
    ) async throws {
        let logger = application.logger
        let mainHandles = makeSourceHandles(domain: domain, available: available)

        try await GenericVariableHandle.convert(
            logger: logger,
            domain: domain,
            createNetcdf: createNetcdf,
            run: run,
            handles: mainHandles,
            concurrent: 1,
            writeUpdateJson: true,
            uploadS3Bucket: uploadS3Bucket,
            uploadS3OnlyProbabilities: uploadS3OnlyProbabilities,
            generateFullRun: false,
            generateTimeSeries: true
        )

        if let ensembleMeanDomain = domain.ensembleMeanDomain {
            let meanHandles = try await SpatialEnsembleStats.calculate(
                logger: logger,
                run: run,
                ensembleMeanDomain: ensembleMeanDomain,
                handles: mainHandles
            )
            try await GenericVariableHandle.convert(
                logger: logger,
                domain: ensembleMeanDomain,
                createNetcdf: createNetcdf,
                run: run,
                handles: meanHandles,
                concurrent: 1,
                writeUpdateJson: true,
                uploadS3Bucket: uploadS3Bucket,
                uploadS3OnlyProbabilities: uploadS3OnlyProbabilities,
                generateFullRun: ensembleMeanDomain.countEnsembleMember == 1,
                generateTimeSeries: true
            )
        }

        let probabilityHandles = try await makeProbabilityHandles(domain: domain, available: available)
        if !probabilityHandles.isEmpty {
            try await GenericVariableHandle.convert(
                logger: logger,
                domain: domain,
                createNetcdf: createNetcdf,
                run: run,
                handles: probabilityHandles,
                concurrent: 1,
                writeUpdateJson: true,
                uploadS3Bucket: uploadS3Bucket,
                uploadS3OnlyProbabilities: uploadS3OnlyProbabilities,
                generateFullRun: false,
                generateTimeSeries: true
            )
        } else if let uploadS3Bucket, uploadS3OnlyProbabilities {
            try await domain.domainRegistry.syncToS3(
                logger: logger,
                bucket: uploadS3Bucket,
                variables: [ProbabilityVariable.precipitation_probability]
            )
        }
    }

    func makeSourceHandles(
        domain: WeatherNextDomain,
        available: [(time: Timestamp, path: String, source: WeatherNextSourceFile)]
    ) -> [GenericVariableHandle] {
        let dimensions = [UInt64(domain.grid.ny), UInt64(domain.grid.nx)]
        var handles = [GenericVariableHandle]()
        handles.reserveCapacity(available.count * WeatherNextVariable.allOutputVariables.count * domain.countEnsembleMember)

        for entry in available {
            let time = TimerangeDt(start: entry.time, nTime: 1, dtSeconds: domain.dtSeconds)
            for variable in WeatherNextVariable.allOutputVariables {
                for member in 0..<domain.countEnsembleMember {
                    let source = entry.source
                    handles.append(GenericVariableHandle(
                        variable: variable,
                        time: time,
                        member: member,
                        domain: domain,
                        dimensions: dimensions,
                        readRange: { range in
                            guard range.count == 2 else {
                                fatalError("WeatherNext source handles only support 2D spatial reads")
                            }
                            return try await source.readSpatial(
                                variable: variable,
                                member: member,
                                yRange: range[0],
                                xRange: range[1]
                            )
                        }
                    ))
                }
            }
        }
        return handles
    }

    func makeProbabilityHandles(
        domain: WeatherNextDomain,
        available: [(time: Timestamp, path: String, source: WeatherNextSourceFile)]
    ) async throws -> [GenericVariableHandle] {
        guard domain.countEnsembleMember > 1,
              WeatherNextVariable.allOutputVariables.contains(.total_precipitation_6hr)
        else {
            return []
        }

        let threshold = Float(0.1) * Float(domain.dtSeconds / 3600)
        let dimensions = [UInt64(domain.grid.ny), UInt64(domain.grid.nx)]
        let fullY = 0..<UInt64(domain.grid.ny)
        let fullX = 0..<UInt64(domain.grid.nx)
        var handles = [GenericVariableHandle]()
        handles.reserveCapacity(available.count)

        for entry in available {
            var probability = [Float](repeating: 0, count: domain.grid.count)
            for member in 0..<domain.countEnsembleMember {
                let precip = try await entry.source.readSpatial(
                    variable: .total_precipitation_6hr,
                    member: member,
                    yRange: fullY,
                    xRange: fullX
                )
                for i in precip.indices where precip[i] >= threshold {
                    probability[i] += 1
                }
            }
            probability.multiplyAdd(multiply: 100 / Float(domain.countEnsembleMember), add: 0)

            let time = TimerangeDt(start: entry.time, nTime: 1, dtSeconds: domain.dtSeconds)
            let probabilityData = probability
            let nx = domain.grid.nx
            handles.append(GenericVariableHandle(
                variable: ProbabilityVariable.precipitation_probability,
                time: time,
                member: 0,
                domain: domain,
                dimensions: dimensions,
                readRange: { range in
                    guard range.count == 2 else {
                        fatalError("Probability handles only support 2D spatial reads")
                    }
                    return Self.make2DSlice(
                        data: probabilityData,
                        nx: nx,
                        yRange: range[0],
                        xRange: range[1]
                    )
                }
            ))
        }
        return handles
    }

    static func make2DSlice(data: [Float], nx: Int, yRange: Range<UInt64>, xRange: Range<UInt64>) -> [Float] {
        if yRange.count == 0 || xRange.count == 0 {
            return []
        }
        if yRange.lowerBound == 0,
           yRange.upperBound == UInt64(data.count / nx),
           xRange.lowerBound == 0,
           xRange.upperBound == UInt64(nx) {
            return data
        }

        let nY = Int(yRange.count)
        let nX = Int(xRange.count)
        var out = [Float]()
        out.reserveCapacity(nY * nX)
        for y in Int(yRange.lowerBound)..<Int(yRange.upperBound) {
            let rowStart = y * nx + Int(xRange.lowerBound)
            let rowEnd = rowStart + nX
            out.append(contentsOf: data[rowStart..<rowEnd])
        }
        return out
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

    private func shiftedXRanges(for xRange: Range<UInt64>) -> (primary: Range<UInt64>, secondary: Range<UInt64>?) {
        guard !xRange.isEmpty else {
            return (0..<0, nil)
        }
        let nx = UInt64(domain.grid.nx)
        let half = nx / 2
        let srcStart = (xRange.lowerBound + half) % nx
        let srcEnd = (xRange.upperBound - 1 + half) % nx + 1
        if srcStart < srcEnd {
            return (srcStart..<srcEnd, nil)
        }
        return (srcStart..<nx, 0..<srcEnd)
    }

    func readSpatial(
        variable: WeatherNextVariable,
        member: Int,
        yRange: Range<UInt64>,
        xRange: Range<UInt64>
    ) async throws -> [Float] {
        if variable.isCloudCoverDerived {
            return try await readCloudCoverTile(variable: variable, member: member, yRange: yRange, xRange: xRange)
        }
        return try await readRawTile(variable: variable, member: member, yRange: yRange, xRange: xRange)
    }

    private func readRawTile(
        variable: WeatherNextVariable,
        member: Int,
        yRange: Range<UInt64>,
        xRange: Range<UInt64>
    ) async throws -> [Float] {
        guard let array = arrays[variable] else {
            throw WeatherNextDownloaderError.missingVariable(variable.rawValue)
        }
        let nY = Int(yRange.count)
        let nX = Int(xRange.count)
        var out = [Float](repeating: .nan, count: nY * nX)

        if nY == 0 || nX == 0 {
            return out
        }

        let (primaryRange, secondaryRange) = shiftedXRanges(for: xRange)

        if let secondaryRange {
            let nLeft = Int(primaryRange.upperBound - primaryRange.lowerBound)
            let nRight = Int(secondaryRange.upperBound - secondaryRange.lowerBound)
            var leftBuf = [Float](repeating: .nan, count: nY * nLeft)
            var rightBuf = [Float](repeating: .nan, count: nY * nRight)

            try await array.read(
                into: &leftBuf,
                range: [UInt64(member)..<UInt64(member + 1), yRange, primaryRange]
            )
            try await array.read(
                into: &rightBuf,
                range: [UInt64(member)..<UInt64(member + 1), yRange, secondaryRange]
            )

            for y in 0..<nY {
                let outBase = y * nX
                let leftBase = y * nLeft
                let rightBase = y * nRight
                for x in 0..<nLeft { out[outBase + x] = leftBuf[leftBase + x] }
                for x in 0..<nRight { out[outBase + nLeft + x] = rightBuf[rightBase + x] }
            }
            return out
        }

        try await array.read(
            into: &out,
            range: [UInt64(member)..<UInt64(member + 1), yRange, primaryRange]
        )
        return out
    }

    private func readCloudCoverTile(
        variable: WeatherNextVariable,
        member: Int,
        yRange: Range<UInt64>,
        xRange: Range<UInt64>
    ) async throws -> [Float] {

        // Helper to read specific levels and compute CC
        let computeCC = { @Sendable (levels: [WeatherNextPressureLevel]) async throws -> [Float] in
            var inputs: [(rh: [Float], rhCrit: Float)] = []
            for level in levels {
                let rh = try await self.readRawTile(
                    variable: .pressure(.init(variable: .relative_humidity, level: level)),
                    member: member, yRange: yRange, xRange: xRange
                )
                let rhCrit = Meteorology.relativeHumidityThreshold(pressureHPa: Float(level.rawValue))
                inputs.append((rh: rh, rhCrit: rhCrit))
            }
            return Meteorology.cloudCoverFromRH(inputs)
        }

        switch variable {
        case .cloud_cover_low:
            return try await computeCC([.hPa1000, .hPa925, .hPa850])

        case .cloud_cover_mid:
            return try await computeCC([.hPa700, .hPa600, .hPa500, .hPa400])

        case .cloud_cover_high:
            return try await computeCC([.hPa300, .hPa250, .hPa200, .hPa150, .hPa100, .hPa50])

        case .cloud_cover:
            // Total cloud cover needs all of them
            async let low = computeCC([.hPa1000, .hPa925, .hPa850])
            async let mid = computeCC([.hPa700, .hPa600, .hPa500, .hPa400])
            async let high = computeCC([.hPa300, .hPa250, .hPa200, .hPa150, .hPa100, .hPa50])

            return try await Meteorology.cloudCoverTotal(low: low, mid: mid, high: high)

        default:
            throw WeatherNextDownloaderError.missingVariable(variable.rawValue)
        }
    }

    private func readCloudCoverTiles(
        member: Int,
        yRange: Range<UInt64>,
        xRange: Range<UInt64>
    ) async throws -> [WeatherNextVariable: [Float]] {
        var rh = [WeatherNextPressureLevel: [Float]]()
        rh.reserveCapacity(WeatherNextPressureLevel.allCases.count)
        for level in WeatherNextPressureLevel.allCases {
            rh[level] = try await readRawTile(
                variable: .pressure(.init(variable: .relative_humidity, level: level)),
                member: member,
                yRange: yRange,
                xRange: xRange
            )
        }

        let lowCC  = Meteorology.cloudCoverFromRH([
            (rh: rh[.hPa1000]!, rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 1000)),
            (rh: rh[.hPa925]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 925)),
            (rh: rh[.hPa850]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 850))
        ])
        let midCC  = Meteorology.cloudCoverFromRH([
            (rh: rh[.hPa700]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 700)),
            (rh: rh[.hPa600]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 600)),
            (rh: rh[.hPa500]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 500)),
            (rh: rh[.hPa400]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 400))
        ])
        let highCC = Meteorology.cloudCoverFromRH([
            (rh: rh[.hPa300]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 300)),
            (rh: rh[.hPa250]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 250)),
            (rh: rh[.hPa200]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 200)),
            (rh: rh[.hPa150]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 150)),
            (rh: rh[.hPa100]!,  rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 100)),
            (rh: rh[.hPa50]!,   rhCrit: Meteorology.relativeHumidityThreshold(pressureHPa: 50))
        ])

        return [
            .cloud_cover_low: lowCC,
            .cloud_cover_mid: midCC,
            .cloud_cover_high: highCC,
            .cloud_cover: Meteorology.cloudCoverTotal(low: lowCC, mid: midCC, high: highCC)
        ]
    }
}
