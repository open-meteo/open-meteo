/**
  Copyright (C) powturbo 2013-2017
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
//  TurboPFor Integer Compression: Bit Packing
#ifdef OPI
#define BITUNBLK64_0(ip, i, op, nb,parm) { \
  OUT(op,i*0+ 0, 0, nb,parm);\
  OUT(op,i*0+ 1, 0, nb,parm);\
  OUT(op,i*0+ 2, 0, nb,parm);\
  OUT(op,i*0+ 3, 0, nb,parm);\
  OUT(op,i*0+ 4, 0, nb,parm);\
  OUT(op,i*0+ 5, 0, nb,parm);\
  OUT(op,i*0+ 6, 0, nb,parm);\
  OUT(op,i*0+ 7, 0, nb,parm);\
  OUT(op,i*0+ 8, 0, nb,parm);\
  OUT(op,i*0+ 9, 0, nb,parm);\
  OUT(op,i*0+10, 0, nb,parm);\
  OUT(op,i*0+11, 0, nb,parm);\
  OUT(op,i*0+12, 0, nb,parm);\
  OUT(op,i*0+13, 0, nb,parm);\
  OUT(op,i*0+14, 0, nb,parm);\
  OUT(op,i*0+15, 0, nb,parm);\
  OUT(op,i*0+16, 0, nb,parm);\
  OUT(op,i*0+17, 0, nb,parm);\
  OUT(op,i*0+18, 0, nb,parm);\
  OUT(op,i*0+19, 0, nb,parm);\
  OUT(op,i*0+20, 0, nb,parm);\
  OUT(op,i*0+21, 0, nb,parm);\
  OUT(op,i*0+22, 0, nb,parm);\
  OUT(op,i*0+23, 0, nb,parm);\
  OUT(op,i*0+24, 0, nb,parm);\
  OUT(op,i*0+25, 0, nb,parm);\
  OUT(op,i*0+26, 0, nb,parm);\
  OUT(op,i*0+27, 0, nb,parm);\
  OUT(op,i*0+28, 0, nb,parm);\
  OUT(op,i*0+29, 0, nb,parm);\
  OUT(op,i*0+30, 0, nb,parm);\
  OUT(op,i*0+31, 0, nb,parm);;\
}

#define BITUNPACK64_0(ip,  op, nb,parm) { \
  BITUNBLK64_0(ip, 0, op, nb,parm);  OPI(op, nb,parm);\
}

#define BITUNBLK64_1(ip, i, op, nb,parm) { uint32_t w0;   w0 = *(uint32_t *)(ip+(i*1+0)*4/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x1, nb,parm);\
  OUT(op,i*32+ 1, (w0 >>  1) & 0x1, nb,parm);\
  OUT(op,i*32+ 2, (w0 >>  2) & 0x1, nb,parm);\
  OUT(op,i*32+ 3, (w0 >>  3) & 0x1, nb,parm);\
  OUT(op,i*32+ 4, (w0 >>  4) & 0x1, nb,parm);\
  OUT(op,i*32+ 5, (w0 >>  5) & 0x1, nb,parm);\
  OUT(op,i*32+ 6, (w0 >>  6) & 0x1, nb,parm);\
  OUT(op,i*32+ 7, (w0 >>  7) & 0x1, nb,parm);\
  OUT(op,i*32+ 8, (w0 >>  8) & 0x1, nb,parm);\
  OUT(op,i*32+ 9, (w0 >>  9) & 0x1, nb,parm);\
  OUT(op,i*32+10, (w0 >> 10) & 0x1, nb,parm);\
  OUT(op,i*32+11, (w0 >> 11) & 0x1, nb,parm);\
  OUT(op,i*32+12, (w0 >> 12) & 0x1, nb,parm);\
  OUT(op,i*32+13, (w0 >> 13) & 0x1, nb,parm);\
  OUT(op,i*32+14, (w0 >> 14) & 0x1, nb,parm);\
  OUT(op,i*32+15, (w0 >> 15) & 0x1, nb,parm);\
  OUT(op,i*32+16, (w0 >> 16) & 0x1, nb,parm);\
  OUT(op,i*32+17, (w0 >> 17) & 0x1, nb,parm);\
  OUT(op,i*32+18, (w0 >> 18) & 0x1, nb,parm);\
  OUT(op,i*32+19, (w0 >> 19) & 0x1, nb,parm);\
  OUT(op,i*32+20, (w0 >> 20) & 0x1, nb,parm);\
  OUT(op,i*32+21, (w0 >> 21) & 0x1, nb,parm);\
  OUT(op,i*32+22, (w0 >> 22) & 0x1, nb,parm);\
  OUT(op,i*32+23, (w0 >> 23) & 0x1, nb,parm);\
  OUT(op,i*32+24, (w0 >> 24) & 0x1, nb,parm);\
  OUT(op,i*32+25, (w0 >> 25) & 0x1, nb,parm);\
  OUT(op,i*32+26, (w0 >> 26) & 0x1, nb,parm);\
  OUT(op,i*32+27, (w0 >> 27) & 0x1, nb,parm);\
  OUT(op,i*32+28, (w0 >> 28) & 0x1, nb,parm);\
  OUT(op,i*32+29, (w0 >> 29) & 0x1, nb,parm);\
  OUT(op,i*32+30, (w0 >> 30) & 0x1, nb,parm);\
  OUT(op,i*32+31, (w0 >> 31) , nb,parm);;\
}

#define BITUNPACK64_1(ip,  op, nb,parm) { \
  BITUNBLK64_1(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 1*4/sizeof(ip[0]);\
}

#define BITUNBLK64_2(ip, i, op, nb,parm) { uint64_t w0;   w0 = *(uint64_t *)(ip+(i*1+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3, nb,parm);\
  OUT(op,i*32+ 1, (w0 >>  2) & 0x3, nb,parm);\
  OUT(op,i*32+ 2, (w0 >>  4) & 0x3, nb,parm);\
  OUT(op,i*32+ 3, (w0 >>  6) & 0x3, nb,parm);\
  OUT(op,i*32+ 4, (w0 >>  8) & 0x3, nb,parm);\
  OUT(op,i*32+ 5, (w0 >> 10) & 0x3, nb,parm);\
  OUT(op,i*32+ 6, (w0 >> 12) & 0x3, nb,parm);\
  OUT(op,i*32+ 7, (w0 >> 14) & 0x3, nb,parm);\
  OUT(op,i*32+ 8, (w0 >> 16) & 0x3, nb,parm);\
  OUT(op,i*32+ 9, (w0 >> 18) & 0x3, nb,parm);\
  OUT(op,i*32+10, (w0 >> 20) & 0x3, nb,parm);\
  OUT(op,i*32+11, (w0 >> 22) & 0x3, nb,parm);\
  OUT(op,i*32+12, (w0 >> 24) & 0x3, nb,parm);\
  OUT(op,i*32+13, (w0 >> 26) & 0x3, nb,parm);\
  OUT(op,i*32+14, (w0 >> 28) & 0x3, nb,parm);\
  OUT(op,i*32+15, (w0 >> 30) & 0x3, nb,parm);\
  OUT(op,i*32+16, (w0 >> 32) & 0x3, nb,parm);\
  OUT(op,i*32+17, (w0 >> 34) & 0x3, nb,parm);\
  OUT(op,i*32+18, (w0 >> 36) & 0x3, nb,parm);\
  OUT(op,i*32+19, (w0 >> 38) & 0x3, nb,parm);\
  OUT(op,i*32+20, (w0 >> 40) & 0x3, nb,parm);\
  OUT(op,i*32+21, (w0 >> 42) & 0x3, nb,parm);\
  OUT(op,i*32+22, (w0 >> 44) & 0x3, nb,parm);\
  OUT(op,i*32+23, (w0 >> 46) & 0x3, nb,parm);\
  OUT(op,i*32+24, (w0 >> 48) & 0x3, nb,parm);\
  OUT(op,i*32+25, (w0 >> 50) & 0x3, nb,parm);\
  OUT(op,i*32+26, (w0 >> 52) & 0x3, nb,parm);\
  OUT(op,i*32+27, (w0 >> 54) & 0x3, nb,parm);\
  OUT(op,i*32+28, (w0 >> 56) & 0x3, nb,parm);\
  OUT(op,i*32+29, (w0 >> 58) & 0x3, nb,parm);\
  OUT(op,i*32+30, (w0 >> 60) & 0x3, nb,parm);\
  OUT(op,i*32+31, (w0 >> 62) , nb,parm);;\
}

#define BITUNPACK64_2(ip,  op, nb,parm) { \
  BITUNBLK64_2(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 2*4/sizeof(ip[0]);\
}

#define BITUNBLK64_3(ip, i, op, nb,parm) { uint64_t w0,w1;   w0 = *(uint64_t *)(ip+(i*3+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7, nb,parm);\
  OUT(op,i*64+ 1, (w0 >>  3) & 0x7, nb,parm);\
  OUT(op,i*64+ 2, (w0 >>  6) & 0x7, nb,parm);\
  OUT(op,i*64+ 3, (w0 >>  9) & 0x7, nb,parm);\
  OUT(op,i*64+ 4, (w0 >> 12) & 0x7, nb,parm);\
  OUT(op,i*64+ 5, (w0 >> 15) & 0x7, nb,parm);\
  OUT(op,i*64+ 6, (w0 >> 18) & 0x7, nb,parm);\
  OUT(op,i*64+ 7, (w0 >> 21) & 0x7, nb,parm);\
  OUT(op,i*64+ 8, (w0 >> 24) & 0x7, nb,parm);\
  OUT(op,i*64+ 9, (w0 >> 27) & 0x7, nb,parm);\
  OUT(op,i*64+10, (w0 >> 30) & 0x7, nb,parm);\
  OUT(op,i*64+11, (w0 >> 33) & 0x7, nb,parm);\
  OUT(op,i*64+12, (w0 >> 36) & 0x7, nb,parm);\
  OUT(op,i*64+13, (w0 >> 39) & 0x7, nb,parm);\
  OUT(op,i*64+14, (w0 >> 42) & 0x7, nb,parm);\
  OUT(op,i*64+15, (w0 >> 45) & 0x7, nb,parm);\
  OUT(op,i*64+16, (w0 >> 48) & 0x7, nb,parm);\
  OUT(op,i*64+17, (w0 >> 51) & 0x7, nb,parm);\
  OUT(op,i*64+18, (w0 >> 54) & 0x7, nb,parm);\
  OUT(op,i*64+19, (w0 >> 57) & 0x7, nb,parm);\
  OUT(op,i*64+20, (w0 >> 60) & 0x7, nb,parm);   w1 = *(uint32_t *)(ip+(i*3+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w0 >> 63) | (w1 <<  1) & 0x7, nb,parm);\
  OUT(op,i*64+22, (w1 >>  2) & 0x7, nb,parm);\
  OUT(op,i*64+23, (w1 >>  5) & 0x7, nb,parm);\
  OUT(op,i*64+24, (w1 >>  8) & 0x7, nb,parm);\
  OUT(op,i*64+25, (w1 >> 11) & 0x7, nb,parm);\
  OUT(op,i*64+26, (w1 >> 14) & 0x7, nb,parm);\
  OUT(op,i*64+27, (w1 >> 17) & 0x7, nb,parm);\
  OUT(op,i*64+28, (w1 >> 20) & 0x7, nb,parm);\
  OUT(op,i*64+29, (w1 >> 23) & 0x7, nb,parm);\
  OUT(op,i*64+30, (w1 >> 26) & 0x7, nb,parm);\
  OUT(op,i*64+31, (w1 >> 29) & 0x7, nb,parm);;\
}

#define BITUNPACK64_3(ip,  op, nb,parm) { \
  BITUNBLK64_3(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 3*4/sizeof(ip[0]);\
}

#define BITUNBLK64_4(ip, i, op, nb,parm) { uint64_t w0,w1;   w0 = *(uint64_t *)(ip+(i*1+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xf, nb,parm);\
  OUT(op,i*16+ 1, (w0 >>  4) & 0xf, nb,parm);\
  OUT(op,i*16+ 2, (w0 >>  8) & 0xf, nb,parm);\
  OUT(op,i*16+ 3, (w0 >> 12) & 0xf, nb,parm);\
  OUT(op,i*16+ 4, (w0 >> 16) & 0xf, nb,parm);\
  OUT(op,i*16+ 5, (w0 >> 20) & 0xf, nb,parm);\
  OUT(op,i*16+ 6, (w0 >> 24) & 0xf, nb,parm);\
  OUT(op,i*16+ 7, (w0 >> 28) & 0xf, nb,parm);\
  OUT(op,i*16+ 8, (w0 >> 32) & 0xf, nb,parm);\
  OUT(op,i*16+ 9, (w0 >> 36) & 0xf, nb,parm);\
  OUT(op,i*16+10, (w0 >> 40) & 0xf, nb,parm);\
  OUT(op,i*16+11, (w0 >> 44) & 0xf, nb,parm);\
  OUT(op,i*16+12, (w0 >> 48) & 0xf, nb,parm);\
  OUT(op,i*16+13, (w0 >> 52) & 0xf, nb,parm);\
  OUT(op,i*16+14, (w0 >> 56) & 0xf, nb,parm);\
  OUT(op,i*16+15, (w0 >> 60) , nb,parm);;\
}

#define BITUNPACK64_4(ip,  op, nb,parm) { \
  BITUNBLK64_4(ip, 0, op, nb,parm);\
  BITUNBLK64_4(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 4*4/sizeof(ip[0]);\
}

#define BITUNBLK64_5(ip, i, op, nb,parm) { uint64_t w0,w1,w2;   w0 = *(uint64_t *)(ip+(i*5+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1f, nb,parm);\
  OUT(op,i*64+ 1, (w0 >>  5) & 0x1f, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 10) & 0x1f, nb,parm);\
  OUT(op,i*64+ 3, (w0 >> 15) & 0x1f, nb,parm);\
  OUT(op,i*64+ 4, (w0 >> 20) & 0x1f, nb,parm);\
  OUT(op,i*64+ 5, (w0 >> 25) & 0x1f, nb,parm);\
  OUT(op,i*64+ 6, (w0 >> 30) & 0x1f, nb,parm);\
  OUT(op,i*64+ 7, (w0 >> 35) & 0x1f, nb,parm);\
  OUT(op,i*64+ 8, (w0 >> 40) & 0x1f, nb,parm);\
  OUT(op,i*64+ 9, (w0 >> 45) & 0x1f, nb,parm);\
  OUT(op,i*64+10, (w0 >> 50) & 0x1f, nb,parm);\
  OUT(op,i*64+11, (w0 >> 55) & 0x1f, nb,parm);   w1 = *(uint64_t *)(ip+(i*5+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w0 >> 60) | (w1 <<  4) & 0x1f, nb,parm);\
  OUT(op,i*64+13, (w1 >>  1) & 0x1f, nb,parm);\
  OUT(op,i*64+14, (w1 >>  6) & 0x1f, nb,parm);\
  OUT(op,i*64+15, (w1 >> 11) & 0x1f, nb,parm);\
  OUT(op,i*64+16, (w1 >> 16) & 0x1f, nb,parm);\
  OUT(op,i*64+17, (w1 >> 21) & 0x1f, nb,parm);\
  OUT(op,i*64+18, (w1 >> 26) & 0x1f, nb,parm);\
  OUT(op,i*64+19, (w1 >> 31) & 0x1f, nb,parm);\
  OUT(op,i*64+20, (w1 >> 36) & 0x1f, nb,parm);\
  OUT(op,i*64+21, (w1 >> 41) & 0x1f, nb,parm);\
  OUT(op,i*64+22, (w1 >> 46) & 0x1f, nb,parm);\
  OUT(op,i*64+23, (w1 >> 51) & 0x1f, nb,parm);\
  OUT(op,i*64+24, (w1 >> 56) & 0x1f, nb,parm);   w2 = *(uint32_t *)(ip+(i*5+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w1 >> 61) | (w2 <<  3) & 0x1f, nb,parm);\
  OUT(op,i*64+26, (w2 >>  2) & 0x1f, nb,parm);\
  OUT(op,i*64+27, (w2 >>  7) & 0x1f, nb,parm);\
  OUT(op,i*64+28, (w2 >> 12) & 0x1f, nb,parm);\
  OUT(op,i*64+29, (w2 >> 17) & 0x1f, nb,parm);\
  OUT(op,i*64+30, (w2 >> 22) & 0x1f, nb,parm);\
  OUT(op,i*64+31, (w2 >> 27) & 0x1f, nb,parm);;\
}

#define BITUNPACK64_5(ip,  op, nb,parm) { \
  BITUNBLK64_5(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 5*4/sizeof(ip[0]);\
}

#define BITUNBLK64_6(ip, i, op, nb,parm) { uint64_t w0,w1,w2;   w0 = *(uint64_t *)(ip+(i*3+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3f, nb,parm);\
  OUT(op,i*32+ 1, (w0 >>  6) & 0x3f, nb,parm);\
  OUT(op,i*32+ 2, (w0 >> 12) & 0x3f, nb,parm);\
  OUT(op,i*32+ 3, (w0 >> 18) & 0x3f, nb,parm);\
  OUT(op,i*32+ 4, (w0 >> 24) & 0x3f, nb,parm);\
  OUT(op,i*32+ 5, (w0 >> 30) & 0x3f, nb,parm);\
  OUT(op,i*32+ 6, (w0 >> 36) & 0x3f, nb,parm);\
  OUT(op,i*32+ 7, (w0 >> 42) & 0x3f, nb,parm);\
  OUT(op,i*32+ 8, (w0 >> 48) & 0x3f, nb,parm);\
  OUT(op,i*32+ 9, (w0 >> 54) & 0x3f, nb,parm);   w1 = *(uint64_t *)(ip+(i*3+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w0 >> 60) | (w1 <<  4) & 0x3f, nb,parm);\
  OUT(op,i*32+11, (w1 >>  2) & 0x3f, nb,parm);\
  OUT(op,i*32+12, (w1 >>  8) & 0x3f, nb,parm);\
  OUT(op,i*32+13, (w1 >> 14) & 0x3f, nb,parm);\
  OUT(op,i*32+14, (w1 >> 20) & 0x3f, nb,parm);\
  OUT(op,i*32+15, (w1 >> 26) & 0x3f, nb,parm);\
  OUT(op,i*32+16, (w1 >> 32) & 0x3f, nb,parm);\
  OUT(op,i*32+17, (w1 >> 38) & 0x3f, nb,parm);\
  OUT(op,i*32+18, (w1 >> 44) & 0x3f, nb,parm);\
  OUT(op,i*32+19, (w1 >> 50) & 0x3f, nb,parm);\
  OUT(op,i*32+20, (w1 >> 56) & 0x3f, nb,parm);   w2 = *(uint64_t *)(ip+(i*3+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w1 >> 62) | (w2 <<  2) & 0x3f, nb,parm);\
  OUT(op,i*32+22, (w2 >>  4) & 0x3f, nb,parm);\
  OUT(op,i*32+23, (w2 >> 10) & 0x3f, nb,parm);\
  OUT(op,i*32+24, (w2 >> 16) & 0x3f, nb,parm);\
  OUT(op,i*32+25, (w2 >> 22) & 0x3f, nb,parm);\
  OUT(op,i*32+26, (w2 >> 28) & 0x3f, nb,parm);\
  OUT(op,i*32+27, (w2 >> 34) & 0x3f, nb,parm);\
  OUT(op,i*32+28, (w2 >> 40) & 0x3f, nb,parm);\
  OUT(op,i*32+29, (w2 >> 46) & 0x3f, nb,parm);\
  OUT(op,i*32+30, (w2 >> 52) & 0x3f, nb,parm);\
  OUT(op,i*32+31, (w2 >> 58) , nb,parm);;\
}

#define BITUNPACK64_6(ip,  op, nb,parm) { \
  BITUNBLK64_6(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 6*4/sizeof(ip[0]);\
}

#define BITUNBLK64_7(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3;   w0 = *(uint64_t *)(ip+(i*7+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7f, nb,parm);\
  OUT(op,i*64+ 1, (w0 >>  7) & 0x7f, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 14) & 0x7f, nb,parm);\
  OUT(op,i*64+ 3, (w0 >> 21) & 0x7f, nb,parm);\
  OUT(op,i*64+ 4, (w0 >> 28) & 0x7f, nb,parm);\
  OUT(op,i*64+ 5, (w0 >> 35) & 0x7f, nb,parm);\
  OUT(op,i*64+ 6, (w0 >> 42) & 0x7f, nb,parm);\
  OUT(op,i*64+ 7, (w0 >> 49) & 0x7f, nb,parm);\
  OUT(op,i*64+ 8, (w0 >> 56) & 0x7f, nb,parm);   w1 = *(uint64_t *)(ip+(i*7+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w0 >> 63) | (w1 <<  1) & 0x7f, nb,parm);\
  OUT(op,i*64+10, (w1 >>  6) & 0x7f, nb,parm);\
  OUT(op,i*64+11, (w1 >> 13) & 0x7f, nb,parm);\
  OUT(op,i*64+12, (w1 >> 20) & 0x7f, nb,parm);\
  OUT(op,i*64+13, (w1 >> 27) & 0x7f, nb,parm);\
  OUT(op,i*64+14, (w1 >> 34) & 0x7f, nb,parm);\
  OUT(op,i*64+15, (w1 >> 41) & 0x7f, nb,parm);\
  OUT(op,i*64+16, (w1 >> 48) & 0x7f, nb,parm);\
  OUT(op,i*64+17, (w1 >> 55) & 0x7f, nb,parm);   w2 = *(uint64_t *)(ip+(i*7+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w1 >> 62) | (w2 <<  2) & 0x7f, nb,parm);\
  OUT(op,i*64+19, (w2 >>  5) & 0x7f, nb,parm);\
  OUT(op,i*64+20, (w2 >> 12) & 0x7f, nb,parm);\
  OUT(op,i*64+21, (w2 >> 19) & 0x7f, nb,parm);\
  OUT(op,i*64+22, (w2 >> 26) & 0x7f, nb,parm);\
  OUT(op,i*64+23, (w2 >> 33) & 0x7f, nb,parm);\
  OUT(op,i*64+24, (w2 >> 40) & 0x7f, nb,parm);\
  OUT(op,i*64+25, (w2 >> 47) & 0x7f, nb,parm);\
  OUT(op,i*64+26, (w2 >> 54) & 0x7f, nb,parm);   w3 = *(uint32_t *)(ip+(i*7+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w2 >> 61) | (w3 <<  3) & 0x7f, nb,parm);\
  OUT(op,i*64+28, (w3 >>  4) & 0x7f, nb,parm);\
  OUT(op,i*64+29, (w3 >> 11) & 0x7f, nb,parm);\
  OUT(op,i*64+30, (w3 >> 18) & 0x7f, nb,parm);\
  OUT(op,i*64+31, (w3 >> 25) & 0x7f, nb,parm);;\
}

#define BITUNPACK64_7(ip,  op, nb,parm) { \
  BITUNBLK64_7(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 7*4/sizeof(ip[0]);\
}

#define BITUNBLK64_8(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3;   w0 = *(uint64_t *)(ip+(i*1+0)*8/sizeof(ip[0]));\
  OUT(op,i*8+ 0, (w0 ) & 0xff, nb,parm);\
  OUT(op,i*8+ 1, (w0 >>  8) & 0xff, nb,parm);\
  OUT(op,i*8+ 2, (w0 >> 16) & 0xff, nb,parm);\
  OUT(op,i*8+ 3, (w0 >> 24) & 0xff, nb,parm);\
  OUT(op,i*8+ 4, (w0 >> 32) & 0xff, nb,parm);\
  OUT(op,i*8+ 5, (w0 >> 40) & 0xff, nb,parm);\
  OUT(op,i*8+ 6, (w0 >> 48) & 0xff, nb,parm);\
  OUT(op,i*8+ 7, (w0 >> 56) , nb,parm);;\
}

#define BITUNPACK64_8(ip,  op, nb,parm) { \
  BITUNBLK64_8(ip, 0, op, nb,parm);\
  BITUNBLK64_8(ip, 1, op, nb,parm);\
  BITUNBLK64_8(ip, 2, op, nb,parm);\
  BITUNBLK64_8(ip, 3, op, nb,parm);  OPI(op, nb,parm); ip += 8*4/sizeof(ip[0]);\
}

#define BITUNBLK64_9(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4;   w0 = *(uint64_t *)(ip+(i*9+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >>  9) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 18) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 3, (w0 >> 27) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 4, (w0 >> 36) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 5, (w0 >> 45) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 6, (w0 >> 54) & 0x1ff, nb,parm);   w1 = *(uint64_t *)(ip+(i*9+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w0 >> 63) | (w1 <<  1) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 8, (w1 >>  8) & 0x1ff, nb,parm);\
  OUT(op,i*64+ 9, (w1 >> 17) & 0x1ff, nb,parm);\
  OUT(op,i*64+10, (w1 >> 26) & 0x1ff, nb,parm);\
  OUT(op,i*64+11, (w1 >> 35) & 0x1ff, nb,parm);\
  OUT(op,i*64+12, (w1 >> 44) & 0x1ff, nb,parm);\
  OUT(op,i*64+13, (w1 >> 53) & 0x1ff, nb,parm);   w2 = *(uint64_t *)(ip+(i*9+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w1 >> 62) | (w2 <<  2) & 0x1ff, nb,parm);\
  OUT(op,i*64+15, (w2 >>  7) & 0x1ff, nb,parm);\
  OUT(op,i*64+16, (w2 >> 16) & 0x1ff, nb,parm);\
  OUT(op,i*64+17, (w2 >> 25) & 0x1ff, nb,parm);\
  OUT(op,i*64+18, (w2 >> 34) & 0x1ff, nb,parm);\
  OUT(op,i*64+19, (w2 >> 43) & 0x1ff, nb,parm);\
  OUT(op,i*64+20, (w2 >> 52) & 0x1ff, nb,parm);   w3 = *(uint64_t *)(ip+(i*9+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w2 >> 61) | (w3 <<  3) & 0x1ff, nb,parm);\
  OUT(op,i*64+22, (w3 >>  6) & 0x1ff, nb,parm);\
  OUT(op,i*64+23, (w3 >> 15) & 0x1ff, nb,parm);\
  OUT(op,i*64+24, (w3 >> 24) & 0x1ff, nb,parm);\
  OUT(op,i*64+25, (w3 >> 33) & 0x1ff, nb,parm);\
  OUT(op,i*64+26, (w3 >> 42) & 0x1ff, nb,parm);\
  OUT(op,i*64+27, (w3 >> 51) & 0x1ff, nb,parm);   w4 = *(uint32_t *)(ip+(i*9+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w3 >> 60) | (w4 <<  4) & 0x1ff, nb,parm);\
  OUT(op,i*64+29, (w4 >>  5) & 0x1ff, nb,parm);\
  OUT(op,i*64+30, (w4 >> 14) & 0x1ff, nb,parm);\
  OUT(op,i*64+31, (w4 >> 23) & 0x1ff, nb,parm);;\
}

#define BITUNPACK64_9(ip,  op, nb,parm) { \
  BITUNBLK64_9(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 9*4/sizeof(ip[0]);\
}

#define BITUNBLK64_10(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4;   w0 = *(uint64_t *)(ip+(i*5+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 1, (w0 >> 10) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 2, (w0 >> 20) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 3, (w0 >> 30) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 4, (w0 >> 40) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 5, (w0 >> 50) & 0x3ff, nb,parm);   w1 = *(uint64_t *)(ip+(i*5+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w0 >> 60) | (w1 <<  4) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 7, (w1 >>  6) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 8, (w1 >> 16) & 0x3ff, nb,parm);\
  OUT(op,i*32+ 9, (w1 >> 26) & 0x3ff, nb,parm);\
  OUT(op,i*32+10, (w1 >> 36) & 0x3ff, nb,parm);\
  OUT(op,i*32+11, (w1 >> 46) & 0x3ff, nb,parm);   w2 = *(uint64_t *)(ip+(i*5+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w1 >> 56) | (w2 <<  8) & 0x3ff, nb,parm);\
  OUT(op,i*32+13, (w2 >>  2) & 0x3ff, nb,parm);\
  OUT(op,i*32+14, (w2 >> 12) & 0x3ff, nb,parm);\
  OUT(op,i*32+15, (w2 >> 22) & 0x3ff, nb,parm);\
  OUT(op,i*32+16, (w2 >> 32) & 0x3ff, nb,parm);\
  OUT(op,i*32+17, (w2 >> 42) & 0x3ff, nb,parm);\
  OUT(op,i*32+18, (w2 >> 52) & 0x3ff, nb,parm);   w3 = *(uint64_t *)(ip+(i*5+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w2 >> 62) | (w3 <<  2) & 0x3ff, nb,parm);\
  OUT(op,i*32+20, (w3 >>  8) & 0x3ff, nb,parm);\
  OUT(op,i*32+21, (w3 >> 18) & 0x3ff, nb,parm);\
  OUT(op,i*32+22, (w3 >> 28) & 0x3ff, nb,parm);\
  OUT(op,i*32+23, (w3 >> 38) & 0x3ff, nb,parm);\
  OUT(op,i*32+24, (w3 >> 48) & 0x3ff, nb,parm);   w4 = *(uint64_t *)(ip+(i*5+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w3 >> 58) | (w4 <<  6) & 0x3ff, nb,parm);\
  OUT(op,i*32+26, (w4 >>  4) & 0x3ff, nb,parm);\
  OUT(op,i*32+27, (w4 >> 14) & 0x3ff, nb,parm);\
  OUT(op,i*32+28, (w4 >> 24) & 0x3ff, nb,parm);\
  OUT(op,i*32+29, (w4 >> 34) & 0x3ff, nb,parm);\
  OUT(op,i*32+30, (w4 >> 44) & 0x3ff, nb,parm);\
  OUT(op,i*32+31, (w4 >> 54) , nb,parm);;\
}

#define BITUNPACK64_10(ip,  op, nb,parm) { \
  BITUNBLK64_10(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 10*4/sizeof(ip[0]);\
}

#define BITUNBLK64_11(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5;   w0 = *(uint64_t *)(ip+(i*11+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 11) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 22) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 3, (w0 >> 33) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 4, (w0 >> 44) & 0x7ff, nb,parm);   w1 = *(uint64_t *)(ip+(i*11+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w0 >> 55) | (w1 <<  9) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 6, (w1 >>  2) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 7, (w1 >> 13) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 8, (w1 >> 24) & 0x7ff, nb,parm);\
  OUT(op,i*64+ 9, (w1 >> 35) & 0x7ff, nb,parm);\
  OUT(op,i*64+10, (w1 >> 46) & 0x7ff, nb,parm);   w2 = *(uint64_t *)(ip+(i*11+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w1 >> 57) | (w2 <<  7) & 0x7ff, nb,parm);\
  OUT(op,i*64+12, (w2 >>  4) & 0x7ff, nb,parm);\
  OUT(op,i*64+13, (w2 >> 15) & 0x7ff, nb,parm);\
  OUT(op,i*64+14, (w2 >> 26) & 0x7ff, nb,parm);\
  OUT(op,i*64+15, (w2 >> 37) & 0x7ff, nb,parm);\
  OUT(op,i*64+16, (w2 >> 48) & 0x7ff, nb,parm);   w3 = *(uint64_t *)(ip+(i*11+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w2 >> 59) | (w3 <<  5) & 0x7ff, nb,parm);\
  OUT(op,i*64+18, (w3 >>  6) & 0x7ff, nb,parm);\
  OUT(op,i*64+19, (w3 >> 17) & 0x7ff, nb,parm);\
  OUT(op,i*64+20, (w3 >> 28) & 0x7ff, nb,parm);\
  OUT(op,i*64+21, (w3 >> 39) & 0x7ff, nb,parm);\
  OUT(op,i*64+22, (w3 >> 50) & 0x7ff, nb,parm);   w4 = *(uint64_t *)(ip+(i*11+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w3 >> 61) | (w4 <<  3) & 0x7ff, nb,parm);\
  OUT(op,i*64+24, (w4 >>  8) & 0x7ff, nb,parm);\
  OUT(op,i*64+25, (w4 >> 19) & 0x7ff, nb,parm);\
  OUT(op,i*64+26, (w4 >> 30) & 0x7ff, nb,parm);\
  OUT(op,i*64+27, (w4 >> 41) & 0x7ff, nb,parm);\
  OUT(op,i*64+28, (w4 >> 52) & 0x7ff, nb,parm);   w5 = *(uint32_t *)(ip+(i*11+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w4 >> 63) | (w5 <<  1) & 0x7ff, nb,parm);\
  OUT(op,i*64+30, (w5 >> 10) & 0x7ff, nb,parm);\
  OUT(op,i*64+31, (w5 >> 21) & 0x7ff, nb,parm);;\
}

#define BITUNPACK64_11(ip,  op, nb,parm) { \
  BITUNBLK64_11(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 11*4/sizeof(ip[0]);\
}

#define BITUNBLK64_12(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5;   w0 = *(uint64_t *)(ip+(i*3+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xfff, nb,parm);\
  OUT(op,i*16+ 1, (w0 >> 12) & 0xfff, nb,parm);\
  OUT(op,i*16+ 2, (w0 >> 24) & 0xfff, nb,parm);\
  OUT(op,i*16+ 3, (w0 >> 36) & 0xfff, nb,parm);\
  OUT(op,i*16+ 4, (w0 >> 48) & 0xfff, nb,parm);   w1 = *(uint64_t *)(ip+(i*3+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 5, (w0 >> 60) | (w1 <<  4) & 0xfff, nb,parm);\
  OUT(op,i*16+ 6, (w1 >>  8) & 0xfff, nb,parm);\
  OUT(op,i*16+ 7, (w1 >> 20) & 0xfff, nb,parm);\
  OUT(op,i*16+ 8, (w1 >> 32) & 0xfff, nb,parm);\
  OUT(op,i*16+ 9, (w1 >> 44) & 0xfff, nb,parm);   w2 = *(uint64_t *)(ip+(i*3+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+10, (w1 >> 56) | (w2 <<  8) & 0xfff, nb,parm);\
  OUT(op,i*16+11, (w2 >>  4) & 0xfff, nb,parm);\
  OUT(op,i*16+12, (w2 >> 16) & 0xfff, nb,parm);\
  OUT(op,i*16+13, (w2 >> 28) & 0xfff, nb,parm);\
  OUT(op,i*16+14, (w2 >> 40) & 0xfff, nb,parm);\
  OUT(op,i*16+15, (w2 >> 52) , nb,parm);;\
}

#define BITUNPACK64_12(ip,  op, nb,parm) { \
  BITUNBLK64_12(ip, 0, op, nb,parm);\
  BITUNBLK64_12(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 12*4/sizeof(ip[0]);\
}

#define BITUNBLK64_13(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6;   w0 = *(uint64_t *)(ip+(i*13+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1fff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 13) & 0x1fff, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 26) & 0x1fff, nb,parm);\
  OUT(op,i*64+ 3, (w0 >> 39) & 0x1fff, nb,parm);   w1 = *(uint64_t *)(ip+(i*13+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w0 >> 52) | (w1 << 12) & 0x1fff, nb,parm);\
  OUT(op,i*64+ 5, (w1 >>  1) & 0x1fff, nb,parm);\
  OUT(op,i*64+ 6, (w1 >> 14) & 0x1fff, nb,parm);\
  OUT(op,i*64+ 7, (w1 >> 27) & 0x1fff, nb,parm);\
  OUT(op,i*64+ 8, (w1 >> 40) & 0x1fff, nb,parm);   w2 = *(uint64_t *)(ip+(i*13+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w1 >> 53) | (w2 << 11) & 0x1fff, nb,parm);\
  OUT(op,i*64+10, (w2 >>  2) & 0x1fff, nb,parm);\
  OUT(op,i*64+11, (w2 >> 15) & 0x1fff, nb,parm);\
  OUT(op,i*64+12, (w2 >> 28) & 0x1fff, nb,parm);\
  OUT(op,i*64+13, (w2 >> 41) & 0x1fff, nb,parm);   w3 = *(uint64_t *)(ip+(i*13+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w2 >> 54) | (w3 << 10) & 0x1fff, nb,parm);\
  OUT(op,i*64+15, (w3 >>  3) & 0x1fff, nb,parm);\
  OUT(op,i*64+16, (w3 >> 16) & 0x1fff, nb,parm);\
  OUT(op,i*64+17, (w3 >> 29) & 0x1fff, nb,parm);\
  OUT(op,i*64+18, (w3 >> 42) & 0x1fff, nb,parm);   w4 = *(uint64_t *)(ip+(i*13+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w3 >> 55) | (w4 <<  9) & 0x1fff, nb,parm);\
  OUT(op,i*64+20, (w4 >>  4) & 0x1fff, nb,parm);\
  OUT(op,i*64+21, (w4 >> 17) & 0x1fff, nb,parm);\
  OUT(op,i*64+22, (w4 >> 30) & 0x1fff, nb,parm);\
  OUT(op,i*64+23, (w4 >> 43) & 0x1fff, nb,parm);   w5 = *(uint64_t *)(ip+(i*13+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w4 >> 56) | (w5 <<  8) & 0x1fff, nb,parm);\
  OUT(op,i*64+25, (w5 >>  5) & 0x1fff, nb,parm);\
  OUT(op,i*64+26, (w5 >> 18) & 0x1fff, nb,parm);\
  OUT(op,i*64+27, (w5 >> 31) & 0x1fff, nb,parm);\
  OUT(op,i*64+28, (w5 >> 44) & 0x1fff, nb,parm);   w6 = *(uint32_t *)(ip+(i*13+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w5 >> 57) | (w6 <<  7) & 0x1fff, nb,parm);\
  OUT(op,i*64+30, (w6 >>  6) & 0x1fff, nb,parm);\
  OUT(op,i*64+31, (w6 >> 19) & 0x1fff, nb,parm);;\
}

#define BITUNPACK64_13(ip,  op, nb,parm) { \
  BITUNBLK64_13(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 13*4/sizeof(ip[0]);\
}

#define BITUNBLK64_14(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6;   w0 = *(uint64_t *)(ip+(i*7+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3fff, nb,parm);\
  OUT(op,i*32+ 1, (w0 >> 14) & 0x3fff, nb,parm);\
  OUT(op,i*32+ 2, (w0 >> 28) & 0x3fff, nb,parm);\
  OUT(op,i*32+ 3, (w0 >> 42) & 0x3fff, nb,parm);   w1 = *(uint64_t *)(ip+(i*7+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w0 >> 56) | (w1 <<  8) & 0x3fff, nb,parm);\
  OUT(op,i*32+ 5, (w1 >>  6) & 0x3fff, nb,parm);\
  OUT(op,i*32+ 6, (w1 >> 20) & 0x3fff, nb,parm);\
  OUT(op,i*32+ 7, (w1 >> 34) & 0x3fff, nb,parm);\
  OUT(op,i*32+ 8, (w1 >> 48) & 0x3fff, nb,parm);   w2 = *(uint64_t *)(ip+(i*7+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w1 >> 62) | (w2 <<  2) & 0x3fff, nb,parm);\
  OUT(op,i*32+10, (w2 >> 12) & 0x3fff, nb,parm);\
  OUT(op,i*32+11, (w2 >> 26) & 0x3fff, nb,parm);\
  OUT(op,i*32+12, (w2 >> 40) & 0x3fff, nb,parm);   w3 = *(uint64_t *)(ip+(i*7+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w2 >> 54) | (w3 << 10) & 0x3fff, nb,parm);\
  OUT(op,i*32+14, (w3 >>  4) & 0x3fff, nb,parm);\
  OUT(op,i*32+15, (w3 >> 18) & 0x3fff, nb,parm);\
  OUT(op,i*32+16, (w3 >> 32) & 0x3fff, nb,parm);\
  OUT(op,i*32+17, (w3 >> 46) & 0x3fff, nb,parm);   w4 = *(uint64_t *)(ip+(i*7+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w3 >> 60) | (w4 <<  4) & 0x3fff, nb,parm);\
  OUT(op,i*32+19, (w4 >> 10) & 0x3fff, nb,parm);\
  OUT(op,i*32+20, (w4 >> 24) & 0x3fff, nb,parm);\
  OUT(op,i*32+21, (w4 >> 38) & 0x3fff, nb,parm);   w5 = *(uint64_t *)(ip+(i*7+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w4 >> 52) | (w5 << 12) & 0x3fff, nb,parm);\
  OUT(op,i*32+23, (w5 >>  2) & 0x3fff, nb,parm);\
  OUT(op,i*32+24, (w5 >> 16) & 0x3fff, nb,parm);\
  OUT(op,i*32+25, (w5 >> 30) & 0x3fff, nb,parm);\
  OUT(op,i*32+26, (w5 >> 44) & 0x3fff, nb,parm);   w6 = *(uint64_t *)(ip+(i*7+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w5 >> 58) | (w6 <<  6) & 0x3fff, nb,parm);\
  OUT(op,i*32+28, (w6 >>  8) & 0x3fff, nb,parm);\
  OUT(op,i*32+29, (w6 >> 22) & 0x3fff, nb,parm);\
  OUT(op,i*32+30, (w6 >> 36) & 0x3fff, nb,parm);\
  OUT(op,i*32+31, (w6 >> 50) , nb,parm);;\
}

#define BITUNPACK64_14(ip,  op, nb,parm) { \
  BITUNBLK64_14(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 14*4/sizeof(ip[0]);\
}

#define BITUNBLK64_15(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7;   w0 = *(uint64_t *)(ip+(i*15+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7fff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 15) & 0x7fff, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 30) & 0x7fff, nb,parm);\
  OUT(op,i*64+ 3, (w0 >> 45) & 0x7fff, nb,parm);   w1 = *(uint64_t *)(ip+(i*15+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w0 >> 60) | (w1 <<  4) & 0x7fff, nb,parm);\
  OUT(op,i*64+ 5, (w1 >> 11) & 0x7fff, nb,parm);\
  OUT(op,i*64+ 6, (w1 >> 26) & 0x7fff, nb,parm);\
  OUT(op,i*64+ 7, (w1 >> 41) & 0x7fff, nb,parm);   w2 = *(uint64_t *)(ip+(i*15+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w1 >> 56) | (w2 <<  8) & 0x7fff, nb,parm);\
  OUT(op,i*64+ 9, (w2 >>  7) & 0x7fff, nb,parm);\
  OUT(op,i*64+10, (w2 >> 22) & 0x7fff, nb,parm);\
  OUT(op,i*64+11, (w2 >> 37) & 0x7fff, nb,parm);   w3 = *(uint64_t *)(ip+(i*15+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w2 >> 52) | (w3 << 12) & 0x7fff, nb,parm);\
  OUT(op,i*64+13, (w3 >>  3) & 0x7fff, nb,parm);\
  OUT(op,i*64+14, (w3 >> 18) & 0x7fff, nb,parm);\
  OUT(op,i*64+15, (w3 >> 33) & 0x7fff, nb,parm);\
  OUT(op,i*64+16, (w3 >> 48) & 0x7fff, nb,parm);   w4 = *(uint64_t *)(ip+(i*15+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w3 >> 63) | (w4 <<  1) & 0x7fff, nb,parm);\
  OUT(op,i*64+18, (w4 >> 14) & 0x7fff, nb,parm);\
  OUT(op,i*64+19, (w4 >> 29) & 0x7fff, nb,parm);\
  OUT(op,i*64+20, (w4 >> 44) & 0x7fff, nb,parm);   w5 = *(uint64_t *)(ip+(i*15+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w4 >> 59) | (w5 <<  5) & 0x7fff, nb,parm);\
  OUT(op,i*64+22, (w5 >> 10) & 0x7fff, nb,parm);\
  OUT(op,i*64+23, (w5 >> 25) & 0x7fff, nb,parm);\
  OUT(op,i*64+24, (w5 >> 40) & 0x7fff, nb,parm);   w6 = *(uint64_t *)(ip+(i*15+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w5 >> 55) | (w6 <<  9) & 0x7fff, nb,parm);\
  OUT(op,i*64+26, (w6 >>  6) & 0x7fff, nb,parm);\
  OUT(op,i*64+27, (w6 >> 21) & 0x7fff, nb,parm);\
  OUT(op,i*64+28, (w6 >> 36) & 0x7fff, nb,parm);   w7 = *(uint32_t *)(ip+(i*15+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w6 >> 51) | (w7 << 13) & 0x7fff, nb,parm);\
  OUT(op,i*64+30, (w7 >>  2) & 0x7fff, nb,parm);\
  OUT(op,i*64+31, (w7 >> 17) & 0x7fff, nb,parm);;\
}

#define BITUNPACK64_15(ip,  op, nb,parm) { \
  BITUNBLK64_15(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 15*4/sizeof(ip[0]);\
}

#define BITUNBLK64_16(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7;\
  OUT(op,i*4+ 0, *(uint16_t *)(ip+i*8+ 0), nb,parm);\
  OUT(op,i*4+ 1, *(uint16_t *)(ip+i*8+ 2), nb,parm);\
  OUT(op,i*4+ 2, *(uint16_t *)(ip+i*8+ 4), nb,parm);\
  OUT(op,i*4+ 3, *(uint16_t *)(ip+i*8+ 6), nb,parm);;\
}

#define BITUNPACK64_16(ip,  op, nb,parm) { \
  BITUNBLK64_16(ip, 0, op, nb,parm);\
  BITUNBLK64_16(ip, 1, op, nb,parm);\
  BITUNBLK64_16(ip, 2, op, nb,parm);\
  BITUNBLK64_16(ip, 3, op, nb,parm);\
  BITUNBLK64_16(ip, 4, op, nb,parm);\
  BITUNBLK64_16(ip, 5, op, nb,parm);\
  BITUNBLK64_16(ip, 6, op, nb,parm);\
  BITUNBLK64_16(ip, 7, op, nb,parm);  OPI(op, nb,parm); ip += 16*4/sizeof(ip[0]);\
}

#define BITUNBLK64_17(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8;   w0 = *(uint64_t *)(ip+(i*17+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1ffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 17) & 0x1ffff, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 34) & 0x1ffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*17+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w0 >> 51) | (w1 << 13) & 0x1ffff, nb,parm);\
  OUT(op,i*64+ 4, (w1 >>  4) & 0x1ffff, nb,parm);\
  OUT(op,i*64+ 5, (w1 >> 21) & 0x1ffff, nb,parm);\
  OUT(op,i*64+ 6, (w1 >> 38) & 0x1ffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*17+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w1 >> 55) | (w2 <<  9) & 0x1ffff, nb,parm);\
  OUT(op,i*64+ 8, (w2 >>  8) & 0x1ffff, nb,parm);\
  OUT(op,i*64+ 9, (w2 >> 25) & 0x1ffff, nb,parm);\
  OUT(op,i*64+10, (w2 >> 42) & 0x1ffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*17+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w2 >> 59) | (w3 <<  5) & 0x1ffff, nb,parm);\
  OUT(op,i*64+12, (w3 >> 12) & 0x1ffff, nb,parm);\
  OUT(op,i*64+13, (w3 >> 29) & 0x1ffff, nb,parm);\
  OUT(op,i*64+14, (w3 >> 46) & 0x1ffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*17+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w3 >> 63) | (w4 <<  1) & 0x1ffff, nb,parm);\
  OUT(op,i*64+16, (w4 >> 16) & 0x1ffff, nb,parm);\
  OUT(op,i*64+17, (w4 >> 33) & 0x1ffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*17+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w4 >> 50) | (w5 << 14) & 0x1ffff, nb,parm);\
  OUT(op,i*64+19, (w5 >>  3) & 0x1ffff, nb,parm);\
  OUT(op,i*64+20, (w5 >> 20) & 0x1ffff, nb,parm);\
  OUT(op,i*64+21, (w5 >> 37) & 0x1ffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*17+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w5 >> 54) | (w6 << 10) & 0x1ffff, nb,parm);\
  OUT(op,i*64+23, (w6 >>  7) & 0x1ffff, nb,parm);\
  OUT(op,i*64+24, (w6 >> 24) & 0x1ffff, nb,parm);\
  OUT(op,i*64+25, (w6 >> 41) & 0x1ffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*17+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w6 >> 58) | (w7 <<  6) & 0x1ffff, nb,parm);\
  OUT(op,i*64+27, (w7 >> 11) & 0x1ffff, nb,parm);\
  OUT(op,i*64+28, (w7 >> 28) & 0x1ffff, nb,parm);\
  OUT(op,i*64+29, (w7 >> 45) & 0x1ffff, nb,parm);   w8 = *(uint32_t *)(ip+(i*17+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w7 >> 62) | (w8 <<  2) & 0x1ffff, nb,parm);\
  OUT(op,i*64+31, (w8 >> 15) & 0x1ffff, nb,parm);;\
}

#define BITUNPACK64_17(ip,  op, nb,parm) { \
  BITUNBLK64_17(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 17*4/sizeof(ip[0]);\
}

#define BITUNBLK64_18(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8;   w0 = *(uint64_t *)(ip+(i*9+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3ffff, nb,parm);\
  OUT(op,i*32+ 1, (w0 >> 18) & 0x3ffff, nb,parm);\
  OUT(op,i*32+ 2, (w0 >> 36) & 0x3ffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*9+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w0 >> 54) | (w1 << 10) & 0x3ffff, nb,parm);\
  OUT(op,i*32+ 4, (w1 >>  8) & 0x3ffff, nb,parm);\
  OUT(op,i*32+ 5, (w1 >> 26) & 0x3ffff, nb,parm);\
  OUT(op,i*32+ 6, (w1 >> 44) & 0x3ffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*9+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w1 >> 62) | (w2 <<  2) & 0x3ffff, nb,parm);\
  OUT(op,i*32+ 8, (w2 >> 16) & 0x3ffff, nb,parm);\
  OUT(op,i*32+ 9, (w2 >> 34) & 0x3ffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*9+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w2 >> 52) | (w3 << 12) & 0x3ffff, nb,parm);\
  OUT(op,i*32+11, (w3 >>  6) & 0x3ffff, nb,parm);\
  OUT(op,i*32+12, (w3 >> 24) & 0x3ffff, nb,parm);\
  OUT(op,i*32+13, (w3 >> 42) & 0x3ffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*9+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w3 >> 60) | (w4 <<  4) & 0x3ffff, nb,parm);\
  OUT(op,i*32+15, (w4 >> 14) & 0x3ffff, nb,parm);\
  OUT(op,i*32+16, (w4 >> 32) & 0x3ffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*9+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w4 >> 50) | (w5 << 14) & 0x3ffff, nb,parm);\
  OUT(op,i*32+18, (w5 >>  4) & 0x3ffff, nb,parm);\
  OUT(op,i*32+19, (w5 >> 22) & 0x3ffff, nb,parm);\
  OUT(op,i*32+20, (w5 >> 40) & 0x3ffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*9+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w5 >> 58) | (w6 <<  6) & 0x3ffff, nb,parm);\
  OUT(op,i*32+22, (w6 >> 12) & 0x3ffff, nb,parm);\
  OUT(op,i*32+23, (w6 >> 30) & 0x3ffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*9+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w6 >> 48) | (w7 << 16) & 0x3ffff, nb,parm);\
  OUT(op,i*32+25, (w7 >>  2) & 0x3ffff, nb,parm);\
  OUT(op,i*32+26, (w7 >> 20) & 0x3ffff, nb,parm);\
  OUT(op,i*32+27, (w7 >> 38) & 0x3ffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*9+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w7 >> 56) | (w8 <<  8) & 0x3ffff, nb,parm);\
  OUT(op,i*32+29, (w8 >> 10) & 0x3ffff, nb,parm);\
  OUT(op,i*32+30, (w8 >> 28) & 0x3ffff, nb,parm);\
  OUT(op,i*32+31, (w8 >> 46) , nb,parm);;\
}

#define BITUNPACK64_18(ip,  op, nb,parm) { \
  BITUNBLK64_18(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 18*4/sizeof(ip[0]);\
}

#define BITUNBLK64_19(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9;   w0 = *(uint64_t *)(ip+(i*19+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7ffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 19) & 0x7ffff, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 38) & 0x7ffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*19+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w0 >> 57) | (w1 <<  7) & 0x7ffff, nb,parm);\
  OUT(op,i*64+ 4, (w1 >> 12) & 0x7ffff, nb,parm);\
  OUT(op,i*64+ 5, (w1 >> 31) & 0x7ffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*19+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w1 >> 50) | (w2 << 14) & 0x7ffff, nb,parm);\
  OUT(op,i*64+ 7, (w2 >>  5) & 0x7ffff, nb,parm);\
  OUT(op,i*64+ 8, (w2 >> 24) & 0x7ffff, nb,parm);\
  OUT(op,i*64+ 9, (w2 >> 43) & 0x7ffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*19+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w2 >> 62) | (w3 <<  2) & 0x7ffff, nb,parm);\
  OUT(op,i*64+11, (w3 >> 17) & 0x7ffff, nb,parm);\
  OUT(op,i*64+12, (w3 >> 36) & 0x7ffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*19+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w3 >> 55) | (w4 <<  9) & 0x7ffff, nb,parm);\
  OUT(op,i*64+14, (w4 >> 10) & 0x7ffff, nb,parm);\
  OUT(op,i*64+15, (w4 >> 29) & 0x7ffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*19+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w4 >> 48) | (w5 << 16) & 0x7ffff, nb,parm);\
  OUT(op,i*64+17, (w5 >>  3) & 0x7ffff, nb,parm);\
  OUT(op,i*64+18, (w5 >> 22) & 0x7ffff, nb,parm);\
  OUT(op,i*64+19, (w5 >> 41) & 0x7ffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*19+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w5 >> 60) | (w6 <<  4) & 0x7ffff, nb,parm);\
  OUT(op,i*64+21, (w6 >> 15) & 0x7ffff, nb,parm);\
  OUT(op,i*64+22, (w6 >> 34) & 0x7ffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*19+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w6 >> 53) | (w7 << 11) & 0x7ffff, nb,parm);\
  OUT(op,i*64+24, (w7 >>  8) & 0x7ffff, nb,parm);\
  OUT(op,i*64+25, (w7 >> 27) & 0x7ffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*19+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w7 >> 46) | (w8 << 18) & 0x7ffff, nb,parm);\
  OUT(op,i*64+27, (w8 >>  1) & 0x7ffff, nb,parm);\
  OUT(op,i*64+28, (w8 >> 20) & 0x7ffff, nb,parm);\
  OUT(op,i*64+29, (w8 >> 39) & 0x7ffff, nb,parm);   w9 = *(uint32_t *)(ip+(i*19+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w8 >> 58) | (w9 <<  6) & 0x7ffff, nb,parm);\
  OUT(op,i*64+31, (w9 >> 13) & 0x7ffff, nb,parm);;\
}

#define BITUNPACK64_19(ip,  op, nb,parm) { \
  BITUNBLK64_19(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 19*4/sizeof(ip[0]);\
}

#define BITUNBLK64_20(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9;   w0 = *(uint64_t *)(ip+(i*5+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xfffff, nb,parm);\
  OUT(op,i*16+ 1, (w0 >> 20) & 0xfffff, nb,parm);\
  OUT(op,i*16+ 2, (w0 >> 40) & 0xfffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*5+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 3, (w0 >> 60) | (w1 <<  4) & 0xfffff, nb,parm);\
  OUT(op,i*16+ 4, (w1 >> 16) & 0xfffff, nb,parm);\
  OUT(op,i*16+ 5, (w1 >> 36) & 0xfffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*5+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 6, (w1 >> 56) | (w2 <<  8) & 0xfffff, nb,parm);\
  OUT(op,i*16+ 7, (w2 >> 12) & 0xfffff, nb,parm);\
  OUT(op,i*16+ 8, (w2 >> 32) & 0xfffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*5+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 9, (w2 >> 52) | (w3 << 12) & 0xfffff, nb,parm);\
  OUT(op,i*16+10, (w3 >>  8) & 0xfffff, nb,parm);\
  OUT(op,i*16+11, (w3 >> 28) & 0xfffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*5+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+12, (w3 >> 48) | (w4 << 16) & 0xfffff, nb,parm);\
  OUT(op,i*16+13, (w4 >>  4) & 0xfffff, nb,parm);\
  OUT(op,i*16+14, (w4 >> 24) & 0xfffff, nb,parm);\
  OUT(op,i*16+15, (w4 >> 44) , nb,parm);;\
}

#define BITUNPACK64_20(ip,  op, nb,parm) { \
  BITUNBLK64_20(ip, 0, op, nb,parm);\
  BITUNBLK64_20(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 20*4/sizeof(ip[0]);\
}

#define BITUNBLK64_21(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10;   w0 = *(uint64_t *)(ip+(i*21+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1fffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 21) & 0x1fffff, nb,parm);\
  OUT(op,i*64+ 2, (w0 >> 42) & 0x1fffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*21+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w0 >> 63) | (w1 <<  1) & 0x1fffff, nb,parm);\
  OUT(op,i*64+ 4, (w1 >> 20) & 0x1fffff, nb,parm);\
  OUT(op,i*64+ 5, (w1 >> 41) & 0x1fffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*21+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w1 >> 62) | (w2 <<  2) & 0x1fffff, nb,parm);\
  OUT(op,i*64+ 7, (w2 >> 19) & 0x1fffff, nb,parm);\
  OUT(op,i*64+ 8, (w2 >> 40) & 0x1fffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*21+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w2 >> 61) | (w3 <<  3) & 0x1fffff, nb,parm);\
  OUT(op,i*64+10, (w3 >> 18) & 0x1fffff, nb,parm);\
  OUT(op,i*64+11, (w3 >> 39) & 0x1fffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*21+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w3 >> 60) | (w4 <<  4) & 0x1fffff, nb,parm);\
  OUT(op,i*64+13, (w4 >> 17) & 0x1fffff, nb,parm);\
  OUT(op,i*64+14, (w4 >> 38) & 0x1fffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*21+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w4 >> 59) | (w5 <<  5) & 0x1fffff, nb,parm);\
  OUT(op,i*64+16, (w5 >> 16) & 0x1fffff, nb,parm);\
  OUT(op,i*64+17, (w5 >> 37) & 0x1fffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*21+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w5 >> 58) | (w6 <<  6) & 0x1fffff, nb,parm);\
  OUT(op,i*64+19, (w6 >> 15) & 0x1fffff, nb,parm);\
  OUT(op,i*64+20, (w6 >> 36) & 0x1fffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*21+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w6 >> 57) | (w7 <<  7) & 0x1fffff, nb,parm);\
  OUT(op,i*64+22, (w7 >> 14) & 0x1fffff, nb,parm);\
  OUT(op,i*64+23, (w7 >> 35) & 0x1fffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*21+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w7 >> 56) | (w8 <<  8) & 0x1fffff, nb,parm);\
  OUT(op,i*64+25, (w8 >> 13) & 0x1fffff, nb,parm);\
  OUT(op,i*64+26, (w8 >> 34) & 0x1fffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*21+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w8 >> 55) | (w9 <<  9) & 0x1fffff, nb,parm);\
  OUT(op,i*64+28, (w9 >> 12) & 0x1fffff, nb,parm);\
  OUT(op,i*64+29, (w9 >> 33) & 0x1fffff, nb,parm);   w10 = *(uint32_t *)(ip+(i*21+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w9 >> 54) | (w10 << 10) & 0x1fffff, nb,parm);\
  OUT(op,i*64+31, (w10 >> 11) & 0x1fffff, nb,parm);;\
}

#define BITUNPACK64_21(ip,  op, nb,parm) { \
  BITUNBLK64_21(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 21*4/sizeof(ip[0]);\
}

#define BITUNBLK64_22(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10;   w0 = *(uint64_t *)(ip+(i*11+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3fffff, nb,parm);\
  OUT(op,i*32+ 1, (w0 >> 22) & 0x3fffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*11+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w0 >> 44) | (w1 << 20) & 0x3fffff, nb,parm);\
  OUT(op,i*32+ 3, (w1 >>  2) & 0x3fffff, nb,parm);\
  OUT(op,i*32+ 4, (w1 >> 24) & 0x3fffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*11+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w1 >> 46) | (w2 << 18) & 0x3fffff, nb,parm);\
  OUT(op,i*32+ 6, (w2 >>  4) & 0x3fffff, nb,parm);\
  OUT(op,i*32+ 7, (w2 >> 26) & 0x3fffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*11+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w2 >> 48) | (w3 << 16) & 0x3fffff, nb,parm);\
  OUT(op,i*32+ 9, (w3 >>  6) & 0x3fffff, nb,parm);\
  OUT(op,i*32+10, (w3 >> 28) & 0x3fffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*11+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w3 >> 50) | (w4 << 14) & 0x3fffff, nb,parm);\
  OUT(op,i*32+12, (w4 >>  8) & 0x3fffff, nb,parm);\
  OUT(op,i*32+13, (w4 >> 30) & 0x3fffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*11+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w4 >> 52) | (w5 << 12) & 0x3fffff, nb,parm);\
  OUT(op,i*32+15, (w5 >> 10) & 0x3fffff, nb,parm);\
  OUT(op,i*32+16, (w5 >> 32) & 0x3fffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*11+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w5 >> 54) | (w6 << 10) & 0x3fffff, nb,parm);\
  OUT(op,i*32+18, (w6 >> 12) & 0x3fffff, nb,parm);\
  OUT(op,i*32+19, (w6 >> 34) & 0x3fffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*11+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w6 >> 56) | (w7 <<  8) & 0x3fffff, nb,parm);\
  OUT(op,i*32+21, (w7 >> 14) & 0x3fffff, nb,parm);\
  OUT(op,i*32+22, (w7 >> 36) & 0x3fffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*11+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w7 >> 58) | (w8 <<  6) & 0x3fffff, nb,parm);\
  OUT(op,i*32+24, (w8 >> 16) & 0x3fffff, nb,parm);\
  OUT(op,i*32+25, (w8 >> 38) & 0x3fffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*11+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w8 >> 60) | (w9 <<  4) & 0x3fffff, nb,parm);\
  OUT(op,i*32+27, (w9 >> 18) & 0x3fffff, nb,parm);\
  OUT(op,i*32+28, (w9 >> 40) & 0x3fffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*11+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w9 >> 62) | (w10 <<  2) & 0x3fffff, nb,parm);\
  OUT(op,i*32+30, (w10 >> 20) & 0x3fffff, nb,parm);\
  OUT(op,i*32+31, (w10 >> 42) , nb,parm);;\
}

#define BITUNPACK64_22(ip,  op, nb,parm) { \
  BITUNBLK64_22(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 22*4/sizeof(ip[0]);\
}

#define BITUNBLK64_23(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11;   w0 = *(uint64_t *)(ip+(i*23+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7fffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 23) & 0x7fffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*23+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w0 >> 46) | (w1 << 18) & 0x7fffff, nb,parm);\
  OUT(op,i*64+ 3, (w1 >>  5) & 0x7fffff, nb,parm);\
  OUT(op,i*64+ 4, (w1 >> 28) & 0x7fffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*23+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w1 >> 51) | (w2 << 13) & 0x7fffff, nb,parm);\
  OUT(op,i*64+ 6, (w2 >> 10) & 0x7fffff, nb,parm);\
  OUT(op,i*64+ 7, (w2 >> 33) & 0x7fffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*23+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w2 >> 56) | (w3 <<  8) & 0x7fffff, nb,parm);\
  OUT(op,i*64+ 9, (w3 >> 15) & 0x7fffff, nb,parm);\
  OUT(op,i*64+10, (w3 >> 38) & 0x7fffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*23+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w3 >> 61) | (w4 <<  3) & 0x7fffff, nb,parm);\
  OUT(op,i*64+12, (w4 >> 20) & 0x7fffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*23+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w4 >> 43) | (w5 << 21) & 0x7fffff, nb,parm);\
  OUT(op,i*64+14, (w5 >>  2) & 0x7fffff, nb,parm);\
  OUT(op,i*64+15, (w5 >> 25) & 0x7fffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*23+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w5 >> 48) | (w6 << 16) & 0x7fffff, nb,parm);\
  OUT(op,i*64+17, (w6 >>  7) & 0x7fffff, nb,parm);\
  OUT(op,i*64+18, (w6 >> 30) & 0x7fffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*23+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w6 >> 53) | (w7 << 11) & 0x7fffff, nb,parm);\
  OUT(op,i*64+20, (w7 >> 12) & 0x7fffff, nb,parm);\
  OUT(op,i*64+21, (w7 >> 35) & 0x7fffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*23+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w7 >> 58) | (w8 <<  6) & 0x7fffff, nb,parm);\
  OUT(op,i*64+23, (w8 >> 17) & 0x7fffff, nb,parm);\
  OUT(op,i*64+24, (w8 >> 40) & 0x7fffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*23+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w8 >> 63) | (w9 <<  1) & 0x7fffff, nb,parm);\
  OUT(op,i*64+26, (w9 >> 22) & 0x7fffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*23+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w9 >> 45) | (w10 << 19) & 0x7fffff, nb,parm);\
  OUT(op,i*64+28, (w10 >>  4) & 0x7fffff, nb,parm);\
  OUT(op,i*64+29, (w10 >> 27) & 0x7fffff, nb,parm);   w11 = *(uint32_t *)(ip+(i*23+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w10 >> 50) | (w11 << 14) & 0x7fffff, nb,parm);\
  OUT(op,i*64+31, (w11 >>  9) & 0x7fffff, nb,parm);;\
}

#define BITUNPACK64_23(ip,  op, nb,parm) { \
  BITUNBLK64_23(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 23*4/sizeof(ip[0]);\
}

#define BITUNBLK64_24(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11;   w0 = *(uint64_t *)(ip+(i*3+0)*8/sizeof(ip[0]));\
  OUT(op,i*8+ 0, (w0 ) & 0xffffff, nb,parm);\
  OUT(op,i*8+ 1, (w0 >> 24) & 0xffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*3+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 2, (w0 >> 48) | (w1 << 16) & 0xffffff, nb,parm);\
  OUT(op,i*8+ 3, (w1 >>  8) & 0xffffff, nb,parm);\
  OUT(op,i*8+ 4, (w1 >> 32) & 0xffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*3+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 5, (w1 >> 56) | (w2 <<  8) & 0xffffff, nb,parm);\
  OUT(op,i*8+ 6, (w2 >> 16) & 0xffffff, nb,parm);\
  OUT(op,i*8+ 7, (w2 >> 40) , nb,parm);;\
}

#define BITUNPACK64_24(ip,  op, nb,parm) { \
  BITUNBLK64_24(ip, 0, op, nb,parm);\
  BITUNBLK64_24(ip, 1, op, nb,parm);\
  BITUNBLK64_24(ip, 2, op, nb,parm);\
  BITUNBLK64_24(ip, 3, op, nb,parm);  OPI(op, nb,parm); ip += 24*4/sizeof(ip[0]);\
}

#define BITUNBLK64_25(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12;   w0 = *(uint64_t *)(ip+(i*25+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 25) & 0x1ffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*25+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w0 >> 50) | (w1 << 14) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+ 3, (w1 >> 11) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+ 4, (w1 >> 36) & 0x1ffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*25+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w1 >> 61) | (w2 <<  3) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+ 6, (w2 >> 22) & 0x1ffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*25+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w2 >> 47) | (w3 << 17) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+ 8, (w3 >>  8) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+ 9, (w3 >> 33) & 0x1ffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*25+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w3 >> 58) | (w4 <<  6) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+11, (w4 >> 19) & 0x1ffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*25+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w4 >> 44) | (w5 << 20) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+13, (w5 >>  5) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+14, (w5 >> 30) & 0x1ffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*25+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w5 >> 55) | (w6 <<  9) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+16, (w6 >> 16) & 0x1ffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*25+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w6 >> 41) | (w7 << 23) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+18, (w7 >>  2) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+19, (w7 >> 27) & 0x1ffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*25+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w7 >> 52) | (w8 << 12) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+21, (w8 >> 13) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+22, (w8 >> 38) & 0x1ffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*25+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w8 >> 63) | (w9 <<  1) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+24, (w9 >> 24) & 0x1ffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*25+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w9 >> 49) | (w10 << 15) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+26, (w10 >> 10) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+27, (w10 >> 35) & 0x1ffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*25+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w10 >> 60) | (w11 <<  4) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+29, (w11 >> 21) & 0x1ffffff, nb,parm);   w12 = *(uint32_t *)(ip+(i*25+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w11 >> 46) | (w12 << 18) & 0x1ffffff, nb,parm);\
  OUT(op,i*64+31, (w12 >>  7) & 0x1ffffff, nb,parm);;\
}

#define BITUNPACK64_25(ip,  op, nb,parm) { \
  BITUNBLK64_25(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 25*4/sizeof(ip[0]);\
}

#define BITUNBLK64_26(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12;   w0 = *(uint64_t *)(ip+(i*13+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+ 1, (w0 >> 26) & 0x3ffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*13+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w0 >> 52) | (w1 << 12) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+ 3, (w1 >> 14) & 0x3ffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*13+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w1 >> 40) | (w2 << 24) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+ 5, (w2 >>  2) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+ 6, (w2 >> 28) & 0x3ffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*13+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w2 >> 54) | (w3 << 10) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+ 8, (w3 >> 16) & 0x3ffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*13+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w3 >> 42) | (w4 << 22) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+10, (w4 >>  4) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+11, (w4 >> 30) & 0x3ffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*13+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w4 >> 56) | (w5 <<  8) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+13, (w5 >> 18) & 0x3ffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*13+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w5 >> 44) | (w6 << 20) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+15, (w6 >>  6) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+16, (w6 >> 32) & 0x3ffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*13+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w6 >> 58) | (w7 <<  6) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+18, (w7 >> 20) & 0x3ffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*13+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w7 >> 46) | (w8 << 18) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+20, (w8 >>  8) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+21, (w8 >> 34) & 0x3ffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*13+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w8 >> 60) | (w9 <<  4) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+23, (w9 >> 22) & 0x3ffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*13+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w9 >> 48) | (w10 << 16) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+25, (w10 >> 10) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+26, (w10 >> 36) & 0x3ffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*13+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w10 >> 62) | (w11 <<  2) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+28, (w11 >> 24) & 0x3ffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*13+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w11 >> 50) | (w12 << 14) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+30, (w12 >> 12) & 0x3ffffff, nb,parm);\
  OUT(op,i*32+31, (w12 >> 38) , nb,parm);;\
}

#define BITUNPACK64_26(ip,  op, nb,parm) { \
  BITUNBLK64_26(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 26*4/sizeof(ip[0]);\
}

#define BITUNBLK64_27(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13;   w0 = *(uint64_t *)(ip+(i*27+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 27) & 0x7ffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*27+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w0 >> 54) | (w1 << 10) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+ 3, (w1 >> 17) & 0x7ffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*27+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w1 >> 44) | (w2 << 20) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+ 5, (w2 >>  7) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+ 6, (w2 >> 34) & 0x7ffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*27+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w2 >> 61) | (w3 <<  3) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+ 8, (w3 >> 24) & 0x7ffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*27+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w3 >> 51) | (w4 << 13) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+10, (w4 >> 14) & 0x7ffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*27+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w4 >> 41) | (w5 << 23) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+12, (w5 >>  4) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+13, (w5 >> 31) & 0x7ffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*27+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w5 >> 58) | (w6 <<  6) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+15, (w6 >> 21) & 0x7ffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*27+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w6 >> 48) | (w7 << 16) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+17, (w7 >> 11) & 0x7ffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*27+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w7 >> 38) | (w8 << 26) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+19, (w8 >>  1) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+20, (w8 >> 28) & 0x7ffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*27+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w8 >> 55) | (w9 <<  9) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+22, (w9 >> 18) & 0x7ffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*27+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w9 >> 45) | (w10 << 19) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+24, (w10 >>  8) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+25, (w10 >> 35) & 0x7ffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*27+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w10 >> 62) | (w11 <<  2) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+27, (w11 >> 25) & 0x7ffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*27+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w11 >> 52) | (w12 << 12) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+29, (w12 >> 15) & 0x7ffffff, nb,parm);   w13 = *(uint32_t *)(ip+(i*27+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w12 >> 42) | (w13 << 22) & 0x7ffffff, nb,parm);\
  OUT(op,i*64+31, (w13 >>  5) & 0x7ffffff, nb,parm);;\
}

#define BITUNPACK64_27(ip,  op, nb,parm) { \
  BITUNBLK64_27(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 27*4/sizeof(ip[0]);\
}

#define BITUNBLK64_28(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13;   w0 = *(uint64_t *)(ip+(i*7+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xfffffff, nb,parm);\
  OUT(op,i*16+ 1, (w0 >> 28) & 0xfffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*7+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 2, (w0 >> 56) | (w1 <<  8) & 0xfffffff, nb,parm);\
  OUT(op,i*16+ 3, (w1 >> 20) & 0xfffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*7+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 4, (w1 >> 48) | (w2 << 16) & 0xfffffff, nb,parm);\
  OUT(op,i*16+ 5, (w2 >> 12) & 0xfffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*7+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 6, (w2 >> 40) | (w3 << 24) & 0xfffffff, nb,parm);\
  OUT(op,i*16+ 7, (w3 >>  4) & 0xfffffff, nb,parm);\
  OUT(op,i*16+ 8, (w3 >> 32) & 0xfffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*7+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 9, (w3 >> 60) | (w4 <<  4) & 0xfffffff, nb,parm);\
  OUT(op,i*16+10, (w4 >> 24) & 0xfffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*7+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+11, (w4 >> 52) | (w5 << 12) & 0xfffffff, nb,parm);\
  OUT(op,i*16+12, (w5 >> 16) & 0xfffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*7+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+13, (w5 >> 44) | (w6 << 20) & 0xfffffff, nb,parm);\
  OUT(op,i*16+14, (w6 >>  8) & 0xfffffff, nb,parm);\
  OUT(op,i*16+15, (w6 >> 36) , nb,parm);;\
}

#define BITUNPACK64_28(ip,  op, nb,parm) { \
  BITUNBLK64_28(ip, 0, op, nb,parm);\
  BITUNBLK64_28(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 28*4/sizeof(ip[0]);\
}

#define BITUNBLK64_29(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14;   w0 = *(uint64_t *)(ip+(i*29+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 29) & 0x1fffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*29+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w0 >> 58) | (w1 <<  6) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+ 3, (w1 >> 23) & 0x1fffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*29+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w1 >> 52) | (w2 << 12) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+ 5, (w2 >> 17) & 0x1fffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*29+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w2 >> 46) | (w3 << 18) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+ 7, (w3 >> 11) & 0x1fffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*29+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w3 >> 40) | (w4 << 24) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+ 9, (w4 >>  5) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+10, (w4 >> 34) & 0x1fffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*29+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w4 >> 63) | (w5 <<  1) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+12, (w5 >> 28) & 0x1fffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*29+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w5 >> 57) | (w6 <<  7) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+14, (w6 >> 22) & 0x1fffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*29+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w6 >> 51) | (w7 << 13) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+16, (w7 >> 16) & 0x1fffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*29+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w7 >> 45) | (w8 << 19) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+18, (w8 >> 10) & 0x1fffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*29+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w8 >> 39) | (w9 << 25) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+20, (w9 >>  4) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+21, (w9 >> 33) & 0x1fffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*29+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w9 >> 62) | (w10 <<  2) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+23, (w10 >> 27) & 0x1fffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*29+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w10 >> 56) | (w11 <<  8) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+25, (w11 >> 21) & 0x1fffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*29+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w11 >> 50) | (w12 << 14) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+27, (w12 >> 15) & 0x1fffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*29+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w12 >> 44) | (w13 << 20) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+29, (w13 >>  9) & 0x1fffffff, nb,parm);   w14 = *(uint32_t *)(ip+(i*29+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w13 >> 38) | (w14 << 26) & 0x1fffffff, nb,parm);\
  OUT(op,i*64+31, (w14 >>  3) & 0x1fffffff, nb,parm);;\
}

#define BITUNPACK64_29(ip,  op, nb,parm) { \
  BITUNBLK64_29(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 29*4/sizeof(ip[0]);\
}

#define BITUNBLK64_30(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14;   w0 = *(uint64_t *)(ip+(i*15+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+ 1, (w0 >> 30) & 0x3fffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*15+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w0 >> 60) | (w1 <<  4) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+ 3, (w1 >> 26) & 0x3fffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*15+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w1 >> 56) | (w2 <<  8) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+ 5, (w2 >> 22) & 0x3fffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*15+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w2 >> 52) | (w3 << 12) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+ 7, (w3 >> 18) & 0x3fffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*15+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w3 >> 48) | (w4 << 16) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+ 9, (w4 >> 14) & 0x3fffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*15+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w4 >> 44) | (w5 << 20) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+11, (w5 >> 10) & 0x3fffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*15+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w5 >> 40) | (w6 << 24) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+13, (w6 >>  6) & 0x3fffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*15+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w6 >> 36) | (w7 << 28) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+15, (w7 >>  2) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+16, (w7 >> 32) & 0x3fffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*15+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w7 >> 62) | (w8 <<  2) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+18, (w8 >> 28) & 0x3fffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*15+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w8 >> 58) | (w9 <<  6) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+20, (w9 >> 24) & 0x3fffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*15+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w9 >> 54) | (w10 << 10) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+22, (w10 >> 20) & 0x3fffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*15+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w10 >> 50) | (w11 << 14) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+24, (w11 >> 16) & 0x3fffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*15+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w11 >> 46) | (w12 << 18) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+26, (w12 >> 12) & 0x3fffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*15+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w12 >> 42) | (w13 << 22) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+28, (w13 >>  8) & 0x3fffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*15+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w13 >> 38) | (w14 << 26) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+30, (w14 >>  4) & 0x3fffffff, nb,parm);\
  OUT(op,i*32+31, (w14 >> 34) , nb,parm);;\
}

#define BITUNPACK64_30(ip,  op, nb,parm) { \
  BITUNBLK64_30(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 30*4/sizeof(ip[0]);\
}

#define BITUNBLK64_31(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15;   w0 = *(uint64_t *)(ip+(i*31+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+ 1, (w0 >> 31) & 0x7fffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*31+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w0 >> 62) | (w1 <<  2) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+ 3, (w1 >> 29) & 0x7fffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*31+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w1 >> 60) | (w2 <<  4) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+ 5, (w2 >> 27) & 0x7fffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*31+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w2 >> 58) | (w3 <<  6) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+ 7, (w3 >> 25) & 0x7fffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*31+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w3 >> 56) | (w4 <<  8) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+ 9, (w4 >> 23) & 0x7fffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*31+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w4 >> 54) | (w5 << 10) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+11, (w5 >> 21) & 0x7fffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*31+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w5 >> 52) | (w6 << 12) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+13, (w6 >> 19) & 0x7fffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*31+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w6 >> 50) | (w7 << 14) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+15, (w7 >> 17) & 0x7fffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*31+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w7 >> 48) | (w8 << 16) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+17, (w8 >> 15) & 0x7fffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*31+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w8 >> 46) | (w9 << 18) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+19, (w9 >> 13) & 0x7fffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*31+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w9 >> 44) | (w10 << 20) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+21, (w10 >> 11) & 0x7fffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*31+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w10 >> 42) | (w11 << 22) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+23, (w11 >>  9) & 0x7fffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*31+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w11 >> 40) | (w12 << 24) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+25, (w12 >>  7) & 0x7fffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*31+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w12 >> 38) | (w13 << 26) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+27, (w13 >>  5) & 0x7fffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*31+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w13 >> 36) | (w14 << 28) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+29, (w14 >>  3) & 0x7fffffff, nb,parm);   w15 = *(uint32_t *)(ip+(i*31+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w14 >> 34) | (w15 << 30) & 0x7fffffff, nb,parm);\
  OUT(op,i*64+31, (w15 >>  1) & 0x7fffffff, nb,parm);;\
}

#define BITUNPACK64_31(ip,  op, nb,parm) { \
  BITUNBLK64_31(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 31*4/sizeof(ip[0]);\
}

#define BITUNBLK64_32(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15;\
  OUT(op,i*2+ 0, *(uint32_t *)(ip+i*8+ 0), nb,parm);\
  OUT(op,i*2+ 1, *(uint32_t *)(ip+i*8+ 4), nb,parm);;\
}

#define BITUNPACK64_32(ip,  op, nb,parm) { \
  BITUNBLK64_32(ip, 0, op, nb,parm);\
  BITUNBLK64_32(ip, 1, op, nb,parm);\
  BITUNBLK64_32(ip, 2, op, nb,parm);\
  BITUNBLK64_32(ip, 3, op, nb,parm);\
  BITUNBLK64_32(ip, 4, op, nb,parm);\
  BITUNBLK64_32(ip, 5, op, nb,parm);\
  BITUNBLK64_32(ip, 6, op, nb,parm);\
  BITUNBLK64_32(ip, 7, op, nb,parm);\
  BITUNBLK64_32(ip, 8, op, nb,parm);\
  BITUNBLK64_32(ip, 9, op, nb,parm);\
  BITUNBLK64_32(ip, 10, op, nb,parm);\
  BITUNBLK64_32(ip, 11, op, nb,parm);\
  BITUNBLK64_32(ip, 12, op, nb,parm);\
  BITUNBLK64_32(ip, 13, op, nb,parm);\
  BITUNBLK64_32(ip, 14, op, nb,parm);\
  BITUNBLK64_32(ip, 15, op, nb,parm);  OPI(op, nb,parm); ip += 32*4/sizeof(ip[0]);\
}

#define BITUNBLK64_33(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16;   w0 = *(uint64_t *)(ip+(i*33+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1ffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*33+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 33) | (w1 << 31) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+ 2, (w1 >>  2) & 0x1ffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*33+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w1 >> 35) | (w2 << 29) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+ 4, (w2 >>  4) & 0x1ffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*33+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w2 >> 37) | (w3 << 27) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+ 6, (w3 >>  6) & 0x1ffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*33+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w3 >> 39) | (w4 << 25) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+ 8, (w4 >>  8) & 0x1ffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*33+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w4 >> 41) | (w5 << 23) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+10, (w5 >> 10) & 0x1ffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*33+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w5 >> 43) | (w6 << 21) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+12, (w6 >> 12) & 0x1ffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*33+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w6 >> 45) | (w7 << 19) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+14, (w7 >> 14) & 0x1ffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*33+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w7 >> 47) | (w8 << 17) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+16, (w8 >> 16) & 0x1ffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*33+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w8 >> 49) | (w9 << 15) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+18, (w9 >> 18) & 0x1ffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*33+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w9 >> 51) | (w10 << 13) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+20, (w10 >> 20) & 0x1ffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*33+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w10 >> 53) | (w11 << 11) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+22, (w11 >> 22) & 0x1ffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*33+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w11 >> 55) | (w12 <<  9) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+24, (w12 >> 24) & 0x1ffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*33+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w12 >> 57) | (w13 <<  7) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+26, (w13 >> 26) & 0x1ffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*33+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w13 >> 59) | (w14 <<  5) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+28, (w14 >> 28) & 0x1ffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*33+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w14 >> 61) | (w15 <<  3) & 0x1ffffffff, nb,parm);\
  OUT(op,i*64+30, (w15 >> 30) & 0x1ffffffff, nb,parm);   w16 = *(uint32_t *)(ip+(i*33+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w15 >> 63) | (w16 <<  1) & 0x1ffffffff, nb,parm);;\
}

#define BITUNPACK64_33(ip,  op, nb,parm) { \
  BITUNBLK64_33(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 33*4/sizeof(ip[0]);\
}

#define BITUNBLK64_34(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16;   w0 = *(uint64_t *)(ip+(i*17+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3ffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*17+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 34) | (w1 << 30) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+ 2, (w1 >>  4) & 0x3ffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*17+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w1 >> 38) | (w2 << 26) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+ 4, (w2 >>  8) & 0x3ffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*17+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w2 >> 42) | (w3 << 22) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+ 6, (w3 >> 12) & 0x3ffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*17+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w3 >> 46) | (w4 << 18) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+ 8, (w4 >> 16) & 0x3ffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*17+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w4 >> 50) | (w5 << 14) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+10, (w5 >> 20) & 0x3ffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*17+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w5 >> 54) | (w6 << 10) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+12, (w6 >> 24) & 0x3ffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*17+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w6 >> 58) | (w7 <<  6) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+14, (w7 >> 28) & 0x3ffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*17+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w7 >> 62) | (w8 <<  2) & 0x3ffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*17+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w8 >> 32) | (w9 << 32) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+17, (w9 >>  2) & 0x3ffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*17+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w9 >> 36) | (w10 << 28) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+19, (w10 >>  6) & 0x3ffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*17+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w10 >> 40) | (w11 << 24) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+21, (w11 >> 10) & 0x3ffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*17+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w11 >> 44) | (w12 << 20) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+23, (w12 >> 14) & 0x3ffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*17+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w12 >> 48) | (w13 << 16) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+25, (w13 >> 18) & 0x3ffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*17+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w13 >> 52) | (w14 << 12) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+27, (w14 >> 22) & 0x3ffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*17+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w14 >> 56) | (w15 <<  8) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+29, (w15 >> 26) & 0x3ffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*17+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w15 >> 60) | (w16 <<  4) & 0x3ffffffff, nb,parm);\
  OUT(op,i*32+31, (w16 >> 30) , nb,parm);;\
}

#define BITUNPACK64_34(ip,  op, nb,parm) { \
  BITUNBLK64_34(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 34*4/sizeof(ip[0]);\
}

#define BITUNBLK64_35(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17;   w0 = *(uint64_t *)(ip+(i*35+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7ffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*35+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 35) | (w1 << 29) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+ 2, (w1 >>  6) & 0x7ffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*35+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w1 >> 41) | (w2 << 23) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+ 4, (w2 >> 12) & 0x7ffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*35+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w2 >> 47) | (w3 << 17) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+ 6, (w3 >> 18) & 0x7ffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*35+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w3 >> 53) | (w4 << 11) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+ 8, (w4 >> 24) & 0x7ffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*35+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w4 >> 59) | (w5 <<  5) & 0x7ffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*35+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w5 >> 30) | (w6 << 34) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+11, (w6 >>  1) & 0x7ffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*35+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w6 >> 36) | (w7 << 28) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+13, (w7 >>  7) & 0x7ffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*35+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w7 >> 42) | (w8 << 22) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+15, (w8 >> 13) & 0x7ffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*35+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w8 >> 48) | (w9 << 16) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+17, (w9 >> 19) & 0x7ffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*35+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w9 >> 54) | (w10 << 10) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+19, (w10 >> 25) & 0x7ffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*35+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w10 >> 60) | (w11 <<  4) & 0x7ffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*35+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w11 >> 31) | (w12 << 33) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+22, (w12 >>  2) & 0x7ffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*35+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w12 >> 37) | (w13 << 27) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+24, (w13 >>  8) & 0x7ffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*35+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w13 >> 43) | (w14 << 21) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+26, (w14 >> 14) & 0x7ffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*35+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w14 >> 49) | (w15 << 15) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+28, (w15 >> 20) & 0x7ffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*35+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w15 >> 55) | (w16 <<  9) & 0x7ffffffff, nb,parm);\
  OUT(op,i*64+30, (w16 >> 26) & 0x7ffffffff, nb,parm);   w17 = *(uint32_t *)(ip+(i*35+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w16 >> 61) | (w17 <<  3) & 0x7ffffffff, nb,parm);;\
}

#define BITUNPACK64_35(ip,  op, nb,parm) { \
  BITUNBLK64_35(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 35*4/sizeof(ip[0]);\
}

#define BITUNBLK64_36(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17;   w0 = *(uint64_t *)(ip+(i*9+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xfffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*9+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 1, (w0 >> 36) | (w1 << 28) & 0xfffffffff, nb,parm);\
  OUT(op,i*16+ 2, (w1 >>  8) & 0xfffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*9+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 3, (w1 >> 44) | (w2 << 20) & 0xfffffffff, nb,parm);\
  OUT(op,i*16+ 4, (w2 >> 16) & 0xfffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*9+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 5, (w2 >> 52) | (w3 << 12) & 0xfffffffff, nb,parm);\
  OUT(op,i*16+ 6, (w3 >> 24) & 0xfffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*9+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 7, (w3 >> 60) | (w4 <<  4) & 0xfffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*9+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 8, (w4 >> 32) | (w5 << 32) & 0xfffffffff, nb,parm);\
  OUT(op,i*16+ 9, (w5 >>  4) & 0xfffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*9+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+10, (w5 >> 40) | (w6 << 24) & 0xfffffffff, nb,parm);\
  OUT(op,i*16+11, (w6 >> 12) & 0xfffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*9+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+12, (w6 >> 48) | (w7 << 16) & 0xfffffffff, nb,parm);\
  OUT(op,i*16+13, (w7 >> 20) & 0xfffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*9+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+14, (w7 >> 56) | (w8 <<  8) & 0xfffffffff, nb,parm);\
  OUT(op,i*16+15, (w8 >> 28) , nb,parm);;\
}

#define BITUNPACK64_36(ip,  op, nb,parm) { \
  BITUNBLK64_36(ip, 0, op, nb,parm);\
  BITUNBLK64_36(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 36*4/sizeof(ip[0]);\
}

#define BITUNBLK64_37(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18;   w0 = *(uint64_t *)(ip+(i*37+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1fffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*37+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 37) | (w1 << 27) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+ 2, (w1 >> 10) & 0x1fffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*37+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w1 >> 47) | (w2 << 17) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+ 4, (w2 >> 20) & 0x1fffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*37+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w2 >> 57) | (w3 <<  7) & 0x1fffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*37+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w3 >> 30) | (w4 << 34) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+ 7, (w4 >>  3) & 0x1fffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*37+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w4 >> 40) | (w5 << 24) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+ 9, (w5 >> 13) & 0x1fffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*37+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w5 >> 50) | (w6 << 14) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+11, (w6 >> 23) & 0x1fffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*37+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w6 >> 60) | (w7 <<  4) & 0x1fffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*37+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w7 >> 33) | (w8 << 31) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+14, (w8 >>  6) & 0x1fffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*37+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w8 >> 43) | (w9 << 21) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+16, (w9 >> 16) & 0x1fffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*37+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w9 >> 53) | (w10 << 11) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+18, (w10 >> 26) & 0x1fffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*37+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w10 >> 63) | (w11 <<  1) & 0x1fffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*37+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w11 >> 36) | (w12 << 28) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+21, (w12 >>  9) & 0x1fffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*37+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w12 >> 46) | (w13 << 18) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+23, (w13 >> 19) & 0x1fffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*37+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w13 >> 56) | (w14 <<  8) & 0x1fffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*37+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w14 >> 29) | (w15 << 35) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+26, (w15 >>  2) & 0x1fffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*37+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w15 >> 39) | (w16 << 25) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+28, (w16 >> 12) & 0x1fffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*37+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w16 >> 49) | (w17 << 15) & 0x1fffffffff, nb,parm);\
  OUT(op,i*64+30, (w17 >> 22) & 0x1fffffffff, nb,parm);   w18 = *(uint32_t *)(ip+(i*37+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w17 >> 59) | (w18 <<  5) & 0x1fffffffff, nb,parm);;\
}

#define BITUNPACK64_37(ip,  op, nb,parm) { \
  BITUNBLK64_37(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 37*4/sizeof(ip[0]);\
}

#define BITUNBLK64_38(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18;   w0 = *(uint64_t *)(ip+(i*19+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3fffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*19+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 38) | (w1 << 26) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+ 2, (w1 >> 12) & 0x3fffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*19+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w1 >> 50) | (w2 << 14) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+ 4, (w2 >> 24) & 0x3fffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*19+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w2 >> 62) | (w3 <<  2) & 0x3fffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*19+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w3 >> 36) | (w4 << 28) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+ 7, (w4 >> 10) & 0x3fffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*19+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w4 >> 48) | (w5 << 16) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+ 9, (w5 >> 22) & 0x3fffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*19+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w5 >> 60) | (w6 <<  4) & 0x3fffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*19+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w6 >> 34) | (w7 << 30) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+12, (w7 >>  8) & 0x3fffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*19+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w7 >> 46) | (w8 << 18) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+14, (w8 >> 20) & 0x3fffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*19+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w8 >> 58) | (w9 <<  6) & 0x3fffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*19+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w9 >> 32) | (w10 << 32) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+17, (w10 >>  6) & 0x3fffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*19+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w10 >> 44) | (w11 << 20) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+19, (w11 >> 18) & 0x3fffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*19+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w11 >> 56) | (w12 <<  8) & 0x3fffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*19+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w12 >> 30) | (w13 << 34) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+22, (w13 >>  4) & 0x3fffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*19+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w13 >> 42) | (w14 << 22) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+24, (w14 >> 16) & 0x3fffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*19+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w14 >> 54) | (w15 << 10) & 0x3fffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*19+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w15 >> 28) | (w16 << 36) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+27, (w16 >>  2) & 0x3fffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*19+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w16 >> 40) | (w17 << 24) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+29, (w17 >> 14) & 0x3fffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*19+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w17 >> 52) | (w18 << 12) & 0x3fffffffff, nb,parm);\
  OUT(op,i*32+31, (w18 >> 26) , nb,parm);;\
}

#define BITUNPACK64_38(ip,  op, nb,parm) { \
  BITUNBLK64_38(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 38*4/sizeof(ip[0]);\
}

#define BITUNBLK64_39(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19;   w0 = *(uint64_t *)(ip+(i*39+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7fffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*39+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 39) | (w1 << 25) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+ 2, (w1 >> 14) & 0x7fffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*39+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w1 >> 53) | (w2 << 11) & 0x7fffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*39+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w2 >> 28) | (w3 << 36) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+ 5, (w3 >>  3) & 0x7fffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*39+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w3 >> 42) | (w4 << 22) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+ 7, (w4 >> 17) & 0x7fffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*39+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w4 >> 56) | (w5 <<  8) & 0x7fffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*39+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w5 >> 31) | (w6 << 33) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+10, (w6 >>  6) & 0x7fffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*39+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w6 >> 45) | (w7 << 19) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+12, (w7 >> 20) & 0x7fffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*39+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w7 >> 59) | (w8 <<  5) & 0x7fffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*39+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w8 >> 34) | (w9 << 30) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+15, (w9 >>  9) & 0x7fffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*39+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w9 >> 48) | (w10 << 16) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+17, (w10 >> 23) & 0x7fffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*39+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w10 >> 62) | (w11 <<  2) & 0x7fffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*39+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w11 >> 37) | (w12 << 27) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+20, (w12 >> 12) & 0x7fffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*39+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w12 >> 51) | (w13 << 13) & 0x7fffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*39+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w13 >> 26) | (w14 << 38) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+23, (w14 >>  1) & 0x7fffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*39+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w14 >> 40) | (w15 << 24) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+25, (w15 >> 15) & 0x7fffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*39+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w15 >> 54) | (w16 << 10) & 0x7fffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*39+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w16 >> 29) | (w17 << 35) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+28, (w17 >>  4) & 0x7fffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*39+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w17 >> 43) | (w18 << 21) & 0x7fffffffff, nb,parm);\
  OUT(op,i*64+30, (w18 >> 18) & 0x7fffffffff, nb,parm);   w19 = *(uint32_t *)(ip+(i*39+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w18 >> 57) | (w19 <<  7) & 0x7fffffffff, nb,parm);;\
}

#define BITUNPACK64_39(ip,  op, nb,parm) { \
  BITUNBLK64_39(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 39*4/sizeof(ip[0]);\
}

#define BITUNBLK64_40(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19;   w0 = *(uint64_t *)(ip+(i*5+0)*8/sizeof(ip[0]));\
  OUT(op,i*8+ 0, (w0 ) & 0xffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*5+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 1, (w0 >> 40) | (w1 << 24) & 0xffffffffff, nb,parm);\
  OUT(op,i*8+ 2, (w1 >> 16) & 0xffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*5+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 3, (w1 >> 56) | (w2 <<  8) & 0xffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*5+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 4, (w2 >> 32) | (w3 << 32) & 0xffffffffff, nb,parm);\
  OUT(op,i*8+ 5, (w3 >>  8) & 0xffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*5+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 6, (w3 >> 48) | (w4 << 16) & 0xffffffffff, nb,parm);\
  OUT(op,i*8+ 7, (w4 >> 24) , nb,parm);;\
}

#define BITUNPACK64_40(ip,  op, nb,parm) { \
  BITUNBLK64_40(ip, 0, op, nb,parm);\
  BITUNBLK64_40(ip, 1, op, nb,parm);\
  BITUNBLK64_40(ip, 2, op, nb,parm);\
  BITUNBLK64_40(ip, 3, op, nb,parm);  OPI(op, nb,parm); ip += 40*4/sizeof(ip[0]);\
}

#define BITUNBLK64_41(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20;   w0 = *(uint64_t *)(ip+(i*41+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1ffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*41+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 41) | (w1 << 23) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+ 2, (w1 >> 18) & 0x1ffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*41+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w1 >> 59) | (w2 <<  5) & 0x1ffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*41+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w2 >> 36) | (w3 << 28) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+ 5, (w3 >> 13) & 0x1ffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*41+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w3 >> 54) | (w4 << 10) & 0x1ffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*41+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w4 >> 31) | (w5 << 33) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+ 8, (w5 >>  8) & 0x1ffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*41+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w5 >> 49) | (w6 << 15) & 0x1ffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*41+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w6 >> 26) | (w7 << 38) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+11, (w7 >>  3) & 0x1ffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*41+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w7 >> 44) | (w8 << 20) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+13, (w8 >> 21) & 0x1ffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*41+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w8 >> 62) | (w9 <<  2) & 0x1ffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*41+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w9 >> 39) | (w10 << 25) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+16, (w10 >> 16) & 0x1ffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*41+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w10 >> 57) | (w11 <<  7) & 0x1ffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*41+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w11 >> 34) | (w12 << 30) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+19, (w12 >> 11) & 0x1ffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*41+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w12 >> 52) | (w13 << 12) & 0x1ffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*41+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w13 >> 29) | (w14 << 35) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+22, (w14 >>  6) & 0x1ffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*41+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w14 >> 47) | (w15 << 17) & 0x1ffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*41+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w15 >> 24) | (w16 << 40) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+25, (w16 >>  1) & 0x1ffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*41+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w16 >> 42) | (w17 << 22) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+27, (w17 >> 19) & 0x1ffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*41+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w17 >> 60) | (w18 <<  4) & 0x1ffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*41+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w18 >> 37) | (w19 << 27) & 0x1ffffffffff, nb,parm);\
  OUT(op,i*64+30, (w19 >> 14) & 0x1ffffffffff, nb,parm);   w20 = *(uint32_t *)(ip+(i*41+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w19 >> 55) | (w20 <<  9) & 0x1ffffffffff, nb,parm);;\
}

#define BITUNPACK64_41(ip,  op, nb,parm) { \
  BITUNBLK64_41(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 41*4/sizeof(ip[0]);\
}

#define BITUNBLK64_42(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20;   w0 = *(uint64_t *)(ip+(i*21+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3ffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*21+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 42) | (w1 << 22) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+ 2, (w1 >> 20) & 0x3ffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*21+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w1 >> 62) | (w2 <<  2) & 0x3ffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*21+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w2 >> 40) | (w3 << 24) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+ 5, (w3 >> 18) & 0x3ffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*21+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w3 >> 60) | (w4 <<  4) & 0x3ffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*21+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w4 >> 38) | (w5 << 26) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+ 8, (w5 >> 16) & 0x3ffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*21+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w5 >> 58) | (w6 <<  6) & 0x3ffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*21+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w6 >> 36) | (w7 << 28) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+11, (w7 >> 14) & 0x3ffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*21+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w7 >> 56) | (w8 <<  8) & 0x3ffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*21+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w8 >> 34) | (w9 << 30) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+14, (w9 >> 12) & 0x3ffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*21+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w9 >> 54) | (w10 << 10) & 0x3ffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*21+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w10 >> 32) | (w11 << 32) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+17, (w11 >> 10) & 0x3ffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*21+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w11 >> 52) | (w12 << 12) & 0x3ffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*21+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w12 >> 30) | (w13 << 34) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+20, (w13 >>  8) & 0x3ffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*21+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w13 >> 50) | (w14 << 14) & 0x3ffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*21+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w14 >> 28) | (w15 << 36) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+23, (w15 >>  6) & 0x3ffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*21+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w15 >> 48) | (w16 << 16) & 0x3ffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*21+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w16 >> 26) | (w17 << 38) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+26, (w17 >>  4) & 0x3ffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*21+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w17 >> 46) | (w18 << 18) & 0x3ffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*21+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w18 >> 24) | (w19 << 40) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+29, (w19 >>  2) & 0x3ffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*21+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w19 >> 44) | (w20 << 20) & 0x3ffffffffff, nb,parm);\
  OUT(op,i*32+31, (w20 >> 22) , nb,parm);;\
}

#define BITUNPACK64_42(ip,  op, nb,parm) { \
  BITUNBLK64_42(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 42*4/sizeof(ip[0]);\
}

#define BITUNBLK64_43(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21;   w0 = *(uint64_t *)(ip+(i*43+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7ffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*43+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 43) | (w1 << 21) & 0x7ffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*43+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 22) | (w2 << 42) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+ 3, (w2 >>  1) & 0x7ffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*43+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w2 >> 44) | (w3 << 20) & 0x7ffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*43+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w3 >> 23) | (w4 << 41) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+ 6, (w4 >>  2) & 0x7ffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*43+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w4 >> 45) | (w5 << 19) & 0x7ffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*43+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w5 >> 24) | (w6 << 40) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+ 9, (w6 >>  3) & 0x7ffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*43+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w6 >> 46) | (w7 << 18) & 0x7ffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*43+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w7 >> 25) | (w8 << 39) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+12, (w8 >>  4) & 0x7ffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*43+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w8 >> 47) | (w9 << 17) & 0x7ffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*43+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w9 >> 26) | (w10 << 38) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+15, (w10 >>  5) & 0x7ffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*43+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w10 >> 48) | (w11 << 16) & 0x7ffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*43+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w11 >> 27) | (w12 << 37) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+18, (w12 >>  6) & 0x7ffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*43+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w12 >> 49) | (w13 << 15) & 0x7ffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*43+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w13 >> 28) | (w14 << 36) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+21, (w14 >>  7) & 0x7ffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*43+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w14 >> 50) | (w15 << 14) & 0x7ffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*43+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w15 >> 29) | (w16 << 35) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+24, (w16 >>  8) & 0x7ffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*43+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w16 >> 51) | (w17 << 13) & 0x7ffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*43+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w17 >> 30) | (w18 << 34) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+27, (w18 >>  9) & 0x7ffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*43+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w18 >> 52) | (w19 << 12) & 0x7ffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*43+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w19 >> 31) | (w20 << 33) & 0x7ffffffffff, nb,parm);\
  OUT(op,i*64+30, (w20 >> 10) & 0x7ffffffffff, nb,parm);   w21 = *(uint32_t *)(ip+(i*43+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w20 >> 53) | (w21 << 11) & 0x7ffffffffff, nb,parm);;\
}

#define BITUNPACK64_43(ip,  op, nb,parm) { \
  BITUNBLK64_43(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 43*4/sizeof(ip[0]);\
}

#define BITUNBLK64_44(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21;   w0 = *(uint64_t *)(ip+(i*11+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xfffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*11+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 1, (w0 >> 44) | (w1 << 20) & 0xfffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*11+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 2, (w1 >> 24) | (w2 << 40) & 0xfffffffffff, nb,parm);\
  OUT(op,i*16+ 3, (w2 >>  4) & 0xfffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*11+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 4, (w2 >> 48) | (w3 << 16) & 0xfffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*11+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 5, (w3 >> 28) | (w4 << 36) & 0xfffffffffff, nb,parm);\
  OUT(op,i*16+ 6, (w4 >>  8) & 0xfffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*11+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 7, (w4 >> 52) | (w5 << 12) & 0xfffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*11+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 8, (w5 >> 32) | (w6 << 32) & 0xfffffffffff, nb,parm);\
  OUT(op,i*16+ 9, (w6 >> 12) & 0xfffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*11+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+10, (w6 >> 56) | (w7 <<  8) & 0xfffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*11+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+11, (w7 >> 36) | (w8 << 28) & 0xfffffffffff, nb,parm);\
  OUT(op,i*16+12, (w8 >> 16) & 0xfffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*11+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+13, (w8 >> 60) | (w9 <<  4) & 0xfffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*11+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+14, (w9 >> 40) | (w10 << 24) & 0xfffffffffff, nb,parm);\
  OUT(op,i*16+15, (w10 >> 20) , nb,parm);;\
}

#define BITUNPACK64_44(ip,  op, nb,parm) { \
  BITUNBLK64_44(ip, 0, op, nb,parm);\
  BITUNBLK64_44(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 44*4/sizeof(ip[0]);\
}

#define BITUNBLK64_45(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22;   w0 = *(uint64_t *)(ip+(i*45+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1fffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*45+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 45) | (w1 << 19) & 0x1fffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*45+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 26) | (w2 << 38) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+ 3, (w2 >>  7) & 0x1fffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*45+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w2 >> 52) | (w3 << 12) & 0x1fffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*45+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w3 >> 33) | (w4 << 31) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+ 6, (w4 >> 14) & 0x1fffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*45+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w4 >> 59) | (w5 <<  5) & 0x1fffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*45+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w5 >> 40) | (w6 << 24) & 0x1fffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*45+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w6 >> 21) | (w7 << 43) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+10, (w7 >>  2) & 0x1fffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*45+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w7 >> 47) | (w8 << 17) & 0x1fffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*45+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w8 >> 28) | (w9 << 36) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+13, (w9 >>  9) & 0x1fffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*45+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w9 >> 54) | (w10 << 10) & 0x1fffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*45+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w10 >> 35) | (w11 << 29) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+16, (w11 >> 16) & 0x1fffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*45+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w11 >> 61) | (w12 <<  3) & 0x1fffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*45+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w12 >> 42) | (w13 << 22) & 0x1fffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*45+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w13 >> 23) | (w14 << 41) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+20, (w14 >>  4) & 0x1fffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*45+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w14 >> 49) | (w15 << 15) & 0x1fffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*45+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w15 >> 30) | (w16 << 34) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+23, (w16 >> 11) & 0x1fffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*45+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w16 >> 56) | (w17 <<  8) & 0x1fffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*45+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w17 >> 37) | (w18 << 27) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+26, (w18 >> 18) & 0x1fffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*45+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w18 >> 63) | (w19 <<  1) & 0x1fffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*45+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w19 >> 44) | (w20 << 20) & 0x1fffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*45+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w20 >> 25) | (w21 << 39) & 0x1fffffffffff, nb,parm);\
  OUT(op,i*64+30, (w21 >>  6) & 0x1fffffffffff, nb,parm);   w22 = *(uint32_t *)(ip+(i*45+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w21 >> 51) | (w22 << 13) & 0x1fffffffffff, nb,parm);;\
}

#define BITUNPACK64_45(ip,  op, nb,parm) { \
  BITUNBLK64_45(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 45*4/sizeof(ip[0]);\
}

#define BITUNBLK64_46(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22;   w0 = *(uint64_t *)(ip+(i*23+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3fffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*23+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 46) | (w1 << 18) & 0x3fffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*23+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w1 >> 28) | (w2 << 36) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+ 3, (w2 >> 10) & 0x3fffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*23+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w2 >> 56) | (w3 <<  8) & 0x3fffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*23+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w3 >> 38) | (w4 << 26) & 0x3fffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*23+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w4 >> 20) | (w5 << 44) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+ 7, (w5 >>  2) & 0x3fffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*23+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w5 >> 48) | (w6 << 16) & 0x3fffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*23+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w6 >> 30) | (w7 << 34) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+10, (w7 >> 12) & 0x3fffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*23+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w7 >> 58) | (w8 <<  6) & 0x3fffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*23+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w8 >> 40) | (w9 << 24) & 0x3fffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*23+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w9 >> 22) | (w10 << 42) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+14, (w10 >>  4) & 0x3fffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*23+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w10 >> 50) | (w11 << 14) & 0x3fffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*23+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w11 >> 32) | (w12 << 32) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+17, (w12 >> 14) & 0x3fffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*23+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w12 >> 60) | (w13 <<  4) & 0x3fffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*23+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w13 >> 42) | (w14 << 22) & 0x3fffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*23+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w14 >> 24) | (w15 << 40) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+21, (w15 >>  6) & 0x3fffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*23+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w15 >> 52) | (w16 << 12) & 0x3fffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*23+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w16 >> 34) | (w17 << 30) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+24, (w17 >> 16) & 0x3fffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*23+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w17 >> 62) | (w18 <<  2) & 0x3fffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*23+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w18 >> 44) | (w19 << 20) & 0x3fffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*23+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w19 >> 26) | (w20 << 38) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+28, (w20 >>  8) & 0x3fffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*23+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w20 >> 54) | (w21 << 10) & 0x3fffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*23+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w21 >> 36) | (w22 << 28) & 0x3fffffffffff, nb,parm);\
  OUT(op,i*32+31, (w22 >> 18) , nb,parm);;\
}

#define BITUNPACK64_46(ip,  op, nb,parm) { \
  BITUNBLK64_46(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 46*4/sizeof(ip[0]);\
}

#define BITUNBLK64_47(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23;   w0 = *(uint64_t *)(ip+(i*47+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7fffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*47+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 47) | (w1 << 17) & 0x7fffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*47+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 30) | (w2 << 34) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+ 3, (w2 >> 13) & 0x7fffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*47+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w2 >> 60) | (w3 <<  4) & 0x7fffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*47+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w3 >> 43) | (w4 << 21) & 0x7fffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*47+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w4 >> 26) | (w5 << 38) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+ 7, (w5 >>  9) & 0x7fffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*47+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w5 >> 56) | (w6 <<  8) & 0x7fffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*47+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w6 >> 39) | (w7 << 25) & 0x7fffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*47+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w7 >> 22) | (w8 << 42) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+11, (w8 >>  5) & 0x7fffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*47+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w8 >> 52) | (w9 << 12) & 0x7fffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*47+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w9 >> 35) | (w10 << 29) & 0x7fffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*47+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w10 >> 18) | (w11 << 46) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+15, (w11 >>  1) & 0x7fffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*47+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w11 >> 48) | (w12 << 16) & 0x7fffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*47+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w12 >> 31) | (w13 << 33) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+18, (w13 >> 14) & 0x7fffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*47+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w13 >> 61) | (w14 <<  3) & 0x7fffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*47+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w14 >> 44) | (w15 << 20) & 0x7fffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*47+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w15 >> 27) | (w16 << 37) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+22, (w16 >> 10) & 0x7fffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*47+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w16 >> 57) | (w17 <<  7) & 0x7fffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*47+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w17 >> 40) | (w18 << 24) & 0x7fffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*47+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w18 >> 23) | (w19 << 41) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+26, (w19 >>  6) & 0x7fffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*47+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w19 >> 53) | (w20 << 11) & 0x7fffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*47+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w20 >> 36) | (w21 << 28) & 0x7fffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*47+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w21 >> 19) | (w22 << 45) & 0x7fffffffffff, nb,parm);\
  OUT(op,i*64+30, (w22 >>  2) & 0x7fffffffffff, nb,parm);   w23 = *(uint32_t *)(ip+(i*47+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w22 >> 49) | (w23 << 15) & 0x7fffffffffff, nb,parm);;\
}

#define BITUNPACK64_47(ip,  op, nb,parm) { \
  BITUNBLK64_47(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 47*4/sizeof(ip[0]);\
}

#define BITUNBLK64_48(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23;   w0 = *(uint64_t *)(ip+(i*3+0)*8/sizeof(ip[0]));\
  OUT(op,i*4+ 0, (w0 ) & 0xffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*3+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*4+ 1, (w0 >> 48) | (w1 << 16) & 0xffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*3+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*4+ 2, (w1 >> 32) | (w2 << 32) & 0xffffffffffff, nb,parm);\
  OUT(op,i*4+ 3, (w2 >> 16) , nb,parm);;\
}

#define BITUNPACK64_48(ip,  op, nb,parm) { \
  BITUNBLK64_48(ip, 0, op, nb,parm);\
  BITUNBLK64_48(ip, 1, op, nb,parm);\
  BITUNBLK64_48(ip, 2, op, nb,parm);\
  BITUNBLK64_48(ip, 3, op, nb,parm);\
  BITUNBLK64_48(ip, 4, op, nb,parm);\
  BITUNBLK64_48(ip, 5, op, nb,parm);\
  BITUNBLK64_48(ip, 6, op, nb,parm);\
  BITUNBLK64_48(ip, 7, op, nb,parm);  OPI(op, nb,parm); ip += 48*4/sizeof(ip[0]);\
}

#define BITUNBLK64_49(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24;   w0 = *(uint64_t *)(ip+(i*49+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1ffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*49+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 49) | (w1 << 15) & 0x1ffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*49+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 34) | (w2 << 30) & 0x1ffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*49+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 19) | (w3 << 45) & 0x1ffffffffffff, nb,parm);\
  OUT(op,i*64+ 4, (w3 >>  4) & 0x1ffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*49+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w3 >> 53) | (w4 << 11) & 0x1ffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*49+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w4 >> 38) | (w5 << 26) & 0x1ffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*49+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w5 >> 23) | (w6 << 41) & 0x1ffffffffffff, nb,parm);\
  OUT(op,i*64+ 8, (w6 >>  8) & 0x1ffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*49+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w6 >> 57) | (w7 <<  7) & 0x1ffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*49+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w7 >> 42) | (w8 << 22) & 0x1ffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*49+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w8 >> 27) | (w9 << 37) & 0x1ffffffffffff, nb,parm);\
  OUT(op,i*64+12, (w9 >> 12) & 0x1ffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*49+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w9 >> 61) | (w10 <<  3) & 0x1ffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*49+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w10 >> 46) | (w11 << 18) & 0x1ffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*49+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w11 >> 31) | (w12 << 33) & 0x1ffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*49+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w12 >> 16) | (w13 << 48) & 0x1ffffffffffff, nb,parm);\
  OUT(op,i*64+17, (w13 >>  1) & 0x1ffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*49+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w13 >> 50) | (w14 << 14) & 0x1ffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*49+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w14 >> 35) | (w15 << 29) & 0x1ffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*49+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w15 >> 20) | (w16 << 44) & 0x1ffffffffffff, nb,parm);\
  OUT(op,i*64+21, (w16 >>  5) & 0x1ffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*49+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w16 >> 54) | (w17 << 10) & 0x1ffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*49+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w17 >> 39) | (w18 << 25) & 0x1ffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*49+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w18 >> 24) | (w19 << 40) & 0x1ffffffffffff, nb,parm);\
  OUT(op,i*64+25, (w19 >>  9) & 0x1ffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*49+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w19 >> 58) | (w20 <<  6) & 0x1ffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*49+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w20 >> 43) | (w21 << 21) & 0x1ffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*49+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w21 >> 28) | (w22 << 36) & 0x1ffffffffffff, nb,parm);\
  OUT(op,i*64+29, (w22 >> 13) & 0x1ffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*49+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w22 >> 62) | (w23 <<  2) & 0x1ffffffffffff, nb,parm);   w24 = *(uint32_t *)(ip+(i*49+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w23 >> 47) | (w24 << 17) & 0x1ffffffffffff, nb,parm);;\
}

#define BITUNPACK64_49(ip,  op, nb,parm) { \
  BITUNBLK64_49(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 49*4/sizeof(ip[0]);\
}

#define BITUNBLK64_50(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24;   w0 = *(uint64_t *)(ip+(i*25+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3ffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*25+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 50) | (w1 << 14) & 0x3ffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*25+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w1 >> 36) | (w2 << 28) & 0x3ffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*25+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w2 >> 22) | (w3 << 42) & 0x3ffffffffffff, nb,parm);\
  OUT(op,i*32+ 4, (w3 >>  8) & 0x3ffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*25+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w3 >> 58) | (w4 <<  6) & 0x3ffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*25+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w4 >> 44) | (w5 << 20) & 0x3ffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*25+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w5 >> 30) | (w6 << 34) & 0x3ffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*25+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w6 >> 16) | (w7 << 48) & 0x3ffffffffffff, nb,parm);\
  OUT(op,i*32+ 9, (w7 >>  2) & 0x3ffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*25+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w7 >> 52) | (w8 << 12) & 0x3ffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*25+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w8 >> 38) | (w9 << 26) & 0x3ffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*25+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w9 >> 24) | (w10 << 40) & 0x3ffffffffffff, nb,parm);\
  OUT(op,i*32+13, (w10 >> 10) & 0x3ffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*25+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w10 >> 60) | (w11 <<  4) & 0x3ffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*25+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w11 >> 46) | (w12 << 18) & 0x3ffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*25+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w12 >> 32) | (w13 << 32) & 0x3ffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*25+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w13 >> 18) | (w14 << 46) & 0x3ffffffffffff, nb,parm);\
  OUT(op,i*32+18, (w14 >>  4) & 0x3ffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*25+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w14 >> 54) | (w15 << 10) & 0x3ffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*25+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w15 >> 40) | (w16 << 24) & 0x3ffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*25+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w16 >> 26) | (w17 << 38) & 0x3ffffffffffff, nb,parm);\
  OUT(op,i*32+22, (w17 >> 12) & 0x3ffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*25+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w17 >> 62) | (w18 <<  2) & 0x3ffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*25+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w18 >> 48) | (w19 << 16) & 0x3ffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*25+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w19 >> 34) | (w20 << 30) & 0x3ffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*25+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w20 >> 20) | (w21 << 44) & 0x3ffffffffffff, nb,parm);\
  OUT(op,i*32+27, (w21 >>  6) & 0x3ffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*25+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w21 >> 56) | (w22 <<  8) & 0x3ffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*25+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w22 >> 42) | (w23 << 22) & 0x3ffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*25+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w23 >> 28) | (w24 << 36) & 0x3ffffffffffff, nb,parm);\
  OUT(op,i*32+31, (w24 >> 14) , nb,parm);;\
}

#define BITUNPACK64_50(ip,  op, nb,parm) { \
  BITUNBLK64_50(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 50*4/sizeof(ip[0]);\
}

#define BITUNBLK64_51(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25;   w0 = *(uint64_t *)(ip+(i*51+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7ffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*51+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 51) | (w1 << 13) & 0x7ffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*51+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 38) | (w2 << 26) & 0x7ffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*51+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 25) | (w3 << 39) & 0x7ffffffffffff, nb,parm);\
  OUT(op,i*64+ 4, (w3 >> 12) & 0x7ffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*51+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w3 >> 63) | (w4 <<  1) & 0x7ffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*51+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w4 >> 50) | (w5 << 14) & 0x7ffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*51+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w5 >> 37) | (w6 << 27) & 0x7ffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*51+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w6 >> 24) | (w7 << 40) & 0x7ffffffffffff, nb,parm);\
  OUT(op,i*64+ 9, (w7 >> 11) & 0x7ffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*51+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w7 >> 62) | (w8 <<  2) & 0x7ffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*51+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w8 >> 49) | (w9 << 15) & 0x7ffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*51+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w9 >> 36) | (w10 << 28) & 0x7ffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*51+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w10 >> 23) | (w11 << 41) & 0x7ffffffffffff, nb,parm);\
  OUT(op,i*64+14, (w11 >> 10) & 0x7ffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*51+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w11 >> 61) | (w12 <<  3) & 0x7ffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*51+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w12 >> 48) | (w13 << 16) & 0x7ffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*51+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w13 >> 35) | (w14 << 29) & 0x7ffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*51+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w14 >> 22) | (w15 << 42) & 0x7ffffffffffff, nb,parm);\
  OUT(op,i*64+19, (w15 >>  9) & 0x7ffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*51+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w15 >> 60) | (w16 <<  4) & 0x7ffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*51+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w16 >> 47) | (w17 << 17) & 0x7ffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*51+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w17 >> 34) | (w18 << 30) & 0x7ffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*51+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w18 >> 21) | (w19 << 43) & 0x7ffffffffffff, nb,parm);\
  OUT(op,i*64+24, (w19 >>  8) & 0x7ffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*51+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w19 >> 59) | (w20 <<  5) & 0x7ffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*51+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w20 >> 46) | (w21 << 18) & 0x7ffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*51+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w21 >> 33) | (w22 << 31) & 0x7ffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*51+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w22 >> 20) | (w23 << 44) & 0x7ffffffffffff, nb,parm);\
  OUT(op,i*64+29, (w23 >>  7) & 0x7ffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*51+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w23 >> 58) | (w24 <<  6) & 0x7ffffffffffff, nb,parm);   w25 = *(uint32_t *)(ip+(i*51+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w24 >> 45) | (w25 << 19) & 0x7ffffffffffff, nb,parm);;\
}

#define BITUNPACK64_51(ip,  op, nb,parm) { \
  BITUNBLK64_51(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 51*4/sizeof(ip[0]);\
}

#define BITUNBLK64_52(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25;   w0 = *(uint64_t *)(ip+(i*13+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xfffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*13+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 1, (w0 >> 52) | (w1 << 12) & 0xfffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*13+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 2, (w1 >> 40) | (w2 << 24) & 0xfffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*13+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 3, (w2 >> 28) | (w3 << 36) & 0xfffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*13+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 4, (w3 >> 16) | (w4 << 48) & 0xfffffffffffff, nb,parm);\
  OUT(op,i*16+ 5, (w4 >>  4) & 0xfffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*13+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 6, (w4 >> 56) | (w5 <<  8) & 0xfffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*13+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 7, (w5 >> 44) | (w6 << 20) & 0xfffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*13+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 8, (w6 >> 32) | (w7 << 32) & 0xfffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*13+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 9, (w7 >> 20) | (w8 << 44) & 0xfffffffffffff, nb,parm);\
  OUT(op,i*16+10, (w8 >>  8) & 0xfffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*13+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+11, (w8 >> 60) | (w9 <<  4) & 0xfffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*13+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+12, (w9 >> 48) | (w10 << 16) & 0xfffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*13+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+13, (w10 >> 36) | (w11 << 28) & 0xfffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*13+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+14, (w11 >> 24) | (w12 << 40) & 0xfffffffffffff, nb,parm);\
  OUT(op,i*16+15, (w12 >> 12) , nb,parm);;\
}

#define BITUNPACK64_52(ip,  op, nb,parm) { \
  BITUNBLK64_52(ip, 0, op, nb,parm);\
  BITUNBLK64_52(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 52*4/sizeof(ip[0]);\
}

#define BITUNBLK64_53(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26;   w0 = *(uint64_t *)(ip+(i*53+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1fffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*53+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 53) | (w1 << 11) & 0x1fffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*53+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 42) | (w2 << 22) & 0x1fffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*53+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 31) | (w3 << 33) & 0x1fffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*53+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w3 >> 20) | (w4 << 44) & 0x1fffffffffffff, nb,parm);\
  OUT(op,i*64+ 5, (w4 >>  9) & 0x1fffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*53+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w4 >> 62) | (w5 <<  2) & 0x1fffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*53+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w5 >> 51) | (w6 << 13) & 0x1fffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*53+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w6 >> 40) | (w7 << 24) & 0x1fffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*53+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w7 >> 29) | (w8 << 35) & 0x1fffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*53+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w8 >> 18) | (w9 << 46) & 0x1fffffffffffff, nb,parm);\
  OUT(op,i*64+11, (w9 >>  7) & 0x1fffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*53+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w9 >> 60) | (w10 <<  4) & 0x1fffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*53+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w10 >> 49) | (w11 << 15) & 0x1fffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*53+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w11 >> 38) | (w12 << 26) & 0x1fffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*53+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w12 >> 27) | (w13 << 37) & 0x1fffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*53+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w13 >> 16) | (w14 << 48) & 0x1fffffffffffff, nb,parm);\
  OUT(op,i*64+17, (w14 >>  5) & 0x1fffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*53+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w14 >> 58) | (w15 <<  6) & 0x1fffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*53+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w15 >> 47) | (w16 << 17) & 0x1fffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*53+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w16 >> 36) | (w17 << 28) & 0x1fffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*53+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w17 >> 25) | (w18 << 39) & 0x1fffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*53+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w18 >> 14) | (w19 << 50) & 0x1fffffffffffff, nb,parm);\
  OUT(op,i*64+23, (w19 >>  3) & 0x1fffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*53+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w19 >> 56) | (w20 <<  8) & 0x1fffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*53+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w20 >> 45) | (w21 << 19) & 0x1fffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*53+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w21 >> 34) | (w22 << 30) & 0x1fffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*53+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w22 >> 23) | (w23 << 41) & 0x1fffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*53+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w23 >> 12) | (w24 << 52) & 0x1fffffffffffff, nb,parm);\
  OUT(op,i*64+29, (w24 >>  1) & 0x1fffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*53+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w24 >> 54) | (w25 << 10) & 0x1fffffffffffff, nb,parm);   w26 = *(uint32_t *)(ip+(i*53+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w25 >> 43) | (w26 << 21) & 0x1fffffffffffff, nb,parm);;\
}

#define BITUNPACK64_53(ip,  op, nb,parm) { \
  BITUNBLK64_53(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 53*4/sizeof(ip[0]);\
}

#define BITUNBLK64_54(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26;   w0 = *(uint64_t *)(ip+(i*27+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3fffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*27+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 54) | (w1 << 10) & 0x3fffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*27+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w1 >> 44) | (w2 << 20) & 0x3fffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*27+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w2 >> 34) | (w3 << 30) & 0x3fffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*27+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w3 >> 24) | (w4 << 40) & 0x3fffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*27+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w4 >> 14) | (w5 << 50) & 0x3fffffffffffff, nb,parm);\
  OUT(op,i*32+ 6, (w5 >>  4) & 0x3fffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*27+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w5 >> 58) | (w6 <<  6) & 0x3fffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*27+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w6 >> 48) | (w7 << 16) & 0x3fffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*27+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w7 >> 38) | (w8 << 26) & 0x3fffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*27+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w8 >> 28) | (w9 << 36) & 0x3fffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*27+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w9 >> 18) | (w10 << 46) & 0x3fffffffffffff, nb,parm);\
  OUT(op,i*32+12, (w10 >>  8) & 0x3fffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*27+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w10 >> 62) | (w11 <<  2) & 0x3fffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*27+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w11 >> 52) | (w12 << 12) & 0x3fffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*27+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w12 >> 42) | (w13 << 22) & 0x3fffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*27+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w13 >> 32) | (w14 << 32) & 0x3fffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*27+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w14 >> 22) | (w15 << 42) & 0x3fffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*27+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w15 >> 12) | (w16 << 52) & 0x3fffffffffffff, nb,parm);\
  OUT(op,i*32+19, (w16 >>  2) & 0x3fffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*27+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w16 >> 56) | (w17 <<  8) & 0x3fffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*27+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w17 >> 46) | (w18 << 18) & 0x3fffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*27+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w18 >> 36) | (w19 << 28) & 0x3fffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*27+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w19 >> 26) | (w20 << 38) & 0x3fffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*27+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w20 >> 16) | (w21 << 48) & 0x3fffffffffffff, nb,parm);\
  OUT(op,i*32+25, (w21 >>  6) & 0x3fffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*27+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w21 >> 60) | (w22 <<  4) & 0x3fffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*27+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w22 >> 50) | (w23 << 14) & 0x3fffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*27+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w23 >> 40) | (w24 << 24) & 0x3fffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*27+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w24 >> 30) | (w25 << 34) & 0x3fffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*27+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w25 >> 20) | (w26 << 44) & 0x3fffffffffffff, nb,parm);\
  OUT(op,i*32+31, (w26 >> 10) , nb,parm);;\
}

#define BITUNPACK64_54(ip,  op, nb,parm) { \
  BITUNBLK64_54(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 54*4/sizeof(ip[0]);\
}

#define BITUNBLK64_55(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27;   w0 = *(uint64_t *)(ip+(i*55+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7fffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*55+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 55) | (w1 <<  9) & 0x7fffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*55+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 46) | (w2 << 18) & 0x7fffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*55+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 37) | (w3 << 27) & 0x7fffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*55+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w3 >> 28) | (w4 << 36) & 0x7fffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*55+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w4 >> 19) | (w5 << 45) & 0x7fffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*55+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w5 >> 10) | (w6 << 54) & 0x7fffffffffffff, nb,parm);\
  OUT(op,i*64+ 7, (w6 >>  1) & 0x7fffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*55+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w6 >> 56) | (w7 <<  8) & 0x7fffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*55+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w7 >> 47) | (w8 << 17) & 0x7fffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*55+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w8 >> 38) | (w9 << 26) & 0x7fffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*55+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w9 >> 29) | (w10 << 35) & 0x7fffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*55+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w10 >> 20) | (w11 << 44) & 0x7fffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*55+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w11 >> 11) | (w12 << 53) & 0x7fffffffffffff, nb,parm);\
  OUT(op,i*64+14, (w12 >>  2) & 0x7fffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*55+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w12 >> 57) | (w13 <<  7) & 0x7fffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*55+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w13 >> 48) | (w14 << 16) & 0x7fffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*55+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w14 >> 39) | (w15 << 25) & 0x7fffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*55+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w15 >> 30) | (w16 << 34) & 0x7fffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*55+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w16 >> 21) | (w17 << 43) & 0x7fffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*55+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w17 >> 12) | (w18 << 52) & 0x7fffffffffffff, nb,parm);\
  OUT(op,i*64+21, (w18 >>  3) & 0x7fffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*55+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w18 >> 58) | (w19 <<  6) & 0x7fffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*55+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w19 >> 49) | (w20 << 15) & 0x7fffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*55+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w20 >> 40) | (w21 << 24) & 0x7fffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*55+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w21 >> 31) | (w22 << 33) & 0x7fffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*55+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w22 >> 22) | (w23 << 42) & 0x7fffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*55+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w23 >> 13) | (w24 << 51) & 0x7fffffffffffff, nb,parm);\
  OUT(op,i*64+28, (w24 >>  4) & 0x7fffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*55+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w24 >> 59) | (w25 <<  5) & 0x7fffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*55+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w25 >> 50) | (w26 << 14) & 0x7fffffffffffff, nb,parm);   w27 = *(uint32_t *)(ip+(i*55+27)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w26 >> 41) | (w27 << 23) & 0x7fffffffffffff, nb,parm);;\
}

#define BITUNPACK64_55(ip,  op, nb,parm) { \
  BITUNBLK64_55(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 55*4/sizeof(ip[0]);\
}

#define BITUNBLK64_56(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27;   w0 = *(uint64_t *)(ip+(i*7+0)*8/sizeof(ip[0]));\
  OUT(op,i*8+ 0, (w0 ) & 0xffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*7+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 1, (w0 >> 56) | (w1 <<  8) & 0xffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*7+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 2, (w1 >> 48) | (w2 << 16) & 0xffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*7+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 3, (w2 >> 40) | (w3 << 24) & 0xffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*7+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 4, (w3 >> 32) | (w4 << 32) & 0xffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*7+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 5, (w4 >> 24) | (w5 << 40) & 0xffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*7+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*8+ 6, (w5 >> 16) | (w6 << 48) & 0xffffffffffffff, nb,parm);\
  OUT(op,i*8+ 7, (w6 >>  8) , nb,parm);;\
}

#define BITUNPACK64_56(ip,  op, nb,parm) { \
  BITUNBLK64_56(ip, 0, op, nb,parm);\
  BITUNBLK64_56(ip, 1, op, nb,parm);\
  BITUNBLK64_56(ip, 2, op, nb,parm);\
  BITUNBLK64_56(ip, 3, op, nb,parm);  OPI(op, nb,parm); ip += 56*4/sizeof(ip[0]);\
}

#define BITUNBLK64_57(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28;   w0 = *(uint64_t *)(ip+(i*57+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1ffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*57+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 57) | (w1 <<  7) & 0x1ffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*57+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 50) | (w2 << 14) & 0x1ffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*57+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 43) | (w3 << 21) & 0x1ffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*57+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w3 >> 36) | (w4 << 28) & 0x1ffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*57+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w4 >> 29) | (w5 << 35) & 0x1ffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*57+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w5 >> 22) | (w6 << 42) & 0x1ffffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*57+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w6 >> 15) | (w7 << 49) & 0x1ffffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*57+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w7 >> 8) | (w8 << 56) & 0x1ffffffffffffff, nb,parm);\
  OUT(op,i*64+ 9, (w8 >>  1) & 0x1ffffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*57+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w8 >> 58) | (w9 <<  6) & 0x1ffffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*57+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w9 >> 51) | (w10 << 13) & 0x1ffffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*57+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w10 >> 44) | (w11 << 20) & 0x1ffffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*57+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w11 >> 37) | (w12 << 27) & 0x1ffffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*57+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w12 >> 30) | (w13 << 34) & 0x1ffffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*57+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w13 >> 23) | (w14 << 41) & 0x1ffffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*57+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w14 >> 16) | (w15 << 48) & 0x1ffffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*57+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w15 >> 9) | (w16 << 55) & 0x1ffffffffffffff, nb,parm);\
  OUT(op,i*64+18, (w16 >>  2) & 0x1ffffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*57+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w16 >> 59) | (w17 <<  5) & 0x1ffffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*57+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w17 >> 52) | (w18 << 12) & 0x1ffffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*57+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w18 >> 45) | (w19 << 19) & 0x1ffffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*57+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w19 >> 38) | (w20 << 26) & 0x1ffffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*57+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w20 >> 31) | (w21 << 33) & 0x1ffffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*57+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w21 >> 24) | (w22 << 40) & 0x1ffffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*57+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w22 >> 17) | (w23 << 47) & 0x1ffffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*57+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w23 >> 10) | (w24 << 54) & 0x1ffffffffffffff, nb,parm);\
  OUT(op,i*64+27, (w24 >>  3) & 0x1ffffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*57+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w24 >> 60) | (w25 <<  4) & 0x1ffffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*57+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w25 >> 53) | (w26 << 11) & 0x1ffffffffffffff, nb,parm);   w27 = *(uint64_t *)(ip+(i*57+27)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w26 >> 46) | (w27 << 18) & 0x1ffffffffffffff, nb,parm);   w28 = *(uint32_t *)(ip+(i*57+28)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w27 >> 39) | (w28 << 25) & 0x1ffffffffffffff, nb,parm);;\
}

#define BITUNPACK64_57(ip,  op, nb,parm) { \
  BITUNBLK64_57(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 57*4/sizeof(ip[0]);\
}

#define BITUNBLK64_58(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28;   w0 = *(uint64_t *)(ip+(i*29+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3ffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*29+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 58) | (w1 <<  6) & 0x3ffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*29+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w1 >> 52) | (w2 << 12) & 0x3ffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*29+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w2 >> 46) | (w3 << 18) & 0x3ffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*29+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w3 >> 40) | (w4 << 24) & 0x3ffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*29+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w4 >> 34) | (w5 << 30) & 0x3ffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*29+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w5 >> 28) | (w6 << 36) & 0x3ffffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*29+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w6 >> 22) | (w7 << 42) & 0x3ffffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*29+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w7 >> 16) | (w8 << 48) & 0x3ffffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*29+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w8 >> 10) | (w9 << 54) & 0x3ffffffffffffff, nb,parm);\
  OUT(op,i*32+10, (w9 >>  4) & 0x3ffffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*29+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w9 >> 62) | (w10 <<  2) & 0x3ffffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*29+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w10 >> 56) | (w11 <<  8) & 0x3ffffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*29+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w11 >> 50) | (w12 << 14) & 0x3ffffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*29+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w12 >> 44) | (w13 << 20) & 0x3ffffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*29+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w13 >> 38) | (w14 << 26) & 0x3ffffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*29+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w14 >> 32) | (w15 << 32) & 0x3ffffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*29+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w15 >> 26) | (w16 << 38) & 0x3ffffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*29+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w16 >> 20) | (w17 << 44) & 0x3ffffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*29+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w17 >> 14) | (w18 << 50) & 0x3ffffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*29+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w18 >> 8) | (w19 << 56) & 0x3ffffffffffffff, nb,parm);\
  OUT(op,i*32+21, (w19 >>  2) & 0x3ffffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*29+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w19 >> 60) | (w20 <<  4) & 0x3ffffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*29+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w20 >> 54) | (w21 << 10) & 0x3ffffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*29+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w21 >> 48) | (w22 << 16) & 0x3ffffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*29+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w22 >> 42) | (w23 << 22) & 0x3ffffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*29+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w23 >> 36) | (w24 << 28) & 0x3ffffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*29+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w24 >> 30) | (w25 << 34) & 0x3ffffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*29+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w25 >> 24) | (w26 << 40) & 0x3ffffffffffffff, nb,parm);   w27 = *(uint64_t *)(ip+(i*29+27)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w26 >> 18) | (w27 << 46) & 0x3ffffffffffffff, nb,parm);   w28 = *(uint64_t *)(ip+(i*29+28)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w27 >> 12) | (w28 << 52) & 0x3ffffffffffffff, nb,parm);\
  OUT(op,i*32+31, (w28 >>  6) , nb,parm);;\
}

#define BITUNPACK64_58(ip,  op, nb,parm) { \
  BITUNBLK64_58(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 58*4/sizeof(ip[0]);\
}

#define BITUNBLK64_59(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28,w29;   w0 = *(uint64_t *)(ip+(i*59+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7ffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*59+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 59) | (w1 <<  5) & 0x7ffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*59+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 54) | (w2 << 10) & 0x7ffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*59+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 49) | (w3 << 15) & 0x7ffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*59+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w3 >> 44) | (w4 << 20) & 0x7ffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*59+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w4 >> 39) | (w5 << 25) & 0x7ffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*59+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w5 >> 34) | (w6 << 30) & 0x7ffffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*59+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w6 >> 29) | (w7 << 35) & 0x7ffffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*59+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w7 >> 24) | (w8 << 40) & 0x7ffffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*59+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w8 >> 19) | (w9 << 45) & 0x7ffffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*59+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w9 >> 14) | (w10 << 50) & 0x7ffffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*59+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w10 >> 9) | (w11 << 55) & 0x7ffffffffffffff, nb,parm);\
  OUT(op,i*64+12, (w11 >>  4) & 0x7ffffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*59+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w11 >> 63) | (w12 <<  1) & 0x7ffffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*59+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w12 >> 58) | (w13 <<  6) & 0x7ffffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*59+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w13 >> 53) | (w14 << 11) & 0x7ffffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*59+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w14 >> 48) | (w15 << 16) & 0x7ffffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*59+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w15 >> 43) | (w16 << 21) & 0x7ffffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*59+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w16 >> 38) | (w17 << 26) & 0x7ffffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*59+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w17 >> 33) | (w18 << 31) & 0x7ffffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*59+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w18 >> 28) | (w19 << 36) & 0x7ffffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*59+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w19 >> 23) | (w20 << 41) & 0x7ffffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*59+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w20 >> 18) | (w21 << 46) & 0x7ffffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*59+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w21 >> 13) | (w22 << 51) & 0x7ffffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*59+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w22 >> 8) | (w23 << 56) & 0x7ffffffffffffff, nb,parm);\
  OUT(op,i*64+25, (w23 >>  3) & 0x7ffffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*59+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w23 >> 62) | (w24 <<  2) & 0x7ffffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*59+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w24 >> 57) | (w25 <<  7) & 0x7ffffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*59+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w25 >> 52) | (w26 << 12) & 0x7ffffffffffffff, nb,parm);   w27 = *(uint64_t *)(ip+(i*59+27)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w26 >> 47) | (w27 << 17) & 0x7ffffffffffffff, nb,parm);   w28 = *(uint64_t *)(ip+(i*59+28)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w27 >> 42) | (w28 << 22) & 0x7ffffffffffffff, nb,parm);   w29 = *(uint32_t *)(ip+(i*59+29)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w28 >> 37) | (w29 << 27) & 0x7ffffffffffffff, nb,parm);;\
}

#define BITUNPACK64_59(ip,  op, nb,parm) { \
  BITUNBLK64_59(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 59*4/sizeof(ip[0]);\
}

#define BITUNBLK64_60(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28,w29;   w0 = *(uint64_t *)(ip+(i*15+0)*8/sizeof(ip[0]));\
  OUT(op,i*16+ 0, (w0 ) & 0xfffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*15+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 1, (w0 >> 60) | (w1 <<  4) & 0xfffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*15+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 2, (w1 >> 56) | (w2 <<  8) & 0xfffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*15+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 3, (w2 >> 52) | (w3 << 12) & 0xfffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*15+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 4, (w3 >> 48) | (w4 << 16) & 0xfffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*15+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 5, (w4 >> 44) | (w5 << 20) & 0xfffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*15+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 6, (w5 >> 40) | (w6 << 24) & 0xfffffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*15+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 7, (w6 >> 36) | (w7 << 28) & 0xfffffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*15+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 8, (w7 >> 32) | (w8 << 32) & 0xfffffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*15+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+ 9, (w8 >> 28) | (w9 << 36) & 0xfffffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*15+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+10, (w9 >> 24) | (w10 << 40) & 0xfffffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*15+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+11, (w10 >> 20) | (w11 << 44) & 0xfffffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*15+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+12, (w11 >> 16) | (w12 << 48) & 0xfffffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*15+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+13, (w12 >> 12) | (w13 << 52) & 0xfffffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*15+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*16+14, (w13 >> 8) | (w14 << 56) & 0xfffffffffffffff, nb,parm);\
  OUT(op,i*16+15, (w14 >>  4) , nb,parm);;\
}

#define BITUNPACK64_60(ip,  op, nb,parm) { \
  BITUNBLK64_60(ip, 0, op, nb,parm);\
  BITUNBLK64_60(ip, 1, op, nb,parm);  OPI(op, nb,parm); ip += 60*4/sizeof(ip[0]);\
}

#define BITUNBLK64_61(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28,w29,w30;   w0 = *(uint64_t *)(ip+(i*61+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x1fffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*61+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 61) | (w1 <<  3) & 0x1fffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*61+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 58) | (w2 <<  6) & 0x1fffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*61+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 55) | (w3 <<  9) & 0x1fffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*61+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w3 >> 52) | (w4 << 12) & 0x1fffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*61+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w4 >> 49) | (w5 << 15) & 0x1fffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*61+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w5 >> 46) | (w6 << 18) & 0x1fffffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*61+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w6 >> 43) | (w7 << 21) & 0x1fffffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*61+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w7 >> 40) | (w8 << 24) & 0x1fffffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*61+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w8 >> 37) | (w9 << 27) & 0x1fffffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*61+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w9 >> 34) | (w10 << 30) & 0x1fffffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*61+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w10 >> 31) | (w11 << 33) & 0x1fffffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*61+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w11 >> 28) | (w12 << 36) & 0x1fffffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*61+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w12 >> 25) | (w13 << 39) & 0x1fffffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*61+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w13 >> 22) | (w14 << 42) & 0x1fffffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*61+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w14 >> 19) | (w15 << 45) & 0x1fffffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*61+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w15 >> 16) | (w16 << 48) & 0x1fffffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*61+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w16 >> 13) | (w17 << 51) & 0x1fffffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*61+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w17 >> 10) | (w18 << 54) & 0x1fffffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*61+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w18 >> 7) | (w19 << 57) & 0x1fffffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*61+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w19 >> 4) | (w20 << 60) & 0x1fffffffffffffff, nb,parm);\
  OUT(op,i*64+21, (w20 >>  1) & 0x1fffffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*61+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w20 >> 62) | (w21 <<  2) & 0x1fffffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*61+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w21 >> 59) | (w22 <<  5) & 0x1fffffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*61+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w22 >> 56) | (w23 <<  8) & 0x1fffffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*61+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w23 >> 53) | (w24 << 11) & 0x1fffffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*61+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w24 >> 50) | (w25 << 14) & 0x1fffffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*61+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w25 >> 47) | (w26 << 17) & 0x1fffffffffffffff, nb,parm);   w27 = *(uint64_t *)(ip+(i*61+27)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w26 >> 44) | (w27 << 20) & 0x1fffffffffffffff, nb,parm);   w28 = *(uint64_t *)(ip+(i*61+28)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w27 >> 41) | (w28 << 23) & 0x1fffffffffffffff, nb,parm);   w29 = *(uint64_t *)(ip+(i*61+29)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w28 >> 38) | (w29 << 26) & 0x1fffffffffffffff, nb,parm);   w30 = *(uint32_t *)(ip+(i*61+30)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w29 >> 35) | (w30 << 29) & 0x1fffffffffffffff, nb,parm);;\
}

#define BITUNPACK64_61(ip,  op, nb,parm) { \
  BITUNBLK64_61(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 61*4/sizeof(ip[0]);\
}

#define BITUNBLK64_62(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28,w29,w30;   w0 = *(uint64_t *)(ip+(i*31+0)*8/sizeof(ip[0]));\
  OUT(op,i*32+ 0, (w0 ) & 0x3fffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*31+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 1, (w0 >> 62) | (w1 <<  2) & 0x3fffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*31+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 2, (w1 >> 60) | (w2 <<  4) & 0x3fffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*31+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 3, (w2 >> 58) | (w3 <<  6) & 0x3fffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*31+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 4, (w3 >> 56) | (w4 <<  8) & 0x3fffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*31+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 5, (w4 >> 54) | (w5 << 10) & 0x3fffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*31+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 6, (w5 >> 52) | (w6 << 12) & 0x3fffffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*31+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 7, (w6 >> 50) | (w7 << 14) & 0x3fffffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*31+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 8, (w7 >> 48) | (w8 << 16) & 0x3fffffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*31+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+ 9, (w8 >> 46) | (w9 << 18) & 0x3fffffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*31+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+10, (w9 >> 44) | (w10 << 20) & 0x3fffffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*31+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+11, (w10 >> 42) | (w11 << 22) & 0x3fffffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*31+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+12, (w11 >> 40) | (w12 << 24) & 0x3fffffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*31+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+13, (w12 >> 38) | (w13 << 26) & 0x3fffffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*31+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+14, (w13 >> 36) | (w14 << 28) & 0x3fffffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*31+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+15, (w14 >> 34) | (w15 << 30) & 0x3fffffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*31+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+16, (w15 >> 32) | (w16 << 32) & 0x3fffffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*31+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+17, (w16 >> 30) | (w17 << 34) & 0x3fffffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*31+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+18, (w17 >> 28) | (w18 << 36) & 0x3fffffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*31+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+19, (w18 >> 26) | (w19 << 38) & 0x3fffffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*31+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+20, (w19 >> 24) | (w20 << 40) & 0x3fffffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*31+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+21, (w20 >> 22) | (w21 << 42) & 0x3fffffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*31+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+22, (w21 >> 20) | (w22 << 44) & 0x3fffffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*31+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+23, (w22 >> 18) | (w23 << 46) & 0x3fffffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*31+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+24, (w23 >> 16) | (w24 << 48) & 0x3fffffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*31+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+25, (w24 >> 14) | (w25 << 50) & 0x3fffffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*31+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+26, (w25 >> 12) | (w26 << 52) & 0x3fffffffffffffff, nb,parm);   w27 = *(uint64_t *)(ip+(i*31+27)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+27, (w26 >> 10) | (w27 << 54) & 0x3fffffffffffffff, nb,parm);   w28 = *(uint64_t *)(ip+(i*31+28)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+28, (w27 >> 8) | (w28 << 56) & 0x3fffffffffffffff, nb,parm);   w29 = *(uint64_t *)(ip+(i*31+29)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+29, (w28 >> 6) | (w29 << 58) & 0x3fffffffffffffff, nb,parm);   w30 = *(uint64_t *)(ip+(i*31+30)*8/sizeof(ip[0]));\
\
  OUT(op,i*32+30, (w29 >> 4) | (w30 << 60) & 0x3fffffffffffffff, nb,parm);\
  OUT(op,i*32+31, (w30 >>  2) , nb,parm);;\
}

#define BITUNPACK64_62(ip,  op, nb,parm) { \
  BITUNBLK64_62(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 62*4/sizeof(ip[0]);\
}

#define BITUNBLK64_63(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28,w29,w30,w31;   w0 = *(uint64_t *)(ip+(i*63+0)*8/sizeof(ip[0]));\
  OUT(op,i*64+ 0, (w0 ) & 0x7fffffffffffffff, nb,parm);   w1 = *(uint64_t *)(ip+(i*63+1)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 1, (w0 >> 63) | (w1 <<  1) & 0x7fffffffffffffff, nb,parm);   w2 = *(uint64_t *)(ip+(i*63+2)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 2, (w1 >> 62) | (w2 <<  2) & 0x7fffffffffffffff, nb,parm);   w3 = *(uint64_t *)(ip+(i*63+3)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 3, (w2 >> 61) | (w3 <<  3) & 0x7fffffffffffffff, nb,parm);   w4 = *(uint64_t *)(ip+(i*63+4)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 4, (w3 >> 60) | (w4 <<  4) & 0x7fffffffffffffff, nb,parm);   w5 = *(uint64_t *)(ip+(i*63+5)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 5, (w4 >> 59) | (w5 <<  5) & 0x7fffffffffffffff, nb,parm);   w6 = *(uint64_t *)(ip+(i*63+6)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 6, (w5 >> 58) | (w6 <<  6) & 0x7fffffffffffffff, nb,parm);   w7 = *(uint64_t *)(ip+(i*63+7)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 7, (w6 >> 57) | (w7 <<  7) & 0x7fffffffffffffff, nb,parm);   w8 = *(uint64_t *)(ip+(i*63+8)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 8, (w7 >> 56) | (w8 <<  8) & 0x7fffffffffffffff, nb,parm);   w9 = *(uint64_t *)(ip+(i*63+9)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+ 9, (w8 >> 55) | (w9 <<  9) & 0x7fffffffffffffff, nb,parm);   w10 = *(uint64_t *)(ip+(i*63+10)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+10, (w9 >> 54) | (w10 << 10) & 0x7fffffffffffffff, nb,parm);   w11 = *(uint64_t *)(ip+(i*63+11)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+11, (w10 >> 53) | (w11 << 11) & 0x7fffffffffffffff, nb,parm);   w12 = *(uint64_t *)(ip+(i*63+12)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+12, (w11 >> 52) | (w12 << 12) & 0x7fffffffffffffff, nb,parm);   w13 = *(uint64_t *)(ip+(i*63+13)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+13, (w12 >> 51) | (w13 << 13) & 0x7fffffffffffffff, nb,parm);   w14 = *(uint64_t *)(ip+(i*63+14)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+14, (w13 >> 50) | (w14 << 14) & 0x7fffffffffffffff, nb,parm);   w15 = *(uint64_t *)(ip+(i*63+15)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+15, (w14 >> 49) | (w15 << 15) & 0x7fffffffffffffff, nb,parm);   w16 = *(uint64_t *)(ip+(i*63+16)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+16, (w15 >> 48) | (w16 << 16) & 0x7fffffffffffffff, nb,parm);   w17 = *(uint64_t *)(ip+(i*63+17)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+17, (w16 >> 47) | (w17 << 17) & 0x7fffffffffffffff, nb,parm);   w18 = *(uint64_t *)(ip+(i*63+18)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+18, (w17 >> 46) | (w18 << 18) & 0x7fffffffffffffff, nb,parm);   w19 = *(uint64_t *)(ip+(i*63+19)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+19, (w18 >> 45) | (w19 << 19) & 0x7fffffffffffffff, nb,parm);   w20 = *(uint64_t *)(ip+(i*63+20)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+20, (w19 >> 44) | (w20 << 20) & 0x7fffffffffffffff, nb,parm);   w21 = *(uint64_t *)(ip+(i*63+21)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+21, (w20 >> 43) | (w21 << 21) & 0x7fffffffffffffff, nb,parm);   w22 = *(uint64_t *)(ip+(i*63+22)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+22, (w21 >> 42) | (w22 << 22) & 0x7fffffffffffffff, nb,parm);   w23 = *(uint64_t *)(ip+(i*63+23)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+23, (w22 >> 41) | (w23 << 23) & 0x7fffffffffffffff, nb,parm);   w24 = *(uint64_t *)(ip+(i*63+24)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+24, (w23 >> 40) | (w24 << 24) & 0x7fffffffffffffff, nb,parm);   w25 = *(uint64_t *)(ip+(i*63+25)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+25, (w24 >> 39) | (w25 << 25) & 0x7fffffffffffffff, nb,parm);   w26 = *(uint64_t *)(ip+(i*63+26)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+26, (w25 >> 38) | (w26 << 26) & 0x7fffffffffffffff, nb,parm);   w27 = *(uint64_t *)(ip+(i*63+27)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+27, (w26 >> 37) | (w27 << 27) & 0x7fffffffffffffff, nb,parm);   w28 = *(uint64_t *)(ip+(i*63+28)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+28, (w27 >> 36) | (w28 << 28) & 0x7fffffffffffffff, nb,parm);   w29 = *(uint64_t *)(ip+(i*63+29)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+29, (w28 >> 35) | (w29 << 29) & 0x7fffffffffffffff, nb,parm);   w30 = *(uint64_t *)(ip+(i*63+30)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+30, (w29 >> 34) | (w30 << 30) & 0x7fffffffffffffff, nb,parm);   w31 = *(uint32_t *)(ip+(i*63+31)*8/sizeof(ip[0]));\
\
  OUT(op,i*64+31, (w30 >> 33) | (w31 << 31) & 0x7fffffffffffffff, nb,parm);;\
}

#define BITUNPACK64_63(ip,  op, nb,parm) { \
  BITUNBLK64_63(ip, 0, op, nb,parm);  OPI(op, nb,parm); ip += 63*4/sizeof(ip[0]);\
}

#define BITUNBLK64_64(ip, i, op, nb,parm) { uint64_t w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,w20,w21,w22,w23,w24,w25,w26,w27,w28,w29,w30,w31;   w0 = *(uint64_t *)(ip+(i*1+0)*8/sizeof(ip[0]));\
  OUT(op,i*1+ 0, (w0 ) , nb,parm);;\
}

#define BITUNPACK64_64(ip,  op, nb,parm) { \
  BITUNBLK64_64(ip, 0, op, nb,parm);\
  BITUNBLK64_64(ip, 1, op, nb,parm);\
  BITUNBLK64_64(ip, 2, op, nb,parm);\
  BITUNBLK64_64(ip, 3, op, nb,parm);\
  BITUNBLK64_64(ip, 4, op, nb,parm);\
  BITUNBLK64_64(ip, 5, op, nb,parm);\
  BITUNBLK64_64(ip, 6, op, nb,parm);\
  BITUNBLK64_64(ip, 7, op, nb,parm);\
  BITUNBLK64_64(ip, 8, op, nb,parm);\
  BITUNBLK64_64(ip, 9, op, nb,parm);\
  BITUNBLK64_64(ip, 10, op, nb,parm);\
  BITUNBLK64_64(ip, 11, op, nb,parm);\
  BITUNBLK64_64(ip, 12, op, nb,parm);\
  BITUNBLK64_64(ip, 13, op, nb,parm);\
  BITUNBLK64_64(ip, 14, op, nb,parm);\
  BITUNBLK64_64(ip, 15, op, nb,parm);\
  BITUNBLK64_64(ip, 16, op, nb,parm);\
  BITUNBLK64_64(ip, 17, op, nb,parm);\
  BITUNBLK64_64(ip, 18, op, nb,parm);\
  BITUNBLK64_64(ip, 19, op, nb,parm);\
  BITUNBLK64_64(ip, 20, op, nb,parm);\
  BITUNBLK64_64(ip, 21, op, nb,parm);\
  BITUNBLK64_64(ip, 22, op, nb,parm);\
  BITUNBLK64_64(ip, 23, op, nb,parm);\
  BITUNBLK64_64(ip, 24, op, nb,parm);\
  BITUNBLK64_64(ip, 25, op, nb,parm);\
  BITUNBLK64_64(ip, 26, op, nb,parm);\
  BITUNBLK64_64(ip, 27, op, nb,parm);\
  BITUNBLK64_64(ip, 28, op, nb,parm);\
  BITUNBLK64_64(ip, 29, op, nb,parm);\
  BITUNBLK64_64(ip, 30, op, nb,parm);\
  BITUNBLK64_64(ip, 31, op, nb,parm);  OPI(op, nb,parm); ip += 64*4/sizeof(ip[0]);\
}

#ifndef DELTA
#define USIZE 8
unsigned char *TEMPLATE2(_BITUNPACK_,8_0)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*0); const uint8_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_1)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*1); do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_2)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*2); do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_3)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*3); do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_4)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*4); do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_5)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*5); do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_6)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*6); do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_7)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*7); do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_8)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*8); do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_F8 TEMPLATE2(_BITUNPACK_,a8)[] = {
  &TEMPLATE2(_BITUNPACK_,8_0),
  &TEMPLATE2(_BITUNPACK_,8_1),
  &TEMPLATE2(_BITUNPACK_,8_2),
  &TEMPLATE2(_BITUNPACK_,8_3),
  &TEMPLATE2(_BITUNPACK_,8_4),
  &TEMPLATE2(_BITUNPACK_,8_5),
  &TEMPLATE2(_BITUNPACK_,8_6),
  &TEMPLATE2(_BITUNPACK_,8_7),
  &TEMPLATE2(_BITUNPACK_,8_8)
};
unsigned char *TEMPLATE2(_BITUNPACK_,8)( const unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out , unsigned b) { return TEMPLATE2(_BITUNPACK_,a8)[ b](in, n, out); }

#define USIZE 16
unsigned char *TEMPLATE2(_BITUNPACK_,16_0)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*0); const uint16_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_1)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*1); do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_2)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*2); do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_3)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*3); do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_4)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*4); do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_5)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*5); do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_6)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*6); do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_7)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*7); do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_8)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*8); do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_9)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*9); do { BITUNPACK64_9( in, out, 9,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_10)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*10); do { BITUNPACK64_10( in, out, 10,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_11)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*11); do { BITUNPACK64_11( in, out, 11,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_12)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*12); do { BITUNPACK64_12( in, out, 12,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_13)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*13); do { BITUNPACK64_13( in, out, 13,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_14)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*14); do { BITUNPACK64_14( in, out, 14,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_15)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*15); do { BITUNPACK64_15( in, out, 15,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_16)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*16); do { BITUNPACK64_16( in, out, 16,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_F16 TEMPLATE2(_BITUNPACK_,a16)[] = {
  &TEMPLATE2(_BITUNPACK_,16_0),
  &TEMPLATE2(_BITUNPACK_,16_1),
  &TEMPLATE2(_BITUNPACK_,16_2),
  &TEMPLATE2(_BITUNPACK_,16_3),
  &TEMPLATE2(_BITUNPACK_,16_4),
  &TEMPLATE2(_BITUNPACK_,16_5),
  &TEMPLATE2(_BITUNPACK_,16_6),
  &TEMPLATE2(_BITUNPACK_,16_7),
  &TEMPLATE2(_BITUNPACK_,16_8),
  &TEMPLATE2(_BITUNPACK_,16_9),
  &TEMPLATE2(_BITUNPACK_,16_10),
  &TEMPLATE2(_BITUNPACK_,16_11),
  &TEMPLATE2(_BITUNPACK_,16_12),
  &TEMPLATE2(_BITUNPACK_,16_13),
  &TEMPLATE2(_BITUNPACK_,16_14),
  &TEMPLATE2(_BITUNPACK_,16_15),
  &TEMPLATE2(_BITUNPACK_,16_16)
};
unsigned char *TEMPLATE2(_BITUNPACK_,16)( const unsigned char *__restrict in, unsigned n, uint16_t  *__restrict out , unsigned b) { return TEMPLATE2(_BITUNPACK_,a16)[ b](in, n, out); }

#define USIZE 32
unsigned char *TEMPLATE2(_BITUNPACK_,32_0)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*0); const uint32_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_1)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*1); do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_2)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*2); do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_3)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*3); do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_4)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*4); do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_5)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*5); do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_6)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*6); do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_7)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*7); do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_8)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*8); do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_9)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*9); do { BITUNPACK64_9( in, out, 9,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_10)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*10); do { BITUNPACK64_10( in, out, 10,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_11)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*11); do { BITUNPACK64_11( in, out, 11,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_12)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*12); do { BITUNPACK64_12( in, out, 12,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_13)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*13); do { BITUNPACK64_13( in, out, 13,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_14)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*14); do { BITUNPACK64_14( in, out, 14,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_15)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*15); do { BITUNPACK64_15( in, out, 15,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_16)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*16); do { BITUNPACK64_16( in, out, 16,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_17)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*17); do { BITUNPACK64_17( in, out, 17,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_18)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*18); do { BITUNPACK64_18( in, out, 18,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_19)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*19); do { BITUNPACK64_19( in, out, 19,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_20)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*20); do { BITUNPACK64_20( in, out, 20,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_21)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*21); do { BITUNPACK64_21( in, out, 21,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_22)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*22); do { BITUNPACK64_22( in, out, 22,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_23)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*23); do { BITUNPACK64_23( in, out, 23,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_24)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*24); do { BITUNPACK64_24( in, out, 24,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_25)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*25); do { BITUNPACK64_25( in, out, 25,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_26)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*26); do { BITUNPACK64_26( in, out, 26,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_27)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*27); do { BITUNPACK64_27( in, out, 27,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_28)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*28); do { BITUNPACK64_28( in, out, 28,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_29)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*29); do { BITUNPACK64_29( in, out, 29,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_30)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*30); do { BITUNPACK64_30( in, out, 30,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_31)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*31); do { BITUNPACK64_31( in, out, 31,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_32)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*32); do { BITUNPACK64_32( in, out, 32,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_F32 TEMPLATE2(_BITUNPACK_,a32)[] = {
  &TEMPLATE2(_BITUNPACK_,32_0),
  &TEMPLATE2(_BITUNPACK_,32_1),
  &TEMPLATE2(_BITUNPACK_,32_2),
  &TEMPLATE2(_BITUNPACK_,32_3),
  &TEMPLATE2(_BITUNPACK_,32_4),
  &TEMPLATE2(_BITUNPACK_,32_5),
  &TEMPLATE2(_BITUNPACK_,32_6),
  &TEMPLATE2(_BITUNPACK_,32_7),
  &TEMPLATE2(_BITUNPACK_,32_8),
  &TEMPLATE2(_BITUNPACK_,32_9),
  &TEMPLATE2(_BITUNPACK_,32_10),
  &TEMPLATE2(_BITUNPACK_,32_11),
  &TEMPLATE2(_BITUNPACK_,32_12),
  &TEMPLATE2(_BITUNPACK_,32_13),
  &TEMPLATE2(_BITUNPACK_,32_14),
  &TEMPLATE2(_BITUNPACK_,32_15),
  &TEMPLATE2(_BITUNPACK_,32_16),
  &TEMPLATE2(_BITUNPACK_,32_17),
  &TEMPLATE2(_BITUNPACK_,32_18),
  &TEMPLATE2(_BITUNPACK_,32_19),
  &TEMPLATE2(_BITUNPACK_,32_20),
  &TEMPLATE2(_BITUNPACK_,32_21),
  &TEMPLATE2(_BITUNPACK_,32_22),
  &TEMPLATE2(_BITUNPACK_,32_23),
  &TEMPLATE2(_BITUNPACK_,32_24),
  &TEMPLATE2(_BITUNPACK_,32_25),
  &TEMPLATE2(_BITUNPACK_,32_26),
  &TEMPLATE2(_BITUNPACK_,32_27),
  &TEMPLATE2(_BITUNPACK_,32_28),
  &TEMPLATE2(_BITUNPACK_,32_29),
  &TEMPLATE2(_BITUNPACK_,32_30),
  &TEMPLATE2(_BITUNPACK_,32_31),
  &TEMPLATE2(_BITUNPACK_,32_32)
};
unsigned char *TEMPLATE2(_BITUNPACK_,32)( const unsigned char *__restrict in, unsigned n, uint32_t  *__restrict out , unsigned b) { return TEMPLATE2(_BITUNPACK_,a32)[ b](in, n, out); }

#define USIZE 64
unsigned char *TEMPLATE2(_BITUNPACK_,64_0)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*0); const uint64_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_1)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*1); do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_2)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*2); do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_3)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*3); do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_4)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*4); do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_5)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*5); do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_6)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*6); do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_7)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*7); do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_8)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*8); do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_9)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*9); do { BITUNPACK64_9( in, out, 9,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_10)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*10); do { BITUNPACK64_10( in, out, 10,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_11)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*11); do { BITUNPACK64_11( in, out, 11,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_12)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*12); do { BITUNPACK64_12( in, out, 12,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_13)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*13); do { BITUNPACK64_13( in, out, 13,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_14)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*14); do { BITUNPACK64_14( in, out, 14,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_15)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*15); do { BITUNPACK64_15( in, out, 15,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_16)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*16); do { BITUNPACK64_16( in, out, 16,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_17)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*17); do { BITUNPACK64_17( in, out, 17,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_18)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*18); do { BITUNPACK64_18( in, out, 18,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_19)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*19); do { BITUNPACK64_19( in, out, 19,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_20)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*20); do { BITUNPACK64_20( in, out, 20,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_21)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*21); do { BITUNPACK64_21( in, out, 21,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_22)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*22); do { BITUNPACK64_22( in, out, 22,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_23)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*23); do { BITUNPACK64_23( in, out, 23,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_24)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*24); do { BITUNPACK64_24( in, out, 24,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_25)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*25); do { BITUNPACK64_25( in, out, 25,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_26)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*26); do { BITUNPACK64_26( in, out, 26,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_27)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*27); do { BITUNPACK64_27( in, out, 27,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_28)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*28); do { BITUNPACK64_28( in, out, 28,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_29)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*29); do { BITUNPACK64_29( in, out, 29,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_30)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*30); do { BITUNPACK64_30( in, out, 30,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_31)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*31); do { BITUNPACK64_31( in, out, 31,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_32)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*32); do { BITUNPACK64_32( in, out, 32,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_33)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*33); do { BITUNPACK64_33( in, out, 33,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_34)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*34); do { BITUNPACK64_34( in, out, 34,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_35)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*35); do { BITUNPACK64_35( in, out, 35,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_36)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*36); do { BITUNPACK64_36( in, out, 36,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_37)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*37); do { BITUNPACK64_37( in, out, 37,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_38)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*38); do { BITUNPACK64_38( in, out, 38,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_39)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*39); do { BITUNPACK64_39( in, out, 39,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_40)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*40); do { BITUNPACK64_40( in, out, 40,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_41)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*41); do { BITUNPACK64_41( in, out, 41,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_42)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*42); do { BITUNPACK64_42( in, out, 42,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_43)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*43); do { BITUNPACK64_43( in, out, 43,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_44)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*44); do { BITUNPACK64_44( in, out, 44,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_45)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*45); do { BITUNPACK64_45( in, out, 45,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_46)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*46); do { BITUNPACK64_46( in, out, 46,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_47)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*47); do { BITUNPACK64_47( in, out, 47,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_48)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*48); do { BITUNPACK64_48( in, out, 48,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_49)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*49); do { BITUNPACK64_49( in, out, 49,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_50)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*50); do { BITUNPACK64_50( in, out, 50,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_51)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*51); do { BITUNPACK64_51( in, out, 51,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_52)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*52); do { BITUNPACK64_52( in, out, 52,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_53)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*53); do { BITUNPACK64_53( in, out, 53,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_54)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*54); do { BITUNPACK64_54( in, out, 54,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_55)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*55); do { BITUNPACK64_55( in, out, 55,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_56)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*56); do { BITUNPACK64_56( in, out, 56,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_57)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*57); do { BITUNPACK64_57( in, out, 57,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_58)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*58); do { BITUNPACK64_58( in, out, 58,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_59)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*59); do { BITUNPACK64_59( in, out, 59,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_60)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*60); do { BITUNPACK64_60( in, out, 60,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_61)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*61); do { BITUNPACK64_61( in, out, 61,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_62)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*62); do { BITUNPACK64_62( in, out, 62,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_63)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*63); do { BITUNPACK64_63( in, out, 63,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_64)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out  ) { unsigned char *in_=in+PAD8(n*64); do { BITUNPACK64_64( in, out, 64,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_F64 TEMPLATE2(_BITUNPACK_,a64)[] = {
  &TEMPLATE2(_BITUNPACK_,64_0),
  &TEMPLATE2(_BITUNPACK_,64_1),
  &TEMPLATE2(_BITUNPACK_,64_2),
  &TEMPLATE2(_BITUNPACK_,64_3),
  &TEMPLATE2(_BITUNPACK_,64_4),
  &TEMPLATE2(_BITUNPACK_,64_5),
  &TEMPLATE2(_BITUNPACK_,64_6),
  &TEMPLATE2(_BITUNPACK_,64_7),
  &TEMPLATE2(_BITUNPACK_,64_8),
  &TEMPLATE2(_BITUNPACK_,64_9),
  &TEMPLATE2(_BITUNPACK_,64_10),
  &TEMPLATE2(_BITUNPACK_,64_11),
  &TEMPLATE2(_BITUNPACK_,64_12),
  &TEMPLATE2(_BITUNPACK_,64_13),
  &TEMPLATE2(_BITUNPACK_,64_14),
  &TEMPLATE2(_BITUNPACK_,64_15),
  &TEMPLATE2(_BITUNPACK_,64_16),
  &TEMPLATE2(_BITUNPACK_,64_17),
  &TEMPLATE2(_BITUNPACK_,64_18),
  &TEMPLATE2(_BITUNPACK_,64_19),
  &TEMPLATE2(_BITUNPACK_,64_20),
  &TEMPLATE2(_BITUNPACK_,64_21),
  &TEMPLATE2(_BITUNPACK_,64_22),
  &TEMPLATE2(_BITUNPACK_,64_23),
  &TEMPLATE2(_BITUNPACK_,64_24),
  &TEMPLATE2(_BITUNPACK_,64_25),
  &TEMPLATE2(_BITUNPACK_,64_26),
  &TEMPLATE2(_BITUNPACK_,64_27),
  &TEMPLATE2(_BITUNPACK_,64_28),
  &TEMPLATE2(_BITUNPACK_,64_29),
  &TEMPLATE2(_BITUNPACK_,64_30),
  &TEMPLATE2(_BITUNPACK_,64_31),
  &TEMPLATE2(_BITUNPACK_,64_32),
  &TEMPLATE2(_BITUNPACK_,64_33),
  &TEMPLATE2(_BITUNPACK_,64_34),
  &TEMPLATE2(_BITUNPACK_,64_35),
  &TEMPLATE2(_BITUNPACK_,64_36),
  &TEMPLATE2(_BITUNPACK_,64_37),
  &TEMPLATE2(_BITUNPACK_,64_38),
  &TEMPLATE2(_BITUNPACK_,64_39),
  &TEMPLATE2(_BITUNPACK_,64_40),
  &TEMPLATE2(_BITUNPACK_,64_41),
  &TEMPLATE2(_BITUNPACK_,64_42),
  &TEMPLATE2(_BITUNPACK_,64_43),
  &TEMPLATE2(_BITUNPACK_,64_44),
  &TEMPLATE2(_BITUNPACK_,64_45),
  &TEMPLATE2(_BITUNPACK_,64_46),
  &TEMPLATE2(_BITUNPACK_,64_47),
  &TEMPLATE2(_BITUNPACK_,64_48),
  &TEMPLATE2(_BITUNPACK_,64_49),
  &TEMPLATE2(_BITUNPACK_,64_50),
  &TEMPLATE2(_BITUNPACK_,64_51),
  &TEMPLATE2(_BITUNPACK_,64_52),
  &TEMPLATE2(_BITUNPACK_,64_53),
  &TEMPLATE2(_BITUNPACK_,64_54),
  &TEMPLATE2(_BITUNPACK_,64_55),
  &TEMPLATE2(_BITUNPACK_,64_56),
  &TEMPLATE2(_BITUNPACK_,64_57),
  &TEMPLATE2(_BITUNPACK_,64_58),
  &TEMPLATE2(_BITUNPACK_,64_59),
  &TEMPLATE2(_BITUNPACK_,64_60),
  &TEMPLATE2(_BITUNPACK_,64_61),
  &TEMPLATE2(_BITUNPACK_,64_62),
  &TEMPLATE2(_BITUNPACK_,64_63),
  &TEMPLATE2(_BITUNPACK_,64_64)
};
unsigned char *TEMPLATE2(_BITUNPACK_,64)( const unsigned char *__restrict in, unsigned n, uint64_t  *__restrict out , unsigned b) { return TEMPLATE2(_BITUNPACK_,a64)[ b](in, n, out); }

#else
#define USIZE 8
unsigned char *TEMPLATE2(_BITUNPACK_,8_0)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*0),x=0; const uint8_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_1)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*1),x=0; do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_2)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*2),x=0; do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_3)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*3),x=0; do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_4)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*4),x=0; do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_5)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*5),x=0; do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_6)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*6),x=0; do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_7)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*7),x=0; do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,8_8)(const unsigned char *__restrict in, unsigned n, uint8_t *__restrict out , uint8_t start ) { unsigned char *in_=in+PAD8(n*8),x=0; do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_D8 TEMPLATE2(_BITUNPACK_,a8)[] = {
  &TEMPLATE2(_BITUNPACK_,8_0),
  &TEMPLATE2(_BITUNPACK_,8_1),
  &TEMPLATE2(_BITUNPACK_,8_2),
  &TEMPLATE2(_BITUNPACK_,8_3),
  &TEMPLATE2(_BITUNPACK_,8_4),
  &TEMPLATE2(_BITUNPACK_,8_5),
  &TEMPLATE2(_BITUNPACK_,8_6),
  &TEMPLATE2(_BITUNPACK_,8_7),
  &TEMPLATE2(_BITUNPACK_,8_8)
};
unsigned char *TEMPLATE2(_BITUNPACK_,8)( const unsigned char *__restrict in, unsigned n, uint8_t  *__restrict out , uint8_t start, unsigned b) { return TEMPLATE2(_BITUNPACK_,a8)[ b](in, n, out, start); }

#define USIZE 16
unsigned char *TEMPLATE2(_BITUNPACK_,16_0)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*0),x=0; const uint16_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_1)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*1),x=0; do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_2)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*2),x=0; do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_3)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*3),x=0; do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_4)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*4),x=0; do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_5)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*5),x=0; do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_6)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*6),x=0; do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_7)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*7),x=0; do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_8)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*8),x=0; do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_9)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*9),x=0; do { BITUNPACK64_9( in, out, 9,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_10)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*10),x=0; do { BITUNPACK64_10( in, out, 10,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_11)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*11),x=0; do { BITUNPACK64_11( in, out, 11,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_12)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*12),x=0; do { BITUNPACK64_12( in, out, 12,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_13)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*13),x=0; do { BITUNPACK64_13( in, out, 13,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_14)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*14),x=0; do { BITUNPACK64_14( in, out, 14,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_15)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*15),x=0; do { BITUNPACK64_15( in, out, 15,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,16_16)(const unsigned char *__restrict in, unsigned n, uint16_t *__restrict out , uint16_t start ) { unsigned char *in_=in+PAD8(n*16),x=0; do { BITUNPACK64_16( in, out, 16,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_D16 TEMPLATE2(_BITUNPACK_,a16)[] = {
  &TEMPLATE2(_BITUNPACK_,16_0),
  &TEMPLATE2(_BITUNPACK_,16_1),
  &TEMPLATE2(_BITUNPACK_,16_2),
  &TEMPLATE2(_BITUNPACK_,16_3),
  &TEMPLATE2(_BITUNPACK_,16_4),
  &TEMPLATE2(_BITUNPACK_,16_5),
  &TEMPLATE2(_BITUNPACK_,16_6),
  &TEMPLATE2(_BITUNPACK_,16_7),
  &TEMPLATE2(_BITUNPACK_,16_8),
  &TEMPLATE2(_BITUNPACK_,16_9),
  &TEMPLATE2(_BITUNPACK_,16_10),
  &TEMPLATE2(_BITUNPACK_,16_11),
  &TEMPLATE2(_BITUNPACK_,16_12),
  &TEMPLATE2(_BITUNPACK_,16_13),
  &TEMPLATE2(_BITUNPACK_,16_14),
  &TEMPLATE2(_BITUNPACK_,16_15),
  &TEMPLATE2(_BITUNPACK_,16_16)
};
unsigned char *TEMPLATE2(_BITUNPACK_,16)( const unsigned char *__restrict in, unsigned n, uint16_t  *__restrict out , uint16_t start, unsigned b) { return TEMPLATE2(_BITUNPACK_,a16)[ b](in, n, out, start); }

#define USIZE 32
unsigned char *TEMPLATE2(_BITUNPACK_,32_0)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*0),x=0; const uint32_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_1)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*1),x=0; do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_2)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*2),x=0; do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_3)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*3),x=0; do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_4)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*4),x=0; do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_5)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*5),x=0; do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_6)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*6),x=0; do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_7)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*7),x=0; do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_8)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*8),x=0; do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_9)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*9),x=0; do { BITUNPACK64_9( in, out, 9,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_10)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*10),x=0; do { BITUNPACK64_10( in, out, 10,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_11)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*11),x=0; do { BITUNPACK64_11( in, out, 11,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_12)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*12),x=0; do { BITUNPACK64_12( in, out, 12,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_13)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*13),x=0; do { BITUNPACK64_13( in, out, 13,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_14)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*14),x=0; do { BITUNPACK64_14( in, out, 14,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_15)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*15),x=0; do { BITUNPACK64_15( in, out, 15,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_16)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*16),x=0; do { BITUNPACK64_16( in, out, 16,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_17)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*17),x=0; do { BITUNPACK64_17( in, out, 17,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_18)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*18),x=0; do { BITUNPACK64_18( in, out, 18,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_19)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*19),x=0; do { BITUNPACK64_19( in, out, 19,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_20)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*20),x=0; do { BITUNPACK64_20( in, out, 20,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_21)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*21),x=0; do { BITUNPACK64_21( in, out, 21,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_22)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*22),x=0; do { BITUNPACK64_22( in, out, 22,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_23)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*23),x=0; do { BITUNPACK64_23( in, out, 23,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_24)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*24),x=0; do { BITUNPACK64_24( in, out, 24,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_25)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*25),x=0; do { BITUNPACK64_25( in, out, 25,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_26)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*26),x=0; do { BITUNPACK64_26( in, out, 26,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_27)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*27),x=0; do { BITUNPACK64_27( in, out, 27,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_28)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*28),x=0; do { BITUNPACK64_28( in, out, 28,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_29)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*29),x=0; do { BITUNPACK64_29( in, out, 29,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_30)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*30),x=0; do { BITUNPACK64_30( in, out, 30,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_31)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*31),x=0; do { BITUNPACK64_31( in, out, 31,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,32_32)(const unsigned char *__restrict in, unsigned n, uint32_t *__restrict out , uint32_t start ) { unsigned char *in_=in+PAD8(n*32),x=0; do { BITUNPACK64_32( in, out, 32,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_D32 TEMPLATE2(_BITUNPACK_,a32)[] = {
  &TEMPLATE2(_BITUNPACK_,32_0),
  &TEMPLATE2(_BITUNPACK_,32_1),
  &TEMPLATE2(_BITUNPACK_,32_2),
  &TEMPLATE2(_BITUNPACK_,32_3),
  &TEMPLATE2(_BITUNPACK_,32_4),
  &TEMPLATE2(_BITUNPACK_,32_5),
  &TEMPLATE2(_BITUNPACK_,32_6),
  &TEMPLATE2(_BITUNPACK_,32_7),
  &TEMPLATE2(_BITUNPACK_,32_8),
  &TEMPLATE2(_BITUNPACK_,32_9),
  &TEMPLATE2(_BITUNPACK_,32_10),
  &TEMPLATE2(_BITUNPACK_,32_11),
  &TEMPLATE2(_BITUNPACK_,32_12),
  &TEMPLATE2(_BITUNPACK_,32_13),
  &TEMPLATE2(_BITUNPACK_,32_14),
  &TEMPLATE2(_BITUNPACK_,32_15),
  &TEMPLATE2(_BITUNPACK_,32_16),
  &TEMPLATE2(_BITUNPACK_,32_17),
  &TEMPLATE2(_BITUNPACK_,32_18),
  &TEMPLATE2(_BITUNPACK_,32_19),
  &TEMPLATE2(_BITUNPACK_,32_20),
  &TEMPLATE2(_BITUNPACK_,32_21),
  &TEMPLATE2(_BITUNPACK_,32_22),
  &TEMPLATE2(_BITUNPACK_,32_23),
  &TEMPLATE2(_BITUNPACK_,32_24),
  &TEMPLATE2(_BITUNPACK_,32_25),
  &TEMPLATE2(_BITUNPACK_,32_26),
  &TEMPLATE2(_BITUNPACK_,32_27),
  &TEMPLATE2(_BITUNPACK_,32_28),
  &TEMPLATE2(_BITUNPACK_,32_29),
  &TEMPLATE2(_BITUNPACK_,32_30),
  &TEMPLATE2(_BITUNPACK_,32_31),
  &TEMPLATE2(_BITUNPACK_,32_32)
};
unsigned char *TEMPLATE2(_BITUNPACK_,32)( const unsigned char *__restrict in, unsigned n, uint32_t  *__restrict out , uint32_t start, unsigned b) { return TEMPLATE2(_BITUNPACK_,a32)[ b](in, n, out, start); }

#define USIZE 64
unsigned char *TEMPLATE2(_BITUNPACK_,64_0)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*0),x=0; const uint64_t *out_ = out+n; do { BITUNPACK64_0( in, out, 0,start); PREFETCH(in+512,0); } while(out<out_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_1)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*1),x=0; do { BITUNPACK64_1( in, out, 1,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_2)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*2),x=0; do { BITUNPACK64_2( in, out, 2,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_3)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*3),x=0; do { BITUNPACK64_3( in, out, 3,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_4)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*4),x=0; do { BITUNPACK64_4( in, out, 4,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_5)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*5),x=0; do { BITUNPACK64_5( in, out, 5,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_6)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*6),x=0; do { BITUNPACK64_6( in, out, 6,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_7)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*7),x=0; do { BITUNPACK64_7( in, out, 7,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_8)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*8),x=0; do { BITUNPACK64_8( in, out, 8,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_9)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*9),x=0; do { BITUNPACK64_9( in, out, 9,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_10)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*10),x=0; do { BITUNPACK64_10( in, out, 10,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_11)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*11),x=0; do { BITUNPACK64_11( in, out, 11,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_12)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*12),x=0; do { BITUNPACK64_12( in, out, 12,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_13)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*13),x=0; do { BITUNPACK64_13( in, out, 13,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_14)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*14),x=0; do { BITUNPACK64_14( in, out, 14,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_15)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*15),x=0; do { BITUNPACK64_15( in, out, 15,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_16)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*16),x=0; do { BITUNPACK64_16( in, out, 16,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_17)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*17),x=0; do { BITUNPACK64_17( in, out, 17,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_18)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*18),x=0; do { BITUNPACK64_18( in, out, 18,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_19)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*19),x=0; do { BITUNPACK64_19( in, out, 19,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_20)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*20),x=0; do { BITUNPACK64_20( in, out, 20,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_21)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*21),x=0; do { BITUNPACK64_21( in, out, 21,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_22)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*22),x=0; do { BITUNPACK64_22( in, out, 22,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_23)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*23),x=0; do { BITUNPACK64_23( in, out, 23,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_24)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*24),x=0; do { BITUNPACK64_24( in, out, 24,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_25)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*25),x=0; do { BITUNPACK64_25( in, out, 25,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_26)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*26),x=0; do { BITUNPACK64_26( in, out, 26,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_27)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*27),x=0; do { BITUNPACK64_27( in, out, 27,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_28)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*28),x=0; do { BITUNPACK64_28( in, out, 28,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_29)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*29),x=0; do { BITUNPACK64_29( in, out, 29,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_30)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*30),x=0; do { BITUNPACK64_30( in, out, 30,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_31)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*31),x=0; do { BITUNPACK64_31( in, out, 31,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_32)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*32),x=0; do { BITUNPACK64_32( in, out, 32,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_33)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*33),x=0; do { BITUNPACK64_33( in, out, 33,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_34)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*34),x=0; do { BITUNPACK64_34( in, out, 34,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_35)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*35),x=0; do { BITUNPACK64_35( in, out, 35,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_36)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*36),x=0; do { BITUNPACK64_36( in, out, 36,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_37)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*37),x=0; do { BITUNPACK64_37( in, out, 37,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_38)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*38),x=0; do { BITUNPACK64_38( in, out, 38,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_39)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*39),x=0; do { BITUNPACK64_39( in, out, 39,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_40)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*40),x=0; do { BITUNPACK64_40( in, out, 40,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_41)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*41),x=0; do { BITUNPACK64_41( in, out, 41,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_42)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*42),x=0; do { BITUNPACK64_42( in, out, 42,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_43)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*43),x=0; do { BITUNPACK64_43( in, out, 43,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_44)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*44),x=0; do { BITUNPACK64_44( in, out, 44,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_45)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*45),x=0; do { BITUNPACK64_45( in, out, 45,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_46)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*46),x=0; do { BITUNPACK64_46( in, out, 46,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_47)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*47),x=0; do { BITUNPACK64_47( in, out, 47,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_48)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*48),x=0; do { BITUNPACK64_48( in, out, 48,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_49)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*49),x=0; do { BITUNPACK64_49( in, out, 49,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_50)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*50),x=0; do { BITUNPACK64_50( in, out, 50,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_51)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*51),x=0; do { BITUNPACK64_51( in, out, 51,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_52)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*52),x=0; do { BITUNPACK64_52( in, out, 52,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_53)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*53),x=0; do { BITUNPACK64_53( in, out, 53,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_54)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*54),x=0; do { BITUNPACK64_54( in, out, 54,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_55)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*55),x=0; do { BITUNPACK64_55( in, out, 55,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_56)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*56),x=0; do { BITUNPACK64_56( in, out, 56,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_57)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*57),x=0; do { BITUNPACK64_57( in, out, 57,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_58)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*58),x=0; do { BITUNPACK64_58( in, out, 58,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_59)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*59),x=0; do { BITUNPACK64_59( in, out, 59,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_60)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*60),x=0; do { BITUNPACK64_60( in, out, 60,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_61)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*61),x=0; do { BITUNPACK64_61( in, out, 61,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_62)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*62),x=0; do { BITUNPACK64_62( in, out, 62,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_63)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*63),x=0; do { BITUNPACK64_63( in, out, 63,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
unsigned char *TEMPLATE2(_BITUNPACK_,64_64)(const unsigned char *__restrict in, unsigned n, uint64_t *__restrict out , uint64_t start ) { unsigned char *in_=in+PAD8(n*64),x=0; do { BITUNPACK64_64( in, out, 64,start); PREFETCH(in+512,0); } while(in<in_); return in_; }
BITUNPACK_D64 TEMPLATE2(_BITUNPACK_,a64)[] = {
  &TEMPLATE2(_BITUNPACK_,64_0),
  &TEMPLATE2(_BITUNPACK_,64_1),
  &TEMPLATE2(_BITUNPACK_,64_2),
  &TEMPLATE2(_BITUNPACK_,64_3),
  &TEMPLATE2(_BITUNPACK_,64_4),
  &TEMPLATE2(_BITUNPACK_,64_5),
  &TEMPLATE2(_BITUNPACK_,64_6),
  &TEMPLATE2(_BITUNPACK_,64_7),
  &TEMPLATE2(_BITUNPACK_,64_8),
  &TEMPLATE2(_BITUNPACK_,64_9),
  &TEMPLATE2(_BITUNPACK_,64_10),
  &TEMPLATE2(_BITUNPACK_,64_11),
  &TEMPLATE2(_BITUNPACK_,64_12),
  &TEMPLATE2(_BITUNPACK_,64_13),
  &TEMPLATE2(_BITUNPACK_,64_14),
  &TEMPLATE2(_BITUNPACK_,64_15),
  &TEMPLATE2(_BITUNPACK_,64_16),
  &TEMPLATE2(_BITUNPACK_,64_17),
  &TEMPLATE2(_BITUNPACK_,64_18),
  &TEMPLATE2(_BITUNPACK_,64_19),
  &TEMPLATE2(_BITUNPACK_,64_20),
  &TEMPLATE2(_BITUNPACK_,64_21),
  &TEMPLATE2(_BITUNPACK_,64_22),
  &TEMPLATE2(_BITUNPACK_,64_23),
  &TEMPLATE2(_BITUNPACK_,64_24),
  &TEMPLATE2(_BITUNPACK_,64_25),
  &TEMPLATE2(_BITUNPACK_,64_26),
  &TEMPLATE2(_BITUNPACK_,64_27),
  &TEMPLATE2(_BITUNPACK_,64_28),
  &TEMPLATE2(_BITUNPACK_,64_29),
  &TEMPLATE2(_BITUNPACK_,64_30),
  &TEMPLATE2(_BITUNPACK_,64_31),
  &TEMPLATE2(_BITUNPACK_,64_32),
  &TEMPLATE2(_BITUNPACK_,64_33),
  &TEMPLATE2(_BITUNPACK_,64_34),
  &TEMPLATE2(_BITUNPACK_,64_35),
  &TEMPLATE2(_BITUNPACK_,64_36),
  &TEMPLATE2(_BITUNPACK_,64_37),
  &TEMPLATE2(_BITUNPACK_,64_38),
  &TEMPLATE2(_BITUNPACK_,64_39),
  &TEMPLATE2(_BITUNPACK_,64_40),
  &TEMPLATE2(_BITUNPACK_,64_41),
  &TEMPLATE2(_BITUNPACK_,64_42),
  &TEMPLATE2(_BITUNPACK_,64_43),
  &TEMPLATE2(_BITUNPACK_,64_44),
  &TEMPLATE2(_BITUNPACK_,64_45),
  &TEMPLATE2(_BITUNPACK_,64_46),
  &TEMPLATE2(_BITUNPACK_,64_47),
  &TEMPLATE2(_BITUNPACK_,64_48),
  &TEMPLATE2(_BITUNPACK_,64_49),
  &TEMPLATE2(_BITUNPACK_,64_50),
  &TEMPLATE2(_BITUNPACK_,64_51),
  &TEMPLATE2(_BITUNPACK_,64_52),
  &TEMPLATE2(_BITUNPACK_,64_53),
  &TEMPLATE2(_BITUNPACK_,64_54),
  &TEMPLATE2(_BITUNPACK_,64_55),
  &TEMPLATE2(_BITUNPACK_,64_56),
  &TEMPLATE2(_BITUNPACK_,64_57),
  &TEMPLATE2(_BITUNPACK_,64_58),
  &TEMPLATE2(_BITUNPACK_,64_59),
  &TEMPLATE2(_BITUNPACK_,64_60),
  &TEMPLATE2(_BITUNPACK_,64_61),
  &TEMPLATE2(_BITUNPACK_,64_62),
  &TEMPLATE2(_BITUNPACK_,64_63),
  &TEMPLATE2(_BITUNPACK_,64_64)
};
unsigned char *TEMPLATE2(_BITUNPACK_,64)( const unsigned char *__restrict in, unsigned n, uint64_t  *__restrict out , uint64_t start, unsigned b) { return TEMPLATE2(_BITUNPACK_,a64)[ b](in, n, out, start); }

#endif
#endif //OPI
#define BITUNPACK128V16_0(ip,  op, nb,parm) {\
  BITUNBLK128V16_0(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_1(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  1),mv);                                                                                                                 VO16(op,i*16+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*16+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  3),mv);                                                                                                                 VO16(op,i*16+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*16+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  5),mv);                                                                                                                 VO16(op,i*16+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  6),mv);                                                                                                                 VO16(op,i*16+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  7),mv);                                                                                                                 VO16(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  8),mv);                                                                                                                 VO16(op,i*16+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  9),mv);                                                                                                                 VO16(op,i*16+ 9,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 10),mv);                                                                                                                 VO16(op,i*16+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 11),mv);                                                                                                                 VO16(op,i*16+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 12),mv);                                                                                                                 VO16(op,i*16+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 13),mv);                                                                                                                 VO16(op,i*16+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 14),mv);                                                                                                                 VO16(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_1(ip,  op, nb,parm) {\
  BITUNBLK128V16_1(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_2(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*8+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*8+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*8+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  6),mv);                                                                                                                 VO16(op,i*8+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  8),mv);                                                                                                                 VO16(op,i*8+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 10),mv);                                                                                                                 VO16(op,i*8+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 12),mv);                                                                                                                 VO16(op,i*8+ 6,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);                                                                                                                     VO16(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V16_2(ip,  op, nb,parm) {\
  BITUNBLK128V16_2(ip,  0, op, nb,parm);\
  BITUNBLK128V16_2(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V16_3(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  3),mv);                                                                                                                 VO16(op,i*16+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  6),mv);                                                                                                                 VO16(op,i*16+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  9),mv);                                                                                                                 VO16(op,i*16+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 12),mv);                                                                                                                 VO16(op,i*16+ 4,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  1), mv));       VO16(op,i*16+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*16+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  5),mv);                                                                                                                 VO16(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  8),mv);                                                                                                                 VO16(op,i*16+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 11),mv);                                                                                                                 VO16(op,i*16+ 9,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*16+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  1),mv);                                                                                                                 VO16(op,i*16+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*16+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  7),mv);                                                                                                                 VO16(op,i*16+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 10),mv);                                                                                                                 VO16(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 13);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_3(ip,  op, nb,parm) {\
  BITUNBLK128V16_3(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_4(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*4+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*4+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  8),mv);                                                                                                                 VO16(op,i*4+ 2,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);                                                                                                                     VO16(op,i*4+ 3,ov,nb,parm); ;\
}

#define BITUNPACK128V16_4(ip,  op, nb,parm) {\
  BITUNBLK128V16_4(ip,  0, op, nb,parm);\
  BITUNBLK128V16_4(ip,  1, op, nb,parm);\
  BITUNBLK128V16_4(ip,  2, op, nb,parm);\
  BITUNBLK128V16_4(ip,  3, op, nb,parm);\
}

#define BITUNBLK128V16_5(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  5),mv);                                                                                                                 VO16(op,i*16+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv, 10),mv);                                                                                                                 VO16(op,i*16+ 2,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  1), mv));       VO16(op,i*16+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*16+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  9),mv);                                                                                                                 VO16(op,i*16+ 5,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*16+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  3),mv);                                                                                                                 VO16(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  8),mv);                                                                                                                 VO16(op,i*16+ 8,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  3), mv));       VO16(op,i*16+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*16+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  7),mv);                                                                                                                 VO16(op,i*16+11,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*16+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  1),mv);                                                                                                                 VO16(op,i*16+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  6),mv);                                                                                                                 VO16(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 11);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_5(ip,  op, nb,parm) {\
  BITUNBLK128V16_5(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_6(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*8+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  6),mv);                                                                                                                 VO16(op,i*8+ 1,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*8+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*8+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  8),mv);                                                                                                                 VO16(op,i*8+ 4,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*8+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*8+ 6,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 10);                                                                                                                     VO16(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V16_6(ip,  op, nb,parm) {\
  BITUNBLK128V16_6(ip,  0, op, nb,parm);\
  BITUNBLK128V16_6(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V16_7(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  7),mv);                                                                                                                 VO16(op,i*16+ 1,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*16+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  5),mv);                                                                                                                 VO16(op,i*16+ 3,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*16+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  3),mv);                                                                                                                 VO16(op,i*16+ 5,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  6), mv));       VO16(op,i*16+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  1),mv);                                                                                                                 VO16(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi16(iv,  8),mv);                                                                                                                 VO16(op,i*16+ 8,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  1), mv));       VO16(op,i*16+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  6),mv);                                                                                                                 VO16(op,i*16+10,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  3), mv));       VO16(op,i*16+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*16+12,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  5), mv));       VO16(op,i*16+13,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi16(iv,  9);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_7(ip,  op, nb,parm) {\
  BITUNBLK128V16_7(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_8(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*2+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv,  8);                                                                                                                     VO16(op,i*2+ 1,ov,nb,parm); ;\
}

#define BITUNPACK128V16_8(ip,  op, nb,parm) {\
  BITUNBLK128V16_8(ip,  0, op, nb,parm);\
  BITUNBLK128V16_8(ip,  1, op, nb,parm);\
  BITUNBLK128V16_8(ip,  2, op, nb,parm);\
  BITUNBLK128V16_8(ip,  3, op, nb,parm);\
  BITUNBLK128V16_8(ip,  4, op, nb,parm);\
  BITUNBLK128V16_8(ip,  5, op, nb,parm);\
  BITUNBLK128V16_8(ip,  6, op, nb,parm);\
  BITUNBLK128V16_8(ip,  7, op, nb,parm);\
}

#define BITUNBLK128V16_9(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  7), mv));       VO16(op,i*16+ 1,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*16+ 2,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  5), mv));       VO16(op,i*16+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*16+ 4,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  3), mv));       VO16(op,i*16+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  6),mv);                                                                                                                 VO16(op,i*16+ 6,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  1), mv));       VO16(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  8), mv));       VO16(op,i*16+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  1),mv);                                                                                                                 VO16(op,i*16+ 9,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  6), mv));       VO16(op,i*16+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  3),mv);                                                                                                                 VO16(op,i*16+11,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*16+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  5),mv);                                                                                                                 VO16(op,i*16+13,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  7);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_9(ip,  op, nb,parm) {\
  BITUNBLK128V16_9(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_10(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*8+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  6), mv));       VO16(op,i*8+ 1,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*8+ 2,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*8+ 3,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  8), mv));       VO16(op,i*8+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*8+ 5,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*8+ 6,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  6);                                                                                                                     VO16(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V16_10(ip,  op, nb,parm) {\
  BITUNBLK128V16_10(ip,  0, op, nb,parm);\
  BITUNBLK128V16_10(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V16_11(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  5), mv));       VO16(op,i*16+ 1,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 10), mv));       VO16(op,i*16+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  1),mv);                                                                                                                 VO16(op,i*16+ 3,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*16+ 4,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  7);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  9), mv));       VO16(op,i*16+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*16+ 6,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  3), mv));       VO16(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  8), mv));       VO16(op,i*16+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  3),mv);                                                                                                                 VO16(op,i*16+ 9,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*16+10,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  7), mv));       VO16(op,i*16+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  4),mv);                                                                                                                 VO16(op,i*16+12,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  1), mv));       VO16(op,i*16+13,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  6), mv));       VO16(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  5);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_11(ip,  op, nb,parm) {\
  BITUNBLK128V16_11(ip,  0, op, nb,parm);\
  /*BITUNBLK128V16_11(ip,  1, op, nb,parm);*/\
}

