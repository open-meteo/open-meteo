import Foundation
import OmFileFormat
import OmFileIO
import SphericalCube
import Synchronization

extension IconNativeGridIdentity {
    func loadStorage(mapped: MmapFile, path: String) throws -> SphericalCubeIndex {
        do {
            let storage = try SphericalCubeIndex(mapped: mapped)
            try validate(storage: storage, path: path)
            return storage
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(path: path, reason: String(describing: error))
        }
    }

    func validate(storage: SphericalCubeIndex, path: String) throws(IconNativeDomainError) {
        guard storage.identity.number == gridNumber else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "expected grid number \(gridNumber), got \(storage.identity.number)"
            )
        }
        guard storage.identity.uuid == gridUUID.bytes else {
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
        guard storage.coversWholeSphere == isGlobal else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "global/regional grid kind does not match"
            )
        }
        guard storage.level == level else {
            throw IconNativeDomainError.invalidGridArtifact(
                path: path,
                reason: "expected grid level \(level), got \(storage.level)"
            )
        }
    }

}

struct IconNativeGridFile: OmFileManagable, Sendable {
    typealias Payload = IconNativeGridPayload

    let localFile: String
    let registry: DomainRegistry
    let identity: IconNativeGridIdentity
    let cache = IconNativeGridCache()

    func load<Backend: OmFileReaderBackend>(file: Backend) async throws -> SphericalCubeIndex
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
    let storage: SphericalCubeIndex

    init(fd: FileHandle, size: Int64) throws {
        storage = try SphericalCubeIndex(mapped: MmapFile(fn: fd))
    }

    init(file: OmHttpReaderBackend) async throws {
        let artifact: IconNativeGridFile
        switch file.object {
        case "data/dwd_icon_global_native/static/grid.bin":
            artifact = IconNativeGridFile(registry: .dwd_icon_global_native, identity: .global)
        case "data/dwd_icon_d2_native/static/grid.bin":
            artifact = IconNativeGridFile(registry: .dwd_icon_d2_native, identity: .d2)
        default:
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

    func load() async throws -> IconNativeGrid {
        let storage: SphericalCubeIndex
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
    private let entry = AtomicLazyReference<SphericalCubeIndex>()

    func get() -> SphericalCubeIndex? {
        entry.load()
    }

    /// Publish a storage mapping produced by downloader preparation before the cache is resolved.
    func install(_ storage: SphericalCubeIndex) {
        _ = entry.storeIfNil(storage)
    }

}
