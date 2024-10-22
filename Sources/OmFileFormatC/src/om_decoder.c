//
//  om_decoder.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 22.10.2024.
//

#include <stdlib.h>
#include <assert.h>
#include <math.h>
#include "vp4.h"
#include "fp.h"
#include "delta2d.h"
#include "om_decoder.h"

#define MAX_LUT_ELEMENTS 256

// Initialization function for ChunkDataReadInstruction
void om_decoder_data_read_init(om_decoder_data_read_t *data_read, const om_decoder_index_read_t *index_read) {
    data_read->offset = 0;
    data_read->count = 0;
    data_read->indexRange = index_read->indexRange;
    data_read->chunkIndex.lowerBound = 0;
    data_read->chunkIndex.upperBound = 0;
    data_read->nextChunk = index_read->chunkIndex;
}


// Function to get bytes per element for each compression type.
uint64_t compression_bytes_per_element(const om_compression_t type) {
    switch (type) {
        case P4NZDEC256:
        case P4NZDEC256_LOGARITHMIC:
            return 2;
        case FPXDEC32:
            return 4;
        default:
            return 0; // Handle unknown types gracefully.
    }
}

// Function to get the number of bytes per element for each data type
uint64_t bytesPerElement(const om_datatype_t data_type) {
    switch (data_type) {
        case DATA_TYPE_INT8:
        case DATA_TYPE_UINT8:
            return 1;
        case DATA_TYPE_INT16:
        case DATA_TYPE_UINT16:
            return 2;
        case DATA_TYPE_INT32:
        case DATA_TYPE_UINT32:
        case DATA_TYPE_FLOAT:
            return 4;
        case DATA_TYPE_INT64:
        case DATA_TYPE_UINT64:
        case DATA_TYPE_DOUBLE:
            return 8;
        default:
            return 0; // Error case if the data type is not recognized
    }
}

// Function to divide and round up
uint64_t divide_rounded_up(const uint64_t dividend, const uint64_t divisor) {
    uint64_t rem = dividend % divisor;
    return (rem == 0) ? dividend / divisor : dividend / divisor + 1;
}

uint64_t min(const uint64_t a, const uint64_t b) {
    return a < b ? a : b;
}
uint64_t max(const uint64_t a, const uint64_t b) {
    return a > b ? a : b;
}

/// Assume chunk buffer is a 16 bit integer array and convert to float
void om_decoder_copy_int16_to_float(uint64_t count, uint64_t read_offset, uint64_t write_offset, float scalefactor, const void* chunk_buffer, void* into) {
    for (uint64_t i = 0; i < count; ++i) {
        int16_t val = ((int16_t *)chunk_buffer)[read_offset + i];
        ((float *)into)[write_offset + i] = (val == INT16_MAX) ? NAN : (float)val / scalefactor;
    }
}

/// Assume chunk buffer is a 16 bit integer array and convert to float and scale log10
void om_decoder_copy_int16_to_float_log10(uint64_t count, uint64_t read_offset, uint64_t write_offset, float scalefactor, const void* chunk_buffer, void* into) {
    for (uint64_t i = 0; i < count; ++i) {
        int16_t val = ((int16_t *)chunk_buffer)[read_offset + i];
        ((float *)into)[write_offset + i] = (val == INT16_MAX) ? NAN : powf(10, (float)val / scalefactor) - 1;
    }
}

void om_decoder_copy_float(uint64_t count, uint64_t read_offset, uint64_t write_offset, float scalefactor, const void* chunk_buffer, void* into) {
    for (uint64_t i = 0; i < count; ++i) {
        ((float *)into)[write_offset + i] = ((float *)chunk_buffer)[read_offset + i];
    }
}

void om_decoder_copy_double(uint64_t count, uint64_t read_offset, uint64_t write_offset, float scalefactor, const void* chunk_buffer, void* into) {
    for (uint64_t i = 0; i < count; ++i) {
        ((double *)into)[write_offset + i] = ((double *)chunk_buffer)[read_offset + i];
    }
}


