import SwiftPFor2D
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
    
    public func makeReader() throws -> OmFileReader<MmapFile> {
        try OmFileReader(fn: fn)
    }
    
    /// Process concurrently
    static func convert(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], concurrent: Int, writeUpdateJson: Bool) async throws {
        let startTime = Date()
        if concurrent > 1 {
            try await handles.groupedPreservedOrder(by: {"\($0.variable)"}).evenlyChunked(in: concurrent).foreachConcurrent(nConcurrent: concurrent, body: {
                try convert(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: $0.flatMap{$0.values})
            })
        } else {
            try convert(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, handles: handles)
        }
        let timeElapsed = Date().timeIntervalSince(startTime).asSecondsPrettyPrint
        logger.info("Conversion completed in \(timeElapsed)")
        
        /// Write new model meta data, but only of it contains temperature_2m, precipitation, 10m wind or pressure. Ignores e.g. upper level runs
        if writeUpdateJson, let run, handles.contains(where: {["temperature_2m", "precipitation", "wind_u_component_10m", "pressure_msl", "river_discharge", "ocean_u_current", "wave_height", "pm10" ].contains($0.variable.omFileName.file)}) {
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
                        fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: [Float($0.timeIntervalSince1970)])
                    ),
                    GenericVariableHandle(
                        variable: ModelTimeVariable.modification_time,
                        time: $0,
                        member: 0,
                        fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: 1, all: [Float(current.timeIntervalSince1970)])
                    )
                ]
            }
            let storePreviousForecast = handles.first(where: {$0.variable.storePreviousForecast}) != nil
            try convert(logger: logger, domain: domain, createNetcdf: false, run: run, handles: initTimes, storePreviousForecastOverwrite: storePreviousForecast)*/
            try ModelUpdateMetaJson.update(domain: domain, run: run, end: end, now: current)
        }
    }
    
    /// Process each variable and update time-series optimised files
    static func convert(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp?, handles: [Self], storePreviousForecastOverwrite: Bool? = nil) throws {
        let grid = domain.grid
        let nLocations = grid.count
        
        for (_, handles) in handles.groupedPreservedOrder(by: {"\($0.variable)"}) {
            guard let timeMinMax = handles.minAndMax(by: {$0.time < $1.time}) else {
                logger.warning("No data to convert")
                return
            }
            /// `timeMinMax.min.time` has issues with `skip`
            /// Start time (timeMinMax.min) might be before run time in case of MF wave which contains hindcast data
            let startTime = min(run ?? timeMinMax.min.time, timeMinMax.min.time)
            let time = TimerangeDt(range: startTime...timeMinMax.max.time, dtSeconds: domain.dtSeconds)
            
            let variable = handles[0].variable
            let nMembers = (handles.max(by: {$0.member < $1.member})?.member ?? 0) + 1
            let nMembersStr = nMembers > 1 ? " (\(nMembers) nMembers)" : ""
            let progress = ProgressTracker(logger: logger, total: nLocations * nMembers, label: "Convert \(variable.rawValue)\(nMembersStr) \(time.prettyString())")
            
            let readers: [(time: Timestamp, reader: [(fn: OmFileReader<MmapFile>, member: Int)])] = try handles.grouped(by: {$0.time}).map { (time, h) in
                return (time, try h.map{(try $0.makeReader(), $0.member)})
            }
            
            /// If only one value is set, this could be the model initialisation or modifcation time
            let isSingleValueVariable = readers.first?.reader.first?.fn.count == 1
            
            let om = OmFileSplitter(domain,
                                    nLocations: isSingleValueVariable ? 1 : nil,
                                    nMembers: nMembers,
                                    chunknLocations: nMembers > 1 ? nMembers : nil
            )
            let nLocationsPerChunk = om.nLocationsPerChunk
            var data3d = Array3DFastTime(nLocations: nLocationsPerChunk, nLevel: nMembers, nTime: time.count)
            var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
            
            // Create netcdf file for debugging
            if createNetcdf {
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
                    for r in reader.reader {
                        let data = try r.fn.readAll()
                        try ncVariable.write(data, offset: [time.index(of: reader.time)!, r.member, 0, 0], count: [1, 1, grid.ny, grid.nx])
                    }
                }
            }
            
            let storePreviousForecast = (storePreviousForecastOverwrite ?? variable.storePreviousForecast) && nMembers <= 1
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, time: time, scalefactor: variable.scalefactor, storePreviousForecast: storePreviousForecast) { offset in
                let d0offset = offset / nMembers
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                let nLoc = locationRange.count
                data3d.data.fillWithNaNs()
                for reader in readers {
                    precondition(reader.reader.count == nMembers, "nMember count wrong")
                    for r in reader.reader {
                        try r.fn.read(into: &readTemp, arrayDim1Range: 0..<nLoc, arrayDim1Length: nLoc, dim0Slow: 0..<1, dim1: locationRange)
                        data3d[0..<nLoc, r.member, time.index(of: reader.time)!] = readTemp[0..<nLoc]
                    }
                }
                
                // Deaverage radiation. Not really correct for 3h data after 81 hours, but interpolation will correct in the next step.
                //if isAveragedOverTime {
                //    data3d.deavergeOverTime()
                //}
                
                // De-accumulate precipitation
                //if isAccumulatedSinceModelStart {
                //    data3d.deaccumulateOverTime()
                //}
                
                // Interpolate all missing values
                data3d.interpolateInplace(
                    type: variable.interpolation,
                    time: time,
                    grid: domain.grid,
                    locationRange: locationRange
                )
                
                progress.add(nLoc * nMembers)
                return data3d.data[0..<nLoc * nMembers * time.count]
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
    func calculateWindSpeed(u: V, v: V, outSpeedVariable: GenericVariable, outDirectionVariable: GenericVariable?, writer: OmFileWriter, trueNorth: [Float]? = nil) throws -> [GenericVariableHandle] {
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
                    fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: outSpeedVariable.scalefactor, all: speed)
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
                        fn: try writer.writeTemporary(compressionType: .p4nzdec256, scalefactor: outDirectionVariable.scalefactor, all: direction)
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
        
        try OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: 20, chunk1: 20).write(file: elevationFile.getFilePath(), compressionType: .p4nzdec256, scalefactor: 1, all: elevation)
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
