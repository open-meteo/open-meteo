import Foundation
import OmFileFormat
import OmTime
import OmFileIO
import Logging
import Synchronization

/// Grid cells that `sync --bounding-box` keeps: the cells whose centres lie inside the box.
/// Compressed chunks of a weather variable file that hold none of them are written as NaN, so the API returns null for those chunks.
struct SyncBoundingBox: Sendable {
    /// `ny * nx` flags in grid order
    let selectedCells: [Bool]
    let nx: Int

    init(grid: any Gridable, box: BoundingBoxWGS84) throws {
        let inside = Self.selectedCells(grid: grid, box: box)
        guard inside.contains(true) else {
            throw ForecastApiError.generic(message: "the box holds no cell of this grid")
        }
        self.init(selectedCells: inside, nx: grid.nx)
    }

    init(selectedCells: [Bool], nx: Int) {
        self.selectedCells = selectedCells
        self.nx = nx
    }

    /// Longitude from -180 to 180, because some grids count degrees east up to 360
    static func wrapped(longitude: Float) -> Float {
        longitude >= 180 ? longitude - 360 : longitude < -180 ? longitude + 360 : longitude
    }

    /// Cells whose centre lies inside the box
    static func selectedCells(grid: any Gridable, box: BoundingBoxWGS84) -> [Bool] {
        (0 ..< grid.nx * grid.ny).map {
            let (lat, lon) = grid.getCoordinates(gridpoint: $0)
            return box.latitude.contains(lat) && box.longitude.contains(wrapped(longitude: lon))
        }
    }

    /// Select every chunk containing a selected grid cell, across all times and ensemble members.
    /// Returns nil when the spatial dimensions cannot be identified unambiguously.
    func takeChunks(layout: OmFileChunkLayout) -> [Bool]? {
        let dimensions = layout.dimensions
        guard dimensions.count > 0 else { return nil }
        let ny = UInt64(selectedCells.count / nx)

        // Find adjacent [ny, nx] dimensions. Legacy [location, time] files use only a location axis.
        let possibleYDimensions = (0..<dimensions.count - 1).filter { dimension in
            dimensions[dimension] == ny && dimensions[dimension + 1] == UInt64(nx)
        }
        guard possibleYDimensions.count <= 1 else { return nil }
        let yDimension = possibleYDimensions.first
        let xDimension: Int
        if let yDimension {
            xDimension = yDimension + 1
        } else if dimensions.count == 2 && dimensions[0] == UInt64(selectedCells.count) {
            xDimension = 0
        } else {
            return nil
        }

        return layout.map { chunk in
            let columns = chunk.range(in: xDimension)
            guard let yDimension else {
                return columns.contains { location in selectedCells[Int(location)] }
            }
            return chunk.range(in: yDimension).contains { row in
                columns.contains { column in
                    selectedCells[Int(row) * nx + Int(column)]
                }
            }
        }
    }

    /// Combine consecutive selected chunks only when their bytes are adjacent and fit within the limit.
    /// Empty chunks need no read. A single oversized chunk is fetched in one request.
    static func coalescedReadRanges<Ranges: RandomAccessCollection>(ranges: Ranges, takeChunks: [Bool], max limit: Int = runBytes) -> [(chunks: Range<Int>, bytes: Range<Int>)] where Ranges.Index == Int, Ranges.Element == Range<UInt64> {
        var runs = [(chunks: Range<Int>, bytes: Range<Int>)]()
        for i in ranges.indices where takeChunks[i] && !ranges[i].isEmpty {
            let bytes = Int(ranges[i].lowerBound) ..< Int(ranges[i].upperBound)
            if let last = runs.last, last.chunks.upperBound == i, last.bytes.upperBound == bytes.lowerBound,
               bytes.upperBound - last.bytes.lowerBound <= limit {
                runs[runs.count - 1] = (last.chunks.lowerBound ..< i + 1, last.bytes.lowerBound ..< bytes.upperBound)
            } else {
                runs.append((i ..< i + 1, bytes))
            }
        }
        return runs
    }

