//
//  OmFileReader2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 19.10.2024.
//

import Foundation
@_implementationOnly import OmFileFormatC

extension OmFileReaderBackend {
    /// Read and decode
    func decode(decoder: UnsafePointer<om_decoder_t>, into: UnsafeMutableRawPointer, chunkBuffer: UnsafeMutableRawPointer) {
        self.withUnsafeBytes({ ptr in
            var indexRead = om_decoder_index_read_t()
            om_decoder_index_read_init(decoder, &indexRead)
            
            /// Loop over index blocks and read index data
            while om_decoder_next_index_read(decoder, &indexRead) {
                //print("read index \(indexRead)")
                let indexData = ptr.baseAddress!.advanced(by: Int(indexRead.offset))
                
                var dataRead = om_decoder_data_read_t()
                om_decoder_data_read_init(&dataRead, &indexRead)
                
                /// Loop over data blocks and read compressed data chunks
                while om_decoder_next_data_read(decoder, &dataRead, indexData, indexRead.count) {
                    //print("read data \(dataRead)")
                    let dataData = ptr.baseAddress!.advanced(by: Int(dataRead.offset))
                    
                    let _ = om_decoder_decode_chunks(decoder, dataRead.chunkIndex, dataData, dataRead.count, into, chunkBuffer)
                }
            }
        })
    }
}

/// High level implementation to read an OpenMeteo file
/// Decodes meta data which may include JSON
/// Handles actual file reads. The current implementation just uses MMAP or plain memory.
/// Later implementations may use async read operations
struct OmFileReader2<Backend: OmFileReaderBackend> {
    let fn: Backend
    
    let json: OmFileJSON
    
    /// Number of elements in index LUT chunk. Might be hardcoded to 256 later. `1` signals old version 1/2 file without a compressed LUT.
    let lutChunkElementCount: UInt64
        
    /// Open a file and decode om file meta data. In this casem fn is typically mmap or just plain memory
    public static func open_file(fn: Backend, lutChunkElementCount: UInt64 = 256) throws -> Self {
        return try fn.withUnsafeBytes({ptr in
            // TODO Support for old files. Read header and check for old file
            guard ptr[0] == OmHeader.magicNumber1, ptr[1] == OmHeader.magicNumber2 else {
                fatalError("Not an OM file")
            }
            let version = ptr.baseAddress!.advanced(by: 2).assumingMemoryBound(to: UInt8.self).pointee
            if version == 1 || version == 2 {
                let metaV1 = ptr.baseAddress!.assumingMemoryBound(to: OmHeader.self)
                let variable = OmFileJSONVariable(
                    name: "data",
                    dimensions: [UInt64(metaV1.pointee.dim0), UInt64(metaV1.pointee.dim1)],
                    chunks: [UInt64(metaV1.pointee.chunk0), UInt64(metaV1.pointee.chunk1)],
                    dimension_names: nil,
                    scale_factor: metaV1.pointee.scalefactor,
                    add_offset: 0,
                    compression: .init(UInt32(metaV1.pointee.compression)),
                    data_type: DATA_TYPE_FLOAT,
                    lut_offset: UInt64(OmHeader.length),
                    lut_size: 0 // ignored if lutChunkElementCount == 1
                )
                let json = OmFileJSON(variables: [variable], someAttributes: nil)
                return OmFileReader2(fn: fn, json: json, lutChunkElementCount: 1)
            }
            
            if version != 3 {
                fatalError("Unknown version \(version)")
            }
            
            // Version 2 files below use JSON meta data
            let fileSize = fn.count
            /// The last 8 bytes of the file are the size of the JSON payload
            let jsonLength = ptr.baseAddress!.advanced(by: fileSize - 8).assumingMemoryBound(to: Int.self).pointee
            let jsonData = Data(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: (ptr.baseAddress!.advanced(by: fileSize - 8 - jsonLength))),
                count: jsonLength,
                deallocator: .none
            )
            let json = try JSONDecoder().decode(OmFileJSON.self, from: jsonData)
            return OmFileReader2(
                fn: fn,
                json: json,
                lutChunkElementCount: lutChunkElementCount
            )
        })
    }
    
    /// Read the first variable from a OM file
    public func read(into: UnsafeMutableRawPointer, dimRead: [Range<UInt64>], intoCubeOffset: [UInt64], intoCubeDimension: [UInt64], io_size_max: UInt64 = 65536, io_size_merge: UInt64 = 512) {
        let v = self.json.variables[0]
        let nDimensions = v.dimensions.count
        assert(dimRead.count == nDimensions)
        assert(intoCubeOffset.count == nDimensions)
        assert(intoCubeDimension.count == nDimensions)
        
        let readOffset = dimRead.map({UInt64($0.lowerBound)})
        let readCount = dimRead.map({UInt64($0.count)})
        
        var decoder = om_decoder_t()
        om_decoder_init(
            &decoder,
            v.scale_factor,
            v.compression,
            v.data_type,
            UInt64(v.dimensions.count),
            v.dimensions,
            v.chunks,
            readOffset,
            readCount,
            intoCubeOffset,
            intoCubeDimension,
            v.lut_size,
            lutChunkElementCount,
            v.lut_offset,
            io_size_merge,
            io_size_max
        )
        let chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(om_decoder_read_buffer_size(&decoder)), alignment: 4)
        fn.decode(decoder: &decoder, into: into, chunkBuffer: chunkBuffer.baseAddress!)
        chunkBuffer.deallocate()
    }
    
    public func read(_ dimRead: [Range<UInt64>], io_size_max: UInt64 = 65536, io_size_merge: UInt64 = 512) -> [Float] {
        let outDims = dimRead.map({UInt64($0.count)})
        let n = outDims.reduce(1, *)
        var out = [Float](repeating: .nan, count: Int(n))
        out.withUnsafeMutableBytes({
            read(
                into: $0.baseAddress!,
                dimRead: dimRead,
                intoCubeOffset: .init(repeating: 0, count: dimRead.count),
                intoCubeDimension: outDims,
                io_size_max: io_size_max,
                io_size_merge: io_size_merge
            )
        })
        return out
    }
}
