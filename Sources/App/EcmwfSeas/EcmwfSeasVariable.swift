protocol EcmwfSeasVariable: GenericVariable, Hashable {
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)?
    var isAccumulated: Bool { get }
    var shift24h: Bool { get }
}

/// Used to type erase and make EcmwfSeasVariable hashable
struct EcmwfSeasVariableAny: Hashable {
    let variable: any EcmwfSeasVariable
    
    static func == (lhs: EcmwfSeasVariableAny, rhs: EcmwfSeasVariableAny) -> Bool {
        lhs.hashValue == rhs.hashValue
    }
    
    var hashValue: Int {
        return variable.hashValue
    }
    
    func hash(into hasher: inout Hasher) {
        variable.hash(into: &hasher)
    }
}

/// 6-hourly variables in O320 grid
/// 10U/10V/2D/2T/MSL/SF/SSRD/SST/STL1/TCC/TP
enum EcmwfSeasVariableSingleLevel: String, EcmwfSeasVariable {
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
    
    static func from(shortName: String) -> Self? {
        switch shortName {
        case "10u":
            return .wind_u_component_10m
        case "10v":
            return .wind_v_component_10m
        case "2d":
            return .dew_point_2m
        case "2t":
            return .temperature_2m
        case "msl":
            return .pressure_msl
        case "sf":
            return .snowfall_water_equivalent
        case "ssrd":
            return .shortwave_radiation
        case "stl1":
            return .soil_temperature_0_to_7cm
        case "tcc":
            return .cloud_cover
        case "tp":
            return .precipitation
        case "sst":
            return .sea_surface_temperature
        default:
            return nil
        }
    }
    
    var shift24h: Bool {
        return false
    }
    
    var isAccumulated: Bool {
        switch self {
        case .precipitation, .snowfall_water_equivalent:
            return true
        case .shortwave_radiation:
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
        case .temperature_2m:
            return 20
        case .dew_point_2m:
            return 20
        case .pressure_msl:
            return 10
        case .sea_surface_temperature:
            return 20
        case .wind_u_component_10m, .wind_v_component_10m:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .precipitation:
            return 10
        case .shortwave_radiation:
            return 1
        case .soil_temperature_0_to_7cm:
            return 20
        case .cloud_cover:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .dew_point_2m:
            return .hermite(bounds: nil)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .sea_surface_temperature:
            return .hermite(bounds: nil)
        case .wind_u_component_10m, .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .precipitation:
            return .backwards_sum
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .soil_temperature_0_to_7cm:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .dew_point_2m:
            return .celsius
        case .pressure_msl:
            return .hectopascal
        case .sea_surface_temperature:
            return .celsius
        case .wind_u_component_10m, .wind_v_component_10m:
            return .metrePerSecond
        case .snowfall_water_equivalent:
            return .millimetre
        case .precipitation:
            return .millimetre
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .soil_temperature_0_to_7cm:
            return .celsius
        case .cloud_cover:
            return .percentage
        }
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m, .dew_point_2m, .soil_temperature_0_to_7cm, .sea_surface_temperature:
            return (1, -273.15)
        case .pressure_msl:
            return (1 / 100, 0)
        case .cloud_cover:
            return (100, 0)
        case .shortwave_radiation:
            return (1 / (6*3600), 0)
        case .precipitation, .snowfall_water_equivalent:
            return (1000, 0) // meters to millimeter
        default:
            return nil
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m, .dew_point_2m, .soil_temperature_0_to_7cm: return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
}

/// 24 hourly variables in O320 grid
/// STL1/STL2/STL3/STL4/SUND/SWVL1/SWVL2/SWVL3/SWVL4
/// MEAN2T24/MN2T24/MX2T24
enum EcmwfSeasVariable24HourlySingleLevel: String, EcmwfSeasVariable, Equatable {
    // TODO correct timeshift for t2 and sun while downloading
    // TODO rename variables to correct daily
    
    case soil_temperature_0_to_7cm_mean
    case soil_temperature_7_to_28cm_mean
    case soil_temperature_28_to_100cm_mean
    case soil_temperature_100_to_255cm_mean
    
