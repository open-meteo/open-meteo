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
    uint64_t offset;
    uint64_t count;
    uint64_t indexRangeLower;
    uint64_t indexRangeUpper;
    uint64_t chunkIndexLower;
    uint64_t chunkIndexUpper;
    uint64_t nextChunkLower;
    uint64_t nextChunkUpper;
} ChunkIndexReadInstruction;

// Definition of ChunkDataReadInstruction structure
typedef struct {
    uint64_t offset;
    uint64_t count;
    uint64_t indexRangeLower;
    uint64_t indexRangeUpper;
    uint64_t chunkIndexLower;
    uint64_t chunkIndexUpper;
    uint64_t nextChunkLower;
    uint64_t nextChunkUpper;
} ChunkDataReadInstruction;

// Definition of DataType enum
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
} DataType;

// Define an enum for the compression types.
// TODO check data length... looks like 32 bits
typedef enum {
    P4NZDEC256 = 0,          // Lossy compression using 2D delta coding and scalefactor. Only supports float and scales to 16-bit integer.
    FPXDEC32 = 1,            // Lossless compression using 2D xor coding.
    P4NZDEC256_LOGARITHMIC = 3 // Similar to `P4NZDEC256` but applies `log10(1+x)` before.
} CompressionType;

typedef struct {
    uint64_t dims_count;
    uint64_t* dims;
    uint64_t* chunks;
    uint64_t* readOffset;
    uint64_t* readCount;
    uint64_t* intoCubeOffset;
    uint64_t* intoCubeDimension;

    uint64_t io_size_merge;
    uint64_t io_size_max;
    uint64_t lutChunkLength;
    uint64_t lutChunkElementCount;
    uint64_t lutStart;
    uint64_t numberOfChunks;
    
    float scalefactor;
    CompressionType compression;
    DataType dataType;
} OmFileDecoder;

void initialise_index_read(const OmFileDecoder* decoder, ChunkIndexReadInstruction *indexRead);
void initChunkDataReadInstruction(ChunkDataReadInstruction *dataInstruction, const ChunkIndexReadInstruction *indexRead);

uint64_t compression_bytes_per_element(const CompressionType type);
uint64_t bytesPerElement(const DataType dataType);
void initOmFileDecoder(OmFileDecoder* decoder, const float scalefactor, const CompressionType compression, const DataType dataType,
                       const uint64_t* dims, const uint64_t dims_count, const uint64_t* chunks, const uint64_t* readOffset,
                       const uint64_t* readCount, const uint64_t* intoCubeOffset,
                       const uint64_t* intoCubeDimension, const uint64_t lutChunkLength, const uint64_t lutChunkElementCount,
                       const uint64_t lutStart, const uint64_t io_size_merge, const uint64_t io_size_max);
uint64_t get_read_buffer_size(const OmFileDecoder* decoder);
bool get_next_chunk_position(const OmFileDecoder *decoder, uint64_t *chunkIndexLower, uint64_t *chunkIndexUpper);
bool get_next_index_read(const OmFileDecoder* decoder, ChunkIndexReadInstruction* indexRead);
bool get_next_data_read(const OmFileDecoder *decoder, ChunkDataReadInstruction* dataRead, const void* indexData, uint64_t indexDataCount);
uint64_t decode_chunk(const OmFileDecoder *decoder, uint64_t chunkIndex, const void *data, void *into, void *chunkBuffer);
uint64_t decode_chunks(const OmFileDecoder *decoder, uint64_t chunkIndexLower, uint64_t chunkIndexUpper, const void *data, uint64_t dataCount, void *into, void *chunkBuffer);

#endif // DECODE_H
