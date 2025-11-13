import Foundation
@preconcurrency import SwiftEccodes
import CHelper
import NIOCore
import AsyncAlgorithms
import SwiftParallelBzip2



extension AsyncSequence where Element == ByteBuffer, Self: Sendable {
    /**
     Decode an bzip2 encoded stream of ByteBuffer to a stream of decoded blocks. Throws on invalid data.
     `bufferPolicy` can be used to limit buffering of decoded blocks. Defaults to 4 decoded blocks in the output channel
     */
    public func decodeBzip22(bufferPolicy: AsyncBufferSequencePolicy = .bounded(4)) -> Bzip2AsyncStream<Self> {
        return Bzip2AsyncStream(sequence: self)
    }
}

/**
 Decompress incoming ByteBuffer stream to an Async Sequence of Tasks that will return a ByteBuffer. The task is then executed in the background to allow concurrent processing.
 */
public struct Bzip2AsyncStream<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element

    let sequence: T

    public final class AsyncIterator: AsyncIteratorProtocol {
        /// Collect enough bytes to decompress a single message
        private var iterator: T.AsyncIterator
//        var bitstream: bitstream
//        var buffer: ByteBuffer
//        var parser: parser_state = parser_state()

        fileprivate init(iterator: T.AsyncIterator) {
            self.iterator = iterator
//            self.bitstream = Lbzip2.bitstream()
//            self.buffer = ByteBuffer()
//
//            bitstream.live = 0
//            bitstream.buff = 0
//            bitstream.block = nil
//            bitstream.data = nil
//            bitstream.limit = nil
//            bitstream.eof = false
        }
        
//        func more() async throws {
//            guard let next = try await iterator.next() else {
//                bitstream.eof = true
//                return
//            }
//            buffer = consume next
//
//            // make sure to align readable bytes to 4 bytes
//            let remaining = buffer.readableBytes % 4
//            if remaining != 0 {
//                buffer.writeRepeatingByte(0, count: 4-remaining)
//            }
//        }

        public func next() async throws -> ByteBuffer? {
            return try await iterator.next()
//            if bitstream.data == nil {
//                let bs100k = try await parseFileHeader()
//                print("parser init")
//                parser_init(&parser, bs100k, 0)
//            }
//            print("parse")
//            guard let headerCrc = try await parse(parser: &parser) else {
//                return nil
//            }
//            print("retrieve")
//            let decoder = Decoder(headerCrc: headerCrc, bs100k: parser.bs100k)
//            while try await retrieve(decoder: &decoder.decoder) {
//                try await more()
//            }
//            print("decode")
////            return Task {
//                decoder.decode()
//            print("emit")
//                let res = try decoder.emit()
//            print("done")
//            return res
//            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}

extension Bzip2AsyncStream: Sendable where T: Sendable {
    
}


extension Curl {
    /// Download all grib files and return an array of grib messages
    func downloadGrib(url: String, bzip2Decode: Bool, range: String? = nil, minSize: Int? = nil, nConcurrent: Int = 1, deadLineHours: Double? = nil, headers: [(String, String)] = []) async throws -> [GribMessage] {
        let deadline = deadLineHours.map { Date().addingTimeInterval(TimeInterval($0 * 3600)) } ?? deadline
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)

        // AWS does not allow multi http download ranges. Split download into multiple downloads
        let supportMultiRange = !url.contains("amazonaws.com")
        if !supportMultiRange, let parts = range?.split(separator: ","), parts.count > 1 {
            var messages = [GribMessage]()
            for part in parts {
                messages.append(contentsOf: try await downloadGrib(url: url, bzip2Decode: bzip2Decode, range: String(part), headers: headers))
            }
            return messages
        }

        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: range, minSize: minSize, deadline: deadline, nConcurrent: nConcurrent, waitAfterLastModifiedBeforeDownload: waitAfterLastModifiedBeforeDownload, headers: headers)

            // Retry failed file transfers after this point
            do {
                var messages = [GribMessage]()
                let contentLength = try response.contentLength()
                let checksum = response.headers["x-amz-meta-sha256"].first
                let tracker = TransferAmountTracker(logger: logger, totalSize: contentLength)
                if bzip2Decode {
                    for try await m in response.body.tracker(tracker).sha256verify(checksum).decodeBzip22(bufferPolicy: .bounded(0)).decodeGrib() {
                        try Task.checkCancellation()
                        messages.append(m)
                    }
                } else {
                    for try await m in response.body.tracker(tracker).sha256verify(checksum).decodeGrib() {
                        try Task.checkCancellation()
                        messages.append(m)
                    }
                }
                let trackerTransfered = tracker.transfered.load(ordering: .relaxed)
                totalBytesTransfered.add(trackerTransfered, ordering: .relaxed)
                if let minSize = minSize, trackerTransfered < minSize {
                    throw CurlError.sizeTooSmall
                }
                try await response.waitAfterLastModified(logger: logger, wait: waitAfterLastModified)
                return messages
            } catch {
                try await timeout.check(error: error, delay: nil)
            }
        }
    }
    
    /// Stream GRIB messages. Does not restart stream on error
    func getGribStream(url: String, bzip2Decode: Bool, range: String? = nil, minSize: Int? = nil, nConcurrent: Int = 1, deadLineHours: Double? = nil, headers: [(String, String)] = []) async throws -> AnyAsyncSequence<GribMessage> {
        return try await self.withGribStream(url: url, bzip2Decode: bzip2Decode, nConcurrent: nConcurrent, deadLineHours: deadLineHours, headers: headers) {
            return $0
        }.eraseToAnyAsyncSequence()
    }

    /// Stream GRIB messages. The grib stream might be restarted on error.
    func withGribStream<T>(url: String, bzip2Decode: Bool, range: String? = nil, minSize: Int? = nil, nConcurrent: Int = 1, deadLineHours: Double? = nil, headers: [(String, String)] = [], body: (AnyAsyncSequence<GribMessage>) async throws -> (T)) async throws -> T {
        let deadline = deadLineHours.map { Date().addingTimeInterval(TimeInterval($0 * 3600)) } ?? deadline
        let timeout = TimeoutTracker(logger: logger, deadline: deadline)

        // TODO fix AWS code path
        // TODO use grib stream for GLOFAS downloader

        // AWS does not allow multi http download ranges. Split download into multiple downloads
        /*let supportMultiRange = !url.contains("amazonaws.com")
        if !supportMultiRange, let parts = range?.split(separator: ","), parts.count > 1 {
            var messages = [GribMessage]()
            for part in parts {
                messages.append(contentsOf: try await downloadGrib(url: url, bzip2Decode: bzip2Decode, range: String(part)))
            }
            return messages
        }*/

        while true {
            // Start the download and wait for the header
            let response = try await initiateDownload(url: url, range: range, minSize: minSize, deadline: deadline, nConcurrent: nConcurrent, waitAfterLastModifiedBeforeDownload: waitAfterLastModifiedBeforeDownload, headers: headers)

            // Retry failed file transfers after this point
            do {
                let contentLength = try response.contentLength()
                let tracker = TransferAmountTracker(logger: logger, totalSize: contentLength)
                let result: T
                if bzip2Decode {
                    result = try await body(response.body.tracker(tracker).decodeBzip2(bufferPolicy: .bounded(0)).decodeGrib().eraseToAnyAsyncSequence())
                } else {
                    result = try await body(response.body.tracker(tracker).decodeGrib().eraseToAnyAsyncSequence())
                }
                let trackerTransfered = tracker.transfered.load(ordering: .relaxed)
                totalBytesTransfered.add(trackerTransfered, ordering: .relaxed)
                if let minSize = minSize, trackerTransfered < minSize {
                    throw CurlError.sizeTooSmall
                }
                try await response.waitAfterLastModified(logger: logger, wait: waitAfterLastModified)
                return result
            } catch let error as GribAsyncStreamError {
                // do not retry missing Grib header error
                throw error
            } catch {
                try await timeout.check(error: error)
            }
        }
    }
}

