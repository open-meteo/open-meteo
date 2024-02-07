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
    let fn: FileHandle
    let skipHour0: Bool
    let isAveragedOverTime: Bool
    let isAccumulatedSinceModelStart: Bool
    
    public init(variable: GenericVariable, time: Timestamp, member: Int, fn: FileHandle, skipHour0: Bool, isAveragedOverTime: Bool = false, isAccumulatedSinceModelStart: Bool = false) {
        self.variable = variable
        self.time = time
        self.member = member
        self.fn = fn
        self.skipHour0 = skipHour0
        self.isAveragedOverTime = isAveragedOverTime
        self.isAccumulatedSinceModelStart = isAccumulatedSinceModelStart
    }
    
    /// Process concurrently
    static func convert(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp, nMembers: Int, handles: [Self], concurrent: Int) async throws {
        let startTime = Date()
        if concurrent > 1 {
            try await handles.groupedPreservedOrder(by: {"\($0.variable)"}).evenlyChunked(in: concurrent).foreachConcurrent(nConcurrent: concurrent, body: {
                try convert(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, nMembers: nMembers, handles: $0.flatMap{$0.values})
            })
        } else {
            try convert(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, nMembers: nMembers, handles: handles)
        }
        let timeElapsed = Date().timeIntervalSince(startTime).asSecondsPrettyPrint
        logger.info("Conversion completed in \(timeElapsed)")
    }
    
    /// Process each variable and update time-series optimised files
    static func convert(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp, nMembers: Int, handles: [Self]) throws {
        let om = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        guard let timeMinMax = handles.minAndMax(by: {$0.time < $1.time}) else {
            logger.warning("No data to convert")
            return
        }
        // `timeMinMax.min.time` has issues with `skip`
        let time = TimerangeDt(range: run...timeMinMax.max.time, dtSeconds: domain.dtSeconds)
        logger.info("Convert timerange \(time.prettyString())")
        
        let grid = domain.grid
        let nLocations = grid.count
                
        var data3d = Array3DFastTime(nLocations: nLocationsPerChunk, nLevel: nMembers, nTime: time.count)
        var readTemp = [Float](repeating: .nan, count: nLocationsPerChunk)
        
        for (_, handles) in handles.groupedPreservedOrder(by: {"\($0.variable)"}) {
            let variable = handles[0].variable
            
            let skip = handles[0].skipHour0 ? 1 : 0
            let isAveragedOverTime = handles[0].isAveragedOverTime
            let isAccumulatedSinceModelStart = handles[0].isAccumulatedSinceModelStart
            let progress = ProgressTracker(logger: logger, total: nLocations * nMembers, label: "Convert \(variable.rawValue)")
            
            let readers: [(time: Timestamp, reader: [(fn: OmFileReader<MmapFile>, member: Int)])] = try handles.grouped(by: {$0.time}).map { (time, h) in
                return (time, try h.map{(try OmFileReader(fn: $0.fn), $0.member)})
            }
            
            // Create netcdf file for debugging
            if createNetcdf {
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
            
            let storePreviousForecast = variable.storePreviousForecast && nMembers <= 1
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, time: time, skipFirst: skip,  scalefactor: variable.scalefactor, storePreviousForecast: storePreviousForecast) { offset in
                let d0offset = offset / nMembers
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data3d.data.fillWithNaNs()
                for reader in readers {
                    precondition(reader.reader.count == nMembers, "nMember count wrong")
                    for r in reader.reader {
                        try r.fn.read(into: &readTemp, arrayDim1Range: (0..<locationRange.count), arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                        data3d[0..<locationRange.count, r.member, time.index(of: reader.time)!] = readTemp
                    }
                }
                
                // Deaverage radiation. Not really correct for 3h data after 81 hours, but interpolation will correct in the next step.
                if isAveragedOverTime {
                    data3d.deavergeOverTime()
                }
                
                // De-accumulate precipitation
                if isAccumulatedSinceModelStart {
                    data3d.deaccumulateOverTime()
                }
                
                // Interpolate all missing values
                data3d.interpolateInplace(
                    type: variable.interpolation,
                    skipFirst: skip,
                    time: time,
                    grid: domain.grid,
                    locationRange: locationRange
                )
                
                progress.add(locationRange.count * nMembers)
                return data3d.data[0..<locationRange.count * nMembers * time.count]
            }
            progress.finish()
        }
    }
}


/// Keep values from previous timestep. Actori isolated, because of concurrent data conversion
actor GribDeaverager {
    var data = [String: (step: Int, data: [Float])]()
    
    /// Set new value and get previous value out
    func set(variable: GenericVariable, member: Int, step: Int, data d: [Float]) -> (step: Int, data: [Float])? {
        let key = "\(variable)_member\(member)"
        let previous = data[key]
        data[key] = (step, d)
        return previous
    }
    
    /// Returns false if step should be skipped
    func deaccumulateIfRequired(variable: GenericVariable, member: Int, stepType: String, stepRange: String, grib2d: inout GribArray2D) async -> Bool {
        // Deaccumulate precipitation
        if stepType == "accum" {
            guard let (startStep, currentStep) = stepRange.splitTo2Integer() else {
                return false
            }
            // Store data for next timestep
            let previous = set(variable: variable, member: member, step: currentStep, data: grib2d.array.data)
            // For the overall first timestep or the first step of each repeating section, deaveraging is not required
            if let previous, previous.step != startStep {
                for l in previous.data.indices {
                    grib2d.array.data[l] -= previous.data[l]
                }
            }
        }
        
        // Deaverage data
        if stepType == "avg" {
            guard let (startStep, currentStep) = stepRange.splitTo2Integer() else {
                return false
            }
            // Store data for next timestep
            let previous = set(variable: variable, member: member, step: currentStep, data: grib2d.array.data)
            // For the overall first timestep or the first step of each repeating section, deaveraging is not required
            if let previous, previous.step != startStep {
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
