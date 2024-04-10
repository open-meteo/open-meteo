import SwiftPFor2D


/// Might be used to decode API queries later
enum Era5Variable: String, CaseIterable, GenericVariable {
    case temperature_2m
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_10m
    case wind_v_component_10m
    case wind_gusts_10m
    case dew_point_2m
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case snowfall_water_equivalent
    /// Only ERA5-Land and CERRA have snow depth in ACTUAL height. ERA5 and ECMWF IFS use water equivalent and density
    case snow_depth
    case soil_temperature_0_to_7cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm
    case shortwave_radiation
    case precipitation
    case direct_radiation
    
    case wave_height
    case wave_direction
    case wave_period
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .dew_point_2m ||
            self == .soil_temperature_0_to_7cm || self == .soil_temperature_7_to_28cm ||
            self == .soil_temperature_28_to_100cm || self == .soil_temperature_100_to_255cm
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
         return false
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .shortwave_radiation:
            fallthrough
        case .direct_radiation:
            fallthrough
        case .precipitation:
            fallthrough
        case .snowfall_water_equivalent:
            return true
        default:
            return false
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .wind_u_component_100m:
            return .hermite(bounds: nil)
        case .wind_v_component_100m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .dew_point_2m:
            return .hermite(bounds: nil)
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
        case .snow_depth:
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
        case .precipitation:
            return .backwards_sum
        case .direct_radiation:
            return .solar_backwards_averaged
        case .wave_height:
            return .hermite(bounds: nil)
        case .wave_direction:
            return .backwards
        case .wave_period:
            return .hermite(bounds: nil)
        }
    }
    
    func availableForDomain(domain: CdsDomain) -> Bool {
        /// Snow depth is only directly available in era5-land
        /// Others have to download snow depth water equivalent and density separately (not implemented)
        if self == .snow_depth {
            return domain == .era5_land
        }
        
        // Waves are only available for ERA5 ocean at 0.5° resolution
        switch self {
        case .wave_height, .wave_period, .wave_direction:
            return domain == .era5_ocean
        default:
            if domain == .era5_ocean {
                return false
            }
        }
        
        // Note: ERA5-Land wind, pressure, snowfall, radiation and precipitation are only linearly interpolated from ERA5
        if domain == .era5_land {
            switch self {
            case .temperature_2m:
                fallthrough
            case .dew_point_2m:
                fallthrough
            case .soil_temperature_0_to_7cm:
                fallthrough
            case .soil_temperature_7_to_28cm:
                fallthrough
            case .soil_temperature_28_to_100cm:
                fallthrough
            case .soil_temperature_100_to_255cm:
                fallthrough
            case .soil_moisture_0_to_7cm:
                fallthrough
            case .soil_moisture_7_to_28cm:
                fallthrough
            case .soil_moisture_28_to_100cm:
                fallthrough
            case .soil_moisture_100_to_255cm:
                return true
            default: return false
            }
        }
        return true
    }
    
    /// Name used to query the ECMWF CDS API via python
    var cdsApiName: String {
        switch self {
        case .wind_u_component_100m: return "100m_u_component_of_wind"
        case .wind_v_component_100m: return "100m_v_component_of_wind"
        case .wind_u_component_10m: return "10m_u_component_of_wind"
        case .wind_v_component_10m: return "10m_v_component_of_wind"
        case .wind_gusts_10m: return "instantaneous_10m_wind_gust"
        case .dew_point_2m: return "2m_dewpoint_temperature"
        case .temperature_2m: return "2m_temperature"
        case .cloud_cover_low: return "low_cloud_cover"
        case .cloud_cover_mid: return "medium_cloud_cover"
        case .cloud_cover_high: return "high_cloud_cover"
        case .pressure_msl: return "mean_sea_level_pressure"
        case .snowfall_water_equivalent: return "snowfall"
        case .soil_temperature_0_to_7cm: return "soil_temperature_level_1"
        case .soil_temperature_7_to_28cm: return "soil_temperature_level_2"
        case .soil_temperature_28_to_100cm: return "soil_temperature_level_3"
        case .soil_temperature_100_to_255cm: return "soil_temperature_level_4"
        case .shortwave_radiation: return "surface_solar_radiation_downwards"
        case .precipitation: return "total_precipitation"
        case .direct_radiation: return "total_sky_direct_solar_radiation_at_surface"
        case .soil_moisture_0_to_7cm: return "volumetric_soil_water_layer_1"
        case .soil_moisture_7_to_28cm: return "volumetric_soil_water_layer_2"
        case .soil_moisture_28_to_100cm: return "volumetric_soil_water_layer_3"
        case .soil_moisture_100_to_255cm: return "volumetric_soil_water_layer_4"
            // NOTE: snow depth uses different definitions in ERA5 and ECMWF IFS. Only ERA5-land returns the actual height directly
        case .snow_depth: return "snow_depth"
        case .wave_height: return "significant_height_of_combined_wind_waves_and_swell"
        case .wave_direction: return "mean_wave_direction"
        case .wave_period: return "mean_wave_period"
        }
    }
    
    var marsGribCode: String {
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
        case .snow_depth:
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
        case .wave_height:
            fatalError("Not supported")
        case .wave_direction:
            fatalError("Not supported")
        case .wave_period:
            fatalError("Not supported")
        }
    }
    
    /// Applied to the netcdf file after reading
    var netCdfScaling: (offest: Double, scalefactor: Double)? {
        switch self {
        case .temperature_2m: return (-273.15, 1) // kelvin to celsius
        case .dew_point_2m: return (-273.15, 1)
        case .cloud_cover_low: return (0, 100) // fraction to percent
        case .cloud_cover_mid: return (0, 100)
        case .cloud_cover_high: return (0, 100)
        case .pressure_msl: return (0, 1) // keep in Pa (not hPa)
        case .snowfall_water_equivalent: return (0, 1000) // meter to millimeter
        case .soil_temperature_0_to_7cm: return (-273.15, 1) // kelvin to celsius
        case .soil_temperature_7_to_28cm: return (-273.15, 1)
        case .soil_temperature_28_to_100cm: return (-273.15, 1)
        case .soil_temperature_100_to_255cm: return (-273.15, 1)
        case .shortwave_radiation: return (0, 1/3600) // joules to watt
        case .precipitation: return (0, 1000) // meter to millimeter
        case .direct_radiation: return (0, 1/3600)
        default: return nil
        }
    }
    
    /// shortName attribute in GRIB
    var gribShortName: [String] {
        switch self {
        case .wind_gusts_10m: return ["10fg", "gust", "i10fg"] // or "gust" on ubuntu 22.04
        case .temperature_2m: return ["2t"]
        case .cloud_cover_low: return ["lcc"]
        case .cloud_cover_mid: return ["mcc"]
        case .cloud_cover_high: return ["hcc"]
        case .pressure_msl: return ["msl"]
        case .snowfall_water_equivalent: return ["sf"]
        case .shortwave_radiation: return ["ssrd"]
        case .precipitation: return ["tp"]
        case .direct_radiation: return ["tidirswrf", "fdir"]
        case .wind_u_component_100m: return ["100u"]
        case .wind_v_component_100m: return ["100v"]
        case .wind_u_component_10m: return ["10u"]
        case .wind_v_component_10m: return ["10v"]
        case .dew_point_2m: return ["2d"]
        case .soil_temperature_0_to_7cm: return ["stl1"]
        case .soil_temperature_7_to_28cm: return ["stl2"]
        case .soil_temperature_28_to_100cm: return ["stl3"]
        case .soil_temperature_100_to_255cm: return ["stl4"]
        case .soil_moisture_0_to_7cm: return ["swvl1"]
        case .soil_moisture_7_to_28cm: return ["swvl2"]
        case .soil_moisture_28_to_100cm: return ["swvl3"]
        case .soil_moisture_100_to_255cm: return ["swvl4"]
        case .snow_depth: return ["sde"]
        case .wave_height:
            return ["swh"]
        case .wave_direction:
            return ["mwd"]
        case .wave_period:
            return ["mwp"]
        }
    }
    
    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .wind_u_component_100m: return 10
        case .wind_v_component_100m: return 10
        case .wind_u_component_10m: return 10
        case .wind_v_component_10m: return 10
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .wind_gusts_10m: return 10
        case .dew_point_2m: return 20
        case .temperature_2m: return 20
        case .pressure_msl: return 0.1
        case .snowfall_water_equivalent: return 10
        case .soil_temperature_0_to_7cm: return 20
        case .soil_temperature_7_to_28cm: return 20
        case .soil_temperature_28_to_100cm: return 20
        case .soil_temperature_100_to_255cm: return 20
        case .shortwave_radiation: return 1
        case .precipitation: return 10
        case .direct_radiation: return 1
        case .soil_moisture_0_to_7cm: return 1000
        case .soil_moisture_7_to_28cm: return 1000
        case .soil_moisture_28_to_100cm: return 1000
        case .soil_moisture_100_to_255cm: return 1000
        case .snow_depth: return 100 // 1 cm resolution
        case .wave_height:
            return 50 // 0.002m resolution
        case .wave_direction:
            return 1
        case .wave_period:
            return 20 // 0.05s resolution
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .wind_u_component_100m: fallthrough
        case .wind_v_component_100m: fallthrough
        case .wind_u_component_10m: fallthrough
        case .wind_v_component_10m: fallthrough
        case .wind_gusts_10m: return .metrePerSecond
        case .dew_point_2m: return .celsius
        case .temperature_2m: return .celsius
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
        case .precipitation: return .millimetre
        case .direct_radiation: return .wattPerSquareMetre
        case .soil_moisture_0_to_7cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_7_to_28cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_28_to_100cm: return .cubicMetrePerCubicMetre
        case .soil_moisture_100_to_255cm: return .cubicMetrePerCubicMetre
        case .snow_depth: return .metre
        case .wave_height:
            return .metre
        case .wave_direction:
            return .degreeDirection
        case .wave_period:
            return .seconds
        }
    }
}

