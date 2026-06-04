@preconcurrency import OmFileFormat
import Vapor
import SwiftNetCDF
import Foundation
import Logging


/// Downloaders return FileHandles to keep files open while downloading
/// If another download starts and would overlap, this still keeps the old file open
struct GenericVariableHandle: Sendable {
    let variable: any GenericVariable
    let time: TimerangeDt
    let member: Int
    let reader: OmFileReaderArray<MmapFile, Float>
    let domain: GenericDomain

    public init(variable: any GenericVariable, time: Timestamp, member: Int, fn: FileHandle, domain: GenericDomain) async throws {
        self.reader = try await OmFileReader(fn: try MmapFile(fn: fn)).expectArray(of: Float.self)
        let dimensions = reader.getDimensions()
        let nt = dimensions.count == 3 ? Int(dimensions[2]) : 1
        guard dimensions[0] == domain.grid.ny && dimensions[1] == domain.grid.nx else {
            fatalError("Dimensions do not match \(dimensions). Ny \(domain.grid.ny), Nx \(domain.grid.nx)")
        }
        self.time = TimerangeDt(start: time, nTime: nt, dtSeconds: domain.dtSeconds)
        self.variable = variable
        self.member = member
        self.domain = domain
    }
    
    public init(variable: any GenericVariable, time: TimerangeDt, member: Int, reader: OmFileReaderArray<MmapFile, Float>, domain: GenericDomain) {
        self.variable = variable
        self.time = time
        self.member = member
        self.reader = reader
        self.domain = domain
    }

