import Foundation
import Vapor
import SwiftPFor2D
import SwiftNetCDF

struct UkmoDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool

        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "only-variables")
        var onlyVariables: String?
    }

    var help: String {
        "Download KNMI models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try UkmoDomain.load(rawValue: signature.domain)
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let nConcurrent = signature.concurrent ?? System.coreCount
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        let onlyVariables: [UkmoVariable]? = try signature.onlyVariables.map {
            try $0.split(separator: ",").map {
                if let variable = UkmoPressureVariable(rawValue: String($0)) {
                    return UkmoVariable.pressure(variable)
                }
                return UkmoVariable.surface(try UkmoSurfaceVariable.load(rawValue: String($0)))
            }
        }
        
                
        let handles = try await download(application: context.application, domain: domain, variables: onlyVariables ?? UkmoSurfaceVariable.allCases.map{UkmoVariable.surface($0)}, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour)
        
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent)
        //try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            let variables = handles.map { $0.variable }.uniqued(on: { $0.rawValue })
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    /**
     */
    func download(application: Application, domain: UkmoDomain, variables: [UkmoVariable], run: Timestamp, concurrent: Int, maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours = Double(2)
        Process.alarm(seconds: Int(deadLineHours+0.5) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let grid = domain.grid
        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        
        let variables = UkmoSurfaceVariable.allCases // [UkmoSurfaceVariable.temperature_2m]
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: TimeInterval(2*60))
        
        let baseUrl = "https://met-office-atmospheric-model-data.s3-eu-west-2.amazonaws.com/global-deterministic-10km/\(run.iso8601_YYYYMMddTHHmm)Z/"
        
        let handles = try await domain.forecastSteps(run: run).asyncMap { timestamp -> [GenericVariableHandle] in
            let forecastHour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            if let maxForecastHour, forecastHour > maxForecastHour {
                return []
            }
            return try await variables.asyncMap { variable -> GenericVariableHandle? in
                if variable.skipHour0, timestamp == run {
                    return nil
                }
                guard let fileName = variable.getNcFileName(domain: domain) else {
                    return nil
                }
                
                let url = "\(baseUrl)\(timestamp.iso8601_YYYYMMddTHHmm)Z-PT\(forecastHour.zeroPadded(len: 4))H\(timestamp.minute.zeroPadded(len: 2))M-\(fileName).nc"
                let memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024)
                let data = try memory.withUnsafeReadableBytes { memory in
                    guard let nc = try NetCDF.open(memory: memory) else {
                        fatalError("Could not open netcdf from memory")
                    }
                    let vars = nc.getVariables()
                    guard let ncVar = vars.first else {
                        fatalError("Could not open variable for \(fileName)")
                    }
                    guard let unitC: [CChar] = try ncVar.getAttribute("units")?.read(),
                            let unit = String(cString: unitC + [0], encoding: .utf8) else {
                        fatalError("Could not get unit from \(ncVar.name)")
                    }
                    logger.info("Processing \(ncVar.name) [\(unit)]")
                    guard let ncFloat = ncVar.asType(Float.self) else {
                        fatalError("Could not open float variable \(ncVar.name)")
                    }
                    var data = try ncFloat.read()
                    if let scaling = variable.multiplyAdd {
                        data.multiplyAdd(multiply: scaling.scalefactor, add: scaling.offset)
                    }
                    return data
                }
                
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: data)
                return GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: 0,
                    fn: fn,
                    skipHour0: variable.skipHour0
                )
            }.compactMap({$0})
        }.flatMap({$0})
        
        // loop timestemps
        // loop variables
        // download netcdf in memory and convert
        
        await curl.printStatistics()
        return handles
    }
}
