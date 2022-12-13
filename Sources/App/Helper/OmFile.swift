import Foundation
import SwiftPFor2D


/// Read any time from multiple files
struct OmFileSplitter {
    
    /// like `/data/domain/` will be expanded to `/data/domain/variable_123235234.om`
    let basePath: String
    
    /// like `/data/domain-yearly/` and will be expanded to `/data/domain-yearly/2012_variable.om`
    let yearlyArchivePath: String?
    
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
    var chunknLocations: Int {
        Self.calcChunknLocations(nTimePerFile: nTimePerFile)
    }
    
    /// With dynamic nLocation selection based on time, we get chunk locations for each domain. Minimum is set to 6, because spatial correlation does not work well with lower than 6 steps
    /// icon = 12
    /// icon-eu =  16
    /// icon-d2 = 25
    /// ecmwf = 30
    /// NOTE: carefull with reducing nchunkLocaiton, because updates will use the wrong buffer size!!!!
    static func calcChunknLocations(nTimePerFile: Int) -> Int {
        max(6, 3072 / nTimePerFile)
    }
    
    init(basePath: String, nLocations: Int, nTimePerFile: Int, yearlyArchivePath: String?) {
        self.basePath = basePath
        self.nLocations = nLocations
        self.nTimePerFile = nTimePerFile
        self.yearlyArchivePath = yearlyArchivePath
    }
    
    // optimise to use 8 MB memory, but aligned to even `chunknLocations`
    var nLocationsPerChunk: Int {
        8*1024*1024 / MemoryLayout<Float>.stride / nTimePerFile / chunknLocations * chunknLocations
    }

    /// Prefetch all required data into memory
    func willNeed(variable: String, location: Int, time: TimerangeDt) throws {
        // TODO: maybe we can keep the file handles better in scope
        let ringtime = time.toIndexTime()
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var start = ringtime.lowerBound
        if let yearlyArchivePath = yearlyArchivePath {
            let startYear = time.range.lowerBound.toComponents().year
            /// end year is included in itteration range
            let endYear = time.range.upperBound.add(-1 * time.dtSeconds).toComponents().year
            for year in startYear ... endYear {
                let yeartime = TimerangeDt(start: Timestamp(year, 1, 1), to: Timestamp(year+1, 1, 1), dtSeconds: time.dtSeconds)
                /// as index
                let fileTime = yeartime.toIndexTime()
                guard let offsets = ringtime.intersect(fileTime: fileTime) else {
                    continue
                }
                guard let omFile = try OmFileManager.get(basePath: yearlyArchivePath, variable: variable, timeChunk: year) else {
                    continue
                }
                guard omFile.dim0 == nLocations else {
                    continue
                }
                try omFile.willNeed(dim0Slow: location..<location+1, dim1: offsets.file)
                start = fileTime.upperBound
            }
        }
        if start >= ringtime.upperBound {
            return
        }
        let subring = start ..< ringtime.upperBound
        for timeChunk in subring.lowerBound / nTimePerFile ..< subring.upperBound.divideRoundedUp(divisor: nTimePerFile) {
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            guard let offsets = ringtime.intersect(fileTime: fileTime) else {
                continue
            }
            guard let omFile = try OmFileManager.get(basePath: basePath, variable: variable, timeChunk: timeChunk) else {
                continue
            }
            guard omFile.dim0 == nLocations else {
                continue
            }
            try omFile.willNeed(dim0Slow: location..<location+1, dim1: offsets.file)
        }
    }
    
