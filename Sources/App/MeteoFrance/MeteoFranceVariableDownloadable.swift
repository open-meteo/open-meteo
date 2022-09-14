
/// Required additions to a MeteoFrance variable to make it downloadable
protocol MeteoFranceVariableDownloadable: GenericVariableMixing {
    var skipHour0: Bool { get }
    var interpolationType: Interpolation2StepType { get }
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    var isAveragedOverForecastTime: Bool { get }
    var isAccumulatedSinceModelStart: Bool { get }
}

extension MeteoFranceSurfaceVariable: MeteoFranceVariableDownloadable {
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        case .showers: return true
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
        default: return false
        }
    }
    
    var interpolationType: Interpolation2StepType {
        switch self {
        case .temperature_2m: return .hermite(bounds: nil)
        case .cloudcover: return .hermite(bounds: 0...100)
        case .cloudcover_low: return .hermite(bounds: 0...100)
        case .cloudcover_mid: return .hermite(bounds: 0...100)
        case .cloudcover_high: return .hermite(bounds: 0...100)
        case .relativehumidity_2m: return .hermite(bounds: 0...100)
        case .precipitation: return .linear
        case .wind_v_component_10m: return .hermite(bounds: nil)
        case .wind_u_component_10m: return .hermite(bounds: nil)
        case .snow_depth: return .linear
        case .sensible_heatflux: return .hermite_backwards_averaged(bounds: nil)
        case .latent_heatflux: return .hermite_backwards_averaged(bounds: nil)
        case .windgusts_10m: return .linear
        case .freezinglevel_height: return .hermite(bounds: nil)
        case .shortwave_radiation: return .solar_backwards_averaged
        case .soil_temperature_0_to_10cm: return .hermite(bounds: nil)
        case .soil_temperature_10_to_40cm: return .hermite(bounds: nil)
        case .soil_temperature_40_to_100cm: return .hermite(bounds: nil)
        case .soil_temperature_100_to_200cm: return .hermite(bounds: nil)
        case .soil_moisture_0_to_10cm: return .hermite(bounds: nil)
        case .soil_moisture_10_to_40cm: return .hermite(bounds: nil)
        case .soil_moisture_40_to_100cm: return .hermite(bounds: nil)
        case .soil_moisture_100_to_200cm: return .hermite(bounds: nil)
        case .wind_v_component_80m: return .hermite(bounds: nil)
        case .wind_u_component_80m: return .hermite(bounds: nil)
        case .showers: return .linear
        case .pressure_msl: return .hermite(bounds: nil)
        case .frozen_precipitation_percent: return .nearest
        case .diffuse_radiation: return .solar_backwards_averaged
        case .cape: return .hermite(bounds: nil)
        case .lifted_index: return .hermite(bounds: nil)
        case .visibility: return .hermite(bounds: nil)
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1/100, 1)
        case .soil_temperature_0_to_10cm:
            return (1, -273.15)
        case .soil_temperature_10_to_40cm:
            return (1, -273.15)
        case .soil_temperature_40_to_100cm:
            return (1, -273.15)
        case .soil_temperature_100_to_200cm:
            return (1, -273.15)
        default:
            return nil
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        switch self {
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        default: return false
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .showers: return true
        default: return false
        }
    }
}

extension MeteoFrancePressureVariable: MeteoFranceVariableDownloadable {
    var skipHour0: Bool {
        return false
    }
    
    var interpolationType: Interpolation2StepType {
        switch variable {
        case .cloudcover: fallthrough
        case .relativehumidity: return .hermite(bounds: 0...100)
        default: return .hermite(bounds: nil)
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        default:
            return nil
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        return false
    }
    
    var isAccumulatedSinceModelStart: Bool {
        return false
    }
}
