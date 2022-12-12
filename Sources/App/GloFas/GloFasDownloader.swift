import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

struct GloFasDownloader: AsyncCommandFix {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Flag(name: "skip-existing")
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
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() -> TimerangeDt {
            if let timeinterval = timeinterval {
                guard timeinterval.count == 17, timeinterval.contains("-") else {
                    fatalError("format looks wrong")
                }
                let start = Timestamp(Int(timeinterval[0..<4])!, Int(timeinterval[4..<6])!, Int(timeinterval[6..<8])!)
                let end = Timestamp(Int(timeinterval[9..<13])!, Int(timeinterval[13..<15])!, Int(timeinterval[15..<17])!).add(86400)
                return TimerangeDt(start: start, to: end, dtSeconds: 24*3600)
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
        guard let domain = GloFasDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        switch domain {
        case .consolidatedv3:
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
            
            let timeInterval = signature.getTimeinterval()
            try downloadTimeIntervalConsolidated(logger: logger, timeinterval: timeInterval, cdskey: cdskey, domain: domain)
        case .seasonalv3:
            fallthrough
        case .forecastv3:
            let runAuto = domain == .forecastv3 ? Timestamp.now().with(hour: 0) : Timestamp.now().with(day: 1)
            let run = try signature.date.map(IsoDate.init)?.toTimestamp() ?? runAuto
            
            guard let ftpuser = signature.ftpuser else {
                fatalError("ftpuser is required")
            }
            guard let ftppassword = signature.ftppassword else {
                fatalError("ftppassword is required")
            }
            
            try await downloadEnsembleForecast(application: context.application, domain: domain, run: run, skipFilesIfExisting: signature.skipExisting, createNetcdf: signature.createNetcdf, user: ftpuser, password: ftppassword)
        }
    }
    
    /// Download the single GRIB file containing 30 days with 50 members and update the database
    func downloadEnsembleForecast(application: Application, domain: GloFasDomain, run: Timestamp, skipFilesIfExisting: Bool, createNetcdf: Bool, user: String, password: String) async throws {
        let logger = application.logger
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
        var grib2d = GribArray2D(nx: nx, ny: ny)
        
        let downloadTimeHours = domain == .forecastv3 ? 3 : 9
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: downloadTimeHours, readTimeout: 3600*downloadTimeHours)
        let directory = domain == .forecastv3 ? "fc_grib" : "seasonal_fc_grib"
        let remote = "https://\(user):\(password)@aux.ecmwf.int/ecpds/data/file/CEMS_Flood_Glofas/\(directory)/\(run.format_YYYYMMdd)/dis_\(run.format_YYYYMMddHH).grib"
        
        let nTime = domain == .forecastv3 ? 30 : 215
        
        let timerange = TimerangeDt(start: run, nTime: nTime, dtSeconds: 24*3600)
        let ringtime = timerange.toIndexTime()
        let nLocationsPerChunk = om.nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: nx*ny, chunk0: 1, chunk1: nLocationsPerChunk)
        
