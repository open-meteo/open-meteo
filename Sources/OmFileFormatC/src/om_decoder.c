//
//  om_decoder.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 22.10.2024.
//

#include "vp4.h"
#include "fp.h"
#include "delta2d.h"
#include "om_decoder.h"


void om_decoder_init_data_read(OmDecoder_dataRead_t *data_read, const OmDecoder_indexRead_t *index_read) {
    data_read->offset = 0;
    data_read->count = 0;
    data_read->indexRange = index_read->indexRange;
    data_read->chunkIndex.lowerBound = 0;
    data_read->chunkIndex.upperBound = 0;
    data_read->nextChunk = index_read->chunkIndex;
}

OmError_t om_decoder_init(OmDecoder_t* decoder, const OmVariable_t* variable, uint64_t dimension_count, const uint64_t* read_offset, const uint64_t* read_count, const uint64_t* cube_offset, const uint64_t* cube_dimensions, uint64_t io_size_merge, uint64_t io_size_max) {
    
    float scalefactor, add_offset;
    const uint64_t *dimensions, *chunks;
    //uint64_t dimension_count_file;
    OmDataType_t data_type;
    OmCompression_t compression;
    uint64_t lut_size, lut_start, lut_chunk_length;
    
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY: {
            const OmHeaderV1_t* metaV1 = (const OmHeaderV1_t*)variable;
            scalefactor = metaV1->scale_factor;
            add_offset = 0;
            //dimension_count_file = 2;
            data_type = DATA_TYPE_FLOAT_ARRAY;
            compression = (OmCompression_t)metaV1->compression_type;
            if (metaV1->version == 1) {
                compression = COMPRESSION_PFOR_16BIT_DELTA2D;
            }
            lut_chunk_length = 0;
            lut_start = 40; // Right after header
            lut_size = 0; // ignored
            dimensions = &metaV1->dim0;
            chunks = &metaV1->chunk0;
            break;
        }
        case OM_MEMORY_LAYOUT_ARRAY: {
            const OmVariableArrayV3_t* metaV3 = (const OmVariableArrayV3_t*)variable;
            scalefactor = metaV3->scale_factor;
            add_offset = metaV3->add_offset;
            data_type = metaV3->data_type;
            compression = metaV3->compression_type;
            lut_size = metaV3->lut_size;
            lut_start = metaV3->lut_offset;
            dimensions = om_variable_get_dimensions(variable).values;
            chunks = om_variable_get_chunks(variable).values;
            lut_chunk_length = 1;
            break;
        }
        case OM_MEMORY_LAYOUT_SCALAR:
            return ERROR_INVALID_DATA_TYPE;
    }
    
    // Calculate the number of chunks based on dims and chunks
    uint64_t nChunks = 1;
    for (uint64_t i = 0; i < dimension_count; i++) {
        nChunks *= divide_rounded_up(dimensions[i], chunks[i]);
    }
    
    // Correctly calculate number of chunks
    if (lut_chunk_length > 0) {
        const uint64_t nLutChunks = divide_rounded_up(nChunks, LUT_CHUNK_COUNT);
        lut_chunk_length = lut_size / nLutChunks;
    }
    
    decoder->number_of_chunks = nChunks;
    decoder->scale_factor = scalefactor;
    decoder->add_offset = add_offset;
    decoder->dimensions = dimensions;
    decoder->dimensions_count = dimension_count;
    decoder->chunks = chunks;
    decoder->read_offset = read_offset;
    decoder->read_count = read_count;
    decoder->cube_offset = cube_offset;
    decoder->cube_dimensions = cube_dimensions;
    decoder->lut_chunk_length = lut_chunk_length;
    decoder->lut_start = lut_start;
    decoder->io_size_merge = io_size_merge;
    decoder->io_size_max = io_size_max;
    
    // Set element sizes and copy function
    switch (data_type) {
        case DATA_TYPE_INT8_ARRAY:
        case DATA_TYPE_UINT8_ARRAY:
            decoder->bytes_per_element = 1;
            decoder->bytes_per_element_compressed = 1;
            decoder->decompress_copy_callback = om_common_copy8;
            break;
        
        case DATA_TYPE_INT16_ARRAY:
        case DATA_TYPE_UINT16_ARRAY:
            decoder->bytes_per_element = 2;
            decoder->bytes_per_element_compressed = 2;
            decoder->decompress_copy_callback = om_common_copy16;
            break;
            
        case DATA_TYPE_INT32_ARRAY:
        case DATA_TYPE_UINT32_ARRAY:
        case DATA_TYPE_FLOAT_ARRAY:
            decoder->bytes_per_element = 4;
            decoder->bytes_per_element_compressed = 4;
            decoder->decompress_copy_callback = om_common_copy32;
            break;
            
        case DATA_TYPE_INT64_ARRAY:
        case DATA_TYPE_UINT64_ARRAY:
        case DATA_TYPE_DOUBLE_ARRAY:
            decoder->bytes_per_element = 8;
            decoder->bytes_per_element_compressed = 8;
            decoder->decompress_copy_callback = om_common_copy32;
            break;
            
        default:
            return ERROR_INVALID_DATA_TYPE;
    }
    
    // TODO more compression and datatypes
    switch (compression) {
        case COMPRESSION_PFOR_16BIT_DELTA2D:
            if (data_type != DATA_TYPE_FLOAT_ARRAY) {
                return ERROR_INVALID_DATA_TYPE;
            }
            decoder->bytes_per_element = 4;
            decoder->bytes_per_element_compressed = 2;
            decoder->decompress_copy_callback = om_common_copy_int16_to_float;
            decoder->decompress_filter_callback = (om_compress_filter_callback_t)delta2d_decode;
            decoder->decompress_callback = (om_compress_callback_t)p4nzdec128v16;
            break;
            
        case COMPRESSION_FPX_XOR2D:
            switch (data_type) {
                case DATA_TYPE_FLOAT_ARRAY:
                    decoder->decompress_callback = om_common_decompress_fpxdec32;
                    decoder->decompress_filter_callback = (om_compress_filter_callback_t)delta2d_decode_xor;
                    break;
                    
                case DATA_TYPE_DOUBLE_ARRAY:
                    decoder->decompress_callback = om_common_decompress_fpxdec64;
                    decoder->decompress_filter_callback = (om_compress_filter_callback_t)delta2d_decode_xor_double;
                    break;
                    
                default:
                    return ERROR_INVALID_DATA_TYPE;
            }
            break;
            
        case COMPRESSION_PFOR_16BIT_DELTA2D_LOGARITHMIC:
            if (data_type != DATA_TYPE_FLOAT_ARRAY) {
                return ERROR_INVALID_DATA_TYPE;
            }
            decoder->bytes_per_element = 4;
            decoder->bytes_per_element_compressed = 2;
            decoder->decompress_copy_callback = om_common_copy_int16_to_float_log10;
            decoder->decompress_filter_callback = (om_compress_filter_callback_t)delta2d_decode;
            decoder->decompress_callback = (om_compress_callback_t)p4nzdec128v16;
            break;
            
        default:
            return ERROR_INVALID_COMPRESSION_TYPE;
    }
    return ERROR_OK;
}

