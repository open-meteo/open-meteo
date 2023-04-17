import Foundation
import Vapor


extension Process {
    /*static func bunzip2(file: String) throws {
        try spawn(cmd: "bunzip2", args: ["--keep", "-f", file])
    }*/
    
    static public func grib2ToNetcdf(in inn: String, out: String) throws {
        try spawn(cmd: "cdo", args: ["-s","-f", "nc", "copy", inn, out])
    }
    
    /// Convert to NetCDF and shift to -180;180 longitude. Only works for global grids
    static public func grib2ToNetcdfShiftLongitudeInvertLatitude(in inn: String, out: String) throws {
        try spawn(cmd: "cdo", args: ["-s","-f", "nc", "-invertlat", "-sellonlatbox,-180,180,-90,90", inn, out])
    }
    
    static public func grib2ToNetCDFInvertLatitude(in inn: String, out: String) throws {
        try spawn(cmd: "cdo", args: ["-s","-f", "nc", "invertlat", inn, out])
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
            return "0028_R02B07_N02"
        case .iconD2Eps:
            return "0047_R19B07_L"
        }
    }
}

struct CdoIconGlobal {
    let gridFile: String
    let weightsFile: String
    let logger: Logger

    /// Download and prepare weights for icon global is missing
    public init?(logger: Logger, workDirectory: String, client: HTTPClient, domain: IconDomains) async throws {
        self.logger = logger
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
            let curl = Curl(logger: logger, client: client)
            try await curl.download(url: remoteFile, toFile: localUncompressed, bzip2Decode: true)
        }

        logger.info("Generating weights file \(weightsFile)")
        let args = domain == .iconD2Eps ?
            ["-s","gennn,\(gridFile)", "-selgrid,2", localUncompressed, weightsFile] :
            ["-s","gennn,\(gridFile)", localUncompressed, weightsFile]
        let terminationStatus = try Process.spawnWithExitCode(cmd: "cdo", args: args)
        guard terminationStatus == 0 else {
            fatalError("Cdo gennn failed")
        }

        try FileManager.default.removeItem(atPath: localUncompressed)
    }

    public func remap(in inn: String, out: String) throws {
        logger.info("Remapping file \(inn)")
        try Process.spawn(cmd: "cdo", args: ["-s", "-f", "nc", "remap,\(gridFile),\(weightsFile)", inn, out])
    }
}
