//
//  OmFileJSON.swift
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 19.10.2024.
//

@_implementationOnly import OmFileFormatC

/// The entry level JSON structure to descode all meta data inside an OpenMeteo file
/// Should contain an attribute `variable` with a list of variables in this file
public struct OmFileJSON: Codable {
    /// A list of variables inside this file
    let variables: [OmFileJSONVariable]
    
    let someAttributes: String?
}

/// Represent a variable inside an OpenMeteo file.
/// A variable can have arbitrary attributes, but the following are required for decding:
/// `dimensions` and `chunks` to describe the shape of data
/// `compression` and `scalefactor` define how data is compressed
/// `lutOffset` and `lutChunkSize` are required to locate data inside the file
///
/// TODO:
/// - datatype
/// - finalise naming
public struct OmFileJSONVariable: Codable {
    let name: String?
    
    /// The dimensions of the file
    let dimensions: [UInt64]
    
    /// How the dimensions are chunked
    let chunks: [UInt64]
    
    let dimensionNames: [String]?
    
    /// The scalefactor that is applied to convert floating point values to integers
    let scalefactor: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    let compression: OmFileFormatC.om_compression_t
    
    /// Data type like float, int32, uint64
    let dataType: OmFileFormatC.om_datatype_t
    
    /// The offset position of the beginning of the look up table LUT. The LUT comtains then data positions for each chunk
    let lutOffset: UInt64
    
    /// How long a chunk inside the LUT is after compression
    let lutChunkSize: UInt64
}

extension OmFileFormatC.om_compression_t: Codable {
    
}
extension OmFileFormatC.om_datatype_t: Codable {
    
}
/*extension OmFileJSONVariable {
    /// Get a decoder for this variable given the desired read offsets and lengths
    /// `lutChunkElementCount` controls the size of each block to compress the LUT
    func makeReader(dimRead: [Range<Int>], intoCubeOffset: [Int], intoCubeDimension: [Int], lutChunkElementCount: Int = 256, io_size_max: Int = OmFileDecoder.io_size_max_default, io_size_merge: Int = OmFileDecoder.io_size_merge_default) -> OmFileDecoder {
        return OmFileDecoder(
            scalefactor: scalefactor,
            compression: compression,
            dataType: dataType,
            dims: dimensions,
            chunks: chunks,
            readOffset: dimRead.map{$0.lowerBound},
            readCount: dimRead.map{$0.count},
            intoCubeOffset: intoCubeOffset,
            intoCubeDimension: intoCubeDimension,
            lutChunkLength: lutChunkSize,
            lutChunkElementCount: lutChunkElementCount,
            lutStart: lutOffset,
            io_size_merge: io_size_merge,
            io_size_max: io_size_max
        )
    }
}*/
