import Foundation
import Vapor


enum GemVariableDerivedSurface: String, CaseIterable, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case et0_fao_evapotranspiration
    case vapor_pressure_deficit
    case surface_pressure
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case snowfall
    case rain
    case weathercode
    case is_day
    case wet_bulb_temperature_2m
    
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

typealias GemVariableCombined = VariableOrDerived<VariableAndMemberAndControl<GemVariable>, VariableAndMemberAndControl<GemVariableDerived>>

struct GemReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    typealias MixingVar = GemVariableCombined
    
    typealias Domain = GemDomain
    
    typealias Variable = VariableAndMemberAndControl<GemVariable>
    
    typealias Derived = VariableAndMemberAndControl<GemVariableDerived>
    
    var reader: GenericReaderCached<GemDomain, Variable>
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func prefetchData(derived: Derived, time: TimerangeDt) throws {
        let member = derived.member
        switch derived.variable {
        case .surface(let surface):
            switch surface {
            case .apparent_temperature:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.windspeed_10m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
            case .dewpoint_2m:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .vapor_pressure_deficit:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            case .et0_fao_evapotranspiration:
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.windspeed_10m), member), time: time)
            case .surface_pressure:
                try prefetchData(raw: .init(.surface(.pressure_msl), member), time: time)
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
            case .terrestrial_radiation:
                break
            case .terrestrial_radiation_instant:
                break
            case .diffuse_radiation:
                fallthrough
            case .diffuse_radiation_instant:
                fallthrough
            case .direct_normal_irradiance:
                fallthrough
            case .direct_normal_irradiance_instant:
                fallthrough
            case .direct_radiation:
                fallthrough
            case .direct_radiation_instant:
                fallthrough
            case .shortwave_radiation_instant:
                try prefetchData(raw: .init(.surface(.shortwave_radiation), member), time: time)
            case .snowfall:
                try prefetchData(raw: .init(.surface(.snowfall_water_equivalent), member), time: time)
            case .rain:
                try prefetchData(raw: .init(.surface(.precipitation), member), time: time)
                try prefetchData(raw: .init(.surface(.snowfall_water_equivalent), member), time: time)
                if reader.domain != .gem_global_ensemble {
                    try prefetchData(raw: .init(.surface(.showers), member), time: time)
                }
            case .cloudcover_low:
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 1000)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 950)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 850)), member), time: time)
            case .cloudcover_mid:
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 700)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 600)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 500)), member), time: time)
            case .cloudcover_high:
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 400)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 300)), member), time: time)
                try prefetchData(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 200)), member), time: time)
            case .weathercode:
                try prefetchData(raw: .init(.surface(.cloudcover), member), time: time)
                try prefetchData(raw: .init(.surface(.precipitation), member), time: time)
                try prefetchData(derived: .init(.surface(.snowfall), member), time: time)
                try prefetchData(raw: .init(.surface(.showers), member), time: time)
                try prefetchData(raw: .init(.surface(.cape), member), time: time)
                try prefetchData(raw: .init(.surface(.windgusts_10m), member), time: time)
            case .is_day:
                break
            case .wet_bulb_temperature_2m:
                try prefetchData(raw: .init(.surface(.temperature_2m), member), time: time)
                try prefetchData(raw: .init(.surface(.relativehumidity_2m), member), time: time)
            }
        case .pressure(let v):
            switch v.variable {
            case .dewpoint:
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            case .cloudcover:
                try prefetchData(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
            }
        }
    }
    
    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .surface(let variableDerivedSurface):
            switch variableDerivedSurface {
            case .apparent_temperature:
                let windspeed = try get(raw: .init(.surface(.windspeed_10m), member), time: time).data
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let relhum = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let radiation = try get(raw: .init(.surface(.shortwave_radiation), member), time: time).data
                return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            case .vapor_pressure_deficit:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
            case .et0_fao_evapotranspiration:
                let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time).data
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let windspeed = try get(raw: .init(.surface(.windspeed_10m), member), time: time).data
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time).data
                let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
                
                let et0 = swrad.indices.map { i in
                    return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
                }
                return DataAndUnit(et0, .millimeter)
            case .surface_pressure:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time).data
                let pressure = try get(raw: .init(.surface(.pressure_msl), member), time: time)
                return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
            case .terrestrial_radiation:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
            case .terrestrial_radiation_instant:
                /// Use center averaged
                let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(solar, .wattPerSquareMeter)
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
            case .diffuse_radiation:
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(diffuse, swrad.unit)
            case .direct_radiation:
                let swrad = try get(raw: .init(.surface(.shortwave_radiation), member), time: time)
                let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
                return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
            case .direct_radiation_instant:
                let direct = try get(derived: .init(.surface(.direct_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
            case .diffuse_radiation_instant:
                let diff = try get(derived: .init(.surface(.diffuse_radiation), member), time: time)
                let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
                return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
            case .dewpoint_2m:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time)
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .snowfall:
                let snowwater = try get(raw: .init(.surface(.snowfall_water_equivalent), member), time: time).data
                let snowfall = snowwater.map { $0 * 0.7 }
                return DataAndUnit(snowfall, .centimeter)
            case .rain:
                let snowwater = try get(raw: .init(.surface(.snowfall_water_equivalent), member), time: time).data
                let total = try get(raw: .init(.surface(.precipitation), member), time: time).data
                if reader.domain == .gem_global_ensemble {
                    // no showers in ensemble
                    return DataAndUnit(zip(total, snowwater).map(-), .millimeter)
                }
                let showers = try get(raw: .init(.surface(.showers), member), time: time).data
                let rain = zip(zip(total, snowwater), showers).map { (arg0, showers) in
                    let (total, snowwater) = arg0
                    return max(total - snowwater - showers, 0)
                }
                return DataAndUnit(rain, .millimeter)
            case .cloudcover_low:
                let cl0 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 1000)), member), time: time)
                let cl1 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 950)), member), time: time)
                let cl2 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 850)), member), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
            case .cloudcover_mid:
                let cl0 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 700)), member), time: time)
                let cl1 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 600)), member), time: time)
                let cl2 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 500)), member), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
            case .cloudcover_high:
                let cl0 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 400)), member), time: time)
                let cl1 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 300)), member), time: time)
                let cl2 = try get(derived: .init(.pressure(GemPressureVariableDerived(variable: .cloudcover, level: 200)), member), time: time)
                return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
            case .weathercode:
                let cloudcover = try get(raw: .init(.surface(.cloudcover), member), time: time).data
                let precipitation = try get(raw: .init(.surface(.precipitation), member), time: time).data
                let snowfall = try get(derived: .init(.surface(.snowfall), member), time: time).data
                let showers = try get(raw: .init(.surface(.showers), member), time: time).data
                let cape = try get(raw: .init(.surface(.cape), member), time: time).data
                let gusts = try get(raw: .init(.surface(.windgusts_10m), member), time: time).data
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
                return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
            case .wet_bulb_temperature_2m:
                let temperature = try get(raw: .init(.surface(.temperature_2m), member), time: time)
                let rh = try get(raw: .init(.surface(.relativehumidity_2m), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
            }
        case .pressure(let v):
            switch v.variable {
            case .dewpoint:
                let temperature = try get(raw: .init(.pressure(GemPressureVariable(variable: .temperature, level: v.level)), member), time: time)
                let rh = try get(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
                return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
            case .cloudcover:
                let rh = try get(raw: .init(.pressure(GemPressureVariable(variable: .relativehumidity, level: v.level)), member), time: time)
                return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(v.level))}), .percent)
            }
        }
    }
}

struct GemMixer: GenericReaderMixer {
    let reader: [GemReader]
    
    static func makeReader(domain: GemReader.Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws -> GemReader? {
        return try GemReader(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode)
    }
}
