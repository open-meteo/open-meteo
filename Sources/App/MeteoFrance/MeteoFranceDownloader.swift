import Foundation
import Vapor
import SwiftPFor2D


/**
Meteofrance Arome, Arpge downloader
 */
struct MeteoFranceDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?

        @Flag(name: "skip-existing", help: "ONLY FOR TESTING! Do not use in production. May update the database with stale data")
        var skipExisting: Bool
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
    }

    var help: String {
        "Download MeteoFrance models"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        let domain = try MeteoFranceDomain.load(rawValue: signature.domain)
        
        if signature.onlyVariables != nil && signature.upperLevel {
            fatalError("Parameter 'onlyVariables' and 'upperLevel' must not be used simultaneously")
        }
        
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        
        let onlyVariables: [MeteoFranceVariableDownloadable]? = try signature.onlyVariables.map {
            try $0.split(separator: ",").map {
                if let variable = MeteoFrancePressureVariable(rawValue: String($0)) {
                    return variable
                }
                return try MeteoFranceSurfaceVariable.load(rawValue: String($0))
            }
        }
        
        let pressureVariables = domain.levels.reversed().flatMap { level in
            MeteoFrancePressureVariableType.allCases.map { variable -> MeteoFrancePressureVariable in
                return MeteoFrancePressureVariable(variable: variable, level: level)
            }
        }
        let surfaceVariables = MeteoFranceSurfaceVariable.allCases
        
        let variablesAll = onlyVariables ?? (signature.upperLevel ? pressureVariables : surfaceVariables)
        
        let variables = variablesAll.filter({ $0.availableFor(domain: domain, forecastHour: 0) })
        
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        
        try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
        
        try await downloadElevation2(application: context.application, domain: domain, run: run)
        let handles = try await download2(application: context.application, domain: domain, run: run, variables: variables, skipFilesIfExisting: signature.skipExisting)
        try GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, nMembers: 1, handles: handles)
        //try convert(logger: logger, domain: domain, variables: variables, run: run, createNetcdf: signature.createNetcdf)
        logger.info("Finished in \(start.timeElapsedPretty())")
        
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(bucket: uploadS3Bucket, variables: variables)
        }
    }
    
    func downloadElevation2(application: Application, domain: MeteoFranceDomain, run: Timestamp) async throws {
        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()
        guard let apikey = Environment.get("METEOFRANCE_API_KEY") else {
            fatalError("Please specify environment variable 'METEOFRANCE_API_KEY'")
        }
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, headers: [("apikey", apikey)])
        let runTime = "\(run.iso8601_YYYY_MM_dd)T\(run.hour.zeroPadded(len: 2)).00.00Z"
        let subsetGrid = domain.mfSubsetGrid
        let url = "https://public-api.meteofrance.fr/public/\(domain.family.rawValue)/1.0/wcs/\(domain.mfApiName)-WCS/GetCoverage?service=WCS&version=2.0.1&coverageid=GEOMETRIC_HEIGHT__GROUND_OR_WATER_SURFACE___\(runTime)\(subsetGrid)&subset=time(0)&format=application%2Fwmo-grib"
        
        let message = try await curl.downloadGrib(url: url, bzip2Decode: false)[0]
        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        try grib2d.load(message: message)
        if domain.isGlobal {
            grib2d.array.shift180LongitudeAndFlipLatitude()
        } else {
            grib2d.array.flipLatitude()
        }
        try grib2d.array.writeNetcdf(filename: "\(domain.downloadDirectory)elevation.nc")
        //try message.debugGrid(grid: domain.grid, flipLatidude: true, shift180Longitude: true)
        //message.dumpAttributes()
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: surfaceElevationFileOm, compressionType: .p4nzdec256, scalefactor: 1, all: grib2d.array.data)
    }
    
    func download2(application: Application, domain: MeteoFranceDomain, run: Timestamp, variables: [MeteoFranceVariableDownloadable], skipFilesIfExisting: Bool) async throws -> [GenericVariableHandle] {
        
        guard let apikey = Environment.get("METEOFRANCE_API_KEY") else {
            fatalError("Please specify environment variable 'METEOFRANCE_API_KEY'")
        }
        let logger = application.logger
        let deadLineHours: Double = domain == .arpege_europe && run.hour == 12 ? 5.9 : 5
        Process.alarm(seconds: Int(deadLineHours+2) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, headers: [("apikey", apikey)])
        let grid = domain.grid
        var grib2d = GribArray2D(nx: grid.nx, ny: grid.ny)
        let subsetGrid = domain.mfSubsetGrid
        
        let nLocationsPerChunk = OmFileSplitter(domain).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
        var handles = [GenericVariableHandle]()
        
        for hour in domain.forecastHours(run: run.hour, hourlyForArpegeEurope: true) {
            let timestamp = run.add(hours: hour)
            for variable in variables {
                guard variable.availableFor(domain: domain, forecastHour: hour) else {
                    continue
                }
                if hour == 0 && variable.skipHour0(domain: domain) {
                    continue
                }
                let file = "\(domain.downloadDirectory)\(variable.omFileName.file)_\(hour).om"
                
                if skipFilesIfExisting && FileManager.default.fileExists(atPath: file) {
                    handles.append(GenericVariableHandle(
                        variable: variable,
                        time: timestamp,
                        member: 0,
                        fn: try FileHandle.openFileReading(file: file),
                        skipHour0: variable.skipHour0(domain: domain)
                    ))
                    continue
                }
                
                let coverage = variable.getCoverageId()
                let subsetHeight = coverage.height.map { "&subset=height(\($0))" } ?? ""
                let subsetPressure = coverage.pressure.map { "&subset=pressure(\($0))" } ?? ""
                let subsetTime = "&subset=time(\(hour * 3600))"
                let runTime = "\(run.iso8601_YYYY_MM_dd)T\(run.hour.zeroPadded(len: 2)).00.00Z"
                let is3H = domain == .arpege_world && hour >= 51
                let period = coverage.isPeriod ? is3H ? "_PT3H" : "_PT1H" : ""
                
                let url = "https://public-api.meteofrance.fr/public/\(domain.family.rawValue)/1.0/wcs/\(domain.mfApiName)-WCS/GetCoverage?service=WCS&version=2.0.1&coverageid=\(coverage.variable)___\(runTime)\(period)\(subsetGrid)\(subsetHeight)\(subsetPressure)\(subsetTime)&format=application%2Fwmo-grib"
                let message = try await curl.downloadGrib(url: url, bzip2Decode: false)[0]
                
                //try message.debugGrid(grid: grid, flipLatidude: true, shift180Longitude: true)
                //message.dumpAttributes()
                
                try grib2d.load(message: message)
                if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                } else {
                    grib2d.array.flipLatitude()
                }
                if let fma = variable.multiplyAdd {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                
                try FileManager.default.removeItemIfExists(at: file)
                let fn = try writer.write(file: file, compressionType: .p4nzdec256, scalefactor: variable.scalefactor, all: grib2d.array.data)
                handles.append(GenericVariableHandle(
                    variable: variable,
                    time: timestamp,
                    member: 0,
                    fn: fn,
                    skipHour0: variable.skipHour0(domain: domain)
                ))
            }
        }
        await curl.printStatistics()
        return handles
    }
}
