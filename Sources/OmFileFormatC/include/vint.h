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
// "Integer Compression" variable byte include header (scalar TurboVByte+ SIMD TurboByte)
#ifndef _VINT_H_
#define _VINT_H_

#ifdef __cplusplus
extern "C" {
#endif

  #ifdef VINT_IN
#include "conf.h"
//----------------------------------- Variable byte: single value macros (low level) -----------------------------------------------
//------------- 32 bits -------------
extern unsigned char _vtab32_[];
#define _vbxvlen32(_x_) _vtab32_[(unsigned char)(_x_)>>4] // (clz32((_x_) ^ 0xff) - 23) //
#define _vbxlen32(_x_) ((bsr32(_x_|1)+6)/7)

#define _vbxput32(_op_, _x_, _act_) {\
       if(likely((_x_) < (1<< 7))) {        *_op_++ = _x_;                                               _act_;}\
  else if(likely((_x_) < (1<<14))) { ctou16(_op_)   = bswap16((_x_) | 0x8000u);               _op_ += 2; _act_;}\
  else if(likely((_x_) < (1<<21))) {        *_op_++ = _x_ >> 16  | 0xc0u; ctou16(_op_) = _x_; _op_ += 2; _act_;}\
  else if(likely((_x_) < (1<<28))) { ctou32(_op_)   = bswap32((_x_) | 0xe0000000u);              _op_ += 4; _act_;}\
  else                             {        *_op_++ = (unsigned long long)(_x_) >> 32 | 0xf0u; ctou32(_op_) = _x_; _op_ += 4; _act_;}\
}

#define _vbxget32(_ip_, _x_, _act_) do { _x_ = (unsigned)(*_ip_++);\
       if(!(_x_ & 0x80u)) {                                                                      _act_;}\
  else if(!(_x_ & 0x40u)) { _x_ = bswap16(ctou16(_ip_ - 1) & 0xff3fu); _ip_++;                       _act_;}\
  else if(!(_x_ & 0x20u)) { _x_ = (_x_ & 0x1f)<<16 | ctou16(_ip_);                    _ip_ += 2; _act_;}\
  else if(!(_x_ & 0x10u)) { _x_ = bswap32(ctou32(_ip_-1) & 0xffffff0fu);                  _ip_ += 3; _act_;}\
  else                    { _x_ = (unsigned long long)((_x_) & 0x07)<<32 | ctou32(_ip_); _ip_ += 4; _act_;}\
} while(0)

//------------- 64 bits -----------
#define _vbxlen64(_x_)  ((bsr64(_x_)+6)/7)
#define _vbxvlen64(_x_) ((_x_)==0xff?9:clz32((_x_) ^ 0xff) - 23)

#define _vbxput64(_op_, _x_, _act_) {\
       if(likely(_x_ < (1<< 7))) {        *_op_++ = _x_;                                                                                          _act_;}\
  else if(likely(_x_ < (1<<14))) { ctou16(_op_)   =        bswap16(_x_| 0x8000);                                                       _op_ += 2; _act_;}\
  else if(likely(_x_ < (1<<21))) {        *_op_++ =        _x_ >> 16  | 0xc0;      ctou16(_op_) = _x_;                                 _op_ += 2; _act_;}\
  else if(likely(_x_ < (1<<28))) { ctou32(_op_)   =        bswap32(_x_| 0xe0000000);                                                   _op_ += 4; _act_;}\
  else if(       _x_ < 1ull<<35) {        *_op_++ =         _x_ >> 32 | 0xf0;                                      ctou32(_op_) = _x_; _op_ += 4; _act_;}\
  else if(       _x_ < 1ull<<42) { ctou16(_op_)   = bswap16(_x_ >> 32 | 0xf800);                        _op_ += 2; ctou32(_op_) = _x_; _op_ += 4; _act_;}\
  else if(       _x_ < 1ull<<49) {        *_op_++ =         _x_ >> 48 | 0xfc; ctou16(_op_) = _x_ >> 32; _op_ += 2; ctou32(_op_) = _x_; _op_ += 4; _act_;}\
  else if(       _x_ < 1ull<<56) { ctou64(_op_)   = bswap64(_x_       | 0xfe00000000000000ull);                                        _op_ += 8; _act_;}\
  else {                                  *_op_++ =                     0xff;                                      ctou64(_op_) = _x_; _op_ += 8; _act_;}\
}

