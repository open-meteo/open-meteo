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
//  "Integer Compression" TurboPFor - Pfor/PforDelta


#ifdef GUARDED

#ifndef USIZE
#pragma warning( disable : 4005)
#pragma warning( disable : 4090)
#pragma warning( disable : 4068)

#define VINT_IN
//#define BITPACK_DAC
//#define TURBOPFOR_DAC
#define BITUTIL_IN
#include "conf.h"
#include "bitutil.h"
#include "vint.h"
#include "bitpack.h"
#include "vp4.h"

#define PAD8(__x) ( (((__x)+8-1)/8) )

#define P4DELTA(a)
#define P4DELTA_(a)
  #if defined(__SSSE3__) || defined(__ARM_NEON)
extern char _shuffle_32[16][16];  // defined in bitunpack.c
extern char _shuffle_16[256][16];
  #endif

  #ifdef __AVX2__
#define VSIZE 256
#define P4DELTA(a)
#define P4DELTA_(a)

#define _P4DEC        _p4dec256v
#define  P4DEC         p4dec256v
#define  P4NDEC        p4ndec256v
#define  P4NDECS       p4dec
#define  BITUNPACK     bitunpack256v
#define  BITUNPACKD    bitunpack256v
#define  _BITUNPACKD  _bitunpack256v
#define USIZE 32
#include "vp4d.c"

#define P4DELTA(a) ,a
#define P4DELTA_(a) a
#define DELTA

#define _P4DEC        _p4ddec256v
#define  P4DEC         p4ddec256v
#define  P4NDEC        p4nddec256v
#define  P4NDECS       p4ddec
#define  BITUNPACKD    bitdunpack256v
#define  _BITUNPACKD  _bitdunpack256v
#define  BITUNDD       bitddec
#include "vp4d.c"

#define _P4DEC        _p4d1dec256v
#define  P4DEC         p4d1dec256v
#define  P4NDEC        p4nd1dec256v
#define  P4NDECS       p4d1dec
#define  BITUNPACKD    bitd1unpack256v
#define  _BITUNPACKD  _bitd1unpack256v
#define  BITUNDD       bitd1dec
#include "vp4d.c"

#define _P4DEC        _p4zdec256v
#define  P4DEC         p4zdec256v
#define  P4NDEC        p4nzdec256v
#define  P4NDECS       p4zdec
#define  BITUNPACKD    bitzunpack256v
#define  _BITUNPACKD  _bitzunpack256v
#define  BITUNDD       bitzdec
#define USIZE 32
#include "vp4d.c"

#undef  BITUNDD
  #elif !defined(SSE2_ON) && !defined(AVX2_ON)

#define _P4DEC      _p4dec
#define  P4DEC       p4dec
#define  P4NDEC      p4ndec
#define  P4NDECS     p4dec
#define  BITUNPACK   bitunpack  // unpack only
#define  BITUNPACKD  bitunpack  // integrated unpack
#define _BITUNPACKD  bitunpack  // integrated pfor

#ifdef TURBOPFOR_DAC
  #define  P4DECX  // direct access no 64 bits
#endif
#define USIZE 8
#include "vp4d.c"
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"

#ifdef TURBOPFOR_DAC
  #undef  P4DECX
#endif
#define USIZE 64
#include "vp4d.c"

#define P4DELTA(a) ,a
#define P4DELTA_(a) a
#define DELTA

#define _P4DEC      _p4ddec         //delta0
#define  P4DEC       p4ddec
#define  P4NDEC      p4nddec
#define  P4NDECS     p4ddec
#define  BITUNPACKD  bitdunpack
#define _BITUNPACKD _bitdunpack
#define  BITUNDD     bitddec
#define USIZE 8
#include "vp4d.c"
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"
#define USIZE 64
#include "vp4d.c"

#define _P4DEC      _p4d1dec        //delta1
#define  P4DEC       p4d1dec
#define  P4NDEC      p4nd1dec
#define  P4NDECS     p4d1dec
#define  BITUNPACKD  bitd1unpack
#define _BITUNPACKD  bitd1unpack
#define  BITUNDD     bitd1dec
#define USIZE 8
#include "vp4d.c"
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"
#define USIZE 64
#include "vp4d.c"

#define _P4DEC      _p4zdec         //zigzag0
#define  P4DEC       p4zdec
#define  P4NDEC      p4nzdec
#define  P4NDECS     p4zdec
#define  BITUNPACKD  bitzunpack
#define _BITUNPACKD _bitzunpack
#define  BITUNDD     bitzdec
#define USIZE 8
#include "vp4d.c"
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"
#define USIZE 64
#include "vp4d.c"

