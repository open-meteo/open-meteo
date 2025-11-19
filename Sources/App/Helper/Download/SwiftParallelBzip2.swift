import Foundation
import NIOCore
import Lbzip2

public enum SwiftParallelBzip2Error: Error {
    case invalidBzip2Header
    case invalidStreamHeader
    case streamCRCMismatch
    case blockCRCMismatch
    case unexpectedEndOfStream
    case unexpectedParserError(UInt32)
    case unexpectedDecoderError(UInt32)
    case didNotFoundBlockHeader
}

extension AsyncSequence where Element == ByteBuffer, Self: Sendable {
    /**
     Decode an bzip2 encoded stream of ByteBuffer to a stream of decoded blocks. Throws on invalid data.
     `nConcurrent` sets the number of threads to decompress blocks. Default to cpu core count.
     */
    public func decodeBzip2(nConcurrent: Int = System.coreCount) -> Bzip2AsyncStream<Self> {
        return Bzip2AsyncStream(sequence: self, nConcurrent: nConcurrent)
    }
}

final actor BufferLinkedList {
    var value: Entry
    
    var eof: Bool {
        switch value {
        case .eof:
            return true
        default:
            return false
        }
    }
    
    enum Entry {
        case none
        case next(ByteBuffer, BufferLinkedList)
        case eof
    }
    
    init(value: Entry) {
        self.value = value
    }
    
    func setValue(_ value: Entry) -> Void {
        self.value = value
    }
    

}

struct DecodeReturn: Sendable {
    let decoded: ByteBuffer
    let crc: UInt32
    
    // Points to end of data (before next MAGIC+CRC)
    let bitstream: bitstream
    let buffers: BufferLinkedList
    let buffer: ByteBuffer
}

enum DecodeReturnOrError: Sendable {
    case decoded(DecodeReturn)
    case error(Error, crc: UInt32)
}

/**
 Decompress incoming ByteBuffer stream to an Async Sequence of closures that will return a ByteBuffer. The returned closures can then be executed concurrently
 */
