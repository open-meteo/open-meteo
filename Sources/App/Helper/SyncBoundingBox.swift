import Foundation
import OmFileFormat
import OmTime
import OmFileIO
import Logging

/// Grid cells that `sync --bbox` keeps: the cells inside the box, widened by the grid search radius plus one.
/// Chunks of a weather variable file that hold none of them are written as NaN, so the API returns null outside the box.
struct SyncBoundingBox: Sendable {
    let ny: Int
    let nx: Int
    /// Rows and columns from the first to the last kept cell
    let rows: Range<Int>
    let columns: Range<Int>
    /// Kept cells, `ny * nx`, unless every cell of `rows` and `columns` is kept
    let cells: [Bool]?

    /// Values decoded per read, at most 4 chunk rows. With `io_size_max` of 2 MiB this keeps a handful of ranges in flight per read,
    /// because the remote reader allows 10 seconds per range including the wait for a connection
    static let bufferValues = 2 * 1024 * 1024

    /// Reads in flight per file, because each waits a few round trips. Small reads, e.g. one per ring of a Gaussian grid, need many in flight
    static let readsInFlight = 32

    /// Decoded values of the reads in flight per file, so a file holds at most 72 MB of reads including the one being written
    static let valuesInFlight = 8 * bufferValues

    init(grid: any Gridable, box: BoundingBoxWGS84) throws {
        /// A Gaussian grid stores its latitude rings one after another in one row, so a box is a set of cells
        if grid is GaussianGrid {
            self = try SyncBoundingBox(grid: grid) { box.latitude.contains($0) && box.longitude.contains($1) }
            return
        }
        /// Native icosahedral grids store all points in one row without neighbours to widen by
        guard grid.ny > 1 else {
            throw ForecastApiError.generic(message: "regional sync is not supported for this grid")
        }
        ny = grid.ny
        nx = grid.nx
        var y0 = Int.max, y1 = -1, x0 = Int.max, x1 = -1
        for y in 0 ..< ny {
            for x in 0 ..< nx {
                let (lat, lon) = grid.getCoordinates(gridpoint: y * nx + x)
                let lon180 = (lon + 540).truncatingRemainder(dividingBy: 360) - 180
                guard box.latitude.contains(lat), box.longitude.contains(lon180) else {
                    continue
                }
                y0 = min(y0, y); y1 = max(y1, y); x0 = min(x0, x); x1 = max(x1, x)
            }
        }
        /// The API searches around the nearest cell, which may lie one row or column outside the box, so keep one more
        let r = grid.searchRadius + 1
        rows = y1 < 0 ? 0 ..< 0 : max(0, y0 - r) ..< min(ny, y1 + r + 1)
        columns = x1 < 0 ? 0 ..< 0 : max(0, x0 - r) ..< min(nx, x1 + r + 1)
        cells = nil
    }

    /// Keep the cells whose centre `inside(latitude, longitude)` accepts, with longitudes from -180 to 180, and every cell within the grid search radius plus one of them:
    /// rows and columns on a regular grid, neighbouring rings and points along each ring on a Gaussian grid
    init(grid: any Gridable, inside: (Float, Float) -> Bool) throws {
        let gaussian = grid as? GaussianGrid
        guard grid.ny > 1 || gaussian != nil else {
            throw ForecastApiError.generic(message: "regional sync is not supported for this grid")
        }
        let ny = grid.ny, nx = grid.nx, r = grid.searchRadius + 1
        var cells = [Bool](repeating: false, count: ny * nx)
        if let gaussian {
            let rings = 2 * gaussian.type.latitudeLines
            for i in 0 ..< nx {
                let (lat, lon) = grid.getCoordinates(gridpoint: i)
                guard inside(lat, lon >= 180 ? lon - 360 : lon) else {
                    continue
                }
                /// Rings have different point counts, so take the point at the same longitude in each neighbouring ring, then `r` points either side
                let (y, x, points) = gaussian.type.getPos(gridpoint: i)
                for ring in max(0, y - r) ..< min(rings, y + r + 1) {
                    let ringPoints: Int = gaussian.nxOf(y: ring)
                    let centre = Int((Double(x) * Double(ringPoints) / Double(points)).rounded())
                    for k in 0 ..< min(2 * r + 1, ringPoints) {
                        let along: Int = ((centre + k - r) % ringPoints + ringPoints) % ringPoints
                        cells[gaussian.integral(y: ring) + along] = true
                    }
                }
            }
        } else {
            /// Widened along each row first, then along each column
            var wide = [Bool](repeating: false, count: ny * nx)
            for i in 0 ..< ny * nx {
                let (lat, lon) = grid.getCoordinates(gridpoint: i)
                let wrapped: Float = lon >= 180 ? lon - 360 : lon < -180 ? lon + 360 : lon
                guard inside(lat, wrapped) else {
                    continue
                }
                let (y, x) = i.quotientAndRemainder(dividingBy: nx)
                for xx in max(0, x - r) ..< min(nx, x + r + 1) {
                    wide[y * nx + xx] = true
                }
            }
            for y in 0 ..< ny {
                for x in 0 ..< nx where wide[y * nx + x] {
                    for yy in max(0, y - r) ..< min(ny, y + r + 1) {
                        cells[yy * nx + x] = true
                    }
                }
            }
        }
        let kept: [Int] = cells.indices.filter { cells[$0] }
        let keptColumns: [Int] = kept.map { $0 % nx }
        self.ny = ny
        self.nx = nx
        self.rows = kept.isEmpty ? 0 ..< 0 : kept[0] / nx ..< kept[kept.count - 1] / nx + 1
        self.columns = kept.isEmpty ? 0 ..< 0 : keptColumns.min()! ..< keptColumns.max()! + 1
        self.cells = cells
    }

