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
    /// Points to the underlaying memory. Needs to remain in scrope to keep memory accessible
    let fn: Backend
    
    let variable: UnsafePointer<OmVariable_t?>?
    
    /// Number of elements in index LUT chunk. Assumed to 256 in production files. Only used for testing!
    let lutChunkElementCount: UInt64
        
    /// Open a file and decode om file meta data. In this casem fn is typically mmap or just plain memory
    public init(fn: Backend, lutChunkElementCount: UInt64 = 256) throws {
        self.lutChunkElementCount = lutChunkElementCount
        self.fn = fn
        self.variable = fn.withUnsafeBytes {ptr in
            let headerSize = om_read_header_size()
            var root = OmOffsetSize_t(offset: 0, size: 0)
            guard om_read_header(ptr.baseAddress, &root) == ERROR_OK else {
                fatalError("Not an OM file")
            }
            if root.offset == 0 && root.size == 0 {
                // version 3 file, read trailer
                let fileSize = fn.count
                let trailerSize = om_read_trailer_size()
                let dataTrailer = ptr.baseAddress?.advanced(by: fileSize - trailerSize)
                guard om_read_trailer(dataTrailer, &root) == ERROR_OK else {
                    fatalError("Not an OM file")
                }
            }
            /// Read data from root.offset by root.size
            let dataRoot = ptr.baseAddress?.advanced(by: Int(root.offset))
            return om_variable_init(dataRoot)
        }
    }
    
    init(fn: Backend, variable: UnsafePointer<OmVariable_t?>?, lutChunkElementCount: UInt64) {
        self.fn = fn
        self.variable = variable
        self.lutChunkElementCount = lutChunkElementCount
    }
    
    var dataType: DataType {
        return DataType(rawValue: UInt8(om_variable_get_type(variable).rawValue))!
    }
    
    var name: String? {
        var size: UInt16 = 0
        var name: UnsafeMutablePointer<Int8>? = nil
        guard om_variable_get_name(variable, &size, &name) == ERROR_OK, size > 0, let name = name else {
            return nil
        }
        let buffer = Data(bytesNoCopy: name, count: Int(size), deallocator: .none)
        return String(data: buffer, encoding: .utf8)
    }
    
    var numberOfChildren: Int32 {
        return om_variable_number_of_children(variable)
    }
    
    func getChild(_ index: Int32) -> OmFileReader2<Backend>? {
        var child = OmOffsetSize_t(offset: 0, size: 0)
        guard om_variable_get_child(variable, index, &child) == ERROR_OK else {
            return nil
        }
        return fn.withUnsafeBytes {ptr in
            /// Read data from child.offset by child.size
            let dataChild = ptr.baseAddress?.advanced(by: Int(child.offset))
            guard let childVariable = om_variable_init(dataChild) else {
                fatalError()
            }
            return OmFileReader2(fn: fn, variable: childVariable, lutChunkElementCount: lutChunkElementCount)
        }
    }
    
    public func readScalar<OmType: OmFileScalarDataTypeProtocol>() -> OmType? {
        guard OmType.dataTypeScalar == dataType else {
            return nil
        }
        var value = OmType()
        guard withUnsafeMutablePointer(to: &value, { om_variable_read_scalar(variable, $0) }) == ERROR_OK else {
            return nil
        }
        return value
    }
    
    /// Read variable as float array
    public func read(_ dimRead: [Range<UInt64>], io_size_max: UInt64 = 65536, io_size_merge: UInt64 = 512) -> [Float] {
        let outDims = dimRead.map({UInt64($0.count)})
        let n = outDims.reduce(1, *)
        var out = [Float](repeating: .nan, count: Int(n))
        out.withUnsafeMutableBufferPointer({
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
    
    /// Read a variable as an array of dynamic type.
    public func read<OmType: OmFileArrayDataTypeProtocol>(into: UnsafeMutablePointer<OmType>, dimRead: [Range<UInt64>], intoCubeOffset: [UInt64], intoCubeDimension: [UInt64], io_size_max: UInt64 = 65536, io_size_merge: UInt64 = 512) {
        let nDimensions = dimRead.count
        guard OmType.dataTypeArray == self.dataType else {
            fatalError()
        }
        assert(intoCubeOffset.count == nDimensions)
        assert(intoCubeDimension.count == nDimensions)
        
        let readOffset = dimRead.map({$0.lowerBound})
        let readCount = dimRead.map({UInt64($0.count)})
        
        var decoder = OmDecoder_t()
        let error = OmDecoder_init(
            &decoder,
            variable,
            UInt64(nDimensions),
            readOffset,
            readCount,
            intoCubeOffset,
            intoCubeDimension,
            lutChunkElementCount,
            io_size_merge,
            io_size_max
        )
        guard error == ERROR_OK else {
            fatalError("OmDecoder: \(String(cString: OmError_string(error)))")
        }
        let chunkBufferSize = OmDecoder_readBufferSize(&decoder)
        let chunkBuffer = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(chunkBufferSize), alignment: 1)
        fn.decode(decoder: &decoder, into: into, chunkBuffer: chunkBuffer.baseAddress!)
        chunkBuffer.deallocate()
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
                let indexData = ptr.baseAddress!.advanced(by: Int(indexRead.offset))
                
                var dataRead = OmDecoder_dataRead_t()
                OmDecoder_initDataRead(&dataRead, &indexRead)
                
                var error: OmError_t = ERROR_OK
                /// Loop over data blocks and read compressed data chunks
                while OmDecoder_nexDataRead(decoder, &dataRead, indexData, indexRead.count, &error) {
                    let dataData = ptr.baseAddress!.advanced(by: Int(dataRead.offset))
                    guard OmDecoder_decodeChunks(decoder, dataRead.chunkIndex, dataData, dataRead.count, into, chunkBuffer, &error) else {
                        fatalError("OmDecoder: \(String(cString: OmError_string(error)))")
                    }
                }
                guard error == ERROR_OK else {
                    fatalError("OmDecoder: \(String(cString: OmError_string(error)))")
                }
            }
        })
    }
}