    case soil_moisture_0_to_7cm_mean
    case soil_moisture_7_to_28cm_mean
    case soil_moisture_28_to_100cm_mean
    case soil_moisture_100_to_255cm_mean
    
    case temperature_2m_max
    case temperature_2m_min
    case temperature_2m_mean
    
    case sunshine_duration
    
    static func from(shortName: String) -> Self? {
        switch shortName {
        case "stl1":
            return .soil_temperature_0_to_7cm_mean
        case "stl2":
            return .soil_temperature_7_to_28cm_mean
        case "stl3":
            return .soil_temperature_28_to_100cm_mean
        case "stl4":
            return .soil_temperature_100_to_255cm_mean
        case "sund":
            return .sunshine_duration
        case "swvl1":
            return .soil_moisture_0_to_7cm_mean
        case "swvl2":
            return .soil_moisture_7_to_28cm_mean
        case "swvl3":
            return .soil_moisture_28_to_100cm_mean
        case "swvl4":
            return .soil_moisture_100_to_255cm_mean
        case "mean2t24":
            return .temperature_2m_mean
        case "mn2t24":
            return .temperature_2m_min
        case "mx2t24":
            return .temperature_2m_max
        default:
            return nil
        }
    }
    
    var shift24h: Bool {
        switch self {
        case .temperature_2m_max, .temperature_2m_min, .temperature_2m_mean:
            return true
        case .sunshine_duration:
            return true
        default:
            return false
        }
    }
    
    var isAccumulated: Bool {
        switch self {
        case .sunshine_duration:
            return true
        default:
            return false
        }
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return (1, -273.15)
        case .temperature_2m_max, .temperature_2m_min, .temperature_2m_mean:
            return (1, -273.15)
        default:
            return nil
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return 20
        case .soil_moisture_0_to_7cm_mean, .soil_moisture_7_to_28cm_mean, .soil_moisture_28_to_100cm_mean, .soil_moisture_100_to_255cm_mean:
            return 1000
        case .temperature_2m_max, .temperature_2m_min, .temperature_2m_mean:
            return 20
        case .sunshine_duration:
            return 1/60
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return .hermite(bounds: nil)
        case .soil_moisture_0_to_7cm_mean, .soil_moisture_7_to_28cm_mean, .soil_moisture_28_to_100cm_mean, .soil_moisture_100_to_255cm_mean:
            return .hermite(bounds: nil)
        case .temperature_2m_max, .temperature_2m_min, .temperature_2m_mean:
            return .backwards
        case .sunshine_duration:
            return .backwards
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return .celsius
        case .soil_moisture_0_to_7cm_mean, .soil_moisture_7_to_28cm_mean, .soil_moisture_28_to_100cm_mean, .soil_moisture_100_to_255cm_mean:
            return .cubicMetrePerCubicMetre
        case .temperature_2m_max, .temperature_2m_min, .temperature_2m_mean:
            return .celsius
        case .sunshine_duration:
            return .seconds
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return true
        case .temperature_2m_max, .temperature_2m_min, .temperature_2m_mean:
            return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
}

/// Only available as 12-hourly data in N160 grid
/// Model levels 85/87/89 https://confluence.ecmwf.int/display/UDOC/L91+model+level+definitions
/// 85=309.04m, 87=167.39m, 89=67.88m
enum EcmwfSeasVariableUpperLevel: String, EcmwfSeasVariable {
    case temperature_1000hPa
    case temperature_850hPa
    case temperature_500hPa
    case geopotential_height_1000hPa
    case geopotential_height_850hPa
    case geopotential_height_500hPa
    
    case relative_humidity_70m
    case relative_humidity_170m
    case relative_humidity_310m
    case temperature_70m
    case temperature_170m
    case temperature_310m
    case wind_u_component_70m
    case wind_u_component_170m
    case wind_u_component_310m
    case wind_v_component_70m
    case wind_v_component_170m
    case wind_v_component_310m
    
