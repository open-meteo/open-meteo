//
//  OmFileWriter2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 29.10.2024.
//

import Foundation
@_implementationOnly import OmFileFormatC

/// All data is written to this buffer. It needs to be emptied periodically after writing large chunks of data.
public final class OmFileWriter2 {
    /// All data is written to this buffer. The current offset is in `writeBufferPos`. This buffer must be written out before it is full.
    public var buffer: UnsafeMutableBufferPointer<UInt8>
        
    public var writePosition = UInt64(0)
    
    public var totalBytesWritten = UInt64(0)
    
    /// Total capacity
    public let capacity: UInt64
    
    public init(capacity: UInt64) {
        self.writePosition = 0
        self.totalBytesWritten = 0
        self.capacity = capacity
        self.buffer = .allocate(capacity: Int(capacity))
    }
    
    public func writeHeader<FileHandle: OmFileWriterBackend>(fn: FileHandle) throws {
        writeHeader()
        try fn.write(contentsOf: buffer[0..<Int(writePosition)].map({$0}))
        writePosition = 0
    }
    
    public func writeTrailer<FileHandle: OmFileWriterBackend>(meta: OmFileJSON, fn: FileHandle) throws {
        try writeTrailer(meta: meta)
        try fn.write(contentsOf: buffer[0..<Int(writePosition)].map({$0}))
        writePosition = 0
    }
    
    deinit {
        buffer.deallocate()
    }
    
    /// Write header. Only magic number and version 3
    public func writeHeader() {
        assert(capacity - writePosition >= 3)
        buffer[Int(writePosition) + 0] = OmHeader.magicNumber1
        buffer[Int(writePosition) + 1] = OmHeader.magicNumber2
        buffer[Int(writePosition) + 2] = 3
        writePosition += 3
        totalBytesWritten += 3
    }
    
    /// Serialise JSON, write to buffer and write size of JSON
    public func writeTrailer(meta: OmFileJSON) throws {
        //print(meta)
        
        // Serialise and write JSON
        let json = try JSONEncoder().encode(meta)
        assert(capacity - writePosition >= json.count)
        let jsonLength = json.withUnsafeBytes({
            memcpy(buffer.baseAddress!.advanced(by: Int(writePosition)), $0.baseAddress!, $0.count)
            return UInt64($0.count)
        })
        writePosition += jsonLength
        totalBytesWritten += jsonLength
        
        // TODO Pad to 64 bit?
        // TODO Additional version field and maybe some reserved stuff. E.g. if the JSON payload should be compressed later.
        
        // write length of JSON
        assert(capacity - writePosition >= 8)
        buffer.baseAddress!.advanced(by: Int(writePosition)).assumingMemoryBound(to: Int.self, capacity: 1)[0] = Int(jsonLength)
        writePosition += 8
        totalBytesWritten += 8
    }
}

public final class OmFileWriterArray {
    /// Store all byte offsets where our compressed chunks start. Later, we want to decompress chunk 1234 and know it starts at byte offset 5346545
    private var lookUpTable: [UInt64]
    
    var encoder: om_encoder_t
    
    /// Position of last chunk that has been written
    public var chunkIndex: Int = 0
    
    /// The scalefactor that is applied to all write data
    public let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    public let datatype: DataType
    
    /// The dimensions of the file
    let dimensions: [UInt64]
    
    /// How the dimensions are chunked
    let chunks: [UInt64]
    
    /**
     Write new or overwrite new compressed file. Data must be supplied with a closure which supplies the current position in dimension 0. Typically this is the location offset. The closure must return either an even number of elements of `chunk0 * dim1` elements or all remainig elements at once.
     
     One chunk should be around 2'000 to 16'000 elements. Fewer or more are not usefull!
     
     Note: `chunk0` can be a uneven multiple of `dim0`. E.g. for 10 location, we can use chunks of 3, so the last chunk will only cover 1 location.
     */
    public init(dimensions: [UInt64], chunkDimensions: [UInt64], compression: CompressionType, datatype: DataType, scalefactor: Float, lutChunkElementCount: Int = 256) {
        
        /*let chunkSizeByte = chunkDimensions.reduce(1, *) * 4
        if chunkSizeByte > 1024 * 1024 * 4 {
            print("WARNING: Chunk size greater than 4 MB (\(Float(chunkSizeByte) / 1024 / 1024) MB)!")
        }*/
        
        
        
        var encoder = om_encoder_t()
        
        // TODO Remove alloc. Scope could be an issue for arrays!!!!
        let ptrDims = UnsafeMutablePointer<UInt64>.allocate(capacity: dimensions.count * 2)
        let ptrChunks = UnsafeMutablePointer<UInt64>.allocate(capacity: dimensions.count * 2)
        
        for i in 0..<dimensions.count {
            ptrDims[i] = dimensions[i]
            ptrChunks[i] = chunkDimensions[i]
        }
        om_encoder_init(&encoder, scalefactor, compression.toC(), datatype.toC(), ptrDims, ptrChunks, UInt64(dimensions.count), UInt64(lutChunkElementCount))
        self.encoder = encoder

        
        let nChunks = om_encoder_number_of_chunks(&encoder)
        
        // +1 to store also the start address
        self.lookUpTable = .init(repeating: 0, count: Int(nChunks + 1))
        self.chunks = chunkDimensions
        self.dimensions = dimensions
        self.compression = compression
        self.datatype = datatype
        self.scalefactor = scalefactor
    }
    
