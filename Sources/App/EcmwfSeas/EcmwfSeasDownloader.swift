import Foundation
import OmFileFormat
import Vapor

/**
 Download ECMWF seasonal forecast
 */
struct DownloadEcmwfSeasCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?

        @Option(name: "server", help: "Server to download from")
        var server: String?

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download a specified ecmwf model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        let domain = try EcmwfSeasDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? Timestamp.now().with(day: 0)

        let logger = context.application.logger

        let nConcurrent = signature.concurrent ?? 4
        guard let server = signature.server else {
            fatalError("Parameter server is required")
        }
        
        logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        let handles = try await download(application: context.application, domain: domain, server: server, run: run, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }

    func download(application: Application, domain: EcmwfSeasDomain, server: String, run: Timestamp, concurrent: Int, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        Process.alarm(seconds: 12 * 3600)
        defer { Process.alarm(seconds: 0) }

        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let runMonth = run.toComponents().month
        
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil)

        
        for month in 0...7 {
            let monthToDownload = (runMonth + month - 1) % 12 + 1
            let file = "A1L\(runMonth.zeroPadded(len: 2))\010000\(monthToDownload.zeroPadded(len: 2))______1"
            let url = "\(server)\(file)"
            
            let deaverager = GribDeaverager()
            // Download and process concurrently
            let messages = try await curl.getGribStream(url: url, bzip2Decode: false, nConcurrent: concurrent, deadLineHours: 4).mapStream(nConcurrent: concurrent) { message in
                
                let attributes = try message.getAttributes()
                let time = attributes.timestamp
                let member = 0
                var array2d = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false)
                let member = message.getLong(attribute: "perturbationNumber") ?? 0
                /*switch v.variable {
                case .T, .TD_2M, .T_2M, .T_SO:
                    array2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                case .PMSL:
                    array2d.array.data.multiplyAdd(multiply: 1 / 100, add: 0)
                case .FI:
                    // convert geopotential to height (WMO defined gravity constant)
                    array2d.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0)
                default:
                    break
                }*/
                
                // Deaccumulate precipitation
                guard await deaverager.deaccumulateIfRequired(variable: v, member: member, stepType: attributes.stepType.rawValue, stepRange: attributes.stepRange, grib2d: &array2d) else {
                    continue
                }

                if let variable = v.variable.getGenericVariable(attributes: attributes) {
                    try await writer.write(time: time, member: 0, variable: variable, data: array2d.array.data)
                }
            }
            
            
        }
        
        //return try await writer.finalise(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket) + (writerProbabilities?.finalise(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket) ?? [])
        
        fatalError()
    }
}
