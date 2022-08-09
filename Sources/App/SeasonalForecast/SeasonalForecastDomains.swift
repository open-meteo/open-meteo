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
            return 821
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
            return 1
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

enum CfsVariable: String, CaseIterable, CurlIndexedVariable {
    case temperature_2m
    case temperature_2m_max
    case temperature_2m_min
    case soil_moisture_0_to_10_cm
    case soil_moisture_10_to_40_cm
    case soil_moisture_40_to_100_cm
    case soil_moisture_100_to_200_cm
    case soil_temperature_0_to_10_cm
    case soil_temperature_10_to_40_cm
    case soil_temperature_40_to_100_cm
    case soil_temperature_100_to_200_cm
    case snow_depth
    case shortwave_radiation
    case uv_index
    case uv_index_clear_sky
    case low_cloud_cover
    case medium_cloud_cover
    case high_cloud_cover
    case convective_cloud_cover
    case wind_u_component_10m
    case wind_v_component_10m
    case potential_evapotranspiration
    case total_precipitation
    case convective_precipitation
    
    func matchesIndex(_ index: Substring) -> Bool {
        index.contains("\(grib.name):\(grib.level)")
    }
    
    var grib: (name: String, level: String) {
        switch self {
        case .temperature_2m:
            return ("TMP", "2 m above ground")
        case .soil_moisture_0_to_10_cm:
            return ("SOILW", "0-0.1 m below ground")
        case .soil_moisture_10_to_40_cm:
            return ("SOILW", "0.1-0.4 m below ground")
        case .soil_moisture_40_to_100_cm:
            return ("SOILW", "0.4-1 m below ground")
        case .soil_moisture_100_to_200_cm:
            return ("SOILW", "1-2 m below ground")
        case .soil_temperature_0_to_10_cm:
            return ("TMP", "0-0.1 m below ground")
        case .soil_temperature_10_to_40_cm:
            return ("TMP", "0.1-0.4 m below ground")
        case .soil_temperature_40_to_100_cm:
            return ("TMP", "0.4-1 m below ground")
        case .soil_temperature_100_to_200_cm:
            return ("TMP", "1-2 m below ground")
        case .snow_depth:
            return ("SNOD", "surface")
        case .shortwave_radiation:
            return ("DSWRF", "surface")
        case .uv_index:
            return ("DUVB", "surface")
        case .uv_index_clear_sky:
            return ("CDUVB", "surface")
        case .low_cloud_cover:
            return ("TCDC", "high cloud layer")
        case .medium_cloud_cover:
            return ("TCDC", "middle cloud layer")
        case .high_cloud_cover:
            return ("TCDC", "low cloud layer")
        case .convective_cloud_cover:
            return ("TCDC", "convective cloud layer")
        case .wind_u_component_10m:
            return ("UGRD", "10 m above ground")
        case .wind_v_component_10m:
            return ("VGRD", "10 m above ground")
        case .temperature_2m_max:
            return ("TMAX", "2 m above ground")
        case .temperature_2m_min:
            return ("TMIN", "2 m above ground")
        case .potential_evapotranspiration:
            return ("PEVPR", "surface")
        case .total_precipitation:
            return ("PRATE", "surface")
        case .convective_precipitation:
            return ("CPRAT", "surface")
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
