import Foundation
import SwiftEccodes
import Vapor
import SwiftPFor2D


enum CdsDomain: String, GenericDomain {
    case era5
    case era5_land
    case cerra
    
    var dtSeconds: Int {
        return 3600
    }
    
    var isGlobal: Bool {
        self != .cerra
    }
    
    var elevationFile: OmFileReader<MmapFile>? {
        switch self {
        case .era5:
            return Self.era5ElevationFile
        case .era5_land:
            return Self.era5LandElevationFile
        case .cerra:
            return Self.cerraElevationFile
        }
    }
    
    var cdsDatasetName: String {
        switch self {
        case .era5:
            return "reanalysis-era5-single-levels"
        case .era5_land:
            return "reanalysis-era5-land"
        case .cerra:
            return "reanalysis-cerra-single-levels"
        }
    }
    
    private static var era5ElevationFile = try? OmFileReader(file: Self.era5.surfaceElevationFileOm)
    private static var era5LandElevationFile = try? OmFileReader(file: Self.era5_land.surfaceElevationFileOm)
    private static var cerraElevationFile = try? OmFileReader(file: Self.cerra.surfaceElevationFileOm)
    
    /// Filename of the surface elevation file
    var surfaceElevationFileOm: String {
        "\(omfileDirectory)HSURF.om"
    }
    
    var downloadDirectory: String {
        return "\(OpenMeteo.dataDictionary)download-\(rawValue)/"
    }
    
    var omfileDirectory: String {
        return "\(OpenMeteo.dataDictionary)omfile-\(rawValue)//"
    }
    
    var omfileArchive: String? {
        return "\(OpenMeteo.dataDictionary)yearly-\(rawValue)//"
    }
    
    /// Use store 14 days per om file
    var omFileLength: Int {
        // 24 hours over 21 days = 504 timesteps per file
        // Afterwards the om compressor will combine 6 locations to one chunks
        // 6 * 504 = 3024 values per compressed chunk
        // In case for a 1 year API call, around 51 kb will have to be decompressed with 34 IO operations
        return 24 * 21
    }
    
    var grid: Gridable {
        switch self {
        case .era5:
            return RegularGrid(nx: 1440, ny: 721, latMin: -90, lonMin: -180, dx: 0.25, dy: 0.25)
        case .era5_land:
            return RegularGrid(nx: 3600, ny: 1801, latMin: -90, lonMin: -180, dx: 0.1, dy: 0.1)
        case .cerra:
            return ProjectionGrid(nx: 1069, ny: 1069, latitude: 20.29228...63.769516, longitude: -17.485962...74.10509, projection: LambertConformalConicProjection(λ0: 8, ϕ0: 50, ϕ1: 50, ϕ2: 50))
        }
    }
}

