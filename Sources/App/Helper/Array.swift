import Foundation
import SwiftNetCDF
import CHelper


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
            precondition(location.upperBound < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            return data[location.add(time * nLocations)]
        }
        set {
            precondition(location.upperBound < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
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

struct Array2DFastTime {
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
            precondition(time.upperBound < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            return data[time.add(location * nTime)]
        }
        set {
            precondition(location < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time.upperBound < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            data[time.add(location * nTime)] = newValue
        }
    }
    
    /// One spatial field into time-series array
    @inlinable subscript(location: Range<Int>, time: Int) -> [Float] {
        get {
            precondition(location.upperBound < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
            precondition(time < nTime, "time subscript invalid: \(nTime) with nTime=\(nTime)")
            var out = [Float]()
            out.reserveCapacity(location.count)
            for loc in location {
                out.append(self[loc, time])
            }
            return out
        }
        set {
            precondition(location.upperBound < nLocations, "location subscript invalid: \(location) with nLocations=\(nLocations)")
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

extension Array where Element == Float {
    func max(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].max()!
        }
    }
    func min(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].min()!
        }
    }
    func sum(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].reduce(0, +)
        }
    }
    func mean(by: Int) -> [Float] {
        return stride(from: 0, through: count-by, by: by).map { i in
            return self[i..<i+by].reduce(0, +) / Float(by)
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
    
    mutating func multiplyAdd(multiply: Float, add: Float) {
        self.withUnsafeMutableBufferPointer { data in
            for i in 0..<data.count {
                data[i] = fma(data[i], multiply, add)
            }
        }
    }
}
