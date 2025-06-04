import Foundation
@testable import App
import XCTest
import Vapor
import OmFileFormat

final class OmReaderTests: XCTestCase {
    private var app: Application?
    
    override func setUp() async throws {
        app = try await Application.testable()
    }

    override func tearDown() async throws {
        try await app?.asyncShutdown()
        app = nil
    }
    
    func testHttpRead() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)!
        let read = try await OmFileReader(fn: readFn).asArray(of: Float.self)!
        let value = try await read.read(range: [250..<251, 420..<421])
        XCTAssertEqual(value.first, 214)
    }
    
    func testBlockCache() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)!
        let file = "cache64k50.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try AtomicBlockCache(file: file, blockSize: 65536, blockCount: 50)
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: AtomicCacheCoordinator(cache: cache), cacheKey: readFn.cacheKey)
        let read = try! await OmFileReader(fn: cacheFn).asArray(of: Float.self)!
        let value = try await read.read(range: [250..<251, 420..<421])
        XCTAssertEqual(value.first, 214)
        
        let value2 = try await read.read(range: [250..<251, 420..<421])
        XCTAssertEqual(value2.first, 214)
    }
    
    func testBlockCacheConcurrent() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)!
        let file = "cache64k50_2.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try AtomicBlockCache(file: file, blockSize: 65536, blockCount: 50)
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: AtomicCacheCoordinator(cache: cache), cacheKey: readFn.cacheKey)
        let read = try await OmFileReader(fn: cacheFn).asArray(of: Float.self, io_size_max: 4096)!
        let value = try await read.readConcurrent(range: [0..<257, 511..<513])
        XCTAssertEqual(value[123], 1218)
        
        print("SECOND read")
        let value2 = try await read.readConcurrent(range: [0..<257, 511..<513])
        XCTAssertEqual(value2[123], 1218)
    }
    
    /*func testRemoteFileManager() async throws {
        let value = try await RemoteOmFileManager.instance.with(file: .staticFile(domain: .dwd_icon_d2_eps, variable: "HSURF", chunk: nil), client: .shared, logger: .init(label: "")) { reader in
            try await reader.asArray(of: Float.self)!.read(range: [250..<251, 420..<421])
        }
        XCTAssertEqual(value?.first, 214)
    }*/
    
    func testKeyValueCache() async throws {
        let data = DataAsClass(data: Data(repeating: 0, count: (64 + 16)*50))
        let cache = AtomicBlockCache(data: data, blockSize: 64)
        cache.set(key: 234923, value: Data(repeating: 123, count: 64))
        cache.set(key: 234923+50, value: Data(repeating: 142, count: 64))
        XCTAssertEqual(cache.get(key: 234923)!.data, Data(repeating: 123, count: 64))
        XCTAssertEqual(cache.get(key: 234923+50)!.data, Data(repeating: 142, count: 64))
        XCTAssertEqual(cache.blockCount, 50)
        
        for i in 0..<50 {
            cache.set(key: UInt64(1000+i), value: Data(repeating: UInt8(123+i), count: 64))
        }
        for i in 0..<50 {
            XCTAssertEqual(cache.get(key: UInt64(1000+i))!.data, Data(repeating: UInt8(123+i), count: 64))
        }
        // Cache got overwritten
        XCTAssertNil(cache.get(key: 234923))
        XCTAssertNil(cache.get(key: 234923+50))
        
        // First 23 keys are sequentially in cache
        XCTAssertNotNil(cache.get(key: 1000, count: 23))
        XCTAssertNil(cache.get(key: 1022, count: 2))
        // Key 1023 is offset by 2 slots
        XCTAssertNotNil(cache.get(key: 1023, count: 25))
        // Keys 1048 until 1050 are sequentially in cache again, but offset by 2 and wraps at the end of the cache
        XCTAssertNotNil(cache.get(key: 1048, count: 2))
        
        cache.set(key: .max, value: Data(repeating: 123, count: 64))
        XCTAssertEqual(cache.get(key: .max)!.data, Data(repeating: 123, count: 64))
    }
}
