import Foundation
import OmFileFormat
import Synchronization
import Vapor

/// Immutable identity of an operational DWD grid. Both the NetCDF definition and every native
/// GRIB message must match these values so data cannot silently be paired with another grid order.
struct IconNativeGridIdentity: Sendable, Equatable {
    let gridNumber: UInt32
    let gridUUID: [UInt8]
    let gridUUIDHex: String
    let cellCount: Int
    let isGlobal: Bool
    let maximumDistanceMeters: Float
    let sourceFile: String

    static let global = Self(
        gridNumber: 26,
        gridUUID: [0xa2, 0x7b, 0x8d, 0xe6, 0x18, 0xc4, 0x11, 0xe4, 0x82, 0x0a, 0xb5, 0xb0, 0x98, 0xc6, 0xa5, 0xc0],
        gridUUIDHex: "a27b8de618c411e4820ab5b098c6a5c0",
        cellCount: 2_949_120,
        isGlobal: true,
        maximumDistanceMeters: 20_000,
        sourceFile: "icon_grid_0026_R03B07_G.nc.bz2"
    )

    static let d2 = Self(
        gridNumber: 47,
        gridUUID: [0xc6, 0xb1, 0x2d, 0xaa, 0x91, 0xad, 0x64, 0x04, 0x5b, 0x26, 0xc1, 0xb6, 0x45, 0x2a, 0x2a, 0x20],
        gridUUIDHex: "c6b12daa91ad64045b26c1b6452a2a20",
        cellCount: 542_040,
        isGlobal: false,
        maximumDistanceMeters: 4_000,
        sourceFile: "icon_grid_0047_R19B07_L.nc.bz2"
    )

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

private final class IconNativeGridCacheEntry: Sendable {
    let result: Result<IconNativeGrid.CubeIndex, IconNativeDomainError>

    init(_ result: Result<IconNativeGrid.CubeIndex, IconNativeDomainError>) {
        self.result = result
    }
}

/// One cache per physical grid. The first lookup result, including failure, remains fixed for the
/// process lifetime. Downloader preparation validates and installs artifacts explicitly.
final class IconNativeGridCache: Sendable {
    private let file: String
    private let identity: IconNativeGridIdentity
    private let entry = AtomicLazyReference<IconNativeGridCacheEntry>()

    init(file: String, identity: IconNativeGridIdentity) {
        self.file = file
        self.identity = identity
    }

    func get() throws -> IconNativeGrid {
        let resolved = entry.load() ?? entry.storeIfNil(loadEntry())
        return IconNativeGrid(storage: try resolved.result.get())
    }

    /// Publish a storage mapping produced by downloader preparation before the cache is resolved.
    func install(_ grid: IconNativeGrid) {
        _ = entry.storeIfNil(IconNativeGridCacheEntry(.success(grid.storage)))
    }

    /// Downloader-only disk validation. Unlike `get()`, this always inspects the final artifact.
    func validateFileAndInstall() throws {
        let loaded = try loadStorage()
        _ = entry.storeIfNil(IconNativeGridCacheEntry(.success(loaded)))
    }

    private func loadEntry() -> IconNativeGridCacheEntry {
        do {
            return IconNativeGridCacheEntry(.success(try loadStorage()))
        } catch {
            return IconNativeGridCacheEntry(.failure(error))
        }
    }

    private func loadStorage() throws(IconNativeDomainError) -> IconNativeGrid.CubeIndex {
        guard FileManager.default.fileExists(atPath: file) else {
            throw IconNativeDomainError.missingGridArtifact(file)
        }
        do {
            let storage = try IconNativeGrid.CubeIndex(file: URL(fileURLWithPath: file))
            guard storage.gridNumber == identity.gridNumber else {
                throw IconNativeDomainError.invalidGridArtifact(path: file, reason: "expected grid number \(identity.gridNumber), got \(storage.gridNumber)")
            }
            guard storage.gridUUID == identity.gridUUID else {
                throw IconNativeDomainError.invalidGridArtifact(path: file, reason: "grid UUID does not match \(identity.gridUUIDHex)")
            }
            guard storage.cellCount == identity.cellCount else {
                throw IconNativeDomainError.invalidGridArtifact(path: file, reason: "expected \(identity.cellCount) cells, got \(storage.cellCount)")
            }
            guard storage.isGlobal == identity.isGlobal else {
                throw IconNativeDomainError.invalidGridArtifact(path: file, reason: "global/regional grid kind does not match")
            }
            return storage
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(path: file, reason: String(describing: error))
        }
    }
}

private enum IconNativeGridCaches {
    static let global = IconNativeGridCache(
        file: "\(DomainRegistry.dwd_icon_global_native.directory)static/grid.bin",
        identity: .global
    )
    static let d2 = IconNativeGridCache(
        file: "\(DomainRegistry.dwd_icon_d2_native.directory)static/grid.bin",
        identity: .d2
    )
}

extension IconDomains {
    var isNative: Bool {
        nativeGridIdentity != nil
    }

