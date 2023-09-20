import Foundation


enum IconPressureVariableType: String, CaseIterable {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case relativehumidity
}

struct IconPressureVariable: PressureVariableRespresentable, Hashable, GenericVariableMixable {
    let variable: IconPressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        (rawValue, 0)
    }
    
    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            // Use scalefactor of 2 for everything higher than 300 hPa
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        //case .cloudcover:
        //    return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(v.level)))
        case .relativehumidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_u_component:
            return .hermite(bounds: nil)
        case .wind_v_component:
            return .hermite(bounds: nil)
        case .geopotential_height:
            return .hermite(bounds: nil)
        case .relativehumidity:
            return .hermite(bounds: 0...100)
        }
    }
    
    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_u_component:
            return .ms
        case .wind_v_component:
            return .ms
        case .geopotential_height:
            return .meter
        //case .cloudcover:
        //    return .percent
        case .relativehumidity:
            return .percent
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
}

/**
 Combined surface and pressure level variables with all definitions for the API
 */
typealias IconVariable = SurfaceAndPressureVariable<IconSurfaceVariable, IconPressureVariable>

/**
 Available variables to download from the DWD open data server
 */
enum IconSurfaceVariable: String, CaseIterable, GenericVariableMixable {
    case temperature_2m
    case cloudcover // cloudcover total
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    
    /// pressure reduced to sea level
    case pressure_msl
    
    /// Total precipitation accumulated sinve model start. First hour is always 0.
    case precipitation

    /// weather interpretation (WMO) https://www.dwd.de/DWD/forschung/nwv/fepub/icon_database_main.pdf page 47
    /// Significant weather of the last hour. The predicted weather will be diagnosed hourly at each model grid point and coded as a key number. The latter is called ww-code and represents weather phenomena within the last hour. The interpretation of such weather phenomena from raw model output relies on an independent post-processing method. This technique applies a number of thresholding processes based on WMO criteria. Therefore, a couple of ww-codes may differ from the direct model output (e.g. ww-category snow vs. SNOW_GSP/SNOW_CON). Due to limitations in temporal and spatial resolution, not all ww-codes as defined by the WMO criteria can be determined. However, the simulated ww-code is able to take the following values: no significant weather/ cloud cover (0, 1, 2, 3), fog (45, 48), drizzle (51, 53, 55, 56, 57), rain (61, 63, 65, 66, 67), solid precip not in showers (71, 73, 75, 77), showery precip (liquid & solid) (80, 81, 82, 85, 86), thunderstorm (95, 96, 99 (only ICON- D2)) (see also Table 7.1).
    case weathercode

    case wind_v_component_10m

    case wind_u_component_10m
    
    case wind_v_component_80m
    case wind_u_component_80m
    case wind_v_component_120m
    case wind_u_component_120m
    case wind_v_component_180m
    case wind_u_component_180m
    
    case temperature_80m
    case temperature_120m
    case temperature_180m
    
    /// Soil temperature
    case soil_temperature_0cm
    case soil_temperature_6cm
    case soil_temperature_18cm
    case soil_temperature_54cm
    
    /// Soil moisture
    /// The model soil moisture data was converted from kg/m2 to m3/m3 by using the formula SM[m3/m3] = SM[kg/m2] * 0.001 * 1/d, where d is the thickness of the soil layer in meters. The factor 0.001 is due to the assumption that 1kg of water represents 1000cm3, which is 0.001m3.
    case soil_moisture_0_1cm
    case soil_moisture_1_3cm
    case soil_moisture_3_9cm
    case soil_moisture_9_27cm
    case soil_moisture_27_81cm
    
    /// snow depth in meters
    case snow_depth
    
    /// Ceiling is that height above MSL (in m), where the large scale cloud coverage (more precise: scale and sub-scale, but without the convective contribution) first exceeds 50% when starting from ground.
    //case ceiling // not in global
    
    /// Sensible heat net flux at surface (average since model start)
    case sensible_heatflux
    
    /// Latent heat net flux at surface (average since model start)
    case latent_heatflux
    
    /// Convective rain in mm
    case showers
    
    /// Large scale rain in mm
    case rain
    
