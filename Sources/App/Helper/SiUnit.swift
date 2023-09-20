import Foundation


enum SiUnit {
    case celsius
    case fahrenheit
    case kelvin
    case kmh
    case mph
    case knots
    case ms
    case ms_not_unit_converted
    case millimeter
    case centimeter
    case inch
    case feet
    case meter
    case gpm
    case percent
    case hectoPascal
    case pascal
    case degreeDirection
    case wmoCode
    case wattPerSquareMeter
    case kilogramPerSquareMeter
    case gramPerKilogram
    case perSecond
    case second
    case qubicMeterPerQubicMeter
    case qubicMeterPerSecond
    case kiloPascal
    case megaJoulesPerSquareMeter
    case joulesPerKilogram
    case hours
    case iso8601
    case unixtime
    case microgramsPerQuibicMeter
    case grainsPerQuibicMeter
    case dimensionless
    case dimensionless_integer
    case eaqi
    case usaqi
    case gddCelsius
    case fraction
    
    var rawValue: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        case .kelvin: return "°K"
        case .kmh: return "km/h"
        case .mph: return "mp/h"
        case .knots: return "kn"
        case .ms: return "m/s"
        case .ms_not_unit_converted: return "m/s"
        case .millimeter: return "mm"
        case .centimeter: return "cm"
        case .inch: return "inch"
        case .feet: return "ft"
        case .meter: return "m"
        case .gpm: return "gpm"
        case .percent: return "%"
        case .hectoPascal: return "hPa"
        case .pascal: return "Pa"
        case .degreeDirection: return "°"
        case .wmoCode: return "wmo code"
        case .wattPerSquareMeter: return "W/m²"
        case .kilogramPerSquareMeter: return "kg/m²"
        case .gramPerKilogram: return "g/kg"
        case .perSecond: return "s⁻¹"
        case .second: return "s"
        case .qubicMeterPerQubicMeter: return "m³/m³"
        case .qubicMeterPerSecond: return "m³/s"
        case .kiloPascal: return "kPa"
        case .megaJoulesPerSquareMeter: return "MJ/m²"
        case .joulesPerKilogram: return "J/kg"
        case .hours: return "h"
        case .iso8601: return "iso8601"
        case .unixtime: return "unixtime"
        case .microgramsPerQuibicMeter: return "μg/m³"
        case .grainsPerQuibicMeter: return "grains/m³"
        case .dimensionless: return ""
        case .dimensionless_integer: return ""
        case .eaqi: return "EAQI"
        case .usaqi: return "USAQI"
        case .gddCelsius: return "GGDc"
        case .fraction: return "fraction"
        }
    }
    
    var significantDigits: Int {
        switch self {
        case .celsius: return 1
        case .fahrenheit: return 1
        case .kelvin: return 1
        case .kmh: return 1
        case .mph: return 1
        case .knots: return 1
        case .ms: return 2
        case .ms_not_unit_converted: return 2
        case .millimeter: return 2
        case .inch: return 3
        case .feet: return 3
        case .meter: return 2
        case .percent: return 0
        case .hectoPascal: return 1
        case .degreeDirection: return 0
        case .wmoCode: return 0
        case .wattPerSquareMeter: return 1
        case .qubicMeterPerQubicMeter: return 3
        case .kiloPascal: return 2
        case .megaJoulesPerSquareMeter: return 2
        case .hours: return 1
        case .iso8601: return 0
        case .unixtime: return 0
        case .gpm: return 0
        case .kilogramPerSquareMeter: return 2
        case .gramPerKilogram: return 2
        case .perSecond: return 2
        case .pascal: return 0
        case .centimeter: return 2
        case .second: return 2
        case .microgramsPerQuibicMeter: return 1
        case .grainsPerQuibicMeter: return 1
        case .dimensionless: return 2
        case .dimensionless_integer: return 0
        case .joulesPerKilogram: return 1
        case .qubicMeterPerSecond: return 2
        case .eaqi: return 0
        case .usaqi: return 0
        case .gddCelsius: return 2
        case .fraction: return 3
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
    let precipitation_unit: PrecipitationUnit?
    let length_unit: LengthUnit?
}

protocol ApiUnitsSelectable {
    var temperature_unit: TemperatureUnit? { get }
    var windspeed_unit: WindspeedUnit? { get }
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
    func convertAndRound<Query: ApiUnitsSelectable>(params: Query) -> DataAndUnit {
        var data = self.data
        var unit = self.unit
        
        let windspeedUnit = params.windspeed_unit ?? .kmh
        let temperatureUnit = params.temperature_unit
        let precipitationUnit = params.precipitation_unit ?? (params.length_unit == .imperial ? .inch : nil)
        if unit == .celsius && temperatureUnit == .fahrenheit {
            
            for i in data.indices {
                data[i] = (data[i] * 9/5) + 32
            }
            unit = .fahrenheit
        }
        if unit == .ms && windspeedUnit == .kmh {
            for i in data.indices {
                data[i] *= 3.6
            }
            unit = .kmh
        }
        if unit == .ms && windspeedUnit == .mph {
            for i in data.indices {
                data[i] *= 2.237
            }
            unit = .mph
        }
        if unit == .ms && windspeedUnit == .kn {
            for i in data.indices {
                data[i] *= 1.94384
            }
            unit = .knots
        }
        if unit == .millimeter && precipitationUnit == .inch {
            for i in data.indices {
                data[i] /= 25.4
            }
            unit = .inch
        }
        if unit == .centimeter && precipitationUnit == .inch {
            for i in data.indices {
                data[i] /= 2.54
            }
            unit = .inch
        }
        if unit == .meter && precipitationUnit == .inch {
            for i in data.indices {
                data[i] *= 3.280839895
            }
            unit = .feet
        }
        
        // round to 0 to 3 digits
        data.rounded(digits: unit.significantDigits)
        
        return DataAndUnit(data, unit)
    }
    
    func toApi(name: String) -> ApiColumn {
        return ApiColumn(variable: name, unit: unit, data: .float(data))
    }
    
    func toApiSingle(name: String) -> ApiColumnSingle {
        assert(data.count == 1)
        return ApiColumnSingle(variable: name, unit: unit, value: data[0])
    }
}
