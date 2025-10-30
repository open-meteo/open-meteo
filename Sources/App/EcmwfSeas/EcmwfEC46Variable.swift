/// 6-hourly variables in O320 grid
/// 10u/10v/100u/100v/2d/2t/msl/200u/200v/cp/sst/sf/stl1/stl2/stl3/stl4/fdir/ssrd/tcc/tp/10fg/sund/mx2t6/mn2t6/swvl1/swvl2/swvl3/swvl4
/// 0/to/1104/by/6
enum EcmwfEC46Variable6Hourly: String, EcmwfSeasVariable, CaseIterable {
    case temperature_2m
    case dew_point_2m
    case pressure_msl
    case sea_surface_temperature
    case wind_u_component_10m
    case wind_v_component_10m
    case snowfall_water_equivalent
    case precipitation
    case shortwave_radiation
    case soil_temperature_0_to_7cm
    case cloud_cover
    
    // Variables above are also in SEAS5
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_200m
    case wind_v_component_200m
    case direct_radiation
    case temperature_2m_max
    case temperature_2m_min
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case showers
    case wind_gusts_10m
    case sunshine_duration
    case wave_direction
    case wave_height
    case wave_period
    case wave_peak_period
    
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
        case .cloud_cover:
            return "tcc"
        case .showers:
            return "cp"
        case .direct_radiation:
            return "fdir"
        case .temperature_2m:
            return "2t"
        case .wind_gusts_10m:
            return "10fg"
        case .dew_point_2m:
            return "2d"
        case .pressure_msl:
            return "msl"
        case .temperature_2m_min:
            return "mn2t6"
        case .temperature_2m_max:
            return "mx2t6"
        case .snowfall_water_equivalent:
            return "sf"
        case .shortwave_radiation:
            return "ssrd"
        case .precipitation:
            return "tp"
        case .sea_surface_temperature:
            return "sst"
        case .sunshine_duration:
            return "sund"
        case .wave_direction:
            return "mwd"
        case .wave_height:
            return "swh" // Significant height of combined wind waves and swell
        case .wave_period:
            return "mwp"
        case .wave_peak_period:
            return "pp1d"
        }
    }
    
    static func from(shortName: String) -> Self? {
        return Self.allCases.first(where: { $0.gribCode == shortName })
    }
    
    var shift24h: Bool {
        return false
    }
    
    var skipHour0: Bool {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return true
        default:
            return isAccumulated
        }
    }
    
    var isAccumulated: Bool {
        switch self {
        case .precipitation, .snowfall_water_equivalent ,.showers:
            return true
        case .shortwave_radiation, .direct_radiation, .sunshine_duration:
            return true
        default:
            return false
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min:
            return 20
        case .dew_point_2m:
            return 20
        case .pressure_msl:
            return 10
        case .sea_surface_temperature:
            return 20
        case .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_200m, .wind_v_component_200m:
            return 10
        case .wind_gusts_10m: return 10
        case .snowfall_water_equivalent:
            return 10
        case .precipitation, .showers:
            return 10
        case .shortwave_radiation:
            return 1
        case .soil_temperature_0_to_7cm: return 20
        case .soil_temperature_7_to_28cm: return 20
        case .soil_temperature_28_to_100cm: return 20
        case .soil_temperature_100_to_255cm: return 20
        case .direct_radiation: return 1
        case .soil_moisture_0_to_7cm: return 1000
        case .soil_moisture_7_to_28cm: return 1000
        case .soil_moisture_28_to_100cm: return 1000
        case .soil_moisture_100_to_255cm: return 1000
        case .cloud_cover:
            return 1
        case .sunshine_duration:
            return 1/60
        case .wave_height:
            return 50 // 0.02m resolution
        case .wave_period, .wave_peak_period:
            return 20 // 0.05s resolution
        case .wave_direction:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m_max, .temperature_2m_min:
            return .backwards
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .dew_point_2m:
            return .hermite(bounds: nil)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .sea_surface_temperature:
            return .hermite(bounds: nil)
        case .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_200m, .wind_v_component_200m, .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .precipitation, .showers:
            return .backwards_sum
        case .shortwave_radiation, .direct_radiation:
            return .solar_backwards_averaged
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
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .sunshine_duration:
            return .backwards
        case .wave_height:
            return .linear
        case .wave_period, .wave_peak_period:
            return .hermite(bounds: 0...Float.infinity)
        case .wave_direction:
            return .linearDegrees
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m, .temperature_2m_max, .temperature_2m_min:
            return .celsius
        case .dew_point_2m:
            return .celsius
        case .pressure_msl:
            return .hectopascal
        case .sea_surface_temperature:
            return .celsius
        case .wind_u_component_100m, .wind_v_component_100m, .wind_u_component_10m, .wind_v_component_10m, .wind_u_component_200m, .wind_v_component_200m, .wind_gusts_10m:
            return .metrePerSecond
        case .snowfall_water_equivalent:
            return .millimetre
        case .precipitation, .showers:
            return .millimetre
        case .shortwave_radiation, .direct_radiation:
            return .wattPerSquareMetre
        case .soil_temperature_0_to_7cm: return .celsius
        case .soil_temperature_7_to_28cm: return .celsius
        case .soil_temperature_28_to_100cm: return .celsius
        case .soil_temperature_100_to_255cm: return .celsius
        case .soil_moisture_0_to_7cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_7_to_28cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_28_to_100cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_255cm: return .cubicMetrePerCubicMetre
        case .cloud_cover:
            return .percentage
        case .sunshine_duration:
            return .seconds
        case .wave_height:
            return .metre
        case .wave_period, .wave_peak_period:
            return .seconds
        case .wave_direction:
            return .degreeDirection
        }
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .sea_surface_temperature, .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .temperature_2m, .temperature_2m_min, .temperature_2m_max, .dew_point_2m:
            return (1, -273.15)
        case .pressure_msl:
            return (1 / 100, 0)
        case .cloud_cover:
            return (100, 0)
        case .shortwave_radiation, .direct_radiation:
            return (1 / (6*3600), 0)
        case .precipitation, .snowfall_water_equivalent, .showers:
            return (1000, 0) // meters to millimeter
        default:
            return nil
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_7cm, .soil_temperature_7_to_28cm, .soil_temperature_28_to_100cm, .soil_temperature_100_to_255cm, .temperature_2m, .temperature_2m_min, .temperature_2m_max, .dew_point_2m: return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
}

