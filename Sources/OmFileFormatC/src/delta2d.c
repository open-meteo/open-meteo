#include "delta2d.h"

/// Divide and round up
#define divide_rounded_up(dividend,divisor) \
  ({ __typeof__ (dividend) _dividend = (dividend); \
      __typeof__ (divisor) _divisor = (divisor); \
    (_dividend + _divisor - 1) / _divisor; })

/// Maxima of 2 terms
#define max(a,b) \
  ({ __typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
    _a > _b ? _a : _b; })

/// Minima of 2 terms
#define min(a,b) \
  ({ __typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
    _a < _b ? _a : _b; })

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
    for (size_t d0 = length0-1; d0 >= 1; d0--) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBuffer[d0*length1 + d1] -= chunkBuffer[(d0-1)*length1 + d1];
        }
    }
}

void delta2d_decode32(const size_t length0, const size_t length1, int* chunkBuffer) {
    if (length0 <= 1) {
        return;
    }
    for (size_t d0 = 1; d0 < length0; d0++) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBuffer[d0*length1 + d1] += chunkBuffer[(d0-1)*length1 + d1];
        }
    }
}

void delta2d_encode32(const size_t length0, const size_t length1, int* chunkBuffer) {
    if (length0 <= 1) {
        return;
    }
    for (size_t d0 = length0-1; d0 >= 1; d0--) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBuffer[d0*length1 + d1] -= chunkBuffer[(d0-1)*length1 + d1];
        }
    }
}

void delta2d_decode_xor(const size_t length0, const size_t length1, float* chunkBuffer) {
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

void delta2d_encode_xor(const size_t length0, const size_t length1, float* chunkBuffer) {
    if (length0 <= 1) {
        return;
    }
    int* chunkBufferInt = (int*)chunkBuffer;
    for (size_t d0 = length0-1; d0 >= 1; d0--) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBufferInt[d0*length1 + d1] ^= chunkBufferInt[(d0-1)*length1 + d1];
        }
    }
}

