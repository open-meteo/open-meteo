import Foundation
import OmFileFormat
import OmFileIO
import SphericalCube
import Vapor

/// Immutable identity of an operational DWD grid. Both the NetCDF definition and every native
/// GRIB message must match these values so data cannot silently be paired with another grid order.
struct IconNativeGridIdentity: Sendable, Hashable {
    let gridNumber: UInt32
    let gridUUID: UUID
    let cellCount: Int
    let isGlobal: Bool
    let level: Int
    let maximumDistanceMeters: Float
    let sourceFile: String

    static let global = Self(
        gridNumber: 26,
        gridUUID: UUID(uuidString: "a27b8de6-18c4-11e4-820a-b5b098c6a5c0")!,
        cellCount: 2_949_120,
        isGlobal: true,
        level: 9,
        maximumDistanceMeters: 20_000,
        sourceFile: "icon_grid_0026_R03B07_G.nc.bz2"
    )

    static let d2 = Self(
        gridNumber: 47,
        gridUUID: UUID(uuidString: "c6b12daa-91ad-6404-5b26-c1b6452a2a20")!,
        cellCount: 542_040,
        isGlobal: false,
        level: 11,
        maximumDistanceMeters: 4_000,
        sourceFile: "icon_grid_0047_R19B07_L.nc.bz2"
    )

    var maximumChordDistanceSquared: Float {
        SphericalPoint.squaredChordDistance(meters: Double(maximumDistanceMeters))
    }

    var sourceUrl: String {
        "https://opendata.dwd.de/weather/lib/cdo/\(sourceFile)"
    }
}

enum IconNativeDomainError: Error, Equatable, CustomStringConvertible, Sendable {
    case missingGridArtifact(String)
    case invalidGridArtifact(path: String, reason: String)

    var description: String {
        switch self {
        case .missingGridArtifact(let path):
            return "Missing native ICON grid artifact at \(path)"
        case .invalidGridArtifact(let path, let reason):
            return "Invalid native ICON grid artifact at \(path): \(reason)"
        }
    }
}

extension IconNativeDomains {
    func prepareNativeGrid(application: Application, uploadS3Bucket: String?) async throws {
        let downloadDirectory = "\(OpenMeteo.tempDirectory)download-\(domainRegistry.rawValue)/"
        let artifact = nativeGridFile
        let identity = artifact.identity
        let registry = artifact.registry
        do {
            // Downloader preparation deliberately validates the on-disk artifact. API lookups use
            // the atomically pinned mapping and never enter this disk-maintenance path.
            try artifact.validateFileAndInstall()
            // Valid existing artifacts are reused without uploading. Delete grid.bin locally to
            // force regeneration, and supply --upload-s3-bucket to upload the regenerated artifact.
            return
        } catch IconNativeDomainError.missingGridArtifact {
            application.logger.info("Generating missing native ICON grid artifact for '\(rawValue)'")
        } catch {
            application.logger.warning("Regenerating invalid native ICON grid artifact for '\(rawValue)': \(error)")
        }

        // Bootstrap is intentionally owned by the downloader: obtain the official NetCDF mesh,
        // generate the lookup artifact offline, then atomically publish it to the static registry.
        let staticDirectory = "\(registry.directory)static/"
        try FileManager.default.createDirectory(atPath: staticDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        let sourceFile = "\(downloadDirectory)\(identity.sourceFile.dropLast(4))"
        let sourceExisted = FileManager.default.fileExists(atPath: sourceFile)
        let curl = Curl(
            logger: application.logger,
            client: application.dedicatedHttpClient,
            deadLineHours: identity.isGlobal ? 5 : 2
        )

        func downloadSource() async throws {
            application.logger.info("Downloading native ICON grid definition '\(identity.sourceFile)'")
            try await curl.download(
                url: identity.sourceUrl,
                toFile: sourceFile,
                bzip2Decode: true,
                cacheDirectory: nil
            )
        }

        if !sourceExisted {
            try await downloadSource()
        }

        let artifactPath = "\(staticDirectory)grid.bin"
        let grid: IconNativeGrid
        do {
            grid = try IconNativeGrid.Generator.generateAndPublish(
                sourceFile: sourceFile,
                identity: identity,
                artifactFile: artifactPath
            )
        } catch let error as IconNativeGridSourceError where sourceExisted {
            // A cached source may be truncated or may belong to an older operational grid. Retry
            // source errors once with an atomic replacement; readers of the old inode stay valid.
            application.logger.warning("Replacing unusable cached ICON grid definition: \(error)")
            try await downloadSource()
            grid = try IconNativeGrid.Generator.generateAndPublish(
                sourceFile: sourceFile,
                identity: identity,
                artifactFile: artifactPath
            )
        }

        artifact.cache.install(grid.storage)
        application.logger.info("Generated native ICON grid artifact at \(artifactPath)")
        for queue in await application.s3SyncManager.getQueues(bucketsOpt: uploadS3Bucket) ?? [] {
            let uploads = queue.startMultiPartUploads()
            await uploads.uploadMultipart(
                file: artifactPath,
                objectName: "data/\(registry.rawValue)/static/grid.bin",
                lastModified: .now()
            )
            await queue.finishMultiPartUploads(uploads)
        }
    }
}
