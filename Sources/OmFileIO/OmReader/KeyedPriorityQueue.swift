/// A min-heap with stable keys for O(log n) removal and priority changes.
/// Equal priorities have no guaranteed ordering.
/// Uses O(n) storage. Complexity assumes constant-time hashing and comparison,
/// average-case dictionary access, and uniquely owned storage. Mutating a copy
/// can incur an additional O(n) copy-on-write cost.
struct KeyedPriorityQueue<Key: Hashable, Priority: Comparable, Value> {
    private struct Entry {
        let key: Key
        var priority: Priority
        let value: Value
    }

    private var entries: [Entry] = []
    private var indices: [Key: Int] = [:]

    /// - Complexity: O(1).
    var count: Int { entries.count }

    /// - Complexity: O(1) on average.
    func priority(for key: Key) -> Priority? {
        indices[key].map { entries[$0].priority }
    }

    /// - Complexity: O(1) on average.
    func value(for key: Key) -> Value? {
        indices[key].map { entries[$0].value }
    }

    /// - Complexity: O(log n) amortized; storage growth can take O(n).
    mutating func insert(key: Key, priority: Priority, value: Value) {
        precondition(indices[key] == nil, "Heap keys must be unique")
        entries.append(Entry(key: key, priority: priority, value: value))
        siftUp(from: entries.count - 1)
    }

    /// Advances an existing entry only when the new priority is lower, using one key lookup.
    /// - Complexity: O(log n) on average; O(1) if absent or not decreased.
    mutating func decreasePriority(for key: Key, to priority: Priority) {
        guard let index = indices[key], priority < entries[index].priority else { return }
        entries[index].priority = priority
        siftUp(from: index)
    }

    /// - Complexity: O(log n) on average; O(1) if absent or unchanged.
    mutating func updatePriority(for key: Key, to priority: Priority) {
        guard let index = indices[key] else { return }
        let previous = entries[index].priority
        entries[index].priority = priority
        if priority < previous {
            siftUp(from: index)
        } else if previous < priority {
            siftDown(from: index)
        }
    }

    /// - Complexity: O(log n) on average; O(1) if empty.
    mutating func popMin() -> Value? {
        guard !entries.isEmpty else { return nil }
        // The minimum is always at the root; no key-to-index lookup is needed.
        return remove(at: 0)
    }

    /// - Complexity: O(log n) on average; O(1) if absent.
    @discardableResult
    mutating func remove(key: Key) -> Value? {
        guard let index = indices[key] else { return nil }
        return remove(at: index)
    }

    /// - Complexity: O(log n) on average; O(1) when removing the last entry.
    private mutating func remove(at index: Int) -> Value {
        let removed = entries[index]
        let replacement = entries.removeLast()
        indices.removeValue(forKey: removed.key)
        if index < entries.count {
            // Fill the gap directly; the deleted entry needs no temporary index update.
            entries[index] = replacement
            // The last entry can belong above or below the removed entry's position.
            if index > 0, replacement.priority < entries[(index - 1) / 2].priority {
                siftUp(from: index)
            } else {
                siftDown(from: index)
            }
        }
        return removed.value
    }

    /// - Complexity: O(log n) on average, moving at most one entry per level.
    private mutating func siftUp(from start: Int) {
        let entry = entries[start]
        var index = start
        // Move parents into the gap, updating only the entry moved at each level.
        while index > 0 {
            let parent = (index - 1) / 2
            guard entry.priority < entries[parent].priority else { break }
            entries[index] = entries[parent]
            indices[entries[index].key] = index
            index = parent
        }
        entries[index] = entry
        indices[entry.key] = index
    }

    /// - Complexity: O(log n) on average, moving at most one entry per level.
    private mutating func siftDown(from start: Int) {
        let entry = entries[start]
        var index = start
        // Move the smaller child up until the held entry fits, then place it once.
        while index * 2 + 1 < entries.count {
            var child = index * 2 + 1
            let right = child + 1
            if right < entries.count, entries[right].priority < entries[child].priority {
                child = right
            }
            guard entries[child].priority < entry.priority else { break }
            entries[index] = entries[child]
            indices[entries[index].key] = index
            index = child
        }
        entries[index] = entry
        indices[entry.key] = index
    }
}
