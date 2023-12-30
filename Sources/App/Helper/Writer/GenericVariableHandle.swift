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
    
    /// Process each variable and update time-series optimised files
    static func convert(logger: Logger, domain: GenericDomain, createNetcdf: Bool, run: Timestamp, nMembers: Int, handles: [Self]) throws {
        let om = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil)
        let nLocationsPerChunk = om.nLocationsPerChunk
        let timeMinMax = handles.minAndMax(by: {$0.time < $1.time})!
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
            
            let readers: [(time: Timestamp, reader: [OmFileReader<MmapFile>])] = try handles.grouped(by: {$0.time}).map { (time, h) in
                return (time, try h.map{try OmFileReader(fn: $0.fn)})
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
                    for (member,r) in reader.reader.enumerated() {
                        let data = try r.readAll()
                        try ncVariable.write(data, offset: [time.index(of: reader.time)!, member, 0, 0], count: [1, 1, grid.ny, grid.nx])
                    }
                }
            }
            
            try om.updateFromTimeOrientedStreaming(variable: variable.omFileName.file, indexTime: time.toIndexTime(), skipFirst: skip, smooth: 0, skipLast: 0, scalefactor: variable.scalefactor) { offset in
                let d0offset = offset / nMembers
                
                let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
                data3d.data.fillWithNaNs()
                for reader in readers {
                    precondition(reader.reader.count == nMembers, "nMember count wrong")
                    for (i, memberReader) in reader.reader.enumerated() {
                        try memberReader.read(into: &readTemp, arrayDim1Range: (0..<locationRange.count), arrayDim1Length: locationRange.count, dim0Slow: 0..<1, dim1: locationRange)
                        data3d[0..<locationRange.count, i, time.index(of: reader.time)!] = readTemp
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
