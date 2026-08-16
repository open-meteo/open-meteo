import OmFileFormat
import Foundation
import Vapor

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
    
    init(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws {
        let buffer = try await file.getData(offset: 0, count: file.count)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(Self.self, from: buffer)
    }
    
    func remoteUpdated(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> Self {
        return try await Self(file: file)
    }
    
    func remoteDeleted() async throws {
        return
    }
}