    /// Process concurrently
    /// Note: domain is now ignored, because GenericVariableHandle can now domain property. Makes it easier for ensemble mean calculation
    /// If `fullRunSkipMeta` do not generate meta.json for each run
    static func convert(application: Application, domain domainIgnored: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], concurrent: Int, writeUpdateJson: Bool, uploadS3Bucket: String?, uploadS3OnlyProbabilities: Bool, compression: OmCompressionType = .pfor_delta2d_int16, generateFullRun: Bool = true, generateTimeSeries: Bool = true, fullRunSkipMeta: Bool = false, ensembleMeanDomain: (any GenericDomain)? = nil) async throws {
        let logger = application.logger
        for (_, handles) in handles.groupedPreservedOrder(by: {"\($0.domain)"}) {
            let domain = handles[0].domain
            
            let generateTimeSeries = generateTimeSeries && domain.generateTimeSeries
            
            if generateTimeSeries {
                let startTime = DispatchTime.now()
                logger.info("Start Convert [Time \(Timestamp.now().iso8601_YYYY_MM_dd_HH_mm)]")
                try await convertConcurrent(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, onlyGeneratePreviousDays: false, concurrent: concurrent, compression: compression, ensembleMeanDomain: ensembleMeanDomain)
                logger.info("Convert completed in \(startTime.timeElapsedPretty()) [Time \(Timestamp.now().iso8601_YYYY_MM_dd_HH_mm)]")
            }
            
            /// Write new model meta data, but only of it contains temperature_2m, precipitation, 10m wind or pressure. Ignores e.g. upper level runs
            if generateTimeSeries, writeUpdateJson, let run, handles.contains(where: { ["temperature_2m", "precipitation", "precipitation_probability", "wind_u_component_10m", "pressure_msl", "river_discharge", "ocean_u_current", "wave_height", "pm10", "methane", "shortwave_radiation"].contains($0.variable.omFileName.file) }) {
                let end = handles.max(by: { $0.time.range.lowerBound < $1.time.range.lowerBound })?.time.range.lowerBound.add(domain.dtSeconds) ?? Timestamp(0)
                
                // let writer = OmFileWriter(dim0: 1, dim1: 1, chunk0: 1, chunk1: 1)
                
                // generate model update timeseries
                // let range = TimerangeDt(start: run, to: end, dtSeconds: domain.dtSeconds)
                let current = Timestamp.now()
                /*let initTimes = try range.flatMap {
                 // TODO timestamps need 64 bit integration
                 return [
                 GenericVariableHandle(
                 variable: ModelTimeVariable.initialisation_time,
                 time: $0,
                 member: 0,
                 fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: [Float($0.timeIntervalSince1970)])
                 ),
                 GenericVariableHandle(
                 variable: ModelTimeVariable.modification_time,
                 time: $0,
                 member: 0,
                 fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: 1, all: [Float(current.timeIntervalSince1970)])
                 )
                 ]
                 }
                 let storePreviousForecast = handles.first(where: {$0.variable.storePreviousForecast}) != nil
                 try convert(logger: logger, domain: domain, createNetcdf: false, run: run, handles: initTimes, storePreviousForecastOverwrite: storePreviousForecast)*/
                try ModelUpdateMetaJson.update(domain: domain, run: run, end: end, now: current)
            }
            
            if generateTimeSeries, let uploadS3Bucket = uploadS3Bucket {
                try await domain.domainRegistry.syncToS3(
                    application: application,
                    bucket: uploadS3Bucket,
                    variables: uploadS3OnlyProbabilities ? [ProbabilityVariable.precipitation_probability] : nil
                )
            }
        }
        
        if OpenMeteo.generatePreviousDay, generateTimeSeries, let run {
            for (_, handles) in handles.groupedPreservedOrder(by: {"\($0.domain)"}) {
                let domain = handles[0].domain
            
                // if run is nil, do not attempt to generate previous days files
                logger.info("Convert previous day database if required [Time \(Timestamp.now().iso8601_YYYY_MM_dd_HH_mm)]")
                let startTimePreviousDays = DispatchTime.now()
                try await convertConcurrent(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, onlyGeneratePreviousDays: true, concurrent: concurrent, compression: compression, ensembleMeanDomain: ensembleMeanDomain)
                logger.info("Previous day convert in \(startTimePreviousDays.timeElapsedPretty()) [Time \(Timestamp.now().iso8601_YYYY_MM_dd_HH_mm)]")
                
                /// Only upload to S3 if not ensemble domain. Ensemble domains set `uploadS3OnlyProbabilities`
                if !uploadS3OnlyProbabilities, let uploadS3Bucket {
                    try await domain.domainRegistry.syncToS3(
                        application: application,
                        bucket: uploadS3Bucket,
                        variables: nil
                    )

                    // Also sync ensemble mean domain if it was generated
                    if let emDomain = ensembleMeanDomain {
                        let nMembers = (handles.max(by: { $0.member < $1.member })?.member ?? 0) + 1
                        if nMembers > 1 {
                            try await emDomain.domainRegistry.syncToS3(
                                application: application,
                                bucket: uploadS3Bucket,
                                variables: nil
                            )
                        }
                    }
                }
            }
        }
        
        for (_, handles) in handles.groupedPreservedOrder(by: {"\($0.domain)"}) {
            let domain = handles[0].domain
            let generateFullRun = generateFullRun && domain.generateFullRun
            if generateFullRun, OpenMeteo.dataRunDirectory != nil, let run, run.hour % 3 == 0 {
                logger.info("Generate full run data [Time \(Timestamp.now().iso8601_YYYY_MM_dd_HH_mm)]")
                let startTimeFullRun = DispatchTime.now()
                try await generateFullRunData(logger: logger, domain: domain, run: run, handles: handles, concurrent: concurrent, compression: compression, skipMeta: fullRunSkipMeta, ensembleMeanDomain: ensembleMeanDomain)
                logger.info("Full run convert in \(startTimeFullRun.timeElapsedPretty()) [Time \(Timestamp.now().iso8601_YYYY_MM_dd_HH_mm)]")
                
                if let uploadS3Bucket {
                    try await domain.domainRegistry.syncToS3PerRun(
                        application: application,
                        bucket: uploadS3Bucket,
                        run: run,
                        skipMeta: fullRunSkipMeta
                    )
                    
                    // Also sync ensemble mean domain if it was generated
                    if let emDomain = ensembleMeanDomain {
                        let nMembers = (handles.max(by: { $0.member < $1.member })?.member ?? 0) + 1
                        if nMembers > 1 {
                            try await emDomain.domainRegistry.syncToS3PerRun(
                                application: application,
                                bucket: uploadS3Bucket,
                                run: run,
                                skipMeta: false
                            )
                        }
                    }
                }
            }
        }
    }
    
    /// State for ensemble mean/spread file writers
    private struct EnsembleMeanFileState {
        let meanWriteFile: OmFileWriter<FileHandle>
        let meanWriter: OmFileWriterArray<Float, FileHandle>
        let meanFn: FileHandle
        let meanFilePath: String
        let spreadWriteFile: OmFileWriter<FileHandle>
        let spreadWriter: OmFileWriterArray<Float, FileHandle>
        let spreadFn: FileHandle
        let spreadFilePath: String
        let spreadVariable: any GenericVariable
    }
    
    /// Generate time-series optimised files for each variable per run. `/data_run/<domain>/<run>/<variable>.om`
    /// If `ensembleMeanDomain` is provided, additionally computes ensemble mean and spread from multi-member handles and writes 3D files to that domain.
    static func generateFullRunData(logger: Logger, domain: GenericDomain, run: Timestamp, handles: [Self], concurrent: Int, compression: OmCompressionType, skipMeta: Bool, ensembleMeanDomain: (any GenericDomain)? = nil) async throws {
        let grid = domain.grid
        let nx = grid.nx
        let ny = grid.ny

        try await handles.filter({FullRunsVariables.includes($0.variable.omFileName.file)}).groupedPreservedOrder(by: \.variable.omFileName.file).foreachConcurrent(nConcurrent: concurrent) { (_, handles) in
            let variable = handles[0].variable
            let nMembers = (handles.max(by: { $0.member < $1.member })?.member ?? 0) + 1
            let nMembersStr = nMembers > 1 ? " (\(nMembers) nMembers)" : ""
            let time: [Timestamp] = handles.flatMap({Array($0.time)}).uniqued().sorted()
            let nTime = time.count
            
            let progress = TransferAmountTracker(logger: logger, totalSize: nx * ny * nTime * nMembers * MemoryLayout<Float>.size, name: "Convert \(variable.rawValue)\(nMembersStr) \(nTime) timesteps")
            
            // Setup: Regular file is always created
            let chunknLocations = max(1, min(1024 / nTime / nMembers, nx))
            let chunks = nMembers > 1 ? [1, 1, chunknLocations, nTime] : [1, chunknLocations, nTime]
            let dimensions = nMembers > 1 ? [ny, nx, nMembers, nTime] : [ny, nx, nTime]
            let coordinatesString = nMembers > 1 ? "lat lon member time" : "lat lon time"
            
            let processChunkX = max(1, min(nx, 2 * 1024 * 1024 / nTime / nMembers / chunknLocations * chunknLocations))
            let processChunkY = max(1, min(ny, 2 * 1024 * 1024 / nTime / nMembers / processChunkX))
            
            // Regular file (always created)
            let file = OmFileType.run(domain: domain.domainRegistry, variable: variable.omFileName.file, run: run.toIsoDateTime())
            try file.createDirectory()
            let filePath = file.getFilePath()
            let fn = try FileHandle.createNewFile(file: filePath, overwrite: true, temporary: true)
            
            let writeFile = OmFileWriter(fn: fn, initialCapacity: 4 * 1024)
            let writer = try writeFile.prepareArray(
                type: Float.self,
                dimensions: dimensions.map(UInt64.init),
                chunkDimensions: chunks.map(UInt64.init),
                compression: compression,
                scale_factor: variable.scalefactor,
                add_offset: 0
            )
            
            // Ensemble mean/spread files (additional, only if ensembleMeanDomain is provided)
            let ensembleMeanState: EnsembleMeanFileState? = try { () throws -> EnsembleMeanFileState? in
                guard let emDomain = ensembleMeanDomain else { return nil }
                guard nMembers > 1 else {
                    logger.warning("Cannot compute ensemble mean with only \(nMembers) member(s)")
                    return nil
                }
                
                // Derived ensemble mean domain grid always same as original grid                
                // Mean and spread are 3D (no member dimension)
                let meanChunks = [1, chunknLocations, nTime]
                let meanDimensions = [ny, nx, nTime]
                
                // Mean file - written to ensemble mean domain
                let meanFile = OmFileType.run(domain: emDomain.domainRegistry, variable: variable.omFileName.file, run: run.toIsoDateTime())
                try meanFile.createDirectory()
                let meanFilePath = meanFile.getFilePath()
                let meanFn = try FileHandle.createNewFile(file: meanFilePath, overwrite: true, temporary: true)
                
                let meanWriteFile = OmFileWriter(fn: meanFn, initialCapacity: 4 * 1024)
                let meanWriter = try meanWriteFile.prepareArray(
                    type: Float.self,
                    dimensions: meanDimensions.map(UInt64.init),
                    chunkDimensions: meanChunks.map(UInt64.init),
                    compression: compression,
                    scale_factor: variable.scalefactor,
                    add_offset: 0
                )
                
                // Spread file - written to ensemble mean domain
                let spreadVariable = variable.asSpreadVariableGeneric
                let spreadFile = OmFileType.run(domain: emDomain.domainRegistry, variable: spreadVariable.omFileName.file, run: run.toIsoDateTime())
                try spreadFile.createDirectory()
                let spreadFilePath = spreadFile.getFilePath()
                let spreadFn = try FileHandle.createNewFile(file: spreadFilePath, overwrite: true, temporary: true)
                
                let spreadWriteFile = OmFileWriter(fn: spreadFn, initialCapacity: 4 * 1024)
                let spreadWriter = try spreadWriteFile.prepareArray(
                    type: Float.self,
                    dimensions: meanDimensions.map(UInt64.init),
                    chunkDimensions: meanChunks.map(UInt64.init),
                    compression: compression,
                    scale_factor: spreadVariable.scalefactor,
                    add_offset: 0
                )
                
                return EnsembleMeanFileState(
                    meanWriteFile: meanWriteFile,
                    meanWriter: meanWriter,
                    meanFn: meanFn,
                    meanFilePath: meanFilePath,
                    spreadWriteFile: spreadWriteFile,
                    spreadWriter: spreadWriter,
                    spreadFn: spreadFn,
                    spreadFilePath: spreadFilePath,
                    spreadVariable: spreadVariable
                )
            }()
            
            // Single shared loop: read data once, write to all files
            for yRange in (0..<UInt64(ny)).chunks(ofCount: processChunkY) {
                for xRange in (0..<UInt64(nx)).chunks(ofCount: processChunkX) {
                    let memberRange = 0 ..< UInt64(nMembers)
                    let nLoc = yRange.count * xRange.count
                    
                    // Read data into data3d (shared logic)
                    var data3d = Array3DFastTime(nLocations: nLoc, nLevel: memberRange.count, nTime: nTime)
                    for reader in handles {
                        let dimensions = reader.reader.getDimensions()
                        let timeArrayIndex = time.firstIndex(of: reader.time.range.lowerBound)!
                        if dimensions.count == 3 {
                            /// Number of time steps in this file
                            let nt = dimensions[2]
                            guard nt == reader.time.count else {
                                fatalError("invalid timesteps")
                            }
                            let read = try! await reader.reader.read(range: [yRange, xRange, 0..<nt])
                            data3d[0..<nLoc, reader.member, timeArrayIndex ..< timeArrayIndex + Int(nt)] = read[0..<nLoc * Int(nt)]
                        } else {
                            // Single time step
                            let read = try! await reader.reader.read(range: [yRange, xRange])
                            data3d[0..<nLoc, reader.member, timeArrayIndex] = read[0..<nLoc]
                        }
                    }
                    
                    // Always write regular file
                    let thisChunkDimensions = nMembers <= 1 ?
                        [UInt64(yRange.count), UInt64(xRange.count), UInt64(nTime)] :
                        [UInt64(yRange.count), UInt64(xRange.count), UInt64(nMembers), UInt64(nTime)]
                    
                    try writer.writeData(
                        array: data3d.data,
                        arrayDimensions: thisChunkDimensions
                    )
                    
                    // Additionally, compute and write ensemble mean/spread if ensembleMeanDomain is provided
                    if let state = ensembleMeanState {
                        let meanChunkDimensions: [UInt64] = [UInt64(yRange.count), UInt64(xRange.count), UInt64(nTime)]
                        
                        let (chunkMean, chunkSpread) = welfordMeanSpread(
                            data3d: ArraySlice(data3d.data),
                            nLoc: nLoc,
                            nMembers: nMembers,
                            nMembersActual: nMembers,
                            nTime: nTime
                        )
                        
                        try state.meanWriter.writeData(
                            array: chunkMean,
                            arrayDimensions: meanChunkDimensions
                        )
                        try state.spreadWriter.writeData(
                            array: chunkSpread,
                            arrayDimensions: meanChunkDimensions
                        )
                    }
                    
                    await progress.add(data3d.data.count * MemoryLayout<Float>.size)
                }
            }
            
            // Always finalize regular file
            let arrayFinalised = try writer.finalise()
            try finalizeOmRunFile(
                arrayFinalised: arrayFinalised,
                writeFile: writeFile,
                fn: fn,
                filePath: filePath,
                run: run,
                time: time,
                nTime: nTime,
                unit: variable.unit.abbreviation,
                crsWkt: domain.grid.crsWkt2,
                coordinatesString: coordinatesString
            )
            
            // Additionally finalize ensemble mean/spread files if ensembleMeanDomain was provided
            if let state = ensembleMeanState, let emDomain = ensembleMeanDomain {
                let meanArrayFinalised = try state.meanWriter.finalise()
                try finalizeOmRunFile(
                    arrayFinalised: meanArrayFinalised,
                    writeFile: state.meanWriteFile,
                    fn: state.meanFn,
                    filePath: state.meanFilePath,
                    run: run,
                    time: time,
                    nTime: nTime,
                    unit: variable.unit.abbreviation,
                    crsWkt: emDomain.grid.crsWkt2,
                    coordinatesString: "lat lon time"
                )
                
                let spreadArrayFinalised = try state.spreadWriter.finalise()
                try finalizeOmRunFile(
                    arrayFinalised: spreadArrayFinalised,
                    writeFile: state.spreadWriteFile,
                    fn: state.spreadFn,
                    filePath: state.spreadFilePath,
                    run: run,
                    time: time,
                    nTime: nTime,
                    unit: state.spreadVariable.unit.abbreviation,
                    crsWkt: emDomain.grid.crsWkt2,
                    coordinatesString: "lat lon time"
                )
            }
            
            await progress.finish()
        }
        let validTimes = handles.flatMap({$0.time.map({$0})}).uniqued().sorted()
        if !skipMeta {
            try FullRunMetaJson.write(domain: domain, run: run, validTimes: validTimes)
        }
    }
    
    /// Helper to finalize an OmFile with standard metadata
    private static func finalizeOmRunFile(
        arrayFinalised: OmFileWriterArrayFinalised,
        writeFile: OmFileWriter<FileHandle>,
        fn: FileHandle,
        filePath: String,
        run: Timestamp,
        time: [Timestamp],
        nTime: Int,
        unit: String,
        crsWkt: String,
        coordinatesString: String
    ) throws {
        let createdAt = try writeFile.write(value: Timestamp.now().timeIntervalSince1970, name: "created_at", children: [])
        let coordinates = try writeFile.write(value: coordinatesString, name: "coordinates", children: [])
        let runTime: OmOffsetSize? = try writeFile.write(value: run.timeIntervalSince1970, name: "forecast_reference_time", children: [])
        let crs = try writeFile.write(value: crsWkt, name: "crs_wkt", children: [])
        let unitOffset = try writeFile.write(value: unit, name: "unit", children: [])
        let validTimeArray = try writeFile.writeArray(
            data: time.map(\.timeIntervalSince1970),
            dimensions: [UInt64(nTime)],
            chunkDimensions: [UInt64(nTime)],
            compression: .pfor_delta2d,
            scale_factor: 1,
            add_offset: 0
        )
        let validTime = try writeFile.write(array: validTimeArray, name: "time", children: [])
        let root = try writeFile.write(array: arrayFinalised, name: "", children: [crs, unitOffset, runTime, validTime, coordinates, createdAt].compactMap({$0}))
        try writeFile.writeTrailer(rootVariable: root)
        try fn.linkTemporary(file: filePath)
    }

    private static func convertConcurrent(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], onlyGeneratePreviousDays: Bool, concurrent: Int, compression: OmCompressionType, ensembleMeanDomain: (any GenericDomain)?) async throws {
        if concurrent > 1 {
            try await handles
                .filter({ onlyGeneratePreviousDays == false || $0.variable.storePreviousForecast })
                .groupedPreservedOrder(by: { "\($0.variable.omFileName.file)" })
                .foreachConcurrent(nConcurrent: concurrent, body: {
                    try await convertSerial3D(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: $0.values, onlyGeneratePreviousDays: onlyGeneratePreviousDays, compression: compression, ensembleMeanDomain: ensembleMeanDomain)
            })
        } else {
            try await convertSerial3D(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, onlyGeneratePreviousDays: onlyGeneratePreviousDays, compression: compression, ensembleMeanDomain: ensembleMeanDomain)
        }
    }

    /// Process each variable and update time-series optimised files
    private static func convertSerial3D(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], onlyGeneratePreviousDays: Bool, compression: OmCompressionType, ensembleMeanDomain: (any GenericDomain)?) async throws {
        let grid = domain.grid
        let nx = grid.nx
        let ny = grid.ny
        // let nLocations = grid.count
        let dtSeconds = domain.dtSeconds
        
        // Construct mean domain splitter once if needed, reuse for all variables
        let meanDomainSplitter = ensembleMeanDomain.map { OmFileSplitter($0, nMembers: 1) }

        for (_, handles) in handles.groupedPreservedOrder(by: { "\($0.variable.omFileName.file)" }) {
            guard let timeMin = handles.min(by: { $0.time.range.lowerBound < $1.time.range.lowerBound })?.time.range.lowerBound else {
                logger.warning("No data to convert")
                return
            }
            guard let timeMax = handles.max(by: { $0.time.range.upperBound < $1.time.range.upperBound })?.time.range.upperBound else {
                logger.warning("No data to convert")
                return
            }
            guard let maxTimeStepsPerFile = handles.max(by: { $0.time.count < $1.time.count })?.time.count else {
                logger.warning("No data to convert")
                return
            }
            /// `timeMinMax.min.time` has issues with `skip`
            /// Start time (timeMinMax.min) might be before run time in case of MF wave which contains hind-cast data
            /// For weekly and monthly data, always use timeMin instead of run
            let startTime = dtSeconds >= 7*24*3600 ? timeMin : min(run ?? timeMin, timeMin)
            let time = TimerangeDt(range: startTime..<timeMax, dtSeconds: dtSeconds)

            let variable = handles[0].variable
            /// Number of members in the current download. Might be lower than the actual domain member count. E.g. MeteoSwiss sometimes includes fewer members
            let nMembersInVariables = (handles.max(by: { $0.member < $1.member })?.member ?? 0) + 1
            /// nMembers might be set to 1 for variables like precipitation probability. Otherwise use `countEnsembleMember`
            let nMembers = nMembersInVariables == 1 ? 1 : domain.countEnsembleMember
            let nMembersStr = nMembers > 1 ? " (\(nMembers) nMembers)" : ""

            let storePreviousForecast = variable.storePreviousForecast && nMembers <= 1
            if onlyGeneratePreviousDays && !storePreviousForecast {
                // No need to generate previous day forecast
                continue
            }
            /// If only one value is set, this could be the model initialisation or modification time
            /// TODO: check if single value mode is still required
            // let isSingleValueVariable = readers.first?.reader.first?.fn.count == 1

            let om = OmFileSplitter(domain,
                                    // nLocations: isSingleValueVariable ? 1 : nil,
                                    nMembers: nMembers/*,
                                    chunknLocations: nMembers > 1 ? nMembers : nil*/
            )
            // let nLocationsPerChunk = om.nLocationsPerChunk

            // Create netcdf file for debugging
            if createNetcdf && !onlyGeneratePreviousDays {
                logger.info("Generating NetCDF file for \(variable)")
                try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
                let ncFile = try NetCDF.create(path: "\(domain.downloadDirectory)\(variable.omFileName.file).nc", overwriteExisting: true)
                try ncFile.setAttribute("TITLE", "\(domain) \(variable)")
                var ncVariable = try ncFile.createVariable(name: "data", type: Int16.self, dimensions: [
                    try ncFile.createDimension(name: "time", length: time.count),
                    try ncFile.createDimension(name: "member", length: nMembers),
                    try ncFile.createDimension(name: "LAT", length: grid.ny),
                    try ncFile.createDimension(name: "LON", length: grid.nx)
                ])
                // Note: calculating min value and switching to UInt16 improves compression, but requires to scan all data first
                try ncVariable.defineSzip(options: .nearestNeighbor, pixelPerBlock: 16)
                try ncVariable.defineChunking(chunking: .chunked, chunks: [1, 1, grid.ny, grid.nx])
                try ncVariable.setAttribute("scale_factor", 1/variable.scalefactor)
                try ncVariable.setAttribute("add_offset", Float(0))
                try ncVariable.setAttribute("_FillValue", Int16.max)
                for reader in handles {
                    let data = try! await reader.reader.read()
                    let nt = reader.time.count
                    let timeArrayIndex = time.index(of: reader.time.range.lowerBound)!
                    if nt > 1 {
                        let fastSpace = Array2DFastTime(data: data, nLocations: grid.count, nTime: nt).transpose().data
                        try ncVariable.write(
                            fastSpace.map { $0.isFinite ? Int16($0 * variable.scalefactor) : Int16.max },
                            offset: [timeArrayIndex, reader.member, 0, 0],
                            count: [nt, 1, grid.ny, grid.nx]
                        )
                    } else {
                        try ncVariable.write(
                            data.map { $0.isFinite ? Int16($0 * variable.scalefactor) : Int16.max },
                            offset: [timeArrayIndex, reader.member, 0, 0],
                            count: [1, 1, grid.ny, grid.nx]
                        )
                    }
                }
            }

            let progress = TransferAmountTracker(logger: logger, totalSize: nx * ny * time.count * nMembers * MemoryLayout<Float>.size, name: "Convert \(variable.rawValue)\(nMembersStr) \(time.prettyString())")

            let ensembleMeanOutput: EnsembleMeanOutput? = (meanDomainSplitter != nil && nMembers > 1)
                ? EnsembleMeanOutput(
                    splitter: meanDomainSplitter!,
                    meanVariable: variable.omFileName.file,
                    meanScalefactor: variable.scalefactor,
                    spreadVariable: variable.asSpreadVariableGeneric.omFileName.file,
                    spreadScalefactor: variable.asSpreadVariableGeneric.scalefactor,
                    nMembersActual: nMembersInVariables
                )
                : nil

            try await om.updateFromTimeOrientedStreaming3D(variable: variable.omFileName.file, run: run ?? time.range.lowerBound, time: time, scalefactor: variable.scalefactor, compression: compression, onlyGeneratePreviousDays: onlyGeneratePreviousDays, ensembleMean: ensembleMeanOutput) { yRange, xRange, memberRange in
                let nLoc = yRange.count * xRange.count
                var data3d = Array3DFastTime(nLocations: nLoc, nLevel: memberRange.count, nTime: time.count)
                var readTemp = [Float](repeating: .nan, count: nLoc * maxTimeStepsPerFile)
                for reader in handles {
                    let dimensions = reader.reader.getDimensions()
                    let timeArrayIndex = time.index(of: reader.time.range.lowerBound)!
                    guard memberRange.contains(UInt64(reader.member)) else {
                        fatalError("Invalid reader.member \(reader.member) for range \(memberRange)")
                    }
                    if dimensions.count == 3 {
                        /// Number of time steps in this file
                        let nt = dimensions[2]
                        guard nt == reader.time.count else {
                            fatalError("invalid timesteps")
                        }
                        try! await reader.reader.read(into: &readTemp, range: [yRange, xRange, 0..<nt])
                        data3d[0..<nLoc, reader.member, timeArrayIndex ..< timeArrayIndex + Int(nt)] = readTemp[0..<nLoc * Int(nt)]
                    } else {
                        // Single time step
                        try! await reader.reader.read(into: &readTemp, range: [yRange, xRange])
                        data3d[0..<nLoc, reader.member, timeArrayIndex] = readTemp[0..<nLoc]
                    }
                }
                
                let locationRange1D = RegularGridSlice(grid: domain.grid, yRange: Int(yRange.lowerBound) ..< Int(yRange.upperBound), xRange: Int(xRange.lowerBound) ..< Int(xRange.upperBound))

                // Interpolate all missing values
                data3d.interpolateInplace(
                    type: variable.interpolation,
                    time: time,
                    grid: domain.grid,
                    locationRange: locationRange1D
                )

                await progress.add(nLoc * memberRange.count * time.count * MemoryLayout<Float>.size)
                return ArraySlice(data3d.data)
            }
            await progress.finish()
        }
    }
}

