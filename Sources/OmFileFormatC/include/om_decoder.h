/**
 * @file om_decoder.h
 * @brief OmFileDecoder: A component for reading and decompressing data from a compressed file format.
 * 
 * The OmFileDecoder provides functions and structures for reading chunks of compressed data,
 * decompressing them, and storing the results into a target buffer. It supports various compression
 * schemes and allows reading partial or entire datasets in a chunked manner.
 *
 * Created by Patrick Zippenfenig on 22.10.2024.
 * 
 * Usage Example in Swift:
 * --------------
 * var decoder = om_decoder_t();
 * om_decoder_init(
 *     &decoder,
 *     v.scalefactor,               // Scale factor for adjusting data during decompression
 *     v.compression,               // Compression method used in the file (e.g., FPX, P4NZ)
 *     v.dataType,                  // Data type of the compressed data (e.g., float, double)
 *     UInt64(v.dimensions.count),  // Number of dimensions in the data
 *     v.dimensions,                // Array specifying the size of each dimension
 *     v.chunks,                    // Array specifying chunk sizes for each dimension
 *     readOffset,                  // Offset specifying where to begin reading in each dimension
 *     readCount,                   // Number of elements to read from each dimension
 *     intoCubeOffset,              // Offset within the output cube to store decompressed data
 *     intoCubeDimension,           // Dimensions of the output cube (may be larger than readCount)
 *     v.lutSize,              // Maximum size of the compressed LUT in bytes
 *     lutChunkElementCount,        // Number of elements in each LUT chunk (typically 256)
 *     v.lutOffset,                 // Starting offset of the LUT in the file
 *     io_size_merge,               // Maximum size for merging smaller I/O reads. Default: 512
 *     io_size_max                  // Maximum size for a single I/O operation. Default: 65536
 * );
 * 
 * let chunkBuffer = UnsafeMutableRawBufferPointer.allocate(
 *     byteCount: Int(om_decoder_read_buffer_size(&decoder)),
 *     alignment: 4
 * );
 * 
 * mmap.withUnsafeBytes({ ptr in
 *     var indexRead = om_decoder_index_read_t();
 *     om_decoder_index_read_init(&decoder, &indexRead);
 *     
 *     // Loop over index blocks and read index data
 *     while (om_decoder_next_index_read(&decoder, &indexRead)) {
 *         // Access the index data based on read offset
 *         let indexData = ptr.baseAddress!.advanced(by: Int(indexRead.offset));
 *         
 *         var dataRead = om_decoder_data_read_t();
 *         om_decoder_data_read_init(&dataRead, &indexRead);
 *         
 *         // Loop over data blocks and read compressed data chunks
 *         while (om_decoder_next_data_read(&decoder, &dataRead, indexData, indexRead.count)) {
 *             let dataData = ptr.baseAddress!.advanced(by: Int(dataRead.offset));
 *             
 *             om_decoder_decode_chunks(
 *                 &decoder,
 *                 dataRead.chunkIndex,
 *                 dataData,
 *                 dataRead.count,
 *                 into,         // Target buffer for decompressed data
 *                 chunkBuffer   // Temporary buffer for holding decompressed chunk data
 *             );
 *         }
 *     }
 * });
 * 
 * @note This example shows the main steps of setting up the decoder, iterating over index reads, 
 *       and processing the decompressed data chunks. Functions like `om_decoder_index_read_init`, 
 *       `om_decoder_next_index_read`, `om_decoder_data_read_init`, `om_decoder_next_data_read`, 
 *       and `om_decoder_decode_chunks` are essential to this process.
 */

#ifndef OM_DECODER_H
#define OM_DECODER_H

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    uint64_t lowerBound;
    uint64_t upperBound;
} om_range_t;

typedef struct {
    uint64_t offset;
    uint64_t count;
    om_range_t indexRange;
    om_range_t chunkIndex;
    om_range_t nextChunk;
} om_decoder_index_read_t;

typedef om_decoder_index_read_t om_decoder_data_read_t;

typedef enum {
    DATA_TYPE_INT8 = 0,
    DATA_TYPE_UINT8 = 1,
    DATA_TYPE_INT16 = 2,
    DATA_TYPE_UINT16 = 3,
    DATA_TYPE_INT32 = 4,
    DATA_TYPE_UINT32 = 5,
    DATA_TYPE_INT64 = 6,
    DATA_TYPE_UINT64 = 7,
    DATA_TYPE_FLOAT = 8,
    DATA_TYPE_DOUBLE = 9
} om_datatype_t;