// Initialization function for OmFileDecoder
void om_decoder_init(om_decoder_t* decoder, const float scalefactor, const om_compression_t compression, const om_datatype_t data_type, const uint64_t dims_count, const uint64_t* dims, const uint64_t* chunks, const uint64_t* read_offset, const uint64_t* read_count, const uint64_t* cube_offset, const uint64_t* cube_dimensions, const uint64_t lut_chunk_length, const uint64_t lut_chunk_element_count, const uint64_t lust_start, const uint64_t io_size_merge, const uint64_t io_size_max) {
    decoder->scalefactor = scalefactor;
    decoder->compression = compression;
    decoder->data_type = data_type;
    decoder->dims = dims;
    decoder->dims_count = dims_count;
    decoder->chunks = chunks;
    decoder->read_offset = read_offset;
    decoder->read_count = read_count;
    decoder->cube_offset = cube_offset;
    decoder->cube_dimensions = cube_dimensions;
    decoder->lut_chunk_length = lut_chunk_length;
    decoder->lut_chunk_element_count = lut_chunk_element_count;
    decoder->lut_start = lust_start;
    decoder->io_size_merge = io_size_merge;
    decoder->io_size_max = io_size_max;
    
    
    switch (decoder->compression) {
        case P4NZDEC256:
            decoder->copy_callback = om_decoder_copy_int16_to_float;
            break;
            
        case FPXDEC32:
            if (decoder->data_type == DATA_TYPE_FLOAT) {
                decoder->copy_callback = om_decoder_copy_float;
            } else if (decoder->data_type == DATA_TYPE_DOUBLE) {
                decoder->copy_callback = om_decoder_copy_double;
            }
            break;
            
        case P4NZDEC256_LOGARITHMIC:
            decoder->copy_callback = om_decoder_copy_int16_to_float_log10;
            break;
            
        default:
            assert(0 && "Unsupported compression type for copying data.");
    }
    
    // Calculate the number of chunks based on dims and chunks
    uint64_t n = 1;
    for (uint64_t i = 0; i < dims_count; i++) {
        n *= divide_rounded_up(dims[i], chunks[i]);
    }
    decoder->number_of_chunks = n;
}


void om_decoder_index_read_init(const om_decoder_t* decoder, om_decoder_index_read_t *index_read) {
    uint64_t chunkStart = 0;
    uint64_t chunkEnd = 1;
    
    for (uint64_t i = 0; i < decoder->dims_count; i++) {
        // Calculate lower and upper chunk indices for the current dimension
        uint64_t chunkInThisDimensionLower = decoder->read_offset[i] / decoder->chunks[i];
        uint64_t chunkInThisDimensionUpper = divide_rounded_up(decoder->read_offset[i] + decoder->read_count[i], decoder->chunks[i]);
        uint64_t chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower;
        
        uint64_t firstChunkInThisDimension = chunkInThisDimensionLower;
        uint64_t nChunksInThisDimension = divide_rounded_up(decoder->dims[i], decoder->chunks[i]);
        
        // Update chunkStart and chunkEnd
        chunkStart = chunkStart * nChunksInThisDimension + firstChunkInThisDimension;
        
        if (decoder->read_count[i] == decoder->dims[i]) {
            // The entire dimension is read
            chunkEnd = chunkEnd * nChunksInThisDimension;
        } else {
            // Only parts of this dimension are read
            chunkEnd = chunkStart + chunkInThisDimensionCount;
        }
    }
    index_read->offset = 0;
    index_read->count = 0;
    index_read->indexRange.lowerBound = 0;
    index_read->indexRange.upperBound = 0;
    index_read->chunkIndex.lowerBound = 0;
    index_read->chunkIndex.upperBound = 0;
    index_read->nextChunk.lowerBound = chunkStart;
    index_read->nextChunk.upperBound = chunkEnd;
}


// Function to get the read buffer size for a single chunk
uint64_t om_decoder_read_buffer_size(const om_decoder_t* decoder) {
    uint64_t chunkLength = 1;
    for (uint64_t i = 0; i < decoder->dims_count; i++) {
        chunkLength *= decoder->chunks[i];
    }
    // Assuming a bytesPerElement function exists for compression type, adjust as needed.
    return chunkLength * compression_bytes_per_element(decoder->compression);
}

