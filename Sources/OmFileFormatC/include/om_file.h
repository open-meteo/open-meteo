//
//  om_file.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 24.11.2024.
//


#ifndef OM_FILE_H
#define OM_FILE_H

#include "om_common.h"

typedef enum {
    OM_HEADER_INVALID = 0,
    OM_HEADER_LEGACY = 1,
    OM_HEADER_READ_TRAILER = 2,
} OmHeaderType_t;

/// Legacy files only contain one 2D array with attributes in the header
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
    uint32_t reserved2; // can later be used for a 32 bit hash. E.g. xxhash
    uint64_t root_offset;
    uint64_t root_size;
} OmTrailer_t;



/// Return the size in byte of the header that should be read. Always 40 byte to support legacy 2D files.
size_t om_header_size();

/// Size in bytes of the trailer that contains the root variable offset in newer files
size_t om_trailer_size();

/// The size of a OM header for newer files. Always 3 bytes.
size_t om_header_write_size();

/// Check if the header is a OM file header and return if its a legacy version or a new version file
OmHeaderType_t om_header_type(const void* src);

/// Read the trailer of an OM file to get the root variable. Size is set to 0 if this is not an OM file.
bool om_trailer_read(const void* src, uint64_t* offset, uint64_t* size);

/// Write an header for newer OM files
void om_header_write(void* dest);

/// Write an trailer for newer OM files including the root variable
void om_trailer_write(void* dest, uint64_t offset, uint64_t size);

#endif // OM_FILE_H
