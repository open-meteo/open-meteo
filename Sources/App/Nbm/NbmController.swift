import Foundation
import Vapor

enum NbmVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case dew_point_2m
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case diffuse_radiation
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case shortwave_radiation_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case rain
    case showers
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weathercode
    case weather_code
    case is_day
    case wet_bulb_temperature_2m
    case sunshine_duration

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum NbmPressureVariableDerivedType: String, CaseIterable {
    case windspeed
    case winddirection
    case dewpoint
    case wind_speed
    case wind_direction
    case dew_point
    case cloudcover
    case relativehumidity
}

/**
 A pressure level variable on a given level in hPa / mb
 */
struct NbmPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: NbmPressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/// Read GFS domains and perform domain specific corrections
struct NbmReaderLowLevel: GenericReaderProtocol {
    var modelLat: Float {
        reader.modelLat
    }

    var modelLon: Float {
        reader.modelLon
    }

    var modelElevation: ElevationOrSea {
        reader.modelElevation
    }

    var targetElevation: Float {
        reader.targetElevation
    }

    var modelDtSeconds: Int {
        reader.modelDtSeconds
    }

    func getStatic(type: ReaderStaticVariable) throws -> Float? {
        return try reader.getStatic(type: type)
    }

    typealias MixingVar = NbmVariable

    let reader: GenericReaderCached<NbmDomain, NbmVariable>
    let domain: NbmDomain

    func get(variable raw: NbmVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try reader.get(variable: raw, time: time)
    }

    func prefetchData(variable raw: NbmVariable, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
}

typealias NbmVariableDerived = SurfaceAndPressureVariable<NbmVariableDerivedSurface, NbmPressureVariableDerived>

typealias NbmVariableCombined = VariableOrDerived<NbmVariable, NbmVariableDerived>

struct NbmReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = NbmDomain

    typealias Variable = NbmVariable

    typealias Derived = NbmVariableDerived

    typealias MixingVar = NbmVariableCombined

    let reader: GenericReaderMixerSameDomain<NbmReaderLowLevel>

    let options: GenericReaderOptions

    public init?(domains: [Domain], lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws {
        let readers: [NbmReaderLowLevel] = try domains.compactMap { domain in
            guard let reader = try GenericReader<NbmDomain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                return nil
            }
            return NbmReaderLowLevel(reader: GenericReaderCached(reader: reader), domain: domain)
        }
        guard !readers.isEmpty else {
            return nil
        }
        self.reader = GenericReaderMixerSameDomain(reader: readers)
        self.options = options
    }

    public init?(domain: Domain, gridpoint: Int, options: GenericReaderOptions) throws {
        let reader = try GenericReader<NbmDomain, Variable>(domain: domain, position: gridpoint)
        self.reader = GenericReaderMixerSameDomain(reader: [NbmReaderLowLevel(reader: GenericReaderCached(reader: reader), domain: domain)])
        self.options = options
    }

