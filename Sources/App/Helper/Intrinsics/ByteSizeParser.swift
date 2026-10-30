enum ByteSizeParser {
    static func parseSizeStringToBytes(_ str: String) throws -> Int {
        let multiplier: Double
        if str.hasSuffix("KB") {
            multiplier = 1024
        } else if str.hasSuffix("MB") {
            multiplier = 1024 * 1024
        } else if str.hasSuffix("GB") {
            multiplier = 1024 * 1024 * 1024
        } else if str.hasSuffix("TB") {
            multiplier = 1024 * 1024 * 1024 * 1024
        } else {
            throw ByteSizeParserError.numberConversionFailed(str)
        }
        guard let number = Double(str.dropLast(2)) else {
            throw ByteSizeParserError.numberConversionFailed(str)
        }
        let bytes = number * multiplier
        guard bytes.isFinite, bytes >= Double(Int.min), bytes < Double(Int.max) else {
            throw ByteSizeParserError.numberConversionFailed(str)
        }
        return Int(bytes)
    }
}

enum ByteSizeParserError: Error {
    case numberConversionFailed(String)
}