struct Era5Factory {
    /// Build a single reader for a given CdsDomain
    public static func makeReader(domain: CdsDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> Era5Reader<GenericReaderCached<CdsDomain, Era5Variable>> {
        guard let reader = try GenericReader<CdsDomain, Era5Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            // should not be possible
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        return .init(reader: GenericReaderCached(reader: reader), options: options)
    }
    
    /// Build a single reader for a given CdsDomain
    public static func makeReader(domain: CdsDomain, gridpoint: Int, options: GenericReaderOptions) throws -> Era5Reader<GenericReaderCached<CdsDomain, Era5Variable>> {
        let reader = try GenericReader<CdsDomain, Era5Variable>(domain: domain, position: gridpoint)
        return .init(reader: GenericReaderCached(reader: reader), options: options)
    }
    
    /**
     Build a combined ERA5 and ERA5-Land reader.
     Derived variables are calculated after combinding both variables to make it possible to calculate ET0 evapotransipiration with temperature from ERA5-Land, but radiation from ERA5
     */
    public static func makeEra5CombinedLand(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> Era5Reader<GenericReaderMixerSameDomain<GenericReaderCached<CdsDomain, Era5Variable>>> {
        guard /*let era5ocean = try GenericReader<CdsDomain, Era5Variable>(domain: .era5_ocean, lat: lat, lon: lon, elevation: elevation, mode: mode),*/
              let era5 = try GenericReader<CdsDomain, Era5Variable>(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode),
              let era5land = try GenericReader<CdsDomain, Era5Variable>(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode)
        else {
            // should not be possible
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        return .init(reader: GenericReaderMixerSameDomain(reader: [/*GenericReaderCached(reader: era5ocean), */GenericReaderCached(reader: era5), GenericReaderCached(reader: era5land)]), options: options)
    }
    
    public static func makeArchiveBestMatch(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> Era5Reader<GenericReaderMixerSameDomain<GenericReaderCached<CdsDomain, Era5Variable>>> {
        guard let era5 = try GenericReader<CdsDomain, Era5Variable>(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode),
              let era5land = try GenericReader<CdsDomain, Era5Variable>(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode),
              let ecmwfIfs = try GenericReader<CdsDomain, Era5Variable>(domain: .ecmwf_ifs, lat: lat, lon: lon, elevation: elevation, mode: mode) 
        else {
            // should not be possible
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        return .init(reader: GenericReaderMixerSameDomain(reader: [
            GenericReaderCached(reader: era5),
            GenericReaderCached(reader: era5land),
            GenericReaderCached(reader: ecmwfIfs)
        ]), options: options)
    }
}

struct Era5Reader<Reader: GenericReaderProtocol>: GenericReaderDerivedSimple, GenericReaderProtocol where Reader.MixingVar == Era5Variable {
    let reader: Reader
    
    let options: GenericReaderOptions
    
    typealias Domain = CdsDomain
    
    typealias Variable = Era5Variable
    
    typealias Derived = Era5VariableDerived
    
    public init(reader: Reader, options: GenericReaderOptions) {
        self.reader = reader
        self.options = options
    }
    
    func prefetchData(variables: [Era5HourlyVariable], time: TimerangeDtAndSettings) throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try prefetchData(raw: v, time: time)
            case .derived(let v):
                try prefetchData(derived: v, time: time)
            }
        }
    }
    
    func prefetchData(derived: Era5VariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .wind_speed_10m:
            fallthrough
        case .windspeed_10m:
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .relative_humidity_2m:
            fallthrough
        case .relativehumidity_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
        case .wind_direction_10m:
            fallthrough
        case .winddirection_10m:
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .wind_speed_100m:
            fallthrough
        case .windspeed_100m:
            try prefetchData(raw: .wind_u_component_100m, time: time)
            try prefetchData(raw: .wind_v_component_100m, time: time)
        case .wind_direction_100m:
            fallthrough
        case .winddirection_100m:
            try prefetchData(raw: .wind_u_component_100m, time: time)
            try prefetchData(raw: .wind_v_component_100m, time: time)
        case .vapour_pressure_deficit:
            fallthrough
        case .vapor_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
        case .global_tilted_irradiance, .global_tilted_irradiance_instant:
            fallthrough
        case .diffuse_radiation:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
        case .snowfall:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .cloud_cover:
            fallthrough
        case .cloudcover:
            try prefetchData(raw: .cloud_cover_low, time: time)
            try prefetchData(raw: .cloud_cover_mid, time: time)
            try prefetchData(raw: .cloud_cover_high, time: time)
        case .direct_normal_irradiance:
            try prefetchData(raw: .direct_radiation, time: time)
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .weather_code:
            fallthrough
        case .weathercode:
            try prefetchData(derived: .cloudcover, time: time)
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(derived: .snowfall, time: time)
        case .soil_moisture_0_to_100cm:
            try prefetchData(raw: .soil_moisture_0_to_7cm, time: time)
            try prefetchData(raw: .soil_moisture_7_to_28cm, time: time)
            try prefetchData(raw: .soil_moisture_28_to_100cm, time: time)
        case .soil_temperature_0_to_100cm:
            try prefetchData(raw: .soil_temperature_0_to_7cm, time: time)
            try prefetchData(raw: .soil_temperature_7_to_28cm, time: time)
            try prefetchData(raw: .soil_temperature_28_to_100cm, time: time)
        case .growing_degree_days_base_0_limit_50:
            try prefetchData(raw: .temperature_2m, time: time)
        case .leaf_wetness_probability:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .dew_point_2m, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .soil_moisture_index_0_to_7cm:
            try prefetchData(raw: .soil_moisture_0_to_7cm, time: time)
        case .soil_moisture_index_7_to_28cm:
            try prefetchData(raw: .soil_moisture_7_to_28cm, time: time)
        case .soil_moisture_index_28_to_100cm:
            try prefetchData(raw: .soil_moisture_28_to_100cm, time: time)
        case .soil_moisture_index_100_to_255cm:
            try prefetchData(raw: .soil_moisture_100_to_255cm, time: time)
        case .soil_moisture_index_0_to_100cm:
            try prefetchData(derived: .soil_moisture_0_to_100cm, time: time)
        case .is_day:
            break
        case .terrestrial_radiation:
            break
        case .terrestrial_radiation_instant:
            break
        case .shortwave_radiation_instant:
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .diffuse_radiation_instant:
            try prefetchData(derived: .diffuse_radiation, time: time)
        case .direct_radiation_instant:
            try prefetchData(raw: .direct_radiation, time: time)
        case .direct_normal_irradiance_instant:
            try prefetchData(raw: .direct_radiation, time: time)
        case .wet_bulb_temperature_2m:
            try prefetchData(raw: .dew_point_2m, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .cloudcover_low:
            try prefetchData(raw: .cloud_cover_low, time: time)
        case .cloudcover_mid:
            try prefetchData(raw: .cloud_cover_mid, time: time)
        case .cloudcover_high:
            try prefetchData(raw: .cloud_cover_high, time: time)
        case .windgusts_10m:
            try prefetchData(raw: .wind_gusts_10m, time: time)
        case .dewpoint_2m:
            try prefetchData(raw: .dew_point_2m, time: time)
        case .sunshine_duration:
            try prefetchData(raw: .direct_radiation, time: time)
        }
    }
    
    func get(variable: Era5HourlyVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(raw: variable, time: time)
        case .derived(let variable):
            return try get(derived: variable, time: time)
        }
    }
    
    func get(derived: Era5VariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .wind_speed_10m:
            fallthrough
        case .windspeed_10m:
            let u = try get(raw: .wind_u_component_10m, time: time)
            let v = try get(raw: .wind_v_component_10m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .apparent_temperature:
            let windspeed = try get(derived: .windspeed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let relhum = try get(derived: .relativehumidity_2m, time: time).data
            let radiation = try get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
        case .relative_humidity_2m:
            fallthrough
        case .relativehumidity_2m:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dew = try get(raw: .dew_point_2m, time: time).data
            let relativeHumidity = zip(temperature, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(relativeHumidity, .percentage)
        case .wind_direction_10m:
            fallthrough
        case .winddirection_10m:
            let u = try get(raw: .wind_u_component_10m, time: time).data
            let v = try get(raw: .wind_v_component_10m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .wind_speed_100m:
            fallthrough
        case .windspeed_100m:
            let u = try get(raw: .wind_u_component_100m, time: time)
            let v = try get(raw: .wind_v_component_100m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_direction_100m:
            fallthrough
        case .winddirection_100m:
            let u = try get(raw: .wind_u_component_100m, time: time).data
            let v = try get(raw: .wind_v_component_100m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .vapour_pressure_deficit:
            fallthrough
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(raw: .dew_point_2m, time: time).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time.time)
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let windspeed = try get(derived: .windspeed_10m, time: time).data
            let dewpoint = try get(raw: .dew_point_2m, time: time).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation.numeric, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimetre)
        case .diffuse_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let direct = try get(raw: .direct_radiation, time: time).data
            let diff = zip(swrad,direct).map(-)
            return DataAndUnit(diff, .wattPerSquareMetre)
        case .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: targetElevation), pressure.unit)
        case .cloud_cover:
            fallthrough
        case .cloudcover:
            let low = try get(raw: .cloud_cover_low, time: time).data
            let mid = try get(raw: .cloud_cover_mid, time: time).data
            let high = try get(raw: .cloud_cover_high, time: time).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percentage)
        case .snowfall:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimetre)
        case .direct_normal_irradiance:
            let dhi = try get(raw: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, timerange: time.time)
            return DataAndUnit(dni, .wattPerSquareMetre)
        case .rain:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time)
            let precip = try get(raw: .precipitation, time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        case .weather_code:
            fallthrough
        case .weathercode:
            let cloudcover = try get(derived: .cloudcover, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            let snowfall = try get(derived: .snowfall, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: nil,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtSeconds: time.dtSeconds), .wmoCode
            )
        case .soil_moisture_0_to_100cm:
            let sm0_7 = try get(raw: .soil_moisture_0_to_7cm, time: time)
            let sm7_28 = try get(raw: .soil_moisture_7_to_28cm, time: time).data
            let sm28_100 = try get(raw: .soil_moisture_28_to_100cm, time: time).data
            return DataAndUnit(zip(sm0_7.data, zip(sm7_28, sm28_100)).map({
                let (sm0_7, (sm7_28, sm28_100)) = $0
                return sm0_7 * 0.07 + sm7_28 * (0.28 - 0.07) + sm28_100 * (1 - 0.28)
            }), sm0_7.unit)
        case .soil_temperature_0_to_100cm:
            let st0_7 = try get(raw: .soil_temperature_0_to_7cm, time: time)
            let st7_28 = try get(raw: .soil_temperature_7_to_28cm, time: time).data
            let st28_100 = try get(raw: .soil_temperature_28_to_100cm, time: time).data
            return DataAndUnit(zip(st0_7.data, zip(st7_28, st28_100)).map({
                let (st0_7, (st7_28, st28_100)) = $0
                return st0_7 * 0.07 + st7_28 * (0.28 - 0.07) + st28_100 * (1 - 0.28)
            }), st0_7.unit)
        case .growing_degree_days_base_0_limit_50:
            let base: Float = 0
            let limit: Float = 50
            let t2m = try get(raw: .temperature_2m, time: time).data
            return DataAndUnit(t2m.map({ t2m in
                max(min(t2m, limit) - base, 0) / 24
            }), .gddCelsius)
        case .leaf_wetness_probability:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(raw: .dew_point_2m, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            return DataAndUnit(zip(zip(temperature, dewpoint), precipitation).map( {
                let ((temperature, dewpoint), precipitation) = $0
                return Meteorology.leafwetnessPorbability(temperature2mCelsius: temperature, dewpointCelsius: dewpoint, precipitation: precipitation)
            }), .percentage)
        case .soil_moisture_index_0_to_7cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_0_to_7cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_7_to_28cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_7_to_28cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_28_to_100cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_28_to_100cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_100_to_255cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_100_to_255cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_0_to_100cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.time.count), .fraction)
            }
            let soilMoisture = try get(derived: .soil_moisture_0_to_100cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .terrestrial_radiation:
            let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .terrestrial_radiation_instant:
            let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .shortwave_radiation_instant:
            let sw = try get(raw: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .direct_normal_irradiance_instant:
            let direct = try get(derived: .direct_radiation_instant, time: time)
            let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(dni, direct.unit)
        case .direct_radiation_instant:
            let direct = try get(raw: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .wet_bulb_temperature_2m:
            let temperature = try get(raw: .temperature_2m, time: time)
            let dew = try get(raw: .dew_point_2m, time: time).data
            let rh = zip(temperature.data, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(zip(temperature.data, rh).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .cloudcover_low:
            return try get(raw: .cloud_cover_low, time: time)
        case .cloudcover_mid:
            return try get(raw: .cloud_cover_mid, time: time)
        case .cloudcover_high:
            return try get(raw: .cloud_cover_high, time: time)
        case .windgusts_10m:
            return try get(raw: .wind_gusts_10m, time: time)
        case .dewpoint_2m:
            return try get(raw: .dew_point_2m, time: time)
        case .sunshine_duration:
            let directRadiation = try get(raw: .direct_radiation, time: time)
            let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(duration, .seconds)
        case .global_tilted_irradiance:
            let directRadiation = try get(raw: .direct_radiation, time: time).data
            let ghi = try get(raw: .shortwave_radiation, time: time).data
            let diffuseRadiation = zip(ghi, directRadiation).map(-)
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .global_tilted_irradiance_instant:
            let directRadiation = try get(raw: .direct_radiation, time: time).data
            let ghi = try get(raw: .shortwave_radiation, time: time).data
            let diffuseRadiation = zip(ghi, directRadiation).map(-)
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
            return DataAndUnit(gti, .wattPerSquareMetre)
        }
    }
}
