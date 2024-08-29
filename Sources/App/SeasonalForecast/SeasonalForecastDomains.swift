import Foundation
import SwiftPFor2D

enum SeasonalForecastDomain: String, GenericDomain, CaseIterable {
    case ecmwf
    case ukMetOffice
    case meteoFrance
    case dwd
    case cmcc
    case ncep
    case jma
    case eccc
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .ecmwf:
            fatalError()
        case .ukMetOffice:
            fatalError()
        case .meteoFrance:
            fatalError()
        case .dwd:
            fatalError()
        case .cmcc:
            fatalError()
        case .ncep:
            return .ncep_cfsv2
        case .jma:
            fatalError()
        case .eccc:
            fatalError()
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var lastRun: Timestamp {
        switch self {
        case .ecmwf:
            fatalError()
        case .ukMetOffice:
            fatalError()
        case .meteoFrance:
            fatalError()
        case .dwd:
            fatalError()
        case .cmcc:
            fatalError()
        case .ncep:
            let t = Timestamp.now()
            let hour = ((t.hour - 8 + 24) % 24 ).floor(to: 6)
            /// 18z run is available the day after starting 05:26
            return t.add(-8*3600).with(hour: hour)
        case .jma:
            fatalError()
        case .eccc:
            fatalError()
        }

    }
    
    /// 14 days longer than actual one update
    var omFileLength: Int {
        switch self {
        case .ncep:
            return (6 * 31 + 14) * 24 / dtHours
        default:
            return nForecastHours + 14*24 / dtHours
        }
        
    }
    
    var grid: Gridable {
        switch self {
        case .ecmwf:
            fatalError()
        case .ukMetOffice:
            fatalError()
        case .meteoFrance:
            fatalError()
        case .dwd:
            fatalError()
        case .cmcc:
            fatalError()
        case .ncep:
            return RegularGrid(nx: 384, ny: 190, latMin: -89.2767, lonMin: -180, dx: (89.2767*2)/190, dy: 359.062/384, searchRadius: 0)
        case .jma:
            fatalError()
        case .eccc:
            fatalError()
        }
    }
    
    var nForecastHours: Int {
        switch self {
        case .ecmwf:
            fatalError()
        case .ukMetOffice:
            fatalError()
        case .meteoFrance:
            fatalError()
        case .dwd:
            fatalError()
        case .cmcc:
            fatalError()
        case .ncep:
            // Member 1 up to 9 months, but length differs from run to run. Member 2-4 45 days.
            return 7128 / dtHours
        case .jma:
            fatalError()
        case .eccc:
            fatalError()
        }
    }
    
    var dtSeconds: Int {
        return 6*3600
    }
    
    var dtHours: Int {
        dtSeconds / 3600
    }
    
    var version: Int {
        switch self {
        case .ecmwf:
            return 5
        case .ukMetOffice:
            return 601
        case .meteoFrance:
            return 8
        case .dwd:
            return 21
        case .cmcc:
            return 35
        case .ncep:
            return 4
        case .jma:
            return 3
        case .eccc:
            return 3
        }
    }
    
    var nMembers: Int {
        switch self {
        case .ecmwf:
            return 51
        case .ukMetOffice:
            return 2
        case .meteoFrance:
            return 1
        case .dwd:
            return 50
        case .cmcc:
            return 50
        case .ncep:
            return 4
        case .jma:
            return 5
        case .eccc:
            return 10
        }
    }
}

enum CfsVariable: String, CaseIterable, GenericVariable {
    case temperature_2m
    case temperature_2m_max
    case temperature_2m_min
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    case soil_temperature_0_to_10cm
    case shortwave_radiation
    case cloud_cover
    case wind_u_component_10m
    case wind_v_component_10m
    case precipitation
    case showers
    case relative_humidity_2m
    case pressure_msl
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Interpolation from 6h data to 1h not supported")
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_10cm:
            fallthrough
        case .soil_moisture_10_to_40cm:
            fallthrough
        case .soil_moisture_40_to_100cm:
            fallthrough
        case .soil_moisture_100_to_200cm:
            return true
        default:
            return false
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .temperature_2m_max || self == .temperature_2m_min
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .temperature_2m_max:
            return 20
        case .temperature_2m_min:
            return 20
        case .soil_moisture_0_to_10cm:
            return 1000
        case .soil_moisture_10_to_40cm:
            return 1000
        case .soil_moisture_40_to_100cm:
            return 1000
        case .soil_moisture_100_to_200cm:
            return 1000
        case .soil_temperature_0_to_10cm:
            return 20
        case .shortwave_radiation:
            return 1
        case .cloud_cover:
            return 1
        case .wind_u_component_10m:
            return 10
        case .wind_v_component_10m:
            return 10
        case .precipitation:
            return 10
        case .showers:
            return 10
        case .relative_humidity_2m:
            return 1
        case .pressure_msl:
            return 10
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .temperature_2m_max:
            return .celsius
        case .temperature_2m_min:
            return .celsius
        case .soil_moisture_0_to_10cm:
            return .cubicMetrePerCubicMetre
        case .soil_moisture_10_to_40cm:
            return .cubicMetrePerCubicMetre
        case .soil_moisture_40_to_100cm:
            return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_200cm:
            return .cubicMetrePerCubicMetre
        case .soil_temperature_0_to_10cm:
            return .celsius
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .cloud_cover:
            return .percentage
        case .wind_u_component_10m:
            return .metrePerSecond
        case .wind_v_component_10m:
            return .metrePerSecond
        case .precipitation:
            return .millimetre
        case .showers:
            return .millimetre
        case .relative_humidity_2m:
            return .percentage
        case .pressure_msl:
            return .hectopascal
        }
    }
}

/*enum SeasonalForecastVariable6Hourly {
    case temperature_2m
    case dewpoint_2m
    case wind_u_10m
    case wind_v_10m
    case mean_sea_level_pressure
    case total_precipitation
    case snowfall
    case soil_temperature
    case total_cloudcover
}

enum SeasonalForecastVariableDaily {
    case temperature_max
    case temperature_min
    case wind_gusts_max
    case surface_solar_radiation_downwards
    case snow_depth
}*/
