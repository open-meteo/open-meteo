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
//  "TurboPFor: Integer Compression" Turbo PFor/PforDelta

#ifdef GUARDED


#ifndef USIZE //--------------------------------- Functions ----------------------------------------------------------------------
#pragma warning( disable : 4005)
#pragma warning( disable : 4090)
#pragma warning( disable : 4068)

#define VINT_IN
#define BITUTIL_IN
#include "conf.h"
#include "bitpack.h"
#include "vint.h"
#include "bitutil.h"
#include "vp4.h"

#undef P4DELTA
#define PAD8(_x_) ( (((_x_)+8-1)/8) )

#define HYBRID 1 // Hybrid TurboPFor : 0=fixed bit packing, 1=fixed BP+Variable byte

  #if !defined(SSE2_ON) && !defined(AVX2_ON)
#define _P4BITS _p4bits
#define  P4BITS _p4bits
#define _P4ENC   _p4enc
#define  P4ENC    p4enc
#define  P4NENC   p4nenc
#define  BITPACK  bitpack
#define  BITDELTA bitdienc
#define USIZE 8
#include "vp4c.c"
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"
#define USIZE 64
#include "vp4c.c"

#define P4DELTA 0  // p4d functions
#define  P4DENC   p4denc
#define  P4NENC   p4ndenc
#define  P4NENCS  p4denc
#define USIZE 8
#include "vp4c.c"
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"
#define USIZE 64
#include "vp4c.c"

#define P4DELTA 1  // p4d1 functions
#define  P4DENC   p4d1enc
#define  P4NENC   p4nd1enc
#define  P4NENCS  p4d1enc
#define USIZE 8
#include "vp4c.c"
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"
#define USIZE 64
#include "vp4c.c"

#define  BITDELTA  bitzenc // // p4z functions
#define  P4DENC   p4zenc
#define  P4NENC   p4nzenc
#define  P4NENCS  p4zenc
#define USIZE 8
#include "vp4c.c"
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"
#define USIZE 64
#include "vp4c.c"

#undef P4DELTA
#define  BITDELTA bitdienc

#define HYBRID 0             // Direct access
#define  P4BITS _p4bitsx
#define _P4BITS _p4bitsx
#define _P4ENC  _p4encx
#define  P4ENC   p4encx
#define  P4NENC  p4nencx
#define USIZE 8
#include "vp4c.c"
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"
#define USIZE 64
#include "vp4c.c"


#undef _P4ENC
#undef  P4ENC
#undef  BITPACK

#define P4NDENC(in, n, out, _csize_, _usize_, _p4c_) { if(!n) return 0;\
  unsigned char *op = out; \
  start = *in++;\
  TEMPLATE2(vbxput, _usize_)(op, start);\
  for(n--,ip = in; ip != in + (n&~(_csize_-1)); ) { PREFETCH(ip+512,0);\
                         op = TEMPLATE2(_p4c_, _usize_)(ip, _csize_, op, start); ip += _csize_; start = ip[-1];\
  } if(n&=(_csize_-1)) { op = TEMPLATE2(_p4c_, _usize_)(ip, n,       op, start); }\
  return op - out;\
}

#define P4NDDEC(in, n, out, _csize_, _usize_, _p4d_) { if(!n) return 0;\
  unsigned char *ip = in;\
  TEMPLATE2(vbxget, _usize_)(ip, start);\
  for(*out++ = start,--n,op = out; op != out+(n&~(_csize_-1)); ) {                              PREFETCH(ip+512,0);\
                         ip = TEMPLATE2(_p4d_, _usize_)(ip, _csize_, op, start); op += _csize_; start = op[-1];\
  } if(n&=(_csize_-1)) { ip = TEMPLATE2(_p4d_, _usize_)(ip, n,       op, start); }\
  return ip - in;\
}

unsigned char *p4senc16(uint16_t *in, unsigned n, unsigned char *out, uint16_t x) { uint16_t pa[128+32],eq, mdelta = bitdi16(in, n, 0, x); vbput16(out, mdelta); bitdienc16(in, n, pa, x, mdelta); return p4enc16(pa, n, out);}
unsigned char *p4senc32(uint32_t *in, unsigned n, unsigned char *out, uint32_t x) { uint32_t pa[128+32],eq, mdelta = bitdi32(in, n, 0, x); vbput32(out, mdelta); bitdienc32(in, n, pa, x, mdelta); return p4enc32(pa, n, out);}
unsigned char *p4senc64(uint64_t *in, unsigned n, unsigned char *out, uint64_t x) { uint64_t pa[128+64],eq, mdelta = bitdi64(in, n, 0, x); vbput64(out, mdelta); bitdienc64(in, n, pa, x, mdelta); return p4enc64(pa, n, out);}

