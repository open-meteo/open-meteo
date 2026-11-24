@testable import App
import Testing

@Suite struct SarahSunsetRepairTests {
    @Test func reconstructSunset() throws {
        let time = Timestamp(2022, 8, 17, 19)
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 47, lonMin: 8, dx: 1, dy: 1)
        let interval = TimerangeDt(start: time.add(-1800), nTime: 3, dtSeconds: 1800)
        let sun = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: interval).data
        #expect(sun[0] > sun[1] && sun[1] > 0 && sun[2] == 0)
        let result = try #require(EumetsatSarahRepairSunsetCommand.reconstruct(
            previous: sun[0] * Zensun.solarConstant * 0.6,
            solarPrevious: sun[0], solarCurrent: sun[1], solarNext: sun[2]))
        #expect(abs(result - sun[1] * Zensun.solarConstant * 0.6) < 0.001)
    }

    @Test func unrelatedGapsAndInvalidHistory() {
        for (previous, current, next): (Float, Float, Float) in [
            (0.1, 0.2, 0.3), // sunrise
            (0.6, 0.5, 0.4), // afternoon
            (0, 0.01, 0), // no usable previous solar denominator
            (.nan, 0.01, 0)
        ] {
            #expect(EumetsatSarahRepairSunsetCommand.reconstruct(previous: 100,
                solarPrevious: previous, solarCurrent: current, solarNext: next) == nil)
        }
        for previous: Float in [.nan, .infinity, -1] {
            #expect(EumetsatSarahRepairSunsetCommand.reconstruct(previous: previous,
                solarPrevious: 0.1, solarCurrent: 0.01, solarNext: 0) == nil)
        }
        #expect(EumetsatSarahRepairSunsetCommand.reconstruct(previous: 0,
            solarPrevious: 0.1, solarCurrent: 0.01, solarNext: 0) == 0)
    }

    @Test func februarySunsetHole() {
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 50.9211, lonMin: 5.7819, dx: 1, dy: 1)
        let time = TimerangeDt(start: Timestamp(2026, 2, 4, 16, 30), nTime: 3, dtSeconds: 1800)
        let solar = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time).data
        #expect(solar[0] > 0 && solar[1] == 0 && solar[2] == 0)
        #expect(EumetsatSarahRepairSunsetCommand.reconstruct(previous: 1,
            solarPrevious: solar[0], solarCurrent: solar[1], solarNext: solar[2]) == 0)
    }

    @Test func holeImmediatelyAfterSunset() {
        // Observed 1 W/m², then a hole in a dark interval, then nighttime zero.
        for previousSolar: Float in [0.1, 0.001, 0] {
            #expect(EumetsatSarahRepairSunsetCommand.reconstruct(previous: 1,
                solarPrevious: previousSolar, solarCurrent: 0, solarNext: 0) == 0)
        }
        // Missing history still must not turn an unobserved location into nighttime zeros.
        #expect(EumetsatSarahRepairSunsetCommand.reconstruct(previous: .nan,
            solarPrevious: 0.001, solarCurrent: 0, solarNext: 0) == nil)
    }

    @Test func lowSunHistoryRemainsUsable() throws {
        // A previous solar integral below 5 W/m² is still usable for the KT ratio.
        let result = try #require(EumetsatSarahRepairSunsetCommand.reconstruct(previous: 1,
            solarPrevious: 0.001, solarCurrent: 0.0001, solarNext: 0))
        #expect(abs(result - 0.1) < 0.0001)
    }

    @Test func berlinSunriseSpike() {
        let grid = RegularGrid(nx: 1, ny: 1, latMin: 52.5, lonMin: 13.400002, dx: 1, dy: 1)
        let time = TimerangeDt(start: Timestamp(2025, 10, 25, 6, 30), nTime: 2, dtSeconds: 1800)
        let solar = Zensun.calculateRadiationBackwardsAveraged(grid: grid, locationRange: 0..<1, timerange: time).data
        let extraterrestrial = solar[0] * Zensun.solarConstant
        #expect(extraterrestrial > 0 && extraterrestrial < 9095)
        let corrected = EumetsatSarahRepairSunsetCommand.limitRadiation(9095,
            solarFactor: solar[0], next: 33, solarNext: solar[1])
        #expect(abs(corrected - 33 * solar[0] / solar[1]) < 0.0001)
    }

    @Test func nextTimestepKtAndFallback() {
        let solar: Float = 0.1
        let solarNext: Float = 0.2
        let extraterrestrial = solar * Zensun.solarConstant
        for kt: Float in [0, 0.4, 0.9] {
            let corrected = EumetsatSarahRepairSunsetCommand.limitRadiation(9095,
                solarFactor: solar, next: kt * solarNext * Zensun.solarConstant, solarNext: solarNext)
            #expect(abs(corrected - kt * extraterrestrial) < 0.0001)
        }
        for (next, nextSolar): (Float, Float) in [(.nan, 0.2), (.infinity, 0.2), (-1, 0.2),
                                                (9095, 0.2), (0.95 * 0.2 * Zensun.solarConstant, 0.2), (0, 0), (33, .nan)] {
            #expect(EumetsatSarahRepairSunsetCommand.limitRadiation(9095,
                solarFactor: solar, next: next, solarNext: nextSolar) == 0.8 * extraterrestrial)
        }
    }

    @Test func radiationLimitThreshold() {
        let solar: Float = 0.1
        let extraterrestrial = solar * Zensun.solarConstant
        for fraction: Float in [0, 0.8, 0.9] {
            let value = fraction * extraterrestrial
            #expect(EumetsatSarahRepairSunsetCommand.limitRadiation(value, solarFactor: solar) == value)
        }
        for fraction: Float in [0.9001, 0.95, 1, 2] {
            #expect(EumetsatSarahRepairSunsetCommand.limitRadiation(fraction * extraterrestrial, solarFactor: solar) == 0.8 * extraterrestrial)
            #expect(abs(EumetsatSarahRepairSunsetCommand.limitRadiation(fraction * extraterrestrial,
                solarFactor: solar, next: 0.4 * extraterrestrial, solarNext: solar) - 0.4 * extraterrestrial) < 0.0001)
        }
        #expect(EumetsatSarahRepairSunsetCommand.limitRadiation(10, solarFactor: 0) == 0)
        #expect(EumetsatSarahRepairSunsetCommand.limitRadiation(.nan, solarFactor: solar).isNaN)
        #expect(EumetsatSarahRepairSunsetCommand.limitRadiation(10, solarFactor: .nan) == 10)
    }

    @Test func correctedOutputPaths() {
        for variable in ["shortwave_radiation", "direct_radiation"] {
            for name in ["year_2020.om", "chunk_12345.om"] {
                #expect(EumetsatSarahRepairSunsetCommand.correctedFilePath("/data/eumetsat_sarah3_30min/" + variable + "/" + name)
                    == "/data/eumetsat_sarah3_30min/" + variable + "_corrected/" + name)
            }
        }
    }

    @Test func nativeSpatialChunks() {
        #expect(EumetsatSarahRepairSunsetCommand.spatialBlocks(dimensions: [5, 7], chunks: [3, 4]) == [
            [0..<3, 0..<4], [0..<3, 4..<7], [3..<5, 0..<4], [3..<5, 4..<7]
        ])
        #expect(EumetsatSarahRepairSunsetCommand.spatialBlocks(dimensions: [15], chunks: [8]) == [
            [0..<8], [8..<15]
        ])
    }
}
