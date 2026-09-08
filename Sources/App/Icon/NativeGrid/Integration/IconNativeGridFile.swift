import Foundation
import OmFileFormat
import OmFileIO
import SphericalCube
import Synchronization

extension IconNativeGridIdentity {
    func loadGrid(mapped: MmapFile, path: String) throws -> IconNativeGrid {
        do {
            return try validate(grid: IconNativeGrid(storage: SphericalCubeIndex(mapped: mapped)), path: path)
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(path: path, reason: String(describing: error))
        }
    }

    func validate(grid: IconNativeGrid, path: String) throws(IconNativeDomainError) -> IconNativeGrid {
        let storage = grid.storage
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
        return grid
    }

}

struct IconNativeGridFile: OmFileManagable, Sendable {
    typealias Payload = IconNativeGridPayload

    let localFile: String
    let registry: DomainRegistry
    let identity: IconNativeGridIdentity
    let cache: IconNativeGridCache

    init(registry: DomainRegistry, identity: IconNativeGridIdentity) {
        localFile = "\(registry.directory)static/grid.bin"
        self.registry = registry
        self.identity = identity
        self.cache = IconNativeGridCache(file: localFile, identity: identity)
    }

    init(localFile: String, identity: IconNativeGridIdentity) {
        self.localFile = localFile
        registry = identity.isGlobal ? .dwd_icon_global_native : .dwd_icon_d2_native
        self.identity = identity
        self.cache = IconNativeGridCache(file: localFile, identity: identity)
    }

    func materialize<Backend: OmFileReaderBackend>(file: Backend) async throws -> IconNativeGrid
    where Backend.DataType: DataProtocol {
        try createDirectory()
        let handle = try FileHandle.createNewFile(
            file: localFile,
            size: file.count,
            overwrite: true,
            temporary: true
        )
        for offset in stride(from: 0, to: file.count, by: 8 * 1_024 * 1_024) {
            let count = min(8 * 1_024 * 1_024, file.count - offset)
            try handle.write(contentsOf: await file.getData(offset: offset, count: count))
        }
        let grid = try identity.loadGrid(mapped: MmapFile(fn: handle), path: localFile)
        try handle.linkTemporary(file: localFile)
        return grid
    }

    func getFilePath() -> String { localFile }

    func getRelativeFilePathWithData() -> String {
        "data/\(registry.rawValue)/static/grid.bin"
    }
}

/// Local files remain mapped; remote files are validated and atomically materialized before use.
struct IconNativeGridPayload: OmFilePayload {
    let grid: IconNativeGrid

    init(fd: FileHandle, size: Int64) throws {
        grid = IconNativeGrid(storage: try SphericalCubeIndex(mapped: MmapFile(fn: fd)))
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
        grid = try await artifact.materialize(file: cached)
    }

    func remoteUpdated(file: OmHttpReaderBackend) async throws -> Self {
        try await Self(file: file)
    }

    // The complete artifact is already local, and active readers deliberately pin its mapping.
    func remoteDeleted() async throws {}
}

extension IconNativeGridFile {
    func load(context: DomainInitContext) async throws -> any Gridable {
        if let grid = try? cache.get() {
            return grid
        }
        guard let payload = try await OmFileSystemManager.instance.get(
            file: self, client: context.httpClient, logger: context.logger
        ) else {
            throw IconNativeDomainError.missingGridArtifact(getFilePath())
        }
        let grid = try identity.validate(grid: payload.grid, path: getFilePath())
        cache.install(grid)
        return grid
    }
}


/// Pins a successfully loaded mapping for this artifact. Local and remote file
/// discovery belongs to `OmFileSystemManager`.
final class IconNativeGridCache: Sendable {
    private let file: String
    private let identity: IconNativeGridIdentity
    private let entry = AtomicLazyReference<SphericalCubeIndex>()

    init(file: String, identity: IconNativeGridIdentity) {
        self.file = file
        self.identity = identity
    }

    func get() throws -> IconNativeGrid {
        guard let resolved = entry.load() else {
            throw IconNativeDomainError.missingGridArtifact(file)
        }
        return IconNativeGrid(storage: resolved)
    }

    /// Publish a storage mapping produced by downloader preparation before the cache is resolved.
    func install(_ grid: IconNativeGrid) {
        _ = entry.storeIfNil(grid.storage)
    }

    /// Downloader-only disk validation. Unlike `get()`, this always inspects the final artifact.
    func validateFileAndInstall() throws {
        let loaded = try loadStorage()
        _ = entry.storeIfNil(loaded)
    }

    private func loadStorage() throws(IconNativeDomainError) -> SphericalCubeIndex {
        guard FileManager.default.fileExists(atPath: file) else {
            throw IconNativeDomainError.missingGridArtifact(file)
        }
        do {
            let handle = try FileHandle.openFileReading(file: file)
            return try identity.loadGrid(mapped: MmapFile(fn: handle), path: file).storage
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(
                path: file,
                reason: String(describing: error)
            )
        }
    }
}
