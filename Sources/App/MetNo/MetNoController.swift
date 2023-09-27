import Foundation
import Vapor

typealias MetNoHourlyVariable = VariableOrDerived<MetNoVariable, MetNoVariableDerived>

struct MetNoReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    var reader: GenericReaderCached<MetNoDomain, MetNoVariable>
    
    typealias Domain = MetNoDomain
    
    typealias Variable = MetNoVariable
    
    typealias Derived = MetNoVariableDerived
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func prefetchData(derived: MetNoVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .vapor_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
        case .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .terrestrial_radiation:
            break
        case .terrestrial_radiation_instant:
            break
        case .dewpoint_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
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
            try prefetchData(raw: .shortwave_radiation, time: time)
        /*case .cloudcover_low:
            fallthrough
        case .cloudcover_mid:
            fallthrough
        case .cloudcover_high:
            try prefetchData(raw: .cloudcover, time: time)*/
        case .snowfall:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .precipitation, time: time)
        case .weathercode:
            try prefetchData(raw: .cloudcover, time: time)
            try prefetchData(variable: .derived(.snowfall), time: time)
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .windgusts_10m, time: time)
        case .is_day:
            break
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
        case .showers:
            try prefetchData(raw: .precipitation, time: time)
        }
    }
    
    func get(derived: MetNoVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .apparent_temperature:
            let windspeed = try get(raw: .windspeed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let relhum = try get(raw: .relativehumidity_2m, time: time).data
            let radiation = try get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let rh = try get(raw: .relativehumidity_2m, time: time).data
            let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let windspeed = try get(raw: .windspeed_10m, time: time).data
            let rh = try get(raw: .relativehumidity_2m, time: time).data
            let dewpoint = zip(temperature,rh).map(Meteorology.dewpoint)
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: reader.targetElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
        case .terrestrial_radiation:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(solar, .wattPerSquareMeter)
        case .terrestrial_radiation_instant:
            /// Use center averaged
            let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(solar, .wattPerSquareMeter)
        case .dewpoint_2m:
            let temperature = try get(raw: .temperature_2m, time: time)
            let rh = try get(raw: .relativehumidity_2m, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .shortwave_radiation_instant:
            let sw = try get(raw: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .direct_normal_irradiance:
            let dhi = try get(derived: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .direct_normal_irradiance_instant:
            let direct = try get(derived: .direct_radiation_instant, time: time)
            let dni = Zensun.calculateInstantDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(dni, direct.unit)
        case .diffuse_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time)
            let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(diffuse, swrad.unit)
        case .direct_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time)
            let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time)
            return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
        case .direct_radiation_instant:
            let direct = try get(derived: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        /*case .cloudcover_low:
            return try get(raw: .cloudcover, time: time)
        case .cloudcover_mid:
            return try get(raw: .cloudcover, time: time)
        case .cloudcover_high:
            return try get(raw: .cloudcover, time: time)*/
        case .snowfall:
            let temperature = try get(raw: .temperature_2m, time: time)
            let precipitation = try get(raw: .precipitation, time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimeter)
        case .weathercode:
            let cloudcover = try get(raw: .cloudcover, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            let snowfall = try get(derived: .snowfall, time: time).data
            let gusts = try get(raw: .windgusts_10m, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: gusts,
                cape: nil,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtSeconds: time.dtSeconds), .wmoCode
           )
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .rain:
            let temperature = try get(raw: .temperature_2m, time: time)
            let precipitation = try get(raw: .precipitation, time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ ($0 >= 0 ? $1 : 0) }), precipitation.unit)
        case .showers:
            // always 0, but only if any data is available in precipitation.
            let precipitation = try get(raw: .precipitation, time: time)
            return DataAndUnit(precipitation.data.map({ min($0, 0) }), precipitation.unit)
        }
    }
}

/// cloudcover low/mid/high and wind u/v components are requried to be used in the general forecast api
enum MetNoVariableDerived: String, GenericVariableMixable {
    /*case cloudcover_low
    case cloudcover_mid
    case cloudcover_high*/
    
    case apparent_temperature
    case dewpoint_2m
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
    case weathercode
    case is_day
    case rain
    case showers
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
