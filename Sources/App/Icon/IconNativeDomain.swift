import Foundation
import OmFileFormat
import Synchronization
import Vapor
@preconcurrency import SwiftEccodes

/// Immutable identity of an operational DWD grid. Both the NetCDF definition and every native
/// GRIB message must match these values so data cannot silently be paired with another grid order.
struct IconNativeGridIdentity: Sendable, Equatable {
    let gridNumber: UInt32
    let gridUUID: [UInt8]
    let gridUUIDHex: String
    let cellCount: Int
    let isGlobal: Bool
    let sourceFile: String

    static let global = Self(
        gridNumber: 26,
        gridUUID: [0xa2, 0x7b, 0x8d, 0xe6, 0x18, 0xc4, 0x11, 0xe4, 0x82, 0x0a, 0xb5, 0xb0, 0x98, 0xc6, 0xa5, 0xc0],
        gridUUIDHex: "a27b8de618c411e4820ab5b098c6a5c0",
        cellCount: 2_949_120,
        isGlobal: true,
        sourceFile: "icon_grid_0026_R03B07_G.nc.bz2"
    )

    static let d2 = Self(
        gridNumber: 47,
        gridUUID: [0xc6, 0xb1, 0x2d, 0xaa, 0x91, 0xad, 0x64, 0x04, 0x5b, 0x26, 0xc1, 0xb6, 0x45, 0x2a, 0x2a, 0x20],
        gridUUIDHex: "c6b12daa91ad64045b26c1b6452a2a20",
        cellCount: 542_040,
        isGlobal: false,
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

private struct IconNativeGridFileFingerprint: Sendable, Equatable {
    let inode: UInt64
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64

    static func read(file: String) -> Self? {
        guard let stats = FileManager.default.fileStats(at: file) else { return nil }
        #if os(Linux)
        let modification = stats.st_mtim
        #else
        let modification = stats.st_mtimespec
        #endif
        return Self(
            inode: UInt64(stats.st_ino),
            size: Int64(stats.st_size),
            modificationSeconds: Int64(modification.tv_sec),
            modificationNanoseconds: Int64(modification.tv_nsec)
        )
    }
}

private struct IconNativeGridFailureState: Sendable {
    let fingerprint: IconNativeGridFileFingerprint?
    let error: IconNativeDomainError
    let retryAfter: ContinuousClock.Instant
}

/// One cache per physical grid. Once storage is available the hot path is a single atomic load;
/// the mutex is used only to single-flight initial loading and throttled recovery from failures.
final class IconNativeGridCache: Sendable {
    private let file: String
    private let identity: IconNativeGridIdentity
    private let retryInterval: Duration
    private let storage = AtomicLazyReference<IconNativeGridStorage>()
    private let failure = Mutex<IconNativeGridFailureState?>(nil)

    init(file: String, identity: IconNativeGridIdentity, retryInterval: Duration = .seconds(30)) {
        self.file = file
        self.identity = identity
        self.retryInterval = retryInterval
    }

    func get() throws -> IconNativeGrid {
        if let storage = storage.load() {
            return IconNativeGrid(storage: storage)
        }
        return try failure.withLock { failure in
            // Another cold caller may have completed loading while this caller waited for the lock.
            if let storage = storage.load() {
                return IconNativeGrid(storage: storage)
            }
            let now = ContinuousClock.now
            if let failure, now < failure.retryAfter {
                throw failure.error
            }
            let fingerprint = IconNativeGridFileFingerprint.read(file: file)
            if let storage = storage.load() {
                failure = nil
                return IconNativeGrid(storage: storage)
            }
            if let previous = failure, previous.fingerprint == fingerprint {
                failure = IconNativeGridFailureState(
                    fingerprint: fingerprint,
                    error: previous.error,
                    retryAfter: now.advanced(by: retryInterval)
                )
                throw previous.error
            }
            do {
                let loaded = try loadStorage(fingerprint: fingerprint)
                let installed = storage.storeIfNil(loaded)
                failure = nil
                return IconNativeGrid(storage: installed)
            } catch {
                if let storage = storage.load() {
                    failure = nil
                    return IconNativeGrid(storage: storage)
                }
                let wrapped = error as? IconNativeDomainError
                    ?? IconNativeDomainError.invalidGridArtifact(path: file, reason: String(describing: error))
                failure = IconNativeGridFailureState(
                    fingerprint: fingerprint,
                    error: wrapped,
                    retryAfter: now.advanced(by: retryInterval)
                )
                throw wrapped
            }
        }
    }

    /// Publish a storage mapping produced by the downloader. A previously loaded mapping remains
    /// pinned by design; unavailable caches transition immediately without waiting for retry.
    func install(_ grid: IconNativeGrid) {
        _ = storage.storeIfNil(grid.storage)
    }

    /// Downloader-only disk validation. Unlike `get()`, this always inspects the final artifact.
    func validateFileAndInstall() throws {
        let fingerprint = IconNativeGridFileFingerprint.read(file: file)
        let loaded = try loadStorage(fingerprint: fingerprint)
        _ = storage.storeIfNil(loaded)
    }

    private func loadStorage(fingerprint: IconNativeGridFileFingerprint?) throws -> IconNativeGridStorage {
        guard fingerprint != nil else {
            throw IconNativeDomainError.missingGridArtifact(file)
        }
        do {
            let storage = try IconNativeGridStorage(file: URL(fileURLWithPath: file))
            guard storage.gridNumber == identity.gridNumber else {
                throw IconNativeDomainError.invalidGridArtifact(path: file, reason: "expected grid number \(identity.gridNumber), got \(storage.gridNumber)")
            }
            guard storage.gridUUID == identity.gridUUID else {
                throw IconNativeDomainError.invalidGridArtifact(path: file, reason: "grid UUID does not match \(identity.gridUUIDHex)")
            }
            guard storage.cellCount == identity.cellCount else {
                throw IconNativeDomainError.invalidGridArtifact(path: file, reason: "expected \(identity.cellCount) cells, got \(storage.cellCount)")
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
        switch self {
        case .iconNative, .iconD2Native, .iconD2Native15min:
            return true
        default:
            return false
        }
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
        var published = false
        defer {
            if !published {
                try? FileManager.default.removeItem(atPath: stagedArtifactPath)
            }
        }

        let grid: IconNativeGrid
        do {
            grid = try IconNativeGridGenerator.generate(
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
            grid = try IconNativeGridGenerator.generate(
                sourceFile: sourceFile,
                identity: identity,
                artifactFile: stagedArtifactPath
            )
        }

        // The mmap remains valid across rename because it owns the staged file descriptor. Publish
        // only after complete validation, then cache that same mapping without reopening the file.
        try FileManager.default.moveFileOverwrite(from: stagedArtifactPath, to: artifactPath)
        nativeGridCache.install(grid)
        published = true
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

struct IconNativeGribMetadata: Sendable, Equatable {
    let edition: Int?
    let gridType: String?
    let gridDefinitionTemplateNumber: Int?
    let numberOfGridUsed: Int?
    let uuidOfHGrid: String?
    let numberOfDataPoints: Int?

    init(message: GribMessage) {
        edition = message.getLong(attribute: "edition")
        gridType = message.get(attribute: "gridType")
        gridDefinitionTemplateNumber = message.getLong(attribute: "gridDefinitionTemplateNumber")
        numberOfGridUsed = message.getLong(attribute: "numberOfGridUsed")
        uuidOfHGrid = message.get(attribute: "uuidOfHGrid")
        numberOfDataPoints = message.getLong(attribute: "numberOfDataPoints")
    }

    init(edition: Int?, gridType: String?, gridDefinitionTemplateNumber: Int?, numberOfGridUsed: Int?, uuidOfHGrid: String?, numberOfDataPoints: Int?) {
        self.edition = edition
        self.gridType = gridType
        self.gridDefinitionTemplateNumber = gridDefinitionTemplateNumber
        self.numberOfGridUsed = numberOfGridUsed
        self.uuidOfHGrid = uuidOfHGrid
        self.numberOfDataPoints = numberOfDataPoints
    }
}

enum IconNativeGribError: Error, Equatable, CustomStringConvertible {
    case invalidEdition(Int?)
    case invalidGridType(String?)
    case invalidGridDefinitionTemplate(Int?)
    case invalidGridNumber(expected: UInt32, actual: Int?)
    case invalidGridUUID(expected: String, actual: String?)
    case invalidDataPointCount(expected: Int, actual: Int?)
    case invalidDecodedValueCount(expected: Int, actual: Int)

    var description: String {
        switch self {
        case .invalidEdition(let actual):
            return "Expected GRIB edition 2, got \(String(describing: actual))"
        case .invalidGridType(let actual):
            return "Expected unstructured_grid, got \(String(describing: actual))"
        case .invalidGridDefinitionTemplate(let actual):
            return "Expected grid definition template 3.101, got \(String(describing: actual))"
        case .invalidGridNumber(let expected, let actual):
            return "Expected ICON grid number \(expected), got \(String(describing: actual))"
        case .invalidGridUUID(let expected, let actual):
            return "Expected ICON grid UUID \(expected), got \(String(describing: actual))"
        case .invalidDataPointCount(let expected, let actual):
            return "Expected \(expected) ICON data points, got \(String(describing: actual))"
        case .invalidDecodedValueCount(let expected, let actual):
            return "Expected \(expected) bitmap-expanded ICON values, got \(actual)"
        }
    }
}

extension IconNativeGribMetadata {
    func validate(identity: IconNativeGridIdentity) throws {
        guard edition == 2 else {
            throw IconNativeGribError.invalidEdition(edition)
        }
        guard gridType == "unstructured_grid" else {
            throw IconNativeGribError.invalidGridType(gridType)
        }
        guard gridDefinitionTemplateNumber == 101 else {
            throw IconNativeGribError.invalidGridDefinitionTemplate(gridDefinitionTemplateNumber)
        }
        guard numberOfGridUsed == Int(identity.gridNumber) else {
            throw IconNativeGribError.invalidGridNumber(expected: identity.gridNumber, actual: numberOfGridUsed)
        }
        guard uuidOfHGrid?.lowercased() == identity.gridUUIDHex else {
            throw IconNativeGribError.invalidGridUUID(expected: identity.gridUUIDHex, actual: uuidOfHGrid)
        }
        guard numberOfDataPoints == identity.cellCount else {
            throw IconNativeGribError.invalidDataPointCount(expected: identity.cellCount, actual: numberOfDataPoints)
        }
    }
}

enum IconNativeGribDecoder {
    static func validateDecodedValueCount(_ count: Int, identity: IconNativeGridIdentity) throws {
        guard count == identity.cellCount else {
            throw IconNativeGribError.invalidDecodedValueCount(expected: identity.cellCount, actual: count)
        }
    }

    static func decode(message: GribMessage, identity: IconNativeGridIdentity) throws -> Array2D {
        try IconNativeGribMetadata(message: message).validate(identity: identity)
        // ecCodes expands a GRIB bitmap to the complete data-point sequence. Verifying the final
        // length protects the invariant that array offset equals the native cell index.
        let values = try message.getDouble().map(Float.init)
        try validateDecodedValueCount(values.count, identity: identity)
        return Array2D(data: values, nx: identity.cellCount, ny: 1)
    }
}
