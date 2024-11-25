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
    return meta->version == 3 ? OM_HEADER_TRAILER : OM_HEADER_LEGACY;
}

OmOffsetSize_t om_trailer_read(const void* src) {
    const OmTrailer_t* meta = (const OmTrailer_t*)src;
    if (meta->magic_number1 != 'O' || meta->magic_number2 != 'M' || meta->version != 3) {
        return (OmOffsetSize_t){.offset = 0, .size = 0};
    }
    return (OmOffsetSize_t){.offset = meta->root.offset, .size = meta->root.size};
}

void om_header_write(void* dest) {
    *(OmHeaderV3_t*)dest = (OmHeaderV3_t){
        .magic_number1 = 'O',
        .magic_number2 = 'M',
        .version = 3
    };
}

void om_trailer_write(void* dest, const OmOffsetSize_t root) {
    *(OmTrailer_t*)dest = (OmTrailer_t){
        .magic_number1 = 'O',
        .magic_number2 = 'M',
        .version = 3,
        .reserved = 0,
        .reserved2 = 0,
        .root = root
    };
}
