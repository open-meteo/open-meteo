import Foundation
import SwiftPFor2D


/**
 GFS inventory: https://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs.t00z.pgrb2.0p25.f003.shtml
 NAM inventory: https://www.nco.ncep.noaa.gov/pmb/products/nam/nam.t00z.conusnest.hiresf06.tm00.grib2.shtml
 HRR inventory: https://www.nco.ncep.noaa.gov/pmb/products/hrrr/hrrr.t00z.wrfprsf02.grib2.shtml
 
 
 */
enum GfsDomain: String, GenericDomain, CaseIterable {
    /// T1534 sflux grid
    case gfs013
    
    case gfs025
    //case nam_conus // disabled because it only add 12 forecast hours
    case hrrr_conus
    
    case gfs025_ensemble
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    var omFileMaster: (path: String, time: TimerangeDt)? {
        return nil
    }
    
    var dtSeconds: Int {
        return self == .gfs025_ensemble ? 3*3600 : 3600
    }
    
    var isGlobal: Bool {
        return self == .gfs025 || self == .gfs013
    }
    
    var elevationFile: OmFileReader<MmapFile>? {
        switch self {
        case .gfs013:
            return Self.gfs013ElevationFile
        case .gfs025_ensemble:
            fallthrough
        case .gfs025:
            return Self.gfs025ElevationFile
        //case .nam_conus:
            //return Self.namConusElevationFile
        case .hrrr_conus:
            return Self.hrrrConusElevationFile
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Int {
        let t = Timestamp.now()
        switch self {
        case .gfs025_ensemble:
            fallthrough
        case .gfs013:
            fallthrough
        case .gfs025:
            // GFS has a delay of 3:40 hours after initialisation. Cronjobs starts at 3:40
            return ((t.hour - 3 + 24) % 24) / 6 * 6
        //case .nam_conus:
            // NAM has a delay of 1:40 hours after initialisation. Cronjob starts at 1:40
            //return ((t.hour - 1 + 24) % 24) / 6 * 6
        case .hrrr_conus:
            // HRRR has a delay of 55 minutes after initlisation. Cronjob starts at xx:55
            return t.hour
        }
    }
    
    private static var gfs013ElevationFile = try? OmFileReader(file: Self.gfs013.surfaceElevationFileOm)
    private static var gfs025ElevationFile = try? OmFileReader(file: Self.gfs025.surfaceElevationFileOm)
    //private static var namConusElevationFile = try? OmFileReader(file: Self.nam_conus.surfaceElevationFileOm)
    private static var hrrrConusElevationFile = try? OmFileReader(file: Self.hrrr_conus.surfaceElevationFileOm)
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    func forecastHours(run: Int) -> [Int] {
        switch self {
        case .gfs025_ensemble:
            return Array(stride(from: 0, to: 240, by: 3))
        case .gfs013:
            fallthrough
        case .gfs025:
            return Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        //case .nam_conus:
            //return Array(0...60)
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
        case .gfs025_ensemble:
            return []
        case .gfs013:
            return []
        case .gfs025:
            return [10, 15, 20, 30, 40, 50, 70, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000]
        //case .nam_conus:
            // nam uses level 75 instead of 70. Level 15 and 40 missing. Only use the same levels as HRRR.
            //return [                            100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000] // disabled: 50, 75,
        case .hrrr_conus:
            return [                            100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000]  // disabled: 50, 75,
            // all available
            //return [50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
        }
        
    }
    
    var omFileLength: Int {
        switch self {
        case .gfs025_ensemble:
            return (240 + 4*24)/3 + 1 //113
        //case .nam_conus:
            //return 60 + 4*24
        case .gfs013:
            fallthrough
        case .gfs025:
            return 384 + 1 + 4*24
        case .hrrr_conus:
            return 48 + 1 + 4*24
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gfs013:
            // Coordinates confirmed with eccodes coordinate output
            return RegularGrid(nx: 3072, ny: 1536, latMin: -0.11714935 * (1536-1) / 2, lonMin: -180, dx: 360/3072, dy: 0.11714935)
        case .gfs025_ensemble:
            fallthrough
        case .gfs025:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        /*case .nam_conus:
            /// labert conforomal grid https://www.emc.ncep.noaa.gov/mmb/namgrids/hrrrspecs.html
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5)
            return LambertConformalGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)*/
        case .hrrr_conus:
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5, ϕ2: 38.5)
            return ProjectionGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)
        }
    }
    
    func getGribUrl(run: Timestamp, forecastHour: Int) -> String {
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20220813/00/atmos/gfs.t00z.pgrb2.0p25.f084.idx
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.20220818/nam.t00z.conusnest.hiresf00.tm00.grib2.idx
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.20220818/conus/hrrr.t00z.wrfnatf00.grib2
        let fHH = forecastHour.zeroPadded(len: 2)
        let fHHH = forecastHour.zeroPadded(len: 3)
        switch self {
        case .gfs025_ensemble:
            fatalError("not supported, as it needs a member string")
        case .gfs013:
            return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.\(run.format_YYYYMMdd)/\(run.hh)/atmos/gfs.t\(run.hh)z.sfluxgrbf\(fHHH).grib2"
        case .gfs025:
            return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.\(run.format_YYYYMMdd)/\(run.hh)/atmos/gfs.t\(run.hh)z.pgrb2.0p25.f\(fHHH)"
        //case .nam_conus:
        //    return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.\(run.format_YYYYMMdd)/nam.t\(run.hh)z.conusnest.hiresf\(fHH).tm00.grib2"
        case .hrrr_conus:
            return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.\(run.format_YYYYMMdd)/conus/hrrr.t\(run.hh)z.wrfprsf\(fHH).grib2"
        }
    }
}

/**
 List of all surface GFS variables
 */
enum GfsSurfaceVariable: String, CaseIterable, Codable, GenericVariable, GenericVariableMixable {
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
    
    /// CSNOW categorical snow as percent (0-100)
    case frozen_precipitation_percent
    
    /// CFRZR
    case categorical_freezing_rain
    
    /// CICEP
    case categorical_ice_pellets
    
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
    case uv_index
    case uv_index_clear_sky
    
    case cape
    case lifted_index
    
    case visibility
    
    case precipitation_probability
    
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
        case .categorical_freezing_rain: return 1
        case .categorical_ice_pellets: return 1
        case .cape: return 0.1
        case .lifted_index: return 10
        case .visibility: return 0.05 // 50 meter
        case .diffuse_radiation: return 1
        case .uv_index: return 20
        case .uv_index_clear_sky: return 20
        case .precipitation_probability: return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .precipitation_probability:
            return .linear
        default:
            fatalError("Gfs interpolation not required for reader. Already 1h")
        }
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
        case .categorical_freezing_rain: return .percent
        case .categorical_ice_pellets: return .percent
        case .cape: return .joulesPerKilogram
        case .lifted_index: return .dimensionless
        case .visibility: return .meter
        case .diffuse_radiation: return .wattPerSquareMeter
        case .uv_index: return .dimensionless
        case .uv_index_clear_sky: return .dimensionless
        case .precipitation_probability: return .percent
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
}

/**
 Types of pressure level variables
 */
enum GfsPressureVariableType: String, CaseIterable {
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
struct GfsPressureVariable: PressureVariableRespresentable, GenericVariable, Hashable, GenericVariableMixable {
    let variable: GfsPressureVariableType
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
typealias GfsVariable = SurfaceAndPressureVariable<GfsSurfaceVariable, GfsPressureVariable>
