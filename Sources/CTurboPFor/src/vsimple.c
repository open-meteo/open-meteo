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
//  "Integer Compression" variable simple

#ifdef GUARDED

  #ifndef USIZE
    #ifdef __SSE2__
#include <emmintrin.h>
    #elif defined(__ARM_NEON)
#include <arm_neon.h>
#include "sse_neon.h"
    #endif
#pragma warning( disable : 4005)
#pragma warning( disable : 4090)
#pragma warning( disable : 4068)

#include "conf.h"
#include "vsimple.h"
#include <string.h>

  #ifdef __ARM_NEON
#define PREFETCH(_ip_,_rw_)
  #else
#define PREFETCH(_ip_,_rw_) __builtin_prefetch(_ip_,_rw_)
  #endif

  #ifndef SV_LIM32
#define USE_RLE

                                         //   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32
#define SV_LIM8  unsigned char s_lim8[]  = {  0, 28, 28, 28, 28, 36, 36, 36, 36,  0 };
#define SV_ITM8  unsigned      s_itm8[]  = {  0, 28, 14,  9,  7,  7,  6,  5,  4, -1 }
#define SV_LIM16 unsigned char s_lim16[] = {  0, 28, 28, 28, 28, 36, 36, 36, 36, 36, 60, 60, 60, 60, 60, 60, 60, 0 };
#define SV_ITM16 unsigned      s_itm16[] = {  0, 28, 14,  9,  7,  7,  6,  5,  4,  4,  6,  5,  5,  4,  4,  4,  3, -1 }
#define SV_LIM32 unsigned char s_lim32[] = {  0, 28, 28, 28, 28, 36, 36, 36, 36, 36, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 0 };
#define SV_ITM32 unsigned      s_itm32[] = {  0, 28, 14,  9,  7,  7,  6,  5,  4,  4,  6,  5,  5,  4,  4,  4,  3,  3,  3,  3,  3,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  1,  1, -1 }

#define SV_LIM64 unsigned char s_lim64[] = {  0, 28, 28, 28, 28, 36, 36, 36, 36, 36, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60,\
                                             60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 64, 64, 64, 64, 64, 64, 64, 64, 0 };

#define SV_ITM64 unsigned      s_itm64[] = {  0, 28, 14,  9,  7,  7,  6,  5,  4,  4,  6,  5,  5,  4,  4,  4,  3,  3,  3,  3,  3,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  1,  1,\
                                              1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, -1 }

static SV_LIM8;
static SV_ITM8;
static SV_LIM16;
static SV_ITM16;
static SV_LIM32;
static SV_ITM32;
static SV_ITM64;
static SV_LIM64;

#define EFE(__x,__i,__start) ((__x[__i] - __start)-(__i)*EF_INC)

  #endif

#define VSENC vsenc
#define VSDEC vsdec

#define USIZE 8
#include "vsimple.c"
#undef USIZE

#define USIZE 16
#include "vsimple.c"
#undef USIZE

#define USIZE 32
#include "vsimple.c"
#undef USIZE

#define USIZE 64
#include "vsimple.c"
#undef USIZE

  #else

#include <stdio.h>
#include <stdlib.h>
#include "conf.h"
#define VINT_IN
#include "vint.h"
#define uint_t TEMPLATE3(uint, USIZE, _t)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunsequenced"

