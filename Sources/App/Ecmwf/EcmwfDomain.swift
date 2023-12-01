import Foundation
import SwiftPFor2D


enum EcmwfDomain: String, GenericDomain {
    case ifs04
    case ifs04_ensemble
    
    func getDownloadForecastSteps(run: Int) -> [Int] {
        switch run {
        case 0,12: return Array(stride(from: 0, through: 144, by: 3)) + Array(stride(from: 150, through: 240, by: 6))
        case 6,18: return Array(stride(from: 0, through: 90, by: 3))
        default: fatalError("Invalid run")
        }
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var initFileName: String {
        return "\(omfileDirectory)init.txt"
    }
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)/"
    }
    
    var downloadDirectory: String {
        return "\(OpenMeteo.tempDictionary)download-\(rawValue)/"
    }
    
    private static var ifs04ElevationFile = try? OmFileReader(file: Self.ifs04.surfaceElevationFileOm)
    private static var ifs04ensembleElevationFile = try? OmFileReader(file: Self.ifs04_ensemble.surfaceElevationFileOm)
    
    /// There is no elevation file for ECMWF
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        switch type {
        case .soilType:
            return nil
        case .elevation:
            switch self {
            case .ifs04:
                return Self.ifs04ElevationFile
            case .ifs04_ensemble:
                return Self.ifs04ensembleElevationFile
            }
        }
    }
    
    var omfileArchive: String? {
        return nil
    }
    var omFileMaster: (path: String, time: TimerangeDt)? {
        return nil
    }
    
    var omFileLength: Int {
        // 104
        return (240 + 3*24) / dtHours
    }
    
    var dtSeconds: Int {
        return 3*3600
    }
    
    var grid: Gridable {
        return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 360/900, dy: 180/450)
    }
    
    var ensembleMembers: Int {
        switch self {
        case .ifs04:
            return 1
        case .ifs04_ensemble:
            return 50+1
        }
    }
}
