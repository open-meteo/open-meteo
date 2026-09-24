import Foundation
import ReducedLatLon
@testable import App

struct NativeGridFixture {
    let file: URL
    let index: ReducedLatLonIndex
    let centers: [ReducedLatLonPoint]
    let maximumChordDistanceSquared: Float

    func remove() { try? FileManager.default.removeItem(at: file) }
}

extension ReducedLatLonPoint {
    init(latitudeDegrees: Double, longitudeDegrees: Double) {
        self.init(latitudeRadians: latitudeDegrees * .pi / 180, longitudeRadians: longitudeDegrees * .pi / 180)
    }
}

func makeGlobalFixture() throws -> NativeGridFixture {
    let points = (0..<257).map { id -> ReducedLatLonPoint in
        let z = 1 - 2 * (Double(id) + 0.5) / 257
        let radius = sqrt(1 - z * z)
        let longitude = Double(id) * .pi * (3 - sqrt(5))
        return ReducedLatLonPoint(x: Float(radius * cos(longitude)), y: Float(radius * sin(longitude)), z: Float(z))
    }
    return try makeFixture(centers: points)
}

func makeFixture(centers: [ReducedLatLonPoint]) throws -> NativeGridFixture {
    let file = temporaryArtifactFile()
    do {
        try ReducedLatLonArtifact.Writer.write(to: file,
            metadata: .init(number: 26, uuid: Array(0..<16), coversWholeSphere: true),
            points: centers, latitudeBandCount: 32)
        return NativeGridFixture(file: file, index: try ReducedLatLonIndex(file: file), centers: centers,
            maximumChordDistanceSquared: IconNativeGridIdentity.squaredChordDistance(meters: 10_000_000))
    } catch {
        try? FileManager.default.removeItem(at: file)
        throw error
    }
}

func temporaryArtifactFile() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("native-grid-\(UUID()).bin")
}
