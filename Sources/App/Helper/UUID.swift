import Foundation

extension UUID {
    var bytes: [UInt8] {
        withUnsafeBytes(of: uuid) { Array($0) }
    }

    /// Lowercase hexadecimal representation without hyphens, as used by GRIB.
    var hexString: String {
        uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}
