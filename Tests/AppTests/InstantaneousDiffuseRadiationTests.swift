import Foundation
import Testing
@testable import App

@Suite struct InstantaneousDiffuseRadiationTests {
    @Test func ratioSeedingHandlesMissingAndZeroTotals() {
        let ratio = Zensun.instantaneousDiffuseRadiationRatio(
            data: [100, 700, -10, .nan, 100, 0], shortwaveInstant: [400, 400, 400, 400, .nan, 0])
        #expect(Array(ratio.prefix(3)) == [0.25, 1, 0])
        #expect(ratio.suffix(3).allSatisfy { $0.isNaN })
    }

    @Test func nativeTotalAverageAndMissingValues() {
        let time = Timestamp(2022, 8, 17, 12)
        let grid = RegularGrid(nx: 7, ny: 1, latMin: 47, lonMin: 4.5, dx: 0, dy: 1)
        var data: [Float] = [100, 0, 700, .nan, 100, 0, 100]
        let ratio = Zensun.instantaneousDiffuseRadiationToBackwardsAverage(data: &data,
            shortwaveInstant: [400, 400, 400, 400, .nan, 0, 400],
            shortwaveAverage: [200, 200, 200, 200, 200, 200, .nan],
            previous: (time.add(-3600), [Float](repeating: 0.5, count: 7)), grid: grid, time: time)
        #expect(Array(data.prefix(3)) == [50, 0, 200])
        #expect(Array(ratio.prefix(3)) == [0.25, 0, 1])
        #expect(data[3].isNaN && ratio[3].isNaN)
        #expect(data[4].isNaN && ratio[4].isNaN)
        #expect(data[5] == 100 && ratio[5] == 0.5)
        #expect(data[6].isNaN && ratio[6] == 0.25)
    }

    @Test(arguments: [(Float(-1), Float(0.25), Float(30)), (0, 0.25, 30),
                      (1, 0.25, 30), (3, 0.375, 45), (5, 0.5, 60), (10, 0.5, 60)])
    func blendsRatioAtLowSun(elevation: Float, expectedRatio: Float, expectedRadiation: Float) {
        let time = Timestamp(2022, 8, 17, 12)
        let solarLongitude = -15 * (time.hourWithFraction - 12 + time.getSunEquationOfTime())
        let angle = acos(sin(elevation.degreesToRadians) / cos(time.getSunDeclination().degreesToRadians)).radiansToDegrees
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 0, lonMin: solarLongitude + angle, dx: 1, dy: 1)
        var data: [Float] = [elevation > 0 ? 100 : 0]
        let ratio = Zensun.instantaneousDiffuseRadiationToBackwardsAverage(data: &data,
            shortwaveInstant: [elevation > 0 ? 200 : 0], shortwaveAverage: [120],
            previous: (time.add(-3600), [0.25]), grid: grid, time: time)
        #expect(abs(ratio[0] - expectedRatio) < 0.0001)
        #expect(abs(data[0] - expectedRadiation) < 0.001)
        #expect((ratio[0] * 10000).rounded() / 10000 == expectedRatio)
        #expect((data[0] * 100).rounded() / 100 == expectedRadiation)
    }

    @Test func analysisSeedsRatioAndNightClearsIt() {
        let time = Timestamp(2022, 8, 17, 12)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 47, lonMin: 4.5, dx: 1, dy: 1)
        var data: [Float] = [100]
        let initial = Zensun.instantaneousDiffuseRadiationRatio(data: data, shortwaveInstant: [400])
        #expect(initial == [0.25] && data == [100])
        data = [0]
        let sunset = Zensun.instantaneousDiffuseRadiationToBackwardsAverage(data: &data,
            shortwaveInstant: [0], shortwaveAverage: [80], previous: (time, initial),
            grid: grid, time: Timestamp(2022, 8, 17, 19))
        #expect(sunset == [0.25] && data == [20])
        let night = Zensun.instantaneousDiffuseRadiationToBackwardsAverage(data: &data,
            shortwaveInstant: [0], shortwaveAverage: [0], previous: (Timestamp(2022, 8, 17, 19), sunset),
            grid: grid, time: Timestamp(2022, 8, 17, 22))
        #expect(night[0].isNaN && data == [0])
        data = [0]
        _ = Zensun.instantaneousDiffuseRadiationToBackwardsAverage(data: &data,
            shortwaveInstant: [0], shortwaveAverage: [80], previous: nil,
            grid: grid, time: Timestamp(2022, 8, 17, 19))
        #expect(data[0].isNaN)
    }
}
