import Foundation
import OmFileFormat
import OmTime
import OmFileIO
import Logging
import Synchronization

/// Grid cells that `sync --bbox` keeps: the cells whose centres lie inside the box.
/// Compressed chunks of a weather variable file that hold none of them are written as NaN, so the API returns null for those chunks.
struct SyncBoundingBox: Sendable {
    /// `ny * nx` flags in grid order
    let cells: [Bool]
    let nx: Int

    init(grid: any Gridable, box: BoundingBoxWGS84) throws {
        let inside = Self.cells(grid: grid, box: box)
        guard inside.contains(true) else {
            throw ForecastApiError.generic(message: "the box holds no cell of this grid")
        }
        self.init(cells: inside, nx: grid.nx)
    }

    init(cells: [Bool], nx: Int) {
        self.cells = cells
        self.nx = nx
    }

    /// Longitude from -180 to 180, because some grids count degrees east up to 360
    static func wrapped(longitude: Float) -> Float {
        longitude >= 180 ? longitude - 360 : longitude < -180 ? longitude + 360 : longitude
    }

    /// Cells whose centre lies inside the box
    static func cells(grid: any Gridable, box: BoundingBoxWGS84) -> [Bool] {
        (0 ..< grid.nx * grid.ny).map {
            let (lat, lon) = grid.getCoordinates(gridpoint: $0)
            return box.latitude.contains(lat) && box.longitude.contains(wrapped(longitude: lon))
        }
    }

    /// One flag per chunk in chunk order (last dimension fastest): true if the chunk holds a kept cell. Nil if the dimensions are not the grid.
    /// The grid is `[ny, nx]` among the dimensions, e.g. `[ny, nx, time]` or `[member, ny, nx, time]`, or the flat `[ny * nx, time]` of legacy files;
    /// the other dimensions do not matter.
    func takeChunks(layout: OmFileChunkLayout) -> [Bool]? {
        guard let dims = layout.first?.arrayDimensions else { return nil }
        let ny = UInt64(cells.count / nx)
        let pairs = (0 ..< max(0, dims.count - 1)).filter { dims[$0] == ny && dims[$0 + 1] == UInt64(nx) }
        // Dimension sizes alone cannot distinguish multiple matching spatial axes.
        guard pairs.count <= 1 else { return nil }
        let pair = pairs.first
        /// Legacy files are exactly `[ny * nx, time]`; any other dimension that happens to equal the cell count is not the grid
        let isLegacyFlat = dims.count == 2 && dims[0] == UInt64(cells.count)
        guard pair != nil || isLegacyFlat else { return nil }
        let xDimension = pair.map { $0 + 1 } ?? 0
        // Time and member chunks share spatial extents. Scan each extent only once.
        var spatial = [UInt64: Bool]()
        return layout.map { chunk in
            let firstCell = (pair.map { chunk.offset[$0] * UInt64(nx) } ?? 0) + chunk.offset[xDimension]
            if let take = spatial[firstCell] { return take }
            let take = chunk.containsCell(yDimension: pair, xDimension: xDimension) { cells[$0] }
            spatial[firstCell] = take
            return take
        }
    }

    /// Byte ranges to fetch for the chunks to take: neighbours closer than `merge` bytes are joined, as long as a run stays within `max` bytes (a larger chunk is a run on its own).
    /// Each run has the range of chunk indices it holds. Empty chunks are NaN and need no bytes.
    static func runs<Ranges: RandomAccessCollection>(ranges: Ranges, take: [Bool], merge: Int, max limit: Int) -> [(chunks: Range<Int>, bytes: Range<Int>)] where Ranges.Index == Int, Ranges.Element == Range<UInt64> {
        var runs = [(chunks: Range<Int>, bytes: Range<Int>)]()
        for i in ranges.indices where take[i] && !ranges[i].isEmpty {
            let bytes = Int(ranges[i].lowerBound) ..< Int(ranges[i].upperBound)
            if let last = runs.last, bytes.lowerBound - last.bytes.upperBound <= merge, bytes.upperBound - last.bytes.lowerBound <= limit {
                runs[runs.count - 1] = (last.chunks.lowerBound ..< i + 1, last.bytes.lowerBound ..< bytes.upperBound)
            } else {
                runs.append((i ..< i + 1, bytes))
            }
        }
        return runs
    }

