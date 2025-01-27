import Foundation


struct Array3D {
    var data: [Float]
    
    /// slowest
    let dim0: Int
    let dim1: Int
    /// Fastest dim
    let dim2: Int
    
    var count: Int {
        return dim0 * dim1 * dim2
    }
    
    public init(data: [Float], dim0: Int, dim1: Int, dim2: Int) {
        if (data.count != dim0 * dim1 * dim2) {
            fatalError("Wrong Array3D dimensions. dim0=\(dim0) dim1=\(dim1) dim2=\(dim2) count=\(data.count)")
        }
        self.data = data
        self.dim0 = dim0
        self.dim1 = dim1
        self.dim2 = dim2
    }
    
    public init(repeating: Float, dim0: Int, dim1: Int, dim2: Int) {
        self.data = [Float](repeating: repeating, count: dim0 * dim1 * dim2)
        self.dim0 = dim0
        self.dim1 = dim1
        self.dim2 = dim2
    }
    
    @inlinable subscript(d0: Int, d1: Int, d2: Int) -> Float {
        get {
            assert(d0 < dim0, "dim0 subscript invalid: \(d0) with dim0=\(dim0)")
            assert(d1 < dim1, "dim1 subscript invalid: \(d1) with dim1=\(dim1)")
            assert(d2 < dim2, "dim2 subscript invalid: \(d2) with dim2=\(dim2)")
            return data[d0 * dim1 * dim2 + d1 * dim2 + d2]
        }
        set {
            assert(d0 < dim0, "dim0 subscript invalid: \(d0) with dim0=\(dim0)")
            assert(d1 < dim1, "dim1 subscript invalid: \(d1) with dim1=\(dim1)")
            assert(d2 < dim2, "dim2 subscript invalid: \(d2) with dim2=\(dim2)")
            data[d0 * dim1 * dim2 + d1 * dim2 + d2] = newValue
        }
    }
}

public struct Array3DFastTime {
    public var data: [Float]
    public let nLocations: Int
    public let nLevel: Int
    public let nTime: Int
    
    public init(data: [Float], nLocations: Int, nLevel: Int, nTime: Int) {
        if (data.count != nLocations * nTime * nLevel) {
            fatalError("Wrong Array2DFastTime dimensions. nLocations=\(nLocations) nLevel=\(nLevel) nTime=\(nTime) count=\(data.count)")
        }
        self.data = data
        self.nLocations = nLocations
        self.nLevel = nLevel
        self.nTime = nTime
    }
    
    public init(nLocations: Int, nLevel: Int, nTime: Int) {
        self.data = .init(repeating: .nan, count: nLocations * nTime * nLevel)
        self.nLocations = nLocations
        self.nTime = nTime
        self.nLevel = nLevel
    }
    
    @inlinable subscript(location: Int, level: Int, time: Int) -> Float {
        get {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time < nTime, "time subscript invalid: \(time) with nTime=\(nTime)")
            return data[location * nTime * nLevel + level * nTime + time]
        }
        set {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time < nTime, "time subscript invalid: \(time) with nTime=\(nTime)")
            data[location * nTime * nLevel + level * nTime + time] = newValue
        }
    }
    
    @inlinable subscript(location: Int, level: Int, time: Range<Int>) -> ArraySlice<Float> {
        get {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time.upperBound <= nTime, "time subscript invalid: \(time) with nTime=\(nTime)")
            return data[time.add(location * nTime * nLevel + level * nTime)]
        }
        set {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time.upperBound <= nTime, "time subscript invalid: \(time) with nTime=\(nTime)")
            data[time.add(location * nTime * nLevel + level * nTime)] = newValue
        }
    }
    
    /// One spatial field into time-series array
    @inlinable subscript(location: Range<Int>, level: Int, time: Int) -> [Float] {
        get {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            var out = [Float]()
            out.reserveCapacity(location.count)
            for loc in location {
                out.append(self[loc, level, time])
            }
            return out
        }
        set {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            precondition(newValue.count == location.count, "Array and location count do not match")
            for (loc, value) in zip(location, newValue) {
                data[loc * nTime * nLevel + level * nTime + time] = value
            }
        }
    }
    
    @inlinable subscript(location: Range<Int>, level: Int, time: Range<Int>) -> ArraySlice<Float> {
        get {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time.upperBound <= nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            var out = [Float]()
            out.reserveCapacity(location.count * time.count)
            for loc in location {
                out.append(contentsOf: self[loc, level, time])
            }
            return ArraySlice(out)
        }
        set {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time.upperBound <= nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            precondition(newValue.count == location.count, "Array and location count do not match")
            for loc in location {
                data[time.add(loc * nTime * nLevel + level * nTime)] = newValue[(time.count * loc ..< time.count * (loc+1)).add(newValue.startIndex)]
            }
        }
    }
    
    /// One spatial field into time-series array
    @inlinable subscript(location: Range<Int>, level: Int, time: Int) -> ArraySlice<Float> {
        get {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            var out = [Float]()
            out.reserveCapacity(location.count)
            for loc in location {
                out.append(self[loc, level, time])
            }
            return ArraySlice(out)
        }
        set {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(level < nLevel, "level subscript invalid: \(level) with nLevel=\(nLevel)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            precondition(newValue.count == location.count, "Array and location count do not match")
            for (loc, value) in zip(location, newValue) {
                data[loc * nTime * nLevel + level * nTime + time] = value
            }
        }
    }
}
