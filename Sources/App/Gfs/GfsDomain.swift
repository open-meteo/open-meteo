import Foundation
import SwiftPFor2D


/**
 GFS inventory: https://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs.t00z.pgrb2.0p25.f003.shtml
 NAM inventory: https://www.nco.ncep.noaa.gov/pmb/products/nam/nam.t00z.conusnest.hiresf06.tm00.grib2.shtml
 HRR inventory: https://www.nco.ncep.noaa.gov/pmb/products/hrrr/hrrr.t00z.wrfprsf02.grib2.shtml
 */
enum GfsDomain: String, GenericDomain {
    case gfs025
    case nam_conus
    case hrrr_conus
    
    var omfileDirectory: String {
        return "./data/omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "./data/\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    
    var dtSeconds: Int {
        return 3600
    }
    
    var isGlobal: Bool {
        return self == .gfs025
    }
    
    var elevationFile: OmFileReader? {
        switch self {
        case .gfs025:
            return Self.gfs025ElevationFile
        case .nam_conus:
            return Self.namConusElevationFile
        case .hrrr_conus:
            return Self.hrrrConusElevationFile
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .gfs025:
            // GFS has a delay of 3:40 hours after initialisation. Cronjobs starts at 3:40
            return ((t.hour - 3 + 24) % 24) / 6 * 6
        case .nam_conus:
            // NAM has a delay of 1:40 hours after initialisation. Cronjob starts at 1:40
            return ((t.hour - 1 + 24) % 24) / 6 * 6
        case .hrrr_conus:
            // HRRR has a delay of 55 minutes after initlisation. Cronjob starts at xx:55
            return t.hour
        }
    }
    
    private static var gfs025ElevationFile = try? OmFileReader(file: Self.gfs025.surfaceElevationFileOm)
    private static var namConusElevationFile = try? OmFileReader(file: Self.nam_conus.surfaceElevationFileOm)
    private static var hrrrConusElevationFile = try? OmFileReader(file: Self.hrrr_conus.surfaceElevationFileOm)
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    func forecastHours(run: Int) -> [Int] {
        switch self {
        case .gfs025:
            return Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        case .nam_conus:
            return Array(0...60)
        case .hrrr_conus:
            return (run % 6 == 0) ? Array(0...48) : Array(0...18)
        }
    }
    
    /// Pressure levels. Variables HGT, TMP, RH/SPFH , UGRD, VGRD... TCDC starts at 50mb for GFS, HRR has only RH and Cloud Mixing Ratio
    /// https://earthscience.stackexchange.com/questions/12204/what-is-the-mixing-ratio-of-a-cloud
    /// http://funnel.sfsu.edu/courses/metr302/f96/handouts/moist_sum.html
    /// https://www.ecmwf.int/sites/default/files/elibrary/2005/16958-parametrization-cloud-cover.pdf
    var levels: [Int] {
        switch self {
        case .gfs025: return [10, 15, 20, 30, 40, 50, 70, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000]
        case .nam_conus:
            // nam uses level 75 instead of 70. Level 15 and 40 missing. Only use the same levels as HRRR.
            return [/*10, 20, 30,*/ 50, 75, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000]
        case .hrrr_conus:
            return [50, 75, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000]
            // all available
            //return [50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
        }
        
    }
    
    var omFileLength: Int {
        switch self {
        case .nam_conus:
            return 60 + 4*24
        case .gfs025:
            return 384 + 1 + 4*24
        case .hrrr_conus:
            return 48 + 1 + 4*24
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gfs025:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .nam_conus:
            /// labert conforomal grid https://www.emc.ncep.noaa.gov/mmb/namgrids/hrrrspecs.html
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5)
            return LambertConformalGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)
        case .hrrr_conus:
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5)
            return LambertConformalGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)
        }
    }
    
    func getGribUrl(run: Timestamp, forecastHour: Int) -> String {
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20220813/00/atmos/gfs.t00z.pgrb2.0p25.f084.idx
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.20220818/nam.t00z.conusnest.hiresf00.tm00.grib2.idx
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.20220818/conus/hrrr.t00z.wrfnatf00.grib2
        let fHH = forecastHour.zeroPadded(len: 2)
        let fHHH = forecastHour.zeroPadded(len: 3)
        switch self {
        case .gfs025:
            return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.\(run.format_YYYYMMdd)/\(run.hh)/atmos/gfs.t\(run.hh)z.pgrb2.0p25.f\(fHHH)"
        case .nam_conus:
            return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.\(run.format_YYYYMMdd)/nam.t\(run.hh)z.conusnest.hiresf\(fHH).tm00.grib2"
        case .hrrr_conus:
            return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.\(run.format_YYYYMMdd)/conus/hrrr.t\(run.hh)z.wrfprsf\(fHH).grib2"
        }
    }
}

