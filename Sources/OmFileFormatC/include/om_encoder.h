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
    const size_t *dimensions;
    const size_t *chunks;
    size_t dimension_count;
    size_t lut_chunk_element_count;
    
    /// The callback to decompress data
    om_compress_callback compress_callback;

    /// The filter function for each compressed block. E.g. a 2D delta coding.
    om_compress_filter_callback compress_filter_callback;

    /// Copy and scale individual values from a chunk into the output array
    om_compress_copy_callback compress_copy_callback;
    
    float scale_factor;
    
    /// An offset to convert floats to integers while scaling
    float add_offset;
    
    /// Numer of bytes for a single element of the data type
    int8_t bytes_per_element;
    
    /// Numer of bytes for a single element in the compressed stream. E.g. Int16 could be used to scale down floats
    int8_t bytes_per_element_compressed;
} om_encoder_t;



void om_encoder_init(om_encoder_t* encoder, float scale_factor, float add_offset, om_compression_t compression, om_datatype_t data_type, const size_t* dimensions, const size_t* chunks, size_t dimension_count, size_t lut_chunk_element_count);

size_t om_encoder_number_of_chunks(const om_encoder_t* encoder);
size_t om_encoder_number_of_chunks_in_array(const om_encoder_t* encoder, const size_t* array_count);

size_t om_encoder_compress_chunk_buffer_size(const om_encoder_t* encoder);
size_t om_encoder_compress_lut_buffer_size(const om_encoder_t* encoder, const size_t* lookUpTable, size_t lookUpTableCount);

size_t om_encoder_compress_lut(const om_encoder_t* encoder, const size_t* lookUpTable, size_t lookUpTableCount, uint8_t* out, size_t size_of_compressed_lut);
size_t om_encoder_compress_chunk(const om_encoder_t* encoder, const void* array, const size_t* arrayDimensions, const size_t* arrayOffset, const size_t* arrayCount, size_t chunkIndex, size_t chunkIndexOffsetInThisArray, uint8_t* out, uint8_t* chunkBuffer);

#endif // OM_ENCODER_H
