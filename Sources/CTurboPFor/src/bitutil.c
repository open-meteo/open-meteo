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
//    "Integer Compression" utility - delta, for, zigzag / Floating point compression
#include <math.h> //nan
#include "conf.h"
#define BITUTIL_IN
#include "bitutil.h"

//------------ 'or' for bitsize + 'xor' for all duplicate ------------------
#define BT(_i_) { o |= ip[_i_]; x |= ip[_i_] ^ u0; }
#define BIT(_in_, _n_, _usize_) {\
  u0 = _in_[0]; o = x = 0;\
  for(ip = _in_; ip != _in_+(_n_&~(4-1)); ip += 4) { BT(0); BT(1); BT(2); BT(3); }\
  for(;ip != _in_+_n_; ip++) BT(0);\
}

uint8_t  bit8( uint8_t  *in, unsigned n, uint8_t  *px) { uint8_t  o,x,u0,*ip; BIT(in, n,  8); if(px) *px = x; return o; }
uint64_t bit64(uint64_t *in, unsigned n, uint64_t *px) { uint64_t o,x,u0,*ip; BIT(in, n, 64); if(px) *px = x; return o; }

uint16_t bit16(uint16_t *in, unsigned n, uint16_t *px) {
  uint16_t o, x, u0 = in[0], *ip;
    #if defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vb0 = _mm_set1_epi16(u0), vo0 = _mm_setzero_si128(), vx0 = _mm_setzero_si128(),
                                     vo1 = _mm_setzero_si128(), vx1 = _mm_setzero_si128();
  for(ip = in; ip != in+(n&~(16-1)); ip += 16) {                                PREFETCH(ip+512,0);
    __m128i v0 = _mm_loadu_si128((__m128i *) ip);
    __m128i v1 = _mm_loadu_si128((__m128i *)(ip+8));
    vo0 = _mm_or_si128( vo0, v0);
    vo1 = _mm_or_si128( vo1, v1);
    vx0 = _mm_or_si128(vx0, _mm_xor_si128(v0, vb0));
    vx1 = _mm_or_si128(vx1, _mm_xor_si128(v1, vb0));
  }
  vo0 = _mm_or_si128(vo0, vo1); o = mm_hor_epi16(vo0);
  vx0 = _mm_or_si128(vx0, vx1); x = mm_hor_epi16(vx0);
    #else
  ip = in; o = x = 0; //BIT( in, n, 16);
    #endif
  for(; ip != in+n; ip++) BT(0);
  if(px) *px = x;
  return o;
}

uint32_t bit32(uint32_t *in, unsigned n, uint32_t *px) {
  uint32_t o,x,u0 = in[0], *ip;
    #ifdef __AVX2__
  __m256i vb0 = _mm256_set1_epi32(*in), vo0 = _mm256_setzero_si256(), vx0 = _mm256_setzero_si256(),
                                        vo1 = _mm256_setzero_si256(), vx1 = _mm256_setzero_si256();
  for(ip = in; ip != in+(n&~(16-1)); ip += 16) {                                PREFETCH(ip+512,0);
    __m256i v0 = _mm256_loadu_si256((__m256i *) ip);
    __m256i v1 = _mm256_loadu_si256((__m256i *)(ip+8));
    vo0 = _mm256_or_si256(vo0, v0);
    vo1 = _mm256_or_si256(vo1, v1);
    vx0 = _mm256_or_si256(vx0, _mm256_xor_si256(v0, vb0));
    vx1 = _mm256_or_si256(vx1, _mm256_xor_si256(v1, vb0));
  }
  vo0 = _mm256_or_si256(vo0, vo1); o = mm256_hor_epi32(vo0);
  vx0 = _mm256_or_si256(vx0, vx1); x = mm256_hor_epi32(vx0);
    #elif defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vb0 = _mm_set1_epi32(u0), vo0 = _mm_setzero_si128(), vx0 = _mm_setzero_si128(),
                                     vo1 = _mm_setzero_si128(), vx1 = _mm_setzero_si128();
  for(ip = in; ip != in+(n&~(8-1)); ip += 8) {                                  PREFETCH(ip+512,0);
    __m128i v0 = _mm_loadu_si128((__m128i *) ip);
    __m128i v1 = _mm_loadu_si128((__m128i *)(ip+4));
    vo0 = _mm_or_si128(vo0, v0);
    vo1 = _mm_or_si128(vo1, v1);
    vx0 = _mm_or_si128(vx0, _mm_xor_si128(v0, vb0));
    vx1 = _mm_or_si128(vx1, _mm_xor_si128(v1, vb0));
  }
  vo0 = _mm_or_si128(vo0, vo1); o = mm_hor_epi32(vo0);
  vx0 = _mm_or_si128(vx0, vx1); x = mm_hor_epi32(vx0);
    #else
  ip = in; o = x = 0; //BIT( in, n, 32);
    #endif
  for(; ip != in+n; ip++) BT(0);
  if(px) *px = x;
  return o;
}

//----------------------------------------------------------- Delta ----------------------------------------------------------------
#define DE(_ip_,_i_) u = (_ip_[_i_]-start)-_md; start = _ip_[_i_];
#define BITDE(_t_, _in_, _n_, _md_, _act_) { _t_ _md = _md_, *_ip; o = x = 0;\
  for(_ip = _in_; _ip != _in_+(_n_&~(4-1)); _ip += 4) { DE(_ip,0);_act_; DE(_ip,1);_act_; DE(_ip,2);_act_; DE(_ip,3);_act_; }\
  for(;_ip != _in_+_n_;_ip++) { DE(_ip,0); _act_; }\
}
//---- (min. Delta = 0)
//-- delta encoding
uint8_t   bitd8( uint8_t  *in, unsigned n, uint8_t  *px, uint8_t  start) { uint8_t  u, u0 = in[0]-start, o, x; BITDE(uint8_t,  in, n, 0, o |= u; x |= u^u0); if(px) *px = x; return o; }
uint64_t  bitd64(uint64_t *in, unsigned n, uint64_t *px, uint64_t start) { uint64_t u, u0 = in[0]-start, o, x; BITDE(uint64_t, in, n, 0, o |= u; x |= u^u0); if(px) *px = x; return o; }