    static func from(shortName: String, level: String) -> Self? {
        switch (shortName, level) {
        case ("t", "1000"):
            return .temperature_1000hPa
        case ("t", "850"):
            return .temperature_850hPa
        case ("t", "500"):
            return .temperature_500hPa
        case ("gh", "1000"):
            return .geopotential_height_1000hPa
        case ("gh", "850"):
            return .geopotential_height_850hPa
        case ("gh", "500"):
            return .geopotential_height_500hPa
        case ("t", "85"):
            return .temperature_310m
        case ("t", "87"):
            return .temperature_170m
        case ("t", "89"):
            return .temperature_70m
        case ("q", "85"):
            return .relative_humidity_310m
        case ("q", "87"):
            return .relative_humidity_170m
        case ("q", "89"):
            return .relative_humidity_70m
        case ("u", "85"):
            return .wind_u_component_310m
        case ("u", "87"):
            return .wind_u_component_170m
        case ("u", "89"):
            return .wind_u_component_70m
        case ("v", "85"):
            return .wind_v_component_310m
        case ("v", "87"):
            return .wind_v_component_170m
        case ("v", "89"):
            return .wind_v_component_70m
        default:
            return nil
        }
    }
    
    var isAccumulated: Bool {
        return false
    }
    
    var shift24h: Bool {
        return false
    }
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .temperature_1000hPa, .temperature_850hPa, .temperature_500hPa:
            return (1, -273.15)
        case .geopotential_height_1000hPa, .geopotential_height_500hPa, .geopotential_height_850hPa:
            return (1 / 9.80665, 0)
        default:
            return nil
        }
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_1000hPa, .temperature_850hPa, .temperature_500hPa:
            return 20
        case .geopotential_height_1000hPa, .geopotential_height_500hPa, .geopotential_height_850hPa:
            return 1
        case .relative_humidity_70m, .relative_humidity_170m, .relative_humidity_310m:
            return 1
        case .temperature_70m, .temperature_170m, .temperature_310m:
            return 20
        case .wind_u_component_70m, .wind_u_component_170m, .wind_u_component_310m:
            return 10
        case .wind_v_component_70m, .wind_v_component_170m, .wind_v_component_310m:
            return 10
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_1000hPa, .temperature_850hPa, .temperature_500hPa:
            return .hermite(bounds: nil)
        case .geopotential_height_1000hPa, .geopotential_height_500hPa, .geopotential_height_850hPa:
            return .hermite(bounds: nil)
        case .relative_humidity_70m, .relative_humidity_170m, .relative_humidity_310m:
            return .hermite(bounds: 0...100)
        case .temperature_70m, .temperature_170m, .temperature_310m:
            return .hermite(bounds: nil)
        case .wind_u_component_70m, .wind_u_component_170m, .wind_u_component_310m:
            return .hermite(bounds: nil)
        case .wind_v_component_70m, .wind_v_component_170m, .wind_v_component_310m:
            return .hermite(bounds: nil)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_1000hPa, .temperature_850hPa, .temperature_500hPa:
            return .celsius
        case .geopotential_height_1000hPa, .geopotential_height_500hPa, .geopotential_height_850hPa:
            return .metre
        case .relative_humidity_70m, .relative_humidity_170m, .relative_humidity_310m:
            return .celsius
        case .temperature_70m, .temperature_170m, .temperature_310m:
            return .celsius
        case .wind_u_component_70m, .wind_u_component_170m, .wind_u_component_310m:
            return .metrePerSecond
        case .wind_v_component_70m, .wind_v_component_170m, .wind_v_component_310m:
            return .metrePerSecond
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var storePreviousForecast: Bool {
        return false
    }
}

/**
 10 metre U wind component (10u)
 10 metre V wind component (10v)
 10 metre wind speed (10si)
 2 metre dewpoint temperature (2d)
 2 metre temperature (2t)
 Forecast albedo (fal)
 Geopotential (z)
 Instantaneous eastward turbulent surface stress (iews)
 Instantaneous northward turbulent surface stress (inss)
 Lake ice total depth (licd)
 Lake mix-layer temperature (lmlt)
 Land-sea mask (lsm)
 Low cloud cover (lcc)
 Maximum temperature at 2 metres in the last 24 hours (mx2t24)
 Mean sea level pressure (msl)
 Mean sunshine duration rate (msdr)
 Minimum temperature at 2 metres in the last 24 hours (mn2t24)
 Sea ice area fraction (ci)
 Sea surface temperature (sst)
 Snow density (rsn)
 Snow depth (sd)
 Soil temperature level 1 (stl1)
 Soil temperature level 2 (stl2)
 Soil temperature level 3 (stl3)
 Soil temperature level 4 (stl4)
 Time-mean convective precipitation rate (cprate)
 Time-mean eastward turbulent surface stress (ewssra)
 Time-mean evaporation rate (erate)
 Time-mean large-scale precipitation rate (mlsprt)
 Time-mean northward turbulent surface stress (nsssra)
 Time-mean runoff rate (mrort)
 Time-mean short-wave (solar) insolation rate (soira)
 Time-mean sub-surface runoff rate (mssror)
 Time-mean surface downward long-wave (thermal) radiation flux (msdtrf)
 Time-mean surface downward short-wave (solar) radiation flux (msdsrf)
 Time-mean surface latent heat flux (mslhfl)
 Time-mean surface net long-wave (thermal) radiation flux (msntrf)
 Time-mean surface net short-wave (solar) radiation flux (msnsrf)
 Time-mean surface runoff rate (msror)
 Time-mean surface sensible heat flux (msshfl)
 Time-mean top net long-wave (thermal) radiation flux (mtntrf)
 Time-mean top net short-wave (solar) radiation flux (mtnsrf)
 Time-mean total precipitation rate (tprate)
 Time-mean total snowfall rate (mtsfr)
 Total cloud cover (tcc)
 Total column cloud ice water (tciw)
 Total column cloud liquid water (tclw)
 Total column ozone (tco3)
 Total column vertically-integrated water vapour (tcwv)
 Volumetric soil water layer 1 (swvl1)
 Volumetric soil water layer 2 (swvl2)
 Volumetric soil water layer 3 (swvl3)
 Volumetric soil water layer 4 (swvl4)
 
 10 metre U wind component anomaly (10ua)
 10 metre V wind component anomaly (10va)
 10 metre wind gust anomaly (10fga)
 10 metre wind speed anomaly (10sia)
 2 metre dewpoint temperature anomaly (2da)
 2 metre temperature anomaly (2ta)
 East-West surface stress anomalous rate of accumulation (ewssara)
 Forecast albedo anomaly (fala)
 Instantaneous X surface stress anomaly (iewsa)
 Instantaneous Y surface stress anomaly (inssa)
 Lake ice depth anomaly (licda)
 Lake mix-layer temperature anomaly (lmlta)
 Land-sea mask (lsm)
 Low cloud cover anomaly (lcca)
 Maximum 2 metre temperature in the last 24 hours anomaly (mx2t24a)
 Mean convective precipitation rate anomaly (mcpra)
 Mean sea level pressure anomaly (msla)
 Mean sub-surface runoff rate anomaly (mssrora)
 Mean surface runoff rate anomaly (msrora)
 Minimum 2 metre temperature in the last 24 hours anomaly (mn2t24a)
 North-South surface stress anomalous rate of accumulation (nsssara)
 Runoff anomalous rate of accumulation (roara)
 Sea surface temperature anomaly (ssta)
 Sea-ice cover anomaly (sica)
 Snow density anomaly (rsna)
 Snow depth anomaly (sda)
 Snowfall (convective + stratiform) anomalous rate of accumulation (sfara)
 Soil temperature anomaly level 1 (stal1)
 Soil temperature anomaly level 2 (stal2)
 Soil temperature anomaly level 3 (stal3)
 Soil temperature level 4 anomaly (stal4)
 Solar insolation anomalous rate of accumulation (soiara)
 Stratiform precipitation (Large-scale precipitation) anomalous rate of accumulation (lspara)
 Sunshine duration anomalous rate of accumulation (sundara)
 Surface latent heat flux anomalous rate of accumulation (slhfara)
 Surface sensible heat flux anomalous rate of accumulation (sshfara)
 Surface solar radiation anomalous rate of accumulation (ssrara)
 Surface solar radiation downwards anomalous rate of accumulation (ssrdara)
 Surface thermal radiation anomalous rate of accumulation (strara)
 Surface thermal radiation downwards anomalous rate of accumulation (strdara)
 Time-mean evaporation anomalous rate of accumulation (evara)
 Top solar radiation anomalous rate of accumulation (tsrara)
 Top thermal radiation anomalous rate of accumulation (ttrara)
 Total cloud cover anomaly (tcca)
 Total column ice water anomaly (tciwa)
 Total column liquid water anomaly (tclwa)
 Total column ozone anomaly (tco3a)
 Total column water vapour anomaly (tcwva)
 Total precipitation anomalous rate of accumulation (tpara)
 Volumetric soil water anomaly layer 1 (swval1)
 Volumetric soil water anomaly layer 2 (swval2)
 Volumetric soil water anomaly layer 3 (swval3)
 Volumetric soil water anomaly layer 4 (swval4)

 10SI/10U/10V/2D/2T/CI/CPRATE/ERATE/EWSSRA/FAL/IEWS/INSS/LCC/LICD/LMLT/MLSPRT/MN2T24/MRORT/MSDR/MSDSRF/MSDTRF/MSL/MSLHFL/MSNSRF/MSNTRF/MSROR/MSSHFL/MSSROR/MTNSRF/MTNTRF/MTSFR/MX2T24/NSSSRA/RSN/SD/SOIRA/SST/STL1/STL2/STL3/STL4/SWVL1/SWVL2/SWVL3/SWVL4/TCC/TCIW/TCLW/TCO3/TCWV/TPRATE
 
 10FGA/10SIA/10UA/10VA/2DA/2TA/EVARA/EWSSARA/FALA/IEWSA/INSSA/LCCA/LICDA/LMLTA/LSPARA/MCPRA/MN2T24A/MSLA/MSRORA/MSSRORA/MX2T24A/NSSSARA/ROARA/RSNA/SDA/SFARA/SICA/SLHFARA/SOIARA/SSHFARA/SSRARA/SSRDARA/SSTA/STAL1/STAL2/STAL3/STAL4/STRARA/STRDARA/SUNDARA/SWVAL1/SWVAL2/SWVAL3/SWVAL4/TCCA/TCIWA/TCLWA/TCO3A/TCWVA/TPARA/TSRARA/TTRARA
 */
enum EcmwfSeasVariableMonthly: String, EcmwfSeasVariable {
    case wind_gusts_10m_anomaly
    