unsigned char *p4sdec16(unsigned char *in, unsigned n, uint16_t *out, uint16_t x) { uint16_t mdelta; vbget16(in, mdelta); in = p4dec16(in, n, out); bitdidec16(out, n, x, mdelta); return in; }
unsigned char *p4sdec32(unsigned char *in, unsigned n, uint32_t *out, uint32_t x) { uint32_t mdelta; vbget32(in, mdelta); in = p4dec32(in, n, out); bitdidec32(out, n, x, mdelta); return in; }
unsigned char *p4sdec64(unsigned char *in, unsigned n, uint64_t *out, uint64_t x) { uint64_t mdelta; vbget64(in, mdelta); in = p4dec64(in, n, out); bitdidec64(out, n, x, mdelta); return in; }

size_t p4nsenc16(uint16_t *in, size_t n, unsigned char *out) { uint16_t  *ip,start; P4NDENC(in, n, out, 128, 16, p4senc); }
size_t p4nsenc32(uint32_t *in, size_t n, unsigned char *out) { uint32_t  *ip,start; P4NDENC(in, n, out, 128, 32, p4senc); }
size_t p4nsenc64(uint64_t *in, size_t n, unsigned char *out) { uint64_t  *ip,start; P4NDENC(in, n, out, 128, 64, p4senc); }

size_t p4nsdec16(unsigned char *in, size_t n, uint16_t *out) { uint16_t  *op,start; P4NDDEC(in, n, out, 128, 16, p4sdec); }
size_t p4nsdec32(unsigned char *in, size_t n, uint32_t *out) { uint32_t  *op,start; P4NDDEC(in, n, out, 128, 32, p4sdec); }
size_t p4nsdec64(unsigned char *in, size_t n, uint64_t *out) { uint64_t  *op,start; P4NDDEC(in, n, out, 128, 64, p4sdec); }
#undef _P4BITS
  #elif defined(__AVX2__)
#define  BITDELTA bitdienc
#define HYBRID 1
#define P4BITS _p4bits
#define VSIZE 256

#define _P4ENC    _p4enc256v
#define  P4ENC     p4enc256v
#define  P4NENC    p4nenc256v
#define  P4NENCS   p4enc
#define  BITPACK   bitpack256v
#define USIZE 32
#include "vp4c.c"

#define P4DELTA 0
#define  P4DENC    p4denc256v
#define  P4NENC    p4ndenc256v
#define  P4NENCS   p4denc
#include "vp4c.c"

#define P4DELTA 1
#define  P4DENC    p4d1enc256v
#define  P4NENC    p4nd1enc256v
#define  P4NENCS   p4d1enc
#include "vp4c.c"
#undef P4DELTA

#define P4DELTA 0
#define  BITDELTA  bitzenc
#define  P4DENC    p4zenc256v
#define  P4NENC    p4nzenc256v
#define  P4NENCS   p4zenc
#include "vp4c.c"

#undef  _P4ENC
#undef   P4ENC
#undef   BITPACK
  #elif defined(__SSE2__) || defined(__ARM_NEON) //--------------------------------------------------
#define  BITDELTA bitdienc
#define HYBRID 1
#define P4BITS _p4bits
#define USIZE 32

#define VSIZE 128
#define _P4ENC    _p4enc128v
#define  P4ENC     p4enc128v
#define  P4NENCS   p4enc
#define  P4NENC    p4nenc128v
#define  BITPACK   bitpack128v
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"
#define USIZE 64
#include "vp4c.c"

#define P4DELTA 0
#define  P4DENC    p4denc128v
#define  P4NENC    p4ndenc128v
#define  P4NENCS   p4denc
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"

#define P4DELTA 1
#define  P4DENC    p4d1enc128v
#define  P4NENC    p4nd1enc128v
#define  P4NENCS   p4d1enc
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"

#define P4DELTA 0
#define  BITDELTA  bitzenc
#define  P4DENC    p4zenc128v
#define  P4NENC    p4nzenc128v
#define  P4NENCS   p4zenc
#define USIZE 16
#include "vp4c.c"
#define USIZE 32
#include "vp4c.c"

/*#define  BITDELTA bitdienc
#define VSIZE 256
#define _P4ENC    _p4enc256w
#define  P4ENC     p4enc256w
#define  P4NENCS   p4encw
#define  P4NENC    p4nenc256w
#define  BITPACK   bitpack256w
#include "vp4c.c"*/
  #endif