unsigned char *TEMPLATE2(VSENC, USIZE)(uint_t *__restrict in, size_t n, unsigned char *__restrict out) {
  unsigned xm,m,r,x;
  uint_t *e = in+n,*ip,*sp;
  unsigned char *op = out,*op_ = out+n*(USIZE/8);
  for(ip = in; ip < e; ) {                                      PREFETCH(ip+256, 0);
    sp = ip;
      #ifdef USE_RLE
    if(ip+4 < e && *ip == *(ip+1)) {
      uint_t *q = ip+1;
      while(q+1 < e && *(q+1) == *ip) q++;
      r = q - ip;
      if(r*TEMPLATE2(bsr, USIZE)(*ip) > 16 || (!*ip && r>4)) {
        m = (*ip)?(USIZE<=32?33:65):0;
        goto a;
      }
    } else
      #endif
      r = 0;
    for(m = x = TEMPLATE2(bsr, USIZE)(*ip);(r+1)*(xm = x > m?x:m) <= TEMPLATE2(s_lim, USIZE)[xm] && ip+r<e;) m = xm, x = TEMPLATE2(bsr, USIZE)(ip[++r]);
    while(r < TEMPLATE2(s_itm, USIZE)[m]) m++;

    a:; //printf("%d,", m);
    switch(m) {
      case 0: ip += r;
        if(r >= 0xf) {
          *op++ = 0xf0;
          if(n <= 0x100)
            *op++ = r;
          else
            vbxput32(op, r);
        } else *op++ = r<<4;
        break;
      case 1:
        ctou32(op)      =    1 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] <<  5 |
        (unsigned)ip[ 2] <<  6 |
        (unsigned)ip[ 3] <<  7 |
        (unsigned)ip[ 4] <<  8 |
        (unsigned)ip[ 5] <<  9 |
        (unsigned)ip[ 6] << 10 |
        (unsigned)ip[ 7] << 11 |
        (unsigned)ip[ 8] << 12 |
        (unsigned)ip[ 9] << 13 |
        (unsigned)ip[10] << 14 |
        (unsigned)ip[11] << 15 |
        (unsigned)ip[12] << 16 |
        (unsigned)ip[13] << 17 |
        (unsigned)ip[14] << 18 |
        (unsigned)ip[15] << 19 |
        (unsigned)ip[16] << 20 |
        (unsigned)ip[17] << 21 |
        (unsigned)ip[18] << 22 |
        (unsigned)ip[19] << 23 |
        (unsigned)ip[20] << 24 |
        (unsigned)ip[21] << 25 |
        (unsigned)ip[22] << 26 |
        (unsigned)ip[23] << 27 |
        (unsigned)ip[24] << 28 |
        (unsigned)ip[25] << 29 |
        (unsigned)ip[26] << 30 |
        (unsigned)ip[27] << 31;     ip += 28; op += 4;
        break;
      case 2:
        ctou32(op)      =    2 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] <<  6 |
        (unsigned)ip[ 2] <<  8 |
        (unsigned)ip[ 3] << 10 |
        (unsigned)ip[ 4] << 12 |
        (unsigned)ip[ 5] << 14 |
        (unsigned)ip[ 6] << 16 |
        (unsigned)ip[ 7] << 18 |
        (unsigned)ip[ 8] << 20 |
        (unsigned)ip[ 9] << 22 |
        (unsigned)ip[10] << 24 |
        (unsigned)ip[11] << 26 |
        (unsigned)ip[12] << 28 |
        (unsigned)ip[13] << 30;     ip += 14; op += 4;
        break;
      case 3:
        ctou32(op)      =    3 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] <<  7 |
        (unsigned)ip[ 2] << 10 |
        (unsigned)ip[ 3] << 13 |
        (unsigned)ip[ 4] << 16 |
        (unsigned)ip[ 5] << 19 |
        (unsigned)ip[ 6] << 22 |
        (unsigned)ip[ 7] << 25 |
        (unsigned)ip[ 8] << 28;     ip +=  9; op += 4;
        break;
      case 4:
        ctou64(op) =         4 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] <<  8 |
        (unsigned)ip[ 2] << 12 |
        (unsigned)ip[ 3] << 16 |
        (unsigned)ip[ 4] << 20 |
        (unsigned)ip[ 5] << 24 |
        (unsigned)ip[ 6] << 28;     ip += 7; op += 4;
        break;
      case 5:
        ctou64(op) =    5 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] <<  9 |
        (unsigned)ip[ 2] << 14 |
        (unsigned)ip[ 3] << 19 |
        (unsigned)ip[ 4] << 24 |
        (uint64_t)ip[ 5] << 29 |
        (uint64_t)ip[ 6] << 34;     ip += 7; op += 5;
        break;
      case 6:
        ctou64(op) =         6 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] << 10 |
        (unsigned)ip[ 2] << 16 |
        (unsigned)ip[ 3] << 22 |
        (uint64_t)ip[ 4] << 28 |
        (uint64_t)ip[ 5] << 34;     ip +=  6; op += 5;
        break;
      case 7:
        ctou64(op) =         7 |
        (unsigned)ip[ 0] <<  5 |
        (unsigned)ip[ 1] << 12 |
        (unsigned)ip[ 2] << 19 |
        (uint64_t)ip[ 3] << 26 |
        (uint64_t)ip[ 4] << 33;     ip += 5; op += 5;
        break;
      case  8:
      case  9:
        ctou64(op) =         9 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] << 13 |
        (unsigned)ip[ 2] << 22 |
        (uint64_t)ip[ 3] << 31;     ip += 4; op += 5;
        break;
      case 10:
        ctou64(op) =        10 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] << 14 |
        (uint64_t)ip[ 2] << 24 |
        (uint64_t)ip[ 3] << 34 |
        (uint64_t)ip[ 4] << 44 |
        (uint64_t)ip[ 5] << 54;     ip += 6; op += 8;
        break;

      case 11:
      case 12:
        ctou64(op) =        12 |
        (unsigned)ip[ 0] <<  4 |
        (unsigned)ip[ 1] << 16 |
        (uint64_t)ip[ 2] << 28 |
        (uint64_t)ip[ 3] << 40 |
        (uint64_t)ip[ 4] << 52;     ip += 5; op += 8;
        break;
      case 13:
      case 14:
      case 15:
        ctou64(op) =        15 |
        (unsigned)ip[ 0] <<  4 |
        (uint64_t)ip[ 1] << 19 |
        (uint64_t)ip[ 2] << 34 |
        (uint64_t)ip[ 3] << 49;     ip += 4; op += 8;
        break;
      case 16:
      case 17:
      case 18:
      case 19:
      case 20:
        ctou64(op) =        11 |
        (unsigned)ip[ 0] <<  4 |
        (uint64_t)ip[ 1] << 24 |
        (uint64_t)ip[ 2] << 44;     ip += 3; op += 8;
        break;
      case 21:
      case 22:
      case 23:
      case 24:
      case 25:
      case 26:
      case 27:
      case 28:
      case 29:
      case 30:
        ctou64(op) =   13 |
        (uint64_t)ip[ 0] <<  4 |
        (uint64_t)ip[ 1] << 34;     ip += 2; op += 8;
        break;
      case 31:
      case 32:
        #if USIZE == 64
      case 33: case 34: case 35: case 36:
        #endif
        ctou64(op) =   14 |
        (uint64_t)ip[ 0] <<  4;     ip++;    op += 5;
        break;
        #if USIZE == 64
      default: xm = (m+7)/8;
        *op++ =   0x17 | (xm-1) << 5;
        ctou64(op) = (uint64_t)ip[ 0]; ip++;   op += xm;
        break;
        #endif
        #ifdef USE_RLE
      case USIZE<=32?33:65:         ip += r;
        if(--r >= 0xf) {
          *op++ = 0xf0|8;
          if(n <= 0x100)
            *op++ = r;
          else
            vbxput32(op, r);
        } else *op++ = r<<4|8;
        TEMPLATE2(vbxput, USIZE)(op, ip[0]);
        break;
        #endif

    }
    if(op > op_) { *out++ = 0; memcpy(out, in, n*(USIZE/8)); return out+n*(USIZE/8); }
  }
  return op;
}
#pragma clang diagnostic pop


