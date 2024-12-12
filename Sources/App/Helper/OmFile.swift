import Foundation
import OmFileFormatSwift


/// Read any time from multiple files
struct OmFileSplitter {
    let domain: DomainRegistry
    
    let masterTimeRange: Range<Timestamp>?
    
    let hasYearlyFiles: Bool
    
    /// actually also in file
    let nLocations: Int
    
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
    
    init<Domain: GenericDomain>(_ domain: Domain, nLocations: Int? = nil, nMembers: Int? = nil, chunknLocations: Int? = nil) {
        self.init(
            domain: domain.domainRegistry,
            nLocations: nLocations ?? (domain.grid.count * max(nMembers ?? 1, 1)),
            nTimePerFile: domain.omFileLength,
            hasYearlyFiles: domain.hasYearlyFiles,
            masterTimeRange: domain.masterTimeRange,
            chunknLocations: chunknLocations
        )
    }
    
    init(domain: DomainRegistry, nLocations: Int, nTimePerFile: Int, hasYearlyFiles: Bool, masterTimeRange: Range<Timestamp>?, chunknLocations: Int? = nil) {
        self.domain = domain
        self.nLocations = nLocations
        self.nTimePerFile = nTimePerFile
        self.hasYearlyFiles = hasYearlyFiles
        self.masterTimeRange = masterTimeRange
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
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var start = indexTime.lowerBound
        
        if let masterTimeRange {
            let fileTime = TimerangeDt(range: masterTimeRange, dtSeconds: time.dtSeconds).toIndexTime()
            if let offsets = indexTime.intersect(fileTime: fileTime),
               let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .master, chunk: 0, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) {
                try omFile.willNeed(location: location, dim1: offsets.file, level: level, nLocations: nLocations)
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
                try omFile.willNeed(location: location, dim1: offsets.file, level: level, nLocations: nLocations)
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
            try omFile.willNeed(location: location, dim1: offsets.file, level: level, nLocations: nLocations)
        }
    }
    
    func read2D(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings) throws -> Array2DFastTime {
        let data = try read(variable: variable, location: location, level: level, time: time)
        return Array2DFastTime(data: data, nLocations: location.count, nTime: time.time.count)
    }
    
    func read(variable: String, location: Range<Int>, level: Int, time: TimerangeDtAndSettings) throws -> [Float] {
        let indexTime = time.time.toIndexTime()
        var start = indexTime.lowerBound
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var out = [Float](repeating: .nan, count: indexTime.count * location.count)
        
        if let masterTimeRange {
            let fileTime = TimerangeDt(range: masterTimeRange, dtSeconds: time.dtSeconds).toIndexTime()
            if let offsets = indexTime.intersect(fileTime: fileTime),
               let omFile = try OmFileManager.get(.domainChunk(domain: domain, variable: variable, type: .master, chunk: 0, ensembleMember: time.ensembleMember, previousDay: time.previousDay)) {
                
                try omFile.read(into: &out, arrayDim1Range: offsets.array, arrayDim1Length: time.time.count, location: location, dim1: offsets.file, level: level, nLocations: nLocations)
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
                try omFile.read(into: &out, arrayDim1Range: offsets.array, arrayDim1Length: time.time.count, location: location, dim1: offsets.file, level: level, nLocations: nLocations)
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
            try omFile.read(into: &out, arrayDim1Range: offsets.array, arrayDim1Length: time.time.count, location: location, dim1: offsets.file, level: level, nLocations: nLocations)
        }
        return out
    }
    
    /**
     Write new data to the archived storage and combine it with existint data.
     Updates are done in chunks to keep memory size low. Otherwise ICON update would take 4+ GB memory for just this function.
     */
    func updateFromTimeOriented(variable: String, array2d: Array2DFastTime, time: TimerangeDt, scalefactor: Float, compression: CompressionType = .p4nzdec256) throws {
        
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
    func updateFromTimeOrientedStreaming(variable: String, time: TimerangeDt, scalefactor: Float, compression: CompressionType = .p4nzdec256, onlyGeneratePreviousDays: Bool, supplyChunk: (_ dim0Offset: Int) throws -> ArraySlice<Float>) throws {
        
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
                if let omRead = writer.read, omRead.getDimensions().count == 2, omRead.getDimensions()[0] == nLocations, omRead.getDimensions()[1] == nTimePerFile {
                    try omRead.read(
                        into: &fileData,
                        dimRead: [UInt64(locationRange.lowerBound)..<UInt64(locationRange.upperBound), 0..<UInt64(nTimePerFile)]
                    )
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
}
