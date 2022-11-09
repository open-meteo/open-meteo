import Foundation

/// Represent a ECMWF variable as available in the grib2 files
enum EcmwfVariable: String, CaseIterable, Hashable, Codable, GenericVariable, GenericVariableMixable {
    case precipitation
    case runoff
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
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var unit: SiUnit {
        switch self {
        case .precipitation: fallthrough
        case .runoff: return .millimeter
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
        case .geopotential_height_50hPa: return .meter
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
        case .relative_humidity_50hPa: return .percent
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
    
    /// pressure level in hPa or meter in the grib files
    var level: Int? {
        switch self {
        case .precipitation: fallthrough
        case .runoff: return nil
        case .soil_temperature_0_to_7cm: return 0
        case .skin_temperature: return nil
        case .geopotential_height_1000hPa: return 1000
        case .geopotential_height_925hPa: return 925
        case .geopotential_height_850hPa: return 850
        case .geopotential_height_700hPa: return 700
        case .geopotential_height_500hPa: return 500
        case .geopotential_height_300hPa: return 300
        case .geopotential_height_250hPa: return 250
        case .geopotential_height_200hPa: return 200
        case .geopotential_height_50hPa: return 50
        case .northward_wind_1000hPa: return 1000
        case .northward_wind_925hPa: return 925
        case .northward_wind_850hPa: return 850
        case .northward_wind_700hPa: return 700
        case .northward_wind_500hPa: return 500
        case .northward_wind_300hPa: return 300
        case .northward_wind_250hPa: return 250
        case .northward_wind_200hPa: return 200
        case .northward_wind_50hPa: return 50
        case .eastward_wind_1000hPa: return 1000
        case .eastward_wind_925hPa: return 925
        case .eastward_wind_850hPa: return 850
        case .eastward_wind_700hPa: return 700
        case .eastward_wind_500hPa: return 500
        case .eastward_wind_300hPa: return 300
        case .eastward_wind_250hPa: return 250
        case .eastward_wind_200hPa: return 200
        case .eastward_wind_50hPa: return 50
        case .temperature_1000hPa: return 1000
        case .temperature_925hPa: return 925
        case .temperature_850hPa: return 850
        case .temperature_700hPa: return 700
        case .temperature_500hPa: return 500
        case .temperature_300hPa: return 300
        case .temperature_250hPa: return 250
        case .temperature_200hPa: return 200
        case .temperature_50hPa: return 50
        case .relative_humidity_1000hPa: return 1000
        case .relative_humidity_925hPa: return 925
        case .relative_humidity_850hPa: return 850
        case .relative_humidity_700hPa: return 700
        case .relative_humidity_500hPa: return 500
        case .relative_humidity_300hPa: return 300
        case .relative_humidity_250hPa: return 250
        case .relative_humidity_200hPa: return 200
        case .relative_humidity_50hPa: return 50
        case .surface_air_pressure: return nil
        case .pressure_msl: return nil
        case .total_column_integrated_water_vapour: return nil
        case .northward_wind_10m: return 10
        case .eastward_wind_10m: return 10
        case .specific_humidity_1000hPa: return 1000
        case .specific_humidity_925hPa: return 925
        case .specific_humidity_850hPa: return 850
        case .specific_humidity_700hPa: return 700
        case .specific_humidity_500hPa: return 500
        case .specific_humidity_300hPa: return 300
        case .specific_humidity_250hPa: return 250
        case .specific_humidity_200hPa: return 200
        case .specific_humidity_50hPa: return 50
        case .temperature_2m: return 2
        case .atmosphere_relative_vorticity_1000hPa: return 1000
        case .atmosphere_relative_vorticity_925hPa: return 925
        case .atmosphere_relative_vorticity_850hPa: return 850
        case .atmosphere_relative_vorticity_700hPa: return 700
        case .atmosphere_relative_vorticity_500hPa: return 500
        case .atmosphere_relative_vorticity_300hPa: return 300
        case .atmosphere_relative_vorticity_250hPa: return 250
        case .atmosphere_relative_vorticity_200hPa: return 200
        case .atmosphere_relative_vorticity_50hPa: return 50
        case .divergence_of_wind_1000hPa: return 1000
        case .divergence_of_wind_925hPa: return 925
        case .divergence_of_wind_850hPa: return 850
        case .divergence_of_wind_700hPa: return 700
        case .divergence_of_wind_500hPa: return 500
        case .divergence_of_wind_300hPa: return 300
        case .divergence_of_wind_250hPa: return 250
        case .divergence_of_wind_200hPa: return 200
        case .divergence_of_wind_50hPa: return 50
        }
    }
    
    var gribName: String {
        switch self {
        case .precipitation: return "tp"
        case .runoff: return "ro"
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
        case .precipitation: fallthrough
        case .runoff: return 10
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
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_1000hPa: fallthrough
        case .temperature_925hPa: fallthrough
        case .temperature_850hPa: fallthrough
        case .temperature_700hPa: fallthrough
        case .temperature_500hPa: fallthrough
        case .temperature_300hPa: fallthrough
        case .temperature_250hPa: fallthrough
        case .temperature_200hPa: fallthrough
        case .temperature_50hPa: fallthrough
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 0)
        case .surface_air_pressure:
            return (1/100, 0)
        case .precipitation:
            fallthrough
        case .runoff:
            return (1000, 0) // meters to millimeter
        case .specific_humidity_1000hPa: fallthrough
        case .specific_humidity_925hPa: fallthrough
        case .specific_humidity_850hPa: fallthrough
        case .specific_humidity_700hPa: fallthrough
        case .specific_humidity_500hPa: fallthrough
        case .specific_humidity_300hPa: fallthrough
        case .specific_humidity_250hPa: fallthrough
        case .specific_humidity_200hPa: fallthrough
        case .specific_humidity_50hPa:
            return (1000, 0)
        default:
            return nil
        }
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .runoff: return true
        default: return false
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .runoff: return true
        default: return false
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .precipitation: fallthrough
        case .runoff: return .linear
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

enum EcmwfVariableDerived: String, Codable, GenericVariableMixable {
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
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