public struct Bzip2AsyncStream<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element

    let sequence: T
    let nConcurrent: Int
    
    /// Iterates over completed jobs and calculates the stream CRC
    public final class AsyncIterator: AsyncIteratorProtocol {
        /// Collect enough bytes to decompress a single message
        var iterator: AsyncJobIterator
        var parser: parser_state = parser_state()
        var nextCrc: UInt32? = nil
        var finished = false

        fileprivate init(iterator: AsyncJobIterator) {
            self.iterator = iterator
        }
        
        /// Return the next decoded block
        public func next() async throws -> ByteBuffer? {
            if finished {
                return nil
            }
            guard let d = try await iterator.next() else {
                throw SwiftParallelBzip2Error.unexpectedEndOfStream
            }
            
            switch d {
            case .decoded(let d):
                if let nextCrc {
                    guard nextCrc == d.crc else {
                        fatalError("got a block that doesn't match the one we were parsing")
                    }
                } else {
                    // Set initial CRC for stream CRC check
                    parser.computed_crc = d.crc
                }
                
                /// Take the end pointer and move it forward by MAGIC+CRC
                /// The CRC is the next block. Not the current
                var pointer = d.buffers
                var bitstream = d.bitstream
                var buffer = d.buffer
                
                // move stored offset by MAGIC+CRC
                parser.state = 2// Lbzip2.BLOCK_MAGIC_1
                while true {
                    let eof = await pointer.eof
                    var header = header()
                    let parserReturn = buffer.readWithUnsafeReadableBytes { ptr in
                        bitstream.data = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self)
                        bitstream.limit = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: (ptr.count + 4 - 1) / 4)
                        bitstream.eof = eof
                        var garbage: UInt32 = 0
                        let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.parse(&parser, &header, &bitstream, &garbage)))
                        assert(garbage < 32)
                        assert(bitstream.data <= bitstream.limit)
                        let bytesRead = Swift.min(ptr.count, ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0)
                        return (bytesRead, ret)
                    }
                    switch parserReturn {
                    case OK:
                        nextCrc = header.crc
                        break
                    case FINISH:
                        // Correct end of stream
                        finished = true
                        return d.decoded
                    case MORE:
                        switch await pointer.value {
                        case .none:
                            fatalError("Parser returned .MORE but not buffered data avaiable")
                        case .next(let next, let bufferLinkedList):
                            pointer = bufferLinkedList
                            buffer = next
                        case .eof:
                            fatalError("Parser returned .MORE but EOF reached")
                        }
                        continue
                    case ERR_HEADER:
                        throw SwiftParallelBzip2Error.invalidStreamHeader
                    case ERR_STRMCRC:
                        throw SwiftParallelBzip2Error.streamCRCMismatch
                    case ERR_EOF:
                        throw SwiftParallelBzip2Error.unexpectedEndOfStream
                    default:
                        throw SwiftParallelBzip2Error.unexpectedParserError(parserReturn.rawValue)
                    }
                    break
                }
                return d.decoded
            case .error(let error, let crc):
                if let nextCrc, nextCrc != crc {
                    // GOT bogus block, ignoring
                    return try await next()
                }
                throw error
            }
        }
    }

    /// Iterate over bitstream, search for block MAGIC and spawn threads
    final class AsyncJobIterator: AsyncIteratorProtocol {
        /// Collect enough bytes to decompress a single message
        var iterator: T.AsyncIterator
        var bitstream = Lbzip2.bitstream(live: 0, buff: 0, block: nil, data: nil, limit: nil, eof: false)
        var buffers = BufferLinkedList(value: .none)
        var buffer = ByteBuffer()
        var bs100k: Int32 = 0
        
        var tasks: CircularBuffer<Task<DecodeReturnOrError, Never>>? = nil
        let nConcurrent: Int

        fileprivate init(iterator: T.AsyncIterator, nConcurrent: Int) {
            self.iterator = iterator
            self.nConcurrent = nConcurrent
        }
        
        /// Return the next decoded block
        func next() async throws -> DecodeReturnOrError? {
            guard tasks != nil else {
                // fill initial task list
                var tasks = CircularBuffer<Task<DecodeReturnOrError, Never>>(initialCapacity: nConcurrent + 1)
                for _ in 0..<nConcurrent {
                    guard let next = try await decodeNext() else {
                        break
                    }
                    tasks.append(Task {
                        return await next()
                    })
                }
                self.tasks = tasks
                return try await self.next()
            }
            guard tasks?.isEmpty == false else {
                return nil // all tasks completed
            }
            let result = await tasks?.removeFirst().value
            if tasks?.count == nConcurrent - 1 {
                guard let next = try await decodeNext() else {
                    return result
                }
                let task = Task {
                    return await next()
                }
                tasks?.append(task)
            }
            return result
        }
        
        func ensure(current: ByteBuffer, readableBytes: Int, pointer: BufferLinkedList) async throws {
            var pointer = pointer
            var available = current.readableBytes
            while true {
                if available >= readableBytes {
                    return
                }
                switch await pointer.value {
                case .none:
                    guard var data = try await iterator.next() else {
                        await pointer.setValue(.eof)
                        return
                    }
                    // Make sure to get a 32 bit aligned buffer length
                    while data.readableBytes % 4 != 0 {
                        guard var next = try await iterator.next() else {
                            let remaining = data.readableBytes % 4
                            data.reserveCapacity(minimumWritableBytes: 4-remaining)
                            await pointer.setValue(.next(data, .init(value: .eof)))
                            return
                        }
                        data.writeBuffer(&next)
                    }
                    let next = BufferLinkedList(value: .none)
                    await pointer.setValue(.next(data, next))
                    pointer = next
                    available += data.readableBytes
                case .next(let nextBuffer, let next):
                    pointer = next
                    available += nextBuffer.readableBytes
                case .eof:
                    return
                }
            }
        }

        /// Decode the next block and return a closure to decode it
        /// The closure can be executed concurrently
        func decodeNext() async throws -> (@Sendable () async -> DecodeReturnOrError)? {
            if bs100k == 0 {
                // build linked list of buffers and read the file header
                // Parse BZIP2 file header and get block size
                guard var data = try await iterator.next() else {
                    throw SwiftParallelBzip2Error.unexpectedEndOfStream
                }
                
                // Make sure to get a 32 bit aligned buffer length
                while data.readableBytes % 4 != 0 {
                    guard var next = try await iterator.next() else {
                        let remaining = data.readableBytes % 4
                        data.reserveCapacity(minimumWritableBytes: 4-remaining)
                        await buffers.setValue(.eof)
                        break
                    }
                    data.writeBuffer(&next)
                }
                
                guard let head: Int32 = data.getInteger(at: data.readerIndex) else {
                    throw SwiftParallelBzip2Error.unexpectedEndOfStream
                }
                guard head >= 0x425A6830 + 1 && head <= 0x425A6830 + 9 else {
                    throw SwiftParallelBzip2Error.invalidBzip2Header
                }
                bs100k = head - 0x425A6830
                self.buffer = data
            }
            
            // ensure at least 1mb of data available in the buffers chain
            try await ensure(current: buffer, readableBytes: 1024*1024, pointer: buffers)
            
            // Scan for block MAGIC number and BLOCK CRC
            var headerCrc: UInt32 = 0
            var scanState: UInt32 = 0
            while true {
                let eof = await buffers.eof
                let scanReturn = buffer.readWithUnsafeReadableBytes( { ptr in
                    bitstream.data = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self)
                    bitstream.limit = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: (ptr.count + 4 - 1) / 4)
                    bitstream.eof = eof
                    
                    let ret = Lbzip2.error(rawValue: UInt32(scan(&bitstream, 0, &headerCrc, &scanState)))
                    assert(bitstream.data <= bitstream.limit)
                    let bytesRead = Swift.min(ptr.count, ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0)
                    //print("bytes read \(bytesRead)")
                    return (bytesRead, ret)
                })
                if scanReturn == OK {
                    break
                }
                switch await buffers.value {
                case .none:
                    throw SwiftParallelBzip2Error.didNotFoundBlockHeader
                case .next(let next, let bufferLinkedList):
                    buffers = bufferLinkedList
                    buffer = next
                case .eof:
                    // Print potential EOS
                    return nil
                }
            }
            try await ensure(current: buffer, readableBytes: 1024*1024, pointer: buffers)
                        
            // Bitstream points to beginning of data, spawn task and process it
            return { [bitstream, buffers, buffer, headerCrc, bs100k] in
                var bitstream = bitstream
                var pointer = buffers
                var buffer = buffer
                
                var decoder = decoder_state()
                decoder_init(&decoder)
                defer {
                    decoder_free(&decoder)
                }
                while true {
                    let eof = await pointer.eof
                    let ret = buffer.readWithUnsafeReadableBytes { ptr in
                        bitstream.data = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self)
                        bitstream.limit = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: (ptr.count + 4 - 1) / 4)
                        bitstream.eof = eof
                        let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.retrieve(&decoder, &bitstream)))
                        assert(bitstream.data <= bitstream.limit)
                        let bytesRead = Swift.min(ptr.count, ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0)
                        return (bytesRead, ret)
                    }
                    switch ret {
                    case Lbzip2.OK:
                        break
                    case Lbzip2.MORE:
                        switch await pointer.value {
                        case .none, .eof:
                            return .error(SwiftParallelBzip2Error.unexpectedEndOfStream, crc: headerCrc)
                        case .next(let next, let bufferLinkedList):
                            pointer = bufferLinkedList
                            buffer = next
                        }
                        continue
                    default:
                        return .error(SwiftParallelBzip2Error.unexpectedDecoderError(ret.rawValue), crc: headerCrc)
                    }
                    break
                }
                
                //var decoder = decoder
                Lbzip2.decode(&decoder)
                var out = ByteBuffer()
                while true {
                    var ret = Lbzip2.OK
                    out.writeWithUnsafeMutableBytes(minimumWritableBytes: Int(bs100k*100_000)) { ptr in
                        var outsize: Int = ptr.count
                        ret = Lbzip2.error(rawValue: UInt32(Lbzip2.emit(&decoder, ptr.baseAddress, &outsize)))
                        return (ptr.count - outsize)
                    }
                    switch ret {
                    case OK:
                        break
                    case MORE:
                        continue
                    default:
                        return .error(SwiftParallelBzip2Error.unexpectedDecoderError(ret.rawValue), crc: headerCrc)
                    }
                    break
                }
                
                guard decoder.crc == headerCrc else {
                    return .error(SwiftParallelBzip2Error.blockCRCMismatch, crc: headerCrc)
                }
                
                // bitstream is now at end of data block
                // next data is either BLOCK MAGIC+CRC or STREAM EOS MAGIC+CRC
                return .decoded(DecodeReturn(decoded: out, crc: decoder.crc, bitstream: bitstream, buffers: pointer, buffer: buffer))
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: AsyncJobIterator(iterator: sequence.makeAsyncIterator(), nConcurrent: nConcurrent))
    }
}

extension Bzip2AsyncStream: Sendable where T: Sendable {
    
}

extension bitstream: @unchecked @retroactive Sendable {
    
}
