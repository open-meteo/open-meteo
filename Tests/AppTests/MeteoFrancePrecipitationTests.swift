import Testing
@testable import App

@Suite struct MeteoFrancePrecipitationTests {
    @Test func recoversQuarterHourlyAmountsThroughSixHours() {
        // Distinct wet/dry patterns at two grid points expose window shifts and stale history.
        let amounts: [[Float]] = (0..<24).map { [Float(($0 * 7) % 11), Float(($0 * 3) % 5)] }
        var deaggregator = MeteoFrancePrecipitationDeaggregator()
        for step in amounts.indices {
            var data = amounts[step]
            if step >= 4 {
                data = (0..<2).map { point in
                    amounts[(step - 3)...step].reduce(Float(0)) { $0 + $1[point] }
                }
            }
            deaggregator.process(data: &data, forecastSecond: (step + 1) * 900)
            #expect(data == amounts[step])
        }
    }

    @Test func clampsPackingNoiseAndPreservesMissingValues() {
        var deaggregator = MeteoFrancePrecipitationDeaggregator()
        for step in 1...4 {
            var data: [Float] = [1, 1, .nan]
            deaggregator.process(data: &data, forecastSecond: step * 900)
        }
        var data: [Float] = [2.9999, .nan, 4]
        deaggregator.process(data: &data, forecastSecond: 4500)
        #expect(data[0] == 0)
        #expect(data[1].isNaN)
        #expect(data[2].isNaN)
    }
}
