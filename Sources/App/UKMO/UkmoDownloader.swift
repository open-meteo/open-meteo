import Foundation
import Vapor
import SwiftPFor2D
import SwiftNetCDF

/**
 Download UK MetOffice models from AWS rolling archive
 
 TODO:
 - land and sea mask
 - direct radiation to global conversion?
 - additional processing server?
 - deploy on prod server
 */
struct UkmoDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Flag(name: "surface", help: "Download surface variables")
        var surface: Bool
        
        @Flag(name: "pressure", help: "Download pressure level variables")
        var pressure: Bool
        
        @Flag(name: "height", help: "Download height level variables")
        var height: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Option(name: "server", help: "Default 'https://met-office-atmospheric-model-data.s3-eu-west-2.amazonaws.com/'")
        var server: String?
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?
        
        @Flag(name: "skip-missing", help: "Ignore missing files while downloading")
        var skipMissing: Bool
    }

    var help: String {
        "Download UKMO models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try UkmoDomain.load(rawValue: signature.domain)
        let nConcurrent = signature.concurrent ?? System.coreCount
        
        let onlyVariables: [UkmoVariableDownloadable]? = try signature.onlyVariables.map {
            try $0.split(separator: ",").map {
                if let surface = UkmoSurfaceVariable(rawValue: String($0)) {
                    return surface
                }
                if let variable = UkmoPressureVariable(rawValue: String($0)) {
                    return variable
                }
                if let variable = UkmoHeightVariable(rawValue: String($0)) {
                    return variable
                }
                return try UkmoSurfaceVariable.load(rawValue: String($0))
            }
        }
        
        let allSurface = UkmoSurfaceVariable.allCases
        let allPressure = UkmoPressureVariableType.allCases.map { UkmoPressureVariable.init(variable: $0, level: -1) }
        let allHeight = UkmoHeightVariableType.allCases.map { UkmoHeightVariable.init(variable: $0, level: -1) }
        let variables = onlyVariables ?? (signature.surface ? allSurface : []) + (signature.pressure ? allPressure : []) + (signature.height ? allHeight : [])
        
        /// Process a range of runs
        if let timeinterval = signature.timeinterval {
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / domain.runsPerDay) {
                let handles = try await download(application: context.application, domain: domain, variables: variables, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, server: signature.server, skipMissing: signature.skipMissing)
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
            }
            return
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        let handles = try await download(application: context.application, domain: domain, variables: variables, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, server: signature.server, skipMissing: signature.skipMissing)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /**
     Download a specified UKMO run and return file handles for conversion
     */
    func download(application: Application, domain: UkmoDomain, variables: [UkmoVariableDownloadable], run: Timestamp, concurrent: Int, maxForecastHour: Int?, server: String?, skipMissing: Bool) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double
        switch domain {
        case .global_deterministic_10km:
            deadLineHours = 5
        case .uk_deterministic_2km:
            deadLineHours = 1
        }
        Process.alarm(seconds: Int(deadLineHours+0.1) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
                
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, retryError4xx: !skipMissing, waitAfterLastModified: TimeInterval(2*60))
        
        let server = server ?? "https://met-office-atmospheric-model-data.s3-eu-west-2.amazonaws.com/"
        let baseUrl = "\(server)\(domain.modelNameOnS3)/\(run.iso8601_YYYYMMddTHHmm)Z/"
        
        let handles = try await domain.forecastSteps(run: run).asyncFlatMap { timestamp -> [GenericVariableHandle] in
            logger.info("Process timestamp \(timestamp.iso8601_YYYY_MM_dd_HH_mm)")
            let forecastHour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            if let maxForecastHour, forecastHour > maxForecastHour {
                return []
            }
            return try await variables.mapConcurrent(nConcurrent: concurrent) { variable -> [GenericVariableHandle] in
                if variable.skipHour0, timestamp == run {
                    return []
                }
                guard let fileName = variable.getNcFileName(domain: domain, forecastHour: forecastHour) else {
                    return []
                }
                
                let url = "\(baseUrl)\(timestamp.iso8601_YYYYMMddTHHmm)Z-PT\(forecastHour.zeroPadded(len: 4))H\(timestamp.minute.zeroPadded(len: 2))M-\(fileName).nc"
                let memory: ByteBuffer
                do {
                    memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024)
                } catch {
                    if skipMissing {
                        // Ignore download error and continue with next file
                        return []
                    }
                    throw error
                }
                let data = try memory.withUnsafeReadableBytes { memory -> [(level: Float, data: [Float])] in
                    guard let nc = try NetCDF.open(memory: memory) else {
                        fatalError("Could not open netcdf from memory")
                    }
                    let vars = nc.getVariables()
                    guard let ncVar = vars.first else {
                        fatalError("Could not open variable for \(fileName)")
                    }
                    guard let unit = try ncVar.getAttribute("units")?.readString() else {
                        fatalError("Could not get unit from \(ncVar.name)")
                    }
                    logger.info("Processing \(ncVar.name) [\(unit)]")
                    guard let ncFloat = ncVar.asType(Float.self) else {
                        fatalError("Could not open float variable \(ncVar.name)")
                    }
                    /// File contains multiple levels on pressure or height
                    if ncVar.dimensions.count == 3 {
                        /// `height` or `pressure`
                        let levelStr = ncVar.dimensions[0].name
                        guard var levels = try nc.getVariable(name: levelStr)?.asType(Float.self)?.read() else {
                            fatalError("Could not read levels from variable \(levelStr)")
                        }
                        if levelStr == "pressure" {
                            // Pa to hPa
                            levels.multiplyAdd(multiply: 1/100, add: 0)
                        }
                        return try levels.enumerated().compactMap { (i, level) in
                            if level < 10 {
                                // skip pressure levels higher than 10 hPa
                                return nil
                            }
                            var data = try ncFloat.read(offset: [i, 0, 0], count: [1, ncVar.dimensionsFlat[1], ncVar.dimensionsFlat[2]])
                            if let scaling = variable.multiplyAdd {
                                data.multiplyAdd(multiply: scaling.scalefactor, add: scaling.offset)
                            }
                            return (level, data)
                        }
                    }
                    
                    var data = try ncFloat.read()
                    if let scaling = variable.multiplyAdd {
                        data.multiplyAdd(multiply: scaling.scalefactor, add: scaling.offset)
                    }
                    if let variable = variable as? UkmoSurfaceVariable, variable == .cloud_base {
                        for i in data.indices {
                            if data[i].isNaN {
                                data[i] = 0
                            }
                        }
                    }
                    return [(0, data)]
                }
                
                return try data.map { (level, data) -> GenericVariableHandle in
                    let variable = variable.withLevel(level: level)
                    let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: data)
                    return GenericVariableHandle(
                        variable: variable,
                        time: timestamp,
                        member: 0,
                        fn: fn,
                        skipHour0: variable.skipHour0
                    )
                }
            }.flatMap({$0})
        }
        
        await curl.printStatistics()
        return handles
    }
}

extension Attribute {
    /// Try to read attributes value as string. Otherwise return nil
    func readString() throws -> String? {
        guard let char: [CChar] = try read() else {
            return nil
        }
        return String(cString: char + [0], encoding: .utf8)
    }
}
