import Foundation
import Vapor

enum GemVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    case dew_point_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
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
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case snowfall
    case rain
    case weathercode
    case weather_code
    case is_day
    case wet_bulb_temperature_2m

    case relativehumidity_2m
    case cloudcover
    case windspeed_10m
    case winddirection_10m
    case windspeed_40m
    case winddirection_40m
    case windspeed_80m
    case winddirection_80m
    case windspeed_120m
    case winddirection_120m
    case windgusts_10m

    case sunshine_duration

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum GemPressureVariableDerivedType: String, CaseIterable {
    case dewpoint
    case cloudcover
    case dew_point
    case cloud_cover
    case windspeed
    case winddirection
    case relativehumidity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct GemPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: GemPressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias GemVariableDerived = SurfaceAndPressureVariable<GemVariableDerivedSurface, GemPressureVariableDerived>

typealias GemVariableCombined = VariableOrDerived<GemVariable, GemVariableDerived>

struct GemReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    typealias MixingVar = GemVariableCombined

    typealias Domain = GemDomain

    typealias Variable = GemVariable

    typealias Derived = GemVariableDerived

    let reader: GenericReaderCached<GemDomain, Variable>

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

    func prefetchData(derived: Derived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.wind_speed_10m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
                try await prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .dew_point_2m, .dewpoint_2m:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .vapour_pressure_deficit, .vapor_pressure_deficit:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .et0_fao_evapotranspiration:
                try await prefetchData(raw: .surface(.shortwave_radiation), time: time)
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
                try await prefetchData(raw: .surface(.wind_speed_10m), time: time)
            case .surface_pressure:
                try await prefetchData(raw: .surface(.pressure_msl), time: time)
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .diffuse_radiation, .diffuse_radiation_instant, .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation, .direct_radiation_instant, .global_tilted_irradiance, .global_tilted_irradiance_instant, .shortwave_radiation_instant:
                try await prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .snowfall:
                try await prefetchData(raw: .surface(.snowfall_water_equivalent), time: time)
            case .rain:
                try await prefetchData(raw: .surface(.precipitation), time: time)
                try await prefetchData(raw: .surface(.snowfall_water_equivalent), time: time)
                if reader.domain != .gem_global_ensemble {
                    try await prefetchData(raw: .surface(.showers), time: time)
                }
            case .cloud_cover_low, .cloudcover_low:
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 1000)), time: time)
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 950)), time: time)
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 850)), time: time)
            case .cloud_cover_mid, .cloudcover_mid:
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 700)), time: time)
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 600)), time: time)
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 500)), time: time)
            case .cloud_cover_high, .cloudcover_high:
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 400)), time: time)
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 300)), time: time)
                try await prefetchData(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 200)), time: time)
            case .weather_code, .weathercode:
                try await prefetchData(raw: .surface(.cloud_cover), time: time)
                try await prefetchData(raw: .surface(.precipitation), time: time)
                try await prefetchData(derived: .surface(.snowfall), time: time)
                try await prefetchData(raw: .surface(.showers), time: time)
                try await prefetchData(raw: .surface(.cape), time: time)
                try await prefetchData(raw: .surface(.wind_gusts_10m), time: time)
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .relativehumidity_2m:
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .cloudcover:
                try await prefetchData(raw: .surface(.cloud_cover), time: time)
            case .windspeed_10m:
                try await prefetchData(raw: .surface(.wind_speed_10m), time: time)
            case .winddirection_10m:
                try await prefetchData(raw: .surface(.wind_direction_10m), time: time)
            case .windspeed_40m:
                try await prefetchData(raw: .surface(.wind_speed_40m), time: time)
            case .winddirection_40m:
                try await prefetchData(raw: .surface(.wind_direction_40m), time: time)
            case .windspeed_80m:
                try await prefetchData(raw: .surface(.wind_speed_80m), time: time)
            case .winddirection_80m:
                try await prefetchData(raw: .surface(.wind_direction_80m), time: time)
            case .windspeed_120m:
                try await prefetchData(raw: .surface(.wind_speed_120m), time: time)
            case .winddirection_120m:
                try await prefetchData(raw: .surface(.wind_direction_120m), time: time)
            case .windgusts_10m:
                try await prefetchData(raw: .surface(.wind_gusts_10m), time: time)
            case .sunshine_duration:
                try await prefetchData(derived: .surface(.direct_radiation), time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .dew_point, .dewpoint:
                try await prefetchData(raw: .pressure(GemPressureVariable(variable: .temperature, level: v.level)), time: time)
                try await prefetchData(raw: .pressure(GemPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloud_cover, .cloudcover:
                try await prefetchData(raw: .pressure(GemPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .windspeed:
                try await prefetchData(raw: .pressure(GemPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                try await prefetchData(raw: .pressure(GemPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .relativehumidity:
                try await prefetchData(raw: .pressure(GemPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: Derived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .apparent_temperature:
                let windspeed = try await get(raw: .surface(.wind_speed_10m), time: time).data
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let relhum = try await get(raw: .surface(.relative_humidity_2m), time: time).data
                let radiation = try await get(raw: .surface(.shortwave_radiation), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .vapour_pressure_deficit, .vapor_pressure_deficit:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try await get(raw: .surface(.shortwave_radiation), time: time).data
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let windspeed = try await get(raw: .surface(.wind_speed_10m), time: time).data
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)

                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
                }
                return DataAndUnit(et0, .millimetre)
            case .surface_pressure:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let pressure = try await get(raw: .surface(.pressure_msl), time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .shortwave_radiation_instant:
                let sw = try await get(raw: .surface(.shortwave_radiation), time: time)
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
                let swrad = try await get(raw: .surface(.shortwave_radiation), time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation:
                let swrad = try await get(raw: .surface(.shortwave_radiation), time: time)
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
            case .dew_point_2m, .dewpoint_2m:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time)
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .snowfall:
                let snowwater = try await get(raw: .surface(.snowfall_water_equivalent), time: time).data
                let snowfall = snowwater.map { $0 * 0.7 }
                return DataAndUnit(snowfall, .centimetre)
            case .rain:
                let snowwater = try await get(raw: .surface(.snowfall_water_equivalent), time: time).data
                let total = try await get(raw: .surface(.precipitation), time: time).data
                if reader.domain == .gem_global_ensemble {
                    // no showers in ensemble
                    return DataAndUnit(zip(total, snowwater).map(-), .millimetre)
                }
                let showers = try await get(raw: .surface(.showers), time: time).data
                let rain = zip(zip(total, snowwater), showers).map { arg0, showers in
                    let (total, snowwater) = arg0
                    return max(total - snowwater - showers, 0)
                }
                return DataAndUnit(rain, .millimetre)
            case .cloud_cover_low, .cloudcover_low:
                let cl0 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 1000)), time: time)
                let cl1 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 950)), time: time)
                let cl2 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 850)), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percentage)
            case .cloud_cover_mid, .cloudcover_mid:
                let cl0 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 700)), time: time)
                let cl1 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 600)), time: time)
                let cl2 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 500)), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percentage)
            case .cloud_cover_high, .cloudcover_high:
                let cl0 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 400)), time: time)
                let cl1 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 300)), time: time)
                let cl2 = try await get(derived: .pressure(GemPressureVariableDerived(variable: .cloudcover, level: 200)), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percentage)
            case .weather_code, .weathercode:
                let cloudcover = try await get(raw: .surface(.cloud_cover), time: time).data
                let precipitation = try await get(raw: .surface(.precipitation), time: time).data
                let snowfall = try await get(derived: .surface(.snowfall), time: time).data
                let showers = try await get(raw: .surface(.showers), time: time).data
                let cape = try await get(raw: .surface(.cape), time: time).data
                let gusts = try await get(raw: .surface(.wind_gusts_10m), time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: showers,
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
            case .wet_bulb_temperature_2m:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time)
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .relativehumidity_2m:
                return try await get(raw: .surface(.relative_humidity_2m), time: time)
            case .cloudcover:
                return try await get(raw: .surface(.cloud_cover), time: time)
            case .windspeed_10m:
                return try await get(raw: .surface(.wind_speed_10m), time: time)
            case .winddirection_10m:
                return try await get(raw: .surface(.wind_direction_10m), time: time)
            case .windspeed_40m:
                return try await get(raw: .surface(.wind_speed_40m), time: time)
            case .winddirection_40m:
                return try await get(raw: .surface(.wind_direction_40m), time: time)
            case .windspeed_80m:
                return try await get(raw: .surface(.wind_speed_80m), time: time)
            case .winddirection_80m:
                return try await get(raw: .surface(.wind_direction_80m), time: time)
            case .windspeed_120m:
                return try await get(raw: .surface(.wind_speed_120m), time: time)
            case .winddirection_120m:
                return try await get(raw: .surface(.wind_direction_120m), time: time)
            case .windgusts_10m:
                return try await get(raw: .surface(.wind_gusts_10m), time: time)
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
            case .dew_point, .dewpoint:
                let temperature = try await get(raw: .pressure(GemPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try await get(raw: .pressure(GemPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloud_cover, .cloudcover:
                let rh = try await get(raw: .pressure(GemPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level)) }), .percentage)
            case .windspeed:
                return try await get(raw: .pressure(GemPressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                return try await get(raw: .pressure(GemPressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .relativehumidity:
                return try await get(raw: .pressure(GemPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}

struct GemMixer: GenericReaderMixer {
    let reader: [GemReader]

    static func makeReader(domain: GemReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws -> GemReader? {
        return try await GemReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}
