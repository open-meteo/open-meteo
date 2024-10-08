import Foundation
import SwiftPFor2D


/**
National Blend of Models domains
 */
enum NbmDomain: String, GenericDomain, CaseIterable {
    case nbm_conus
    
    var domainRegistry: DomainRegistry {
        switch self {
        case .nbm_conus:
            return .ncep_nbm_conus
        }
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return domainRegistry
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
        case .nbm_conus:
            return 3600
        }
    }
    
    var dtSeconds: Int {
        switch self {
        case .nbm_conus:
            return 3600
        }
    }
    
    var isGlobal: Bool {
        switch self {
        case .nbm_conus:
            return false
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .nbm_conus:
            // NBM has a delay of 55 minutes after initlisation. Cronjob starts at xx:55
            return t.with(hour: t.hour)

        }
    }
    
    var ensembleMembers: Int {
        return 1
    }
    
    /// `SecondFlush` is used to download the hours 390-840 from GFS ensemble 0.5° which are 18 hours later available
    func forecastHours(run: Int, secondFlush: Bool) -> [Int] {
        switch self {
        case .nbm_conus:
            // Has no hour 0
            // 1 to 63 hourly, 36 to 192 3-hourly, 192 to 264 in 6-hourly
            // 270 to 384 is available 10 hours later for run 0z and 12z. This data is not used
            return Array(1...35) + Array(stride(from: 36, to: 192, by: 3)) + Array(stride(from: 192, through: 264, by: 6))
        }
    }
    
    var levels: [Int] {
        switch self {
        case .nbm_conus:
            return []
        }
        
    }
    
    var omFileLength: Int {
        switch self {
        case .nbm_conus:
            return 264 + 1 + 2*24 //313
        }
    }
    
    var grid: Gridable {
        switch self {
        case .nbm_conus:
            /** grib dump
             Nx = 2345;
             Ny = 1597;
             latitudeOfFirstGridPointInDegrees = 19.229;
             longitudeOfFirstGridPointInDegrees = 233.723;
             LaDInDegrees = 25;
             LoVInDegrees = 265;    -360 => -95
             DxInMetres = 2539.7;
             DyInMetres = 2539.7;
             Latin1InDegrees = 25;
             Latin2 = 25000000;
             Latin2InDegrees = 25;
             */
            let proj = LambertConformalConicProjection(λ0: 265-360, ϕ0: 0, ϕ1: 25, ϕ2: 25, radius: 6370.997 * 1000)
            return ProjectionGrid(nx: 2345, ny: 1597, latitudeProjectionOrigion: 19.229, longitudeProjectionOrigion: 233.723-360, dx: 2539.7, dy: 2539.7, projection: proj)
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

        let yyyymmdd = run.format_YYYYMMdd
        let hh = run.hh
        
        let nbmNomads = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/blend/prod/"
        let nbmAws = "https://noaa-nbm-grib2-pds.s3.amazonaws.com/"
        let nbmServer = useArchive ? nbmAws : nbmNomads
        
        switch self {
        case .nbm_conus:
            // /blend.20241007/12/core/blend.t12z.core.f001.co.grib2.idx
            return ["\(nbmServer)blend.\(yyyymmdd)/\(hh)/core/blend.t\(hh)z.core.f\(fHHH).co.grib2"]
        }
    }
}
