import Foundation
import SwiftEccodes

protocol GribMessageAssociated {
    static func fromGrib(attributes: GribAttributes) -> Self?
}

enum GribAttributeError: Error {
    case couldNotGetAttribute(attribute: String)
    case invalidStepType(given: String)
    case invalidLevelType(given: String)
}

struct GribAttributes {
    let shortName: String
    let stepRange: String
    let stepType: StepType
    let levelStr: String
    let typeOfLevel: LevelType
    let parameterName: String
    let parameterUnits: String
    let timestamp: Timestamp
    let unit: String
    let paramId: Int
    let perturbationNumber: Int?
    let parameterNumber: Int?
    let constituentType: Int?
    
    /// For ERA5 ensemble, `em` mean and `es` spread
    let dataType: String?
    
    enum LevelType: String {
        case surface
        case isobaricInhPa
        case meanSea
        case entireAtmosphere
        case heightAboveGround
        case depthBelowLandLayer
        case hybrid
    }
    
    enum StepType: String {
        case accum
        case avg
        case instant
        case max
        case min
        case diff
        case rms
    }
    
    init(message: GribMessage) throws {
        shortName = try message.getOrThrow(attribute: "shortName")
        stepRange = try message.getOrThrow(attribute: "stepRange")
        let stepTypeStr = try message.getOrThrow(attribute: "stepType")
        guard let stepType = StepType(rawValue: stepTypeStr) else {
            throw GribAttributeError.invalidStepType(given: stepTypeStr)
        }
        self.stepType = stepType
        levelStr = try message.getOrThrow(attribute: "level")
        let typeOfLevelStr = try message.getOrThrow(attribute: "typeOfLevel")
        guard let typeOfLevel = LevelType(rawValue:typeOfLevelStr) else {
            throw GribAttributeError.invalidLevelType(given: typeOfLevelStr)
        }
        self.typeOfLevel = typeOfLevel
        
        parameterName = try message.getOrThrow(attribute: "parameterName")
        parameterUnits = try message.getOrThrow(attribute: "parameterUnits")
        let validityTime = try message.getOrThrow(attribute: "validityTime")
        let validityDate = try message.getOrThrow(attribute: "validityDate")
        
        timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
        unit = try message.getOrThrow(attribute: "units")
        paramId = message.getLong(attribute: "paramId") ?? 0
        perturbationNumber = message.getLong(attribute: "perturbationNumber")
        dataType = try message.getOrThrow(attribute: "dataType")
        parameterNumber =  message.getLong(attribute: "parameterNumber")
        constituentType =  message.getLong(attribute: "constituentType")
    }
}


extension GribMessage {
    func getAttributes() throws -> GribAttributes {
        return try GribAttributes(message: self)
    }
    
    fileprivate func getOrThrow(attribute: String) throws -> String {
        guard let value = get(attribute: attribute) else {
            throw GribAttributeError.couldNotGetAttribute(attribute: attribute)
        }
        return value
    }
}