extension GribMessage {
    func dumpCoordinates() throws {
        guard let nx = get(attribute: "Nx")?.toInt() else {
            fatalError("Could not get Nx")
        }
        guard let ny = get(attribute: "Ny")?.toInt() else {
            fatalError("Could not get Ny")
        }
        print("nx=\(nx) ny=\(ny)")
        for (i, (latitude, longitude, value)) in try iterateCoordinatesAndValues().enumerated() {
            if i % 10_000 == 0 || i == ny * nx - 1 {
                print("grid \(i) lat \(latitude) lon \(longitude) value \(value)")
            }
        }
    }

    /// Read data as 2D grid assuming given `nx` and `ny`. Error is dimensions to not agree
    /// if `shift180LongitudeAndFlipLatitudeIfRequired` is set, automatically check the first and last grid points to see if the grid needs to be shifted to alwys start at -90/-180.
    func to2D(nx: Int, ny: Int, shift180LongitudeAndFlipLatitudeIfRequired: Bool) throws -> GribArray2D {
        var array2D = GribArray2D(nx: nx, ny: ny)
        try array2D.load(message: self, shift180LongitudeAndFlipLatitudeIfRequired: shift180LongitudeAndFlipLatitudeIfRequired)
        return array2D
    }
}

struct GribArray2D {
    var bitmap: [Int]
    var double: [Double]
    var array: Array2D

