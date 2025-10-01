enum EcmwfSeasDomain: String, GenericDomain, CaseIterable {
    /// O320 single level
    case seas5_6hourly
    
    /// N160 model and pressure levels
    case seas5_12hourly
    
    /// O320 single level, instant values
    case seas5_24hourly
    
    /// O320 Tmin/max/mean.... consider joining with 24hourly? Tmin/max needs 24 hour backshift
    //case seas5_daily
    
    /// N160 pressure levels
    case seas5_monthly_upper_level
    
    /// O320 single levels
    case seas5_monthly
    
    
    var grid: any Gridable {
        switch self {
        case .seas5_6hourly, .seas5_24hourly, .seas5_monthly:
            return GaussianGrid(type: .o320)
        case .seas5_12hourly, .seas5_monthly_upper_level:
            return GaussianGrid(type: .n160)
        }
    }
    
    var countEnsembleMember: Int {
        switch self {
        case .seas5_6hourly, .seas5_12hourly, .seas5_24hourly:
            return 51
        case .seas5_monthly, .seas5_monthly_upper_level:
            return 1
        }
    }
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .seas5_6hourly:
            return .ecmwf_seas5_6hourly
        case .seas5_12hourly:
            return .ecmwf_seas5_12hourly
        case .seas5_24hourly:
            return .ecmwf_seas5_24hourly
        case .seas5_monthly_upper_level:
            return .ecmwf_seas5_monthly_upper_level
        case .seas5_monthly:
            return .ecmwf_seas5_monthly
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .seas5_6hourly:
            return .ecmwf_seas5_6hourly
        case .seas5_12hourly:
            return .ecmwf_seas5_12hourly
        case .seas5_24hourly:
            return .ecmwf_seas5_6hourly
        case .seas5_monthly_upper_level:
            return .ecmwf_seas5_12hourly
        case .seas5_monthly:
            return .ecmwf_seas5_6hourly
        }
    }
    
    var dtSeconds: Int {
        switch self {
        case .seas5_6hourly:
            return 6*3600
        case .seas5_12hourly:
            return 12*3600
        case .seas5_24hourly:
            return 24*3600
        case .seas5_monthly_upper_level:
            return .dtSecondsMonthly
        case .seas5_monthly:
            return .dtSecondsMonthly
        }
    }
    
    var updateIntervalSeconds: Int {
        return .dtSecondsMonthly
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        return 200
    }
}
