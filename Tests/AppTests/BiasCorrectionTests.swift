import Foundation
@testable import App
import Testing

@Suite struct BiasCorrectionTests {
    @Test func interpolation() {
        #expect(Interpolations.linear(a: 2, b: 4, fraction: 0.75) == 3.5)

        let inverse = Interpolations.linearWeighted(value: 3.5, fraction: 0.75)
        #expect(inverse.a == 0.875)
        #expect(inverse.b == 2.625)
        #expect(inverse.weightA == 0.25)
        #expect(inverse.weightB == 0.75)
    }

    @Test func dailyNormals() {
        let time = TimerangeDt(start: Timestamp(2020, 01, 01), to: Timestamp(2030, 01, 01), dtSeconds: 86400)
        let normalsCalc = DailyNormalsCalculator(years: [2022, 2027], normalsWidthInYears: 5)
        #expect(normalsCalc.timeBins.count == 2)
        let data = (0..<time.count).map { Float($0 / 10).truncatingRemainder(dividingBy: 100) }
        let normals = normalsCalc.calculateDailyNormals(values: ArraySlice(data), time: time)
        XCTAssertEqualArray(normals[0..<10], [33.16129, 34.73077, 32.92, 33.0, 33.08, 33.16, 33.24, 33.36, 33.48, 33.6], accuracy: 0.001)

        let normalsCalc2 = DailyNormalsCalculator(years: [2022, 2027], normalsWidthInYears: 10)
        #expect(normalsCalc2.timeBins.count == 2)
        #expect(normalsCalc2.timeBins[0] == Timestamp(2017, 1, 1)..<Timestamp(2027, 1, 1))
        #expect(normalsCalc2.timeBins[1] == Timestamp(2022, 1, 1)..<Timestamp(2032, 1, 1))
        let data2 = [Float](repeating: 10, count: time.count)
        let normals2 = normalsCalc2.calculateDailyNormals(values: ArraySlice(data2), time: time)
        XCTAssertEqualArray(normals2, [Float](repeating: 10, count: normals2.count), accuracy: 0.001)
    }
}
