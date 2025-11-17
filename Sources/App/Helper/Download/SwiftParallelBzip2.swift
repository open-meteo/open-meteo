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
    let buffer: ByteBuffer
    var next: Entry
    
    var eof: Bool {
        switch next {
        case .eof:
            return true
        default:
            return false
        }
    }
    
    enum Entry {
        case none
        case next(BufferLinkedList)
        case eof
    }
    
    init(buffer: ByteBuffer, next: Entry) {
        self.buffer = buffer
        self.next = next
    }
    
    func setNext(_ next: Entry) -> Void {
        self.next = next
    }
    

}

struct DecodeReturn: Sendable {
    let decoded: ByteBuffer
    let crc: UInt32
    
    /// Points to block after MAGIC+CRC
    let startBlock: BufferLinkedList
    let startBs: bitstream
    let startOffset: Int
    
    // Points to end of data (before next MAGIC+CRC)
    let endBs: bitstream
    let endBlock: BufferLinkedList
    let endOffset: Int
}

enum DecodeReturnOrError: Sendable {
    case decoded(DecodeReturn)
    case error(Error, startBlock: BufferLinkedList, startBs: bitstream, startOffset: Int)
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
        var offset: Int? = nil
        var bitstream: bitstream? = nil
        var pointer: BufferLinkedList? = nil

        fileprivate init(iterator: AsyncJobIterator) {
            self.iterator = iterator
        }
        
