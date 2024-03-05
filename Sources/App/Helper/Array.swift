import Foundation

extension Sequence where Element == Float {
    func mean() -> Float {
        var sum: Float = 0
        var count: Int = 0
        for value in self {
            sum += value
            count += 1
        }
        return count == 0 ? .nan : sum / Float(count)
    }
}

extension Array where Element == Float {
    func max(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].max() ?? .nan
        }
    }
    func min(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].min() ?? .nan
        }
    }
    func sum(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].reduce(0, +)
        }
    }
    func sum(by: Float) -> [Float] {
        return stride(from: Float(0), through: Float(count)-by, by: by).map { (i: Float) -> Float in
            return self[Int(roundf(i))..<Int(roundf(i+by))].reduce(0, +)
        }
    }
    func mean(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].reduce(0, +) / Float(by)
        }
    }
    func meanBackwards(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            if i == 0 {
                return .nan
            }
            return self[i-by..<i].reduce(0, +) / Float(by)
        }
    }
    
    mutating func rounded(digits: Int) {
        let roundExponent = powf(10, Float(digits))
        for i in indices {
            self[i] = Foundation.round(self[i] * roundExponent) / roundExponent
        }
    }
    
    func round(digits: Int) -> [Float] {
        let roundExponent = powf(10, Float(digits))
        return map {
            return Foundation.round($0 * roundExponent) / roundExponent
        }
    }
    
    func containsNaN() -> Bool {
        return first(where: {$0.isNaN}) != nil
    }
    
    mutating func fillWithNaNs() {
        for i in self.indices {
            self[i] = .nan
        }
    }
    
    func onlyNaN() -> Bool {
        return first(where: {!$0.isNaN}) == nil
    }
}

extension Array where Element == Float {
    /// Shift longitudes by 180° and flip south.north
    mutating func shift180LongitudeAndFlipLatitude(nt: Int, ny: Int, nx: Int) {
        precondition(nt * ny * nx == count)
        self.withUnsafeMutableBufferPointer { data in
            /// Data starts eastwards at 0°E... rotate to start at -180°E
            for t in 0..<nt {
                for y in 0..<ny {
                    for x in 0..<nx/2 {
                        let offset = t*nx*ny + y*nx
                        let val = data[offset + x]
                        data[offset + x] = data[offset + x + nx/2]
                        data[offset + x + nx/2] = val
                    }
                }
                /// Also flip south / north
                for y in 0..<ny/2 {
                    for x in 0..<nx {
                        let val = data[t*nx*ny + y*nx + x]
                        data[t*nx*ny + y*nx + x] = data[t*nx*ny + (ny-1-y)*nx + x]
                        data[t*nx*ny + (ny-1-y)*nx + x] = val
                    }
                }
            }
        }
    }
    
    /// Shift longitudes by 180°
    mutating func shift180Longitude(nt: Int, ny: Int, nx: Int) {
        precondition(nt * ny * nx == count)
        self.withUnsafeMutableBufferPointer { data in
            /// Data starts eastwards at 0°E... rotate to start at -180°E
            for t in 0..<nt {
                for y in 0..<ny {
                    for x in 0..<nx/2 {
                        let offset = t*nx*ny + y*nx
                        let val = data[offset + x]
                        data[offset + x] = data[offset + x + nx/2]
                        data[offset + x + nx/2] = val
                    }
                }
            }
        }
    }
    
    /// Flip south.north
    mutating func flipLatitude(nt: Int, ny: Int, nx: Int) {
        precondition(nt * ny * nx == count)
        self.withUnsafeMutableBufferPointer { data in
            for t in 0..<nt {
                /// Also flip south / north
                for y in 0..<ny/2 {
                    for x in 0..<nx {
                        let val = data[t*nx*ny + y*nx + x]
                        data[t*nx*ny + y*nx + x] = data[t*nx*ny + (ny-1-y)*nx + x]
                        data[t*nx*ny + (ny-1-y)*nx + x] = val
                    }
                }
            }
        }
    }
    
    mutating func multiplyAdd(multiply: Float, add: Float) {
        self.withUnsafeMutableBufferPointer { data in
            for i in 0..<data.count {
                data[i] = fma(data[i], multiply, add)
            }
        }
    }

    /// Perform a simple delta encoding. Leave the first value as seed.
    mutating func deltaEncode() {
        if count <= 1 {
            return
        }
        for x in (1..<count).reversed() {
            if self[x-1].isNaN {
                continue
            }
            self[x] = self[x-1] - self[x]
        }
    }
    
    /// Undo delta coding
    mutating func deltaDecode() {
        if count <= 1 {
            return
        }
        for x in 1..<count {
            if self[x-1].isNaN {
                continue
            }
            self[x] = self[x-1] - self[x]
        }
    }
    
    /// Ensure data is greater equals than
    mutating func greater(than value: Float) {
        for x in 0..<count {
            self[x] = Swift.max(self[x], value)
        }
    }
}

