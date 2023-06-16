import SwiftPFor2D


/// Might be used to decode API queries later
enum Era5Variable: String, CaseIterable, GenericVariable {
    case temperature_2m
    case wind_u_component_100m
    case wind_v_component_100m
    case wind_u_component_10m
    case wind_v_component_10m
    case windgusts_10m
    case dewpoint_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case snowfall_water_equivalent
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
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m || self == .dewpoint_2m ||
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
        fatalError("Interpolation not required for era5")
    }
    
    func availableForDomain(domain: CdsDomain) -> Bool {
        // Note: ERA5-Land wind, pressure, snowfall, radiation and precipitation are only linearly interpolated from ERA5
        if domain == .era5_land {
            switch self {
            case .temperature_2m:
                fallthrough
            case .dewpoint_2m:
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
        case .windgusts_10m: return "instantaneous_10m_wind_gust"
        case .dewpoint_2m: return "2m_dewpoint_temperature"
        case .temperature_2m: return "2m_temperature"
        case .cloudcover_low: return "low_cloud_cover"
        case .cloudcover_mid: return "medium_cloud_cover"
        case .cloudcover_high: return "high_cloud_cover"
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
        case .windgusts_10m:
            return "49.128"
        case .dewpoint_2m:
            return "168.128"
        case .cloudcover_low:
            return "186.128"
        case .cloudcover_mid:
            return "187.128"
        case .cloudcover_high:
            return "188.128"
        case .pressure_msl:
            return "151.128"
        case .snowfall_water_equivalent:
            return "144.128"
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
        }
    }
    
    /// Applied to the netcdf file after reading
    var netCdfScaling: (offest: Double, scalefactor: Double)? {
        switch self {
        case .temperature_2m: return (-273.15, 1) // kelvin to celsius
        case .dewpoint_2m: return (-273.15, 1)
        case .cloudcover_low: return (0, 100) // fraction to percent
        case .cloudcover_mid: return (0, 100)
        case .cloudcover_high: return (0, 100)
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
        case .windgusts_10m: return ["10fg", "gust", "i10fg"] // or "gust" on ubuntu 22.04
        case .temperature_2m: return ["2t"]
        case .cloudcover_low: return ["lcc"]
        case .cloudcover_mid: return ["mcc"]
        case .cloudcover_high: return ["hcc"]
        case .pressure_msl: return ["msl"]
        case .snowfall_water_equivalent: return ["sf"]
        case .shortwave_radiation: return ["ssrd"]
        case .precipitation: return ["tp"]
        case .direct_radiation: return ["tidirswrf", "fdir"]
        case .wind_u_component_100m: return ["100u"]
        case .wind_v_component_100m: return ["100v"]
        case .wind_u_component_10m: return ["10u"]
        case .wind_v_component_10m: return ["10v"]
        case .dewpoint_2m: return ["2d"]
        case .soil_temperature_0_to_7cm: return ["stl1"]
        case .soil_temperature_7_to_28cm: return ["stl2"]
        case .soil_temperature_28_to_100cm: return ["stl3"]
        case .soil_temperature_100_to_255cm: return ["stl4"]
        case .soil_moisture_0_to_7cm: return ["swvl1"]
        case .soil_moisture_7_to_28cm: return ["swvl2"]
        case .soil_moisture_28_to_100cm: return ["swvl3"]
        case .soil_moisture_100_to_255cm: return ["swvl4"]
        }
    }
    
    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .wind_u_component_100m: return 10
        case .wind_v_component_100m: return 10
        case .wind_u_component_10m: return 10
        case .wind_v_component_10m: return 10
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .windgusts_10m: return 10
        case .dewpoint_2m: return 20
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
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .wind_u_component_100m: fallthrough
        case .wind_v_component_100m: fallthrough
        case .wind_u_component_10m: fallthrough
        case .wind_v_component_10m: fallthrough
        case .windgusts_10m: return .ms
        case .dewpoint_2m: return .celsius
        case .temperature_2m: return .celsius
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .pressure_msl: return .pascal
        case .snowfall_water_equivalent: return .millimeter
        case .soil_temperature_0_to_7cm: return .celsius
        case .soil_temperature_7_to_28cm: return .celsius
        case .soil_temperature_28_to_100cm: return .celsius
        case .soil_temperature_100_to_255cm: return .celsius
        case .shortwave_radiation: return .wattPerSquareMeter
        case .precipitation: return .millimeter
        case .direct_radiation: return .wattPerSquareMeter
        case .soil_moisture_0_to_7cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_7_to_28cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_28_to_100cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_100_to_255cm: return .qubicMeterPerQubicMeter
        }
    }
}

