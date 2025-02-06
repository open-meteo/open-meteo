import Foundation

@testable import App
import XCTest
import Vapor
import SwiftEccodes

final class OutputformatTests: XCTestCase {
    var app: Application?
    
    override func setUp() async throws {
        app = try Application.testable()
    }
    
    override func tearDown() async throws {
        try await app?.asyncShutdown()
        app = nil
    }
    
    /*func testBz2Grib() async throws {
        let url = "http://opendata.dwd.de/weather/nwp/icon-d2/grib/06/relhum/icon-d2_germany_regular-lat-lon_pressure-level_2022101306_004_500_relhum.grib2.bz2"
        let curl = Curl(logger: app!.logger)
        let grib = try await curl.downloadBz2Grib(url: url, client: app!.http.client.shared)
        
        try grib.forEach({message in
            message.iterate(namespace: .ls).forEach({
                print($0)
            })
            message.iterate(namespace: .geography).forEach({
                print($0)
            })
            print(message.get(attribute: "name")!)
            let data = try message.getDouble()
            print(data.count)
            print(data[0..<10])
        })
    }*/
    
    /// Test adjustment of API call weights
    /// "Heavy" API calls are counted more than just 1 API call
    ///
    /// See: https://github.com/open-meteo/open-meteo/issues/438#issuecomment-1722945326
    func testApiWeight() {
        let dataContainer = ForecastapiResult<MultiDomains>.PerModel(
            model: .best_match,
            latitude: 41,
            longitude: 2,
            elevation: nil,
            //timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"),
            //time: TimerangeLocal(range: Timestamp(2000, 1, 1)..<Timestamp(2021, 1, 1), utcOffsetSeconds: 0),
            prefetch: {},
            //current_weather: nil,
            current: nil,
            hourly: nil,
            daily: nil,
            sixHourly: nil,
            minutely15: nil
        )
        let location20year = ForecastapiResult<MultiDomains>.PerLocation(timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"), time: TimerangeLocal(range: Timestamp(2000, 1, 1)..<Timestamp(2021, 1, 1), utcOffsetSeconds: 3600), locationId: 0, results: [dataContainer])
        let result20year = ForecastapiResult<MultiDomains>(timeformat: .iso8601, results: [location20year])
        // 20 year data, one location, one variable
        XCTAssertEqual(result20year.calculateQueryWeight(nVariablesModels: 1), 54.79286)
        // 20 year data, one location, two variables
        XCTAssertEqual(result20year.calculateQueryWeight(nVariablesModels: 2), 109.58572)
        
        let location7day = ForecastapiResult<MultiDomains>.PerLocation(timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"), time: TimerangeLocal(range: Timestamp(2000, 1, 1)..<Timestamp(2000, 1, 8), utcOffsetSeconds: 3600), locationId: 0, results: [dataContainer])
        
        let result7day = ForecastapiResult<MultiDomains>(timeformat: .iso8601, results: [location7day])
        // 7 day data, one location, one variable
        XCTAssertEqual(result7day.calculateQueryWeight(nVariablesModels: 1), 1)
        // 7 day data, one location, two variables
        XCTAssertEqual(result7day.calculateQueryWeight(nVariablesModels: 2), 1)
        // 7 day data, one location, 15 variables
        XCTAssertEqual(result7day.calculateQueryWeight(nVariablesModels: 15), 1.5)
        // 7 day data, one location, 30 variables
        XCTAssertEqual(result7day.calculateQueryWeight(nVariablesModels: 30), 3)
        
        let location1month = ForecastapiResult<MultiDomains>.PerLocation(timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"), time: TimerangeLocal(range: Timestamp(2000, 1, 1)..<Timestamp(2000, 2, 1), utcOffsetSeconds: 3600), locationId: 0, results: [dataContainer])
        
        let result1month = ForecastapiResult<MultiDomains>(timeformat: .iso8601, results: [location1month, location1month])
        // 1 month data, two locations, one variable
        XCTAssertEqual(result1month.calculateQueryWeight(nVariablesModels: 1), 2.0)
        // 1 month data, two locations, two variables
        XCTAssertEqual(result1month.calculateQueryWeight(nVariablesModels: 2), 2.0)
        // 1 month data, two locations, 15 variables
        XCTAssertEqual(result1month.calculateQueryWeight(nVariablesModels: 15), 6.6428566)
        // 1 month data, two locations, 30 variables
        XCTAssertEqual(result1month.calculateQueryWeight(nVariablesModels: 30), 13.285713)
    }
    
    
    func drainString(_ response: Response) -> String {
        guard var buffer = try? response.body.collect(on: self.app!.eventLoopGroup.next()).wait() else {
            fatalError("could not get buffer")
        }
        guard let string = buffer.readString(length: buffer.writerIndex) else {
            fatalError("could not convert to string")
        }
        return string
    }
    
    func drainData(_ response: Response) -> Data {
        guard var buffer = try? response.body.collect(on: self.app!.eventLoopGroup.next()).wait() else {
            fatalError("could not get byffer")
        }
        guard let data = buffer.readData(length: buffer.writerIndex) else {
            fatalError("could not convert to data")
        }
        return data
    }
    
    func testFormats() async throws {
        /*let current = ForecastapiResult.CurrentWeather(
            temperature: 23,
            windspeed: 12,
            winddirection: 90,
            weathercode: 5,
            is_day: 1,
            temperature_unit: .celsius,
            windspeed_unit: .kmh,
            winddirection_unit: .degreeDirection,
            weathercode_unit: .wmoCode,
            time: Timestamp(2022,7,13,15,0))*/
        
        let daily = ApiSection<ForecastVariableDaily>(name: "daily", time: TimerangeDt(start: Timestamp(2022,7,12,0), nTime: 2, dtSeconds: 86400), columns: [
            ApiColumn(variable: .temperature_2m_mean, unit: .celsius, variables: [.float(.init(repeating: 20, count: 2))]),
            ApiColumn(variable: .windspeed_10m_mean, unit: .kilometresPerHour, variables: [.float(.init(repeating: 10, count: 2))]),
        ])
        
        let hourly = ApiSection<ForecastapiResult<MultiDomains>.SurfacePressureAndHeightVariable>(name: "hourly", time: TimerangeDt(start: Timestamp(2022,7,12,0), nTime: 48, dtSeconds: 3600), columns: [
            ApiColumn(variable: .surface(.init(.temperature_2m, 0)), unit: .celsius, variables: [.float(.init(repeating: 20, count: 48))]),
            ApiColumn(variable: .surface(.init(.windspeed_10m, 0)), unit: .kilometresPerHour, variables: [.float(.init(repeating: 10, count: 48))]),
        ])
        
        let currentSection = ApiSectionSingle<ForecastapiResult<MultiDomains>.SurfacePressureAndHeightVariable>(name: "current_weather", time: Timestamp(2022,7,12,1,15), dtSeconds: 3600/4, columns: [
            ApiColumnSingle(variable: .surface(.init(.temperature_20m, 0)), unit: .celsius, value: 20),
            ApiColumnSingle(variable: .surface(.init(.windspeed_100m, 0)), unit: .kilometresPerHour, value: 10),
        ])
        
        let res = ForecastapiResult<MultiDomains>.PerModel(
            model: .best_match,
            latitude: 41,
            longitude: 2,
            elevation: nil,
            prefetch: {},
            current: {currentSection},
            hourly: {
                hourly
            },
            daily: {
                daily
            },
            sixHourly: nil,
            minutely15: nil
        )
        let data = ForecastapiResult<MultiDomains>(timeformat: .iso8601, results: [ForecastapiResult<MultiDomains>.PerLocation(timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"), time: TimerangeLocal(range: daily.time.range, utcOffsetSeconds: 0), locationId: 0, results: [res])])
        
        XCTAssertEqual(data.calculateQueryWeight(nVariablesModels: 2), 1)
        XCTAssertEqual(data.calculateQueryWeight(nVariablesModels: 15), 1.5)
        XCTAssertEqual(data.calculateQueryWeight(nVariablesModels: 20), 2)
        
        let json = await drainString(try data.response(format: .json, numberOfLocationsMaximum: 1000, fixedGenerationTime: 12))
        XCTAssertEqual(json, """
            {"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","current_weather_units":{"time":"iso8601","interval":"seconds","temperature_20m":"°C","windspeed_100m":"km/h"},"current_weather":{"time":"2022-07-12T02:15","interval":900,"temperature_20m":20.0,"windspeed_100m":10.0},"hourly_units":{"time":"iso8601","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":["2022-07-12T01:00","2022-07-12T02:00","2022-07-12T03:00","2022-07-12T04:00","2022-07-12T05:00","2022-07-12T06:00","2022-07-12T07:00","2022-07-12T08:00","2022-07-12T09:00","2022-07-12T10:00","2022-07-12T11:00","2022-07-12T12:00","2022-07-12T13:00","2022-07-12T14:00","2022-07-12T15:00","2022-07-12T16:00","2022-07-12T17:00","2022-07-12T18:00","2022-07-12T19:00","2022-07-12T20:00","2022-07-12T21:00","2022-07-12T22:00","2022-07-12T23:00","2022-07-13T00:00","2022-07-13T01:00","2022-07-13T02:00","2022-07-13T03:00","2022-07-13T04:00","2022-07-13T05:00","2022-07-13T06:00","2022-07-13T07:00","2022-07-13T08:00","2022-07-13T09:00","2022-07-13T10:00","2022-07-13T11:00","2022-07-13T12:00","2022-07-13T13:00","2022-07-13T14:00","2022-07-13T15:00","2022-07-13T16:00","2022-07-13T17:00","2022-07-13T18:00","2022-07-13T19:00","2022-07-13T20:00","2022-07-13T21:00","2022-07-13T22:00","2022-07-13T23:00","2022-07-14T00:00"],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"iso8601","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":["2022-07-12","2022-07-13"],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}}
            """)
        
        let dataUnix = ForecastapiResult<MultiDomains>(timeformat: .unixtime, results: [ForecastapiResult<MultiDomains>.PerLocation(timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"), time: TimerangeLocal(range: daily.time.range, utcOffsetSeconds: 0), locationId: 0, results: [res])])
        
        let jsonUnix = await drainString(try dataUnix.response(format: .json, numberOfLocationsMaximum: 1000, fixedGenerationTime: 12))
        XCTAssertEqual(jsonUnix, """
            {"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","current_weather_units":{"time":"unixtime","interval":"seconds","temperature_20m":"°C","windspeed_100m":"km/h"},"current_weather":{"time":1657588500,"interval":900,"temperature_20m":20.0,"windspeed_100m":10.0},"hourly_units":{"time":"unixtime","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":[1657584000,1657587600,1657591200,1657594800,1657598400,1657602000,1657605600,1657609200,1657612800,1657616400,1657620000,1657623600,1657627200,1657630800,1657634400,1657638000,1657641600,1657645200,1657648800,1657652400,1657656000,1657659600,1657663200,1657666800,1657670400,1657674000,1657677600,1657681200,1657684800,1657688400,1657692000,1657695600,1657699200,1657702800,1657706400,1657710000,1657713600,1657717200,1657720800,1657724400,1657728000,1657731600,1657735200,1657738800,1657742400,1657746000,1657749600,1657753200],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"unixtime","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":[1657584000,1657670400],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}}
            """)
        
        let csv = await drainString(try data.response(format: .csv, numberOfLocationsMaximum: 1000))
        XCTAssertEqual(csv, """
            latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation
            41.0,2.0,NaN,3600,GMT,GMT

            time,temperature_20m (°C),windspeed_100m (km/h)
            2022-07-12T02:15,20.0,10.0

            time,temperature_2m (°C),windspeed_10m (km/h)
            2022-07-12T01:00,20.0,10.0
            2022-07-12T02:00,20.0,10.0
            2022-07-12T03:00,20.0,10.0
            2022-07-12T04:00,20.0,10.0
            2022-07-12T05:00,20.0,10.0
            2022-07-12T06:00,20.0,10.0
            2022-07-12T07:00,20.0,10.0
            2022-07-12T08:00,20.0,10.0
            2022-07-12T09:00,20.0,10.0
            2022-07-12T10:00,20.0,10.0
            2022-07-12T11:00,20.0,10.0
            2022-07-12T12:00,20.0,10.0
            2022-07-12T13:00,20.0,10.0
            2022-07-12T14:00,20.0,10.0
            2022-07-12T15:00,20.0,10.0
            2022-07-12T16:00,20.0,10.0
            2022-07-12T17:00,20.0,10.0
            2022-07-12T18:00,20.0,10.0
            2022-07-12T19:00,20.0,10.0
            2022-07-12T20:00,20.0,10.0
            2022-07-12T21:00,20.0,10.0
            2022-07-12T22:00,20.0,10.0
            2022-07-12T23:00,20.0,10.0
            2022-07-13T00:00,20.0,10.0
            2022-07-13T01:00,20.0,10.0
            2022-07-13T02:00,20.0,10.0
            2022-07-13T03:00,20.0,10.0
            2022-07-13T04:00,20.0,10.0
            2022-07-13T05:00,20.0,10.0
            2022-07-13T06:00,20.0,10.0
            2022-07-13T07:00,20.0,10.0
            2022-07-13T08:00,20.0,10.0
            2022-07-13T09:00,20.0,10.0
            2022-07-13T10:00,20.0,10.0
            2022-07-13T11:00,20.0,10.0
            2022-07-13T12:00,20.0,10.0
            2022-07-13T13:00,20.0,10.0
            2022-07-13T14:00,20.0,10.0
            2022-07-13T15:00,20.0,10.0
            2022-07-13T16:00,20.0,10.0
            2022-07-13T17:00,20.0,10.0
            2022-07-13T18:00,20.0,10.0
            2022-07-13T19:00,20.0,10.0
            2022-07-13T20:00,20.0,10.0
            2022-07-13T21:00,20.0,10.0
            2022-07-13T22:00,20.0,10.0
            2022-07-13T23:00,20.0,10.0
            2022-07-14T00:00,20.0,10.0

            time,temperature_2m_mean (°C),windspeed_10m_mean (km/h)
            2022-07-12,20.0,10.0
            2022-07-13,20.0,10.0
            
            """)
        
        let csvUnix = await drainString(try dataUnix.response(format: .csv, numberOfLocationsMaximum: 1000))
        XCTAssertEqual(csvUnix, """
            latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation
            41.0,2.0,NaN,3600,GMT,GMT

            time,temperature_20m (°C),windspeed_100m (km/h)
            1657588500,20.0,10.0

            time,temperature_2m (°C),windspeed_10m (km/h)
            1657584000,20.0,10.0
            1657587600,20.0,10.0
            1657591200,20.0,10.0
            1657594800,20.0,10.0
            1657598400,20.0,10.0
            1657602000,20.0,10.0
            1657605600,20.0,10.0
            1657609200,20.0,10.0
            1657612800,20.0,10.0
            1657616400,20.0,10.0
            1657620000,20.0,10.0
            1657623600,20.0,10.0
            1657627200,20.0,10.0
            1657630800,20.0,10.0
            1657634400,20.0,10.0
            1657638000,20.0,10.0
            1657641600,20.0,10.0
            1657645200,20.0,10.0
            1657648800,20.0,10.0
            1657652400,20.0,10.0
            1657656000,20.0,10.0
            1657659600,20.0,10.0
            1657663200,20.0,10.0
            1657666800,20.0,10.0
            1657670400,20.0,10.0
            1657674000,20.0,10.0
            1657677600,20.0,10.0
            1657681200,20.0,10.0
            1657684800,20.0,10.0
            1657688400,20.0,10.0
            1657692000,20.0,10.0
            1657695600,20.0,10.0
            1657699200,20.0,10.0
            1657702800,20.0,10.0
            1657706400,20.0,10.0
            1657710000,20.0,10.0
            1657713600,20.0,10.0
            1657717200,20.0,10.0
            1657720800,20.0,10.0
            1657724400,20.0,10.0
            1657728000,20.0,10.0
            1657731600,20.0,10.0
            1657735200,20.0,10.0
            1657738800,20.0,10.0
            1657742400,20.0,10.0
            1657746000,20.0,10.0
            1657749600,20.0,10.0
            1657753200,20.0,10.0

            time,temperature_2m_mean (°C),windspeed_10m_mean (km/h)
            1657584000,20.0,10.0
            1657670400,20.0,10.0
            
            """)
        
        /// needs to set a timestamp, because of zip compression headers
        let xlsx = await drainData(try data.response(format: .xlsx, numberOfLocationsMaximum: 1000, timestamp: Timestamp(2022,7,13))).sha256
        XCTAssertEqual(xlsx, "fe097d32e320d1d122a1f391400e8cdb718d41c23bab8b976fdf8ad3db491024")
        
        let flatbuffers = await drainData(try data.response(format: .flatbuffers, numberOfLocationsMaximum: 1000, fixedGenerationTime: 12)).sha256
        XCTAssertEqual(flatbuffers, "a1dadac11cfff2adbc09ff15355c9fa87f2671f16477d77312ef60e916a7c683")
    }
    
    /// Test output formats for 2 locations
    func testFormatsMultiLocation() async throws {
        /*let current = ForecastapiResult.CurrentWeather(
            temperature: 23,
            windspeed: 12,
            winddirection: 90,
            weathercode: 5,
            is_day: 1,
            temperature_unit: .celsius,
            windspeed_unit: .kmh,
            winddirection_unit: .degreeDirection,
            weathercode_unit: .wmoCode,
            time: Timestamp(2022,7,13,15,0))*/
        
        let daily = ApiSection<ForecastVariableDaily>(name: "daily", time: TimerangeDt(start: Timestamp(2022,7,12,0), nTime: 2, dtSeconds: 86400), columns: [
            ApiColumn(variable: .temperature_2m_mean, unit: .celsius, variables: [.float(.init(repeating: 20, count: 2))]),
            ApiColumn(variable: .windspeed_10m_mean, unit: .kilometresPerHour, variables: [.float(.init(repeating: 10, count: 2))]),
        ])
        
        let hourly = ApiSection<ForecastapiResult<MultiDomains>.SurfacePressureAndHeightVariable>(name: "hourly", time: TimerangeDt(start: Timestamp(2022,7,12,0), nTime: 48, dtSeconds: 3600), columns: [
            ApiColumn(variable: .surface(.init(.temperature_2m, 0)), unit: .celsius, variables: [.float(.init(repeating: 20, count: 48))]),
            ApiColumn(variable: .surface(.init(.windspeed_10m, 0)), unit: .kilometresPerHour, variables: [.float(.init(repeating: 10, count: 48))]),
        ])
        
        let currentSection = ApiSectionSingle<ForecastapiResult<MultiDomains>.SurfacePressureAndHeightVariable>(name: "current_weather", time: Timestamp(2022,7,12,1,15), dtSeconds: 3600/4, columns: [
            ApiColumnSingle(variable: .surface(.init(.temperature_20m, 0)), unit: .celsius, value: 20),
            ApiColumnSingle(variable: .surface(.init(.windspeed_100m, 0)), unit: .kilometresPerHour, value: 10),
        ])
        
        let res = ForecastapiResult<MultiDomains>.PerModel(
            model: .best_match,
            latitude: 41,
            longitude: 2,
            elevation: nil,
            prefetch: {},
            current: {currentSection},
            hourly: {
                hourly
            },
            daily: {
                daily
            },
            sixHourly: nil,
            minutely15: nil
        )
        let location1 = ForecastapiResult<MultiDomains>.PerLocation(timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"), time: TimerangeLocal(range: daily.time.range, utcOffsetSeconds: 0), locationId: 0, results: [res])
        let location2 = ForecastapiResult<MultiDomains>.PerLocation(timezone: .init(utcOffsetSeconds: 3600, identifier: "GMT", abbreviation: "GMT"), time: TimerangeLocal(range: daily.time.range, utcOffsetSeconds: 0), locationId: 1, results: [res])
        let data = ForecastapiResult<MultiDomains>(timeformat: .iso8601, results: [location1, location2])
        
        XCTAssertEqual(data.calculateQueryWeight(nVariablesModels: 2), 2)
        XCTAssertEqual(data.calculateQueryWeight(nVariablesModels: 15), 3)
        XCTAssertEqual(data.calculateQueryWeight(nVariablesModels: 20), 4)
        
        let json = await drainString(try data.response(format: .json, numberOfLocationsMaximum: 1000, fixedGenerationTime: 12))
        XCTAssertEqual(json, """
            [{"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","current_weather_units":{"time":"iso8601","interval":"seconds","temperature_20m":"°C","windspeed_100m":"km/h"},"current_weather":{"time":"2022-07-12T02:15","interval":900,"temperature_20m":20.0,"windspeed_100m":10.0},"hourly_units":{"time":"iso8601","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":["2022-07-12T01:00","2022-07-12T02:00","2022-07-12T03:00","2022-07-12T04:00","2022-07-12T05:00","2022-07-12T06:00","2022-07-12T07:00","2022-07-12T08:00","2022-07-12T09:00","2022-07-12T10:00","2022-07-12T11:00","2022-07-12T12:00","2022-07-12T13:00","2022-07-12T14:00","2022-07-12T15:00","2022-07-12T16:00","2022-07-12T17:00","2022-07-12T18:00","2022-07-12T19:00","2022-07-12T20:00","2022-07-12T21:00","2022-07-12T22:00","2022-07-12T23:00","2022-07-13T00:00","2022-07-13T01:00","2022-07-13T02:00","2022-07-13T03:00","2022-07-13T04:00","2022-07-13T05:00","2022-07-13T06:00","2022-07-13T07:00","2022-07-13T08:00","2022-07-13T09:00","2022-07-13T10:00","2022-07-13T11:00","2022-07-13T12:00","2022-07-13T13:00","2022-07-13T14:00","2022-07-13T15:00","2022-07-13T16:00","2022-07-13T17:00","2022-07-13T18:00","2022-07-13T19:00","2022-07-13T20:00","2022-07-13T21:00","2022-07-13T22:00","2022-07-13T23:00","2022-07-14T00:00"],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"iso8601","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":["2022-07-12","2022-07-13"],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}},{"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","location_id":1,"current_weather_units":{"time":"iso8601","interval":"seconds","temperature_20m":"°C","windspeed_100m":"km/h"},"current_weather":{"time":"2022-07-12T02:15","interval":900,"temperature_20m":20.0,"windspeed_100m":10.0},"hourly_units":{"time":"iso8601","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":["2022-07-12T01:00","2022-07-12T02:00","2022-07-12T03:00","2022-07-12T04:00","2022-07-12T05:00","2022-07-12T06:00","2022-07-12T07:00","2022-07-12T08:00","2022-07-12T09:00","2022-07-12T10:00","2022-07-12T11:00","2022-07-12T12:00","2022-07-12T13:00","2022-07-12T14:00","2022-07-12T15:00","2022-07-12T16:00","2022-07-12T17:00","2022-07-12T18:00","2022-07-12T19:00","2022-07-12T20:00","2022-07-12T21:00","2022-07-12T22:00","2022-07-12T23:00","2022-07-13T00:00","2022-07-13T01:00","2022-07-13T02:00","2022-07-13T03:00","2022-07-13T04:00","2022-07-13T05:00","2022-07-13T06:00","2022-07-13T07:00","2022-07-13T08:00","2022-07-13T09:00","2022-07-13T10:00","2022-07-13T11:00","2022-07-13T12:00","2022-07-13T13:00","2022-07-13T14:00","2022-07-13T15:00","2022-07-13T16:00","2022-07-13T17:00","2022-07-13T18:00","2022-07-13T19:00","2022-07-13T20:00","2022-07-13T21:00","2022-07-13T22:00","2022-07-13T23:00","2022-07-14T00:00"],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"iso8601","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":["2022-07-12","2022-07-13"],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}}]
            """)
        
        let dataUnix = ForecastapiResult<MultiDomains>(timeformat: .unixtime, results: [location1, location2])
        
        let jsonUnix = await drainString(try dataUnix.response(format: .json, numberOfLocationsMaximum: 1000, fixedGenerationTime: 12))
        XCTAssertEqual(jsonUnix, """
            [{"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","current_weather_units":{"time":"unixtime","interval":"seconds","temperature_20m":"°C","windspeed_100m":"km/h"},"current_weather":{"time":1657588500,"interval":900,"temperature_20m":20.0,"windspeed_100m":10.0},"hourly_units":{"time":"unixtime","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":[1657584000,1657587600,1657591200,1657594800,1657598400,1657602000,1657605600,1657609200,1657612800,1657616400,1657620000,1657623600,1657627200,1657630800,1657634400,1657638000,1657641600,1657645200,1657648800,1657652400,1657656000,1657659600,1657663200,1657666800,1657670400,1657674000,1657677600,1657681200,1657684800,1657688400,1657692000,1657695600,1657699200,1657702800,1657706400,1657710000,1657713600,1657717200,1657720800,1657724400,1657728000,1657731600,1657735200,1657738800,1657742400,1657746000,1657749600,1657753200],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"unixtime","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":[1657584000,1657670400],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}},{"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","location_id":1,"current_weather_units":{"time":"unixtime","interval":"seconds","temperature_20m":"°C","windspeed_100m":"km/h"},"current_weather":{"time":1657588500,"interval":900,"temperature_20m":20.0,"windspeed_100m":10.0},"hourly_units":{"time":"unixtime","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":[1657584000,1657587600,1657591200,1657594800,1657598400,1657602000,1657605600,1657609200,1657612800,1657616400,1657620000,1657623600,1657627200,1657630800,1657634400,1657638000,1657641600,1657645200,1657648800,1657652400,1657656000,1657659600,1657663200,1657666800,1657670400,1657674000,1657677600,1657681200,1657684800,1657688400,1657692000,1657695600,1657699200,1657702800,1657706400,1657710000,1657713600,1657717200,1657720800,1657724400,1657728000,1657731600,1657735200,1657738800,1657742400,1657746000,1657749600,1657753200],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"unixtime","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":[1657584000,1657670400],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}}]
            """)
        
        let csv = await drainString(try data.response(format: .csv, numberOfLocationsMaximum: 1000))
        XCTAssertEqual(csv, """
            location_id,latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation
            0,41.0,2.0,NaN,3600,GMT,GMT
            1,41.0,2.0,NaN,3600,GMT,GMT
            
            location_id,time,temperature_20m (°C),windspeed_100m (km/h)
            0,2022-07-12T02:15,20.0,10.0
            1,2022-07-12T02:15,20.0,10.0

            location_id,time,temperature_2m (°C),windspeed_10m (km/h)
            0,2022-07-12T01:00,20.0,10.0
            0,2022-07-12T02:00,20.0,10.0
            0,2022-07-12T03:00,20.0,10.0
            0,2022-07-12T04:00,20.0,10.0
            0,2022-07-12T05:00,20.0,10.0
            0,2022-07-12T06:00,20.0,10.0
            0,2022-07-12T07:00,20.0,10.0
            0,2022-07-12T08:00,20.0,10.0
            0,2022-07-12T09:00,20.0,10.0
            0,2022-07-12T10:00,20.0,10.0
            0,2022-07-12T11:00,20.0,10.0
            0,2022-07-12T12:00,20.0,10.0
            0,2022-07-12T13:00,20.0,10.0
            0,2022-07-12T14:00,20.0,10.0
            0,2022-07-12T15:00,20.0,10.0
            0,2022-07-12T16:00,20.0,10.0
            0,2022-07-12T17:00,20.0,10.0
            0,2022-07-12T18:00,20.0,10.0
            0,2022-07-12T19:00,20.0,10.0
            0,2022-07-12T20:00,20.0,10.0
            0,2022-07-12T21:00,20.0,10.0
            0,2022-07-12T22:00,20.0,10.0
            0,2022-07-12T23:00,20.0,10.0
            0,2022-07-13T00:00,20.0,10.0
            0,2022-07-13T01:00,20.0,10.0
            0,2022-07-13T02:00,20.0,10.0
            0,2022-07-13T03:00,20.0,10.0
            0,2022-07-13T04:00,20.0,10.0
            0,2022-07-13T05:00,20.0,10.0
            0,2022-07-13T06:00,20.0,10.0
            0,2022-07-13T07:00,20.0,10.0
            0,2022-07-13T08:00,20.0,10.0
            0,2022-07-13T09:00,20.0,10.0
            0,2022-07-13T10:00,20.0,10.0
            0,2022-07-13T11:00,20.0,10.0
            0,2022-07-13T12:00,20.0,10.0
            0,2022-07-13T13:00,20.0,10.0
            0,2022-07-13T14:00,20.0,10.0
            0,2022-07-13T15:00,20.0,10.0
            0,2022-07-13T16:00,20.0,10.0
            0,2022-07-13T17:00,20.0,10.0
            0,2022-07-13T18:00,20.0,10.0
            0,2022-07-13T19:00,20.0,10.0
            0,2022-07-13T20:00,20.0,10.0
            0,2022-07-13T21:00,20.0,10.0
            0,2022-07-13T22:00,20.0,10.0
            0,2022-07-13T23:00,20.0,10.0
            0,2022-07-14T00:00,20.0,10.0
            1,2022-07-12T01:00,20.0,10.0
            1,2022-07-12T02:00,20.0,10.0
            1,2022-07-12T03:00,20.0,10.0
            1,2022-07-12T04:00,20.0,10.0
            1,2022-07-12T05:00,20.0,10.0
            1,2022-07-12T06:00,20.0,10.0
            1,2022-07-12T07:00,20.0,10.0
            1,2022-07-12T08:00,20.0,10.0
            1,2022-07-12T09:00,20.0,10.0
            1,2022-07-12T10:00,20.0,10.0
            1,2022-07-12T11:00,20.0,10.0
            1,2022-07-12T12:00,20.0,10.0
            1,2022-07-12T13:00,20.0,10.0
            1,2022-07-12T14:00,20.0,10.0
            1,2022-07-12T15:00,20.0,10.0
            1,2022-07-12T16:00,20.0,10.0
            1,2022-07-12T17:00,20.0,10.0
            1,2022-07-12T18:00,20.0,10.0
            1,2022-07-12T19:00,20.0,10.0
            1,2022-07-12T20:00,20.0,10.0
            1,2022-07-12T21:00,20.0,10.0
            1,2022-07-12T22:00,20.0,10.0
            1,2022-07-12T23:00,20.0,10.0
            1,2022-07-13T00:00,20.0,10.0
            1,2022-07-13T01:00,20.0,10.0
            1,2022-07-13T02:00,20.0,10.0
            1,2022-07-13T03:00,20.0,10.0
            1,2022-07-13T04:00,20.0,10.0
            1,2022-07-13T05:00,20.0,10.0
            1,2022-07-13T06:00,20.0,10.0
            1,2022-07-13T07:00,20.0,10.0
            1,2022-07-13T08:00,20.0,10.0
            1,2022-07-13T09:00,20.0,10.0
            1,2022-07-13T10:00,20.0,10.0
            1,2022-07-13T11:00,20.0,10.0
            1,2022-07-13T12:00,20.0,10.0
            1,2022-07-13T13:00,20.0,10.0
            1,2022-07-13T14:00,20.0,10.0
            1,2022-07-13T15:00,20.0,10.0
            1,2022-07-13T16:00,20.0,10.0
            1,2022-07-13T17:00,20.0,10.0
            1,2022-07-13T18:00,20.0,10.0
            1,2022-07-13T19:00,20.0,10.0
            1,2022-07-13T20:00,20.0,10.0
            1,2022-07-13T21:00,20.0,10.0
            1,2022-07-13T22:00,20.0,10.0
            1,2022-07-13T23:00,20.0,10.0
            1,2022-07-14T00:00,20.0,10.0

            location_id,time,temperature_2m_mean (°C),windspeed_10m_mean (km/h)
            0,2022-07-12,20.0,10.0
            0,2022-07-13,20.0,10.0
            1,2022-07-12,20.0,10.0
            1,2022-07-13,20.0,10.0

            """)
        
        let csvUnix = await drainString(try dataUnix.response(format: .csv, numberOfLocationsMaximum: 1000))
        XCTAssertEqual(csvUnix, """
            location_id,latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation
            0,41.0,2.0,NaN,3600,GMT,GMT
            1,41.0,2.0,NaN,3600,GMT,GMT
            
            location_id,time,temperature_20m (°C),windspeed_100m (km/h)
            0,1657588500,20.0,10.0
            1,1657588500,20.0,10.0

            location_id,time,temperature_2m (°C),windspeed_10m (km/h)
            0,1657584000,20.0,10.0
            0,1657587600,20.0,10.0
            0,1657591200,20.0,10.0
            0,1657594800,20.0,10.0
            0,1657598400,20.0,10.0
            0,1657602000,20.0,10.0
            0,1657605600,20.0,10.0
            0,1657609200,20.0,10.0
            0,1657612800,20.0,10.0
            0,1657616400,20.0,10.0
            0,1657620000,20.0,10.0
            0,1657623600,20.0,10.0
            0,1657627200,20.0,10.0
            0,1657630800,20.0,10.0
            0,1657634400,20.0,10.0
            0,1657638000,20.0,10.0
            0,1657641600,20.0,10.0
            0,1657645200,20.0,10.0
            0,1657648800,20.0,10.0
            0,1657652400,20.0,10.0
            0,1657656000,20.0,10.0
            0,1657659600,20.0,10.0
            0,1657663200,20.0,10.0
            0,1657666800,20.0,10.0
            0,1657670400,20.0,10.0
            0,1657674000,20.0,10.0
            0,1657677600,20.0,10.0
            0,1657681200,20.0,10.0
            0,1657684800,20.0,10.0
            0,1657688400,20.0,10.0
            0,1657692000,20.0,10.0
            0,1657695600,20.0,10.0
            0,1657699200,20.0,10.0
            0,1657702800,20.0,10.0
            0,1657706400,20.0,10.0
            0,1657710000,20.0,10.0
            0,1657713600,20.0,10.0
            0,1657717200,20.0,10.0
            0,1657720800,20.0,10.0
            0,1657724400,20.0,10.0
            0,1657728000,20.0,10.0
            0,1657731600,20.0,10.0
            0,1657735200,20.0,10.0
            0,1657738800,20.0,10.0
            0,1657742400,20.0,10.0
            0,1657746000,20.0,10.0
            0,1657749600,20.0,10.0
            0,1657753200,20.0,10.0
            1,1657584000,20.0,10.0
            1,1657587600,20.0,10.0
            1,1657591200,20.0,10.0
            1,1657594800,20.0,10.0
            1,1657598400,20.0,10.0
            1,1657602000,20.0,10.0
            1,1657605600,20.0,10.0
            1,1657609200,20.0,10.0
            1,1657612800,20.0,10.0
            1,1657616400,20.0,10.0
            1,1657620000,20.0,10.0
            1,1657623600,20.0,10.0
            1,1657627200,20.0,10.0
            1,1657630800,20.0,10.0
            1,1657634400,20.0,10.0
            1,1657638000,20.0,10.0
            1,1657641600,20.0,10.0
            1,1657645200,20.0,10.0
            1,1657648800,20.0,10.0
            1,1657652400,20.0,10.0
            1,1657656000,20.0,10.0
            1,1657659600,20.0,10.0
            1,1657663200,20.0,10.0
            1,1657666800,20.0,10.0
            1,1657670400,20.0,10.0
            1,1657674000,20.0,10.0
            1,1657677600,20.0,10.0
            1,1657681200,20.0,10.0
            1,1657684800,20.0,10.0
            1,1657688400,20.0,10.0
            1,1657692000,20.0,10.0
            1,1657695600,20.0,10.0
            1,1657699200,20.0,10.0
            1,1657702800,20.0,10.0
            1,1657706400,20.0,10.0
            1,1657710000,20.0,10.0
            1,1657713600,20.0,10.0
            1,1657717200,20.0,10.0
            1,1657720800,20.0,10.0
            1,1657724400,20.0,10.0
            1,1657728000,20.0,10.0
            1,1657731600,20.0,10.0
            1,1657735200,20.0,10.0
            1,1657738800,20.0,10.0
            1,1657742400,20.0,10.0
            1,1657746000,20.0,10.0
            1,1657749600,20.0,10.0
            1,1657753200,20.0,10.0

            location_id,time,temperature_2m_mean (°C),windspeed_10m_mean (km/h)
            0,1657584000,20.0,10.0
            0,1657670400,20.0,10.0
            1,1657584000,20.0,10.0
            1,1657670400,20.0,10.0
            
            """)
        
        /// needs to set a timestamp, because of zip compression headers
        let xlsx = await drainData(try data.response(format: .xlsx, numberOfLocationsMaximum: 1000, timestamp: Timestamp(2022,7,13))).sha256
        XCTAssertEqual(xlsx, "91e1b562e1a7ef1fafe7894f0a797162405eb30677099a5f8e9665d7b180026b")
        
        let flatbuffers = await drainData(try data.response(format: .flatbuffers, numberOfLocationsMaximum: 1000, fixedGenerationTime: 12)).sha256
        XCTAssertEqual(flatbuffers, "52899e668476fef0cbc11934eedcd8adafd54e2f413fef3e7774abce1c62f73b")
    }
    
    func testXlsxWriter() throws {
        let xlsx = try XlsxWriter()
        xlsx.startRow()
        xlsx.write(5)
        xlsx.writeTimestamp(Timestamp(2022,07,10,5,6))
        xlsx.write(42.1, significantDigits: 1)
        xlsx.endRow()
        var data = xlsx.write(timestamp: Timestamp(2022,7,10))
        //try data.write(to: URL(fileURLWithPath: "/Users/patrick/Downloads/test.xlsx"))
        
        XCTAssertEqual(data.readData(length: data.writerIndex)!.sha256, "987fff4d1b6ba45e799e204c55ca03a53794e6479c5c497c0c4fa279f0f6c0f6")
    }
    
    func testGzipStream() throws {
        let hello = try GzipStream(level: 6, chunkCapacity: 512)
        hello.write("Hello")
        let world = try GzipStream(level: 6, chunkCapacity: 512)
        world.write("World")
        let helloGz = hello.finish()
        let worldGz = world.finish()
        
        var zip = ZipWriter.zip(files: [("hello.txt", helloGz), ("world.txt", worldGz)], timestamp: Timestamp(2000,1,1))
        
        XCTAssertEqual(zip.readData(length: zip.writerIndex)!.sha256, "443f2602754152053754ff14b49218858bd555e74b5d8dc8d5e16fc85c7cdcce")
    }
}
