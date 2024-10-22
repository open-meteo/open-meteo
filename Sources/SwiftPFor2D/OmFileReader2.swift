//
//  OmFileReader2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 19.10.2024.
//

import Foundation
@_implementationOnly import CTurboPFor

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
        
        var decoder = OmFileDecoder()
        initOmFileDecoder(
            &decoder,
            v.scalefactor,
            v.compression,
            v.dataType,
            v.dimensions,
            UInt64(v.dimensions.count),
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
        /*let decoder = json.variables[0].makeReader(
            dimRead: dimRead,
            intoCubeOffset: intoCubeOffset,
            intoCubeDimension: intoCubeDimension,
            lutChunkElementCount: lutChunkElementCount,
            io_size_max: io_size_max,
            io_size_merge: io_size_merge
        )*/
        let chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(get_read_buffer_size(&decoder)), alignment: 4)
        Self.read(fn: fn, decoder: &decoder, into: into, chunkBuffer: chunkBuffer.baseAddress!)
        chunkBuffer.deallocate()
    }
    
    static func read(fn: Backend, decoder: UnsafePointer<OmFileDecoder>, into: UnsafeMutableRawPointer, chunkBuffer: UnsafeMutableRawPointer) {
        //print("new read \(self)")
        
        // TODO validate input buffer size based on data type?
        
        fn.withUnsafeBytes({ ptr in
            
            var readIndexInstruction = ChunkIndexReadInstruction()
            initialise_index_read(decoder, &readIndexInstruction)
            //print("start \(readIndexInstruction)")
            //decoder.initilalise_index_read()
            
            /// Loop over index blocks
            while get_next_index_read(decoder, &readIndexInstruction) {
                // actually "read" index data from file
                //print("read index \(readIndexInstruction)")
                let indexData = ptr.baseAddress!.advanced(by: Int(readIndexInstruction.offset))
                
                
                var readDataInstruction = ChunkDataReadInstruction()
                initChunkDataReadInstruction(&readDataInstruction, &readIndexInstruction)
                
                /// Loop over data blocks
                while get_next_data_read(decoder, &readDataInstruction, indexData, readIndexInstruction.count) {
                    // actually "read" compressed chunk data from file
                    //print("read data \(readDataInstruction)")
                    let dataData = ptr.baseAddress!.advanced(by: Int(readDataInstruction.offset))
                    
                    let _ = decode_chunks(decoder, readDataInstruction.chunkIndexLower, readDataInstruction.chunkIndexUpper, dataData, readDataInstruction.count, into, chunkBuffer)
                }
            }
        })
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
