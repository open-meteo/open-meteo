import OmFileFormat
import Foundation
import AsyncHTTPClient
import Logging
import OmFileIO

struct OmFileLocalRemoteOmReader {
    let reader: any OmFileReaderArrayProtocol<Float>
    let timestamps: [Timestamp]?
    let timeRangeDt: TimerangeDt?
    
    init(remoteFile: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws {
        let readerRaw = try await OmFileReader(fn: remoteFile)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
}

extension OmFileLocalRemoteOmReader: OmFilePayload {
    init(fd: FileHandle, size: Int64) async throws {
        // TODO because the size is known already, this should be passed to MmapFile.init
        let file = try MmapFile(fn: fd)
        let readerRaw = try await OmFileReader(fn: file)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
    
    init(file: OmHttpReaderBackend) async throws {
        let file = OmReaderBlockCache(backend: file, cache: OpenMeteo.dataBlockCache, cacheKey: file.cacheKey)
        try await self.init(remoteFile: file)
    }
    
    func remoteUpdated(file: OmHttpReaderBackend) async throws -> OmFileLocalRemoteOmReader {
        let file = OmReaderBlockCache(backend: file, cache: OpenMeteo.dataBlockCache, cacheKey: file.cacheKey)
        // Mark the old file as deleted/modified.
        // Cached queries still work, but new queries will immediately throw an error without unnecessarily doing HTTP requests.
        guard let reader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("remoteUpdated cannot be called on a non-OmFileRemoteOmReader")
        }
        
        let logger = reader.fn.backend.server.logger
        let activeBlocks = reader.fn.listOfActiveBlocks(maxAgeSeconds: 15*60)
        
        /// TODO: Consider that the new file might be significantly bigger and the block placement is not correct anymore. It could be possible to map the actual used array data ranges from old block addresses to new ones.
        try await file.preloadBlocks(blocks: activeBlocks)
        let deletedBlocks = reader.fn.deleteCachedBlocks(olderThanSeconds: 60)
        logger.warning("OmFileRemoteOmReader: Blocks freed=\(deletedBlocks) preloaded=\(activeBlocks.count). Updated file \(file.backend.object) (old size=\(reader.fn.count) new size=\(file.count)). ")
        return try await OmFileLocalRemoteOmReader(remoteFile: file)
    }
    
    func remoteDeleted() async throws {
        guard let reader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("remoteDeleted cannot be called on a non-OmFileRemoteOmReader")
        }
        let logger = reader.fn.backend.server.logger
        let deletedBlocks = reader.fn.deleteCachedBlocks(olderThanSeconds: 60)
        logger.warning("OmFileRemoteOmReader: File deleted from server. \(deletedBlocks) previously cached blocks have been deleted.")
    }
}
