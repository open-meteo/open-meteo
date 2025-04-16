import Foundation
import OmFileFormat
import Vapor
import SwiftEccodes
import NIOConcurrencyHelpers

/**
 Downloader for CMA domains
 */
struct DownloadCmaCommand: AsyncCommand {
    struct Signature: CommandSignature {
        @Option(name: "run")
        var run: String?

        @Argument(name: "domain")
        var domain: String

        @Option(name: "server", help: "Root server path")
        var server: String?

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?

        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?

        /*@Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?

        @Flag(name: "fix-solar", help: "Fix old solar files")
        var fixSolar: Bool*/
    }

    var help: String {
        "Download a specified CMA model run"
    }

    func run(using context: CommandContext, signature: Signature) async throws {
        disableIdleSleep()

        let domain = try CmaDomain.load(rawValue: signature.domain)
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        let logger = context.application.logger

        logger.info("Downloading domain \(domain) run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")

        /*if let timeinterval = signature.timeinterval {
            if signature.fixSolar {
                // timeinterval devided by chunk time range
                let time = try Timestamp.parseRange(yyyymmdd: timeinterval)
                try self.fixSolarFiles(application: context.application, domain: domain, timerange: time)
                return
            }
            fatalError("Time interval downloads not possible")
        }*/

        guard let server = signature.server else {
            fatalError("Parameter 'server' is required")
        }

        let nConcurrent = signature.concurrent ?? 1
        let handles = try await download(application: context.application, domain: domain, run: run, server: server, concurrent: nConcurrent)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
    }

    /// read each file in chunks, apply shortwave correction and write again
    /*func fixSolarFiles(application: Application, domain: CmaDomain, timerange: ClosedRange<Timestamp>) throws {
        let nTimePerFile = domain.omFileLength
        let indexTime = timerange.toRange(dt: domain.dtSeconds).toIndexTime()
        
        for variable in [CmaSurfaceVariable.shortwave_radiation, .shortwave_radiation_clear_sky] {
            for timeChunk in indexTime.divideRoundedUp(divisor: nTimePerFile) {
                /// Note make sure to set previous days to 0..<10 next time
                for previousDay in 0..<10 {
                    let fileTime = TimerangeDt(start: Timestamp(timeChunk * nTimePerFile * domain.dtSeconds), nTime: nTimePerFile, dtSeconds: domain.dtSeconds)
                    let readFile = OmFileManagerReadable.domainChunk(domain: domain.domainRegistry, variable: variable.omFileName.file, type: .chunk, chunk: timeChunk, ensembleMember: 0, previousDay: previousDay)
                    guard let omRead = try readFile.openRead() else {
                        continue
                    }
                    let fileName = readFile.getFilePath()
                    application.logger.info("Correcting file \(fileName)")
                    let tempFile = fileName + "~"
                    try FileManager.default.removeItemIfExists(at: tempFile)
                    let fn = try FileHandle.createNewFile(file: tempFile)
                    
                    let writer = try OmFileWriterState<FileHandle>(fn: fn, dim0: omRead.dim0, dim1: omRead.dim1, chunk0: omRead.chunk0, chunk1: omRead.chunk1, compression: omRead.compression, scalefactor: omRead.scalefactor, fsync: true)
                    try writer.writeHeader()
                    
                    // loop over data in chunks
                    for locations in (0..<omRead.dim0).chunks(ofCount: omRead.chunk0) {
                        var data = try omRead.read(dim0Slow: locations, dim1: nil)
                        let solfac = Zensun.calculateRadiationBackwardsAveraged(grid: domain.grid, locationRange: locations, timerange: fileTime)
                        for i in data.indices {
                            data[i] = min(data[i], solfac.data[i] * Float(1367.7 * 0.85)) // limit to 85% exrad
                        }
                        try writer.write(ArraySlice(data))
                    }
                    
                    try writer.writeTail()
                    try writer.fn.close()
                    
                    // Overwrite existing file, with newly created
                    try FileManager.default.moveFileOverwrite(from: tempFile, to: fileName)
                }
            }
        }
    }*/

