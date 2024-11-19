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
typedef void(*om_compress_copy_callback_t)(uint64_t length, float scale_factor, float add_offset, const void* src, void* dest);

/// compress input, of n-elements to output and return number of compressed byte
typedef uint64_t(*om_compress_callback_t)(const void* src, uint64_t length, void* dest);

/// Perform a 2d filter operation
typedef void(*om_compress_filter_callback_t)(const uint64_t length0, const uint64_t length1, void* buffer);

#define MAX_LUT_ELEMENTS 256

typedef enum {
    ERROR_OK = 0, // not an error
    ERROR_INVALID_COMPRESSION_TYPE = 1,
    ERROR_INVALID_DATA_TYPE = 2,
    ERROR_INVALID_LUT_CHUNK_LENGTH = 3,
    ERROR_OUT_OF_BOUND_READ = 4,
    ERROR_NOT_AN_OM_FILE = 5
} OmError_t;

const char* OmError_string(OmError_t error);

/// Data types
typedef enum {
    DATA_TYPE_NONE = 0,
    DATA_TYPE_INT8 = 1,
    DATA_TYPE_UINT8 = 2,
    DATA_TYPE_INT16 = 3,
    DATA_TYPE_UINT16 = 4,
    DATA_TYPE_INT32 = 5,
    DATA_TYPE_UINT32 = 6,
    DATA_TYPE_INT64 = 7,
    DATA_TYPE_UINT64 = 8,
    DATA_TYPE_FLOAT = 9,
    DATA_TYPE_DOUBLE = 10,
    DATA_TYPE_STRING = 11,
    DATA_TYPE_INT8_ARRAY = 12,
    DATA_TYPE_UINT8_ARRAY = 13,
    DATA_TYPE_INT16_ARRAY = 14,
    DATA_TYPE_UINT16_ARRAY = 15,
    DATA_TYPE_INT32_ARRAY = 16,
    DATA_TYPE_UINT32_ARRAY = 17,
    DATA_TYPE_INT64_ARRAY = 18,
    DATA_TYPE_UINT64_ARRAY = 19,
    DATA_TYPE_FLOAT_ARRAY = 20,
    DATA_TYPE_DOUBLE_ARRAY = 21,
    DATA_TYPE_STRING_ARRAY = 22
} OmDataType_t;

/// Compression types
typedef enum {
    COMPRESSION_PFOR_16BIT_DELTA2D = 0, // Lossy compression using 2D delta coding and scalefactor. Only supports float and scales to 16-bit integer.
    COMPRESSION_FPX_XOR2D = 1, // Lossless float/double compression using 2D xor coding.
    COMPRESSION_PFOR_16BIT_DELTA2D_LOGARITHMIC = 3, // Similar to `P4NZDEC256` but applies `log10(1+x)` before.
    COMPRESSION_NONE = 4
} OmCompression_t;

typedef struct {
    uint64_t offset;
    uint64_t size;
} OmOffsetSize_t;

/// Old files directly contain array information for 2 dimensional arrays
/// File content: Header, look-up-table, compressed data
typedef struct {
    uint8_t magic_number1;
    uint8_t magic_number2;
    uint8_t version;
    uint8_t compression_type; // OmCompression_t
    float scale_factor;
    uint64_t dim0;
    uint64_t dim1;
    uint64_t chunk0;
    uint64_t chunk1;
    // followed by lookup table and then data
} OmHeaderV1_t;

/// Newer version only contain magic number "OM" and the version 3
typedef struct {
    uint8_t magic_number1;
    uint8_t magic_number2;
    uint8_t version;
} OmHeaderV3_t;

/// Trailer only present in version 3 files
typedef struct {
    uint8_t magic_number1;
    uint8_t magic_number2;
    uint8_t version;
    uint8_t reserved;
    OmOffsetSize_t root; // 2x 64 bit
} OmTrailer_t;

typedef struct {
    uint8_t data_type; // OmDataType_t
    uint8_t compression_type; // OmCompression_t
    uint16_t length_of_name; // maximum 65k name strings
    uint32_t number_of_children;

    // Followed by payload: NOTE: Lets to try 64 bit align it somehow
    //uint32_t[number_of_children] children_length;
    //uint32_t[number_of_children] children_offset;
    
    // Scalars are now set
    //void* value;
    
    // name is always last
    //char[length_of_name] name;
} OmVariableV3_t;

typedef struct {
    uint8_t data_type; // OmDataType_t
    uint8_t compression_type; // OmCompression_t
    uint16_t length_of_name; // maximum 65k name strings
    uint32_t number_of_children;
    uint64_t lut_size;
    uint64_t lut_offset;
    uint64_t dimension_count;
    
    float scale_factor;
    float add_offset;
    
    // Followed by payload: NOTE: Lets to try 64 bit align it somehow
    //uint32_t[number_of_children] children_length;
    //uint32_t[number_of_children] children_offset;
    
    // Afterwards additional payload from value types
    //uint64_t[dimension_count] dimensions;
    //uint64_t[dimension_count] chunks;
    
    // name is always last
    //char[length_of_name] name;
} OmVariableArrayV3_t;

typedef struct {
    uint8_t data_type; // OmDataType_t
    uint8_t compression_type; // OmCompression_t
    uint16_t length_of_name; // maximum 65k name strings
    uint32_t number_of_children;
    uint64_t string_size;
    // followed by the string value
    // name is always last
    //char[length_of_name] name;
} OmVariablStringV3_t;


/// only expose an opague pointer
typedef void* OmVariable_t;

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

/// Copy 16 bit integer array and convert to float
void om_common_copy_float_to_int16(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);

/// Copy 16 bit integer array and convert to float and scale log10
void om_common_copy_float_to_int16_log10(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);

/// Convert int16 and scale to float
void om_common_copy_int16_to_float(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);

/// Convert int16 and scale to float with log10
void om_common_copy_int16_to_float_log10(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);

void om_common_copy8(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);
void om_common_copy16(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);
void om_common_copy32(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);
void om_common_copy64(uint64_t length, float scale_factor, float add_offset, const void* src, void* dst);

uint64_t om_common_compress_fpxenc32(const void* src, uint64_t length, void* dst);
uint64_t om_common_compress_fpxenc64(const void* src, uint64_t length, void* dst);
uint64_t om_common_decompress_fpxdec32(const void* src, uint64_t length, void* dst);
uint64_t om_common_decompress_fpxdec64(const void* src, uint64_t length, void* dst);



#endif // OM_COMMON_H
