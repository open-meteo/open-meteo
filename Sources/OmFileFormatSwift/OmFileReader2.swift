//
//  OmFileReader2.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 19.10.2024.
//

import Foundation
@_implementationOnly import OmFileFormatC

/// High level implementation to read an OpenMeteo file
/// Decodes meta data which may include JSON
/// Handles actual file reads. The current implementation just uses MMAP or plain memory.
/// Later implementations may use async read operations
struct OmFileReader2<Backend: OmFileReaderBackend> {
    let fn: Backend
    
    let json: OmFileJSON
    
    /// Number of elements in index LUT chunk. Might be hardcoded to 256 later. `1` signals old version 1/2 file without a compressed LUT.
    let lutChunkElementCount: Int
        
    /// Open a file and decode om file meta data. In this casem fn is typically mmap or just plain memory
    public static func open_file(fn: Backend, lutChunkElementCount: Int = 256) throws -> Self {
        return try fn.withUnsafeBytes({ptr in
            // Support for old files. Read header and check for old file
            // If possble always read the first 40 bytes to decode a Version 1/2 file
            // Once all old files are migrates, this can be removed entirely
            guard ptr[0] == OmHeader.magicNumber1, ptr[1] == OmHeader.magicNumber2 else {
                fatalError("Not an OM file")
            }
            let version = ptr.baseAddress!.advanced(by: 2).assumingMemoryBound(to: UInt8.self).pointee
            if version == 1 || version == 2 {
                let metaV1 = ptr.baseAddress!.assumingMemoryBound(to: OmHeader.self)
                let variable = OmFileJSONVariable(
                    name: nil,
                    dimensions: [metaV1.pointee.dim0, metaV1.pointee.dim1],
                    chunks: [metaV1.pointee.chunk0, metaV1.pointee.chunk1],
                    dimension_names: nil,
                    scale_factor: metaV1.pointee.scalefactor,
                    add_offset: 0,
                    compression: .init(rawValue: metaV1.pointee.compression)!,
                    data_type: .float,
                    lut_offset: OmHeader.length,
                    lut_size: 0 // ignored if lutChunkElementCount == 1
                )
                let json = OmFileJSON(variables: [variable], someAttributes: nil)
                return OmFileReader2(fn: fn, json: json, lutChunkElementCount: 1)
            }
            
            if version != 3 {
                fatalError("Unknown version \(version)")
            }
            
            // Version 3 use JSON meta data at the end
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
    public func read(into: UnsafeMutableRawPointer, dimRead: [Range<Int>], intoCubeOffset: [Int], intoCubeDimension: [Int], io_size_max: Int = 65536, io_size_merge: Int = 512) {
        let v = self.json.variables[0]
        let nDimensions = v.dimensions.count
        assert(dimRead.count == nDimensions)
        assert(intoCubeOffset.count == nDimensions)
        assert(intoCubeDimension.count == nDimensions)
        
        let readOffset = dimRead.map({$0.lowerBound})
        let readCount = dimRead.map({$0.count})
        
        var decoder = OmDecoder_t()
        let error = OmDecoder_init(
            &decoder,
            v.scale_factor,
            v.add_offset,
            v.compression.toC(),
            v.data_type.toC(),
            v.dimensions.count,
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
        guard error == ERROR_OK else {
            fatalError("Om encoder: \(String(cString: OmError_string(error)))")
        }
        let chunkBufferSize = OmDecoder_readBufferSize(&decoder)
        let chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: chunkBufferSize, alignment: 4)
        fn.decode(decoder: &decoder, into: into, chunkBuffer: chunkBuffer.baseAddress!)
        chunkBuffer.deallocate()
    }
    
    public func read(_ dimRead: [Range<Int>], io_size_max: Int = 65536, io_size_merge: Int = 512) -> [Float] {
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


extension OmFileReaderBackend {
    /// Read and decode
    func decode(decoder: UnsafePointer<OmDecoder_t>, into: UnsafeMutableRawPointer, chunkBuffer: UnsafeMutableRawPointer) {
        self.withUnsafeBytes({ ptr in
            var indexRead = OmDecoder_indexRead_t()
            OmDecoder_initIndexRead(decoder, &indexRead)
            
            /// Loop over index blocks and read index data
            while OmDecoder_nextIndexRead(decoder, &indexRead) {
                //print("read index \(indexRead)")
                let indexData = ptr.baseAddress!.advanced(by: indexRead.offset)
                
                var dataRead = OmDecoder_dataRead_t()
                OmDecoder_initDataRead(&dataRead, &indexRead)
                
                var error: OmError_t = ERROR_OK
                /// Loop over data blocks and read compressed data chunks
                while OmDecoder_nexDataRead(decoder, &dataRead, indexData, indexRead.count, &error) {
                    //print("read data \(dataRead)")
                    let dataData = ptr.baseAddress!.advanced(by: dataRead.offset)
                    guard OmDecoder_decodeChunks(decoder, dataRead.chunkIndex, dataData, dataRead.count, into, chunkBuffer, &error) else {
                        fatalError("Om decoder: \(String(cString: OmError_string(error)))")
                    }
                }
                guard error == ERROR_OK else {
                    fatalError("Om decoder: \(String(cString: OmError_string(error)))")
                }
            }
        })
    }
}
