import Foundation
import Vapor
import SwiftEccodes
import SwiftPFor2D


typealias CerraHourlyVariable = VariableOrDerived<CerraVariable, CerraVariableDerived>

enum CerraVariableDerived: String, Codable, RawRepresentableString, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    //case relativehumidity_2m
    //case windspeed_10m
    //case winddirection_10m
    //case windspeed_100m
    //case winddirection_100m
    case vapor_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case direct_normal_irradiance
    case weathercode
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct CerraReader: GenericReaderDerivedSimple, GenericReaderMixable {
    var reader: GenericReaderCached<CdsDomain, CerraVariable>
    
    typealias Domain = CdsDomain
    
    typealias Variable = CerraVariable
    
    typealias Derived = CerraVariableDerived
    
    func prefetchData(variables: [CerraHourlyVariable], time: TimerangeDt) throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try prefetchData(raw: v, time: time)
            case .derived(let v):
                try prefetchData(derived: v, time: time)
            }
        }
    }
    
    func prefetchData(derived: CerraVariableDerived, time: TimerangeDt) throws {
        switch derived {
        //case .windspeed_10m:
        //    try prefetchData(variable: .wind_u_component_10m, time: time)
        //    try prefetchData(variable: .wind_v_component_10m, time: time)
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .dewpoint_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            /*case .relativehumidity_2m:
            try prefetchData(variable: .temperature_2m, time: time)
            try prefetchData(variable: .dewpoint_2m, time: time)
        case .winddirection_10m:
            try prefetchData(variable: .wind_u_component_10m, time: time)
            try prefetchData(variable: .wind_v_component_10m, time: time)
        case .windspeed_100m:
            try prefetchData(variable: .wind_u_component_100m, time: time)
            try prefetchData(variable: .wind_v_component_100m, time: time)
        case .winddirection_100m:
            try prefetchData(variable: .wind_u_component_100m, time: time)
            try prefetchData(variable: .wind_v_component_100m, time: time)*/
        case .vapor_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
        case .diffuse_radiation:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(derived: .diffuse_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relativehumidity_2m, time: time)
            try prefetchData(raw: .windspeed_10m, time: time)
        case .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
        case .snowfall:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .cloudcover:
            try prefetchData(raw: .cloudcover_low, time: time)
            try prefetchData(raw: .cloudcover_mid, time: time)
            try prefetchData(raw: .cloudcover_high, time: time)
        case .direct_normal_irradiance:
            try prefetchData(raw: .direct_radiation, time: time)
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .weathercode:
            try prefetchData(derived: .cloudcover, time: time)
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(derived: .snowfall, time: time)
        }
    }
    
    func get(variable: CerraHourlyVariable, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(raw: variable, time: time)
        case .derived(let variable):
            return try get(derived: variable, time: time)
        }
    }
    
    
    func get(derived: CerraVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        /*case .windspeed_10m:
            let u = try get(variable: .wind_u_component_10m, time: time)
            let v = try get(variable: .wind_v_component_10m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)*/
        case .dewpoint_2m:
            let relhum = try get(raw: .relativehumidity_2m, time: time)
            let temperature = try get(raw: .temperature_2m, time: time)
            return DataAndUnit(zip(temperature.data,relhum.data).map(Meteorology.dewpoint), temperature.unit)
        case .apparent_temperature:
            let windspeed = try get(raw: .windspeed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let relhum = try get(raw: .relativehumidity_2m, time: time).data
            let radiation = try get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortware_radiation: radiation), .celsius)
            /*case .relativehumidity_2m:
            let temperature = try get(variable: .temperature_2m, time: time).data
            let dew = try get(variable: .dewpoint_2m, time: time).data
            let relativeHumidity = zip(temperature, dew).map(Meteorology.relativeHumidity)
            return DataAndUnit(relativeHumidity, .percent)
        case .winddirection_10m:
            let u = try get(variable: .wind_u_component_10m, time: time).data
            let v = try get(variable: .wind_v_component_10m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_100m:
            let u = try get(variable: .wind_u_component_100m, time: time)
            let v = try get(variable: .wind_v_component_100m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_100m:
            let u = try get(variable: .wind_u_component_100m, time: time).data
            let v = try get(variable: .wind_v_component_100m, time: time).data
            let direction = Meteorology.windirectionFast(u: u, v: v)
            return DataAndUnit(direction, .degreeDirection)*/
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(derived: .dewpoint_2m, time: time).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kiloPascal)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time)
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let windspeed = try get(raw: .windspeed_10m, time: time).data
            let dewpoint = try get(derived: .dewpoint_2m, time: time).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimeter)
        case .diffuse_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let direct = try get(raw: .direct_radiation, time: time).data
            let diff = zip(swrad,direct).map(-)
            return DataAndUnit(diff, .wattPerSquareMeter)
        case .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: modelElevation), pressure.unit)
        case .cloudcover:
            let low = try get(raw: .cloudcover_low, time: time).data
            let mid = try get(raw: .cloudcover_mid, time: time).data
            let high = try get(raw: .cloudcover_high, time: time).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percent)
        case .snowfall:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimeter)
        case .direct_normal_irradiance:
            let dhi = try get(raw: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, timerange: time)
            return DataAndUnit(dni, .wattPerSquareMeter)
        case .rain:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time)
            let precip = try get(raw: .precipitation, time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        case .weathercode:
            let cloudcover = try get(derived: .cloudcover, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            let snowfall = try get(derived: .snowfall, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: nil,
                liftedIndex: nil,
                modelDtHours: time.dtSeconds / 3600), .wmoCode
           )
        }
    }
}

