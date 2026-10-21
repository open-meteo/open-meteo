import Foundation
@testable import App
import OmFileFormat
import Testing
import Logging
import ReducedLatLon

@Suite struct SyncBoundingBoxTests {
    /// 15 x 12 cells of one degree, south-west corner at 0N 0E
    let grid = RegularGrid(nx: 15, ny: 12, latMin: 0, lonMin: 0, dx: 1, dy: 1, searchRadius: 1)

    @Test func parseBox() throws {
        let box = try BoundingBoxWGS84(coordinates: [5, 7, 6.5, 8.5])
        #expect(box.latitude == 5 ..< 6.5)
        #expect(box.longitude == 7 ..< 8.5)
        #expect(throws: (any Error).self) { try BoundingBoxWGS84(coordinates: [5, 7, 6.5]) }
        #expect(throws: (any Error).self) { try BoundingBoxWGS84(coordinates: [6.5, 7, 5, 8.5]) }
        #expect(throws: (any Error).self) { try BoundingBoxWGS84(coordinates: [5, 7, 95, 8.5]) }
        #expect(try BoundingBoxWGS84(commaSeparated: "5, 7,6.5,8.5").latitude == 5 ..< 6.5)
        #expect(throws: (any Error).self) { try BoundingBoxWGS84(commaSeparated: "35,x,36,140,150") }
        #expect(throws: (any Error).self) { try BoundingBoxWGS84(commaSeparated: "35,x,36,140") }
        #expect(throws: (any Error).self) { try BoundingBoxWGS84(commaSeparated: "35,,36,140") }
    }

    /// Rows and columns of the kept cells
    func bounds(_ keep: SyncBoundingBox) -> (rows: ClosedRange<Int>, columns: ClosedRange<Int>) {
        let kept = keep.cells.indices.filter { keep.cells[$0] }.map { $0.quotientAndRemainder(dividingBy: keep.nx) }
        return (kept.map(\.quotient).min()! ... kept.map(\.quotient).max()!, kept.map(\.remainder).min()! ... kept.map(\.remainder).max()!)
    }

