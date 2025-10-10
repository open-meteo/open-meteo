/// ECMWF weather models directly retrieved via ECPDS delivery
enum EcmwfEcpdsDomain: String, GenericDomain {
    case ifs

    func getDownloadForecastSteps(run: Int) -> [Int] {
        switch run {
        case 0, 12: return Array(stride(from: 0, through: 90, by: 1)) +  Array(stride(from: 93, through: 144, by: 3)) + Array(stride(from: 150, through: 360, by: 6))
        case 6, 18: return Array(stride(from: 0, through: 90, by: 1)) +  Array(stride(from: 93, through: 144, by: 3))
        default: fatalError("Invalid run")
        }
    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .ifs:
            return .ecmwf_ifs
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
    }

    var hasYearlyFiles: Bool {
        return true
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var omFileLength: Int {
        switch self {
        case .ifs:
            // 15 days forecast, 1-hourly data.
            // Must be `24 * 21` for compatibility reasons from old IFS HRES data
            return 24 * 21 // 504
        }
    }

    var dtSeconds: Int {
        switch self {
        case .ifs:
            return 3600
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .ifs:
            return 6 * 3600
        }
    }

    var grid: any Gridable {
        switch self {
        case .ifs:
            return GaussianGrid(type: .o1280)
        }
    }

    var countEnsembleMember: Int {
        switch self {
        case .ifs:
            return 1
        }
    }

    var isEnsemble: Bool {
        return countEnsembleMember > 1
    }
    
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .ifs:
            // https://confluence.ecmwf.int/display/DAC/Dissemination+schedule
            // IFS has a delay of 5:45
            // the last step being available at 7:34 (0z/12z) or 6:27 (6z/18z)
            // OpenMeteo uses pre-delivery schedule with files available at 5:02
            // Cronjobs start at 4:45
            return t.subtract(hours: 4).floor(toNearestHour: 6)
        }
    }
}
