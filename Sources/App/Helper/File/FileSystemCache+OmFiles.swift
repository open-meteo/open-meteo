import OmFileFormat
import Foundation
import AsyncHTTPClient
import Logging


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


// TODO implement JSON files parsing as well

extension OmFileLocalRemoteOmReader: FileSystemPayload {
    init(fd: FileHandle, size: Int64) async throws {
        // TODO because the size is known already, this should be passed to MmapFile.init
        let file = try MmapFile(fn: fd)
        let readerRaw = try await OmFileReader(fn: file)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
    
    init(client: HTTPClient, logger: Logger, server: String, objectKey: String, size: Int64, lastModified: Timestamp) async throws {
        let backend = OmHttpReaderBackend(client: client, logger: logger, url: "\(server)\(objectKey)", count: Int(size), lastModified: lastModified, eTag: nil, lastValidated: .now())
        
        let file = OmReaderBlockCache<OmHttpReaderBackend, MmapFile>(backend: backend, cache: OpenMeteo.dataBlockCache, cacheKey: backend.cacheKey)
        try await self.init(remoteFile: file)
    }
    
    func remoteUpdated(client: HTTPClient, logger: Logger, server: String, objectKey: String, size: Int64, lastModified: Timestamp) async throws -> OmFileLocalRemoteOmReader {
        // Mark the old file as deleted/modified.
        // Cached queries still work, but new queries will immediately throw an error without unnecessarily doing HTTP requests.
        guard let reader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("remoteUpdated cannot be called on a non-OmFileRemoteOmReader")
        }
        let fn = reader.fn
        
        let logger = reader.fn.backend.logger
        let activeBlocks = reader.fn.listOfActiveBlocks(maxAgeSeconds: 15*60)
        
        let newBackend = OmHttpReaderBackend(client: client, logger: logger, url: "\(server)\(objectKey)", count: Int(size), lastModified: lastModified, eTag: nil, lastValidated: .now())
        let newBackendCached = OmReaderBlockCache<OmHttpReaderBackend, MmapFile>(backend: newBackend, cache: OpenMeteo.dataBlockCache, cacheKey: newBackend.cacheKey)
        
        try await newBackendCached.preloadBlocks(blocks: activeBlocks)
        let deletedBlocks = fn.deleteCachedBlocks(olderThanSeconds: 60)
        logger.warning("OmFileRemoteOmReader: Updated file. \(deletedBlocks) previously cached blocks have been deleted. \(activeBlocks.count) active blocks preloaded")
        return try await OmFileLocalRemoteOmReader(remoteFile: newBackendCached)
    }
    
    func remoteDeleted() async throws {
        guard let reader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("remoteDeleted cannot be called on a non-OmFileRemoteOmReader")
        }
        let logger = reader.fn.backend.logger
        let deletedBlocks = reader.fn.deleteCachedBlocks(olderThanSeconds: 60)
        logger.warning("OmFileRemoteOmReader: File deleted from server. \(deletedBlocks) previously cached blocks have been deleted.")
    }
}