    case wind_speed_10m_mean
    case wind_speed_10m_anomaly
    
    case albedo_mean
    case albedo_anomaly
    
    case cloud_cover_low_mean
    case cloud_cover_low_anomaly
    
    case showers_mean
    case showers_anomaly
    
    case runoff_mean
    case runoff_anomaly
    
    case snow_density_mean
    case snow_density_anomaly
    case snow_depth_water_equivalent_mean
    case snow_depth_water_equivalent_anomaly
    
    case total_column_integrated_water_vapour_mean
    case total_column_integrated_water_vapour_anomaly
    
    case temperature_2m_mean
    case temperature_2m_anomaly
    
    case dew_point_2m_mean
    case dew_point_2m_anomaly
    
    case pressure_msl_mean
    case pressure_msl_anomaly
    
    case sea_surface_temperature_mean
    case sea_surface_temperature_anomaly
    
    case wind_u_component_10m_mean
    case wind_u_component_10m_anomaly
    
    case wind_v_component_10m_mean
    case wind_v_component_10m_anomaly
    
    case snowfall_water_equivalent_mean
    case snowfall_water_equivalent_anomaly
    
    case precipitation_mean
    case precipitation_anomaly
    
    case shortwave_radiation_mean
    case shortwave_radiation_anomaly
    
