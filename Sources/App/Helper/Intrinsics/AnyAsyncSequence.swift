/**
 Type erase AnySequence
 See https://forums.swift.org/t/anyasyncsequence/50828/4
 */
struct AnyAsyncSequence<Element>: AsyncSequence {
    typealias AsyncIterator = AnyAsyncIterator<Element>
    typealias Element = Element

    let _makeAsyncIterator: () -> AnyAsyncIterator<Element>

    @available(iOS 15.0, *)
    struct AnyAsyncIterator<Element2>: AsyncIteratorProtocol {
        typealias Element = Element2

        private let _next: () async throws -> Element2?

        init<I: AsyncIteratorProtocol>(itr: I) where I.Element == Element2 {
            var itr = itr
            self._next = {
                try await itr.next()
            }
        }

        mutating func next() async throws -> Element2? {
            return try await _next()
        }
    }

    init<S: AsyncSequence>(seq: S) where S.Element == Element {
        _makeAsyncIterator = {
            AnyAsyncIterator(itr: seq.makeAsyncIterator())
        }
    }

    func makeAsyncIterator() -> AnyAsyncIterator<Element> {
        return _makeAsyncIterator()
    }
}

extension AsyncSequence {
    func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
        AnyAsyncSequence(seq: self)
    }
}
