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
//  "Integer Compression" bit packing

#ifdef GUARDED


#include <stdio.h>
#define BITUTIL_IN
#define VINT_IN
#include "conf.h"
#include "bitutil.h"
#include "vint.h"
#include "bitpack.h"
#define PAD8(_x_) ( (((_x_)+8-1)/8) )

  #ifdef __ARM_NEON
#define PREFETCH(_ip_,_rw_)
  #else
#define PREFETCH(_ip_,_rw_) __builtin_prefetch(_ip_,_rw_)
  #endif

#pragma warning( disable : 4005)
#pragma warning( disable : 4090)
#pragma warning( disable : 4068)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunsequenced"

#if !defined(SSE2_ON) && !defined(AVX2_ON) //----------------------------------- Plain -----------------------------------------------------------------------
typedef unsigned char *(*BITPACK_F8)( uint8_t  *__restrict out, unsigned n, const unsigned char *__restrict in);
typedef unsigned char *(*BITPACK_D8)( uint8_t  *__restrict out, unsigned n, const unsigned char *__restrict in, uint8_t start);
typedef unsigned char *(*BITPACK_F16)(uint16_t *__restrict out, unsigned n, const unsigned char *__restrict in);
typedef unsigned char *(*BITPACK_D16)(uint16_t *__restrict out, unsigned n, const unsigned char *__restrict in, uint16_t start);
typedef unsigned char *(*BITPACK_F32)(uint32_t *__restrict out, unsigned n, const unsigned char *__restrict in);
typedef unsigned char *(*BITPACK_D32)(uint32_t *__restrict out, unsigned n, const unsigned char *__restrict in, uint32_t start);
typedef unsigned char *(*BITPACK_F64)(uint64_t *__restrict out, unsigned n, const unsigned char *__restrict in);
typedef unsigned char *(*BITPACK_D64)(uint64_t *__restrict out, unsigned n, const unsigned char *__restrict in, uint64_t start);

#if 1 //def _MSC_VER
#define VX (v=x)
#define V  x
#else
#define VX v
#define V  v
#endif

#if 0
#define IP0(_ip_,_x_) *_ip_
#define IP( _ip_,_x_) *_ip_++
#define IPI(_ip_)
#else
#define IP0(_ip_,_x_) _ip_[_x_]
#define IP( _ip_,_x_) _ip_[_x_]
#define IPI(_ip_) _ip_ += 32
#endif

#define IP9(_ip_,_x_, _parm_)
#define IPW(_ip_,_x_)           VX
#define IPX(_ip_,_x_)           (V = IP(_ip_,_x_))

#define IPV(_ip_,_x_)           IP(_ip_,_x_)
#define IP16(_ip_,_x_, _parm_)
#define IP32(_ip_,_x_, _parm_)
#define IP64(_ip_,_x_, _parm_)
#define _BITPACK_ bitpack
#include "bitpack_.h"
#undef IP9
#undef IPV
#undef IPX
#undef IP16
#undef IP32
#undef IP64

#define DELTA

#define IP9(_ip_,_x_, _parm_)   V = IP0(_ip_,_x_) - start; start = IP(_ip_,_x_)
#define IPV(_ip_,_x_)           VX
#define IPX(_ip_,_x_)          (V = IP(_ip_,_x_) - start)
#define IP16(_ip_,_x_, _parm_)   start = IP(_ip_,_x_)
#define IP32(_ip_,_x_, _parm_)   start = IP(_ip_,_x_)
#define IP64(_ip_,_x_, _parm_)   start = IP(_ip_,_x_)
#define _BITPACK_ bitdpack
#include "bitpack_.h"
#undef IP9
#undef IPV
#undef IPX
#undef IP16
#undef IP32
#undef IP64

