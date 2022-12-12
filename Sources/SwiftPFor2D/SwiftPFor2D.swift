@_implementationOnly import CTurboPFor
import Foundation

public enum SwiftPFor2DError: Error {
    case cannotOpenFile(filename: String, errno: Int32, error: String)
    case cannotOpenFile(errno: Int32, error: String)
    case cannotMoveFile(from: String, to: String, errno: Int32, error: String)
    case chunkHasWrongNumberOfElements
    case dimensionOutOfBounds(range: Range<Int>, allowed: Int)
    case chunkDimensionIsSmallerThenOverallDim
    case dimensionMustBeLargerThan0
    case notAOmFile
    case fileExistsAlready(filename: String)
    case posixFallocateFailed(error: Int32)
    case ftruncateFailed(error: Int32)
}


public enum CompressionType: UInt8 {
    /// Lossy compression using 2D delta coding and scalefactor
    case p4nzdec256 = 0
    
    /// Lossless compression using 2D xor coding
    case fpxdec32 = 1
    
    ///  Similar to `p4nzdec256` but apply `log10(1+x)` before
    case p4nzdec256logarithmic = 3
    
    public var bytesPerElement: Int {
        switch self {
        case .p4nzdec256:
            fallthrough
        case .p4nzdec256logarithmic:
            return 2
        case .fpxdec32:
            return 4
        }
    }
}



/**
 Writer header:
 - 2 byte magic number
 - 1 byte version
 - 1 byte compression type with filter
 - 4 byte float scalefactor
 - 8 byte dim0 dim (slow)
 - 8 byte dom0 dim1 (fast)
 - 8 byte chunk dim0
 - 8 byte chunk dim1
 - Reserve space for reference table
 - Data block
 */
public final class OmFileWriter {
    let dim0: Int
    let dim1: Int
    
    let chunk0: Int
    let chunk1: Int
    
    var readBuffer: UnsafeMutableRawBufferPointer
    
    /// Compressed chunks are written into this buffer
    /// 8 MB write buffer or larger if chunks are very large
    var writeBuffer: UnsafeMutableBufferPointer<UInt8>
    
    public init(dim0: Int, dim1: Int, chunk0: Int, chunk1: Int) {
        self.dim0 = dim0
        self.dim1 = dim1
        self.chunk0 = chunk0
        self.chunk1 = chunk1

        let bufferSize = P4NENC256_BOUND(n: chunk0*chunk1, bytesPerElement: 4)
        
        // Read buffer needs to be a bit larger for AVX 256 bit alignment
        self.readBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: bufferSize, alignment: 4)
        