#undef _P4DEC
#undef  P4DEC
#undef  BITUNPACK
#undef  BITUNDD
#undef  P4DELTA
#undef USIZE
#undef DELTA

  #elif defined(__SSSE3__) || defined(__ARM_NEON)
#define VSIZE 128
#define P4DELTA(a)
#define P4DELTA_(a)

#define _P4DEC        _p4dec128v
#define  P4DEC         p4dec128v
#define  P4NDEC        p4ndec128v
#define  P4NDECS       p4dec
#define  BITUNPACK     bitunpack128v
#define  BITUNPACKD    bitunpack128v
#define  _BITUNPACKD  _bitunpack128v
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"
#define USIZE 64
#include "vp4d.c"

#define P4DELTA(a) ,a
#define P4DELTA_(a) a
#define DELTA

#define _P4DEC        _p4ddec128v
#define  P4DEC         p4ddec128v
#define  P4NDEC        p4nddec128v
#define  P4NDECS       p4ddec
#define  BITUNPACKD    bitdunpack128v
#define  _BITUNPACKD  _bitdunpack128v
#define  BITUNDD       bitddec
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"

#define _P4DEC        _p4d1dec128v
#define  P4DEC         p4d1dec128v
#define  P4NDEC        p4nd1dec128v
#define  P4NDECS       p4d1dec
#define  BITUNPACKD    bitd1unpack128v
#define  _BITUNPACKD  _bitd1unpack128v
#define  BITUNDD       bitd1dec
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"

#define _P4DEC        _p4zdec128v
#define  P4DEC         p4zdec128v
#define  P4NDEC        p4nzdec128v
#define  P4NDECS       p4zdec
#define  BITUNPACKD    bitzunpack128v
#define  _BITUNPACKD  _bitzunpack128v
#define  BITUNDD       bitzdec
#define USIZE 16
#include "vp4d.c"
#define USIZE 32
#include "vp4d.c"

#undef  BITUNDD
#undef  P4DELTA
#undef  DELTA

#define  VSIZE 256

#define P4DELTA(a)
#define P4DELTA_(a)
#undef  DELTA

#define _P4DEC        _p4dec256w
#define  P4DEC         p4dec256w
#define  P4NDEC        p4ndec256w
#define  P4NDECS       p4dec
#define  BITUNPACK     bitunpack256w
#define  BITUNPACKD    bitunpack256w
#define  _BITUNPACKD  _bitunpack256w
#include "vp4d.c"
  #endif
#undef  DELTA

#else
#define uint_t TEMPLATE3(uint, USIZE, _t)

#pragma GCC push_options
#pragma GCC optimize ("align-functions=16")

