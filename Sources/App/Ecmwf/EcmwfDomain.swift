import Foundation
import OmFileFormat

enum EcmwfDomain: String, SyncGridDomain {
    case ifs04
    case ifs04_ensemble

    case ifs01
    case ifs01_pressure_levels
    case ifs01_ensemble
    case ifs01_ensemble_pressure_levels
    case ifs01_ensemble_mean
    case ifs01_ensemble_pressure_levels_mean

    case ifs025
    case ifs025_ensemble
    case ifs025_ensemble_mean

    case wam01
    case wam01_ensemble
    case wam01_ensemble_mean

    case wam025
    case wam025_ensemble
    case wam025_ensemble_mean

    case aifs025
    case aifs025_single
    case aifs025_ensemble
    case aifs025_ensemble_mean
    
    var ensembleMeanDomain: Self? {
        switch self {
        case .ifs01_ensemble:
            return .ifs01_ensemble_mean
        case .ifs01_ensemble_pressure_levels:
            return .ifs01_ensemble_pressure_levels_mean
        case .ifs025_ensemble:
            return .ifs025_ensemble_mean
        case .aifs025_ensemble:
            return .aifs025_ensemble_mean
        case .wam01_ensemble:
            return .wam01_ensemble_mean
        case .wam025_ensemble:
            return .wam025_ensemble_mean
        default:
            return nil
        }
    }

    func getDownloadForecastSteps(run: Int) -> [Int] {
        if self == .aifs025 || self == .aifs025_single || self == .aifs025_ensemble {
            return Array(stride(from: 0, through: 360, by: dtHours))
        }
        let fullLength = isIfs01 || isWam01 || isEnsemble || self == .ifs025 || self == .wam025
        switch run {
        case 0, 12: return Array(stride(from: 0, through: 144, by: dtHours)) + Array(stride(from: 150, through: fullLength ? 360 : 240, by: 6))
        case 6, 18: return Array(stride(from: 0, through: fullLength ? 144 : 90, by: dtHours))
        default: fatalError("Invalid run")
        }
    }

    var isIfs01: Bool {
        switch self {
        case .ifs01, .ifs01_pressure_levels, .ifs01_ensemble, .ifs01_ensemble_pressure_levels, .ifs01_ensemble_mean, .ifs01_ensemble_pressure_levels_mean: return true
        default: return false
        }
    }

    var isWam01: Bool {
        self == .wam01 || self == .wam01_ensemble || self == .wam01_ensemble_mean
    }

    var isPressureLevels: Bool {
        switch self {
        case .ifs01_pressure_levels, .ifs01_ensemble_pressure_levels, .ifs01_ensemble_pressure_levels_mean: return true
        default: return false
        }
    }

    func includes(variable: EcmwfVariable) -> Bool {
        !isIfs01 || variable.isPressureLevel == isPressureLevels
    }

    /// IFS 0.1° supplies native clouds in its separate surface files.
    var requiresCloudCoverFromHumidity: Bool { !isIfs01 }

    var elevationDomain: Self { isIfs01 ? .ifs01 : self }

    var domainRegistry: DomainRegistry {
        switch self {
        case .ifs01:
            return .ecmwf_ifs01
        case .ifs01_pressure_levels:
            return .ecmwf_ifs01_pressure_levels
        case .ifs01_ensemble:
            return .ecmwf_ifs01_ensemble
        case .ifs01_ensemble_pressure_levels:
            return .ecmwf_ifs01_ensemble_pressure_levels
        case .ifs01_ensemble_mean:
            return .ecmwf_ifs01_ensemble_mean
        case .ifs01_ensemble_pressure_levels_mean:
            return .ecmwf_ifs01_ensemble_pressure_levels_mean
        case .ifs04:
            return .ecmwf_ifs04
        case .ifs04_ensemble:
            return .ecmwf_ifs04_ensemble
        case .ifs025:
            return .ecmwf_ifs025
        case .ifs025_ensemble:
            return .ecmwf_ifs025_ensemble
        case .aifs025:
            return .ecmwf_aifs025
        case .aifs025_single:
            return .ecmwf_aifs025_single
        case .wam01:
            return .ecmwf_wam01
        case .wam01_ensemble:
            return .ecmwf_wam01_ensemble
        case .wam01_ensemble_mean:
            return .ecmwf_wam01_ensemble_mean
        case .wam025:
            return .ecmwf_wam025
        case .wam025_ensemble:
            return .ecmwf_wam025_ensemble
        case .aifs025_ensemble:
            return .ecmwf_aifs025_ensemble
        case .ifs025_ensemble_mean:
            return .ecmwf_ifs025_ensemble_mean
        case .wam025_ensemble_mean:
            return .ecmwf_wam025_ensemble_mean
        case .aifs025_ensemble_mean:
            return .ecmwf_aifs025_ensemble_mean
        }
    }

