//
//  File.swift
//  
//
//  Created by Patrick Zippenfenig on 09.09.2024.
//

import Foundation
@_implementationOnly import CTurboPFor
@_implementationOnly import CHelper


struct ChunkIndexReadInstruction {
    var offset: Int
    var count: Int
    var indexRangeLower: Int
    var indexRangeUpper: Int
    var chunkIndexLower: Int
    var chunkIndexUpper: Int
    var nextChunkLower: Int
    var nextChunkUpper: Int
    
    public init(nextChunk: Range<Int>) {
        self.offset = 0
        self.count = 0
        self.indexRangeLower = 0
        self.indexRangeUpper = 0
        self.chunkIndexLower = 0
        self.chunkIndexUpper = 0
        self.nextChunkLower = nextChunk.lowerBound
        self.nextChunkUpper = nextChunk.upperBound
    }
}

struct ChunkDataReadInstruction {
    var offset: Int
    var count: Int
    let indexRangeLower: Int
    let indexRangeUpper: Int
    var chunkIndexLower: Int
    var chunkIndexUpper: Int
    var nextChunkLower: Int
    var nextChunkUpper: Int
    
    public init(indexRead: ChunkIndexReadInstruction) {
        self.offset = 0
        self.count = 0
        self.indexRangeLower = indexRead.indexRangeLower
        self.indexRangeUpper = indexRead.indexRangeUpper
        chunkIndexLower = 0
        chunkIndexUpper = 0
        self.nextChunkLower = indexRead.chunkIndexLower
        self.nextChunkUpper = indexRead.chunkIndexUpper
        
    }
}

/**
 C-style implementation to read chunks from a OpenMeteo file variable. No allocations should occur below.
 This code below might be move to C or other programming languages
 
 TODO:
 - 64 bit padding to trailer
 - reserved fields for trailer
 - data type support / filter pipeline?
 - consider if we need to access the index LUT inside decompress call instead of relying on returned data size. Certainly required for other compressors
 - number of chunks calculation may be move outside
 - All read requests should be guarded against out-of-bounds reads. May require `fileSize` as an input paramter
 */
struct OmFileDecoder {
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    /// The dimensions of the file
    let dims: [Int]
    
    /// How the dimensions are chunked
    let chunks: [Int]
    
    /// Which values to read
    let readOffset: [Int]
    
    /// Which values to read
    let readCount: [Int]
    
    /// The offset the result should be placed into the target cube. E.g. a slice or a chunk of a cube
    let intoCubeOffset: [Int]
    
    /// The target cube dimensions. E.g. Reading 2 years of data may read data from mutliple files
    let intoCubeDimension: [Int]
    
    /// Automatically merge and break up IO to ideal sizes
    /// Merging is important to reduce the number of IO operations for the lookup table
    /// A maximum size will break up chunk reads. Otherwise a full file read could result in a single 20GB read.
    let io_size_merge: Int
    
    /// Maximum length of a returned IO read
    let io_size_max: Int
    
    /// How long a chunk inside the LUT is after compression
    let lutChunkLength: Int
    
    /// Number of elements in each LUT chunk. If `1` this is an version 1/2 file with non-compressed LUT before data
    let lutChunkElementCount: Int
    
    /// Offset  in bytes of LUT index
    let lutStart: Int
    
    /// Number of chunkls. Precomputed, because it is required often
    let numberOfChunks: Int
    
    
    public init(scalefactor: Float, compression: CompressionType, dims: [Int], chunks: [Int], readOffset: [Int], readCount: [Int], intoCubeOffset: [Int], intoCubeDimension: [Int], lutChunkLength: Int, lutChunkElementCount: Int, lutStart: Int, io_size_merge: Int = 512, io_size_max: Int = 65536) {
        self.scalefactor = scalefactor
        self.compression = compression
        self.dims = dims
        self.chunks = chunks
        self.readOffset = readOffset
        self.readCount = readCount
        self.intoCubeOffset = intoCubeOffset
        self.intoCubeDimension = intoCubeDimension
        self.lutChunkLength = lutChunkLength
        self.lutChunkElementCount = lutChunkElementCount
        self.lutStart = lutStart
        self.io_size_max = io_size_max
        self.io_size_merge = io_size_merge
        
        var n = 1
        for i in 0..<dims.count {
            n *= dims[i].divideRoundedUp(divisor: chunks[i])
        }
        numberOfChunks = n
    }

