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
//    "Floating Point + Integer Compression (All integer compression functions can be used for float/double and vice versa)"
  #ifndef USIZE
#pragma warning( disable : 4005)
#pragma warning( disable : 4090)
#pragma warning( disable : 4068)

#define BITUTIL_IN
#include "conf.h"
#include "vp4.h"
#include "bitutil.h"
#include "fp.h"
#include <string.h>

//---------------------- template generation --------------------------------------------
#define VSIZE 128

#define P4ENC  p4enc
#define P4DEC  p4dec
#define P4ENCV p4enc
#define P4DECV p4dec

#define NL 18
#define N4 17 // must be > 16

#define N_0 3
#define N_1 4

#define N2  3
#define N3  5
#define USIZE 8
#include "fp.c"

#define P4ENCV p4enc128v
#define P4DECV p4dec128v

#define N_0 3
#define N_1 5

#define N2   6
#define N3  12
#define USIZE 16
#include "fp.c"

#define N_0 4
#define N_1 6

#define N2  6 // for seconds time series
#define N3 10
#define USIZE 32
#include "fp.c"

#define N_1 7
#define N2  6    // for seconds/milliseconds,... time series
#define N3 12
#define N4 20    // must be > 16
#define USIZE 64
#include "fp.c"

  #else //-------------------------------------- Template functions ------------------------------------------------------------

#pragma message("AAAAAAAAAAAAAAAAAAAA!")

#define XORENC( _u_, _pu_, _usize_) ((_u_)^(_pu_))  // xor predictor
#define XORDEC( _u_, _pu_, _usize_) ((_u_)^(_pu_))
#define ZZAGENC(_u_, _pu_, _usize_)  TEMPLATE2(zigzagenc,_usize_)((_u_)-(_pu_)) //zigzag predictor
#define ZZAGDEC(_u_, _pu_, _usize_) (TEMPLATE2(zigzagdec,_usize_)(_u_)+(_pu_))

#define uint_t TEMPLATE3(uint, USIZE, _t)
#define int_t  TEMPLATE3(int,  USIZE, _t)

//-------- TurboPFor Zigzag of zigzag for unsorted/sorted integer/floating point array ---------------------------------------
size_t TEMPLATE2(p4nzzenc128v,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t        _p[VSIZE+32], *ip, *p, pd = 0;
  unsigned char *op = out;

  #define FE(i,_usize_) { TEMPLATE3(uint, USIZE, _t) u = ip[i]; start = u-start; p[i] = ZZAGENC(start,pd,_usize_); pd = start; start = u; }
  for(ip = in; ip != in + (n&~(VSIZE-1)); ) {
    for(p = _p; p != &_p[VSIZE]; p+=4,ip+=4) { FE(0,USIZE); FE(1,USIZE); FE(2,USIZE); FE(3,USIZE); }
    op = TEMPLATE2(P4ENCV,USIZE)(_p, VSIZE, op);                                                    PREFETCH(ip+512,0);
  }
  if(n = (in+n)-ip) {
    for(p = _p; p != &_p[n]; p++,ip++) FE(0,USIZE);
    op = TEMPLATE2(P4ENC,USIZE)(_p, n, op);
  }
  return op - out;
}

size_t TEMPLATE2(p4nzzdec128v,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) {
  uint_t        _p[VSIZE+32],*p, *op, pd=0;
  unsigned char *ip = in;

  #define FD(i,_usize_) { TEMPLATE3(uint, USIZE, _t) u = ZZAGDEC(p[i],start+pd,_usize_); op[i] = u; pd = u - start; start = u; }
  for(op = out; op != out+(n&~(VSIZE-1)); ) {                           PREFETCH(ip+512,0);
    for(ip = TEMPLATE2(P4DECV,USIZE)(ip, VSIZE, _p), p = _p; p != &_p[VSIZE]; p+=4,op+=4) { FD(0,USIZE); FD(1,USIZE); FD(2,USIZE); FD(3,USIZE); }
  }
  if(n = (out+n) - op)
    for(ip = TEMPLATE2(P4DEC,USIZE)(ip, n, _p), p = _p; p != &_p[n]; p++,op++) FD(0,USIZE);
  return ip - in;
}

