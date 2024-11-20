//
//  OmFileWriter2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 29.10.2024.
//

import Foundation
@_implementationOnly import OmFileFormatC

public struct OffsetSize {
    let offset: UInt64
    let size: UInt64
    
    var cOffsetSize: OmOffsetSize_t {
        return OmOffsetSize_t(offset: offset, size: size)
    }
}

/// Writes om file header and trailer
public struct OmFileWriter2<FileHandle: OmFileWriterBackend> {
    let buffer: OmWriteBuffer;
    
    let fn: FileHandle
    
    init(fn: FileHandle, bufferCapacity: Int) {
        self.buffer = OmWriteBuffer(capacity: bufferCapacity)
        self.fn = fn
        
        /// Write header
        let size = om_write_header_size()
        buffer.reallocate(minimumCapacity: size)
        om_write_header(buffer.bufferAtWritePosition)
        buffer.incrementWritePosition(by: size)
    }
    
    public func write<OmType: OmFileScalarDataTypeProtocol>(value: OmType, name: String, children: [OffsetSize]) -> OffsetSize {
        var name = name
        return name.withUTF8{ name in
            guard name.count <= UInt16.max else { fatalError() }
            guard children.count <= UInt32.max else { fatalError() }
            let type = OmType.dataTypeScalar.toC()
            let size = om_variable_write_scalar_size(UInt16(name.count), UInt32(children.count), type)
            buffer.alignTo64Bytes()
            buffer.reallocate(minimumCapacity: Int(size))
            let childrenSize = children.map{$0.size}
            let childrenOffset = children.map{$0.offset}
            var value = value
            withUnsafePointer(to: &value, { value in
                om_variable_write_scalar(buffer.bufferAtWritePosition, UInt16(name.count), UInt32(children.count), childrenSize, childrenOffset, name.baseAddress, type, value)
            })
            let offset = buffer.totalBytesWritten
            buffer.incrementWritePosition(by: size)
            return OffsetSize(offset: UInt64(offset), size: UInt64(size))
        }
    }
    
    public func prepareArray<OmType: OmFileArrayDataTypeProtocol>(type: OmType.Type, dimensions: [UInt64], chunkDimensions: [UInt64], compression: CompressionType, scale_factor: Float, add_offset: Float, lutChunkElementCount: UInt64 = 256) -> OmFileWriterArray<OmType, FileHandle> {
        return .init(dimensions: dimensions, chunkDimensions: chunkDimensions, compression: compression, scale_factor: scale_factor, add_offset: add_offset, buffer: buffer, fn: fn, lutChunkElementCount: lutChunkElementCount)
    }
    
    public func write(array: OmFileWriterArrayFinalisd, name: String, children: [OffsetSize]) -> OffsetSize {
        guard array.dimensions.count == array.chunks.count else {
            fatalError()
        }
        var name = name
        return name.withUTF8{ name in
            guard name.count <= UInt16.max else { fatalError() }
            let size = om_variable_write_numeric_array_size(UInt16(name.count), UInt32(children.count), UInt64(array.dimensions.count))
            buffer.alignTo64Bytes()
            buffer.reallocate(minimumCapacity: Int(size))
            let childrenSize = children.map{$0.size}
            let childrenOffset = children.map{$0.offset}
            let dimensions = array.dimensions.map{UInt64($0)}
            let chunks = array.chunks.map{UInt64($0)}
            om_variable_write_numeric_array(buffer.bufferAtWritePosition, UInt16(name.count), UInt32(children.count), childrenSize, childrenOffset, name.baseAddress, array.datatype.toC(), array.compression.toC(), array.scale_factor, array.add_offset, UInt64(dimensions.count), dimensions, chunks, UInt64(array.lutSize), UInt64(array.lutOffset))
            let offset = buffer.totalBytesWritten
            buffer.incrementWritePosition(by: size)
            return OffsetSize(offset: UInt64(offset), size: UInt64(size))
        }
    }
    
