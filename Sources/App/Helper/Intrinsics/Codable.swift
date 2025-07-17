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
        let fn = try FileHandle.createNewFile(file: "\(path)~")
        try fn.write(contentsOf: try encoder.encode(self))
        try fn.close()
        try FileManager.default.moveFileOverwrite(from: "\(path)~", to: path)
    }
}

extension Decodable {
    static func readFrom(path: String) throws -> Self {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try data.decodeJson(as: Self.self)
    }
}
