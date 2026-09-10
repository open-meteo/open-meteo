import Foundation
import OmFileFormat
import Testing
@testable import App
@testable import SphericalCube

/// Opt-in benchmark using an existing global or D2 grid.bin.
/// ICON_NATIVE_GRID_BENCHMARK=1 ICON_NATIVE_GRID_ARTIFACT=/path/to/grid.bin \
/// swift test -c release --jobs 16 -Xswiftc -num-threads -Xswiftc 16 --filter IconNativeGridBenchmarkTests
@Suite struct IconNativeGridBenchmarkTests {
    private let queryCount = 65_536
    private let repeats = 8
    private let elevationQueryCount = 1_024
    private let sampleCount = 9
    private typealias Query = (latitude: Float, longitude: Float)

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_BENCHMARK"] == "1"))
    func benchmark() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_ARTIFACT"],
            "Set ICON_NATIVE_GRID_ARTIFACT to an existing global or D2 grid.bin")
        let grid = try IconNativeGrid.load(file: URL(fileURLWithPath: path))
        let queries = makeQueries(grid: grid)
        let workloads = [(name: "ordinary", queries: queries, repeats: repeats)]
            + [(name: "seam/corner", queries: makeBoundaryQueries(grid: grid), repeats: 4)]
        print("ICON native grid benchmark: \(path)")
        print("  cells: \(grid.nx), queries/sample: \(queryCount * repeats), samples: \(sampleCount)")
        for workload in workloads {
            printResult("\(workload.name) nearest lookup", measure(executions: workload.queries.count * workload.repeats) {
                lookupChecksum(grid: grid, queries: workload.queries, repeats: workload.repeats)
            })
            printResult("\(workload.name) lookup with candidates", measure(executions: workload.queries.count * workload.repeats) {
                lookupWithCandidatesChecksum(grid: grid, queries: workload.queries, repeats: workload.repeats)
            })
        }
        try await measureElevationSelection(grid: grid, queries: queries)
    }

    /// Cover all cube seams and corners, with queries on and just across each boundary.
    /// Regional grids may return nil here; global grids exercise populated boundaries.
    private func makeBoundaryQueries(grid: IconNativeGrid) -> [Query] {
        let width = 2 / Double(grid.storage.resolution)
        var queries = [Query]()
        for face in 0..<6 {
            for epsilon in [-0.0001, 0, 0.0001] {
                for sign in [-1.0, 1.0] {
                    let boundary = sign + epsilon * width
                    for step in 0..<256 {
                        let along = -1 + (Double(step) + 0.5) * 2 / 256
                        queries.append(SphericalCubeGeometry.faceVector(face: face, u: boundary, v: along).coordinate)
                        queries.append(SphericalCubeGeometry.faceVector(face: face, u: along, v: boundary).coordinate)
                        for otherSign in [-1.0, 1.0] {
                            queries.append(SphericalCubeGeometry.faceVector(
                                face: face, u: boundary, v: otherSign + epsilon * width).coordinate)
                        }
                    }
                }
            }
        }
        return queries
    }

    private func measureElevationSelection(grid: IconNativeGrid, queries: [Query]) async throws {
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
        let payload = try await file.payload()
        let cachedGrid = IconNativeGrid(storage: grid.storage, elevationFile: payload.reader)
        let cache = try #require(cachedGrid.elevationCache)
        _ = try await cache.loadValues()

        let scenarios: [(name: String, queries: [Query], mode: GridSelectionMode)] = [
            ("sea hit", seaQueries, .sea),
            ("sea search from land", landQueries, .sea),
            ("forced terrain search with fallback", landQueries, .land)
        ]
        for scenario in scenarios {
            let raw = try await measureAsync(executions: elevationQueryCount) {
                try await selectionChecksum(grid: grid, reader: reader, queries: scenario.queries, mode: scenario.mode)
            }
            let warm = try await measureAsync(executions: elevationQueryCount) {
                try await selectionChecksum(grid: cachedGrid, reader: reader, queries: scenario.queries, mode: scenario.mode)
            }
            printResult("raw \(scenario.name)", raw)
            printResult("warm \(scenario.name)", warm)
        }
    }

    private func measure(
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

    private func measureAsync(
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

    private func printResult(
        _ name: String,
        _ measurement: (samples: [Double], checksum: Int)
    ) {
        print("  \(name) median: \(measurement.samples[sampleCount / 2]) ns/query")
        print("  \(name) range: \(measurement.samples[0])...\(measurement.samples[sampleCount - 1]) ns/query")
        print("  \(name) checksum: \(measurement.checksum)")
    }

    private func makeQueries(grid: IconNativeGrid) -> [(latitude: Float, longitude: Float)] {
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
    private func lookupChecksum(
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
                ) ?? -1
            }
        }
        return checksum
    }

    @inline(never)
    private func lookupWithCandidatesChecksum(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                guard let lookup = grid.storage.nearestLookup(
                    latitude: query.latitude,
                    longitude: query.longitude
                ) else {
                    checksum &+= -1
                    continue
                }
                let candidates = grid.storage.nearestCandidates(from: lookup)
                checksum &+= candidates.pointIDs[0] &+ candidates.count
            }
        }
        return checksum
    }

    @inline(never)
    private func selectionChecksum(
        grid: IconNativeGrid,
        reader: any OmFileReaderArrayProtocol<Float>,
        queries: [Query],
        mode: GridSelectionMode
    ) async throws -> Int {
        var checksum = 0
        for query in queries {
            let result = try await grid.findPoint(
                lat: query.latitude, lon: query.longitude, elevation: -10_000,
                elevationFile: reader, mode: mode
            )
            checksum &+= result?.gridpoint ?? -1
        }
        return checksum
    }
}