    var syncGridRegistry: SyncGridRegistry {
        switch self {
        case .ifs01, .ifs01_pressure_levels, .ifs01_ensemble, .ifs01_ensemble_pressure_levels,
            .ifs01_ensemble_mean, .ifs01_ensemble_pressure_levels_mean,
            .wam01, .wam01_ensemble, .wam01_ensemble_mean:
            return .ecmwf_ifs01
        case .ifs04:
            return .ecmwf_ifs04
        case .ifs04_ensemble:
            // Elevation comes from the ensemble enfo file, while IFS04 uses oper/scda.
            // Keep separate until their elevation and land-sea fields are verified equivalent.
            return .ecmwf_ifs04_ensemble
        case .ifs025, .ifs025_ensemble, .ifs025_ensemble_mean,
            .aifs025, .aifs025_single, .aifs025_ensemble, .aifs025_ensemble_mean,
            .wam025, .wam025_ensemble, .wam025_ensemble_mean:
            // IFS025 ensemble uses the deterministic IFS025 file for elevation.
            // WAM025 uses IFS025 static fields because wave downloads do not generate elevation.
            return .ecmwf_ifs025
        }
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        switch self {
        case .wam01, .wam01_ensemble, .wam01_ensemble_mean, .ifs01, .ifs01_pressure_levels, .ifs01_ensemble, .ifs01_ensemble_pressure_levels, .ifs01_ensemble_mean, .ifs01_ensemble_pressure_levels_mean, .ifs04, .ifs04_ensemble, .ifs025, .ifs025_ensemble, .wam025, .wam025_ensemble, .ifs025_ensemble_mean, .wam025_ensemble_mean:
            // 10 days forecast, 3-hourly data
            return (240 + 3 * 24) / dtHours // 104
        case .aifs025, .aifs025_single, .aifs025_ensemble, .aifs025_ensemble_mean:
            // 15 days forecast, 6-hourly data
            return (360 + 3 * 24) / dtHours // 72
        }
    }

    var dtSeconds: Int {
        switch self {
        case .aifs025, .aifs025_single, .aifs025_ensemble, .aifs025_ensemble_mean:
            return 6 * 3600
        default:
            return 3 * 3600
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .wam01, .wam01_ensemble, .wam01_ensemble_mean, .ifs01, .ifs01_pressure_levels, .ifs01_ensemble, .ifs01_ensemble_pressure_levels, .ifs01_ensemble_mean, .ifs01_ensemble_pressure_levels_mean:
            return 6 * 3600
        case .ifs04, .ifs04_ensemble:
            return 6 * 3600
        case .ifs025, .ifs025_ensemble, .ifs025_ensemble_mean:
            return 6 * 3600
        case .wam025, .wam025_ensemble, .wam025_ensemble_mean:
            return 6 * 3600
        case .aifs025, .aifs025_single, .aifs025_ensemble, .aifs025_ensemble_mean:
            return 6 * 3600
        }
    }

    var countEnsembleMember: Int {
        switch self {
        case .wam01, .wam01_ensemble_mean, .ifs01, .ifs01_pressure_levels, .ifs01_ensemble_mean, .ifs01_ensemble_pressure_levels_mean, .ifs04, .ifs025, .wam025:
            return 1
        case .ifs025_ensemble_mean, .aifs025_ensemble_mean, .wam025_ensemble_mean:
            return 1
        case .wam01_ensemble, .ifs01_ensemble, .ifs01_ensemble_pressure_levels, .ifs04_ensemble, .ifs025_ensemble, .wam025_ensemble, .aifs025_ensemble:
            return 50 + 1
        case .aifs025, .aifs025_single:
            return 1
        }
    }

    var isEnsemble: Bool {
        return countEnsembleMember > 1
    }
}
