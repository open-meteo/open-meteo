import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
 GFS inventory: https://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs.t00z.pgrb2.0p25.f003.shtml
 NAM inventory: https://www.nco.ncep.noaa.gov/pmb/products/nam/nam.t00z.conusnest.hiresf06.tm00.grib2.shtml
 HRR inventory: https://www.nco.ncep.noaa.gov/pmb/products/hrrr/hrrr.t00z.wrfprsf02.grib2.shtml
 */
enum NcepDomain: String, GenericDomain {
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
    
    private static var gfs025ElevationFile = try? OmFileReader(file: Self.gfs025.surfaceElevationFileOm)
    private static var namConusElevationFile = try? OmFileReader(file: Self.nam_conus.surfaceElevationFileOm)
    private static var hrrrConusElevationFile = try? OmFileReader(file: Self.hrrr_conus.surfaceElevationFileOm)
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var forecastHours: [Int] {
        switch self {
        case .gfs025:
            return Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        case .nam_conus:
            return Array(0...60)
        case .hrrr_conus:
            return Array(0...48)
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
    
    func getLeastCommonGribUrl(run: Timestamp, forecastHour: Int) -> String {
        guard self == .gfs025 else {
            fatalError("onyl for gfs")
        }
        let fHHH = forecastHour.zeroPadded(len: 3)
        /// `pgrb2b` instead of `pgrb2`
        return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.\(run.format_YYYYMMdd)/\(run.hh)/atmos/gfs.t\(run.hh)z.pgrb2b.0p25.f\(fHHH)"
    }
}


protocol GfsVariablify: GenericVariableMixing {
    func gribIndexName(for domain: NcepDomain) -> String?
    
    var skipHour0: Bool { get }
    var interpolationType: InterpolationType { get }
    var isAveragedOverForecastTime: Bool { get }
    var multiplyAdd: (multiply: Float, add: Float)? { get }
    var isAccumulatedSinceModelStart: Bool { get }
}


enum GfsSurfaceVariable: String, CaseIterable, Codable, GfsVariablify {
    case temperature_2m
    case cloudcover
    case cloudcover_low
    case cloudcover_mid
    case cloudcover_high
    case pressure_msl
    case relativehumidity_2m
    
    /// accumulated since forecast start
    case precipitation
    
    case v_10m
    case u_10m
    case v_80m
    case u_80m
    
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
    
    /// Only available in NAM, but at least it can be used to get diffuse radiation
    case clear_sky_radiation
    
    /// only GFS
    //case uv_index
    /// only GFS
    //case uv_index_clear_sky
    
    case cape
    case lifted_index
    
    case visibility
    
    var interpolation: ReaderInterpolation {
        fatalError("Gfs interpolation not required for reader. Already 1h")
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        case .showers: return true
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
        case .clear_sky_radiation: return true
        //case .uv_index: return true
        //case .uv_index_clear_sky: return true
        default: return false
        }
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
        case .v_10m: return 10
        case .u_10m: return 10
        case .v_80m: return 10
        case .u_80m: return 10
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
        //case .uv_index_clear_sky: return 20
        //case .uv_index: return 20
        }
    }
    
    /// unit stored on disk... or directly read by low level reads
    var unit: SiUnit {
        switch self {
        case .temperature_2m: return .celsius
        case .cloudcover: return .percent
        case .cloudcover_low: return .percent
        case .cloudcover_mid: return .percent
        case .cloudcover_high: return .percent
        case .relativehumidity_2m: return .percent
        case .precipitation: return .millimeter
        case .v_10m: return .ms
        case .u_10m: return .ms
        case .v_80m: return .ms
        case .u_80m: return .ms
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
        //case .uv_index: return .dimensionless
        //case .uv_index_clear_sky: return .dimensionless
        }
    }
    