/**
 // Weekly means & anomalies
 10 metre U wind component (10u) OK
 10 metre V wind component (10v) OK
 100 metre U wind component (100u) OK
 100 metre V wind component (100v) OK
 2 metre dewpoint temperature (2d) OK
 2 metre temperature (2t) OK
 Geopotential (z) ignore
 Land-sea mask (lsm) ignore
 Maximum temperature at 2 metres in the last 6 hours (mx2t6)
 Maximum temperature at 2 metres since previous post-processing (mx2t)
 Mean sea level pressure (msl) OK
 Mean sunshine duration rate (msdr) OK
 Minimum temperature at 2 metres in the last 6 hours (mn2t6)
 Minimum temperature at 2 metres since previous post-processing (mn2t)
 Most-unstable CAPE (mucape) ignore -> no matching anomaly
 Sea surface temperature (sst) OK
 Snow density (rsn) OK
 Snow depth (sd) OK
 Soil temperature level 1 (stl1) OK
 Time-mean convective precipitation rate (cprate) OK -> missing anomaly
 Time-mean large-scale precipitation rate (mlsprt)
 Time-mean total precipitation rate (tprate) OK
 Time-mean total snowfall rate (mtsfr) OK
 Total cloud cover (tcc) OK
 Total column cloud ice water (tciw) ignore
 Total column cloud liquid water (tclw) ignore
 Total column vertically-integrated water vapour (tcwv) OK
 Total column water (tcw) ignore
 
 10 metre U wind component anomaly (10ua) OK
 10 metre V wind component anomaly (10va) OK
 100 metre U wind component anomaly (100ua) OK
 100 metre V wind component anomaly (100va) OK
 2 metre dewpoint temperature anomaly (2da) OK
 2 metre temperature anomaly (2ta) OK
 Geopotential (z) ignore
 Land-sea mask (lsm) ignore
 Maximum temperature at 2 metres anomaly (mx2ta)
 Maximum temperature at 2 metres in the last 6 hours anomaly (mx2t6a)
 Mean sea level pressure anomaly (msla) OK
 Minimum temperature at 2 metres anomaly (mn2ta)
 Minimum temperature at 2 metres in the last 6 hours anomaly (mn2t6a)
 Sea surface temperature anomaly (ssta) OK
 Snow density anomaly (rsna) OK
 Snow depth anomaly (sda) OK
 Snowfall (convective + stratiform) anomalous rate of accumulation (sfara)  OK
 Soil temperature anomaly level 1 (stal1) OK
 Sunshine duration anomalous rate of accumulation (sundara) OK
 Total cloud cover anomaly (tcca) OK
 Total column ice water anomaly (tciwa) ignore
 Total column liquid water anomaly (tclwa) ignore
 Total column water anomaly (tcwa) ignore
 Total column water vapour anomaly (tcwva) OK
 Total precipitation anomalous rate of accumulation (tpara) OK
 type                = taem,
   param               = 100ua/100va/rsn/rsna/sst/ssta/tclw/tclwa/tciw/tciwa/mx2t6/mx2t6a/mn2t6/mn2t6a/tcw/tcwa/tcwv/tcwva/stl1/stal1/sd/sda/mlsprt/cprate/mtsfr/sfara/msl/msla/tcc/tcca/10u/10ua/10v/10va/2t/2ta/2d/2da/msdr/sundara/mx2t/mx2ta/mn2t/mn2ta/tprate/tpara/100u/100v/avg_mucape,
 
 
 // Probabilities - Weekly accumulated and averaged
 2m temperature anomaly of at least +1K (2tag1)
 2m temperature anomaly of at least +2K (2tag2)
 2m temperature anomaly of at least 0K (2tag0)
 2m temperature anomaly of at most -1K (2talm1)
 2m temperature anomaly of at most -2K (2talm2)
 Mean sea level pressure anomaly of at least 0 Pa (mslag0)
 Surface temperature anomaly of at least 0K (stag0)
 Total precipitation anomaly of at least 0 mm (tpag0)
 Total precipitation anomaly of at least 10 mm (tpag10)
 Total precipitation anomaly of at least 20 mm (tpag20)
 Total precipitation anomaly of at least 0 mm (tpag0)
 Total precipitation anomaly of at least 10 mm (tpag10)
 Total precipitation anomaly of at least 20 mm (tpag20)
 type                = ep,
   param               = 2tag2/2tag1/2tag0/2talm1/2talm2/tpag20/tpag10/tpag0/stag0/mslag0,


 
 // Shift of tails
 2 metre temperature index (2ti): 10:100, 90:100
 Total precipitation index (tpi): 90:100
 type                = sot,
 param               = tpi/2ti,  number              = 90 (-> 90:100)
 param               = 2ti, number              = 10 (-> 10:100)
 
 
 // Extreme Forecast Index (EFI) index -1 to +1
 2 metre temperature index (2ti)
 Total precipitation index (tpi)
 type                = efi,
 param               = tpi/2ti
 */
