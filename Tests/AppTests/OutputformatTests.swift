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
        app?.shutdown()
        app = nil
    }
    
    func testBz2Grib() async throws {
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
    }
    
    
    func drainString(_ response: Response) -> String {
        guard var buffer = try? response.body.collect(on: app!.eventLoopGroup.next()).wait() else {
            fatalError("could not get byffer")
        }
        guard let string = buffer.readString(length: buffer.writerIndex) else {
            fatalError("could not convert to string")
        }
        return string
    }
    
    func drainData(_ response: Response) -> Data {
        guard var buffer = try? response.body.collect(on: app!.eventLoopGroup.next()).wait() else {
            fatalError("could not get byffer")
        }
        guard let data = buffer.readData(length: buffer.writerIndex) else {
            fatalError("could not convert to data")
        }
        return data
    }
    
    func testFormats() throws {
        let current = ForecastapiResult.CurrentWeather(
            temperature: 23,
            windspeed: 12,
            winddirection: 90,
            weathercode: 5,
            temperature_unit: .celsius,
            windspeed_unit: .kmh,
            winddirection_unit: .degreeDirection,
            weathercode_unit: .wmoCode,
            time: Timestamp(2022,7,13,15,0))
        
        let sections = [
            ApiSection(name: "hourly", time: TimerangeDt(start: Timestamp(2022,7,12,0), nTime: 48, dtSeconds: 3600), columns: [
                ApiColumn(variable: "temperature_2m", unit: .celsius, data: .float(.init(repeating: 20, count: 48))),
                ApiColumn(variable: "windspeed_10m", unit: .kmh, data: .float(.init(repeating: 10, count: 48))),
            ]),
            ApiSection(name: "daily", time: TimerangeDt(start: Timestamp(2022,7,12,0), nTime: 2, dtSeconds: 86400), columns: [
                ApiColumn(variable: "temperature_2m_mean", unit: .celsius, data: .float(.init(repeating: 20, count: 2))),
                ApiColumn(variable: "windspeed_10m_mean", unit: .kmh, data: .float(.init(repeating: 10, count: 2))),
            ]),
        ]
        
        let data = ForecastapiResult(
            latitude: 41,
            longitude: 2,
            elevation: nil,
            generationtime_ms: 12,
            utc_offset_seconds: 3600,
            timezone: TimeZone(identifier: "GMT")!,
            current_weather: current,
            sections: sections,
            timeformat: .iso8601)
        
        let json = drainString(try data.response(format: .json))
        XCTAssertEqual(json, """
            {"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","current_weather":{"temperature":23.0,"windspeed":12.0,"winddirection":90.0,"weathercode":5,"time":"2022-07-13T16:00"},"hourly_units":{"time":"iso8601","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":["2022-07-12T01:00","2022-07-12T02:00","2022-07-12T03:00","2022-07-12T04:00","2022-07-12T05:00","2022-07-12T06:00","2022-07-12T07:00","2022-07-12T08:00","2022-07-12T09:00","2022-07-12T10:00","2022-07-12T11:00","2022-07-12T12:00","2022-07-12T13:00","2022-07-12T14:00","2022-07-12T15:00","2022-07-12T16:00","2022-07-12T17:00","2022-07-12T18:00","2022-07-12T19:00","2022-07-12T20:00","2022-07-12T21:00","2022-07-12T22:00","2022-07-12T23:00","2022-07-13T00:00","2022-07-13T01:00","2022-07-13T02:00","2022-07-13T03:00","2022-07-13T04:00","2022-07-13T05:00","2022-07-13T06:00","2022-07-13T07:00","2022-07-13T08:00","2022-07-13T09:00","2022-07-13T10:00","2022-07-13T11:00","2022-07-13T12:00","2022-07-13T13:00","2022-07-13T14:00","2022-07-13T15:00","2022-07-13T16:00","2022-07-13T17:00","2022-07-13T18:00","2022-07-13T19:00","2022-07-13T20:00","2022-07-13T21:00","2022-07-13T22:00","2022-07-13T23:00","2022-07-14T00:00"],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"iso8601","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":["2022-07-12","2022-07-13"],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}}
            """)
        
        let dataUnix = ForecastapiResult(
            latitude: 41,
            longitude: 2,
            elevation: nil,
            generationtime_ms: 12,
            utc_offset_seconds: 3600,
            timezone: TimeZone(identifier: "GMT")!,
            current_weather: current,
            sections: sections,
            timeformat: .unixtime)
        
        let jsonUnix = drainString(try dataUnix.response(format: .json))
        XCTAssertEqual(jsonUnix, """
            {"latitude":41.0,"longitude":2.0,"generationtime_ms":12.0,"utc_offset_seconds":3600,"timezone":"GMT","timezone_abbreviation":"GMT","current_weather":{"temperature":23.0,"windspeed":12.0,"winddirection":90.0,"weathercode":5,"time":1657724400},"hourly_units":{"time":"unixtime","temperature_2m":"°C","windspeed_10m":"km/h"},"hourly":{"time":[1657584000,1657587600,1657591200,1657594800,1657598400,1657602000,1657605600,1657609200,1657612800,1657616400,1657620000,1657623600,1657627200,1657630800,1657634400,1657638000,1657641600,1657645200,1657648800,1657652400,1657656000,1657659600,1657663200,1657666800,1657670400,1657674000,1657677600,1657681200,1657684800,1657688400,1657692000,1657695600,1657699200,1657702800,1657706400,1657710000,1657713600,1657717200,1657720800,1657724400,1657728000,1657731600,1657735200,1657738800,1657742400,1657746000,1657749600,1657753200],"temperature_2m":[20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0,20.0],"windspeed_10m":[10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0,10.0]},"daily_units":{"time":"unixtime","temperature_2m_mean":"°C","windspeed_10m_mean":"km/h"},"daily":{"time":[1657584000,1657670400],"temperature_2m_mean":[20.0,20.0],"windspeed_10m_mean":[10.0,10.0]}}
            """)
        
        let csv = drainString(try data.response(format: .csv))
        XCTAssertEqual(csv, """
            latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation
            41.0,2.0,NaN,3600,GMT,GMT

            current_weather_time,temperature (°C),windspeed (km/h),winddirection (°),weathercode (wmo code)
            2022-07-13T16:00,23.0,12.0,90.0,5

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
        
        let csvUnix = drainString(try dataUnix.response(format: .csv))
        XCTAssertEqual(csvUnix, """
            latitude,longitude,elevation,utc_offset_seconds,timezone,timezone_abbreviation
            41.0,2.0,NaN,3600,GMT,GMT

            current_weather_time,temperature (°C),windspeed (km/h),winddirection (°),weathercode (wmo code)
            1657724400,23.0,12.0,90.0,5

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
        let xlsx = drainData(try data.response(format: .xlsx, timestamp: Timestamp(2022,7,13))).base64EncodedString()
        XCTAssertEqual(xlsx, "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")
    }
    
    func testXlsxWriter() throws {
        let xlsx = try XlsxWriter()
        xlsx.startRow()
        xlsx.write(5)
        xlsx.writeTimestamp(Timestamp(2022,07,10,5,6))
        xlsx.write(42.1)
        xlsx.endRow()
        var data = xlsx.write(timestamp: Timestamp(2022,7,10))
        //try data.write(to: URL(fileURLWithPath: "/Users/patrick/Downloads/test.xlsx"))
        
        XCTAssertEqual(data.readData(length: data.writerIndex)!.base64EncodedString(), "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")
    }
    
    func testGzipStream() throws {
        let hello = try GzipStream(level: 6, chunkCapacity: 512)
        hello.write("Hello")
        let world = try GzipStream(level: 6, chunkCapacity: 512)
        world.write("World")
        let helloGz = hello.finish()
        let worldGz = world.finish()
        
        var zip = ZipWriter.zip(files: [("hello.txt", helloGz), ("world.txt", worldGz)], timestamp: Timestamp(2000,1,1))
        
        XCTAssertEqual(zip.readData(length: zip.writerIndex)!.base64EncodedString(), "UEsDBBQAAAAIAAAAISiCidH3BwAAAAUAAAAJAAAAaGVsbG8udHh080jNyckHAFBLAwQUAAAACAAAACEoRz62+wcAAAAFAAAACQAAAHdvcmxkLnR4dAvPL8pJAQBQSwECAAAUAAAACAAAACEogonR9wcAAAAFAAAACQAAAAAAAAAAAAAAAAAAAAAAaGVsbG8udHh0UEsBAgAAFAAAAAgAAAAhKEc+tvsHAAAABQAAAAkAAAAAAAAAAAAAAAAALgAAAHdvcmxkLnR4dFBLBQYAAAAAAgACAG4AAABcAAAAAAA=")
    }
}
