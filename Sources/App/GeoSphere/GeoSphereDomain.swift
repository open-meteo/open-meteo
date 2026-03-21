import Foundation
import OmFileFormat
import Vapor

/// GeoSphere Austria AROME 2.5km regional model
/// Data: https://data.hub.geosphere.at/dataset/nwp-v1-1h-2500m
enum GeoSphereDomain: String, GenericDomain, CaseIterable {
    case arome_austria

    var domainRegistry: DomainRegistry {
        switch self {
        case .arome_austria:
            return .geosphere_arome_austria
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var countEnsembleMember: Int {
        return 1
    }

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var dtSeconds: Int {
        return 3600
    }

    var isGlobal: Bool {
        return false
    }

    /// Runs every 3 hours (00, 03, 06, 09, 12, 15, 18, 21) with ~4h delay
    var lastRun: Timestamp {
        let t = Timestamp.now()
        // Subtract 4 hours for delay, then floor to nearest 3h
        let adjustedHour = (t.hour - 4 + 24) % 24
        let runHour = adjustedHour - (adjustedHour % 3)
        return t.with(hour: runHour)
    }

    /// 60h forecast + 2 days buffer
    var omFileLength: Int {
        return 108
    }

    var grid: any Gridable {
        switch self {
        case .arome_austria:
            // lon=594, lat=492, south-to-north
            return RegularGrid(nx: 594, ny: 492, latMin: 42.981, lonMin: 5.498, dx: 0.028, dy: 0.018)
        }
    }

    var updateIntervalSeconds: Int {
        return 10800 // 3 hours
    }
}

/// SYMBOL (weather symbol) uses GeoSphere-specific codes 1-31 (not WMO), so weather_code
/// is derived from raw fields via WeatherCode.calculate().
enum GeoSphereVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case relative_humidity_2m
    case temperature_2m_min
    case temperature_2m_max
    case wind_speed_10m
    case wind_direction_10m
    case wind_gusts_10m
    case precipitation
    case rain
    case snowfall_water_equivalent
    case pressure_msl
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case surface_temperature
    case snow_depth_water_equivalent
    
    case shortwave_radiation
    case cape
    case convective_inhibition
    case snowfall_height
    case sunshine_duration
    case weather_code

    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation, .rain, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .wind_gusts_10m, .wind_speed_10m, .wind_direction_10m: return true
        case .cape, .snowfall_height, .sunshine_duration, .weather_code: return false
        default:
            return false
        }
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        switch self {
        case .temperature_2m, .surface_temperature, .temperature_2m_min, .temperature_2m_max:
            return 20
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return 1
        case .convective_inhibition:
            return 1
        case .relative_humidity_2m:
            return 1
        case .precipitation:
            return 10
        case .rain:
            return 10
        case .snowfall_water_equivalent:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation:
            return 1
        case .wind_speed_10m:
            return 10
        case .wind_direction_10m:
            return 1
        case .cape:
            return 0.1
        case .snowfall_height:
            return 0.1
        case .sunshine_duration:
            return 1
        case .weather_code:
            return 1
        case .snow_depth_water_equivalent:
            return 1 // 1mm res
        }
    }

    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m, .surface_temperature, .temperature_2m_min, .temperature_2m_max:
            return .hermite(bounds: nil)
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .hermite(bounds: 0...100)
        case .convective_inhibition:
            return .hermite(bounds: nil)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_speed_10m:
            return .hermite(bounds: 0...10e9)
        case .wind_direction_10m:
            return .linearDegrees
        case .precipitation:
            return .backwards_sum
        case .rain:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: 0...10e9)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .snowfall_height:
            return .hermite(bounds: nil)
        case .sunshine_duration:
            return .backwards_sum
        case .weather_code:
            return .backwards
        case .snow_depth_water_equivalent:
            return .linear
        }
    }

    var unit: SiUnit {
        switch self {
        case .temperature_2m, .surface_temperature, .temperature_2m_min, .temperature_2m_max:
            return .celsius
        case .cloud_cover, .cloud_cover_low, .cloud_cover_mid, .cloud_cover_high:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .precipitation:
            return .millimetre
        case .rain:
            return .millimetre
        case .snowfall_water_equivalent:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .wind_speed_10m:
            return .metrePerSecond
        case .wind_direction_10m:
            return .degreeDirection
        case .cape:
            return .joulePerKilogram
        case .convective_inhibition:
            return .joulePerKilogram
        case .snowfall_height:
            return .metre
        case .sunshine_duration:
            return .seconds
        case .weather_code:
            return .wmoCode
        case .snow_depth_water_equivalent:
            return .millimetre
        }
    }

    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
}

