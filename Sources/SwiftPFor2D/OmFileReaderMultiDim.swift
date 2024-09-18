//
//  File.swift
//  
//
//  Created by Patrick Zippenfenig on 09.09.2024.
//

import Foundation
@_implementationOnly import CTurboPFor
@_implementationOnly import CHelper

/**
 TODO:
 - IO merging
 - differnet compression implementation
 */
struct OmFileReadRequest {
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    /// The dimensions of the file
    let dims: [Int]
    
    /// How the dimensions are chunked
    let chunks: [Int]
    
    /// Which values to read
    let dimRead: [Range<Int>]
    
    /// The offset the result should be placed into the target cube. E.g. a slice or a chunk of a cube
    let intoCoordLower: [Int]
    
    /// The target cube dimensions. E.g. Reading 2 years of data may read data from mutliple files
    let intoCubeDimension: [Int] // = dimRead.map { $0.count }
    
    /// Automatically merge and break up IO to ideal sizes
    /// Merging is important to reduce the number of IO operations for the lookup table
    /// A maximum size will break up chunk reads. Otherwise a full file read could result in a single 20GB read.
    let io_size_merge: Int = 512
    
    /// Maximum length of a return IO read
    let io_size_max: Int = 65536
    
    /// Actually read data from a file
    /// TODO: The read offset calculation is not ideal
    /// Probably have to change some code for IO merging
    func read_from_file<Backend: OmFileReaderBackend>(fn: Backend, into: UnsafeMutablePointer<Float>, chunkBuffer: UnsafeMutableRawPointer) {
        
        var chunkIndex = get_first_chunk_position()
        
        let nChunks = number_of_chunks()
        
        fn.withUnsafeBytes({ ptr in
            while true {
                // Read index and decode
                let readIndexInstruction = get_index_read(globalChunkNum: chunkIndex)
                let indexData = ptr.baseAddress!.advanced(by: OmHeader.length + readIndexInstruction.offset).assumingMemoryBound(to: UInt8.self)
                
                // Read data and decode
                let readDataInstruction = get_data_read(globalChunkNum: chunkIndex, data: indexData)
                let dataData = ptr.baseAddress!.advanced(by: OmHeader.length + nChunks*8 + readDataInstruction.offset)
                decode_chunk_into_array(globalChunkNum: chunkIndex, data: dataData, into: into, chunkBuffer: chunkBuffer)
                
                // Look for next index
                guard let nextChunk = get_next_chunk_position(globalChunkNum: chunkIndex) else {
                    return
                }
                chunkIndex = nextChunk
            }
        })
    }
    
    /// With IO merging
    func read_from_file2<Backend: OmFileReaderBackend>(fn: Backend, into: UnsafeMutablePointer<Float>, chunkBuffer: UnsafeMutableRawPointer) {
        
        print("new read \(self)")
        
        var chunkIndex: Int? = get_first_chunk_position()
        
        let nChunks = number_of_chunks()
        
        fn.withUnsafeBytes({ ptr in
            /// Loop over index blocks
            while let readIndexInstruction = get_next_index_read(chunkIndex: &chunkIndex) {
                var chunkIndexRead: Int? = readIndexInstruction.indexChunkNumStart
                let indexEndChunk = readIndexInstruction.endChunk
                
                print("read index \(readIndexInstruction), chunkIndexRead=\(chunkIndexRead), indexEndChunk=\(indexEndChunk)")
                
                
                
                // actually "read" index data from file
                let indexData = ptr.baseAddress!.advanced(by: OmHeader.length + readIndexInstruction.offset).assumingMemoryBound(to: UInt8.self)
                
                /// Loop over data blocks
                while let readDataInstruction = get_next_data_read(chunkIndex: &chunkIndexRead, indexStartChunk: readIndexInstruction.indexChunkNumStart, indexEndChunk: indexEndChunk, indexData: indexData) {
                    print("read data \(readDataInstruction)")
                    // actually "read" compressed chunk data from file
                    let dataData = ptr.baseAddress!.advanced(by: OmHeader.length + nChunks*8 + readDataInstruction.offset)
                    
                    let uncompressedSize = decode_chunks(globalChunkNum: readDataInstruction.dataStartChunk, lastChunk: readDataInstruction.dataLastChunk, data: dataData, into: into, chunkBuffer: chunkBuffer)
                    if uncompressedSize != readDataInstruction.count {
                        fatalError("Uncompressed size missmatch")
                    }
                }
            }
        })
    }
    
    
    func number_of_chunks() -> Int {
        var n = 1
        for i in 0..<dims.count {
            n *= dims[i].divideRoundedUp(divisor: chunks[i])
        }
        return n
    }
    
