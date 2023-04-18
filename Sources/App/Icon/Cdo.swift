import Foundation
import Vapor
import SwiftEccodes


extension Process {
    /*static func bunzip2(file: String) throws {
        try spawn(cmd: "bunzip2", args: ["--keep", "-f", file])
    }*/
    
    /*static public func grib2ToNetcdf(in inn: String, out: String) throws {
        try spawn(cmd: "cdo", args: ["-s","-f", "nc", "copy", inn, out])
    }
    
    /// Convert to NetCDF and shift to -180;180 longitude. Only works for global grids
    static public func grib2ToNetcdfShiftLongitudeInvertLatitude(in inn: String, out: String) throws {
        try spawn(cmd: "cdo", args: ["-s","-f", "nc", "-invertlat", "-sellonlatbox,-180,180,-90,90", inn, out])
    }
    
    static public func grib2ToNetCDFInvertLatitude(in inn: String, out: String) throws {
        try spawn(cmd: "cdo", args: ["-s","-f", "nc", "invertlat", inn, out])
    }*/
}

struct CdoHelper {
    let cdo: CdoIconGlobal?
    let grid: Gridable
    let domain: IconDomains
    let curl: Curl
    
    var needsRemapping: Bool {
        return cdo != nil
    }
    
    init(domain: IconDomains, logger: Logger, curl: Curl) async throws {
        // icon global needs resampling to plate carree
        self.curl = curl
        cdo = try await CdoIconGlobal(logger: logger, workDirectory: domain.downloadDirectory, curl: curl, domain: domain)
        grid = domain.grid
        self.domain = domain
    }
    
    // Uncompress bz2, reproject to regular grid and read into memory
    func downloadAndRemap(_ url: String) async throws -> [GribMessage] {
        guard let cdo else {
            return try await curl.downloadGrib(url: url, bzip2Decode: true)
        }
        // Multiple messages might be present in each grib fle
        // DWD produces non-standard GRIB2 files for 15 minutes ensemble data
        // GRIB messages need to be reordered by timestep
        // Otherwise CDO does not work
        let buffer = try await curl.downloadInMemoryAsync(url: url, minSize: nil, bzip2Decode: true)
        
        var m = [(ptr: UnsafeRawBufferPointer, endStep: Int)]()
        try buffer.withUnsafeReadableBytes({
            var ptr: UnsafeRawBufferPointer = $0
            while let seek = GribAsyncStreamHelper.seekGrib(memory: ptr) {
                //let file = try FileHandle.createNewFile(file: file.replacingOccurrences(of: "#", with: "\(i)"), size: seek.length)
                //try file.write(contentsOf: ptr[seek.offset ..< seek.offset + seek.length])
                let bytes: UnsafeRawBufferPointer = UnsafeRawBufferPointer(rebasing: ptr[seek.offset ..< seek.offset + seek.length])
                let message = try SwiftEccodes.getMessages(memory: bytes, multiSupport: true)[0]
                let endStep = message.get(attribute: "endStep").flatMap(Int.init) ?? 0
                m.append((ptr: bytes, endStep: endStep))
                ptr = UnsafeRawBufferPointer(rebasing: ptr[(seek.offset + seek.length)...])
            }
        })
        m.sort(by: {$0.endStep < $1.endStep})
        
        let gribFile = "\(domain.downloadDirectory)temp.grib2"
        try {
            let size = m.reduce(0, {$0 + $1.ptr.count})
            let file = try FileHandle.createNewFile(file: gribFile, size: size)
            for (ptr,_) in m {
                try file.write(contentsOf: ptr)
            }
        }()
        
        let gribFileRemapped = "\(domain.downloadDirectory)remapped.grib2"
        try cdo.remap(in: gribFile, out: gribFileRemapped)
        
        let messages = try SwiftEccodes.getMessages(fileName: gribFileRemapped, multiSupport: true)
        try FileManager.default.removeItem(atPath: gribFile)
        try FileManager.default.removeItem(atPath: gribFileRemapped)
        return messages
    }
}

extension IconDomains {
    fileprivate var iconGridName: String? {
        switch self {
        case .icon:
            return "0026_R03B07_G"
        case .iconEu:
            return nil
        case .iconD2:
            return nil
        case .iconD2_15min:
            return nil
        case .iconEps:
            return "0036_R03B06_G"
        case .iconEuEps:
            return "0037_R03B07_N02"
        case .iconD2Eps:
            return "0047_R19B07_L"
        }
    }
}

struct CdoIconGlobal {
    let gridFile: String
    let weightsFile: String
    let logger: Logger
    let domain: IconDomains

    /// Download and prepare weights for icon global is missing
    public init?(logger: Logger, workDirectory: String, curl: Curl, domain: IconDomains) async throws {
        self.logger = logger
        self.domain = domain
        guard let iconGridName = domain.iconGridName else {
            return nil
        }
        let fileName = "icon_grid_\(iconGridName).nc"
        let remoteFile = "http://opendata.dwd.de/weather/lib/cdo/\(fileName).bz2"
        let localUncompressed = "\(workDirectory)\(fileName)"
        gridFile = "\(workDirectory)grid_icogl2world_0125.txt"
        weightsFile = "\(workDirectory)weights_icogl2world_0125.nc"
        let fm = FileManager.default
        
        let grid = domain.grid as! RegularGrid

        if fm.fileExists(atPath: gridFile) && fm.fileExists(atPath: weightsFile) {
            return
        }

        if !fm.fileExists(atPath: gridFile) {
            let gridContext = """
            # Climate Data Operator (CDO) grid description file
            # Input: ICON
            # Area: Global
            # Grid: regular latitude longitude/geographical grid
            # Resolution: 0.125 x 0.125 degrees (approx. 13km)

            gridtype = lonlat
            xsize    = \(grid.nx)
            ysize    = \(grid.ny)
            xfirst   = \(grid.lonMin)
            xinc     = \(grid.dx)
            yfirst   = \(grid.latMin)
            yinc     = \(grid.dy)
            """
            try gridContext.write(toFile: gridFile, atomically: true, encoding: .utf8)
        }

        if !fm.fileExists(atPath: localUncompressed) {
            try await curl.download(url: remoteFile, toFile: localUncompressed, bzip2Decode: true)
        }

        logger.info("Generating weights file \(weightsFile)")
        if domain == .iconD2Eps {
            try Process.spawn(cmd: "cdo", args: ["-s","gennn,\(gridFile)", localUncompressed, weightsFile])
            //try Process.spawn(cmd: "cdo", args: ["-selgrid,2", localUncompressed, "\(localUncompressed)_selgrid"])
            //try FileManager.default.moveFileOverwrite(from: "\(localUncompressed)~", to: localUncompressed)
            //try Process.spawn(cmd: "cdo", args: ["-s","gennn,\(gridFile)", "-setgrid,\(localUncompressed)_selgrid", weightsFile])
        } else {
            try Process.spawn(cmd: "cdo", args: ["-s","gennn,\(gridFile)", localUncompressed, weightsFile])
        }
        try FileManager.default.removeItem(atPath: localUncompressed)
    }

    public func remap(in inn: String, out: String) throws {
        logger.debug("Remapping file \(inn)")
        try Process.spawn(cmd: "cdo", args: ["-s", "-f", "grb2", "remap,\(gridFile),\(weightsFile)", inn, out])
    }
}
