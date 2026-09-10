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
            + makeBoundaryWorkloads(grid: grid)
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

    /// Fixed query sets shared by baseline and candidate; generation is outside measured regions.
    private func makeBoundaryWorkloads(grid: IconNativeGrid) -> [(name: String, queries: [Query], repeats: Int)] {
        let index = grid.storage
        let resolution = index.resolution
        let width = 2 / Double(resolution)
        var minLat: Float = 90, maxLat: Float = -90
        var minLon: Float = 180, maxLon: Float = -180
        if !index.coversWholeSphere {
            for pointID in 0..<grid.nx {
                let coordinate = grid.getCoordinates(gridpoint: pointID)
                minLat = min(minLat, coordinate.latitude)
                maxLat = max(maxLat, coordinate.latitude)
                minLon = min(minLon, coordinate.longitude)
                maxLon = max(maxLon, coordinate.longitude)
            }
        }
        let sections = index.faceSections.enumerated().filter { $0.element.columns > 0 && $0.element.rows > 0 }
        var geographic = [Query](), buckets = [Query](), seams = [Query](), corners = [Query](), regional = [Query]()
        var state: UInt64 = 0x3c6e_f372_fe94_f82b
        func random() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        for i in 0..<65_536 {
            let a = random(), b = random()
            geographic.append(index.coversWholeSphere
                ? (Float(asin(2 * a - 1) * 180 / .pi), Float(360 * b - 180))
                : (minLat + Float(a) * (maxLat - minLat), minLon + Float(b) * (maxLon - minLon)))
            guard i < 16_384 else { continue }
            let (face, section) = sections[i % sections.count]
            let x = section.minimumX + Int(a * Double(section.columns))
            let y = section.minimumY + Int(b * Double(section.rows))
            let epsilon = [-0.0001, 0, 0.0001][(i / 24) % 3] * width
            // Every eighth bucket boundary is also a storage-tile boundary.
            buckets.append(SphericalCubeGeometry.faceVector(face: face,
                u: -1 + (Double(x) + (i.isMultiple(of: 2) ? 0 : 0.5)) * width + epsilon,
                v: -1 + (Double(y) + (i.isMultiple(of: 2) ? 0.5 : 0)) * width + epsilon).coordinate)
            let edge = (i / 6) % 4
            let boundary = (edge < 2 ? -1.0 : 1.0) + epsilon
            seams.append(SphericalCubeGeometry.faceVector(face: i % 6,
                u: edge.isMultiple(of: 2) ? boundary : 2 * a - 1,
                v: edge.isMultiple(of: 2) ? 2 * a - 1 : boundary).coordinate)
            corners.append(SphericalCubeGeometry.faceVector(face: i % 6,
                u: ((i / 6).isMultiple(of: 2) ? -1.0 : 1.0) + epsilon,
                v: ((i / 12).isMultiple(of: 2) ? -1.0 : 1.0) + epsilon).coordinate)
            if !index.coversWholeSphere {
                let offset = Float([-2.0, -0.1, 0, 0.1, 2.0][i % 5])
                switch (i / 5) % 4 {
                case 0: regional.append((minLat + offset, minLon + Float(a) * (maxLon - minLon)))
                case 1: regional.append((maxLat + offset, minLon + Float(a) * (maxLon - minLon)))
                case 2: regional.append((minLat + Float(a) * (maxLat - minLat), minLon + offset))
                default: regional.append((minLat + Float(a) * (maxLat - minLat), maxLon + offset))
                }
            }
        }
        var result = [("geographic", geographic, 8), ("bucket-boundary", buckets, 4),
                      ("seam", seams, 4), ("corner", corners, 4)]
        if !regional.isEmpty { result.append(("regional-boundary", regional, 4)) }
        return result
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
        // A fresh decoded cache each sample, with the OM reader already open; not cold disk I/O.
        printResult("first elevation-cache load", try await measureFirstElevationLoad(reader: reader), unit: "ns/load")
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
            // Compare complete selections outside the timed loops; checksums keep timed results observable.
            for query in scenario.queries {
                let raw = try await grid.findPoint(lat: query.latitude, lon: query.longitude, elevation: -10_000,
                    elevationFile: reader, mode: scenario.mode)
                let warm = try await cachedGrid.findPoint(lat: query.latitude, lon: query.longitude, elevation: -10_000,
                    elevationFile: reader, mode: scenario.mode)
                #expect(raw?.gridpoint == warm?.gridpoint)
                #expect(raw?.gridElevation.numeric == warm?.gridElevation.numeric)
            }
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

    private func measureFirstElevationLoad(
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

    private func printResult(
        _ name: String,
        _ measurement: (samples: [Double], checksum: Int),
        unit: String = "ns/query"
    ) {
        print("  \(name) median: \(measurement.samples[sampleCount / 2]) \(unit)")
        print("  \(name) range: \(measurement.samples[0])...\(measurement.samples[sampleCount - 1]) \(unit)")
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
