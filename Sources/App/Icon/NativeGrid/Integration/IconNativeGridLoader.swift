import OmFileFormat

/// Pins complete native grids until restart, sharing geometry and elevations across domains.
actor IconNativeGridLoader {
    static let shared = IconNativeGridLoader()

    private enum State {
        case loading([CheckedContinuation<IconNativeGrid, any Error>])
        case loaded(IconNativeGrid)
        case error(any Error)
    }

    private var cache = [AsyncGridRegistry: State]()

    func load(grid registry: AsyncGridRegistry) async throws -> IconNativeGrid {
        switch cache[registry] {
        case .loaded(let grid):
            return grid
        case .loading(var continuations):
            return try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
                cache[registry] = .loading(continuations)
            }
        case .error(let error):
            throw error
        case nil:
            cache[registry] = .loading([])
        }
        do {
            let file = IconNativeGridFile.forGrid(registry)
            var grid = try await file.load()
            let payload = try? await OmFileSystemManager.instance.get(
                file: OmFileType.staticFile(domain: file.registry, variable: "HSURF"),
                client: .shared, logger: IconNativeDomains.logger
            )
            if let payload {
                grid.elevations = try await ElevationValues(decoded: payload.reader.read(), expectedCount: grid.nx)
            }
            guard case .loading(let continuations) = cache.removeValue(forKey: registry) else {
                fatalError("Expected loading state")
            }
            cache[registry] = .loaded(grid)
            for continuation in continuations {
                continuation.resume(returning: grid)
            }
            return grid
        } catch {
            guard case .loading(let continuations) = cache.removeValue(forKey: registry) else {
                fatalError("Expected loading state")
            }
            for continuation in continuations {
                continuation.resume(throwing: error)
            }
            cache[registry] = .error(error)
            throw error
        }
    }
}
