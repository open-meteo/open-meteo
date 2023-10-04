import Foundation
@testable import App
import XCTest
import SwiftEccodes


final class MeteorologyTests: XCTestCase {
    func testWetbulbTemperature() {
        XCTAssertEqual(Meteorology.wetBulbTemperature(temperature: 10, relativeHumidity: 50), 5.10125499, accuracy: 0.001)
        XCTAssertEqual(Meteorology.wetBulbTemperature(temperature: 5, relativeHumidity: 90), 3.99465138, accuracy: 0.001)
    }
    
    func testRelativeHumidity() {
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 20, dewpoint: 15), 72.93877)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 30, dewpoint: 15), 40.17284)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 40, dewpoint: 15), 23.078619)
        
        // not possible
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 0, dewpoint: 0), 100.0)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 15, dewpoint: 15), 100.0)
        XCTAssertEqual(Meteorology.relativeHumidity(temperature: 5, dewpoint: 15), 100)
    }
    
    func testWindScale() {
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 120, to: 130), 1.008896)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 130, to: 120), 0.9911824)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 98, to: 80), 0.9769196)
        XCTAssertEqual(Meteorology.scaleWindFactor(from: 174, to: 120), 0.9603451)
    }
    
    func testCloudcover() {
        XCTAssertEqual(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 80, pressureHPa: 1000), 0)
        XCTAssertEqual(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 85, pressureHPa: 1000), 0)
        XCTAssertEqual(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 1000), 32.740467)
        XCTAssertEqual(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 1013), 29.359013)
        XCTAssertEqual(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 950), 42.449123)
        XCTAssertEqual(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 500), 59.17517)
        XCTAssertEqual(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 200), 59.17517)
    }
    
    func testElevationFromPressure() {
        XCTAssertEqual(Meteorology.elevation(sealevelPressure: 1020, surfacePressure: 806, temperature_2m: 0.1), 1926.2726)
    }
    
    func testWinddirection() {
        XCTAssertEqualArray(Meteorology.windirectionFast(u: [.nan, 0, 1, -1, 1, -1], v: [0, 0, -1, -1, 1, 1]), [.nan, 180.0, 315.00012, 44.999893, 224.99991, 135.00009], accuracy: 0.0001)
        XCTAssertEqual(Meteorology.windirectionFast(u: [-1,-0,0,1,2,3,4,5,6], v: [-3,-2,-1,-0,0,1,2,3,4]), [18.435053, 360.0, 360.0, 270.0, 270.0, 251.56496, 243.43501, 239.0363, 236.3099])
    }
    
    func testEvapotranspiration() {
        let time = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: 47, longitude: 9, timerange: TimerangeDt(start: time, nTime: 1, dtSeconds: 3600))
        XCTAssertEqual(exrad[0], 626.4218)
        
        let et0 = Meteorology.et0Evapotranspiration(temperature2mCelsius: 25, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 300, elevation: 250, extraTerrestrialRadiation: exrad[0], dtSeconds: 3600)
        XCTAssertEqual(et0, 0.23535295)
        
        let et0night = Meteorology.et0Evapotranspiration(temperature2mCelsius: 25, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 0, elevation: 250, extraTerrestrialRadiation: 0, dtSeconds: 3600)
        XCTAssertEqual(et0night, 0.05091571)
        
        XCTAssertTrue(Meteorology.et0Evapotranspiration(temperature2mCelsius: .nan, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 0, elevation: 250, extraTerrestrialRadiation: 0, dtSeconds: 3600).isNaN)
        
        var et0day = Meteorology.et0EvapotranspirationDaily(temperature2mCelsiusDailyMax: 32, temperature2mCelsiusDailyMin: 18, temperature2mCelsiusDailyMean: 24, windspeed10mMeterPerSecondMean: 8, shortwaveRadiationMJSum: 20, elevation: 100, extraTerrestrialRadiationSum: 28, relativeHumidity: .maxmin(max: 78, min: 54))
        XCTAssertEqual(et0day, 2.7935097)
        
        et0day = Meteorology.et0EvapotranspirationDaily(temperature2mCelsiusDailyMax: 32, temperature2mCelsiusDailyMin: 18, temperature2mCelsiusDailyMean: 24, windspeed10mMeterPerSecondMean: 8, shortwaveRadiationMJSum: 20, elevation: 100, extraTerrestrialRadiationSum: 28, relativeHumidity: .mean(mean: 66))
        XCTAssertEqual(et0day, 2.7744882)
        
        et0day = Meteorology.et0EvapotranspirationDaily(temperature2mCelsiusDailyMax: 32, temperature2mCelsiusDailyMin: 18, temperature2mCelsiusDailyMean: 24, windspeed10mMeterPerSecondMean: 8, shortwaveRadiationMJSum: .nan, elevation: 100, extraTerrestrialRadiationSum: 28, relativeHumidity: .mean(mean: 66))
        XCTAssertEqual(et0day, 2.351875)
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
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1012.04913), 10, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1007.25775), 50, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1001.2942), 100, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 977.72565), 300, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 954.6082), 500, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 898.7457), 1000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 794.95197), 2000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 701.08527), 3000, accuracy: 0.1)
        XCTAssertEqual(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 657.64056), 3500, accuracy: 0.1)
        
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 0), 1013.25, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 10), 1012.04913, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 50), 1007.25775, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 100), 1001.2942, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 300), 977.72565, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 500), 954.6082, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 1000), 898.7457, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 2000), 794.95197, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 3000), 701.08527, accuracy: 0.001)
        XCTAssertEqual(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 3500), 657.64056, accuracy: 0.001)
    }
    
    /// model description https://www.jma.go.jp/jma/jma-eng/jma-center/nwp/outline2022-nwp/pdf/outline2022_03.pdf
    /*func testJMA() throws {
        let file = "/Users/patrick/Downloads/Z__C_RJTD_20221025000000_MSM_GPV_Rjp_Lsurf_FH00-15_grib2.bin"
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file), "No grib file")
        
        let grib = try GribFile(file: file)
        for message in grib.messages {
            print("name", message.get(attribute: "name")!)
            print("shortName", message.get(attribute: "shortName")!)
            print("level", message.get(attribute: "level")!)
            print("stepRange", message.get(attribute: "stepRange")!)
            print("startStep end", message.get(attribute: "startStep")!, message.get(attribute: "endStep")!)
            print("parameterCategory", message.get(attribute: "parameterCategory")!) // can be used to identify
            print("parameterNumber", message.get(attribute: "parameterNumber")!) // can be used to identify
            print("JMA", message.toJmaVariable() ?? "nil")
            
            guard let nx = message.get(attribute: "Nx").map(Int.init) ?? nil else {
                fatalError("Could not get Nx")
            }
            guard let ny = message.get(attribute: "Ny").map(Int.init) ?? nil else {
                fatalError("Could not get Ny")
            }

            /*print(nx, ny)
            message.iterate(namespace: .ls).forEach({
                print($0)
            })
            message.iterate(namespace: .time).forEach({
                print($0)
            })
            message.iterate(namespace: .vertial).forEach({
                print($0)
            })
            message.iterate(namespace: .parameter).forEach({
                print($0)
            })
            message.iterate(namespace: .geography).forEach({
                print($0)
            })*/
            
            let data = try message.getDouble()
            print(data[0..<10])
            
            /*guard let nx = message.get(attribute: "Nx").map(Int.init) ?? nil else {
                fatalError("Could not get Nx")
            }
            guard let ny = message.get(attribute: "Ny").map(Int.init) ?? nil else {
                fatalError("Could not get Ny")
            }
            let short = message.get(attribute: "shortName")!
            let stepRange = message.get(attribute: "stepRange")!
            let array2d = Array2D(data: data.map(Float.init), nx: nx, ny: ny)
            try array2d.writeNetcdf(filename: "\(file)-\(short)-\(stepRange)")*/
        }
    }*/
}
