import Foundation
@testable import App
import OmFileFormat
import Testing

@Suite struct IconNativeGridTests {
    @Test func coordinateRoundTripsUseNativeOrdering() throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid(data: fixture.data)

        #expect(grid.nx == 8)
        #expect(grid.ny == 1)
        #expect(grid.gridNumber == 26)
        #expect(grid.gridUUID == Array(0..<16))
        #expect(grid.gridSourceChecksum == Array(repeating: 26, count: 32))
        #expect(grid.gridBounds == GridBounds(lat_bounds: -90...90, lon_bounds: -180...180))

        for index in fixture.centers.indices {
            let coordinate = grid.getCoordinates(gridpoint: index)
            #expect(grid.findPoint(lat: coordinate.latitude, lon: coordinate.longitude) == index)
        }
    }

    @Test func lookupMatchesBruteForceAndHasFixedCandidateBound() throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid(data: fixture.data)

        for latitude in stride(from: Float(-90), through: 90, by: 2.5) {
            for longitude in stride(from: Float(-180), to: 180, by: 2.5) {
                let expected = bruteForce(latitude: latitude, longitude: longitude, centers: fixture.centers)
                let result = try #require(grid.findPointWithCandidateCount(lat: latitude, lon: longitude))
                #expect(result.gridpoint == expected)
                #expect(result.candidateCount <= IconNativeGrid.maximumCandidateCount)
            }
        }
    }

    @Test func polesDatelineAndInvalidCoordinatesAreDeterministic() throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid(data: fixture.data)

        #expect(grid.findPoint(lat: 0, lon: -180) == grid.findPoint(lat: 0, lon: 180))
        #expect(grid.findPoint(lat: 12, lon: -179.999) == grid.findPoint(lat: 12, lon: 180.001))
        #expect(grid.findPoint(lat: 90, lon: -180) == bruteForce(latitude: 90, longitude: -180, centers: fixture.centers))
        #expect(grid.findPoint(lat: -90, lon: 179.9) == bruteForce(latitude: -90, longitude: 179.9, centers: fixture.centers))
        #expect(grid.findPoint(lat: 90, lon: -180) == grid.findPoint(lat: 90, lon: 123))
        #expect(grid.findPoint(lat: -90, lon: -123) == grid.findPoint(lat: -90, lon: 179))
        #expect(grid.findPoint(lat: .nan, lon: 0) == nil)
        #expect(grid.findPoint(lat: 0, lon: .infinity) == nil)
        #expect(grid.findPoint(lat: 90.1, lon: 0) == nil)
    }

    @Test func regionalBoundaryTrianglesRejectPointsOutsideTheDomain() throws {
        let triangle = IconNativeGridBoundaryTriangle(
            a: IconNativeGridPoint(latitude: 0, longitude: 0),
            b: IconNativeGridPoint(latitude: 0, longitude: 10),
            c: IconNativeGridPoint(latitude: 10, longitude: 0)
        )
        let center = IconNativeGridPoint(latitude: 3.33, longitude: 3.33)
        let data = try IconNativeGridArtifact.make(
            metadata: .init(
                gridNumber: 47,
                gridUUID: Array(repeating: 47, count: 16),
                sourceChecksum: Array(repeating: 47, count: 32),
                isGlobal: false,
                bounds: GridBounds(lat_bounds: 0...10, lon_bounds: 0...10),
                seedNx: 1,
                seedNy: 1,
                seedLatMin: 0,
                seedLonMin: 0,
                seedDx: 10,
                seedDy: 10
            ),
            centers: [center],
            neighbours: [[IconNativeGrid.missingIndex, IconNativeGrid.missingIndex, IconNativeGrid.missingIndex]],
            seeds: [0],
            coverage: [2],
            boundaryOffsets: [0, 1],
            boundaryTriangles: [triangle]
        )
        let grid = try IconNativeGrid(data: data)

        #expect(grid.findPoint(lat: 2, lon: 2) == 0)
        #expect(grid.findPoint(lat: 8, lon: 8) == nil)
        #expect(grid.findPoint(lat: -0.1, lon: 2) == nil)
        #expect(grid.findPoint(lat: 2, lon: 10.1) == nil)
    }

    @Test func nativeScaleBoundaryHalfSpacesDoNotHideOutsidePoints() {
        let triangle = IconNativeGridBoundaryTriangle(
            a: IconNativeGridPoint(latitude: 50, longitude: 10),
            b: IconNativeGridPoint(latitude: 50, longitude: 10.02),
            c: IconNativeGridPoint(latitude: 50.02, longitude: 10)
        )

        #expect(triangle.contains(IconNativeGridPoint(latitude: 50.005, longitude: 10.005)))
        #expect(!triangle.contains(IconNativeGridPoint(latitude: 50.02, longitude: 10.02)))
        #expect(!triangle.contains(IconNativeGridPoint(latitude: 50.1, longitude: 10.1)))
        #expect(!triangle.contains(IconNativeGridPoint(latitude: 51, longitude: 11)))
    }

    @Test func unsupportedRectangularOperationsReturnNil() throws {
        let grid = try IconNativeGrid(data: makeGlobalFixture().data)
        let boundingBox = BoundingBoxWGS84(latitude: 40..<50, longitude: 0..<10)

        #expect(grid.findPointInterpolated(lat: 45, lon: 5) == nil)
        #expect(grid.findBox(boundingBox: boundingBox) == nil)
        #expect(grid.estimatedNumberOfGridCells(boundingBox: boundingBox) == nil)
    }

    @Test func fileBackedArtifactUsesTheSameValidatedPath() throws {
        let fixture = try makeGlobalFixture()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("icon-native-\(UUID().uuidString).grid")
        try fixture.data.write(to: file, options: .atomic)
        defer { try? FileManager.default.removeItem(at: file) }

        let grid = try IconNativeGrid(file: file)
        #expect(grid.findPoint(lat: 45, lon: 45) == bruteForce(latitude: 45, longitude: 45, centers: fixture.centers))
    }

    @Test func terrainAndSeaSelectionFollowTopologyInsteadOfStorageOrder() async throws {
        let centers = [
            IconNativeGridPoint(latitude: 0, longitude: 0),
            IconNativeGridPoint(latitude: 0.8, longitude: 0.8),
            IconNativeGridPoint(latitude: -0.8, longitude: -0.8),
            IconNativeGridPoint(latitude: 0, longitude: 0.2),
            IconNativeGridPoint(latitude: 0, longitude: 0.1),
        ]
        let missing = IconNativeGrid.missingIndex
        let neighbours: [[UInt32]] = [
            [4, 1, 2],
            [0, missing, missing],
            [0, missing, missing],
            [4, missing, missing],
            [0, 3, missing],
        ]
        let data = try IconNativeGridArtifact.make(
            metadata: .init(
                gridNumber: 47,
                gridUUID: Array(repeating: 47, count: 16),
                sourceChecksum: Array(repeating: 47, count: 32),
                isGlobal: false,
                bounds: GridBounds(lat_bounds: -1...1, lon_bounds: -1...1),
                seedNx: 1,
                seedNy: 1,
                seedLatMin: -1,
                seedLonMin: -1,
                seedDx: 2,
                seedDy: 2
            ),
            centers: centers,
            neighbours: neighbours,
            seeds: [0]
        )
        let grid = try IconNativeGrid(data: data)
        let terrainFile = try await makeElevationFile([0, 100, 100, 100, 500])
        let seaFile = try await makeElevationFile([100, 100, 100, 100, -999])
        defer {
            try? FileManager.default.removeItem(atPath: terrainFile.path)
            try? FileManager.default.removeItem(atPath: seaFile.path)
        }

        let terrain = try #require(try await grid.findPointTerrainOptimised(
            lat: 0,
            lon: 0,
            elevation: 500,
            elevationFile: terrainFile.reader
        ))
        #expect(terrain.gridpoint == 4)
        if case .elevation(let value) = terrain.gridElevation {
            #expect(value == 500)
        } else {
            Issue.record("Expected topology-based terrain selection")
        }

        let sea = try #require(try await grid.findPointInSea(lat: 0, lon: 0, elevationFile: seaFile.reader))
        #expect(sea.gridpoint == 4)
        if case .sea = sea.gridElevation {
            // Expected.
        } else {
            Issue.record("Expected topology-based sea selection")
        }
    }

    @Test func corruptArtifactsFailBeforeLookup() throws {
        let fixture = try makeGlobalFixture()

        var invalidMagic = fixture.data
        invalidMagic[0] ^= 0xff
        #expect(throws: IconNativeGridError.invalidMagic) {
            _ = try IconNativeGrid(data: invalidMagic)
        }

        var invalidPayload = fixture.data
        invalidPayload[IconNativeGridArtifact.headerSize] ^= 0x01
        #expect(throws: IconNativeGridError.invalidChecksum) {
            _ = try IconNativeGrid(data: invalidPayload)
        }

        var invalidIdentity = fixture.data
        invalidIdentity[136] ^= 0x01
        #expect(throws: IconNativeGridError.invalidChecksum) {
            _ = try IconNativeGrid(data: invalidIdentity)
        }

        var truncated = fixture.data
        truncated.removeLast()
        #expect(throws: IconNativeGridError.invalidHeader) {
            _ = try IconNativeGrid(data: truncated)
        }
    }

    @Test func topologyAndSeedInvariantsAreValidatedByTheWriter() throws {
        let fixture = try makeGlobalFixtureInputs()
        var invalidNeighbours = fixture.neighbours
        invalidNeighbours[0][0] = 0
        #expect(throws: IconNativeGridError.invalidNeighbour(cell: 0, neighbour: 0)) {
            _ = try IconNativeGridArtifact.make(
                metadata: fixture.metadata,
                centers: fixture.centers,
                neighbours: invalidNeighbours,
                seeds: fixture.seeds
            )
        }

        var asymmetricNeighbours = fixture.neighbours
        let neighbour = Int(asymmetricNeighbours[0][0])
        let reciprocalPosition = try #require(asymmetricNeighbours[neighbour].firstIndex(of: 0))
        asymmetricNeighbours[neighbour][reciprocalPosition] = IconNativeGrid.missingIndex
        #expect(throws: IconNativeGridError.asymmetricNeighbour(cell: 0, neighbour: neighbour)) {
            _ = try IconNativeGridArtifact.make(
                metadata: fixture.metadata,
                centers: fixture.centers,
                neighbours: asymmetricNeighbours,
                seeds: fixture.seeds
            )
        }

        var invalidSeeds = fixture.seeds
        invalidSeeds[0] = UInt32(fixture.centers.count)
        #expect(throws: IconNativeGridError.invalidSeed(bin: 0, seed: UInt32(fixture.centers.count))) {
            _ = try IconNativeGridArtifact.make(
                metadata: fixture.metadata,
                centers: fixture.centers,
                neighbours: fixture.neighbours,
                seeds: invalidSeeds
            )
        }
    }

    @Test func artifactWriterRejectsAnUnprovenSeed() throws {
        let fixture = try makeGlobalFixtureInputs()
        var seeds = fixture.seeds
        seeds[0] ^= 7

        do {
            _ = try IconNativeGridArtifact.make(
                metadata: fixture.metadata,
                centers: fixture.centers,
                neighbours: fixture.neighbours,
                seeds: seeds
            )
            Issue.record("Expected the d1 + 2r seed proof to fail")
        } catch IconNativeGridError.seedProofFailed(let bin, _) {
            #expect(bin == 0)
        }
    }

    @Test func concurrentLookupsAreStable() async throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid(data: fixture.data)
        let expected = (0..<360).map { offset in
            let longitude = Float(offset) - 179.75
            return bruteForce(latitude: 37.5, longitude: longitude, centers: fixture.centers)
        }

        let correct = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for task in 0..<16 {
                group.addTask {
                    for offset in 0..<360 {
                        let longitude = Float(offset) - 179.75 + Float(task) * 0.0001
                        if grid.findPoint(lat: 37.5, lon: longitude) != expected[offset] {
                            return false
                        }
                    }
                    return true
                }
            }
            for await value in group where !value {
                return false
            }
            return true
        }
        #expect(correct)
    }
}

