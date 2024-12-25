import Foundation
import Vapor
import SwiftEccodes
import OmFileFormat


typealias CerraHourlyVariable = VariableOrDerived<CerraVariable, CerraVariableDerived>

enum CerraVariableDerived: String, RawRepresentableString, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    case dew_point_2m
    case vapor_pressure_deficit
    case vapour_pressure_deficit
    case diffuse_radiation
    case surface_pressure
    case snowfall
    case rain
    case et0_fao_evapotranspiration
    case cloudcover
    case cloud_cover
    case direct_normal_irradiance
    case weathercode
    case weather_code
    case is_day
    case terrestrial_radiation
    case terrestrial_radiation_instant
    case shortwave_radiation_instant
    case diffuse_radiation_instant
    case direct_radiation_instant
    case direct_normal_irradiance_instant
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case wet_bulb_temperature_2m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_100m
    case wind_direction_100m
    case wind_gusts_10m
    case relative_humidity_2m
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case sunshine_duration
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

struct CerraReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    let reader: GenericReaderCached<CdsDomain, CerraVariable>
    
    let options: GenericReaderOptions
    
    typealias Domain = CdsDomain
    
    typealias Variable = CerraVariable
    
    typealias Derived = CerraVariableDerived
    
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
    
    func prefetchData(variables: [CerraHourlyVariable], time: TimerangeDtAndSettings) throws {
        for variable in variables {
            switch variable {
            case .raw(let v):
                try prefetchData(raw: v, time: time)
            case .derived(let v):
                try prefetchData(derived: v, time: time)
            }
        }
    }
    
    func prefetchData(derived: CerraVariableDerived, time: TimerangeDtAndSettings) throws {
        switch derived {
        case .apparent_temperature:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .wind_speed_10m, time: time)
            try prefetchData(raw: .relative_humidity_2m, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .dew_point_2m:
            fallthrough
        case .dewpoint_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relative_humidity_2m, time: time)
        case .vapour_pressure_deficit:
            fallthrough
        case .vapor_pressure_deficit:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relative_humidity_2m, time: time)
        case .global_tilted_irradiance, .global_tilted_irradiance_instant:
            fallthrough
        case .diffuse_radiation:
            try prefetchData(raw: .shortwave_radiation, time: time)
            try prefetchData(raw: .direct_radiation, time: time)
        case .et0_fao_evapotranspiration:
            try prefetchData(raw: .direct_radiation, time: time)
            try prefetchData(derived: .diffuse_radiation, time: time)
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relative_humidity_2m, time: time)
            try prefetchData(raw: .wind_speed_10m, time: time)
        case .surface_pressure:
            try prefetchData(raw: .pressure_msl, time: time)
        case .snowfall:
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .cloud_cover:
            fallthrough
        case .cloudcover:
            try prefetchData(raw: .cloud_cover_low, time: time)
            try prefetchData(raw: .cloud_cover_mid, time: time)
            try prefetchData(raw: .cloud_cover_high, time: time)
        case .direct_normal_irradiance:
            try prefetchData(raw: .direct_radiation, time: time)
        case .rain:
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .weather_code:
            fallthrough
        case .weathercode:
            try prefetchData(derived: .cloudcover, time: time)
            try prefetchData(raw: .precipitation, time: time)
            try prefetchData(derived: .snowfall, time: time)
        case .is_day:
            break
        case .terrestrial_radiation:
            break
        case .terrestrial_radiation_instant:
            break
        case .shortwave_radiation_instant:
            try prefetchData(raw: .shortwave_radiation, time: time)
        case .diffuse_radiation_instant:
            try prefetchData(derived: .diffuse_radiation, time: time)
        case .direct_radiation_instant:
            try prefetchData(raw: .direct_radiation, time: time)
        case .direct_normal_irradiance_instant:
            try prefetchData(raw: .direct_radiation, time: time)
        case .wet_bulb_temperature_2m:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .relative_humidity_2m, time: time)
        case .wind_speed_10m:
            try prefetchData(raw: .wind_speed_10m, time: time)
        case .wind_direction_10m:
            try prefetchData(raw: .wind_direction_10m, time: time)
        case .wind_gusts_10m:
            try prefetchData(raw: .wind_gusts_10m, time: time)
        case .relative_humidity_2m:
            try prefetchData(raw: .relative_humidity_2m, time: time)
        case .cloud_cover_low:
            try prefetchData(raw: .cloud_cover_low, time: time)
        case .cloud_cover_mid:
            try prefetchData(raw: .cloud_cover_mid, time: time)
        case .cloud_cover_high:
            try prefetchData(raw: .cloud_cover_high, time: time)
        case .wind_speed_100m:
            try prefetchData(raw: .wind_speed_100m, time: time)
        case .wind_direction_100m:
            try prefetchData(raw: .wind_speed_100m, time: time)
        case .sunshine_duration:
            try prefetchData(raw: .direct_radiation, time: time)
        }
    }
    
    func get(variable: CerraHourlyVariable, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch variable {
        case .raw(let variable):
            return try get(raw: variable, time: time)
        case .derived(let variable):
            return try get(derived: variable, time: time)
        }
    }
    
    
    func get(derived: CerraVariableDerived, time: TimerangeDtAndSettings) throws -> DataAndUnit {
        switch derived {
        case .dew_point_2m:
            fallthrough
        case .dewpoint_2m:
            let relhum = try get(raw: .relative_humidity_2m, time: time)
            let temperature = try get(raw: .temperature_2m, time: time)
            return DataAndUnit(zip(temperature.data,relhum.data).map(Meteorology.dewpoint), temperature.unit)
        case .apparent_temperature:
            let windspeed = try get(raw: .wind_speed_10m, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let relhum = try get(raw: .relative_humidity_2m, time: time).data
            let radiation = try get(raw: .shortwave_radiation, time: time).data
            return DataAndUnit(Meteorology.apparentTemperature(temperature_2m: temperature, relativehumidity_2m: relhum, windspeed_10m: windspeed, shortwave_radiation: radiation), .celsius)
        case .vapour_pressure_deficit:
            fallthrough
        case .vapor_pressure_deficit:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let dewpoint = try get(derived: .dewpoint_2m, time: time).data
            return DataAndUnit(zip(temperature,dewpoint).map(Meteorology.vaporPressureDeficit), .kilopascal)
        case .et0_fao_evapotranspiration:
            let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: modelLat, longitude: modelLon, timerange: time.time)
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let temperature = try get(raw: .temperature_2m, time: time).data
            let windspeed = try get(raw: .wind_speed_10m, time: time).data
            let dewpoint = try get(derived: .dewpoint_2m, time: time).data
            
            let et0 = swrad.indices.map { i in
                return Meteorology.et0Evapotranspiration(temperature2mCelsius: temperature[i], windspeed10mMeterPerSecond: windspeed[i], dewpointCelsius: dewpoint[i], shortwaveRadiationWatts: swrad[i], elevation: self.modelElevation.numeric, extraTerrestrialRadiation: exrad[i], dtSeconds: 3600)
            }
            return DataAndUnit(et0, .millimetre)
        case .diffuse_radiation:
            let swrad = try get(raw: .shortwave_radiation, time: time).data
            let direct = try get(raw: .direct_radiation, time: time).data
            let diff = zip(swrad,direct).map(-)
            return DataAndUnit(diff, .wattPerSquareMetre)
        case .surface_pressure:
            let temperature = try get(raw: .temperature_2m, time: time).data
            let pressure = try get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.surfacePressure(temperature: temperature, pressure: pressure.data, elevation: targetElevation), pressure.unit)
        case .cloud_cover:
            fallthrough
        case .cloudcover:
            let low = try get(raw: .cloud_cover_low, time: time).data
            let mid = try get(raw: .cloud_cover_mid, time: time).data
            let high = try get(raw: .cloud_cover_high, time: time).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percentage)
        case .snowfall:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time).data
            let snowfall = snowwater.map { $0 * 0.7 }
            return DataAndUnit(snowfall, .centimetre)
        case .direct_normal_irradiance:
            let dhi = try get(raw: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: modelLat, longitude: modelLon, timerange: time.time)
            return DataAndUnit(dni, .wattPerSquareMetre)
        case .rain:
            let snowwater = try get(raw: .snowfall_water_equivalent, time: time)
            let precip = try get(raw: .precipitation, time: time)
            let rain = zip(precip.data, snowwater.data).map({
                return max($0.0-$0.1, 0)
            })
            return DataAndUnit(rain, precip.unit)
        case .weather_code:
            fallthrough
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
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtSeconds: time.dtSeconds), .wmoCode
           )
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .terrestrial_radiation:
            let solar = Zensun.extraTerrestrialRadiationBackwards(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .terrestrial_radiation_instant:
            let solar = Zensun.extraTerrestrialRadiationInstant(latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(solar, .wattPerSquareMetre)
        case .shortwave_radiation_instant:
            let sw = try get(raw: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .direct_normal_irradiance_instant:
            let direct = try get(raw: .direct_radiation, time: time)
            let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
            return DataAndUnit(dni, direct.unit)
        case .direct_radiation_instant:
            let direct = try get(raw: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .wet_bulb_temperature_2m:
            let relhum = try get(raw: .relative_humidity_2m, time: time)
            let temperature = try get(raw: .temperature_2m, time: time)
            return DataAndUnit(zip(temperature.data,relhum.data).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .wind_speed_10m:
            return try get(raw: .wind_speed_10m, time: time)
        case .wind_direction_10m:
            return try get(raw: .wind_direction_10m, time: time)
        case .wind_speed_100m:
            return try get(raw: .wind_speed_10m, time: time)
        case .wind_direction_100m:
            return try get(raw: .wind_direction_100m, time: time)
        case .wind_gusts_10m:
            return try get(raw: .wind_gusts_10m, time: time)
        case .relative_humidity_2m:
            return try get(raw: .relative_humidity_2m, time: time)
        case .cloud_cover_low:
            return try get(raw: .cloud_cover_low, time: time)
        case .cloud_cover_mid:
            return try get(raw: .cloud_cover_mid, time: time)
        case .cloud_cover_high:
            return try get(raw: .cloud_cover_high, time: time)
        case .sunshine_duration:
            let directRadiation = try get(raw: .direct_radiation, time: time)
            let duration = Zensun.calculateBackwardsSunshineDuration(directRadiation: directRadiation.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(duration, .seconds)
        case .global_tilted_irradiance:
            let directRadiation = try get(raw: .direct_radiation, time: time).data
            let ghi = try get(raw: .shortwave_radiation, time: time).data
            let diffuseRadiation = zip(ghi, directRadiation).map(-)
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .global_tilted_irradiance_instant:
            let directRadiation = try get(raw: .direct_radiation, time: time).data
            let ghi = try get(raw: .shortwave_radiation, time: time).data
            let diffuseRadiation = zip(ghi, directRadiation).map(-)
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: try options.getTilt(), azimuth: try options.getAzimuth(), latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
            return DataAndUnit(gti, .wattPerSquareMetre)
        }
    }
}

/**
Sources:
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-land?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-single-levels?tab=form
 - https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-cerra-height-levels?tab=overview
 */
enum CerraVariable: String, CaseIterable, GenericVariable {
    case temperature_2m
    case wind_speed_10m
    case wind_direction_10m
    case wind_speed_100m
    case wind_direction_100m
    case wind_gusts_10m
    case relative_humidity_2m
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
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
    case albedo
    case snow_depth
    case snow_depth_water_equivalent
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .wind_speed_10m:
            return .hermite(bounds: nil)
        case .wind_direction_10m:
            return .linearDegrees
        case .wind_speed_100m:
            return .hermite(bounds: nil)
        case .wind_direction_100m:
            return .linearDegrees
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .precipitation:
            return .backwards_sum
        case .direct_radiation:
            return .solar_backwards_averaged
        case .albedo:
            return .linear
        case .snow_depth, .snow_depth_water_equivalent:
            return .linear
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
         return false
    }
    
    /// Name used to query the ECMWF CDS API via python
    var cdsApiName: String {
        switch self {
        case .wind_gusts_10m: return "10m_wind_gust_since_previous_post_processing"
        case .relative_humidity_2m: return "2m_relative_humidity"
        case .temperature_2m: return "2m_temperature"
        case .cloud_cover_low: return "low_cloud_cover"
        case .cloud_cover_mid: return "medium_cloud_cover"
        case .cloud_cover_high: return "high_cloud_cover"
        case .pressure_msl: return "mean_sea_level_pressure"
        case .snowfall_water_equivalent: return "snow_fall_water_equivalent"
        case .shortwave_radiation: return "surface_solar_radiation_downwards"
        case .precipitation: return "total_precipitation"
        case .direct_radiation: return "time_integrated_surface_direct_short_wave_radiation_flux"
        case .wind_speed_10m: return "10m_wind_speed"
        case .wind_direction_10m: return "10m_wind_direction"
        case .wind_speed_100m: return "wind_speed"
        case .wind_direction_100m: return "wind_direction"
        case .albedo: return "albedo"
        case .snow_depth: return "snow_depth"
        case .snow_depth_water_equivalent: return "snow_depth_water_equivalent"
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
        case .wind_speed_100m: fallthrough
        case .wind_direction_100m: return true
        default: return false
        }
    }
    
    /// Applied to the netcdf file after reading
    var netCdfScaling: (offest: Double, scalefactor: Double)? {
        switch self {
        case .temperature_2m: return (-273.15, 1) // kelvin to celsius
        case .shortwave_radiation: fallthrough // joules to watt
        case .direct_radiation: return (0, 1/3600)
        case .albedo: return (0, 100)
        case .snow_depth: return (0, 1/100) // cm to metre. GRIB files show metre, but it is cm
        default: return nil
        }
    }
    
    /// shortName attribute in GRIB
    var gribShortName: [String] {
        switch self {
        case .wind_speed_10m: return ["10si"]
        case .wind_direction_10m: return ["10wdir"]
        case .wind_speed_100m: return ["ws"]
        case .wind_direction_100m: return ["wdir"]
        case .wind_gusts_10m: return ["10fg", "gust"] // or "gust" on ubuntu 22.04
        case .relative_humidity_2m: return ["2r"]
        case .temperature_2m: return ["2t"]
        case .cloud_cover_low: return ["lcc"]
        case .cloud_cover_mid: return ["mcc"]
        case .cloud_cover_high: return ["hcc"]
        case .pressure_msl: return ["msl"]
        case .snowfall_water_equivalent: return ["sf"]
        case .shortwave_radiation: return ["ssrd"]
        case .precipitation: return ["tp"]
        case .direct_radiation: return ["tidirswrf"]
        case .albedo: return ["al"]
        case .snow_depth: return ["sd"]
        case .snow_depth_water_equivalent: return ["sde"]
        }
    }
    
    /// Scalefactor to compress data
    var scalefactor: Float {
        switch self {
        case .cloud_cover_low: return 1
        case .cloud_cover_mid: return 1
        case .cloud_cover_high: return 1
        case .wind_gusts_10m: return 10
        case .relative_humidity_2m: return 1
        case .temperature_2m: return 20
        case .pressure_msl: return 0.1
        case .snowfall_water_equivalent: return 10
        case .shortwave_radiation: return 1
        case .precipitation: return 10
        case .direct_radiation: return 1
        case .wind_speed_10m: return 10
        case .wind_direction_10m: return 0.5
        case .wind_speed_100m: return 10
        case .wind_direction_100m: return 0.5
        case .albedo: return 1
        case .snow_depth: return 100 // 1cm res
        case .snow_depth_water_equivalent: return 10 // 0.1mm res
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .wind_speed_10m: fallthrough
        case .wind_speed_100m: fallthrough
        case .wind_gusts_10m: return .metrePerSecond
        case .wind_direction_10m: return .degreeDirection
        case .wind_direction_100m: return .degreeDirection
        case .relative_humidity_2m: return .percentage
        case .temperature_2m: return .celsius
        case .cloud_cover_low: return .percentage
        case .cloud_cover_mid: return .percentage
        case .cloud_cover_high: return .percentage
        case .pressure_msl: return .pascal
        case .snowfall_water_equivalent: return .millimetre
        case .shortwave_radiation: return .wattPerSquareMetre
        case .precipitation: return .millimetre
        case .direct_radiation: return .wattPerSquareMetre
        case .albedo: return .percentage
        case .snow_depth: return .metre
        case .snow_depth_water_equivalent: return .millimetre
        }
    }
}
