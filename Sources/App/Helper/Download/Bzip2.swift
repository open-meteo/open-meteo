import Foundation
import NIO
import CBz2lib

extension AsyncSequence where Element == ByteBuffer {
    /// Decompress incoming data using BZIP2
    func decompressBzip2() -> Bzip2AsyncDecompress<Self> {
        return Bzip2AsyncDecompress(sequence: self)
    }
}

/**
 Decompress incoming data using BZIP2
 */
struct Bzip2AsyncDecompress<T: AsyncSequence>: AsyncSequence where T.Element == ByteBuffer {
    public typealias Element = AsyncIterator.Element

    let sequence: T

    public final class AsyncIterator: AsyncIteratorProtocol {
        private var iterator: T.AsyncIterator
        private var bz2: bz_stream
        private var writebuffer: ByteBuffer

        fileprivate init(iterator: T.AsyncIterator) {
            self.iterator = iterator
            self.writebuffer = ByteBuffer()
            self.bz2 = bz_stream()

            let error = BZ2_bzDecompressInit(&bz2, 0, 0)
            guard error == BZ_OK else {
                fatalError("BZ2_bzDecompressInit failed \(error)")
            }
        }

        public func next() async throws -> ByteBuffer? {
            guard var compressed = try await self.iterator.next() else {
                return nil
            }
            writebuffer.clear(minimumCapacity: compressed.readableBytes * 4)
            bz2.avail_in = UInt32(compressed.readableBytes)
            return compressed.withUnsafeMutableReadableBytes({ compressed in
                bz2.next_in = compressed.baseAddress?.assumingMemoryBound(to: CChar.self)
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
                        return writebuffer
                    }
                    // Grow output buffer
                    writebuffer.reserveCapacity(minimumWritableBytes: 128*1024)
                }
            })
        }

        deinit {
            let error = BZ2_bzDecompressEnd(&self.bz2)
            guard error == BZ_OK else {
                fatalError("BZ2_bzDecompressEnd failed \(error)")
            }
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: sequence.makeAsyncIterator())
    }
}
