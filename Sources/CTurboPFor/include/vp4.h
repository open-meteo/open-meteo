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
//  "TurboPFor: Integer Compression" PFor/PForDelta  + Direct access
#ifndef VP4_H_
#define VP4_H_
#if defined(_MSC_VER) && _MSC_VER < 1600
#include "vs/stdint.h"
#else
#include <stdint.h>
#endif
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif
//************************************************ High level API - n unlimited ****************************************************
// Compress integer array with n values to the buffer out.
// Return value = number of bytes written to compressed buffer out
size_t p4nenc8(       uint8_t  *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nenc16(      uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nenc32(      uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nenc64(      uint64_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nenc128v16(  uint16_t *__restrict in, size_t n, unsigned char *__restrict out); // SIMD (Vertical bitpacking)
size_t p4nenc128v32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nenc128v64(  uint64_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nenc256w32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nenc256v32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out);


size_t p4ndenc8(      uint8_t  *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4ndenc16(     uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4ndenc32(     uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4ndenc128v16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4ndenc128v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4ndenc256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4ndenc64(     uint64_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t p4nd1enc8(     uint8_t  *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nd1enc16(    uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nd1enc32(    uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nd1enc128v16(uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nd1enc128v32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nd1enc256v32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nd1enc64(    uint64_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t p4nzenc8(      uint8_t  *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nzenc16(     uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nzenc32(     uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nzenc128v16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nzenc128v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nzenc256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t p4nzenc64(     uint64_t *__restrict in, size_t n, unsigned char *__restrict out);

// Decompress the compressed n values in input buffer in to the integer array out.
// Return value = number of bytes read from the ompressed buffer in
size_t p4ndec8(       unsigned char *__restrict in, size_t n, uint8_t  *__restrict out);
size_t p4ndec16(      unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4ndec32(      unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4ndec64(      unsigned char *__restrict in, size_t n, uint64_t *__restrict out);
size_t p4ndec128v16(  unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4ndec128v32(  unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4ndec128v64(  unsigned char *__restrict in, size_t n, uint64_t *__restrict out);
size_t p4ndec256v32(  unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

// Delta minimum = 0
size_t p4nddec8(      unsigned char *__restrict in, size_t n, uint8_t  *__restrict out);
size_t p4nddec16(     unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4nddec32(     unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nddec128v16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4nddec128v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nddec256w32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nddec256v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nddec64(     unsigned char *__restrict in, size_t n, uint64_t *__restrict out);
// Delta minimum = 1
size_t p4nd1dec8(     unsigned char *__restrict in, size_t n, uint8_t  *__restrict out);
size_t p4nd1dec16(    unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4nd1dec32(    unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nd1dec128v16(unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4nd1dec128v32(unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nd1dec256v32(unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nd1dec64(    unsigned char *__restrict in, size_t n, uint64_t *__restrict out);
//Zigzag
size_t p4nzdec8(      unsigned char *__restrict in, size_t n, uint8_t  *__restrict out);
size_t p4nzdec16(     unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4nzdec32(     unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nzdec128v16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t p4nzdec128v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nzdec256v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t p4nzdec64(     unsigned char *__restrict in, size_t n, uint64_t *__restrict out);

//************** Low level API - n limited to 128/256 ***************************************
#define P4D_MAX 256

// -------------- TurboPFor: Encode ------------
//#include <assert.h>
// Low level API: Single block n limited
//compress integer array with n values to the buffer out. Return value = end of compressed buffer out
unsigned char *p4enc8(       uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out);
unsigned char *p4enc16(      uint16_t *__restrict in, unsigned n, unsigned char *__restrict out);
unsigned char *p4enc32(      uint32_t *__restrict in, unsigned n, unsigned char *__restrict out);
unsigned char *p4enc128v16(  uint16_t *__restrict in, unsigned n, unsigned char *__restrict out); // SSE (Vertical bitpacking)
unsigned char *p4enc128v32(  uint32_t *__restrict in, unsigned n, unsigned char *__restrict out);
unsigned char *p4enc128v64(  uint64_t *__restrict in, unsigned n, unsigned char *__restrict out);
unsigned char *p4enc256v32(  uint32_t *__restrict in, unsigned n, unsigned char *__restrict out); // AVX2
unsigned char *p4enc64(      uint64_t *__restrict in, unsigned n, unsigned char *__restrict out);

unsigned char *p4enc256w32(  uint32_t *__restrict in, unsigned n, unsigned char *__restrict out);

unsigned char *p4encx8(      uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out);// Direct access
unsigned char *p4encx16(     uint16_t *__restrict in, unsigned n, unsigned char *__restrict out);
unsigned char *p4encx32(     uint32_t *__restrict in, unsigned n, unsigned char *__restrict out);
unsigned char *p4encx64(     uint64_t *__restrict in, unsigned n, unsigned char *__restrict out);

unsigned char *p4denc8(      uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out, uint8_t  start);
unsigned char *p4denc16(     uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start);
unsigned char *p4denc32(     uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4denc128v16( uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start);
unsigned char *p4denc128v32( uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4denc256v32( uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4denc64(     uint64_t *__restrict in, unsigned n, unsigned char *__restrict out, uint64_t start);

unsigned char *p4denc256w32( uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);

unsigned char *p4dencx8(     uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out, uint8_t  start); // Direct access
unsigned char *p4dencx16(    uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start);
unsigned char *p4dencx32(    unsigned *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);

unsigned char *p4d1enc8(     uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out, uint8_t  start);
unsigned char *p4d1enc16(    uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start);
unsigned char *p4d1enc32(    uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4d1enc128v16(uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start); // SIMD (Vertical bitpacking)
unsigned char *p4d1enc128v32(uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4d1enc256v32(uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4d1enc64(    uint64_t *__restrict in, unsigned n, unsigned char *__restrict out, uint64_t start);

unsigned char *p4d1encx8(    uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out, uint8_t  start); // Direct access
unsigned char *p4d1encx16(   uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start);
unsigned char *p4d1encx32(   uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);

unsigned char *p4zenc8(      uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out, uint8_t  start);
unsigned char *p4zenc16(     uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start);
unsigned char *p4zenc32(     uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4zenc128v16( uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, uint16_t start);
unsigned char *p4zenc128v32( uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4zenc256v32( uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, uint32_t start);
unsigned char *p4zenc64(     uint64_t *__restrict in, unsigned n, unsigned char *__restrict out, uint64_t start);

unsigned char *p4senc16(uint16_t      *in, unsigned n, unsigned char *out, uint16_t start);
unsigned char *p4senc32(uint32_t      *in, unsigned n, unsigned char *out, uint32_t start);
unsigned char *p4senc64(uint64_t      *in, unsigned n, unsigned char *out, uint64_t start);

unsigned char *p4sdec16(unsigned char *in, unsigned n, uint16_t *out,      uint16_t start);
unsigned char *p4sdec32(unsigned char *in, unsigned n, uint32_t *out,      uint32_t start);
unsigned char *p4sdec64(unsigned char *in, unsigned n, uint64_t *out,      uint64_t start);

size_t p4nsenc16(uint16_t *in, size_t n, unsigned char *out);
size_t p4nsenc32(uint32_t *in, size_t n, unsigned char *out);
size_t p4nsenc64(uint64_t *in, size_t n, unsigned char *out);

size_t p4nsdec16(unsigned char *in, size_t n, uint16_t *out);
size_t p4nsdec32(unsigned char *in, size_t n, uint32_t *out);
size_t p4nsdec64(unsigned char *in, size_t n, uint64_t *out);

// same as p4enc, but with b and bx as parameters. Call after _p4bitsXX
inline unsigned char *_p4enc8(      uint8_t  *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4enc16(     uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4enc32(     uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4enc128v16( uint16_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx); // SIMD (Vertical bitpacking)
inline unsigned char *_p4enc128v32( uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx); // SIMD (Vertical bitpacking)
inline unsigned char *_p4enc128v64( uint64_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx); // SIMD (Vertical bitpacking)
inline unsigned char *_p4enc256v32( uint32_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4enc64(     uint64_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx);
// calculate the best bit sizes b and bx, return b.
unsigned _p4bits8(           uint8_t  *__restrict in, unsigned n, unsigned *pbx);
unsigned _p4bits16(          uint16_t *__restrict in, unsigned n, unsigned *pbx);
unsigned _p4bits32(          uint32_t *__restrict in, unsigned n, unsigned *pbx);
unsigned _p4bits64(          uint64_t *__restrict in, unsigned n, unsigned *pbx);

unsigned _p4bitsx8(          uint8_t  *__restrict in, unsigned n, unsigned *pbx);
unsigned _p4bitsx16(         uint16_t *__restrict in, unsigned n, unsigned *pbx);
unsigned _p4bitsx32(         uint32_t *__restrict in, unsigned n, unsigned *pbx);
unsigned _p4bitsx64(         uint64_t *__restrict in, unsigned n, unsigned *pbx);

#define P4HVE(_out_, _b_, _bx_,_usize_) do { if(!_bx_) *_out_++ = _b_;else if(_bx_ <= _usize_) *_out_++ = 0x80|_b_, *_out_++ = _bx_; else *_out_++= (_bx_ == _usize_+1?0x40:0xc0)|_b_; } while(0)

#define P4HVE8( _out_, _b_, _bx_) P4HVE(_out_, _b_, _bx_, 8)
#define P4HVE16(_out_, _b_, _bx_) P4HVE(_out_, _b_, _bx_,16)
#define P4HVE32(_out_, _b_, _bx_) P4HVE(_out_, _b_, _bx_,32)
#define P4HVE64(_out_, _b_, _bx_) do { unsigned _c = _b_==64?64-1:_b_; P4HVE(_out_, _c, _bx_,64); } while(0)

//---------------------------- TurboPFor: Decode --------------------------------------------------------
// decompress a previously (with p4enc32) bit packed array. Return value = end of packed buffer in
//-- scalar. (see p4getx32 for direct access)
// b and bx specified (not stored within the compressed stream header)
inline unsigned char *_p4dec8(       unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4dec16(      unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4dec32(      unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4dec128v16(  unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, unsigned b, unsigned bx); // SIMD (Vertical BitPacking)
inline unsigned char *_p4dec128v32(  unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4dec128v64(  unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, unsigned b, unsigned bx);
inline unsigned char *_p4dec64(      unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, unsigned b, unsigned bx);

unsigned char *p4dec8(        unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out);
unsigned char *p4dec16(       unsigned char *__restrict in, unsigned n, uint16_t *__restrict out);
unsigned char *p4dec32(       unsigned char *__restrict in, unsigned n, uint32_t *__restrict out);
unsigned char *p4dec128v16(   unsigned char *__restrict in, unsigned n, uint16_t *__restrict out);  // SIMD (Vertical BitPacking)
unsigned char *p4dec128v32(   unsigned char *__restrict in, unsigned n, uint32_t *__restrict out);
unsigned char *p4dec128v64(   unsigned char *__restrict in, unsigned n, uint64_t *__restrict out);
unsigned char *p4dec256v32(   unsigned char *__restrict in, unsigned n, uint32_t *__restrict out);
unsigned char *p4dec64(       unsigned char *__restrict in, unsigned n, uint64_t *__restrict out);
//------ Delta decoding --------------------------- Return value = end of packed input buffer in ---------------------------
//-- Increasing integer lists. out[i] = out[i-1] + in[i]
// b and bx specified
unsigned char *_p4ddec8(      unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out, uint8_t  start, unsigned b, unsigned bx);
unsigned char *_p4ddec16(     unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start, unsigned b, unsigned bx);
unsigned char *_p4ddec32(     unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
unsigned char *_p4ddec128v16( unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start, unsigned b, unsigned bx);
unsigned char *_p4ddec128v32( unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
unsigned char *_p4ddec256v32( unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
unsigned char *_p4ddec64(     unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, uint64_t start, unsigned b, unsigned bx);

unsigned char *p4ddec8(       unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out, uint8_t  start);
unsigned char *p4ddec16(      unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start);
unsigned char *p4ddec32(      unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4ddec128v16(  unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start); // SIMD (Vertical BitPacking)
unsigned char *p4ddec128v32(  unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4ddec256v32(  unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4ddec64(      unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, uint64_t start);

//-- Strictly increasing (never remaining constant or decreasing) integer lists. out[i] = out[i-1] + in[i] +  1
// b and bx specified (see idxcr.c/idxqry.c for an example)
unsigned char *_p4d1dec8(     unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out, uint8_t  start, unsigned b, unsigned bx);
unsigned char *_p4d1dec16(    unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start, unsigned b, unsigned bx);
unsigned char *_p4d1dec32(    unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
unsigned char *_p4d1dec128v16(unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start, unsigned b, unsigned bx); // SIMD (Vertical BitPacking)
unsigned char *_p4d1dec128v32(unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
unsigned char *_p4d1dec256v32(unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
unsigned char *_p4d1dec64(    unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, uint64_t start, unsigned b, unsigned bx);

unsigned char *p4d1dec8(      unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out, uint8_t  start);
unsigned char *p4d1dec16(     unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start);
unsigned char *p4d1dec32(     unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4d1dec128v16( unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start); // SIMD (Vertical BitPacking)
unsigned char *p4d1dec128v32( unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4d1dec256v32( unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4d1dec64(     unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, uint64_t start);

// ZigZag encoding
inline unsigned char *_p4zdec8(      unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out, uint8_t  start, unsigned b, unsigned bx);
inline unsigned char *_p4zdec16(     unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start, unsigned b, unsigned bx);
inline unsigned char *_p4zdec32(     unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
inline unsigned char *_p4zdec128v16( unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start, unsigned b, unsigned bx);
inline unsigned char *_p4zdec128v32( unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
inline unsigned char *_p4zdec256v32( unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start, unsigned b, unsigned bx);
inline unsigned char *_p4zdec64(     unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, uint64_t start, unsigned b, unsigned bx);

unsigned char *p4zdec8(       unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out, uint8_t  start);
unsigned char *p4zdec16(      unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start);
unsigned char *p4zdec32(      unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4zdec128v16(  unsigned char *__restrict in, unsigned n, uint16_t *__restrict out, uint16_t start); // SIMD (Vertical BitPacking)
unsigned char *p4zdec128v32(  unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4zdec256v32(  unsigned char *__restrict in, unsigned n, uint32_t *__restrict out, uint32_t start);
unsigned char *p4zdec64(      unsigned char *__restrict in, unsigned n, uint64_t *__restrict out, uint64_t start);

//---------------- Direct Access functions to compressed TurboPFor array p4encx16/p4encx32 -------------------------------------------------------
  #ifdef TURBOPFOR_DAC
#include "conf.h"
#define P4D_PAD8(_x_)       ( (((_x_)+8-1)/8) )
#define P4D_B(_x_)          ((_x_) & 0x7f)
#define P4D_XB(_x_)         (((_x_) & 0x80)?((_x_) >> 8):0)
#define P4D_ININC(_in_, _x_) _in_ += 1+((_x_) >> 7)

static inline unsigned p4bits(unsigned char *__restrict in, int *bx) { unsigned i = ctou16(in); *bx = P4D_XB(i); return P4D_B(i); }

struct p4 {
  unsigned long long *xmap;
  unsigned char *ex;
  unsigned isx,bx,cum[P4D_MAX/64+1];
  int oval,idx;
};

static unsigned long long p4xmap[P4D_MAX/64+1] = { 0 };

// prepare direct access usage
static inline void p4ini(struct p4 *p4, unsigned char **pin, unsigned n, unsigned *b) { unsigned char *in = *pin;
  unsigned p4i  = ctou16(in);
  p4->isx       = p4i&0x80;
  *b            = P4D_B(p4i);
  p4->bx        = P4D_XB(p4i);              //printf("p4i=%x,b=%d,bx=%d ", p4->i, *b, p4->bx);                        //assert(n <= P4D_MAX);
  *pin = p4->ex = ++in;
  if(p4->isx) {
    unsigned num=0,j;
    unsigned char *p;
    ++in;
    p4->xmap = (unsigned long long *)in;
    for(j=0; j < n/64; j++) { p4->cum[j] = num; num += popcnt64(ctou64(in+j*8)); }
    if(n & 0x3f) num += popcnt64(ctou64(in+j*8) & ((1ull<<(n&0x3f))-1) );
    p4->ex = p = in + (n+7)/8;
    *pin   = p = p4->ex+(((uint64_t)num*p4->bx+7)/8);
  } else p4->xmap = p4xmap;
  p4->oval = p4->idx  = -1;
}

//---------- Get a single value with index "idx" from a "p4encx32" packed array
static ALWAYS_INLINE uint8_t  p4getx8( struct p4 *p4, unsigned char *in, unsigned idx, unsigned b) { unsigned bi, cl, u = bitgetx8( in, idx, b);
  if(p4->xmap[bi=idx>>6] & (1ull<<(cl=idx&63))) u += bitgetx8(p4->ex, p4->cum[bi] + popcnt64(p4->xmap[bi] & ~(~0ull<<cl)), p4->bx) << b;
  return u;
}

static ALWAYS_INLINE uint16_t p4getx16(struct p4 *p4, unsigned char *in, unsigned idx, unsigned b) { unsigned bi, cl, u = bitgetx16(in, idx, b);
  if(p4->xmap[bi=idx>>6] & (1ull<<(cl=idx&63))) u += bitgetx16(p4->ex, p4->cum[bi] + popcnt64(p4->xmap[bi] & ~(~0ull<<cl)), p4->bx) << b;
  return u;
}
static ALWAYS_INLINE uint32_t p4getx32(struct p4 *p4, unsigned char *in, unsigned idx, unsigned b) { unsigned bi, cl, u = bitgetx32(in, idx, b);
  if(p4->xmap[bi=idx>>6] & (1ull<<(cl=idx&63))) u += bitgetx32(p4->ex, p4->cum[bi] + popcnt64(p4->xmap[bi] & ~(~0ull<<cl)), p4->bx) << b;
  return u;
}

// Get the next single value greater of equal to val
static ALWAYS_INLINE uint16_t p4geqx8( struct p4 *p4, unsigned char *in, unsigned b, uint8_t  val) { do p4->oval += p4getx8( p4, in, ++p4->idx, b)+1; while(p4->oval < val); return p4->oval; }
static ALWAYS_INLINE uint16_t p4geqx16(struct p4 *p4, unsigned char *in, unsigned b, uint16_t val) { do p4->oval += p4getx16(p4, in, ++p4->idx, b)+1; while(p4->oval < val); return p4->oval; }
static ALWAYS_INLINE uint32_t p4geqx32(struct p4 *p4, unsigned char *in, unsigned b, uint32_t val) { do p4->oval += p4getx32(p4, in, ++p4->idx, b)+1; while(p4->oval < val); return p4->oval; }

/* DO NOT USE : like p4dec32 but using direct access. This is only a demo showing direct access usage. Use p4dec32 instead for decompressing entire blocks */
unsigned char *p4decx32(   unsigned char *in, unsigned n, uint32_t *out);  // unsorted
unsigned char *p4fdecx32(  unsigned char *in, unsigned n, uint32_t *out, uint32_t start); // FOR increasing
unsigned char *p4f1decx32( unsigned char *in, unsigned n, uint32_t *out, uint32_t start); // FOR strictly increasing
  #endif

#ifdef __cplusplus
}
#endif

#endif