/*---------------- TurboFloat XOR: last value Predictor with TurboPFor ---------------------------------------------------------
 Compress significantly (115% - 160%) better than Facebook's Gorilla algorithm for values
 BEST results are obtained with LOSSY COMPRESSION (using fppad32/fppad64 in bitutil.c)
 1: XOR value with previous value. We have now leading (for common sign/exponent bits) + mantissa trailing zero bits
 2: Eliminate the common block leading zeros of sign/exponent by shifting all values in the block to left
 3: reverse values to bring the mantissa trailing zero bits to left for better compression with TurboPFor
*/
size_t TEMPLATE2(fpxenc,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t         _p[VSIZE+32], *ip, *p;
  unsigned char *op = out;
    #if defined(__AVX2__) && USIZE >= 32
  #define _mm256_set1_epi64(a) _mm256_set1_epi64x(a)
  __m256i sv = TEMPLATE2(_mm256_set1_epi, USIZE)(start);
    #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && (USIZE == 16 || USIZE == 32)
  #define _mm_set1_epi64(a) _mm_set1_epi64x(a)
  __m128i sv = TEMPLATE2(_mm_set1_epi, USIZE)(start);
    #endif

  #define FE(i,_usize_) { TEMPLATE3(uint, _usize_, _t) u = ip[i]; p[i] = XORENC(u, start,_usize_); b |= p[i]; start = u; }
  for(ip = in; ip != in + (n&~(VSIZE-1)); ) { uint_t b = 0;
      #if defined(__AVX2__) && USIZE >= 32
    __m256i bv = _mm256_setzero_si256();
    for(p = _p; p != &_p[VSIZE]; p+=64/(USIZE/8),ip+=64/(USIZE/8)) {
      __m256i v0 = _mm256_loadu_si256((__m256i *) ip);
      __m256i v1 = _mm256_loadu_si256((__m256i *)(ip+32/(USIZE/8)));
              sv = TEMPLATE2(mm256_xore_epi, USIZE)(v0,sv); bv = _mm256_or_si256(bv, sv); _mm256_storeu_si256((__m256i *) p,               sv); sv = v0;
              sv = TEMPLATE2(mm256_xore_epi, USIZE)(v1,sv); bv = _mm256_or_si256(bv, sv); _mm256_storeu_si256((__m256i *)(p+32/(USIZE/8)), sv); sv = v1;
    }
    start = (uint_t)TEMPLATE2(_mm256_extract_epi,USIZE)(sv, 256/USIZE-1);
    b     = TEMPLATE2(mm256_hor_epi, USIZE)(bv);
      #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && (USIZE == 16 || USIZE == 32)
    __m128i bv = _mm_setzero_si128();
    for(p = _p; p != &_p[VSIZE]; p+=32/(USIZE/8),ip+=32/(USIZE/8)) {
      __m128i v0 = _mm_loadu_si128((__m128i *) ip);
      __m128i v1 = _mm_loadu_si128((__m128i *)(ip+16/(USIZE/8)));
              sv = TEMPLATE2(mm_xore_epi, USIZE)(v0,sv);    bv = _mm_or_si128(bv, sv);        _mm_storeu_si128((__m128i *) p,               sv); sv = v0;
              sv = TEMPLATE2(mm_xore_epi, USIZE)(v1,sv);    bv = _mm_or_si128(bv, sv);        _mm_storeu_si128((__m128i *)(p+16/(USIZE/8)), sv); sv = v1;
    }
    start = (uint_t)TEMPLATE2(mm_cvtsi128_si,USIZE)(_mm_srli_si128(sv,16-USIZE/8));
    b     = TEMPLATE2(mm_hor_epi, USIZE)(bv);
      #else
    for(p = _p; p != &_p[VSIZE]; p+=4,ip+=4) { FE(0,USIZE); FE(1,USIZE); FE(2,USIZE); FE(3,USIZE); }
      #endif
    *op++ = b = TEMPLATE2(clz,USIZE)(b);
    #define TR(i,_usize_) p[i] = TEMPLATE2(rbit,_usize_)(p[i]<<b)
      #if defined(__AVX2__) && USIZE >= 32
    for(p = _p; p != &_p[VSIZE]; p+=64/(USIZE/8)) {
      __m256i v0 = _mm256_loadu_si256((__m256i *)p);
      __m256i v1 = _mm256_loadu_si256((__m256i *)(p+32/(USIZE/8)));
              v0 = TEMPLATE2(_mm256_slli_epi, USIZE)(v0,b);
              v1 = TEMPLATE2(_mm256_slli_epi, USIZE)(v1,b);
              v0 = TEMPLATE2( mm256_rbit_epi, USIZE)(v0);
              v1 = TEMPLATE2( mm256_rbit_epi, USIZE)(v1);
                   _mm256_storeu_si256((__m256i *) p, v0);
                   _mm256_storeu_si256((__m256i *)(p+32/(USIZE/8)), v1);
    }
      #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && (USIZE == 16 || USIZE == 32)
    for(p = _p; p != &_p[VSIZE]; p+=32/(USIZE/8)) {
      __m128i v0 = _mm_loadu_si128((__m128i *) p);
      __m128i v1 = _mm_loadu_si128((__m128i *)(p+16/(USIZE/8)));
              v0 = TEMPLATE2(_mm_slli_epi, USIZE)(v0,b);
              v0 = TEMPLATE2( mm_rbit_epi, USIZE)(v0);
              v1 = TEMPLATE2(_mm_slli_epi, USIZE)(v1,b);
              v1 = TEMPLATE2( mm_rbit_epi, USIZE)(v1);
      _mm_storeu_si128((__m128i *) p,               v0);
      _mm_storeu_si128((__m128i *)(p+16/(USIZE/8)), v1);
    }
      #else
    for(p = _p; p != &_p[VSIZE]; p+=4) { TR(0,USIZE); TR(1,USIZE); TR(2,USIZE); TR(3,USIZE); }
      #endif
    op = TEMPLATE2(P4ENCV,USIZE)(_p, VSIZE, op);                                                    PREFETCH(ip+512,0);
  }
  if(n = (in+n)-ip) { uint_t b = 0;
    for(p = _p; p != &_p[n]; p++,ip++) FE(0,USIZE);
    b = TEMPLATE2(clz,USIZE)(b);
    *op++ = b;
    for(p = _p; p != &_p[n]; p++) TR(0,USIZE);
    op = TEMPLATE2(P4ENC,USIZE)(_p, n, op);
  }
  return op - out;
}

