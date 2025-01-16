import Foundation
import OmFileFormat


/// Read any time from multiple files
struct OmFileSplitter {
    let domain: DomainRegistry
    
    let masterTimeRange: Range<Timestamp>?
    
    let hasYearlyFiles: Bool
    
    /// actually also in file
    var nLocations: Int { nx * ny * nMembers }
    
    let ny: Int
    let nx: Int
    
    /// Number of ensemble members or levels
    let nMembers: Int
    
    /// actually also in file
    let nTimePerFile: Int
    
    /// Compression ratio largly depends on chunk size for location. For small timeranges e.g. icon-d2 (121 timesteps per file the nlocation parameter effects the file size:
    /// 1 = 2.09 GB
    /// 2 = 1.15 GB
    /// 6 = 870.7 MB
    /// 12 = 739.4 MB
    /// 24 = 683.7 MB
    /// 33 = 669.2 MB
    /// 48 = 650 MB
    /// 96 = 637.1 MB
    /// Decompress performance is mostly the same, because the chunks are so small, that IO overhead is more dominant than CPU cycles
    let chunknLocations: Int
    
    /// With dynamic nLocation selection based on time, we get chunk locations for each domain. Minimum is set to 6, because spatial correlation does not work well with lower than 6 steps
    /// icon = 12
    /// icon-eu =  16
    /// icon-d2 = 25
    /// ecmwf = 30
    /// NOTE: carefull with reducing nchunkLocaiton, because updates will use the wrong buffer size!!!!
    static func calcChunknLocations(nTimePerFile: Int) -> Int {
        max(6, 3072 / nTimePerFile)
    }
    
    init<Domain: GenericDomain>(_ domain: Domain, nMembers: Int? = nil, chunknLocations: Int? = nil) {
        self.init(
            domain: domain.domainRegistry,
            nMembers: max(nMembers ?? 1, 1),
            nx: domain.grid.nx,
            ny: domain.grid.ny,
            nTimePerFile: domain.omFileLength,
            hasYearlyFiles: domain.hasYearlyFiles,
            masterTimeRange: domain.masterTimeRange,
            chunknLocations: chunknLocations
        )
    }
    
    init(domain: DomainRegistry, nMembers: Int, nx: Int, ny: Int, nTimePerFile: Int, hasYearlyFiles: Bool, masterTimeRange: Range<Timestamp>?, chunknLocations: Int? = nil) {
        self.domain = domain
        self.nMembers = nMembers
        self.nx = nx
        self.ny = ny
        self.nTimePerFile = nTimePerFile
        self.hasYearlyFiles = hasYearlyFiles
        self.masterTimeRange = masterTimeRange
        let nLocations = nx * ny * nMembers
        self.chunknLocations = chunknLocations ?? min(nLocations, Self.calcChunknLocations(nTimePerFile: nTimePerFile))
    }
    
    // optimise to use 8 MB memory, but aligned to even `chunknLocations`
    var nLocationsPerChunk: Int {
        min(nLocations, 8*1024*1024 / MemoryLayout<Float>.stride / nTimePerFile / chunknLocations * chunknLocations)
    }

