import Foundation
import SwiftPFor2D
import NIOConcurrencyHelpers
import Vapor
import NIO

enum OmFileManagerType: String {
    case chunk
    case year
    case master
    case linear_bias_seasonal
}

enum OmFileManagerReadable: Hashable {
    case domainChunk(domain: DomainRegistry, variable: String, type: OmFileManagerType, chunk: Int?, ensembleMember: Int, previousDay: Int)
    case staticFile(domain: DomainRegistry, variable: String, chunk: Int? = nil)
    
    /// Assemble the full file system path
    func getFilePath() -> String {
        return "\(OpenMeteo.dataDirectory)\(getRelativeFilePath())"
    }
    
    private func getRelativeFilePath() -> String {
        switch self {
        case .domainChunk(let domain, let variable, let type, let chunk, let ensembleMember, let previousDay):
            let ensembleMember = ensembleMember > 0 ? "_member\(ensembleMember.zeroPadded(len: 2))" : ""
            let previousDay = previousDay > 0 ? "_previous_day\(previousDay)" : ""
            if let chunk {
                return "\(domain.rawValue)/\(variable)\(previousDay)\(ensembleMember)/\(type)_\(chunk).om"
            }
            return "\(domain.rawValue)/\(variable)\(previousDay)\(ensembleMember)/\(type).om"
        case .staticFile(let domain, let variable, let chunk):
            if let chunk {
                // E.g. DEM model '/copernicus_dem90/static/lat_-1.om'
                return "\(domain.rawValue)/static/\(variable)_\(chunk).om"
            }
            return "\(domain.rawValue)/static/\(variable).om"
        }
    }
    
    func createDirectory(dataDirectory: String = OpenMeteo.dataDirectory) throws {
        let file = getRelativeFilePath()
        guard let last = file.lastIndex(of: "/") else {
            return
        }
        let path = "\(dataDirectory)\(file[file.startIndex..<last])"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    
    func openRead() throws -> OmFileReader<MmapFile>? {
        let file = getFilePath()
        guard FileManager.default.fileExists(atPath: file) else {
            return nil
        }
        return try OmFileReader(file: file)
    }
    
    func openReadCached() throws -> OmFileReader<MmapFileCached>? {
        let fileRel = getRelativeFilePath()
        let file = "\(OpenMeteo.dataDirectory)\(fileRel)"
        guard FileManager.default.fileExists(atPath: file) else {
            return nil
        }
        if let cacheDir = OpenMeteo.cacheDirectory {
            let cacheFile = "\(cacheDir)\(fileRel)"
            try createDirectory(dataDirectory: cacheDir)
            return try OmFileReader(file: file, cacheFile: cacheFile)
        }
        return try OmFileReader(file: file, cacheFile: nil)
    }
}

/// cache file handles, background close checks
/// If a file path is missing, this information is cached and checked in the background
final class OmFileManager: LifecycleHandler {
    /// A file might exist and is open, or it is missing
    enum OmFileState {
        case exists(file: OmFileReader<MmapFileCached>)
        case missing(path: String)
    }
    
    /// Non existing files are set to nil
    private let cached = NIOLockedValueBox<[Int: OmFileState]>(.init())
    
    private let backgroundWatcher = NIOLockedValueBox<Task<(), Error>?>(nil)
    
    public static var instance = OmFileManager()
    
    private init() {}
    
    func didBoot(_ application: Application) throws {
        let logger = application.logger
        backgroundWatcher.withLockedValue({
            $0 = Task {
                try await backgroundTask(logger: logger)
            }
        })
    }
    
    func shutdown(_ application: Application) {
        backgroundWatcher.withLockedValue {
            $0?.cancel()
        }
    }
    
