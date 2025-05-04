import Foundation
import Vapor
import OmFileFormat
import SwiftNetCDF

/**
 Download UK MetOffice models from AWS rolling archive
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

        // @Flag(name: "fix-solar", help: "Fix old solar files")
        // var fixSolar: Bool
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
        let allPressure = UkmoPressureVariableType.allCases.map { UkmoPressureVariable(variable: $0, level: -1) }
        let allHeight = UkmoHeightVariableType.allCases.map { UkmoHeightVariable(variable: $0, level: -1) }
        let variables = onlyVariables ?? (signature.surface ? allSurface : []) + (signature.pressure ? allPressure : []) + (signature.height ? allHeight : [])

        /// Process a range of runs
        if let timeinterval = signature.timeinterval {
            /*if signature.fixSolar {
                // timeinterval devided by chunk time range
                let time = try Timestamp.parseRange(yyyymmdd: timeinterval)
                try self.fixSolarFiles(application: context.application, domain: domain, timerange: time)
                return
            }*/

            for run in try Timestamp.parseRange(yyyymmdd: timeinterval).toRange(dt: 86400).with(dtSeconds: 86400 / domain.runsPerDay) {
                let handles = try await download(application: context.application, domain: domain, variables: variables, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, server: signature.server, skipMissing: signature.skipMissing, uploadS3Bucket: nil)
                try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: false, uploadS3Bucket: nil, uploadS3OnlyProbabilities: false)
            }
            return
        }

        let run = try signature.run.flatMap(Timestamp.fromRunHourOrYYYYMMDD) ?? domain.lastRun
        logger.info("Downloading domain '\(domain.rawValue)' run '\(run.iso8601_YYYY_MM_dd_HH_mm)'")
        try await downloadElevation(application: context.application, domain: domain, run: run, server: signature.server, createNetcdf: signature.createNetcdf)
        let handles = try await download(application: context.application, domain: domain, variables: variables, run: run, concurrent: nConcurrent, maxForecastHour: signature.maxForecastHour, server: signature.server, skipMissing: signature.skipMissing, uploadS3Bucket: signature.uploadS3Bucket)

        try await GenericVariableHandle.convert(logger: logger, domain: domain, createNetcdf: signature.createNetcdf, run: run, handles: handles, concurrent: nConcurrent, writeUpdateJson: true, uploadS3Bucket: signature.uploadS3Bucket, uploadS3OnlyProbabilities: false)
        logger.info("Finished in \(start.timeElapsedPretty())")
    }

    /// read each file in chunks, apply shortwave correction and write again
    /*func fixSolarFiles(application: Application, domain: UkmoDomain, timerange: ClosedRange<Timestamp>) throws {
        let nTimePerFile = domain.omFileLength
        let indexTime = timerange.toRange(dt: domain.dtSeconds).toIndexTime()
        
        for variable in [UkmoSurfaceVariable.shortwave_radiation, .direct_radiation] {
            for timeChunk in indexTime.divideRoundedUp(divisor: nTimePerFile) {
                for previousDay in 1..<10 { // 0..<10}
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
                        let factor = Zensun.backwardsAveragedToInstantFactor(grid: domain.grid, locationRange: locations, timerange: fileTime)
                        for i in data.indices {
                            if factor.data[i] < 0.05 {
                                continue
                            }
                            data[i] /= factor.data[i]
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

    func downloadElevation(application: Application, domain: UkmoDomain, run: Timestamp, server: String?, createNetcdf: Bool) async throws {
        // UKMO Global data has been manually converted from GRIB files
        /*try DownloadEra5Command.processElevationLsmGrib(domain: domain, files: ["/Users/patrick/Downloads/UKMO_static/uk2km_ground_land-cover+model-terrain-height_00.grib2"], createNetCdf: createNetcdf, shift180LongitudeAndFlipLatitude: false)
        fatalError()*/

        let logger = application.logger
        let surfaceElevationFileOm = domain.surfaceElevationFileOm.getFilePath()
        if FileManager.default.fileExists(atPath: surfaceElevationFileOm) {
            return
        }
        try domain.surfaceElevationFileOm.createDirectory()

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient)

        let server = server ?? "https://\(domain.s3Bucket).s3-eu-west-2.amazonaws.com/"
        let timeStr = (domain == .global_ensemble_20km || domain == .uk_ensemble_2km ) ? "\(run.format_directoriesYYYYMMdd)/T\(run.hh)00" : run.iso8601_YYYYMMddTHHmm
        let baseUrl = "\(server)\(domain.modelNameOnS3)/\(timeStr)Z/\(run.iso8601_YYYYMMddTHHmm)Z-PT0000H00M-"

        /// Ensemble model has a height_of_orography.nc and landsea_mask
        if domain == .global_ensemble_20km || domain == .uk_ensemble_2km {
            logger.info("Downloading height and elevation data")
            let orographyFile = "\(baseUrl)height_of_orography.nc"
            let landSeaMaskFile = "\(baseUrl)landsea_mask.nc"
            guard var elevation = try await curl.downloadInMemoryAsync(url: orographyFile, minSize: nil).readUkmoNetCDF().data.first?.data.data else {
                fatalError("Could not download surface elevation")
            }
            guard let landmask = try await curl.downloadInMemoryAsync(url: landSeaMaskFile, minSize: nil).readUkmoNetCDF().data.first?.data.data else {
                fatalError("Could not download landsea_mask")
            }
            for i in elevation.indices {
                if landmask[i] != 1 {
                    elevation[i] = -999 // mask sea grid points
                }
            }
            try elevation.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid, createNetCdf: createNetcdf)
            return
        }

        if domain != .uk_deterministic_2km {
            // only UKV 2km domain has the required information to calculate height and land mask
            return
        }
        logger.info("Downloading height and elevation data")

        let surfacePressureFile = "\(baseUrl)pressure_at_surface.nc"
        let mslPressureFile = "\(baseUrl)pressure_at_mean_sea_level.nc"
        let lsmFile = "\(baseUrl)landsea_mask.nc"
        let temperatureFile = "\(baseUrl)temperature_at_screen_level.nc"

        guard let surfacePressure = try await curl.downloadInMemoryAsync(url: surfacePressureFile, minSize: nil).readUkmoNetCDF().data.first?.data else {
            fatalError("Could not download surface pressure")
        }
        guard let mslPressure = try await curl.downloadInMemoryAsync(url: mslPressureFile, minSize: nil).readUkmoNetCDF().data.first?.data else {
            fatalError("Could not download mean sea level pressure")
        }
        guard var temperature = try await curl.downloadInMemoryAsync(url: temperatureFile, minSize: nil).readUkmoNetCDF().data.first?.data else {
            fatalError("Could not download temperature")
        }
        temperature.data.multiplyAdd(multiply: 1, add: -273.15)

        var elevation = Meteorology.elevation(
            sealevelPressure: mslPressure.data,
            surfacePressure: surfacePressure.data,
            temperature_2m: temperature.data
        )

        guard let lsm = try await curl.downloadInMemoryAsync(url: lsmFile, minSize: nil).readUkmoNetCDF().data.first?.data else {
            fatalError("Could not download land sea mask")
        }
        for i in elevation.indices {
            if lsm.data[i] <= 0 {
                elevation[i] = -999 // mask sea grid points
            }
        }
        try elevation.writeOmFile2D(file: surfaceElevationFileOm, grid: domain.grid, createNetCdf: createNetcdf)
    }

    /**
     Download a specified UKMO run and return file handles for conversion
     */
    func download(application: Application, domain: UkmoDomain, variables: [UkmoVariableDownloadable], run: Timestamp, concurrent: Int, maxForecastHour: Int?, server: String?, skipMissing: Bool, uploadS3Bucket: String?) async throws -> [GenericVariableHandle] {
        let logger = application.logger
        let deadLineHours: Double
        switch domain {
        case .global_deterministic_10km, .global_ensemble_20km:
            deadLineHours = 6
        case .uk_deterministic_2km, .uk_ensemble_2km:
            deadLineHours = 2.5
        }
        Process.alarm(seconds: Int(deadLineHours + 0.1) * 3600)
        defer { Process.alarm(seconds: 0) }

        let writer = OmRunSpatialWriter(domain: domain, run: run, storeOnDisk: domain == .uk_deterministic_2km || domain == .global_deterministic_10km)

        let curl = Curl(logger: logger, client: application.dedicatedHttpClient, deadLineHours: deadLineHours, retryError4xx: !skipMissing)

        let server = server ?? "https://\(domain.s3Bucket).s3-eu-west-2.amazonaws.com/"
        let timeStr = (domain == .global_ensemble_20km || domain == .uk_ensemble_2km) ? "\(run.format_directoriesYYYYMMdd)/T\(run.hh)00" : run.iso8601_YYYYMMddTHHmm
        let baseUrl = "\(server)\(domain.modelNameOnS3)/\(timeStr)Z/"

        var handles = [GenericVariableHandle]()
        for timestamp in domain.forecastSteps(run: run) {
            logger.info("Process timestamp \(timestamp.iso8601_YYYY_MM_dd_HH_mm)")
            let forecastHour = (timestamp.timeIntervalSince1970 - run.timeIntervalSince1970) / 3600
            if let maxForecastHour, forecastHour > maxForecastHour {
                break
            }
            do {
                let handle = try await variables.mapConcurrent(nConcurrent: concurrent) { variable -> [GenericVariableHandle] in
                    if variable.skipHour0, timestamp == run {
                        return []
                    }
                    guard let fileName = variable.getNcFileName(domain: domain, forecastHour: forecastHour, run: run) else {
                        return []
                    }

                    let url = "\(baseUrl)\(timestamp.iso8601_YYYYMMddTHHmm)Z-PT\(forecastHour.zeroPadded(len: 4))H\(timestamp.minute.zeroPadded(len: 2))M-\(fileName).nc"
                    let memory = try await curl.downloadInMemoryAsync(url: url, minSize: 1024)
                    let data = try memory.readUkmoNetCDF()
                    logger.info("Processing \(data.name) [\(data.unit)]")
                    return try data.data.compactMap { level, member, data -> GenericVariableHandle? in
                        var data = data.data
                        if let scaling = variable.multiplyAdd {
                            data.multiplyAdd(multiply: scaling.scalefactor, add: scaling.offset)
                        }
                        if let variable = variable as? UkmoSurfaceVariable {
                            if variable == .cloud_base {
                                for i in data.indices {
                                    if data[i].isNaN {
                                        data[i] = 0
                                    }
                                }
                            }
                            /// UKMO provides solar radiation as instant values. Convert to backwards averaged data.
                            if variable == .direct_radiation || variable == .shortwave_radiation {
                                let factor = Zensun.backwardsAveragedToInstantFactor(grid: domain.grid, locationRange: 0..<domain.grid.count, timerange: TimerangeDt(start: timestamp, nTime: 1, dtSeconds: domain.dtSeconds))
                                for i in data.indices {
                                    if factor.data[i] < 0.05 {
                                        continue
                                    }
                                    data[i] /= factor.data[i]
                                }
                            }
                        }
                        let variable = variable.withLevel(level: level)
                        return try writer.write(time: timestamp, member: member, variable: variable, data: data)
                    }
                }.flatMap({ $0 })
                handles.append(contentsOf: handle)
            } catch UkmoDownloadError.is12HoursShortRun {
                break
            }
            if let uploadS3Bucket {
                try domain.domainRegistry.syncToS3Spatial(bucket: uploadS3Bucket, timesteps: [timestamp])
            }
        }
        await curl.printStatistics()
        return handles
    }
}