    /// Get the size of the buffer that needs to be suplied to decode a single chunk. It is the product of chunk dimensions times the size of the output.
    public func get_read_buffer_size() -> Int {
        let chunkLength = chunks.reduce(1, *)
        return chunkLength * compression.bytesPerElement
    }
    
    /// Return the next data-block to read from the lookup table. Merges reads from mutliple chunks adress lookups.
    /// Modifies `chunkIndex` to keep as a internal reference counter
    /// Should be called in a loop. Return `nil` once all blocks have been processed and the hyperchunk read is complete
    public func get_next_index_read(indexRead: inout ChunkIndexReadInstruction) -> Bool {
        let chunkIndexStartLower = indexRead.nextChunkLower
        let chunkIndexStartUpper = indexRead.nextChunkUpper
        if chunkIndexStartLower == chunkIndexStartUpper {
            return false
        }
        indexRead.chunkIndexLower = chunkIndexStartLower
        indexRead.chunkIndexUpper = chunkIndexStartUpper
        indexRead.indexRangeLower = chunkIndexStartLower
        
        var chunkIndex = chunkIndexStartLower
        
        let isV3LUT = lutChunkElementCount > 1
        
        /// Old files do not store the chunk start in the first LUT entry
        /// LUT old: end0, end1, end2
        /// LUT new: start0, end0, end1, end2
        let alignOffset = isV3LUT || chunkIndexStartLower == 0 ? 0 : 1
        let endAlignOffset = isV3LUT ? 1 : 0
        
        var rangeEnd = chunkIndexStartUpper
        
        /// The current read start position
        let readStart = (chunkIndexStartLower-alignOffset) / lutChunkElementCount * lutChunkLength
        
        /// loop to next chunk until the end is reached, consecutive reads are further appart than `io_size_merge` or the maximum read length is reached `io_size_max`
        while true {
            /// The read end potiions of the previous chunk index. Could be consecutive, or has a huge gap.
            let readEndPrevious = chunkIndex / lutChunkElementCount * lutChunkLength
            
            /// How many elements could we read before we reach the maximum IO size
            let maxRead = io_size_max / lutChunkLength * lutChunkElementCount
            let nextIncrement = max(1, min(maxRead, rangeEnd - chunkIndex - 1))
            
            var next = chunkIndex + nextIncrement
            if next >= rangeEnd {
                guard let nextRange = get_next_chunk_position(chunkIndex: chunkIndex) else {
                    // there is no next chunk anymore, finish processing the current one and then stop with the next call
                    indexRead.nextChunkLower = 0
                    indexRead.nextChunkUpper = 0
                    break
                }
                rangeEnd = nextRange.upperBound
                next = nextRange.lowerBound
                
                indexRead.nextChunkLower = next
                indexRead.nextChunkUpper = rangeEnd
                let readStartNext = (next+endAlignOffset) / lutChunkElementCount * lutChunkLength - lutChunkLength
                
                // The new range could be quite far apart.
                // E.g. A LUT of 10MB and you only need information from the beginning and end
                // Check how "far" appart the the new read
                guard readStartNext - readEndPrevious <= io_size_merge else {
                    // Reads are too far appart. E.g. a lot of unsed data in the middle
                    break
                }
            }
            indexRead.nextChunkLower = next
            indexRead.nextChunkUpper = rangeEnd
            
            /// The read end position if the current index would be read
            let readEndNext = (next+endAlignOffset) / lutChunkElementCount * lutChunkLength
            
            guard readEndNext - readStart <= io_size_max else {
                // the next read would exceed IO limitons
                break
            }
            chunkIndex = next
        }
        let readEnd = ((chunkIndex + endAlignOffset) / lutChunkElementCount + 1) * lutChunkLength
        
        let lutTotalSize = numberOfChunks.divideRoundedUp(divisor: lutChunkElementCount) * lutChunkLength
        assert(readEnd <= lutTotalSize)
        
        indexRead.offset = lutStart + readStart
        indexRead.count = readEnd - readStart
        indexRead.indexRangeUpper = chunkIndex+1
        return true
    }
    
    
    /// Data = index of global chunk num
    public func get_next_data_read(dataRead: inout ChunkDataReadInstruction, indexData: UnsafeRawBufferPointer) -> Bool {
        let chunkRangeLower = dataRead.nextChunkLower
        let chunkRangeUpper = dataRead.nextChunkUpper
        if chunkRangeLower == chunkRangeUpper {
            return false
        }
        //dataRead.chunkIndex = chunkIndexStart
        let indexRangeLower = dataRead.indexRangeLower
        let indexRangeUpper = dataRead.indexRangeUpper
        dataRead.chunkIndexLower = chunkRangeLower
        var chunkIndex = chunkRangeLower
        //var nextChunkRangeLower: Int? = chunkRangeLower
        //var nextChunkRangeUpper: Int? = chunkRangeUpper
        
        /// Version 1 case
        if lutChunkElementCount == 1 {
            // index is a flat Int64 array
            let data = indexData.assumingMemoryBound(to: Int.self).baseAddress!
            
            /// If the start index starts at 0, the entire array is shifted by one, because the start position of 0 is not stored
            let startOffset = indexRangeLower == 0 ? 1 : 0
            
            /// Index data relative to startindex, needs special care because startpos==0 reads one value less
            let startPos = indexRangeLower == 0 ? 0 : data.advanced(by: indexRangeLower - chunkRangeLower - startOffset).pointee
            var endPos = data.advanced(by: indexRangeLower == 0 ? 0 : 1).pointee
            
            var rangeEnd = chunkRangeUpper
            
            /// loop to next chunk until the end is reached, consecutive reads are further appart than `io_size_merge` or the maximum read length is reached `io_size_max`
            while true {
                var next = chunkIndex + 1
                if next >= rangeEnd {
                    guard let nextRange = get_next_chunk_position(chunkIndex: chunkIndex) else {
                        // there is no next chunk anymore, finish processing the current one and then stop with the next call
                        dataRead.nextChunkLower = 0
                        dataRead.nextChunkUpper = 0
                        break
                    }
                    rangeEnd = nextRange.upperBound
                    next = nextRange.lowerBound
                }
                guard next < indexRangeUpper else {
                    dataRead.nextChunkLower = 0
                    dataRead.nextChunkUpper = 0
                    break
                }
                dataRead.nextChunkLower = next
                dataRead.nextChunkUpper = rangeEnd
                
                let dataStartPos = data.advanced(by: next - indexRangeLower - startOffset).pointee
                let dataEndPos = data.advanced(by: next - indexRangeLower - startOffset + 1).pointee
                
                /// Merge and split IO requests
                if dataEndPos - startPos > io_size_max,
                    dataStartPos - endPos > io_size_merge {
                    break
                }
                endPos = dataEndPos
                chunkIndex = next
            }
            /// Old files do not compress LUT and data is after LUT
            let dataStart = OmHeader.length + numberOfChunks*8
            
            //print("Read \(startPos)-\(endPos) (\(endPos - startPos) bytes)")
            
            dataRead.offset = startPos + dataStart
            dataRead.count = endPos - startPos
            dataRead.chunkIndexUpper = chunkIndex+1
            return true
        }

        
        let indexDataPtr = UnsafeMutablePointer(mutating: indexData.baseAddress!.assumingMemoryBound(to: UInt8.self))
        
        /// TODO This should be stack allocated to a max size of 256 elements
        var uncompressedLut = [UInt64](repeating: 0, count: lutChunkElementCount)
        
        /// Which LUT chunk is currently loaded into `uncompressedLut`
        var lutChunk = chunkRangeLower / lutChunkElementCount
        
        /// Uncompress the first LUT index chunk and check the length
        if true {
            let thisLutChunkElementCount = min((lutChunk + 1) * lutChunkElementCount, numberOfChunks+1) - lutChunk * lutChunkElementCount
            let start = lutChunk * self.lutChunkLength - indexRangeLower / lutChunkElementCount * self.lutChunkLength
            assert(start >= 0)
            assert(start + self.lutChunkLength <= indexData.count)
            // Decompress LUT chunk
            uncompressedLut.withUnsafeMutableBufferPointer { dest in
                let _ = p4nddec64(indexDataPtr.advanced(by: start), thisLutChunkElementCount, dest.baseAddress)
            }
            //print("Initial LUT load \(uncompressedLut), \(thisLutChunkElementCount), start=\(start)")
        }
        
        /// Index data relative to startindex, needs special care because startpos==0 reads one value less
        let startPos = uncompressedLut[(chunkRangeLower - 0) % lutChunkElementCount]
        
        /// For the unlucky case that only th last value of the LUT was required, we now have to decompress the next LUT
        if (indexRangeLower + 1) / lutChunkElementCount != lutChunk {
            lutChunk = (chunkRangeLower + 1) / lutChunkElementCount
            let thisLutChunkElementCount = min((lutChunk + 1) * lutChunkElementCount, numberOfChunks+1) - lutChunk * lutChunkElementCount
            let start = lutChunk * self.lutChunkLength - indexRangeLower / lutChunkElementCount * self.lutChunkLength
            assert(start >= 0)
            assert(start + self.lutChunkLength <= indexData.count)
            // Decompress LUT chunk
            uncompressedLut.withUnsafeMutableBufferPointer { dest in
                let _ = p4nddec64(indexDataPtr.advanced(by: start), thisLutChunkElementCount, dest.baseAddress)
            }
            //print("Secondary LUT load \(uncompressedLut), \(thisLutChunkElementCount), start=\(start)")
        }
        
        var endPos = uncompressedLut[(chunkRangeLower+1) % lutChunkElementCount]
        
        var chunkIndexEnd = chunkRangeUpper
        
        /// loop to next chunk until the end is reached, consecutive reads are further appart than `io_size_merge` or the maximum read length is reached `io_size_max`
        while true {
            var next = chunkIndex + 1
            //print("next \(next)")
            if next >= chunkIndexEnd {
                guard let nextRange = get_next_chunk_position(chunkIndex: chunkIndex) else {
                    // there is no next chunk anymore, finish processing the current one and then stop with the next call
                    dataRead.nextChunkLower = 0
                    dataRead.nextChunkUpper = 0
                    break
                }
                chunkIndexEnd = nextRange.upperBound
                next = nextRange.lowerBound
            }
            guard next < indexRangeUpper else {
                dataRead.nextChunkLower = 0
                dataRead.nextChunkUpper = 0
                break
            }
            dataRead.nextChunkLower = next
            dataRead.nextChunkUpper = chunkIndexEnd
            
            let nextLutChunk = (next+1) / lutChunkElementCount
            
            /// Maybe the next LUT chunk needs to be uncompressed
            if nextLutChunk != lutChunk {
                let nextlutChunkElementCount = min((nextLutChunk + 1) * lutChunkElementCount, numberOfChunks+1) - nextLutChunk * lutChunkElementCount
                let start = nextLutChunk * self.lutChunkLength - indexRangeLower / lutChunkElementCount * self.lutChunkLength
                assert(start >= 0)
                assert(start + self.lutChunkLength <= indexData.count)
                // Decompress LUT chunk
                uncompressedLut.withUnsafeMutableBufferPointer { dest in
                    let _ = p4nddec64(indexDataPtr.advanced(by: start), nextlutChunkElementCount, dest.baseAddress)
                }
                //print("Next LUT load \(uncompressedLut), \(nextlutChunkElementCount), start=\(start)")
                //print(uncompressedLut)
                lutChunk = nextLutChunk
            }
            
            //let dataStartPos = data.advanced(by: next - indexRange.lowerBound - startOffset).pointee
            //let dataEndPos = data.advanced(by: next - indexRange.lowerBound - startOffset + 1).pointee
            
            let dataEndPos = uncompressedLut[(next+1) % lutChunkElementCount]
            
            /// Merge and split IO requests
            if dataEndPos - startPos > io_size_max,
               dataEndPos - endPos > io_size_merge {
                break
            }
            endPos = dataEndPos
            chunkIndex = next
        }
        //print("Read \(startPos)-\(endPos) (\(endPos - startPos) bytes)")
        
        dataRead.offset = Int(startPos)
        dataRead.count = Int(endPos) - Int(startPos)
        dataRead.chunkIndexUpper = chunkIndex+1
        return true
    }
    