    func read(variable: String, location: Int, time: TimerangeDt) throws -> [Float] {
        let ringtime = time.toIndexTime()
        var start = ringtime.lowerBound
        /// If yearly files are present, the start parameter is moved to read fewer files later
        var out = [Float](repeating: .nan, count: ringtime.count)
        
        if let yearlyArchivePath = yearlyArchivePath {
            let startYear = time.range.lowerBound.toComponents().year
            /// end year is included in itteration range
            let endYear = time.range.upperBound.add(-1 * time.dtSeconds).toComponents().year
            for year in startYear ... endYear {
                let yeartime = TimerangeDt(start: Timestamp(year, 1, 1), to: Timestamp(year+1, 1, 1), dtSeconds: time.dtSeconds)
                /// as index
                let fileTime = yeartime.toIndexTime()
                guard let offsets = ringtime.intersect(fileTime: fileTime) else {
                    continue
                }
                guard let omFile = try OmFileManager.get(basePath: yearlyArchivePath, variable: variable, timeChunk: year) else {
                    continue
                }
                guard omFile.dim0 == nLocations else {
                    continue
                }
                //assert(omFile.chunk0 == nLocations)
                //assert(omFile.chunk1 == nTimePerFile)
                try omFile.read(into: &out, arrayRange: offsets.array, dim0Slow: location..<location+1, dim1: offsets.file)
                start = fileTime.upperBound
            }
        }
        let delta = start - ringtime.lowerBound
        if start >= ringtime.upperBound {
            return out
        }
        let subring = start ..< ringtime.upperBound
        for timeChunk in subring.lowerBound / nTimePerFile ..< subring.upperBound.divideRoundedUp(divisor: nTimePerFile) {
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            guard let offsets = subring.intersect(fileTime: fileTime) else {
                continue
            }
            guard let omFile = try OmFileManager.get(basePath: basePath, variable: variable, timeChunk: timeChunk) else {
                continue
            }
            guard omFile.dim0 == nLocations else {
                continue
            }
            //assert(omFile.chunk0 == nLocations)
            //assert(omFile.chunk1 == nTimePerFile)
            try omFile.read(into: &out, arrayRange: offsets.array.add(delta), dim0Slow: location..<location+1, dim1: offsets.file)
        }
        return out
    }
    
    /**
     Write new data to the archived storage and combine it with existint data.
     Updates are done in chunks of 8 MB to keep memory size low. Otherwise ICON update would take 4+ GB memory for just this function.
     
     TODO: smoothing is not implemented
     TODO: a data callback would be possible to reduce memory every further -> issue with itterating over time, have to completely change OmFileWriter
     */
    func updateFromTimeOriented(variable: String, array2d: Array2DFastTime, ringtime: Range<Int>, skipFirst: Int, smooth: Int, skipLast: Int, scalefactor: Float, compression: CompressionType = .p4nzdec256) throws {
        
        // optimise to use 8 MB memory, but aligned to even `chunknLocations`
        let locationsChunk = nLocationsPerChunk
        
        // Allocate buffers to uncompress existing data
        var fileData = [Float](repeating: .nan, count: nTimePerFile * locationsChunk)
        
        let writer = OmFileWriter(dim0: nLocations, dim1: nTimePerFile, chunk0: chunknLocations, chunk1: nTimePerFile)
        
        /// icon global, one file has 4GB uncompressed floats inside....
        /// Therefore we only read 12 locations from each file at once and then write them to the new file
        /// This greatly reduced memory... Otherwise the icon downloader takes 8GB memory
        for timeChunk in ringtime.lowerBound / nTimePerFile ..< ringtime.upperBound.divideRoundedUp(divisor: nTimePerFile) {
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            
            guard let offsets = ringtime.intersect(fileTime: fileTime) else {
                continue
            }
            
            let readFile = basePath + variable + "_\(timeChunk).om"
            let tempFile = readFile + "~"
            let omRead = FileManager.default.fileExists(atPath: readFile) ? try OmFileReader(file: readFile) : nil
            
            try FileManager.default.removeItemIfExists(at: tempFile)
            
            // generate new file, while filling it step by step
            try writer.write(file: tempFile, compressionType: compression, scalefactor: scalefactor, supplyChunk: {
                d0offset in
                
                // Read existing data for a chunk of locations.. Around 8MB data
                let locationRange = d0offset ..< min(d0offset+locationsChunk, nLocations)
                if let omRead = omRead, omRead.dim0 == nLocations, omRead.dim1 == nTimePerFile {
                    try omRead.read(into: &fileData, arrayRange: fileData.indices, dim0Slow: locationRange, dim1: 0..<nTimePerFile)
                } else {
                    /// If the old file does not exist, just make sure it is filled with NaNs
                    for i in fileData.indices {
                        fileData[i] = .nan
                    }
                }
                
                // write "new" data into existing data
                for l in 0..<locationRange.count {
                    for (tFile,tArray) in zip(offsets.file, offsets.array) {
                        if tArray < skipFirst {
                            continue
                        }
                        if array2d.nTime - tArray <= skipLast {
                            continue
                        }
                        fileData[nTimePerFile * l + tFile] = array2d.data[(l + d0offset) * array2d.nTime + tArray]
                    }
                }
                
                // Return data to writer and write chunk to file
                return fileData[0..<locationRange.count * nTimePerFile]
            })
            
            // Overwrite existing file, with newly created
            try FileManager.default.moveFileOverwrite(from: tempFile, to: readFile)
        }
    }
    