#define IP9(_ip_,_x_, _parm_)
#define IPV(_ip_,_x_)           IP(_ip_,_x_) - start
#define IPX(_ip_,_x_)           (V = IP(_ip_,_x_) - start)
#define IP16(_ip_,_x_, _parm_)
#define IP32(_ip_,_x_, _parm_)
#define IP64(_ip_,_x_, _parm_)
#define _BITPACK_ bitfpack
#include "bitpack_.h"
#undef IP9
#undef IPV
#undef IPX
#undef IP16
#undef IP32
#undef IP64

#define IP9( _ip_,_x_, _parm_)  V = IP0(_ip_,_x_) - start - 1; start = IP(_ip_,_x_)
#define IPV( _ip_,_x_)          VX
#define IPX(_ip_,_x_)          (V = IP(_ip_,_x_) - start - 1)
#define IP16(_ip_,_x_, _parm_)   start = IP(_ip_,_x_)
#define IP32(_ip_,_x_, _parm_)   start = IP(_ip_,_x_)
#define IP64(_ip_,_x_, _parm_)   start = IP(_ip_,_x_)
#define _BITPACK_ bitd1pack
#include "bitpack_.h"
#undef IP9
#undef IPV
#undef IPX
#undef IP16
#undef IP32
#undef IP64

/*#define IP9( _ip_,_x_, _parm_)    v = IP(_ip_,_x_) - start - mdelta; start = IP(_ip_,_x_)
#define IPV( _ip_,_x_)          v
#define IPX(_ip_,_x_)          (v = IP(_ip_,_x_) - start - mdelta)
#define IP32(_ip_,_x_, _parm_)   start = IP(_ip_,_x_)
#define _BITPACK_ bitepack
#include "bitpack_.h"*/

#define IP9(_ip_,_x_, _parm_)   V = TEMPLATE2(zigzagenc, USIZE)(IP(_ip_,_x_) - start); start = IP(_ip_,_x_)
#define IPV(_ip_,_x_)           VX
#define IPX(_ip_,_x_)          (V = TEMPLATE2(zigzagenc, USIZE)(IP(_ip_,_x_) - start))
#define IP16(_ip_,_x_, _parm_)  start = IP(_ip_,_x_)
#define IP32(_ip_,_x_, _parm_)  start = IP(_ip_,_x_)
#define IP64(_ip_,_x_, _parm_)  start = IP(_ip_,_x_)
#define _BITPACK_ bitzpack
#include "bitpack_.h"
#undef IP9
#undef IPV
#undef IPX
#undef IP16
#undef IP32
#undef IP64

#define IPI(_ip_) _ip_ += 32; start += 32
#define IP9(_ip_,_x_, _parm_)
#define IPV(_ip_,_x_)           (IP(_ip_,_x_) - start - (_x_) - 1)
#define IPX(_ip_,_x_)           (V = IP(_ip_,_x_) - start - (_x_) - 1)
#define IP16(_ip_,_x_, _parm_)
#define IP32(_ip_,_x_, _parm_)
#define IP64(_ip_,_x_, _parm_)
#define _BITPACK_ bitf1pack
#include "bitpack_.h"
#undef IPI
#undef IP9
#undef IPV
#undef IPX
#undef IP16
#undef IP32
#undef IP64

#define BITNPACK(in, n, out, _csize_, _usize_) { unsigned char *op = out;\
  for(ip = in, in += n; ip < in;) { \
    TEMPLATE3(uint, _usize_, _t) o,x;\
    unsigned iplen = in - ip,b; \
    if(iplen > _csize_) iplen = _csize_;                            PREFETCH(ip+512,0);\
    o = TEMPLATE2(bit,_usize_)(ip, iplen, &x); b = TEMPLATE2(bsr,_usize_)(o);\
    *op++ = b; op = TEMPLATE2(bitpacka, _usize_)[b](ip, iplen, op);\
    ip += iplen;\
  }\
  return op - out;\
}

