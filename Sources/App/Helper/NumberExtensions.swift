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
    
    /// Performs mathematical module keeping the result positive
    @inlinable func moduloPositive(_ devisor: Int) -> Int {
        return((self % devisor) + devisor) % devisor
    }
    
    /// Devide the current number using integer devision, and report the reaming part as a fraction
    @inlinable func moduloFraction(_ devisor: Int) -> (quotient: Int, fraction: Float) {
        let fraction = Float(self.moduloPositive(devisor)) / Float(devisor)
        return (self / devisor, fraction)
    }
}

extension Range where Element == Int {
    /// The lower bound uses a regular division, the upper bound uses divideRoundedUp
    func divideRoundedUp(divisor: Int) -> Range<Int> {
        return lowerBound / divisor ..< upperBound.divideRoundedUp(divisor: divisor)
    }
    
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
    
    @inlinable public func multiply(_ by: Int) -> Range<Int> {
        return lowerBound * by ..< upperBound * by
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
    
    /// Assume data is organised in a ring. E,g, the right hand side border will interpolate with the left side.
    @inlinable func interpolateLinearRing(_ i: Int, _ fraction: Float) -> Float {
        assert(self.count != 0)
        assert(0 <= fraction && fraction <= 1)
        let leftVal = self[i % count]
        if fraction < 0.001 {
            return leftVal
        }
        let rightVal = self[(i + 1) % count]
        if fraction > 0.999 {
            return rightVal
        }
        return leftVal * (1-fraction) + rightVal * fraction
    }
    
    /// Assume data is organised in a ring. E,g, the right hand side border will interpolate with the left side.
    @inlinable func interpolateHermiteRing(_ i: Int, _ fraction: Float) -> Float {
        assert(self.count != 0)
        assert(0 <= fraction && fraction <= 1)
        
        let A = self[(i - 1 + count) % count]
        let B = self[i % count]
        let C = self[(i+1) % count]
        let D = self[(i+2) % count]
        
        let a = -A/2.0 + (3.0*B)/2.0 - (3.0*C)/2.0 + D/2.0
        let b = A - (5.0*B)/2.0 + 2.0*C - D / 2.0
        let c = -A/2.0 + C/2.0
        let d = B
        return (a*fraction*fraction*fraction + b*fraction*fraction + c*fraction + d)
    }
}
