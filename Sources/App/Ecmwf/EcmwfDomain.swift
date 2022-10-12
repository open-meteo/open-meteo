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
        return "\(OpenMeteo.dataDictionary)omfile-ecmwf/"
    }
    var omfileArchive: String? {
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
    
    /// All levels available in the API
    static var apiLevels: [Int] {
        return [50, 200, 250, 300, 500, 700, 850, 925, 1000]
    }
}


typealias EcmwfReader = GenericReader<EcmwfDomain, EcmwfVariable>

extension EcmwfReader {
    func prefetchData(variables: [EcmwfHourlyVariable], time: TimerangeDt) throws {
        for variable in variables {
            switch variable {
            case .raw(let ecmwfVariable):
                try prefetchData(variable: ecmwfVariable, time: time)
            case .derived(let ecmwfVariableDerived):
                try prefetchData(derived: ecmwfVariableDerived, time: time)
            }
        }
    }
    
    func prefetchData(derived: EcmwfVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .windspeed_10m:
            try prefetchData(variable: .northward_wind_10m, time: time)
            try prefetchData(variable: .eastward_wind_10m, time: time)
        case .windspeed_1000hPa:
            try prefetchData(variable: .northward_wind_1000hPa, time: time)
            try prefetchData(variable: .eastward_wind_1000hPa, time: time)
        case .windspeed_925hPa:
            try prefetchData(variable: .northward_wind_925hPa, time: time)
            try prefetchData(variable: .eastward_wind_925hPa, time: time)
        case .windspeed_850hPa:
            try prefetchData(variable: .northward_wind_850hPa, time: time)
            try prefetchData(variable: .eastward_wind_850hPa, time: time)
        case .windspeed_700hPa:
            try prefetchData(variable: .northward_wind_700hPa, time: time)
            try prefetchData(variable: .eastward_wind_700hPa, time: time)
        case .windspeed_500hPa:
            try prefetchData(variable: .northward_wind_500hPa, time: time)
            try prefetchData(variable: .eastward_wind_500hPa, time: time)
        case .windspeed_300hPa:
            try prefetchData(variable: .northward_wind_300hPa, time: time)
            try prefetchData(variable: .eastward_wind_300hPa, time: time)
        case .windspeed_250hPa:
            try prefetchData(variable: .northward_wind_250hPa, time: time)
            try prefetchData(variable: .eastward_wind_250hPa, time: time)
        case .windspeed_200hPa:
            try prefetchData(variable: .northward_wind_200hPa, time: time)
            try prefetchData(variable: .eastward_wind_200hPa, time: time)
        case .windspeed_50hPa:
            try prefetchData(variable: .northward_wind_50hPa, time: time)
            try prefetchData(variable: .eastward_wind_50hPa, time: time)
        case .winddirection_10m:
            try prefetchData(variable: .northward_wind_10m, time: time)
            try prefetchData(variable: .eastward_wind_10m, time: time)
        case .winddirection_1000hPa:
            try prefetchData(variable: .northward_wind_1000hPa, time: time)
            try prefetchData(variable: .eastward_wind_1000hPa, time: time)
        case .winddirection_925hPa:
            try prefetchData(variable: .northward_wind_925hPa, time: time)
            try prefetchData(variable: .eastward_wind_925hPa, time: time)
        case .winddirection_850hPa:
            try prefetchData(variable: .northward_wind_850hPa, time: time)
            try prefetchData(variable: .eastward_wind_850hPa, time: time)
        case .winddirection_700hPa:
            try prefetchData(variable: .northward_wind_700hPa, time: time)
            try prefetchData(variable: .eastward_wind_700hPa, time: time)
        case .winddirection_500hPa:
            try prefetchData(variable: .northward_wind_500hPa, time: time)
            try prefetchData(variable: .eastward_wind_500hPa, time: time)
        case .winddirection_300hPa:
            try prefetchData(variable: .northward_wind_300hPa, time: time)
            try prefetchData(variable: .eastward_wind_300hPa, time: time)
        case .winddirection_250hPa:
            try prefetchData(variable: .northward_wind_250hPa, time: time)
            try prefetchData(variable: .eastward_wind_250hPa, time: time)
        case .winddirection_200hPa:
            try prefetchData(variable: .northward_wind_200hPa, time: time)
            try prefetchData(variable: .eastward_wind_200hPa, time: time)
        case .winddirection_50hPa:
            try prefetchData(variable: .northward_wind_50hPa, time: time)
            try prefetchData(variable: .eastward_wind_50hPa, time: time)
        case .soil_temperature_0_7cm:
            try prefetchData(variable: .soil_temperature_0_to_7cm, time: time)
        }
    }
    
    func get(variable: EcmwfHourlyVariable, time: TimerangeDt) throws -> DataAndUnit {
        switch variable {
        case .raw(let ecmwfVariable):
            return try get(variable: ecmwfVariable, time: time)
        case .derived(let ecmwfVariableDerived):
            return try get(derived: ecmwfVariableDerived, time: time)
        }
    }
    
    
    func get(derived: EcmwfVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .windspeed_10m:
            let u = try get(variable: .northward_wind_10m, time: time)
            let v = try get(variable: .eastward_wind_10m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let u = try get(variable: .northward_wind_10m, time: time)
            let v = try get(variable: .eastward_wind_10m, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_1000hPa:
            let u = try get(variable: .northward_wind_1000hPa, time: time)
            let v = try get(variable: .eastward_wind_1000hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_925hPa:
            let u = try get(variable: .northward_wind_925hPa, time: time)
            let v = try get(variable: .eastward_wind_925hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_850hPa:
            let u = try get(variable: .northward_wind_850hPa, time: time)
            let v = try get(variable: .eastward_wind_850hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_700hPa:
            let u = try get(variable: .northward_wind_700hPa, time: time)
            let v = try get(variable: .eastward_wind_700hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_500hPa:
            let u = try get(variable: .northward_wind_500hPa, time: time)
            let v = try get(variable: .eastward_wind_500hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_300hPa:
            let u = try get(variable: .northward_wind_300hPa, time: time)
            let v = try get(variable: .eastward_wind_300hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_250hPa:
            let u = try get(variable: .northward_wind_250hPa, time: time)
            let v = try get(variable: .eastward_wind_250hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_200hPa:
            let u = try get(variable: .northward_wind_200hPa, time: time)
            let v = try get(variable: .eastward_wind_200hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_50hPa:
            let u = try get(variable: .northward_wind_50hPa, time: time)
            let v = try get(variable: .eastward_wind_50hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_1000hPa:
            let u = try get(variable: .northward_wind_1000hPa, time: time)
            let v = try get(variable: .eastward_wind_1000hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_925hPa:
            let u = try get(variable: .northward_wind_925hPa, time: time)
            let v = try get(variable: .eastward_wind_925hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_850hPa:
            let u = try get(variable: .northward_wind_850hPa, time: time)
            let v = try get(variable: .eastward_wind_850hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_700hPa:
            let u = try get(variable: .northward_wind_700hPa, time: time)
            let v = try get(variable: .eastward_wind_700hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_500hPa:
            let u = try get(variable: .northward_wind_500hPa, time: time)
            let v = try get(variable: .eastward_wind_500hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_300hPa:
            let u = try get(variable: .northward_wind_300hPa, time: time)
            let v = try get(variable: .eastward_wind_300hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_250hPa:
            let u = try get(variable: .northward_wind_250hPa, time: time)
            let v = try get(variable: .eastward_wind_250hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_200hPa:
            let u = try get(variable: .northward_wind_200hPa, time: time)
            let v = try get(variable: .eastward_wind_200hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_50hPa:
            let u = try get(variable: .northward_wind_50hPa, time: time)
            let v = try get(variable: .eastward_wind_50hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .soil_temperature_0_7cm:
            return try get(variable: .soil_temperature_0_to_7cm, time: time)
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