private struct IconNativeGridFixture {
    let data: Data
    let centers: [IconNativeGridPoint]
}

private struct IconNativeGridFixtureInputs {
    let metadata: IconNativeGridArtifact.Metadata
    let centers: [IconNativeGridPoint]
    let neighbours: [[UInt32]]
    let seeds: [UInt32]
}

private struct IconNativeGridElevationFile {
    let path: String
    let reader: OmFileReaderArray<FileHandleWithCount, Float>
}

private func makeElevationFile(_ elevations: [Float]) async throws -> IconNativeGridElevationFile {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("icon-native-elevation-\(UUID().uuidString).om")
        .path
    try elevations.writeOmFile(
        file: path,
        dimensions: [1, elevations.count],
        chunks: [1, elevations.count],
        compression: .pfor_delta2d_int16,
        scalefactor: 1
    )
    let reader = try await OmFileReader(file: path).expectArray(of: Float.self)
    return IconNativeGridElevationFile(path: path, reader: reader)
}

private func makeGlobalFixture() throws -> IconNativeGridFixture {
    let inputs = try makeGlobalFixtureInputs()
    return IconNativeGridFixture(
        data: try IconNativeGridArtifact.make(
            metadata: inputs.metadata,
            centers: inputs.centers,
            neighbours: inputs.neighbours,
            seeds: inputs.seeds
        ),
        centers: inputs.centers
    )
}

