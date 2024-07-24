import Foundation
import SwiftPFor2D
import Vapor



typealias Era5HourlyVariable = VariableOrDerived<Era5Variable, Era5VariableDerived>

enum Era5VariableDerived: String, RawRepresentableString, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case relative_humidity_2m
    case windspeed_10m
    case wind_speed_10m
    case winddirection_10m
    case wind_direction_10m
    case windspeed_100m
    case wind_speed_100m
    case winddirection_100m
    case wind_direction_100m
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case showers
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case cloud_cover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case direct_normal_irradiance
    case weathercode
    case weather_code
    case soil_moisture_0_to_100cm
    case soil_temperature_0_to_100cm
    case growing_degree_days_base_0_limit_50
    case leaf_wetness_probability
    case soil_moisture_index_0_to_7cm
    case soil_moisture_index_7_to_28cm
    case soil_moisture_index_28_to_100cm
    case soil_moisture_index_100_to_255cm
    case soil_moisture_index_0_to_100cm
    case is_day
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case wet_bulb_temperature_2m
    case windgusts_10m
    case dewpoint_2m
    case sunshine_duration
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    
    case wind_speed_10m_spread
    case wind_speed_100m_spread
    case snowfall_spread
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
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
        case .showers:
               try prefetchData(raw: .precipitation, time: time)
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
        case .wind_speed_10m_spread:
            try prefetchData(raw: .wind_u_component_10m_spread, time: time)
            try prefetchData(raw: .wind_v_component_10m_spread, time: time)
        case .wind_speed_100m_spread:
            try prefetchData(raw: .wind_u_component_100m_spread, time: time)
            try prefetchData(raw: .wind_v_component_100m_spread, time: time)
        case .snowfall_spread:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
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
        case .showers:
            let precipitation = try get(raw: .precipitation, time: time)
            return DataAndUnit(precipitation.data.map({min($0, 0)}), precipitation.unit)
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
        case .wind_speed_10m_spread:
            let u = try get(raw: .wind_u_component_10m_spread, time: time)
            let v = try get(raw: .wind_v_component_10m_spread, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .wind_speed_100m_spread:
            let u = try get(raw: .wind_u_component_100m_spread, time: time)
            let v = try get(raw: .wind_v_component_100m_spread, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .metrePerSecond)
        case .snowfall_spread:
            let snowwater = try get(raw: .snowfall_water_equivalent_spread, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimetre)
        }
    }
}
