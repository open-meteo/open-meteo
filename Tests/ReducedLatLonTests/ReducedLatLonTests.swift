import Foundation
import OmFileFormat
import Testing
@testable import ReducedLatLon

private typealias Point = ReducedLatLonPoint
private typealias Artifact = ReducedLatLonArtifact

private func centers(_ count: Int) -> [Point] {
    (0..<count).map { i in
        let z = 1 - 2 * (Double(i) + 0.5) / Double(count)
        let longitude = Double(i) * .pi * (3 - sqrt(5))
        return Point(x: Float(sqrt(1 - z * z) * cos(longitude)),
                     y: Float(sqrt(1 - z * z) * sin(longitude)), z: Float(z))
    }
}

private func fixture(_ points: [Point], bands: Int = 32, global: Bool = true) throws -> (URL, ReducedLatLonIndex) {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent("reduced-lat-lon-test-\(UUID()).bin")
    try Artifact.Writer.write(to: file, metadata: .init(number: 123, uuid: Array(0..<16), coversWholeSphere: global),
                              points: points, latitudeBandCount: bands)
    return (file, try ReducedLatLonIndex(file: file))
}

/// Deliberately independent of the index's distance, bucket and cap helpers.
private func oracle(_ points: [Point], latitude: Float, longitude: Float, limit: Float) -> [(Int, Float)] {
    var lon = longitude.truncatingRemainder(dividingBy: 360)
    if lon < -180 { lon += 360 }
    if lon >= 180 { lon -= 360 }
    let lat = latitude * (Float.pi / 180)
    lon *= Float.pi / 180
    let qx = cos(lat) * cos(lon)
    let qy = cos(lat) * sin(lon)
    let qz = sin(lat)
    return points.enumerated().compactMap { id, point -> (Int, Float)? in
        let dx = qx - point.x
        let dy = qy - point.y
        let dz = qz - point.z
        let distance = dx * dx + dy * dy + dz * dz
        return distance <= limit ? (id, distance) : nil
    }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }
}

private func verify(_ index: ReducedLatLonIndex, _ points: [Point], latitude: Float, longitude: Float,
                    nearestLimit: Float = 4, candidateLimit: Float = 4) {
    let expected = oracle(points, latitude: latitude, longitude: longitude, limit: nearestLimit)
    let lookup = index.nearestLookup(latitude: latitude, longitude: longitude, maximumChordDistanceSquared: nearestLimit)
    #expect(lookup?.pointID == expected.first?.0)
    #expect(lookup?.distanceSquared == expected.first?.1)
    guard let lookup else { return }
    let candidates = index.nearestCandidates(from: lookup, maximumChordDistanceSquared: candidateLimit)
    let ranked = Array(oracle(points, latitude: latitude, longitude: longitude, limit: candidateLimit).prefix(10))
    #expect(candidates.count == ranked.count)
    for i in 0..<min(candidates.count, ranked.count) {
        #expect(candidates.pointIDs[i] == ranked[i].0)
        #expect(candidates.distancesSquared[i] == ranked[i].1)
    }
}