ALWAYS_INLINE unsigned char *TEMPLATE2(_P4DEC, USIZE)(unsigned char *__restrict in, unsigned n, uint_t *__restrict out P4DELTA(uint_t start), unsigned b, unsigned bx ) {
  if(!(b & 0x80)) {
      #if USIZE == 64
    b = (b == 63)?64:b;  // 63,64 are both encoded w. same bitsize 64 (permits using only 6 bits for b)
      #endif
    return TEMPLATE2(BITUNPACKD, USIZE)(in, n, out P4DELTA(start), b);  // bitunpack only
  }
  b &= 0x7f;
    #if VSIZE >= 128      // vertical SIMD bitpacking
      #if USIZE == 64
  if(b+bx <= 32)          // use SIMD when bitsize <= 32 (scalar horizontal bitunpack64 is used when 32 < bitsize <=64 )
      #endif
  { unsigned char *pb = in;
      #if VSIZE == 128
        #if USIZE == 64
    uint32_t ex[P4D_MAX+64];
    in = TEMPLATE2(bitunpack, 32)(in+16, popcnt64(ctou64(in)) + popcnt64(ctou64(in+8)), ex, bx);     // unpack the fixex size part
        #else
    uint_t ex[P4D_MAX+64];
    in = TEMPLATE2(bitunpack, USIZE)(in+16, popcnt64(ctou64(in)) + popcnt64(ctou64(in+8)), ex, bx);
        #endif
      #else
    uint_t ex[P4D_MAX+64];
    in = TEMPLATE2(bitunpack, USIZE)(in+32, popcnt64(ctou64(in)) + popcnt64(ctou64(in+8)) + popcnt64(ctou64(in+16)) + popcnt64(ctou64(in+24)), ex, bx);
      #endif
    return TEMPLATE2(_BITUNPACKD, USIZE)(in, n, out P4DELTA(start), b, ex, pb);  // unpack the exceptions
  }
    #endif
    #if VSIZE < 128 || USIZE == 64     // bitunpack the rest number of elements < 128/256  or when 32 < bitsize <=64 is used
  { uint_t ex[P4D_MAX+64];
    unsigned long long bb[P4D_MAX/64];
    unsigned num=0,i,p4dn = (n+63)/64;
    for(i = 0; i < n/64; i++) { bb[i] = ctou64(in+i*8); num += popcnt64(bb[i]); }
    if(n & 0x3f) { bb[i] = ctou64(in+i*8) & ((1ull<<(n&0x3f))-1); num += popcnt64(bb[i]); }
    in = TEMPLATE2(bitunpack, USIZE)(in+PAD8(n), num, ex, bx);
    in = TEMPLATE2(BITUNPACK, USIZE)(in, n, out, b);
      #if 0 //defined(__AVX2__)
    { uint_t *op,*pex = ex;
      for(i = 0; i < p4dn; i++) {
        for(op = out;    bb[i]; bb[i] >>= 8,op += 8) { unsigned m = (unsigned char)bb[i], mc=popcnt32(m), s = pex[mc]; pex[mc]=0;
          _mm256_storeu_si256((__m256i *)op, _mm256_add_epi32(_mm256_loadu_si256((const __m256i*)op), mm256_maskz_expand_epi32(m,_mm256_slli_epi32(_mm256_load_si256((const __m256i*)pex), b)))); pex += mc; *pex=s;
        } //out += 64;
      }
    }
      #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && USIZE == 32
    { uint_t *_op = out,*op,*pex = ex;
      for(i = 0; i < p4dn; i++) {
        for(op=_op;  bb[i]; bb[i] >>= 4,op+=4) { const unsigned m = bb[i]&0xf;
          _mm_storeu_si128((__m128i *)op, _mm_add_epi32(_mm_loadu_si128((__m128i*)op), _mm_shuffle_epi8(_mm_slli_epi32(_mm_loadu_si128((__m128i*)pex), b), _mm_load_si128((__m128i*)_shuffle_32[m]) ) )); pex += popcnt32(m);
        } _op+=64;
      }
    }
      #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && USIZE == 16
    { uint_t *_op = out, *op, *pex = ex;
      for(i = 0; i < p4dn; i++) {
        for(op = _op;  bb[i]; bb[i] >>= 8,op += 8) { const unsigned char m = bb[i];
          _mm_storeu_si128((__m128i *)op, _mm_add_epi16(_mm_loadu_si128((__m128i*)op), _mm_shuffle_epi8(_mm_slli_epi16(_mm_loadu_si128((__m128i*)pex), b), _mm_load_si128((__m128i*)_shuffle_16[m]) ) )); pex += popcnt32(m);
        } _op += 64;
      }
    }
      #else
    { unsigned k = 0;
      uint_t *op,*p;
      for(op=out,i = 0; i < p4dn; i++,op += 64) { unsigned long long u = bb[i];
          #if 1 // faster
        while(u) op[ctz64(u)] += ex[k++]<<b, u &= u-1;
          #else
         p = op;
        #define OP(_i_) p[_i_] += ex[k++]<<b;
        while(u) {
          unsigned x = ctz64(u); u >>= x; p+=x;
          switch(u&0xf) {
            case  0:                             break; //0000
            case  1:                      OP(0); break; //0001
            case  2:               OP(1);        break; //0010
            case  3:               OP(1); OP(0); break; //0011
            case  4:        OP(2);               break; //0100
            case  5:        OP(2);        OP(0); break; //0101
            case  6:        OP(2); OP(1);        break; //0110
            case  7:        OP(2); OP(1); OP(0); break; //0111
            case  8: OP(3);                      break; //1000
            case  9: OP(3);               OP(0); break; //1001
            case 10: OP(3);        OP(1);        break; //1010
            case 11: OP(3);        OP(1); OP(0); break; //1011
            case 12: OP(3); OP(2);               break; //1100
            case 13: OP(3); OP(2);        OP(0); break; //1101
            case 14: OP(3); OP(2); OP(1);        break; //1110
            case 15: OP(3); OP(2); OP(1); OP(0); break; //1111
          }
          u >>= 4;
          p += 4;
        }
        #endif
      }
    }
      #endif
  }
      #ifdef BITUNDD
  TEMPLATE2(BITUNDD, USIZE)(out, n, start);
      #endif
  return in;
    #endif
}