/// Derived variables computed from raw GeoSphere variables
enum GeoSphereVariableDerived: String, GenericVariableMixable {
    case apparent_temperature
    case dewpoint_2m
    case dew_point_2m
    case direct_normal_irradiance
    case direct_normal_irradiance_instant
    case direct_radiation
    case direct_radiation_instant
    case diffuse_radiation_instant
    case diffuse_radiation
    case shortwave_radiation_instant
    case et0_fao_evapotranspiration
    case vapour_pressure_deficit
    case vapor_pressure_deficit
    case pressure_msl
    case global_tilted_irradiance
    case global_tilted_irradiance_instant
    case snowfall
    case is_day
    case showers
    case wet_bulb_temperature_2m
    case cloudcover
    case relativehumidity_2m
    case windspeed_10m
    case winddirection_10m
    case windgusts_10m
}

typealias GeoSphereHourlyVariable = VariableOrDerived<GeoSphereVariable, GeoSphereVariableDerived>

struct GeoSphereReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    let reader: GenericReaderCached<GeoSphereDomain, GeoSphereVariable>

    let options: GenericReaderOptions

    typealias Domain = GeoSphereDomain

    typealias Variable = GeoSphereVariable

    typealias Derived = GeoSphereVariableDerived

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

    func prefetchData(derived: GeoSphereVariableDerived, time: TimerangeDtAndSettings) async throws {
        switch derived {
        case .apparent_temperature:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .wind_speed_10m, time: time)
            try await prefetchData(raw: .relative_humidity_2m, time: time)
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .vapor_pressure_deficit, .vapour_pressure_deficit:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .relative_humidity_2m, time: time)
        case .et0_fao_evapotranspiration:
            try await prefetchData(raw: .shortwave_radiation, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .relative_humidity_2m, time: time)
            try await prefetchData(raw: .wind_speed_10m, time: time)
        case .pressure_msl:
            try await prefetchData(raw: .pressure_msl, time: time)
            try await prefetchData(raw: .temperature_2m, time: time)
        case .dewpoint_2m, .dew_point_2m:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .relative_humidity_2m, time: time)
        case .diffuse_radiation, .diffuse_radiation_instant, .direct_normal_irradiance, .direct_normal_irradiance_instant, .direct_radiation, .direct_radiation_instant, .global_tilted_irradiance, .global_tilted_irradiance_instant, .shortwave_radiation_instant:
            try await prefetchData(raw: .shortwave_radiation, time: time)
        case .snowfall:
            try await prefetchData(raw: .snowfall_water_equivalent, time: time)
        case .is_day:
            break
        case .showers:
            try await prefetchData(raw: .precipitation, time: time)
        case .wet_bulb_temperature_2m:
            try await prefetchData(raw: .temperature_2m, time: time)
            try await prefetchData(raw: .relative_humidity_2m, time: time)
        case .cloudcover:
            try await prefetchData(raw: .cloud_cover, time: time)
        case .relativehumidity_2m:
            try await prefetchData(raw: .relative_humidity_2m, time: time)
        case .windspeed_10m:
            try await prefetchData(raw: .wind_speed_10m, time: time)
        case .winddirection_10m:
            try await prefetchData(raw: .wind_direction_10m, time: time)
        case .windgusts_10m:
            try await prefetchData(raw: .wind_gusts_10m, time: time)
        }
    }

    func get(derived: GeoSphereVariableDerived, time: TimerangeDtAndSettings) async throws -> DataAndUnit {
        switch derived {
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
        case .pressure_msl:
            // Inverse of MetNo: GeoSphere provides surface_pressure, so we compute sea-level pressure.
            // MetNo provides pressure_msl and derives surface_pressure.
            let temperature = try await get(raw: .temperature_2m, time: time).data
            let pressure = try await get(raw: .pressure_msl, time: time)
            return DataAndUnit(Meteorology.sealevelPressure(temperature: temperature, pressure: pressure.data, elevation: reader.targetElevation), pressure.unit)
        case .dewpoint_2m, .dew_point_2m:
            let temperature = try await get(raw: .temperature_2m, time: time)
            let rh = try await get(raw: .relative_humidity_2m, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .shortwave_radiation_instant:
            let sw = try await get(raw: .shortwave_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(sw.data, factor).map(*), sw.unit)
        case .direct_normal_irradiance:
            let dhi = try await get(derived: .direct_radiation, time: time).data
            let dni = Zensun.calculateBackwardsDNI(directRadiation: dhi, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(dni, .wattPerSquareMetre)
        case .direct_normal_irradiance_instant:
            let direct = try await get(derived: .direct_radiation, time: time)
            let dni = Zensun.calculateBackwardsDNI(directRadiation: direct.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertToInstant: true)
            return DataAndUnit(dni, direct.unit)
        case .diffuse_radiation:
            let swrad = try await get(raw: .shortwave_radiation, time: time)
            let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(diffuse, swrad.unit)
        case .direct_radiation:
            let swrad = try await get(raw: .shortwave_radiation, time: time)
            let diffuse = Zensun.calculateDiffuseRadiationBackwards(shortwaveRadiation: swrad.data, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time)
            return DataAndUnit(zip(swrad.data, diffuse).map(-), swrad.unit)
        case .direct_radiation_instant:
            let direct = try await get(derived: .direct_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(direct.data, factor).map(*), direct.unit)
        case .diffuse_radiation_instant:
            let diff = try await get(derived: .diffuse_radiation, time: time)
            let factor = Zensun.backwardsAveragedToInstantFactor(time: time.time, latitude: reader.modelLat, longitude: reader.modelLon)
            return DataAndUnit(zip(diff.data, factor).map(*), diff.unit)
        case .snowfall:
            // Convert SWE (mm) to snowfall (cm) using a fixed 0.7 factor.
            // More accurate than MetNo's temperature-based approach since we have actual SWE data.
            let swe = try await get(raw: .snowfall_water_equivalent, time: time)
            return DataAndUnit(swe.data.map({ $0 * 0.7 }), .centimetre)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time.time, lat: reader.modelLat, lon: reader.modelLon), .dimensionlessInteger)
        case .showers:
            // always 0, but only if any data is available in precipitation.
            let precipitation = try await get(raw: .precipitation, time: time)
            return DataAndUnit(precipitation.data.map({ min($0, 0) }), precipitation.unit)
        case .wet_bulb_temperature_2m:
            let temperature = try await get(raw: .temperature_2m, time: time)
            let rh = try await get(raw: .relative_humidity_2m, time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.wetBulbTemperature), temperature.unit)
        case .cloudcover:
            return try await get(raw: .cloud_cover, time: time)
        case .relativehumidity_2m:
            return try await get(raw: .relative_humidity_2m, time: time)
        case .windspeed_10m:
            return try await get(raw: .wind_speed_10m, time: time)
        case .winddirection_10m:
            return try await get(raw: .wind_direction_10m, time: time)
        case .windgusts_10m:
            return try await get(raw: .wind_gusts_10m, time: time)
        case .global_tilted_irradiance:
            let directRadiation = try await get(derived: .direct_radiation, time: time).data
            let diffuseRadiation = try await get(derived: .diffuse_radiation, time: time).data
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: false)
            return DataAndUnit(gti, .wattPerSquareMetre)
        case .global_tilted_irradiance_instant:
            let directRadiation = try await get(derived: .direct_radiation, time: time).data
            let diffuseRadiation = try await get(derived: .diffuse_radiation, time: time).data
            let gti = Zensun.calculateTiltedIrradiance(directRadiation: directRadiation, diffuseRadiation: diffuseRadiation, tilt: options.tilt, azimuth: options.azimuth, latitude: reader.modelLat, longitude: reader.modelLon, timerange: time.time, convertBackwardsToInstant: true)
            return DataAndUnit(gti, .wattPerSquareMetre)
        }
    }
}
