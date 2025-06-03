import Foundation
import Vapor

enum GfsVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    case temperature_120m
    case windspeed_10m
    case winddirection_10m
    case windspeed_80m
    case winddirection_80m
    case windspeed_100m
    case winddirection_100m
    // Map 100m wind to 120m level
    case windspeed_120m
    case winddirection_120m
    case relativehumidity_2m
    case dew_point_2m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_80m
    case wind_direction_80m
    case wind_speed_100m
    case wind_direction_100m
    case wind_speed_120m
    case wind_direction_120m
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case shortwave_radiation_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case evapotranspiration
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case snowfall
    case rain
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weathercode
    case weather_code
    case is_day
    case wet_bulb_temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case sensible_heatflux
    case latent_heatflux
    case windgusts_10m
    case freezinglevel_height
    case mass_density_8m

    case sunshine_duration

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/**
 Types of pressure level variables
 */
enum GfsPressureVariableDerivedType: String, CaseIterable {
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
struct GfsPressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: GfsPressureVariableDerivedType
    let level: Int

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/// Read GFS domains and perform domain specific corrections
struct GfsReaderLowLevel: GenericReaderProtocol {
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

    func getStatic(type: ReaderStaticVariable) async throws -> Float? {
        return try await reader.getStatic(type: type)
    }

    typealias MixingVar = GfsVariable

    let reader: GenericReaderCached<GfsDomain, GfsVariable>
    let domain: GfsDomain

    func get(variable raw: GfsVariable, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        /// HRRR domain has no cloud cover for pressure levels, calculate from RH
        if domain == .hrrr_conus, case let .pressure(pressure) = raw, pressure.variable == .cloud_cover {
            let rh = try await reader.get(variable: .pressure(GfsPressureVariable(variable: .relative_humidity, level: pressure.level)), time: time)
            return DataAndUnit(rh.data.map({ Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(pressure.level)) }), .percentage)
        }

        /// Make sure showers are `0` instead of `NaN` in HRRR, otherwise it is mixed with GFS showers
        if domain == .hrrr_conus || domain == .hrrr_conus_15min, case let .surface(variable) = raw, variable == .showers {
            let precipitation = try await reader.get(variable: .surface(.precipitation), time: time)
            return DataAndUnit(precipitation.data.map({ min($0, 0) }), precipitation.unit)
        }

        /// Adjust surface pressure to target elevation. Surface pressure is stored for `modelElevation`, but we want to get the pressure on `targetElevation`
        /*if case let .surface(variable) = raw.variable, variable == .pressure_msl {
            let pressure = try reader.get(variable: raw, time: time)
            
            let factor = Meteorology.sealevelPressureFactor(temperature: 20 - 0.0065 * (reader.modelElevation.numeric - reader.modelElevation.numeric), elevation: reader.modelElevation.numeric) / Meteorology.sealevelPressureFactor(temperature: 20, elevation: reader.targetElevation)
            print("target \(reader.targetElevation) model \(reader.modelElevation.numeric) factor \(factor)")
            return DataAndUnit(pressure.data.map({$0*factor}), pressure.unit)
        }*/

        /// GFS ensemble has no diffuse radiation
        if domain == .gfs025_ens || domain == .gfs05_ens, case let .surface(variable) = raw, variable == .diffuse_radiation {
            let ghi = try await reader.get(variable: .surface(.shortwave_radiation), time: time)
            let dhi = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: ghi.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(dhi, ghi.unit)
        }

        /// Only GFS013 has showers
        if domain != .gfs013, case let .surface(variable) = raw, variable == .showers {
            // Use precip to return an array with 0, but preserve NaNs if the timerange is unavailable
            let precip = try await reader.get(variable: .surface(.precipitation), time: time)
            return DataAndUnit(precip.data.map({ $0 * 0 }), precip.unit)
        }

        return try await reader.get(variable: raw, time: time)
    }

