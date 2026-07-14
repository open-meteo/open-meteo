import Foundation
import OmFileFormat

/// A native ICON triangular grid backed by a memory-mappable lookup artifact.
///
/// The artifact stores cell centres, the three neighbours of every cell and one seed cell per
/// regular latitude/longitude bin. A lookup evaluates the seed, its neighbours and the second
/// neighbour ring. An undisturbed triangular mesh has at most ten unique cells in those rings,
/// making lookup cost independent of the number of cells in the grid.
struct IconNativeGrid: Gridable {
    typealias SliceType = Range<Int>

    static let missingIndex = UInt32.max
    static let maximumCandidateCount = 10

    let storage: IconNativeGridStorage

    init(file: URL) throws {
        storage = try IconNativeGridStorage(file: file)
    }

    /// Map generated artifact data through a temporary file. The file can be unlinked immediately
    /// after `mmap`; the mapping and its file handle remain owned by `MmapFile`.
    static func loadMapped(data: Data) throws -> Self {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-native-grid-\(UUID().uuidString).bin")
        try data.write(to: file, options: .atomic)
        defer { try? FileManager.default.removeItem(at: file) }
        return try Self(file: file)
    }

    var nx: Int { storage.cellCount }
    var ny: Int { 1 }
    var searchRadius: Int { 2 }
    var gridNumber: UInt32 { storage.gridNumber }
    var gridUUID: [UInt8] { storage.gridUUID }
    var gridSourceChecksum: [UInt8] { storage.sourceChecksum }

    var gridBounds: GridBounds {
        storage.bounds
    }

    var crsWkt2: String {
        """
        GEOGCRS["ICON Native Grid",
            DATUM["Sphere",
                ELLIPSOID["Sphere",6371229,0]],
            CS[ellipsoidal,2],
                AXIS["latitude",north],
                AXIS["longitude",east],
                ANGLEUNIT["degree",0.0174532925199433]]
        """
    }

    func findPoint(lat: Float, lon: Float) -> Int? {
        findPointWithCandidateCount(lat: lat, lon: lon)?.gridpoint
    }

    /// Exposed internally for invariant and performance tests.
    func findPointWithCandidateCount(lat: Float, lon: Float) -> (gridpoint: Int, candidateCount: Int)? {
        guard let query = lookupInput(lat: lat, lon: lon) else {
            return nil
        }
        let candidates = surroundingGridpoints(seed: query.seed)
        var bestIndex = -1
        var bestDot = -Float.greatestFiniteMagnitude
        for position in 0..<candidates.count {
            let index = candidates.points[position]
            let dot = storage.center(at: index).dot(query.point)
            if dot > bestDot || (dot == bestDot && index < bestIndex) {
                bestDot = dot
                bestIndex = index
            }
        }
        return bestIndex >= 0 ? (bestIndex, candidates.count) : nil
    }

    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? {
        nil
    }

    /// Rectangular slices have no meaningful representation on the unstructured native grid.
    func findBox(boundingBox bb: BoundingBoxWGS84) -> Range<Int>? {
        nil
    }

    func estimatedNumberOfGridCells(boundingBox bb: BoundingBoxWGS84) -> Int? {
        nil
    }

    func getCoordinates(gridpoint: Int) -> (latitude: Float, longitude: Float) {
        precondition(gridpoint >= 0 && gridpoint < storage.cellCount, "ICON grid point out of range")
        let point = storage.center(at: gridpoint)
        let latitude = asin(max(-1, min(1, point.z))) * 180 / .pi
        let longitude = atan2(point.y, point.x) * 180 / .pi
        return (latitude, longitude)
    }

    func findPointInSea(lat: Float, lon: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let query = lookupInput(lat: lat, lon: lon) else {
            return nil
        }
        let candidates = surroundingGridpoints(seed: query.seed)
        let nearest = nearestCandidate(candidates: candidates, point: query.point)
        let nearestElevation = try await readFromStaticFile(gridpoint: nearest.gridpoint, file: elevationFile)
        if nearestElevation <= -999 {
            return (nearest.gridpoint, .sea)
        }
        let elevations = try await readElevations(
            candidates: candidates,
            knownPosition: nearest.position,
            knownValue: nearestElevation,
            elevationFile: elevationFile
        )

        var bestPosition = -1
        var bestDot = -Float.greatestFiniteMagnitude
        for position in 0..<candidates.count where elevations[position] <= -999 {
            let dot = storage.center(at: candidates.points[position]).dot(query.point)
            if dot > bestDot || (dot == bestDot && candidates.points[position] < candidates.points[bestPosition]) {
                bestDot = dot
                bestPosition = position
            }
        }
        guard bestPosition >= 0 else {
            if elevations[nearest.position].isNaN {
                return (nearest.gridpoint, .noData)
            }
            return elevationResult(gridpoint: nearest.gridpoint, value: elevations[nearest.position])
        }
        return (candidates.points[bestPosition], .sea)
    }

