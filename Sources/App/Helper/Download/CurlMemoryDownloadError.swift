import OmFileIO

/// These failures cannot be fixed by retrying the same range request.
enum CurlMemoryDownloadError: NonRetryError {
    case exceedsSizeLimit
    case invalidRangeResponse

    static func validateSize(current: Int, additional: Int, limit: Int?) throws {
        if let limit, additional < 0 || current > limit || additional > limit - current {
            throw Self.exceedsSizeLimit
        }
    }

    static func validateRange(status: Int, contentRange: String?, expected: Range<Int>) throws {
        guard status == 206, let contentRange else { throw Self.invalidRangeResponse }
        let parts = contentRange.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == "bytes \(expected.lowerBound)-\(expected.upperBound - 1)",
              parts[1] == "*" || Int(parts[1]).map({ $0 >= expected.upperBound }) == true else {
            throw Self.invalidRangeResponse
        }
    }
}
