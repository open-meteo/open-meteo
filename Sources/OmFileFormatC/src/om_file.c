//
//  om_file.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 24.11.2024.
//

#include "om_file.h"

size_t om_read_header_size() {
    return sizeof(OmHeaderV1_t);
}
size_t om_read_trailer_size() {
    return sizeof(OmTrailer_t);
}

OmHeaderType_t om_header_type(const void* src) {
    const OmHeaderV3_t* meta = (const OmHeaderV3_t*)src;
    if (meta->magic_number1 != 'O' || meta->magic_number2 != 'M' || meta->version > 3 || meta->version <= 0) {
        return OM_HEADER_INVALID;
    }
    return meta->version == 3 ? OM_HEADER_TRAILER : OM_HEADER_LEGACY;
}

OmError_t om_read_trailer(const void* src, OmOffsetSize_t* root) {
    const OmTrailer_t* meta = (const OmTrailer_t*)src;
    if (meta->magic_number1 != 'O' || meta->magic_number2 != 'M' || meta->version != 3) {
        return ERROR_NOT_AN_OM_FILE;
    }
    root->size = meta->root.size;
    root->offset = meta->root.offset;
    return ERROR_OK;
}


size_t om_write_header_size() {
    return sizeof(OmHeaderV3_t);
}

size_t om_write_trailer_size() {
    return sizeof(OmTrailer_t);
}

void om_write_header(void* dest) {
    OmHeaderV3_t* meta = (OmHeaderV3_t*)dest;
    meta->magic_number1 = 'O';
    meta->magic_number2 = 'M';
    meta->version = 3;
}

void om_write_trailer(void* dest, const OmOffsetSize_t root) {
    OmTrailer_t* meta = (OmTrailer_t*)dest;
    meta->magic_number1 = 'O';
    meta->magic_number2 = 'M';
    meta->version = 3;
    meta->reserved = 0;
    meta->reserved2 = 0;
    meta->root = root;
}
