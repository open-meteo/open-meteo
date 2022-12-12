import Foundation

extension UnsafeBufferPointer {
    func toUnsafeRawBufferPointer() -> UnsafeRawBufferPointer {
        return UnsafeRawBufferPointer(start: self.baseAddress, count: count * MemoryLayout<Element>.stride)
    }
}

extension UnsafePointer {
    public func assumingMemoryBound<T>(to: T.Type, capacity: Int) -> UnsafeBufferPointer<T> {
        let raw = UnsafeRawPointer(self)
        return UnsafeBufferPointer(start: raw.assumingMemoryBound(to: to), count: capacity)
    }
}

extension UnsafeMutablePointer {
    public func assumingMemoryBound<T>(to: T.Type, capacity: Int) -> UnsafeMutableBufferPointer<T> {
        let raw = UnsafeMutableRawPointer(self)
        return UnsafeMutableBufferPointer(start: raw.assumingMemoryBound(to: to), count: capacity)
    }
}

public extension Int {
    func ceil(to: Int) -> Int {
        guard to != 0 else {
            return self
        }
        let mod = self % to
        guard mod != 0 else {
            return self
        }
        return self - mod + to
    }
    
    func floor(to: Int) -> Int {
        guard to != 0 else {
            return self
        }
        return self - self % to
    }
    
    /// Integer division, but round up instead of floor
    func divideRoundedUp(divisor: Int) -> Int {
        let rem = self % divisor
        return rem == 0 ? self / divisor : self / divisor + 1
    }
    
}

/// For encoding: compression lib read and write more data to buffers https://github.com/powturbo/TurboPFor-Integer-Compression/issues/59
public func P4NENC256_BOUND(n: Int, bytesPerElement: Int) -> Int {
    return ((n + 255) / 256 + (n + 32)) * bytesPerElement
}
/// For Decoding: compression lib read and write more data to buffers https://github.com/powturbo/TurboPFor-Integer-Compression/issues/59
public func P4NDEC256_BOUND(n: Int, bytesPerElement: Int) -> Int {
    return n * bytesPerElement + 32*4
}

extension Range where Bound == Int {
    func add(_ val: Int) -> Range<Int> {
        return lowerBound + val ..< upperBound + val
    }
    func substract(_ val: Int) -> Range<Int> {
        return lowerBound - val ..< upperBound - val
    }
}
