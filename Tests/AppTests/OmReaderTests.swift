import Foundation
@testable import App
import XCTest
// import Vapor
import OmFileFormat

final class OmReaderTests: XCTestCase {
    func testHttpRead() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)
        let read = try await OmFileReaderAsync(fn: readFn).asArray(of: Float.self)!
        let value = try await read.read(range: [250..<251, 420..<421])
        XCTAssertEqual(value.first, 214)
    }
    
    func testBlockCache() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)
        let cache = SimpleKVCache()
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: cache, cacheKey: 234)
        let read = try await OmFileReaderAsync(fn: cacheFn).asArray(of: Float.self)!
        let value = try await read.read(range: [250..<251, 420..<421])
        XCTAssertEqual(value.first, 214)
    }
    
    func testBlockCacheConcurrent() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)
        let cache = SimpleKVCache()
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: cache, cacheKey: 234)
        let read = try await OmFileReaderAsync(fn: cacheFn).asArray(of: Float.self, io_size_max: 4096)!
        let value = try await read.readConcurrent(range: [0..<257, 511..<513])
        XCTAssertEqual(value[123], 1218)
    }
    
    func testKeyValueCache() async throws {
        let file = "cache.bin"
        let cache = try MmapBlockCache(file: file, blockSize: 64, blockCount: 50)
        cache.set(key: 234923, value: Data(repeating: 123, count: 8))
        XCTAssertEqual(cache.get(key: 234923), Data(repeating: 123, count: 8))
    }
}
