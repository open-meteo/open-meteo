import Synchronization

extension Atomic where Value == Float {
    /// Atomically adds a value using relaxed memory ordering and returns the updated value.
    @discardableResult
    func add(_ value: Float) -> Float {
        var previous = load(ordering: .relaxed)
        while true {
            let updated = previous + value
            let result = compareExchange(expected: previous, desired: updated, ordering: .relaxed)
            if result.exchanged { return updated }
            previous = result.original
        }
    }
}
