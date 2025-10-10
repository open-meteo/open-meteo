// Wraps an AsyncSequence and executes a finalizer when the sequence finishes.
/*struct AsyncSequenceWithFinalizer<Base: AsyncSequence>: AsyncSequence, Sendable where Base: Sendable {
    typealias Element = Base.Element
    typealias AsyncIterator = Iterator

    let base: Base
    let finalizer: @Sendable () async throws -> Void

    init(base: Base, finalizer: @escaping @Sendable () async throws -> Void) {
        self.base = base
        self.finalizer = finalizer
    }

    struct Iterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        let finalizer: @Sendable () async throws -> Void

        mutating func next() async throws -> Base.Element? {
            if let element = try await baseIterator.next() {
                return element
            } else {
                try await finalizer()
                return nil
            }
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(baseIterator: base.makeAsyncIterator(), finalizer: finalizer)
    }
}

extension AsyncSequence where Self: Sendable {
    // Wraps an AsyncSequence and executes a finalizer when the sequence finishes.
    func finalizer(_ finalizer: @escaping @Sendable () async throws -> Void) -> AsyncSequenceWithFinalizer<Self> {
        return AsyncSequenceWithFinalizer(base: self, finalizer: finalizer)
    }
}
*/
