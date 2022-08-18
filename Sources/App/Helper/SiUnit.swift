import Foundation


enum SiUnit: String, Codable {
    case celsius = "°C"
    case fahrenheit = "°F"
    case kmh = "km/h"
    case mph = "mp/h"
    case knots = "kn"
    case ms = "m/s"
    case millimeter = "mm"
    case centimeter = "cm"
    case inch = "inch"
    case meter = "m"
    case gpm = "gpm"
    case percent = "%"
    case hectoPascal = "hPa"
    case pascal = "Pa"
    case degreeDirection = "°"
    case wmoCode = "wmo code"
    case wattPerSquareMeter = "W/m²"
    case kilogramPerSquareMeter = "kg/m²"
    case gramPerKilogram = "g/kg"
    case perSecond = "s⁻¹"
    case second = "s"
    case qubicMeterPerQubicMeter = "m³/m³"
    case kiloPascal = "kPa"
    case megaJoulesPerSquareMeter = "MJ/m²"
    case joulesPerKilogram = "J/kg"
    case hours = "h"
    case iso8601
    case unixtime
    case microgramsPerQuibicMeter = "μg/m³"
    case grainsPerQuibicMeter = "grains/m³"
    case dimensionless = ""
    
    var significantDigits: Int {
        switch self {
        case .celsius: return 1
        case .fahrenheit: return 1
        case .kmh: return 1
        case .mph: return 1
        case .knots: return 1
        case .ms: return 2
        case .millimeter: return 2
        case .inch: return 3
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
        case .microgramsPerQuibicMeter: return 0
        case .grainsPerQuibicMeter: return 1
        case .dimensionless: return 2
        case .joulesPerKilogram: return 0
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


struct DataAndUnit {
    let data: [Float]
    let unit: SiUnit
    
    public init(_ data: [Float], _ unit: SiUnit) {
        self.data = data
        self.unit = unit
    }
    
    func conertAndRound(params: ForecastapiQuery) -> DataAndUnit {
        return convertAndRound(temperatureUnit: params.temperature_unit, windspeedUnit: params.windspeed_unit, precipitationUnit: params.precipitation_unit)
    }
    
    func conertAndRound(params: SeasonalQuery) -> DataAndUnit {
        return convertAndRound(temperatureUnit: params.temperature_unit, windspeedUnit: params.windspeed_unit, precipitationUnit: params.precipitation_unit)
    }
    
    func conertAndRound(params: Era5Query) -> DataAndUnit {
        return convertAndRound(temperatureUnit: params.temperature_unit, windspeedUnit: params.windspeed_unit, precipitationUnit: params.precipitation_unit)
    }

    /// Convert a given array to target unit
    func convertAndRound(temperatureUnit: TemperatureUnit?, windspeedUnit: WindspeedUnit?, precipitationUnit: PrecipitationUnit?) -> DataAndUnit {
        
        var data = self.data
        var unit = self.unit
        
        let windspeedUnit = windspeedUnit ?? .kmh
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
        
        // round to 0 to 3 digits
        data.rounded(digits: unit.significantDigits)
        
        return DataAndUnit(data, unit)
    }
    
    func toApi(name: String) -> ApiColumn {
        return ApiColumn(variable: name, unit: unit, data: .float(data))
    }
}
