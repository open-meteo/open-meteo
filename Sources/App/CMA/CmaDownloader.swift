import Foundation
import SwiftPFor2D
import Vapor
import SwiftEccodes

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
        
        guard let server = signature.server else {
            fatalError("Parameter 'server' is required")
        }

        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        let handles = try await download(application: context.application, domain: domain, run: run, server: server)
        try GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: 1, handles: handles)
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    func getCmaVariable(logger: Logger, message: GribMessage) -> CmaVariableDownloadable? {
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
            case "Vertical velocity":
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
    
    func download(application: Application, domain: CmaDomain, run: Timestamp, server: String) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double = 10
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours)
        Process.alarm(seconds: Int(deadLineHours + 1) * 3600)
        defer {
            curl.printStatistics()
            Process.alarm(seconds: 0)
        }
        let forecastHours = stride(from: 0, through: 240, by: 3)
        
        
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        var handles = [GenericVariableHandle]()
        
        var previousData = [String: (step: Int, data: [Float])]()
        
        for forecastHour in forecastHours {
            let url = "\(server)t\(run.hh)00/f0_f240_6h/Z_NAFP_C_BABJ_\(run.format_YYYYMMddHH)0000_P_NWPC-GRAPES-GFS-GLB-\(forecastHour.zeroPadded(len: 3))00.grib2"
            let timestamp = run.add(hours: forecastHour)
            
            let grib = try await curl.downloadGrib(url: url, bzip2Decode: false, nConcurrent: 6)
            for message in grib {
                guard let stepRange = message.get(attribute: "stepRange"),
                      let stepType = message.get(attribute: "stepType")
                else {
                    fatalError("could not get step range or type")
                }
                if stepType == "accum" && forecastHour == 0 {
                    continue
                }
                guard let variable = getCmaVariable(logger: logger, message: message) else {
                    continue
                }
                if let variable = variable as? CmaSurfaceVariable {
                    if (variable == .snow_depth || variable == .wind_gusts_10m) && forecastHour == 0 {
                        continue
                    }
                }
                
                //message.dumpAttributes()
                try grib2d.load(message: message)
                grib2d.array.shift180LongitudeAndFlipLatitude()
                
                // Scaling before compression with scalefactor
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                /*if (variable as? CmaSurfaceVariable) == .snow_depth {
                    try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)test.nc")
                    fatalError()
                } else {
                    continue
                }*/
                
                if stepType == "accum" {
                    let splited = stepRange.split(separator: "-")
                    guard splited.count == 2 else {
                        continue
                    }
                    let startStep = Int(splited[0])!
                    let currentStep = Int(splited[1])!
                    let previous = previousData[variable.rawValue]
                    // Store data for averaging in next run
                    previousData[variable.rawValue] = (currentStep, grib2d.array.data)
                    // For the overall first timestep or the first step of each repeating section, deaveraging is not required
                    if let previous, previous.step != startStep {
                        for l in previous.data.indices {
                            grib2d.array.data[l] -= previous.data[l]
                        }
                    }
                }
                
                let file = "\(domain.downloadDirectory)\(variable.omFileName.file)_\(forecastHour).om"
                try FileManager.default.removeItemIfExists(at: file)
                
                logger.info("Compressing and writing data to \(variable.omFileName.file)_\(forecastHour).om")
                let fn = try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                
                handles.append(.init(variable: variable, time: timestamp, member: 0, fn: fn, skipHour0: stepType == "accum"))
            }
        }
        return handles
    }
}
