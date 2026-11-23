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
            (0.1, 0, 0), // darkness
            (0, 0, 0),
            (0.001, 0.0001, 0), // insufficient solar denominator
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
