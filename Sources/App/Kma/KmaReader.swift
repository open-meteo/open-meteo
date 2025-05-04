import Foundation
import Vapor

enum KmaVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case dewpoint_2m
    case dew_point_2m
    case windspeed_10m
    case winddirection_10m

    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    // case evapotranspiration
    case et0_fao_evapotranspiration
    case vapour_pressure_deficit
    case vapor_pressure_deficit
    case snowfall
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weathercode
    case weather_code
    case is_day
    case rain
    case wet_bulb_temperature_2m
    case cloud_cover
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case windgusts_10m
    case sunshine_duration

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum KmaPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case wind_speed
    case wind_direction
    case dew_point
    case cloudcover
    case relativehumidity
    case cloud_cover
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct KmaPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: KmaPressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias KmaVariableDerived = SurfaceAndPressureVariable<KmaVariableDerivedSurface, KmaPressureVariableDerived>

typealias KmaVariableCombined = VariableOrDerived<KmaVariable, KmaVariableDerived>

struct KmaReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = KmaDomain

    typealias Variable = KmaVariable

    typealias Derived = KmaVariableDerived

    typealias MixingVar = KmaVariableCombined

    let reader: GenericReaderCached<KmaDomain, KmaVariable>

    let options: GenericReaderOptions

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) throws {
        let reader = try GenericReader<Domain, Variable>(domain: domain, position: gridpoint)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    func get(raw: KmaVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch raw {
        case .surface(let variable):
            if reader.domain == .ldps && variable == .showers {
                /// Set showers to 0 for LDPS domain
                let showers = try reader.get(variable: .surface(.precipitation), time: time).data.map({ max($0, 0) })
                return DataAndUnit(showers, .millimetre)
            }
        case .pressure:
            break
        }

        return try reader.get(variable: raw, time: time)
    }

    func prefetchData(raw: KmaVariable, time: TimerangeDtAndSettings) throws {
        switch raw {
        case .surface(let variable):
            if reader.domain == .ldps && variable == .showers {
                /// Set showers to 0 for LDPS domain
                try reader.prefetchData(variable: .surface(.precipitation), time: time)
            }
        case .pressure:
            break
        }
        try reader.prefetchData(variable: raw, time: time)
    }

    func prefetchData(variable: KmaSurfaceVariable, time: TimerangeDtAndSettings) throws {
        try prefetchData(variable: .raw(.surface(variable)), time: time)
    }

    func get(raw: KmaSurfaceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }

    func prefetchData(derived: KmaVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .wind_speed_10m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .relativehumidity_2m:
                try prefetchData(variable: .relative_humidity_2m, time: time)
            case .windspeed_10m:
                try prefetchData(variable: .wind_speed_10m, time: time)
            case .winddirection_10m:
                try prefetchData(variable: .wind_direction_10m, time: time)
            case .vapor_pressure_deficit, .vapour_pressure_deficit:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(variable: .shortwave_radiation, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
                try prefetchData(variable: .wind_speed_10m, time: time)
            case .snowfall:
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
            case .surface_pressure:
                try prefetchData(variable: .pressure_msl, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
            case .terrestrial_radiation, .terrestrial_radiation_instant:
                break
            case .dew_point_2m, .dewpoint_2m:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
            case .global_tilted_irradiance, .global_tilted_irradiance_instant, .direct_normal_irradiance, .direct_radiation_instant, .direct_normal_irradiance_instant:
                try prefetchData(variable: .direct_radiation, time: time)
            case .shortwave_radiation_instant:
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .diffuse_radiation, .diffuse_radiation_instant:
                try prefetchData(variable: .shortwave_radiation, time: time)
                try prefetchData(variable: .direct_radiation, time: time)
            case .weather_code, .weathercode:
                try prefetchData(variable: .cloud_cover_low, time: time)
                try prefetchData(variable: .cloud_cover_mid, time: time)
                try prefetchData(variable: .cloud_cover_high, time: time)
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
                try prefetchData(variable: .cape, time: time)
                try prefetchData(variable: .visibility, time: time)
                try prefetchData(variable: .wind_gusts_10m, time: time)
                if reader.domain == .gdps {
                    try prefetchData(variable: .showers, time: time)
                }
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
            case .cloudcover, .cloud_cover:
                try prefetchData(variable: .cloud_cover_low, time: time)
                try prefetchData(variable: .cloud_cover_mid, time: time)
                try prefetchData(variable: .cloud_cover_high, time: time)
            case .cloudcover_low:
                try prefetchData(variable: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                try prefetchData(variable: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                try prefetchData(variable: .cloud_cover_high, time: time)
            case .windgusts_10m:
                try prefetchData(variable: .wind_gusts_10m, time: time)
            case .sunshine_duration:
                try prefetchData(variable: .direct_radiation, time: time)
            case .rain:
                if reader.domain == .gdps {
                    try prefetchData(variable: .showers, time: time)
                }
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed, .wind_speed, .winddirection, .wind_direction:
                try prefetchData(raw: .pressure(KmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(KmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dewpoint, .dew_point, .relativehumidity:
                try prefetchData(raw: .pressure(KmaPressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(KmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover, .cloud_cover:
                try prefetchData(raw: .pressure(KmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: KmaVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .windspeed_10m:
                return try get(raw: .wind_speed_10m, time: time)
            case .winddirection_10m:
                return try get(raw: .wind_direction_10m, time: time)
            case .apparent_temperature:
                let windspeed = try get(raw: .wind_speed_10m, time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let relhum = try get(raw: .relative_humidity_2m, time: time).data
                let radiation = try get(raw: .shortwave_radiation, time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .vapor_pressure_deficit, .vapour_pressure_deficit:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try get(raw: .shortwave_radiation, time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let windspeed = try get(raw: .wind_speed_10m, time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)

                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                let snowfall_water_equivalent = try get(raw: .snowfall_water_equivalent, time: time).data
                let snowfall = snowfall_water_equivalent.map({ $0 * 0.7 })
                return DataAndUnit(snowfall, SiUnit.centimetre)
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
            case .dewpoint_2m, .dew_point_2m:
                let temperature = try get(raw: .temperature_2m, time: time)
                let rh = try get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try get(raw: .shortwave_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try get(raw: .direct_radiation, time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try get(raw: .surface(.direct_radiation), time: time)
                let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation_instant:
                let direct = try get(raw: .direct_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weathercode, .weather_code:
                let cloudcover = try get(derived: .surface(.cloud_cover), time: time).data
                let precipitation = try get(derived: .surface(.rain), time: time).data
                let snowfall = try get(derived: .surface(.snowfall), time: time).data
                let cape = try get(raw: .cape, time: time).data
                let gusts = try get(raw: .wind_gusts_10m, time: time).data
                let visibility = try get(raw: .visibility, time: time).data
                let showers = reader.domain == .gdps ? try get(raw: .showers, time: time).data : nil
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: showers,
                    snowfallCentimeters: snowfall,
                    gusts: gusts,
                    cape: cape,
                    liftedIndex: nil,
                    visibilityMeters: visibility,
                    categoricalFreezingRain: nil,
                    modelDtSeconds: time.dtSeconds), .wmoCode
                )
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .wet_bulb_temperature_2m:
                let temperature = try get(raw: .temperature_2m, time: time)
                let rh = try get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloudcover, .cloud_cover:
                let low = try get(raw: .cloud_cover_low, time: time).data
                let mid = try get(raw: .cloud_cover_mid, time: time).data
                let high = try get(raw: .cloud_cover_high, time: time).data
                return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percentage)
            case .cloudcover_low:
                return try get(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                return try get(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                return try get(raw: .cloud_cover_high, time: time)
            case .windgusts_10m:
                return try get(raw: .wind_gusts_10m, time: time)
            case .sunshine_duration:
                let directRadiation = try get(raw: .direct_radiation, time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
            case .rain:
                let precip = try get(raw: .precipitation, time: time)
                let snoweq = try get(raw: .snowfall_water_equivalent, time: time)
                if reader.domain == .gdps {
                    let showers = try get(raw: .showers, time: time)
                    return DataAndUnit(zip(precip.data, zip(snoweq.data, showers.data)).map({ $0 - $1.0 - $1.1 }), precip.unit)
                }
                return DataAndUnit(zip(precip.data, snoweq.data).map(-), precip.unit)
            case .global_tilted_irradiance:
                let directRadiation = try get(raw: .direct_radiation, time: time).data
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let directRadiation = try get(raw: .direct_radiation, time: time).data
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed, .wind_speed:
                let u = try get(raw: .pressure(KmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(KmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data, v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection, .wind_direction:
                let u = try get(raw: .pressure(KmaPressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(KmaPressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint, .dew_point:
                let temperature = try get(raw: .pressure(KmaPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(KmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover, .cloud_cover:
                let rh = try get(raw: .pressure(.init(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level)) }), .percentage)
            case .relativehumidity:
                return try get(raw: .pressure(KmaPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}

/*struct KmaMixer: GenericReaderMixer {
    let reader: [KmaReader]
    
    static func makeReader(domain: KmaReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> KmaReader? {
        return try KmaReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}*/