struct Era5Factory {
    /// Build a single reader for a given CdsDomain
    public static func makeReader(domain: CdsDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> Era5Reader<GenericReaderCached<CdsDomain, Era5Variable>> {
        guard let reader = try GenericReader<CdsDomain, Era5Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            // should not be possible
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        return .init(reader: GenericReaderCached(reader: reader))
    }
    
    /**
     Build a combined ERA5 and ERA5-Land reader.
     Derived variables are calculated after combinding both variables to make it possible to calculate ET0 evapotransipiration with temperature from ERA5-Land, but radiation from ERA5
     */
    public static func makeEra5CombinedLand(lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> Era5Reader<GenericReaderMixerSameDomain<GenericReaderCached<CdsDomain, Era5Variable>>> {
        guard let era5 = try GenericReader<CdsDomain, Era5Variable>(domain: .era5, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            // should not be possible
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        guard let era5land = try GenericReader<CdsDomain, Era5Variable>(domain: .era5_land, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            // should not be possible
            throw ForecastapiError.noDataAvilableForThisLocation
        }
        return .init(reader: GenericReaderMixerSameDomain(reader: [GenericReaderCached(reader: era5), GenericReaderCached(reader: era5land)]))
    }
}

struct Era5Reader<Reader: GenericReaderProtocol>: GenericReaderDerivedSimple, GenericReaderProtocol where Reader.MixingVar == Era5Variable {
    var reader: Reader
    
    typealias Domain = CdsDomain
    
    typealias Variable = Era5Variable
    
    typealias Derived = Era5VariableDerived
    
    public init(reader: Reader) {
        self.reader = reader
    }
    
    func prefetchData(variables: [Era5HourlyVariable], time: TimerangeDt) throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try prefetchData(raw: v, time: time)
            case .derived(let v):
                try prefetchData(derived: v, time: time)
            }
        }
    }
    
    func prefetchData(derived: Era5VariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .windspeed_10m:
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
            try prefetchData(raw: .dewpoint_2m, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .relativehumidity_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dewpoint_2m, time: time)
        case .winddirection_10m:
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .windspeed_100m:
            try prefetchData(raw: .wind_u_component_100m, time: time)
            try prefetchData(raw: .wind_v_component_100m, time: time)
        case .winddirection_100m:
            try prefetchData(raw: .wind_u_component_100m, time: time)
            try prefetchData(raw: .wind_v_component_100m, time: time)
        case .vapor_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dewpoint_2m, time: time)
        case .diffuse_radiation:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .dewpoint_2m, time: time)
            try prefetchData(raw: .wind_u_component_10m, time: time)
            try prefetchData(raw: .wind_v_component_10m, time: time)
        case .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
        case .snowfall:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .cloudcover:
            try prefetchData(raw: .cloudcover_low, time: time)
            try prefetchData(raw: .cloudcover_mid, time: time)
            try prefetchData(raw: .cloudcover_high, time: time)
        case .direct_normal_irradiance:
            try prefetchData(raw: .direct_radiation, time: time)
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
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
            try prefetchData(raw: .dewpoint_2m, time: time)
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
        }
    }
    
    func get(variable: Era5HourlyVariable, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(raw: variable, time: time)
        case .derived(let variable):
            return try get(derived: variable, time: time)
        }
    }
    
    func get(derived: Era5VariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .windspeed_10m:
            let u = try get(raw: .wind_u_component_10m, time: time)
            let v = try get(raw: .wind_v_component_10m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .apparent_temperature:
            let windspeed = try get(derived: .windspeed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let relhum = try get(derived: .relativehumidity_2m, time: time).data
            let radiation = try get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
        case .relativehumidity_2m:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dew = try get(raw: .dewpoint_2m, time: time).data
            let relativeHumidity = zip(temperature, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(relativeHumidity, .percent)
        case .winddirection_10m:
            let u = try get(raw: .wind_u_component_10m, time: time).data
            let v = try get(raw: .wind_v_component_10m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_100m:
            let u = try get(raw: .wind_u_component_100m, time: time)
            let v = try get(raw: .wind_v_component_100m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_100m:
            let u = try get(raw: .wind_u_component_100m, time: time).data
            let v = try get(raw: .wind_v_component_100m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(raw: .dewpoint_2m, time: time).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time)
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let windspeed = try get(derived: .windspeed_10m, time: time).data
            let dewpoint = try get(raw: .dewpoint_2m, time: time).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation.numeric, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .diffuse_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let direct = try get(raw: .direct_radiation, time: time).data
            let diff = zip(swrad,direct).map(-)
            return DataAndUnit(diff, .wattPerSquareMeter)
        case .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: targetElevation), pressure.unit)
        case .cloudcover:
            let low = try get(raw: .cloudcover_low, time: time).data
            let mid = try get(raw: .cloudcover_mid, time: time).data
            let high = try get(raw: .cloudcover_high, time: time).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percent)
        case .snowfall:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimeter)
        case .direct_normal_irradiance:
            let dhi = try get(raw: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, timerange: time)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .rain:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time)
            let precip = try get(raw: .precipitation, time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
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
                modelDtHours: time.dtSeconds / 3600), .wmoCode
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
            let dewpoint = try get(raw: .dewpoint_2m, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            return DataAndUnit(zip(zip(temperature, dewpoint), precipitation).map( {
                let ((temperature, dewpoint), precipitation) = $0
                return Meteorology.leafwetnessPorbability(temperature2mCelsius: temperature, dewpointCelsius: dewpoint, precipitation: precipitation)
            }), .percent)
        case .soil_moisture_index_0_to_7cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_0_to_7cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_7_to_28cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_7_to_28cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_28_to_100cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_28_to_100cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_100_to_255cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.count), .fraction)
            }
            let soilMoisture = try get(raw: .soil_moisture_100_to_255cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .soil_moisture_index_0_to_100cm:
            guard let soilType = try self.getStatic(type: .soilType) else {
                throw ForecastapiError.generic(message: "Could not read ERA5 soil type")
            }
            guard let type = SoilTypeEra5(rawValue: Int(soilType)) else {
                return DataAndUnit([Float](repeating: .nan, count: time.count), .fraction)
            }
            let soilMoisture = try get(derived: .soil_moisture_0_to_100cm, time: time)
            return DataAndUnit(type.calculateSoilMoistureIndex(soilMoisture.data), .fraction)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionless_integer)
        }
    }
}
