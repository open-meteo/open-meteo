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
        
        @Option(name: "apikey", short: "k", help: "API key for ECMWF API")
        var apikey: String?

        @Option(name: "email", help: "Email for the ECMWF API service")
        var email: String?
    }

    var help: String {
        "Download a specified ecmwf model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        //disableIdleSleep()

        let domain = try EcmwfSeasDomain.load(rawValue: signature.domain)

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun

        let logger = context.application.logger

        let nConcurrent = signature.concurrent ?? 4
        guard let server = signature.server else {
            fatalError("Parameter server is required")
        }
        
        let generateTimeSeries: Bool
        switch domain {
        case .seas5_6hourly, .seas5_12hourly, .seas5_24hourly:
            generateTimeSeries = true
        case .seas5_monthly, .seas5_monthly_upper_level, .ec46_weekly, .ec46_6hourly:
            generateTimeSeries = true
        }
        try await downloadElevation(application: context.application, apikey: signature.apikey, email: signature.email, domain: domain, createNetCdf: signature.createNetcdf)
        logger.info("Downloading domain ECMWF SEAS5 run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        let handles: [GenericVariableHandle]
        switch domain {
        case .ec46_6hourly, .ec46_weekly:
            handles = try await downloadEC46(application: context.application, domain: domain, server: server, run: run, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket)
        case .seas5_6hourly, .seas5_monthly, .seas5_12hourly, .seas5_24hourly, .seas5_monthly_upper_level:
            handles = try await download(application: context.application, domain: domain, server: server, run: run, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket)
        }
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false, generateFullRun: false, generateTimeSeries: generateTimeSeries)
    }
    
    func downloadElevation(application: Application, apikey: String?, email: String?, domain: EcmwfSeasDomain, createNetCdf: Bool) async throws {
        let logger = application.logger
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()

        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        let tempDownloadGribFile = "\(downloadDir)elevation.grib"

        if !FileManager.default.fileExists(atPath: tempDownloadGribFile) {
            logger.info("Downloading elevation and sea mask")
            switch domain {
            case .seas5_6hourly:
                guard let email else {
                    fatalError("email required")
                }
                guard let apikey else {
                    fatalError("password required")
                }
                struct Query: Encodable {
                    let `class` = "od"
                    let date = "2025-09-01"
                    let expver = 1
                    let levtype = "sfc"
                    let method = 1
                    let number = 0
                    let origin = "ecmf"
                    let param = ["129.128", "172.128"]
                    let step = 0
                    let stream = "mmsf"
                    let system = 5
                    let time = "00:00:00"
                    let type = "fc"
                }
                let client = application.makeNewHttpClient(redirectConfiguration: .disallow)
                let curl = Curl(logger: logger, client: client, deadLineHours: 99999)
                try await curl.downloadEcmwfApi(query: Query(), email: email, apikey: apikey, destinationFile: tempDownloadGribFile)
                try await client.shutdown()
            default:
                return
            }
        }

        try DownloadEra5Command.processElevationLsmGrib(domain: domain, files: [tempDownloadGribFile], createNetCdf: createNetCdf)
        try FileManager.default.removeItemIfExists(at: tempDownloadGribFile)
    }
    
    func downloadEC46(application: Application, domain: EcmwfSeasDomain, server: String, run: Timestamp, concurrent: Int, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
        Process.alarm(seconds: 12 * 3600)
        defer { Process.alarm(seconds: 0) }

        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: domain == .ec46_weekly, realm: nil)
        //let isMonthly = domain.dtSeconds >= .dtSecondsMonthly
        let isWeekly = domain.dtSeconds == 7*24*3600
        
        let package: String
        let types: [String]
        switch domain {
        case .ec46_6hourly:
            package = "e1"
            types = ["cf","pf"]
        case .ec46_weekly:
            package = "e2"
            types = ["efi", "ep", "sot", "taem"]
        default:
            fatalError()
        }
                
        let deaverager = GribDeaverager()
        for day in 0..<46 {
            let dayTimestamp = run.add(days: day)
            
            if domain.dtSeconds == 7*24*3600 && (dayTimestamp.weekday != .monday || day < 7 ) {
                // Weekly data has only data every 7 days on Monday
                continue
            }
            
            /// ope_e1_ifs-subs_od_eefo_cf_20251008T000000Z_20251008_d01.bz2
            let urls = types.map({"\(server)ope_\(package)_ifs-subs_od_eefo_\($0)_\(run.format_YYYYMMdd)T000000Z_\(dayTimestamp.format_YYYYMMdd)_d\((day+1).zeroPadded(len: 2)).bz2"})
            
            for url in urls {
                /// Single GRIB files contains multiple time-steps in mixed order
                let inMemoryAccumulated = VariablePerMemberStorage<EcmwfSeasVariableAny>()
                
                // Download and process concurrently
                try await curl.getGribStream(url: url, bzip2Decode: true, nConcurrent: concurrent, deadLineHours: 4).foreachConcurrent(nConcurrent: concurrent) { message in
                    let attributes = try message.getAttributes()
                    /// For weekly data, subtract 7 days, to make the timestamp start at a given week instead of end at a given week (forward definition)
                    let time = isWeekly ? attributes.timestamp.add(days: -7) : attributes.timestamp
                    var array2d = try message.to2D(nx: nx, ny: ny, shift180LongitudeAndFlipLatitudeIfRequired: false)
                    let member = domain.dtSeconds > 24*3600 ? 0 : message.getLong(attribute: "perturbationNumber") ?? 0
                    
                    let variable: (any EcmwfSeasVariable)?
                    switch domain {
                    case .ec46_6hourly:
                        variable = EcmwfEC46Variable6Hourly.from(shortName: attributes.shortName)
                    case .ec46_weekly:
                        variable = EcmwfEC46VariableWeekly.from(shortName: attributes.shortName, number: message.getLong(attribute: "number"))
                    default:
                        fatalError()
                    }
                    guard let variable else {
                        logger.info("Could not find variable for name=\(attributes.shortName) level=\(attributes.levelStr)")
                        return
                    }
                    if let fma = variable.multiplyAdd(dtSeconds: domain.dtSeconds) {
                        array2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    if variable.skipHour0 && run == time {
                        logger.debug("Skipping accumulated variable as forecast hour 0")
                        return
                    }
                    if variable.isAccumulated {
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
                            logger.debug("Writing accumulated variable \(variable) member \(member) unit=\(attributes.unit) timestamp \(time.format_YYYYMMddHH) backlog \(count)")
                            try await writer.write(time: time, member: member, variable: variable, data: data.data)
                        }
                        return
                    }
                    logger.debug("Processing variable \(variable) member \(member) unit=\(attributes.unit) timestamp \(time.format_YYYYMMddHH)")
                    try await writer.write(time: time, member: member, variable: variable, data: array2d.array.data)
                }
            }
        }
        return try await writer.finalise(completed: true, validTimes: nil, uploadS3Bucket: uploadS3Bucket)
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
        let isMonthly = domain.dtSeconds >= .dtSecondsMonthly
        
        let deaverager = GribDeaverager()
        for month in 0...6 {
            let monthTimestamp = run.toYearMonth().advanced(by: month).timestamp
            let monthToDownload = (runMonth + month - 1) % 12 + 1
            /// dtSeconds with the correct value for the corresponding month
            let dtSecondActual = isMonthly ? run.toYearMonth().advanced(by: month+1).timestamp.timeIntervalSince1970 - monthTimestamp.timeIntervalSince1970 : domain.dtSeconds
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
                    /// For monthly files use the monthly timestamp. Valid time in GRIB is one month ahead
                    let time = isMonthly ? monthTimestamp : attributes.timestamp
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
                    case .ec46_6hourly:
                        fatalError()
                    case .ec46_weekly:
                        fatalError()
                    }
                    guard let variable else {
                        logger.debug("Could not find variable for name=\(attributes.shortName) level=\(attributes.levelStr)")
                        return
                    }
                    if let fma = variable.multiplyAdd(dtSeconds: dtSecondActual) {
                        array2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    if variable.skipHour0 && run == time {
                        logger.debug("Skipping accumulated variable as forecast hour 0")
                        return
                    }
                    if variable.isAccumulated {
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
                            logger.debug("Writing accumulated variable \(variable) member \(member) unit=\(attributes.unit) timestamp \(time.format_YYYYMMddHH) backlog \(count)")
                            try await writer.write(time: time, member: member, variable: variable, data: data.data)
                        }
                        return
                    }
                    let timeOut = variable.shift24h ? time.add(hours: -24) : time
                    logger.debug("Processing variable \(variable) member \(member) unit=\(attributes.unit) timestamp \(timeOut.format_YYYYMMddHH)")
                    try await writer.write(time: timeOut, member: member, variable: variable, data: array2d.array.data)
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
        case .ec46_6hourly:
            return []
        case .ec46_weekly:
            return []
        }
    }
    
    var ensembleMembers: Int {
        // Note: model levels = 11 member, pressure levels full 51
        switch self {
        case .seas5_6hourly, .seas5_24hourly, .seas5_monthly, .ec46_6hourly:
            return 51
        case .seas5_12hourly, .seas5_monthly_upper_level, .ec46_weekly:
            return 11
        }
    }
    
    var lastRun: Timestamp {
        switch self {
        case .ec46_weekly,.ec46_6hourly:
            // Delay of 20 hours, one update per day
            let t = Timestamp.now()
            return t.add(hours: -19).with(hour: 0)
        default:
            return Timestamp.now().with(day: 1)
        }
    }
}