enum EcmwfEC46VariableWeekly: String, EcmwfSeasVariable, CaseIterable {
    case temperature_2m_anomaly_gt1
    case temperature_2m_anomaly_gt2
    case temperature_2m_anomaly_gt0
    case temperature_2m_anomaly_ltm1
    case temperature_2m_anomaly_ltm2
    case pressure_msl_anomaly_gt0
    case surface_temperature_anomaly_gt0
    case precipitation_anomaly_gt0
    case precipitation_anomaly_gt10
    case precipitation_anomaly_gt20
    
    
    case temperature_2m_sot10
    case temperature_2m_sot90
    case temperature_2m_efi
    
    case precipitation_efi
    case precipitation_sot90
    
    //case wind_gusts_10m_anomaly
    
    //case wind_speed_10m_mean
    //case wind_speed_10m_anomaly
    
    //case albedo_mean
    //case albedo_anomaly
    
    //case cloud_cover_low_mean
    //case cloud_cover_low_anomaly
    
    case showers_mean // OK
    //case showers_anomaly // missing
    
    //case runoff_mean
    //case runoff_anomaly
    
    case snow_density_mean // OK
    case snow_density_anomaly
    case snow_depth_water_equivalent_mean
    case snow_depth_water_equivalent_anomaly
    
    case total_column_integrated_water_vapour_mean // ok
    case total_column_integrated_water_vapour_anomaly
    
    case temperature_2m_mean // OK
    case temperature_2m_anomaly
    
    case dew_point_2m_mean //OK
    case dew_point_2m_anomaly
    
    case pressure_msl_mean // OK
    case pressure_msl_anomaly
    
    case sea_surface_temperature_mean // OK
    case sea_surface_temperature_anomaly
    