void delta2d_decode_xor_double(const size_t length0, const size_t length1, double* chunkBuffer) {
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

void delta2d_encode_xor_double(const size_t length0, const size_t length1, double* chunkBuffer) {
    if (length0 <= 1) {
        return;
    }
    int* chunkBufferInt = (int*)chunkBuffer;
    for (size_t d0 = length0-1; d0 >= 1; d0--) {
        for (size_t d1 = 0; d1 < length1; d1++) {
            chunkBufferInt[d0*length1 + d1] ^= chunkBufferInt[(d0-1)*length1 + d1];
        }
    }
}

uint64_t calcLengthInChunk(uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count) {
    uint64_t lengthInChunk = 1;
    uint64_t rollingMultiply = 1;
    for (int64_t i = dimension_count - 1; i >= 0; i--) {
        const uint64_t dimension = dimensions[i];
        const uint64_t chunk = chunks[i];
        const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
        const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
        const uint64_t length0 = min((c0 + 1) * chunk, dimension) - c0 * chunk;
        lengthInChunk *= length0;
        rollingMultiply *= nChunksInThisDimension;
    }
    return lengthInChunk;
}

/// Delta encode in n dimensional chunk space
void delta_nd_decode16(int16_t *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count) {
    if (dimension_count <= 1) {
        return;
    }
    uint64_t lengthInChunk = calcLengthInChunk(chunkIndex, dimensions, chunks, dimension_count);
    
    // note -1 because zigzag is done later
    for (int64_t nDimOuter = 0; nDimOuter < dimension_count - 1; nDimOuter++) {
        uint64_t writePos = 0;
        while (true) {
            uint64_t rollingMultiply = 1;
            uint64_t rollingMultiplyChunkLength = 1;
            uint64_t readPos = 0;
            for (int64_t i = dimension_count - 1; i >= 0; i--) {
                const uint64_t dimension = dimensions[i];
                const uint64_t chunk = chunks[i];
                const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
                const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
                const uint64_t length0 = min((c0 + 1) * chunk, dimension) - c0 * chunk;
                const uint64_t x = (writePos / rollingMultiplyChunkLength) % length0;
                //printf("writePos=%llu i=%llu x=%llu nDimOuter=%llu\n",writePos, i, x, nDimOuter);
                if (i == nDimOuter && x == 0) {
                    break;
                }
                if (i == nDimOuter) {
                    readPos += (x-1) * rollingMultiplyChunkLength;
                } else {
                    readPos += x * rollingMultiplyChunkLength;
                }
                if (i == 0) {
                    chunkbuffer[writePos] += chunkbuffer[readPos];
                }
                
                rollingMultiply *= nChunksInThisDimension;
                rollingMultiplyChunkLength *= length0;
            }
            writePos++;
            if (writePos == lengthInChunk) {
                break;
            }
        }
    }
}

/// Delta decode in n dimensional chunk space
void delta_nd_encode16(int16_t *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count) {
    if (dimension_count <= 1) {
        return;
    }
    uint64_t lengthInChunk = calcLengthInChunk(chunkIndex, dimensions, chunks, dimension_count);
    
    // note -1 because zigzag is done later
    for (int64_t nDimOuter = 0; nDimOuter < dimension_count - 1; nDimOuter++) {
        uint64_t writePos = lengthInChunk;
        while (true) {
            uint64_t rollingMultiply = 1;
            uint64_t rollingMultiplyChunkLength = 1;
            uint64_t readPos = 0;
            for (int64_t i = dimension_count - 1; i >= 0; i--) {
                const uint64_t dimension = dimensions[i];
                const uint64_t chunk = chunks[i];
                const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
                const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
                const uint64_t length0 = min((c0 + 1) * chunk, dimension) - c0 * chunk;
                const uint64_t x = (writePos / rollingMultiplyChunkLength) % length0;
                if (i == nDimOuter && x == 0) {
                    break;
                }
                if (i == nDimOuter) {
                    readPos += (x-1) * rollingMultiplyChunkLength;
                } else {
                    readPos += x * rollingMultiplyChunkLength;
                }
                if (i == 0) {
                    chunkbuffer[writePos] -= chunkbuffer[readPos];
                }
                
                rollingMultiply *= nChunksInThisDimension;
                rollingMultiplyChunkLength *= length0;
            }
            if (writePos == 0) {
                break;
            }
            writePos--;
        }
    }
}


/// xor encode in n dimensional chunk space
void xor_nd_decode_float(float *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count) {
    if (dimension_count <= 1) {
        return;
    }
    int32_t* chunkBufferInt = (int32_t*)chunkbuffer;
    uint64_t lengthInChunk = calcLengthInChunk(chunkIndex, dimensions, chunks, dimension_count);
    
    // note -1 because zigzag is done later
    for (int64_t nDimOuter = 0; nDimOuter < dimension_count - 1; nDimOuter++) {
        uint64_t writePos = 0;
        while (true) {
            uint64_t rollingMultiply = 1;
            uint64_t rollingMultiplyChunkLength = 1;
            uint64_t readPos = 0;
            for (int64_t i = dimension_count - 1; i >= 0; i--) {
                const uint64_t dimension = dimensions[i];
                const uint64_t chunk = chunks[i];
                const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
                const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
                const uint64_t length0 = min((c0 + 1) * chunk, dimension) - c0 * chunk;
                const uint64_t x = (writePos / rollingMultiplyChunkLength) % length0;
                //printf("writePos=%llu i=%llu x=%llu nDimOuter=%llu\n",writePos, i, x, nDimOuter);
                if (i == nDimOuter && x == 0) {
                    break;
                }
                if (i == nDimOuter) {
                    readPos += (x-1) * rollingMultiplyChunkLength;
                } else {
                    readPos += x * rollingMultiplyChunkLength;
                }
                if (i == 0) {
                    chunkBufferInt[writePos] ^= chunkBufferInt[readPos];
                }
                
                rollingMultiply *= nChunksInThisDimension;
                rollingMultiplyChunkLength *= length0;
            }
            writePos++;
            if (writePos == lengthInChunk) {
                break;
            }
        }
    }
}

/// xor decode in n dimensional chunk space
void xor_nd_encode_float(float *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count) {
    if (dimension_count <= 1) {
        return;
    }
    uint64_t lengthInChunk = calcLengthInChunk(chunkIndex, dimensions, chunks, dimension_count);
    int32_t* chunkBufferInt = (int32_t*)chunkbuffer;
    
    // note -1 because zigzag is done later
    for (int64_t nDimOuter = 0; nDimOuter < dimension_count - 1; nDimOuter++) {
        uint64_t writePos = lengthInChunk;
        while (true) {
            uint64_t rollingMultiply = 1;
            uint64_t rollingMultiplyChunkLength = 1;
            uint64_t readPos = 0;
            for (int64_t i = dimension_count - 1; i >= 0; i--) {
                const uint64_t dimension = dimensions[i];
                const uint64_t chunk = chunks[i];
                const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
                const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
                const uint64_t length0 = min((c0 + 1) * chunk, dimension) - c0 * chunk;
                const uint64_t x = (writePos / rollingMultiplyChunkLength) % length0;
                if (i == nDimOuter && x == 0) {
                    break;
                }
                if (i == nDimOuter) {
                    readPos += (x-1) * rollingMultiplyChunkLength;
                } else {
                    readPos += x * rollingMultiplyChunkLength;
                }
                if (i == 0) {
                    chunkBufferInt[writePos] ^= chunkBufferInt[readPos];
                }
                
                rollingMultiply *= nChunksInThisDimension;
                rollingMultiplyChunkLength *= length0;
            }
            if (writePos == 0) {
                break;
            }
            writePos--;
        }
    }
}

/// xor encode in n dimensional chunk space
void xor_nd_decode_double(double *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count) {
    if (dimension_count <= 1) {
        return;
    }
    int64_t* chunkBufferInt = (int64_t*)chunkbuffer;
    uint64_t lengthInChunk = calcLengthInChunk(chunkIndex, dimensions, chunks, dimension_count);
    
    // note -1 because zigzag is done later
    for (int64_t nDimOuter = 0; nDimOuter < dimension_count - 1; nDimOuter++) {
        uint64_t writePos = 0;
        while (true) {
            uint64_t rollingMultiply = 1;
            uint64_t rollingMultiplyChunkLength = 1;
            uint64_t readPos = 0;
            for (int64_t i = dimension_count - 1; i >= 0; i--) {
                const uint64_t dimension = dimensions[i];
                const uint64_t chunk = chunks[i];
                const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
                const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
                const uint64_t length0 = min((c0 + 1) * chunk, dimension) - c0 * chunk;
                const uint64_t x = (writePos / rollingMultiplyChunkLength) % length0;
                //printf("writePos=%llu i=%llu x=%llu nDimOuter=%llu\n",writePos, i, x, nDimOuter);
                if (i == nDimOuter && x == 0) {
                    break;
                }
                if (i == nDimOuter) {
                    readPos += (x-1) * rollingMultiplyChunkLength;
                } else {
                    readPos += x * rollingMultiplyChunkLength;
                }
                if (i == 0) {
                    chunkBufferInt[writePos] ^= chunkBufferInt[readPos];
                }
                
                rollingMultiply *= nChunksInThisDimension;
                rollingMultiplyChunkLength *= length0;
            }
            writePos++;
            if (writePos == lengthInChunk) {
                break;
            }
        }
    }
}

/// xor decode in n dimensional chunk space
void xor_nd_encode_double(double *chunkbuffer, uint64_t chunkIndex, const uint64_t* dimensions, const uint64_t* chunks, uint64_t dimension_count) {
    if (dimension_count <= 1) {
        return;
    }
    uint64_t lengthInChunk = calcLengthInChunk(chunkIndex, dimensions, chunks, dimension_count);
    int64_t* chunkBufferInt = (int64_t*)chunkbuffer;
    
    // note -1 because zigzag is done later
    for (int64_t nDimOuter = 0; nDimOuter < dimension_count - 1; nDimOuter++) {
        uint64_t writePos = lengthInChunk;
        while (true) {
            uint64_t rollingMultiply = 1;
            uint64_t rollingMultiplyChunkLength = 1;
            uint64_t readPos = 0;
            for (int64_t i = dimension_count - 1; i >= 0; i--) {
                const uint64_t dimension = dimensions[i];
                const uint64_t chunk = chunks[i];
                const uint64_t nChunksInThisDimension = divide_rounded_up(dimension, chunk);
                const uint64_t c0 = (chunkIndex / rollingMultiply) % nChunksInThisDimension;
                const uint64_t length0 = min((c0 + 1) * chunk, dimension) - c0 * chunk;
                const uint64_t x = (writePos / rollingMultiplyChunkLength) % length0;
                if (i == nDimOuter && x == 0) {
                    break;
                }
                if (i == nDimOuter) {
                    readPos += (x-1) * rollingMultiplyChunkLength;
                } else {
                    readPos += x * rollingMultiplyChunkLength;
                }
                if (i == 0) {
                    chunkBufferInt[writePos] ^= chunkBufferInt[readPos];
                }
                
                rollingMultiply *= nChunksInThisDimension;
                rollingMultiplyChunkLength *= length0;
            }
            if (writePos == 0) {
                break;
            }
            writePos--;
        }
    }
}
