import Foundation

enum GfsGraphCastDomain: String, GenericDomain, CaseIterable {
    case graphcast025
    case aigfs025
    case aigefs025
    case aigefs025_ensemble_mean
    case hgefs025_ensemble_mean
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .graphcast025:
            return .ncep_gfs_graphcast025
        case .aigfs025:
            return .ncep_aigfs025
        case .aigefs025:
            return .ncep_aigefs025
        case .hgefs025_ensemble_mean:
            return .ncep_hgefs025_ensemble_mean
        case .aigefs025_ensemble_mean:
            return .ncep_aigefs025_ensemble_mean
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return .ncep_gfs025
    }

    var hasYearlyFiles: Bool {
        return false
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var runsPerDay: Int {
        return 4
    }

    var dtSeconds: Int {
        return 6 * 3600
    }
    
    var countEnsembleMember: Int {
        switch self {
        case .graphcast025:
            return 1
        case .aigfs025:
            return 1
        case .aigefs025:
            return 30+1
        case .hgefs025_ensemble_mean:
            return 1
        case .aigefs025_ensemble_mean:
            return 1
        }
    }

    var updateIntervalSeconds: Int {
        return 6 * 3600
    }

    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .graphcast025:
            // GraphCast has a delay of 9-10 hours hours after initialisation. Cronjobs starts at 9:05
            return t.add(hours: -9).floor(toNearestHour: 6)
        case .aigfs025, .aigefs025:
            // 3:40 delay for AIGFS
            return t.add(hours: -3).floor(toNearestHour: 6)
        case .hgefs025_ensemble_mean:
            // 6:35 delay
            return t.add(hours: -6).floor(toNearestHour: 6)
        case .aigefs025_ensemble_mean:
            fatalError()
        }
    }

    func forecastHours(run: Int) -> [Int] {
        switch self {
        case .graphcast025:
            return Array(stride(from: 6, through: 384, by: 6))
        case .aigfs025, .aigefs025:
            return Array(stride(from: 0, through: 384, by: 6))
        case .hgefs025_ensemble_mean:
            return Array(stride(from: 0, through: 240, by: 6))
        case .aigefs025_ensemble_mean:
            fatalError()
        }
        
    }

//    var levels: [Int] {
//        // Switched to 13 levels from 37 on 2024-05-25. See https://github.com/NOAA-EMC/graphcast/issues/39
//        // return [10, 20, 30, 50, 70, 100, 125, 150, 175, 200, 225, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
//        return [50, 100, 150, 200, 250, 300, 400, 500, 600, 700, 850, 925, 1000]
//    }

    var omFileLength: Int {
        return 60
    }

    var grid: any Gridable {
        return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
    }
    
    var ensembleMeanDomain: Self? {
        switch self {
        case .aigefs025:
            return .aigefs025_ensemble_mean
        default:
            return nil
        }
    }
    
    /// Returns two grib files, in case grib messages are split in two different files
    func getGribUrl(run: Timestamp, forecastHour: Int, member: Int) -> [String] {
        let fHHH = forecastHour.zeroPadded(len: 3)
        let yyyymmdd = run.format_YYYYMMdd
        let hh = run.hh

        switch self {
        case .graphcast025:
            let server = "https://noaa-nws-graphcastgfs-pds.s3.amazonaws.com/"
            return ["\(server)graphcastgfs.\(run.format_YYYYMMdd)/\(run.hh)/forecasts_13_levels/graphcastgfs.t\(run.hh)z.pgrb2.0p25.f\(fHHH)"]
        case .aigefs025:
            let server = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/"
            let mmm = member.zeroPadded(len: 3)
            let base = "\(server)aigefs/prod/aigefs.\(yyyymmdd)/\(hh)/mem\(mmm)/model/atmos/grib2/"
            return ["\(base)aigefs.t\(hh)z.sfc.f\(fHHH).grib2", "\(base)aigefs.t\(hh)z.pres.f\(fHHH).grib2"]
        case .aigfs025:
            let server = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/"
            let base = "\(server)aigfs/prod/aigfs.\(yyyymmdd)/\(hh)/model/atmos/grib2/"
            return ["\(base)aigfs.t\(hh)z.sfc.f\(fHHH).grib2", "\(base)aigfs.t\(hh)z.pres.f\(fHHH).grib2"]
        case .hgefs025_ensemble_mean:
            let server = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/"
            let base = "\(server)hgefs/prod/hgefs.\(yyyymmdd)/\(hh)/ensstat/products/atmos/grib2/"
            return ["\(base)hgefs.t\(hh)z.sfc.avg.f\(fHHH).grib2", "\(base)hgefs.t\(hh)z.pres.avg.f\(fHHH).grib2", "\(base)hgefs.t\(hh)z.sfc.spr.f\(fHHH).grib2", "\(base)hgefs.t\(hh)z.pres.spr.f\(fHHH).grib2"]
        case .aigefs025_ensemble_mean:
            fatalError()
        }
    }
}
