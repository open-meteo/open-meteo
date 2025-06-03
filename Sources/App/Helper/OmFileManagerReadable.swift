import Foundation
@preconcurrency import OmFileFormat
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
    case meta(domain: DomainRegistry)

    /// Assemble the full file system path
    func getFilePath() -> String {
        return "\(OpenMeteo.dataDirectory)\(getRelativeFilePath())"
    }
    
    /// Relative file path like `/dwd_icon/temperature_2m/chunk_1234.om`
    func getRelativeFilePath() -> String {
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
        case .meta(let domain):
            return "\(domain.rawValue)/static/meta.json"
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

    func exists() -> Bool {
        let file = getFilePath()
        return FileManager.default.fileExists(atPath: file)
    }
}

extension OmFileReaderArrayProtocol where OmType == Float {
    /// Read interpolated between 4 points. Assuming dim0 is used for locations and dim1 is a time series
    public func readInterpolated(dim0: GridPoint2DFraction, dim0Nx: Int, dim1 dim1Read: Range<Int>) async throws -> [Float] {
        let gridpoint = dim0.gridpoint
        
        return try await readInterpolated(
            dim0X: gridpoint % dim0Nx,
            dim0XFraction: dim0.xFraction,
            dim0Y: gridpoint / dim0Nx,
            dim0YFraction: dim0.yFraction,
            dim0Nx: dim0Nx,
            dim1: dim1Read.toUInt64()
        )
    }

    /// Read interpolated between 4 points. Assuming dim0 and dim1 are a spatial field
    public func readInterpolated(pos: GridPoint2DFraction) async throws -> Float {
        let dims = getDimensions()
        guard dims.count == 2 else {
            fatalError("Dimension count must be 2")
        }
        
        return try await readInterpolated(
            dim0: pos.gridpoint / Int(dims[1]),
            dim0Fraction: pos.yFraction,
            dim1: pos.gridpoint % Int(dims[1]),
            dim1Fraction: pos.xFraction
        )
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
}
