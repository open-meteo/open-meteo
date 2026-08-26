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

extension OmFileLocalRemoteOmReader: OmFilePayload {
    init(fd: FileHandle, size: Int64) async throws {
        // TODO because the size is known already, this should be passed to MmapFile.init
        let file = try MmapFile(fn: fd)
        let readerRaw = try await OmFileReader(fn: file)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
    }
    
    init(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws {
        try await self.init(remoteFile: file)
    }
    
    func remoteUpdated(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> OmFileLocalRemoteOmReader {
        // Mark the old file as deleted/modified.
        // Cached queries still work, but new queries will immediately throw an error without unnecessarily doing HTTP requests.
        guard let reader = self.reader as? OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float> else {
            fatalError("remoteUpdated cannot be called on a non-OmFileRemoteOmReader")
        }
        
        let logger = reader.fn.backend.server.logger
        let activeBlocks = reader.fn.listOfActiveBlocks(maxAgeSeconds: 15*60)
        
        try await file.preloadBlocks(blocks: activeBlocks)
        let deletedBlocks = reader.fn.deleteCachedBlocks(olderThanSeconds: 60)
        logger.warning("OmFileRemoteOmReader: Blocks freed=\(deletedBlocks) preloaded=\(activeBlocks.count). Updated file \(file.backend.object). ")
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
