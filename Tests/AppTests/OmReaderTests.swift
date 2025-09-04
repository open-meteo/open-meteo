import Foundation
@testable import App
import Testing
import VaporTesting
import OmFileFormat

@Suite struct OmReaderTests {
    @Test func metaCache() throws {
        #expect(MemoryLayout<OmHttpMetaCache.Entry>.stride == 72)
        
        let entry = try OmHttpMetaCache.Entry(contentLength: 1234, lastModified: Timestamp(252454), lastValidated: Timestamp(34598743), eTagString: "srgkjnsrgasf")
        #expect(entry.eTag.string.count == 12)
        #expect(entry.lastModified.timeIntervalSince1970 == 252454)
        #expect(entry.lastValidated.timeIntervalSince1970 == 34598743)
        #expect(entry.eTag.string == "srgkjnsrgasf")
        
        let entry48 = try OmHttpMetaCache.Entry(contentLength: 1234, lastModified: Timestamp(252454), lastValidated: Timestamp(34598743), eTagString: "srgkjnsrgasfwfjnwofegne3wognwkjndgwongpwiefngfog")
        #expect(entry48.eTag.string.count == 48)
        #expect(entry48.eTag.string == "srgkjnsrgasfwfjnwofegne3wognwkjndgwongpwiefngfog")
    }
    
