import OmFileFormat
import Foundation

/// Represents a "File" that could be read from local or remote
protocol RemoteFileManageable: Sendable, Hashable {
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
}

/// A simplified interface to simply cast `Data` into a value
protocol RemoteFileManageableSimple: RemoteFileManageable {
    func readFrom(data: Data) throws -> Value
}

extension RemoteFileManageableSimple {
    func makeLocalReader(file: MmapFile) async throws -> LocalFileRepresentableSimple<Value> {
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: file.data.baseAddress!), count: file.count, deallocator: .none)
        return LocalFileRepresentableSimple(fn: file, value: try readFrom(data: data))
    }
    
    func makeRemoteReader(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> RemoteFileRepresentableSimple<Value> {
        let value = try await file.withData(offset: 0, count: file.count) { buffer in
            try readFrom(data: buffer.data)
        }
        return RemoteFileRepresentableSimple(fn: file, value: value)
    }
}

struct RemoteFileRepresentableSimple<Value: Sendable>: RemoteFileRepresentable {
    let fn: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>
    let value: Value
    
    func cast() -> Value {
        return value
    }
}

struct LocalFileRepresentableSimple<Value: Sendable>: LocalFileRepresentable {
    let fn: MmapFile
    let value: Value
    
    func cast() -> Value {
        return value
    }
}
