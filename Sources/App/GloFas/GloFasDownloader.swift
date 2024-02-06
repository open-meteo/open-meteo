import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

struct GloFasDownloader: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        @Option(name: "ftpuser", short: "u", help: "Username for the ECMWF CAMS FTP server")
        var ftpuser: String?
        
        @Option(name: "ftppassword", short: "p", help: "Password for the ECMWF CAMS FTP server")
        var ftppassword: String?
        
        @Option(name: "date", short: "d", help: "Which run date to download like 2022-12-01")
        var date: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() throws -> TimerangeDt {
            if let timeinterval = timeinterval {
                return try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 24*3600)
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
        let logger = context.application.logger
        let domain = try GloFasDomain.load(rawValue: signature.domain)
        
        switch domain {
        case .consolidatedv3:
            fallthrough
        case .intermediate:
            fallthrough
        case .intermediatev3:
            fallthrough
        case .consolidated:
            guard let cdskey = signature.cdskey else {
                fatalError("cds key is required")
            }
            /// Only download one specified year
            if let yearStr = signature.year {
                if yearStr.contains("-") {
                    let split = yearStr.split(separator: "-")
                    guard split.count == 2 else {
                        fatalError("year invalid")
                    }
                    for year in Int(split[0])! ... Int(split[1])! {
                        try downloadYear(logger: logger, year: year, cdskey: cdskey, domain: domain)
                    }
                } else {
                    guard let year = Int(yearStr) else {
                        fatalError("Could not convert year to integer")
                    }
                    try downloadYear(logger: logger, year: year, cdskey: cdskey, domain: domain)
                }
                return
            }
            
            let timeInterval = try signature.getTimeinterval()
            try downloadTimeIntervalConsolidated(logger: logger, timeinterval: timeInterval, cdskey: cdskey, domain: domain)
        case .seasonalv3:
            fallthrough
        case .forecast:
            fallthrough
        case .seasonal:
            fallthrough
        case .forecastv3:
            let runAuto = domain.isForecast ? Timestamp.now().with(hour: 0) : Timestamp.now().with(day: 1)
            let run = try signature.date.map(IsoDate.init)?.toTimestamp() ?? runAuto
            
            guard let ftpuser = signature.ftpuser else {
                fatalError("ftpuser is required")
            }
            guard let ftppassword = signature.ftppassword else {
                fatalError("ftppassword is required")
            }
            
            try await downloadEnsembleForecast(application: context.application, domain: domain, run: run, skipFilesIfExisting: signature.skipExisting, createNetcdf: signature.createNetcdf, user: ftpuser, password: ftppassword)
        }
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: nil)
        }
    }
    
    /// Download the single GRIB file containing 30 days with 50 members and update the database
    func downloadEnsembleForecast(application: Application, domain: GloFasDomain, run: Timestamp, skipFilesIfExisting: Bool, createNetcdf: Bool, user: String, password: String) async throws {
        let logger = application.logger
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let om = OmFileSplitter(domain)
        var grib2d = GribArray2D(nx: nx, ny: ny)
        
        let downloadTimeHours: Double = domain.isForecast ? 5 : 14
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: downloadTimeHours, readTimeout: Int(3600*downloadTimeHours))
        let directory = domain.isForecast ? "fc_grib" : "seasonal_fc_grib"
        let remote = "https://\(user):\(password)@aux.ecmwf.int/ecpds/data/file/CEMS_Flood_Glofas/\(directory)/\(run.format_YYYYMMdd)/dis_\(run.format_YYYYMMddHH).grib"
        
        let nTime = domain.isForecast ? 30 : 215
        
        // forecast day 0 is valid for the next day
        let timerange = TimerangeDt(start: run.add(24*3600), nTime: nTime, dtSeconds: 24*3600)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: nx*ny, chunk0: 1, chunk1: nLocationsPerChunk)
        
        // Read all GRIB messages and directly update OM file database
        // Database update is done in a second thread
        logger.info("Starting grib streaming. nLocationsPerChunk=\(nLocationsPerChunk) nTime=\(nTime)")
        let timeout = TimeoutTracker(logger: logger, deadline: curl.deadline)
        
        actor Counter {
            var count = 0
            
            func inc() {
                count += 1
            }
            
            func dec() {
                count -= 1
            }
        }
        
        while true {
            let response = try await curl.initiateDownload(url: remote, range: nil, minSize: nil, deadline: Date().addingTimeInterval(TimeInterval(downloadTimeHours * 3600)), nConcurrent: 1, waitAfterLastModifiedBeforeDownload: nil)
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    let counter = Counter()
                    let tracker = TransferAmountTracker(logger: logger, totalSize: try response.contentLength())
                    var dataPerTimestep = [OmFileReader<DataAsClass>]()
                    dataPerTimestep.reserveCapacity(nTime)
                    for try await message in response.body.tracker(tracker).decodeGrib() {
                        let date = message.get(attribute: "validityDate")!
                        /// 0 = control
                        let member = Int(message.get(attribute: "number")!)!
                        /// Which forecast date... range from 0 to 29 or 214
                        let forecastDate = Int(message.get(attribute: "startStep")!)!/24
                        guard message.get(attribute: "shortName") == "dis24" else {
                            fatalError("Unknown variable")
                        }
                        
                        logger.info("Converting day \(date) Member \(member) forecastDate \(forecastDate)")
                        let dailyFile = "\(domain.downloadDirectory)river_discharge_member\(member.zeroPadded(len: 2))_\(date).om"
                        try FileManager.default.removeItemIfExists(at: dailyFile)
                        try grib2d.load(message: message)
                        grib2d.array.flipLatitude()
                        
                        // iterates from 0 to 29 forecast date and then updates om file
                        guard forecastDate <= nTime else {
                            fatalError("Got more data than expected \(forecastDate)")
                        }
                        
                        // If conversion is running, reduce download speed
                        if await counter.count > 0 {
                            try await Task.sleep(nanoseconds: 5_000_000_000)
                        }
                        
                        /// Use compressed memory to store each downloaded step
                        /// Roughly 2.5 MB memory per step (uncompressed 20.6 MB)
                        dataPerTimestep.append(try OmFileReader(fn: DataAsClass(data: try writer.writeInMemory(compressionType: .p4nzdec256logarithmic, scalefactor: 1000, all: grib2d.array.data))))
                        
                        guard forecastDate == nTime-1 else {
                            continue
                        }
                        // Process om file update in separat thread, otherwise the download stalls
                        let dataPerTimestepCopy = dataPerTimestep
                        dataPerTimestep.removeAll()
                        
                        group.addTask {
                            await counter.inc()
                            logger.info("Starting om file update for member \(member)")
                            let progress = ProgressTracker(logger: logger, total: nx*ny, label: "Conversion member \(member)")
                            let name = member == 0 ? "river_discharge" : "river_discharge_member\(member.zeroPadded(len: 2))"
                            var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
                            /// Reused read buffer
                            var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
                            try om.updateFromTimeOrientedStreaming(variable: name, time: timerange, skipFirst: 0, scalefactor: 1000, compression: .p4nzdec256logarithmic, storePreviousForecast: false) { d0offset in
                                
                                try Task.checkCancellation()
                                
                                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nx*ny)
                                for (forecastDate, data) in dataPerTimestepCopy.enumerated() {
                                    try data.read(into: &readTemp, arrayDim1Range: 0..<locationRange.count, arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                                    data2d[0..<data2d.nLocations, forecastDate] = readTemp
                                }
                                
                                progress.add(locationRange.count)
                                
                                return data2d.data[0..<locationRange.count * nTime]
                            }
                            progress.finish()
                            await counter.dec()
                        }
                    }
                    await curl.totalBytesTransfered.add(tracker.transfered)
                }
                break
            } catch {
                try await timeout.check(error: error)
            }
        }
        await curl.printStatistics()
    }
    
    struct GlofasQuery: Encodable {
        let system_version: String
        let format = "grib"
        let variable = "river_discharge_in_the_last_24_hours"
        let hyear: String
        let hmonth: [String]
        let hday: [String]
        let hydrological_model = "lisflood"
        let product_type: String
    }
    
    /// Download timeinterval and convert to omfile database
    func downloadTimeIntervalConsolidated(logger: Logger, timeinterval: TimerangeDt, cdskey: String, domain: GloFasDomain) throws {
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
                hday: (0...31).map{$0.zeroPadded(len: 2)},
                product_type: domain.productType
            )
            try Process.cdsApi(
                dataset: "cems-glofas-historical",
                key: cdskey,
                query: query,
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
                try Process.cdsApi(
                    dataset: "cems-glofas-historical",
                    key: cdskey,
                    query: query,
                    destinationFile: gribFile
                )
                try convertGribFileToDaily(logger: logger, domain: domain, gribFile: gribFile)
            }
        }
        
        
        logger.info("Reading to timeseries")
        let om = OmFileSplitter(domain)
        var data2d = Array2DFastTime(nLocations: nx*ny, nTime: timeinterval.count)
        for (i, date) in timeinterval.enumerated() {
            logger.info("Reading \(date.format_YYYYMMdd)")
            let file = "\(downloadDir)glofas_\(date.format_YYYYMMdd).om"
            guard FileManager.default.fileExists(atPath: file) else {
                continue
            }
            let dailyFile = try OmFileReader(file: file)
            data2d[0..<nx*ny, i] = try dailyFile.readAll()
        }
        logger.info("Update om database")
        try om.updateFromTimeOriented(variable: "river_discharge", array2d: data2d, time: timeinterval, skipFirst: 0, scalefactor: 1000, compression: .p4nzdec256logarithmic, storePreviousForecast: false)
    }
    
    /// Convert a single file
    func convertGribFileToDaily(logger: Logger, domain: GloFasDomain, gribFile: String) throws {
        let ny = domain.grid.ny
        let nx = domain.grid.nx
        // 21k locations -> 30MB chunks for 1 year
        let nLocationChunk = nx * ny / 1000
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
            //try grib2d.array.writeNetcdf(filename: "\(downloadDir)glofas_\(date).nc")
           
            try OmFileWriter(dim0: ny*nx, dim1: 1, chunk0: nLocationChunk, chunk1: 1).write(file: dailyFile, compressionType: .p4nzdec256logarithmic, scalefactor: 1000, all: grib2d.array.data)
        }
    }
    
    /// Download and convert entire year to yearly files
    func downloadYear(logger: Logger, year: Int, cdskey: String, domain: GloFasDomain) throws {
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        let gribFile = "\(downloadDir)glofasv4_\(year).grib"
        
        if !FileManager.default.fileExists(atPath: gribFile) {
            logger.info("Downloading year \(year)")
            let query = GlofasQuery(
                system_version: domain.version,
                hyear: "\(year)",
                hmonth: ["april", "august", "december", "february", "january", "july",
                          "june", "march", "may", "november", "october", "september"],
                hday: (0...31).map{$0.zeroPadded(len: 2)},
                product_type: domain.productType
            )
            try Process.cdsApi(
                dataset: "cems-glofas-historical",
                key: cdskey,
                query: query,
                destinationFile: gribFile
            )
        }
        
        logger.info("Converting year \(year) to daily files")
        
        try convertGribFileToDaily(logger: logger, domain: domain, gribFile: gribFile)
        
        logger.info("Converting daily files time series")
        let time = TimerangeDt(range: Timestamp(year, 1, 1) ..< Timestamp(year+1, 1, 1), dtSeconds: 3600*24)
        let nt = time.count
        let yearlyFile = OmFileManagerReadable.domainChunk(domain: domain.domainRegistry, variable: "river_discharge", type: .year, chunk: year, ensembleMember: 0, previousDay: 0)
        
        let omFiles = try time.map { time -> OmFileReader in
            let omFile = "\(downloadDir)glofas_\(time.format_YYYYMMdd).om"
            return try OmFileReader(file: omFile)
        }
        
        let ny = domain.grid.ny
        let nx = domain.grid.nx
        // 21k locations -> 30MB chunks for 1 year
        let nLocationChunk = nx * ny / 1000
        var percent = 0
        var looptime = DispatchTime.now()
        // Scale logarithmic. Max discharge around 400_000 m3/s
        // Note: delta 2d coding (chunk0=6) save around 15% space
        try OmFileWriter(dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: time.count).write(file: yearlyFile.getFilePath(), compressionType: .p4nzdec256logarithmic, scalefactor: 1000, overwrite: false, supplyChunk: { dim0 in
            
            let ratio = Int(Float(dim0) / (Float(nx*ny)) * 100)
            if percent != ratio {
                /// time ~4.5 seconds
                logger.info("\(ratio) %, time per step \(looptime.timeElapsedPretty())")
                looptime = DispatchTime.now()
                percent = ratio
            }
            
            /// Process around 360 MB memory at once
            let locationRange = dim0..<min(dim0+nLocationChunk, nx*ny)
            
            var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt * locationRange.count), nLocations: locationRange.count, nTime: nt)
            
            for (i, omfile) in omFiles.enumerated() {
                try omfile.willNeed(dim0Slow: locationRange, dim1: 0..<1)
                let read = try omfile.read(dim0Slow: locationRange, dim1: 0..<1)
                let read2d = Array2DFastTime(data: read, nLocations: locationRange.count, nTime: 1)
                for l in 0..<locationRange.count {
                    fasttime[l, i ..< (i+1)] = read2d[l, 0..<1]
                }
            }
            return ArraySlice(fasttime.data)
        })
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
        case .consolidated:
            fallthrough
        case .intermediate:
            fallthrough
        case .seasonal:
            fallthrough
        case .forecast:
            return RegularGrid(nx: 7200, ny: 3000, latMin: -60, lonMin: -180, dx: 0.05, dy: 0.05)
        case .consolidatedv3:
            fallthrough
        case .intermediatev3:
            fallthrough
        case .seasonalv3:
            fallthrough
        case .forecastv3:
            return RegularGrid(nx: 3600, ny: 1500, latMin: -60, lonMin: -180, dx: 0.1, dy: 0.1)
        }
    }
    
    var isForecast: Bool {
        switch self {
        case .forecast:
            fallthrough
        case .forecastv3:
            return true
        default: return false
        }
    }
    
    var dtSeconds: Int {
        return 3600*24
    }
    
    /// `version_3_1` or  `version_4_0`
    var version: String {
        switch self {
        case .seasonal:
            fatalError("should never be called")
        case .forecast:
            fallthrough
        case .intermediate:
            fallthrough
        case .consolidated:
            return "version_4_0"
        case .forecastv3:
            fallthrough
        case .seasonalv3:
            fatalError("should never be called")
        case.intermediatev3:
            fallthrough
        case .consolidatedv3:
            return "version_3_1"
        }
    }
    
    /// `intermediate` or `consolidated`
    var productType: String {
        switch self {
        case .consolidatedv3:
            fallthrough
        case .consolidated:
            return "consolidated"
        case .forecast:
            fallthrough
        case .seasonal:
            fallthrough
        case .seasonalv3:
            fallthrough
        case .forecastv3:
            fatalError("should never be called")
        case .intermediatev3:
            fallthrough
        case .intermediate:
            return "intermediate"
        }
    }
    
    var omFileLength: Int {
        switch self {
        case .consolidatedv3:
            fallthrough
        case .intermediate:
            fallthrough
        case .intermediatev3:
            fallthrough
        case .consolidated:
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