#define BITUNBLK128V16_12(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*4+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*4+ 1,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  8), mv));       VO16(op,i*4+ 2,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  4);                                                                                                                     VO16(op,i*4+ 3,ov,nb,parm); ;\
}

#define BITUNPACK128V16_12(ip,  op, nb,parm) {\
  BITUNBLK128V16_12(ip,  0, op, nb,parm);\
  BITUNBLK128V16_12(ip,  1, op, nb,parm);\
  BITUNBLK128V16_12(ip,  2, op, nb,parm);\
  BITUNBLK128V16_12(ip,  3, op, nb,parm);\
}

#define BITUNBLK128V16_13(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  3), mv));       VO16(op,i*16+ 1,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  6), mv));       VO16(op,i*16+ 2,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  7);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  9), mv));       VO16(op,i*16+ 3,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  4);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 12), mv));       VO16(op,i*16+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  1),mv);                                                                                                                 VO16(op,i*16+ 5,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*16+ 6,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  5), mv));       VO16(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  8), mv));       VO16(op,i*16+ 8,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  5);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 11), mv));       VO16(op,i*16+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi16(iv,  2),mv);                                                                                                                 VO16(op,i*16+10,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  1), mv));       VO16(op,i*16+11,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*16+12,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  7), mv));       VO16(op,i*16+13,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 10), mv));       VO16(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  3);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_13(ip,  op, nb,parm) {\
  BITUNBLK128V16_13(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_14(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*8+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*8+ 1,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*8+ 2,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  6), mv));       VO16(op,i*8+ 3,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  8), mv));       VO16(op,i*8+ 4,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 10), mv));       VO16(op,i*8+ 5,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  4);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 12), mv));       VO16(op,i*8+ 6,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  2);                                                                                                                     VO16(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V16_14(ip,  op, nb,parm) {\
  BITUNBLK128V16_14(ip,  0, op, nb,parm);\
  BITUNBLK128V16_14(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V16_15(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi16(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  1), mv));       VO16(op,i*16+ 1,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  2), mv));       VO16(op,i*16+ 2,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  3), mv));       VO16(op,i*16+ 3,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  4), mv));       VO16(op,i*16+ 4,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  5), mv));       VO16(op,i*16+ 5,ov,nb,parm);\
  ov =                mm_srli_epi16(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  6), mv));       VO16(op,i*16+ 6,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  7), mv));       VO16(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  8), mv));       VO16(op,i*16+ 8,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  7);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv,  9), mv));       VO16(op,i*16+ 9,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 10), mv));       VO16(op,i*16+10,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  5);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 11), mv));       VO16(op,i*16+11,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  4);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 12), mv));       VO16(op,i*16+12,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  3);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 13), mv));       VO16(op,i*16+13,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  2);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi16(iv, 14), mv));       VO16(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi16(iv,  1);                                                                                                                     VO16(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V16_15(ip,  op, nb,parm) {\
  BITUNBLK128V16_15(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V16_16(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO16(op,i*1+ 0,ov,nb,parm); ;\
}

#define BITUNPACK128V16_16(ip,  op, nb,parm) {\
  BITUNBLK128V16_16(ip,  0, op, nb,parm);\
  BITUNBLK128V16_16(ip,  1, op, nb,parm);\
  BITUNBLK128V16_16(ip,  2, op, nb,parm);\
  BITUNBLK128V16_16(ip,  3, op, nb,parm);\
  BITUNBLK128V16_16(ip,  4, op, nb,parm);\
  BITUNBLK128V16_16(ip,  5, op, nb,parm);\
  BITUNBLK128V16_16(ip,  6, op, nb,parm);\
  BITUNBLK128V16_16(ip,  7, op, nb,parm);\
  BITUNBLK128V16_16(ip,  8, op, nb,parm);\
  BITUNBLK128V16_16(ip,  9, op, nb,parm);\
  BITUNBLK128V16_16(ip, 10, op, nb,parm);\
  BITUNBLK128V16_16(ip, 11, op, nb,parm);\
  BITUNBLK128V16_16(ip, 12, op, nb,parm);\
  BITUNBLK128V16_16(ip, 13, op, nb,parm);\
  BITUNBLK128V16_16(ip, 14, op, nb,parm);\
  BITUNBLK128V16_16(ip, 15, op, nb,parm);\
}

#define BITUNPACK128V32_0(ip,  op, nb,parm) {\
  BITUNBLK128V32_0(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_1(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 25),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 27),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 28),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 29),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 30),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_1(ip,  op, nb,parm) {\
  BITUNBLK128V32_1(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_2(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 28),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_2(ip,  op, nb,parm) {\
  BITUNBLK128V32_2(ip,  0, op, nb,parm);\
  BITUNBLK128V32_2(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_3(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 27),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 25),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 28),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_3(ip,  op, nb,parm) {\
  BITUNBLK128V32_3(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_4(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*8+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*8+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*8+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*8+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*8+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*8+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V32_4(ip,  op, nb,parm) {\
  BITUNBLK128V32_4(ip,  0, op, nb,parm);\
  BITUNBLK128V32_4(ip,  1, op, nb,parm);\
  BITUNBLK128V32_4(ip,  2, op, nb,parm);\
  BITUNBLK128V32_4(ip,  3, op, nb,parm);\
}

#define BITUNBLK128V32_5(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 25),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_5(ip,  op, nb,parm) {\
  BITUNBLK128V32_5(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_6(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_6(ip,  op, nb,parm) {\
  BITUNBLK128V32_6(ip,  0, op, nb,parm);\
  BITUNBLK128V32_6(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_7(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_7(ip,  op, nb,parm) {\
  BITUNBLK128V32_7(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_8(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*4+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*4+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*4+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);                                                                                                                     VO32(op,i*4+ 3,ov,nb,parm); ;\
}

#define BITUNPACK128V32_8(ip,  op, nb,parm) {\
  BITUNBLK128V32_8(ip,  0, op, nb,parm);\
  BITUNBLK128V32_8(ip,  1, op, nb,parm);\
  BITUNBLK128V32_8(ip,  2, op, nb,parm);\
  BITUNBLK128V32_8(ip,  3, op, nb,parm);\
  BITUNBLK128V32_8(ip,  4, op, nb,parm);\
  BITUNBLK128V32_8(ip,  5, op, nb,parm);\
  BITUNBLK128V32_8(ip,  6, op, nb,parm);\
  BITUNBLK128V32_8(ip,  7, op, nb,parm);\
}

#define BITUNBLK128V32_9(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_9(ip,  op, nb,parm) {\
  BITUNBLK128V32_9(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_10(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_10(ip,  op, nb,parm) {\
  BITUNBLK128V32_10(ip,  0, op, nb,parm);\
  BITUNBLK128V32_10(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_11(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 21);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_11(ip,  op, nb,parm) {\
  BITUNBLK128V32_11(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_12(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*8+ 1,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*8+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*8+ 3,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*8+ 4,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*8+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*8+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V32_12(ip,  op, nb,parm) {\
  BITUNBLK128V32_12(ip,  0, op, nb,parm);\
  BITUNBLK128V32_12(ip,  1, op, nb,parm);\
  BITUNBLK128V32_12(ip,  2, op, nb,parm);\
  BITUNBLK128V32_12(ip,  3, op, nb,parm);\
}

#define BITUNBLK128V32_13(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 19);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_13(ip,  op, nb,parm) {\
  BITUNBLK128V32_13(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_14(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 18);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_14(ip,  op, nb,parm) {\
  BITUNBLK128V32_14(ip,  0, op, nb,parm);\
  BITUNBLK128V32_14(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_15(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm_and_si128( mm_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 17);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_15(ip,  op, nb,parm) {\
  BITUNBLK128V32_15(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_16(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*2+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 16);                                                                                                                     VO32(op,i*2+ 1,ov,nb,parm); ;\
}

#define BITUNPACK128V32_16(ip,  op, nb,parm) {\
  BITUNBLK128V32_16(ip,  0, op, nb,parm);\
  BITUNBLK128V32_16(ip,  1, op, nb,parm);\
  BITUNBLK128V32_16(ip,  2, op, nb,parm);\
  BITUNBLK128V32_16(ip,  3, op, nb,parm);\
  BITUNBLK128V32_16(ip,  4, op, nb,parm);\
  BITUNBLK128V32_16(ip,  5, op, nb,parm);\
  BITUNBLK128V32_16(ip,  6, op, nb,parm);\
  BITUNBLK128V32_16(ip,  7, op, nb,parm);\
  BITUNBLK128V32_16(ip,  8, op, nb,parm);\
  BITUNBLK128V32_16(ip,  9, op, nb,parm);\
  BITUNBLK128V32_16(ip, 10, op, nb,parm);\
  BITUNBLK128V32_16(ip, 11, op, nb,parm);\
  BITUNBLK128V32_16(ip, 12, op, nb,parm);\
  BITUNBLK128V32_16(ip, 13, op, nb,parm);\
  BITUNBLK128V32_16(ip, 14, op, nb,parm);\
  BITUNBLK128V32_16(ip, 15, op, nb,parm);\
}

#define BITUNBLK128V32_17(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_17(ip,  op, nb,parm) {\
  BITUNBLK128V32_17(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_18(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_18(ip,  op, nb,parm) {\
  BITUNBLK128V32_18(ip,  0, op, nb,parm);\
  BITUNBLK128V32_18(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_19(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 17), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 13);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_19(ip,  op, nb,parm) {\
  BITUNBLK128V32_19(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_20(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*8+ 1,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*8+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*8+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*8+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*8+ 5,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*8+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V32_20(ip,  op, nb,parm) {\
  BITUNBLK128V32_20(ip,  0, op, nb,parm);\
  BITUNBLK128V32_20(ip,  1, op, nb,parm);\
  BITUNBLK128V32_20(ip,  2, op, nb,parm);\
  BITUNBLK128V32_20(ip,  3, op, nb,parm);\
}

#define BITUNBLK128V32_21(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 17), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 19), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 11);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_21(ip,  op, nb,parm) {\
  BITUNBLK128V32_21(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_22(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_22(ip,  op, nb,parm) {\
  BITUNBLK128V32_22(ip,  0, op, nb,parm);\
  BITUNBLK128V32_22(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_23(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 22), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 17), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 21), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 19), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  9);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_23(ip,  op, nb,parm) {\
  BITUNBLK128V32_23(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_24(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*4+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*4+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*4+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);                                                                                                                     VO32(op,i*4+ 3,ov,nb,parm); ;\
}

#define BITUNPACK128V32_24(ip,  op, nb,parm) {\
  BITUNBLK128V32_24(ip,  0, op, nb,parm);\
  BITUNBLK128V32_24(ip,  1, op, nb,parm);\
  BITUNBLK128V32_24(ip,  2, op, nb,parm);\
  BITUNBLK128V32_24(ip,  3, op, nb,parm);\
  BITUNBLK128V32_24(ip,  4, op, nb,parm);\
  BITUNBLK128V32_24(ip,  5, op, nb,parm);\
  BITUNBLK128V32_24(ip,  6, op, nb,parm);\
  BITUNBLK128V32_24(ip,  7, op, nb,parm);\
}

#define BITUNBLK128V32_25(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 21), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 17), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 24), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 23), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 19), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 22), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  7);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_25(ip,  op, nb,parm) {\
  BITUNBLK128V32_25(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_26(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 24), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 22), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  6);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_26(ip,  op, nb,parm) {\
  BITUNBLK128V32_26(ip,  0, op, nb,parm);\
  BITUNBLK128V32_26(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_27(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  7);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 25), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 23), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 21), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 26), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 19), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 24), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 17), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 22), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  5);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_27(ip,  op, nb,parm) {\
  BITUNBLK128V32_27(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_28(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*8+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*8+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*8+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*8+ 4,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*8+ 5,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 24), mv));       VO32(op,i*8+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  4);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK128V32_28(ip,  op, nb,parm) {\
  BITUNBLK128V32_28(ip,  0, op, nb,parm);\
  BITUNBLK128V32_28(ip,  1, op, nb,parm);\
  BITUNBLK128V32_28(ip,  2, op, nb,parm);\
  BITUNBLK128V32_28(ip,  3, op, nb,parm);\
}

#define BITUNBLK128V32_29(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 21), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 24), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  5);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 27), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 19), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 22), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  7);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 25), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  4);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 28), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm_and_si128( mm_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 17), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 23), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 26), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  3);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_29(ip,  op, nb,parm) {\
  BITUNBLK128V32_29(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_30(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 22), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 24), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 26), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  4);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 28), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  2);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK128V32_30(ip,  op, nb,parm) {\
  BITUNBLK128V32_30(ip,  0, op, nb,parm);\
  BITUNBLK128V32_30(ip,  1, op, nb,parm);\
}

#define BITUNBLK128V32_31(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =                mm_srli_epi32(iv, 31);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 30);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 29);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 28);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 27);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 26);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 25);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 24);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 23);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 22);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 10), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 21);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 11), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 20);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 12), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 19);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 13), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 18);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 14), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 17);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 15), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 16);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 15);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 17), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 14);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 18), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 13);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 19), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 12);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 20), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 11);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 21), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov =                mm_srli_epi32(iv, 10);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 22), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  9);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 23), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  8);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 24), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  7);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 25), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  6);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 26), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  5);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 27), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  4);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 28), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  3);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 29), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  2);      iv = _mm_loadu_si128((__m128i *)ip++); ov = _mm_or_si128(ov, _mm_and_si128( mm_slli_epi32(iv, 30), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =                mm_srli_epi32(iv,  1);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK128V32_31(ip,  op, nb,parm) {\
  BITUNBLK128V32_31(ip,  0, op, nb,parm);\
}

#define BITUNBLK128V32_32(ip, i, op, nb,parm) { __m128i ov,iv = _mm_loadu_si128((__m128i *)ip++);\
  ov = _mm_and_si128(               iv     ,mv);                                                                                                                 VO32(op,i*1+ 0,ov,nb,parm); ;\
}

#define BITUNPACK128V32_32(ip,  op, nb,parm) {\
  BITUNBLK128V32_32(ip,  0, op, nb,parm);\
  BITUNBLK128V32_32(ip,  1, op, nb,parm);\
  BITUNBLK128V32_32(ip,  2, op, nb,parm);\
  BITUNBLK128V32_32(ip,  3, op, nb,parm);\
  BITUNBLK128V32_32(ip,  4, op, nb,parm);\
  BITUNBLK128V32_32(ip,  5, op, nb,parm);\
  BITUNBLK128V32_32(ip,  6, op, nb,parm);\
  BITUNBLK128V32_32(ip,  7, op, nb,parm);\
  BITUNBLK128V32_32(ip,  8, op, nb,parm);\
  BITUNBLK128V32_32(ip,  9, op, nb,parm);\
  BITUNBLK128V32_32(ip, 10, op, nb,parm);\
  BITUNBLK128V32_32(ip, 11, op, nb,parm);\
  BITUNBLK128V32_32(ip, 12, op, nb,parm);\
  BITUNBLK128V32_32(ip, 13, op, nb,parm);\
  BITUNBLK128V32_32(ip, 14, op, nb,parm);\
  BITUNBLK128V32_32(ip, 15, op, nb,parm);\
  BITUNBLK128V32_32(ip, 16, op, nb,parm);\
  BITUNBLK128V32_32(ip, 17, op, nb,parm);\
  BITUNBLK128V32_32(ip, 18, op, nb,parm);\
  BITUNBLK128V32_32(ip, 19, op, nb,parm);\
  BITUNBLK128V32_32(ip, 20, op, nb,parm);\
  BITUNBLK128V32_32(ip, 21, op, nb,parm);\
  BITUNBLK128V32_32(ip, 22, op, nb,parm);\
  BITUNBLK128V32_32(ip, 23, op, nb,parm);\
  BITUNBLK128V32_32(ip, 24, op, nb,parm);\
  BITUNBLK128V32_32(ip, 25, op, nb,parm);\
  BITUNBLK128V32_32(ip, 26, op, nb,parm);\
  BITUNBLK128V32_32(ip, 27, op, nb,parm);\
  BITUNBLK128V32_32(ip, 28, op, nb,parm);\
  BITUNBLK128V32_32(ip, 29, op, nb,parm);\
  BITUNBLK128V32_32(ip, 30, op, nb,parm);\
  BITUNBLK128V32_32(ip, 31, op, nb,parm);\
}

#define BITUNPACK256V32_0(ip,  op, nb,parm) {\
  BITUNBLK256V32_0(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_1(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 25),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 27),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 28),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 29),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 30),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_1(ip,  op, nb,parm) {\
  BITUNBLK256V32_1(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_2(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 28),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_2(ip,  op, nb,parm) {\
  BITUNBLK256V32_2(ip,  0, op, nb,parm);\
  BITUNBLK256V32_2(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_3(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 27),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 25),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 28),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_3(ip,  op, nb,parm) {\
  BITUNBLK256V32_3(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_4(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*8+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*8+ 2,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*8+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*8+ 4,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*8+ 5,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*8+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK256V32_4(ip,  op, nb,parm) {\
  BITUNBLK256V32_4(ip,  0, op, nb,parm);\
  BITUNBLK256V32_4(ip,  1, op, nb,parm);\
  BITUNBLK256V32_4(ip,  2, op, nb,parm);\
  BITUNBLK256V32_4(ip,  3, op, nb,parm);\
}

#define BITUNBLK256V32_5(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 25),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 26),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_5(ip,  op, nb,parm) {\
  BITUNBLK256V32_5(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_6(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_6(ip,  op, nb,parm) {\
  BITUNBLK256V32_6(ip,  0, op, nb,parm);\
  BITUNBLK256V32_6(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_7(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 24),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 23),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_7(ip,  op, nb,parm) {\
  BITUNBLK256V32_7(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_8(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*4+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*4+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*4+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);                                                                                                                     VO32(op,i*4+ 3,ov,nb,parm); ;\
}

#define BITUNPACK256V32_8(ip,  op, nb,parm) {\
  BITUNBLK256V32_8(ip,  0, op, nb,parm);\
  BITUNBLK256V32_8(ip,  1, op, nb,parm);\
  BITUNBLK256V32_8(ip,  2, op, nb,parm);\
  BITUNBLK256V32_8(ip,  3, op, nb,parm);\
  BITUNBLK256V32_8(ip,  4, op, nb,parm);\
  BITUNBLK256V32_8(ip,  5, op, nb,parm);\
  BITUNBLK256V32_8(ip,  6, op, nb,parm);\
  BITUNBLK256V32_8(ip,  7, op, nb,parm);\
}

#define BITUNBLK256V32_9(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 22),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 21),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_9(ip,  op, nb,parm) {\
  BITUNBLK256V32_9(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_10(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_10(ip,  op, nb,parm) {\
  BITUNBLK256V32_10(ip,  0, op, nb,parm);\
  BITUNBLK256V32_10(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_11(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 19),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 20),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 21);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_11(ip,  op, nb,parm) {\
  BITUNBLK256V32_11(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_12(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*8+ 1,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*8+ 2,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*8+ 3,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*8+ 4,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*8+ 5,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*8+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK256V32_12(ip,  op, nb,parm) {\
  BITUNBLK256V32_12(ip,  0, op, nb,parm);\
  BITUNBLK256V32_12(ip,  1, op, nb,parm);\
  BITUNBLK256V32_12(ip,  2, op, nb,parm);\
  BITUNBLK256V32_12(ip,  3, op, nb,parm);\
}

#define BITUNBLK256V32_13(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 17),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 18),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 19);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_13(ip,  op, nb,parm) {\
  BITUNBLK256V32_13(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_14(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*16+ 1,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 7,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*16+ 8,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 18);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_14(ip,  op, nb,parm) {\
  BITUNBLK256V32_14(ip,  0, op, nb,parm);\
  BITUNBLK256V32_14(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_15(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 15),mv);                                                                                                                 VO32(op,i*32+ 1,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+15,ov,nb,parm); \
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 16),mv);                                                                                                                 VO32(op,i*32+16,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+30,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 17);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_15(ip,  op, nb,parm) {\
  BITUNBLK256V32_15(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_16(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*2+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 16);                                                                                                                     VO32(op,i*2+ 1,ov,nb,parm); ;\
}

#define BITUNPACK256V32_16(ip,  op, nb,parm) {\
  BITUNBLK256V32_16(ip,  0, op, nb,parm);\
  BITUNBLK256V32_16(ip,  1, op, nb,parm);\
  BITUNBLK256V32_16(ip,  2, op, nb,parm);\
  BITUNBLK256V32_16(ip,  3, op, nb,parm);\
  BITUNBLK256V32_16(ip,  4, op, nb,parm);\
  BITUNBLK256V32_16(ip,  5, op, nb,parm);\
  BITUNBLK256V32_16(ip,  6, op, nb,parm);\
  BITUNBLK256V32_16(ip,  7, op, nb,parm);\
  BITUNBLK256V32_16(ip,  8, op, nb,parm);\
  BITUNBLK256V32_16(ip,  9, op, nb,parm);\
  BITUNBLK256V32_16(ip, 10, op, nb,parm);\
  BITUNBLK256V32_16(ip, 11, op, nb,parm);\
  BITUNBLK256V32_16(ip, 12, op, nb,parm);\
  BITUNBLK256V32_16(ip, 13, op, nb,parm);\
  BITUNBLK256V32_16(ip, 14, op, nb,parm);\
  BITUNBLK256V32_16(ip, 15, op, nb,parm);\
}

#define BITUNBLK256V32_17(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 14),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 13),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_17(ip,  op, nb,parm) {\
  BITUNBLK256V32_17(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_18(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+ 4,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+11,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*16+13,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_18(ip,  op, nb,parm) {\
  BITUNBLK256V32_18(ip,  0, op, nb,parm);\
  BITUNBLK256V32_18(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_19(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 12),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 11),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 17), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 13);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_19(ip,  op, nb,parm) {\
  BITUNBLK256V32_19(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_20(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*8+ 1,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*8+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*8+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*8+ 4,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*8+ 5,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*8+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK256V32_20(ip,  op, nb,parm) {\
  BITUNBLK256V32_20(ip,  0, op, nb,parm);\
  BITUNBLK256V32_20(ip,  1, op, nb,parm);\
  BITUNBLK256V32_20(ip,  2, op, nb,parm);\
  BITUNBLK256V32_20(ip,  3, op, nb,parm);\
}

#define BITUNBLK256V32_21(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv, 10),mv);                                                                                                                 VO32(op,i*32+ 2,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  9),mv);                                                                                                                 VO32(op,i*32+ 5,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+ 8,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+11,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 17), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+20,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+23,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 13);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 19), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+26,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+29,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 11);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_21(ip,  op, nb,parm) {\
  BITUNBLK256V32_21(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_22(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 3,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*16+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*16+12,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_22(ip,  op, nb,parm) {\
  BITUNBLK256V32_22(ip,  0, op, nb,parm);\
  BITUNBLK256V32_22(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_23(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+ 3,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 22), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 7,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 17), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 11);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 21), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+14,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  7),mv);                                                                                                                 VO32(op,i*32+17,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  8),mv);                                                                                                                 VO32(op,i*32+24,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 13);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 19), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+28,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  9);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_23(ip,  op, nb,parm) {\
  BITUNBLK256V32_23(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_24(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*4+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*4+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*4+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);                                                                                                                     VO32(op,i*4+ 3,ov,nb,parm); ;\
}

#define BITUNPACK256V32_24(ip,  op, nb,parm) {\
  BITUNBLK256V32_24(ip,  0, op, nb,parm);\
  BITUNBLK256V32_24(ip,  1, op, nb,parm);\
  BITUNBLK256V32_24(ip,  2, op, nb,parm);\
  BITUNBLK256V32_24(ip,  3, op, nb,parm);\
  BITUNBLK256V32_24(ip,  4, op, nb,parm);\
  BITUNBLK256V32_24(ip,  5, op, nb,parm);\
  BITUNBLK256V32_24(ip,  6, op, nb,parm);\
  BITUNBLK256V32_24(ip,  7, op, nb,parm);\
}

#define BITUNBLK256V32_25(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 11);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 21), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+ 4,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 17), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 24), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+ 9,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  5),mv);                                                                                                                 VO32(op,i*32+13,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  9);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 23), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+18,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 13);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 19), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  6),mv);                                                                                                                 VO32(op,i*32+22,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 22), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+27,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  7);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_25(ip,  op, nb,parm) {\
  BITUNBLK256V32_25(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_26(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 24), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*16+ 5,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 22), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*16+10,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  6);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_26(ip,  op, nb,parm) {\
  BITUNBLK256V32_26(ip,  0, op, nb,parm);\
  BITUNBLK256V32_26(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_27(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  7);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 25), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+ 6,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  9);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 23), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  4),mv);                                                                                                                 VO32(op,i*32+12,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 11);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 21), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  6);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 26), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+19,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 13);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 19), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 24), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  3),mv);                                                                                                                 VO32(op,i*32+25,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 17), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 22), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  5);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_27(ip,  op, nb,parm) {\
  BITUNBLK256V32_27(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_28(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*8+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*8+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*8+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*8+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*8+ 4,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*8+ 5,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 24), mv));       VO32(op,i*8+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  4);                                                                                                                     VO32(op,i*8+ 7,ov,nb,parm); ;\
}

#define BITUNPACK256V32_28(ip,  op, nb,parm) {\
  BITUNBLK256V32_28(ip,  0, op, nb,parm);\
  BITUNBLK256V32_28(ip,  1, op, nb,parm);\
  BITUNBLK256V32_28(ip,  2, op, nb,parm);\
  BITUNBLK256V32_28(ip,  3, op, nb,parm);\
}

#define BITUNBLK256V32_29(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 11);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 21), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 24), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  5);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 27), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  2),mv);                                                                                                                 VO32(op,i*32+10,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 13);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 19), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 22), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  7);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 25), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  4);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 28), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov = _mm256_and_si256(_mm256_srli_epi32(iv,  1),mv);                                                                                                                 VO32(op,i*32+21,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 17), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  9);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 23), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  6);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 26), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  3);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_29(ip,  op, nb,parm) {\
  BITUNBLK256V32_29(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_30(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*16+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*16+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*16+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*16+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*16+ 4,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*16+ 5,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*16+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*16+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*16+ 8,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*16+ 9,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*16+10,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 22), mv));       VO32(op,i*16+11,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 24), mv));       VO32(op,i*16+12,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  6);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 26), mv));       VO32(op,i*16+13,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  4);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 28), mv));       VO32(op,i*16+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  2);                                                                                                                     VO32(op,i*16+15,ov,nb,parm); ;\
}