    @Test func httpRead() async throws {
        try await withApp { app in
            let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
            let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)!
            let read = try await OmFileReader(fn: readFn).expectArray(of: Float.self)
            let value = try await read.read(range: [250..<251, 420..<421])
            #expect(value.first == 214)
        }
    }

    @Test func blockCache() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)!
        let file = "cache64k50.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try AtomicBlockCache(file: file, blockSize: 65536, blockCount: 50)
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: AtomicCacheCoordinator(cache: cache), cacheKey: readFn.cacheKey)
        let read = try! await OmFileReader(fn: cacheFn).expectArray(of: Float.self)
        let value = try await read.read(range: [250..<251, 420..<421])
        #expect(value.first == 214)
        
        let activeBlocks = cacheFn.listOfActiveBlocks(maxAgeSeconds: 10)
        #expect(activeBlocks == [3, 8])
        
        let value2 = try await read.read(range: [250..<251, 420..<421])
        #expect(value2.first == 214)

        let value3 = try await read.read(range: [120..<121, 420..<421])
        #expect(value3.first == 743)
        let activeBlocks2 = cacheFn.listOfActiveBlocks(maxAgeSeconds: 10)
        #expect(activeBlocks2 == [1, 3, 8])
    }
    
    /// Consecutive reads that are not cached should be merged
    @Test func consecutiveBlockReads() async throws {
        let file = "cache64k50_consecutive.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try AtomicBlockCache(file: file, blockSize: 20, blockCount: 10)
        let coordinator = AtomicCacheCoordinator(cache: cache)
        // Read 2 blocks, both not cached
        try await coordinator.get(key: 123, count: 2, provider: { key,count in
            #expect(key == 123)
            #expect(count == 2)
            return (0..<count * cache.blockSize).map{UInt8(truncatingIfNeeded: $0)}
        }, dataCallback: { key, data in
            switch key {
            case 123:
                #expect(data[4] == 4)
            case 124:
                #expect(data[4] == 24)
            default:
                #expect(Bool(false))
            }
        })
        // First block cached, second missing
        try await coordinator.get(key: 124, count: 2, provider: { key,count in
            #expect(key == 125)
            #expect(count == 1)
            return (0..<count * cache.blockSize).map{UInt8(truncatingIfNeeded: $0)}
        }, dataCallback: { key, data in
            switch key {
            case 124:
                #expect(data[4] == 24)
            case 125:
                #expect(data[4] == 4)
            default:
                #expect(Bool(false))
            }
        })
        // Both blocks cached
        try await coordinator.get(key: 123, count: 3, provider: { key,count in
            #expect(Bool(false))
            return (0..<count * cache.blockSize).map{UInt8(truncatingIfNeeded: $0)}
        }, dataCallback: { key, data in
            switch key {
            case 123:
                #expect(data[4] == 4)
            case 124:
                #expect(data[4] == 24)
            case 125:
                #expect(data[4] == 4)
            default:
                #expect(Bool(false))
            }
        })
    }

    @Test func blockCacheConcurrent() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)!
        let file = "cache64k50_2.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try AtomicBlockCache(file: file, blockSize: 65536, blockCount: 50)
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: AtomicCacheCoordinator(cache: cache), cacheKey: readFn.cacheKey)
        let read = try await OmFileReader(fn: cacheFn).expectArray(of: Float.self, io_size_max: 4096)
        let value = try await read.readConcurrent(range: [0..<257, 511..<513])
        #expect(value[123] == 1218)

        let value2 = try await read.readConcurrent(range: [0..<257, 511..<513])
        #expect(value2[123] == 1218)
    }

    /*func testRemoteFileManager() async throws {
        let value = try await RemoteOmFileManager.instance.with(file: .staticFile(domain: .dwd_icon_d2_eps, variable: "HSURF", chunk: nil), client: .shared, logger: .init(label: "")) { reader in
            try await reader.asArray(of: Float.self)!.read(range: [250..<251, 420..<421])
        }
        #expect(value?.first == 214)
    }*/

    @Test func keyValueCache() async throws {
        let data = DataAsClass(data: Data(repeating: 0, count: (64 + 16)*50))
        let cache = AtomicBlockCache(data: data, blockSize: 64)
        cache.set(key: 234923, value: Data(repeating: 123, count: 64))
        cache.set(key: 234923+50, value: Data(repeating: 142, count: 64))
        #expect(cache.get(key: 234923, maxAccessedAgeInSeconds: 10)!.data == Data(repeating: 123, count: 64))
        #expect(cache.get(key: 234923+50, maxAccessedAgeInSeconds: 10)!.data == Data(repeating: 142, count: 64))
        #expect(cache.blockCount == 50)

        for i in 0..<50 {
            cache.set(key: UInt64(1000+i), value: Data(repeating: UInt8(123+i), count: 64))
        }
        for i in 0..<50 {
            #expect(cache.get(key: UInt64(1000+i), maxAccessedAgeInSeconds: 10)!.data == Data(repeating: UInt8(123+i), count: 64))
        }
        // Cache got overwritten
        #expect(cache.get(key: 234923, maxAccessedAgeInSeconds: 10) == nil)
        #expect(cache.get(key: 234923+50, maxAccessedAgeInSeconds: 10) == nil)

        // First 23 keys are sequentially in cache
        #expect(cache.get(key: 1000, count: 23) != nil)
        #expect(cache.get(key: 1022, count: 2) == nil)
        // Key 1023 is offset by 2 slots
        #expect(cache.get(key: 1023, count: 25) != nil)
        // Keys 1048 until 1050 are sequentially in cache again, but offset by 2 and wraps at the end of the cache
        #expect(cache.get(key: 1048, count: 2) != nil)

        #expect(cache.delete(key: 1000, count: 2, olderThanSeconds: 10) == 0)
        #expect(cache.delete(key: 1000, count: 2, olderThanSeconds: 0) == 2)
        #expect(cache.get(key: 1000, count: 2) == nil)
        
        // Test key delete across last cached block
        #expect(cache.get(key: 1047, count: 2) == nil)
        #expect(cache.get(key: 1047, count: 1) != nil)
        #expect(cache.get(key: 1048, count: 1) != nil)
        #expect(cache.delete(key: 1047, count: 2, olderThanSeconds: 0) == 2)
        #expect(cache.get(key: 1047, count: 1) == nil)
        #expect(cache.get(key: 1048, count: 1) == nil)
        
        cache.set(key: .max, value: Data(repeating: 123, count: 64))
        #expect(cache.get(key: .max, maxAccessedAgeInSeconds: 10)!.data == Data(repeating: 123, count: 64))
    }
}
