//
//  om_variable.c
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 16.11.2024.
//

#include "om_variable.h"

#define SIZE_VARIABLEV3 8

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
    if (meta->version == 3) {
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

void om_read_variable_name(const OmVariable_t* variable, uint16_t* name_length, char** name) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY: {
            // Legacy files to not have a name field
            *name_length = 0;
            *name = NULL;
        }
        case OM_MEMORY_LAYOUT_ARRAY: {
            // 'Name' is after dimension arrays
            const OmVariableArrayV3_t* meta = (const OmVariableArrayV3_t*)variable;
            *name_length = meta->length_of_name;
            *name = (char*)((void *)variable + sizeof(OmVariableArrayV3_t) + 16 * meta->number_of_children + 16 * meta->dimension_count);
        }
        case OM_MEMORY_LAYOUT_SCALAR: {
            // 'Name' is after the scalar value
            const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
            *name_length = meta->length_of_name;
            char* base = (char*)((void *)variable + sizeof(OmVariableV3_t) + 16 * meta->number_of_children);
            switch (meta->data_type) {
                case DATA_TYPE_INT8:
                case DATA_TYPE_UINT8:
                    *name = base + 1;
                    break;
                case DATA_TYPE_INT16:
                case DATA_TYPE_UINT16:
                    *name = base + 2;
                    break;
                case DATA_TYPE_INT32:
                case DATA_TYPE_UINT32:
                case DATA_TYPE_FLOAT:
                    *name = base + 4;
                    break;
                case DATA_TYPE_INT64:
                case DATA_TYPE_UINT64:
                case DATA_TYPE_DOUBLE:
                    *name = base + 8;
                    break;
                default:
                    break;
            }
        }
    }
}

OmDataType_t om_variable_get_type(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY:
            return DATA_TYPE_FLOAT_ARRAY;
        case OM_MEMORY_LAYOUT_ARRAY:
        case OM_MEMORY_LAYOUT_SCALAR: {
            const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
            return meta->data_type;
        }
    }
}

OmCompression_t om_variable_get_compression(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY: {
            const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
            if (meta->version == 1) {
                return COMPRESSION_PFOR_16BIT_DELTA2D;
            }
            return meta->compression_type;
        }
        case OM_MEMORY_LAYOUT_ARRAY:
        case OM_MEMORY_LAYOUT_SCALAR: {
            const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
            return meta->compression_type;
        }
    }
}

OmMemoryLayout_t _om_variable_memory_layout(const OmVariable_t* variable) {
    const OmHeaderV3_t* meta = (const OmHeaderV3_t*)variable;
    bool isLegacy = meta->magic_number1 == 'O' && meta->magic_number2 == 'M' && (meta->version == 1 || meta->version == 2);
    if (isLegacy) {
        return OM_MEMORY_LAYOUT_LEGACY;
    }
    const OmVariableV3_t* var = (const OmVariableV3_t*)variable;
    bool isArray = var->data_type >= DATA_TYPE_INT8_ARRAY && var->data_type <= DATA_TYPE_DOUBLE_ARRAY;
    return isArray ? OM_MEMORY_LAYOUT_ARRAY : OM_MEMORY_LAYOUT_SCALAR;
}

uint64_t om_variable_get_number_of_dimensions(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY:
            return 2;
        case OM_MEMORY_LAYOUT_ARRAY:
            return ((OmVariableArrayV3_t*)variable)->dimension_count;
        case OM_MEMORY_LAYOUT_SCALAR:
            return 0;
    }
}

float om_variable_get_scale_factor(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY:
            return ((OmHeaderV1_t*)variable)->scale_factor;
        case OM_MEMORY_LAYOUT_ARRAY:
            return ((OmVariableArrayV3_t*)variable)->scale_factor;
        case OM_MEMORY_LAYOUT_SCALAR:
            return 1;
    }
}

float om_variable_get_add_offset(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY:
            return 0;
        case OM_MEMORY_LAYOUT_ARRAY:
            return ((OmVariableArrayV3_t*)variable)->add_offset;
        case OM_MEMORY_LAYOUT_SCALAR:
            return 0;
    }
}

const uint64_t* om_variable_get_dimensions(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY: {
                const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
                return &meta->dim0;
            }
        case OM_MEMORY_LAYOUT_ARRAY: {
                const OmVariableArrayV3_t* meta = (const OmVariableArrayV3_t*)variable;
                return (const uint64_t*)((void *)variable + sizeof(OmVariableArrayV3_t) + 16 * meta->number_of_children);
            }
        case OM_MEMORY_LAYOUT_SCALAR:
            return NULL;
    }
}

const uint64_t* om_variable_get_chunks(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY: {
                const OmHeaderV1_t* meta = (const OmHeaderV1_t*)variable;
                return &meta->chunk0;
            }
        case OM_MEMORY_LAYOUT_ARRAY: {
                const OmVariableArrayV3_t* meta = (const OmVariableArrayV3_t*)variable;
                return (const uint64_t*)((void *)variable + sizeof(OmVariableArrayV3_t) + 16 * meta->number_of_children + 8 * meta->dimension_count);
            }
        case OM_MEMORY_LAYOUT_SCALAR:
            return NULL;
    }
}

