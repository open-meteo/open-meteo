import Foundation
import SwiftPFor2D

/**
 Generic domain that is required for the reader
 */
protocol GenericDomain {
    /// The grid definition. Could later be replaced with a more generic implementation
    var grid: Gridable { get }
    
    /// Domain name used as data directory
    var domainName: String { get }
    
    /// Time resoltuion of the deomain. 3600 for hourly, 10800 for 3-hourly
    var dtSeconds: Int { get }
    
    /// Where chunked time series files are stroed
    var omfileDirectory: String { get }
    
    /// If true, domain has yearly files
    var hasYearlyFiles: Bool { get }
    
    /// If present, the timerange that is available in a master file
    var masterTimeRange: Range<Timestamp>? { get }
    
    /// The time length of each compressed time series file
    var omFileLength: Int { get }
    
    /// Single master file for a large time series
    var omFileMaster: (path: String, time: TimerangeDt)? { get }
    
    /// The the file containing static information for elevation of soil types
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>?
    
    
}

extension GenericDomain {
    var dtHours: Int { dtSeconds / 3600 }
    
    /// Directory to store time chunks
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDirectory)omfile-\(domainName)/"
    }
    
    /// Temporary directory to download data
    var downloadDirectory: String {
        return "\(OpenMeteo.tempDirectory)download-\(domainName)/"
    }
    
    /// Directory for yearly files
    var omfileArchive: String {
        return "\(OpenMeteo.dataDirectory)archive-\(domainName)/"
    }
    
    /// Master file to store "all" timesteps in one file. Used only in CMIP for store 100 years a once
    var omMasterDirectory: String {
        "\(OpenMeteo.dataDirectory)master-\(domainName)/"
    }
    
    /// Single master file for a large time series
    var omFileMaster: (path: String, time: TimerangeDt)? {
        guard let time = masterTimeRange else {
            return nil
        }
        return (omMasterDirectory, TimerangeDt(range: time, dtSeconds: dtSeconds))
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var soilTypeFileOm: String {
        "\(omfileDirectory)soil_type.om"
    }
}

/**
 Generic variable for the reader implementation
 */
protocol GenericVariable: GenericVariableMixable {
    /// The filename of the variable. Typically just `temperature_2m`. Level is used to store mutliple levels or ensemble members in one file
    var omFileName: (file: String, level: Int) { get }
    
    /// The scalefactor to compress data
    var scalefactor: Float { get }
    
    /// Kind of interpolation for this variable. Used to interpolate from 1 to 3 hours
    var interpolation: ReaderInterpolation { get }
    
    /// SI unit of this variable
    var unit: SiUnit { get }
    
    /// If true, temperature will be corrected by 0.65°K per 100 m
    var isElevationCorrectable: Bool { get }
}

enum ReaderInterpolation {
    /// Simple linear interpolation
    case linear
    
    /// Hermite interpolation for more smooth interpolation for temperature
    case hermite(bounds: ClosedRange<Float>?)
    
    case solar_backwards_averaged
    
    /// Take the next hour, and devide by `dt` to preserve sums like precipitation
    case backwards_sum
    
    /// Take the next hour. E.g. used in weathercode, frozen precipitation percent
    case backwards
    
    /// How many timesteps on the left and right side are used for interpolation
    var padding: Int {
        switch self {
        case .linear:
            return 1
        case .hermite:
            return 2
        case .solar_backwards_averaged:
            return 2
        case .backwards_sum:
            return 1
        case .backwards:
            return 1
        }
    }
    
    var bounds: ClosedRange<Float>? {
        switch self {
        case .hermite(let bounds):
            return bounds
        default:
            return nil
        }
    }
}
