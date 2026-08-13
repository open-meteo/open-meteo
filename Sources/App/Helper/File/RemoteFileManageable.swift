import OmFileFormat
import Foundation
import Vapor

/// Represents a "File" that could be read from local or remote
/*protocol RemoteFileManageable: Sendable, Hashable {
    associatedtype Value: Sendable
    associatedtype Local: LocalFileRepresentable<Value>
    associatedtype Remote: RemoteFileRepresentable<Value>
    
    func makeRemoteReader(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> Remote
    func makeLocalReader(file: MmapFile) async throws -> Local
    func revalidateEverySeconds(modificationTime: Timestamp?, now: Timestamp) -> Int
    func getFilePath() -> String
    func getRemoteUrl() -> String?
}

/// An intermediate **remote** file representation that can be cast to a final value
protocol RemoteFileRepresentable<Value>: Sendable {
    associatedtype Value
    var fn: OmReaderBlockCache<OmHttpReaderBackend, MmapFile> { get }
    func cast() -> Value
}

/// An intermediate **local** file representation that can be cast to a final value
protocol LocalFileRepresentable<Value>: Sendable {
    associatedtype Value
    var fn: MmapFile { get }
    func cast() -> Value
}*/


protocol RemoteFileManageable2 {
    associatedtype Payload: FileSystemPayload
    
    /// Get the relative file prefixed with `data/` or `data_spatial` like `data/dwd_icon/temperature_2m/chunk_1234.om`
    func getRelativeFilePathWithData() -> String
}

extension RemoteFileManageable2 {
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

protocol FileSystemPayloadCodable: FileSystemPayload, Codable {
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
