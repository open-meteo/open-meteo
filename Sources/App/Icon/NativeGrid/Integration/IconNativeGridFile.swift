import Foundation
import OmFileFormat
import OmFileIO
import ReducedLatLon
import Synchronization

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

/// Static artifact location and lifetime-pinned cache shared by domains using the same ICON mesh.
/// Publish replacements atomically; never modify or truncate a mapped inode. Initialized domains
/// retain their mapping and decoded elevations, so restart readers to load replacement resources.
/// API readers validate artifacts but do not regenerate them: generation belongs to downloader
/// preparation. Coordinate artifact publication with deployment of readers supporting its format.
struct IconNativeGridFile: OmFileManagable, Sendable {
    typealias Payload = IconNativeGridPayload

    let localFile: String
    let registry: DomainRegistry
    let identity: IconNativeGridIdentity
    let cache = IconNativeGridCache()

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
        guard let domain = IconNativeDomains.allCases.first(where: {
            $0.nativeGridFile.getRelativeFilePathWithData() == file.object
        }) else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: file.object, reason: "Unknown native grid path"
            )
        }
        let cached = OmReaderBlockCache(backend: file, cache: OpenMeteo.dataBlockCache, cacheKey: file.cacheKey)
        storage = try await domain.nativeGridFile.load(file: cached)
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

    /// Downloader preparation always validates the on-disk artifact before installing it.
    func validateFileAndInstall() throws(IconNativeDomainError) {
        guard FileManager.default.fileExists(atPath: localFile) else {
            throw IconNativeDomainError.missingGridArtifact(localFile)
        }
        do {
            let handle = try FileHandle.openFileReading(file: localFile)
            let storage = try identity.loadStorage(mapped: MmapFile(fn: handle), path: localFile)
            cache.install(storage)
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(
                path: localFile,
                reason: String(describing: error)
            )
        }
    }

    /// Resolves and pins a validated index, returning an adapter with this grid's distance policy.
    func load() async throws -> IconNativeGrid {
        let storage: ReducedLatLonIndex
        if let cached = cache.get() {
            storage = cached
        } else {
            guard let payload = try await OmFileSystemManager.instance.get(
                file: self, client: .shared, logger: IconNativeDomains.logger
            ) else {
                throw IconNativeDomainError.missingGridArtifact(getFilePath())
            }
            try identity.validate(storage: payload.storage, path: getFilePath())
            storage = payload.storage
            cache.install(storage)
        }
        return IconNativeGrid(
            storage: storage,
            maximumChordDistanceSquared: identity.maximumChordDistanceSquared,
            nearbyMaximumChordDistanceSquared: identity.nearbyMaximumChordDistanceSquared
        )
    }
}


/// Pins a successfully loaded mapping for this artifact. Local and remote file
/// discovery belongs to `OmFileSystemManager`.
final class IconNativeGridCache: Sendable {
    private let entry = AtomicLazyReference<ReducedLatLonIndex>()

    /// Returns the first successfully installed mapping, or nil before initialization.
    func get() -> ReducedLatLonIndex? {
        entry.load()
    }

    /// Publish a storage mapping produced by downloader preparation before the cache is resolved.
    func install(_ storage: ReducedLatLonIndex) {
        _ = entry.storeIfNil(storage)
    }

}
