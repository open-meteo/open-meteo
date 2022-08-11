import Foundation
import SwiftPFor2D

enum SeasonalForecastDomain: String, GenericDomain {
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
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    static var ncepElevation = try? OmFileReader(file: Self.ncep.surfaceElevationFileOm)
    
    var elevationFile: OmFileReader? {
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
            return Self.ncepElevation
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
            return RegularGrid(nx: 384, ny: 190, latMin: -89.2767, lonMin: -180, dx: (89.2767*2)/190, dy: 359.062/384)
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

enum CfsVariable: String, CaseIterable, Codable, GenericVariable {
    case temperature_2m
    case temperature_2m_max
    case temperature_2m_min
    case soil_moisture_0_to_10_cm
    case soil_moisture_10_to_40_cm
    case soil_moisture_40_to_100_cm
    case soil_moisture_100_to_200_cm
    case soil_temperature_0_to_10_cm
    case shortwave_radiation
    case total_cloud_cover
    case wind_u_component_10m
    case wind_v_component_10m
    case total_precipitation
    case convective_precipitation
    case specific_humidity_2m
    case surface_pressure
    
    var omFileName: String {
        return rawValue
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Interpolation from 6h data to 1h not supported")
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .temperature_2m_max || self == .temperature_2m_min || self == .surface_pressure
    }
    
    
    /// Note: wind u/v components are in the same grib file
    var timeGribName: String {
        switch self {
        case .temperature_2m:
            return "tmp2m"
        case .temperature_2m_max:
            return "tmax"
        case .temperature_2m_min:
            return "tmin"
        case .soil_moisture_0_to_10_cm:
            return "soilm1"
        case .soil_moisture_10_to_40_cm:
            return "soilm2"
        case .soil_moisture_40_to_100_cm:
            return "soilm3"
        case .soil_moisture_100_to_200_cm:
            return "soilm4"
        case .soil_temperature_0_to_10_cm:
            return "soilt1"
        case .shortwave_radiation:
            return "dswsfc"
        case .total_cloud_cover:
            return "tcdcclm"
        case .wind_u_component_10m:
            return "wnd10m" // mixed in wnd10m
        case .wind_v_component_10m:
            return "wnd10m"
        case .total_precipitation:
            return "prate"
        case .convective_precipitation:
            return "cprat"
        case .specific_humidity_2m:
            return "q2m"
        case .surface_pressure:
            return "pressfc"
        }
    }
    
    /// Grib shortname and level
    var timeGribKey: String? {
        switch self {
        case .wind_u_component_10m:
            return "10u10"
        case .wind_v_component_10m:
            return "10v10"
        default:
            return nil
        }
    }
    
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
        case .shortwave_radiation:
            return 1
        case .total_cloud_cover:
            return 1
        case .wind_u_component_10m:
            return 10
        case .wind_v_component_10m:
            return 10
        case .total_precipitation:
            return 10
        case .convective_precipitation:
            return 10
        case .specific_humidity_2m:
            // grams of water (moisture) per kilogram of air (ranges 0-21)
            return 100
        case .surface_pressure:
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
        case .shortwave_radiation:
            return .wattPerSquareMeter
        case .total_cloud_cover:
            return .percent
        case .wind_u_component_10m:
            return .ms
        case .wind_v_component_10m:
            return .ms
        case .total_precipitation:
            return .millimeter
        case .convective_precipitation:
            return .millimeter
        case .specific_humidity_2m:
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
        case .shortwave_radiation:
            return (1,0)
        case .total_cloud_cover:
            return (1,0)
        case .wind_u_component_10m:
            return (1,0)
        case .wind_v_component_10m:
            return (1,0)
        case .total_precipitation:
            return (3600*6,0)
        case .convective_precipitation:
            return (3600*6,0)
        case .surface_pressure:
            // convert Pa to hPa
            return (1/100,0)
        case .specific_humidity_2m:
            // convert kg/kg to g/kg
            return (1000,0)
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
