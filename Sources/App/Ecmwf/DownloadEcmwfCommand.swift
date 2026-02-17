import Foundation
import OmFileFormat
import Vapor
import SwiftNetCDF


/**
 Download from
 https://confluence.ecmwf.int/display/UDOC/ECMWF+Open+Data+-+Real+Time
 https://data.ecmwf.int/forecasts/20220831/00z/0p4-beta/oper/
 
 model info (not everything is open data) https://www.ecmwf.int/en/forecasts/datasets/set-i
 */
struct DownloadEcmwfCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?

        @Option(name: "domain")
        var domain: String?

        @Option(name: "server", help: "Root server path. Default: 'https://data.ecmwf.int/forecasts/'")
        var server: String?

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
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
        
        @Flag(name: "download-full-grib-file", help: "Skip GRIB inventory and process entire file")
        var downloadFullGribFile: Bool
    }

    var help: String {
        "Download a specified ecmwf model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        let domain = signature.domain.map {
            guard let domain = EcmwfDomain(rawValue: $0) else {
                fatalError("Could not initialise domain from \($0)")
            }
            return domain
        } ?? EcmwfDomain.ifs04

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun

        let logger = context.application.logger
        let isWave = domain == .wam025 || domain == .wam025_ensemble

        let onlyVariables = try EcmwfVariable.load(commaSeparatedOptional: signature.onlyVariables)
        let variables = onlyVariables ?? EcmwfVariable.allCases
        let nConcurrent = signature.concurrent ?? 1
        let base = signature.server ?? "https://data.ecmwf.int/forecasts/"

        let waveVariables = [EcmwfWaveVariable.wave_direction, .wave_height, .wave_period, .wave_peak_period]

        if let timeinterval = signature.timeinterval {
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / 4) {
                logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                let handles = isWave ? try await downloadEcmwfWave(application: context.application, domain: domain, base: base, run: run, variables: waveVariables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: nil, downloadFullGribFile: signature.downloadFullGribFile) : try await downloadEcmwf(application: context.application, domain: domain, base: base, run: run, variables: variables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: nil, downloadFullGribFile: signature.downloadFullGribFile)
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }
        logger.info("Downloading domain ECMWF run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        if !isWave {
            try await downloadEcmwfElevation(application: context.application, domain: domain, base: base, run: run)
        }
        let generateFullRun = domain.countEnsembleMember == 1
        let handles = isWave ? try await downloadEcmwfWave(application: context.application, domain: domain, base: base, run: run, variables: waveVariables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: signature.uploadS3Bucket, downloadFullGribFile: signature.downloadFullGribFile) : try await downloadEcmwf(application: context.application, domain: domain, base: base, run: run, variables: variables, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, uploadS3Bucket: signature.uploadS3Bucket, downloadFullGribFile: signature.downloadFullGribFile)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities, generateFullRun: generateFullRun)
    }

    /// Download elevation file
    func downloadEcmwfElevation(application: Application, domain: EcmwfDomain, base: String, run: Timestamp) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm.getFilePath()) {
            return
        }
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)

        var generateElevationFileData: (lsm: [Float]?, surfacePressure: [Float]?, sealevelPressure: [Float]?, temperature_2m: [Float]?) = (nil, nil, nil, nil)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)

        logger.info("Downloading height and elevation data")
        let url = domain.getUrl(base: base, run: run, hour: 0)[0]
        for try await message in try await curl.downloadEcmwfIndexed(url: url, concurrent: 1, downloadFullGribFile: false, isIncluded: { entry in
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
        try elevation.writeOmFile2D(file: domain.surfaceElevationFileOm.getFilePath(), grid: domain.grid)
    }
    
    struct ShortNameLevel: Hashable {
        let shortName: String
        let level: Int
        
        init(_ shortName: String, _ level: Int) {
            self.shortName = shortName
            self.level = level
        }
    }

    /// Download ECMWF ifs open data
    func downloadEcmwf(application: Application, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfVariable], concurrent: Int, maxForecastHour: Int?, uploadS3Bucket: String?, downloadFullGribFile: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        // Retry unauthorized errors, because ECMWF servers randomly return this error code
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 5.5, retryUnauthorized: true)
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }

        var forecastHours = domain.getDownloadForecastSteps(run: run.hour)
        if let maxForecastHour {
            forecastHours = forecastHours.filter({ $0 <= maxForecastHour })
        }
        let timestamps = forecastHours.map { run.add(hours: $0) }
        let deaverager = GribDeaverager()
        
        let storeOnDisk = domain == .ifs025 || domain == .aifs025_single || domain == .wam025
        /// Run AWS upload in the background
        var uploadTask: Task<(), any Error>? = nil

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
            let inMemory = VariablePerMemberStorage<EcmwfVariable>()
            let inMemory2 = VariablePerMemberStorage<ShortNameLevel>()
            
            let rhCalculator = RelativeHumidityCalculator(outVariable: EcmwfVariable.relative_humidity_2m)
            let verticalVelocityCalculator = VerticalVelocityCalculator<EcmwfVariable>()

            /// AIFS025 ensemble stores control and perturbed forecast in different files
            let urls = domain.getUrl(base: base, run: run, hour: hour)
            for url in urls {
                try await curl.downloadEcmwfIndexed(url: url, concurrent: max(2, concurrent), downloadFullGribFile: downloadFullGribFile, isIncluded: { entry in
                    return variables.contains(where: { variable in
                        if entry.param == "max_i10fg" && variable == .wind_gusts_10m {
                            return true
                        }
                        if ["mx2t6", "max_2t", "mx2t3"].contains(entry.param) && variable == .temperature_2m_max {
                            return true
                        }
                        if ["mn2t6", "min_2t", "mn2t3"].contains(entry.param) && variable == .temperature_2m_min {
                            return true
                        }
                        if let level = entry.level {
                            // entry is a pressure level variable
                            if variable.gribName == "gh" && variable.level == level && entry.param == "z" {
                                return true
                            }
                            return variable.level == level && entry.param == variable.gribName
                        }
                        return entry.param == variable.gribName
                    })
                }).foreachConcurrent(nConcurrent: concurrent) { message in
                    guard let shortName = message.get(attribute: "shortName"),
                          var stepRange = message.get(attribute: "stepRange"),
                          let stepType = message.get(attribute: "stepType") else {
                        fatalError("could not get step range or type")
                    }
                    if shortName == "lsm" {
                        return
                    }
                    let levelhPa = message.get(attribute: "level").flatMap(Int.init)!
                    let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                    
                    guard let variable = EcmwfVariable.from(shortName: shortName, levelhPa: levelhPa) else {
                        let name = message.get(attribute: "name") ?? "-"
                        let shortName = message.get(attribute: "shortName") ?? "-"
                        let level = message.get(attribute: "level") ?? "-"
                        let paramId = message.getLong(attribute: "paramId") ?? -1
                        logger.debug("Got unknown variable \(shortName) id=\(paramId) level=\(level) '\(name)'")
                        return
                    }
                    //print(message.get(attribute: "packingType"), message.get(attribute: "bitsPerValue"), message.get(attribute: "binaryScaleFactor"))
                    /// Gusts in hour 0 only contain `0` values. The attributes for stepType and stepRange are not correctly set.
                    if [EcmwfVariable.wind_gusts_10m, .temperature_2m_max, .temperature_2m_min, .shortwave_radiation, .precipitation, .runoff].contains(variable) && hour == 0 {
                        return
                    }
                    
                    // logger.info("Processing \(variable)")
                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    try grib2d.load(message: message)
                    grib2d.array.flipLatitude()
                    
                    // try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: false)
                    // fatalError()
                    
                    /// Note 2025-08-01: The latest AIFS update sets wrong stepRange parameter
                    if domain == .aifs025_single && stepType == "accum" {
                        logger.debug("Overwriting stepRange for AIFS025_single from \(stepRange) to 0-\(hour)")
                        stepRange = "0-\(hour)"
                    }
                    
                    // solar shortwave radition show accum with step range "90"
                    if stepType == "accum" && !stepRange.contains("-") {
                        stepRange = "0-\(stepRange)"
                    }
                    
                    // Deaccumulate precipitation
                    guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                        return
                    }
                    
                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd(domain: domain, dtSeconds: dtSeconds) {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }
                    
                    if shortName == "z" && [EcmwfDomain.aifs025, .aifs025_single, .aifs025_ensemble].contains(domain) {
                        grib2d.array.data.multiplyAdd(multiply: 1 / 9.80665, add: 0)
                    }
                    
                    // Keep relative humidity in memory to generate total cloud cover files
                    if variable.gribName == "r" {
                        await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                    }
                    
                    // Snow depth retrieved as water equivalent. Use snow density to calculate the actual snow depth.
                    if ["sd", "rsn"].contains(shortName) {
                        await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                        try await inMemory.calculateSnowDepth(density: .snow_depth, waterEquivalent: .snow_depth_water_equivalent, outVariable: EcmwfVariable.snow_depth, writer: writer)
                        if variable == .snow_depth {
                            return
                        }
                    }
                    
                    // Calculate geometric vertical velocity
                    if ["t", "w"].contains(shortName) {
                        let level = Float(levelhPa)
                        let vvVariable = EcmwfVariable.from(shortName: "w", levelhPa: levelhPa)!
                        switch shortName {
                        case "t":
                            try await verticalVelocityCalculator.ingest(.temperature(grib2d.array), member: member, pressureLevel: level, outVariable: vvVariable, writer: writer)
                        case "w":
                            try await verticalVelocityCalculator.ingest(.omega(grib2d.array), member: member, pressureLevel: level, outVariable: vvVariable, writer: writer)
                            return // do not store omega on disk
                        default:
                            break
                        }
                    }
                    
                    // Calculate relative humidity for AIFS on pressure level
                    if [EcmwfDomain.aifs025_single, .aifs025_ensemble].contains(domain) && ["t", "q"].contains(variable.gribName) {
                        await inMemory2.set(variable: ShortNameLevel(shortName, levelhPa), timestamp: timestamp, member: member, data: grib2d.array)
                        while let (t, q, member) = await inMemory2.getTwoRemoving(first: ShortNameLevel("t", levelhPa), second: ShortNameLevel("q", levelhPa), timestamp: timestamp) {
                            let rh = zip(t.data, q.data).map { t, q in
                                return Meteorology.specificToRelativeHumidity(specificHumidity: q, temperature: t, pressure: Float(levelhPa))
                            }
                            await inMemory.set(variable: .from(shortName: "r", levelhPa: levelhPa)!, timestamp: writer.time, member: member, data: Array2D(data: rh, nx: t.nx, ny: t.ny))
                            try await writer.write(member: member, variable: EcmwfVariable.from(shortName: "r", levelhPa: levelhPa)!, data: rh)
                        }
                    }
                    
                    // Never write specific humidity
                    if ["q"].contains(variable.gribName) {
                        return
                    }
                    
                    // Keep pressure level RH in memory for cloud cover calculation
                    if variable.gribName == "r" && levelhPa > 10 {
                        await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                    }
                    
                    if variable == .temperature_2m {
                        try await rhCalculator.ingest(.temperature(grib2d.array), member: member, writer: writer)
                    }
                    
                    if variable == .dew_point_2m {
                        try await rhCalculator.ingest(.dewpoint(grib2d.array), member: member, writer: writer)
                        return // do not store dewpoint on disk
                    }

                    // Keep precip in memory for probability
                    if domain.countEnsembleMember > 1 && variable == .precipitation {
                        await inMemory.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                    }
                    //let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    // Note: skipHour0 needs still to be set for solar interpolation
                    logger.info("Processing \(variable) member \(member) timestep \(timestamp.format_YYYYMMddHH)")
                    try await writer.write(member: member, variable: variable, data: grib2d.array.data)
                }
            }

            // Calculate mid/low/high/total cloudocover
            logger.info("Calculating derived variables")
            for member in 0..<domain.countEnsembleMember {
                logger.info("Calculating cloud cover")
                // 2025-10-13: added 100/150/600/400 hPa levels
                guard let rh1000 = await inMemory.get(variable: .relative_humidity_1000hPa, timestamp: timestamp, member: member)?.data,
                      let rh925 = await inMemory.get(variable: .relative_humidity_925hPa, timestamp: timestamp, member: member)?.data,
                      let rh850 = await inMemory.get(variable: .relative_humidity_850hPa, timestamp: timestamp, member: member)?.data,
                      let rh700 = await inMemory.get(variable: .relative_humidity_700hPa, timestamp: timestamp, member: member)?.data,
                      let rh600 = await inMemory.get(variable: .relative_humidity_600hPa, timestamp: timestamp, member: member)?.data,
                      let rh500 = await inMemory.get(variable: .relative_humidity_500hPa, timestamp: timestamp, member: member)?.data,
                      let rh400 = await inMemory.get(variable: .relative_humidity_400hPa, timestamp: timestamp, member: member)?.data,
                      let rh300 = await inMemory.get(variable: .relative_humidity_300hPa, timestamp: timestamp, member: member)?.data,
                      let rh250 = await inMemory.get(variable: .relative_humidity_250hPa, timestamp: timestamp, member: member)?.data,
                      let rh200 = await inMemory.get(variable: .relative_humidity_200hPa, timestamp: timestamp, member: member)?.data,
                      let rh150 = await inMemory.get(variable: .relative_humidity_150hPa, timestamp: timestamp, member: member)?.data,
                      let rh100 = await inMemory.get(variable: .relative_humidity_100hPa, timestamp: timestamp, member: member)?.data,
                      let rh50 = await inMemory.get(variable: .relative_humidity_50hPa, timestamp: timestamp, member: member)?.data else {
                    logger.warning("Pressure level relative humidity unavailable")
                    continue
                }
                /// low clouds (surface - 3km): 1000/925/850
                let cloudcoverLow = zip(rh1000, zip(rh925, rh850)).map {
                    return max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0, pressureHPa: 1000),
                               max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 925),
                                   Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 850)))
                }
                /// mid clouds (3 km - 8km): 700/600/500/400
                let cloudcoverMid = zip(zip(rh700, rh600), zip(rh500, rh400)).map {
                    return max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.0, pressureHPa: 700),
                        max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.1, pressureHPa: 600),
                               max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0, pressureHPa: 500),
                                   Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1, pressureHPa: 400))))
                }
                /// high clouds (>8 km): 300/250/200/150/100/50
                let cloudcoverHigh = zip(zip(rh300, rh250), zip(zip(rh200, rh150), zip(rh100, rh50))).map {
                    return max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.0, pressureHPa: 300),
                            max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.0.1, pressureHPa: 250),
                                max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0.0, pressureHPa: 200),
                                    max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.0.1, pressureHPa: 150),
                                        max(Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1.0, pressureHPa: 100),
                                            Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0.1.1.1, pressureHPa: 50))))))
                }
                
                try await writer.write(member: member, variable: EcmwfVariable.cloud_cover_low, data: cloudcoverLow)
                try await writer.write(member: member, variable: EcmwfVariable.cloud_cover_mid, data: cloudcoverMid)
                try await writer.write(member: member, variable: EcmwfVariable.cloud_cover_high, data: cloudcoverHigh)
                if await !writer.contains(member: member, variable: EcmwfVariable.cloud_cover) {
                    let cloudcover = Meteorology.cloudCoverTotal(low: cloudcoverLow, mid: cloudcoverMid, high: cloudcoverHigh)
                    try await writer.write(member: member, variable: EcmwfVariable.cloud_cover, data: cloudcover)
                }
            }

            if let writerProbabilities {
                logger.info("Calculating precipitation probability")
                try await inMemory.calculatePrecipitationProbability(
                    precipitationVariable: .precipitation,
                    dtHoursOfCurrentStep: hour - previousHour,
                    writer: writerProbabilities
                )
            }
            
            let completed = i == timestamps.count - 1
            let handles = try await writer.finalise() + (writerProbabilities?.finalise() ?? [])
            try await uploadTask?.value
            uploadTask = Task {
                try await writer.writeMetaAndAWSUpload(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket)
                try await writerProbabilities?.writeMetaAndAWSUpload(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket)
            }
            return handles
        }
        await curl.printStatistics()
        return handles
    }

    /// Download ECMWF ifs open data
    func downloadEcmwfWave(application: Application, domain: EcmwfDomain, base: String, run: Timestamp, variables: [EcmwfWaveVariable], concurrent: Int, maxForecastHour: Int?, uploadS3Bucket: String?, downloadFullGribFile: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 5.5)
        Process.alarm(seconds: 6 * 3600)
        defer { Process.alarm(seconds: 0) }
        
        if variables.isEmpty {
            return []
        }

        var forecastHours = domain.getDownloadForecastSteps(run: run.hour)
        if let maxForecastHour {
            forecastHours = forecastHours.filter({ $0 <= maxForecastHour })
        }
        let timestamps = forecastHours.map { run.add(hours: $0) }
        /// Run AWS upload in the background
        var uploadTask: Task<(), any Error>? = nil

        let handles: [GenericVariableHandle] = try await timestamps.enumerated().asyncFlatMap { (i,timestamp) -> [GenericVariableHandle] in
            let hour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading hour \(hour)")
            
            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: domain == .wam025, realm: nil)

            let url = domain.getUrl(base: base, run: run, hour: hour)[0]
            try await curl.downloadEcmwfIndexed(url: url, concurrent: concurrent, downloadFullGribFile: downloadFullGribFile, isIncluded: { entry in
                return variables.contains(where: { variable in
                    return entry.param == variable.gribName
                })
            }).foreachConcurrent(nConcurrent: concurrent) { message in
                guard let shortName = message.get(attribute: "shortName") else {
                    fatalError("could not get step range or type")
                }
                if shortName == "lsm" {
                    return
                }
                let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0

                guard let variable = variables.first(where: { variable in
                    return shortName == variable.gribName
                }) else {
                    let name = message.get(attribute: "name") ?? "-"
                    let shortName = message.get(attribute: "shortName") ?? "-"
                    let level = message.get(attribute: "level") ?? "-"
                    let paramId = message.getLong(attribute: "paramId") ?? -1
                    logger.debug("Got unknown variable \(shortName) id=\(paramId) level=\(level) '\(name)'")
                    return
                }
                // logger.info("Processing \(variable)")
                var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                try grib2d.load(message: message)
                grib2d.array.flipLatitude()
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
        await curl.printStatistics()
        return handles
    }
}

