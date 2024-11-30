import Foundation
import NIOConcurrencyHelpers
import SwiftPFor2D

/**
 ICON Domains including ensemble
 */
enum IconDomains: String, CaseIterable, GenericDomain {
    /// hourly data until forecast hour 78, then 3 h until 180
    case icon
    case iconEu = "icon-eu"
    case iconD2 = "icon-d2"
    case iconD2_15min = "icon-d2-15min"
    case iconEps = "icon-eps"
    case iconEuEps = "icon-eu-eps"
    case iconD2Eps = "icon-d2-eps"
    
    var dtSeconds: Int {
        if self == .iconD2_15min {
            return 3600/4
        }
        return 3600
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .icon:
            return .dwd_icon
        case .iconEu:
            return .dwd_icon_eu
        case .iconD2:
            return .dwd_icon_d2
        case .iconD2_15min:
            return .dwd_icon_d2_15min
        case .iconEps:
            return .dwd_icon_eps
        case .iconEuEps:
            return .dwd_icon_eu_eps
        case .iconD2Eps:
            return .dwd_icon_d2_eps
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .iconD2_15min:
            return .dwd_icon_d2
        default:
            return domainRegistry
        }
    }

    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    /// How many hourly timesteps to keep in each compressed chunk
    var omFileLength: Int {
        switch self {
        case .icon, .iconEps:
            return 180+1 + 3*24
        case .iconEu, .iconEuEps:
            return 120+1 + 3*24
        case .iconD2, .iconD2Eps:
            return 48+1 + 3*24
        case .iconD2_15min:
            return 48*4 + 3*24
        }
    }
    
    /// All available pressure levels for the current domain
    var levels: [Int] {
        switch self {
        case .icon:
            return [30, 50, 70, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 850, 900, 925, 950,      1000]
        case .iconEu:
            return [    50, 70, 100, 150, 200, 250, 300, 400, 500, 600, 700, 800, 850, 900, 925, 950,      1000] // disabled: 775, 825, 875
        case .iconD2:
            return [                      200, 250, 300, 400, 500, 600, 700,      850,           950, 975, 1000]
        case .iconD2_15min:
            return []
        case .iconEps:
            return []
        case .iconEuEps:
            return [] // 300, 500, 850 only temperature and wind
        case .iconD2Eps:
            return [] // 500, 700, 850, 950, 975, 1000
        }
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .icon:
            return 6*3600
        case .iconEu, .iconD2, .iconD2_15min:
            return 3*3600
        case .iconEps:
            return 12*3600
        case .iconEuEps:
            return 6*3600
        case .iconD2Eps:
            return 3*3600
        }
    }
    
    /// Number of available forecast steps differs from run
    /// E.g. icon global 0z has 180 as a last value, but 6z only 120
    func getDownloadForecastSteps(run: Int) -> [Int] {
        switch self {
        case .iconEps:
            // Note ICON-EPS has only 6 hourly data for 6/18z runs, not used here
            // Hourly data until 48h, 3 hourly until 72, 6 hourly until 120h (same as ICON-EU-EPS) and 12 hourly until 180h
            return Array(0...48) + Array(stride(from: 51, through: 72, by: 3)) + Array(stride(from: 78, through: 120, by: 6)) + Array(stride(from: 132, through: 180, by: 12))
        case .icon:
            if  run == 6 || run == 18  {
                // only up to 120
                return Array(0...78) + Array(stride(from: 81, through: 120, by: 3))
            } else {
                // full 180
                return Array(0...78) + Array(stride(from: 81, through: 180, by: 3))
            }
        case .iconEuEps:
            // Hourly data until 48h, 3 hourly until 72, then 6 hourly until 120h (same as ICON-EPS)
            // no side runs
            return Array(0...48) + Array(stride(from: 51, through: 72, by: 3)) + Array(stride(from: 78, through: 120, by: 6))
        case .iconEu:
            if run % 6 == 0 {
                return Array(0...78) + Array(stride(from: 81, through: 120, by: 3))
            }
            // side runs
            return Array(0...30)
        case .iconD2_15min:
            return Array(0...48*4-1)
        case .iconD2Eps:
            fallthrough
        case .iconD2:
            return Array(0...48)
        }
    }

    var grid: Gridable {
        switch self {
        case .icon:
            return RegularGrid(nx: 2879, ny: 1441, latMin: -90, lonMin: -180, dx: 0.125, dy: 0.125)
        case .iconEu:
            return RegularGrid(nx: 1377, ny: 657, latMin: 29.5, lonMin: -23.5, dx: 0.0625, dy: 0.0625)
        case .iconD2_15min:
            fallthrough
        case .iconD2:
            return RegularGrid(nx: 1215, ny: 746, latMin: 43.18, lonMin: -3.94, dx: 0.02, dy: 0.02)
        case .iconEps:
            // R03B06 avg 26.5 km
            return RegularGrid(nx: 1439, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .iconEuEps:
            // R03B07 avg 13.2 km
            return RegularGrid(nx: 689, ny: 329, latMin: 29.5, lonMin: -23.5, dx: 0.125, dy: 0.125)
        case .iconD2Eps:
            // R19B07 avg 2 km
            // Note: 1px difference to use the same weights as official
            return RegularGrid(nx: 1214, ny: 745, latMin: 43.18, lonMin: -3.94, dx: 0.02, dy: 0.02)
        }
    }
    
    /// name in the filenames
    var region: String {
        switch self {
        case .iconEps: fallthrough
        case .icon: return "global"
        case .iconEuEps: fallthrough
        case .iconEu: return "europe"
        case .iconD2Eps: fallthrough
        case .iconD2_15min: fallthrough
        case .iconD2: return "germany"
        }
    }
    
    /// model level standard heights, full levels
    /// icon wind level 1-90 88=98m, 87-174m
    /// icon-eu 1-60 58,57
    /// icon-d2 1-65.... 63=78m, 62=126m
    var numberOfModelFullLevels: Int {
        switch self {
        case .iconEps:
            fallthrough
        case .icon:
            return 120 // was 90
        case .iconEuEps:
            fallthrough
        case .iconEu:
            return 74 // was 60
        case .iconD2Eps:
            fallthrough
        case .iconD2_15min:
            fallthrough
        case .iconD2:
            return 65
        }
    }
    
    /// ICON uses 1.5°C melting point temperature: https://gitlab.dkrz.de/icon/icon-model/-/blob/release-2024.01-public/src/atm_phy_nwp/mo_nh_interface_nwp.f90?ref_type=heads#L2232
    static let tMelt = Float(1.5)
}