    /// True if a kept cell lies in these rows and columns
    func keeps(rows: Range<Int>, columns: Range<Int>) -> Bool {
        let rows = rows.clamped(to: self.rows), columns = columns.clamped(to: self.columns)
        guard let cells else {
            return !rows.isEmpty && !columns.isEmpty
        }
        return rows.contains { y in columns.contains { cells[y * nx + $0] } }
    }

    /// Write `remote` to `file` with every chunk without a kept cell as NaN. Kept chunks are decoded and encoded again with the same settings.
    /// Returns false and writes nothing if the file is not a 3D float array `[ny, nx, time]` on this grid with scalar attributes only.
    func write<Backend: OmFileReaderBackend>(remote: Backend, to file: String, modificationTime: Timestamp?, logger: Logger, bufferValues: Int = Self.bufferValues) async throws -> Bool {
        let reader = try await OmFileReader(fn: remote)
        /// Gaps up to 16 KiB are read along. A larger gap would join the chunk rows of a narrow box into whole rows of the grid
        let array = reader.asArray(of: Float.self, io_size_max: 2 * 1024 * 1024, io_size_merge: 16 * 1024)
        let dims = array?.getDimensions().map(Int.init) ?? []
        guard let array, dims.count == 3, dims[0] == ny, dims[1] == nx else {
            logger.info("Not a float array [\(ny), \(nx), time], copying whole: \(file)")
            return false
        }
        let chunks = array.getChunkDimensions().map(Int.init)
        var attributes = [OmFileReader<Backend>]()
        for i in 0 ..< reader.numberOfChildren {
            guard let child = try await reader.getChild(i), child.numberOfChildren == 0,
                  (OmDataType.int8.rawValue ... OmDataType.string.rawValue).contains(child.dataType.rawValue) else {
                logger.debug("Attributes are not all plain values, copying whole: \(file)")
                return false
            }
            attributes.append(child)
        }
        let nChunks: [Int] = (0 ..< 3).map { (dims[$0] + chunks[$0] - 1) / chunks[$0] }
        var kept = [Bool]()
        /// Chunk columns from the first to the last kept chunk of each chunk row
        var spans = [Range<Int>]()
        for cy in 0 ..< nChunks[0] {
            let rows: Range<Int> = cy * chunks[0] ..< (cy + 1) * chunks[0]
            var first = nChunks[1], last = -1
            for cx in 0 ..< nChunks[1] {
                let keep = keeps(rows: rows, columns: cx * chunks[1] ..< (cx + 1) * chunks[1])
                kept.append(keep)
                if keep {
                    first = min(first, cx)
                    last = cx
                }
            }
            spans.append(last < 0 ? 0 ..< 0 : first ..< last + 1)
        }
        /// A read covers some kept chunks of one chunk row, or the kept chunk columns of up to 4 chunk rows. Chunks in between that are not kept are read too
        let columnValues: Int = chunks[0] * chunks[1] * dims[2]
        let chunksPerRead: Int = max(1, min(4 * nChunks[1], bufferValues / columnValues))
        /// Chunk rows and columns of each read, in the order the chunks are written: a run of kept chunks in one row,
        /// or the kept chunks of following rows too while a row holds one run and all fit in one read
        var reads = [(rows: Range<Int>, columns: Range<Int>)]()
        for cy in 0 ..< nChunks[0] {
            for cx in spans[cy] where kept[cy * nChunks[1] + cx] {
                if let last = reads.last, last.rows.contains(cy), last.columns.contains(cx) {
                    continue
                }
                var rows = cy ..< cy + 1
                var end = cx + 1
                while end < min(spans[cy].upperBound, cx + chunksPerRead), kept[cy * nChunks[1] + end] {
                    end += 1
                }
                var columns = cx ..< end
                let wholeRow = columns == spans[cy]
                while wholeRow, rows.count < 4, rows.upperBound < nChunks[0], !spans[rows.upperBound].isEmpty {
                    let next = spans[rows.upperBound]
                    let union: Range<Int> = min(columns.lowerBound, next.lowerBound) ..< max(columns.upperBound, next.upperBound)
                    guard (rows.count + 1) * union.count <= chunksPerRead else {
                        break
                    }
                    rows = rows.lowerBound ..< rows.upperBound + 1
                    columns = union
                }
                reads.append((rows, columns))
            }
        }
        /// Up to `readsInFlight` reads run ahead of the writer, which takes their values in order. A failed read fails the file
        var pending = [(task: Task<[Float], any Error>, values: Int)]()
        defer { pending.forEach { $0.task.cancel() } }
        var nextRead = 0, valuesInFlight = 0
        func takeRead() async throws -> [Float] {
            while pending.count < Self.readsInFlight, nextRead < reads.count {
                let y: Range<Int> = reads[nextRead].rows.lowerBound * chunks[0] ..< min(reads[nextRead].rows.upperBound * chunks[0], ny)
                let x: Range<Int> = reads[nextRead].columns.lowerBound * chunks[1] ..< min(reads[nextRead].columns.upperBound * chunks[1], nx)
                let values: Int = y.count * x.count * dims[2]
                guard pending.isEmpty || valuesInFlight + values <= Self.valuesInFlight else {
                    break
                }
                let range: InlineArray<3, Range<UInt64>> = [UInt64(y.lowerBound) ..< UInt64(y.upperBound), UInt64(x.lowerBound) ..< UInt64(x.upperBound), 0 ..< UInt64(dims[2])]
                pending.append((Task { try await array.readConcurrent(range: range) }, values))
                valuesInFlight += values
                nextRead += 1
            }
            let read = pending.removeFirst()
            valuesInFlight -= read.values
            return try await read.task.value
        }
        /// One chunk column copied out of a read, because the encoder cannot take a column offset into a wider array
        let column = UnsafeMutableBufferPointer<Float>.allocate(capacity: columnValues)
        defer { column.deallocate() }

        let fn = try FileHandle.createNewFile(file: file, overwrite: true, temporary: true)
        let writer = OmFileWriter(fn: fn, initialCapacity: 1024 * 1024)
        let out = try writer.prepareArray(type: Float.self, dimensions: dims.map(UInt64.init), chunkDimensions: chunks.map(UInt64.init), compression: array.compression, scale_factor: array.scaleFactor, add_offset: array.addOffset)
        /// One NaN chunk per chunk shape. Only the last chunk along a dimension may be smaller
        var nanChunks = [[UInt8]?](repeating: nil, count: 8)
        /// Chunk rows and columns held in `values`
        var read = (rows: 0 ..< 0, columns: 0 ..< 0), values = [Float]()
        for cy in 0 ..< nChunks[0] {
            for cx in 0 ..< nChunks[1] {
                guard kept[cy * nChunks[1] + cx] else {
                    for ct in 0 ..< nChunks[2] {
                        let lastRow: Int = cy == nChunks[0] - 1 ? 4 : 0
                        let lastColumn: Int = cx == nChunks[1] - 1 ? 2 : 0
                        let lastTime: Int = ct == nChunks[2] - 1 ? 1 : 0
                        let shape = lastRow + lastColumn + lastTime
                        if nanChunks[shape] == nil {
                            let height: Int = min(chunks[0], dims[0] - cy * chunks[0])
                            let width: Int = min(chunks[1], dims[1] - cx * chunks[1])
                            let length: Int = min(chunks[2], dims[2] - ct * chunks[2])
                            let count = height * width * length
                            nanChunks[shape] = try out.compressChunk(chunkIndex: (cy * nChunks[1] + cx) * nChunks[2] + ct, array: [Float](repeating: .nan, count: count))
                        }
                        try out.writeCompressedChunk(nanChunks[shape]!)
                    }
                    continue
                }
                if !read.rows.contains(cy) || !read.columns.contains(cx) {
                    /// The oldest read in flight, or the next one if none is
                    read = reads[nextRead - pending.count]
                    values = try await takeRead()
                }
                let y: Range<Int> = read.rows.lowerBound * chunks[0] ..< min(read.rows.upperBound * chunks[0], ny)
                let x: Range<Int> = read.columns.lowerBound * chunks[1] ..< min(read.columns.upperBound * chunks[1], nx)
                let height: Int = min(chunks[0], ny - cy * chunks[0])
                let width: Int = min(chunks[1], nx - cx * chunks[1]) * dims[2]
                for row in 0 ..< height {
                    let start: Int = ((cy * chunks[0] + row - y.lowerBound) * x.count + cx * chunks[1] - x.lowerBound) * dims[2]
                    values.withUnsafeBufferPointer { column.baseAddress!.advanced(by: row * width).update(from: $0.baseAddress!.advanced(by: start), count: width) }
                }
                try out.writeData(pointer: UnsafeBufferPointer(start: column.baseAddress, count: height * width), arrayDimensions: [UInt64(height), UInt64(width / dims[2]), UInt64(dims[2])])
            }
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
        try fn.linkTemporary(file: file)
        return true
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
