import Foundation
import OmFileFormat
@testable import OmFileIO
import Testing

@Suite struct OmReaderMemoryCacheTests {
    @Test func cachesTailAndCoalescesMissingBlocks() async throws {
        let backend = RecordingBackend()
        let cache = OmReaderMemoryCache(backend: backend)
        #expect(try await cache.getData(offset: 19_980, count: 20) == backend.data.subdata(in: 19_980..<20_000))
        #expect(try await cache.withData(offset: 19_000, count: 100) { Data($0) } == backend.data.subdata(in: 19_000..<19_100))
        #expect(await backend.requests == [16_384..<20_000])
        // A large lookup table needs one additional contiguous read, reusing the cached tail.
        #expect(try await cache.getData(offset: 4000, count: 16_000) == backend.data.subdata(in: 4000..<20_000))
        #expect(await backend.requests == [16_384..<20_000, 0..<16_384])
        try await cache.prefetchData(offset: 4090, count: 20)
        #expect(try await cache.getData(offset: 4090, count: 20) == backend.data.subdata(in: 4090..<4110))
        #expect(try await cache.getData(offset: 20_000, count: 0).isEmpty)
        #expect(await backend.requests.count == 2)
    }

    @Test func rejectsInvalidAndShortReads() async throws {
        let backend = RecordingBackend(shortRead: true)
        let cache = OmReaderMemoryCache(backend: backend)
        for (offset, count) in [(-1, 1), (0, -1), (20_001, 0), (19_999, Int.max)] {
            await #expect(throws: OmReaderMemoryCache<RecordingBackend>.ReadError.self) {
                _ = try await cache.getData(offset: offset, count: count)
            }
        }
        #expect(await backend.requests.isEmpty)
        for _ in 0..<2 {
            await #expect(throws: OmReaderMemoryCache<RecordingBackend>.ReadError.shortRead) {
                _ = try await cache.getData(offset: 10, count: 10)
            }
        }
        // A failed fetch must not populate the cache.
        #expect(await backend.requests == [0..<4096, 0..<4096])
    }

    private actor RecordingBackend: OmFileReaderBackend {
        nonisolated let data = Data((0..<20_000).map { UInt8($0 % 251) })
        nonisolated var count: Int { data.count }
        let shortRead: Bool
        var requests = [Range<Int>]()

        init(shortRead: Bool = false) { self.shortRead = shortRead }

        func getData(offset: Int, count: Int) async throws -> Data {
            requests.append(offset..<offset + count)
            return data.subdata(in: offset..<offset + count - (shortRead ? 1 : 0))
        }

        nonisolated func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
            try await getData(offset: offset, count: count).withUnsafeBytes(fn)
        }

        func prefetchData(offset: Int, count: Int) async throws {}
    }
}
