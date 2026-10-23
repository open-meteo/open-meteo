/// Accumulate precipitation probability for one timestep without retaining member fields.
actor PrecipitationProbabilityCalculator {
    enum Failure: Error {
        case duplicateMember(Int)
        case inconsistentGridSize
    }

    private let dtHours: Int
    private var members = Set<Int>()
    private var counts = [Float]()

    init(dtHours: Int) {
        self.dtHours = dtHours
    }

    func ingest(member: Int, data: [Float]) throws {
        guard dtHours > 0 else { return }
        guard !members.contains(member) else { throw Failure.duplicateMember(member) }
        if members.isEmpty {
            counts = Array(repeating: 0, count: data.count)
        }
        guard data.count == counts.count else { throw Failure.inconsistentGridSize }
        members.insert(member)
        let threshold = Float(0.1) * Float(dtHours)
        for i in data.indices where data[i] >= threshold {
            counts[i] += 1
        }
    }

    func probabilities() -> [Float]? {
        guard members.count > 1 else { return nil }
        // As before, NaN does not exceed the threshold, but its member counts in the denominator.
        let scale = 100 / Float(members.count)
        return counts.map { $0 * scale }
    }
}