        /// Return the next decoded block
        public func next() async throws -> ByteBuffer? {
            guard let d = try await iterator.next() else {
                return nil
            }
            
            switch d {
            case .decoded(let d):
                if let pointer, let bitstream, let offset {
                    guard pointer.buffer == d.startBlock.buffer, bitstream.data == d.startBs.data, offset == d.startOffset else {
                        fatalError("got a block that doesn't match the one we were parsing")
                    }
                } else {
                    // Set initial CRC for stream CRC check
                    parser.computed_crc = d.crc
                }
                
                /// Take the end pointer and move it forward by MAGIC+CRC
                /// The CRC is the next block. Not the current
                var pointer = d.endBlock
                var bitstream = d.endBs
                var offset = d.endOffset
                
                // move stored offset by MAGIC+CRC
                parser.state = 2// Lbzip2.BLOCK_MAGIC_1
                while true {
                    let eof = await pointer.eof
                    let parserReturn = pointer.buffer.withUnsafeReadableBytes { ptr in
                        bitstream.data = ptr.baseAddress?.advanced(by: offset).assumingMemoryBound(to: UInt32.self)
                        bitstream.limit = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: (ptr.count + 4 - 1) / 4)
                        bitstream.eof = eof
                        var garbage: UInt32 = 0
                        var header = header()
                        let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.parse(&parser, &header, &bitstream, &garbage)))
                        assert(garbage < 32)
                        assert(bitstream.data <= bitstream.limit)
                        offset = ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0
                        return ret
                    }
                    switch parserReturn {
                    case OK:
                        break
                    case FINISH:
                        // Correct end of stream
                        return d.decoded
                    case MORE:
                        switch await pointer.next {
                        case .none:
                            fatalError("Parser returned .MORE but not buffered data avaiable")
                        case .next(let bufferLinkedList):
                            pointer = bufferLinkedList
                            offset = 0
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
                self.offset = offset
                self.pointer = pointer
                self.bitstream = bitstream
                return d.decoded
                
                
            case .error(let error, let startBlock, let startBs, let startOffset):
                if let pointer, let bitstream, let offset {
                    guard pointer.buffer == startBlock.buffer, bitstream.data == startBs.data, startOffset == offset else {
                        // GOT bogus block, ignoring
                        return try await next()
                    }
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
        var offset: Int = 0
        var buffers: BufferLinkedList? = nil
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
        
        func ensure(readableBytes: Int, pointer: BufferLinkedList) async throws {
            var pointer = pointer
            var available = pointer.buffer.readableBytes
            while true {
                if available >= readableBytes {
                    return
                }
                switch await pointer.next {
                case .none:
                    guard var data = try await iterator.next() else {
                        await pointer.setNext(.eof)
                        break
                    }
                    // make sure to align readable bytes to 4 bytes
                    let remaining = data.readableBytes % 4
                    data.reserveCapacity(minimumWritableBytes: 4-remaining)
                    let next = BufferLinkedList(buffer: data, next: .none)
                    await pointer.setNext(.next(next))
                    pointer = next
                    available += next.buffer.readableBytes
                case .next(let next):
                    pointer = next
                    available += next.buffer.readableBytes
                case .eof:
                    return
                }
            }
        }

        /// Decode the next block and return a closure to decode it
        /// The closure can be executed concurrently
        func decodeNext() async throws -> (@Sendable () async -> DecodeReturnOrError)? {
            if buffers == nil {
                // build linked list of buffers and read the file header
                // Parse BZIP2 file header and get block size
                guard var data = try await iterator.next() else {
                    throw SwiftParallelBzip2Error.unexpectedEndOfStream
                }
                // make sure to align readable bytes to 4 bytes
                let remaining = data.readableBytes % 4
                data.reserveCapacity(minimumWritableBytes: 4-remaining)
                guard let head: Int32 = data.getInteger(at: data.readerIndex) else {
                    throw SwiftParallelBzip2Error.unexpectedEndOfStream
                }
                guard head >= 0x425A6830 + 1 && head <= 0x425A6830 + 9 else {
                    throw SwiftParallelBzip2Error.invalidBzip2Header
                }
                bs100k = head - 0x425A6830
                
                self.offset = 4
                self.buffers = BufferLinkedList(buffer: data, next: .none)
            }
            
            // ensure at least 1mb of data available in the buffers chain
            guard let start = buffers else {
                fatalError()
            }
            try await ensure(readableBytes: 1024*1024 + offset, pointer: start)
            var pointer = start
            
            // Scan for block MAGIC number and BLOCK CRC
            var headerCrc: UInt32 = 0
            while true {
                let eof = await pointer.eof
                let scanReturn = pointer.buffer.withUnsafeReadableBytes( { ptr in
                    bitstream.data = ptr.baseAddress?.advanced(by: offset).assumingMemoryBound(to: UInt32.self)
                    bitstream.limit = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: (ptr.count + 4 - 1) / 4)
                    bitstream.eof = eof
                    let ret = Lbzip2.error(rawValue: UInt32(scan(&bitstream, 0, &headerCrc)))
                    assert(bitstream.data <= bitstream.limit)
                    offset = ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0
                    return ret
                })
                if scanReturn == OK {
                    break
                }
                switch await pointer.next {
                case .none:
                    throw SwiftParallelBzip2Error.didNotFoundBlockHeader
                case .next(let bufferLinkedList):
                    pointer = bufferLinkedList
                    offset = 0
                case .eof:
                    // Print potential EOS
                    return nil
                }
            }
            self.buffers = pointer
            
            try await ensure(readableBytes: 1024*1024 + offset, pointer: pointer)
            
            // Bitstream points to beginning of data, spawn task and process it
            return { [bitstream, pointer, offset, headerCrc, bs100k] in
                let startBitstream = bitstream
                var bitstream = bitstream
                let startOffset = offset
                let startPointer = pointer
                var offset = offset
                var pointer = pointer
                
                var decoder = decoder_state()
                decoder_init(&decoder)
                defer {
                    decoder_free(&decoder)
                }
                while true {
                    let eof = await pointer.eof
                    let ret = pointer.buffer.withUnsafeReadableBytes { ptr in
                        bitstream.data = ptr.baseAddress?.advanced(by: offset).assumingMemoryBound(to: UInt32.self)
                        bitstream.limit = ptr.baseAddress?.assumingMemoryBound(to: UInt32.self).advanced(by: (ptr.count + 4 - 1) / 4)
                        bitstream.eof = eof
                        let ret = Lbzip2.error(rawValue: UInt32(Lbzip2.retrieve(&decoder, &bitstream)))
                        assert(bitstream.data <= bitstream.limit)
                        offset = ptr.baseAddress?.distance(to: UnsafeRawPointer(bitstream.data)) ?? 0
                        return ret
                    }
                    switch ret {
                    case Lbzip2.OK:
                        break
                    case Lbzip2.MORE:
                        switch await pointer.next {
                        case .none, .eof:
                            return .error(SwiftParallelBzip2Error.unexpectedEndOfStream, startBlock: start, startBs: startBitstream, startOffset: startOffset)
                        case .next(let bufferLinkedList):
                            pointer = bufferLinkedList
                            offset = 0
                        }
                        continue
                    default:
                        return .error(SwiftParallelBzip2Error.unexpectedDecoderError(ret.rawValue), startBlock: start, startBs: startBitstream, startOffset: startOffset)
                    }
                    break
                }
                
                //var decoder = decoder
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
                    return .error(SwiftParallelBzip2Error.blockCRCMismatch, startBlock: startPointer, startBs: startBitstream, startOffset: startOffset)
                }
                
                // bitstream is now at end of data block
                // next data is either BLOCK MAGIC+CRC or STREAM EOS MAGIC+CRC
                return .decoded(DecodeReturn(decoded: out, crc: decoder.crc, startBlock: startPointer, startBs: startBitstream, startOffset: startOffset, endBs: bitstream, endBlock: pointer, endOffset: offset))
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