#define BITUNPACK256V32_30(ip,  op, nb,parm) {\
  BITUNBLK256V32_30(ip,  0, op, nb,parm);\
  BITUNBLK256V32_30(ip,  1, op, nb,parm);\
}

#define BITUNBLK256V32_31(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*32+ 0,ov,nb,parm); \
  ov =               _mm256_srli_epi32(iv, 31);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  1), mv));       VO32(op,i*32+ 1,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 30);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  2), mv));       VO32(op,i*32+ 2,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 29);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  3), mv));       VO32(op,i*32+ 3,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 28);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  4), mv));       VO32(op,i*32+ 4,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 27);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  5), mv));       VO32(op,i*32+ 5,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 26);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  6), mv));       VO32(op,i*32+ 6,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 25);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  7), mv));       VO32(op,i*32+ 7,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 24);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  8), mv));       VO32(op,i*32+ 8,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 23);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv,  9), mv));       VO32(op,i*32+ 9,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 22);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 10), mv));       VO32(op,i*32+10,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 21);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 11), mv));       VO32(op,i*32+11,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 20);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 12), mv));       VO32(op,i*32+12,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 19);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 13), mv));       VO32(op,i*32+13,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 18);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 14), mv));       VO32(op,i*32+14,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 17);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 15), mv));       VO32(op,i*32+15,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 16);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 16), mv));       VO32(op,i*32+16,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 15);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 17), mv));       VO32(op,i*32+17,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 14);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 18), mv));       VO32(op,i*32+18,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 13);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 19), mv));       VO32(op,i*32+19,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 12);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 20), mv));       VO32(op,i*32+20,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 11);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 21), mv));       VO32(op,i*32+21,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv, 10);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 22), mv));       VO32(op,i*32+22,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  9);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 23), mv));       VO32(op,i*32+23,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  8);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 24), mv));       VO32(op,i*32+24,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  7);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 25), mv));       VO32(op,i*32+25,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  6);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 26), mv));       VO32(op,i*32+26,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  5);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 27), mv));       VO32(op,i*32+27,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  4);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 28), mv));       VO32(op,i*32+28,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  3);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 29), mv));       VO32(op,i*32+29,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  2);      iv = _mm256_loadu_si256((__m128i *)ip++); ov = _mm256_or_si256(ov, _mm256_and_si256(_mm256_slli_epi32(iv, 30), mv));       VO32(op,i*32+30,ov,nb,parm);\
  ov =               _mm256_srli_epi32(iv,  1);                                                                                                                     VO32(op,i*32+31,ov,nb,parm); ;\
}

