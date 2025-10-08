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

        @Option(name: "only-variables")
        var onlyVariables: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
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

        let variables = try EcmwfEcdpsIfsVariable.load(commaSeparatedOptional: signature.onlyVariables) ?? EcmwfEcdpsIfsVariable.allCases
        let nConcurrent = signature.concurrent ?? 2
        guard let server = signature.server else {
            fatalError("Parameter server is required")
        }

        if let timeinterval = signature.timeinterval {
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / 4) {
                logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                let handles = try await downloadEcmwf(application: context.application, domain: domain, server: server, run: run, variables: variables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: nil)
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }
        logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        //try await downloadEcmwfElevation(application: context.application, domain: domain, base: base, run: run)
        let handles = try await downloadEcmwf(application: context.application, domain: domain, server: server, run: run, variables: variables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: signature.uploadS3Bucket)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities)
    }

    /// Download elevation file
    func downloadEcmwfElevation(application: Application, domain: EcmwfEcpdsDomain, server: String, run: Timestamp) async throws {
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

    /// Download ECMWF ifs open data
    func downloadEcmwf(application: Application, domain: EcmwfEcpdsDomain, server: String, run: Timestamp, variables: [EcmwfEcdpsIfsVariable], concurrent: Int, maxForecastHour: Int?, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
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

        let handles: [GenericVariableHandle] = try await timestamps.enumerated().asyncFlatMap { (i,timestamp) -> [GenericVariableHandle] in
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading hour \(hour)")
            let previousHour = (timestamps[max(0, i-1)].timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            /// Delta time seconds considering irregular timesteps
            let dtSeconds = previousHour == 0 ? domain.dtSeconds : ((hour - previousHour) * 3600)
            
            let writerProbabilities = domain.countEnsembleMember > 1 ? OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: true, realm: nil) : nil
            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: storeOnDisk, realm: nil)

            if variables.isEmpty {
                return []
            }
            let inMemory = VariablePerMemberStorage<EcmwfEcdpsIfsVariable>()
            let file = hour == 0 ? 11 : 1
            let prefix = run.hour % 12 == 0 ? "D" : "S"
            let url = "\(server)D1\(prefix)\(run.format_MMddHH)00\(timestamp.format_MMddHH)\(file.zeroPadded(len: 3)).bz2"
            
            try await curl.downloadGrib(url: url, bzip2Decode: true, nConcurrent: concurrent).foreachConcurrent(nConcurrent: concurrent) { message in
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
                
                guard let variable = EcmwfEcdpsIfsVariable.allCases.first(where: {$0.gribCode == shortName}) else {
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
                grib2d.array.flipLatitude()
                
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

                /*if variable == .temperature_2m {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                }
                
                if variable == .dew_point_2m {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                    return
                }
                // Keep precip in memory for probability
                if domain.countEnsembleMember > 1 && variable == .precipitation {
                    await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                }*/
                
                logger.info("Processing \(variable) member=\(member) unit=\(unit) stepType=\(stepType) stepRange=\(stepRange) timestep=\(timestamp.format_YYYYMMddHH)")
                try await writer.write(member: member, variable: variable, data: grib2d.array.data)
            }

            // Calculate mid/low/high/total cloudocover
            /*logger.info("Calculating derived variables")
            for member in 0..<domain.countEnsembleMember {
                /// calculate RH 2m from dewpoint. Only store RH on disk.
                if let dewpoint = await inMemory.get(variable: .dew_point_2m, timestamp: timestamp, member: member)?.data,
                   let temperature = await inMemory.get(variable: .temperature_2m, timestamp: timestamp, member: member)?.data {
                    let rh = zip(temperature, dewpoint).map(Meteorology.relativeHumidity)
                    try await writer.write(member: member, variable: EcmwfVariable.relative_humidity_2m, data: rh)
                }
            }*/

            /*if let writerProbabilities {
                logger.info("Calculating precipitation probability")
                try await inMemory.calculatePrecipitationProbability(
                    precipitationVariable: .precipitation,
                    dtHoursOfCurrentStep: hour - previousHour,
                    writer: writerProbabilities
                )
            }*/
            
            let completed = i == timestamps.count - 1
            return try await writer.finalise(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket) + (writerProbabilities?.finalise(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket) ?? [])
        }
        await curl.printStatistics()
        return handles
    }
}