    func findPointTerrainOptimised(lat: Float, lon: Float, elevation: Float, elevationFile: any OmFileReaderArrayProtocol<Float>) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let query = lookupInput(lat: lat, lon: lon) else {
            return nil
        }
        let candidates = surroundingGridpoints(seed: query.seed)
        let nearest = nearestCandidate(candidates: candidates, point: query.point)
        let nearestElevation = try await readFromStaticFile(gridpoint: nearest.gridpoint, file: elevationFile)
        if nearestElevation.isFinite, nearestElevation > -999, abs(nearestElevation - elevation) <= 100 {
            return elevationResult(gridpoint: nearest.gridpoint, value: nearestElevation)
        }
        let elevations = try await readElevations(
            candidates: candidates,
            knownPosition: nearest.position,
            knownValue: nearestElevation,
            elevationFile: elevationFile
        )

        var bestPosition = -1
        var bestScore = Float.greatestFiniteMagnitude
        for position in 0..<candidates.count {
            let candidateElevation = elevations[position]
            if !candidateElevation.isFinite || candidateElevation <= -999 {
                continue
            }
            let dot = max(-1, min(1, storage.center(at: candidates.points[position]).dot(query.point)))
            let distanceKilometres = acos(dot) * 6371.229
            if distanceKilometres >= 50 {
                continue
            }
            let elevationDelta = candidateElevation >= 9999 ? 0 : abs(candidateElevation - elevation)
            let score = elevationDelta + distanceKilometres * 30
            if score < bestScore || (score == bestScore && candidates.points[position] < candidates.points[bestPosition]) {
                bestScore = score
                bestPosition = position
            }
        }

        if bestPosition < 0 || bestScore > 1500 {
            return elevationResult(gridpoint: nearest.gridpoint, value: nearestElevation)
        }
        return elevationResult(gridpoint: candidates.points[bestPosition], value: elevations[bestPosition])
    }

    private func lookupInput(lat: Float, lon: Float) -> (point: IconNativeGridPoint, seed: Int)? {
        guard lat.isFinite, lon.isFinite, lat >= -90, lat <= 90 else {
            return nil
        }
        let longitude = storage.isGlobal ? normalisedLongitude(lon) : lon
        guard let bin = storage.seedBin(lat: lat, lon: longitude) else {
            return nil
        }
        if storage.hasCoverage {
            switch storage.coverage(at: bin) {
            case 0:
                return nil
            case 1:
                break
            case 2:
                let point = IconNativeGridPoint(latitude: lat, longitude: longitude)
                guard storage.contains(point: point, boundaryBin: bin) else {
                    return nil
                }
                let seed = storage.seed(at: bin)
                return seed == Self.missingIndex ? nil : (point, Int(seed))
            default:
                return nil
            }
        }
        let seed = storage.seed(at: bin)
        guard seed != Self.missingIndex else {
            return nil
        }
        return (IconNativeGridPoint(latitude: lat, longitude: longitude), Int(seed))
    }

    private func surroundingGridpoints(seed: Int) -> (points: InlineArray<10, Int>, count: Int) {
        var points = InlineArray<10, Int>(repeating: -1)
        var count = 0

        @inline(__always) func append(_ point: Int, points: inout InlineArray<10, Int>, count: inout Int) {
            guard point >= 0 else {
                return
            }
            for position in 0..<count where points[position] == point {
                return
            }
            precondition(count < Self.maximumCandidateCount, "ICON topology exceeds the two-ring candidate bound")
            points[count] = point
            count += 1
        }

        append(seed, points: &points, count: &count)
        for neighbourPosition in 0..<3 {
            let neighbour = storage.neighbour(cell: seed, position: neighbourPosition)
            if neighbour != Self.missingIndex {
                append(Int(neighbour), points: &points, count: &count)
            }
        }
        let firstRingEnd = count
        if firstRingEnd > 1 {
            for position in 1..<firstRingEnd {
                let cell = points[position]
                for neighbourPosition in 0..<3 {
                    let neighbour = storage.neighbour(cell: cell, position: neighbourPosition)
                    if neighbour != Self.missingIndex {
                        append(Int(neighbour), points: &points, count: &count)
                    }
                }
            }
        }
        return (points, count)
    }

    private func nearestCandidate(candidates: (points: InlineArray<10, Int>, count: Int), point: IconNativeGridPoint) -> (gridpoint: Int, position: Int) {
        var bestPosition = 0
        var bestDot = -Float.greatestFiniteMagnitude
        for position in 0..<candidates.count {
            let index = candidates.points[position]
            let dot = storage.center(at: index).dot(point)
            if dot > bestDot || (dot == bestDot && index < candidates.points[bestPosition]) {
                bestDot = dot
                bestPosition = position
            }
        }
        return (candidates.points[bestPosition], bestPosition)
    }

    private func readElevations(
        candidates: (points: InlineArray<10, Int>, count: Int),
        knownPosition: Int,
        knownValue: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> [Float] {
        let sorted = (0..<candidates.count).filter { $0 != knownPosition }.map {
            (gridpoint: candidates.points[$0], originalPosition: $0)
        }.sorted {
            $0.gridpoint < $1.gridpoint
        }
        var result = [Float](repeating: .nan, count: candidates.count)
        result[knownPosition] = knownValue
        var start = 0
        while start < sorted.count {
            var end = start
            while end + 1 < sorted.count, sorted[end + 1].gridpoint == sorted[end].gridpoint + 1 {
                end += 1
            }
            let lower = UInt64(sorted[start].gridpoint)
            let upper = UInt64(sorted[end].gridpoint + 1)
            let values = try await elevationFile.read(range: [0..<1, lower..<upper])
            for position in start...end {
                result[sorted[position].originalPosition] = values[sorted[position].gridpoint - sorted[start].gridpoint]
            }
            start = end + 1
        }
        return result
    }

    private func elevationResult(gridpoint: Int, value: Float) -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        if value.isNaN {
            return nil
        }
        if value <= -999 {
            return (gridpoint, .sea)
        }
        if value >= 9999 {
            return (gridpoint, .landWithoutElevation)
        }
        return (gridpoint, .elevation(value))
    }

    private func normalisedLongitude(_ longitude: Float) -> Float {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value < -180 {
            value += 360
        } else if value >= 180 {
            value -= 360
        }
        return value
    }
}