        self.writeBuffer = .allocate(capacity: max(1024 * 1024 * 8, bufferSize))
    }
    
    deinit {
        readBuffer.deallocate()
        writeBuffer.deallocate()
    }
    
    /**
     Write new or overwrite new compressed file. Data must be supplied with a closure which supplies the current position in dimension 0. Typically this is the location offset. The closure must return either an even number of elements of `chunk0 * dim1` elements or all remainig elements at once.
     
     One chunk should be around 2'000 to 16'000 elements. Fewer or more are not usefull!
     
     Note: `chunk0` can be a uneven multiple of `dim0`. E.g. for 10 location, we can use chunks of 3, so the last chunk will only cover 1 location.
     */
    public func write<Backend: OmFileWriterBackend>(fn: inout Backend, compressionType: CompressionType, scalefactor: Float, supplyChunk: (_ dim0Offset: Int) throws -> ArraySlice<Float>) throws {
        
        let nDim0Chunks = dim0.divideRoundedUp(divisor: chunk0)
        let nDim1Chunks = dim1.divideRoundedUp(divisor: chunk1)
        let nChunks = nDim0Chunks * nDim1Chunks
        
        guard chunk0 > 0 && chunk1 > 0 && dim0 > 0 && dim1 > 0 else {
            throw SwiftPFor2DError.dimensionMustBeLargerThan0
        }
        guard chunk0 <= dim0 && chunk1 <= dim1 else {
            throw SwiftPFor2DError.chunkDimensionIsSmallerThenOverallDim
        }
        
        /// Create header and write to file
        let header = OmHeader(
            compression: compressionType.rawValue,
            scalefactor: scalefactor,
            dim0: dim0,
            dim1: dim1,
            chunk0: chunk0,
            chunk1: chunk1)
        
        
        try withUnsafeBytes(of: header) { ptr in
            assert(ptr.count == OmHeader.length)
            try fn.write(contentsOf: ptr)
        }
        
        /// reserve space for chunk offsets
        try fn.write(contentsOf: Data(repeating: 0, count: nChunks * MemoryLayout<Int>.size))
        
        /// Store all byte offsets where our compressed chunks start. Later, we want to decompress chunk 1234 and know it starts at byte offset 5346545
        var chunkOffsetBytes = [Int]()
        chunkOffsetBytes.reserveCapacity(nChunks)
        
        /// Size a compressed chunk might
        let minBufferSize = P4NENC256_BOUND(n: chunk0*chunk1, bytesPerElement: compressionType.bytesPerElement)
        var writeBufferPos = 0
                
        /// itterate over all chunks
        var c0 = 0
        
        switch compressionType {
        case .p4nzdec256:
            fallthrough
        case .p4nzdec256logarithmic:
            let buffer = readBuffer.baseAddress!.assumingMemoryBound(to: Int16.self)
            while c0 < nDim0Chunks {
                // Get new data from closure
                let uncompressedInput = try supplyChunk(c0 * chunk0)
                
                // Make sure that we received an even number of `c0 * chunk0` or all remaining elements at once. The last chunk might be smaller than `c0 * chunk0`
                /// Number of elements in a row of chunks. Not just one chunk.
                let elementsPerChunkRow = chunk0 * dim1
                let missingElements = dim0 * dim1 - c0 * elementsPerChunkRow
                if missingElements < elementsPerChunkRow {
                    // For the last chunk, the number must match exactly
                    guard uncompressedInput.count == missingElements else {
                        throw SwiftPFor2DError.chunkHasWrongNumberOfElements
                    }
                }
                let isEvenMultipleOfChunkSize = uncompressedInput.count % elementsPerChunkRow == 0
                guard isEvenMultipleOfChunkSize || uncompressedInput.count == missingElements else {
                    throw SwiftPFor2DError.chunkHasWrongNumberOfElements
                }
                
                let nReadChunks = uncompressedInput.count.divideRoundedUp(divisor: elementsPerChunkRow)
                
                for c00 in 0..<nReadChunks {
                    let length0 = min((c0+c00+1) * chunk0, dim0) - (c0+c00) * chunk0
                    
                    for c1 in 0..<nDim1Chunks {
                        // load chunk into buffer
                        // consider the length, even if the last is only partial... E.g. at 1000 elements with 600 chunk length, the last one is only 400
                        let length1 = min((c1+1) * chunk1, dim1) - c1 * chunk1
                        for d0 in 0..<length0 {
                            let start = c1 * chunk1 + d0 * dim1 + c00*elementsPerChunkRow + uncompressedInput.startIndex
                            let rangeBuffer = d0*length1 ..< (d0+1)*length1
                            let rangeInput = start ..< start + length1
                            for (posBuffer, posInput) in zip(rangeBuffer, rangeInput) {
                                let val = uncompressedInput[posInput]
                                if val.isNaN {
                                    // Int16.min is not representable because of zigzag coding
                                    buffer[posBuffer] = Int16.max
                                }
                                let scaled = compressionType == .p4nzdec256logarithmic ? (log10(1+val) * scalefactor) : (val * scalefactor)
                                buffer[posBuffer] = Int16(max(Float(Int16.min), min(Float(Int16.max), round(scaled))))
                            }
                        }
                        
                        // 2D delta encoding
                        if length0 > 1/* && length0 != dx*dx*/ {
                            //print("in regular 2D")
                            for d1 in 0..<length1 {
                                for d0 in (1..<length0).reversed() {
                                    buffer[d0*length1 + d1] &-= buffer[(d0-1)*length1 + d1]
                                }
                            }
                        }
                        
                        let writeLength = p4nzenc128v16(buffer, length1 * length0, writeBuffer.baseAddress?.advanced(by: writeBufferPos))
                        
                        /// If the write buffer is too full, write it to disk. Too full means, that the next compressed chunk may not fit inside
                        writeBufferPos += writeLength
                        if (writeBuffer.count - writeBufferPos) < minBufferSize{
                            try fn.write(contentsOf: UnsafeBufferPointer(start: writeBuffer.baseAddress, count: writeBufferPos))
                            // Make sure to write to disk, otherwise we get a lot of dirty pages and overload kernel page cache
                            try fn.synchronize()
                            writeBufferPos = 0
                        }
                        
                        // Store chunk offset position in our lookup table
                        let previous = chunkOffsetBytes.last ?? 0
                        chunkOffsetBytes.append(previous + writeLength)
                    }
                }
                c0 += nReadChunks
            }
        case .fpxdec32:
            let bufferFloat = readBuffer.baseAddress!.assumingMemoryBound(to: Float.self)
            let buffer = readBuffer.baseAddress!.assumingMemoryBound(to: UInt32.self)
            while c0 < nDim0Chunks {
                // Get new data from closure
                let uncompressedInput = try supplyChunk(c0 * chunk0)
                
                // Make sure that we received an even number of `c0 * chunk0` or all remaining elements at once. The last chunk might be smaller than `c0 * chunk0`
                /// Number of elements in a row of chunks. Not just one chunk.
                let elementsPerChunkRow = chunk0 * dim1
                let missingElements = dim0 * dim1 - c0 * elementsPerChunkRow
                if missingElements < elementsPerChunkRow {
                    // For the last chunk, the number must match exactly
                    guard uncompressedInput.count == missingElements else {
                        throw SwiftPFor2DError.chunkHasWrongNumberOfElements
                    }
                }
                let isEvenMultipleOfChunkSize = uncompressedInput.count % elementsPerChunkRow == 0
                guard isEvenMultipleOfChunkSize || uncompressedInput.count == missingElements else {
                    throw SwiftPFor2DError.chunkHasWrongNumberOfElements
                }
                
                let nReadChunks = uncompressedInput.count.divideRoundedUp(divisor: elementsPerChunkRow)
                
                for c00 in 0..<nReadChunks {
                    let length0 = min((c0+c00+1) * chunk0, dim0) - (c0+c00) * chunk0
                    
                    for c1 in 0..<nDim1Chunks {
                        // load chunk into buffer
                        // consider the length, even if the last is only partial... E.g. at 1000 elements with 600 chunk length, the last one is only 400
                        let length1 = min((c1+1) * chunk1, dim1) - c1 * chunk1
                        for d0 in 0..<length0 {
                            let start = c1 * chunk1 + d0 * dim1 + c00*elementsPerChunkRow + uncompressedInput.startIndex
                            let rangeBuffer = d0*length1 ..< (d0+1)*length1
                            let rangeInput = start ..< start + length1
                            for (posBuffer, posInput) in zip(rangeBuffer, rangeInput) {
                                let val = uncompressedInput[posInput]
                                bufferFloat[posBuffer] = val
                            }
                        }
                        
                        // 2D xor encoding
                        if length0 > 1/* && length0 != dx*dx*/ {
                            //print("in regular 2D")
                            for d1 in 0..<length1 {
                                for d0 in (1..<length0).reversed() {
                                    buffer[d0*length1 + d1] ^= buffer[(d0-1)*length1 + d1]
                                }
                            }
                        }
                        
                        let writeLength = fpxenc32(buffer, length1 * length0, writeBuffer.baseAddress?.advanced(by: writeBufferPos), 0)
                        
                        /// If the write buffer is too full, write it to disk. Too full means, that the next compressed chunk may not fit inside
                        writeBufferPos += writeLength
                        if (writeBuffer.count - writeBufferPos) < minBufferSize{
                            try fn.write(contentsOf: UnsafeBufferPointer(start: writeBuffer.baseAddress, count: writeBufferPos))
                            // Make sure to write to disk, otherwise we get a lot of dirty pages and overload kernel page cache
                            try fn.synchronize()
                            writeBufferPos = 0
                        }
                        
                        // Store chunk offset position in our lookup table
                        let previous = chunkOffsetBytes.last ?? 0
                        chunkOffsetBytes.append(previous + writeLength)
                    }
                }
                c0 += nReadChunks
            }
        }
        
        
        // Write remainind data from buffer
        try fn.write(contentsOf: UnsafeBufferPointer(start: writeBuffer.baseAddress, count: writeBufferPos))
        
        //print("avg chunk size bytes", (chunkOffsetBytes.last ?? 0) / (nDim0Chunks*nDim1Chunks))
        
        // write trailing byte to allow the encoder to read with 256 bit alignment
        let trailingBytes = P4NDEC256_BOUND(n: 0, bytesPerElement: 4)
        try fn.write(contentsOf: Data(repeating: 0, count: trailingBytes))
        
        // write dictionary
        try chunkOffsetBytes.withUnsafeBufferPointer { ptr in
            try fn.write(contentsOf: ptr.toUnsafeRawBufferPointer(), atOffset: OmHeader.length)
        }
        
        // ensure data is written to disk
        try fn.synchronize()
    }
    
    /// Write new. Throw error is file exists
    public func write(file: String, compressionType: CompressionType, scalefactor: Float, supplyChunk: (_ dim0Offset: Int) throws -> ArraySlice<Float>) throws {
        if FileManager.default.fileExists(atPath: file) {
            throw SwiftPFor2DError.fileExistsAlready(filename: file)
        }
        var fn = try FileHandle.createNewFile(file: file)
        try write(fn: &fn, compressionType: compressionType, scalefactor: scalefactor, supplyChunk: supplyChunk)
    }
    
    /// Write to memory
    public func writeInMemory(compressionType: CompressionType, scalefactor: Float, supplyChunk: (_ dim0Offset: Int) throws -> ArraySlice<Float>) throws -> Data {
        var data = Data()
        try write(fn: &data, compressionType: compressionType, scalefactor: scalefactor, supplyChunk: supplyChunk)
        return data
    }
    
    /// Write all data at once without any streaming
    public func writeInMemory(compressionType: CompressionType, scalefactor: Float, all: [Float]) throws -> Data {
        return try writeInMemory(compressionType: compressionType, scalefactor: scalefactor, supplyChunk: { range in
            return ArraySlice(all)
        })
    }
    
    /// Write all data at once without any streaming
    public func write(file: String, compressionType: CompressionType, scalefactor: Float, all: [Float]) throws {
        try write(file: file, compressionType: compressionType, scalefactor: scalefactor, supplyChunk: { range in
            return ArraySlice(all)
        })
    }
}

