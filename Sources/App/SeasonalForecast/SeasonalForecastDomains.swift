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
    
    var downloadDirectory: String {
        return "./data/\(rawValue)/"
    }
    
    var omfileDirectory: String {
        return "./data/omfile-\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    
    /// 14 days longer than actual one update
    var omFileLength: Int {
        return nForecastHours + 14*24/dtHours
    }
    
    var grid: RegularGrid {
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
            return RegularGrid(nx: 384, ny: 190, latMin: -89.2767, lonMin: -179.531, dx: (89.2767*2)/190, dy: (2*179.531)/384)
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
    case low_cloud_cover
    case medium_cloud_cover
    case high_cloud_cover
    case convective_cloud_cover
    case wind_u_component_10m
    case wind_v_component_10m
    case potential_evapotranspiration
    case total_precipitation
    case convective_precipitation
    case latent_heatflux
    case specific_humidity
    case surface_pressure
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .temperature_2m_max:
            return 20
        case .temperature_2m_min:
            return 20
        case .soil_moisture_0_to_10_cm:
            return 1000
        case .soil_moisture_10_to_40_cm:
            return 1000
        case .soil_moisture_40_to_100_cm:
            return 1000
        case .soil_moisture_100_to_200_cm:
            return 1000
        case .soil_temperature_0_to_10_cm:
            return 20
        case .soil_temperature_10_to_40_cm:
            return 20
        case .soil_temperature_40_to_100_cm:
            return 20
        case .soil_temperature_100_to_200_cm:
            return 20
        case .snow_depth:
            return 100
        case .shortwave_radiation:
            return 1
        case .low_cloud_cover:
            return 1
        case .medium_cloud_cover:
            return 1
        case .high_cloud_cover:
            return 1
        case .convective_cloud_cover:
            return 1
        case .wind_u_component_10m:
            return 10
        case .wind_v_component_10m:
            return 10
        case .potential_evapotranspiration:
            return 10
        case .total_precipitation:
            return 10
        case .convective_precipitation:
            return 10
        case .latent_heatflux:
            return 0.144 // round watts to 7.. results in 0.01 resolution in evpotrans
        case .specific_humidity:
            // grams of water (moisture) per kilogram of air (ranges 0-21)
            return 100
        case .surface_pressure:
            return 10
        }
    }
    
    var skipHour0: Bool {
        switch self {
        case.convective_cloud_cover:
            return true
        default:
            return false
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
        case .soil_moisture_0_to_10_cm:
            return .qubicMeterPerQubicMeter
        case .soil_moisture_10_to_40_cm:
            return .qubicMeterPerQubicMeter
        case .soil_moisture_40_to_100_cm:
            return .qubicMeterPerQubicMeter
        case .soil_moisture_100_to_200_cm:
            return .qubicMeterPerQubicMeter
        case .soil_temperature_0_to_10_cm:
            return .celsius
        case .soil_temperature_10_to_40_cm:
            return .celsius
        case .soil_temperature_40_to_100_cm:
            return .celsius
        case .soil_temperature_100_to_200_cm:
            return .celsius
        case .snow_depth:
            return .meter
        case .shortwave_radiation:
            return .wattPerSquareMeter
        case .low_cloud_cover:
            return .percent
        case .medium_cloud_cover:
            return .percent
        case .high_cloud_cover:
            return .percent
        case .convective_cloud_cover:
            return .percent
        case .wind_u_component_10m:
            return .ms
        case .wind_v_component_10m:
            return .ms
        case .potential_evapotranspiration:
            return .millimeter
        case .total_precipitation:
            return .millimeter
        case .convective_precipitation:
            return .millimeter
        case .latent_heatflux:
            return .wattPerSquareMeter
        case .specific_humidity:
            return .gramPerKilogram
        case .surface_pressure:
            return .hectoPascal
        }
    }
    
    var gribMultiplyAdd: (multiply: Float, add: Float) {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .temperature_2m_max:
            return (1, -273.15)
        case .temperature_2m_min:
            return (1, -273.15)
        case .soil_moisture_0_to_10_cm:
            return (1,0)
        case .soil_moisture_10_to_40_cm:
            return (1,0)
        case .soil_moisture_40_to_100_cm:
            return (1,0)
        case .soil_moisture_100_to_200_cm:
            return (1,0)
        case .soil_temperature_0_to_10_cm:
            return (1, -273.15)
        case .soil_temperature_10_to_40_cm:
            return (1, -273.15)
        case .soil_temperature_40_to_100_cm:
            return (1, -273.15)
        case .soil_temperature_100_to_200_cm:
            return (1, -273.15)
        case .snow_depth:
            return (1,0)
        case .shortwave_radiation:
            return (1,0)
        case .low_cloud_cover:
            return (1,0)
        case .medium_cloud_cover:
            return (1,0)
        case .high_cloud_cover:
            return (1,0)
        case .convective_cloud_cover:
            return (1,0)
        case .wind_u_component_10m:
            return (1,0)
        case .wind_v_component_10m:
            return (1,0)
        case .potential_evapotranspiration:
            return (3600*6/2.5e6,0)
        case .total_precipitation:
            return (3600*6,0)
        case .convective_precipitation:
            return (3600*6,0)
        case .latent_heatflux:
            return (1,0)
        case .surface_pressure:
            // convert Pa to hPa
            return (1/100,0)
        case .specific_humidity:
            // convert kg/kg to g/kg
            return (1000,0)
        }
    }
    
    var gribIndexName: String {
        switch self {
        case .temperature_2m:
            return ":TMP:2 m above ground:"
        case .soil_moisture_0_to_10_cm:
            return ":SOILW:0-0.1 m below ground:"
        case .soil_moisture_10_to_40_cm:
            return ":SOILW:0.1-0.4 m below ground:"
        case .soil_moisture_40_to_100_cm:
            return ":SOILW:0.4-1 m below ground:"
        case .soil_moisture_100_to_200_cm:
            return ":SOILW:1-2 m below ground:"
        case .soil_temperature_0_to_10_cm:
            return ":TMP:0-0.1 m below ground:"
        case .soil_temperature_10_to_40_cm:
            return ":TMP:0.1-0.4 m below ground:"
        case .soil_temperature_40_to_100_cm:
            return ":TMP:0.4-1 m below ground:"
        case .soil_temperature_100_to_200_cm:
            return ":TMP:1-2 m below ground:"
        case .snow_depth:
            return ":SNOD:surface:"
        case .shortwave_radiation:
            return ":DSWRF:surface:"
        case .low_cloud_cover:
            return ":TCDC:high cloud layer:"
        case .medium_cloud_cover:
            return ":TCDC:middle cloud layer:"
        case .high_cloud_cover:
            return ":TCDC:low cloud layer:"
        case .convective_cloud_cover:
            return ":TCDC:convective cloud layer:"
        case .wind_u_component_10m:
            return ":UGRD:10 m above ground:"
        case .wind_v_component_10m:
            return ":VGRD:10 m above ground:"
        case .temperature_2m_max:
            return ":TMAX:2 m above ground:"
        case .temperature_2m_min:
            return ":TMIN:2 m above ground:"
        case .potential_evapotranspiration:
            return ":PEVPR:surface:"
        case .total_precipitation:
            return ":PRATE:surface:"
        case .convective_precipitation:
            return ":CPRAT:surface:"
        case .latent_heatflux:
            return ":LHTFL:surface:"
        case .specific_humidity:
            return ":SPFH:2 m above ground:"
        case .surface_pressure:
            return ":PRES:surface:"
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
