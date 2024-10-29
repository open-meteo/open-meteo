//
//  om_encoder.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 29.10.2024.
//

#ifndef OM_ENCODER_H
#define OM_ENCODER_H

#include "om_common.h"

/// The function to convert a single a a sequence of elements and convert data type. Applies scale factor.
typedef void(*om_compress_copy_callback)(uint64_t count, uint64_t read_offset, uint64_t write_offset, float scalefactor, const void* chunk_buffer, void* into);

/// compress input, of n-elements to output and return number of compressed byte
typedef uint64_t(*om_compress_callback)(const void* in, uint64_t count, void* out);

/// Perform a 2d filter operation
typedef void(*om_compress_filter_callback)(const size_t length0, const size_t length1, void* chunkBuffer);

// Encoder struct
typedef struct {
    float scalefactor;
    om_compression_t compression;
    om_datatype_t datatype;
    const uint64_t *dimensions;
    const uint64_t *chunks;
    uint64_t dimension_count;
    uint64_t lut_chunk_element_count;
    
    /// The callback to decompress data
    om_compress_callback compress_callback;

    /// The filter function for each compressed block. E.g. a 2D delta coding.
    om_compress_filter_callback compress_filter_callback;

    /// Copy and scale individual values from a chunk into the output array
    om_compress_copy_callback compress_copy_callback;
    
    /// Numer of bytes for a single element after decompression. Does not need to be the output datatype. E.g. Compression can use 16 bit and convert to float
    int8_t bytes_per_element;
} om_encoder_t;



void om_encoder_init(om_encoder_t* encoder, float scalefactor, om_compression_t compression, om_datatype_t datatype, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count, uint64_t lut_chunk_element_count);

uint64_t om_encoder_number_of_chunks(const om_encoder_t* encoder);
uint64_t om_encoder_number_of_chunks_in_array(const om_encoder_t* encoder, const uint64_t* array_count);
uint64_t om_encoder_chunk_buffer_size(const om_encoder_t* encoder);
uint64_t om_encoder_minimum_chunk_write_buffer(const om_encoder_t* encoder);
uint64_t om_encoder_output_buffer_capacity(const om_encoder_t* encoder);
uint64_t om_encoder_size_of_compressed_lut(const om_encoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount);
void om_encoder_compress_lut(const om_encoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount, uint8_t* out, uint64_t size_of_compressed_lut);
size_t om_encoder_writeSingleChunk(const om_encoder_t* encoder, const float* array, const uint64_t* arrayDimensions, const uint64_t* arrayOffset, const uint64_t* arrayCount, uint64_t chunkIndex, uint64_t chunkIndexOffsetInThisArray, uint8_t* out, uint64_t outSize, uint8_t* chunkBuffer);

#endif // OM_ENCODER_H
