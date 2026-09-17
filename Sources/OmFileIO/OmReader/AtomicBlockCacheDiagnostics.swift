import Foundation
import Logging
import Synchronization

/// Process-local write/deletion diagnostics. Recent access is a risk indicator,
/// not proof that a reader was still using the affected payload.
public final class AtomicBlockCacheDiagnostics: Sendable {
    public static let shared = AtomicBlockCacheDiagnostics()

    enum Path: String, CaseIterable {
        case empty, sameKey = "same_key", lru

        var index: Int {
            switch self {
            case .empty: return 0
            case .sameKey: return 1
            case .lru: return 2
            }
        }
    }

    enum Age: String, CaseIterable {
        case under10ms = "lt_10ms"
        case under100ms = "10ms_100ms"
        case under1s = "100ms_1s"
        case under5s = "1s_5s"
        case older = "ge_5s"

        var index: Int {
            switch self {
            case .under10ms: return 0
            case .under100ms: return 1
            case .under1s: return 2
            case .under5s: return 3
            case .older: return 4
            }
        }

        init(nanoseconds: UInt) {
            switch nanoseconds {
            case ..<10_000_000: self = .under10ms
            case ..<100_000_000: self = .under100ms
            case ..<1_000_000_000: self = .under1s
            case ..<5_000_000_000: self = .under5s
            default: self = .older
            }
        }
    }

    private final class Counter: Sendable {
        let value = Atomic<UInt64>(0)
    }

    private final class PathCounters: Sendable {
        let claims = Atomic<UInt64>(0)
        let inFlight = Atomic<UInt64>(0)
        let ages = Age.allCases.map { _ in Counter() }
    }

    private let paths = Path.allCases.map { _ in PathCounters() }
    private let publicationConflicts = Atomic<UInt64>(0)
    private let deletions = Age.allCases.map { _ in Counter() }
    private let processID = ProcessInfo.processInfo.processIdentifier
    private let logger: Logger

    init(logger: Logger = Logger(label: "OmFileIO.AtomicBlockCache")) {
        self.logger = logger
    }

    /// Called once per successful claim, after publication. `observed` must be
    /// publication.original, not a later load that could describe another event.
    func recordWrite(previous: WordPair, claim: WordPair, slot: Int, path: Path, claimedAt: UInt, published: Bool, observed: WordPair, cacheFile: String) {
        let path = previous.second == 0 ? .empty : path
        let counters = paths[path.index]
        counters.claims.add(1, ordering: .relaxed)

        var reason: String?
        let age = previous.second == 0 ? nil : Self.age(of: previous, at: claimedAt)
        if let age {
            if previous.second & 1 == 0 {
                counters.inFlight.add(1, ordering: .relaxed)
                reason = "replaced_inflight_entry"
            } else {
                counters.ages[Age(nanoseconds: age).index].value.add(1, ordering: .relaxed)
                if age < 5_000_000_000 { reason = "replaced_recent_entry" }
            }
        }
        if !published { publicationConflicts.add(1, ordering: .relaxed) }
        guard reason != nil || !published else { return }

        var metadata = metadata(previous: previous, slot: slot, cacheFile: cacheFile, age: age)
        metadata["path"] = .string(path.rawValue)
        metadata["new_key"] = .stringConvertible(claim.first)
        metadata["claim_timestamp_ns"] = .stringConvertible(claim.second & ~UInt(1))
        metadata["published"] = .stringConvertible(published)
        if !published {
            metadata["observed_key"] = .stringConvertible(observed.first)
            metadata["observed_state"] = .string(Self.state(of: observed))
            metadata["observed_timestamp_ns"] = .stringConvertible(observed.second & ~UInt(1))
        }
        if let reason {
            metadata["reason"] = .string(reason)
            logger.warning("Atomic block cache entry replaced; active reader/writer overlap is not established", metadata: metadata)
        }
        if !published {
            metadata["reason"] = "publication_conflict"
            logger.warning("Atomic block cache claim changed before publication, after payload copying", metadata: metadata)
        }
    }

