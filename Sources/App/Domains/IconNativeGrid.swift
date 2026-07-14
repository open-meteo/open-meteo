import Foundation
import OmFileFormat

typealias LatLon = (latitude: Float, longitude: Float)

/// An exact native ICON triangular grid backed by a memory-mappable mesh artifact.
///
/// Coordinate lookup maps to one regular latitude/longitude bin and tests only the native
/// triangles conservatively assigned to that bin. The artifact generator bounds every bin to
/// `maximumCandidateCount`, so lookup cost is independent of the total number of cells.
struct IconNativeGrid: Gridable {
    typealias SliceType = Range<Int>

    static let missingIndex = UInt32.max
    static let maximumCandidateCount = 128

    let storage: IconNativeGridStorage

    init(storage: IconNativeGridStorage) {
        self.storage = storage
    }

    static func load(file: URL) throws -> Self {
        Self(storage: try IconNativeGridStorage(file: file))
    }

    var nx: Int { storage.cellCount }
    var ny: Int { 1 }
    var searchRadius: Int { 2 }
    var gridNumber: UInt32 { storage.gridNumber }
    var gridUUID: [UInt8] { storage.gridUUID }

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

    /// Exposed internally for correctness and fixed-work lookup tests.
    func findPointWithCandidateCount(lat: Float, lon: Float) -> (gridpoint: Int, candidateCount: Int)? {
        guard let query = lookupInput(lat: lat, lon: lon) else {
            return nil
        }
        let result = storage.containingCell(point: query.point, bin: query.bin)
        precondition(!storage.isGlobal || result.cell != nil, "Global ICON mesh does not contain a valid coordinate")
        guard let cell = result.cell else {
            return nil
        }
        return (cell, result.candidateCount)
    }

    func findPointInterpolated(lat: Float, lon: Float) -> GridPoint2DFraction? { nil }

    func findBox(boundingBox bb: BoundingBoxWGS84) -> Range<Int>? { nil }

    func estimatedNumberOfGridCells(boundingBox bb: BoundingBoxWGS84) -> Int? { nil }

    func getCoordinates(gridpoint: Int) -> LatLon {
        precondition(gridpoint >= 0 && gridpoint < storage.cellCount, "ICON grid point out of range")
        return storage.center(at: gridpoint)
    }

    func findPointInSea(
        lat: Float,
        lon: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let query = lookupInput(lat: lat, lon: lon),
              let containing = storage.containingCell(point: query.point, bin: query.bin).cell else {
            return nil
        }
        let candidates = surroundingGridpoints(seed: containing)
        let containingElevation = try await readFromStaticFile(gridpoint: containing, file: elevationFile)
        if containingElevation <= -999 {
            return (containing, .sea)
        }
        let elevations = try await readElevations(
            candidates: candidates,
            knownPosition: 0,
            knownValue: containingElevation,
            elevationFile: elevationFile
        )

        var bestPosition = -1
        var bestDot = -Float.greatestFiniteMagnitude
        for position in 0..<candidates.count where elevations[position] <= -999 {
            let dot = storage.centerPoint(at: candidates.points[position]).dot(query.point)
            if dot > bestDot || (dot == bestDot && (bestPosition < 0 || candidates.points[position] < candidates.points[bestPosition])) {
                bestDot = dot
                bestPosition = position
            }
        }
        guard bestPosition >= 0 else {
            return elevationResult(gridpoint: containing, value: containingElevation)
        }
        return (candidates.points[bestPosition], .sea)
    }

