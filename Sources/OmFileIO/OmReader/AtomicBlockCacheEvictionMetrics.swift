import Synchronization

/// Per-cache process counters. Copies of a cache share these counters.
final class AtomicBlockCacheEvictionMetrics: Sendable {
    static let windows: [(name: String, seconds: UInt)] = [
        ("1m", 60), ("5m", 300), ("15m", 900), ("30m", 1800),
        ("60m", 3600), ("3h", 10800), ("24h", 86400)
    ]

    private final class Counter: Sendable {
        let value = Atomic(0)
    }
    // Exclusive age buckets keep each eviction to one atomic increment.
    private let buckets = (0...windows.count).map { _ in Counter() }

    func record(evicted: WordPair, replacementKey: UInt64, now: UInt) {
        // Empty slots, unfinished writes and same-key updates are not evictions.
        guard evicted.second & 1 == 1, evicted.first != replacementKey else { return }
        let accessedAt = evicted.second & ~UInt(1)
        let age = now >= accessedAt ? now - accessedAt : 0
        let bucket = Self.windows.firstIndex { age <= $0.seconds * 1_000_000_000 } ?? Self.windows.count
        buckets[bucket].value.add(1, ordering: .relaxed)
    }

    var snapshot: AtomicBlockCacheEvictionStatistics {
        let counts = buckets.map { $0.value.load(ordering: .relaxed) }
        var cumulative = 0
        let recent = Self.windows.enumerated().map { index, window in
            cumulative += counts[index]
            return (window: window.name, count: cumulative)
        }
        return .init(total: cumulative + counts.last!, accessedWithin: recent)
    }
}

public struct AtomicBlockCacheEvictionStatistics: Sendable {
    public let total: Int
    /// Cumulative counters classified by access age at eviction, not rolling totals.
    public let accessedWithin: [(window: String, count: Int)]

    public static let zero = AtomicBlockCacheEvictionStatistics(
        total: 0, accessedWithin: AtomicBlockCacheEvictionMetrics.windows.map { ($0.name, 0) }
    )
}
