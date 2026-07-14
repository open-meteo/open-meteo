import Foundation
@testable import App
import OmFileFormat
import Testing

@Suite struct IconNativeGridTests {
    @Test func coordinateRoundTripsUseNativeOrdering() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)

        #expect(grid.nx == fixture.centers.count)
        #expect(grid.ny == 1)
        #expect(grid.gridNumber == 26)
        #expect(grid.gridUUID == Array(0..<16))

        for index in fixture.centers.indices {
            let coordinate = grid.getCoordinates(gridpoint: index)
            #expect(abs(coordinate.latitude - fixture.centers[index].latitude) < 1e-4)
            #expect(abs(coordinate.longitude - fixture.centers[index].longitude) < 1e-4)
            #expect(grid.findPoint(lat: coordinate.latitude, lon: coordinate.longitude) == index)
        }
    }

    @Test func lookupMatchesExhaustiveContainmentAndHasFixedCandidateBound() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)

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
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)

        #expect(grid.findPoint(lat: 0, lon: -180) == grid.findPoint(lat: 0, lon: 180))
        #expect(grid.findPoint(lat: 12, lon: -179.999) == grid.findPoint(lat: 12, lon: 180.001))
        #expect(grid.findPoint(lat: 90, lon: -180) == grid.findPoint(lat: 90, lon: 123))
        #expect(grid.findPoint(lat: -90, lon: -123) == grid.findPoint(lat: -90, lon: 179))

        let sharedEdge = SphericalPoint(latitude: 0, longitude: 45)
        let matching = matchingCells(point: sharedEdge, vertices: fixture.vertices, vertexIndices: fixture.vertexIndices)
        #expect(matching.count >= 2)
        #expect(grid.findPoint(lat: 0, lon: 45) == matching.min())

        #expect(grid.findPoint(lat: .nan, lon: 0) == nil)
        #expect(grid.findPoint(lat: 0, lon: .infinity) == nil)
        #expect(grid.findPoint(lat: 90.1, lon: 0) == nil)
    }

    @Test func regionalMeshRejectsPointsOutsideItsTriangles() throws {
        let vertices = [
            SphericalPoint(latitude: 0, longitude: 0),
            SphericalPoint(latitude: 0, longitude: 0.1),
            SphericalPoint(latitude: 0.1, longitude: 0),
        ]
        let vertexIndices: [UInt32] = [0, 1, 2]
        let centers = triangleCenters(vertices: vertices, vertexIndices: vertexIndices)
        let bounds = GridBounds(lat_bounds: 0...0.1, lon_bounds: 0...0.1)
        let index = try IconNativeGridGenerator.makeSpatialIndex(
            vertices: vertices,
            vertexIndices: vertexIndices,
            isGlobal: false,
            bounds: bounds,
            step: 0.04
        )
        let file = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: file) }
        try IconNativeGridArtifact.write(
            to: file.path,
            metadata: makeMetadata(isGlobal: false, bounds: bounds, index: index),
            centers: centers,
            vertices: vertices,
            vertexIndices: vertexIndices,
            neighbourIndices: Array(repeating: IconNativeGrid.missingIndex, count: 3),
            binOffsets: index.offsets,
            binCells: index.cells
        )
        let grid = try IconNativeGrid.load(file: file)

        #expect(grid.findPoint(lat: 0.02, lon: 0.02) == 0)
        #expect(grid.findPoint(lat: 0.08, lon: 0.08) == nil)
        #expect(grid.findPoint(lat: -0.01, lon: 0.02) == nil)
        #expect(grid.findPoint(lat: 0.02, lon: 0.11) == nil)
    }

    @Test func nativeScaleHalfSpacesRejectOutsidePoints() {
        let triangle = SphericalTriangle(
            a: SphericalPoint(latitude: 50, longitude: 10),
            b: SphericalPoint(latitude: 50, longitude: 10.02),
            c: SphericalPoint(latitude: 50.02, longitude: 10)
        )

        #expect(triangle.contains(SphericalPoint(latitude: 50.005, longitude: 10.005)))
        #expect(!triangle.contains(SphericalPoint(latitude: 50.02, longitude: 10.02)))
        #expect(!triangle.contains(SphericalPoint(latitude: 50.1, longitude: 10.1)))
        #expect(!triangle.contains(SphericalPoint(latitude: 51, longitude: 11)))
    }

    @Test func validatedStagingMappingSurvivesAtomicPublication() throws {
        let fixture = try makeGlobalFixture()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("icon-native-publication-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let staged = directory.appendingPathComponent("grid.bin~")
        let published = directory.appendingPathComponent("grid.bin")
        try FileManager.default.moveFileOverwrite(from: fixture.file.path, to: staged.path)

        let grid = try IconNativeGrid.load(file: staged)
        try FileManager.default.moveFileOverwrite(from: staged.path, to: published.path)

        #expect(!FileManager.default.fileExists(atPath: staged.path))
        #expect(FileManager.default.fileExists(atPath: published.path))
        #expect(grid.findPoint(lat: 45, lon: 45) != nil)
        #expect(grid.gridNumber == 26)
    }

    @Test func cacheSingleFlightsAndPinsSuccessfulStorage() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let identity = makeIdentity(for: fixture)
        let cache = IconNativeGridCache(file: fixture.file.path, identity: identity)

        let storageIdentifiers = try await withThrowingTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    let grid = try cache.get()
                    return ObjectIdentifier(grid.storage)
                }
            }
            var identifiers = [ObjectIdentifier]()
            for try await identifier in group { identifiers.append(identifier) }
            return identifiers
        }
        #expect(Set(storageIdentifiers).count == 1)

        let replacement = try makeGlobalFixture()
        try FileManager.default.moveFileOverwrite(from: replacement.file.path, to: fixture.file.path)
        let pinned = try cache.get()
        #expect(ObjectIdentifier(pinned.storage) == storageIdentifiers[0])
    }

    @Test func cachedMissingArtifactBecomesAvailableAfterPublication() throws {
        let fixture = try makeGlobalFixture()
        let published = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: published) }
        let identity = makeIdentity(for: fixture)
        let cache = IconNativeGridCache(file: published.path, identity: identity)

        #expect(throws: IconNativeDomainError.missingGridArtifact(published.path)) {
            _ = try cache.get()
        }
        try FileManager.default.moveFileOverwrite(from: fixture.file.path, to: published.path)
        cache.install(try IconNativeGrid.load(file: published))
        let grid = try cache.get()
        #expect(grid.nx == fixture.centers.count)
    }

    @Test func failedCacheRetriesWhenArtifactFingerprintChanges() throws {
        let fixture = try makeGlobalFixture()
        let published = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: published) }
        let cache = IconNativeGridCache(
            file: published.path,
            identity: makeIdentity(for: fixture),
            retryInterval: .zero
        )

        #expect(throws: IconNativeDomainError.missingGridArtifact(published.path)) {
            _ = try cache.get()
        }
        try FileManager.default.moveFileOverwrite(from: fixture.file.path, to: published.path)
        #expect(try cache.get().nx == fixture.centers.count)
    }

    @Test func downloaderValidationInspectsDiskWithoutReplacingPinnedStorage() throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let cache = IconNativeGridCache(file: fixture.file.path, identity: makeIdentity(for: fixture))
        let pinned = try cache.get()
        var invalid = try Data(contentsOf: fixture.file)
        invalid[0] ^= 0xff
        try invalid.write(to: fixture.file)

        #expect(throws: IconNativeDomainError.self) {
            try cache.validateFileAndInstall()
        }
        #expect(ObjectIdentifier(try cache.get().storage) == ObjectIdentifier(pinned.storage))
    }

    @Test func terrainAndSeaSelectionFollowNativeTopology() async throws {
        let fixture = try makeRegionalFixture()
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)
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
        defer { fixture.remove() }
        let data = try Data(contentsOf: fixture.file)

        var invalidMagic = data
        invalidMagic[0] ^= 0xff
        let invalidMagicFile = try writeTemporaryData(invalidMagic)
        defer { try? FileManager.default.removeItem(at: invalidMagicFile) }
        #expect(throws: IconNativeGridError.invalidMagic) {
            _ = try IconNativeGrid.load(file: invalidMagicFile)
        }

        var invalidPayload = data
        invalidPayload[IconNativeGridArtifact.headerSize] ^= 0x01
        let invalidPayloadFile = try writeTemporaryData(invalidPayload)
        defer { try? FileManager.default.removeItem(at: invalidPayloadFile) }
        #expect(throws: IconNativeGridError.invalidChecksum) {
            _ = try IconNativeGrid.load(file: invalidPayloadFile)
        }

        var invalidIdentity = data
        invalidIdentity[136] ^= 0x01
        let invalidIdentityFile = try writeTemporaryData(invalidIdentity)
        defer { try? FileManager.default.removeItem(at: invalidIdentityFile) }
        #expect(throws: IconNativeGridError.invalidChecksum) {
            _ = try IconNativeGrid.load(file: invalidIdentityFile)
        }

        var truncated = data
        truncated.removeLast()
        let truncatedFile = try writeTemporaryData(truncated)
        defer { try? FileManager.default.removeItem(at: truncatedFile) }
        #expect(throws: IconNativeGridError.invalidHeader) {
            _ = try IconNativeGrid.load(file: truncatedFile)
        }
    }

    @Test func artifactSizeBudgetIsCheckedBeforeWriting() throws {
        let fixture = try makeRegionalFixtureInputs()
        let file = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            try IconNativeGridArtifact.write(
                to: file.path,
                metadata: fixture.metadata,
                centers: fixture.centers,
                vertices: fixture.vertices,
                vertexIndices: fixture.vertexIndices,
                neighbourIndices: fixture.neighbours,
                binOffsets: fixture.index.offsets,
                binCells: fixture.index.cells,
                maximumFileSize: 1
            )
            Issue.record("Expected artifact size budget failure")
        } catch IconNativeGridError.artifactTooLarge {
            #expect(!FileManager.default.fileExists(atPath: file.path))
        }
    }

    @Test func invalidNetcdfErrorsStayInTheSourceErrorDomain() throws {
        let file = try writeTemporaryData(Data("not a NetCDF file".utf8))
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            _ = try IconNativeGridGenerator.readSource(file: file.path, identity: .d2)
            Issue.record("Expected invalid NetCDF source to fail")
        } catch is IconNativeGridSourceError {
            // The downloader can safely identify this as a replaceable cached source.
        } catch {
            Issue.record("Expected IconNativeGridSourceError, got \(error)")
        }
    }

    @Test func spatialIndexRejectsAnUnboundedCandidateBin() throws {
        let vertices = [
            SphericalPoint(latitude: 0, longitude: 0),
            SphericalPoint(latitude: 0, longitude: 0.01),
            SphericalPoint(latitude: 0.01, longitude: 0),
        ]
        let vertexIndices = Array(repeating: [UInt32(0), UInt32(1), UInt32(2)], count: 129).flatMap { $0 }
        do {
            _ = try IconNativeGridGenerator.makeSpatialIndex(
                vertices: vertices,
                vertexIndices: vertexIndices,
                isGlobal: false,
                bounds: GridBounds(lat_bounds: 0...0.01, lon_bounds: 0...0.01),
                step: 0.02
            )
            Issue.record("Expected the per-bin candidate bound to fail")
        } catch IconNativeGridError.candidateLimit {
            // Expected.
        }
    }

    @Test func concurrentLookupsAreStable() async throws {
        let fixture = try makeGlobalFixture()
        defer { fixture.remove() }
        let grid = try IconNativeGrid.load(file: fixture.file)
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

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"] != nil))
    func officialD2TriangleInteriorsPreserveNativeIndices() throws {
        guard let sourceFile = ProcessInfo.processInfo.environment["ICON_D2_GRID_TEST_FILE"] else {
            return
        }
        let source = try IconNativeGridGenerator.readSource(file: sourceFile, identity: .d2)
        let artifactFile = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: artifactFile) }
        let grid = try IconNativeGridGenerator.generate(
            sourceFile: sourceFile,
            identity: .d2,
            artifactFile: artifactFile.path
        )

        #expect(grid.nx == IconNativeGridIdentity.d2.cellCount)
        let artifactSize = FileManager.default.fileStats(at: artifactFile.path).map { Int($0.st_size) } ?? .max
        #expect(artifactSize <= 64 * 1_024 * 1_024)
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
            let interior = SphericalPoint(x: x / length, y: y / length, z: z / length)
            let actual = grid.findPoint(lat: interior.latitude, lon: interior.longitude)
            if actual != cell {
                Issue.record("Official ICON-D2 triangle interior \(cell) resolved to \(String(describing: actual))")
                return
            }
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"] != nil))
    func officialGlobalGridPreservesSampledNativeIndices() throws {
        guard let sourceFile = ProcessInfo.processInfo.environment["ICON_GLOBAL_GRID_TEST_FILE"] else {
            return
        }
        let source = try IconNativeGridGenerator.readSource(file: sourceFile, identity: .global)
        let artifactFile = temporaryArtifactFile()
        defer { try? FileManager.default.removeItem(at: artifactFile) }
        let grid = try IconNativeGridGenerator.generate(
            sourceFile: sourceFile,
            identity: .global,
            artifactFile: artifactFile.path
        )

        let stride = max(1, source.centers.count / 100_000)
        for cell in Swift.stride(from: 0, to: source.centers.count, by: stride) {
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
            let interior = SphericalPoint(
                x: x / length,
                y: y / length,
                z: z / length
            )
            #expect(grid.findPoint(lat: interior.latitude, lon: interior.longitude) == cell)
        }
    }
}

