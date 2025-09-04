import OmFileFormat
import Foundation

/// A simplified interface to cache JSON files
protocol RemoteFileManageableJson: RemoteFileManageable where Value: Decodable { }

extension RemoteFileManageableJson {
    func makeLocalReader(file: MmapFile) async throws -> LocalFileRepresentableSimple<Value> {
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: file.data.baseAddress!), count: file.count, deallocator: .none)
        guard let json = try? JSONDecoder().decode(Value.self, from: data) else {
            throw ForecastApiError.generic(message: "could not cast file to \(Value.self)")
        }
        return LocalFileRepresentableSimple(fn: file, value: json)
    }
    
    func makeRemoteReader(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> RemoteFileRepresentableSimple<Value> {
        let buffer = try await file.getData(offset: 0, count: file.count)
        guard let json = try? JSONDecoder().decode(Value.self, from: buffer) else {
            throw ForecastApiError.generic(message: "could not cast file to \(Value.self)")
        }
        return RemoteFileRepresentableSimple(fn: file, value: json)
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
