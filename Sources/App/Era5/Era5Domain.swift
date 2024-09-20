import SwiftPFor2D

///  ERA5: https://rmets.onlinelibrary.wiley.com/doi/10.1002/qj.3803
enum CdsDomain: String, GenericDomain, CaseIterable {
    case era5
    case era5_daily
    case era5_ocean
    case era5_land
    case era5_land_daily
    case era5_ensemble
    case cerra
    case ecmwf_ifs
    case ecmwf_ifs_analysis
    case ecmwf_ifs_analysis_long_window
    case ecmwf_ifs_long_window
    
    var dtSeconds: Int {
        switch self {
        case .era5_daily, .era5_land_daily:
            return 24*3600
        case .ecmwf_ifs_long_window, .era5_ensemble:
            return 3*3600
        case .ecmwf_ifs_analysis_long_window, .ecmwf_ifs_analysis:
            return 6*3600
        default:
            return 3600
        }
    }
    
    var isGlobal: Bool {
        self != .cerra
    }
    
    var cdsDatasetName: String {
        switch self {
        case .era5, .era5_ocean, .era5_ensemble:
            return "reanalysis-era5-single-levels"
        case .era5_land:
            return "reanalysis-era5-land"
        case .cerra:
            return "reanalysis-cerra-single-levels"
        case .ecmwf_ifs, .ecmwf_ifs_analysis_long_window, .ecmwf_ifs_long_window, .ecmwf_ifs_analysis:
            return ""
        case .era5_land_daily, .era5_daily:
            fatalError()
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .era5_daily:
            return .copernicus_era5
        case .era5_land_daily:
            return .copernicus_era5_land
        case .ecmwf_ifs_analysis_long_window, .ecmwf_ifs_long_window:
            return .ecmwf_ifs
        default:
            return domainRegistry
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .era5:
            return .copernicus_era5
        case .era5_daily:
            return .copernicus_era5_daily
        case .era5_ocean:
            return .copernicus_era5_ocean
        case .era5_land:
            return .copernicus_era5_land
        case .era5_land_daily:
            return .copernicus_era5_land_daily
        case .era5_ensemble:
            return .copernicus_era5_ensemble
        case .cerra:
            return .copernicus_cerra
        case .ecmwf_ifs:
            return .ecmwf_ifs
        case .ecmwf_ifs_analysis_long_window:
            return .ecmwf_ifs_analysis_long_window
        case .ecmwf_ifs_long_window:
            return .ecmwf_ifs_long_window
        case .ecmwf_ifs_analysis:
            return .ecmwf_ifs_analysis
        }
    }
    
    var hasYearlyFiles: Bool {
        return true
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    /// Use store 14 days per om file
    var omFileLength: Int {
        // 24 hours over 21 days = 504 timesteps per file
        // Afterwards the om compressor will combine 6 locations to one chunks
        // 6 * 504 = 3024 values per compressed chunk
        // In case for a 1 year API call, around 51 kb will have to be decompressed with 34 IO operations
        return 24 * 21
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .era5:
            return 24*3600
        case .era5_daily:
            return 0
        case .era5_ocean:
            return 24*3600
        case .era5_land:
            return 24*3600
        case .era5_land_daily:
            return 0
        case .era5_ensemble:
            return 24*3600
        case .cerra:
            return 0
        case .ecmwf_ifs:
            return 24*3600
        case .ecmwf_ifs_analysis:
            return 24*3600
        case .ecmwf_ifs_analysis_long_window:
            return 24*3600
        case .ecmwf_ifs_long_window:
            return 24*3600
        }
    }
    
    var grid: Gridable {
        switch self {
        case .era5, .era5_daily:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .era5_ocean, .era5_ensemble:
            return RegularGrid(nx: 720, ny: 361, latMin: -90, lonMin: -180, dx: 0.5, dy: 0.5)
        case .era5_land, .era5_land_daily:
            return RegularGrid(nx: 3600, ny: 1801, latMin: -90, lonMin: -180, dx: 0.1, dy: 0.1)
        case .cerra:
            return ProjectionGrid(nx: 1069, ny: 1069, latitude: 20.29228...63.769516, longitude: -17.485962...74.10509, projection: LambertConformalConicProjection(λ0: 8, ϕ0: 50, ϕ1: 50, ϕ2: 50))
        case .ecmwf_ifs, .ecmwf_ifs_analysis_long_window, .ecmwf_ifs_long_window, .ecmwf_ifs_analysis:
            return GaussianGrid(type: .o1280)
        }
    }
}
