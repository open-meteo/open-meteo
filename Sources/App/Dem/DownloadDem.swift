import Foundation
import Vapor
import SwiftNetCDF
import OmFileFormat


/**
 Download digital elevation model from Copernicus and Sinergise https://copernicus-dem-30m.s3.amazonaws.com/readme.html

 Data is stored on a S3 bucket with 1x1 degree files. Files closer to poles, have fewer resolution on longitude axis.
 Downloader is downloading 1x1 files and converting them to latitude files. E.g. every latitude has its own compressed `om` file.

 Total size after conversion `10.48 GB`
 */
struct Dem90: GenericDomain {
    var grid: Gridable {
        fatalError("Dem90 does not offer a grid")
    }
    
    var domainRegistry: DomainRegistry {
        return .copernicus_dem90
    }
    
    var domainRegistryStatic: DomainRegistry? {
        return .copernicus_dem90
    }
    
    var dtSeconds: Int {
        return 0
    }
    
    var hasYearlyFiles: Bool {
        return false
    }
    
    var masterTimeRange: Range<Timestamp>? {
        return nil
    }
    
    var omFileLength: Int {
        return 0
    }
    
    var updateIntervalSeconds: Int {
        return 0
    }

    /// Get elevation for coordinate. Access to om files is cached.
    static func read(lat: Float, lon: Float) throws -> Float {
        if lat < -90 || lat >= 90 || lon < -180 || lon >= 180 {
            return .nan
        }
        let lati = lat < 0 ? Int(lat) - 1 : Int(lat)
        guard let om = try OmFileManager.get(.staticFile(domain: .copernicus_dem90, variable: "lat", chunk: lati)) else {
            // file not available
            return .nan
        }
        let latrow = UInt64(lat * 1200 + 90 * 1200) % 1200
        let px = pixel(latitude: lati)
        let lonrow = UInt64((lon + 180) * Float(px))
        var value: Float = .nan
        try om.read(into: &value, range: [latrow..<latrow+1, lonrow..<lonrow+1])
        return value
    }

    /// Get the longitude resolution on a given latitude
    static func pixel(latitude: Int) -> Int {
        if latitude < -85 {
            return 120
        }
        if latitude < -80 {
            return 240
        }
        if latitude < -70 {
            return 400
        }
        if latitude < -60 {
            return 600
        }
        if latitude < -50 {
            return 800
        }
        if latitude < 50 {
            return 1200
        }
        if latitude < 60 {
            return 800
        }
        if latitude < 70 {
            return 600
        }
        if latitude < 80 {
            return 400
        }
        if latitude < 85 {
            return 240
        }
        return 120
    }
}

/**
 Download digital elevation model from Sinergise https://copernicus-dem-30m.s3.amazonaws.com/readme.html
 */
struct DownloadDemCommand: AsyncCommand {
    var help: String {
        return "Convert digital elevation model"
    }

    struct Signature: CommandSignature {
        @Argument(name: "path", help: "Local path with DEM90 data")
        var path: String

        @Option(name: "concurrent-conversion-jobs", help: "Max number of concurrent conversion jobs. Default 4")
        var concurrentConversions: Int?

        @Option(name: "concurrent-compression-jobs", help: "Max number of concurrent compression jobs. Default 4")
        var concurrentCompressions: Int?
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        try FileManager.default.createDirectory(atPath: Dem90().downloadDirectory, withIntermediateDirectories: true)
        let logger = context.application.logger
        //let curl = Curl(logger: logger)

        //let tifTemp = "\(Dem90.downloadDirectory)temp.tif"

        var scheduledConversions = 0

