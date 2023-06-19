import Foundation
import SwiftPFor2D


/**
 Definition of GEM domains from the Canadian Weather Service
 */
enum GemDomain: String, GenericDomain, CaseIterable {
    case gem_global
    case gem_regional
    case gem_hrdps_continental
    case gem_global_ensemble
    
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
        case .gem_global:
            return 3*3600
        case .gem_regional:
            return 3600
        case .gem_hrdps_continental:
            return 3600
        case .gem_global_ensemble:
            return 3*3600
        }
    }
    var isGlobal: Bool {
        switch self {
        case .gem_global:
            return true
        case .gem_regional:
            return false
        case .gem_hrdps_continental:
            return false
        case .gem_global_ensemble:
            return true
        }
    }

    private static var gemGlobalElevationFile = try? OmFileReader(file: Self.gem_global.surfaceElevationFileOm)
    private static var gemRegionalElevationFile = try? OmFileReader(file: Self.gem_regional.surfaceElevationFileOm)
    private static var gemHrdpsContinentalElevationFile = try? OmFileReader(file: Self.gem_hrdps_continental.surfaceElevationFileOm)
    private static var gemGlobalEnsembleElevationFile = try? OmFileReader(file: Self.gem_global_ensemble.surfaceElevationFileOm)
    
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        switch type {
        case .soilType:
            return nil
        case .elevation:
            switch self {
            case .gem_global:
                return Self.gemGlobalElevationFile
            case .gem_regional:
                return Self.gemRegionalElevationFile
            case .gem_hrdps_continental:
                return Self.gemHrdpsContinentalElevationFile
            case .gem_global_ensemble:
                return Self.gemGlobalEnsembleElevationFile
            }
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .gem_global:
            // First hours 3:40 h delay, second part 6.5 h delay
            // every 12 hours
            return t.add(-3*3600).floor(toNearest: 12*3600)
        case .gem_regional:
            // Delay of 2:47 hours to init
            // every 6 hours
            return t.add(-2*3600).floor(toNearest: 6*3600)
        case .gem_hrdps_continental:
            // Delay of 3:08 hours to init
            // every 6 hours
            return t.add(-2*3600).floor(toNearest: 6*3600)
        case .gem_global_ensemble:
            return t.add(-3*3600).floor(toNearest: 12*3600)
        }
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    func getForecastHours(run: Timestamp) -> [Int] {
        switch self {
        case .gem_global:
            return Array(stride(from: 0, through: 240, by: 3))
        case .gem_regional:
            return Array(stride(from: 0, through: 84, by: 1))
        case .gem_hrdps_continental:
            return Array(stride(from: 0, through: 48, by: 1))
        case .gem_global_ensemble:
            let through = run.hour == 0 && run.weekday == .thursday ? 768 : 384
            return Array(stride(from: 0, to: 192, by: 3)) + Array(stride(from: 192, through: through, by: 6))
        }
    }
    
    /// pressure levels
    var levels: [Int] {
        switch self {
        case .gem_global:
            fallthrough
        case .gem_regional:
            return [1015, 1000, 985, 970, 950, 925, 900, 875, 850, 800, 750, 700, 650, 600, 550, 500, 450, 400, 350, 300, 275, 250, 225, 200, 175, 150, 100, 50, 30, 20, 10/*, 5, 1*/].reversed() // 5 and 1 not available for dewpoint
        case .gem_hrdps_continental:
            return [1015, 1000, 985, 970, 950, 925, 900, 875, 850, 800, 750, 700, 650, 600, 550, 500, 450, 400, 350, 300, 275, 250, 225, 200, 175, 150, 100, 50].reversed()
        case .gem_global_ensemble:
            /// Smaller selection, same as ECMWF IFS04
            return [50, 200, 250, 300, 500, 700, 850, 925, 1000]
        }
    }
    
    var ensembleMembers: Int {
        switch self {
        case .gem_global:
            return 1
        case .gem_regional:
            return 1
        case .gem_hrdps_continental:
            return 1
        case .gem_global_ensemble:
            return 20+1
        }
    }
    
    func getUrl(run: Timestamp, hour: Int, gribName: String, server: String?) -> String {
        let h3 = hour.zeroPadded(len: 3)
        let yyyymmddhh = run.format_YYYYMMddHH
        let server = (server ?? "https://hpfx.collab.science.gc.ca/YYYYMMDD/WXO-DD/").replacingOccurrences(of: "YYYYMMDD", with: run.format_YYYYMMdd)
        switch self {
        case .gem_global:
            return "\(server)model_gem_global/15km/grib2/lat_lon/\(run.hh)/\(h3)/CMC_glb_\(gribName)_latlon.15x.15_\(yyyymmddhh)_P\(h3).grib2"
        case .gem_regional:
            return "\(server)model_gem_regional/10km/grib2/\(run.hh)/\(h3)/CMC_reg_\(gribName)_ps10km_\(yyyymmddhh)_P\(h3).grib2"
        case .gem_hrdps_continental:
            return "\(server)model_hrdps/continental/2.5km/\(run.hh)/\(h3)/\(run.format_YYYYMMdd)T\(run.hh)Z_MSC_HRDPS_\(gribName)_RLatLon0.0225_PT\(h3)H.grib2"
        case .gem_global_ensemble:
            return "\(server)ensemble/geps/grib2/raw/\(run.hh)/\(h3)/CMC_geps-raw_\(gribName)_latlon0p5x0p5_\(yyyymmddhh)_P\(h3)_allmbrs.grib2"
        }
    }
    
    var omFileLength: Int {
        switch self {
        case .gem_global:
            return 110
        case .gem_regional:
            return 78+36
        case .gem_hrdps_continental:
            return 48+36
        case .gem_global_ensemble:
            return 384/3 + 48/3 // 144
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gem_global:
            return RegularGrid(nx: 2400, ny: 1201, latMin: -90, lonMin: -180, dx: 0.15, dy: 0.15)
        case .gem_regional:
            return ProjectionGrid(nx: 935, ny: 824, latitude: 18.14503...45.405453, longitude: 217.10745...349.8256, projection: StereograpicProjection(latitude: 90, longitude: 249, radius: 6371229))
        case .gem_hrdps_continental:
            return ProjectionGrid(nx: 2540, ny: 1290, latitude: 39.626034...47.876457, longitude: -133.62952...(-40.708557), projection: RotatedLatLonProjection(latitude: -36.0885, longitude: 245.305))
        case .gem_global_ensemble:
            return RegularGrid(nx: 720, ny: 361, latMin: -90, lonMin: -180, dx: 0.5, dy: 0.5)
        }
    }
}
