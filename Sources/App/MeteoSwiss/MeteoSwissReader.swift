import Foundation
import Vapor

enum MeteoSwissVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case dew_point_2m
    case wind_speed_10m
    case wind_direction_10m
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case et0_fao_evapotranspiration
    case vapour_pressure_deficit
    case vapor_pressure_deficit
    case snowfall
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weather_code
    case is_day
    case showers
    case rain
    case wet_bulb_temperature_2m

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum MeteoSwissPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case dew_point
    case cloudcover
    case relativehumidity
    case cloud_cover
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct MeteoSwissPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: MeteoSwissPressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias MeteoSwissVariableDerived = SurfaceAndPressureVariable<MeteoSwissVariableDerivedSurface, MeteoSwissPressureVariableDerived>

typealias MeteoSwissVariableCombined = VariableOrDerived<MeteoSwissVariable, MeteoSwissVariableDerived>

struct MeteoSwissReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = MeteoSwissDomain

    typealias Variable = MeteoSwissVariable

    typealias Derived = MeteoSwissVariableDerived

    typealias MixingVar = MeteoSwissVariableCombined

    let reader: GenericReaderCached<MeteoSwissDomain, MeteoSwissVariable>

    let options: GenericReaderOptions

    let domain: MeteoSwissDomain

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
        self.domain = domain
    }

    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<Domain, Variable>(domain: domain, position: gridpoint, options: options)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
        self.domain = domain
    }

    func get(raw: MeteoSwissVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await reader.get(variable: raw, time: time)
    }

    func prefetchData(raw: MeteoSwissVariable, time: TimerangeDtAndSettings) async throws {
        try await reader.prefetchData(variable: raw, time: time)
    }

    func prefetchData(variable: MeteoSwissSurfaceVariable, time: TimerangeDtAndSettings) async throws {
        try await prefetchData(variable: .raw(.surface(variable)), time: time)
    }

    func get(raw: MeteoSwissSurfaceVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await get(variable: .raw(.surface(raw)), time: time)
    }

    func prefetchData(derived: MeteoSwissVariableDerived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .wind_u_component_10m, time: time)
                try await prefetchData(variable: .wind_v_component_10m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
                try await prefetchData(variable: .shortwave_radiation, time: time)
            case .vapor_pressure_deficit, .vapour_pressure_deficit:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try await prefetchData(variable: .shortwave_radiation, time: time)
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
                try await prefetchData(variable: .wind_u_component_10m, time: time)
                try await prefetchData(variable: .wind_v_component_10m, time: time)
            case .snowfall, .rain:
                try await prefetchData(variable: .precipitation, time: time)
                try await prefetchData(variable: .snowfall_height, time: time)
            case .surface_pressure:
                try await prefetchData(variable: .pressure_msl, time: time)
                try await prefetchData(variable: .temperature_2m, time: time)
            case .terrestrial_radiation, .terrestrial_radiation_instant:
                break
            case .dew_point_2m:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .global_tilted_irradiance, .global_tilted_irradiance_instant, .diffuse_radiation, .diffuse_radiation_instant:
                try await prefetchData(variable: .direct_radiation, time: time)
                try await prefetchData(variable: .shortwave_radiation, time: time)
            case .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation_instant, .shortwave_radiation_instant:
                try await prefetchData(variable: .direct_radiation, time: time)
            case .weather_code:
                try await prefetchData(variable: .cloud_cover, time: time)
                try await prefetchData(variable: .precipitation, time: time)
                try await prefetchData(variable: .snowfall_height, time: time)
                try await prefetchData(variable: .cape, time: time)
                try await prefetchData(variable: .wind_gusts_10m, time: time)
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .showers:
                try await prefetchData(variable: .precipitation, time: time)
            case .wind_speed_10m, .wind_direction_10m:
                try await prefetchData(variable: .wind_u_component_10m, time: time)
                try await prefetchData(variable: .wind_v_component_10m, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                try await prefetchData(raw: .pressure(MeteoSwissPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                try await prefetchData(raw: .pressure(MeteoSwissPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point, .relativehumidity:
                try await prefetchData(raw: .pressure(MeteoSwissPressureVariable(variable: .temperature, level: v.level)), time: time)
                try await prefetchData(raw: .pressure(MeteoSwissPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover, .cloud_cover:
                try await prefetchData(raw: .pressure(MeteoSwissPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: MeteoSwissVariableDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .wind_speed_10m:
                let u = try await get(raw: .wind_u_component_10m, time: time).data
                let v = try await get(raw: .wind_v_component_10m, time: time).data
                let speed = zip(u, v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_10m:
                let u = try await get(raw: .wind_u_component_10m, time: time).data
                let v = try await get(raw: .wind_v_component_10m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .apparent_temperature:
                let windspeed = try await get(derived: .surface(.wind_speed_10m), time: time).data
                let temperature = try await get(raw: .temperature_2m, time: time).data
                let relhum = try await get(raw: .relative_humidity_2m, time: time).data
                let radiation = try await get(raw: .shortwave_radiation, time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .vapor_pressure_deficit, .vapour_pressure_deficit:
                let temperature = try await get(raw: .temperature_2m, time: time).data
                let rh = try await get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try await get(raw: .shortwave_radiation, time: time).data
                let temperature = try await get(raw: .temperature_2m, time: time).data
                let windspeed = try await get(derived: .surface(.wind_speed_10m), time: time).data
                let rh = try await get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)

                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                let precipitation = try await get(raw: .precipitation, time: time)
                let snowfall_height = try await get(raw: .snowfall_height, time: time)
                let elevation = reader.targetElevation
                let snowfall = zip(snowfall_height.data, precipitation.data).map {
                    $0 > elevation ? $1*0.7 : 0
                }
                return DataAndUnit(snowfall, SiUnit.centimetre)
            case .rain:
                let precipitation = try await get(raw: .precipitation, time: time)
                let snowfall_height = try await get(raw: .snowfall_height, time: time)
                let elevation = reader.targetElevation
                let snowfall = zip(snowfall_height.data, precipitation.data).map {
                    $0 > elevation ? 0 : $1
                }
                return DataAndUnit(snowfall, SiUnit.centimetre)
            case .surface_pressure:
                let temperature = try await get(raw: .temperature_2m, time: time).data
                let pressure = try await get(raw: .pressure_msl, time: time)
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
                let temperature = try await get(raw: .temperature_2m, time: time)
                let rh = try await get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try await get(raw: .shortwave_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try await get(raw: .direct_radiation, time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try await get(raw: .surface(.direct_radiation), time: time)
                let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try await get(raw: .shortwave_radiation, time: time)
                let direct = try await get(raw: .direct_radiation, time: time)
                return DataAndUnit(zip(swrad.data, direct.data).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try await get(raw: .direct_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try await get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weather_code:
                let cloudcover = try await get(raw: .cloud_cover, time: time).data
                let precipitation = try await get(raw: .precipitation, time: time).data
                let snowfall = try await get(derived: .surface(.snowfall), time: time).data
                let cape = try await get(raw: .cape, time: time).data
                let gusts = try await get(raw: .wind_gusts_10m, time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: nil,
                    snowfallCentimeters: snowfall,
                    gusts: gusts,
                    cape: cape,
                    liftedIndex: nil,
                    visibilityMeters: nil,
                    categoricalFreezingRain: nil,
                    modelDtSeconds: time.dtSeconds), .wmoCode
                )
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .showers:
                let precipitation = try await get(raw: .precipitation, time: time)
                return DataAndUnit(precipitation.data.map({ min($0, 0) }), precipitation.unit)
            case .wet_bulb_temperature_2m:
                let temperature = try await get(raw: .temperature_2m, time: time)
                let rh = try await get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .global_tilted_irradiance:
                let directRadiation = try await get(raw: .direct_radiation, time: time).data
                let diffuseRadiation = try await get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let directRadiation = try await get(raw: .direct_radiation, time: time).data
                let diffuseRadiation = try await get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                return try await get(raw: .pressure(MeteoSwissPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                return try await get(raw: .pressure(MeteoSwissPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point:
                let temperature = try await get(raw: .pressure(MeteoSwissPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try await get(raw: .pressure(MeteoSwissPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover, .cloud_cover:
                let rh = try await get(raw: .pressure(.init(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level)) }), .percentage)
            case .relativehumidity:
                return try await get(raw: .pressure(MeteoSwissPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}
