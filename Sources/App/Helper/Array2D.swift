import Foundation
import SwiftNetCDF

struct Array2D {
    /// The underlying data storage for the 2D array.
    var data: [Float]

    /// The number of elements in x dimension
    let nx: Int

    /// The number of elements in y dimension
    let ny: Int

    /// The total number of elements in this array
    var count: Int {
        return nx * ny
    }

    init(data: [Float], nx: Int, ny: Int) {
        precondition(data.count == nx * ny)
        self.data = data
        self.nx = nx
        self.ny = ny
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

    mutating func flipEverySecondScanLine() {
        // flip every second line
        for y in stride(from: 1, to: ny, by: 2) {
            for x in 0 ..< nx / 2 {
                let temp = data[y * nx + x]
                data[y * nx + x] = data[y * nx + nx - x - 1]
                data[y * nx + nx - x - 1] = temp
            }
        }
    }

    mutating func shift180Longitudee() {
        data.shift180Longitude(nt: 1, ny: ny, nx: nx)
    }

    mutating func flipLatitude() {
        data.flipLatitude(nt: 1, ny: ny, nx: nx)
    }
}

/**
 `Array2DFastSpace` is a struct that represents a 2D array of Float values with fast space indexing. It allows accessing and modifying individual elements using subscript notation.
 
 Data is stored to be accessed quickly for multiple locatios in a row, while accessing timesteps is slower
*/
struct Array2DFastSpace {
    /// The underlying data storage for the 2D array.
    var data: [Float]

    /// The number of spatial locations in the array.
    let nLocations: Int

    /// The number of time steps in the array.
    let nTime: Int

    /**
     Initializes a new instance of `Array2DFastSpace`.
     
     - Parameters:
        - data: The data to be used as the underlying storage of the 2D array. Its count should be equal to `nLocations * nTime`.
        - nLocations: The number of spatial locations in the array.
        - nTime: The number of time steps in the array.
     
     - Precondition: `data.count` should be equal to `nLocations * nTime`, otherwise the initializer will fatalError.
     */
    public init(data: [Float], nLocations: Int, nTime: Int) {
        if data.count != nLocations * nTime {
            fatalError("Wrong Array2DFastTime dimensions. nLocations=\(nLocations) nTime=\(nTime) count=\(data.count)")
        }
        self.data = data
        self.nLocations = nLocations
        self.nTime = nTime
    }

    /**
     Initializes a new instance of `Array2DFastSpace` with all elements set to `NaN`.
     
     - Parameters:
        - nLocations: The number of spatial locations in the array.
        - nTime: The number of time steps in the array.
     */
    public init(nLocations: Int, nTime: Int) {
        self.data = .init(repeating: .nan, count: nLocations * nTime)
        self.nLocations = nLocations
        self.nTime = nTime
    }

    /**
     Writes the 2D array data to a NetCDF file.
     
     - Parameters:
        - filename: The name of the file to write to.
        - nx: The number of grid points in the x (longitude) direction.
        - ny: The number of grid points in the y (latitude) direction.
     
     - Throws: An error of type `NetCDFError` if the write operation fails.
     */
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

    /// Accesses the element at the specified time and location in the 2D array.
    ///
    /// - Parameters:
    ///   - time: The time index of the element to access.
    ///   - location: The location index of the element to access.
    ///
    /// - Precondition: `location` must be less than `nLocations`.
    /// - Precondition: `time` must be less than `nTime`.
    ///
    /// - Returns: The element at the specified time and location in the 2D array.
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

    /// Accesses a range of values in the array for a specific time.
    ///
    /// Use this subscript to access a range of values from the `Array2DFastSpace` array
    /// for a specific time. The range of locations is specified as a `Range` object.
    ///
    /// - Parameters:
    ///   - time: The time to access the range of values for.
    ///   - location: The range of locations to access.
    ///
    /// - Returns: An array slice that contains the values of the specified range
    ///   of locations for the specified time.
    ///
    /// - Precondition: `time` must be less than `nTime` and `location.upperBound` must
    ///   be less than or equal to `nLocations`.
    ///
    /// - SeeAlso: `subscript(time: Int, location: Int) -> Float`
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

/**
 `Array2DFastTime` is a struct that represents a 2D array of Float values with fast time indexing. It allows accessing and modifying individual elements using subscript notation.
 
 Data is stored to be accessed quickly for multiple time temps in a row, while accessing locations is slower
*/
public struct Array2DFastTime {
    /// The underlying data storage for the 2D array.
    public var data: [Float]

    /// The number of spatial locations in the array.
    public let nLocations: Int

    /// The number of time steps in the array.
    public let nTime: Int

    /**
     Initializes a new instance of `Array2DFastTime`.
     
     - Parameters:
        - data: The data to be used as the underlying storage of the 2D array. Its count should be equal to `nLocations * nTime`.
        - nLocations: The number of spatial locations in the array.
        - nTime: The number of time steps in the array.
     
     - Precondition: `data.count` should be equal to `nLocations * nTime`, otherwise the initializer will fatalError.
     */
    public init(data: [Float], nLocations: Int, nTime: Int) {
        if data.count != nLocations * nTime {
            fatalError("Wrong Array2DFastTime dimensions. nLocations=\(nLocations) nTime=\(nTime) count=\(data.count)")
        }
        self.data = data
        self.nLocations = nLocations
        self.nTime = nTime
    }

    /**
     Initializes a new instance of `Array2DFastTime` with all elements set to `NaN`.
     
     - Parameters:
        - nLocations: The number of spatial locations in the array.
        - nTime: The number of time steps in the array.
     */
    public init(nLocations: Int, nTime: Int) {
        self.data = .init(repeating: .nan, count: nLocations * nTime)
        self.nLocations = nLocations
        self.nTime = nTime
    }

    /// Accesses the element at the specified time and location in the 2D array.
    ///
    /// - Parameters:
    ///   - location: The location index of the element to access.
    ///   - time: The time index of the element to access.
    ///
    /// - Precondition: `location` must be less than `nLocations`.
    /// - Precondition: `time` must be less than `nTime`.
    ///
    /// - Returns: The element at the specified time and location in the 2D array.
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

    /// Accesses a range of values in the array for a specific location.
    ///
    /// Use this subscript to access a range of values from the `Array2DFastTime` array
    /// for a specific location. The range of time steps is specified as a `Range` object.
    ///
    /// - Parameters:
    ///   - location: The location to access the range of values for.
    ///   - time: The range of time steps to access.
    ///
    /// - Returns: An array slice that contains the values of the specified range
    ///   of timesteps for the specified location.
    ///
    /// - Precondition: `location` must be less than `nLocations` and `time.upperBound` must
    ///   be less than or equal to `nTime`.
    ///
    /// - SeeAlso: `subscript(time: Int, location: Int) -> Float`
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

    /// Accesses a range of values in the array for a specific time. This function is relatively slow, because data needs to be transposed.
    ///
    /// Use this subscript to access a range of values from the `Array2DFastTime` array
    /// for a specific time. The range of locations is specified as a `Range` object.
    ///
    /// - Parameters:
    ///   - time: The time to access the range of values for.
    ///   - location: The range of locations to access.
    ///
    /// - Returns: An array slice that contains the values of the specified range
    ///   of locations for the specified time.
    ///
    /// - Precondition: `time` must be less than `nTime` and `location.upperBound` must
    ///   be less than or equal to `nLocations`.
    ///
    /// - SeeAlso: `subscript(time: Int, location: Int) -> Float`
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
