//
//  Header.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 29.10.2024.
//

#include "om_encoder.h"
#include <stdlib.h>
#include <assert.h>
#include <math.h>
#include "vp4.h"
#include "fp.h"
#include "delta2d.h"

#define P4NENC256_BOUND(n) ((n + 255) /256 + (n + 32) * sizeof(uint32_t))

/// Assume chunk buffer is a 16 bit integer array and convert to float
void om_encoder_copy_float_to_int16(uint64_t length, float scale_factor, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        float val = ((float *)src)[i];
        if (isnan(val)) {
            ((int16_t *)dst)[i] = INT16_MAX;
        } else {
            float scaled = val * scale_factor;
            ((int16_t *)dst)[i] = (int16_t)fmaxf(INT16_MIN, fminf(INT16_MAX, roundf(scaled)));
        }
    }
}

/// Assume chunk buffer is a 16 bit integer array and convert to float and scale log10
void om_encoder_copy_float_to_int16_log10(uint64_t length, float scale_factor, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        float val = ((float *)src)[i];
        if (isnan(val)) {
            ((float *)dst)[i] = INT16_MAX;
        } else {
            float scaled = log10f(1 + val) * scale_factor;
            ((float *)dst)[i] = (int16_t)fmaxf(INT16_MIN, fminf(INT16_MAX, roundf(scaled)));
        }
    }
}

void om_encoder_copy_float(uint64_t length, float scale_factor, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        ((float *)dst)[i] = ((float *)src)[i];
    }
}

void om_encoder_copy_double(uint64_t length, float scale_factor, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        ((double *)dst)[i] = ((double *)src)[i];
    }
}

uint64_t om_encoder_compress_fpxenc32(const void* src, uint64_t length, void* dst) {
    return fpxenc32((uint32_t*)src, length, (unsigned char *)dst, 0);
}

uint64_t om_encoder_compress_fpxenc64(const void* src, uint64_t length, void* dst) {
    return fpxenc64((uint64_t*)src, length, (unsigned char *)dst, 0);
}

// Initialize om_file_encoder
void om_encoder_init(om_encoder_t* encoder, float scalefactor, om_compression_t compression, om_datatype_t data_type, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count, uint64_t lut_chunk_element_count) {
    encoder->scalefactor = scalefactor;
    encoder->dimensions = dimensions;
    encoder->chunks = chunks;
    encoder->dimension_count = dimension_count;
    encoder->lut_chunk_element_count = lut_chunk_element_count;
    
    // TODO more compression and datatypes
    switch (compression) {
        case COMPRESSION_P4NZDEC256:
            encoder->bytes_per_element = 4;
            encoder->bytes_per_element_compressed = 2;
            encoder->compress_copy_callback = om_encoder_copy_float_to_int16;
            encoder->compress_filter_callback = (om_compress_filter_callback)delta2d_encode;
            encoder->compress_callback = (om_compress_callback)p4nzenc128v16;
            break;
            
        case COMPRESSION_FPXDEC32:
            if (data_type == DATA_TYPE_FLOAT) {
                encoder->bytes_per_element = 4;
                encoder->bytes_per_element_compressed = 4;
                encoder->compress_callback = om_encoder_compress_fpxenc32;
                encoder->compress_filter_callback = (om_compress_filter_callback)delta2d_encode_xor;
                encoder->compress_copy_callback = om_encoder_copy_float;
            } else if (data_type == DATA_TYPE_DOUBLE) {
                encoder->bytes_per_element = 8;
                encoder->bytes_per_element_compressed = 8;
                encoder->compress_callback = om_encoder_compress_fpxenc64;
                encoder->compress_filter_callback = (om_compress_filter_callback)delta2d_encode_xor_double;
                encoder->compress_copy_callback = om_encoder_copy_double;
            }
            break;
            
        case COMPRESSION_P4NZDEC256_LOGARITHMIC:
            encoder->bytes_per_element = 4;
            encoder->bytes_per_element_compressed = 2;
            encoder->compress_callback = (om_compress_callback)p4nzenc128v16;
            encoder->compress_filter_callback = (om_compress_filter_callback)delta2d_encode;
            encoder->compress_copy_callback = om_encoder_copy_float_to_int16_log10;
            break;
            
        default:
            assert(0 && "Unsupported compression type for copying data.");
    }
}

