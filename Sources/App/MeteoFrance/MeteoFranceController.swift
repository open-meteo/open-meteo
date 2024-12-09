import Foundation
import Vapor


enum MeteoFranceVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case relativehumidity_2m
    case dewpoint_2m
    case dew_point_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_20m
    case winddirection_20m
    case windspeed_50m
    case winddirection_50m
    case windspeed_100m
    case winddirection_100m
    case windspeed_150m
    case winddirection_150m
    case windspeed_200m
    case winddirection_200m
    /// Is using 100m wind
    case windspeed_80m
    case winddirection_80m
    /// Is using 150m wind
    case windspeed_120m
    case winddirection_120m
    /// Is using 200m wind
    case windspeed_180m
    case winddirection_180m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_20m
    case wind_direction_20m
    case wind_speed_50m
    case wind_direction_50m
    case wind_speed_100m
    case wind_direction_100m
    case wind_speed_150m
    case wind_direction_150m
    case wind_speed_200m
    case wind_direction_200m
    /// Is using 100m wind
    case wind_speed_80m
    case wind_direction_80m
    /// Is using 150m wind
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
    //case evapotranspiration
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
    case rain
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
enum MeteoFrancePressureVariableDerivedType: String, CaseIterable {
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
struct MeteoFrancePressureVariableDerived: PressureVariableRespresentable, GenericVariableMixable {
    let variable: MeteoFrancePressureVariableDerivedType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

typealias MeteoFranceVariableDerived = SurfaceAndPressureVariable<MeteoFranceVariableDerivedSurface, MeteoFrancePressureVariableDerived>

typealias MeteoFranceVariableCombined = VariableOrDerived<MeteoFranceVariable, MeteoFranceVariableDerived>

struct MeteoFranceReader: GenericReaderDerived, GenericReaderProtocol {
    typealias Domain = MeteoFranceDomain
    
    typealias Variable = MeteoFranceVariable
    
    typealias Derived = MeteoFranceVariableDerived
    
    typealias MixingVar = MeteoFranceVariableCombined
    
    let reader: GenericReaderCached<MeteoFranceDomain, MeteoFranceVariable>
    
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
    
    func get(raw: MeteoFranceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        if case let .surface(variable) = raw, variable == .shortwave_radiation {
            // Note: Shortwave radiation was wrongly converted from Joules to Watt. Correct the value here.
            // Exact error is 125/162 = 0.771
            let ssrd = try reader.get(variable: raw, time: time)
            return DataAndUnit(ssrd.data.map{$0 / (3600/10_000_000) * (1/3600)}, ssrd.unit)
        }
        
        return try reader.get(variable: raw, time: time)
    }
    
    func prefetchData(raw: MeteoFranceVariable, time: TimerangeDtAndSettings) throws {
        try reader.prefetchData(variable: raw, time: time)
    }
    
    
    /// TODO partly duplicate code with ICON
    /*private func interpolatePressureLevel(variable: MeteoFrancePressureVariableType, level: Int, lowerLevel: Int, upperLevel: Int, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        let lower = try get(raw: .pressure(MeteoFrancePressureVariable(variable: variable, level: lowerLevel)), time: time)
        let upper = try get(raw: .pressure(MeteoFrancePressureVariable(variable: variable, level: upperLevel)), time: time)
        
        switch variable {
        case .temperature:
            // temperature/pressure is linear, therefore
            // perform linear interpolation between 2 points
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        case .geopotential_height:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                let lP = Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: l)
                let hP = Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: h)
                let adjPressure = lP + Float(level - lowerLevel) * (hP - lP) / Float(upperLevel - lowerLevel)
                return Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: adjPressure)
            }, lower.unit)
        case .relative_humidity:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return (l + h) / 2
            }, lower.unit)
        case .cloud_cover:
            return DataAndUnit(zip(lower.data, upper.data).map { (l, h) -> Float in
                return l + Float(level - lowerLevel) * (h - l) / Float(upperLevel - lowerLevel)
            }, lower.unit)
        }
    }*/
    
