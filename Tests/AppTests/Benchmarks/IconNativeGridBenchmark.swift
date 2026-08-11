import Foundation
import OmFileFormat
import Testing
@testable import App

/// Opt-in because this generates an R3B7-scale artifact and performs several million lookups.
/// Run with:
/// `ICON_NATIVE_GRID_BENCHMARK=1 swift test -c release --filter IconNativeGridBenchmarkTests`
@Suite struct IconNativeGridBenchmarkTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_NATIVE_GRID_BENCHMARK"] == "1"))
    func benchmark() async throws {
        try await IconNativeGridBenchmark.run()
    }
}

/// Retained microbenchmark for changes to the mmap-backed cube lookup and artifact layout.
///
/// This lives in the test target so benchmark-only topology and oracle code is never linked into
/// the production server executable.
enum IconNativeGridBenchmark {
    private static let cellCount = 2_949_120
    private static let queryCount = 65_536
    private static let repeats = 8
    private static let sampleCount = 9

    private struct CandidatePolicy {
        let name: String
        let scanLimit: Int
    }

    private static let candidatePolicies = [
        CandidatePolicy(name: "fixed-12", scanLimit: 12),
        CandidatePolicy(name: "fixed-40", scanLimit: 40),
    ]

    static func run() async throws {
        try runLookupBenchmark()
        try await runTerrainComparisonIfAvailable()
    }

