import Foundation
import OmFileFormat
import Testing
@testable import App
@testable import SphericalCube

/// Opt-in benchmark using an existing global or D2 grid.bin.
/// ICON_NATIVE_GRID_BENCHMARK=1 ICON_NATIVE_GRID_ARTIFACT=/path/to/grid.bin \
/// swift test -c release --jobs 16 -Xswiftc -num-threads -Xswiftc 16 --filter IconNativeGridBenchmarkTests
@Suite struct IconNativeGridBenchmarkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_BENCHMARK"] == "1"))
    func benchmark() async throws {
        try await IconNativeGridBenchmark.run()
    }
}

enum IconNativeGridBenchmark {
    private static let queryCount = 65_536
    private static let repeats = 8
    private static let elevationQueryCount = 1_024
    private static let sampleCount = 9
    private typealias Query = (latitude: Float, longitude: Float)

    static func run() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_ARTIFACT"],
            "Set ICON_NATIVE_GRID_ARTIFACT to an existing global or D2 grid.bin")
        let grid = try IconNativeGrid.load(file: URL(fileURLWithPath: path))
        let queries = makeQueries(grid: grid)
        print("ICON native grid benchmark: \(path)")
        print("  cells: \(grid.nx), queries/sample: \(queryCount * repeats), samples: \(sampleCount)")
        printResult("nearest lookup", measure(executions: queryCount * repeats) {
            lookupChecksum(grid: grid, queries: queries, repeats: repeats)
        })
        printResult("lookup with candidates", measure(executions: queryCount * repeats) {
            lookupWithCandidatesChecksum(grid: grid, queries: queries, repeats: repeats)
        })
        try await measureElevationSelection(grid: grid, queries: queries)
    }

    private static func measureElevationSelection(grid: IconNativeGrid, queries: [Query]) async throws {
        // Preserve the original synthetic elevation workload on operational grid coordinates.
        let elevations: [Float] = (0..<grid.nx).map { pointID in
            let isSea = grid.storage.coversWholeSphere
                ? grid.storage.point(at: pointID).z >= 0 : pointID < grid.nx / 2
            return isSea ? -999 : Float(100 + (pointID * 37) % 2_000)
        }
        var seaQueries = [Query]()
        var landQueries = [Query]()
        for query in queries {
            guard let pointID = grid.storage.nearestPointID(latitude: query.latitude, longitude: query.longitude) else { continue }
            if elevations[pointID] <= -999, seaQueries.count < elevationQueryCount {
                seaQueries.append(query)
            } else if elevations[pointID] > -999, landQueries.count < elevationQueryCount {
                landQueries.append(query)
            }
            if seaQueries.count == elevationQueryCount, landQueries.count == elevationQueryCount { break }
        }
        try #require(seaQueries.count == elevationQueryCount && landQueries.count == elevationQueryCount,
            "Artifact must supply \(elevationQueryCount) queries for each synthetic sea/land workload")
        let file = try await makeElevationFile(elevations)
        defer { file.remove() }
        let reader = file.reader
        print("  elevation queries/sample: \(elevationQueryCount)")
        // A fresh decoded cache each sample, with the OM reader already open; not cold disk I/O.
        printResult("first elevation-cache load", try await measureFirstElevationLoad(reader: reader), unit: "ns/load")
        let cache = try #require(ElevationCache(reader: reader))
        _ = try await cache.loadValues()

        typealias Operation = (IconNativeGrid, any OmFileReaderArrayProtocol<Float>, [Query], ElevationCache?) async throws -> Int
        let scenarios: [(name: String, queries: [Query], mode: GridSelectionMode, operation: Operation)] = [
            ("sea hit", seaQueries, .sea, seaSelectionChecksum),
            ("sea search from land", landQueries, .sea, seaSelectionChecksum),
            ("terrain search", landQueries, .land, terrainSelectionChecksum)
        ]
        for scenario in scenarios {
            // Compare complete selections outside the timed loops; checksums keep timed results observable.
            for query in scenario.queries {
                let raw = try await grid.findPoint(lat: query.latitude, lon: query.longitude, elevation: -10_000,
                    elevationFile: reader, mode: scenario.mode, elevationCache: nil)
                let warm = try await grid.findPoint(lat: query.latitude, lon: query.longitude, elevation: -10_000,
                    elevationFile: reader, mode: scenario.mode, elevationCache: cache)
                #expect(raw?.gridpoint == warm?.gridpoint)
                #expect(raw?.gridElevation.numeric == warm?.gridElevation.numeric)
            }
            let raw = try await measureAsync(executions: elevationQueryCount) {
                try await scenario.operation(grid, reader, scenario.queries, nil)
            }
            let warm = try await measureAsync(executions: elevationQueryCount) {
                try await scenario.operation(grid, reader, scenario.queries, cache)
            }
            #expect(raw.checksum == warm.checksum)
            printResult("raw \(scenario.name)", raw)
            printResult("warm \(scenario.name)", warm)
        }
        let matchedElevations = landQueries.map { query in
            elevations[grid.storage.nearestPointID(latitude: query.latitude, longitude: query.longitude)!]
        }
        printResult("warm terrain hit", try await measureAsync(executions: elevationQueryCount) {
            var checksum = 0
            for (index, query) in landQueries.enumerated() {
                let result = try await grid.findPointTerrainOptimised(
                    lat: query.latitude, lon: query.longitude, elevation: matchedElevations[index],
                    elevationFile: reader, elevationCache: cache)
                checksum &+= result?.gridpoint ?? -1
            }
            return checksum
        })
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

    private static func measureAsync(
        executions: Int,
        _ operation: () async throws -> Int
    ) async throws -> (samples: [Double], checksum: Int) {
        var checksum = try await operation()
        var samples = [Double]()
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= try await operation()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsed) / Double(executions))
        }
        samples.sort()
        return (samples, checksum)
    }

    private static func measureFirstElevationLoad(
        reader: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (samples: [Double], checksum: Int) {
        var checksum = 0
        var samples = [Double]()
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let cache = try #require(ElevationCache(reader: reader))
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= Int(try await cache.loadValues()[0])
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start))
        }
        samples.sort()
        return (samples, checksum)
    }

    private static func printResult(
        _ name: String,
        _ measurement: (samples: [Double], checksum: Int),
        unit: String = "ns/query"
    ) {
        print("  \(name) median: \(measurement.samples[sampleCount / 2]) \(unit)")
        print("  \(name) range: \(measurement.samples[0])...\(measurement.samples[sampleCount - 1]) \(unit)")
        print("  \(name) checksum: \(measurement.checksum)")
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
    private static func lookupWithCandidatesChecksum(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                let lookup = grid.storage.nearestLookup(
                    latitude: query.latitude,
                    longitude: query.longitude
                )!
                let candidates = grid.storage.nearestCandidates(from: lookup)
                checksum &+= candidates.pointIDs[0] &+ candidates.count
            }
        }
        return checksum
    }

    @inline(never)
    private static func seaSelectionChecksum(
        grid: IconNativeGrid,
        reader: any OmFileReaderArrayProtocol<Float>,
        queries: [(latitude: Float, longitude: Float)],
        cache: ElevationCache? = nil
    ) async throws -> Int {
        var checksum = 0
        for query in queries {
            let result = try await grid.findPointInSea(
                lat: query.latitude,
                lon: query.longitude,
                elevationFile: reader,
                elevationCache: cache
            )
            checksum &+= result?.gridpoint ?? -1
        }
        return checksum
    }

    @inline(never)
    private static func terrainSelectionChecksum(
        grid: IconNativeGrid,
        reader: any OmFileReaderArrayProtocol<Float>,
        queries: [(latitude: Float, longitude: Float)],
        cache: ElevationCache? = nil
    ) async throws -> Int {
        var checksum = 0
        for query in queries {
            let result = try await grid.findPointTerrainOptimised(
                lat: query.latitude,
                lon: query.longitude,
                elevation: -10_000,
                elevationFile: reader,
                elevationCache: cache
            )
            checksum &+= result?.gridpoint ?? -1
        }
        return checksum
    }
}