    /// Return the next data-block to read from the lookup table. Merges reads from mutliple chunks adress lookups.
    /// Modifies `globalChunkNum` to keep as a internal reference counter
    /// Should be called in a loop. Return `nil` once all blocks have been processed and the hyperchunk read is complete
    public func get_next_index_read(chunkIndex: inout Int?) -> (offset: Int, count: Int, indexChunkNumStart: Int, endChunk: Int)? {
        guard let indexStartChunk = chunkIndex else {
            print("end of index")
            return nil
        }
        
        var globalChunkNum = indexStartChunk
        
        /// loop to next chunk until the end is reached, consecutive reads are further appart than `io_size_merge` or the maximum read length is reached `io_size_max`
        while true {
            guard let next = get_next_chunk_position(globalChunkNum: globalChunkNum) else {
                // there is no next chunk anymore, finish processing the current one and then stop with the next call
                chunkIndex = nil
                break
            }
            chunkIndex = next
            
            guard (next - globalChunkNum)*8 <= io_size_merge, (next - indexStartChunk)*8 <= io_size_max else {
                // the next read would exceed IO limitons
                break
            }
            globalChunkNum = next
        }
        if indexStartChunk == 0 {
            return (0, (globalChunkNum + 1) * 8, indexStartChunk, globalChunkNum)
        }
        return ((indexStartChunk-1) * 8, (globalChunkNum - indexStartChunk + 1) * 8, indexStartChunk, globalChunkNum)
    }
    
    
    /// Data = index of global chunk num
    public func get_next_data_read(chunkIndex: inout Int?, indexStartChunk: Int, indexEndChunk: Int, indexData: UnsafeRawPointer) -> (offset: Int, count: Int, dataStartChunk: Int, dataLastChunk: Int)? {
        guard let dataStartChunk = chunkIndex else {
            print("end of data")
            return nil
        }
        var globalChunkNum = indexStartChunk
        
        // index is a flat Int64 array
        let data = indexData.assumingMemoryBound(to: Int.self)
        
        /// If the start index starts at 0, the entire array is shifted by one, because the start position of 0 is not stored
        let startOffset = indexStartChunk == 0 ? 1 : 0
        
        /// Index data relative to startindex, needs special care because startpos==0 reads one value less
        let startPos = dataStartChunk == 0 ? 0 : data.advanced(by: indexStartChunk - dataStartChunk - startOffset).pointee
        var endPos = data.advanced(by: dataStartChunk == 0 ? 0 : 1).pointee
        
        /// loop to next chunk until the end is reached, consecutive reads are further appart than `io_size_merge` or the maximum read length is reached `io_size_max`
        while true {
            guard let next = get_next_chunk_position(globalChunkNum: globalChunkNum), next <= indexEndChunk else {
                chunkIndex = nil
                break
            }
            chunkIndex = next
            
            let dataStartPos = data.advanced(by: next - indexStartChunk - startOffset).pointee
            let dataEndPos = data.advanced(by: next - indexStartChunk - startOffset + 1).pointee
            
            print("Next IO read size: \(dataEndPos - startPos), merge distance \(dataStartPos - endPos)")
            
            if dataEndPos - startPos > io_size_max,
                dataStartPos - endPos > io_size_merge {
                break
            }
            endPos = dataEndPos
            globalChunkNum = next
        }
        print("Read \(startPos)-\(endPos) (\(endPos - startPos) bytes)")
        return (startPos, endPos - startPos, dataStartChunk, globalChunkNum)
    }
    
    /// Decode multiple chunks inside `data`. Chunks are ordered strictly increasing by 1. Due to IO merging, a chunk might be read, that does not contain relevant data for the output.
    /// Returns number of processed bytes from input
    public func decode_chunks(globalChunkNum: Int, lastChunk: Int, data: UnsafeRawPointer, into: UnsafeMutablePointer<Float>, chunkBuffer: UnsafeMutableRawPointer) -> Int {

        // Note: Relays on the correct number of uncompressed bytes from the compression library...
        // Maybe we need a differnet way that is independenet of this information
        var pos = 0
        for chunkNum in globalChunkNum ... lastChunk {
            let uncompressedBytes = decode_chunk_into_array(globalChunkNum: chunkNum, data: data.advanced(by: pos), into: into, chunkBuffer: chunkBuffer)
            pos += uncompressedBytes
        }
        return pos
    }
    
    // Return the address to read the lookup table
    public func get_index_read(globalChunkNum: Int) -> (offset: Int, count: Int) {
        if globalChunkNum == 0 {
            return (0, 4)
        }
        return ((globalChunkNum-1) * 8, 2 * 8)
        
        //let startPos = globalChunkNum == 0 ? 0 : chunkOffsets[globalChunkNum-1]
        //precondition(compressedDataStartOffset + startPos < ptr.count, "chunk out of range read")
        //let lengthCompressedBytes = chunkOffsets[globalChunkNum] - startPos
    }
    
    /// Data = index of global chunk num
    public func get_data_read(globalChunkNum: Int, data: UnsafeRawPointer) -> (offset: Int, count: Int) {
        /// TODO correct offset
        let offsetToData = 0
        if globalChunkNum == 0 {
            let startPos = 0
            let lengthCompressedBytes = data.assumingMemoryBound(to: Int.self).pointee
            return (offsetToData + startPos, lengthCompressedBytes)
        }
        
        let startPos = data.assumingMemoryBound(to: Int.self).pointee
        let lengthCompressedBytes = data.assumingMemoryBound(to: Int.self).advanced(by: 1).pointee - startPos
        return (offsetToData + startPos, lengthCompressedBytes)
    }
    
