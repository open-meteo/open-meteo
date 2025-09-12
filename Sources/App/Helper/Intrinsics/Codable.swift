import Foundation

extension Data {
    func decodeJson<T: Decodable>(as type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: self)
    }
}

extension Encodable {
    /// Write to as an atomic operation
    func writeTo(path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        
        let fileTemp = "\(path)~"
        let fn = try FileHandle.createNewFile(file: fileTemp, size: data.count, overwrite: true)
        try fn.write(contentsOf: data)
        try fn.close()
        try FileManager.default.moveFileOverwrite(from: fileTemp, to: path)
    }
}

extension Decodable {
    static func readFrom(path: String) throws -> Self {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try data.decodeJson(as: Self.self)
    }
}
