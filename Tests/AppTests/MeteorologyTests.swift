import Foundation
@testable import App
import Testing
@preconcurrency import SwiftEccodes

@Suite struct MeteorologyTests {
    @Test func wetbulbTemperature() {
        #expect(Meteorology.wetBulbTemperature(temperature: 10, relativeHumidity: 50).isApproximatelyEqual(to: 5.10125499, absoluteTolerance: 0.001))
        #expect(Meteorology.wetBulbTemperature(temperature: 5, relativeHumidity: 90).isApproximatelyEqual(to: 3.99465138, absoluteTolerance: 0.001))
        #expect(Meteorology.wetBulbTemperature(temperature: 23.1, relativeHumidity: 99).isApproximatelyEqual(to: 23.001404, absoluteTolerance: 0.001))
        #expect(Meteorology.wetBulbTemperature(temperature: 23.1, relativeHumidity: 100).isApproximatelyEqual(to: 23.1, absoluteTolerance: 0.001))
        #expect(Meteorology.wetBulbTemperature(temperature: 23.1, relativeHumidity: 1).isApproximatelyEqual(to: 7.469844, absoluteTolerance: 0.001))
        #expect(Meteorology.wetBulbTemperature(temperature: 23.1, relativeHumidity: 5).isApproximatelyEqual(to: 7.2715874, absoluteTolerance: 0.001))
    }

    @Test func relativeHumidity() {
        #expect(Meteorology.relativeHumidity(temperature: 20, dewpoint: 15) == 72.93877)
        #expect(Meteorology.relativeHumidity(temperature: 30, dewpoint: 15) == 40.17284)
        #expect(Meteorology.relativeHumidity(temperature: 40, dewpoint: 15) == 23.078619)

        // not possible
        #expect(Meteorology.relativeHumidity(temperature: 0, dewpoint: 0) == 100.0)
        #expect(Meteorology.relativeHumidity(temperature: 15, dewpoint: 15) == 100.0)
        #expect(Meteorology.relativeHumidity(temperature: 5, dewpoint: 15) == 100)
    }

    @Test func windScale() {
        #expect(Meteorology.scaleWindFactor(from: 120, to: 130) == 1.008896)
        #expect(Meteorology.scaleWindFactor(from: 130, to: 120) == 0.9911824)
        #expect(Meteorology.scaleWindFactor(from: 98, to: 80) == 0.9769196)
        #expect(Meteorology.scaleWindFactor(from: 174, to: 120) == 0.9603451)
    }

    @Test func cloudcover() {
        #expect(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 80, pressureHPa: 1000) == 0)
        #expect(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 85, pressureHPa: 1000) == 0)
        #expect(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 1000) == 32.740467)
        #expect(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 1013) == 29.359013)
        #expect(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 950) == 42.449123)
        #expect(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 500) == 59.17517)
        #expect(Meteorology.relativeHumidityToCloudCover(relativeHumidity: 95, pressureHPa: 200) == 59.17517)
    }

    @Test func elevationFromPressure() {
        #expect(Meteorology.elevation(sealevelPressure: 1020, surfacePressure: 806, temperature_2m: 0.1) == 1926.2726)
    }

    @Test func winddirection() {
        /*XCTAssertEqual(Meteorology.windirection(u: -4, v:-0), 90)
        XCTAssertEqual(Meteorology.windirection(u: 4, v: 0), 270)
        XCTAssertEqual(Meteorology.windirection(u: 0, v: -4), 360)
        XCTAssertEqual(Meteorology.windirection(u: 0, v: 4), 180)*/
        #expect(arraysEqual(Meteorology.windirectionFast(u: [-4, 4, 0, 0], v: [0, 0, -4, 4]), [90, 270, 360, 180], accuracy: 0.0001))
        #expect(arraysEqual(Meteorology.windirectionFast(u: [.nan, 0, 1, -1, 1, -1], v: [1, 0, -1, -1, 1, 1]), [.nan, 270, 315.00012, 44.999893, 224.99991, 135.00009], accuracy: 0.0001))
        #expect(Meteorology.windirectionFast(u: [-1, -0, 0, 1, 2, 3, 4, 5, 6], v: [-3, -2, -1, -0, 0, 1, 2, 3, 4]) == [18.435053, 360.0, 360.0, 270.0, 270.0, 251.56496, 243.43501, 239.0363, 236.3099])
    }

