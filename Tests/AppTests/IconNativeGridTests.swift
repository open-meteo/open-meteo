import Foundation
@testable import App
import OmFileFormat
import Testing

@Suite struct IconNativeGridTests {
    @Test func coordinateRoundTripsUseNativeOrdering() throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid.loadMapped(data: fixture.data)

        #expect(grid.nx == fixture.centers.count)
        #expect(grid.ny == 1)
        #expect(grid.gridNumber == 26)
        #expect(grid.gridUUID == Array(0..<16))
        #expect(grid.gridSourceChecksum == Array(repeating: 26, count: 32))
        #expect(grid.gridBounds == GridBounds(lat_bounds: -90...90, lon_bounds: -180...180))

        for index in fixture.centers.indices {
            let coordinate = grid.getCoordinates(gridpoint: index)
            #expect(abs(coordinate.latitude - fixture.centers[index].latitude) < 1e-4)
            #expect(abs(coordinate.longitude - fixture.centers[index].longitude) < 1e-4)
            #expect(grid.findPoint(lat: coordinate.latitude, lon: coordinate.longitude) == index)
        }
    }

    @Test func lookupMatchesExhaustiveContainmentAndHasFixedCandidateBound() throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid.loadMapped(data: fixture.data)

        for latitude in stride(from: Float(-90), through: 90, by: 2.5) {
            for longitude in stride(from: Float(-180), to: 180, by: 2.5) {
                let expected = try #require(bruteForceContaining(
                    latitude: latitude,
                    longitude: longitude,
                    vertices: fixture.vertices,
                    vertexIndices: fixture.vertexIndices
                ))
                let result = try #require(grid.findPointWithCandidateCount(lat: latitude, lon: longitude))
                #expect(result.gridpoint == expected)
                #expect(result.candidateCount <= IconNativeGrid.maximumCandidateCount)
            }
        }
    }

    @Test func sharedEdgesPolesAndDatelineAreDeterministic() throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid.loadMapped(data: fixture.data)

        #expect(grid.findPoint(lat: 0, lon: -180) == grid.findPoint(lat: 0, lon: 180))
        #expect(grid.findPoint(lat: 12, lon: -179.999) == grid.findPoint(lat: 12, lon: 180.001))
        #expect(grid.findPoint(lat: 90, lon: -180) == grid.findPoint(lat: 90, lon: 123))
        #expect(grid.findPoint(lat: -90, lon: -123) == grid.findPoint(lat: -90, lon: 179))

        let sharedEdge = IconNativeGridPoint(latitude: 0, longitude: 45)
        let matching = matchingCells(point: sharedEdge, vertices: fixture.vertices, vertexIndices: fixture.vertexIndices)
        #expect(matching.count >= 2)
        #expect(grid.findPoint(lat: 0, lon: 45) == matching.min())

        #expect(grid.findPoint(lat: .nan, lon: 0) == nil)
        #expect(grid.findPoint(lat: 0, lon: .infinity) == nil)
        #expect(grid.findPoint(lat: 90.1, lon: 0) == nil)
    }

    @Test func regionalMeshRejectsPointsOutsideItsTriangles() throws {
        let vertices = [
            IconNativeGridPoint(latitude: 0, longitude: 0),
            IconNativeGridPoint(latitude: 0, longitude: 0.1),
            IconNativeGridPoint(latitude: 0.1, longitude: 0),
        ]
        let vertexIndices: [UInt32] = [0, 1, 2]
        let centers = triangleCenters(vertices: vertices, vertexIndices: vertexIndices)
        let bounds = GridBounds(lat_bounds: 0...0.1, lon_bounds: 0...0.1)
        let index = try IconNativeGridGenerator.makeSpatialIndex(
            vertices: vertices,
            vertexIndices: vertexIndices,
            isGlobal: false,
            bounds: bounds,
            initialStep: 0.04
        )
        let data = try IconNativeGridArtifact.make(
            metadata: makeMetadata(isGlobal: false, bounds: bounds, index: index),
            centers: centers,
            vertices: vertices,
            vertexIndices: vertexIndices,
            neighbourIndices: Array(repeating: IconNativeGrid.missingIndex, count: 3),
            binOffsets: index.offsets,
            binCells: index.cells
        )
        let grid = try IconNativeGrid.loadMapped(data: data)

        #expect(grid.findPoint(lat: 0.02, lon: 0.02) == 0)
        #expect(grid.findPoint(lat: 0.08, lon: 0.08) == nil)
        #expect(grid.findPoint(lat: -0.01, lon: 0.02) == nil)
        #expect(grid.findPoint(lat: 0.02, lon: 0.11) == nil)
    }

    @Test func nativeScaleHalfSpacesRejectOutsidePoints() {
        let triangle = IconNativeGridTriangle(
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
        let grid = try IconNativeGrid.loadMapped(data: makeGlobalFixture().data)
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
        #expect(grid.findPoint(lat: 45, lon: 45) == bruteForceContaining(
            latitude: 45,
            longitude: 45,
            vertices: fixture.vertices,
            vertexIndices: fixture.vertexIndices
        ))
    }

    @Test func terrainAndSeaSelectionFollowNativeTopology() async throws {
        let fixture = try makeRegionalFixture()
        let grid = try IconNativeGrid.loadMapped(data: fixture.data)
        let terrainFile = try await makeElevationFile([0, 500])
        let seaFile = try await makeElevationFile([100, -999])
        defer {
            try? FileManager.default.removeItem(atPath: terrainFile.path)
            try? FileManager.default.removeItem(atPath: seaFile.path)
        }

        let terrain = try #require(try await grid.findPointTerrainOptimised(
            lat: 0.04,
            lon: 0.04,
            elevation: 500,
            elevationFile: terrainFile.reader
        ))
        #expect(terrain.gridpoint == 1)
        if case .elevation(let value) = terrain.gridElevation {
            #expect(value == 500)
        } else {
            Issue.record("Expected topology-based terrain selection")
        }

        let sea = try #require(try await grid.findPointInSea(
            lat: 0.04,
            lon: 0.04,
            elevationFile: seaFile.reader
        ))
        #expect(sea.gridpoint == 1)
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
            _ = try IconNativeGrid.loadMapped(data: invalidMagic)
        }

        var invalidPayload = fixture.data
        invalidPayload[IconNativeGridArtifact.headerSize] ^= 0x01
        #expect(throws: IconNativeGridError.invalidChecksum) {
            _ = try IconNativeGrid.loadMapped(data: invalidPayload)
        }

        var invalidIdentity = fixture.data
        invalidIdentity[136] ^= 0x01
        #expect(throws: IconNativeGridError.invalidChecksum) {
            _ = try IconNativeGrid.loadMapped(data: invalidIdentity)
        }

        var truncated = fixture.data
        truncated.removeLast()
        #expect(throws: IconNativeGridError.invalidHeader) {
            _ = try IconNativeGrid.loadMapped(data: truncated)
        }
    }

    @Test func meshTopologyAndCsrInvariantsAreValidatedByTheWriter() throws {
        let fixture = try makeRegionalFixtureInputs()

        var invalidVertices = fixture.vertexIndices
        invalidVertices[0] = UInt32(fixture.vertices.count)
        #expect(throws: IconNativeGridError.invalidTriangle(0)) {
            _ = try makeArtifact(inputs: fixture, vertexIndices: invalidVertices)
        }

        var invalidNeighbours = fixture.neighbours
        invalidNeighbours[0] = 0
        #expect(throws: IconNativeGridError.invalidNeighbour(cell: 0, neighbour: 0)) {
            _ = try makeArtifact(inputs: fixture, neighbours: invalidNeighbours)
        }

        var invalidCells = fixture.index.cells
        invalidCells[0] = UInt32(fixture.centers.count)
        #expect(throws: IconNativeGridError.invalidBinCell(bin: 0, cell: UInt32(fixture.centers.count))) {
            _ = try makeArtifact(inputs: fixture, binCells: invalidCells)
        }
    }

    @Test func spatialIndexRejectsAnUnboundedCandidateBin() throws {
        let vertices = [
            IconNativeGridPoint(latitude: 0, longitude: 0),
            IconNativeGridPoint(latitude: 0, longitude: 0.01),
            IconNativeGridPoint(latitude: 0.01, longitude: 0),
        ]
        let vertexIndices = Array(repeating: [UInt32(0), UInt32(1), UInt32(2)], count: 129).flatMap { $0 }
        do {
            _ = try IconNativeGridGenerator.makeSpatialIndex(
                vertices: vertices,
                vertexIndices: vertexIndices,
                isGlobal: false,
                bounds: GridBounds(lat_bounds: 0...0.01, lon_bounds: 0...0.01),
                initialStep: 0.02
            )
            Issue.record("Expected the per-bin candidate bound to fail")
        } catch IconNativeGridError.candidateLimit {
            // Expected.
        }
    }

    @Test func concurrentLookupsAreStable() async throws {
        let fixture = try makeGlobalFixture()
        let grid = try IconNativeGrid.loadMapped(data: fixture.data)
        let expected = (0..<360).map { offset in
            bruteForceContaining(
                latitude: 37.5,
                longitude: Float(offset) - 179.75,
                vertices: fixture.vertices,
                vertexIndices: fixture.vertexIndices
            )
        }

        let correct = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for task in 0..<16 {
                group.addTask {
                    for offset in 0..<360 {
                        let longitude = Float(offset) - 179.75 + Float(task) * 0.0001
                        if grid.findPoint(lat: 37.5, lon: longitude) != expected[offset] { return false }
                    }
                    return true
                }
            }
            for await value in group where !value { return false }
            return true
        }
        #expect(correct)
    }

    @Test func officialD2TriangleInteriorsPreserveNativeIndices() throws {
        guard let sourceFile = ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"] else {
            return
        }
        let source = try IconNativeGridGenerator.readSource(file: sourceFile, identity: .d2)
        let data = try IconNativeGridGenerator.generate(sourceFile: sourceFile, identity: .d2)
        let grid = try IconNativeGrid.loadMapped(data: data)

        #expect(grid.nx == IconNativeGridIdentity.d2.cellCount)
        #expect(data.count <= 64 * 1_024 * 1_024)
        for cell in source.centers.indices {
            let coordinate = grid.getCoordinates(gridpoint: cell)
            #expect(abs(coordinate.latitude - source.centers[cell].latitude) < 1e-4)
            #expect(abs(coordinate.longitude - source.centers[cell].longitude) < 1e-4)

            let offset = cell * 3
            let a = source.vertices[Int(source.vertexIndices[offset])]
            let b = source.vertices[Int(source.vertexIndices[offset + 1])]
            let c = source.vertices[Int(source.vertexIndices[offset + 2])]
            let x = a.x + b.x + c.x
            let y = a.y + b.y + c.y
            let z = a.z + b.z + c.z
            let length = sqrt(x * x + y * y + z * z)
            let interior = IconNativeGridPoint(x: x / length, y: y / length, z: z / length)
            let actual = grid.findPoint(lat: interior.latitude, lon: interior.longitude)
            if actual != cell {
                Issue.record("Official ICON-D2 triangle interior \(cell) resolved to \(String(describing: actual))")
                return
            }
        }
    }
}