    func findPointTerrainOptimised(
        lat: Float,
        lon: Float,
        elevation: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (gridpoint: Int, gridElevation: ElevationOrSea)? {
        guard let query = lookupInput(lat: lat, lon: lon),
              let containing = storage.containingCell(point: query.point, bin: query.bin).cell else {
            return nil
        }
        let candidates = surroundingGridpoints(seed: containing)
        let containingElevation = try await readFromStaticFile(gridpoint: containing, file: elevationFile)
        if containingElevation.isFinite, containingElevation > -999, abs(containingElevation - elevation) <= 100 {
            return elevationResult(gridpoint: containing, value: containingElevation)
        }
        let elevations = try await readElevations(
            candidates: candidates,
            knownPosition: 0,
            knownValue: containingElevation,
            elevationFile: elevationFile
        )

        var bestPosition = -1
        var bestScore = Float.greatestFiniteMagnitude
        for position in 0..<candidates.count {
            let candidateElevation = elevations[position]
            if !candidateElevation.isFinite || candidateElevation <= -999 {
                continue
            }
            let dot = max(-1, min(1, storage.centerPoint(at: candidates.points[position]).dot(query.point)))
            let distanceKilometres = acos(dot) * 6371.229
            if distanceKilometres >= 50 {
                continue
            }
            let elevationDelta = candidateElevation >= 9999 ? 0 : abs(candidateElevation - elevation)
            let score = elevationDelta + distanceKilometres * 30
            if score < bestScore || (score == bestScore && (bestPosition < 0 || candidates.points[position] < candidates.points[bestPosition])) {
                bestScore = score
                bestPosition = position
            }
        }

        if bestPosition < 0 || bestScore > 1500 {
            return elevationResult(gridpoint: containing, value: containingElevation)
        }
        return elevationResult(gridpoint: candidates.points[bestPosition], value: elevations[bestPosition])
    }

    private func lookupInput(lat: Float, lon: Float) -> (point: SphericalPoint, bin: Int)? {
        guard lat.isFinite, lon.isFinite, lat >= -90, lat <= 90 else {
            return nil
        }
        let longitude = storage.isGlobal ? normalisedLongitude(lon) : lon
        guard let bin = storage.bin(latitude: lat, longitude: longitude) else {
            return nil
        }
        return (SphericalPoint(latitude: lat, longitude: longitude), bin)
    }

    private func surroundingGridpoints(seed: Int) -> (points: InlineArray<16, Int>, count: Int) {
        var points = InlineArray<16, Int>(repeating: -1)
        var count = 0

        @inline(__always) func append(_ point: Int, points: inout InlineArray<16, Int>, count: inout Int) {
            guard point >= 0 else { return }
            for position in 0..<count where points[position] == point { return }
            precondition(count < 16, "ICON topology exceeds the two-ring candidate bound")
            points[count] = point
            count += 1
        }

        append(seed, points: &points, count: &count)
        for position in 0..<3 {
            let neighbour = storage.neighbour(cell: seed, position: position)
            if neighbour != Self.missingIndex {
                append(Int(neighbour), points: &points, count: &count)
            }
        }
        let firstRingEnd = count
        if firstRingEnd > 1 {
            for index in 1..<firstRingEnd {
                for position in 0..<3 {
                    let neighbour = storage.neighbour(cell: points[index], position: position)
                    if neighbour != Self.missingIndex {
                        append(Int(neighbour), points: &points, count: &count)
                    }
                }
            }
        }
        return (points, count)
    }

    private func readElevations(
        candidates: (points: InlineArray<16, Int>, count: Int),
        knownPosition: Int,
        knownValue: Float,
        elevationFile: any OmFileReaderArrayProtocol<Float>
    ) async throws -> [Float] {
        let sorted = (0..<candidates.count).filter { $0 != knownPosition }.map {
            (gridpoint: candidates.points[$0], originalPosition: $0)
        }.sorted { $0.gridpoint < $1.gridpoint }
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
        if value.isNaN { return nil }
        if value <= -999 { return (gridpoint, .sea) }
        if value >= 9999 { return (gridpoint, .landWithoutElevation) }
        return (gridpoint, .elevation(value))
    }

    private func normalisedLongitude(_ longitude: Float) -> Float {
        var value = longitude.truncatingRemainder(dividingBy: 360)
        if value < -180 { value += 360 }
        if value >= 180 { value -= 360 }
        return value
    }
}

enum IconNativeGridError: Error, Equatable, CustomStringConvertible {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case invalidHeader
    case invalidChecksum
    case invalidTriangle(Int)
    case invalidBinOffset(Int)
    case candidateLimit(bin: Int, count: Int)
    case artifactTooLarge(actual: Int, maximum: Int)

    var description: String {
        switch self {
        case .invalidMagic: "Invalid ICON native grid magic"
        case .unsupportedVersion(let version): "Unsupported ICON native grid version \(version)"
        case .invalidHeader: "Invalid ICON native grid header or section layout"
        case .invalidChecksum: "ICON native grid checksum mismatch"
        case .invalidTriangle(let cell): "Invalid ICON triangle at cell \(cell)"
        case .invalidBinOffset(let bin): "Invalid ICON spatial-bin offset at bin \(bin)"
        case .candidateLimit(let bin, let count): "ICON spatial bin \(bin) requires \(count) candidates"
        case .artifactTooLarge(let actual, let maximum): "ICON grid artifact requires \(actual) bytes; limit is \(maximum) bytes"
        }
    }
}

struct SphericalPoint: Sendable, Equatable {
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

