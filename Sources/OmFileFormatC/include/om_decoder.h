/**
 * @file om_decoder.h
 * @brief OmFileDecoder: A component for reading and decompressing data from a compressed file format.
 * 
 * The OmFileDecoder provides functions and structures for reading chunks of compressed data,
 * decompressing them, and storing the results into a target buffer. It supports various compression
 * schemes and allows reading partial or entire datasets in a chunked manner.
 *
 * Created by Patrick Zippenfenig on 22.10.2024.
 */

#ifndef OM_DECODER_H
#define OM_DECODER_H

#include "om_common.h"
#include "om_variable.h"

typedef struct {
    uint64_t lowerBound;
    uint64_t upperBound;
} OmRange_t;

typedef struct {
    uint64_t offset;
    uint64_t count;
    OmRange_t indexRange;
    OmRange_t chunkIndex;
    OmRange_t nextChunk;
} OmDecoder_indexRead_t;

typedef OmDecoder_indexRead_t OmDecoder_dataRead_t;


typedef struct {
    /// Number of dimensions
    uint64_t dimensions_count;

    /// Combine smaller IO reads to a single larger read. If consecutive reads are smaller than `io_size_merge` they might be merged. Default should be 512 bytes.
    uint64_t io_size_merge;

    /// The maximum IO size before IO operations are split up. Default 64k. If data is in memory, this can be set higher.
    uint64_t io_size_max;

    /// Each 64 LUT entries are compressed into a LUT chunk. The LUT chunk length returns the size in byte how large a maximum compressed size for a LUT chunk is. 0 for version 1/2 files that do not compress LUT.
    uint64_t lut_chunk_length;

    /// The offset position where the LUT should start
    uint64_t lut_start;

    /// uint64_t of data chunks in this file. This value is computed in the initialisation.
    uint64_t number_of_chunks;
    
    /// The dimensions of the data array. The last dimension is the "fast" dimension meaning the elements are sequential in memory
    const uint64_t* dimensions;

    /// The chunk lengths for each dimension
    const uint64_t* chunks;

    /// The read offset to start reading data in each dimension
    const uint64_t* read_offset;

    /// How many elements in each dimension to read
    const uint64_t* read_count;

    /// The dimensions of the target array. This can be the same as `read_count`, but it is also possible to read into a larger array
    const uint64_t* cube_dimensions;

    /// The offset for each dimension if data is read into a larger array.
    const uint64_t* cube_offset;
    
    /// The callback to decompress data
    om_compress_callback_t decompress_callback;

    /// The filter function for each decompressed block. E.g. a 2D delta coding.
    om_compress_filter_callback_t decompress_filter_callback;

    /// Copy and scale individual values from a chunk into the output array
    om_compress_copy_callback_t decompress_copy_callback;
    
    /// A scalefactor to convert floats to integers
    float scale_factor;
    
    /// An offset to convert floats to integers while scaling
    float add_offset;

    /// Number of bytes for a single element of the data type
    int8_t bytes_per_element;
    
    /// Number of bytes for a single element in the compressed stream. E.g. Int16 could be used to scale down floats
    int8_t bytes_per_element_compressed;
} OmDecoder_t;

/**
 * @brief Initializes the `om_decoder_t` structure with the specified parameters.
 * 
 * This function sets up the `om_decoder_t` instance, configuring its dimensions, chunk information,
 * reading parameters, LUT (Look-Up Table) properties, and decompression methods. It prepares the 
 * decoder for reading and processing compressed data, managing the scaling and decompression callbacks.
 * 
 * @param decoder A pointer to an `om_decoder_t` structure that will be initialized.
 * @param variable A pointer to the data region of the variable to read
 * @param dimension_count The number of dimensions of the data (e.g., 3 for 3D data). All following array must have the some dimension count.
 * @param read_offset A pointer to an array specifying the offsets for reading data in each dimension. This array sets the starting points for data reads.
 * @param read_count A pointer to an array specifying the number of elements to read along each dimension. It defines how much data to read starting from `read_offset`.
 * @param cube_offset A pointer to an array specifying the offset of the target cube in each dimension. This is used when reading data into a larger array.
 * @param cube_dimensions A pointer to an array specifying the dimensions of the target cube being written to.It can be the same as `read_count` but allows writing into larger arrays..
 * @param io_size_merge The maximum size (in bytes) for merging consecutive IO operations. It helps to optimize read performance by merging small reads.
 * @param io_size_max The maximum size (in bytes) for a single IO operation before it is split. It defines the threshold for splitting large reads.
 * 
 * @returns Return an om_error_t if the compression or dimension is invalid
 */
