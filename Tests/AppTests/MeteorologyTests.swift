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
    
    func testPressureLevelAltitude() {
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1013.25), 0, accuracy: 0.01)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1012.04913), 100, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1007.25775), 500, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1001.2942), 1000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 977.72565), 3000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 954.6082), 5000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 898.7457), 10000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 794.95197), 20000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 701.08527), 30000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 657.64056), 35000, accuracy: 0.1)
        
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 0), 1013.25, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 100), 1012.04913, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 500), 1007.25775, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 1000), 1001.2942, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 3000), 977.72565, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 5000), 954.6082, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 10000), 898.7457, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 20000), 794.95197, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 30000), 701.08527, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 35000), 657.64056, accuracy: 0.001)
        
        let t = Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 900)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 850), to: t), 0.97187996, accuracy: 0.001)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 950), to: t), 1.0471461, accuracy: 0.001)
    }
}