bool _om_decoder_next_chunk_position(const om_decoder_t *decoder, om_range_t *chunk_index) {
    uint64_t rollingMultiply = 1;
    
    // Number of consecutive chunks that can be read linearly.
    uint64_t linearReadCount = 1;
    bool linearRead = true;
    
    for (int64_t i = decoder->dims_count - 1; i >= 0; --i) {
        // Number of chunks in this dimension.
        uint64_t nChunksInThisDimension = divide_rounded_up(decoder->dims[i], decoder->chunks[i]);
        
        // Calculate chunk range in this dimension.
        uint64_t chunkInThisDimensionLower = decoder->read_offset[i] / decoder->chunks[i];
        uint64_t chunkInThisDimensionUpper = divide_rounded_up(decoder->read_offset[i] + decoder->read_count[i], decoder->chunks[i]);
        uint64_t chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower;
        
        // Move forward by one.
        chunk_index->lowerBound += rollingMultiply;
        
        // Check for linear read conditions.
        if (i == decoder->dims_count - 1 && decoder->dims[i] != decoder->read_count[i]) {
            // If the fast dimension is only partially read.
            linearReadCount = chunkInThisDimensionCount;
            linearRead = false;
        }
        
        if (linearRead && decoder->dims[i] == decoder->read_count[i]) {
            // The dimension is read entirely.
            linearReadCount *= nChunksInThisDimension;
        } else {
            // Dimension is read partly; cannot merge further reads.
            linearRead = false;
        }
        
        // Calculate the chunk index in this dimension.
        uint64_t c0 = (chunk_index->lowerBound / rollingMultiply) % nChunksInThisDimension;
        
        // Check for overflow.
        if (c0 != chunkInThisDimensionUpper && c0 != 0) {
            break; // No overflow in this dimension, break.
        }
        
        // Adjust chunkIndex.lowerBound if there is an overflow.
        chunk_index->lowerBound -= chunkInThisDimensionCount * rollingMultiply;
        
        // Update the rolling multiplier for the next dimension.
        rollingMultiply *= nChunksInThisDimension;
        
        // If we're at the first dimension and have processed all chunks.
        if (i == 0) {
            chunk_index->upperBound = chunk_index->lowerBound;
            return false;
        }
    }
    
    // Update chunkIndex.upperBound based on the number of chunks that can be read linearly.
    chunk_index->upperBound = chunk_index->lowerBound + linearReadCount;
    return true;
}


bool om_decocder_next_index_read(const om_decoder_t* decoder, om_decoder_index_read_t* index_read) {
    if (index_read->nextChunk.lowerBound >= index_read->nextChunk.upperBound) {
        return false;
    }
    
    index_read->chunkIndex = index_read->nextChunk;
    index_read->indexRange.lowerBound = index_read->nextChunk.lowerBound;
    
    uint64_t chunkIndex = index_read->nextChunk.lowerBound;
    
    bool isV3LUT = decoder->lut_chunk_element_count > 1;
    uint64_t alignOffset = isV3LUT || index_read->indexRange.lowerBound == 0 ? 0 : 1;
    uint64_t endAlignOffset = isV3LUT ? 1 : 0;
    
    uint64_t readStart = (index_read->nextChunk.lowerBound - alignOffset) / decoder->lut_chunk_element_count * decoder->lut_chunk_length;
    
    while (1) {
        uint64_t maxRead = decoder->io_size_max / decoder->lut_chunk_length * decoder->lut_chunk_element_count;
        uint64_t nextIncrement = max(1, min(maxRead, index_read->nextChunk.upperBound - index_read->nextChunk.lowerBound - 1));
        
        if (index_read->nextChunk.lowerBound + nextIncrement >= index_read->nextChunk.upperBound) {
            if (!_om_decoder_next_chunk_position(decoder, &index_read->nextChunk)) {
                break;
            }
            uint64_t readStartNext = (index_read->nextChunk.lowerBound + endAlignOffset) / decoder->lut_chunk_element_count * decoder->lut_chunk_length - decoder->lut_chunk_length;
            uint64_t readEndPrevious = chunkIndex / decoder->lut_chunk_element_count * decoder->lut_chunk_length;
            
            if (readStartNext - readEndPrevious > decoder->io_size_merge) {
                break;
            }
        } else {
            index_read->nextChunk.lowerBound += nextIncrement;
        }
        
        uint64_t readEndNext = (index_read->nextChunk.lowerBound + endAlignOffset) / decoder->lut_chunk_element_count * decoder->lut_chunk_length;
        
        if (readEndNext - readStart > decoder->io_size_max) {
            break;
        }
        
        chunkIndex = index_read->nextChunk.lowerBound;
    }
    
    uint64_t readEnd = ((chunkIndex + endAlignOffset) / decoder->lut_chunk_element_count + 1) * decoder->lut_chunk_length;
    uint64_t lutTotalSize = divide_rounded_up(decoder->number_of_chunks, decoder->lut_chunk_element_count) * decoder->lut_chunk_length;
    assert(readEnd <= lutTotalSize);
    
    index_read->offset = decoder->lut_start + readStart;
    index_read->count = readEnd - readStart;
    index_read->indexRange.upperBound = chunkIndex + 1;
    return true;
}


