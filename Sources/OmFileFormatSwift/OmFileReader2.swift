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
        // TODO validate input buffer size based on data type?
        
        self.withUnsafeBytes({ ptr in
            var indexRead = om_decoder_index_read_t()
            om_decoder_index_read_init(decoder, &indexRead)
            
            /// Loop over index blocks and read index data
            while om_decocder_next_index_read(decoder, &indexRead) {
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
        
    public static func open_file(fn: Backend, lutChunkElementCount: UInt64 = 256) throws -> Self {
        // switch version 2 and 3
        
        // if version 3, read trailer
        
        return try fn.withUnsafeBytes({ptr in
            // TODO read header and check for old file
            // if old file
            // read header
            
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
    
    public func read(into: UnsafeMutableRawPointer, dimRead: [Range<UInt64>], intoCubeOffset: [UInt64], intoCubeDimension: [UInt64], io_size_max: UInt64 = 65536, io_size_merge: UInt64 = 512) {
        let v = self.json.variables[0]
        let readOffset = dimRead.map({UInt64($0.lowerBound)})
        let readCount = dimRead.map({UInt64($0.count)})
        
        var decoder = om_decoder_t()
        om_decoder_init(
            &decoder,
            v.scalefactor,
            v.compression,
            v.dataType,
            UInt64(v.dimensions.count),
            v.dimensions,
            v.chunks,
            readOffset,
            readCount,
            intoCubeOffset,
            intoCubeDimension,
            v.lutChunkSize,
            lutChunkElementCount,
            v.lutOffset,
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
