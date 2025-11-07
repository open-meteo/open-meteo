import Foundation
import NIO
import CBz2lib
@preconcurrency import SwiftEccodes
import Logging
import AsyncAlgorithms

extension AsyncSequence where Self: Sendable, Element == ByteBuffer {
    /// Decode incoming data to GRIB messages. Processing takes place in detached task
    func decodeGrib() -> AsyncThrowingChannel<GribMessage, Error> {
        let channel = AsyncThrowingChannel<GribMessage, Error>()
        _ = Task {
            var iterator = self.makeAsyncIterator()
            var buffer = ByteBuffer()
            do {
                while true {
                    // repeat until GRIB header is found
                    guard let seek = buffer.withUnsafeReadableBytes(GribAsyncStreamHelper.seekGrib) else {
                        guard let input = try await iterator.next() else {
                            break // end of stream
                        }
                        guard buffer.readableBytes < 64 * 1024 else {
                            throw GribAsyncStreamError.didNotFindGibHeader
                        }
                        buffer.writeImmutableBuffer(input)
                        continue
                    }

                    // Repeat until enough data is available
                    while buffer.readableBytes < seek.offset + seek.length {
                        guard let input = try await iterator.next() else {
                            // If EOF is reached before message length, still try to decode it with eccodes
                            continue
                        }
                        buffer.writeImmutableBuffer(input)
                    }

                    // Decode message with eccodes
                    let messages = try buffer.readWithUnsafeReadableBytes({
                        let range = seek.offset ..< Swift.min(seek.offset + seek.length, $0.count)
                        let memory = UnsafeRawBufferPointer(rebasing: $0[range])
                        let messages = try SwiftEccodes.getMessages(memory: memory, multiSupport: true)
                        return (seek.offset + seek.length, messages)
                    })

                    buffer.discardReadBytes()
                    for message in messages {
                        await channel.send(message)
                    }
                }
                channel.finish()
            } catch {
                channel.fail(error)
            }
        }
        return channel
    }
}

enum GribAsyncStreamHelper {
    /// Detect a range of bytes in a byte stream if there is a grib header and returns it
    /// Note: The required length to decode a GRIB message is not checked of the input buffer
    static func seekGrib(memory: UnsafeRawBufferPointer) -> (offset: Int, length: Int, gribVersion: Int)? {
        let search = "GRIB"
        guard let base = memory.baseAddress else {
            return nil
        }
        guard let offset = search.withCString({ memory.firstRange(of: UnsafeRawBufferPointer(start: $0, count: strlen($0))) })?.lowerBound else {
            return nil
        }
        guard offset <= (1 << 40), offset + 16 <= memory.count else {
            return nil
        }
        /// GRIB version in 1 and 2 is always at byte 8
        /// https://codes.ecmwf.int/grib/format/grib2/sections/0/
        let edition = base.advanced(by: offset + 7).assumingMemoryBound(to: UInt8.self).pointee

        switch edition {
        case 1:
            // 1-4 identifier = GRIB
            // 5-7 totalLength = 4284072
            // 8 editionNumber = 1
            let length = base.advanced(by: offset + 4).uint24
            guard length <= (1 << 24) else {
                return nil
            }
            if length >= 0x800000 {
                // large GRIB >8MB messages size
                var sectionOffset = offset + 8
                let section1Length = base.advanced(by: sectionOffset).uint24
                let flags = base.advanced(by: sectionOffset + 3 + 4).assumingMemoryBound(to: UInt8.self).pointee
                sectionOffset += Int(section1Length)
                // print("Section 1 length \(section1Length); flags \(flags)")

                // Section 2
                if flags & (1 << 7) != 0 {
                    guard memory.count >= sectionOffset + 3 else {
                        return nil
                    }
                    let section2Length = base.advanced(by: sectionOffset).uint24
                    sectionOffset += Int(section2Length)
                    // print("Section 2 length \(section2Length)")
                }

                // Section 3
                if flags & (1 << 6) != 0 {
                    guard memory.count >= sectionOffset + 3 else {
                        return nil
                    }
                    let section3Length = base.advanced(by: sectionOffset).uint24
                    sectionOffset += Int(section3Length)
                    // print("Section 3 length \(section3Length)")
                }

                guard memory.count >= sectionOffset + 3 else {
                    return nil
                }
                let section4Length = base.advanced(by: sectionOffset).uint24
                // print("Section 4 length \(section4Length)")

                if section4Length < 120 {
                    // "Special Coding"
                    let correctedLength = (Int(length) & 0x7fffff) * 120 - Int(section4Length) + 4
                    return (offset, correctedLength, 1)
                }
            }
            return (offset, Int(length), 1)
        case 2:
            let length = base.advanced(by: offset + 8).assumingMemoryBound(to: UInt64.self).pointee.bigEndian
            guard length <= (1 << 40) else {
                return nil
            }
            return (offset, Int(length), 2)
        default:
            fatalError("Unknown GRIB version \(edition)")
        }
    }
}

fileprivate extension UnsafeRawPointer {
    /// Decode next 3 bytes and return as UInt32
    var uint24: UInt32 {
        let u = self.assumingMemoryBound(to: UInt8.self)
        return (UInt32(u.pointee) << 16) | (UInt32(u.advanced(by: 1).pointee) << 8) | UInt32(u.advanced(by: 2).pointee)
    }
}

enum GribAsyncStreamError: Error {
    case didNotFindGibHeader
}