private struct IconNativeGridFixture {
    let data: Data
    let centers: [IconNativeGridPoint]
    let vertices: [IconNativeGridPoint]
    let vertexIndices: [UInt32]
}

private struct IconNativeGridFixtureInputs {
    let metadata: IconNativeGridArtifact.Metadata
    let centers: [IconNativeGridPoint]
    let vertices: [IconNativeGridPoint]
    let vertexIndices: [UInt32]
    let neighbours: [UInt32]
    let index: IconNativeGridGenerator.SpatialIndex
}

private struct IconNativeGridElevationFile {
    let path: String
    let reader: OmFileReaderArray<FileHandleWithCount, Float>
}

private func makeElevationFile(_ elevations: [Float]) async throws -> IconNativeGridElevationFile {
    let path = FileManager.default.temporaryDirectory
        .appendingPathComponent("icon-native-elevation-\(UUID().uuidString).om").path
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
    let vertices = [
        IconNativeGridPoint(x: 0, y: 0, z: 1),
        IconNativeGridPoint(x: 0, y: 0, z: -1),
        IconNativeGridPoint(x: 1, y: 0, z: 0),
        IconNativeGridPoint(x: 0, y: 1, z: 0),
        IconNativeGridPoint(x: -1, y: 0, z: 0),
        IconNativeGridPoint(x: 0, y: -1, z: 0),
    ]
    let vertexIndices: [UInt32] = [
        0, 2, 3, 0, 3, 4, 0, 4, 5, 0, 5, 2,
        1, 3, 2, 1, 4, 3, 1, 5, 4, 1, 2, 5,
    ]
    let centers = triangleCenters(vertices: vertices, vertexIndices: vertexIndices)
    let neighbours = makeNeighbours(vertexIndices: vertexIndices)
    let bounds = GridBounds(lat_bounds: -90...90, lon_bounds: -180...180)
    let index = try IconNativeGridGenerator.makeSpatialIndex(
        vertices: vertices,
        vertexIndices: vertexIndices,
        isGlobal: true,
        bounds: bounds,
        initialStep: 45
    )
    let metadata = makeMetadata(isGlobal: true, bounds: bounds, index: index)
    let data = try IconNativeGridArtifact.make(
        metadata: metadata,
        centers: centers,
        vertices: vertices,
        vertexIndices: vertexIndices,
        neighbourIndices: neighbours,
        binOffsets: index.offsets,
        binCells: index.cells
    )
    return IconNativeGridFixture(data: data, centers: centers, vertices: vertices, vertexIndices: vertexIndices)
}