size_t TEMPLATE2(fpxdec,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) {
  uint_t        *op, _p[VSIZE+32],*p;
  unsigned char *ip = in;
    #if defined(__AVX2__) && USIZE >= 32
  #define _mm256_set1_epi64(a) _mm256_set1_epi64x(a)
  __m256i sv = TEMPLATE2(_mm256_set1_epi, USIZE)(start);
    #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && (USIZE == 16 || USIZE == 32)
  #define _mm_set1_epi64(a) _mm_set1_epi64x(a)
  __m128i sv = TEMPLATE2(_mm_set1_epi, USIZE)(start);
    #endif
  #define FD(i,_usize_) { TEMPLATE3(uint, USIZE, _t) u = p[i]; u = TEMPLATE2(rbit,_usize_)(u)>>b; u = XORDEC(u, start,_usize_); op[i] = start = u; }
  for(op = out; op != out+(n&~(VSIZE-1)); ) {                           PREFETCH(ip+512,0);
    unsigned b = *ip++; ip = TEMPLATE2(P4DECV,USIZE)(ip, VSIZE, _p);

      #if defined(__AVX2__) && USIZE >= 32
    for(p = _p; p != &_p[VSIZE]; p+=64/(USIZE/8),op+=64/(USIZE/8)) {
      __m256i v0 = _mm256_loadu_si256((__m256i *)p);
      __m256i v1 = _mm256_loadu_si256((__m256i *)(p+32/(USIZE/8)));
              v0 = TEMPLATE2( mm256_rbit_epi, USIZE)(v0);
              v1 = TEMPLATE2( mm256_rbit_epi, USIZE)(v1);
              v0 = TEMPLATE2(_mm256_srli_epi, USIZE)(v0,b);
              v1 = TEMPLATE2(_mm256_srli_epi, USIZE)(v1,b);
              v0 = TEMPLATE2( mm256_xord_epi, USIZE)(v0,sv);
              sv = TEMPLATE2( mm256_xord_epi, USIZE)(v1,v0);
                   _mm256_storeu_si256((__m256i *)op, v0);
                   _mm256_storeu_si256((__m256i *)(op+32/(USIZE/8)), sv);
    }
    start = (uint_t)TEMPLATE2(_mm256_extract_epi,USIZE)(sv, 256/USIZE-1);
      #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && (USIZE == 16 || USIZE == 32)
    for(p = _p; p != &_p[VSIZE]; p+=32/(USIZE/8),op+=32/(USIZE/8)) {
      __m128i v0 = _mm_loadu_si128((__m128i *)p);
      __m128i v1 = _mm_loadu_si128((__m128i *)(p+16/(USIZE/8)));
              v0 = TEMPLATE2( mm_rbit_epi, USIZE)(v0);
              v0 = TEMPLATE2(_mm_srli_epi, USIZE)(v0,b);
              v0 = TEMPLATE2( mm_xord_epi, USIZE)(v0,sv);
              v1 = TEMPLATE2( mm_rbit_epi, USIZE)(v1);
              v1 = TEMPLATE2(_mm_srli_epi, USIZE)(v1,b);
              sv = TEMPLATE2( mm_xord_epi, USIZE)(v1,v0);
      _mm_storeu_si128((__m128i *) op,               v0);
      _mm_storeu_si128((__m128i *)(op+16/(USIZE/8)), sv);
    }
    start = (uint_t)TEMPLATE2(mm_cvtsi128_si,USIZE)(_mm_srli_si128(sv,16-USIZE/8));
      #else
    for(p = _p; p != &_p[VSIZE]; p+=4,op+=4) { FD(0,USIZE); FD(1,USIZE); FD(2,USIZE); FD(3,USIZE); }
      #endif
  }
  if(n = (out+n) - op) {
    uint_t b = *ip++;
    for(ip = TEMPLATE2(P4DEC,USIZE)(ip, n, _p), p = _p; p < &_p[n]; p++,op++) FD(0,USIZE);
  }
  return ip - in;
}

//-------- TurboFloat FCM: Finite Context Method Predictor ---------------------------------------------------------------
#define HBITS 13 //15
#define HASH64(_h_,_u_) (((_h_)<<5 ^ (_u_)>>50) & ((1u<<HBITS)-1))
#define HASH32(_h_,_u_) (((_h_)<<4 ^ (_u_)>>23) & ((1u<<HBITS)-1))
#define HASH16(_h_,_u_) (((_h_)<<3 ^ (_u_)>>12) & ((1u<<HBITS)-1))
#define HASH8( _h_,_u_) (((_h_)<<2 ^ (_u_)>> 5) & ((1u<<HBITS)-1))