/**
 List of all surface GFS variables
 */
enum GfsSurfaceVariable: String, CaseIterable, Codable {
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
    
    /// Only available in NAM, but at least it can be used to get a better kt index
    case clear_sky_radiation
    
    /// only GFS
    //case uv_index
    /// only GFS
    //case uv_index_clear_sky
    
    case cape
    case lifted_index
    
    case visibility
}

/**
 Types of pressure level variables
 */
enum GfsPressureVariableType: String, CaseIterable {
    case temperature
    case u_wind
    case v_wind
    case geopotential_height
    case cloudcover
    case relativehumidity
}


/**
 A pressure level variable on a given level in hPa / mb
 */
struct GfsPressureVariable: PressureVariableRespresentable {
    let variable: GfsPressureVariableType
    let level: Int
}

/**
 Combined surface and pressure level variables with all definitions for downloading and API
 */
typealias GfsVariable = SurfaceAndPressureVariable<GfsSurfaceVariable, GfsPressureVariable>

extension GfsVariable: GenericVariableMixing, GenericVariable, Hashable, Equatable {
    static func allCases(for domain: GfsDomain) -> [GfsVariable] {
        /// process level by level to reduce the time while U/V components are updated
        let pressure = domain.levels.flatMap { level in
            GfsPressureVariableType.allCases.map { variable in
                GfsVariable.pressure(GfsPressureVariable(variable: variable, level: level))
            }
        }
        let surface = GfsSurfaceVariable.allCases.map {GfsVariable.surface($0)}
        return surface + pressure
    }
    