#define _vbxget64(_ip_, _x_, _act_) do { _x_ = *_ip_++;\
       if(!(_x_ & 0x80)) {                                                                                                _act_;}\
  else if(!(_x_ & 0x40)) { _x_ = bswap16(ctou16(_ip_++-1) & 0xff3f);                                                      _act_;}\
  else if(!(_x_ & 0x20)) { _x_ = (_x_ & 0x1f)<<16 | ctou16(_ip_);                                              _ip_ += 2; _act_;}\
  else if(!(_x_ & 0x10)) { _x_ = bswap32(ctou32(_ip_-1) & 0xffffff0f);                                         _ip_ += 3; _act_;}\
  else if(!(_x_ & 0x08)) { _x_ = (_x_ & 0x07)<<32 | ctou32(_ip_);                                              _ip_ += 4; _act_;}\
  else if(!(_x_ & 0x04)) { _x_ = (unsigned long long)(bswap16(ctou16(_ip_-1)) & 0x7ff) << 32 | ctou32(_ip_+1); _ip_ += 5; _act_;}\
  else if(!(_x_ & 0x02)) { _x_ = (_x_ & 0x03)<<48 |   (unsigned long long)ctou16(_ip_) << 32 | ctou32(_ip_+2); _ip_ += 6; _act_;}\
  else if(!(_x_ & 0x01)) { _x_ = bswap64(ctou64(_ip_-1)) & 0x01ffffffffffffffull;                              _ip_ += 7; _act_;}\
  else                   { _x_ = ctou64(_ip_);                                                                 _ip_ += 8; _act_;}\
} while(0)

#define vbxput64(_op_, _x_) { unsigned long long _x = _x_; _vbxput64(_op_, _x, ;); }
#define vbxput32(_op_, _x_) { register unsigned  _x = _x_; _vbxput32(_op_, _x, ;); }
#define vbxput16(_op_, _x_)   vbxput32(_op_, _x_)
#define vbxput8(  _op_, _x_)  (*_op_++ = _x_)

#define vbxget64(_ip_, _x_) _vbxget64(_ip_, _x_, ;)
#define vbxget32(_ip_, _x_) _vbxget32(_ip_, _x_, ;)
#define vbxget16(_ip_, _x_)  vbxget32(_ip_,_x_)
#define vbxget8(_ip_, _x_)       (_x_ = *_ip_++)
//---------------------------------------------------------------------------
#define VB_SIZE 64
#define VB_MAX 254
#define VB_B2 6
#define VB_B3 3
#define VB_BA3 (VB_MAX - (VB_SIZE/8 - 3))
#define VB_BA2 (VB_BA3 - (1<<VB_B3))

#define VB_OFS1 (VB_BA2 - (1<<VB_B2))
#define VB_OFS2 (VB_OFS1 + (1 << (8+VB_B2)))
#define VB_OFS3 (VB_OFS2 + (1 << (16+VB_B3)))

#define _vblen32(_x_)  ((_x_) < VB_OFS1?1:((_x_) < VB_OFS2?2:((_x_) < VB_OFS3)?3:(bsr32(_x_)+7)/8+1))
#define _vbvlen32(_x_) ((_x_) < VB_OFS1?1:((_x_) < VB_BA2?2:((_x_) < VB_BA3)?3:(_x_-VB_BA3)))

#define _vbput32(_op_, _x_, _act_) {\
  if(likely((_x_) < VB_OFS1)){ *_op_++ = (_x_);                                                                 _act_;}\
  else if  ((_x_) < VB_OFS2) { ctou16(_op_) = bswap16((VB_OFS1<<8)+((_x_)-VB_OFS1));             _op_  += 2; /*(_x_) -= VB_OFS1; *_op_++ = VB_OFS1 + ((_x_) >> 8); *_op_++ = (_x_);*/ _act_; }\
  else if  ((_x_) < VB_OFS3) { *_op_++ = VB_BA2 + (((_x_) -= VB_OFS2) >> 16); ctou16(_op_) = (_x_); _op_  += 2;  _act_;}\
  else { unsigned _b = (bsr32((_x_))+7)/8; *_op_++ = VB_BA3 + (_b - 3);    ctou32(_op_) = (_x_); _op_  += _b; _act_;}\
}

