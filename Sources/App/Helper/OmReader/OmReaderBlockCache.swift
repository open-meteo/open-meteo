import OmFileFormat
import Foundation


/**
 Chunk data into blocks of 64k and store blocks in a KV cache.
 
 Cache misses are isolated by the underlaying cache coordinator, preventing same blocks requested from the backend.
 Cache hits do not block. Atomic operations are used to prevent race conditions.
 
 Cache keys are linear for 8MB (super block). Linear cache keys can be stored linearly by the underlaying atomic cache. This is the default AWS S3 `multipart_chunksize`.
 Consecutive reads of blocks are merged together. E.g. Two 64 kb reads are merged to a single 128 kb read. This reduces latency if data across multiple blocks is read.
 Only reads within the 8MB super block are merged to optimise for AWS S3 multipart chunk size.
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
    
    /// Number of  64 kb block to form a super block. Aligned to 8MB.
    @inlinable var superBlockLength: Int {
        return 8*1024*1024 / cache.cache.blockSize
    }
    
    /// Calculate cache key for block. 100 blocks are stored consecutive in cache.
    @inlinable func calculateCacheKey(block: Int) -> UInt64 {
        return cacheKey.addFnv1aHash(UInt64(block / superBlockLength)) &+ UInt64(block % superBlockLength)
    }
    
    func prefetchData(offset: Int, count: Int) async throws {
        // TODO: Prefetch data from backend in detached Task
        
        let blockSize = cache.cache.blockSize
        let blocks = offset / blockSize ..< (offset + count).divideRoundedUp(divisor: blockSize)
        for block in blocks {
            cache.prefetchData(key: calculateCacheKey(block: block))
        }
    }
    
    @inlinable var count: Int {
        return backend.count
    }
    
    fileprivate enum DataOwnership {
        /// Only usable for a short time. Must not be freed.
        case borrowed(UnsafeRawBufferPointer)
        
        /// Must be freed after use
        case owned(UnsafeRawBufferPointer)
    }
    
    /// Fetch data from cache or backend. If data is cached, return a temporary pointer. Otherwise allocate a new buffer which must be freed afterwards
    fileprivate func fetch(offset: Int, count: Int) async throws -> DataOwnership {
        let blockSize = cache.cache.blockSize
        let dataRange = offset ..< (offset + count)
        let fileSize = self.backend.count
        let blocks = dataRange.divideRoundedUp(divisor: blockSize)
        let superBlocks = dataRange.divideRoundedUp(divisor: blockSize * superBlockLength)
        //print("withData superBlocks \(superBlocks), \(blocks.count) blocks \(blocks), offset \(offset), count \(count)")
        
        /// Check if all blocks are available sequentially in cache
        let sameSuperBlock = superBlocks.count == 1
        if sameSuperBlock, let ptr = cache.cache.get(key: calculateCacheKey(block: blocks.lowerBound), count: UInt64(blocks.count)) {
            let blockRange = blocks.lowerBound * blockSize ..< blocks.upperBound * blockSize
            let range = dataRange.intersect(fileTime: blockRange)!
            return .borrowed(UnsafeRawBufferPointer(rebasing: ptr[range.file]))
        }
        
        let data = UnsafeMutableRawBufferPointer.allocate(byteCount: count, alignment: 1)
        //defer { data.deallocate() }
        for superBlock in superBlocks {
            let superKey = cacheKey.addFnv1aHash(UInt64(superBlock))
            let blocks = (superBlock * superBlockLength ..< (superBlock + 1) * superBlockLength).clamped(to: blocks)
            let keyStart = superKey &+ UInt64(blocks.lowerBound)
            //print("withData blocks \(blocks)")
            try await cache.get(key: keyStart, count: blocks.count, provider: ({ (key, count) in
                let block = blocks.lowerBound + Int(key &- keyStart)
                let fileRange = block * blockSize ..< min((block + count) * blockSize, fileSize)
                return try await backend.getData(offset: fileRange.lowerBound, count: fileRange.count)
            }), dataCallback: {(key, value) in
                let block = blocks.lowerBound + Int(key &- keyStart)
                let fileRange = block * blockSize ..< min((block + 1) * blockSize, fileSize)
                let range = dataRange.intersect(fileTime: fileRange)!
                let dest = UnsafeMutableRawBufferPointer(rebasing: data[range.array])
                value[range.file].copyBytes(to: dest)
            })
        }
        return .owned(UnsafeRawBufferPointer(data))
    }
    
    /// Execute a closure with retrieved data. If data is cached, the underlaying data is used to call be closure (zero-copy).
    func withData<T: Sendable>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
        switch try await fetch(offset: offset, count: count) {
        case .borrowed(let data):
            return try fn(data)
        case .owned(let data):
            defer { data.deallocate() }
            return try fn(data)
        }
    }
    
    /// Get a exclusive `Data` object which is retrained independent from the underlaying cache.
    func getData(offset: Int, count: Int) async throws -> Data {
        switch try await fetch(offset: offset, count: count) {
        case .borrowed(let data):
            // Copy data
            return Data(data)
        case .owned(let data):
            // Reuse existing buffer
            let ptr = UnsafeMutableRawPointer(mutating: data.baseAddress!)
            return Data(bytesNoCopy: ptr, count: count, deallocator: .free)
        }
    }
    
    /// Which blocks have been accessed recently. When a file is modified on the remote server, use a list of blocks to preload the new file.
    func listOfActiveBlocks(maxAgeSeconds: UInt) -> [Int] {
        // TODO: return consecutive blocks as [Range]
        
        let totalCount = self.backend.count
        let blockSize = cache.cache.blockSize
        let blocks = 0..<totalCount.divideRoundedUp(divisor: blockSize)
        return blocks.compactMap({ block in
            return cache.cache.get(key: calculateCacheKey(block: block), maxAccessedAgeInSeconds: maxAgeSeconds).map{_ in block}
        })
    }
    
    /// Remove cached data blocks that are older then a couple of seconds. Return the number of deleted blocks
    func deleteCachedBlocks(olderThanSeconds: UInt) -> Int {
        let blockSize = cache.cache.blockSize
        let dataRange = 0..<backend.count
        let blocks = dataRange.divideRoundedUp(divisor: blockSize)
        let superBlocks = dataRange.divideRoundedUp(divisor: blockSize * superBlockLength)
        var deletedCount = 0
        for superBlock in superBlocks {
            let superKey = cacheKey.addFnv1aHash(UInt64(superBlock))
            let blocks = (superBlock * superBlockLength ..< (superBlock + 1) * superBlockLength).clamped(to: blocks)
            deletedCount += cache.cache.delete(key: superKey, count: UInt64(blocks.count), olderThanSeconds: olderThanSeconds)
        }
        return deletedCount
    }
    
    /// Load list of blocks into cache. This is used to prefetch data after rotating files.
    func preloadBlocks(blocks: [Int]) async throws {
        // TODO: preload consecutive blocks as [Range<Int>]
        
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
                count: 1,
                provider: ({ _,_ in
                    return try await backend.getData(offset: blockRange.lowerBound, count: blockRange.count)
                }),
                dataCallback: { _,_ in }
            )
        }
    }
}