    /// convective snowfall
    case snowfall_convective_water_equivalent
    
    /// largescale snowfall
    case snowfall_water_equivalent
    
    /// Convective available potential energy
    case cape
    //case tke
    
    /// LPI Lightning Potential Index . Only available in icon-d2. Scales form 0 to ~120
    case lightning_potential

    /// vmax has no timstep 0
    /// Maximum wind gust at 10m above ground. It is diagnosed from the turbulence state in the atmospheric boundary layer, including a potential enhancement by the SSO parameterization over mountainous terrain.
    /// In the presence of deep convection, it contains an additional contribution due to convective gusts.
    /// Maxima are collected over hourly intervals on all domains. (Prior to 2015-07-07 maxima were collected over 3-hourly intervals on the global grid.)
    case windgusts_10m
    
    /// Height of snow fall limit above MSL. It is defined as the height where the wet bulb temperature Tw first exceeds 1.3◦C (scanning mode from top to bottom).
    /// If this threshold is never reached within the entire atmospheric column, SNOWLMT is undefined (GRIB2 bitmap). Only icon-eu + d2
    case snowfall_height
    
    /// Height of the 0◦ C isotherm above MSL. In case of multiple 0◦ C isotherms, HZEROCL contains the uppermost one.
    /// If the temperature is below 0◦ C throughout the entire atmospheric column, HZEROCL is set equal to the topography height (fill value).
    case freezinglevel_height
    
    /// Relative humidity on 2 meters
    case relativehumidity_2m
    
    /// Downward solar diffuse radiation flux at the surface, averaged over forecast time.
    case diffuse_radiation
    
    /// Downward solar direct radiation flux at the surface, averaged over forecast time. This quantity is not directly provided by the radiation scheme.
    /// Diffuse + direct it still valid as the total shortwave radiation
    case direct_radiation
    