// Define an enum for the compression types.
typedef enum {
    COMPRESSION_P4NZDEC256 = 0,          // Lossy compression using 2D delta coding and scalefactor. Only supports float and scales to 16-bit integer.
    COMPRESSION_FPXDEC32 = 1,            // Lossless compression using 2D xor coding.
    COMPRESSION_P4NZDEC256_LOGARITHMIC = 3 // Similar to `P4NZDEC256` but applies `log10(1+x)` before.
} om_compression_t;

/// The function to convert a single a a sequence of elements and convert data type. Applies scale factor.
typedef void(*om_decompress_copy_callback)(uint64_t count, uint64_t read_offset, uint64_t write_offset, float scalefactor, const void* chunk_buffer, void* into);

/// decompress input, of n-elements to output and return number of compressed byte
typedef uint64_t(*om_decompress_callback)(const void* in, uint64_t count, void* out);

/// Perform a 2d filter operation
typedef void(*om_decompress_filter_callback)(const size_t length0, const size_t length1, void* chunkBuffer);

typedef struct {
    /// Number of dimensions
    uint64_t dimensions_count;

    /// Combine smaller IO reads to a single larger read. If consecutive reads are smaller than `io_size_merge` they might be merged. Default should be 512 bytes.
    uint64_t io_size_merge;

    /// The maximum IO size before IO operations are split up. Default 64k. If data is in memory, this can be set higher.
    uint64_t io_size_max;

    /// Each 256 LUT entries are compressed into a LUT chunk. The LUT chunk length returns the size in byte how large a maximum compressed size for a LUT chunk is.
    uint64_t lut_chunk_length;

    /// How many elements in the look up table LUT should be compressed. Default 256. A value of 1 assumes that the LUT is not compressed and assumes a om version 1/2 file.
    uint64_t lut_chunk_element_count;

    /// The offset position where the LUT should start
    uint64_t lut_start;

    /// Number of data chunks in this file. This value is computed in the initialisation.
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
    om_decompress_callback decompress_callback;

    /// The filter function for each decompressed block. E.g. a 2D delta coding.
    om_decompress_filter_callback decompress_filter_callback;

    /// Copy and scale individual values from a chunk into the output array
    om_decompress_copy_callback decompress_copy_callback;
    
    /// A scalefactor to convert floats to integers
    float scalefactor;

    /// Numer of bytes for a single element after decompression. Does not need to be the output datatype. E.g. Compression can use 16 bit and convert to float
    int8_t bytes_per_element;
} om_decoder_t;