    var isAveragedOverForecastTime: Bool {
        switch self {
        case .shortwave_radiation: return true
        case .diffuse_radiation: return true
        case .clear_sky_radiation: return false // NOTE: only in NAM
        //case .uv_index: return true
        //case .uv_index_clear_sky: return true
        case .sensible_heatflux: return true
        case .latent_heatflux: return true
        default: return false
        }
    }
    
    /// Soil moisture or snow depth are cumulative processes and have offests if mutliple models are mixed
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
    
    var interpolationType: InterpolationType {
        switch self {
        case .temperature_2m: return .hermite
        case .cloudcover: return .hermite
        case .cloudcover_low: return .hermite
        case .cloudcover_mid: return .hermite
        case .cloudcover_high: return .hermite
        case .relativehumidity_2m: return .hermite
        case .precipitation: return .linear
        case .v_10m: return .hermite
        case .u_10m: return .hermite
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
        case .v_80m: return .hermite
        case .u_80m: return .hermite
        case .showers: return .linear
        case .pressure_msl: return .hermite
        case .frozen_precipitation_percent: return .nearest
        case .diffuse_radiation: return .solar_backwards_averaged
        case .clear_sky_radiation: return .solar_backwards_averaged
        case .cape: return .hermite
        case .lifted_index: return .hermite
        case .visibility: return .hermite
        //case .uv_index: return .solar_backwards_averaged
        //case .uv_index_clear_sky: return .solar_backwards_averaged
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .showers: return true
        default: return false
        }
    }
    