    func prefetchData(raw: NbmReaderLowLevel.MixingVar, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: raw, time: time)
    }

    func get(raw: NbmReaderLowLevel.MixingVar, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try reader.get(variable: raw, time: time)
    }

    func prefetchData(derived: Derived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.wind_speed_10m), time: time)
                try prefetchData(raw: .surface(.relative_humidity_2m), time: time)
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .vapour_pressure_deficit, .vapor_pressure_deficit:
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.relative_humidity_2m), time: time)
                try prefetchData(raw: .surface(.wind_speed_10m), time: time)
            case .rain:
                try prefetchData(raw: .surface(.precipitation), time: time)
                try prefetchData(raw: .surface(.snowfall), time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .dew_point_2m:
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .diffuse_radiation_instant:
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation, .global_tilted_irradiance, .global_tilted_irradiance_instant, .direct_radiation_instant:
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .shortwave_radiation_instant:
                try prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .weather_code, .weathercode:
                try prefetchData(raw: .surface(.cloud_cover), time: time)
                try prefetchData(raw: .surface(.precipitation), time: time)
                try prefetchData(raw: .surface(.snowfall), time: time)
                try prefetchData(raw: .surface(.cape), time: time)
                try prefetchData(raw: .surface(.wind_gusts_10m), time: time)
                try prefetchData(raw: .surface(.visibility), time: time)
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try prefetchData(raw: .surface(.temperature_2m), time: time)
                try prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .sunshine_duration:
                try prefetchData(derived: .surface(.direct_radiation), time: time)
            case .diffuse_radiation:
                try prefetchData(derived: .surface(.direct_radiation), time: time)
            case .showers:
                try prefetchData(raw: .surface(.precipitation), time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .wind_speed, .windspeed, .wind_direction, .winddirection:
                try prefetchData(raw: .pressure(NbmPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(NbmPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dew_point, .dewpoint:
                try prefetchData(raw: .pressure(NbmPressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(NbmPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover:
                try prefetchData(raw: .pressure(NbmPressureVariable(variable: .cloud_cover, level: v.level)), time: time)
            case .relativehumidity:
                try prefetchData(raw: .pressure(NbmPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: Derived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .surface(let gfsVariableDerivedSurface):
            switch gfsVariableDerivedSurface {
            case .apparent_temperature:
                let windspeed = try get(raw: .surface(.wind_speed_10m), time: time).data
                let temperature = try get(raw: .surface(.temperature_2m), time: time).data
                let relhum = try get(raw: .surface(.relative_humidity_2m), time: time).data
                let radiation = try get(raw: .surface(.shortwave_radiation), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .vapour_pressure_deficit, .vapor_pressure_deficit:
                let temperature = try get(raw: .surface(.temperature_2m), time: time).data
                let rh = try get(raw: .surface(.relative_humidity_2m), time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try get(raw: .surface(.shortwave_radiation), time: time).data
                let temperature = try get(raw: .surface(.temperature_2m), time: time).data
                let windspeed = try get(raw: .surface(.wind_speed_10m), time: time).data
                let rh = try get(raw: .surface(.relative_humidity_2m), time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)

                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
                }
                return DataAndUnit(et0, .millimetre)
            case .rain:
                let snow_fall = try get(raw: .surface(.snowfall), time: time).data
                let precipitation = try get(raw: .surface(.precipitation), time: time).data
                let rain = zip(precipitation, snow_fall).map({ $0 - $1 / 0.7 })
                return DataAndUnit(rain, .millimetre)
            case .terrestrial_radiation:
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .terrestrial_radiation_instant:
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .dew_point_2m:
                let temperature = try get(raw: .surface(.temperature_2m), time: time)
                let rh = try get(raw: .surface(.relative_humidity_2m), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try get(raw: .surface(.shortwave_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try get(derived: .surface(.direct_radiation), time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .surface(.direct_radiation), time: time)
                let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
                return DataAndUnit(dni, direct.unit)
            case .direct_radiation:
                let diffuse = try get(derived: .surface(.diffuse_radiation), time: time)
                let swrad = try get(raw: .surface(.shortwave_radiation), time: time)
                return DataAndUnit(zip(swrad.data, diffuse.data).map(-), diffuse.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .surface(.direct_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weather_code, .weathercode:
                let cloudcover = try get(raw: .surface(.cloud_cover), time: time).data
                let precipitation = try get(raw: .surface(.precipitation), time: time).data
                let snowfall = try get(raw: .surface(.snowfall), time: time).data
                let cape = try get(raw: .surface(.cape), time: time).data
                let gusts = try get(raw: .surface(.wind_gusts_10m), time: time).data
                let visibility = try get(raw: .surface(.visibility), time: time).data
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
            case .wet_bulb_temperature_2m:
                let temperature = try get(raw: .surface(.temperature_2m), time: time)
                let rh = try get(raw: .surface(.relative_humidity_2m), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .sunshine_duration:
                let directRadiation = try get(derived: .surface(.direct_radiation), time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
            case .global_tilted_irradiance:
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let ghi = try get(raw: .surface(.shortwave_radiation), time: time).data
                let directRadiation = zip(ghi, diffuseRadiation).map(-)
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let ghi = try get(raw: .surface(.shortwave_radiation), time: time).data
                let directRadiation = zip(ghi, diffuseRadiation).map(-)
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .diffuse_radiation:
                let swrad = try get(raw: .surface(.shortwave_radiation), time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, swrad.unit)
            case .showers:
                let precipitation = try get(raw: .surface(.precipitation), time: time).data
                return DataAndUnit(precipitation.map { $0 * 0 }, .millimetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .wind_speed, .windspeed:
                let u = try get(raw: .pressure(NbmPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(NbmPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data, v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .wind_direction, .winddirection:
                let u = try get(raw: .pressure(NbmPressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(NbmPressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dew_point, .dewpoint:
                let temperature = try get(raw: .pressure(NbmPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(NbmPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover:
                return try get(raw: .pressure(NbmPressureVariable(variable: .cloud_cover, level: v.level)), time: time)
            case .relativehumidity:
                return try get(raw: .pressure(NbmPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}