    /// Writes a chunk index into the
    /// Return number of uncompressed bytes from the data
    @discardableResult
    public func decode_chunk_into_array(globalChunkNum: Int, data: UnsafeRawPointer, into: UnsafeMutablePointer<Float>, chunkBuffer: UnsafeMutableRawPointer) -> Int {
        print("globalChunkNum=\(globalChunkNum)")
        
        let chunkBuffer = chunkBuffer.assumingMemoryBound(to: UInt16.self)
        
        var rollingMultiplty = 1
        var rollingMultiplyChunkLength = 1
        var rollingMultiplyTargetCube = 1
        
        /// Read coordinate from temporary chunk buffer
        var d = 0
        
        /// Write coordinate to output cube
        var q = 0
        
        var lengthLast = 0
        
        var no_data = false
        
        /// Count length in chunk and find first buffer offset position
        for i in (0..<dims.count).reversed() {
            let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
            let c0 = (globalChunkNum / rollingMultiplty) % nChunksInThisDimension
            let length0 = min((c0+1) * chunks[i], dims[i]) - c0 * chunks[i]
            let chunkGlobal0 = c0 * chunks[i] ..< c0 * chunks[i] + length0
            
            if dimRead[i].upperBound <= chunkGlobal0.lowerBound || dimRead[i].lowerBound >= chunkGlobal0.upperBound {
                // There is no data in this chunk that should be read
                print("Not reading chunk \(globalChunkNum)")
                no_data = true
            }
            
            let clampedGlobal0 = chunkGlobal0.clamped(to: dimRead[i])
            let clampedLocal0 = clampedGlobal0.substract(c0 * chunks[i])
            
            if i == dims.count-1 {
                lengthLast = length0
            }
            
            /// start only!
            let d0 = clampedLocal0.lowerBound
            /// Target coordinate in hyperchunk. Range `0...dim0Read`
            let t0 = chunkGlobal0.lowerBound - dimRead[i].lowerBound + d0
            
            let q0 = t0 + intoCoordLower[i]
            
            d = d + rollingMultiplyChunkLength * d0
            q = q + rollingMultiplyTargetCube * q0
                            
            rollingMultiplty *= nChunksInThisDimension
            rollingMultiplyTargetCube *= intoCubeDimension[i]
            rollingMultiplyChunkLength *= length0
        }
        
        /// How many elements are in this chunk
        let lengthInChunk = rollingMultiplyChunkLength
        print("lengthInChunk \(lengthInChunk), t sstart=\(d)")
        
        // load chunk from mmap
        //precondition(globalChunkNum < nChunks, "invalid chunkNum")
        //let startPos = globalChunkNum == 0 ? 0 : chunkOffsets[globalChunkNum-1]
        //precondition(compressedDataStartOffset + startPos < ptr.count, "chunk out of range read")
        //let lengthCompressedBytes = chunkOffsets[globalChunkNum] - startPos
        //fn.preRead(offset: compressedDataStartOffset + startPos, count: lengthCompressedBytes)
        let mutablePtr = UnsafeMutablePointer(mutating: data.assumingMemoryBound(to: UInt8.self))
        let uncompressedBytes = p4nzdec128v16(mutablePtr, lengthInChunk, chunkBuffer)
        //precondition(uncompressedBytes == lengthCompressedBytes, "chunk read bytes mismatch")
        
        if no_data {
            return uncompressedBytes
        }
        
        // TODO chunks could actually contain no relevant data due.
        
        // TODO multi dimensional encode/decode
        delta2d_decode(lengthInChunk / lengthLast, lengthLast, chunkBuffer)
        
        /// Loop over all values need to be copied to the output buffer
        loopBuffer: while true {
            print("read buffer from pos=\(d) and write to \(q)")
            
            let val = chunkBuffer[d]
            if val == Int16.max {
                into.advanced(by: q).pointee = .nan
            } else {
                let unscaled = compression == .p4nzdec256logarithmic ? (powf(10, Float(val) / scalefactor) - 1) : (Float(val) / scalefactor)
                into.advanced(by: q).pointee = unscaled
            }
            
            
            // TODO for the last dimension, it would be better to have a range copy
            // The loop below could be expensive....
                            
            /// Move `q` and `d` to next position
            rollingMultiplty = 1
            rollingMultiplyTargetCube = 1
            rollingMultiplyChunkLength = 1
            for i in (0..<dims.count).reversed() {
                let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                let c0 = (globalChunkNum / rollingMultiplty) % nChunksInThisDimension
                let length0 = min((c0+1) * chunks[i], dims[i]) - c0 * chunks[i]
                let chunkGlobal0 = c0 * chunks[i] ..< c0 * chunks[i] + length0
                let clampedGlobal0 = chunkGlobal0.clamped(to: dimRead[i])
                let clampedLocal0 = clampedGlobal0.substract(c0 * chunks[i])
                
                /// More forward
                d += rollingMultiplyChunkLength
                q += rollingMultiplyTargetCube
                
                let d0 = (d / rollingMultiplyChunkLength) % length0
                if d0 != clampedLocal0.upperBound && d0 != 0 {
                    break // no overflow in this dimension, break
                }
                
                d -= clampedLocal0.count * rollingMultiplyChunkLength
                q -= clampedLocal0.count * rollingMultiplyTargetCube
                
                rollingMultiplty *= nChunksInThisDimension
                rollingMultiplyTargetCube *= intoCubeDimension[i]
                rollingMultiplyChunkLength *= length0
                if i == 0 {
                    // All chunks have been read. End of iteration
                    break loopBuffer
                }
            }
        }
        
        return uncompressedBytes
    }
    
    func get_first_chunk_position() -> Int {
        var globalChunkNum = 0
        //var totalChunks = 1
        for i in 0..<dims.count {
            let chunkInThisDimension = dimRead[i].divide(by: chunks[i])
            //let nChunksReadInThisDimension = chunkInThisDimension.count
            //nChunksToRead *= nChunksReadInThisDimension
            let firstChunkInThisDimension = chunkInThisDimension.lowerBound
            let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
            globalChunkNum = globalChunkNum * nChunksInThisDimension + firstChunkInThisDimension
            //print(nChunksReadInThisDimension, firstChunkInThisDimension)
            //totalChunks *= nChunksInThisDimension
        }
        return globalChunkNum
    }
    
