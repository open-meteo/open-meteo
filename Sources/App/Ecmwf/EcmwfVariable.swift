import Foundation

/// Represent a ECMWF variable as available in the grib2 files
enum EcmwfVariable: String, CaseIterable, Hashable, Codable, GenericVariable {
    case soil_temperature_0_to_7cm
    case skin_temperature
    case geopotential_height_1000hPa
    case geopotential_height_925hPa
    case geopotential_height_850hPa
    case geopotential_height_700hPa
    case geopotential_height_500hPa
    case geopotential_height_300hPa
    case geopotential_height_250hPa
    case geopotential_height_200hPa
    case geopotential_height_50hPa
    case northward_wind_1000hPa
    case northward_wind_925hPa
    case northward_wind_850hPa
    case northward_wind_700hPa
    case northward_wind_500hPa
    case northward_wind_300hPa
    case northward_wind_250hPa
    case northward_wind_200hPa
    case northward_wind_50hPa
    case eastward_wind_1000hPa
    case eastward_wind_925hPa
    case eastward_wind_850hPa
    case eastward_wind_700hPa
    case eastward_wind_500hPa
    case eastward_wind_300hPa
    case eastward_wind_250hPa
    case eastward_wind_200hPa
    case eastward_wind_50hPa
    case temperature_1000hPa
    case temperature_925hPa
    case temperature_850hPa
    case temperature_700hPa
    case temperature_500hPa
    case temperature_300hPa
    case temperature_250hPa
    case temperature_200hPa
    case temperature_50hPa
    case relative_humidity_1000hPa
    case relative_humidity_925hPa
    case relative_humidity_850hPa
    case relative_humidity_700hPa
    case relative_humidity_500hPa
    case relative_humidity_300hPa
    case relative_humidity_250hPa
    case relative_humidity_200hPa
    case relative_humidity_50hPa
    case surface_air_pressure
    case pressure_msl
    case total_column_integrated_water_vapour
    case northward_wind_10m
    case eastward_wind_10m
    case specific_humidity_1000hPa
    case specific_humidity_925hPa
    case specific_humidity_850hPa
    case specific_humidity_700hPa
    case specific_humidity_500hPa
    case specific_humidity_300hPa
    case specific_humidity_250hPa
    case specific_humidity_200hPa
    case specific_humidity_50hPa
    case temperature_2m
    case atmosphere_relative_vorticity_1000hPa
    case atmosphere_relative_vorticity_925hPa
    case atmosphere_relative_vorticity_850hPa
    case atmosphere_relative_vorticity_700hPa
    case atmosphere_relative_vorticity_500hPa
    case atmosphere_relative_vorticity_300hPa
    case atmosphere_relative_vorticity_250hPa
    case atmosphere_relative_vorticity_200hPa
    case atmosphere_relative_vorticity_50hPa
    case divergence_of_wind_1000hPa
    case divergence_of_wind_925hPa
    case divergence_of_wind_850hPa
    case divergence_of_wind_700hPa
    case divergence_of_wind_500hPa
    case divergence_of_wind_300hPa
    case divergence_of_wind_250hPa
    case divergence_of_wind_200hPa
    case divergence_of_wind_50hPa
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    static let pressure_levels = [1000, 925, 850, 700, 500, 300, 250, 200, 50]
    
    var omFileName: String {
        return nameInFiles
    }
    
    var nameInFiles: String {
        return rawValue
    }
    