size_t TEMPLATE2(fpfcmenc,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t        htab[1<<HBITS] = {0}, _p[VSIZE+32], *ip, h = 0, *p;
  unsigned char *op = out;

    #if defined(__AVX2__) && USIZE >= 32
  #define _mm256_set1_epi64(a) _mm256_set1_epi64x(a)
  __m256i sv = TEMPLATE2(_mm256_set1_epi, USIZE)(start);
    #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && (USIZE == 16 || USIZE == 32)
  #define _mm_set1_epi64(a) _mm_set1_epi64x(a)
  __m128i sv = TEMPLATE2(_mm_set1_epi, USIZE)(start);
    #endif

  for(ip = in; ip != in + (n&~(VSIZE-1)); ) { uint_t b = 0;
    #define FE(i,_usize_) { TEMPLATE3(uint, _usize_, _t) u = ip[i]; p[i] = XORENC(u, htab[h],_usize_); b |= p[i]; htab[h] = u; h = TEMPLATE2(HASH,_usize_)(h,u); }
    for(p = _p; p != &_p[VSIZE]; p+=4,ip+=4) { FE(0,USIZE); FE(1,USIZE); FE(2,USIZE); FE(3,USIZE); }
    *op++ = b = TEMPLATE2(clz,USIZE)(b);
      #if defined(__AVX2__) && USIZE >= 32
    for(p = _p; p != &_p[VSIZE]; p+=64/(USIZE/8)) {
      __m256i v0 = _mm256_loadu_si256((__m256i *)p);
      __m256i v1 = _mm256_loadu_si256((__m256i *)(p+32/(USIZE/8)));
              v0 = TEMPLATE2(_mm256_slli_epi, USIZE)(v0,b);
              v1 = TEMPLATE2(_mm256_slli_epi, USIZE)(v1,b);
              v0 = TEMPLATE2( mm256_rbit_epi, USIZE)(v0);
              v1 = TEMPLATE2( mm256_rbit_epi, USIZE)(v1);
                   _mm256_storeu_si256((__m256i *) p, v0);
                   _mm256_storeu_si256((__m256i *)(p+32/(USIZE/8)), v1);
    }
      #elif (defined(__SSSE3__) || defined(__ARM_NEON)) && (USIZE == 16 || USIZE == 32)
    for(p = _p; p != &_p[VSIZE]; p+=32/(USIZE/8)) {
      __m128i v0 = _mm_loadu_si128((__m128i *) p);
      __m128i v1 = _mm_loadu_si128((__m128i *)(p+16/(USIZE/8)));
              v0 = TEMPLATE2(_mm_slli_epi, USIZE)(v0,b);
              v0 = TEMPLATE2( mm_rbit_epi, USIZE)(v0);
              v1 = TEMPLATE2(_mm_slli_epi, USIZE)(v1,b);
              v1 = TEMPLATE2( mm_rbit_epi, USIZE)(v1);
      _mm_storeu_si128((__m128i *) p,               v0);
      _mm_storeu_si128((__m128i *)(p+16/(USIZE/8)), v1);
    }
      #else
    #define TR(i,_usize_) p[i] = TEMPLATE2(rbit,_usize_)(p[i]<<b)
    for(p = _p; p != &_p[VSIZE]; p+=4) { TR(0,USIZE); TR(1,USIZE); TR(2,USIZE); TR(3,USIZE); }
      #endif
    op = TEMPLATE2(P4ENCV,USIZE)(_p, VSIZE, op);                                                    PREFETCH(ip+512,0);
  }
  if(n = (in+n)-ip) { uint_t b = 0;
    for(p = _p; p != &_p[n]; p++,ip++) FE(0,USIZE);
    b = TEMPLATE2(clz,USIZE)(b);
    *op++ = b;
    for(p = _p; p != &_p[n]; p++) TR(0,USIZE);
    op = TEMPLATE2(P4ENC,USIZE)(_p, n, op);
  }
  return op - out;
}

size_t TEMPLATE2(fpfcmdec,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) {
  uint_t *op, htab[1<<HBITS] = {0}, h = 0, _p[VSIZE+32],*p;
  unsigned char *ip = in;

  #define FD(i,_usize_) { TEMPLATE3(uint, _usize_, _t) u = p[i]; u = TEMPLATE2(rbit,_usize_)(u)>>b;\
    u = XORDEC(u, htab[h], _usize_); op[i] = u; htab[h] = u; h = TEMPLATE2(HASH,_usize_)(h,u);\
  }
  for(op = (uint_t*)out; op != out+(n&~(VSIZE-1)); ) {                          PREFETCH(ip+512,0);
     unsigned b = *ip++; ip = TEMPLATE2(P4DECV,USIZE)(ip, VSIZE, _p);
    for(p = _p; p != &_p[VSIZE]; p+=4,op+=4) { FD(0,USIZE); FD(1,USIZE); FD(2,USIZE); FD(3,USIZE); }
  }
  if(n = ((uint_t *)out+n) - op) {
    unsigned b = *ip++; ip = TEMPLATE2(P4DEC,USIZE)(ip, n, _p);
    for(p = _p; p != &_p[n]; p++,op++) FD(0,USIZE);
  }
  return ip - in;
}