struct OmHeader {
    /// Magic number for the file header
    let magicNumber1: UInt8 = Self.magicNumber1
    
    /// Magic number for the file header
    let magicNumber2: UInt8 = Self.magicNumber2
    
    /// Version. Version 1 was setting compression type incorrectly. Version 2 just fixes compression type.
    let version: UInt8 = Self.version
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    let compression: UInt8
    
    /// The scalefactor that is applied to all write data
    let scalefactor: Float
    
    /// Number of elements in dimension 0... The slow one
    let dim0: Int
    
    /// Number of elements in dimension 1... The fast one. E.g. time-series
    let dim1: Int
    
    /// Number of elements to chunk in dimension 0. Must be lower or equals `chunk0`
    let chunk0: Int
    
    /// Number of elements to chunk in dimension 1. Must be lower or equals `chunk1`
    let chunk1: Int
    
    /// OM header
    static var magicNumber1: UInt8 = 79
    
    /// OM header
    static var magicNumber2: UInt8 = 77
    
    /// Default version
    static var version: UInt8 = 2
    
    /// Size in bytes of the header
    static var length: Int { 40 }
}

public final class OmFileReader<Backend: OmFileReaderBackend> {
    public let fn: Backend
    
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    /// Number of elements in dimension 0... The slow one
    public let dim0: Int
    
