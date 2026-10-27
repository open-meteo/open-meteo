import Foundation

/// Reduce corresponding samples across members stored in separate files.
struct EnsembleReduction {
    enum Statistic {
        case mean
        case minimum
        case maximum
        case percentile(Float)
    }

    let members: Range<Int>
    let statistic: Statistic
    /// GloFAS treats a wholly missing control member as an unavailable source.
    /// This applies to the entire requested range, not individual samples.
    let requireFirstMemberData: Bool

    init(members: Range<Int>, statistic: Statistic, requireFirstMemberData: Bool = false) {
        precondition(!members.isEmpty)
        self.members = members
        self.statistic = statistic
        self.requireFirstMemberData = requireFirstMemberData
    }

    func readTimes(_ time: TimerangeDtAndSettings) -> [TimerangeDtAndSettings] {
        members.map { time.with(ensembleMember: $0) }
    }

    func calculate(_ data: [DataAndUnit]) -> DataAndUnit {
        precondition(data.count == members.count)
        let first = data[0]
        precondition(data.allSatisfy { $0.data.count == first.data.count && $0.unit == first.unit })
        if requireFirstMemberData && first.data.onlyNaN() {
            return first
        }
        let values: [Float] = first.data.indices.map { t in
            switch statistic {
            case .mean:
                // Missing members propagate through the mean.
                return data.lazy.map { $0.data[t] }.mean()
            case .minimum:
                return data.reduce(Float.nan, { $0.isNaN || $1.data[t] < $0 ? $1.data[t] : $0 })
            case .maximum:
                return data.reduce(Float.nan, { $0.isNaN || $1.data[t] > $0 ? $1.data[t] : $0 })
            case .percentile(let percentile):
                // Retain the existing percentile interpolation and NaN behavior.
                return data.map { $0.data[t] }.percentile(percentile)
            }
        }
        return DataAndUnit(values, first.unit)
    }
}