    /// Decode multiple chunks inside `data`. Chunks are ordered strictly increasing by 1. Due to IO merging, a chunk might be read, that does not contain relevant data for the output.
    /// Returns number of processed bytes from input
    public func decode_chunks(chunkIndexLower: Int, chunkIndexUpper: Int, data: UnsafeRawPointer, into: UnsafeMutablePointer<Float>, chunkBuffer: UnsafeMutableRawPointer) -> Int {

        // Note: Relays on the correct number of uncompressed bytes from the compression library...
        // Maybe we need a differnet way that is independenet of this information
        var pos = 0
        for chunkNum in chunkIndexLower ..< chunkIndexUpper {
            //print("decompress chunk \(chunkNum), pos \(pos)")
            let uncompressedBytes = decode_chunk_into_array(chunkIndex: chunkNum, data: data.advanced(by: pos), into: into, chunkBuffer: chunkBuffer)
            pos += uncompressedBytes
        }
        return pos
    }
    
    /// Writes a chunk index into the
    /// Return number of uncompressed bytes from the data
    @discardableResult
    public func decode_chunk_into_array(chunkIndex: Int, data: UnsafeRawPointer, into: UnsafeMutablePointer<Float>, chunkBuffer: UnsafeMutableRawPointer) -> Int {
        //print("globalChunkNum=\(globalChunkNum)")
        
        var rollingMultiplty = 1
        var rollingMultiplyChunkLength = 1
        var rollingMultiplyTargetCube = 1
        
        /// Read coordinate from temporary chunk buffer
        var d = 0
        
        /// Write coordinate to output cube
        var q = 0
        
        /// Copy multiple elements from the decoded chunk into the output buffer. For long time-series this drastically improves copy performance.
        var linearReadCount = 1
        
        /// Internal state to keep track if everything is kept linear
        var linearRead = true
        
        /// Used for 2d delta coding
        var lengthLast = 0
        
        /// If no data needs to be read from this chunk, it will still be decompressed to caclculate the number of compressed bytes
        var no_data = false
        
        /// Count length in chunk and find first buffer offset position
        for i in (0..<dims.count).reversed() {
            let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
            let c0 = (chunkIndex / rollingMultiplty) % nChunksInThisDimension
            /// Number of elements in this dim in this chunk
            let length0 = min((c0+1) * chunks[i], dims[i]) - c0 * chunks[i]
            
            let chunkGlobal0Start = c0 * chunks[i]
            let chunkGlobal0End = chunkGlobal0Start + length0
            let clampedGlobal0Start = max(chunkGlobal0Start, readOffset[i])
            let clampedGlobal0End = min(chunkGlobal0End, readOffset[i] + readCount[i])
            let clampedLocal0Start = clampedGlobal0Start - c0 * chunks[i]
            //let clampedLocal0End = clampedGlobal0End - c0 * chunks[i]
            /// Numer of elements read in this chunk
            let lengthRead = clampedGlobal0End - clampedGlobal0Start
            
            if readOffset[i] + readCount[i] <= chunkGlobal0Start || readOffset[i] >= chunkGlobal0End {
                // There is no data in this chunk that should be read. This happens if IO is merged, combining mutliple read blocks.
                // The returned bytes count still needs to be computed
                //print("Not reading chunk \(globalChunkNum)")
                no_data = true
            }
            
            if i == dims.count-1 {
                lengthLast = length0
            }
            
            /// start only!
            let d0 = clampedLocal0Start
            /// Target coordinate in hyperchunk. Range `0...dim0Read`
            let t0 = chunkGlobal0Start - readOffset[i] + d0
            
            let q0 = t0 + intoCubeOffset[i]
            
            d = d + rollingMultiplyChunkLength * d0
            q = q + rollingMultiplyTargetCube * q0
            
            if i == dims.count-1 && !(lengthRead == length0 && readCount[i] == length0 && intoCubeDimension[i] == length0) {
                // if fast dimension and only partially read
                linearReadCount = lengthRead
                linearRead = false
            }
            if linearRead && lengthRead == length0 && readCount[i] == length0 && intoCubeDimension[i] == length0 {
                // dimension is read entirely
                // and can be copied linearly into the output buffer
                linearReadCount *= length0
            } else {
                // dimension is read partly, cannot merge further reads
                linearRead = false
            }
                            
            rollingMultiplty *= nChunksInThisDimension
            rollingMultiplyTargetCube *= intoCubeDimension[i]
            rollingMultiplyChunkLength *= length0
        }
        
        /// How many elements are in this chunk
        let lengthInChunk = rollingMultiplyChunkLength
        //print("lengthInChunk \(lengthInChunk), t sstart=\(d)")
        
        
        let uncompressedBytes: Int
        
        switch compression {
        case .p4nzdec256, .p4nzdec256logarithmic:
            let chunkBuffer = chunkBuffer.assumingMemoryBound(to: UInt16.self)
            let mutablePtr = UnsafeMutablePointer(mutating: data.assumingMemoryBound(to: UInt8.self))
            uncompressedBytes = p4nzdec128v16(mutablePtr, lengthInChunk, chunkBuffer)
        case .fpxdec32:
            let chunkBuffer = chunkBuffer.assumingMemoryBound(to: UInt32.self)
            let mutablePtr = UnsafeMutablePointer(mutating: data.assumingMemoryBound(to: UInt8.self))
            uncompressedBytes = fpxdec32(mutablePtr, lengthInChunk, chunkBuffer, 0)
        }
        
        //print("uncompressed bytes", uncompressedBytes, "lengthInChunk", lengthInChunk)
        
        if no_data {
            return uncompressedBytes
        }

        switch compression {
        case .p4nzdec256, .p4nzdec256logarithmic:
            let chunkBuffer = chunkBuffer.assumingMemoryBound(to: UInt16.self)
            delta2d_decode(lengthInChunk / lengthLast, lengthLast, chunkBuffer)
        case .fpxdec32:
            let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Float.self)
            delta2d_decode_xor(lengthInChunk / lengthLast, lengthLast, chunkBuffer)
        }
        
        
        /// Loop over all values need to be copied to the output buffer
        loopBuffer: while true {
            //print("read buffer from pos=\(d) and write to \(q), count=\(linearReadCount)")
            //linearReadCount=1
            
            switch compression {
            case .p4nzdec256:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: UInt16.self)
                for i in 0..<linearReadCount {
                    let val = chunkBuffer[d+i]
                    if val == Int16.max {
                        into.advanced(by: q+i).pointee = .nan
                    } else {
                        let unscaled = Float(val) / scalefactor
                        into.advanced(by: q+i).pointee = unscaled
                    }
                }
            case .fpxdec32:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Float.self)
                for i in 0..<linearReadCount {
                    into.advanced(by: q+i).pointee = chunkBuffer[d+i]
                }
            case .p4nzdec256logarithmic:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: UInt16.self)
                for i in 0..<linearReadCount {
                    let val = chunkBuffer[d+i]
                    if val == Int16.max {
                        into.advanced(by: q+i).pointee = .nan
                    } else {
                        let unscaled = powf(10, Float(val) / scalefactor) - 1
                        into.advanced(by: q+i).pointee = unscaled
                    }
                }
            }

            q += linearReadCount-1
            d += linearReadCount-1
                            
            /// Move `q` and `d` to next position
            rollingMultiplty = 1
            rollingMultiplyTargetCube = 1
            rollingMultiplyChunkLength = 1
            linearReadCount = 1
            linearRead = true
            for i in (0..<dims.count).reversed() {
                let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                let c0 = (chunkIndex / rollingMultiplty) % nChunksInThisDimension
                /// Number of elements in this dim in this chunk
                let length0 = min((c0+1) * chunks[i], dims[i]) - c0 * chunks[i]
                let chunkGlobal0Start = c0 * chunks[i]
                let chunkGlobal0End = chunkGlobal0Start + length0
                let clampedGlobal0Start = max(chunkGlobal0Start, readOffset[i])
                let clampedGlobal0End = min(chunkGlobal0End, readOffset[i] + readCount[i])
                //let clampedLocal0Start = clampedGlobal0Start - c0 * chunks[i]
                let clampedLocal0End = clampedGlobal0End - c0 * chunks[i]
                /// Numer of elements read in this chunk
                let lengthRead = clampedGlobal0End - clampedGlobal0Start
                
                /// More forward
                d += rollingMultiplyChunkLength
                q += rollingMultiplyTargetCube
                
                if i == dims.count-1 && !(lengthRead == length0 && readCount[i] == length0 && intoCubeDimension[i] == length0) {
                    // if fast dimension and only partially read
                    linearReadCount = lengthRead
                    linearRead = false
                }
                if linearRead && lengthRead == length0 && readCount[i] == length0 && intoCubeDimension[i] == length0 {
                    // dimension is read entirely
                    // and can be copied linearly into the output buffer
                    linearReadCount *= length0
                } else {
                    // dimension is read partly, cannot merge further reads
                    linearRead = false
                }
                
                let d0 = (d / rollingMultiplyChunkLength) % length0
                if d0 != clampedLocal0End && d0 != 0 {
                    break // no overflow in this dimension, break
                }
                
                d -= lengthRead * rollingMultiplyChunkLength
                q -= lengthRead * rollingMultiplyTargetCube
                
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
    
    /// Find the first chunk indices that needs to be processed. If chunks are consecutive, a range is returned.
    func initilalise_index_read() -> ChunkIndexReadInstruction {
        var chunkStart = 0
        var chunkEnd = 1
        for i in 0..<dims.count {
            // E.g. 2..<4
            let chunkInThisDimensionLower = readOffset[i] / chunks[i]
            let chunkInThisDimensionUpper = (readOffset[i] + readCount[i]).divideRoundedUp(divisor: chunks[i])
            let chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower
                            
            let firstChunkInThisDimension = chunkInThisDimensionLower
            let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
            chunkStart = chunkStart * nChunksInThisDimension + firstChunkInThisDimension
            if readCount[i] == dims[i] {
                // The entire dimension is read
                chunkEnd = chunkEnd * nChunksInThisDimension
            } else {
                // Only parts of this dimension are read
                chunkEnd = chunkStart + chunkInThisDimensionCount
            }
        }
        return ChunkIndexReadInstruction(nextChunk: chunkStart..<chunkEnd)
    }
    
    /// Find the next chunk index that should be processed to satisfy the read request. Nil if not further chunks need to be read
    func get_next_chunk_position(chunkIndex: Int) -> Range<Int>? {
        var nextChunk = chunkIndex
        
        // Move `globalChunkNum` to next position
        var rollingMultiplty = 1
        
        /// Number of consecutive chunks that can be read linearly
        var linearReadCount = 1
        
        var linearRead = true
        
        for i in (0..<dims.count).reversed() {
            // E.g. 10
            let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
            
            // E.g. 2..<4
            let chunkInThisDimensionLower = readOffset[i] / chunks[i]
            let chunkInThisDimensionUpper = (readOffset[i] + readCount[i]).divideRoundedUp(divisor: chunks[i])
            let chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower
                            
            // Move forward by one
            nextChunk += rollingMultiplty
            // Check for overflow in limited read coordinates
            
            
            if i == dims.count-1 && dims[i] != readCount[i] {
                // if fast dimension and only partially read
                linearReadCount = chunkInThisDimensionCount
                linearRead = false
            }
            if linearRead && dims[i] == readCount[i] {
                // dimension is read entirely
                linearReadCount *= nChunksInThisDimension
            } else {
                // dimension is read partly, cannot merge further reads
                linearRead = false
            }
            
            let c0 = (nextChunk / rollingMultiplty) % nChunksInThisDimension
            if c0 != chunkInThisDimensionUpper && c0 != 0 {
                break // no overflow in this dimension, break
            }
            nextChunk -= chunkInThisDimensionCount * rollingMultiplty
            rollingMultiplty *= nChunksInThisDimension
            if i == 0 {
                // All chunks have been read. End of iteration
                return nil
            }
        }
        //print("Next chunk \(nextChunk), count \(linearReadCount), from \(globalChunkNum)")
        return nextChunk ..< nextChunk + linearReadCount
    }
}
