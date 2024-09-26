import Foundation
import SwiftPFor2D


/**
 GFS025 inventory: https://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs.t00z.pgrb2.0p25.f003.shtml
 GFS013 inventory: https://www.nco.ncep.noaa.gov/pmb/products/gfs/gfs.t00z.sfluxgrbf001.grib2.shtml
 NAM inventory: https://www.nco.ncep.noaa.gov/pmb/products/nam/nam.t00z.conusnest.hiresf06.tm00.grib2.shtml
 HRR inventory: https://www.nco.ncep.noaa.gov/pmb/products/hrrr/hrrr.t00z.wrfprsf02.grib2.shtml
 
 
 */
enum GfsDomain: String, GenericDomain, CaseIterable {
    /// T1534 sflux grid
    case gfs013
    
    case gfs025
    //case nam_conus // disabled because it only add 12 forecast hours
    case hrrr_conus
    
    case hrrr_conus_15min
    
    /// Actually contains raw member data.
    /// Contains up to 35 days of forecast, BUT the first 16 days are calculated at first, followed by day 16-25 18 hours later and only for 0z run.
    case gfs025_ens
    
    /// 0.5° ensemble version for up to 25 days of forecast... Low forecast skill obviously.
    case gfs05_ens
    
    case gfswave025
    
