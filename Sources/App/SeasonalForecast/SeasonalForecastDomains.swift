import Foundation

enum SeasonalForecastDomain: String {
    case ecmwf
    case ukMetOffice
    case meteoFrance
    case dwd
    case cmcc
    case ncep
    case jma
    case eccc
    
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
            return 2
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
            return 1
        case .jma:
            return 5
        case .eccc:
            return 10
        }
    }
}

enum SeasonalForecastVariable6Hourly {
    case temperature_2m
    case dewpoint_2m
    case wind_u_10m
    case wind_v_10m
    case mean_sea_level_pressure
    case total_precipitation
    case snowfall
    case soil_temperature
    case total_cloud_cover
}

enum SeasonalForecastVariableDaily {
    case temperature_max
    case temperature_min
    case wind_gusts_max
    case surface_solar_radiation_downwards
    case snow_depth
}
