import Foundation
import Vapor
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
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    
    /// There is no elevation file for ECMWF
    func getStaticFile(type: ReaderStaticVariable) -> OmFileReader<MmapFile>? {
        return nil
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
    
    var ensembleMembers: Int? {
        switch self {
        case .ifs04:
            return 1
        case .ifs04_ensemble:
            return 50+1
        }
    }
}


struct EcmwfReader: GenericReaderDerivedSimple, GenericReaderProtocol {
    var reader: GenericReaderCached<EcmwfDomain, Variable>
    
    typealias Domain = EcmwfDomain
    
    typealias Variable = VariableAndMemberAndControl<EcmwfVariable>
    
    typealias Derived = VariableAndMemberAndControl<EcmwfVariableDerived>
    
    public init?(domain: Domain, lat: Float, lon: Float, elevation: Float, mode: GridSelectionMode) throws {
        guard let reader = try GenericReader<Domain, Variable>(domain: domain, lat: lat, lon: lon, elevation: elevation, mode: mode) else {
            return nil
        }
        self.reader = GenericReaderCached(reader: reader)
    }
    
    func get(derived: Derived, time: TimerangeDt) throws -> DataAndUnit {
        let member = derived.member
        switch derived.variable {
        case .windspeed_10m:
            let v = try get(raw: .init(.northward_wind_10m, member), time: time)
            let u = try get(raw: .init(.eastward_wind_10m, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_10m:
            let v = try get(raw: .init(.northward_wind_10m, member), time: time)
            let u = try get(raw: .init(.eastward_wind_10m, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .windspeed_1000hPa:
            let v = try get(raw: .init(.northward_wind_1000hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_1000hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_925hPa:
            let v = try get(raw: .init(.northward_wind_925hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_925hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_850hPa:
            let v = try get(raw: .init(.northward_wind_850hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_850hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_700hPa:
            let v = try get(raw: .init(.northward_wind_700hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_700hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_500hPa:
            let v = try get(raw: .init(.northward_wind_500hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_500hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_300hPa:
            let v = try get(raw: .init(.northward_wind_300hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_300hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_250hPa:
            let v = try get(raw: .init(.northward_wind_250hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_250hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_200hPa:
            let v = try get(raw: .init(.northward_wind_200hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_200hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .windspeed_50hPa:
            let v = try get(raw: .init(.northward_wind_50hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_50hPa, member), time: time)
            let speed = zip(u.data,v.data).map(Meteorology.windspeed)
            return DataAndUnit(speed, .ms)
        case .winddirection_1000hPa:
            let v = try get(raw: .init(.northward_wind_1000hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_1000hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_925hPa:
            let v = try get(raw: .init(.northward_wind_925hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_925hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_850hPa:
            let v = try get(raw: .init(.northward_wind_850hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_850hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_700hPa:
            let v = try get(raw: .init(.northward_wind_700hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_700hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_500hPa:
            let v = try get(raw: .init(.northward_wind_500hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_500hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_300hPa:
            let v = try get(raw: .init(.northward_wind_300hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_300hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_250hPa:
            let v = try get(raw: .init(.northward_wind_250hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_250hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_200hPa:
            let v = try get(raw: .init(.northward_wind_200hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_200hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .winddirection_50hPa:
            let v = try get(raw: .init(.northward_wind_50hPa, member), time: time)
            let u = try get(raw: .init(.eastward_wind_50hPa, member), time: time)
            let direction = Meteorology.windirectionFast(u: u.data, v: v.data)
            return DataAndUnit(direction, .degreeDirection)
        case .soil_temperature_0_10cm:
            fallthrough
        case .soil_temperature_0_7cm:
            return try get(raw: .init(.soil_temperature_0_to_7cm, member), time: time)
        case .weathercode:
            let cloudcover = try get(derived: .init(.cloudcover, member), time: time).data
            let precipitation = try get(raw: .init(.precipitation, member), time: time).data
            let snowfall = try get(derived: .init(.snowfall, member), time: time).data
            return DataAndUnit(WeatherCode.calculate(
                cloudcover: cloudcover,
                precipitation: precipitation,
                convectivePrecipitation: nil,
                snowfallCentimeters: snowfall,
                gusts: nil,
                cape: nil,
                liftedIndex: nil,
                visibilityMeters: nil,
                categoricalFreezingRain: nil,
                modelDtHours: time.dtSeconds / 3600), .wmoCode
            )
        case .cloudcover:
            let low = try get(derived: .init(.cloudcover_low, member), time: time).data
            let mid = try get(derived: .init(.cloudcover_mid, member), time: time).data
            let high = try get(derived: .init(.cloudcover_high, member), time: time).data
            return DataAndUnit(Meteorology.cloudCoverTotal(low: low, mid: mid, high: high), .percent)
        case .cloudcover_low:
            let cl0 = try get(derived: .init(.cloudcover_1000hPa, member), time: time)
            let cl1 = try get(derived: .init(.cloudcover_925hPa, member), time: time)
            let cl2 = try get(derived: .init(.cloudcover_850hPa, member), time: time)
            return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
        case .cloudcover_mid:
            let cl0 = try get(derived: .init(.cloudcover_700hPa, member), time: time)
            let cl1 = try get(derived: .init(.cloudcover_500hPa, member), time: time)
            return DataAndUnit(zip(cl0.data, cl1.data).map(max), .percent)
        case .cloudcover_high:
            let cl0 = try get(derived: .init(.cloudcover_300hPa, member), time: time)
            let cl1 = try get(derived: .init(.cloudcover_250hPa, member), time: time)
            let cl2 = try get(derived: .init(.cloudcover_200hPa, member), time: time)
            return DataAndUnit(zip(zip(cl0.data, cl1.data).map(max), cl2.data).map(max), .percent)
        case .cloudcover_1000hPa:
            let rh = try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 1000)}), .percent)
        case .cloudcover_925hPa:
            let rh = try get(raw: .init(.relative_humidity_925hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 925)}), .percent)
        case .cloudcover_850hPa:
            let rh = try get(raw: .init(.relative_humidity_850hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 850)}), .percent)
        case .cloudcover_700hPa:
            let rh = try get(raw: .init(.relative_humidity_700hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 700)}), .percent)
        case .cloudcover_500hPa:
            let rh = try get(raw: .init(.relative_humidity_500hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 500)}), .percent)
        case .cloudcover_300hPa:
            let rh = try get(raw: .init(.relative_humidity_300hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 300)}), .percent)
        case .cloudcover_250hPa:
            let rh = try get(raw: .init(.relative_humidity_250hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 250)}), .percent)
        case .cloudcover_200hPa:
            let rh = try get(raw: .init(.relative_humidity_200hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 200)}), .percent)
        case .cloudcover_50hPa:
            let rh = try get(raw: .init(.relative_humidity_50hPa, member), time: time)
            return DataAndUnit(rh.data.map({Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: 50)}), .percent)
        case .snowfall:
            let temperature = try get(raw: .init(.temperature_2m, member), time: time)
            let precipitation = try get(raw: .init(.precipitation, member), time: time)
            return DataAndUnit(zip(temperature.data, precipitation.data).map({ $1 * ($0 >= 0 ? 0 : 0.7) }), .centimeter)
        case .is_day:
            return DataAndUnit(Zensun.calculateIsDay(timeRange: time, lat: reader.modelLat, lon: reader.modelLon), .dimensionless_integer)
        case .relativehumidity_1000hPa:
            return try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .relativehumidity_925hPa:
            return try get(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .relativehumidity_850hPa:
            return try get(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .relativehumidity_700hPa:
            return try get(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .relativehumidity_500hPa:
            return try get(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .relativehumidity_300hPa:
            return try get(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .relativehumidity_250hPa:
            return try get(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .relativehumidity_200hPa:
            return try get(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .relativehumidity_50hPa:
            return try get(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .dewpoint_1000hPa:
            let temperature = try get(raw: .init(.temperature_1000hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_1000hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_925hPa:
            let temperature = try get(raw: .init(.temperature_925hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_925hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_850hPa:
            let temperature = try get(raw: .init(.temperature_850hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_850hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_700hPa:
            let temperature = try get(raw: .init(.temperature_700hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_700hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_500hPa:
            let temperature = try get(raw: .init(.temperature_500hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_500hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_300hPa:
            let temperature = try get(raw: .init(.temperature_300hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_300hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_250hPa:
            let temperature = try get(raw: .init(.temperature_250hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_250hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_200hPa:
            let temperature = try get(raw: .init(.temperature_200hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_200hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .dewpoint_50hPa:
            let temperature = try get(raw: .init(.temperature_50hPa, member), time: time)
            let rh = try get(raw: .init(.relative_humidity_50hPa, member), time: time)
            return DataAndUnit(zip(temperature.data, rh.data).map(Meteorology.dewpoint), temperature.unit)
        case .soil_temperature_0cm:
            fallthrough
        case .surface_temperature:
            return try get(raw: .init(.skin_temperature, member), time: time)
        case .surface_pressure:
            return try get(raw: .init(.surface_air_pressure, member), time: time)
        }
    }
    
    func prefetchData(derived: Derived, time: TimerangeDt) throws {
        let member = derived.member
        switch derived.variable {
        case .windspeed_10m:
            try prefetchData(raw: .init(.northward_wind_10m, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_10m, member), time: time)
        case .windspeed_1000hPa:
            try prefetchData(raw: .init(.northward_wind_1000hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_1000hPa, member), time: time)
        case .windspeed_925hPa:
            try prefetchData(raw: .init(.northward_wind_925hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_925hPa, member), time: time)
        case .windspeed_850hPa:
            try prefetchData(raw: .init(.northward_wind_850hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_850hPa, member), time: time)
        case .windspeed_700hPa:
            try prefetchData(raw: .init(.northward_wind_700hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_700hPa, member), time: time)
        case .windspeed_500hPa:
            try prefetchData(raw: .init(.northward_wind_500hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_500hPa, member), time: time)
        case .windspeed_300hPa:
            try prefetchData(raw: .init(.northward_wind_300hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_300hPa, member), time: time)
        case .windspeed_250hPa:
            try prefetchData(raw: .init(.northward_wind_250hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_250hPa, member), time: time)
        case .windspeed_200hPa:
            try prefetchData(raw: .init(.northward_wind_200hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_200hPa, member), time: time)
        case .windspeed_50hPa:
            try prefetchData(raw: .init(.northward_wind_50hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_50hPa, member), time: time)
        case .winddirection_10m:
            try prefetchData(raw: .init(.northward_wind_10m, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_10m, member), time: time)
        case .winddirection_1000hPa:
            try prefetchData(raw: .init(.northward_wind_1000hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_1000hPa, member), time: time)
        case .winddirection_925hPa:
            try prefetchData(raw: .init(.northward_wind_925hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_925hPa, member), time: time)
        case .winddirection_850hPa:
            try prefetchData(raw: .init(.northward_wind_850hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_850hPa, member), time: time)
        case .winddirection_700hPa:
            try prefetchData(raw: .init(.northward_wind_700hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_700hPa, member), time: time)
        case .winddirection_500hPa:
            try prefetchData(raw: .init(.northward_wind_500hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_500hPa, member), time: time)
        case .winddirection_300hPa:
            try prefetchData(raw: .init(.northward_wind_300hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_300hPa, member), time: time)
        case .winddirection_250hPa:
            try prefetchData(raw: .init(.northward_wind_250hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_250hPa, member), time: time)
        case .winddirection_200hPa:
            try prefetchData(raw: .init(.northward_wind_200hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_200hPa, member), time: time)
        case .winddirection_50hPa:
            try prefetchData(raw: .init(.northward_wind_50hPa, member), time: time)
            try prefetchData(raw: .init(.eastward_wind_50hPa, member), time: time)
        case .soil_temperature_0_10cm:
            fallthrough
        case .soil_temperature_0_7cm:
            try prefetchData(raw: .init(.soil_temperature_0_to_7cm, member), time: time)
        case .cloudcover_1000hPa:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .cloudcover_925hPa:
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .cloudcover_850hPa:
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .cloudcover_700hPa:
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .cloudcover_500hPa:
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .cloudcover_300hPa:
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .cloudcover_250hPa:
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .cloudcover_200hPa:
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .cloudcover_50hPa:
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .weathercode:
            try prefetchData(derived: .init(.cloudcover, member), time: time)
            try prefetchData(derived: .init(.snowfall, member), time: time)
            try prefetchData(raw: .init(.precipitation, member), time: time)
        case .cloudcover:
            try prefetchData(derived: .init(.cloudcover_low, member), time: time)
            try prefetchData(derived: .init(.cloudcover_mid, member), time: time)
            try prefetchData(derived: .init(.cloudcover_high, member), time: time)
        case .cloudcover_low:
            try prefetchData(derived: .init(.cloudcover_1000hPa, member), time: time)
            try prefetchData(derived: .init(.cloudcover_925hPa, member), time: time)
            try prefetchData(derived: .init(.cloudcover_850hPa, member), time: time)
        case .cloudcover_mid:
            try prefetchData(derived: .init(.cloudcover_700hPa, member), time: time)
            try prefetchData(derived: .init(.cloudcover_500hPa, member), time: time)
        case .cloudcover_high:
            try prefetchData(derived: .init(.cloudcover_300hPa, member), time: time)
            try prefetchData(derived: .init(.cloudcover_250hPa, member), time: time)
            try prefetchData(derived: .init(.cloudcover_200hPa, member), time: time)
        case .snowfall:
            try prefetchData(raw: .init(.temperature_2m, member), time: time)
            try prefetchData(raw: .init(.precipitation, member), time: time)
        case .is_day:
            break
        case .relativehumidity_1000hPa:
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .relativehumidity_925hPa:
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .relativehumidity_850hPa:
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .relativehumidity_700hPa:
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .relativehumidity_500hPa:
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .relativehumidity_300hPa:
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .relativehumidity_250hPa:
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .relativehumidity_200hPa:
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .relativehumidity_50hPa:
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .dewpoint_1000hPa:
            try prefetchData(raw: .init(.temperature_1000hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_1000hPa, member), time: time)
        case .dewpoint_925hPa:
            try prefetchData(raw: .init(.temperature_925hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_925hPa, member), time: time)
        case .dewpoint_850hPa:
            try prefetchData(raw: .init(.temperature_850hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_850hPa, member), time: time)
        case .dewpoint_700hPa:
            try prefetchData(raw: .init(.temperature_700hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_700hPa, member), time: time)
        case .dewpoint_500hPa:
            try prefetchData(raw: .init(.temperature_500hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_500hPa, member), time: time)
        case .dewpoint_300hPa:
            try prefetchData(raw: .init(.temperature_300hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_300hPa, member), time: time)
        case .dewpoint_250hPa:
            try prefetchData(raw: .init(.temperature_250hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_250hPa, member), time: time)
        case .dewpoint_200hPa:
            try prefetchData(raw: .init(.temperature_200hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_200hPa, member), time: time)
        case .dewpoint_50hPa:
            try prefetchData(raw: .init(.temperature_50hPa, member), time: time)
            try prefetchData(raw: .init(.relative_humidity_50hPa, member), time: time)
        case .surface_temperature:
            fallthrough
        case .soil_temperature_0cm:
            try prefetchData(raw: .init(.skin_temperature, member), time: time)
        case .surface_pressure:
            try prefetchData(raw: .init(.surface_air_pressure, member), time: time)
        }
    }
}
