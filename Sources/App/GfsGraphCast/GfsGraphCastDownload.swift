import Foundation
import OmFileFormat
import Vapor
@preconcurrency import SwiftEccodes

/**
 Downloader for GFS GraphCast
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
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }

    func getCmaVariable(logger: Logger, message: GribMessage) -> GfsGraphCastVariableDownloadable? {
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
            case "Specific humidity":
                return GfsGraphCastPressureVariable(variable: .specific_humdity, level: level)
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

    func download(application: Application, domain: GfsGraphCastDomain, run: Timestamp, concurrent: Int, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 4
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        let forecastHours = domain.forecastHours(run: run.hour)
        let writer = OmRunSpatialWriter(domain: domain, run: run, storeOnDisk: true)

        // https://noaa-nws-graphcastgfs-pds.s3.amazonaws.com/graphcastgfs.20240401/00/forecasts_13_levels/graphcastgfs.t00z.pgrb2.0p25.f006
        let server = "https://noaa-nws-graphcastgfs-pds.s3.amazonaws.com/"
        let handles = try await forecastHours.asyncFlatMap { forecastHour -> [GenericVariableHandle] in
            let thhh = forecastHour.zeroPadded(len: 3)
            let url = "\(server)graphcastgfs.\(run.format_YYYYMMdd)/\(run.hh)/forecasts_13_levels/graphcastgfs.t\(run.hh)z.pgrb2.0p25.f\(thhh)"
            let timestamp = run.add(hours: forecastHour)
            let storage = VariablePerMemberStorage<GfsGraphCastPressureVariable>()
            let handles = try await curl.withGribStream(url: url, bzip2Decode: false, nConcurrent: concurrent) { stream in
                return try await stream.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                    guard let variable = getCmaVariable(logger: logger, message: message) else {
                        return nil
                    }
                    guard let stepRange = message.get(attribute: "stepRange") else {
                        fatalError("could not get step range or type")
                    }

                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    // message.dumpAttributes()
                    try grib2d.load(message: message)
                    grib2d.array.shift180LongitudeAndFlipLatitude()

                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }

                    if let variable = variable as? GfsGraphCastSurfaceVariable, variable == .precipitation {
                        // There are 2 precipitation messages inside. Actiually the second is no precip
                        if stepRange.starts(with: "0-") {
                            return nil
                        }
                    }

                    if let variable = variable as? GfsGraphCastPressureVariable, [GfsGraphCastPressureVariableType.temperature, .specific_humdity, .vertical_velocity].contains(variable.variable) {
                        await storage.set(variable: variable, timestamp: timestamp, member: 0, data: grib2d.array)
                        if variable.variable == .specific_humdity || variable.variable == .vertical_velocity {
                            // do not store specific humidity on disk
                            return nil
                        }
                    }

                    logger.info("Compressing and writing data to \(variable.omFileName.file)_\(forecastHour).om")
                    return try writer.write(time: timestamp, member: 0, variable: variable, data: grib2d.array.data)
                }.collect().compactMap({ $0 })
            }

            /// Convert specific humidity to relative humidity
            let handles2 = try await storage.data.mapConcurrent(nConcurrent: concurrent) { v, data -> GenericVariableHandle? in
                guard v.variable.variable == .specific_humdity else {
                    return nil
                }
                let level = v.variable.level
                logger.info("Calculating relative humidity on level \(level)")
                guard let t = await storage.get(v.with(variable: .init(variable: .temperature, level: level))) else {
                    fatalError("Requires temperature_2m")
                }

                let data = Meteorology.specificToRelativeHumidity(specificHumidity: data.data, temperature: t.data, pressure: .init(repeating: Float(level), count: t.count))

                let rhVariable = GfsGraphCastPressureVariable(variable: .relative_humidity, level: level)
                // Store to calculate cloud cover
                await storage.set(variable: rhVariable, timestamp: timestamp, member: 0, data: Array2D(data: data, nx: t.nx, ny: t.ny))
                return try writer.write(time: timestamp, member: 0, variable: rhVariable, data: data)
            }.compactMap({ $0 })

            // convert pressure vertical velocity to geometric velocity
            let handles3 = try await storage.data.mapConcurrent(nConcurrent: concurrent) { v, data -> GenericVariableHandle? in
                guard v.variable.variable == .vertical_velocity else {
                    return nil
                }
                let level = v.variable.level
                logger.info("Calculating vertical velocity on level \(level)")
                guard let t = await storage.get(v.with(variable: .init(variable: .temperature, level: level))) else {
                    fatalError("Requires temperature_2m")
                }
                let data = Meteorology.verticalVelocityPressureToGeometric(omega: data.data, temperature: t.data, pressureLevel: Float(level))
                return try writer.write(time: v.timestamp, member: 0, variable: v.variable, data: data)
            }.compactMap({ $0 })

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
                case ...250:
                    for i in cloudcover_high.indices {
                        if cloudcover_high[i].isNaN || cloudcover_high[i] < clouds[i] {
                            cloudcover_high[i] = clouds[i]
                        }
                    }
                case ...700:
                    for i in cloudcover_mid.indices {
                        if cloudcover_mid[i].isNaN || cloudcover_mid[i] < clouds[i] {
                            cloudcover_mid[i] = clouds[i]
                        }
                    }
                default:
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
            let handlesClouds = [
                try writer.write(time: timestamp, member: 0, variable: GfsGraphCastSurfaceVariable.cloud_cover_low, data: cloudcover_low),
                try writer.write(time: timestamp, member: 0, variable: GfsGraphCastSurfaceVariable.cloud_cover_mid, data: cloudcover_mid),
                try writer.write(time: timestamp, member: 0, variable: GfsGraphCastSurfaceVariable.cloud_cover_high, data: cloudcover_high),
                try writer.write(time: timestamp, member: 0, variable: GfsGraphCastSurfaceVariable.cloud_cover, data: cloudcover)
            ]
            if let uploadS3Bucket {
                try domain.domainRegistry.syncToS3Spatial(bucket: uploadS3Bucket, timesteps: [timestamp])
            }
            return handles + handles2 + handles3 + handlesClouds
        }
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles
    }
}
