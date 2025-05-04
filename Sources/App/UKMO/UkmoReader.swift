import Foundation
import Vapor

enum UkmoVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
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
    case showers
    case wet_bulb_temperature_2m
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
enum UkmoPressureVariableDerivedType: String, CaseIterable {
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
struct UkmoPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: UkmoPressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias UkmoVariableDerived = SurfaceAndPressureVariable<UkmoVariableDerivedSurface, UkmoPressureVariableDerived>

typealias UkmoVariableCombined = VariableOrDerived<UkmoVariable, UkmoVariableDerived>

struct UkmoReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = UkmoDomain

    typealias Variable = UkmoVariable

    typealias Derived = UkmoVariableDerived

    typealias MixingVar = UkmoVariableCombined

    let reader: GenericReaderCached<UkmoDomain, UkmoVariable>

    let options: GenericReaderOptions

    let domain: UkmoDomain

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
        self.domain = domain
    }

    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) throws {
        let reader = try GenericReader<Domain, Variable>(domain: domain, position: gridpoint)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
        self.domain = domain
    }

    func get(raw: UkmoVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        if case let .surface(variable) = raw {
            if domain == .global_deterministic_10km || domain == .global_ensemble_20km {
                // Global domain does not have amounts for showers and snowfall.
                // Precip and rain are available. The remainder must be either snow or showers.
                // Use temperature < 0°C to estimate snow or showers
                switch variable {
                case .showers, .snowfall_water_equivalent:
                    let temperature = try get(raw: .temperature_2m, time: time).data
                    let rain = try get(raw: .rain, time: time).data
                    let precipitation = try get(raw: .precipitation, time: time).data
                    return variable == .showers ?
                    DataAndUnit(zip(temperature, zip(precipitation, rain)).map({
                        $0 > 0 ? $1.0 - $1.1 : 0
                    }), .millimetre) :
                    DataAndUnit(zip(temperature, zip(precipitation, rain)).map({
                        $0 <= 0 ? $1.0 - $1.1 : 0
                    }), .millimetre)
                default: break
                }
            }
            if domain == .uk_ensemble_2km || domain == .global_ensemble_20km {
                // no precipitation total
                if variable == .precipitation {
                    let rain = try get(raw: .rain, time: time).data
                    let snow = try get(raw: .snowfall_water_equivalent, time: time).data
                    return DataAndUnit(zip(rain, snow).map(+), .millimetre)
                }
                // no showers, use rain to preserve NaNs and set everything to 0
                if variable == .showers {
                    let rain = try get(raw: .rain, time: time).data
                    return DataAndUnit(rain.map({min($0, 0)}), .millimetre)
                }
                
            }
        }
        return try reader.get(variable: raw, time: time)
    }

    func prefetchData(raw: UkmoVariable, time: TimerangeDtAndSettings) throws {
        if case let .surface(variable) = raw {
            if domain == .global_deterministic_10km {
                // Global domain does not have amounts for showers and snowfall.
                // Precip and rain are available. The remainder must be either snow or showers.
                // Use temperature < 0°C to estimate snow or showers
                switch variable {
                case .showers, .snowfall_water_equivalent:
                    try reader.prefetchData(variable: .surface(.precipitation), time: time)
                    try reader.prefetchData(variable: .surface(.rain), time: time)
                    try reader.prefetchData(variable: .surface(.temperature_2m), time: time)
                    return
                default: break
                }
            }
            if domain == .uk_ensemble_2km {
                if variable == .precipitation {
                    try reader.prefetchData(variable: .surface(.rain), time: time)
                    try reader.prefetchData(variable: .surface(.snowfall_water_equivalent), time: time)
                }
                if variable == .showers {
                    try reader.prefetchData(variable: .surface(.rain), time: time)
                }
            }
        }
        try reader.prefetchData(variable: raw, time: time)
    }

    func prefetchData(variable: UkmoSurfaceVariable, time: TimerangeDtAndSettings) throws {
        try prefetchData(variable: .raw(.surface(variable)), time: time)
    }

    func get(raw: UkmoSurfaceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }

    func prefetchData(derived: UkmoVariableDerived, time: TimerangeDtAndSettings) throws {
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
            case .global_tilted_irradiance, .global_tilted_irradiance_instant, .diffuse_radiation, .diffuse_radiation_instant:
                try prefetchData(variable: .direct_radiation, time: time)
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation_instant, .shortwave_radiation_instant:
                try prefetchData(variable: .direct_radiation, time: time)
            case .weather_code, .weathercode:
                try prefetchData(variable: .cloud_cover, time: time)
                try prefetchData(variable: .rain, time: time)
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
                // try prefetchData(variable: .cape, time: time)
                try prefetchData(variable: .wind_gusts_10m, time: time)
                try prefetchData(variable: .visibility, time: time)
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
            case .cloudcover:
                try prefetchData(variable: .cloud_cover, time: time)
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
            case .showers:
                try prefetchData(variable: .rain, time: time)
            case .winddirection_10m:
                try prefetchData(variable: .wind_direction_10m, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                try prefetchData(raw: .pressure(UkmoPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                try prefetchData(raw: .pressure(UkmoPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point, .relativehumidity:
                try prefetchData(raw: .pressure(UkmoPressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(UkmoPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover, .cloud_cover:
                try prefetchData(raw: .pressure(UkmoPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: UkmoVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
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
                let direct = try get(raw: .direct_radiation, time: time)
                return DataAndUnit(zip(swrad.data, direct.data).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try get(raw: .direct_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weathercode, .weather_code:
                let cloudcover = try get(raw: .cloud_cover, time: time).data
                let precipitation = try get(raw: .precipitation, time: time).data
                let snowfall = try get(derived: .surface(.snowfall), time: time).data
                let cape = try get(raw: .cape, time: time).data
                let gusts = try get(raw: .wind_gusts_10m, time: time).data
                let visibility = try get(raw: .visibility, time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: nil,
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
            case .showers:
                let precipitation = try get(raw: .rain, time: time)
                return DataAndUnit(precipitation.data.map({ min($0, 0) }), precipitation.unit)
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
            case .windgusts_10m:
                return try get(raw: .wind_gusts_10m, time: time)
            case .sunshine_duration:
                let directRadiation = try get(raw: .direct_radiation, time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
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
            case .windspeed:
                return try get(raw: .pressure(UkmoPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                return try get(raw: .pressure(UkmoPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point:
                let temperature = try get(raw: .pressure(UkmoPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(UkmoPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover, .cloud_cover:
                let rh = try get(raw: .pressure(.init(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level)) }), .percentage)
            case .relativehumidity:
                return try get(raw: .pressure(UkmoPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}

/*struct UkmoMixer: GenericReaderMixer {
    let reader: [UkmoReader]
    
    static func makeReader(domain: UkmoReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> UkmoReader? {
        return try UkmoReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}*/
