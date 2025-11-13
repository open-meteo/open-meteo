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
    public func decodeBzip2(bufferPolicy: AsyncBufferSequencePolicy = .bounded(4)) -> AsyncMapSequence<Bzip2AsyncStream<Self>, ByteBuffer> {
        return Bzip2AsyncStream(sequence: self).map { decoder in
            //Task {
                var decoder = decoder
                Lbzip2.decode(&decoder)
                var out = ByteBuffer()
                // Reserve the maximum output block size
                out.writeWithUnsafeMutableBytes(minimumWritableBytes: Int(9*100_000)) { ptr in
                    var outsize: Int = ptr.count
                    guard Lbzip2.emit(&decoder, ptr.baseAddress, &outsize) == Lbzip2.OK.rawValue else {
                        // Emit should not fail because enough output capacity is available
                        fatalError("emit failed")
                    }
                    return ptr.count - outsize
                }
                decoder_free(&decoder)
                //            guard decoder.crc == headerCrc else {
                //                throw SwiftParallelBzip2Error.blockCRCMismatch
                //            }
                //print("emit \(out.readableBytes) bytes")
                return out
            //}
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
        var bitstream: bitstream
        var buffer: ByteBuffer
        var parser: parser_state = parser_state()

        fileprivate init(iterator: T.AsyncIterator) {
            self.iterator = iterator
            self.bitstream = Lbzip2.bitstream()
            self.buffer = ByteBuffer()
            
            bitstream.live = 0
            bitstream.buff = 0
            bitstream.block = nil
            bitstream.data = nil
            bitstream.limit = nil
            bitstream.eof = false
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

        public func next() async throws -> decoder_state? {
            if bitstream.data == nil {
                let bs100k = try await parseFileHeader()
                parser_init(&parser, bs100k, 0)
            }
            guard let headerCrc = try await parse(parser: &parser) else {
                return nil
            }
            let bs100k = parser.bs100k
            var decoder = decoder_state()
            do {
                while try await retrieve(decoder: &decoder) {
                    try await more()
                }
            } catch {
                decoder_free(&decoder)
            }
            return decoder
//            return Task {
//
//            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}

extension Bzip2AsyncStream: Sendable where T: Sendable {
    
}