    /// Write `remote` to `file` with the compressed bytes of the chunks that hold a kept cell as they are, and the others as NaN.
    /// Returns the bytes fetched from `remote`, or nil and writes nothing if the file is not a float array on this grid with scalar attributes only.
    func write<Backend: OmFileReaderBackend>(remote: Backend, url: String, to file: String, modificationTime: Timestamp?, logger: Logger) async throws -> Int? {
        try Task.checkCancellation()
        let startTime = DispatchTime.now()
        let remote = CountingBackend(remote)
        // Prefetch the last 8 KiB which should contain most metadata
        let metadata = OmReaderMemoryCache(backend: remote)
        let prefetchSize = min(remote.count, 8 * 1024)
        try await metadata.prefetchData(offset: remote.count - prefetchSize, count: prefetchSize)
        let reader = try await OmFileReader(fn: metadata)
        guard let array = reader.asArray(of: Float.self) else {
            logger.info("Not a float array, type \(reader.dataType), copying whole: \(file)")
            return nil
        }
        let layout = try array.chunkLayout()
        let dims = layout.dimensions, chunks = layout.chunkDimensions
        guard let take = takeChunks(layout: layout) else {
            logger.info("Not an array on the model grid, dims \(dims), copying whole: \(file)")
            return nil
        }
        var attributes = [OmFileReader<OmReaderMemoryCache<CountingBackend<Backend>>>]()
        for i in 0 ..< reader.numberOfChildren {
            guard let child = try await reader.getChild(i), child.numberOfChildren == 0,
                  (OmDataType.int8.rawValue ... OmDataType.string.rawValue).contains(child.dataType.rawValue) else {
                logger.debug("Attributes are not all plain values, copying whole: \(file)")
                return nil
            }
            attributes.append(child)
        }
        let ranges = try await array.chunkIndex()
        let runs = Self.coalescedReadRanges(ranges: ranges, takeChunks: take)

        let fn = try FileHandle.createNewFile(file: file, overwrite: true, temporary: true)
        let writer = OmFileWriter(fn: fn, initialCapacity: 1024 * 1024)
        let out = try writer.prepareArray(type: Float.self, dimensions: dims, chunkDimensions: chunks, compression: array.compression, scale_factor: array.scaleFactor, add_offset: array.addOffset)
        var nextChunk = 0

        let reads = runs.mapStream(nConcurrent: Self.maxConcurrentReads) { run in
            try Task.checkCancellation()
            let data = try await remote.getData(offset: run.bytes.lowerBound, count: run.bytes.count)
            guard data.withUnsafeBytes({ $0.count }) == run.bytes.count else { throw CurlErrorNonRetry.chunkSizeMismatch }
            return (run, data)
        }
        // mapStream yields in file order and retains only a bounded number of reads.
        for try await (run, buffer) in reads {
            for _ in nextChunk..<run.chunks.lowerBound {
                try Task.checkCancellation()
                try out.writeCompressedChunk(UnsafeRawBufferPointer(start: nil, count: 0))
            }
            try buffer.withUnsafeBytes { bytes in
                for chunkIndex in run.chunks {
                    try Task.checkCancellation()
                    let start = Int(ranges[chunkIndex].lowerBound) - run.bytes.lowerBound
                    let end = Int(ranges[chunkIndex].upperBound) - run.bytes.lowerBound
                    try out.writeCompressedChunk(UnsafeRawBufferPointer(rebasing: bytes[start..<end]))
                }
            }
            nextChunk = run.chunks.upperBound
        }
        for _ in nextChunk..<ranges.count {
            try Task.checkCancellation()
            try out.writeCompressedChunk(UnsafeRawBufferPointer(start: nil, count: 0))
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
        let fetched = remote.fetched.load(ordering: .relaxed)
        let requests = remote.requests.load(ordering: .relaxed)
        let elapsed = startTime.timeElapsedSeconds()
        let rate = Int(Double(fetched) / max(elapsed, 0.001))
        let percent = String(format: "%.1f", 100 * Double(fetched) / Double(remote.count))
        let keptChunks = take.reduce(0) { $0 + ($1 ? 1 : 0) }
        logger.info("Downloaded bbox \(String(url.prefix { $0 != "?" }).stripHttpPassword()) [chunks=\(keptChunks)/\(take.count) ranges=\(runs.count) requests=\(requests) transferred=\(fetched.bytesHumanReadable)/\(remote.count.bytesHumanReadable) (\(percent)%)] in \(elapsed.asSecondsPrettyPrint), \(rate.bytesHumanReadable)/s")
        return fetched
    }

    static let runBytes = 8 * 1024 * 1024
    /// Maximum concurrent range requests per file.
    static let maxConcurrentReads = 8
}

/// Counts read requests and bytes from the wrapped backend for transfer statistics.
final class CountingBackend<Backend: OmFileReaderBackend>: OmFileReaderBackend {
    let backend: Backend
    let fetched = Atomic(0)
    /// Counts backend reads, excluding cache hits and retries internal to the backend.
    let requests = Atomic(0)

    init(_ backend: Backend) {
        self.backend = backend
    }

    var count: Int { backend.count }

    func prefetchData(offset: Int, count: Int) async throws {
        try await backend.prefetchData(offset: offset, count: count)
    }

    func getData(offset: Int, count: Int) async throws -> Backend.DataType {
        requests.add(1, ordering: .relaxed)
        fetched.add(count, ordering: .relaxed)
        return try await backend.getData(offset: offset, count: count)
    }

    func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        requests.add(1, ordering: .relaxed)
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
        guard values.count == 4, !values.contains(nil) else { throw ForecastApiError.generic(message: "--bounding-box must be 4 comma separated numbers: lat1,lon1,lat2,lon2") }
        try self.init(coordinates: values.compactMap { $0 })
    }
}
