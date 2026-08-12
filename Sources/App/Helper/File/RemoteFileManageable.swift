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

    //func revalidateEverySeconds(modificationTime: Timestamp?, now: Timestamp) -> Int
    func getFilePath() -> String
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
