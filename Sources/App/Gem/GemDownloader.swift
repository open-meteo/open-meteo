import Foundation
import Vapor
import SwiftPFor2D
import SwiftEccodes

/**
Gem regional and global Downloader
 - Regional https://dd.weather.gc.ca/model_gem_regional/10km/grib2/
 - Global https://dd.weather.gc.ca/model_gem_global/15km/grib2/lat_lon/
 
 High perf server
 - Global https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_global/15km/grib2/lat_lon/00/
 - Regional https://hpfx.collab.science.gc.ca/20221121/WXO-DD/model_gem_regional/10km/grib2/00/
 */
struct GemDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String
        
        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "server", help: "Server base URL. Default 'https://hpfx.collab.science.gc.ca/YYYYMMDD/WXO-DD/'. Alternative 'https://dd.weather.gc.ca/'")
        var server: String?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }
    
    var help: String {
        "Download Gem models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try GemDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? 1
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        if signature.onlyVariables != nil && signature.upperLevel {
            fatalError("Parameter 'onlyVariables' and 'upperLevel' must not be used simultaneously")
        }
        
        let onlyVariables: [GemVariableDownloadable]? = signature.onlyVariables.map {
            $0.split(separator: ",").map {
                if let variable = GemPressureVariable(rawValue: String($0)) {
                    return variable
                }
                guard let variable = GemSurfaceVariable(rawValue: String($0)) else {
                    fatalError("Invalid variable '\($0)'")
                }
                return variable
            }
        }
        
        let variablesSurface: [GemVariableDownloadable] = GemSurfaceVariable.allCases
        
        let variablesPressure: [GemVariableDownloadable] = domain.levels.flatMap {
            level in GemPressureVariableType.allCases.compactMap { variable in
                return GemPressureVariable(variable: variable, level: level)
            }
        }
        
        /// For GEM ensemble, only download pressure levels if `--upper-level` is set
        let variablesDefault = domain == .gem_global_ensemble ? (signature.upperLevel ? variablesPressure : variablesSurface) : (variablesSurface+variablesPressure)
        
        let variables = onlyVariables ?? variablesDefault
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
                
        try await downloadElevation(application: context.application, domain: domain, run: run, server: signature.server)
        let handles = try await download(application: context.application, domain: domain, variables: variables, run: run, server: signature.server)
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(
                bucket: uploadS3Bucket,
                variables: signature.uploadS3OnlyProbabilities ? [ProbabilityVariable.precipitation_probability] : variables
            )
        }
    }
    
    // download seamask and height
    func downloadElevation(application: Application, domain: GemDomain, run: Timestamp, server: String?) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()
        
        logger.info("Downloading height and elevation data")
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: 4)
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        
        var height: [Float]
        if domain == .gem_hrdps_continental {
            // HRDPS has no HGT_SFC_0 file
            // Download temperature, pressure and calculate it manually
            try grib2d.load(message: try await curl.downloadGrib(url: domain.getUrl(run: run, hour: 0, gribName: "TMP_AGL-2m", server: server), bzip2Decode: false)[0])
            grib2d.array.data.multiplyAdd(multiply: 1, add: -273.15)
            let temperature_2m = grib2d.array.data
            try grib2d.load(message: try await curl.downloadGrib(url: domain.getUrl(run: run, hour: 0, gribName: "PRES_Sfc", server: server), bzip2Decode: false)[0])
            grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
            let surfacePressure = grib2d.array.data
            try grib2d.load(message: try await curl.downloadGrib(url: domain.getUrl(run: run, hour: 0, gribName: "PRMSL_MSL", server: server), bzip2Decode: false)[0])
            grib2d.array.data.multiplyAdd(multiply: 1/100, add: 0)
            let sealevelPressure = grib2d.array.data
            height = zip(zip(surfacePressure, sealevelPressure), temperature_2m).map {
                let ((surfacePressure, sealevelPressure), temperature_2m) = $0
                return Meteorology.elevation(sealevelPressure: sealevelPressure, surfacePressure: surfacePressure, temperature_2m: temperature_2m)
            }
        } else {
            let terrainUrl = domain.getUrl(run: run, hour: 0, gribName: "HGT_SFC_0", server: server)
            let message = try await curl.downloadGrib(url: terrainUrl, bzip2Decode: false)[0]
            try grib2d.load(message: message)
            if domain == .gem_global_ensemble {
                // Only ensemble model is shifted by 180° and uses geopotential
                grib2d.array.shift180Longitudee()
                grib2d.array.data.multiplyAdd(multiply: 9.80665, add: 0)
            }
            height = grib2d.array.data
        }
        
        if domain != .gem_global_ensemble {
            let gribName = domain == .gem_hrdps_continental ? "LAND_Sfc" : "LAND_SFC_0"
            let landmaskUrl = domain.getUrl(run: run, hour: 0, gribName: gribName, server: server)
            var landmask: Array2D? = nil
            for message in try await curl.downloadGrib(url: landmaskUrl, bzip2Decode: false) {
                try grib2d.load(message: message)
                landmask = grib2d.array
            }
            if let landmask {
                for i in landmask.data.indices {
                    // landmask: 0=sea, 1=land
                    height[i] = landmask.data[i] >= 0.5 ? height[i] : -999
                }
            }
        }
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: height)
    }
    
    /// Download data and store as compressed files for each timestep
    func download(application: Application, domain: GemDomain, variables: [GemVariableDownloadable], run: Timestamp, server: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours = (domain == .gem_global_ensemble || domain == .gem_global) ? 11 : 5.0
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours) // 12 hours and 6 hours interval so we let 1 hour for data conversion
        let nMembers = domain.ensembleMembers
        
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        var handles = [GenericVariableHandle]()
        
        /// Keep values from previous timestep. Actori isolated, because of concurrent data conversion
        let deaverager = GribDeaverager()
                
        let forecastHours = domain.getForecastHours(run: run)
        var previousHour = 0
        for hour in forecastHours {
            let timestamp = run.add(hours: hour)
            logger.info("Downloading hour \(hour)")
            struct GemSurfaceVariableMember: Hashable {
                let variable: GemSurfaceVariable
                let member: Int
                
                init(_ variable: GemSurfaceVariable, _ member: Int) {
                    self.variable = variable
                    self.member = member
                }
            }
            /// Keep wind vectors in memory to calculate wind speed / direction for ensemble
            var inMemory = [GemSurfaceVariableMember: [Float]]()
            
            for variable in variables {
                guard let gribName = variable.gribName(domain: domain) else {
                    continue
                }
                if hour == 0 && variable.skipHour0 {
                    continue
                }
                if !variable.includedFor(hour: hour, domain: domain) {
                    continue
                }
                let url = domain.getUrl(run: run, hour: hour, gribName: gribName, server: server)
                // snowfall file might be missing. Ignore any issues here
                let isSnowfallWaterEq = domain == .gem_hrdps_continental && (gribName == "WEASN_Sfc" || gribName == "APCP_Sfc")
                let deadLineHours = isSnowfallWaterEq ? 0.01 : nil
                
                /// Store precip to calculate probability later
                let storePrecipitation = VariablePerMemberStorage<GemSurfaceVariable>()
                
                do {
                    for message in try await curl.downloadGrib(url: url, bzip2Decode: false, deadLineHours: deadLineHours) {
                        let member = message.get(attribute: "perturbationNumber").flatMap(Int.init) ?? 0
                        //try message.debugGrid(grid: domain.grid, flipLatidude: false, shift180Longitude: true)
                        //fatalError()
                        try grib2d.load(message: message)
                        if domain == .gem_global_ensemble {
                            // Only ensemble model is shifted by 180°
                            grib2d.array.shift180Longitudee()
                        }
                        
                        // Scaling before compression with scalefactor
                        if let fma = variable.multiplyAdd(dtSeconds: domain.dtSeconds) {
                            grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                        }
                        
                        guard let stepRange = message.get(attribute: "stepRange"),
                              let stepType = message.get(attribute: "stepType") else {
                            fatalError("could not get step range")
                        }
                        // Deaccumulate precipitation
                        guard await deaverager.deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, grib2d: &grib2d) else {
                            continue
                        }
                        
                        // GEM ensemble does not have wind speed and direction directly, calculate from u/v components
                        if domain == .gem_global_ensemble, let variable = variable as? GemSurfaceVariable {
                            // keep wind speed in memory, which actually contains wind U-component
                            if [.wind_speed_10m, .wind_speed_40m, .wind_speed_80m, .wind_speed_120m].contains(variable) {
                                inMemory[.init(variable, member)] = grib2d.array.data
                                continue
                            }
                            // keep precipitation to calculate probabilitties later
                            if [.precipitation].contains(variable) {
                                await storePrecipitation.set(variable: variable, timestamp: timestamp, member: member, data: grib2d.array)
                            }
                            if let windspeedVariable = variable.winddirectionCounterPartVariable {
                                guard let u = inMemory[.init(windspeedVariable, member)] else {
                                    fatalError("Wind speed calculation requires \(windspeedVariable) to download")
                                }
                                let windspeed = zip(u, grib2d.array.data).map(Meteorology.windspeed)
                                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: windspeedVariable.scalefactor, all: windspeed)
                                handles.append(GenericVariableHandle(
                                    variable: windspeedVariable,
                                    time: run.add(hours: hour),
                                    member: member,
                                    fn: fn,
                                    skipHour0: variable.skipHour0
                                ))
                                grib2d.array.data = Meteorology.windirectionFast(u: u, v: grib2d.array.data)
                            }
                        }
                        
                        let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                        handles.append(GenericVariableHandle(
                            variable: variable,
                            time: run.add(hours: hour),
                            member: member,
                            fn: fn,
                            skipHour0: variable.skipHour0
                        ))
                    }
                } catch {
                    if !isSnowfallWaterEq {
                        throw error
                    }
                }
                
                if domain == .gem_global_ensemble && variable as? GemSurfaceVariable == GemSurfaceVariable.precipitation {
                    logger.info("Calculating precipitation probability")
                    if let handle = try await storePrecipitation.calculatePrecipitationProbability(
                        precipitationVariable: .precipitation,
                        domain: domain,
                        timestamp: timestamp,
                        dtHoursOfCurrentStep: hour - previousHour
                    ) {
                        handles.append(handle)
                    }
                }
                previousHour = hour
            }
        }
        await curl.printStatistics()
        return handles
    }
}


