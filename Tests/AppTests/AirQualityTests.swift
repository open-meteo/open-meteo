import Foundation
@testable import App
import XCTest
@preconcurrency import SwiftEccodes

final class AirQualityTests: XCTestCase {
    func testEuropeanAirQuality() {
        XCTAssertTrue(EuropeanAirQuality.indexNo2(no2: -1).isNaN)
        XCTAssertEqual(EuropeanAirQuality.indexNo2(no2: 0), 0)
        XCTAssertEqual(EuropeanAirQuality.indexNo2(no2: 20), 10)
        XCTAssertEqual(EuropeanAirQuality.indexNo2(no2: 65), 30)
        XCTAssertEqual(EuropeanAirQuality.indexNo2(no2: 105), 50)
        XCTAssertEqual(EuropeanAirQuality.indexNo2(no2: 175), 70)
        XCTAssertEqual(EuropeanAirQuality.indexNo2(no2: 285), 90)
        XCTAssertEqual(EuropeanAirQuality.indexNo2(no2: 395), 110)

        XCTAssertEqual(EuropeanAirQuality.indexO3(o3: 30), 12.0)
        XCTAssertEqual(EuropeanAirQuality.indexO3(o3: 90), 36.0)
        XCTAssertEqual(EuropeanAirQuality.indexO3(o3: 150), 63.636364, accuracy: 0.001)
        XCTAssertEqual(EuropeanAirQuality.indexO3(o3: 210), 74.545456, accuracy: 0.001)
        XCTAssertEqual(EuropeanAirQuality.indexO3(o3: 260), 82.85714, accuracy: 0.001)
    }

    func testUSAirQuality() {
        XCTAssertEqual(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 40), 36.363636, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 100), 72.5, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 170), 107.50001, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 260), 152.5, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 356), 201.42856, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 424), 298.57144, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexPm10(pm10_24h_mean: 600), 495.0, accuracy: 0.001)

        XCTAssertEqual(UnitedStatesAirQuality.indexO3(o3: 30, o3_8h_mean: 10), 9.090909, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexO3(o3: 90, o3_8h_mean: 50), 45.454548, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexO3(o3: 150, o3_8h_mean: 100), 187.5, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexO3(o3: 210, o3_8h_mean: 150), 247.36844, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexO3(o3: 260, o3_8h_mean: 190), 289.47366, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexO3(o3: 406, o3_8h_mean: 410), 301.00003, accuracy: 0.001)
        XCTAssertEqual(UnitedStatesAirQuality.indexO3(o3: 600, o3_8h_mean: 410), 495.0, accuracy: 0.001)
    }
}
