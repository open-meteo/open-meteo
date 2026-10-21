import Foundation
@testable import App
import OmFileFormat
import Testing
import Logging
import ReducedLatLon
import Synchronization
@testable import OmFileIO

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
        let kept = keep.selectedCells.indices.filter { keep.selectedCells[$0] }.map { $0.quotientAndRemainder(dividingBy: keep.nx) }
        return (kept.map(\.quotient).min()! ... kept.map(\.quotient).max()!, kept.map(\.remainder).min()! ... kept.map(\.remainder).max()!)
    }

    @Test func keepsOnlyCellsInsideTheBox() throws {
        let box = BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5)
        let inside = SyncBoundingBox.selectedCells(grid: grid, box: box)
        #expect(inside.filter { $0 }.count == 4)
        let keep = try SyncBoundingBox(grid: grid, box: box)
        /// Rows 5 and 6, columns 7 and 8, regardless of the grid search radius
        let (rows, columns) = bounds(keep)
        #expect(rows == 5 ... 6 && columns == 7 ... 8)
        #expect(keep.selectedCells.filter { $0 }.count == 4)
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
        #expect(keep.selectedCells == [false, true, false, true])
        try await copyAndCheck(keep: keep, dims: [1, 4, 5], chunks: [1, 1, 2], cell: { $0[1] })
        try await copyAndCheck(keep: keep, dims: [4, 5], chunks: [1, 2], cell: { $0[0] })
    }

    @Test func takeChunksFollowsTheGridWhateverTheOtherDimensions() async throws {
        let keep = SyncBoundingBox(selectedCells: (0 ..< 12 * 15).map { $0 == 4 * 15 + 7 }, nx: 15)
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
        // Partial member/time chunks repeat the same spatial selection.
        #expect(try await takeChunks(dims: [3, 12, 15, 5], chunks: [2, 2, 3, 2]) == (0..<2).flatMap { _ in spatial.flatMap { [Bool](repeating: $0, count: 3) } })
        #expect(try await takeChunks(dims: [12, 15, 3, 5], chunks: [2, 3, 2, 2]) == spatial.flatMap { [Bool](repeating: $0, count: 6) })
        /// The flat array of legacy files: cell 67 is in chunk 9 of 7 cells
        let flat = try #require(try await takeChunks(dims: [180, 5], chunks: [7, 3]))
        #expect(flat.indices.filter { flat[$0] } == [18, 19])
        #expect(try await takeChunks(dims: [12, 14, 5], chunks: [2, 3, 2]) == nil)
        #expect(try await takeChunks(dims: [5], chunks: [2]) == nil)
        /// A dimension that only equals the cell count is not the grid: time first, or a third dimension
        #expect(try await takeChunks(dims: [5, 180], chunks: [2, 7]) == nil)
        #expect(try await takeChunks(dims: [3, 180, 5], chunks: [1, 7, 3]) == nil)
        #expect(try await takeChunks(dims: [12, 15, 12, 15], chunks: [2, 3, 2, 3]) == nil)
    }

    @Test func coalescedReadRangesOnlyJoinAdjacentSelectedChunks() {
        let ranges: [Range<UInt64>] = [100..<150, 150..<200, 200..<200, 210..<250, 250..<300, 300..<400, 400..<410]
        let take = [true, false, true, true, true, true, true]
        let runs = SyncBoundingBox.coalescedReadRanges(ranges: ranges, takeChunks: take, max: 150)
        #expect(runs.map(\.chunks) == [0..<1, 3..<5, 5..<7])
        #expect(runs.map(\.bytes) == [100..<150, 210..<300, 300..<410])
        // Even a one-byte gap must not be fetched.
        let gap = SyncBoundingBox.coalescedReadRanges(ranges: [0..<10, 11..<20] as [Range<UInt64>], takeChunks: [true, true])
        #expect(gap.map(\.bytes) == [0..<10, 11..<20])
        let capped = SyncBoundingBox.coalescedReadRanges(ranges: [0..<100, 100..<150, 150..<151] as [Range<UInt64>], takeChunks: [true, true, true], max: 150)
        #expect(capped.map(\.bytes) == [0..<150, 150..<151])
    }

    @Test func concurrentReadsKeepChunkOrderAndNeverFetchGaps() async throws {
        let values = (0..<120).map { Float($0) / 20 }
        let source = try fixture(values, dimensions: [1, 40, 3], chunks: [1, 1, 3])
        let array = try await OmFileReader(fn: source).expectArray(of: Float.self)
        let ranges = try await array.chunkIndex()
        let selectedCells = (0..<40).map { $0 % 2 == 1 }
        let selectedRanges = ranges.indices.filter { selectedCells[$0] }.map {
            Int(ranges[$0].lowerBound)..<Int(ranges[$0].upperBound)
        }
        let backend = RecordingReadBackend(data: source.data, delayedOffsets: Set(selectedRanges.map(\.lowerBound)))
        let keep = SyncBoundingBox(selectedCells: selectedCells, nx: 40)
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID()).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        _ = try await keep.write(remote: backend, to: file, modificationTime: nil, logger: Logger(label: "test"))

        #expect(await backend.peakConcurrentReads == SyncBoundingBox.maxConcurrentReads)
        #expect(await backend.readsBeforeFirstCompleted == SyncBoundingBox.maxConcurrentReads)
        let retained = backend.liveBuffers.state.withLock { $0 }
        #expect(retained.peak <= SyncBoundingBox.maxConcurrentReads)
        #expect(retained.current == 0)
        let payloadReads = await backend.requests.filter { selectedRanges.contains($0) }
        #expect(payloadReads.sorted { $0.lowerBound < $1.lowerBound } == selectedRanges)
        let payloadStart = Int(ranges[0].lowerBound)
        let payloadEnd = Int(ranges[ranges.count - 1].upperBound)
        let allPayloadReads = await backend.requests.filter { $0.overlaps(payloadStart..<payloadEnd) }
        #expect(allPayloadReads.count == selectedRanges.count)
        let copied = try await OmFileReader(fn: DataAsClass(data: Data(contentsOf: URL(fileURLWithPath: file)))).expectArray(of: Float.self).read()
        for i in copied.indices {
            if selectedCells[i / 3] {
                #expect(copied[i] == values[i])
            } else {
                #expect(copied[i].isNaN)
            }
        }
    }

    @Test func oversizedChunkRemainsOneRange() {
        let oversizedEnd = UInt64(2 * SyncBoundingBox.runBytes + 10)
        let ranges: [Range<UInt64>] = [0..<3, 3..<oversizedEnd, oversizedEnd..<(oversizedEnd + 3)]
        let runs = SyncBoundingBox.coalescedReadRanges(ranges: ranges, takeChunks: [true, true, true])
        #expect(runs.map(\.bytes) == ranges.map { Int($0.lowerBound)..<Int($0.upperBound) })
    }

    @Test func noSelectedChunksProducesOnlyNaNs() async throws {
        let keep = SyncBoundingBox(selectedCells: [Bool](repeating: false, count: 180), nx: 15)
        try await copyAndCheck(keep: keep, dims: [12, 15, 5], chunks: [2, 3, 2], cell: { $0[0] * 15 + $0[1] })
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
            if keep.selectedCells[cell(index)] {
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
        let keepAll = SyncBoundingBox(selectedCells: [Bool](repeating: true, count: keep.selectedCells.count), nx: keep.nx)
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
        try await copyAndCheck(keep: keep, dims: [3, 12, 15, 5], chunks: [2, 2, 3, 2], cell: { $0[1] * 15 + $0[2] })
        try await copyAndCheck(keep: keep, dims: [12, 15, 3, 5], chunks: [2, 3, 2, 2], cell: { $0[0] * 15 + $0[1] })
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

    @Test func regionalSyncStillChecksSizesOfWholeFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("sync-bbox-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("static"), withIntermediateDirectories: true)
        let modified = Date(timeIntervalSince1970: 1_700_000_000)
        let names = ["weather.om", "static/elevation.om", "meta.json", "other.json"]
        let remote = try names.map { name in
            let file = directory.appendingPathComponent(name)
            try Data([1]).write(to: file)
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: file.path)
            return S3List.ListV2File(name: "data/\(name)", modificationTime: Timestamp(1_700_000_000), fileSize: 2, eTag: "\"etag\"")
        }
        let regional = remote.includeFiles(compareLocalDirectory: directory.path + "/", modificationTimeOnly: true)
        #expect(regional.map(\.name) == ["data/static/elevation.om", "data/other.json"])
        let whole = remote.includeFiles(compareLocalDirectory: directory.path + "/", modificationTimeOnly: false)
        #expect(whole.map(\.name) == ["data/weather.om", "data/static/elevation.om", "data/other.json"])
    }

    @Test func shortChunkReadPreservesExistingFile() async throws {
        let source = try fixture((0..<900).map(Float.init), dimensions: [12, 15, 5], chunks: [2, 3, 2])
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5..<6.5, longitude: 7..<8.5))
        let array = try await OmFileReader(fn: source).expectArray(of: Float.self)
        let ranges = try await array.chunkIndex()
        let take = try #require(try keep.takeChunks(layout: array.chunkLayout()))
        let firstRun = try #require(SyncBoundingBox.coalescedReadRanges(ranges: ranges, takeChunks: take).first)
        let backend = ShortReadBackend(data: source.data, shortReadOffset: firstRun.bytes.lowerBound)
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID()).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        let previous = Data("existing file".utf8)
        try previous.write(to: URL(fileURLWithPath: file))
        await #expect(throws: CurlErrorNonRetry.self) {
            try await keep.write(remote: backend, to: file, modificationTime: nil, logger: Logger(label: "test"))
        }
        #expect(try Data(contentsOf: URL(fileURLWithPath: file)) == previous)
    }

    @Test func cancelledCopyPreservesExistingFile() async throws {
        let source = try fixture([Float](repeating: 1, count: 900), dimensions: [12, 15, 5], chunks: [2, 3, 2])
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5..<6.5, longitude: 7..<8.5))
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID()).om"
        defer { try? FileManager.default.removeItem(atPath: file) }
        let previous = Data("existing file".utf8)
        try previous.write(to: URL(fileURLWithPath: file))
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await keep.write(remote: source, to: file, modificationTime: nil, logger: Logger(label: "test"))
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try Data(contentsOf: URL(fileURLWithPath: file)) == previous)
    }

    @Test func otherLayoutsAreNotWritten() async throws {
        let keep = try SyncBoundingBox(grid: grid, box: BoundingBoxWGS84(latitude: 5 ..< 6.5, longitude: 7 ..< 8.5))
        let file = "\(FileManager.default.temporaryDirectory.path)/sync-bbox-\(UUID().uuidString).om"
        let other = try fixture([Float](repeating: 1, count: 10 * 15), dimensions: [10, 15], chunks: [4, 5])
        #expect(try await keep.write(remote: other, to: file, modificationTime: nil, logger: Logger(label: "test")) == nil)
        #expect(FileManager.default.fileExists(atPath: file) == false)
    }
}

