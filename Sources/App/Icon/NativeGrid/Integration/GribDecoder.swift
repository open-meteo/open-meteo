import Foundation
@preconcurrency import SwiftEccodes

struct IconNativeGribMetadata: Sendable, Equatable {
    let edition: Int?
    let gridType: String?
    let gridDefinitionTemplateNumber: Int?
    let numberOfGridUsed: Int?
    let uuidOfHGrid: String?
    let numberOfDataPoints: Int?

}

enum IconNativeGribError: Error, Equatable, CustomStringConvertible {
    case invalidEdition(Int?)
    case invalidGridType(String?)
    case invalidGridDefinitionTemplate(Int?)
    case invalidGridNumber(expected: UInt32, actual: Int?)
    case invalidGridUUID(expected: String, actual: String?)
    case invalidDataPointCount(expected: Int, actual: Int?)
    case invalidDecodedValueCount(expected: Int, actual: Int)

    var description: String {
        switch self {
        case .invalidEdition(let actual):
            return "Expected GRIB edition 2, got \(String(describing: actual))"
        case .invalidGridType(let actual):
            return "Expected unstructured_grid, got \(String(describing: actual))"
        case .invalidGridDefinitionTemplate(let actual):
            return "Expected grid definition template 3.101, got \(String(describing: actual))"
        case .invalidGridNumber(let expected, let actual):
            return "Expected ICON grid number \(expected), got \(String(describing: actual))"
        case .invalidGridUUID(let expected, let actual):
            return "Expected ICON grid UUID \(expected), got \(String(describing: actual))"
        case .invalidDataPointCount(let expected, let actual):
            return "Expected \(expected) ICON data points, got \(String(describing: actual))"
        case .invalidDecodedValueCount(let expected, let actual):
            return "Expected \(expected) bitmap-expanded ICON values, got \(actual)"
        }
    }
}

extension IconNativeGribMetadata {
    init(message: GribMessage) {
        edition = message.getLong(attribute: "edition")
        gridType = message.get(attribute: "gridType")
        gridDefinitionTemplateNumber = message.getLong(attribute: "gridDefinitionTemplateNumber")
        numberOfGridUsed = message.getLong(attribute: "numberOfGridUsed")
        uuidOfHGrid = message.get(attribute: "uuidOfHGrid")
        numberOfDataPoints = message.getLong(attribute: "numberOfDataPoints")
    }

    func validate(identity: IconNativeGridIdentity) throws {
        guard edition == 2 else {
            throw IconNativeGribError.invalidEdition(edition)
        }
        guard gridType == "unstructured_grid" else {
            throw IconNativeGribError.invalidGridType(gridType)
        }
        guard gridDefinitionTemplateNumber == 101 else {
            throw IconNativeGribError.invalidGridDefinitionTemplate(gridDefinitionTemplateNumber)
        }
        guard numberOfGridUsed == Int(identity.gridNumber) else {
            throw IconNativeGribError.invalidGridNumber(expected: identity.gridNumber, actual: numberOfGridUsed)
        }
        guard uuidOfHGrid?.lowercased() == identity.gridUUIDHex else {
            throw IconNativeGribError.invalidGridUUID(expected: identity.gridUUIDHex, actual: uuidOfHGrid)
        }
        guard numberOfDataPoints == identity.cellCount else {
            throw IconNativeGribError.invalidDataPointCount(expected: identity.cellCount, actual: numberOfDataPoints)
        }
    }
}

enum IconNativeGribDecoder {
    static func validateDecodedValueCount(_ count: Int, identity: IconNativeGridIdentity) throws {
        guard count == identity.cellCount else {
            throw IconNativeGribError.invalidDecodedValueCount(expected: identity.cellCount, actual: count)
        }
    }

    static func decode(message: GribMessage, identity: IconNativeGridIdentity) throws -> Array2D {
        try IconNativeGribMetadata(message: message).validate(identity: identity)
        // ecCodes expands a GRIB bitmap to the complete data-point sequence. Verifying the final
        // length protects the invariant that array offset equals the native cell index.
        let values = try message.getDouble().map(Float.init)
        try validateDecodedValueCount(values.count, identity: identity)
        return Array2D(data: values, nx: identity.cellCount, ny: 1)
    }
}
