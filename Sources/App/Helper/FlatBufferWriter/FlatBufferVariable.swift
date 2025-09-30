import OpenMeteoSdk


/*
struct VariableGeneric {
    enum Hourly {
        case surface(ForecastSurfaceVariable)
        case airquality(CamsVariable)
        case flood(GloFasVariable)
        case marine(MarineVariable)
        case height(ForecastHeightVariableType, height: Int16)
        case pressure(ForecastPressureVariableType, pressure: Int16)
        case soil(ForecastSurfaceVariable, depth: Int16)
        case soilFromTo(ForecastSurfaceVariable, depth: Int16, depthTo: Int16)
    }
    
    enum Aggregation: String {
        case min
        case max
        case mean
    }
    
    enum Daily {
        case surface(ForecastVariableDaily)
        
    }
    
    let hourly: Hourly
    let daily: Daily
    let previousDay: Int16
}






struct FlatBufferVariable: RawRepresentableString, Equatable, Hashable {
    enum SurfaceOrPressure: Equatable, Hashable {
        // altitude=0 is surface
        case altitude(variable: openmeteo_sdk_Variable, altitude: Int16)
        case pressure(variable: openmeteo_sdk_Variable, pressureLevel: Int16)
        case depth(variable: openmeteo_sdk_Variable, depth: Int16)
        case depthFromTo(variable: openmeteo_sdk_Variable, depth: Int16, depthTo: Int16)
    }
    
    let variable: SurfaceOrPressure
    let previousDay: Int16
    let aggregation: openmeteo_sdk_Aggregation
    
    var variableSdk: openmeteo_sdk_Variable {
        switch variable {
        case .altitude(let variable, _):
            return variable
        case .pressure(let variable, _):
            return variable
        case .depth(let variable, _):
            return variable
        case .depthFromTo(let variable, _, _):
            return variable
        }
    }
    
    init(variable: SurfaceOrPressure, previousDay: Int16, aggregation: openmeteo_sdk_Aggregation) {
        self.variable = variable
        self.previousDay = previousDay
        self.aggregation = aggregation
    }
    
    init?(rawValue: String) {
        var end = rawValue.endIndex
        // scan backwards, first previous day, aggregation, then height/pressure
        
        if let start = rawValue.index(end, offsetBy: -14, limitedBy: rawValue.startIndex), rawValue[start ..< rawValue.index(end, offsetBy: -1)] == "_previous_day", let day = Int16(rawValue[rawValue.index(end, offsetBy: -1) ..< end]) {
            end = start
            self.previousDay = day
        } else {
            self.previousDay = 0
        }
        
        if let start = rawValue[..<end].lastIndex(of: "_"), let start2 = rawValue.index(start, offsetBy: 1, limitedBy: end), let agg = openmeteo_sdk_Aggregation.from(stringBackwardsCompatible: rawValue[start2..<end]) {
            self.aggregation = agg
            end = start
        } else {
            self.aggregation = .none_
        }
        
        // soil here
        
        if let start = rawValue[..<end].lastIndex(of: "_"), let start2 = rawValue.index(start, offsetBy: 1, limitedBy: end), let posM = rawValue.index(end, offsetBy: -1, limitedBy: start2), rawValue[posM..<end] == "m", let altitude = Int16(rawValue[start2..<posM]) {
            print(rawValue[posM..<end])
            print(rawValue[start2..<posM])
            print(altitude)
            end = start
            
            guard let v = openmeteo_sdk_Variable.from(stringBackwardsCompatible: rawValue[..<end]) else {
                return nil
            }
            
            self.variable = .altitude(variable: v, altitude: altitude)
            return
        }
        
        print(rawValue[..<end])
        
        
        fatalError()
    }
    
    var rawValue: String {
        fatalError()
    }
}

extension openmeteo_sdk_Aggregation {
    static func from(stringBackwardsCompatible str: Substring) -> Self? {
        if let value = Self(rawValue: String(str)) {
            return value
        }
        switch str {
        case "min":
            return .minimum
        case "max":
            return .maximum
        default:
            return nil
        }
    }
}


extension openmeteo_sdk_Variable {
    static func from(stringBackwardsCompatible str: Substring) -> Self? {
        if let value = Self(rawValue: String(str)) {
            return value
        }
        switch str {
        case "relativehumidity":
            return .relativeHumidity
        case "windspeed":
            return .windSpeed
        case "winddirection":
            return .windDirection
        case "surface_air_pressure":
            return .surfacePressure
        default:
            return nil
        }
    }
}
*/