#define BITUNPACK256V32_31(ip,  op, nb,parm) {\
  BITUNBLK256V32_31(ip,  0, op, nb,parm);\
}

#define BITUNBLK256V32_32(ip, i, op, nb,parm) { __m256i ov,iv = _mm256_loadu_si256((__m256i *)ip++);\
  ov = _mm256_and_si256(                  iv     ,mv);                                                                                                                 VO32(op,i*1+ 0,ov,nb,parm); ;\
}

#define BITUNPACK256V32_32(ip,  op, nb,parm) {\
  BITUNBLK256V32_32(ip,  0, op, nb,parm);\
  BITUNBLK256V32_32(ip,  1, op, nb,parm);\
  BITUNBLK256V32_32(ip,  2, op, nb,parm);\
  BITUNBLK256V32_32(ip,  3, op, nb,parm);\
  BITUNBLK256V32_32(ip,  4, op, nb,parm);\
  BITUNBLK256V32_32(ip,  5, op, nb,parm);\
  BITUNBLK256V32_32(ip,  6, op, nb,parm);\
  BITUNBLK256V32_32(ip,  7, op, nb,parm);\
  BITUNBLK256V32_32(ip,  8, op, nb,parm);\
  BITUNBLK256V32_32(ip,  9, op, nb,parm);\
  BITUNBLK256V32_32(ip, 10, op, nb,parm);\
  BITUNBLK256V32_32(ip, 11, op, nb,parm);\
  BITUNBLK256V32_32(ip, 12, op, nb,parm);\
  BITUNBLK256V32_32(ip, 13, op, nb,parm);\
  BITUNBLK256V32_32(ip, 14, op, nb,parm);\
  BITUNBLK256V32_32(ip, 15, op, nb,parm);\
  BITUNBLK256V32_32(ip, 16, op, nb,parm);\
  BITUNBLK256V32_32(ip, 17, op, nb,parm);\
  BITUNBLK256V32_32(ip, 18, op, nb,parm);\
  BITUNBLK256V32_32(ip, 19, op, nb,parm);\
  BITUNBLK256V32_32(ip, 20, op, nb,parm);\
  BITUNBLK256V32_32(ip, 21, op, nb,parm);\
  BITUNBLK256V32_32(ip, 22, op, nb,parm);\
  BITUNBLK256V32_32(ip, 23, op, nb,parm);\
  BITUNBLK256V32_32(ip, 24, op, nb,parm);\
  BITUNBLK256V32_32(ip, 25, op, nb,parm);\
  BITUNBLK256V32_32(ip, 26, op, nb,parm);\
  BITUNBLK256V32_32(ip, 27, op, nb,parm);\
  BITUNBLK256V32_32(ip, 28, op, nb,parm);\
  BITUNBLK256V32_32(ip, 29, op, nb,parm);\
  BITUNBLK256V32_32(ip, 30, op, nb,parm);\
  BITUNBLK256V32_32(ip, 31, op, nb,parm);\
}