    case wind_u_component_10m_mean // OK
    case wind_u_component_10m_anomaly
    case wind_v_component_10m_mean
    case wind_v_component_10m_anomaly
    
    case wind_u_component_100m_mean // OK
    case wind_u_component_100m_anomaly
    case wind_v_component_100m_mean
    case wind_v_component_100m_anomaly
    
    case snowfall_water_equivalent_mean // OK
    case snowfall_water_equivalent_anomaly
    
    case precipitation_mean // OK
    case precipitation_anomaly
    
    //case shortwave_radiation_mean
    //case shortwave_radiation_anomaly
    
    //case longwave_radiation_mean
    //case longwave_radiation_anomaly
    
    case cloud_cover_mean // ok
    case cloud_cover_anomaly
    
    case sunshine_duration_mean // ok
    case sunshine_duration_anomaly
    
    case soil_temperature_0_to_7cm_mean // OK
    case soil_temperature_0_to_7cm_anomaly
    
    /*case soil_temperature_7_to_28cm_mean
    case soil_temperature_7_to_28cm_anomaly
    case soil_temperature_28_to_100cm_mean
    case soil_temperature_28_to_100cm_anomaly
    case soil_temperature_100_to_255cm_mean
    case soil_temperature_100_to_255cm_anomaly
    
    case soil_moisture_0_to_7cm_mean
    case soil_moisture_0_to_7cm_anomaly
    case soil_moisture_7_to_28cm_mean
    case soil_moisture_7_to_28cm_anomaly
    
    case soil_moisture_28_to_100cm_mean
    case soil_moisture_28_to_100cm_anomaly
    
    case soil_moisture_100_to_255cm_mean
    case soil_moisture_100_to_255cm_anomaly*/
    
    // there is a "6h" version and "last post processing" -> both contain exactly the same data
    // a 24h min/max would be way better
    case temperature_max6h_2m_mean
    case temperature_max6h_2m_anomaly
    case temperature_min6h_2m_mean
    case temperature_min6h_2m_anomaly
    
    //case sea_ice_cover_mean
    //case sea_ice_cover_anomaly
    
    //case latent_heat_flux_mean
    //case latent_heat_flux_anomaly
    
    //case sensible_heat_flux_mean
    //case sensible_heat_flux_anomaly
    
    //case evapotranspiration_mean
    //case evapotranspiration_anomaly
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .soil_temperature_0_to_7cm_mean /*, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean*/:
            return (1, -273.15)
        case .temperature_max6h_2m_mean, .temperature_min6h_2m_mean:
            return (1, -273.15)
        case .temperature_2m_mean, .dew_point_2m_mean:
            return (1, -273.15)
        case .pressure_msl_mean, .pressure_msl_anomaly:
            return (1 / 100, 0)
        case .cloud_cover_mean, .cloud_cover_anomaly:
            return (100, 0)
        case .sunshine_duration_mean, .sunshine_duration_anomaly:
            return (Float(dtSeconds),0)
        case .snow_depth_water_equivalent_mean, .snow_depth_water_equivalent_anomaly:
            return (1000, 0) // metre to millimetre
        case .precipitation_mean, .precipitation_anomaly, .showers_mean, /*.showers_anomaly,*/ .snowfall_water_equivalent_mean, .snowfall_water_equivalent_anomaly:
            // Metre per second rate to mm per month
            return (Float(dtSeconds*1000), 0)
        //case .shortwave_radiation_mean:
        //    return (1 / 6*3600, 0)
        default:
            return nil
        }
    }
    
    var isAccumulated: Bool {
        return false
    }
    
    var skipHour0: Bool {
        return false
    }
    
    var shift24h: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .soil_temperature_0_to_7cm_mean:
            return 20
        case .temperature_max6h_2m_mean, .temperature_min6h_2m_mean:
            return 20
        case .sunshine_duration_mean:
            return 1/3600
        case .sunshine_duration_anomaly:
            return 1/60
        case .temperature_2m_mean:
            return 20
        case .dew_point_2m_mean:
            return 20
        case .pressure_msl_mean:
            return 10
        case .sea_surface_temperature_mean:
            return 20
        case .wind_u_component_10m_mean, .wind_v_component_10m_mean, .wind_u_component_100m_mean, .wind_v_component_100m_mean:
            return 10
        case .snowfall_water_equivalent_mean:
            return 10
        case .precipitation_mean:
            return 10
        case .cloud_cover_mean:
            return 10
        case .soil_temperature_0_to_7cm_anomaly:
            return 20
        case .temperature_max6h_2m_anomaly, .temperature_min6h_2m_anomaly, .temperature_2m_anomaly, .dew_point_2m_anomaly:
            return 20
        case .pressure_msl_anomaly:
            return 10
        case .sea_surface_temperature_anomaly:
            return 20
        case .wind_u_component_10m_anomaly, .wind_v_component_10m_anomaly, .wind_u_component_100m_anomaly, .wind_v_component_100m_anomaly:
            return 10
        case .snowfall_water_equivalent_anomaly:
            return 10
        case .precipitation_anomaly:
            return 10
        case .cloud_cover_anomaly:
            return 1
        case .showers_mean:
            return 10