enum IconNativeGridError: Error, Equatable, CustomStringConvertible {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case invalidHeader
    case invalidChecksum
    case invalidCenter(Int)
    case invalidNeighbour(cell: Int, neighbour: UInt32)
    case asymmetricNeighbour(cell: Int, neighbour: Int)
    case invalidSeed(bin: Int, seed: UInt32)
    case seedProofFailed(bin: Int, omittedCell: Int)
    case invalidCoverage(bin: Int, value: UInt8)
    case invalidBoundaryIndex(bin: Int)

    var description: String {
        switch self {
        case .invalidMagic: "Invalid ICON native grid magic"
        case .unsupportedVersion(let version): "Unsupported ICON native grid version \(version)"
        case .invalidHeader: "Invalid ICON native grid header or section layout"
        case .invalidChecksum: "ICON native grid checksum mismatch"
        case .invalidCenter(let cell): "Invalid ICON cell centre at index \(cell)"
        case .invalidNeighbour(let cell, let neighbour): "Invalid ICON neighbour \(neighbour) for cell \(cell)"
        case .asymmetricNeighbour(let cell, let neighbour): "ICON neighbour relation \(cell)-\(neighbour) is not symmetric"
        case .invalidSeed(let bin, let seed): "Invalid ICON seed \(seed) in bin \(bin)"
        case .seedProofFailed(let bin, let omittedCell): "ICON seed proof failed in bin \(bin); cell \(omittedCell) is outside the seed's two topology rings"
        case .invalidCoverage(let bin, let value): "Invalid ICON coverage value \(value) in bin \(bin)"
        case .invalidBoundaryIndex(let bin): "Invalid ICON boundary triangle index in bin \(bin)"
        }
    }
}

struct IconNativeGridPoint: Sendable, Equatable {
    let x: Float
    let y: Float
    let z: Float

    init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    init(latitude: Float, longitude: Float) {
        if latitude >= 90 {
            self.init(x: 0, y: 0, z: 1)
            return
        }
        if latitude <= -90 {
            self.init(x: 0, y: 0, z: -1)
            return
        }
        let latitudeRadians = latitude * .pi / 180
        let longitudeRadians = longitude * .pi / 180
        let cosLatitude = cos(latitudeRadians)
        self.init(
            x: cosLatitude * cos(longitudeRadians),
            y: cosLatitude * sin(longitudeRadians),
            z: sin(latitudeRadians)
        )
    }

    @inline(__always) func dot(_ other: Self) -> Float {
        x * other.x + y * other.y + z * other.z
    }

    @inline(__always) func cross(_ other: Self) -> Self {
        Self(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }
}

struct IconNativeGridBoundaryTriangle: Sendable, Equatable {
    let a: IconNativeGridPoint
    let b: IconNativeGridPoint
    let c: IconNativeGridPoint

    func contains(_ point: IconNativeGridPoint) -> Bool {
        let angularTolerance: Float = 1e-6
        return isInsideEdge(a: a, b: b, opposite: c, point: point, tolerance: angularTolerance)
            && isInsideEdge(a: b, b: c, opposite: a, point: point, tolerance: angularTolerance)
            && isInsideEdge(a: c, b: a, opposite: b, point: point, tolerance: angularTolerance)
    }

    private func isInsideEdge(a: IconNativeGridPoint, b: IconNativeGridPoint, opposite: IconNativeGridPoint, point: IconNativeGridPoint, tolerance: Float) -> Bool {
        let normal = a.cross(b)
        let length = sqrt(normal.dot(normal))
        guard length > 1e-8 else {
            return false
        }
        let signedDistance = normal.dot(point) / length
        let orientation: Float = normal.dot(opposite) >= 0 ? 1 : -1
        return signedDistance * orientation >= -tolerance
    }
}

/// Writer used by the offline grid converter and by grid invariant tests. Production lookup only
/// needs `IconNativeGrid`; it never builds this representation at runtime.
enum IconNativeGridArtifact {
    static let magic = Array("ICONNG01".utf8)
    static let version: UInt32 = 1
    static let headerSize = 192
    static let globalFlag: UInt32 = 1
    static let coverageFlag: UInt32 = 2

