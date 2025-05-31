import OmFileFormat
import Foundation


/*protocol OmFileReaderBackendAsyncData: OmFileReaderBackendAsync {
    /// Read data. Must be thread safe!
    func getData(offset: Int, count: Int) async throws -> Data
}*/

/**
 Chunk data into blocks of 64k and store blocks in a KV cache
 */
final class OmReaderBlockCache<Backend: OmFileReaderBackendAsync, Cache: BlockCacheStorable>: OmFileReaderBackendAsync, Sendable {
    let backend: Backend
    private let cache: KVCacheCoordinator<Cache>
    let cacheKey: UInt64
    
    typealias DataType = Data
    
    init(backend: Backend, cache: MmapBlockCache<Cache>, cacheKey: UInt64) {
        self.backend = backend
        self.cache = KVCacheCoordinator(cache: cache)
        self.cacheKey = cacheKey
    }
    
    
    func prefetchData(offset: Int, count: Int) async throws {
        // Maybe could prefetch cached blocks as well
    }
    
    var count: Int {
        return backend.count
    }
    
    func withData<T>(offset: Int, count: Int, fn: (UnsafeRawPointer) async throws -> T) async throws -> T {
        let blockSize = 65536
        let dataRange = offset ..< (offset + count)
        let data = UnsafeMutableRawPointer.allocate(byteCount: count, alignment: 1)
        defer { data.deallocate() }
        let totalCount = self.backend.count
        // TODO shortcut for single block
        
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        for block in blocks {
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            print(range)
            let value = try await cache.get(key: cacheKey &+ UInt64(block)) {
                try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
            }
            let dest = UnsafeMutableRawBufferPointer(start: data.advanced(by: range.array.lowerBound), count: range.array.count)
            value[range.file].copyBytes(to: dest)
            // copy data into output data
            //data[range.array] = value[range.file]
        }
        return try await fn(data)
    }
    
    
    func getData(offset: Int, count: Int) async throws -> Data {
        let blockSize = 65536
        let dataRange = offset ..< (offset + count)
        var data = Data()
        data.reserveCapacity(count)
        let totalCount = self.backend.count
        // TODO shortcut for single block
        
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        for block in blocks {
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            print(range)
            let value = try await cache.get(key: cacheKey &+ UInt64(block)) {
                try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
            }
            // copy data into output data
            //data[range.array] = value[range.file]
            let _ = data.withUnsafeMutableBytes { data in
                let dest = UnsafeMutableRawBufferPointer(start: data.advanced(by: range.array.lowerBound), count: range.array.count)
                return value[range.file].copyBytes(to: dest)
            }
        }
        return data
    }
}