    public init(nx: Int, ny: Int) {
        array = Array2D(data: [Float](repeating: .nan, count: nx * ny), nx: nx, ny: ny)
        bitmap = .init(repeating: 0, count: nx * ny)
        double = .init(repeating: .nan, count: nx * ny)
    }

    /// Read data as 2D grid assuming given `nx` and `ny`. Error is dimensions to not agree
    /// if `shift180LongitudeAndFlipLatitudeIfRequired` is set, automatically check the first and last grid points to see if the grid needs to be shifted to alwys start at -90/-180.
    public mutating func load(message: GribMessage, shift180LongitudeAndFlipLatitudeIfRequired: Bool = false) throws {
        guard let gridType = message.get(attribute: "gridType") else {
            fatalError("Could not get gridType")
        }
        if gridType == "reduced_gg" {
            guard let numberOfDataPoints = message.get(attribute: "numberOfDataPoints")?.toInt() else {
                fatalError("Could not get numberOfDataPoints")
            }
            guard numberOfDataPoints == array.count else {
                fatalError("GRIB dimensions (count=\(numberOfDataPoints)) do not match domain grid dimensions (nx=\(array.nx), ny=\(array.ny))")
            }
        } else {
            guard let nx = message.get(attribute: "Nx")?.toInt() else {
                fatalError("Could not get Nx")
            }
            guard let ny = message.get(attribute: "Ny")?.toInt() else {
                fatalError("Could not get Ny")
            }
            guard nx == array.nx, ny == array.ny else {
                fatalError("GRIB dimensions (nx=\(nx), ny=\(ny)) do not match domain grid dimensions (nx=\(array.nx), ny=\(array.ny))")
            }
        }
        try message.loadDoubleNotNaNChecked(into: &double)
        for i in double.indices {
            array.data[i] = Float(double[i])
        }
        if try message.loadBitmap(into: &bitmap) {
            for i in bitmap.indices {
                if bitmap[i] == 0 {
                    array.data[i] = .nan
                }
            }
        }

        /// Some global grids start at latitude 90 and longitude 0. As a convention we always use -90 and -180.
        if shift180LongitudeAndFlipLatitudeIfRequired, gridType == "regular_ll" {
            guard let latitudeFirst = message.get(attribute: "latitudeOfFirstGridPointInDegrees").flatMap(Float.init),
                  let longitudeFirst = message.get(attribute: "longitudeOfFirstGridPointInDegrees").flatMap(Float.init) else {
                fatalError("Could not read first grid point coordinates")
            }
            guard let latitudeLast = message.get(attribute: "latitudeOfLastGridPointInDegrees").flatMap(Float.init),
                  let longitudeLast = message.get(attribute: "longitudeOfLastGridPointInDegrees").flatMap(Float.init) else {
                fatalError("Could not read last grid point coordinates")
            }
            let flipLatitude = latitudeFirst > latitudeLast
            let shiftLongitude = (-2...2).contains(longitudeFirst) && (358...362).contains(longitudeLast)
            if shiftLongitude {
                array.shift180Longitudee()
            }
            if flipLatitude {
                array.flipLatitude()
            }
        }
    }
}
