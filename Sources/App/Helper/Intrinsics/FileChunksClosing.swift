import NIOFileSystem
import NIOCore

struct FileChunksClosing: AsyncSequence {
    let handle: ReadFileHandle
    let chunkLength: ByteCount
    
    struct Iterator: AsyncIteratorProtocol {
        let handle: ReadFileHandle
        var chunks: FileChunks.AsyncIterator
        mutating func next() async throws -> ByteBuffer? {
            guard let chunk = try await chunks.next() else {
                try await handle.close()
                return nil
            }
            return chunk
        }
    }
    
    func makeAsyncIterator() -> Iterator {
        Iterator(handle: handle, chunks: handle.readChunks(chunkLength: chunkLength).makeAsyncIterator())
    }
}

extension ReadFileHandle {
    /// Returns an asynchronous sequence of chunks read from the file. Closes the file after read.
    ///
    /// - Parameters:
    ///   - chunkLength: The length of chunks to read, defaults to 128 KiB.
    /// - SeeAlso: ``ReadableFileHandleProtocol/readChunks(in:chunkLength:)-2dz6``.
    /// - Returns: An `AsyncSequence` of chunks read from the file.
    func readChunksAndClose(chunkLength: ByteCount = .kibibytes(128)) -> FileChunksClosing {
        return FileChunksClosing(handle: self, chunkLength: chunkLength)
    }
}
