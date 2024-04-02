
import Foundation
import SwiftPFor2D
import Vapor
import SwiftEccodes
import NIOConcurrencyHelpers

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
    }

    var help: String {
        "Download a specified GFS GraphCast model run"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()
        
        let domain = try GfsGraphCastDomain.load(rawValue: signature.domain)
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        let nConcurrent = signature.concurrent ?? 1
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let handles = try await download(application: context.application, domain: domain, run: run, concurrent: nConcurrent)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: 1, handles: handles, concurrent: nConcurrent)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
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
            case "Vertical velocity (geometric)":
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
    
    /// Create elevation and sea mask
    func writeElevation(grib: [GribMessage], domain: GfsGraphCastDomain) async throws {
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        try domain.surfaceElevationFileOm.createDirectory()
        guard let orogGrib = grib.first(where: { message in
            message.get(attribute: "shortName") == "orog"
        }) else {
            fatalError("Could not get orography")
        }
        guard let soilMoistureGrib = grib.first(where: { message in
            message.get(attribute: "shortName") == "q" && message.get(attribute: "typeOfLevel") == "depthBelowLandLayer"
        }) else {
            fatalError("Could not get soil moisture")
        }
        var orog = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        var soilMoisture = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        try orog.load(message: orogGrib)
        try soilMoisture.load(message: soilMoistureGrib)
        orog.array.shift180LongitudeAndFlipLatitude()
        soilMoisture.array.shift180LongitudeAndFlipLatitude()
        
        for i in orog.array.data.indices {
            if soilMoisture.array.data[i].isNaN || soilMoisture.array.data[i] > 1000 {
                // Mark as sea level
                orog.array.data[i] = -999
            }
        }
        //try orog.array.writeNetcdf(filename: surfaceElevationFileOm.replacingOccurrences(of: ".om", with: ".nc"))
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: orog.array.data)
    }
    
    /// Uses concurrent downloads and concurrent data conversion to process data as fast as possible
    /// Each download GRIB file is split into hundrets 16 MB parts and download in parallel using HTTP RANGE.
    /// Individual grib messages are extracted while downloading and processed concurrently
    func download(application: Application, domain: GfsGraphCastDomain, run: Timestamp, concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 10
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        let forecastHours = domain.forecastHours(run: run.hour)
        
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        
        // https://noaa-nws-graphcastgfs-pds.s3.amazonaws.com/graphcastgfs.20240401/00/forecasts_37_levels/graphcastgfs.t00z.pgrb2.0p25.f006
        let server = "https://noaa-nws-graphcastgfs-pds.s3.amazonaws.com/"
        let handles = try await forecastHours.asyncFlatMap { forecastHour -> [GenericVariableHandle] in
            let thhh = forecastHour.zeroPadded(len: 3)
            let url = "\(server)graphcastgfs.\(run.format_YYYYMMdd)/\(run.hh)/forecasts_37_levels/graphcastgfs.t\(run.hh)z.pgrb2.0p25.f\(thhh)"
            let timestamp = run.add(hours: forecastHour)
            let storage = VariablePerMemberStorage<GfsGraphCastPressureVariable>()
            var handles = try await curl.withGribStream(url: url, bzip2Decode: false, nConcurrent: concurrent) { stream in
                return try await stream.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                    guard let variable = getCmaVariable(logger: logger, message: message) else {
                        return nil
                    }
                    guard let stepRange = message.get(attribute: "stepRange"),
                          let stepType = message.get(attribute: "stepType") else {
                        fatalError("could not get step range or type")
                    }
                    
                    let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    //message.dumpAttributes()
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
                    
                    if let variable = variable as? GfsGraphCastPressureVariable, [GfsGraphCastPressureVariableType.temperature, .specific_humdity].contains(variable.variable) {
                        await storage.set(variable: variable, timestamp: timestamp, member: 0, data: grib2d.array)
                        if variable.variable == .specific_humdity {
                            // do not store specific humidity on disk
                            return nil
                        }
                    }
                    
                    logger.info("Compressing and writing data to \(variable.omFileName.file)_\(forecastHour).om")
                    let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: false)
                }.collect().compactMap({$0})
            }
            
            /// Convert specific humidity to relative humidity
            let handles2 = try await storage.data.mapConcurrent(nConcurrent: concurrent) { (v, data) -> GenericVariableHandle? in
                guard v.variable.variable == .specific_humdity else {
                    return nil
                }
                let level = v.variable.level
                logger.info("Calculating relative humidity on level \(level)")
                guard let t = await storage.get(v.with(variable: .init(variable: .temperature, level: level))) else {
                    fatalError("Weather code correction requires temperature_2m")
                }
                
                let data = Meteorology.specificToRelativeHumidity(specificHumidity: data.data, temperature: t.data, pressure: .init(repeating: Float(level), count: t.count))
                
                let rhVariable = GfsGraphCastPressureVariable(variable: .relative_humidity, level: level)
                // Store to calculate cloud cover
                await storage.set(variable: rhVariable, timestamp: timestamp, member: 0, data: Array2D(data: data, nx: t.nx, ny: t.ny))
                
                let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: rhVariable.scalefactor, all: data)
                return GenericVariableHandle(
                    variable: rhVariable,
                    time: v.timestamp,
                    member: v.member,
                    fn: fn,
                    skipHour0: false
                )
            }.compactMap({$0})
            
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
            let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
            let handlesClouds = [
                GenericVariableHandle(
                    variable: GfsGraphCastSurfaceVariable.cloud_cover_low,
                    time: timestamp,
                    member: 0,
                    fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcover_low),
                    skipHour0: false
                ),
                GenericVariableHandle(
                    variable: GfsGraphCastSurfaceVariable.cloud_cover_mid,
                    time: timestamp,
                    member: 0,
                    fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcover_mid),
                    skipHour0: false
                ),
                GenericVariableHandle(
                    variable: GfsGraphCastSurfaceVariable.cloud_cover_high,
                    time: timestamp,
                    member: 0,
                    fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcover_high),
                    skipHour0: false
                ),
                GenericVariableHandle(
                    variable: GfsGraphCastSurfaceVariable.cloud_cover,
                    time: timestamp,
                    member: 0,
                    fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: cloudcover),
                    skipHour0: false
                )
            ]
            return handles + handles2 + handlesClouds
        }
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles
    }
}