//        case .showers_anomaly:
//            return 10
        case .snow_density_mean:
            return 10
        case .snow_density_anomaly:
            return 10
        case .snow_depth_water_equivalent_mean:
            return 1 // 1 mm water = 0.7 cm snow resolution
        case .snow_depth_water_equivalent_anomaly:
            return 1
        case .total_column_integrated_water_vapour_mean:
            return 10
        case .total_column_integrated_water_vapour_anomaly:
            return 10
        case .temperature_2m_sot10, .temperature_2m_sot90:
            return 20
        case .temperature_2m_efi:
            return 20
        case .precipitation_efi:
            return 10
        case .precipitation_sot90:
            return 10
        case .temperature_2m_anomaly_gt1, .temperature_2m_anomaly_gt2, .temperature_2m_anomaly_gt0, .temperature_2m_anomaly_ltm1, .temperature_2m_anomaly_ltm2:
            return 1 // percent
        case .pressure_msl_anomaly_gt0:
            return 1
        case .surface_temperature_anomaly_gt0:
            return 1
        case .precipitation_anomaly_gt0, .precipitation_anomaly_gt10, .precipitation_anomaly_gt20:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        // Monthly data will not be interpolated
        return .linear
    }
    
    var unit: SiUnit {
        switch self {
        case .soil_temperature_0_to_7cm_mean:
            return .celsius
        case .temperature_max6h_2m_mean, .temperature_min6h_2m_mean:
            return .celsius
        case .sunshine_duration_mean:
            return .seconds
        case .temperature_2m_mean:
            return .celsius
        case .dew_point_2m_mean:
            return .celsius
        case .pressure_msl_mean:
            return .hectopascal
        case .sea_surface_temperature_mean:
            return .celsius
        case .wind_u_component_10m_mean, .wind_v_component_10m_mean, .wind_u_component_100m_mean, .wind_v_component_100m_mean:
            return .metrePerSecond
        case .snowfall_water_equivalent_mean:
            return .millimetre
        case .precipitation_mean:
            return .millimetre
        case .cloud_cover_mean:
            return .percentage
        case .soil_temperature_0_to_7cm_anomaly:
            return .kelvin
        case .temperature_max6h_2m_anomaly, .temperature_min6h_2m_anomaly:
            return .kelvin
        case .sunshine_duration_anomaly:
            return .seconds
        case .temperature_2m_anomaly:
            return .kelvin
        case .dew_point_2m_anomaly:
            return .kelvin
        case .pressure_msl_anomaly:
            return .hectopascal
        case .sea_surface_temperature_anomaly:
            return .kelvin
        case .wind_u_component_10m_anomaly, .wind_v_component_10m_anomaly, .wind_u_component_100m_anomaly, .wind_v_component_100m_anomaly:
            return .metrePerSecond
        case .snowfall_water_equivalent_anomaly:
            return .millimetre
        case .precipitation_anomaly:
            return .millimetre
        case .cloud_cover_anomaly:
            return .percentage
        case .showers_mean:
            return .millimetre
//        case .showers_anomaly:
//            return .millimetre
        case .snow_density_mean:
            return .kilogramPerCubicMetre
        case .snow_density_anomaly:
            return .kilogramPerCubicMetre
        case .snow_depth_water_equivalent_mean:
            return .millimetre
        case .snow_depth_water_equivalent_anomaly:
            return .millimetre
        case .total_column_integrated_water_vapour_mean:
            return .kilogramPerSquareMetre
        case .total_column_integrated_water_vapour_anomaly:
            return .kilogramPerSquareMetre
        case .temperature_2m_sot10, .temperature_2m_sot90:
            return .kelvin
        case .temperature_2m_efi:
            return .dimensionless
        case .precipitation_efi:
            return .millimetre
        case .precipitation_sot90:
            return .dimensionless
        case .temperature_2m_anomaly_gt1, .temperature_2m_anomaly_gt2, .temperature_2m_anomaly_gt0, .temperature_2m_anomaly_ltm1, .temperature_2m_anomaly_ltm2:
            return .percentage
        case .pressure_msl_anomaly_gt0:
            return .percentage
        case .surface_temperature_anomaly_gt0:
            return .percentage
        case .precipitation_anomaly_gt0, .precipitation_anomaly_gt10, .precipitation_anomaly_gt20:
            return .percentage
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_7cm_mean:
            return true
        case .temperature_max6h_2m_mean, .temperature_min6h_2m_mean:
            return true
        case .temperature_2m_mean, .dew_point_2m_mean: return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    
    static func from(shortName: String, number: Int?) -> Self? {
        switch shortName {
        case "cprate":
            return .showers_mean
//        case "mcpra":
//            return .showers_anomaly
        case "rsn":
            return .snow_density_mean
        case "rsna":
            return .snow_density_anomaly
        case "sd":
            return .snow_depth_water_equivalent_mean
        case "sda":
            return .snow_depth_water_equivalent_anomaly
        case "stl1":
            return .soil_temperature_0_to_7cm_mean
        case "msdr":
            return .sunshine_duration_mean
        case "10u":
            return .wind_u_component_10m_mean
        case "10v":
            return .wind_v_component_10m_mean
        case "100u":
            return .wind_u_component_100m_mean
        case "100v":
            return .wind_v_component_100m_mean
        case "2d":
            return .dew_point_2m_mean
        case "2t":
            return .temperature_2m_mean
        case "msl":
            return .pressure_msl_mean
        case "mtsfr":
            return .snowfall_water_equivalent_mean
        case "tcc":
            return .cloud_cover_mean
        case "tprate":
            return .precipitation_mean
        case "mn2t":
            return .temperature_min6h_2m_mean
        case "mx2t":
            return .temperature_max6h_2m_mean
        case "stal1":
            return .soil_temperature_0_to_7cm_anomaly
        case "sundara":
            return .sunshine_duration_anomaly
        case "10ua":
            return .wind_u_component_10m_anomaly
        case "10va":
            return .wind_v_component_10m_anomaly
        case "100ua":
            return .wind_u_component_100m_anomaly
        case "100va":
            return .wind_v_component_100m_anomaly
        case "2da":
            return .dew_point_2m_anomaly
        case "2ta":
            return .temperature_2m_anomaly
        case "msla":
            return .pressure_msl_anomaly
        case "sfara":
            return .snowfall_water_equivalent_anomaly
        case "tcca":
            return .cloud_cover_anomaly
        case "tpara":
            return .precipitation_anomaly
        case "mn2ta":
            return .temperature_min6h_2m_anomaly
        case "mx2ta":
            return .temperature_max6h_2m_anomaly
        case "tcwv":
            return .total_column_integrated_water_vapour_mean
        case "tcwva":
            return .total_column_integrated_water_vapour_anomaly
        case "sst":
            return .sea_surface_temperature_mean
        case "ssta":
            return .sea_surface_temperature_anomaly
        case "tpi":
            switch number {
            case 90:
                return .precipitation_sot90
            default:
                return .precipitation_efi
            }
        case "2ti":
            switch number {
            case 10:
                return .temperature_2m_sot10
            case 90:
                return .temperature_2m_sot90
            default:
                return .temperature_2m_efi
            }
        case "2tag1":
            return .temperature_2m_anomaly_gt1
        case "2tag2":
            return .temperature_2m_anomaly_gt2
        case "2tag0":
            return .temperature_2m_anomaly_gt0
        case "2talm1":
            return .temperature_2m_anomaly_ltm1
        case "2talm2":
            return .temperature_2m_anomaly_ltm2
        case "mslag0":
            return .pressure_msl_anomaly_gt0
        case "stag0":
            return .surface_temperature_anomaly_gt0
        case "tpag0":
            return .precipitation_anomaly_gt0
        case "tpag10":
            return .precipitation_anomaly_gt10
        case "tpag20":
            return .precipitation_anomaly_gt20
        default:
            return nil
        }
    }
}
