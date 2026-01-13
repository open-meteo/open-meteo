import Vapor

struct DownloadEcmwfEcpdsCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?

        @Option(name: "server", help: "Root server path. Default: 'https://data.ecmwf.int/forecasts/'")
        var server: String?

        @Option(name: "concurrent", short: "c", help: "Number of concurrent download/conversion jobs")
        var concurrent: Int?

        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?

        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Flag(name: "skip-timeseries")
        var skipTimeseries: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
        
        @Option(name: "key", short: "k", help: "ECMWF key")
        var key: String?

        @Option(name: "email", help: "Email for the ECMWF API service")
        var email: String?
    }

    var help: String {
        "Download a specified ecmwf model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        guard let domain = EcmwfEcpdsDomain(rawValue: signature.domain) else {
            fatalError("Could not initialise domain from \(signature.domain)")
        }

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun

        let logger = context.application.logger

        let nConcurrent = signature.concurrent ?? 2

        if let timeinterval = signature.timeinterval {
            guard let email = signature.email, let key = signature.key else {
                fatalError("Email and key required")
            }
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / 4) {
                logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                let handles = try await downloadMars(application: context.application, domain: domain, run: run, concurrent: nConcurrent, key: key, email: email)
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities, generateTimeSeries: !signature.skipTimeseries)
                
                if let directory = OpenMeteo.dataRunDirectory, signature.uploadS3Bucket != nil {
                    // Delete run directory after S3 upload
                    let model = domain.domainRegistry.rawValue
                    let timeFormatted = run.format_directoriesYYYYMMddhhmm
                    let runDir = "\(directory)\(model)/\(timeFormatted)/"
                    logger.info("Deleting local run directory: \(runDir)")
                    try FileManager.default.removeItem(atPath: runDir)
                }
            }
            return
        }
        guard let server = signature.server else {
            fatalError("Parameter server is required")
        }

        logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        try await downloadEcmwfElevation(application: context.application, domain: domain, run: run)
        let handles = try await downloadEcmwf(application: context.application, domain: domain, server: server, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: signature.uploadS3Bucket)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities, generateTimeSeries: !signature.skipTimeseries)
    }

    /// Download elevation file
    func downloadEcmwfElevation(application: Application, domain: EcmwfEcpdsDomain, run: Timestamp) async throws {
        /*Manually generate land mask
         let path = "/Users/patrick/Downloads/_mars-bol-webmars-private-svc-blue-000-7a527896970b09a4fc90fa37bf98d3ff-_kuWGj.grib"
        try domain.surfaceElevationFileOm.createDirectory()
        try DownloadEra5Command.processElevationLsmGrib(domain: domain, files: [path], createNetCdf: false)
        fatalError("OK")*/
        
        /*let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm.getFilePath()) {
            return
        }
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)

        var generateElevationFileData: (lsm: [Float]?, surfacePressure: [Float]?, sealevelPressure: [Float]?, temperature_2m: [Float]?) = (nil, nil, nil, nil)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)

        logger.info("Downloading height and elevation data")
        let url = domain.getUrl(base: base, run: run, hour: 0)[0]
        for try await message in try await curl.downloadEcmwfIndexed(url: url, concurrent: 1, isIncluded: { entry in
            guard entry.number == nil else {
                // ignore ensemble members, only use control
                return false
            }
            return entry.levtype == .sfc && ["lsm", "2t", "sp", "msl"].contains(entry.param)
        }) {
            let shortName = message.get(attribute: "shortName")!
            try grib2d.load(message: message)
            grib2d.array.flipLatitude()

            switch shortName {
            case "lsm":
                generateElevationFileData.lsm = grib2d.array.data
            case "2t":
                grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
                generateElevationFileData.temperature_2m = grib2d.array.data
            case "sp":
                grib2d.array.data.multiplyAdd(multiply: 1 / 100, add: 0)
                generateElevationFileData.surfacePressure = grib2d.array.data
            case "msl":
                grib2d.array.data.multiplyAdd(multiply: 1 / 100, add: 0)
                generateElevationFileData.sealevelPressure = grib2d.array.data
            default:
                fatalError("Received too many grib messages \(shortName)")
            }
        }
        logger.info("Generating elevation file")
        guard let lsm = generateElevationFileData.lsm else {
            fatalError("Did not get LSM data")
        }
        guard let surfacePressure = generateElevationFileData.surfacePressure,
              let sealevelPressure = generateElevationFileData.sealevelPressure,
              let temperature_2m = generateElevationFileData.temperature_2m else {
            fatalError("Did not get pressure data")
        }
        let elevation: [Float] = zip(zip(surfacePressure, sealevelPressure), zip(temperature_2m, lsm)).map {
            let ((surfacePressure, sealevelPressure), (temperature_2m, landmask)) = $0
            return landmask < 0.5 ? -999 : Meteorology.elevation(sealevelPressure: sealevelPressure, surfacePressure: surfacePressure, temperature_2m: temperature_2m)
        }
        try domain.surfaceElevationFileOm.createDirectory()
        try elevation.writeOmFile2D(file: domain.surfaceElevationFileOm.getFilePath(), grid: domain.grid)*/
    }
    
    func downloadMars(application: Application, domain: EcmwfEcpdsDomain, run: Timestamp, concurrent: Int, key: String, email: String) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        logger.info("Downloading run \(run.iso8601_YYYY_MM_dd_HH_mm)")
        
        struct EcmwfQuery: Encodable {
            let `class` = "od"
            /// iso string `2016-03-18`
            let date: String
            let expver = 1
            let levtype = "sfc"
            let param: String
            /// Use forecast hours 1...12. Skip hour 0, as the model is instable at hour 0
            let step: String
            let stream: String
            /// init time "00:00:00"
            let time: String
            let type: String
        }
        
        let client = application.makeNewHttpClient(redirectConfiguration: .disallow)
        let curl = Curl(logger: logger, client: client, deadLineHours: 99999)
        
        let sideRunSteps = ["0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17/18/19/20/21/22/23/24/25/26/27/28/29/30/31/32/33/34/35/36/37/38/39/40/41/42/43/44/45/46/47/48/49/50/51/52/53/54/55/56/57/58/59/60/61/62/63/64/65/66/67/68/69/70/71/72/73/74/75/76/77/78/79/80/81/82/83/84/85/86/87/88/89/90/93/96/99/102/105/108/111/114/117/120/123/126/129/132/135/138/141/144"]
        /// Split 0z/12z runs into 2 requests, because MARS transfers are limited to 75 GB
        let fullRunSteps = [sideRunSteps[0], "150/156/162/168/174/180/186/192/198/204/210/216/222/228/234/240/246/252/258/264/270/276/282/288/294/300/306/312/318/324/330/336/342/348/354/360"]
        

        let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: false, realm: nil)
        
        for steps in run.hour % 12 == 0 ? fullRunSteps : sideRunSteps {
            // 20.3 = visibility
            // 145.151 = Sea surface height
            // 98.174 = Sea ice thickness
            // 228051 = litota1
            // 228057 = litota3 + litota6
            let query = EcmwfQuery(
                date: run.iso8601_YYYY_MM_dd,
                param: "100u/100v/10fg/10u/10v/200u/200v/2d/2t/cp/fal/fdir/fsr/hcc/kx/lcc/mcc/mn2t/msl/mucape/mucin/mx2t/pev/ptype/ro/rsn/sd/sf/skt/ssrd/stl1/stl2/stl3/stl4/swvl1/swvl2/swvl3/swvl4/tcc/tcwv/tp/20.3/blh/98.174/ocu/ocv/145.151/228051/228057",
                step: steps,
                stream: run.hour % 12 == 0 ? "oper" : "scda",
                time: "\(run.hh)00",
                type: "fc"
            )
            try await curl.withEcmwfApi(query: query, email: email, apikey: key, nConcurrent: max(2, concurrent)) { messages in
                let inMemory = VariablePerMemberStorage<EcmwfEcdpsIfsVariable>()
                let deaverager = GribDeaverager()
                let dtSeconds = domain.dtSeconds
                
                for try await message in messages {
                    guard let shortName = message.get(attribute: "shortName"),
                          let unit = message.get(attribute: "units"),
                          let stepRange = message.get(attribute: "stepRange"),
                          let stepType = message.get(attribute: "stepType") else {
                        fatalError("could not get step range or type")
                    }
                    let timestamp = try message.getValidTimestamp()
                    let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
                    if shortName == "lsm" {
                        continue
                    }
                    //let levelhPa = message.get(attribute: "level").flatMap(Int.init)!
                    let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                    
                    guard let variable = EcmwfEcdpsIfsVariable.allCases.first(where: {$0.gribCode.split(separator: ",").contains(where: { $0 == shortName})}) else {
                        logger.warning("Could not map variable \(shortName)")
                        continue
                    }
                    
                    //print(message.get(attribute: "packingType"), message.get(attribute: "bitsPerValue"), message.get(attribute: "binaryScaleFactor"))
                    let isMax = [EcmwfEcdpsIfsVariable.wind_gusts_10m, .temperature_2m_max, .temperature_2m_min].contains(variable)
                    let isAccumulated = [EcmwfEcdpsIfsVariable.shortwave_radiation, .direct_radiation, .precipitation, .runoff, .snowfall_water_equivalent, .showers].contains(variable)
                    /// Gusts in hour 0 only contain `0` values. The attributes for stepType and stepRange are not correctly set.
                    if (isAccumulated || isMax) && hour == 0 {
                        continue
                    }
                    
                    // logger.info("Processing \(variable)")
                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    try grib2d.load(message: message)
                    
                    // Deaccumulate precipitation
                    if isAccumulated {
                        // grib attributes for `stepType` are set wrongly to `instant`
                        guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: "accum", stepRange: "0-\(hour)", grib2d: &grib2d) else {
                            continue
                        }
                    }
                    
                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd(dtSeconds: dtSeconds) {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    let writer = try await writer.getWriter(time: timestamp)
                    
                    // Snow depth retrieved as water equivalent. Use snow density to calculate the actual snow depth.
                    if [EcmwfEcdpsIfsVariable.snow_density, .snow_depth].contains(variable) {
                        await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                        try await inMemory.calculateSnowDepth(density: .snow_density, waterEquivalent: .snow_depth, outVariable: EcmwfEcdpsIfsVariable.snow_depth, writer: writer)
                        if variable == .snow_depth {
                            continue
                        }
                    }
                    
                    logger.info("Processing \(variable) member=\(member) unit=\(unit) stepType=\(stepType) stepRange=\(stepRange) timestep=\(timestamp.format_YYYYMMddHH)")
                    try await writer.write(member: member, variable: variable, data: grib2d.array.data)
                }
            }
        }
        try await client.shutdown()
        let handles = try await writer.finalise(completed: true, validTimes: nil, uploadS3Bucket: nil)
        return handles
    }

    /// Download ECMWF ifs open data
    func downloadEcmwf(application: Application, domain: EcmwfEcpdsDomain, server: String, run: Timestamp, concurrent: Int, maxForecastHour: Int?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        if domain == .wam {
            return try await downloadEcmwfWam(application: application, domain: domain, server: server, run: run, concurrent: concurrent, maxForecastHour: maxForecastHour, uploadS3Bucket: uploadS3Bucket)
        }
        
        let logger = application.logger
        // Note 2025-10-08 0z: The delivery for the last forecast hours took more than 4 hours caused by a retry.
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 6, retryUnauthorized: false)
        Process.alarm(seconds: 6 * 3600 + 600)
        defer { Process.alarm(seconds: 0) }

        var forecastHours = domain.getDownloadForecastSteps(run: run.hour)
        if let maxForecastHour {
            forecastHours = forecastHours.filter({ $0 <= maxForecastHour })
        }
        let timestamps = forecastHours.map { run.add(hours: $0) }
        let deaverager = GribDeaverager()
        
        let storeOnDisk = true
        /// Run AWS upload in the background
        var uploadTask: Task<(), any Error>? = nil

        let handles: [GenericVariableHandle] = try await timestamps.enumerated().asyncFlatMap { (i,timestamp) -> [GenericVariableHandle] in
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading hour \(hour)")
            let previousHour = (timestamps[max(0, i-1)].timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            /// Delta time seconds considering irregular timesteps
            let dtSeconds = previousHour == 0 ? domain.dtSeconds : ((hour - previousHour) * 3600)
            
            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: storeOnDisk, realm: nil)

            let inMemory = VariablePerMemberStorage<EcmwfEcdpsIfsVariable>()
            let file = hour == 0 ? 11 : 1
            let prefix = run.hour % 12 == 0 ? "D" : "S"
            let url = "\(server)D1\(prefix)\(run.format_MMddHH)00\(timestamp.format_MMddHH)\(file.zeroPadded(len: 3)).bz2"
            
            try await curl.getGribStream(url: url, bzip2Decode: true, nConcurrent: concurrent).foreachConcurrent(nConcurrent: concurrent) { message in
                guard let shortName = message.get(attribute: "shortName"),
                      let unit = message.get(attribute: "units"),
                      let stepRange = message.get(attribute: "stepRange"),
                      let stepType = message.get(attribute: "stepType") else {
                    fatalError("could not get step range or type")
                }
                if shortName == "lsm" {
                    return
                }
                //let levelhPa = message.get(attribute: "level").flatMap(Int.init)!
                let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                
                guard let variable = EcmwfEcdpsIfsVariable.allCases.first(where: {$0.gribCode.split(separator: ",").contains(where: { $0 == shortName})}) else {
                    logger.warning("Could not map variable \(shortName)")
                    return
                }
                
                //print(message.get(attribute: "packingType"), message.get(attribute: "bitsPerValue"), message.get(attribute: "binaryScaleFactor"))
                let isMax = [EcmwfEcdpsIfsVariable.wind_gusts_10m, .temperature_2m_max, .temperature_2m_min].contains(variable)
                let isAccumulated = [EcmwfEcdpsIfsVariable.shortwave_radiation, .direct_radiation, .precipitation, .runoff, .snowfall_water_equivalent, .showers].contains(variable)
                /// Gusts in hour 0 only contain `0` values. The attributes for stepType and stepRange are not correctly set.
                if (isAccumulated || isMax) && hour == 0 {
                    return
                }
                
                // logger.info("Processing \(variable)")
                var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib2d.load(message: message)
                
                // Deaccumulate precipitation
                if isAccumulated {
                    // grib attributes for `stepType` are set wrongly to `instant`
                    guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: "accum", stepRange: "0-\(hour)", grib2d: &grib2d) else {
                        return
                    }
                }

                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd(dtSeconds: dtSeconds) {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                // Snow depth retrieved as water equivalent. Use snow density to calculate the actual snow depth.
                if [EcmwfEcdpsIfsVariable.snow_density, .snow_depth].contains(variable) {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                    try await inMemory.calculateSnowDepth(density: .snow_density, waterEquivalent: .snow_depth, outVariable: EcmwfEcdpsIfsVariable.snow_depth, writer: writer)
                    if variable == .snow_depth {
                        return
                    }
                }

                logger.info("Processing \(variable) member=\(member) unit=\(unit) stepType=\(stepType) stepRange=\(stepRange) timestep=\(timestamp.format_YYYYMMddHH)")
                try await writer.write(member: member, variable: variable, data: grib2d.array.data)
            }

            
            let completed = i == timestamps.count - 1            
            let handles = try await writer.finalise()
            try await uploadTask?.value
            uploadTask = Task {
                try await writer.writeMetaAndAWSUpload(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket)
            }
            return handles
        }
        try await uploadTask?.value
        await curl.printStatistics()
        return handles
    }
    
    
    /// Download wave model
    func downloadEcmwfWam(application: Application, domain: EcmwfEcpdsDomain, server: String, run: Timestamp, concurrent: Int, maxForecastHour: Int?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        // Note 2025-10-08 0z: The delivery for the last forecast hours took more than 4 hours caused by a retry.
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 6, retryUnauthorized: false)
        Process.alarm(seconds: 6 * 3600 + 600)
        defer { Process.alarm(seconds: 0) }

        var forecastHours = domain.getDownloadForecastSteps(run: run.hour)
        if let maxForecastHour {
            forecastHours = forecastHours.filter({ $0 <= maxForecastHour })
        }
        let timestamps = forecastHours.map { run.add(hours: $0) }
        let storeOnDisk = true
        /// Run AWS upload in the background
        var uploadTask: Task<(), any Error>? = nil

        let handles: [GenericVariableHandle] = try await timestamps.enumerated().asyncFlatMap { (i,timestamp) -> [GenericVariableHandle] in
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading hour \(hour)")
            
            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: storeOnDisk, realm: nil)

            let stream = run.hour % 12 == 0 ? "wave" : "scwv"
            // ope_d2_ifs-ens-cf_od_scwv_fc_20251116T180000Z_20251116T180000Z_0h.bz2
            // ope_d2_ifs-ens-cf_od_wave_fc_20251109T000000Z_20251109T000000Z_0h.bz2
            let url = "\(server)ope_d2_ifs-ens-cf_od_\(stream)_fc_\(run.iso8601_YYYYMMddTHHmm)00Z_\(timestamp.iso8601_YYYYMMddTHHmm)00Z_\(hour)h.bz2"
            
            try await curl.getGribStream(url: url, bzip2Decode: true, nConcurrent: concurrent).foreachConcurrent(nConcurrent: concurrent) { message in
                guard let shortName = message.get(attribute: "shortName"),
                      let unit = message.get(attribute: "units"),
                      let stepRange = message.get(attribute: "stepRange"),
                      let stepType = message.get(attribute: "stepType") else {
                    fatalError("could not get step range or type")
                }
                if shortName == "lsm" {
                    return
                }
                let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                guard let variable = EcmwfEcdpsWamVariable.allCases.first(where: {$0.gribCode.split(separator: ",").contains(where: { $0 == shortName})}) else {
                    logger.warning("Could not map variable \(shortName)")
                    return
                }
                // logger.info("Processing \(variable)")
                var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib2d.load(message: message)
                grib2d.array.flipLatitude()
                
                logger.info("Processing \(variable) member=\(member) unit=\(unit) stepType=\(stepType) stepRange=\(stepRange) timestep=\(timestamp.format_YYYYMMddHH)")
                try await writer.write(member: member, variable: variable, data: grib2d.array.data)
            }
            
            let completed = i == timestamps.count - 1
            let handles = try await writer.finalise()
            try await uploadTask?.value
            uploadTask = Task {
                try await writer.writeMetaAndAWSUpload(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket)
            }
            return handles
        }
        try await uploadTask?.value
        await curl.printStatistics()
        return handles
    }
}
