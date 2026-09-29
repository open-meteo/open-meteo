import Foundation
import OmFileFormat
import OmFileIO
import Vapor
import SwiftNetCDF

/// Immutable identity of an operational DWD grid. Both the NetCDF definition and every native
/// GRIB message must match these values so data cannot silently be paired with another grid order.
struct IconNativeGridIdentity: Sendable, Hashable {
    let gridNumber: UInt32
    let gridUUID: UUID
    let cellCount: Int
    let isGlobal: Bool
    /// Number of equal-height latitude bands used by the spatial index.
    let latitudeBandCount: Int
    let maximumDistanceMeters: Float
    /// Uncompressed NetCDF filename in MPI's DWD grid catalogue, also used for the local cache.
    let sourceFile: String

    static let global = Self(
        gridNumber: 26,
        gridUUID: UUID(uuidString: "a27b8de6-18c4-11e4-820a-b5b098c6a5c0")!,
        cellCount: 2_949_120,
        isGlobal: true,
        latitudeBandCount: 1_111,
        maximumDistanceMeters: 20_000,
        sourceFile: "icon_grid_0026_R03B07_G.nc"
    )

    static let d2 = Self(
        gridNumber: 47,
        gridUUID: UUID(uuidString: "c6b12daa-91ad-6404-5b26-c1b6452a2a20")!,
        cellCount: 542_040,
        isGlobal: false,
        latitudeBandCount: 4_446,
        maximumDistanceMeters: 4_000,
        sourceFile: "icon_grid_0047_R19B07_L.nc"
    )

    // Extends will change slightly on Oct. 6 2026
    // We will only start archiving this native domain after with the new grid
    static let europe = Self(
        gridNumber: 27, 
        gridUUID: UUID(uuidString: "ec13b8bc-b82d-11e4-b13f-4d55411d42e6")!,
        cellCount: 659_156, 
        isGlobal: false, 
        latitudeBandCount: 2_222,
        maximumDistanceMeters: 13_000, 
        sourceFile: "icon_grid_0027_R03B08_N02.nc"
    )

    // Resolution will change on Oct. 6 2026
    // We will only start archiving this native domain after with the new grid
    static let globalEnsemble = Self(
        gridNumber: 36, 
        gridUUID: UUID(uuidString: "ae487d14-fe2e-11e4-af85-e50a2a56a360")!,
        cellCount: 737_280, 
        isGlobal: true, 
        latitudeBandCount: 556,
        maximumDistanceMeters: 52_000, 
        sourceFile: "icon_grid_0036_R03B06_G.nc"
    )

    // Resolution will change on Oct. 6 2026
    // We will only start archiving this native domain after with the new grid
    static let europeEnsemble = Self(
        gridNumber: 37, 
        gridUUID: UUID(uuidString: "ae487d28-fe2e-11e4-af85-e50a2a56a360")!,
        cellCount: 164_984, 
        isGlobal: false, 
        latitudeBandCount: 1_111,
        maximumDistanceMeters: 26_000, 
        sourceFile: "icon_grid_0037_R03B07_N02.nc"
    )

    /// ICON's spherical Earth radius in metres, independent of the index format.
    static let earthRadiusMeters: Double = 6_371_229

    /// Converts a surface distance in metres to squared chord distance on the unit sphere.
    static func squaredChordDistance(meters: Double) -> Float {
        let chord = 2 * sin(meters / earthRadiusMeters * 0.5)
        return Float(chord * chord)
    }

    /// Maximum accepted distance for the initial nearest-cell lookup.
    var maximumChordDistanceSquared: Float {
        Self.squaredChordDistance(meters: Double(maximumDistanceMeters))
    }

    /// Terrain and sea selection inspect a slightly wider, resolution-scaled neighbourhood than
    /// the distance used to accept the initial nearest-cell lookup.
    var nearbyMaximumChordDistanceSquared: Float {
        Self.squaredChordDistance(meters: Double(maximumDistanceMeters) * 1.5)
    }

