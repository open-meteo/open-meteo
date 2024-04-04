import Foundation

/// Range, but with 2 dimensions
struct Range2D {
    let y: Range<Int>
    let x: Range<Int>
    
    init(_ y: Range<Int>, _ x: Range<Int>) {
        self.y = y
        self.x = x
    }
}

extension Range2D: Sequence {
    func makeIterator() -> Iterator2D<Range<Int>, Range<Int>> {
        return Iterator2D(y, x)
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