    var latitude: Float { asin(max(-1, min(1, z))) * 180 / .pi }
    var longitude: Float { atan2(y, x) * 180 / .pi }

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

struct SphericalTriangle: Sendable, Equatable {
    let a: SphericalPoint
    let b: SphericalPoint
    let c: SphericalPoint

    func contains(_ point: SphericalPoint) -> Bool {
        let tolerance: Float = 1e-6
        return isInsideEdge(a: a, b: b, opposite: c, point: point, tolerance: tolerance)
            && isInsideEdge(a: b, b: c, opposite: a, point: point, tolerance: tolerance)
            && isInsideEdge(a: c, b: a, opposite: b, point: point, tolerance: tolerance)
    }

    var isValid: Bool {
        edgeIsValid(a, b) && edgeIsValid(b, c) && edgeIsValid(c, a)
    }

    private func edgeIsValid(_ lhs: SphericalPoint, _ rhs: SphericalPoint) -> Bool {
        lhs.cross(rhs).dot(lhs.cross(rhs)) > 1e-12
    }

    private func isInsideEdge(
        a: SphericalPoint,
        b: SphericalPoint,
        opposite: SphericalPoint,
        point: SphericalPoint,
        tolerance: Float
    ) -> Bool {
        let normal = a.cross(b)
        let length = sqrt(normal.dot(normal))
        guard length > 1e-8 else { return false }
        let orientation: Float = normal.dot(opposite) >= 0 ? 1 : -1
        return normal.dot(point) / length * orientation >= -tolerance
    }
}

enum IconNativeGridArtifact {
    static let magic = Array("ICONMSH1".utf8)
    static let version: UInt32 = 4
    static let headerSize = 160
    static let globalFlag: UInt32 = 1

    struct Metadata: Sendable {
        let gridNumber: UInt32
        let gridUUID: [UInt8]
        let isGlobal: Bool
        let bounds: GridBounds
        let binNx: Int
        let binNy: Int
        let binLatMin: Float
        let binLonMin: Float
        let binDx: Float
        let binDy: Float
    }