    var isAvailable: Bool {
        guard isNative else {
            return true
        }
        // API servers do not generate artifacts. A missing or corrupt grid disables only this
        // domain; the download command calls `prepareNativeGrid` to create or repair it.
        return (try? requireNativeGrid()) != nil
    }

    var isD2Deterministic: Bool {
        self == .iconD2 || self == .iconD2Native
    }

    var isD2FifteenMinute: Bool {
        self == .iconD2_15min || self == .iconD2Native15min
    }

    var fifteenMinuteDomain: Self? {
        switch self {
        case .iconD2:
            return .iconD2_15min
        case .iconD2Native:
            return .iconD2Native15min
        default:
            return nil
        }
    }

    var sourceDomain: Self {
        // Native domains have independent storage registries, but DWD still publishes them below
        // the existing `icon` and `icon-d2` source paths.
        switch self {
        case .iconNative:
            return .icon
        case .iconD2Native, .iconD2Native15min:
            return .iconD2
        default:
            return self
        }
    }

    var nativeGridIdentity: IconNativeGridIdentity? {
        switch self {
        case .iconNative:
            return .global
        case .iconD2Native, .iconD2Native15min:
            return .d2
        default:
            return nil
        }
    }

    private var nativeGridCache: IconNativeGridCache {
        switch self {
        case .iconNative:
            return IconNativeGridCaches.global
        case .iconD2Native, .iconD2Native15min:
            return IconNativeGridCaches.d2
        default:
            preconditionFailure("\(self) is not a native ICON domain")
        }
    }

    func requireNativeGrid() throws -> IconNativeGrid {
        try nativeGridCache.get()
    }

    func prepareNativeGrid(application: Application) async throws {
        guard let identity = nativeGridIdentity else {
            return
        }
        guard let registry = domainRegistryStatic else {
            preconditionFailure("Native ICON domain has no static registry")
        }
        do {
            // Downloader preparation deliberately validates the on-disk artifact. API lookups use
            // the atomically pinned mapping and never enter this disk-maintenance path.
            try nativeGridCache.validateFileAndInstall()
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
        let stagedArtifactPath = "\(artifactPath)~"
        try FileManager.default.removeItemIfExists(at: stagedArtifactPath)
        defer {
            try? FileManager.default.removeItem(atPath: stagedArtifactPath)
        }

        let grid: IconNativeGrid
        do {
            grid = try IconNativeGrid.Generator.generate(
                sourceFile: sourceFile,
                identity: identity,
                artifactFile: stagedArtifactPath
            )
        } catch let error as IconNativeGridSourceError where sourceExisted {
            // A cached source may be truncated or may belong to an older operational grid. Retry
            // source errors once with a fresh download; generation errors are retained for diagnosis.
            application.logger.warning("Discarding unusable cached ICON grid definition and downloading it again: \(error)")
            try FileManager.default.removeItem(atPath: sourceFile)
            try FileManager.default.removeItemIfExists(at: stagedArtifactPath)
            try await downloadSource()
            grid = try IconNativeGrid.Generator.generate(
                sourceFile: sourceFile,
                identity: identity,
                artifactFile: stagedArtifactPath
            )
        }

        // The mmap remains valid across rename because it owns the staged file descriptor. Publish
        // only after complete validation, then cache that same mapping without reopening the file.
        try FileManager.default.moveFileOverwrite(from: stagedArtifactPath, to: artifactPath)
        nativeGridCache.install(grid)
        try? FileManager.default.removeItem(atPath: sourceFile)
        application.logger.info("Generated native ICON grid artifact at \(artifactPath)")
    }
}

/// Safety net for code paths that access `GenericDomain.grid` without checking availability.
/// Reader construction rejects this grid because every lookup returns `nil`.
struct IconNativeUnavailableGrid: Gridable {
    typealias SliceType = Range<Int>

    let nx = 1
    let ny = 1
    let searchRadius = 0
    func findPoint(lat: Float, lon: Float) -> Int? { nil }
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? { nil }
    func findBox(boundingBox bb: BoundingBoxWGS84) -> Range<Int>? { nil }
    func estimatedNumberOfGridCells(boundingBox bb: BoundingBoxWGS84) -> Int? { nil }
    func getCoordinates(gridpoint: Int) -> LatLon { (.nan, .nan) }
    func findPointTerrainOptimised(
        lat: Float,
        lon: Float,
        elevation: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? { nil }
    func findPointInSea(
        lat: Float,
        lon: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? { nil }

    var crsWkt2: String { "" }
}
