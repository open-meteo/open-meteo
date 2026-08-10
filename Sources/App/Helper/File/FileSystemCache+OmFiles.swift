import OmFileFormat
import Foundation
import AsyncHTTPClient
import Logging

extension OmFileLocalOmReader: FileSystemCache.FilePayload {
    init(fd: FileHandle, size: Int64) async throws {
        // TODO because the size is known already, this should be passed to MmapFile.init
        let file = try MmapFile(fn: fd)
        let readerRaw = try await OmFileReader(fn: file)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
}


// TODO implement JSON files parsing as well


extension OmFileRemoteOmReader: RemoteFilePayload {
    init(client: HTTPClient, logger: Logger, server: String, objectKey: String, size: Int64, lastModified: Timestamp) async throws {
        let backend = OmHttpReaderBackend(client: client, logger: logger, url: "\(server)\(objectKey)", count: Int(size), lastModified: lastModified, eTag: nil, lastValidated: .now())
        
        let file = OmReaderBlockCache<OmHttpReaderBackend, MmapFile>(backend: backend, cache: OpenMeteo.dataBlockCache, cacheKey: backend.cacheKey)
        let readerRaw = try await OmFileReader(fn: file)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
    
    func remoteUpdated(new: Self) async throws {
        let logger = reader.fn.backend.logger
        let activeBlocks = fn.listOfActiveBlocks(maxAgeSeconds: 15*60)
        try await new.fn.preloadBlocks(blocks: activeBlocks)
        let deletedBlocks = fn.deleteCachedBlocks(olderThanSeconds: 60)
        logger.warning("OmFileRemoteOmReader: Updated file. \(deletedBlocks) previously cached blocks have been deleted. \(activeBlocks.count) active blocks preloaded")
    }
    
    func remoteDeleted() async throws {
        let logger = reader.fn.backend.logger
        let deletedBlocks = fn.deleteCachedBlocks(olderThanSeconds: 60)
        logger.warning("OmFileRemoteOmReader: File deleted from server. \(deletedBlocks) previously cached blocks have been deleted.")
    }
}