    func gribIndexName(for domain: GfsDomain) -> String? {
        switch self {
        case .surface(let variable):
            // NAM has eoms different definitons
            if domain == .nam_conus {
                switch variable {
                case .lifted_index:
                    return ":LFTX:500-1000 mb:"
                case .cloudcover:
                    return ":TCDC:entire atmosphere (considered as a single layer):"
                case .precipitation:
                    // only 3h accumulation is availble
                    return ":APCP:surface:"
                case .showers:
                    // there is no parameterised convective precipitation field
                    // NAM and HRRR are convection-allowing models https://learningweather.psu.edu/node/90
                    return nil
                default: break
                }
            }
            
            if domain == .hrrr_conus {
                switch variable {
                case .lifted_index:
                    return ":LFTX:500-1000 mb:"
                case .showers:
                    // there is no parameterised convective precipitation field
                    // NAM and HRRR are convection-allowing models https://learningweather.psu.edu/node/90
                    return nil
                case .soil_moisture_0_to_10cm:
                    fallthrough
                case .soil_moisture_10_to_40cm:
                    fallthrough
                case .soil_moisture_40_to_100cm:
                    fallthrough
                case .soil_moisture_100_to_200cm:
                    fallthrough
                case .soil_temperature_0_to_10cm:
                    fallthrough
                case .soil_temperature_10_to_40cm:
                    fallthrough
                case .soil_temperature_40_to_100cm:
                    fallthrough
                case .soil_temperature_100_to_200cm:
                    return nil
                case .pressure_msl:
                    return nil
                default: break
                }
            }
            
            switch variable {
            case .temperature_2m:
                return ":TMP:2 m above ground:"
            case .cloudcover:
                return ":TCDC:entire atmosphere:"
            case .cloudcover_low:
                return ":LCDC:low cloud layer:"
            case .cloudcover_mid:
                return ":MCDC:middle cloud layer:"
            case .cloudcover_high:
                return ":HCDC:high cloud layer:"
            case .pressure_msl:
                return ":PRMSL:mean sea level:"
            case .relativehumidity_2m:
                return ":RH:2 m above ground:"
            case .precipitation:
                return ":APCP:surface:0-"
            case .wind_v_component_10m:
                return ":VGRD:10 m above ground:"
            case .wind_u_component_10m:
                return ":UGRD:10 m above ground:"
            case .wind_v_component_80m:
                return ":VGRD:80 m above ground:"
            case .wind_u_component_80m:
                return ":UGRD:80 m above ground:"
            case .soil_temperature_0_to_10cm:
                return ":TSOIL:0-0.1 m below ground:"
            case .soil_temperature_10_to_40cm:
                return ":TSOIL:0.1-0.4 m below ground:"
            case .soil_temperature_40_to_100cm:
                return ":TSOIL:0.4-1 m below ground:"
            case .soil_temperature_100_to_200cm:
                return ":TSOIL:1-2 m below ground:"
            case .soil_moisture_0_to_10cm:
                return ":SOILW:0-0.1 m below ground:"
            case .soil_moisture_10_to_40cm:
                return ":SOILW:0.1-0.4 m below ground:"
            case .soil_moisture_40_to_100cm:
                return ":SOILW:0.4-1 m below ground:"
            case .soil_moisture_100_to_200cm:
                return ":SOILW:1-2 m below ground:"
            case .snow_depth:
                return ":SNOD:surface:"
            case .sensible_heatflux:
                return ":SHTFL:surface:"
            case .latent_heatflux:
                return ":LHTFL:surface:"
            case .showers:
                return ":ACPCP:surface:0-"
            case .windgusts_10m:
                return ":GUST:surface:"
            case .freezinglevel_height:
                return ":HGT:0C isotherm:"
            case .shortwave_radiation:
                return ":DSWRF:surface:"
            case .frozen_precipitation_percent:
                return ":CPOFP:surface:"
            case .cape:
                return ":CAPE:surface:"
            case .lifted_index:
                return ":LFTX:surface:"
            case .visibility:
                return ":VIS:surface:"
            case .diffuse_radiation:
                // only HRRR
                if domain != .hrrr_conus {
                    return nil
                }
                return ":VDDSF:surface:"
            case .clear_sky_radiation:
                // only NAM
                if domain != .nam_conus {
                    return nil
                }
                return ":CSDSF:surface:"
            /*case .uv_index_clear_sky:
                return ":CDUVB:surface:"
            case .uv_index:
                return ":DUVB:surface:"*/
            }
        case .pressure(let v):
            let level = v.level
            switch v.variable {
            case .temperature:
                return ":TMP:\(level) mb:"
            case .u_wind:
                return ":UGRD:\(level) mb:"
            case .v_wind:
                return ":VGRD:\(level) mb:"
            case .geopotential_height:
                return ":HGT:\(level) mb:"
            case .cloudcover:
                if domain != .gfs025 {
                    // no cloud cover in HRRR and NAM
                    return nil
                }
                if level < 50 || level == 70 {
                    return nil
                }
                return ":TCDC:\(level) mb:"
            case .relativehumidity:
                return ":RH:\(level) mb:"
            }
        }
    }
    