private struct IconNativeGridFixture {
    let file: URL
    let centers: [LatLon]
    let vertices: [SphericalPoint]
    let vertexIndices: [UInt32]

    func remove() {
        try? FileManager.default.removeItem(at: file)
    }
}

private struct IconNativeGridFixtureInputs {
    let metadata: IconNativeGridArtifact.Metadata
    let centers: [LatLon]
    let vertices: [SphericalPoint]
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
    let handle = try FileHandle.createNewFile(file: path)
    try elevations.writeOmFile(
        fn: handle,
        dimensions: [1, elevations.count],
        chunks: [1, elevations.count],
        compression: .pfor_delta2d_int16,
        scalefactor: 1
    )
    try handle.close()
    let reader = try await OmFileReader(file: path).expectArray(of: Float.self)
    return IconNativeGridElevationFile(path: path, reader: reader)
}

private func makeGlobalFixture() throws -> IconNativeGridFixture {
    let vertices = [
        SphericalPoint(x: 0, y: 0, z: 1),
        SphericalPoint(x: 0, y: 0, z: -1),
        SphericalPoint(x: 1, y: 0, z: 0),
        SphericalPoint(x: 0, y: 1, z: 0),
        SphericalPoint(x: -1, y: 0, z: 0),
        SphericalPoint(x: 0, y: -1, z: 0),
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
        step: 45
    )
    let metadata = makeMetadata(isGlobal: true, bounds: bounds, index: index)
    let file = temporaryArtifactFile()
    try IconNativeGridArtifact.write(
        to: file.path,
        metadata: metadata,
        centers: centers,
        vertices: vertices,
        vertexIndices: vertexIndices,
        neighbourIndices: neighbours,
        binOffsets: index.offsets,
        binCells: index.cells
    )
    _ = try IconNativeGrid.load(file: file)
    return IconNativeGridFixture(file: file, centers: centers, vertices: vertices, vertexIndices: vertexIndices)
}

