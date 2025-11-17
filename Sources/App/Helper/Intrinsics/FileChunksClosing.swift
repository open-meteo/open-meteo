import NIOFileSystem
import NIOCore

struct FileChunksClosing: AsyncSequence {
    let handle: ReadFileHandle
    let chunkLength: ByteCount
    
    final class Iterator: AsyncIteratorProtocol {
        let handle: ReadFileHandle
        var chunks: FileChunks.AsyncIterator
        var closed = false
        func next() async throws -> ByteBuffer? {
            guard let chunk = try await chunks.next() else {
                try await handle.close()
                closed = true
                return nil
            }
            return chunk
        }
        
        init(handle: ReadFileHandle, chunks: FileChunks.AsyncIterator) {
            self.handle = handle
            self.chunks = chunks
        }
        
        deinit {
            if closed == true {
                return
            }
            let handle = self.handle
            _ = Task {
                try await handle.close()
            }
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