uint16_t bitd16(uint16_t *in, unsigned n, uint16_t *px, uint16_t start) {
  uint16_t o, x, *ip, u0 = in[0]-start;
    #if defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vb0 = _mm_set1_epi16(u0),
          vo0 = _mm_setzero_si128(), vx0 = _mm_setzero_si128(),
          vo1 = _mm_setzero_si128(), vx1 = _mm_setzero_si128();                 __m128i vs = _mm_set1_epi16(start);
  for(ip = in; ip != in+(n&~(16-1)); ip += 16) {                                PREFETCH(ip+512,0);
    __m128i vi0 = _mm_loadu_si128((__m128i *) ip);
    __m128i vi1 = _mm_loadu_si128((__m128i *)(ip+8));                           __m128i v0 = mm_delta_epi16(vi0,vs); vs = vi0;
                                                                                __m128i v1 = mm_delta_epi16(vi1,vs); vs = vi1;
    vo0 = _mm_or_si128(vo0, v0);
    vo1 = _mm_or_si128(vo1, v1);
    vx0 = _mm_or_si128(vx0, _mm_xor_si128(v0, vb0));
    vx1 = _mm_or_si128(vx1, _mm_xor_si128(v1, vb0));
  }                                                                             start = mm_cvtsi128_si16(_mm_srli_si128(vs,14));
  vo0 = _mm_or_si128(vo0, vo1); o = mm_hor_epi16(vo0);
  vx0 = _mm_or_si128(vx0, vx1); x = mm_hor_epi16(vx0);
    #else
  ip = in; o = x = 0;
    #endif
  for(;ip != in+n; ip++) {
    uint16_t u = *ip - start; start = *ip;
    o |= u;
    x |= u ^ u0;
  }
  if(px) *px = x;
  return o;
}

uint32_t bitd32(uint32_t *in, unsigned n, uint32_t *px, uint32_t start) {
  uint32_t o, x, *ip, u0 = in[0] - start;
    #ifdef __AVX2__
  __m256i vb0 = _mm256_set1_epi32(u0),
          vo0 = _mm256_setzero_si256(), vx0 = _mm256_setzero_si256(),
          vo1 = _mm256_setzero_si256(), vx1 = _mm256_setzero_si256();           __m256i vs = _mm256_set1_epi32(start);
  for(ip = in; ip != in+(n&~(16-1)); ip += 16) {                                PREFETCH(ip+512,0);
    __m256i vi0 = _mm256_loadu_si256((__m256i *) ip);
    __m256i vi1 = _mm256_loadu_si256((__m256i *)(ip+8));                        __m256i v0 = mm256_delta_epi32(vi0,vs); vs = vi0;
                                                                                __m256i v1 = mm256_delta_epi32(vi1,vs); vs = vi1;
    vo0 = _mm256_or_si256(vo0, v0);
    vo1 = _mm256_or_si256(vo1, v1);
    vx0 = _mm256_or_si256(vx0, _mm256_xor_si256(v0, vb0));
    vx1 = _mm256_or_si256(vx1, _mm256_xor_si256(v1, vb0));
  }                                                                             start = (unsigned)_mm256_extract_epi32(vs, 7);
  vo0 = _mm256_or_si256(vo0, vo1); o = mm256_hor_epi32(vo0);
  vx0 = _mm256_or_si256(vx0, vx1); x = mm256_hor_epi32(vx0);
    #elif defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vb0 = _mm_set1_epi32(u0),
          vo0 = _mm_setzero_si128(), vx0 = _mm_setzero_si128(),
          vo1 = _mm_setzero_si128(), vx1 = _mm_setzero_si128();                 __m128i vs = _mm_set1_epi32(start);
  for(ip = in; ip != in+(n&~(8-1)); ip += 8) {                                  PREFETCH(ip+512,0);
    __m128i vi0 = _mm_loadu_si128((__m128i *)ip);
    __m128i vi1 = _mm_loadu_si128((__m128i *)(ip+4));                           __m128i v0 = mm_delta_epi32(vi0,vs); vs = vi0;
                                                                                __m128i v1 = mm_delta_epi32(vi1,vs); vs = vi1;
    vo0 = _mm_or_si128(vo0, v0);
    vo1 = _mm_or_si128(vo1, v1);
    vx0 = _mm_or_si128(vx0, _mm_xor_si128(v0, vb0));
    vx1 = _mm_or_si128(vx1, _mm_xor_si128(v1, vb0));
  }                                                                             start = _mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  vo0 = _mm_or_si128(vo0, vo1); o = mm_hor_epi32(vo0);
  vx0 = _mm_or_si128(vx0, vx1); x = mm_hor_epi32(vx0);
    #else
  ip = in; o = x = 0;
    #endif
  for(;ip != in+n; ip++) {
    uint32_t u = *ip - start; start = *ip;
    o |= u;
    x |= u ^ u0;
  }
  if(px) *px = x;
  return o;
}

//----- Undelta: In-place prefix sum (min. Delta = 0) -------------------
#define DD(i) _ip[i] = (start += _ip[i] + _md);
#define BITDD(_t_, _in_, _n_, _md_) { _t_ *_ip; const int _md = _md_;\
  for(_ip = _in_; _ip != _in_+(_n_&~(4-1)); _ip += 4) { DD(0); DD(1); DD(2); DD(3); }\
  for(;_ip != _in_+_n_; _ip++) DD(0);\
}

void bitddec8( uint8_t  *p, unsigned n, uint8_t  start) { BITDD(uint8_t,  p, n, 0); }
void bitddec16(uint16_t *p, unsigned n, uint16_t start) { BITDD(uint16_t, p, n, 0); }
void bitddec64(uint64_t *p, unsigned n, uint64_t start) { BITDD(uint64_t, p, n, 0); }
void bitddec32(uint32_t *p, unsigned n, unsigned start) {
    #ifdef __AVX2__
  __m256i vs = _mm256_set1_epi32(start);
  unsigned *ip;
  for(ip = p; ip != p+(n&~(8-1)); ip += 8) {
    __m256i v =  _mm256_loadu_si256((__m256i *)ip);
    vs = mm256_scan_epi32(v,vs);
    _mm256_storeu_si256((__m256i *)ip, vs);
  }
  start = (unsigned)_mm256_extract_epi32(vs, 7);
  while(ip != p+n) {
    *ip = (start += (*ip));
    ip++;
  }
    #elif defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vs = _mm_set1_epi32(start);
  unsigned *ip;
  for(ip = p; ip != p+(n&~(4-1)); ip += 4) {
    __m128i v =  _mm_loadu_si128((__m128i *)ip);
    vs = mm_scan_epi32(v, vs);
    _mm_storeu_si128((__m128i *)ip, vs);
  }
  start = (unsigned)_mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  while(ip != p+n) {
    *ip = (start += (*ip));
    ip++;
  }
    #else
  BITDD(uint32_t, p, n, 0);
    #endif
}

