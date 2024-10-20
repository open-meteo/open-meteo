//
//  OmFileReader2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 19.10.2024.
//

import Foundation

/// High level implementation to read an OpenMeteo file
/// Decodes meta data which may include JSON
/// Handles actual file reads. The current implementation just uses MMAP or plain memory.
/// Later implementations may use async read operations
struct OmFileReader2<Backend: OmFileReaderBackend> {
    let fn: Backend
    
    let json: OmFileJSON
    
    /// Number of elements in index LUT chunk. Might be hardcoded to 256 later. `1` signals old version 1/2 file without a compressed LUT.
    let lutChunkElementCount: Int
        
    public static func open_file(fn: Backend, lutChunkElementCount: Int = 256) throws -> Self {
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
    
    public func read(into: UnsafeMutableRawPointer, dimRead: [Range<Int>], intoCubeOffset: [Int], intoCubeDimension: [Int], io_size_max: Int = OmFileDecoder.io_size_max_default, io_size_merge: Int = OmFileDecoder.io_size_merge_default) {
        let decoder = json.variables[0].makeReader(
            dimRead: dimRead,
            intoCubeOffset: intoCubeOffset,
            intoCubeDimension: intoCubeDimension,
            lutChunkElementCount: lutChunkElementCount,
            io_size_max: io_size_max,
            io_size_merge: io_size_merge
        )
        let chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: decoder.get_read_buffer_size(), alignment: 4)
        Self.read(fn: fn, decoder: decoder, into: into, chunkBuffer: chunkBuffer.baseAddress!)
        chunkBuffer.deallocate()
    }
    
    static func read(fn: Backend, decoder: OmFileDecoder, into: UnsafeMutableRawPointer, chunkBuffer: UnsafeMutableRawPointer) {
        //print("new read \(self)")
        
        // TODO validate input buffer size?
        
        fn.withUnsafeBytes({ ptr in
            var readIndexInstruction = decoder.initilalise_index_read()
            
            /// Loop over index blocks
            while decoder.get_next_index_read(indexRead: &readIndexInstruction) {
                // actually "read" index data from file
                //print("read index \(readIndexInstruction)")
                let indexData = UnsafeRawBufferPointer(rebasing: ptr[readIndexInstruction.offset ..< readIndexInstruction.offset + readIndexInstruction.count])
                //ptr.baseAddress!.advanced(by: lutStart + readIndexInstruction.offset).assumingMemoryBound(to: UInt8.self)
                //print(ptr.baseAddress!.advanced(by: lutStart).assumingMemoryBound(to: Int.self).assumingMemoryBound(to: Int.self, capacity: readIndexInstruction.count / 8).map{$0})
                
                var readDataInstruction = ChunkDataReadInstruction(indexRead: readIndexInstruction)
                
                /// Loop over data blocks
                while decoder.get_next_data_read(dataRead: &readDataInstruction, indexData: indexData) {
                    // actually "read" compressed chunk data from file
                    //print("read data \(readDataInstruction)")
                    let dataData = ptr.baseAddress!.advanced(by: readDataInstruction.offset)
                    
                    let uncompressedSize = decoder.decode_chunks(chunkIndexLower: readDataInstruction.chunkIndexLower, chunkIndexUpper: readDataInstruction.chunkIndexUpper, data: dataData, into: into, chunkBuffer: chunkBuffer)
                    if uncompressedSize != readDataInstruction.count {
                        fatalError("Uncompressed size missmatch")
                    }
                }
            }
        })
    }
    
    public func read(_ dimRead: [Range<Int>], io_size_max: Int = OmFileDecoder.io_size_max_default, io_size_merge: Int = OmFileDecoder.io_size_merge_default) -> [Float] {
        let outDims = dimRead.map({$0.count})
        let n = outDims.reduce(1, *)
        var out = [Float](repeating: .nan, count: n)
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
