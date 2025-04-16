import Foundation
import OmFileFormat

/**
National Blend of Models domains
 */
enum NbmDomain: String, GenericDomain, CaseIterable {
    case nbm_conus
    case nbm_alaska

    var domainRegistry: DomainRegistry {
        switch self {
        case .nbm_conus:
            return .ncep_nbm_conus
        case .nbm_alaska:
            return .ncep_nbm_alaska
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
        return (24 * 3600) / updateIntervalSeconds
    }

    var updateIntervalSeconds: Int {
        return 3600
    }

    var dtSeconds: Int {
        return 3600
    }

    var isGlobal: Bool {
        return false
    }

    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        // NBM has a delay of 55 minutes after initlisation. Cronjob starts at xx:55
        return t.with(hour: t.hour)
    }

    var ensembleMembers: Int {
        return 1
    }

    func forecastHours(run: Int) -> [Int] {
        // Has no hour 0
        // 1 to 63 hourly, 36 to 192 3-hourly, 192 to 264 in 6-hourly
        // 270 to 384 is available 10 hours later for run 0z and 12z. This data is not used
        /**
         0z 35,36,39 ... 186,189,195 ... 264
         1z 36, 38, 41 ... 185,188,191,197 ... 263 ... ONLY PRECP 1z full 1h until 264
         2z 36,37,40 ... 184,187,190,196 ... 262
         3z 35,36,39 ... 186,189,195 ... 261
         4z 35,36,38,41 ... 185,188,194 ... 260
         5z 36,37,40 ... 184,187,193 ... 259
         6z 35,36,39 ... 189,192,198 ... 264 (like 0z)
         7z full 1h until 264 (like 1z)
         8z 36,37,40 ... 184,187,190,196 ... 262 (like 2z)
         9z 35,36,39 ... 186,189,195 ... 261 (like 3z)
         */
        switch run % 6 {
        case 1:  return Array(1..<37) + Array(stride(from: 38, to: 191, by: 3)) + Array(stride(from: 191, through: 263, by: 6))
        case 2:  return Array(1..<37) + Array(stride(from: 37, to: 190, by: 3)) + Array(stride(from: 190, through: 262, by: 6))
        case 3:  return Array(1..<36) + Array(stride(from: 36, to: 189, by: 3)) + Array(stride(from: 189, through: 261, by: 6))
        case 4:  return Array(1..<37) + Array(stride(from: 38, to: 188, by: 3)) + Array(stride(from: 188, through: 260, by: 6))
        case 5:  return Array(1..<37) + Array(stride(from: 37, to: 187, by: 3)) + Array(stride(from: 187, through: 259, by: 6))
        default: return Array(1..<36) + Array(stride(from: 36, to: 192, by: 3)) + Array(stride(from: 192, through: 264, by: 6))
        }
    }

    var levels: [Int] {
        return []
    }

    var omFileLength: Int {
        return 264 + 1 + 2 * 24 // 313
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
            let proj = LambertConformalConicProjection(λ0: 265 - 360, ϕ0: 0, ϕ1: 25, ϕ2: 25, radius: 6371200)
            return ProjectionGrid(nx: 2345, ny: 1597, latitude: 19.229, longitude: 233.723 - 360, dx: 2539.7, dy: 2539.7, projection: proj)
        case .nbm_alaska:
            /**
             Nx = 1649;
             Ny = 1105;
             latitudeOfFirstGridPointInDegrees = 40.53;
             longitudeOfFirstGridPointInDegrees = 181.429;
             LaDInDegrees = 60;
             orientationOfTheGridInDegrees = 210;
             DxInMetres = 2976.56;
             DyInMetres = 2976.56;
             iScansNegatively = 0;
             jScansPositively = 1;
             jPointsAreConsecutive = 0;
             alternativeRowScanning = 1;
             gridType = polar_stereographic;
             */
            let proj = StereograpicProjection(latitude: 90, longitude: 210, radius: 6371200)
            // Note dx/dy would need to be scaled, because they are defined as 60° latitude
            // ProjectionGrid(nx: 1649, ny: 1105, latitude: 40.53, longitude: 181.429-360, dx: 2976.56, dy: 2976.56, projection: proj)
            return ProjectionGrid(nx: 1649, ny: 1105, latitude: 40.53...63.97579, longitude: (181.429 - 360)...(-93.689514), projection: proj)
        }
    }

    /// Returns two grib files, in case grib messages are split in two differnent files
    func getGribUrl(run: Timestamp, forecastHour: Int, member: Int) -> [String] {
        let fHHH = forecastHour.zeroPadded(len: 3)
        // Files older than 48 hours are not available anymore on nomads
        let useArchive = (Timestamp.now().timeIntervalSince1970 - run.timeIntervalSince1970) > 36 * 3600

        let yyyymmdd = run.format_YYYYMMdd
        let hh = run.hh

        let nbmNomads = "https://nomads.ncep.noaa.gov/pub/data/nccf/com/blend/prod/"
        let nbmAws = "https://noaa-nbm-grib2-pds.s3.amazonaws.com/"
        let nbmServer = useArchive ? nbmAws : nbmNomads

        let nameShort: String
        switch self {
        case .nbm_conus:
            nameShort = "co"
        case .nbm_alaska:
            nameShort = "ak"
        }
        // /blend.20241007/12/core/blend.t12z.core.f001.co.grib2.idx
        return ["\(nbmServer)blend.\(yyyymmdd)/\(hh)/core/blend.t\(hh)z.core.f\(fHHH).\(nameShort).grib2"]
    }
}
