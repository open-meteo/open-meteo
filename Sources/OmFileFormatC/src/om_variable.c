//
//  om_variable.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 16.11.2024.
//

#include "om_variable.h"

size_t om_read_header_size() {
    return sizeof(OmHeaderV1_t);
}
size_t om_read_trailer_size() {
    return sizeof(OmTrailer_t);
}


OmError_t om_read_header(const void* src, OmOffsetSize_t* root) {
    return 0;
}
OmError_t om_read_trailer(const void* src, OmOffsetSize_t* root) {
    return 0;
}

const OmVariable_t* om_variable_init(const void* src) {
    return NULL;
}

void om_variable_get_name(const OmVariable_t* variable, uint16_t* name_length, char** name) {
    
}

OmDataType_t om_variable_get_type(const OmVariable_t* variable) {
    return 0;
}

bool _om_variable_is_version3(const OmVariable_t* variable) {
    return false;
}

uint64_t om_variable_number_of_dimensions(const OmVariable_t* variable) {
    return 0;
}

const uint64_t* om_variable_get_dimensions(const OmVariable_t* variable) {
    return NULL;
}

const uint64_t* om_variable_get_chunks(const OmVariable_t* variable) {
    return NULL;
}

uint32_t om_variable_number_of_children(const OmVariable_t* variable) {
    return 0;
}

void om_variable_get_child(const OmVariable_t* variable, int nChild, OmOffsetSize_t* child) {
}

OmError_t om_variable_read_scalar(const OmVariable_t* variable, void* value) {
    return 0;
}

size_t om_variable_write_scalar_size(uint16_t length_of_name, uint32_t number_of_children, OmDataType_t data_type) {
    return 0;
}

void om_variable_write_scalar(void* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, const void* value) {
    return;
}

size_t om_variable_write_numeric_array_size(uint16_t length_of_name, uint32_t number_of_children, uint64_t dimension_count) {
    return 0;
}

void om_variable_write_numeric_array(void* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, OmCompression_t compression_type, float scale_factor, float add_offset, uint64_t dimension_count, const uint64_t *dimensions, const uint64_t *chunks, uint64_t lut_size, uint64_t lut_offset) {
    return;
}

size_t om_write_header_size() {
    return 0;
}

size_t om_write_trailer_size() {
    return 0;
}

void om_write_header(void* dest) {
    
}

void om_write_trailer(void* dest, const OmOffsetSize_t root) {
    
}