bool om_decoder_next_data_read(const om_decoder_t *decoder, om_decoder_data_read_t* data_read, const void* index_data, uint64_t index_data_size) {
    if (data_read->nextChunk.lowerBound >= data_read->nextChunk.upperBound) {
        return false;
    }
    
    uint64_t chunkIndex = data_read->nextChunk.lowerBound;
    data_read->chunkIndex.lowerBound = chunkIndex;
    
    uint64_t lutChunkElementCount = decoder->lut_chunk_element_count;
    uint64_t lutChunkLength = decoder->lut_chunk_length;
    
    // Version 1 case
    if (decoder->lut_chunk_element_count == 1) {
        // index is a flat Int64 array
        const int64_t* data = (const int64_t*)index_data;
        
        bool isOffset0 = (data_read->indexRange.lowerBound == 0);
        uint64_t startOffset = isOffset0 ? 1 : 0;
        
        
        uint64_t readPos = data_read->indexRange.lowerBound - chunkIndex - startOffset;
        assert((readPos + 1) * sizeof(int64_t) <= index_data_size);
        
        uint64_t startPos = isOffset0 ? 0 : data[readPos];
        uint64_t endPos = startPos;
        
        // Loop to the next chunk until the end is reached
        while (true) {
            readPos = data_read->nextChunk.lowerBound - data_read->indexRange.lowerBound - startOffset + 1;
            assert((readPos + 1) * sizeof(int64_t) <= index_data_size);
            uint64_t dataEndPos = data[readPos];
            
            // Merge and split IO requests, ensuring at least one IO request is sent
            if (startPos != endPos && (dataEndPos - startPos > decoder->io_size_max || dataEndPos - endPos > decoder->io_size_merge)) {
                break;
            }
            endPos = dataEndPos;
            chunkIndex = data_read->nextChunk.lowerBound;
            
            if (data_read->nextChunk.lowerBound + 1 >= data_read->nextChunk.upperBound) {
                if (!_om_decoder_next_chunk_position(decoder, &data_read->nextChunk)) {
                    // No next chunk, finish processing the current one and stop
                    break;
                }
            } else {
                data_read->nextChunk.lowerBound += 1;
            }
            
            if (data_read->nextChunk.lowerBound >= data_read->indexRange.upperBound) {
                data_read->nextChunk.lowerBound = 0;
                data_read->nextChunk.upperBound = 0;
                break;
            }
        }
        
        // Old files do not compress LUT and data is after LUT
        // V1 header size
        uint64_t om_header_v1_length = 40;
        size_t dataStart = om_header_v1_length + decoder->number_of_chunks * sizeof(int64_t);
        
        data_read->offset = startPos + dataStart;
        data_read->count = endPos - startPos;
        data_read->chunkIndex.upperBound = chunkIndex + 1;
        return true;
    }
    
    uint8_t* indexDataPtr = (uint8_t*)index_data;
    
    uint64_t uncompressedLut[MAX_LUT_ELEMENTS] = {0};
    
    // Which LUT chunk is currently loaded into `uncompressedLut`
    uint64_t lutChunk = chunkIndex / lutChunkElementCount;
    
    // Offset byte in LUT relative to the index range
    size_t lutOffset = data_read->indexRange.lowerBound / lutChunkElementCount * lutChunkLength;
    
    // Uncompress the first LUT index chunk and check the length
    {
        uint64_t thisLutChunkElementCount = min((lutChunk + 1) * lutChunkElementCount, decoder->number_of_chunks+1) - lutChunk * lutChunkElementCount;
        size_t start = lutChunk * lutChunkLength - lutOffset;
        assert(start >= 0);
        assert(start + lutChunkLength <= index_data_size);
        
        // Decompress LUT chunk
        p4nddec64(indexDataPtr + start, thisLutChunkElementCount, uncompressedLut);
    }
    
    // Index data relative to start index
    uint64_t startPos = uncompressedLut[chunkIndex % lutChunkElementCount];
    uint64_t endPos = startPos;
    
    // Loop to the next chunk until the end is reached
    while (true) {
        uint64_t nextLutChunk = (data_read->nextChunk.lowerBound + 1) / lutChunkElementCount;
        
        // Maybe the next LUT chunk needs to be uncompressed
        if (nextLutChunk != lutChunk) {
            uint64_t nextLutChunkElementCount = min((nextLutChunk + 1) * lutChunkElementCount, decoder->number_of_chunks+1) - nextLutChunk * lutChunkElementCount;
            size_t start = nextLutChunk * lutChunkLength - lutOffset;
            assert(start >= 0);
            assert(start + lutChunkLength <= index_data_size);
            
            // Decompress LUT chunk
            p4nddec64(indexDataPtr + start, nextLutChunkElementCount, uncompressedLut);
            lutChunk = nextLutChunk;
        }
        
        uint64_t dataEndPos = uncompressedLut[(data_read->nextChunk.lowerBound + 1) % lutChunkElementCount];
        
        // Merge and split IO requests, ensuring at least one IO request is sent
        if (startPos != endPos && (dataEndPos - startPos > decoder->io_size_max || dataEndPos - endPos > decoder->io_size_merge)) {
            break;
        }
        endPos = dataEndPos;
        chunkIndex = data_read->nextChunk.lowerBound;
        
        if (chunkIndex + 1 >= data_read->nextChunk.upperBound) {
            if (!_om_decoder_next_chunk_position(decoder, &data_read->nextChunk)) {
                // No next chunk, finish processing the current one and stop
                break;
            }
        } else {
            data_read->nextChunk.lowerBound += 1;
        }
        
        if (data_read->nextChunk.lowerBound >= data_read->indexRange.upperBound) {
            data_read->nextChunk.lowerBound = 0;
            data_read->nextChunk.upperBound = 0;
            break;
        }
    }
    
    data_read->offset = (size_t)startPos;
    data_read->count = (size_t)endPos - (size_t)startPos;
    data_read->chunkIndex.upperBound = chunkIndex + 1;
    return true;
}