    private static func runLookupBenchmark() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-native-cube-benchmark-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: file) }

        print("Generating deterministic R3B7-scale cube artifact...")
        try IconNativeGrid.Generator.ArtifactWriter.write(
            to: file,
            metadata: .init(
                gridNumber: 26,
                gridUUID: [UInt8](repeating: 0, count: 16),
                isGlobal: true,
                maximumDistanceMeters: 20_000
            ),
            centers: makeCenters(),
            level: 9
        )
        let grid = try IconNativeGrid.load(file: file)
        let queries = makeQueries()

        let conversion = measure {
            conversionChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let lookup = measure {
            lookupChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let terrainCandidates = measure {
            terrainCandidateChecksum(grid: grid, queries: queries, repeats: repeats)
        }
        let prototypeCandidates = candidatePolicies.map { policy in
            (
                policy,
                measure {
                    terrainCandidatePrototypeChecksum(
                        grid: grid,
                        queries: queries,
                        repeats: repeats,
                        policy: policy
                    )
                }
            )
        }

        print("ICON native cube benchmark")
        print("  cells: \(cellCount)")
        print("  queries/sample: \(queryCount * repeats)")
        print("  samples: \(sampleCount)")
        print("  coordinate conversion median: \(conversion.samples[sampleCount / 2]) ns/query")
        print("  coordinate conversion range: \(conversion.samples[0])...\(conversion.samples[sampleCount - 1]) ns/query")
        print("  lookup median: \(lookup.samples[sampleCount / 2]) ns/query")
        print("  lookup range: \(lookup.samples[0])...\(lookup.samples[sampleCount - 1]) ns/query")
        print("  terrain candidates median: \(terrainCandidates.samples[sampleCount / 2]) ns/query")
        print("  terrain candidates range: \(terrainCandidates.samples[0])...\(terrainCandidates.samples[sampleCount - 1]) ns/query")
        for (policy, result) in prototypeCandidates {
            print("  \(policy.name): \(result.samples[sampleCount / 2]) ns/query")
        }
        print("  artifact: \(grid.storage.artifactBytes) bytes")
        print("  lookup checksum: \(lookup.checksum)")
        print("  terrain checksum: \(terrainCandidates.checksum)")
    }

    /// Compares only the part changed by removing topology. Both paths use the same current
    /// cube lookup for the exact seed, the same official centres, queries, and elevations, and
    /// run in the same optimized process. Elevations are decoded before timing so this measures
    /// candidate generation and CPU-side terrain selection rather than storage-cache noise.
    private static func runTerrainComparisonIfAvailable() async throws {
        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let legacyFile = directory.appendingPathComponent("data/dwd_icon_d2_native/static/grid.bin")
        let elevationFile = directory.appendingPathComponent("data/dwd_icon_d2_native/static/HSURF.om")
        guard FileManager.default.fileExists(atPath: legacyFile.path),
              FileManager.default.fileExists(atPath: elevationFile.path) else {
            print("Skipping fair terrain comparison: ICON-D2 grid.bin or HSURF.om is unavailable")
            return
        }

        print("Loading official ICON-D2 topology and elevations...")
        let legacy = try LegacyTopologyGrid(file: legacyFile)
        let elevationReader = try await OmFileReader(mmapFile: elevationFile.path)
            .expectArray(of: Float.self)
        let elevations = try await elevationReader.read()
        guard elevations.count == legacy.centers.count else {
            throw BenchmarkError.invalidElevationCount(
                actual: elevations.count,
                expected: legacy.centers.count
            )
        }

        let cubeFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-native-d2-terrain-benchmark-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: cubeFile) }
        try IconNativeGrid.Generator.ArtifactWriter.write(
            to: cubeFile,
            metadata: legacy.cubeMetadata,
            centers: legacy.centers,
            level: 11
        )
        let grid = try IconNativeGrid.load(file: cubeFile)
        let queries = makeTerrainQueries(
            coordinates: legacy.coordinates,
            elevations: elevations,
            grid: grid,
            count: 32_768
        )
        let coordinateQueries = queries.map { ($0.latitude, $0.longitude) }
        let comparisonRepeats = 4
        let executions = queries.count * comparisonRepeats

        let topologyCandidates = measure(executions: executions) {
            topologyCandidateChecksum(
                grid: grid,
                topology: legacy.neighbours,
                queries: queries,
                repeats: comparisonRepeats
            )
        }
        let cubeCandidates = measure(executions: executions) {
            terrainCandidateChecksum(
                grid: grid,
                queries: coordinateQueries,
                repeats: comparisonRepeats
            )
        }
        let prototypeCandidates = candidatePolicies.map { policy in
            (
                policy,
                measure(executions: executions) {
                    terrainCandidatePrototypeChecksum(
                        grid: grid,
                        queries: coordinateQueries,
                        repeats: comparisonRepeats,
                        policy: policy
                    )
                }
            )
        }
        let topologyTerrain = measure(executions: executions) {
            terrainSelectionChecksum(
                grid: grid,
                topology: legacy.neighbours,
                elevations: elevations,
                queries: queries,
                repeats: comparisonRepeats,
                useCubeCandidates: false
            )
        }
        let cubeTerrain = measure(executions: executions) {
            terrainSelectionChecksum(
                grid: grid,
                topology: legacy.neighbours,
                elevations: elevations,
                queries: queries,
                repeats: comparisonRepeats,
                useCubeCandidates: true
            )
        }
        let quality = compareTerrainSelections(
            grid: grid,
            topology: legacy.neighbours,
            elevations: elevations,
            queries: queries
        )
        let prototypeQuality = candidatePolicies.map { policy in
            (
                policy,
                compareTerrainSelections(
                    grid: grid,
                    topology: legacy.neighbours,
                    elevations: elevations,
                    queries: queries,
                    candidatePolicy: policy
                )
            )
        }
        let storageQueries = Array(queries.prefix(2_048))
        let fastStorageQueries = makeFastTerrainQueries(
            from: storageQueries,
            elevations: elevations,
            grid: grid
        )
        let topologyStorage = try await measureAsync(executions: storageQueries.count) {
            try await terrainStorageChecksum(
                grid: grid,
                topology: legacy.neighbours,
                elevationFile: elevationReader,
                queries: storageQueries,
                useCubeCandidates: false
            )
        }
        let cubeStorage = try await measureAsync(executions: storageQueries.count) {
            try await terrainStorageChecksum(
                grid: grid,
                topology: legacy.neighbours,
                elevationFile: elevationReader,
                queries: storageQueries,
                useCubeCandidates: true
            )
        }
        let topologyFastStorage = try await measureAsync(executions: fastStorageQueries.count) {
            try await terrainStorageChecksum(
                grid: grid,
                topology: legacy.neighbours,
                elevationFile: elevationReader,
                queries: fastStorageQueries,
                useCubeCandidates: false
            )
        }
        let cubeFastStorage = try await measureAsync(executions: fastStorageQueries.count) {
            try await terrainStorageChecksum(
                grid: grid,
                topology: legacy.neighbours,
                elevationFile: elevationReader,
                queries: fastStorageQueries,
                useCubeCandidates: true
            )
        }
        let topologyBytes = legacy.centers.count * 3 * MemoryLayout<UInt32>.size

        print("Fair ICON-D2 terrain comparison")
        print("  cells: \(legacy.centers.count)")
        print("  queries/sample: \(executions) (forced non-fast terrain path)")
        print("  exact seed: current Float32 cube lookup for both paths")
        print("  topology candidates median: \(topologyCandidates.samples[sampleCount / 2]) ns/query")
        print("  cube candidates median: \(cubeCandidates.samples[sampleCount / 2]) ns/query")
        for index in prototypeCandidates.indices {
            let policy = prototypeCandidates[index].0
            let timing = prototypeCandidates[index].1.samples[sampleCount / 2]
            let policyQuality = prototypeQuality[index].1
            print(
                "  \(policy.name): \(timing) ns/query; "
                    + "agreement \(policyQuality.equalPercent)%; "
                    + "union optimum \(policyQuality.cubeUnionPercent)%"
            )
        }
        print("  topology terrain median: \(topologyTerrain.samples[sampleCount / 2]) ns/query")
        print("  cube terrain median: \(cubeTerrain.samples[sampleCount / 2]) ns/query")
        print("  topology terrain + OM reads median: \(topologyStorage.samples[2]) ns/query")
        print("  cube terrain + OM reads median: \(cubeStorage.samples[2]) ns/query")
        print("  topology fast terrain + OM reads median: \(topologyFastStorage.samples[2]) ns/query")
        print("  cube fast terrain + OM reads median: \(cubeFastStorage.samples[2]) ns/query")
        print("  selection agreement: \(quality.equalSelections) / \(queries.count) (\(quality.equalPercent)%)")
        print("  topology selects union optimum: \(quality.topologyUnionPercent)%")
        print("  cube selects union optimum: \(quality.cubeUnionPercent)%")
        print("  mean candidates: topology \(quality.topologyMeanCount), cube \(quality.cubeMeanCount)")
        print("  topology section: \(topologyBytes) bytes")
        print("  topology-free artifact: \(grid.storage.artifactBytes) bytes")
        print("  comparable artifact with topology: \(grid.storage.artifactBytes + topologyBytes) bytes")
        print("  checksums: \(topologyCandidates.checksum), \(cubeCandidates.checksum), \(topologyTerrain.checksum), \(cubeTerrain.checksum)")
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

    private static func measureAsync(
        executions: Int,
        _ operation: () async throws -> Int
    ) async throws -> (samples: [Double], checksum: Int) {
        var checksum = try await operation()
        var samples = [Double]()
        samples.reserveCapacity(5)
        for _ in 0..<5 {
            let start = DispatchTime.now().uptimeNanoseconds
            checksum &+= try await operation()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsed) / Double(executions))
        }
        samples.sort()
        return (samples, checksum)
    }

    private static func makeCenters() -> [IconNativeCenter] {
        let goldenAngle = Double.pi * (3 - sqrt(5.0))
        var centers = [IconNativeCenter]()
        centers.reserveCapacity(cellCount)
        for index in 0..<cellCount {
            let z = 1 - 2 * (Double(index) + 0.5) / Double(cellCount)
            let radius = sqrt(max(0, 1 - z * z))
            let longitude = Double(index) * goldenAngle
            centers.append(
                IconNativeCenter(
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

    @inline(never)
    private static func conversionChecksum(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                let longitude = Float(IconNativeCenter.normalizedLongitude(query.longitude))
                let vector = IconNativeCenter.fastCubeLookupVector(
                    latitudeDegrees: query.latitude,
                    longitudeDegrees: longitude
                )
                let location = IconNativeGrid.CubeGeometry.location(
                    for: vector.center,
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
                checksum &+= grid.storage.findNearestCell(
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
                let candidates = grid.storage.findNearestCells(
                    latitude: query.latitude,
                    longitude: query.longitude
                )!
                checksum &+= candidates.points[0] &+ candidates.count
            }
        }
        return checksum
    }

    @inline(never)
    private static func terrainCandidatePrototypeChecksum(
        grid: IconNativeGrid,
        queries: [(latitude: Float, longitude: Float)],
        repeats: Int,
        policy: CandidatePolicy
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                let lookup = grid.storage.findNearestLookup(
                    latitude: query.latitude,
                    longitude: query.longitude
                )!
                let candidates = grid.storage.findNearestCells(
                    from: lookup,
                    scanLimit: policy.scanLimit,
                    certifyTopCandidates: false
                )
                checksum &+= candidates.points[0] &+ candidates.count
            }
        }
        return checksum
    }

    private struct TerrainQuery {
        let latitude: Float
        let longitude: Float
        let elevation: Float
    }

    private enum BenchmarkError: Error {
        case invalidLegacyArtifact
        case invalidElevationCount(actual: Int, expected: Int)
    }

    /// Reader for the last topology-bearing production artifact. Only benchmark data are decoded;
    /// this deliberately does not restore the old runtime implementation.
    private struct LegacyTopologyGrid {
        let centers: [IconNativeCenter]
        let coordinates: [(latitude: Float, longitude: Float)]
        let neighbours: [UInt32]
        let cubeMetadata: IconNativeGrid.CubeArtifact.Metadata

        init(file: URL) throws {
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            guard data.count >= 160,
                  data[0] == 0x49, data[1] == 0x43, data[2] == 0x4f, data[3] == 0x4e,
                  data[4] == 0x4d, data[5] == 0x53, data[6] == 0x48, data[7] == 0x31,
                  data.readUInt32(at: 8) == 4,
                  data.readUInt32(at: 12) == 160 else {
                throw BenchmarkError.invalidLegacyArtifact
            }
            let flags = data.readUInt32(at: 16)
            let count = Int(data.readUInt32(at: 24))
            let nx = Int(data.readUInt32(at: 32))
            let ny = Int(data.readUInt32(at: 36))
            let centersOffset = Int(data.readUInt64(at: 80))
            let neighboursOffset = Int(data.readUInt64(at: 104))
            guard count > 0, nx > 0, ny > 0,
                  centersOffset >= 160,
                  centersOffset + count * 8 <= data.count,
                  neighboursOffset + count * 12 <= data.count else {
                throw BenchmarkError.invalidLegacyArtifact
            }

            var coordinates = [(latitude: Float, longitude: Float)]()
            var centers = [IconNativeCenter]()
            coordinates.reserveCapacity(count)
            centers.reserveCapacity(count)
            data.withUnsafeBytes { bytes in
                for cell in 0..<count {
                    let offset = centersOffset + cell * 8
                    let latitude = Float(bitPattern: UInt32(littleEndian: bytes.loadUnaligned(
                        fromByteOffset: offset,
                        as: UInt32.self
                    )))
                    let longitude = Float(bitPattern: UInt32(littleEndian: bytes.loadUnaligned(
                        fromByteOffset: offset + 4,
                        as: UInt32.self
                    )))
                    coordinates.append((latitude, longitude))
                    centers.append(IconNativeCenter(
                        latitudeDegrees: Double(latitude),
                        longitudeDegrees: Double(longitude)
                    ))
                }
            }
            var neighbours = [UInt32](repeating: UInt32.max, count: count * 3)
            data.withUnsafeBytes { bytes in
                for position in neighbours.indices {
                    neighbours[position] = UInt32(littleEndian: bytes.loadUnaligned(
                        fromByteOffset: neighboursOffset + position * 4,
                        as: UInt32.self
                    ))
                }
            }
            var uuid = [UInt8]()
            uuid.reserveCapacity(16)
            for offset in 136..<152 { uuid.append(data[offset]) }

            self.centers = centers
            self.coordinates = coordinates
            self.neighbours = neighbours
            cubeMetadata = .init(
                gridNumber: data.readUInt32(at: 20),
                gridUUID: uuid,
                isGlobal: flags & 1 != 0,
                maximumDistanceMeters: 4_000
            )
        }
    }

    private static func makeTerrainQueries(
        coordinates: [(latitude: Float, longitude: Float)],
        elevations: [Float],
        grid: IconNativeGrid,
        count: Int
    ) -> [TerrainQuery] {
        var queries = [TerrainQuery]()
        queries.reserveCapacity(count)
        var state: UInt64 = 0x243f_6a88_85a3_08d3
        while queries.count < count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let cell = Int(state % UInt64(coordinates.count))
            let coordinate = coordinates[cell]
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let latitudeJitter = Float(Int(state & 0xffff) - 32_768) / 32_768 * 0.004
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let longitudeJitter = Float(Int(state & 0xffff) - 32_768) / 32_768 * 0.006
            let latitude = min(90, max(-90, coordinate.latitude + latitudeJitter))
            let longitude = coordinate.longitude + longitudeJitter
            guard let nearest = grid.storage.findNearestCell(
                latitude: latitude,
                longitude: longitude
            ) else { continue }
            let nearestElevation = elevations[nearest]
            let target = nearestElevation.isFinite && nearestElevation > -999 && nearestElevation < 9999
                ? nearestElevation + (queries.count.isMultiple(of: 2) ? 600 : -600)
                : 500
            queries.append(TerrainQuery(
                latitude: latitude,
                longitude: longitude,
                elevation: target
            ))
        }
        return queries
    }

    private static func makeFastTerrainQueries(
        from queries: [TerrainQuery],
        elevations: [Float],
        grid: IconNativeGrid
    ) -> [TerrainQuery] {
        queries.compactMap { query in
            guard let nearest = grid.storage.findNearestCell(
                latitude: query.latitude,
                longitude: query.longitude
            ) else { return nil }
            let elevation = elevations[nearest]
            guard elevation.isFinite, elevation > -999, elevation < 9999 else { return nil }
            return TerrainQuery(
                latitude: query.latitude,
                longitude: query.longitude,
                elevation: elevation
            )
        }
    }

    @inline(__always)
    private static func topologyCandidates(
        seed: Int,
        topology: [UInt32]
    ) -> (points: InlineArray<16, Int>, count: Int) {
        var points = InlineArray<16, Int>(repeating: -1)
        var count = 0
        @inline(__always)
        func append(_ cell: Int) {
            for position in 0..<count where points[position] == cell { return }
            guard count < 10 else { return }
            points[count] = cell
            count += 1
        }
        append(seed)
        for edge in 0..<3 {
            let neighbour = topology[seed * 3 + edge]
            if neighbour != UInt32.max { append(Int(neighbour)) }
        }
        let firstRingEnd = count
        if firstRingEnd > 1 {
            for position in 1..<firstRingEnd {
                let cell = points[position]
                for edge in 0..<3 {
                    let neighbour = topology[cell * 3 + edge]
                    if neighbour != UInt32.max { append(Int(neighbour)) }
                }
            }
        }
        return (points, count)
    }

    @inline(never)
    private static func topologyCandidateChecksum(
        grid: IconNativeGrid,
        topology: [UInt32],
        queries: [TerrainQuery],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for query in queries {
                let seed = grid.storage.findNearestCell(
                    latitude: query.latitude,
                    longitude: query.longitude
                )!
                let candidates = topologyCandidates(seed: seed, topology: topology)
                checksum &+= candidates.points[0] &+ candidates.count
            }
        }
        return checksum
    }

    @inline(__always)
    private static func terrainSelection<let capacity: Int>(
        candidates: (points: InlineArray<capacity, Int>, count: Int),
        query: IconNativeCenter,
        elevation: Float,
        grid: IconNativeGrid,
        elevations: [Float]
    ) -> Int {
        let nearest = candidates.points[0]
        let nearestElevation = elevations[nearest]
        if nearestElevation.isFinite, nearestElevation > -999,
            abs(nearestElevation - elevation) <= 100 {
            return nearest
        }
        var bestCell = -1
        var bestScore = Float.greatestFiniteMagnitude
        for position in 0..<candidates.count {
            let cell = candidates.points[position]
            let candidateElevation = elevations[cell]
            if !candidateElevation.isFinite || candidateElevation <= -999 { continue }
            let dot = max(-1, min(1, grid.storage.centerVector(at: cell).dot(query)))
            let distanceKilometres = Float(acos(dot) * 6371.229)
            if distanceKilometres >= 50 { continue }
            let elevationDelta = candidateElevation >= 9999 ? 0 : abs(candidateElevation - elevation)
            let score = elevationDelta + distanceKilometres * 30
            if score < bestScore || (score == bestScore && (bestCell < 0 || cell < bestCell)) {
                bestScore = score
                bestCell = cell
            }
        }
        return bestCell < 0 || bestScore > 1500 ? nearest : bestCell
    }

    @inline(never)
    private static func terrainSelectionChecksum(
        grid: IconNativeGrid,
        topology: [UInt32],
        elevations: [Float],
        queries: [TerrainQuery],
        repeats: Int,
        useCubeCandidates: Bool
    ) -> Int {
        if useCubeCandidates {
            return cubeTerrainSelectionChecksum(
                grid: grid,
                elevations: elevations,
                queries: queries,
                repeats: repeats
            )
        }
        var checksum = 0
        for _ in 0..<repeats {
            for item in queries {
                let query = IconNativeCenter(
                    latitudeDegrees: Double(item.latitude),
                    longitudeDegrees: IconNativeCenter.normalizedLongitude(item.longitude)
                )
                let seed = grid.storage.findNearestCell(
                    latitude: item.latitude,
                    longitude: item.longitude
                )!
                let candidates = topologyCandidates(seed: seed, topology: topology)
                checksum &+= terrainSelection(
                    candidates: candidates,
                    query: query,
                    elevation: item.elevation,
                    grid: grid,
                    elevations: elevations
                )
            }
        }
        return checksum
    }

    @inline(never)
    private static func cubeTerrainSelectionChecksum(
        grid: IconNativeGrid,
        elevations: [Float],
        queries: [TerrainQuery],
        repeats: Int
    ) -> Int {
        var checksum = 0
        for _ in 0..<repeats {
            for item in queries {
                let lookup = grid.storage.findNearestLookup(
                    latitude: item.latitude,
                    longitude: item.longitude
                )!
                let nearestElevation = elevations[lookup.cell]
                if nearestElevation.isFinite, nearestElevation > -999,
                    abs(nearestElevation - item.elevation) <= 100 {
                    checksum &+= lookup.cell
                    continue
                }
                let candidates = grid.storage.findNearestCells(from: lookup)
                var bestPosition = -1
                var bestScore = Float.greatestFiniteMagnitude
                for position in 0..<candidates.count {
                    let candidateElevation = elevations[candidates.points[position]]
                    if !candidateElevation.isFinite || candidateElevation <= -999 { continue }
                    let distanceKilometres =
                        sqrt(max(0, candidates.distancesSquared[position])) * 6371.229
                    if distanceKilometres >= 50 { continue }
                    let elevationDelta = candidateElevation >= 9999
                        ? 0
                        : abs(candidateElevation - item.elevation)
                    let score = elevationDelta + distanceKilometres * 30
                    if score < bestScore
                        || (score == bestScore
                            && (bestPosition < 0
                                || candidates.points[position] < candidates.points[bestPosition])) {
                        bestScore = score
                        bestPosition = position
                    }
                }
                checksum &+= bestPosition < 0 || bestScore > 1500
                    ? lookup.cell
                    : candidates.points[bestPosition]
            }
        }
        return checksum
    }

    private static func compareTerrainSelections(
        grid: IconNativeGrid,
        topology: [UInt32],
        elevations: [Float],
        queries: [TerrainQuery],
        candidatePolicy: CandidatePolicy? = nil
    ) -> (
        equalSelections: Int,
        equalPercent: Double,
        topologyUnionPercent: Double,
        cubeUnionPercent: Double,
        topologyMeanCount: Double,
        cubeMeanCount: Double
    ) {
        var equal = 0
        var topologyUnion = 0
        var cubeUnion = 0
        var topologyCount = 0
        var cubeCount = 0
        for item in queries {
            let query = IconNativeCenter(
                latitudeDegrees: Double(item.latitude),
                longitudeDegrees: IconNativeCenter.normalizedLongitude(item.longitude)
            )
            let seed = grid.storage.findNearestCell(
                latitude: item.latitude,
                longitude: item.longitude
            )!
            let topologyCandidates = topologyCandidates(seed: seed, topology: topology)
            let cubeCandidates: (points: InlineArray<16, Int>, count: Int)
            if let candidatePolicy {
                let lookup = grid.storage.findNearestLookup(
                    latitude: item.latitude,
                    longitude: item.longitude
                )!
                let prototype = grid.storage.findNearestCells(
                    from: lookup,
                    scanLimit: candidatePolicy.scanLimit,
                    certifyTopCandidates: false
                )
                cubeCandidates = (prototype.points, prototype.count)
            } else {
                cubeCandidates = grid.storage.findNearestCells(
                    latitude: item.latitude,
                    longitude: item.longitude
                )!
            }
            let topologyCell = terrainSelection(
                candidates: topologyCandidates,
                query: query,
                elevation: item.elevation,
                grid: grid,
                elevations: elevations
            )
            let cubeCell = terrainSelection(
                candidates: cubeCandidates,
                query: query,
                elevation: item.elevation,
                grid: grid,
                elevations: elevations
            )
            var union = (
                points: InlineArray<32, Int>(repeating: -1),
                count: topologyCandidates.count
            )
            for position in 0..<topologyCandidates.count {
                union.points[position] = topologyCandidates.points[position]
            }
            for position in 0..<cubeCandidates.count {
                let cell = cubeCandidates.points[position]
                var exists = false
                for existing in 0..<union.count where union.points[existing] == cell {
                    exists = true
                }
                if !exists {
                    union.points[union.count] = cell
                    union.count += 1
                }
            }
            let unionCell = terrainSelection(
                candidates: union,
                query: query,
                elevation: item.elevation,
                grid: grid,
                elevations: elevations
            )
            equal += topologyCell == cubeCell ? 1 : 0
            topologyUnion += topologyCell == unionCell ? 1 : 0
            cubeUnion += cubeCell == unionCell ? 1 : 0
            topologyCount += topologyCandidates.count
            cubeCount += cubeCandidates.count
        }
        let divisor = Double(queries.count)
        return (
            equal,
            Double(equal) / divisor * 100,
            Double(topologyUnion) / divisor * 100,
            Double(cubeUnion) / divisor * 100,
            Double(topologyCount) / divisor,
            Double(cubeCount) / divisor
        )
    }


    @inline(never)
    private static func terrainStorageChecksum(
        grid: IconNativeGrid,
        topology: [UInt32],
        elevationFile: any OmFileReaderArrayProtocol<Float>,
        queries: [TerrainQuery],
        useCubeCandidates: Bool
    ) async throws -> Int {
        if useCubeCandidates {
            var checksum = 0
            for item in queries {
                let result = try await grid.findPointTerrainOptimised(
                    lat: item.latitude,
                    lon: item.longitude,
                    elevation: item.elevation,
                    elevationFile: elevationFile
                )
                checksum &+= result?.gridpoint ?? -1
            }
            return checksum
        }
        var checksum = 0
        for item in queries {
            let query = IconNativeCenter(
                latitudeDegrees: Double(item.latitude),
                longitudeDegrees: IconNativeCenter.normalizedLongitude(item.longitude)
            )
            let seed = grid.storage.findNearestCell(
                latitude: item.latitude,
                longitude: item.longitude
            )!
            let candidates = topologyCandidates(seed: seed, topology: topology)

            let nearest = candidates.points[0]
            let nearestValues = try await elevationFile.read(
                range: [0..<1, UInt64(nearest)..<UInt64(nearest + 1)]
            )
            let nearestElevation = nearestValues[0]
            if nearestElevation.isFinite, nearestElevation > -999,
                abs(nearestElevation - item.elevation) <= 100 {
                checksum &+= nearest
                continue
            }

            let sorted = (1..<candidates.count).map {
                (gridpoint: candidates.points[$0], originalPosition: $0)
            }.sorted { $0.gridpoint < $1.gridpoint }
            var values = [Float](repeating: .nan, count: candidates.count)
            values[0] = nearestElevation
            var start = 0
            while start < sorted.count {
                var end = start
                while end + 1 < sorted.count,
                    sorted[end + 1].gridpoint == sorted[end].gridpoint + 1 {
                    end += 1
                }
                let lower = UInt64(sorted[start].gridpoint)
                let upper = UInt64(sorted[end].gridpoint + 1)
                let read = try await elevationFile.read(range: [0..<1, lower..<upper])
                for position in start...end {
                    values[sorted[position].originalPosition] = read[
                        sorted[position].gridpoint - sorted[start].gridpoint
                    ]
                }
                start = end + 1
            }

            var bestCell = -1
            var bestScore = Float.greatestFiniteMagnitude
            for position in 0..<candidates.count {
                let cell = candidates.points[position]
                let candidateElevation = values[position]
                if !candidateElevation.isFinite || candidateElevation <= -999 { continue }
                let dot = max(-1, min(1, grid.storage.centerVector(at: cell).dot(query)))
                let distanceKilometres = Float(acos(dot) * 6371.229)
                if distanceKilometres >= 50 { continue }
                let elevationDelta = candidateElevation >= 9999
                    ? 0
                    : abs(candidateElevation - item.elevation)
                let score = elevationDelta + distanceKilometres * 30
                if score < bestScore || (score == bestScore && (bestCell < 0 || cell < bestCell)) {
                    bestScore = score
                    bestCell = cell
                }
            }
            checksum &+= bestCell < 0 || bestScore > 1500 ? nearest : bestCell
        }
        return checksum
    }
}

private extension Data {
    func readUInt32(at offset: Int) -> UInt32 {
        withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self)) }
    }

    func readUInt64(at offset: Int) -> UInt64 {
        withUnsafeBytes { UInt64(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self)) }
    }

    func readFloat(at offset: Int) -> Float {
        Float(bitPattern: readUInt32(at: offset))
    }
}