    func get_next_chunk_position(globalChunkNum: Int) -> Int? {
        var nextChunk = globalChunkNum
        
        // Move `globalChunkNum` to next position
        var rollingMultiplty = 1
        for i in (0..<dims.count).reversed() {
            // E.g. 10
            let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
            
            // E.g. 2..<4
            let chunkInThisDimension = dimRead[i].divide(by: chunks[i])
                            
            // Move forward by one
            nextChunk += rollingMultiplty
            // Check for overflow in limited read coordinates
            
            let c0 = (nextChunk / rollingMultiplty) % nChunksInThisDimension
            if c0 != chunkInThisDimension.upperBound && c0 != 0 {
                break // no overflow in this dimension, break
            }
            nextChunk -= chunkInThisDimension.count * rollingMultiplty
            rollingMultiplty *= nChunksInThisDimension
            if i == 0 {
                // All chunks have been read. End of iteration
                return nil
            }
        }
        return nextChunk
    }
}


public final class OmFileReader2<Backend: OmFileReaderBackend> {
    public let fn: Backend
    
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    /// Number of elements in dimension 0... The slow one
    public let dim0: Int
    
    /// Number of elements in dimension 1... The fast one. E.g. time-series
    public let dim1: Int
    
    /// Number of elements in dimension 0... The slow one
    public let dim2: Int
    
    /// Number of elements in dimension 1... The fast one. E.g. time-series
    public let dim3: Int
    
    /// Number of elements to chunk in dimension 0. Must be lower or equals `chunk0`
    public let chunk0: Int
    
    /// Number of elements to chunk in dimension 1. Must be lower or equals `chunk1`
    public let chunk1: Int
    
    
    /// Number of elements to chunk in dimension 0. Must be lower or equals `chunk0`
    public let chunk2: Int
    
    /// Number of elements to chunk in dimension 1. Must be lower or equals `chunk1`
    public let chunk3: Int
    
    
    public init(fn: Backend) throws {
        // Fetch header
        fn.preRead(offset: 0, count: OmHeader.length)
        let header = fn.withUnsafeBytes {
            $0.baseAddress!.withMemoryRebound(to: OmHeader.self, capacity: 1) { ptr in
                ptr.pointee
            }
        }
        
        guard header.magicNumber1 == OmHeader.magicNumber1 && header.magicNumber2 == OmHeader.magicNumber2 else {
            throw SwiftPFor2DError.notAOmFile
        }
        
        self.fn = fn
        dim0 = header.dim0
        dim1 = header.dim1
        chunk0 = header.chunk0
        chunk1 = header.chunk1
        dim2 = header.dim0
        dim3 = header.dim1
        chunk2 = header.chunk0
        chunk3 = header.chunk1
        scalefactor = header.scalefactor
        // bug in version 1: compression type was random
        compression = header.version == 1 ? .p4nzdec256 : CompressionType(rawValue: header.compression)!
    }
    