#undef P4DELTA
#undef  _P4ENC
#undef   P4ENC
#undef   BITPACK

#else //------------------------------------------ Templates ---------------------------------------------------------------
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wparentheses"

#pragma GCC push_options
#pragma GCC optimize ("align-functions=16")

#define uint_t TEMPLATE3(uint, USIZE, _t)

  #ifdef VSIZE
#define CSIZE VSIZE
  #else
#define CSIZE 128
  #endif

  #ifndef P4DELTA

    #ifdef _P4BITS
unsigned TEMPLATE2(_P4BITS, USIZE)(uint_t *__restrict in, unsigned n, unsigned *pbx) {
      #if HYBRID > 0 && USIZE >= 16
    // OM EDIT: added `+16` on both sides to prevent a invalid stack access
  unsigned _vb[USIZE*2+64+16] = {0}, *vb=&_vb[USIZE+16];
      #endif
  unsigned cnt[USIZE+8] = {0}, x, bx, bmp8=(n+7)/8;
  uint_t *ip, u=0, a = in[0];
  int b,i,ml,l,fx=0,vv,eq=0;

  #define CNTE(i) { ++cnt[TEMPLATE2(bsr, USIZE)(ip[i])], u |= ip[i]; eq += (ip[i] == a); }
  for(ip = in; ip != in+(n&~3); ip+=4) { CNTE(0); CNTE(1); CNTE(2); CNTE(3); }
  for(;ip != in+n;ip++) CNTE(0);

  b  = TEMPLATE2(bsr, USIZE)(u);
      #if HYBRID > 0
  if(eq == n && a) { *pbx = USIZE+2;
        #if USIZE == 64
    if(b == USIZE-1) b = USIZE;
        #endif
    return b;
  }
    #endif
  bx = b;
  ml = PAD8(n*b)+1; x = cnt[b];

    #if HYBRID > 0 && USIZE >= 16
  #define VBB(_x_,_b_) vb[_b_-7]+=_x_; vb[_b_-15]+=_x_*2; vb[_b_-19]+=_x_*3; vb[_b_-25]+=_x_*4;
  vv = x; VBB(x,b);
    #else
  ml -= 2+bmp8;
    #endif
  for(i = b-1; i >= 0; --i) {
    int fi,v;
      #if HYBRID > 0 && USIZE >= 16
    v = PAD8(n*i) + 2 + x + vv;
    l = PAD8(n*i) + 2+bmp8 + PAD8(x*(bx-i));
    x  += cnt[i];
    vv += cnt[i]+vb[i];
    VBB(cnt[i],i);
    fi = l < ml;  ml = fi?l:ml; b = fi?i:b; fx=fi?0:fx;
    fi = v < ml;  ml = fi?v:ml; b = fi?i:b; fx=fi?1:fx;
      #else
    l = PAD8(n*i) + PAD8(x*(bx-i));
    x += cnt[i];
    fi = l < ml;
    ml = fi?l:ml; b = fi?i:b;
      #endif
  }                                             //fx = 0;
    #if HYBRID > 0 && USIZE >= 16
  *pbx = fx?(USIZE+1):(bx - b);
      #if USIZE == 64
  if(b == USIZE-1) { b = USIZE; *pbx = 0; }
      #endif
    #else
  *pbx = bx - b;
    #endif
  return b;
}
  #endif