/**
 * @brief Initializes the `om_decoder_t` structure with the specified parameters.
 * 
 * This function sets up the `om_decoder_t` instance, configuring its dimensions, chunk information,
 * reading parameters, LUT (Look-Up Table) properties, and decompression methods. It prepares the 
 * decoder for reading and processing compressed data, managing the scaling and decompression callbacks.
 * 
 * @param decoder A pointer to an `om_decoder_t` structure that will be initialized.
 * @param scalefactor A floating-point value used to scale the decompressed data. This factor
 *                    is applied when converting decompressed values to the desired scale.
 * @param compression Specifies the type of compression applied to the data.
 *                    Possible values include `COMPRESSION_P4NZDEC256`, `COMPRESSION_FPXDEC32`, 
 *                    and `COMPRESSION_P4NZDEC256_LOGARITHMIC`.
 * @param data_type Specifies the type of data, such as `DATA_TYPE_FLOAT` or `DATA_TYPE_DOUBLE`.
 *                  This affects the decompression and copy methods used.
 * @param dims_count The number of dimensions of the data (e.g., 3 for 3D data). This value is 
 *                   stored in `decoder->dims_count`.
 * @param dims A pointer to an array containing the size of each dimension. This defines the shape
 *             of the data being read and is stored in `decoder->dims`.
 * @param chunks A pointer to an array specifying the chunk sizes for each dimension. This array
 *               indicates how data is partitioned into chunks for reading and is stored in `decoder->chunks`.
 * @param read_offset A pointer to an array specifying the offsets for reading data in each dimension.
 *                    This array sets the starting points for data reads and is stored in `decoder->read_offset`.
 * @param read_count A pointer to an array specifying the number of elements to read along each dimension.
 *                   It defines how much data to read starting from `read_offset` and is stored in `decoder->read_count`.
 * @param cube_offset A pointer to an array specifying the offset of the target cube in each dimension.
 *                    This is used when reading data into a larger array and is stored in `decoder->cube_offset`.
 * @param cube_dimensions A pointer to an array specifying the dimensions of the target cube being read.
 *                        It can be the same as `read_count` but allows reading into larger arrays.
 *                        This is stored in `decoder->cube_dimensions`.
 * @param lut_size  The length (in bytes) of the compressed Look-Up Table (LUT). Ignored for Verion 1/2 files if lut_chunk_element_count == 1.
 * @param lut_chunk_element_count The number of elements in each LUT chunk. Default is 256. A value
 *                                of 1 indicates that the LUT is not compressed. This is stored in `decoder->lut_chunk_element_count`.
 * @param lut_start  The starting byte position of the LUT in the file. This is stored in `decoder->lut_start`.
 * @param io_size_merge The maximum size (in bytes) for merging consecutive IO operations.
 *                      It helps to optimize read performance by merging small reads and is stored in `decoder->io_size_merge`.
 * @param io_size_max The maximum size (in bytes) for a single IO operation before it is split.
 *                    It defines the threshold for splitting large reads and is stored in `decoder->io_size_max`.
 * 
 * @note The function configures the appropriate decompression callback functions based on the 
 *       specified compression and data type. For example, it handles different types of 
 *       decompression and copy routines for `COMPRESSION_P4NZDEC256` and `COMPRESSION_FPXDEC32`.
 * 
 * @warning The function asserts if an unsupported compression type is provided, which may cause 
 *          a program to terminate if an invalid `compression` value is used.
 * 
 * @todo Add support for additional compression types and data types as required.
 * 
 * @example
 * om_decoder_t decoder;
 * om_decoder_init(&decoder, 1.0f, COMPRESSION_P4NZDEC256, DATA_TYPE_FLOAT, 3, dims, chunks,
 *                 read_offset, read_count, cube_offset, cube_dimensions, 256, 54, 0, 1024, 4096);
 * 
 * @details This function computes the total number of chunks required based on the data dimensions
 *          and chunk sizes using the formula:
 *          \code
 *          uint64_t n = 1;
 *          for (uint64_t i = 0; i < dims_count; i++) {
 *              n *= divide_rounded_up(dims[i], chunks[i]);
 *          }
 *          decoder->number_of_chunks = n;
 *          \endcode
 *          This value is stored in `decoder->number_of_chunks` and is used for managing the read operations.
 */
void om_decoder_init(om_decoder_t* decoder, const float scalefactor, const om_compression_t compression, const om_datatype_t data_type, uint64_t dims_count, const uint64_t* dims, const uint64_t* chunks, const uint64_t* read_offset, const uint64_t* read_count, const uint64_t* cube_offset, const uint64_t* cube_dimensions, uint64_t lut_size, uint64_t lut_chunk_element_count, uint64_t lut_start, uint64_t io_size_merge, uint64_t io_size_max);

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
void om_decoder_index_read_init(const om_decoder_t* decoder, om_decoder_index_read_t *indexRead);


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
 * @return `true` if the next read range was successfully computed and updated in `index_read`.
 *         `false` if there are no more chunks left to read, indicating that the end of the read range has been reached.
 * 
 */
bool om_decoder_next_index_read(const om_decoder_t* decoder, om_decoder_index_read_t* index_read);


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
void om_decoder_data_read_init(om_decoder_data_read_t *data_read, const om_decoder_index_read_t *index_read);


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
 * @note This function ensures that read operations respect the maximum I/O size (`io_size_max`)
 *       and merging thresholds (`io_size_merge`) defined in the `decoder`. It also handles 
 *       transitioning between different LUT chunks if required.
 */
bool om_decoder_next_data_read(const om_decoder_t *decoder, om_decoder_data_read_t* dataRead, const void* indexData, uint64_t indexDataCount);


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
uint64_t om_decoder_read_buffer_size(const om_decoder_t* decoder);


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
 * 
 * @returns The total number of uncompressed bytes processed from the given chunk range.
 *          This value is equal to `data_size` if all chunks are decoded correctly.
 * 
 * @note The function asserts that the sum of uncompressed bytes matches the provided 
 *       `data_size`, ensuring that the entire input buffer has been processed without 
 *       any leftover data.
 * 
 * @warning The `into` buffer must be large enough to accommodate the decompressed data 
 *          from all chunks within the specified range, or memory corruption may occur.
 */
uint64_t om_decoder_decode_chunks(const om_decoder_t *decoder, om_range_t chunkIndex, const void *data, uint64_t dataCount, void *into, void *chunkBuffer);

#endif // OM_DECODER_H
