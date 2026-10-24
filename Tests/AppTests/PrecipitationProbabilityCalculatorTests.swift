import Testing
@testable import App

@Suite struct PrecipitationProbabilityCalculatorTests {
    @Test(arguments: [3, 6])
    func matchesMemberFieldsIncludingMissingValues(dtHours: Int) async throws {
        let threshold = Float(0.1) * Float(dtHours)
        let fields: [[Float]] = [
            [0, threshold, threshold.nextDown, .nan, 2],
            [1, threshold, threshold.nextUp, 2, .nan],
            [.nan, 0, 0, 0, 2]
        ]
        let calculator = PrecipitationProbabilityCalculator(dtHours: dtHours)
        for (member, field) in fields.enumerated() {
            try await calculator.ingest(member: member, data: field)
        }
        let expected = fields[0].indices.map { i in
            Float(fields.filter { $0[i] >= threshold }.count) * (100 / Float(fields.count))
        }
        #expect(await calculator.probabilities() == expected)
    }

    @Test func requiresTwoMembersAndPositiveInterval() async throws {
        for dtHours in [0, -1, 3] {
            let calculator = PrecipitationProbabilityCalculator(dtHours: dtHours)
            #expect(await calculator.probabilities() == nil)
            try await calculator.ingest(member: 0, data: [1])
            #expect(await calculator.probabilities() == nil)
            try await calculator.ingest(member: 1, data: [1])
            #expect(await calculator.probabilities() == (dtHours > 0 ? [100] : nil))
        }
    }

    @Test func concurrentMembersAreCountedOnce() async throws {
        let calculator = PrecipitationProbabilityCalculator(dtHours: 3)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for member in 0..<51 {
                group.addTask {
                    try await calculator.ingest(member: member, data: [member < 17 ? 1 : 0, 1])
                }
            }
            try await group.waitForAll()
        }
        #expect(await calculator.probabilities() == [17 * (100 / Float(51)), 51 * (100 / Float(51))])
        await #expect(throws: PrecipitationProbabilityCalculator.Failure.self) {
            try await calculator.ingest(member: 0, data: [1, 1])
        }
        await #expect(throws: PrecipitationProbabilityCalculator.Failure.self) {
            try await calculator.ingest(member: 51, data: [1])
        }
    }
}