OmError_t om_decoder_init(OmDecoder_t* decoder, const OmVariable_t* variable, uint64_t dimension_count, const uint64_t* read_offset, const uint64_t* read_count, const uint64_t* cube_offset, const uint64_t* cube_dimensions, uint64_t io_size_merge, uint64_t io_size_max);

//OmError_t OmDecoder_init(OmDecoder_t* decoder, float scalefactor, float add_offset, const OmCompression_t compression, const OmDataType_t data_type, uint64_t dimension_count, const uint64_t* dimensions, const uint64_t* chunks, const uint64_t* read_offset, const uint64_t* read_count, const uint64_t* cube_offset, const uint64_t* cube_dimensions, uint64_t lut_size, uint64_t lut_chunk_element_count, uint64_t lut_start, uint64_t io_size_merge, uint64_t io_size_max);

/**
 * @brief Initializes an `om_decoder_index_read_t` structure for reading chunk indices.
 * 
 * This function calculates the starting and ending chunk indices for reading data based on 
 * the dimensions, chunk sizes, and read parameters provided by the `om_decoder_t` structure. 
 * It determines the range of chunks that need to be processed to fulfill the read request, 
 * setting the appropriate values in the `om_decoder_index_read_t` structure.
 * 
 * @param decoder A pointer to a constant `om_decoder_t` structure containing information 
 *                about the data array, chunk sizes, read offsets, and dimensions.
 * @param index_read A pointer to an `om_decoder_index_read_t` structure that will be 
 *                   initialized with the computed chunk index range and other related values.
 */
void om_decoder_init_index_read(const OmDecoder_t* decoder, OmDecoder_indexRead_t *indexRead);


/**
 * @brief Determines the next range of chunks to be read and updates the `om_decoder_index_read_t` structure.
 * 
 * This function calculates the next set of chunk indices that need to be read from the data, based on the
 * limits set by the maximum I/O size, alignment, and the logical structure of the data. It updates the 
 * `om_decoder_index_read_t` structure to reflect the new range of chunks and the corresponding read parameters.
 * 
 * @param decoder A pointer to a constant `om_decoder_t` structure containing information about the data array,
 *                chunk sizes, I/O constraints, and other relevant parameters.
 * @param index_read A pointer to an `om_decoder_index_read_t` structure, which will be updated with the next
 *                   range of chunks to read and the corresponding offset and size of the read operation.
 * 
 * @returns `true` if the next read range was successfully computed and updated in `index_read`.
 *         `false` if there are no more chunks left to read, indicating that the end of the read range has been reached.
 * 
 */
bool om_decoder_next_index_read(const OmDecoder_t* decoder, OmDecoder_indexRead_t* index_read);


/**
 * @brief Initializes an `om_decoder_data_read_t` structure for data reading.
 * 
 * This function sets the initial state of the `om_decoder_data_read_t` structure,
 * preparing it for subsequent data read operations. It initializes the offset, 
 * count, index range, and chunk indices based on the provided index read structure.
 * 
 * @param[out] data_read   A pointer to the `om_decoder_data_read_t` structure that 
 *                         will be initialized. This structure maintains the state 
 *                         for reading data chunks.
 * @param[in]  index_read  A pointer to the `om_decoder_index_read_t` structure that 
 *                         contains information about the index range and the initial 
 *                         chunk index to be used for reading.
 */
void om_decoder_init_data_read(OmDecoder_dataRead_t *data_read, const OmDecoder_indexRead_t *index_read);


