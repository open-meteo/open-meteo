//
//  om_common.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 30.10.2024.
//

#include "om_common.h"
#include <stdlib.h>
#include <assert.h>
#include <math.h>
#include "vp4.h"
#include "fp.h"

/// Assume chunk buffer is a 16 bit integer array and convert to float
void om_common_copy_float_to_int16(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        float val = ((float *)src)[i];
        if (isnan(val)) {
            ((int16_t *)dst)[i] = INT16_MAX;
        } else {
            float scaled = val * scale_factor + add_offset;
            ((int16_t *)dst)[i] = (int16_t)fmaxf(INT16_MIN, fminf(INT16_MAX, roundf(scaled)));
        }
    }
}

/// Assume chunk buffer is a 16 bit integer array and convert to float and scale log10
void om_common_copy_float_to_int16_log10(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
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

/// Assume chunk buffer is a 16 bit integer array and convert to float
void om_common_copy_int16_to_float(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        int16_t val = ((int16_t *)src)[i];
        ((float *)dst)[i] = (val == INT16_MAX) ? NAN : (float)val / scale_factor - add_offset;
    }
}

/// Assume chunk buffer is a 16 bit integer array and convert to float and scale log10
void om_common_copy_int16_to_float_log10(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        int16_t val = ((int16_t *)src)[i];
        ((float *)dst)[i] = (val == INT16_MAX) ? NAN : powf(10, (float)val / scale_factor) - 1;
    }
}

void om_common_copy8(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        ((int8_t *)dst)[i] = ((int8_t *)src)[i];
    }
}

void om_common_copy16(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        ((int16_t *)dst)[i] = ((int16_t *)src)[i];
    }
}

void om_common_copy32(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        ((int32_t *)dst)[i] = ((int32_t *)src)[i];
    }
}

void om_common_copy64(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst) {
    for (uint64_t i = 0; i < length; ++i) {
        ((int64_t *)dst)[i] = ((int64_t *)src)[i];
    }
}

uint64_t om_common_compress_fpxenc32(const void* src, uint64_t length, void* dst) {
    return fpxenc32((uint32_t*)src, length, (unsigned char *)dst, 0);
}

uint64_t om_common_compress_fpxenc64(const void* src, uint64_t length, void* dst) {
    return fpxenc64((uint64_t*)src, length, (unsigned char *)dst, 0);
}

uint64_t om_common_decompress_fpxdec32(const void* src, uint64_t length, void* dst) {
    return fpxdec32((unsigned char *)src, length, (uint32_t *)dst, 0);
}

uint64_t om_common_decompress_fpxdec64(const void* src, uint64_t length, void* dst) {
    return fpxdec64((unsigned char *)src, length, (uint64_t *)dst, 0);
}

