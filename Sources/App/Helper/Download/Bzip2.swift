import Foundation
import NIO
import CBz2lib
import AsyncAlgorithms

extension AsyncSequence where Element == ByteBuffer, Self: Sendable {
    /// Decompress incoming data using bzip2. Processing takes place in detached task
    func decompressBzip2() -> AsyncThrowingChannel<ByteBuffer, Error> {
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