    struct Metadata: Sendable {
        let gridNumber: UInt32
        let gridUUID: [UInt8]
        let sourceChecksum: [UInt8]
        let isGlobal: Bool
        let bounds: GridBounds
        let seedNx: Int
        let seedNy: Int
        let seedLatMin: Float
        let seedLonMin: Float
        let seedDx: Float
        let seedDy: Float
    }

    static func make(
        metadata: Metadata,
        centers: [IconNativeGridPoint],
        neighbours: [[UInt32]],
        seeds: [UInt32],
        coverage: [UInt8]? = nil,
        boundaryOffsets: [UInt32]? = nil,
        boundaryTriangles: [IconNativeGridBoundaryTriangle] = []
    ) throws -> Data {
        let binCount = metadata.seedNx * metadata.seedNy
        guard metadata.gridUUID.count == 16,
              metadata.sourceChecksum.count == 32,
              !centers.isEmpty,
              neighbours.count == centers.count,
              neighbours.allSatisfy({ $0.count == 3 }),
              seeds.count == binCount,
              metadata.seedNx > 0,
              metadata.seedNy > 0,
              metadata.seedDx > 0,
              metadata.seedDy > 0 else {
            throw IconNativeGridError.invalidHeader
        }
        if let coverage {
            guard coverage.count == binCount,
                  boundaryOffsets?.count == binCount + 1 else {
                throw IconNativeGridError.invalidHeader
            }
        } else if boundaryOffsets != nil || !boundaryTriangles.isEmpty {
            throw IconNativeGridError.invalidHeader
        }

        var data = Data(repeating: 0, count: headerSize)
        let centersOffset = data.count
        for center in centers {
            data.appendFloat(center.x)
            data.appendFloat(center.y)
            data.appendFloat(center.z)
        }
        data.padToEightBytes()
        let neighboursOffset = data.count
        for cellNeighbours in neighbours {
            for neighbour in cellNeighbours {
                data.appendInteger(neighbour)
            }
        }
        data.padToEightBytes()
        let seedsOffset = data.count
        for seed in seeds {
            data.appendInteger(seed)
        }
        data.padToEightBytes()

        var coverageOffset = 0
        var boundaryOffsetsOffset = 0
        var boundaryTrianglesOffset = 0
        if let coverage, let boundaryOffsets {
            coverageOffset = data.count
            data.append(contentsOf: coverage)
            data.padToEightBytes()
            boundaryOffsetsOffset = data.count
            for offset in boundaryOffsets {
                data.appendInteger(offset)
            }
            data.padToEightBytes()
            boundaryTrianglesOffset = data.count
            for triangle in boundaryTriangles {
                for point in [triangle.a, triangle.b, triangle.c] {
                    data.appendFloat(point.x)
                    data.appendFloat(point.y)
                    data.appendFloat(point.z)
                }
            }
            data.padToEightBytes()
        }

        data.replaceSubrange(0..<magic.count, with: magic)
        data.writeInteger(version, at: 8)
        data.writeInteger(UInt32(headerSize), at: 12)
        var flags: UInt32 = metadata.isGlobal ? globalFlag : 0
        if coverage != nil {
            flags |= coverageFlag
        }
        data.writeInteger(flags, at: 16)
        data.writeInteger(metadata.gridNumber, at: 20)
        data.writeInteger(UInt32(centers.count), at: 24)
        data.writeInteger(UInt32(metadata.seedNx), at: 28)
        data.writeInteger(UInt32(metadata.seedNy), at: 32)
        data.writeFloat(metadata.seedLatMin, at: 36)
        data.writeFloat(metadata.seedLonMin, at: 40)
        data.writeFloat(metadata.seedDx, at: 44)
        data.writeFloat(metadata.seedDy, at: 48)
        data.writeFloat(metadata.bounds.lat_bounds.lowerBound, at: 52)
        data.writeFloat(metadata.bounds.lat_bounds.upperBound, at: 56)
        data.writeFloat(metadata.bounds.lon_bounds.lowerBound, at: 60)
        data.writeFloat(metadata.bounds.lon_bounds.upperBound, at: 64)
        data.writeInteger(UInt32(IconNativeGrid.maximumCandidateCount), at: 68)
        data.writeInteger(UInt64(centersOffset), at: 72)
        data.writeInteger(UInt64(neighboursOffset), at: 80)
        data.writeInteger(UInt64(seedsOffset), at: 88)
        data.writeInteger(UInt64(coverageOffset), at: 96)
        data.writeInteger(UInt64(boundaryOffsetsOffset), at: 104)
        data.writeInteger(UInt64(boundaryTrianglesOffset), at: 112)
        data.writeInteger(UInt32(boundaryTriangles.count), at: 120)
        data.replaceSubrange(136..<152, with: metadata.gridUUID)
        data.writeInteger(UInt64(data.count), at: 152)
        data.replaceSubrange(160..<192, with: metadata.sourceChecksum)
        let checksum = data.withUnsafeBytes {
            iconNativeGridChecksum(bytes: RawSpan(_unsafeBytes: $0))
        }
        data.writeInteger(checksum, at: 128)

        // Run the same validation as the runtime loader before emitting an artifact.
        _ = try IconNativeGrid.loadMapped(data: data)
        try IconNativeGridSeedProof.validate(
            metadata: metadata,
            centers: centers,
            neighbours: neighbours,
            seeds: seeds,
            coverage: coverage
        )
        return data
    }
}

final class IconNativeGridStorage: @unchecked Sendable {
    private let mapped: MmapFile

