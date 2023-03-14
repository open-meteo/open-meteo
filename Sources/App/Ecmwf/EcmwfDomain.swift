import Foundation
import Vapor
import SwiftPFor2D


enum EcmwfDomain: String, GenericDomain {
    case ifs04
    
    /// There is no elevation file for ECMWF
    var elevationFile: OmFileReader<MmapFile>? {
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


struct EcmwfReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    var reader: GenericReaderCached<EcmwfDomain, EcmwfVariable>
    
    typealias Domain = EcmwfDomain
    
    typealias Variable = EcmwfVariable
    
    typealias Derived = EcmwfVariableDerived
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func get(derived: EcmwfVariableDerived, time: TimerangeDt) throws -> DataAndUnit {
        switch derived {
        case .windspeed_10m:
            let u = try get(raw: .northward_wind_10m, time: time)
            let v = try get(raw: .eastward_wind_10m, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let u = try get(raw: .northward_wind_10m, time: time)
            let v = try get(raw: .eastward_wind_10m, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_1000hPa:
            let u = try get(raw: .northward_wind_1000hPa, time: time)
            let v = try get(raw: .eastward_wind_1000hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_925hPa:
            let u = try get(raw: .northward_wind_925hPa, time: time)
            let v = try get(raw: .eastward_wind_925hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_850hPa:
            let u = try get(raw: .northward_wind_850hPa, time: time)
            let v = try get(raw: .eastward_wind_850hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_700hPa:
            let u = try get(raw: .northward_wind_700hPa, time: time)
            let v = try get(raw: .eastward_wind_700hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_500hPa:
            let u = try get(raw: .northward_wind_500hPa, time: time)
            let v = try get(raw: .eastward_wind_500hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_300hPa:
            let u = try get(raw: .northward_wind_300hPa, time: time)
            let v = try get(raw: .eastward_wind_300hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_250hPa:
            let u = try get(raw: .northward_wind_250hPa, time: time)
            let v = try get(raw: .eastward_wind_250hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_200hPa:
            let u = try get(raw: .northward_wind_200hPa, time: time)
            let v = try get(raw: .eastward_wind_200hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_50hPa:
            let u = try get(raw: .northward_wind_50hPa, time: time)
            let v = try get(raw: .eastward_wind_50hPa, time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_1000hPa:
            let u = try get(raw: .northward_wind_1000hPa, time: time)
            let v = try get(raw: .eastward_wind_1000hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_925hPa:
            let u = try get(raw: .northward_wind_925hPa, time: time)
            let v = try get(raw: .eastward_wind_925hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_850hPa:
            let u = try get(raw: .northward_wind_850hPa, time: time)
            let v = try get(raw: .eastward_wind_850hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_700hPa:
            let u = try get(raw: .northward_wind_700hPa, time: time)
            let v = try get(raw: .eastward_wind_700hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_500hPa:
            let u = try get(raw: .northward_wind_500hPa, time: time)
            let v = try get(raw: .eastward_wind_500hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_300hPa:
            let u = try get(raw: .northward_wind_300hPa, time: time)
            let v = try get(raw: .eastward_wind_300hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_250hPa:
            let u = try get(raw: .northward_wind_250hPa, time: time)
            let v = try get(raw: .eastward_wind_250hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_200hPa:
            let u = try get(raw: .northward_wind_200hPa, time: time)
            let v = try get(raw: .eastward_wind_200hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_50hPa:
            let u = try get(raw: .northward_wind_50hPa, time: time)
            let v = try get(raw: .eastward_wind_50hPa, time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .soil_temperature_0_7cm:
            return try get(raw: .soil_temperature_0_to_7cm, time: time)
        case .weathercode:
            let cloudcover = try get(derived: .cloudcover, time: time).data
            let precipitation = try get(raw: .precipitation, time: time).data
            let snowfall = try get(derived: .snowfall, time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: nil,
                liftedIndex: nil,
                visibilityMeters: nil,
                modelDtHours: time.dtSeconds / 3600), .wmoCode
            )
        case .cloudcover:
            let low = try get(derived: .cloudcover_low, time: time).data
            let mid = try get(derived: .cloudcover_mid, time: time).data
            let high = try get(derived: .cloudcover_high, time: time).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percent)
        case .cloudcover_low:
            let cl0 = try get(derived: .cloudcover_1000hPa, time: time)
            let cl1 = try get(derived: .cloudcover_925hPa, time: time)
            let cl2 = try get(derived: .cloudcover_850hPa, time: time)
            return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
        case .cloudcover_mid:
            let cl0 = try get(derived: .cloudcover_700hPa, time: time)
            let cl1 = try get(derived: .cloudcover_500hPa, time: time)
            return DataAndUnit(zip(cl0.data, cl1.data).map(max), .percent)
        case .cloudcover_high:
            let cl0 = try get(derived: .cloudcover_300hPa, time: time)
            let cl1 = try get(derived: .cloudcover_250hPa, time: time)
            let cl2 = try get(derived: .cloudcover_200hPa, time: time)
            return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
        case .cloudcover_1000hPa:
            let rh = try get(raw: .relative_humidity_1000hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 1000)}), .percent)
        case .cloudcover_925hPa:
            let rh = try get(raw: .relative_humidity_925hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 925)}), .percent)
        case .cloudcover_850hPa:
            let rh = try get(raw: .relative_humidity_850hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 850)}), .percent)
        case .cloudcover_700hPa:
            let rh = try get(raw: .relative_humidity_700hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 700)}), .percent)
        case .cloudcover_500hPa:
            let rh = try get(raw: .relative_humidity_500hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 500)}), .percent)
        case .cloudcover_300hPa:
            let rh = try get(raw: .relative_humidity_300hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 300)}), .percent)
        case .cloudcover_250hPa:
            let rh = try get(raw: .relative_humidity_250hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 250)}), .percent)
        case .cloudcover_200hPa:
            let rh = try get(raw: .relative_humidity_200hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 200)}), .percent)
        case .cloudcover_50hPa:
            let rh = try get(raw: .relative_humidity_50hPa, time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 50)}), .percent)
        case .snowfall:
            let temperature = try get(raw: .temperature_2m, time: time)
            let precipitation = try get(raw: .precipitation, time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimeter)
        }
    }
    
    func prefetchData(derived: EcmwfVariableDerived, time: TimerangeDt) throws {
        switch derived {
        case .windspeed_10m:
            try prefetchData(raw: .northward_wind_10m, time: time)
            try prefetchData(raw: .eastward_wind_10m, time: time)
        case .windspeed_1000hPa:
            try prefetchData(raw: .northward_wind_1000hPa, time: time)
            try prefetchData(raw: .eastward_wind_1000hPa, time: time)
        case .windspeed_925hPa:
            try prefetchData(raw: .northward_wind_925hPa, time: time)
            try prefetchData(raw: .eastward_wind_925hPa, time: time)
        case .windspeed_850hPa:
            try prefetchData(raw: .northward_wind_850hPa, time: time)
            try prefetchData(raw: .eastward_wind_850hPa, time: time)
        case .windspeed_700hPa:
            try prefetchData(raw: .northward_wind_700hPa, time: time)
            try prefetchData(raw: .eastward_wind_700hPa, time: time)
        case .windspeed_500hPa:
            try prefetchData(raw: .northward_wind_500hPa, time: time)
            try prefetchData(raw: .eastward_wind_500hPa, time: time)
        case .windspeed_300hPa:
            try prefetchData(raw: .northward_wind_300hPa, time: time)
            try prefetchData(raw: .eastward_wind_300hPa, time: time)
        case .windspeed_250hPa:
            try prefetchData(raw: .northward_wind_250hPa, time: time)
            try prefetchData(raw: .eastward_wind_250hPa, time: time)
        case .windspeed_200hPa:
            try prefetchData(raw: .northward_wind_200hPa, time: time)
            try prefetchData(raw: .eastward_wind_200hPa, time: time)
        case .windspeed_50hPa:
            try prefetchData(raw: .northward_wind_50hPa, time: time)
            try prefetchData(raw: .eastward_wind_50hPa, time: time)
        case .winddirection_10m:
            try prefetchData(raw: .northward_wind_10m, time: time)
            try prefetchData(raw: .eastward_wind_10m, time: time)
        case .winddirection_1000hPa:
            try prefetchData(raw: .northward_wind_1000hPa, time: time)
            try prefetchData(raw: .eastward_wind_1000hPa, time: time)
        case .winddirection_925hPa:
            try prefetchData(raw: .northward_wind_925hPa, time: time)
            try prefetchData(raw: .eastward_wind_925hPa, time: time)
        case .winddirection_850hPa:
            try prefetchData(raw: .northward_wind_850hPa, time: time)
            try prefetchData(raw: .eastward_wind_850hPa, time: time)
        case .winddirection_700hPa:
            try prefetchData(raw: .northward_wind_700hPa, time: time)
            try prefetchData(raw: .eastward_wind_700hPa, time: time)
        case .winddirection_500hPa:
            try prefetchData(raw: .northward_wind_500hPa, time: time)
            try prefetchData(raw: .eastward_wind_500hPa, time: time)
        case .winddirection_300hPa:
            try prefetchData(raw: .northward_wind_300hPa, time: time)
            try prefetchData(raw: .eastward_wind_300hPa, time: time)
        case .winddirection_250hPa:
            try prefetchData(raw: .northward_wind_250hPa, time: time)
            try prefetchData(raw: .eastward_wind_250hPa, time: time)
        case .winddirection_200hPa:
            try prefetchData(raw: .northward_wind_200hPa, time: time)
            try prefetchData(raw: .eastward_wind_200hPa, time: time)
        case .winddirection_50hPa:
            try prefetchData(raw: .northward_wind_50hPa, time: time)
            try prefetchData(raw: .eastward_wind_50hPa, time: time)
        case .soil_temperature_0_7cm:
            try prefetchData(raw: .soil_temperature_0_to_7cm, time: time)
        case .cloudcover_1000hPa:
            try prefetchData(raw: .relative_humidity_1000hPa, time: time)
        case .cloudcover_925hPa:
            try prefetchData(raw: .relative_humidity_925hPa, time: time)
        case .cloudcover_850hPa:
            try prefetchData(raw: .relative_humidity_850hPa, time: time)
        case .cloudcover_700hPa:
            try prefetchData(raw: .relative_humidity_700hPa, time: time)
        case .cloudcover_500hPa:
            try prefetchData(raw: .relative_humidity_500hPa, time: time)
        case .cloudcover_300hPa:
            try prefetchData(raw: .relative_humidity_300hPa, time: time)
        case .cloudcover_250hPa:
            try prefetchData(raw: .relative_humidity_250hPa, time: time)
        case .cloudcover_200hPa:
            try prefetchData(raw: .relative_humidity_200hPa, time: time)
        case .cloudcover_50hPa:
            try prefetchData(raw: .relative_humidity_50hPa, time: time)
        case .weathercode:
            try prefetchData(derived: .cloudcover, time: time)
            try prefetchData(derived: .snowfall, time: time)
            try prefetchData(raw: .precipitation, time: time)
        case .cloudcover:
            try prefetchData(derived: .cloudcover_low, time: time)
            try prefetchData(derived: .cloudcover_mid, time: time)
            try prefetchData(derived: .cloudcover_high, time: time)
        case .cloudcover_low:
            try prefetchData(derived: .cloudcover_1000hPa, time: time)
            try prefetchData(derived: .cloudcover_925hPa, time: time)
            try prefetchData(derived: .cloudcover_850hPa, time: time)
        case .cloudcover_mid:
            try prefetchData(derived: .cloudcover_700hPa, time: time)
            try prefetchData(derived: .cloudcover_500hPa, time: time)
        case .cloudcover_high:
            try prefetchData(derived: .cloudcover_300hPa, time: time)
            try prefetchData(derived: .cloudcover_250hPa, time: time)
            try prefetchData(derived: .cloudcover_200hPa, time: time)
        case .snowfall:
            try prefetchData(raw: .temperature_2m, time: time)
            try prefetchData(raw: .precipitation, time: time)
        }
    }
}
