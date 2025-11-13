import Foundation
import NIOCore
import AsyncAlgorithms
import Lbzip2

public enum SwiftParallelBzip2Error: Error {
    case invalidBzip2Header
    case invalidStreamHeader
    case streamCRCMismatch
    case blockCRCMismatch
    case unexpectedEndOfStream
    case unexpectedParserError(UInt32)
    case unexpectedDecoderError(UInt32)
}

extension AsyncSequence where Element == ByteBuffer, Self: Sendable {
    /**
     Decode an bzip2 encoded stream of ByteBuffer to a stream of decoded blocks. Throws on invalid data.
     `bufferPolicy` can be used to limit buffering of decoded blocks. Defaults to 4 decoded blocks in the output channel
     */
    public func decodeBzip2(bufferPolicy: AsyncBufferSequencePolicy = .bounded(4)) -> AsyncThrowingMapSequence<AsyncBufferSequence<Bzip2AsyncStream<Self>>, ByteBuffer> {
        return Bzip2AsyncStream(sequence: self).buffer(policy: bufferPolicy).map { task in
            return try await task.value
        }
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
        var iterator: T.AsyncIterator
        var bitstream: Lbzip2.bitstream
        var buffer: ByteBuffer
        var parser: Lbzip2.parser_state = parser_state()

        fileprivate init(iterator: T.AsyncIterator) {
            self.iterator = iterator
            self.bitstream = Lbzip2.bitstream()
            self.buffer = ByteBuffer()
        }
        
        func more() async throws {
            guard let next = try await iterator.next() else {
                bitstream.eof = true
                return
            }
            buffer = consume next
            
            // make sure to align readable bytes to 4 bytes
            let remaining = buffer.readableBytes % 4
            if remaining != 0 {
                buffer.writeRepeatingByte(0, count: 4-remaining)
            }
        }

        public func next() async throws -> Task<ByteBuffer, any Error>? {
            if bitstream.data == nil {
                let bs100k = try await parseFileHeader()
                parser_init(&parser, bs100k, 0)
            }
            guard let headerCrc = try await parse(parser: &parser) else {
                return nil
            }
            let decoder = Decoder(headerCrc: headerCrc, bs100k: parser.bs100k)
            while try await retrieve(decoder: &decoder.decoder) {
                try await more()
            }
            return Task {
                decoder.decode()
                return try decoder.emit()
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}

extension Bzip2AsyncStream: Sendable where T: Sendable {
    
}

extension Bzip2AsyncStream.AsyncIterator {
    func parseFileHeader() async throws -> Int32 {
        guard var firstData = try await iterator.next() else {
            throw SwiftParallelBzip2Error.unexpectedEndOfStream
        }
        buffer.writeBuffer(&firstData)
        guard let head: Int32 = buffer.readInteger() else {
            throw SwiftParallelBzip2Error.unexpectedEndOfStream
        }
        guard head >= 0x425A6830 + 1 && head <= 0x425A6830 + 9 else {
            throw SwiftParallelBzip2Error.invalidBzip2Header
        }
        let bs100k = head - 0x425A6830
        return bs100k
    }
    
    /// Return true until all data is available
    func retrieve(decoder: inout decoder_state) async throws -> Bool {
        let ret = buffer.readWithUnsafeReadableBytes { ptr in
            bitstream.data = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self)
            bitstream.limit = ptr.baseAddress?.advanced(by: ptr.count).assumingMemoryBound(to: UInt32.self)
            //print("Bitstream IN \(bitstream.data!) \(bitstream.limit!)")
            let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.retrieve(&decoder, &bitstream)))
            assert(bitstream.data <= bitstream.limit)
            //print("Bitstream OUT \(bitstream.data!) \(bitstream.limit!)")
            let bytesRead = ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0
            //print("retrieve bytesRead \(bytesRead) ret=\(ret)")
            return (bytesRead, ret)
        }
        switch ret {
        case Lbzip2.OK:
            return false
        case Lbzip2.MORE:
            return true
        default:
            throw SwiftParallelBzip2Error.unexpectedDecoderError(ret.rawValue)
        }
    }
    
    func parse(parser: inout parser_state) async throws -> UInt32? {
        /* Parse stream headers until a compressed block or end of stream is reached.

           Possible return codes:
             OK          - a compressed block was found
             FINISH      - end of stream was reached
             MORE        - more input is need, parsing was suspended
             ERR_HEADER  - invalid stream header
             ERR_STRMCRC - stream CRC does not match
             ERR_EOF     - unterminated stream (EOF reached before end of stream)

           garbage is set only when returning FINISH.  It is number of garbage bits
           consumed after end of stream was reached.
        */
        while true {
            var header = header()
            parserLoop: while true {
                let parserReturn = buffer.readWithUnsafeReadableBytes { ptr in
                    bitstream.data = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self)
                    bitstream.limit = ptr.baseAddress?.advanced(by: ptr.count).assumingMemoryBound(to: UInt32.self)
                    var garbage: UInt32 = 0
                    let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.parse(&parser, &header, &bitstream, &garbage)))
                    assert(garbage < 32)
                    assert(bitstream.data <= bitstream.limit)
                    let bytesRead = ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0
                    //print("parser bytesRead \(bytesRead)")
                    return (bytesRead, ret)
                }
                switch parserReturn {
                case OK:
                    return header.crc
                case FINISH:
                    return nil
                case MORE:
                    try await more()
                    continue
                case ERR_HEADER:
                    throw SwiftParallelBzip2Error.invalidStreamHeader
                case ERR_STRMCRC:
                    throw SwiftParallelBzip2Error.streamCRCMismatch
                case ERR_EOF:
                    throw SwiftParallelBzip2Error.streamCRCMismatch
                default:
                    throw SwiftParallelBzip2Error.unexpectedParserError(parserReturn.rawValue)
                }
            }
        }
    }
}

fileprivate final class Decoder {
    var decoder = Lbzip2.decoder_state()
    let headerCrc: UInt32
    let bs100k: Int32
    
    public init(headerCrc: UInt32, bs100k: Int32) {
        decoder_init(&decoder)
        self.headerCrc = headerCrc
        self.bs100k = bs100k
    }
    
    func decode() {
        // Decode can now run in a different thread
        // Decoder does not need buffered input data anymore
        Lbzip2.decode(&decoder)
    }
    
    func emit() throws(SwiftParallelBzip2Error) -> ByteBuffer {
        var out = ByteBuffer()
        // Reserve the maximum output block size
        out.writeWithUnsafeMutableBytes(minimumWritableBytes: Int(bs100k*100_000)) { ptr in
            var outsize: Int = ptr.count
            guard Lbzip2.emit(&decoder, ptr.baseAddress, &outsize) == Lbzip2.OK.rawValue else {
                // Emit should not fail because enough output capacity is available
                fatalError("emit failed")
            }
            return ptr.count - outsize
        }
        guard decoder.crc == headerCrc else {
            throw .blockCRCMismatch
        }
        //print("emit \(out.readableBytes) bytes")
        return out
    }
    
    deinit {
        decoder_free(&decoder)
    }
}

extension decoder_state: @retroactive @unchecked Sendable {
    
}
