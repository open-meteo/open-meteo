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
    
    
    func download(application: Application, domain: ArpaeDomain, run: Timestamp, concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 3
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        
        // download single JSON file for meta https://meteohub.mistralportal.it/api/datasets/COSMO-2I/opendata
        
        //{"date":"2024-01-30","run":"00:00","filename":"data-20240130T044559Z-93a22050-7b23-4f2c-bf93-9726657b0c7f.grib"}

        let meta = try await waitForRun(curl: curl, domain: domain, run: run)
        
        for message in try await curl.downloadGrib(url: "https://meteohub.mistralportal.it/api/opendata/\(meta.filename)", bzip2Decode: false) {
            message.dumpAttributes()
        }
        print(meta)
        
        // download single GRIB file https://meteohub.mistralportal.it/api/opendata/data-20240131T034805Z-6ae934c1-903b-4ff3-9b42-bd8636af36c7.grib
        // loop grib messages
        // return handles to chunked files
        
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        //return handles
        fatalError()
    }
    
    /// Check the Mistral API for a new run
    fileprivate func waitForRun(curl: Curl, domain: ArpaeDomain, run: Timestamp) async throws -> ArpaeMetaResponse {
        let progress = TimeoutTracker(logger: curl.logger, deadline: Date().addingTimeInterval(2*3600))
        while true {
            guard let meta = try await curl.downloadInMemoryAsync(url: "https://meteohub.mistralportal.it/api/datasets/\(domain.apiName)/opendata", minSize: nil).readJSONDecodable([ArpaeMetaResponse].self)?.first(where: {$0.date == run.iso8601_YYYY_MM_dd && $0.run == "\(run.hh):00"}) else {
                try await progress.check(error: CurlError.timeoutReached, delay: 5)
                continue
            }
            return meta
        }
    }
}

fileprivate struct ArpaeMetaResponse: Decodable {
    let date: String
    let run: String
    let filename: String
}

extension ByteBuffer {
    public func readJSONDecodable<T: Decodable>(_ type: T.Type) throws -> T? {
        var a = self
        return try a.readJSONDecodable(type, length: a.readableBytes)
    }
}