    /// Prefetch all required data into memory
    func willNeed(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings) throws {
        // TODO: maybe we can keep the file handles better in scope
        let indexTime = time.time.toIndexTime()
        let nTime = indexTime.count
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var start = indexTime.lowerBound
        
        if let masterTimeRange {
            let fileTime = TimerangeDt(range: masterTimeRange, dtSeconds: time.dtSeconds).toIndexTime()
            if let offsets = indexTime.intersect(fileTime: fileTime),
               let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .master, chunk: 0, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) {
                try omFile.willNeed3D(ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                start = fileTime.upperBound
            }
        }
        if start >= indexTime.upperBound {
            return
        }
        
        if hasYearlyFiles {
            let startYear = time.range.lowerBound.toComponents().year
            /// end year is included in itteration range
            let endYear = time.range.upperBound.add(-1 * time.dtSeconds).toComponents().year
            for year in startYear ... endYear {
                let yeartime = TimerangeDt(start: Timestamp(year, 1, 1), to: Timestamp(year+1, 1, 1), dtSeconds: time.dtSeconds)
                /// as index
                let fileTime = yeartime.toIndexTime()
                guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                    continue
                }
                guard let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .year, chunk: year, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) else {
                    continue
                }
                try omFile.willNeed3D(ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                start = fileTime.upperBound
            }
        }
        if start >= indexTime.upperBound {
            return
        }
        let subring = start ..< indexTime.upperBound
        for timeChunk in subring.divideRoundedUp(divisor: nTimePerFile) {
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                continue
            }
            guard let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .chunk, chunk: timeChunk, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) else {
                continue
            }
            try omFile.willNeed3D(ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
        }
    }
    
    func read2D(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings) throws -> Array2DFastTime {
        let data = try read(variable: variable, location: location, level: level, time: time)
        return Array2DFastTime(data: data, nLocations: location.count, nTime: time.time.count)
    }
    
    /**
     TODO:
     - `level` implementation could be moved to a 3D file level
     */
    func read(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings) throws -> [Float] {
        let indexTime = time.time.toIndexTime()
        let nTime = indexTime.count
        var start = indexTime.lowerBound
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var out = [Float](repeating: .nan, count: nTime * location.count)
        
        if let masterTimeRange {
            let fileTime = TimerangeDt(range: masterTimeRange, dtSeconds: time.dtSeconds).toIndexTime()
            if let offsets = indexTime.intersect(fileTime: fileTime),
               let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .master, chunk: 0, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) {
                try omFile.read3D(into: &out, ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                start = fileTime.upperBound
            }
        }
        
        if hasYearlyFiles {
            let startYear = time.range.lowerBound.toComponents().year
            /// end year is included in itteration range
            let endYear = time.range.upperBound.add(-1 * time.dtSeconds).toComponents().year
            for year in startYear ... endYear {
                let yeartime = TimerangeDt(start: Timestamp(year, 1, 1), to: Timestamp(year+1, 1, 1), dtSeconds: time.dtSeconds)
                /// as index
                let fileTime = yeartime.toIndexTime()
                guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                    continue
                }
                guard let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .year, chunk: year, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) else {
                    continue
                }
                try omFile.read3D(into: &out, ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: offsets)
                start = fileTime.upperBound
            }
        }
        let delta = start - indexTime.lowerBound
        if start >= indexTime.upperBound {
            return out
        }
        let subring = start ..< indexTime.upperBound
        for timeChunk in subring.divideRoundedUp(divisor: nTimePerFile) {
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            guard let offsets = subring.intersect(fileTime: fileTime) else {
                continue
            }
            guard let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .chunk, chunk: timeChunk, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) else {
                continue
            }
            try omFile.read3D(into: &out, ny: ny, nx: nx, nTime: nTime, nMembers: nMembers, location: location, level: level, timeOffsets: (offsets.file, offsets.array.add(delta)))
        }
        return out
    }
    
    /**
     Write new data to the archived storage and combine it with existint data.
     Updates are done in chunks to keep memory size low. Otherwise ICON update would take 4+ GB memory for just this function.
     */
    func updateFromTimeOriented(variable: String, array2d: Array2DFastTime, time: TimerangeDt, scalefactor: Float, compression: CompressionType = .pfor_delta2d_int16) throws {
        
        precondition(array2d.nTime == time.count)
        
        // Process at most 8 MB at once
        try updateFromTimeOrientedStreaming(variable: variable, time: time, scalefactor: scalefactor, compression: compression, onlyGeneratePreviousDays: false) { d0offset in
            
            let locationRange = d0offset ..< min(d0offset+nLocationsPerChunk, nLocations)
            let dataRange = locationRange.multiply(array2d.nTime)
            return array2d.data[dataRange]
        }
    }
    
    /**
     Write new data to archived storage and combine it with existing data.
     `supplyChunk` should provide data for a couple of thousands locations at once. Upates are done streamlingly to low memory usage
     */
    func updateFromTimeOrientedStreaming(variable: String, time: TimerangeDt, scalefactor: Float, compression: CompressionType = .pfor_delta2d_int16, onlyGeneratePreviousDays: Bool, supplyChunk: (_ dim0Offset: Int) throws -> ArraySlice<Float>) throws {
        
        let indexTime = time.toIndexTime()
        let indextimeChunked = indexTime.divideRoundedUp(divisor: nTimePerFile)
        
        /// Previous days of forecast to keep. Max 7 past days
        /// `0..<1` if previous days are not generated
        /// `1..<n` for all previous days
        let previousDaysRange: Range<Int> = onlyGeneratePreviousDays ? (1..<max(1, min(8, time.range.count / 86400))) : (0..<1)
        if previousDaysRange.isEmpty {
            return
        }
        
        struct WriterPerStep {
            let read: OmFileReader<MmapFile>?
            let write: OmFileWriterState<FileHandle>
            let offsets: (file: CountableRange<Int>, array: CountableRange<Int>)
            let fileName: String
            let skip: Int
        }
        
        // open all files for all timeranges and write a header
        let writers: [WriterPerStep] = try indextimeChunked.flatMap { timeChunk -> [WriterPerStep] in
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                return []
            }
            
            return try previousDaysRange.map { previousDay -> WriterPerStep in
                let skip =  previousDay * 86400 / time.dtSeconds
                let readFile = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .chunk, chunk: timeChunk, ensembleMember: 0, previousDay: previousDay)
                try readFile.createDirectory()
                let tempFile = readFile.getFilePath() + "~"
                // Another process might be updating this file right now. E.g. Second flush of GFS ensemble
                FileManager.default.waitIfFileWasRecentlyModified(at: tempFile)
                try FileManager.default.removeItemIfExists(at: tempFile)
                let fn = try FileHandle.createNewFile(file: tempFile)
                
                let omRead = try readFile.openRead()
                try omRead?.willNeed()

                let omWrite = try OmFileWriterState<FileHandle>(fn: fn, dim0: nLocations, dim1: nTimePerFile, chunk0: chunknLocations, chunk1: nTimePerFile, compression: compression, scalefactor: scalefactor, fsync: true)

                try omWrite.writeHeader()
                
                return WriterPerStep(read: omRead, write: omWrite, offsets: offsets, fileName: readFile.getFilePath(), skip: skip)
            }
        }
        
        let nIndexTime = indexTime.count
        var fileData = [Float]()
        
        // loop chunks of locations
        var dim0Offset = 0
        while dim0Offset < nLocations {
            let data = try supplyChunk(dim0Offset)
            let nLocInChunk = data.count / nIndexTime
            //print("nLocaInChunk \(nLocInChunk) dim0Offset \(dim0Offset) total \(nLocations) \(Float(dim0Offset)/Float(nLocations))%")
            if fileData.count < nLocInChunk * nTimePerFile {
                fileData = [Float](repeating: .nan, count: nLocInChunk * nTimePerFile)
            }
            let locationRange = dim0Offset ..< min(dim0Offset+nLocInChunk, nLocations)
            
            for writer in writers {
                // Read existing data for a chunk of locations
                if let omRead = writer.read, omRead.dim0 == nLocations, omRead.dim1 == nTimePerFile {
                    try omRead.read(into: &fileData, arrayDim1Range: 0..<locationRange.count * nTimePerFile, arrayDim1Length: nTimePerFile, dim0Slow: locationRange, dim1: 0..<nTimePerFile)
                } else {
                    /// If the old file does not exist, just make sure it is filled with NaNs
                    for i in fileData.indices {
                        fileData[i] = .nan
                    }
                }
                
                // write "new" data into existing data
                for l in 0..<locationRange.count {
                    for (tFile,tArray) in zip(writer.offsets.file, writer.offsets.array) {
                        if tArray < writer.skip {
                            continue
                        }
                        /*if nIndexTime - tArray <= skipLast {
                            continue
                        }*/
                        if data[data.startIndex + l * nIndexTime + tArray].isNaN {
                            continue
                        }
                        fileData[nTimePerFile * l + tFile] = data[data.startIndex + l * nIndexTime + tArray]
                    }
                }
                
                // Write data
                try writer.write.write(fileData[0..<locationRange.count * nTimePerFile])
            }
            
            dim0Offset += nLocInChunk
        }
        
        /// Write end of file and move it in position
        for writer in writers {
            try writer.write.writeTail()
            try writer.write.fn.close()
            
            // Overwrite existing file, with newly created
            try FileManager.default.moveFileOverwrite(from: "\(writer.fileName)~", to: writer.fileName)
        }
    }
    
    
    /**
     Write new data to archived storage and combine it with existing data.
     `supplyChunk` should provide data for a couple of thousands locations at once. Upates are done streamlingly to low memory usage
     */
    func updateFromTimeOrientedStreaming3D(variable: String, time: TimerangeDt, scalefactor: Float, compression: CompressionType = .pfor_delta2d_int16, onlyGeneratePreviousDays: Bool, supplyChunk: (_ y: Range<UInt64>, _ x: Range<UInt64>, _ member: Range<UInt64>) throws -> ArraySlice<Float>) throws {
        
        let indexTime = time.toIndexTime()
        let indextimeChunked = indexTime.divideRoundedUp(divisor: nTimePerFile)
        
        /// Previous days of forecast to keep. Max 7 past days
        /// `0..<1` if previous days are not generated
        /// `1..<n` for all previous days
        let previousDaysRange: Range<Int> = onlyGeneratePreviousDays ? (1..<max(1, min(8, time.range.count / 86400))) : (0..<1)
        if previousDaysRange.isEmpty {
            return
        }
        
        struct WriterPerStep {
            let read: OmFileReader2<MmapFile>?
            let writeFile: OmFileWriter2<FileHandle>
            let write: OmFileWriterArray<Float, FileHandle>
            let writeFn: FileHandle
            let offsets: (file: CountableRange<Int>, array: CountableRange<Int>)
            let fileName: String
            let skip: Int
        }
        
        // open all files for all timeranges and write a header
        let writers: [WriterPerStep] = try indextimeChunked.flatMap { timeChunk -> [WriterPerStep] in
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            guard let offsets = indexTime.intersect(fileTime: fileTime) else {
                return []
            }
            
            return try previousDaysRange.map { previousDay -> WriterPerStep in
                let skip =  previousDay * 86400 / time.dtSeconds
                let readFile = OmFileManagerReadable.domainChunk(domain: domain, variable: variable, type: .chunk, chunk: timeChunk, ensembleMember: 0, previousDay: previousDay)
                try readFile.createDirectory()
                let tempFile = readFile.getFilePath() + "~"
                // Another process might be updating this file right now. E.g. Second flush of GFS ensemble
                FileManager.default.waitIfFileWasRecentlyModified(at: tempFile)
                try FileManager.default.removeItemIfExists(at: tempFile)
                let fn = try FileHandle.createNewFile(file: tempFile)
                let omRead = try? OmFileReader2(file: readFile.getFilePath())
                
                let writeFile = OmFileWriter2(fn: fn, initialCapacity: 1024*1024)
                let writer = try writeFile.prepareArray(
                    type: Float.self,
                    dimensions: nMembers <= 1 ? [UInt64(ny), UInt64(nx), UInt64(nTimePerFile)] : [UInt64(ny), UInt64(nx), UInt64(nMembers), UInt64(nTimePerFile)],
                    chunkDimensions: nMembers <= 1 ? [1, UInt64(chunknLocations), UInt64(nTimePerFile)] : [1, UInt64(chunknLocations), 1, UInt64(nTimePerFile)],
                    compression: compression,
                    scale_factor: scalefactor,
                    add_offset: 0
                )
                return WriterPerStep(read: omRead, writeFile: writeFile, write: writer, writeFn: fn, offsets: offsets, fileName: readFile.getFilePath(), skip: skip)
            }
        }
        
        let nIndexTime = indexTime.count
        
        /// Spatial files use chunks multiple time larger than the final chunk. E.g. [15,526] will be [1,15] in the final time-series file
        let spatialChunks = OmFileSplitter.calculateSpatialXYChunk(domain: domain.getDomain(), nMembers: nMembers)
        var fileData = [Float](repeating: .nan, count: spatialChunks.y * spatialChunks.x * nTimePerFile * nMembers)
        
        for yStart in stride(from: 0, to: UInt64(ny), by: UInt64.Stride(spatialChunks.y)) {
            for xStart in stride(from: 0, to: UInt64(nx), by: UInt64.Stride(spatialChunks.x)) {
                let yRange = yStart ..< min(yStart + UInt64(spatialChunks.y), UInt64(ny))
                let xRange = xStart ..< min(xStart + UInt64(spatialChunks.x), UInt64(nx))
                let memberRange = 0 ..< UInt64(nMembers)
                
                // Contains the entire time-series to be updated for a chunks of locations
                let data = try supplyChunk(yRange, xRange, memberRange)
                
                // TODO check if chunks need to be reorganised for ensemble files!!!
                
                for writer in writers {
                    if let omRead = writer.read?.asArray(of: Float.self) {
                        // Read existing data for a range of locations
                        let dimensions = omRead.getDimensions()
                        switch dimensions.count {
                        case 2: // Old legacy file
                            if dimensions[0] == UInt64(ny * nx) {
                                // Dimensions are ok, read data. Ignores legacy ensemble files
                                let start = yRange.lowerBound * UInt64(nx) + xRange.lowerBound
                                let count = UInt64(yRange.count * xRange.count)
                                try omRead.read(
                                    into: &fileData,
                                    range: [start ..< start + count, 0..<UInt64(nTimePerFile)]
                                )
                            }
                        case 3:
                            try omRead.read(
                                into: &fileData,
                                range: [yRange, xRange, 0..<UInt64(nTimePerFile)]
                            )
                        case 4: // ensemble files
                            try omRead.read(
                                into: &fileData,
                                range: [yRange, xRange, memberRange, 0..<UInt64(nTimePerFile)]
                            )
                        default:
                            fatalError("Unexpected number of dimensions (\(dimensions.count))")
                        }

                    } else {
                        // If the old file does not exist, just make sure it is filled with NaNs
                        for i in fileData.indices {
                            fileData[i] = .nan
                        }
                    }
                    // write "new" data into existing data
                    for l in 0 ..< (yRange.count * xRange.count * nMembers) {
                        for (tFile,tArray) in zip(writer.offsets.file, writer.offsets.array) {
                            if tArray < writer.skip {
                                continue
                            }
                            if data[data.startIndex + l * nIndexTime + tArray].isNaN {
                                continue
                            }
                            fileData[nTimePerFile * l + tFile] = data[data.startIndex + l * nIndexTime + tArray]
                        }
                    }
                    
                    // Write data
                    /// TODO support for array slices
                    try writer.write.writeData(
                        array: Array(fileData[0..<yRange.count * xRange.count * nMembers * nTimePerFile]),
                        arrayDimensions: nMembers <= 1 ?
                        [UInt64(yRange.count), UInt64(xRange.count), UInt64(nTimePerFile)] :
                            [UInt64(yRange.count), UInt64(xRange.count), UInt64(nMembers), UInt64(nTimePerFile)]
                    )
                }
            }
        }
        
        /// Write end of file and move it in position
        for writer in writers {
            let root = try writer.writeFile.write(array: writer.write.finalise(), name: "", children: [])
            try writer.writeFile.writeTrailer(rootVariable: root)
            try writer.writeFn.close()
            
            // Overwrite existing file, with newly created
            try FileManager.default.moveFileOverwrite(from: "\(writer.fileName)~", to: writer.fileName)
        }
    }
}

