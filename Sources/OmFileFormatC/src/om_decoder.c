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

// Initialization function for ChunkDataReadInstruction
void om_decoder_data_read_init(om_decoder_data_read_t *data_read, const om_decoder_index_read_t *index_read) {
    data_read->offset = 0;
    data_read->count = 0;
    data_read->indexRange = index_read->indexRange;
    data_read->chunkIndex.lowerBound = 0;
    data_read->chunkIndex.upperBound = 0;
    data_read->nextChunk = index_read->chunkIndex;
}


// Initialization function for OmFileDecoder
void om_decoder_init(om_decoder_t* decoder, float scalefactor, float add_offset, const om_compression_t compression, const om_datatype_t data_type, size_t dims_count, const size_t* dims, const size_t* chunks, const size_t* read_offset, const size_t* read_count, const size_t* cube_offset, const size_t* cube_dimensions, size_t lut_size, size_t lut_chunk_element_count, size_t lut_start, size_t io_size_merge, size_t io_size_max) {
    // Calculate the number of chunks based on dims and chunks
    size_t nChunks = 1;
    for (size_t i = 0; i < dims_count; i++) {
        nChunks *= divide_rounded_up(dims[i], chunks[i]);
    }
    size_t nLutChunks = divide_rounded_up(nChunks, lut_chunk_element_count);
    size_t lut_chunk_length = lut_size / nLutChunks;
    if (lut_chunk_element_count == 1) {
        // OLD v1 files do not use compressed LUT
        lut_chunk_length = 8;
    }
    
    decoder->number_of_chunks = nChunks;
    decoder->scale_factor = scalefactor;
    decoder->add_offset = add_offset;
    decoder->dimensions = dims;
    decoder->dimensions_count = dims_count;
    decoder->chunks = chunks;
    decoder->read_offset = read_offset;
    decoder->read_count = read_count;
    decoder->cube_offset = cube_offset;
    decoder->cube_dimensions = cube_dimensions;
    decoder->lut_chunk_length = lut_chunk_length;
    decoder->lut_chunk_element_count = lut_chunk_element_count;
    decoder->lut_start = lut_start;
    decoder->io_size_merge = io_size_merge;
    decoder->io_size_max = io_size_max;

    assert(lut_chunk_element_count > 0 && lut_chunk_element_count <= MAX_LUT_ELEMENTS);
    
    // TODO more compression and datatypes
    switch (compression) {
        case COMPRESSION_P4NZDEC256:
            decoder->bytes_per_element = 4;
            decoder->bytes_per_element_compressed = 2;
            decoder->decompress_copy_callback = om_common_copy_int16_to_float;
            decoder->decompress_filter_callback = (om_compress_filter_callback)delta2d_decode;
            decoder->decompress_callback = (om_compress_callback)p4nzdec128v16;
            break;
            
        case COMPRESSION_FPXDEC32:
            if (data_type == DATA_TYPE_FLOAT) {
                decoder->bytes_per_element = 4;
                decoder->bytes_per_element_compressed = 4;
                decoder->decompress_callback = om_common_decompress_fpxdec32;
                decoder->decompress_filter_callback = (om_compress_filter_callback)delta2d_decode_xor;
                decoder->decompress_copy_callback = om_common_copy32;
            } else if (data_type == DATA_TYPE_DOUBLE) {
                decoder->bytes_per_element = 8;
                decoder->bytes_per_element_compressed = 8;
                decoder->decompress_callback = om_common_decompress_fpxdec64;
                decoder->decompress_filter_callback = (om_compress_filter_callback)delta2d_decode_xor_double;
                decoder->decompress_copy_callback = om_common_copy64;
            }
            break;
            
        case COMPRESSION_P4NZDEC256_LOGARITHMIC:
            decoder->bytes_per_element = 4;
            decoder->bytes_per_element_compressed = 2;
            decoder->decompress_callback = (om_compress_callback)p4nzdec128v16;
            decoder->decompress_filter_callback = (om_compress_filter_callback)delta2d_decode;
            decoder->decompress_copy_callback = om_common_copy_int16_to_float_log10;
            break;
            
        default:
            assert(0 && "Unsupported compression type for copying data.");
    }
}


