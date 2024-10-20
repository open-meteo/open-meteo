#ifndef delta2d_h
#define delta2d_h

#include <stdio.h>

void delta2d_decode(const size_t length0, const size_t length1, short* chunkBuffer);
void delta2d_encode(const size_t length0, const size_t length1, short* chunkBuffer);

void delta2d_decode32(const size_t length0, const size_t length1, int* chunkBuffer);
void delta2d_encode32(const size_t length0, const size_t length1, int* chunkBuffer);

void delta2d_encode_xor(const size_t length0, const size_t length1, float* chunkBuffer);
void delta2d_decode_xor(const size_t length0, const size_t length1, float* chunkBuffer);

void delta2d_encode_xor_double(const size_t length0, const size_t length1, double* chunkBuffer);
void delta2d_decode_xor_double(const size_t length0, const size_t length1, double* chunkBuffer);


#endif /* deleta2d_h */
