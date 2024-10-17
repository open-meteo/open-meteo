@_implementationOnly import CTurboPFor
@_implementationOnly import CHelper
import Foundation

/// All data is written to this buffer. It needs to be emptied periodically after writing large chunks of data.
/// TODO consider reallocation strategy when migrating to C
public final class OmFileBufferedWriter {
    /// All data is written to this buffer. The current offset is in `writeBufferPos`. This buffer must be written out before it is full.
    public var buffer: UnsafeMutableBufferPointer<UInt8>
        
    public var writePosition = 0
    
    public var totalBytesWritten = 0
    
    /// Total capacity
    public let capacity: Int
    
    public init(capacity: Int) {
        self.writePosition = 0
        self.totalBytesWritten = 0
        self.capacity = capacity
        self.buffer = .allocate(capacity: capacity)
    }
    
    public func writeHeader<FileHandle: OmFileWriterBackend>(fn: FileHandle) throws {
        writeHeader()
        try fn.write(contentsOf: buffer[0..<writePosition].map({$0}))
        writePosition = 0
    }
    
    public func writeTrailer<FileHandle: OmFileWriterBackend>(meta: OmFileJSON, fn: FileHandle) throws {
        try writeTrailer(meta: meta)
        try fn.write(contentsOf: buffer[0..<writePosition].map({$0}))
        writePosition = 0
    }
    
    deinit {
        buffer.deallocate()
    }
    
    /// Write header. Onnly magic number and version 3
    public func writeHeader() {
        assert(capacity - writePosition >= 3)
        buffer[writePosition + 0] = OmHeader.magicNumber1
        buffer[writePosition + 1] = OmHeader.magicNumber2
        buffer[writePosition + 2] = 3
        writePosition += 3
        totalBytesWritten += 3
    }
    
    /// Serialise JSON, write to buffer and write size of JSON
    public func writeTrailer(meta: OmFileJSON) throws {
        print(meta)
        
        // Serialise and write JSON
        let json = try JSONEncoder().encode(meta)
        assert(capacity - writePosition >= json.count)
        let jsonLength = json.withUnsafeBytes({
            memcpy(buffer.baseAddress!.advanced(by: writePosition), $0.baseAddress!, $0.count)
            return $0.count
        })
        writePosition += jsonLength
        totalBytesWritten += jsonLength
        
        // write length of JSON
        assert(capacity - writePosition >= 8)
        buffer.baseAddress!.advanced(by: writePosition).assumingMemoryBound(to: Int.self, capacity: 1)[0] = jsonLength
        writePosition += 8
        totalBytesWritten += 8
    }
}

/// The meta data block should have a "variables" array
public struct OmFileJSON: Codable {
    let variables: [OmFileJSONVariable]
    let someAttributes: String?
}

/// Technically can have any attributes
public struct OmFileJSONVariable: Codable {
    let name: String?
    let dimensions: [Int]
    let chunks: [Int]
    let dimensionNames: [String]?
    let scalefactor: Float
    let compression: CompressionType
    let dataOffset: Int
    let lutOffset: Int
    let lutChunkSize: Int
}


/// Write an om file and write multiple chunks of data
public final class OmFileEncoder {
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    /// The dimensions of the file
    let dims: [Int]
    
    /// How the dimensions are chunked
    let chunks: [Int]
    
    /// Store all byte offsets where our compressed chunks start. Later, we want to decompress chunk 1234 and know it starts at byte offset 5346545
    private var chunkOffsetBytes: [Int]
    
    /// Buffer where chunks are moved to, before compression them. => input for compression call
    private var chunkBuffer: UnsafeMutableRawBufferPointer
    
    /// Position of last chunk that has been written
    public var chunkIndex: Int = 0

    /// This might be hard coded to 256 in later versions
    let lutChunkElementCount: Int
    
    /// Return the total number of chunks in this file
    func number_of_chunks() -> Int {
        var n = 1
        for i in 0..<dims.count {
            n *= dims[i].divideRoundedUp(divisor: chunks[i])
        }
        return n
    }
    
    func maximum_buffer_capacity() -> Int {
        let bufferSize = P4NENC256_BOUND(n: chunks.reduce(1, *), bytesPerElement: 4)
        return bufferSize
    }
    