    let isGlobal: Bool
    let hasCoverage: Bool
    let gridNumber: UInt32
    let gridUUID: [UInt8]
    let sourceChecksum: [UInt8]
    let cellCount: Int
    let seedNx: Int
    let seedNy: Int
    let seedLatMin: Float
    let seedLonMin: Float
    let seedDx: Float
    let seedDy: Float
    let bounds: GridBounds

    private let centersOffset: Int
    private let neighboursOffset: Int
    private let seedsOffset: Int
    private let coverageOffset: Int
    private let boundaryOffsetsOffset: Int
    private let boundaryTrianglesOffset: Int
    private let boundaryTriangleCount: Int

    init(file: URL) throws {
        let fileHandle = try FileHandle.openFileReading(file: file.path)
        let mapped = try MmapFile(fn: fileHandle)
        guard !mapped.data.isEmpty else {
            throw IconNativeGridError.invalidHeader
        }
        self.mapped = mapped
        let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data))
        let length = mapped.data.count
        guard length >= IconNativeGridArtifact.headerSize else {
            throw IconNativeGridError.invalidHeader
        }
        var magicMatches = true
        for offset in IconNativeGridArtifact.magic.indices where Self.readUInt8(bytes, at: offset) != IconNativeGridArtifact.magic[offset] {
            magicMatches = false
        }
        guard magicMatches else {
            throw IconNativeGridError.invalidMagic
        }
        let version = Self.readUInt32(bytes, at: 8)
        guard version == IconNativeGridArtifact.version else {
            throw IconNativeGridError.unsupportedVersion(version)
        }
        guard Self.readUInt32(bytes, at: 12) == IconNativeGridArtifact.headerSize,
              Self.readUInt64(bytes, at: 152) == length else {
            throw IconNativeGridError.invalidHeader
        }
        let checksum = iconNativeGridChecksum(bytes: bytes)
        guard checksum == Self.readUInt64(bytes, at: 128) else {
            throw IconNativeGridError.invalidChecksum
        }

        let flags = Self.readUInt32(bytes, at: 16)
        guard flags & ~(IconNativeGridArtifact.globalFlag | IconNativeGridArtifact.coverageFlag) == 0 else {
            throw IconNativeGridError.invalidHeader
        }
        isGlobal = flags & IconNativeGridArtifact.globalFlag != 0
        hasCoverage = flags & IconNativeGridArtifact.coverageFlag != 0
        gridNumber = Self.readUInt32(bytes, at: 20)
        cellCount = Int(Self.readUInt32(bytes, at: 24))
        seedNx = Int(Self.readUInt32(bytes, at: 28))
        seedNy = Int(Self.readUInt32(bytes, at: 32))
        seedLatMin = Self.readFloat(bytes, at: 36)
        seedLonMin = Self.readFloat(bytes, at: 40)
        seedDx = Self.readFloat(bytes, at: 44)
        seedDy = Self.readFloat(bytes, at: 48)
        let latitudeLowerBound = Self.readFloat(bytes, at: 52)
        let latitudeUpperBound = Self.readFloat(bytes, at: 56)
        let longitudeLowerBound = Self.readFloat(bytes, at: 60)
        let longitudeUpperBound = Self.readFloat(bytes, at: 64)
        guard latitudeLowerBound.isFinite,
              latitudeUpperBound.isFinite,
              longitudeLowerBound.isFinite,
              longitudeUpperBound.isFinite,
              latitudeLowerBound <= latitudeUpperBound,
              longitudeLowerBound <= longitudeUpperBound else {
            throw IconNativeGridError.invalidHeader
        }
        bounds = GridBounds(
            lat_bounds: latitudeLowerBound...latitudeUpperBound,
            lon_bounds: longitudeLowerBound...longitudeUpperBound
        )
        guard let parsedCentersOffset = Int(exactly: Self.readUInt64(bytes, at: 72)),
              let parsedNeighboursOffset = Int(exactly: Self.readUInt64(bytes, at: 80)),
              let parsedSeedsOffset = Int(exactly: Self.readUInt64(bytes, at: 88)),
              let parsedCoverageOffset = Int(exactly: Self.readUInt64(bytes, at: 96)),
              let parsedBoundaryOffsetsOffset = Int(exactly: Self.readUInt64(bytes, at: 104)),
              let parsedBoundaryTrianglesOffset = Int(exactly: Self.readUInt64(bytes, at: 112)) else {
            throw IconNativeGridError.invalidHeader
        }
        centersOffset = parsedCentersOffset
        neighboursOffset = parsedNeighboursOffset
        seedsOffset = parsedSeedsOffset
        coverageOffset = parsedCoverageOffset
        boundaryOffsetsOffset = parsedBoundaryOffsetsOffset
        boundaryTrianglesOffset = parsedBoundaryTrianglesOffset
        boundaryTriangleCount = Int(Self.readUInt32(bytes, at: 120))
        var gridUUID = [UInt8]()
        gridUUID.reserveCapacity(16)
        for offset in 136..<152 {
            gridUUID.append(Self.readUInt8(bytes, at: offset))
        }
        self.gridUUID = gridUUID
        var sourceChecksum = [UInt8]()
        sourceChecksum.reserveCapacity(32)
        for offset in 160..<192 {
            sourceChecksum.append(Self.readUInt8(bytes, at: offset))
        }
        self.sourceChecksum = sourceChecksum

