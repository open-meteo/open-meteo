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
} OmEncoder_t;

/// Initialise the OmEncoder structure with information about the shape of data
/// May return an error on invalid compression or data types
OmError_t OmEncoder_init(OmEncoder_t* encoder, float scale_factor, float add_offset, OmCompression_t compression, OmDataType_t data_type, const size_t* dimensions, const size_t* chunks, size_t dimension_count, size_t lut_chunk_element_count);

/// Get the number of chunks that is caluclated from dimensions and chunks
size_t OmEncoder_countChunks(const OmEncoder_t* encoder);

/// Calculate how many chunks can be filled from a given input
size_t OmEncoder_countChunksInArray(const OmEncoder_t* encoder, const size_t* array_count);

/// The buffer size required to collect a single chunk of data
size_t OmEncoder_chunkBufferSize(const OmEncoder_t* encoder);

/// The buffer size required to compress a single chunk.
size_t OmEncoder_compressedChunkBufferSize(const OmEncoder_t* encoder);

/// Calculate the required buffer size for the entire compressed LUT
size_t OmEncoder_lutBufferSize(const OmEncoder_t* encoder, const size_t* lookUpTable, size_t lookUpTableCount);

/// Compress the LUT and return the size of compressed LUT in bytes
size_t OmEncoder_compressLut(const OmEncoder_t* encoder, const size_t* lookUpTable, size_t lookUpTableCount, uint8_t* out, size_t size_of_compressed_lut);

/// Compress a single chunk. Chunk buffer must be of size `OmEncoder_chunkBufferSize`
size_t OmEncoder_compressChunk(const OmEncoder_t* encoder, const void* array, const size_t* arrayDimensions, const size_t* arrayOffset, const size_t* arrayCount, size_t chunkIndex, size_t chunkIndexOffsetInThisArray, uint8_t* out, uint8_t* chunkBuffer);

#endif // OM_ENCODER_H