#define BITNDPACK(in, n, out, _csize_, _usize_, _bitd_, _bitpacka_) { if(!n) return 0;\
  unsigned char *op = out; \
  TEMPLATE3(uint, _usize_, _t) o,x;\
  start = *in++; \
  TEMPLATE2(vbxput, _usize_)(op, start);\
  for(n--,ip = in; ip != in + (n&~(_csize_-1)); ) { unsigned b;     PREFETCH(ip+512,0);\
    o = TEMPLATE2(_bitd_, _usize_)(ip, _csize_, &x, start); b = TEMPLATE2(bsr,_usize_)(o); *op++ = b; op = TEMPLATE2(_bitpacka_,_usize_)[b](ip, _csize_, op, start); ip += _csize_; start = ip[-1];\
  }\
  if(n&=(_csize_-1)) { unsigned b;\
    o = TEMPLATE2(_bitd_, _usize_)(ip, n,       &x, start); b = TEMPLATE2(bsr,_usize_)(o); *op++ = b; op = TEMPLATE2(_bitpacka_,_usize_)[b](ip, n,       op, start);\
  }\
  return op - out;\
}

size_t bitnpack8(   uint8_t  *__restrict in, size_t n, unsigned char *__restrict out) { uint8_t  *ip,start; BITNPACK(in, n, out, 128,  8); }
size_t bitnpack16(  uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; BITNPACK(in, n, out, 128, 16); }
size_t bitnpack32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; BITNPACK(in, n, out, 128, 32); }
size_t bitnpack64(  uint64_t *__restrict in, size_t n, unsigned char *__restrict out) { uint64_t *ip,start; BITNPACK(in, n, out, 128, 64); }

size_t bitndpack8(  uint8_t  *__restrict in, size_t n, unsigned char *__restrict out) { uint8_t  *ip,start; BITNDPACK(in, n, out, 128,  8, bitd, bitdpacka); }
size_t bitndpack16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; BITNDPACK(in, n, out, 128, 16, bitd, bitdpacka); }
size_t bitndpack32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; BITNDPACK(in, n, out, 128, 32, bitd, bitdpacka); }
size_t bitndpack64( uint64_t *__restrict in, size_t n, unsigned char *__restrict out) { uint64_t *ip,start; BITNDPACK(in, n, out, 128, 64, bitd, bitdpacka); }

size_t bitnd1pack8( uint8_t  *__restrict in, size_t n, unsigned char *__restrict out) { uint8_t  *ip,start; BITNDPACK(in, n, out, 128,  8, bitd1, bitd1packa); }
size_t bitnd1pack16(uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; BITNDPACK(in, n, out, 128, 16, bitd1, bitd1packa); }
size_t bitnd1pack32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; BITNDPACK(in, n, out, 128, 32, bitd1, bitd1packa); }
size_t bitnd1pack64(uint64_t *__restrict in, size_t n, unsigned char *__restrict out) { uint64_t *ip,start; BITNDPACK(in, n, out, 128, 64, bitd1, bitd1packa); }

size_t bitnzpack8(  uint8_t  *__restrict in, size_t n, unsigned char *__restrict out) { uint8_t  *ip,start; BITNDPACK(in, n, out, 128,  8, bitz, bitzpacka); }
size_t bitnzpack16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; BITNDPACK(in, n, out, 128, 16, bitz, bitzpacka); }
size_t bitnzpack32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; BITNDPACK(in, n, out, 128, 32, bitz, bitzpacka); }
size_t bitnzpack64( uint64_t *__restrict in, size_t n, unsigned char *__restrict out) { uint64_t *ip,start; BITNDPACK(in, n, out, 128, 64, bitz, bitzpacka); }

size_t bitnfpack8(  uint8_t  *__restrict in, size_t n, unsigned char *__restrict out) { uint8_t  *ip,start; BITNDPACK(in, n, out, 128,  8, bitf, bitfpacka); }
size_t bitnfpack16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; BITNDPACK(in, n, out, 128, 16, bitf, bitfpacka); }
size_t bitnfpack32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; BITNDPACK(in, n, out, 128, 32, bitf, bitfpacka); }
size_t bitnfpack64( uint64_t *__restrict in, size_t n, unsigned char *__restrict out) { uint64_t *ip,start; BITNDPACK(in, n, out, 128, 64, bitf, bitfpacka); }

