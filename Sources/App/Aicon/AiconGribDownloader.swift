import Foundation

struct AiconGribDownloader: Sendable {
    let domain: AiconDomain
    let curl: Curl

    func download(url: String, run: Timestamp, forecastHours: Int) async throws -> Array2D {
        let messages = try await curl.downloadGrib(url: url, bzip2Decode: false)
        guard messages.count == 1, let message = messages.first else {
            throw IconDownloadError(description: "Expected one AICON field at \(url)")
        }
        guard message.getLong(attribute: "dataDate") == Int(run.format_YYYYMMddHH.prefix(8)),
              message.getLong(attribute: "dataTime") == run.hour * 100,
              try message.getValidTimestamp() == run.add(hours: forecastHours) else {
            throw IconDownloadError(description: "AICON run or valid time mismatch at \(url)")
        }
        return try IconNativeGribDecoder.decode(message: message, identity: domain.nativeGridDefinition.nativeGridFile.identity)
    }
}