    /**
     Write new data to the archived storage and combine it with existint data.
     `supplyChunk` should provide data for a couple of thousands locations at once. Upates are done streamlingly to low memory usage
     
     TODO: smoothing is not implemented
     */
    func updateFromTimeOrientedStreaming(variable: String, ringtime: Range<Int>, skipFirst: Int, smooth: Int, skipLast: Int, scalefactor: Float, compression: CompressionType = .p4nzdec256, supplyChunk: (_ dim0Offset: Int) throws -> ArraySlice<Float>) throws {
        
        // open all files for all timeranges and write a header
        let writers: [(read: OmFileReader<MmapFile>?, write: OmFileWriterState<FileHandle>, offsets: (file: CountableRange<Int>, array: CountableRange<Int>), fileName: String)] = try (ringtime.lowerBound / nTimePerFile ..< ringtime.upperBound.divideRoundedUp(divisor: nTimePerFile)).compactMap { timeChunk in
            let fileTime = timeChunk * nTimePerFile ..< (timeChunk+1) * nTimePerFile
            
            guard let offsets = ringtime.intersect(fileTime: fileTime) else {
                return nil
            }
            
            let readFile = basePath + variable + "_\(timeChunk).om"
            let tempFile = readFile + "~"
            let omRead = FileManager.default.fileExists(atPath: readFile) ? try OmFileReader(file: readFile) : nil
            try omRead?.willNeed()
            
            try FileManager.default.removeItemIfExists(at: tempFile)
            
            let bufferSize = P4NENC256_BOUND(n: chunknLocations * nTimePerFile, bytesPerElement: compression.bytesPerElement)
            let readBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 4)
            /// 1MB write cache
            let writeBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: max(1024 * 1024, bufferSize))
            //print("readBuffer \(readBuffer.count.bytesHumanReadable) writeBuffer \(writeBuffer.count.bytesHumanReadable)")
            let fn = try FileHandle.createNewFile(file: tempFile)
            
            let omWrite = try OmFileWriterState<FileHandle>(fn: fn, dim0: nLocations, dim1: nTimePerFile, chunk0: chunknLocations, chunk1: nTimePerFile, compression: compression, scalefactor: scalefactor, readBuffer: readBuffer, writeBuffer: writeBuffer)
            
            try omWrite.writeHeader()
            
            return (omRead, omWrite, offsets, readFile)
        }
        
        let nRingtime = ringtime.count
        var fileData = [Float]()
        
        // loop chunks of locations
        var dim0Offset = 0
        while dim0Offset < nLocations {
            let data = try supplyChunk(dim0Offset)
            let nLocInChunk = data.count / nRingtime
            //print("nLocaInChunk \(nLocInChunk) dim0Offset \(dim0Offset) total \(nLocations) \(Float(dim0Offset)/Float(nLocations))%")
            if fileData.count < nLocInChunk * nTimePerFile {
                fileData = [Float](repeating: .nan, count: nLocInChunk * nTimePerFile)
            }
            
            for writer in writers {
                // Read existing data for a chunk of locations
                let locationRange = dim0Offset ..< min(dim0Offset+nLocInChunk, nLocations)
                if let omRead = writer.read, omRead.dim0 == nLocations, omRead.dim1 == nTimePerFile {
                    try omRead.read(into: &fileData, arrayRange: 0..<locationRange.count * nTimePerFile, dim0Slow: locationRange, dim1: 0..<nTimePerFile)
                } else {
                    /// If the old file does not exist, just make sure it is filled with NaNs
                    for i in fileData.indices {
                        fileData[i] = .nan
                    }
                }
                
                // write "new" data into existing data
                for l in 0..<locationRange.count {
                    for (tFile,tArray) in zip(writer.offsets.file, writer.offsets.array) {
                        if tArray < skipFirst {
                            continue
                        }
                        if nRingtime - tArray <= skipLast {
                            continue
                        }
                        fileData[nTimePerFile * l + tFile] = data[l * nRingtime + tArray]
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
            writer.write.readBuffer.deallocate()
            writer.write.writeBuffer.deallocate()
            
            try writer.write.fn.close()
            
            // Overwrite existing file, with newly created
            try FileManager.default.moveFileOverwrite(from: "\(writer.fileName)~", to: writer.fileName)
        }
    }
}