private func makeRegionalFixture() throws -> IconNativeGridFixture {
    let inputs = try makeRegionalFixtureInputs()
    return IconNativeGridFixture(
        file: try makeArtifact(inputs: inputs),
        centers: inputs.centers,
        vertices: inputs.vertices,
        vertexIndices: inputs.vertexIndices
    )
}

private func makeRegionalFixtureInputs() throws -> IconNativeGridFixtureInputs {
    let vertices = [
        SphericalPoint(latitude: 0, longitude: 0),
        SphericalPoint(latitude: 0, longitude: 0.1),
        SphericalPoint(latitude: 0.1, longitude: 0),
        SphericalPoint(latitude: 0.1, longitude: 0.1),
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
        step: 0.04
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

private func makeArtifact(inputs: IconNativeGridFixtureInputs) throws -> URL {
    let file = temporaryArtifactFile()
    do {
        try IconNativeGridArtifact.write(
            to: file.path,
            metadata: inputs.metadata,
            centers: inputs.centers,
            vertices: inputs.vertices,
            vertexIndices: inputs.vertexIndices,
            neighbourIndices: inputs.neighbours,
            binOffsets: inputs.index.offsets,
            binCells: inputs.index.cells
        )
        _ = try IconNativeGrid.load(file: file)
        return file
    } catch {
        try? FileManager.default.removeItem(at: file)
        throw error
    }
}

private func temporaryArtifactFile() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("icon-native-grid-\(UUID().uuidString).bin")
}

private func writeTemporaryData(_ data: Data) throws -> URL {
    let file = temporaryArtifactFile()
    try data.write(to: file)
    return file
}

private func makeIdentity(for fixture: IconNativeGridFixture) -> IconNativeGridIdentity {
    IconNativeGridIdentity(
        gridNumber: 26,
        gridUUID: Array(0..<16),
        gridUUIDHex: Array(0..<16).map { String(format: "%02x", $0) }.joined(),
        cellCount: fixture.centers.count,
        isGlobal: true,
        sourceFile: "synthetic.nc.bz2"
    )
}

private func triangleCenters(vertices: [SphericalPoint], vertexIndices: [UInt32]) -> [LatLon] {
    (0..<(vertexIndices.count / 3)).map { cell in
        let a = vertices[Int(vertexIndices[cell * 3])]
        let b = vertices[Int(vertexIndices[cell * 3 + 1])]
        let c = vertices[Int(vertexIndices[cell * 3 + 2])]
        let x = a.x + b.x + c.x
        let y = a.y + b.y + c.y
        let z = a.z + b.z + c.z
        let length = sqrt(x * x + y * y + z * z)
        let point = SphericalPoint(x: x / length, y: y / length, z: z / length)
        return (point.latitude, point.longitude)
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
    vertices: [SphericalPoint],
    vertexIndices: [UInt32]
) -> Int? {
    matchingCells(
        point: SphericalPoint(latitude: latitude, longitude: longitude),
        vertices: vertices,
        vertexIndices: vertexIndices
    ).min()
}

private func matchingCells(
    point: SphericalPoint,
    vertices: [SphericalPoint],
    vertexIndices: [UInt32]
) -> [Int] {
    (0..<(vertexIndices.count / 3)).filter { cell in
        SphericalTriangle(
            a: vertices[Int(vertexIndices[cell * 3])],
            b: vertices[Int(vertexIndices[cell * 3 + 1])],
            c: vertices[Int(vertexIndices[cell * 3 + 2])]
        ).contains(point)
    }
}
