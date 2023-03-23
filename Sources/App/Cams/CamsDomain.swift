import Foundation
import SwiftPFor2D


/// CAMS Air quality domain definitions for Europe and global domains
enum CamsDomain: String, GenericDomain, CaseIterable {
    case cams_global
    case cams_europe
    
    /// count of forecast hours
    var forecastHours: Int {
        switch self {
        case .cams_global:
            return 121
        case .cams_europe:
            return 97
        }
    }
    
    /// Cams has delay of 8 hours
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .cams_global:
            return t.with(hour: t.hour > 14 ? 12 : 0)
        case .cams_europe:
            return t.with(hour: 0)
        }
    }
    
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        return nil
    }
    
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
        return 3600
    }
    
    var omFileLength: Int {
        return forecastHours + 4*24
    }
    
    var grid: Gridable {
        switch self {
        case .cams_global:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)
        case .cams_europe:
            return RegularGrid(nx: 700, ny: 420, latMin: /*30.05*/ 71.95, lonMin: -24.95, dx: 0.1, dy: -0.1)
        }
    }
}

/// Variables for CAMS. Some variables are not available in
enum CamsVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case pm10
    case pm2_5
    case dust
    case aerosol_optical_depth
    case carbon_monoxide
    case nitrogen_dioxide
    case ammonia
    case ozone
    case sulphur_dioxide
    case uv_index
    case uv_index_clear_sky
    case alder_pollen
    case birch_pollen
    case grass_pollen
    case mugwort_pollen
    case olive_pollen
    case ragweed_pollen
    
    var omFileName: String {
        return rawValue
    }
    
    var interpolation: ReaderInterpolation {
        fatalError("No interpolation required")
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        // TODO maybe it needs it
        return false
    }
    
    var unit: SiUnit {
        switch self {
        case .pm10:
            return .microgramsPerQuibicMeter
        case .pm2_5:
            return .microgramsPerQuibicMeter
        case .dust:
            return .microgramsPerQuibicMeter
        case .aerosol_optical_depth:
            return .dimensionless
        case .carbon_monoxide:
            return .microgramsPerQuibicMeter
        case .nitrogen_dioxide:
            return .microgramsPerQuibicMeter
        case .ammonia:
            return .microgramsPerQuibicMeter
        case .ozone:
            return .microgramsPerQuibicMeter
        case .sulphur_dioxide:
            return .microgramsPerQuibicMeter
        case .uv_index:
            return .dimensionless
        case .uv_index_clear_sky:
            return .dimensionless
        case .alder_pollen:
            return .grainsPerQuibicMeter
        case .birch_pollen:
            return .grainsPerQuibicMeter
        case .grass_pollen:
            return .grainsPerQuibicMeter
        case .mugwort_pollen:
            return .grainsPerQuibicMeter
        case .olive_pollen:
            return .grainsPerQuibicMeter
        case .ragweed_pollen:
            return .grainsPerQuibicMeter
        }
    }
    
    /// Scalefator for time-series files
    var scalefactor: Float {
        switch self {
        case .pm10:
            return 10
        case .pm2_5:
            return 10
        case .dust:
            return 1
        case .aerosol_optical_depth:
            return 100
        case .carbon_monoxide:
            return 1
        case .nitrogen_dioxide:
            return 10
        case .ammonia:
            return 10
        case .ozone:
            return 1
        case .sulphur_dioxide:
            return 10
        case .uv_index:
            return 20
        case .uv_index_clear_sky:
            return 20
        case .alder_pollen:
            return 10
        case .birch_pollen:
            return 10
        case .grass_pollen:
            return 10
        case .mugwort_pollen:
            return 10
        case .olive_pollen:
            return 10
        case .ragweed_pollen:
            return 10
        }
    }
    
    /// Name of the variable in the CDS API, if available
    func getCamsEuMeta() -> (apiName: String, gribName: String)? {
        switch self {
        case .pm10:
            return ("particulate_matter_10um", "pm10_conc")
        case .pm2_5:
            return ("particulate_matter_2.5um", "pm2p5_conc")
        case .dust:
            return ("dust", "dust")
        case .carbon_monoxide:
            return ("carbon_monoxide", "co_conc")
        case .nitrogen_dioxide:
            return ("nitrogen_dioxide", "no2_conc")
        case .ammonia:
            return ("ammonia", "nh3_conc")
        case .ozone:
            return ("ozone", "o3_conc")
        case .sulphur_dioxide:
            return ("sulphur_dioxide", "so2_conc")
        case .uv_index:
            return nil
        case .uv_index_clear_sky:
            return nil
        case .alder_pollen:
            return ("alder_pollen", "apg_conc")
        case .birch_pollen:
            return ("birch_pollen", "bpg_conc")
        case .grass_pollen:
            return ("grass_pollen", "gpg_conc")
        case .mugwort_pollen:
            return ("mugwort_pollen", "mpg_conc")
        case .olive_pollen:
            return ("olive_pollen", "opg_conc")
        case .ragweed_pollen:
            return ("ragweed_pollen", "rwpg_conc")
        case .aerosol_optical_depth:
            return nil
        }
    }
    
    func getCamsGlobalMeta() -> (gribname: String, isMultiLevel: Bool, scalefactor: Float)? {
        /// Air density on surface level. See https://confluence.ecmwf.int/display/UDOC/L60+model+level+definitions
        /// 1013.25/(288.09*287)*100
        let airDensitySurface: Float = 1.223803
        let massMixingToUgm3 = airDensitySurface * 1e9
        
        switch self {
        case .pm10:
            return ("pm10", false, 1e9)
        case .pm2_5:
            return ("pm2p5", false, 1e9)
        case .dust:
            return ("aermr06", true, massMixingToUgm3)
        case .carbon_monoxide:
            return ("co", true, massMixingToUgm3)
        case .nitrogen_dioxide:
            return ("no2", true, massMixingToUgm3)
        case .ammonia:
            return nil
        case .ozone:
            return ("go3", true, massMixingToUgm3)
        case .sulphur_dioxide:
            return ("so2", true, massMixingToUgm3)
        case .uv_index:
            return ("uvbed", false, 40)
        case .uv_index_clear_sky:
            return ("uvbedcs", false, 40)
        case .alder_pollen:
            return nil
        case .birch_pollen:
            return nil
        case .grass_pollen:
            return nil
        case .mugwort_pollen:
            return nil
        case .olive_pollen:
            return nil
        case .ragweed_pollen:
            return nil
        case .aerosol_optical_depth:
            return ("aod550", false, 1)
        }
    }
}