    /// Compress data
    /// Can be all, a single or multiple chunks. If mutliple chunks are given at once, they must align with chunks.
    public func writeData<FileHandle: OmFileWriterBackend>(array: [Float], arrayDimensions: [UInt64], arrayRead: [Range<UInt64>], fn: FileHandle, out: OmFileWriter2) throws {
        // TODO check dimensions of arrayDimensions and arrayRead
        
        let arrayOffset = arrayRead.map({UInt64($0.lowerBound)})
        let arrayCount = arrayRead.map({UInt64($0.count)})
        
        let numberOfChunksInArray = om_encoder_number_of_chunks_in_array(&encoder, arrayCount)
        
        /// This is the minimum output buffer size for each compressed size. In practice the buffer should be a couple of MB.
        let minimumBuffer = Int(om_encoder_minimum_chunk_write_buffer(&encoder))
        
        // Each thread needs its own chunk buffer to compress data
        let chunkBufferSize = Int(om_encoder_chunk_buffer_size(&encoder))
        let chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: chunkBufferSize, alignment: 1)
        defer {
            chunkBuffer.deallocate()
        }
        
        if chunkIndex == 0 {
            // Store data start address
            lookUpTable[chunkIndex] = out.totalBytesWritten
        }
        
        // This loop could be done in parallel. However, the order of chunks must remain the same in the LUT and final output buffer.
        // For multithreading, multiple buffers are required that need to be copied into the final buffer afterwards
        for chunkIndexOffsetInThisArray in 0..<numberOfChunksInArray {
            let outPtr = out.buffer.baseAddress!.advanced(by: Int(out.writePosition))
            let outSize = out.buffer.count - Int(out.writePosition)
            assert(outSize >= minimumBuffer)
            let writeLength = om_encoder_compress_chunk(&encoder, array, arrayDimensions, arrayOffset, arrayCount, UInt64(chunkIndex), chunkIndexOffsetInThisArray, outPtr, UInt64(outSize), chunkBuffer.baseAddress)

            //print("compressed size", writeLength, "lengthInChunk", lengthInChunk, "start offset", totalBytesWritten)
            out.writePosition += UInt64(writeLength)
            out.totalBytesWritten += UInt64(writeLength)
            
            // Store chunk offset in LUT
            lookUpTable[chunkIndex+1] = out.totalBytesWritten
            chunkIndex += 1
            
            // Write buffer to disk if the next chunk may not fit anymore in the output buffer
            if out.buffer.count - Int(out.writePosition) < minimumBuffer {
                try fn.write(contentsOf: out.buffer[0..<Int(out.writePosition)].map({$0}))
                out.writePosition = 0
            }
        }
    }
    
    /// Returns LUT size
    public func writeLut(out: OmFileWriter2, fn: FileHandle) throws -> UInt64 {
        let size_of_compressed_lut = om_encoder_size_of_compressed_lut(&encoder, lookUpTable, UInt64(lookUpTable.count))
        assert(out.buffer.count - Int(out.writePosition) >= Int(size_of_compressed_lut))
        om_encoder_compress_lut(&encoder, lookUpTable, UInt64(lookUpTable.count), out.buffer.baseAddress!.advanced(by: Int(out.writePosition)), size_of_compressed_lut)
        
        out.writePosition += UInt64(size_of_compressed_lut)
        out.totalBytesWritten += UInt64(size_of_compressed_lut)
        
        try fn.write(contentsOf: out.buffer[0..<Int(out.writePosition)].map({$0}))
        out.writePosition = 0
        return UInt64(size_of_compressed_lut)
    }
    

    func output_buffer_capacity() -> UInt64 {
        om_encoder_output_buffer_capacity(&encoder)
    }
}
