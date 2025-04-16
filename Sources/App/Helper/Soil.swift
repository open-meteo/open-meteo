import Foundation

/**
 Soil type definitions from ERA5 which uses IFC cycle 41r2
 The seven soil types are: 1: Coarse, 2: Medium, 3: Medium fine, 4: Fine, 5: Very fine, 6: Organic, 7: Tropical organic. A value of 0 indicates a non-land point.
 
 Defined in https://www.ecmwf.int/en/elibrary/79697-ifs-documentation-cy41r2-part-iv-physical-processes (page 137)
 */
enum SoilTypeEra5: Int {
    case coarse = 1
    case medium = 2
    case mediumFine = 3
    case fine = 4
    case veryFine = 5
    case organic = 6
    case loamy = 7

    /// Saturation, `θsat` in `m3^m−3`
    var saturation: Float {
        switch self {
        case .coarse:
            return 0.403
        case .medium:
            return 0.439
        case .mediumFine:
            return 0.430
        case .fine:
            return 0.520
        case .veryFine:
            return 0.614
        case .organic:
            return 0.766
        case .loamy:
            return 0.472
        }
    }

    /// Field Capacity, `θcap` in `m3^m−3`
    var fieldCapacity: Float {
        switch self {
        case .coarse:
            return 0.244
        case .medium:
            return 0.347
        case .mediumFine:
            return 0.383
        case .fine:
            return 0.448
        case .veryFine:
            return 0.541
        case .organic:
            return 0.663
        case .loamy:
            return 0.323
        }
    }

    /// Permanent wilting point, `θpwp` in `m3^m−3`
    var permanentWiltingPoint: Float {
        switch self {
        case .coarse:
            return 0.059
        case .medium:
            return 0.151
        case .mediumFine:
            return 0.133
        case .fine:
            return 0.279
        case .veryFine:
            return 0.335
        case .organic:
            return 0.267
        case .loamy:
            return 0.171
        }
    }

    /// Residual Moisture , `θres` in `m3^m−3`
    var residualMoisture: Float {
        switch self {
        case .coarse:
            return 0.025
        default:
            return 0.010
        }
    }

    /// Plant available soil moisture `θcap − θpwp` in `m3^m−3`
    var plantAvailableSoilMoisture: Float {
        return fieldCapacity - permanentWiltingPoint
    }

    /// soil moisture index (SMI) defined as (SM-PWP)/(FC-PWP). This index is equal to zero at the permanent wilting point and one at field capacity but it can be larger than one after rain
    /// https://www.ecmwf.int/en/forecasts/documentation-and-support/evolution-ifs/cycles/change-soil-hydrology-scheme-ifs-cycle
    func calculateSoilMoistureIndex(_ data: [Float]) -> [Float] {
        return data.map {
            return ($0 - permanentWiltingPoint) / (fieldCapacity - permanentWiltingPoint)
        }
    }
}