    func getCmaVariable(logger: Logger, message: GribMessage) -> (any CmaVariableDownloadable)? {
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
                return CmaPressureVariable(variable: .temperature, level: level)
            case "u-component of wind":
                return CmaPressureVariable(variable: .wind_u_component, level: level)
            case "v-component of wind":
                return CmaPressureVariable(variable: .wind_v_component, level: level)
            case "Geopotential height":
                return CmaPressureVariable(variable: .geopotential_height, level: level)
            case "Vertical velocity (geometric)":
                return CmaPressureVariable(variable: .vertical_velocity, level: level)
            case "Relative humidity":
                return CmaPressureVariable(variable: .relative_humidity, level: level)
            case "Cloud cover":
                return CmaPressureVariable(variable: .cloud_cover, level: level)
            default:
                return nil
            }
        case "surface":
            switch shortName {
            case "ssrc": return CmaSurfaceVariable.shortwave_radiation_clear_sky
            case "ssr": return CmaSurfaceVariable.shortwave_radiation
            default: break
            }
            switch parameterName {
            case "Temperature": return CmaSurfaceVariable.surface_temperature
            case "Total precipitation": return CmaSurfaceVariable.precipitation
            case "Convective precipitation": return CmaSurfaceVariable.showers
            case "Precipitation type": return CmaSurfaceVariable.precipitation_type
            case "Total snowfall": return CmaSurfaceVariable.snowfall
            case "Snow depth": return CmaSurfaceVariable.snow_depth
            case "Convective available potential energy": return CmaSurfaceVariable.cape
            case "Convective inhibition": return CmaSurfaceVariable.convective_inhibition
            case "Best lifted index (to 500 hPa)": return CmaSurfaceVariable.lifted_index
            case "Visibility": return CmaSurfaceVariable.visibility
            default: break
            }
        case "meanSea":
            switch parameterName {
            case "Pressure reduced to MSL": return CmaSurfaceVariable.pressure_msl
            default: break
            }
        case "entireAtmosphere":
            switch parameterName {
            case "Total cloud cover": return CmaSurfaceVariable.cloud_cover
            case "Low cloud cover": return CmaSurfaceVariable.cloud_cover_low
            case "Medium cloud cover": return CmaSurfaceVariable.cloud_cover_mid
            case "High cloud cover": return CmaSurfaceVariable.cloud_cover_high
            default: break
            }
        case "heightAboveGround":
            switch (parameterName, level) {
            case ("Temperature", 2): return CmaSurfaceVariable.temperature_2m
            case ("v-component of wind", 10): return CmaSurfaceVariable.wind_v_component_10m
            case ("v-component of wind", 30): return CmaSurfaceVariable.wind_v_component_30m
            case ("v-component of wind", 50): return CmaSurfaceVariable.wind_v_component_50m
            case ("v-component of wind", 70): return CmaSurfaceVariable.wind_v_component_70m
            case ("v-component of wind", 100): return CmaSurfaceVariable.wind_v_component_100m
            case ("v-component of wind", 120): return CmaSurfaceVariable.wind_v_component_120m
            case ("v-component of wind", 140): return CmaSurfaceVariable.wind_v_component_140m
            case ("v-component of wind", 160): return CmaSurfaceVariable.wind_v_component_160m
            case ("v-component of wind", 180): return CmaSurfaceVariable.wind_v_component_180m
            case ("v-component of wind", 200): return CmaSurfaceVariable.wind_v_component_200m
            case ("u-component of wind", 10): return CmaSurfaceVariable.wind_u_component_10m
            case ("u-component of wind", 30): return CmaSurfaceVariable.wind_u_component_30m
            case ("u-component of wind", 50): return CmaSurfaceVariable.wind_u_component_50m
            case ("u-component of wind", 70): return CmaSurfaceVariable.wind_u_component_70m
            case ("u-component of wind", 100): return CmaSurfaceVariable.wind_u_component_100m
            case ("u-component of wind", 120): return CmaSurfaceVariable.wind_u_component_120m
            case ("u-component of wind", 140): return CmaSurfaceVariable.wind_u_component_140m
            case ("u-component of wind", 160): return CmaSurfaceVariable.wind_u_component_160m
            case ("u-component of wind", 180): return CmaSurfaceVariable.wind_u_component_180m
            case ("u-component of wind", 200): return CmaSurfaceVariable.wind_u_component_200m
            case ("Relative humidity", 2): return CmaSurfaceVariable.relative_humidity_2m
            case ("Wind speed (gust)", 10): return CmaSurfaceVariable.wind_gusts_10m
            default: break
            }

