import Foundation
import Vapor
import OmFileFormat
@preconcurrency import SwiftEccodes

struct GloFasDownloader: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "cdskey", short: "k", help: "CDS API key like: f412e2d2-4123-456...")
        var cdskey: String?

        @Option(name: "ftpuser", short: "u", help: "Username for the ECMWF CAMS FTP server")
        var ftpuser: String?

        @Option(name: "ftppassword", short: "p", help: "Password for the ECMWF CAMS FTP server")
        var ftppassword: String?

        @Option(name: "date", short: "d", help: "Which run date to download like 2022-12-01")
        var date: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?

        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() throws -> TimerangeDt {
            if let timeinterval = timeinterval {
                return try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 24 * 3600)
            }
            // Era5 has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            return TimerangeDt(start: Timestamp.now().with(hour: 0).add(lastDays * -86400), nTime: lastDays, dtSeconds: 86400)
        }
    }

    var help: String {
        "Download river discharge data from GloFAS"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        // let logger = context.application.logger
        let domain = try GloFasDomain.load(rawValue: signature.domain)

        switch domain {
        case .consolidatedv3, .intermediate, .intermediatev3, .consolidated:
            guard let cdskey = signature.cdskey else {
                fatalError("cds key is required")
            }
            let timeInterval = try signature.getTimeinterval()
            try await downloadTimeIntervalConsolidated(application: context.application, timeinterval: timeInterval, cdskey: cdskey, domain: domain)
        case .seasonalv3, .forecast, .seasonal, .forecastv3:
            let runAuto = domain.isForecast ? Timestamp.now().with(hour: 0) : Timestamp.now().with(day: 1)
            let run = try signature.date.map(IsoDate.init)?.toTimestamp() ?? runAuto

            guard let ftpuser = signature.ftpuser else {
                fatalError("ftpuser is required")
            }
            guard let ftppassword = signature.ftppassword else {
                fatalError("ftppassword is required")
            }

            let nConcurrent = signature.concurrent ?? 1
            let handles = try await downloadEnsembleForecast(application: context.application, domain: domain, run: run, skipFilesIfExisting: signature.skipExisting, createNetcdf: signature.createNetcdf, user: ftpuser, password: ftppassword, concurrent: nConcurrent)
            let logger = context.application.logger
            try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false, compression: .pfor_delta2d_int16_logarithmic)
        }
    }

    /// Download the single GRIB file containing 30 days with 50 members and update the database
    func downloadEnsembleForecast(application: Application, domain: GloFasDomain, run: Timestamp, skipFilesIfExisting: Bool, createNetcdf: Bool, user: String, password: String, concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)

        let downloadTimeHours: Double = domain.isForecast ? 5 : 14
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: downloadTimeHours, readTimeout: Int(3600 * downloadTimeHours))
        let directory = domain.isForecast ? "fc_grib" : "seasonal_fc_grib"
        let nMembers = domain.isForecast ? 1 : 51
        let handles = try await (0..<nMembers).asyncFlatMap { member -> [GenericVariableHandle] in
            let memberUrlStr = nMembers <= 1 ? "" : "_\(member)"
            let remote = "https://\(user):\(password)@aux.ecmwf.int/ecpds/data/file/CEMS_Flood_Glofas/\(directory)/\(run.format_YYYYMMdd)/dis_\(run.format_YYYYMMddHH)\(memberUrlStr).grib"

            return try await curl.withGribStream(url: remote, bzip2Decode: false, nConcurrent: concurrent) { messages in
                return try await messages.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                    let attributes = try message.getAttributes()
                    let member = Int(message.get(attribute: "number")!)!
                    logger.info("Processing \(attributes.timestamp.format_YYYYMMddHH) member \(member)")

                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    try grib2d.load(message: message)
                    grib2d.array.flipLatitude()

                    let writer = OmFileSplitter.makeSpatialWriter(domain: domain)
                    let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16_logarithmic, scalefactor: 1000, all: grib2d.array.data)
                    let variable = GloFasVariableAndMember(member: member)
                    return GenericVariableHandle(variable: variable, time: attributes.timestamp, member: 0, fn: fn)
                }.collect().compactMap({ $0 })
            }
        }
        await curl.printStatistics()
        return handles
    }

    struct GlofasQuery: Encodable {
        let system_version: String
        let data_format = "grib"
        let download_format = "unarchived"
        let variable = "river_discharge_in_the_last_24_hours"
        let hyear: String
        let hmonth: [String]
        let hday: [String]
        let hydrological_model = "lisflood"
        let product_type: String
    }

    /// Download timeinterval and convert to omfile database
    func downloadTimeIntervalConsolidated(application: Application, timeinterval: TimerangeDt, cdskey: String, domain: GloFasDomain) async throws {
        let logger = application.logger
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        let gribFile = "\(downloadDir)glofasv4_temp.grib"

        let ny = domain.grid.ny
        let nx = domain.grid.nx

        let months = timeinterval.toYearMonth()

        /// download multiple months at once
        if months.count >= 2 {
            let year = months.lowerBound.year
            let months = months.lowerBound.month ... months.upperBound.advanced(by: -1).month
            let monthNames = ["", "january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]

            logger.info("Downloading year \(year) months \(months)")
            let query = GlofasQuery(
                system_version: domain.version,
                hyear: "\(year)",
                hmonth: Array(monthNames[months]),
                hday: (0...31).map { $0.zeroPadded(len: 2) },
                product_type: domain.productType
            )
            let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 24)
            try await curl.downloadCdsApi(
                dataset: "cems-glofas-historical",
                query: query,
                apikey: cdskey,
                destinationFile: gribFile
            )
            try convertGribFileToDaily(logger: logger, domain: domain, gribFile: gribFile)
        } else {
            // download day by day
            for date in timeinterval {
                logger.info("Downloading date \(date.format_YYYYMMdd)")

                let dailyFile = "\(downloadDir)glofas_\(date.format_YYYYMMdd).om"
                if FileManager.default.fileExists(atPath: dailyFile) {
                    continue
                }

                let day = date.toComponents()

                let query = GlofasQuery(
                    system_version: domain.version,
                    hyear: "\(day.year)",
                    hmonth: ["\(day.month.zeroPadded(len: 2))"],
                    hday: ["\(day.day.zeroPadded(len: 2))"],
                    product_type: domain.productType
                )
                let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 24)
                try await curl.downloadCdsApi(
                    dataset: "cems-glofas-historical",
                    query: query,
                    apikey: cdskey,
                    destinationFile: gribFile
                )
                try convertGribFileToDaily(logger: logger, domain: domain, gribFile: gribFile)
            }
        }

        logger.info("Reading to timeseries")
        let om = OmFileSplitter(domain)
        var data2d = Array2DFastTime(nLocations: nx * ny, nTime: timeinterval.count)
        for (i, date) in timeinterval.enumerated() {
            logger.info("Reading \(date.format_YYYYMMdd)")
            let file = "\(downloadDir)glofas_\(date.format_YYYYMMdd).om"
            guard FileManager.default.fileExists(atPath: file),
                    let dailyFile = try OmFileReader(file: file).asArray(of: Float.self)
            else {
                continue
            }
            data2d[0..<nx * ny, i] = try dailyFile.read()
        }
        logger.info("Update om database")
        try om.updateFromTimeOriented(variable: "river_discharge", array2d: data2d, time: timeinterval, scalefactor: 1000, compression: .pfor_delta2d_int16_logarithmic)
    }

    /// Convert a single file
    func convertGribFileToDaily(logger: Logger, domain: GloFasDomain, gribFile: String) throws {
        let ny = domain.grid.ny
        let nx = domain.grid.nx
        // 21k locations -> 30MB chunks for 1 year
        // let nLocationChunk = nx * ny / 1000
        var grib2d = GribArray2D(nx: nx, ny: ny)

        try SwiftEccodes.iterateMessages(fileName: gribFile, multiSupport: true) { message in
            /// Date in ISO timestamp string format `20210101`
            let date = message.get(attribute: "dataDate")!
            logger.info("Converting day \(date)")
            let dailyFile = "\(domain.downloadDirectory)glofas_\(date).om"
            if FileManager.default.fileExists(atPath: dailyFile) {
                return
            }
            try grib2d.load(message: message)
            grib2d.array.flipLatitude()
            // try grib2d.array.writeNetcdf(filename: "\(downloadDir)glofas_\(date).nc")

            let writer = OmFileSplitter.makeSpatialWriter(domain: domain, nMembers: 1)
            try writer.write(file: dailyFile, compressionType: .pfor_delta2d_int16_logarithmic, scalefactor: 1000, all: grib2d.array.data)
        }
    }
}

