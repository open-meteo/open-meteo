import Foundation
import Vapor


enum GfsVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumitidy_2m
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
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case shortwave_radiation_instant
    case evapotranspiration
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case snowfall
    case rain
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case weathercode
    case is_day
    
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
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(pressure.level))}), .percent)
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
            case .relativehumitidy_2m:
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .windspeed_10m:
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
            case .winddirection_10m:
                try prefetchData(raw: .init(.surface(.wind_u_component_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_10m), member), time: time)
            case .windspeed_80m:
                try prefetchData(raw: .init(.surface(.wind_u_component_80m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_80m), member), time: time)
            case .winddirection_80m:
                try prefetchData(raw: .init(.surface(.wind_u_component_80m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_80m), member), time: time)
            case .windspeed_120m:
                fallthrough
            case .windspeed_100m:
                try prefetchData(raw: .init(.surface(.wind_u_component_100m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_100m), member), time: time)
            case .winddirection_120m:
                fallthrough
            case .winddirection_100m:
                try prefetchData(raw: .init(.surface(.wind_u_component_100m), member), time: time)
                try prefetchData(raw: .init(.surface(.wind_v_component_100m), member), time: time)
            case .evapotranspiration:
                try prefetchData(raw: .init(.surface(.latent_heatflux), member), time: time)
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
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                fallthrough
            case .winddirection:
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time)
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time)
            case .dewpoint:
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                try prefetchData(raw: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            }
        }
    }
    
    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .surface(let gfsVariableDerivedSurface):
            switch gfsVariableDerivedSurface {
            case .windspeed_10m:
                let u = try get(raw: .init(.surface(.wind_u_component_10m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_10m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_10m:
                let u = try get(raw: .init(.surface(.wind_u_component_10m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_10m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_80m:
                let u = try get(raw: .init(.surface(.wind_u_component_80m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_80m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_80m:
                let u = try get(raw: .init(.surface(.wind_u_component_80m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_80m), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_120m:
                // Take 100m wind and scale to 120m
                let u = try get(raw: .init(.surface(.wind_u_component_100m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_100m), member), time: time).data
                let scalefactor = Meteorology.scaleWindFactor(from: 100, to: 120)
                var speed = zip(u,v).map(Meteorology.windspeed)
                speed.multiplyAdd(multiply: scalefactor, add: 0)
                return DataAndUnit(speed, .ms)
            case .windspeed_100m:
                let u = try get(raw: .init(.surface(.wind_u_component_100m), member), time: time).data
                let v = try get(raw: .init(.surface(.wind_v_component_100m), member), time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .ms)
            case .winddirection_120m:
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
                return DataAndUnit(evapotranspiration, .millimeter)
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
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
                return DataAndUnit(et0, .millimeter)
            case .snowfall:
                let frozen_precipitation_percent = try get(raw: .init(.surface(.frozen_precipitation_percent), member), time: time).data
                let precipitation = try get(raw: .init(.surface(.precipitation), member), time: time).data
                let snowfall = zip(frozen_precipitation_percent, precipitation).map({
                    max($0/100 * $1 * 0.7, 0)
                })
                return DataAndUnit(snowfall, SiUnit.centimeter)
            case .rain:
                let frozen_precipitation_percent = try get(raw: .init(.surface(.frozen_precipitation_percent), member), time: time).data
                let precipitation = try get(raw: .init(.surface(.precipitation), member), time: time).data
                if domain != .gfs013 {
                    // showers are only in gfs013
                    let rain = zip(frozen_precipitation_percent, precipitation).map({ (frozen_precipitation_percent, precipitation) in
                        let snowfallWaterEqivalent = (frozen_precipitation_percent/100) * precipitation
                        return max(precipitation - snowfallWaterEqivalent , 0)
                    })
                    return DataAndUnit(rain, .millimeter)
                } else {
                    let showers = try get(raw: .init(.surface(.showers), member), time: time).data
                    let rain = zip(frozen_precipitation_percent, zip(precipitation, showers)).map({ (frozen_precipitation_percent, arg1) in
                        let (precipitation, showers) = arg1
                        let snowfallWaterEqivalent = (frozen_precipitation_percent/100) * precipitation
                        return max(precipitation - snowfallWaterEqivalent - showers, 0)
                    })
                    return DataAndUnit(rain, .millimeter)
                }
            case .relativehumitidy_2m:
                return try get(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .surface_pressure:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let pressure_msl = try get(raw: .init(.surface(.pressure_msl), member), time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure_msl.data, elevation: reader.targetElevation), pressure_msl.unit)
            case .terrestrial_radiation:
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .terrestrial_radiation_instant:
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
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
                return DataAndUnit(dni, .wattPerSquareMeter)
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
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed:
                let u = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time)
                let v = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection:
                let u = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_u_component, level: v.level)), member), time: time).data
                let v = try get(raw: .init(.pressure(GfsPressureVariable(variable: .wind_v_component, level: v.level)), member), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint:
                let temperature = try get(raw: .init(.pressure(GfsPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                let rh = try get(raw: .init(.pressure(GfsPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
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