    var unit: SiUnit {
        switch self {
        case .soil_temperature_0_to_7cm: fallthrough
        case .skin_temperature: return .celsius
        case .geopotential_height_1000hPa: fallthrough
        case .geopotential_height_925hPa: fallthrough
        case .geopotential_height_850hPa: fallthrough
        case .geopotential_height_700hPa: fallthrough
        case .geopotential_height_500hPa: fallthrough
        case .geopotential_height_300hPa: fallthrough
        case .geopotential_height_250hPa: fallthrough
        case .geopotential_height_200hPa: fallthrough
        case .geopotential_height_50hPa: return .gpm
        case .northward_wind_1000hPa: fallthrough
        case .northward_wind_925hPa: fallthrough
        case .northward_wind_850hPa: fallthrough
        case .northward_wind_700hPa: fallthrough
        case .northward_wind_500hPa: fallthrough
        case .northward_wind_300hPa: fallthrough
        case .northward_wind_250hPa: fallthrough
        case .northward_wind_200hPa: fallthrough
        case .northward_wind_50hPa: fallthrough
        case .eastward_wind_1000hPa: fallthrough
        case .eastward_wind_925hPa: fallthrough
        case .eastward_wind_850hPa: fallthrough
        case .eastward_wind_700hPa: fallthrough
        case .eastward_wind_500hPa: fallthrough
        case .eastward_wind_300hPa: fallthrough
        case .eastward_wind_250hPa: fallthrough
        case .eastward_wind_200hPa: fallthrough
        case .eastward_wind_50hPa: return .ms
        case .temperature_1000hPa: fallthrough
        case .temperature_925hPa: fallthrough
        case .temperature_850hPa: fallthrough
        case .temperature_700hPa: fallthrough
        case .temperature_500hPa: fallthrough
        case .temperature_300hPa: fallthrough
        case .temperature_250hPa: fallthrough
        case .temperature_200hPa: fallthrough
        case .temperature_50hPa: return .celsius
        case .relative_humidity_1000hPa: fallthrough
        case .relative_humidity_925hPa: fallthrough
        case .relative_humidity_850hPa: fallthrough
        case .relative_humidity_700hPa: fallthrough
        case .relative_humidity_500hPa: fallthrough
        case .relative_humidity_300hPa: fallthrough
        case .relative_humidity_250hPa: fallthrough
        case .relative_humidity_200hPa: fallthrough
        case .relative_humidity_50hPa: return .gramPerKilogram
        case .surface_air_pressure: return .hectoPascal
        case .pressure_msl: return .hectoPascal
        case .total_column_integrated_water_vapour: return .kilogramPerSquareMeter
        case .northward_wind_10m: return .ms
        case .eastward_wind_10m: return .ms
        case .specific_humidity_1000hPa: fallthrough
        case .specific_humidity_925hPa: fallthrough
        case .specific_humidity_850hPa: fallthrough
        case .specific_humidity_700hPa: fallthrough
        case .specific_humidity_500hPa: fallthrough
        case .specific_humidity_300hPa: fallthrough
        case .specific_humidity_250hPa: fallthrough
        case .specific_humidity_200hPa: fallthrough
        case .specific_humidity_50hPa: return .gramPerKilogram
        case .temperature_2m: return .celsius
        case .atmosphere_relative_vorticity_1000hPa: fallthrough
        case .atmosphere_relative_vorticity_925hPa: fallthrough
        case .atmosphere_relative_vorticity_850hPa: fallthrough
        case .atmosphere_relative_vorticity_700hPa: fallthrough
        case .atmosphere_relative_vorticity_500hPa: fallthrough
        case .atmosphere_relative_vorticity_300hPa: fallthrough
        case .atmosphere_relative_vorticity_250hPa: fallthrough
        case .atmosphere_relative_vorticity_200hPa: fallthrough
        case .atmosphere_relative_vorticity_50hPa: return .perSecond
        case .divergence_of_wind_1000hPa: fallthrough
        case .divergence_of_wind_925hPa: fallthrough
        case .divergence_of_wind_850hPa: fallthrough
        case .divergence_of_wind_700hPa: fallthrough
        case .divergence_of_wind_500hPa: fallthrough
        case .divergence_of_wind_300hPa: fallthrough
        case .divergence_of_wind_250hPa: fallthrough
        case .divergence_of_wind_200hPa: fallthrough
        case .divergence_of_wind_50hPa: return .perSecond
        }
    }
    
