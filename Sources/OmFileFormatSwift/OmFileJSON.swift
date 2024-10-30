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
    let dimensions: [Int]
    
    /// How the dimensions are chunked
    let chunks: [Int]
    
    let dimension_names: [String]?
    
    /// The scalefactor that is applied to convert floating point values to integers
    let scale_factor: Float
    
    let add_offset: Float
    
    /// Type of compression and coding. E.g. delta, zigzag coding is then implemented in different compression routines
    let compression: CompressionType
    
    /// Data type like float, int32, Int
    let data_type: DataType
    
    /// The offset position of the beginning of the look up table LUT. The LUT comtains then data positions for each chunk
    let lut_offset: Int
    
    /// The total size of the compressed LUT.
    let lut_size: Int
}

extension OmFileFormatC.om_compression_t: Codable {
    
}
extension OmFileFormatC.om_datatype_t: Codable {
    
}
