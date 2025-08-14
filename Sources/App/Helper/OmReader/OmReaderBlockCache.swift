import OmFileFormat
import Foundation


/**
 Chunk data into blocks of 64k and store blocks in a KV cache
 */
final class OmReaderBlockCache<Backend: OmFileReaderBackend, Cache: AtomicBlockCacheStorable>: OmFileReaderBackend, Sendable {
    let backend: Backend
    private let cache: AtomicCacheCoordinator<Cache>
    let cacheKey: UInt64
    
    typealias DataType = Data
    
    init(backend: Backend, cache: AtomicCacheCoordinator<Cache>, cacheKey: UInt64) {
        self.backend = backend
        self.cache = cache
        self.cacheKey = cacheKey
    }
    
    /// Calculate cache key for block. 100 blocks are stored consecutive in cache.
    @inlinable func calculateCacheKey(block: Int) -> UInt64 {
        return cacheKey.addFnv1aHash(UInt64(block / 10)) &+ UInt64(block % 100)
    }
    
    func prefetchData(offset: Int, count: Int) async throws {
        let blockSize = cache.cache.blockSize
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        for block in blocks {
            cache.prefetchData(key: calculateCacheKey(block: block))
        }
    }
    
    var count: Int {
        return backend.count
    }
    
    func withData<T: Sendable>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        let blockSize = cache.cache.blockSize
        let dataRange = offset ..< (offset + count)
        let totalCount = self.backend.count
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        
        /// Check if all blocks are available sequentially in cache
        let sameSuperBlock = blocks.lowerBound / 100 == (blocks.upperBound-1) / 100
        if sameSuperBlock, let ptr = cache.cache.get(key: calculateCacheKey(block: blocks.lowerBound), count: UInt64(blocks.count)) {
            let blockRange = blocks.lowerBound * blockSize ..< blocks.upperBound * blockSize
            let range = dataRange.intersect(fileTime: blockRange)!
            return try fn(UnsafeRawBufferPointer(rebasing: ptr[range.file]))
        }
        
        let data = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        defer { data.deallocate() }
        //print("withData \(blocks.count) blocks")
        for block in blocks {
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            let dest = UnsafeMutableRawBufferPointer(rebasing: data[range.array])
            let ptr = try await cache.get(
                key: calculateCacheKey(block: block),
                backendFetch: ({
                    return try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
                })
            )
            let _ = ptr[range.file].copyBytes(to: dest)
        }
        return try fn(UnsafeRawBufferPointer(data))
    }
    
    
    func getData(offset: Int, count: Int) async throws -> Data {
        let blockSize = cache.cache.blockSize
        let dataRange = offset ..< (offset + count)
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        
        /// Check if all blocks are available sequentially in cache
        let sameSuperBlock = blocks.lowerBound / 100 == (blocks.upperBound-1) / 100
        if sameSuperBlock, let ptr = cache.cache.get(key: calculateCacheKey(block: blocks.lowerBound), count: UInt64(blocks.count)) {
            let blockRange = blocks.lowerBound * blockSize ..< blocks.upperBound * blockSize
            let range = dataRange.intersect(fileTime: blockRange)!
            return Data(ptr[range.file])
        }
        
        let data = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        let dataRet = Data(bytesNoCopy: data.baseAddress!, count: count, deallocator: .free)
        let totalCount = self.backend.count
        
        //rint("getData \(blocks.count) blocks")
        for block in blocks {
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let range = dataRange.intersect(fileTime: blockRange)!
            let dest = UnsafeMutableRawBufferPointer(rebasing: data[range.array])
            let ptr = try await cache.get(
                key: calculateCacheKey(block: block),
                backendFetch: ({
                    return try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
                })
            )
            let _ = ptr[range.file].copyBytes(to: dest)
        }
        return dataRet
    }
    
    /// Which blocks have been accessed recently. When a file is modified on the remote server, use a list of blocks to preload the new file.
    func listOfActiveBlocks(maxAgeSeconds: UInt) -> [Int] {
        let totalCount = self.backend.count
        let blockSize = cache.cache.blockSize
        let blocks = 0..<totalCount.divideRoundedUp(divisor: blockSize)
        return blocks.compactMap({ block in
            return cache.cache.get(key: calculateCacheKey(block: block), maxAccessedAgeInSeconds: maxAgeSeconds).map{_ in block}
        })
    }
    
    /// Load list of blocks into cache. This is used to prefetch data after rotating files.
    func preloadBlocks(blocks: [Int]) async throws {
        let blockSize = cache.cache.blockSize
        let totalCount = self.backend.count
        let totalBlockCount = totalCount.divideRoundedUp(divisor: blockSize)
        for block in blocks {
            guard block < totalBlockCount else {
                /// The list of blocks is from an older file revision.
                /// The new file could be smaller and contain fewer blocks.
                continue
            }
            let blockRange = block * blockSize ..< min((block + 1) * blockSize, totalCount)
            let _ = try await cache.get(
                key: calculateCacheKey(block: block),
                backendFetch: ({
                    return try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
                })
            )
        }
    }
}
