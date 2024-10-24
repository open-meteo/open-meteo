//
//  om_decoder.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 22.10.2024.
//

#ifndef DECODE_H
#define DECODE_H

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint64_t lowerBound;
    uint64_t upperBound;
} om_range_t;

typedef struct {
    uint64_t offset;
    uint64_t count;
    om_range_t indexRange;
    om_range_t chunkIndex;
    om_range_t nextChunk;
} om_decoder_index_read_t;

typedef om_decoder_index_read_t om_decoder_data_read_t;

typedef enum {
    DATA_TYPE_INT8 = 0,
    DATA_TYPE_UINT8 = 1,
    DATA_TYPE_INT16 = 2,
    DATA_TYPE_UINT16 = 3,
    DATA_TYPE_INT32 = 4,
    DATA_TYPE_UINT32 = 5,
    DATA_TYPE_INT64 = 6,
    DATA_TYPE_UINT64 = 7,
    DATA_TYPE_FLOAT = 8,
    DATA_TYPE_DOUBLE = 9
} om_datatype_t;

// Define an enum for the compression types.
// TODO check data length... looks like 32 bits
typedef enum {
    P4NZDEC256 = 0,          // Lossy compression using 2D delta coding and scalefactor. Only supports float and scales to 16-bit integer.
    FPXDEC32 = 1,            // Lossless compression using 2D xor coding.
    P4NZDEC256_LOGARITHMIC = 3 // Similar to `P4NZDEC256` but applies `log10(1+x)` before.
} om_compression_t;

typedef void(*om_decompress_copy_callback)(uint64_t, uint64_t, uint64_t, float, const void*, void*);

/// decompress input, of n-elements to output and return number of compressed byte
typedef uint64_t(*om_decompress_callback)(const void*, uint64_t lengthInChunk, void*);

/// Perform a 2d filter operation
typedef void(*om_decompress_filter_callback)(const size_t length0, const size_t length1, void* chunkBuffer);

typedef struct {
    uint64_t dims_count;
    uint64_t io_size_merge;
    uint64_t io_size_max;
    uint64_t lut_chunk_length;
    uint64_t lut_chunk_element_count;
    uint64_t lut_start;
    uint64_t number_of_chunks;
    
    const uint64_t* dims;
    const uint64_t* chunks;
    const uint64_t* read_offset;
    const uint64_t* read_count;
    const uint64_t* cube_offset;
    const uint64_t* cube_dimensions;
    
    om_decompress_callback decompress_callback;
    om_decompress_filter_callback decompress_filter_callback;
    om_decompress_copy_callback decompress_copy_callback;
    
    float scalefactor;
    //om_compression_t compression;
    //om_datatype_t data_type;
    int8_t bytes_per_element;
} om_decoder_t;

void om_decoder_index_read_init(const om_decoder_t* decoder, om_decoder_index_read_t *indexRead);
void om_decoder_data_read_init(om_decoder_data_read_t *dataInstruction, const om_decoder_index_read_t *indexRead);

void om_decoder_init(om_decoder_t* decoder, const float scalefactor, const om_compression_t compression, const om_datatype_t dataType, const uint64_t dims_count, const uint64_t* dims, const uint64_t* chunks, const uint64_t* readOffset, const uint64_t* readCount, const uint64_t* intoCubeOffset, const uint64_t* intoCubeDimension, const uint64_t lutChunkLength, const uint64_t lutChunkElementCount, const uint64_t lutStart, const uint64_t io_size_merge, const uint64_t io_size_max);
uint64_t om_decoder_read_buffer_size(const om_decoder_t* decoder);
bool om_decocder_next_index_read(const om_decoder_t* decoder, om_decoder_index_read_t* indexRead);
bool om_decoder_next_data_read(const om_decoder_t *decoder, om_decoder_data_read_t* dataRead, const void* indexData, uint64_t indexDataCount);
uint64_t om_decoder_decode_chunks(const om_decoder_t *decoder, om_range_t chunkIndex, const void *data, uint64_t dataCount, void *into, void *chunkBuffer);

#endif // DECODE_H