private struct ShortReadBackend: OmFileReaderBackend {
    let data: Data
    let shortReadOffset: Int
    var count: Int { data.count }

    func prefetchData(offset: Int, count: Int) async throws {}

    func getData(offset: Int, count: Int) async throws -> Data {
        data.subdata(in: offset..<(offset + count - (offset == shortReadOffset ? 1 : 0)))
    }

    func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        try await getData(offset: offset, count: count).withUnsafeBytes(fn)
    }
}

private actor RecordingReadBackend: OmFileReaderBackend {
    nonisolated let data: Data
    nonisolated var count: Int { data.count }
    let delayedOffsets: Set<Int>
    var requests = [Range<Int>]()
    var activeReads = 0
    var peakConcurrentReads = 0
    var firstCompleted = false
    var readsBeforeFirstCompleted = 0
    nonisolated let liveBuffers = LiveReadBuffers()

    init(data: Data, delayedOffsets: Set<Int> = []) {
        self.data = data
        self.delayedOffsets = delayedOffsets
    }

    func prefetchData(offset: Int, count: Int) async throws {}

    func getData(offset: Int, count: Int) async throws -> TrackedReadBuffer {
        requests.append(offset..<(offset + count))
        activeReads += 1
        peakConcurrentReads = max(peakConcurrentReads, activeReads)
        defer { activeReads -= 1 }
        if delayedOffsets.contains(offset) {
            if !firstCompleted { readsBeforeFirstCompleted += 1 }
            let isFirst = offset == delayedOffsets.min()
            // A slow first read must not let the remaining file accumulate in memory.
            try await Task.sleep(for: .milliseconds(isFirst ? 100 : 20))
            if isFirst { firstCompleted = true }
        }
        return TrackedReadBuffer(data: data.subdata(in: offset..<(offset + count)), lifetime: delayedOffsets.contains(offset) ? liveBuffers : nil)
    }

    nonisolated func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        try await getData(offset: offset, count: count).withUnsafeBytes(fn)
    }
}

private final class LiveReadBuffers: Sendable {
    let state = Mutex((current: 0, peak: 0))
}

private final class TrackedReadBuffer: ContiguousBytes, Sendable {
    let data: Data
    let lifetime: LiveReadBuffers?

    init(data: Data, lifetime: LiveReadBuffers?) {
        self.data = data
        self.lifetime = lifetime
        lifetime?.state.withLock {
            $0.current += 1
            $0.peak = max($0.peak, $0.current)
        }
    }

    deinit {
        lifetime?.state.withLock { $0.current -= 1 }
    }

    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try data.withUnsafeBytes(body)
    }
}