    /// Prefetch fhe required data regions into memory
    public func willNeed(dim0Slow dim0Read: Range<Int>? = nil, dim1 dim1Read: Range<Int>? = nil) throws {
        guard fn.needsPrefetch else {
            return
        }
        let dim0Read = dim0Read ?? 0..<dim0
        let dim1Read = dim1Read ?? 0..<dim1
        
        guard dim0Read.lowerBound >= 0 && dim0Read.lowerBound <= dim0 && dim0Read.upperBound <= dim0 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim0Read, allowed: dim0)
        }
        guard dim1Read.lowerBound >= 0 && dim1Read.lowerBound <= dim1 && dim1Read.upperBound <= dim1 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim1Read, allowed: dim1)
        }
        
        let nDim0Chunks = dim0.divideRoundedUp(divisor: chunk0)
        let nDim1Chunks = dim1.divideRoundedUp(divisor: chunk1)
        
        let nChunks = nDim0Chunks * nDim1Chunks
        var fetchStart = 0
        var fetchEnd = 0
        fn.withUnsafeBytes { ptr in
            let chunkOffsets = ptr.assumingMemoryBound(to: UInt8.self).baseAddress!.advanced(by: OmHeader.length).assumingMemoryBound(to: Int.self, capacity: nChunks)
            
            let compressedDataStartOffset = OmHeader.length + nChunks * MemoryLayout<Int>.stride
            
            for c0 in dim0Read.divide(by: chunk0) {
                let c1Range = dim1Read.divide(by: chunk1)
                let c1Chunks = c1Range.add(c0 * nDim1Chunks)
                // pre-read chunk table at specific offset
                fn.prefetchData(offset: OmHeader.length + max(c1Chunks.lowerBound - 1, 0) * MemoryLayout<Int>.stride, count: (c1Range.count+1) * MemoryLayout<Int>.stride)
                fn.preRead(offset: OmHeader.length + max(c1Chunks.lowerBound - 1, 0) * MemoryLayout<Int>.stride, count: (c1Range.count+1) * MemoryLayout<Int>.stride)
                
                for c1 in c1Range {
                    // load chunk from mmap
                    let chunkNum = c0 * nDim1Chunks + c1
                    let startPos = chunkNum == 0 ? 0 : chunkOffsets[chunkNum-1]
                    let lengthCompressedBytes = chunkOffsets[chunkNum] - startPos
                    
                    let newfetchStart = compressedDataStartOffset + startPos
                    let newfetchEnd = newfetchStart + lengthCompressedBytes
                    
                    if newfetchStart != fetchEnd {
                        if fetchEnd != 0 {
                            //print("fetching from \(fetchStart) to \(fetchEnd)... count \(fetchEnd-fetchStart)")
                            fn.prefetchData(offset: fetchStart, count: fetchEnd-fetchStart)
                        }
                        fetchStart = newfetchStart
                        
                    }
                    fetchEnd = newfetchEnd
                }
            }
        }
        
        //print("fetching from \(fetchStart) to \(fetchEnd)... count \(fetchEnd-fetchStart)")
        fn.prefetchData(offset: fetchStart, count: fetchEnd-fetchStart)
    }
    
    public static func test() {
        /// The dimensions of the file
        let dims = [100, 100, 100, 100]
        
        /// How the dimensions are chunked
        let chunks = [10, 10, 10, 10]
        
        /// Which values to read
        let dimRead = [5..<6, 5..<6, 5..<16, 15..<26]
        
        /// The offset the result should be placed into the target cube. E.g. a slice or a chunk of a cube
        let intoCoordLower = [0, 0, 0, 0]
        
        /// The target cube dimensions. E.g. Reading 2 years of data may read data from mutliple files
        let intoCubeDimension = dimRead.map { $0.count }
        
        // Find the first chunk that needs to be read
        //var nChunksToRead = 1
        var globalChunkNum = 0
        //var totalChunks = 1
        for i in 0..<dims.count {
            let chunkInThisDimension = dimRead[i].divide(by: chunks[i])
            let nChunksReadInThisDimension = chunkInThisDimension.count
            //nChunksToRead *= nChunksReadInThisDimension
            let firstChunkInThisDimension = chunkInThisDimension.lowerBound
            let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
            globalChunkNum = globalChunkNum * nChunksInThisDimension + firstChunkInThisDimension
            print(nChunksReadInThisDimension, firstChunkInThisDimension)
            //totalChunks *= nChunksInThisDimension
        }
        //print("nChunksToRead \(nChunksToRead)")
        print("first chunk to read: globalChunkNum \(globalChunkNum)")
        //print("totalChunks \(totalChunks)")
                
        // Loop over all chunks that need to be read
        outer: while true {
            print("globalChunkNum=\(globalChunkNum)")
            
            var rollingMultiplty = 1
            var rollingMultiplyChunkLength = 1
            var rollingMultiplyTargetCube = 1
            
            /// Read coordinate from temporary chunk buffer
            var d = 0
            
            /// Write coordinate to output cube
            var q = 0
            
            /// Count length in chunk and find first buffer offset position
            for i in (0..<dims.count).reversed() {
                let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                let c0 = (globalChunkNum / rollingMultiplty) % nChunksInThisDimension
                let length0 = min((c0+1) * chunks[i], dims[i]) - c0 * chunks[i]
                let chunkGlobal0 = c0 * chunks[i] ..< c0 * chunks[i] + length0
                let clampedGlobal0 = chunkGlobal0.clamped(to: dimRead[i])
                let clampedLocal0 = clampedGlobal0.substract(c0 * chunks[i])
                
                /// start only!
                let d0 = clampedLocal0.lowerBound
                /// Target coordinate in hyperchunk. Range `0...dim0Read`
                let t0 = chunkGlobal0.lowerBound - dimRead[i].lowerBound + d0
                
                let q0 = t0 + intoCoordLower[i]
                
                d = d + rollingMultiplyChunkLength * d0
                q = q + rollingMultiplyTargetCube * q0
                                
                rollingMultiplty *= nChunksInThisDimension
                rollingMultiplyTargetCube *= intoCubeDimension[i]
                rollingMultiplyChunkLength *= length0
            }
            
            /// How many elements are in this chunk
            let lengthInChunk = rollingMultiplyChunkLength
            print("lengthInChunk \(lengthInChunk), t sstart=\(d)")
            
            // load chunk from mmap
            //precondition(globalChunkNum < nChunks, "invalid chunkNum")
            //let startPos = globalChunkNum == 0 ? 0 : chunkOffsets[globalChunkNum-1]
            //precondition(compressedDataStartOffset + startPos < ptr.count, "chunk out of range read")
            //let lengthCompressedBytes = chunkOffsets[globalChunkNum] - startPos
            //fn.preRead(offset: compressedDataStartOffset + startPos, count: lengthCompressedBytes)
            //let uncompressedBytes = p4nzdec128v16(compressedDataStartPtr.advanced(by: startPos), lengthInChunk, chunkBuffer)
            //precondition(uncompressedBytes == lengthCompressedBytes, "chunk read bytes mismatch")
            
            // TODO multi dimensional encode/decode
            
            /// Loop over all values need to be copied to the output buffer
            loopBuffer: while true {
                print("read buffer from pos=\(d) and write to \(q)")
                
                // TODO for the last dimension, it would be better to have a range copy
                // The loop below could be expensive....
                                
                /// Move `q` and `d` to next position
                rollingMultiplty = 1
                rollingMultiplyTargetCube = 1
                rollingMultiplyChunkLength = 1
                for i in (0..<dims.count).reversed() {
                    let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                    let c0 = (globalChunkNum / rollingMultiplty) % nChunksInThisDimension
                    let length0 = min((c0+1) * chunks[i], dims[i]) - c0 * chunks[i]
                    let chunkGlobal0 = c0 * chunks[i] ..< c0 * chunks[i] + length0
                    let clampedGlobal0 = chunkGlobal0.clamped(to: dimRead[i])
                    let clampedLocal0 = clampedGlobal0.substract(c0 * chunks[i])
                    
                    /// More forward
                    d += rollingMultiplyChunkLength
                    q += rollingMultiplyTargetCube
                    
                    let d0 = (d / rollingMultiplyChunkLength) % length0
                    if d0 != clampedLocal0.upperBound && d0 != 0 {
                        break // no overflow in this dimension, break
                    }
                    
                    d -= clampedLocal0.count * rollingMultiplyChunkLength
                    q -= clampedLocal0.count * rollingMultiplyTargetCube
                    
                    rollingMultiplty *= nChunksInThisDimension
                    rollingMultiplyTargetCube *= intoCubeDimension[i]
                    rollingMultiplyChunkLength *= length0
                    if i == 0 {
                        // All chunks have been read. End of iteration
                        break loopBuffer
                    }
                }
            }

            
            // Move `globalChunkNum` to next position
            rollingMultiplty = 1
            for i in (0..<dims.count).reversed() {
                // E.g. 10
                let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                
                // E.g. 2..<4
                let chunkInThisDimension = dimRead[i].divide(by: chunks[i])
                                
                // Move forward by one
                globalChunkNum += rollingMultiplty
                // Check for overflow in limited read coordinates
                
                let c0 = (globalChunkNum / rollingMultiplty) % nChunksInThisDimension
                if c0 != chunkInThisDimension.upperBound && c0 != 0 {
                    break // no overflow in this dimension, break
                }
                globalChunkNum -= chunkInThisDimension.count * rollingMultiplty
                rollingMultiplty *= nChunksInThisDimension
                if i == 0 {
                    // All chunks have been read. End of iteration
                    break outer
                }
            }
        }
    }
    
    /// Read data into existing buffers. Can only work with sequential ranges. Reading random offsets, requires external loop.
    ///
    /// This code could be moved to C/Rust for better performance. The 2D delta and scaling code is not yet using vector instructions yet
    /// Future implemtations could use async io via lib uring
    ///
    /// `into` is a 2d flat array with `arrayDim1Length` count elements in the fast dimension
    /// `chunkBuffer` is used to temporary decompress chunks of data
    /// `arrayDim1Range` defines the offset in dimension 1 what is applied to the read into array
    /// `arrayDim1Length` if dim0Slow.count is greater than 1, the arrayDim1Length will be used as a stride. Like `nTime` in a 2d fast time array
    /// `dim0Slow` the slow dimension to read. Typically a location range
    /// `dim1Read` the fast dimension to read. Tpyicall a time range
    public func read(dim0 dim0Read: Range<Int>, dim1 dim1Read: Range<Int>, dim2 dim2Read: Range<Int>, dim3 dim3Read: Range<Int>, into: HyperCubeSlice, chunkBuffer: UnsafeMutableRawPointer) throws {
        
        //assert(arrayDim1Range.count == dim1Read.count)
        
        guard dim0Read.lowerBound >= 0 && dim0Read.lowerBound <= dim0 && dim0Read.upperBound <= dim0 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim0Read, allowed: dim0)
        }
        guard dim1Read.lowerBound >= 0 && dim1Read.lowerBound <= dim1 && dim1Read.upperBound <= dim1 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim1Read, allowed: dim1)
        }
        guard dim2Read.lowerBound >= 0 && dim2Read.lowerBound <= dim2 && dim2Read.upperBound <= dim2 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim2Read, allowed: dim2)
        }
        guard dim3Read.lowerBound >= 0 && dim3Read.lowerBound <= dim3 && dim3Read.upperBound <= dim3 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim3Read, allowed: dim3)
        }
        let chunk0 = self.chunk0
        let chunk1 = self.chunk1
        let chunk2 = self.chunk2
        let chunk3 = self.chunk3
        
        // TODO validate hyper chunk coordinates
        
        let nDim0Chunks = dim0.divideRoundedUp(divisor: chunk0)
        let nDim1Chunks = dim1.divideRoundedUp(divisor: chunk1)
        let nDim2Chunks = dim2.divideRoundedUp(divisor: chunk2)
        let nDim3Chunks = dim3.divideRoundedUp(divisor: chunk3)
        
        let nChunks = nDim0Chunks * nDim1Chunks * nDim2Chunks * nDim3Chunks
        fn.withUnsafeBytes { ptr in
            //fn.preRead(offset: OmHeader.length, count: nChunks * MemoryLayout<Int>.stride)
            let chunkOffsets = ptr.assumingMemoryBound(to: UInt8.self).baseAddress!.advanced(by: OmHeader.length).assumingMemoryBound(to: Int.self, capacity: nChunks)
            
            let compressedDataStartOffset = OmHeader.length + nChunks * MemoryLayout<Int>.stride
            let compressedDataStartPtr = UnsafeMutablePointer(mutating: ptr.assumingMemoryBound(to: UInt8.self).baseAddress!.advanced(by: compressedDataStartOffset))
            
            switch compression {
            case.p4nzdec256logarithmic:
                fallthrough
            case .p4nzdec256:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Int16.self)
                
                let chunks = [chunk0, chunk1, chunk2, chunk3]
                let dims = [dim0, dim1, dim2, dim3]
                let dimRead = [dim0Read, dim1Read, dim2Read, dim3Read]
                
                // Find starting position
                var nChunksToRead = 1
                var globalChunkNum = 0
                for i in 0..<dims.count {
                    let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                    nChunksToRead *= nChunksInThisDimension
                    let firstChunkInThisDimension = dimRead[i].lowerBound / chunks[i]
                    globalChunkNum = globalChunkNum * nChunksInThisDimension + firstChunkInThisDimension
                }
                print("nChunksToRead \(nChunksToRead)")
                print("globalChunkNum \(globalChunkNum)")
                
                // Loop over all chunks that need to be read
                for c in 0..<nChunksToRead {
                    print("c=\(c) globalChunkNum=\(globalChunkNum)")
                    // load chunk from mmap
                    precondition(globalChunkNum < nChunks, "invalid chunkNum")
                    let startPos = globalChunkNum == 0 ? 0 : chunkOffsets[globalChunkNum-1]
                    precondition(compressedDataStartOffset + startPos < ptr.count, "chunk out of range read")
                    let lengthCompressedBytes = chunkOffsets[globalChunkNum] - startPos
                    fn.preRead(offset: compressedDataStartOffset + startPos, count: lengthCompressedBytes)
                    //let uncompressedBytes = p4nzdec128v16(compressedDataStartPtr.advanced(by: startPos), length0 * length1 * length2 * length3, chunkBuffer)
                    //precondition(uncompressedBytes == lengthCompressedBytes, "chunk read bytes mismatch")
                    
                    // Iterate dimensions and move `globalChunkNum` to next position
                    var chunkOffset = 1
                    for i in 0..<dims.count {
                        let nextChunk = c + 1
                        let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                        if nextChunk % nChunksInThisDimension == 0 {
                            let firstChunkInThisDimension = dimRead[i].lowerBound / chunks[i]
                            chunkOffset = chunkOffset * nChunksInThisDimension + firstChunkInThisDimension
                        }
                    }
                    globalChunkNum += chunkOffset
                }
                
                
                for c0 in dim0Read.divide(by: chunk0) {
                   
                    //let c1Chunks = c1Range.add(c0 * nDim1Chunks)
                    // pre-read chunk table at specific offset
                    //fn.preRead(offset: OmHeader.length + max(c1Chunks.lowerBound - 1, 0) * MemoryLayout<Int>.stride, count: (c1Range.count+1) * MemoryLayout<Int>.stride)
                    for c1 in dim1Read.divide(by: chunk1) {
                        for c2 in dim2Read.divide(by: chunk2) {
                            for c3 in dim3Read.divide(by: chunk3) {
                                // load chunk into buffer
                                // consider the length, even if the last is only partial... E.g. at 1000 elements with 600 chunk length, the last one is only 400
                                
                                let length0 = min((c0+1) * chunk0, dim0) - c0 * chunk0
                                let length1 = min((c1+1) * chunk1, dim1) - c1 * chunk1
                                let length2 = min((c2+1) * chunk2, dim2) - c2 * chunk2
                                let length3 = min((c3+1) * chunk3, dim3) - c3 * chunk3
                                
                                /// The chunk coordinates in global space... e.g. 600..<1000
                                let chunkGlobal0 = c0 * chunk0 ..< c0 * chunk0 + length0
                                let chunkGlobal1 = c1 * chunk1 ..< c1 * chunk1 + length1
                                let chunkGlobal2 = c2 * chunk2 ..< c2 * chunk2 + length2
                                let chunkGlobal3 = c3 * chunk3 ..< c3 * chunk3 + length3
                                
                                /// This chunk clamped to read coodinates... e.g. 650..<950
                                let clampedGlobal0 = chunkGlobal0.clamped(to: dim0Read)
                                let clampedGlobal1 = chunkGlobal1.clamped(to: dim1Read)
                                let clampedGlobal2 = chunkGlobal2.clamped(to: dim2Read)
                                let clampedGlobal3 = chunkGlobal3.clamped(to: dim3Read)
                                
                                // load chunk from mmap
                                let chunkNum = ((c0 * nDim1Chunks + c1) * nDim2Chunks + c2) * nDim3Chunks + c3
                                
                                precondition(chunkNum < nChunks, "invalid chunkNum")
                                let startPos = chunkNum == 0 ? 0 : chunkOffsets[chunkNum-1]
                                precondition(compressedDataStartOffset + startPos < ptr.count, "chunk out of range read")
                                let lengthCompressedBytes = chunkOffsets[chunkNum] - startPos
                                fn.preRead(offset: compressedDataStartOffset + startPos, count: lengthCompressedBytes)
                                let uncompressedBytes = p4nzdec128v16(compressedDataStartPtr.advanced(by: startPos), length0 * length1 * length2 * length3, chunkBuffer)
                                precondition(uncompressedBytes == lengthCompressedBytes, "chunk read bytes mismatch")
                                
                                // 2D delta decoding
                                delta2d_decode(length0, length1, chunkBuffer)
                                
                                // Moved to local coordinates... e.g. 50..<350. Coordinates of the current chunk
                                let clampedLocal0 = clampedGlobal0.substract(c0 * chunk0)
                                let clampedLocal1 = clampedGlobal1.substract(c1 * chunk1)
                                let clampedLocal2 = clampedGlobal2.substract(c2 * chunk2)
                                let clampedLocal3 = clampedGlobal3.substract(c3 * chunk2)
                                
                                /// Read coordinate in current chunk buffer
                                for d0 in clampedLocal0 {
                                    /// Target coordinate in hyperchunk. Range `0...dim0Read`
                                    let t0 = chunkGlobal0.lowerBound - dim0Read.lowerBound + d0
                                    /// Target coordinate in hyperchube
                                    let q0 = t0 + into.coord0.lowerBound
                                    
                                    for d1 in clampedLocal1 {
                                        let t1 = chunkGlobal1.lowerBound - dim1Read.lowerBound + d1
                                        let q1 = t1 + into.coord1.lowerBound
                                        
                                        for d2 in clampedLocal2 {
                                            let t2 = chunkGlobal2.lowerBound - dim2Read.lowerBound + d2
                                            let q2 = t2 + into.coord2.lowerBound
                                            
                                            for (i,d3) in clampedLocal3.enumerated() {
                                                let t3 = chunkGlobal3.lowerBound - dim3Read.lowerBound + d3
                                                let q3 = t3 + into.coord3.lowerBound
                                                
                                                let posBuffer = ((d0 * length1 + d1) * length2 + d2) * length3 + d3
                                                let posOut = ((q0 * into.cube.dim1 + q1) * into.cube.dim2 + q2) * into.cube.dim3 + q3
                                                
                                                let val = chunkBuffer[posBuffer]
                                                if val == Int16.max {
                                                    into.cube.data.baseAddress?.advanced(by: posOut).pointee = Float.nan
                                                } else {
                                                    let unscaled = compression == .p4nzdec256logarithmic ? (powf(10, Float(val) / scalefactor) - 1) : (Float(val) / scalefactor)
                                                    into.cube.data.baseAddress?.advanced(by: posOut).pointee = unscaled
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            case .fpxdec32:
                break
                /*let chunkBufferUInt = chunkBuffer.assumingMemoryBound(to: UInt32.self)
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Float.self)
                
                for c0 in dim0Read.divide(by: chunk0) {
                    let c1Range = dim1Read.divide(by: chunk1)
                    let c1Chunks = c1Range.add(c0 * nDim1Chunks)
                    // pre-read chunk table at specific offset
                    fn.preRead(offset: OmHeader.length + max(c1Chunks.lowerBound - 1, 0) * MemoryLayout<Int>.stride, count: (c1Range.count+1) * MemoryLayout<Int>.stride)
                    
                    for c1 in c1Range {
                        // load chunk into buffer
                        // consider the length, even if the last is only partial... E.g. at 1000 elements with 600 chunk length, the last one is only 400
                        let length1 = min((c1+1) * chunk1, dim1) - c1 * chunk1
                        let length0 = min((c0+1) * chunk0, dim0) - c0 * chunk0
                        
                        /// The chunk coordinates in global space... e.g. 600..<1000
                        let chunkGlobal0 = c0 * chunk0 ..< c0 * chunk0 + length0
                        let chunkGlobal1 = c1 * chunk1 ..< c1 * chunk1 + length1
                        
                        /// This chunk clamped to read coodinates... e.g. 650..<950
                        let clampedGlobal0 = chunkGlobal0.clamped(to: dim0Read)
                        let clampedGlobal1 = chunkGlobal1.clamped(to: dim1Read)
                        
                        // load chunk from mmap
                        let chunkNum = c0 * nDim1Chunks + c1
                        let startPos = chunkNum == 0 ? 0 : chunkOffsets[chunkNum-1]
                        let lengthCompressedBytes = chunkOffsets[chunkNum] - startPos
                        fn.preRead(offset: compressedDataStartOffset + startPos, count: lengthCompressedBytes)
                        let uncompressedBytes = fpxdec32(compressedDataStartPtr.advanced(by: startPos), length0 * length1, chunkBufferUInt, 0)
                        precondition(uncompressedBytes == lengthCompressedBytes)
                        
                        // 2D xor decoding
                        delta2d_decode_xor(length0, length1, chunkBuffer)
                        
                        /// Moved to local coordinates... e.g. 50..<350
                        let clampedLocal0 = clampedGlobal0.substract(c0 * chunk0)
                        let clampedLocal1 = clampedGlobal1.lowerBound - c1 * chunk1
                        
                        for d0 in clampedLocal0 {
                            let readStart = clampedLocal1 + d0 * length1
                            let localOut0 = chunkGlobal0.lowerBound + d0 - dim0Read.lowerBound
                            let localOut1 = clampedGlobal1.lowerBound - dim1Read.lowerBound
                            let localRange = localOut1 + localOut0 * arrayDim1Length + arrayDim1Range.lowerBound
                            for i in 0..<clampedGlobal1.count {
                                let posBuffer = readStart + i
                                let posOut = localRange + i
                                let val = chunkBuffer[posBuffer]
                                into.advanced(by: posOut).pointee = val
                            }
                        }
                    }
                }*/
            }
        }
    }
}


public struct HyperCube {
    let dim0: Int
    let dim1: Int
    let dim2: Int
    let dim3: Int
    let data: UnsafeMutableBufferPointer<Float>
}

public struct HyperCubeSlice {
    let cube: HyperCube
    /// same as offset+count
    let coord0: Range<Int>
    let coord1: Range<Int>
    let coord2: Range<Int>
    let coord3: Range<Int>
}
