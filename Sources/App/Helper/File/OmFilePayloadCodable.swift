import OmFileFormat
import Foundation
import Vapor
import OmFileIO

protocol OmFilePayloadCodable: OmFilePayload, Codable {
    
}

enum OmFilePayloadCodableError: Error {
    case readFailed
}

extension OmFilePayloadCodable {
    init(fd: FileHandle, size: Int64) async throws {
        guard let data = try fd.readToEnd() else {
            throw OmFilePayloadCodableError.readFailed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(Self.self, from: data)
    }
    
    init(file: OmHttpReaderBackend) async throws {
        let file = OmReaderBlockCache(backend: file, cache: OpenMeteo.dataBlockCache, cacheKey: file.cacheKey)
        let buffer = try await file.getData(offset: 0, count: file.count)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(Self.self, from: buffer)
    }
    
    // This payload is already fully loaded locally.
    func cachedOnly() async throws -> Self { self }

    func updateMetaData(file: OmHttpReaderBackend) async throws -> Self {
        return try await Self(file: file)
    }

    // Decoding already reads the entire payload, so there is no data left to prefetch.
    func prefetchBackground(from previous: any OmRemotePayload) async throws {}
    
    func remoteDeleted() async throws {
        return
    }
}