        case "depthBelowLandLayer":
            guard let depth = Int(scaledValueOfFirstFixedSurface) else {
                return nil
            }
            switch (parameterName, depth) {
            case ("Temperature", 0): return CmaSurfaceVariable.soil_temperature_0_to_10cm
            case ("Temperature", 10): return CmaSurfaceVariable.soil_temperature_10_to_40cm
            case ("Temperature", 40): return CmaSurfaceVariable.soil_temperature_40_to_100cm
            case ("Temperature", 100): return CmaSurfaceVariable.soil_temperature_100_to_200cm
            case ("Specific humidity", 0): return CmaSurfaceVariable.soil_moisture_0_to_10cm
            case ("Specific humidity", 10): return CmaSurfaceVariable.soil_moisture_10_to_40cm
            case ("Specific humidity", 40): return CmaSurfaceVariable.soil_moisture_40_to_100cm
            case ("Specific humidity", 100): return CmaSurfaceVariable.soil_moisture_100_to_200cm
            default: break
            }
        default: break
        }

        logger.debug("Unmapped GRIB message \(shortName) \(stepRange) \(stepType) \(typeOfLevel) \(level) \(parameterName) \(parameterUnits) \(cfName) \(scaledValueOfFirstFixedSurface) \(scaledValueOfSecondFixedSurface) \(paramId)")
        return nil
    }

    /// Create elevation and sea mask
    func writeElevation(grib: [GribMessage], domain: CmaDomain) async throws {
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
        // try orog.array.writeNetcdf(filename: surfaceElevationFileOm.replacingOccurrences(of: ".om", with: ".nc"))

        try orog.array.data.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid)
    }

    /// Download CMA data.
    /// Uses concurrent downloads and concurrent data conversion to process data as fast as possible
    /// Each download GRIB file is split into hundrets 16 MB parts and download in parallel using HTTP RANGE.
    /// Individual grib messages are extracted while downloading and processed concurrently
    func download(application: Application, domain: CmaDomain, run: Timestamp, server: String, concurrent: Int) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 10
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        let nForecastHours = domain.forecastHours(run: run.hour)
        let forecastHours = stride(from: 0, through: nForecastHours, by: 3)

        let previous = GribDeaverager()

        let handles = try await forecastHours.asyncFlatMap { forecastHour -> [GenericVariableHandle] in
            let timeint = (run.hour % 12 == 6) ? "f0_f120_3h" : "f0_f240_6h"
            let url = "\(server)t\(run.hh)00/\(timeint)/Z_NAFP_C_BABJ_\(run.format_YYYYMMddHH)0000_P_NWPC-GRAPES-GFS-GLB-\(forecastHour.zeroPadded(len: 3))00.grib2"
            let timestamp = run.add(hours: forecastHour)
            // Split download into 16 MB parts and download concurrently
            // In case processing is too slow, incoming data will be buffered
            return try await curl.withGribStream(url: url, bzip2Decode: false, nConcurrent: concurrent) { stream in
                // Process each grib message concurrently. Independent from download thread
                return try await stream.mapStream(nConcurrent: concurrent) { message -> GenericVariableHandle? in
                    /*
                     if !FileManager.default.fileExists(atPath: domain.surfaceElevationFileOm.getFilePath()) {
                         try await writeElevation(grib: grib, domain: domain)
                     }
                     */
                    guard let stepRange = message.get(attribute: "stepRange"),
                          let stepType = message.get(attribute: "stepType")
                    else {
                        fatalError("could not get step range or type")
                    }
                    if stepType == "accum" && forecastHour == 0 {
                        return nil
                    }
                    guard let variable = getCmaVariable(logger: logger, message: message) else {
                        return nil
                    }
                    if let variable = variable as? CmaSurfaceVariable {
                        if (variable == .snow_depth || variable == .wind_gusts_10m) && forecastHour == 0 {
                            return nil
                        }
                    }

                    let writer = OmFileSplitter.makeSpatialWriter(domain: domain)
                    var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
                    // message.dumpAttributes()
                    try grib2d.load(message: message)
                    grib2d.array.shift180LongitudeAndFlipLatitude()

                    // Scaling before compression with scalefactor
                    if let fma = variable.multiplyAdd {
                        grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                    }

                    // Deaccumulate precipitation
                    guard await previous.deaccumulateIfRequired(variable: variable, member: 0, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                        return nil
                    }

                    logger.info("Compressing and writing data to \(variable.omFileName.file)_\(forecastHour).om")
                    let fn = try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: variable.scalefactor, all: grib2d.array.data)
                    return GenericVariableHandle(variable: variable, time: timestamp, member: 0, fn: fn)
                }.collect().compactMap({ $0 })
            }
        }
        await curl.printStatistics()
        Process.alarm(seconds: 0)
        return handles
    }
}
