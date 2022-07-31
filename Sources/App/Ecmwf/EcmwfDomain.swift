import Foundation
import Vapor
import SwiftPFor2D


enum EcmwfDomain: GenericDomain {
    case ifs04
    
    /// There is no elevation file for ECMWF
    var elevationFile: OmFileReader? {
        return nil
    }
    
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
        return "./data/omfile-ecmwf/"
    }
    
    var omFileLength: Int {
        // 104
        return (240 + 3*24) / dtHours
    }
    
    var dtSeconds: Int {
        return 3*3600
    }
    
    var grid: RegularGrid {
        return RegularGrid(nx: 900, ny: 451, latMin: -90, lonMin: -180, dx: 360/900, dy: 180/450)
    }
}


enum EcmwfVariableDerived: String, Codable {
    case windspeed_10m
    case windspeed_1000hPa
    case windspeed_925hPa
    case windspeed_850hPa
    case windspeed_700hPa
    case windspeed_500hPa
    case windspeed_300hPa
    case windspeed_250hPa
    case windspeed_200hPa
    case windspeed_50hPa
    case winddirection_10m
    case winddirection_1000hPa
    case winddirection_925hPa
    case winddirection_850hPa
    case winddirection_700hPa
    case winddirection_500hPa
    case winddirection_300hPa
    case winddirection_250hPa
    case winddirection_200hPa
    case winddirection_50hPa
}


typealias EcmwfReader = GenericReader<EcmwfDomain, EcmwfVariable>

extension EcmwfReader {
    func prefetchData(variables: [EcmwfHourlyVariable]) throws {
        for variable in variables {
            switch variable {
            case .raw(let ecmwfVariable):
                try prefetchData(variable: ecmwfVariable)
            case .derived(let ecmwfVariableDerived):
                try prefetchData(derived: ecmwfVariableDerived)
            }
        }
    }
    
    func prefetchData(derived: EcmwfVariableDerived) throws {
        switch derived {
        case .windspeed_10m:
            try prefetchData(variable: .northward_wind_10m)
            try prefetchData(variable: .eastward_wind_10m)
        case .windspeed_1000hPa:
            try prefetchData(variable: .northward_wind_1000hPa)
            try prefetchData(variable: .eastward_wind_1000hPa)
        case .windspeed_925hPa:
            try prefetchData(variable: .northward_wind_925hPa)
            try prefetchData(variable: .eastward_wind_925hPa)
        case .windspeed_850hPa:
            try prefetchData(variable: .northward_wind_850hPa)
            try prefetchData(variable: .eastward_wind_850hPa)
        case .windspeed_700hPa:
            try prefetchData(variable: .northward_wind_700hPa)
            try prefetchData(variable: .eastward_wind_700hPa)
        case .windspeed_500hPa:
            try prefetchData(variable: .northward_wind_500hPa)
            try prefetchData(variable: .eastward_wind_500hPa)
        case .windspeed_300hPa:
            try prefetchData(variable: .northward_wind_300hPa)
            try prefetchData(variable: .eastward_wind_300hPa)
        case .windspeed_250hPa:
            try prefetchData(variable: .northward_wind_250hPa)
            try prefetchData(variable: .eastward_wind_250hPa)
        case .windspeed_200hPa:
            try prefetchData(variable: .northward_wind_200hPa)
            try prefetchData(variable: .eastward_wind_200hPa)
        case .windspeed_50hPa:
            try prefetchData(variable: .northward_wind_50hPa)
            try prefetchData(variable: .eastward_wind_50hPa)
        case .winddirection_10m:
            try prefetchData(variable: .northward_wind_10m)
            try prefetchData(variable: .eastward_wind_10m)
        case .winddirection_1000hPa:
            try prefetchData(variable: .northward_wind_1000hPa)
            try prefetchData(variable: .eastward_wind_1000hPa)
        case .winddirection_925hPa:
            try prefetchData(variable: .northward_wind_925hPa)
            try prefetchData(variable: .eastward_wind_925hPa)
        case .winddirection_850hPa:
            try prefetchData(variable: .northward_wind_850hPa)
            try prefetchData(variable: .eastward_wind_850hPa)
        case .winddirection_700hPa:
            try prefetchData(variable: .northward_wind_700hPa)
            try prefetchData(variable: .eastward_wind_700hPa)
        case .winddirection_500hPa:
            try prefetchData(variable: .northward_wind_500hPa)
            try prefetchData(variable: .eastward_wind_500hPa)
        case .winddirection_300hPa:
            try prefetchData(variable: .northward_wind_300hPa)
            try prefetchData(variable: .eastward_wind_300hPa)
        case .winddirection_250hPa:
            try prefetchData(variable: .northward_wind_250hPa)
            try prefetchData(variable: .eastward_wind_250hPa)
        case .winddirection_200hPa:
            try prefetchData(variable: .northward_wind_200hPa)
            try prefetchData(variable: .eastward_wind_200hPa)
        case .winddirection_50hPa:
            try prefetchData(variable: .northward_wind_50hPa)
            try prefetchData(variable: .eastward_wind_50hPa)
        }
    }
    
