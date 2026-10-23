import Foundation
import OmFileFormat
import OmFileIO
import ReducedLatLon

extension IconNativeGridIdentity {
    /// Validates a mapped artifact and its operational identity, wrapping failures with its path.
    func loadStorage(mapped: MmapFile, path: String) throws -> ReducedLatLonIndex {
        do {
            let storage = try ReducedLatLonIndex(mapped: mapped)
            try validate(storage: storage, path: path)
            return storage
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(path: path, reason: String(describing: error))
        }
    }

    /// Rejects structurally valid artifacts whose dataset or index resolution does not match ICON.
    func validate(storage: ReducedLatLonIndex, path: String) throws(IconNativeDomainError) {
        guard storage.metadata.number == gridNumber else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "expected grid number \(gridNumber), got \(storage.metadata.number)"
            )
        }
        guard storage.metadata.uuid == gridUUID.bytes else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "grid UUID does not match \(gridUUID.hexString)"
            )
        }
        guard storage.pointCount == cellCount else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "expected \(cellCount) cells, got \(storage.pointCount)"
            )
        }
        guard storage.metadata.coversWholeSphere == isGlobal else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "global/regional grid kind does not match"
            )
        }
        guard storage.latitudeBandCount == latitudeBandCount else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "expected \(latitudeBandCount) latitude bands, got \(storage.latitudeBandCount)"
            )
        }
    }

}

/// Static artifact location and validation for an ICON mesh.
/// Publish replacements atomically; never modify or truncate a mapped inode. Initialized domains
/// retain their mapping and decoded elevations, so restart readers to load replacement resources.
/// API readers validate artifacts but do not regenerate them: generation belongs to downloader
/// preparation. Coordinate artifact publication with deployment of readers supporting its format.
struct IconNativeGridFile: OmFileManagable, Sendable {
    typealias Payload = IconNativeGridPayload

    let localFile: String
    let registry: DomainRegistry
    let identity: IconNativeGridIdentity

    static func forGrid(_ grid: AsyncGridRegistry) -> Self {
        let identity: IconNativeGridIdentity
        switch grid {
        case .dwd_icon_global_native:
            identity = .global
        case .dwd_icon_eu_native:
            identity = .europe
        case .dwd_icon_d2_native:
            identity = .d2
        case .dwd_icon_global_eps_native:
            identity = .globalEnsemble
        case .dwd_icon_eu_eps_native:
            identity = .europeEnsemble
        }
        return Self(registry: grid.staticDomain, identity: identity)
    }

    static func forRemotePath(_ path: String) -> Self? {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 4, components[0] == "data",
              components[2] == "static", components[3] == "grid.bin",
              let grid = AsyncGridRegistry(rawValue: String(components[1])) else { return nil }
        return forGrid(grid)
    }

    /// Materializes a complete backend, validating it before atomically replacing the local file.
    func load<Backend: OmFileReaderBackend>(file: Backend) async throws -> ReducedLatLonIndex
    where Backend.DataType: DataProtocol {
        try await materialize(file: file) { handle in
            try identity.loadStorage(mapped: MmapFile(fn: handle), path: localFile)
        }
    }

    func getFilePath() -> String { localFile }

    func getRelativeFilePathWithData() -> String {
        "data/\(registry.rawValue)/static/grid.bin"
    }
}

/// Local files remain mapped; remote files are validated before atomic publication.
struct IconNativeGridPayload: OmFilePayload {
    let storage: ReducedLatLonIndex

    /// Maps and structurally validates a local file; its domain checks operational identity later.
    init(fd: FileHandle, size: Int64) throws {
        storage = try ReducedLatLonIndex(mapped: MmapFile(fn: fd))
    }

    /// Loads a supported remote registry path through validated local materialization.
    init(file: OmHttpReaderBackend) async throws {
        guard let artifact = IconNativeGridFile.forRemotePath(file.object) else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: file.object, reason: "Unknown native grid path"
            )
        }
        let cached = OmReaderBlockCache(backend: file, cache: OpenMeteo.dataBlockCache, cacheKey: file.cacheKey)
        storage = try await artifact.load(file: cached)
    }

    func remoteUpdated(file: OmHttpReaderBackend) async throws -> Self {
        try await Self(file: file)
    }

    // The complete artifact is already local, and active readers deliberately pin its mapping.
    func remoteDeleted() async throws {}
}

extension IconNativeGridFile {
    init(registry: DomainRegistry, identity: IconNativeGridIdentity) {
        localFile = "\(registry.directory)static/grid.bin"
        self.registry = registry
        self.identity = identity
    }

    /// Downloader preparation validates the on-disk artifact before installing it in the loader.
    func validateFile() throws(IconNativeDomainError) -> ReducedLatLonIndex {
        guard FileManager.default.fileExists(atPath: localFile) else {
            throw IconNativeDomainError.missingGridArtifact(localFile)
        }
        do {
            let handle = try FileHandle.openFileReading(file: localFile)
            return try identity.loadStorage(mapped: MmapFile(fn: handle), path: localFile)
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(
                path: localFile,
                reason: String(describing: error)
            )
        }
    }

    /// Reads and validates the artifact; shared geometry is retained by IconNativeGridLoader.
    func load() async throws -> ReducedLatLonIndex {
        guard let payload = try await OmFileSystemManager.instance.get(
            file: self, client: .shared, logger: IconNativeDomains.logger
        ) else {
            throw IconNativeDomainError.missingGridArtifact(getFilePath())
        }
        try identity.validate(storage: payload.storage, path: getFilePath())
        return payload.storage
    }
}
