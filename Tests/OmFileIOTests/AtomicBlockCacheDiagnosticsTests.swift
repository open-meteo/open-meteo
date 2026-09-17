import Foundation
import Logging
import OmFileFormat
@testable import OmFileIO
import Synchronization
import Testing

// Age timestamps directly so expiry tests do not sleep for a minute.
extension AtomicBlockCache {
    func ageEntriesForReplacement() {
        let count = blockCount
        data.withMutableUnsafeBytes { bytes in
            let entries = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
            for slot in 0..<count {
                let entry = entries[slot].load(ordering: .relaxed)
                if entry.second != 0 {
                    entries[slot].store(.init(first: entry.first, second: entry.second - 61_000_000_000), ordering: .relaxed)
                }
            }
        }
    }
}

@Suite struct AtomicBlockCacheDiagnosticsTests {
    @Test func invalidationPreservesBytesAndDoesNotRenewGracePeriod() throws {
        try withCache { cache, _, _ in
            let original = Data(repeating: 1, count: 64)
            let replacement = Data(repeating: 2, count: 64)
            let borrowed = try #require(cache.set(key: 10, value: original))
            cache.invalidate(key: 10, count: 1)
            #expect(cache.get(key: 10, count: 1) == nil)
            #expect(cache.get(key: 10, maxAccessedAgeInSeconds: 600) == nil)
            #expect(cache.delete(key: 10, count: 1, olderThanSeconds: 0) == 0)
            #expect(cache.set(key: 10, value: replacement) == nil)
            #expect(cache.set(key: 11, value: replacement) == nil)
            #expect(Data(borrowed) == original)

            cache.ageEntriesForReplacement()
            cache.invalidate(key: 10, count: 1)
            #expect(cache.get(key: 10, count: 1) == nil)
            #expect(cache.set(key: 10, value: replacement) != nil)
            #expect(cache.get(key: 10, count: 1)?.data == replacement)
        }
    }

    @Test(arguments: [false, true], [false, true])
    func gracePeriodAndAbandonedWriterRecovery(committed: Bool, sameKey: Bool) throws {
        try withCache { cache, _, _ in
            let original = Data(repeating: 0x11, count: 64)
            let replacement = Data(repeating: 0x22, count: 64)
            cache.set(key: 10, value: original)
            if !committed {
                cache.data.withMutableUnsafeBytes { bytes in
                    let entry = bytes.assumingMemoryBound(to: Atomic<WordPair>.self)
                    let previous = entry[0].load(ordering: .relaxed)
                    entry[0].store(.init(first: previous.first, second: previous.second & ~1), ordering: .relaxed)
                }
            }
            let key: UInt64 = sameKey ? 10 : 11
            #expect(cache.set(key: key, value: replacement) == nil)
            cache.ageEntriesForReplacement()
            #expect(cache.set(key: key, value: replacement) != nil)
            #expect(cache.get(key: key, count: 1).map { Data($0) } == replacement)
        }
    }

    @Test func readRenewsGracePeriod() throws {
        try withCache { cache, _, _ in
            cache.set(key: 10, value: Data(repeating: 1, count: 64))
            cache.ageEntriesForReplacement()
            #expect(cache.get(key: 10, count: 1) != nil)
            #expect(cache.set(key: 11, value: Data(repeating: 2, count: 64)) == nil)
        }
    }

    private final class Logs: Sendable {
        let entries = Mutex<[Logger.Metadata]>([])

        var logger: Logger {
            Logger(label: "cache-diagnostics-test") { _ in Handler(logs: self) }
        }
    }

    private struct Handler: LogHandler {
        let logs: Logs
        var metadata: Logger.Metadata = [:]
        var logLevel: Logger.Level = .warning

        subscript(metadataKey key: String) -> Logger.Metadata.Value? {
            get { metadata[key] }
            set { metadata[key] = newValue }
        }

