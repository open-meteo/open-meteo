import Foundation
import NIO
import CBz2lib
import SwiftEccodes
import Logging


extension AsyncSequence where Element == ByteBuffer {
    /// Decode incoming data to GRIB messges
    func decodeGrib() -> GribAsyncStream<Self> {
        return GribAsyncStream(sequence: self)
    }
}

struct GribAsyncStreamHelper {
    /// Detect a range of bytes in a byte stream if there is a grib header and returns it
    /// Note: The required length to decode a GRIB message is not checked of the input buffer
    static func seekGrib(memory: UnsafeRawBufferPointer) -> (offset: Int, length: Int)? {
        let search = "GRIB"
        guard let base = memory.baseAddress else {
            return nil
        }
        guard let offset = search.withCString({memory.firstRange(of: UnsafeRawBufferPointer(start: $0, count: strlen($0)))})?.lowerBound else {
            return nil
        }
        guard offset <= (1 << 40), offset + MemoryLayout<GribHeader>.size <= memory.count else {
            return nil
        }
        struct GribHeader {
            /// "GRIB"
            let magic: UInt32
            
            let reserved: UInt16
            
            /// 0 - for Meteorological Products, 2 for Land Surface Products, 10 - for Oceanographic Products
            let type: UInt8
            
            /// Version 1 and 2 supported
            let version: UInt8
            
            /// Endian needs to be swapped
            let length: UInt64
        }
        
        let header = base.advanced(by: offset).assumingMemoryBound(to: GribHeader.self).pointee
        
        // GRIB1 detection
        if header.version == 1 {
            // 1-4 identifier = GRIB
            // 5-7 totalLength = 4284072
            // 8 editionNumber = 1
            // Read 24 bytes as bigEndian and turn into UInt32
            let base = base.advanced(by: offset + 4).assumingMemoryBound(to: UInt32.self).pointee
            let masked = (base & 0x00ffffff)
            let shifted = (masked << 8)
            let length = shifted.bigEndian
            guard length <= (1 << 24) else {
                return nil
            }
            return (offset, Int(length))
        }
        
        let length = header.length.bigEndian
        
        guard (1...2).contains(header.version), length <= (1 << 40) else {
            return nil
        }
        return (offset, Int(length))
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
        
        /// Buffer mutliple messages to only return one at a time
        private var messages: [GribMessage]? = nil

        fileprivate init(iterator: T.AsyncIterator) {
            self.iterator = iterator
            self.buffer = ByteBuffer()
            buffer.reserveCapacity(minimumWritableBytes: 4096)
        }

        public func next() async throws -> GribMessage? {
            if let next = messages?.popLast() {
                return next
            }
            
            while true {
                // repeat until GRIB header is found
                guard let seek = buffer.withUnsafeReadableBytes(GribAsyncStreamHelper.seekGrib) else {
                    guard let input = try await self.iterator.next() else {
                        return nil
                    }
                    guard buffer.readableBytes < 4096 else {
                        fatalError("Did not find GRIB header")
                    }
                    buffer.writeImmutableBuffer(input)
                    continue
                }
                
                // Repeat until enough data is available
                while buffer.readableBytes < seek.offset + seek.length {
                    guard let input = try await self.iterator.next() else {
                        return nil
                    }
                    buffer.writeImmutableBuffer(input)
                }
                
                messages = try buffer.readWithUnsafeReadableBytes({
                    let memory = UnsafeRawBufferPointer(rebasing: $0[seek.offset ..< seek.offset+seek.length])
                    let messages = try SwiftEccodes.getMessages(memory: memory, multiSupport: true)
                    return (seek.offset+seek.length, messages)
                })
                buffer.discardReadBytes()
                if let next = messages?.popLast() {
                    return next
                }
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}
