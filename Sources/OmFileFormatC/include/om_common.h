//
//  om_common.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 29.10.2024.
//

#ifndef OM_COMMON_H
#define OM_COMMON_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

/// The function to convert a single a a sequence of elements and convert data type. Applies scale factor.
typedef void(*om_compress_copy_callback)(uint64_t length, float scalef_actor, const void* src, void* dest);

/// compress input, of n-elements to output and return number of compressed byte
typedef uint64_t(*om_compress_callback)(const void* src, uint64_t length, void* dest);

/// Perform a 2d filter operation
typedef void(*om_compress_filter_callback)(const size_t length0, const size_t length1, void* buffer);

#define MAX_LUT_ELEMENTS 256

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
typedef enum {
    COMPRESSION_P4NZDEC256 = 0,          // Lossy compression using 2D delta coding and scalefactor. Only supports float and scales to 16-bit integer.
    COMPRESSION_FPXDEC32 = 1,            // Lossless compression using 2D xor coding.
    COMPRESSION_P4NZDEC256_LOGARITHMIC = 3 // Similar to `P4NZDEC256` but applies `log10(1+x)` before.
} om_compression_t;


/// Divide and round up
#define divide_rounded_up(dividend,divisor) \
  ({ __typeof__ (dividend) _dividend = (dividend); \
      __typeof__ (divisor) _divisor = (divisor); \
    (_dividend + _divisor - 1) / _divisor; })

/// Maxima of 2 terms
#define max(a,b) \
  ({ __typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
    _a > _b ? _a : _b; })

/// Minima of 2 terms
#define min(a,b) \
  ({ __typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
    _a < _b ? _a : _b; })

#endif // OM_COMMON_H
