#ifndef delta2d_h
#define delta2d_h

#include <stdio.h>

void delta2d_decode(const size_t length0, const size_t length1, short* chunkBuffer);
void delta2d_encode(const size_t length0, const size_t length1, short* chunkBuffer);

void delta2d_encode_xor(const size_t length0, const size_t length1, float* chunkBuffer);
void delta2d_decode_xor(const size_t length0, const size_t length1, float* chunkBuffer);


#endif /* deleta2d_h */