void om_decoder_index_read_init(const om_decoder_t* decoder, om_decoder_index_read_t *index_read) {
    size_t chunkStart = 0;
    size_t chunkEnd = 1;
    
    for (size_t i = 0; i < decoder->dimensions_count; i++) {
        // Calculate lower and upper chunk indices for the current dimension
        size_t chunkInThisDimensionLower = decoder->read_offset[i] / decoder->chunks[i];
        size_t chunkInThisDimensionUpper = divide_rounded_up(decoder->read_offset[i] + decoder->read_count[i], decoder->chunks[i]);
        size_t chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower;
        
        size_t firstChunkInThisDimension = chunkInThisDimensionLower;
        size_t nChunksInThisDimension = divide_rounded_up(decoder->dimensions[i], decoder->chunks[i]);
        
        // Update chunkStart and chunkEnd
        chunkStart = chunkStart * nChunksInThisDimension + firstChunkInThisDimension;
        
        if (decoder->read_count[i] == decoder->dimensions[i]) {
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
size_t om_decoder_read_buffer_size(const om_decoder_t* decoder) {
    size_t chunkLength = 1;
    for (size_t i = 0; i < decoder->dimensions_count; i++) {
        chunkLength *= decoder->chunks[i];
    }
    return chunkLength * decoder->bytes_per_element;
}

bool _om_decoder_next_chunk_position(const om_decoder_t *decoder, om_range_t *chunk_index) {
    size_t rollingMultiply = 1;
    
    // Number of consecutive chunks that can be read linearly.
    size_t linearReadCount = 1;
    bool linearRead = true;
    
    for (int64_t i = decoder->dimensions_count - 1; i >= 0; --i) {
        // Number of chunks in this dimension.
        size_t nChunksInThisDimension = divide_rounded_up(decoder->dimensions[i], decoder->chunks[i]);
        
        // Calculate chunk range in this dimension.
        size_t chunkInThisDimensionLower = decoder->read_offset[i] / decoder->chunks[i];
        size_t chunkInThisDimensionUpper = divide_rounded_up(decoder->read_offset[i] + decoder->read_count[i], decoder->chunks[i]);
        size_t chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower;
        
        // Move forward by one.
        chunk_index->lowerBound += rollingMultiply;
        
        // Check for linear read conditions.
        if (i == decoder->dimensions_count - 1 && decoder->dimensions[i] != decoder->read_count[i]) {
            // If the fast dimension is only partially read.
            linearReadCount = chunkInThisDimensionCount;
            linearRead = false;
        }
        
        if (linearRead && decoder->dimensions[i] == decoder->read_count[i]) {
            // The dimension is read entirely.
            linearReadCount *= nChunksInThisDimension;
        } else {
            // Dimension is read partly; cannot merge further reads.
            linearRead = false;
        }
        
        // Calculate the chunk index in this dimension.
        size_t c0 = (chunk_index->lowerBound / rollingMultiply) % nChunksInThisDimension;
        
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


bool om_decoder_next_index_read(const om_decoder_t* decoder, om_decoder_index_read_t* index_read) {
    if (index_read->nextChunk.lowerBound >= index_read->nextChunk.upperBound) {
        return false;
    }
    
    index_read->chunkIndex = index_read->nextChunk;
    index_read->indexRange.lowerBound = index_read->nextChunk.lowerBound;
    
    size_t chunkIndex = index_read->nextChunk.lowerBound;
    
    bool isV3LUT = decoder->lut_chunk_element_count > 1;
    size_t alignOffset = isV3LUT || index_read->indexRange.lowerBound == 0 ? 0 : 1;
    size_t endAlignOffset = isV3LUT ? 1 : 0;
    
    size_t readStart = (index_read->nextChunk.lowerBound - alignOffset) / decoder->lut_chunk_element_count * decoder->lut_chunk_length;
    
    while (1) {
        size_t maxRead = decoder->io_size_max / decoder->lut_chunk_length * decoder->lut_chunk_element_count;
        size_t nextIncrement = max(1, min(maxRead, index_read->nextChunk.upperBound - index_read->nextChunk.lowerBound - 1));
        
        if (index_read->nextChunk.lowerBound + nextIncrement >= index_read->nextChunk.upperBound) {
            if (!_om_decoder_next_chunk_position(decoder, &index_read->nextChunk)) {
                break;
            }
            size_t readStartNext = (index_read->nextChunk.lowerBound + endAlignOffset) / decoder->lut_chunk_element_count * decoder->lut_chunk_length - decoder->lut_chunk_length;
            size_t readEndPrevious = chunkIndex / decoder->lut_chunk_element_count * decoder->lut_chunk_length;
            
            if (readStartNext - readEndPrevious > decoder->io_size_merge) {
                break;
            }
        } else {
            index_read->nextChunk.lowerBound += nextIncrement;
        }
        
        size_t readEndNext = (index_read->nextChunk.lowerBound + endAlignOffset) / decoder->lut_chunk_element_count * decoder->lut_chunk_length;
        
        if (readEndNext - readStart > decoder->io_size_max) {
            break;
        }
        
        chunkIndex = index_read->nextChunk.lowerBound;
    }
    
    size_t readEnd = ((chunkIndex + endAlignOffset) / decoder->lut_chunk_element_count + 1) * decoder->lut_chunk_length;
    size_t lutTotalSize = divide_rounded_up(decoder->number_of_chunks, decoder->lut_chunk_element_count) * decoder->lut_chunk_length;
    assert(readEnd <= lutTotalSize);
    
    index_read->offset = decoder->lut_start + readStart;
    index_read->count = readEnd - readStart;
    index_read->indexRange.upperBound = chunkIndex + 1;
    return true;
}


bool om_decoder_next_data_read(const om_decoder_t *decoder, om_decoder_data_read_t* data_read, const void* index_data, size_t index_data_size) {
    if (data_read->nextChunk.lowerBound >= data_read->nextChunk.upperBound) {
        return false;
    }
    
    size_t chunkIndex = data_read->nextChunk.lowerBound;
    data_read->chunkIndex.lowerBound = chunkIndex;
    
    size_t lutChunkElementCount = decoder->lut_chunk_element_count;
    size_t lutChunkLength = decoder->lut_chunk_length;
    
    // Version 1 case
    if (decoder->lut_chunk_element_count == 1) {
        // index is a flat Int64 array
        const size_t* data = (const size_t*)index_data;
        
        bool isOffset0 = (data_read->indexRange.lowerBound == 0);
        size_t startOffset = isOffset0 ? 1 : 0;
        
        
        size_t readPos = data_read->indexRange.lowerBound - chunkIndex - startOffset;
        assert((readPos + 1) * sizeof(int64_t) <= index_data_size);
        
        size_t startPos = isOffset0 ? 0 : data[readPos];
        size_t endPos = startPos;
        
        // Loop to the next chunk until the end is reached
        while (true) {
            readPos = data_read->nextChunk.lowerBound - data_read->indexRange.lowerBound - startOffset + 1;
            assert((readPos + 1) * sizeof(int64_t) <= index_data_size);
            size_t dataEndPos = data[readPos];
            
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
        size_t om_header_v1_length = 40;
        size_t dataStart = om_header_v1_length + decoder->number_of_chunks * sizeof(int64_t);
        
        data_read->offset = startPos + dataStart;
        data_read->count = endPos - startPos;
        data_read->chunkIndex.upperBound = chunkIndex + 1;
        return true;
    }
    
    uint8_t* indexDataPtr = (uint8_t*)index_data;
    
    size_t uncompressedLut[MAX_LUT_ELEMENTS] = {0};
    
    // Which LUT chunk is currently loaded into `uncompressedLut`
    size_t lutChunk = chunkIndex / lutChunkElementCount;
    
    // Offset byte in LUT relative to the index range
    size_t lutOffset = data_read->indexRange.lowerBound / lutChunkElementCount * lutChunkLength;
    
    // Uncompress the first LUT index chunk and check the length
    {
        size_t thisLutChunkElementCount = min((lutChunk + 1) * lutChunkElementCount, decoder->number_of_chunks+1) - lutChunk * lutChunkElementCount;
        size_t start = lutChunk * lutChunkLength - lutOffset;
        assert(start >= 0);
        assert(start + lutChunkLength <= index_data_size);
        
        // Decompress LUT chunk
        p4nddec64(indexDataPtr + start, thisLutChunkElementCount, (uint64_t*)uncompressedLut);
    }
    
    // Index data relative to start index
    size_t startPos = uncompressedLut[chunkIndex % lutChunkElementCount];
    size_t endPos = startPos;
    
    // Loop to the next chunk until the end is reached
    while (true) {
        size_t nextLutChunk = (data_read->nextChunk.lowerBound + 1) / lutChunkElementCount;
        
        // Maybe the next LUT chunk needs to be uncompressed
        if (nextLutChunk != lutChunk) {
            size_t nextLutChunkElementCount = min((nextLutChunk + 1) * lutChunkElementCount, decoder->number_of_chunks+1) - nextLutChunk * lutChunkElementCount;
            size_t start = nextLutChunk * lutChunkLength - lutOffset;
            assert(start >= 0);
            assert(start + lutChunkLength <= index_data_size);
            
            // Decompress LUT chunk
            p4nddec64(indexDataPtr + start, nextLutChunkElementCount, (uint64_t*)uncompressedLut);
            lutChunk = nextLutChunk;
        }
        
        size_t dataEndPos = uncompressedLut[(data_read->nextChunk.lowerBound + 1) % lutChunkElementCount];
        
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
size_t _om_decoder_decode_chunk(const om_decoder_t *decoder, size_t chunk, const void *data, void *into, void *chunk_buffer) {
    size_t rollingMultiply = 1;
    size_t rollingMultiplyChunkLength = 1;
    size_t rollingMultiplyTargetCube = 1;
    
    int64_t d = 0; // Read coordinate.
    int64_t q = 0; // Write coordinate.
    int64_t linearReadCount = 1;
    bool linearRead = true;
    int64_t lengthLast = 0;
    bool no_data = false;
    
    //printf("decode dimcount=%d \n", decoder->dims_count );
    
    // Count length in chunk and find first buffer offset position.
    for (int64_t i = decoder->dimensions_count - 1; i >= 0; --i) {
        size_t nChunksInThisDimension = divide_rounded_up(decoder->dimensions[i], decoder->chunks[i]);
        size_t c0 = (chunk / rollingMultiply) % nChunksInThisDimension;
        size_t length0 = min((c0+1) * decoder->chunks[i], decoder->dimensions[i]) - c0 * decoder->chunks[i];
        
        size_t chunkGlobal0Start = c0 * decoder->chunks[i];
        size_t chunkGlobal0End = chunkGlobal0Start + length0;
        size_t clampedGlobal0Start = max(chunkGlobal0Start, decoder->read_offset[i]);
        size_t clampedGlobal0End = min(chunkGlobal0End, decoder->read_offset[i] + decoder->read_count[i]);
        size_t clampedLocal0Start = clampedGlobal0Start - c0 * decoder->chunks[i];
        size_t lengthRead = clampedGlobal0End - clampedGlobal0Start;
        
        if (decoder->read_offset[i] + decoder->read_count[i] <= chunkGlobal0Start || decoder->read_offset[i] >= chunkGlobal0End) {
            no_data = true;
        }
        
        if (i == decoder->dimensions_count - 1) {
            lengthLast = length0;
        }
        
        size_t d0 = clampedLocal0Start;
        size_t t0 = chunkGlobal0Start - decoder->read_offset[i] + d0;
        size_t q0 = t0 + decoder->cube_offset[i];
        
        d += rollingMultiplyChunkLength * d0;
        q += rollingMultiplyTargetCube * q0;
        
        if (i == decoder->dimensions_count - 1 && !(lengthRead == length0 && decoder->read_count[i] == length0 && decoder->cube_dimensions[i] == length0)) {
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
    
    size_t lengthInChunk = rollingMultiplyChunkLength;
    size_t uncompressedBytes = (*decoder->decompress_callback)(data, lengthInChunk, chunk_buffer);
    
    if (no_data) {
        return uncompressedBytes;
    }
    
    /// Perform 2D decoding
    (*decoder->decompress_filter_callback)(lengthInChunk / lengthLast, lengthLast, chunk_buffer);
    
    // Copy data from the chunk buffer to the output buffer.
    while (true) {
        /// Copy values from chunk buffer into output buffer
        (*decoder->decompress_copy_callback)(linearReadCount, decoder->scale_factor, decoder->add_offset, &chunk_buffer[d * decoder->bytes_per_element_compressed], &into[q * decoder->bytes_per_element]);
        
        q += linearReadCount - 1;
        d += linearReadCount - 1;
        
        rollingMultiply = 1;
        rollingMultiplyTargetCube = 1;
        rollingMultiplyChunkLength = 1;
        linearReadCount = 1;
        linearRead = true;
        for (int64_t i = decoder->dimensions_count-1; i >= 0; i--) {
            //printf("i=%d q=%d d=%d\n", i,q,d);
            size_t nChunksInThisDimension = divide_rounded_up(decoder->dimensions[i], decoder->chunks[i]);
            size_t c0 = (chunk / rollingMultiply) % nChunksInThisDimension;
            size_t length0 = min((c0+1) * decoder->chunks[i], decoder->dimensions[i]) - c0 * decoder->chunks[i];
            
            size_t chunkGlobal0Start = c0 * decoder->chunks[i];
            size_t chunkGlobal0End = chunkGlobal0Start + length0;
            size_t clampedGlobal0Start = max(chunkGlobal0Start, decoder->read_offset[i]);
            size_t clampedGlobal0End = min(chunkGlobal0End, decoder->read_offset[i] + decoder->read_count[i]);
            size_t clampedLocal0End = clampedGlobal0End - c0 * decoder->chunks[i];
            size_t lengthRead = clampedGlobal0End - clampedGlobal0Start;
            
            d += rollingMultiplyChunkLength;
            q += rollingMultiplyTargetCube;
            
            if ((i == decoder->dimensions_count - 1) && !(lengthRead == length0 && decoder->read_count[i] == length0 && decoder->cube_dimensions[i] == length0)) {
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
            
            size_t d0 = (d / rollingMultiplyChunkLength) % length0;
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
size_t om_decoder_decode_chunks(const om_decoder_t *decoder, om_range_t chunk, const void *data, size_t data_size, void *into, void *chunkBuffer) {
    size_t pos = 0;
    //printf("chunkIndex.lowerBound %d %d\n",chunkIndex.lowerBound,chunkIndex.upperBound);
    for (size_t chunkNum = chunk.lowerBound; chunkNum < chunk.upperBound; ++chunkNum) {
        //printf("chunkIndex %d pos=%d dataCount=%d \n",chunkNum, pos, dataCount);
        assert(pos < data_size);
        size_t uncompressedBytes = _om_decoder_decode_chunk(decoder, chunkNum, (const uint8_t *)data + pos, into, chunkBuffer);
        pos += uncompressedBytes;
    }
    //printf("%d %d \n", pos, dataCount);
    assert(pos == data_size);
    return pos;
}
