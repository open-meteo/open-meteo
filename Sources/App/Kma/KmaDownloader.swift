import Foundation
import Vapor
import SwiftEccodes
import OmFileFormat

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
        
        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "server", short: "c", help: "Server prefix")
        var server: String?
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
        
        guard let server = signature.server else {
            fatalError("Option server is required")
        }
                
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, server: server)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    
    func download(application: Application, domain: KmaDomain, run: Timestamp, concurrent: Int, maxForecastHour: Int?, server: String) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours = Double(4)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: domain.ensembleMembers)
        
        let ftp = FtpDownloader()
        
        let variables = [KmaSurfaceVariable.temperature_2m]
        // 0z/12z 288, 6z/18z 87
        let forecastHours = stride(from: 0, through: run.hour % 12 == 6 ? 87 : 288, by: 3)
        
        return try await forecastHours.asyncFlatMap { forecastHour in
            return try await variables.asyncMap { variable in
                let fHHH = forecastHour.zeroPadded(len: 3)
                let url = "\(server)GDPS/UNIS/g128_v070_tmpr_unis_h\(fHHH).\(run.format_YYYYMMddHH).gb2"
                guard let data = try await ftp.get(logger: logger, url: url) else {
                    fatalError()
                }
                let (array2d, attributes) = try data.withUnsafeBytes({
                    let message = try SwiftEccodes.getMessages(memory: $0, multiSupport: true)[0]
                    let attributes = try message.getAttributes()
                    var array2d = try message.to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: true)
                    if attributes.unit == "K" {
                        array2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                    }
                    return (array2d, attributes)
                })
                
                let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: array2d.array.data)
                logger.info("Processing \(variable) timestep \(attributes.timestamp)")
                return GenericVariableHandle(
                    variable: variable,
                    time: attributes.timestamp,
                    member: 0,
                    fn: fn
                )
            }
        }
    }
}
