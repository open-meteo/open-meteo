//
//  om_file.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 24.11.2024.
//

#include "om_file.h"

size_t om_header_size() {
    return sizeof(OmHeaderV1_t);
}

size_t om_header_write_size() {
    return sizeof(OmHeaderV3_t);
}

size_t om_trailer_size() {
    return sizeof(OmTrailer_t);
}

OmHeaderType_t om_header_type(const void* src) {
    const OmHeaderV3_t* meta = (const OmHeaderV3_t*)src;
    if (meta->magic_number1 != 'O' || meta->magic_number2 != 'M' || meta->version > 3 || meta->version <= 0) {
        return OM_HEADER_INVALID;
    }
    return meta->version == 3 ? OM_HEADER_READ_TRAILER : OM_HEADER_LEGACY;
}

bool om_trailer_read(const void* src, uint64_t* offset, uint64_t* size) {
    const OmTrailer_t* meta = (const OmTrailer_t*)src;
    if (meta->magic_number1 != 'O' || meta->magic_number2 != 'M' || meta->version != 3) {
        *offset = 0;
        *size = 0;
        return false;
    }
    *offset = meta->root_offset;
    *size = meta->root_size;
    return true;
}

void om_header_write(void* dest) {
    *(OmHeaderV3_t*)dest = (OmHeaderV3_t){
        .magic_number1 = 'O',
        .magic_number2 = 'M',
        .version = 3
    };
}

void om_trailer_write(void* dest, uint64_t offset, uint64_t size) {
    *(OmTrailer_t*)dest = (OmTrailer_t){
        .magic_number1 = 'O',
        .magic_number2 = 'M',
        .version = 3,
        .reserved = 0,
        .reserved2 = 0,
        .root_size = size,
        .root_offset = offset
    };
}
