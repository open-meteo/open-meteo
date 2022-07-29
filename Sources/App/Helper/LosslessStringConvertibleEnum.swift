import Foundation

/// Protocol to conform a string enum to LosslessStringConvertible
public protocol LosslessStringConvertibleEnum: RawRepresentable, LosslessStringConvertible {
    
}

extension LosslessStringConvertibleEnum where RawValue == String {
    public init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
    
    var description: String {
        return rawValue
    }
}
