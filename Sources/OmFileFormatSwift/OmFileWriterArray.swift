//
//  OmFileWriter2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 29.10.2024.
//

import Foundation
@_implementationOnly import OmFileFormatC

/// Writes om file header and trailer
public final class OmFileWriter2 {
    /// Write header. Only magic number and version 3
    static public func writeHeader(buffer: OmWriteBuffer) {
        buffer.reallocate(minimumCapacity: 3)
        buffer.bufferAtWritePosition.assumingMemoryBound(to: UInt8.self).pointee = OmHeader.magicNumber1
        buffer.incrementWritePosition(by: 1)
        buffer.bufferAtWritePosition.assumingMemoryBound(to: UInt8.self).pointee = OmHeader.magicNumber2
        buffer.incrementWritePosition(by: 1)
        buffer.bufferAtWritePosition.assumingMemoryBound(to: UInt8.self).pointee = 3 // version
        buffer.incrementWritePosition(by: 1)
    }
    
    static public func writeTrailer(buffer: OmWriteBuffer, meta: OmFileJSON) throws {
        // Serialise and write JSON
        let json = try JSONEncoder().encode(meta)
        buffer.reallocate(minimumCapacity: UInt64(json.count))
        let jsonLength = json.withUnsafeBytes({
            memcpy(buffer.bufferAtWritePosition, $0.baseAddress!, $0.count)
            return UInt64($0.count)
        })
        buffer.incrementWritePosition(by: jsonLength)
        
        // TODO Pad to 64 bit?
        // TODO Additional version field and maybe some reserved stuff. E.g. if the JSON payload should be compressed later.
        
        // write length of JSON
        buffer.reallocate(minimumCapacity: 8)
        buffer.bufferAtWritePosition.assumingMemoryBound(to: Int.self)[0] = Int(jsonLength)
        buffer.incrementWritePosition(by: 8)
    }
}

/// Compress a single variable inside an om file. A om file may contain mutliple variables
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
    /// It is important that this function can write data out to a FileHandle to empty the buffer. Otherwise the buffer could grow to multiple gigabytes
    public func writeData<FileHandle: OmFileWriterBackend>(array: [Float], arrayDimensions: [UInt64], arrayRead: [Range<UInt64>], fn: FileHandle, out: OmWriteBuffer) throws {
        assert(zip(arrayDimensions, arrayRead).allSatisfy { $1.upperBound <= $0 })
        
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

            out.incrementWritePosition(by: UInt64(bytes_written))
            
            // Store chunk offset in LUT
            lookUpTable[chunkIndex+1] = out.totalBytesWritten
            chunkIndex += 1
            
            // Write buffer to disk if the next chunk may not fit anymore in the output buffer
            if out.remainingCapacity < chunkBufferSize {
                try out.writeToFile(fn: fn)
            }
        }
    }
    
    /// Returns LUT size
    /// TODO the compressed LUT might be big. Consider breaking it up into a loop
    public func writeLut(out: OmWriteBuffer) -> UInt64 {
        /// The size of the total compressed LUT including some padding
        let buffer_size = om_encoder_compress_lut_buffer_size(&encoder, lookUpTable, UInt64(lookUpTable.count))
        out.reallocate(minimumCapacity: buffer_size)
        
        /// Compress the LUT and return the actual compressed LUT size
        let compressed_lut_size = om_encoder_compress_lut(&encoder, lookUpTable, UInt64(lookUpTable.count), out.bufferAtWritePosition, buffer_size)
        out.incrementWritePosition(by: compressed_lut_size)
        return UInt64(compressed_lut_size)
    }
    
    deinit {
        chunkBuffer.deallocate()
    }
}