    case longwave_radiation_mean
    case longwave_radiation_anomaly
    
    case cloud_cover_mean
    case cloud_cover_anomaly
    
    case sunshine_duration_mean
    case sunshine_duration_anomaly
    
    case soil_temperature_0_to_7cm_mean
    case soil_temperature_0_to_7cm_anomaly
    case soil_temperature_7_to_28cm_mean
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
    case soil_moisture_100_to_255cm_anomaly
    
    case temperature_max24h_2m_mean
    case temperature_max24h_2m_anomaly
    case temperature_min24h_2m_mean
    case temperature_min24h_2m_anomaly
    
    case sea_ice_cover_mean
    case sea_ice_cover_anomaly
    
    case latent_heat_flux_mean
    case latent_heat_flux_anomaly
    
    case sensible_heat_flux_mean
    case sensible_heat_flux_anomaly
    
    case evapotranspiration_mean
    case evapotranspiration_anomaly
    
    func multiplyAdd(dtSeconds: Int) -> (multiply: Float, add: Float)? {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return (1, -273.15)
        case .temperature_max24h_2m_mean, .temperature_min24h_2m_mean:
            return (1, -273.15)
        case .temperature_2m_mean, .dew_point_2m_mean:
            return (1, -273.15)
        case .pressure_msl_mean, .pressure_msl_anomaly:
            return (1 / 100, 0)
        case .cloud_cover_mean, .cloud_cover_low_mean, .cloud_cover_anomaly, .cloud_cover_low_anomaly:
            return (100, 0)
        case .sunshine_duration_mean, .sunshine_duration_anomaly:
            return (Float(dtSeconds),0)
        case .snow_depth_water_equivalent_mean, .snow_depth_water_equivalent_anomaly:
            return (1000, 0) // metre to millimetre
        case .shortwave_radiation_mean, .shortwave_radiation_anomaly, .longwave_radiation_mean, .longwave_radiation_anomaly, .latent_heat_flux_mean, .latent_heat_flux_anomaly, .sensible_heat_flux_mean, .sensible_heat_flux_anomaly:
            return ((Float(dtSeconds)/1000000), 0)
        case .precipitation_mean, .precipitation_anomaly, .showers_mean, .showers_anomaly, .snowfall_water_equivalent_mean, .snowfall_water_equivalent_anomaly, .runoff_mean, .runoff_anomaly, .evapotranspiration_mean, .evapotranspiration_anomaly:
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
    
    var shift24h: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (self.rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return 20
        case .soil_moisture_0_to_7cm_mean, .soil_moisture_7_to_28cm_mean, .soil_moisture_28_to_100cm_mean, .soil_moisture_100_to_255cm_mean:
            return 1000
        case .temperature_max24h_2m_mean, .temperature_min24h_2m_mean:
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
        case .wind_u_component_10m_mean, .wind_v_component_10m_mean:
            return 10
        case .snowfall_water_equivalent_mean:
            return 10
        case .precipitation_mean, .evapotranspiration_mean, .evapotranspiration_anomaly:
            return 10
        case .shortwave_radiation_mean, .longwave_radiation_mean, .longwave_radiation_anomaly, .latent_heat_flux_mean, .latent_heat_flux_anomaly, .sensible_heat_flux_mean, .sensible_heat_flux_anomaly:
            return 10
        case .cloud_cover_mean:
            return 10
        case .soil_temperature_0_to_7cm_anomaly, .soil_temperature_7_to_28cm_anomaly, .soil_temperature_28_to_100cm_anomaly, .soil_temperature_100_to_255cm_anomaly:
            return 20
        case .soil_moisture_0_to_7cm_anomaly, .soil_moisture_7_to_28cm_anomaly, .soil_moisture_28_to_100cm_anomaly, .soil_moisture_100_to_255cm_anomaly:
            return 1000
        case .temperature_max24h_2m_anomaly, .temperature_min24h_2m_anomaly, .temperature_2m_anomaly, .dew_point_2m_anomaly:
            return 20
        case .pressure_msl_anomaly:
            return 10
        case .sea_surface_temperature_anomaly:
            return 20
        case .wind_u_component_10m_anomaly, .wind_v_component_10m_anomaly:
            return 10
        case .snowfall_water_equivalent_anomaly:
            return 10
        case .precipitation_anomaly:
            return 10
        case .shortwave_radiation_anomaly:
            return 1
        case .cloud_cover_anomaly:
            return 1
        case .wind_gusts_10m_anomaly:
            return 10
        case .wind_speed_10m_mean:
            return 10
        case .wind_speed_10m_anomaly:
            return 10
        case .albedo_mean:
            return 100
        case .albedo_anomaly:
            return 100
        case .cloud_cover_low_mean:
            return 1
        case .cloud_cover_low_anomaly:
            return 1
        case .showers_mean:
            return 10
        case .showers_anomaly:
            return 10
        case .runoff_mean:
            return 10
        case .runoff_anomaly:
            return 10
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
        case .sea_ice_cover_mean, .sea_ice_cover_anomaly:
            return 100
        }
    }
    