    /// Number of elements in dimension 1... The fast one. E.g. time-series
    public let dim1: Int
    
    /// Number of elements to chunk in dimension 0. Must be lower or equals `chunk0`
    public let chunk0: Int
    
    /// Number of elements to chunk in dimension 1. Must be lower or equals `chunk1`
    public let chunk1: Int
    
    public init(fn: Backend) throws {
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
        scalefactor = header.scalefactor
        // bug in version 1: compression type was random
        compression = header.version == 1 ? .p4nzdec256 : CompressionType(rawValue: header.compression)!
    }
    
    /// Prefetch fhe required data regions into memory
    public func willNeed(dim0Slow dim0Read: Range<Int>, dim1 dim1Read: Range<Int>) throws {
        guard fn.needsPrefetch else {
            return
        }
        
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
            
            for c0 in dim0Read.lowerBound / chunk0 ..< dim0Read.upperBound.divideRoundedUp(divisor: chunk0) {
                for c1 in dim1Read.lowerBound / chunk1 ..< dim1Read.upperBound.divideRoundedUp(divisor: chunk1) {
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
    
    /// Read data into existing buffers
    public func read(into: UnsafeMutablePointer<Float>, arrayRange: Range<Int>, chunkBuffer: UnsafeMutableRawPointer, dim0Slow dim0Read: Range<Int>, dim1 dim1Read: Range<Int>) throws {
        
        guard dim0Read.lowerBound >= 0 && dim0Read.lowerBound <= dim0 && dim0Read.upperBound <= dim0 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim0Read, allowed: dim0)
        }
        guard dim1Read.lowerBound >= 0 && dim1Read.lowerBound <= dim1 && dim1Read.upperBound <= dim1 else {
            throw SwiftPFor2DError.dimensionOutOfBounds(range: dim1Read, allowed: dim1)
        }
        
        let nDim0Chunks = dim0.divideRoundedUp(divisor: chunk0)
        let nDim1Chunks = dim1.divideRoundedUp(divisor: chunk1)
        
        let nChunks = nDim0Chunks * nDim1Chunks
        fn.withUnsafeBytes { ptr in
            let chunkOffsets = ptr.assumingMemoryBound(to: UInt8.self).baseAddress!.advanced(by: OmHeader.length).assumingMemoryBound(to: Int.self, capacity: nChunks)
            
            let compressedDataStartOffset = OmHeader.length + nChunks * MemoryLayout<Int>.stride
            let compressedDataStartPtr = UnsafeMutablePointer(mutating: ptr.assumingMemoryBound(to: UInt8.self).baseAddress!.advanced(by: compressedDataStartOffset))
            
            switch compression {
            case.p4nzdec256logarithmic:
                fallthrough
            case .p4nzdec256:
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Int16.self)
                for c0 in dim0Read.lowerBound / chunk0 ..< dim0Read.upperBound.divideRoundedUp(divisor: chunk0) {
                    for c1 in dim1Read.lowerBound / chunk1 ..< dim1Read.upperBound.divideRoundedUp(divisor: chunk1) {
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
                        let uncompressedBytes = p4nzdec128v16(compressedDataStartPtr.advanced(by: startPos), length0 * length1, chunkBuffer)
                        precondition(uncompressedBytes == lengthCompressedBytes)
                        
                        // 2D delta decoding
                        if length0 > 1 {
                            for d1 in 0..<length1 {
                                for d0 in (1..<length0) {
                                    chunkBuffer[d0*length1 + d1] &+= chunkBuffer[(d0-1)*length1 + d1]
                                }
                            }
                        }
                        
                        /// Moved to local coordinates... e.g. 50..<350
                        let clampedLocal0 = clampedGlobal0.substract(c0 * chunk0)
                        let clampedLocal1 = clampedGlobal1.substract(c1 * chunk1)
                        
                        for d0 in clampedLocal0 {
                            let read = clampedLocal1.add(d0 * length1)
                            
                            let localOut0 = chunkGlobal0.lowerBound + d0 - dim0Read.lowerBound
                            let localOut1 = clampedGlobal1.substract(dim1Read.lowerBound)
                            let localRange = localOut1.add(localOut0 * dim1Read.count + arrayRange.lowerBound)
                            
                            for (posBuffer, posOut) in zip(read, localRange) {
                                let val = chunkBuffer[posBuffer]
                                if val == Int16.max {
                                    into.advanced(by: posOut).pointee = .nan
                                } else {
                                    let unscaled = compression == .p4nzdec256logarithmic ? (powf(10, Float(val) / scalefactor) - 1) : (Float(val) / scalefactor)
                                    into.advanced(by: posOut).pointee = unscaled
                                }
                            }
                        }
                    }
                }
            case .fpxdec32:
                let chunkBufferUInt = chunkBuffer.assumingMemoryBound(to: UInt32.self)
                let chunkBuffer = chunkBuffer.assumingMemoryBound(to: Float.self)
                
                for c0 in dim0Read.lowerBound / chunk0 ..< dim0Read.upperBound.divideRoundedUp(divisor: chunk0) {
                    for c1 in dim1Read.lowerBound / chunk1 ..< dim1Read.upperBound.divideRoundedUp(divisor: chunk1) {
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
                        let uncompressedBytes = fpxdec32(compressedDataStartPtr.advanced(by: startPos), length0 * length1, chunkBufferUInt, 0)
                        precondition(uncompressedBytes == lengthCompressedBytes)
                        
                        // 2D xor decoding
                        if length0 > 1 {
                            for d1 in 0..<length1 {
                                for d0 in (1..<length0) {
                                    chunkBufferUInt[d0*length1 + d1] ^= chunkBufferUInt[(d0-1)*length1 + d1]
                                }
                            }
                        }
                        
                        /// Moved to local coordinates... e.g. 50..<350
                        let clampedLocal0 = clampedGlobal0.substract(c0 * chunk0)
                        let clampedLocal1 = clampedGlobal1.substract(c1 * chunk1)
                        
                        for d0 in clampedLocal0 {
                            let read = clampedLocal1.add(d0 * length1)
                            
                            let localOut0 = chunkGlobal0.lowerBound + d0 - dim0Read.lowerBound
                            let localOut1 = clampedGlobal1.substract(dim1Read.lowerBound)
                            let localRange = localOut1.add(localOut0 * dim1Read.count + arrayRange.lowerBound)
                            
                            for (posBuffer, posOut) in zip(read, localRange) {
                                let val = chunkBuffer[posBuffer]
                                into.advanced(by: posOut).pointee = val
                            }
                        }
                    }
                }
            }
        }
    }
}

extension OmFileReader where Backend == MmapFile {
    public convenience init(file: String) throws {
        let fn = try FileHandle.openFileReading(file: file)
        let mmap = try MmapFile(fn: fn)
        try self.init(fn: mmap)
    }
    
    /// Check if the file was deleted on the file system. Linux keep the file alive, as long as some processes have it open.
    public func wasDeleted() -> Bool {
        fn.wasDeleted()
    }
}