        guard cellCount > 0,
              seedNx > 0,
              seedNy > 0,
              seedDx.isFinite,
              seedDy.isFinite,
              seedDx > 0,
              seedDy > 0,
              seedLatMin.isFinite,
              seedLonMin.isFinite,
              Self.readUInt32(bytes, at: 68) == IconNativeGrid.maximumCandidateCount,
              bounds.lat_bounds.lowerBound >= -90,
              bounds.lat_bounds.upperBound <= 90,
              bounds.lat_bounds.lowerBound <= bounds.lat_bounds.upperBound,
              bounds.lon_bounds.lowerBound <= bounds.lon_bounds.upperBound,
              let centerBytes = Self.multiplied(cellCount, 12),
              let neighbourBytes = Self.multiplied(cellCount, 12),
              let binCount = Self.multiplied(seedNx, seedNy),
              let seedBytes = Self.multiplied(binCount, 4),
              Self.validSection(offset: centersOffset, length: centerBytes, dataLength: length),
              Self.validSection(offset: neighboursOffset, length: neighbourBytes, dataLength: length),
              Self.validSection(offset: seedsOffset, length: seedBytes, dataLength: length),
              centersOffset == IconNativeGridArtifact.headerSize,
              let expectedNeighboursOffset = Self.alignedEnd(offset: centersOffset, length: centerBytes),
              neighboursOffset == expectedNeighboursOffset,
              let expectedSeedsOffset = Self.alignedEnd(offset: neighboursOffset, length: neighbourBytes),
              seedsOffset == expectedSeedsOffset,
              let expectedAfterSeeds = Self.alignedEnd(offset: seedsOffset, length: seedBytes) else {
            throw IconNativeGridError.invalidHeader
        }

        if isGlobal {
            let latitudeSpan = Float(seedNy) * seedDy
            let longitudeSpan = Float(seedNx) * seedDx
            guard abs(seedLatMin + 90) < 1e-4,
                  abs(latitudeSpan - 180) < 1e-3,
                  abs(longitudeSpan - 360) < 1e-3 else {
                throw IconNativeGridError.invalidHeader
            }
        }

        if hasCoverage {
            guard coverageOffset > 0,
                  boundaryOffsetsOffset > 0,
                  boundaryTrianglesOffset > 0,
                  let boundaryIndexBytes = Self.multiplied(binCount + 1, 4),
                  let triangleBytes = Self.multiplied(boundaryTriangleCount, 36),
                  Self.validSection(offset: coverageOffset, length: binCount, dataLength: length),
                  Self.validSection(offset: boundaryOffsetsOffset, length: boundaryIndexBytes, dataLength: length),
                  Self.validSection(offset: boundaryTrianglesOffset, length: triangleBytes, dataLength: length),
                  coverageOffset == expectedAfterSeeds,
                  let expectedBoundaryOffsetsOffset = Self.alignedEnd(offset: coverageOffset, length: binCount),
                  boundaryOffsetsOffset == expectedBoundaryOffsetsOffset,
                  let expectedBoundaryTrianglesOffset = Self.alignedEnd(offset: boundaryOffsetsOffset, length: boundaryIndexBytes),
                  boundaryTrianglesOffset == expectedBoundaryTrianglesOffset,
                  let expectedFileSize = Self.alignedEnd(offset: boundaryTrianglesOffset, length: triangleBytes),
                  expectedFileSize == length else {
                throw IconNativeGridError.invalidHeader
            }
        } else {
            guard coverageOffset == 0,
                  boundaryOffsetsOffset == 0,
                  boundaryTrianglesOffset == 0,
                  boundaryTriangleCount == 0,
                  expectedAfterSeeds == length else {
                throw IconNativeGridError.invalidHeader
            }
        }

