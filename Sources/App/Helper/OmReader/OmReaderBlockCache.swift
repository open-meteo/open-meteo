import OmFileFormat
import Foundation


/**
 Chunk data into blocks of 64k and store blocks in a KV cache
 */
struct OmReaderBlockCache<Backend: OmFileReaderBackend, Cache: AtomicBlockCacheStorable>: OmFileReaderBackend, Sendable {
    let backend: Backend
    private let cache: AtomicCacheCoordinator<Cache>
    let cacheKey: UInt64
    
    typealias DataType = Data
    
    init(backend: Backend, cache: AtomicCacheCoordinator<Cache>, cacheKey: UInt64) {
        self.backend = backend
        self.cache = cache
        self.cacheKey = cacheKey
    }
    
    
    func prefetchData(offset: Int, count: Int) async throws {
        let blockSize = 65536
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        for block in blocks {
            cache.prefetchData(key: cacheKey &+ UInt64(block))
        }
    }
    
    var count: Int {
        return backend.count
    }
    
    func withData<T: Sendable>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let blockSize = 65536
        let dataRange = offset ..< (offset + count)
        let totalCount = self.backend.count
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        
        /// TODO: check if cached data is sequentially available in cache
        /// Single block read, can directly execute closure on cached data
        /// No extra allocation
        if blocks.count == 1 {
            //print("withData single block")
            let block = offset / blockSize
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            return try await cache.with(
                key: cacheKey &+ UInt64(block),
                backendFetch: ({
                try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
            }), callback: ({ ptr in
                return try fn(UnsafeRawBufferPointer(rebasing: ptr[range.file]))
            }))
        }
        
        let data = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { data.deallocate() }
        //print("withData \(blocks.count) blocks")
        for block in blocks {
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            let dest = UnsafeMutableRawBufferPointer(rebasing: data[range.array])
            try await cache.with(
                key: cacheKey &+ UInt64(block),
                backendFetch: ({
                try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
            }), callback: ({ ptr in
                let _ = ptr[range.file].copyBytes(to: dest)
            }))
        }
        return try fn(UnsafeRawBufferPointer(data))
    }
    
    
    func getData(offset: Int, count: Int) async throws -> Data {
        let blockSize = 65536
        let dataRange = offset ..< (offset + count)
        let data = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        let dataRet = Data(bytesNoCopy: data.baseAddress!, count: count, deallocator: .free)
        let totalCount = self.backend.count
        
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        //rint("getData \(blocks.count) blocks")
        for block in blocks {
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            let dest = UnsafeMutableRawBufferPointer(rebasing: data[range.array])
            try await cache.with(
                key: cacheKey &+ UInt64(block),
                backendFetch: ({
                try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
            }), callback: ({ ptr in
                //data.replaceSubrange(range.array, with: ptr[range.file])
                let _ = ptr[range.file].copyBytes(to: dest)
            }))
        }
        return dataRet
    }
}
