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
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let server = signature.server ?? "gs://om-weathernext/output/"
        let nConcurrent = signature.concurrent ?? 1
        let generateFullRun = domain.countEnsembleMember == 1

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)

        let handles = try await download(
            application: context.application,
            domain: domain,
            run: run,
            server: server,
            concurrent: nConcurrent,
            skipFilesIfExisting: signature.skipExisting,
            processLocalOnly: signature.processLocalOnly,
            uploadS3Bucket: signature.uploadS3Bucket
        )

        try await GenericVariableHandle.convert(
            logger: logger,
            domain: domain,
            createNetcdf: signature.createNetcdf,
            run: run,
            handles: handles,
            concurrent: nConcurrent,
            writeUpdateJson: true,
            uploadS3Bucket: signature.uploadS3Bucket,
            uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities,
            generateFullRun: generateFullRun
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
        uploadS3Bucket: String?
    ) async throws -> [GenericVariableHandle] {
        let logger = application.logger

        let writer = OmSpatialMultistepWriter(
            domain: domain,
            run: run,
            storeOnDisk: true, // FIXME: change to false
            realm: nil,
            logger: logger,
            ensembleMeanDomain: domain.ensembleMeanDomain
        )

        let timestamps = domain.forecastTimestamps(for: run)
        logger.info("Processing \(timestamps.count) WeatherNext timesteps")

        let localFiles = try await timestamps.asyncMap { timestamp in
            let source = WeatherNextSourcePath(server: server, run: run, validTime: timestamp)
            let localFile = "\(domain.downloadDirectory)\(timestamp.iso8601_YYYY_MM_dd_HHmm).om"

            logger.info("Processing \(source.remotePath)")

            if !processLocalOnly {
                if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: localFile) {
                    try await fetchSourceFile(
                        application: application,
                        remotePath: source.remotePath,
                        localFile: localFile
                    )
                }
            } else if !FileManager.default.fileExists(atPath: localFile) {
                logger.info("Skipping missing local file: \(localFile)")
            }

            return localFile
        }

        // Collect probability handles across all timesteps
        let allHandles = try await zip(timestamps, localFiles).asyncMap { timestamp, localFile in
            guard FileManager.default.fileExists(atPath: localFile) else {
                return [GenericVariableHandle]()
            }

            return try await processWeatherNextFile(
                application: application,
                domain: domain,
                file: localFile,
                run: run,
                validTime: timestamp,
                writer: writer,
                concurrent: concurrent
            )
        }

        let mainHandles = try await writer.finalise(
            completed: true,
            validTimes: timestamps,
            uploadS3Bucket: uploadS3Bucket
        )

        return mainHandles + allHandles.flatMap { $0 }
    }

    func fetchSourceFile(
        application: Application,
        remotePath: String,
        localFile: String
    ) async throws {
        try await GoogleCloudStorage.download(
            client: application.dedicatedHttpClient,
            logger: application.logger,
            remotePath: remotePath,
            localFile: localFile
        )
    }

    func processWeatherNextFile(
        application: Application,
        domain: WeatherNextDomain,
        file: String,
        run: Timestamp,
        validTime: Timestamp,
        writer: OmSpatialMultistepWriter,
        concurrent: Int
    ) async throws -> [GenericVariableHandle] {
        let logger = application.logger

        logger.info("Writing timestep \(validTime.iso8601_YYYY_MM_dd_HH_mm)")

        let inMemoryPrecipitation = VariablePerMemberStorage<WeatherNextVariable>()

        try await Array(0..<domain.countEnsembleMember).foreachConcurrent(nConcurrent: concurrent) { member in
            let root = try await OmFileReader(file: file)
            let arrays = try await openVariableArrays(root: root, variables: WeatherNextVariable.rawVariables, domain: domain)

            var relativeHumidity = [WeatherNextPressureLevel: [Float]]()
            relativeHumidity.reserveCapacity(WeatherNextPressureLevel.allCases.count)

            for variable in WeatherNextVariable.rawVariables {
                let data = try await readMemberSlice(
                    array: try array(for: variable, in: arrays),
                    variable: variable,
                    member: member,
                    domain: domain
                )

                try await writer.write(
                    time: validTime,
                    member: member,
                    variable: variable,
                    data: data
                )

                if variable == .total_precipitation_6hr {
                    await inMemoryPrecipitation.set(
                        variable: variable,
                        timestamp: validTime,
                        member: member,
                        data: Array2D(data: data, nx: domain.grid.nx, ny: domain.grid.ny)
                    )
                }

                if let level = variable.pressureLevel, variable.isRelativeHumidityPressureLevel {
                    relativeHumidity[level] = data
                }
            }

            try await deriveCloudCover(
                writer: writer,
                validTime: validTime,
                member: member,
                relativeHumidity: relativeHumidity
            )
        }

        if domain.countEnsembleMember > 1 {
            let writerProbabilities = OmSpatialTimestepWriter(
                domain: domain,
                run: run,
                time: validTime,
                storeOnDisk: true,
                realm: nil,
                logger: logger
            )
            try await inMemoryPrecipitation.calculatePrecipitationProbability(
                precipitationVariable: .total_precipitation_6hr,
                dtHoursOfCurrentStep: domain.dtSeconds / 3600,
                writer: writerProbabilities
            )
            return try await writerProbabilities.finalise(
                completed: true,
                validTimes: [validTime],
                uploadS3Bucket: nil
            )
        }
        return []
    }

    func openVariableArrays<Backend>(
        root: OmFileReader<Backend>,
        variables: [WeatherNextVariable],
        domain: WeatherNextDomain
    ) async throws -> [WeatherNextVariable: OmFileReaderArray<Backend, Float>] {
        var arrays = [WeatherNextVariable: OmFileReaderArray<Backend, Float>]()
        arrays.reserveCapacity(variables.count)

        for variable in variables {
            let sourceName = variable.rawValue

            guard let child = try await root.getChild(name: sourceName),
                  let array = child.asArray(of: Float.self) else {
                throw WeatherNextDownloaderError.notImplemented("Could not open source variable \(sourceName)")
            }

            let dims = Array(array.getDimensions())
            guard dims.count == 3 else {
                throw WeatherNextDownloaderError.notImplemented("Unexpected dimensions for \(sourceName): \(dims)")
            }
            guard dims[0] == UInt64(domain.countEnsembleMember),
                  dims[1] == UInt64(domain.grid.ny),
                  dims[2] == UInt64(domain.grid.nx) else {
                throw WeatherNextDownloaderError.notImplemented("Unexpected shape for \(sourceName): \(dims)")
            }

            arrays[variable] = array
        }

        return arrays
    }

    func array<Backend>(
        for variable: WeatherNextVariable,
        in arrays: [WeatherNextVariable: OmFileReaderArray<Backend, Float>]
    ) throws -> OmFileReaderArray<Backend, Float> {
        guard let array = arrays[variable] else {
            throw WeatherNextDownloaderError.notImplemented("Missing cached source variable \(variable.rawValue)")
        }
        return array
    }

    func readMemberSlice<Backend>(
        array: OmFileReaderArray<Backend, Float>,
        variable: WeatherNextVariable,
        member: Int,
        domain: WeatherNextDomain
    ) async throws -> [Float] {
        let memberRange = UInt64(member)..<UInt64(member + 1)
        let latRange = UInt64(0)..<UInt64(domain.grid.ny)
        let lonRange = UInt64(0)..<UInt64(domain.grid.nx)

        var data = [Float](repeating: .nan, count: domain.grid.count)
        try await array.read(
            into: &data,
            range: [memberRange, latRange, lonRange],
            intoCubeOffset: [0, 0, 0],
            intoCubeDimension: [1, UInt64(domain.grid.ny), UInt64(domain.grid.nx)]
        )

        data.shift180Longitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)

        return data
    }

    func deriveCloudCover(
        writer: OmSpatialMultistepWriter,
        validTime: Timestamp,
        member: Int,
        relativeHumidity: [WeatherNextPressureLevel: [Float]]
    ) async throws {
        guard
            let rh1000 = relativeHumidity[.hPa1000],
            let rh925 = relativeHumidity[.hPa925],
            let rh850 = relativeHumidity[.hPa850],
            let rh700 = relativeHumidity[.hPa700],
            let rh600 = relativeHumidity[.hPa600],
            let rh500 = relativeHumidity[.hPa500],
            let rh400 = relativeHumidity[.hPa400],
            let rh300 = relativeHumidity[.hPa300],
            let rh250 = relativeHumidity[.hPa250],
            let rh200 = relativeHumidity[.hPa200],
            let rh150 = relativeHumidity[.hPa150],
            let rh100 = relativeHumidity[.hPa100],
            let rh50 = relativeHumidity[.hPa50]
        else {
            return
        }

        let cloudcoverLow = zip(rh1000, zip(rh925, rh850)).map {
            max(
                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0, pressureHPa: 1000),
                max(
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 925),
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 850)
                )
            )
        }

        let cloudcoverMid = zip(zip(rh700, rh600), zip(rh500, rh400)).map {
            max(
                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.0, pressureHPa: 700),
                max(
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.1, pressureHPa: 600),
                    max(
                        Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 500),
                        Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 400)
                    )
                )
            )
        }

        let cloudcoverHigh = zip(zip(rh300, rh250), zip(zip(rh200, rh150), zip(rh100, rh50))).map {
            max(
                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.0, pressureHPa: 300),
                max(
                    Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.1, pressureHPa: 250),
                    max(
                        Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0.0, pressureHPa: 200),
                        max(
                            Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0.1, pressureHPa: 150),
                            max(
                                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1.0, pressureHPa: 100),
                                Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1.1, pressureHPa: 50)
                            )
                        )
                    )
                )
            )
        }

        let cloudcover = Meteorology.cloudCoverTotal(low: cloudcoverLow, mid: cloudcoverMid, high: cloudcoverHigh)

        try await writer.write(time: validTime, member: member, variable: WeatherNextVariable.cloud_cover_low, data: cloudcoverLow)
        try await writer.write(time: validTime, member: member, variable: WeatherNextVariable.cloud_cover_mid, data: cloudcoverMid)
        try await writer.write(time: validTime, member: member, variable: WeatherNextVariable.cloud_cover_high, data: cloudcoverHigh)
        try await writer.write(time: validTime, member: member, variable: WeatherNextVariable.cloud_cover, data: cloudcover)
    }
}

enum WeatherNextDownloaderError: Error {
    case notImplemented(String)
}

struct WeatherNextSourcePath {
    let server: String
    let run: Timestamp
    let validTime: Timestamp

    var remotePath: String {
        let base = server.hasSuffix("/") ? server : "\(server)/"
        return "\(base)\(run.iso8601_YYYY_MM_dd_HH_mm_ssZ)/\(validTime.iso8601_YYYY_MM_dd_HH_mm_ssZ).om"
    }
}
