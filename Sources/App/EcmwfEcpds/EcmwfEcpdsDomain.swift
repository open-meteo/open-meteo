/// ECMWF weather models directly retrieved via ECPDS delivery
enum EcmwfEcpdsDomain: String, GenericDomain {
    case ifs
    case wam
    
    case ifs_europe_ensemble
    case ifs_europe_ensemble_mean
    
    case aifs_europe_ensemble
    case aifs_europe_ensemble_mean

    func getDownloadForecastSteps(run: Int) -> [Int] {
        switch self {
        case .ifs, .wam, .ifs_europe_ensemble, .ifs_europe_ensemble_mean:
            switch run {
            case 0, 12: return Array(stride(from: 0, through: 90, by: 1)) +  Array(stride(from: 93, through: 144, by: 3)) + Array(stride(from: 150, through: 360, by: 6))
            case 6, 18: return Array(stride(from: 0, through: 90, by: 1)) +  Array(stride(from: 93, through: 144, by: 3))
            default: fatalError("Invalid run")
            }
        case .aifs_europe_ensemble, .aifs_europe_ensemble_mean:
            return Array(stride(from: 0, through: 360, by: 6))
        }

    }

    var domainRegistry: DomainRegistry {
        switch self {
        case .ifs:
            return .ecmwf_ifs
        case .wam:
            return .ecmwf_wam
        case .ifs_europe_ensemble:
            return .ecmwf_ifs_europe_ensemble
        case .ifs_europe_ensemble_mean:
            return .ecmwf_ifs_europe_ensemble_mean
        case .aifs_europe_ensemble:
            return .ecmwf_aifs_europe_ensemble
        case .aifs_europe_ensemble_mean:
            return .ecmwf_aifs_europe_ensemble_mean
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
        case .ifs, .wam, .ifs_europe_ensemble, .ifs_europe_ensemble_mean:
            // 15 days forecast, 1-hourly data.
            // Must be `24 * 21` for compatibility reasons from old IFS HRES data
            return 24 * 21 // 504
        case .aifs_europe_ensemble, .aifs_europe_ensemble_mean:
            return 8 * (15 + 4) // 152
        }
    }

    var dtSeconds: Int {
        switch self {
        case .ifs, .wam, .ifs_europe_ensemble, .ifs_europe_ensemble_mean:
            return 3600
        case .aifs_europe_ensemble, .aifs_europe_ensemble_mean:
            return 6*3600
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .ifs, .wam, .ifs_europe_ensemble, .ifs_europe_ensemble_mean, .aifs_europe_ensemble, .aifs_europe_ensemble_mean:
            return 6 * 3600
        }
    }

    var grid: any Gridable {
        switch self {
        case .ifs, .wam:
            return GaussianGrid(type: .o1280)
        case .ifs_europe_ensemble, .ifs_europe_ensemble_mean:
            return GaussianGridArea(type: .o1280, bounds: BoundingBoxWGS84(latitude: 33.005..<70.967, longitude: -11..<37))
        case .aifs_europe_ensemble, .aifs_europe_ensemble_mean:
            return GaussianGridArea(type: .n320, bounds: BoundingBoxWGS84(latitude: 33.0211..<70.9601, longitude: -11..<37))
        }
    }

    var countEnsembleMember: Int {
        switch self {
        case .ifs, .wam, .ifs_europe_ensemble_mean, .aifs_europe_ensemble_mean:
            return 1
        case .ifs_europe_ensemble, .aifs_europe_ensemble:
            return 51
        }
    }
    
    var ensembleMeanDomain: EcmwfEcpdsDomain? {
        switch self {
        case .ifs_europe_ensemble:
            return .ifs_europe_ensemble_mean
        case .aifs_europe_ensemble:
            return .aifs_europe_ensemble_mean
        default:
            return nil
        }
    }

    var isEnsemble: Bool {
        return countEnsembleMember > 1
    }
    
    var generateFullRun: Bool {
        // Force full run database also for ensembles
        return true
    }
    
    var generateTimeSeries: Bool {
        switch self {
        case .ifs:
            return true
        case .wam:
            return true
        case .ifs_europe_ensemble, .aifs_europe_ensemble:
            return false
        case .ifs_europe_ensemble_mean, .aifs_europe_ensemble_mean:
            return true
        }
    }
    
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .ifs, .wam, .ifs_europe_ensemble, .ifs_europe_ensemble_mean, .aifs_europe_ensemble, .aifs_europe_ensemble_mean:
            // https://confluence.ecmwf.int/display/DAC/Dissemination+schedule
            // IFS has a delay of 5:45
            // the last step being available at 7:34 (0z/12z) or 6:27 (6z/18z)
            // OpenMeteo uses pre-delivery schedule with files available at 5:02
            // Cronjobs start at 4:45
            return t.subtract(hours: 4).floor(toNearestHour: 6)
        }
    }
    
    func getUrl(run: Timestamp, timestamp: Timestamp, server: String) -> [String] {
        let is50R1 = run >= Timestamp(2026, 5, 12, 6, 0)
        switch self {
        case .ifs:
            // old legacy format
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            let file = hour == 0 ? 11 : 1
            let prefix = (run.hour % 12 == 0 || is50R1) ? "D" : "S"
            let url = "\(server)D1\(prefix)\(run.format_MMddHH)00\(timestamp.format_MMddHH)\(file.zeroPadded(len: 3)).bz2"
            return [url]
        case .wam:
            // ope_d2_ifs-ens-cf_od_scwv_fc_20251116T180000Z_20251116T180000Z_0h.bz2
            // ope_d2_ifs-ens-cf_od_wave_fc_20251109T000000Z_20251109T000000Z_0h.bz2
            let stream = (run.hour % 12 == 0 || is50R1) ? "wave" : "scwv"
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            let url = "\(server)ope_d2_ifs-ens-cf_od_\(stream)_fc_\(run.iso8601_YYYYMMddTHHmm)00Z_\(timestamp.iso8601_YYYYMMddTHHmm)00Z_\(hour)h.bz2"
            return [url]
        case .ifs_europe_ensemble, .ifs_europe_ensemble_mean:
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            // ope_i1_ifs-ens_od_enfo_pf_20260424T060000Z_20260430T060000Z_144h.bz2
            // ope_i1_ifs-ens_od_enfo_cf_20260424T060000Z_20260430T060000Z_144h.bz2
            return [
                "\(server)ope_i1_ifs-ens-cf_od_oper_fc_\(run.iso8601_YYYYMMddTHHmm)00Z_\(timestamp.iso8601_YYYYMMddTHHmm)00Z_\(hour)h.bz2",
                "\(server)ope_i1_ifs-ens_od_enfo_pf_\(run.iso8601_YYYYMMddTHHmm)00Z_\(timestamp.iso8601_YYYYMMddTHHmm)00Z_\(hour)h.bz2"
            ]
        case .aifs_europe_ensemble, .aifs_europe_ensemble_mean:
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            return [
                "\(server)ope_i2_aifs-ens_ai_enfo_cf_\(run.iso8601_YYYYMMddTHHmm)00Z_\(timestamp.iso8601_YYYYMMddTHHmm)00Z_\(hour)h.bz2",
                "\(server)ope_i2_aifs-ens_ai_enfo_pf_\(run.iso8601_YYYYMMddTHHmm)00Z_\(timestamp.iso8601_YYYYMMddTHHmm)00Z_\(hour)h.bz2"
            ]
        }
    }
}
