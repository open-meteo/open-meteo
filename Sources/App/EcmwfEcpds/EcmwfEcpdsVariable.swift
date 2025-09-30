

enum EcmwfEcdpsIfsVariable: String, CaseIterable, GenericVariable {
    case wind_u_component_10m
    case wind_v_component_10m
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_200m
    case wind_v_component_200m
    case cape
    case potential_evapotranspiration
    case convective_inhibition
    case precipitation_type
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case surface_temperature
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case showers
    case visibility
    case roughness_length
    case snow_depth_water_equivalent
    case direct_radiation
    case albedo
    case temperature_2m
    case wind_gusts_10m
    case dew_point_2m
    case pressure_msl
    case k_index
    case runoff
    case temperature_2m_min
    case temperature_2m_max
    case snowfall_water_equivalent
    case shortwave_radiation
    case precipitation
    case total_column_integrated_water_vapour
    
    //case sea_surface_temperature
    //case boundary_layer_height
    //case snow_density

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_200m, .wind_v_component_200m: return 20 // 0.05 m/s resolution. Typically 10, but want to have sligthly higher resolution
        case .cloud_cover: return 1
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .wind_gusts_10m: return 10
        case .dew_point_2m: return 20
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min, .surface_temperature: return 20
        case .pressure_msl: return 0.1 // stored in pascal for historical reasons
        case .snowfall_water_equivalent: return 10
        case .soil_temperature_0_to_7cm: return 20
        case .soil_temperature_7_to_28cm: return 20
        case .soil_temperature_28_to_100cm: return 20
        case .soil_temperature_100_to_255cm: return 20
        case .shortwave_radiation: return 1
        case .precipitation, .runoff, .showers: return 10
        case .direct_radiation: return 1
        case .soil_moisture_0_to_7cm: return 1000
        case .soil_moisture_7_to_28cm: return 1000
        case .soil_moisture_28_to_100cm: return 1000
        case .soil_moisture_100_to_255cm: return 1000
        case .snow_depth_water_equivalent: return 10
        //case .boundary_layer_height: return 0.2 // 5m resolution
        case .total_column_integrated_water_vapour: return 10
        //case .sea_surface_temperature: return 20
        case .cape: return 0.1
        case .potential_evapotranspiration: return 10
        case .convective_inhibition: return 1
        case .precipitation_type: return 1
        case .visibility: return 0.05 // 50 meter
        case .roughness_length: return 1 // CHECK SCALE
        case .albedo: return 1
        case .k_index: return 100
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature:
            return .hermite(bounds: nil)
        case .temperature_2m_max, .temperature_2m_min:
            return .backwards
        case .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_200m, .wind_v_component_200m:
            return .hermite(bounds: nil)
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .dew_point_2m:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .snow_depth_water_equivalent:
            return .linear
        case .soil_temperature_0_to_7cm:
            return .hermite(bounds: nil)
        case .soil_temperature_7_to_28cm:
            return .hermite(bounds: nil)
        case .soil_temperature_28_to_100cm:
            return .hermite(bounds: nil)
        case .soil_temperature_100_to_255cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_7cm:
            return .hermite(bounds: nil)
        case .soil_moisture_7_to_28cm:
            return .hermite(bounds: nil)
        case .soil_moisture_28_to_100cm:
            return .hermite(bounds: nil)
        case .soil_moisture_100_to_255cm:
            return .hermite(bounds: nil)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .precipitation, .runoff, .showers:
            return .backwards_sum
        case .direct_radiation:
            return .solar_backwards_averaged
        //case .boundary_layer_height:
        //    return .hermite(bounds: 0...10e9)
        case .total_column_integrated_water_vapour:
            return .hermite(bounds: nil)
        //case .sea_surface_temperature:
        //    return .hermite(bounds: nil)
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .potential_evapotranspiration:
            return .backwards_sum
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .precipitation_type:
            return .backwards
        case .visibility:
            return .linear
        case .roughness_length:
            return .linear
        case .albedo:
            return .linear
        case .k_index:
            return .linear
        }
    }

    /*var marsGribCode: String {
        switch self {
        case .temperature_2m:
            return "167.128"
        case .wind_u_component_100m:
            return "246.228"
        case .wind_v_component_100m:
            return "247.228"
        case .wind_u_component_10m:
            return "165.128"
        case .wind_v_component_10m:
            return "166.128"
        case .wind_gusts_10m:
            return "49.128"
        case .dew_point_2m:
            return "168.128"
        case .cloud_cover:
            return "164.128"
        case .cloud_cover_low:
            return "186.128"
        case .cloud_cover_mid:
            return "187.128"
        case .cloud_cover_high:
            return "188.128"
        case .pressure_msl:
            return "151.128"
        case .snowfall_water_equivalent:
            return "144.128"
        case .snow_depth_water_equivalent:
            fatalError("Not supported")
        case .soil_temperature_0_to_7cm:
            return "139.128"
        case .soil_temperature_7_to_28cm:
            return "170.128"
        case .soil_temperature_28_to_100cm:
            return "183.128"
        case .soil_temperature_100_to_255cm:
            return "236.128"
        case .soil_moisture_0_to_7cm:
            return "39.128"
        case .soil_moisture_7_to_28cm:
            return "40.128"
        case .soil_moisture_28_to_100cm:
            return "41.128"
        case .soil_moisture_100_to_255cm:
            return "42.128"
        case .shortwave_radiation:
            return "169.128"
        case .precipitation:
            return "228.128"
        case .direct_radiation:
            return "21.228"
        //case .boundary_layer_height:
        //    return "159.128"
        case .total_column_integrated_water_vapour:
            return "137.128"
        //case .sea_surface_temperature:
        //    return "34.128"
        default:
            fatalError("Not supported")
        }
    }*/

    var unit: SiUnit {
        switch self {
        case .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_200m, .wind_v_component_200m, .wind_gusts_10m: return .metrePerSecond
        case .dew_point_2m: return .celsius
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min, .surface_temperature: return .celsius
        case .cloud_cover: return .percentage
        case .cloud_cover_low: return .percentage
        case .cloud_cover_mid: return .percentage
        case .cloud_cover_high: return .percentage
        case .pressure_msl: return .pascal
        case .snowfall_water_equivalent: return .millimetre
        case .soil_temperature_0_to_7cm: return .celsius
        case .soil_temperature_7_to_28cm: return .celsius
        case .soil_temperature_28_to_100cm: return .celsius
        case .soil_temperature_100_to_255cm: return .celsius
        case .shortwave_radiation: return .wattPerSquareMetre
        case .precipitation, .runoff, .showers: return .millimetre
        case .direct_radiation: return .wattPerSquareMetre
        case .soil_moisture_0_to_7cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_7_to_28cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_28_to_100cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_255cm: return .cubicMetrePerCubicMetre
        case .snow_depth_water_equivalent: return .millimetre
        //case .boundary_layer_height: return .metre
        case .total_column_integrated_water_vapour: return .kilogramPerSquareMetre
        //case .sea_surface_temperature: return .celsius
        case .cape: return .joulePerKilogram
        case .potential_evapotranspiration: return .millimetre
        case .convective_inhibition: return .joulePerKilogram
        case .precipitation_type: return .dimensionless
        case .visibility: return .metre
        case .roughness_length: return .metre
        case .albedo: return .percentage
        case .k_index: return .dimensionless
        }
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .dew_point_2m ||
            self == .soil_temperature_0_to_7cm || self == .soil_temperature_7_to_28cm ||
            self == .soil_temperature_28_to_100cm || self == .soil_temperature_100_to_255cm ||
            self == .surface_temperature || self == .temperature_2m_max || self == .temperature_2m_min
    }

    var storePreviousForecast: Bool {
        return false
    }
    
    var gribCode: String {
        switch self {
        case .wind_u_component_10m:
            return "10u"
        case .wind_v_component_10m:
            return "10v"
        case .wind_u_component_100m:
            return "100u"
        case .wind_v_component_100m:
            return "100v"
        case .wind_u_component_200m:
            return "200u"
        case .wind_v_component_200m:
            return "200v"
        case .cape:
            return "mucape"
        case .potential_evapotranspiration:
            return "pev"
        case .convective_inhibition:
            return "mucin"
        case .precipitation_type:
            return "ptype"
        case .soil_temperature_0_to_7cm:
            return "stl1"
        case .soil_temperature_7_to_28cm:
            return "stl2"
        case .soil_temperature_28_to_100cm:
            return "stl3"
        case .soil_temperature_100_to_255cm:
            return "stl4"
        case .soil_moisture_0_to_7cm:
            return "swvl1"
        case .soil_moisture_7_to_28cm:
            return "swvl2"
        case .soil_moisture_28_to_100cm:
            return "swvl3"
        case .soil_moisture_100_to_255cm:
            return "swvl4"
        case .surface_temperature:
            return "skt"
        case .cloud_cover:
            return "tcc"
        case .cloud_cover_low:
            return "lcc"
        case .cloud_cover_mid:
            return "mcc"
        case .cloud_cover_high:
            return "hcc"
        case .showers:
            return "cp"
        case .visibility:
            return "vis"
        case .roughness_length:
            return "fsr"
        case .snow_depth_water_equivalent:
            return "sd"
        case .direct_radiation:
            return "fdir"
        case .albedo:
            return "fal"
        case .temperature_2m:
            return "2t"
        case .wind_gusts_10m:
            return "10fg"
        case .dew_point_2m:
            return "2d"
        case .pressure_msl:
            return "msl"
        case .k_index:
            return "kx"
        case .runoff:
            return "ro"
        case .temperature_2m_min:
            return "mn2t"
        case .temperature_2m_max:
            return "mx2t"
        case .snowfall_water_equivalent:
            return "sf"
        case .shortwave_radiation:
            return "ssrd"
        case .precipitation:
            return "tp"
        case .total_column_integrated_water_vapour:
            return "tcwv"
        }
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .surface_temperature, .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .temperature_2m, .temperature_2m_min, .temperature_2m_max, .dew_point_2m:
            return (1, -273.15)
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return (100, 0)
       // case .pressure_msl: // for historical backwards compatibility reasons, pressure is stored in pascal
            //return (1 / 100, 0)
        case .albedo:
            return (100, 0)
        case .precipitation, .showers, .snowfall_water_equivalent, .runoff, .snow_depth_water_equivalent:
            return (1000, 0) // meters to millimetre
        case .shortwave_radiation, .direct_radiation:
            return (1 / Float(dtSeconds), 0) // joules to watt
        default:
            return nil
        }
    }
}
