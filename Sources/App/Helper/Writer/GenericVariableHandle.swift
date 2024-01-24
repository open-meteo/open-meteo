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
    
    /// Process concurrently
    static func convert(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp, nMembers: Int, handles: [Self], concurrent: Int) async throws {
        let startTime = Date()
        try await handles.groupedPreservedOrder(by: {"\($0.variable)"}).evenlyChunked(in: concurrent).foreachConcurrent(nConcurrent: concurrent, body: {
            try convert(logger: logger, domain: domain, createNetcdf: createNetcdf, run: run, nMembers: nMembers, handles: $0.flatMap{$0.values})
        })
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