        func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
            logs.entries.withLock { $0.append(metadata ?? [:]) }
        }
    }

    private func withCache(_ body: (AtomicBlockCache<MmapFile>, AtomicBlockCacheDiagnostics, Logs) throws -> Void) throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("cache-diagnostics-\(UUID().uuidString).bin").path
        defer { try? FileManager.default.removeItem(atPath: file) }
        let existing = try AtomicBlockCache(file: file, blockSize: 64, blockCount: 1)
        let logs = Logs()
        let diagnostics = AtomicBlockCacheDiagnostics(logger: logs.logger)
        let cache = AtomicBlockCache(data: existing.data, blockSize: 64, cacheFile: file, diagnostics: diagnostics)
        try body(cache, diagnostics, logs)
    }

    private func value(_ metrics: String, _ series: String) -> UInt64? {
        let prefix = series + " "
        return metrics.split(separator: "\n").first { $0.hasPrefix(prefix) }.flatMap { UInt64($0.dropFirst(prefix.count)) }
    }

    @Test func insertReplaceAndEvict() throws {
        try withCache { cache, diagnostics, logs in
            cache.set(key: 11, value: Data(repeating: 1, count: 64))
            cache.ageEntriesForReplacement()
            cache.set(key: 11, value: Data(repeating: 2, count: 64))
            // A different key with a one-slot cache must take the LRU path.
            cache.ageEntriesForReplacement()
            cache.set(key: 12, value: Data(repeating: 3, count: 64))
            #expect(cache.get(key: 12, count: 1)?.data == Data(repeating: 3, count: 64))
            #expect(cache.get(key: 11, count: 1) == nil)
            let metrics = diagnostics.prometheusMetrics()
            for path in ["empty", "same_key", "lru"] {
                #expect(value(metrics, "om_block_cache_write_claims_total{path=\"\(path)\"}") == 1)
            }
            for path in ["same_key", "lru"] {
                let total = AtomicBlockCacheDiagnostics.Age.allCases.reduce(UInt64(0)) {
                    $0 + (value(metrics, "om_block_cache_replacements_total{path=\"\(path)\",age=\"\($1.rawValue)\"}") ?? 0)
                }
                #expect(total == 1)
                #expect(value(metrics, "om_block_cache_inflight_replacements_total{path=\"\(path)\"}") == 0)
            }
            #expect(value(metrics, "om_block_cache_publication_conflicts_total") == 0)
            #expect(metrics.contains("# TYPE om_block_cache_replacements_total counter"))
            let events = logs.entries.withLock { $0 }
            #expect(events.isEmpty) // Old committed replacements do not warn.
        }
    }

    @Test(arguments: [false, true])
    func replacingInFlightEntry(lru: Bool) throws {
        try withCache { cache, diagnostics, logs in
            cache.data.withMutableUnsafeBytes {
                $0.assumingMemoryBound(to: Atomic<WordPair>.self)[0].store(.init(first: 11, second: 2), ordering: .relaxed)
            }
            let key: UInt64 = lru ? 12 : 11
            cache.set(key: key, value: Data(repeating: 4, count: 64))
            #expect(cache.get(key: key, count: 1)?.data == Data(repeating: 4, count: 64))
            let event = try #require(logs.entries.withLock { $0.first })
            #expect(event["reason"]?.description == "replaced_inflight_entry")
            #expect(event["previous_state"]?.description == "inflight")
            #expect(event["previous_timestamp_ns"]?.description == "2")
            #expect(event["published"]?.description == "true")
            #expect(event["access_age_seconds"] != nil)
            let path = lru ? "lru" : "same_key"
            let metrics = diagnostics.prometheusMetrics()
            #expect(value(metrics, "om_block_cache_inflight_replacements_total{path=\"\(path)\"}") == 1)
            for age in AtomicBlockCacheDiagnostics.Age.allCases {
                #expect(value(metrics, "om_block_cache_replacements_total{path=\"\(path)\",age=\"\(age.rawValue)\"}") == 0)
            }
        }
    }

    /// Deterministically interfere between a successful claim and publication.
    private final class InterferingBytes: ContiguousBytes {
        let cache: AtomicBlockCache<MmapFile>
        let calls = Atomic(0)

        init(cache: AtomicBlockCache<MmapFile>) { self.cache = cache }

        func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            if calls.add(1, ordering: .relaxed).oldValue == 0 {
                cache.data.withMutableUnsafeBytes {
                    $0.assumingMemoryBound(to: Atomic<WordPair>.self)[0].store(.init(first: 0, second: 0), ordering: .relaxed)
                }
            }
            return try Data(repeating: 5, count: 64).withUnsafeBytes(body)
        }
    }

    @Test(arguments: [false, true])
    func publicationConflictPreservesRetry(lru: Bool) throws {
        try withCache { cache, diagnostics, logs in
            if lru { cache.set(key: 10, value: Data(repeating: 1, count: 64)) }
            cache.ageEntriesForReplacement()
            cache.set(key: 11, value: InterferingBytes(cache: cache))
            #expect(cache.get(key: 11, count: 1)?.data == Data(repeating: 5, count: 64))
            let metrics = diagnostics.prometheusMetrics()
            #expect(value(metrics, "om_block_cache_publication_conflicts_total") == 1)
            #expect(value(metrics, "om_block_cache_write_claims_total{path=\"empty\"}") == 2)
            #expect(value(metrics, "om_block_cache_write_claims_total{path=\"lru\"}") == (lru ? 1 : 0))
            let event = try #require(logs.entries.withLock { $0.first { $0["reason"]?.description == "publication_conflict" } })
            #expect(event["published"]?.description == "false")
            #expect(event["observed_key"]?.description == "0")
            #expect(event["observed_state"]?.description == "empty")
            #expect(event["observed_timestamp_ns"]?.description == "0")
            #expect(event["claim_timestamp_ns"] != nil)
        }
    }

    @Test func agesAndRepeatedWarnings() {
        let logs = Logs()
        let diagnostics = AtomicBlockCacheDiagnostics(logger: logs.logger)
        let now: UInt = 100_000_000_000
        let claim = WordPair(first: 2, second: now)
        let ages: [(UInt, AtomicBlockCacheDiagnostics.Age)] = [
            (0, .under10ms), (9_999_998, .under10ms),
            (10_000_000, .under100ms), (99_999_998, .under100ms),
            (100_000_000, .under1s), (999_999_998, .under1s),
            (1_000_000_000, .under5s), (4_999_999_998, .under5s),
            (5_000_000_000, .older), (6_000_000_000, .older)
        ]
        for (age, expected) in ages {
            #expect(AtomicBlockCacheDiagnostics.Age(nanoseconds: age) == expected)
            diagnostics.recordWrite(previous: .init(first: 1, second: (now - age) | 1), claim: claim, slot: 3, path: .lru, claimedAt: now, published: true, observed: claim, cacheFile: "test-cache")
        }
        for bucket in AtomicBlockCacheDiagnostics.Age.allCases {
            #expect(value(diagnostics.prometheusMetrics(), "om_block_cache_replacements_total{path=\"lru\",age=\"\(bucket.rawValue)\"}") == 2)
        }
        #expect(logs.entries.withLock { $0.count } == 8)
        #expect(logs.entries.withLock { $0.first?["slot"]?.description } == "3")

        // Every qualifying write logs, even for repeated events on the same slot.
        for _ in 0..<3 {
            diagnostics.recordWrite(previous: .init(first: 1, second: now | 1), claim: claim, slot: 3, path: .sameKey, claimedAt: now, published: false, observed: .init(first: 77, second: (now + 2) | 1), cacheFile: "test-cache")
        }
        let events = logs.entries.withLock { $0 }
        #expect(events.count == 14)
        let conflicts = events.filter { $0["reason"]?.description == "publication_conflict" }
        #expect(conflicts.count == 3)
        #expect(conflicts.allSatisfy { $0["observed_key"]?.description == "77" && $0["observed_state"]?.description == "committed" && $0["observed_timestamp_ns"]?.description == String(now + 2) })
        #expect(value(diagnostics.prometheusMetrics(), "om_block_cache_publication_conflicts_total") == 3)
    }

    @Test func inflightAgeAndObservedState() throws {
        let logs = Logs()
        let diagnostics = AtomicBlockCacheDiagnostics(logger: logs.logger)
        let now: UInt = 100_000_000_000
        let claim = WordPair(first: 2, second: now)
        for age in [UInt(0), 60_000_000_000] {
            diagnostics.recordWrite(previous: .init(first: 1, second: now - age), claim: claim, slot: 3, path: .lru, claimedAt: now, published: true, observed: claim, cacheFile: "test-cache")
        }
        let events = logs.entries.withLock { $0 }
        #expect(events.count == 2)
        #expect(events.allSatisfy { $0["reason"]?.description == "replaced_inflight_entry" })
        #expect(events[0]["access_age_seconds"]?.description == "0.0")
        #expect(events[1]["access_age_seconds"]?.description == "60.0")
        diagnostics.recordWrite(previous: .init(first: 0, second: 0), claim: claim, slot: 3, path: .sameKey, claimedAt: 0, published: false, observed: .init(first: 77, second: now + 2), cacheFile: "test-cache")
        let conflict = try #require(logs.entries.withLock { $0.last })
        #expect(conflict["path"]?.description == "empty")
        #expect(conflict["previous_state"]?.description == "empty")
        #expect(conflict["access_age_seconds"] == nil)
        #expect(conflict["observed_state"]?.description == "inflight")
        #expect(conflict["observed_key"]?.description == "77")
    }

    @Test func deletionDiagnostics() throws {
        try withCache { cache, diagnostics, logs in
            // Empty and in-flight entries must not be counted as removed.
            #expect(cache.delete(key: 0, count: 1, olderThanSeconds: 0) == 0)
            cache.data.withMutableUnsafeBytes {
                $0.assumingMemoryBound(to: Atomic<WordPair>.self)[0].store(.init(first: 11, second: 2), ordering: .relaxed)
            }
            #expect(cache.delete(key: 11, count: 1, olderThanSeconds: 0) == 0)
            #expect(logs.entries.withLock { $0.isEmpty })
            #expect(AtomicBlockCacheDiagnostics.Age.allCases.allSatisfy {
                value(diagnostics.prometheusMetrics(), "om_block_cache_deletions_total{age=\"\($0.rawValue)\"}") == 0
            })

            for _ in 0..<2 {
                let now = UInt(Date().timeIntervalSince1970 * 1_000_000_000)
                cache.data.withMutableUnsafeBytes {
                    $0.assumingMemoryBound(to: Atomic<WordPair>.self)[0].store(.init(first: 11, second: (now - 1_000_000_000) | 1), ordering: .relaxed)
                }
                #expect(cache.delete(key: 11, count: 1, olderThanSeconds: 60) == 0)
                #expect(cache.delete(key: 11, count: 1, olderThanSeconds: 0) == 1)
                #expect(cache.delete(key: 11, count: 1, olderThanSeconds: 0) == 0)
            }
            let events = logs.entries.withLock { $0 }
            #expect(events.count == 2)
            #expect(events.allSatisfy { $0["reason"]?.description == "deleted_recent_entry" && $0["previous_key"]?.description == "11" && $0["previous_state"]?.description == "committed" && $0["older_than_seconds"]?.description == "0" })
            #expect(value(diagnostics.prometheusMetrics(), "om_block_cache_deletions_total{age=\"1s_5s\"}") == 2)
            let old = UInt(Date().timeIntervalSince1970 * 1_000_000_000) - 60_000_000_000
            cache.data.withMutableUnsafeBytes {
                $0.assumingMemoryBound(to: Atomic<WordPair>.self)[0].store(.init(first: 12, second: old | 1), ordering: .relaxed)
            }
            #expect(cache.delete(key: 12, count: 1, olderThanSeconds: 0) == 1)
            #expect(value(diagnostics.prometheusMetrics(), "om_block_cache_deletions_total{age=\"ge_5s\"}") == 1)
            #expect(logs.entries.withLock { $0.count } == 2)
        }
    }
}
