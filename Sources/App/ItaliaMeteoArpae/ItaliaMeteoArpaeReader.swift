import Foundation
import Vapor

enum ItaliaMeteoArpaeVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
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
    case is_day
    case wet_bulb_temperature_2m
    case cloud_cover
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case windgusts_10m
    case sunshine_duration
    case surface_temperature

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum ItaliaMeteoArpaePressureVariableDerivedType: String, CaseIterable {
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
struct ItaliaMeteoArpaePressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: ItaliaMeteoArpaePressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias ItaliaMeteoArpaeVariableDerived = SurfaceAndPressureVariable<ItaliaMeteoArpaeVariableDerivedSurface, ItaliaMeteoArpaePressureVariableDerived>

typealias ItaliaMeteoArpaeVariableCombined = VariableOrDerived<ItaliaMeteoArpaeVariable, ItaliaMeteoArpaeVariableDerived>

struct ItaliaMeteoArpaeReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = ItaliaMeteoArpaeDomain

    typealias Variable = ItaliaMeteoArpaeVariable

    typealias Derived = ItaliaMeteoArpaeVariableDerived

    typealias MixingVar = ItaliaMeteoArpaeVariableCombined

    let reader: GenericReaderCached<ItaliaMeteoArpaeDomain, ItaliaMeteoArpaeVariable>

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

    func get(raw: ItaliaMeteoArpaeVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await reader.get(variable: raw, time: time)
    }

    func prefetchData(raw: ItaliaMeteoArpaeVariable, time: TimerangeDtAndSettings) async throws {
        try await reader.prefetchData(variable: raw, time: time)
    }

    func prefetchData(variable: ItaliaMeteoArpaeSurfaceVariable, time: TimerangeDtAndSettings) async throws {
        try await prefetchData(variable: .raw(.surface(variable)), time: time)
    }

    func get(raw: ItaliaMeteoArpaeSurfaceVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await get(variable: .raw(.surface(raw)), time: time)
    }

    func prefetchData(derived: ItaliaMeteoArpaeVariableDerived, time: TimerangeDtAndSettings) async throws {
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
            case .winddirection_10m:
                try await prefetchData(variable: .wind_direction_10m, time: time)
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
            case .global_tilted_irradiance, .global_tilted_irradiance_instant, .direct_normal_irradiance, .direct_radiation_instant, .direct_normal_irradiance_instant:
                try await prefetchData(variable: .direct_radiation, time: time)
            case .shortwave_radiation_instant:
                try await prefetchData(variable: .shortwave_radiation, time: time)
            case .diffuse_radiation, .diffuse_radiation_instant:
                try await prefetchData(variable: .shortwave_radiation, time: time)
                try await prefetchData(variable: .direct_radiation, time: time)
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try await prefetchData(variable: .temperature_2m, time: time)
                try await prefetchData(variable: .relative_humidity_2m, time: time)
            case .cloudcover, .cloud_cover:
                try await prefetchData(variable: .cloud_cover_low, time: time)
                try await prefetchData(variable: .cloud_cover_mid, time: time)
                try await prefetchData(variable: .cloud_cover_high, time: time)
            case .cloudcover_low:
                try await prefetchData(variable: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                try await prefetchData(variable: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                try await prefetchData(variable: .cloud_cover_high, time: time)
            case .windgusts_10m:
                try await prefetchData(variable: .wind_gusts_10m, time: time)
            case .sunshine_duration:
                try await prefetchData(variable: .direct_radiation, time: time)
            case .surface_temperature:
                try await prefetchData(variable: .soil_temperature_0cm, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                try await prefetchData(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                try await prefetchData(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point:
                try await prefetchData(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .temperature, level: v.level)), time: time)
                try await prefetchData(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover, .cloud_cover, .relativehumidity:
                try await prefetchData(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: ItaliaMeteoArpaeVariableDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .windspeed_10m:
                return try await get(raw: .wind_speed_10m, time: time)
            case .winddirection_10m:
                return try await get(raw: .wind_direction_10m, time: time)
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
                let dhi = try await get(raw: .direct_radiation, time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try await get(raw: .surface(.direct_radiation), time: time)
                let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try await get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation_instant:
                let direct = try await get(raw: .direct_radiation, time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try await get(derived: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .wet_bulb_temperature_2m:
                let temperature = try await get(raw: .temperature_2m, time: time)
                let rh = try await get(raw: .relative_humidity_2m, time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloudcover, .cloud_cover:
                let low = try await get(raw: .cloud_cover_low, time: time).data
                let mid = try await get(raw: .cloud_cover_mid, time: time).data
                let high = try await get(raw: .cloud_cover_high, time: time).data
                return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percentage)
            case .cloudcover_low:
                return try await get(raw: .cloud_cover_low, time: time)
            case .cloudcover_mid:
                return try await get(raw: .cloud_cover_mid, time: time)
            case .cloudcover_high:
                return try await get(raw: .cloud_cover_high, time: time)
            case .windgusts_10m:
                return try await get(raw: .wind_gusts_10m, time: time)
            case .sunshine_duration:
                let directRadiation = try await get(raw: .direct_radiation, time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
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
            case .surface_temperature:
                return try await get(raw: .soil_temperature_0cm, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                return try await get(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .wind_speed, level: v.level)), time: time)
            case .winddirection:
                return try await get(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .wind_direction, level: v.level)), time: time)
            case .dewpoint, .dew_point:
                let temperature = try await get(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try await get(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover, .cloud_cover:
                let rh = try await get(raw: .pressure(.init(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level)) }), .percentage)
            case .relativehumidity:
                return try await get(raw: .pressure(ItaliaMeteoArpaePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}
