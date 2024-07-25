import Foundation
import SwiftEccodes
import Vapor
import SwiftPFor2D




struct DownloadEra5Command: AsyncCommand {
    /// 6k locations require around 200 MB memory for a yearly time-series
    static var nLocationsPerChunk = 6_000
    
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download with format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "year", short: "y", help: "Download one year")
        var year: String?
        
        @Option(name: "prefetch-factor", short: "p", help: "Prefetch factor for bias calculation. Default 2")
        var prefetchFactor: Int?
        
        @Option(name: "cdskey", short: "k", help: "CDS API user and key like: 123456:8ec08f...")
        var cdskey: String?
        
        @Option(name: "email", help: "Email for the ECMWF API service")
        var email: String?
        
        @Flag(name: "force", short: "f", help: "Force to update given timeinterval, regardless if files could be downloaded")
        var force: Bool
        
        @Flag(name: "calculate-bias-field", short: "b", help: "Generate seasonal averages for bias corrections for CMIP climate data")
        var calculateBiasField: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent conversion jobs")
        var concurrent: Int?
        
        /// Get the specified timerange in the command, or use the last 7 days as range
        func getTimeinterval(domain: CdsDomain) throws -> TimerangeDt {
            let dt = 3600*24
            if let timeinterval = timeinterval {
                return try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: dt)
            }
            // Era5 has a typical delay of 5 days
            // Per default, check last 14 days for new data. If data is already downloaded, downloading is skipped
            let lastDays = 14
            // 6 days delay for ERA5, 2 days for ECMWF IFS
            let daysBack = [CdsDomain.ecmwf_ifs, .ecmwf_ifs_analysis, .ecmwf_ifs_analysis_long_window, .ecmwf_ifs_long_window].contains(domain) ? -2 : -6
            let time0z = Timestamp.now().add(days: daysBack).with(hour: 0)
            return TimerangeDt(start: time0z.add(days: -1 * lastDays), to: time0z.add(days: 1), dtSeconds: dt)
        }
    }

    var help: String {
        "Download ERA5 from the ECMWF climate data store and convert"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let logger = context.application.logger
        
        let domain = try CdsDomain.load(rawValue: signature.domain)
        
        let variables: [GenericVariable]
        switch domain {
        case .cerra:
            variables = try CerraVariable.load(commaSeparatedOptional: signature.onlyVariables) ?? CerraVariable.allCases
        default:
            variables = try Era5Variable.load(commaSeparatedOptional: signature.onlyVariables) ?? Era5Variable.allCases.filter({ $0.availableForDomain(domain: domain) })
        }
        
        if signature.calculateBiasField {
            try generateBiasCorrectionFields(logger: logger, domain: domain, prefetchFactor: signature.prefetchFactor ?? 2)
            return
        }
        guard let cdskey = signature.cdskey else {
            fatalError("cds key is required")
        }
        /// Make sure elevation information is present. Otherwise download it
        try await downloadElevation(application: context.application, cdskey: cdskey, email: signature.email, domain: domain)
        
        let concurrent = signature.concurrent ?? System.coreCount
        
        /// Only download one specified year
        if let yearStr = signature.year {
            if yearStr.contains("-") {
                let split = yearStr.split(separator: "-")
                guard split.count == 2 else {
                    fatalError("year invalid")
                }
                for year in Int(split[0])! ... Int(split[1])! {
                    try await runYear(application: context.application, year: year, cdskey: cdskey, email: signature.email, domain: domain, variables: variables, forceUpdate: signature.force, timeintervalDaily: nil, concurrent: concurrent)
                }
            } else {
                guard let year = Int(yearStr) else {
                    fatalError("Could not convert year to integer")
                }
                try await runYear(application: context.application, year: year, cdskey: cdskey, email: signature.email, domain: domain, variables: variables, forceUpdate: signature.force, timeintervalDaily: signature.force ? signature.getTimeinterval(domain: domain) : nil, concurrent: concurrent)
            }
            return
        }
        
        /// Select the desired timerange, or use last 14 day
        let timeinterval = try signature.getTimeinterval(domain: domain)
        let handles = try await downloadDailyFiles(application: context.application, cdskey: cdskey, email: signature.email, timeinterval: timeinterval, domain: domain, variables: variables, concurrent: concurrent, forceUpdate: signature.force)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: nil, handles: handles, concurrent: concurrent)
        
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /// Generate seasonal averages for bias corrections for CMIP climate data
    /// They way how `GenericReaderMulti` is used, is not the cleanest, but otherwise daily calculations need to be implemented manually
    func generateBiasCorrectionFields(logger: Logger, domain: CdsDomain, prefetchFactor: Int) throws {
        logger.info("Calculating bias correction fields")
        
        let binsPerYear = 6
        let nLocationChunks = 200
        let writer = OmFileWriter(dim0: domain.grid.count, dim1: binsPerYear, chunk0: nLocationChunks, chunk1: binsPerYear)
        let units = ApiUnits(temperature_unit: .celsius, windspeed_unit: .ms, wind_speed_unit: nil, precipitation_unit: .mm, length_unit: .metric)
        let variables: [Cmip6VariableOrDerived] = Cmip6Variable.allCases.map{.raw($0)} + Cmip6VariableDerivedBiasCorrected.allCases.map{.derived($0)}
        let availableForEra5Land: [Cmip6VariableOrDerived] = [
            Cmip6Variable.temperature_2m_min,
            .temperature_2m_max,
            .temperature_2m_mean,
            .relative_humidity_2m_max,
            .relative_humidity_2m_min,
            .relative_humidity_2m_mean,
            .soil_moisture_0_to_10cm_mean,
        ].map{.raw($0)} + [
            Cmip6VariableDerivedBiasCorrected.soil_moisture_0_to_7cm_mean,
            .soil_moisture_7_to_28cm_mean,
            .soil_moisture_28_to_100cm_mean,
            .soil_temperature_0_to_7cm_mean,
            .soil_temperature_7_to_28cm_mean,
            .soil_temperature_28_to_100cm_mean,
            .vapour_pressure_deficit_max
        ].map{.derived($0)}
        
        let options = GenericReaderOptions()
        
        for variable in variables {
            guard let era5Variable = ForecastVariableDaily(rawValue: variable.rawValue) else {
                fatalError("Could not initialise Era5DailyWeatherVariable for \(variable)")
            }
            try domain.getBiasCorrectionFile(for: era5Variable.rawValue).createDirectory()
            let biasFile = domain.getBiasCorrectionFile(for: era5Variable.rawValue).getFilePath()
            if FileManager.default.fileExists(atPath: biasFile) {
                continue
            }
            if domain == .era5_land && !availableForEra5Land.contains(where: {$0.rawValue == variable.rawValue}) {
                logger.info("Skipping \(variable), because unavailable for ERA5-Land")
                continue
            }
            let time = TimerangeDt(start: Timestamp(1960,1,1), to: Timestamp(2022+1,1,1), dtSeconds: 24*3600).toSettings()
            let progress = ProgressTracker(logger: logger, total: writer.dim0, label: "Convert \(biasFile)")
            try writer.write(file: biasFile, compressionType: .fpxdec32, scalefactor: 1, overwrite: false, supplyChunk: { dim0 in
                let locationRange = dim0..<min(dim0+nLocationChunks, writer.dim0)
                var bias = Array2DFastTime(nLocations: locationRange.count, nTime: binsPerYear)
                
                // Read location one-by-one... Multi location support does not work with derived varibales
                for (l, gridpoint) in locationRange.enumerated() {
                    let gridpointNext = min(gridpoint+1, writer.dim0-1)
                    let readerNext = GenericReaderMulti<ForecastVariable, MultiDomains>(domain: MultiDomains.era5, reader: [Era5Reader(reader: GenericReaderCached<CdsDomain, Era5Variable>(reader: try GenericReader<CdsDomain, Era5Variable>(domain: domain, position: gridpointNext)), options: options)])
                    try readerNext.prefetchData(variables: [era5Variable], time: time)
                    
                    let reader = GenericReaderMulti<ForecastVariable, MultiDomains>(domain: MultiDomains.era5, reader: [Era5Reader(reader: GenericReaderCached<CdsDomain, Era5Variable>(reader: try GenericReader<CdsDomain, Era5Variable>(domain: domain, position: gridpoint)), options: options)])
                    
                    guard let dataFlat = try reader.getDaily(variable: era5Variable, params: units, time: time)?.data else {
                        fatalError("Could not get \(era5Variable)")
                    }
                    bias[l, 0..<binsPerYear] = ArraySlice(BiasCorrectionSeasonalLinear(ArraySlice(dataFlat), time: time.time, binsPerYear: binsPerYear).meansPerYear)
                }
                progress.add(bias.nLocations)
                return ArraySlice(bias.data)
            })
            progress.finish()
        }
    }
    
    /**
     Soil type information: https://www.ecmwf.int/en/forecasts/documentation-and-support/evolution-ifs/cycles/change-soil-hydrology-scheme-ifs-cycle
     */
    func downloadElevation(application: Application, cdskey: String, email: String?, domain: CdsDomain) async throws {
        let logger = application.logger
        if FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()
        
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        let tempDownloadGribFile = "\(downloadDir)elevation.grib"
        let tempDownloadGribFile2 = domain == .era5_land ? "\(downloadDir)lsm.grib" : nil
        let tempDownloadGribFile3 = domain == .era5_land ? "\(downloadDir)soil_type.grib" : nil
        

        
        if !FileManager.default.fileExists(atPath: tempDownloadGribFile) {
            logger.info("Downloading elevation and sea mask")
            let client = application.makeNewHttpClient(redirectConfiguration: .disallow)
            let curl = Curl(logger: logger, client: client, deadLineHours: 99999)
            
            
            switch domain {
            case .era5_daily, .era5_land_daily:
                fatalError()
            case .era5_ocean:
                // Just use wave data and mark all NaN areas as land
                struct Query: Encodable {
                    let product_type = "reanalysis"
                    let format = "grib"
                    let variable = ["significant_height_of_combined_wind_waves_and_swell"]
                    let time = "00:00"
                    let day = "01"
                    let month = "01"
                    let year = "2022"
                }
                try await curl.downloadCdsApi(dataset: domain.cdsDatasetName, query:  Query(), apikey: cdskey, destinationFile: tempDownloadGribFile)
            case .ecmwf_ifs, .ecmwf_ifs_analysis_long_window, .ecmwf_ifs_long_window, .ecmwf_ifs_analysis:
                guard let email else {
                    fatalError("email required")
                }
                struct Query: Encodable {
                    let `class` = "od"
                    let date = "2022-03-31"
                    let expver = 1
                    let levtype = "sfc"
                    let param = ["129.128", "172.128", "43.128"]
                    let step = 0
                    let stream = "oper"
                    let time = "00:00:00"
                    let type = "an"
                }
                try await curl.downloadEcmwfApi(query: Query(), email: email, apikey: cdskey, destinationFile: tempDownloadGribFile)
            case .era5, .era5_ensemble:
                struct Query: Encodable {
                    let product_type: String
                    let format = "grib"
                    let variable = ["geopotential", "land_sea_mask", "soil_type"]
                    let time = "00:00"
                    let day = "01"
                    let month = "01"
                    let year = "2022"
                }
                try await curl.downloadCdsApi(dataset: domain.cdsDatasetName, query: Query(product_type: domain == .era5_ensemble ? "ensemble_mean" : "reanalysis"), apikey: cdskey, destinationFile: tempDownloadGribFile)
            case .era5_land:
                let z = "https://confluence.ecmwf.int/download/attachments/140385202/geo_1279l4_0.1x0.1.grb?version=1&modificationDate=1570448352562&api=v2&download=true"
                let lsm = "https://confluence.ecmwf.int/download/attachments/140385202/lsm_1279l4_0.1x0.1.grb?version=1&modificationDate=1567525024201&api=v2&download=true"
                let soilType = "https://confluence.ecmwf.int/download/attachments/140385202/slt.grib?version=1&modificationDate=1634824634152&api=v2&download=true"
                let curl = Curl(logger: logger, client: application.dedicatedHttpClient)
                try await curl.download(url: z, toFile: tempDownloadGribFile, bzip2Decode: false)
                try await curl.download(url: lsm, toFile: tempDownloadGribFile2!, bzip2Decode: false)
                try await curl.download(url: soilType, toFile: tempDownloadGribFile3!, bzip2Decode: false)
            case .cerra:
                struct Query: Encodable {
                    let product_type = "analysis"
                    let data_type = "reanalysis"
                    let level_type = "surface_or_atmosphere"
                    let format = "grib"
                    let variable = ["land_sea_mask", "orography"] //, "soil_type"]
                    let time = "00:00"
                    let day = "21"
                    let month = "12"
                    let year = "2019"
                }
                try await curl.downloadCdsApi(dataset: domain.cdsDatasetName, query:  Query(), apikey: cdskey, destinationFile: tempDownloadGribFile)
            }
            
            try await client.shutdown()
        }
        
        var landmask: [Float]? = nil
        var elevation: [Float]? = nil
        var soilType: [Float]? = nil
        for file in [tempDownloadGribFile, tempDownloadGribFile2, tempDownloadGribFile3].compacted() {
            try SwiftEccodes.iterateMessages(fileName: file, multiSupport: true) { message in
                let shortName = message.get(attribute: "shortName")!
                var data = try message.getDouble().map(Float.init)
                if domain.isGlobal && domain != .ecmwf_ifs {
                    data.shift180LongitudeAndFlipLatitude(nt: 1, ny: domain.grid.ny, nx: domain.grid.nx)
                }
                switch shortName {
                case "orog":
                    elevation = data
                case "z":
                    data.multiplyAdd(multiply: 1/9.80665, add: 0)
                    elevation = data
                case "lsm":
                    landmask = data
                case "slt":
                    soilType = data
                case "swh":
                    elevation = .init(repeating: .nan, count: data.count)
                    landmask = data.map { $0.isNaN ? 1 : 0 }
                default:
                    fatalError("Found \(shortName) in grib")
                }
            }
        }
    
        guard var elevation, let landmask else {
            fatalError("missing elevation in grib")
        }
        
        let chunk0 = min(domain.grid.ny, 20)
        let writer = OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: chunk0, chunk1: 400/chunk0)
        
        if let soilType {
            try writer.write(file: domain.soilTypeFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: soilType)
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

        try writer.write(file: domain.surfaceElevationFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
        
        try FileManager.default.removeItemIfExists(at: tempDownloadGribFile)
        if let tempDownloadGribFile2 {
            try FileManager.default.removeItemIfExists(at: tempDownloadGribFile2)
        }
        if let tempDownloadGribFile3 {
            try FileManager.default.removeItemIfExists(at: tempDownloadGribFile3)
        }
    }
    
    func runYear(application: Application, year: Int, cdskey: String, email: String?, domain: CdsDomain, variables: [GenericVariable], forceUpdate: Bool, timeintervalDaily: TimerangeDt?, concurrent: Int) async throws {
        let timeintervalDaily = timeintervalDaily ?? TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: 24*3600)
        /// TODO with `forceUpdate` all handles can be returned... pass this along to `convertYear` function
        let _ = try await downloadDailyFiles(application: application, cdskey: cdskey, email: email, timeinterval: timeintervalDaily, domain: domain, variables: variables, concurrent: concurrent, forceUpdate: forceUpdate)
        
        let variablesConvert: [GenericVariable]
        if domain == .era5_ensemble {
            // ERA5 ensemble domain also contains a spread variable for each mean variable
            variablesConvert = variables.flatMap {
                guard let spread: GenericVariable = Era5Variable(rawValue: "\($0)_spread") else {
                    fatalError("Did not find spread variable for \($0)")
                }
                return [$0, spread]
            }
        } else {
            variablesConvert = variables
        }
        
        try convertYear(logger: application.logger, year: year, domain: domain, variables: variablesConvert, forceUpdate: forceUpdate)
    }
    
    func downloadDailyFiles(application: Application, cdskey: String, email: String?, timeinterval: TimerangeDt, domain: CdsDomain, variables: [GenericVariable], concurrent: Int, forceUpdate: Bool) async throws -> [GenericVariableHandle] {
        switch domain {
        case .era5_land, .era5, .era5_ocean, .era5_ensemble:
            return try await downloadDailyEra5Files(application: application, cdskey: cdskey, timeinterval: timeinterval, domain: domain, variables: variables as! [Era5Variable], concurrent: concurrent, forceUpdate: forceUpdate)
        case .cerra:
            return try await downloadDailyFilesCerra(application: application, cdskey: cdskey, timeinterval: timeinterval, variables: variables as! [CerraVariable], concurrent: concurrent)
        case .ecmwf_ifs, .ecmwf_ifs_analysis_long_window, .ecmwf_ifs_long_window, .ecmwf_ifs_analysis:
            guard let email else {
                fatalError("email required")
            }
            return try await downloadDailyEcmwfIfsFiles(application: application, key: cdskey, email: email, timeinterval: timeinterval, domain: domain, variables: variables as! [Era5Variable], concurrent: concurrent, forceUpdate: forceUpdate)
        case .era5_daily, .era5_land_daily:
            fatalError()
        }
    }
    
    struct CdsQuery: Encodable {
        let product_type: [String]
        let format = "grib"
        let year: String
        let month: String
        let day: String
        let time: [String]
        let variable: [String]
    }
    
    /// Download ERA5 files from CDS and convert them to daily compressed files
    func downloadDailyEra5Files(application: Application, cdskey: String, timeinterval: TimerangeDt, domain: CdsDomain, variables: [Era5Variable], concurrent: Int, forceUpdate: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        guard timeinterval.dtSeconds == 86400 else {
            fatalError("need daily time axis")
        }
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 99999)
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: Self.nLocationsPerChunk)
        
        var handles = [GenericVariableHandle]()
        
        timeLoop: for timestamp in timeinterval {
            logger.info("Downloading timestamp \(timestamp.format_YYYYMMdd)")
            let date = timestamp.toComponents()
            let timestampDir = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)"
            
            if FileManager.default.fileExists(atPath: "\(timestampDir)/\(variables[0].rawValue)_\(timestamp.format_YYYYMMdd)00.om") {
                // Return file handles, for existing files to trigger update
                if forceUpdate {
                    let variablesConvert: [Era5Variable]
                    if domain == .era5_ensemble {
                        // ERA5 ensemble domain also contains a spread variable for each mean variable
                        variablesConvert = variables.flatMap {
                            guard let spread = Era5Variable(rawValue: "\($0)_spread") else {
                                fatalError("Did not find spread variable for \($0)")
                            }
                            return [$0, spread]
                        }
                    } else {
                        variablesConvert = variables
                    }
                    for t in TimerangeDt(start: timestamp, to: timestamp.add(days: 1), dtSeconds: domain.dtSeconds) {
                        for variable in variablesConvert {
                            let file = "\(timestampDir)/\(variable.rawValue)_\(t.format_YYYYMMddHH).om"
                            logger.info("Open \(file)")
                            guard let fn = try? FileHandle.openFileReading(file: file) else {
                                continue
                            }
                            handles.append(GenericVariableHandle(
                                variable: variable,
                                time: t,
                                member: 0,
                                fn: fn,
                                skipHour0: false
                            ))
                        }
                    }
                }
                continue
            }
            // Download 1 hour or 24 hours
            let hours = timeinterval.dtSeconds == 3600 ? [timestamp.hour] : Array(0..<24)
            
            let query = CdsQuery(
                product_type: domain == .era5_ensemble ? ["ensemble_mean", "ensemble_spread"] : ["reanalysis"],
                year: "\(date.year)",
                month: date.month.zeroPadded(len: 2),
                day: date.day.zeroPadded(len: 2),
                time: hours.map({"\($0.zeroPadded(len: 2)):00"}),
                variable: variables.compactMap {$0.cdsApiName}
            )
            
            
            do {
                let h = try await curl.withCdsApi(dataset: domain.cdsDatasetName, query: query, apikey: cdskey) { messages in
                    return try await messages.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                        let attributes = try GribAttributes(message: message)
                        let timestamp = attributes.timestamp
                        guard let variable = Era5Variable.fromGrib(attributes: attributes) else {
                            fatalError("Could not find \(attributes) in grib")
                        }
                        
                        logger.info("Converting variable \(variable) \(timestamp.format_YYYYMMddHH) \(message.get(attribute: "name")!)")
                        
                        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                        try grib2d.load(message: message)
                        if let scaling = variable.netCdfScaling(domain: domain) {
                            grib2d.array.data.multiplyAdd(multiply: scaling.scalefactor, add: scaling.offset)
                        }
                        grib2d.array.shift180LongitudeAndFlipLatitude()
                        
                        //let fastTime = Array2DFastSpace(data: grib2d.array.data, nLocations: domain.grid.count, nTime: nt).transpose()
                        /*guard !fastTime[0, 0..<nt].contains(.nan) else {
                            // For realtime updates, the latest day could only contain partial data. Skip it.
                            logger.warning("Timestap \(timestamp.iso8601_YYYY_MM_dd) for variable \(variable) contains missing data. Skipping.")
                            break timeLoop
                        }*/
                        
                        try FileManager.default.createDirectory(atPath: "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)", withIntermediateDirectories: true)
                        let omFile = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)/\(variable.rawValue)_\(timestamp.format_YYYYMMddHH).om"
                        try FileManager.default.removeItemIfExists(at: omFile)
                        let fn = try writer.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                        return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: false)
                    }.collect().compactMap({$0})
                }
                handles.append(contentsOf: h)
            } catch CdsApiError.restrictedAccessToValidData {
                logger.info("Timestep \(timestamp.iso8601_YYYY_MM_dd) seems to be unavailable. Skipping downloading now.")
                break timeLoop
            }
        }
        
        return handles
    }
    
    /// Download ECMWF IFS operational archives
    func downloadDailyEcmwfIfsFiles(application: Application, key: String, email: String, timeinterval: TimerangeDt, domain: CdsDomain, variables: [Era5Variable], concurrent: Int, forceUpdate: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        guard timeinterval.dtSeconds == 86400 else {
            fatalError("need daily time axis")
        }
        
        let client = application.makeNewHttpClient(redirectConfiguration: .disallow)
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        let curl = Curl(logger: logger, client: client, deadLineHours: 99999)
        var handles = [GenericVariableHandle]()
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: Self.nLocationsPerChunk)
        
        
        struct EcmwfQuery: Encodable {
            let `class` = "od"
            /// iso string `2016-03-18`
            let date: String
            let expver = 1
            let levtype = "sfc"
            let param: [String]
            /// Use forecast hours 1...12. Skip hour 0, as the model is instable at hour 0
            let step: [Int]?
            let stream: String
            /// init time "00:00:00"
            let time: [String]
            let type: String
        }
        
        timeLoop: for timestamp in timeinterval {
            logger.info("Downloading timestamp \(timestamp.format_YYYYMMdd)")
            let timestampDir = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)"
            
            // check for timestep 6, as this should be available also for 6 hourly assimilation data
            if FileManager.default.fileExists(atPath: "\(timestampDir)/\(variables[0].rawValue)_\(timestamp.format_YYYYMMdd)06.om") {
                // Return file handles, for existing files to trigger update
                if forceUpdate {
                    for t in TimerangeDt(start: timestamp, to: timestamp.add(days: 1), dtSeconds: domain.dtSeconds) {
                        for variable in variables {
                            let file = "\(timestampDir)/\(variable.rawValue)_\(t.format_YYYYMMddHH).om"
                            logger.info("Open \(file)")
                            guard let fn = try? FileHandle.openFileReading(file: file) else {
                                continue
                            }
                            handles.append(GenericVariableHandle(
                                variable: variable,
                                time: t,
                                member: 0,
                                fn: fn,
                                skipHour0: false
                            ))
                        }
                    }
                }
                continue
            }
            
            let query: EcmwfQuery
            let deaccumulatePrecipitation: Bool
            switch domain {
            case .ecmwf_ifs:
                query = EcmwfQuery(
                    date: timestamp.iso8601_YYYY_MM_dd,
                    param: variables.map {$0.marsGribCode},
                    step: (1...12).map({$0}),
                    stream: "oper",
                    time: ["00:00:00", "12:00:00"],
                    type: "fc"
                )
                deaccumulatePrecipitation = true
            case .ecmwf_ifs_long_window:
                query = EcmwfQuery(
                    date: timestamp.iso8601_YYYY_MM_dd,
                    param: variables.map {$0.marsGribCode},
                    step: stride(from: 0, through: 12, by: 3).map({$0}),
                    stream: "lwda",
                    time: ["06:00:00", "18:00:00"],
                    type: "fc"
                )
                deaccumulatePrecipitation = true
            case .ecmwf_ifs_analysis_long_window:
                query = EcmwfQuery(
                    date: timestamp.iso8601_YYYY_MM_dd,
                    param: variables.map {$0.marsGribCode},
                    step: nil,
                    stream: "lwda",
                    time: ["00:00:00", "06:00:00", "12:00:00", "18:00:00"],
                    type: "an"
                )
                deaccumulatePrecipitation = false
            case .ecmwf_ifs_analysis:
                query = EcmwfQuery(
                    date: timestamp.iso8601_YYYY_MM_dd,
                    param: variables.map {$0.marsGribCode},
                    step: nil,
                    stream: "oper",
                    time: ["00:00:00", "06:00:00", "12:00:00", "18:00:00"],
                    type: "an"
                )
                deaccumulatePrecipitation = false
            default:
                fatalError()
            }
            do {
                let h = try await curl.withEcmwfApi(query: query, email: email, apikey: key) { messages in
                    let deaverager = GribDeaverager()
                    return try await messages.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                        let attributes = try GribAttributes(message: message)
                        let timestamp = attributes.timestamp
                        guard let variable = Era5Variable.fromGrib(attributes: attributes) else {
                            fatalError("Could not find \(attributes) in grib")
                        }
                        
                        let endStep = Int(message.get(attribute: "endStep")!)!
                        logger.info("Converting variable \(variable) \(timestamp.format_YYYYMMddHH) \(attributes.parameterName)")
                        
                        if variable == .wind_gusts_10m && endStep == 0 {
                            return nil
                        }
                        
                        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                        try grib2d.load(message: message)
                        if let scaling = variable.netCdfScaling(domain: domain) {
                            grib2d.array.data.multiplyAdd(multiply: scaling.scalefactor, add: scaling.offset)
                        }
                        
                        var stepType = attributes.stepType
                        var stepRange = attributes.stepRange
                        
                        // Deaccumulate data. Data is marked as `instant` in GRIB although data is accumulated
                        if deaccumulatePrecipitation && [Era5Variable.shortwave_radiation, .direct_radiation, .precipitation, .snowfall_water_equivalent].contains(variable) {
                            if attributes.stepRange == "0" {
                                return nil
                            }
                            stepType = .accum
                            stepRange = "0-\(attributes.stepRange)"
                        }

                        // Deaccumulate precipitation
                        guard await deaverager.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType.rawValue, stepRange: stepRange, grib2d: &grib2d) else {
                            return nil
                        }
                        
                        try FileManager.default.createDirectory(atPath: "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)", withIntermediateDirectories: true)
                        let omFile = "\(domain.downloadDirectory)\(timestamp.format_YYYYMMdd)/\(variable.rawValue)_\(timestamp.format_YYYYMMddHH).om"
                        try FileManager.default.removeItemIfExists(at: omFile)
                        let fn = try writer.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                        return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: false)
                    }.collect().compactMap({$0})
                }
                handles.append(contentsOf: h)
            } catch EcmwfApiError.restrictedAccessToValidData {
                logger.info("Timestep \(timestamp.iso8601_YYYY_MM_dd) seems to be unavailable. Skipping downloading now.")
                break timeLoop
            }
        }
        try await client.shutdown()
        return handles
    }
    
    /// Dowload CERRA data, use analysis if available, otherwise use forecast
    func downloadDailyFilesCerra(application: Application, cdskey: String, timeinterval: TimerangeDt, variables: [CerraVariable], concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let domain = CdsDomain.cerra
        logger.info("Downloading timerange \(timeinterval.prettyString())")
        
        /// Directory dir, where to place temporary downloaded files
        let downloadDir = domain.downloadDirectory
        try FileManager.default.createDirectory(atPath: downloadDir, withIntermediateDirectories: true)
        
        /// loop over each day, download data and convert it
        let pid = ProcessInfo.processInfo.processIdentifier
        let tempDownloadGribFile = "\(downloadDir)cerradownload_\(pid).grib"
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 99999)
        
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: Self.nLocationsPerChunk)
        var handles = [GenericVariableHandle]()
        
        
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
        
        func downloadAndConvert(datasetName: String, productType: [String], variables: [CerraVariable], height_level: String?, level_type: String?, year: Int, month: Int, day: Int?, leadtime_hours: [Int]) async throws {
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
            
            do {
                let h = try await curl.withCdsApi(dataset: domain.cdsDatasetName, query: query, apikey: cdskey) { messages in
                    // Deaccumulate data on the fly. Keep previous timestep in memory
                    let deaverager = GribDeaverager()
                    
                    return try await messages.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                        guard let shortName = message.get(attribute: "shortName"),
                              let stepRange = message.get(attribute: "stepRange"),
                              let stepType = message.get(attribute: "stepType")
                        else {
                            fatalError("could not get attributes")
                        }
                        
                        guard let variable = variables.first(where: {$0.gribShortName.contains(shortName)}) else {
                            fatalError("Could not find \(shortName) in grib")
                        }
                        
                        /// (key: "validityTime", value: "1700")
                        let hour = Int(message.get(attribute: "validityTime")!)!/100
                        let date = message.get(attribute: "validityDate")!
                        logger.info("Converting variable \(variable) \(date) \(hour) \(message.get(attribute: "name")!)")
                        let timestamp = try Timestamp.from(yyyymmdd: "\(date)\(hour.zeroPadded(len: 2))")
                        //try message.debugGrid(grid: domain.grid)
                        
                        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                        try grib2d.load(message: message)
                        if let scaling = variable.netCdfScaling {
                            grib2d.array.data.multiplyAdd(multiply: Float(scaling.scalefactor), add: Float(scaling.offest))
                        }
                        
                        // Deaccumulate precipitation
                        guard await deaverager.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                            return nil
                        }
                        
                        try FileManager.default.createDirectory(atPath: "\(domain.downloadDirectory)\(date)", withIntermediateDirectories: true)
                        let omFile = "\(domain.downloadDirectory)\(date)/\(variable.rawValue)_\(date)\(hour.zeroPadded(len: 2)).om"
                        try FileManager.default.removeItemIfExists(at: omFile)
                        let fn = try writer.write(file: omFile, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                        return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: false)
                    }.collect().compactMap({$0})
                }
                handles.append(contentsOf: h)
            }
        }
        
        func downloadAndConvertAll(year: Int, month: Int, day: Int?) async throws {
            // download forecast hour 1,2,3 for variables without analysis. Analysis is zick zacking around like crazy
            let variablesForecastHour3 = variables.filter { !$0.isHeightLevel }
            try await downloadAndConvert(datasetName: domain.cdsDatasetName, productType: ["forecast"], variables: variablesForecastHour3, height_level: nil, level_type: "surface_or_atmosphere", year: year, month: month, day: day, leadtime_hours: [1,2,3])
            
            // download 3 forecast steps from level 100m
            let variablesHeightLevel = variables.filter { $0.isHeightLevel }
            try await downloadAndConvert(datasetName: "reanalysis-cerra-height-levels", productType: ["forecast"], variables: variablesHeightLevel, height_level: "100_m", level_type: nil, year: year, month: month, day: day, leadtime_hours: [1,2,3])
        }
        
        /// Make sure data of the day ahead is available
        let dayBefore = timeinterval.range.lowerBound.add(-24*3600).toComponents()
        try await downloadAndConvertAll(year: dayBefore.year, month: dayBefore.month, day: dayBefore.day)
        
        let months = timeinterval.toYearMonth()
        if months.count >= 3 {
            /// Download one month at once
            for date in months {
                logger.info("Downloading year \(date.year) month \(date.month)")
                try await downloadAndConvertAll(year: date.year, month: date.month, day: nil)
            }
        } else {
            for timestamp in timeinterval {
                logger.info("Downloading day \(timestamp.format_YYYYMMdd)")
                let date = timestamp.toComponents()
                try await downloadAndConvertAll(year: date.year, month: date.month, day: date.day)
            }
        }
            
        try FileManager.default.removeItemIfExists(at: tempDownloadGribFile)
        try FileManager.default.removeItemIfExists(at: "\(tempDownloadGribFile).py")
        return handles
    }
    
    /// Data is stored in one file per hour
    /// If `forceUpdate` is set, an existing file is updated
    func convertYear(logger: Logger, year: Int, domain: CdsDomain, variables: [GenericVariable], forceUpdate: Bool) throws {
        let timeintervalHourly = TimerangeDt(start: Timestamp(year,1,1), to: Timestamp(year+1,1,1), dtSeconds: domain.dtSeconds)
        
        let nx = domain.grid.nx // 721
        let ny = domain.grid.ny // 1440
        let nt = timeintervalHourly.count // 8784
                
        // convert to yearly file
        for variable in variables {
            let progress = ProgressTracker(logger: logger, total: nx*ny, label: "Convert \(variable) year \(year)")
            let writeFile = OmFileManagerReadable.domainChunk(domain: domain.domainRegistry, variable: "\(variable)", type: .year, chunk: year, ensembleMember: 0, previousDay: 0)
            if !forceUpdate && FileManager.default.fileExists(atPath: writeFile.getFilePath()) {
                continue
            }
            try writeFile.createDirectory()
            
            let existingFile = forceUpdate ? try writeFile.openRead() : nil
            let omFiles = try timeintervalHourly.map { timeinterval -> OmFileReader<MmapFile>? in
                let timestampDir = "\(domain.downloadDirectory)\(timeinterval.format_YYYYMMdd)"
                let omFile = "\(timestampDir)/\(variable.rawValue)_\(timeinterval.format_YYYYMMddHH).om"
                if !FileManager.default.fileExists(atPath: omFile) {
                    return nil
                }
                return try OmFileReader(file: omFile)
            }
            // For updates, delete file before creating a new one.
            // Because the file is open, data access is still possible
            try FileManager.default.removeItemIfExists(at: writeFile.getFilePath())
            
            // chunk 6 locations and 21 days of data
            try OmFileWriter(dim0: ny*nx, dim1: nt, chunk0: 6, chunk1: 21 * 24).write(file: writeFile.getFilePath(), compressionType: .p4nzdec256, scalefactor: variable.scalefactor, overwrite: false, supplyChunk: { dim0 in
                let locationRange = dim0..<min(dim0+Self.nLocationsPerChunk, nx*ny)
                
                var fasttime = Array2DFastTime(data: [Float](repeating: .nan, count: nt * locationRange.count), nLocations: locationRange.count, nTime: nt)
                
                if let existingFile {
                    // Load existing data if present
                    try existingFile.read(into: &fasttime.data, arrayRange: 0..<locationRange.count, arrayDim1Length: nt, dim0Slow: locationRange, dim1: 0..<nt)
                }
                
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