// Function to decode a single chunk.
uint64_t _om_decoder_decode_chunk(const om_decoder_t *decoder, uint64_t chunk, const void *data, void *into, void *chunk_buffer) {
    uint64_t rollingMultiply = 1;
    uint64_t rollingMultiplyChunkLength = 1;
    uint64_t rollingMultiplyTargetCube = 1;
    
    int64_t d = 0; // Read coordinate.
    int64_t q = 0; // Write coordinate.
    int64_t linearReadCount = 1;
    bool linearRead = true;
    int64_t lengthLast = 0;
    bool no_data = false;
    
    //printf("decode dimcount=%d \n", decoder->dims_count );
    
    // Count length in chunk and find first buffer offset position.
    for (int64_t i = decoder->dims_count - 1; i >= 0; --i) {
        uint64_t nChunksInThisDimension = divide_rounded_up(decoder->dims[i], decoder->chunks[i]);
        uint64_t c0 = (chunk / rollingMultiply) % nChunksInThisDimension;
        uint64_t length0 = min((c0+1) * decoder->chunks[i], decoder->dims[i]) - c0 * decoder->chunks[i];
        
        uint64_t chunkGlobal0Start = c0 * decoder->chunks[i];
        uint64_t chunkGlobal0End = chunkGlobal0Start + length0;
        uint64_t clampedGlobal0Start = max(chunkGlobal0Start, decoder->read_offset[i]);
        uint64_t clampedGlobal0End = min(chunkGlobal0End, decoder->read_offset[i] + decoder->read_count[i]);
        uint64_t clampedLocal0Start = clampedGlobal0Start - c0 * decoder->chunks[i];
        uint64_t lengthRead = clampedGlobal0End - clampedGlobal0Start;
        
        if (decoder->read_offset[i] + decoder->read_count[i] <= chunkGlobal0Start || decoder->read_offset[i] >= chunkGlobal0End) {
            no_data = true;
        }
        
        if (i == decoder->dims_count - 1) {
            lengthLast = length0;
        }
        
        uint64_t d0 = clampedLocal0Start;
        uint64_t t0 = chunkGlobal0Start - decoder->read_offset[i] + d0;
        uint64_t q0 = t0 + decoder->cube_offset[i];
        
        d += rollingMultiplyChunkLength * d0;
        q += rollingMultiplyTargetCube * q0;
        
        if (i == decoder->dims_count - 1 && !(lengthRead == length0 && decoder->read_count[i] == length0 && decoder->cube_dimensions[i] == length0)) {
            // if fast dimension and only partially read
            linearReadCount = lengthRead;
            linearRead = false;
        }
        
        if (linearRead && lengthRead == length0 && decoder->read_count[i] == length0 && decoder->cube_dimensions[i] == length0) {
            // dimension is read entirely
            // and can be copied linearly into the output buffer
            linearReadCount *= length0;
        } else {
            // dimension is read partly, cannot merge further reads
            linearRead = false;
        }
        
        rollingMultiply *= nChunksInThisDimension;
        rollingMultiplyTargetCube *= decoder->cube_dimensions[i];
        rollingMultiplyChunkLength *= length0;
    }
    
    uint64_t lengthInChunk = rollingMultiplyChunkLength;
    uint64_t uncompressedBytes;
    uint8_t *dataMutablePtr = (uint8_t *)data;
    
    // Handle decompression based on compression type and data type.
    switch (decoder->compression) {
        case P4NZDEC256:
        case P4NZDEC256_LOGARITHMIC:
            if (decoder->data_type == DATA_TYPE_FLOAT) {
                uncompressedBytes = p4nzdec128v16(dataMutablePtr, lengthInChunk, (uint16_t *)chunk_buffer);
            } else {
                // Handle other data types as needed.
                assert(0 && "Unsupported data type for compression.");
            }
            break;
            
        case FPXDEC32:
            if (decoder->data_type == DATA_TYPE_FLOAT) {
                uncompressedBytes = fpxdec32(dataMutablePtr, lengthInChunk, (uint32_t *)chunk_buffer, 0);
            } else if (decoder->data_type == DATA_TYPE_DOUBLE) {
                uncompressedBytes = fpxdec64(dataMutablePtr, lengthInChunk, (uint64_t *)chunk_buffer, 0);
            } else {
                assert(0 && "Unsupported data type for compression.");
            }
            break;
            
        default:
            assert(0 && "Unsupported compression type.");
    }
    
    if (no_data) {
        return uncompressedBytes;
    }
    
    // Decode delta if necessary.
    switch (decoder->compression) {
        case P4NZDEC256:
            if (decoder->data_type == DATA_TYPE_FLOAT) {
                delta2d_decode(lengthInChunk / lengthLast, lengthLast, (uint16_t *)chunk_buffer);
            } else {
                assert(0 && "Unsupported data type for delta decoding.");
            }
            break;
            
        case FPXDEC32:
            if (decoder->data_type == DATA_TYPE_FLOAT) {
                delta2d_decode_xor(lengthInChunk / lengthLast, lengthLast, (float *)chunk_buffer);
            } else if (decoder->data_type == DATA_TYPE_DOUBLE) {
                delta2d_decode_xor_double(lengthInChunk / lengthLast, lengthLast, (double *)chunk_buffer);
            } else {
                assert(0 && "Unsupported data type for delta decoding.");
            }
            break;
            
        default:
            assert(0 && "Unsupported compression type for delta decoding.");
    }
    
    // Copy data from the chunk buffer to the output buffer.
    while (true) {
        /// Copy values from chunk buffer into output buffer
        (*decoder->copy_callback)(linearReadCount, d, q, decoder->scalefactor, chunk_buffer, into);
        
        q += linearReadCount - 1;
        d += linearReadCount - 1;
        
        rollingMultiply = 1;
        rollingMultiplyTargetCube = 1;
        rollingMultiplyChunkLength = 1;
        linearReadCount = 1;
        linearRead = true;
        for (int64_t i = decoder->dims_count-1; i >= 0; i--) {
            //printf("i=%d q=%d d=%d\n", i,q,d);
            uint64_t nChunksInThisDimension = divide_rounded_up(decoder->dims[i], decoder->chunks[i]);
            uint64_t c0 = (chunk / rollingMultiply) % nChunksInThisDimension;
            uint64_t length0 = min((c0+1) * decoder->chunks[i], decoder->dims[i]) - c0 * decoder->chunks[i];
            
            uint64_t chunkGlobal0Start = c0 * decoder->chunks[i];
            uint64_t chunkGlobal0End = chunkGlobal0Start + length0;
            uint64_t clampedGlobal0Start = max(chunkGlobal0Start, decoder->read_offset[i]);
            uint64_t clampedGlobal0End = min(chunkGlobal0End, decoder->read_offset[i] + decoder->read_count[i]);
            uint64_t clampedLocal0End = clampedGlobal0End - c0 * decoder->chunks[i];
            uint64_t lengthRead = clampedGlobal0End - clampedGlobal0Start;
            
            d += rollingMultiplyChunkLength;
            q += rollingMultiplyTargetCube;
            
            if ((i == decoder->dims_count - 1) && !(lengthRead == length0 && decoder->read_count[i] == length0 && decoder->cube_dimensions[i] == length0)) {
                // if fast dimension and only partially read
                linearReadCount = lengthRead;
                linearRead = false;
            }
            if (linearRead && (lengthRead == length0) && (decoder->read_count[i] == length0) && (decoder->cube_dimensions[i] == length0)) {
                // dimension is read entirely
                // and can be copied linearly into the output buffer
                linearReadCount *= length0;
            } else {
                // dimension is read partly, cannot merge further reads
                linearRead = false;
            }
            
            uint64_t d0 = (d / rollingMultiplyChunkLength) % length0;
            if (d0 != clampedLocal0End && d0 != 0) {
                //printf("break\n");
                break; // No overflow in this dimension, break
            }
            
            d -= lengthRead * rollingMultiplyChunkLength;
            q -= lengthRead * rollingMultiplyTargetCube;
            
            rollingMultiply *= nChunksInThisDimension;
            rollingMultiplyTargetCube *= decoder->cube_dimensions[i];
            rollingMultiplyChunkLength *= length0;
            //printf("next iter\n");
            if (i == 0) {
                //printf("return\n");
                return uncompressedBytes; // All chunks have been read. End of iteration
            }
        }
    }
    
    return uncompressedBytes;
}


// Function to decode multiple chunks inside data.
uint64_t om_decoder_decode_chunks(const om_decoder_t *decoder, om_range_t chunk, const void *data, uint64_t data_size, void *into, void *chunkBuffer) {
    uint64_t pos = 0;
    //printf("chunkIndex.lowerBound %d %d\n",chunkIndex.lowerBound,chunkIndex.upperBound);
    for (uint64_t chunkNum = chunk.lowerBound; chunkNum < chunk.upperBound; ++chunkNum) {
        //printf("chunkIndex %d pos=%d dataCount=%d \n",chunkNum, pos, dataCount);
        assert(pos < data_size);
        uint64_t uncompressedBytes = _om_decoder_decode_chunk(decoder, chunkNum, (const uint8_t *)data + pos, into, chunkBuffer);
        pos += uncompressedBytes;
    }
    //printf("%d %d \n", pos, dataCount);
    assert(pos == data_size);
    return pos;
}
