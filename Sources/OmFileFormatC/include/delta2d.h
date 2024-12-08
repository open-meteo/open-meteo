#ifndef delta2d_h
#define delta2d_h

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

void delta2d_decode(const size_t length0, const size_t length1, short* chunkBuffer);
void delta2d_encode(const size_t length0, const size_t length1, short* chunkBuffer);

void delta2d_decode32(const size_t length0, const size_t length1, int* chunkBuffer);
void delta2d_encode32(const size_t length0, const size_t length1, int* chunkBuffer);

void delta2d_encode_xor(const size_t length0, const size_t length1, float* chunkBuffer);
void delta2d_decode_xor(const size_t length0, const size_t length1, float* chunkBuffer);

void delta2d_encode_xor_double(const size_t length0, const size_t length1, double* chunkBuffer);
void delta2d_decode_xor_double(const size_t length0, const size_t length1, double* chunkBuffer);

void delta_nd_decode16(int16_t *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count);
void delta_nd_encode16(int16_t *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count);

void xor_nd_decode_float(float *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count);
void xor_nd_encode_float(float *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count);

void xor_nd_decode_double(double *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count);
void xor_nd_encode_double(double *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count);

#endif /* deleta2d_h */
