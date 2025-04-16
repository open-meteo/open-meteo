import Foundation
import enum OpenMeteoSdk.openmeteo_sdk_Unit

typealias SiUnit = openmeteo_sdk_Unit

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

struct DataAndUnit {
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
