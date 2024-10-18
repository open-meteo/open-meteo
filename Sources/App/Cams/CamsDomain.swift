import Foundation
import SwiftPFor2D


/// CAMS Air quality domain definitions for Europe and global domains
enum CamsDomain: String, GenericDomain, CaseIterable {
    case cams_global
    case cams_europe
    case cams_europe_reanalysis_interim
    case cams_europe_reanalysis_validated
    
    /// count of forecast hours
    var forecastHours: Int {
        switch self {
        case .cams_global:
            return 121
        case .cams_europe:
            return 97
        case .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated:
            // Downloaded in 1 month files
            return 14*24
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
        case .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated:
            return t
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .cams_global:
            return .cams_global
        case .cams_europe:
            return .cams_europe
        case .cams_europe_reanalysis_interim:
            return .cams_europe_reanalysis_interim
        case .cams_europe_reanalysis_validated:
            return .cams_europe_reanalysis_validated
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
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
    
    var omFileLength: Int {
        return forecastHours + 4*24
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .cams_global:
            return 12*3600
        case .cams_europe:
            return 24*3600
        case .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated:
            return 0
        }
    }
    
    var grid: Gridable {
        switch self {
        case .cams_global:
            return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 0.4, dy: 0.4)
        case .cams_europe, .cams_europe_reanalysis_interim, .cams_europe_reanalysis_validated:
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
    
    case formaldehyde
    case glyoxal
    case non_methane_volatile_organic_compounds
    case pm10_wildfires
    case peroxyacyl_nitrates
    case secondary_inorganic_aerosol
    case residential_elementary_carbon
    case total_elementary_carbon
    case pm2_5_total_organic_matter
    case sea_salt_aerosol
    case nitrogen_monoxide
    
    var storePreviousForecast: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .uv_index, .uv_index_clear_sky:
            return .solar_backwards_averaged
        default:
            return .hermite(bounds: 0...Float.infinity)
        }
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var unit: SiUnit {
        switch self {
        case .pm10:
            return .microgramsPerCubicMetre
        case .pm2_5:
            return .microgramsPerCubicMetre
        case .dust:
            return .microgramsPerCubicMetre
        case .aerosol_optical_depth:
            return .dimensionless
        case .carbon_monoxide:
            return .microgramsPerCubicMetre
        case .nitrogen_dioxide:
            return .microgramsPerCubicMetre
        case .ammonia:
            return .microgramsPerCubicMetre
        case .ozone:
            return .microgramsPerCubicMetre
        case .sulphur_dioxide:
            return .microgramsPerCubicMetre
        case .uv_index:
            return .dimensionless
        case .uv_index_clear_sky:
            return .dimensionless
        case .alder_pollen:
            return .grainsPerCubicMetre
        case .birch_pollen:
            return .grainsPerCubicMetre
        case .grass_pollen:
            return .grainsPerCubicMetre
        case .mugwort_pollen:
            return .grainsPerCubicMetre
        case .olive_pollen:
            return .grainsPerCubicMetre
        case .ragweed_pollen:
            return .grainsPerCubicMetre
        case .formaldehyde:
            return .microgramsPerCubicMetre
        case .glyoxal:
            return .microgramsPerCubicMetre
        case .non_methane_volatile_organic_compounds:
            return .microgramsPerCubicMetre
        case .pm10_wildfires:
            return .microgramsPerCubicMetre
        case .peroxyacyl_nitrates:
            return .microgramsPerCubicMetre
        case .secondary_inorganic_aerosol:
            return .microgramsPerCubicMetre
        case .residential_elementary_carbon:
            return .microgramsPerCubicMetre
        case .total_elementary_carbon:
            return .microgramsPerCubicMetre
        case .pm2_5_total_organic_matter:
            return .microgramsPerCubicMetre
        case .nitrogen_monoxide:
            return .microgramsPerCubicMetre
        case .sea_salt_aerosol:
            return .microgramsPerCubicMetre
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
        case .formaldehyde:
            return 10
        case .glyoxal:
            return 100
        case .non_methane_volatile_organic_compounds:
            return 1
        case .pm10_wildfires:
            return 10
        case .peroxyacyl_nitrates:
            return 10
        case .secondary_inorganic_aerosol:
            return 10
        case .residential_elementary_carbon:
            return 100
        case .total_elementary_carbon:
            return 100
        case .pm2_5_total_organic_matter:
            return 10
        case .nitrogen_monoxide:
            return 10
        case .sea_salt_aerosol:
            return 10
        }
    }
    
    /// Name of the variable in the CDS API, if available
    func getCamsEuMeta() -> (apiName: String, gribName: String, reanalysisFileName: String?)? {
        switch self {
        case .pm10:
            return ("particulate_matter_10um", "pm10_conc", "pm10")
        case .pm2_5:
            return ("particulate_matter_2.5um", "pm2p5_conc", "pm2p5")
        case .dust:
            return ("dust", "dust", "dust")
        case .carbon_monoxide:
            return ("carbon_monoxide", "co_conc", "co")
        case .nitrogen_dioxide:
            return ("nitrogen_dioxide", "no2_conc", "no2")
        case .ammonia:
            return ("ammonia", "nh3_conc", "nh3")
        case .ozone:
            return ("ozone", "o3_conc", "o3")
        case .sulphur_dioxide:
            return ("sulphur_dioxide", "so2_conc", "so2")
        case .uv_index:
            return nil
        case .uv_index_clear_sky:
            return nil
        case .alder_pollen:
            return ("alder_pollen", "apg_conc", nil)
        case .birch_pollen:
            return ("birch_pollen", "bpg_conc", nil)
        case .grass_pollen:
            return ("grass_pollen", "gpg_conc", nil)
        case .mugwort_pollen:
            return ("mugwort_pollen", "mpg_conc", nil)
        case .olive_pollen:
            return ("olive_pollen", "opg_conc", nil)
        case .ragweed_pollen:
            return ("ragweed_pollen", "rwpg_conc", nil)
        case .aerosol_optical_depth:
            return nil
        case .formaldehyde:
            return ("formaldehyde", "hcho_conc", "hcho")
        case .glyoxal:
            return ("glyoxal", "chocho_conc", "chocho")
        case .non_methane_volatile_organic_compounds:
            return ("non_methane_vocs", "nmvoc_conc", "nmvoc")
        case .pm10_wildfires:
            return ("pm10_wildfires", "pmwf_conc", "pmwildfire")
        case .peroxyacyl_nitrates:
            return ("peroxyacyl_nitrates", "pans_conc", "pans")
        case .secondary_inorganic_aerosol:
            return ("secondary_inorganic_aerosol", "sia_conc", "sia")
        case .residential_elementary_carbon:
            return ("residential_elementary_carbon", "ecres_conc", "ecres")
        case .total_elementary_carbon:
            return ("total_elementary_carbon", "ectot_conc", "ectot")
        case .pm2_5_total_organic_matter:
            return ("pm2.5_total_organic_matter", "pm2p5_total_om_conc", nil)
        case .nitrogen_monoxide:
            return ("nitrogen_monoxide", "no_conc", "no")
        case .sea_salt_aerosol:
            return ("pm10_sea_salt_dry", "pm10_ss_conc", nil)
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
            return nil // no ml137
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
        case .formaldehyde:
            return ("hcho", true, massMixingToUgm3)
        case .glyoxal:
            return ("glyoxal", true, massMixingToUgm3)
        case .non_methane_volatile_organic_compounds:
            return nil
        case .pm10_wildfires:
            return nil
        case .peroxyacyl_nitrates:
            return ("pan", true, massMixingToUgm3)
        case .secondary_inorganic_aerosol:
            return nil
        case .residential_elementary_carbon:
            return nil
        case .total_elementary_carbon:
            return nil
        case .pm2_5_total_organic_matter:
            return nil
        case .nitrogen_monoxide:
            return ("no", true, massMixingToUgm3)
        case .sea_salt_aerosol:
            return ("aermr03", true, massMixingToUgm3)
        }
    }
}
