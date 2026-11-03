import Foundation
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers
import NIOFileSystem

/// Protocol of how a file can be chunked into 8 MB parts and upload as individual ByteBuffers. Unfortunately, `AsyncHTTPClient` only accepts ByteBuffers so a memory copy can not be avoided.
public protocol S3UploadAble {
    associatedtype ByteBufferSequence: AsyncSequence where ByteBufferSequence.Element == ByteBuffer, ByteBufferSequence: Sendable
    func readChunks(chunkLength: ByteCount) -> ByteBufferSequence
    
    func getFileSize() async throws -> Int64
}

extension ReadFileHandle: S3UploadAble {
    public func getFileSize() async throws -> Int64 {
        return try await self.info().size
    }
}

/// Retains the open file while uploads read it, including files that were never linked to a path.
/// Each upload gets an independent chunk iterator; no shared file offset is modified.
extension Foundation.FileHandle: S3UploadAble {
    public func getFileSize() async throws -> Int64 {
        Int64(fileSize())
    }

    public func readChunks(chunkLength: ByteCount) -> FileHandleUploadChunks {
        FileHandleUploadChunks(file: self, size: fileSize(), chunkSize: Int(chunkLength.bytes))
    }
}

public struct FileHandleUploadChunks: AsyncSequence, Sendable {
    public typealias Element = ByteBuffer
    let file: Foundation.FileHandle
    let size: Int
    let chunkSize: Int

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(file: file, size: size, chunkSize: chunkSize)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        let file: Foundation.FileHandle
        let size: Int
        let chunkSize: Int
        private var offset = 0
        private let buffer = NIOLockedValueBox(ByteBuffer())

        fileprivate init(file: Foundation.FileHandle, size: Int, chunkSize: Int) {
            precondition(chunkSize > 0)
            self.file = file
            self.size = size
            self.chunkSize = chunkSize
        }

        public mutating func next() async throws -> ByteBuffer? {
            try Task.checkCancellation()
            guard offset < size else { return nil }
            let length = Swift.min(chunkSize, size - offset)
            let fileOffset = offset
            let chunk = try await NIOThreadPool.singleton.runIfActive { [file, buffer] in
                try buffer.withLockedValue { buffer in
                    // Reuse storage when the previous chunk has been released. Copy-on-write
                    // protects chunks still retained by in-flight uploads.
                    buffer.clear()
                    try buffer.writeWithUnsafeMutableBytes(minimumWritableBytes: length) { bytes in
                        var count = 0
                        while count < length {
                            let n = pread(file.fileDescriptor, bytes.baseAddress!.advanced(by: count), length - count, off_t(fileOffset + count))
                            if n < 0 {
                                if errno == EINTR { continue }
                                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                            }
                            guard n > 0 else { throw S3UploaderError.unexpectedEndOfFile }
                            count += n
                        }
                        return count
                    }
                    return buffer
                }
            }
            try Task.checkCancellation()
            offset += length
            return chunk
        }
    }
}

extension ByteBuffer: S3UploadAble {
    public func getFileSize() async throws -> Int64 {
        return Int64(self.readableBytes)
    }
    
    public func readChunks(chunkLength: ByteCount) -> AsyncStream<ByteBuffer> {
        let chunkSize = Int(chunkLength.bytes)
        var copy = self
        return AsyncStream { continuation in
            while copy.readableBytes > 0 {
                let slice = copy.readSlice(length: min(chunkSize, copy.readableBytes))!
                continuation.yield(slice)
            }
            continuation.finish()
        }
    }
}