enum GloFasDomain: String, GenericDomain, CaseIterable {
    case forecast
    case consolidated
    case seasonal
    case intermediate

    case forecastv3
    case consolidatedv3
    case seasonalv3
    case intermediatev3

    var domainRegistry: DomainRegistry {
        switch self {
        case .forecast:
            return .glofas_forecast_v4
        case .consolidated:
            return .glofas_consolidated_v4
        case .seasonal:
            return .glofas_seasonal_v4
        case .intermediate:
            return .glofas_intermediate_v4
        case .forecastv3:
            return .glofas_forecast_v3
        case .consolidatedv3:
            return .glofas_consolidated_v3
        case .seasonalv3:
            return .glofas_seasonal_v3
        case .intermediatev3:
            return .glofas_intermediate_v3
        }
    }

    var domainRegistryStatic: DomainRegistry? {
        return nil
    }

    var hasYearlyFiles: Bool {
        switch self {
        case .consolidated, .consolidatedv3:
            return true
        default:
            return false
        }
    }

    var masterTimeRange: Range<Timestamp>? {
        return nil
    }

    var grid: Gridable {
        switch self {
        case .consolidated, .intermediate, .seasonal, .forecast:
            return RegularGrid(nx: 7200, ny: 3000, latMin: -60, lonMin: -180, dx: 0.05, dy: 0.05)
        case .consolidatedv3, .intermediatev3, .seasonalv3, .forecastv3:
            return RegularGrid(nx: 3600, ny: 1500, latMin: -60, lonMin: -180, dx: 0.1, dy: 0.1)
        }
    }