//#include "bitunpack_0.h"
#define BITUNPACK128V16(__ip, __nbits, __op, _parm_) { __m128i mv,*_ov=(__m128i *)__op,*_iv=(__m128i *)__ip; \
  switch(__nbits&0x3f) {\
    case  0: BITUNPACK0(_parm_);               BITUNPACK128V16_0( _iv, _ov,  0,_parm_); break;\
    case  1: mv = _mm_set1_epi16((1u<< 1)-1);  BITUNPACK128V16_1( _iv, _ov,  1,_parm_); break;\
    case  2: mv = _mm_set1_epi16((1u<< 2)-1);  BITUNPACK128V16_2( _iv, _ov,  2,_parm_); break;\
    case  3: mv = _mm_set1_epi16((1u<< 3)-1);  BITUNPACK128V16_3( _iv, _ov,  3,_parm_); break;\
    case  4: mv = _mm_set1_epi16((1u<< 4)-1);  BITUNPACK128V16_4( _iv, _ov,  4,_parm_); break;\
    case  5: mv = _mm_set1_epi16((1u<< 5)-1);  BITUNPACK128V16_5( _iv, _ov,  5,_parm_); break;\
    case  6: mv = _mm_set1_epi16((1u<< 6)-1);  BITUNPACK128V16_6( _iv, _ov,  6,_parm_); break;\
    case  7: mv = _mm_set1_epi16((1u<< 7)-1);  BITUNPACK128V16_7( _iv, _ov,  7,_parm_); break;\
    case  8: mv = _mm_set1_epi16((1u<< 8)-1);  BITUNPACK128V16_8( _iv, _ov,  8,_parm_); break;\
    case  9: mv = _mm_set1_epi16((1u<< 9)-1);  BITUNPACK128V16_9( _iv, _ov,  9,_parm_); break;\
    case 10: mv = _mm_set1_epi16((1u<<10)-1);  BITUNPACK128V16_10(_iv, _ov, 10,_parm_); break;\
    case 11: mv = _mm_set1_epi16((1u<<11)-1);  BITUNPACK128V16_11(_iv, _ov, 11,_parm_); break;\
    case 12: mv = _mm_set1_epi16((1u<<12)-1);  BITUNPACK128V16_12(_iv, _ov, 12,_parm_); break;\
    case 13: mv = _mm_set1_epi16((1u<<13)-1);  BITUNPACK128V16_13(_iv, _ov, 13,_parm_); break;\
    case 14: mv = _mm_set1_epi16((1u<<14)-1);  BITUNPACK128V16_14(_iv, _ov, 14,_parm_); break;\
    case 15: mv = _mm_set1_epi16((1u<<15)-1);  BITUNPACK128V16_15(_iv, _ov, 15,_parm_); break;\
    case 16: mv = _mm_set1_epi16((1u<<16)-1);  BITUNPACK128V16_16(_iv, _ov, BITMAX16,_parm_); break;\
    /*defaultcase 17 ... 63: break;*/\
  }\
}

