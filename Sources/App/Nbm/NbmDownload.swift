import Foundation
import Vapor
import SwiftPFor2D
import SwiftNetCDF

/**
NCEP NBM downloader
 
 TODO:
 - surface elevation height and land-sea-mask
 
 Note: Depending on the run, different variables are available. See: https://vlab.noaa.gov/web/mdl/nbm-v4.2-weather-elements and  https://vlab.noaa.gov/web/mdl/nbm-data-availability-v4.2
 */
struct NbmDownload: AsyncCommand {
    struct Signature: CommandSignature {
        @Argument(name: "domain")
        var domain: String

        @Option(name: "run")
        var run: String?
        
        @Flag(name: "create-netcdf")
        var createNetcdf: Bool
        
        @Option(name: "only-variables")
        var onlyVariables: String?
        
        @Flag(name: "upper-level", help: "Download upper-level variables on pressure levels")
        var upperLevel: Bool
        
        @Flag(name: "surface-level", help: "Download surface-level variables")
        var surfaceLevel: Bool
        
        @Option(name: "max-forecast-hour", help: "Only download data until this forecast hour")
        var maxForecastHour: Int?
        
        @Option(name: "timeinterval", short: "t", help: "Timeinterval to download past forecasts. Format 20220101-20220131")
        var timeinterval: String?
        
        @Option(name: "concurrent", short: "c", help: "Numer of concurrent download/conversion jobs")
        var concurrent: Int?
        
        @Option(name: "upload-s3-bucket", help: "Upload open-meteo database to an S3 bucket after processing")
        var uploadS3Bucket: String?
        
        @Flag(name: "upload-s3-only-probabilities", help: "Only upload probabilities files to S3")
        var uploadS3OnlyProbabilities: Bool
    }

    var help: String {
        "Download GFS from NOAA NCEP"
    }
    
