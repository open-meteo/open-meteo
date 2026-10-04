import Foundation
import OmFileFormat
import ReducedLatLon
import Testing
@testable import App

/// Opt-in measurements of the production native ICON adapter on operational coordinates.
/// Run separately for each global or D2 artifact:
///
/// ```sh
/// ICON_NATIVE_GRID_BENCHMARK=1 ICON_NATIVE_GRID_ARTIFACT=/path/to/grid.bin \
/// swift test -c release --filter IconNativeGridBenchmarkTests
/// ```
///
/// Each operation warms up and records nine batch-average samples. Elevations are
/// synthetic; terrain queries exercise candidate search and fallback, not a real terrain distribution.
@Suite struct IconNativeGridBenchmarkTests {
    /// Geographic latitude/longitude in degrees.
    private struct Query {
        let latitude: Float
        let longitude: Float
    }

    /// Query lists for nearest lookup, sea hits, and land/terrain searches, respectively.
    private struct Corpus {
        let ordinary: [Query]
        let sea: [Query]
        let land: [Query]
    }

    /// Batch-average nanoseconds/query and the checksum verified across timing samples.
    private struct Measurement {
        let operation: String
        let samplesNS: [Double]
        let checksum: Int
    }

    private let sampleCount = 9
    private let repeats = 8

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_BENCHMARK"] == "1"))
    func benchmark() async throws {
        let env = ProcessInfo.processInfo.environment
        let path = try #require(env["ICON_NATIVE_GRID_ARTIFACT"], "Set ICON_NATIVE_GRID_ARTIFACT to a global or D2 grid.bin")
        let storage = try ReducedLatLonIndex(file: URL(fileURLWithPath: path))
        let identity = try #require([IconNativeGridIdentity.global, .d2].first { $0.gridNumber == storage.metadata.number })
        try identity.validate(storage: storage, path: path)
        let grid = IconNativeGrid(storage: storage, maximumChordDistanceSquared: identity.maximumChordDistanceSquared,
            nearbyMaximumChordDistanceSquared: identity.nearbyMaximumChordDistanceSquared)

        let elevations = (0..<grid.nx).map { id -> Float in
            let sea = storage.metadata.coversWholeSphere ? storage.point(at: id).z >= 0 : id < grid.nx / 2
            return sea ? -999 : Float(100 + (id * 37) % 2_000)
        }
        let corpus = try makeCorpus(grid: grid, elevations: elevations)
        let file = try await makeElevationFile(elevations)
        defer { file.remove() }
        let reader = file.reader
        try #require(!corpus.ordinary.isEmpty && !corpus.sea.isEmpty && !corpus.land.isEmpty)
        let decoded = try await ElevationValues(decoded: reader.read(), expectedCount: grid.nx)
        let cached = IconNativeGrid(storage: storage, maximumChordDistanceSquared: grid.maximumChordDistanceSquared,
            nearbyMaximumChordDistanceSquared: grid.nearbyMaximumChordDistanceSquared, elevations: decoded)
        var results = [Measurement]()
        results.append(try measure("Nearest lookup", executions: corpus.ordinary.count * repeats) {
            nearestChecksum(grid, queries: corpus.ordinary)
        })
        for (name, adapter, queries, mode) in [
            ("Uncached elevation sea hit", grid, corpus.sea, GridSelectionMode.sea),
            ("Cached elevation sea hit", cached, corpus.sea, .sea),
            ("Uncached elevation terrain search", grid, corpus.land, .land),
            ("Cached elevation terrain search", cached, corpus.land, .land),
            ("Uncached sea search from land", grid, corpus.land, .sea),
            ("Cached sea search from land", cached, corpus.land, .sea)
        ] {
            results.append(try await measureAsync(name, executions: queries.count) {
                try await selectionChecksum(adapter, reader: reader, queries: queries, mode: mode)
            })
        }
        results.append(try measure("Nearest plus ten candidates", executions: corpus.ordinary.count * repeats) {
            candidateChecksum(grid, queries: corpus.ordinary)
        })
        let boundaries = makeBoundaryQueries(grid: grid)
        results.append(try measure("Boundary nearest lookup", executions: boundaries.count * repeats) {
            nearestChecksum(grid, queries: boundaries)
        })
        results.append(try measure("Boundary nearest plus ten candidates", executions: boundaries.count * repeats) {
            candidateChecksum(grid, queries: boundaries)
        })
        print("ICON native grid benchmark: \(path), \(grid.nx) cells, \(sampleCount) samples")
        for result in results {
            print("  \(result.operation): \(result.samplesNS.sorted()[sampleCount / 2] / 1_000) µs/query; checksum \(result.checksum)")
        }
    }

