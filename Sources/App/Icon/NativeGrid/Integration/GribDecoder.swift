import Foundation
@preconcurrency import SwiftEccodes

enum IconNativeGribError: Error {
    case invalidAttribute(String)
    case invalidValueCount(expected: Int, actual: Int)
}

enum IconNativeGribDecoder {
    static func decode(message: GribMessage, identity: IconNativeGridIdentity) throws -> Array2D {
        guard message.getLong(attribute: "edition") == 2 else {
            throw IconNativeGribError.invalidAttribute("edition")
        }
        guard message.get(attribute: "gridType") == "unstructured_grid" else {
            throw IconNativeGribError.invalidAttribute("gridType")
        }
        guard message.getLong(attribute: "gridDefinitionTemplateNumber") == 101 else {
            throw IconNativeGribError.invalidAttribute("gridDefinitionTemplateNumber")
        }
        guard message.getLong(attribute: "numberOfGridUsed") == Int(identity.gridNumber) else {
            throw IconNativeGribError.invalidAttribute("numberOfGridUsed")
        }
        guard message.get(attribute: "uuidOfHGrid")?.lowercased() == identity.gridUUID.hexString else {
            throw IconNativeGribError.invalidAttribute("uuidOfHGrid")
        }
        guard message.getLong(attribute: "numberOfDataPoints") == identity.cellCount else {
            throw IconNativeGribError.invalidAttribute("numberOfDataPoints")
        }
        // ecCodes expands a GRIB bitmap to the complete data-point sequence. Verifying the final
        // length protects the invariant that array offset equals the native cell index.
        let values = try message.getFloats()
        guard values.count == identity.cellCount else {
            throw IconNativeGribError.invalidValueCount(expected: identity.cellCount, actual: values.count)
        }
        return Array2D(data: values, nx: identity.cellCount, ny: 1)
    }
}