//----------- Zigzag of Delta --------------------------
#define ZDE(i, _usize_) d = (_ip[i]-start)-_md; u = TEMPLATE2(zigzagenc, _usize_)(d - startd); startd = d; start = _ip[i]
#define BITZDE(_t_, _in_, _n_, _md_, _usize_, _act_) { _t_ *_ip, _md = _md_;\
  for(_ip = _in_; _ip != _in_+(_n_&~(4-1)); _ip += 4) { ZDE(0, _usize_);_act_; ZDE(1, _usize_);_act_; ZDE(2, _usize_);_act_; ZDE(3, _usize_);_act_; }\
  for(;_ip != _in_+_n_;_ip++) { ZDE(0, _usize_); _act_; }\
}

uint8_t  bitzz8( uint8_t  *in, unsigned n, uint8_t  *px, uint8_t  start) { uint8_t  o=0, x=0,d,startd=0,u; BITZDE(uint8_t,  in, n, 1,  8, o |= u; x |= u ^ in[0]); if(px) *px = x; return o; }
uint16_t bitzz16(uint16_t *in, unsigned n, uint16_t *px, uint16_t start) { uint16_t o=0, x=0,d,startd=0,u; BITZDE(uint16_t, in, n, 1, 16, o |= u; x |= u ^ in[0]); if(px) *px = x; return o; }
uint32_t bitzz32(uint32_t *in, unsigned n, uint32_t *px, uint32_t start) { uint64_t o=0, x=0,d,startd=0,u; BITZDE(uint32_t, in, n, 1, 32, o |= u; x |= u ^ in[0]); if(px) *px = x; return o; }
uint64_t bitzz64(uint64_t *in, unsigned n, uint64_t *px, uint64_t start) { uint64_t o=0, x=0,d,startd=0,u; BITZDE(uint64_t, in, n, 1, 64, o |= u; x |= u ^ in[0]); if(px) *px = x; return o; }
uint8_t  bitzzenc8( uint8_t  *in, unsigned n, uint8_t  *out, uint8_t  start, uint8_t  mindelta) { uint8_t  o=0,*op = out,u,d,startd=0; BITZDE(uint8_t,  in, n, mindelta,  8,o |= u;*op++ = u); return o;}
uint16_t bitzzenc16(uint16_t *in, unsigned n, uint16_t *out, uint16_t start, uint16_t mindelta) { uint16_t o=0,*op = out,u,d,startd=0; BITZDE(uint16_t, in, n, mindelta, 16,o |= u;*op++ = u); return o;}
uint32_t bitzzenc32(uint32_t *in, unsigned n, uint32_t *out, uint32_t start, uint32_t mindelta) { uint32_t o=0,*op = out,u,d,startd=0; BITZDE(uint32_t, in, n, mindelta, 32,o |= u;*op++ = u); return o;}
uint64_t bitzzenc64(uint64_t *in, unsigned n, uint64_t *out, uint64_t start, uint64_t mindelta) { uint64_t o=0,*op = out,u,d,startd=0; BITZDE(uint64_t, in, n, mindelta, 64,o |= u;*op++ = u); return o;}

#define ZDD(i) u = _ip[i]; d = u - start; _ip[i] = zigzagdec64(u)+(int64_t)startd+_md; startd = d; start = u
#define BITZDD(_t_, _in_, _n_, _md_) { _t_ *_ip, startd=0,d,u; const int _md = _md_;\
  for(_ip = _in_; _ip != _in_+(_n_&~(4-1)); _ip += 4) { ZDD(0); ZDD(1); ZDD(2); ZDD(3); }\
  for(;_ip != _in_+_n_; _ip++) ZDD(0);\
}
void bitzzdec8( uint8_t  *p, unsigned n, uint8_t  start) { BITZDD(uint8_t,  p, n, 1); }
void bitzzdec16(uint16_t *p, unsigned n, uint16_t start) { BITZDD(uint16_t, p, n, 1); }
void bitzzdec64(uint64_t *p, unsigned n, uint64_t start) { BITZDD(uint64_t, p, n, 1); }
void bitzzdec32(uint32_t *p, unsigned n, uint32_t start) { BITZDD(uint32_t, p, n, 1); }

//-----Undelta: In-place prefix sum (min. Delta = 1) -------------------
uint8_t  bitd18( uint8_t  *in, unsigned n, uint8_t  *px, uint8_t  start) { uint8_t  o=0,x=0,u,*ip; BITDE(uint8_t,  in, n, 1, o |= u; x |= u ^ in[0]); if(px) *px = x; return o; }
uint16_t bitd116(uint16_t *in, unsigned n, uint16_t *px, uint16_t start) { uint16_t o=0,x=0,u,*ip; BITDE(uint16_t, in, n, 1, o |= u; x |= u ^ in[0]); if(px) *px = x; return o; }
uint64_t bitd164(uint64_t *in, unsigned n, uint64_t *px, uint64_t start) { uint64_t o=0,x=0,u,*ip; BITDE(uint64_t, in, n, 1, o |= u; x |= u ^ in[0]); if(px) *px = x; return o; }