    func backgroundTask(logger: Logger) async throws {
        var count: Double = 0
        var elapsed: Double = 0
        var max: Double = 0
        while true {
            let start = DispatchTime.now()
            let stats = self.secondlyCallback()
            let dt = Double((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)) / 1_000_000_000
            if dt > max {
                max = dt
            }
            elapsed += dt
            count += 1
            if count >= 10 {
                if (stats.open > 0) {
                    let buf = OmFileReader<MmapFile>.getStatistics()
                    logger.info("OmFileManager checked \(stats.open) open files and \(stats.missing) missing files. Time average=\((elapsed/count).asSecondsPrettyPrint) max=\(max.asSecondsPrettyPrint). Buffers \(buf.count) total=\(buf.totalSize.bytesHumanReadable) max=\(buf.maxSize.bytesHumanReadable)")
                }
                count = 0
                elapsed = 0
                max = 0
            }
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try Task.checkCancellation()
        }
    }
    
    /// Called every couple of seconds to check for any file modifications
    func secondlyCallback() -> (open: Int, missing: Int, ejected: Int) {
        // Could be later used to expose some metrics
        var countExisting = 0
        var countMissing = 0
        var countEjected = 0
        
        let copy = cached.withLockedValue {
            return $0
        }
        
        for e in copy {
            switch e.value {
            case .exists(file: let file):
                // Remove file from cache, if it was deleted
                if file.wasDeleted() {
                    cached.withLockedValue({
                        $0.removeValue(forKey: e.key)
                        countEjected += 1
                    })
                }
                countExisting += 1
            case .missing(path: let path):
                // Remove file from cache, if it is now available, so the next open, will make it available
                if FileManager.default.fileExists(atPath: path) {
                    cached.withLockedValue({
                        let _ = $0.removeValue(forKey: e.key)
                        countEjected += 1
                    })
                }
                countMissing += 1
            }
        }
        return (countExisting, countMissing, countEjected)
        //logger.info("OmFileManager tracking \(countExisting) open files, \(countMissing) missing files. \(countEjected) were ejected in this update.")
    }
    
    /// Get cached file or return nil, if the files does not exist
    public static func get(_ file: OmFileManagerReadable) throws -> OmFileReader<MmapFileCached>? {
        try instance.get(file)
    }

    /// Get cached file or return nil, if the files does not exist
    public func get(_ file: OmFileManagerReadable) throws -> OmFileReader<MmapFileCached>? {
        let key = file.hashValue
        
        return try cached.withLockedValue { cached in
            if let file = cached[key] {
                switch file {
                case .exists(file: let file):
                    return file
                case .missing(path: _):
                    return nil
                }
            }
            guard let file = try file.openReadCached() else {
                cached[key] = .missing(path: file.getFilePath())
                return nil
            }
            cached[key] = .exists(file: file)
            return file
        }
    }
}

/// Keep one buffer per thread
fileprivate var buffers = [Thread: UnsafeMutableRawBufferPointer]()

/// Thread safe access to buffers
fileprivate let lockBuffers = NIOLock()

extension OmFileReader {
    /// Basic buffer usage statistics
    public static func getStatistics() -> (count: Int, totalSize: Int, maxSize: Int) {
        return lockBuffers.withLock {
            let total = buffers.reduce(0, {$0 + $1.value.count})
            let max = buffers .max(by: {$0.value.count > $1.value.count})?.value.count ?? 0
            return (buffers.count, total, max)
        }
    }
    
    /// Thread safe buffer provider that automatically reallocates buffers
    public static func getBuffer(minBytes: Int) -> UnsafeMutableRawBufferPointer {
        return lockBuffers.withLock {
            if let buffer = buffers[Thread.current] {
                if buffer.count < minBytes {
                    let buffer = UnsafeMutableRawBufferPointer(start: realloc(buffer.baseAddress, minBytes), count: minBytes)
                    buffers[Thread.current] = buffer
                    return buffer
                }
                return buffer
            }
            let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: minBytes, alignment: 4)
            buffers[Thread.current] = buffer
            return buffer
        }
    }
    /// Read data into existing output float buffer
    public func read(into: UnsafeMutablePointer<Float>, arrayDim1Range: Range<Int>, arrayDim1Length: Int, dim0Slow dim0Read: Range<Int>, dim1 dim1Read: Range<Int>) throws {
        //assert(arrayDim1Range.count == dim1Read.count)
        let chunkBuffer = OmFileReader.getBuffer(minBytes: P4NDEC256_BOUND(n: chunk0*chunk1, bytesPerElement: compression.bytesPerElement)).baseAddress!
        try read(into: into, arrayDim1Range: arrayDim1Range, arrayDim1Length: arrayDim1Length, chunkBuffer: chunkBuffer, dim0Slow: dim0Read, dim1: dim1Read)
    }
    