#define BITUNPACK128V32(__ip, __nbits, __op, _parm_) { __m128i mv,*_ov=(__m128i *)__op,*_iv=(__m128i *)__ip; \
  switch(__nbits&0x3f) {\
    case  0: BITUNPACK0(_parm_);               BITUNPACK128V32_0( _iv, _ov,  0,_parm_); break;\
    case  1: mv = _mm_set1_epi32((1u<< 1)-1);  BITUNPACK128V32_1( _iv, _ov,  1,_parm_); break;\
    case  2: mv = _mm_set1_epi32((1u<< 2)-1);  BITUNPACK128V32_2( _iv, _ov,  2,_parm_); break;\
    case  3: mv = _mm_set1_epi32((1u<< 3)-1);  BITUNPACK128V32_3( _iv, _ov,  3,_parm_); break;\
    case  4: mv = _mm_set1_epi32((1u<< 4)-1);  BITUNPACK128V32_4( _iv, _ov,  4,_parm_); break;\
    case  5: mv = _mm_set1_epi32((1u<< 5)-1);  BITUNPACK128V32_5( _iv, _ov,  5,_parm_); break;\
    case  6: mv = _mm_set1_epi32((1u<< 6)-1);  BITUNPACK128V32_6( _iv, _ov,  6,_parm_); break;\
    case  7: mv = _mm_set1_epi32((1u<< 7)-1);  BITUNPACK128V32_7( _iv, _ov,  7,_parm_); break;\
    case  8: mv = _mm_set1_epi32((1u<< 8)-1);  BITUNPACK128V32_8( _iv, _ov,  8,_parm_); break;\
    case  9: mv = _mm_set1_epi32((1u<< 9)-1);  BITUNPACK128V32_9( _iv, _ov,  9,_parm_); break;\
    case 10: mv = _mm_set1_epi32((1u<<10)-1);  BITUNPACK128V32_10(_iv, _ov, 10,_parm_); break;\
    case 11: mv = _mm_set1_epi32((1u<<11)-1);  BITUNPACK128V32_11(_iv, _ov, 11,_parm_); break;\
    case 12: mv = _mm_set1_epi32((1u<<12)-1);  BITUNPACK128V32_12(_iv, _ov, 12,_parm_); break;\
    case 13: mv = _mm_set1_epi32((1u<<13)-1);  BITUNPACK128V32_13(_iv, _ov, 13,_parm_); break;\
    case 14: mv = _mm_set1_epi32((1u<<14)-1);  BITUNPACK128V32_14(_iv, _ov, 14,_parm_); break;\
    case 15: mv = _mm_set1_epi32((1u<<15)-1);  BITUNPACK128V32_15(_iv, _ov, 15,_parm_); break;\
    case 16: mv = _mm_set1_epi32((1u<<16)-1);  BITUNPACK128V32_16(_iv, _ov, 16,_parm_); break;\
    case 17: mv = _mm_set1_epi32((1u<<17)-1);  BITUNPACK128V32_17(_iv, _ov, 17,_parm_); break;\
    case 18: mv = _mm_set1_epi32((1u<<18)-1);  BITUNPACK128V32_18(_iv, _ov, 18,_parm_); break;\
    case 19: mv = _mm_set1_epi32((1u<<19)-1);  BITUNPACK128V32_19(_iv, _ov, 19,_parm_); break;\
    case 20: mv = _mm_set1_epi32((1u<<20)-1);  BITUNPACK128V32_20(_iv, _ov, 20,_parm_); break;\
    case 21: mv = _mm_set1_epi32((1u<<21)-1);  BITUNPACK128V32_21(_iv, _ov, 21,_parm_); break;\
    case 22: mv = _mm_set1_epi32((1u<<22)-1);  BITUNPACK128V32_22(_iv, _ov, 22,_parm_); break;\
    case 23: mv = _mm_set1_epi32((1u<<23)-1);  BITUNPACK128V32_23(_iv, _ov, 23,_parm_); break;\
    case 24: mv = _mm_set1_epi32((1u<<24)-1);  BITUNPACK128V32_24(_iv, _ov, 24,_parm_); break;\
    case 25: mv = _mm_set1_epi32((1u<<25)-1);  BITUNPACK128V32_25(_iv, _ov, 25,_parm_); break;\
    case 26: mv = _mm_set1_epi32((1u<<26)-1);  BITUNPACK128V32_26(_iv, _ov, 26,_parm_); break;\
    case 27: mv = _mm_set1_epi32((1u<<27)-1);  BITUNPACK128V32_27(_iv, _ov, 27,_parm_); break;\
    case 28: mv = _mm_set1_epi32((1u<<28)-1);  BITUNPACK128V32_28(_iv, _ov, 28,_parm_); break;\
    case 29: mv = _mm_set1_epi32((1u<<29)-1);  BITUNPACK128V32_29(_iv, _ov, 29,_parm_); break;\
    case 30: mv = _mm_set1_epi32((1u<<30)-1);  BITUNPACK128V32_30(_iv, _ov, 30,_parm_); break;\
    case 31: mv = _mm_set1_epi32((1u<<31)-1);  BITUNPACK128V32_31(_iv, _ov, 31,_parm_); break;\
    case 32: mv = _mm_set1_epi32((1ull<<32)-1);BITUNPACK128V32_32(_iv, _ov, BITMAX32,_parm_); break;\
    /*defaultcase 33 ... 63: break;*/\
  }\
}