#else //--------------------------------------- SIMD ----------------------------------------------------------------------------------------------

#define _BITNPACKV(in, n, out, _csize_, _usize_, _bitpackv_) {\
  unsigned char *op = out; TEMPLATE3(uint, _usize_, _t) _o,_x;\
  for(ip = in; ip != in + (n&~(_csize_-1)); ip += _csize_) {        PREFETCH(ip+512,0);\
                         unsigned _b; _o = TEMPLATE2(bit,_usize_)(ip, _csize_, &_x); _b = TEMPLATE2(bsr,_usize_)(_o); *op++ = _b; op = TEMPLATE2(_bitpackv_, _usize_)(ip, _csize_, op, _b);\
  } if(n&=(_csize_-1)) { unsigned _b; _o = TEMPLATE2(bit,_usize_)(ip, n,       &_x); _b = TEMPLATE2(bsr,_usize_)(_o); *op++ = _b; op = TEMPLATE2(bitpack,    _usize_)(ip, n,       op, _b); }\
  return op - out;\
}

#define _BITNDPACKV(in, n, out, _csize_, _usize_, _bitdv_, _bitpackv_,  _bitd_, _bitpack_) { if(!n) return 0;\
  unsigned char *op = out; TEMPLATE3(uint, _usize_, _t) _o,_x;\
  start = *in++; \
  TEMPLATE2(vbxput, _usize_)(op, start);\
  for(n--,ip = in; ip != in + (n&~(_csize_-1)); ) { PREFETCH(ip+512,0);\
                         unsigned _b; _o = TEMPLATE2(_bitdv_, _usize_)(ip, _csize_, &_x, start); _b = TEMPLATE2(bsr,_usize_)(_o); *op++ = _b; op = TEMPLATE2(_bitpackv_, _usize_)(ip, _csize_, op, start, _b); ip += _csize_; start = ip[-1];\
  } if(n&=(_csize_-1)) { unsigned _b; _o = TEMPLATE2(_bitd_,  _usize_)(ip, n,       &_x, start); _b = TEMPLATE2(bsr,_usize_)(_o); *op++ = _b; op = TEMPLATE2(_bitpack_,  _usize_)(ip, n,       op, start, _b); }\
  return op - out;\
}

  #ifdef __AVX2__
#include <immintrin.h>
#include "bitpack_.h"

#define OPPE(__op)
#define IPPE(__op)

#define PAD8(__x) (((__x)+8-1)/8)
#define OPPE(__op)
#define IPPE(__op)

#define VI32(ip, i, iv, parm)
#define IP32(ip, i, iv) _mm256_loadu_si256(ip++)

unsigned char *bitpack256v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b) { unsigned char *pout = out+PAD8(256*b); BITPACK256V32(in, b, out, 0); return pout; }
#undef VI32
#undef IP32


#define VI32(_ip_, _i_, _iv_, _sv_) _iv_ = _mm256_sub_epi32(_mm256_loadu_si256(_ip_++),sv)
#define IP32(_ip_, i, _iv_)             _iv_
#include "bitpack_.h"
unsigned char *bitfpack256v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned start, unsigned b) { unsigned char *pout = out+PAD8(256*b);
  __m256i v, sv = _mm256_set1_epi32(start);
  BITPACK256V32(in, b, out, sv);
  return pout;
}

#define VI32(_ip_, _i_, _iv_, _sv_) _iv_ = _mm256_sub_epi32(_mm256_loadu_si256(_ip_++),_sv_); _sv_ = _mm256_add_epi32(_sv_,cv);
#define IP32(ip, i, _iv_) _iv_
unsigned char *bitf1pack256v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned start, unsigned b) { unsigned char *pout = out+PAD8(256*b);
  __m256i v, sv = _mm256_set_epi32(start+8,start+7,start+6,start+5,start+4,start+3,start+2,start+1), cv = _mm256_set1_epi32(8);
  BITPACK256V32(in, b, out, sv); return pout;
}