@Suite struct ReducedLatLonTests {
    @Test func unpublishedHandleAndAtomicReplacementPreserveMappings() throws {
        let originalPoints = centers(17)
        let (file, originalIndex) = try fixture(originalPoints)
        defer { try? FileManager.default.removeItem(at: file) }
        let originalBytes = try Data(contentsOf: file)
        let handle = try FileHandle.createNewFile(file: file.path, overwrite: true, temporary: true)
        try Artifact.Writer.write(to: handle, metadata: originalIndex.metadata,
            points: originalPoints, latitudeBandCount: originalIndex.latitudeBandCount)
        let mapped = try ReducedLatLonIndex(mapped: MmapFile(fn: handle))
        #expect(mapped.point(at: 0) == originalPoints[0])
        #expect(try Data(contentsOf: file) == originalBytes)
        try handle.linkTemporary(file: file.path)
        #expect(try Data(contentsOf: file) == originalBytes)

        let replacementPoints = Array(originalPoints.reversed())
        try Artifact.Writer.write(to: file, metadata: originalIndex.metadata,
            points: replacementPoints, latitudeBandCount: originalIndex.latitudeBandCount)
        let replacement = try ReducedLatLonIndex(file: file)
        #expect(replacement.point(at: 0) == replacementPoints[0])
        #expect(originalIndex.point(at: 0) == originalPoints[0])
        #expect(mapped.point(at: 0) == originalPoints[0])
        let replacementBytes = try Data(contentsOf: file)
        #expect(throws: ReducedLatLonArtifactError.artifactTooLarge) {
            try Artifact.Writer.write(to: file, metadata: originalIndex.metadata, points: originalPoints,
                latitudeBandCount: originalIndex.latitudeBandCount, maximumFileSize: 64)
        }
        #expect(try Data(contentsOf: file) == replacementBytes)
    }

    @Test func rejectsUnsupportedFormatsAndInvalidWriterMetadata() throws {
        let points = centers(17)
        let (file, index) = try fixture(points)
        defer { try? FileManager.default.removeItem(at: file) }
        let original = try Data(contentsOf: file)
        for (offset, value, error) in [
            (0, UInt32(0), ReducedLatLonArtifactError.invalidMagic),
            (8, UInt32(2), .unsupportedVersion(2))
        ] {
            var bytes = original
            bytes.withUnsafeMutableBytes { buffer in
                var span = MutableRawSpan(_unsafeBytes: buffer)
                Artifact.put(&span, offset, value)
            }
            try bytes.write(to: file, options: .atomic)
            #expect(throws: error) { try ReducedLatLonIndex(file: file) }
        }
        for bands in [0, 65_537] {
            #expect(throws: ReducedLatLonArtifactError.invalidHeader) {
                try Artifact.Writer.write(to: file, metadata: index.metadata, points: points, latitudeBandCount: bands)
            }
        }
        #expect(throws: ReducedLatLonArtifactError.invalidHeader) {
            try Artifact.Writer.write(to: file, metadata: .init(number: 123, uuid: [], coversWholeSphere: true),
                points: points, latitudeBandCount: 32)
        }
    }

    @Test(arguments: [1, 2, 16, 65])
    func globalOracle(bands: Int) throws {
        let points = centers(257)
        let (file, index) = try fixture(points, bands: bands)
        defer { try? FileManager.default.removeItem(at: file) }
        for latitude in stride(from: Float(-90), through: 90, by: 7.5) {
            for longitude in stride(from: Float(-180), through: 180, by: 13.5) {
                verify(index, points, latitude: latitude, longitude: longitude)
                verify(index, points, latitude: latitude, longitude: longitude, nearestLimit: 0.02, candidateLimit: 0.04)
            }
        }
    }

    @Test(arguments: [0, 1, 2])
    func regionalHolesAndWrapping(region: Int) throws {
        let points = centers(1024).filter {
            let c = $0.coordinate
            switch region {
            case 0: return c.latitude > 20 && c.latitude < 60 && abs(c.longitude) < 40 && abs(c.longitude) > 5
            case 1: return abs(c.longitude) > 155 && abs(c.latitude) < 35
            default: return abs(c.latitude) > 70
            }
        }
        let (file, index) = try fixture(points, bands: 97, global: false)
        defer { try? FileManager.default.removeItem(at: file) }
        for latitude in stride(from: Float(-90), through: 90, by: 10) {
            for longitude in stride(from: Float(-540), through: 540, by: 45) {
                verify(index, points, latitude: latitude, longitude: longitude, nearestLimit: 0.02, candidateLimit: 0.2)
                verify(index, points, latitude: latitude, longitude: longitude)
            }
        }
    }

    @Test func bandBoundariesAndRadii() throws {
        let points = centers(513) + [Point(x: 0, y: 0, z: 1), Point(x: 0, y: 0, z: -1)]
        let (file, index) = try fixture(points, bands: 33)
        defer { try? FileManager.default.removeItem(at: file) }
        for row in 0...33 {
            let latitude = Float(-90 + Double(row) * 180 / 33)
            let n = Artifact.columns(band: min(row, 32), bandCount: 33)
            for column in stride(from: 0, through: n, by: max(1, n / 8)) {
                let longitude = Float(-180 + Double(column) * 360 / Double(n))
                for lat in [max(-90, latitude.nextDown), latitude, min(90, latitude.nextUp)] {
                    verify(index, points, latitude: lat, longitude: longitude, nearestLimit: 0.04, candidateLimit: 0.2)
                }
            }
        }
        for coordinate in [(Float(12), Float(179)), (90, 0), (-90, 180), (0, 0)] {
            let distance = oracle(points, latitude: coordinate.0, longitude: coordinate.1, limit: 4)[0].1
            for limit in [max(Float.leastNonzeroMagnitude, distance.nextDown), max(Float.leastNonzeroMagnitude, distance), distance.nextUp, 2, 4] {
                verify(index, points, latitude: coordinate.0, longitude: coordinate.1, nearestLimit: limit, candidateLimit: max(limit, 0.2))
            }
        }
    }

    @Test func duplicatesAndSparseCandidates() throws {
        let points = [Point](repeating: .init(x: 1, y: 0, z: 0), count: 17)
            + [Point(latitudeRadians: 0, longitudeRadians: 0.2), Point(latitudeRadians: 0, longitudeRadians: -0.2)]
        let (file, index) = try fixture(points, bands: 512, global: false)
        defer { try? FileManager.default.removeItem(at: file) }
        verify(index, points, latitude: 0, longitude: 0)
        verify(index, points, latitude: 0, longitude: 45)
        verify(index, points, latitude: 0, longitude: 12, nearestLimit: 0.01, candidateLimit: 0.01)
        let original = try #require(index.nearestLookup(latitude: 0, longitude: 0, maximumChordDistanceSquared: 4))
        let supplied = ReducedLatLonIndex.Lookup(query: original.query, latitude: original.latitude,
            longitude: original.longitude, cosineLatitude: original.cosineLatitude, seedBoundary: original.seedBoundary,
            bucket: original.bucket, position: original.position + 12, pointID: 12, distanceSquared: 0)
        let candidates = index.nearestCandidates(from: supplied, maximumChordDistanceSquared: 4)
        #expect(candidates.pointIDs[0] == 12)
        for i in 1..<10 { #expect(candidates.pointIDs[i] == i - 1) }
        for lat in [Float.nan, .infinity, -91, 91] {
            #expect(index.nearestPointID(latitude: lat, longitude: 0, maximumChordDistanceSquared: 4) == nil)
        }
        #expect(index.nearestPointID(latitude: 0, longitude: .nan, maximumChordDistanceSquared: 4) == nil)
        #expect(index.nearestPointID(latitude: 0, longitude: .infinity, maximumChordDistanceSquared: 4) == nil)
    }

    @Test func artifactRoundTripAndValidation() throws {
        let points = centers(101)
        let (file, index) = try fixture(points, bands: 29, global: false)
        defer { try? FileManager.default.removeItem(at: file) }
        let original = try Data(contentsOf: file)
        #expect(index.metadata == .init(number: 123, uuid: Array(0..<16), coversWholeSphere: false))
        for id in points.indices { #expect(index.point(at: id) == points[id]) }
        try Artifact.Writer.write(to: file, metadata: index.metadata, points: points, latitudeBandCount: 29)
        #expect(try Data(contentsOf: file) == original)
        original.withUnsafeBytes { buffer in
            let bytes = RawSpan(_unsafeBytes: buffer)
            for id in points.indices {
                let angles = points[id].radians
                let bucket = index.bucket(latitude: angles.latitude, longitude: angles.longitude)!
                let position = Int(Artifact.uint(bytes, index.reverseOffset + id * 4))
                #expect(index.pointRange(bucket..<bucket + 1, bytes: bytes).contains(position))
                #expect(Artifact.uint(bytes, index.pointsOffset + position * 16 + 12) == id)
            }
        }
        // Mutations affect fresh mappings only. The existing mapping pins the original inode.
        for length in [0, 8, 63, 64, original.count - 1] {
            try Data(original.prefix(length)).write(to: file, options: .atomic)
            #expect(throws: (any Error).self) { try ReducedLatLonIndex(file: file) }
        }
        for (offset, value) in [(0, UInt32(0)), (8, 2), (16, 0), (16, .max), (20, .max), (28, .max),
                                (36, 2), (56, 1), (64, 0), (76, .max), (index.directoryOffset, 1),
                                (index.directoryOffset + 4, .max), (index.reverseOffset, UInt32(points.count))] {
            var corrupt = original
            corrupt.withUnsafeMutableBytes { buffer in
                var bytes = MutableRawSpan(_unsafeBytes: buffer)
                Artifact.put(&bytes, offset, value)
            }
            try corrupt.write(to: file, options: .atomic)
            #expect(throws: (any Error).self) { try ReducedLatLonIndex(file: file) }
        }
        for invalid in [[], [Point(x: .nan, y: 0, z: 0)], [Point(x: 0, y: 0, z: 0)], [Point(x: 2, y: 0, z: 0)]] {
            #expect(throws: (any Error).self) {
                try Artifact.Writer.write(to: file, metadata: index.metadata, points: invalid, latitudeBandCount: 29)
            }
        }
        #expect(throws: ReducedLatLonArtifactError.artifactTooLarge) {
            try Artifact.Writer.write(to: file, metadata: index.metadata, points: points, latitudeBandCount: 29, maximumFileSize: 64)
        }
    }

    @Test func spanLoadsUnalignedLittleEndianWords() {
        let data = Data([0xff, 0x78, 0x56, 0x34, 0x12])
        data.withUnsafeBytes { buffer in
            let bytes = RawSpan(_unsafeBytes: buffer)
            #expect(Artifact.uint(bytes, 1) == 0x12345678)
        }
    }

    @Test func concurrentReaders() async throws {
        let points = centers(257)
        let (file, index) = try fixture(points)
        defer { try? FileManager.default.removeItem(at: file) }
        await withTaskGroup(of: Void.self) { group in
            for worker in 0..<8 {
                group.addTask {
                    for i in 0..<64 {
                        verify(index, points, latitude: Float(i) * 2 - 64, longitude: Float(worker * 40 - 160))
                    }
                }
            }
        }
    }

    @Test func capTraversalIsCompleteAndUnique() throws {
        // Exercise accepted radial rounding as well as ordinary quantized unit vectors.
        let perturbed: [Point] = centers(1024).enumerated().map { id, p -> Point in
            let factor = id % 2 == 0 ? Float(1).nextUp : Float(1).nextDown
            return Point(x: p.x * factor, y: p.y * factor, z: p.z * factor)
        }
        let points = perturbed.filter { abs($0.coordinate.longitude) > 120 || abs($0.coordinate.latitude) > 50 }
        let (file, index) = try fixture(points, bands: 73, global: false)
        defer { try? FileManager.default.removeItem(at: file) }
        let data = try Data(contentsOf: file)
        for latitude in stride(from: Float(-90), through: 90, by: 15) {
            for longitude in stride(from: Float(-180), through: 180, by: 30) {
                let query = Point.query(latitude: latitude, longitude: longitude)
                let angles = query.radians
                for limit: Float in [0.000001, 0.02, 0.5, 2, 3, 4] {
                    var visited = Set<Int>()
                    data.withUnsafeBytes { buffer in
                        let bytes = RawSpan(_unsafeBytes: buffer)
                        index.forEachCapRange(latitude: angles.latitude, longitude: angles.longitude, limit: limit, excluding: nil) { buckets in
                            for position in index.pointRange(buckets, bytes: bytes) {
                                let id = Int(Artifact.uint(bytes, index.pointsOffset + position * 16 + 12))
                                #expect(visited.insert(id).inserted)
                            }
                        }
                    }
                    for id in points.indices where query.squaredDistance(to: points[id]) <= limit {
                        #expect(visited.contains(id))
                    }
                }
            }
        }
    }

    @Test func fullSeedDoesNotHideCloserOutsidePoint() throws {
        let points = [Point(latitudeRadians: 0, longitudeRadians: 0.01 * .pi / 180)]
            + (0..<9).map { Point(latitudeRadians: 0, longitudeRadians: (0.90 + Double($0) * 0.001) * .pi / 180) }
            + [Point(latitudeRadians: 0, longitudeRadians: -0.01 * .pi / 180)]
        let (file, index) = try fixture(points, bands: 180, global: false)
        defer { try? FileManager.default.removeItem(at: file) }
        verify(index, points, latitude: 0, longitude: 0.01)
        let lookup = try #require(index.nearestLookup(latitude: 0, longitude: 0.01, maximumChordDistanceSquared: 4))
        #expect(index.nearestCandidates(from: lookup, maximumChordDistanceSquared: 4).pointIDs[1] == 10)
    }

    @Test func originalAnglesBoundRoundedQueryDirections() throws {
        // Float trigonometry can put a query on the opposite side of a bucket edge,
        // or reverse its longitude at a pole. The fast path must retain exact IDs.
        let coordinates: [(Float, Float)] = [(-90, 0), (90, 180), (-89.99999, -179.99998),
            (89.99999, 179.99998), (-10, -10), (10, 10), (0, 0), (45, 180)]
        let points = coordinates.flatMap { lat, lon in
            [Point.query(latitude: lat, longitude: Point.normalizeLongitude(lon)),
             Point.query(latitude: max(-90, lat.nextDown), longitude: Point.normalizeLongitude(lon.nextDown)),
             Point.query(latitude: min(90, lat.nextUp), longitude: Point.normalizeLongitude(lon.nextUp))]
        }
        for bands in [1, 180, 65_536] {
            let (file, index) = try fixture(points, bands: bands, global: false)
            defer { try? FileManager.default.removeItem(at: file) }
            for (lat, lon) in coordinates {
                verify(index, points, latitude: lat, longitude: lon,
                       nearestLimit: .leastNonzeroMagnitude, candidateLimit: 0.000001)
                verify(index, points, latitude: lat, longitude: lon)
            }
        }
    }

    @Test func denseQueriesMatchBruteForce() throws {
        let points = centers(20_000)
        let (file, index) = try fixture(points, bands: 32)
        defer { try? FileManager.default.removeItem(at: file) }
        for i in 0..<256 {
            let c = points[(i * 73) % points.count].coordinate
            verify(index, points, latitude: c.latitude, longitude: c.longitude,
                   nearestLimit: 0.002, candidateLimit: 0.004)
        }
    }
}
