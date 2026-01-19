enum EcmwfSeasDomain: String, GenericDomain, CaseIterable {
    /// O320 single level, 6 hourly data, 51 members
    case seas5
    case seas5_ensemble_mean
    
    /// N160 model and pressure levels, 6 hourly data, 51 members
    case seas5_12hourly
    
    /// O320 single level, 51 member, instant values for soil temperature and moisture
    case seas5_daily
    case seas5_daily_ensemble_mean
    
    /// N160 pressure levels
    case seas5_monthly_upper_level
    
    /// O320 single levels
    case seas5_monthly
    
    /// O320 grid, 6 hourly data, 51 members
    case ec46
    
    /// O320 grid, 6 hourly data, calculated mean+spread from 51 members
    case ec46_ensemble_mean
    
    /// O320 grid, weekly mean/anomaly/sot/efi/probabilities
    case ec46_weekly
    
    
    var grid: any Gridable {
        switch self {
        case .seas5, .seas5_daily, .seas5_monthly, .ec46, .ec46_weekly, .ec46_ensemble_mean, .seas5_ensemble_mean, .seas5_daily_ensemble_mean:
            return GaussianGrid(type: .o320)
        case .seas5_12hourly, .seas5_monthly_upper_level:
            return GaussianGrid(type: .n160)
        }
    }
    
    var ensembleMeanDomain: Self? {
        switch self {
        case .ec46:
            return .ec46_ensemble_mean
        case .seas5:
            return .seas5_ensemble_mean
        case .seas5_daily:
            return .seas5_daily_ensemble_mean
        default:
            return nil
        }
    }
    
    var countEnsembleMember: Int {
        switch self {
        case .seas5, .seas5_daily, .ec46:
            return 51
        case .seas5_12hourly:
            return 11
        case .seas5_monthly, .seas5_monthly_upper_level, .ec46_weekly, .ec46_ensemble_mean, .seas5_ensemble_mean, .seas5_daily_ensemble_mean:
            return 1
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .seas5:
            return .ecmwf_seas5
        case .seas5_12hourly:
            return .ecmwf_seas5_12hourly
        case .seas5_daily:
            return .ecmwf_seas5_daily
        case .seas5_monthly_upper_level:
            return .ecmwf_seas5_monthly_upper_level
        case .seas5_monthly:
            return .ecmwf_seas5_monthly
        case .ec46:
            return .ecmwf_ec46
        case .ec46_weekly:
            return .ecmwf_ec46_weekly
        case .ec46_ensemble_mean:
            return .ecmwf_ec46_ensemble_mean
        case .seas5_ensemble_mean:
            return .ecmwf_seas5_ensemble_mean
        case .seas5_daily_ensemble_mean:
            return .ecmwf_seas5_daily_ensemble_mean
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .seas5, .ec46, .ec46_weekly, .ec46_ensemble_mean, .seas5_ensemble_mean, .seas5_daily_ensemble_mean:
            return .ecmwf_seas5
        case .seas5_12hourly:
            return .ecmwf_seas5_12hourly
        case .seas5_daily:
            return .ecmwf_seas5
        case .seas5_monthly_upper_level:
            return .ecmwf_seas5_12hourly
        case .seas5_monthly:
            return .ecmwf_seas5
        }
    }
    
    var dtSeconds: Int {
        switch self {
        case .seas5, .ec46 ,.ec46_ensemble_mean, .seas5_ensemble_mean:
            return 6*3600
        case .seas5_12hourly:
            return 12*3600
        case .seas5_daily, .seas5_daily_ensemble_mean:
            return 24*3600
        case .seas5_monthly_upper_level:
            return .dtSecondsMonthly
        case .seas5_monthly:
            return .dtSecondsMonthly
        case .ec46_weekly:
            return 7*24*3600
        }
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .ec46_weekly, .ec46:
            return 24*3600
        default:
            return .dtSecondsMonthly
        }
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        switch self {
        case .ec46:
            return 46*24 / 6 // 184
        default:
            return 200
        }
    }
}