    /// Write `remote` to `file` with the compressed bytes of the chunks that hold a kept cell as they are, and the others as NaN.
    /// Returns the bytes fetched from `remote`, or nil and writes nothing if the file is not a float array on this grid with scalar attributes only.
    func write<Backend: OmFileReaderBackend>(remote: Backend, to file: String, modificationTime: Timestamp?, logger: Logger, runsInFlight: Int = SyncBoundingBox.runsInFlightTotal) async throws -> Int? {
        try Task.checkCancellation()
        let remote = CountingBackend(remote)
        let reader = try await OmFileReader(fn: remote)
        /// `chunkIndex()` reads the complete lookup table in one request.
        guard let array = reader.asArray(of: Float.self) else {
            logger.info("Not a float array, type \(reader.dataType), copying whole: \(file)")
            return nil
        }
        let dims = array.getDimensions(), chunks = array.getChunkDimensions()
        guard let take = try takeChunks(layout: array.chunkLayout()) else {
            logger.info("Not an array on the model grid, dims \(dims), copying whole: \(file)")
            return nil
        }
        var attributes = [OmFileReader<CountingBackend<Backend>>]()
        for i in 0 ..< reader.numberOfChildren {
            guard let child = try await reader.getChild(i), child.numberOfChildren == 0,
                  (OmDataType.int8.rawValue ... OmDataType.string.rawValue).contains(child.dataType.rawValue) else {
                logger.debug("Attributes are not all plain values, copying whole: \(file)")
                return nil
            }
            attributes.append(child)
        }
        let ranges = try await array.chunkIndex()
        let runs = Self.runs(ranges: ranges, take: take, merge: Self.mergeBytes, max: Self.runBytes)

        /// Runs are fetched up to `runsInFlight` ahead of the writer, which takes them in order. A failed run fails the file
        var pending = [Task<Backend.DataType, any Error>]()
        var next = 0
        defer { pending.forEach { $0.cancel() } }
        let fn = try FileHandle.createNewFile(file: file, overwrite: true, temporary: true)
        let writer = OmFileWriter(fn: fn, initialCapacity: 1024 * 1024)
        let out = try writer.prepareArray(type: Float.self, dimensions: dims, chunkDimensions: chunks, compression: array.compression, scale_factor: array.scaleFactor, add_offset: array.addOffset)
        var run = 0 ..< 0, runStart = 0, taken = 0, data: Backend.DataType?
        for i in take.indices {
            try Task.checkCancellation()
            guard take[i], !ranges[i].isEmpty else {
                /// An empty payload appends one zero-byte NaN chunk, including smaller edge chunks.
                try out.writeCompressedChunk(UnsafeRawBufferPointer(start: nil, count: 0))
                continue
            }
            if !run.contains(i) {
                while pending.count < max(1, runsInFlight), next < runs.count {
                    let bytes = runs[next].bytes
                    pending.append(Task { try await remote.getData(offset: bytes.lowerBound, count: bytes.count) })
                    next += 1
                }
                (run, runStart) = (runs[taken].chunks, runs[taken].bytes.lowerBound)
                taken += 1
                let task = pending.removeFirst()
                data = try await withTaskCancellationHandler {
                    try await task.value
                } onCancel: {
                    task.cancel()
                }
                // A short body would let the slices below read past the buffer, which a release build does not check
                guard data!.withUnsafeBytes({ $0.count }) == runs[taken - 1].bytes.count else { throw CurlErrorNonRetry.chunkSizeMismatch }
            }
            let start = Int(ranges[i].lowerBound) - runStart
            try data!.withUnsafeBytes { try out.writeCompressedChunk(UnsafeRawBufferPointer(rebasing: $0[start ..< start + Int(ranges[i].count)])) }
        }
        let children = try attributes.map { try $0.copyScalar(to: writer) }
        let root = try writer.write(array: try out.finalise(), name: reader.getName(), children: children)
        try writer.writeTrailer(rootVariable: root)
        if let modificationTime {
            let times = [timespec](repeating: timespec(tv_sec: modificationTime.timeIntervalSince1970, tv_nsec: 0), count: 2)
            guard futimens(fn.fileDescriptor, times) == 0 else {
                throw CurlError.futimes(error: String(cString: strerror(errno)))
            }
        }
        try Task.checkCancellation()
        try fn.linkTemporary(file: file)
        return remote.fetched.load(ordering: .relaxed)
    }

    /// Bound each read-ahead buffer to 16 MiB, unless a single chunk is larger.
    static let runBytes = 16 * 1024 * 1024
    /// Read small gaps between selected chunks to reduce HTTP request overhead.
    static let mergeBytes = 1024 * 1024
    /// Read-ahead budget per model, shared between concurrently copied files.
    static let runsInFlightTotal = 8
}

/// Sums the bytes read from the wrapped backend, for the transfer statistics
final class CountingBackend<Backend: OmFileReaderBackend>: OmFileReaderBackend {
    let backend: Backend
    let fetched = Atomic(0)

    init(_ backend: Backend) {
        self.backend = backend
    }

    var count: Int { backend.count }

    func prefetchData(offset: Int, count: Int) async throws {
        try await backend.prefetchData(offset: offset, count: count)
    }

    func getData(offset: Int, count: Int) async throws -> Backend.DataType {
        fetched.add(count, ordering: .relaxed)
        return try await backend.getData(offset: offset, count: count)
    }

    func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        fetched.add(count, ordering: .relaxed)
        return try await backend.withData(offset: offset, count: count, fn: fn)
    }
}

extension OmFileReader {
    /// Write this scalar variable with its name to `writer`
    func copyScalar<W: OmFileWriterBackend>(to writer: OmFileWriter<W>) throws -> OmOffsetSize {
        func copy<T: OmFileScalarDataTypeProtocol>(_: T.Type) throws -> OmOffsetSize {
            guard let value: T = readScalar() else {
                throw OmFileFormatSwiftError.invalidDataType
            }
            return try writer.write(value: value, name: getName(), children: [])
        }
        switch dataType {
        case .int8: return try copy(Int8.self)
        case .uint8: return try copy(UInt8.self)
        case .int16: return try copy(Int16.self)
        case .uint16: return try copy(UInt16.self)
        case .int32: return try copy(Int32.self)
        case .uint32: return try copy(UInt32.self)
        case .int64: return try copy(Int.self)
        case .uint64: return try copy(UInt.self)
        case .float: return try copy(Float.self)
        case .double: return try copy(Double.self)
        case .string: return try copy(String.self)
        default: throw OmFileFormatSwiftError.invalidDataType
        }
    }
}

extension BoundingBoxWGS84 {
    /// Parse `lat1,lon1,lat2,lon2`. A part that is not a number fails like a wrong number of values
    init(commaSeparated: String) throws {
        let values = commaSeparated.split(separator: ",", omittingEmptySubsequences: false).map { Float($0.trimmingCharacters(in: .whitespaces)) }
        try self.init(coordinates: values.contains(nil) ? [] : values.compactMap { $0 })
    }
}
