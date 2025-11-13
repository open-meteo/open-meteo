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
    public func decodeBzip2(bufferPolicy: AsyncBufferSequencePolicy = .bounded(4)) -> Bzip2AsyncStream<Self> {
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

        public func next() async throws -> ByteBuffer? {
            if bitstream.data == nil {
                let bs100k = try await parseFileHeader()
                print("parser init")
                parser_init(&parser, bs100k, 0)
            }
            print("parse")
            guard let headerCrc = try await parse(parser: &parser) else {
                return nil
            }
            print("retrieve")
            let decoder = Bz2Decoder(headerCrc: headerCrc, bs100k: parser.bs100k)
            while try await retrieve(decoder: &decoder.decoder) {
                try await more()
            }
            print("decode")
//            return Task {
                decoder.decode()
            print("emit")
                let res = try decoder.emit()
            print("done")
            return res
//            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}

extension Bzip2AsyncStream: Sendable where T: Sendable {
    
}
