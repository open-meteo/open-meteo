import OmFileFormat
import Foundation


protocol OmFileReaderBackendAsyncData: OmFileReaderBackendAsync {
    /// Read data. Must be thread safe!
    func getData(offset: Int, count: Int) async throws -> Data
}

/**
 Chunk data into blocks of 64k and store blocks in a KV cache
 */
final class OmReaderBlockCache<Backend: OmFileReaderBackendAsyncData & Sendable, Cache: KVCache>: OmFileReaderBackendAsync, Sendable {
    let backend: Backend
    private let cache: KVCacheCoordinator<Cache>
    let cacheKey: UInt64
    
    typealias DataType = Data
    
    init(backend: Backend, cache: Cache, cacheKey: UInt64) {
        self.backend = backend
        self.cache = KVCacheCoordinator(cache: cache)
        self.cacheKey = cacheKey
    }
    
    func getCount() async throws -> UInt64 {
        try await backend.getCount()
    }
    
    func prefetchData(offset: Int, count: Int) async throws {
        // Maybe could prefetch cached blocks as well
    }
    
    func getData(offset: Int, count: Int) async throws -> Data {
        let blockSize = 65536
        let dataRange = offset ..< (offset + count)
        var data = Data()
        data.reserveCapacity(count)
        let totalCount = Int(try await getCount())
        
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        for block in blocks {
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            let value = try await cache.get(key: cacheKey &+ UInt64(block)) {
                try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
            }
            // copy data into ouput data
            data[range.array] = value[range.file]
        }
        return try await backend.getData(offset: offset, count: count)
    }
}
