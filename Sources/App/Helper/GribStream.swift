import Foundation
import NIO
import CBz2lib
import SwiftEccodes
import Logging


extension AsyncSequence where Element == ByteBuffer {
    /// Decode incoming data to GRIB messges
    func decodeGrib(logger: Logger, totalSize: Int?) -> GribAsyncStream<Self> {
        return GribAsyncStream(sequence: self, logger: logger, totalSize: totalSize)
    }
}

/// Detect a range of bytes in a byte stream if there is a grib header and returns it
/// Note: The required length to decode a GRIB message is not checked of the input buffer
fileprivate func seekGrib(memory: UnsafeRawBufferPointer) -> (offset: Int, length: Int)? {
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
    
    let header = base.advanced(by: offset).assumingMemoryBound(to: GribHeader.self)
    let length = header.pointee.length.bigEndian
    
    guard (1...2).contains(header.pointee.version), length <= (1 << 40) else {
        return nil
    }
    return (offset, Int(length))
}

/**
 Decode incoming binary stream to grib messages
 */
struct GribAsyncStream<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element
    
    let sequence: T
    let logger: Logger
    let totalSize: Int?

    public final class AsyncIterator: AsyncIteratorProtocol {
        private var iterator: T.AsyncIterator
        
        /// Collect enough bytes to decompress a single message
        private var buffer: ByteBuffer
        
        var transfered = 0
        var transferedLastPrint = 0
        let printDelta: Double = 20
        let startTime = Date()
        var lastPrint = Date()
        
        let totalSize: Int?
        let logger: Logger

        fileprivate init(iterator: T.AsyncIterator, logger: Logger, totalSize: Int?) {
            self.iterator = iterator
            self.buffer = ByteBuffer()
            buffer.reserveCapacity(minimumWritableBytes: 4096)
            self.logger = logger
            self.totalSize = totalSize
        }
        
        /// Print status from time to time
        private func printStatus() {
            let deltaT = Date().timeIntervalSince(lastPrint)
            if deltaT > printDelta {
                let timeElapsed = Date().timeIntervalSince(startTime)
                let rate = (transfered - transferedLastPrint) / Int(deltaT)
                logger.info("Transferred \(transfered.bytesHumanReadable) / \(totalSize?.bytesHumanReadable ?? "-") in \(Int(timeElapsed/60)):\((Int(timeElapsed) % 60).zeroPadded(len: 2)), \(rate.bytesHumanReadable)/s")
                lastPrint = Date()
                transferedLastPrint = transfered
            }
        }

        public func next() async throws -> [GribMessage]? {
            while true {
                // repeat until GRIB header is found
                guard let seek = buffer.withUnsafeReadableBytes(seekGrib) else {
                    guard let input = try await self.iterator.next() else {
                        return nil
                    }
                    guard buffer.readableBytes < 4096 else {
                        fatalError("Did not find GRIB header")
                    }
                    transfered += input.readableBytes
                    buffer.writeImmutableBuffer(input)
                    printStatus()
                    continue
                }
                
                // Repeat until enough data is available
                while buffer.readableBytes < seek.offset + seek.length {
                    guard let input = try await self.iterator.next() else {
                        return nil
                    }
                    transfered += input.readableBytes
                    buffer.writeImmutableBuffer(input)
                    printStatus()
                }
                
                let messages = try buffer.readWithUnsafeReadableBytes({
                    let memory = UnsafeRawBufferPointer(rebasing: $0[seek.offset ..< seek.offset+seek.length])
                    let messages = try SwiftEccodes.getMessages(memory: memory, multiSupport: true)
                    return (seek.offset+seek.length, messages)
                })
                buffer.discardReadBytes()
                return messages
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator(), logger: logger, totalSize: totalSize)
    }
}
