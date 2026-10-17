import Foundation
import Vapor

/// DWD source metadata is independent of regular or native storage outputs.
enum DwdModel: Sendable, Equatable {
    case icon(IconDomains)
    case aicon

    var iconDomain: IconDomains? {
        guard case .icon(let domain) = self else { return nil }
        return domain
    }

    var modelName: String {
        switch self {
        case .icon(let domain): return domain == .iconD2_15min ? IconDomains.iconD2.rawValue : domain.rawValue
        case .aicon: return "aicon"
        }
    }

    var nativeDomain: IconNativeDomains {
        switch self {
        case .icon(let domain): return domain.nativeDomain
        case .aicon: return .aiconNative
        }
    }

    var sourceGridIdentity: IconNativeGridIdentity { nativeDomain.nativeGridFile.identity }
    var dtSeconds: Int { iconDomain?.dtSeconds ?? 3 * 3600 }
    var updateIntervalSeconds: Int { iconDomain?.updateIntervalSeconds ?? 3 * 3600 }
    var omFileLength: Int { iconDomain?.omFileLength ?? 84 }
    var countEnsembleMember: Int { iconDomain?.countEnsembleMember ?? 1 }
    var hasYearlyFiles: Bool { iconDomain?.hasYearlyFiles ?? false }
    var masterTimeRange: Range<Timestamp>? { iconDomain?.masterTimeRange }
    var generateFullRun: Bool { iconDomain?.generateFullRun ?? true }
    var generateTimeSeries: Bool { iconDomain?.generateTimeSeries ?? true }

    /// AICON shares ICON global's native elevation and land fraction, which AICON does not publish.
    var staticSource: Self { self == .aicon ? .icon(.icon) : self }

    func lastRun(now: Timestamp = .now()) -> Timestamp {
        switch self {
        case .icon(let domain): return domain.lastRun(now: now)
        case .aicon: return now.subtract(hours: 2).floor(toNearestHour: 3)
        }
    }

    func getDownloadForecastSteps(run: Int) throws -> [Int] {
        switch self {
        case .icon(let domain): return domain.getDownloadForecastSteps(run: run)
        case .aicon:
            guard (0..<24).contains(run), run.isMultiple(of: 3) else {
                throw Abort(.badRequest, reason: "AICON runs must be initialized at a multiple of three UTC hours.")
            }
            let lastHour = run.isMultiple(of: 12) ? 180 : run.isMultiple(of: 6) ? 120 : 48
            return Array(stride(from: 3, through: lastHour, by: 3))
        }
    }

    func getGribUrl(field: (variable: String, cat: String, level: Int?), run: Timestamp, leadSeconds: Int, member: Int = 0) -> String {
        let levelPath: String
        switch field.cat {
        case "pressure-level": levelPath = "lvt1/100/lv1/\(field.level! * 100)/"
        case "model-level": levelPath = "lvt1/150/lv1/\(field.level!)/"
        case "soil-level": levelPath = "lvt1/106/lv1/\(Double(field.level!) / 100)/"
        default: levelPath = ""
        }
        let ensemble = countEnsembleMember > 1 ? "e/\((member + 1).zeroPadded(len: 2))/" : ""
        let hours = (leadSeconds / 3600).zeroPadded(len: 3)
        let minutes = ((leadSeconds % 3600) / 60).zeroPadded(len: 2)
        return "https://opendata.dwd.de/weather/nwp/v1/m/\(modelName)/p/\(field.variable.uppercased())/\(levelPath)r/\(run.iso8601_YYYY_MM_dd_HH_mm)/\(ensemble)s/PT\(hours)H\(minutes)M.grib2"
    }
}

extension DomainTimeSeriesMetadata {
    init(_ model: DwdModel) {
        self.dtSeconds = model.dtSeconds
        self.omFileLength = model.omFileLength
        self.updateIntervalSeconds = model.updateIntervalSeconds
    }
}