    /// Read data into existing output float buffer
    public func read(into: inout [Float], arrayRange: Range<Int>, arrayDim1Length: Int, dim0Slow dim0Read: Range<Int>, dim1 dim1Read: Range<Int>) throws {
        try into.withUnsafeMutableBufferPointer {
            let chunkBuffer = OmFileReader.getBuffer(minBytes: P4NDEC256_BOUND(n: chunk0*chunk1, bytesPerElement: compression.bytesPerElement)).baseAddress!
            try read(into: $0.baseAddress!, arrayDim1Range: arrayRange, arrayDim1Length: arrayDim1Length, chunkBuffer: chunkBuffer, dim0Slow: dim0Read, dim1: dim1Read)
        }
    }
    
    /// Read data. This version is a bit slower, because it is allocating the output buffer
    public func read(dim0Slow dim0Read: Range<Int>?, dim1 dim1Read: Range<Int>?) throws -> [Float] {
        let dim0Read = dim0Read ?? 0..<dim0
        let dim1Read = dim1Read ?? 0..<dim1
        let count = dim0Read.count * dim1Read.count
        return try [Float](unsafeUninitializedCapacity: count, initializingWith: {ptr, countRead in
            try read(into: ptr.baseAddress!, arrayDim1Range: 0..<dim1Read.count, arrayDim1Length: dim1Read.count, dim0Slow: dim0Read, dim1: dim1Read)
            countRead += count
        })
    }
    
    /// Read interpolated between 4 points. Assuming dim0 is used for lcations and dim1 is a time series
    public func readInterpolated(dim0: GridPoint2DFraction, dim0Nx: Int, dim1 dim1Read: Range<Int>) throws -> [Float] {
        let gridpoint = dim0.gridpoint
        return try readInterpolated(
            dim0X: gridpoint % dim0Nx,
            dim0XFraction: dim0.xFraction,
            dim0Y: gridpoint / dim0Nx,
            dim0YFraction: dim0.yFraction,
            dim0Nx: dim0Nx,
            dim1: dim1Read
        )
    }
    
    /// Read interpolated between 4 points. Assuming dim0 is used for lcations and dim1 is a time series
    public func readInterpolated(dim0X: Int, dim0XFraction: Float, dim0Y: Int, dim0YFraction: Float, dim0Nx: Int, dim1 dim1Read: Range<Int>) throws -> [Float] {
        
        // bound x and y
        var dim0X = dim0X
        var dim0XFraction = dim0XFraction
        if dim0X > dim0Nx-2 {
            dim0X = dim0Nx-2
            dim0XFraction = 1
        }
        var dim0Y = dim0Y
        var dim0YFraction = dim0YFraction
        let dim0Ny = dim0 / dim0Nx
        if dim0Y > dim0Ny-2 {
            dim0Y = dim0Ny-2
            dim0YFraction = 1
        }
        
        // reads 4 points. As 2 points are next to each other, we can read a small row of 2 elements at once
        let top = try read(dim0Slow: dim0Y * dim0Nx + dim0X ..< dim0Y * dim0Nx + dim0X + 2, dim1: dim1Read)
        let bottom = try read(dim0Slow: (dim0Y + 1) * dim0Nx + dim0X ..< (dim0Y + 1) * dim0Nx + dim0X + 2, dim1: dim1Read)
        
        // interpolate linearly between
        let nt = dim1Read.count
        return zip(zip(top[0..<nt], top[nt..<2*nt]), zip(bottom[0..<nt], bottom[nt..<2*nt])).map {
            let ((a,b),(c,d)) = $0
            return  a * (1-dim0XFraction) * (1-dim0YFraction) +
                    b * (dim0XFraction) * (1-dim0YFraction) +
                    c * (1-dim0XFraction) * (dim0YFraction) +
                    d * (dim0XFraction) * (dim0YFraction)
        }
    }
    
    
    /// Read interpolated between 4 points. Assuming dim0 and dim1 are a spatial field
    public func readInterpolated(pos: GridPoint2DFraction) throws -> Float {
        return try readInterpolated(
            dim0: pos.gridpoint / self.dim1,
            dim0Fraction: pos.yFraction,
            dim1: pos.gridpoint % self.dim1,
            dim1Fraction: pos.xFraction
        )
    }
    
