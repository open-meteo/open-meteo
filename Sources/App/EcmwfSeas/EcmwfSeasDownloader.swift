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
        //disableIdleSleep()

        let domain = try EcmwfSeasDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? Timestamp.now().with(day: 1)

        let logger = context.application.logger

        let nConcurrent = signature.concurrent ?? 4
        guard let server = signature.server else {
            fatalError("Parameter server is required")
        }
        
        let generateTimeSeries: Bool
        switch domain {
        case .seas5_6hourly, .seas5_12hourly, .seas5_24hourly:
            generateTimeSeries = false
        case .seas5_monthly, .seas5_monthly_upper_level:
            generateTimeSeries = true
        }
        
        logger.info("Downloading domain ECMWF SEAS5 run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        let handles = try await download(application: context.application, domain: domain, server: server, run: run, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false, generateTimeSeries: generateTimeSeries)
    }

    func download(application: Application, domain: EcmwfSeasDomain, server: String, run: Timestamp, concurrent: Int, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        Process.alarm(seconds: 12 * 3600)
        defer { Process.alarm(seconds: 0) }

        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let runMonth = run.toComponents().month
        let storeOnDisk = domain == .seas5_monthly || domain == .seas5_monthly_upper_level
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: storeOnDisk, realm: nil)

        let deaverager = GribDeaverager()
        for month in 0...6 {
            let monthToDownload = (runMonth + month - 1) % 12 + 1
            for package in domain.downloadPackages {
                if package == 1 && month == 6 {
                    continue
                }
                let file = "A\(package)L\(runMonth.zeroPadded(len: 2))010000\(monthToDownload.zeroPadded(len: 2))______1"
                let url = "\(server)\(file)"
                
                /// Single GRIB files contains multiple time-steps in mixed order
                let inMemoryAccumulated = VariablePerMemberStorage<EcmwfSeasVariableAny>()
                
                // Download and process concurrently
                try await curl.getGribStream(url: url, bzip2Decode: false, nConcurrent: concurrent, deadLineHours: 4).foreachConcurrent(nConcurrent: concurrent) { message in
                    let attributes = try message.getAttributes()
                    let time = attributes.timestamp
                    var array2d = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false)
                    let member = message.getLong(attribute: "perturbationNumber") ?? 0
                    
                    let variable: (any EcmwfSeasVariable)?
                    switch domain {
                    case .seas5_6hourly:
                        variable = EcmwfSeasVariableSingleLevel.from(shortName: attributes.shortName)
                    case .seas5_12hourly:
                        variable = EcmwfSeasVariableUpperLevel.from(shortName: attributes.shortName, level: attributes.levelStr)
                    case .seas5_24hourly:
                        variable = EcmwfSeasVariable24HourlySingleLevel.from(shortName: attributes.shortName)
                    case .seas5_monthly_upper_level:
                        variable = nil
                    case .seas5_monthly:
                        variable = EcmwfSeasVariableMonthly.from(shortName: attributes.shortName)
                    }
                    guard let variable else {
                        logger.debug("Could not find variable for name=\(attributes.shortName) level=\(attributes.levelStr)")
                        return
                    }
                    if let fma = variable.multiplyAdd {
                        array2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    if variable.isAccumulated {
                        if run == time {
                            logger.debug("Skipping accumulated variable as forecast hour 0")
                            return
                        }
                        // Collect all accumulated variables and process them as soon as they are in sequential order
                        await inMemoryAccumulated.set(variable: .init(variable: variable), timestamp: time, member: member, data: array2d.array)
                        while true {
                            let step = (await deaverager.lastStep(variable, member) ?? 0) + domain.dtHours
                            let time = run.add(hours: step)
                            guard var data = await inMemoryAccumulated.remove(variable: EcmwfSeasVariableAny(variable: variable), timestamp: time, member: member) else {
                                break
                            }
                            guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: "accum", stepRange: "0-\(step)", array2d: &data) else {
                                continue
                            }
                            let count = await inMemoryAccumulated.data.count
                            logger.debug("Writing accumulated variable \(variable) member \(member) timestamp \(time.format_YYYYMMddHH) backlog \(count)")
                            try await writer.write(time: time, member: member, variable: variable, data: data.data)
                        }
                        return
                    }
                    logger.debug("Processing variable \(variable) member \(member) timestamp \(time.format_YYYYMMddHH)")
                    // TODO On the fly conversions: Specific humidity to relative humidity, needs pressure
                    try await writer.write(time: time, member: member, variable: variable, data: array2d.array.data)
                }
            }
        }
        return try await writer.finalise(completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
    }
}

extension EcmwfSeasDomain {
    /**
     A1: 12h model levels N160 (only 6 months)
     A2: 6h single levels O320
     A3: 24h single levels O320
     A4: 12h pressure levels N160
     A5: monthly single level means O320
     A6: monthly pressure level means N160
     A7: monthly single level anomaly O320
     A8: monthly pressure level anomalies N160
     */
    var downloadPackages: [Int] {
        switch self {
        case .seas5_6hourly:
            return [2]
        case .seas5_12hourly:
            return [1, 4]
        case .seas5_24hourly:
            return [3]
        case .seas5_monthly_upper_level:
            return [6, 8]
        case .seas5_monthly:
            return [5, 7]
        }
    }
    
    var ensembleMembers: Int {
        // Note: model levels = 11 member, pressure levels full 51
        switch self {
        case .seas5_6hourly, .seas5_24hourly, .seas5_monthly:
            return 51
        case .seas5_12hourly, .seas5_monthly_upper_level:
            return 11
        }
    }
}