        try validate(bytes: bytes, binCount: binCount)
    }

    @inline(__always) func center(at cell: Int) -> IconNativeGridPoint {
        withBytes { center(at: cell, bytes: $0) }
    }

    @inline(__always) private func center(at cell: Int, bytes: borrowing RawSpan) -> IconNativeGridPoint {
        let offset = centersOffset + cell * 12
        return IconNativeGridPoint(
            x: Self.readFloat(bytes, at: offset),
            y: Self.readFloat(bytes, at: offset + 4),
            z: Self.readFloat(bytes, at: offset + 8)
        )
    }

    @inline(__always) func neighbour(cell: Int, position: Int) -> UInt32 {
        withBytes {
            Self.readUInt32($0, at: neighboursOffset + (cell * 3 + position) * 4)
        }
    }

    @inline(__always) private func neighbour(cell: Int, position: Int, bytes: borrowing RawSpan) -> UInt32 {
        Self.readUInt32(bytes, at: neighboursOffset + (cell * 3 + position) * 4)
    }

    @inline(__always) func seed(at bin: Int) -> UInt32 {
        withBytes { Self.readUInt32($0, at: seedsOffset + bin * 4) }
    }

    @inline(__always) private func seed(at bin: Int, bytes: borrowing RawSpan) -> UInt32 {
        Self.readUInt32(bytes, at: seedsOffset + bin * 4)
    }

    @inline(__always) func coverage(at bin: Int) -> UInt8 {
        withBytes { Self.readUInt8($0, at: coverageOffset + bin) }
    }

    func seedBin(lat: Float, lon: Float) -> Int? {
        let xValue = floor((lon - seedLonMin) / seedDx)
        let yValue = floor((lat - seedLatMin) / seedDy)
        guard xValue.isFinite, yValue.isFinite else {
            return nil
        }
        var x = Int(xValue)
        var y = Int(yValue)
        if isGlobal {
            x %= seedNx
            if x < 0 {
                x += seedNx
            }
            y = max(0, min(seedNy - 1, y))
        } else {
            if x == seedNx, abs(lon - (seedLonMin + Float(seedNx) * seedDx)) < 1e-5 {
                x = seedNx - 1
            }
            if y == seedNy, abs(lat - (seedLatMin + Float(seedNy) * seedDy)) < 1e-5 {
                y = seedNy - 1
            }
            guard x >= 0, x < seedNx, y >= 0, y < seedNy else {
                return nil
            }
        }
        return y * seedNx + x
    }

    func contains(point: IconNativeGridPoint, boundaryBin: Int) -> Bool {
        withBytes { bytes in
            contains(point: point, boundaryBin: boundaryBin, bytes: bytes)
        }
    }

    private func contains(point: IconNativeGridPoint, boundaryBin: Int, bytes: borrowing RawSpan) -> Bool {
        let lower = Int(Self.readUInt32(bytes, at: boundaryOffsetsOffset + boundaryBin * 4))
        let upper = Int(Self.readUInt32(bytes, at: boundaryOffsetsOffset + (boundaryBin + 1) * 4))
        guard lower <= upper, upper <= boundaryTriangleCount else {
            return false
        }
        for triangleIndex in lower..<upper {
            if boundaryTriangle(at: triangleIndex, bytes: bytes).contains(point) {
                return true
            }
        }
        return false
    }

    private func boundaryTriangle(at index: Int, bytes: borrowing RawSpan) -> IconNativeGridBoundaryTriangle {
        let offset = boundaryTrianglesOffset + index * 36
        func point(_ position: Int) -> IconNativeGridPoint {
            let pointOffset = offset + position * 12
            return IconNativeGridPoint(
                x: Self.readFloat(bytes, at: pointOffset),
                y: Self.readFloat(bytes, at: pointOffset + 4),
                z: Self.readFloat(bytes, at: pointOffset + 8)
            )
        }
        return IconNativeGridBoundaryTriangle(a: point(0), b: point(1), c: point(2))
    }

    private func validate(bytes: borrowing RawSpan, binCount: Int) throws {
        for cell in 0..<cellCount {
            let point = center(at: cell, bytes: bytes)
            let normSquared = point.dot(point)
            guard point.x.isFinite, point.y.isFinite, point.z.isFinite, abs(normSquared - 1) < 1e-5 else {
                throw IconNativeGridError.invalidCenter(cell)
            }
            var uniqueNeighbours = InlineArray<3, UInt32>(repeating: IconNativeGrid.missingIndex)
            var uniqueCount = 0
            for position in 0..<3 {
                let value = neighbour(cell: cell, position: position, bytes: bytes)
                if value == IconNativeGrid.missingIndex {
                    continue
                }
                guard value < cellCount, value != cell else {
                    throw IconNativeGridError.invalidNeighbour(cell: cell, neighbour: value)
                }
                for previous in 0..<uniqueCount where uniqueNeighbours[previous] == value {
                    throw IconNativeGridError.invalidNeighbour(cell: cell, neighbour: value)
                }
                uniqueNeighbours[uniqueCount] = value
                uniqueCount += 1
                var reciprocal = false
                for reciprocalPosition in 0..<3 where neighbour(cell: Int(value), position: reciprocalPosition, bytes: bytes) == cell {
                    reciprocal = true
                }
                guard reciprocal else {
                    throw IconNativeGridError.asymmetricNeighbour(cell: cell, neighbour: Int(value))
                }
            }
        }

        for bin in 0..<binCount {
            let seed = seed(at: bin, bytes: bytes)
            if seed != IconNativeGrid.missingIndex, seed >= cellCount {
                throw IconNativeGridError.invalidSeed(bin: bin, seed: seed)
            }
            if isGlobal, seed == IconNativeGrid.missingIndex {
                throw IconNativeGridError.invalidSeed(bin: bin, seed: seed)
            }
            guard hasCoverage else {
                continue
            }
            let coverage = Self.readUInt8(bytes, at: coverageOffset + bin)
            guard coverage <= 2 else {
                throw IconNativeGridError.invalidCoverage(bin: bin, value: coverage)
            }
            if coverage > 0, seed == IconNativeGrid.missingIndex {
                throw IconNativeGridError.invalidSeed(bin: bin, seed: seed)
            }
            let lower = Int(Self.readUInt32(bytes, at: boundaryOffsetsOffset + bin * 4))
            let upper = Int(Self.readUInt32(bytes, at: boundaryOffsetsOffset + (bin + 1) * 4))
            guard lower <= upper, upper <= boundaryTriangleCount, coverage == 2 || lower == upper else {
                throw IconNativeGridError.invalidBoundaryIndex(bin: bin)
            }
            if coverage == 2, lower == upper {
                throw IconNativeGridError.invalidBoundaryIndex(bin: bin)
            }
        }
        if hasCoverage,
           Self.readUInt32(bytes, at: boundaryOffsetsOffset + binCount * 4) != boundaryTriangleCount {
            throw IconNativeGridError.invalidBoundaryIndex(bin: binCount)
        }
        if hasCoverage {
            for triangleIndex in 0..<boundaryTriangleCount {
                let triangle = boundaryTriangle(at: triangleIndex, bytes: bytes)
                for point in [triangle.a, triangle.b, triangle.c] {
                    guard point.x.isFinite,
                          point.y.isFinite,
                          point.z.isFinite,
                          abs(point.dot(point) - 1) < 1e-5 else {
                        throw IconNativeGridError.invalidBoundaryIndex(bin: triangleIndex)
                    }
                }
            }
        }
    }

    @inline(__always) private func withBytes<R>(_ body: (borrowing RawSpan) throws -> R) rethrows -> R {
        try body(RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data)))
    }

    private static func multiplied(_ lhs: Int, _ rhs: Int) -> Int? {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? nil : result.partialValue
    }

    private static func validSection(offset: Int, length: Int, dataLength: Int) -> Bool {
        guard offset >= IconNativeGridArtifact.headerSize, offset.isMultiple(of: 8), length >= 0 else {
            return false
        }
        let end = offset.addingReportingOverflow(length)
        return !end.overflow && end.partialValue <= dataLength
    }

    private static func alignedEnd(offset: Int, length: Int) -> Int? {
        let end = offset.addingReportingOverflow(length)
        guard !end.overflow else {
            return nil
        }
        let withPadding = end.partialValue.addingReportingOverflow(7)
        guard !withPadding.overflow else {
            return nil
        }
        return withPadding.partialValue / 8 * 8
    }

    @inline(__always) private static func readUInt8(_ bytes: borrowing RawSpan, at offset: Int) -> UInt8 {
        bytes.unsafeLoad(fromByteOffset: offset, as: UInt8.self)
    }

    @inline(__always) private static func readUInt32(_ bytes: borrowing RawSpan, at offset: Int) -> UInt32 {
        UInt32(littleEndian: bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    @inline(__always) private static func readUInt64(_ bytes: borrowing RawSpan, at offset: Int) -> UInt64 {
        UInt64(littleEndian: bytes.unsafeLoadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }

    @inline(__always) private static func readFloat(_ bytes: borrowing RawSpan, at offset: Int) -> Float {
        Float(bitPattern: readUInt32(bytes, at: offset))
    }
}

private extension Data {
    mutating func appendInteger<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendFloat(_ value: Float) {
        appendInteger(value.bitPattern)
    }

    mutating func writeInteger<T: FixedWidthInteger>(_ value: T, at offset: Int) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            replaceSubrange(offset..<(offset + $0.count), with: $0)
        }
    }

    mutating func writeFloat(_ value: Float, at offset: Int) {
        writeInteger(value.bitPattern, at: offset)
    }

    mutating func padToEightBytes() {
        let padding = (8 - count % 8) % 8
        if padding > 0 {
            append(contentsOf: repeatElement(0, count: padding))
        }
    }
}

private func iconNativeGridChecksum(bytes: borrowing RawSpan) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for index in bytes.byteOffsets {
        // The checksum field is treated as zero by both writer and reader.
        let byte: UInt8 = (128..<136).contains(index)
            ? 0
            : bytes.unsafeLoad(fromByteOffset: index, as: UInt8.self)
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    return hash
}