// Calculate number of chunks
uint64_t om_encoder_number_of_chunks(const om_encoder_t* encoder) {
    uint64_t n = 1;
    for (int i = 0; i < encoder->dimension_count; i++) {
        n *= divide_rounded_up(encoder->dimensions[i], encoder->chunks[i]);
    }
    return n;
}

uint64_t om_encoder_number_of_chunks_in_array(const om_encoder_t* encoder, const uint64_t* array_count) {
    uint64_t numberOfChunksInArray = 1;
    for (int i = 0; i < encoder->dimension_count; i++) {
        numberOfChunksInArray *= divide_rounded_up(array_count[i], encoder->chunks[i]);
    }
    return numberOfChunksInArray;
}

// Calculate chunk buffer size
uint64_t om_encoder_chunk_buffer_size(const om_encoder_t* encoder) {
    uint64_t chunkLength = 1;
    for (int i = 0; i < encoder->dimension_count; i++) {
        chunkLength *= encoder->chunks[i];
    }
    return P4NENC256_BOUND(chunkLength);
}

// Calculate minimum chunk write buffer size
uint64_t om_encoder_minimum_chunk_write_buffer(const om_encoder_t* encoder) {
    // TODO size of element
    return P4NENC256_BOUND(om_encoder_number_of_chunks(encoder));
}

// Calculate output buffer capacity to store compressed data and LUT. Minimum 4K.
uint64_t om_encoder_output_buffer_capacity(const om_encoder_t* encoder) {
    uint64_t bufferSize = om_encoder_chunk_buffer_size(encoder);
    uint64_t nChunks = om_encoder_number_of_chunks(encoder);
    uint64_t lutBufferSize = nChunks * 8;
    return max(4096, max(lutBufferSize, bufferSize));
}

// Calculate the size of the compressed LUT buffer
uint64_t om_encoder_compress_lut_buffer_size(const om_encoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount) {
    unsigned char buffer[MAX_LUT_ELEMENTS+32] = {0};
    uint64_t nLutChunks = divide_rounded_up(lookUpTableCount, encoder->lut_chunk_element_count);
    uint64_t maxLength = 0;
    for (int i = 0; i < nLutChunks; i++) {
        uint64_t rangeStart = i * encoder->lut_chunk_element_count;
        uint64_t rangeEnd = min(rangeStart + encoder->lut_chunk_element_count, lookUpTableCount);
        size_t len = p4ndenc64((uint64_t*)&lookUpTable[rangeStart], rangeEnd - rangeStart, buffer);
        if (len > maxLength) maxLength = len;
    }
    /// Compression function can write 32 integers more
    return maxLength * nLutChunks + 32 * sizeof(uint64_t);
}

// Compress the LUT to an output buffer and return the size of the compressed LUT
uint64_t om_encoder_compress_lut(const om_encoder_t* encoder, const uint64_t* lookUpTable, uint64_t lookUpTableCount, uint8_t* out, uint64_t compressed_lut_buffer_size) {
    uint64_t nLutChunks = divide_rounded_up(lookUpTableCount, encoder->lut_chunk_element_count);
    uint64_t lutChunkLength = compressed_lut_buffer_size / nLutChunks;

    for (uint64_t i = 0; i < nLutChunks; i++) {
        uint64_t rangeStart = i * encoder->lut_chunk_element_count;
        uint64_t rangeEnd = min(rangeStart + encoder->lut_chunk_element_count, lookUpTableCount);
        p4ndenc64((uint64_t*)&lookUpTable[rangeStart], rangeEnd - rangeStart, &out[i * lutChunkLength]);
    }
    return lutChunkLength * nLutChunks;
}

