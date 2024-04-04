import Foundation

/// Range, but with 2 dimensions
struct Range2D<Element1: Comparable, Element2: Comparable> {
    let y: Range<Element1>
    let x: Range<Element2>
    
    init(_ y: Range<Element1>, _ x: Range<Element2>) {
        self.y = y
        self.x = x
    }
}

extension Range2D: Sequence where Element1: Strideable, Element2: Strideable {
    func makeIterator() -> Iterator {
        return Iterator(range: self)
    }
    
    struct Iterator: IteratorProtocol {
        var y: Element1
        var x: Element2
        let range: Range2D
        
        init(range: Range2D) {
            self.y = range.y.lowerBound
            self.x = range.x.lowerBound
            self.range = range
        }
        
        mutating func next() -> (y: Element1, x: Element2)? {
            let xNext = x.advanced(by: 1)
            if xNext == range.x.upperBound {
                let yNext = y.advanced(by: 1)
                if yNext == range.y.upperBound {
                    return nil
                }
                let currentX = x
                let currentY = y
                x = range.x.lowerBound
                y = yNext
                return (currentY, currentX)
            }
            let currentX = x
            x = xNext
            return (y, currentX)
        }
    }
}