private func makeRegionalFixture() throws -> IconNativeGridFixture {
    let inputs = try makeRegionalFixtureInputs()
    return IconNativeGridFixture(
        data: try makeArtifact(inputs: inputs),
        centers: inputs.centers,
        vertices: inputs.vertices,
        vertexIndices: inputs.vertexIndices
    )
}

private func makeRegionalFixtureInputs() throws -> IconNativeGridFixtureInputs {
    let vertices = [
        IconNativeGridPoint(latitude: 0, longitude: 0),
        IconNativeGridPoint(latitude: 0, longitude: 0.1),
        IconNativeGridPoint(latitude: 0.1, longitude: 0),
        IconNativeGridPoint(latitude: 0.1, longitude: 0.1),
    ]
    let vertexIndices: [UInt32] = [0, 1, 2, 1, 3, 2]
    let centers = triangleCenters(vertices: vertices, vertexIndices: vertexIndices)
    let neighbours: [UInt32] = [
        1, IconNativeGrid.missingIndex, IconNativeGrid.missingIndex,
        0, IconNativeGrid.missingIndex, IconNativeGrid.missingIndex,
    ]
    let bounds = GridBounds(lat_bounds: 0...0.1, lon_bounds: 0...0.1)
    let index = try IconNativeGridGenerator.makeSpatialIndex(
        vertices: vertices,
        vertexIndices: vertexIndices,
        isGlobal: false,
        bounds: bounds,
        initialStep: 0.04
    )
    return IconNativeGridFixtureInputs(
        metadata: makeMetadata(isGlobal: false, bounds: bounds, index: index),
        centers: centers,
        vertices: vertices,
        vertexIndices: vertexIndices,
        neighbours: neighbours,
        index: index
    )
}

