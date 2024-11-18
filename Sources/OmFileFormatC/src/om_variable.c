//
//  om_variable.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 16.11.2024.
//

#include "om_variable.h"

#define SIZE_VARIABLEV3 8
#define SIZE_VARIABLEV3_ARRAY 4*8

size_t om_read_header_size() {
    return sizeof(OmHeaderV1_t);
}
size_t om_read_trailer_size() {
    return sizeof(OmTrailer_t);
}


OmError_t om_read_header(const void* src, OmOffsetSize_t* root) {
    const OmHeaderV3_t* meta = (const OmHeaderV3_t*)src;
    if (meta->magic_number1 != 79 || meta->magic_number2 != 77 || meta->version >= 3) {
        return ERROR_NOT_AN_OM_FILE;
    }
    if (_om_variable_is_version3(src)) {
        root->size = 0;
        root->offset = 0;
    } else {
        root->size = sizeof(OmHeaderV1_t);
        root->offset = 0;
    }
    return ERROR_OK;
}

OmError_t om_read_trailer(const void* src, OmOffsetSize_t* root) {
    const OmTrailer_t* meta = (const OmTrailer_t*)src;
    if (meta->magic_number1 != 79 || meta->magic_number2 != 77 || meta->version != 3) {
        return ERROR_NOT_AN_OM_FILE;
    }
    root->size = meta->root.size;
    root->offset = meta->root.offset;
    return ERROR_OK;
}

const OmVariable_t* om_variable_init(const void* src) {
    return src;
}

void om_variable_get_name(const OmVariable_t* variable, uint16_t* name_length, char** name) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        name_length = meta->length_of_name;
        // TODO SET POINTER
    } else {
        name_length = 0;
        *name = NULL;
    }
}

OmDataType_t om_variable_get_type(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return meta->data_type;
    } else {
        return DATA_TYPE_FLOAT_ARRAY;
    }
}

OmCompression_t om_variable_get_compression(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return meta->compression_type;
    } else {
        const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
        return meta->compression_type;
    }
}

bool _om_variable_is_version3(const OmVariable_t* variable) {
    const OmHeaderV3_t* meta = (const OmHeaderV3_t*)variable;
    bool isLegacy = meta->magic_number1 == 79 && meta->magic_number2 == 77 && (meta->version == 1 || meta->version == 2);
    return !isLegacy;
}

uint64_t om_variable_number_of_dimensions(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return _om_variable_is_array(meta) ? meta->additional.array.dimension_count : 0;
    } else {
        return 2;
    }
}

float om_variable_get_scale_factor(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return _om_variable_is_array(meta) ? meta->additional.array.scale_factor : 1;
    } else {
        const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
        return meta->scale_factor;
    }
}

float om_variable_get_add_offset(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return _om_variable_is_array(meta) ? meta->additional.array.add_offset : 0;
    } else {
        return 0;
    }
}

const uint64_t* om_variable_get_dimensions(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return (const uint64_t*)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 16 * meta->number_of_children;
    } else {
        const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
        return &meta->dim0;
    }
}

const uint64_t* om_variable_get_chunks(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return (const uint64_t*)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 16 * meta->number_of_children + 8 * meta->additional.array.dimension_count;
    } else {
        const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
        return &meta->dim0;
    }
}

uint32_t om_variable_number_of_children(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return meta->number_of_children;
    } else {
        return 0;
    }
}

void om_variable_get_child(const OmVariable_t* variable, int nChild, OmOffsetSize_t* child) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        const uint64_t* sizes, *offsets;
        if (_om_variable_is_array(meta)) {
            sizes = (const uint64_t*)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY;
            offsets = (const uint64_t*)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 8 * meta->number_of_children;
        } else {
            sizes = (const uint64_t*)variable + SIZE_VARIABLEV3;
            offsets = (const uint64_t*)variable + SIZE_VARIABLEV3 + 8 * meta->number_of_children;
        }
        if (nChild < meta->number_of_children) {
            child->size = sizes[nChild];
            child->offset = offsets[nChild];
        } else {
            child->size = 0;
            child->offset = 0;
        }
    }
}

OmError_t om_variable_read_scalar(const OmVariable_t* variable, void* value) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        if (_om_variable_is_array(meta)) {
            return ERROR_INVALID_DATA_TYPE;
        }
        const void* src = (const void*)variable + SIZE_VARIABLEV3 + 16 * meta->number_of_children;
        switch (meta->data_type) {
            case DATA_TYPE_INT8:
                ((int8_t *)value)[0] = ((int8_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_UINT8:
                ((uint8_t *)value)[0] = ((uint8_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_INT16:
                ((int16_t *)value)[0] = ((int16_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_UINT16:
                ((uint16_t *)value)[0] = ((uint16_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_INT32:
                ((int32_t *)value)[0] = ((int32_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_UINT32:
                ((uint32_t *)value)[0] = ((uint32_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_INT64:
                ((int64_t *)value)[0] = ((int64_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_UINT64:
                ((uint64_t *)value)[0] = ((uint64_t*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_FLOAT:
                ((float *)value)[0] = ((float*)src)[0];
                return ERROR_OK;
            case DATA_TYPE_DOUBLE:
                ((double *)value)[0] = ((double*)src)[0];
                return ERROR_OK;
            default:
                return ERROR_INVALID_DATA_TYPE;
        }
    } else {
        return ERROR_INVALID_DATA_TYPE;
    }
}

size_t om_variable_write_scalar_size(uint16_t length_of_name, uint32_t number_of_children, OmDataType_t data_type) {
    size_t base = SIZE_VARIABLEV3 + length_of_name + number_of_children * 16;
    switch (data_type) {
        case DATA_TYPE_NONE:
            return base;
        case DATA_TYPE_INT8:
        case DATA_TYPE_UINT8:
            return base + 1;
        case DATA_TYPE_INT16:
        case DATA_TYPE_UINT16:
            return base + 2;
        case DATA_TYPE_INT32:
        case DATA_TYPE_UINT32:
        case DATA_TYPE_FLOAT:
            return base + 4;
        case DATA_TYPE_INT64:
        case DATA_TYPE_UINT64:
        case DATA_TYPE_DOUBLE:
            return base + 8;
        default:
            return 0;
    }
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