//-------- TurboFloat DFCM: Differential Finite Context Method Predictor ----------------------------------------------------------
size_t TEMPLATE2(fpdfcmenc,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t *ip, _p[VSIZE+32], h = 0, *p, htab[1<<HBITS] = {0};
  unsigned char *op = out;

  #define FE(i,_usize_) { TEMPLATE3(uint, _usize_, _t) u = ip[i]; p[i] = XORENC(u, (htab[h]+start),_usize_); b |= p[i]; \
    htab[h] = start = u - start; h = TEMPLATE2(HASH,_usize_)(h,start); start = u;\
  }
  for(ip = in; ip != in + (n&~(VSIZE-1)); ) { uint_t b;
    for(p = _p; p != &_p[VSIZE]; p+=4,ip+=4) { FE(0,USIZE); FE(1,USIZE); FE(2,USIZE); FE(3,USIZE); }
    #define TR(i,_usize_) p[i] = TEMPLATE2(rbit,_usize_)(p[i]<<b)
    b = TEMPLATE2(clz,USIZE)(b);
    for(p = _p; p != &_p[VSIZE]; p+=4) { TR(0,USIZE); TR(1,USIZE); TR(2,USIZE); TR(3,USIZE); }
    *op++ = b; op = TEMPLATE2(P4ENCV,USIZE)(_p, VSIZE, op);                                                     PREFETCH(ip+512,0);
  }
  if(n = (in+n)-ip) { uint_t b;
    for(p = _p; p != &_p[n]; p++,ip++) FE(0,USIZE);
    b = TEMPLATE2(clz,USIZE)(b);
    for(p = _p; p != &_p[n]; p++) TR(0,USIZE);
    *op++ = b; op = TEMPLATE2(P4ENC,USIZE)(_p, n, op);
  }
  return op - out;
}

size_t TEMPLATE2(fpdfcmdec,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) {
  uint_t        _p[VSIZE+32], *op, h = 0, *p, htab[1<<HBITS] = {0};
  unsigned char *ip = in;

  #define FD(i,_usize_) { TEMPLATE3(uint, _usize_, _t) u = TEMPLATE2(rbit,_usize_)(p[i])>>b; u = XORDEC(u, (htab[h]+start),_usize_); \
    op[i] = u; htab[h] = start = u-start; h = TEMPLATE2(HASH,_usize_)(h,start); start = u;\
  }
  for(op = (uint_t*)out; op != out+(n&~(VSIZE-1)); ) {                                          PREFETCH(ip+512,0);
    uint_t b = *ip++;
    ip = TEMPLATE2(P4DECV,USIZE)(ip, VSIZE, _p);
    for(p = _p; p != &_p[VSIZE]; p+=4,op+=4) { FD(0,USIZE); FD(1,USIZE); FD(2,USIZE); FD(3,USIZE); }
  }
  if(n = ((uint_t *)out+n) - op) {
    uint_t b = *ip++;
    ip = TEMPLATE2(P4DEC,USIZE)(ip, n, _p);
    for(p = _p; p != &_p[n]; p++,op++) FD(0,USIZE);
  }
  return ip - in;
}

//-------- TurboFloat 2D DFCM: Differential Finite Context Method Predictor ----------------------------------------------------------
size_t TEMPLATE2(fp2dfcmenc,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t *ip, _p[VSIZE+32], h = 0, *p, htab[1<<HBITS] = {0},start0=start; start=0;
  unsigned char *op = out;

  #define FE(i,_usize_) { TEMPLATE3(uint, _usize_, _t) u = ip[i]; p[i] = XORENC(u, (htab[h]+start),_usize_); b |= p[i]; \
    htab[h] = start = u - start; h = TEMPLATE2(HASH,_usize_)(h,start); start = start0; start0 = u;\
  }
  #define TR(i,_usize_) p[i] = TEMPLATE2(rbit,_usize_)(p[i]<<b)

  for(ip = in; ip != in + (n&~(VSIZE-1)); ) {
    uint_t b;
    for(p = _p; p != &_p[VSIZE]; p+=4,ip+=4) { FE(0,USIZE); FE(1,USIZE); FE(2,USIZE); FE(3,USIZE); }
    b = TEMPLATE2(clz,USIZE)(b);

    for(p = _p; p != &_p[VSIZE]; p+=4) { TR(0,USIZE); TR(1,USIZE); TR(2,USIZE); TR(3,USIZE); }
    *op++ = b; op = TEMPLATE2(P4ENCV,USIZE)(_p, VSIZE, op);                                                     PREFETCH(ip+512,0);
  }
  if(n = (in+n)-ip) {
    uint_t b;
    for(p = _p; p != &_p[n]; p++,ip++) FE(0,USIZE);
    b = TEMPLATE2(clz,USIZE)(b);

    for(p = _p; p != &_p[n]; p++) TR(0,USIZE);
    *op++ = b; op = TEMPLATE2(P4ENC,USIZE)(_p, n, op);
  }
  return op - out;
}

size_t TEMPLATE2(fp2dfcmdec,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) {
  uint_t      _p[VSIZE+32], *op, h = 0, *p, htab[1<<HBITS] = {0},start0=start; start=0; ;
  unsigned char *ip = in;

  #define FD(i,_usize_) { TEMPLATE3(uint, _usize_, _t) u = TEMPLATE2(rbit,_usize_)(p[i])>>b; u = XORDEC(u, (htab[h]+start),_usize_);\
    op[i] = u; htab[h] = start = u-start; h = TEMPLATE2(HASH,_usize_)(h,start); start = start0; start0 = u;\
  }

  for(op = (uint_t*)out; op != out+(n&~(VSIZE-1)); ) {                      PREFETCH(ip+512,0);
    uint_t b = *ip++;
    ip = TEMPLATE2(P4DECV,USIZE)(ip, VSIZE, _p);
    for(p = _p; p != &_p[VSIZE]; p+=4,op+=4) { FD(0,USIZE); FD(1,USIZE); FD(2,USIZE); FD(3,USIZE); }
  }
  if(n = ((uint_t *)out+n) - op) {
    uint_t b = *ip++;
    ip = TEMPLATE2(P4DEC,USIZE)(ip, n, _p);
    for(p = _p; p != &_p[n]; p++,op++) FD(0,USIZE);
  }
  return ip - in;
}