private func makeMetadata(
    isGlobal: Bool,
    bounds: GridBounds,
    index: IconNativeGridGenerator.SpatialIndex
) -> IconNativeGridArtifact.Metadata {
    IconNativeGridArtifact.Metadata(
        gridNumber: isGlobal ? 26 : 47,
        gridUUID: isGlobal ? Array(0..<16) : Array(repeating: 47, count: 16),
        sourceChecksum: Array(repeating: isGlobal ? 26 : 47, count: 32),
        isGlobal: isGlobal,
        bounds: bounds,
        binNx: index.nx,
        binNy: index.ny,
        binLatMin: index.latitudeMinimum,
        binLonMin: index.longitudeMinimum,
        binDx: index.dx,
        binDy: index.dy
    )
}

private func makeArtifact(
    inputs: IconNativeGridFixtureInputs,
    vertexIndices: [UInt32]? = nil,
    neighbours: [UInt32]? = nil,
    binCells: [UInt32]? = nil
) throws -> Data {
    try IconNativeGridArtifact.make(
        metadata: inputs.metadata,
        centers: inputs.centers,
        vertices: inputs.vertices,
        vertexIndices: vertexIndices ?? inputs.vertexIndices,
        neighbourIndices: neighbours ?? inputs.neighbours,
        binOffsets: inputs.index.offsets,
        binCells: binCells ?? inputs.index.cells
    )
}