    public func writeTrailer(rootVariable: OffsetSize) throws {
        buffer.alignTo64Bytes()
        
        // write length of JSON
        let size = om_write_trailer_size()
        buffer.reallocate(minimumCapacity: size)
        om_write_trailer(buffer.bufferAtWritePosition, rootVariable.cOffsetSize)
        buffer.incrementWritePosition(by: size)
        
        // Flush
        try buffer.writeToFile(fn: fn)
    }
}

/// Compress a single variable inside an om file. A om file may contain mutliple variables
public final class OmFileWriterArray<OmType: OmFileArrayDataTypeProtocol, FileHandle: OmFileWriterBackend> {
    /// Store all byte offsets where our compressed chunks start. Later, we want to decompress chunk 1234 and know it starts at byte offset 5346545
    private var lookUpTable: [UInt64]
    
    private var encoder: OmEncoder_t
    
    /// Position of last chunk that has been written
    var chunkIndex: Int = 0
    
    /// The scalefactor that is applied to all write data
    let scale_factor: Float
    
    /// The offset that is applied to all write data
    let add_offset: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    let compression: CompressionType
    
    /// The dimensions of the file
    let dimensions: [UInt64]
    
    /// How the dimensions are chunked
    let chunks: [UInt64]
    
    let compressedChunkBufferSize: UInt64
    
    let chunkBuffer: UnsafeMutableRawBufferPointer
    
    /// Temporaly write data here. Keeps als track of `totalBytesWritten`
    let buffer: OmWriteBuffer
    
    /// Final backing storage
    let fn: FileHandle
    
    /// `lutChunkElementCount` should be 256 for production files. Only for testing a lower number can be used.
    public init(dimensions: [UInt64], chunkDimensions: [UInt64], compression: CompressionType, scale_factor: Float, add_offset: Float, buffer: OmWriteBuffer, fn: FileHandle, lutChunkElementCount: UInt64 = 256) {

        assert(dimensions.count == chunkDimensions.count)
        
        self.chunks = chunkDimensions
        self.dimensions = dimensions
        self.compression = compression
        self.scale_factor = scale_factor
        self.add_offset = add_offset
        
        // Note: The encoder keeps the pointer to `&self.dimensions`. It is important that this array is not deallocated!
        self.encoder = OmEncoder_t()
        let error = OmEncoder_init(&encoder, scale_factor, add_offset, compression.toC(), OmType.dataTypeArray.toC(), &self.dimensions, &self.chunks, UInt64(dimensions.count), lutChunkElementCount)
        
        guard error == ERROR_OK else {
            fatalError("Om encoder: \(String(cString: OmError_string(error)))")
        }

        /// Number of total chunks in the compressed files
        let nChunks = OmEncoder_countChunks(&encoder)
        
        /// This is the minimum output buffer size for each compressed size. In practice the buffer should be much larger.
        self.compressedChunkBufferSize = OmEncoder_compressedChunkBufferSize(&encoder)
        
        let chunkBufferSize = OmEncoder_chunkBufferSize(&encoder)
        
        /// Each thread needs its own chunk buffer to compress data. This implementation is single threaded
        self.chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(chunkBufferSize), alignment: 1)
        
        /// Allocate space for a lookup table. Needs to be number_of_chunks+1 to store start address and for each chunk then end address
        self.lookUpTable = .init(repeating: 0, count: Int(nChunks) + 1)
        