    private func makeCorpus(grid: IconNativeGrid, elevations: [Float]) throws -> Corpus {
        var state: UInt64 = 0xbb67_ae85_84ca_a73b
        var ordinary = [Query]()
        var sea = [Query]()
        var land = [Query]()
        for _ in 0..<65_536 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let coordinate = grid.getCoordinates(gridpoint: Int(state % UInt64(grid.nx)))
            let latitudeOffset = Float(Int((state >> 32) % 2_001) - 1_000) * 0.00001
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let longitudeOffset = Float(Int((state >> 32) % 2_001) - 1_000) * 0.00001
            let query = Query(latitude: min(90, max(-90, coordinate.latitude + latitudeOffset)), longitude: coordinate.longitude + longitudeOffset)
            ordinary.append(query)
            guard let id = grid.findPoint(lat: query.latitude, lon: query.longitude) else { continue }
            if elevations[id] <= -999, sea.count < 1_024 { sea.append(query) }
            if elevations[id] > -999, land.count < 1_024 { land.append(query) }
        }
        try #require(sea.count == 1_024 && land.count == 1_024)
        return Corpus(ordinary: ordinary, sea: sea, land: land)
    }

    /// Sample populated band/column boundaries and wider regional offsets, plus poles and dateline.
    private func makeBoundaryQueries(grid: IconNativeGrid) -> [Query] {
        let bands = grid.storage.latitudeBandCount
        let height = 180 / Double(bands)
        var queries = [Query]()
        for id in stride(from: 0, to: grid.nx, by: max(1, grid.nx / 1_024)) {
            let point = grid.getCoordinates(gridpoint: id)
            let row = min(bands - 1, max(0, Int((Double(point.latitude) + 90) / height)))
            let latitude = -90 + Double(row) * height
            let columns = max(1, Int((360 * cos((latitude + height / 2) * .pi / 180) / height).rounded()))
            let width = 360 / Double(columns)
            let longitude = -180 + floor((Double(point.longitude) + 180) / width) * width
            for epsilon in [-0.0001, 0, 0.0001] {
                queries.append(Query(latitude: Float(max(-90, min(90, latitude + epsilon * height))), longitude: point.longitude))
                queries.append(Query(latitude: point.latitude, longitude: Float(longitude + epsilon * width)))
            }
            for offset: Float in [-1, 1] {
                queries.append(Query(latitude: min(90, max(-90, point.latitude + offset)), longitude: point.longitude + offset))
            }
        }
        for latitude: Float in [-90, -89.99999, 0, 89.99999, 90] {
            for longitude: Float in [-540, -180, -179.99999, 0, 179.99999, 180, 540] {
                queries.append(Query(latitude: latitude, longitude: longitude))
            }
        }
        return queries
    }

    private func measure(_ name: String, executions: Int, _ operation: () -> Int) throws -> Measurement {
        let expected = operation()
        var samples = [Double]()
        for _ in 0..<sampleCount {
            let start = DispatchTime.now().uptimeNanoseconds
            let checksum = operation()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            try #require(checksum == expected)
            samples.append(Double(elapsed) / Double(executions))
        }
        return Measurement(operation: name, samplesNS: samples, checksum: expected)
    }

    private func measureAsync(_ name: String, executions: Int, _ operation: () async throws -> Int) async throws -> Measurement {
        let expected = try await operation()
        var samples = [Double]()
        for _ in 0..<sampleCount {
            let start = DispatchTime.now().uptimeNanoseconds
            let checksum = try await operation()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            try #require(checksum == expected)
            samples.append(Double(elapsed) / Double(executions))
        }
        return Measurement(operation: name, samplesNS: samples, checksum: expected)
    }

    @inline(never)
    private func nearestChecksum(_ grid: IconNativeGrid, queries: [Query]) -> Int {
        var sum = 0
        for _ in 0..<repeats {
            for query in queries { sum &+= grid.findPoint(lat: query.latitude, lon: query.longitude) ?? -1 }
        }
        return sum
    }

    @inline(never)
    private func candidateChecksum(_ grid: IconNativeGrid, queries: [Query]) -> Int {
        var sum = 0
        for _ in 0..<repeats {
            for query in queries {
                guard let lookup = grid.storage.nearestLookup(latitude: query.latitude, longitude: query.longitude,
                    maximumChordDistanceSquared: grid.maximumChordDistanceSquared) else { sum &+= -1; continue }
                let candidates = grid.storage.nearestCandidates(from: lookup, maximumChordDistanceSquared: grid.nearbyMaximumChordDistanceSquared)
                sum &+= candidates.count
                for i in 0..<candidates.count {
                    sum = (sum &* 31) &+ candidates.pointIDs[i] &+ Int(candidates.distancesSquared[i].bitPattern)
                }
            }
        }
        return sum
    }

    @inline(never)
    private func selectionChecksum(_ grid: IconNativeGrid, reader: any OmFileReaderArrayProtocol<Float>,
                                   queries: [Query], mode: GridSelectionMode) async throws -> Int {
        var sum = 0
        for query in queries {
            let result = try await grid.findPoint(lat: query.latitude, lon: query.longitude,
                elevation: -10_000, elevationFile: reader, mode: mode)
            let elevationChecksum: Int
            switch result?.gridElevation {
            case nil: elevationChecksum = 0
            case .noData: elevationChecksum = 1
            case .sea: elevationChecksum = 2
            case .landWithoutElevation: elevationChecksum = 3
            case .elevation(let value): elevationChecksum = 4 &+ Int(value.bitPattern)
            }
            sum = (sum &* 31) &+ (result?.gridpoint ?? -1) &+ elevationChecksum
        }
        return sum
    }
}
