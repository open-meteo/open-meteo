import Foundation
@testable import App
import XCTest


final class ZensunTests: XCTestCase {
    func testIsDaylightTime() {
        let time = TimerangeDt(start: Timestamp(2023,04,06), nTime: 48, dtSeconds: 3600)
        let isDay = Zensun.calculateIsDay(timeRange: time, lat: 52.52, lon: 13.42)
        XCTAssertEqual(isDay, [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    }
    
    func testSunRiseSetLosAngeles() {
        // https://www.timeanddate.com/sun/usa/los-angeles?month=11&year=2021
        let utcOffsetSeconds = -25200
        let currentTime = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let time = ForecastApiQuery.forecastTimeRange(currentTime: currentTime, utcOffsetSeconds: utcOffsetSeconds, pastDays: 0, forecastDays: 1)
        
        // vancouver: lat: 49.25, lon: -123.12
        let times = Zensun.calculateSunRiseSet(timeRange: time.range, lat: 34.05223, lon: -118.24368, utcOffsetSeconds: utcOffsetSeconds)
        XCTAssertEqual(times.rise[0], Timestamp(1636208262))
        XCTAssertEqual(times.set[0], Timestamp(1636246531))
        let sunset = times.set.map({$0.add(utcOffsetSeconds)}).iso8601_YYYYMMddHHmm
        let sunrise = times.rise.map({$0.add(utcOffsetSeconds)}).iso8601_YYYYMMddHHmm
        XCTAssertEqual(sunrise[0], "2021-11-06T07:17") // supposed to be 07:17
        XCTAssertEqual(sunset[0], "2021-11-06T17:55") // supposed to be 17:55
    }
    
    
    func testSunRiseSetVancouver() {
        // https://www.timeanddate.com/sun/canada/vancouver?month=11&year=2021
        let utcOffsetSeconds = -25200
        let currentTime = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let time = ForecastApiQuery.forecastTimeRange(currentTime: currentTime, utcOffsetSeconds: utcOffsetSeconds, pastDays: 0, forecastDays: 1)
        
        let times = Zensun.calculateSunRiseSet(timeRange: time.range, lat: 49.25, lon: -123.12, utcOffsetSeconds: utcOffsetSeconds)
        XCTAssertEqual(times.rise[0], Timestamp(1636211367))
        XCTAssertEqual(times.set[0], Timestamp(1636245767))
        let sunset = times.set.map({$0.add(utcOffsetSeconds)}).iso8601_YYYYMMddHHmm
        let sunrise = times.rise.map({$0.add(utcOffsetSeconds)}).iso8601_YYYYMMddHHmm
        XCTAssertEqual(sunset[0], "2021-11-06T17:42") // supposed to be 17:42
        XCTAssertEqual(sunrise[0], "2021-11-06T08:09") // supposed to be 08:09
    }
    
    func testExtraTerrestrialRadiation() {
        // jaunary 3rd sun is closest to earth
        XCTAssertEqual(Zensun.extraTerrestrialRadiationBackwards(latitude: -23.5, longitude: 0, timerange: TimerangeDt(start: Timestamp(2020, 12, 26, 12), nTime: 1, dtSeconds: 3600))[0], 1400.2303)
        // on jyuly 4rd the sun is the farthest away from earth
        XCTAssertEqual(Zensun.extraTerrestrialRadiationBackwards(latitude: 23.5, longitude: 0, timerange: TimerangeDt(start: Timestamp(2020, 6, 26, 12), nTime: 1, dtSeconds: 3600))[0], 1308.6616)
    }
    
    func testDaylightDuration() {
        // https://www.timeanddate.com/sun/usa/los-angeles?month=11&year=2021
        // should be length 10:46:48 -> 10.78
        let duration = Zensun.calculateDaylightDuration(utcMidnight: Timestamp(2021,11,01) ..< Timestamp(2021,11,02), lat: 34.05223, lon: -118.24368)
        XCTAssertEqual(duration[0]/3600, 10.78, accuracy: 0.0001)
    }
    
    func testZensunDate() {
        // https://en.wikipedia.org/wiki/June_solstice
        XCTAssertEqual(Timestamp(2018, 03, 20, 16, 15).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2018, 06, 21, 10, 07).getSunDeclination() - 23.44, 0, accuracy: 0.01)
        XCTAssertEqual(Timestamp(2018, 09, 23, 01, 54).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2018, 12, 21, 22, 22).getSunDeclination() + 23.44, 0, accuracy: 0.01)
        
        XCTAssertEqual(Timestamp(2019, 03, 20, 21, 58).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2019, 06, 21, 15, 54).getSunDeclination() - 23.44, 0, accuracy: 0.01)
        XCTAssertEqual(Timestamp(2019, 09, 23, 07, 50).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2019, 12, 22, 04, 19).getSunDeclination() + 23.44, 0, accuracy: 0.01)
        
        XCTAssertEqual(Timestamp(2020, 03, 20, 03, 50).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2020, 06, 20, 21, 43).getSunDeclination() - 23.44, 0, accuracy: 0.01)
        XCTAssertEqual(Timestamp(2020, 09, 22, 13, 31).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2020, 12, 21, 10, 03).getSunDeclination() + 23.44, 0, accuracy: 0.01)
        
        XCTAssertEqual(Timestamp(2021, 03, 20, 09, 37).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2021, 06, 21, 03, 32).getSunDeclination() - 23.44, 0, accuracy: 0.01)
        XCTAssertEqual(Timestamp(2021, 09, 22, 19, 21).getSunDeclination(), 0, accuracy: 0.001)
        XCTAssertEqual(Timestamp(2021, 12, 21, 15, 59).getSunDeclination() + 23.44, 0, accuracy: 0.01)
        
        XCTAssertEqual(Timestamp(2023, 3, 20, 12, 25).getSunDeclination(), -0.1483404, accuracy: 0.01)
        
        // reference https://gml.noaa.gov/grad/solcalc/azel.html
        let p = Timestamp(2022,1,1,12).getSunDeclination()
        let e = Timestamp(2022,1,1,12).getSunEquationOfTime()
        XCTAssertEqual(p, -22.977999, accuracy: 0.001)
        XCTAssertEqual(e * 60, -3.5339856, accuracy: 0.001)
        
        let p2 = Timestamp(2024,1,1,12).getSunDeclination()
        let e2 = Timestamp(2024,1,1,12).getSunEquationOfTime()
        XCTAssertEqual(p2, -23.018219, accuracy: 0.001)
        XCTAssertEqual(e2 * 60, -3.3114738, accuracy: 0.001)
        
        let p3 = Timestamp(2022,7,1,12).getSunDeclination()
        let e3 = Timestamp(2022,7,1,12).getSunEquationOfTime()
        XCTAssertEqual(p3, 23.08617, accuracy: 0.001)
        XCTAssertEqual(e3 * 60, -3.9086208, accuracy: 0.001) // should be -3.95
        
        XCTAssertEqual(Timestamp(1970,1,1,12).fractionalDayMidday, 2.0)
        XCTAssertEqual(Timestamp(2022,1,1,12).fractionalDayMidday, 2.0)
        XCTAssertEqual(Timestamp(2023,1,1,12).fractionalDayMidday, 1.75)
        XCTAssertEqual(Timestamp(2024,1,1,12).fractionalDayMidday, 1.5) // leap year
        XCTAssertEqual(Timestamp(2025,1,1,12).fractionalDayMidday, 2.25)
        XCTAssertEqual(Timestamp(2026,1,1,12).fractionalDayMidday, 2.0)
    }
    
    
    func testDNI() {
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 116.0, 305.0, 485.0, 615.0, 680.0, 681.0, 579.0, 428.0, 272.0, 87.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let time = TimerangeDt(start: Timestamp(2022,7,31), nTime: 24, dtSeconds: 3600)
        let dni = Zensun.calculateBackwardsDNISupersampled(directRadiation: directRadiation, latitude: -22.5, longitude: 17, timerange: time, samples: 60)
        // Note: The 7 watts in the morning are just limited to direct radiation. Could be an underlaying bug in DNI calculation
        XCTAssertEqualArray(dni, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 324.14078, 636.4932, 789.15875, 867.035, 900.33246, 912.8854, 881.52747, 797.36115, 714.4923, 552.5704, 97.66914, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01)
        
        //let dni2 = Zensun.calculateBackwardsDNI(directRadiation: directRadiation, latitude: -22.5, longitude: 17, timerange: time)
        //XCTAssertEqual(dni2[1...], [0.0, 0.0, 0.0, 0.0, 0.0, 23.298893, 358.03854, 635.08167, 788.98944, 866.9147, 900.1934, 912.40094, 880.8849, 797.1055, 708.6094, 551.5554, 126.22124, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    }
}