    func prefetchData(variable raw: GfsVariable, time: TimerangeDtAndSettings) async throws {
        /// HRRR domain has no cloud cover for pressure levels, calculate from RH
        if domain == .hrrr_conus, case let .pressure(pressure) = raw, pressure.variable == .cloud_cover {
            return try await reader.prefetchData(variable: .pressure(GfsPressureVariable(variable: .relative_humidity, level: pressure.level)), time: time)
        }

        /// Make sure showers are `0` in HRRR, otherwise it is mixed with GFS showers
        if domain == .hrrr_conus || domain == .hrrr_conus_15min, case let .surface(variable) = raw, variable == .showers {
            return try await reader.prefetchData(variable: .surface(.precipitation), time: time)
        }

        /// GFS ensemble has no diffuse radiation
        if domain == .gfs025_ens || domain == .gfs05_ens, case let .surface(variable) = raw, variable == .diffuse_radiation {
            return try await reader.prefetchData(variable: .surface(.shortwave_radiation), time: time)
        }

        /// Only GFS013 has showers
        if domain != .gfs013, case let .surface(variable) = raw, variable == .showers {
            return try await reader.prefetchData(variable: .surface(.precipitation), time: time)
        }

        try await reader.prefetchData(variable: raw, time: time)
    }
}

typealias GfsVariableDerived = SurfaceAndPressureVariable<GfsVariableDerivedSurface, GfsPressureVariableDerived>

typealias GfsVariableCombined = VariableOrDerived<GfsVariable, GfsVariableDerived>

