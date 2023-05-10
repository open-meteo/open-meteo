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
    
    /// Only used for precipitation probability on the fly
    case gfs025_ensemble
    
    /// Actually contains raw member data.
    /// Contains up to 35 days of forecast, BUT the first 16 days are calculated at first, followed by day 16-25 18 hours later and only for 0z run.
    case gfs025_ens
    
    /// 0.5° ensemble version for up to 25 days of forecast... Low forecast skill obviously.
    case gfs05_ens
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    var omfileArchive: String? {
        return nil
    }
    var omFileMaster: (path: String, time: TimerangeDt)? {
        return nil
    }
    
    var dtSeconds: Int {
        switch self {
        case .gfs013:
            return 3600
        case .gfs025:
            return 3600
        case .hrrr_conus:
            return 3600
        case .gfs025_ensemble:
            return 3*3600
        case .gfs025_ens:
            return 3*3600
        case .gfs05_ens:
            return 3*3600
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
        case .gfs025_ensemble:
            return true
        case .gfs025_ens:
            return true
        case .gfs05_ens:
            return true
        }
    }
    
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        switch type {
        case .soilType:
            return nil
        case .elevation:
            switch self {
            case .gfs05_ens:
                return Self.gfs05ensElevationFile
            case .gfs013:
                return Self.gfs013ElevationFile
            case .gfs025_ens:
                return Self.gfs025ensElevationFile
            case .gfs025_ensemble:
                fallthrough
            case .gfs025:
                return Self.gfs025ElevationFile
                //case .nam_conus:
                //return Self.namConusElevationFile
            case .hrrr_conus:
                return Self.hrrrConusElevationFile
            }
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gfs05_ens:
            fallthrough
        case .gfs025_ens:
            fallthrough
        case .gfs025_ensemble:
            fallthrough
        case .gfs013:
            fallthrough
        case .gfs025:
            // GFS has a delay of 3:40 hours after initialisation. Cronjobs starts at 3:40
            return t.with(hour: ((t.hour - 3 + 24) % 24) / 6 * 6)
        //case .nam_conus:
            // NAM has a delay of 1:40 hours after initialisation. Cronjob starts at 1:40
            //return ((t.hour - 1 + 24) % 24) / 6 * 6
        case .hrrr_conus:
            // HRRR has a delay of 55 minutes after initlisation. Cronjob starts at xx:55
            return t.with(hour: t.hour)
        }
    }
    
    private static var gfs013ElevationFile = try? OmFileReader(file: Self.gfs013.surfaceElevationFileOm)
    private static var gfs025ElevationFile = try? OmFileReader(file: Self.gfs025.surfaceElevationFileOm)
    //private static var namConusElevationFile = try? OmFileReader(file: Self.nam_conus.surfaceElevationFileOm)
    private static var hrrrConusElevationFile = try? OmFileReader(file: Self.hrrr_conus.surfaceElevationFileOm)
    private static var gfs025ensElevationFile = try? OmFileReader(file: Self.gfs025_ens.surfaceElevationFileOm)
    private static var gfs05ensElevationFile = try? OmFileReader(file: Self.gfs05_ens.surfaceElevationFileOm)
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var ensembleMembers: Int {
        switch self {
        case .gfs05_ens:
            return 30+1
        case .gfs025_ens:
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
        case .gfs025_ensemble:
            return Array(stride(from: 0, through: 240, by: 3))
        case .gfs013:
            fallthrough
        case .gfs025:
            return Array(stride(from: 0, to: 120, by: 1)) + Array(stride(from: 120, through: 384, by: 3))
        //case .nam_conus:
            //return Array(0...60)
        case .hrrr_conus:
            return (run % 6 == 0) ? Array(0...48) : Array(0...18)
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
            fallthrough
        case .gfs025_ensemble:
            return []
        case .gfs013:
            return []
        case .gfs025:
            return [10, 15, 20, 30, 40, 50, 70, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000]
        //case .nam_conus:
            // nam uses level 75 instead of 70. Level 15 and 40 missing. Only use the same levels as HRRR.
            //return [                            100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000] // disabled: 50, 75,
        case .hrrr_conus:
            return [                            100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 925, 950, 975, 1000]  // disabled: 50, 75,
            // all available
            //return [50, 75, 100, 125, 150, 175, 200, 225, 250, 275, 300, 325, 350, 375, 400, 425, 450, 475, 500, 525, 550, 575, 600, 625, 650, 675, 700, 725, 750, 775, 800, 825, 850, 875, 900, 925, 950, 975, 1000]
        }
        
    }
    
    var omFileLength: Int {
        switch self {
        case .gfs05_ens:
            return (840 + 4*24)/3 + 1 // 313
        case .gfs025_ens:
            fallthrough
        case .gfs025_ensemble:
            return (240 + 4*24)/3 + 1 // 113
        //case .nam_conus:
            //return 60 + 4*24
        case .gfs013:
            fallthrough
        case .gfs025:
            return 384 + 1 + 4*24
        case .hrrr_conus:
            return 48 + 1 + 4*24
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
        case .gfs025_ensemble:
            fallthrough
        case .gfs025:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        /*case .nam_conus:
            /// labert conforomal grid https://www.emc.ncep.noaa.gov/mmb/namgrids/hrrrspecs.html
            let proj = LambertConformalConicProjection(λ0: -97.5, ϕ0: 0, ϕ1: 38.5)
            return LambertConformalGrid(nx: 1799, ny: 1059, latitude: 21.138...47.8424, longitude: (-122.72)...(-60.918), projection: proj)*/
        case .hrrr_conus:
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
        switch self {
        case .gfs05_ens:
            let memberString = member == 0 ? "gec00" : "gep\(member.zeroPadded(len: 2))"
            return ["https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/gefs.\(yyyymmdd)/\(hh)/atmos/pgrb2ap5/\(memberString).t\(hh)z.pgrb2a.0p50.f\(fHHH)",
                    "https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/gefs.\(yyyymmdd)/\(hh)/atmos/pgrb2bp5/\(memberString).t\(hh)z.pgrb2b.0p50.f\(fHHH)"]
        case .gfs025_ensemble:
            fallthrough
        case .gfs025_ens:
            let memberString = member == 0 ? "gec00" : "gep\(member.zeroPadded(len: 2))"
            return ["https://nomads.ncep.noaa.gov/pub/data/nccf/com/gens/prod/gefs.\(yyyymmdd)/\(hh)/atmos/pgrb2sp25/\(memberString).t\(hh)z.pgrb2s.0p25.f\(fHHH)"]
        case .gfs013:
            return ["\(useArchive ? gfsAws : gfsNomads)gfs.\(yyyymmdd)/\(hh)/atmos/gfs.t\(hh)z.sfluxgrbf\(fHHH).grib2"]
        case .gfs025:
            return ["\(useArchive ? gfsAws : gfsNomads)gfs.\(yyyymmdd)/\(hh)/atmos/gfs.t\(hh)z.pgrb2.0p25.f\(fHHH)"]
        //case .nam_conus:
        //    return "https://nomads.ncep.noaa.gov/pub/data/nccf/com/nam/prod/nam.\(run.format_YYYYMMdd)/nam.t\(run.hh)z.conusnest.hiresf\(fHH).tm00.grib2"
        case .hrrr_conus:
            let nomads = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/hrrr/prod/"
            //let google = "https://storage.googleapis.com/high-resolution-rapid-refresh/"
            let aws = "https://noaa-hrrr-bdp-pds.s3.amazonaws.com/"
            return ["\(useArchive ? aws : nomads)hrrr.\(yyyymmdd)/conus/hrrr.t\(hh)z.wrfprsf\(fHH).grib2"]
        }
    }
}
