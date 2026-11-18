import Testing
@testable import App

struct GribDeaveragerTests {
    @Test func concurrentAccumulationAndAveragesPreserveHistoryAndResets() async {
        for length in [0, 1, 7, 65_539] {
            for concurrency in [1, 4, 16] {
                for stepType in ["accum", "avg"] {
                    let deaverager = GribDeaverager()
                    let steps = [(0, 3, 2, 2, 2), (0, 6, 5, 3, 8), (0, 9, 8, 3, 14), (9, 12, 4, 4, 4), (9, 15, 10, 6, 16)]
                    for (start, end, cumulative, difference, average) in steps {
                        let input = (0..<length).map { $0 == 3 ? Float.nan : Float(($0 % 17 + 1) * cumulative) }
                        var array = Array2D(data: input, nx: length, ny: 1)
                        let keep = await deaverager.deaccumulateIfRequired(variable: "test", member: 0, stepType: stepType, startStep: start, currentStep: end, array2d: &array, nConcurrent: concurrency)
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

    @Test func skippedStepsAndStreamsRemainIndependent() async {
        let deaverager = GribDeaverager()
        var array = Array2D(data: [10, 20], nx: 2, ny: 1)
        #expect(await deaverager.deaccumulateIfRequired(variable: "rain", member: 0, stepType: "instant", stepRange: "invalid", array2d: &array))
        #expect(await deaverager.lastStep("rain", 0) == nil)
        #expect(!(await deaverager.deaccumulateIfRequired(variable: "rain", member: 0, stepType: "accum", stepRange: "invalid", array2d: &array)))
        #expect(!(await deaverager.deaccumulateIfRequired(variable: "rain", member: 0, stepType: "accum", stepRange: "0-0", array2d: &array)))
        #expect(await deaverager.lastStep("rain", 0) == nil)
        for (variable, member, scale) in [("rain", 0, 1), ("rain", 1, 2), ("snow", 0, 3)] {
            for hour in [3, 6, 9] {
                var field = Array2D(data: [Float(hour * scale), Float(hour * scale * 2)], nx: 2, ny: 1)
                #expect(await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: "accum", stepRange: "0-\(hour)", array2d: &field))
                #expect(field.data == [Float(3 * scale), Float(6 * scale)])
            }
        }
        #expect(await deaverager.deaccumulateIfRequired(variable: "rain", member: 0, stepType: "accum", stepRange: "0-9", array2d: &array))
        #expect(array.data == [10, 20])
        #expect(await deaverager.deaccumulateIfRequired(variable: "rain", member: 0, stepType: "accum", stepRange: "0-6", array2d: &array))
        #expect(array.data == [10, 20])
    }
}
