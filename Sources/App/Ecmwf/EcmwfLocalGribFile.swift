import Foundation
import OmFileFormat
import OmFileIO
@preconcurrency import SwiftEccodes

/// Scan headers once, retaining only byte ranges and submessage numbers. Grids
/// are decoded on demand while the mapping keeps their compressed bytes alive.
final class EcmwfLocalGribFile: Sendable {
    struct Field: Sendable {
        let range: Range<Int>
        let submessage: Int
        let shortName: String
        let level: Int
        let typeOfLevel: String
        let member: Int
    }

    enum Failure: Error {
        case invalidMessage(path: String, offset: Int)
        case invalidMetadata
    }

    let mapping: MmapFile
    let fields: [Field]

    static func download(curl: Curl, url: String, path: String, concurrent: Int) async throws {
        if FileManager.default.fileExists(atPath: path) {
            curl.logger.info("Using cached GRIB \(path)")
            return
        }
        // Curl publishes the final path atomically only after a successful transfer.
        try await curl.download(url: url, toFile: path, bzip2Decode: false, cacheDirectory: nil, nConcurrent: concurrent, deadLineHours: 5.5)
    }

    init(path: String) throws {
        let mapping = try MmapFile(fn: FileHandle.openFileReading(file: path))
        var fields = [Field]()
        var offset = 0
        while offset < mapping.count {
            try Task.checkCancellation()
            let remaining = try mapping.getData(offset: offset, count: mapping.count - offset)
            guard let header = try GribAsyncStreamHelper.seekGrib(memory: remaining), header.offset == 0,
                  header.length >= 20, header.length <= remaining.count else {
                throw Failure.invalidMessage(path: path, offset: offset)
            }
            let range = offset..<offset + header.length
            let bytes = try mapping.getData(offset: range.lowerBound, count: range.count)
            guard bytes.suffix(4).elementsEqual([55, 55, 55, 55]) else {
                throw Failure.invalidMessage(path: path, offset: offset)
            }
            let messages = try GribAsyncStreamHelper.decodeMessages(memory: bytes)
            guard !messages.isEmpty else { throw Failure.invalidMessage(path: path, offset: offset) }
            for (submessage, message) in messages.enumerated() {
                guard let shortName = message.get(attribute: "shortName"),
                      let level = message.getLong(attribute: "level"),
                      let typeOfLevel = message.get(attribute: "typeOfLevel") else {
                    throw Failure.invalidMessage(path: path, offset: offset)
                }
                fields.append(Field(range: range, submessage: submessage, shortName: shortName, level: level,
                                    typeOfLevel: typeOfLevel, member: message.getLong(attribute: "perturbationNumber") ?? 0))
            }
            offset = range.upperBound
        }
        self.mapping = mapping
        self.fields = fields
    }

    func withMessage<T>(field: Field, body: (GribMessage) throws -> T) throws -> T {
        try withExtendedLifetime(mapping) {
            let bytes = try mapping.getData(offset: field.range.lowerBound, count: field.range.count)
            let messages = try GribAsyncStreamHelper.decodeMessages(memory: bytes)
            return try body(messages[field.submessage])
        }
    }
}
