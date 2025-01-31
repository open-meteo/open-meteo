import OmFileFormat
import SwiftNetCDF
import Foundation
import Logging

/// Downloaders return FileHandles to keep files open while downloading
/// If another download starts and would overlap, this still keeps the old file open
struct GenericVariableHandle {
    let variable: GenericVariable
    let time: Timestamp
    let member: Int
    private let fn: FileHandle
    
    public init(variable: GenericVariable, time: Timestamp, member: Int, fn: FileHandle) {
        self.variable = variable
        self.time = time
        self.member = member
        self.fn = fn
    }
    
    public func makeReader() throws -> OmFileReaderArray<MmapFile, Float> {
        try OmFileReader(fn: try MmapFile(fn: fn)).asArray(of: Float.self)!
    }
    
    /// Process concurrently
    static func convert(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], concurrent: Int, writeUpdateJson: Bool, uploadS3Bucket: String?, uploadS3OnlyProbabilities: Bool, compression: CompressionType = .pfor_delta2d_int16) async throws {
        
        let startTime = DispatchTime.now()
        try await convertConcurrent(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, onlyGeneratePreviousDays: false, concurrent: concurrent, compression: compression)
        logger.info("Convert completed in \(startTime.timeElapsedPretty())")
        
        /// Write new model meta data, but only of it contains temperature_2m, precipitation, 10m wind or pressure. Ignores e.g. upper level runs
        if writeUpdateJson, let run, handles.contains(where: {["temperature_2m", "precipitation", "precipitation_probability", "wind_u_component_10m", "pressure_msl", "river_discharge", "ocean_u_current", "wave_height", "pm10", "methane", "shortwave_radiation"].contains($0.variable.omFileName.file)}) {
            let end = handles.max(by: {$0.time < $1.time})?.time.add(domain.dtSeconds) ?? Timestamp(0)
            
            //let writer = OmFileWriter(dim0: 1, dim1: 1, chunk0: 1, chunk1: 1)
            
            // generate model update timeseries
            //let range = TimerangeDt(start: run, to: end, dtSeconds: domain.dtSeconds)
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
        
        if let uploadS3Bucket = uploadS3Bucket {
            logger.info("AWS upload to bucket \(uploadS3Bucket)")
            let startTimeAws = DispatchTime.now()
            let variables = handles.map { $0.variable }.uniqued(on: { $0.omFileName.file })
            do {
                try domain.domainRegistry.syncToS3(
                    bucket: uploadS3Bucket,
                    variables: uploadS3OnlyProbabilities ? [ProbabilityVariable.precipitation_probability] : variables
                )
            } catch {
                logger.error("Sync to AWS failed: \(error)")
            }
            logger.info("AWS upload completed in \(startTimeAws.timeElapsedPretty())")
        }

        if let run {
            // if run is nil, do not attempt to generate previous days files
            logger.info("Convert previous day database if required")
            let startTimePreviousDays = DispatchTime.now()
            try await convertConcurrent(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, onlyGeneratePreviousDays: true, concurrent: concurrent, compression: compression)
            logger.info("Previous day convert in \(startTimePreviousDays.timeElapsedPretty())")
        }
    }
    
    static private func convertConcurrent(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], onlyGeneratePreviousDays: Bool, concurrent: Int, compression: CompressionType) async throws {
        if concurrent > 1 {
            try await handles
                .filter({ onlyGeneratePreviousDays == false || $0.variable.storePreviousForecast })
                .groupedPreservedOrder(by: {"\($0.variable.omFileName.file)"})
                .evenlyChunked(in: concurrent)
                .foreachConcurrent(nConcurrent: concurrent, body: {
                    try convertSerial3D(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: $0.flatMap{$0.values}, onlyGeneratePreviousDays: onlyGeneratePreviousDays, compression: compression)
                    
            })
        } else {
            try convertSerial3D(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles, onlyGeneratePreviousDays: onlyGeneratePreviousDays, compression: compression)
        }
    }
    
    /// Process each variable and update time-series optimised files
    static private func convertSerial3D(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], onlyGeneratePreviousDays: Bool, compression: CompressionType) throws {
        let grid = domain.grid
        let nx = grid.nx
        let ny = grid.ny
        let nLocations = grid.count
        let dtSeconds = domain.dtSeconds
        
        for (_, handles) in handles.groupedPreservedOrder(by: {"\($0.variable.omFileName.file)"}) {
            let readers: [(time: TimerangeDt, reader: OmFileReaderArray<MmapFile, Float>, member: Int)] = try handles.grouped(by: {$0.time}).flatMap { (time, h) in
                return try h.map {
                    let reader = try $0.makeReader()
                    let dimensions = reader.getDimensions()
                    let nt = dimensions.count == 3 ? Int(dimensions[2]) : 1
                    guard dimensions[0] == ny && dimensions[1] == nx else {
                        fatalError("Dimensions do not match \(dimensions). Ny \(ny), Nx \(nx)")
                    }
                    let time = TimerangeDt(start: time, nTime: nt, dtSeconds: dtSeconds)
                    return(time, reader, $0.member)
                }
            }
            guard let timeMin = readers.min(by: {$0.time.range.lowerBound < $1.time.range.lowerBound})?.time.range.lowerBound else {
                logger.warning("No data to convert")
                return
            }
            guard let timeMax = readers.max(by: {$0.time.range.upperBound < $1.time.range.upperBound})?.time.range.upperBound else {
                logger.warning("No data to convert")
                return
            }
            guard let maxTimeStepsPerFile = readers.max(by: {$0.time.count < $1.time.count})?.time.count else {
                logger.warning("No data to convert")
                return
            }
            /// `timeMinMax.min.time` has issues with `skip`
            /// Start time (timeMinMax.min) might be before run time in case of MF wave which contains hindcast data
            let startTime = min(run ?? timeMin, timeMin)
            let time = TimerangeDt(range: startTime..<timeMax, dtSeconds: dtSeconds)
            
            let variable = handles[0].variable
            let nMembers = (handles.max(by: {$0.member < $1.member})?.member ?? 0) + 1
            let nMembersStr = nMembers > 1 ? " (\(nMembers) nMembers)" : ""
            
            let storePreviousForecast = variable.storePreviousForecast && nMembers <= 1
            if onlyGeneratePreviousDays && !storePreviousForecast {
                // No need to generate previous day forecast
                continue
            }
            /// If only one value is set, this could be the model initialisation or modifcation time
            /// TODO: check if single value mode is still required
            //let isSingleValueVariable = readers.first?.reader.first?.fn.count == 1
            
            let om = OmFileSplitter(domain,
                                    //nLocations: isSingleValueVariable ? 1 : nil,
                                    nMembers: nMembers/*,
                                    chunknLocations: nMembers > 1 ? nMembers : nil*/
            )
            //let nLocationsPerChunk = om.nLocationsPerChunk
            
            let spatialChunks = OmFileSplitter.calculateSpatialXYChunk(domain: domain, nMembers: nMembers, nTime: 1)
            var data3d = Array3DFastTime(nLocations: spatialChunks.x * spatialChunks.y, nLevel: nMembers, nTime: time.count)
            var readTemp = [Float](repeating: .nan, count: spatialChunks.x * spatialChunks.y * maxTimeStepsPerFile)
            
            // Create netcdf file for debugging
            if createNetcdf && !onlyGeneratePreviousDays {
                logger.info("Generating NetCDF file for \(variable)")
                try FileManager.default.createDirectory(atPath: domain.downloadDirectory, withIntermediateDirectories: true)
                let ncFile = try NetCDF.create(path: "\(domain.downloadDirectory)\(variable.omFileName.file).nc", overwriteExisting: true)
                try ncFile.setAttribute("TITLE", "\(domain) \(variable)")
                var ncVariable = try ncFile.createVariable(name: "data", type: Float.self, dimensions: [
                    try ncFile.createDimension(name: "time", length: time.count),
                    try ncFile.createDimension(name: "member", length: nMembers),
                    try ncFile.createDimension(name: "LAT", length: grid.ny),
                    try ncFile.createDimension(name: "LON", length: grid.nx)
                ])
                for reader in readers {
                    let data = try reader.reader.read()
                    let nt = reader.time.count
                    let timeArrayIndex = time.index(of: reader.time.range.lowerBound)!
                    if nt > 1 {
                        let fastSpace = Array2DFastTime(data: data, nLocations: grid.count, nTime: nt).transpose().data
                        try ncVariable.write(fastSpace, offset: [timeArrayIndex, reader.member, 0, 0], count: [nt, 1, grid.ny, grid.nx])
                    } else {
                        try ncVariable.write(data, offset: [timeArrayIndex, reader.member, 0, 0], count: [1, 1, grid.ny, grid.nx])
                    }
                }
            }
            
            let progress = ProgressTracker(logger: logger, total: nLocations, label: "Convert \(variable.rawValue)\(nMembersStr) \(time.prettyString())")
                        
            try om.updateFromTimeOrientedStreaming3D(variable: variable.omFileName.file, time: time, scalefactor: variable.scalefactor, compression: compression, onlyGeneratePreviousDays: onlyGeneratePreviousDays) { (yRange, xRange, memberRange) in
                let nLoc = yRange.count * xRange.count
                data3d.data.fillWithNaNs()
                for reader in readers {
                    let dimensions = reader.reader.getDimensions()
                    let timeArrayIndex = time.index(of: reader.time.range.lowerBound)!
                    if dimensions.count == 3 {
                        /// Number of time steps in this file
                        let nt = dimensions[2]
                        try reader.reader.read(into: &readTemp, range: [yRange, xRange, 0..<nt])
                        data3d[0..<nLoc, reader.member, timeArrayIndex ..< timeArrayIndex+Int(nt)] = readTemp[0..<nLoc*Int(nt)]
                    } else {
                        // Single time step
                        try reader.reader.read(into: &readTemp, range: [yRange, xRange])
                        data3d[0..<nLoc, reader.member, timeArrayIndex] = readTemp[0..<nLoc]
                    }
                }
                
                // Interpolate all missing values
                data3d.interpolateInplace(
                    type: variable.interpolation,
                    time: time,
                    grid: domain.grid,
                    locationRange: RegularGridSlice(grid: domain.grid, yRange: Int(yRange.lowerBound) ..< Int(yRange.upperBound), xRange: Int(xRange.lowerBound) ..< Int(xRange.upperBound))
                )
                
                progress.add(nLoc)
                return data3d.data[0..<nLoc * memberRange.count * time.count]
            }
            progress.finish()
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

/// Thread safe storage for downloading grib messages. Can be used to post process data.
actor VariablePerMemberStorage<V: Hashable> {
    struct VariableAndMember: Hashable {
        let variable: V
        let timestamp: Timestamp
        let member: Int
        
        func with(variable: V, timestamp: Timestamp? = nil) -> VariableAndMember {
            .init(variable: variable, timestamp: timestamp ?? self.timestamp, member: self.member)
        }
        
        var timestampAndMember: TimestampAndMember {
            return .init(timestamp: timestamp, member: member)
        }
    }
    
    struct TimestampAndMember: Equatable {
        let timestamp: Timestamp
        let member: Int
    }
    
    var data = [VariableAndMember: Array2D]()
    
    init(data: [VariableAndMember : Array2D] = [VariableAndMember: Array2D]()) {
        self.data = data
    }
    
    func set(variable: V, timestamp: Timestamp, member: Int, data: Array2D) {
        self.data[.init(variable: variable, timestamp: timestamp, member: member)] = data
    }
    
    func get(variable: V, timestamp: Timestamp, member: Int) -> Array2D? {
        return data[.init(variable: variable, timestamp: timestamp, member: member)]
    }
    
    func get(_ variable: VariableAndMember) -> Array2D? {
        return data[variable]
    }
}


extension VariablePerMemberStorage {
    /// Calculate wind speed and direction from U/V components for all available members an timesteps.
    /// if `trueNorth` is given, correct wind direction due to rotated grid projections. E.g. DMI HARMONIE AROME using LambertCC
    func calculateWindSpeed(u: V, v: V, outSpeedVariable: GenericVariable, outDirectionVariable: GenericVariable?, writer: OmFileWriterHelper, trueNorth: [Float]? = nil) throws -> [GenericVariableHandle] {
        return try self.data
            .groupedPreservedOrder(by: {$0.key.timestampAndMember})
            .flatMap({ (t, handles) -> [GenericVariableHandle] in
                guard let u = handles.first(where: {$0.key.variable == u}), let v = handles.first(where: {$0.key.variable == v}) else {
                    return []
                }
                let speed = zip(u.value.data, v.value.data).map(Meteorology.windspeed)
                let speedHandle = GenericVariableHandle(
                    variable: outSpeedVariable,
                    time: t.timestamp,
                    member: t.member,
                    fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: outSpeedVariable.scalefactor, all: speed)
                )
                
                if let outDirectionVariable {
                    var direction = Meteorology.windirectionFast(u: u.value.data, v: v.value.data)
                    if let trueNorth {
                        direction = zip(direction, trueNorth).map({($0-$1+360).truncatingRemainder(dividingBy: 360)})
                    }
                    let directionHandle = GenericVariableHandle(
                        variable: outDirectionVariable,
                        time: t.timestamp,
                        member: t.member,
                        fn: try writer.writeTemporary(compressionType: .pfor_delta2d_int16, scalefactor: outDirectionVariable.scalefactor, all: direction)
                    )
                    return [speedHandle, directionHandle]
                }
                return [speedHandle]
            }
        )
    }
    
    /// Generate elevation file
    /// - `elevation`: in metres
    /// - `landMask` 0 = sea, 1 = land. Fractions below 0.5 are considered sea.
    func generateElevationFile(elevation: V, landmask: V, domain: GenericDomain) throws {
        let elevationFile = domain.surfaceElevationFileOm
        if FileManager.default.fileExists(atPath: elevationFile.getFilePath()) {
            return
        }
        guard var elevation = self.data.first(where: {$0.key.variable == elevation})?.value.data,
              let landMask = self.data.first(where: {$0.key.variable == landmask})?.value.data else {
            return
        }
        
        try elevationFile.createDirectory()
        for i in elevation.indices {
            if elevation[i] >= 9000 {
                fatalError("Elevation greater 90000")
            }
            if landMask[i] < 0.5 {
                // mask sea
                elevation[i] = -999
            }
        }
        #if Xcode
        try Array2D(data: elevation, nx: domain.grid.nx, ny: domain.grid.ny).writeNetcdf(filename: domain.surfaceElevationFileOm.getFilePath().replacingOccurrences(of: ".om", with: ".nc"))
        #endif
        
        try elevation.writeOmFile2D(file: elevationFile.getFilePath(), grid: domain.grid, createNetCdf: false)
    }
}


/// Keep values from previous timestep. Actori isolated, because of concurrent data conversion
actor GribDeaverager {
    var data: [String: (step: Int, data: [Float])]
    
    /// Set new value and get previous value out
    func set(variable: GenericVariable, member: Int, step: Int, data d: [Float]) -> (step: Int, data: [Float])? {
        let key = "\(variable)_member\(member)"
        let previous = data[key]
        data[key] = (step, d)
        return previous
    }
    
    /// Make a deep copy
    func copy() -> GribDeaverager {
        return .init(data: data)
    }
    
    public init(data: [String : (step: Int, data: [Float])] = [String: (step: Int, data: [Float])]()) {
        self.data = data
    }
    
    /// Returns false if step should be skipped
    func deaccumulateIfRequired(variable: GenericVariable, member: Int, stepType: String, stepRange: String, grib2d: inout GribArray2D) async -> Bool {
        // Deaccumulate precipitation
        if stepType == "accum" {
            guard let (startStep, currentStep) = stepRange.splitTo2Integer(), startStep != currentStep else {
                return false
            }
            // Store data for next timestep
            let previous = set(variable: variable, member: member, step: currentStep, data: grib2d.array.data)
            // For the overall first timestep or the first step of each repeating section, deaveraging is not required
            if let previous, previous.step != startStep, currentStep > previous.step {
                for l in previous.data.indices {
                    grib2d.array.data[l] -= previous.data[l]
                }
            }
        }
        
        // Deaverage data
        if stepType == "avg" {
            guard let (startStep, currentStep) = stepRange.splitTo2Integer(), startStep != currentStep else {
                return false
            }
            // Store data for next timestep
            let previous = set(variable: variable, member: member, step: currentStep, data: grib2d.array.data)
            // For the overall first timestep or the first step of each repeating section, deaveraging is not required
            if let previous, previous.step != startStep, currentStep > previous.step {
                let deltaHours = Float(currentStep - startStep)
                let deltaHoursPrevious = Float(previous.step - startStep)
                for l in previous.data.indices {
                    grib2d.array.data[l] = (grib2d.array.data[l] * deltaHours - previous.data[l] * deltaHoursPrevious) / (deltaHours - deltaHoursPrevious)
                }
            }
        }
        
        return true
    }
}
