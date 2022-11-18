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
        let locationsChunk = 8*1024*1024 / MemoryLayout<Float>.stride / nTimePerFile / chunknLocations * chunknLocations
        
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
                if let omRead = omRead {
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
}
