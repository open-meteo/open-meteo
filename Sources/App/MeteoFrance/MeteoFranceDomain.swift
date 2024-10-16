import Foundation
import SwiftPFor2D


/**
Docs https://mf-models-on-aws.org/en/doc
 
 HP1 files, model levels, temp, rh, wind, pres
 HP2 files, model level, tke, spfh, gp, cloud cover, dewpoint
 IP 1 pressure, temp, rh, wind, gp
 IP 2, dew, vvel, spfh, wind dir/speed
 IP3, cloud water, tke, cloud cover,
 IP4, vorticity, relv, epot
 SP1 surface, prmsl, wind, gust, tmp, rh, total clouds, precip rate, snow precip rate, swrad
 SP2, low mid high clouds, surface pressure, lw rad,
 
 arome models:
 SP3 heat flux,
 
 arome HD:
 - HP1 rh wind, 20/50/100 m
 - SP1 wind, temp, th
 - SP2 surface pres,
 - SP3, dist, brightness temperature
 
 */
enum MeteoFranceDomain: String, GenericDomain, CaseIterable {
    case arpege_europe
    case arpege_world
    case arome_france
    case arome_france_hd
    
    case arome_france_15min
    case arome_france_hd_15min
    
    case arpege_europe_probabilities
    case arpege_world_probabilities
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .arpege_europe:
            return .meteofrance_arpege_europe
        case .arpege_world:
            return .meteofrance_arpege_world025
        case .arome_france:
            return .meteofrance_arome_france0025
        case .arome_france_hd:
            return .meteofrance_arome_france_hd
        case .arome_france_15min:
            return .meteofrance_arome_france0025_15min
        case .arome_france_hd_15min:
            return .meteofrance_arome_france_hd_15min
        case .arpege_europe_probabilities:
            return .meteofrance_arpege_europe_probabilities
        case .arpege_world_probabilities:
            return .meteofrance_arpege_world025_probabilities
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .arome_france_15min:
            return .meteofrance_arome_france0025
        case .arome_france_hd_15min:
            return .meteofrance_arome_france_hd
        case .arpege_europe_probabilities:
            return .meteofrance_arpege_europe
        case .arpege_world_probabilities:
            return .meteofrance_arpege_world025
        default:
            return domainRegistry
        }
    }
    
    var dtSeconds: Int {
        switch self {
        case .arpege_europe, .arpege_world:
            return 3600
        case .arome_france, .arome_france_hd:
            return 3600
        case .arome_france_15min, .arome_france_hd_15min:
            return 900
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            return 3*3600
        }
    }
    var isGlobal: Bool {
        return self == .arpege_world
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .arpege_europe, .arpege_world:
            return 6*3600
        case .arome_france, .arome_france_hd:
            return 3*3600
        case .arome_france_15min, .arome_france_hd_15min:
            return 3600
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            return 12*3600
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fallthrough
        case .arpege_europe, .arpege_world:
            // Delay of 3:40 hours after initialisation. Cronjobs starts at 3:00
            return t.with(hour: ((t.hour - 2 + 24) % 24) / 6 * 6)
        case .arome_france, .arome_france_hd:
            // Delay of 3:40 hours after initialisation. Cronjobs starts at or 2:00
            return t.with(hour: ((t.hour - 2 + 24) % 24) / 3 * 3)
        case .arome_france_15min, .arome_france_hd_15min:
            return t.with(hour: t.hour)
        }
    }
    
    var timeoutHours: Double {
        switch self {
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fallthrough
        case .arpege_europe, .arpege_world:
            // Arpege has sometimes larger delays
            return 7.5
        case .arome_france, .arome_france_hd:
            // Arome has sometimes larger delays
            return 5.5
        case .arome_france_15min, .arome_france_hd_15min:
            return 1.5
        }
    }
    
    var mfApiName: String {
        switch self {
        case .arpege_europe:
            return "MF-NWP-GLOBAL-ARPEGE-01-EUROPE"
        case .arpege_world:
            return "MF-NWP-GLOBAL-ARPEGE-025-GLOBE"
        case .arome_france:
            return "MF-NWP-HIGHRES-AROME-0025-FRANCE"
        case .arome_france_hd:
            return "MF-NWP-HIGHRES-AROME-001-FRANCE"
        case .arome_france_15min:
            return "MF-NWP-HIGHRES-AROMEPI-0025-FRANCE"
        case .arome_france_hd_15min:
            return "MF-NWP-HIGHRES-AROMEPI-001-FRANCE"
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fatalError()
        }
    }
    
    var mfApiGridName: String {
        switch self {
        case .arpege_europe, .arpege_europe_probabilities:
            return "0.1"
        case .arpege_world, .arpege_world_probabilities:
            return "0.25"
        case .arome_france:
            return "0.025"
        case .arome_france_hd:
            return "0.01"
        case .arome_france_15min:
            return ""
        case .arome_france_hd_15min:
            return ""
        }
    }
    
    var mfApiPackageTimes: [String] {
        switch self {
        case .arpege_europe:
            return ["000H012H", "013H024H", "025H036H", "037H048H", "049H060H", "061H072H", "073H084H", "085H096H", "097H102H"]
        case .arpege_world:
            return ["000H024H", "025H048H", "049H072H", "073H102H"]
        case .arome_france:
            return ["00H06H","07H12H","13H18H","19H24H","25H30H","31H36H","37H42H","43H48H","49H51H"]
        case .arome_france_hd:
            return (0...51).map{"\($0.zeroPadded(len: 2))H"}
        case .arome_france_15min:
            return []
        case .arome_france_hd_15min:
            return []
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fatalError()
        }
    }
    
    var mfApiPackagesSurface: [String] {
        switch self {
        case .arpege_europe, .arpege_world:
            return ["SP1", "SP2", "HP1"]
        case .arome_france:
            return ["SP1", "SP2", "SP3", "HP1"]
        case .arome_france_hd:
            return ["SP1", "SP2", "HP1"]
        case .arome_france_15min:
            return []
        case .arome_france_hd_15min:
            return []
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fatalError()
        }
    }
    
    var mfApiPackagesPressure: [String] {
        switch self {
        case .arpege_europe:
            return ["IP1"]
        case .arpege_world:
            return ["IP1"]
        case .arome_france:
            return ["IP1"]
        case .arome_france_hd:
            return []
        case .arome_france_15min:
            return []
        case .arome_france_hd_15min:
            return []
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fatalError()
        }
    }
    
    enum Family: String {
        case arpege
        case arome
        case aromepi
        
        var mfApiDDP: String {
            switch self {
            case .arpege:
                return "ARPEGE"
            case .arome:
                return "AROME"
            case .aromepi:
                return ""
            }
        }
        
        var mfApiProductName: String {
            switch self {
            case .arpege:
                return "productARP"
            case .arome:
                return "productARO"
            case .aromepi:
                return ""
            }
        }
    }
    
    var family: Family {
        switch self {
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fallthrough
        case .arpege_world, .arpege_europe:
            return .arpege
        case .arome_france, .arome_france_hd:
            return .arome
        case .arome_france_15min, .arome_france_hd_15min:
            return .aromepi
        }
    }
    
    var mfSubsetGrid: String {
        switch self {
        case .arpege_europe:
            return "&subset=lat(20,72)&subset=long(-32,42)"
        case .arpege_world:
            return "&subset=long(-180,180)&subset=lat(-90,90)"
        case .arome_france, .arome_france_hd, .arome_france_15min, .arome_france_hd_15min:
            return "&subset=lat(37.5,55.4)&subset=long(-12,16)"
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            fatalError()
        }
    }

    func forecastSeconds(run: Int, hourlyForArpegeEurope: Bool) -> [Int] {
        switch self {
        case .arpege_world:
            if run == 12 {
                return Array(stride(from: 0, through: 48*3600, by: 3600)) + Array(stride(from: 51*3600, through: 114*3600, by: 3*3600))
            }
            return Array(stride(from: 0, through: 48*3600, by: 3600)) + Array(stride(from: 51*3600, through: 102*3600, by: 3*3600))
        case .arpege_europe:
            if run == 12 {
                return Array(stride(from: 0, through: 114*3600, by: 3600))
            }
            return Array(stride(from: 0, through: 102*3600, by: 3600))
        case .arome_france, .arome_france_hd:
            return Array(stride(from: 0, through: 51*3600, by: 3600))
        case .arome_france_15min, .arome_france_hd_15min:
            return Array(stride(from: 0, through: 6*3600, by: 900))
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            return Array(stride(from: 3*3600, through: (run == 6 ? 90 : 102)*3600, by: 3*3600))
        }
    }
    
    /// pressure levels
    var levels: [Int] {
        switch self {
        case .arpege_europe:
            return [                    100, 125, 150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        case .arpege_world:
            // 2024-06-21 MeteoFrance removed levels 10, 20, 30, 50, 70,
            return [                    100, 125, 150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        case .arome_france:
            return [                    100, 125, 150, 175, 200, 225, 250, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        case .arome_france_hd:
            return []
        case .arome_france_15min, .arome_france_hd_15min:
            return []
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            return []
        }
    }
    
    var omFileLength: Int {
        switch self {
        case .arpege_europe:
            return 114 + 3*24
        case .arpege_world:
            return 114 + 4*24
        case .arome_france, .arome_france_hd:
            return 36 + 3*24
        case .arome_france_15min, .arome_france_hd_15min:
            // 6 h forecast a 15min = 24 steps per update
            return 24 * 2
        case .arpege_europe_probabilities, .arpege_world_probabilities:
            return (102 + 4*24)/3
        }
    }
    
    var grid: Gridable {
        switch self {
        case .arpege_europe, .arpege_europe_probabilities:
            return RegularGrid(nx: 741, ny: 521, latMin: 20, lonMin: -32, dx: 0.1, dy: 0.1)
        case .arpege_world, .arpege_world_probabilities:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .arome_france, .arome_france_15min:
            return RegularGrid(nx: 1121, ny: 717, latMin: 37.5, lonMin: -12.0, dx: 0.025, dy: 0.025)
        case .arome_france_hd, .arome_france_hd_15min:
            return RegularGrid(nx: 2801, ny: 1791, latMin: 37.5, lonMin: -12.0, dx: 0.01, dy: 0.01)
        }
    }
}

/**
 List of all surface MeteoFrance variables
 */
enum MeteoFranceSurfaceVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloud_cover
    case cloud_cover_low
    case cloud_cover_mid
    case cloud_cover_high
    case pressure_msl
    case relative_humidity_2m
    
    case wind_v_component_10m
    case wind_u_component_10m
    
    /**
     Avaibility of upper level variables (U. VGRD, RH, TMP):
     - Arome HD, `HP1`, 20, 50 and 100 m (no TMP)
     - Arome france `HP1`, 20, 35,  50, 75, 100, 150, 200, 250, 375, 500, 625, 750, 875, 1000, 1125, 1250, 1375, 1500, 2000, 2250, 2500, 2750, 3000
     - Arpege, same as arome france
     */
    case wind_v_component_20m
    case wind_u_component_20m
    case wind_v_component_50m
    case wind_u_component_50m
    case wind_v_component_100m
    case wind_u_component_100m
    case wind_v_component_150m
    case wind_u_component_150m
    case wind_v_component_200m
    case wind_u_component_200m
    
    case temperature_20m
    case temperature_50m
    case temperature_100m
    case temperature_150m
    case temperature_200m
    
    /// accumulated since forecast start
    case precipitation
   
    case snowfall_water_equivalent
    
    case wind_gusts_10m

    case shortwave_radiation
   
    case cape
    
    var storePreviousForecast: Bool {
        switch self {
        case .temperature_2m, .relative_humidity_2m: return true
        case .precipitation, .snowfall_water_equivalent: return true
        case .pressure_msl: return true
        case .cloud_cover: return true
        case .shortwave_radiation: return true
        case .cape: return true
        default: return false
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .cloud_cover:
            return 1
        case .cloud_cover_low:
            return 1
        case .cloud_cover_mid:
            return 1
        case .cloud_cover_high:
            return 1
        case .relative_humidity_2m:
            return 1
        case .precipitation:
            return 10
        case .wind_gusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation:
            return 1
        case .cape:
            return 0.1
        case .snowfall_water_equivalent:
            return 10
        case .wind_v_component_10m:
            return 10
        case .wind_u_component_10m:
            return 10
        case .wind_v_component_20m:
            fallthrough
        case .wind_u_component_20m:
            fallthrough
        case .wind_v_component_50m:
            fallthrough
        case .wind_u_component_50m:
            fallthrough
        case .wind_v_component_100m:
            fallthrough
        case .wind_u_component_100m:
            fallthrough
        case .wind_v_component_150m:
            fallthrough
        case .wind_u_component_150m:
            fallthrough
        case .wind_v_component_200m:
            fallthrough
        case .wind_u_component_200m:
            return 10
        case .temperature_20m:
            fallthrough
        case .temperature_50m:
            fallthrough
        case .temperature_100m:
            fallthrough
        case .temperature_150m:
            fallthrough
        case .temperature_200m:
            return 20
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloud_cover:
            return .hermite(bounds: 0...100)
        case .cloud_cover_low:
            return .hermite(bounds: 0...100)
        case .cloud_cover_mid:
            return .hermite(bounds: 0...100)
        case .cloud_cover_high:
            return .hermite(bounds: 0...10)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relative_humidity_2m:
            return .hermite(bounds: 0...100)
        case .wind_v_component_10m:
            return .hermite(bounds: nil)
        case .wind_u_component_10m:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .snowfall_water_equivalent:
            return .backwards_sum
        case .wind_gusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        case .cape:
            return .hermite(bounds: 0...10e9)
        case .wind_v_component_20m:
            fallthrough
        case .wind_u_component_20m:
            fallthrough
        case .wind_v_component_50m:
            fallthrough
        case .wind_u_component_50m:
            fallthrough
        case .wind_v_component_100m:
            fallthrough
        case .wind_u_component_100m:
            fallthrough
        case .wind_v_component_150m:
            fallthrough
        case .wind_u_component_150m:
            fallthrough
        case .wind_v_component_200m:
            fallthrough
        case .wind_u_component_200m:
            return .hermite(bounds: nil)
        case .temperature_20m:
            fallthrough
        case .temperature_50m:
            fallthrough
        case .temperature_100m:
            fallthrough
        case .temperature_150m:
            fallthrough
        case .temperature_200m:
            return .hermite(bounds: nil)
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .cloud_cover:
            return .percentage
        case .cloud_cover_low:
            return .percentage
        case .cloud_cover_mid:
            return .percentage
        case .cloud_cover_high:
            return .percentage
        case .relative_humidity_2m:
            return .percentage
        case .precipitation:
            return .millimetre
        case .wind_gusts_10m:
            return .metrePerSecond
        case .pressure_msl:
            return .hectopascal
        case .shortwave_radiation:
            return .wattPerSquareMetre
        case .cape:
            return .joulePerKilogram
        case .snowfall_water_equivalent:
            return .millimetre
        case .wind_v_component_10m:
            return .metrePerSecond
        case .wind_u_component_10m:
            return .metrePerSecond
        case .wind_v_component_20m:
            fallthrough
        case .wind_u_component_20m:
            fallthrough
        case .wind_v_component_50m:
            fallthrough
        case .wind_u_component_50m:
            fallthrough
        case .wind_v_component_100m:
            fallthrough
        case .wind_u_component_100m:
            fallthrough
        case .wind_v_component_150m:
            fallthrough
        case .wind_u_component_150m:
            fallthrough
        case .wind_v_component_200m:
            fallthrough
        case .wind_u_component_200m:
            return .metrePerSecond
        case .temperature_20m:
            fallthrough
        case .temperature_50m:
            fallthrough
        case .temperature_100m:
            fallthrough
        case .temperature_150m:
            fallthrough
        case .temperature_200m:
            return .celsius
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .temperature_2m:
            fallthrough
        case .temperature_20m:
            fallthrough
        case .temperature_50m:
            fallthrough
        case .temperature_100m:
            fallthrough
        case .temperature_150m:
            fallthrough
        case .temperature_200m:
            return true
        default:
            return false
        }
    }
}

/**
 Types of pressure level variables
 */
enum MeteoFrancePressureVariableType: String, CaseIterable {
    case temperature
    case wind_u_component
    case wind_v_component
    case geopotential_height
    case relative_humidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct MeteoFrancePressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: MeteoFrancePressureVariableType
    let level: Int
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var scalefactor: Float {
        // Upper level data are more dynamic and that is bad for compression. Use lower scalefactors
        switch variable {
        case .temperature:
            // Use scalefactor of 2 for everything higher than 300 hPa
            return (2..<10).interpolated(atFraction: (300..<1000).fraction(of: Float(level)))
        case .wind_u_component:
            fallthrough
        case .wind_v_component:
            // Use scalefactor 3 for levels higher than 500 hPa.
            return (3..<10).interpolated(atFraction: (500..<1000).fraction(of: Float(level)))
        case .geopotential_height:
            return (0.05..<1).interpolated(atFraction: (0..<500).fraction(of: Float(level)))
        case .relative_humidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite(bounds: nil)
        case .wind_u_component:
            return .hermite(bounds: nil)
        case .wind_v_component:
            return .hermite(bounds: nil)
        case .geopotential_height:
            return .hermite(bounds: nil)
        case .relative_humidity:
            return .hermite(bounds: 0...100)
        }
    }
    
    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_u_component:
            return .metrePerSecond
        case .wind_v_component:
            return .metrePerSecond
        case .geopotential_height:
            return .metre
        case .relative_humidity:
            return .percentage
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
}
/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias MeteoFranceVariable = SurfaceAndPressureVariable<MeteoFranceSurfaceVariable, MeteoFrancePressureVariable>
