import Foundation
@testable import App
import XCTest


final class ZensunTests: XCTestCase {
    /// https://github.com/open-meteo/open-meteo/issues/48
    func testSunRiseSetLosAngeles() {
        let utcOffsetSeconds = -25200
        let currentTime = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let time = ForecastApiQuery.forecastTimeRange(currentTime: currentTime, utcOffsetSeconds: utcOffsetSeconds, pastDays: 0, forecastDays: 1)
        
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
    
    func testZensunDate() {
        // reference https://gml.noaa.gov/grad/solcalc/azel.html
        let p = Timestamp(2022,1,1,12).getSunDeclination()
        XCTAssertEqual(p.decang, -22.962, accuracy: 0.001) // should be -22.96
        XCTAssertEqual(p.eqtime * 60, -3.6820002, accuracy: 0.001) // should be -3.7
        
        let p2 = Timestamp(2024,1,1,12).getSunDeclination()
        XCTAssertEqual(p2.decang, -23.011, accuracy: 0.001) // should be -23
        XCTAssertEqual(p2.eqtime * 60, -3.4559999, accuracy: 0.001) // should be -3.47
        
        let p3 = Timestamp(2022,7,1,12).getSunDeclination()
        XCTAssertEqual(p3.decang, 23.066, accuracy: 0.001) // should be 23.06
        XCTAssertEqual(p3.eqtime * 60, -3.8260005, accuracy: 0.001) // should be -3.95
        
        XCTAssertEqual(Timestamp(1970,1,1,12).fractionalDay, 2.0)
        XCTAssertEqual(Timestamp(2022,1,1,12).fractionalDay, 2.0)
        XCTAssertEqual(Timestamp(2023,1,1,12).fractionalDay, 1.75)
        XCTAssertEqual(Timestamp(2024,1,1,12).fractionalDay, 1.5) // leap year
        XCTAssertEqual(Timestamp(2025,1,1,12).fractionalDay, 2.25)
        XCTAssertEqual(Timestamp(2026,1,1,12).fractionalDay, 2.0)
    }
    
    
    func testDNI() {
        let directRadiation = [Float(0.0), 0.0, 0.0, 0.0, 0.0, 0.0, 7.0, 116.0, 305.0, 485.0, 615.0, 680.0, 681.0, 579.0, 428.0, 272.0, 87.0, 3.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
        let time = TimerangeDt(start: Timestamp(2022,7,31), nTime: 24, dtSeconds: 3600)
        let dni = Zensun.calculateBackwardsDNISupersampled(directRadiation: directRadiation, latitude: -22.5, longitude: 17, timerange: time, samples: 60)
        XCTAssertEqualArray(dni, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 324.14075, 636.494, 789.159, 867.03485, 900.33246, 912.8853, 881.5282, 797.361, 714.4906, 552.56854, 97.66914, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], accuracy: 0.01)
        
        //let dni2 = Zensun.calculateBackwardsDNI(directRadiation: directRadiation, latitude: -22.5, longitude: 17, timerange: time)
        //XCTAssertEqual(dni2[1...], [0.0, 0.0, 0.0, 0.0, 0.0, 23.298893, 358.03854, 635.08167, 788.98944, 866.9147, 900.1934, 912.40094, 880.8849, 797.1055, 708.6094, 551.5554, 126.22124, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
    }
}
