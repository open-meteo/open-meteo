import Testing
@testable import App

struct GribDeaveragerTests {
    @Test func concurrentAccumulationAndAveragesPreserveHistoryAndResets() async {
        for length in [0, 1, 7] {
            for stepType in ["accum", "avg"] {
                let deaverager = GribDeaverager()
                let steps = [(0, 3, 2, 2, 2), (0, 6, 5, 3, 8), (0, 9, 8, 3, 14), (9, 12, 4, 4, 4), (9, 15, 10, 6, 16)]
                for (start, end, cumulative, difference, average) in steps {
                    let input = (0..<length).map { $0 == 3 ? Float.nan : Float(($0 % 17 + 1) * cumulative) }
                    var array = Array2D(data: input, nx: length, ny: 1)
                    let keep = await deaverager.deaccumulateIfRequired(variable: "test", member: 0, stepType: stepType, startStep: start, currentStep: end, array2d: &array)
                    #expect(keep)
                    #expect(await deaverager.lastStep("test", 0) == end)
                    let factor = stepType == "accum" ? difference : average
                    #expect(array.data.enumerated().allSatisfy { index, value in
                        index == 3 ? value.isNaN : value == Float((index % 17 + 1) * factor)
                    })
                    #expect(input.enumerated().allSatisfy { index, value in
                        index == 3 ? value.isNaN : value == Float((index % 17 + 1) * cumulative)
                    })
                }
            }
        }
    }
}
