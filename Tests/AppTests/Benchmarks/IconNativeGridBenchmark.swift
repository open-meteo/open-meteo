import Foundation
import OmFileFormat
import Testing
@testable import App
@testable import SphericalCube
@testable import SphericalCubeTests

/// Opt-in because this generates an R3B7-scale artifact and performs several million lookups.
/// Run with:
/// `ICON_NATIVE_GRID_BENCHMARK=1 swift test -c release --filter IconNativeGridBenchmarkTests`
/// Set `ICON_NATIVE_GRID_ARTIFACT` to benchmark an existing global or regional artifact instead.
@Suite struct IconNativeGridBenchmarkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_BENCHMARK"] == "1"))
    func benchmark() async throws {
        try await IconNativeGridBenchmark.run()
    }
}

/// Retained microbenchmark for the active mmap-backed cube lookup and elevation-selection paths.
enum IconNativeGridBenchmark {
    private static let syntheticCellCount = 2_949_120
    private static let queryCount = 65_536
    private static let repeats = 8
    private static let elevationQueryCount = 1_024
    private static let sampleCount = 9

    static func run() async throws {
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
                points: makeSphericalCenters(count: syntheticCellCount),
                level: 9
            )
        }
        defer {
            if usesTemporaryArtifact { try? FileManager.default.removeItem(at: file) }
        }
        let grid = try IconNativeGrid.load(file: file)
        let artifactBytes = try #require(
            file.resourceValues(forKeys: [.fileSizeKey]).fileSize
        )
        let queries = configuredArtifact == nil ? makeQueries() : makeQueries(grid: grid)
        let conversion = measure {
            conversionChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let lookup = measure {
            lookupChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let terrainCandidates = measure {
            terrainCandidateChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let elevationBenchmark = try await measureElevationSelection(
            grid: grid,
            queries: queries
        )

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
        print("  elevation queries/path: \(elevationQueryCount)")
        printResult("cold full-grid load", elevationBenchmark.coldGridLoad, unit: "ns/load")
        printResult("raw sea hit", elevationBenchmark.rawSea)
        printResult("cold-cache sea hit", elevationBenchmark.coldSea)
        printResult("warm-cache sea hit", elevationBenchmark.warmSea)
        printResult("warm-cache terrain hit", elevationBenchmark.warmTerrainHit)
        printResult("raw land candidate search", elevationBenchmark.rawLand)
        printResult("cold-cache land candidate search", elevationBenchmark.coldLand)
        printResult("warm-cache land candidate search", elevationBenchmark.warmLand)
        printResult("raw terrain elevation search", elevationBenchmark.rawTerrain)
        printResult("cold-cache terrain elevation search", elevationBenchmark.coldTerrain)
        printResult("warm-cache terrain elevation search", elevationBenchmark.warmTerrain)
        print("  artifact: \(artifactBytes) bytes")
        print("  lookup checksum: \(lookup.checksum)")
        print("  terrain checksum: \(terrainCandidates.checksum)")
        print("  elevation checksum: \(elevationBenchmark.checksum)")
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

    private struct ElevationSelectionMeasurements {
        let coldGridLoad: (samples: [Double], checksum: Int)
        let rawSea: (samples: [Double], checksum: Int)
        let coldSea: (samples: [Double], checksum: Int)
        let warmSea: (samples: [Double], checksum: Int)
        let warmTerrainHit: (samples: [Double], checksum: Int)
        let rawLand: (samples: [Double], checksum: Int)
        let coldLand: (samples: [Double], checksum: Int)
        let warmLand: (samples: [Double], checksum: Int)
        let rawTerrain: (samples: [Double], checksum: Int)
        let coldTerrain: (samples: [Double], checksum: Int)
        let warmTerrain: (samples: [Double], checksum: Int)

        var checksum: Int {
            coldGridLoad.checksum &+ rawSea.checksum &+ coldSea.checksum &+ warmSea.checksum &+ warmTerrainHit.checksum
                &+ rawLand.checksum &+ coldLand.checksum &+ warmLand.checksum
                &+ rawTerrain.checksum &+ coldTerrain.checksum &+ warmTerrain.checksum
        }
    }

    private static func measureElevationSelection(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)]
    ) async throws -> ElevationSelectionMeasurements {
        // Separate the fast sea branch from the land candidate branch while retaining varied
        // int16-compressed land values instead of benchmarking a constant decoded chunk.
        var elevations = [Float](repeating: 0, count: grid.nx)
        for pointID in elevations.indices {
            // Regional grids can lie entirely in one hemisphere. Split their canonical IDs so
            // both selection paths have samples while preserving the global benchmark workload.
            let isSea = grid.storage.coversWholeSphere
                ? grid.storage.point(at: pointID).z >= 0
                : pointID < grid.nx / 2
            elevations[pointID] = isSea
                ? -999
                : Float(100 + (pointID * 37) % 2_000)
        }

        var seaQueries = [(latitude: Float, longitude: Float)]()
        var landQueries = [(latitude: Float, longitude: Float)]()
        seaQueries.reserveCapacity(elevationQueryCount)
        landQueries.reserveCapacity(elevationQueryCount)
        for query in queries {
            guard let pointID = grid.storage.nearestPointID(
                latitude: query.latitude,
                longitude: query.longitude
            ) else { continue }
            if elevations[pointID] <= -999, seaQueries.count < elevationQueryCount {
                seaQueries.append(query)
            } else if elevations[pointID] > -999, landQueries.count < elevationQueryCount {
                landQueries.append(query)
            }
            if seaQueries.count == elevationQueryCount, landQueries.count == elevationQueryCount {
                break
            }
        }
        guard
            seaQueries.count == elevationQueryCount,
            landQueries.count == elevationQueryCount
        else {
            throw BenchmarkError.insufficientElevationQueries
        }

        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-native-surface-benchmark-\(UUID().uuidString).om").path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let handle = try FileHandle.createNewFile(file: path)
        try elevations.writeOmFile(
            fn: handle,
            dimensions: [1, elevations.count],
            chunks: [1, 400],
            compression: .pfor_delta2d_int16,
            scalefactor: 1
        )
        try handle.close()
        let reader = try await OmFileReader(file: path).expectArray(of: Float.self)

        let coldGridLoad = try await measureColdGridLoad(reader: reader)
        let rawSea = try await measureAsync(executions: seaQueries.count) {
            try await elevationSelectionChecksum(grid: grid, reader: reader, queries: seaQueries)
        }
        let coldSea = try await measureColdCache(reader: reader, grid: grid, queries: seaQueries)
        let warmSeaReader = try #require(OmFileLazyInt16ArrayReader(wrapping: reader))
        let warmSea = try await measureAsync(executions: seaQueries.count) {
            try await elevationSelectionChecksum(
                grid: grid,
                reader: warmSeaReader,
                queries: seaQueries
            )
        }

        let rawLand = try await measureAsync(executions: landQueries.count) {
            try await elevationSelectionChecksum(grid: grid, reader: reader, queries: landQueries)
        }
        let coldLand = try await measureColdCache(reader: reader, grid: grid, queries: landQueries)
        let warmLandReader = try #require(OmFileLazyInt16ArrayReader(wrapping: reader))
        let warmLand = try await measureAsync(executions: landQueries.count) {
            try await elevationSelectionChecksum(
                grid: grid,
                reader: warmLandReader,
                queries: landQueries
            )
        }

        let rawTerrain = try await measureAsync(executions: landQueries.count) {
            try await terrainSelectionChecksum(grid: grid, reader: reader, queries: landQueries)
        }
        let coldTerrain = try await measureColdCache(
            reader: reader,
            grid: grid,
            queries: landQueries,
            operation: terrainSelectionChecksum
        )
        let warmTerrainReader = try #require(OmFileLazyInt16ArrayReader(wrapping: reader))
        let matchedElevations = landQueries.map { query in
            elevations[grid.storage.nearestPointID(latitude: query.latitude, longitude: query.longitude)!]
        }
        let warmTerrainHit = try await measureAsync(executions: landQueries.count) {
            var checksum = 0
            for (index, query) in landQueries.enumerated() {
                let result = try await grid.findPointTerrainOptimised(
                    lat: query.latitude,
                    lon: query.longitude,
                    elevation: matchedElevations[index],
                    elevationFile: warmTerrainReader
                )
                checksum &+= result?.gridpoint ?? -1
            }
            return checksum
        }
        let warmTerrain = try await measureAsync(executions: landQueries.count) {
            try await terrainSelectionChecksum(
                grid: grid,
                reader: warmTerrainReader,
                queries: landQueries
            )
        }

        return ElevationSelectionMeasurements(
            coldGridLoad: coldGridLoad,
            rawSea: rawSea,
            coldSea: coldSea,
            warmSea: warmSea,
            warmTerrainHit: warmTerrainHit,
            rawLand: rawLand,
            coldLand: coldLand,
            warmLand: warmLand,
            rawTerrain: rawTerrain,
            coldTerrain: coldTerrain,
            warmTerrain: warmTerrain
        )
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

    private static func measureColdCache(
        reader: any OmFileReaderArrayProtocol<Float>,
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        operation: (
            IconNativeGrid,
            any OmFileReaderArrayProtocol<Float>,
            [(latitude: Float, longitude: Float)]
        ) async throws -> Int = elevationSelectionChecksum
    ) async throws -> (samples: [Double], checksum: Int) {
        var checksum = 0
        var samples = [Double]()
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let cachedReader = try #require(OmFileLazyInt16ArrayReader(wrapping: reader))
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= try await operation(grid, cachedReader, queries)
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsed) / Double(queries.count))
        }
        samples.sort()
        return (samples, checksum)
    }

    private static func measureColdGridLoad(
        reader: any OmFileReaderArrayProtocol<Float>
    ) async throws -> (samples: [Double], checksum: Int) {
        var checksum = 0
        var samples = [Double]()
        samples.reserveCapacity(sampleCount)
        for _ in 0..<sampleCount {
            let cachedReader = try #require(OmFileLazyInt16ArrayReader(wrapping: reader))
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= Int(try await cachedReader.read(pointID: 0))
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
    }

    private enum BenchmarkError: Error {
        case insufficientElevationQueries
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
    private static func elevationSelectionChecksum(
        grid: IconNativeGrid,
        reader: any OmFileReaderArrayProtocol<Float>,
        queries: [(latitude: Float, longitude: Float)]
    ) async throws -> Int {
        var checksum = 0
        for query in queries {
            let result = try await grid.findPointInSea(
                lat: query.latitude,
                lon: query.longitude,
                elevationFile: reader
            )
            checksum &+= result?.gridpoint ?? -1
        }
        return checksum
    }

    @inline(never)
    private static func terrainSelectionChecksum(
        grid: IconNativeGrid,
        reader: any OmFileReaderArrayProtocol<Float>,
        queries: [(latitude: Float, longitude: Float)]
    ) async throws -> Int {
        var checksum = 0
        for query in queries {
            let result = try await grid.findPointTerrainOptimised(
                lat: query.latitude,
                lon: query.longitude,
                elevation: -10_000,
                elevationFile: reader
            )
            checksum &+= result?.gridpoint ?? -1
        }
        return checksum
    }
}
