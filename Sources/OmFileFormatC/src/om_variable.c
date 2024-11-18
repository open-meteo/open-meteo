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
    if (meta->magic_number1 != 'O' || meta->magic_number2 != 'M' || meta->version > 3) {
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
    if (meta->magic_number1 != 'O' || meta->magic_number2 != 'M' || meta->version != 3) {
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
    bool isLegacy = meta->magic_number1 == 'O' && meta->magic_number2 == 'M' && (meta->version == 1 || meta->version == 2);
    return !isLegacy;
}

bool _om_variable_is_array(const OmVariableV3_t* variable) {
    return variable->data_type >= DATA_TYPE_INT8_ARRAY && variable->data_type <= DATA_TYPE_DOUBLE_ARRAY;
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
        return (const uint64_t*)((char *)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 16 * meta->number_of_children);
    } else {
        const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
        return &meta->dim0;
    }
}

const uint64_t* om_variable_get_chunks(const OmVariable_t* variable) {
    if (_om_variable_is_version3(variable)) {
        const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
        return (const uint64_t*)((char *)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 16 * meta->number_of_children + 8 * meta->additional.array.dimension_count);
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
            sizes = (const uint64_t*)((char *)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY);
            offsets = (const uint64_t*)((char *)variable + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 8 * meta->number_of_children);
        } else {
            sizes = (const uint64_t*)((char *)variable + SIZE_VARIABLEV3);
            offsets = (const uint64_t*)((char *)variable + SIZE_VARIABLEV3 + 8 * meta->number_of_children);
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
        const void* src = (const void*)((char *)variable + SIZE_VARIABLEV3 + 16 * meta->number_of_children);
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

void om_variable_write_scalar(char* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, const void* value) {
    OmVariableV3_t* meta = (OmVariableV3_t*)dst;
    meta->data_type = (uint8_t)data_type;
    meta->compression_type = COMPRESSION_NONE;
    meta->length_of_name = length_of_name;
    meta->number_of_children = number_of_children;
    
    /// Set childen
    uint64_t* baseChildSize = (uint64_t*)((char *)dst + SIZE_VARIABLEV3);
    uint64_t* baseChildOffset = (uint64_t*)((char *)dst + SIZE_VARIABLEV3 + 8 * number_of_children);
    for (uint32_t i = 0; i<number_of_children; i++) {
        baseChildSize[i] = children_length[i];
        baseChildOffset[i] = children_offset[i];
    }
    
    /// Set value
    char* base = (char*)dst + SIZE_VARIABLEV3 + 16 * number_of_children;
    switch (data_type) {
        case DATA_TYPE_INT8:
            ((int8_t *)base)[0] = ((int8_t*)value)[0];
            base += 1;
            break;
        case DATA_TYPE_UINT8:
            ((uint8_t *)base)[0] = ((uint8_t*)value)[0];
            base += 1;
            break;
        case DATA_TYPE_INT16:
            ((int16_t *)base)[0] = ((int16_t*)value)[0];
            base += 2;
            break;
        case DATA_TYPE_UINT16:
            ((uint16_t *)base)[0] = ((uint16_t*)value)[0];
            base += 2;
            break;
        case DATA_TYPE_INT32:
            ((int32_t *)base)[0] = ((int32_t*)value)[0];
            base += 4;
            break;
        case DATA_TYPE_UINT32:
            ((uint32_t *)base)[0] = ((uint32_t*)value)[0];
            base += 4;
            break;
        case DATA_TYPE_INT64:
            ((int64_t *)base)[0] = ((int64_t*)value)[0];
            base += 8;
            break;
        case DATA_TYPE_UINT64:
            ((uint64_t *)base)[0] = ((uint64_t*)value)[0];
            base += 8;
            break;
        case DATA_TYPE_FLOAT:
            ((float *)base)[0] = ((float*)value)[0];
            base += 4;
            break;
        case DATA_TYPE_DOUBLE:
            ((double *)base)[0] = ((double*)value)[0];
            base += 8;
            break;
        default:
            break;
    }
    
    /// Set name
    for (uint16_t i = 0; i<length_of_name; i++) {
        base[i] = name[i];
    }
}

size_t om_variable_write_numeric_array_size(uint16_t length_of_name, uint32_t number_of_children, uint64_t dimension_count) {
    return SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + length_of_name + number_of_children * 16 + dimension_count * 16;
}

void om_variable_write_numeric_array(char* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, OmCompression_t compression_type, float scale_factor, float add_offset, uint64_t dimension_count, const uint64_t *dimensions, const uint64_t *chunks, uint64_t lut_size, uint64_t lut_offset) {
    
    OmVariableV3_t* meta = (OmVariableV3_t*)dst;
    meta->data_type = (uint8_t)data_type;
    meta->compression_type = compression_type;
    meta->length_of_name = length_of_name;
    meta->number_of_children = number_of_children;
    meta->additional.array.add_offset = add_offset;
    meta->additional.array.scale_factor = scale_factor;
    meta->additional.array.dimension_count = dimension_count;
    meta->additional.array.lut_size = lut_size;
    meta->additional.array.lut_offset = lut_offset;
    
    /// Set childen
    uint64_t* baseChildSize = (uint64_t*)(dst + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY);
    uint64_t* baseChildOffset = (uint64_t*)(dst + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 8 * number_of_children);
    for (uint32_t i = 0; i<number_of_children; i++) {
        baseChildSize[i] = children_length[i];
        baseChildOffset[i] = children_offset[i];
    }
    
    /// Set dimensions
    uint64_t* baseDimensions = (uint64_t*)(dst + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 16 * number_of_children);
    uint64_t* baseChunks = (uint64_t*)(dst + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 16 * number_of_children + 8 * dimension_count);
    for (uint64_t i = 0; i<dimension_count; i++) {
        baseDimensions[i] = dimensions[i];
        baseChunks[i] = chunks[i];
    }
    /// Set name
    char* baseName = (char*)(dst + SIZE_VARIABLEV3 + SIZE_VARIABLEV3_ARRAY + 16 * number_of_children + 16 * dimension_count);
    for (uint16_t i = 0; i<length_of_name; i++) {
        baseName[i] = name[i];
    }
}

size_t om_write_header_size() {
    return sizeof(OmHeaderV3_t);
}

size_t om_write_trailer_size() {
    return sizeof(OmTrailer_t);
}

void om_write_header(char* dest) {
    OmHeaderV3_t* meta = (OmHeaderV3_t*)dest;
    meta->magic_number1 = 'O';
    meta->magic_number2 = 'M';
    meta->version = 3;
}

void om_write_trailer(char* dest, const OmOffsetSize_t root) {
    OmTrailer_t* meta = (OmTrailer_t*)dest;
    meta->magic_number1 = 'O';
    meta->magic_number2 = 'M';
    meta->version = 3;
    meta->root = root;
}
