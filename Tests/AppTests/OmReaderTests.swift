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
        let file = "cache64k50.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try MmapBlockCache(file: file, blockSize: 65536, blockCount: 50)
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: cache, cacheKey: readFn.cacheKey)
        let read = try! await OmFileReaderAsync(fn: cacheFn).asArray(of: Float.self)!
        let value = try await read.read(range: [250..<251, 420..<421])
        XCTAssertEqual(value.first, 214)
        
        let value2 = try await read.read(range: [250..<251, 420..<421])
        XCTAssertEqual(value2.first, 214)
    }
    
    func testBlockCacheConcurrent() async throws {
        let url = "https://openmeteo.s3.amazonaws.com/data/dwd_icon_d2_eps/static/HSURF.om"
        let readFn = try await OmHttpReaderBackend(client: .shared, logger: .init(label: "logger"), url: url)
        let file = "cache64k50_2.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try MmapBlockCache(file: file, blockSize: 65536, blockCount: 50)
        let cacheFn = OmReaderBlockCache(backend: readFn, cache: cache, cacheKey: readFn.cacheKey)
        let read = try await OmFileReaderAsync(fn: cacheFn).asArray(of: Float.self, io_size_max: 4096)!
        let value = try await read.readConcurrent(range: [0..<257, 511..<513])
        XCTAssertEqual(value[123], 1218)
    }
    
    func testKeyValueCache() async throws {
        let file = "cache.bin"
        try FileManager.default.removeItemIfExists(at: file)
        defer { try! FileManager.default.removeItem(atPath: file) }
        let cache = try MmapBlockCache(file: file, blockSize: 64, blockCount: 50)
        cache.set(key: 234923, value: Data(repeating: 123, count: 64))
        cache.set(key: 234923+50, value: Data(repeating: 142, count: 64))
        XCTAssertEqual(cache.get(key: 234923), Data(repeating: 123, count: 64))
        XCTAssertEqual(cache.get(key: 234923+50), Data(repeating: 142, count: 64))
        
        for i in 0..<50 {
            cache.set(key: UInt64(1000+i), value: Data(repeating: UInt8(123+i), count: 64))
        }
        for i in 0..<50 {
            XCTAssertEqual(cache.get(key: UInt64(1000+i)), Data(repeating: UInt8(123+i), count: 64))
        }
        // Cache got overwritten
        XCTAssertNil(cache.get(key: 234923))
        XCTAssertNil(cache.get(key: 234923+50))
    }
}
