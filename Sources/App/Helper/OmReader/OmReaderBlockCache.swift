import OmFileFormat
import Foundation


protocol OmFileReaderBackendAsyncData: OmFileReaderBackendAsync {
    /// Read data. Must be thread safe!
    func getData(offset: Int, count: Int) async throws -> Data
}

/**
 Chunk data into blocks of 64k and store blocks in a KV cache
 */
final class OmReaderBlockCache<Backend: OmFileReaderBackendAsyncData, Cache: KVCache>: OmFileReaderBackendAsync {
    let backend: Backend
    let cache: Cache
    let cacheKey: Int
    
    typealias DataType = Data
    
    init(backend: Backend, cache: Cache, cacheKey: Int) {
        self.backend = backend
        self.cache = cache
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
            if let value = cache.get(key: cacheKey &+ block) {
                // copy data into output data
                //print("Using cached block \(block)")
                data[range.array] = value[range.file]
                continue
            }
            
            // missing, request block from backend
            let value = try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
            cache.set(key: cacheKey &+ block, value: value)
            
            // copy data into ouput data
            data[range.array] = value[range.file]
        }
        
        return try await backend.getData(offset: offset, count: count)
    }
    
}

protocol KVCache {
    func set(key: Int, value: Data)
    func get(key: Int) -> Data?
}

class SimpleKVCache: KVCache {
    var cache: [Int: Data] = [:]
    
    func set(key: Int, value: Data) {
        print("Storing \(value.count) bytes in cache for key \(key)")
        cache[key] = value
    }
    
    func get(key: Int) -> Data? {
        if let value = cache[key] {
            print("Cache HIT for key \(key)")
            return value
        }
        print("Cache MISS for key \(key)")
        return nil
    }
}