extension OmFileReader {
    /// Read data from file. Switch between old legacy files and new multi dimensional files.
    /// Note: `nTime` is the output array nTime. It is now the file nTime!
    /// TODO: nMembers variable is wrong if called via API controller. Aways 1
    func read3D(into: inout [Float], ny: Int, nx: Int, nTime: Int, nMembers: Int, location: Range<Int>, level: Int, timeOffsets: (file: CountableRange<Int>, array: CountableRange<Int>)) throws {
        let dimensions = reader.getDimensions()
        switch dimensions.count {
        case 2:
            // Legacy files use 2 dimensions and flatten XY coordinates
            guard dim0 % (nx*ny) == 0 else {
                return // in case dimensions got change and do not agree anymore, ignore this file
            }
            /// Even worse, they also flatten `levels` dimensions which is used for ensemble files
            let nLevels = dim0 / (nx*ny)
            if nLevels > 1 && location.count > 1 {
                fatalError("Multi level and multi location not supported")
            }
            guard level < nLevels else {
                return
            }
            let dim0 = location.lowerBound * nLevels + level ..< location.lowerBound * nLevels + level + location.count
            try read(into: &into, arrayDim1Range: timeOffsets.array, arrayDim1Length: nTime, dim0Slow: dim0, dim1: timeOffsets.file)
        case 3:
            // File uses dimensions [ny,nx,ntime]
            guard ny == dimensions[0], nx == dimensions[1] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound-1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, fileTime]
            do {
                try reader.read(
                    into: &into,
                    range: range,
                    intoCubeOffset: [0, 0, UInt64(timeOffsets.array.lowerBound)],
                    intoCubeDimension: [UInt64(y.count), UInt64(x.count), UInt64(nTime)]
                )
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        case 4:
            // File uses dimensions [ny,nx,nLevel,ntime]
            //print("4D \(dimensions.map{Int($0)}) ny\(ny) nx\(nx) nMembers\(nMembers) l\(level)")
            guard ny == dimensions[0], nx == dimensions[1], level < dimensions[2] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound-1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let l = UInt64(level) ..< UInt64(level+1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, l, fileTime]
            do {
                try reader.read(
                    into: &into,
                    range: range,
                    intoCubeOffset: [0, 0, 0, UInt64(timeOffsets.array.lowerBound)],
                    intoCubeDimension: [UInt64(y.count), UInt64(x.count), 1, UInt64(nTime)]
                )
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        default:
            fatalError("ndims not implemented")
        }
    }
    
    /// Prefetch data for fast access. Switch between old legacy files and new multi dimensional files
    /// Note: `nTime` is the output array nTime. It is now the file nTime!
    /// /// TODO: nMembers variable is wrong if called via API controller. Aways 1
    func willNeed3D(ny: Int, nx: Int, nTime: Int, nMembers: Int, location: Range<Int>, level: Int, timeOffsets: (file: CountableRange<Int>, array: CountableRange<Int>)) throws {
        let dimensions = reader.getDimensions()
        switch dimensions.count {
        case 2:
            // Legacy files use 2 dimensions and flatten XY coordinates
            guard dim0 % (nx*ny) == 0 else {
                return // in case dimensions got change and do not agree anymore, ignore this file
            }
            /// Even worse, they also flatten `levels` dimensions which is used for ensemble files
            let nLevels = dim0 / (nx*ny)
            if nLevels > 1 && location.count > 1 {
                fatalError("Multi level and multi location not supported")
            }
            guard level < nLevels else {
                return
            }
            let dim0 = location.lowerBound * nLevels + level ..< location.lowerBound * nLevels + level + location.count
            try willNeed(dim0Slow: dim0, dim1: timeOffsets.file)
        case 3:
            // File uses dimensions [ny,nx,ntime]
            guard ny == dimensions[0], nx == dimensions[1] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound-1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, fileTime]
            do {
                try reader.willNeed(range: range)
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        case 4:
            // File uses dimensions [ny,nx,nLevel,ntime]
            guard ny == dimensions[0], nx == dimensions[1], level < dimensions[2] else {
                return
            }
            let x = UInt64(location.lowerBound % nx) ..< UInt64((location.upperBound-1) % nx) + 1
            let y = UInt64(location.lowerBound / nx) ..< UInt64(location.lowerBound / nx + 1)
            let l = UInt64(level) ..< UInt64(level+1)
            let fileTime = UInt64(timeOffsets.file.lowerBound) ..< UInt64(timeOffsets.file.upperBound)
            let range = [y, x, l, fileTime]
            do {
                try reader.willNeed(range: range)
            } catch OmFileFormatSwiftError.omDecoder(let error) {
                print("\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
                throw OmFileFormatSwiftError.omDecoder(error: "\(error) range=\(range) [ny=\(ny) nx=\(nx) nTime=\(nTime) location=\(location) nMembers=\(nMembers) level=\(level) timeOffsets=\(timeOffsets)]")
            }
        default:
            fatalError("ndims not implemented")
        }
    }
}


extension OmFileSplitter {
    /// Prepare a write to store individual timesteps as spatial encoded files
    /// This makes it easier to migrate to the new file format writer
    static func makeSpatialWriter(domain: GenericDomain, nMembers: Int = 1) -> OmFileWriter {
        if OpenMeteo.generteOmFilesVersion3 {
            /// TODO: Not sure if chunklocations needs to be dependent on nMembers....
            let chunks = calculateSpatialXYChunk(domain: domain, nMembers: nMembers)
            return OmFileWriter(dim0: domain.grid.ny, dim1: domain.grid.nx, chunk0: chunks.y, chunk1: chunks.x)
        }
        /// TODO: Not sure if chunklocations needs to be dependent on nMembers....
        let nLocationsPerChunk = OmFileSplitter(domain, nMembers: nMembers, chunknLocations: nMembers > 1 ? nMembers : nil).nLocationsPerChunk
        return OmFileWriter(dim0: 1, dim1: domain.grid.count, chunk0: 1, chunk1: nLocationsPerChunk)
    }
    
    static func calculateSpatialXYChunk(domain: GenericDomain, nMembers: Int) -> (y: Int, x: Int) {
        let splitter = OmFileSplitter(domain, nMembers: nMembers/*, chunknLocations: nMembers > 1 ? nMembers : nil*/)
        let nx = domain.grid.nx
        let ny = domain.grid.ny
        let nTimePerFile = splitter.nTimePerFile // domain.omFileLength
        let chunknLocations = splitter.chunknLocations // max(6, 3072 / nTimePerFile)
        let xchunks = max(1, min(nx, 8*1024*1024 / MemoryLayout<Float>.stride / nTimePerFile / nMembers / chunknLocations * chunknLocations))
        let ychunks = max(1, min(ny, 8*1024*1024 / MemoryLayout<Float>.stride / nTimePerFile / nMembers / xchunks))
        print("Chunks [\(ychunks),\(xchunks)] nTimePerFile=\(nTimePerFile) chunknLocations=\(chunknLocations)")
        return (ychunks, xchunks)
    }
}


extension OmFileWriter {
    /// Write all data at once without any streaming
    /// Creates a temporary file and returns only a file handle
    public func writeTemporary(compressionType: CompressionType, scalefactor: Float, all: [Float]) throws -> FileHandle {
        let file = "\(OpenMeteo.tempDirectory)/\(Int.random(in: 0..<Int.max)).om"
        try FileManager.default.removeItemIfExists(at: file)
        let fn = try FileHandle.createNewFile(file: file, exclusive: true)
        try FileManager.default.removeItem(atPath: file)
        try write(fn: fn, compressionType: compressionType, scalefactor: scalefactor, fsync: false, supplyChunk: { range in
            return ArraySlice(all)
        })
        return fn
    }
}