#define _vbget32(_ip_, _x_, _act_) do { _x_ = *_ip_++;\
       if(likely(_x_ < VB_OFS1)) { _act_ ;}\
  else if(likely(_x_ < VB_BA2))  { _x_ = /*bswap16(ctou16(_ip_-1))*/ ((_x_<<8) + (*_ip_)) + (VB_OFS1 - (VB_OFS1 <<  8)); _ip_++; _act_;} \
  else if(likely(_x_ < VB_BA3))  { _x_ = ctou16(_ip_) + ((_x_ - VB_BA2 ) << 16) + VB_OFS2; _ip_ += 2; _act_;}\
  else { unsigned _b = _x_-VB_BA3; _x_ = ctou32(_ip_) & ((1u << 8 * _b << 24) - 1); _ip_ += 3 + _b; _act_;}\
} while(0)

#define _vblen64(_x_)  _vblen32(_x_)
#define _vbvlen64(_x_) _vbvlen32(_x_)
#define _vbput64(_op_, _x_, _act_) {\
  if(likely((_x_) < VB_OFS1)){ *_op_++ = (_x_);                                                                 _act_;}\
  else if  ((_x_) < VB_OFS2) { ctou16(_op_) = bswap16((VB_OFS1<<8)+((_x_)-VB_OFS1));             _op_  += 2; /*(_x_) -= VB_OFS1; *_op_++ = VB_OFS1 + ((_x_) >> 8); *_op_++ = (_x_);*/ _act_; }\
  else if  ((_x_) < VB_OFS3) { *_op_++ = VB_BA2 + (((_x_) -= VB_OFS2) >> 16); ctou16(_op_) = (_x_); _op_  += 2;  _act_;}\
  else { unsigned _b = (bsr64((_x_))+7)/8; *_op_++ = VB_BA3 + (_b - 3);    ctou64(_op_) = (_x_); _op_  += _b; _act_;}\
}

#define _vbget64(_ip_, _x_, _act_) do { _x_ = *_ip_++;\
       if(likely(_x_ < VB_OFS1)) { _act_ ;}\
  else if(likely(_x_ < VB_BA2))  { _x_ = /*bswap16(ctou16(_ip_-1))*/ ((_x_<<8) + (*_ip_)) + (VB_OFS1 - (VB_OFS1 <<  8)); _ip_++; _act_;} \
  else if(likely(_x_ < VB_BA3))  { _x_ = ctou16(_ip_) + ((_x_ - VB_BA2 ) << 16) + VB_OFS2; _ip_ += 2; _act_;}\
  else { unsigned _b = _x_-VB_BA3; _x_ = ctou64(_ip_) & ((1ull << 8 * _b << 24) - 1); _ip_ += 3 + _b; _act_;}\
} while(0)

#ifdef _WIN32
//#define fgetc_unlocked(_f_)    _fgetc_nolock(_f_)
#define fputc_unlocked(_c_, _f_) fputc(_c_,_f_)
#define fgetc_unlocked(_f_)      fgetc(_f_)
#else
#define fputc_unlocked(_c_, _f_) fputc(_c_,_f_) //_IO_putc_unlocked(_c_,_f_)
#define fgetc_unlocked(_f_)      fgetc(_f_) //_IO_getc_unlocked(_f_)
#endif

#define leb128put(_op_, _x_)  { uint64_t _x = _x_; while(_x > 0x7f) { *_op_++ =      _x & 0x7f;       _x >>= 7; }  *_op_++ =     _x | 0x80; }
#define vbfput32(_f_,  _x_)  ({ uint64_t _x = _x_; while(_x > 0x7f) { fputc_unlocked(_x & 0x7f, _f_); _x >>= 7; } fputc_unlocked(_x | 0x80, _f_); })

