import Foundation
import Vapor


extension Process {
    static func bunzip2(file: String) async throws {
        try await spawn(cmd: "bunzip2", args: ["--keep", "-f", file])
    }
    
    static public func grib2ToNetcdf(in inn: String, out: String) async throws {
        try await spawn(cmd: "cdo", args: ["-s","-f", "nc", "copy", inn, out])
    }
    
    /// Convert to NetCDF and shift to -180;180 longitude. Only works for global grids
    static public func grib2ToNetcdfShiftLongitudeInvertLatitude(in inn: String, out: String) async throws {
        try await spawn(cmd: "cdo", args: ["-s","-f", "nc", "-invertlat", "-sellonlatbox,-180,180,-90,90", inn, out])
    }
    
    static public func grib2ToNetCDFInvertLatitude(in inn: String, out: String) async throws {
        try await spawn(cmd: "cdo", args: ["-s","-f", "nc", "invertlat", inn, out])
    }
    
    static func bunzip2(file: String) throws {
        try spawn(cmd: "bunzip2", args: ["--keep", "-f", file])
    }
    
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

struct CdoIconGlobal {
    let gridFile: String
    let weightsFile: String
    let logger: Logger

    /// Download and prepare weights for icon global is missing
    public init(logger: Logger, workDirectory: String) async throws {
        self.logger = logger
        let fileName = "icon_grid_0026_R03B07_G.nc"
        let remoteFile = "https://opendata.dwd.de/weather/lib/cdo/\(fileName).bz2"
        let localFile = "\(workDirectory)\(fileName).bz2"
        let localUncompressed = "\(workDirectory)\(fileName)"
        gridFile = "\(workDirectory)grid_icogl2world_0125.txt"
        weightsFile = "\(workDirectory)weights_icogl2world_0125.nc"
        let fm = FileManager.default

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
            xsize    = 2879
            ysize    = 1441
            xfirst   = -180
            xinc     = 0.125
            yfirst   = -90
            yinc     = 0.125
            """
            try gridContext.write(toFile: gridFile, atomically: true, encoding: .utf8)
        }

        if !fm.fileExists(atPath: localFile) {
            let curl = Curl(logger: logger)
            try await curl.downloadAsync(url: remoteFile, to: localFile)
        }

        if !fm.fileExists(atPath: localUncompressed) {
            logger.info("Uncompressing \(localFile)")
            try await Process.bunzip2(file: localFile)
        }

        logger.info("Generating weights file \(weightsFile)")
        let terminationStatus = try await Process.spawnWithPipes(cmd: "cdo", args: ["-s","gennn,\(gridFile)", localUncompressed, weightsFile])
        guard terminationStatus == 0 else {
            fatalError("Cdo gennn failed")
        }

        try FileManager.default.removeItem(atPath: localUncompressed)
        try FileManager.default.removeItem(atPath: localFile)
    }

    public func remap(in inn: String, out: String) async throws {
        logger.info("Remapping file \(inn)")
        try await Process.spawn(cmd: "cdo", args: ["-s", "-f", "nc", "remap,\(gridFile),\(weightsFile)", inn, out])
    }
}
