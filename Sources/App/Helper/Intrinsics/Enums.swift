import Foundation

enum RawRepresentableError: Error {
    case invalidValue(value: String, availableValues: [String])
}

extension RawRepresentable where Self: CaseIterable, RawValue == String {
    /// Try to initialise this enum or throw an error message with a list of possible cases
    static func load(rawValue: String) throws -> Self {
        guard let value = Self(rawValue: rawValue) else {
            throw RawRepresentableError.invalidValue(value: rawValue, availableValues: allCases.map({ $0.rawValue }))
        }
        return value
    }

    /// Try to initialise this enum or throw an error message with a list of possible cases
    static func load(rawValueOptional: String?) throws -> Self? {
        guard let rawValueOptional else {
            return nil
        }
        return try load(rawValue: rawValueOptional)
    }

    /// Try to initialise and array of enums or throw an error message with a list of possible cases
    static func load(commaSeparated: String) throws -> [Self] {
        return try commaSeparated.split(separator: ",").map { rawValue in
            try Self.load(rawValue: String(rawValue))
        }
    }

    /// Try to initialise and array of enums or throw an error message with a list of possible cases
    static func load(commaSeparatedOptional: String?) throws -> [Self]? {
        guard let commaSeparatedOptional else {
            return nil
        }
        return try load(commaSeparated: commaSeparatedOptional)
    }
}

extension RawRepresentableString {
    /// Initialise from string array and also decode comas
    static func load(commaSeparatedOptional: [String]?) throws -> [Self]? {
        guard let commaSeparatedOptional else {
            return nil
        }
        return try load(commaSeparated: commaSeparatedOptional)
    }

    /// Initialise from string array and also decode comas
    static func load(commaSeparated: [String]) throws -> [Self] {
        return try commaSeparated.flatMap({ s in
            try s.split(separator: ",").map {
                guard let v = Self(rawValue: String($0)) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Cannot initialize \(Self.self) from invalid String value \(s)", underlyingError: nil))
                }
                return v
            }
        })
    }
}

extension Float {
    /// Initialise from string array and also decode comas
    static func load(commaSeparated: [String]) throws -> [Float] {
        return try commaSeparated.flatMap({ s in
            try s.split(separator: ",").map {
                guard let v = Float($0) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Cannot initialize \(Self.self) from invalid String value \(s)", underlyingError: nil))
                }
                return v
            }
        })
    }

    /// Initialise from string array and also decode comas
    static func load(commaSeparatedOptional: [String]?) throws -> [Self]? {
        guard let commaSeparatedOptional else {
            return nil
        }
        return try load(commaSeparated: commaSeparatedOptional)
    }
}

extension Int {
    /// Initialise from string array and also decode comas
    static func load(commaSeparated: [String]) throws -> [Int] {
        return try commaSeparated.flatMap({ s in
            try s.split(separator: ",").map {
                guard let v = Int($0) else {
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Cannot initialize \(Self.self) from invalid String value \(s)", underlyingError: nil))
                }
                return v
            }
        })
    }

    /// Initialise from string array and also decode comas
    static func load(commaSeparatedOptional: [String]?) throws -> [Self]? {
        guard let commaSeparatedOptional else {
            return nil
        }
        return try load(commaSeparated: commaSeparatedOptional)
    }
}
