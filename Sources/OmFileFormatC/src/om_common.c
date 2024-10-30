//
//  om_common.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 30.10.2024.
//

#include "om_common.h"
#include <stdlib.h>
#include <math.h>
#include "vp4.h"
#include "fp.h"

const char* OmError_string(OmError_t error) {
    switch (error) {
        case ERROR_OK:
            return "No error occured";
        case ERROR_INVALID_COMPRESSION_TYPE:
            return "Invalid compression type";
        case ERROR_INVALID_DATA_TYPE:
            return "Invalid data type";
        case ERROR_INVALID_LUT_CHUNK_LENGTH:
            return "Invalid LUT chunk length. Max 256.";
        case ERROR_OUT_OF_BOUND_READ:
            return "Corrupted data with potential out-of-bound read";
    }
    return "";
}

void om_common_copy_float_to_int16(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        float val = ((float *)src)[i];
        if (isnan(val)) {
            ((int16_t *)dst)[i] = INT16_MAX;
        } else {
            float scaled = val * scale_factor + add_offset;
            ((int16_t *)dst)[i] = (int16_t)fmaxf(INT16_MIN, fminf(INT16_MAX, roundf(scaled)));
        }
    }
}

void om_common_copy_float_to_int16_log10(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        float val = ((float *)src)[i];
        if (isnan(val)) {
            ((float *)dst)[i] = INT16_MAX;
        } else {
            float scaled = log10f(1 + val) * scale_factor;
            ((float *)dst)[i] = (int16_t)fmaxf(INT16_MIN, fminf(INT16_MAX, roundf(scaled)));
        }
    }
}

void om_common_copy_int16_to_float(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        int16_t val = ((int16_t *)src)[i];
        ((float *)dst)[i] = (val == INT16_MAX) ? NAN : (float)val / scale_factor - add_offset;
    }
}

void om_common_copy_int16_to_float_log10(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        int16_t val = ((int16_t *)src)[i];
        ((float *)dst)[i] = (val == INT16_MAX) ? NAN : powf(10, (float)val / scale_factor) - 1;
    }
}

void om_common_copy8(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        ((int8_t *)dst)[i] = ((int8_t *)src)[i];
    }
}

void om_common_copy16(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        ((int16_t *)dst)[i] = ((int16_t *)src)[i];
    }
}

void om_common_copy32(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        ((int32_t *)dst)[i] = ((int32_t *)src)[i];
    }
}

void om_common_copy64(size_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (size_t i = 0; i < length; ++i) {
        ((int64_t *)dst)[i] = ((int64_t *)src)[i];
    }
}

size_t om_common_compress_fpxenc32(const void* src, size_t length, void* dst) {
    return fpxenc32((uint32_t*)src, length, (unsigned char *)dst, 0);
}

size_t om_common_compress_fpxenc64(const void* src, size_t length, void* dst) {
    return fpxenc64((uint64_t*)src, length, (unsigned char *)dst, 0);
}

size_t om_common_decompress_fpxdec32(const void* src, size_t length, void* dst) {
    return fpxdec32((unsigned char *)src, length, (uint32_t *)dst, 0);
}

size_t om_common_decompress_fpxdec64(const void* src, size_t length, void* dst) {
    return fpxdec64((unsigned char *)src, length, (uint64_t *)dst, 0);
}

