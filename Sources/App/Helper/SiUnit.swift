import Foundation
import enum OpenMeteoSdk.openmeteo_sdk_Unit

typealias SiUnit = openmeteo_sdk_Unit

extension SiUnit {
    /// Number of decimals used when formatting values for API/file output (JSON/CSV/XLSX/export).
    /// Defaults to the SDK's `significantDigits`, but raises specific humidity (g/kg) to 5: it spans
    /// ~4–5 orders of magnitude, so the default 2 decimals truncates dry-layer values to `0.00`
    /// (and breaks any client-side dew-point computed from the rounded value).
    var apiSignificantDigits: Int {
        switch self {
        case .gramPerKilogram: return 5
        default: return significantDigits
        }
    }
}

enum TemperatureUnit: String, Codable {
    case celsius
    case fahrenheit
}

enum WindspeedUnit: String, Codable {
    case kmh
    case mph
    case kn
    case ms
}

enum PrecipitationUnit: String, Codable {
    case mm
    case inch
}

enum LengthUnit: String, Codable {
    case metric
    case imperial
}

struct ApiUnits: ApiUnitsSelectable {
    let temperature_unit: TemperatureUnit?
    let windspeed_unit: WindspeedUnit?
    let wind_speed_unit: WindspeedUnit?
    let precipitation_unit: PrecipitationUnit?
    let length_unit: LengthUnit?
}

protocol ApiUnitsSelectable {
    var temperature_unit: TemperatureUnit? { get }
    var windspeed_unit: WindspeedUnit? { get }
    var wind_speed_unit: WindspeedUnit? { get }
    var precipitation_unit: PrecipitationUnit? { get }
    var length_unit: LengthUnit? { get }
}

extension SiUnit: @retroactive @unchecked Sendable {
    
}

struct DataAndUnit: Sendable {
    let data: [Float]
    let unit: SiUnit

    public init(_ data: [Float], _ unit: SiUnit) {
        self.data = data
        self.unit = unit
    }

    /// Convert a given array to target units
    /// Note: Rounding is now done in the writers
    func convertAndRound<Query: ApiUnitsSelectable>(params: Query) -> DataAndUnit {
        var data = self.data
        var unit = self.unit

        let windspeedUnit = params.windspeed_unit ?? params.wind_speed_unit ?? .kmh
        let temperatureUnit = params.temperature_unit
        let precipitationUnit = params.precipitation_unit ?? (params.length_unit == .imperial ? .inch : nil)
        if unit == .celsius && temperatureUnit == .fahrenheit {
            for i in data.indices {
                data[i] = (data[i] * 9 / 5) + 32
            }
            unit = .fahrenheit
        }
        if unit == .metrePerSecond && windspeedUnit == .kmh {
            for i in data.indices {
                data[i] *= 3.6
            }
            unit = .kilometresPerHour
        }
        if unit == .metrePerSecond && windspeedUnit == .mph {
            for i in data.indices {
                data[i] *= 2.237
            }
            unit = .milesPerHour
        }
        if unit == .metrePerSecond && windspeedUnit == .kn {
            for i in data.indices {
                data[i] *= 1.94384
            }
            unit = .knots
        }
        if unit == .millimetre && precipitationUnit == .inch {
            for i in data.indices {
                data[i] /= 25.4
            }
            unit = .inch
        }
        if unit == .centimetre && precipitationUnit == .inch {
            for i in data.indices {
                data[i] /= 2.54
            }
            unit = .inch
        }
        if unit == .metre && precipitationUnit == .inch {
            for i in data.indices {
                data[i] *= 3.280839895
            }
            unit = .feet
        }
        return DataAndUnit(data, unit)
    }
}