uint32_t bitd132(uint32_t *in, unsigned n, uint32_t *px, uint32_t start) {
  uint32_t o, x, *ip, u0 = in[0]-start-1;
    #ifdef __AVX2__
   __m256i vb0 = _mm256_set1_epi32(u0),
           vo0 = _mm256_setzero_si256(), vx0 = _mm256_setzero_si256(),
           vo1 = _mm256_setzero_si256(), vx1 = _mm256_setzero_si256();          __m256i vs = _mm256_set1_epi32(start), cv = _mm256_set1_epi32(1);
  for(ip = in; ip != in+(n&~(16-1)); ip += 16) {                                PREFETCH(ip+512,0);
    __m256i vi0 = _mm256_loadu_si256((__m256i *)ip);
    __m256i vi1 = _mm256_loadu_si256((__m256i *)(ip+8));                        __m256i v0 = _mm256_sub_epi32(mm256_delta_epi32(vi0,vs),cv); vs = vi0;
                                                                                __m256i v1 = _mm256_sub_epi32(mm256_delta_epi32(vi1,vs),cv); vs = vi1;
    vo0 = _mm256_or_si256(vo0, v0);
    vo1 = _mm256_or_si256(vo1, v1);
    vx0 = _mm256_or_si256(vx0, _mm256_xor_si256(v0, vb0));
    vx1 = _mm256_or_si256(vx1, _mm256_xor_si256(v1, vb0));
  }                                                                             start = (unsigned)_mm256_extract_epi32(vs, 7);
  vo0 = _mm256_or_si256(vo0, vo1); o = mm256_hor_epi32(vo0);
  vx0 = _mm256_or_si256(vx0, vx1); x = mm256_hor_epi32(vx0);
   #elif defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vb0 = _mm_set1_epi32(u0),
          vo0 = _mm_setzero_si128(), vx0 = _mm_setzero_si128(),
          vo1 = _mm_setzero_si128(), vx1 = _mm_setzero_si128();                 __m128i vs = _mm_set1_epi32(start), cv = _mm_set1_epi32(1);
  for(ip = in; ip != in+(n&~(8-1)); ip += 8) {                                  PREFETCH(ip+512,0);
    __m128i vi0 = _mm_loadu_si128((__m128i *)ip);
    __m128i vi1 = _mm_loadu_si128((__m128i *)(ip+4));                           __m128i v0 = _mm_sub_epi32(mm_delta_epi32(vi0,vs),cv); vs = vi0;
                                                                                __m128i v1 = _mm_sub_epi32(mm_delta_epi32(vi1,vs),cv); vs = vi1;
    vo0 = _mm_or_si128(vo0, v0);
    vo1 = _mm_or_si128(vo1, v1);
    vx0 = _mm_or_si128(vx0, _mm_xor_si128(v0, vb0));
    vx1 = _mm_or_si128(vx1, _mm_xor_si128(v1, vb0));
  }                                                                             start = _mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  vo0 = _mm_or_si128(vo0, vo1); o = mm_hor_epi32(vo0);
  vx0 = _mm_or_si128(vx0, vx1); x = mm_hor_epi32(vx0);
    #else
  ip = in; o = x = 0;
    #endif
  for(;ip != in+n; ip++) {
    uint32_t u = ip[0] - start-1; start = *ip;
    o |= u;
    x |= u ^ u0;
  }
  if(px) *px = x;
  return o;
}

uint16_t bits128v16(uint16_t *in, unsigned n, uint16_t *px, uint16_t start) {
    #if defined(__SSE2__) || defined(__ARM_NEON)
  unsigned *ip,b; __m128i bv = _mm_setzero_si128(), vs = _mm_set1_epi16(start), cv = _mm_set1_epi16(8);
  for(ip = in; ip != in+(n&~(4-1)); ip += 4) {
    __m128i iv = _mm_loadu_si128((__m128i *)ip);
    bv = _mm_or_si128(bv,_mm_sub_epi16(SUBI16x8(iv,vs),cv));
    vs = iv;
  }
  start = (unsigned short)_mm_cvtsi128_si32(_mm_srli_si128(vs,14));
  b = mm_hor_epi16(bv);
  if(px) *px = 0;
  return b;
    #endif
}

unsigned bits128v32(uint32_t *in, unsigned n, uint32_t *px, uint32_t start) {
    #if defined(__SSE2__) || defined(__ARM_NEON)
  unsigned *ip,b; __m128i bv = _mm_setzero_si128(), vs = _mm_set1_epi32(start), cv = _mm_set1_epi32(4);
  for(ip = in; ip != in+(n&~(4-1)); ip += 4) {
    __m128i iv = _mm_loadu_si128((__m128i *)ip);
    bv = _mm_or_si128(bv,_mm_sub_epi32(SUBI32x4(iv,vs),cv));
    vs = iv;
  }
  start = (unsigned)_mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  b = mm_hor_epi32(bv);
  if(px) *px = 0;
  return b;
    #endif
}

void bitd1dec8( uint8_t  *p, unsigned n, uint8_t  start) { BITDD(uint8_t,  p, n, 1); }
void bitd1dec16(uint16_t *p, unsigned n, uint16_t start) { BITDD(uint16_t, p, n, 1); }
void bitd1dec64(uint64_t *p, unsigned n, uint64_t start) { BITDD(uint64_t, p, n, 1); }
void bitd1dec32(uint32_t *p, unsigned n, uint32_t start) {
    #ifdef __AVX2__
  __m256i vs = _mm256_set1_epi32(start),zv = _mm256_setzero_si256(), cv = _mm256_set_epi32(8,7,6,5,4,3,2,1);
  unsigned *ip;
  for(ip = p; ip != p+(n&~(8-1)); ip += 8) {
    __m256i v =  _mm256_loadu_si256((__m256i *)ip);                             vs = mm256_scani_epi32(v, vs, cv);
    _mm256_storeu_si256((__m256i *)ip, vs);
  }
                                                                                start = (unsigned)_mm256_extract_epi32(vs, 7);
  while(ip != p+n) {
    *ip = (start += (*ip) + 1);
    ip++;
  }
    #elif defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vs = _mm_set1_epi32(start), cv = _mm_set_epi32(4,3,2,1);
  unsigned *ip;
  for(ip = p; ip != p+(n&~(4-1)); ip += 4) {
    __m128i v =  _mm_loadu_si128((__m128i *)ip);
    vs = mm_scani_epi32(v, vs, cv);
    _mm_storeu_si128((__m128i *)ip, vs);
  }
  start = (unsigned)_mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  while(ip != p+n) {
    *ip = (start += (*ip) + 1);
    ip++;
  }
    #else
  BITDD(uint32_t, p, n, 1);
    #endif
}

//---------Delta encoding/decoding (min. Delta = mindelta) -------------------
//determine min. delta for encoding w/ bitdiencNN function
#define DI(_ip_,_i_) u = _ip_[_i_] - start; start = _ip_[_i_]; if(u < mindelta) mindelta = u
#define BITDIE(_in_, _n_) {\
  for(_ip = _in_,mindelta = _ip[0]; _ip != _in_+(_n_&~(4-1)); _ip+=4) { DI(_ip,0); DI(_ip,1); DI(_ip,2); DI(_ip,3); }\
  for(;_ip != _in_+_n_;_ip++) DI(_ip,0);\
}

