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
    public var buffer: UnsafeMutableRawBufferPointer
        
    public var writePosition = UInt64(0)
    
    public var totalBytesWritten = UInt64(0)
    
    public init(capacity: UInt64) {
        self.writePosition = 0
        self.totalBytesWritten = 0
        self.buffer = .allocate(byteCount: Int(capacity), alignment: 1)
    }
    
    /// How many bytes are left in the write buffer
    var remainingCapacity: UInt64 {
        return UInt64(buffer.count) - (writePosition)
    }
    
    /// A pointer to the current write position
    var bufferAtWritePosition: UnsafeMutableRawPointer {
        return buffer.baseAddress!.advanced(by: Int(writePosition))
    }
    
    /// Ensure the buffer has at least a minimum capacity
    public func reallocate(minimumCapacity: UInt64) {
        if remainingCapacity >= minimumCapacity {
            return
        }
        buffer = UnsafeMutableRawBufferPointer(start: realloc(buffer.baseAddress, Int(minimumCapacity)), count: Int(minimumCapacity))
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
        reallocate(minimumCapacity: 3)
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
        reallocate(minimumCapacity: UInt64(json.count))
        
        let jsonLength = json.withUnsafeBytes({
            memcpy(buffer.baseAddress!.advanced(by: Int(writePosition)), $0.baseAddress!, $0.count)
            return UInt64($0.count)
        })
        writePosition += jsonLength
        totalBytesWritten += jsonLength
        
        // TODO Pad to 64 bit?
        // TODO Additional version field and maybe some reserved stuff. E.g. if the JSON payload should be compressed later.
        
        // write length of JSON
        reallocate(minimumCapacity: 8)
        buffer.baseAddress!.advanced(by: Int(writePosition)).assumingMemoryBound(to: Int.self)[0] = Int(jsonLength)
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
    public let scale_factor: Float
    
    /// The offset that is applied to all write data
    public let add_offset: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    public let compression: CompressionType
    
    public let datatype: DataType
    
    /// The dimensions of the file
    let dimensions: [UInt64]
    
    /// How the dimensions are chunked
    let chunks: [UInt64]
    
    let chunkBufferSize: UInt64
    
    let chunkBuffer: UnsafeMutableRawBufferPointer
    
    /// `lutChunkElementCount` should be 256 for production files. Only for testing a lower number can be used.
    public init(dimensions: [UInt64], chunkDimensions: [UInt64], compression: CompressionType, datatype: DataType, scale_factor: Float, add_offset: Float, lutChunkElementCount: Int = 256) {

        assert(dimensions.count == chunkDimensions.count)
        
        self.chunks = chunkDimensions
        self.dimensions = dimensions
        self.compression = compression
        self.datatype = datatype
        self.scale_factor = scale_factor
        self.add_offset = add_offset
        
        // Note: The encoder keeps the pointer to `&self.dimensions`. It is important that this array is not deallocated!
        self.encoder = om_encoder_t()
        om_encoder_init(&encoder, scale_factor, add_offset, compression.toC(), datatype.toC(), &self.dimensions, &self.chunks, UInt64(dimensions.count), UInt64(lutChunkElementCount))

        /// Number of total chunks in the compressed files
        let nChunks = om_encoder_number_of_chunks(&encoder)
        
        /// This is the minimum output buffer size for each compressed size. In practice the buffer should be much larger.
        self.chunkBufferSize = om_encoder_compress_chunk_buffer_size(&encoder)
        
        /// Each thread needs its own chunk buffer to compress data. This implementation is single threaded
        self.chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(chunkBufferSize), alignment: 1)
        
        /// Allocate space for a lookup table. Needs to be number_of_chunks+1 to store start address and for each chunk then end address
        self.lookUpTable = .init(repeating: 0, count: Int(nChunks + 1))
    }
    
    /// Compress data
    /// Can be all, a single or multiple chunks. If mutliple chunks are given at once, they must align with chunks.
    public func writeData<FileHandle: OmFileWriterBackend>(array: [Float], arrayDimensions: [UInt64], arrayRead: [Range<UInt64>], fn: FileHandle, out: OmFileWriter2) throws {
        // TODO check dimensions of arrayDimensions and arrayRead
        
        let arrayOffset = arrayRead.map({UInt64($0.lowerBound)})
        let arrayCount = arrayRead.map({UInt64($0.count)})
        
        /// For performance the output buffer should be able to hold a multiple of the chunk buffer size
        out.reallocate(minimumCapacity: chunkBufferSize * 4)
        
        /// How many chunks can be written to the output. This could be only a single one, or multiple
        let numberOfChunksInArray = om_encoder_number_of_chunks_in_array(&encoder, arrayCount)
        
        if chunkIndex == 0 {
            // Store data start address
            lookUpTable[chunkIndex] = out.totalBytesWritten
        }
        
        // This loop could be done in parallel. However, the order of chunks must remain the same in the LUT and final output buffer.
        // For multithreading, multiple buffers are required that need to be copied into the final buffer afterwards
        for chunkIndexOffsetInThisArray in 0..<numberOfChunksInArray {
            assert(out.remainingCapacity >= chunkBufferSize)
            let bytes_written = om_encoder_compress_chunk(&encoder, array, arrayDimensions, arrayOffset, arrayCount, UInt64(chunkIndex), chunkIndexOffsetInThisArray, out.bufferAtWritePosition, chunkBuffer.baseAddress)

            out.writePosition += UInt64(bytes_written)
            out.totalBytesWritten += UInt64(bytes_written)
            
            // Store chunk offset in LUT
            lookUpTable[chunkIndex+1] = out.totalBytesWritten
            chunkIndex += 1
            
            // Write buffer to disk if the next chunk may not fit anymore in the output buffer
            if out.remainingCapacity < chunkBufferSize {
                try fn.write(contentsOf: out.buffer[0..<Int(out.writePosition)].map({$0}))
                out.writePosition = 0
            }
        }
    }
    
    /// Returns LUT size
    public func writeLut(out: OmFileWriter2, fn: FileHandle) throws -> UInt64 {
        /// The size of the total compressed LUT including some padding
        let buffer_size = om_encoder_compress_lut_buffer_size(&encoder, lookUpTable, UInt64(lookUpTable.count))
        out.reallocate(minimumCapacity: buffer_size)
        
        /// Compress the LUT and return the actual compressed LUT size
        let compressed_lut_size = om_encoder_compress_lut(&encoder, lookUpTable, UInt64(lookUpTable.count), out.bufferAtWritePosition, buffer_size)
        
        out.writePosition += UInt64(compressed_lut_size)
        out.totalBytesWritten += UInt64(compressed_lut_size)
        
        try fn.write(contentsOf: out.buffer[0..<Int(out.writePosition)].map({$0}))
        out.writePosition = 0
        return UInt64(compressed_lut_size)
    }
    
    deinit {
        chunkBuffer.deallocate()
    }
}