extension EcmwfDomain {
    /// Based on the current time , guess the current run that should be available soon on the open-data server
    fileprivate var lastRun: Timestamp {
        let t = Timestamp.now()
        switch self {
        case .ifs04_ensemble, .ifs025_ensemble, .wam025_ensemble, .ifs04, . ifs025, .wam025:
            // ECMWF has a delay of 7-8 hours after initialisation
            return t.subtract(hours: 6).floor(toNearestHour: 6)
        case .aifs025, .aifs025_single, .aifs025_ensemble:
            // AIFS025 has a delay of 5-7 hours after initialisation
            return t.subtract(hours: 4).floor(toNearestHour: 6)
        }
    }
    /// Get download url for a given domain and timestep
    fileprivate func getUrl(base: String, run: Timestamp, hour: Int) -> [String] {
        let runStr = run.hour.zeroPadded(len: 2)
        let dateStr = run.format_YYYYMMdd
        switch self {
        case .ifs04:
            let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
            return ["\(base)\(dateStr)/\(runStr)z/ifs/0p4-beta/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"]
        case .wam025:
            let product = run.hour == 0 || run.hour == 12 ? "wave" : "scwv"
            return ["\(base)\(dateStr)/\(runStr)z/ifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"]
        case .wam025_ensemble:
            let product = run.hour == 0 || run.hour == 12 ? "waef" : "scda"
            return ["\(base)\(dateStr)/\(runStr)z/ifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-ef.grib2"]
        case .ifs04_ensemble:
            return ["\(base)\(dateStr)/\(runStr)z/ifs/0p4-beta/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-ef.grib2"]
        case .ifs025:
            let product = run.hour == 0 || run.hour == 12 ? "oper" : "scda"
            return ["\(base)\(dateStr)/\(runStr)z/ifs/0p25/\(product)/\(dateStr)\(runStr)0000-\(hour)h-\(product)-fc.grib2"]
        case .ifs025_ensemble:
            return ["\(base)\(dateStr)/\(runStr)z/ifs/0p25/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-ef.grib2"]
        case .aifs025:
            return ["\(base)\(dateStr)/\(runStr)z/aifs/0p25/oper/\(dateStr)\(runStr)0000-\(hour)h-oper-fc.grib2"]
        case .aifs025_single:
            // https://data.ecmwf.int/forecasts/20250220/00z/aifs-single/0p25/experimental/oper/
            return ["\(base)\(dateStr)/\(runStr)z/aifs-single/0p25/oper/\(dateStr)\(runStr)0000-\(hour)h-oper-fc.grib2"]
        case .aifs025_ensemble:
            // control and perturbed runs are stored in different files
            return [
                "\(base)\(dateStr)/\(runStr)z/aifs-ens/0p25/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-cf.grib2",
                "\(base)\(dateStr)/\(runStr)z/aifs-ens/0p25/enfo/\(dateStr)\(runStr)0000-\(hour)h-enfo-pf.grib2"
            ]
        }
    }
}