#define _leb128get(_ip_, _x_, _act_) { unsigned _sft=0; for(_x_=0;;_sft += 7) { unsigned _c = *_ip_++; _x_ += (_c & 0x7f) << _sft; if(_c >= 0x80) { _act_; break; } } }
#define leb128get(_ip_, _x_) vbgetax(_ip_, _x_, ;)
#define vbfget32(_f_ )  ({ unsigned _sft=0,_x=0; for(;;_sft += 7) { unsigned _c = fgetc_unlocked(_f_); if(_c != EOF) { _x += (_c & 0x7f) << _sft; if(_c & 0x80) break; } else { _x = EOF; break; } } _x; })

//------------- 16 bits -----------
#define _vblen16(_x_) _vblen32(_x_)
#define _vbvlen16(_x_) _vbvlen32(_x_)

#define _vbput16(_op_, _x_, _act_) _vbput32(_op_, _x_, _act_)
#define _vbget16(_ip_, _x_, _act_) _vbget32(_ip_, _x_, _act_)

#define _vblen8(_x_) 1
#define _vbvlen8(_x_) 1
#define _vbput8(_op_, _x_, _act_) { *_op_++ = _x_; _act_; }
#define _vbget8(_ip_, _x_, _act_) { _x_ = *_ip_++; _act_; }
//----------------------------------- Variable byte: single value functions -----------------------------------------------
// ---- Variable byte length after compression
static inline unsigned vblen16(unsigned short x) { return _vblen16(x); }
static inline unsigned vblen32(unsigned       x) { return _vblen32(x); }
static inline unsigned vblen64(uint64_t       x) { return _vblen64(x); }

// ---- Length of compressed value. Input in is the first char of the compressed buffer start (Ex. vbvlen32(in[0]) )
static inline unsigned vbvlen16(unsigned x) { return _vbvlen32(x); }
static inline unsigned vbvlen32(unsigned x) { return _vbvlen32(x); }
static inline unsigned vbvlen64(unsigned x) { return _vbvlen64(x); }

//----- encode/decode 16/32/64 single value and advance output/input pointer
#define vbput64(_op_, _x_) { unsigned long long _x = _x_; _vbput64(_op_, _x, ;); }
#define vbput32(_op_, _x_) { register unsigned  _x = _x_; _vbput32(_op_, _x, ;); }
#define vbput16(_op_, _x_)   vbput32(_op_, _x_)
#define vbput8(_op_, _x_)    (*_op_++ = _x_)

#define vbget64(_ip_, _x_)     _vbget64(_ip_, _x_, ;)
#define vbget32(_ip_, _x_)     _vbget32(_ip_, _x_, ;)
#define vbget16(_ip_, _x_)      vbget32(_ip_,_x_)
#define vbget8(_ip_, _x_)       (_x_ = *_ip_++)
  #endif
//----------------------------- TurboVByte 'vb':Variable byte + SIMD TurboByte 'v8': array functions ----------------------------------------
// Encoding/DEcoding: Return value = end of compressed output/input buffer out/in

//----------------------- Encoding/Decoding unsorted array with n integer values --------------------------
unsigned char *vbenc16(  unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out); //TurboVByte
unsigned char *vbenc32(  unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out);
unsigned char *vbenc64(  uint64_t       *__restrict in, unsigned n, unsigned char  *__restrict out);

//-- Decode
unsigned char *vbdec16(  unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out);
unsigned char *vbdec32(  unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out);
unsigned char *vbdec64(  unsigned char  *__restrict in, unsigned n, uint64_t       *__restrict out);

//-- Get value stored at index idx (idx:0...n-1)
unsigned short vbgetx16(  unsigned char *__restrict in, unsigned idx);
unsigned       vbgetx32(  unsigned char *__restrict in, unsigned idx);
uint64_t       vbgetx64(  unsigned char *__restrict in, unsigned idx);

//-- Search and return index of next value equal to key or n when no key value found
// ex. unsigned idx;unsigned char *ip; for(idx=0,ip=in;;) { if((idx = vgeteq32(&ip, idx, 4321))>=n) break; printf("found at %u ", idx); }
unsigned vbgeteq16( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned short key);
unsigned vbgeteq32( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned       key);
unsigned vbgeteq64( unsigned char **__restrict in, unsigned n, unsigned idx, uint64_t       key);

