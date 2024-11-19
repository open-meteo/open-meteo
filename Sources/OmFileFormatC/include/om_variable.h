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
 TODO:
 - do we need 64 bit alignment?
 - String and String array support
 */

/// Return the size in byte of the header that should be read. Always 40 byte to support legacy 2D files.
size_t om_read_header_size();
/// Size in bytes of the trailer that contains the root variable offset in newer files
size_t om_read_trailer_size();

/// read header of a file. Older files return root start and end directly, new files require to read trailer. For newer files, root is set to 0.
/// Data should be read afterwards from offset by size. This data is a pointer to `OmVariable_t`.
/// Error if not an OM file
OmError_t om_read_header(const void* src, OmOffsetSize_t* root);
/// Read the trailer of an OM file to get the root variable. Error if not an OM file.
OmError_t om_read_trailer(const void* src, OmOffsetSize_t* root);

/// After reading data for the variable, initlise it. This is literally a simple cast to an opague pointer. Source memory must remain accessible!
const OmVariable_t* om_variable_init(const void* src);

/// Get the name of of a given variable. No guarantee for zero termination!
void om_variable_get_name(const OmVariable_t* variable, uint16_t* name_length, char** name);

/// Get the type of the current variable
OmDataType_t om_variable_get_type(const OmVariable_t* variable);

/// Get the compression type of the current variable
OmCompression_t om_variable_get_compression(const OmVariable_t* variable);

float om_variable_get_scale_factor(const OmVariable_t* variable);

float om_variable_get_add_offset(const OmVariable_t* variable);

/// Check if a variable is legacy or version 3. Legacy files are the entire header containing magic number and version.
bool _om_variable_is_version3(const OmVariable_t* variable);

/// Return number of dimensions
uint64_t om_variable_number_of_dimensions(const OmVariable_t* variable);

/// Get a pointer to the dimensions of a OM variable
const uint64_t* om_variable_get_dimensions(const OmVariable_t* variable);

/// Get a pointer to the chunk dimensions of an OM Variable
const uint64_t* om_variable_get_chunks(const OmVariable_t* variable);

/// Return how many chilrden are available for a given variable
uint32_t om_variable_number_of_children(const OmVariable_t* variable);

/// Get the file offset where a specified child can be read
void om_variable_get_child(const OmVariable_t* variable, int nChild, OmOffsetSize_t* child);

/// Read a variable as a scalar
OmError_t om_variable_read_scalar(const OmVariable_t* variable, void* value);

/// Get the length of a scalar variable if written to a file
size_t om_variable_write_scalar_size(uint16_t length_of_name, uint32_t number_of_children, OmDataType_t data_type);

/// Write a scalar variable with name and children variables
void om_variable_write_scalar(void* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, const void* value);

/// Get the size of meta attributes of a numeric array if written to a file. Does not contain any data. Only offsets for the actual data.
size_t om_variable_write_numeric_array_size(uint16_t length_of_name, uint32_t number_of_children, uint64_t dimension_count);

/// Write meta data for a numeric array to file
void om_variable_write_numeric_array(void* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, OmCompression_t compression_type, float scale_factor, float add_offset, uint64_t dimension_count, const uint64_t *dimensions, const uint64_t *chunks, uint64_t lut_size, uint64_t lut_offset);

/// The size of a OM header for newer files. Always 3 bytes.
size_t om_write_header_size();

/// The size of the trailer for newer files
size_t om_write_trailer_size();

/// Write an header for newer OM files
void om_write_header(void* dest);

/// Write an trailer for newer OM files including the root variable
void om_write_trailer(void* dest, const OmOffsetSize_t root);

#endif // OM_VARIABLE_H
