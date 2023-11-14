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
    case relative_humidity_2m
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
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case sensible_heat_flux
    case latent_heat_flux
    case wind_gusts_10m
    case freezing_level_height
    
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
    case cloud_cover
    case relative_humidity
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

typealias GfsVariableDerived = SurfaceAndPressureVariable<GfsVariableDerivedSurface, GfsPressureVariableDerived>

typealias GfsVariableCombined = VariableOrDerived<VariableAndMemberAndControl<GfsVariable>, VariableAndMemberAndControl<GfsVariableDerived>>

struct GfsReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = GfsDomain
    
    typealias Variable = VariableAndMemberAndControl<GfsVariable>
    
    typealias Derived = VariableAndMemberAndControl<GfsVariableDerived>
    
    typealias MixingVar = GfsVariableCombined
    
    var reader: GenericReaderMixerSameDomain<GenericReaderCached<GfsDomain, Variable>>
    
    var domain: Domain
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        switch domain {
        case .gfs013:
            // Note gfs025_ensemble only offers precipitation probability at 3h
            // A nicer implementation should use a dedicated variables enum
            let readers: [GenericReaderCached<GfsDomain, Variable>] = try [GfsDomain.gfs025_ensemble, .gfs025, .gfs013].compactMap {
                guard let reader = try GenericReader<GfsDomain, Variable>(domain: $0, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                    return nil
                }
                return GenericReaderCached(reader: reader)
            }
            guard !readers.isEmpty else {
                return nil
            }
            self.reader = GenericReaderMixerSameDomain(reader: readers)
        case .gfs025:
            fatalError("gfs025 should not been initilised in GfsMixer025_013")
        case .gfs025_ensemble:
            fatalError("gfs025_ensemble should not been initilised in GfsMixer025_013")
        case .gfs025_ens:
            guard let reader = try GenericReader<GfsDomain, Variable>(domain: .gfs025_ens, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                return nil
            }
            self.reader = GenericReaderMixerSameDomain(reader: [GenericReaderCached(reader: reader)])
        case .gfs05_ens:
            guard let reader = try GenericReader<GfsDomain, Variable>(domain: .gfs05_ens, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                return nil
            }
            self.reader = GenericReaderMixerSameDomain(reader: [GenericReaderCached(reader: reader)])
        case .hrrr_conus:
            // Combine HRRR hourly and 15 minutely data. This way, weather codes can be calculated using HRRR hourly and 15 minutely data.
            // E.g. CAPE is not available for HRRR 15 minutely data.
            let readers: [GenericReaderCached<GfsDomain, Variable>] = try [GfsDomain.hrrr_conus, .hrrr_conus_15min].compactMap {
                guard let reader = try GenericReader<GfsDomain, Variable>(domain: $0, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
                    return nil
                }
                return GenericReaderCached(reader: reader)
            }
            guard !readers.isEmpty else {
                return nil
            }
            self.reader = GenericReaderMixerSameDomain(reader: readers)
        case .hrrr_conus_15min:
            fatalError("hrrr_conus_15min should not been initilised in GfsMixer025_013")
        }
        self.domain = domain
    }
    
    func get(raw: Variable, time: TimerangeDt) throws -> DataAndUnit {
        let member = raw.member
        /// HRRR domain has no cloud cover for pressure levels, calculate from RH
        if domain == .hrrr_conus, case let .pressure(pressure) = raw.variable, pressure.variable == .cloudcover {
            let rh = try reader.get(variable: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: pressure.level)), member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(pressure.level))}), .percentage)
        }
        
        /// Make sure showers are `0` instead of `NaN` in HRRR, otherwise it is mixed with GFS showers
        if (domain == .hrrr_conus || domain == .hrrr_conus_15min), case let .surface(variable) = raw.variable, variable == .showers {
            let precipitation = try reader.get(variable: .init(.surface(.precipitation), member), time: time)
            return DataAndUnit(precipitation.data.map({min($0, 0)}), precipitation.unit)
        }
        
        /// Adjust surface pressure to target elevation. Surface pressure is stored for `modelElevation`, but we want to get the pressure on `targetElevation`
        /*if case let .surface(variable) = raw.variable, variable == .pressure_msl {
            let pressure = try reader.get(variable: raw, time: time)
            
            let factor = Meteorology.sealevelPressureFactor(temperature: 20 - 0.0065 * (reader.modelElevation.numeric - reader.modelElevation.numeric), elevation: reader.modelElevation.numeric) / Meteorology.sealevelPressureFactor(temperature: 20, elevation: reader.targetElevation)
            print("target \(reader.targetElevation) model \(reader.modelElevation.numeric) factor \(factor)")
            return DataAndUnit(pressure.data.map({$0*factor}), pressure.unit)
        }*/
        
        /// GFS ensemble has no diffuse radiation
        if (domain == .gfs025_ens || domain == .gfs05_ens), case let .surface(variable) = raw.variable, variable == .diffuse_radiation {
            let ghi = try reader.get(variable: .init(.surface(.shortwave_radiation), member), time: time)
            let dhi = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: ghi.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(dhi, ghi.unit)
        }
        
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: Variable, time: TimerangeDt) throws {
        let member = raw.member
        /// HRRR domain has no cloud cover for pressure levels, calculate from RH
        if domain == .hrrr_conus, case let .pressure(pressure) = raw.variable, pressure.variable == .cloudcover {
            return try reader.prefetchData(variable: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: pressure.level)), member), time: time)
        }
        
        /// Make sure showers are `0` in HRRR, otherwise it is mixed with GFS showers
        if (domain == .hrrr_conus || domain == .hrrr_conus_15min), case let .surface(variable) = raw.variable, variable == .showers {
            return try reader.prefetchData(variable: .init(.surface(.precipitation), member), time: time)
        }
        
        /// GFS ensemble has no diffuse radiation
        if (domain == .gfs025_ens || domain == .gfs05_ens), case let .surface(variable) = raw.variable, variable == .diffuse_radiation {
            return try reader.prefetchData(variable: .init(.surface(.shortwave_radiation), member), time: time)
        }
        
        try reader.prefetchData(variable: raw, time: time)
    }
    
    func prefetchData(derived: Derived, time: TimerangeDt) throws {
        let member = derived.member
        switch derived.variable {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
            case .relative_humidity_2m:
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
            case .wind_speed_80m:
                fallthrough
            case .windspeed_80m:
                try prefetchData(raw: .init(.surface(.wind_u_component_80m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_80m), member), time: time)
            case .wind_direction_80m:
                fallthrough
            case .winddirection_80m:
                try prefetchData(raw: .init(.surface(.wind_u_component_80m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_80m), member), time: time)
            case .wind_speed_120m:
                fallthrough
            case .windspeed_120m:
                fallthrough
            case .wind_speed_100m:
                fallthrough
            case .windspeed_100m:
                try prefetchData(raw: .init(.surface(.wind_u_component_100m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_100m), member), time: time)
            case .wind_direction_120m:
                fallthrough
            case .winddirection_120m:
                fallthrough
            case .wind_direction_100m:
                fallthrough
            case .winddirection_100m:
                try prefetchData(raw: .init(.surface(.wind_u_component_100m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_100m), member), time: time)
            case .evapotranspiration:
                try prefetchData(raw: .init(.surface(.latent_heatflux), member), time: time)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
            case .rain:
                try prefetchData(raw: .init(.surface(.frozen_precipitation_percent), member), time: time)
                try prefetchData(raw: .init(.surface(.precipitation), member), time: time)
                if domain == .gfs013 {
                    try prefetchData(raw: .init(.surface(.showers), member), time: time)
                }
            case .snowfall:
                try prefetchData(raw: .init(.surface(.frozen_precipitation_percent), member), time: time)
                try prefetchData(raw: .init(.surface(.precipitation), member), time: time)
            case .surface_pressure:
                try prefetchData(raw: .init(.surface(.pressure_msl), member), time: time)
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .diffuse_radiation_instant:
                try prefetchData(raw: .init(.surface(.diffuse_radiation), member), time: time)
            case .direct_normal_irradiance:
                fallthrough
            case .direct_normal_irradiance_instant:
                fallthrough
            case .direct_radiation:
                fallthrough
            case .direct_radiation_instant:
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
                try prefetchData(raw: .init(.surface(.diffuse_radiation), member), time: time)
            case .shortwave_radiation_instant:
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
            case .weather_code:
                fallthrough
            case .weathercode:
                try prefetchData(raw: .init(.surface(.cloudcover), member), time: time)
                try prefetchData(raw: .init(.surface(.precipitation), member), time: time)
                try prefetchData(derived: .init(.surface(.snowfall), member), time: time)
                try prefetchData(raw: .init(.surface(.showers), member), time: time)
                try prefetchData(raw: .init(.surface(.cape), member), time: time)
                try prefetchData(raw: .init(.surface(.windgusts_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.visibility), member), time: time)
                try prefetchData(raw: .init(.surface(.lifted_index), member), time: time)
            case .is_day:
                break
            case .temperature_120m:
                try prefetchData(raw: .init(.surface(.temperature_100m), member), time: time)
            case .wet_bulb_temperature_2m:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .cloud_cover:
                try prefetchData(raw: .init(.surface(.cloudcover), member), time: time)
            case .cloud_cover_low:
                try prefetchData(raw: .init(.surface(.cloudcover_low), member), time: time)
            case .cloud_cover_mid:
                try prefetchData(raw: .init(.surface(.cloudcover_mid), member), time: time)
            case .cloud_cover_high:
                try prefetchData(raw: .init(.surface(.cloudcover_high), member), time: time)
            case .sensible_heat_flux:
                try prefetchData(raw: .init(.surface(.sensible_heatflux), member), time: time)
            case .latent_heat_flux:
                try prefetchData(raw: .init(.surface(.latent_heatflux), member), time: time)
            case .wind_gusts_10m:
                try prefetchData(raw: .init(.surface(.windgusts_10m), member), time: time)
            case .freezing_level_height:
                try prefetchData(raw: .init(.surface(.freezinglevel_height), member), time: time)
            case .sunshine_duration:
                try prefetchData(derived: .init(.surface(.direct_radiation), member), time: time)
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
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time)
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time)
            case .dew_point:
                fallthrough
            case .dewpoint:
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            case .cloud_cover:
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .cloudcover, level: v.level)), member), time: time)
            case .relative_humidity:
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            }
        }
    }
    
    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .surface(let gfsVariableDerivedSurface):
            switch gfsVariableDerivedSurface {
            case .wind_speed_10m:
                fallthrough
            case .windspeed_10m:
                let u = try get(raw: .init(.surface(.wind_u_component_10m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_10m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_10m:
                fallthrough
            case .winddirection_10m:
                let u = try get(raw: .init(.surface(.wind_u_component_10m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_10m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_80m:
                fallthrough
            case .windspeed_80m:
                let u = try get(raw: .init(.surface(.wind_u_component_80m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_80m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_80m:
                fallthrough
            case .winddirection_80m:
                let u = try get(raw: .init(.surface(.wind_u_component_80m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_80m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .wind_speed_120m:
                fallthrough
            case .windspeed_120m:
                // Take 100m wind and scale to 120m
                let u = try get(raw: .init(.surface(.wind_u_component_100m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_100m), member), time: time).data
                let scalefactor = Meteorology.scaleWindFactor(from: 100, to: 120)
                var speed = zip(u,v).map(Meteorology.windspeed)
                speed.multiplyAdd(multiply: scalefactor, add: 0)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_speed_100m:
                fallthrough
            case .windspeed_100m:
                let u = try get(raw: .init(.surface(.wind_u_component_100m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_100m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .wind_direction_120m:
                fallthrough
            case .winddirection_120m:
                fallthrough
            case .wind_direction_100m:
                fallthrough
            case .winddirection_100m:
                let u = try get(raw: .init(.surface(.wind_u_component_100m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_100m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .apparent_temperature:
                let windspeed = try get(derived: .init(.surface(.windspeed_10m), member), time: time).data
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let relhum = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let radiation = try get(raw: .init(.surface(.shortwave_radiation), member), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            case .evapotranspiration:
                let latent = try get(raw: .init(.surface(.latent_heatflux), member), time: time).data
                let evapotranspiration = latent.map(Meteorology.evapotranspiration)
                return DataAndUnit(evapotranspiration, .millimetre)
            case .vapour_pressure_deficit:
                fallthrough
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time).data
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let windspeed = try get(derived: .init(.surface(.windspeed_10m), member), time: time).data
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                let frozen_precipitation_percent = try get(raw: .init(.surface(.frozen_precipitation_percent), member), time: time).data
                let precipitation = try get(raw: .init(.surface(.precipitation), member), time: time).data
                let snowfall = zip(frozen_precipitation_percent, precipitation).map({
                    max($0/100 * $1 * 0.7, 0)
                })
                return DataAndUnit(snowfall, SiUnit.centimetre)
            case .rain:
                let frozen_precipitation_percent = try get(raw: .init(.surface(.frozen_precipitation_percent), member), time: time).data
                let precipitation = try get(raw: .init(.surface(.precipitation), member), time: time).data
                if domain != .gfs013 {
                    // showers are only in gfs013
                    let rain = zip(frozen_precipitation_percent, precipitation).map({ (frozen_precipitation_percent, precipitation) in
                        let snowfallWaterEqivalent = (frozen_precipitation_percent/100) * precipitation
                        return max(precipitation - snowfallWaterEqivalent , 0)
                    })
                    return DataAndUnit(rain, .millimetre)
                } else {
                    let showers = try get(raw: .init(.surface(.showers), member), time: time).data
                    let rain = zip(frozen_precipitation_percent, zip(precipitation, showers)).map({ (frozen_precipitation_percent, arg1) in
                        let (precipitation, showers) = arg1
                        let snowfallWaterEqivalent = (frozen_precipitation_percent/100) * precipitation
                        return max(precipitation - snowfallWaterEqivalent - showers, 0)
                    })
                    return DataAndUnit(rain, .millimetre)
                }
            case .relative_humidity_2m:
                return try get(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .surface_pressure:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let pressure_msl = try get(raw: .init(.surface(.pressure_msl), member), time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure_msl.data, elevation: reader.targetElevation), pressure_msl.unit)
            case .terrestrial_radiation:
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .terrestrial_radiation_instant:
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMetre)
            case .dew_point_2m:
                fallthrough
            case .dewpoint_2m:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time)
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .shortwave_radiation_instant:
                let sw = try get(raw: .init(.surface(.shortwave_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
            case .direct_normal_irradiance:
                let dhi = try get(derived: .init(.surface(.direct_radiation), member), time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .init(.surface(.direct_radiation_instant), member), time: time)
                let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(dni, direct.unit)
            case .direct_radiation:
                let diffuse = try get(raw: .init(.surface(.diffuse_radiation), member), time: time)
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time)
                return DataAndUnit(zip(swrad.data, diffuse.data).map(-), diffuse.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .init(.surface(.direct_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(raw: .init(.surface(.diffuse_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .weather_code:
                fallthrough
            case .weathercode:
                let cloudcover = try get(raw: .init(.surface(.cloudcover), member), time: time).data
                let precipitation = try get(raw: .init(.surface(.precipitation), member), time: time).data
                let snowfall = try get(derived: .init(.surface(.snowfall), member), time: time).data
                let showers = try get(raw: .init(.surface(.showers), member), time: time).data
                let cape = try get(raw: .init(.surface(.cape), member), time: time).data
                let gusts = try get(raw: .init(.surface(.windgusts_10m), member), time: time).data
                let visibility = try get(raw: .init(.surface(.visibility), member), time: time).data
                let categoricalFreezingRain = try get(raw: .init(.surface(.categorical_freezing_rain), member), time: time).data
                let liftedIndex = try get(raw: .init(.surface(.lifted_index), member), time: time).data
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
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .temperature_120m:
                return try get(raw: .init(.surface(.temperature_100m), member), time: time)
            case .wet_bulb_temperature_2m:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time)
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            case .cloud_cover:
                return try get(raw: .init(.surface(.cloudcover), member), time: time)
            case .cloud_cover_low:
                return try get(raw: .init(.surface(.cloudcover_low), member), time: time)
            case .cloud_cover_mid:
                return try get(raw: .init(.surface(.cloudcover_mid), member), time: time)
            case .cloud_cover_high:
                return try get(raw: .init(.surface(.cloudcover_high), member), time: time)
            case .sensible_heat_flux:
                return try get(raw: .init(.surface(.sensible_heatflux), member), time: time)
            case .latent_heat_flux:
                return try get(raw: .init(.surface(.latent_heatflux), member), time: time)
            case .wind_gusts_10m:
                return try get(raw: .init(.surface(.windgusts_10m), member), time: time)
            case .freezing_level_height:
                return try get(raw: .init(.surface(.freezinglevel_height), member), time: time)
            case .sunshine_duration:
                let directRadiation = try get(derived: .init(.surface(.direct_radiation), member), time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(duration, .seconds)
            }
        case .pressure(let v):
            switch v.variable {
            case .wind_speed:
                fallthrough
            case .windspeed:
                let u = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time)
                let v = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .wind_direction:
                fallthrough
            case .winddirection:
                let u = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time).data
                let v = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dew_point:
                fallthrough
            case .dewpoint:
                let temperature = try get(raw: .init(.pressure(GfsPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                let rh = try get(raw: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloud_cover:
                return try get(raw: .init(.pressure(GfsPressureVariable(variable: .cloudcover, level: v.level)), member), time: time)
            case .relative_humidity:
                return try get(raw: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            }
        }
    }
}


struct GfsMixer: GenericReaderMixer {
    let reader: [GfsReader]
    
    static func makeReader(domain: GfsDomain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GfsReader? {
        return try GfsReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}