    var interpolation: ReaderInterpolation {
        // Monthly data will not be interpolated
        return .linear
    }
    
    var unit: SiUnit {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return .celsius
        case .soil_moisture_0_to_7cm_mean, .soil_moisture_7_to_28cm_mean, .soil_moisture_28_to_100cm_mean, .soil_moisture_100_to_255cm_mean:
            return .cubicMetrePerCubicMetre
        case .temperature_max24h_2m_mean, .temperature_min24h_2m_mean:
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
        case .wind_u_component_10m_mean, .wind_v_component_10m_mean:
            return .metrePerSecond
        case .snowfall_water_equivalent_mean:
            return .millimetre
        case .precipitation_mean:
            return .millimetre
        case .shortwave_radiation_mean:
            return .megajoulePerSquareMetre
        case .cloud_cover_mean:
            return .percentage
        case .soil_temperature_0_to_7cm_anomaly, .soil_temperature_7_to_28cm_anomaly, .soil_temperature_28_to_100cm_anomaly, .soil_temperature_100_to_255cm_anomaly:
            return .kelvin
        case .soil_moisture_0_to_7cm_anomaly, .soil_moisture_7_to_28cm_anomaly, .soil_moisture_28_to_100cm_anomaly, .soil_moisture_100_to_255cm_anomaly:
            return .cubicMetrePerCubicMetre
        case .temperature_max24h_2m_anomaly, .temperature_min24h_2m_anomaly:
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
        case .wind_u_component_10m_anomaly, .wind_v_component_10m_anomaly:
            return .metrePerSecond
        case .snowfall_water_equivalent_anomaly:
            return .millimetre
        case .precipitation_anomaly:
            return .millimetre
        case .shortwave_radiation_anomaly:
            return .megajoulePerSquareMetre
        case .cloud_cover_anomaly:
            return .percentage
        case .wind_gusts_10m_anomaly:
            return .metrePerSecond
        case .wind_speed_10m_mean:
            return .metrePerSecond
        case .wind_speed_10m_anomaly:
            return .metrePerSecond
        case .albedo_mean:
            return .fraction
        case .albedo_anomaly:
            return .fraction
        case .cloud_cover_low_mean:
            return .percentage
        case .cloud_cover_low_anomaly:
            return .percentage
        case .showers_mean:
            return .millimetre
        case .showers_anomaly:
            return .millimetre
        case .runoff_mean:
            return .millimetre
        case .runoff_anomaly:
            return .millimetre
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
        case .longwave_radiation_mean, .longwave_radiation_anomaly:
            return .megajoulePerSquareMetre
        case .sea_ice_cover_mean, .sea_ice_cover_anomaly:
            return .fraction
        case .latent_heat_flux_mean, .latent_heat_flux_anomaly, .sensible_heat_flux_mean, .sensible_heat_flux_anomaly:
            return .megajoulePerSquareMetre
        case .evapotranspiration_mean, .evapotranspiration_anomaly:
            return .millimetre
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .soil_temperature_0_to_7cm_mean, .soil_temperature_7_to_28cm_mean, .soil_temperature_28_to_100cm_mean, .soil_temperature_100_to_255cm_mean:
            return true
        case .temperature_max24h_2m_mean, .temperature_min24h_2m_mean:
            return true
        case .temperature_2m_mean, .dew_point_2m_mean: return true
        default:
            return false
        }
    }
    
