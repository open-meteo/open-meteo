import Foundation
import Testing
import OmFileFormat
@testable import App
@testable import OmFileIO

struct RemotePayloadRetirementTests {
    @Test func failedPreloadStillRetiresOldBlocks() async throws {
        let fixture = try await makeElevationFile([1, 2, 3, 4])
        defer { fixture.remove() }
        let bytes = try Data(contentsOf: URL(fileURLWithPath: fixture.path))
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        let cache = AtomicCacheCoordinator(cache: try AtomicBlockCache(file: path, blockSize: 4096, blockCount: 16))
        let context = S3ServerHealth(logger: .init(label: "test"), servers: [], checksHealth: false)
        let oldKey = cache.calculateCacheKey(fileKey: 123, block: 0)

        // Keep reader references in this scope so returning exercises their actual deinitializers.
        func replace() async throws {
            let oldBackend = OmHttpReaderBackend(context: context, object: "test.om", count: bytes.count, eTag: "\"old\"", lastModified: .init(0))
            let newBackend = OmHttpReaderBackend(context: context, object: "test.om", count: bytes.count, eTag: "\"new\"", lastModified: .init(1))
            let oldReader = OmReaderBlockCache(backend: oldBackend, cache: cache, cacheKey: 123)
            let newReader = OmReaderBlockCache(backend: newBackend, cache: cache, cacheKey: 456)
            // Metadata construction reads only cached bytes; no network is involved.
            bytes.withUnsafeBytes {
                _ = cache.cache.set(key: oldKey, value: $0)
                _ = cache.cache.set(key: cache.calculateCacheKey(fileKey: 456, block: 0), value: $0)
            }
            let old = try await OmFileLocalRemoteOmReader(remoteFile: oldReader)
            let new = try await OmFileLocalRemoteOmReader(remoteFile: newReader)
            #expect(newReader.deleteCachedBlocks(olderThanSeconds: 0) == 1)
            newBackend.markModified()
            do {
                try await new.prefetchBackground(from: old)
                Issue.record("Expected preloading the modified replacement to fail")
            } catch CurlErrorNonRetry.fileModifiedOrPrevalidationFailed {}
            // Failure marks retirement but must not remove blocks from a still-live reader.
            #expect(oldReader.countCachedBlocks() == 1)
        }
        try await replace()
        #expect(!cache.cache.contains(key: oldKey))
    }
}