enum UkmoDownloadError: Error {
    case is12HoursShortRun
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

fileprivate extension ByteBuffer {
    /**
     Read NetCDF files from UKMO. For muliple levels (pressuse and height files) multiple levels are returned
     */
    func readUkmoNetCDF() throws -> (name: String, unit: String, data: [(level: Float, member: Int, data: Array2D)]) {
        return try withUnsafeReadableBytes { memory in
            guard let nc = try NetCDF.open(memory: memory) else {
                fatalError("Could not open netcdf from memory")
            }
            let vars = nc.getVariables()
            guard let ncVar = vars.first else {
                fatalError("Could not open variable")
            }
            guard let unit = try ncVar.getAttribute("units")?.readString() else {
                fatalError("Could not get unit from \(ncVar.name)")
            }

            if let ncInt32 = ncVar.asType(Int32.self) {
                // landmask uses `Int`
                let data = try ncInt32.read()
                let ny = ncVar.dimensionsFlat[0]
                let nx = ncVar.dimensionsFlat[1]
                return (ncVar.name, unit, [(0, 0, Array2D(data: data.map({ Float($0) }), nx: nx, ny: ny))])
            }

            guard let ncFloat = ncVar.asType(Float.self) else {
                fatalError("Could not open float variable \(ncVar.name)")
            }
            /// 3D ensemble files
            if ncVar.dimensions.count == 3 && ncVar.dimensions[0].name == "realization" {
                return (ncVar.name, unit, try (0..<ncVar.dimensions[0].length).compactMap({ member in
                    let ny = ncVar.dimensionsFlat[1]
                    let nx = ncVar.dimensionsFlat[2]
                    let data = try ncFloat.read(offset: [member, 0, 0], count: [1, ny, nx])
                    return (0, member, Array2D(data: data, nx: nx, ny: ny))
                }))
            }
            /// File contains multiple levels on pressure or height
            if ncVar.dimensions.count == 3 {
                /// `height` or `pressure`
                let levelStr = ncVar.dimensions[0].name
                guard let levels = try nc.getVariable(name: levelStr)?.asType(Float.self)?.read() else {
                    fatalError("Could not read levels from variable \(levelStr)")
                }
                return (ncVar.name, unit, try levels.enumerated().compactMap({ i, level in
                    // Pa to hPa
                    let level = levelStr == "pressure" ? level / 100 : level
                    if level < 10 {
                        // skip pressure levels higher than 10 hPa
                        return nil
                    }
                    let ny = ncVar.dimensionsFlat[1]
                    let nx = ncVar.dimensionsFlat[2]
                    let data = try ncFloat.read(offset: [i, 0, 0], count: [1, ny, nx])
                    return (level, 0, Array2D(data: data, nx: nx, ny: ny))
                }))
            }
            let data = try ncFloat.read()
            let ny = ncVar.dimensionsFlat[0]
            let nx = ncVar.dimensionsFlat[1]
            return (ncVar.name, unit, [(0, 0, Array2D(data: data, nx: nx, ny: ny))])
        }
    }
}