        try await withThrowingTaskGroup(of: Void.self) { group in
            for lon in -180..<180 {
                for lat in -90..<90 {
                    if scheduledConversions >= signature.concurrentConversions ?? 4 {
                        try await group.next()
                    } else {
                        scheduledConversions += 1
                    }

                    group.addTask {
                        logger.info("Dem lon \(lon) lat \(lat)")
                        let omFile = "\(Dem90().downloadDirectory)\(lat)_\(lon).om"
                        let testFile = "\(Dem90().downloadDirectory)\(lat)_\(lon).txt"
                        if FileManager.default.fileExists(atPath: omFile) || FileManager.default.fileExists(atPath: testFile) {
                            return
                        }
                        let north = lat >= 0 ? "N" : "S"
                        let east = lon >= 0 ? "E" : "W"
                        let coords = "\(north)\(abs(lat).zeroPadded(len: 2))_00_\(east)\(abs(lon).zeroPadded(len: 3))_00"

                        let tifLocal = "\(signature.path)/Copernicus_DSM_COG_30_\(coords)_DEM/Copernicus_DSM_COG_30_\(coords)_DEM.tif"
                        if !FileManager.default.fileExists(atPath: tifLocal) {
                            return
                        }

                        /*let args = [
                            "-s",
                            "--show-error",
                            "--fail", // also retry 404
                            "--insecure", // ignore expired or invalid SSL certs
                            "--retry-connrefused",
                            "--limit-rate", "10M", // Limit to 10 MB/s -> 80 Mbps
                            "-o", tifTemp,
                            "https://copernicus-dem-90m.s3.amazonaws.com/Copernicus_DSM_COG_30_\(coords)_DEM/Copernicus_DSM_COG_30_\(coords)_DEM.tif"
                        ]
                        do {
                            try Process.spawnOrDie(cmd: "curl", args: args)
                        } catch {
                            try "".write(toFile: testFile, atomically: true, encoding: .utf8)
                            continue
                        }*/

                        let ncTemp = "\(Dem90().downloadDirectory)\(lat)_\(lon)_temp.nc"

                        try Process.spawn(cmd: "gdal_translate", args: ["-of","NetCDF",tifLocal,ncTemp])
                        //try FileManager.default.removeItem(atPath: tifTemp)

                        let data = try readNc(file: ncTemp)
                        try FileManager.default.removeItem(atPath: ncTemp)

                        try data.data.writeOmFile(file: omFile, dimensions: [data.dimensions[0], data.dimensions[1]], chunks: [20, 20])
                    }
                }
            }

            try await group.waitForAll()

            var scheduledCompressions = 0

            for lat in -90..<90 {
                let file = OmFileManagerReadable.staticFile(domain: .copernicus_dem90, variable: "lat", chunk: lat)
                if FileManager.default.fileExists(atPath: file.getFilePath()) {
                    continue
                }
                try file.createDirectory()

                if scheduledCompressions >= signature.concurrentCompressions ?? 4 {
                    try await group.next()
                } else {
                    scheduledCompressions += 1
                }

                group.addTask {
                    let px = Dem90.pixel(latitude: lat)
                    var line = [Float](repeating: 0, count: 360*1200*px)
                    for lon in -180..<180 {
                        logger.info("Dem convert lon \(lon) lat \(lat)")
                        let omFile = "\(Dem90().downloadDirectory)\(lat)_\(lon).om"
                        if !FileManager.default.fileExists(atPath: omFile) {
                            continue
                        }

                        guard let om = try OmFileReader(file: omFile).asArray(of: Float.self) else {
                            fatalError("not a float array")
                        }
                        let dimensions = om.getDimensions()
                        precondition(dimensions[0] == 1200)
                        precondition(dimensions[1] == px)
                        let data = try om.read()
                        for i in 0..<1200 {
                            line[i * (px * 360) + (lon+180)*px ..< i * (px * 360) + (lon+180)*px + px] = data[i*px ..< (i+1)*px]
                        }
                    }

                    //let a2 = Array2DFastSpace(data: line, nLocations: 1200*360*px, nTime: 1)
                    //try a2.writeNetcdf(filename: "\(Dem90.downloadDirectory)lat_\(lat).nc", nx: 360*px, ny: 1200)
                    try line.writeOmFile(file: file.getFilePath(), dimensions: [1200, px*360], chunks: [60, 60])
                }
            }

            try await group.waitForAll()
        }
    }

    fileprivate func readNc(file: String) throws -> (data: [Float], dimensions: [Int]) {
        guard let file = try NetCDF.open(path: file, allowUpdate: false) else {
            fatalError("File test.nc does not exist")
        }

        guard let variable = file.getVariable(name: "Band1") else {
            fatalError("No variable named MyData available")
        }
        guard let data = try variable.asType(Float.self)?.read() else {
            fatalError("MyData is not a Float type")
        }
        return (data, variable.dimensionsFlat)
    }
}
