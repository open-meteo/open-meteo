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

enum IconNativeDomainError: Error, Equatable, CustomStringConvertible {
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

private enum IconNativeGridCache {
    /// Keep one mmap alive per physical grid. ICON-D2 hourly and 15-minute domains deliberately
    /// share grid 47 and therefore the same cache entry and `grid.bin`.
    private static let grids = Mutex<[UInt32: IconNativeGrid]>([:])

    static func get(registry: DomainRegistry, identity: IconNativeGridIdentity) throws -> IconNativeGrid {
        if let cached = grids.withLock({ $0[identity.gridNumber] }) {
            return cached
        }
        let grid = try load(registry: registry, identity: identity)
        grids.withLock { $0[identity.gridNumber] = grid }
        return grid
    }

    static func store(_ grid: IconNativeGrid, identity: IconNativeGridIdentity) {
        grids.withLock { $0[identity.gridNumber] = grid }
    }

    static func load(registry: DomainRegistry, identity: IconNativeGridIdentity) throws -> IconNativeGrid {
        let path = "\(registry.directory)static/grid.bin"
        guard FileManager.default.fileExists(atPath: path) else {
            throw IconNativeDomainError.missingGridArtifact(path)
        }
        do {
            let grid = try IconNativeGrid(file: URL(fileURLWithPath: path))
            guard grid.gridNumber == identity.gridNumber else {
                throw IconNativeDomainError.invalidGridArtifact(path: path, reason: "expected grid number \(identity.gridNumber), got \(grid.gridNumber)")
            }
            guard grid.gridUUID == identity.gridUUID else {
                throw IconNativeDomainError.invalidGridArtifact(path: path, reason: "grid UUID does not match \(identity.gridUUIDHex)")
            }
            guard grid.nx == identity.cellCount, grid.ny == 1 else {
                throw IconNativeDomainError.invalidGridArtifact(path: path, reason: "expected \(identity.cellCount) cells, got \(grid.nx * grid.ny)")
            }
            return grid
        } catch let error as IconNativeDomainError {
            throw error
        } catch {
            throw IconNativeDomainError.invalidGridArtifact(path: path, reason: String(describing: error))
        }
    }
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

    func requireNativeGrid() throws -> IconNativeGrid {
        switch self {
        case .iconNative:
            return try IconNativeGridCache.get(registry: .dwd_icon_global_native, identity: .global)
        case .iconD2Native, .iconD2Native15min:
            return try IconNativeGridCache.get(registry: .dwd_icon_d2_native, identity: .d2)
        default:
            preconditionFailure("\(self) is not a native ICON domain")
        }
    }

    func prepareNativeGrid(application: Application) async throws {
        guard let identity = nativeGridIdentity else {
            return
        }
        guard let registry = domainRegistryStatic else {
            preconditionFailure("Native ICON domain has no static registry")
        }
        do {
            // The common case performs only mmap validation and populates the process cache.
            let grid = try IconNativeGridCache.load(registry: registry, identity: identity)
            IconNativeGridCache.store(grid, identity: identity)
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

        let artifact: Data
        do {
            artifact = try IconNativeGridGenerator.generate(sourceFile: sourceFile, identity: identity)
        } catch let error as IconNativeGridSourceError where sourceExisted {
            // A cached source may be truncated or may belong to an older operational grid. Retry
            // source errors once with a fresh download; generation errors are retained for diagnosis.
            application.logger.warning("Discarding unusable cached ICON grid definition and downloading it again: \(error)")
            try FileManager.default.removeItem(atPath: sourceFile)
            try await downloadSource()
            artifact = try IconNativeGridGenerator.generate(sourceFile: sourceFile, identity: identity)
        }

        let artifactPath = "\(staticDirectory)grid.bin"
        try artifact.write(to: URL(fileURLWithPath: artifactPath), options: .atomic)
        let grid = try IconNativeGridCache.load(registry: registry, identity: identity)
        IconNativeGridCache.store(grid, identity: identity)
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
    let gridBounds = GridBounds(lat_bounds: -90...90, lon_bounds: -180...180)

    func findPoint(lat: Float, lon: Float) -> Int? { nil }
    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? { nil }
    func findBox(boundingBox bb: BoundingBoxWGS84) -> Range<Int>? { nil }
    func estimatedNumberOfGridCells(boundingBox bb: BoundingBoxWGS84) -> Int? { nil }
    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) { (.nan, .nan) }
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
