import Foundation

extension EcmwfVariable {
    /// Canonical GRIB parameter and level distinguish pressure and soil fields.
    var gribKey: String {
        let name = gribName!
        return level.map { "\(name):\($0)" } ?? name
    }

    var skipHourZero: Bool {
        ["10fg", "mx2t3", "mn2t3", "ssrd", "tp", "sf", "ro"].contains(gribName)
    }

    func matches(_ entry: Curl.EcmwfIndexEntry) -> Bool {
        guard (entry.levtype == .pl) == isPressureLevel else { return false }
        if isPressureLevel && entry.level != level { return false }
        if entry.levtype == .sol, let entryLevel = entry.level, entryLevel != level { return false }
        return matchesParameter(entry.param)
    }

    func matches(shortName: String, level: Int) -> Bool {
        if let expected = self.level, expected != level { return false }
        return matchesParameter(shortName)
    }

    private func matchesParameter(_ parameter: String) -> Bool {
        if parameter == gribName { return true }
        switch gribName {
        case "gh": return parameter == "z"
        case "10fg": return ["10fg3", "10fg6", "max_i10fg"].contains(parameter)
        case "mx2t3": return ["max_2t", "mx2t6"].contains(parameter)
        case "mn2t3": return ["min_2t", "mn2t6"].contains(parameter)
        default: return false
        }
    }
}
