import Foundation
@preconcurrency import SwiftEccodes

struct IconDownloadError: Error, CustomStringConvertible {
    let description: String
}

struct IconGribDownloader: Sendable {
    let domain: IconDomains
    let curl: Curl
    let remapper: IconRemapper?

    func downloadAndRemap(field: (variable: String, cat: String, level: Int?), run: Timestamp, leadSeconds: Int, member: Int = 0) async throws -> (message: GribMessage, data: Array2D) {
        let url = domain.getGribUrl(field: field, run: run, leadSeconds: leadSeconds, member: member)
        let messages = try await curl.downloadGrib(url: url, bzip2Decode: false)
        guard messages.count == 1, let message = messages.first else {
            throw IconDownloadError(description: "Expected one ICON field at \(url)")
        }
        guard message.getLong(attribute: "dataDate") == Int(run.format_YYYYMMddHH.prefix(8)),
              message.getLong(attribute: "dataTime") == run.hour * 100,
              try message.getValidTimestamp() == run.add(leadSeconds),
              domain.countEnsembleMember == 1 || message.getLong(attribute: "perturbationNumber") == member + 1 else {
            throw IconDownloadError(description: "ICON run, valid time or member mismatch at \(url)")
        }
        let native = try IconNativeGribDecoder.decode(message: message, identity: domain.sourceGridIdentity)
        guard let remapper else { return (message, native) }
        return (message, Array2D(data: remapper.remap(native.data), nx: domain.grid.nx, ny: domain.grid.ny))
    }
}

struct IconStepInterval: Equatable {
    let start: Int
    let end: Int

    init(start: Int, end: Int, unit: Int) throws {
        let seconds: Int
        switch unit {
        case 0: seconds = 60
        case 1: seconds = 3600
        case 2: seconds = 86400
        case 10: seconds = 10800
        case 11: seconds = 21600
        case 12: seconds = 43200
        case 13: seconds = 1
        default: throw IconDownloadError(description: "Unsupported ICON step unit \(unit)")
        }
        guard start >= 0, end >= start else { throw IconDownloadError(description: "Invalid ICON step interval \(start)-\(end)") }
        self.start = start * seconds
        self.end = end * seconds
    }

    init(_ message: GribMessage) throws {
        guard let start = message.getLong(attribute: "startStep"), let end = message.getLong(attribute: "endStep"),
              let unit = message.getLong(attribute: "stepUnits") else {
            throw IconDownloadError(description: "Missing ICON step interval")
        }
        try self.init(start: start, end: end, unit: unit)
    }
}
