// See docs/ncep-rrfs/README.md for RRFS products, GRIB inputs and processing details.

import Foundation
import OmFileFormat
import Vapor
@preconcurrency import SwiftEccodes

/// Download RRFS deterministic, subhourly and five-member ensemble forecasts.
struct NcepRrfsDownloader: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain") var domain: String
        @Option(name: "run") var run: String?
        @Option(name: "concurrent", short: "c") var concurrent: Int?
        @Option(name: "timeinterval", short: "t") var timeinterval: String?
        @Option(name: "server", help: "Root RRFS server URL (defaults to NOAA's AWS archive)") var server: String?
        @Option(name: "max-forecast-hour", help: "Limit the forecast horizon") var maxForecastHour: Int?
        @Option(name: "upload-s3-bucket") var uploadS3Bucket: String?
        @Flag(name: "create-netcdf") var createNetcdf: Bool
        @Flag(name: "skip-timeseries") var skipTimeseries: Bool
    }

    var help: String { "Download and process NOAA RRFS forecasts" }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        let domain = try NcepRrfsDomain.load(rawValue: signature.domain)
        let concurrent = signature.concurrent ?? 2
        guard concurrent > 0 else { throw CommandError.unknownInput("--concurrent must be positive") }
        if let maxHour = signature.maxForecastHour, !domain.forecastHours.contains(maxHour) {
            throw CommandError.unknownInput("--max-forecast-hour must be in \(domain.forecastHours)")
        }
        let runs: [Timestamp]
        if let interval = signature.timeinterval {
            runs = Array(try Timestamp.parseRange(yyyymmdd: interval).toRange(dt: 86400).with(dtSeconds: domain.updateIntervalSeconds))
        } else {
            runs = [try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun]
        }
        for run in runs {
            guard run.hour % (domain.updateIntervalSeconds / 3600) == 0 else {
                throw CommandError.unknownInput("This RRFS domain requires a six-hourly cycle")
            }
            let handles = try await download(application: context.application, domain: domain, run: run,
                                             concurrent: concurrent, maxForecastHour: signature.maxForecastHour,
                                             server: signature.server ?? "https://noaa-rrfs-ops-pds.s3.amazonaws.com",
                                             uploadS3Bucket: signature.uploadS3Bucket)
            try await GenericVariableHandle.convert(application: context.application, domain: domain,
                createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: concurrent,
                writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false,
                generateFullRun: domain.generateFullRun, generateTimeSeries: !signature.skipTimeseries)
        }
    }

    func download(application: Application, domain: NcepRrfsDomain, run: Timestamp, concurrent: Int,
                  maxForecastHour: Int?, server: String, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 6)
        Process.alarm(seconds: 7 * 3600)
        defer { Process.alarm(seconds: 0) }
        try await downloadElevation(curl: curl, domain: domain, run: run, server: server)
        let domainElevation: [Float]?
        if domain != .ncep_rrfs_conus_ensemble {
            guard let elevation = try await domain.getStaticFile(type: .elevation, httpClient: curl.client, logger: logger)?.read() else {
                throw NcepRrfsError.missingElevation
            }
            domainElevation = elevation
        } else {
            domainElevation = nil
        }
        let grid = domain.grid
        let trueNorth = domain == .ncep_rrfs_north_america
            ? domain.northAmericaGrid.getTrueNorthDirection() : domain.conusGrid.getTrueNorthDirection()
        let deaverager = GribDeaverager()
        let lastHour = maxForecastHour ?? domain.forecastHours.upperBound
        var handles = [GenericVariableHandle]()
        var validTimes = [Timestamp]()
        for hour in domain.forecastHours.lowerBound...lastHour {
            logger.info("Downloading \(domain.rawValue) run \(run.format_YYYYMMddHH) forecast hour \(hour)")
            let minutes = domain == .ncep_rrfs_conus_15min ? Array(stride(from: hour * 60 - 45, through: hour * 60, by: 15)) : [hour * 60]
            validTimes.append(contentsOf: minutes.map { run.add($0 * 60) })
            let precipitationMembers = domain == .ncep_rrfs_conus_ensemble && hour > 0
                ? VariablePerMemberStorage<NcepRrfsEnsembleSurfaceVariable>() : nil
            let writer = OmSpatialMultistepWriter(domain: domain, run: run, storeOnDisk: true, realm: nil, logger: logger)
            // Create writers in chronological order even when fields finish concurrently.
            for minute in minutes { _ = try await writer.getWriter(time: run.add(minute * 60)) }
            for member in 0..<domain.countEnsembleMember {
                let wind = WindSpeedCalculator<NcepRrfsVariable>(trueNorth: trueNorth)
                let rh = RelativeHumidityCalculator(outVariable: NcepRrfs15MinVariable.relative_humidity_2m)
                for url in domain.gribUrls(run: run, forecastHour: hour, member: member, server: server) {
                    let variables = domain.downloadVariables(forecastHour: hour, pressureFile: url.contains("prslev"))
                    let snow = domain == .ncep_rrfs_conus_ensemble && !url.contains("prslev") && hour > 0
                        ? VariablePerMemberStorage<NcepRrfsSnowInput>() : nil
                    let accumulated = NcepRrfsAccumulatedFields()
                    let messages = try await curl.downloadIndexedGrib(url: [url], variables: variables)
                    try await messages.foreachConcurrent(nConcurrent: concurrent) { input, message in
                        let variable = input.variable
                        let time = run.add(input.minute * 60)
                        guard minutes.contains(input.minute),
                              let date = message.get(attribute: "validityDate"),
                              let validity = message.getLong(attribute: "validityTime"),
                              try Timestamp.from(yyyymmdd: "\(date)\(validity.zeroPadded(len: 4))") == time else {
                            throw NcepRrfsError.invalidTimestamp
                        }
                        var array = try message.to2D(nx: grid.nx, ny: grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
                        variable.convertUnits(data: &array.data)
                        if variable.isCloudHeight, let domainElevation {
                            variable.convertCloudHeightToAboveGround(data: &array.data, elevation: domainElevation)
                        }
                        let timestepWriter = try await writer.getWriter(time: time)
                        if domain == .ncep_rrfs_conus_15min {
                            if variable.rawValue == "temperature_2m" { try await rh.ingest(.temperature(array), member: member, writer: timestepWriter) }
                            if variable.isDewpoint {
                                try await rh.ingest(.dewpoint(array), member: member, writer: timestepWriter)
                                return
                            }
                        }
                        if variable.isFrozenPrecipitationPercent {
                            await snow?.set(variable: .fraction, timestamp: time, member: member, data: array)
                            return
                        }
                        if let components = variable.windComponents {
                            try await wind.ingest(variable.gribInput.parameter == "UGRD" ? .u(array) : .v(array), member: member,
                                                  outSpeed: components.speed, outDirection: components.direction, writer: timestepWriter)
                            return
                        }
                        // Averaged solar inputs cover the last hour and need no deaveraging.
                        if input.interval.type == "accum" || (input.interval.type == "avg" && !variable.isSolarRadiation) {
                            await accumulated.append(input: input, array: array)
                            return
                        }
                        if input.requiresSolarBackwardsConversion {
                            let factor = Zensun.backwardsAveragedToInstantFactor(grid: grid, locationRange: 0..<grid.count,
                                timerange: TimerangeDt(start: time, nTime: 1, dtSeconds: domain.dtSeconds))
                            for i in array.data.indices where factor.data[i] >= 0.05 { array.data[i] /= factor.data[i] }
                        }
                        try await timestepWriter.write(member: member, variable: variable, data: array.data)
                    }
                    // Parallelize across variables, while preserving every variable's time order.
                    let groups = await accumulated.grouped()
                    try await groups.foreachConcurrent(nConcurrent: concurrent) { fields in
                        for (input, raw) in fields.sorted(by: { $0.0.minute < $1.0.minute }) {
                            let variable = input.variable
                            var array = raw
                            guard await deaverager.deaccumulateIfRequired(variable: variable.rawValue, member: member,
                                stepType: input.interval.type, stepRange: "\(input.interval.start)-\(input.minute)", array2d: &array) else { continue }
                            if variable.rawValue == "precipitation" {
                                await snow?.set(variable: .precipitation, timestamp: run.add(input.minute * 60), member: member, data: array)
                                await precipitationMembers?.set(variable: .precipitation, timestamp: run.add(input.minute * 60), member: member, data: array)
                            }
                            try await writer.write(time: run.add(input.minute * 60), member: member, variable: variable, data: array.data)
                        }
                    }
                    if let snow {
                        let timestep = try await writer.getWriter(time: run.add(hours: hour))
                        // The reduced ensemble supplies CPOFP; deterministic products
                        // write native TSNOWP through the accumulation path above.
                        try await snow.calculateSnowfallAmount(precipitation: .precipitation, frozen_precipitation_percent: .fraction,
                            outVariable: NcepRrfsEnsembleSurfaceVariable.snowfall_water_equivalent, writer: timestep)
                    }
                }
            }
            if let precipitationMembers {
                let timestepWriter = try await writer.getWriter(time: run.add(hours: hour))
                try await precipitationMembers.calculatePrecipitationProbability(
                    precipitationVariable: .precipitation, dtHoursOfCurrentStep: domain.dtHours, writer: timestepWriter)
            }
            handles += try await writer.finalise(application: application, completed: hour == lastHour, validTimes: validTimes, uploadS3Bucket: uploadS3Bucket)
        }
        await curl.printStatistics()
        return handles
    }

    private func downloadElevation(curl: Curl, domain: NcepRrfsDomain, run: Timestamp, server: String) async throws {
        guard !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) else { return }
        // The CONUS products share terrain; North America has its own rotated grid.
        let elevationDomain: NcepRrfsDomain = domain == .ncep_rrfs_north_america ? .ncep_rrfs_north_america : .ncep_rrfs_conus
        let url = elevationDomain.gribUrls(run: run, forecastHour: 0, member: 0, server: server)[0]
        let storage = VariablePerMemberStorage<NcepRrfsStaticVariable>()
        for (variable, message) in try await curl.downloadIndexedGrib(url: [url], variables: NcepRrfsStaticVariable.allCases) {
            let array = try message.to2D(nx: domain.grid.nx, ny: domain.grid.ny, shift180LongitudeAndFlipLatitudeIfRequired: false).array
            await storage.set(variable: variable, timestamp: run, member: 0, data: array)
        }
        try await storage.generateElevationFile(elevation: .elevation, landmask: .landmask, domain: domain)
        guard FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) else { throw NcepRrfsError.missingElevation }
    }
}

private enum NcepRrfsStaticVariable: String, CaseIterable, CurlIndexedVariable {
    case elevation, landmask
    var gribIndexName: String? { self == .elevation ? ":HGT:surface:" : ":LAND:surface:" }
    var exactMatch: Bool { false }
}

private actor NcepRrfsAccumulatedFields {
    var fields = [(NcepRrfsDownloadVariable, Array2D)]()
    func append(input: NcepRrfsDownloadVariable, array: Array2D) { fields.append((input, array)) }
    func grouped() -> [[(NcepRrfsDownloadVariable, Array2D)]] { Array(Dictionary(grouping: fields, by: { $0.0.variable.rawValue }).values) }
}

private enum NcepRrfsSnowInput: Hashable, Sendable { case precipitation, fraction }

private enum NcepRrfsError: Error {
    case invalidTimestamp
    case missingElevation
}