//-------- TurboGorilla : Improved Gorilla style (see Facebook paper) Floating point compression with bitio ------------------------------------
#define bitput2(_bw_,_br_, _n1_, _n2_, _x_) {\
           if(!_x_)                  bitput(_bw_,_br_,      1,       1);/*1*/\
      else if( _x_ < (1<< (_n1_-1))) bitput(_bw_,_br_, _n1_+2,_x_<<2|2);/*10*/\
      else                           bitput(_bw_,_br_, _n2_+2,_x_<<2  );/*00*/\
}

#define bitget2(_bw_,_br_, _n1_, _n2_, _x_) { _x_ = bitbw(_bw_,_br_);\
       if(_x_ & 1) bitrmv(_bw_,_br_,   0+1), _x_ = 0;\
  else if(_x_ & 2) bitrmv(_bw_,_br_,_n1_+2), _x_ = BZHI32(_x_>>2, _n1_);\
  else             bitrmv(_bw_,_br_,_n2_+2), _x_ = BZHI32(_x_>>2, _n2_);\
}

#define BSIZE(_usize_) (_usize_==64?6:(_usize_==32?5:(_usize_==16?4:3)))
size_t TEMPLATE2(fpgenc,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t        *ip;
  unsigned       ol = 0,ot = 0;
  unsigned char *op = out;
  bitdef(bw,br);
  if(start) { ol = TEMPLATE2(clz,USIZE)(start); ot = TEMPLATE2(ctz,USIZE)(start); }

  #define FE(i,_usize_) { TEMPLATE3(uint, _usize_, _t) z = XORENC(ip[i], start,_usize_); start = ip[i];\
    if(likely(!z))                           bitput( bw,br, 1, 1);\
    else { unsigned t = TEMPLATE2(ctz,_usize_)(z), l = TEMPLATE2(clz,_usize_)(z);\
      unsigned s = _usize_ - l - t, os = _usize_ - ol - ot;\
      if(l >= ol && t >= ot && os < 6+5+s) { bitput( bw,br, 2, 2);                                                                   TEMPLATE2(bitput,_usize_)(bw,br, os, z>>ot,op); }\
      else {                                 bitput( bw,br, 2+BSIZE(_usize_), l<<2); bitput2(bw,br, N_0, N_1, t); bitenorm(bw,br,op);TEMPLATE2(bitput,_usize_)(bw,br,  s, z>>t,op); ol = l; ot = t; }\
    } bitenorm(bw,br,op);\
  }
  for(ip = in; ip != in + (n&~(4-1)); ip+=4) { PREFETCH(ip+512,0); FE(0,USIZE); FE(1,USIZE); FE(2,USIZE); FE(3,USIZE); }
  for(       ; ip != in +  n        ; ip++) FE(0,USIZE);
  bitflush(bw,br,op);
  return op - out;
}

size_t TEMPLATE2(fpgdec,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) { if(!n) return 0;
  uint_t        *op;
  unsigned       ol = 0,ot = 0,x;
  unsigned char *ip = in;
  bitdef(bw,br);
  if(start) { ol = TEMPLATE2(clz,USIZE)(start); ot = TEMPLATE2(ctz,USIZE)(start); }

  #define FD(i,_usize_) { TEMPLATE3(uint, _usize_, _t) z=0; unsigned _x; BITGET32(bw,br,1,_x); \
    if(likely(!_x)) { BITGET32(bw,br,1,_x);\
      if(!_x) { BITGET32(bw,br,BSIZE(_usize_),ol); bitget2(bw,br, N_0, N_1, ot); bitdnorm(bw,br,ip); }\
      TEMPLATE2(bitget,_usize_)(bw,br,_usize_ - ol - ot,z,ip);\
      z<<=ot;\
    } op[i] = start = XORDEC(z, start,_usize_); bitdnorm(bw,br,ip);\
  }
  for(bitdnorm(bw,br,ip),op = out; op != out+(n&~(4-1)); op+=4) { FD(0,USIZE); FD(1,USIZE); FD(2,USIZE); FD(3,USIZE); PREFETCH(ip+512,0); }
  for(        ; op != out+n; op++) FD(0,USIZE);
  bitalign(bw,br,ip);
  return ip - in;
}

//------ Zigzag of zigzag with bitio for timestamps with bitio ------------------------------------------------------------------------------------------
// Improved Gorilla style compression with sliding zigzag of delta + RLE + overflow handling for timestamps in time series.
// More than 300 times better compression and several times faster
#define OVERFLOW if(op >= out_) { *out++ = 1<<4; /*bitini(bw,br); bitput(bw,br,4+3,1<<4); bitflush(bw,br,out);*/ memcpy(out,in,n*sizeof(in[0])); return 1+n*sizeof(in[0]); }

