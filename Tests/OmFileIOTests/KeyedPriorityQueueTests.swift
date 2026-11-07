@testable import OmFileIO
import Testing

struct KeyedPriorityQueueTests {
    @Test func decreasePriorityOnlyPromotesExistingEntries() {
        var heap = KeyedPriorityQueue<Int, Int, Int>()
        for key in 0..<8 { heap.insert(key: key, priority: key, value: key) }
        heap.decreasePriority(for: 7, to: -1)
        heap.decreasePriority(for: 7, to: -1)
        heap.decreasePriority(for: 7, to: 100)
        heap.decreasePriority(for: 99, to: -2)
        #expect(heap.count == 8)
        #expect(heap.priority(for: 7) == -1)
        #expect(heap.priority(for: 99) == nil)
        // Promotion crosses several levels; subsequent removals also verify the index map.
        #expect(heap.popMin() == 7)
        #expect(heap.remove(key: 3) == 3)
        for key in [0, 1, 2, 4, 5, 6] { #expect(heap.popMin() == key) }
        #expect(heap.popMin() == nil)
    }

    @Test func deepHeapPreservesKeysThroughPriorityChangesAndRemoval() throws {
        var heap = KeyedPriorityQueue<Int, Int, Int>()
        var priorities: [Int: Int] = [:]
        for key in 0..<1024 {
            let priority = (key * 7919) % 1024
            heap.insert(key: key, priority: priority, value: key)
            priorities[key] = priority
        }
        // Move entries several levels in both directions, then remove arbitrary positions.
        for key in stride(from: 0, to: 1024, by: 7) {
            heap.updatePriority(for: key, to: -key)
            priorities[key] = -key
        }
        for key in stride(from: 0, to: 1024, by: 11) {
            heap.updatePriority(for: key, to: key + 2048)
            priorities[key] = key + 2048
        }
        for key in stride(from: 0, to: 1024, by: 5) {
            #expect(heap.remove(key: key) == key)
            priorities.removeValue(forKey: key)
            #expect(heap.value(for: key) == nil)
        }
        for (key, priority) in priorities {
            #expect(heap.priority(for: key) == priority)
            #expect(heap.value(for: key) == key)
        }
        for priority in priorities.values.sorted() {
            let popped = heap.popMin()
            let key = try #require(popped)
            #expect(priorities.removeValue(forKey: key) == priority)
            #expect(heap.priority(for: key) == nil)
            #expect(heap.count == priorities.count)
        }
        #expect(heap.popMin() == nil)
        heap.insert(key: 1, priority: 1, value: 1)
        #expect(heap.remove(key: 1) == 1)
        #expect(heap.count == 0)
        #expect(heap.value(for: 1) == nil)
    }

    @Test func updatesAndRemovalsMatchReferenceQueue() {
        var heap = KeyedPriorityQueue<Int, Int, Int>()
        var priorities: [Int: Int] = [:]
        var random: UInt64 = 42
        func next(_ limit: Int) -> Int {
            random = random &* 6364136223846793005 &+ 1
            return Int((random >> 32) % UInt64(limit))
        }

        // Exercise changing indices, both priority directions, ties, and key reuse.
        for _ in 0..<10_000 {
            let key = next(100)
            switch next(4) {
            case 0:
                let priority = next(50)
                if priorities[key] == nil {
                    heap.insert(key: key, priority: priority, value: key)
                } else {
                    heap.updatePriority(for: key, to: priority)
                }
                priorities[key] = priority
            case 1:
                let priority = next(50)
                heap.updatePriority(for: key, to: priority)
                if priorities[key] != nil { priorities[key] = priority }
            case 2:
                let expected = priorities.removeValue(forKey: key)
                #expect(heap.remove(key: key) == (expected == nil ? nil : key))
            default:
                let minimum = priorities.values.min()
                if let popped = heap.popMin() {
                    #expect(priorities.removeValue(forKey: popped) == minimum)
                } else {
                    #expect(priorities.isEmpty)
                }
            }
            #expect(heap.count == priorities.count)
            // Check every key after every operation without emitting two million assertions.
            let mismatch = (0..<100).first { key in
                heap.priority(for: key) != priorities[key]
                    || heap.value(for: key) != (priorities[key] == nil ? nil : key)
            }
            #expect(mismatch == nil, "Incorrect lookup for key \(String(describing: mismatch))")
        }
        while !priorities.isEmpty {
            let minimum = priorities.values.min()
            guard let key = heap.popMin() else {
                Issue.record("Heap lost an entry")
                return
            }
            #expect(priorities.removeValue(forKey: key) == minimum)
        }
        #expect(heap.count == 0)
        #expect(heap.popMin() == nil)
        #expect(heap.remove(key: 0) == nil)
    }
}
