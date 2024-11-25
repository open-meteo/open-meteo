/**
 * @file om_encoder.h
 * @brief OmFileEncoder: Write compressed chunks arrays to an OM file
 *
 * Created by Patrick Zippenfenig on 29.10.2024.
 */

#ifndef OM_ENCODER_H
#define OM_ENCODER_H

#include "om_common.h"


// Encoder struct
typedef struct {
    const uint64_t *dimensions;
    const uint64_t *chunks;
    uint64_t dimension_count;
    uint64_t lut_chunk_element_count;
    
    /// The callback to decompress data
    om_compress_callback_t compress_callback;

    /// The filter function for each compressed block. E.g. a 2D delta coding.
    om_compress_filter_callback_t compress_filter_callback;

    /// Copy and scale individual values from a chunk into the output array
    om_compress_copy_callback_t compress_copy_callback;
    
    float scale_factor;
    
    /// An offset to convert floats to integers while scaling
    float add_offset;
    
    /// Numer of bytes for a single element of the data type
    int8_t bytes_per_element;
    
    /// Numer of bytes for a single element in the compressed stream. E.g. Int16 could be used to scale down floats
    int8_t bytes_per_element_compressed;
} OmEncoder_t;

/// Initialise the OmEncoder structure with information about the shape of data
/// May return an error on invalid compression or data types
OmError_t om_encoder_init(OmEncoder_t* encoder, float scale_factor, float add_offset, OmCompression_t compression, OmDataType_t data_type, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count, uint64_t lut_chunk_element_count) ;

/// Get the number of chunks that is caluclated from dimensions and chunks
uint64_t om_encoder_count_chunks(const OmEncoder_t* encoder);

/// Calculate how many chunks can be filled from a given input
uint64_t om_encoder_count_chunks_in_array(const OmEncoder_t* encoder, const uint64_t* array_count);

/// The buffer size required to collect a single chunk of data
uint64_t om_encoder_chunk_buffer_size(const OmEncoder_t* encoder);

/// The buffer size required to compress a single chunk.
uint64_t om_encoder_compressed_chunk_buffer_size(const OmEncoder_t* encoder);

/// Calculate the required buffer size for the entire compressed LUT
uint64_t om_encoder_lut_buffer_size(const OmEncoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount);

/// Compress the LUT and return the size of compressed LUT in bytes
uint64_t om_encoder_compress_lut(const OmEncoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount, uint8_t* out, uint64_t size_of_compressed_lut);

/// Compress a single chunk. Chunk buffer must be of size `OmEncoder_chunkBufferSize`
uint64_t om_encoder_compress_chunk(const OmEncoder_t* encoder, const void* array, const uint64_t* arrayDimensions, const uint64_t* arrayOffset, const uint64_t* arrayCount, uint64_t chunkIndex, uint64_t chunkIndexOffsetInThisArray, uint8_t* out, uint8_t* chunkBuffer);

#endif // OM_ENCODER_H
