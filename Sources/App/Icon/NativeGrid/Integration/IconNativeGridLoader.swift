import OmFileFormat
import ReducedLatLon

/// Pins complete native grids until restart, sharing geometry and elevations across domains.
actor IconNativeGridLoader {
    static let shared = IconNativeGridLoader()

    private enum State {
        case loading([CheckedContinuation<IconNativeGrid, any Error>])
        case loaded(IconNativeGrid)
        case error(any Error)
    }

    private var geometryCache = [AsyncGridRegistry: ReducedLatLonIndex]()

    /// Keep the first validated mapping alive, including mappings prepared by the downloader.
    @discardableResult
    func installGeometry(_ storage: ReducedLatLonIndex, for registry: AsyncGridRegistry) -> ReducedLatLonIndex {
        if let cached = geometryCache[registry] {
            return cached
        }
        geometryCache[registry] = storage
        return storage
    }

    /// Downloader preparation needs geometry before elevation files have been generated.
    func loadGeometry(grid registry: AsyncGridRegistry) async throws -> IconNativeGrid {
        let file = IconNativeGridFile.forGrid(registry)
        let storage: ReducedLatLonIndex
        if let cached = geometryCache[registry] {
            storage = cached
        } else {
            let loaded = try await file.load()
            storage = installGeometry(loaded, for: registry)
        }
        return IconNativeGrid(
            storage: storage,
            resolutionMeters: file.identity.resolutionMeters,
            maximumChordDistanceSquared: file.identity.maximumChordDistanceSquared,
            nearbyMaximumChordDistanceSquared: file.identity.nearbyMaximumChordDistanceSquared
        )
    }

    private var loadedGridCache = [AsyncGridRegistry: State]()

    func load(grid registry: AsyncGridRegistry) async throws -> IconNativeGrid {
        switch loadedGridCache[registry] {
        case .loaded(let grid):
            return grid
        case .loading(var continuations):
            return try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
                loadedGridCache[registry] = .loading(continuations)
            }
        case .error(let error):
            throw error
        case nil:
            loadedGridCache[registry] = .loading([])
        }
        do {
            let file = IconNativeGridFile.forGrid(registry)
            var grid = try await loadGeometry(grid: registry)
            let payload = try? await OmFileSystemManager.instance.get(
                file: OmFileType.staticFile(domain: file.registry, variable: "HSURF")
            )
            if let payload {
                grid.elevations = try await ElevationValues(decoded: payload.reader.read(), expectedCount: grid.nx)
            }
            guard case .loading(let continuations) = loadedGridCache.removeValue(forKey: registry) else {
                fatalError("Expected loading state")
            }
            loadedGridCache[registry] = .loaded(grid)
            for continuation in continuations {
                continuation.resume(returning: grid)
            }
            return grid
        } catch {
            guard case .loading(let continuations) = loadedGridCache.removeValue(forKey: registry) else {
                fatalError("Expected loading state")
            }
            for continuation in continuations {
                continuation.resume(throwing: error)
            }
            loadedGridCache[registry] = .error(error)
            throw error
        }
    }
}
