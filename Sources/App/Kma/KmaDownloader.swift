import Foundation
import Vapor
import OmFileFormat
import SwiftEccodes

struct KmaDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
    }

    var help: String {
        "Download Kma models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try KmaDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? System.coreCount
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    
    /**
     */
    func download(application: Application, domain: KmaDomain, run: Timestamp, concurrent: Int, maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours = Double(4)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2*60))
        

        fatalError()
    }
}
