import OmFileFormat
import Foundation

/*protocol OmFileReaderAsyncProvider {
    func asArray<OmType: OmFileArrayDataTypeProtocol>(of: OmType.Type, io_size_max: UInt64, io_size_merge: UInt64) -> any OmFileReaderAsyncArrayProvider
}

protocol OmFileReaderAsyncArrayProvider {
    associatedtype OmType: OmFileArrayDataTypeProtocol
    
    func willNeed(range: [Range<UInt64>]?) async throws
    func read(into: UnsafeMutablePointer<Float>, range: [Range<UInt64>], intoCubeOffset: [UInt64]?, intoCubeDimension: [UInt64]?) async throws
}

extension OmFileReaderAsync: OmFileReaderAsyncProvider {
    func asArray<OmType>(of: OmType.Type, io_size_max: UInt64, io_size_merge: UInt64) -> any OmFileReaderAsyncArrayProvider where OmType : OmFileFormat.OmFileArrayDataTypeProtocol {
        return self.asArray(of: of, io_size_max: io_size_max, io_size_merge: io_size_merge)
    }
}
extension OmFileReaderAsyncArray: OmFileReaderAsyncArrayProvider {
    func read(into: UnsafeMutablePointer<Float>, range: [Range<UInt64>], intoCubeOffset: [UInt64]?, intoCubeDimension: [UInt64]?) async throws {
        return try await self.read(into: into, range: range, intoCubeOffset: intoCubeOffset, intoCubeDimension: intoCubeDimension)
    }
}*/

/**
 Keep track of remote files.
 Store 404 state
 Keep files open
 Reload files on read/willNeed if remote file was modified, retry with new file
 Background check if remote file was modified (every x seconds)
 */
final class RemoteFileManager {
    /// Isolate requests to files
    var cache = IsolatedSerialisationCache<OmFileManagerReadable, OmHttpReaderBackend?>()
    
    func get(file: OmFileManagerReadable, forceNew: Bool = false) async throws -> OmFileReaderAsync<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>>? {
        guard let backend = try await cache.get(key: file, forceNew: forceNew, provider: {
            try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: file.getFilePath())
        }) else {
            return nil
        }
        let cacheFn = OmReaderBlockCache(backend: backend, cache: OpenMeteo.dataBlockCache!, cacheKey: backend.cacheKey)
        return try await OmFileReaderAsync(fn: cacheFn)
    }
    
    public func willNeed(file: OmFileManagerReadable, range: [Range<UInt64>]? = nil) async throws {
        do {
            let read = try await get(file: file)!.asArray(of: Float.self)!
            try await read.willNeed(range: range)
        } catch CurlError.fileModifiedSinceLastDownload {
            let read = try await get(file: file, forceNew: true)!.asArray(of: Float.self)!
            try await read.willNeed(range: range)
        }
    }
    
    public func read(file: OmFileManagerReadable, into: UnsafeMutablePointer<Float>, range: [Range<UInt64>], intoCubeOffset: [UInt64]? = nil, intoCubeDimension: [UInt64]? = nil) async throws {
        do {
            let read = try await get(file: file)!.asArray(of: Float.self)!
            try await read.read(into: into, range: range, intoCubeOffset: intoCubeOffset, intoCubeDimension: intoCubeDimension)
        } catch CurlError.fileModifiedSinceLastDownload {
            // File was modified on the remote server
            let read = try await get(file: file, forceNew: true)!.asArray(of: Float.self)!
            try await read.read(into: into, range: range, intoCubeOffset: intoCubeOffset, intoCubeDimension: intoCubeDimension)
        }
    }
}


/**
 Chunk data into blocks of 64k and store blocks in a KV cache
 */
final class OmReaderBlockCache<Backend: OmFileReaderBackendAsync, Cache: AtomicBlockCacheStorable>: OmFileReaderBackendAsync, Sendable {
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

extension UnsafeMutableRawBufferPointer: @unchecked @retroactive Sendable {
    
}
