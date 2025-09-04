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

enum OmFileManagerReadable: Hashable, OmFileManageable {
    typealias Value = (reader: any OmFileReaderArrayProtocol<Float>, timestamps: [Timestamp]?)
    
    case domainChunk(domain: DomainRegistry, variable: String, type: OmFileManagerType, chunk: Int?, ensembleMember: Int, previousDay: Int)
    case staticFile(domain: DomainRegistry, variable: String, chunk: Int? = nil)
    case meta(domain: DomainRegistry)
    
    /// Full forecast run horizon per run per variable. `data_run/<model>/<run>/<variable>.om`
    case run(domain: DomainRegistry, variable: String, run: IsoDateTime)
    
    func makeRemoteReader(file: OmReaderBlockCache<OmHttpReaderBackend, MmapFile>) async throws -> (any OmFileRemoteManaged<Value>)? {
        do {
            let reader = try await OmFileReader(fn: file)
            
            guard let arrayReader = reader.asArray(of: Float.self) else {
                return nil
            }
            if let times = try await reader.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init) {
                return OmFileRemoteOmReader(reader: arrayReader, timestamps: times)
            }
            return OmFileRemoteOmReader(reader: arrayReader, timestamps: nil)
        } catch OmFileFormatSwiftError.notAnOpenMeteoFile {
            print("[ ERROR ] Not an OpenMeteo file \(file.backend.url)")
            return nil
        }
    }
    
    func makeLocalReader(file: FileHandle) async throws -> any OmFileLocalManaged<Value> {
        let reader = try await OmFileReader(fn: try MmapFile(fn: file, mode: .readOnly))
        guard let arrayReader = reader.asArray(of: Float.self) else {
            throw ForecastApiError.generic(message: "Om file does not contain float array")
        }
        if let times = try await reader.getChild(name: "time")?.asArray(of: Int.self)?.read().map(Timestamp.init) {
            return OmFileLocalOmReader(reader: arrayReader, timestamps: times)
        }
        return OmFileLocalOmReader(reader: arrayReader, timestamps: nil)
    }

    /// Assemble the full file system path
    func getFilePath() -> String {
        return "\(getDataDirectoryPath())\(getRelativeFilePath())"
    }
    
    /// How often this file should be checked for modifications. Some files update every hour, some never update.
    func revalidateEverySeconds(modificationTime: Timestamp?, now: Timestamp) -> Int {
        switch self {
        case .domainChunk(let domain, _, let type, let chunk, _, _):
            switch type {
            case .chunk:
                guard let domain = domain.getDomain(), let chunk else {
                    return 24*3600
                }
                let chunkTime = Timestamp(chunk * domain.omFileLength * domain.dtSeconds) ..< Timestamp((chunk + 1) * domain.omFileLength * domain.dtSeconds)
                
                /// Chunk contains data older than 7 days or 2 times updateTime (seasonal forecast = 31 days)
                /// Covers era5 with 5 days delay
                /// Fore more precise checks, domain needs to report how much past data is updated
                let chunkFinalised = chunkTime.upperBound < now.subtract(seconds: max(7*24*3600, domain.updateIntervalSeconds * 2))
                if chunkFinalised {
                    return 24*3600
                }
                if let modificationTime {
                    if modificationTime < now.subtract(seconds: domain.updateIntervalSeconds / 2) {
                        return 15*60
                    }
                    if modificationTime < now.subtract(seconds: Int(Double(domain.updateIntervalSeconds) * 0.9)) {
                        return 3*60
                    }
                }
                return 10*60
            case .year:
                return 24*3600
            case .master:
                return 24*3600
            case .linear_bias_seasonal:
                return 24*3600
            }
        case .staticFile(_, _, _):
            return 24*3600
        case .meta(_):
            return 24*3600
        case .run(_, _, _):
            return 24*3600
        }
    }
    
    /// Get the remote URL. May replace "data" with "data_run"
    func getRemoteUrl() -> String? {
        guard let remoteDirectory = OpenMeteo.remoteDataDirectory else {
            return nil
        }
        let file = getRelativeFilePath()
        switch self {
        case .run(let domain, _, _):
            return "\(remoteDirectory.replacingOccurrences(of: "data", with: "data_run").replacing("MODEL", with: domain.bucketName))\(file)"
        case .domainChunk(let domain, _, _, _, _, _):
            return "\(remoteDirectory.replacing("MODEL", with: domain.bucketName))\(file)"
        case .staticFile(domain: let domain, _, _):
            return "\(remoteDirectory.replacing("MODEL", with: domain.bucketName))\(file)"
        case .meta(domain: let domain):
            return "\(remoteDirectory.replacing("MODEL", with: domain.bucketName))\(file)"
        }
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
        case .run(domain: let domain, variable: let variable, run: let run):
            return "\(domain.rawValue)/\(run.format_directoriesYYYYMMddhhmm)/\(variable).om"
        }
    }
    
    /// `./data/` or `./data_run/`
    func getDataDirectoryPath() -> String {
        switch self {
        case .domainChunk(_, _, _, _, _, _):
            return OpenMeteo.dataDirectory
        case .staticFile(_, _, _):
            return OpenMeteo.dataDirectory
        case .meta(_):
            return OpenMeteo.dataDirectory
        case .run(_, _, _):
            return OpenMeteo.dataRunDirectory ?? OpenMeteo.dataDirectory
        }
    }

    func createDirectory() throws {
        let file = getFilePath()
        guard let last = file.lastIndex(of: "/") else {
            return
        }
        let path = "\(file[file.startIndex..<last])"
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    func exists() -> Bool {
        let file = getFilePath()
        return FileManager.default.fileExists(atPath: file)
    }
}

struct OmFileRemoteOmReader: OmFileRemoteManaged {
    let reader: OmFileReaderArray<OmReaderBlockCache<OmHttpReaderBackend, MmapFile>, Float>
    let timestamps: [Timestamp]?
    
    var fn: OmReaderBlockCache<OmHttpReaderBackend, MmapFile> {
        reader.fn
    }
    
    func cast() -> (reader: any OmFileReaderArrayProtocol<Float>, timestamps: [Timestamp]?) {
        return (reader, timestamps)
    }
}

struct OmFileLocalOmReader: OmFileLocalManaged {
    let reader: OmFileReaderArray<MmapFile, Float>
    let timestamps: [Timestamp]?
    
    var fn: FileHandle {
        reader.fn.file
    }
    
    func cast() -> (reader: any OmFileReaderArrayProtocol<Float>, timestamps: [Timestamp]?) {
        return (reader, timestamps)
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
