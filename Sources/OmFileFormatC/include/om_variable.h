//
//  om_variable.h
//  OpenMeteoApi
//
//  Created by Patrick Zippenfenig on 16.11.2024.
//

#ifndef OM_VARIABLE_H
#define OM_VARIABLE_H

#include "om_common.h"
#include "om_file.h"

/**
 TODO:
 - String and String array support
 */

/// =========== Structures describing the data layout ===============




typedef struct {
    uint8_t data_type; // OmDataType_t
    uint8_t compression_type; // OmCompression_t
    uint16_t length_of_name; // maximum 65k name strings
    uint32_t number_of_children;

    // Followed by payload: NOTE: Lets to try 64 bit align it somehow
    //uint32_t[number_of_children] children_length;
    //uint32_t[number_of_children] children_offset;

    // Scalars are now set
    //void* value;
    
    // name is always last
    //char[length_of_name] name;
} OmVariableV3_t;

typedef struct {
    uint8_t data_type; // OmDataType_t
    uint8_t compression_type; // OmCompression_t
    uint16_t length_of_name; // maximum 65k name strings
    uint32_t number_of_children;
    uint64_t lut_size;
    uint64_t lut_offset;
    uint64_t dimension_count;
    
    float scale_factor;
    float add_offset;
    
    // Followed by payload: NOTE: Lets to try 64 bit align it somehow
    //uint32_t[number_of_children] children_length;
    //uint32_t[number_of_children] children_offset;
    
    // Afterwards additional payload from value types
    //uint64_t[dimension_count] dimensions;
    //uint64_t[dimension_count] chunks;
    
    // name is always last
    //char[length_of_name] name;
} OmVariableArrayV3_t;

typedef struct {
    uint8_t data_type; // OmDataType_t
    uint8_t compression_type; // OmCompression_t
    uint16_t length_of_name; // maximum 65k name strings
    uint32_t number_of_children;
    uint64_t string_size;
    // followed by the string value
    // name is always last
    //char[length_of_name] name;
} OmVariablStringV3_t;


/// only expose an opague pointer
typedef void* OmVariable_t;



/// =========== Functions for reading ===============


typedef struct {
    const uint16_t size;
    const char* value;
} OmString_t;

typedef struct {
    const uint64_t count;
    const uint64_t* values;
} OmDimensions_t;



/// After reading data for the variable, initlise it. This is literally a simple cast to an opague pointer. Source memory must remain accessible!
const OmVariable_t* om_variable_init(const void* src);

/// Get the name of of a given variable. No guarantee for zero termination!
OmString_t om_read_variable_name(const OmVariable_t* variable);

/// Get the type of the current variable
OmDataType_t om_variable_get_type(const OmVariable_t* variable);

/// Get the compression type of the current variable
OmCompression_t om_variable_get_compression(const OmVariable_t* variable);

float om_variable_get_scale_factor(const OmVariable_t* variable);

float om_variable_get_add_offset(const OmVariable_t* variable);

/// Get a pointer to the dimensions of a OM variable
OmDimensions_t om_variable_get_dimensions(const OmVariable_t* variable);

/// Get a pointer to the chunk dimensions of an OM Variable
OmDimensions_t om_variable_get_chunks(const OmVariable_t* variable);

/// Return how many chilrden are available for a given variable
uint32_t om_variable_get_number_of_children(const OmVariable_t* variable);

/// Get the file offset where a specified child can be read
OmOffsetSize_t om_variable_get_child(const OmVariable_t* variable, int nChild);

/// Read a variable as a scalar
OmError_t om_variable_read_scalar(const OmVariable_t* variable, void* value);




/// =========== Functions for writing ===============

/// Get the length of a scalar variable if written to a file
size_t om_variable_write_scalar_size(uint16_t length_of_name, uint32_t number_of_children, OmDataType_t data_type);

/// Write a scalar variable with name and children variables
void om_variable_write_scalar(void* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, const void* value);

/// Get the size of meta attributes of a numeric array if written to a file. Does not contain any data. Only offsets for the actual data.
size_t om_variable_write_numeric_array_size(uint16_t length_of_name, uint32_t number_of_children, uint64_t dimension_count);

/// Write meta data for a numeric array to file
void om_variable_write_numeric_array(void* dst, uint16_t length_of_name, uint32_t number_of_children, const uint64_t* children_length, const uint64_t* children_offset, const char* name, OmDataType_t data_type, OmCompression_t compression_type, float scale_factor, float add_offset, uint64_t dimension_count, const uint64_t *dimensions, const uint64_t *chunks, uint64_t lut_size, uint64_t lut_offset);



/// =========== Internal functions ===============

/// Memory layout types
typedef enum {
    OM_MEMORY_LAYOUT_LEGACY = 0,
    OM_MEMORY_LAYOUT_ARRAY = 1,
    OM_MEMORY_LAYOUT_SCALAR = 3,
    //OM_MEMORY_LAYOUT_STRING = 4,
    //OM_MEMORY_LAYOUT_STRING_ARRAY = 5,
} OmMemoryLayout_t;

/// Check if a variable is legacy or version 3 array of scalar. Legacy files are the entire header containing magic number and version.
OmMemoryLayout_t _om_variable_memory_layout(const OmVariable_t* variable);




#endif // OM_VARIABLE_H