    func run(using context: CommandContext, signature: Signature) async throws {
        let domain = try NbmDomain.load(rawValue: signature.domain)
        disableIdleSleep()
        
        if let timeinterval = signature.timeinterval {
            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / domain.runsPerDay) {
                try await downloadRun(using: context, signature: signature, run: run, domain: domain)
            }
            return
        }
        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        try await downloadRun(using: context, signature: signature, run: run, domain: domain)
    }
    
    func downloadRun(using context: CommandContext, signature: Signature, run: Timestamp, domain: NbmDomain) async throws {
        let start = DispatchTime.now()
        let logger = context.application.logger
        disableIdleSleep()
        
        if signature.onlyVariables != nil && signature.upperLevel {
            fatalError("Parameter 'onlyVariables' and 'upperLevel' must not be used simultaneously")
        }
                
        let onlyVariables: [any NbmVariableDownloadable]? = try signature.onlyVariables.map {
            try $0.split(separator: ",").map {
                if let variable = NbmPressureVariable(rawValue: String($0)) {
                    return variable
                }
                return try NbmSurfaceVariable.load(rawValue: String($0))
            }
        }
        
        let pressureVariables = domain.levels.reversed().flatMap { level in
            NbmPressureVariableType.allCases.map { variable in
                NbmPressureVariable(variable: variable, level: level)
            }
        }
        let surfaceVariables = NbmSurfaceVariable.allCases
        
        let variables: [any NbmVariableDownloadable] = onlyVariables ?? (signature.upperLevel ? (signature.surfaceLevel ? surfaceVariables+pressureVariables : pressureVariables) : surfaceVariables)
        
        let handles = try await downloadNbm(application: context.application, domain: domain, run: run, variables: variables, maxForecastHour: signature.maxForecastHour)
        
        let nConcurrent = signature.concurrent ?? 1
        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true)
        
        logger.info("Finished in \(start.timeElapsedPretty())")
        if let uploadS3Bucket = signature.uploadS3Bucket {
            try domain.domainRegistry.syncToS3(
                bucket: uploadS3Bucket,
                variables: signature.uploadS3OnlyProbabilities ? [ProbabilityVariable.precipitation_probability] : variables
            )
        }
    }
    
    func downloadNbm(application: Application, domain: NbmDomain, run: Timestamp, variables: [any NbmVariableDownloadable], maxForecastHour: Int?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        
        let deadLineHours: Double = 2
        let waitAfterLastModified: TimeInterval = 120
        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, waitAfterLastModified: waitAfterLastModified)
        Process.alarm(seconds: Int(deadLineHours+2) * 3600)
        defer { Process.alarm(seconds: 0) }
        
        var forecastHours = domain.forecastHours(run: run.hour)
        if let maxForecastHour {
            forecastHours = forecastHours.filter({$0 <= maxForecastHour})
        }
        
        let nMembers = domain.ensembleMembers
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        let writer = OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)

        var grib2d = GribArray2D(nx: domain.grid.nx, ny: domain.grid.ny)
        var handles = [GenericVariableHandle]()
        
        var previousForecastHour = 0
        
        for forecastHour in forecastHours {
            logger.info("Downloading forecastHour \(forecastHour)")
            let timestamp = run.add(hours: forecastHour)
            
            let url = domain.getGribUrl(run: run, forecastHour: forecastHour, member: 0)
            
            let variables: [NbmVariableAndDomain] = variables.map {
                NbmVariableAndDomain(variable: $0, domain: domain, timestep: forecastHour, previousTimestep: previousForecastHour, run: run.hour)
            }
                           
            for (variable, message) in try await curl.downloadIndexedGrib(url: url, variables: variables, errorOnMissing: false) {
                guard let nx = message.get(attribute: "Nx").map(Int.init) ?? nil else {
                    fatalError("Could not get Nx")
                }
                guard let ny = message.get(attribute: "Ny").map(Int.init) ?? nil else {
                    fatalError("Could not get Ny")
                }
                if domain.grid.nx != nx || domain.grid.ny != ny {
                    logger.warning("GRIB dimensions (nx=\(nx), ny=\(ny)) do not match domain grid dimensions (nx=\(domain.grid.nx), ny=\(domain.grid.ny)). Skipping")
                    continue
                }

                try grib2d.load(message: message)
                if domain.isGlobal {
                    grib2d.array.shift180LongitudeAndFlipLatitude()
                }
                
                /// NBM scan lines are alternating https://github.com/ecmwf/cfgrib/issues/276
                if message.getLong(attribute: "alternativeRowScanning") == 1 {
                    grib2d.array.flipEverySecondScanLine()
                }
                //try message.debugGrid(grid: domain.grid, flipLatidude: domain.isGlobal, shift180Longitude: domain.isGlobal)
                
                /// Generate land mask from regular data for GFS Wave013
                //if domain == .gfswave016 && !domain.surfaceElevationFileOm.exists() {
                    //let height = Array2D(data: grib2d.array.data.map { $0.isNaN ? 0 : -999 }, nx: domain.grid.nx, ny: domain.grid.ny)
                    //try height.writeNetcdf(filename: domain.surfaceElevationFileOm.getFilePath().replacingOccurrences(of: ".om", with: ".nc"))
                   // try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: domain.surfaceElevationFileOm.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: height.data)
               // }
                
                // NBM contains instantanous values for solar flux. Convert it to backwards averaged.
                if let variable = variable.variable as? NbmSurfaceVariable, variable == .shortwave_radiation {
                    let factor = Zensun.backwardsAveragedToInstantFactor(grid: domain.grid, locationRange: 0..<domain.grid.count, timerange: TimerangeDt(start: timestamp, nTime: 1, dtSeconds: domain.dtSeconds))
                    for i in grib2d.array.data.indices {
                        if factor.data[i] < 0.05 {
                            continue
                        }
                        grib2d.array.data[i] /= factor.data[i]
                    }
                }
                
                // Scaling before compression with scalefactor
                if let fma = variable.variable.multiplyAdd(domain: domain) {
                    grib2d.array.data.multiplyAdd(multiply: fma.multiply, add: fma.add)
                }
                
                let fn = try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: variable.variable.scalefactor, all: grib2d.array.data)
                handles.append(GenericVariableHandle(
                    variable: variable.variable,
                    time: timestamp,
                    member: 0, fn: fn
                ))
            }
            
            previousForecastHour = forecastHour
        }
        await curl.printStatistics()
        return handles
    }
}

/// Small helper structure to fuse domain and variable for more control in the gribindex selection
struct NbmVariableAndDomain: CurlIndexedVariable {
    let variable: any NbmVariableDownloadable
    let domain: NbmDomain
    let timestep: Int
    let previousTimestep: Int
    let run: Int
    
    var exactMatch: Bool {
        return true
    }
    
    var gribIndexName: String? {
        return variable.gribIndexName(for: domain, timestep: timestep, previousTimestep: previousTimestep, run: run)
    }
}
