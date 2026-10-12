import Foundation
@testable import App
import OmFileFormat
import Testing
import Logging

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

    @Test func rowsAndColumns() throws {
        let inside = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        #expect(inside.rows == 3 ..< 9)
        #expect(inside.columns == 5 ..< 11)
        /// A query at 5.1N picks row 5, outside the box, and searches row 4 around it
        let between = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5.1 ..< 6.5, longitude: 7 ..< 8.5))
        #expect(between.rows == 4 ..< 9)
        /// A box larger than the grid is clamped to its edges
        let edges = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: -20 ..< 0.5, longitude: 13.5 ..< 40))
        #expect(edges.rows == 0 ..< 3)
        #expect(edges.columns == 12 ..< 15)
        let outside = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 50 ..< 60, longitude: 50 ..< 60))
        #expect(outside.rows.isEmpty)
        #expect(throws: (any Error).self) {
            try SyncBoundingBox(grid: RegularGrid(nx: 100, ny: 1, latMin: 0, lonMin: 0, dx: 1, dy: 1), box: BoundingBoxWGS84(latitude: 0 ..< 1, longitude: 0 ..< 1))
        }
    }

    /// Write `values` as a file `[12, 15, 5]` with chunks `[2, 3, 2]` and one attribute, and serve it from memory
    func fixture(_ values: [Float], dimensions: [UInt64] = [12, 15, 5], chunks: [UInt64] = [2, 3, 2]) throws -> DataAsClass {
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        let writer = OmFileWriter(fn: try FileHandle.createNewFile(file: file), initialCapacity: 1024)
        let array = try writer.writeArray(data: values, dimensions: dimensions, chunkDimensions: chunks, compression: .pfor_delta2d_int16, scale_factor: 20, add_offset: 0)
        let start = try writer.write(value: 1_700_000_000, name: "time_start", children: [])
        try writer.writeTrailer(rootVariable: try writer.write(array: array, name: "", children: [start]))
        return DataAsClass(data: try Data(contentsOf: URL(fileURLWithPath: file)))
    }

    /// Buffers of one chunk, two chunks and the default cover reads by chunk column, by groups of columns and by several chunk rows
    @Test(arguments: [30, 60, SyncBoundingBox.bufferValues])
    func keepsChunksInsideBoxAndNaNElsewhere(bufferValues: Int) async throws {
        let values = (0 ..< 12 * 15 * 5).map { Float($0 % 400) / 20 }
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        #expect(try await keep.write(remote: fixture(values), to: file, modificationTime: Timestamp(1_600_000_000), logger: Logger(label: "test"), bufferValues: bufferValues))

        let reader = try await OmFileReader(fn: DataAsClass(data: Data(contentsOf: URL(fileURLWithPath: file))))
        let array = try reader.expectArray(of: Float.self)
        #expect(array.getDimensions() == [12, 15, 5])
        #expect(array.getChunkDimensions() == [2, 3, 2])
        #expect(array.compression == .pfor_delta2d_int16)
        #expect(array.scaleFactor == 20 && array.addOffset == 0)
        #expect(try await reader.getChild(name: "time_start")?.readScalar() == 1_700_000_000)
        let modified = try FileManager.default.attributesOfItem(atPath: file)[.modificationDate] as? Date
        #expect(modified?.timeIntervalSince1970 == 1_600_000_000)

        /// Rows 3..<9 and columns 5..<11 widen to whole chunks: rows 2..<10 and columns 3..<12
        let read = try await array.read()
        for y in 0 ..< 12 {
            for x in 0 ..< 15 {
                for t in 0 ..< 5 {
                    let i = (y * 15 + x) * 5 + t
                    if (2 ..< 10).contains(y) && (3 ..< 12).contains(x) {
                        #expect(read[i].bitPattern == values[i].bitPattern)
                    } else {
                        #expect(read[i].isNaN)
                    }
                }
            }
        }
    }

    /// Rings of the n160 Gaussian grid, the smallest one, have different point counts
    @Test func gaussianCells() throws {
        let gaussian = GaussianGrid(type: .n160)
        let keep = try SyncBoundingBox(grid: gaussian, box: BoundingBoxWGS84(latitude: 45 ..< 48, longitude: 5 ..< 11))
        let cells = try #require(keep.cells)
        var inside = [Int: ClosedRange<Int>](), kept = [Int: ClosedRange<Int>]()
        for i in 0 ..< gaussian.nx {
            let (lat, lon) = gaussian.getCoordinates(gridpoint: i)
            let (y, x, _) = gaussian.type.getPos(gridpoint: i)
            if (45 ..< 48).contains(lat), (5 ..< 11).contains(lon) {
                #expect(cells[i])
                inside[y] = min(inside[y]?.lowerBound ?? x, x) ... max(inside[y]?.upperBound ?? x, x)
            }
            if cells[i] {
                kept[y] = min(kept[y]?.lowerBound ?? x, x) ... max(kept[y]?.upperBound ?? x, x)
            }
        }
        /// Two rings north and south, and two points either side along each ring
        let rings = try #require(inside.keys.min()) ... (try #require(inside.keys.max()))
        #expect(Set(kept.keys) == Set(rings.lowerBound - 2 ... rings.upperBound + 2))
        for (y, x) in inside {
            #expect(kept[y] == x.lowerBound - 2 ... x.upperBound + 2)
        }
        #expect(keep.rows == 0 ..< 1)
    }

    @Test func gaussianFileKeepsChunksWithAKeptCell() async throws {
        let gaussian = GaussianGrid(type: .n160)
        let keep = try SyncBoundingBox(grid: gaussian, box: BoundingBoxWGS84(latitude: 45 ..< 48, longitude: 5 ..< 11))
        let values = (0 ..< gaussian.nx * 2).map { Float($0 % 400) / 20 }
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-gaussian-\(UUID().uuidString).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        let source = try fixture(values, dimensions: [1, UInt64(gaussian.nx), 2], chunks: [1, 100, 2])
        #expect(try await keep.write(remote: source, to: file, modificationTime: nil, logger: Logger(label: "test")))

        let read = try await OmFileReader(fn: DataAsClass(data: Data(contentsOf: URL(fileURLWithPath: file)))).expectArray(of: Float.self).read()
        var keptChunks = 0
        for cx in 0 ..< (gaussian.nx + 99) / 100 {
            let columns = cx * 100 ..< min(cx * 100 + 100, gaussian.nx)
            let kept = keep.keeps(rows: 0 ..< 1, columns: columns)
            keptChunks += kept ? 1 : 0
            for i in columns.lowerBound * 2 ..< columns.upperBound * 2 {
                let same: Bool = kept ? read[i].bitPattern == values[i].bitPattern : read[i].isNaN
                #expect(same)
            }
        }
        /// One run of kept chunks per ring, far apart in the file
        #expect(keptChunks > 7 && keptChunks < 40)
    }

    /// Legacy files store `[ny * nx, time]` as a flat 2D array. The mask keeps the chunks of the cells inside the box and keeps the layout
    @Test func legacyFlatFileKeepsLayoutAndMasksChunks() async throws {
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        let cells = grid.ny * grid.nx, time = 5, chunkCells = 7
        let values = (0 ..< cells * time).map { Float($0 % 400) / 20 }
        let source = try fixture(values, dimensions: [UInt64(cells), UInt64(time)], chunks: [UInt64(chunkCells), 3])
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        #expect(try await keep.write(remote: source, to: file, modificationTime: nil, logger: Logger(label: "test")))

        let reader = try await OmFileReader(fn: DataAsClass(data: Data(contentsOf: URL(fileURLWithPath: file))))
        let array = try reader.expectArray(of: Float.self)
        #expect(array.getDimensions() == [UInt64(cells), UInt64(time)])
        #expect(array.getChunkDimensions() == [UInt64(chunkCells), 3])
        #expect(array.compression == .pfor_delta2d_int16)
        #expect(array.scaleFactor == 20 && array.addOffset == 0)
        #expect(try await reader.getChild(name: "time_start")?.readScalar() == 1_700_000_000)

        /// Rows 3..<9 and columns 5..<11 as flat cells; a chunk is kept if any of its cells is inside
        let flat = keep.flattened()
        let read = try await array.read()
        var keptChunks = 0
        for chunk in 0 ..< (cells + chunkCells - 1) / chunkCells {
            let range = chunk * chunkCells ..< min(cells, (chunk + 1) * chunkCells)
            let kept = range.contains { y in (3 ..< 9).contains(y / grid.nx) && (5 ..< 11).contains(y % grid.nx) }
            #expect(flat.keeps(rows: 0 ..< 1, columns: range) == kept)
            keptChunks += kept ? 1 : 0
            for cell in range {
                for t in 0 ..< time {
                    let same: Bool = kept ? read[cell * time + t].bitPattern == values[cell * time + t].bitPattern : read[cell * time + t].isNaN
                    #expect(same)
                }
            }
        }
        #expect(keptChunks > 0 && keptChunks < (cells + chunkCells - 1) / chunkCells)
    }

    @Test func otherLayoutsAreNotWritten() async throws {
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        let flat = try fixture([Float](repeating: 1, count: 12 * 15), dimensions: [12, 15], chunks: [4, 5])
        #expect(try await keep.write(remote: flat, to: file, modificationTime: nil, logger: Logger(label: "test")) == false)
        #expect(FileManager.default.fileExists(atPath: file) == false)
    }
}