size_t TEMPLATE2(bvzzenc,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t        *ip = in, pd = 0, *pp = in,dd;
  unsigned char *op = out, *out_ = out+n*sizeof(in[0]);

  bitdef(bw,br);
  #define FE(_pp_, _ip_, _d_, _op_,_usize_) do {\
    uint64_t _r = _ip_ - _pp_;\
    if(_r > NL) { _r -= NL; unsigned _b = (bsr64(_r)+7)>>3; bitput(bw,br,4+3+3,(_b-1)<<(4+3)); bitput64(bw,br,_b<<3, _r, _op_); bitenorm(bw,br,_op_); }\
    else while(_r--) { bitput(bw,br,1,1); bitenorm(bw,br,_op_); }\
    _d_ = TEMPLATE2(zigzagenc,_usize_)(_d_);\
         if(!_d_)                bitput(bw,br,    1,       1);\
    else if(_d_ <  (1<< (N2-1))) bitput(bw,br, N2+2,_d_<<2|2);\
    else if(_d_ <  (1<< (N3-1))) bitput(bw,br, N3+3,_d_<<3|4);\
    else if(_d_ <  (1<< (N4-1))) bitput(bw,br, N4+4,_d_<<4|8);\
    else { unsigned _b = (TEMPLATE2(bsr,_usize_)(_d_)+7)>>3; bitput(bw,br,4+3,(_b-1)<<4); TEMPLATE2(bitput,_usize_)(bw,br, _b<<3, _d_,_op_); }\
    bitenorm(bw,br,_op_);\
  } while(0)

  if(n > 4)
    for(; ip < in+(n-1-4);) {
      start = ip[0] - start; dd = start-pd; pd = start; start = ip[0]; if(dd) goto a; ip++;
      start = ip[0] - start; dd = start-pd; pd = start; start = ip[0]; if(dd) goto a; ip++;
      start = ip[0] - start; dd = start-pd; pd = start; start = ip[0]; if(dd) goto a; ip++;
      start = ip[0] - start; dd = start-pd; pd = start; start = ip[0]; if(dd) goto a; ip++;     PREFETCH(ip+256,0);
      continue;
      a:;
      FE(pp,ip, dd, op,USIZE);
      pp = ++ip;        OVERFLOW;
    }

  for(;ip < in+n;) {
    start = ip[0] - start; dd = start-pd; pd = start; start = ip[0]; if(dd) goto b; ip++;
    continue;
    b:;
    FE(pp,ip, dd, op,USIZE);
    pp = ++ip; OVERFLOW;
  }
  if(ip > pp) {
    start = ip[0] - start; dd = start-pd;
    FE(pp, ip, dd, op, USIZE); OVERFLOW;
  }
  bitflush(bw,br,op);
  return op - out;
}

size_t TEMPLATE2(bvzzdec,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) { if(!n) return 0;
  uint_t *op = out, pd = 0;
  unsigned char *ip = in;

  bitdef(bw,br);
  for(bitdnorm(bw,br,ip); op < out+n; ) {                                                           PREFETCH(ip+384,0);
     #if USIZE == 64
    uint_t dd = bitbw(bw,br);
     #else
    uint32_t dd = bitbw(bw,br);
     #endif
         if(dd & 1) bitrmv(bw,br, 0+1), dd = 0;
    else if(dd & 2) bitrmv(bw,br,N2+2), dd = BZHI32(dd>>2, N2);
    else if(dd & 4) bitrmv(bw,br,N3+3), dd = BZHI32(dd>>3, N3);
    else if(dd & 8) bitrmv(bw,br,N4+4), dd = BZHI32(dd>>4, N4);
    else {
      unsigned b; uint_t *_op; uint64_t r;
      BITGET32(bw,br, 4+3, b);
      if((b>>=4) <= 1) {
        if(b==1) {                                                           // No compression, because of overflow
          memcpy(out,in+1, n*sizeof(out[0]));
          return 1+n*sizeof(out[0]);
        }
        BITGET32(bw,br,3,b); bitget32(bw,br,(b+1)<<3,r,ip); bitdnorm(bw,br,ip);//RLE     //r+=NL; while(r--) *op++=(start+=pd);
          #if (defined(__SSE2__) /*|| defined(__ARM_NEON)*/) && USIZE == 32
        __m128i sv = _mm_set1_epi32(start), cv = _mm_set_epi32(4*pd,3*pd,2*pd,1*pd);
        for(r += NL, _op = op; op != _op+(r&~7);) {
          sv = _mm_add_epi32(sv,cv); _mm_storeu_si128(op, sv); sv = mm_shuffle_nnnn_epi32(sv, 3); op += 4; //_mm_shuffle_epi32(sv, _MM_SHUFFLE(3, 3, 3, 3))->mm_shuffle_nnnn_epi32(sv, 3)
          sv = _mm_add_epi32(sv,cv); _mm_storeu_si128(op, sv); sv = mm_shuffle_nnnn_epi32(sv, 3); op += 4;
        }
        start = (unsigned)mm_cvtsi128_si32(_mm_srli_si128(sv,12));
          #else
        for(r+=NL, _op = op; op != _op+(r&~7); op += 8)
          op[0]=(start+=pd),
          op[1]=(start+=pd),
          op[2]=(start+=pd),
          op[3]=(start+=pd),
          op[4]=(start+=pd),
          op[5]=(start+=pd),
          op[6]=(start+=pd),
          op[7]=(start+=pd);
          #endif
        for(; op != _op+r; op++)
          *op = (start+=pd);
        continue;
      }
      TEMPLATE2(bitget,USIZE)(bw,br,(b+1)<<3,dd,ip);
    }
    pd += TEMPLATE2(zigzagdec,USIZE)(dd);
    *op++ = (start += pd);
    bitdnorm(bw,br,ip);
  }
  bitalign(bw,br,ip);
  return ip - in;
}