    @Test func evapotranspiration() {
        let time = Timestamp(1636199223) // UTC 2021-11-06T11:47:03+00:00
        let exrad = Zensun.extraTerrestrialRadiationBackwards(latitude: 47, longitude: 9, timerange: TimerangeDt(start: time, nTime: 1, dtSeconds: 3600))
        #expect(exrad[0] == 626.4218)

        let et0 = Meteorology.et0Evapotranspiration(temperature2mCelsius: 25, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 300, elevation: 250, extraTerrestrialRadiation: exrad[0], dtSeconds: 3600)
        #expect(et0 == 0.23535295)

        let et0night = Meteorology.et0Evapotranspiration(temperature2mCelsius: 25, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 0, elevation: 250, extraTerrestrialRadiation: 0, dtSeconds: 3600)
        #expect(et0night == 0.05091571)

        #expect(Meteorology.et0Evapotranspiration(temperature2mCelsius: .nan, windspeed10mMeterPerSecond: 2, dewpointCelsius: 13.8, shortwaveRadiationWatts: 0, elevation: 250, extraTerrestrialRadiation: 0, dtSeconds: 3600).isNaN)

        var et0day = Meteorology.et0EvapotranspirationDaily(temperature2mCelsiusDailyMax: 32, temperature2mCelsiusDailyMin: 18, temperature2mCelsiusDailyMean: 24, windspeed10mMeterPerSecondMean: 8, shortwaveRadiationMJSum: 20, elevation: 100, extraTerrestrialRadiationSum: 28, relativeHumidity: .maxmin(max: 78, min: 54))
        #expect(et0day == 2.7935097)

        et0day = Meteorology.et0EvapotranspirationDaily(temperature2mCelsiusDailyMax: 32, temperature2mCelsiusDailyMin: 18, temperature2mCelsiusDailyMean: 24, windspeed10mMeterPerSecondMean: 8, shortwaveRadiationMJSum: 20, elevation: 100, extraTerrestrialRadiationSum: 28, relativeHumidity: .mean(mean: 66))
        #expect(et0day == 2.7744882)

        et0day = Meteorology.et0EvapotranspirationDaily(temperature2mCelsiusDailyMax: 32, temperature2mCelsiusDailyMin: 18, temperature2mCelsiusDailyMean: 24, windspeed10mMeterPerSecondMean: 8, shortwaveRadiationMJSum: .nan, elevation: 100, extraTerrestrialRadiationSum: 28, relativeHumidity: .mean(mean: 66))
        #expect(et0day == 2.351875)
    }

    @Test func vaporPressureDeficit() {
        // confirmed with https://www.omnicalculator.com/biology/vapor-pressure-deficit
        #expect(Meteorology.vaporPressureDeficit(temperature2mCelsius: 25, dewpointCelsius: 13.8) == 1.5898033)
        #expect(Meteorology.vaporPressureDeficit(temperature2mCelsius: 25, dewpointCelsius: 25) == 0)
        #expect(Meteorology.vaporPressureDeficit(temperature2mCelsius: 25, dewpointCelsius: 26) == 0)
        #expect(Meteorology.vaporPressureDeficit(temperature2mCelsius: 20, dewpointCelsius: -10) == 2.0525706)
    }

    @Test func pressure() {
        #expect(Meteorology.sealevelPressure(temperature: [15], pressure: [980], elevation: 1000) == [1101.9026])
        #expect(Meteorology.surfacePressure(temperature: [15], pressure: [1101.9026], elevation: 1000) == [980])
    }

    @Test func specificHumidity() {
        #expect(Meteorology.specificToRelativeHumidity(specificHumidity: [6.06], temperature: [23.00], pressure: [1013.25]) == [35.06456])
        #expect(Meteorology.specificToRelativeHumidity(specificHumidity: [0.06], temperature: [23.00], pressure: [1013.25]) == [0.3484397])
        // not really possible
        #expect(Meteorology.specificToRelativeHumidity(specificHumidity: [24.06], temperature: [23.00], pressure: [1013.25]) == [100])
    }

    @Test func pressureLevelAltitude() {
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1013.25).isApproximatelyEqual(to: 0, absoluteTolerance: 0.01))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1012.04913).isApproximatelyEqual(to: 10, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1007.25775).isApproximatelyEqual(to: 50, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 1001.2942).isApproximatelyEqual(to: 100, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 977.72565).isApproximatelyEqual(to: 300, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 954.6082).isApproximatelyEqual(to: 500, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 898.7457).isApproximatelyEqual(to: 1000, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 794.95197).isApproximatelyEqual(to: 2000, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 701.08527).isApproximatelyEqual(to: 3000, absoluteTolerance: 0.1))
        #expect(Meteorology.altitudeAboveSeaLevelMeters(pressureLevelHpA: 657.64056).isApproximatelyEqual(to: 3500, absoluteTolerance: 0.1))

        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 0).isApproximatelyEqual(to: 1013.25, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 10).isApproximatelyEqual(to: 1012.04913, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 50).isApproximatelyEqual(to: 1007.25775, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 100).isApproximatelyEqual(to: 1001.2942, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 300).isApproximatelyEqual(to: 977.72565, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 500).isApproximatelyEqual(to: 954.6082, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 1000).isApproximatelyEqual(to: 898.7457, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 2000).isApproximatelyEqual(to: 794.95197, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 3000).isApproximatelyEqual(to: 701.08527, absoluteTolerance: 0.001))
        #expect(Meteorology.pressureLevelHpA(altitudeAboveSeaLevelMeters: 3500).isApproximatelyEqual(to: 657.64056, absoluteTolerance: 0.001))
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