void om_decoder_init_index_read(const OmDecoder_t* decoder, OmDecoder_indexRead_t *index_read) {
    uint64_t chunkStart = 0;
    uint64_t chunkEnd = 1;
    
    for (uint64_t i = 0; i < decoder->dimensions_count; i++) {
        const uint64_t dimension = decoder->dimensions[i];
        const uint64_t chunk = decoder->chunks[i];
        const uint64_t read_offset = decoder->read_offset[i];
        const uint64_t read_count = decoder->read_count[i];
        //printf("dimension=%llu chunk=%llu read_offset=%llu read_count=%llu\n", dimension,chunk,read_offset,read_count);
        
        // Calculate lower and upper chunk indices for the current dimension
        const uint64_t chunkInThisDimensionLower = read_offset / chunk;
        const uint64_t chunkInThisDimensionUpper = divide_rounded_up(read_offset + read_count, chunk);
        const uint64_t chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower;
        
        const uint64_t firstChunkInThisDimension = chunkInThisDimensionLower;
        const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
        
        // Update chunkStart and chunkEnd
        chunkStart = chunkStart * nChunksInThisDimension + firstChunkInThisDimension;
        
        if (read_count == dimension) {
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

uint64_t om_decoder_read_buffer_size(const OmDecoder_t* decoder) {
    uint64_t chunkLength = 1;
    for (uint64_t i = 0; i < decoder->dimensions_count; i++) {
        chunkLength *= decoder->chunks[i];
    }
    return chunkLength * decoder->bytes_per_element;
}

bool _om_decoder_next_chunk_position(const OmDecoder_t *decoder, OmRange_t *chunk_index) {
    uint64_t rollingMultiply = 1;
    
    // Number of consecutive chunks that can be read linearly.
    uint64_t linearReadCount = 1;
    bool linearRead = true;
    const uint64_t dimensions_count = decoder->dimensions_count;
    
    for (int64_t i = dimensions_count - 1; i >= 0; --i) {
        const uint64_t dimension = decoder->dimensions[i];
        const uint64_t chunk = decoder->chunks[i];
        const uint64_t read_offset = decoder->read_offset[i];
        const uint64_t read_count = decoder->read_count[i];
        
        // Number of chunks in this dimension.
        const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
        
        // Calculate chunk range in this dimension.
        const uint64_t chunkInThisDimensionLower = read_offset / chunk;
        const uint64_t chunkInThisDimensionUpper = divide_rounded_up(read_offset + read_count, chunk);
        const uint64_t chunkInThisDimensionCount = chunkInThisDimensionUpper - chunkInThisDimensionLower;
        
        // Move forward by one.
        chunk_index->lowerBound += rollingMultiply;
        
        // Check for linear read conditions.
        if (i == dimensions_count - 1 && dimension != read_count) {
            // If the fast dimension is only partially read.
            linearReadCount = chunkInThisDimensionCount;
            linearRead = false;
        }
        
        if (linearRead && dimension == read_count) {
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

bool om_decoder_next_index_read(const OmDecoder_t* decoder, OmDecoder_indexRead_t* index_read) {
    if (index_read->nextChunk.lowerBound >= index_read->nextChunk.upperBound) {
        return false;
    }
    
    index_read->chunkIndex = index_read->nextChunk;
    index_read->indexRange.lowerBound = index_read->nextChunk.lowerBound;
    
    uint64_t chunkIndex = index_read->nextChunk.lowerBound;
    
    const bool isV3LUT = decoder->lut_chunk_length > 1;
    const uint64_t lut_chunk_element_count = isV3LUT ? LUT_CHUNK_COUNT : 1;
    const uint64_t lut_chunk_length = isV3LUT ? decoder->lut_chunk_length : sizeof(uint64_t);
    const uint64_t io_size_max = decoder->io_size_max;
    
    const uint64_t alignOffset = isV3LUT || index_read->indexRange.lowerBound == 0 ? 0 : 1;
    const uint64_t endAlignOffset = isV3LUT ? 1 : 0;
    
    const uint64_t readStart = (index_read->nextChunk.lowerBound - alignOffset) / lut_chunk_element_count * lut_chunk_length;
    
    while (1) {
        const uint64_t maxRead = io_size_max / lut_chunk_length * lut_chunk_element_count;
        const uint64_t nextChunkCount = index_read->nextChunk.upperBound - index_read->nextChunk.lowerBound;
        const uint64_t nextIncrement = max(1, min(maxRead-1, nextChunkCount - 1));
        
        if (index_read->nextChunk.lowerBound + nextIncrement >= index_read->nextChunk.upperBound) {
            if (!_om_decoder_next_chunk_position(decoder, &index_read->nextChunk)) {
                break;
            }
            const uint64_t readEndNext = (index_read->nextChunk.lowerBound + endAlignOffset) / lut_chunk_element_count * lut_chunk_length;
            const uint64_t readStartNext = readEndNext - lut_chunk_length;
            const uint64_t readEndPrevious = chunkIndex / lut_chunk_element_count * lut_chunk_length;
            
            if (readEndNext - readStart > io_size_max) {
                break;
            }
            if (readStartNext - readEndPrevious > decoder->io_size_merge) {
                break;
            }
        } else {
            const uint64_t readEndNext = (index_read->nextChunk.lowerBound + nextIncrement + endAlignOffset) / lut_chunk_element_count * lut_chunk_length;
            
            if (readEndNext - readStart > io_size_max) {
                index_read->nextChunk.lowerBound += 1;
                break;
            }
            index_read->nextChunk.lowerBound += nextIncrement;
        }
        chunkIndex = index_read->nextChunk.lowerBound;
    }
    
    const uint64_t readEnd = ((chunkIndex + endAlignOffset) / lut_chunk_element_count + 1) * lut_chunk_length;
    //uint64_t lutTotalSize = divide_rounded_up(decoder->number_of_chunks, decoder->lut_chunk_element_count) * lut_chunk_length;
    //assert(readEnd <= lutTotalSize);
    
    index_read->offset = decoder->lut_start + readStart;
    index_read->count = readEnd - readStart;
    index_read->indexRange.upperBound = chunkIndex + 1;
    return true;
}

bool om_decoder_next_data_read(const OmDecoder_t *decoder, OmDecoder_dataRead_t* data_read, const void* index_data, uint64_t index_data_size, OmError_t* error) {
    if (data_read->nextChunk.lowerBound >= data_read->nextChunk.upperBound) {
        return false;
    }
    
    uint64_t chunkIndex = data_read->nextChunk.lowerBound;
    data_read->chunkIndex.lowerBound = chunkIndex;
    
    // Version 1 case
    if (decoder->lut_chunk_length == 0) {
        // index is a flat Int64 array
        const uint64_t* data = (const uint64_t*)index_data;
        
        const bool isOffset0 = (data_read->indexRange.lowerBound == 0);
        const uint64_t startOffset = isOffset0 ? 1 : 0;
        
        
        uint64_t readPos = chunkIndex - data_read->indexRange.lowerBound - startOffset;
        //printf("chunkIndex %llu lowerBound %llu readPos %llu \n", chunkIndex, data_read->indexRange.lowerBound, readPos);
        if (!isOffset0 && (readPos + 1) * sizeof(int64_t) > index_data_size) {
            (*error) = ERROR_OUT_OF_BOUND_READ;
            return false;
        }
        
        const uint64_t startPos = isOffset0 && chunkIndex == 0 ? 0 : data[readPos];
        uint64_t endPos = startPos;
        
        // Loop to the next chunk until the end is reached
        while (true) {
            readPos = data_read->nextChunk.lowerBound - data_read->indexRange.lowerBound - startOffset + 1;
            if ((readPos + 1) * sizeof(int64_t) > index_data_size) {
                (*error) = ERROR_OUT_OF_BOUND_READ;
                return false;
            }
            const uint64_t dataEndPos = data[readPos];
            
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
        const uint64_t om_header_v1_length = sizeof(OmHeaderV1_t);
        const uint64_t dataStart = om_header_v1_length + decoder->number_of_chunks * sizeof(int64_t);
        
        data_read->offset = startPos + dataStart;
        data_read->count = endPos - startPos;
        data_read->chunkIndex.upperBound = chunkIndex + 1;
        return true;
    }
    
    uint8_t* indexDataPtr = (uint8_t*)index_data;
    
    uint64_t uncompressedLut[LUT_CHUNK_COUNT] = {0};
    
    // Which LUT chunk is currently loaded into `uncompressedLut`
    uint64_t lutChunk = chunkIndex / LUT_CHUNK_COUNT;
    
    const uint64_t lutChunkLength = decoder->lut_chunk_length;
    
    // Offset byte in LUT relative to the index range
    const uint64_t lutOffset = data_read->indexRange.lowerBound / LUT_CHUNK_COUNT * lutChunkLength;
    
    // Uncompress the first LUT index chunk and check the length
    {
        const uint64_t thisLutChunkElementCount = min((lutChunk + 1) * LUT_CHUNK_COUNT, decoder->number_of_chunks+1) - lutChunk * LUT_CHUNK_COUNT;
        const uint64_t start = lutChunk * lutChunkLength - lutOffset;
        if (start + lutChunkLength > index_data_size) {
            (*error) = ERROR_OUT_OF_BOUND_READ;
            return false;
        }
        
        // Decompress LUT chunk
        p4nddec64(indexDataPtr + start, thisLutChunkElementCount, uncompressedLut);
    }
    
    // Index data relative to start index
    const uint64_t startPos = uncompressedLut[chunkIndex % LUT_CHUNK_COUNT];
    uint64_t endPos = startPos;
    
    // Loop to the next chunk until the end is reached
    while (true) {
        const uint64_t nextLutChunk = (data_read->nextChunk.lowerBound + 1) / LUT_CHUNK_COUNT;
        
        // Maybe the next LUT chunk needs to be uncompressed
        if (nextLutChunk != lutChunk) {
            const uint64_t nextLutChunkElementCount = min((nextLutChunk + 1) * LUT_CHUNK_COUNT, decoder->number_of_chunks+1) - nextLutChunk * LUT_CHUNK_COUNT;
            const uint64_t start = nextLutChunk * lutChunkLength - lutOffset;
            if (start + lutChunkLength > index_data_size) {
                (*error) = ERROR_OUT_OF_BOUND_READ;
                return false;
            }
            
            // Decompress LUT chunk
            p4nddec64(indexDataPtr + start, nextLutChunkElementCount, uncompressedLut);
            lutChunk = nextLutChunk;
        }
        
        const uint64_t dataEndPos = uncompressedLut[(data_read->nextChunk.lowerBound + 1) % LUT_CHUNK_COUNT];
        
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
    
    data_read->offset = (uint64_t)startPos;
    data_read->count = (uint64_t)endPos - (uint64_t)startPos;
    data_read->chunkIndex.upperBound = chunkIndex + 1;
    return true;
}

// Internal function to decode a single chunk.
uint64_t _om_decoder_decode_chunk(const OmDecoder_t *decoder, uint64_t chunkIndex, const void *data, void *into, void *chunk_buffer) {
    uint64_t rollingMultiply = 1;
    uint64_t rollingMultiplyChunkLength = 1;
    uint64_t rollingMultiplyTargetCube = 1;
    
    int64_t d = 0; // Read coordinate.
    int64_t q = 0; // Write coordinate.
    int64_t linearReadCount = 1;
    bool linearRead = true;
    int64_t lengthLast = 0;
    bool no_data = false;
    
    const uint64_t dimensions_count = decoder->dimensions_count;
    
    //printf("decode dimcount=%d \n", decoder->dims_count );
    
    // Count length in chunk and find first buffer offset position.
    for (int64_t i = dimensions_count - 1; i >= 0; --i) {
        const uint64_t dimension = decoder->dimensions[i];
        const uint64_t chunk = decoder->chunks[i];
        const uint64_t read_offset = decoder->read_offset[i];
        const uint64_t read_count = decoder->read_count[i];
        const uint64_t cube_offset = decoder->cube_offset[i];
        const uint64_t cube_dimension = decoder->cube_dimensions[i];
        
        const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
        const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
        const uint64_t chunkGlobal0Start = c0 * chunk;
        const uint64_t chunkGlobal0End = min((c0+1) * chunk, dimension);
        const uint64_t length0 = chunkGlobal0End - chunkGlobal0Start;
        const uint64_t clampedGlobal0Start = max(chunkGlobal0Start, read_offset);
        const uint64_t clampedGlobal0End = min(chunkGlobal0End, read_offset + read_count);
        const uint64_t clampedLocal0Start = clampedGlobal0Start - c0 * chunk;
        const uint64_t lengthRead = clampedGlobal0End - clampedGlobal0Start;
        
        if (read_offset + read_count <= chunkGlobal0Start || read_offset >= chunkGlobal0End) {
            no_data = true;
        }
        
        if (i == dimensions_count - 1) {
            lengthLast = length0;
        }
        
        const uint64_t d0 = clampedLocal0Start;
        const uint64_t t0 = chunkGlobal0Start - read_offset + d0;
        const uint64_t q0 = t0 + cube_offset;
        
        d += rollingMultiplyChunkLength * d0;
        q += rollingMultiplyTargetCube * q0;
        
        if (i == dimensions_count - 1 && !(lengthRead == length0 && read_count == length0 && cube_dimension == length0)) {
            // if fast dimension and only partially read
            linearReadCount = lengthRead;
            linearRead = false;
        }
        
        if (linearRead && lengthRead == length0 && read_count == length0 && cube_dimension == length0) {
            // dimension is read entirely
            // and can be copied linearly into the output buffer
            linearReadCount *= length0;
        } else {
            // dimension is read partly, cannot merge further reads
            linearRead = false;
        }
        
        rollingMultiply *= nChunksInThisDimension;
        rollingMultiplyTargetCube *= cube_dimension;
        rollingMultiplyChunkLength *= length0;
    }
    
    const uint64_t lengthInChunk = rollingMultiplyChunkLength;
    const uint64_t uncompressedBytes = (*decoder->decompress_callback)(data, lengthInChunk, chunk_buffer);
    
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
        for (int64_t i = dimensions_count-1; i >= 0; i--) {
            const uint64_t dimension = decoder->dimensions[i];
            const uint64_t chunk = decoder->chunks[i];
            const uint64_t read_offset = decoder->read_offset[i];
            const uint64_t read_count = decoder->read_count[i];
            const uint64_t cube_dimension = decoder->cube_dimensions[i];
            
            //printf("i=%d q=%d d=%d\n", i,q,d);
            const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
            const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
            const uint64_t chunkGlobal0Start = c0 * chunk;
            const uint64_t chunkGlobal0End = min((c0+1) * chunk, dimension);
            const uint64_t length0 = chunkGlobal0End - chunkGlobal0Start;
            const uint64_t clampedGlobal0Start = max(chunkGlobal0Start, read_offset);
            const uint64_t clampedGlobal0End = min(chunkGlobal0End, read_offset + read_count);
            const uint64_t clampedLocal0End = clampedGlobal0End - chunkGlobal0Start;
            const uint64_t lengthRead = clampedGlobal0End - clampedGlobal0Start;
            
            d += rollingMultiplyChunkLength;
            q += rollingMultiplyTargetCube;
            
            if ((i == dimensions_count - 1) && !(lengthRead == length0 && read_count == length0 && cube_dimension == length0)) {
                // if fast dimension and only partially read
                linearReadCount = lengthRead;
                linearRead = false;
            }
            if (linearRead && (lengthRead == length0) && (read_count == length0) && (cube_dimension == length0)) {
                // dimension is read entirely
                // and can be copied linearly into the output buffer
                linearReadCount *= length0;
            } else {
                // dimension is read partly, cannot merge further reads
                linearRead = false;
            }
            
            const uint64_t d0 = (d / rollingMultiplyChunkLength) % length0;
            if (d0 != clampedLocal0End && d0 != 0) {
                //printf("break\n");
                break; // No overflow in this dimension, break
            }
            
            d -= lengthRead * rollingMultiplyChunkLength;
            q -= lengthRead * rollingMultiplyTargetCube;
            
            rollingMultiply *= nChunksInThisDimension;
            rollingMultiplyTargetCube *= cube_dimension;
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

bool om_decoder_decode_chunks(const OmDecoder_t *decoder, OmRange_t chunk, const void *data, uint64_t data_size, void *into, void *chunkBuffer, OmError_t* error) {
    uint64_t pos = 0;
    //printf("chunkIndex.lowerBound %llu %llu\n",chunk.lowerBound,chunk.upperBound);
    for (uint64_t chunkNum = chunk.lowerBound; chunkNum < chunk.upperBound; ++chunkNum) {
        //printf("chunkIndex %llu pos=%llu dataCount=%llu \n",chunkNum, pos, data_size);
        if (pos >= data_size) {
            (*error) = ERROR_DEFLATED_SIZE_MISMATCH;
            return false;
        }
        uint64_t uncompressedBytes = _om_decoder_decode_chunk(decoder, chunkNum, (const uint8_t *)data + pos, into, chunkBuffer);
        pos += uncompressedBytes;
    }
    //printf("%llu %llu \n", pos, data_size);
    
    if (pos != data_size) {
        (*error) = ERROR_DEFLATED_SIZE_MISMATCH;
        return false;
    }
    return pos;
}