    var level: Int? {
        switch self {
        case .soil_temperature_0_to_7cm: return 0
        case .skin_temperature: return nil
        case .geopotential_height_1000hPa: return 0
        case .geopotential_height_925hPa: return 1
        case .geopotential_height_850hPa: return 2
        case .geopotential_height_700hPa: return 3
        case .geopotential_height_500hPa: return 4
        case .geopotential_height_300hPa: return 5
        case .geopotential_height_250hPa: return 6
        case .geopotential_height_200hPa: return 7
        case .geopotential_height_50hPa: return 0
        case .northward_wind_1000hPa: return 0
        case .northward_wind_925hPa: return 1
        case .northward_wind_850hPa: return 2
        case .northward_wind_700hPa: return 3
        case .northward_wind_500hPa: return 4
        case .northward_wind_300hPa: return 5
        case .northward_wind_250hPa: return 6
        case .northward_wind_200hPa: return 7
        case .northward_wind_50hPa: return 0
        case .eastward_wind_1000hPa: return 0
        case .eastward_wind_925hPa: return 1
        case .eastward_wind_850hPa: return 2
        case .eastward_wind_700hPa: return 3
        case .eastward_wind_500hPa: return 4
        case .eastward_wind_300hPa: return 5
        case .eastward_wind_250hPa: return 6
        case .eastward_wind_200hPa: return 7
        case .eastward_wind_50hPa: return 0
        case .temperature_1000hPa: return 0
        case .temperature_925hPa: return 1
        case .temperature_850hPa: return 2
        case .temperature_700hPa: return 3
        case .temperature_500hPa: return 4
        case .temperature_300hPa: return 5
        case .temperature_250hPa: return 6
        case .temperature_200hPa: return 7
        case .temperature_50hPa: return 0
        case .relative_humidity_1000hPa: return 0
        case .relative_humidity_925hPa: return 1
        case .relative_humidity_850hPa: return 2
        case .relative_humidity_700hPa: return 3
        case .relative_humidity_500hPa: return 4
        case .relative_humidity_300hPa: return 5
        case .relative_humidity_250hPa: return 6
        case .relative_humidity_200hPa: return 7
        case .relative_humidity_50hPa: return 0
        case .surface_air_pressure: return nil
        case .pressure_msl: return nil
        case .total_column_integrated_water_vapour: return nil
        case .northward_wind_10m: return nil
        case .eastward_wind_10m: return nil
        case .specific_humidity_1000hPa: return 0
        case .specific_humidity_925hPa: return 1
        case .specific_humidity_850hPa: return 2
        case .specific_humidity_700hPa: return 3
        case .specific_humidity_500hPa: return 4
        case .specific_humidity_300hPa: return 5
        case .specific_humidity_250hPa: return 6
        case .specific_humidity_200hPa: return 7
        case .specific_humidity_50hPa: return 0
        case .temperature_2m: return nil
        case .atmosphere_relative_vorticity_1000hPa: return 0
        case .atmosphere_relative_vorticity_925hPa: return 1
        case .atmosphere_relative_vorticity_850hPa: return 2
        case .atmosphere_relative_vorticity_700hPa: return 3
        case .atmosphere_relative_vorticity_500hPa: return 4
        case .atmosphere_relative_vorticity_300hPa: return 5
        case .atmosphere_relative_vorticity_250hPa: return 6
        case .atmosphere_relative_vorticity_200hPa: return 7
        case .atmosphere_relative_vorticity_50hPa: return 0
        case .divergence_of_wind_1000hPa: return 0
        case .divergence_of_wind_925hPa: return 1
        case .divergence_of_wind_850hPa: return 2
        case .divergence_of_wind_700hPa: return 3
        case .divergence_of_wind_500hPa: return 4
        case .divergence_of_wind_300hPa: return 5
        case .divergence_of_wind_250hPa: return 6
        case .divergence_of_wind_200hPa: return 7
        case .divergence_of_wind_50hPa: return 0
        }
    }
    
