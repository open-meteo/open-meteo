import Foundation
import SwiftPFor2D

enum MetNoDomain: String, GenericDomain, CaseIterable {
    case nordic_pp
    
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
        return 3600
    }
    var isGlobal: Bool {
        return false
    }

    private static var nordicPpElevationFile = try? OmFileReader(file: Self.nordic_pp.surfaceElevationFileOm)
    
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        switch type {
        case .soilType:
            return nil
        case .elevation:
            switch self {
            case .nordic_pp:
                return Self.nordicPpElevationFile
            }
        }
    }
    
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    var lastRun: Timestamp {
        let t = Timestamp.now()
        // 30 min delay
        return t.with(hour: t.hour)
    }
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var omFileLength: Int {
        return 64 + 2*24
    }
    
    var grid: Gridable {
        switch self {
        case .nordic_pp:
            return ProjectionGrid(nx: 1796, ny: 2321, latitude: 52.30272...72.18527, longitude: 1.9184653...41.764282, projection: LambertConformalConicProjection(λ0: 15, ϕ0: 63, ϕ1: 63, ϕ2: 63))
        }
    }
}

enum MetNoVariable: String, CaseIterable, GenericVariable, GenericVariableMixable {
    case temperature_2m
    case cloudcover
    case pressure_msl
    case relativehumidity_2m
    case windspeed_10m
    case winddirection_10m
    case windgusts_10m
    case shortwave_radiation
    case precipitation
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        switch self {
        case .temperature_2m:
            return 20
        case .cloudcover:
            return 1
        case .relativehumidity_2m:
            return 1
        case .precipitation:
            return 10
        case .windgusts_10m:
            return 10
        case .pressure_msl:
            return 10
        case .shortwave_radiation:
            return 1
        case .windspeed_10m:
            return 10
        case .winddirection_10m:
            return 1
        }
    }
    
    var interpolation: ReaderInterpolation {
        switch self {
        case .temperature_2m:
            return .hermite(bounds: nil)
        case .cloudcover:
            return .hermite(bounds: 0...100)
        case .pressure_msl:
            return .hermite(bounds: nil)
        case .relativehumidity_2m:
            return .hermite(bounds: 0...100)
        case .windspeed_10m:
            return .hermite(bounds: nil)
        case .winddirection_10m:
            return .hermite(bounds: nil)
        case .precipitation:
            return .backwards_sum
        case .windgusts_10m:
            return .hermite(bounds: nil)
        case .shortwave_radiation:
            return .solar_backwards_averaged
        }
    }
    
    var unit: SiUnit {
        switch self {
        case .temperature_2m:
            return .celsius
        case .cloudcover:
            return .percent
        case .relativehumidity_2m:
            return .percent
        case .precipitation:
            return .millimeter
        case .windgusts_10m:
            return .ms
        case .pressure_msl:
            return .hectoPascal
        case .shortwave_radiation:
            return .wattPerSquareMeter
        case .windspeed_10m:
            return .ms
        case .winddirection_10m:
            return .degreeDirection
        }
    }
    
    var multiplyAdd: (multiply: Float, add: Float)? {
        switch self {
        case .temperature_2m:
            return (1, -273.15)
        case .cloudcover:
            return (100, 0)
        case .relativehumidity_2m:
            return (100, 0)
        case .pressure_msl:
            return (1/100, 0)
        case .shortwave_radiation:
            return (1/3600, 0)
        default:
            return nil
        }
    }
    
    var skipHour0: Bool {
        switch self {
        case .precipitation: return true
        case .shortwave_radiation: return true
        default: return false
        }
    }
    
    var isElevationCorrectable: Bool {
        return self == .temperature_2m
    }
    
    var isAccumulatedSinceModelStart: Bool {
        switch self {
        case .precipitation: fallthrough
        case .shortwave_radiation: return true
        default: return false
        }
    }
    
    var netCdfName: String {
        switch self {
        case .temperature_2m:
            return "air_temperature_2m"
        case .cloudcover:
            return "cloud_area_fraction"
        case .pressure_msl:
            return "air_pressure_at_sea_level"
        case .relativehumidity_2m:
            return "relative_humidity_2m"
        case .windspeed_10m:
            return "wind_speed_10m"
        case .winddirection_10m:
            return "wind_direction_10m"
        case .windgusts_10m:
            return "wind_speed_of_gust"
        case .shortwave_radiation:
            return "integral_of_surface_downwelling_shortwave_flux_in_air_wrt_time"
        case .precipitation:
            return "precipitation_amount"
        }
    }
}