struct GfsReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = GfsDomain

    typealias Variable = GfsVariable

    typealias Derived = GfsVariableDerived

    typealias MixingVar = GfsVariableCombined

    let reader: GenericReaderMixerSameDomain<GfsReaderLowLevel>

    let options: GenericReaderOptions

    public init?(domains: [Domain], lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) async throws {
        let readers: [GfsReaderLowLevel] = try await domains.asyncCompactMap { domain in
            guard let reader = try await GenericReader<GfsDomain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options) else {
                return nil
            }
            return GfsReaderLowLevel(reader: GenericReaderCached(reader: reader), domain: domain)
        }
        guard !readers.isEmpty else {
            return nil
        }
        self.reader = GenericReaderMixerSameDomain(reader: readers)
        self.options = options
    }

    public init?(domain: Domain, gridpoint: Int, options: GenericReaderOptions) async throws {
        let reader = try await GenericReader<GfsDomain, Variable>(domain: domain, position: gridpoint, options: options)
        self.reader = GenericReaderMixerSameDomain(reader: [GfsReaderLowLevel(reader: GenericReaderCached(reader: reader), domain: domain)])
        self.options = options
    }

    func prefetchData(raw: GfsReaderLowLevel.MixingVar, time: TimerangeDtAndSettings) async throws {
        try await reader.prefetchData(variable: raw, time: time)
    }

    func get(raw: GfsReaderLowLevel.MixingVar, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        return try await reader.get(variable: raw, time: time)
    }

    func prefetchData(derived: Derived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_10m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
                try await prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .relativehumidity_2m:
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .wind_speed_10m, .windspeed_10m:
                try await prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_10m), time: time)
            case .wind_direction_10m, .winddirection_10m:
                try await prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_10m), time: time)
            case .wind_speed_80m, .windspeed_80m:
                try await prefetchData(raw: .surface(.wind_u_component_80m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_80m), time: time)
            case .wind_direction_80m, .winddirection_80m:
                try await prefetchData(raw: .surface(.wind_u_component_80m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_80m), time: time)
            case .wind_speed_120m, .windspeed_120m, .wind_speed_100m, .windspeed_100m:
                try await prefetchData(raw: .surface(.wind_u_component_100m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_100m), time: time)
            case .wind_direction_120m, .winddirection_120m, .wind_direction_100m, .winddirection_100m:
                try await prefetchData(raw: .surface(.wind_u_component_100m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_100m), time: time)
            case .evapotranspiration:
                try await prefetchData(raw: .surface(.latent_heat_flux), time: time)
            case .vapour_pressure_deficit, .vapor_pressure_deficit:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .et0_fao_evapotranspiration:
                try await prefetchData(raw: .surface(.shortwave_radiation), time: time)
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
                try await prefetchData(raw: .surface(.wind_u_component_10m), time: time)
                try await prefetchData(raw: .surface(.wind_v_component_10m), time: time)
            case .rain:
                try await prefetchData(raw: .surface(.snowfall_water_equivalent), time: time)
                try await prefetchData(raw: .surface(.precipitation), time: time)
                try await prefetchData(raw: .surface(.showers), time: time)
            case .snowfall:
                try await prefetchData(raw: .surface(.snowfall_water_equivalent), time: time)
            case .surface_pressure:
                try await prefetchData(raw: .surface(.pressure_msl), time: time)
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .dew_point_2m, .dewpoint_2m:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .diffuse_radiation_instant:
                try await prefetchData(raw: .surface(.diffuse_radiation), time: time)
            case .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation, .global_tilted_irradiance, .global_tilted_irradiance_instant, .direct_radiation_instant:
                try await prefetchData(raw: .surface(.shortwave_radiation), time: time)
                try await prefetchData(raw: .surface(.diffuse_radiation), time: time)
            case .shortwave_radiation_instant:
                try await prefetchData(raw: .surface(.shortwave_radiation), time: time)
            case .weather_code, .weathercode:
                try await prefetchData(raw: .surface(.cloud_cover), time: time)
                try await prefetchData(raw: .surface(.precipitation), time: time)
                try await prefetchData(derived: .surface(.snowfall), time: time)
                try await prefetchData(raw: .surface(.showers), time: time)
                try await prefetchData(raw: .surface(.cape), time: time)
                try await prefetchData(raw: .surface(.wind_gusts_10m), time: time)
                try await prefetchData(raw: .surface(.visibility), time: time)
                try await prefetchData(raw: .surface(.lifted_index), time: time)
            case .is_day:
                break
            case .temperature_120m:
                try await prefetchData(raw: .surface(.temperature_100m), time: time)
            case .wet_bulb_temperature_2m:
                try await prefetchData(raw: .surface(.temperature_2m), time: time)
                try await prefetchData(raw: .surface(.relative_humidity_2m), time: time)
            case .cloudcover:
                try await prefetchData(raw: .surface(.cloud_cover), time: time)
            case .cloudcover_low:
                try await prefetchData(raw: .surface(.cloud_cover_low), time: time)
            case .cloudcover_mid:
                try await prefetchData(raw: .surface(.cloud_cover_mid), time: time)
            case .cloudcover_high:
                try await prefetchData(raw: .surface(.cloud_cover_high), time: time)
            case .sensible_heatflux:
                try await prefetchData(raw: .surface(.sensible_heat_flux), time: time)
            case .latent_heatflux:
                try await prefetchData(raw: .surface(.latent_heat_flux), time: time)
            case .windgusts_10m:
                try await prefetchData(raw: .surface(.wind_gusts_10m), time: time)
            case .freezinglevel_height:
                try await prefetchData(raw: .surface(.freezing_level_height), time: time)
            case .sunshine_duration:
                try await prefetchData(derived: .surface(.direct_radiation), time: time)
            case .mass_density_8m:
                try await prefetchData(derived: .surface(.mass_density_8m), time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .wind_speed, .windspeed, .wind_direction, .winddirection:
                try await prefetchData(raw: .pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try await prefetchData(raw: .pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dew_point, .dewpoint:
                try await prefetchData(raw: .pressure(GfsPressureVariable(variable: .temperature, level: v.level)), time: time)
                try await prefetchData(raw: .pressure(GfsPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover:
                try await prefetchData(raw: .pressure(GfsPressureVariable(variable: .cloud_cover, level: v.level)), time: time)
            case .relativehumidity:
                try await prefetchData(raw: .pressure(GfsPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }

    func get(derived: Derived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
        case .surface(let gfsVariableDerivedSurface):
            switch gfsVariableDerivedSurface {
            case .wind_speed_10m, .windspeed_10m:
                let u = try await get(raw: .surface(.wind_u_component_10m), time: time).data
                let v = try await get(raw: .surface(.wind_v_component_10m), time: time).data
                let speed = zip(u, v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_10m, .winddirection_10m:
                let u = try await get(raw: .surface(.wind_u_component_10m), time: time).data
                let v = try await get(raw: .surface(.wind_v_component_10m), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_80m, .windspeed_80m:
                let u = try await get(raw: .surface(.wind_u_component_80m), time: time).data
                let v = try await get(raw: .surface(.wind_v_component_80m), time: time).data
                let speed = zip(u, v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_80m, .winddirection_80m:
                let u = try await get(raw: .surface(.wind_u_component_80m), time: time).data
                let v = try await get(raw: .surface(.wind_v_component_80m), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_120m, .windspeed_120m:
                // Take 100m wind and scale to 120m
                let u = try await get(raw: .surface(.wind_u_component_100m), time: time).data
                let v = try await get(raw: .surface(.wind_v_component_100m), time: time).data
                let scalefactor = Meteorology.scaleWindFactor(from: 100, to: 120)
                var speed = zip(u, v).map(Meteorology.windspeed)
                speed.multiplyAdd(multiply: scalefactor, add: 0)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_speed_100m, .windspeed_100m:
                let u = try await get(raw: .surface(.wind_u_component_100m), time: time).data
                let v = try await get(raw: .surface(.wind_v_component_100m), time: time).data
                let speed = zip(u, v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_120m, .winddirection_120m, .wind_direction_100m, .winddirection_100m:
                let u = try await get(raw: .surface(.wind_u_component_100m), time: time).data
                let v = try await get(raw: .surface(.wind_v_component_100m), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .apparent_temperature:
                let windspeed = try await get(derived: .surface(.windspeed_10m), time: time).data
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let relhum = try await get(raw: .surface(.relative_humidity_2m), time: time).data
                let radiation = try await get(raw: .surface(.shortwave_radiation), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .evapotranspiration:
                let latent = try await get(raw: .surface(.latent_heat_flux), time: time).data
                let evapotranspiration = latent.map(Meteorology.evapotranspiration)
                return DataAndUnit(evapotranspiration, .millimetre)
            case .vapour_pressure_deficit, .vapor_pressure_deficit:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature, dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try await get(raw: .surface(.shortwave_radiation), time: time).data
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let windspeed = try await get(derived: .surface(.windspeed_10m), time: time).data
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time).data
                let dewpoint = zip(temperature, rh).map(Meteorology.dewpoint)

                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: time.dtSeconds)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                let snowfall_water_equivalent = try await get(raw: .surface(.snowfall_water_equivalent), time: time).data
                let snowfall = snowfall_water_equivalent.map({ $0 * 0.7 })
                return DataAndUnit(snowfall, SiUnit.centimetre)
            case .rain:
                let snowfall_water_equivalent = try await get(raw: .surface(.snowfall_water_equivalent), time: time).data
                let precipitation = try await get(raw: .surface(.precipitation), time: time).data
                let showers = try await get(raw: .surface(.showers), time: time).data
                let rain = zip(snowfall_water_equivalent, zip(precipitation, showers)).map({ snowfall_water_equivalent, arg1 in
                    let (precipitation, showers) = arg1
                    return max(precipitation - snowfall_water_equivalent - showers, 0)
                })
                return DataAndUnit(rain, .millimetre)
            case .relativehumidity_2m:
                return try await get(raw: .surface(.relative_humidity_2m), time: time)
            case .surface_pressure:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time).data
                let pressure_msl = try await get(raw: .surface(.pressure_msl), time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure_msl.data, elevation: reader.targetElevation), pressure_msl.unit)
            case .terrestrial_radiation:
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .terrestrial_radiation_instant:
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .dew_point_2m, .dewpoint_2m:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time)
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
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
            case .direct_radiation:
                let diffuse = try await get(raw: .surface(.diffuse_radiation), time: time)
                let swrad = try await get(raw: .surface(.shortwave_radiation), time: time)
                return DataAndUnit(zip(swrad.data, diffuse.data).map(-), diffuse.unit)
            case .direct_radiation_instant:
                let direct = try await get(derived: .surface(.direct_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try await get(raw: .surface(.diffuse_radiation), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weather_code, .weathercode:
                let cloudcover = try await get(raw: .surface(.cloud_cover), time: time).data
                let precipitation = try await get(raw: .surface(.precipitation), time: time).data
                let snowfall = try await get(derived: .surface(.snowfall), time: time).data
                let showers = try await get(raw: .surface(.showers), time: time).data
                let cape = try await get(raw: .surface(.cape), time: time).data
                let gusts = try await get(raw: .surface(.wind_gusts_10m), time: time).data
                let visibility = try await get(raw: .surface(.visibility), time: time).data
                let categoricalFreezingRain = try await get(raw: .surface(.categorical_freezing_rain), time: time).data
                let liftedIndex = try await get(raw: .surface(.lifted_index), time: time).data
                return DataAndUnit(WeatherCode.calculate(
                    cloudcover: cloudcover,
                    precipitation: precipitation,
                    convectivePrecipitation: showers,
                    snowfallCentimeters: snowfall,
                    gusts: gusts,
                    cape: cape,
                    liftedIndex: liftedIndex,
                    visibilityMeters: visibility,
                    categoricalFreezingRain: categoricalFreezingRain,
                    modelDtSeconds: time.dtSeconds), .wmoCode
                )
            case .is_day:
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .temperature_120m:
                return try await get(raw: .surface(.temperature_100m), time: time)
            case .wet_bulb_temperature_2m:
                let temperature = try await get(raw: .surface(.temperature_2m), time: time)
                let rh = try await get(raw: .surface(.relative_humidity_2m), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloudcover:
                return try await get(raw: .surface(.cloud_cover), time: time)
            case .cloudcover_low:
                return try await get(raw: .surface(.cloud_cover_low), time: time)
            case .cloudcover_mid:
                return try await get(raw: .surface(.cloud_cover_mid), time: time)
            case .cloudcover_high:
                return try await get(raw: .surface(.cloud_cover_high), time: time)
            case .sensible_heatflux:
                return try await get(raw: .surface(.sensible_heat_flux), time: time)
            case .latent_heatflux:
                return try await get(raw: .surface(.latent_heat_flux), time: time)
            case .windgusts_10m:
                return try await get(raw: .surface(.wind_gusts_10m), time: time)
            case .freezinglevel_height:
                return try await get(raw: .surface(.freezing_level_height), time: time)
            case .mass_density_8m:
                return try await get(raw: .surface(.mass_density_8m), time: time)
            case .sunshine_duration:
                let directRadiation = try await get(derived: .surface(.direct_radiation), time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
            case .global_tilted_irradiance:
                let diffuseRadiation = try await get(raw: .surface(.diffuse_radiation), time: time).data
                let ghi = try await get(raw: .surface(.shortwave_radiation), time: time).data
                let directRadiation = zip(ghi, diffuseRadiation).map(-)
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let diffuseRadiation = try await get(raw: .surface(.diffuse_radiation), time: time).data
                let ghi = try await get(raw: .surface(.shortwave_radiation), time: time).data
                let directRadiation = zip(ghi, diffuseRadiation).map(-)
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .wind_speed, .windspeed:
                let u = try await get(raw: .pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try await get(raw: .pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data, v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .wind_direction, .winddirection:
                let u = try await get(raw: .pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try await get(raw: .pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dew_point, .dewpoint:
                let temperature = try await get(raw: .pressure(GfsPressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try await get(raw: .pressure(GfsPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover:
                return try await get(raw: .pressure(GfsPressureVariable(variable: .cloud_cover, level: v.level)), time: time)
            case .relativehumidity:
                return try await get(raw: .pressure(GfsPressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}