    var storePreviousForecast: Bool {
        return false
    }
    
    
    static func from(shortName: String) -> Self? {
        switch shortName {
        case "10fga":
            return .wind_gusts_10m_anomaly
        case "10si":
            return .wind_speed_10m_mean
        case "10sia":
            return .wind_speed_10m_anomaly
        case "fal":
            return .albedo_mean
        case "fala":
            return .albedo_anomaly
        case "lcc":
            return .cloud_cover_low_mean
        case "lcca":
            return .cloud_cover_low_anomaly
        case "cprate":
            return .showers_mean
        case "mcpra":
            return .showers_anomaly
        case "mrort":
            return .runoff_mean
        case "roara":
            return .runoff_anomaly
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
        case "stl2":
            return .soil_temperature_7_to_28cm_mean
        case "stl3":
            return .soil_temperature_28_to_100cm_mean
        case "stl4":
            return .soil_temperature_100_to_255cm_mean
        case "msdr":
            return .sunshine_duration_mean
        case "swvl1":
            return .soil_moisture_0_to_7cm_mean
        case "swvl2":
            return .soil_moisture_7_to_28cm_mean
        case "swvl3":
            return .soil_moisture_28_to_100cm_mean
        case "swvl4":
            return .soil_moisture_100_to_255cm_mean
        case "10u":
            return .wind_u_component_10m_mean
        case "10v":
            return .wind_v_component_10m_mean
        case "2d":
            return .dew_point_2m_mean
        case "2t":
            return .temperature_2m_mean
        case "msl":
            return .pressure_msl_mean
        case "mtsfr":
            return .snowfall_water_equivalent_mean
        case "msdsrf":
            return .shortwave_radiation_mean
        case "tcc":
            return .cloud_cover_mean
        case "tprate":
            return .precipitation_mean
        case "mn2t24":
            return .temperature_min24h_2m_mean
        case "mx2t24":
            return .temperature_max24h_2m_mean
        case "stal1":
            return .soil_temperature_0_to_7cm_anomaly
        case "stal2":
            return .soil_temperature_7_to_28cm_anomaly
        case "stal3":
            return .soil_temperature_28_to_100cm_anomaly
        case "stal4":
            return .soil_temperature_100_to_255cm_anomaly
        case "sundara":
            return .sunshine_duration_anomaly
        case "swval1":
            return .soil_moisture_0_to_7cm_anomaly
        case "swval2":
            return .soil_moisture_7_to_28cm_anomaly
        case "swval3":
            return .soil_moisture_28_to_100cm_anomaly
        case "swval4":
            return .soil_moisture_100_to_255cm_anomaly
        case "10ua":
            return .wind_u_component_10m_anomaly
        case "10va":
            return .wind_v_component_10m_anomaly
        case "2da":
            return .dew_point_2m_anomaly
        case "2ta":
            return .temperature_2m_anomaly
        case "msla":
            return .pressure_msl_anomaly
        case "sfara":
            return .snowfall_water_equivalent_anomaly
        case "ssrdara":
            return .shortwave_radiation_anomaly
        case "tcca":
            return .cloud_cover_anomaly
        case "tpara":
            return .precipitation_anomaly
        case "mn2t24a":
            return .temperature_min24h_2m_anomaly
        case "mx2t24a":
            return .temperature_max24h_2m_anomaly
        case "tcwv":
            return .total_column_integrated_water_vapour_mean
        case "tcwva":
            return .total_column_integrated_water_vapour_anomaly
        case "ci":
            return .sea_ice_cover_mean
        case "sica":
            return .sea_ice_cover_anomaly
        case "erate":
            return .evapotranspiration_mean
        case "evara":
            return .evapotranspiration_anomaly
        case "mslhfl":
            return .latent_heat_flux_mean
        case "slhfara":
            return .latent_heat_flux_anomaly
        case "msshfl":
            return .sensible_heat_flux_mean
        case "sshfara":
            return .sensible_heat_flux_anomaly
        case "msdtrf":
            return .longwave_radiation_mean
        case "strdara":
            return .longwave_radiation_anomaly
        default:
            return nil
        }
    }
}
