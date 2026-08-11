import Foundation
import Testing
@testable import App

/// Opt-in because this generates an R3B7-scale artifact and performs several million lookups.
/// Run with:
/// `ICON_NATIVE_GRID_BENCHMARK=1 swift test -c release --filter IconNativeGridBenchmarkTests`
/// Set `ICON_NATIVE_GRID_ARTIFACT` to benchmark an existing global or regional artifact instead.
@Suite struct IconNativeGridBenchmarkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_BENCHMARK"] == "1"))
    func benchmark() throws {
        try IconNativeGridBenchmark.run()
    }
}

/// Retained microbenchmark for the active mmap-backed cube lookup and terrain-candidate path.
enum IconNativeGridBenchmark {
    private static let syntheticCellCount = 2_949_120
    private static let queryCount = 65_536
    private static let repeats = 8
    private static let fallbackQueryCount = 8_192
    private static let fallbackRepeats = 2
    private static let sampleCount = 9

    static func run() throws {
        let configuredArtifact = ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_ARTIFACT"]
        let file: URL
        let usesTemporaryArtifact: Bool
        if let configuredArtifact {
            file = URL(fileURLWithPath: configuredArtifact)
            usesTemporaryArtifact = false
            print("Loading ICON native cube artifact at \(file.path)...")
        } else {
            file = FileManager.default.temporaryDirectory
                .appendingPathComponent("icon-native-cube-benchmark-\(UUID().uuidString).bin")
            usesTemporaryArtifact = true
            print("Generating deterministic R3B7-scale cube artifact...")
            try SphericalCubeArtifact.Writer.write(
                to: file,
                metadata: .init(
                    identity: .init(number: 26, uuid: [UInt8](repeating: 0, count: 16)),
                    coversWholeSphere: true,
                    maximumChordDistanceSquared: maximumChordDistanceSquared(meters: 20_000)
                ),
                points: makeCenters(),
                level: 9
            )
        }
        defer {
            if usesTemporaryArtifact { try? FileManager.default.removeItem(at: file) }
        }
        let grid = try IconNativeGrid.load(file: file)
        let queries = configuredArtifact == nil ? makeQueries() : makeQueries(grid: grid)
        let fallbackQueries = makeFallbackQueries(grid: grid, queries: queries)

        let conversion = measure {
            conversionChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let lookup = measure {
            lookupChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let terrainCandidates = measure {
            terrainCandidateChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let exactFallback = measure(
            executions: fallbackQueries.count * fallbackRepeats
        ) {
            exactFallbackChecksum(
                grid: grid,
                queries: fallbackQueries,
                repeats: fallbackRepeats
            )
        }

        print("ICON native cube benchmark")
        print("  cells: \(grid.nx)")
        print("  queries/sample: \(queryCount * repeats)")
        print("  samples: \(sampleCount)")
        print("  coordinate conversion median: \(conversion.samples[sampleCount / 2]) ns/query")
        print("  coordinate conversion range: \(conversion.samples[0])...\(conversion.samples[sampleCount - 1]) ns/query")
        print("  lookup median: \(lookup.samples[sampleCount / 2]) ns/query")
        print("  lookup range: \(lookup.samples[0])...\(lookup.samples[sampleCount - 1]) ns/query")
        print("  terrain candidates median: \(terrainCandidates.samples[sampleCount / 2]) ns/query")
        print("  terrain candidates range: \(terrainCandidates.samples[0])...\(terrainCandidates.samples[sampleCount - 1]) ns/query")
        print("  seeded exact fallback median: \(exactFallback.samples[sampleCount / 2]) ns/query")
        print("  seeded exact fallback range: \(exactFallback.samples[0])...\(exactFallback.samples[sampleCount - 1]) ns/query")
        print("  artifact: \(grid.storage.artifactBytes) bytes")
        print("  lookup checksum: \(lookup.checksum)")
        print("  terrain checksum: \(terrainCandidates.checksum)")
        print("  fallback checksum: \(exactFallback.checksum)")
    }

    private static func measure(_ operation: () -> Int) -> (samples: [Double], checksum: Int) {
        measure(executions: queryCount * repeats, operation)
    }

    private static func measure(
        executions: Int,
        _ operation: () -> Int
    ) -> (samples: [Double], checksum: Int) {
        var checksum = operation()
        var samples = [Double]()
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= operation()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsed) / Double(executions))
        }
        samples.sort()
        return (samples, checksum)
    }