#define BITUNPACK256V32(__ip, __nbits, __op, _parm_) { __m256i mv,*_ov=(__m256i *)__op,*_iv=(__m256i *)__ip; \
  switch(__nbits&0x3f) {\
    case  0: BITUNPACK0(_parm_);                  BITUNPACK256V32_0( _iv, _ov,  0,_parm_); break;\
    case  1: mv = _mm256_set1_epi32((1u<< 1)-1);  BITUNPACK256V32_1( _iv, _ov,  1,_parm_); break;\
    case  2: mv = _mm256_set1_epi32((1u<< 2)-1);  BITUNPACK256V32_2( _iv, _ov,  2,_parm_); break;\
    case  3: mv = _mm256_set1_epi32((1u<< 3)-1);  BITUNPACK256V32_3( _iv, _ov,  3,_parm_); break;\
    case  4: mv = _mm256_set1_epi32((1u<< 4)-1);  BITUNPACK256V32_4( _iv, _ov,  4,_parm_); break;\
    case  5: mv = _mm256_set1_epi32((1u<< 5)-1);  BITUNPACK256V32_5( _iv, _ov,  5,_parm_); break;\
    case  6: mv = _mm256_set1_epi32((1u<< 6)-1);  BITUNPACK256V32_6( _iv, _ov,  6,_parm_); break;\
    case  7: mv = _mm256_set1_epi32((1u<< 7)-1);  BITUNPACK256V32_7( _iv, _ov,  7,_parm_); break;\
    case  8: mv = _mm256_set1_epi32((1u<< 8)-1);  BITUNPACK256V32_8( _iv, _ov,  8,_parm_); break;\
    case  9: mv = _mm256_set1_epi32((1u<< 9)-1);  BITUNPACK256V32_9( _iv, _ov,  9,_parm_); break;\
    case 10: mv = _mm256_set1_epi32((1u<<10)-1);  BITUNPACK256V32_10(_iv, _ov, 10,_parm_); break;\
    case 11: mv = _mm256_set1_epi32((1u<<11)-1);  BITUNPACK256V32_11(_iv, _ov, 11, _parm_); break;\
    case 12: mv = _mm256_set1_epi32((1u<<12)-1);  BITUNPACK256V32_12(_iv, _ov, 12, _parm_); break;\
    case 13: mv = _mm256_set1_epi32((1u<<13)-1);  BITUNPACK256V32_13(_iv, _ov, 13, _parm_); break;\
    case 14: mv = _mm256_set1_epi32((1u<<14)-1);  BITUNPACK256V32_14(_iv, _ov, 14, _parm_); break;\
    case 15: mv = _mm256_set1_epi32((1u<<15)-1);  BITUNPACK256V32_15(_iv, _ov, 15, _parm_); break;\
    case 16: mv = _mm256_set1_epi32((1u<<16)-1);  BITUNPACK256V32_16(_iv, _ov, 16, _parm_); break;\
    case 17: mv = _mm256_set1_epi32((1u<<17)-1);  BITUNPACK256V32_17(_iv, _ov, 17, _parm_); break;\
    case 18: mv = _mm256_set1_epi32((1u<<18)-1);  BITUNPACK256V32_18(_iv, _ov, 18, _parm_); break;\
    case 19: mv = _mm256_set1_epi32((1u<<19)-1);  BITUNPACK256V32_19(_iv, _ov, 19, _parm_); break;\
    case 20: mv = _mm256_set1_epi32((1u<<20)-1);  BITUNPACK256V32_20(_iv, _ov, 20, _parm_); break;\
    case 21: mv = _mm256_set1_epi32((1u<<21)-1);  BITUNPACK256V32_21(_iv, _ov, 21, _parm_); break;\
    case 22: mv = _mm256_set1_epi32((1u<<22)-1);  BITUNPACK256V32_22(_iv, _ov, 22, _parm_); break;\
    case 23: mv = _mm256_set1_epi32((1u<<23)-1);  BITUNPACK256V32_23(_iv, _ov, 23, _parm_); break;\
    case 24: mv = _mm256_set1_epi32((1u<<24)-1);  BITUNPACK256V32_24(_iv, _ov, 24, _parm_); break;\
    case 25: mv = _mm256_set1_epi32((1u<<25)-1);  BITUNPACK256V32_25(_iv, _ov, 25, _parm_); break;\
    case 26: mv = _mm256_set1_epi32((1u<<26)-1);  BITUNPACK256V32_26(_iv, _ov, 26, _parm_); break;\
    case 27: mv = _mm256_set1_epi32((1u<<27)-1);  BITUNPACK256V32_27(_iv, _ov, 27, _parm_); break;\
    case 28: mv = _mm256_set1_epi32((1u<<28)-1);  BITUNPACK256V32_28(_iv, _ov, 28, _parm_); break;\
    case 29: mv = _mm256_set1_epi32((1u<<29)-1);  BITUNPACK256V32_29(_iv, _ov, 29, _parm_); break;\
    case 30: mv = _mm256_set1_epi32((1u<<30)-1);  BITUNPACK256V32_30(_iv, _ov, 30, _parm_); break;\
    case 31: mv = _mm256_set1_epi32((1u<<31)-1);  BITUNPACK256V32_31(_iv, _ov, 31, _parm_); break;\
    case 32: mv = _mm256_set1_epi32((1ull<<32)-1);BITUNPACK256V32_32(_iv, _ov, 32, _parm_); break;\
    /*case 33 ... 63: break;*/\
  }\
}

