import Foundation
@testable import App
import Testing
@preconcurrency import SwiftEccodes

@Suite struct AirQualityTests {
    @Test func europeanAirQuality() {
        #expect(EuropeanAirQuality.indexNo2(no2: -1).isNaN)
        #expect(EuropeanAirQuality.indexNo2(no2: 0) == 0)
        #expect(EuropeanAirQuality.indexNo2(no2: 5) == 10)
        #expect(EuropeanAirQuality.indexNo2(no2: 17.5) == 30)
        #expect(EuropeanAirQuality.indexNo2(no2: 42.5) == 50)
        #expect(EuropeanAirQuality.indexNo2(no2: 80) == 70)
        #expect(EuropeanAirQuality.indexNo2(no2: 125) == 90)
        #expect(EuropeanAirQuality.indexNo2(no2: 175) == 110)

        #expect(EuropeanAirQuality.indexO3(o3: 30) == 10)
        #expect(EuropeanAirQuality.indexO3(o3: 80) == 30)
        #expect(EuropeanAirQuality.indexO3(o3: 110) == 50)
        #expect(EuropeanAirQuality.indexO3(o3: 140) == 70)
        #expect(EuropeanAirQuality.indexO3(o3: 170) == 90)
        #expect(EuropeanAirQuality.indexO3(o3: 190) == 110)

        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 2.5) == 10)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 10) == 30)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 32.5) == 50)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 70) == 70)
        #expect(EuropeanAirQuality.indexPm2_5(pm2_5: 115) == 90)

        #expect(EuropeanAirQuality.indexPm10(pm10: 7.5) == 10)
        #expect(EuropeanAirQuality.indexPm10(pm10: 30) == 30)
        #expect(EuropeanAirQuality.indexPm10(pm10: 82.5) == 50)
        #expect(EuropeanAirQuality.indexPm10(pm10: 157.5) == 70)
        #expect(EuropeanAirQuality.indexPm10(pm10: 232.5) == 90)
    }

    @Test func usAirQuality() {
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 40).isApproximatelyEqual(to: 36.363636, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 100).isApproximatelyEqual(to: 72.5, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 170).isApproximatelyEqual(to: 107.50001, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 260).isApproximatelyEqual(to: 152.5, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 356).isApproximatelyEqual(to: 201.42856, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 424).isApproximatelyEqual(to: 298.57144, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 600).isApproximatelyEqual(to: 495.0, absoluteTolerance: 0.001))

        #expect(UnitedStatesAirQuality.indexO3(o3: 30, o3_8h_mean: 10).isApproximatelyEqual(to: 9.090909, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 90, o3_8h_mean: 50).isApproximatelyEqual(to: 45.454548, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 150, o3_8h_mean: 100).isApproximatelyEqual(to: 187.5, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 210, o3_8h_mean: 150).isApproximatelyEqual(to: 247.36844, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 260, o3_8h_mean: 190).isApproximatelyEqual(to: 289.47366, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 406, o3_8h_mean: 410).isApproximatelyEqual(to: 301.00003, absoluteTolerance: 0.001))
        #expect(UnitedStatesAirQuality.indexO3(o3: 600, o3_8h_mean: 410).isApproximatelyEqual(to: 495.0, absoluteTolerance: 0.001))
    }
}
