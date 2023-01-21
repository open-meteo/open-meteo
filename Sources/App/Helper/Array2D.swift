import Foundation
import SwiftNetCDF


struct Array2D {
    var data: [Float]
    let nx: Int
    let ny: Int
    
    var count: Int {
        return nx * ny
    }
    
    func writeNetcdf(filename: String) throws {
        let file = try NetCDF.create(path: filename, overwriteExisting: true)
        try file.setAttribute("TITLE", "My data set")
        let dimensions = [
            try file.createDimension(name: "LAT", length: ny),
            try file.createDimension(name: "LON", length: nx)
        ]
        var variable = try file.createVariable(name: "data", type: Float.self, dimensions: dimensions)
        try variable.write(data)
    }
    
    mutating func shift180LongitudeAndFlipLatitude() {
        data.shift180LongitudeAndFlipLatitude(nt: 1, ny: ny, nx: nx)
    }
    
    mutating func flipLatitude() {
        data.flipLatitude(nt: 1, ny: ny, nx: nx)
    }
}

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

struct Array2DFastSpace {
    var data: [Float]
    let nLocations: Int
    let nTime: Int
    
    public init(data: [Float], nLocations: Int, nTime: Int) {
        if (data.count != nLocations * nTime) {
            fatalError("Wrong Array2DFastTime dimensions. nLocations=\(nLocations) nTime=\(nTime) count=\(data.count)")
        }
        self.data = data
        self.nLocations = nLocations
        self.nTime = nTime
    }
    
    public init(nLocations: Int, nTime: Int) {
        self.data = .init(repeating: .nan, count: nLocations * nTime)
        self.nLocations = nLocations
        self.nTime = nTime
    }

    func writeNetcdf(filename: String, nx: Int, ny: Int) throws {
        let file = try NetCDF.create(path: filename, overwriteExisting: true)

        try file.setAttribute("TITLE", "My data set")

        let dimensions = [
            try file.createDimension(name: "TIME", length: nTime),
            try file.createDimension(name: "LAT", length: ny),
            try file.createDimension(name: "LON", length: nx)
        ]

        var variable = try file.createVariable(name: "MyData", type: Float.self, dimensions: dimensions)
        try variable.write(data)
    }
    
    @inlinable subscript(time: Int, location: Int) -> Float {
        get {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            return data[time * nLocations + location]
        }
        set {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            data[time * nLocations + location] = newValue
        }
    }
    
    @inlinable subscript(time: Int, location: Range<Int>) -> ArraySlice<Float> {
        get {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            return data[location.add(time * nLocations)]
        }
        set {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            data[location.add(time * nLocations)] = newValue
        }
    }
    
    /// Transpose to fast time
    func transpose() -> Array2DFastTime {
        precondition(data.count == nLocations * nTime)
        return data.withUnsafeBufferPointer { data in
            let out = [Float](unsafeUninitializedCapacity: data.count) { buffer, initializedCount in
                for l in 0..<nLocations {
                    for t in 0..<nTime {
                        buffer[l * nTime + t] = data[t * nLocations + l]
                    }
                }
                initializedCount += data.count
            }
            return Array2DFastTime(data: out, nLocations: nLocations, nTime: nTime)
        }
    }
}


/*extension Array {
    /// Calculate start positions for cycles
    static func transposeCalculateCycles(rows: Int, cols: Int) -> [Int] {
        var cycles = [Int]()
        let size = rows * cols - 1
        var b = [Bool](repeating: false, count: rows*cols)
        b[0] = true
        b[size] = true
        var i = 1
        while i < size {
            let cycleBegin = i
            cycles.append(i)
            repeat {
                b[i] = true
                i = (i*rows)%size
            } while i != cycleBegin
     
            i = 1
            while i < size && b[i] == true {
                i += 1
            }
        }
        return cycles
    }
    
    /// Perform inplace transposition using `following cycles algorithm`. This is 10 slower than double buffer transpose, exclusing the cycle calculation
    /// See: https://en.wikipedia.org/wiki/In-place_matrix_transposition
    /// See: https://www.geeksforgeeks.org/inplace-m-x-n-size-matrix-transpose/
    mutating func transpose(rows: Int, cols: Int, cycles: [Int]? = nil) {
        precondition(count == rows * cols)
        let cycles = cycles ?? Self.transposeCalculateCycles(rows: rows, cols: cols)
        self.withUnsafeMutableBufferPointer { ptr in
            let size = rows * cols - 1
            for cycleBegin in cycles {
                var i = cycleBegin
                var t = ptr[i]
                repeat {
                    i = (i*rows)%size
                    swap(&ptr[i], &t)
                } while i != cycleBegin
            }
        }
    }
}*/


public struct Array2DFastTime {
    public var data: [Float]
    public let nLocations: Int
    public let nTime: Int
    
    public init(data: [Float], nLocations: Int, nTime: Int) {
        if (data.count != nLocations * nTime) {
            fatalError("Wrong Array2DFastTime dimensions. nLocations=\(nLocations) nTime=\(nTime) count=\(data.count)")
        }
        self.data = data
        self.nLocations = nLocations
        self.nTime = nTime
    }
    
    public init(nLocations: Int, nTime: Int) {
        self.data = .init(repeating: .nan, count: nLocations * nTime)
        self.nLocations = nLocations
        self.nTime = nTime
    }
    
    @inlinable subscript(location: Int, time: Int) -> Float {
        get {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            return data[location * nTime + time]
        }
        set {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            data[location * nTime + time] = newValue
        }
    }
    
    @inlinable subscript(location: Int, time: Range<Int>) -> ArraySlice<Float> {
        get {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time.upperBound <= nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            return data[time.add(location * nTime)]
        }
        set {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time.upperBound <= nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            data[time.add(location * nTime)] = newValue
        }
    }
    
    /// One spatial field into time-series array
    @inlinable subscript(location: Range<Int>, time: Int) -> [Float] {
        get {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            var out = [Float]()
            out.reserveCapacity(location.count)
            for loc in location {
                out.append(self[loc, time])
            }
            return out
        }
        set {
            precondition(location.upperBound <= nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            precondition(newValue.count == location.count, "Array and location count do not match")
            for (loc, value) in zip(location, newValue) {
                data[loc * nTime + time] = value
            }
        }
    }
    
    /// Transpose to fast space
    func transpose() -> Array2DFastSpace {
        precondition(data.count == nLocations * nTime)
        return data.withUnsafeBufferPointer { data in
            let out = [Float](unsafeUninitializedCapacity: data.count) { buffer, initializedCount in
                for t in 0..<nTime {
                    for l in 0..<nLocations {
                        buffer[t * nLocations + l] = data[l * nTime + t]
                    }
                }
                initializedCount += data.count
            }
            return Array2DFastSpace(data: out, nLocations: nLocations, nTime: nTime)
        }
    }
}