    static func write(
        to file: String,
        metadata: Metadata,
        centers: [LatLon],
        vertices: [SphericalPoint],
        vertexIndices: [UInt32],
        neighbourIndices: [UInt32],
        binOffsets: [UInt32],
        binCells: [UInt32],
        maximumFileSize: Int = .max
    ) throws {
        let binCount = metadata.binNx.multipliedReportingOverflow(by: metadata.binNy)
        guard !binCount.overflow,
              metadata.gridUUID.count == 16,
              !centers.isEmpty,
              !vertices.isEmpty,
              centers.count <= Int(UInt32.max),
              vertices.count <= Int(UInt32.max),
              vertexIndices.count == centers.count * 3,
              neighbourIndices.count == centers.count * 3,
              binOffsets.count == binCount.partialValue + 1,
              metadata.binNx > 0,
              metadata.binNy > 0,
              metadata.binDx.isFinite,
              metadata.binDy.isFinite,
              metadata.binDx > 0,
              metadata.binDy > 0 else {
            throw IconNativeGridError.invalidHeader
        }

        guard let verticesOffset = alignedEnd(offset: headerSize, length: centers.count * 8),
              let vertexIndicesOffset = alignedEnd(offset: verticesOffset, length: vertices.count * 12),
              let neighboursOffset = alignedEnd(offset: vertexIndicesOffset, length: vertexIndices.count * 4),
              let binOffsetsOffset = alignedEnd(offset: neighboursOffset, length: neighbourIndices.count * 4),
              let binCellsOffset = alignedEnd(offset: binOffsetsOffset, length: binOffsets.count * 4),
              let fileSize = alignedEnd(offset: binCellsOffset, length: binCells.count * 4) else {
            throw IconNativeGridError.invalidHeader
        }
        guard fileSize <= maximumFileSize else {
            throw IconNativeGridError.artifactTooLarge(actual: fileSize, maximum: maximumFileSize)
        }

        var header = Data(repeating: 0, count: headerSize)
        header.replaceSubrange(0..<magic.count, with: magic)
        header.writeInteger(version, at: 8)
        header.writeInteger(UInt32(headerSize), at: 12)
        header.writeInteger(metadata.isGlobal ? globalFlag : 0, at: 16)
        header.writeInteger(metadata.gridNumber, at: 20)
        header.writeInteger(UInt32(centers.count), at: 24)
        header.writeInteger(UInt32(vertices.count), at: 28)
        header.writeInteger(UInt32(metadata.binNx), at: 32)
        header.writeInteger(UInt32(metadata.binNy), at: 36)
        header.writeFloat(metadata.binLatMin, at: 40)
        header.writeFloat(metadata.binLonMin, at: 44)
        header.writeFloat(metadata.binDx, at: 48)
        header.writeFloat(metadata.binDy, at: 52)
        header.writeFloat(metadata.bounds.lat_bounds.lowerBound, at: 56)
        header.writeFloat(metadata.bounds.lat_bounds.upperBound, at: 60)
        header.writeFloat(metadata.bounds.lon_bounds.lowerBound, at: 64)
        header.writeFloat(metadata.bounds.lon_bounds.upperBound, at: 68)
        header.writeInteger(UInt32(IconNativeGrid.maximumCandidateCount), at: 72)
        header.writeInteger(UInt64(headerSize), at: 80)
        header.writeInteger(UInt64(verticesOffset), at: 88)
        header.writeInteger(UInt64(vertexIndicesOffset), at: 96)
        header.writeInteger(UInt64(neighboursOffset), at: 104)
        header.writeInteger(UInt64(binOffsetsOffset), at: 112)
        header.writeInteger(UInt64(binCellsOffset), at: 120)
        header.replaceSubrange(136..<152, with: metadata.gridUUID)
        header.writeInteger(UInt64(fileSize), at: 152)

        let handle = try FileHandle.createNewFile(file: file, size: fileSize, overwrite: true)
        var writer = IconNativeGridArtifactWriter(handle: handle)
        do {
            try writer.write(header)
            for center in centers {
                try writer.writeFloat(center.latitude)
                try writer.writeFloat(center.longitude)
            }
            try writer.pad(to: verticesOffset)
            for vertex in vertices {
                try writer.writeFloat(vertex.x)
                try writer.writeFloat(vertex.y)
                try writer.writeFloat(vertex.z)
            }
            try writer.pad(to: vertexIndicesOffset)
            for value in vertexIndices { try writer.writeInteger(value) }
            try writer.pad(to: neighboursOffset)
            for value in neighbourIndices { try writer.writeInteger(value) }
            try writer.pad(to: binOffsetsOffset)
            for value in binOffsets { try writer.writeInteger(value) }
            try writer.pad(to: binCellsOffset)
            for value in binCells { try writer.writeInteger(value) }
            try writer.pad(to: fileSize)
            let checksum = try writer.finish()
            try handle.seek(toOffset: 128)
            var littleEndianChecksum = checksum.littleEndian
            try Swift.withUnsafeBytes(of: &littleEndianChecksum) { bytes in
                try handle.write(contentsOf: bytes)
            }
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }

    private static func alignedEnd(offset: Int, length: Int) -> Int? {
        let end = offset.addingReportingOverflow(length)
        guard !end.overflow else { return nil }
        let padded = end.partialValue.addingReportingOverflow(7)
        guard !padded.overflow else { return nil }
        return padded.partialValue / 8 * 8
    }
}

final class IconNativeGridStorage: Sendable {
    private let mapped: MmapFile

    let isGlobal: Bool
    let gridNumber: UInt32
    let gridUUID: [UInt8]
    let cellCount: Int
    let binNx: Int
    let binNy: Int
    let binLatMin: Float
    let binLonMin: Float
    let binDx: Float
    let binDy: Float
    let bounds: GridBounds

    private let centersOffset: Int
    private let verticesOffset: Int
    private let vertexIndicesOffset: Int
    private let neighboursOffset: Int
    private let binOffsetsOffset: Int
    private let binCellsOffset: Int