struct DownloadEra5Command: AsyncCommandFix {
    /// 6k locations require around 200 MB memory for a yearly time-series
    static var nLocationsPerChunk = 6_000
    
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Option(name: "stripseaYear", short: "s", help: "strip sea of converted files")
        var stripseaYear: String?
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        @Flag(name: "force", short: "f", help: "Force to update given timeinterval, regardless if files could be downloaded")
        var force: Bool
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval() -> TimerangeDt {
            let dt = 3600*24
            if let timeinterval = timeinterval {
                guard timeinterval.count == 17, timeinterval.contains("-") else {
                    fatalError("format looks wrong")
                }
                let start = Timestamp(Int(timeinterval[0..<4])!, Int(timeinterval[4..<6])!, Int(timeinterval[6..<8])!)
                let end = Timestamp(Int(timeinterval[9..<13])!, Int(timeinterval[13..<15])!, Int(timeinterval[15..<17])!).add(86400)
                return TimerangeDt(start: start, to: end, dtSeconds: dt)
            }
            // Era5 has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            let time0z = Timestamp.now().add(5 * -86400).with(hour: 0)
            return TimerangeDt(start: time0z.add(lastDays * -86400), to: time0z, dtSeconds: dt)
        }
    }

    var help: String {
        "Download ERA5 from the ECMWF climate data store and convert"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        guard let domain = CdsDomain.init(rawValue: signature.domain) else {
            fatalError("Invalid domain '\(signature.domain)'")
        }
        
        let variables: [GenericVariable] = domain == .cerra ? CerraVariable.allCases : Era5Variable.allCases.filter({ $0.availableForDomain(domain: domain) })
        
        if let stripseaYear = signature.stripseaYear {
            try runStripSea(logger: logger, year: Int(stripseaYear)!, domain: domain, variables: variables)
            return
        }
        guard let cdskey = signature.cdskey else {
            fatalError("cds key is required")
        }
        /// Make sure elevation information is present. Otherwise download it
        try await downloadElevation(application: context.application, cdskey: cdskey, domain: domain)
        
        /// Only download one specified year
        if let yearStr = signature.year {
            if yearStr.contains("-") {
                let split = yearStr.split(separator: "-")
                guard split.count == 2 else {
                    fatalError("year invalid")
                }
                for year in Int(split[0])! ... Int(split[1])! {
                    try runYear(logger: logger, year: year, cdskey: cdskey, domain: domain, variables: variables)
                }
            } else {
                guard let year = Int(yearStr) else {
                    fatalError("Could not convert year to integer")
                }
                try runYear(logger: logger, year: year, cdskey: cdskey, domain: domain, variables: variables)
            }
            return
        }
        
        /// Select the desired timerange, or use last 14 day
        let timeinterval = signature.getTimeinterval()
        let timeintervalReturned = try downloadDailyFiles(logger: logger, cdskey: cdskey, timeinterval: timeinterval, domain: domain, variables: variables)
        try convertDailyFiles(logger: logger, timeinterval: signature.force ? timeinterval : timeintervalReturned, domain: domain, variables: variables)
    }
    
    func stripSea(logger: Logger, readFilePath: String, writeFilePath: String, elevation: [Float]) throws {
        let domain = CdsDomain.era5
        if FileManager.default.fileExists(atPath: writeFilePath) {
            return
        }
        let read = try OmFileReader(file: readFilePath)
        
        var percent = 0
        try OmFileWriter(dim0: read.dim0, dim1: read.dim1, chunk0: read.chunk0, chunk1: read.chunk1).write(file: writeFilePath, compressionType: .p4nzdec256, scalefactor: read.scalefactor) { dim0 in
            let ratio = Int(Float(dim0) / (Float(read.dim0)) * 100)
            if percent != ratio {
                logger.info("\(ratio) %")
                percent = ratio
            }
            
            let nLocations = 1000 * read.chunk0
            let locationRange = dim0..<min(dim0+nLocations, read.dim0)
            
            try read.willNeed(dim0Slow: locationRange, dim1: 0..<read.dim1)
            var data = try read.read(dim0Slow: locationRange, dim1: nil)
            for loc in locationRange {
                let (lat,lon) = domain.grid.getCoordinates(gridpoint: loc)
                let isNorthRussia = lon >= 43 && lat > 63
                let isNorthCanadaGreenlandAlaska = lat > 66 && lon < -26
                let isAntarctica = lat < -56
                
                if elevation[loc] <= -999 || lat > 72 || isNorthRussia || isNorthCanadaGreenlandAlaska || isAntarctica {
                    for t in 0..<read.dim1 {
                        data[(loc-dim0) * read.dim1 + t] = .nan
                    }
                }
            }
            return ArraySlice(data)
        }
    }
    
    func downloadElevation(application: Application, cdskey: String, domain: CdsDomain) async throws {
        let logger = application.logger
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm) {
            return
        }
        
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let tempDownloadGribFile = "\(downloadDir)elevation.grib"
        let tempDownloadGribFile2 = domain == .era5_land ? "\(downloadDir)lsm.grib" : nil
        
        if !FileManager.default.fileExists(atPath: tempDownloadGribFile) {
            logger.info("Downloading elevation and sea mask")
            switch domain {
            case .era5:
                struct Query: Encodable {
                    let product_type = "reanalysis"
                    let format = "grib"
                    let variable = ["geopotential", "land_sea_mask"]
                    let time = "00:00"
                    let day = "01"
                    let month = "01"
                    let year = "2022"
                }
                try Process.cdsApi(
                    dataset: domain.cdsDatasetName,
                    key: cdskey,
                    query: Query(),
                    destinationFile: tempDownloadGribFile
                )
            case .era5_land:
                let z = "https://confluence.ecmwf.int/download/attachments/140385202/geo_1279l4_0.1x0.1.grb?version=1&modificationDate=1570448352562&api=v2&download=true"
                let lsm = "https://confluence.ecmwf.int/download/attachments/140385202/lsm_1279l4_0.1x0.1.grb?version=1&modificationDate=1567525024201&api=v2&download=true"
                let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
                try await curl.download(url: z, toFile: tempDownloadGribFile, bzip2Decode: false)
                try await curl.download(url: lsm, toFile: tempDownloadGribFile2!, bzip2Decode: false)
            case .cerra:
                struct Query: Encodable {
                    let product_type = "analysis"
                    let data_type = "reanalysis"
                    let level_type = "surface_or_atmosphere"
                    let format = "grib"
                    let variable = ["land_sea_mask", "orography"]
                    let time = "00:00"
                    let day = "21"
                    let month = "12"
                    let year = "2019"
                }
                try Process.cdsApi(
                    dataset: domain.cdsDatasetName,
                    key: cdskey,
                    query: Query(),
                    destinationFile: tempDownloadGribFile)
            }
        }
        
        var landmask: [Float]? = nil
        var elevation: [Float]? = nil
        for file in [tempDownloadGribFile, tempDownloadGribFile2].compacted() {
            try SwiftEccodes.iterateMessages(fileName: file, multiSupport: true) { message in
                let shortName = message.get(attribute: "shortName")!
                var data = try message.getDouble().map(Float.init)
                if domain.isGlobal {
                    data.shift180LongitudeAndFlipLatitude(nt: 1, ny:  domain.grid.ny, nx: domain.grid.nx)
                }
                switch shortName {
                case "orog":
                    elevation = data
                case "z":
                    data.multiplyAdd(multiply: 1/9.80665, add: 0)
                    elevation = data
                case "lsm":
                    landmask = data
                default:
                    fatalError("Found \(shortName) in grib")
                }
            }
        }
    
        guard var elevation, let landmask else {
            fatalError("missing elevation in grib")
        }
        
        /*let a1 = Array2DFastSpace(data: elevation, nLocations: domain.grid.count, nTime: 1)
        try a1.writeNetcdf(filename: "\(downloadDir)/elevation_converted.nc", nx: domain.grid.nx, ny: domain.grid.ny)
        let a2 = Array2DFastSpace(data: landmask, nLocations: domain.grid.count, nTime: 1)
        try a2.writeNetcdf(filename: "\(downloadDir)/landmask_converted.nc", nx: domain.grid.nx, ny: domain.grid.ny)*/
        
        // Set all sea grid points to -999
        precondition(elevation.count == landmask.count)
        for i in elevation.indices {
            if landmask[i] < 0.5 {
                elevation[i] = -999
            }
        }
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
        
        try FileManager.default.removeItemIfExists(at: tempDownloadGribFile)
    }
    
    func runStripSea(logger: Logger, year: Int, domain: CdsDomain, variables: [GenericVariable]) throws {
        let domain = CdsDomain.era5
        try FileManager.default.createDirectory(atPath: "\(domain.omfileArchive!)-no-sea", withIntermediateDirectories: true)
        logger.info("Read elevation")
        let elevation = try OmFileReader(file: domain.surfaceElevationFileOm).readAll()
        
        for variable in variables {
            logger.info("Converting variable \(variable)")
            let fullFile = "\(domain.omfileArchive!)\(variable)_\(year).om"
            let strippedFile = "\(domain.omfileArchive!)-no-sea/\(variable)_\(year).om"
            try stripSea(logger: logger, readFilePath: fullFile, writeFilePath: strippedFile, elevation: elevation)
        }
    }
    
    func runYear(logger: Logger, year: Int, cdskey: String, domain: CdsDomain, variables: [GenericVariable]) throws {
        let timeintervalDaily = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 24*3600)
        let _ = try downloadDailyFiles(logger: logger, cdskey: cdskey, timeinterval: timeintervalDaily, domain: domain, variables: variables)
        try convertYear(logger: logger, year: year, domain: domain, variables: variables)
    }
    
    func downloadDailyFiles(logger: Logger, cdskey: String, timeinterval: TimerangeDt, domain: CdsDomain, variables: [GenericVariable]) throws -> TimerangeDt {
        switch domain {
        case .era5:
            fallthrough
        case .era5_land:
            return try downloadDailyEra5Files(logger: logger, cdskey: cdskey, timeinterval: timeinterval, domain: domain, variables: variables as! [Era5Variable])
        case .cerra:
            return try downloadDailyFilesCerra(logger: logger, cdskey: cdskey, timeinterval: timeinterval, variables: variables as! [CerraVariable])
        }
    }
    
    /// Download ERA5 files from CDS and convert them to daily compressed files
    func downloadDailyEra5Files(logger: Logger, cdskey: String, timeinterval: TimerangeDt, domain: CdsDomain, variables: [Era5Variable]) throws -> TimerangeDt {
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        guard timeinterval.dtSeconds == 86400 else {
            fatalError("need daily time axis")
        }
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        /// loop over each day, download data and convert it
        let pid = ProcessInfo.processInfo.processIdentifier
        let tempDownloadGribFile = "\(downloadDir)era5download_\(pid).grib"
        let tempPythonFile = "\(downloadDir)era5download_\(pid).py"
        
        /// The effective range of downloaded steps
        /// The lower bound will be adapted if timesteps already exist
        /// The upper bound will be reduced if the files are not yet on the remote server
        var downloadedRange = timeinterval.range.upperBound ..< timeinterval.range.upperBound
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: Self.nLocationsPerChunk)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        struct CdsQuery: Encodable {
            let product_type = "reanalysis"
            let format = "grib"
            let year: String
            let month: String
            let day: String
            let time: [String]
            let variable: [String]
        }
        
        timeLoop: for timestamp in timeinterval {
            logger.info("Downloading timestamp \(timestamp.format_YYYYMMdd)")
            let date = timestamp.toComponents()
            let timestampDir = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)"
            
            if FileManager.default.fileExists(atPath: "\(timestampDir)/\(variables[0].rawValue)_\(timestamp.format_YYYYMMdd)00.om") {
                continue
            }
            // Download 1 hour or 24 hours
            let hours = timeinterval.dtSeconds == 3600 ? [timestamp.hour] : Array(0..<24)
            
            let query = CdsQuery(
                year: "\(date.year)",
                month: date.month.zeroPadded(len: 2),
                day: date.day.zeroPadded(len: 2),
                time: hours.map({"\($0.zeroPadded(len: 2)):00"}),
                variable: variables.map {$0.cdsApiName}
            )
            do {
                try Process.cdsApi(dataset: domain.cdsDatasetName, key: cdskey, query: query, destinationFile: tempDownloadGribFile)
            } catch SpawnError.commandFailed(cmd: let cmd, returnCode: let code, args: let args) {
                if code == 70 {
                    logger.info("Timestep \(timestamp.iso8601_YYYY_MM_dd) seems to be unavailable. Skipping downloading now.")
                    downloadedRange = min(downloadedRange.lowerBound, timestamp) ..< timestamp
                    break timeLoop
                } else {
                    throw SpawnError.commandFailed(cmd: cmd, returnCode: code, args: args)
                }
            }
            
            try SwiftEccodes.iterateMessages(fileName: tempDownloadGribFile, multiSupport: true) { message in
                let shortName = message.get(attribute: "shortName")!
                guard let variable = variables.first(where: {$0.gribShortName.contains(shortName)}) else {
                    fatalError("Could not find \(shortName) in grib")
                }
                
                let hour = Int(message.get(attribute: "validityTime")!)!/100
                let date = message.get(attribute: "validityDate")!
                logger.info("Converting variable \(variable) \(date) \(hour) \(message.get(attribute: "name")!)")
                
                try grib2d.load(message: message)
                if let scaling = variable.netCdfScaling {
                    grib2d.array.data.multiplyAdd(multiply: Float(scaling.scalefactor), add: Float(scaling.offest))
                }
                grib2d.array.shift180LongitudeAndFlipLatitude()
                
                //let fastTime = Array2DFastSpace(data: grib2d.array.data, nLocations: domain.grid.count, nTime: nt).transpose()
                /*guard !fastTime[0, 0..<nt].contains(.nan) else {
                    // For realtime updates, the latest day could only contain partial data. Skip it.
                    logger.warning("Timestap \(timestamp.iso8601_YYYY_MM_dd) for variable \(variable) contains missing data. Skipping.")
                    break timeLoop
                }*/
                
                try FileManager.default.createDirectory(atPath: "\(domain.downloadDirectory)\(date)", withIntermediateDirectories: true)
                let omFile = "\(domain.downloadDirectory)\(date)/\(variable.rawValue)_\(date)\(hour.zeroPadded(len: 2)).om"
                try FileManager.default.removeItemIfExists(at: omFile)
                try writer.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
            
            // Update downloaded range if download successfull
            if downloadedRange.lowerBound > timestamp {
                downloadedRange = timestamp ..< downloadedRange.upperBound
            }
        }
        
        try FileManager.default.removeItemIfExists(at: tempDownloadGribFile)
        try FileManager.default.removeItemIfExists(at: tempPythonFile)
        return downloadedRange.range(dtSeconds: timeinterval.dtSeconds)
    }
    
    /// Dowload CERRA data, use analysis if available, otherwise use forecast
    func downloadDailyFilesCerra(logger: Logger, cdskey: String, timeinterval: TimerangeDt, variables: [CerraVariable]) throws -> TimerangeDt {
        let domain = CdsDomain.cerra
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        /// loop over each day, download data and convert it
        let pid = ProcessInfo.processInfo.processIdentifier
        let tempDownloadGribFile = "\(downloadDir)cerradownload_\(pid).grib"
        let tempPythonFile = "\(downloadDir)cerradownload_\(pid).py"
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: Self.nLocationsPerChunk)
        
        
        struct CdsQuery: Encodable {
            let product_type: [String]
            let format = "grib"
            let level_type: String?
            let data_type = "reanalysis"
            let height_level: String?
            let year: String
            let month: String
            let day: [String]
            let leadtime_hour: [String]
            let time: [String] = ["00:00", "03:00", "06:00", "09:00", "12:00", "15:00", "18:00", "21:00"]
            let variable: [String]
        }
        
        func downloadAndConvert(datasetName: String, productType: [String], variables: [CerraVariable], height_level: String?, level_type: String?, year: Int, month: Int, day: Int?, leadtime_hours: [Int]) throws {
            let lastDayInMonth = Timestamp(year, month % 12 + 1, 1).add(-86400).toComponents().day
            let days = day.map{[$0.zeroPadded(len: 2)]} ?? (1...lastDayInMonth).map{$0.zeroPadded(len: 2)}
            
            let YYYYMMdd = "\(year)\(month.zeroPadded(len: 2))\(days[0])"
            if FileManager.default.fileExists(atPath: "\(downloadDir)\(YYYYMMdd)/\(variables[0].rawValue)_\(YYYYMMdd)01.om") {
                logger.info("Already exists \(YYYYMMdd) variable \(variables[0]). Skipping.")
                return
            }
            
            let query = CdsQuery(
                product_type: productType,
                level_type: level_type,
                height_level: height_level,
                year: year.zeroPadded(len: 2),
                month: month.zeroPadded(len: 2),
                day: days,
                leadtime_hour: leadtime_hours.map(String.init),
                variable: variables.map {$0.cdsApiName}
            )
            try Process.cdsApi(dataset: datasetName, key: cdskey, query: query, destinationFile: tempDownloadGribFile)
            
            // Deaccumulate data on the fly. Keep previous timestep in memory
            var accumulated = [CerraVariable: [Float]]()
            
            try SwiftEccodes.iterateMessages(fileName: tempDownloadGribFile, multiSupport: true) { message in
                let shortName = message.get(attribute: "shortName")!
                guard let variable = variables.first(where: {$0.gribShortName.contains(shortName)}) else {
                    fatalError("Could not find \(shortName) in grib")
                }
                
                /// (key: "validityTime", value: "1700")
                let hour = Int(message.get(attribute: "validityTime")!)!/100
                let date = message.get(attribute: "validityDate")!
                logger.info("Converting variable \(variable) \(date) \(hour) \(message.get(attribute: "name")!)")
                //try message.debugGrid(grid: domain.grid)
                
                try grib2d.load(message: message)
                if let scaling = variable.netCdfScaling {
                    grib2d.array.data.multiplyAdd(multiply: Float(scaling.scalefactor), add: Float(scaling.offest))
                }
                
                // Deaccumulate data for forecast hours 1,2,3
                if variable.isAccumulatedSinceModelStart {
                    let previous = accumulated[variable]
                    accumulated[variable] = hour % 3 == 0 ? nil : grib2d.array.data
                    if let previous {
                        for i in grib2d.array.data.indices {
                            grib2d.array.data[i] -= previous[i]
                        }
                    }
                }
                
                try FileManager.default.createDirectory(atPath: "\(domain.downloadDirectory)\(date)", withIntermediateDirectories: true)
                let omFile = "\(domain.downloadDirectory)\(date)/\(variable.rawValue)_\(date)\(hour.zeroPadded(len: 2)).om"
                try FileManager.default.removeItemIfExists(at: omFile)
                try writer.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
            }
        }
        
        func downloadAndConvertAll(year: Int, month: Int, day: Int?) throws {
            // download forecast hour 1,2,3 for variables without analysis. Analysis is zick zacking around like crazy
            let variablesForecastHour3 = variables.filter { !$0.isHeightLevel }
            try downloadAndConvert(datasetName: domain.cdsDatasetName, productType: ["forecast"], variables: variablesForecastHour3, height_level: nil, level_type: "surface_or_atmosphere", year: year, month: month, day: day, leadtime_hours: [1,2,3])
            
            // download 3 forecast steps from level 100m
            let variablesHeightLevel = variables.filter { $0.isHeightLevel }
            try downloadAndConvert(datasetName: "reanalysis-cerra-height-levels", productType: ["forecast"], variables: variablesHeightLevel, height_level: "100_m", level_type: nil, year: year, month: month, day: day, leadtime_hours: [1,2,3])
        }
        
        /// Make sure data of the day ahead is available
        let dayBefore = timeinterval.range.lowerBound.add(-24*3600).toComponents()
        try downloadAndConvertAll(year: dayBefore.year, month: dayBefore.month, day: dayBefore.day)
        
        let months = timeinterval.toYearMonth()
        if months.count >= 3 {
            /// Download one month at once
            for date in months {
                logger.info("Downloading year \(date.year) month \(date.month)")
                try downloadAndConvertAll(year: date.year, month: date.month, day: nil)
            }
        } else {
            for timestamp in timeinterval {
                logger.info("Downloading day \(timestamp.format_YYYYMMdd)")
                let date = timestamp.toComponents()
                try downloadAndConvertAll(year: date.year, month: date.month, day: date.day)
            }
        }
            
        try FileManager.default.removeItemIfExists(at: tempDownloadGribFile)
        try FileManager.default.removeItemIfExists(at: tempPythonFile)
        return timeinterval
    }
    
    /// Convert daily compressed files to longer compressed files specified by `Era5.omFileLength`. E.g. 14 days in one file.
    func convertDailyFiles(logger: Logger, timeinterval: TimerangeDt, domain: CdsDomain, variables: [GenericVariable]) throws {
        
        let timeintervalHourly = timeinterval.with(dtSeconds: 3600)
        if timeinterval.count == 0 {
            logger.info("No new timesteps could be downloaded. Nothing to do. Existing")
            return
        }
        
        logger.info("Converting timerange \(timeinterval.prettyString())")
       
        try FileManager.default.createDirectory(atPath: domain.omfileDirectory, withIntermediateDirectories: true)
        let om = OmFileSplitter(basePath: domain.omfileDirectory, nLocations: domain.grid.count, nTimePerFile: domain.omFileLength, yearlyArchivePath: nil)
                
        let ringtime = timeintervalHourly.toIndexTime()
        let nt = timeintervalHourly.count
        
        /// loop over each day convert it
        for variable in variables {
            let progress = ProgressTracker(logger: logger, total: domain.grid.count, label: "Convert \(variable.rawValue)")
            
            let omFiles = try timeintervalHourly.map { timeinterval -> OmFileReader<MmapFile>? in
                let timestampDir = "\(domain.downloadDirectory)\(timeinterval.format_YYYYMMdd)"
                let omFile = "\(timestampDir)/\(variable.rawValue)_\(timeinterval.format_YYYYMMddHH).om"
                if !FileManager.default.fileExists(atPath: omFile) {
                    return nil
                }
                return try OmFileReader(file: omFile)
            }
            
            // chunk 6 locations and 21 days of data
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName, ringtime: ringtime, skipFirst: 0, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { dim0 in
                /// Process around 20 MB memory at once
                let locationRange = dim0..<min(dim0+Self.nLocationsPerChunk, domain.grid.count)
                
                var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt * locationRange.count), nLocations: locationRange.count, nTime: nt)
                
                for (i, omfile) in omFiles.enumerated() {
                    guard let omfile else {
                        continue
                    }
                    try omfile.willNeed(dim0Slow: 0..<1, dim1: locationRange)
                    let read = try omfile.read(dim0Slow: 0..<1, dim1: locationRange)
                    for l in 0..<locationRange.count {
                        fasttime[l, i] = read[l]
                    }
                }
                progress.add(locationRange.count)
                return ArraySlice(fasttime.data)
            }
            progress.finish()
        }
    }
    
    // Data is stored in one file per hour
    func convertYear(logger: Logger, year: Int, domain: CdsDomain, variables: [GenericVariable]) throws {
        let timeintervalHourly = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 3600)
        
        let nx = domain.grid.nx // 721
        let ny = domain.grid.ny // 1440
        let nt = timeintervalHourly.count // 8784
        
        try FileManager.default.createDirectory(atPath: domain.omfileArchive!, withIntermediateDirectories: true)
        
        // convert to yearly file
        for variable in variables {
            let progress = ProgressTracker(logger: logger, total: nx*ny, label: "Converting variable \(variable)")
            let writeFile = "\(domain.omfileArchive!)\(variable)_\(year).om"
            if FileManager.default.fileExists(atPath: writeFile) {
                continue
            }
            let omFiles = try timeintervalHourly.map { timeinterval -> OmFileReader<MmapFile>? in
                let timestampDir = "\(domain.downloadDirectory)\(timeinterval.format_YYYYMMdd)"
                let omFile = "\(timestampDir)/\(variable.rawValue)_\(timeinterval.format_YYYYMMddHH).om"
                if !FileManager.default.fileExists(atPath: omFile) {
                    return nil
                }
                return try OmFileReader(file: omFile)
            }
            
            // chunk 6 locations and 21 days of data
            try OmFileWriter(dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: 21 * 24).write(file: writeFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, supplyChunk: { dim0 in
                let locationRange = dim0..<min(dim0+Self.nLocationsPerChunk, nx*ny)
                
                var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt * locationRange.count), nLocations: locationRange.count, nTime: nt)
                
                for (i, omfile) in omFiles.enumerated() {
                    guard let omfile else {
                        continue
                    }
                    try omfile.willNeed(dim0Slow: 0..<1, dim1: locationRange)
                    let read = try omfile.read(dim0Slow: 0..<1, dim1: locationRange)
                    for l in 0..<locationRange.count {
                        fasttime[l, i] = read[l]
                    }
                }
                progress.add(locationRange.count)
                return ArraySlice(fasttime.data)
            })
            progress.finish()
        }
    }
}


extension Process {
    /// Spawn python CDS API and download to a specified file
    static func cdsApi(dataset: String, key: String, query: Encodable, destinationFile: String, url: String = "https://cds.climate.copernicus.eu/api/v2") throws {
        let queryEncoded = String(data: try JSONEncoder().encode(query), encoding: .utf8)!
        let pyCode = """
            import cdsapi

            c = cdsapi.Client(url="\(url)", key="\(key)", verify=True)
            try:
                c.retrieve('\(dataset)',\(queryEncoded),'\(destinationFile)')
            except Exception as e:
                if "Please, check that your date selection is valid" in str(e):
                    exit(70)
                if "the request you have submitted is not valid" in str(e):
                    exit(70)
                raise e
            """
        
        try pyCode.write(toFile: "\(destinationFile).py", atomically: true, encoding: .utf8)
        try Process.spawn(cmd: "python3", args: ["\(destinationFile).py"])
    }
}