actor GenericVariableHandleStorage {
    var handles = [GenericVariableHandle]()

    func append(_ element: GenericVariableHandle) {
        handles.append(element)
    }

    func append(_ element: GenericVariableHandle?) {
        guard let element else {
            return
        }
        handles.append(element)
    }

    func append(contentsOf elements: [GenericVariableHandle]) {
        handles.append(contentsOf: elements)
    }
}


/// Keep values from previous timestep. Actori isolated, because of concurrent data conversion
actor GribDeaverager {
    var data: [Int: (step: Int, data: [Float])]

    /// Set new value and get previous value out
    func set<V: Hashable>(variable: V, member: Int, step: Int, data d: [Float]) -> (step: Int, data: [Float])? {
        var hash = Hasher()
        hash.combine(variable)
        hash.combine(member)
        let key = hash.finalize()
        let previous = data[key]
        data[key] = (step, d)
        return previous
    }
    
    /// Get the last step of variable + member
    func lastStep<V: Hashable>(_ variable: V, _ member: Int) -> Int? {
        var hash = Hasher()
        hash.combine(variable)
        hash.combine(member)
        let key = hash.finalize()
        return data[key]?.step
    }

    /// Make a deep copy
    func copy() -> GribDeaverager {
        return .init(data: data)
    }

    public init(data: [Int: (step: Int, data: [Float])] = .init()) {
        self.data = data
    }
    
    /// Returns false if step should be skipped
    func deaccumulateIfRequired<V: Hashable>(variable: V, member: Int, stepType: String, stepRange: String, array2d: inout Array2D) async -> Bool {
        // Deaccumulate precipitation
        if stepType == "accum" {
            guard let (startStep, currentStep) = stepRange.splitTo2Integer(), startStep != currentStep else {
                return false
            }
            // Store data for next timestep
            let previous = set(variable: variable, member: member, step: currentStep, data: array2d.data)
            // For the overall first timestep or the first step of each repeating section, deaveraging is not required
            if let previous, previous.step != startStep, currentStep > previous.step {
                for l in previous.data.indices {
                    array2d.data[l] -= previous.data[l]
                }
            }
        }

        // Deaverage data
        if stepType == "avg" {
            guard let (startStep, currentStep) = stepRange.splitTo2Integer(), startStep != currentStep else {
                return false
            }
            // Store data for next timestep
            let previous = set(variable: variable, member: member, step: currentStep, data: array2d.data)
            // For the overall first timestep or the first step of each repeating section, deaveraging is not required
            if let previous, previous.step != startStep, currentStep > previous.step {
                let deltaHours = Float(currentStep - startStep)
                let deltaHoursPrevious = Float(previous.step - startStep)
                for l in previous.data.indices {
                    array2d.data[l] = (array2d.data[l] * deltaHours - previous.data[l] * deltaHoursPrevious) / (deltaHours - deltaHoursPrevious)
                }
            }
        }

        return true
    }

    /// Returns false if step should be skipped
    func deaccumulateIfRequired<V: Hashable>(variable: V, member: Int, stepType: String, stepRange: String, grib2d: inout GribArray2D) async -> Bool {
        return await deaccumulateIfRequired(variable: variable, member: member, stepType: stepType, stepRange: stepRange, array2d: &grib2d.array)
    }
}