    init(file: URL) throws {
        let fileHandle = try FileHandle.openFileReading(file: file.path)
        let mapped = try MmapFile(fn: fileHandle)
        guard !mapped.data.isEmpty else { throw IconNativeGridError.invalidHeader }
        self.mapped = mapped
        let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data))
        let length = mapped.data.count
        guard length >= IconNativeGridArtifact.headerSize else { throw IconNativeGridError.invalidHeader }
        for offset in IconNativeGridArtifact.magic.indices
        where Self.readUInt8(bytes, at: offset) != IconNativeGridArtifact.magic[offset] {
            throw IconNativeGridError.invalidMagic
        }
        let version = Self.readUInt32(bytes, at: 8)
        guard version == IconNativeGridArtifact.version else {
            throw IconNativeGridError.unsupportedVersion(version)
        }
        guard Self.readUInt32(bytes, at: 12) == IconNativeGridArtifact.headerSize,
              Self.readUInt64(bytes, at: 152) == UInt64(length) else {
            throw IconNativeGridError.invalidHeader
        }
        guard iconNativeGridChecksum(bytes: bytes) == Self.readUInt64(bytes, at: 128) else {
            throw IconNativeGridError.invalidChecksum
        }

        let flags = Self.readUInt32(bytes, at: 16)
        guard flags & ~IconNativeGridArtifact.globalFlag == 0 else { throw IconNativeGridError.invalidHeader }
        isGlobal = flags & IconNativeGridArtifact.globalFlag != 0
        gridNumber = Self.readUInt32(bytes, at: 20)
        cellCount = Int(Self.readUInt32(bytes, at: 24))
        let vertexCount = Int(Self.readUInt32(bytes, at: 28))
        binNx = Int(Self.readUInt32(bytes, at: 32))
        binNy = Int(Self.readUInt32(bytes, at: 36))
        binLatMin = Self.readFloat(bytes, at: 40)
        binLonMin = Self.readFloat(bytes, at: 44)
        binDx = Self.readFloat(bytes, at: 48)
        binDy = Self.readFloat(bytes, at: 52)
        let latLower = Self.readFloat(bytes, at: 56)
        let latUpper = Self.readFloat(bytes, at: 60)
        let lonLower = Self.readFloat(bytes, at: 64)
        let lonUpper = Self.readFloat(bytes, at: 68)
        guard latLower.isFinite, latUpper.isFinite, lonLower.isFinite, lonUpper.isFinite,
              latLower <= latUpper, lonLower <= lonUpper else {
            throw IconNativeGridError.invalidHeader
        }
        bounds = GridBounds(lat_bounds: latLower...latUpper, lon_bounds: lonLower...lonUpper)

        guard let centersOffset = Int(exactly: Self.readUInt64(bytes, at: 80)),
              let verticesOffset = Int(exactly: Self.readUInt64(bytes, at: 88)),
              let vertexIndicesOffset = Int(exactly: Self.readUInt64(bytes, at: 96)),
              let neighboursOffset = Int(exactly: Self.readUInt64(bytes, at: 104)),
              let binOffsetsOffset = Int(exactly: Self.readUInt64(bytes, at: 112)),
              let binCellsOffset = Int(exactly: Self.readUInt64(bytes, at: 120)) else {
            throw IconNativeGridError.invalidHeader
        }
        self.centersOffset = centersOffset
        self.verticesOffset = verticesOffset
        self.vertexIndicesOffset = vertexIndicesOffset
        self.neighboursOffset = neighboursOffset
        self.binOffsetsOffset = binOffsetsOffset
        self.binCellsOffset = binCellsOffset

        var uuid = [UInt8](); uuid.reserveCapacity(16)
        for offset in 136..<152 { uuid.append(Self.readUInt8(bytes, at: offset)) }
        gridUUID = uuid