    /// Maximum updraft within 10 km altitude `W_CTMAX`
    case updraft
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m: return 20
        case .cloudcover: return 1
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .precipitation: return 10
        case .weathercode: return 1
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .wind_v_component_80m: return 10
        case .wind_u_component_80m: return 10
        case .wind_v_component_120m: return 10
        case .wind_u_component_120m: return 10
        case .wind_v_component_180m: return 10
        case .wind_u_component_180m: return 10
        case .soil_temperature_0cm: return 20
        case .soil_temperature_6cm: return 20
        case .soil_temperature_18cm: return 20
        case .soil_temperature_54cm: return 20
        case .soil_moisture_0_1cm: return 1000
        case .soil_moisture_1_3cm: return 1000
        case .soil_moisture_3_9cm: return 1000
        case .soil_moisture_9_27cm: return 1000
        case .soil_moisture_27_81cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .sensible_heatflux: return 0.144
        case .latent_heatflux: return 0.144 // round watts to 7.. results in 0.01 resolution in evpotrans
        case .windgusts_10m: return 10
        case .freezinglevel_height:  return 0.1 // zero height 10 meter resolution
        case .relativehumidity_2m: return 1
        case .diffuse_radiation: return 1
        case .direct_radiation: return 1
        case .showers: return 10
        case .rain: return 10
        case .pressure_msl: return 10
        case .snowfall_convective_water_equivalent: return 10
        case .snowfall_water_equivalent: return 10
        case .temperature_80m:
            fallthrough
        case .temperature_120m:
            fallthrough
        case .temperature_180m:
            return 10
        case .cape:
            return 0.1
        case .lightning_potential:
            return 10
        case .snowfall_height:
            return 0.1
        case .updraft:
            return 100
        }
    }
    
    /// unit stored on disk... or directly read by low level reads
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloudcover: return .percent
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .precipitation: return .millimeter
        case .weathercode: return .wmoCode
        case .wind_v_component_10m: return .ms
        case .wind_u_component_10m: return .ms
        case .wind_v_component_80m: return .ms
        case .wind_u_component_80m: return .ms
        case .wind_v_component_120m: return .ms
        case .wind_u_component_120m: return .ms
        case .wind_v_component_180m: return .ms
        case .wind_u_component_180m: return .ms
        case .soil_temperature_0cm: return .celsius
        case .soil_temperature_6cm: return .celsius
        case .soil_temperature_18cm: return .celsius
        case .soil_temperature_54cm: return .celsius
        case .soil_moisture_0_1cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_1_3cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_3_9cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_9_27cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_27_81cm: return .qubicMeterPerQubicMeter
        case .snow_depth: return .meter
        case .sensible_heatflux: return .wattPerSquareMeter
        case .latent_heatflux: return .wattPerSquareMeter
        case .showers: return .millimeter
        case .rain: return .millimeter
        case .windgusts_10m: return .ms
        case .freezinglevel_height: return .meter
        case .relativehumidity_2m: return .percent
        case .diffuse_radiation: return .wattPerSquareMeter
        case .snowfall_convective_water_equivalent: return .millimeter
        case .snowfall_water_equivalent: return .millimeter
        case .direct_radiation: return .wattPerSquareMeter
        case .pressure_msl: return .hectoPascal
        case .temperature_80m:
            return .celsius
        case .temperature_120m:
            return .celsius
        case .temperature_180m:
            return .celsius
        case .cape:
            return .joulesPerKilogram
        case .lightning_potential:
            return .joulesPerKilogram
        case .snowfall_height:
            return .meter
        case .updraft:
            return .msNotUnitConverted
        }
    }
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_1cm: return true
        case .soil_moisture_1_3cm: return true
        case .soil_moisture_3_9cm: return true
        case .soil_moisture_9_27cm: return true
        case .soil_moisture_27_81cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
    
    /// Name in dwd filenames
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloudcover:
            return .linear
        case .cloudcover_low:
            return .linear
        case .cloudcover_mid:
            return .linear
        case .cloudcover_high:
            return .linear
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .weathercode:
            return .backwards
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .wind_v_component_80m:
            return .hermite(bounds: nil)
        case .wind_u_component_80m:
            return .hermite(bounds: nil)
        case .wind_v_component_120m:
            return .hermite(bounds: nil)
        case .wind_u_component_120m:
            return .hermite(bounds: nil)
        case .wind_v_component_180m:
            return .hermite(bounds: nil)
        case .wind_u_component_180m:
            return .hermite(bounds: nil)
        case .temperature_80m:
            return .hermite(bounds: nil)
        case .temperature_120m:
            return .hermite(bounds: nil)
        case .temperature_180m:
            return .hermite(bounds: nil)
        case .soil_temperature_0cm:
            return .hermite(bounds: nil)
        case .soil_temperature_6cm:
            return .hermite(bounds: nil)
        case .soil_temperature_18cm:
            return .hermite(bounds: nil)
        case .soil_temperature_54cm:
            return .hermite(bounds: nil)
        case .soil_moisture_0_1cm:
            return .hermite(bounds: nil)
        case .soil_moisture_1_3cm:
            return .hermite(bounds: nil)
        case .soil_moisture_3_9cm:
            return .hermite(bounds: nil)
        case .soil_moisture_9_27cm:
            return .hermite(bounds: nil)
        case .soil_moisture_27_81cm:
            return .hermite(bounds: nil)
        case .snow_depth:
            return .linear
        case .sensible_heatflux:
            return .hermite(bounds: nil)
        case .latent_heatflux:
            return .hermite(bounds: nil)
        case .showers:
            return .backwards_sum
        case .rain:
            return .backwards_sum
        case .snowfall_convective_water_equivalent:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .lightning_potential:
            return .linear
        case .windgusts_10m:
            return .linear
        case .snowfall_height:
            return .linear
        case .freezinglevel_height:
            return .linear
        case .relativehumidity_2m:
            return .hermite(bounds: 0...100)
        case .diffuse_radiation:
            return .solar_backwards_averaged
        case .direct_radiation:
            return .solar_backwards_averaged
        case .updraft:
            return .hermite(bounds: nil)
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .temperature_80m ||
            self == .temperature_120m || self == .temperature_180m ||
            self == .soil_temperature_0cm || self == .soil_temperature_6cm ||
            self == .soil_temperature_18cm || self == .soil_temperature_54cm
    }
}