#define VI32(_ip_, _i_, _iv_, _sv_) v = _mm256_loadu_si256(_ip_++); _iv_ = mm256_delta_epi32(v,_sv_); _sv_ = v
#define IP32(ip, i, _iv_) _iv_
#include "bitpack_.h"
unsigned char *bitdpack256v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned start, unsigned b) { unsigned char *pout = out+PAD8(256*b);
  __m256i v,sv = _mm256_set1_epi32(start);
  BITPACK256V32(in, b, out, sv);
  return pout;
}

#define VI32(_ip_, _i_, _iv_, _sv_) v = _mm256_loadu_si256(_ip_++); _iv_ = _mm256_sub_epi32(mm256_delta_epi32(v,_sv_),cv); _sv_ = v
unsigned char *bitd1pack256v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned start, unsigned b) { unsigned char *pout = out+PAD8(256*b);
  __m256i v, sv = _mm256_set1_epi32(start), cv = _mm256_set1_epi32(1);
  BITPACK256V32(in, b, out, sv);
  return pout;
}

#define VI32(_ip_, _i_, _iv_, _sv_) v = _mm256_loadu_si256(_ip_++); _iv_ = mm256_delta_epi32(v,_sv_); _sv_ = v; _iv_ = mm256_zzage_epi32(_iv_)
unsigned char *bitzpack256v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned start, unsigned b) { unsigned char *pout = out+PAD8(256*b);
  __m256i v, sv = _mm256_set1_epi32(start), cv = _mm256_set1_epi32(1);
  BITPACK256V32(in, b, out, sv);
  return pout;
}

size_t bitnpack256v32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip;       _BITNPACKV( in, n, out, 256, 32, bitpack256v); }
size_t bitndpack256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 256, 32, bitd,  bitdpack256v, bitd, bitdpack); }
size_t bitnd1pack256v32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 256, 32, bitd1, bitd1pack256v,bitd1, bitd1pack); }
size_t bitnzpack256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 256, 32, bitz,  bitzpack256v, bitz, bitzpack); }
size_t bitnfpack256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 256, 32, bitf,  bitfpack256v, bitf, bitfpack); }

  #elif defined(__SSE2__) || defined(__ARM_NEON) //----------------------------- SSE ---------------------------------------------------------------
#define OPPE(__op)
#define IPPE(__op)

#define VI16(ip, i, iv, parm)
#define VI32(ip, i, iv, parm)
#define IP16(_ip_, i, iv) _mm_loadu_si128(_ip_++)
#define IP32(_ip_, i, iv) _mm_loadu_si128(_ip_++)
#include "bitpack_.h"
unsigned char *bitpack128v16(unsigned short *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b) { unsigned char *pout = out+PAD8(128*b); BITPACK128V16(in, b, out, 0); return pout; }
unsigned char *bitpack128v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b) { unsigned char *pout = out+PAD8(128*b); BITPACK128V32(in, b, out, 0); return pout; }
unsigned char *bitpack256w32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b) { unsigned char *_out=out; unsigned *_in=in;
BITPACK128V32(in, b, out, 0); in = _in+128; out = _out+PAD8(128*b); BITPACK128V32(in, b, out, 0); return _out+PAD8(256*b); }