    /**
     Write new or overwrite new compressed file. Data must be supplied with a closure which supplies the current position in dimension 0. Typically this is the location offset. The closure must return either an even number of elements of `chunk0 * dim1` elements or all remainig elements at once.
     
     One chunk should be around 2'000 to 16'000 elements. Fewer or more are not usefull!
     
     Note: `chunk0` can be a uneven multiple of `dim0`. E.g. for 10 location, we can use chunks of 3, so the last chunk will only cover 1 location.
     */
    public init(dimensions: [Int], chunkDimensions: [Int], compression: CompressionType, scalefactor: Float, lutChunkElementCount: Int = 256) {
        var nChunks = 1
        for i in 0..<dimensions.count {
            nChunks *= dimensions[i].divideRoundedUp(divisor: chunkDimensions[i])
        }
        
        let chunkSizeByte = chunkDimensions.reduce(1, *) * 4
        if chunkSizeByte > 1024 * 1024 * 4 {
            print("WARNING: Chunk size greater than 4 MB (\(Float(chunkSizeByte) / 1024 / 1024) MB)!")
        }
        
        self.chunkOffsetBytes = .init(repeating: 0, count: nChunks)
        self.dims = dimensions
        self.chunks = chunkDimensions
        self.scalefactor = scalefactor
        self.compression = compression
        
        let bufferSize = P4NENC256_BOUND(n: chunkDimensions.reduce(1, *), bytesPerElement: 4)
        
        // Read buffer needs to be a bit larger for AVX 256 bit alignment
        self.chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 4)
        self.lutChunkElementCount = lutChunkElementCount
    }
    

    /*public func writeTrailer<FileHandle: OmFileWriterBackend>(fn: FileHandle, out: OmFileBufferedWriter) throws {
        self.writeTrailer(out: out)
        try fn.write(contentsOf: out.buffer[0..<out.writePosition].map({$0}))
        out.writePosition = 0
    }*/
    /// Can be all, a single or multiple chunks
    public func writeData<FileHandle: OmFileWriterBackend>(array: [Float], arrayDimensions: [Int], arrayRead: [Range<Int>], fn: FileHandle, out: OmFileBufferedWriter) throws {
        // TODO check dimensions of arrayDimensions and arrayRead
        
        var numberOfChunksInArray = 1
        for i in 0..<dims.count {
            numberOfChunksInArray *= arrayRead[i].count.divideRoundedUp(divisor: chunks[i])
        }
        
        var q: Int? = 0
        while let qIn = q {
            q = writeNextChunks(array: array, arrayDimensions: arrayDimensions, arrayOffset: arrayRead.map({$0.lowerBound}), arrayCount: arrayRead.map({$0.count}), cOffset: qIn, numberOfChunksInArray: numberOfChunksInArray, out: out)
            try fn.write(contentsOf: out.buffer[0..<out.writePosition].map({$0}))
            out.writePosition = 0
        }
    }
    
    /// Write header, data and trailer
    /*public func write<FileHandle: OmFileWriterBackend>(array: [Float], arrayDimensions: [Int], arrayRead: [Range<Int>], fn: FileHandle, out: OmFileBufferedWriter) throws {
        try out.writeHeader(fn: fn)
        try writeData(array: array, arrayDimensions: arrayDimensions, arrayRead: arrayRead, fn: fn, out: out)
        try writeTrailer(fn: fn, out: out)
    }*/
    
    public func writeLut(out: OmFileBufferedWriter, fn: FileHandle) throws -> Int {
        let lutChunkLength = writeLut(out: out)
        try fn.write(contentsOf: out.buffer[0..<out.writePosition].map({$0}))
        out.writePosition = 0
        return lutChunkLength
    }
    
    /// Returns LUT chunk length
    public func writeLut(out: OmFileBufferedWriter) -> Int {
        //let lutStart = out.totalBytesWritten
        //print("LUT start \(lutStart), \(chunkOffsetBytes)")
        let lutChunkLength = chunkOffsetBytes.withUnsafeBytes({
            var maxLength = 0
            
            /// Calculate maximum chunk size
            for i in 0..<chunkOffsetBytes.count.divideRoundedUp(divisor: lutChunkElementCount) {
                let rangeStart = i*lutChunkElementCount
                let rangeEnd = min((i+1)*lutChunkElementCount, chunkOffsetBytes.count)
                let len = p4ndenc64(UnsafeMutablePointer(mutating: $0.baseAddress?.advanced(by: rangeStart*8).assumingMemoryBound(to: UInt64.self)), rangeEnd-rangeStart, out.buffer.baseAddress!.advanced(by: out.writePosition))
                if len > maxLength { maxLength = len }
            }
            /// Write chunks to buffer and pad all chunks to have `maxLength` bytes
            for i in 0..<chunkOffsetBytes.count.divideRoundedUp(divisor: lutChunkElementCount) {
                let rangeStart = i*lutChunkElementCount
                let rangeEnd = min((i+1)*lutChunkElementCount, chunkOffsetBytes.count)
                _ = p4ndenc64(UnsafeMutablePointer(mutating: $0.baseAddress?.advanced(by: rangeStart*8).assumingMemoryBound(to: UInt64.self)), rangeEnd-rangeStart, out.buffer.baseAddress!.advanced(by: out.writePosition))
                out.writePosition += maxLength
                out.totalBytesWritten += maxLength
            }
            //print("Index size", $0.count, " bytes compressed to ", maxLength*chunkOffsetBytes.count.divideRoundedUp(divisor: lutChunkElementCount))
            return maxLength
        })
        return lutChunkLength
    }
    
    /*public func writeTrailer(out: OmFileBufferedWriter) {
        let lutStart = out.totalBytesWritten
        let lutChunkLength = writeLut(out: out)
        
        // TODO: pad to 64 bit?
        
        let len2 = dims.withUnsafeBytes({
            memcpy(out.buffer.baseAddress!.advanced(by: out.writePosition), $0.baseAddress!, $0.count)
            return $0.count
        })
        out.writePosition += len2
        out.totalBytesWritten += len2
        
        let len3 = chunks.withUnsafeBytes({
            memcpy(out.buffer.baseAddress!.advanced(by: out.writePosition), $0.baseAddress!, $0.count)
            return $0.count
        })
        out.writePosition += len3
        out.totalBytesWritten += len3
        
        // n dimensions
        out.buffer.baseAddress!.advanced(by: out.writePosition).assumingMemoryBound(to: Int.self, capacity: 1)[0] = dims.count
        out.writePosition += 8
        out.totalBytesWritten += 8
        
        // TODO scalefactor, version, magic number
        
        // LUT chunk size
        out.buffer.baseAddress!.advanced(by: out.writePosition).assumingMemoryBound(to: Int.self, capacity: 1)[0] = lutChunkLength
        out.writePosition += 8
        out.totalBytesWritten += 8
        
        // LUT start offset
        out.buffer.baseAddress!.advanced(by: out.writePosition).assumingMemoryBound(to: Int.self, capacity: 1)[0] = lutStart
        out.writePosition += 8
        out.totalBytesWritten += 8
        
        // TODO LUT compressed chunk size
    }*/
    
    /// Data must be exactly of the size of the next chunk or chunks!
    /// Return true if all inpupt data base been processed
    ///
    /// `cOffset=0` if chunks are feed one by one
    /// Otherwise `cOffset` is incremented while looping over a large array
    public func writeNextChunks(array: [Float], arrayDimensions: [Int], arrayOffset: [Int], arrayCount: [Int], cOffset: Int, numberOfChunksInArray: Int, out: OmFileBufferedWriter) -> Int? {
        assert(array.count == arrayDimensions.reduce(1, *))
        
        var cOffset = cOffset
        
        while true {
            // Calculate number of elements in this chunk
            var rollingMultiplty = 1
            var rollingMultiplyChunkLength = 1
            var rollingMultiplyTargetCube = 1
            
            /// Read coordinate from input array
            var readCoordinate = 0
            
            /// Position to write to in the chunk buffer
            var writeCoordinate = 0
            
            /// Copy multiple elements from the decoded chunk into the output buffer. For long time-series this drastically improves copy performance.
            var linearReadCount = 1
            
            /// Internal state to keep track if everything is kept linear
            var linearRead = true
            
            /// Used for 2d delta coding
            var lengthLast = 0
            
            /// Count length in chunk and find first buffer offset position
            for i in (0..<dims.count).reversed() {
                let nChunksInThisDimension = dims[i].divideRoundedUp(divisor: chunks[i])
                let c0 = (chunkIndex / rollingMultiplty) % nChunksInThisDimension
                let c0Offset = (cOffset / rollingMultiplty) % nChunksInThisDimension
                let length0 = min((c0+1) * chunks[i], dims[i]) - c0 * chunks[i]
                //let chunkGlobal0 = c0 * chunks[i] ..< c0 * chunks[i] + length0
                //let clampedGlobal0 = chunkGlobal0//.clamped(to: dimRead[i])
                //let clampedLocal0 = clampedGlobal0.substract(c0 * chunks[i])
                
                if i == dims.count-1 {
                    lengthLast = length0
                }

                readCoordinate = readCoordinate + rollingMultiplyTargetCube * (c0Offset * chunks[i] + arrayOffset[i])
                //print("i", i, "arrayRead[i].count", arrayRead[i].count, "length0", length0, "arrayDimensions[i]", arrayDimensions[i])
                assert(length0 <= arrayCount[i])
                assert(length0 <= arrayDimensions[i])
                if i == dims.count-1 && !(arrayCount[i] == length0 && arrayDimensions[i] == length0) {
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
            loopBuffer: while true {
                //print("q=\(q) d=\(d), count=\(linearReadCount)")
                //linearReadCount = 1
                
                switch compression {
                case .p4nzdec256:
                    let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Int16.self)
                    for i in 0..<linearReadCount {
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
                    for i in 0..<linearReadCount {
                        assert(readCoordinate+i < array.count)
                        assert(writeCoordinate+i < lengthInChunk)
                        chunkBuffer[writeCoordinate+i] = array[readCoordinate+i]
                    }
                case .p4nzdec256logarithmic:
                    let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Int16.self)
                    for i in 0..<linearReadCount {
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
                

                readCoordinate += linearReadCount-1
                writeCoordinate += linearReadCount-1
                writeCoordinate += 1
                
                // Move `q` to next position
                rollingMultiplyTargetCube = 1
                linearRead = true
                linearReadCount = 1
                for i in (0..<dims.count).reversed() {
                    let qPos = ((readCoordinate / rollingMultiplyTargetCube) % arrayDimensions[i] - arrayOffset[i]) / chunks[i]
                    let length0 = min((qPos+1) * chunks[i], arrayCount[i]) - qPos * chunks[i]
                    
                    /// More forward
                    readCoordinate += rollingMultiplyTargetCube
                    
                    if i == dims.count-1 && !(arrayCount[i] == length0 && arrayDimensions[i] == length0) {
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
                    let q0 = ((readCoordinate / rollingMultiplyTargetCube) % arrayDimensions[i] - arrayOffset[i]) % chunks[i]
                    if q0 != 0 && q0 != length0 {
                        break // no overflow in this dimension, break
                    }
                    readCoordinate -= length0 * rollingMultiplyTargetCube
                    
                    rollingMultiplyTargetCube *= arrayDimensions[i]
                    if i == 0 {
                        // All chunks have been read. End of iteration
                        break loopBuffer
                    }
                }
            }
            
            // 2D coding and compression
            let writeLength: Int
            let minimumBuffer: Int
            switch compression {
            case .p4nzdec256, .p4nzdec256logarithmic:
                minimumBuffer = P4NENC256_BOUND(n: lengthInChunk, bytesPerElement: 4)
                assert(out.buffer.count - out.writePosition >= minimumBuffer)
                /// TODO check delta encoding if done correctly
                delta2d_encode(lengthInChunk / lengthLast, lengthLast, chunkBuffer.assumingMemoryBound(to: Int16.self).baseAddress)
                writeLength = p4nzenc128v16(chunkBuffer.assumingMemoryBound(to: UInt16.self).baseAddress!, lengthInChunk, out.buffer.baseAddress!.advanced(by: out.writePosition))
            case .fpxdec32:
                minimumBuffer = P4NENC256_BOUND(n: lengthInChunk, bytesPerElement: 4)
                assert(out.buffer.count - out.writePosition >= minimumBuffer)
                delta2d_encode_xor(lengthInChunk / lengthLast, lengthLast, chunkBuffer.assumingMemoryBound(to: Float.self).baseAddress)
                writeLength = fpxenc32(chunkBuffer.assumingMemoryBound(to: UInt32.self).baseAddress!, lengthInChunk, out.buffer.baseAddress!.advanced(by: out.writePosition), 0)
            }

            //print("compressed size", writeLength, "lengthInChunk", lengthInChunk, "start offset", totalBytesWritten)
            out.writePosition += writeLength
            out.totalBytesWritten += writeLength
            
            // Store chunk offset in LUT
            chunkOffsetBytes[chunkIndex] = out.totalBytesWritten
            chunkIndex += 1
            cOffset += 1
            
            //print("cOffset", cOffset, "number_of_chunks_in_array", number_of_chunks_in_array)
            if cOffset == numberOfChunksInArray {
                return nil
            }
            
            // Return to caller if the next chunk would not fit into the buffer
            if out.buffer.count - out.writePosition <= minimumBuffer {
                return cOffset
            }
        }
    }
    
    deinit {
        chunkBuffer.deallocate()
    }
}

