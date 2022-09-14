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
enum MeteoFranceDomain: String, GenericDomain {
    case arpege_europe
    case arpege_world
    case arome_france
    case arome_france_hd
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    
    var dtSeconds: Int {
        if self == .arpege_world {
            return 3*3600
        }
        return 3600
    }

    private static var arpegeEuropeElevationFile = try? OmFileReader(file: Self.arpege_europe.surfaceElevationFileOm)
    private static var arpegeWorldElevationFile = try? OmFileReader(file: Self.arpege_world.surfaceElevationFileOm)
    private static var aromeFranceElevationFile = try? OmFileReader(file: Self.arome_france.surfaceElevationFileOm)
    private static var aromeFranceHdElevationFile = try? OmFileReader(file: Self.arome_france_hd.surfaceElevationFileOm)
    
    var elevationFile: OmFileReader? {
        switch self {
        case .arpege_europe:
            return Self.arpegeEuropeElevationFile
        case .arpege_world:
            return Self.arpegeWorldElevationFile
        case .arome_france:
            return Self.aromeFranceElevationFile
        case .arome_france_hd:
            return Self.aromeFranceHdElevationFile
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Int {
        let t = Timestamp.now()
        // Delay of 3:40 hours after initialisation. Cronjobs starts at 3:40
        return ((t.hour - 3 + 24) % 24) / 6 * 6
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    func forecastHours(run: Int) -> [Int] {
        switch self {
        case .arpege_europe:
            // Note: apparently surface variables are hourly, while pressure/model levels are 1/3/6h
            // In SP2 some are hourly and some are switching 1/3/6h
            if run == 18 {
                // up to 60h, no 6h afterwards
                return Array(stride(from: 0, through: 12, by: 1)) + Array(stride(from: 15, through: 60, by: 3))
            }
            let through = (run == 0 || run == 12) ? 102 : 72
            return Array(stride(from: 0, through: 12, by: 1)) + Array(stride(from: 15, through: 72, by: 3)) + Array(stride(from: 78, through: through, by: 6))
            
            //return Array(stride(from: 0, through: through, by: 1))
        case .arpege_world:
            if run == 6 || run == 18 {
                // no 6h
                let through = run == 6 ? 72 : 60
                return Array(stride(from: 0, through: through, by: 3))
            }
            let through = 102
            return Array(stride(from: 0, to: 96, by: 3)) + Array(stride(from: 96, through: through, by: 6))
        case .arome_france:
            fallthrough
        case .arome_france_hd:
            let through = run == 00 || run == 12 ? 42 : 36
            return Array(stride(from: 0, through: through, by: 1))
        }
    }
    
    /// world 0-24, 27-48, 51-72, 75-102
    func getForecastHoursPerFile(run: Int) -> [(file: String, steps: ArraySlice<Int>)] {
        
        let breakpoints: [Int]
        switch self {
        case .arpege_europe:
            breakpoints = [12,24,36,48,60,72,84,96,102]
        case .arpege_world:
            breakpoints = [24,48,72,102]
        case .arome_france:
            breakpoints = [6,12,18,24,30,36,42]
        case .arome_france_hd:
            breakpoints = []
        }
        
        let timesteps = forecastHours(run: run)
        let steps = timesteps.chunked(by: { t, i in
            return !breakpoints.isEmpty && !breakpoints.contains(t)
        })
        
        return steps.enumerated().map { (i, s) in
            if breakpoints.count == 0 {
                return ("\(i.zeroPadded(len: 2))H", s)
            }
            let start = i == 0 ? 0 : breakpoints[i-1] + dtHours
            let end = breakpoints[i]
            let file = "\(start.zeroPadded(len: 2))H\(end.zeroPadded(len: 2))"
            
            return (file, s)
        }
    }
    
    /// pressure levels
    var levels: [Int] {
        switch self {
        case .arpege_europe:
            fallthrough
        case .arpege_world:
            return [10, 30, 50, 70, 100, 150, 175, 200, 225, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        case .arome_france:
            fallthrough
        case .arome_france_hd:
            return [100, 125, 150, 175, 200, 225, 275, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 1000]
        }
    }
    
    var omFileLength: Int {
        switch self {
        case .arpege_europe:
            return 114 + 3*24
        case .arpege_world:
            return (114 + 4*24) / 3
        case .arome_france:
            fallthrough
        case .arome_france_hd:
            return 36 + 3*24
        }
    }
    
    var grid: Gridable {
        switch self {
        case .arpege_europe:
            return RegularGrid(nx: 1, ny: 1, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .arpege_world:
            return RegularGrid(nx: 1, ny: 1, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .arome_france:
            return RegularGrid(nx: 1, ny: 1, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .arome_france_hd:
            return RegularGrid(nx: 1, ny: 1, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        }
    }
}

/**
 List of all surface MeteoFrance variables
 */
enum MeteoFranceSurfaceVariable: String, CaseIterable, Codable, GenericVariableMixing {
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    
    /// accumulated since forecast start
    case precipitation
    
    case wind_v_component_10m
    case wind_u_component_10m
    case wind_v_component_80m
    case wind_u_component_80m
    
    case soil_temperature_0_to_10cm
    case soil_temperature_10_to_40cm
    case soil_temperature_40_to_100cm
    case soil_temperature_100_to_200cm
    
    case soil_moisture_0_to_10cm
    case soil_moisture_10_to_40cm
    case soil_moisture_40_to_100cm
    case soil_moisture_100_to_200cm
    
    case snow_depth
    
    /// averaged since model start
    case sensible_heatflux
    case latent_heatflux
    
    case showers
    
    /// CPOFP Percent frozen precipitation
    case frozen_precipitation_percent
    //case rain
    //case snowfall_convective_water_equivalent
    //case snowfall_water_equivalent
    
    case windgusts_10m
    case freezinglevel_height
    case shortwave_radiation
    /// Only for HRRR domain. Otherwise diff could be estimated with https://arxiv.org/pdf/2007.01639.pdf 3) method
    case diffuse_radiation
    //case direct_radiation
    
    /// only GFS
    //case uv_index
    /// only GFS
    //case uv_index_clear_sky
    
    case cape
    case lifted_index
    
    case visibility
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .soil_moisture_0_to_10cm: return true
        case .soil_moisture_10_to_40cm: return true
        case .soil_moisture_40_to_100cm: return true
        case .soil_moisture_100_to_200cm: return true
        case .snow_depth: return true
        default: return false
        }
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m: return 20
        case .cloudcover: return 1
        case .cloudcover_low: return 1
        case .cloudcover_mid: return 1
        case .cloudcover_high: return 1
        case .relativehumidity_2m: return 1
        case .precipitation: return 10
        case .wind_v_component_10m: return 10
        case .wind_u_component_10m: return 10
        case .wind_v_component_80m: return 10
        case .wind_u_component_80m: return 10
        case .soil_temperature_0_to_10cm: return 20
        case .soil_temperature_10_to_40cm: return 20
        case .soil_temperature_40_to_100cm: return 20
        case .soil_temperature_100_to_200cm: return 20
        case .soil_moisture_0_to_10cm: return 1000
        case .soil_moisture_10_to_40cm: return 1000
        case .soil_moisture_40_to_100cm: return 1000
        case .soil_moisture_100_to_200cm: return 1000
        case .snow_depth: return 100 // 1cm res
        case .sensible_heatflux: return 0.144
        case .latent_heatflux: return 0.144 // round watts to 7.. results in 0.01 resolution in evpotrans
        case .windgusts_10m: return 10
        case .freezinglevel_height:  return 0.1 // zero height 10 meter resolution
        case .showers: return 10
        case .pressure_msl: return 10
        case .shortwave_radiation: return 1
        case .frozen_precipitation_percent: return 1
        case .cape: return 0.1
        case .lifted_index: return 10
        case .visibility: return 0.05 // 50 meter
        case .diffuse_radiation: return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Gfs interpolation not required for reader. Already 1h")
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloudcover: return .percent
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .relativehumidity_2m: return .percent
        case .precipitation: return .millimeter
        case .wind_v_component_10m: return .ms
        case .wind_u_component_10m: return .ms
        case .wind_v_component_80m: return .ms
        case .wind_u_component_80m: return .ms
        case .soil_temperature_0_to_10cm: return .celsius
        case .soil_temperature_10_to_40cm: return .celsius
        case .soil_temperature_40_to_100cm: return .celsius
        case .soil_temperature_100_to_200cm: return .celsius
        case .soil_moisture_0_to_10cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_10_to_40cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_40_to_100cm: return .qubicMeterPerQubicMeter
        case .soil_moisture_100_to_200cm: return .qubicMeterPerQubicMeter
        case .snow_depth: return .meter
        case .sensible_heatflux: return .wattPerSquareMeter
        case .latent_heatflux: return .wattPerSquareMeter
        case .showers: return .millimeter
        case .windgusts_10m: return .ms
        case .freezinglevel_height: return .meter
        case .pressure_msl: return .hectoPascal
        case .shortwave_radiation: return .wattPerSquareMeter
        case .frozen_precipitation_percent: return .percent
        case .cape: return .joulesPerKilogram
        case .lifted_index: return .dimensionless
        case .visibility: return .meter
        case .diffuse_radiation: return .wattPerSquareMeter
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
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
    case cloudcover
    case relativehumidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct MeteoFrancePressureVariable: PressureVariableRespresentable, GenericVariableMixing, Hashable {
    let variable: MeteoFrancePressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: String {
        return rawValue
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
        case .cloudcover:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        case .relativehumidity:
            return (0.2..<1).interpolated(atFraction: (0..<800).fraction(of: Float(level)))
        }
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Gfs interpolation not required for reader. Already 1h")
    }
    
    var unit: SiUnit {
        switch variable {
        case .temperature:
            return .celsius
        case .wind_u_component:
            return .ms
        case .wind_v_component:
            return .ms
        case .geopotential_height:
            return .meter
        case .cloudcover:
            return .percent
        case .relativehumidity:
            return .percent
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
