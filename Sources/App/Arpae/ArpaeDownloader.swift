import Foundation
import SwiftPFor2D
import Vapor
import SwiftEccodes
import NIOConcurrencyHelpers

/**
 Downloader for ARPAE domains
 */
struct DownloadArpaeCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?
        
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download a specified CMA model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        
        let domain = try ArpaeDomain.load(rawValue: signature.domain)
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let nConcurrent = signature.concurrent ?? 1
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: 1, handles: handles, concurrent: nConcurrent)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /// Download an ARPAE model from MISTRAL meteo hub
    /// 1. Fetch a metadata API to get the GRIB file name
    /// 2. Download GRIB file and convert to a temporary chunked file for later timeseries update
    /// Uses concurrent mutipart downlad and concurrent processing (Slightly overkill for this small domain)
    func download(application: Application, domain: ArpaeDomain, run: Timestamp, concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 3
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        let previous = GribDeaverager()
        
        let meta = try await waitForRun(curl: curl, domain: domain, run: run)
        let handles = try await curl.withGribStream(url: meta.url, bzip2Decode: false, nConcurrent: concurrent) { messages in
            return try await messages.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                guard let shortName = message.get(attribute: "shortName"),
                      let stepRange = message.get(attribute: "stepRange"),
                      let stepType = message.get(attribute: "stepType"),
                      let levelStr = message.get(attribute: "level"),
                      let parameterName = message.get(attribute: "parameterName"),
                      let parameterUnits = message.get(attribute: "parameterUnits"),
                      let validityTime = message.get(attribute: "validityTime"),
                      let validityDate = message.get(attribute: "validityDate")
                else {
                    fatalError("could not get attributes")
                }
                let timestamp = try Timestamp.from(yyyymmdd: "\(validityDate)\(Int(validityTime)!.zeroPadded(len: 4))")
                guard let variable = getVariable(shortName: shortName, levelStr: levelStr) else {
                    logger.debug("Unmapped GRIB message \(shortName) \(stepRange) \(stepType) \(parameterName) \(parameterUnits)")
                    return nil
                }
                //print(shortName, stepRange, stepType, levelStr, parameterName, parameterUnits, validityDate, validityTime, variable)
                //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib2d.load(message: message)
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                // Deaccumulate precipitation
                guard await previous.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                    return nil
                }
                
                let file = "\(domain.downloadDirectory)\(variable.omFileName.file)_\(timestamp.timeIntervalSince1970).om"
                try FileManager.default.removeItemIfExists(at: file)
                logger.info("Compressing and writing data to \(timestamp.format_YYYYMMddHH) \(variable)")
                let fn = try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                // Just delete file afterwards. Handle is still open, therefore file is still accessible
                try FileManager.default.removeItemIfExists(at: file)
                return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: stepType == "accum")
            }.collect().compactMap({$0})
        }
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles
    }
    
    func getVariable(shortName: String, levelStr: String) -> ArpaeSurfaceVariable? {
        switch (shortName, levelStr) {
        case ("2t", "2"):
            return .temperature_2m
        case ("tp", "0"):
            return .precipitation
        case ("pmsl", "0"):
              return .pressure_msl
        case ("t_g", "0"):
              return .surface_temperature
        case ("10v", "10"):
              return .wind_v_component_10m
        case ("10u", "10"):
              return .wind_u_component_10m
        case ("2d", "2"):
              return .dew_point_2m
        case ("clct", "0"):
              return .cloud_cover
        case ("snow_gsp", "0"):
              return .snowfall_water_equivalent
        default: return nil
        }
    }
    
    /// Check the Mistral API for a new run
    /// Uses metadata endpoint like https://meteohub.mistralportal.it/api/datasets/COSMO-2I/opendata
    fileprivate func waitForRun(curl: Curl, domain: ArpaeDomain, run: Timestamp) async throws -> ArpaeMetaResponse {
        let progress = TimeoutTracker(logger: curl.logger, deadline: Date().addingTimeInterval(2*3600))
        while true {
            guard let meta = try await curl.downloadInMemoryAsync(url: ArpaeMetaResponse.metaUrl(for: domain), minSize: nil).readJSONDecodable([ArpaeMetaResponse].self)?.first(where: {$0.date == run.iso8601_YYYY_MM_dd && $0.run == "\(run.hh):00"}) else {
                try await progress.check(error: CurlError.timeoutReached, delay: 5)
                continue
            }
            return meta
        }
    }
}

extension String {
    /// Assuming the string contains to 2 integers split by a dash like `0-10`, return both numbers
    func splitTo2Integer() -> (Int, Int)? {
        let splited = split(separator: "-")
        guard
            splited.count == 2,
            let left = Int(splited[0]),
            let right = Int(splited[1])
        else {
            return nil
        }
        return (left, right)
    }
}

/// Response of the Mistral metadata API
fileprivate struct ArpaeMetaResponse: Decodable {
    let date: String
    let run: String
    let filename: String
    
    var url: String {
        "https://meteohub.mistralportal.it/api/opendata/\(filename)"
    }
    
    static func metaUrl(for domain: ArpaeDomain) -> String {
        "https://meteohub.mistralportal.it/api/datasets/\(domain.apiName)/opendata"
    }
}

extension ByteBuffer {
    public func readJSONDecodable<T: Decodable>(_ type: T.Type) throws -> T? {
        var a = self
        return try a.readJSONDecodable(type, length: a.readableBytes)
    }
}
