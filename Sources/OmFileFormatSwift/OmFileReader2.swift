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
public struct OmFileReader2<Backend: OmFileReaderBackend> {
    /// Points to the underlaying memory. Needs to remain in scrope to keep memory accessible
    public let fn: Backend
    
    let variable: UnsafePointer<OmVariable_t?>?
    
    /// Number of elements in index LUT chunk. Assumed to 256 in production files. Only used for testing!
    let lutChunkElementCount: UInt64
        
    /// Open a file and decode om file meta data. In this casem fn is typically mmap or just plain memory
    public init(fn: Backend, lutChunkElementCount: UInt64 = 256) throws {
        self.lutChunkElementCount = lutChunkElementCount
        self.fn = fn
        
        let headerSize = om_header_size()
        let headerData = fn.getData(offset: 0, count: headerSize)
        
        switch om_header_type(headerData) {
        case OM_HEADER_LEGACY:
            self.variable = om_variable_init(headerData)
        case OM_HEADER_TRAILER:
            let fileSize = fn.count
            let trailerSize = om_trailer_size()
            let trailerData = fn.getData(offset: fileSize - trailerSize, count: trailerSize)
            let position = om_trailer_read(trailerData)
            guard position.size > 0 else {
                fatalError("Not an OM file")
            }
            /// Read data from root.offset by root.size. Important: data must remain accessible throughout the use of this variable!!
            let dataVariable = fn.getData(offset: Int(position.offset), count: Int(position.size))
            self.variable = om_variable_init(dataVariable)
        case OM_HEADER_INVALID:
            fallthrough
        default:
            fatalError("Not an OM file")
        }
    }
    
    init(fn: Backend, variable: UnsafePointer<OmVariable_t?>?, lutChunkElementCount: UInt64) {
        self.fn = fn
        self.variable = variable
        self.lutChunkElementCount = lutChunkElementCount
    }
    
    public var dataType: DataType {
        return DataType(rawValue: UInt8(om_variable_get_type(variable).rawValue))!
    }
    
    public var compression: CompressionType {
        return CompressionType(rawValue: UInt8(om_variable_get_compression(variable).rawValue))!
    }
    
    public var scaleFactor: Float {
        return om_variable_get_scale_factor(variable)
    }
    
    public var addOffset: Float {
        return om_variable_get_add_offset(variable)
    }
    
    public func getDimensions() -> UnsafeBufferPointer<UInt64> {
        let dimensions = om_variable_get_dimensions(variable);
        return UnsafeBufferPointer<UInt64>(start: dimensions.values, count: Int(dimensions.count))
    }
    
    public func getChunkDimensions() -> UnsafeBufferPointer<UInt64> {
        let dimensions = om_variable_get_chunks(variable);
        return UnsafeBufferPointer<UInt64>(start: dimensions.values, count: Int(dimensions.count))
    }
    
    public func getName() -> String? {
        let name = om_read_variable_name(variable);
        guard name.size > 0 else {
            return nil
        }
        let buffer = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: name.value), count: Int(name.size), deallocator: .none)
        return String(data: buffer, encoding: .utf8)
    }
    
    public var numberOfChildren: UInt32 {
        return om_variable_get_number_of_children(variable)
    }
    
    public func getChild(_ index: Int32) -> OmFileReader2<Backend>? {
        let child = om_variable_get_child(variable, index)
        guard child.size > 0 else {
            return nil
        }
        /// Read data from child.offset by child.size
        let dataChild = fn.getData(offset: Int(child.offset), count: Int(child.size))
        guard let childVariable = om_variable_init(dataChild) else {
            fatalError()
        }
        return OmFileReader2(fn: fn, variable: childVariable, lutChunkElementCount: lutChunkElementCount)
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
        var indexRead = OmDecoder_indexRead_t()
        OmDecoder_initIndexRead(decoder, &indexRead)
        
        /// Loop over index blocks and read index data
        while OmDecoder_nextIndexRead(decoder, &indexRead) {
            let indexData = self.getData(offset: Int(indexRead.offset), count: Int(indexRead.count))
            
            var dataRead = OmDecoder_dataRead_t()
            OmDecoder_initDataRead(&dataRead, &indexRead)
            
            var error: OmError_t = ERROR_OK
            /// Loop over data blocks and read compressed data chunks
            while OmDecoder_nexDataRead(decoder, &dataRead, indexData, indexRead.count, &error) {
                let dataData = self.getData(offset: Int(dataRead.offset), count: Int(dataRead.count))
                guard OmDecoder_decodeChunks(decoder, dataRead.chunkIndex, dataData, dataRead.count, into, chunkBuffer, &error) else {
                    fatalError("OmDecoder: \(String(cString: OmError_string(error)))")
                }
            }
            guard error == ERROR_OK else {
                fatalError("OmDecoder: \(String(cString: OmError_string(error)))")
            }
        }
    }

    /// Do an madvice to load data chunks from disk into page cache in the background
    func decodePrefetch(decoder: UnsafePointer<OmDecoder_t>) {
        var indexRead = OmDecoder_indexRead_t()
        OmDecoder_initIndexRead(decoder, &indexRead)
        
        /// Loop over index blocks and read index data
        while OmDecoder_nextIndexRead(decoder, &indexRead) {
            let indexData = self.getData(offset: Int(indexRead.offset), count: Int(indexRead.count))
            
            var dataRead = OmDecoder_dataRead_t()
            OmDecoder_initDataRead(&dataRead, &indexRead)
            
            var error: OmError_t = ERROR_OK
            /// Loop over data blocks and read compressed data chunks
            while OmDecoder_nexDataRead(decoder, &dataRead, indexData, indexRead.count, &error) {
                self.prefetchData(offset: Int(dataRead.offset), count: Int(dataRead.count))
            }
        }
    }
}