    var skipHour0: Bool {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
            case .precipitation: return true
            case .sensible_heatflux: return true
            case .latent_heatflux: return true
            case .showers: return true
            case .shortwave_radiation: return true
            case .diffuse_radiation: return true
            case .clear_sky_radiation: return true
            default: return false
            }
        case .pressure(_):
            return false
        }
    }
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
            case .soil_moisture_0_to_10cm: return true
            case .soil_moisture_10_to_40cm: return true
            case .soil_moisture_40_to_100cm: return true
            case .soil_moisture_100_to_200cm: return true
            case .snow_depth: return true
            default: return false
            }
        case .pressure(_):
            return false
        }
    }
    
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
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
            case .clear_sky_radiation: return 1
            }
        case .pressure(let v):
            switch v.variable {
            case .temperature:
                return 20
            case .u_wind:
                return 10
            case .v_wind:
                return 10
            case .geopotential_height:
                return 1
            case .cloudcover:
                return 1
            case .relativehumidity:
                return 1
            }
        }
    }
    
    var interpolationType: InterpolationType {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
            case .temperature_2m: return .hermite
            case .cloudcover: return .hermite
            case .cloudcover_low: return .hermite
            case .cloudcover_mid: return .hermite
            case .cloudcover_high: return .hermite
            case .relativehumidity_2m: return .hermite
            case .precipitation: return .linear
            case .wind_v_component_10m: return .hermite
            case .wind_u_component_10m: return .hermite
            case .snow_depth: return .linear
            case .sensible_heatflux: return .hermite_backwards_averaged
            case .latent_heatflux: return .hermite_backwards_averaged
            case .windgusts_10m: return .linear
            case .freezinglevel_height: return .hermite
            case .shortwave_radiation: return .solar_backwards_averaged
            case .soil_temperature_0_to_10cm: return .hermite
            case .soil_temperature_10_to_40cm: return .hermite
            case .soil_temperature_40_to_100cm: return .hermite
            case .soil_temperature_100_to_200cm: return .hermite
            case .soil_moisture_0_to_10cm: return .hermite
            case .soil_moisture_10_to_40cm: return .hermite
            case .soil_moisture_40_to_100cm: return .hermite
            case .soil_moisture_100_to_200cm: return .hermite
            case .wind_v_component_80m: return .hermite
            case .wind_u_component_80m: return .hermite
            case .showers: return .linear
            case .pressure_msl: return .hermite
            case .frozen_precipitation_percent: return .nearest
            case .diffuse_radiation: return .solar_backwards_averaged
            case .clear_sky_radiation: return .solar_backwards_averaged
            case .cape: return .hermite
            case .lifted_index: return .hermite
            case .visibility: return .hermite
            }
        case .pressure(_):
            return .hermite
        }
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("Gfs interpolation not required for reader. Already 1h")
    }
    
    /// unit stored on disk... or directly read by low level reads
    var unit: SiUnit {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
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
            case .clear_sky_radiation: return .wattPerSquareMeter
            }
        case .pressure(let v):
            switch v.variable {
            case .temperature:
                return .celsius
            case .u_wind:
                return .ms
            case .v_wind:
                return .ms
            case .geopotential_height:
                return .meter
            case .cloudcover:
                return .percent
            case .relativehumidity:
                return .percent
            }
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable == .temperature_2m
        case .pressure(_):
            return false
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
            case .temperature_2m:
                return (1, -273.15)
            case .pressure_msl:
                return (1/100, 1)
            case .soil_temperature_0_to_10cm:
                return (1, -273.15)
            case .soil_temperature_10_to_40cm:
                return (1, -273.15)
            case .soil_temperature_40_to_100cm:
                return (1, -273.15)
            case .soil_temperature_100_to_200cm:
                return (1, -273.15)
            default:
                return nil
            }
        case .pressure(let v):
            switch v.variable {
            case .temperature:
                return (1, -273.15)
            default:
                return nil
            }
        }

    }
    
    var isAveragedOverForecastTime: Bool {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
            case .shortwave_radiation: return true
            case .diffuse_radiation: return true
            case .clear_sky_radiation: return false // NOTE: only in NAM
            case .sensible_heatflux: return true
            case .latent_heatflux: return true
            default: return false
            }
        case .pressure(_):
            return false
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .surface(let gfsSurfaceVariable):
            switch gfsSurfaceVariable {
            case .precipitation: fallthrough
            case .showers: return true
            default: return false
            }
        case .pressure(_):
            return false
        }
    }
}