uint8_t  bitdi8( uint8_t  *in, unsigned n, uint8_t  *px, uint8_t  start) { uint8_t  mindelta,u,*_ip; BITDIE(in, n); if(px) *px = 0; return mindelta; }
uint16_t bitdi16(uint16_t *in, unsigned n, uint16_t *px, uint16_t start) { uint16_t mindelta,u,*_ip; BITDIE(in, n); if(px) *px = 0; return mindelta; }
uint32_t bitdi32(uint32_t *in, unsigned n, uint32_t *px, uint32_t start) { uint32_t mindelta,u,*_ip; BITDIE(in, n); if(px) *px = 0; return mindelta; }
uint64_t bitdi64(uint64_t *in, unsigned n, uint64_t *px, uint64_t start) { uint64_t mindelta,u,*_ip; BITDIE(in, n); if(px) *px = 0; return mindelta; }

uint8_t  bitdienc8( uint8_t  *in, unsigned n, uint8_t  *out, uint8_t  start, uint8_t  mindelta) { uint8_t  o=0,x=0,*op = out,u,*ip; BITDE(uint8_t,  in, n, mindelta, o |= u; x |= u ^ in[0]; *op++ = u); return o; }
uint16_t bitdienc16(uint16_t *in, unsigned n, uint16_t *out, uint16_t start, uint16_t mindelta) { uint16_t o=0,x=0,*op = out,u,*ip; BITDE(uint16_t, in, n, mindelta, o |= u; x |= u ^ in[0]; *op++ = u); return o; }
uint64_t bitdienc64(uint64_t *in, unsigned n, uint64_t *out, uint64_t start, uint64_t mindelta) { uint64_t o=0,x=0,*op = out,u,*ip; BITDE(uint64_t, in, n, mindelta, o |= u; x |= u ^ in[0]; *op++ = u); return o; }
uint32_t bitdienc32(uint32_t *in, unsigned n, uint32_t *out, uint32_t start, uint32_t mindelta) {
    #if defined(__SSE2__) || defined(__ARM_NEON)
  unsigned *ip,b,*op = out;
  __m128i bv = _mm_setzero_si128(), vs = _mm_set1_epi32(start), cv = _mm_set1_epi32(mindelta), dv;
  for(ip = in; ip != in+(n&~(4-1)); ip += 4,op += 4) {
    __m128i iv = _mm_loadu_si128((__m128i *)ip);
    bv = _mm_or_si128(bv, dv = _mm_sub_epi32(mm_delta_epi32(iv,vs),cv));
    vs = iv;
    _mm_storeu_si128((__m128i *)op, dv);
  }
  start = (unsigned)_mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  b = mm_hor_epi32(bv);
  while(ip != in+n) {
    unsigned x = *ip-start-mindelta;
    start = *ip++;
    b    |= x;
    *op++ = x;
  }
    #else
  uint32_t b = 0,*op = out, x, *_ip;
  BITDE(uint32_t, in, n, mindelta, b |= x; *op++ = x);
    #endif
  return b;
}

void bitdidec8(  uint8_t  *p, unsigned n, uint8_t  start, uint8_t  mindelta) { BITDD(uint8_t,  p, n, mindelta); }
void bitdidec16( uint16_t *p, unsigned n, uint16_t start, uint16_t mindelta) { BITDD(uint16_t, p, n, mindelta); }
void bitdidec32( uint32_t *p, unsigned n, uint32_t start, uint32_t mindelta) { BITDD(uint32_t, p, n, mindelta); }
void bitdidec64( uint64_t *p, unsigned n, uint64_t start, uint64_t mindelta) { BITDD(uint64_t, p, n, mindelta); }

//------------------- For ------------------------------
uint8_t  bitf8(  uint8_t  *in, unsigned n, uint8_t  *px, uint8_t  start) { if(px) *px = 0; return n?in[n-1] - start    :0; }
uint8_t  bitf18( uint8_t  *in, unsigned n, uint8_t  *px, uint8_t  start) { if(px) *px = 0; return n?in[n-1] - start - n:0; }
uint16_t bitf16( uint16_t *in, unsigned n, uint16_t *px, uint16_t start) { if(px) *px = 0; return n?in[n-1] - start    :0; }
uint16_t bitf116(uint16_t *in, unsigned n, uint16_t *px, uint16_t start) { if(px) *px = 0; return n?in[n-1] - start - n:0; }
uint32_t bitf32( uint32_t *in, unsigned n, uint32_t *px, uint32_t start) { if(px) *px = 0; return n?in[n-1] - start    :0; }
uint32_t bitf132(uint32_t *in, unsigned n, uint32_t *px, uint32_t start) { if(px) *px = 0; return n?in[n-1] - start - n:0; }
uint64_t bitf64( uint64_t *in, unsigned n, uint64_t *px, uint64_t start) { if(px) *px = 0; return n?in[n-1] - start    :0; }
uint64_t bitf164(uint64_t *in, unsigned n, uint64_t *px, uint64_t start) { if(px) *px = 0; return n?in[n-1] - start - n:0; }

//------------------- Zigzag ---------------------------
#define ZE(i,_it_,_usize_) u = TEMPLATE2(zigzagenc, _usize_)((_it_)_ip[i]-(_it_)start); start = _ip[i]
#define BITZENC(_ut_, _it_, _usize_, _in_,_n_, _act_) { _ut_ *_ip; o = 0; x = -1;\
  for(_ip = _in_; _ip != _in_+(_n_&~(4-1)); _ip += 4) { ZE(0,_it_,_usize_);_act_; ZE(1,_it_,_usize_);_act_; ZE(2,_it_,_usize_);_act_; ZE(3,_it_,_usize_);_act_; }\
  for(;_ip != _in_+_n_; _ip++) { ZE(0,_it_,_usize_); _act_; }\
}

// 'or' bits for zigzag encoding
uint8_t  bitz8( uint8_t  *in, unsigned n, uint8_t  *px, uint8_t  start) { uint8_t  o, u,x; BITZENC(uint8_t,  int8_t, 8, in, n, o |= x); if(px) *px = 0; return o; }
uint64_t bitz64(uint64_t *in, unsigned n, uint64_t *px, uint64_t start) { uint64_t o, u,x; BITZENC(uint64_t, int64_t,64,in, n, o |= x); if(px) *px = 0; return o; }

