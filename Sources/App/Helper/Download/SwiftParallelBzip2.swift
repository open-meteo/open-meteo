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
    public func decodeBzip2(bufferPolicy: AsyncBufferSequencePolicy = .bounded(4)) -> AsyncThrowingMapSequence<Bzip2AsyncStream<Self>, ByteBuffer> {
        return Bzip2AsyncStream(sequence: self).map { fn in
            return try fn()
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
        var bitstream = Lbzip2.bitstream(live: 0, buff: 0, block: nil, data: nil, limit: nil, eof: false)
        var buffer = ByteBuffer()
        var parser = parser_state(state: 0, bs100k: 0, stored_crc: 0, computed_crc: 0, stream_mode: 0)

        fileprivate init(iterator: T.AsyncIterator) {
            self.iterator = iterator
        }
        
//        func more() async throws {
//            guard let next = try! await iterator.next() else {
//                bitstream.pointee.eof = true
//                return
//            }
//            buffer = consume next
//            // make sure to align readable bytes to 4 bytes
//            let remaining = buffer.readableBytes % 4
//            if remaining != 0 {
//                buffer.writeRepeatingByte(0, count: 4-remaining)
//            }
//        }

        public func next() async throws -> (() throws -> (ByteBuffer))? {
            var headerCrc: UInt32 = 0
            var header = header()
            while true {
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
                    headerCrc = header.crc
                    break
                case FINISH:
                    return nil
                case MORE:
                    guard let next = try! await iterator.next() else {
                        bitstream.eof = true
                        continue
                    }
                    buffer = consume next
                    // make sure to align readable bytes to 4 bytes
                    let remaining = buffer.readableBytes % 4
                    if remaining != 0 {
                        buffer.writeRepeatingByte(0, count: 4-remaining)
                    }
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
                break
            }
            let bs100k = parser.bs100k
            var decoder = decoder_state(internal_state: nil, rand: false, bwt_idx: 0, block_size: 0, crc: 0, ftab: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), tt: nil, rle_state: 0, rle_crc: 0, rle_index: 0, rle_avail: 0, rle_char: 0, rle_prev: 0)
            decoder_init(&decoder)
            do {
                while true {
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
                        break
                    case Lbzip2.MORE:
                        guard let next = try! await iterator.next() else {
                            bitstream.eof = true
                            continue
                        }
                        buffer = consume next
                        // make sure to align readable bytes to 4 bytes
                        let remaining = buffer.readableBytes % 4
                        if remaining != 0 {
                            buffer.writeRepeatingByte(0, count: 4-remaining)
                        }
                        continue
                    default:
                        throw SwiftParallelBzip2Error.unexpectedDecoderError(ret.rawValue)
                    }
                    break
                }
            } catch {
                decoder_free(&decoder)
            }
            return {
                Lbzip2.decode(&decoder)
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
                    throw SwiftParallelBzip2Error.blockCRCMismatch
                }
                decoder_free(&decoder)
                //print("emit \(out.readableBytes) bytes")
                return out
            }

        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}

extension Bzip2AsyncStream: Sendable where T: Sendable {
    
}