        guard cellCount > 0,
              vertexCount > 0,
              binNx > 0,
              binNy > 0,
              binLatMin.isFinite,
              binLonMin.isFinite,
              binDx.isFinite,
              binDy.isFinite,
              binDx > 0,
              binDy > 0,
              bounds.lat_bounds.lowerBound >= -90,
              bounds.lat_bounds.upperBound <= 90,
              Self.readUInt32(bytes, at: 72) == IconNativeGrid.maximumCandidateCount,
              let centerBytes = Self.multiplied(cellCount, 8),
              let vertexBytes = Self.multiplied(vertexCount, 12),
              let topologyBytes = Self.multiplied(cellCount, 12),
              let binCount = Self.multiplied(binNx, binNy),
              let binOffsetBytes = Self.multiplied(binCount + 1, 4),
              centersOffset == IconNativeGridArtifact.headerSize,
              verticesOffset == Self.alignedEnd(offset: centersOffset, length: centerBytes),
              vertexIndicesOffset == Self.alignedEnd(offset: verticesOffset, length: vertexBytes),
              neighboursOffset == Self.alignedEnd(offset: vertexIndicesOffset, length: topologyBytes),
              binOffsetsOffset == Self.alignedEnd(offset: neighboursOffset, length: topologyBytes),
              binCellsOffset == Self.alignedEnd(offset: binOffsetsOffset, length: binOffsetBytes),
              Self.validSection(offset: binOffsetsOffset, length: binOffsetBytes, dataLength: length) else {
            throw IconNativeGridError.invalidHeader
        }

        let finalBinOffset = Int(Self.readUInt32(bytes, at: binOffsetsOffset + binCount * 4))
        guard let binCellBytes = Self.multiplied(finalBinOffset, 4),
              Self.validSection(offset: centersOffset, length: centerBytes, dataLength: length),
              Self.validSection(offset: verticesOffset, length: vertexBytes, dataLength: length),
              Self.validSection(offset: vertexIndicesOffset, length: topologyBytes, dataLength: length),
              Self.validSection(offset: neighboursOffset, length: topologyBytes, dataLength: length),
              Self.validSection(offset: binCellsOffset, length: binCellBytes, dataLength: length),
              Self.alignedEnd(offset: binCellsOffset, length: binCellBytes) == length else {
            throw IconNativeGridError.invalidHeader
        }
        if isGlobal {
            guard abs(binLatMin + 90) < 1e-4,
                  abs(Float(binNy) * binDy - 180) < 1e-3,
                  abs(Float(binNx) * binDx - 360) < 1e-3 else {
                throw IconNativeGridError.invalidHeader
            }
        }
    }

    @inline(__always) func center(at cell: Int) -> LatLon {
        withBytes { bytes in
            let offset = centersOffset + cell * 8
            return (Self.readFloat(bytes, at: offset), Self.readFloat(bytes, at: offset + 4))
        }
    }

    @inline(__always) func centerPoint(at cell: Int) -> SphericalPoint {
        let coordinate = center(at: cell)
        return SphericalPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    @inline(__always) func neighbour(cell: Int, position: Int) -> UInt32 {
        withBytes { Self.readUInt32($0, at: neighboursOffset + (cell * 3 + position) * 4) }
    }

    func bin(latitude: Float, longitude: Float) -> Int? {
        if !isGlobal {
            guard bounds.lat_bounds.contains(latitude), bounds.lon_bounds.contains(longitude) else { return nil }
        }
        let xValue = floor((longitude - binLonMin) / binDx)
        let yValue = floor((latitude - binLatMin) / binDy)
        guard xValue.isFinite, yValue.isFinite else { return nil }
        var x = Int(xValue)
        var y = Int(yValue)
        if isGlobal {
            x %= binNx
            if x < 0 { x += binNx }
            y = max(0, min(binNy - 1, y))
        } else {
            if x == binNx, abs(longitude - (binLonMin + Float(binNx) * binDx)) < 1e-5 { x -= 1 }
            if y == binNy, abs(latitude - (binLatMin + Float(binNy) * binDy)) < 1e-5 { y -= 1 }
            guard x >= 0, x < binNx, y >= 0, y < binNy else { return nil }
        }
        return y * binNx + x
    }

    func containingCell(point: SphericalPoint, bin: Int) -> (cell: Int?, candidateCount: Int) {
        withBytes { bytes in
            let lower = Int(Self.readUInt32(bytes, at: binOffsetsOffset + bin * 4))
            let upper = Int(Self.readUInt32(bytes, at: binOffsetsOffset + (bin + 1) * 4))
            var best: Int?
            for index in lower..<upper {
                let cell = Int(Self.readUInt32(bytes, at: binCellsOffset + index * 4))
                if triangle(cell: cell, bytes: bytes).contains(point), best == nil || cell < best! {
                    best = cell
                }
            }
            return (best, upper - lower)
        }
    }

    private func triangle(cell: Int, bytes: borrowing RawSpan) -> SphericalTriangle {
        let offset = vertexIndicesOffset + cell * 12
        return SphericalTriangle(
            a: vertex(at: Int(Self.readUInt32(bytes, at: offset)), bytes: bytes),
            b: vertex(at: Int(Self.readUInt32(bytes, at: offset + 4)), bytes: bytes),
            c: vertex(at: Int(Self.readUInt32(bytes, at: offset + 8)), bytes: bytes)
        )
    }

    private func vertex(at index: Int, bytes: borrowing RawSpan) -> SphericalPoint {
        let offset = verticesOffset + index * 12
        return SphericalPoint(
            x: Self.readFloat(bytes, at: offset),
            y: Self.readFloat(bytes, at: offset + 4),
            z: Self.readFloat(bytes, at: offset + 8)
        )
    }

    @inline(__always) private func withBytes<R>(_ body: (borrowing RawSpan) throws -> R) rethrows -> R {
        try body(RawSpan(_unsafeBytes: UnsafeRawBufferPointer(mapped.data)))
    }

    private static func multiplied(_ lhs: Int, _ rhs: Int) -> Int? {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? nil : result.partialValue
    }

    private static func validSection(offset: Int, length: Int, dataLength: Int) -> Bool {
        guard offset >= IconNativeGridArtifact.headerSize, offset.isMultiple(of: 8), length >= 0 else { return false }
        let end = offset.addingReportingOverflow(length)
        return !end.overflow && end.partialValue <= dataLength
    }

    private static func alignedEnd(offset: Int, length: Int) -> Int? {
        let end = offset.addingReportingOverflow(length)
        guard !end.overflow else { return nil }
        let padded = end.partialValue.addingReportingOverflow(7)
        guard !padded.overflow else { return nil }
        return padded.partialValue / 8 * 8
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
    mutating func writeInteger<T: FixedWidthInteger>(_ value: T, at offset: Int) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            replaceSubrange(offset..<(offset + $0.count), with: $0)
        }
    }