private func triangleCenters(vertices: [IconNativeGridPoint], vertexIndices: [UInt32]) -> [IconNativeGridPoint] {
    (0..<(vertexIndices.count / 3)).map { cell in
        let a = vertices[Int(vertexIndices[cell * 3])]
        let b = vertices[Int(vertexIndices[cell * 3 + 1])]
        let c = vertices[Int(vertexIndices[cell * 3 + 2])]
        let x = a.x + b.x + c.x
        let y = a.y + b.y + c.y
        let z = a.z + b.z + c.z
        let length = sqrt(x * x + y * y + z * z)
        return IconNativeGridPoint(x: x / length, y: y / length, z: z / length)
    }
}

private func makeNeighbours(vertexIndices: [UInt32]) -> [UInt32] {
    let cellCount = vertexIndices.count / 3
    var neighbours = [UInt32](repeating: IconNativeGrid.missingIndex, count: cellCount * 3)
    for cell in 0..<cellCount {
        let vertices = Set(vertexIndices[(cell * 3)..<(cell * 3 + 3)])
        var position = 0
        for other in 0..<cellCount where other != cell {
            let otherVertices = Set(vertexIndices[(other * 3)..<(other * 3 + 3)])
            if vertices.intersection(otherVertices).count == 2 {
                neighbours[cell * 3 + position] = UInt32(other)
                position += 1
            }
        }
    }
    return neighbours
}

private func bruteForceContaining(
    latitude: Float,
    longitude: Float,
    vertices: [IconNativeGridPoint],
    vertexIndices: [UInt32]
) -> Int? {
    matchingCells(
        point: IconNativeGridPoint(latitude: latitude, longitude: longitude),
        vertices: vertices,
        vertexIndices: vertexIndices
    ).min()
}

private func matchingCells(
    point: IconNativeGridPoint,
    vertices: [IconNativeGridPoint],
    vertexIndices: [UInt32]
) -> [Int] {
    (0..<(vertexIndices.count / 3)).filter { cell in
        IconNativeGridTriangle(
            a: vertices[Int(vertexIndices[cell * 3])],
            b: vertices[Int(vertexIndices[cell * 3 + 1])],
            c: vertices[Int(vertexIndices[cell * 3 + 2])]
        ).contains(point)
    }
}