size_t om_encoder_compress_chunk(const om_encoder_t* encoder, const void* array, const uint64_t* arrayDimensions, const uint64_t* arrayOffset, const uint64_t* arrayCount, uint64_t chunkIndex, uint64_t chunkIndexOffsetInThisArray, uint8_t* out, uint64_t outSize, uint8_t* chunkBuffer) {
    /// The total size of `arrayDimensions`. Only used to check for out of bound reads
    uint64_t arrayTotalCount = 1;
    for (uint64_t i = 0; i < encoder->dimension_count; i++) {
        arrayTotalCount *= arrayDimensions[i];
    }
    
    uint64_t rollingMultiply = 1;
    uint64_t rollingMultiplyChunkLength = 1;
    uint64_t rollingMultiplyTargetCube = 1;
    uint64_t readCoordinate = 0;
    uint64_t writeCoordinate = 0;
    uint64_t linearReadCount = 1;
    bool linearRead = true;
    uint64_t lengthLast = 0;

    for (int64_t i = encoder->dimension_count - 1; i >= 0; i--) {
        uint64_t nChunksInThisDimension = divide_rounded_up(encoder->dimensions[i], encoder->chunks[i]);
        uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
        uint64_t c0Offset = (chunkIndexOffsetInThisArray / rollingMultiply) % nChunksInThisDimension;
        uint64_t length0 = min((c0 + 1) * encoder->chunks[i], encoder->dimensions[i]) - c0 * encoder->chunks[i];

        if (i == encoder->dimension_count - 1) {
            lengthLast = length0;
        }

        readCoordinate += rollingMultiplyTargetCube * (c0Offset * encoder->chunks[i] + arrayOffset[i]);
        assert(length0 <= arrayCount[i]);
        assert(length0 <= arrayDimensions[i]);

        if (i == encoder->dimension_count - 1 && !(arrayCount[i] == length0 && arrayDimensions[i] == length0)) {
            linearReadCount = length0;
            linearRead = false;
        }
        if (linearRead && arrayCount[i] == length0 && arrayDimensions[i] == length0) {
            linearReadCount *= length0;
        } else {
            linearRead = false;
        }

        rollingMultiply *= nChunksInThisDimension;
        rollingMultiplyTargetCube *= arrayDimensions[i];
        rollingMultiplyChunkLength *= length0;
    }

    uint64_t lengthInChunk = rollingMultiplyChunkLength;

    while (true) {
        assert(readCoordinate + linearReadCount <= arrayTotalCount);
        assert(writeCoordinate + linearReadCount <= lengthInChunk);
        (*encoder->compress_copy_callback)(linearReadCount, encoder->scalefactor, &array[encoder->bytes_per_element * readCoordinate], &chunkBuffer[encoder->bytes_per_element_compressed * writeCoordinate]);

        readCoordinate += linearReadCount - 1;
        writeCoordinate += linearReadCount - 1;
        writeCoordinate += 1;

        rollingMultiplyTargetCube = 1;
        linearRead = true;
        linearReadCount = 1;

        for (int64_t i = encoder->dimension_count - 1; i >= 0; i--) {
            uint64_t qPos = ((readCoordinate / rollingMultiplyTargetCube) % arrayDimensions[i] - arrayOffset[i]) / encoder->chunks[i];
            uint64_t length0 = min((qPos + 1) * encoder->chunks[i], arrayCount[i]) - qPos * encoder->chunks[i];
            readCoordinate += rollingMultiplyTargetCube;

            if (i == encoder->dimension_count - 1 && !(arrayCount[i] == length0 && arrayDimensions[i] == length0)) {
                linearReadCount = length0;
                linearRead = false;
            }
            if (linearRead && arrayCount[i] == length0 && arrayDimensions[i] == length0) {
                linearReadCount *= length0;
            } else {
                linearRead = false;
            }
            uint64_t q0 = ((readCoordinate / rollingMultiplyTargetCube) % arrayDimensions[i] - arrayOffset[i]) % encoder->chunks[i];
            if (q0 != 0 && q0 != length0) {
                break;
            }
            readCoordinate -= length0 * rollingMultiplyTargetCube;
            rollingMultiplyTargetCube *= arrayDimensions[i];

            if (i == 0) {
                (*encoder->compress_filter_callback)(lengthInChunk / lengthLast, lengthLast, chunkBuffer);
                return (*encoder->compress_callback)(chunkBuffer, lengthInChunk, out);
            }
        }
    }
}
