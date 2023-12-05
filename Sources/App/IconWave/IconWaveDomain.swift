import Foundation
import SwiftPFor2D

/**
 Domain definition for ICON wave models
 */
enum IconWaveDomain: String, CaseIterable, GenericDomain {
    case gwam
    case ewam
    
    static var gwamElevation = try? OmFileReader(file: IconWaveDomain.gwam.surfaceElevationFileOm)
    static var ewamElevation = try? OmFileReader(file: IconWaveDomain.ewam.surfaceElevationFileOm)
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var domainName: String {
        return rawValue
    }
    
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        switch type {
        case .soilType:
            return nil
        case .elevation:
            switch self {
            case .gwam:
                return Self.gwamElevation
            case .ewam:
                return Self.ewamElevation
            }
        }
    }
    
    /// Number of time steps in each time series optimised file. 5 days more than each run.
    var omFileLength: Int {
        let dtHours = dtSeconds/3600
        return countForecastHours + 5 * 24 / dtHours
    }
    
    var dtSeconds: Int {
        switch self {
        case .gwam:
            return 3*3600
        case .ewam:
            return 3600
        }
    }
    
    var grid: Gridable {
        switch self {
        case .gwam:
            return RegularGrid(nx: 1440, ny: 699, latMin: -85.25, lonMin: -180, dx: 0.25, dy: 0.25)
        case .ewam:
            return RegularGrid(nx: 526, ny: 721, latMin: 30, lonMin: -10.5, dx: 0.1, dy: 0.05)
        }
    }
    
    /// Number of actual forecast timesteps per run
    var countForecastHours: Int {
        switch self {
        case .gwam:
            return 59
        case .ewam:
            return 79
        }
    }
}

enum IconWaveVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    //case windspeed_10m // Disabled, because already available in better quality in regular domains
    //case winddirection_10m
    case wave_height
    case wave_period
    case wave_direction
    case wind_wave_height
    case wind_wave_period
    case wind_wave_peak_period
    case wind_wave_direction
    case swell_wave_height
    case swell_wave_period
    case swell_wave_peak_period
    case swell_wave_direction
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }
    
    /// Name used on the dwd open data server
    var dwdName: String {
        switch self {
        /*case .windspeed_10m:
            return "sp_10m"
        case .winddirection_10m:
            return "dd_10m"*/
        case .wave_height:
            return "swh"
        case .wave_period:
            return "tm10"
        case .wave_direction:
            return "mwd"
        case .wind_wave_height:
            return "shww"
        case .wind_wave_period:
            return "mpww"
        case .wind_wave_peak_period:
            return "ppww"
        case .wind_wave_direction:
            return "mdww"
        case .swell_wave_height:
            return "shts"
        case .swell_wave_period:
            return "mpts"
        case .swell_wave_peak_period:
            return "ppts"
        case .swell_wave_direction:
            return "mdts"
        }
    }
    
    /// Si unit
    var unit: SiUnit {
        switch self {
        /*case .windspeed_10m:
            return .metrePerSecond
        case .winddirection_10m:
            return .degreeDirection*/
        case .wave_height:
            return .metre
        case .wave_period:
            return .seconds
        case .wave_direction:
            return .degreeDirection
        case .wind_wave_height:
            return .metre
        case .wind_wave_period:
            return .seconds
        case .wind_wave_peak_period:
            return .seconds
        case .wind_wave_direction:
            return .degreeDirection
        case .swell_wave_height:
            return .metre
        case .swell_wave_period:
            return .seconds
        case .swell_wave_peak_period:
            return .seconds
        case .swell_wave_direction:
            return .degreeDirection
        }
    }
    
    var scalefactor: Float {
        let period: Float = 20 // 0.05s resolution
        let height: Float = 50 // 0.002m resolution
        let direction: Float = 1
        switch self {
        /*case .windspeed_10m:
            return 36 // 0.1 kmh resolution
        case .winddirection_10m:
            return direction*/
        case .wave_height:
            return height
        case .wave_period:
            return period
        case .wave_direction:
            return direction
        case .wind_wave_height:
            return height
        case .wind_wave_period:
            return period
        case .wind_wave_peak_period:
            return period
        case .wind_wave_direction:
            return direction
        case .swell_wave_height:
            return height
        case .swell_wave_period:
            return period
        case .swell_wave_peak_period:
            return period
        case .swell_wave_direction:
            return direction
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        /*case .windspeed_10m:
            return .hermite
        case .winddirection_10m:
            return .linear*/
        case .wave_height:
            return .linear
        case .wave_period:
            return .hermite(bounds: 0...Float.infinity)
        case .wave_direction:
            return .linear
        case .wind_wave_height:
            return .linear
        case .wind_wave_period:
            return .hermite(bounds: 0...Float.infinity)
        case .wind_wave_peak_period:
            return .hermite(bounds: 0...Float.infinity)
        case .wind_wave_direction:
            return .linear
        case .swell_wave_height:
            return .linear
        case .swell_wave_period:
            return .hermite(bounds: 0...Float.infinity)
        case .swell_wave_peak_period:
            return .hermite(bounds: 0...Float.infinity)
        case .swell_wave_direction:
            return .linear
        }
    }
}