private func makeGlobalFixtureInputs() throws -> IconNativeGridFixtureInputs {
    let inverseSquareRootOfThree = Float(1 / sqrt(3.0))
    let centers = (0..<8).map { index in
        IconNativeGridPoint(
            x: (index & 1) == 0 ? -inverseSquareRootOfThree : inverseSquareRootOfThree,
            y: (index & 2) == 0 ? -inverseSquareRootOfThree : inverseSquareRootOfThree,
            z: (index & 4) == 0 ? -inverseSquareRootOfThree : inverseSquareRootOfThree
        )
    }
    var neighbours = [[UInt32]]()
    for index in 0..<8 {
        let first = UInt32(index ^ 1)
        let second = UInt32(index ^ 2)
        let third = UInt32(index ^ 4)
        neighbours.append([first, second, third])
    }
    let metadata = IconNativeGridArtifact.Metadata(
        gridNumber: 26,
        gridUUID: Array(0..<16),
        sourceChecksum: Array(repeating: 26, count: 32),
        isGlobal: true,
        bounds: GridBounds(lat_bounds: -90...90, lon_bounds: -180...180),
        seedNx: 8,
        seedNy: 4,
        seedLatMin: -90,
        seedLonMin: -180,
        seedDx: 45,
        seedDy: 45
    )
    var seeds = [UInt32]()
    for y in 0..<metadata.seedNy {
        for x in 0..<metadata.seedNx {
            let latitude = metadata.seedLatMin + (Float(y) + 0.5) * metadata.seedDy
            let longitude = metadata.seedLonMin + (Float(x) + 0.5) * metadata.seedDx
            seeds.append(UInt32(bruteForce(latitude: latitude, longitude: longitude, centers: centers)))
        }
    }
    return IconNativeGridFixtureInputs(metadata: metadata, centers: centers, neighbours: neighbours, seeds: seeds)
}

private func bruteForce(latitude: Float, longitude: Float, centers: [IconNativeGridPoint]) -> Int {
    let point = IconNativeGridPoint(latitude: latitude, longitude: longitude)
    var bestIndex = 0
    var bestDot = -Float.greatestFiniteMagnitude
    for index in centers.indices {
        let dot = centers[index].dot(point)
        if dot > bestDot || (dot == bestDot && index < bestIndex) {
            bestDot = dot
            bestIndex = index
        }
    }
    return bestIndex
}
