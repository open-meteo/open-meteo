import OmFileFormat
import Foundation
import AsyncHTTPClient
import Logging
import OmFileIO

struct OmFileLocalRemoteOmReader {
    let reader: any OmFileReaderArrayProtocol<Float>
    let timestamps: [Timestamp]?
    let timeRangeDt: TimerangeDt?
    let forecastReferenceTime: Timestamp?
    /// Inclusive last valid timestamp of the forecast run, not necessarily this chunk.
    let forecastLastValidTime: Timestamp?
    
    /// Limit file coverage while retaining its origin for array offsets.
    func prefetchTimeRange(fileTime: Range<Int>, dtSeconds: Int) -> Range<Int> {
        guard let forecastLastValidTime else { return fileTime }
        let lastIndex = dtSeconds == .dtSecondsMonthly ? forecastLastValidTime.monthIntervalSince1970Average : forecastLastValidTime.timeIntervalSince1970 / dtSeconds
        let end = max(fileTime.lowerBound, min(fileTime.upperBound, lastIndex + 1))
        return fileTime.lowerBound..<end
    }

    init(remoteFile: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws {
        let readerRaw = try await OmFileReader(fn: remoteFile)
        self.reader = try readerRaw.expectArray(of: Float.self)
        self.timestamps = try await readerRaw.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init)
        self.timeRangeDt = try await readerRaw.getTimeRangeDt()
        let referenceTime: Int? = try await readerRaw.getChild(name: "forecast_reference_time")?.readScalar()
        let lastValidTime: Int? = try await readerRaw.getChild(name: "forecast_last_valid_time")?.readScalar()
        self.forecastReferenceTime = referenceTime.map(Timestamp.init)
        self.forecastLastValidTime = lastValidTime.map(Timestamp.init)
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
        let referenceTime: Int? = try await readerRaw.getChild(name: "forecast_reference_time")?.readScalar()
        let lastValidTime: Int? = try await readerRaw.getChild(name: "forecast_last_valid_time")?.readScalar()
        self.forecastReferenceTime = referenceTime.map(Timestamp.init)
        self.forecastLastValidTime = lastValidTime.map(Timestamp.init)
    }
    
    init(file: OmHttpReaderBackend) async throws {
        let file = OmReaderBlockCache(backend: file, cache: OpenMeteo.dataBlockCache, cacheKey: file.cacheKey)
        try await self.init(remoteFile: file)
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
        let file = updatedReader.fn
        let logger = reader.fn.backend.server.logger
        let activeBlocks = reader.fn.listOfActiveBlocks(maxAgeSeconds: OpenMeteo.remoteDataPreloadMaxAgeSeconds, scaledToFileSize: file.count)
        // Retire old blocks even if optional preloading fails. Live readers and backend
        // jobs retain this reader, so deletion still waits for their final reference.
        reader.fn.deleteCachedBlocksOnDeinit()
        
        // Relative block positions are an estimate when the replacement file's internal layout changes.
        let preloaded = try await file.preloadBlocks(blocks: activeBlocks)
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
