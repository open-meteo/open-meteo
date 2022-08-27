import Foundation


public extension Double {
    func round(digits: Int) -> Double {
        let mut = pow(10, Double(digits))
        return (self * mut).rounded() / mut
    }
}

public extension Float {
    var degreesToRadians: Float {
        return self * .pi / 180
    }
    
    var radiansToDegrees: Float {
        return self * 180 / .pi
    }
}


extension Int {
    /// Integer division, but round up instead of floor
    func divideRoundedUp(divisor: Int) -> Int {
        let rem = self % divisor
        return rem == 0 ? self / divisor : self / divisor + 1
    }
    
    func zeroPadded(len: Int) -> String {
        return String(format: "%0\(len)d", self)
    }
}

extension Range where Element == Int {
    /// Return the intersect position between 2 ranges
    public func intersect(fileTime: Range<Int>) -> (file: CountableRange<Int>, array: CountableRange<Int>)? {
        let fileLower = fileTime.lowerBound
        let fileUpper = fileTime.upperBound
        let arrayLower = self.lowerBound
        let arrayUpper = self.upperBound

        let arrayStart = Swift.max(0, fileLower - arrayLower)
        let arrayEnd = Swift.min(fileUpper - arrayLower, arrayUpper - arrayLower)
        
        if arrayStart >= arrayEnd {
            return nil
        }
        
        let array = arrayStart ..< arrayEnd
        if array.count == 0 {
            return nil
        }
        
        let fileEnd = Swift.min(arrayUpper - fileLower, fileUpper - fileLower)
        let fileStart = fileEnd - array.count
        let file = fileStart ..< fileEnd
        assert(file.count == array.count, "Offsets missmatch file=\(file.count), array=\(array.count)")
        return (file, array)
    }
    
    @inlinable public func add(_ offset: Int) -> Range<Int> {
        return lowerBound + offset ..< upperBound + offset
    }
}

extension Range where Bound == Float {
    /// Interpolate between lower and upper bound
    func interpolated(atFraction at: Float) -> Float {
        let value = lowerBound + (upperBound - lowerBound) * at
        return Swift.min(Swift.max(value, lowerBound), upperBound)
    }
    
    /// Return the fraction of wheever the value is. limited to to 0...1
    func fraction(of value: Float) -> Float {
        let limited = Swift.min(Swift.max(value, lowerBound), upperBound)
        return (limited - lowerBound) / (upperBound - lowerBound)
    }
}


public extension RandomAccessCollection where Element == Float, Index == Int {
    /// Calculate linear interpolation. Index and fraction are kept apart, because of floating point inprecisions
    @inlinable func interpolateLinear(_ i: Int, _ fraction: Float) -> Float {
        assert(self.count != 0)
        assert(0 <= fraction && fraction <= 1)
        if i < startIndex {
            return self.first!
        }
        if i >= endIndex - 1 {
            return self.last!
        }
        let leftVal = self[i]
        if fraction < 0.001 {
            return leftVal
        }
        let rightVal = self[i + 1]
        if fraction > 0.999 {
            return rightVal
        }
        return leftVal * (1-fraction) + rightVal * fraction
    }
}