unsigned char *TEMPLATE2(_P4ENC, USIZE)(uint_t *__restrict in, unsigned n, unsigned char *__restrict out, unsigned b, unsigned bx) {
  uint_t             msk =  (1ull << b)-1, _in[P4D_MAX+32]={0}, inx[P4D_MAX+32]={0},a,ax;
  unsigned long long xmap[P4D_MAX/64] = {0};
  unsigned           miss[P4D_MAX]={0},i, xn, c;                                    //, eq=0,eqx=0;
  unsigned char *_out = out;

  if(!bx)
    return TEMPLATE2(BITPACK, USIZE)(in, n, out, b);
    #if HYBRID > 0
  if(bx == USIZE+2) {
    TEMPLATE2(ctou, USIZE)(out) = in[0];
    return out+((b+7)/8);
  }
    #endif
  #define MISS { miss[xn] = i; xn += in[i] > msk; _in[i] = in[i] & msk; i++; } //eq+= (_in[i] == a); } a = in[0] & msk;
  for(xn = i = 0; i != n&~3; ) { MISS; MISS; MISS; MISS; }
  while(i != n) MISS;
                                                                                //ax = inx[miss[0]] >> b;
  for(i = 0; i != xn; ++i) {
    c           = miss[i];
    xmap[c>>6] |= (1ull << (c&0x3f));
    inx[i]      = in[c] >> b;                                                   // eqx        += inx[i] == a;
  }

    #if HYBRID > 0 && USIZE >= 16
  if(bx <= USIZE) {
    #endif
    for(i = 0; i < (n+63)/64; i++) ctou64(out+i*8) = xmap[i]; out += PAD8(n);   //if(eqx == xn && bx) { out[-1] |=0x80; TEMPLATE2(ctou, USIZE)(out)=ax; out += (bx+7)/8; } else
    out = TEMPLATE2(bitpack, USIZE)(inx, xn, out, bx);                          //if(eq == n && b) { out[-1]|= 0x80; TEMPLATE2(ctou, USIZE)(out)=a; out += (b+7)/8; } else
    out = TEMPLATE2(BITPACK, USIZE)(_in, n,  out, b);
    #if HYBRID > 0 && USIZE >= 16
  }
  else {
    *out++ = xn;                                                                //if(b && eq == n) { *out++ = 0x80; TEMPLATE2(ctou, USIZE)(out) = _in[0]; out += (b+7)/8; } else { *out++ = 0;
      out = TEMPLATE2(BITPACK, USIZE)(_in, n, out, b);

    out = TEMPLATE2(vbenc, USIZE)(inx, xn, out);
    for(i = 0; i != xn; ++i) *out++ = miss[i];
  }
    #endif
  return out;
}

unsigned char *TEMPLATE2(P4ENC, USIZE)(uint_t *__restrict in, unsigned n, unsigned char *__restrict out) { unsigned bx, b;
  if(!n) return out;
  b = TEMPLATE2(P4BITS, USIZE)(in, n, &bx);
  TEMPLATE2(P4HVE, USIZE)(out,b,bx);
  out = TEMPLATE2(_P4ENC, USIZE)(in, n, out, b, bx);
  return out;
}

size_t TEMPLATE2(P4NENC, USIZE)(uint_t *__restrict in, size_t n, unsigned char *__restrict out) { if(!n) return 0;
  unsigned char *op = out;
  uint_t *ip;

  for(ip = in; ip != in+(n&~(CSIZE-1)); ip += CSIZE) { unsigned bx, b;          PREFETCH(ip+512,0);
    b = TEMPLATE2(P4BITS, USIZE)(ip, CSIZE, &bx);
    TEMPLATE2(P4HVE, USIZE)(op,b,bx);
    op = TEMPLATE2(_P4ENC, USIZE)(ip, CSIZE, op, b, bx);
  }
  return TEMPLATE2(p4enc, USIZE)(ip, n&(CSIZE-1), op) - out;
}
    #else
unsigned char *TEMPLATE2(P4DENC, USIZE)(uint_t *__restrict in, unsigned n, unsigned char *__restrict out, uint_t start) {
  uint_t _in[P4D_MAX+8]={0};
  if(!n) return out;
  TEMPLATE2(BITDELTA, USIZE)(in, n, _in, start, P4DELTA);
  return TEMPLATE2(P4ENC, USIZE)(_in, n, out);
}

size_t TEMPLATE2(P4NENC, USIZE)(uint_t *__restrict in, size_t n, unsigned char *__restrict out) {
  unsigned char *op = out;
  uint_t *ip, start = *in++;
  if(!n)
    return 0;

  TEMPLATE2(vbxput, USIZE)(op, start);
  for(ip = in, --n; ip != in+(n&~(CSIZE-1)); ip += CSIZE) { uint_t _in[P4D_MAX+8];unsigned bx, b;           PREFETCH(ip+512,0);
    TEMPLATE2(BITDELTA, USIZE)(ip, CSIZE, _in, start, P4DELTA);
    b = TEMPLATE2(_p4bits, USIZE)(_in, CSIZE, &bx);
    TEMPLATE2(P4HVE, USIZE)(op,b,bx);
    op = TEMPLATE2(_P4ENC, USIZE)(_in, CSIZE, op, b, bx);  // op = TEMPLATE2(P4ENC, USIZE)(_in, CSIZE, op);
    start = ip[CSIZE-1];
  }
  return TEMPLATE2(P4NENCS, USIZE)(ip, n&(CSIZE-1), op, start) - out;
}
    #endif
#pragma clang diagnostic pop
  #endif

#endif
