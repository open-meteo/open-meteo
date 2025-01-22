import Foundation
import Vapor
import OmFileFormat
import SwiftNetCDF


/// Download MetNo domains from OpenDAP server
/// https://github.com/metno/NWPdocs/wiki
/// Nordic dataset (same as yr.no API) https://github.com/metno/NWPdocs/wiki/MET-Nordic-dataset
struct MetNoDownloader: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download MetNo models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try MetNoDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let variables = try MetNoVariable.load(commaSeparatedOptional: signature.onlyVariables) ?? MetNoVariable.allCases
                
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let handles = try download(logger: logger, domain: domain, variables: variables, run: run)
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        
        logger.info("Finished in \(start.timeElapsedPretty())")
        
    }
    
    /// Process each variable and update time-series optimised files
    func download(logger: Logger, domain: MetNoDomain, variables: [MetNoVariable], run: Timestamp) throws -> [GenericVariableHandle] {
        Process.alarm(seconds: 3 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let useArchive = run.olderThan(days: 2)
        
        let file = "met_forecast_1_0km_nordic_\(run.format_YYYYMMdd)T\(run.hour.zeroPadded(len: 2))Z.nc"
        let server = "https://thredds.met.no/thredds/dodsC"
        let openDap = useArchive ? "\(server)/metpparchive/\(run.format_directoriesYYYYMMdd)/\(file)" : "\(server)/metpplatest/\(file)"
        
        // Wait up to 30 minutes until data is availble
        let ncFile = try NetCDF.openOrWait(path: openDap, deadline: Date().addingTimeInterval(30*60), logger: logger)
        let dimensions = ncFile.getDimensions()
        guard dimensions.count == 3 else {
            fatalError("Expected 3 dimensions, got \(dimensions.count)")
        }
        let nx = dimensions.first(where: {$0.name == "x"})!.length
        let ny = dimensions.first(where: {$0.name == "y"})!.length
        let nTime = dimensions.first(where: {$0.name == "time"})!.length
        
        guard nx == domain.grid.nx, ny == domain.grid.ny else {
            fatalError("Wrong domain dimensions \(nx), \(ny)")
        }
        guard (48...64).contains(nTime) else {
            fatalError("Wrong time dimensions \(nTime)")
        }
        
        /// Create elevation file if requried
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if !FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            logger.info("Creating elevation file")
            try domain.surfaceElevationFileOm.createDirectory()
            // unit meters
            guard var altitude = try ncFile.getVariable(name: "altitude")?.asType(Float.self)?.read() else {
                fatalError("Could not get float data from altitude")
            }
            // units 0=sea, 1=land
            guard let land_area_fraction = try ncFile.getVariable(name: "land_area_fraction")?.asType(Float.self)?.read() else {
                fatalError("Could not get float data from altitude")
            }
            for i in altitude.indices {
                if land_area_fraction[i] < 0.5 {
                    altitude[i] = -999
                }
            }
            logger.info("Writing elevation file")
            try altitude.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid, createNetCdf: false)
        }
        
        /// Verify projection and grid coordinates
        /*if true {
            guard let lats = try ncFile.getVariable(name: "latitude")?.asType(Float.self)?.read() else {
                fatalError("Could not get float data from latitude")
            }
            guard let lons = try ncFile.getVariable(name: "longitude")?.asType(Float.self)?.read() else {
                fatalError("Could not get float data from longitude")
            }
            
            print("0,0 \(lats[0])/\(lons[0])")
            print("ny-1,nx-1 \(lats[(ny-1)*nx+nx-1])/\(lons[(ny-1)*nx+nx-1])")
            
            for x in 0..<nx {
                for y in 0..<ny {
                    let coord = domain.grid.getCoordinates(gridpoint: y*nx + x)
                    let lat = lats[y*nx + x]
                    let lon = lons[y*nx + x]
                    if abs(coord.latitude - lat) > 0.1 || abs(coord.longitude - lon) > 0.1 {
                        fatalError("lat \(x) \(y) diffs \(coord) \(lat) \(lon)")
                    }
                }
            }
            return
        }*/
        
        return try variables.flatMap { variable in
            logger.info("Download \(variable)")
            
            guard let ncVar = ncFile.getVariable(name: variable.netCdfName) else {
                fatalError("Could not open nc variable \(variable) \(variable.netCdfName)")
            }
            guard let data = try ncVar.asType(Float.self)?.read() else {
                fatalError("Could not get float data from \(variable)")
            }
            /// 1GB spatial oriented file. In total 2.7 GB memory used while running
            var spatial = Array2DFastSpace(data: data, nLocations: nx*ny, nTime: nTime)
            
            if let fma = variable.multiplyAdd {
                spatial.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
            }
            
            /// Solar radiation is accumulated over time. Timestep 0 contains zero values which should be NaN.
            if variable.isAccumulatedSinceModelStart {
                spatial.data.deaccumulateOverTimeSpatial(nTime: nTime)
                for i in 0..<nx*ny {
                    spatial.data[i] = .nan
                }
            }
            
            return try (0..<nTime).map { t in
                let writer = OmFileSplitter.makeSpatialWriter(domain: domain)
                let data = Array(spatial[t, 0..<spatial.nLocations])
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: data)
                return GenericVariableHandle(
                    variable: variable,
                    time: run.add(hours: t),
                    member: 0,
                    fn: fn
                )
            }
        }
    }
}