unsigned char *TEMPLATE2(P4DEC, USIZE)(unsigned char *__restrict in, unsigned n, uint_t *__restrict out P4DELTA(uint_t start) ) {
  unsigned b, bx = 0, i;
  if(!n) return in;
  b = *in++;
  if((b & 0xc0) == 0xc0) {  // all items are equal
    b &= 0x3f;
      #if USIZE == 64
    b = b == 63?64:b; // use 64 instead of 63 (permis using only 6 bits to store b)
      #endif
    uint_t u = TEMPLATE2(ctou, USIZE)(in); if(b < USIZE) u = TEMPLATE2(BZHI, USIZE)(u,b);
    for(i=0; i < n; i++) out[i] = u;
      #ifdef BITUNDD
    TEMPLATE2(BITUNDD, USIZE)(out, n, start);
      #endif
    return in+(b+7)/8;
  } else if(likely(!(b & 0x40))) { // PFOR
    if(b & 0x80)
      bx = *in++;
    return TEMPLATE2(_P4DEC, USIZE)(in, n, out P4DELTA(start), b, bx);
  }
  else {  // Variable byte
#if USIZE > 8
    uint_t ex[P4D_MAX+64],*pex=ex;
    b  &= 0x3f;
    bx = *in++;                                                                             /*if(b && *in++ == 0x80) { uint_t u = TEMPLATE2(ctou, USIZE)(in); if(b < USIZE) u = TEMPLATE2(BZHI, USIZE)(u,b); int i; for(i = 0; i < n; i++) out[i] = u; in+=(b+7)/8;  } else*/
    in = TEMPLATE2(BITUNPACK, USIZE)(in, n, out, b);
    in = TEMPLATE2(vbdec,     USIZE)(in, bx, ex);
    #define ST(j) out[in[i+j]] |= ex[i+j] << b
    //#define ST(j) out[*ip++] |= (*pex++) << b;
    //unsigned char *ip;for(ip = in; ip != in + (bx & ~3); )
    for(i  = 0;  i != (bx & ~7); i+=8)
    { ST(0);ST(1);ST(2);ST(3); ST(4);ST(5);ST(6);ST(7); }
    //for(;ip != in+bx; ) ST(0);
    for(;i != bx; i++) ST(0);
    in += bx;
      #ifdef BITUNDD
    TEMPLATE2(BITUNDD, USIZE)(out, n, start);
      #endif
    #undef ST
#endif // USIZE > 8
    return in;
  }
}

#ifdef VSIZE
  #define CSIZE VSIZE
#else
  #define CSIZE 128
#endif

size_t TEMPLATE2(P4NDEC, USIZE)(unsigned char *__restrict in, size_t n, uint_t *__restrict out) {
  unsigned char *ip = in;
  uint_t        *op;
  if(!n) return 0;
  {
    #ifdef DELTA
  uint_t start;
  TEMPLATE2(vbxget, USIZE)(ip, start);
  *out++ = start;
  --n;
    #endif
  for(op = out; op != out+(n&~(CSIZE-1)); op += CSIZE) {
    unsigned b = *ip++, bx = 0, i;                                           PREFETCH(ip+512,0);//ip = TEMPLATE2(P4DEC, USIZE)(ip, CSIZE, op P4DELTA(start));

    if((b & 0xc0) == 0xc0) {
      b &= 0x3f;
        #if USIZE == 64
      b = b == 63?64:b;
        #endif
      uint_t u = TEMPLATE2(ctou, USIZE)(ip); if(b < USIZE) u = TEMPLATE2(BZHI, USIZE)(u,b);
      int i; for(i=0; i < CSIZE; i++) op[i] = u;
        #ifdef BITUNDD
      TEMPLATE2(BITUNDD, USIZE)(op, CSIZE, start);
        #endif
      ip += (b+7)/8;
    } else if(likely(!(b & 0x40))) {
      if(b & 0x80)
        bx = *ip++;
      ip = TEMPLATE2(_P4DEC, USIZE)(ip, CSIZE, op P4DELTA(start), b, bx);
    }
      #if USIZE > 8
    else {
      uint_t ex[P4D_MAX+64];
      b  &= 0x3f;
      bx = *ip++;                                                           //f(*ip++ == 0x80 && b) { uint_t u = TEMPLATE2(ctou, USIZE)(ip); ip+=(b+7)/8; if(b < USIZE) u = TEMPLATE2(BZHI, USIZE)(u,b);  int i; for(i=0; i < CSIZE; i++) op[i] = u; } else
      ip = TEMPLATE2(BITUNPACK, USIZE)(ip, CSIZE, op, b);
      ip = TEMPLATE2(vbdec,     USIZE)(ip, bx, ex);
      for(i = 0; i != (bx & ~7); i += 8) {
        op[ip[i  ]] |= ex[i  ] << b;
        op[ip[i+1]] |= ex[i+1] << b;
        op[ip[i+2]] |= ex[i+2] << b;
        op[ip[i+3]] |= ex[i+3] << b;
        op[ip[i+4]] |= ex[i+4] << b;
        op[ip[i+5]] |= ex[i+5] << b;
        op[ip[i+6]] |= ex[i+6] << b;
        op[ip[i+7]] |= ex[i+7] << b;
      }
      for(;i != bx; i++)
        op[ip[i]] |= ex[i] << b;
      ip += bx;
        #ifdef BITUNDD
      TEMPLATE2(BITUNDD, USIZE)(op, CSIZE, start);
        #endif
    }
      #endif
    P4DELTA_(start = op[CSIZE-1]);
  }
  return TEMPLATE2(P4NDECS, USIZE)(ip, n&(CSIZE-1), op P4DELTA(start)) - in;
  }
}

    #ifdef P4DECX
