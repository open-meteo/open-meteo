import Foundation
@testable import App
import XCTest


final class MeteorologyTests: XCTestCase {
    func testRelativeHumidity() {
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 20, dewpoint: 15), 72.93877)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 30, dewpoint: 15), 40.17284)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 40, dewpoint: 15), 23.078619)
        
        // not possible
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 0, dewpoint: 0), 100.0)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 15, dewpoint: 15), 100.0)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 5, dewpoint: 15), 195.28018)
    }
    
    func testWindScale() {
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 120, to: 130), 1.008896)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 130, to: 120), 0.9911824)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 98, to: 80), 0.9769196)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 174, to: 120), 0.9603451)
    }
    
    func testWinddirection() {
        XCTAssertEqual(Meteorology.windirectionFast(u: [-1,-0,0,1,2,3,4,5,6], v: [-3,-2,-1,-0,0,1,2,3,4]), [18.435059, 360.0, 360.0, 270.0, 270.0, 251.56496, 243.43501, 239.03632, 236.3099])
    }
    
    func testEvapotranspiration() {
        let time = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: 47, longitude: 9, timerange: TimerangeDt(start: time, nTime: 1, dtSeconds: 3600))
        XCTAssertEqual(exrad[0], 626.56384)
        
        let et0 = Meteorology.et0Evapotranspiration(temperature2mCelsius: 25, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 300, elevation: 250, extraTerrestrialRadiation: exrad[0], dtSeconds: 3600)
        XCTAssertEqual(et0, 0.23536535)
        
        let et0night = Meteorology.et0Evapotranspiration(temperature2mCelsius: 25, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 0, elevation: 250, extraTerrestrialRadiation: 0, dtSeconds: 3600)
        XCTAssertEqual(et0night, 0.05091571)
        
        XCTAssertTrue(Meteorology.et0Evapotranspiration(temperature2mCelsius: .nan, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 0, elevation: 250, extraTerrestrialRadiation: 0, dtSeconds: 3600).isNaN)
    }
    
    func testVaporPressureDeficit() {
        // confirmed with https://www.omnicalculator.com/biology/vapor-pressure-deficit
        XCTAssertEqual(Meteorology.vaporPressureDeficit(temperature2mCelsius: 25, dewpointCelsius: 13.8), 1.5898033)
        XCTAssertEqual(Meteorology.vaporPressureDeficit(temperature2mCelsius: 25, dewpointCelsius: 25), 0)
        XCTAssertEqual(Meteorology.vaporPressureDeficit(temperature2mCelsius: 25, dewpointCelsius: 26), 0)
        XCTAssertEqual(Meteorology.vaporPressureDeficit(temperature2mCelsius: 20, dewpointCelsius: -10), 2.0525706)
    }
    
    func testPressure() {
        XCTAssertEqual(Meteorology.sealevelPressure(temperature: [15], pressure: [980], elevation: 1000), [1101.9026])
        XCTAssertEqual(Meteorology.surfacePressure(temperature: [15], pressure: [1101.9026], elevation: 1000), [980])
    }
    
    func testspecificHumidity() {
        XCTAssertEqual(Meteorology.specificToRelativeHumidity(specificHumidity: [6.06], temperature: [23.00], pressure: [1013.25]), [35.06456])
        XCTAssertEqual(Meteorology.specificToRelativeHumidity(specificHumidity: [0.06], temperature: [23.00], pressure: [1013.25]), [0.3484397])
        // not really possible
        XCTAssertEqual(Meteorology.specificToRelativeHumidity(specificHumidity: [24.06], temperature: [23.00], pressure: [1013.25]), [100])
    }
}
