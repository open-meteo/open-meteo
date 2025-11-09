import Foundation
import NIO
import CBz2lib
import AsyncAlgorithms
import Synchronization

enum Bzip2Error: Error {
    case processFailed(code: Int32)
    case binaryNotAvailble
}

extension AsyncSequence where Element == ByteBuffer, Self: Sendable {
    // Decompress BZIP2 using lbzip2 executable if available
    func decompressBzip2Parallel() throws -> AsyncThrowingChannel<ByteBuffer, Error> {
        let paths = ["/opt/homebrew/bin/lbzip2", "/usr/local/bin/lbzip2", "/usr/bin/lbzip2"]
        guard let path = paths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw Bzip2Error.binaryNotAvailble
        }
        let stdoutPipe = Pipe()
        let stdinPipe = Pipe()
        let channelOut = AsyncThrowingChannel<ByteBuffer, Error>()
        stdoutPipe.fileHandleForReading.readabilityHandler = { fn in
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                defer { semaphore.signal() }
                let data = fn.availableData
                if data.count > 0 {
                    await channelOut.send(ByteBuffer(data: data))
                }
            }
            semaphore.wait()
        }
        let dataIn = AsyncIteratorBoxed<Self>(self)
        stdinPipe.fileHandleForWriting.writeabilityHandler = { fn in
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                defer { semaphore.signal() }
                do {
                    guard let data = try await dataIn.next() else {
                        try fn.close()
                        return
                    }
                    try fn.write(contentsOf: data.readableBytesView)
                } catch {
                    try? fn.close()
                    channelOut.fail(error)
                }
            }
            semaphore.wait()
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--decompress", "--stdout" /*, "-n", "8"*/]
        process.standardOutput = stdoutPipe
        process.standardInput = stdinPipe
        process.terminationHandler = { process in
            guard process.terminationStatus == 0 else {
                channelOut.fail(Bzip2Error.processFailed(code: process.terminationStatus))
                return
            }
            channelOut.finish()
        }
        try process.run()
        return channelOut
    }
}
extension AsyncSequence where Element == ByteBuffer, Self: Sendable {
    
    /// Decompress incoming data using bzip2. Processing takes place in detached task
    func decompressBzip2SingleThreaded() -> AsyncThrowingChannel<ByteBuffer, Error> {
        let channel = AsyncThrowingChannel<ByteBuffer, Error>()
        _ = Task {
            var bz2 = bz_stream()
            let error = BZ2_bzDecompressInit(&bz2, 0, 0)
            guard error == BZ_OK else {
                fatalError("BZ2_bzDecompressInit failed \(error)")
            }
            defer {
                let error = BZ2_bzDecompressEnd(&bz2)
                guard error == BZ_OK else {
                    fatalError("BZ2_bzDecompressEnd failed \(error)")
                }
            }
            do {
                var writebuffer = ByteBuffer()
                for try await compressed in self {
                    writebuffer.clear(minimumCapacity: compressed.readableBytes * 4)
                    bz2.avail_in = UInt32(compressed.readableBytes)
                    compressed.withUnsafeReadableBytes({ compressed in
                        bz2.next_in = UnsafeMutablePointer<CChar>(mutating: compressed.baseAddress?.assumingMemoryBound(to: CChar.self))
                        while true {
                            let ret = writebuffer.withUnsafeMutableWritableBytes({ out in
                                bz2.next_out = out.baseAddress?.assumingMemoryBound(to: CChar.self)
                                bz2.avail_out = UInt32(out.count)
                                return BZ2_bzDecompress(&bz2)
                            })
                            guard ret == BZ_OK || ret == BZ_STREAM_END else {
                                fatalError("BZ2_bzDecompress failed \(ret)")
                            }
                            writebuffer.moveWriterIndex(forwardBy: writebuffer.writableBytes - Int(bz2.avail_out))
                            if bz2.avail_out > 0 || ret == BZ_STREAM_END {
                                return
                            }
                            // Grow output buffer
                            writebuffer.reserveCapacity(minimumWritableBytes: 128*1024)
                        }
                    })
                    await channel.send(writebuffer)
                }
                channel.finish()
            } catch {
                channel.fail(error)
            }
        }
        return channel
    }
}


/// Actor isolated async iterator
fileprivate actor AsyncIteratorBoxed<T: AsyncSequence>: Sendable {
    private var itr: T.AsyncIterator

    init(_ itr: T) {
        self.itr = itr.makeAsyncIterator()
    }
    
    func next() async throws -> T.Element? {
        var itrNext = self.itr
        let ret = try await itrNext.next(isolation: self)
        self.itr = itrNext
        return ret
    }
}


/*struct ChunkedByteBufferSequence<Base: AsyncSequence>: AsyncSequence
where Base.Element == ByteBuffer {
    typealias Element = ByteBuffer
    typealias AsyncIterator = Iterator
    
    private let base: Base
    private let maxChunkSize: Int
    
    init(base: Base, maxChunkSize: Int = 64 * 1024) {
        self.base = base
        self.maxChunkSize = maxChunkSize
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(baseIterator: base.makeAsyncIterator(), maxChunkSize: maxChunkSize)
    }
    
    struct Iterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        let maxChunkSize: Int
        var carryOver: ByteBuffer? = nil
        
        mutating func next() async throws -> ByteBuffer? {
            // Fill up a working buffer
            var buffer: ByteBuffer
            
            if let leftover = carryOver {
                carryOver = nil
                buffer = leftover
            } else if let next = try await baseIterator.next() {
                buffer = next
            } else {
                return nil
            }
            
            // If the buffer already fits, just return it
            if buffer.readableBytes <= maxChunkSize {
                return buffer
            }
            
            // Split into two parts
            let first = buffer.readSlice(length: maxChunkSize)!
            carryOver = buffer // remainder
            return first
        }
    }
}*/
