@_implementationOnly import OmFileFormatC
@_implementationOnly import CHelper
import Foundation


/// Encodes a single variable to an OpenMeteo file
/// Mutliple variables may be encoded in the single file
///
/// This file currenly allocates a chunk buffer and LUT table. This might change if this is moved to C
struct OmFileEncoder {
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    /// The dimensions of the file
    let dimensions: [UInt64]
    
    /// How the dimensions are chunked
    let chunks: [UInt64]

    /// This might be hard coded to 256 in later versions
    let lutChunkElementCount: Int
    
    /// Return the total number of chunks in this file
    func number_of_chunks() -> UInt64 {
        var n = UInt64(1)
        for i in 0..<dimensions.count {
            n *= dimensions[i].divideRoundedUp(divisor: chunks[i])
        }
        return n
    }
    
    func chunk_buffer_size() -> UInt64 {
        return UInt64(P4NENC256_BOUND(n: Int(chunks.reduce(1, *)), bytesPerElement: compression.bytesPerElement))
    }
    
    func minimum_chunk_write_buffer() -> UInt64 {
        return UInt64(P4NENC256_BOUND(n: Int(number_of_chunks()), bytesPerElement: compression.bytesPerElement))
    }
    
    /// Calculate the size of the output buffer.
    func output_buffer_capacity() -> UInt64 {
        let bufferSize = UInt64(P4NENC256_BOUND(n: Int(chunks.reduce(1, *)), bytesPerElement: compression.bytesPerElement))
        
        var nChunks = UInt64(1)
        for i in 0..<dimensions.count {
            nChunks *= dimensions[i].divideRoundedUp(divisor: chunks[i])
        }
        /// Assume the lut buffer is not compressible
        let lutBufferSize = nChunks * 8
        
        return max(4096, max(lutBufferSize, bufferSize))
    }
    
    func number_of_chunks_in_array(arrayCount: [UInt64]) -> UInt64 {
        var numberOfChunksInArray = UInt64(1)
        for i in 0..<dimensions.count {
            numberOfChunksInArray *= arrayCount[i].divideRoundedUp(divisor: chunks[i])
        }
        return numberOfChunksInArray
    }
    
    /// Return the size of the compressed LUT
    func size_of_compressed_lut(lookUpTable: [UInt64]) -> Int {
        /// TODO stack allocate in C
        let bufferSize = P4NENC256_BOUND(n: 256, bytesPerElement: 8)
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 1)
        defer { buffer.deallocate() }
        
        let nLutChunks = lookUpTable.count.divideRoundedUp(divisor: lutChunkElementCount)
        
