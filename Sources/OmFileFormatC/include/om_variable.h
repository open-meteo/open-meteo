//
//  om_variable.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 16.11.2024.
//

#ifndef OM_VARIABLE_H
#define OM_VARIABLE_H

#include "om_common.h"

/**
Variable
 - string name
 - [Variable] chilrden
 - enum data_type
 - data
 
 Data:
 - int8
 
 
 read file -> version + *OmVariable_t offset + length
 
 TODO:
 - do we need 64 bit alignment?
 */

size_t om_read_header_size(); // -> 40 bytes for legacy versions
size_t om_read_trailer_size(); // -> 20 bytes

/// read header of a file. Older files return root start and end directly, new files require to read trailer. For newer files, root is set to 0.
/// Data should be read afterwards from offset by size. This data is a pointer to `OmVariable_t`
OmError_t om_read_header(const void* src, int *version, OmOffsetSize_t* root);
OmError_t om_read_trailer(const void* src, int *version, OmOffsetSize_t* root);

/// After reading data for the variable, initlise it. This is literally a simple cast to an opague pointer. Source memory must remain accessible!
OmVariable_t* om_variable_init(void* src);

OmError_t om_variable_get_name(const OmVariable_t* variable, size_t* name_length, char** name);
OmDataType_t om_variable_get_type(const OmVariable_t* variable);

/// Check if a variable is legacy or version 3. Legacy files are the entire header containing magic number and version.
bool _om_variable_is_version3(const OmVariable_t* variable);

/// Get the file position where a specified child can be read
OmError_t om_variable_get_child(const OmVariable_t* variable, int nChild, OmOffsetSize_t* child);
int om_variable_number_of_children(const OmVariable_t* variable);


int om_variable_size_of_prefix(size_t length_of_name, size_t number_of_children);
int om_variable_write_prefix(void* dst, size_t length_of_name, size_t number_of_children, size_t children_length, size_t children_offset, char* name);


int om_variable_size_of_int8();
void om_variable_write_int8(void* dst);
OmError_t om_variable_read_int8(const OmVariable_t* variable, int8_t* value);

int om_variable_size_of_numeric_array(size_t dimension_count);
int om_variable_write_numeric_array(void* dst, char compression_type, scalefactor, dataoffset, size_t dimension_count, size_t *dimensions, size_t *chunks, lut_offset, lut_size);


OmError_t OmDecoder_init(OmDecoder_t* decoder, int version, const OmVariable_t* variable, const size_t* read_offset, const size_t* read_count, const size_t* cube_offset, const size_t* cube_dimensions, size_t io_size_merge, size_t io_size_max);



size_t om_write_header_size(); // 3
size_t om_write_trailer_size(); // 20
OmError_t om_write_header(void* dest);
OmError_t om_write_trailer(void* dest, const OmOffsetSize_t* root);


#endif // OM_VARIABLE_H