        self.buffer = buffer
        self.fn = fn
    }
    
    /// Compress data and write it to file. Can be all, a single or multiple chunks. If mutliple chunks are given at once, they must align with chunks.
    /// `arrayDimensions` specify the total dimensions of the input array
    /// `arrayRead` specify which parts of this array should be read
    /// It is important that this function can write data out to a FileHandle to empty the buffer. Otherwise the buffer could grow to multiple gigabytes
    public func writeData(array: [OmType], arrayDimensions: [UInt64], arrayRead: [Range<UInt64>]) throws {
        assert(array.count == arrayDimensions.reduce(1, *))
        assert(arrayDimensions.allSatisfy({$0 >= 0}))
        assert(arrayRead.allSatisfy({$0.lowerBound >= 0}))
        assert(zip(arrayDimensions, arrayRead).allSatisfy { $1.upperBound <= $0 })
        
        let arrayOffset = arrayRead.map({$0.lowerBound})
        let arrayCount = arrayRead.map({UInt64($0.count)})
        
        /// For performance the output buffer should be able to hold a multiple of the chunk buffer size
        buffer.reallocate(minimumCapacity: Int(compressedChunkBufferSize) * 4)
        
        /// How many chunks can be written to the output. This could be only a single one, or multiple
        let numberOfChunksInArray = OmEncoder_countChunksInArray(&encoder, arrayCount)
        
        /// Store data start address if this is the first time this read is called
        if chunkIndex == 0 {
            lookUpTable[chunkIndex] = UInt64(buffer.totalBytesWritten)
        }
        
        // This loop could be done in parallel. However, the order of chunks must remain the same in the LUT and final output buffer.
        // For multithreading, multiple buffers are required that need to be copied into the final buffer afterwards
        for chunkIndexOffsetInThisArray in 0..<numberOfChunksInArray {
            assert(buffer.remainingCapacity >= compressedChunkBufferSize)
            let bytes_written = array.withUnsafeBytes { array in
                return OmEncoder_compressChunk(&encoder, array.baseAddress, arrayDimensions, arrayOffset, arrayCount, UInt64(chunkIndex), chunkIndexOffsetInThisArray, buffer.bufferAtWritePosition, chunkBuffer.baseAddress)
            }

            buffer.incrementWritePosition(by: Int(bytes_written))
            
            // Store chunk offset in LUT
            lookUpTable[chunkIndex+1] = UInt64(buffer.totalBytesWritten)
            chunkIndex += 1
            
            // Write buffer to disk if the next chunk may not fit anymore in the output buffer
            if buffer.remainingCapacity < compressedChunkBufferSize {
                try buffer.writeToFile(fn: fn)
            }
        }
    }
    
    /// Compress the lookup table and write it to the output buffer
    public func finalise() -> OmFileWriterArrayFinalisd {
        let lut_offset = buffer.totalBytesWritten
        
        /// The size of the total compressed LUT including some padding
        let buffer_size = OmEncoder_lutBufferSize(&encoder, lookUpTable, UInt64(lookUpTable.count))
        buffer.reallocate(minimumCapacity: Int(buffer_size))
        
        /// Compress the LUT and return the actual compressed LUT size
        let compressed_lut_size = OmEncoder_compressLut(&encoder, lookUpTable, UInt64(lookUpTable.count), buffer.bufferAtWritePosition, buffer_size)
        buffer.incrementWritePosition(by: Int(compressed_lut_size))
        return OmFileWriterArrayFinalisd(
            scale_factor: scale_factor,
            add_offset: add_offset,
            compression: compression,
            datatype: OmType.dataTypeArray,
            dimensions: dimensions,
            chunks: chunks,
            lutSize: compressed_lut_size,
            lutOffset: UInt64(lut_offset)
        )
    }
    
    deinit {
        chunkBuffer.deallocate()
    }
}

/// Attributes of an compressed array that had been written and now contains LUT size and offset
public struct OmFileWriterArrayFinalisd {
    /// The scalefactor that is applied to all write data
    let scale_factor: Float
    
    /// The offset that is applied to all write data
    let add_offset: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    let compression: CompressionType
    
    let datatype: DataType
    
    /// The dimensions of the file
    let dimensions: [UInt64]
    
    /// How the dimensions are chunked
    let chunks: [UInt64]
    
    let lutSize: UInt64
    
    let lutOffset: UInt64
}