    var gribName: String {
        switch self {
        case .soil_temperature_0_to_7cm: return "st"
        case .skin_temperature: return "skt"
        case .geopotential_height_1000hPa: return "gh"
        case .geopotential_height_925hPa: return "gh"
        case .geopotential_height_850hPa: return "gh"
        case .geopotential_height_700hPa: return "gh"
        case .geopotential_height_500hPa: return "gh"
        case .geopotential_height_300hPa: return "gh"
        case .geopotential_height_250hPa: return "gh"
        case .geopotential_height_200hPa: return "gh"
        case .geopotential_height_50hPa: return "gh"
        case .northward_wind_1000hPa: return "v"
        case .northward_wind_925hPa: return "v"
        case .northward_wind_850hPa: return "v"
        case .northward_wind_700hPa: return "v"
        case .northward_wind_500hPa: return "v"
        case .northward_wind_300hPa: return "v"
        case .northward_wind_250hPa: return "v"
        case .northward_wind_200hPa: return "v"
        case .northward_wind_50hPa: return "v"
        case .eastward_wind_1000hPa: return "u"
        case .eastward_wind_925hPa: return "u"
        case .eastward_wind_850hPa: return "u"
        case .eastward_wind_700hPa: return "u"
        case .eastward_wind_500hPa: return "u"
        case .eastward_wind_300hPa: return "u"
        case .eastward_wind_250hPa: return "u"
        case .eastward_wind_200hPa: return "u"
        case .eastward_wind_50hPa: return "u"
        case .temperature_1000hPa: return "t"
        case .temperature_925hPa: return "t"
        case .temperature_850hPa: return "t"
        case .temperature_700hPa: return "t"
        case .temperature_500hPa: return "t"
        case .temperature_300hPa: return "t"
        case .temperature_250hPa: return "t"
        case .temperature_200hPa: return "t"
        case .temperature_50hPa: return "t"
        case .relative_humidity_1000hPa: return "r"
        case .relative_humidity_925hPa: return "r"
        case .relative_humidity_850hPa: return "r"
        case .relative_humidity_700hPa: return "r"
        case .relative_humidity_500hPa: return "r"
        case .relative_humidity_300hPa: return "r"
        case .relative_humidity_250hPa: return "r"
        case .relative_humidity_200hPa: return "r"
        case .relative_humidity_50hPa: return "r"
        case .surface_air_pressure: return "sp"
        case .pressure_msl: return "msl"
        case .total_column_integrated_water_vapour: return "tciwv"
        case .northward_wind_10m: return "10v"
        case .eastward_wind_10m: return "10u"
        case .specific_humidity_1000hPa: return "q"
        case .specific_humidity_925hPa: return "q"
        case .specific_humidity_850hPa: return "q"
        case .specific_humidity_700hPa: return "q"
        case .specific_humidity_500hPa: return "q"
        case .specific_humidity_300hPa: return "q"
        case .specific_humidity_250hPa: return "q"
        case .specific_humidity_200hPa: return "q"
        case .specific_humidity_50hPa: return "q"
        case .temperature_2m: return "2t"
        case .atmosphere_relative_vorticity_1000hPa: return "vo"
        case .atmosphere_relative_vorticity_925hPa: return "vo"
        case .atmosphere_relative_vorticity_850hPa: return "vo"
        case .atmosphere_relative_vorticity_700hPa: return "vo"
        case .atmosphere_relative_vorticity_500hPa: return "vo"
        case .atmosphere_relative_vorticity_300hPa: return "vo"
        case .atmosphere_relative_vorticity_250hPa: return "vo"
        case .atmosphere_relative_vorticity_200hPa: return "vo"
        case .atmosphere_relative_vorticity_50hPa: return "vo"
        case .divergence_of_wind_1000hPa: return "d"
        case .divergence_of_wind_925hPa: return "d"
        case .divergence_of_wind_850hPa: return "d"
        case .divergence_of_wind_700hPa: return "d"
        case .divergence_of_wind_500hPa: return "d"
        case .divergence_of_wind_300hPa: return "d"
        case .divergence_of_wind_250hPa: return "d"
        case .divergence_of_wind_200hPa: return "d"
        case .divergence_of_wind_50hPa: return "d"
        }
    }
    
