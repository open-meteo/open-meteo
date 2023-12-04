import Foundation
import Vapor
import SwiftNetCDF
import SwiftPFor2D


/**
 Download digital elevation model from Copernicus and Sinergise https://copernicus-dem-30m.s3.amazonaws.com/readme.html

 Data is stored on a S3 bucket with 1x1 degree files. Files closer to poles, have fewer resolution on longitude axis.
 Downloader is downloading 1x1 files and converting them to latitude files. E.g. every latitude has its own compressed `om` file.

 Total size after conversion `10.48 GB`
 */
struct Dem90 {
    static let downloadDirectory = "\(OpenMeteo.dataDictionary)download-dem90/"
    static let omDirectory = "\(OpenMeteo.dataDictionary)omfile-dem90/"

    /// Get elevation for coordinate. Access to om files is cached.
    static func read(lat: Float, lon: Float) throws -> Float {
        if lat < -90 || lat >= 90 || lon < -180 || lon >= 180 {
            return .nan
        }
        let lati = lat < 0 ? Int(lat) - 1 : Int(lat)
        guard let om = try OmFileManager.get(OmFilePathWithTime(basePath: Dem90.omDirectory, variable: "lat", timeChunk: lati)) else {
            // file not available
            return .nan
        }
        let latrow = Int(lat * 1200 + 90 * 1200) % 1200
        let px = pixel(latitude: lati)
        let lonrow = Int((lon + 180) * Float(px))
        return try om.read(dim0Slow: latrow..<latrow+1, dim1: lonrow..<lonrow+1)[0]
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
        try FileManager.default.createDirectory(atPath: Dem90.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: Dem90.omDirectory, withIntermediateDirectories: true)
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
                        let omFile = "\(Dem90.downloadDirectory)\(lat)_\(lon).om"
                        let testFile = "\(Dem90.downloadDirectory)\(lat)_\(lon).txt"
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

                        let ncTemp = "\(Dem90.downloadDirectory)\(lat)_\(lon)_temp.nc"

                        try Process.spawn(cmd: "gdal_translate", args: ["-of","NetCDF",tifLocal,ncTemp])
                        //try FileManager.default.removeItem(atPath: tifTemp)

                        let data = try readNc(file: ncTemp)
                        try FileManager.default.removeItem(atPath: ncTemp)


                        try OmFileWriter(dim0: data.dimensions[0], dim1: data.dimensions[1], chunk0: 20, chunk1: 20).write(file: omFile, compressionType: .p4nzdec256, scalefactor: 1, all: data.data)
                    }
                }
            }

            try await group.waitForAll()

            var scheduledCompressions = 0

            for lat in -90..<90 {
                if FileManager.default.fileExists(atPath: "\(Dem90.omDirectory)lat_\(lat).om") {
                    continue
                }

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
                        let omFile = "\(Dem90.downloadDirectory)\(lat)_\(lon).om"
                        if !FileManager.default.fileExists(atPath: omFile) {
                            continue
                        }

                        let om = try OmFileReader(file: omFile)
                        precondition(om.dim0 == 1200)
                        precondition(om.dim1 == px)
                        let data = try om.readAll()
                        for i in 0..<1200 {
                            line[i * (px * 360) + (lon+180)*px ..< i * (px * 360) + (lon+180)*px + px] = data[i*px ..< (i+1)*px]
                        }
                    }

                    //let a2 = Array2DFastSpace(data: line, nLocations: 1200*360*px, nTime: 1)
                    //try a2.writeNetcdf(filename: "\(Dem90.downloadDirectory)lat_\(lat).nc", nx: 360*px, ny: 1200)
                    try OmFileWriter(dim0: 1200, dim1: px*360, chunk0: 60, chunk1: 60).write(file: "\(Dem90.omDirectory)lat_\(lat).om", compressionType: .p4nzdec256, scalefactor: 1, all: line)
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
