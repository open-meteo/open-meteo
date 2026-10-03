/// Controls which stored files may fall back to the remote block cache.
enum RemoteDataPolicy: String, CaseIterable, Sendable {
    case all
    case pressureLevelsOnly

    func allowsRemoteFile(path: String) -> Bool {
        switch self {
        case .all:
            return true
        case .pressureLevelsOnly:
            return Self.isPressureLevelFile(path: path)
        }
    }

    private static func isPressureLevelFile(path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              let filename = parts.last, filename.hasSuffix(".om") else {
            return false
        }

        let variable: Substring
        switch parts.first {
        case "data" where parts.count == 4:
            // Match only the series filenames produced by OmFileType.
            guard filename.wholeMatch(of: /(?:chunk|year|master|linear_bias_seasonal|rolling)(?:_-?[0-9]+)?\.om/) != nil else {
                return false
            }
            variable = parts[2]
        case "data_run" where parts.count == 7:
            // data_run/<domain>/YYYY/MM/DD/HHmmZ/<variable>.om
            guard parts[2].wholeMatch(of: /[0-9]{4}/) != nil,
                  parts[3].wholeMatch(of: /(?:0[1-9]|1[0-2])/) != nil,
                  parts[4].wholeMatch(of: /(?:0[1-9]|[12][0-9]|3[01])/) != nil,
                  parts[5].wholeMatch(of: /(?:[01][0-9]|2[0-3])[0-5][0-9]Z/) != nil else {
                return false
            }
            variable = filename.dropLast(3)
        default:
            // Static artifacts, metadata and spatial files (which can mix levels) stay local.
            return false
        }

        // Storage suffixes follow the variable, then previous day, then ensemble member.
        return variable.wholeMatch(of: /[a-z][a-z0-9]*(?:_[a-z0-9]+)*_[1-9][0-9]*hPa(?:_spread)?(?:_previous_day[1-9][0-9]*)?(?:_member[0-9]+)?/) != nil
    }
}

enum RemoteDataPolicyError: Error, Equatable, CustomStringConvertible {
    case remoteFileNotAllowed(String)

    var description: String {
        switch self {
        case .remoteFileNotAllowed(let path):
            return "Remote block cache access is restricted to pressure-level data: \(path)"
        }
    }
}