/**
 * @brief Prepares the next data read operation for a given chunk of compressed data.
 * 
 * This function advances the data reading process by calculating the start and end positions
 * of the next data segment to read based on the provided index data and current state
 * of the `om_decoder_data_read_t` structure. It determines how much data to read from
 * the compressed data source and where the decompressed data should be written.
 * 
 * The function supports two formats:
 * 1. Version 1 format (non-compressed LUTs, where `lut_chunk_element_count` is 1).
 * 2. Compressed LUT format (Version 3+).
 * 
 * The function reads from a specified index data and updates the `data_read` structure
 * with the offset and size of the next data block to be read.
 * 
 * @param[in]  decoder           A pointer to the `om_decoder_t` structure, which contains 
 *                               information about the file format, compression settings, 
 *                               and LUT (look-up table) characteristics.
 * @param[out] data_read         A pointer to `om_decoder_data_read_t` structure that holds 
 *                               the state of the current data read operation. This structure 
 *                               is updated to reflect the next segment of data to read.
 * @param[in]  index_data        A pointer to the index data, which provides the compressed
 *                               offset information for each chunk in the LUT.
 * @param[in]  index_data_size   The size of the `index_data` buffer in bytes.
 * 
 * @returns `true` if the next data segment was successfully prepared and ready for reading, 
 *          `false` if there are no more data segments to read or if the range is exhausted.
 * 
 * @returns May return an out-of-bounds read error on corrupted data.
 */
bool om_decoder_next_data_read(const OmDecoder_t *decoder, OmDecoder_dataRead_t* dataRead, const void* indexData, uint64_t indexDataCount, OmError_t* error);


/**
 * @brief Calculates the size of the buffer required to read a single data chunk.
 * 
 * This function determines the size, in bytes, of the buffer needed to read a single 
 * chunk of data from the compressed file, based on the chunk dimensions and the 
 * number of bytes per element after decompression.
 * 
 * The calculation involves multiplying the chunk lengths across all dimensions by 
 * the number of bytes required to store a single element in the decompressed form.
 * 
 * @param[in] decoder  A pointer to the `om_decoder_t` structure, which holds the 
 *                     decoder configuration, including chunk sizes for each dimension, 
 *                     and the number of bytes per element.
 * 
 * @returns The size of the buffer required to read a single chunk, in bytes.
 * 
 * @note This buffer size is used to allocate memory when reading data chunks during 
 *       the decoding process, ensuring that there is sufficient space to store the 
 *       decompressed data of a chunk.
 */
uint64_t om_decoder_read_buffer_size(const OmDecoder_t* decoder);


/**
 * @brief Decodes multiple data chunks from compressed input into a target buffer.
 * 
 * This function iteratively decodes a range of chunks from the compressed input data 
 * using the specified decoder configuration. It processes each chunk within the provided 
 * range, decompressing it into a buffer and copying the decompressed data into the 
 * output buffer. The decoding uses an internal function `_om_decoder_decode_chunk` 
 * for each individual chunk.
 * 
 * @param[in]  decoder      A pointer to the `om_decoder_t` structure, which defines 
 *                          the decoder configuration, including dimensions, chunk sizes, 
 *                          and decompression callbacks.
 * @param[in]  chunk        An `om_range_t` structure specifying the range of chunks 
 *                          to decode. The range is defined by `chunk.lowerBound` 
 *                          (inclusive) and `chunk.upperBound` (exclusive).
 * @param[in]  data         A pointer to the compressed data buffer from which the chunks 
 *                          are read and decoded.
 * @param[in]  data_size    The size of the `data` buffer, in bytes. This ensures that 
 *                          the function does not read beyond the provided data size.
 * @param[out] into         A pointer to the output buffer where the decompressed data 
 *                          will be written. The buffer should have enough space to store 
 *                          the decompressed output.
 * @param[out] chunkBuffer  A temporary buffer used for storing intermediate decompressed 
 *                          chunk data before copying it into the final output buffer. 
 *                          Must be sized according to `om_decoder_read_buffer_size`
 * @param[out] error  May return an out-of-bounds read error on corrupted data.
 *
 * @returns `false` if an error occurred.
 */
bool om_decoder_decode_chunks(const OmDecoder_t *decoder, OmRange_t chunkIndex, const void *data, uint64_t dataCount, void *into, void *chunkBuffer, OmError_t* error);

#endif // OM_DECODER_H
