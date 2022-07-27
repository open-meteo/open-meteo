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
//  "Integer Compression" variable simple "SimpleV"
//  this belongs to the integer compression known as "simple family", like simple-9,simple-16
//  or simple-8b. SimpleV is compressing integers in groups into variable word size 32, 40 and 64 bits + RLE (run length encoding)
//  SimpleV is faster than simple-16 and compress better than simple-16 or simple-8b.

#ifdef __cplusplus
extern "C" {
#endif

// vsencNN: compress array with n unsigned (NN bits in[n]) values to the buffer out. Return value = end of compressed output buffer out
unsigned char *vsenc8( unsigned char  *__restrict in, size_t n, unsigned char  *__restrict out);
unsigned char *vsenc16(unsigned short *__restrict in, size_t n, unsigned char  *__restrict out);
unsigned char *vsenc32(unsigned       *__restrict in, size_t n, unsigned char  *__restrict out);
unsigned char *vsenc64(uint64_t       *__restrict in, size_t n, unsigned char  *__restrict out);

// vsdecNN: decompress buffer into an array of n unsigned values. Return value = end of compressed input buffer in
unsigned char *vsdec8( unsigned char  *__restrict in, size_t n, unsigned char  *__restrict out);
unsigned char *vsdec16(unsigned char  *__restrict in, size_t n, unsigned short *__restrict out);
unsigned char *vsdec32(unsigned char  *__restrict in, size_t n, unsigned       *__restrict out);
unsigned char *vsdec64(unsigned char  *__restrict in, size_t n, uint64_t       *__restrict out);

#ifdef __cplusplus
}
#endif