    @Test func keepsOnlyCellsInsideTheBox() throws {
        let box = BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5)
        let inside = SyncBoundingBox.cells(grid: grid, box: box)
        #expect(inside.filter { $0 }.count == 4)
        let keep = try SyncBoundingBox(grid: grid, box: box)
        /// Rows 5 and 6, columns 7 and 8, regardless of the grid search radius
        let (rows, columns) = bounds(keep)
        #expect(rows == 5 ... 6 && columns == 7 ... 8)
        #expect(keep.cells.filter { $0 }.count == 4)
    }

    @Test func boxPartlyOutsideKeepsTheCellsInside() throws {
        let edges = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: -20 ..< 0.5, longitude: 13.5 ..< 40))
        let (rows, columns) = bounds(edges)
        #expect(rows == 0 ... 0 && columns == 14 ... 14)
        #expect(throws: (any Error).self) {
            try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 50 ..< 60, longitude: 50 ..< 60))
        }
    }

    @Test func nativeGridKeepsOnlyCellsInsideTheBox() async throws {
        let fixture = try makeFixture(centers: [
            ReducedLatLonPoint(latitudeDegrees: 20, longitudeDegrees: 20),
            ReducedLatLonPoint(latitudeDegrees: 5, longitudeDegrees: 5),
            ReducedLatLonPoint(latitudeDegrees: -20, longitudeDegrees: -20),
            ReducedLatLonPoint(latitudeDegrees: 6, longitudeDegrees: 6)
        ])
        defer { fixture.remove() }
        let grid = IconNativeGrid(storage: fixture.index, resolutionMeters: 1000,
            maximumChordDistanceSquared: 1, nearbyMaximumChordDistanceSquared: 1)
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 0..<10, longitude: 0..<10))
        #expect(keep.cells == [false, true, false, true])
        try await copyAndCheck(keep: keep, dims: [1, 4, 5], chunks: [1, 1, 2], cell: { $0[1] })
        try await copyAndCheck(keep: keep, dims: [4, 5], chunks: [1, 2], cell: { $0[0] })
    }

    @Test func takeChunksFollowsTheGridWhateverTheOtherDimensions() async throws {
        let keep = SyncBoundingBox(cells: (0 ..< 12 * 15).map { $0 == 4 * 15 + 7 }, nx: 15)
        func takeChunks(dims: [Int], chunks: [Int]) async throws -> [Bool]? {
            let source = try fixture([Float](repeating: 0, count: dims.reduce(1, *)), dimensions: dims.map(UInt64.init), chunks: chunks.map(UInt64.init))
            let array = try await OmFileReader(fn: source).expectArray(of: Float.self)
            return try keep.takeChunks(layout: array.chunkLayout())
        }
        /// Chunks of 2 rows and 3 columns: the cell is in chunk row 2 and chunk column 2
        let spatial = (0 ..< 6 * 5).map { $0 == 2 * 5 + 2 }
        #expect(try await takeChunks(dims: [12, 15, 5], chunks: [2, 3, 2]) == spatial.flatMap { [Bool](repeating: $0, count: 3) })
        /// Members first, or between the grid and time
        #expect(try await takeChunks(dims: [3, 12, 15, 5], chunks: [1, 2, 3, 5]) == (0 ..< 3).flatMap { _ in spatial })
        #expect(try await takeChunks(dims: [12, 15, 3, 5], chunks: [2, 3, 2, 5]) == spatial.flatMap { [Bool](repeating: $0, count: 2) })
        /// The flat array of legacy files: cell 67 is in chunk 9 of 7 cells
        let flat = try #require(try await takeChunks(dims: [180, 5], chunks: [7, 3]))
        #expect(flat.indices.filter { flat[$0] } == [18, 19])
        #expect(try await takeChunks(dims: [12, 14, 5], chunks: [2, 3, 2]) == nil)
        #expect(try await takeChunks(dims: [5], chunks: [2]) == nil)
        /// A dimension that only equals the cell count is not the grid: time first, or a third dimension
        #expect(try await takeChunks(dims: [5, 180], chunks: [2, 7]) == nil)
        #expect(try await takeChunks(dims: [3, 180, 5], chunks: [1, 7, 3]) == nil)
    }

    @Test func chunkCellsUseGlobalIndicesAndStopAtFirstMatch() async throws {
        let source = try fixture([Float](repeating: 0, count: 3 * 5 * 2 * 3), dimensions: [3, 5, 2, 3], chunks: [2, 3, 1, 2])
        let layout = try await OmFileReader(fn: source).expectArray(of: Float.self).chunkLayout()
        let edge = try #require(layout.last)
        var visited = [Int]()
        #expect(!edge.containsCell(yDimension: 0, xDimension: 1) { visited.append($0); return false })
        #expect(visited == [13, 14])
        visited.removeAll()
        #expect(edge.containsCell(yDimension: 0, xDimension: 1) { visited.append($0); return true })
        #expect(visited == [13])
        enum Failure: Error { case predicate }
        #expect(throws: Failure.self) {
            try edge.containsCell(yDimension: 0, xDimension: 1) { _ in throw Failure.predicate }
        }
        visited.removeAll()
        #expect(!layout[0].containsCell(yDimension: 0, xDimension: 1) { visited.append($0); return false })
        #expect(visited == [0, 1, 2, 5, 6, 7])

        let flatSource = try fixture([Float](repeating: 0, count: 7 * 3), dimensions: [7, 3], chunks: [3, 2])
        let flatLayout = try await OmFileReader(fn: flatSource).expectArray(of: Float.self).chunkLayout()
        let flatEdge = try #require(flatLayout.last)
        visited.removeAll()
        #expect(!flatEdge.containsCell(yDimension: nil, xDimension: 0) { visited.append($0); return false })
        #expect(visited == [6])
    }

    @Test func runsJoinCloseChunksAndCapTheirSize() {
        let ranges: [Range<UInt64>] = [100..<150, 150..<200, 200..<200, 210..<250, 100_000..<100_010, 100_010..<100_110, 200_000..<200_010]
        let take = [true, false, true, true, true, true, true]
        let runs = SyncBoundingBox.runs(ranges: ranges, take: take, merge: 16, max: 150)
        /// The chunk that is not taken is a gap of 50 bytes, the empty one is skipped, and the last run would exceed 150 bytes
        #expect(runs.map(\.chunks) == [0 ..< 1, 3 ..< 4, 4 ..< 6, 6 ..< 7])
        #expect(runs.map(\.bytes) == [100 ..< 150, 210 ..< 250, 100_000 ..< 100_110, 200_000 ..< 200_010])
        #expect(SyncBoundingBox.runs(ranges: ranges, take: take, merge: 100, max: 1000).map(\.chunks) == [0 ..< 4, 4 ..< 6, 6 ..< 7])
    }

    /// Write `values` as a file with one attribute, and serve it from memory
    func fixture(_ values: [Float], dimensions: [UInt64], chunks: [UInt64]) throws -> DataAsClass {
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        let writer = OmFileWriter(fn: try FileHandle.createNewFile(file: file), initialCapacity: 1024)
        let array = try writer.writeArray(data: values, dimensions: dimensions, chunkDimensions: chunks, compression: .pfor_delta2d_int16, scale_factor: 20, add_offset: 0)
        let start = try writer.write(value: 1_700_000_000, name: "time_start", children: [])
        try writer.writeTrailer(rootVariable: try writer.write(array: array, name: "", children: [start]))
        return DataAsClass(data: try Data(contentsOf: URL(fileURLWithPath: file)))
    }

    /// Copy a generated file with `keep` and check that every chunk holding a kept cell is as in the source and all others are NaN.
    /// `cell` is the grid cell of an element, found from its index in each dimension. Returns the number of kept chunks.
    @discardableResult
    func copyAndCheck(keep: SyncBoundingBox, dims: [Int], chunks: [Int], cell: ([Int]) -> Int, modificationTime: Timestamp? = nil) async throws -> Int {
        let values = (0 ..< dims.reduce(1, *)).map { Float($0 % 400) / 20 }
        let source = try fixture(values, dimensions: dims.map(UInt64.init), chunks: chunks.map(UInt64.init))
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        let fetched = try #require(try await keep.write(remote: source, to: file, modificationTime: modificationTime, logger: Logger(label: "test")))

        let reader = try await OmFileReader(fn: DataAsClass(data: Data(contentsOf: URL(fileURLWithPath: file))))
        let array = try reader.expectArray(of: Float.self)
        #expect(array.getDimensions() == dims.map(UInt64.init))
        #expect(array.getChunkDimensions() == chunks.map(UInt64.init))
        #expect(array.compression == .pfor_delta2d_int16)
        #expect(array.scaleFactor == 20 && array.addOffset == 0)
        #expect(try await reader.getChild(name: "time_start")?.readScalar() == 1_700_000_000)
        if let modificationTime {
            let modified = try FileManager.default.attributesOfItem(atPath: file)[.modificationDate] as? Date
            #expect(modified?.timeIntervalSince1970 == Double(modificationTime.timeIntervalSince1970))
        }

        /// A chunk is kept if any of its elements lies in a kept cell
        var keptChunks = Set<[Int]>(), allChunks = Set<[Int]>()
        func position(_ i: Int) -> [Int] {
            var rest = i
            var pos = [Int](repeating: 0, count: dims.count)
            for d in dims.indices.reversed() {
                pos[d] = rest % dims[d]
                rest /= dims[d]
            }
            return pos
        }
        for i in values.indices {
            let index = position(i), chunk = zip(index, chunks).map { $0 / $1 }
            allChunks.insert(chunk)
            if keep.cells[cell(index)] {
                keptChunks.insert(chunk)
            }
        }
        let original = try await OmFileReader(fn: source).expectArray(of: Float.self).read()
        let copy = try await array.read()
        for i in values.indices {
            if keptChunks.contains(zip(position(i), chunks).map { $0 / $1 }) {
                #expect(copy[i].bitPattern == original[i].bitPattern)
            } else {
                #expect(copy[i].isNaN)
            }
        }
        let sourceArray = try await OmFileReader(fn: source).expectArray(of: Float.self)
        let sourceIndex = try await sourceArray.chunkIndex()
        let copiedIndex = try await array.chunkIndex()
        let take = try #require(try keep.takeChunks(layout: array.chunkLayout()))
        let copiedData = try Data(contentsOf: URL(fileURLWithPath: file))
        for i in take.indices {
            if take[i] {
                let bytes = sourceIndex[i]
                let originalBytes = try await source.getData(offset: Int(bytes.lowerBound), count: Int(bytes.count))
                #expect(originalBytes.withUnsafeBytes { Data($0) } == copiedData.subdata(in: Int(copiedIndex[i].lowerBound)..<Int(copiedIndex[i].upperBound)))
            } else {
                #expect(copiedIndex[i].isEmpty)
            }
        }
        // Syncing a file that already contains zero-byte chunks preserves its values.
        let secondFile = "\(file).copy"
        defer { try? FileManager.default.removeItem(atPath: secondFile) }
        let keepAll = SyncBoundingBox(cells: [Bool](repeating: true, count: keep.cells.count), nx: keep.nx)
        #expect(try await keepAll.write(remote: DataAsClass(data: copiedData), to: secondFile, modificationTime: nil, logger: Logger(label: "test")) != nil)
        let second = try await OmFileReader(fn: DataAsClass(data: Data(contentsOf: URL(fileURLWithPath: secondFile)))).expectArray(of: Float.self).read()
        #expect(zip(copy, second).allSatisfy { $0.bitPattern == $1.bitPattern || ($0.isNaN && $1.isNaN) })
        /// The chunks left out are not downloaded
        #expect(keptChunks.count < allChunks.count && fetched < source.count)
        return keptChunks.count
    }

    @Test func keepsChunksInsideBoxAndNaNElsewhere() async throws {
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        /// Time chunks of 2 over 5 values: the last chunk is smaller. Rows 5 and 6 occupy chunk rows 2 and 3; columns 7 and 8 share chunk column 2
        let kept = try await copyAndCheck(keep: keep, dims: [12, 15, 5], chunks: [2, 3, 2], cell: { $0[0] * 15 + $0[1] }, modificationTime: Timestamp(1_600_000_000))
        #expect(kept == 2 * 1 * 3)
    }

    @Test func ensembleFilesKeepTheirMembers() async throws {
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        try await copyAndCheck(keep: keep, dims: [3, 12, 15, 5], chunks: [1, 2, 3, 5], cell: { $0[1] * 15 + $0[2] })
        try await copyAndCheck(keep: keep, dims: [12, 15, 3, 5], chunks: [2, 3, 2, 5], cell: { $0[0] * 15 + $0[1] })
    }

    @Test func gaussianFileKeepsChunksWithAKeptCell() async throws {
        let gaussian = GaussianGrid(type: .n160)
        let keep = try SyncBoundingBox(grid: gaussian, box: BoundingBoxWGS84(latitude: 45 ..< 48, longitude: 5 ..< 11))
        /// One run of kept chunks per ring, far apart in the file
        let kept = try await copyAndCheck(keep: keep, dims: [1, gaussian.nx, 2], chunks: [1, 100, 2], cell: { $0[1] })
        #expect(kept > 0 && kept < 40)
    }

    /// Legacy files store `[ny * nx, time]` as a flat 2D array
    @Test func legacyFlatFileKeepsLayoutAndMasksChunks() async throws {
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        let kept = try await copyAndCheck(keep: keep, dims: [12 * 15, 5], chunks: [7, 3], cell: { $0[0] })
        #expect(kept > 0)
    }

    @Test func otherLayoutsAreNotWritten() async throws {
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        let other = try fixture([Float](repeating: 1, count: 10 * 15), dimensions: [10, 15], chunks: [4, 5])
        #expect(try await keep.write(remote: other, to: file, modificationTime: nil, logger: Logger(label: "test")) == nil)
        #expect(FileManager.default.fileExists(atPath: file) == false)
    }
}