extension DomainRegistry {
    /// Upload all data to a specified S3 bucket
    func syncToS3(bucket: String, variables: [GenericVariable]?) throws {
        let dir = rawValue
        if let variables {
            let vDirectories = variables.map { $0.omFileName.file } + ["static"]
            for variable in vDirectories {
                if variable.contains("_previous_day") {
                    // do not upload data from past days yet
                    continue
                }
                let src = "\(OpenMeteo.dataDirectory)\(dir)/\(variable)"
                let dest = "s3://\(bucket)/data/\(dir)/\(variable)"
                if !FileManager.default.fileExists(atPath: src) {
                    continue
                }
                try Process.spawnRetried(
                    cmd: "aws",
                    args: ["s3", "sync", "--exclude", "*~", "--no-progress", src, dest]
                )
            }
        } else {
            let src = "\(OpenMeteo.dataDirectory)\(dir)"
            let dest = "s3://\(bucket)/data/\(dir)"
            try Process.spawnRetried(
                cmd: "aws",
                args: ["s3", "sync", "--exclude", "*~", "--no-progress", src, dest]
            )
        }
    }
}

extension NetCDF {
    /// Try to open a file. If it does not excist, wait 10 seconds and try again until deadline is reached
    /// Works with OpenDap urls
    public static func openOrWait(path: String, deadline: Date, logger: Logger) throws -> Group {
        let startTime = Date()
        var lastPrint = Date().addingTimeInterval(TimeInterval(-60))
        let retySeconds = 10
        
        while true {
            guard let nc = try openCatchMssing(path: path, allowUpdate: false) else {
                let timeElapsed = Date().timeIntervalSince(startTime).asSecondsPrettyPrint
                if Date().timeIntervalSince(lastPrint) > 60 {
                    logger.info("NetCDF open failed, retry every \(retySeconds) seconds, (\(timeElapsed) elapsed")
                    lastPrint = Date()
                }
                if Date() > deadline {
                    logger.error("Deadline reached")
                    throw CurlError.timeoutReached
                }
                sleep(UInt32(retySeconds))
                continue
            }
            return nc
        }
    }
    
    /// Try to open a file, but catch error "file not found"
    fileprivate static func openCatchMssing(path: String, allowUpdate: Bool) throws -> Group? {
        do {
            return try open(path: path, allowUpdate: allowUpdate)
        } catch (NetCDFError.ncerror(code: let code, error: let error)) {
            if error == "NetCDF: file not found" {
                return nil
            }
            throw NetCDFError.ncerror(code: code, error: error)
        }
    }
}

extension Group {
    /// Recursively print all groups
    func dump() {
        print("Group: \(name)")
        
        for d in getDimensions() {
            print("Dimension: \(d.name) \(d.length) \(d.isUnlimited)")
        }
        
        for v in getVariables() {
            print("Variable: \(v.name) \(v.type.asExternalDataType()!)")
            for d in v.dimensions {
                print("Variable dimension: \(d.name) \(d.length) \(d.isUnlimited)")
            }
        }
        
        for a in try! getAttributes() {
            print("Attribute: \(a.name) \(a.length) \(a.type.asExternalDataType()!)")
        }
        
        for subgroup in getGroups() {
            subgroup.dump()
        }
    }
}
