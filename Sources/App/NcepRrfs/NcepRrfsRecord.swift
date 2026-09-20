// See docs/ncep-rrfs/README.md for RRFS products, GRIB inputs and processing details.

import Foundation

/// A selected GRIB input and its forecast interval, supplied by the variable catalog.
struct NcepRrfsRecord: Sendable {
    let variable: String
    let parameter: String
    let startMinute: Int
    let endMinute: Int
    let stepType: String

    var field: NcepRrfsVariable? { NcepRrfsVariable(rawValue: variable) }
    var isSolarRadiation: Bool { parameter == "DSWRF" || parameter == "VDDSF" }
    var requiresSolarBackwardsConversion: Bool { isSolarRadiation && stepType == "instant" }
    var isWind: Bool { parameter == "UGRD" || parameter == "VGRD" }

    func convertUnits(data: inout [Float]) {
        if ["TMP", "DPT", "TSOIL"].contains(parameter) { data.multiplyAdd(multiply: 1, add: -273.15) }
        if variable == "pressure_msl" || variable == "surface_pressure" { data.multiplyAdd(multiply: 0.01, add: 0) }
        if variable == "snowfall" { data.multiplyAdd(multiply: 100, add: 0) }
        // NOAA reports negative CIN; Open-Meteo stores its positive magnitude.
        if variable == "convective_inhibition" { data.multiplyAdd(multiply: -1, add: 0) }
    }
}