unsigned char *TEMPLATE2(p4decx, USIZE)(unsigned char *in, unsigned n, uint_t *__restrict out) {
  unsigned b,i;
  struct p4 p4;

  p4ini(&p4, &in, n, &b);

  if(unlikely(p4.isx)) {
    #define ITX(k) out[i+k] = TEMPLATE2(p4getx, USIZE)(&p4, in, i+k, b);
    for(i = 0; i != n&~3; i += 4) { ITX(0); ITX(1); ITX(2); ITX(3); }
    for(     ; i != n;    i++   )   ITX(0);
  } else {
    #define ITY(k) out[i+k] = TEMPLATE2(bitgetx, USIZE)(in, i+k, b);
    for(i = 0; i != n&~3; i += 4) { ITY(0); ITY(1); ITY(2); ITY(3); }
    for(     ; i != n; i++) ITY(0);
  }
  return in + PAD8(n*b);
}

unsigned char *TEMPLATE2(p4f1decx, USIZE)(unsigned char *in, unsigned n, uint_t *__restrict out, uint_t start) {
  unsigned b,i;
  struct p4 p4;

  p4ini(&p4, &in, n, &b);
  if(unlikely(p4.isx)) {
    #define ITX(k) out[i+k] = TEMPLATE2(p4getx, USIZE)(&p4, in, (i+k), b)+start+i+k+1;
    for(i = 0; i != n&~3; i+=4) { ITX(0); ITX(1); ITX(2); ITX(3); }
    for(     ; i != n; i++) ITX(0);
  } else {
    #define ITY(k) out[i+k] = TEMPLATE2(bitgetx, USIZE)(in, (i+k), b)+start+i+k+1;
    for(i = 0; i != n&~3; i += 4) { ITY(0); ITY(1); ITY(2); ITY(3); }
    for(     ; i != n; i++) ITY(0);
  }
  return in + PAD8(n*b);
}

unsigned char *TEMPLATE2(p4fdecx, USIZE)(unsigned char *in, unsigned n, uint_t *__restrict out, uint_t start) {
  unsigned b,i;
  struct p4 p4;
  p4ini(&p4, &in, n, &b);

  if(unlikely(p4.isx)) {
    #define ITX(k) out[i+k] = TEMPLATE2(p4getx, USIZE)(&p4, in, i+k, b)+start;
    for(i = 0; i != n&~3; i+=4) { ITX(0); ITX(1); ITX(2); ITX(3); }
    for(     ; i != n; i++) ITX(0);
  } else {
    #define ITY(k) out[i+k] = TEMPLATE2(bitgetx, USIZE)(in, (i+k), b)+start;
    for(i = 0; i != n&~3; i+=4) { ITY(0); ITY(1); ITY(2); ITY(3); }
    for(     ; i != n; i++) ITY(0);
  }
  return in + PAD8(n*b);
}
    #endif
#endif

#endif
