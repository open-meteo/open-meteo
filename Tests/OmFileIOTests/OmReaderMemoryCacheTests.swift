import Foundation
import NIOCore
import OmFileFormat
@testable import OmFileIO
import Testing

@Suite struct OmReaderMemoryCacheTests {
    @Test func cachesTailAndCoalescesMissingBlocks() async throws {
        let backend = RecordingBackend()
        let cache = OmReaderMemoryCache(backend: backend)
        #expect(try await cache.getData(offset: 19_980, count: 20) == ByteBuffer(bytes: backend.data.subdata(in: 19_980..<20_000)))
        #expect(try await cache.withData(offset: 19_000, count: 100) { Data($0) } == backend.data.subdata(in: 19_000..<19_100))
        #expect(await backend.requests == [16_384..<20_000])
        try await cache.prefetchData(offset: 4090, count: 20)
        #expect(await backend.requests == [16_384..<20_000, 0..<8192])
        #expect(try await cache.getData(offset: 4090, count: 20) == ByteBuffer(bytes: backend.data.subdata(in: 4090..<4110)))
        #expect(try await cache.getData(offset: 20_000, count: 0).readableBytes == 0)
        #expect(await backend.requests.count == 2)
    }

    @Test func largeReadsUseFullyCachedRanges() async throws {
        let backend = RecordingBackend()
        let cache = OmReaderMemoryCache(backend: backend)
        for offset in stride(from: 0, to: backend.count, by: 4096) {
            try await cache.prefetchData(offset: offset, count: 1)
        }
        let requests = await backend.requests
        #expect(try await cache.getData(offset: 4000, count: 16_000) == ByteBuffer(bytes: backend.data.subdata(in: 4000..<20_000)))
        #expect(await backend.requests == requests)
    }

    @Test(arguments: [[], [0], [4], [0, 2, 4]])
    func fetchesOneRangeBetweenMissingBlocks(cachedBlocks: [Int]) async throws {
        let backend = RecordingBackend()
        let cache = OmReaderMemoryCache(backend: backend)
        for block in cachedBlocks {
            try await cache.prefetchData(offset: block * 4096, count: 1)
        }
        let initialRequests = await backend.requests
        let firstMissing = try #require((0..<5).first { !cachedBlocks.contains($0) })
        let lastMissing = try #require((0..<5).last { !cachedBlocks.contains($0) })
        let expectedRange = firstMissing * 4096..<min((lastMissing + 1) * 4096, backend.count)
        #expect(try await cache.getData(offset: 4000, count: 16_000) == ByteBuffer(bytes: backend.data.subdata(in: 4000..<20_000)))
        #expect(await backend.requests == initialRequests + [expectedRange])
        // Every fetched block is now reusable, including the rounded prefix and partial EOF block.
        #expect(try await cache.getData(offset: 0, count: backend.count) == ByteBuffer(bytes: backend.data))
        #expect(await backend.requests == initialRequests + [expectedRange])
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
        await #expect(throws: OmReaderMemoryCache<RecordingBackend>.ReadError.shortRead) {
            _ = try await cache.getData(offset: 100, count: 4097)
        }
        #expect(await backend.requests.last == 0..<8192)
    }

    private actor RecordingBackend: OmFileReaderBackend {
        nonisolated let data: Data
        nonisolated var count: Int { data.count }
        let shortRead: Bool
        var requests = [Range<Int>]()

        init(shortRead: Bool = false, size: Int = 20_000) {
            self.shortRead = shortRead
            self.data = Data((0..<size).map { UInt8($0 % 251) })
        }

        func getData(offset: Int, count: Int) async throws -> ByteBuffer {
            requests.append(offset..<offset + count)
            // Exercise slices whose readable bytes do not start at index zero.
            var buffer = ByteBuffer(bytes: [UInt8](repeating: 0, count: 7))
            buffer.writeBytes(data.subdata(in: offset..<offset + count - (shortRead ? 1 : 0)))
            buffer.moveReaderIndex(forwardBy: 7)
            return buffer
        }

        nonisolated func withData<T>(offset: Int, count: Int, fn: @Sendable (UnsafeRawBufferPointer) throws -> T) async throws -> T {
            try await getData(offset: offset, count: count).withUnsafeReadableBytes(fn)
        }

        func prefetchData(offset: Int, count: Int) async throws {}
    }
}