/**
Sources:
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-land?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-single-levels?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-height-levels?tab=overview
 */
enum CerraVariable: String, CaseIterable, Codable, GenericVariable {
    case temperature_2m
    case windspeed_10m
    case winddirection_10m
    case windspeed_100m
    case winddirection_100m
    case windgusts_10m
    case relativehumidity_2m
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case snowfall_water_equivalent
    /*case soil_temperature_0_to_7cm  // special dataset now, with very fine grained spacing ~1-4cm
    case soil_temperature_7_to_28cm
    case soil_temperature_28_to_100cm
    case soil_temperature_100_to_255cm
    case soil_moisture_0_to_7cm
    case soil_moisture_7_to_28cm
    case soil_moisture_28_to_100cm
    case soil_moisture_100_to_255cm*/
    case shortwave_radiation
    case precipitation
    case direct_radiation
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Interpolation not required for cerra")
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
         return false
    }
    
    /// Name used to query the ECMWF CDS API via python
    var cdsApiName: String {
        switch self {
        case .windgusts_10m: return "10m_wind_gust_since_previous_post_processing"
        case .relativehumidity_2m: return "2m_relative_humidity"
        case .temperature_2m: return "2m_temperature"
        case .cloudcover_low: return "low_cloud_cover"
        case .cloudcover_mid: return "medium_cloud_cover"
        case .cloudcover_high: return "high_cloud_cover"
        case .pressure_msl: return "mean_sea_level_pressure"
        case .snowfall_water_equivalent: return "snow_fall_water_equivalent"
        case .shortwave_radiation: return "surface_solar_radiation_downwards"
        case .precipitation: return "total_precipitation"
        case .direct_radiation: return "time_integrated_surface_direct_short_wave_radiation_flux"
        case .windspeed_10m: return "10m_wind_speed"
        case .winddirection_10m: return "10m_wind_direction"
        case .windspeed_100m: return "wind_speed"
        case .winddirection_100m: return "wind_direction"
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .shortwave_radiation:
            fallthrough
        case .direct_radiation:
            fallthrough
        case .precipitation:
            fallthrough
        case .snowfall_water_equivalent:
            return true
        default:
            return false
        }
    }
    
    var isHeightLevel: Bool {
        switch self {
        case .windspeed_100m: fallthrough
        case .winddirection_100m: return true
        default: return false
        }
    }
    
    /// Applied to the netcdf file after reading
    var netCdfScaling: (offest: Double, scalefactor: Double)? {
        switch self {
        case .temperature_2m: return (-273.15, 1) // kelvin to celsius
        case .shortwave_radiation: fallthrough // joules to watt
        case .direct_radiation: return (0, 1/3600)
        default: return nil
        }
    }
    
    /// shortName attribute in GRIB
    var gribShortName: [String] {
        switch self {
        case .windspeed_10m: return ["10si"]
        case .winddirection_10m: return ["10wdir"]
        case .windspeed_100m: return ["ws"]
        case .winddirection_100m: return ["wdir"]
        case .windgusts_10m: return ["10fg", "gust"] // or "gust" on ubuntu 22.04
        case .relativehumidity_2m: return ["2r"]
        case .temperature_2m: return ["2t"]
        case .cloudcover_low: return ["lcc"]
        case .cloudcover_mid: return ["mcc"]
        case .cloudcover_high: return ["hcc"]
        case .pressure_msl: return ["msl"]
        case .snowfall_water_equivalent: return ["sf"]
        case .shortwave_radiation: return ["ssrd"]
        case .precipitation: return ["tp"]
        case .direct_radiation: return ["tidirswrf"]
        }
    }
    
    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .windgusts_10m: return 10
        case .relativehumidity_2m: return 1
        case .temperature_2m: return 20
        case .pressure_msl: return 0.1
        case .snowfall_water_equivalent: return 10
        case .shortwave_radiation: return 1
        case .precipitation: return 10
        case .direct_radiation: return 1
        case .windspeed_10m: return 10
        case .winddirection_10m: return 0.5
        case .windspeed_100m: return 10
        case .winddirection_100m: return 0.5
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .windspeed_10m: fallthrough
        case .windspeed_100m: fallthrough
        case .windgusts_10m: return .ms
        case .winddirection_10m: return .degreeDirection
        case .winddirection_100m: return .degreeDirection
        case .relativehumidity_2m: return .percent
        case .temperature_2m: return .celsius
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .pressure_msl: return .pascal
        case .snowfall_water_equivalent: return .millimeter
        case .shortwave_radiation: return .wattPerSquareMeter
        case .precipitation: return .millimeter
        case .direct_radiation: return .wattPerSquareMeter
        }
    }
}