    func get(variable: EcmwfHourlyVariable) throws -> DataAndUnit {
        switch variable {
        case .raw(let ecmwfVariable):
            return try get(variable: ecmwfVariable)
        case .derived(let ecmwfVariableDerived):
            return try get(derived: ecmwfVariableDerived)
        }
    }
    
    
    func get(derived: EcmwfVariableDerived) throws -> DataAndUnit {
        switch derived {
        case .windspeed_10m:
            let u = try get(variable: .northward_wind_10m)
            let v = try get(variable: .eastward_wind_10m)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let u = try get(variable: .northward_wind_10m)
            let v = try get(variable: .eastward_wind_10m)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_1000hPa:
            let u = try get(variable: .northward_wind_1000hPa)
            let v = try get(variable: .eastward_wind_1000hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_925hPa:
            let u = try get(variable: .northward_wind_925hPa)
            let v = try get(variable: .eastward_wind_925hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_850hPa:
            let u = try get(variable: .northward_wind_850hPa)
            let v = try get(variable: .eastward_wind_850hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_700hPa:
            let u = try get(variable: .northward_wind_700hPa)
            let v = try get(variable: .eastward_wind_700hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_500hPa:
            let u = try get(variable: .northward_wind_500hPa)
            let v = try get(variable: .eastward_wind_500hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_300hPa:
            let u = try get(variable: .northward_wind_300hPa)
            let v = try get(variable: .eastward_wind_300hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_250hPa:
            let u = try get(variable: .northward_wind_250hPa)
            let v = try get(variable: .eastward_wind_250hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_200hPa:
            let u = try get(variable: .northward_wind_200hPa)
            let v = try get(variable: .eastward_wind_200hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_50hPa:
            let u = try get(variable: .northward_wind_50hPa)
            let v = try get(variable: .eastward_wind_50hPa)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_1000hPa:
            let u = try get(variable: .northward_wind_1000hPa)
            let v = try get(variable: .eastward_wind_1000hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_925hPa:
            let u = try get(variable: .northward_wind_925hPa)
            let v = try get(variable: .eastward_wind_925hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_850hPa:
            let u = try get(variable: .northward_wind_850hPa)
            let v = try get(variable: .eastward_wind_850hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_700hPa:
            let u = try get(variable: .northward_wind_700hPa)
            let v = try get(variable: .eastward_wind_700hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_500hPa:
            let u = try get(variable: .northward_wind_500hPa)
            let v = try get(variable: .eastward_wind_500hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_300hPa:
            let u = try get(variable: .northward_wind_300hPa)
            let v = try get(variable: .eastward_wind_300hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_250hPa:
            let u = try get(variable: .northward_wind_250hPa)
            let v = try get(variable: .eastward_wind_250hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_200hPa:
            let u = try get(variable: .northward_wind_200hPa)
            let v = try get(variable: .eastward_wind_200hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_50hPa:
            let u = try get(variable: .northward_wind_50hPa)
            let v = try get(variable: .eastward_wind_50hPa)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        }
    }
}


/*final class InitTxtReader {
    private let lock = Lock()
    private var time = InitTime(initTime: Timestamp(0), length: 0, range: Timestamp(0)..<Timestamp(0))
    private var update: TimeInterval = 0
    let file: String
    
    struct InitTime {
        let initTime: Timestamp
        let length: Int
        let range: Range<Timestamp>
    }
    
    public init(_ file: String) {
        self.file = file
    }
    
    func get() -> InitTime {
        lock.withLock {
            let now = Date().timeIntervalSince1970
            if update + 10 >= now {
                return time
            }
            let timeString = try! String(contentsOfFile: file, encoding: .utf8).replacingOccurrences(of: "\n", with: "")
            let parts = timeString.split(separator: ",")
            
            time = InitTime(
                initTime: Timestamp(Int(parts[0])!),
                length: Int(parts[1])!,
                range: Timestamp(Int(parts[2])!) ..< Timestamp(Int(parts[3])!))
            update = now
            return time
        }
    }
}*/
