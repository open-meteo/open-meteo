import Foundation

/// Sequence, but with 2 dimensions
struct Sequence2D<S1: Sequence, S2: Sequence> {
    let y: S1
    let x: S2
    
    init(_ y: S1, _ x: S2) {
        self.y = y
        self.x = x
    }
}

extension Sequence2D: Sequence {
    func makeIterator() -> Iterator2D<S1, S2> {
        return Iterator2D(y, x)
    }
}

extension Sequence {
    /// Iterate over 2 dimensions. The second sequence is iterated self.count times
    func iterate2D<S: Sequence>(over other: S) -> Sequence2D<Self, S> {
        return Sequence2D(self, other)
    }
}

/*
 Iterator over 2 sequences as 2 dimensions Y and X. It will iterate y-times of x.
 */
struct Iterator2D<Y: Sequence, X: Sequence>: IteratorProtocol {
    var yIterator: Y.Iterator
    var y: Y.Element?
    var xIterator: X.Iterator
    let xSequence: X
    
    init(_ y: Y, _ x: X) {
        self.yIterator = y.makeIterator()
        self.y = yIterator.next()
        self.xIterator = x.makeIterator()
        self.xSequence = x
    }
    
    mutating func next() -> (y: Y.Element, x: X.Element)? {
        guard let y else {
            return nil
        }
        guard let x = xIterator.next() else {
            // xIterator finished, get next y and a new xIterator
            guard let yNext = yIterator.next() else {
                // end of itertion
                self.y = nil
                return nil
            }
            self.y = yNext
            self.xIterator = xSequence.makeIterator()
            guard let x = xIterator.next() else {
                self.y = nil
                return nil
            }
            return (yNext, x)
        }
        return (y, x)
    }
}
