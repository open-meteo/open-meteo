/**
    Copyright (C) powturbo 2013-2019
    GPL v2 License

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

    - homepage : https://sites.google.com/site/powturbo/
    - github   : https://github.com/powturbo
    - twitter  : https://twitter.com/powturbo
    - email    : powturbo [_AT_] gmail [_DOT_] com
**/
//   transpose.h - Byte/Nibble transpose for further compressing with lz77 or other compressors
#ifdef __cplusplus
extern "C" {
#endif
// Syntax
// in    : Input buffer
// n     : Total number of bytes in input buffer
// out   : output buffer
// esize : element size in bytes (ex. 2, 4, 8,... )

//---------- High level functions with dynamic cpu detection and JIT scalar/sse/avx2 switching
void tpenc(       unsigned char *in, unsigned n, unsigned char *out, unsigned esize); // tranpose
void tpdec(       unsigned char *in, unsigned n, unsigned char *out, unsigned esize); // reverse transpose

void tp2denc(unsigned char *in,             unsigned x, unsigned y,             unsigned char *out, unsigned esize); //2D transpose
void tp2ddec(unsigned char *in,             unsigned x, unsigned y,             unsigned char *out, unsigned esize);
void tp3denc(unsigned char *in,             unsigned x, unsigned y, unsigned z, unsigned char *out, unsigned esize); //3D transpose
void tp3ddec(unsigned char *in,             unsigned x, unsigned y, unsigned z, unsigned char *out, unsigned esize);
void tp4denc(unsigned char *in, unsigned w, unsigned x, unsigned y, unsigned z, unsigned char *out, unsigned esize); //4D transpose
void tp4ddec(unsigned char *in, unsigned w, unsigned x, unsigned y, unsigned z, unsigned char *out, unsigned esize);

// Nibble transpose SIMD (SSE2,AVX2, ARM Neon)
void tp4enc(      unsigned char *in, unsigned n, unsigned char *out, unsigned esize);
void tp4dec(      unsigned char *in, unsigned n, unsigned char *out, unsigned esize);

// bit transpose
//void tp1enc(      unsigned char *in, unsigned n, unsigned char *out, unsigned esize);
//void tp1dec(      unsigned char *in, unsigned n, unsigned char *out, unsigned esize);

//---------- Low level functions ------------------------------------
void tpenc2(      unsigned char *in, unsigned n, unsigned char *out);  // scalar
void tpenc3(      unsigned char *in, unsigned n, unsigned char *out);
void tpenc4(      unsigned char *in, unsigned n, unsigned char *out);
void tpenc8(      unsigned char *in, unsigned n, unsigned char *out);
void tpenc16(     unsigned char *in, unsigned n, unsigned char *out);

void tpdec2(      unsigned char *in, unsigned n, unsigned char *out);
void tpdec3(      unsigned char *in, unsigned n, unsigned char *out);
void tpdec4(      unsigned char *in, unsigned n, unsigned char *out);
void tpdec8(      unsigned char *in, unsigned n, unsigned char *out);
void tpdec16(     unsigned char *in, unsigned n, unsigned char *out);

void tpenc128v2(  unsigned char *in, unsigned n, unsigned char *out);   // sse2
void tpdec128v2(  unsigned char *in, unsigned n, unsigned char *out);
void tpenc128v4(  unsigned char *in, unsigned n, unsigned char *out);
void tpdec128v4(  unsigned char *in, unsigned n, unsigned char *out);
void tpenc128v8(  unsigned char *in, unsigned n, unsigned char *out);
void tpdec128v8(  unsigned char *in, unsigned n, unsigned char *out);

void tp4enc128v2( unsigned char *in, unsigned n, unsigned char *out);
void tp4dec128v2( unsigned char *in, unsigned n, unsigned char *out);
void tp4enc128v4( unsigned char *in, unsigned n, unsigned char *out);
void tp4dec128v4( unsigned char *in, unsigned n, unsigned char *out);
void tp4enc128v8( unsigned char *in, unsigned n, unsigned char *out);
void tp4dec128v8( unsigned char *in, unsigned n, unsigned char *out);

void tp1enc128v2( unsigned char *in, unsigned n, unsigned char *out);
void tp1dec128v2( unsigned char *in, unsigned n, unsigned char *out);
void tp1enc128v4( unsigned char *in, unsigned n, unsigned char *out);
void tp1dec128v4( unsigned char *in, unsigned n, unsigned char *out);
void tp1enc128v8( unsigned char *in, unsigned n, unsigned char *out);
void tp1dec128v8( unsigned char *in, unsigned n, unsigned char *out);

void tpenc256v2(  unsigned char *in, unsigned n, unsigned char *out);   // avx2
void tpdec256v2(  unsigned char *in, unsigned n, unsigned char *out);
void tpenc256v4(  unsigned char *in, unsigned n, unsigned char *out);
void tpdec256v4(  unsigned char *in, unsigned n, unsigned char *out);
void tpenc256v8(  unsigned char *in, unsigned n, unsigned char *out);
void tpdec256v8(  unsigned char *in, unsigned n, unsigned char *out);

void tp4enc256v2( unsigned char *in, unsigned n, unsigned char *out);
void tp4dec256v2( unsigned char *in, unsigned n, unsigned char *out);
void tp4enc256v4( unsigned char *in, unsigned n, unsigned char *out);
void tp4dec256v4( unsigned char *in, unsigned n, unsigned char *out);
void tp4enc256v8( unsigned char *in, unsigned n, unsigned char *out);
void tp4dec256v8( unsigned char *in, unsigned n, unsigned char *out);

//------- CPU instruction set
// cpuiset  = 0: return current simd set,
// cpuiset != 0: set simd set 0:scalar, 20:sse2, 52:avx2
unsigned cpuini(unsigned cpuiset);

// convert simd set to string "sse3", "sse3", "sse4.1" or "avx2"
// Ex.: printf("current cpu set=%s\n", cpustr(cpuini(0)) );
char *cpustr(unsigned cpuisa);

unsigned cpuisa(void);
#ifdef __cplusplus
}
#endif