    var sourceUrl: String {
        // Catalogue: http://icon-downloads.mpimet.mpg.de/dwd_grids.xml
        // This server provides plain NetCDF files over HTTP (HTTPS is unavailable).
        "http://icon-downloads.mpimet.mpg.de/grids/public/edzw/\(sourceFile)"
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
    /// Validates/reuses the local artifact or regenerates it offline; only generated files upload.
    func prepareNativeGrid(application: Application, uploadS3Bucket: String?) async throws {
        let artifact = nativeGridFile
        let curl = Curl(logger: application.logger, client: application.dedicatedHttpClient)
        let prepared = try await artifact.prepare(curl: curl)
        guard prepared.generated else { return }
        let coordinatesFile = OmFileType.staticFile(domain: artifact.registry, variable: "coordinates")
        for queue in await application.s3SyncManager.getQueues(bucketsOpt: uploadS3Bucket) ?? [] {
            let uploads = queue.startMultiPartUploads()
            await uploads.uploadMultipart(
                file: artifact.getFilePath(),
                objectName: artifact.getRelativeFilePathWithData(),
                lastModified: .now()
            )
            if prepared.coordinatesGenerated {
                await uploads.uploadMultipart(
                    file: coordinatesFile.getFilePath(),
                    objectName: coordinatesFile.getRelativeFilePathWithData(),
                    lastModified: .now()
                )
            }
            await queue.finishMultiPartUploads(uploads)
        }
    }
}

extension IconNativeGridFile {
    /// Downloader-only preparation. Native ingestion needs the source only when rebuilding;
    /// remapping also retains its validated coordinates and mesh topology.
    func prepare(curl: Curl, loadSource: Bool = false) async throws -> (
        generated: Bool, coordinatesGenerated: Bool,
        source: (mesh: Group, coordinates: IconNativeGrid.Generator.Coordinates)?
    ) {
        var generated = false
        do {
            try validateFileAndInstall()
        } catch {
            curl.logger.info("Generating native ICON index: \(error)")
            generated = true
        }
        if !generated && !loadSource { return (false, false, nil) }

        let downloadDirectory = "\(OpenMeteo.tempDirectory)download-\(registry.rawValue)/"
        try FileManager.default.createDirectory(atPath: downloadDirectory, withIntermediateDirectories: true)
        let sourceFile = "\(downloadDirectory)\(identity.sourceFile)"
        let sourceExisted = FileManager.default.fileExists(atPath: sourceFile)
        func downloadSource() async throws {
            try await curl.download(url: identity.sourceUrl, toFile: sourceFile, bzip2Decode: false, cacheDirectory: nil)
        }
        func readSource() throws -> (mesh: Group, coordinates: IconNativeGrid.Generator.Coordinates) {
            guard let mesh = try NetCDF.open(path: sourceFile, allowUpdate: false) else {
                throw IconNativeGridSourceError.couldNotOpen(sourceFile)
            }
            return (mesh, try IconNativeGrid.Generator.readCoordinates(group: mesh, identity: identity))
        }
        if !sourceExisted { try await downloadSource() }
        let source: (mesh: Group, coordinates: IconNativeGrid.Generator.Coordinates)
        do {
            source = try readSource()
        } catch where sourceExisted {
            // Replace an unusable cached mesh once; a bad fresh download fails validation.
            curl.logger.warning("Replacing unusable cached ICON grid definition: \(error)")
            try await downloadSource()
            source = try readSource()
        }
        var coordinatesGenerated = false
        if generated {
            try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: localFile).deletingLastPathComponent().path, withIntermediateDirectories: true)
            let coordinatesFile = OmFileType.staticFile(domain: registry, variable: "coordinates")
            let result = try IconNativeGrid.Generator.generateAndPublish(
                coordinates: source.coordinates, identity: identity, artifactFile: localFile,
                coordinatesFile: coordinatesFile.getFilePath()
            )
            cache.install(result.grid.storage)
            coordinatesGenerated = result.coordinatesGenerated
            curl.logger.info("Generated native ICON grid artifact at \(localFile)")
            if coordinatesGenerated {
                curl.logger.info("Generated native ICON coordinates at \(coordinatesFile.getFilePath())")
            }
        }
        return (generated, coordinatesGenerated, source)
    }
}