    /// Read interpolated between 4 points. Assuming dim0 and dim1 are a spatial field
    public func readInterpolated(dim0: Int, dim0Fraction: Float, dim1: Int, dim1Fraction: Float) throws -> Float {
        // bound x and y
        var dim0 = dim0
        var dim0Fraction = dim0Fraction
        if dim0 > self.dim0-2 {
            dim0 = self.dim0-2
            dim0Fraction = 1
        }
        var dim1 = dim1
        var dim1Fraction = dim1Fraction
        if dim1 > self.dim1-2 {
            dim1 = self.dim1-2
            dim1Fraction = 1
        }
        
        // reads 4 points at once
        let points = try read(dim0Slow: dim0 ..< dim0 + 2, dim1: dim1 ..< dim1 + 2)
        
        // interpolate linearly between
        return points[0] * (1-dim0Fraction) * (1-dim1Fraction) +
               points[1] * (dim0Fraction) * (1-dim1Fraction) +
               points[2] * (1-dim0Fraction) * (dim1Fraction) +
               points[3] * (dim0Fraction) * (dim1Fraction)
    }
    
    /// Read interpolated between 4 points. If one point is NaN, ignore it.
    /*public func readInterpolatedIgnoreNaN(dim0X: Int, dim0XFraction: Float, dim0Y: Int, dim0YFraction: Float, dim0Nx: Int, dim1 dim1Read: Range<Int>) throws -> [Float] {
        
        // reads 4 points. As 2 points are next to each other, we can read a small row of 2 elements at once
        let top = try read(dim0Slow: dim0Y * dim0Nx + dim0X ..< dim0Y * dim0Nx + dim0X + 2, dim1: dim1Read)
        let bottom = try read(dim0Slow: (dim0Y + 1) * dim0Nx + dim0X ..< (dim0Y + 1) * dim0Nx + dim0X + 2, dim1: dim1Read)
        
        // interpolate linearly between
        let nt = dim1Read.count
        return zip(zip(top[0..<nt], top[nt..<2*nt]), zip(bottom[0..<nt], bottom[nt..<2*nt])).map {
            let ((a,b),(c,d)) = $0
            var value: Float = 0
            var weight: Float = 0
            if !a.isNaN {
                value += a * (1-dim0XFraction) * (1-dim0YFraction)
                weight += (1-dim0XFraction) * (1-dim0YFraction)
            }
            if !b.isNaN {
                value += b * (1-dim0XFraction) * (dim0YFraction)
                weight += (1-dim0XFraction) * (dim0YFraction)
            }
            if !c.isNaN {
                value += c * (dim0XFraction) * (1-dim0YFraction)
                weight += (dim0XFraction) * (1-dim0YFraction)
            }
            if !d.isNaN {
                value += d * (dim0XFraction) * (dim0YFraction)
                weight += (dim0XFraction) * (dim0YFraction)
            }
            return weight > 0.001 ? value / weight : .nan
        }
    }*/
    
    // prefect and read all
    public func readAll() throws -> [Float] {
        fn.prefetchData(offset: 0, count: fn.count)
        return try read(dim0Slow: 0..<dim0, dim1: 0..<dim1)
    }
    
    // prefect and read all
    public func readAll2D() throws -> Array2DFastTime {
        return Array2DFastTime(data: try readAll(), nLocations: dim0, nTime: dim1)
    }
}
