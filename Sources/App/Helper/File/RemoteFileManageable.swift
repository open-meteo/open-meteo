import OmFileFormat
import Foundation
import Vapor


protocol RemoteFileManageable {
    associatedtype Payload: RemoteFileManagablePayload
    
    /// Get the relative file prefixed with `data/` or `data_spatial` like `data/dwd_icon/temperature_2m/chunk_1234.om`
    func getRelativeFilePathWithData() -> String
}

protocol RemoteFileManagablePayload: RemotePayload, LocalPayload {
    
}

protocol RemotePayload: Sendable {
    /// Initialise from remote source
    init(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws
    func remoteUpdated(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> Self
    func remoteDeleted() async throws
}

protocol LocalPayload: Sendable {
    /// Payload can retain a reference to FileHandle to ensure the file stays open
    init(fd: FileHandle, size: Int64) async throws
}


extension RemoteFileManageable {
    /// Get the absolute file system path like `/var/lib/openmeteo-`
    func getFilePath() -> String {
        let path = getRelativeFilePathWithData()
        if path.starts(with: "data/") {
            return path.replacingOccurrences(of: "data/", with: OpenMeteo.dataDirectory)
        }
        if path.starts(with: "data_run/") {
            return path.replacingOccurrences(of: "data_run/", with: OpenMeteo.dataRunDirectory ?? OpenMeteo.dataDirectory)
        }
        if path.starts(with: "data_spatial/") {
            return path.replacingOccurrences(of: "data_spatial/", with: OpenMeteo.dataSpatialDirectory ?? OpenMeteo.dataDirectory)
        }
        fatalError("Unexpected data path \(path)")
    }
    
    func createDirectory() throws {
        let file = getFilePath()
        guard let last = file.lastIndex(of: "/") else {
            return
        }
        let path = "\(file[file.startIndex..<last])"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    
    func exists() -> Bool {
        let file = getFilePath()
        return FileManager.default.fileExists(atPath: file)
    }
}

protocol FileSystemPayloadCodable: RemoteFileManagablePayload, Codable {
}

enum FileSystemError: Error {
    case readFailed
}

extension FileSystemPayloadCodable {
    init(fd: FileHandle, size: Int64) async throws {
        guard let data = try fd.readToEnd() else {
            throw FileSystemError.readFailed
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
