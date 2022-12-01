import Foundation
import NIO
import CBz2lib
import SwiftEccodes


extension AsyncSequence where Element == ByteBuffer {
    /// Decode incoming data to GRIB messges
    func decodeGrib() -> GribAsyncStream<Self> {
        return GribAsyncStream(sequence: self)
    }
}

/**
 Decode incoming binary stream to grib messages
 */
struct GribAsyncStream<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element
    
    let sequence: T

    public final class AsyncIterator: AsyncIteratorProtocol {
        private var iterator: T.AsyncIterator
        
        /// Collect enough bytes to decompress a single message
        private var buffer: ByteBuffer

        fileprivate init(iterator: T.AsyncIterator) {
            self.iterator = iterator
            self.buffer = ByteBuffer()
            buffer.reserveCapacity(minimumWritableBytes: 4096)
        }

        public func next() async throws -> [GribMessage]? {
            // TODO, it might be better to get the grib length and then wait until the number of bytes are available
            if let messages = try buffer.readNextGribMessages() {
                return messages
            }
            while true {
                // need to read more data
                guard let input = try await self.iterator.next() else {
                    return nil
                }
                buffer.writeImmutableBuffer(input)
                if let messages = try buffer.readNextGribMessages() {
                    return messages
                }
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}

fileprivate extension ByteBuffer {
    /// Read the next available grib messages from the byte buffer
    mutating func readNextGribMessages() throws -> [GribMessage]? {
        try withUnsafeReadableBytes ({ ptr -> [GribMessage]? in
            guard let seek = SwiftEccodes.seekGrib(memory: ptr) else {
                return nil
            }
            let memory = UnsafeRawBufferPointer(rebasing: ptr[seek.offset ..< seek.offset+seek.length])
            let messages = try SwiftEccodes.getMessages(memory: memory, multiSupport: true)
            moveReaderIndex(forwardBy: seek.offset+seek.length)
            return messages
        })
    }
}