    func prefetchData(variable: MeteoFranceSurfaceVariable, time: TimerangeDtAndSettings) throws {
        try prefetchData(variable: .raw(.surface(variable)), time: time)
    }
    
    func get(raw: MeteoFranceSurfaceVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        return try get(variable: .raw(.surface(raw)), time: time)
    }
    
    func prefetchData(derived: MeteoFranceVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .relativehumidity_2m:
                try prefetchData(variable: .relative_humidity_2m, time: time)
            case .wind_speed_10m, .windspeed_10m, .wind_direction_10m, .winddirection_10m:
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
            case .vapor_pressure_deficit, .vapour_pressure_deficit:
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(variable: .shortwave_radiation, time: time)
                try prefetchData(variable: .temperature_2m, time: time)
                try prefetchData(variable: .relative_humidity_2m, time: time)
                try prefetchData(variable: .wind_u_component_10m, time: time)
                try prefetchData(variable: .wind_v_component_10m, time: time)
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
            case .global_tilted_irradiance, .global_tilted_irradiance_instant:
                fallthrough
            case .diffuse_radiation, .diffuse_radiation_instant, .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation, .direct_radiation_instant, .shortwave_radiation_instant:
                try prefetchData(variable: .shortwave_radiation, time: time)
            case .weather_code, .weathercode:
                try prefetchData(variable: .cloud_cover, time: time)
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(derived: .surface(.snowfall), time: time)
                try prefetchData(variable: .cape, time: time)
                try prefetchData(variable: .wind_gusts_10m, time: time)
            case .is_day:
                break
            case .wind_speed_20m, .windspeed_20m, .wind_direction_20m, .winddirection_20m:
                try prefetchData(variable: .wind_u_component_20m, time: time)
                try prefetchData(variable: .wind_v_component_20m, time: time)
            case .windspeed_50m, .wind_speed_50m, .winddirection_50m, .wind_direction_50m:
                try prefetchData(variable: .wind_u_component_50m, time: time)
                try prefetchData(variable: .wind_v_component_50m, time: time)
            case .windspeed_80m, .wind_speed_80m, .winddirection_80m, .wind_direction_80m, .windspeed_100m, .wind_speed_100m, .winddirection_100m, .wind_direction_100m:
                try prefetchData(variable: .wind_u_component_100m, time: time)
                try prefetchData(variable: .wind_v_component_100m, time: time)
            case .windspeed_120m, .wind_speed_120m, .winddirection_120m, .wind_direction_120m, .windspeed_150m, .wind_speed_150m, .winddirection_150m, .wind_direction_150m:
                try prefetchData(variable: .wind_u_component_150m, time: time)
                try prefetchData(variable: .wind_v_component_150m, time: time)
            case .windspeed_180m, .wind_speed_180m, .winddirection_180m, .wind_direction_180m, .windspeed_200m, .wind_speed_200m, .winddirection_200m, .wind_direction_200m:
                try prefetchData(variable: .wind_u_component_200m, time: time)
                try prefetchData(variable: .wind_v_component_200m, time: time)
            case .temperature_80m:
                try prefetchData(variable: .temperature_100m, time: time)
            case .temperature_120m:
                try prefetchData(variable: .temperature_150m, time: time)
            case .temperature_180m:
                try prefetchData(variable: .temperature_200m, time: time)
            case .showers:
                try prefetchData(variable: .precipitation, time: time)
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
                try prefetchData(derived: .surface(.direct_radiation), time: time)
            case .rain:
                try prefetchData(variable: .precipitation, time: time)
                try prefetchData(variable: .snowfall_water_equivalent, time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed, .wind_speed:
                fallthrough
            case .winddirection, .wind_direction:
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_v_component, level: v.level)), time: time)
            case .dewpoint, .dew_point, .relativehumidity:
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .temperature, level: v.level)), time: time)
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            case .cloudcover, .cloud_cover:
                try prefetchData(raw: .pressure(MeteoFrancePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
    
    func get(derived: MeteoFranceVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .windspeed_10m, .wind_speed_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .winddirection_10m, .wind_direction_10m:
                let u = try get(raw: .wind_u_component_10m, time: time).data
                let v = try get(raw: .wind_v_component_10m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .apparent_temperature:
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let relhum = try get(raw: .relative_humidity_2m, time: time).data
                let radiation = try get(raw: .shortwave_radiation, time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
            case .vapor_pressure_deficit, .vapour_pressure_deficit:
                let temperature = try get(raw: .temperature_2m, time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                let swrad = try get(raw: .shortwave_radiation, time: time).data
                let temperature = try get(raw: .temperature_2m, time: time).data
                let windspeed = try get(derived: .surface(.windspeed_10m), time: time).data
                let rh = try get(raw: .relative_humidity_2m, time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimetre)
            case .snowfall:
                let snowfall_water_equivalent = try get(raw: .snowfall_water_equivalent, time: time).data
                let snowfall = snowfall_water_equivalent.map({$0 * 0.7})
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
                let dhi = try get(derived: .surface(.direct_radiation), time: time).data
                let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(dni, .wattPerSquareMetre)
            case .direct_normal_irradiance_instant:
                let direct = try get(derived: .surface(.direct_radiation), time: time)
                let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
                return DataAndUnit(dni, direct.unit)
            case .diffuse_radiation:
                let swrad = try get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation:
                let swrad = try get(raw: .shortwave_radiation, time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .surface(.direct_radiation), time: time)
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
            case .windspeed_20m, .wind_speed_20m:
                let u = try get(raw: .wind_u_component_20m, time: time).data
                let v = try get(raw: .wind_v_component_20m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .winddirection_20m, .wind_direction_20m:
                let u = try get(raw: .wind_u_component_20m, time: time).data
                let v = try get(raw: .wind_v_component_20m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_50m, .wind_speed_50m:
                let u = try get(raw: .wind_u_component_50m, time: time).data
                let v = try get(raw: .wind_v_component_50m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .winddirection_50m, .wind_direction_50m:
                let u = try get(raw: .wind_u_component_50m, time: time).data
                let v = try get(raw: .wind_v_component_50m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_80m, .wind_speed_80m:
                let u = try get(raw: .wind_u_component_100m, time: time).data
                let v = try get(raw: .wind_v_component_100m, time: time).data
                let scalefactor = Meteorology.scaleWindFactor(from: 100, to: 80)
                var speed = zip(u,v).map(Meteorology.windspeed)
                speed.multiplyAdd(multiply: scalefactor, add: 0)
                return DataAndUnit(speed, .metrePerSecond)
            case .windspeed_100m, .wind_speed_100m:
                let u = try get(raw: .wind_u_component_100m, time: time).data
                let v = try get(raw: .wind_v_component_100m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .winddirection_80m, .wind_direction_80m:
                fallthrough
            case .winddirection_100m, .wind_direction_100m:
                let u = try get(raw: .wind_u_component_100m, time: time).data
                let v = try get(raw: .wind_v_component_100m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_120m, .wind_speed_120m:
                let u = try get(raw: .wind_u_component_150m, time: time).data
                let v = try get(raw: .wind_v_component_150m, time: time).data
                let scalefactor = Meteorology.scaleWindFactor(from: 150, to: 120)
                var speed = zip(u,v).map(Meteorology.windspeed)
                speed.multiplyAdd(multiply: scalefactor, add: 0)
                return DataAndUnit(speed, .metrePerSecond)
            case .windspeed_150m, .wind_speed_150m:
                let u = try get(raw: .wind_u_component_150m, time: time).data
                let v = try get(raw: .wind_v_component_150m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .winddirection_120m, .wind_direction_120m:
                fallthrough
            case .winddirection_150m, .wind_direction_150m:
                let u = try get(raw: .wind_u_component_150m, time: time).data
                let v = try get(raw: .wind_v_component_150m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .windspeed_180m, .wind_speed_180m:
                let u = try get(raw: .wind_u_component_200m, time: time).data
                let v = try get(raw: .wind_v_component_200m, time: time).data
                let scalefactor = Meteorology.scaleWindFactor(from: 200, to: 180)
                var speed = zip(u,v).map(Meteorology.windspeed)
                speed.multiplyAdd(multiply: scalefactor, add: 0)
                return DataAndUnit(speed, .metrePerSecond)
            case .windspeed_200m, .wind_speed_200m:
                let u = try get(raw: .wind_u_component_200m, time: time).data
                let v = try get(raw: .wind_v_component_200m, time: time).data
                let speed = zip(u,v).map(Meteorology.windspeed)
                return DataAndUnit(speed, .metrePerSecond)
            case .winddirection_180m, .wind_direction_180m:
                fallthrough
            case .winddirection_200m, .wind_direction_200m:
                let u = try get(raw: .wind_u_component_200m, time: time).data
                let v = try get(raw: .wind_v_component_200m, time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .temperature_80m:
                return try get(raw: .temperature_100m, time: time)
            case .temperature_120m:
                return try get(raw: .temperature_150m, time: time)
            case .temperature_180m:
                return try get(raw: .temperature_200m, time: time)
            case .showers:
                let precipitation = try get(raw: .precipitation, time: time)
                return DataAndUnit(precipitation.data.map({min($0, 0)}), precipitation.unit)
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
                let directRadiation = try get(derived: .surface(.direct_radiation), time: time)
                let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
                return DataAndUnit(duration, .seconds)
            case .rain:
                let precipitation = try get(raw: .precipitation, time: time)
                let snoweq = try get(raw: .snowfall_water_equivalent, time: time)
                return DataAndUnit(zip(precipitation.data, snoweq.data).map(-), precipitation.unit)
            case .global_tilted_irradiance:
                let directRadiation = try get(derived: .surface(.direct_radiation), time: time).data
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
                return DataAndUnit(gti, .wattPerSquareMetre)
            case .global_tilted_irradiance_instant:
                let directRadiation = try get(derived: .surface(.direct_radiation), time: time).data
                let diffuseRadiation = try get(derived: .surface(.diffuse_radiation), time: time).data
                let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
                return DataAndUnit(gti, .wattPerSquareMetre)
            }
        case .pressure(let v):
            switch v.variable {
            case .windspeed, .wind_speed:
                let u = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_u_component, level: v.level)), time: time)
                let v = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_v_component, level: v.level)), time: time)
                let speed = zip(u.data,v.data).map(Meteorology.windspeed)
                return DataAndUnit(speed, u.unit)
            case .winddirection, .wind_direction:
                let u = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_u_component, level: v.level)), time: time).data
                let v = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .wind_v_component, level: v.level)), time: time).data
                let direction = Meteorology.windirectionFast(u: u, v: v)
                return DataAndUnit(direction, .degreeDirection)
            case .dewpoint, .dew_point:
                let temperature = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .temperature, level: v.level)), time: time)
                let rh = try get(raw: .pressure(MeteoFrancePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover, .cloud_cover:
                let rh = try get(raw: .pressure(.init(variable: .relative_humidity, level: v.level)), time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level))}), .percentage)
            case .relativehumidity:
                return try get(raw: .pressure(MeteoFrancePressureVariable(variable: .relative_humidity, level: v.level)), time: time)
            }
        }
    }
}

struct MeteoFranceMixer: GenericReaderMixer {
    let reader: [MeteoFranceReader]
    
    static func makeReader(domain: MeteoFranceReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode, options: GenericReaderOptions) throws -> MeteoFranceReader? {
        return try MeteoFranceReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode, options: options)
    }
}