uint16_t bitz16(uint16_t *in, unsigned n, uint16_t *px, uint16_t start) {
  uint16_t o, x, *ip; uint32_t u0 = zigzagenc16((int)in[0] - (int)start);

    #if defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vb0 = _mm_set1_epi16(u0), vo0 = _mm_setzero_si128(), vx0 = _mm_setzero_si128(),
                                    vo1 = _mm_setzero_si128(), vx1 = _mm_setzero_si128(); __m128i vs = _mm_set1_epi16(start);
  for(ip = in; ip != in+(n&~(16-1)); ip += 16) {            PREFETCH(ip+512,0);
    __m128i vi0 = _mm_loadu_si128((__m128i *) ip);
    __m128i vi1 = _mm_loadu_si128((__m128i *)(ip+8));                                      __m128i v0 = mm_delta_epi16(vi0,vs); vs = vi0; v0 = mm_zzage_epi16(v0);
                                                                                           __m128i v1 = mm_delta_epi16(vi1,vs); vs = vi1; v1 = mm_zzage_epi16(v1);
    vo0 = _mm_or_si128(vo0, v0);
    vo1 = _mm_or_si128(vo1, v1);
    vx0 = _mm_or_si128(vx0, _mm_xor_si128(v0, vb0));
    vx1 = _mm_or_si128(vx1, _mm_xor_si128(v1, vb0));
  }                                                                                         start = mm_cvtsi128_si16(_mm_srli_si128(vs,14));
  vo0 = _mm_or_si128(vo0, vo1); o = mm_hor_epi16(vo0);
  vx0 = _mm_or_si128(vx0, vx1); x = mm_hor_epi16(vx0);
    #else
  ip = in; //uint16_t u; o=x=0; BITDE(uint16_t, in, n, 0, o |= u; x |= u^u0); //BITZENC(uint16_t, int16_t, 16, in, n, o |= u,x &= u^u0);
    #endif
  for(;ip != in+n; ip++) {
    uint16_t u = zigzagenc16((int)ip[0] - (int)start); //int i = ((int)(*ip) - (int)start); i = (i << 1) ^ (i >> 15);
    start = *ip;
    o |= u;
    x |= u ^ u0;
  }
  if(px) *px = x;
  return o;
}

uint32_t bitz32(unsigned *in, unsigned n, uint32_t *px, unsigned start) {
  uint32_t o, x, *ip; uint32_t u0 = zigzagenc32((int)in[0] - (int)start);
    #ifdef __AVX2__
   __m256i vb0 = _mm256_set1_epi32(u0), vo0 = _mm256_setzero_si256(), vx0 = _mm256_setzero_si256(),
                                         vo1 = _mm256_setzero_si256(), vx1 = _mm256_setzero_si256(); __m256i vs = _mm256_set1_epi32(start);
  for(ip = in; ip != in+(n&~(16-1)); ip += 16) {                                PREFETCH(ip+512,0);
    __m256i vi0 = _mm256_loadu_si256((__m256i *) ip);
    __m256i vi1 = _mm256_loadu_si256((__m256i *)(ip+8));                        __m256i v0 = mm256_delta_epi32(vi0,vs); vs = vi0; v0 = mm256_zzage_epi32(v0);
                                                                                __m256i v1 = mm256_delta_epi32(vi1,vs); vs = vi1; v1 = mm256_zzage_epi32(v1);
    vo0 = _mm256_or_si256(vo0, v0);
    vo1 = _mm256_or_si256(vo1, v1);
    vx0 = _mm256_or_si256(vx0, _mm256_xor_si256(v0, vb0));
    vx1 = _mm256_or_si256(vx1, _mm256_xor_si256(v1, vb0));
  }                                                                             start = (unsigned)_mm256_extract_epi32(vs, 7);
  vo0 = _mm256_or_si256(vo0, vo1); o = mm256_hor_epi32(vo0);
  vx0 = _mm256_or_si256(vx0, vx1); x = mm256_hor_epi32(vx0);

    #elif defined(__SSE2__) || defined(__ARM_NEON)
   __m128i vb0 = _mm_set1_epi32(u0),
           vo0 = _mm_setzero_si128(), vx0 = _mm_setzero_si128(),
           vo1 = _mm_setzero_si128(), vx1 = _mm_setzero_si128();                __m128i vs = _mm_set1_epi32(start);
  for(ip = in; ip != in+(n&~(8-1)); ip += 8) {                                  PREFETCH(ip+512,0);
    __m128i vi0 = _mm_loadu_si128((__m128i *) ip);
    __m128i vi1 = _mm_loadu_si128((__m128i *)(ip+4));                           __m128i v0 = mm_delta_epi32(vi0,vs); vs = vi0; v0 = mm_zzage_epi32(v0);
                                                                                __m128i v1 = mm_delta_epi32(vi1,vs); vs = vi1; v1 = mm_zzage_epi32(v1);
    vo0 = _mm_or_si128(vo0, v0);
    vo1 = _mm_or_si128(vo1, v1);
    vx0 = _mm_or_si128(vx0, _mm_xor_si128(v0, vb0));
    vx1 = _mm_or_si128(vx1, _mm_xor_si128(v1, vb0));
  }                                                                             start = mm_cvtsi128_si16(_mm_srli_si128(vs,12));
  vo0 = _mm_or_si128(vo0, vo1); o = mm_hor_epi32(vo0);
  vx0 = _mm_or_si128(vx0, vx1); x = mm_hor_epi32(vx0);
    #else
  ip = in; o = x = 0; //uint32_t u; BITDE(uint32_t, in, n, 0, o |= u; x |= u^u0);
    #endif
  for(;ip != in+n; ip++) {
    uint32_t u = zigzagenc32((int)ip[0] - (int)start); start = *ip; //((int)(*ip) - (int)start);    //i = (i << 1) ^ (i >> 31);
    o |= u;
    x |= u ^ u0;
  }
  if(px) *px = x;
  return o;
}