    private static func makeCenters() -> [SphericalPoint] {
        let goldenAngle = Double.pi * (3 - sqrt(5.0))
        var centers = [SphericalPoint]()
        centers.reserveCapacity(syntheticCellCount)
        for index in 0..<syntheticCellCount {
            let z = 1 - 2 * (Double(index) + 0.5) / Double(syntheticCellCount)
            let radius = sqrt(max(0, 1 - z * z))
            let longitude = Double(index) * goldenAngle
            centers.append(
                SphericalPoint(
                    x: radius * cos(longitude),
                    y: radius * sin(longitude),
                    z: z
                )
            )
        }
        return centers
    }

    private static func makeQueries() -> [(latitude: Float, longitude: Float)] {
        var state: UInt64 = 0x6a09_e667_f3bc_c909
        var queries = [(latitude: Float, longitude: Float)]()
        queries.reserveCapacity(queryCount)
        for _ in 0..<queryCount {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let latitudeUnit = Double(state >> 11) * 0x1p-53
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let longitudeUnit = Double(state >> 11) * 0x1p-53
            queries.append(
                (
                    latitude: Float(asin(2 * latitudeUnit - 1) * 180 / .pi),
                    longitude: Float(longitudeUnit * 360 - 180)
                )
            )
        }
        return queries
    }

    private static func makeQueries(grid: IconNativeGrid) -> [(latitude: Float, longitude: Float)] {
        var state: UInt64 = 0xbb67_ae85_84ca_a73b
        var queries = [(latitude: Float, longitude: Float)]()
        queries.reserveCapacity(queryCount)
        for _ in 0..<queryCount {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let cell = Int(state % UInt64(grid.nx))
            let coordinate = grid.getCoordinates(gridpoint: cell)
            let latitudeOffset = Float(Int((state >> 32) % 2_001) - 1_000) * 0.00001
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let longitudeOffset = Float(Int((state >> 32) % 2_001) - 1_000) * 0.00001
            queries.append(
                (
                    latitude: min(90, max(-90, coordinate.latitude + latitudeOffset)),
                    longitude: coordinate.longitude + longitudeOffset
                )
            )
        }
        return queries
    }

    private struct FallbackQuery {
        let center: SphericalPoint
        let seedPosition: Int
    }

    private static func makeFallbackQueries(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)]
    ) -> [FallbackQuery] {
        queries.prefix(fallbackQueryCount).compactMap { query in
            guard let lookup = grid.storage.nearestLookup(
                latitude: query.latitude,
                longitude: query.longitude
            ) else { return nil }
            return FallbackQuery(center: lookup.query.point, seedPosition: lookup.position)
        }
    }

    @inline(never)
    private static func conversionChecksum(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                let vector = SphericalPoint.fastLookupVector(
                    latitudeDegrees: query.latitude,
                    longitudeDegrees: SphericalPoint.normalizedLongitude(query.longitude)
                )
                let location = SphericalCubeGeometry.location(
                    for: vector.point,
                    resolution: grid.storage.resolution,
                    resolutionScale: grid.storage.resolutionScale
                )
                checksum &+= location.face &+ location.x &+ location.y
                checksum &+= Int(
                    vector.x.bitPattern
                        &+ vector.y.bitPattern
                        &+ vector.z.bitPattern
                )
            }
        }
        return checksum
    }

    @inline(never)
    private static func lookupChecksum(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                checksum &+= grid.storage.nearestPointID(
                    latitude: query.latitude,
                    longitude: query.longitude
                )!
            }
        }
        return checksum
    }

    @inline(never)
    private static func terrainCandidateChecksum(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                let candidates = grid.storage.nearestCandidates(
                    latitude: query.latitude,
                    longitude: query.longitude
                )!
                checksum &+= candidates.pointIDs[0] &+ candidates.count
            }
        }
        return checksum
    }

    @inline(never)
    private static func exactFallbackChecksum(
        grid: IconNativeGrid,
        queries: [FallbackQuery],
        repeats: Int
    ) -> Int {
        grid.storage.withBytes { bytes in
            var checksum = 0
            for _ in 0..<repeats {
                for query in queries {
                    checksum &+= grid.storage.nearest(
                        to: query.center,
                        maximumDistanceSquared: .infinity,
                        seedPosition: query.seedPosition,
                        certifiedRegion: nil,
                        bytes: bytes
                    )!
                }
            }
            return checksum
        }
    }

    private static func maximumChordDistanceSquared(meters: Double) -> Float {
        let chord = 2 * sin(meters / 6_371_229 * 0.5)
        return Float(chord * chord)
    }
}
