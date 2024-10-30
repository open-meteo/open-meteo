//
//  om_encoder.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 29.10.2024.
//

#ifndef OM_ENCODER_H
#define OM_ENCODER_H

#include "om_common.h"



// Encoder struct
typedef struct {
    float scale_factor;
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
    
    /// Numer of bytes for a single element of the data type
    int8_t bytes_per_element;
    
    /// Numer of bytes for a single element in the compressed stream. E.g. Int16 could be used to scale down floats
    int8_t bytes_per_element_compressed;
} om_encoder_t;



void om_encoder_init(om_encoder_t* encoder, float scale_factor, om_compression_t compression, om_datatype_t datatype, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count, uint64_t lut_chunk_element_count);

uint64_t om_encoder_number_of_chunks(const om_encoder_t* encoder);
uint64_t om_encoder_number_of_chunks_in_array(const om_encoder_t* encoder, const uint64_t* array_count);

uint64_t om_encoder_compress_chunk_buffer_size(const om_encoder_t* encoder);
uint64_t om_encoder_compress_lut_buffer_size(const om_encoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount);

uint64_t om_encoder_compress_lut(const om_encoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount, uint8_t* out, uint64_t size_of_compressed_lut);
size_t   om_encoder_compress_chunk(const om_encoder_t* encoder, const void* array, const uint64_t* arrayDimensions, const uint64_t* arrayOffset, const uint64_t* arrayCount, uint64_t chunkIndex, uint64_t chunkIndexOffsetInThisArray, uint8_t* out, uint8_t* chunkBuffer);

#endif // OM_ENCODER_H