//---------------------- Delta encoding/decoding sorted array ---------------------------------------------
//-- Increasing integer array. out[i] = out[i-1] + in[i]
unsigned char *vbdenc16( unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *vbdenc32( unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);
unsigned char *vbdenc64( uint64_t       *__restrict in, unsigned n, unsigned char  *__restrict out, uint64_t       start);

unsigned char *vbddec16( unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *vbddec32( unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);
unsigned char *vbddec64( unsigned char  *__restrict in, unsigned n, uint64_t       *__restrict out, uint64_t       start);

//-- Get value stored at index idx (idx:0...n-1)
unsigned short vbdgetx16(  unsigned char *__restrict in, unsigned idx, unsigned short start);
unsigned       vbdgetx32(  unsigned char *__restrict in, unsigned idx, unsigned start);
uint64_t       vbdgetx64(  unsigned char *__restrict in, unsigned idx, uint64_t start);

//-- Search and return index of next value equal to key or n when no key value found
// ex. unsigned idx;unsigned char *ip; for(idx=0,ip=in;;) { if((idx = vgeteq32(&ip, idx, 4321))>=n) break; printf("found at %u ", idx); }
unsigned vbdgetgeq16( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned short *key, unsigned short start);
unsigned vbdgetgeq32( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned       *key, unsigned       start);
unsigned vbdgetgeq64( unsigned char **__restrict in, unsigned n, unsigned idx, uint64_t       *key, uint64_t       start);

//-- Strictly increasing (never remaining constant or decreasing) integer array. out[i] = out[i-1] + in[i] + 1
unsigned char *vbd1enc16(unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *vbd1enc32(unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);
unsigned char *vbd1enc64(uint64_t       *__restrict in, unsigned n, unsigned char  *__restrict out, uint64_t       start);

unsigned char *vbd1dec16(unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *vbd1dec32(unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);
unsigned char *vbd1dec64(unsigned char  *__restrict in, unsigned n, uint64_t       *__restrict out, uint64_t       start);


//-- Get value stored at index idx (idx:0...n-1)
unsigned short vbd1getx16(  unsigned char *__restrict in, unsigned idx, unsigned short start);
unsigned       vbd1getx32(  unsigned char *__restrict in, unsigned idx, unsigned       start);
uint64_t       vbd1getx64(  unsigned char *__restrict in, unsigned idx, uint64_t       start);

//-- Search and return index of next value equal to key or n when no key value found
// ex. unsigned idx;unsigned char *ip; for(idx=0,ip=in;;) { if((idx = vgeteq32(&ip, idx, 4321))>=n) break; printf("found at %u ", idx); }
unsigned vbd1getgeq16( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned short *key, unsigned short start);
unsigned vbd1getgeq32( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned       *key, unsigned       start);
unsigned vbd1getgeq64( unsigned char **__restrict in, unsigned n, unsigned idx, uint64_t       *key, uint64_t       start);

//---------------------- Zigzag encoding/decoding for unsorted integer lists.
unsigned char *vbzenc8(  unsigned char  *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned char start);
unsigned char *vbzenc16( unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *vbzenc32( unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);
unsigned char *vbzenc64( uint64_t       *__restrict in, unsigned n, unsigned char  *__restrict out, uint64_t       start);

unsigned char *vbzdec8(  unsigned char  *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned char  start);
unsigned char *vbzdec16( unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *vbzdec32( unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);
unsigned char *vbzdec64( unsigned char  *__restrict in, unsigned n, uint64_t       *__restrict out, uint64_t       start);

//---------------------- XOR encoding/decoding for unsorted integer lists.
unsigned char *vbxenc8(  unsigned char  *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned char start);
unsigned char *vbxenc16( unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *vbxenc32( unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);
unsigned char *vbxenc64( uint64_t       *__restrict in, unsigned n, unsigned char  *__restrict out, uint64_t       start);

unsigned char *vbxdec8(  unsigned char  *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned char  start);
unsigned char *vbxdec16( unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *vbxdec32( unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);
unsigned char *vbxdec64( unsigned char  *__restrict in, unsigned n, uint64_t       *__restrict out, uint64_t       start);

//---------------------- Delta of delta encoding/decoding for unsorted integer lists.
unsigned char *vbddenc16( unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *vbddenc32( unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);
unsigned char *vbddenc64( uint64_t       *__restrict in, unsigned n, unsigned char  *__restrict out, uint64_t       start);

unsigned char *vbdddec16( unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *vbdddec32( unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);
unsigned char *vbdddec64( unsigned char  *__restrict in, unsigned n, uint64_t       *__restrict out, uint64_t       start);

//-- Get value stored at index idx (idx:0...n-1)
unsigned short vbzgetx16(  unsigned char *__restrict in, unsigned idx, unsigned short start);
unsigned       vbzgetx32(  unsigned char *__restrict in, unsigned idx, unsigned       start);
uint64_t       vbzgetx64(  unsigned char *__restrict in, unsigned idx, uint64_t       start);

//-- Search and return index of next value equal to key or n when no key value found
// ex. unsigned idx;unsigned char *ip; for(idx=0,ip=in;;) { if((idx = vgeteq32(&ip, idx, 4321))>=n) break; printf("found at %u ", idx); }
/*unsigned vbzgeteq15( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned short key, unsigned start);
unsigned vbzgeteq16( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned short key, unsigned start);
unsigned vbzgeteq32( unsigned char **__restrict in, unsigned n, unsigned idx, unsigned       key, unsigned start);
unsigned vbzgeteq64( unsigned char **__restrict in, unsigned n, unsigned idx, uint64_t       key, unsigned start);*/

//-------------------------- TurboByte (SIMD Group varint) --------------------------------------------------------------
unsigned char *v8enc16(  unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out); //TurboByte
unsigned char *v8enc32(  unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out);

unsigned char *v8dec16(  unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out);
unsigned char *v8dec32(  unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out);

//------ delta ---------
unsigned char *v8denc16( unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *v8denc32( unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);

unsigned char *v8ddec16( unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *v8ddec32( unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);

//------ delta 1 -------
unsigned char *v8d1enc16(unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *v8d1enc32(unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);

unsigned char *v8d1dec16(unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *v8d1dec32(unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);

//------- zigzag -------
unsigned char *v8zenc16( unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *v8zenc32( unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);

unsigned char *v8zdec16( unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *v8zdec32( unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);

//------- xor ----------
unsigned char *v8xenc16( unsigned short *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned short start);
unsigned char *v8xenc32( unsigned       *__restrict in, unsigned n, unsigned char  *__restrict out, unsigned       start);

unsigned char *v8xdec16( unsigned char  *__restrict in, unsigned n, unsigned short *__restrict out, unsigned short start);
unsigned char *v8xdec32( unsigned char  *__restrict in, unsigned n, unsigned       *__restrict out, unsigned       start);
//-------------------------- TurboByte Hybrid (SIMD Group varint) + Bitpacking -------------------------------------------
size_t v8nenc16(  uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nenc32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8ndenc16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8ndenc32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8nd1enc16(uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nd1enc32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8nzenc16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nzenc32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8ndec16(  unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8ndec32(  unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nddec16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nddec32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nd1dec16(unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nd1dec32(unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nzdec16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nzdec32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nxdec16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nxdec32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
//-------------
size_t v8nenc128v16(  uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nenc128v32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8ndenc128v16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8ndenc128v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8nd1enc128v16(uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nd1enc128v32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8nzenc128v16( uint16_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nzenc128v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8ndec128v16(  unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8ndec128v32(  unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nddec128v16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nddec128v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nd1dec128v16(unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nd1dec128v32(unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nzdec128v16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nzdec128v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

size_t v8nxdec128v16( unsigned char *__restrict in, size_t n, uint16_t *__restrict out);
size_t v8nxdec128v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
//-------------
size_t v8nenc256v32(  uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8ndenc256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nd1enc256v32(uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nzenc256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);
size_t v8nxenc256v32( uint32_t *__restrict in, size_t n, unsigned char *__restrict out);

size_t v8ndec256v32(  unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t v8nddec256v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t v8nd1dec256v32(unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t v8nzdec256v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);
size_t v8nxdec256v32( unsigned char *__restrict in, size_t n, uint32_t *__restrict out);

#ifdef __cplusplus
}
#endif

#endif
