import Foundation
import Vapor

enum KnmiVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case dewpoint_2m
    case dew_point_2m

    case windspeed_10m
    case winddirection_10m
    case windspeed_100m
    case winddirection_100m
    case windspeed_200m
    case winddirection_200m
    case windspeed_300m
    case winddirection_300m
    /// Is using 100m wind
    case windspeed_80m
    case winddirection_80m
    /// Is using 100m wind
    case windspeed_120m
    case winddirection_120m
    /// Is using 200m wind
    case windspeed_180m
    case winddirection_180m

    /// Is using 100m wind
    case wind_speed_80m
    case wind_direction_80m
    /// Is using 100m wind
    case wind_speed_120m
    case wind_direction_120m
    /// Is using 200m wind
    case wind_speed_180m
    case wind_direction_180m

    case temperature_80m
    case temperature_120m
    case temperature_180m
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
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
enum KnmiPressureVariableDerivedType: String, CaseIterable {
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
struct KnmiPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: KnmiPressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias KnmiVariableDerived = SurfaceAndPressureVariable<KnmiVariableDerivedSurface, KnmiPressureVariableDerived>

typealias KnmiVariableCombined = VariableOrDerived<KnmiVariable, KnmiVariableDerived>

struct KnmiReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = KnmiDomain

    typealias Variable = KnmiVariable

    typealias Derived = KnmiVariableDerived

    typealias MixingVar = KnmiVariableCombined

    let reader: GenericReaderCached<KnmiDomain, KnmiVariable>

    let options: GenericReaderOptions

    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        guard let reader = try await GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    public init(domain: Domain, gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<Domain, Variable>(domain: domain, position: gridpoint, options: options)
        self.reader = GenericReaderCached(reader: reader)
        self.options = options
    }

    func get(raw: KnmiVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await reader.get(variable: raw, time: time)
    }

    func prefetchData(raw: KnmiVariable, time: TimerangeDtAndSettings) async throws {
        try await reader.prefetchData(variable: raw, time: time)
    }

    func prefetchData(variable: KnmiSurfaceVariable, time: TimerangeDtAndSettings) async throws {
        try await prefetchData(variable: .raw(.surface(variable)), time: time)
    }

    func get(raw: KnmiSurfaceVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await get(variable: .raw(.surface(raw)), time: time)
    }