#define OP(__x) op[__x] // *op++ //
#define OPI(__x) op+=__x// //

unsigned char *TEMPLATE2(VSDEC, USIZE)(unsigned char *__restrict ip, size_t n, uint_t *__restrict op) {
  uint_t *op_ = op+n;
  while(op < op_) {
    uint64_t w = *(uint64_t *)ip;                                               PREFETCH(ip+256, 0);
    switch(w & 0xf) {
      case 0: {
        uint_t *q = op;
        unsigned r = (w>>4)&0xf;
        if(!r) { memcpy(op,ip+1, n*(USIZE/8)); return ip+n*(USIZE/8); }
            #if defined(__SSE2__) || defined(__ARM_NEON)
        __m128i zv = _mm_setzero_si128();
          #endif
        ip++;
        if(unlikely(r == 0xf)) {
          if(n <= 0x100)
            r = (w>>8)&0xff, ip++;
          else { vbxget32(ip, r); }
        }
        r -= 1;
        op += r+1;
        while(q < op) {
            #if defined(__SSE2__) || defined(__ARM_NEON)
          _mm_storeu_si128((__m128i *)q,zv); q = (uint_t *)((unsigned char *)q+16);
          _mm_storeu_si128((__m128i *)q,zv); q = (uint_t *)((unsigned char *)q+16);
            #else
          q[0]=q[1]=q[2]=q[3]=q[4]=q[5]=q[6]=q[7]=0; q+=8;
            #endif
        } //while(r-->=0) *op++=0;
      } break;
      case 1:
        OP( 0) = (w >>  4) & 1;
        OP( 1) = (w >>  5) & 1;
        OP( 2) = (w >>  6) & 1;
        OP( 3) = (w >>  7) & 1;
        OP( 4) = (w >>  8) & 1;
        OP( 5) = (w >>  9) & 1;
        OP( 6) = (w >> 10) & 1;
        OP( 7) = (w >> 11) & 1;
        OP( 8) = (w >> 12) & 1;
        OP( 9) = (w >> 13) & 1;
        OP(10) = (w >> 14) & 1;
        OP(11) = (w >> 15) & 1;
        OP(12) = (w >> 16) & 1;
        OP(13) = (w >> 17) & 1;
        OP(14) = (w >> 18) & 1;
        OP(15) = (w >> 19) & 1;
        OP(16) = (w >> 20) & 1;
        OP(17) = (w >> 21) & 1;
        OP(18) = (w >> 22) & 1;
        OP(19) = (w >> 23) & 1;
        OP(20) = (w >> 24) & 1;
        OP(21) = (w >> 25) & 1;
        OP(22) = (w >> 26) & 1;
        OP(23) = (w >> 27) & 1;
        OP(24) = (w >> 28) & 1;
        OP(25) = (w >> 29) & 1;
        OP(26) = (w >> 30) & 1;
        OP(27) = (w >> 31) & 1;             OPI( 28); ip+=4;
        break;
      case 2:
        OP( 0) = (w >>  4) & 3;
        OP( 1) = (w >>  6) & 3;
        OP( 2) = (w >>  8) & 3;
        OP( 3) = (w >> 10) & 3;
        OP( 4) = (w >> 12) & 3;
        OP( 5) = (w >> 14) & 3;
        OP( 6) = (w >> 16) & 3;
        OP( 7) = (w >> 18) & 3;
        OP( 8) = (w >> 20) & 3;
        OP( 9) = (w >> 22) & 3;
        OP(10) = (w >> 24) & 3;
        OP(11) = (w >> 26) & 3;
        OP(12) = (w >> 28) & 3;
        OP(13) = (w >> 30) & 3;             OPI( 14);  ip+=4;
        break;
      case 3:
        OP( 0) = (w >>  4) & 7;
        OP( 1) = (w >>  7) & 7;
        OP( 2) = (w >> 10) & 7;
        OP( 3) = (w >> 13) & 7;
        OP( 4) = (w >> 16) & 7;
        OP( 5) = (w >> 19) & 7;
        OP( 6) = (w >> 22) & 7;
        OP( 7) = (w >> 25) & 7;
        OP( 8) = (w >> 28) & 7;             OPI( 9); ip+=4;
        break;
      case 4:
        OP( 0) = (w >>  4) & 0xf;
        OP( 1) = (w >>  8) & 0xf;
        OP( 2) = (w >> 12) & 0xf;
        OP( 3) = (w >> 16) & 0xf;
        OP( 4) = (w >> 20) & 0xf;
        OP( 5) = (w >> 24) & 0xf;
        OP( 6) = (w >> 28) & 0xf;           OPI( 7); ip+=4;
        break;
      case 5:
        OP( 0) = (w >>  4) & 0x1f;
        OP( 1) = (w >>  9) & 0x1f;
        OP( 2) = (w >> 14) & 0x1f;
        OP( 3) = (w >> 19) & 0x1f;
        OP( 4) = (w >> 24) & 0x1f;
        OP( 5) = (w >> 29) & 0x1f;
        OP( 6) = (w >> 34) & 0x1f;          OPI(  7); ip+=5;
        break;
      case 6:
        OP(0) = (w >>  4) & 0x3f;
        OP(1) = (w >> 10) & 0x3f;
        OP(2) = (w >> 16) & 0x3f;
        OP(3) = (w >> 22) & 0x3f;
        OP(4) = (w >> 28) & 0x3f;
        OP(5) = (w >> 34) & 0x3f;           OPI(  6); ip+=5;
        break;

      case 7:
          #if USIZE == 64
        if(unlikely((w>>4) & 1)) {
          unsigned b = ((*ip++) >> 5)+1;
          *op = *(unsigned long long *)ip;
          if(unlikely(b!=8))
            *op &= (1ull<<(b*8))-1;         op++; ip += b;
          break;
        }
          #endif
        OP(0) = (w >>  5) & 0x7f;
        OP(1) = (w >> 12) & 0x7f;
        OP(2) = (w >> 19) & 0x7f;
        OP(3) = (w >> 26) & 0x7f;
        OP(4) = (w >> 33) & 0x7f;           OPI( 5); ip+=5;
        break;

        #ifdef USE_RLE
      case 8: {
        uint_t *q=op,u;
        int r = (w>>4)&0xf;
        ip++;
        if(unlikely(r == 0xf)) {
          if(n <= 0x100)
            r = (w>>8)&0xff, ip++;
          else { vbxget32(ip, r); }
        }
        op += r+1; TEMPLATE2(vbxget, USIZE)(ip,u);
          #if (defined(__SSE2__) || defined(__ARM_NEON)) && USIZE == 32
        { __m128i v = _mm_set1_epi32(u);
          while(q < op) {
            _mm_storeu_si128((__m128i *)q,v); q += 4;
            _mm_storeu_si128((__m128i *)q,v); q += 4;
          }
        }
          #else
        while(q < op) {
          q[0]=q[1]=q[2]=q[3]=q[4]=q[5]=q[6]=q[7]=u; q+=8;
        } //while(r-->=0) *op++=u;
          #endif
      } break;
        #endif
      case 9:
        OP(0) = (w >>  4) & 0x1ff;
        OP(1) = (w >> 13) & 0x1ff;
        OP(2) = (w >> 22) & 0x1ff;
        OP(3) = (w >> 31) & 0x1ff;          OPI( 4); ip+=5;
        break;

      case 10:
        OP(0) = (w >>  4) & 0x3ff;
        OP(1) = (w >> 14) & 0x3ff;
        OP(2) = (w >> 24) & 0x3ff;
        OP(3) = (w >> 34) & 0x3ff;
        OP(4) = (w >> 44) & 0x3ff;
        OP(5) = (w >> 54) & 0x3ff;          OPI( 6); ip+=8;
        break;
      case 12:
        OP(0) = (w >>  4) & 0xfffu;
        OP(1) = (w >> 16) & 0xfffu;
        OP(2) = (w >> 28) & 0xfffu;
        OP(3) = (w >> 40) & 0xfffu;
        OP(4) = (w >> 52) & 0xfffu;         OPI( 5); ip+=8;
        break;
      case 15:
        OP(0) = (w >>  4) & 0x7fffu;
        OP(1) = (w >> 19) & 0x7fffu;
        OP(2) = (w >> 34) & 0x7fffu;
        OP(3) = (w >> 49) & 0x7fffu;        OPI( 4); ip+=8;
        break;
      case 11:
        OP(0) = (w >>  4) & 0xfffffu; // 20
        OP(1) = (w >> 24) & 0xfffffu;
        OP(2) = (w >> 44) & 0xfffffu;       OPI( 3); ip+=8;
        break;
      case 13:
        OP(0) = (w >>  4) & 0x3fffffffu;
        OP(1) = (w >> 34) & 0x3fffffffu;    OPI( 2); ip+=8;
        break;
      case 14:
          #if USIZE <= 32
        OP(0) = (w >> 4) &  0xfffffffffull; OPI( 1); ip+=5;
          #else
        OP(0) = (w >> 4) & 0xfffffffffull;  OPI( 1); ip+=5;
          #endif
        break;
    }
  }
 return ip;
}
#endif
#endif
