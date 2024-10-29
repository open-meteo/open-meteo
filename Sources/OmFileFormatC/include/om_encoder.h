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
    float scalefactor;
    om_compression_t compression;
    om_datatype_t datatype;
    const uint64_t *dimensions;
    const uint64_t *chunks;
    uint64_t dimension_count;
    uint64_t lut_chunk_element_count;
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