    func prefetchData(derived: KnmiVariableDerived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .wind_speed_10m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
                try await prefetchData(variable: .shortwave_radiation, time: time)
            case .relativehumidity_2m:
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .windspeed_10m:
                try await prefetchData(variable: .wind_speed_10m, time: time)
            case .windspeed_80m, .wind_speed_80m, .windspeed_100m, .windspeed_120m, .wind_speed_120m:
                try await prefetchData(variable: .wind_speed_100m, time: time)
            case .windspeed_200m, .windspeed_180m, .wind_speed_180m:
                try await prefetchData(variable: .wind_speed_200m, time: time)
            case .winddirection_10m:
                try await prefetchData(variable: .wind_direction_10m, time: time)
            case .winddirection_80m, .wind_direction_80m, .winddirection_100m, .winddirection_120m, .wind_direction_120m:
                try await prefetchData(variable: .wind_direction_100m, time: time)
            case .winddirection_200m, .winddirection_180m, .wind_direction_180m:
                try await prefetchData(variable: .wind_direction_200m, time: time)
            case .windspeed_300m:
                try await prefetchData(variable: .wind_speed_300m, time: time)
            case .winddirection_300m:
                try await prefetchData(variable: .wind_direction_300m, time: time)
            case .vapor_pressure_deficit, .vapour_pressure_deficit:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try await prefetchData(variable: .shortwave_radiation, time: time)
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
                try await prefetchData(variable: .wind_speed_10m, time: time)
            case .snowfall:
                try await prefetchData(variable: .snowfall_water_equivalent, time: time)
            case .surface_pressure:
                try await prefetchData(variable: .pressure_msl, time: time)
                try await prefetchData(variable: .temperature_2m, time: time)
            case .terrestrial_radiation, .terrestrial_radiation_instant:
                break
            case .dew_point_2m, .dewpoint_2m:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .global_tilted_irradiance, .global_tilted_irradiance_instant, .diffuse_radiation, .diffuse_radiation_instant, .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation, .direct_radiation_instant, .shortwave_radiation_instant:
                try await prefetchData(variable: .shortwave_radiation, time: time)
            case .weather_code, .weathercode:
                try await prefetchData(variable: .cloud_cover, time: time)
                try await prefetchData(variable: .rain, time: time)
                try await prefetchData(variable: .snowfall_water_equivalent, time: time)
                // try await prefetchData(variable: .cape, time: time)
                try await prefetchData(variable: .wind_gusts_10m, time: time)
                try await prefetchData(variable: .visibility, time: time)
            case .is_day:
                break
            case .temperature_80m:
                try await prefetchData(variable: .temperature_100m, time: time)
            case .temperature_120m:
                try await prefetchData(variable: .temperature_100m, time: time)
            case .temperature_180m:
                try await prefetchData(variable: .temperature_200m, time: time)
            case .wet_bulb_temperature_2m:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .cloudcover:
                try await prefetchData(variable: .cloud_cover, time: time)
            case .cloudcover_low:
                try await prefetchData(variable: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                try await prefetchData(variable: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                try await prefetchData(variable: .cloud_cover_high, time: time)
            case .windgusts_10m:
                try await prefetchData(variable: .wind_gusts_10m, time: time)
            case .sunshine_duration:
                try await prefetchData(derived: .surface(.direct_radiation), time: time)
            case .showers:
                try await prefetchData(variable: .rain, time: time)
                try await prefetchData(variable: .precipitation, time: time)
                try await prefetchData(variable: .snowfall_water_equivalent, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                try await prefetchData(raw: .pressure(KnmiPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                try await prefetchData(raw: .pressure(KnmiPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point, .relativehumidity:
                try await prefetchData(raw: .pressure(KnmiPressureVariable(variable: .temperature, level: v.level)), time: time)
                try await prefetchData(raw: .pressure(KnmiPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover, .cloud_cover:
                try await prefetchData(raw: .pressure(KnmiPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: KnmiVariableDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .windspeed_10m:
                return try await get(raw: .wind_speed_10m, time: time)
            case .windspeed_80m, .wind_speed_80m:
                let data = try await get(raw: .wind_speed_100m, time: time)
                let scalefactor = Meteorology.scaleWindFactor(from: 100, to: 80)
                return DataAndUnit(data.data.map { $0 * scalefactor }, data.unit)
            case .windspeed_100m:
                return try await get(raw: .wind_speed_100m, time: time)
            case .windspeed_120m, .wind_speed_120m:
                let data = try await get(raw: .wind_speed_100m, time: time)
                let scalefactor = Meteorology.scaleWindFactor(from: 100, to: 120)
                return DataAndUnit(data.data.map { $0 * scalefactor }, data.unit)
            case .windspeed_180m, .wind_speed_180m:
                let data = try await get(raw: .wind_speed_200m, time: time)
                let scalefactor = Meteorology.scaleWindFactor(from: 200, to: 180)
                return DataAndUnit(data.data.map { $0 * scalefactor }, data.unit)
            case .windspeed_200m:
                return try await get(raw: .wind_speed_200m, time: time)
            case .windspeed_300m:
                return try await get(raw: .wind_speed_300m, time: time)
            case .winddirection_10m:
                return try await get(raw: .wind_direction_10m, time: time)
            case .winddirection_80m, .wind_direction_80m, .winddirection_100m, .winddirection_120m, .wind_direction_120m:
                return try await get(raw: .wind_direction_100m, time: time)
            case .winddirection_200m, .winddirection_180m, .wind_direction_180m:
                return try await get(raw: .wind_direction_200m, time: time)
            case .winddirection_300m:
                return try await get(raw: .wind_direction_300m, time: time)
            case .apparent_temperature:
                let windspeed = try await get(raw: .wind_speed_10m, time: time).data
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
                let windspeed = try await get(raw: .wind_speed_10m, time: time).data
                let rh = try await get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)

                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                let snowfall_water_equivalent = try await get(raw: .snowfall_water_equivalent, time: time).data
                let snowfall = snowfall_water_equivalent.map({ $0 * 0.7 })
                return DataAndUnit(snowfall, SiUnit.centimetre)
            case .relativehumidity_2m:
                return try await get(raw: .relative_humidity_2m, time: time)
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
            case .dewpoint_2m, .dew_point_2m:
                let temperature = try await get(raw: .temperature_2m, time: time)
                let rh = try await get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try await get(raw: .shortwave_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try await get(derived: .surface(.direct_radiation), time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try await get(derived: .surface(.direct_radiation), time: time)
                let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try await get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation:
                let swrad = try await get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try await get(derived: .surface(.direct_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try await get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weathercode, .weather_code:
                let cloudcover = try await get(raw: .cloud_cover, time: time).data
                let precipitation = try await get(raw: .precipitation, time: time).data
                let snowfall = try await get(derived: .surface(.snowfall), time: time).data
                // let cape = try await get(raw: .cape, time: time).data
                let gusts = try await get(raw: .wind_gusts_10m, time: time).data
                let visibility = try await get(raw: .visibility, time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: nil,
                    snowfallCentimeters: snowfall,
                    gusts: gusts,
                    cape: nil,
                    liftedIndex: nil,
                    visibilityMeters: visibility,
                    categoricalFreezingRain: nil,
                    modelDtSeconds: time.dtSeconds), .wmoCode
                )
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .temperature_80m:
                return try await get(raw: .temperature_100m, time: time)
            case .temperature_120m:
                return try await get(raw: .temperature_100m, time: time)
            case .temperature_180m:
                return try await get(raw: .temperature_200m, time: time)
            case .showers:
                let precipitation = try await get(raw: .precipitation, time: time)
                let snow = try await get(raw: .snowfall_water_equivalent, time: time)
                let rain = try await get(raw: .rain, time: time)
                return DataAndUnit(zip(zip(precipitation.data, rain.data), snow.data).map({ max($0.0 - $0.1 - $1, 0) }), precipitation.unit)
            case .wet_bulb_temperature_2m:
                let temperature = try await get(raw: .temperature_2m, time: time)
                let rh = try await get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloudcover:
                return try await get(raw: .cloud_cover, time: time)
            case .cloudcover_low:
                return try await get(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                return try await get(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                return try await get(raw: .cloud_cover_high, time: time)
            case .windgusts_10m:
                return try await get(raw: .wind_gusts_10m, time: time)
            case .sunshine_duration:
                let directRadiation = try await get(derived: .surface(.direct_radiation), time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
            case .global_tilted_irradiance:
                let directRadiation = try await get(derived: .surface(.direct_radiation), time: time).data
                let diffuseRadiation = try await get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let directRadiation = try await get(derived: .surface(.direct_radiation), time: time).data
                let diffuseRadiation = try await get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                return try await get(raw: .pressure(KnmiPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                return try await get(raw: .pressure(KnmiPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point:
                let temperature = try await get(raw: .pressure(KnmiPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try await get(raw: .pressure(KnmiPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover, .cloud_cover:
                let rh = try await get(raw: .pressure(.init(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level)) }), .percentage)
            case .relativehumidity:
                return try await get(raw: .pressure(KnmiPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}

/*struct KnmiMixer: GenericReaderMixer {
    let reader: [KnmiReader]
    
    static func makeReader(domain: KnmiReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> KnmiReader? {
        return try KnmiReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}*/
