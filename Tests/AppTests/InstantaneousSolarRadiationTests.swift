import Foundation
import Testing
@testable import App

@Suite struct InstantaneousSolarRadiationTests {
    let grid = RegularGrid(nx: 1, ny: 1, latMin: 47, lonMin: 4.5, dx: 1, dy: 1)

    @Test(arguments: [900, 3600, 10800])
    func combinedGeometryMatchesSeparateCalculations(dtSeconds: Int) {
        // Include the date line and polar day/night in both hemispheres.
        let grid = RegularGrid(nx: 37, ny: 17, latMin: -80, lonMin: -180, dx: 10, dy: 10)
        for time in [Timestamp(2022, 3, 20), Timestamp(2022, 6, 21, 12),
                     Timestamp(2022, 9, 22, 18), Timestamp(2022, 12, 21, 6)] {
            let range = TimerangeDt(start: time, nTime: 1, dtSeconds: dtSeconds)
            let instant = Zensun.calculateRadiationInstant(grid: grid, timerange: range)
            let averaged = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<grid.count, timerange: range).data
            let radius = time.getSunRadius()
            var data = instant.map { max($0, 0) * Zensun.solarConstant * 0.6 }
            data[0] = .nan
            let kt = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data,
                previous: (time.add(-dtSeconds), [Float](repeating: 0.2, count: grid.count)),
                grid: grid, time: time, dtSeconds: dtSeconds)
            #expect(data[0].isNaN && kt[0].isNaN)
            for i in 1..<grid.count {
                let mean = max(averaged[i], 0)
                if mean == 0 {
                    #expect(data[i] == 0 && kt[i].isNaN)
                    continue
                }
                let elevation = asin(min(instant[i] * radius * radius, 1)).radiansToDegrees
                let expectedKt: Float = 0.2 + min(max((elevation - 1) / 2, 0), 1) * 0.4
                #expect(abs(kt[i] - expectedKt) < 0.0001)
                #expect(abs(data[i] - expectedKt * Zensun.solarConstant * mean) < 0.02)
            }
        }
    }

    @Test(arguments: [900, 3600])
    func sunsetAndLowSun(dtSeconds: Int) throws {
        let day = TimerangeDt(start: Timestamp(2022, 8, 17), nTime: 1440, dtSeconds: 60)
        let times = Array(day)
        let sun = Zensun.calculateRadiationInstant(grid: grid, timerange: day)
        // Find sunset and the last sunlit minute, below the elevation cutoff.
        let sunset = try #require((720..<1440).first { sun[$0] <= 0 })
        let lowSun = sunset - 1
        #expect(sun[lowSun] > 0 && sun[lowSun] * Zensun.solarConstant < 5)
        #expect(lowSun == 1124 && sunset == 1125) // 18:44 and 18:45 UTC
        let expectedRadiation: [Float] = dtSeconds == 900 ? [18.09, 15.85] : [69.66, 67.37]
        for (index, watts) in zip([lowSun, sunset], expectedRadiation) {
            let previous: [Float] = [0.6]
            let range = TimerangeDt(start: times[index], nTime: 1, dtSeconds: dtSeconds)
            let mean = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: range).data[0]
            #expect(mean > 0)
            // Low sun and sunset use only cached KT.
            let expectedKt: Float = 0.6
            var data: [Float] = [max(sun[index], 0) * 0.4 * Zensun.solarConstant]
            let kt = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data, previous: (times[index].add(-dtSeconds), previous), grid: grid, time: times[index], dtSeconds: dtSeconds)
            #expect(abs(data[0] - expectedKt * Zensun.solarConstant * mean) < 0.001)
            #expect(abs(kt[0] - expectedKt) < 0.0001)
            #expect((kt[0] * 10000).rounded() / 10000 == 0.6)
            #expect((data[0] * 100).rounded() / 100 == watts)

            for missingPrevious: [Float]? in [nil, [.nan], [0]] {
                var data: [Float] = [0]
                _ = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data, previous: missingPrevious.map { (times[index].add(-dtSeconds), $0) }, grid: grid, time: times[index], dtSeconds: dtSeconds)
                #expect(data[0] == 0)
            }
            var missing: [Float] = [.nan]
            _ = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &missing, previous: (times[index].add(-dtSeconds), previous), grid: grid, time: times[index], dtSeconds: dtSeconds)
            #expect(missing[0].isNaN)
        }
    }

    @Test(arguments: [3600, 10800])
    func irregularPreviousTimestamp(dtSeconds: Int) {
        let previousTime = Timestamp(2022, 8, 17, 16)
        let time = Timestamp(2022, 8, 17, 19)
        let previousSun = Zensun.calculateRadiationInstant(grid: grid,
            timerange: TimerangeDt(start: previousTime, nTime: 1, dtSeconds: 3600))[0]
        let range = TimerangeDt(start: time, nTime: 1, dtSeconds: dtSeconds)
        #expect(Zensun.calculateRadiationInstant(grid: grid, timerange: range)[0] < 0)
        let mean = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: range).data[0]
        #expect(mean > 0)
        var previousData = [0.6 * Zensun.solarConstant * previousSun]
        let previousKt = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &previousData,
            previous: nil, grid: grid, time: previousTime, dtSeconds: 3600)
        var data: [Float] = [0]
        // A three-hour sample gap supports either a one-hour or three-hour output average.
        // The previous KT must always use the actual 16:00 timestamp.
        _ = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data,
            previous: (previousTime, previousKt),
            grid: grid, time: time, dtSeconds: dtSeconds)
        #expect(abs(data[0] - 0.6 * Zensun.solarConstant * mean) < 0.001)
        let expectedRadiation: Float = dtSeconds == 3600 ? 37.54 : 171.85
        #expect((data[0] * 100).rounded() / 100 == expectedRadiation)
        #expect((previousKt[0] * 10000).rounded() / 10000 == 0.6)
    }

    @Test func cachedKtSurvivesLowSunAndClearsAtNight() {
        var previous: (time: Timestamp, clearnessIndex: [Float])?
        let expectedRadiation: [Float] = [171.35, 67.37, 37.54, 0]
        for (time, watts) in zip([Timestamp(2022, 8, 17, 18), Timestamp(2022, 8, 17, 18, 45),
                                 Timestamp(2022, 8, 17, 19), Timestamp(2022, 8, 17, 20)], expectedRadiation) {
            let range = TimerangeDt(start: time, nTime: 1, dtSeconds: 3600)
            let sun = Zensun.calculateRadiationInstant(grid: grid, timerange: range)[0]
            var data = [max(0, sun) * 0.6 * Zensun.solarConstant]
            let kt = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data,
                previous: previous, grid: grid, time: time, dtSeconds: 3600)
            if time == Timestamp(2022, 8, 17, 20) {
                #expect(data[0] == 0 && kt[0].isNaN)
            } else {
                #expect(data[0] > 0 && abs(kt[0] - 0.6) < 0.0001)
                #expect((kt[0] * 10000).rounded() / 10000 == 0.6)
            }
            #expect((data[0] * 100).rounded() / 100 == watts)
            previous = (time, kt)
        }
        var missing: [Float] = [.nan]
        let kt = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &missing,
            previous: nil, grid: grid, time: Timestamp(2022, 8, 18, 12), dtSeconds: 3600)
        #expect(missing[0].isNaN && kt[0].isNaN)
    }

    // Fixed reference values supplement the formula checks below. Round radiation to
    // 0.01 W/m² and KT to four decimals to tolerate platform-specific floating-point noise.
    @Test(arguments: [
        (Float(-0.01), Float(0.2), Float(33.75)),
        (0, 0.2, 33.80),
        (0.01, 0.2, 33.85),
        (0.99, 0.2, 38.35),
        (1, 0.2, 38.40),
        (1.01, 0.203, 39.02),
        (2, 0.5, 107.47),
        (3, 0.8, 190.24),
        (4, 0.8, 208.48),
        (4.99, 0.8, 226.46),
        (5, 0.8, 226.64),
        (5.01, 0.8, 226.82)
    ])
    func blendsFromThreeToOneDegrees(elevation: Float, expectedKt: Float, expectedRadiation: Float) {
        let time = Timestamp(2022, 8, 17, 12)
        // Position an equatorial grid point at the requested afternoon solar elevation.
        let solarLongitude = -15 * (time.hourWithFraction - 12 + time.getSunEquationOfTime())
        let hourAngle = acos(sin(elevation.degreesToRadians) / cos(time.getSunDeclination().degreesToRadians)).radiansToDegrees
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 0, lonMin: solarLongitude + hourAngle, dx: 1, dy: 1)
        let range = TimerangeDt(start: time, nTime: 1, dtSeconds: 3600)
        let instant = Zensun.calculateRadiationInstant(grid: grid, timerange: range)[0]
        let mean = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: range).data[0]
        #expect(mean > 0)
        var data = [max(instant, 0) * Zensun.solarConstant * 0.8]
        let kt = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data,
            previous: (time.add(-3600), [0.2]), grid: grid, time: time, dtSeconds: 3600)
        // 1° -> cached KT, 2° -> equal weights, 3° -> current KT.
        let expected: Float = 0.2 + min(max((elevation - 1) / 2, 0), 1) * 0.6
        #expect(abs(kt[0] - expected) < 0.0001)
        #expect((kt[0] * 10000).rounded() / 10000 == expectedKt)
        #expect((data[0] * 100).rounded() / 100 == expectedRadiation)
        #expect(abs(data[0] - expected * Zensun.solarConstant * mean) < 0.01)
    }

    @Test func daytimeUsesCurrentSample() {
        let time = Timestamp(2022, 8, 17, 12)
        let range = TimerangeDt(start: time, nTime: 1, dtSeconds: 3600)
        let instant = Zensun.calculateRadiationInstant(grid: grid, timerange: range)[0]
        let mean = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: range).data[0]
        var data = [0.4 * Zensun.solarConstant * instant]
        let kt = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data, previous: (time.add(-3600), [1000]), grid: grid, time: time, dtSeconds: 3600)
        #expect(abs(data[0] - 0.4 * Zensun.solarConstant * mean) < 0.001)
        #expect((kt[0] * 10000).rounded() / 10000 == 0.4)
        #expect((data[0] * 100).rounded() / 100 == 442.40)
    }

    @Test func nightAndMissingHistory() {
        for time in [Timestamp(2022, 8, 17, 3), Timestamp(2022, 8, 17, 23)] {
            var data: [Float] = [2]
            _ = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data, previous: (time.add(-3600), [500]), grid: grid, time: time, dtSeconds: 3600)
            #expect(data[0] == 0)
        }
        // Sunrise stays finite even with a zero cached KT.
        let day = TimerangeDt(start: Timestamp(2022, 8, 17), nTime: 1440, dtSeconds: 60)
        let sun = Zensun.calculateRadiationInstant(grid: grid, timerange: day)
        let times = Array(day)
        let index = sun.firstIndex { $0 > 0 }!
        var data: [Float] = [1]
        _ = Zensun.instantaneousSolarRadiationToBackwardsAverage(data: &data, previous: (times[index].add(-900), [0]), grid: grid, time: times[index], dtSeconds: 900)
        #expect(data[0].isFinite && data[0] >= 0 && data[0] <= 1)
        #expect(data[0] == 0)
    }
}