        return lookUpTable.withUnsafeBytes({
            var maxLength = 0
            /// Calculate maximum chunk size
            for i in 0..<nLutChunks {
                let rangeStart = i*lutChunkElementCount
                let rangeEnd = min((i+1)*lutChunkElementCount, lookUpTable.count)
                let len = p4ndenc64(UnsafeMutablePointer(mutating: $0.baseAddress?.advanced(by: rangeStart*8).assumingMemoryBound(to: UInt64.self)), rangeEnd-rangeStart, buffer.baseAddress!)
                if len > maxLength { maxLength = len }
            }
            return maxLength * nLutChunks
        })
    }
    
    /// Out size needs to cover at least `size_of_compressed_lut()`
    /// Returns length of each lut chunk
    func compress_lut(lookUpTable: [UInt64], out: UnsafeMutablePointer<UInt8>, size_of_compressed_lut: Int) {
        let nLutChunks = lookUpTable.count.divideRoundedUp(divisor: lutChunkElementCount)
        let lutChunkLength = size_of_compressed_lut / nLutChunks
        
        lookUpTable.withUnsafeBytes({
            /// Write chunks to buffer and pad all chunks to have `maxLength` bytes
            for i in 0..<nLutChunks {
                let rangeStart = i*lutChunkElementCount
                let rangeEnd = min((i+1)*lutChunkElementCount, lookUpTable.count)
                _ = p4ndenc64(UnsafeMutablePointer(mutating: $0.baseAddress?.advanced(by: rangeStart*8).assumingMemoryBound(to: UInt64.self)), rangeEnd-rangeStart, out.advanced(by: i * lutChunkLength))
            }
        })
    }
    
    
    /// Write a single chunk
    /// `chunkIndex` is the chunk numer of the global array
    /// `chunkIndexInThisArray` is the chunk index offset, if the current array contains more than one chunk
    /// Return the number of compressed bytes into out
    @inlinable public func writeSingleChunk(array: [Float], arrayDimensions: [UInt64], arrayOffset: [UInt64], arrayCount: [UInt64], chunkIndex: UInt64, chunkIndexOffsetInThisArray: UInt64, out: UnsafeMutablePointer<UInt8>, outSize: Int, chunkBuffer: UnsafeMutableRawBufferPointer) -> Int {
        
        // Calculate number of elements in this chunk
        var rollingMultiplty = UInt64(1)
        var rollingMultiplyChunkLength = UInt64(1)
        var rollingMultiplyTargetCube = UInt64(1)
        
        /// Read coordinate from input array
        var readCoordinate = Int(0)
        
        /// Position to write to in the chunk buffer
        var writeCoordinate = Int(0)
        
        /// Copy multiple elements from the decoded chunk into the output buffer. For long time-series this drastically improves copy performance.
        var linearReadCount = UInt64(1)
        
        /// Internal state to keep track if everything is kept linear
        var linearRead = true
        
        /// Used for 2d delta coding
        var lengthLast = UInt64(0)
        
        /// Count length in chunk and find first buffer offset position
        for i in (0..<dimensions.count).reversed() {
            let nChunksInThisDimension = dimensions[i].divideRoundedUp(divisor: chunks[i])
            let c0 = (UInt64(chunkIndex) / rollingMultiplty) % nChunksInThisDimension
            let c0Offset = (chunkIndexOffsetInThisArray / rollingMultiplty) % nChunksInThisDimension
            let length0 = min((c0+1) * chunks[i], dimensions[i]) - c0 * chunks[i]
            //let chunkGlobal0 = c0 * chunks[i] ..< c0 * chunks[i] + length0
            //let clampedGlobal0 = chunkGlobal0//.clamped(to: dimRead[i])
            //let clampedLocal0 = clampedGlobal0.substract(c0 * chunks[i])
            
            if i == dimensions.count-1 {
                lengthLast = length0
            }

            readCoordinate = readCoordinate + Int(rollingMultiplyTargetCube * (c0Offset * chunks[i] + arrayOffset[i]))
            //print("i", i, "arrayRead[i].count", arrayRead[i].count, "length0", length0, "arrayDimensions[i]", arrayDimensions[i])
            assert(length0 <= arrayCount[i])
            assert(length0 <= arrayDimensions[i])
            if i == dimensions.count-1 && !(arrayCount[i] == length0 && arrayDimensions[i] == length0) {
                // if fast dimension and only partially read
                linearReadCount = length0
                linearRead = false
            }
            if linearRead && arrayCount[i] == length0 && arrayDimensions[i] == length0 {
                // dimension is read entirely
                // and can be copied linearly into the output buffer
                linearReadCount *= length0
            } else {
                // dimension is read partly, cannot merge further reads
                linearRead = false
            }
       
            rollingMultiplty *= nChunksInThisDimension
            rollingMultiplyTargetCube *= arrayDimensions[i]
            rollingMultiplyChunkLength *= length0
        }
        
        /// How many elements are in this chunk
        let lengthInChunk = rollingMultiplyChunkLength
        
        //print("compress chunk \(chunkIndex) lengthInChunk \(lengthInChunk)")
        
        // loop over elements to read and move to target buffer. Apply scalefactor and convert UInt16
        while true {
            //print("q=\(q) d=\(d), count=\(linearReadCount)")
            //linearReadCount = 1
            
            switch compression {
            case .p4nzdec256:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Int16.self)
                for i in 0..<Int(linearReadCount) {
                    assert(readCoordinate+i < array.count)
                    assert(writeCoordinate+i < lengthInChunk)
                    let val = array[readCoordinate+i]
                    if val.isNaN {
                        // Int16.min is not representable because of zigzag coding
                        chunkBuffer[writeCoordinate+i] = Int16.max
                    }
                    let scaled = val * scalefactor
                    chunkBuffer[writeCoordinate+i] = Int16(max(Float(Int16.min), min(Float(Int16.max), round(scaled))))
                }
            case .fpxdec32:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Float.self)
                for i in 0..<Int(linearReadCount) {
                    assert(readCoordinate+i < array.count)
                    assert(writeCoordinate+i < lengthInChunk)
                    chunkBuffer[writeCoordinate+i] = array[readCoordinate+i]
                }
            case .p4nzdec256logarithmic:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Int16.self)
                for i in 0..<Int(linearReadCount) {
                    assert(readCoordinate+i < array.count)
                    assert(writeCoordinate+i < lengthInChunk)
                    let val = array[readCoordinate+i]
                    if val.isNaN {
                        // Int16.min is not representable because of zigzag coding
                        chunkBuffer[writeCoordinate+i] = Int16.max
                    }
                    let scaled = log10(1+val) * scalefactor
                    chunkBuffer[writeCoordinate+i] = Int16(max(Float(Int16.min), min(Float(Int16.max), round(scaled))))
                }
            }
            

            readCoordinate += Int(linearReadCount)-1
            writeCoordinate += Int(linearReadCount)-1
            writeCoordinate += 1
            
            // Move `q` to next position
            rollingMultiplyTargetCube = 1
            linearRead = true
            linearReadCount = 1
            for i in (0..<dimensions.count).reversed() {
                let qPos = ((UInt64(readCoordinate) / rollingMultiplyTargetCube) % arrayDimensions[i] - arrayOffset[i]) / chunks[i]
                let length0 = min((qPos+1) * chunks[i], arrayCount[i]) - qPos * chunks[i]
                
                /// More forward
                readCoordinate += Int(rollingMultiplyTargetCube)
                
                if i == dimensions.count-1 && !(arrayCount[i] == length0 && arrayDimensions[i] == length0) {
                    // if fast dimension and only partially read
                    linearReadCount = length0
                    linearRead = false
                }
                if linearRead && arrayCount[i] == length0 && arrayDimensions[i] == length0 {
                    // dimension is read entirely
                    // and can be copied linearly into the output buffer
                    linearReadCount *= length0
                } else {
                    // dimension is read partly, cannot merge further reads
                    linearRead = false
                }
                let q0 = ((UInt64(readCoordinate) / rollingMultiplyTargetCube) % arrayDimensions[i] - arrayOffset[i]) % chunks[i]
                if q0 != 0 && q0 != length0 {
                    break // no overflow in this dimension, break
                }
                readCoordinate -= Int(length0 * rollingMultiplyTargetCube)
                
                rollingMultiplyTargetCube *= arrayDimensions[i]
                if i == 0 {
                    // All values have been loaded into chunk buffer. Proceed to compression
                    // 2D coding and compression
                    let writeLength: Int
                    let minimumBuffer: Int
                    switch compression {
                    case .p4nzdec256, .p4nzdec256logarithmic:
                        minimumBuffer = P4NENC256_BOUND(n: Int(lengthInChunk), bytesPerElement: 4)
                        assert(outSize >= minimumBuffer)
                        /// TODO check delta encoding if done correctly
                        delta2d_encode(Int(lengthInChunk / lengthLast), Int(lengthLast), chunkBuffer.assumingMemoryBound(to: Int16.self).baseAddress)
                        writeLength = p4nzenc128v16(chunkBuffer.assumingMemoryBound(to: UInt16.self).baseAddress!, Int(lengthInChunk), out)
                    case .fpxdec32:
                        minimumBuffer = P4NENC256_BOUND(n: Int(lengthInChunk), bytesPerElement: 4)
                        assert(outSize >= minimumBuffer)
                        delta2d_encode_xor(Int(lengthInChunk / lengthLast), Int(lengthLast), chunkBuffer.assumingMemoryBound(to: Float.self).baseAddress)
                        writeLength = fpxenc32(chunkBuffer.assumingMemoryBound(to: UInt32.self).baseAddress!, Int(lengthInChunk), out, 0)
                    }
                    return writeLength
                }
            }
        }
    }
}

