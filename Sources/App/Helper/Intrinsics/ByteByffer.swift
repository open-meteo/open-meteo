import NIOCore

extension ByteBuffer {
    public func readJSONDecodable<T: Decodable>(_ type: T.Type) throws -> T? {
        var a = self
        return try a.readJSONDecodable(type, length: a.readableBytes)
    }
}