//-------- Zigzag with bit/io + RLE --------------------------------------------------------------------------
size_t TEMPLATE2(bvzenc,USIZE)(uint_t *in, size_t n, unsigned char *out, uint_t start) {
  uint_t        *ip = in, *pp = in,dd;
  unsigned char *op = out, *out_ = out+n*sizeof(in[0]);

  bitdef(bw,br);
  #define FE(_pp_, _ip_, _d_, _op_,_usize_) do {\
    uint64_t _r = _ip_ - _pp_;\
    if(_r > NL) { _r -= NL; unsigned _b = (bsr64(_r)+7)>>3; bitput(bw,br,4+3+3,(_b-1)<<(4+3)); bitput64(bw,br,_b<<3, _r, _op_); bitenorm(bw,br,_op_); }\
    else while(_r--) { bitput(bw,br,1,1); bitenorm(bw,br,_op_); }\
    _d_ = TEMPLATE2(zigzagenc,_usize_)(_d_);\
         if(!_d_)                bitput(bw,br,    1,       1);\
    else if(_d_ <  (1<< (N2-1))) bitput(bw,br, N2+2,_d_<<2|2);\
    else if(_d_ <  (1<< (N3-1))) bitput(bw,br, N3+3,_d_<<3|4);\
    else if(_d_ <  (1<< (N4-1))) bitput(bw,br, N4+4,_d_<<4|8);\
    else { unsigned _b = (TEMPLATE2(bsr,_usize_)(_d_)+7)>>3; bitput(bw,br,4+3,(_b-1)<<4); TEMPLATE2(bitput,_usize_)(bw,br, _b<<3, _d_,_op_); }\
    bitenorm(bw,br,_op_);\
  } while(0)

  if(n > 4)
    for(; ip < in+(n-1-4);) {
      dd = ip[0] - start; start = ip[0]; if(dd) goto a; ip++;
      dd = ip[0] - start; start = ip[0]; if(dd) goto a; ip++;
      dd = ip[0] - start; start = ip[0]; if(dd) goto a; ip++;
      dd = ip[0] - start; start = ip[0]; if(dd) goto a; ip++;   PREFETCH(ip+256,0);
      continue;
      a:;
      FE(pp,ip, dd, op,USIZE);
      pp = ++ip;        OVERFLOW;
    }

  for(;ip < in+n;) {
      dd = ip[0] - start; start = ip[0]; if(dd) goto b; ip++;
    continue;
    b:;
    FE(pp,ip, dd, op,USIZE);
    pp = ++ip; OVERFLOW;
  }
  if(ip > pp) {
    dd = ip[0] - start; start = ip[0];
    FE(pp, ip, dd, op, USIZE); OVERFLOW;
  }
  bitflush(bw,br,op);
  return op - out;
}

size_t TEMPLATE2(bvzdec,USIZE)(unsigned char *in, size_t n, uint_t *out, uint_t start) { if(!n) return 0;
  uint_t *op = out;
  unsigned char *ip = in;

  bitdef(bw,br);
  for(bitdnorm(bw,br,ip); op < out+n; ) {                                                           PREFETCH(ip+384,0);
     #if USIZE == 64
    uint_t dd = bitbw(bw,br);
     #else
    uint32_t dd = bitbw(bw,br);
     #endif
         if(dd & 1) bitrmv(bw,br, 0+1), dd = 0;
    else if(dd & 2) bitrmv(bw,br,N2+2), dd = BZHI32(dd>>2, N2);
    else if(dd & 4) bitrmv(bw,br,N3+3), dd = BZHI32(dd>>3, N3);
    else if(dd & 8) bitrmv(bw,br,N4+4), dd = BZHI32(dd>>4, N4);
    else {
      unsigned b; uint_t *_op; uint64_t r;
      BITGET32(bw,br, 4+3, b);
      if((b>>=4) <= 1) {
        if(b==1) {                                                           // No compression, because of overflow
          memcpy(out,in+1, n*sizeof(out[0]));
          return 1+n*sizeof(out[0]);
        }
        BITGET32(bw,br,3,b); bitget32(bw,br,(b+1)<<3,r,ip); bitdnorm(bw,br,ip);//RLE     //r+=NL; while(r--) *op++=(start+=pd);
          #if (defined(__SSE2__) || defined(__ARM_NEON)) && USIZE == 32
        __m128i sv = _mm_set1_epi32(start);
        for(r += NL, _op = op; op != _op+(r&~7);) {
          _mm_storeu_si128(op, sv); op += 4;
          _mm_storeu_si128(op, sv); op += 4;
        }
          #else
        for(r+=NL, _op = op; op != _op+(r&~7); op += 8)
          op[0]=op[1]=op[2]=op[3]=op[4]=op[5]=op[6]=op[7]=start;
          #endif
        for(; op != _op+r; op++)
          *op = start;
        continue;
      }
      TEMPLATE2(bitget,USIZE)(bw,br,(b+1)<<3,dd,ip);
    }
    dd = TEMPLATE2(zigzagdec,USIZE)(dd);
    *op++ = (start += dd);
    bitdnorm(bw,br,ip);
  }
  bitalign(bw,br,ip);
  return ip - in;
}

#undef USIZE
  #endif