#ifdef __ARM_NEON
//#define IP32(_ip_, i, iv)     _mm_or_si128(_mm_shuffle_epi32(    _mm_loadu_si128(_ip_++),_MM_SHUFFLE(3, 1, 2, 0)), _mm_shuffle_epi32(     _mm_loadu_si128(_ip_++),_MM_SHUFFLE(2, 0, 3, 1)) )
#define IP32(_ip_, _i_, _iv_) _mm_or_si128(mm_shuffle_3120_epi32(_mm_loadu_si128(_ip_++)                        ), mm_shuffle_2031_epi32(_mm_loadu_si128(_ip++)                        ) ) // optimized shuffle
#else
#define IP32(_ip_, i, iv)     _mm_or_si128(_mm_shuffle_epi32(    _mm_loadu_si128(_ip_++),_MM_SHUFFLE(2, 0, 3, 1)), _mm_shuffle_epi32(     _mm_loadu_si128(_ip_++),_MM_SHUFFLE(3, 1, 2, 0)) )
#endif
#include "bitpack_.h"
unsigned char *bitpack128v64(uint64_t       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b) {
  if(b<=32) { unsigned char *pout = out+PAD8(128*b); BITPACK128V32(in, b, out, 0); return pout; } else return bitpack64(in,n,out,b);
}

#define VI16(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = mm_delta_epi16(v,_sv_); _sv_ = v
#define VI32(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = mm_delta_epi32(v,_sv_); _sv_ = v
#define IP16(ip, i, _iv_) _iv_
#define IP32(ip, i, _iv_) _iv_
#include "bitpack_.h"
unsigned char *bitdpack128v16(unsigned short *__restrict in, unsigned n, unsigned char *__restrict out, unsigned short start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v,sv = _mm_set1_epi16(start); BITPACK128V16(in, b, out, sv); return pout;
}
unsigned char *bitdpack128v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned       start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v,sv = _mm_set1_epi32(start); BITPACK128V32(in, b, out, sv); return pout;
}

#define VI16(_ip_, _i_, _iv_, _sv_)
#define VI32(_ip_, _i_, _iv_, _sv_)
#define IP16(_ip_, i, _iv_)             _mm_sub_epi16(_mm_loadu_si128(_ip_++),sv)
#define IP32(_ip_, i, _iv_)             _mm_sub_epi32(_mm_loadu_si128(_ip_++),sv)
#include "bitpack_.h"
unsigned char *bitfpack128v16(unsigned short *__restrict in, unsigned n, unsigned char *__restrict out, unsigned short start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set1_epi16(start); BITPACK128V16(in, b, out, sv);  return pout;
}
unsigned char *bitfpack128v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned       start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set1_epi32(start); BITPACK128V32(in, b, out, sv);  return pout;
}

#define VI16(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = _mm_sub_epi16(mm_delta_epi16(v,_sv_),cv); _sv_ = v
#define VI32(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = _mm_sub_epi32(mm_delta_epi32(v,_sv_),cv); _sv_ = v
#define IP16(ip, i, _iv_) _iv_
#define IP32(ip, i, _iv_) _iv_
unsigned char *bitd1pack128v16(unsigned short *__restrict in, unsigned n, unsigned char *__restrict out, unsigned short start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i sv = _mm_set1_epi16(start), cv = _mm_set1_epi16(1), v; BITPACK128V16(in, b, out, sv); return pout;
}
unsigned char *bitd1pack128v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set1_epi32(start), cv = _mm_set1_epi32(1); BITPACK128V32(in, b, out, sv); return pout;
}

#define VI16(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = _mm_sub_epi16(SUBI16x8(v,_sv_),cv); _sv_ = v
#define VI32(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = _mm_sub_epi32(SUBI32x4(v,_sv_),cv); _sv_ = v
#define IP16(ip, i, _iv_) _iv_
#define IP32(ip, i, _iv_) _iv_
unsigned char *bits1pack128v16(unsigned short *__restrict in, unsigned n, unsigned char *__restrict out, unsigned short start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set1_epi16(start), cv = _mm_set1_epi16(8); BITPACK128V16(in, b, out, sv); return pout;
}
unsigned char *bits1pack128v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set1_epi32(start), cv = _mm_set1_epi32(4); BITPACK128V32(in, b, out, sv); return pout;
}