uint32_t om_variable_get_number_of_children(const OmVariable_t* variable) {
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY:
            return 0;
        case OM_MEMORY_LAYOUT_ARRAY:
        case OM_MEMORY_LAYOUT_SCALAR:
            return ((OmVariableV3_t*)variable)->number_of_children;
    }
}

void om_variable_get_child(const OmVariable_t* variable, int nChild, OmOffsetSize_t* child) {
    uint64_t sizeof_variable;
    switch (_om_variable_memory_layout(variable)) {
        case OM_MEMORY_LAYOUT_LEGACY:
            return;
        case OM_MEMORY_LAYOUT_ARRAY:
            sizeof_variable = SIZE_VARIABLEV3;
            break;
        case OM_MEMORY_LAYOUT_SCALAR:
            sizeof_variable = sizeof(OmVariableArrayV3_t);
            break;
    }
    const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
    if (nChild < meta->number_of_children) {
        const uint64_t* sizes = (const uint64_t*)((void *)variable + sizeof_variable);
        const uint64_t* offsets = (const uint64_t*)((void *)variable + sizeof_variable + 8 * meta->number_of_children);
        child->size = sizes[nChild];
        child->offset = offsets[nChild];
    } else {
        child->size = 0;
        child->offset = 0;
    }
}

OmError_t om_variable_read_scalar(const OmVariable_t* variable, void* value) {
    if (_om_variable_memory_layout(variable) != OM_MEMORY_LAYOUT_SCALAR) {
        return ERROR_INVALID_DATA_TYPE;
    }
    
    const OmVariableV3_t* meta = (const OmVariableV3_t*)variable;
    const void* src = (const void*)((char *)variable + SIZE_VARIABLEV3 + 16 * meta->number_of_children);
    switch (meta->data_type) {
        case DATA_TYPE_INT8:
        case DATA_TYPE_UINT8:
            *(int8_t *)value = *(int8_t*)src;
            return ERROR_OK;
        case DATA_TYPE_INT16:
        case DATA_TYPE_UINT16:
            *(int16_t *)value = *(int16_t*)src;
            return ERROR_OK;
        case DATA_TYPE_INT32:
        case DATA_TYPE_UINT32:
        case DATA_TYPE_FLOAT:
            *(int32_t *)value = *(int32_t*)src;
            return ERROR_OK;
        case DATA_TYPE_INT64:
        case DATA_TYPE_UINT64:
        case DATA_TYPE_DOUBLE:
            *(int64_t *)value = *(int64_t*)src;
            return ERROR_OK;
        default:
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
    char* base = (char*)(dst + SIZE_VARIABLEV3 + 16 * number_of_children);
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
    return sizeof(OmVariableArrayV3_t) + length_of_name + number_of_children * 16 + dimension_count * 16;
}

void om_variable_write_numeric_array(void* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, OmCompression_t compression_type, float scale_factor, float add_offset, uint64_t dimension_count, const uint64_t *dimensions, const uint64_t *chunks, uint64_t lut_size, uint64_t lut_offset) {
    
    OmVariableArrayV3_t* meta = (OmVariableArrayV3_t*)dst;
    meta->data_type = (uint8_t)data_type;
    meta->compression_type = compression_type;
    meta->length_of_name = length_of_name;
    meta->number_of_children = number_of_children;
    meta->add_offset = add_offset;
    meta->scale_factor = scale_factor;
    meta->dimension_count = dimension_count;
    meta->lut_size = lut_size;
    meta->lut_offset = lut_offset;
    
    /// Set childen
    uint64_t* baseChildSize = (uint64_t*)(dst + sizeof(OmVariableArrayV3_t));
    uint64_t* baseChildOffset = (uint64_t*)(dst + sizeof(OmVariableArrayV3_t) + 8 * number_of_children);
    for (uint32_t i = 0; i<number_of_children; i++) {
        baseChildSize[i] = children_length[i];
        baseChildOffset[i] = children_offset[i];
    }
    
    /// Set dimensions
    uint64_t* baseDimensions = (uint64_t*)(dst + sizeof(OmVariableArrayV3_t) + 16 * number_of_children);
    uint64_t* baseChunks = (uint64_t*)(dst + sizeof(OmVariableArrayV3_t) + 16 * number_of_children + 8 * dimension_count);
    for (uint64_t i = 0; i<dimension_count; i++) {
        baseDimensions[i] = dimensions[i];
        baseChunks[i] = chunks[i];
    }
    /// Set name
    char* baseName = (char*)(dst + sizeof(OmVariableArrayV3_t) + 16 * number_of_children + 16 * dimension_count);
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
    meta->root = root;
}