uint8_t  bitzenc8( uint8_t  *in, unsigned n, uint8_t  *out, uint8_t  start, uint8_t  mindelta) { uint8_t  o,x,u,*op = out; BITZENC(uint8_t,  int8_t,  8,in, n, o |= u; *op++ = u); return o; }
uint16_t bitzenc16(uint16_t *in, unsigned n, uint16_t *out, uint16_t start, uint16_t mindelta) { uint16_t o,x,u,*op = out; BITZENC(uint16_t, int16_t,16,in, n, o |= u; *op++ = u); return o; }
uint64_t bitzenc64(uint64_t *in, unsigned n, uint64_t *out, uint64_t start, uint64_t mindelta) { uint64_t o,x,u,*op = out; BITZENC(uint64_t, int64_t,64,in, n, o |= u; *op++ = u); return o; }
uint32_t bitzenc32(uint32_t *in, unsigned n, uint32_t *out, uint32_t start, uint32_t mindelta) {
    #if defined(__SSE2__) || defined(__ARM_NEON)
  unsigned *ip,b,*op = out;
  __m128i bv = _mm_setzero_si128(), vs = _mm_set1_epi32(start), dv;
  for(ip = in; ip != in+(n&~(4-1)); ip += 4,op += 4) {
    __m128i iv = _mm_loadu_si128((__m128i *)ip);
    dv = mm_delta_epi32(iv,vs); vs = iv;
    dv = mm_zzage_epi32(dv);
    bv = _mm_or_si128(bv, dv);
    _mm_storeu_si128((__m128i *)op, dv);
  }
  start = (unsigned)_mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  b = mm_hor_epi32(bv);
  while(ip != in+n) {
    int x = ((int)(*ip)-(int)start);
    x = (x << 1) ^ (x >> 31);
    start = *ip++;
    b |= x;
    *op++ = x;
  }
    #else
  uint32_t b = 0, *op = out,x;
  BITZENC(uint32_t, int32_t, 32,in, n, b |= x; *op++ = x);
    #endif
  return bsr32(b);
}

#define ZD(_t_, _usize_, i) { _t_ _z = _ip[i]; _ip[i] = (start += TEMPLATE2(zigzagdec, _usize_)(_z)); }
#define BITZDEC(_t_, _usize_, _in_, _n_) { _t_ *_ip;\
  for(_ip = _in_; _ip != _in_+(_n_&~(4-1)); _ip += 4) { ZD(_t_, _usize_, 0); ZD(_t_, _usize_, 1); ZD(_t_, _usize_, 2); ZD(_t_, _usize_, 3); }\
  for(;_ip != _in_+_n_;_ip++) ZD(_t_, _usize_, 0);\
}

void bitzdec8( uint8_t  *p, unsigned n, uint8_t  start) { BITZDEC(uint8_t,  8, p, n); }
void bitzdec64(uint64_t *p, unsigned n, uint64_t start) { BITZDEC(uint64_t, 64,p, n); }

void bitzdec16(uint16_t *p, unsigned n, uint16_t start) {
    #if defined(__SSSE3__) || defined(__ARM_NEON)
  __m128i vs = _mm_set1_epi16(start); //, c1 = _mm_set1_epi32(1), cz = _mm_setzero_si128();
  uint16_t *ip;
  for(ip = p; ip != p+(n&~(8-1)); ip += 8) {
    __m128i iv =  _mm_loadu_si128((__m128i *)ip);
    iv = mm_zzagd_epi16(iv);
    vs = mm_scan_epi16(iv, vs);
    _mm_storeu_si128((__m128i *)ip, vs);
  }
  start = (uint16_t)_mm_cvtsi128_si32(_mm_srli_si128(vs,14));
  while(ip != p+n) {
    uint16_t z = *ip;
    *ip++ = (start += (z >> 1 ^ -(z & 1)));
  }
    #else
  BITZDEC(uint16_t, 16, p, n);
    #endif
}

void bitzdec32(unsigned *p, unsigned n, unsigned start) {
    #ifdef __AVX2__
  __m256i vs = _mm256_set1_epi32(start); //, zv = _mm256_setzero_si256()*/; //, c1 = _mm_set1_epi32(1), cz = _mm_setzero_si128();
  unsigned *ip;
  for(ip = p; ip != p+(n&~(8-1)); ip += 8) {
    __m256i iv =  _mm256_loadu_si256((__m256i *)ip);
    iv = mm256_zzagd_epi32(iv);
    vs = mm256_scan_epi32(iv,vs);
    _mm256_storeu_si256((__m256i *)ip, vs);
  }
  start = (unsigned)_mm256_extract_epi32(_mm256_srli_si256(vs,12), 4);
  while(ip != p+n) {
    unsigned z = *ip;
    *ip++ = (start += (z >> 1 ^ -(z & 1)));
  }
    #elif defined(__SSE2__) || defined(__ARM_NEON)
  __m128i vs = _mm_set1_epi32(start); //, c1 = _mm_set1_epi32(1), cz = _mm_setzero_si128();
  unsigned *ip;
  for(ip = p; ip != p+(n&~(4-1)); ip += 4) {
    __m128i iv =  _mm_loadu_si128((__m128i *)ip);
    iv = mm_zzagd_epi32(iv);
    vs = mm_scan_epi32(iv, vs);
    _mm_storeu_si128((__m128i *)ip, vs);
  }
  start = (unsigned)_mm_cvtsi128_si32(_mm_srli_si128(vs,12));
  while(ip != p+n) {
    unsigned z = *ip;
    *ip++ = (start += zigzagdec32(z));
  }
    #else
  BITZDEC(uint32_t, 32, p, n);
    #endif
}

//----------------------- XOR : return max. bits ---------------------------------
#define XE(i) x = _ip[i] ^ start; start = _ip[i]
#define BITXENC(_t_, _in_, _n_, _act_) { _t_ *_ip;\
  for(_ip = _in_; _ip != _in_+(_n_&~(4-1)); _ip += 4) { XE(0);_act_; XE(1);_act_; XE(2);_act_; XE(3);_act_; }\
  for(        ; _ip != _in_+ _n_;         _ip++   ) { XE(0);_act_; }\
}
uint8_t  bitxenc8( uint8_t  *in, unsigned n, uint8_t  *out, uint8_t  start) { uint8_t  b = 0,*op = out,x; BITXENC(uint8_t,  in, n, b |= x; *op++ = x); return b; }
uint16_t bitxenc16(uint16_t *in, unsigned n, uint16_t *out, uint16_t start) { uint16_t b = 0,*op = out,x; BITXENC(uint16_t, in, n, b |= x; *op++ = x); return b; }
uint32_t bitxenc32(uint32_t *in, unsigned n, uint32_t *out, uint32_t start) { uint32_t b = 0,*op = out,x; BITXENC(uint32_t, in, n, b |= x; *op++ = x); return b; }
uint64_t bitxenc64(uint64_t *in, unsigned n, uint64_t *out, uint64_t start) { uint64_t b = 0,*op = out,x; BITXENC(uint64_t, in, n, b |= x; *op++ = x); return b; }