#define VI16(_ip_, _i_, _iv_, _sv_) _iv_ = _mm_sub_epi16(_mm_loadu_si128(_ip_++),_sv_); _sv_ = _mm_add_epi16(_sv_,cv);
#define VI32(_ip_, _i_, _iv_, _sv_) _iv_ = _mm_sub_epi32(_mm_loadu_si128(_ip_++),_sv_); _sv_ = _mm_add_epi32(_sv_,cv);
#define IP16(ip, i, _iv_) _iv_
#define IP32(ip, i, _iv_) _iv_
unsigned char *bitf1pack128v16(unsigned short *__restrict in, unsigned n, unsigned char *__restrict out, unsigned short start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set_epi16(start+8,start+7,start+6,start+5,start+4,start+3,start+2,start+1), cv = _mm_set1_epi16(8); BITPACK128V16(in, b, out, sv); return pout;
}
unsigned char *bitf1pack128v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned       start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set_epi32(                                start+4,start+3,start+2,start+1), cv = _mm_set1_epi32(4); BITPACK128V32(in, b, out, sv); return pout;
}

#define VI16(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = mm_delta_epi16(v,_sv_); _sv_ = v; _iv_ = mm_zzage_epi16(_iv_)
unsigned char *bitzpack128v16(unsigned short *__restrict in, unsigned n, unsigned char *__restrict out, unsigned short start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set1_epi16(start), cv = _mm_set1_epi16(1); BITPACK128V16(in, b, out, sv); return pout;
}
#define VI32(_ip_, _i_, _iv_, _sv_) v = _mm_loadu_si128(_ip_++); _iv_ = mm_delta_epi32(v,_sv_); _sv_ = v; _iv_ = mm_zzage_epi32(_iv_)
unsigned char *bitzpack128v32(unsigned       *__restrict in, unsigned n, unsigned char *__restrict out, unsigned       start, unsigned b) { unsigned char *pout = out+PAD8(128*b);
  __m128i v, sv = _mm_set1_epi32(start), cv = _mm_set1_epi32(1); BITPACK128V32(in, b, out, sv); return pout;
}

size_t bitnpack128v16(  uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip;       _BITNPACKV( in, n, out, 128, 16, bitpack128v); }
size_t bitnpack128v32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip;       _BITNPACKV( in, n, out, 128, 32, bitpack128v); }
size_t bitnpack128v64(  uint64_t *__restrict in, size_t n, unsigned char *__restrict out) { uint64_t *ip;       _BITNPACKV( in, n, out, 128, 64, bitpack128v); }
size_t bitnpack256w32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip;       _BITNPACKV( in, n, out, 256, 32, bitpack256w); }

size_t bitndpack128v16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; _BITNDPACKV(in, n, out, 128, 16, bitd,  bitdpack128v, bitd, bitdpack); }
size_t bitndpack128v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 128, 32, bitd,  bitdpack128v, bitd, bitdpack); }

size_t bitnd1pack128v16(uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; _BITNDPACKV(in, n, out, 128, 16, bitd1, bitd1pack128v, bitd1, bitd1pack); }
size_t bitnd1pack128v32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 128, 32, bitd1, bitd1pack128v, bitd1, bitd1pack); }

size_t bitns1pack128v16(uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; _BITNDPACKV(in, n, out, 128, 16, bits128v, bits1pack128v, bitd1, bitd1pack); }
size_t bitns1pack128v32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 128, 32, bits128v, bits1pack128v, bitd1, bitd1pack); }

size_t bitnzpack128v16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; _BITNDPACKV(in, n, out, 128, 16, bitz,  bitzpack128v, bitz, bitzpack); }
size_t bitnzpack128v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 128, 32, bitz,  bitzpack128v, bitz, bitzpack); }

size_t bitnfpack128v16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out) { uint16_t *ip,start; _BITNDPACKV(in, n, out, 128, 16, bitf,  bitfpack128v, bitf, bitfpack); }
size_t bitnfpack128v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out) { uint32_t *ip,start; _BITNDPACKV(in, n, out, 128, 32, bitf,  bitfpack128v, bitf, bitfpack); }
  #endif // SSE
#endif // Plain

#pragma clang diagnostic pop

#endif
