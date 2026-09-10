import Foundation
import OmFileFormat
@testable import SphericalCube

let oracleScoreTolerance = 1e-15

struct SphericalCubeFixture {
    let file: URL
    let index: SphericalCubeIndex
    let centers: [SphericalPoint]
    let maximumChordDistanceSquared: Float

    func remove() {
        try? FileManager.default.removeItem(at: file)
    }
}

let globalMetadata = SphericalCubeArtifact.Metadata(
    identity: .init(number: 26, uuid: Array(0..<16)),
    coversWholeSphere: true
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
    maximumDistanceMeters: Float = 10_000_000,
    level: Int? = nil
) throws -> SphericalCubeFixture {
    let file = temporaryArtifactFile()
    let metadata = SphericalCubeArtifact.Metadata(
        identity: isGlobal ? globalMetadata.identity : .init(number: 47, uuid: Array(repeating: 47, count: 16)),
        coversWholeSphere: isGlobal
    )
    do {
        try SphericalCubeArtifact.Writer.write(
            to: file,
            metadata: metadata,
            points: centers,
            level: level ?? (isGlobal ? 4 : 3)
        )
        return SphericalCubeFixture(
            file: file,
            index: try SphericalCubeIndex(file: file),
            centers: centers,
            maximumChordDistanceSquared: SphericalPoint.squaredChordDistance(meters: Double(maximumDistanceMeters))
        )
    } catch {
        try? FileManager.default.removeItem(at: file)
        throw error
    }
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
    return max(0, actualDistance - expectedDistance) * SphericalPoint.earthRadiusMeters
}

func centerDirectionDistance(_ lhs: SphericalPoint, _ rhs: SphericalPoint) -> Double {
    let inverseNorms = 1 / sqrt(lhs.dot(lhs) * rhs.dot(rhs))
    let dot = max(-1, min(1, lhs.dot(rhs) * inverseNorms))
    return acos(dot) * SphericalPoint.earthRadiusMeters
}

func temporaryArtifactFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("spherical-cube-\(UUID().uuidString).bin")
}