        // Read all GRIB messages and directly update OM file database
        // Database update is done in a second thread
        logger.info("Reading grib file")
        let timeout = TimeoutTracker(logger: logger, deadline: curl.deadline)
        while true {
            let response = try await curl.initiateDownload(url: remote, range: nil, minSize: nil)
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    let tracker = TransferAmountTracker(logger: logger, totalSize: try response.contentLength())
                    var dataPerTimestep = [Data]()
                    dataPerTimestep.reserveCapacity(nTime)
                    for try await messages in response.body.tracker(tracker).decodeGrib() {
                        for message in messages {
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
                            
                            /// Use compressed memory to store each downloaded step
                            /// Roughly 2.5 MB memory per step (uncompressed 20.6 MB)
                            dataPerTimestep.append(try writer.writeInMemory(compressionType: .p4nzdec256logarithmic, scalefactor: 1000, all: grib2d.array.data))
                            
                            guard forecastDate == nTime-1 else {
                                continue
                            }
                            // Process om file update in separat thread, otherwise the download stalls
                            let dataPerTimestepCopy = dataPerTimestep
                            dataPerTimestep.removeAll()
                            
                            group.addTask {
                                logger.info("Starting om file update for member \(member)")
                                let startOm = DispatchTime.now()
                                let name = member == 0 ? "river_discharge" : "river_discharge_member\(member.zeroPadded(len: 2))"
                                var data2d = Array2DFastTime(nLocations: nLocationsPerChunk, nTime: nTime)
                                try om.updateFromTimeOrientedStreaming(variable: name, ringtime: ringtime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: 1000, compression: .p4nzdec256logarithmic) { d0offset in
                                    
                                    let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nx*ny)
                                    for (forecastDate, data) in dataPerTimestepCopy.enumerated() {
                                        data2d[0..<data2d.nLocations, forecastDate] = try OmFileReader(fn: DataAsClass(data: data)).read(dim0Slow: 0..<1, dim1: locationRange)
                                    }
                                    return data2d.data[0..<locationRange.count * nTime]
                                }
                                
                                /*if createNetcdf {
                                    try data2d.transpose().writeNetcdf(filename: "\(name).nc", nx: nx, ny: ny)
                                }

                                try om.updateFromTimeOriented(variable: name, array2d: data2d, ringtime: ringtime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: 1000, compression: .p4nzdec256logarithmic)*/
                                logger.info("Update om for member \(member) finished in \(startOm.timeElapsedPretty())")
                            }
                        }
                    }
                    curl.totalBytesTransfered += tracker.transfered
                }
                break
            } catch {
                try await timeout.check(error: error)
            }
        }
        curl.printStatistics()
    }
    
    /// Download timeinterval and convert to omfile database
    func downloadTimeIntervalConsolidated(logger: Logger, timeinterval: TimerangeDt, cdskey: String, domain: GloFasDomain) throws {
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let gribFile = "\(downloadDir)glofasv4_temp.grib"
        
        let ny = domain.grid.ny
        let nx = domain.grid.nx
        
        let months = timeinterval.toYearMonth()
        
        /// download multiple months at once
        if months.count >= 2 {
            let year = months.lowerBound.year
            let months = months.lowerBound.month ... months.upperBound.advanced(by: -1).month
            let monthNames = ["", "january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
            let monthsJson = String(data: try JSONEncoder().encode(Array(monthNames[months])), encoding: .utf8)!
            
            logger.info("Downloading year \(year) months \(monthsJson)")
            
            let pyCode = """
                import cdsapi
                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
                
                c.retrieve(
                    'cems-glofas-historical',
                    {
                        'system_version': '\(domain.version)',
                        'variable': 'river_discharge_in_the_last_24_hours',
                        'format': 'grib',
                        'hyear': '\(year)',
                        'hmonth': \(monthsJson),
                        'hday': [
                            '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12', '13', '14', '15',
                             '16', '17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31'
                        ],
                        'hydrological_model': 'lisflood',
                        'product_type': '\(domain.productType)',
                    },
                    '\(gribFile)')
                """
            let tempPythonFile = "\(downloadDir)glofasdownload_interval.py"
            
            try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            try Process.spawn(cmd: "python3", args: [tempPythonFile])
            
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
                let pyCode = """
                    import cdsapi
                    c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
                    
                    c.retrieve(
                        'cems-glofas-historical',
                        {
                            'system_version': '\(domain.version)',
                            'variable': 'river_discharge_in_the_last_24_hours',
                            'format': 'grib',
                            'hyear': '\(day.year)',
                            'hmonth': [
                                '\(day.month.zeroPadded(len: 2))',
                            ],
                            'hday': [
                                '\(day.day.zeroPadded(len: 2))',
                            ],
                            'hydrological_model': 'lisflood',
                            'product_type': '\(domain.productType)',
                        },
                        '\(gribFile)')
                    """
                let tempPythonFile = "\(downloadDir)glofasdownload_interval.py"
                
                try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
                try Process.spawn(cmd: "python3", args: [tempPythonFile])
                
                try convertGribFileToDaily(logger: logger, domain: domain, gribFile: gribFile)
            }
        }
        
        
        logger.info("Reading to timeseries")
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
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
        let indextime = timeinterval.toIndexTime()
        try om.updateFromTimeOriented(variable: "river_discharge", array2d: data2d, ringtime: indextime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: 1000, compression: .p4nzdec256logarithmic)
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
        try FileManager.default.createDirectory(atPath: domain.omfileArchive!, withIntermediateDirectories: true)
        let gribFile = "\(downloadDir)glofasv4_\(year).grib"
        
        if !FileManager.default.fileExists(atPath: gribFile) {
            logger.info("Downloading year \(year)")
            let pyCode = """
                import cdsapi
                c = cdsapi.Client(url="https://cds.climate.copernicus.eu/api/v2", key="\(cdskey)", verify=True)
                
                c.retrieve(
                    'cems-glofas-historical',
                    {
                        'system_version': '\(domain.version)',
                        'variable': 'river_discharge_in_the_last_24_hours',
                        'format': 'grib',
                        'hyear': '\(year)',
                        'hmonth': [
                            'april', 'august', 'december',
                            'february', 'january', 'july',
                            'june', 'march', 'may',
                            'november', 'october', 'september',
                        ],
                        'hday': [
                            '01', '02', '03',
                            '04', '05', '06',
                            '07', '08', '09',
                            '10', '11', '12',
                            '13', '14', '15',
                            '16', '17', '18',
                            '19', '20', '21',
                            '22', '23', '24',
                            '25', '26', '27',
                            '28', '29', '30',
                            '31',
                        ],
                        'hydrological_model': 'lisflood',
                        'product_type': '\(domain.productType)',
                    },
                    '\(gribFile)')
                """
            let tempPythonFile = "\(downloadDir)glofasdownload.py"
            
            try pyCode.write(toFile: tempPythonFile, atomically: true, encoding: .utf8)
            try Process.spawn(cmd: "python3", args: [tempPythonFile])
        }
        
        logger.info("Converting year \(year) to daily files")
        
        try convertGribFileToDaily(logger: logger, domain: domain, gribFile: gribFile)
        
        logger.info("Converting daily files time series")
        let time = TimerangeDt(range: Timestamp(year, 1, 1) ..< Timestamp(year+1, 1, 1), dtSeconds: 3600*24)
        let nt = time.count
        let yearlyFile = "\(domain.omfileArchive!)river_discharge_\(year).om"
        
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
        try OmFileWriter(dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: time.count).write(file: yearlyFile, compressionType: .p4nzdec256logarithmic, scalefactor: 1000, supplyChunk: { dim0 in
            
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

enum GloFasDomain: String, GenericDomain {
    case consolidated
    case forecastv3
    case consolidatedv3
    case seasonalv3
    case intermediatev3
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-glofas-\(rawValue)/"
    }
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-glofas-\(rawValue)/"
    }
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)archive-glofas-\(rawValue)/"
    }
    
    var grid: Gridable {
        switch self {
        case .consolidated:
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
    
    var dtSeconds: Int {
        return 3600*24
    }
    
    var elevationFile: SwiftPFor2D.OmFileReader<MmapFile>? {
        return nil
    }
    
    /// `version_3_1` or  `version_4_0`
    var version: String {
        switch self {
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
        case .seasonalv3:
            fallthrough
        case .forecastv3:
            fatalError("should never be called")
        case .intermediatev3:
            return "intermediate"
        }
    }
    
    var omFileLength: Int {
        switch self {
        case .consolidatedv3:
            fallthrough
        case .intermediatev3:
            fallthrough
        case .consolidated:
            return 100 // 100 days per file
        case .forecastv3:
            return 60
        case .seasonalv3:
            return 215
        }
    }
}

enum GloFasVariable: String, Codable, GenericVariable {
    case river_discharge
    
    var omFileName: String {
        return rawValue
    }
    
    var scalefactor: Float {
        return 1
    }
    
    var interpolation: ReaderInterpolation {
        return .hermite(bounds: 0...10_000_000)
    }
    
    var unit: SiUnit {
        return .qubicMeterPerSecond
    }
    
    var isElevationCorrectable: Bool {
        return false
    }
    
    var requiresOffsetCorrectionForMixing: Bool {
        return false
    }
}