    var scalefactor: Float {
        switch self {
            
        case .soil_temperature_0_to_7cm: return 20
        case .skin_temperature: return 20
        case .geopotential_height_1000hPa: fallthrough
        case .geopotential_height_925hPa: fallthrough
        case .geopotential_height_850hPa: fallthrough
        case .geopotential_height_700hPa: fallthrough
        case .geopotential_height_500hPa: fallthrough
        case .geopotential_height_300hPa: fallthrough
        case .geopotential_height_250hPa: fallthrough
        case .geopotential_height_200hPa: fallthrough
        case .geopotential_height_50hPa: return 1
        case .northward_wind_1000hPa: fallthrough
        case .northward_wind_925hPa: fallthrough
        case .northward_wind_850hPa: fallthrough
        case .northward_wind_700hPa: fallthrough
        case .northward_wind_500hPa: fallthrough
        case .northward_wind_300hPa: fallthrough
        case .northward_wind_250hPa: fallthrough
        case .northward_wind_200hPa: fallthrough
        case .northward_wind_50hPa: return 10
        case .eastward_wind_1000hPa: fallthrough
        case .eastward_wind_925hPa: fallthrough
        case .eastward_wind_850hPa: fallthrough
        case .eastward_wind_700hPa: fallthrough
        case .eastward_wind_500hPa: fallthrough
        case .eastward_wind_300hPa: fallthrough
        case .eastward_wind_250hPa: fallthrough
        case .eastward_wind_200hPa: fallthrough
        case .eastward_wind_50hPa: return 10
        case .temperature_1000hPa: fallthrough
        case .temperature_925hPa: fallthrough
        case .temperature_850hPa: fallthrough
        case .temperature_700hPa: fallthrough
        case .temperature_500hPa: fallthrough
        case .temperature_300hPa: fallthrough
        case .temperature_250hPa: fallthrough
        case .temperature_200hPa: fallthrough
        case .temperature_50hPa: return 20
        case .relative_humidity_1000hPa: fallthrough
        case .relative_humidity_925hPa: fallthrough
        case .relative_humidity_850hPa: fallthrough
        case .relative_humidity_700hPa: fallthrough
        case .relative_humidity_500hPa: fallthrough
        case .relative_humidity_300hPa: fallthrough
        case .relative_humidity_250hPa: fallthrough
        case .relative_humidity_200hPa: fallthrough
        case .relative_humidity_50hPa: return 1
        case .surface_air_pressure: return 1
        case .pressure_msl: return 1
        case .total_column_integrated_water_vapour: return 10
        case .northward_wind_10m: return 10
        case .eastward_wind_10m: return 10
        case .specific_humidity_1000hPa: fallthrough
        case .specific_humidity_925hPa: fallthrough
        case .specific_humidity_850hPa: fallthrough
        case .specific_humidity_700hPa: fallthrough
        case .specific_humidity_500hPa: fallthrough
        case .specific_humidity_300hPa: fallthrough
        case .specific_humidity_250hPa: fallthrough
        case .specific_humidity_200hPa: fallthrough
        case .specific_humidity_50hPa: return 100
        case .temperature_2m: return 20
        case .atmosphere_relative_vorticity_1000hPa: fallthrough
        case .atmosphere_relative_vorticity_925hPa: fallthrough
        case .atmosphere_relative_vorticity_850hPa: fallthrough
        case .atmosphere_relative_vorticity_700hPa: fallthrough
        case .atmosphere_relative_vorticity_500hPa: fallthrough
        case .atmosphere_relative_vorticity_300hPa: fallthrough
        case .atmosphere_relative_vorticity_250hPa: fallthrough
        case .atmosphere_relative_vorticity_200hPa: fallthrough
        case .atmosphere_relative_vorticity_50hPa: return 100
        case .divergence_of_wind_1000hPa: fallthrough
        case .divergence_of_wind_925hPa: fallthrough
        case .divergence_of_wind_850hPa: fallthrough
        case .divergence_of_wind_700hPa: fallthrough
        case .divergence_of_wind_500hPa: fallthrough
        case .divergence_of_wind_300hPa: fallthrough
        case .divergence_of_wind_250hPa: fallthrough
        case .divergence_of_wind_200hPa: fallthrough
        case .divergence_of_wind_50hPa: return 100
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .relative_humidity_1000hPa: fallthrough
        case .relative_humidity_925hPa: fallthrough
        case .relative_humidity_850hPa: fallthrough
        case .relative_humidity_700hPa: fallthrough
        case .relative_humidity_500hPa: fallthrough
        case .relative_humidity_300hPa: fallthrough
        case .relative_humidity_250hPa: fallthrough
        case .relative_humidity_200hPa: fallthrough
        case .relative_humidity_50hPa: return .hermite(bounds: 0...100)
        default: return .hermite(bounds: nil)
        }
    }
}

enum EcmwfVariableDerived: String, Codable {
    case windspeed_10m
    case windspeed_1000hPa
    case windspeed_925hPa
    case windspeed_850hPa
    case windspeed_700hPa
    case windspeed_500hPa
    case windspeed_300hPa
    case windspeed_250hPa
    case windspeed_200hPa
    case windspeed_50hPa
    case winddirection_10m
    case winddirection_1000hPa
    case winddirection_925hPa
    case winddirection_850hPa
    case winddirection_700hPa
    case winddirection_500hPa
    case winddirection_300hPa
    case winddirection_250hPa
    case winddirection_200hPa
    case winddirection_50hPa
    case soil_temperature_0_7cm
}