    /// Only call after a successful deletion CAS, with the entry it removed.
    func recordDelete(previous: WordPair, slot: Int, deletedAt: UInt, olderThanSeconds: UInt, cacheFile: String) {
        let age = Self.age(of: previous, at: deletedAt)
        deletions[Age(nanoseconds: age).index].value.add(1, ordering: .relaxed)
        guard age < 5_000_000_000 else { return }
        var metadata = metadata(previous: previous, slot: slot, cacheFile: cacheFile, age: age)
        metadata["reason"] = "deleted_recent_entry"
        metadata["older_than_seconds"] = .stringConvertible(olderThanSeconds)
        logger.warning("Atomic block cache recently accessed entry deleted; outstanding readers are not tracked", metadata: metadata)
    }

    private static func state(of entry: WordPair) -> String {
        if entry.second == 0 { return "empty" }
        return entry.second & 1 == 0 ? "inflight" : "committed"
    }

    /// Preserve the existing age buckets, clamping backwards wall-clock movement.
    private static func age(of entry: WordPair, at time: UInt) -> UInt {
        let timestamp = entry.second & ~UInt(1)
        return time >= timestamp ? time - timestamp : 0
    }

    private func metadata(previous: WordPair, slot: Int, cacheFile: String, age: UInt?) -> Logger.Metadata {
        var metadata: Logger.Metadata = [
            "cache_file": .string(cacheFile),
            "pid": .stringConvertible(processID),
            "slot": .stringConvertible(slot),
            "previous_key": .stringConvertible(previous.first),
            "previous_state": .string(Self.state(of: previous)),
            "previous_timestamp_ns": .stringConvertible(previous.second & ~UInt(1))
        ]
        if let age {
            metadata["access_age_seconds"] = .stringConvertible(Double(age) / 1_000_000_000)
        }
        return metadata
    }

    /// Fixed-cardinality metrics; no cache scan or lazy cache initialization.
    public func prometheusMetrics() -> String {
        var lines = [
            "# HELP om_block_cache_write_claims_total Successful write slot claims, including claims whose publication later failed.",
            "# TYPE om_block_cache_write_claims_total counter"
        ]
        for path in Path.allCases {
            lines.append("om_block_cache_write_claims_total{path=\"\(path.rawValue)\"} \(paths[path.index].claims.load(ordering: .relaxed))")
        }
        lines += [
            "# HELP om_block_cache_replacements_total Committed entries claimed for replacement, by non-overlapping access-age bucket; not proof of reader overlap.",
            "# TYPE om_block_cache_replacements_total counter"
        ]
        for path in [Path.sameKey, .lru] {
            for (index, age) in Age.allCases.enumerated() {
                lines.append("om_block_cache_replacements_total{path=\"\(path.rawValue)\",age=\"\(age.rawValue)\"} \(paths[path.index].ages[index].value.load(ordering: .relaxed))")
            }
        }
        lines += [
            "# HELP om_block_cache_inflight_replacements_total Claims of nonempty entries still marked as being written.",
            "# TYPE om_block_cache_inflight_replacements_total counter"
        ]
        for path in [Path.sameKey, .lru] {
            lines.append("om_block_cache_inflight_replacements_total{path=\"\(path.rawValue)\"} \(paths[path.index].inFlight.load(ordering: .relaxed))")
        }
        lines += [
            "# HELP om_block_cache_publication_conflicts_total Failed publication CAS operations after copying a payload; includes interference from deletion.",
            "# TYPE om_block_cache_publication_conflicts_total counter",
            "om_block_cache_publication_conflicts_total \(publicationConflicts.load(ordering: .relaxed))"
        ]
        lines += [
            "# HELP om_block_cache_deletions_total Successful committed entry deletions, by non-overlapping access-age bucket; not proof of reader overlap.",
            "# TYPE om_block_cache_deletions_total counter"
        ]
        for (index, age) in Age.allCases.enumerated() {
            lines.append("om_block_cache_deletions_total{age=\"\(age.rawValue)\"} \(deletions[index].value.load(ordering: .relaxed))")
        }
        return lines.joined(separator: "\n")
    }
}
