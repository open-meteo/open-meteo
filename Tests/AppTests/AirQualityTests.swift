import Foundation
@testable import App
import Testing
@preconcurrency import SwiftEccodes

@Suite struct AirQualityTests {
    @Test func europeanAirQuality() {
        #expect(EuropeanAirQuality.indexNo2(no2: -1).isNaN)
        #expect(EuropeanAirQuality.indexNo2(no2: 0) == 0)
        #expect(EuropeanAirQuality.indexNo2(no2: 20) == 10)
        #expect(EuropeanAirQuality.indexNo2(no2: 65) == 30)
        #expect(EuropeanAirQuality.indexNo2(no2: 105) == 50)
        #expect(EuropeanAirQuality.indexNo2(no2: 175) == 70)
        #expect(EuropeanAirQuality.indexNo2(no2: 285) == 90)
        #expect(EuropeanAirQuality.indexNo2(no2: 395) == 110)

        #expect(EuropeanAirQuality.indexO3(o3: 30) == 12.0)
        #expect(EuropeanAirQuality.indexO3(o3: 90) == 36.0)
        #expect(EuropeanAirQuality.indexO3(o3: 150).isApproximatelyEqual(to: 63.636364, absoluteTolerance: 0.001))
        #expect(EuropeanAirQuality.indexO3(o3: 210).isApproximatelyEqual(to: 74.545456, absoluteTolerance: 0.001))
        #expect(EuropeanAirQuality.indexO3(o3: 260).isApproximatelyEqual(to: 82.85714, absoluteTolerance: 0.001))
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
