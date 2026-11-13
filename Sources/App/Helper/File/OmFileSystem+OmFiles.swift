import OmFileFormat
import Foundation
import AsyncHTTPClient
import Logging
import OmFileIO

struct OmFileLocalRemoteOmReader {
    let reader: any OmFileReaderArrayProtocol<Float>
    let timestamps: [Timestamp]?
    let timeRangeDt: TimerangeDt?
    
    init<Backend: OmFileReaderBackend>(remoteFile: Backend) async throws {
        let readerRaw = try await OmFileReader(fn: remoteFile)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
}

extension OmFileLocalRemoteOmReader: OmFilePayload {
    init(fd: FileHandle, size: Int64) async throws {
        // TODO because the size is known already, this should be passed to MmapFile.init
        let file = try MmapFile(fn: fd, advice: .random)
        let readerRaw = try await OmFileReader(fn: file)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
    
    init(file: OmHttpReaderBackend) async throws {
        let file = OmReaderBlockCache(backend: file, cache: OpenMeteo.dataBlockCache, cacheKey: file.cacheKey)
        try await self.init(remoteFile: file)
    }
    
    func cachedOnly() async throws -> Self {
        guard let reader = reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            return self
        }
        return try await Self(remoteFile: reader.fn.cachedOnly())
    }

    func updateMetaData(file: OmHttpReaderBackend) async throws -> OmFileLocalRemoteOmReader {
        guard let reader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("updateMetaData requires a remote OM reader")
        }
        // The inventory already identified a replacement. Cached blocks remain usable,
        // but cache misses must fail locally instead of sending requests with the old ETag.
        reader.fn.backend.markModified()
        return try await Self(file: file)
    }

    func prefetchBackground(from previous: any OmRemotePayload) async throws {
        guard let previous = previous as? Self,
              let reader = previous.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float>,
              let updatedReader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("prefetchBackground requires remote OM readers")
        }
        // Retire old blocks even if optional preloading is disabled or fails. Live readers and backend
        // jobs retain this reader, so deletion still waits for their final reference.
        reader.fn.deleteCachedBlocksOnDeinit()
        guard OpenMeteo.remoteDataPreloadMaxAgeSeconds > 0 else { return }

        let file = updatedReader.fn
        let logger = reader.fn.backend.server.logger
        let activeBlocks = reader.fn.listOfActiveBlocks(maxAgeSeconds: OpenMeteo.remoteDataPreloadMaxAgeSeconds, scaledToFileSize: file.count)
        // Relative block positions are an estimate when the replacement file's internal layout changes.
        let preloaded = try await file.preloadBlocks(blocks: activeBlocks, allowedWait: .seconds(OpenMeteo.remoteDataPreloadDeadlineSeconds))
        let blocksToFree = reader.fn.countCachedBlocks()
        logger.warning("OmFileRemoteOmReader: Blocks to free on deinit=\(blocksToFree) preloaded=\(preloaded ? activeBlocks.reduce(0) { $0 + $1.count } : 0) ranges=\(activeBlocks.count). Updated file \(file.backend.object) (old size=\(reader.fn.count) new size=\(file.count)). ")
    }
    
    func remoteDeleted() async throws {
        guard let reader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("remoteDeleted cannot be called on a non-OmFileRemoteOmReader")
        }
        let logger = reader.fn.backend.server.logger
        reader.fn.deleteCachedBlocksOnDeinit()
        let blocksToFree = reader.fn.countCachedBlocks()
        logger.warning("OmFileRemoteOmReader: File deleted from server. Blocks to free on deinit=\(blocksToFree). Cached blocks will be deleted when the last reader is released.")
    }
}
