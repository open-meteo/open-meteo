import Foundation
@testable import App
import XCTest


final class ZensunTests: XCTestCase {
    /// https://github.com/open-meteo/open-meteo/issues/48
    func testSunRiseSetLosAngeles() {
        let utcOffsetSeconds = -25200
        let currentTime = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let time = ForecastapiQuery.forecastTimeRange(currentTime: currentTime, utcOffsetSeconds: utcOffsetSeconds, pastDays: 0, forecastDays: 1)
        
        let times = Zensun.calculateSunRiseSet(timeRange: time.range, lat: 49.25, lon: -123.12, utcOffsetSeconds: utcOffsetSeconds)
        XCTAssertEqual(times.rise[0], Timestamp(1636211261))
        XCTAssertEqual(times.set[0], Timestamp(1636245878))
        let sunset = times.set.map({$0.add(utcOffsetSeconds)}).iso8601_YYYYMMddHHmm
        let sunrise = times.rise.map({$0.add(utcOffsetSeconds)}).iso8601_YYYYMMddHHmm
        XCTAssertEqual(sunset[0], "2021-11-06T17:44")
        XCTAssertEqual(sunrise[0], "2021-11-06T08:07")
    }
    
    func testExtraTerrestrialRadiation() {
        // jaunary 3rd sun is closest to earth
        XCTAssertEqual(Zensun.extraTerrestrialRadiationBackwards(latitude: -23.5, longitude: 0, timerange: TimerangeDt(start: Timestamp(2020, 12, 26, 12), nTime: 1, dtSeconds: 3600))[0], 1400.2303)
        // on jyuly 4rd the sun is the farthest away from earth
        XCTAssertEqual(Zensun.extraTerrestrialRadiationBackwards(latitude: 23.5, longitude: 0, timerange: TimerangeDt(start: Timestamp(2020, 6, 26, 12), nTime: 1, dtSeconds: 3600))[0], 1308.6616)
    }
}
