import Foundation
import OmFileFormat
import Vapor
@preconcurrency import SwiftEccodes

/**
 Downloader for GFS GraphCast, AIGFS and AIGEFS
 */
struct GfsGraphCastDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?

        @Argument(name: "domain")
        var domain: String

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?

        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?
        
        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }

    var help: String {
        "Download a specified GFS GraphCast model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        let domain = try GfsGraphCastDomain.load(rawValue: signature.domain)
        if let timeinterval = signature.timeinterval {
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / domain.runsPerDay) {
                try await downloadRun(using: context, signature: signature, run: run, domain: domain)
            }
            return
        }
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        try await downloadRun(using: context, signature: signature, run: run, domain: domain)
    }

    func downloadRun(using context: CommandContext, signature: Signature, run: Timestamp, domain: GfsGraphCastDomain) async throws {
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let nConcurrent = signature.concurrent ?? 1
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent, uploadS3Bucket: signature.uploadS3Bucket)
        
        for (domain, handles) in handles {
            let generateFullRun = domain.countEnsembleMember == 1
            try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: signature.uploadS3OnlyProbabilities, generateFullRun: generateFullRun, generateTimeSeries: true)
        }
    }

    func getCmaVariable(logger: Logger, message: GribMessage) -> (any GfsGraphCastVariableDownloadable)? {
        guard let shortName = message.get(attribute: "shortName"),
              let stepRange = message.get(attribute: "stepRange"),
              let stepType = message.get(attribute: "stepType"),
              let typeOfLevel = message.get(attribute: "typeOfLevel"),
              let scaledValueOfFirstFixedSurface = message.get(attribute: "scaledValueOfFirstFixedSurface"),
              let scaledValueOfSecondFixedSurface = message.get(attribute: "scaledValueOfSecondFixedSurface"),
              let levelStr = message.get(attribute: "level"),
              let level = Int(levelStr),
              let parameterName = message.get(attribute: "parameterName"),
              let parameterUnits = message.get(attribute: "parameterUnits"),
              let cfName = message.get(attribute: "cfName"),
              let paramId = message.get(attribute: "paramId")
        else {
            fatalError("could not get step range or type")
        }

        switch typeOfLevel {
        case "isobaricInhPa":
            if level < 10 {
                return nil
            }
            switch parameterName {
            case "Temperature":
                return GfsGraphCastPressureVariable(variable: .temperature, level: level)
            case "u-component of wind":
                return GfsGraphCastPressureVariable(variable: .wind_u_component, level: level)
            case "v-component of wind":
                return GfsGraphCastPressureVariable(variable: .wind_v_component, level: level)
            case "Geopotential height":
                return GfsGraphCastPressureVariable(variable: .geopotential_height, level: level)
            case "Vertical velocity (pressure)":
                return GfsGraphCastPressureVariable(variable: .vertical_velocity, level: level)
            case "Specific humidity": // specific humidity if converted to relative humidity 
                return GfsGraphCastPressureVariable(variable: .relative_humidity, level: level)
            default:
                return nil
            }
        case "surface":
            switch parameterName {
            case "Total precipitation": return GfsGraphCastSurfaceVariable.precipitation
            default: break
            }
        case "meanSea":
            switch parameterName {
            case "Pressure reduced to MSL": return GfsGraphCastSurfaceVariable.pressure_msl
            default: break
            }
        case "heightAboveGround":
            switch (parameterName, level) {
            case ("Temperature", 2): return GfsGraphCastSurfaceVariable.temperature_2m
            case ("v-component of wind", 10): return GfsGraphCastSurfaceVariable.wind_v_component_10m
            case ("u-component of wind", 10): return GfsGraphCastSurfaceVariable.wind_u_component_10m
            default: break
            }
        default: break
        }
        logger.debug("Unmapped GRIB message \(shortName) \(stepRange) \(stepType) \(typeOfLevel) \(level) \(parameterName) \(parameterUnits) \(cfName) \(scaledValueOfFirstFixedSurface) \(scaledValueOfSecondFixedSurface) \(paramId)")
        return nil
    }

    func download(application: Application, domain: GfsGraphCastDomain, run: Timestamp, concurrent: Int, uploadS3Bucket: String?) async throws -> [GfsGraphCastDomain: [GenericVariableHandle]] {
        let logger = application.logger
        let deadLineHours: Double = domain == .aigefs025 ? 6 : 4
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        let timestamps = domain.forecastHours(run: run.hour).map { run.add(hours: $0) }
        let isEnsemble = domain.countEnsembleMember > 1
        let members = 0..<domain.countEnsembleMember
        
        /// Run AWS upload in the background
        var uploadTask: Task<(), any Error>? = nil
        
        var handlesEnsembleMean = [GenericVariableHandle]()
        
        let handles = try await timestamps.enumerated().asyncFlatMap { (i,timestamp) -> [GenericVariableHandle] in
            let forecastHour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            logger.info("Downloading forecastHour \(forecastHour)")
            
            let storePrecipMembers = VariablePerMemberStorage<GfsGraphCastSurfaceVariable>()
            let writer = OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: !isEnsemble, realm: nil)
            let writerProbabilities = isEnsemble ? OmSpatialTimestepWriter(domain: domain, run: run, time: timestamp, storeOnDisk: true, realm: nil) : nil
            let ensembleMean = domain.ensembleMeanDomain.map {(
                writer: OmSpatialTimestepWriter(domain: $0, run: run, time: timestamp, storeOnDisk: true, realm: nil),
                 calculator: EnsembleMeanCalculator()
            )}
            
            try await members.foreachConcurrent(nConcurrent: 2) { member in
                let urls = domain.getGribUrl(run: run, forecastHour: forecastHour, member: member)
                let storage = VariablePerMemberStorage<GfsGraphCastPressureVariable>()
                
                for url in urls {
                    for try await message in try await curl.getGribStream(url: url, bzip2Decode: false, nConcurrent: min(2, concurrent)) {
                        guard var variable = getCmaVariable(logger: logger, message: message) else {
                            continue
                        }
                        /// HGEFS provides std dev directly
                        let isSpread = message.getLong(attribute: "derivedForecast") == 2
                        if isSpread, let v = variable as? GfsGraphCastSurfaceVariable {
                            variable = VariableOrSpread(variable: v, isSpread: true)
                        }
                        if isSpread, let v = variable as? GfsGraphCastPressureVariable {
                            if [GfsGraphCastPressureVariableType.relative_humidity, .vertical_velocity].contains(v.variable) {
                                // Cannot convert specific humidity spread to relative humidity spread.
                                // Well could, but too much work because error propagation maths gets complicated
                                continue
                            }
                            variable = VariableOrSpread(variable: v, isSpread: true)
                        }
                        
                        guard let stepRange = message.get(attribute: "stepRange") else {
                            fatalError("could not get step range or type")
                        }

                        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                        // message.dumpAttributes()
                        try grib2d.load(message: message)
                        grib2d.array.shift180LongitudeAndFlipLatitude()

                        // Scaling before compression with scale-factor
                        if let fma = variable.multiplyAdd {
                            grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                        }
                        
                        if let variable = variable as? GfsGraphCastSurfaceVariable , variable == .precipitation {
                            // There are 2 precipitation messages inside. Actually the second is no precipitation
                            if stepRange.starts(with: "0-") {
                                continue
                            }
                            // Store precipitation for probabilities
                            await storePrecipMembers.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                        }

                        if let variable = variable as? GfsGraphCastPressureVariable, [GfsGraphCastPressureVariableType.temperature, .relative_humidity, .vertical_velocity].contains(variable.variable) {
                            await storage.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                            if variable.variable == .relative_humidity || variable.variable == .vertical_velocity {
                                // do not store specific humidity on disk
                                continue
                            }
                        }
                        
                        logger.info("Compressing and writing data \(variable.omFileName.file) hour \(forecastHour) member \(member)")
                        try await writer.write(member: member, variable: variable, data: grib2d.array.data)
                        await ensembleMean?.calculator.ingest(variable: variable, spreadVariable: variable.asSpreadVariableGeneric, data: grib2d.array.data)
                    }
                }
                
                /// Convert specific humidity to relative humidity
                try await storage.data.foreachConcurrent(nConcurrent: concurrent) { v, data in
                    guard v.variable.variable == .relative_humidity else {
                        return
                    }
                    let level = v.variable.level
                    logger.info("Calculating relative humidity on level \(level)")
                    guard let t = await storage.get(v.with(variable: .init(variable: .temperature, level: level))) else {
                        fatalError("Requires temperature in level \(level)")
                    }

                    let data = Meteorology.specificToRelativeHumidity(specificHumidity: data.data, temperature: t.data, pressure: Float(level))

                    let rhVariable = GfsGraphCastPressureVariable(variable: .relative_humidity, level: level)
                    // Store to calculate cloud cover
                    await storage.set(variable: rhVariable, timestamp: timestamp, member: member, data: Array2D(data: data, nx: t.nx, ny: t.ny))
                    try await writer.write(member: member, variable: rhVariable, data: data)
                    await ensembleMean?.calculator.ingest(variable: rhVariable, spreadVariable: rhVariable.asSpreadVariableGeneric, data: data)
                }

                // convert pressure vertical velocity to geometric velocity
                try await storage.data.foreachConcurrent(nConcurrent: concurrent) { v, data in
                    guard v.variable.variable == .vertical_velocity else {
                        return
                    }
                    let level = v.variable.level
                    logger.info("Calculating vertical velocity on level \(level)")
                    guard let t = await storage.get(v.with(variable: .init(variable: .temperature, level: level))) else {
                        fatalError("Requires temperature_2m")
                    }
                    let data = Meteorology.verticalVelocityPressureToGeometric(omega: data.data, temperature: t.data, pressureLevel: Float(level))
                    try await writer.write(member: member, variable: v.variable, data: data)
                    await ensembleMean?.calculator.ingest(variable:  v.variable, spreadVariable:  v.variable.asSpreadVariableGeneric, data: data)
                }

                // Calculate cloud cover mid/low/high/total
                logger.info("Calculating cloud cover mid/low/high/total")
                var cloudcover_low = [Float](repeating: .nan, count: domain.grid.count)
                var cloudcover_mid = [Float](repeating: .nan, count: domain.grid.count)
                var cloudcover_high = [Float](repeating: .nan, count: domain.grid.count)
                for (v, data) in await storage.data {
                    guard v.variable.variable == .relative_humidity else {
                        continue
                    }
                    let level = v.variable.level
                    let clouds = data.data.map { Meteorology.relativeHumidityToCloudCover(relativeHumidity: $0, pressureHPa: Float(level)) }
                    switch level {
                    case ...300:
                        /// high clouds (>8 km): 300/250/200/150/100/50
                        for i in cloudcover_high.indices {
                            if cloudcover_high[i].isNaN || cloudcover_high[i] < clouds[i] {
                                cloudcover_high[i] = clouds[i]
                            }
                        }
                    case ...700:
                        /// mid clouds (3 km - 8km): 700/600/500/400
                        for i in cloudcover_mid.indices {
                            if cloudcover_mid[i].isNaN || cloudcover_mid[i] < clouds[i] {
                                cloudcover_mid[i] = clouds[i]
                            }
                        }
                    default:
                        /// low clouds (surface - 3km): 1000/925/850
                        for i in cloudcover_low.indices {
                            if cloudcover_low[i].isNaN || cloudcover_low[i] < clouds[i] {
                                cloudcover_low[i] = clouds[i]
                            }
                        }
                    }
                }
                let cloudcover = Meteorology.cloudCoverTotal(
                    low: cloudcover_low,
                    mid: cloudcover_mid,
                    high: cloudcover_high
                )
                try await writer.write(member: member, variable: GfsGraphCastSurfaceVariable.cloud_cover_low, data: cloudcover_low)
                try await writer.write(member: member, variable: GfsGraphCastSurfaceVariable.cloud_cover_mid, data: cloudcover_mid)
                try await writer.write(member: member, variable: GfsGraphCastSurfaceVariable.cloud_cover_high, data: cloudcover_high)
                try await writer.write(member: member, variable: GfsGraphCastSurfaceVariable.cloud_cover, data: cloudcover)
                
                await ensembleMean?.calculator.ingest(variable: GfsGraphCastSurfaceVariable.cloud_cover_low, spreadVariable: GfsGraphCastSurfaceVariable.cloud_cover_low.asSpreadVariableGeneric, data: cloudcover_low)
                await ensembleMean?.calculator.ingest(variable: GfsGraphCastSurfaceVariable.cloud_cover_mid, spreadVariable: GfsGraphCastSurfaceVariable.cloud_cover_mid.asSpreadVariableGeneric, data: cloudcover_mid)
                await ensembleMean?.calculator.ingest(variable: GfsGraphCastSurfaceVariable.cloud_cover_high, spreadVariable: GfsGraphCastSurfaceVariable.cloud_cover_high.asSpreadVariableGeneric, data: cloudcover_high)
                await ensembleMean?.calculator.ingest(variable: GfsGraphCastSurfaceVariable.cloud_cover, spreadVariable: GfsGraphCastSurfaceVariable.cloud_cover.asSpreadVariableGeneric, data: cloudcover)
            }
            
            if let writerProbabilities {
                let previousHour = (timestamps[max(0, i-1)].timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
                try await storePrecipMembers.calculatePrecipitationProbability(
                    precipitationVariable: .precipitation,
                    dtHoursOfCurrentStep: forecastHour - previousHour,
                    writer: writerProbabilities
                )
            }
            
            if let ensembleMean {
                try await ensembleMean.calculator.calculateAndWrite(to: ensembleMean.writer)
                handlesEnsembleMean.append(contentsOf: try await ensembleMean.writer.finalise())
            }
            
            let completed = i == timestamps.count - 1
            let handles = try await writer.finalise() + (writerProbabilities?.finalise() ?? [])
            try await uploadTask?.value
            uploadTask = Task {
                try await writer.writeMetaAndAWSUpload(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket)
                try await writerProbabilities?.writeMetaAndAWSUpload(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket)
                try await ensembleMean?.writer.writeMetaAndAWSUpload(completed: completed, validTimes: Array(timestamps[0...i]), uploadS3Bucket: uploadS3Bucket)
            }
            
            return handles
        }
        try await uploadTask?.value
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        
        if let ensembleMeanDomain = domain.ensembleMeanDomain {
            return [domain: handles, ensembleMeanDomain : handlesEnsembleMean]
        }
        return [domain: handles]
    }
}
