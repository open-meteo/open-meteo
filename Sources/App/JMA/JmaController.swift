import Foundation
import Vapor


enum JmaVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case dewpoint_2m
    case dew_point_2m
    case windspeed_10m
    case wind_speed_10m
    case winddirection_10m
    case wind_direction_10m
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case et0_fao_evapotranspiration
    case vapour_pressure_deficit
    case vapor_pressure_deficit
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weathercode
    case weather_code
    case snowfall
    case rain
    case showers
    case is_day
    case wet_bulb_temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case sunshine_duration
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum JmaPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case cloudcover
    case wind_speed
    case wind_direction
    case dew_point
    case cloud_cover
    case relativehumidity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct JmaPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: JmaPressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias JmaVariableDerived = SurfaceAndPressureVariable<JmaVariableDerivedSurface, JmaPressureVariableDerived>

typealias JmaVariableCombined = VariableOrDerived<JmaVariable, JmaVariableDerived>

struct JmaReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    typealias MixingVar = JmaVariableCombined
    
    typealias Domain = JmaDomain
    
    typealias Variable = JmaVariable
    
    typealias Derived = JmaVariableDerived
    
    let reader: GenericReaderCached<JmaDomain, JmaVariable>
    
    let options: GenericReaderOptions
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }
    
    func get(raw: SurfaceAndPressureVariable<JmaSurfaceVariable, JmaPressureVariable>, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch raw {
        case .pressure(let variable):
            if variable.variable == .geopotential_height {
                let data = try self.reader.get(variable: raw, time: time)
                return DataAndUnit(data.data.map { $0 * 9.80665 }, data.unit)
            }
        default:
            break
        }
        
        return try self.reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: JmaSurfaceVariable, time: TimerangeDtAndSettings) throws {
        try prefetchData(raw: .surface(raw), time: time)
    }
    
    func get(raw: JmaSurfaceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        try get(raw: .surface(raw), time: time)
    }
    
    func prefetchData(derived: JmaVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
                try prefetchData(raw: .shortwave_radiation, time: time)
            case .relativehumidity_2m:
                try prefetchData(raw: .relative_humidity_2m, time: time)
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                fallthrough
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .shortwave_radiation, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
                try prefetchData(raw: .wind_u_component_10m, time: time)
                try prefetchData(raw: .wind_v_component_10m, time: time)
            case .surface_pressure:
                try prefetchData(raw: .pressure_msl, time: time)
                try prefetchData(raw: .temperature_2m, time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
            case .diffuse_radiation:
                fallthrough
            case .diffuse_radiation_instant:
                fallthrough
            case .direct_normal_irradiance:
                fallthrough
            case .direct_normal_irradiance_instant:
                fallthrough
            case .direct_radiation:
                fallthrough
            case .direct_radiation_instant:
                fallthrough
            case .global_tilted_irradiance, .global_tilted_irradiance_instant:
                fallthrough
            case .shortwave_radiation_instant:
                try prefetchData(raw: .shortwave_radiation, time: time)
            case .weather_code:
                fallthrough
            case .weathercode:
                try prefetchData(raw: .cloud_cover, time: time)
                try prefetchData(variable: .derived(.surface(.snowfall)), time: time)
                try prefetchData(raw: .precipitation, time: time)
            case .snowfall:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .precipitation, time: time)
            case .showers:
                try prefetchData(raw: .precipitation, time: time)
            case .rain:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .precipitation, time: time)
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try prefetchData(raw: .temperature_2m, time: time)
                try prefetchData(raw: .relative_humidity_2m, time: time)
            case .cloudcover:
                try prefetchData(raw: .cloud_cover, time: time)
            case .cloudcover_low:
                try prefetchData(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                try prefetchData(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                try prefetchData(raw: .cloud_cover_high, time: time)
            case .sunshine_duration:
                try prefetchData(derived: .surface(.direct_radiation), time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .wind_speed:
                fallthrough
            case .windspeed:
                fallthrough
            case .wind_direction:
                fallthrough
            case .winddirection:
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dew_point:
                fallthrough
            case .dewpoint:
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloud_cover:
                fallthrough
            case .cloudcover:
                fallthrough
            case .relativehumidity:
                try prefetchData(raw: .pressure(JmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
    
    func get(derived: JmaVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .apparent_temperature:
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let relhum = try get(raw: .relative_humidity_2m, time: time).data
                let radiation = try get(raw: .shortwave_radiation, time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try get(raw: .shortwave_radiation, time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimetre)
            case .relativehumidity_2m:
                return try get(raw: .relative_humidity_2m, time: time)
            case .surface_pressure:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let pressure = try get(raw: .pressure_msl, time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                let temperature = try get(raw: .temperature_2m, time: time)
                let rh = try get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try get(raw: .shortwave_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try get(derived: .surface(.direct_radiation), time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .surface(.direct_radiation_instant), time: time)
                let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation:
                let swrad = try get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .surface(.direct_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weather_code:
                fallthrough
            case .weathercode:
                let cloudcover = try get(raw: .cloud_cover, time: time).data
                let precipitation = try get(raw: .precipitation, time: time).data
                let snowfall = try get(derived: .surface(.snowfall), time: time).data
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
            case .snowfall:
                let temperature = try get(raw: .temperature_2m, time: time)
                let precipitation = try get(raw: .precipitation, time: time)
                return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimetre)
            case .rain:
                let temperature = try get(raw: .temperature_2m, time: time)
                let precipitation = try get(raw: .precipitation, time: time)
                return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 1 : 0) }), .millimetre)
            case .showers:
                let precipitation = try get(raw: .precipitation, time: time)
                return DataAndUnit(precipitation.data.map({min($0, 0)}), precipitation.unit)
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .wet_bulb_temperature_2m:
                let temperature = try get(raw: .temperature_2m, time: time)
                let rh = try get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloudcover:
                return try get(raw: .cloud_cover, time: time)
            case .cloudcover_low:
                return try get(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                return try get(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                return try get(raw: .cloud_cover_high, time: time)
            case .sunshine_duration:
                let directRadiation = try get(derived: .surface(.direct_radiation), time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
            case .global_tilted_irradiance:
                let directRadiation = try get(derived: .surface(.direct_radiation), time: time).data
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let directRadiation = try get(derived: .surface(.direct_radiation), time: time).data
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .wind_speed:
                fallthrough
            case .windspeed:
                let u = try get(raw: .pressure(JmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(JmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .wind_direction:
                fallthrough
            case .winddirection:
                let u = try get(raw: .pressure(JmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(JmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dew_point:
                fallthrough
            case .dewpoint:
                let temperature = try get(raw: .pressure(JmaPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(JmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloud_cover:
                fallthrough
            case .cloudcover:
                let rh = try get(raw: .pressure(JmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level))}), .percentage)
            case .relativehumidity:
                return try get(raw: .pressure(JmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}

struct JmaMixer: GenericReaderMixer {
    let reader: [JmaReader]
    
    static func makeReader(domain: JmaReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> JmaReader? {
        return try JmaReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}
