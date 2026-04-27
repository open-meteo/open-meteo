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
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let server = signature.server ?? "gs://om-weathernext/output/"
        let nConcurrent = signature.concurrent ?? 1
        let generateFullRun = false

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try await prepareStaticFilesIfRequired(application: context.application, domain: domain, server: server, run: run)

        let handles = try await download(
            application: context.application,
            domain: domain,
            run: run,
            server: server,
            concurrent: nConcurrent,
            skipFilesIfExisting: signature.skipExisting,
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

    func prepareStaticFilesIfRequired(
        application: Application,
        domain: WeatherNextDomain,
        server: String,
        run: Timestamp
    ) async throws {
        let logger = application.logger
        _ = server
        _ = run
        logger.info("Static file preparation for \(domain) is currently a no-op")
    }

    func download(
        application: Application,
        domain: WeatherNextDomain,
        run: Timestamp,
        server: String,
        concurrent: Int,
        skipFilesIfExisting: Bool,
        uploadS3Bucket: String?
    ) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        _ = concurrent

        let writer = OmSpatialMultistepWriter(
            domain: domain,
            run: run,
            storeOnDisk: true, // FIXME: change to false
            realm: nil,
            logger: logger,
            ensembleMeanDomain: domain.ensembleMeanDomain
        )

        let timestamps = (0..<domain.omFileLength).map { run.add(($0 + 1) * domain.dtSeconds) }
        logger.info("Processing \(timestamps.count) WeatherNext timesteps")

        for timestamp in timestamps {
            let source = WeatherNextSourcePath(server: server, run: run, validTime: timestamp)
            let localFile = "\(domain.downloadDirectory)\(timestamp.iso8601_YYYY_MM_dd_HHmm).om"

            logger.info("Processing \(source.remotePath)")

            if !skipFilesIfExisting || !FileManager.default.fileExists(atPath: localFile) {
                try await fetchSourceFile(
                    application: application,
                    remotePath: source.remotePath,
                    localFile: localFile
                )
            }

            try await processWeatherNextFile(
                application: application,
                domain: domain,
                file: localFile,
                run: run,
                validTime: timestamp,
                writer: writer
            )
        }

        return try await writer.finalise(
            completed: true,
            validTimes: timestamps,
            uploadS3Bucket: uploadS3Bucket
        )
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
        writer: OmSpatialMultistepWriter
    ) async throws {
        let logger = application.logger
        _ = run

        let root = try await OmFileReader(file: file)

        logger.info("Writing timestep \(validTime.iso8601_YYYY_MM_dd_HH_mm)")

        for member in 0..<domain.countEnsembleMember {
            var relativeHumidity = [WeatherNextPressureLevel: [Float]]()
            relativeHumidity.reserveCapacity(WeatherNextPressureLevel.allCases.count)

            for variable in WeatherNextVariable.rawVariables {
                let data = try await readMemberSlice(
                    root: root,
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
    }

    func readMemberSlice<Backend>(
        root: OmFileReader<Backend>,
        variable: WeatherNextVariable,
        member: Int,
        domain: WeatherNextDomain
    ) async throws -> [Float] {
        guard let child = try await root.getChild(name: variable.rawValue),
              let array = child.asArray(of: Float.self) else {
            throw WeatherNextDownloaderError.notImplemented("Could not open source variable \(variable.rawValue)")
        }

        let dims = Array(array.getDimensions())
        guard dims.count == 3 else {
            throw WeatherNextDownloaderError.notImplemented("Unexpected dimensions for \(variable.rawValue): \(dims)")
        }
        guard dims[0] == UInt64(domain.countEnsembleMember),
              dims[1] == UInt64(domain.grid.ny),
              dims[2] == UInt64(domain.grid.nx) else {
            throw WeatherNextDownloaderError.notImplemented("Unexpected shape for \(variable.rawValue): \(dims)")
        }

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

        if let fma = variable.multiplyAdd {
            data.multiplyAdd(multiply: fma.multiply, add: fma.add)
        }
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