#define XD(i) _ip[i] = (start ^= _ip[i])
#define BITXDEC(_t_, _in_, _n_) { _t_ *_ip, _x;\
  for(_ip = _in_;_ip != _in_+(_n_&~(4-1)); _ip += 4) { XD(0); XD(1); XD(2); XD(3); }\
  for(        ;_ip != _in_+ _n_        ; _ip++   )   XD(0);\
}

void bitxdec8( uint8_t  *p, unsigned n, uint8_t  start) { BITXDEC(uint8_t,  p, n); }
void bitxdec16(uint16_t *p, unsigned n, uint16_t start) { BITXDEC(uint16_t, p, n); }
void bitxdec32(uint32_t *p, unsigned n, uint32_t start) { BITXDEC(uint32_t, p, n); }
void bitxdec64(uint64_t *p, unsigned n, uint64_t start) { BITXDEC(uint64_t, p, n); }

//-------------- For : calc max. bits, min,max value ------------------------
#define FM(i) mi = _ip[i] < mi?_ip[i]:mi; mx = _ip[i] > mx?_ip[i]:mx
#define BITFM(_t_, _in_,_n_) { _t_ *_ip; \
  for(_ip = _in_, mi = mx = *_ip; _ip != _in_+(_n_&~(4-1)); _ip += 4) { FM(0); FM(1); FM(2); FM(3); }\
  for(;_ip != _in_+_n_; _ip++) FM(0);\
}

uint8_t  bitfm8( uint8_t  *in, unsigned n, uint8_t   *px, uint8_t  *pmin) { uint8_t  mi,mx; BITFM(uint8_t,  in, n); *pmin = mi; if(px) *px = 0; return mx - mi; }
uint16_t bitfm16(uint16_t *in, unsigned n, uint16_t  *px, uint16_t *pmin) { uint16_t mi,mx; BITFM(uint16_t, in, n); *pmin = mi; if(px) *px = 0; return mx - mi; }
uint32_t bitfm32(uint32_t *in, unsigned n, uint32_t  *px, uint32_t *pmin) { uint32_t mi,mx; BITFM(uint32_t, in, n); *pmin = mi; if(px) *px = 0; return mx - mi; }
uint64_t bitfm64(uint64_t *in, unsigned n, uint64_t  *px, uint64_t *pmin) { uint64_t mi,mx; BITFM(uint64_t, in, n); *pmin = mi; if(px) *px = 0; return mx - mi; }

//----------- Lossy floating point conversion: pad the trailing mantissa bits with zero bits according to the relative error e (ex. 0.00001)  ----------

  #ifdef USE_FLOAT16
// https://clang.llvm.org/docs/LanguageExtensions.html#half-precision-floating-point
#define ctof16(_cp_) (*(_Float16 *)(_cp_))

static inline _Float16 _fppad16(_Float16 d, float e, int lg2e) {
  uint16_t u, du = ctou16(&d);
  int b = (du>>10 & 0x1f)-15; // mantissa=10 bits, exponent=5bits, bias=15
  if ((b = 12 - b - lg2e) <= 0) return d;
  b = (b > 10) ? 10 : b;
  do { u = du & (~((1u<<(--b))-1)); } while (fabs((ctof16(&u) - d)/d) > e);
  return ctof16(&u);
}

void fppad16(_Float16 *in, size_t n, _Float16 *out, float e) { int lg2e = -log(e)/log(2.0); _Float16 *ip; for (ip = in; ip < in+n; ip++,out++) *out = _fppad16(*ip, e, lg2e); }
  #endif

//do u = du & (~((1u<<(--b))-1)); while(fabsf((ctof32(&u) - d)/d) > e);
#define OP(t,s) sign = du & ((t)1<<(s-1)); du &= ~((t)1<<(s-1));  d = TEMPLATE2(ctof,s)(&du);\
  do u = du & (~(((t)1<<(--b))-1)); while(d - TEMPLATE2(ctof,s)(&u) > e*d);\
  u |= sign;\
  return TEMPLATE2(ctof,s)(&u);

static inline float _fppad32(float d, float e, int lg2e) {
  uint32_t u, du = ctou32(&d), sign;
  int      b = (du>>23 & 0xff)-0x7e;
  if((b = 25 - b - lg2e) <= 0)
    return d;
  b    = b > 23?23:b;
  sign = du & (1<<31);
  du  &= 0x7fffffffu;
  d    = ctof32(&du);
  do u = du & (~((1u<<(--b))-1)); while(d - ctof32(&u) > e*d);
  u |= sign;
  return ctof32(&u);
}

void fppad32(float *in, size_t n, float *out, float e) { int lg2e = -log(e)/log(2.0); float *ip; for(ip = in; ip < in+n; ip++,out++) *out = _fppad32(*ip, e, lg2e); }

static inline double _fppad64(double d, double e, int lg2e) { if(isnan(d)) return d;
  union    r { uint64_t u; double d; } u,du; du.d = d; //if((du.u>>52)==0xfff)
  uint64_t sign;
  int      b = (du.u>>52 & 0x7ff)-0x3fe;
  if((b = 54 - b - lg2e) <= 0)
    return d;
  b = b > 52?52:b;
  sign = du.u & (1ull<<63); du.u &= 0x7fffffffffffffffull;
  int _b = b;
  for(;;) { if((_b -= 8) <= 0) break; u.u = du.u & (~((1ull<<_b)-1)); if(d - u.d <= e*d) break; b = _b; }
  do u.u = du.u & (~((1ull<<(--b))-1)); while(d - u.d > e*d);
  u.u |= sign;
  return ctof64(&u);
}

void fppad64(double *in, size_t n, double *out, double e) { int lg2e = -log(e)/log(2.0); double *ip; for(ip = in; ip < in+n; ip++,out++) *out = _fppad64(*ip, e, lg2e); }

