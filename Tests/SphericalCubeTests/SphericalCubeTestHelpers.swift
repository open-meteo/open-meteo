import Foundation
import OmFileFormat
@testable import SphericalCube
import Testing

let oracleScoreTolerance = 1e-15

struct SphericalCubeFixture {
    let file: URL
    let index: SphericalCubeIndex
    let centers: [SphericalPoint]

    func remove() {
        try? FileManager.default.removeItem(at: file)
    }
}

let globalMetadata = SphericalCubeArtifact.Metadata(
    identity: .init(number: 26, uuid: Array(0..<16)),
    coversWholeSphere: true,
    maximumChordDistanceSquared: maximumChordDistanceSquared(meters: 10_000_000)
)

func makeGlobalFixture() throws -> SphericalCubeFixture {
    try makeFixture(centers: makeSphericalCenters(count: 257))
}

func makeSphericalCenters(count: Int) -> [SphericalPoint] {
    let goldenAngle = Double.pi * (3 - sqrt(5.0))
    return (0..<count).map { cell in
        let z = 1 - 2 * (Double(cell) + 0.5) / Double(count)
        let radius = sqrt(max(0, 1 - z * z))
        let longitude = Double(cell) * goldenAngle
        return SphericalPoint(
            x: radius * cos(longitude),
            y: radius * sin(longitude),
            z: z
        )
    }
}

func makeFixture(
    centers: [SphericalPoint],
    isGlobal: Bool = true,
    maximumDistanceMeters: Float = 10_000_000
) throws -> SphericalCubeFixture {
    let file = temporaryArtifactFile()
    let metadata = isGlobal ? globalMetadata : SphericalCubeArtifact.Metadata(
        identity: .init(number: 47, uuid: Array(repeating: 47, count: 16)),
        coversWholeSphere: false,
        maximumChordDistanceSquared: maximumChordDistanceSquared(
            meters: Double(maximumDistanceMeters)
        )
    )
    do {
        try SphericalCubeArtifact.Writer.write(
            to: file,
            metadata: metadata,
            points: centers,
            level: isGlobal ? 4 : 3
        )
        return SphericalCubeFixture(
            file: file,
            index: try SphericalCubeIndex(file: file),
            centers: centers
        )
    } catch {
        try? FileManager.default.removeItem(at: file)
        throw error
    }
}

/// Expensive semantic verification belongs to artifact generation tests, not mmap startup.
func validateGeneratedArtifact(file: URL, centers: [SphericalPoint]) throws {
    typealias Artifact = SphericalCubeArtifact
    let artifact = try Artifact.open(file: file)
    let bytes = RawSpan(_unsafeBytes: UnsafeRawBufferPointer(artifact.mapped.data))
    let bucketCount = artifact.faceSections.reduce(0) { $0 + $1.columns * $1.rows }
    var previous = 0
    for bucket in 0...bucketCount {
        let current = Artifact.directoryPosition(
            bucket,
            bytes: bytes,
            basesOffset: artifact.directoryBasesOffset,
            localsOffset: artifact.directoryLocalsOffset
        )
        #expect(current >= previous)
        #expect(current <= artifact.pointCount)
        previous = current
    }
    #expect(previous == artifact.pointCount)

    var seen = [Bool](repeating: false, count: artifact.pointCount)
    for position in 0..<artifact.pointCount {
        let center = Artifact.point(
            position: position,
            bytes: bytes,
            pointsOffset: artifact.pointsOffset
        )
        #expect(center.x.isFinite && center.y.isFinite && center.z.isFinite)
        #expect(abs(center.dot(center) - 1) <= 4e-12)

        let cell = Artifact.pointID(
            position: position,
            bytes: bytes,
            pointsOffset: artifact.pointsOffset
        )
        guard cell >= 0, cell < artifact.pointCount else {
            Issue.record("Invalid canonical cell \(cell) at artifact position \(position)")
            continue
        }
        #expect(centerDirectionDistance(centers[cell], center) <= 2)
        #expect(!seen[cell])
        seen[cell] = true
        #expect(
            Artifact.readUInt32(bytes, at: artifact.positionsByIDOffset + cell * 4)
                == UInt32(position)
        )

        let location = SphericalCubeGeometry.location(
            for: center,
            resolution: artifact.resolution
        )
        guard let bucket = artifact.faceSections[location.face].bucket(
            x: location.x,
            y: location.y
        ) else {
            Issue.record("Center \(cell) falls outside its face section")
            continue
        }
        let begin = Artifact.directoryPosition(
            bucket,
            bytes: bytes,
            basesOffset: artifact.directoryBasesOffset,
            localsOffset: artifact.directoryLocalsOffset
        )
        let end = Artifact.directoryPosition(
            bucket + 1,
            bytes: bytes,
            basesOffset: artifact.directoryBasesOffset,
            localsOffset: artifact.directoryLocalsOffset
        )
        #expect(position >= begin && position < end)
    }
    #expect(seen.allSatisfy { $0 })
}

func nearest(point: SphericalPoint, centers: [SphericalPoint]) -> Int {
    var bestScore = -Double.infinity
    for center in centers { bestScore = max(bestScore, point.dot(center)) }
    return centers.indices.first {
        point.dot(centers[$0]) >= bestScore - oracleScoreTolerance
    }!
}

func distanceRegret(
    query: SphericalPoint,
    expected: SphericalPoint,
    actual: SphericalPoint
) -> Double {
    let expectedDistance = acos(max(-1, min(1, query.dot(expected))))
    let actualDistance = acos(max(-1, min(1, query.dot(actual))))
    return max(0, actualDistance - expectedDistance) * 6_371_229
}

func centerDirectionDistance(_ lhs: SphericalPoint, _ rhs: SphericalPoint) -> Double {
    let inverseNorms = 1 / sqrt(lhs.dot(lhs) * rhs.dot(rhs))
    let dot = max(-1, min(1, lhs.dot(rhs) * inverseNorms))
    return acos(dot) * 6_371_229
}

func maximumChordDistanceSquared(meters: Double) -> Float {
    let chord = 2 * sin(meters / 6_371_229 * 0.5)
    return Float(chord * chord)
}

func temporaryArtifactFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("spherical-cube-\(UUID().uuidString).bin")
}

func truncateLastByte(of file: URL) throws {
    let handle = try FileHandle(forWritingTo: file)
    defer { try? handle.close() }
    let size = try handle.seekToEnd()
    try handle.truncate(atOffset: size - 1)
}