    case gfswave025_ens
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .gfs013:
            return .ncep_gfs013
        case .gfs025:
            return .ncep_gfs025
        case .hrrr_conus:
            return .ncep_hrrr_conus
        case .hrrr_conus_15min:
            return .ncep_hrrr_conus_15min
        case .gfs025_ens:
            return .ncep_gefs025
        case .gfs05_ens:
            return .ncep_gefs05
        case .gfswave025:
            return .ncep_gfswave025
        case .gfswave025_ens:
            return .ncep_gefswave025
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        switch self {
        case .hrrr_conus_15min:
            return .ncep_hrrr_conus
        case .gfswave025, .gfswave025_ens:
            return .ncep_gefs025
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
    
    var runsPerDay: Int {
        return (24*3600) / updateIntervalSeconds
    }
    
    var updateIntervalSeconds: Int {
        switch self {
        case .gfs013, .gfs025:
            return 6*3600
        case .hrrr_conus, .hrrr_conus_15min:
            return 3600
        case .gfs025_ens, .gfs05_ens:
            return 6*3600
        case .gfswave025, .gfswave025_ens:
            return 6*3600
        }
    }
    
    var dtSeconds: Int {
        switch self {
        case .gfs013:
            return 3600
        case .gfs025:
            return 3600
        case .hrrr_conus:
            return 3600
        case .gfs025_ens, .gfswave025_ens:
            return 3*3600
        case .gfs05_ens:
            return 3*3600
        case .hrrr_conus_15min:
            return 3600/4
        case .gfswave025:
            return 3600
        }
    }
    
    var isGlobal: Bool {
        switch self {
        case .gfs013:
            return true
        case .gfs025:
            return true
        case .hrrr_conus:
            return false
        case .gfs025_ens, .gfswave025_ens:
            return true
        case .gfs05_ens:
            return true
        case .hrrr_conus_15min:
            return false
        case .gfswave025:
            return true
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gfs05_ens:
            fallthrough
        case .gfs025_ens, .gfswave025_ens:
            fallthrough
        case .gfs013:
            fallthrough
        case .gfs025, .gfswave025:
            // GFS has a delay of 3:40 hours after initialisation. Cronjobs starts at 3:40
            return t.with(hour: ((t.hour - 3 + 24) % 24) / 6 * 6)
        //case .nam_conus:
            // NAM has a delay of 1:40 hours after initialisation. Cronjob starts at 1:40
            //return ((t.hour - 1 + 24) % 24) / 6 * 6
        case .hrrr_conus_15min:
            fallthrough
        case .hrrr_conus:
            // HRRR has a delay of 55 minutes after initlisation. Cronjob starts at xx:55
            return t.with(hour: t.hour)

        }
    }
    
    var ensembleMembers: Int {
        switch self {
        case .gfs05_ens:
            return 30+1
        case .gfs025_ens, .gfswave025_ens:
            return 30+1
        default:
            return 1
        }
    }
    
    /// `SecondFlush` is used to download the hours 390-840 from GFS ensemble 0.5° which are 18 hours later available
    func forecastHours(run: Int, secondFlush: Bool) -> [Int] {
        switch self {
        case .gfs05_ens:
            if secondFlush {
                return Array(stride(from: 390, through: 840, by: 6))
            }
            return Array(stride(from: 0, to: 240, by: 3)) + Array(stride(from: 240, through: 384, by: 6))
        case .gfs025_ens:
            fallthrough
        case .gfswave025_ens:
            return Array(stride(from: 0, through: 240, by: 3))
        case .gfs013:
            fallthrough
        case .gfs025:
            return Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        //case .nam_conus:
            //return Array(0...60)
        case .hrrr_conus:
            return (run % 6 == 0) ? Array(0...48) : Array(0...18)
        case .hrrr_conus_15min:
            return Array(0...18*4)
        case .gfswave025:
            return Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        }
    }
    
    /// Pressure levels. Variables HGT, TMP, RH/SPFH , UGRD, VGRD... TCDC starts at 50mb for GFS, HRR has only RH and Cloud Mixing Ratio
    /// https://earthscience.stackexchange.com/questions/12204/what-is-the-mixing-ratio-of-a-cloud
    /// http://funnel.sfsu.edu/courses/metr302/f96/handouts/moist_sum.html
    /// https://www.ecmwf.int/sites/default/files/elibrary/2005/16958-parametrization-cloud-cover.pdf
    var levels: [Int] {
        switch self {
        case .gfs05_ens:
            /// Smaler selection, same as ECMWF IFS04
            return [50, 200, 250, 300, 500, 700, 850, 925, 1000]
        case .gfs025_ens:
            return []
        case .gfs013:
            return []
        case .gfs025:
            // pgrb2
            // let all = [0.01, 0.02, 0.04, 0.07, 0.1, 0.2, 0.4, 0.7, 1, 2, 3, 5, 7, 10, 15, 20, 30, 40, 50, 70, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 975, 1000]
            // pgrb2b
            return [10, 15, 20, 30, 40, 50, 70, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
        //case .nam_conus:
            // nam uses level 75 instead of 70. Level 15 and 40 missing. Only use the same levels as HRRR.
            //return [                            100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000] // disabled: 50, 75,
        case .hrrr_conus:
            // Note: HRRR uses level 70 instead of 75
            return [                           50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
            // all available
            //return [50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
        case .hrrr_conus_15min:
            return []
        case .gfswave025, .gfswave025_ens:
            return []
        }
        
    }
    
    var omFileLength: Int {
        switch self {
        case .gfs05_ens:
            return (840 + 4*24)/3 + 1 // 313
        case .gfs025_ens:
            fallthrough
        //case .nam_conus:
            //return 60 + 4*24
        case .gfs013:
            fallthrough
        case .gfs025:
            return 384 + 1 + 4*24
        case .hrrr_conus:
            return 48 + 1 + 4*24
        case .hrrr_conus_15min:
            return 48*4*2
        case .gfswave025:
            return 384 + 1 + 4*24
        case .gfswave025_ens:
            return (384 + 4*24)/3 + 1
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gfs05_ens:
            return RegularGrid(nx: 720, ny: 361, latMin: -90, lonMin: -180, dx: 0.5, dy: 0.5)
        case .gfs013:
            // Coordinates confirmed with eccodes coordinate output
            return RegularGrid(nx: 3072, ny: 1536, latMin: -0.11714935 * (1536-1) / 2, lonMin: -180, dx: 360/3072, dy: 0.11714935)
        case .gfs025_ens:
            fallthrough
        case .gfs025, .gfswave025, .gfswave025_ens:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        /*case .nam_conus:
            /// labert conforomal grid https://www.emc.ncep.noaa.gov/mmb/namgrids/hrrrspecs.html
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5)
            return LambertConformalGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)*/
        case .hrrr_conus_15min:
            fallthrough
        case .hrrr_conus:
            /*
             (key: "Nx", value: "1799")
             (key: "Ny", value: "1059")
             (key: "latitudeOfFirstGridPointInDegrees", value: "21.1381")
             (key: "longitudeOfFirstGridPointInDegrees", value: "237.28")
             (key: "LaDInDegrees", value: "38.5")
             (key: "LoVInDegrees", value: "262.5") 262.5-360=-97.5
             (key: "Latin1InDegrees", value: "38.5")
             (key: "Latin2InDegrees", value: "38.5")
             */
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5, ϕ2: 38.5)
            return ProjectionGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)
        }
    }
    
    /// Returns two grib files, in case grib messages are split in two differnent files
    func getGribUrl(run: Timestamp, forecastHour: Int, member: Int) -> [String] {
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20220813/00/atmos/gfs.t00z.pgrb2.0p25.f084.idx
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.20220818/nam.t00z.conusnest.hiresf00.tm00.grib2.idx
        //https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/hrrr.20220818/conus/hrrr.t00z.wrfnatf00.grib2
        let fHH = forecastHour.zeroPadded(len: 2)
        let fHHH = forecastHour.zeroPadded(len: 3)
        // Files older than 48 hours are not available anymore on nomads
        let useArchive = (Timestamp.now().timeIntervalSince1970 - run.timeIntervalSince1970) > 36*3600
        /// 4 week archive
        let gfsAws = "https://noaa-gfs-bdp-pds.s3.amazonaws.com/"
        
        let gfsNomads = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/"
        let yyyymmdd = run.format_YYYYMMdd
        let hh = run.hh
        
        let gefsAws = "https://noaa-gefs-pds.s3.amazonaws.com/"
        let gefsNomads = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/"
        let gefsServer = useArchive ? gefsAws : gefsNomads
        
        let hrrrNomads = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/"
        let hrrrAws = "https://noaa-hrrr-bdp-pds.s3.amazonaws.com/"
        let hrrrServer = useArchive ? hrrrAws : hrrrNomads
        
        switch self {
        case .gfs05_ens:
            let memberString = member == 0 ? "gec00" : "gep\(member.zeroPadded(len: 2))"
            return ["\(gefsServer)gefs.\(yyyymmdd)/\(hh)/atmos/pgrb2ap5/\(memberString).t\(hh)z.pgrb2a.0p50.f\(fHHH)",
                    "\(gefsServer)gefs.\(yyyymmdd)/\(hh)/atmos/pgrb2bp5/\(memberString).t\(hh)z.pgrb2b.0p50.f\(fHHH)"]
        case .gfs025_ens:
            let memberString = member == 0 ? "gec00" : "gep\(member.zeroPadded(len: 2))"
            return ["\(gefsServer)gefs.\(yyyymmdd)/\(hh)/atmos/pgrb2sp25/\(memberString).t\(hh)z.pgrb2s.0p25.f\(fHHH)"]
        case .gfs013:
            return ["\(useArchive ? gfsAws : gfsNomads)gfs.\(yyyymmdd)/\(hh)/atmos/gfs.t\(hh)z.sfluxgrbf\(fHHH).grib2"]
        case .gfs025:
            let base = "\(useArchive ? gfsAws : gfsNomads)gfs.\(yyyymmdd)/\(hh)/atmos"
            return ["\(base)/gfs.t\(hh)z.pgrb2.0p25.f\(fHHH)", "\(base)/gfs.t\(hh)z.pgrb2b.0p25.f\(fHHH)"]
        case .gfswave025:
            // https://nomads.ncep.noaa.gov/pub/data/nccf/com/gfs/prod/gfs.20240619/00/wave/gridded/gfswave.t00z.global.0p25.f000.grib2
            let base = "\(useArchive ? gfsAws : gfsNomads)gfs.\(yyyymmdd)/\(hh)/wave/gridded"
            return ["\(base)/gfswave.t\(hh)z.global.0p25.f\(fHHH).grib2"]
        case .gfswave025_ens:
            // https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/gefs.20240619/00/wave/gridded/gefs.wave.t00z.c00.global.0p25.f000.grib2
            let memberString = member == 0 ? "c00" : "p\(member.zeroPadded(len: 2))"
            return ["\(gefsServer)gefs.\(yyyymmdd)/\(hh)/wave/gridded/gefs.wave.t\(hh)z.\(memberString).global.0p25.f\(fHHH).grib2"]
        //case .nam_conus:
        //    return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.\(run.format_YYYYMMdd)/nam.t\(run.hh)z.conusnest.hiresf\(fHH).tm00.grib2"
        case .hrrr_conus:
            //let google = "https://storage.googleapis.com/high-resolution-rapid-refresh/"
            return ["\(hrrrServer)hrrr.\(yyyymmdd)/conus/hrrr.t\(hh)z.wrfprsf\(fHH).grib2"]
        case .hrrr_conus_15min:
            return ["\(hrrrServer)hrrr.\(yyyymmdd)/conus/hrrr.t\(hh)z.wrfsubhf\(fHH).grib2"]
        }
    }
}