    mutating func writeFloat(_ value: Float, at offset: Int) { writeInteger(value.bitPattern, at: offset) }
}

/// Sequential, bounded-memory artifact writer. Hashing flushed chunks avoids rereading the staged
/// file merely to calculate its checksum; the loader still independently verifies it afterwards.
private struct IconNativeGridArtifactWriter {
    private static let bufferSize = 1 * 1_024 * 1_024

    private let handle: FileHandle
    private var buffer = Data()
    private(set) var position = 0
    private var hash: UInt64 = 0xcbf29ce484222325

    init(handle: FileHandle) {
        self.handle = handle
        buffer.reserveCapacity(Self.bufferSize)
    }

    mutating func write(_ data: Data) throws {
        try data.withUnsafeBytes { try write($0) }
    }

    mutating func writeInteger<T: FixedWidthInteger>(_ value: T) throws {
        var littleEndian = value.littleEndian
        try Swift.withUnsafeBytes(of: &littleEndian) { try write($0) }
    }

    mutating func writeFloat(_ value: Float) throws {
        try writeInteger(value.bitPattern)
    }

    mutating func pad(to offset: Int) throws {
        guard offset >= position else { throw IconNativeGridError.invalidHeader }
        if offset > position {
            try write(Data(repeating: 0, count: offset - position))
        }
    }

    mutating func finish() throws -> UInt64 {
        try flush()
        return hash
    }

    private mutating func write(_ bytes: UnsafeRawBufferPointer) throws {
        var source = bytes
        while !source.isEmpty {
            let count = min(Self.bufferSize - buffer.count, source.count)
            buffer.append(contentsOf: source.prefix(count))
            position += count
            source = UnsafeRawBufferPointer(rebasing: source[count...])
            if buffer.count == Self.bufferSize {
                try flush()
            }
        }
    }

    private mutating func flush() throws {
        guard !buffer.isEmpty else { return }
        for byte in buffer {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        try handle.write(contentsOf: buffer)
        buffer.removeAll(keepingCapacity: true)
    }
}

private func iconNativeGridChecksum(bytes: borrowing RawSpan) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    for index in bytes.byteOffsets {
        let byte: UInt8 = (128..<136).contains(index) ? 0 : bytes.unsafeLoad(fromByteOffset: index, as: UInt8.self)
        hash ^= UInt64(byte)
        hash &*= 0x100000001b3
    }
    return hash
}