    /// GFS has a second file with least commonly used paramerters
    //var isLeastCommonlyUsedParameter: Bool {
    //    return self == .uv_index || self == .uv_index_clear_sky
    //}
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
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
    }
    
    func gribIndexName(for domain: NcepDomain) -> String? {
        // NAM has eoms different definitons
        if domain == .nam_conus {
            switch self {
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
            switch self {
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
        
        switch self {
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
        case .v_10m:
            return ":VGRD:10 m above ground:"
        case .u_10m:
            return ":UGRD:10 m above ground:"
        case .v_80m:
            return ":VGRD:80 m above ground:"
        case .u_80m:
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
    }
}

enum GfsPressureVariableType: String, CaseIterable {
    case temperature
    case u_wind
    case v_wind
    case geopotential_height
    case cloudcover
    case relativehumidity
}

struct GfsPressureVariable: GfsVariablify {
    let variable: GfsPressureVariableType
    let level: Int
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: String {
        return "\(variable.rawValue)_\(level)hPa"
    }
    
    var scalefactor: Float {
        switch variable {
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
    
    var interpolation: ReaderInterpolation {
        switch variable {
        case .temperature:
            return .hermite
        case .u_wind:
            return .hermite
        case .v_wind:
            return .hermite
        case .geopotential_height:
            return .hermite
        case .cloudcover:
            return .hermite
        case .relativehumidity:
            return .hermite
        }
    }
    
    var unit: SiUnit {
        switch variable {
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
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var skipHour0: Bool {
        return false
    }
    
    func gribIndexName(for domain: NcepDomain) -> String? {
        switch variable {
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
    
    var interpolationType: InterpolationType {
        return .hermite
    }
    
    var isAveragedOverForecastTime: Bool {
        return false
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch variable {
        case .temperature:
            return (1, -273.15)
        default:
            return nil
        }
    }
    
    var isAccumulatedSinceModelStart: Bool {
        return false
    }
}



/// Ugly glue code to make `Codable` working. It requires a different wy of decoding URL strings to enums to get rid of the code below
enum GfsVariable: Codable, Equatable, GenericVariableMixing, RawRepresentable, Hashable {
    typealias RawValue = String
    
    case surface(GfsSurfaceVariable)
    case pressure(GfsPressureVariable)
    
    init?(rawValue: String) {
        if let pos = rawValue.lastIndex(of: "_"), let posEnd = rawValue[pos..<rawValue.endIndex].range(of: "hPa") {
            let variableString = rawValue[rawValue.startIndex ..< pos]
            guard let variable = GfsPressureVariableType(rawValue: String(variableString)) else {
                return nil
            }
            
            let start = rawValue.index(after: pos)
            let levelString = rawValue[start..<posEnd.lowerBound]
            guard let level = Int(levelString) else {
                return nil
            }
            self = .pressure(GfsPressureVariable(variable: variable, level: level))
            return
        }
        guard let variable = GfsSurfaceVariable(rawValue: rawValue) else {
            return nil
        }
        self = .surface(variable)
    }
    
    var rawValue: String {
        return omFileName
    }
    
    static func allCases(for domain: NcepDomain) -> [GfsVariable] {
        let pressure = GfsPressureVariableType.allCases.flatMap { variable in
            domain.levels.map { GfsVariable.pressure(GfsPressureVariable(variable: variable, level: $0)) }
        }
        let surface = GfsSurfaceVariable.allCases.map {GfsVariable.surface($0)}
        return surface + pressure
    }
    
    var v: GfsVariablify {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable
        case .pressure(let gfsPressureVariable):
            return gfsPressureVariable
        }
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable.requiresOffsetCorrectionForMixing
        case .pressure(let gfsPressureVariable):
            return gfsPressureVariable.requiresOffsetCorrectionForMixing
        }
    }
    
    var omFileName: String {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable.omFileName
        case .pressure(let gfsPressureVariable):
            return gfsPressureVariable.omFileName
        }
    }
    
    var scalefactor: Float {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable.scalefactor
        case .pressure(let gfsPressureVariable):
            return gfsPressureVariable.scalefactor
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable.interpolation
        case .pressure(let gfsPressureVariable):
            return gfsPressureVariable.interpolation
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable.unit
        case .pressure(let gfsPressureVariable):
            return gfsPressureVariable.unit
        }
    }
    
    var isElevationCorrectable: Bool {
        switch self {
        case .surface(let gfsSurfaceVariable):
            return gfsSurfaceVariable.isElevationCorrectable
        case .pressure(let gfsPressureVariable):
            return gfsPressureVariable.isElevationCorrectable
        }
    }
}



struct GfsVariableAndDomain: CurlIndexedVariable {
    let variable: GfsVariable
    let domain: NcepDomain
    
    var gribIndexName: String? {
        return variable.v.gribIndexName(for: domain)
    }
}


/**
NCEP GFS downloader
 */
struct NcepDownload: Command {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download GFS from NOAA NCEP"
    }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let logger = context.application.logger
        guard let domain = NcepDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        switch domain {
        case .hrrr_conus:
            fallthrough
        case .nam_conus:
            fallthrough
        case .gfs025:
            let run = signature.run.map {
                guard let run = Int($0) else {
                    fatalError("Invalid run '\($0)'")
                }
                return run
            } ?? ((Timestamp.now().hour - 2 + 24) % 24 ).floor(to: 6)
            
            let variables: [GfsVariable] = signature.onlyVariables.map {
                $0.split(separator: ",").map {
                    guard let variable = GfsVariable(rawValue: String($0)) else {
                        fatalError("Invalid variable '\($0)'")
                    }
                    return variable
                }
            } ?? GfsVariable.allCases(for: domain)
            
            /// 18z run is available the day after starting 05:26
            let date = Timestamp.now().with(hour: run)
            
            try downloadGfs(logger: logger, domain: domain, run: date, variables: variables, skipFilesIfExisting: signature.skipExisting)
            try convertGfs(logger: logger, domain: domain, variables: variables, run: date, createNetcdf: signature.createNetcdf)
        }
    }
    
    func downloadNcepElevation(logger: Logger, url: String, surfaceElevationFileOm: String, grid: Gridable, isGlobal: Bool) throws {
        /// download seamask and height
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        
        logger.info("Downloading height and elevation data")
        
        enum ElevationVariable: String, CurlIndexedVariable, CaseIterable {
            case height
            case landmask
            
            var gribIndexName: String? {
                switch self {
                case .height:
                    return ":HGT:surface:"
                case .landmask:
                    return ":LAND:surface:"
                }
            }
        }
        
        var height: Array2D? = nil
        var landmask: Array2D? = nil
        let curl = Curl(logger: logger)
        for (variable, message) in try curl.downloadIndexedGrib(url: url, variables: ElevationVariable.allCases) {
            var data = message.toArray2d()
            if isGlobal {
                data.shift180LongitudeAndFlipLatitude()
            }
            data.ensureDimensions(of: grid)
            switch variable {
            case .height:
                height = data
            case .landmask:
                landmask = data
            }
            //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue).nc")
        }
        guard var height = height, let landmask = landmask else {
            fatalError("Could not download land and sea mask")
        }
        for i in height.data.indices {
            // landmask: 0=sea, 1=land
            height.data[i] = landmask.data[i] == 1 ? height.data[i] : -999
        }
        try OmFileWriter.write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, dim0: grid.ny, dim1: grid.nx, chunk0: 20, chunk1: 20, all: height.data)
    }
    
    /// download GFS025 and NAM CONUS
    func downloadGfs(logger: Logger, domain: NcepDomain, run: Timestamp, variables: [GfsVariable], skipFilesIfExisting: Bool) throws {
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let elevationUrl = domain.getGribUrl(run: run, forecastHour: 0)
        try downloadNcepElevation(logger: logger, url: elevationUrl, surfaceElevationFileOm: domain.surfaceElevationFileOm, grid: domain.grid, isGlobal: domain.isGlobal)
        
        let curl = Curl(logger: logger)
        let forecastHours = domain.forecastHours
        
        let variables: [GfsVariableAndDomain] = variables.map {
            GfsVariableAndDomain(variable: $0, domain: domain)
        }
        
        let variablesHour0 = variables.filter({!$0.variable.v.skipHour0})
        
        for forecastHour in forecastHours {
            logger.info("Downloading forecastHour \(forecastHour)")
            let variables = (forecastHour == 0 ? variablesHour0 : variables).filter { variable in
                let fileDest = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(forecastHour).fpg"
                return !skipFilesIfExisting || !FileManager.default.fileExists(atPath: fileDest)
            }
            //let variables = variablesAll.filter({ !$0.variable.isLeastCommonlyUsedParameter })
            let url = domain.getGribUrl(run: run, forecastHour: forecastHour)
            for (variable, message) in try curl.downloadIndexedGrib(url: url, variables: variables) {
                var data = message.toArray2d()
                /*for (i,(latitude, longitude,value)) in try message.iterateCoordinatesAndValues().enumerated() {
                    if i % 10_000 == 0 {
                        print("grid \(i) lat \(latitude) lon \(longitude)")
                    }
                }
                fatalError("OK")*/
                if domain.isGlobal {
                    data.shift180LongitudeAndFlipLatitude()
                }
                data.ensureDimensions(of: domain.grid)
                //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName)_\(forecastHour).nc")
                let file = "\(domain.downloadDirectory)\(variable.variable.omFileName)_\(forecastHour).fpg"
                try FileManager.default.removeItemIfExists(at: file)
                try FloatArrayCompressor.write(file: file, data: data.data)
            }
            
            // Get least common variables
            /*let variablesLeastCommon = variablesAll.filter({ $0.variable.isLeastCommonlyUsedParameter })
            let urlLeastCommon = domain.getLeastCommonGribUrl(run: run, forecastHour: forecastHour)
            for (variable, message) in try curl.downloadIndexedGrib(url: urlLeastCommon, variables: variablesLeastCommon) {
                var data = message.toArray2d()
                if domain.isGlobal {
                    data.shift180LongitudeAndFlipLatitude()
                }
                data.ensureDimensions(of: domain.grid)
                //try data.writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.rawValue)_\(forecastHour).nc")
                let file = "\(domain.downloadDirectory)\(variable.variable.rawValue)_\(forecastHour).fpg"
                try FileManager.default.removeItemIfExists(at: file)
                try FloatArrayCompressor.write(file: file, data: data.data)
            }*/
        }
    }
    
    /// Process each variable and update time-series optimised files
    func convertGfs(logger: Logger, domain: NcepDomain, variables: [GfsVariable], run: Timestamp, createNetcdf: Bool) throws {
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        let forecastHours = domain.forecastHours
        let nForecastHours = forecastHours.max()!+1
        
        let grid = domain.grid
        let nLocation = grid.count
        
        
        for variable in variables {
            let startConvert = DispatchTime.now()
            
            if GfsVariableAndDomain(variable: variable, domain: domain).gribIndexName == nil {
                continue
            }
            
            logger.info("Converting \(variable)")
            
            var data2d = Array2DFastTime(nLocations: nLocation, nTime: nForecastHours)

            for forecastHour in forecastHours {
                if forecastHour == 0 && variable.v.skipHour0 {
                    continue
                }
                let file = "\(domain.downloadDirectory)\(variable.omFileName)_\(forecastHour).fpg"
                data2d[0..<nLocation, forecastHour] = try FloatArrayCompressor.read(file: file, nElements: nLocation)
            }
            
            let skip = variable.v.skipHour0 ? 1 : 0
            
            // Deaverage radiation. Not really correct for 3h data after 120 hours, but solar interpolation will correct it afterwards
            if variable.v.isAveragedOverForecastTime {
                switch domain {
                case .gfs025:
                    data2d.deavergeOverTime(slidingWidth: 6, slidingOffset: skip)
                case .nam_conus:
                    data2d.deavergeOverTime(slidingWidth: 3, slidingOffset: skip)
                case .hrrr_conus:
                    break
                }
            }
            
            // interpolate missing timesteps. We always fill 2 timesteps at once
            // data looks like: DDDDDDDDDD--D--D--D--D--D
            let forecastStepsToInterpolate = (0..<nForecastHours).compactMap { hour -> Int? in
                if forecastHours.contains(hour) || hour % 3 != 1 {
                    // process 2 timesteps at once
                    return nil
                }
                return hour
            }
            
            switch variable.v.interpolationType {
            case .linear:
                data2d.interpolate2StepsLinear(positions: forecastStepsToInterpolate)
            case .nearest:
                data2d.interpolate2StepsNearest(positions: forecastStepsToInterpolate)
            case .solar_backwards_averaged:
                data2d.interpolate2StepsSolarBackwards(positions: forecastStepsToInterpolate, grid: domain.grid, run: run, dtSeconds: domain.dtSeconds)
            case .hermite:
                data2d.interpolate2StepsHermite(positions: forecastStepsToInterpolate)
            case .hermite_backwards_averaged:
                data2d.interpolate2StepsHermiteBackwardsAveraged(positions: forecastStepsToInterpolate)
            }
            
            if let fma = variable.v.multiplyAdd {
                data2d.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
            }
            
            // De-accumulate precipitation
            if variable.v.isAccumulatedSinceModelStart {
                data2d.deaccumulateOverTime(slidingWidth: domain == .nam_conus ? 3 : data2d.nTime, slidingOffset: skip)
            }
            
            let ringtime = run.timeIntervalSince1970 / 3600 ..< run.timeIntervalSince1970 / 3600 + nForecastHours
            
            if createNetcdf {
                try data2d.transpose().writeNetcdf(filename: "\(domain.downloadDirectory)\(variable.omFileName).nc", nx: grid.nx, ny: grid.ny)
            }
            
            logger.info("Reading and interpolation done in \(startConvert.timeElapsedPretty()). Starting om file update")
            let startOm = DispatchTime.now()
            try om.updateFromTimeOriented(variable: variable.omFileName, array2d: data2d, ringtime: ringtime, skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor)
            logger.info("Update om finished in \(startOm.timeElapsedPretty())")
        }
    }
}
