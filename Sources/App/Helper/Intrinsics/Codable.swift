import Foundation

extension Data {
    func decodeJson<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: self)
    }
    
    func writeAtomic(path: String) throws {
        let fn = try FileHandle.createNewFile(file: path, size: self.count, overwrite: true, temporary: true)
        try fn.write(contentsOf: self)
        try fn.linkTemporary(file: path)
        try fn.close()
    }
}

extension Encodable {
    func jsonEncodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// Write to as an atomic operation
    func writeTo(path: String) throws {
        try jsonEncodedData().writeAtomic(path: path)
    }
}

extension Decodable {
    static func readFrom(path: String) throws -> Self {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try data.decodeJson(as: Self.self)
    }
}
