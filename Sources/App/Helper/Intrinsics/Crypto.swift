import Foundation
import Crypto

extension Data {
    var sha256: String {
        SHA256.hash(data: self).hexEncodedString()
    }
}

extension String {
    var sha256: String {
        if let hash = withContiguousStorageIfAvailable({
            let ptr = UnsafeRawBufferPointer($0)
            return SHA256.hash(data: ptr).hex
        }) {
            return hash
        }
        let data = self.data(using: .utf8) ?? Data()
        return SHA256.hash(data: data).hex
    }
}
