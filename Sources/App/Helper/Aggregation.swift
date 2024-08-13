extension Array where Element == Float {
    /// Aggregate data
    /// timeOld = 1h
    /// timeNew = 3h
    func aggregate(type: ReaderInterpolation, timeOld: TimerangeDt, timeNew: TimerangeDt) -> [Float] {
        let steps = timeNew.dtSeconds / timeOld.dtSeconds
        let backSeconds = -1 * timeOld.dtSeconds * (steps - 1)
        precondition(timeNew.dtSeconds % timeOld.dtSeconds == 0)
        switch type {
        case .linear, .linearDegrees, .hermite(_), .backwards:
            // take instantanous value
            return timeNew.map({ t in
                guard let i = timeOld.index(of: t) else {
                    return .nan
                }
                return self[i]
            })
        case .solar_backwards_averaged:
            /// Average past steps
            return timeNew.map({ t in
                guard let start = timeOld.index(of: t.add(backSeconds)) else {
                    return .nan
                }
                guard let end = timeOld.index(of: t) else {
                    return .nan
                }
                return self[start...end].mean()
            })
        case .backwards_sum:
            /// Sum past steps
            return timeNew.map({ t in
                guard let start = timeOld.index(of: t.add(backSeconds)) else {
                    return .nan
                }
                guard let end = timeOld.index(of: t) else {
                    return .nan
                }
                return self[start...end].reduce(0, +)
            })
        }
    }
}
