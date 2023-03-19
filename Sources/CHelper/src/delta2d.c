#include "delta2d.h"

void delta2d_decode(const size_t length0, const size_t length1, short* chunkBuffer) {
    if (length0 <= 1) {
        return;
    }
    for (size_t d0 = 1; d0 < length0; d0++) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBuffer[d0*length1 + d1] += chunkBuffer[(d0-1)*length1 + d1];
        }
    }
}

void delta2d_encode(const size_t length0, const size_t length1, short* chunkBuffer) {
    if (length0 <= 1) {
        return;
    }
    for (size_t d0 = 1; d0 < length0; d0++) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBuffer[d0*length1 + d1] -= chunkBuffer[(d0-1)*length1 + d1];
        }
    }
}

void delta2d_xor(const size_t length0, const size_t length1, float* chunkBuffer) {
    if (length0 <= 1) {
        return;
    }
    int* chunkBufferInt = (int*)chunkBuffer;
    for (size_t d0 = 1; d0 < length0; d0++) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBufferInt[d0*length1 + d1] ^= chunkBufferInt[(d0-1)*length1 + d1];
        }
    }
}