    var isForecast: Bool {
        switch self {
        case .forecast, .forecastv3:
            return true
        default: return false
        }
    }

    var dtSeconds: Int {
        return 3600 * 24
    }

    /// `version_3_1` or  `version_4_0`
    var version: String {
        switch self {
        case .seasonal:
            fatalError("should never be called")
        case .forecast, .intermediate, .consolidated:
            return "version_4_0"
        case .forecastv3, .seasonalv3:
            fatalError("should never be called")
        case.intermediatev3, .consolidatedv3:
            return "version_3_1"
        }
    }

    /// `intermediate` or `consolidated`
    var productType: String {
        switch self {
        case .consolidatedv3, .consolidated:
            return "consolidated"
        case .forecast, .seasonal, .seasonalv3, .forecastv3:
            fatalError("should never be called")
        case .intermediatev3, .intermediate:
            return "intermediate"
        }
    }

    var omFileLength: Int {
        switch self {
        case .consolidatedv3, .intermediate, .intermediatev3, .consolidated:
            return 100 // 100 days per file
        case .forecastv3:
            return 60
        case .seasonalv3:
            return 215
        case .forecast:
            return 60
        case .seasonal:
            return 215
        }
    }

    var updateIntervalSeconds: Int {
        switch self {
        case .forecast:
            return 12 * 3600
        case .consolidated:
            return 0
        case .seasonal:
            return 12 * 3600
        case .intermediate:
            return 0
        case .forecastv3:
            return 12 * 3600
        case .consolidatedv3:
            return 0
        case .seasonalv3:
            return 12 * 3600
        case .intermediatev3:
            return 0
        }
    }
}

enum GloFasVariable: String, GenericVariable {
    case river_discharge

    var storePreviousForecast: Bool {
        return false
    }

    var omFileName: (file: String, level: Int) {
        return (rawValue, 0)
    }

    var scalefactor: Float {
        return 1
    }

    var interpolation: ReaderInterpolation {
        return .hermite(bounds: 0...10_000_000)
    }

    var unit: SiUnit {
        return .cubicMetrePerSecond
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}

/// Variable to store each member in its own file
fileprivate struct GloFasVariableAndMember: GenericVariable {
    let member: Int

    init(member: Int) {
        self.member = member
    }

    var omFileName: (file: String, level: Int) {
        let name = member == 0 ? "river_discharge" : "river_discharge_member\(member.zeroPadded(len: 2))"
        return (name, 0)
    }

    var scalefactor: Float {
        return 1000
    }

    var interpolation: ReaderInterpolation {
        return .linear
    }

    var unit: SiUnit {
        return .cubicMetrePerSecond
    }

    var isElevationCorrectable: Bool {
        return false
    }

    var storePreviousForecast: Bool {
        return false
    }

    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }

    init?(rawValue: String) {
        fatalError()
    }

    var rawValue: String {
        return omFileName.file
    }
}
