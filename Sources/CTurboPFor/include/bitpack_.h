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
#ifdef IPI
#define BITBLK64_1(ip, i, op, parm) {   uint32_t w;;\
  IP9(ip, i*32+ 0, parm); w  = (uint32_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); w |= (uint32_t)IPV(ip, i*32+ 1) <<  1;\
  IP9(ip, i*32+ 2, parm); w |= (uint32_t)IPV(ip, i*32+ 2) <<  2;\
  IP9(ip, i*32+ 3, parm); w |= (uint32_t)IPV(ip, i*32+ 3) <<  3;\
  IP9(ip, i*32+ 4, parm); w |= (uint32_t)IPV(ip, i*32+ 4) <<  4;\
  IP9(ip, i*32+ 5, parm); w |= (uint32_t)IPV(ip, i*32+ 5) <<  5;\
  IP9(ip, i*32+ 6, parm); w |= (uint32_t)IPV(ip, i*32+ 6) <<  6;\
  IP9(ip, i*32+ 7, parm); w |= (uint32_t)IPV(ip, i*32+ 7) <<  7;\
  IP9(ip, i*32+ 8, parm); w |= (uint32_t)IPV(ip, i*32+ 8) <<  8;\
  IP9(ip, i*32+ 9, parm); w |= (uint32_t)IPV(ip, i*32+ 9) <<  9;\
  IP9(ip, i*32+10, parm); w |= (uint32_t)IPV(ip, i*32+10) << 10;\
  IP9(ip, i*32+11, parm); w |= (uint32_t)IPV(ip, i*32+11) << 11;\
  IP9(ip, i*32+12, parm); w |= (uint32_t)IPV(ip, i*32+12) << 12;\
  IP9(ip, i*32+13, parm); w |= (uint32_t)IPV(ip, i*32+13) << 13;\
  IP9(ip, i*32+14, parm); w |= (uint32_t)IPV(ip, i*32+14) << 14;\
  IP9(ip, i*32+15, parm); w |= (uint32_t)IPV(ip, i*32+15) << 15;\
  IP9(ip, i*32+16, parm); w |= (uint32_t)IPV(ip, i*32+16) << 16;\
  IP9(ip, i*32+17, parm); w |= (uint32_t)IPV(ip, i*32+17) << 17;\
  IP9(ip, i*32+18, parm); w |= (uint32_t)IPV(ip, i*32+18) << 18;\
  IP9(ip, i*32+19, parm); w |= (uint32_t)IPV(ip, i*32+19) << 19;\
  IP9(ip, i*32+20, parm); w |= (uint32_t)IPV(ip, i*32+20) << 20;\
  IP9(ip, i*32+21, parm); w |= (uint32_t)IPV(ip, i*32+21) << 21;\
  IP9(ip, i*32+22, parm); w |= (uint32_t)IPV(ip, i*32+22) << 22;\
  IP9(ip, i*32+23, parm); w |= (uint32_t)IPV(ip, i*32+23) << 23;\
  IP9(ip, i*32+24, parm); w |= (uint32_t)IPV(ip, i*32+24) << 24;\
  IP9(ip, i*32+25, parm); w |= (uint32_t)IPV(ip, i*32+25) << 25;\
  IP9(ip, i*32+26, parm); w |= (uint32_t)IPV(ip, i*32+26) << 26;\
  IP9(ip, i*32+27, parm); w |= (uint32_t)IPV(ip, i*32+27) << 27;\
  IP9(ip, i*32+28, parm); w |= (uint32_t)IPV(ip, i*32+28) << 28;\
  IP9(ip, i*32+29, parm); w |= (uint32_t)IPV(ip, i*32+29) << 29;\
  IP9(ip, i*32+30, parm); w |= (uint32_t)IPV(ip, i*32+30) << 30;\
  IP9(ip, i*32+31, parm); w |= (uint32_t)IPV(ip, i*32+31) << 31;*((uint32_t *)op+i*1+ 0) = w;;\
}

#define BITPACK64_1(ip,  op, parm) { \
  BITBLK64_1(ip, 0, op, parm);  IPI(ip); op += 1*4/sizeof(op[0]);\
}

#define BITBLK64_2(ip, i, op, parm) {   uint64_t w;;\
  IP9(ip, i*32+ 0, parm); w  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); w |= (uint64_t)IPV(ip, i*32+ 1) <<  2;\
  IP9(ip, i*32+ 2, parm); w |= (uint64_t)IPV(ip, i*32+ 2) <<  4;\
  IP9(ip, i*32+ 3, parm); w |= (uint64_t)IPV(ip, i*32+ 3) <<  6;\
  IP9(ip, i*32+ 4, parm); w |= (uint64_t)IPV(ip, i*32+ 4) <<  8;\
  IP9(ip, i*32+ 5, parm); w |= (uint64_t)IPV(ip, i*32+ 5) << 10;\
  IP9(ip, i*32+ 6, parm); w |= (uint64_t)IPV(ip, i*32+ 6) << 12;\
  IP9(ip, i*32+ 7, parm); w |= (uint64_t)IPV(ip, i*32+ 7) << 14;\
  IP9(ip, i*32+ 8, parm); w |= (uint64_t)IPV(ip, i*32+ 8) << 16;\
  IP9(ip, i*32+ 9, parm); w |= (uint64_t)IPV(ip, i*32+ 9) << 18;\
  IP9(ip, i*32+10, parm); w |= (uint64_t)IPV(ip, i*32+10) << 20;\
  IP9(ip, i*32+11, parm); w |= (uint64_t)IPV(ip, i*32+11) << 22;\
  IP9(ip, i*32+12, parm); w |= (uint64_t)IPV(ip, i*32+12) << 24;\
  IP9(ip, i*32+13, parm); w |= (uint64_t)IPV(ip, i*32+13) << 26;\
  IP9(ip, i*32+14, parm); w |= (uint64_t)IPV(ip, i*32+14) << 28;\
  IP9(ip, i*32+15, parm); w |= (uint64_t)IPV(ip, i*32+15) << 30;\
  IP9(ip, i*32+16, parm); w |= (uint64_t)IPV(ip, i*32+16) << 32;\
  IP9(ip, i*32+17, parm); w |= (uint64_t)IPV(ip, i*32+17) << 34;\
  IP9(ip, i*32+18, parm); w |= (uint64_t)IPV(ip, i*32+18) << 36;\
  IP9(ip, i*32+19, parm); w |= (uint64_t)IPV(ip, i*32+19) << 38;\
  IP9(ip, i*32+20, parm); w |= (uint64_t)IPV(ip, i*32+20) << 40;\
  IP9(ip, i*32+21, parm); w |= (uint64_t)IPV(ip, i*32+21) << 42;\
  IP9(ip, i*32+22, parm); w |= (uint64_t)IPV(ip, i*32+22) << 44;\
  IP9(ip, i*32+23, parm); w |= (uint64_t)IPV(ip, i*32+23) << 46;\
  IP9(ip, i*32+24, parm); w |= (uint64_t)IPV(ip, i*32+24) << 48;\
  IP9(ip, i*32+25, parm); w |= (uint64_t)IPV(ip, i*32+25) << 50;\
  IP9(ip, i*32+26, parm); w |= (uint64_t)IPV(ip, i*32+26) << 52;\
  IP9(ip, i*32+27, parm); w |= (uint64_t)IPV(ip, i*32+27) << 54;\
  IP9(ip, i*32+28, parm); w |= (uint64_t)IPV(ip, i*32+28) << 56;\
  IP9(ip, i*32+29, parm); w |= (uint64_t)IPV(ip, i*32+29) << 58;\
  IP9(ip, i*32+30, parm); w |= (uint64_t)IPV(ip, i*32+30) << 60;\
  IP9(ip, i*32+31, parm); w |= (uint64_t)IPV(ip, i*32+31) << 62;*((uint64_t *)op+i*1+ 0) = w;;\
}

#define BITPACK64_2(ip,  op, parm) { \
  BITBLK64_2(ip, 0, op, parm);  IPI(ip); op += 2*4/sizeof(op[0]);\
}

#define BITBLK64_3(ip, i, op, parm) {   uint64_t w;;\
  IP9(ip, i*64+ 0, parm); w  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); w |= (uint64_t)IPV(ip, i*64+ 1) <<  3;\
  IP9(ip, i*64+ 2, parm); w |= (uint64_t)IPV(ip, i*64+ 2) <<  6;\
  IP9(ip, i*64+ 3, parm); w |= (uint64_t)IPV(ip, i*64+ 3) <<  9;\
  IP9(ip, i*64+ 4, parm); w |= (uint64_t)IPV(ip, i*64+ 4) << 12;\
  IP9(ip, i*64+ 5, parm); w |= (uint64_t)IPV(ip, i*64+ 5) << 15;\
  IP9(ip, i*64+ 6, parm); w |= (uint64_t)IPV(ip, i*64+ 6) << 18;\
  IP9(ip, i*64+ 7, parm); w |= (uint64_t)IPV(ip, i*64+ 7) << 21;\
  IP9(ip, i*64+ 8, parm); w |= (uint64_t)IPV(ip, i*64+ 8) << 24;\
  IP9(ip, i*64+ 9, parm); w |= (uint64_t)IPV(ip, i*64+ 9) << 27;\
  IP9(ip, i*64+10, parm); w |= (uint64_t)IPV(ip, i*64+10) << 30;\
  IP9(ip, i*64+11, parm); w |= (uint64_t)IPV(ip, i*64+11) << 33;\
  IP9(ip, i*64+12, parm); w |= (uint64_t)IPV(ip, i*64+12) << 36;\
  IP9(ip, i*64+13, parm); w |= (uint64_t)IPV(ip, i*64+13) << 39;\
  IP9(ip, i*64+14, parm); w |= (uint64_t)IPV(ip, i*64+14) << 42;\
  IP9(ip, i*64+15, parm); w |= (uint64_t)IPV(ip, i*64+15) << 45;\
  IP9(ip, i*64+16, parm); w |= (uint64_t)IPV(ip, i*64+16) << 48;\
  IP9(ip, i*64+17, parm); w |= (uint64_t)IPV(ip, i*64+17) << 51;\
  IP9(ip, i*64+18, parm); w |= (uint64_t)IPV(ip, i*64+18) << 54;\
  IP9(ip, i*64+19, parm); w |= (uint64_t)IPV(ip, i*64+19) << 57;\
  IP9(ip, i*64+20, parm); w |= (uint64_t)IPV(ip, i*64+20) << 60 | (uint64_t)IPX(ip, i*64+21) << 63;*((uint64_t *)op+i*3+ 0) = w;\
  IP64(ip, i*64+21, parm); w  = (uint64_t)IPW(ip, i*64+21) >>  1;\
  IP9(ip, i*64+22, parm); w |= (uint64_t)IPV(ip, i*64+22) <<  2;\
  IP9(ip, i*64+23, parm); w |= (uint64_t)IPV(ip, i*64+23) <<  5;\
  IP9(ip, i*64+24, parm); w |= (uint64_t)IPV(ip, i*64+24) <<  8;\
  IP9(ip, i*64+25, parm); w |= (uint64_t)IPV(ip, i*64+25) << 11;\
  IP9(ip, i*64+26, parm); w |= (uint64_t)IPV(ip, i*64+26) << 14;\
  IP9(ip, i*64+27, parm); w |= (uint64_t)IPV(ip, i*64+27) << 17;\
  IP9(ip, i*64+28, parm); w |= (uint64_t)IPV(ip, i*64+28) << 20;\
  IP9(ip, i*64+29, parm); w |= (uint64_t)IPV(ip, i*64+29) << 23;\
  IP9(ip, i*64+30, parm); w |= (uint64_t)IPV(ip, i*64+30) << 26;\
  IP9(ip, i*64+31, parm); w |= (uint64_t)IPV(ip, i*64+31) << 29;*((uint64_t *)op+i*3+ 1) = w;;\
}

#define BITPACK64_3(ip,  op, parm) { \
  BITBLK64_3(ip, 0, op, parm);  IPI(ip); op += 3*4/sizeof(op[0]);\
}

#define BITBLK64_4(ip, i, op, parm) {   uint64_t w;;\
  IP9(ip, i*16+ 0, parm); w  = (uint64_t)IPV(ip, i*16+ 0)      ;\
  IP9(ip, i*16+ 1, parm); w |= (uint64_t)IPV(ip, i*16+ 1) <<  4;\
  IP9(ip, i*16+ 2, parm); w |= (uint64_t)IPV(ip, i*16+ 2) <<  8;\
  IP9(ip, i*16+ 3, parm); w |= (uint64_t)IPV(ip, i*16+ 3) << 12;\
  IP9(ip, i*16+ 4, parm); w |= (uint64_t)IPV(ip, i*16+ 4) << 16;\
  IP9(ip, i*16+ 5, parm); w |= (uint64_t)IPV(ip, i*16+ 5) << 20;\
  IP9(ip, i*16+ 6, parm); w |= (uint64_t)IPV(ip, i*16+ 6) << 24;\
  IP9(ip, i*16+ 7, parm); w |= (uint64_t)IPV(ip, i*16+ 7) << 28;\
  IP9(ip, i*16+ 8, parm); w |= (uint64_t)IPV(ip, i*16+ 8) << 32;\
  IP9(ip, i*16+ 9, parm); w |= (uint64_t)IPV(ip, i*16+ 9) << 36;\
  IP9(ip, i*16+10, parm); w |= (uint64_t)IPV(ip, i*16+10) << 40;\
  IP9(ip, i*16+11, parm); w |= (uint64_t)IPV(ip, i*16+11) << 44;\
  IP9(ip, i*16+12, parm); w |= (uint64_t)IPV(ip, i*16+12) << 48;\
  IP9(ip, i*16+13, parm); w |= (uint64_t)IPV(ip, i*16+13) << 52;\
  IP9(ip, i*16+14, parm); w |= (uint64_t)IPV(ip, i*16+14) << 56;\
  IP9(ip, i*16+15, parm); w |= (uint64_t)IPV(ip, i*16+15) << 60;*((uint64_t *)op+i*1+ 0) = w;;\
}

#define BITPACK64_4(ip,  op, parm) { \
  BITBLK64_4(ip, 0, op, parm);\
  BITBLK64_4(ip, 1, op, parm);  IPI(ip); op += 4*4/sizeof(op[0]);\
}

#define BITBLK64_5(ip, i, op, parm) {   uint64_t w;;\
  IP9(ip, i*64+ 0, parm); w  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); w |= (uint64_t)IPV(ip, i*64+ 1) <<  5;\
  IP9(ip, i*64+ 2, parm); w |= (uint64_t)IPV(ip, i*64+ 2) << 10;\
  IP9(ip, i*64+ 3, parm); w |= (uint64_t)IPV(ip, i*64+ 3) << 15;\
  IP9(ip, i*64+ 4, parm); w |= (uint64_t)IPV(ip, i*64+ 4) << 20;\
  IP9(ip, i*64+ 5, parm); w |= (uint64_t)IPV(ip, i*64+ 5) << 25;\
  IP9(ip, i*64+ 6, parm); w |= (uint64_t)IPV(ip, i*64+ 6) << 30;\
  IP9(ip, i*64+ 7, parm); w |= (uint64_t)IPV(ip, i*64+ 7) << 35;\
  IP9(ip, i*64+ 8, parm); w |= (uint64_t)IPV(ip, i*64+ 8) << 40;\
  IP9(ip, i*64+ 9, parm); w |= (uint64_t)IPV(ip, i*64+ 9) << 45;\
  IP9(ip, i*64+10, parm); w |= (uint64_t)IPV(ip, i*64+10) << 50;\
  IP9(ip, i*64+11, parm); w |= (uint64_t)IPV(ip, i*64+11) << 55 | (uint64_t)IPX(ip, i*64+12) << 60;*((uint64_t *)op+i*5+ 0) = w;\
  IP64(ip, i*64+12, parm); w  = (uint64_t)IPW(ip, i*64+12) >>  4;\
  IP9(ip, i*64+13, parm); w |= (uint64_t)IPV(ip, i*64+13) <<  1;\
  IP9(ip, i*64+14, parm); w |= (uint64_t)IPV(ip, i*64+14) <<  6;\
  IP9(ip, i*64+15, parm); w |= (uint64_t)IPV(ip, i*64+15) << 11;\
  IP9(ip, i*64+16, parm); w |= (uint64_t)IPV(ip, i*64+16) << 16;\
  IP9(ip, i*64+17, parm); w |= (uint64_t)IPV(ip, i*64+17) << 21;\
  IP9(ip, i*64+18, parm); w |= (uint64_t)IPV(ip, i*64+18) << 26;\
  IP9(ip, i*64+19, parm); w |= (uint64_t)IPV(ip, i*64+19) << 31;\
  IP9(ip, i*64+20, parm); w |= (uint64_t)IPV(ip, i*64+20) << 36;\
  IP9(ip, i*64+21, parm); w |= (uint64_t)IPV(ip, i*64+21) << 41;\
  IP9(ip, i*64+22, parm); w |= (uint64_t)IPV(ip, i*64+22) << 46;\
  IP9(ip, i*64+23, parm); w |= (uint64_t)IPV(ip, i*64+23) << 51;\
  IP9(ip, i*64+24, parm); w |= (uint64_t)IPV(ip, i*64+24) << 56 | (uint64_t)IPX(ip, i*64+25) << 61;*((uint64_t *)op+i*5+ 1) = w;\
  IP64(ip, i*64+25, parm); w  = (uint64_t)IPW(ip, i*64+25) >>  3;\
  IP9(ip, i*64+26, parm); w |= (uint64_t)IPV(ip, i*64+26) <<  2;\
  IP9(ip, i*64+27, parm); w |= (uint64_t)IPV(ip, i*64+27) <<  7;\
  IP9(ip, i*64+28, parm); w |= (uint64_t)IPV(ip, i*64+28) << 12;\
  IP9(ip, i*64+29, parm); w |= (uint64_t)IPV(ip, i*64+29) << 17;\
  IP9(ip, i*64+30, parm); w |= (uint64_t)IPV(ip, i*64+30) << 22;\
  IP9(ip, i*64+31, parm); w |= (uint64_t)IPV(ip, i*64+31) << 27;*((uint64_t *)op+i*5+ 2) = w;;\
}

#define BITPACK64_5(ip,  op, parm) { \
  BITBLK64_5(ip, 0, op, parm);  IPI(ip); op += 5*4/sizeof(op[0]);\
}

#define BITBLK64_6(ip, i, op, parm) {   uint64_t w;;\
  IP9(ip, i*32+ 0, parm); w  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); w |= (uint64_t)IPV(ip, i*32+ 1) <<  6;\
  IP9(ip, i*32+ 2, parm); w |= (uint64_t)IPV(ip, i*32+ 2) << 12;\
  IP9(ip, i*32+ 3, parm); w |= (uint64_t)IPV(ip, i*32+ 3) << 18;\
  IP9(ip, i*32+ 4, parm); w |= (uint64_t)IPV(ip, i*32+ 4) << 24;\
  IP9(ip, i*32+ 5, parm); w |= (uint64_t)IPV(ip, i*32+ 5) << 30;\
  IP9(ip, i*32+ 6, parm); w |= (uint64_t)IPV(ip, i*32+ 6) << 36;\
  IP9(ip, i*32+ 7, parm); w |= (uint64_t)IPV(ip, i*32+ 7) << 42;\
  IP9(ip, i*32+ 8, parm); w |= (uint64_t)IPV(ip, i*32+ 8) << 48;\
  IP9(ip, i*32+ 9, parm); w |= (uint64_t)IPV(ip, i*32+ 9) << 54 | (uint64_t)IPX(ip, i*32+10) << 60;*((uint64_t *)op+i*3+ 0) = w;\
  IP64(ip, i*32+10, parm); w  = (uint64_t)IPW(ip, i*32+10) >>  4;\
  IP9(ip, i*32+11, parm); w |= (uint64_t)IPV(ip, i*32+11) <<  2;\
  IP9(ip, i*32+12, parm); w |= (uint64_t)IPV(ip, i*32+12) <<  8;\
  IP9(ip, i*32+13, parm); w |= (uint64_t)IPV(ip, i*32+13) << 14;\
  IP9(ip, i*32+14, parm); w |= (uint64_t)IPV(ip, i*32+14) << 20;\
  IP9(ip, i*32+15, parm); w |= (uint64_t)IPV(ip, i*32+15) << 26;\
  IP9(ip, i*32+16, parm); w |= (uint64_t)IPV(ip, i*32+16) << 32;\
  IP9(ip, i*32+17, parm); w |= (uint64_t)IPV(ip, i*32+17) << 38;\
  IP9(ip, i*32+18, parm); w |= (uint64_t)IPV(ip, i*32+18) << 44;\
  IP9(ip, i*32+19, parm); w |= (uint64_t)IPV(ip, i*32+19) << 50;\
  IP9(ip, i*32+20, parm); w |= (uint64_t)IPV(ip, i*32+20) << 56 | (uint64_t)IPX(ip, i*32+21) << 62;*((uint64_t *)op+i*3+ 1) = w;\
  IP64(ip, i*32+21, parm); w  = (uint64_t)IPW(ip, i*32+21) >>  2;\
  IP9(ip, i*32+22, parm); w |= (uint64_t)IPV(ip, i*32+22) <<  4;\
  IP9(ip, i*32+23, parm); w |= (uint64_t)IPV(ip, i*32+23) << 10;\
  IP9(ip, i*32+24, parm); w |= (uint64_t)IPV(ip, i*32+24) << 16;\
  IP9(ip, i*32+25, parm); w |= (uint64_t)IPV(ip, i*32+25) << 22;\
  IP9(ip, i*32+26, parm); w |= (uint64_t)IPV(ip, i*32+26) << 28;\
  IP9(ip, i*32+27, parm); w |= (uint64_t)IPV(ip, i*32+27) << 34;\
  IP9(ip, i*32+28, parm); w |= (uint64_t)IPV(ip, i*32+28) << 40;\
  IP9(ip, i*32+29, parm); w |= (uint64_t)IPV(ip, i*32+29) << 46;\
  IP9(ip, i*32+30, parm); w |= (uint64_t)IPV(ip, i*32+30) << 52;\
  IP9(ip, i*32+31, parm); w |= (uint64_t)IPV(ip, i*32+31) << 58;*((uint64_t *)op+i*3+ 2) = w;;\
}

#define BITPACK64_6(ip,  op, parm) { \
  BITBLK64_6(ip, 0, op, parm);  IPI(ip); op += 6*4/sizeof(op[0]);\
}

#define BITBLK64_7(ip, i, op, parm) {   uint64_t w;;\
  IP9(ip, i*64+ 0, parm); w  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); w |= (uint64_t)IPV(ip, i*64+ 1) <<  7;\
  IP9(ip, i*64+ 2, parm); w |= (uint64_t)IPV(ip, i*64+ 2) << 14;\
  IP9(ip, i*64+ 3, parm); w |= (uint64_t)IPV(ip, i*64+ 3) << 21;\
  IP9(ip, i*64+ 4, parm); w |= (uint64_t)IPV(ip, i*64+ 4) << 28;\
  IP9(ip, i*64+ 5, parm); w |= (uint64_t)IPV(ip, i*64+ 5) << 35;\
  IP9(ip, i*64+ 6, parm); w |= (uint64_t)IPV(ip, i*64+ 6) << 42;\
  IP9(ip, i*64+ 7, parm); w |= (uint64_t)IPV(ip, i*64+ 7) << 49;\
  IP9(ip, i*64+ 8, parm); w |= (uint64_t)IPV(ip, i*64+ 8) << 56 | (uint64_t)IPX(ip, i*64+9) << 63;*((uint64_t *)op+i*7+ 0) = w;\
  IP64(ip, i*64+ 9, parm); w  = (uint64_t)IPW(ip, i*64+ 9) >>  1;\
  IP9(ip, i*64+10, parm); w |= (uint64_t)IPV(ip, i*64+10) <<  6;\
  IP9(ip, i*64+11, parm); w |= (uint64_t)IPV(ip, i*64+11) << 13;\
  IP9(ip, i*64+12, parm); w |= (uint64_t)IPV(ip, i*64+12) << 20;\
  IP9(ip, i*64+13, parm); w |= (uint64_t)IPV(ip, i*64+13) << 27;\
  IP9(ip, i*64+14, parm); w |= (uint64_t)IPV(ip, i*64+14) << 34;\
  IP9(ip, i*64+15, parm); w |= (uint64_t)IPV(ip, i*64+15) << 41;\
  IP9(ip, i*64+16, parm); w |= (uint64_t)IPV(ip, i*64+16) << 48;\
  IP9(ip, i*64+17, parm); w |= (uint64_t)IPV(ip, i*64+17) << 55 | (uint64_t)IPX(ip, i*64+18) << 62;*((uint64_t *)op+i*7+ 1) = w;\
  IP64(ip, i*64+18, parm); w  = (uint64_t)IPW(ip, i*64+18) >>  2;\
  IP9(ip, i*64+19, parm); w |= (uint64_t)IPV(ip, i*64+19) <<  5;\
  IP9(ip, i*64+20, parm); w |= (uint64_t)IPV(ip, i*64+20) << 12;\
  IP9(ip, i*64+21, parm); w |= (uint64_t)IPV(ip, i*64+21) << 19;\
  IP9(ip, i*64+22, parm); w |= (uint64_t)IPV(ip, i*64+22) << 26;\
  IP9(ip, i*64+23, parm); w |= (uint64_t)IPV(ip, i*64+23) << 33;\
  IP9(ip, i*64+24, parm); w |= (uint64_t)IPV(ip, i*64+24) << 40;\
  IP9(ip, i*64+25, parm); w |= (uint64_t)IPV(ip, i*64+25) << 47;\
  IP9(ip, i*64+26, parm); w |= (uint64_t)IPV(ip, i*64+26) << 54 | (uint64_t)IPX(ip, i*64+27) << 61;*((uint64_t *)op+i*7+ 2) = w;\
  IP64(ip, i*64+27, parm); w  = (uint64_t)IPW(ip, i*64+27) >>  3;\
  IP9(ip, i*64+28, parm); w |= (uint64_t)IPV(ip, i*64+28) <<  4;\
  IP9(ip, i*64+29, parm); w |= (uint64_t)IPV(ip, i*64+29) << 11;\
  IP9(ip, i*64+30, parm); w |= (uint64_t)IPV(ip, i*64+30) << 18;\
  IP9(ip, i*64+31, parm); w |= (uint64_t)IPV(ip, i*64+31) << 25;*((uint64_t *)op+i*7+ 3) = w;;\
}

#define BITPACK64_7(ip,  op, parm) { \
  BITBLK64_7(ip, 0, op, parm);  IPI(ip); op += 7*4/sizeof(op[0]);\
}

#define BITBLK64_8(ip, i, op, parm) { ;\
  IP9(ip, i*8+ 0, parm); *((uint64_t *)op+i*1+ 0)  = (uint64_t)IPV(ip, i*8+ 0)      ;\
  IP9(ip, i*8+ 1, parm); *((uint64_t *)op+i*1+ 0) |= (uint64_t)IPV(ip, i*8+ 1) <<  8;\
  IP9(ip, i*8+ 2, parm); *((uint64_t *)op+i*1+ 0) |= (uint64_t)IPV(ip, i*8+ 2) << 16;\
  IP9(ip, i*8+ 3, parm); *((uint64_t *)op+i*1+ 0) |= (uint64_t)IPV(ip, i*8+ 3) << 24;\
  IP9(ip, i*8+ 4, parm); *((uint64_t *)op+i*1+ 0) |= (uint64_t)IPV(ip, i*8+ 4) << 32;\
  IP9(ip, i*8+ 5, parm); *((uint64_t *)op+i*1+ 0) |= (uint64_t)IPV(ip, i*8+ 5) << 40;\
  IP9(ip, i*8+ 6, parm); *((uint64_t *)op+i*1+ 0) |= (uint64_t)IPV(ip, i*8+ 6) << 48;\
  IP9(ip, i*8+ 7, parm); *((uint64_t *)op+i*1+ 0) |= (uint64_t)IPV(ip, i*8+ 7) << 56;\
}

#define BITPACK64_8(ip,  op, parm) { \
  BITBLK64_8(ip, 0, op, parm);\
  BITBLK64_8(ip, 1, op, parm);\
  BITBLK64_8(ip, 2, op, parm);\
  BITBLK64_8(ip, 3, op, parm);  IPI(ip); op += 8*4/sizeof(op[0]);\
}

#define BITBLK64_9(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*9+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*64+ 1) <<  9;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*64+ 2) << 18;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*64+ 3) << 27;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*64+ 4) << 36;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*64+ 5) << 45;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*64+ 6) << 54 | (uint64_t)IPX(ip, i*64+7) << 63;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*9+ 1)  = (uint64_t)IPW(ip, i*64+ 7) >>  1;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*64+ 8) <<  8;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*64+ 9) << 17;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*64+10) << 26;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*64+11) << 35;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*64+12) << 44;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*64+13) << 53 | (uint64_t)IPX(ip, i*64+14) << 62;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*9+ 2)  = (uint64_t)IPW(ip, i*64+14) >>  2;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*64+15) <<  7;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*64+16) << 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*64+17) << 25;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*64+18) << 34;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*64+19) << 43;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*64+20) << 52 | (uint64_t)IPX(ip, i*64+21) << 61;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*9+ 3)  = (uint64_t)IPW(ip, i*64+21) >>  3;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*64+22) <<  6;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*64+23) << 15;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*64+24) << 24;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*64+25) << 33;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*64+26) << 42;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*64+27) << 51 | (uint64_t)IPX(ip, i*64+28) << 60;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*9+ 4)  = (uint64_t)IPW(ip, i*64+28) >>  4;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*9+ 4) |= (uint64_t)IPV(ip, i*64+29) <<  5;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*9+ 4) |= (uint64_t)IPV(ip, i*64+30) << 14;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*9+ 4) |= (uint64_t)IPV(ip, i*64+31) << 23;\
}

#define BITPACK64_9(ip,  op, parm) { \
  BITBLK64_9(ip, 0, op, parm);  IPI(ip); op += 9*4/sizeof(op[0]);\
}

#define BITBLK64_10(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*5+ 0)  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); *((uint64_t *)op+i*5+ 0) |= (uint64_t)IPV(ip, i*32+ 1) << 10;\
  IP9(ip, i*32+ 2, parm); *((uint64_t *)op+i*5+ 0) |= (uint64_t)IPV(ip, i*32+ 2) << 20;\
  IP9(ip, i*32+ 3, parm); *((uint64_t *)op+i*5+ 0) |= (uint64_t)IPV(ip, i*32+ 3) << 30;\
  IP9(ip, i*32+ 4, parm); *((uint64_t *)op+i*5+ 0) |= (uint64_t)IPV(ip, i*32+ 4) << 40;\
  IP9(ip, i*32+ 5, parm); *((uint64_t *)op+i*5+ 0) |= (uint64_t)IPV(ip, i*32+ 5) << 50 | (uint64_t)IPX(ip, i*32+6) << 60;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*5+ 1)  = (uint64_t)IPW(ip, i*32+ 6) >>  4;\
  IP9(ip, i*32+ 7, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*32+ 7) <<  6;\
  IP9(ip, i*32+ 8, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*32+ 8) << 16;\
  IP9(ip, i*32+ 9, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*32+ 9) << 26;\
  IP9(ip, i*32+10, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*32+10) << 36;\
  IP9(ip, i*32+11, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*32+11) << 46 | (uint64_t)IPX(ip, i*32+12) << 56;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*5+ 2)  = (uint64_t)IPW(ip, i*32+12) >>  8;\
  IP9(ip, i*32+13, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*32+13) <<  2;\
  IP9(ip, i*32+14, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*32+14) << 12;\
  IP9(ip, i*32+15, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*32+15) << 22;\
  IP9(ip, i*32+16, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*32+16) << 32;\
  IP9(ip, i*32+17, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*32+17) << 42;\
  IP9(ip, i*32+18, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*32+18) << 52 | (uint64_t)IPX(ip, i*32+19) << 62;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*5+ 3)  = (uint64_t)IPW(ip, i*32+19) >>  2;\
  IP9(ip, i*32+20, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*32+20) <<  8;\
  IP9(ip, i*32+21, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*32+21) << 18;\
  IP9(ip, i*32+22, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*32+22) << 28;\
  IP9(ip, i*32+23, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*32+23) << 38;\
  IP9(ip, i*32+24, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*32+24) << 48 | (uint64_t)IPX(ip, i*32+25) << 58;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*5+ 4)  = (uint64_t)IPW(ip, i*32+25) >>  6;\
  IP9(ip, i*32+26, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*32+26) <<  4;\
  IP9(ip, i*32+27, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*32+27) << 14;\
  IP9(ip, i*32+28, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*32+28) << 24;\
  IP9(ip, i*32+29, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*32+29) << 34;\
  IP9(ip, i*32+30, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*32+30) << 44;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*32+31) << 54;\
}

#define BITPACK64_10(ip,  op, parm) { \
  BITBLK64_10(ip, 0, op, parm);  IPI(ip); op += 10*4/sizeof(op[0]);\
}

#define BITBLK64_11(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*11+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*11+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 11;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*11+ 0) |= (uint64_t)IPV(ip, i*64+ 2) << 22;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*11+ 0) |= (uint64_t)IPV(ip, i*64+ 3) << 33;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*11+ 0) |= (uint64_t)IPV(ip, i*64+ 4) << 44 | (uint64_t)IPX(ip, i*64+5) << 55;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*11+ 1)  = (uint64_t)IPW(ip, i*64+ 5) >>  9;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*11+ 1) |= (uint64_t)IPV(ip, i*64+ 6) <<  2;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*11+ 1) |= (uint64_t)IPV(ip, i*64+ 7) << 13;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*11+ 1) |= (uint64_t)IPV(ip, i*64+ 8) << 24;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*11+ 1) |= (uint64_t)IPV(ip, i*64+ 9) << 35;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*11+ 1) |= (uint64_t)IPV(ip, i*64+10) << 46 | (uint64_t)IPX(ip, i*64+11) << 57;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*11+ 2)  = (uint64_t)IPW(ip, i*64+11) >>  7;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*64+12) <<  4;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*64+13) << 15;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*64+14) << 26;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*64+15) << 37;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*64+16) << 48 | (uint64_t)IPX(ip, i*64+17) << 59;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*11+ 3)  = (uint64_t)IPW(ip, i*64+17) >>  5;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*11+ 3) |= (uint64_t)IPV(ip, i*64+18) <<  6;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*11+ 3) |= (uint64_t)IPV(ip, i*64+19) << 17;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*11+ 3) |= (uint64_t)IPV(ip, i*64+20) << 28;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*11+ 3) |= (uint64_t)IPV(ip, i*64+21) << 39;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*11+ 3) |= (uint64_t)IPV(ip, i*64+22) << 50 | (uint64_t)IPX(ip, i*64+23) << 61;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*11+ 4)  = (uint64_t)IPW(ip, i*64+23) >>  3;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*64+24) <<  8;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*64+25) << 19;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*64+26) << 30;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*64+27) << 41;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*64+28) << 52 | (uint64_t)IPX(ip, i*64+29) << 63;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*11+ 5)  = (uint64_t)IPW(ip, i*64+29) >>  1;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*11+ 5) |= (uint64_t)IPV(ip, i*64+30) << 10;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*11+ 5) |= (uint64_t)IPV(ip, i*64+31) << 21;\
}

#define BITPACK64_11(ip,  op, parm) { \
  BITBLK64_11(ip, 0, op, parm);  IPI(ip); op += 11*4/sizeof(op[0]);\
}

#define BITBLK64_12(ip, i, op, parm) { ;\
  IP9(ip, i*16+ 0, parm); *((uint64_t *)op+i*3+ 0)  = (uint64_t)IPV(ip, i*16+ 0)      ;\
  IP9(ip, i*16+ 1, parm); *((uint64_t *)op+i*3+ 0) |= (uint64_t)IPV(ip, i*16+ 1) << 12;\
  IP9(ip, i*16+ 2, parm); *((uint64_t *)op+i*3+ 0) |= (uint64_t)IPV(ip, i*16+ 2) << 24;\
  IP9(ip, i*16+ 3, parm); *((uint64_t *)op+i*3+ 0) |= (uint64_t)IPV(ip, i*16+ 3) << 36;\
  IP9(ip, i*16+ 4, parm); *((uint64_t *)op+i*3+ 0) |= (uint64_t)IPV(ip, i*16+ 4) << 48 | (uint64_t)IPX(ip, i*16+5) << 60;\
  IP64(ip, i*16+ 5, parm); *((uint64_t *)op+i*3+ 1)  = (uint64_t)IPW(ip, i*16+ 5) >>  4;\
  IP9(ip, i*16+ 6, parm); *((uint64_t *)op+i*3+ 1) |= (uint64_t)IPV(ip, i*16+ 6) <<  8;\
  IP9(ip, i*16+ 7, parm); *((uint64_t *)op+i*3+ 1) |= (uint64_t)IPV(ip, i*16+ 7) << 20;\
  IP9(ip, i*16+ 8, parm); *((uint64_t *)op+i*3+ 1) |= (uint64_t)IPV(ip, i*16+ 8) << 32;\
  IP9(ip, i*16+ 9, parm); *((uint64_t *)op+i*3+ 1) |= (uint64_t)IPV(ip, i*16+ 9) << 44 | (uint64_t)IPX(ip, i*16+10) << 56;\
  IP64(ip, i*16+10, parm); *((uint64_t *)op+i*3+ 2)  = (uint64_t)IPW(ip, i*16+10) >>  8;\
  IP9(ip, i*16+11, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*16+11) <<  4;\
  IP9(ip, i*16+12, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*16+12) << 16;\
  IP9(ip, i*16+13, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*16+13) << 28;\
  IP9(ip, i*16+14, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*16+14) << 40;\
  IP9(ip, i*16+15, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*16+15) << 52;\
}

#define BITPACK64_12(ip,  op, parm) { \
  BITBLK64_12(ip, 0, op, parm);\
  BITBLK64_12(ip, 1, op, parm);  IPI(ip); op += 12*4/sizeof(op[0]);\
}

#define BITBLK64_13(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*13+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*13+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 13;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*13+ 0) |= (uint64_t)IPV(ip, i*64+ 2) << 26;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*13+ 0) |= (uint64_t)IPV(ip, i*64+ 3) << 39 | (uint64_t)IPX(ip, i*64+4) << 52;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*13+ 1)  = (uint64_t)IPW(ip, i*64+ 4) >> 12;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*13+ 1) |= (uint64_t)IPV(ip, i*64+ 5) <<  1;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*13+ 1) |= (uint64_t)IPV(ip, i*64+ 6) << 14;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*13+ 1) |= (uint64_t)IPV(ip, i*64+ 7) << 27;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*13+ 1) |= (uint64_t)IPV(ip, i*64+ 8) << 40 | (uint64_t)IPX(ip, i*64+9) << 53;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*13+ 2)  = (uint64_t)IPW(ip, i*64+ 9) >> 11;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*13+ 2) |= (uint64_t)IPV(ip, i*64+10) <<  2;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*13+ 2) |= (uint64_t)IPV(ip, i*64+11) << 15;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*13+ 2) |= (uint64_t)IPV(ip, i*64+12) << 28;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*13+ 2) |= (uint64_t)IPV(ip, i*64+13) << 41 | (uint64_t)IPX(ip, i*64+14) << 54;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*13+ 3)  = (uint64_t)IPW(ip, i*64+14) >> 10;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*13+ 3) |= (uint64_t)IPV(ip, i*64+15) <<  3;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*13+ 3) |= (uint64_t)IPV(ip, i*64+16) << 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*13+ 3) |= (uint64_t)IPV(ip, i*64+17) << 29;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*13+ 3) |= (uint64_t)IPV(ip, i*64+18) << 42 | (uint64_t)IPX(ip, i*64+19) << 55;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*13+ 4)  = (uint64_t)IPW(ip, i*64+19) >>  9;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*13+ 4) |= (uint64_t)IPV(ip, i*64+20) <<  4;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*13+ 4) |= (uint64_t)IPV(ip, i*64+21) << 17;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*13+ 4) |= (uint64_t)IPV(ip, i*64+22) << 30;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*13+ 4) |= (uint64_t)IPV(ip, i*64+23) << 43 | (uint64_t)IPX(ip, i*64+24) << 56;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*13+ 5)  = (uint64_t)IPW(ip, i*64+24) >>  8;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*13+ 5) |= (uint64_t)IPV(ip, i*64+25) <<  5;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*13+ 5) |= (uint64_t)IPV(ip, i*64+26) << 18;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*13+ 5) |= (uint64_t)IPV(ip, i*64+27) << 31;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*13+ 5) |= (uint64_t)IPV(ip, i*64+28) << 44 | (uint64_t)IPX(ip, i*64+29) << 57;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*13+ 6)  = (uint64_t)IPW(ip, i*64+29) >>  7;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*13+ 6) |= (uint64_t)IPV(ip, i*64+30) <<  6;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*13+ 6) |= (uint64_t)IPV(ip, i*64+31) << 19;\
}

#define BITPACK64_13(ip,  op, parm) { \
  BITBLK64_13(ip, 0, op, parm);  IPI(ip); op += 13*4/sizeof(op[0]);\
}

#define BITBLK64_14(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*7+ 0)  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); *((uint64_t *)op+i*7+ 0) |= (uint64_t)IPV(ip, i*32+ 1) << 14;\
  IP9(ip, i*32+ 2, parm); *((uint64_t *)op+i*7+ 0) |= (uint64_t)IPV(ip, i*32+ 2) << 28;\
  IP9(ip, i*32+ 3, parm); *((uint64_t *)op+i*7+ 0) |= (uint64_t)IPV(ip, i*32+ 3) << 42 | (uint64_t)IPX(ip, i*32+4) << 56;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*7+ 1)  = (uint64_t)IPW(ip, i*32+ 4) >>  8;\
  IP9(ip, i*32+ 5, parm); *((uint64_t *)op+i*7+ 1) |= (uint64_t)IPV(ip, i*32+ 5) <<  6;\
  IP9(ip, i*32+ 6, parm); *((uint64_t *)op+i*7+ 1) |= (uint64_t)IPV(ip, i*32+ 6) << 20;\
  IP9(ip, i*32+ 7, parm); *((uint64_t *)op+i*7+ 1) |= (uint64_t)IPV(ip, i*32+ 7) << 34;\
  IP9(ip, i*32+ 8, parm); *((uint64_t *)op+i*7+ 1) |= (uint64_t)IPV(ip, i*32+ 8) << 48 | (uint64_t)IPX(ip, i*32+9) << 62;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*7+ 2)  = (uint64_t)IPW(ip, i*32+ 9) >>  2;\
  IP9(ip, i*32+10, parm); *((uint64_t *)op+i*7+ 2) |= (uint64_t)IPV(ip, i*32+10) << 12;\
  IP9(ip, i*32+11, parm); *((uint64_t *)op+i*7+ 2) |= (uint64_t)IPV(ip, i*32+11) << 26;\
  IP9(ip, i*32+12, parm); *((uint64_t *)op+i*7+ 2) |= (uint64_t)IPV(ip, i*32+12) << 40 | (uint64_t)IPX(ip, i*32+13) << 54;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*7+ 3)  = (uint64_t)IPW(ip, i*32+13) >> 10;\
  IP9(ip, i*32+14, parm); *((uint64_t *)op+i*7+ 3) |= (uint64_t)IPV(ip, i*32+14) <<  4;\
  IP9(ip, i*32+15, parm); *((uint64_t *)op+i*7+ 3) |= (uint64_t)IPV(ip, i*32+15) << 18;\
  IP9(ip, i*32+16, parm); *((uint64_t *)op+i*7+ 3) |= (uint64_t)IPV(ip, i*32+16) << 32;\
  IP9(ip, i*32+17, parm); *((uint64_t *)op+i*7+ 3) |= (uint64_t)IPV(ip, i*32+17) << 46 | (uint64_t)IPX(ip, i*32+18) << 60;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*7+ 4)  = (uint64_t)IPW(ip, i*32+18) >>  4;\
  IP9(ip, i*32+19, parm); *((uint64_t *)op+i*7+ 4) |= (uint64_t)IPV(ip, i*32+19) << 10;\
  IP9(ip, i*32+20, parm); *((uint64_t *)op+i*7+ 4) |= (uint64_t)IPV(ip, i*32+20) << 24;\
  IP9(ip, i*32+21, parm); *((uint64_t *)op+i*7+ 4) |= (uint64_t)IPV(ip, i*32+21) << 38 | (uint64_t)IPX(ip, i*32+22) << 52;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*7+ 5)  = (uint64_t)IPW(ip, i*32+22) >> 12;\
  IP9(ip, i*32+23, parm); *((uint64_t *)op+i*7+ 5) |= (uint64_t)IPV(ip, i*32+23) <<  2;\
  IP9(ip, i*32+24, parm); *((uint64_t *)op+i*7+ 5) |= (uint64_t)IPV(ip, i*32+24) << 16;\
  IP9(ip, i*32+25, parm); *((uint64_t *)op+i*7+ 5) |= (uint64_t)IPV(ip, i*32+25) << 30;\
  IP9(ip, i*32+26, parm); *((uint64_t *)op+i*7+ 5) |= (uint64_t)IPV(ip, i*32+26) << 44 | (uint64_t)IPX(ip, i*32+27) << 58;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*7+ 6)  = (uint64_t)IPW(ip, i*32+27) >>  6;\
  IP9(ip, i*32+28, parm); *((uint64_t *)op+i*7+ 6) |= (uint64_t)IPV(ip, i*32+28) <<  8;\
  IP9(ip, i*32+29, parm); *((uint64_t *)op+i*7+ 6) |= (uint64_t)IPV(ip, i*32+29) << 22;\
  IP9(ip, i*32+30, parm); *((uint64_t *)op+i*7+ 6) |= (uint64_t)IPV(ip, i*32+30) << 36;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*7+ 6) |= (uint64_t)IPV(ip, i*32+31) << 50;\
}

#define BITPACK64_14(ip,  op, parm) { \
  BITBLK64_14(ip, 0, op, parm);  IPI(ip); op += 14*4/sizeof(op[0]);\
}

#define BITBLK64_15(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*15+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*15+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 15;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*15+ 0) |= (uint64_t)IPV(ip, i*64+ 2) << 30;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*15+ 0) |= (uint64_t)IPV(ip, i*64+ 3) << 45 | (uint64_t)IPX(ip, i*64+4) << 60;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*15+ 1)  = (uint64_t)IPW(ip, i*64+ 4) >>  4;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*15+ 1) |= (uint64_t)IPV(ip, i*64+ 5) << 11;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*15+ 1) |= (uint64_t)IPV(ip, i*64+ 6) << 26;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*15+ 1) |= (uint64_t)IPV(ip, i*64+ 7) << 41 | (uint64_t)IPX(ip, i*64+8) << 56;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*15+ 2)  = (uint64_t)IPW(ip, i*64+ 8) >>  8;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*15+ 2) |= (uint64_t)IPV(ip, i*64+ 9) <<  7;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*15+ 2) |= (uint64_t)IPV(ip, i*64+10) << 22;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*15+ 2) |= (uint64_t)IPV(ip, i*64+11) << 37 | (uint64_t)IPX(ip, i*64+12) << 52;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*15+ 3)  = (uint64_t)IPW(ip, i*64+12) >> 12;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*15+ 3) |= (uint64_t)IPV(ip, i*64+13) <<  3;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*15+ 3) |= (uint64_t)IPV(ip, i*64+14) << 18;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*15+ 3) |= (uint64_t)IPV(ip, i*64+15) << 33;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*15+ 3) |= (uint64_t)IPV(ip, i*64+16) << 48 | (uint64_t)IPX(ip, i*64+17) << 63;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*15+ 4)  = (uint64_t)IPW(ip, i*64+17) >>  1;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*15+ 4) |= (uint64_t)IPV(ip, i*64+18) << 14;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*15+ 4) |= (uint64_t)IPV(ip, i*64+19) << 29;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*15+ 4) |= (uint64_t)IPV(ip, i*64+20) << 44 | (uint64_t)IPX(ip, i*64+21) << 59;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*15+ 5)  = (uint64_t)IPW(ip, i*64+21) >>  5;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*15+ 5) |= (uint64_t)IPV(ip, i*64+22) << 10;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*15+ 5) |= (uint64_t)IPV(ip, i*64+23) << 25;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*15+ 5) |= (uint64_t)IPV(ip, i*64+24) << 40 | (uint64_t)IPX(ip, i*64+25) << 55;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*15+ 6)  = (uint64_t)IPW(ip, i*64+25) >>  9;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*15+ 6) |= (uint64_t)IPV(ip, i*64+26) <<  6;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*15+ 6) |= (uint64_t)IPV(ip, i*64+27) << 21;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*15+ 6) |= (uint64_t)IPV(ip, i*64+28) << 36 | (uint64_t)IPX(ip, i*64+29) << 51;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*15+ 7)  = (uint64_t)IPW(ip, i*64+29) >> 13;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*15+ 7) |= (uint64_t)IPV(ip, i*64+30) <<  2;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*15+ 7) |= (uint64_t)IPV(ip, i*64+31) << 17;\
}

#define BITPACK64_15(ip,  op, parm) { \
  BITBLK64_15(ip, 0, op, parm);  IPI(ip); op += 15*4/sizeof(op[0]);\
}

#define BITBLK64_16(ip, i, op, parm) { \
  IP9(ip, i*4+ 0, parm); *(uint16_t *)(op+i*8+ 0) = IPV(ip, i*4+ 0);\
  IP9(ip, i*4+ 1, parm); *(uint16_t *)(op+i*8+ 2) = IPV(ip, i*4+ 1);\
  IP9(ip, i*4+ 2, parm); *(uint16_t *)(op+i*8+ 4) = IPV(ip, i*4+ 2);\
  IP9(ip, i*4+ 3, parm); *(uint16_t *)(op+i*8+ 6) = IPV(ip, i*4+ 3);;\
}

#define BITPACK64_16(ip,  op, parm) { \
  BITBLK64_16(ip, 0, op, parm);\
  BITBLK64_16(ip, 1, op, parm);\
  BITBLK64_16(ip, 2, op, parm);\
  BITBLK64_16(ip, 3, op, parm);\
  BITBLK64_16(ip, 4, op, parm);\
  BITBLK64_16(ip, 5, op, parm);\
  BITBLK64_16(ip, 6, op, parm);\
  BITBLK64_16(ip, 7, op, parm);  IPI(ip); op += 16*4/sizeof(op[0]);\
}

#define BITBLK64_17(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*17+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*17+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 17;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*17+ 0) |= (uint64_t)IPV(ip, i*64+ 2) << 34 | (uint64_t)IPX(ip, i*64+3) << 51;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*17+ 1)  = (uint64_t)IPW(ip, i*64+ 3) >> 13;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*17+ 1) |= (uint64_t)IPV(ip, i*64+ 4) <<  4;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*17+ 1) |= (uint64_t)IPV(ip, i*64+ 5) << 21;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*17+ 1) |= (uint64_t)IPV(ip, i*64+ 6) << 38 | (uint64_t)IPX(ip, i*64+7) << 55;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*17+ 2)  = (uint64_t)IPW(ip, i*64+ 7) >>  9;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*17+ 2) |= (uint64_t)IPV(ip, i*64+ 8) <<  8;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*17+ 2) |= (uint64_t)IPV(ip, i*64+ 9) << 25;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*17+ 2) |= (uint64_t)IPV(ip, i*64+10) << 42 | (uint64_t)IPX(ip, i*64+11) << 59;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*17+ 3)  = (uint64_t)IPW(ip, i*64+11) >>  5;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*17+ 3) |= (uint64_t)IPV(ip, i*64+12) << 12;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*17+ 3) |= (uint64_t)IPV(ip, i*64+13) << 29;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*17+ 3) |= (uint64_t)IPV(ip, i*64+14) << 46 | (uint64_t)IPX(ip, i*64+15) << 63;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*17+ 4)  = (uint64_t)IPW(ip, i*64+15) >>  1;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*17+ 4) |= (uint64_t)IPV(ip, i*64+16) << 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*17+ 4) |= (uint64_t)IPV(ip, i*64+17) << 33 | (uint64_t)IPX(ip, i*64+18) << 50;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*17+ 5)  = (uint64_t)IPW(ip, i*64+18) >> 14;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*17+ 5) |= (uint64_t)IPV(ip, i*64+19) <<  3;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*17+ 5) |= (uint64_t)IPV(ip, i*64+20) << 20;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*17+ 5) |= (uint64_t)IPV(ip, i*64+21) << 37 | (uint64_t)IPX(ip, i*64+22) << 54;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*17+ 6)  = (uint64_t)IPW(ip, i*64+22) >> 10;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*17+ 6) |= (uint64_t)IPV(ip, i*64+23) <<  7;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*17+ 6) |= (uint64_t)IPV(ip, i*64+24) << 24;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*17+ 6) |= (uint64_t)IPV(ip, i*64+25) << 41 | (uint64_t)IPX(ip, i*64+26) << 58;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*17+ 7)  = (uint64_t)IPW(ip, i*64+26) >>  6;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*17+ 7) |= (uint64_t)IPV(ip, i*64+27) << 11;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*17+ 7) |= (uint64_t)IPV(ip, i*64+28) << 28;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*17+ 7) |= (uint64_t)IPV(ip, i*64+29) << 45 | (uint64_t)IPX(ip, i*64+30) << 62;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*17+ 8)  = (uint64_t)IPW(ip, i*64+30) >>  2;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*17+ 8) |= (uint64_t)IPV(ip, i*64+31) << 15;\
}

#define BITPACK64_17(ip,  op, parm) { \
  BITBLK64_17(ip, 0, op, parm);  IPI(ip); op += 17*4/sizeof(op[0]);\
}

#define BITBLK64_18(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*9+ 0)  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*32+ 1) << 18;\
  IP9(ip, i*32+ 2, parm); *((uint64_t *)op+i*9+ 0) |= (uint64_t)IPV(ip, i*32+ 2) << 36 | (uint64_t)IPX(ip, i*32+3) << 54;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*9+ 1)  = (uint64_t)IPW(ip, i*32+ 3) >> 10;\
  IP9(ip, i*32+ 4, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*32+ 4) <<  8;\
  IP9(ip, i*32+ 5, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*32+ 5) << 26;\
  IP9(ip, i*32+ 6, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*32+ 6) << 44 | (uint64_t)IPX(ip, i*32+7) << 62;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*9+ 2)  = (uint64_t)IPW(ip, i*32+ 7) >>  2;\
  IP9(ip, i*32+ 8, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*32+ 8) << 16;\
  IP9(ip, i*32+ 9, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*32+ 9) << 34 | (uint64_t)IPX(ip, i*32+10) << 52;\
  IP64(ip, i*32+10, parm); *((uint64_t *)op+i*9+ 3)  = (uint64_t)IPW(ip, i*32+10) >> 12;\
  IP9(ip, i*32+11, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*32+11) <<  6;\
  IP9(ip, i*32+12, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*32+12) << 24;\
  IP9(ip, i*32+13, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*32+13) << 42 | (uint64_t)IPX(ip, i*32+14) << 60;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*9+ 4)  = (uint64_t)IPW(ip, i*32+14) >>  4;\
  IP9(ip, i*32+15, parm); *((uint64_t *)op+i*9+ 4) |= (uint64_t)IPV(ip, i*32+15) << 14;\
  IP9(ip, i*32+16, parm); *((uint64_t *)op+i*9+ 4) |= (uint64_t)IPV(ip, i*32+16) << 32 | (uint64_t)IPX(ip, i*32+17) << 50;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*9+ 5)  = (uint64_t)IPW(ip, i*32+17) >> 14;\
  IP9(ip, i*32+18, parm); *((uint64_t *)op+i*9+ 5) |= (uint64_t)IPV(ip, i*32+18) <<  4;\
  IP9(ip, i*32+19, parm); *((uint64_t *)op+i*9+ 5) |= (uint64_t)IPV(ip, i*32+19) << 22;\
  IP9(ip, i*32+20, parm); *((uint64_t *)op+i*9+ 5) |= (uint64_t)IPV(ip, i*32+20) << 40 | (uint64_t)IPX(ip, i*32+21) << 58;\
  IP64(ip, i*32+21, parm); *((uint64_t *)op+i*9+ 6)  = (uint64_t)IPW(ip, i*32+21) >>  6;\
  IP9(ip, i*32+22, parm); *((uint64_t *)op+i*9+ 6) |= (uint64_t)IPV(ip, i*32+22) << 12;\
  IP9(ip, i*32+23, parm); *((uint64_t *)op+i*9+ 6) |= (uint64_t)IPV(ip, i*32+23) << 30 | (uint64_t)IPX(ip, i*32+24) << 48;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*9+ 7)  = (uint64_t)IPW(ip, i*32+24) >> 16;\
  IP9(ip, i*32+25, parm); *((uint64_t *)op+i*9+ 7) |= (uint64_t)IPV(ip, i*32+25) <<  2;\
  IP9(ip, i*32+26, parm); *((uint64_t *)op+i*9+ 7) |= (uint64_t)IPV(ip, i*32+26) << 20;\
  IP9(ip, i*32+27, parm); *((uint64_t *)op+i*9+ 7) |= (uint64_t)IPV(ip, i*32+27) << 38 | (uint64_t)IPX(ip, i*32+28) << 56;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*9+ 8)  = (uint64_t)IPW(ip, i*32+28) >>  8;\
  IP9(ip, i*32+29, parm); *((uint64_t *)op+i*9+ 8) |= (uint64_t)IPV(ip, i*32+29) << 10;\
  IP9(ip, i*32+30, parm); *((uint64_t *)op+i*9+ 8) |= (uint64_t)IPV(ip, i*32+30) << 28;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*9+ 8) |= (uint64_t)IPV(ip, i*32+31) << 46;\
}

#define BITPACK64_18(ip,  op, parm) { \
  BITBLK64_18(ip, 0, op, parm);  IPI(ip); op += 18*4/sizeof(op[0]);\
}

#define BITBLK64_19(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*19+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*19+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 19;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*19+ 0) |= (uint64_t)IPV(ip, i*64+ 2) << 38 | (uint64_t)IPX(ip, i*64+3) << 57;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*19+ 1)  = (uint64_t)IPW(ip, i*64+ 3) >>  7;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*19+ 1) |= (uint64_t)IPV(ip, i*64+ 4) << 12;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*19+ 1) |= (uint64_t)IPV(ip, i*64+ 5) << 31 | (uint64_t)IPX(ip, i*64+6) << 50;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*19+ 2)  = (uint64_t)IPW(ip, i*64+ 6) >> 14;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*19+ 2) |= (uint64_t)IPV(ip, i*64+ 7) <<  5;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*19+ 2) |= (uint64_t)IPV(ip, i*64+ 8) << 24;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*19+ 2) |= (uint64_t)IPV(ip, i*64+ 9) << 43 | (uint64_t)IPX(ip, i*64+10) << 62;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*19+ 3)  = (uint64_t)IPW(ip, i*64+10) >>  2;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*19+ 3) |= (uint64_t)IPV(ip, i*64+11) << 17;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*19+ 3) |= (uint64_t)IPV(ip, i*64+12) << 36 | (uint64_t)IPX(ip, i*64+13) << 55;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*19+ 4)  = (uint64_t)IPW(ip, i*64+13) >>  9;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*19+ 4) |= (uint64_t)IPV(ip, i*64+14) << 10;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*19+ 4) |= (uint64_t)IPV(ip, i*64+15) << 29 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*19+ 5)  = (uint64_t)IPW(ip, i*64+16) >> 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*19+ 5) |= (uint64_t)IPV(ip, i*64+17) <<  3;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*19+ 5) |= (uint64_t)IPV(ip, i*64+18) << 22;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*19+ 5) |= (uint64_t)IPV(ip, i*64+19) << 41 | (uint64_t)IPX(ip, i*64+20) << 60;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*19+ 6)  = (uint64_t)IPW(ip, i*64+20) >>  4;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*19+ 6) |= (uint64_t)IPV(ip, i*64+21) << 15;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*19+ 6) |= (uint64_t)IPV(ip, i*64+22) << 34 | (uint64_t)IPX(ip, i*64+23) << 53;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*19+ 7)  = (uint64_t)IPW(ip, i*64+23) >> 11;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*19+ 7) |= (uint64_t)IPV(ip, i*64+24) <<  8;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*19+ 7) |= (uint64_t)IPV(ip, i*64+25) << 27 | (uint64_t)IPX(ip, i*64+26) << 46;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*19+ 8)  = (uint64_t)IPW(ip, i*64+26) >> 18;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*19+ 8) |= (uint64_t)IPV(ip, i*64+27) <<  1;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*19+ 8) |= (uint64_t)IPV(ip, i*64+28) << 20;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*19+ 8) |= (uint64_t)IPV(ip, i*64+29) << 39 | (uint64_t)IPX(ip, i*64+30) << 58;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*19+ 9)  = (uint64_t)IPW(ip, i*64+30) >>  6;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*19+ 9) |= (uint64_t)IPV(ip, i*64+31) << 13;\
}

#define BITPACK64_19(ip,  op, parm) { \
  BITBLK64_19(ip, 0, op, parm);  IPI(ip); op += 19*4/sizeof(op[0]);\
}

#define BITBLK64_20(ip, i, op, parm) { ;\
  IP9(ip, i*16+ 0, parm); *((uint64_t *)op+i*5+ 0)  = (uint64_t)IPV(ip, i*16+ 0)      ;\
  IP9(ip, i*16+ 1, parm); *((uint64_t *)op+i*5+ 0) |= (uint64_t)IPV(ip, i*16+ 1) << 20;\
  IP9(ip, i*16+ 2, parm); *((uint64_t *)op+i*5+ 0) |= (uint64_t)IPV(ip, i*16+ 2) << 40 | (uint64_t)IPX(ip, i*16+3) << 60;\
  IP64(ip, i*16+ 3, parm); *((uint64_t *)op+i*5+ 1)  = (uint64_t)IPW(ip, i*16+ 3) >>  4;\
  IP9(ip, i*16+ 4, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*16+ 4) << 16;\
  IP9(ip, i*16+ 5, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*16+ 5) << 36 | (uint64_t)IPX(ip, i*16+6) << 56;\
  IP64(ip, i*16+ 6, parm); *((uint64_t *)op+i*5+ 2)  = (uint64_t)IPW(ip, i*16+ 6) >>  8;\
  IP9(ip, i*16+ 7, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*16+ 7) << 12;\
  IP9(ip, i*16+ 8, parm); *((uint64_t *)op+i*5+ 2) |= (uint64_t)IPV(ip, i*16+ 8) << 32 | (uint64_t)IPX(ip, i*16+9) << 52;\
  IP64(ip, i*16+ 9, parm); *((uint64_t *)op+i*5+ 3)  = (uint64_t)IPW(ip, i*16+ 9) >> 12;\
  IP9(ip, i*16+10, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*16+10) <<  8;\
  IP9(ip, i*16+11, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*16+11) << 28 | (uint64_t)IPX(ip, i*16+12) << 48;\
  IP64(ip, i*16+12, parm); *((uint64_t *)op+i*5+ 4)  = (uint64_t)IPW(ip, i*16+12) >> 16;\
  IP9(ip, i*16+13, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*16+13) <<  4;\
  IP9(ip, i*16+14, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*16+14) << 24;\
  IP9(ip, i*16+15, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*16+15) << 44;\
}

#define BITPACK64_20(ip,  op, parm) { \
  BITBLK64_20(ip, 0, op, parm);\
  BITBLK64_20(ip, 1, op, parm);  IPI(ip); op += 20*4/sizeof(op[0]);\
}

#define BITBLK64_21(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*21+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*21+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 21;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*21+ 0) |= (uint64_t)IPV(ip, i*64+ 2) << 42 | (uint64_t)IPX(ip, i*64+3) << 63;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*21+ 1)  = (uint64_t)IPW(ip, i*64+ 3) >>  1;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*21+ 1) |= (uint64_t)IPV(ip, i*64+ 4) << 20;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*21+ 1) |= (uint64_t)IPV(ip, i*64+ 5) << 41 | (uint64_t)IPX(ip, i*64+6) << 62;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*21+ 2)  = (uint64_t)IPW(ip, i*64+ 6) >>  2;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*21+ 2) |= (uint64_t)IPV(ip, i*64+ 7) << 19;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*21+ 2) |= (uint64_t)IPV(ip, i*64+ 8) << 40 | (uint64_t)IPX(ip, i*64+9) << 61;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*21+ 3)  = (uint64_t)IPW(ip, i*64+ 9) >>  3;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*21+ 3) |= (uint64_t)IPV(ip, i*64+10) << 18;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*21+ 3) |= (uint64_t)IPV(ip, i*64+11) << 39 | (uint64_t)IPX(ip, i*64+12) << 60;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*21+ 4)  = (uint64_t)IPW(ip, i*64+12) >>  4;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*21+ 4) |= (uint64_t)IPV(ip, i*64+13) << 17;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*21+ 4) |= (uint64_t)IPV(ip, i*64+14) << 38 | (uint64_t)IPX(ip, i*64+15) << 59;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*21+ 5)  = (uint64_t)IPW(ip, i*64+15) >>  5;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*21+ 5) |= (uint64_t)IPV(ip, i*64+16) << 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*21+ 5) |= (uint64_t)IPV(ip, i*64+17) << 37 | (uint64_t)IPX(ip, i*64+18) << 58;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*21+ 6)  = (uint64_t)IPW(ip, i*64+18) >>  6;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*21+ 6) |= (uint64_t)IPV(ip, i*64+19) << 15;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*21+ 6) |= (uint64_t)IPV(ip, i*64+20) << 36 | (uint64_t)IPX(ip, i*64+21) << 57;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*21+ 7)  = (uint64_t)IPW(ip, i*64+21) >>  7;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*21+ 7) |= (uint64_t)IPV(ip, i*64+22) << 14;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*21+ 7) |= (uint64_t)IPV(ip, i*64+23) << 35 | (uint64_t)IPX(ip, i*64+24) << 56;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*21+ 8)  = (uint64_t)IPW(ip, i*64+24) >>  8;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*21+ 8) |= (uint64_t)IPV(ip, i*64+25) << 13;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*21+ 8) |= (uint64_t)IPV(ip, i*64+26) << 34 | (uint64_t)IPX(ip, i*64+27) << 55;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*21+ 9)  = (uint64_t)IPW(ip, i*64+27) >>  9;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*21+ 9) |= (uint64_t)IPV(ip, i*64+28) << 12;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*21+ 9) |= (uint64_t)IPV(ip, i*64+29) << 33 | (uint64_t)IPX(ip, i*64+30) << 54;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*21+10)  = (uint64_t)IPW(ip, i*64+30) >> 10;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*21+10) |= (uint64_t)IPV(ip, i*64+31) << 11;\
}

#define BITPACK64_21(ip,  op, parm) { \
  BITBLK64_21(ip, 0, op, parm);  IPI(ip); op += 21*4/sizeof(op[0]);\
}

#define BITBLK64_22(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*11+ 0)  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); *((uint64_t *)op+i*11+ 0) |= (uint64_t)IPV(ip, i*32+ 1) << 22 | (uint64_t)IPX(ip, i*32+2) << 44;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*11+ 1)  = (uint64_t)IPW(ip, i*32+ 2) >> 20;\
  IP9(ip, i*32+ 3, parm); *((uint64_t *)op+i*11+ 1) |= (uint64_t)IPV(ip, i*32+ 3) <<  2;\
  IP9(ip, i*32+ 4, parm); *((uint64_t *)op+i*11+ 1) |= (uint64_t)IPV(ip, i*32+ 4) << 24 | (uint64_t)IPX(ip, i*32+5) << 46;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*11+ 2)  = (uint64_t)IPW(ip, i*32+ 5) >> 18;\
  IP9(ip, i*32+ 6, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*32+ 6) <<  4;\
  IP9(ip, i*32+ 7, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*32+ 7) << 26 | (uint64_t)IPX(ip, i*32+8) << 48;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*11+ 3)  = (uint64_t)IPW(ip, i*32+ 8) >> 16;\
  IP9(ip, i*32+ 9, parm); *((uint64_t *)op+i*11+ 3) |= (uint64_t)IPV(ip, i*32+ 9) <<  6;\
  IP9(ip, i*32+10, parm); *((uint64_t *)op+i*11+ 3) |= (uint64_t)IPV(ip, i*32+10) << 28 | (uint64_t)IPX(ip, i*32+11) << 50;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*11+ 4)  = (uint64_t)IPW(ip, i*32+11) >> 14;\
  IP9(ip, i*32+12, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*32+12) <<  8;\
  IP9(ip, i*32+13, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*32+13) << 30 | (uint64_t)IPX(ip, i*32+14) << 52;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*11+ 5)  = (uint64_t)IPW(ip, i*32+14) >> 12;\
  IP9(ip, i*32+15, parm); *((uint64_t *)op+i*11+ 5) |= (uint64_t)IPV(ip, i*32+15) << 10;\
  IP9(ip, i*32+16, parm); *((uint64_t *)op+i*11+ 5) |= (uint64_t)IPV(ip, i*32+16) << 32 | (uint64_t)IPX(ip, i*32+17) << 54;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*11+ 6)  = (uint64_t)IPW(ip, i*32+17) >> 10;\
  IP9(ip, i*32+18, parm); *((uint64_t *)op+i*11+ 6) |= (uint64_t)IPV(ip, i*32+18) << 12;\
  IP9(ip, i*32+19, parm); *((uint64_t *)op+i*11+ 6) |= (uint64_t)IPV(ip, i*32+19) << 34 | (uint64_t)IPX(ip, i*32+20) << 56;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*11+ 7)  = (uint64_t)IPW(ip, i*32+20) >>  8;\
  IP9(ip, i*32+21, parm); *((uint64_t *)op+i*11+ 7) |= (uint64_t)IPV(ip, i*32+21) << 14;\
  IP9(ip, i*32+22, parm); *((uint64_t *)op+i*11+ 7) |= (uint64_t)IPV(ip, i*32+22) << 36 | (uint64_t)IPX(ip, i*32+23) << 58;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*11+ 8)  = (uint64_t)IPW(ip, i*32+23) >>  6;\
  IP9(ip, i*32+24, parm); *((uint64_t *)op+i*11+ 8) |= (uint64_t)IPV(ip, i*32+24) << 16;\
  IP9(ip, i*32+25, parm); *((uint64_t *)op+i*11+ 8) |= (uint64_t)IPV(ip, i*32+25) << 38 | (uint64_t)IPX(ip, i*32+26) << 60;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*11+ 9)  = (uint64_t)IPW(ip, i*32+26) >>  4;\
  IP9(ip, i*32+27, parm); *((uint64_t *)op+i*11+ 9) |= (uint64_t)IPV(ip, i*32+27) << 18;\
  IP9(ip, i*32+28, parm); *((uint64_t *)op+i*11+ 9) |= (uint64_t)IPV(ip, i*32+28) << 40 | (uint64_t)IPX(ip, i*32+29) << 62;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*11+10)  = (uint64_t)IPW(ip, i*32+29) >>  2;\
  IP9(ip, i*32+30, parm); *((uint64_t *)op+i*11+10) |= (uint64_t)IPV(ip, i*32+30) << 20;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*11+10) |= (uint64_t)IPV(ip, i*32+31) << 42;\
}

#define BITPACK64_22(ip,  op, parm) { \
  BITBLK64_22(ip, 0, op, parm);  IPI(ip); op += 22*4/sizeof(op[0]);\
}

#define BITBLK64_23(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*23+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*23+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 23 | (uint64_t)IPX(ip, i*64+2) << 46;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*23+ 1)  = (uint64_t)IPW(ip, i*64+ 2) >> 18;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*23+ 1) |= (uint64_t)IPV(ip, i*64+ 3) <<  5;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*23+ 1) |= (uint64_t)IPV(ip, i*64+ 4) << 28 | (uint64_t)IPX(ip, i*64+5) << 51;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*23+ 2)  = (uint64_t)IPW(ip, i*64+ 5) >> 13;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*23+ 2) |= (uint64_t)IPV(ip, i*64+ 6) << 10;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*23+ 2) |= (uint64_t)IPV(ip, i*64+ 7) << 33 | (uint64_t)IPX(ip, i*64+8) << 56;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*23+ 3)  = (uint64_t)IPW(ip, i*64+ 8) >>  8;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*23+ 3) |= (uint64_t)IPV(ip, i*64+ 9) << 15;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*23+ 3) |= (uint64_t)IPV(ip, i*64+10) << 38 | (uint64_t)IPX(ip, i*64+11) << 61;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*23+ 4)  = (uint64_t)IPW(ip, i*64+11) >>  3;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*23+ 4) |= (uint64_t)IPV(ip, i*64+12) << 20 | (uint64_t)IPX(ip, i*64+13) << 43;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*23+ 5)  = (uint64_t)IPW(ip, i*64+13) >> 21;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*23+ 5) |= (uint64_t)IPV(ip, i*64+14) <<  2;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*23+ 5) |= (uint64_t)IPV(ip, i*64+15) << 25 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*23+ 6)  = (uint64_t)IPW(ip, i*64+16) >> 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*23+ 6) |= (uint64_t)IPV(ip, i*64+17) <<  7;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*23+ 6) |= (uint64_t)IPV(ip, i*64+18) << 30 | (uint64_t)IPX(ip, i*64+19) << 53;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*23+ 7)  = (uint64_t)IPW(ip, i*64+19) >> 11;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*23+ 7) |= (uint64_t)IPV(ip, i*64+20) << 12;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*23+ 7) |= (uint64_t)IPV(ip, i*64+21) << 35 | (uint64_t)IPX(ip, i*64+22) << 58;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*23+ 8)  = (uint64_t)IPW(ip, i*64+22) >>  6;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*23+ 8) |= (uint64_t)IPV(ip, i*64+23) << 17;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*23+ 8) |= (uint64_t)IPV(ip, i*64+24) << 40 | (uint64_t)IPX(ip, i*64+25) << 63;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*23+ 9)  = (uint64_t)IPW(ip, i*64+25) >>  1;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*23+ 9) |= (uint64_t)IPV(ip, i*64+26) << 22 | (uint64_t)IPX(ip, i*64+27) << 45;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*23+10)  = (uint64_t)IPW(ip, i*64+27) >> 19;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*23+10) |= (uint64_t)IPV(ip, i*64+28) <<  4;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*23+10) |= (uint64_t)IPV(ip, i*64+29) << 27 | (uint64_t)IPX(ip, i*64+30) << 50;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*23+11)  = (uint64_t)IPW(ip, i*64+30) >> 14;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*23+11) |= (uint64_t)IPV(ip, i*64+31) <<  9;\
}

#define BITPACK64_23(ip,  op, parm) { \
  BITBLK64_23(ip, 0, op, parm);  IPI(ip); op += 23*4/sizeof(op[0]);\
}

#define BITBLK64_24(ip, i, op, parm) { ;\
  IP9(ip, i*8+ 0, parm); *((uint64_t *)op+i*3+ 0)  = (uint64_t)IPV(ip, i*8+ 0)      ;\
  IP9(ip, i*8+ 1, parm); *((uint64_t *)op+i*3+ 0) |= (uint64_t)IPV(ip, i*8+ 1) << 24 | (uint64_t)IPX(ip, i*8+2) << 48;\
  IP64(ip, i*8+ 2, parm); *((uint64_t *)op+i*3+ 1)  = (uint64_t)IPW(ip, i*8+ 2) >> 16;\
  IP9(ip, i*8+ 3, parm); *((uint64_t *)op+i*3+ 1) |= (uint64_t)IPV(ip, i*8+ 3) <<  8;\
  IP9(ip, i*8+ 4, parm); *((uint64_t *)op+i*3+ 1) |= (uint64_t)IPV(ip, i*8+ 4) << 32 | (uint64_t)IPX(ip, i*8+5) << 56;\
  IP64(ip, i*8+ 5, parm); *((uint64_t *)op+i*3+ 2)  = (uint64_t)IPW(ip, i*8+ 5) >>  8;\
  IP9(ip, i*8+ 6, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*8+ 6) << 16;\
  IP9(ip, i*8+ 7, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*8+ 7) << 40;\
}

#define BITPACK64_24(ip,  op, parm) { \
  BITBLK64_24(ip, 0, op, parm);\
  BITBLK64_24(ip, 1, op, parm);\
  BITBLK64_24(ip, 2, op, parm);\
  BITBLK64_24(ip, 3, op, parm);  IPI(ip); op += 24*4/sizeof(op[0]);\
}

#define BITBLK64_25(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*25+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*25+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 25 | (uint64_t)IPX(ip, i*64+2) << 50;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*25+ 1)  = (uint64_t)IPW(ip, i*64+ 2) >> 14;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*25+ 1) |= (uint64_t)IPV(ip, i*64+ 3) << 11;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*25+ 1) |= (uint64_t)IPV(ip, i*64+ 4) << 36 | (uint64_t)IPX(ip, i*64+5) << 61;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*25+ 2)  = (uint64_t)IPW(ip, i*64+ 5) >>  3;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*25+ 2) |= (uint64_t)IPV(ip, i*64+ 6) << 22 | (uint64_t)IPX(ip, i*64+7) << 47;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*25+ 3)  = (uint64_t)IPW(ip, i*64+ 7) >> 17;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*25+ 3) |= (uint64_t)IPV(ip, i*64+ 8) <<  8;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*25+ 3) |= (uint64_t)IPV(ip, i*64+ 9) << 33 | (uint64_t)IPX(ip, i*64+10) << 58;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*25+ 4)  = (uint64_t)IPW(ip, i*64+10) >>  6;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*25+ 4) |= (uint64_t)IPV(ip, i*64+11) << 19 | (uint64_t)IPX(ip, i*64+12) << 44;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*25+ 5)  = (uint64_t)IPW(ip, i*64+12) >> 20;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*25+ 5) |= (uint64_t)IPV(ip, i*64+13) <<  5;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*25+ 5) |= (uint64_t)IPV(ip, i*64+14) << 30 | (uint64_t)IPX(ip, i*64+15) << 55;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*25+ 6)  = (uint64_t)IPW(ip, i*64+15) >>  9;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*25+ 6) |= (uint64_t)IPV(ip, i*64+16) << 16 | (uint64_t)IPX(ip, i*64+17) << 41;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*25+ 7)  = (uint64_t)IPW(ip, i*64+17) >> 23;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*25+ 7) |= (uint64_t)IPV(ip, i*64+18) <<  2;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*25+ 7) |= (uint64_t)IPV(ip, i*64+19) << 27 | (uint64_t)IPX(ip, i*64+20) << 52;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*25+ 8)  = (uint64_t)IPW(ip, i*64+20) >> 12;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*25+ 8) |= (uint64_t)IPV(ip, i*64+21) << 13;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*25+ 8) |= (uint64_t)IPV(ip, i*64+22) << 38 | (uint64_t)IPX(ip, i*64+23) << 63;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*25+ 9)  = (uint64_t)IPW(ip, i*64+23) >>  1;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*25+ 9) |= (uint64_t)IPV(ip, i*64+24) << 24 | (uint64_t)IPX(ip, i*64+25) << 49;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*25+10)  = (uint64_t)IPW(ip, i*64+25) >> 15;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*25+10) |= (uint64_t)IPV(ip, i*64+26) << 10;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*25+10) |= (uint64_t)IPV(ip, i*64+27) << 35 | (uint64_t)IPX(ip, i*64+28) << 60;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*25+11)  = (uint64_t)IPW(ip, i*64+28) >>  4;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*25+11) |= (uint64_t)IPV(ip, i*64+29) << 21 | (uint64_t)IPX(ip, i*64+30) << 46;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*25+12)  = (uint64_t)IPW(ip, i*64+30) >> 18;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*25+12) |= (uint64_t)IPV(ip, i*64+31) <<  7;\
}

#define BITPACK64_25(ip,  op, parm) { \
  BITBLK64_25(ip, 0, op, parm);  IPI(ip); op += 25*4/sizeof(op[0]);\
}

#define BITBLK64_26(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*13+ 0)  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); *((uint64_t *)op+i*13+ 0) |= (uint64_t)IPV(ip, i*32+ 1) << 26 | (uint64_t)IPX(ip, i*32+2) << 52;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*13+ 1)  = (uint64_t)IPW(ip, i*32+ 2) >> 12;\
  IP9(ip, i*32+ 3, parm); *((uint64_t *)op+i*13+ 1) |= (uint64_t)IPV(ip, i*32+ 3) << 14 | (uint64_t)IPX(ip, i*32+4) << 40;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*13+ 2)  = (uint64_t)IPW(ip, i*32+ 4) >> 24;\
  IP9(ip, i*32+ 5, parm); *((uint64_t *)op+i*13+ 2) |= (uint64_t)IPV(ip, i*32+ 5) <<  2;\
  IP9(ip, i*32+ 6, parm); *((uint64_t *)op+i*13+ 2) |= (uint64_t)IPV(ip, i*32+ 6) << 28 | (uint64_t)IPX(ip, i*32+7) << 54;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*13+ 3)  = (uint64_t)IPW(ip, i*32+ 7) >> 10;\
  IP9(ip, i*32+ 8, parm); *((uint64_t *)op+i*13+ 3) |= (uint64_t)IPV(ip, i*32+ 8) << 16 | (uint64_t)IPX(ip, i*32+9) << 42;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*13+ 4)  = (uint64_t)IPW(ip, i*32+ 9) >> 22;\
  IP9(ip, i*32+10, parm); *((uint64_t *)op+i*13+ 4) |= (uint64_t)IPV(ip, i*32+10) <<  4;\
  IP9(ip, i*32+11, parm); *((uint64_t *)op+i*13+ 4) |= (uint64_t)IPV(ip, i*32+11) << 30 | (uint64_t)IPX(ip, i*32+12) << 56;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*13+ 5)  = (uint64_t)IPW(ip, i*32+12) >>  8;\
  IP9(ip, i*32+13, parm); *((uint64_t *)op+i*13+ 5) |= (uint64_t)IPV(ip, i*32+13) << 18 | (uint64_t)IPX(ip, i*32+14) << 44;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*13+ 6)  = (uint64_t)IPW(ip, i*32+14) >> 20;\
  IP9(ip, i*32+15, parm); *((uint64_t *)op+i*13+ 6) |= (uint64_t)IPV(ip, i*32+15) <<  6;\
  IP9(ip, i*32+16, parm); *((uint64_t *)op+i*13+ 6) |= (uint64_t)IPV(ip, i*32+16) << 32 | (uint64_t)IPX(ip, i*32+17) << 58;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*13+ 7)  = (uint64_t)IPW(ip, i*32+17) >>  6;\
  IP9(ip, i*32+18, parm); *((uint64_t *)op+i*13+ 7) |= (uint64_t)IPV(ip, i*32+18) << 20 | (uint64_t)IPX(ip, i*32+19) << 46;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*13+ 8)  = (uint64_t)IPW(ip, i*32+19) >> 18;\
  IP9(ip, i*32+20, parm); *((uint64_t *)op+i*13+ 8) |= (uint64_t)IPV(ip, i*32+20) <<  8;\
  IP9(ip, i*32+21, parm); *((uint64_t *)op+i*13+ 8) |= (uint64_t)IPV(ip, i*32+21) << 34 | (uint64_t)IPX(ip, i*32+22) << 60;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*13+ 9)  = (uint64_t)IPW(ip, i*32+22) >>  4;\
  IP9(ip, i*32+23, parm); *((uint64_t *)op+i*13+ 9) |= (uint64_t)IPV(ip, i*32+23) << 22 | (uint64_t)IPX(ip, i*32+24) << 48;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*13+10)  = (uint64_t)IPW(ip, i*32+24) >> 16;\
  IP9(ip, i*32+25, parm); *((uint64_t *)op+i*13+10) |= (uint64_t)IPV(ip, i*32+25) << 10;\
  IP9(ip, i*32+26, parm); *((uint64_t *)op+i*13+10) |= (uint64_t)IPV(ip, i*32+26) << 36 | (uint64_t)IPX(ip, i*32+27) << 62;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*13+11)  = (uint64_t)IPW(ip, i*32+27) >>  2;\
  IP9(ip, i*32+28, parm); *((uint64_t *)op+i*13+11) |= (uint64_t)IPV(ip, i*32+28) << 24 | (uint64_t)IPX(ip, i*32+29) << 50;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*13+12)  = (uint64_t)IPW(ip, i*32+29) >> 14;\
  IP9(ip, i*32+30, parm); *((uint64_t *)op+i*13+12) |= (uint64_t)IPV(ip, i*32+30) << 12;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*13+12) |= (uint64_t)IPV(ip, i*32+31) << 38;\
}

#define BITPACK64_26(ip,  op, parm) { \
  BITBLK64_26(ip, 0, op, parm);  IPI(ip); op += 26*4/sizeof(op[0]);\
}

#define BITBLK64_27(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*27+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*27+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 27 | (uint64_t)IPX(ip, i*64+2) << 54;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*27+ 1)  = (uint64_t)IPW(ip, i*64+ 2) >> 10;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*27+ 1) |= (uint64_t)IPV(ip, i*64+ 3) << 17 | (uint64_t)IPX(ip, i*64+4) << 44;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*27+ 2)  = (uint64_t)IPW(ip, i*64+ 4) >> 20;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*27+ 2) |= (uint64_t)IPV(ip, i*64+ 5) <<  7;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*27+ 2) |= (uint64_t)IPV(ip, i*64+ 6) << 34 | (uint64_t)IPX(ip, i*64+7) << 61;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*27+ 3)  = (uint64_t)IPW(ip, i*64+ 7) >>  3;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*27+ 3) |= (uint64_t)IPV(ip, i*64+ 8) << 24 | (uint64_t)IPX(ip, i*64+9) << 51;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*27+ 4)  = (uint64_t)IPW(ip, i*64+ 9) >> 13;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*27+ 4) |= (uint64_t)IPV(ip, i*64+10) << 14 | (uint64_t)IPX(ip, i*64+11) << 41;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*27+ 5)  = (uint64_t)IPW(ip, i*64+11) >> 23;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*27+ 5) |= (uint64_t)IPV(ip, i*64+12) <<  4;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*27+ 5) |= (uint64_t)IPV(ip, i*64+13) << 31 | (uint64_t)IPX(ip, i*64+14) << 58;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*27+ 6)  = (uint64_t)IPW(ip, i*64+14) >>  6;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*27+ 6) |= (uint64_t)IPV(ip, i*64+15) << 21 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*27+ 7)  = (uint64_t)IPW(ip, i*64+16) >> 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*27+ 7) |= (uint64_t)IPV(ip, i*64+17) << 11 | (uint64_t)IPX(ip, i*64+18) << 38;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*27+ 8)  = (uint64_t)IPW(ip, i*64+18) >> 26;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*27+ 8) |= (uint64_t)IPV(ip, i*64+19) <<  1;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*27+ 8) |= (uint64_t)IPV(ip, i*64+20) << 28 | (uint64_t)IPX(ip, i*64+21) << 55;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*27+ 9)  = (uint64_t)IPW(ip, i*64+21) >>  9;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*27+ 9) |= (uint64_t)IPV(ip, i*64+22) << 18 | (uint64_t)IPX(ip, i*64+23) << 45;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*27+10)  = (uint64_t)IPW(ip, i*64+23) >> 19;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*27+10) |= (uint64_t)IPV(ip, i*64+24) <<  8;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*27+10) |= (uint64_t)IPV(ip, i*64+25) << 35 | (uint64_t)IPX(ip, i*64+26) << 62;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*27+11)  = (uint64_t)IPW(ip, i*64+26) >>  2;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*27+11) |= (uint64_t)IPV(ip, i*64+27) << 25 | (uint64_t)IPX(ip, i*64+28) << 52;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*27+12)  = (uint64_t)IPW(ip, i*64+28) >> 12;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*27+12) |= (uint64_t)IPV(ip, i*64+29) << 15 | (uint64_t)IPX(ip, i*64+30) << 42;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*27+13)  = (uint64_t)IPW(ip, i*64+30) >> 22;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*27+13) |= (uint64_t)IPV(ip, i*64+31) <<  5;\
}

#define BITPACK64_27(ip,  op, parm) { \
  BITBLK64_27(ip, 0, op, parm);  IPI(ip); op += 27*4/sizeof(op[0]);\
}

#define BITBLK64_28(ip, i, op, parm) { ;\
  IP9(ip, i*16+ 0, parm); *((uint64_t *)op+i*7+ 0)  = (uint64_t)IPV(ip, i*16+ 0)      ;\
  IP9(ip, i*16+ 1, parm); *((uint64_t *)op+i*7+ 0) |= (uint64_t)IPV(ip, i*16+ 1) << 28 | (uint64_t)IPX(ip, i*16+2) << 56;\
  IP64(ip, i*16+ 2, parm); *((uint64_t *)op+i*7+ 1)  = (uint64_t)IPW(ip, i*16+ 2) >>  8;\
  IP9(ip, i*16+ 3, parm); *((uint64_t *)op+i*7+ 1) |= (uint64_t)IPV(ip, i*16+ 3) << 20 | (uint64_t)IPX(ip, i*16+4) << 48;\
  IP64(ip, i*16+ 4, parm); *((uint64_t *)op+i*7+ 2)  = (uint64_t)IPW(ip, i*16+ 4) >> 16;\
  IP9(ip, i*16+ 5, parm); *((uint64_t *)op+i*7+ 2) |= (uint64_t)IPV(ip, i*16+ 5) << 12 | (uint64_t)IPX(ip, i*16+6) << 40;\
  IP64(ip, i*16+ 6, parm); *((uint64_t *)op+i*7+ 3)  = (uint64_t)IPW(ip, i*16+ 6) >> 24;\
  IP9(ip, i*16+ 7, parm); *((uint64_t *)op+i*7+ 3) |= (uint64_t)IPV(ip, i*16+ 7) <<  4;\
  IP9(ip, i*16+ 8, parm); *((uint64_t *)op+i*7+ 3) |= (uint64_t)IPV(ip, i*16+ 8) << 32 | (uint64_t)IPX(ip, i*16+9) << 60;\
  IP64(ip, i*16+ 9, parm); *((uint64_t *)op+i*7+ 4)  = (uint64_t)IPW(ip, i*16+ 9) >>  4;\
  IP9(ip, i*16+10, parm); *((uint64_t *)op+i*7+ 4) |= (uint64_t)IPV(ip, i*16+10) << 24 | (uint64_t)IPX(ip, i*16+11) << 52;\
  IP64(ip, i*16+11, parm); *((uint64_t *)op+i*7+ 5)  = (uint64_t)IPW(ip, i*16+11) >> 12;\
  IP9(ip, i*16+12, parm); *((uint64_t *)op+i*7+ 5) |= (uint64_t)IPV(ip, i*16+12) << 16 | (uint64_t)IPX(ip, i*16+13) << 44;\
  IP64(ip, i*16+13, parm); *((uint64_t *)op+i*7+ 6)  = (uint64_t)IPW(ip, i*16+13) >> 20;\
  IP9(ip, i*16+14, parm); *((uint64_t *)op+i*7+ 6) |= (uint64_t)IPV(ip, i*16+14) <<  8;\
  IP9(ip, i*16+15, parm); *((uint64_t *)op+i*7+ 6) |= (uint64_t)IPV(ip, i*16+15) << 36;\
}

#define BITPACK64_28(ip,  op, parm) { \
  BITBLK64_28(ip, 0, op, parm);\
  BITBLK64_28(ip, 1, op, parm);  IPI(ip); op += 28*4/sizeof(op[0]);\
}

#define BITBLK64_29(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*29+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*29+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 29 | (uint64_t)IPX(ip, i*64+2) << 58;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*29+ 1)  = (uint64_t)IPW(ip, i*64+ 2) >>  6;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*29+ 1) |= (uint64_t)IPV(ip, i*64+ 3) << 23 | (uint64_t)IPX(ip, i*64+4) << 52;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*29+ 2)  = (uint64_t)IPW(ip, i*64+ 4) >> 12;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*29+ 2) |= (uint64_t)IPV(ip, i*64+ 5) << 17 | (uint64_t)IPX(ip, i*64+6) << 46;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*29+ 3)  = (uint64_t)IPW(ip, i*64+ 6) >> 18;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*29+ 3) |= (uint64_t)IPV(ip, i*64+ 7) << 11 | (uint64_t)IPX(ip, i*64+8) << 40;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*29+ 4)  = (uint64_t)IPW(ip, i*64+ 8) >> 24;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*29+ 4) |= (uint64_t)IPV(ip, i*64+ 9) <<  5;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*29+ 4) |= (uint64_t)IPV(ip, i*64+10) << 34 | (uint64_t)IPX(ip, i*64+11) << 63;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*29+ 5)  = (uint64_t)IPW(ip, i*64+11) >>  1;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*29+ 5) |= (uint64_t)IPV(ip, i*64+12) << 28 | (uint64_t)IPX(ip, i*64+13) << 57;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*29+ 6)  = (uint64_t)IPW(ip, i*64+13) >>  7;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*29+ 6) |= (uint64_t)IPV(ip, i*64+14) << 22 | (uint64_t)IPX(ip, i*64+15) << 51;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*29+ 7)  = (uint64_t)IPW(ip, i*64+15) >> 13;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*29+ 7) |= (uint64_t)IPV(ip, i*64+16) << 16 | (uint64_t)IPX(ip, i*64+17) << 45;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*29+ 8)  = (uint64_t)IPW(ip, i*64+17) >> 19;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*29+ 8) |= (uint64_t)IPV(ip, i*64+18) << 10 | (uint64_t)IPX(ip, i*64+19) << 39;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*29+ 9)  = (uint64_t)IPW(ip, i*64+19) >> 25;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*29+ 9) |= (uint64_t)IPV(ip, i*64+20) <<  4;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*29+ 9) |= (uint64_t)IPV(ip, i*64+21) << 33 | (uint64_t)IPX(ip, i*64+22) << 62;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*29+10)  = (uint64_t)IPW(ip, i*64+22) >>  2;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*29+10) |= (uint64_t)IPV(ip, i*64+23) << 27 | (uint64_t)IPX(ip, i*64+24) << 56;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*29+11)  = (uint64_t)IPW(ip, i*64+24) >>  8;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*29+11) |= (uint64_t)IPV(ip, i*64+25) << 21 | (uint64_t)IPX(ip, i*64+26) << 50;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*29+12)  = (uint64_t)IPW(ip, i*64+26) >> 14;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*29+12) |= (uint64_t)IPV(ip, i*64+27) << 15 | (uint64_t)IPX(ip, i*64+28) << 44;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*29+13)  = (uint64_t)IPW(ip, i*64+28) >> 20;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*29+13) |= (uint64_t)IPV(ip, i*64+29) <<  9 | (uint64_t)IPX(ip, i*64+30) << 38;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*29+14)  = (uint64_t)IPW(ip, i*64+30) >> 26;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*29+14) |= (uint64_t)IPV(ip, i*64+31) <<  3;\
}

#define BITPACK64_29(ip,  op, parm) { \
  BITBLK64_29(ip, 0, op, parm);  IPI(ip); op += 29*4/sizeof(op[0]);\
}

#define BITBLK64_30(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*15+ 0)  = (uint64_t)IPV(ip, i*32+ 0)      ;\
  IP9(ip, i*32+ 1, parm); *((uint64_t *)op+i*15+ 0) |= (uint64_t)IPV(ip, i*32+ 1) << 30 | (uint64_t)IPX(ip, i*32+2) << 60;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*15+ 1)  = (uint64_t)IPW(ip, i*32+ 2) >>  4;\
  IP9(ip, i*32+ 3, parm); *((uint64_t *)op+i*15+ 1) |= (uint64_t)IPV(ip, i*32+ 3) << 26 | (uint64_t)IPX(ip, i*32+4) << 56;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*15+ 2)  = (uint64_t)IPW(ip, i*32+ 4) >>  8;\
  IP9(ip, i*32+ 5, parm); *((uint64_t *)op+i*15+ 2) |= (uint64_t)IPV(ip, i*32+ 5) << 22 | (uint64_t)IPX(ip, i*32+6) << 52;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*15+ 3)  = (uint64_t)IPW(ip, i*32+ 6) >> 12;\
  IP9(ip, i*32+ 7, parm); *((uint64_t *)op+i*15+ 3) |= (uint64_t)IPV(ip, i*32+ 7) << 18 | (uint64_t)IPX(ip, i*32+8) << 48;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*15+ 4)  = (uint64_t)IPW(ip, i*32+ 8) >> 16;\
  IP9(ip, i*32+ 9, parm); *((uint64_t *)op+i*15+ 4) |= (uint64_t)IPV(ip, i*32+ 9) << 14 | (uint64_t)IPX(ip, i*32+10) << 44;\
  IP64(ip, i*32+10, parm); *((uint64_t *)op+i*15+ 5)  = (uint64_t)IPW(ip, i*32+10) >> 20;\
  IP9(ip, i*32+11, parm); *((uint64_t *)op+i*15+ 5) |= (uint64_t)IPV(ip, i*32+11) << 10 | (uint64_t)IPX(ip, i*32+12) << 40;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*15+ 6)  = (uint64_t)IPW(ip, i*32+12) >> 24;\
  IP9(ip, i*32+13, parm); *((uint64_t *)op+i*15+ 6) |= (uint64_t)IPV(ip, i*32+13) <<  6 | (uint64_t)IPX(ip, i*32+14) << 36;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*15+ 7)  = (uint64_t)IPW(ip, i*32+14) >> 28;\
  IP9(ip, i*32+15, parm); *((uint64_t *)op+i*15+ 7) |= (uint64_t)IPV(ip, i*32+15) <<  2;\
  IP9(ip, i*32+16, parm); *((uint64_t *)op+i*15+ 7) |= (uint64_t)IPV(ip, i*32+16) << 32 | (uint64_t)IPX(ip, i*32+17) << 62;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*15+ 8)  = (uint64_t)IPW(ip, i*32+17) >>  2;\
  IP9(ip, i*32+18, parm); *((uint64_t *)op+i*15+ 8) |= (uint64_t)IPV(ip, i*32+18) << 28 | (uint64_t)IPX(ip, i*32+19) << 58;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*15+ 9)  = (uint64_t)IPW(ip, i*32+19) >>  6;\
  IP9(ip, i*32+20, parm); *((uint64_t *)op+i*15+ 9) |= (uint64_t)IPV(ip, i*32+20) << 24 | (uint64_t)IPX(ip, i*32+21) << 54;\
  IP64(ip, i*32+21, parm); *((uint64_t *)op+i*15+10)  = (uint64_t)IPW(ip, i*32+21) >> 10;\
  IP9(ip, i*32+22, parm); *((uint64_t *)op+i*15+10) |= (uint64_t)IPV(ip, i*32+22) << 20 | (uint64_t)IPX(ip, i*32+23) << 50;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*15+11)  = (uint64_t)IPW(ip, i*32+23) >> 14;\
  IP9(ip, i*32+24, parm); *((uint64_t *)op+i*15+11) |= (uint64_t)IPV(ip, i*32+24) << 16 | (uint64_t)IPX(ip, i*32+25) << 46;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*15+12)  = (uint64_t)IPW(ip, i*32+25) >> 18;\
  IP9(ip, i*32+26, parm); *((uint64_t *)op+i*15+12) |= (uint64_t)IPV(ip, i*32+26) << 12 | (uint64_t)IPX(ip, i*32+27) << 42;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*15+13)  = (uint64_t)IPW(ip, i*32+27) >> 22;\
  IP9(ip, i*32+28, parm); *((uint64_t *)op+i*15+13) |= (uint64_t)IPV(ip, i*32+28) <<  8 | (uint64_t)IPX(ip, i*32+29) << 38;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*15+14)  = (uint64_t)IPW(ip, i*32+29) >> 26;\
  IP9(ip, i*32+30, parm); *((uint64_t *)op+i*15+14) |= (uint64_t)IPV(ip, i*32+30) <<  4;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*15+14) |= (uint64_t)IPV(ip, i*32+31) << 34;\
}

#define BITPACK64_30(ip,  op, parm) { \
  BITBLK64_30(ip, 0, op, parm);  IPI(ip); op += 30*4/sizeof(op[0]);\
}

#define BITBLK64_31(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*31+ 0)  = (uint64_t)IPV(ip, i*64+ 0)      ;\
  IP9(ip, i*64+ 1, parm); *((uint64_t *)op+i*31+ 0) |= (uint64_t)IPV(ip, i*64+ 1) << 31 | (uint64_t)IPX(ip, i*64+2) << 62;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*31+ 1)  = (uint64_t)IPW(ip, i*64+ 2) >>  2;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*31+ 1) |= (uint64_t)IPV(ip, i*64+ 3) << 29 | (uint64_t)IPX(ip, i*64+4) << 60;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*31+ 2)  = (uint64_t)IPW(ip, i*64+ 4) >>  4;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*31+ 2) |= (uint64_t)IPV(ip, i*64+ 5) << 27 | (uint64_t)IPX(ip, i*64+6) << 58;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*31+ 3)  = (uint64_t)IPW(ip, i*64+ 6) >>  6;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*31+ 3) |= (uint64_t)IPV(ip, i*64+ 7) << 25 | (uint64_t)IPX(ip, i*64+8) << 56;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*31+ 4)  = (uint64_t)IPW(ip, i*64+ 8) >>  8;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*31+ 4) |= (uint64_t)IPV(ip, i*64+ 9) << 23 | (uint64_t)IPX(ip, i*64+10) << 54;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*31+ 5)  = (uint64_t)IPW(ip, i*64+10) >> 10;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*31+ 5) |= (uint64_t)IPV(ip, i*64+11) << 21 | (uint64_t)IPX(ip, i*64+12) << 52;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*31+ 6)  = (uint64_t)IPW(ip, i*64+12) >> 12;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*31+ 6) |= (uint64_t)IPV(ip, i*64+13) << 19 | (uint64_t)IPX(ip, i*64+14) << 50;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*31+ 7)  = (uint64_t)IPW(ip, i*64+14) >> 14;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*31+ 7) |= (uint64_t)IPV(ip, i*64+15) << 17 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*31+ 8)  = (uint64_t)IPW(ip, i*64+16) >> 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*31+ 8) |= (uint64_t)IPV(ip, i*64+17) << 15 | (uint64_t)IPX(ip, i*64+18) << 46;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*31+ 9)  = (uint64_t)IPW(ip, i*64+18) >> 18;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*31+ 9) |= (uint64_t)IPV(ip, i*64+19) << 13 | (uint64_t)IPX(ip, i*64+20) << 44;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*31+10)  = (uint64_t)IPW(ip, i*64+20) >> 20;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*31+10) |= (uint64_t)IPV(ip, i*64+21) << 11 | (uint64_t)IPX(ip, i*64+22) << 42;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*31+11)  = (uint64_t)IPW(ip, i*64+22) >> 22;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*31+11) |= (uint64_t)IPV(ip, i*64+23) <<  9 | (uint64_t)IPX(ip, i*64+24) << 40;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*31+12)  = (uint64_t)IPW(ip, i*64+24) >> 24;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*31+12) |= (uint64_t)IPV(ip, i*64+25) <<  7 | (uint64_t)IPX(ip, i*64+26) << 38;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*31+13)  = (uint64_t)IPW(ip, i*64+26) >> 26;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*31+13) |= (uint64_t)IPV(ip, i*64+27) <<  5 | (uint64_t)IPX(ip, i*64+28) << 36;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*31+14)  = (uint64_t)IPW(ip, i*64+28) >> 28;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*31+14) |= (uint64_t)IPV(ip, i*64+29) <<  3 | (uint64_t)IPX(ip, i*64+30) << 34;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*31+15)  = (uint64_t)IPW(ip, i*64+30) >> 30;\
  IP9(ip, i*64+31, parm); *((uint64_t *)op+i*31+15) |= (uint64_t)IPV(ip, i*64+31) <<  1;\
}

#define BITPACK64_31(ip,  op, parm) { \
  BITBLK64_31(ip, 0, op, parm);  IPI(ip); op += 31*4/sizeof(op[0]);\
}

#define BITBLK64_32(ip, i, op, parm) { \
  IP9(ip, i*2+ 0, parm); *(uint32_t *)(op+i*8+ 0) = IPV(ip, i*2+ 0);\
  IP9(ip, i*2+ 1, parm); *(uint32_t *)(op+i*8+ 4) = IPV(ip, i*2+ 1);;\
}

#define BITPACK64_32(ip,  op, parm) { \
  BITBLK64_32(ip, 0, op, parm);\
  BITBLK64_32(ip, 1, op, parm);\
  BITBLK64_32(ip, 2, op, parm);\
  BITBLK64_32(ip, 3, op, parm);\
  BITBLK64_32(ip, 4, op, parm);\
  BITBLK64_32(ip, 5, op, parm);\
  BITBLK64_32(ip, 6, op, parm);\
  BITBLK64_32(ip, 7, op, parm);\
  BITBLK64_32(ip, 8, op, parm);\
  BITBLK64_32(ip, 9, op, parm);\
  BITBLK64_32(ip, 10, op, parm);\
  BITBLK64_32(ip, 11, op, parm);\
  BITBLK64_32(ip, 12, op, parm);\
  BITBLK64_32(ip, 13, op, parm);\
  BITBLK64_32(ip, 14, op, parm);\
  BITBLK64_32(ip, 15, op, parm);  IPI(ip); op += 32*4/sizeof(op[0]);\
}

#define BITBLK64_33(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*33+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 33;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*33+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 31;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*33+ 1) |= (uint64_t)IPV(ip, i*64+ 2) <<  2 | (uint64_t)IPX(ip, i*64+3) << 35;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*33+ 2)  = (uint64_t)IPW(ip, i*64+ 3) >> 29;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*33+ 2) |= (uint64_t)IPV(ip, i*64+ 4) <<  4 | (uint64_t)IPX(ip, i*64+5) << 37;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*33+ 3)  = (uint64_t)IPW(ip, i*64+ 5) >> 27;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*33+ 3) |= (uint64_t)IPV(ip, i*64+ 6) <<  6 | (uint64_t)IPX(ip, i*64+7) << 39;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*33+ 4)  = (uint64_t)IPW(ip, i*64+ 7) >> 25;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*33+ 4) |= (uint64_t)IPV(ip, i*64+ 8) <<  8 | (uint64_t)IPX(ip, i*64+9) << 41;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*33+ 5)  = (uint64_t)IPW(ip, i*64+ 9) >> 23;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*33+ 5) |= (uint64_t)IPV(ip, i*64+10) << 10 | (uint64_t)IPX(ip, i*64+11) << 43;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*33+ 6)  = (uint64_t)IPW(ip, i*64+11) >> 21;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*33+ 6) |= (uint64_t)IPV(ip, i*64+12) << 12 | (uint64_t)IPX(ip, i*64+13) << 45;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*33+ 7)  = (uint64_t)IPW(ip, i*64+13) >> 19;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*33+ 7) |= (uint64_t)IPV(ip, i*64+14) << 14 | (uint64_t)IPX(ip, i*64+15) << 47;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*33+ 8)  = (uint64_t)IPW(ip, i*64+15) >> 17;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*33+ 8) |= (uint64_t)IPV(ip, i*64+16) << 16 | (uint64_t)IPX(ip, i*64+17) << 49;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*33+ 9)  = (uint64_t)IPW(ip, i*64+17) >> 15;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*33+ 9) |= (uint64_t)IPV(ip, i*64+18) << 18 | (uint64_t)IPX(ip, i*64+19) << 51;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*33+10)  = (uint64_t)IPW(ip, i*64+19) >> 13;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*33+10) |= (uint64_t)IPV(ip, i*64+20) << 20 | (uint64_t)IPX(ip, i*64+21) << 53;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*33+11)  = (uint64_t)IPW(ip, i*64+21) >> 11;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*33+11) |= (uint64_t)IPV(ip, i*64+22) << 22 | (uint64_t)IPX(ip, i*64+23) << 55;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*33+12)  = (uint64_t)IPW(ip, i*64+23) >>  9;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*33+12) |= (uint64_t)IPV(ip, i*64+24) << 24 | (uint64_t)IPX(ip, i*64+25) << 57;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*33+13)  = (uint64_t)IPW(ip, i*64+25) >>  7;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*33+13) |= (uint64_t)IPV(ip, i*64+26) << 26 | (uint64_t)IPX(ip, i*64+27) << 59;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*33+14)  = (uint64_t)IPW(ip, i*64+27) >>  5;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*33+14) |= (uint64_t)IPV(ip, i*64+28) << 28 | (uint64_t)IPX(ip, i*64+29) << 61;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*33+15)  = (uint64_t)IPW(ip, i*64+29) >>  3;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*33+15) |= (uint64_t)IPV(ip, i*64+30) << 30 | (uint64_t)IPX(ip, i*64+31) << 63;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*33+16)  = (uint64_t)IPW(ip, i*64+31) >>  1;\
}

#define BITPACK64_33(ip,  op, parm) { \
  BITBLK64_33(ip, 0, op, parm);  IPI(ip); op += 33*4/sizeof(op[0]);\
}

#define BITBLK64_34(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*17+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 34;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*17+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >> 30;\
  IP9(ip, i*32+ 2, parm); *((uint64_t *)op+i*17+ 1) |= (uint64_t)IPV(ip, i*32+ 2) <<  4 | (uint64_t)IPX(ip, i*32+3) << 38;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*17+ 2)  = (uint64_t)IPW(ip, i*32+ 3) >> 26;\
  IP9(ip, i*32+ 4, parm); *((uint64_t *)op+i*17+ 2) |= (uint64_t)IPV(ip, i*32+ 4) <<  8 | (uint64_t)IPX(ip, i*32+5) << 42;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*17+ 3)  = (uint64_t)IPW(ip, i*32+ 5) >> 22;\
  IP9(ip, i*32+ 6, parm); *((uint64_t *)op+i*17+ 3) |= (uint64_t)IPV(ip, i*32+ 6) << 12 | (uint64_t)IPX(ip, i*32+7) << 46;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*17+ 4)  = (uint64_t)IPW(ip, i*32+ 7) >> 18;\
  IP9(ip, i*32+ 8, parm); *((uint64_t *)op+i*17+ 4) |= (uint64_t)IPV(ip, i*32+ 8) << 16 | (uint64_t)IPX(ip, i*32+9) << 50;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*17+ 5)  = (uint64_t)IPW(ip, i*32+ 9) >> 14;\
  IP9(ip, i*32+10, parm); *((uint64_t *)op+i*17+ 5) |= (uint64_t)IPV(ip, i*32+10) << 20 | (uint64_t)IPX(ip, i*32+11) << 54;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*17+ 6)  = (uint64_t)IPW(ip, i*32+11) >> 10;\
  IP9(ip, i*32+12, parm); *((uint64_t *)op+i*17+ 6) |= (uint64_t)IPV(ip, i*32+12) << 24 | (uint64_t)IPX(ip, i*32+13) << 58;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*17+ 7)  = (uint64_t)IPW(ip, i*32+13) >>  6;\
  IP9(ip, i*32+14, parm); *((uint64_t *)op+i*17+ 7) |= (uint64_t)IPV(ip, i*32+14) << 28 | (uint64_t)IPX(ip, i*32+15) << 62;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*17+ 8)  = (uint64_t)IPW(ip, i*32+15) >>  2 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*17+ 9)  = (uint64_t)IPW(ip, i*32+16) >> 32;\
  IP9(ip, i*32+17, parm); *((uint64_t *)op+i*17+ 9) |= (uint64_t)IPV(ip, i*32+17) <<  2 | (uint64_t)IPX(ip, i*32+18) << 36;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*17+10)  = (uint64_t)IPW(ip, i*32+18) >> 28;\
  IP9(ip, i*32+19, parm); *((uint64_t *)op+i*17+10) |= (uint64_t)IPV(ip, i*32+19) <<  6 | (uint64_t)IPX(ip, i*32+20) << 40;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*17+11)  = (uint64_t)IPW(ip, i*32+20) >> 24;\
  IP9(ip, i*32+21, parm); *((uint64_t *)op+i*17+11) |= (uint64_t)IPV(ip, i*32+21) << 10 | (uint64_t)IPX(ip, i*32+22) << 44;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*17+12)  = (uint64_t)IPW(ip, i*32+22) >> 20;\
  IP9(ip, i*32+23, parm); *((uint64_t *)op+i*17+12) |= (uint64_t)IPV(ip, i*32+23) << 14 | (uint64_t)IPX(ip, i*32+24) << 48;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*17+13)  = (uint64_t)IPW(ip, i*32+24) >> 16;\
  IP9(ip, i*32+25, parm); *((uint64_t *)op+i*17+13) |= (uint64_t)IPV(ip, i*32+25) << 18 | (uint64_t)IPX(ip, i*32+26) << 52;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*17+14)  = (uint64_t)IPW(ip, i*32+26) >> 12;\
  IP9(ip, i*32+27, parm); *((uint64_t *)op+i*17+14) |= (uint64_t)IPV(ip, i*32+27) << 22 | (uint64_t)IPX(ip, i*32+28) << 56;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*17+15)  = (uint64_t)IPW(ip, i*32+28) >>  8;\
  IP9(ip, i*32+29, parm); *((uint64_t *)op+i*17+15) |= (uint64_t)IPV(ip, i*32+29) << 26 | (uint64_t)IPX(ip, i*32+30) << 60;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*17+16)  = (uint64_t)IPW(ip, i*32+30) >>  4;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*17+16) |= (uint64_t)IPV(ip, i*32+31) << 30;\
}

#define BITPACK64_34(ip,  op, parm) { \
  BITBLK64_34(ip, 0, op, parm);  IPI(ip); op += 34*4/sizeof(op[0]);\
}

#define BITBLK64_35(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*35+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 35;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*35+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 29;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*35+ 1) |= (uint64_t)IPV(ip, i*64+ 2) <<  6 | (uint64_t)IPX(ip, i*64+3) << 41;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*35+ 2)  = (uint64_t)IPW(ip, i*64+ 3) >> 23;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*35+ 2) |= (uint64_t)IPV(ip, i*64+ 4) << 12 | (uint64_t)IPX(ip, i*64+5) << 47;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*35+ 3)  = (uint64_t)IPW(ip, i*64+ 5) >> 17;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*35+ 3) |= (uint64_t)IPV(ip, i*64+ 6) << 18 | (uint64_t)IPX(ip, i*64+7) << 53;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*35+ 4)  = (uint64_t)IPW(ip, i*64+ 7) >> 11;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*35+ 4) |= (uint64_t)IPV(ip, i*64+ 8) << 24 | (uint64_t)IPX(ip, i*64+9) << 59;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*35+ 5)  = (uint64_t)IPW(ip, i*64+ 9) >>  5 | (uint64_t)IPX(ip, i*64+10) << 30;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*35+ 6)  = (uint64_t)IPW(ip, i*64+10) >> 34;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*35+ 6) |= (uint64_t)IPV(ip, i*64+11) <<  1 | (uint64_t)IPX(ip, i*64+12) << 36;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*35+ 7)  = (uint64_t)IPW(ip, i*64+12) >> 28;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*35+ 7) |= (uint64_t)IPV(ip, i*64+13) <<  7 | (uint64_t)IPX(ip, i*64+14) << 42;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*35+ 8)  = (uint64_t)IPW(ip, i*64+14) >> 22;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*35+ 8) |= (uint64_t)IPV(ip, i*64+15) << 13 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*35+ 9)  = (uint64_t)IPW(ip, i*64+16) >> 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*35+ 9) |= (uint64_t)IPV(ip, i*64+17) << 19 | (uint64_t)IPX(ip, i*64+18) << 54;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*35+10)  = (uint64_t)IPW(ip, i*64+18) >> 10;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*35+10) |= (uint64_t)IPV(ip, i*64+19) << 25 | (uint64_t)IPX(ip, i*64+20) << 60;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*35+11)  = (uint64_t)IPW(ip, i*64+20) >>  4 | (uint64_t)IPX(ip, i*64+21) << 31;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*35+12)  = (uint64_t)IPW(ip, i*64+21) >> 33;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*35+12) |= (uint64_t)IPV(ip, i*64+22) <<  2 | (uint64_t)IPX(ip, i*64+23) << 37;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*35+13)  = (uint64_t)IPW(ip, i*64+23) >> 27;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*35+13) |= (uint64_t)IPV(ip, i*64+24) <<  8 | (uint64_t)IPX(ip, i*64+25) << 43;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*35+14)  = (uint64_t)IPW(ip, i*64+25) >> 21;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*35+14) |= (uint64_t)IPV(ip, i*64+26) << 14 | (uint64_t)IPX(ip, i*64+27) << 49;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*35+15)  = (uint64_t)IPW(ip, i*64+27) >> 15;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*35+15) |= (uint64_t)IPV(ip, i*64+28) << 20 | (uint64_t)IPX(ip, i*64+29) << 55;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*35+16)  = (uint64_t)IPW(ip, i*64+29) >>  9;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*35+16) |= (uint64_t)IPV(ip, i*64+30) << 26 | (uint64_t)IPX(ip, i*64+31) << 61;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*35+17)  = (uint64_t)IPW(ip, i*64+31) >>  3;\
}

#define BITPACK64_35(ip,  op, parm) { \
  BITBLK64_35(ip, 0, op, parm);  IPI(ip); op += 35*4/sizeof(op[0]);\
}

#define BITBLK64_36(ip, i, op, parm) { ;\
  IP9(ip, i*16+ 0, parm); *((uint64_t *)op+i*9+ 0)  = (uint64_t)IPV(ip, i*16+ 0)       | (uint64_t)IPX(ip, i*16+1) << 36;\
  IP64(ip, i*16+ 1, parm); *((uint64_t *)op+i*9+ 1)  = (uint64_t)IPW(ip, i*16+ 1) >> 28;\
  IP9(ip, i*16+ 2, parm); *((uint64_t *)op+i*9+ 1) |= (uint64_t)IPV(ip, i*16+ 2) <<  8 | (uint64_t)IPX(ip, i*16+3) << 44;\
  IP64(ip, i*16+ 3, parm); *((uint64_t *)op+i*9+ 2)  = (uint64_t)IPW(ip, i*16+ 3) >> 20;\
  IP9(ip, i*16+ 4, parm); *((uint64_t *)op+i*9+ 2) |= (uint64_t)IPV(ip, i*16+ 4) << 16 | (uint64_t)IPX(ip, i*16+5) << 52;\
  IP64(ip, i*16+ 5, parm); *((uint64_t *)op+i*9+ 3)  = (uint64_t)IPW(ip, i*16+ 5) >> 12;\
  IP9(ip, i*16+ 6, parm); *((uint64_t *)op+i*9+ 3) |= (uint64_t)IPV(ip, i*16+ 6) << 24 | (uint64_t)IPX(ip, i*16+7) << 60;\
  IP64(ip, i*16+ 7, parm); *((uint64_t *)op+i*9+ 4)  = (uint64_t)IPW(ip, i*16+ 7) >>  4 | (uint64_t)IPX(ip, i*16+8) << 32;\
  IP64(ip, i*16+ 8, parm); *((uint64_t *)op+i*9+ 5)  = (uint64_t)IPW(ip, i*16+ 8) >> 32;\
  IP9(ip, i*16+ 9, parm); *((uint64_t *)op+i*9+ 5) |= (uint64_t)IPV(ip, i*16+ 9) <<  4 | (uint64_t)IPX(ip, i*16+10) << 40;\
  IP64(ip, i*16+10, parm); *((uint64_t *)op+i*9+ 6)  = (uint64_t)IPW(ip, i*16+10) >> 24;\
  IP9(ip, i*16+11, parm); *((uint64_t *)op+i*9+ 6) |= (uint64_t)IPV(ip, i*16+11) << 12 | (uint64_t)IPX(ip, i*16+12) << 48;\
  IP64(ip, i*16+12, parm); *((uint64_t *)op+i*9+ 7)  = (uint64_t)IPW(ip, i*16+12) >> 16;\
  IP9(ip, i*16+13, parm); *((uint64_t *)op+i*9+ 7) |= (uint64_t)IPV(ip, i*16+13) << 20 | (uint64_t)IPX(ip, i*16+14) << 56;\
  IP64(ip, i*16+14, parm); *((uint64_t *)op+i*9+ 8)  = (uint64_t)IPW(ip, i*16+14) >>  8;\
  IP9(ip, i*16+15, parm); *((uint64_t *)op+i*9+ 8) |= (uint64_t)IPV(ip, i*16+15) << 28;\
}

#define BITPACK64_36(ip,  op, parm) { \
  BITBLK64_36(ip, 0, op, parm);\
  BITBLK64_36(ip, 1, op, parm);  IPI(ip); op += 36*4/sizeof(op[0]);\
}

#define BITBLK64_37(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*37+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 37;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*37+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 27;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*37+ 1) |= (uint64_t)IPV(ip, i*64+ 2) << 10 | (uint64_t)IPX(ip, i*64+3) << 47;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*37+ 2)  = (uint64_t)IPW(ip, i*64+ 3) >> 17;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*37+ 2) |= (uint64_t)IPV(ip, i*64+ 4) << 20 | (uint64_t)IPX(ip, i*64+5) << 57;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*37+ 3)  = (uint64_t)IPW(ip, i*64+ 5) >>  7 | (uint64_t)IPX(ip, i*64+6) << 30;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*37+ 4)  = (uint64_t)IPW(ip, i*64+ 6) >> 34;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*37+ 4) |= (uint64_t)IPV(ip, i*64+ 7) <<  3 | (uint64_t)IPX(ip, i*64+8) << 40;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*37+ 5)  = (uint64_t)IPW(ip, i*64+ 8) >> 24;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*37+ 5) |= (uint64_t)IPV(ip, i*64+ 9) << 13 | (uint64_t)IPX(ip, i*64+10) << 50;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*37+ 6)  = (uint64_t)IPW(ip, i*64+10) >> 14;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*37+ 6) |= (uint64_t)IPV(ip, i*64+11) << 23 | (uint64_t)IPX(ip, i*64+12) << 60;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*37+ 7)  = (uint64_t)IPW(ip, i*64+12) >>  4 | (uint64_t)IPX(ip, i*64+13) << 33;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*37+ 8)  = (uint64_t)IPW(ip, i*64+13) >> 31;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*37+ 8) |= (uint64_t)IPV(ip, i*64+14) <<  6 | (uint64_t)IPX(ip, i*64+15) << 43;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*37+ 9)  = (uint64_t)IPW(ip, i*64+15) >> 21;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*37+ 9) |= (uint64_t)IPV(ip, i*64+16) << 16 | (uint64_t)IPX(ip, i*64+17) << 53;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*37+10)  = (uint64_t)IPW(ip, i*64+17) >> 11;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*37+10) |= (uint64_t)IPV(ip, i*64+18) << 26 | (uint64_t)IPX(ip, i*64+19) << 63;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*37+11)  = (uint64_t)IPW(ip, i*64+19) >>  1 | (uint64_t)IPX(ip, i*64+20) << 36;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*37+12)  = (uint64_t)IPW(ip, i*64+20) >> 28;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*37+12) |= (uint64_t)IPV(ip, i*64+21) <<  9 | (uint64_t)IPX(ip, i*64+22) << 46;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*37+13)  = (uint64_t)IPW(ip, i*64+22) >> 18;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*37+13) |= (uint64_t)IPV(ip, i*64+23) << 19 | (uint64_t)IPX(ip, i*64+24) << 56;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*37+14)  = (uint64_t)IPW(ip, i*64+24) >>  8 | (uint64_t)IPX(ip, i*64+25) << 29;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*37+15)  = (uint64_t)IPW(ip, i*64+25) >> 35;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*37+15) |= (uint64_t)IPV(ip, i*64+26) <<  2 | (uint64_t)IPX(ip, i*64+27) << 39;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*37+16)  = (uint64_t)IPW(ip, i*64+27) >> 25;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*37+16) |= (uint64_t)IPV(ip, i*64+28) << 12 | (uint64_t)IPX(ip, i*64+29) << 49;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*37+17)  = (uint64_t)IPW(ip, i*64+29) >> 15;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*37+17) |= (uint64_t)IPV(ip, i*64+30) << 22 | (uint64_t)IPX(ip, i*64+31) << 59;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*37+18)  = (uint64_t)IPW(ip, i*64+31) >>  5;\
}

#define BITPACK64_37(ip,  op, parm) { \
  BITBLK64_37(ip, 0, op, parm);  IPI(ip); op += 37*4/sizeof(op[0]);\
}

#define BITBLK64_38(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*19+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 38;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*19+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >> 26;\
  IP9(ip, i*32+ 2, parm); *((uint64_t *)op+i*19+ 1) |= (uint64_t)IPV(ip, i*32+ 2) << 12 | (uint64_t)IPX(ip, i*32+3) << 50;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*19+ 2)  = (uint64_t)IPW(ip, i*32+ 3) >> 14;\
  IP9(ip, i*32+ 4, parm); *((uint64_t *)op+i*19+ 2) |= (uint64_t)IPV(ip, i*32+ 4) << 24 | (uint64_t)IPX(ip, i*32+5) << 62;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*19+ 3)  = (uint64_t)IPW(ip, i*32+ 5) >>  2 | (uint64_t)IPX(ip, i*32+6) << 36;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*19+ 4)  = (uint64_t)IPW(ip, i*32+ 6) >> 28;\
  IP9(ip, i*32+ 7, parm); *((uint64_t *)op+i*19+ 4) |= (uint64_t)IPV(ip, i*32+ 7) << 10 | (uint64_t)IPX(ip, i*32+8) << 48;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*19+ 5)  = (uint64_t)IPW(ip, i*32+ 8) >> 16;\
  IP9(ip, i*32+ 9, parm); *((uint64_t *)op+i*19+ 5) |= (uint64_t)IPV(ip, i*32+ 9) << 22 | (uint64_t)IPX(ip, i*32+10) << 60;\
  IP64(ip, i*32+10, parm); *((uint64_t *)op+i*19+ 6)  = (uint64_t)IPW(ip, i*32+10) >>  4 | (uint64_t)IPX(ip, i*32+11) << 34;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*19+ 7)  = (uint64_t)IPW(ip, i*32+11) >> 30;\
  IP9(ip, i*32+12, parm); *((uint64_t *)op+i*19+ 7) |= (uint64_t)IPV(ip, i*32+12) <<  8 | (uint64_t)IPX(ip, i*32+13) << 46;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*19+ 8)  = (uint64_t)IPW(ip, i*32+13) >> 18;\
  IP9(ip, i*32+14, parm); *((uint64_t *)op+i*19+ 8) |= (uint64_t)IPV(ip, i*32+14) << 20 | (uint64_t)IPX(ip, i*32+15) << 58;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*19+ 9)  = (uint64_t)IPW(ip, i*32+15) >>  6 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*19+10)  = (uint64_t)IPW(ip, i*32+16) >> 32;\
  IP9(ip, i*32+17, parm); *((uint64_t *)op+i*19+10) |= (uint64_t)IPV(ip, i*32+17) <<  6 | (uint64_t)IPX(ip, i*32+18) << 44;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*19+11)  = (uint64_t)IPW(ip, i*32+18) >> 20;\
  IP9(ip, i*32+19, parm); *((uint64_t *)op+i*19+11) |= (uint64_t)IPV(ip, i*32+19) << 18 | (uint64_t)IPX(ip, i*32+20) << 56;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*19+12)  = (uint64_t)IPW(ip, i*32+20) >>  8 | (uint64_t)IPX(ip, i*32+21) << 30;\
  IP64(ip, i*32+21, parm); *((uint64_t *)op+i*19+13)  = (uint64_t)IPW(ip, i*32+21) >> 34;\
  IP9(ip, i*32+22, parm); *((uint64_t *)op+i*19+13) |= (uint64_t)IPV(ip, i*32+22) <<  4 | (uint64_t)IPX(ip, i*32+23) << 42;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*19+14)  = (uint64_t)IPW(ip, i*32+23) >> 22;\
  IP9(ip, i*32+24, parm); *((uint64_t *)op+i*19+14) |= (uint64_t)IPV(ip, i*32+24) << 16 | (uint64_t)IPX(ip, i*32+25) << 54;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*19+15)  = (uint64_t)IPW(ip, i*32+25) >> 10 | (uint64_t)IPX(ip, i*32+26) << 28;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*19+16)  = (uint64_t)IPW(ip, i*32+26) >> 36;\
  IP9(ip, i*32+27, parm); *((uint64_t *)op+i*19+16) |= (uint64_t)IPV(ip, i*32+27) <<  2 | (uint64_t)IPX(ip, i*32+28) << 40;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*19+17)  = (uint64_t)IPW(ip, i*32+28) >> 24;\
  IP9(ip, i*32+29, parm); *((uint64_t *)op+i*19+17) |= (uint64_t)IPV(ip, i*32+29) << 14 | (uint64_t)IPX(ip, i*32+30) << 52;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*19+18)  = (uint64_t)IPW(ip, i*32+30) >> 12;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*19+18) |= (uint64_t)IPV(ip, i*32+31) << 26;\
}

#define BITPACK64_38(ip,  op, parm) { \
  BITBLK64_38(ip, 0, op, parm);  IPI(ip); op += 38*4/sizeof(op[0]);\
}

#define BITBLK64_39(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*39+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 39;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*39+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 25;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*39+ 1) |= (uint64_t)IPV(ip, i*64+ 2) << 14 | (uint64_t)IPX(ip, i*64+3) << 53;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*39+ 2)  = (uint64_t)IPW(ip, i*64+ 3) >> 11 | (uint64_t)IPX(ip, i*64+4) << 28;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*39+ 3)  = (uint64_t)IPW(ip, i*64+ 4) >> 36;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*39+ 3) |= (uint64_t)IPV(ip, i*64+ 5) <<  3 | (uint64_t)IPX(ip, i*64+6) << 42;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*39+ 4)  = (uint64_t)IPW(ip, i*64+ 6) >> 22;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*39+ 4) |= (uint64_t)IPV(ip, i*64+ 7) << 17 | (uint64_t)IPX(ip, i*64+8) << 56;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*39+ 5)  = (uint64_t)IPW(ip, i*64+ 8) >>  8 | (uint64_t)IPX(ip, i*64+9) << 31;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*39+ 6)  = (uint64_t)IPW(ip, i*64+ 9) >> 33;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*39+ 6) |= (uint64_t)IPV(ip, i*64+10) <<  6 | (uint64_t)IPX(ip, i*64+11) << 45;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*39+ 7)  = (uint64_t)IPW(ip, i*64+11) >> 19;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*39+ 7) |= (uint64_t)IPV(ip, i*64+12) << 20 | (uint64_t)IPX(ip, i*64+13) << 59;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*39+ 8)  = (uint64_t)IPW(ip, i*64+13) >>  5 | (uint64_t)IPX(ip, i*64+14) << 34;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*39+ 9)  = (uint64_t)IPW(ip, i*64+14) >> 30;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*39+ 9) |= (uint64_t)IPV(ip, i*64+15) <<  9 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*39+10)  = (uint64_t)IPW(ip, i*64+16) >> 16;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*39+10) |= (uint64_t)IPV(ip, i*64+17) << 23 | (uint64_t)IPX(ip, i*64+18) << 62;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*39+11)  = (uint64_t)IPW(ip, i*64+18) >>  2 | (uint64_t)IPX(ip, i*64+19) << 37;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*39+12)  = (uint64_t)IPW(ip, i*64+19) >> 27;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*39+12) |= (uint64_t)IPV(ip, i*64+20) << 12 | (uint64_t)IPX(ip, i*64+21) << 51;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*39+13)  = (uint64_t)IPW(ip, i*64+21) >> 13 | (uint64_t)IPX(ip, i*64+22) << 26;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*39+14)  = (uint64_t)IPW(ip, i*64+22) >> 38;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*39+14) |= (uint64_t)IPV(ip, i*64+23) <<  1 | (uint64_t)IPX(ip, i*64+24) << 40;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*39+15)  = (uint64_t)IPW(ip, i*64+24) >> 24;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*39+15) |= (uint64_t)IPV(ip, i*64+25) << 15 | (uint64_t)IPX(ip, i*64+26) << 54;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*39+16)  = (uint64_t)IPW(ip, i*64+26) >> 10 | (uint64_t)IPX(ip, i*64+27) << 29;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*39+17)  = (uint64_t)IPW(ip, i*64+27) >> 35;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*39+17) |= (uint64_t)IPV(ip, i*64+28) <<  4 | (uint64_t)IPX(ip, i*64+29) << 43;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*39+18)  = (uint64_t)IPW(ip, i*64+29) >> 21;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*39+18) |= (uint64_t)IPV(ip, i*64+30) << 18 | (uint64_t)IPX(ip, i*64+31) << 57;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*39+19)  = (uint64_t)IPW(ip, i*64+31) >>  7;\
}

#define BITPACK64_39(ip,  op, parm) { \
  BITBLK64_39(ip, 0, op, parm);  IPI(ip); op += 39*4/sizeof(op[0]);\
}

#define BITBLK64_40(ip, i, op, parm) { ;\
  IP9(ip, i*8+ 0, parm); *((uint64_t *)op+i*5+ 0)  = (uint64_t)IPV(ip, i*8+ 0)       | (uint64_t)IPX(ip, i*8+1) << 40;\
  IP64(ip, i*8+ 1, parm); *((uint64_t *)op+i*5+ 1)  = (uint64_t)IPW(ip, i*8+ 1) >> 24;\
  IP9(ip, i*8+ 2, parm); *((uint64_t *)op+i*5+ 1) |= (uint64_t)IPV(ip, i*8+ 2) << 16 | (uint64_t)IPX(ip, i*8+3) << 56;\
  IP64(ip, i*8+ 3, parm); *((uint64_t *)op+i*5+ 2)  = (uint64_t)IPW(ip, i*8+ 3) >>  8 | (uint64_t)IPX(ip, i*8+4) << 32;\
  IP64(ip, i*8+ 4, parm); *((uint64_t *)op+i*5+ 3)  = (uint64_t)IPW(ip, i*8+ 4) >> 32;\
  IP9(ip, i*8+ 5, parm); *((uint64_t *)op+i*5+ 3) |= (uint64_t)IPV(ip, i*8+ 5) <<  8 | (uint64_t)IPX(ip, i*8+6) << 48;\
  IP64(ip, i*8+ 6, parm); *((uint64_t *)op+i*5+ 4)  = (uint64_t)IPW(ip, i*8+ 6) >> 16;\
  IP9(ip, i*8+ 7, parm); *((uint64_t *)op+i*5+ 4) |= (uint64_t)IPV(ip, i*8+ 7) << 24;\
}

#define BITPACK64_40(ip,  op, parm) { \
  BITBLK64_40(ip, 0, op, parm);\
  BITBLK64_40(ip, 1, op, parm);\
  BITBLK64_40(ip, 2, op, parm);\
  BITBLK64_40(ip, 3, op, parm);  IPI(ip); op += 40*4/sizeof(op[0]);\
}

#define BITBLK64_41(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*41+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 41;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*41+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 23;\
  IP9(ip, i*64+ 2, parm); *((uint64_t *)op+i*41+ 1) |= (uint64_t)IPV(ip, i*64+ 2) << 18 | (uint64_t)IPX(ip, i*64+3) << 59;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*41+ 2)  = (uint64_t)IPW(ip, i*64+ 3) >>  5 | (uint64_t)IPX(ip, i*64+4) << 36;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*41+ 3)  = (uint64_t)IPW(ip, i*64+ 4) >> 28;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*41+ 3) |= (uint64_t)IPV(ip, i*64+ 5) << 13 | (uint64_t)IPX(ip, i*64+6) << 54;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*41+ 4)  = (uint64_t)IPW(ip, i*64+ 6) >> 10 | (uint64_t)IPX(ip, i*64+7) << 31;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*41+ 5)  = (uint64_t)IPW(ip, i*64+ 7) >> 33;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*41+ 5) |= (uint64_t)IPV(ip, i*64+ 8) <<  8 | (uint64_t)IPX(ip, i*64+9) << 49;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*41+ 6)  = (uint64_t)IPW(ip, i*64+ 9) >> 15 | (uint64_t)IPX(ip, i*64+10) << 26;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*41+ 7)  = (uint64_t)IPW(ip, i*64+10) >> 38;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*41+ 7) |= (uint64_t)IPV(ip, i*64+11) <<  3 | (uint64_t)IPX(ip, i*64+12) << 44;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*41+ 8)  = (uint64_t)IPW(ip, i*64+12) >> 20;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*41+ 8) |= (uint64_t)IPV(ip, i*64+13) << 21 | (uint64_t)IPX(ip, i*64+14) << 62;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*41+ 9)  = (uint64_t)IPW(ip, i*64+14) >>  2 | (uint64_t)IPX(ip, i*64+15) << 39;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*41+10)  = (uint64_t)IPW(ip, i*64+15) >> 25;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*41+10) |= (uint64_t)IPV(ip, i*64+16) << 16 | (uint64_t)IPX(ip, i*64+17) << 57;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*41+11)  = (uint64_t)IPW(ip, i*64+17) >>  7 | (uint64_t)IPX(ip, i*64+18) << 34;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*41+12)  = (uint64_t)IPW(ip, i*64+18) >> 30;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*41+12) |= (uint64_t)IPV(ip, i*64+19) << 11 | (uint64_t)IPX(ip, i*64+20) << 52;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*41+13)  = (uint64_t)IPW(ip, i*64+20) >> 12 | (uint64_t)IPX(ip, i*64+21) << 29;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*41+14)  = (uint64_t)IPW(ip, i*64+21) >> 35;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*41+14) |= (uint64_t)IPV(ip, i*64+22) <<  6 | (uint64_t)IPX(ip, i*64+23) << 47;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*41+15)  = (uint64_t)IPW(ip, i*64+23) >> 17 | (uint64_t)IPX(ip, i*64+24) << 24;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*41+16)  = (uint64_t)IPW(ip, i*64+24) >> 40;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*41+16) |= (uint64_t)IPV(ip, i*64+25) <<  1 | (uint64_t)IPX(ip, i*64+26) << 42;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*41+17)  = (uint64_t)IPW(ip, i*64+26) >> 22;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*41+17) |= (uint64_t)IPV(ip, i*64+27) << 19 | (uint64_t)IPX(ip, i*64+28) << 60;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*41+18)  = (uint64_t)IPW(ip, i*64+28) >>  4 | (uint64_t)IPX(ip, i*64+29) << 37;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*41+19)  = (uint64_t)IPW(ip, i*64+29) >> 27;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*41+19) |= (uint64_t)IPV(ip, i*64+30) << 14 | (uint64_t)IPX(ip, i*64+31) << 55;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*41+20)  = (uint64_t)IPW(ip, i*64+31) >>  9;\
}

#define BITPACK64_41(ip,  op, parm) { \
  BITBLK64_41(ip, 0, op, parm);  IPI(ip); op += 41*4/sizeof(op[0]);\
}

#define BITBLK64_42(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*21+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 42;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*21+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >> 22;\
  IP9(ip, i*32+ 2, parm); *((uint64_t *)op+i*21+ 1) |= (uint64_t)IPV(ip, i*32+ 2) << 20 | (uint64_t)IPX(ip, i*32+3) << 62;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*21+ 2)  = (uint64_t)IPW(ip, i*32+ 3) >>  2 | (uint64_t)IPX(ip, i*32+4) << 40;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*21+ 3)  = (uint64_t)IPW(ip, i*32+ 4) >> 24;\
  IP9(ip, i*32+ 5, parm); *((uint64_t *)op+i*21+ 3) |= (uint64_t)IPV(ip, i*32+ 5) << 18 | (uint64_t)IPX(ip, i*32+6) << 60;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*21+ 4)  = (uint64_t)IPW(ip, i*32+ 6) >>  4 | (uint64_t)IPX(ip, i*32+7) << 38;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*21+ 5)  = (uint64_t)IPW(ip, i*32+ 7) >> 26;\
  IP9(ip, i*32+ 8, parm); *((uint64_t *)op+i*21+ 5) |= (uint64_t)IPV(ip, i*32+ 8) << 16 | (uint64_t)IPX(ip, i*32+9) << 58;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*21+ 6)  = (uint64_t)IPW(ip, i*32+ 9) >>  6 | (uint64_t)IPX(ip, i*32+10) << 36;\
  IP64(ip, i*32+10, parm); *((uint64_t *)op+i*21+ 7)  = (uint64_t)IPW(ip, i*32+10) >> 28;\
  IP9(ip, i*32+11, parm); *((uint64_t *)op+i*21+ 7) |= (uint64_t)IPV(ip, i*32+11) << 14 | (uint64_t)IPX(ip, i*32+12) << 56;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*21+ 8)  = (uint64_t)IPW(ip, i*32+12) >>  8 | (uint64_t)IPX(ip, i*32+13) << 34;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*21+ 9)  = (uint64_t)IPW(ip, i*32+13) >> 30;\
  IP9(ip, i*32+14, parm); *((uint64_t *)op+i*21+ 9) |= (uint64_t)IPV(ip, i*32+14) << 12 | (uint64_t)IPX(ip, i*32+15) << 54;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*21+10)  = (uint64_t)IPW(ip, i*32+15) >> 10 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*21+11)  = (uint64_t)IPW(ip, i*32+16) >> 32;\
  IP9(ip, i*32+17, parm); *((uint64_t *)op+i*21+11) |= (uint64_t)IPV(ip, i*32+17) << 10 | (uint64_t)IPX(ip, i*32+18) << 52;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*21+12)  = (uint64_t)IPW(ip, i*32+18) >> 12 | (uint64_t)IPX(ip, i*32+19) << 30;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*21+13)  = (uint64_t)IPW(ip, i*32+19) >> 34;\
  IP9(ip, i*32+20, parm); *((uint64_t *)op+i*21+13) |= (uint64_t)IPV(ip, i*32+20) <<  8 | (uint64_t)IPX(ip, i*32+21) << 50;\
  IP64(ip, i*32+21, parm); *((uint64_t *)op+i*21+14)  = (uint64_t)IPW(ip, i*32+21) >> 14 | (uint64_t)IPX(ip, i*32+22) << 28;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*21+15)  = (uint64_t)IPW(ip, i*32+22) >> 36;\
  IP9(ip, i*32+23, parm); *((uint64_t *)op+i*21+15) |= (uint64_t)IPV(ip, i*32+23) <<  6 | (uint64_t)IPX(ip, i*32+24) << 48;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*21+16)  = (uint64_t)IPW(ip, i*32+24) >> 16 | (uint64_t)IPX(ip, i*32+25) << 26;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*21+17)  = (uint64_t)IPW(ip, i*32+25) >> 38;\
  IP9(ip, i*32+26, parm); *((uint64_t *)op+i*21+17) |= (uint64_t)IPV(ip, i*32+26) <<  4 | (uint64_t)IPX(ip, i*32+27) << 46;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*21+18)  = (uint64_t)IPW(ip, i*32+27) >> 18 | (uint64_t)IPX(ip, i*32+28) << 24;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*21+19)  = (uint64_t)IPW(ip, i*32+28) >> 40;\
  IP9(ip, i*32+29, parm); *((uint64_t *)op+i*21+19) |= (uint64_t)IPV(ip, i*32+29) <<  2 | (uint64_t)IPX(ip, i*32+30) << 44;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*21+20)  = (uint64_t)IPW(ip, i*32+30) >> 20;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*21+20) |= (uint64_t)IPV(ip, i*32+31) << 22;\
}

#define BITPACK64_42(ip,  op, parm) { \
  BITBLK64_42(ip, 0, op, parm);  IPI(ip); op += 42*4/sizeof(op[0]);\
}

#define BITBLK64_43(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*43+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 43;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*43+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 21 | (uint64_t)IPX(ip, i*64+2) << 22;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*43+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 42;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*43+ 2) |= (uint64_t)IPV(ip, i*64+ 3) <<  1 | (uint64_t)IPX(ip, i*64+4) << 44;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*43+ 3)  = (uint64_t)IPW(ip, i*64+ 4) >> 20 | (uint64_t)IPX(ip, i*64+5) << 23;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*43+ 4)  = (uint64_t)IPW(ip, i*64+ 5) >> 41;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*43+ 4) |= (uint64_t)IPV(ip, i*64+ 6) <<  2 | (uint64_t)IPX(ip, i*64+7) << 45;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*43+ 5)  = (uint64_t)IPW(ip, i*64+ 7) >> 19 | (uint64_t)IPX(ip, i*64+8) << 24;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*43+ 6)  = (uint64_t)IPW(ip, i*64+ 8) >> 40;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*43+ 6) |= (uint64_t)IPV(ip, i*64+ 9) <<  3 | (uint64_t)IPX(ip, i*64+10) << 46;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*43+ 7)  = (uint64_t)IPW(ip, i*64+10) >> 18 | (uint64_t)IPX(ip, i*64+11) << 25;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*43+ 8)  = (uint64_t)IPW(ip, i*64+11) >> 39;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*43+ 8) |= (uint64_t)IPV(ip, i*64+12) <<  4 | (uint64_t)IPX(ip, i*64+13) << 47;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*43+ 9)  = (uint64_t)IPW(ip, i*64+13) >> 17 | (uint64_t)IPX(ip, i*64+14) << 26;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*43+10)  = (uint64_t)IPW(ip, i*64+14) >> 38;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*43+10) |= (uint64_t)IPV(ip, i*64+15) <<  5 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*43+11)  = (uint64_t)IPW(ip, i*64+16) >> 16 | (uint64_t)IPX(ip, i*64+17) << 27;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*43+12)  = (uint64_t)IPW(ip, i*64+17) >> 37;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*43+12) |= (uint64_t)IPV(ip, i*64+18) <<  6 | (uint64_t)IPX(ip, i*64+19) << 49;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*43+13)  = (uint64_t)IPW(ip, i*64+19) >> 15 | (uint64_t)IPX(ip, i*64+20) << 28;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*43+14)  = (uint64_t)IPW(ip, i*64+20) >> 36;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*43+14) |= (uint64_t)IPV(ip, i*64+21) <<  7 | (uint64_t)IPX(ip, i*64+22) << 50;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*43+15)  = (uint64_t)IPW(ip, i*64+22) >> 14 | (uint64_t)IPX(ip, i*64+23) << 29;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*43+16)  = (uint64_t)IPW(ip, i*64+23) >> 35;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*43+16) |= (uint64_t)IPV(ip, i*64+24) <<  8 | (uint64_t)IPX(ip, i*64+25) << 51;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*43+17)  = (uint64_t)IPW(ip, i*64+25) >> 13 | (uint64_t)IPX(ip, i*64+26) << 30;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*43+18)  = (uint64_t)IPW(ip, i*64+26) >> 34;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*43+18) |= (uint64_t)IPV(ip, i*64+27) <<  9 | (uint64_t)IPX(ip, i*64+28) << 52;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*43+19)  = (uint64_t)IPW(ip, i*64+28) >> 12 | (uint64_t)IPX(ip, i*64+29) << 31;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*43+20)  = (uint64_t)IPW(ip, i*64+29) >> 33;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*43+20) |= (uint64_t)IPV(ip, i*64+30) << 10 | (uint64_t)IPX(ip, i*64+31) << 53;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*43+21)  = (uint64_t)IPW(ip, i*64+31) >> 11;\
}

#define BITPACK64_43(ip,  op, parm) { \
  BITBLK64_43(ip, 0, op, parm);  IPI(ip); op += 43*4/sizeof(op[0]);\
}

#define BITBLK64_44(ip, i, op, parm) { ;\
  IP9(ip, i*16+ 0, parm); *((uint64_t *)op+i*11+ 0)  = (uint64_t)IPV(ip, i*16+ 0)       | (uint64_t)IPX(ip, i*16+1) << 44;\
  IP64(ip, i*16+ 1, parm); *((uint64_t *)op+i*11+ 1)  = (uint64_t)IPW(ip, i*16+ 1) >> 20 | (uint64_t)IPX(ip, i*16+2) << 24;\
  IP64(ip, i*16+ 2, parm); *((uint64_t *)op+i*11+ 2)  = (uint64_t)IPW(ip, i*16+ 2) >> 40;\
  IP9(ip, i*16+ 3, parm); *((uint64_t *)op+i*11+ 2) |= (uint64_t)IPV(ip, i*16+ 3) <<  4 | (uint64_t)IPX(ip, i*16+4) << 48;\
  IP64(ip, i*16+ 4, parm); *((uint64_t *)op+i*11+ 3)  = (uint64_t)IPW(ip, i*16+ 4) >> 16 | (uint64_t)IPX(ip, i*16+5) << 28;\
  IP64(ip, i*16+ 5, parm); *((uint64_t *)op+i*11+ 4)  = (uint64_t)IPW(ip, i*16+ 5) >> 36;\
  IP9(ip, i*16+ 6, parm); *((uint64_t *)op+i*11+ 4) |= (uint64_t)IPV(ip, i*16+ 6) <<  8 | (uint64_t)IPX(ip, i*16+7) << 52;\
  IP64(ip, i*16+ 7, parm); *((uint64_t *)op+i*11+ 5)  = (uint64_t)IPW(ip, i*16+ 7) >> 12 | (uint64_t)IPX(ip, i*16+8) << 32;\
  IP64(ip, i*16+ 8, parm); *((uint64_t *)op+i*11+ 6)  = (uint64_t)IPW(ip, i*16+ 8) >> 32;\
  IP9(ip, i*16+ 9, parm); *((uint64_t *)op+i*11+ 6) |= (uint64_t)IPV(ip, i*16+ 9) << 12 | (uint64_t)IPX(ip, i*16+10) << 56;\
  IP64(ip, i*16+10, parm); *((uint64_t *)op+i*11+ 7)  = (uint64_t)IPW(ip, i*16+10) >>  8 | (uint64_t)IPX(ip, i*16+11) << 36;\
  IP64(ip, i*16+11, parm); *((uint64_t *)op+i*11+ 8)  = (uint64_t)IPW(ip, i*16+11) >> 28;\
  IP9(ip, i*16+12, parm); *((uint64_t *)op+i*11+ 8) |= (uint64_t)IPV(ip, i*16+12) << 16 | (uint64_t)IPX(ip, i*16+13) << 60;\
  IP64(ip, i*16+13, parm); *((uint64_t *)op+i*11+ 9)  = (uint64_t)IPW(ip, i*16+13) >>  4 | (uint64_t)IPX(ip, i*16+14) << 40;\
  IP64(ip, i*16+14, parm); *((uint64_t *)op+i*11+10)  = (uint64_t)IPW(ip, i*16+14) >> 24;\
  IP9(ip, i*16+15, parm); *((uint64_t *)op+i*11+10) |= (uint64_t)IPV(ip, i*16+15) << 20;\
}

#define BITPACK64_44(ip,  op, parm) { \
  BITBLK64_44(ip, 0, op, parm);\
  BITBLK64_44(ip, 1, op, parm);  IPI(ip); op += 44*4/sizeof(op[0]);\
}

#define BITBLK64_45(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*45+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 45;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*45+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 19 | (uint64_t)IPX(ip, i*64+2) << 26;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*45+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 38;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*45+ 2) |= (uint64_t)IPV(ip, i*64+ 3) <<  7 | (uint64_t)IPX(ip, i*64+4) << 52;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*45+ 3)  = (uint64_t)IPW(ip, i*64+ 4) >> 12 | (uint64_t)IPX(ip, i*64+5) << 33;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*45+ 4)  = (uint64_t)IPW(ip, i*64+ 5) >> 31;\
  IP9(ip, i*64+ 6, parm); *((uint64_t *)op+i*45+ 4) |= (uint64_t)IPV(ip, i*64+ 6) << 14 | (uint64_t)IPX(ip, i*64+7) << 59;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*45+ 5)  = (uint64_t)IPW(ip, i*64+ 7) >>  5 | (uint64_t)IPX(ip, i*64+8) << 40;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*45+ 6)  = (uint64_t)IPW(ip, i*64+ 8) >> 24 | (uint64_t)IPX(ip, i*64+9) << 21;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*45+ 7)  = (uint64_t)IPW(ip, i*64+ 9) >> 43;\
  IP9(ip, i*64+10, parm); *((uint64_t *)op+i*45+ 7) |= (uint64_t)IPV(ip, i*64+10) <<  2 | (uint64_t)IPX(ip, i*64+11) << 47;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*45+ 8)  = (uint64_t)IPW(ip, i*64+11) >> 17 | (uint64_t)IPX(ip, i*64+12) << 28;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*45+ 9)  = (uint64_t)IPW(ip, i*64+12) >> 36;\
  IP9(ip, i*64+13, parm); *((uint64_t *)op+i*45+ 9) |= (uint64_t)IPV(ip, i*64+13) <<  9 | (uint64_t)IPX(ip, i*64+14) << 54;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*45+10)  = (uint64_t)IPW(ip, i*64+14) >> 10 | (uint64_t)IPX(ip, i*64+15) << 35;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*45+11)  = (uint64_t)IPW(ip, i*64+15) >> 29;\
  IP9(ip, i*64+16, parm); *((uint64_t *)op+i*45+11) |= (uint64_t)IPV(ip, i*64+16) << 16 | (uint64_t)IPX(ip, i*64+17) << 61;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*45+12)  = (uint64_t)IPW(ip, i*64+17) >>  3 | (uint64_t)IPX(ip, i*64+18) << 42;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*45+13)  = (uint64_t)IPW(ip, i*64+18) >> 22 | (uint64_t)IPX(ip, i*64+19) << 23;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*45+14)  = (uint64_t)IPW(ip, i*64+19) >> 41;\
  IP9(ip, i*64+20, parm); *((uint64_t *)op+i*45+14) |= (uint64_t)IPV(ip, i*64+20) <<  4 | (uint64_t)IPX(ip, i*64+21) << 49;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*45+15)  = (uint64_t)IPW(ip, i*64+21) >> 15 | (uint64_t)IPX(ip, i*64+22) << 30;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*45+16)  = (uint64_t)IPW(ip, i*64+22) >> 34;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*45+16) |= (uint64_t)IPV(ip, i*64+23) << 11 | (uint64_t)IPX(ip, i*64+24) << 56;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*45+17)  = (uint64_t)IPW(ip, i*64+24) >>  8 | (uint64_t)IPX(ip, i*64+25) << 37;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*45+18)  = (uint64_t)IPW(ip, i*64+25) >> 27;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*45+18) |= (uint64_t)IPV(ip, i*64+26) << 18 | (uint64_t)IPX(ip, i*64+27) << 63;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*45+19)  = (uint64_t)IPW(ip, i*64+27) >>  1 | (uint64_t)IPX(ip, i*64+28) << 44;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*45+20)  = (uint64_t)IPW(ip, i*64+28) >> 20 | (uint64_t)IPX(ip, i*64+29) << 25;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*45+21)  = (uint64_t)IPW(ip, i*64+29) >> 39;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*45+21) |= (uint64_t)IPV(ip, i*64+30) <<  6 | (uint64_t)IPX(ip, i*64+31) << 51;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*45+22)  = (uint64_t)IPW(ip, i*64+31) >> 13;\
}

#define BITPACK64_45(ip,  op, parm) { \
  BITBLK64_45(ip, 0, op, parm);  IPI(ip); op += 45*4/sizeof(op[0]);\
}

#define BITBLK64_46(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*23+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 46;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*23+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >> 18 | (uint64_t)IPX(ip, i*32+2) << 28;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*23+ 2)  = (uint64_t)IPW(ip, i*32+ 2) >> 36;\
  IP9(ip, i*32+ 3, parm); *((uint64_t *)op+i*23+ 2) |= (uint64_t)IPV(ip, i*32+ 3) << 10 | (uint64_t)IPX(ip, i*32+4) << 56;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*23+ 3)  = (uint64_t)IPW(ip, i*32+ 4) >>  8 | (uint64_t)IPX(ip, i*32+5) << 38;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*23+ 4)  = (uint64_t)IPW(ip, i*32+ 5) >> 26 | (uint64_t)IPX(ip, i*32+6) << 20;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*23+ 5)  = (uint64_t)IPW(ip, i*32+ 6) >> 44;\
  IP9(ip, i*32+ 7, parm); *((uint64_t *)op+i*23+ 5) |= (uint64_t)IPV(ip, i*32+ 7) <<  2 | (uint64_t)IPX(ip, i*32+8) << 48;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*23+ 6)  = (uint64_t)IPW(ip, i*32+ 8) >> 16 | (uint64_t)IPX(ip, i*32+9) << 30;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*23+ 7)  = (uint64_t)IPW(ip, i*32+ 9) >> 34;\
  IP9(ip, i*32+10, parm); *((uint64_t *)op+i*23+ 7) |= (uint64_t)IPV(ip, i*32+10) << 12 | (uint64_t)IPX(ip, i*32+11) << 58;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*23+ 8)  = (uint64_t)IPW(ip, i*32+11) >>  6 | (uint64_t)IPX(ip, i*32+12) << 40;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*23+ 9)  = (uint64_t)IPW(ip, i*32+12) >> 24 | (uint64_t)IPX(ip, i*32+13) << 22;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*23+10)  = (uint64_t)IPW(ip, i*32+13) >> 42;\
  IP9(ip, i*32+14, parm); *((uint64_t *)op+i*23+10) |= (uint64_t)IPV(ip, i*32+14) <<  4 | (uint64_t)IPX(ip, i*32+15) << 50;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*23+11)  = (uint64_t)IPW(ip, i*32+15) >> 14 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*23+12)  = (uint64_t)IPW(ip, i*32+16) >> 32;\
  IP9(ip, i*32+17, parm); *((uint64_t *)op+i*23+12) |= (uint64_t)IPV(ip, i*32+17) << 14 | (uint64_t)IPX(ip, i*32+18) << 60;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*23+13)  = (uint64_t)IPW(ip, i*32+18) >>  4 | (uint64_t)IPX(ip, i*32+19) << 42;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*23+14)  = (uint64_t)IPW(ip, i*32+19) >> 22 | (uint64_t)IPX(ip, i*32+20) << 24;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*23+15)  = (uint64_t)IPW(ip, i*32+20) >> 40;\
  IP9(ip, i*32+21, parm); *((uint64_t *)op+i*23+15) |= (uint64_t)IPV(ip, i*32+21) <<  6 | (uint64_t)IPX(ip, i*32+22) << 52;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*23+16)  = (uint64_t)IPW(ip, i*32+22) >> 12 | (uint64_t)IPX(ip, i*32+23) << 34;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*23+17)  = (uint64_t)IPW(ip, i*32+23) >> 30;\
  IP9(ip, i*32+24, parm); *((uint64_t *)op+i*23+17) |= (uint64_t)IPV(ip, i*32+24) << 16 | (uint64_t)IPX(ip, i*32+25) << 62;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*23+18)  = (uint64_t)IPW(ip, i*32+25) >>  2 | (uint64_t)IPX(ip, i*32+26) << 44;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*23+19)  = (uint64_t)IPW(ip, i*32+26) >> 20 | (uint64_t)IPX(ip, i*32+27) << 26;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*23+20)  = (uint64_t)IPW(ip, i*32+27) >> 38;\
  IP9(ip, i*32+28, parm); *((uint64_t *)op+i*23+20) |= (uint64_t)IPV(ip, i*32+28) <<  8 | (uint64_t)IPX(ip, i*32+29) << 54;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*23+21)  = (uint64_t)IPW(ip, i*32+29) >> 10 | (uint64_t)IPX(ip, i*32+30) << 36;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*23+22)  = (uint64_t)IPW(ip, i*32+30) >> 28;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*23+22) |= (uint64_t)IPV(ip, i*32+31) << 18;\
}

#define BITPACK64_46(ip,  op, parm) { \
  BITBLK64_46(ip, 0, op, parm);  IPI(ip); op += 46*4/sizeof(op[0]);\
}

#define BITBLK64_47(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*47+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 47;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*47+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 17 | (uint64_t)IPX(ip, i*64+2) << 30;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*47+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 34;\
  IP9(ip, i*64+ 3, parm); *((uint64_t *)op+i*47+ 2) |= (uint64_t)IPV(ip, i*64+ 3) << 13 | (uint64_t)IPX(ip, i*64+4) << 60;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*47+ 3)  = (uint64_t)IPW(ip, i*64+ 4) >>  4 | (uint64_t)IPX(ip, i*64+5) << 43;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*47+ 4)  = (uint64_t)IPW(ip, i*64+ 5) >> 21 | (uint64_t)IPX(ip, i*64+6) << 26;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*47+ 5)  = (uint64_t)IPW(ip, i*64+ 6) >> 38;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*47+ 5) |= (uint64_t)IPV(ip, i*64+ 7) <<  9 | (uint64_t)IPX(ip, i*64+8) << 56;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*47+ 6)  = (uint64_t)IPW(ip, i*64+ 8) >>  8 | (uint64_t)IPX(ip, i*64+9) << 39;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*47+ 7)  = (uint64_t)IPW(ip, i*64+ 9) >> 25 | (uint64_t)IPX(ip, i*64+10) << 22;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*47+ 8)  = (uint64_t)IPW(ip, i*64+10) >> 42;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*47+ 8) |= (uint64_t)IPV(ip, i*64+11) <<  5 | (uint64_t)IPX(ip, i*64+12) << 52;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*47+ 9)  = (uint64_t)IPW(ip, i*64+12) >> 12 | (uint64_t)IPX(ip, i*64+13) << 35;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*47+10)  = (uint64_t)IPW(ip, i*64+13) >> 29 | (uint64_t)IPX(ip, i*64+14) << 18;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*47+11)  = (uint64_t)IPW(ip, i*64+14) >> 46;\
  IP9(ip, i*64+15, parm); *((uint64_t *)op+i*47+11) |= (uint64_t)IPV(ip, i*64+15) <<  1 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*47+12)  = (uint64_t)IPW(ip, i*64+16) >> 16 | (uint64_t)IPX(ip, i*64+17) << 31;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*47+13)  = (uint64_t)IPW(ip, i*64+17) >> 33;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*47+13) |= (uint64_t)IPV(ip, i*64+18) << 14 | (uint64_t)IPX(ip, i*64+19) << 61;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*47+14)  = (uint64_t)IPW(ip, i*64+19) >>  3 | (uint64_t)IPX(ip, i*64+20) << 44;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*47+15)  = (uint64_t)IPW(ip, i*64+20) >> 20 | (uint64_t)IPX(ip, i*64+21) << 27;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*47+16)  = (uint64_t)IPW(ip, i*64+21) >> 37;\
  IP9(ip, i*64+22, parm); *((uint64_t *)op+i*47+16) |= (uint64_t)IPV(ip, i*64+22) << 10 | (uint64_t)IPX(ip, i*64+23) << 57;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*47+17)  = (uint64_t)IPW(ip, i*64+23) >>  7 | (uint64_t)IPX(ip, i*64+24) << 40;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*47+18)  = (uint64_t)IPW(ip, i*64+24) >> 24 | (uint64_t)IPX(ip, i*64+25) << 23;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*47+19)  = (uint64_t)IPW(ip, i*64+25) >> 41;\
  IP9(ip, i*64+26, parm); *((uint64_t *)op+i*47+19) |= (uint64_t)IPV(ip, i*64+26) <<  6 | (uint64_t)IPX(ip, i*64+27) << 53;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*47+20)  = (uint64_t)IPW(ip, i*64+27) >> 11 | (uint64_t)IPX(ip, i*64+28) << 36;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*47+21)  = (uint64_t)IPW(ip, i*64+28) >> 28 | (uint64_t)IPX(ip, i*64+29) << 19;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*47+22)  = (uint64_t)IPW(ip, i*64+29) >> 45;\
  IP9(ip, i*64+30, parm); *((uint64_t *)op+i*47+22) |= (uint64_t)IPV(ip, i*64+30) <<  2 | (uint64_t)IPX(ip, i*64+31) << 49;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*47+23)  = (uint64_t)IPW(ip, i*64+31) >> 15;\
}

#define BITPACK64_47(ip,  op, parm) { \
  BITBLK64_47(ip, 0, op, parm);  IPI(ip); op += 47*4/sizeof(op[0]);\
}

#define BITBLK64_48(ip, i, op, parm) { ;\
  IP9(ip, i*4+ 0, parm); *((uint64_t *)op+i*3+ 0)  = (uint64_t)IPV(ip, i*4+ 0)       | (uint64_t)IPX(ip, i*4+1) << 48;\
  IP64(ip, i*4+ 1, parm); *((uint64_t *)op+i*3+ 1)  = (uint64_t)IPW(ip, i*4+ 1) >> 16 | (uint64_t)IPX(ip, i*4+2) << 32;\
  IP64(ip, i*4+ 2, parm); *((uint64_t *)op+i*3+ 2)  = (uint64_t)IPW(ip, i*4+ 2) >> 32;\
  IP9(ip, i*4+ 3, parm); *((uint64_t *)op+i*3+ 2) |= (uint64_t)IPV(ip, i*4+ 3) << 16;\
}

#define BITPACK64_48(ip,  op, parm) { \
  BITBLK64_48(ip, 0, op, parm);\
  BITBLK64_48(ip, 1, op, parm);\
  BITBLK64_48(ip, 2, op, parm);\
  BITBLK64_48(ip, 3, op, parm);\
  BITBLK64_48(ip, 4, op, parm);\
  BITBLK64_48(ip, 5, op, parm);\
  BITBLK64_48(ip, 6, op, parm);\
  BITBLK64_48(ip, 7, op, parm);  IPI(ip); op += 48*4/sizeof(op[0]);\
}

#define BITBLK64_49(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*49+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 49;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*49+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 15 | (uint64_t)IPX(ip, i*64+2) << 34;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*49+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 30 | (uint64_t)IPX(ip, i*64+3) << 19;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*49+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >> 45;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*49+ 3) |= (uint64_t)IPV(ip, i*64+ 4) <<  4 | (uint64_t)IPX(ip, i*64+5) << 53;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*49+ 4)  = (uint64_t)IPW(ip, i*64+ 5) >> 11 | (uint64_t)IPX(ip, i*64+6) << 38;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*49+ 5)  = (uint64_t)IPW(ip, i*64+ 6) >> 26 | (uint64_t)IPX(ip, i*64+7) << 23;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*49+ 6)  = (uint64_t)IPW(ip, i*64+ 7) >> 41;\
  IP9(ip, i*64+ 8, parm); *((uint64_t *)op+i*49+ 6) |= (uint64_t)IPV(ip, i*64+ 8) <<  8 | (uint64_t)IPX(ip, i*64+9) << 57;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*49+ 7)  = (uint64_t)IPW(ip, i*64+ 9) >>  7 | (uint64_t)IPX(ip, i*64+10) << 42;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*49+ 8)  = (uint64_t)IPW(ip, i*64+10) >> 22 | (uint64_t)IPX(ip, i*64+11) << 27;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*49+ 9)  = (uint64_t)IPW(ip, i*64+11) >> 37;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*49+ 9) |= (uint64_t)IPV(ip, i*64+12) << 12 | (uint64_t)IPX(ip, i*64+13) << 61;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*49+10)  = (uint64_t)IPW(ip, i*64+13) >>  3 | (uint64_t)IPX(ip, i*64+14) << 46;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*49+11)  = (uint64_t)IPW(ip, i*64+14) >> 18 | (uint64_t)IPX(ip, i*64+15) << 31;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*49+12)  = (uint64_t)IPW(ip, i*64+15) >> 33 | (uint64_t)IPX(ip, i*64+16) << 16;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*49+13)  = (uint64_t)IPW(ip, i*64+16) >> 48;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*49+13) |= (uint64_t)IPV(ip, i*64+17) <<  1 | (uint64_t)IPX(ip, i*64+18) << 50;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*49+14)  = (uint64_t)IPW(ip, i*64+18) >> 14 | (uint64_t)IPX(ip, i*64+19) << 35;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*49+15)  = (uint64_t)IPW(ip, i*64+19) >> 29 | (uint64_t)IPX(ip, i*64+20) << 20;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*49+16)  = (uint64_t)IPW(ip, i*64+20) >> 44;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*49+16) |= (uint64_t)IPV(ip, i*64+21) <<  5 | (uint64_t)IPX(ip, i*64+22) << 54;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*49+17)  = (uint64_t)IPW(ip, i*64+22) >> 10 | (uint64_t)IPX(ip, i*64+23) << 39;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*49+18)  = (uint64_t)IPW(ip, i*64+23) >> 25 | (uint64_t)IPX(ip, i*64+24) << 24;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*49+19)  = (uint64_t)IPW(ip, i*64+24) >> 40;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*49+19) |= (uint64_t)IPV(ip, i*64+25) <<  9 | (uint64_t)IPX(ip, i*64+26) << 58;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*49+20)  = (uint64_t)IPW(ip, i*64+26) >>  6 | (uint64_t)IPX(ip, i*64+27) << 43;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*49+21)  = (uint64_t)IPW(ip, i*64+27) >> 21 | (uint64_t)IPX(ip, i*64+28) << 28;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*49+22)  = (uint64_t)IPW(ip, i*64+28) >> 36;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*49+22) |= (uint64_t)IPV(ip, i*64+29) << 13 | (uint64_t)IPX(ip, i*64+30) << 62;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*49+23)  = (uint64_t)IPW(ip, i*64+30) >>  2 | (uint64_t)IPX(ip, i*64+31) << 47;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*49+24)  = (uint64_t)IPW(ip, i*64+31) >> 17;\
}

#define BITPACK64_49(ip,  op, parm) { \
  BITBLK64_49(ip, 0, op, parm);  IPI(ip); op += 49*4/sizeof(op[0]);\
}

#define BITBLK64_50(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*25+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 50;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*25+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >> 14 | (uint64_t)IPX(ip, i*32+2) << 36;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*25+ 2)  = (uint64_t)IPW(ip, i*32+ 2) >> 28 | (uint64_t)IPX(ip, i*32+3) << 22;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*25+ 3)  = (uint64_t)IPW(ip, i*32+ 3) >> 42;\
  IP9(ip, i*32+ 4, parm); *((uint64_t *)op+i*25+ 3) |= (uint64_t)IPV(ip, i*32+ 4) <<  8 | (uint64_t)IPX(ip, i*32+5) << 58;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*25+ 4)  = (uint64_t)IPW(ip, i*32+ 5) >>  6 | (uint64_t)IPX(ip, i*32+6) << 44;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*25+ 5)  = (uint64_t)IPW(ip, i*32+ 6) >> 20 | (uint64_t)IPX(ip, i*32+7) << 30;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*25+ 6)  = (uint64_t)IPW(ip, i*32+ 7) >> 34 | (uint64_t)IPX(ip, i*32+8) << 16;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*25+ 7)  = (uint64_t)IPW(ip, i*32+ 8) >> 48;\
  IP9(ip, i*32+ 9, parm); *((uint64_t *)op+i*25+ 7) |= (uint64_t)IPV(ip, i*32+ 9) <<  2 | (uint64_t)IPX(ip, i*32+10) << 52;\
  IP64(ip, i*32+10, parm); *((uint64_t *)op+i*25+ 8)  = (uint64_t)IPW(ip, i*32+10) >> 12 | (uint64_t)IPX(ip, i*32+11) << 38;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*25+ 9)  = (uint64_t)IPW(ip, i*32+11) >> 26 | (uint64_t)IPX(ip, i*32+12) << 24;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*25+10)  = (uint64_t)IPW(ip, i*32+12) >> 40;\
  IP9(ip, i*32+13, parm); *((uint64_t *)op+i*25+10) |= (uint64_t)IPV(ip, i*32+13) << 10 | (uint64_t)IPX(ip, i*32+14) << 60;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*25+11)  = (uint64_t)IPW(ip, i*32+14) >>  4 | (uint64_t)IPX(ip, i*32+15) << 46;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*25+12)  = (uint64_t)IPW(ip, i*32+15) >> 18 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*25+13)  = (uint64_t)IPW(ip, i*32+16) >> 32 | (uint64_t)IPX(ip, i*32+17) << 18;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*25+14)  = (uint64_t)IPW(ip, i*32+17) >> 46;\
  IP9(ip, i*32+18, parm); *((uint64_t *)op+i*25+14) |= (uint64_t)IPV(ip, i*32+18) <<  4 | (uint64_t)IPX(ip, i*32+19) << 54;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*25+15)  = (uint64_t)IPW(ip, i*32+19) >> 10 | (uint64_t)IPX(ip, i*32+20) << 40;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*25+16)  = (uint64_t)IPW(ip, i*32+20) >> 24 | (uint64_t)IPX(ip, i*32+21) << 26;\
  IP64(ip, i*32+21, parm); *((uint64_t *)op+i*25+17)  = (uint64_t)IPW(ip, i*32+21) >> 38;\
  IP9(ip, i*32+22, parm); *((uint64_t *)op+i*25+17) |= (uint64_t)IPV(ip, i*32+22) << 12 | (uint64_t)IPX(ip, i*32+23) << 62;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*25+18)  = (uint64_t)IPW(ip, i*32+23) >>  2 | (uint64_t)IPX(ip, i*32+24) << 48;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*25+19)  = (uint64_t)IPW(ip, i*32+24) >> 16 | (uint64_t)IPX(ip, i*32+25) << 34;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*25+20)  = (uint64_t)IPW(ip, i*32+25) >> 30 | (uint64_t)IPX(ip, i*32+26) << 20;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*25+21)  = (uint64_t)IPW(ip, i*32+26) >> 44;\
  IP9(ip, i*32+27, parm); *((uint64_t *)op+i*25+21) |= (uint64_t)IPV(ip, i*32+27) <<  6 | (uint64_t)IPX(ip, i*32+28) << 56;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*25+22)  = (uint64_t)IPW(ip, i*32+28) >>  8 | (uint64_t)IPX(ip, i*32+29) << 42;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*25+23)  = (uint64_t)IPW(ip, i*32+29) >> 22 | (uint64_t)IPX(ip, i*32+30) << 28;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*25+24)  = (uint64_t)IPW(ip, i*32+30) >> 36;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*25+24) |= (uint64_t)IPV(ip, i*32+31) << 14;\
}

#define BITPACK64_50(ip,  op, parm) { \
  BITBLK64_50(ip, 0, op, parm);  IPI(ip); op += 50*4/sizeof(op[0]);\
}

#define BITBLK64_51(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*51+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 51;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*51+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 13 | (uint64_t)IPX(ip, i*64+2) << 38;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*51+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 26 | (uint64_t)IPX(ip, i*64+3) << 25;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*51+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >> 39;\
  IP9(ip, i*64+ 4, parm); *((uint64_t *)op+i*51+ 3) |= (uint64_t)IPV(ip, i*64+ 4) << 12 | (uint64_t)IPX(ip, i*64+5) << 63;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*51+ 4)  = (uint64_t)IPW(ip, i*64+ 5) >>  1 | (uint64_t)IPX(ip, i*64+6) << 50;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*51+ 5)  = (uint64_t)IPW(ip, i*64+ 6) >> 14 | (uint64_t)IPX(ip, i*64+7) << 37;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*51+ 6)  = (uint64_t)IPW(ip, i*64+ 7) >> 27 | (uint64_t)IPX(ip, i*64+8) << 24;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*51+ 7)  = (uint64_t)IPW(ip, i*64+ 8) >> 40;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*51+ 7) |= (uint64_t)IPV(ip, i*64+ 9) << 11 | (uint64_t)IPX(ip, i*64+10) << 62;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*51+ 8)  = (uint64_t)IPW(ip, i*64+10) >>  2 | (uint64_t)IPX(ip, i*64+11) << 49;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*51+ 9)  = (uint64_t)IPW(ip, i*64+11) >> 15 | (uint64_t)IPX(ip, i*64+12) << 36;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*51+10)  = (uint64_t)IPW(ip, i*64+12) >> 28 | (uint64_t)IPX(ip, i*64+13) << 23;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*51+11)  = (uint64_t)IPW(ip, i*64+13) >> 41;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*51+11) |= (uint64_t)IPV(ip, i*64+14) << 10 | (uint64_t)IPX(ip, i*64+15) << 61;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*51+12)  = (uint64_t)IPW(ip, i*64+15) >>  3 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*51+13)  = (uint64_t)IPW(ip, i*64+16) >> 16 | (uint64_t)IPX(ip, i*64+17) << 35;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*51+14)  = (uint64_t)IPW(ip, i*64+17) >> 29 | (uint64_t)IPX(ip, i*64+18) << 22;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*51+15)  = (uint64_t)IPW(ip, i*64+18) >> 42;\
  IP9(ip, i*64+19, parm); *((uint64_t *)op+i*51+15) |= (uint64_t)IPV(ip, i*64+19) <<  9 | (uint64_t)IPX(ip, i*64+20) << 60;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*51+16)  = (uint64_t)IPW(ip, i*64+20) >>  4 | (uint64_t)IPX(ip, i*64+21) << 47;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*51+17)  = (uint64_t)IPW(ip, i*64+21) >> 17 | (uint64_t)IPX(ip, i*64+22) << 34;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*51+18)  = (uint64_t)IPW(ip, i*64+22) >> 30 | (uint64_t)IPX(ip, i*64+23) << 21;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*51+19)  = (uint64_t)IPW(ip, i*64+23) >> 43;\
  IP9(ip, i*64+24, parm); *((uint64_t *)op+i*51+19) |= (uint64_t)IPV(ip, i*64+24) <<  8 | (uint64_t)IPX(ip, i*64+25) << 59;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*51+20)  = (uint64_t)IPW(ip, i*64+25) >>  5 | (uint64_t)IPX(ip, i*64+26) << 46;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*51+21)  = (uint64_t)IPW(ip, i*64+26) >> 18 | (uint64_t)IPX(ip, i*64+27) << 33;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*51+22)  = (uint64_t)IPW(ip, i*64+27) >> 31 | (uint64_t)IPX(ip, i*64+28) << 20;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*51+23)  = (uint64_t)IPW(ip, i*64+28) >> 44;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*51+23) |= (uint64_t)IPV(ip, i*64+29) <<  7 | (uint64_t)IPX(ip, i*64+30) << 58;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*51+24)  = (uint64_t)IPW(ip, i*64+30) >>  6 | (uint64_t)IPX(ip, i*64+31) << 45;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*51+25)  = (uint64_t)IPW(ip, i*64+31) >> 19;\
}

#define BITPACK64_51(ip,  op, parm) { \
  BITBLK64_51(ip, 0, op, parm);  IPI(ip); op += 51*4/sizeof(op[0]);\
}

#define BITBLK64_52(ip, i, op, parm) { ;\
  IP9(ip, i*16+ 0, parm); *((uint64_t *)op+i*13+ 0)  = (uint64_t)IPV(ip, i*16+ 0)       | (uint64_t)IPX(ip, i*16+1) << 52;\
  IP64(ip, i*16+ 1, parm); *((uint64_t *)op+i*13+ 1)  = (uint64_t)IPW(ip, i*16+ 1) >> 12 | (uint64_t)IPX(ip, i*16+2) << 40;\
  IP64(ip, i*16+ 2, parm); *((uint64_t *)op+i*13+ 2)  = (uint64_t)IPW(ip, i*16+ 2) >> 24 | (uint64_t)IPX(ip, i*16+3) << 28;\
  IP64(ip, i*16+ 3, parm); *((uint64_t *)op+i*13+ 3)  = (uint64_t)IPW(ip, i*16+ 3) >> 36 | (uint64_t)IPX(ip, i*16+4) << 16;\
  IP64(ip, i*16+ 4, parm); *((uint64_t *)op+i*13+ 4)  = (uint64_t)IPW(ip, i*16+ 4) >> 48;\
  IP9(ip, i*16+ 5, parm); *((uint64_t *)op+i*13+ 4) |= (uint64_t)IPV(ip, i*16+ 5) <<  4 | (uint64_t)IPX(ip, i*16+6) << 56;\
  IP64(ip, i*16+ 6, parm); *((uint64_t *)op+i*13+ 5)  = (uint64_t)IPW(ip, i*16+ 6) >>  8 | (uint64_t)IPX(ip, i*16+7) << 44;\
  IP64(ip, i*16+ 7, parm); *((uint64_t *)op+i*13+ 6)  = (uint64_t)IPW(ip, i*16+ 7) >> 20 | (uint64_t)IPX(ip, i*16+8) << 32;\
  IP64(ip, i*16+ 8, parm); *((uint64_t *)op+i*13+ 7)  = (uint64_t)IPW(ip, i*16+ 8) >> 32 | (uint64_t)IPX(ip, i*16+9) << 20;\
  IP64(ip, i*16+ 9, parm); *((uint64_t *)op+i*13+ 8)  = (uint64_t)IPW(ip, i*16+ 9) >> 44;\
  IP9(ip, i*16+10, parm); *((uint64_t *)op+i*13+ 8) |= (uint64_t)IPV(ip, i*16+10) <<  8 | (uint64_t)IPX(ip, i*16+11) << 60;\
  IP64(ip, i*16+11, parm); *((uint64_t *)op+i*13+ 9)  = (uint64_t)IPW(ip, i*16+11) >>  4 | (uint64_t)IPX(ip, i*16+12) << 48;\
  IP64(ip, i*16+12, parm); *((uint64_t *)op+i*13+10)  = (uint64_t)IPW(ip, i*16+12) >> 16 | (uint64_t)IPX(ip, i*16+13) << 36;\
  IP64(ip, i*16+13, parm); *((uint64_t *)op+i*13+11)  = (uint64_t)IPW(ip, i*16+13) >> 28 | (uint64_t)IPX(ip, i*16+14) << 24;\
  IP64(ip, i*16+14, parm); *((uint64_t *)op+i*13+12)  = (uint64_t)IPW(ip, i*16+14) >> 40;\
  IP9(ip, i*16+15, parm); *((uint64_t *)op+i*13+12) |= (uint64_t)IPV(ip, i*16+15) << 12;\
}

#define BITPACK64_52(ip,  op, parm) { \
  BITBLK64_52(ip, 0, op, parm);\
  BITBLK64_52(ip, 1, op, parm);  IPI(ip); op += 52*4/sizeof(op[0]);\
}

#define BITBLK64_53(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*53+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 53;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*53+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >> 11 | (uint64_t)IPX(ip, i*64+2) << 42;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*53+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 22 | (uint64_t)IPX(ip, i*64+3) << 31;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*53+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >> 33 | (uint64_t)IPX(ip, i*64+4) << 20;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*53+ 4)  = (uint64_t)IPW(ip, i*64+ 4) >> 44;\
  IP9(ip, i*64+ 5, parm); *((uint64_t *)op+i*53+ 4) |= (uint64_t)IPV(ip, i*64+ 5) <<  9 | (uint64_t)IPX(ip, i*64+6) << 62;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*53+ 5)  = (uint64_t)IPW(ip, i*64+ 6) >>  2 | (uint64_t)IPX(ip, i*64+7) << 51;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*53+ 6)  = (uint64_t)IPW(ip, i*64+ 7) >> 13 | (uint64_t)IPX(ip, i*64+8) << 40;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*53+ 7)  = (uint64_t)IPW(ip, i*64+ 8) >> 24 | (uint64_t)IPX(ip, i*64+9) << 29;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*53+ 8)  = (uint64_t)IPW(ip, i*64+ 9) >> 35 | (uint64_t)IPX(ip, i*64+10) << 18;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*53+ 9)  = (uint64_t)IPW(ip, i*64+10) >> 46;\
  IP9(ip, i*64+11, parm); *((uint64_t *)op+i*53+ 9) |= (uint64_t)IPV(ip, i*64+11) <<  7 | (uint64_t)IPX(ip, i*64+12) << 60;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*53+10)  = (uint64_t)IPW(ip, i*64+12) >>  4 | (uint64_t)IPX(ip, i*64+13) << 49;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*53+11)  = (uint64_t)IPW(ip, i*64+13) >> 15 | (uint64_t)IPX(ip, i*64+14) << 38;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*53+12)  = (uint64_t)IPW(ip, i*64+14) >> 26 | (uint64_t)IPX(ip, i*64+15) << 27;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*53+13)  = (uint64_t)IPW(ip, i*64+15) >> 37 | (uint64_t)IPX(ip, i*64+16) << 16;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*53+14)  = (uint64_t)IPW(ip, i*64+16) >> 48;\
  IP9(ip, i*64+17, parm); *((uint64_t *)op+i*53+14) |= (uint64_t)IPV(ip, i*64+17) <<  5 | (uint64_t)IPX(ip, i*64+18) << 58;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*53+15)  = (uint64_t)IPW(ip, i*64+18) >>  6 | (uint64_t)IPX(ip, i*64+19) << 47;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*53+16)  = (uint64_t)IPW(ip, i*64+19) >> 17 | (uint64_t)IPX(ip, i*64+20) << 36;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*53+17)  = (uint64_t)IPW(ip, i*64+20) >> 28 | (uint64_t)IPX(ip, i*64+21) << 25;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*53+18)  = (uint64_t)IPW(ip, i*64+21) >> 39 | (uint64_t)IPX(ip, i*64+22) << 14;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*53+19)  = (uint64_t)IPW(ip, i*64+22) >> 50;\
  IP9(ip, i*64+23, parm); *((uint64_t *)op+i*53+19) |= (uint64_t)IPV(ip, i*64+23) <<  3 | (uint64_t)IPX(ip, i*64+24) << 56;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*53+20)  = (uint64_t)IPW(ip, i*64+24) >>  8 | (uint64_t)IPX(ip, i*64+25) << 45;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*53+21)  = (uint64_t)IPW(ip, i*64+25) >> 19 | (uint64_t)IPX(ip, i*64+26) << 34;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*53+22)  = (uint64_t)IPW(ip, i*64+26) >> 30 | (uint64_t)IPX(ip, i*64+27) << 23;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*53+23)  = (uint64_t)IPW(ip, i*64+27) >> 41 | (uint64_t)IPX(ip, i*64+28) << 12;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*53+24)  = (uint64_t)IPW(ip, i*64+28) >> 52;\
  IP9(ip, i*64+29, parm); *((uint64_t *)op+i*53+24) |= (uint64_t)IPV(ip, i*64+29) <<  1 | (uint64_t)IPX(ip, i*64+30) << 54;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*53+25)  = (uint64_t)IPW(ip, i*64+30) >> 10 | (uint64_t)IPX(ip, i*64+31) << 43;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*53+26)  = (uint64_t)IPW(ip, i*64+31) >> 21;\
}

#define BITPACK64_53(ip,  op, parm) { \
  BITBLK64_53(ip, 0, op, parm);  IPI(ip); op += 53*4/sizeof(op[0]);\
}

#define BITBLK64_54(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*27+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 54;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*27+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >> 10 | (uint64_t)IPX(ip, i*32+2) << 44;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*27+ 2)  = (uint64_t)IPW(ip, i*32+ 2) >> 20 | (uint64_t)IPX(ip, i*32+3) << 34;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*27+ 3)  = (uint64_t)IPW(ip, i*32+ 3) >> 30 | (uint64_t)IPX(ip, i*32+4) << 24;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*27+ 4)  = (uint64_t)IPW(ip, i*32+ 4) >> 40 | (uint64_t)IPX(ip, i*32+5) << 14;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*27+ 5)  = (uint64_t)IPW(ip, i*32+ 5) >> 50;\
  IP9(ip, i*32+ 6, parm); *((uint64_t *)op+i*27+ 5) |= (uint64_t)IPV(ip, i*32+ 6) <<  4 | (uint64_t)IPX(ip, i*32+7) << 58;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*27+ 6)  = (uint64_t)IPW(ip, i*32+ 7) >>  6 | (uint64_t)IPX(ip, i*32+8) << 48;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*27+ 7)  = (uint64_t)IPW(ip, i*32+ 8) >> 16 | (uint64_t)IPX(ip, i*32+9) << 38;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*27+ 8)  = (uint64_t)IPW(ip, i*32+ 9) >> 26 | (uint64_t)IPX(ip, i*32+10) << 28;\
  IP64(ip, i*32+10, parm); *((uint64_t *)op+i*27+ 9)  = (uint64_t)IPW(ip, i*32+10) >> 36 | (uint64_t)IPX(ip, i*32+11) << 18;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*27+10)  = (uint64_t)IPW(ip, i*32+11) >> 46;\
  IP9(ip, i*32+12, parm); *((uint64_t *)op+i*27+10) |= (uint64_t)IPV(ip, i*32+12) <<  8 | (uint64_t)IPX(ip, i*32+13) << 62;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*27+11)  = (uint64_t)IPW(ip, i*32+13) >>  2 | (uint64_t)IPX(ip, i*32+14) << 52;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*27+12)  = (uint64_t)IPW(ip, i*32+14) >> 12 | (uint64_t)IPX(ip, i*32+15) << 42;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*27+13)  = (uint64_t)IPW(ip, i*32+15) >> 22 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*27+14)  = (uint64_t)IPW(ip, i*32+16) >> 32 | (uint64_t)IPX(ip, i*32+17) << 22;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*27+15)  = (uint64_t)IPW(ip, i*32+17) >> 42 | (uint64_t)IPX(ip, i*32+18) << 12;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*27+16)  = (uint64_t)IPW(ip, i*32+18) >> 52;\
  IP9(ip, i*32+19, parm); *((uint64_t *)op+i*27+16) |= (uint64_t)IPV(ip, i*32+19) <<  2 | (uint64_t)IPX(ip, i*32+20) << 56;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*27+17)  = (uint64_t)IPW(ip, i*32+20) >>  8 | (uint64_t)IPX(ip, i*32+21) << 46;\
  IP64(ip, i*32+21, parm); *((uint64_t *)op+i*27+18)  = (uint64_t)IPW(ip, i*32+21) >> 18 | (uint64_t)IPX(ip, i*32+22) << 36;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*27+19)  = (uint64_t)IPW(ip, i*32+22) >> 28 | (uint64_t)IPX(ip, i*32+23) << 26;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*27+20)  = (uint64_t)IPW(ip, i*32+23) >> 38 | (uint64_t)IPX(ip, i*32+24) << 16;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*27+21)  = (uint64_t)IPW(ip, i*32+24) >> 48;\
  IP9(ip, i*32+25, parm); *((uint64_t *)op+i*27+21) |= (uint64_t)IPV(ip, i*32+25) <<  6 | (uint64_t)IPX(ip, i*32+26) << 60;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*27+22)  = (uint64_t)IPW(ip, i*32+26) >>  4 | (uint64_t)IPX(ip, i*32+27) << 50;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*27+23)  = (uint64_t)IPW(ip, i*32+27) >> 14 | (uint64_t)IPX(ip, i*32+28) << 40;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*27+24)  = (uint64_t)IPW(ip, i*32+28) >> 24 | (uint64_t)IPX(ip, i*32+29) << 30;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*27+25)  = (uint64_t)IPW(ip, i*32+29) >> 34 | (uint64_t)IPX(ip, i*32+30) << 20;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*27+26)  = (uint64_t)IPW(ip, i*32+30) >> 44;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*27+26) |= (uint64_t)IPV(ip, i*32+31) << 10;\
}

#define BITPACK64_54(ip,  op, parm) { \
  BITBLK64_54(ip, 0, op, parm);  IPI(ip); op += 54*4/sizeof(op[0]);\
}

#define BITBLK64_55(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*55+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 55;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*55+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >>  9 | (uint64_t)IPX(ip, i*64+2) << 46;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*55+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 18 | (uint64_t)IPX(ip, i*64+3) << 37;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*55+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >> 27 | (uint64_t)IPX(ip, i*64+4) << 28;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*55+ 4)  = (uint64_t)IPW(ip, i*64+ 4) >> 36 | (uint64_t)IPX(ip, i*64+5) << 19;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*55+ 5)  = (uint64_t)IPW(ip, i*64+ 5) >> 45 | (uint64_t)IPX(ip, i*64+6) << 10;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*55+ 6)  = (uint64_t)IPW(ip, i*64+ 6) >> 54;\
  IP9(ip, i*64+ 7, parm); *((uint64_t *)op+i*55+ 6) |= (uint64_t)IPV(ip, i*64+ 7) <<  1 | (uint64_t)IPX(ip, i*64+8) << 56;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*55+ 7)  = (uint64_t)IPW(ip, i*64+ 8) >>  8 | (uint64_t)IPX(ip, i*64+9) << 47;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*55+ 8)  = (uint64_t)IPW(ip, i*64+ 9) >> 17 | (uint64_t)IPX(ip, i*64+10) << 38;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*55+ 9)  = (uint64_t)IPW(ip, i*64+10) >> 26 | (uint64_t)IPX(ip, i*64+11) << 29;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*55+10)  = (uint64_t)IPW(ip, i*64+11) >> 35 | (uint64_t)IPX(ip, i*64+12) << 20;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*55+11)  = (uint64_t)IPW(ip, i*64+12) >> 44 | (uint64_t)IPX(ip, i*64+13) << 11;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*55+12)  = (uint64_t)IPW(ip, i*64+13) >> 53;\
  IP9(ip, i*64+14, parm); *((uint64_t *)op+i*55+12) |= (uint64_t)IPV(ip, i*64+14) <<  2 | (uint64_t)IPX(ip, i*64+15) << 57;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*55+13)  = (uint64_t)IPW(ip, i*64+15) >>  7 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*55+14)  = (uint64_t)IPW(ip, i*64+16) >> 16 | (uint64_t)IPX(ip, i*64+17) << 39;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*55+15)  = (uint64_t)IPW(ip, i*64+17) >> 25 | (uint64_t)IPX(ip, i*64+18) << 30;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*55+16)  = (uint64_t)IPW(ip, i*64+18) >> 34 | (uint64_t)IPX(ip, i*64+19) << 21;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*55+17)  = (uint64_t)IPW(ip, i*64+19) >> 43 | (uint64_t)IPX(ip, i*64+20) << 12;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*55+18)  = (uint64_t)IPW(ip, i*64+20) >> 52;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*55+18) |= (uint64_t)IPV(ip, i*64+21) <<  3 | (uint64_t)IPX(ip, i*64+22) << 58;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*55+19)  = (uint64_t)IPW(ip, i*64+22) >>  6 | (uint64_t)IPX(ip, i*64+23) << 49;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*55+20)  = (uint64_t)IPW(ip, i*64+23) >> 15 | (uint64_t)IPX(ip, i*64+24) << 40;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*55+21)  = (uint64_t)IPW(ip, i*64+24) >> 24 | (uint64_t)IPX(ip, i*64+25) << 31;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*55+22)  = (uint64_t)IPW(ip, i*64+25) >> 33 | (uint64_t)IPX(ip, i*64+26) << 22;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*55+23)  = (uint64_t)IPW(ip, i*64+26) >> 42 | (uint64_t)IPX(ip, i*64+27) << 13;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*55+24)  = (uint64_t)IPW(ip, i*64+27) >> 51;\
  IP9(ip, i*64+28, parm); *((uint64_t *)op+i*55+24) |= (uint64_t)IPV(ip, i*64+28) <<  4 | (uint64_t)IPX(ip, i*64+29) << 59;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*55+25)  = (uint64_t)IPW(ip, i*64+29) >>  5 | (uint64_t)IPX(ip, i*64+30) << 50;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*55+26)  = (uint64_t)IPW(ip, i*64+30) >> 14 | (uint64_t)IPX(ip, i*64+31) << 41;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*55+27)  = (uint64_t)IPW(ip, i*64+31) >> 23;\
}

#define BITPACK64_55(ip,  op, parm) { \
  BITBLK64_55(ip, 0, op, parm);  IPI(ip); op += 55*4/sizeof(op[0]);\
}

#define BITBLK64_56(ip, i, op, parm) { ;\
  IP9(ip, i*8+ 0, parm); *((uint64_t *)op+i*7+ 0)  = (uint64_t)IPV(ip, i*8+ 0)       | (uint64_t)IPX(ip, i*8+1) << 56;\
  IP64(ip, i*8+ 1, parm); *((uint64_t *)op+i*7+ 1)  = (uint64_t)IPW(ip, i*8+ 1) >>  8 | (uint64_t)IPX(ip, i*8+2) << 48;\
  IP64(ip, i*8+ 2, parm); *((uint64_t *)op+i*7+ 2)  = (uint64_t)IPW(ip, i*8+ 2) >> 16 | (uint64_t)IPX(ip, i*8+3) << 40;\
  IP64(ip, i*8+ 3, parm); *((uint64_t *)op+i*7+ 3)  = (uint64_t)IPW(ip, i*8+ 3) >> 24 | (uint64_t)IPX(ip, i*8+4) << 32;\
  IP64(ip, i*8+ 4, parm); *((uint64_t *)op+i*7+ 4)  = (uint64_t)IPW(ip, i*8+ 4) >> 32 | (uint64_t)IPX(ip, i*8+5) << 24;\
  IP64(ip, i*8+ 5, parm); *((uint64_t *)op+i*7+ 5)  = (uint64_t)IPW(ip, i*8+ 5) >> 40 | (uint64_t)IPX(ip, i*8+6) << 16;\
  IP64(ip, i*8+ 6, parm); *((uint64_t *)op+i*7+ 6)  = (uint64_t)IPW(ip, i*8+ 6) >> 48;\
  IP9(ip, i*8+ 7, parm); *((uint64_t *)op+i*7+ 6) |= (uint64_t)IPV(ip, i*8+ 7) <<  8;\
}

#define BITPACK64_56(ip,  op, parm) { \
  BITBLK64_56(ip, 0, op, parm);\
  BITBLK64_56(ip, 1, op, parm);\
  BITBLK64_56(ip, 2, op, parm);\
  BITBLK64_56(ip, 3, op, parm);  IPI(ip); op += 56*4/sizeof(op[0]);\
}

#define BITBLK64_57(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*57+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 57;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*57+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >>  7 | (uint64_t)IPX(ip, i*64+2) << 50;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*57+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 14 | (uint64_t)IPX(ip, i*64+3) << 43;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*57+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >> 21 | (uint64_t)IPX(ip, i*64+4) << 36;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*57+ 4)  = (uint64_t)IPW(ip, i*64+ 4) >> 28 | (uint64_t)IPX(ip, i*64+5) << 29;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*57+ 5)  = (uint64_t)IPW(ip, i*64+ 5) >> 35 | (uint64_t)IPX(ip, i*64+6) << 22;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*57+ 6)  = (uint64_t)IPW(ip, i*64+ 6) >> 42 | (uint64_t)IPX(ip, i*64+7) << 15;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*57+ 7)  = (uint64_t)IPW(ip, i*64+ 7) >> 49 | (uint64_t)IPX(ip, i*64+8) <<  8;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*57+ 8)  = (uint64_t)IPW(ip, i*64+ 8) >> 56;\
  IP9(ip, i*64+ 9, parm); *((uint64_t *)op+i*57+ 8) |= (uint64_t)IPV(ip, i*64+ 9) <<  1 | (uint64_t)IPX(ip, i*64+10) << 58;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*57+ 9)  = (uint64_t)IPW(ip, i*64+10) >>  6 | (uint64_t)IPX(ip, i*64+11) << 51;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*57+10)  = (uint64_t)IPW(ip, i*64+11) >> 13 | (uint64_t)IPX(ip, i*64+12) << 44;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*57+11)  = (uint64_t)IPW(ip, i*64+12) >> 20 | (uint64_t)IPX(ip, i*64+13) << 37;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*57+12)  = (uint64_t)IPW(ip, i*64+13) >> 27 | (uint64_t)IPX(ip, i*64+14) << 30;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*57+13)  = (uint64_t)IPW(ip, i*64+14) >> 34 | (uint64_t)IPX(ip, i*64+15) << 23;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*57+14)  = (uint64_t)IPW(ip, i*64+15) >> 41 | (uint64_t)IPX(ip, i*64+16) << 16;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*57+15)  = (uint64_t)IPW(ip, i*64+16) >> 48 | (uint64_t)IPX(ip, i*64+17) <<  9;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*57+16)  = (uint64_t)IPW(ip, i*64+17) >> 55;\
  IP9(ip, i*64+18, parm); *((uint64_t *)op+i*57+16) |= (uint64_t)IPV(ip, i*64+18) <<  2 | (uint64_t)IPX(ip, i*64+19) << 59;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*57+17)  = (uint64_t)IPW(ip, i*64+19) >>  5 | (uint64_t)IPX(ip, i*64+20) << 52;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*57+18)  = (uint64_t)IPW(ip, i*64+20) >> 12 | (uint64_t)IPX(ip, i*64+21) << 45;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*57+19)  = (uint64_t)IPW(ip, i*64+21) >> 19 | (uint64_t)IPX(ip, i*64+22) << 38;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*57+20)  = (uint64_t)IPW(ip, i*64+22) >> 26 | (uint64_t)IPX(ip, i*64+23) << 31;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*57+21)  = (uint64_t)IPW(ip, i*64+23) >> 33 | (uint64_t)IPX(ip, i*64+24) << 24;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*57+22)  = (uint64_t)IPW(ip, i*64+24) >> 40 | (uint64_t)IPX(ip, i*64+25) << 17;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*57+23)  = (uint64_t)IPW(ip, i*64+25) >> 47 | (uint64_t)IPX(ip, i*64+26) << 10;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*57+24)  = (uint64_t)IPW(ip, i*64+26) >> 54;\
  IP9(ip, i*64+27, parm); *((uint64_t *)op+i*57+24) |= (uint64_t)IPV(ip, i*64+27) <<  3 | (uint64_t)IPX(ip, i*64+28) << 60;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*57+25)  = (uint64_t)IPW(ip, i*64+28) >>  4 | (uint64_t)IPX(ip, i*64+29) << 53;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*57+26)  = (uint64_t)IPW(ip, i*64+29) >> 11 | (uint64_t)IPX(ip, i*64+30) << 46;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*57+27)  = (uint64_t)IPW(ip, i*64+30) >> 18 | (uint64_t)IPX(ip, i*64+31) << 39;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*57+28)  = (uint64_t)IPW(ip, i*64+31) >> 25;\
}

#define BITPACK64_57(ip,  op, parm) { \
  BITBLK64_57(ip, 0, op, parm);  IPI(ip); op += 57*4/sizeof(op[0]);\
}

#define BITBLK64_58(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*29+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 58;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*29+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >>  6 | (uint64_t)IPX(ip, i*32+2) << 52;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*29+ 2)  = (uint64_t)IPW(ip, i*32+ 2) >> 12 | (uint64_t)IPX(ip, i*32+3) << 46;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*29+ 3)  = (uint64_t)IPW(ip, i*32+ 3) >> 18 | (uint64_t)IPX(ip, i*32+4) << 40;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*29+ 4)  = (uint64_t)IPW(ip, i*32+ 4) >> 24 | (uint64_t)IPX(ip, i*32+5) << 34;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*29+ 5)  = (uint64_t)IPW(ip, i*32+ 5) >> 30 | (uint64_t)IPX(ip, i*32+6) << 28;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*29+ 6)  = (uint64_t)IPW(ip, i*32+ 6) >> 36 | (uint64_t)IPX(ip, i*32+7) << 22;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*29+ 7)  = (uint64_t)IPW(ip, i*32+ 7) >> 42 | (uint64_t)IPX(ip, i*32+8) << 16;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*29+ 8)  = (uint64_t)IPW(ip, i*32+ 8) >> 48 | (uint64_t)IPX(ip, i*32+9) << 10;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*29+ 9)  = (uint64_t)IPW(ip, i*32+ 9) >> 54;\
  IP9(ip, i*32+10, parm); *((uint64_t *)op+i*29+ 9) |= (uint64_t)IPV(ip, i*32+10) <<  4 | (uint64_t)IPX(ip, i*32+11) << 62;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*29+10)  = (uint64_t)IPW(ip, i*32+11) >>  2 | (uint64_t)IPX(ip, i*32+12) << 56;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*29+11)  = (uint64_t)IPW(ip, i*32+12) >>  8 | (uint64_t)IPX(ip, i*32+13) << 50;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*29+12)  = (uint64_t)IPW(ip, i*32+13) >> 14 | (uint64_t)IPX(ip, i*32+14) << 44;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*29+13)  = (uint64_t)IPW(ip, i*32+14) >> 20 | (uint64_t)IPX(ip, i*32+15) << 38;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*29+14)  = (uint64_t)IPW(ip, i*32+15) >> 26 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*29+15)  = (uint64_t)IPW(ip, i*32+16) >> 32 | (uint64_t)IPX(ip, i*32+17) << 26;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*29+16)  = (uint64_t)IPW(ip, i*32+17) >> 38 | (uint64_t)IPX(ip, i*32+18) << 20;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*29+17)  = (uint64_t)IPW(ip, i*32+18) >> 44 | (uint64_t)IPX(ip, i*32+19) << 14;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*29+18)  = (uint64_t)IPW(ip, i*32+19) >> 50 | (uint64_t)IPX(ip, i*32+20) <<  8;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*29+19)  = (uint64_t)IPW(ip, i*32+20) >> 56;\
  IP9(ip, i*32+21, parm); *((uint64_t *)op+i*29+19) |= (uint64_t)IPV(ip, i*32+21) <<  2 | (uint64_t)IPX(ip, i*32+22) << 60;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*29+20)  = (uint64_t)IPW(ip, i*32+22) >>  4 | (uint64_t)IPX(ip, i*32+23) << 54;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*29+21)  = (uint64_t)IPW(ip, i*32+23) >> 10 | (uint64_t)IPX(ip, i*32+24) << 48;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*29+22)  = (uint64_t)IPW(ip, i*32+24) >> 16 | (uint64_t)IPX(ip, i*32+25) << 42;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*29+23)  = (uint64_t)IPW(ip, i*32+25) >> 22 | (uint64_t)IPX(ip, i*32+26) << 36;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*29+24)  = (uint64_t)IPW(ip, i*32+26) >> 28 | (uint64_t)IPX(ip, i*32+27) << 30;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*29+25)  = (uint64_t)IPW(ip, i*32+27) >> 34 | (uint64_t)IPX(ip, i*32+28) << 24;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*29+26)  = (uint64_t)IPW(ip, i*32+28) >> 40 | (uint64_t)IPX(ip, i*32+29) << 18;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*29+27)  = (uint64_t)IPW(ip, i*32+29) >> 46 | (uint64_t)IPX(ip, i*32+30) << 12;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*29+28)  = (uint64_t)IPW(ip, i*32+30) >> 52;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*29+28) |= (uint64_t)IPV(ip, i*32+31) <<  6;\
}

#define BITPACK64_58(ip,  op, parm) { \
  BITBLK64_58(ip, 0, op, parm);  IPI(ip); op += 58*4/sizeof(op[0]);\
}

#define BITBLK64_59(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*59+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 59;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*59+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >>  5 | (uint64_t)IPX(ip, i*64+2) << 54;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*59+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >> 10 | (uint64_t)IPX(ip, i*64+3) << 49;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*59+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >> 15 | (uint64_t)IPX(ip, i*64+4) << 44;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*59+ 4)  = (uint64_t)IPW(ip, i*64+ 4) >> 20 | (uint64_t)IPX(ip, i*64+5) << 39;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*59+ 5)  = (uint64_t)IPW(ip, i*64+ 5) >> 25 | (uint64_t)IPX(ip, i*64+6) << 34;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*59+ 6)  = (uint64_t)IPW(ip, i*64+ 6) >> 30 | (uint64_t)IPX(ip, i*64+7) << 29;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*59+ 7)  = (uint64_t)IPW(ip, i*64+ 7) >> 35 | (uint64_t)IPX(ip, i*64+8) << 24;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*59+ 8)  = (uint64_t)IPW(ip, i*64+ 8) >> 40 | (uint64_t)IPX(ip, i*64+9) << 19;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*59+ 9)  = (uint64_t)IPW(ip, i*64+ 9) >> 45 | (uint64_t)IPX(ip, i*64+10) << 14;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*59+10)  = (uint64_t)IPW(ip, i*64+10) >> 50 | (uint64_t)IPX(ip, i*64+11) <<  9;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*59+11)  = (uint64_t)IPW(ip, i*64+11) >> 55;\
  IP9(ip, i*64+12, parm); *((uint64_t *)op+i*59+11) |= (uint64_t)IPV(ip, i*64+12) <<  4 | (uint64_t)IPX(ip, i*64+13) << 63;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*59+12)  = (uint64_t)IPW(ip, i*64+13) >>  1 | (uint64_t)IPX(ip, i*64+14) << 58;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*59+13)  = (uint64_t)IPW(ip, i*64+14) >>  6 | (uint64_t)IPX(ip, i*64+15) << 53;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*59+14)  = (uint64_t)IPW(ip, i*64+15) >> 11 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*59+15)  = (uint64_t)IPW(ip, i*64+16) >> 16 | (uint64_t)IPX(ip, i*64+17) << 43;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*59+16)  = (uint64_t)IPW(ip, i*64+17) >> 21 | (uint64_t)IPX(ip, i*64+18) << 38;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*59+17)  = (uint64_t)IPW(ip, i*64+18) >> 26 | (uint64_t)IPX(ip, i*64+19) << 33;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*59+18)  = (uint64_t)IPW(ip, i*64+19) >> 31 | (uint64_t)IPX(ip, i*64+20) << 28;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*59+19)  = (uint64_t)IPW(ip, i*64+20) >> 36 | (uint64_t)IPX(ip, i*64+21) << 23;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*59+20)  = (uint64_t)IPW(ip, i*64+21) >> 41 | (uint64_t)IPX(ip, i*64+22) << 18;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*59+21)  = (uint64_t)IPW(ip, i*64+22) >> 46 | (uint64_t)IPX(ip, i*64+23) << 13;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*59+22)  = (uint64_t)IPW(ip, i*64+23) >> 51 | (uint64_t)IPX(ip, i*64+24) <<  8;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*59+23)  = (uint64_t)IPW(ip, i*64+24) >> 56;\
  IP9(ip, i*64+25, parm); *((uint64_t *)op+i*59+23) |= (uint64_t)IPV(ip, i*64+25) <<  3 | (uint64_t)IPX(ip, i*64+26) << 62;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*59+24)  = (uint64_t)IPW(ip, i*64+26) >>  2 | (uint64_t)IPX(ip, i*64+27) << 57;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*59+25)  = (uint64_t)IPW(ip, i*64+27) >>  7 | (uint64_t)IPX(ip, i*64+28) << 52;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*59+26)  = (uint64_t)IPW(ip, i*64+28) >> 12 | (uint64_t)IPX(ip, i*64+29) << 47;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*59+27)  = (uint64_t)IPW(ip, i*64+29) >> 17 | (uint64_t)IPX(ip, i*64+30) << 42;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*59+28)  = (uint64_t)IPW(ip, i*64+30) >> 22 | (uint64_t)IPX(ip, i*64+31) << 37;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*59+29)  = (uint64_t)IPW(ip, i*64+31) >> 27;\
}

#define BITPACK64_59(ip,  op, parm) { \
  BITBLK64_59(ip, 0, op, parm);  IPI(ip); op += 59*4/sizeof(op[0]);\
}

#define BITBLK64_60(ip, i, op, parm) { ;\
  IP9(ip, i*16+ 0, parm); *((uint64_t *)op+i*15+ 0)  = (uint64_t)IPV(ip, i*16+ 0)       | (uint64_t)IPX(ip, i*16+1) << 60;\
  IP64(ip, i*16+ 1, parm); *((uint64_t *)op+i*15+ 1)  = (uint64_t)IPW(ip, i*16+ 1) >>  4 | (uint64_t)IPX(ip, i*16+2) << 56;\
  IP64(ip, i*16+ 2, parm); *((uint64_t *)op+i*15+ 2)  = (uint64_t)IPW(ip, i*16+ 2) >>  8 | (uint64_t)IPX(ip, i*16+3) << 52;\
  IP64(ip, i*16+ 3, parm); *((uint64_t *)op+i*15+ 3)  = (uint64_t)IPW(ip, i*16+ 3) >> 12 | (uint64_t)IPX(ip, i*16+4) << 48;\
  IP64(ip, i*16+ 4, parm); *((uint64_t *)op+i*15+ 4)  = (uint64_t)IPW(ip, i*16+ 4) >> 16 | (uint64_t)IPX(ip, i*16+5) << 44;\
  IP64(ip, i*16+ 5, parm); *((uint64_t *)op+i*15+ 5)  = (uint64_t)IPW(ip, i*16+ 5) >> 20 | (uint64_t)IPX(ip, i*16+6) << 40;\
  IP64(ip, i*16+ 6, parm); *((uint64_t *)op+i*15+ 6)  = (uint64_t)IPW(ip, i*16+ 6) >> 24 | (uint64_t)IPX(ip, i*16+7) << 36;\
  IP64(ip, i*16+ 7, parm); *((uint64_t *)op+i*15+ 7)  = (uint64_t)IPW(ip, i*16+ 7) >> 28 | (uint64_t)IPX(ip, i*16+8) << 32;\
  IP64(ip, i*16+ 8, parm); *((uint64_t *)op+i*15+ 8)  = (uint64_t)IPW(ip, i*16+ 8) >> 32 | (uint64_t)IPX(ip, i*16+9) << 28;\
  IP64(ip, i*16+ 9, parm); *((uint64_t *)op+i*15+ 9)  = (uint64_t)IPW(ip, i*16+ 9) >> 36 | (uint64_t)IPX(ip, i*16+10) << 24;\
  IP64(ip, i*16+10, parm); *((uint64_t *)op+i*15+10)  = (uint64_t)IPW(ip, i*16+10) >> 40 | (uint64_t)IPX(ip, i*16+11) << 20;\
  IP64(ip, i*16+11, parm); *((uint64_t *)op+i*15+11)  = (uint64_t)IPW(ip, i*16+11) >> 44 | (uint64_t)IPX(ip, i*16+12) << 16;\
  IP64(ip, i*16+12, parm); *((uint64_t *)op+i*15+12)  = (uint64_t)IPW(ip, i*16+12) >> 48 | (uint64_t)IPX(ip, i*16+13) << 12;\
  IP64(ip, i*16+13, parm); *((uint64_t *)op+i*15+13)  = (uint64_t)IPW(ip, i*16+13) >> 52 | (uint64_t)IPX(ip, i*16+14) <<  8;\
  IP64(ip, i*16+14, parm); *((uint64_t *)op+i*15+14)  = (uint64_t)IPW(ip, i*16+14) >> 56;\
  IP9(ip, i*16+15, parm); *((uint64_t *)op+i*15+14) |= (uint64_t)IPV(ip, i*16+15) <<  4;\
}

#define BITPACK64_60(ip,  op, parm) { \
  BITBLK64_60(ip, 0, op, parm);\
  BITBLK64_60(ip, 1, op, parm);  IPI(ip); op += 60*4/sizeof(op[0]);\
}

#define BITBLK64_61(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*61+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 61;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*61+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >>  3 | (uint64_t)IPX(ip, i*64+2) << 58;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*61+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >>  6 | (uint64_t)IPX(ip, i*64+3) << 55;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*61+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >>  9 | (uint64_t)IPX(ip, i*64+4) << 52;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*61+ 4)  = (uint64_t)IPW(ip, i*64+ 4) >> 12 | (uint64_t)IPX(ip, i*64+5) << 49;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*61+ 5)  = (uint64_t)IPW(ip, i*64+ 5) >> 15 | (uint64_t)IPX(ip, i*64+6) << 46;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*61+ 6)  = (uint64_t)IPW(ip, i*64+ 6) >> 18 | (uint64_t)IPX(ip, i*64+7) << 43;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*61+ 7)  = (uint64_t)IPW(ip, i*64+ 7) >> 21 | (uint64_t)IPX(ip, i*64+8) << 40;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*61+ 8)  = (uint64_t)IPW(ip, i*64+ 8) >> 24 | (uint64_t)IPX(ip, i*64+9) << 37;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*61+ 9)  = (uint64_t)IPW(ip, i*64+ 9) >> 27 | (uint64_t)IPX(ip, i*64+10) << 34;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*61+10)  = (uint64_t)IPW(ip, i*64+10) >> 30 | (uint64_t)IPX(ip, i*64+11) << 31;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*61+11)  = (uint64_t)IPW(ip, i*64+11) >> 33 | (uint64_t)IPX(ip, i*64+12) << 28;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*61+12)  = (uint64_t)IPW(ip, i*64+12) >> 36 | (uint64_t)IPX(ip, i*64+13) << 25;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*61+13)  = (uint64_t)IPW(ip, i*64+13) >> 39 | (uint64_t)IPX(ip, i*64+14) << 22;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*61+14)  = (uint64_t)IPW(ip, i*64+14) >> 42 | (uint64_t)IPX(ip, i*64+15) << 19;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*61+15)  = (uint64_t)IPW(ip, i*64+15) >> 45 | (uint64_t)IPX(ip, i*64+16) << 16;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*61+16)  = (uint64_t)IPW(ip, i*64+16) >> 48 | (uint64_t)IPX(ip, i*64+17) << 13;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*61+17)  = (uint64_t)IPW(ip, i*64+17) >> 51 | (uint64_t)IPX(ip, i*64+18) << 10;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*61+18)  = (uint64_t)IPW(ip, i*64+18) >> 54 | (uint64_t)IPX(ip, i*64+19) <<  7;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*61+19)  = (uint64_t)IPW(ip, i*64+19) >> 57 | (uint64_t)IPX(ip, i*64+20) <<  4;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*61+20)  = (uint64_t)IPW(ip, i*64+20) >> 60;\
  IP9(ip, i*64+21, parm); *((uint64_t *)op+i*61+20) |= (uint64_t)IPV(ip, i*64+21) <<  1 | (uint64_t)IPX(ip, i*64+22) << 62;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*61+21)  = (uint64_t)IPW(ip, i*64+22) >>  2 | (uint64_t)IPX(ip, i*64+23) << 59;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*61+22)  = (uint64_t)IPW(ip, i*64+23) >>  5 | (uint64_t)IPX(ip, i*64+24) << 56;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*61+23)  = (uint64_t)IPW(ip, i*64+24) >>  8 | (uint64_t)IPX(ip, i*64+25) << 53;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*61+24)  = (uint64_t)IPW(ip, i*64+25) >> 11 | (uint64_t)IPX(ip, i*64+26) << 50;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*61+25)  = (uint64_t)IPW(ip, i*64+26) >> 14 | (uint64_t)IPX(ip, i*64+27) << 47;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*61+26)  = (uint64_t)IPW(ip, i*64+27) >> 17 | (uint64_t)IPX(ip, i*64+28) << 44;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*61+27)  = (uint64_t)IPW(ip, i*64+28) >> 20 | (uint64_t)IPX(ip, i*64+29) << 41;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*61+28)  = (uint64_t)IPW(ip, i*64+29) >> 23 | (uint64_t)IPX(ip, i*64+30) << 38;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*61+29)  = (uint64_t)IPW(ip, i*64+30) >> 26 | (uint64_t)IPX(ip, i*64+31) << 35;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*61+30)  = (uint64_t)IPW(ip, i*64+31) >> 29;\
}

#define BITPACK64_61(ip,  op, parm) { \
  BITBLK64_61(ip, 0, op, parm);  IPI(ip); op += 61*4/sizeof(op[0]);\
}

#define BITBLK64_62(ip, i, op, parm) { ;\
  IP9(ip, i*32+ 0, parm); *((uint64_t *)op+i*31+ 0)  = (uint64_t)IPV(ip, i*32+ 0)       | (uint64_t)IPX(ip, i*32+1) << 62;\
  IP64(ip, i*32+ 1, parm); *((uint64_t *)op+i*31+ 1)  = (uint64_t)IPW(ip, i*32+ 1) >>  2 | (uint64_t)IPX(ip, i*32+2) << 60;\
  IP64(ip, i*32+ 2, parm); *((uint64_t *)op+i*31+ 2)  = (uint64_t)IPW(ip, i*32+ 2) >>  4 | (uint64_t)IPX(ip, i*32+3) << 58;\
  IP64(ip, i*32+ 3, parm); *((uint64_t *)op+i*31+ 3)  = (uint64_t)IPW(ip, i*32+ 3) >>  6 | (uint64_t)IPX(ip, i*32+4) << 56;\
  IP64(ip, i*32+ 4, parm); *((uint64_t *)op+i*31+ 4)  = (uint64_t)IPW(ip, i*32+ 4) >>  8 | (uint64_t)IPX(ip, i*32+5) << 54;\
  IP64(ip, i*32+ 5, parm); *((uint64_t *)op+i*31+ 5)  = (uint64_t)IPW(ip, i*32+ 5) >> 10 | (uint64_t)IPX(ip, i*32+6) << 52;\
  IP64(ip, i*32+ 6, parm); *((uint64_t *)op+i*31+ 6)  = (uint64_t)IPW(ip, i*32+ 6) >> 12 | (uint64_t)IPX(ip, i*32+7) << 50;\
  IP64(ip, i*32+ 7, parm); *((uint64_t *)op+i*31+ 7)  = (uint64_t)IPW(ip, i*32+ 7) >> 14 | (uint64_t)IPX(ip, i*32+8) << 48;\
  IP64(ip, i*32+ 8, parm); *((uint64_t *)op+i*31+ 8)  = (uint64_t)IPW(ip, i*32+ 8) >> 16 | (uint64_t)IPX(ip, i*32+9) << 46;\
  IP64(ip, i*32+ 9, parm); *((uint64_t *)op+i*31+ 9)  = (uint64_t)IPW(ip, i*32+ 9) >> 18 | (uint64_t)IPX(ip, i*32+10) << 44;\
  IP64(ip, i*32+10, parm); *((uint64_t *)op+i*31+10)  = (uint64_t)IPW(ip, i*32+10) >> 20 | (uint64_t)IPX(ip, i*32+11) << 42;\
  IP64(ip, i*32+11, parm); *((uint64_t *)op+i*31+11)  = (uint64_t)IPW(ip, i*32+11) >> 22 | (uint64_t)IPX(ip, i*32+12) << 40;\
  IP64(ip, i*32+12, parm); *((uint64_t *)op+i*31+12)  = (uint64_t)IPW(ip, i*32+12) >> 24 | (uint64_t)IPX(ip, i*32+13) << 38;\
  IP64(ip, i*32+13, parm); *((uint64_t *)op+i*31+13)  = (uint64_t)IPW(ip, i*32+13) >> 26 | (uint64_t)IPX(ip, i*32+14) << 36;\
  IP64(ip, i*32+14, parm); *((uint64_t *)op+i*31+14)  = (uint64_t)IPW(ip, i*32+14) >> 28 | (uint64_t)IPX(ip, i*32+15) << 34;\
  IP64(ip, i*32+15, parm); *((uint64_t *)op+i*31+15)  = (uint64_t)IPW(ip, i*32+15) >> 30 | (uint64_t)IPX(ip, i*32+16) << 32;\
  IP64(ip, i*32+16, parm); *((uint64_t *)op+i*31+16)  = (uint64_t)IPW(ip, i*32+16) >> 32 | (uint64_t)IPX(ip, i*32+17) << 30;\
  IP64(ip, i*32+17, parm); *((uint64_t *)op+i*31+17)  = (uint64_t)IPW(ip, i*32+17) >> 34 | (uint64_t)IPX(ip, i*32+18) << 28;\
  IP64(ip, i*32+18, parm); *((uint64_t *)op+i*31+18)  = (uint64_t)IPW(ip, i*32+18) >> 36 | (uint64_t)IPX(ip, i*32+19) << 26;\
  IP64(ip, i*32+19, parm); *((uint64_t *)op+i*31+19)  = (uint64_t)IPW(ip, i*32+19) >> 38 | (uint64_t)IPX(ip, i*32+20) << 24;\
  IP64(ip, i*32+20, parm); *((uint64_t *)op+i*31+20)  = (uint64_t)IPW(ip, i*32+20) >> 40 | (uint64_t)IPX(ip, i*32+21) << 22;\
  IP64(ip, i*32+21, parm); *((uint64_t *)op+i*31+21)  = (uint64_t)IPW(ip, i*32+21) >> 42 | (uint64_t)IPX(ip, i*32+22) << 20;\
  IP64(ip, i*32+22, parm); *((uint64_t *)op+i*31+22)  = (uint64_t)IPW(ip, i*32+22) >> 44 | (uint64_t)IPX(ip, i*32+23) << 18;\
  IP64(ip, i*32+23, parm); *((uint64_t *)op+i*31+23)  = (uint64_t)IPW(ip, i*32+23) >> 46 | (uint64_t)IPX(ip, i*32+24) << 16;\
  IP64(ip, i*32+24, parm); *((uint64_t *)op+i*31+24)  = (uint64_t)IPW(ip, i*32+24) >> 48 | (uint64_t)IPX(ip, i*32+25) << 14;\
  IP64(ip, i*32+25, parm); *((uint64_t *)op+i*31+25)  = (uint64_t)IPW(ip, i*32+25) >> 50 | (uint64_t)IPX(ip, i*32+26) << 12;\
  IP64(ip, i*32+26, parm); *((uint64_t *)op+i*31+26)  = (uint64_t)IPW(ip, i*32+26) >> 52 | (uint64_t)IPX(ip, i*32+27) << 10;\
  IP64(ip, i*32+27, parm); *((uint64_t *)op+i*31+27)  = (uint64_t)IPW(ip, i*32+27) >> 54 | (uint64_t)IPX(ip, i*32+28) <<  8;\
  IP64(ip, i*32+28, parm); *((uint64_t *)op+i*31+28)  = (uint64_t)IPW(ip, i*32+28) >> 56 | (uint64_t)IPX(ip, i*32+29) <<  6;\
  IP64(ip, i*32+29, parm); *((uint64_t *)op+i*31+29)  = (uint64_t)IPW(ip, i*32+29) >> 58 | (uint64_t)IPX(ip, i*32+30) <<  4;\
  IP64(ip, i*32+30, parm); *((uint64_t *)op+i*31+30)  = (uint64_t)IPW(ip, i*32+30) >> 60;\
  IP9(ip, i*32+31, parm); *((uint64_t *)op+i*31+30) |= (uint64_t)IPV(ip, i*32+31) <<  2;\
}

#define BITPACK64_62(ip,  op, parm) { \
  BITBLK64_62(ip, 0, op, parm);  IPI(ip); op += 62*4/sizeof(op[0]);\
}

#define BITBLK64_63(ip, i, op, parm) { ;\
  IP9(ip, i*64+ 0, parm); *((uint64_t *)op+i*63+ 0)  = (uint64_t)IPV(ip, i*64+ 0)       | (uint64_t)IPX(ip, i*64+1) << 63;\
  IP64(ip, i*64+ 1, parm); *((uint64_t *)op+i*63+ 1)  = (uint64_t)IPW(ip, i*64+ 1) >>  1 | (uint64_t)IPX(ip, i*64+2) << 62;\
  IP64(ip, i*64+ 2, parm); *((uint64_t *)op+i*63+ 2)  = (uint64_t)IPW(ip, i*64+ 2) >>  2 | (uint64_t)IPX(ip, i*64+3) << 61;\
  IP64(ip, i*64+ 3, parm); *((uint64_t *)op+i*63+ 3)  = (uint64_t)IPW(ip, i*64+ 3) >>  3 | (uint64_t)IPX(ip, i*64+4) << 60;\
  IP64(ip, i*64+ 4, parm); *((uint64_t *)op+i*63+ 4)  = (uint64_t)IPW(ip, i*64+ 4) >>  4 | (uint64_t)IPX(ip, i*64+5) << 59;\
  IP64(ip, i*64+ 5, parm); *((uint64_t *)op+i*63+ 5)  = (uint64_t)IPW(ip, i*64+ 5) >>  5 | (uint64_t)IPX(ip, i*64+6) << 58;\
  IP64(ip, i*64+ 6, parm); *((uint64_t *)op+i*63+ 6)  = (uint64_t)IPW(ip, i*64+ 6) >>  6 | (uint64_t)IPX(ip, i*64+7) << 57;\
  IP64(ip, i*64+ 7, parm); *((uint64_t *)op+i*63+ 7)  = (uint64_t)IPW(ip, i*64+ 7) >>  7 | (uint64_t)IPX(ip, i*64+8) << 56;\
  IP64(ip, i*64+ 8, parm); *((uint64_t *)op+i*63+ 8)  = (uint64_t)IPW(ip, i*64+ 8) >>  8 | (uint64_t)IPX(ip, i*64+9) << 55;\
  IP64(ip, i*64+ 9, parm); *((uint64_t *)op+i*63+ 9)  = (uint64_t)IPW(ip, i*64+ 9) >>  9 | (uint64_t)IPX(ip, i*64+10) << 54;\
  IP64(ip, i*64+10, parm); *((uint64_t *)op+i*63+10)  = (uint64_t)IPW(ip, i*64+10) >> 10 | (uint64_t)IPX(ip, i*64+11) << 53;\
  IP64(ip, i*64+11, parm); *((uint64_t *)op+i*63+11)  = (uint64_t)IPW(ip, i*64+11) >> 11 | (uint64_t)IPX(ip, i*64+12) << 52;\
  IP64(ip, i*64+12, parm); *((uint64_t *)op+i*63+12)  = (uint64_t)IPW(ip, i*64+12) >> 12 | (uint64_t)IPX(ip, i*64+13) << 51;\
  IP64(ip, i*64+13, parm); *((uint64_t *)op+i*63+13)  = (uint64_t)IPW(ip, i*64+13) >> 13 | (uint64_t)IPX(ip, i*64+14) << 50;\
  IP64(ip, i*64+14, parm); *((uint64_t *)op+i*63+14)  = (uint64_t)IPW(ip, i*64+14) >> 14 | (uint64_t)IPX(ip, i*64+15) << 49;\
  IP64(ip, i*64+15, parm); *((uint64_t *)op+i*63+15)  = (uint64_t)IPW(ip, i*64+15) >> 15 | (uint64_t)IPX(ip, i*64+16) << 48;\
  IP64(ip, i*64+16, parm); *((uint64_t *)op+i*63+16)  = (uint64_t)IPW(ip, i*64+16) >> 16 | (uint64_t)IPX(ip, i*64+17) << 47;\
  IP64(ip, i*64+17, parm); *((uint64_t *)op+i*63+17)  = (uint64_t)IPW(ip, i*64+17) >> 17 | (uint64_t)IPX(ip, i*64+18) << 46;\
  IP64(ip, i*64+18, parm); *((uint64_t *)op+i*63+18)  = (uint64_t)IPW(ip, i*64+18) >> 18 | (uint64_t)IPX(ip, i*64+19) << 45;\
  IP64(ip, i*64+19, parm); *((uint64_t *)op+i*63+19)  = (uint64_t)IPW(ip, i*64+19) >> 19 | (uint64_t)IPX(ip, i*64+20) << 44;\
  IP64(ip, i*64+20, parm); *((uint64_t *)op+i*63+20)  = (uint64_t)IPW(ip, i*64+20) >> 20 | (uint64_t)IPX(ip, i*64+21) << 43;\
  IP64(ip, i*64+21, parm); *((uint64_t *)op+i*63+21)  = (uint64_t)IPW(ip, i*64+21) >> 21 | (uint64_t)IPX(ip, i*64+22) << 42;\
  IP64(ip, i*64+22, parm); *((uint64_t *)op+i*63+22)  = (uint64_t)IPW(ip, i*64+22) >> 22 | (uint64_t)IPX(ip, i*64+23) << 41;\
  IP64(ip, i*64+23, parm); *((uint64_t *)op+i*63+23)  = (uint64_t)IPW(ip, i*64+23) >> 23 | (uint64_t)IPX(ip, i*64+24) << 40;\
  IP64(ip, i*64+24, parm); *((uint64_t *)op+i*63+24)  = (uint64_t)IPW(ip, i*64+24) >> 24 | (uint64_t)IPX(ip, i*64+25) << 39;\
  IP64(ip, i*64+25, parm); *((uint64_t *)op+i*63+25)  = (uint64_t)IPW(ip, i*64+25) >> 25 | (uint64_t)IPX(ip, i*64+26) << 38;\
  IP64(ip, i*64+26, parm); *((uint64_t *)op+i*63+26)  = (uint64_t)IPW(ip, i*64+26) >> 26 | (uint64_t)IPX(ip, i*64+27) << 37;\
  IP64(ip, i*64+27, parm); *((uint64_t *)op+i*63+27)  = (uint64_t)IPW(ip, i*64+27) >> 27 | (uint64_t)IPX(ip, i*64+28) << 36;\
  IP64(ip, i*64+28, parm); *((uint64_t *)op+i*63+28)  = (uint64_t)IPW(ip, i*64+28) >> 28 | (uint64_t)IPX(ip, i*64+29) << 35;\
  IP64(ip, i*64+29, parm); *((uint64_t *)op+i*63+29)  = (uint64_t)IPW(ip, i*64+29) >> 29 | (uint64_t)IPX(ip, i*64+30) << 34;\
  IP64(ip, i*64+30, parm); *((uint64_t *)op+i*63+30)  = (uint64_t)IPW(ip, i*64+30) >> 30 | (uint64_t)IPX(ip, i*64+31) << 33;\
  IP64(ip, i*64+31, parm); *((uint64_t *)op+i*63+31)  = (uint64_t)IPW(ip, i*64+31) >> 31;\
}

#define BITPACK64_63(ip,  op, parm) { \
  BITBLK64_63(ip, 0, op, parm);  IPI(ip); op += 63*4/sizeof(op[0]);\
}

#define BITBLK64_64(ip, i, op, parm) { ;\
  IP9(ip, i*1+ 0, parm); *((uint64_t *)op+i*1+ 0)  = (uint64_t)IPV(ip, i*1+ 0)      ;\
}

#define BITPACK64_64(ip,  op, parm) { \
  BITBLK64_64(ip, 0, op, parm);\
  BITBLK64_64(ip, 1, op, parm);\
  BITBLK64_64(ip, 2, op, parm);\
  BITBLK64_64(ip, 3, op, parm);\
  BITBLK64_64(ip, 4, op, parm);\
  BITBLK64_64(ip, 5, op, parm);\
  BITBLK64_64(ip, 6, op, parm);\
  BITBLK64_64(ip, 7, op, parm);\
  BITBLK64_64(ip, 8, op, parm);\
  BITBLK64_64(ip, 9, op, parm);\
  BITBLK64_64(ip, 10, op, parm);\
  BITBLK64_64(ip, 11, op, parm);\
  BITBLK64_64(ip, 12, op, parm);\
  BITBLK64_64(ip, 13, op, parm);\
  BITBLK64_64(ip, 14, op, parm);\
  BITBLK64_64(ip, 15, op, parm);\
  BITBLK64_64(ip, 16, op, parm);\
  BITBLK64_64(ip, 17, op, parm);\
  BITBLK64_64(ip, 18, op, parm);\
  BITBLK64_64(ip, 19, op, parm);\
  BITBLK64_64(ip, 20, op, parm);\
  BITBLK64_64(ip, 21, op, parm);\
  BITBLK64_64(ip, 22, op, parm);\
  BITBLK64_64(ip, 23, op, parm);\
  BITBLK64_64(ip, 24, op, parm);\
  BITBLK64_64(ip, 25, op, parm);\
  BITBLK64_64(ip, 26, op, parm);\
  BITBLK64_64(ip, 27, op, parm);\
  BITBLK64_64(ip, 28, op, parm);\
  BITBLK64_64(ip, 29, op, parm);\
  BITBLK64_64(ip, 30, op, parm);\
  BITBLK64_64(ip, 31, op, parm);  IPI(ip); op += 64*4/sizeof(op[0]);\
}

#ifndef DELTA
#define USIZE 8
unsigned char *TEMPLATE2(_BITPACK_,8_0)( uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,8_1)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*1); uint8_t v,x;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_2)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*2); uint8_t v,x;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_3)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*3); uint8_t v,x;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_4)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*4); uint8_t v,x;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_5)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*5); uint8_t v,x;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_6)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*6); uint8_t v,x;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_7)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*7); uint8_t v,x;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_8)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*8); uint8_t v,x;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_F8 TEMPLATE2(_BITPACK_,a8)[] = {
  &TEMPLATE2(_BITPACK_,8_0),
  &TEMPLATE2(_BITPACK_,8_1),
  &TEMPLATE2(_BITPACK_,8_2),
  &TEMPLATE2(_BITPACK_,8_3),
  &TEMPLATE2(_BITPACK_,8_4),
  &TEMPLATE2(_BITPACK_,8_5),
  &TEMPLATE2(_BITPACK_,8_6),
  &TEMPLATE2(_BITPACK_,8_7),
  &TEMPLATE2(_BITPACK_,8_8)
};
unsigned char *TEMPLATE2(_BITPACK_,8)( uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , unsigned b) { return TEMPLATE2(_BITPACK_,a8)[ b](in, n, out); }

#define USIZE 16
unsigned char *TEMPLATE2(_BITPACK_,16_0)( uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,16_1)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*1); uint16_t v,x;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_2)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*2); uint16_t v,x;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_3)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*3); uint16_t v,x;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_4)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*4); uint16_t v,x;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_5)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*5); uint16_t v,x;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_6)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*6); uint16_t v,x;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_7)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*7); uint16_t v,x;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_8)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*8); uint16_t v,x;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_9)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*9); uint16_t v,x;do { BITPACK64_9( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_10)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*10); uint16_t v,x;do { BITPACK64_10( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_11)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*11); uint16_t v,x;do { BITPACK64_11( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_12)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*12); uint16_t v,x;do { BITPACK64_12( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_13)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*13); uint16_t v,x;do { BITPACK64_13( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_14)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*14); uint16_t v,x;do { BITPACK64_14( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_15)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*15); uint16_t v,x;do { BITPACK64_15( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_16)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*16); uint16_t v,x;do { BITPACK64_16( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_F16 TEMPLATE2(_BITPACK_,a16)[] = {
  &TEMPLATE2(_BITPACK_,16_0),
  &TEMPLATE2(_BITPACK_,16_1),
  &TEMPLATE2(_BITPACK_,16_2),
  &TEMPLATE2(_BITPACK_,16_3),
  &TEMPLATE2(_BITPACK_,16_4),
  &TEMPLATE2(_BITPACK_,16_5),
  &TEMPLATE2(_BITPACK_,16_6),
  &TEMPLATE2(_BITPACK_,16_7),
  &TEMPLATE2(_BITPACK_,16_8),
  &TEMPLATE2(_BITPACK_,16_9),
  &TEMPLATE2(_BITPACK_,16_10),
  &TEMPLATE2(_BITPACK_,16_11),
  &TEMPLATE2(_BITPACK_,16_12),
  &TEMPLATE2(_BITPACK_,16_13),
  &TEMPLATE2(_BITPACK_,16_14),
  &TEMPLATE2(_BITPACK_,16_15),
  &TEMPLATE2(_BITPACK_,16_16)
};
unsigned char *TEMPLATE2(_BITPACK_,16)( uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , unsigned b) { return TEMPLATE2(_BITPACK_,a16)[ b](in, n, out); }

#define USIZE 32
unsigned char *TEMPLATE2(_BITPACK_,32_0)( uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,32_1)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*1); uint32_t v,x;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_2)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*2); uint32_t v,x;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_3)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*3); uint32_t v,x;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_4)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*4); uint32_t v,x;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_5)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*5); uint32_t v,x;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_6)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*6); uint32_t v,x;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_7)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*7); uint32_t v,x;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_8)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*8); uint32_t v,x;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_9)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*9); uint32_t v,x;do { BITPACK64_9( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_10)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*10); uint32_t v,x;do { BITPACK64_10( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_11)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*11); uint32_t v,x;do { BITPACK64_11( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_12)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*12); uint32_t v,x;do { BITPACK64_12( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_13)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*13); uint32_t v,x;do { BITPACK64_13( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_14)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*14); uint32_t v,x;do { BITPACK64_14( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_15)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*15); uint32_t v,x;do { BITPACK64_15( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_16)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*16); uint32_t v,x;do { BITPACK64_16( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_17)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*17); uint32_t v,x;do { BITPACK64_17( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_18)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*18); uint32_t v,x;do { BITPACK64_18( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_19)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*19); uint32_t v,x;do { BITPACK64_19( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_20)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*20); uint32_t v,x;do { BITPACK64_20( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_21)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*21); uint32_t v,x;do { BITPACK64_21( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_22)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*22); uint32_t v,x;do { BITPACK64_22( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_23)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*23); uint32_t v,x;do { BITPACK64_23( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_24)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*24); uint32_t v,x;do { BITPACK64_24( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_25)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*25); uint32_t v,x;do { BITPACK64_25( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_26)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*26); uint32_t v,x;do { BITPACK64_26( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_27)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*27); uint32_t v,x;do { BITPACK64_27( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_28)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*28); uint32_t v,x;do { BITPACK64_28( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_29)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*29); uint32_t v,x;do { BITPACK64_29( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_30)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*30); uint32_t v,x;do { BITPACK64_30( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_31)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*31); uint32_t v,x;do { BITPACK64_31( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_32)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*32); uint32_t v,x;do { BITPACK64_32( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_F32 TEMPLATE2(_BITPACK_,a32)[] = {
  &TEMPLATE2(_BITPACK_,32_0),
  &TEMPLATE2(_BITPACK_,32_1),
  &TEMPLATE2(_BITPACK_,32_2),
  &TEMPLATE2(_BITPACK_,32_3),
  &TEMPLATE2(_BITPACK_,32_4),
  &TEMPLATE2(_BITPACK_,32_5),
  &TEMPLATE2(_BITPACK_,32_6),
  &TEMPLATE2(_BITPACK_,32_7),
  &TEMPLATE2(_BITPACK_,32_8),
  &TEMPLATE2(_BITPACK_,32_9),
  &TEMPLATE2(_BITPACK_,32_10),
  &TEMPLATE2(_BITPACK_,32_11),
  &TEMPLATE2(_BITPACK_,32_12),
  &TEMPLATE2(_BITPACK_,32_13),
  &TEMPLATE2(_BITPACK_,32_14),
  &TEMPLATE2(_BITPACK_,32_15),
  &TEMPLATE2(_BITPACK_,32_16),
  &TEMPLATE2(_BITPACK_,32_17),
  &TEMPLATE2(_BITPACK_,32_18),
  &TEMPLATE2(_BITPACK_,32_19),
  &TEMPLATE2(_BITPACK_,32_20),
  &TEMPLATE2(_BITPACK_,32_21),
  &TEMPLATE2(_BITPACK_,32_22),
  &TEMPLATE2(_BITPACK_,32_23),
  &TEMPLATE2(_BITPACK_,32_24),
  &TEMPLATE2(_BITPACK_,32_25),
  &TEMPLATE2(_BITPACK_,32_26),
  &TEMPLATE2(_BITPACK_,32_27),
  &TEMPLATE2(_BITPACK_,32_28),
  &TEMPLATE2(_BITPACK_,32_29),
  &TEMPLATE2(_BITPACK_,32_30),
  &TEMPLATE2(_BITPACK_,32_31),
  &TEMPLATE2(_BITPACK_,32_32)
};
unsigned char *TEMPLATE2(_BITPACK_,32)( uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , unsigned b) { return TEMPLATE2(_BITPACK_,a32)[ b](in, n, out); }

#define USIZE 64
unsigned char *TEMPLATE2(_BITPACK_,64_0)( uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,64_1)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*1); uint64_t v,x;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_2)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*2); uint64_t v,x;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_3)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*3); uint64_t v,x;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_4)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*4); uint64_t v,x;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_5)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*5); uint64_t v,x;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_6)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*6); uint64_t v,x;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_7)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*7); uint64_t v,x;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_8)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*8); uint64_t v,x;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_9)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*9); uint64_t v,x;do { BITPACK64_9( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_10)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*10); uint64_t v,x;do { BITPACK64_10( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_11)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*11); uint64_t v,x;do { BITPACK64_11( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_12)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*12); uint64_t v,x;do { BITPACK64_12( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_13)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*13); uint64_t v,x;do { BITPACK64_13( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_14)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*14); uint64_t v,x;do { BITPACK64_14( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_15)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*15); uint64_t v,x;do { BITPACK64_15( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_16)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*16); uint64_t v,x;do { BITPACK64_16( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_17)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*17); uint64_t v,x;do { BITPACK64_17( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_18)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*18); uint64_t v,x;do { BITPACK64_18( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_19)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*19); uint64_t v,x;do { BITPACK64_19( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_20)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*20); uint64_t v,x;do { BITPACK64_20( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_21)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*21); uint64_t v,x;do { BITPACK64_21( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_22)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*22); uint64_t v,x;do { BITPACK64_22( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_23)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*23); uint64_t v,x;do { BITPACK64_23( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_24)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*24); uint64_t v,x;do { BITPACK64_24( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_25)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*25); uint64_t v,x;do { BITPACK64_25( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_26)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*26); uint64_t v,x;do { BITPACK64_26( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_27)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*27); uint64_t v,x;do { BITPACK64_27( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_28)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*28); uint64_t v,x;do { BITPACK64_28( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_29)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*29); uint64_t v,x;do { BITPACK64_29( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_30)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*30); uint64_t v,x;do { BITPACK64_30( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_31)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*31); uint64_t v,x;do { BITPACK64_31( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_32)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*32); uint64_t v,x;do { BITPACK64_32( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_33)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*33); uint64_t v,x;do { BITPACK64_33( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_34)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*34); uint64_t v,x;do { BITPACK64_34( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_35)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*35); uint64_t v,x;do { BITPACK64_35( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_36)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*36); uint64_t v,x;do { BITPACK64_36( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_37)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*37); uint64_t v,x;do { BITPACK64_37( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_38)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*38); uint64_t v,x;do { BITPACK64_38( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_39)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*39); uint64_t v,x;do { BITPACK64_39( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_40)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*40); uint64_t v,x;do { BITPACK64_40( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_41)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*41); uint64_t v,x;do { BITPACK64_41( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_42)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*42); uint64_t v,x;do { BITPACK64_42( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_43)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*43); uint64_t v,x;do { BITPACK64_43( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_44)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*44); uint64_t v,x;do { BITPACK64_44( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_45)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*45); uint64_t v,x;do { BITPACK64_45( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_46)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*46); uint64_t v,x;do { BITPACK64_46( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_47)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*47); uint64_t v,x;do { BITPACK64_47( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_48)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*48); uint64_t v,x;do { BITPACK64_48( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_49)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*49); uint64_t v,x;do { BITPACK64_49( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_50)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*50); uint64_t v,x;do { BITPACK64_50( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_51)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*51); uint64_t v,x;do { BITPACK64_51( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_52)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*52); uint64_t v,x;do { BITPACK64_52( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_53)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*53); uint64_t v,x;do { BITPACK64_53( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_54)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*54); uint64_t v,x;do { BITPACK64_54( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_55)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*55); uint64_t v,x;do { BITPACK64_55( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_56)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*56); uint64_t v,x;do { BITPACK64_56( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_57)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*57); uint64_t v,x;do { BITPACK64_57( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_58)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*58); uint64_t v,x;do { BITPACK64_58( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_59)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*59); uint64_t v,x;do { BITPACK64_59( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_60)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*60); uint64_t v,x;do { BITPACK64_60( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_61)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*61); uint64_t v,x;do { BITPACK64_61( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_62)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*62); uint64_t v,x;do { BITPACK64_62( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_63)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*63); uint64_t v,x;do { BITPACK64_63( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_64)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out  ) { unsigned char *out_=out+PAD8(n*64); uint64_t v,x;do { BITPACK64_64( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_F64 TEMPLATE2(_BITPACK_,a64)[] = {
  &TEMPLATE2(_BITPACK_,64_0),
  &TEMPLATE2(_BITPACK_,64_1),
  &TEMPLATE2(_BITPACK_,64_2),
  &TEMPLATE2(_BITPACK_,64_3),
  &TEMPLATE2(_BITPACK_,64_4),
  &TEMPLATE2(_BITPACK_,64_5),
  &TEMPLATE2(_BITPACK_,64_6),
  &TEMPLATE2(_BITPACK_,64_7),
  &TEMPLATE2(_BITPACK_,64_8),
  &TEMPLATE2(_BITPACK_,64_9),
  &TEMPLATE2(_BITPACK_,64_10),
  &TEMPLATE2(_BITPACK_,64_11),
  &TEMPLATE2(_BITPACK_,64_12),
  &TEMPLATE2(_BITPACK_,64_13),
  &TEMPLATE2(_BITPACK_,64_14),
  &TEMPLATE2(_BITPACK_,64_15),
  &TEMPLATE2(_BITPACK_,64_16),
  &TEMPLATE2(_BITPACK_,64_17),
  &TEMPLATE2(_BITPACK_,64_18),
  &TEMPLATE2(_BITPACK_,64_19),
  &TEMPLATE2(_BITPACK_,64_20),
  &TEMPLATE2(_BITPACK_,64_21),
  &TEMPLATE2(_BITPACK_,64_22),
  &TEMPLATE2(_BITPACK_,64_23),
  &TEMPLATE2(_BITPACK_,64_24),
  &TEMPLATE2(_BITPACK_,64_25),
  &TEMPLATE2(_BITPACK_,64_26),
  &TEMPLATE2(_BITPACK_,64_27),
  &TEMPLATE2(_BITPACK_,64_28),
  &TEMPLATE2(_BITPACK_,64_29),
  &TEMPLATE2(_BITPACK_,64_30),
  &TEMPLATE2(_BITPACK_,64_31),
  &TEMPLATE2(_BITPACK_,64_32),
  &TEMPLATE2(_BITPACK_,64_33),
  &TEMPLATE2(_BITPACK_,64_34),
  &TEMPLATE2(_BITPACK_,64_35),
  &TEMPLATE2(_BITPACK_,64_36),
  &TEMPLATE2(_BITPACK_,64_37),
  &TEMPLATE2(_BITPACK_,64_38),
  &TEMPLATE2(_BITPACK_,64_39),
  &TEMPLATE2(_BITPACK_,64_40),
  &TEMPLATE2(_BITPACK_,64_41),
  &TEMPLATE2(_BITPACK_,64_42),
  &TEMPLATE2(_BITPACK_,64_43),
  &TEMPLATE2(_BITPACK_,64_44),
  &TEMPLATE2(_BITPACK_,64_45),
  &TEMPLATE2(_BITPACK_,64_46),
  &TEMPLATE2(_BITPACK_,64_47),
  &TEMPLATE2(_BITPACK_,64_48),
  &TEMPLATE2(_BITPACK_,64_49),
  &TEMPLATE2(_BITPACK_,64_50),
  &TEMPLATE2(_BITPACK_,64_51),
  &TEMPLATE2(_BITPACK_,64_52),
  &TEMPLATE2(_BITPACK_,64_53),
  &TEMPLATE2(_BITPACK_,64_54),
  &TEMPLATE2(_BITPACK_,64_55),
  &TEMPLATE2(_BITPACK_,64_56),
  &TEMPLATE2(_BITPACK_,64_57),
  &TEMPLATE2(_BITPACK_,64_58),
  &TEMPLATE2(_BITPACK_,64_59),
  &TEMPLATE2(_BITPACK_,64_60),
  &TEMPLATE2(_BITPACK_,64_61),
  &TEMPLATE2(_BITPACK_,64_62),
  &TEMPLATE2(_BITPACK_,64_63),
  &TEMPLATE2(_BITPACK_,64_64)
};
unsigned char *TEMPLATE2(_BITPACK_,64)( uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , unsigned b) { return TEMPLATE2(_BITPACK_,a64)[ b](in, n, out); }

#else
#define USIZE 8
unsigned char *TEMPLATE2(_BITPACK_,8_0)( uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,8_1)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*1); uint8_t v,x=0;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_2)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*2); uint8_t v,x=0;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_3)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*3); uint8_t v,x=0;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_4)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*4); uint8_t v,x=0;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_5)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*5); uint8_t v,x=0;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_6)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*6); uint8_t v,x=0;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_7)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*7); uint8_t v,x=0;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,8_8)(uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start ) { unsigned char *out_=out+PAD8(n*8); uint8_t v,x=0;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_D8 TEMPLATE2(_BITPACK_,a8)[] = {
  &TEMPLATE2(_BITPACK_,8_0),
  &TEMPLATE2(_BITPACK_,8_1),
  &TEMPLATE2(_BITPACK_,8_2),
  &TEMPLATE2(_BITPACK_,8_3),
  &TEMPLATE2(_BITPACK_,8_4),
  &TEMPLATE2(_BITPACK_,8_5),
  &TEMPLATE2(_BITPACK_,8_6),
  &TEMPLATE2(_BITPACK_,8_7),
  &TEMPLATE2(_BITPACK_,8_8)
};
unsigned char *TEMPLATE2(_BITPACK_,8)( uint8_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint8_t start, unsigned b) { return TEMPLATE2(_BITPACK_,a8)[ b](in, n, out, start); }

#define USIZE 16
unsigned char *TEMPLATE2(_BITPACK_,16_0)( uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,16_1)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*1); uint16_t v,x=0;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_2)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*2); uint16_t v,x=0;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_3)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*3); uint16_t v,x=0;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_4)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*4); uint16_t v,x=0;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_5)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*5); uint16_t v,x=0;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_6)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*6); uint16_t v,x=0;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_7)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*7); uint16_t v,x=0;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_8)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*8); uint16_t v,x=0;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_9)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*9); uint16_t v,x=0;do { BITPACK64_9( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_10)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*10); uint16_t v,x=0;do { BITPACK64_10( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_11)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*11); uint16_t v,x=0;do { BITPACK64_11( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_12)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*12); uint16_t v,x=0;do { BITPACK64_12( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_13)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*13); uint16_t v,x=0;do { BITPACK64_13( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_14)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*14); uint16_t v,x=0;do { BITPACK64_14( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_15)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*15); uint16_t v,x=0;do { BITPACK64_15( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,16_16)(uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start ) { unsigned char *out_=out+PAD8(n*16); uint16_t v,x=0;do { BITPACK64_16( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_D16 TEMPLATE2(_BITPACK_,a16)[] = {
  &TEMPLATE2(_BITPACK_,16_0),
  &TEMPLATE2(_BITPACK_,16_1),
  &TEMPLATE2(_BITPACK_,16_2),
  &TEMPLATE2(_BITPACK_,16_3),
  &TEMPLATE2(_BITPACK_,16_4),
  &TEMPLATE2(_BITPACK_,16_5),
  &TEMPLATE2(_BITPACK_,16_6),
  &TEMPLATE2(_BITPACK_,16_7),
  &TEMPLATE2(_BITPACK_,16_8),
  &TEMPLATE2(_BITPACK_,16_9),
  &TEMPLATE2(_BITPACK_,16_10),
  &TEMPLATE2(_BITPACK_,16_11),
  &TEMPLATE2(_BITPACK_,16_12),
  &TEMPLATE2(_BITPACK_,16_13),
  &TEMPLATE2(_BITPACK_,16_14),
  &TEMPLATE2(_BITPACK_,16_15),
  &TEMPLATE2(_BITPACK_,16_16)
};
unsigned char *TEMPLATE2(_BITPACK_,16)( uint16_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint16_t start, unsigned b) { return TEMPLATE2(_BITPACK_,a16)[ b](in, n, out, start); }

#define USIZE 32
unsigned char *TEMPLATE2(_BITPACK_,32_0)( uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,32_1)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*1); uint32_t v,x=0;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_2)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*2); uint32_t v,x=0;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_3)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*3); uint32_t v,x=0;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_4)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*4); uint32_t v,x=0;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_5)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*5); uint32_t v,x=0;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_6)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*6); uint32_t v,x=0;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_7)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*7); uint32_t v,x=0;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_8)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*8); uint32_t v,x=0;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_9)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*9); uint32_t v,x=0;do { BITPACK64_9( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_10)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*10); uint32_t v,x=0;do { BITPACK64_10( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_11)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*11); uint32_t v,x=0;do { BITPACK64_11( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_12)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*12); uint32_t v,x=0;do { BITPACK64_12( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_13)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*13); uint32_t v,x=0;do { BITPACK64_13( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_14)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*14); uint32_t v,x=0;do { BITPACK64_14( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_15)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*15); uint32_t v,x=0;do { BITPACK64_15( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_16)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*16); uint32_t v,x=0;do { BITPACK64_16( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_17)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*17); uint32_t v,x=0;do { BITPACK64_17( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_18)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*18); uint32_t v,x=0;do { BITPACK64_18( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_19)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*19); uint32_t v,x=0;do { BITPACK64_19( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_20)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*20); uint32_t v,x=0;do { BITPACK64_20( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_21)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*21); uint32_t v,x=0;do { BITPACK64_21( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_22)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*22); uint32_t v,x=0;do { BITPACK64_22( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_23)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*23); uint32_t v,x=0;do { BITPACK64_23( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_24)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*24); uint32_t v,x=0;do { BITPACK64_24( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_25)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*25); uint32_t v,x=0;do { BITPACK64_25( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_26)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*26); uint32_t v,x=0;do { BITPACK64_26( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_27)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*27); uint32_t v,x=0;do { BITPACK64_27( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_28)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*28); uint32_t v,x=0;do { BITPACK64_28( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_29)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*29); uint32_t v,x=0;do { BITPACK64_29( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_30)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*30); uint32_t v,x=0;do { BITPACK64_30( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_31)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*31); uint32_t v,x=0;do { BITPACK64_31( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,32_32)(uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start ) { unsigned char *out_=out+PAD8(n*32); uint32_t v,x=0;do { BITPACK64_32( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_D32 TEMPLATE2(_BITPACK_,a32)[] = {
  &TEMPLATE2(_BITPACK_,32_0),
  &TEMPLATE2(_BITPACK_,32_1),
  &TEMPLATE2(_BITPACK_,32_2),
  &TEMPLATE2(_BITPACK_,32_3),
  &TEMPLATE2(_BITPACK_,32_4),
  &TEMPLATE2(_BITPACK_,32_5),
  &TEMPLATE2(_BITPACK_,32_6),
  &TEMPLATE2(_BITPACK_,32_7),
  &TEMPLATE2(_BITPACK_,32_8),
  &TEMPLATE2(_BITPACK_,32_9),
  &TEMPLATE2(_BITPACK_,32_10),
  &TEMPLATE2(_BITPACK_,32_11),
  &TEMPLATE2(_BITPACK_,32_12),
  &TEMPLATE2(_BITPACK_,32_13),
  &TEMPLATE2(_BITPACK_,32_14),
  &TEMPLATE2(_BITPACK_,32_15),
  &TEMPLATE2(_BITPACK_,32_16),
  &TEMPLATE2(_BITPACK_,32_17),
  &TEMPLATE2(_BITPACK_,32_18),
  &TEMPLATE2(_BITPACK_,32_19),
  &TEMPLATE2(_BITPACK_,32_20),
  &TEMPLATE2(_BITPACK_,32_21),
  &TEMPLATE2(_BITPACK_,32_22),
  &TEMPLATE2(_BITPACK_,32_23),
  &TEMPLATE2(_BITPACK_,32_24),
  &TEMPLATE2(_BITPACK_,32_25),
  &TEMPLATE2(_BITPACK_,32_26),
  &TEMPLATE2(_BITPACK_,32_27),
  &TEMPLATE2(_BITPACK_,32_28),
  &TEMPLATE2(_BITPACK_,32_29),
  &TEMPLATE2(_BITPACK_,32_30),
  &TEMPLATE2(_BITPACK_,32_31),
  &TEMPLATE2(_BITPACK_,32_32)
};
unsigned char *TEMPLATE2(_BITPACK_,32)( uint32_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint32_t start, unsigned b) { return TEMPLATE2(_BITPACK_,a32)[ b](in, n, out, start); }

#define USIZE 64
unsigned char *TEMPLATE2(_BITPACK_,64_0)( uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { return out; }
unsigned char *TEMPLATE2(_BITPACK_,64_1)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*1); uint64_t v,x=0;do { BITPACK64_1( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_2)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*2); uint64_t v,x=0;do { BITPACK64_2( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_3)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*3); uint64_t v,x=0;do { BITPACK64_3( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_4)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*4); uint64_t v,x=0;do { BITPACK64_4( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_5)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*5); uint64_t v,x=0;do { BITPACK64_5( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_6)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*6); uint64_t v,x=0;do { BITPACK64_6( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_7)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*7); uint64_t v,x=0;do { BITPACK64_7( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_8)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*8); uint64_t v,x=0;do { BITPACK64_8( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_9)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*9); uint64_t v,x=0;do { BITPACK64_9( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_10)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*10); uint64_t v,x=0;do { BITPACK64_10( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_11)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*11); uint64_t v,x=0;do { BITPACK64_11( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_12)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*12); uint64_t v,x=0;do { BITPACK64_12( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_13)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*13); uint64_t v,x=0;do { BITPACK64_13( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_14)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*14); uint64_t v,x=0;do { BITPACK64_14( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_15)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*15); uint64_t v,x=0;do { BITPACK64_15( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_16)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*16); uint64_t v,x=0;do { BITPACK64_16( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_17)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*17); uint64_t v,x=0;do { BITPACK64_17( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_18)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*18); uint64_t v,x=0;do { BITPACK64_18( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_19)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*19); uint64_t v,x=0;do { BITPACK64_19( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_20)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*20); uint64_t v,x=0;do { BITPACK64_20( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_21)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*21); uint64_t v,x=0;do { BITPACK64_21( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_22)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*22); uint64_t v,x=0;do { BITPACK64_22( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_23)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*23); uint64_t v,x=0;do { BITPACK64_23( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_24)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*24); uint64_t v,x=0;do { BITPACK64_24( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_25)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*25); uint64_t v,x=0;do { BITPACK64_25( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_26)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*26); uint64_t v,x=0;do { BITPACK64_26( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_27)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*27); uint64_t v,x=0;do { BITPACK64_27( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_28)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*28); uint64_t v,x=0;do { BITPACK64_28( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_29)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*29); uint64_t v,x=0;do { BITPACK64_29( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_30)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*30); uint64_t v,x=0;do { BITPACK64_30( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_31)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*31); uint64_t v,x=0;do { BITPACK64_31( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_32)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*32); uint64_t v,x=0;do { BITPACK64_32( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_33)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*33); uint64_t v,x=0;do { BITPACK64_33( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_34)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*34); uint64_t v,x=0;do { BITPACK64_34( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_35)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*35); uint64_t v,x=0;do { BITPACK64_35( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_36)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*36); uint64_t v,x=0;do { BITPACK64_36( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_37)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*37); uint64_t v,x=0;do { BITPACK64_37( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_38)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*38); uint64_t v,x=0;do { BITPACK64_38( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_39)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*39); uint64_t v,x=0;do { BITPACK64_39( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_40)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*40); uint64_t v,x=0;do { BITPACK64_40( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_41)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*41); uint64_t v,x=0;do { BITPACK64_41( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_42)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*42); uint64_t v,x=0;do { BITPACK64_42( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_43)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*43); uint64_t v,x=0;do { BITPACK64_43( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_44)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*44); uint64_t v,x=0;do { BITPACK64_44( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_45)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*45); uint64_t v,x=0;do { BITPACK64_45( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_46)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*46); uint64_t v,x=0;do { BITPACK64_46( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_47)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*47); uint64_t v,x=0;do { BITPACK64_47( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_48)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*48); uint64_t v,x=0;do { BITPACK64_48( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_49)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*49); uint64_t v,x=0;do { BITPACK64_49( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_50)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*50); uint64_t v,x=0;do { BITPACK64_50( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_51)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*51); uint64_t v,x=0;do { BITPACK64_51( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_52)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*52); uint64_t v,x=0;do { BITPACK64_52( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_53)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*53); uint64_t v,x=0;do { BITPACK64_53( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_54)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*54); uint64_t v,x=0;do { BITPACK64_54( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_55)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*55); uint64_t v,x=0;do { BITPACK64_55( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_56)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*56); uint64_t v,x=0;do { BITPACK64_56( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_57)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*57); uint64_t v,x=0;do { BITPACK64_57( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_58)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*58); uint64_t v,x=0;do { BITPACK64_58( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_59)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*59); uint64_t v,x=0;do { BITPACK64_59( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_60)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*60); uint64_t v,x=0;do { BITPACK64_60( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_61)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*61); uint64_t v,x=0;do { BITPACK64_61( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_62)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*62); uint64_t v,x=0;do { BITPACK64_62( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_63)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*63); uint64_t v,x=0;do { BITPACK64_63( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
unsigned char *TEMPLATE2(_BITPACK_,64_64)(uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start ) { unsigned char *out_=out+PAD8(n*64); uint64_t v,x=0;do { BITPACK64_64( in, out, start); PREFETCH(in+512,0); } while(out<out_); return out_; }
BITPACK_D64 TEMPLATE2(_BITPACK_,a64)[] = {
  &TEMPLATE2(_BITPACK_,64_0),
  &TEMPLATE2(_BITPACK_,64_1),
  &TEMPLATE2(_BITPACK_,64_2),
  &TEMPLATE2(_BITPACK_,64_3),
  &TEMPLATE2(_BITPACK_,64_4),
  &TEMPLATE2(_BITPACK_,64_5),
  &TEMPLATE2(_BITPACK_,64_6),
  &TEMPLATE2(_BITPACK_,64_7),
  &TEMPLATE2(_BITPACK_,64_8),
  &TEMPLATE2(_BITPACK_,64_9),
  &TEMPLATE2(_BITPACK_,64_10),
  &TEMPLATE2(_BITPACK_,64_11),
  &TEMPLATE2(_BITPACK_,64_12),
  &TEMPLATE2(_BITPACK_,64_13),
  &TEMPLATE2(_BITPACK_,64_14),
  &TEMPLATE2(_BITPACK_,64_15),
  &TEMPLATE2(_BITPACK_,64_16),
  &TEMPLATE2(_BITPACK_,64_17),
  &TEMPLATE2(_BITPACK_,64_18),
  &TEMPLATE2(_BITPACK_,64_19),
  &TEMPLATE2(_BITPACK_,64_20),
  &TEMPLATE2(_BITPACK_,64_21),
  &TEMPLATE2(_BITPACK_,64_22),
  &TEMPLATE2(_BITPACK_,64_23),
  &TEMPLATE2(_BITPACK_,64_24),
  &TEMPLATE2(_BITPACK_,64_25),
  &TEMPLATE2(_BITPACK_,64_26),
  &TEMPLATE2(_BITPACK_,64_27),
  &TEMPLATE2(_BITPACK_,64_28),
  &TEMPLATE2(_BITPACK_,64_29),
  &TEMPLATE2(_BITPACK_,64_30),
  &TEMPLATE2(_BITPACK_,64_31),
  &TEMPLATE2(_BITPACK_,64_32),
  &TEMPLATE2(_BITPACK_,64_33),
  &TEMPLATE2(_BITPACK_,64_34),
  &TEMPLATE2(_BITPACK_,64_35),
  &TEMPLATE2(_BITPACK_,64_36),
  &TEMPLATE2(_BITPACK_,64_37),
  &TEMPLATE2(_BITPACK_,64_38),
  &TEMPLATE2(_BITPACK_,64_39),
  &TEMPLATE2(_BITPACK_,64_40),
  &TEMPLATE2(_BITPACK_,64_41),
  &TEMPLATE2(_BITPACK_,64_42),
  &TEMPLATE2(_BITPACK_,64_43),
  &TEMPLATE2(_BITPACK_,64_44),
  &TEMPLATE2(_BITPACK_,64_45),
  &TEMPLATE2(_BITPACK_,64_46),
  &TEMPLATE2(_BITPACK_,64_47),
  &TEMPLATE2(_BITPACK_,64_48),
  &TEMPLATE2(_BITPACK_,64_49),
  &TEMPLATE2(_BITPACK_,64_50),
  &TEMPLATE2(_BITPACK_,64_51),
  &TEMPLATE2(_BITPACK_,64_52),
  &TEMPLATE2(_BITPACK_,64_53),
  &TEMPLATE2(_BITPACK_,64_54),
  &TEMPLATE2(_BITPACK_,64_55),
  &TEMPLATE2(_BITPACK_,64_56),
  &TEMPLATE2(_BITPACK_,64_57),
  &TEMPLATE2(_BITPACK_,64_58),
  &TEMPLATE2(_BITPACK_,64_59),
  &TEMPLATE2(_BITPACK_,64_60),
  &TEMPLATE2(_BITPACK_,64_61),
  &TEMPLATE2(_BITPACK_,64_62),
  &TEMPLATE2(_BITPACK_,64_63),
  &TEMPLATE2(_BITPACK_,64_64)
};
unsigned char *TEMPLATE2(_BITPACK_,64)( uint64_t *__restrict in, unsigned n, const unsigned char *__restrict out , uint64_t start, unsigned b) { return TEMPLATE2(_BITPACK_,a64)[ b](in, n, out, start); }

#endif
#endif //IP9

//---------------------------------------------------------
#define BITBLK128V16_1(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 1, iv),  1));\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 2, iv),  2));\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 3, iv),  3));\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 4, iv),  4));\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 5, iv),  5));\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 6, iv),  6));\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 7, iv),  7));\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 8, iv),  8));\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 9, iv),  9));\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+10, iv), 10));\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+11, iv), 11));\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+12, iv), 12));\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+13, iv), 13));\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+14, iv), 14));\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv), 15)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_1(ip,  op, parm) {\
  BITBLK128V16_1(ip, 0, op, parm); IPPE(ip); OPPE(op += 1*4/sizeof(op[0]));\
}

#define BITBLK128V16_2(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*8+ 0, iv, parm); ov =                                      IP16(ip, i*8+ 0, iv);\
  VI16(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 1, iv),  2));\
  VI16(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 2, iv),  4));\
  VI16(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 3, iv),  6));\
  VI16(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 4, iv),  8));\
  VI16(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 5, iv), 10));\
  VI16(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 6, iv), 12));\
  VI16(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 7, iv), 14)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_2(ip,  op, parm) {\
  BITBLK128V16_2(ip, 0, op, parm);\
  BITBLK128V16_2(ip, 1, op, parm); IPPE(ip); OPPE(op += 2*4/sizeof(op[0]));\
}

#define BITBLK128V16_3(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 1, iv),  3));\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 2, iv),  6));\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 3, iv),  9));\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 4, iv), 12));\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 5, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 1);\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 6, iv),  2));\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 7, iv),  5));\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 8, iv),  8));\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 9, iv), 11));\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+10, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+11, iv),  1));\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+12, iv),  4));\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+13, iv),  7));\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+14, iv), 10));\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv), 13)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_3(ip,  op, parm) {\
  BITBLK128V16_3(ip, 0, op, parm);  IPPE(ip); OPPE(op += 3*4/sizeof(op[0]));\
}

#define BITBLK128V16_4(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*4+ 0, iv, parm); ov =                                      IP16(ip, i*4+ 0, iv);\
  VI16(ip, i*4+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*4+ 1, iv),  4));\
  VI16(ip, i*4+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*4+ 2, iv),  8));\
  VI16(ip, i*4+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*4+ 3, iv), 12)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_4(ip,  op, parm) {\
  BITBLK128V16_4(ip, 0, op, parm);\
  BITBLK128V16_4(ip, 1, op, parm);\
  BITBLK128V16_4(ip, 2, op, parm);\
  BITBLK128V16_4(ip, 3, op, parm); IPPE(ip); OPPE(op += 4*4/sizeof(op[0]));\
}

#define BITBLK128V16_5(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 1, iv),  5));\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 2, iv), 10));\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 3, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 1);\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 4, iv),  4));\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 5, iv),  9));\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 6, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 7, iv),  3));\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 8, iv),  8));\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 9, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 3);\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+10, iv),  2));\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+11, iv),  7));\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+12, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+13, iv),  1));\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+14, iv),  6));\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv), 11)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_5(ip,  op, parm) {\
  BITBLK128V16_5(ip, 0, op, parm); IPPE(ip); OPPE(op += 5*4/sizeof(op[0]));\
}

#define BITBLK128V16_6(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*8+ 0, iv, parm); ov =                                      IP16(ip, i*8+ 0, iv);\
  VI16(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 1, iv),  6));\
  VI16(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 2, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 3, iv),  2));\
  VI16(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 4, iv),  8));\
  VI16(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 5, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 6, iv),  4));\
  VI16(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 7, iv), 10)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_6(ip,  op, parm) {\
  BITBLK128V16_6(ip, 0, op, parm);\
  BITBLK128V16_6(ip, 1, op, parm); IPPE(ip); OPPE(op += 6*4/sizeof(op[0]));\
}

#define BITBLK128V16_7(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 1, iv),  7));\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 2, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 3, iv),  5));\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 4, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 5, iv),  3));\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 6, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 6);\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 7, iv),  1));\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 8, iv),  8));\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 9, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 1);\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+10, iv),  6));\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+11, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 3);\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+12, iv),  4));\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+13, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 5);\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+14, iv),  2));\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv),  9)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_7(ip,  op, parm) {\
  BITBLK128V16_7(ip, 0, op, parm); IPPE(ip); OPPE(op += 7*4/sizeof(op[0]));\
}

#define BITBLK128V16_8(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*2+ 0, iv, parm); ov =                                      IP16(ip, i*2+ 0, iv);\
  VI16(ip, i*2+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*2+ 1, iv),  8)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_8(ip,  op, parm) {\
  BITBLK128V16_8(ip, 0, op, parm);\
  BITBLK128V16_8(ip, 1, op, parm);\
  BITBLK128V16_8(ip, 2, op, parm);\
  BITBLK128V16_8(ip, 3, op, parm);\
  BITBLK128V16_8(ip, 4, op, parm);\
  BITBLK128V16_8(ip, 5, op, parm);\
  BITBLK128V16_8(ip, 6, op, parm);\
  BITBLK128V16_8(ip, 7, op, parm); IPPE(ip); OPPE(op += 8*4/sizeof(op[0]));\
}

#define BITBLK128V16_9(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 1, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 7);\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 2, iv),  2));\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 3, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 5);\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 4, iv),  4));\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 5, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 3);\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 6, iv),  6));\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 7, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 1);\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 8, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 8);\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 9, iv),  1));\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+10, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 6);\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+11, iv),  3));\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+12, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+13, iv),  5));\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+14, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv),  7)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_9(ip,  op, parm) {\
  BITBLK128V16_9(ip, 0, op, parm); IPPE(ip); OPPE(op += 9*4/sizeof(op[0]));\
}

#define BITBLK128V16_10(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*8+ 0, iv, parm); ov =                                      IP16(ip, i*8+ 0, iv);\
  VI16(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 1, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 6);\
  VI16(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 2, iv),  4));\
  VI16(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 3, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 4, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 8);\
  VI16(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 5, iv),  2));\
  VI16(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 6, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 7, iv),  6)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_10(ip,  op, parm) {\
  BITBLK128V16_10(ip, 0, op, parm);\
  BITBLK128V16_10(ip, 1, op, parm); IPPE(ip); OPPE(op += 10*4/sizeof(op[0]));\
}

#define BITBLK128V16_11(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 1, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 5);\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 2, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 10);\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 3, iv),  1));\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 4, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 5, iv), 7)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 9);\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 6, iv),  2));\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 7, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 3);\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 8, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 8);\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 9, iv),  3));\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+10, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+11, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 7);\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+12, iv),  4));\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+13, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 1);\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+14, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 6);\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv),  5)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_11(ip,  op, parm) {\
  BITBLK128V16_11(ip, 0, op, parm); IPPE(ip); OPPE(op += 11*4/sizeof(op[0]));\
}

#define BITBLK128V16_12(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*4+ 0, iv, parm); ov =                                      IP16(ip, i*4+ 0, iv);\
  VI16(ip, i*4+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*4+ 1, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*4+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*4+ 2, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 8);\
  VI16(ip, i*4+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*4+ 3, iv),  4)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_12(ip,  op, parm) {\
  BITBLK128V16_12(ip, 0, op, parm);\
  BITBLK128V16_12(ip, 1, op, parm);\
  BITBLK128V16_12(ip, 2, op, parm);\
  BITBLK128V16_12(ip, 3, op, parm); IPPE(ip); OPPE(op += 12*4/sizeof(op[0]));\
}

#define BITBLK128V16_13(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 1, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 3);\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 2, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 6);\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 3, iv), 7)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 9);\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 4, iv), 4)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 12);\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+ 5, iv),  1));\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 6, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 7, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 5);\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 8, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 8);\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 9, iv), 5)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 11);\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+10, iv),  2));\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+11, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 1);\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+12, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+13, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 7);\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+14, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 10);\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv),  3)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_13(ip,  op, parm) {\
  BITBLK128V16_13(ip, 0, op, parm); IPPE(ip); OPPE(op += 13*4/sizeof(op[0]));\
}

#define BITBLK128V16_14(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*8+ 0, iv, parm); ov =                                      IP16(ip, i*8+ 0, iv);\
  VI16(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 1, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 2, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 3, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 6);\
  VI16(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 4, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 8);\
  VI16(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 5, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 10);\
  VI16(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*8+ 6, iv), 4)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 12);\
  VI16(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*8+ 7, iv),  2)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_14(ip,  op, parm) {\
  BITBLK128V16_14(ip, 0, op, parm);\
  BITBLK128V16_14(ip, 1, op, parm); IPPE(ip); OPPE(op += 14*4/sizeof(op[0]));\
}

#define BITBLK128V16_15(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*16+ 0, iv, parm); ov =                                      IP16(ip, i*16+ 0, iv);\
  VI16(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 1, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 1);\
  VI16(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 2, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 2);\
  VI16(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 3, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 3);\
  VI16(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 4, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 4);\
  VI16(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 5, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 5);\
  VI16(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 6, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 6);\
  VI16(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 7, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 7);\
  VI16(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 8, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 8);\
  VI16(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+ 9, iv), 7)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 9);\
  VI16(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+10, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 10);\
  VI16(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+11, iv), 5)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 11);\
  VI16(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+12, iv), 4)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 12);\
  VI16(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+13, iv), 3)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 13);\
  VI16(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(iv = IP16(ip, i*16+14, iv), 2)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi16(iv, 14);\
  VI16(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi16(     IP16(ip, i*16+15, iv),  1)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_15(ip,  op, parm) {\
  BITBLK128V16_15(ip, 0, op, parm); IPPE(ip); OPPE(op += 15*4/sizeof(op[0]));\
}

#define BITBLK128V16_16(ip, i, op, parm) { __m128i ov,iv;\
  VI16(ip, i*1+ 0, iv, parm); ov =                                      IP16(ip, i*1+ 0, iv); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V16_16(ip,  op, parm) {\
  BITBLK128V16_16(ip, 0, op, parm);\
  BITBLK128V16_16(ip, 1, op, parm);\
  BITBLK128V16_16(ip, 2, op, parm);\
  BITBLK128V16_16(ip, 3, op, parm);\
  BITBLK128V16_16(ip, 4, op, parm);\
  BITBLK128V16_16(ip, 5, op, parm);\
  BITBLK128V16_16(ip, 6, op, parm);\
  BITBLK128V16_16(ip, 7, op, parm);\
  BITBLK128V16_16(ip, 8, op, parm);\
  BITBLK128V16_16(ip, 9, op, parm);\
  BITBLK128V16_16(ip, 10, op, parm);\
  BITBLK128V16_16(ip, 11, op, parm);\
  BITBLK128V16_16(ip, 12, op, parm);\
  BITBLK128V16_16(ip, 13, op, parm);\
  BITBLK128V16_16(ip, 14, op, parm);\
  BITBLK128V16_16(ip, 15, op, parm); IPPE(ip); OPPE(op += 16*4/sizeof(op[0]));\
}

#define BITBLK128V32_1(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv),  1));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv),  2));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv),  3));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv),  5));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv),  6));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv),  7));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv),  9));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv), 10));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv), 11));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv), 12));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv), 13));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv), 14));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv), 15));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv), 17));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv), 18));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv), 19));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv), 20));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv), 21));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv), 22));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv), 23));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv), 24));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv), 25));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv), 26));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv), 27));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv), 28));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv), 29));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv), 30));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 31)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_1(ip,  op, parm) {\
  BITBLK128V32_1(ip, 0, op, parm);  IPPE(ip); OPPE(op += 1*4/sizeof(op[0]));\
}

#define BITBLK128V32_2(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 1, iv),  2));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 2, iv),  4));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 3, iv),  6));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 4, iv),  8));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 5, iv), 10));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 6, iv), 12));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 7, iv), 14));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 9, iv), 18));\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+10, iv), 20));\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+11, iv), 22));\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+12, iv), 24));\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+13, iv), 26));\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+14, iv), 28));\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv), 30)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_2(ip,  op, parm) {\
  BITBLK128V32_2(ip, 0, op, parm);\
  BITBLK128V32_2(ip, 1, op, parm);  IPPE(ip); OPPE(op += 2*4/sizeof(op[0]));\
}

#define BITBLK128V32_3(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv),  3));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv),  6));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv),  9));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv), 12));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv), 15));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv), 18));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv), 21));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv), 24));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv), 27));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv),  1));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv),  7));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv), 10));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv), 13));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv), 19));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv), 22));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv), 25));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv), 28));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv),  2));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv),  5));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv), 11));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv), 14));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv), 17));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv), 20));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv), 23));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv), 26));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 29)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_3(ip,  op, parm) {\
  BITBLK128V32_3(ip, 0, op, parm);  IPPE(ip); OPPE(op += 3*4/sizeof(op[0]));\
}

#define BITBLK128V32_4(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 1, iv),  4));\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 2, iv),  8));\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 3, iv), 12));\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 4, iv), 16));\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 5, iv), 20));\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 6, iv), 24));\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 7, iv), 28)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_4(ip,  op, parm) {\
  BITBLK128V32_4(ip, 0, op, parm);\
  BITBLK128V32_4(ip, 1, op, parm);\
  BITBLK128V32_4(ip, 2, op, parm);\
  BITBLK128V32_4(ip, 3, op, parm);  IPPE(ip); OPPE(op += 4*4/sizeof(op[0]));\
}

#define BITBLK128V32_5(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv),  5));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv), 10));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv), 15));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv), 20));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv), 25));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv),  3));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv), 13));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv), 18));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv), 23));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv),  1));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv),  6));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv), 11));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv), 21));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv), 26));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv),  4));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv),  9));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv), 14));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv), 19));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv), 24));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv),  2));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv),  7));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv), 12));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv), 17));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv), 22));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 27)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_5(ip,  op, parm) {\
  BITBLK128V32_5(ip, 0, op, parm);  IPPE(ip); OPPE(op += 5*4/sizeof(op[0]));\
}

#define BITBLK128V32_6(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 1, iv),  6));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 2, iv), 12));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 3, iv), 18));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 4, iv), 24));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 6, iv),  4));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 7, iv), 10));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 9, iv), 22));\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+10, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+11, iv),  2));\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+12, iv),  8));\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+13, iv), 14));\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+14, iv), 20));\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv), 26)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_6(ip,  op, parm) {\
  BITBLK128V32_6(ip, 0, op, parm);\
  BITBLK128V32_6(ip, 1, op, parm);  IPPE(ip); OPPE(op += 6*4/sizeof(op[0]));\
}

#define BITBLK128V32_7(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv),  7));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv), 14));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv), 21));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv),  3));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv), 10));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv), 17));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv), 24));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv),  6));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv), 13));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv), 20));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv),  2));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv),  9));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv), 23));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv),  5));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv), 12));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv), 19));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv),  1));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv), 15));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv), 22));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv),  4));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv), 11));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv), 18));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 25)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_7(ip,  op, parm) {\
  BITBLK128V32_7(ip, 0, op, parm);  IPPE(ip); OPPE(op += 7*4/sizeof(op[0]));\
}

#define BITBLK128V32_8(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*4+ 0, iv, parm); ov =                                      IP32(ip, i*4+ 0, iv);\
  VI32(ip, i*4+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*4+ 1, iv),  8));\
  VI32(ip, i*4+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*4+ 2, iv), 16));\
  VI32(ip, i*4+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*4+ 3, iv), 24)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_8(ip,  op, parm) {\
  BITBLK128V32_8(ip, 0, op, parm);\
  BITBLK128V32_8(ip, 1, op, parm);\
  BITBLK128V32_8(ip, 2, op, parm);\
  BITBLK128V32_8(ip, 3, op, parm);\
  BITBLK128V32_8(ip, 4, op, parm);\
  BITBLK128V32_8(ip, 5, op, parm);\
  BITBLK128V32_8(ip, 6, op, parm);\
  BITBLK128V32_8(ip, 7, op, parm);  IPPE(ip); OPPE(op += 8*4/sizeof(op[0]));\
}

#define BITBLK128V32_9(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv),  9));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv), 18));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv), 13));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv), 22));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv), 17));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv),  3));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv), 12));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv), 21));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv),  7));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv),  2));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv), 11));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv), 20));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv),  6));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv), 15));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv),  1));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv), 10));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv), 19));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv),  5));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv), 14));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 23)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_9(ip,  op, parm) {\
  BITBLK128V32_9(ip, 0, op, parm);  IPPE(ip); OPPE(op += 9*4/sizeof(op[0]));\
}

#define BITBLK128V32_10(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 1, iv), 10));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 2, iv), 20));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 4, iv),  8));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 5, iv), 18));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 7, iv),  6));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+10, iv),  4));\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+11, iv), 14));\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+12, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+13, iv),  2));\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+14, iv), 12));\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv), 22)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_10(ip,  op, parm) {\
  BITBLK128V32_10(ip, 0, op, parm);\
  BITBLK128V32_10(ip, 1, op, parm);  IPPE(ip); OPPE(op += 10*4/sizeof(op[0]));\
}

#define BITBLK128V32_11(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv), 11));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv),  1));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv), 12));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv),  2));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv), 13));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv),  3));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv), 14));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv), 15));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv),  5));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv),  6));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv), 17));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv),  7));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv), 18));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv), 19));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv),  9));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv), 20));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv), 10));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 21)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_11(ip,  op, parm) {\
  BITBLK128V32_11(ip, 0, op, parm);  IPPE(ip); OPPE(op += 11*4/sizeof(op[0]));\
}

#define BITBLK128V32_12(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 1, iv), 12));\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 2, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 3, iv),  4));\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 4, iv), 16));\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 5, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 6, iv),  8));\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 7, iv), 20)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_12(ip,  op, parm) {\
  BITBLK128V32_12(ip, 0, op, parm);\
  BITBLK128V32_12(ip, 1, op, parm);\
  BITBLK128V32_12(ip, 2, op, parm);\
  BITBLK128V32_12(ip, 3, op, parm);  IPPE(ip); OPPE(op += 12*4/sizeof(op[0]));\
}

#define BITBLK128V32_13(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv), 13));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv),  7));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv),  1));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv), 14));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv),  2));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv), 15));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv),  9));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv),  3));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv), 10));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv),  4));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv), 17));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv), 11));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv),  5));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv), 18));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv), 12));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv),  6));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 19)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_13(ip,  op, parm) {\
  BITBLK128V32_13(ip, 0, op, parm);  IPPE(ip); OPPE(op += 13*4/sizeof(op[0]));\
}

#define BITBLK128V32_14(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 1, iv), 14));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 3, iv), 10));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 5, iv),  6));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 7, iv),  2));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+10, iv), 12));\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+11, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+12, iv),  8));\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+13, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+14, iv),  4));\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv), 18)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_14(ip,  op, parm) {\
  BITBLK128V32_14(ip, 0, op, parm);\
  BITBLK128V32_14(ip, 1, op, parm);  IPPE(ip); OPPE(op += 14*4/sizeof(op[0]));\
}

#define BITBLK128V32_15(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 1, iv), 15));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv), 13));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv), 11));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv),  9));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv),  7));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv),  5));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv),  3));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+15, iv),  1));\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv), 14));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv), 12));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv), 10));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv),  6));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv),  4));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+30, iv),  2));\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 17)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_15(ip,  op, parm) {\
  BITBLK128V32_15(ip, 0, op, parm);  IPPE(ip); OPPE(op += 15*4/sizeof(op[0]));\
}

#define BITBLK128V32_16(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*2+ 0, iv, parm); ov =                                      IP32(ip, i*2+ 0, iv);\
  VI32(ip, i*2+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*2+ 1, iv), 16)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_16(ip,  op, parm) {\
  BITBLK128V32_16(ip, 0, op, parm);\
  BITBLK128V32_16(ip, 1, op, parm);\
  BITBLK128V32_16(ip, 2, op, parm);\
  BITBLK128V32_16(ip, 3, op, parm);\
  BITBLK128V32_16(ip, 4, op, parm);\
  BITBLK128V32_16(ip, 5, op, parm);\
  BITBLK128V32_16(ip, 6, op, parm);\
  BITBLK128V32_16(ip, 7, op, parm);\
  BITBLK128V32_16(ip, 8, op, parm);\
  BITBLK128V32_16(ip, 9, op, parm);\
  BITBLK128V32_16(ip, 10, op, parm);\
  BITBLK128V32_16(ip, 11, op, parm);\
  BITBLK128V32_16(ip, 12, op, parm);\
  BITBLK128V32_16(ip, 13, op, parm);\
  BITBLK128V32_16(ip, 14, op, parm);\
  BITBLK128V32_16(ip, 15, op, parm);  IPPE(ip); OPPE(op += 16*4/sizeof(op[0]));\
}

#define BITBLK128V32_17(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv),  2));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv),  6));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv), 10));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv), 12));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv), 14));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv),  1));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv),  3));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv),  5));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv),  7));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv),  9));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv), 11));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv), 13));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 15)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_17(ip,  op, parm) {\
  BITBLK128V32_17(ip, 0, op, parm);  IPPE(ip); OPPE(op += 17*4/sizeof(op[0]));\
}

#define BITBLK128V32_18(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 2, iv),  4));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 4, iv),  8));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 6, iv), 12));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 9, iv),  2));\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+10, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+11, iv),  6));\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+12, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+13, iv), 10));\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+14, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv), 14)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_18(ip,  op, parm) {\
  BITBLK128V32_18(ip, 0, op, parm);\
  BITBLK128V32_18(ip, 1, op, parm);  IPPE(ip); OPPE(op += 18*4/sizeof(op[0]));\
}

#define BITBLK128V32_19(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv),  6));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv), 12));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv),  5));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv), 11));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv), 10));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv),  3));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv),  9));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 17);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv),  2));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv),  1));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv),  7));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 13)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_19(ip,  op, parm) {\
  BITBLK128V32_19(ip, 0, op, parm);  IPPE(ip); OPPE(op += 19*4/sizeof(op[0]));\
}

#define BITBLK128V32_20(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 1, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 2, iv),  8));\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 3, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 4, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 5, iv),  4));\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 6, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 7, iv), 12)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_20(ip,  op, parm) {\
  BITBLK128V32_20(ip, 0, op, parm);\
  BITBLK128V32_20(ip, 1, op, parm);\
  BITBLK128V32_20(ip, 2, op, parm);\
  BITBLK128V32_20(ip, 3, op, parm);  IPPE(ip); OPPE(op += 20*4/sizeof(op[0]));\
}

#define BITBLK128V32_21(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 2, iv), 10));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 5, iv),  9));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+11, iv),  7));\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv),  6));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv),  5));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 17);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+20, iv),  4));\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+23, iv),  3));\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 19);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+26, iv),  2));\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+29, iv),  1));\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv), 11)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_21(ip,  op, parm) {\
  BITBLK128V32_21(ip, 0, op, parm);  IPPE(ip); OPPE(op += 21*4/sizeof(op[0]));\
}

#define BITBLK128V32_22(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 3, iv),  2));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 6, iv),  4));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 9, iv),  6));\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+10, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+11, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+12, iv),  8));\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+13, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+14, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv), 10)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_22(ip,  op, parm) {\
  BITBLK128V32_22(ip, 0, op, parm);\
  BITBLK128V32_22(ip, 1, op, parm);  IPPE(ip); OPPE(op += 22*4/sizeof(op[0]));\
}

#define BITBLK128V32_23(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 3, iv),  5));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 22);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 7, iv),  1));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 17);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv),  6));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 21);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+14, iv),  2));\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+17, iv),  7));\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv),  3));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 19);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+28, iv),  4));\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv),  9)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_23(ip,  op, parm) {\
  BITBLK128V32_23(ip, 0, op, parm);  IPPE(ip); OPPE(op += 23*4/sizeof(op[0]));\
}

#define BITBLK128V32_24(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*4+ 0, iv, parm); ov =                                      IP32(ip, i*4+ 0, iv);\
  VI32(ip, i*4+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*4+ 1, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*4+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*4+ 2, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*4+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*4+ 3, iv),  8)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_24(ip,  op, parm) {\
  BITBLK128V32_24(ip, 0, op, parm);\
  BITBLK128V32_24(ip, 1, op, parm);\
  BITBLK128V32_24(ip, 2, op, parm);\
  BITBLK128V32_24(ip, 3, op, parm);\
  BITBLK128V32_24(ip, 4, op, parm);\
  BITBLK128V32_24(ip, 5, op, parm);\
  BITBLK128V32_24(ip, 6, op, parm);\
  BITBLK128V32_24(ip, 7, op, parm);  IPPE(ip); OPPE(op += 24*4/sizeof(op[0]));\
}

#define BITBLK128V32_25(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 21);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 17);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 24);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 9, iv),  1));\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+13, iv),  5));\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 23);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+18, iv),  2));\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 19);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+22, iv),  6));\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 22);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+27, iv),  3));\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv),  7)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_25(ip,  op, parm) {\
  BITBLK128V32_25(ip, 0, op, parm);  IPPE(ip); OPPE(op += 25*4/sizeof(op[0]));\
}

#define BITBLK128V32_26(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 24);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+ 5, iv),  2));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 22);\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+10, iv),  4));\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+11, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+12, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+13, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+14, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv),  6)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_26(ip,  op, parm) {\
  BITBLK128V32_26(ip, 0, op, parm);\
  BITBLK128V32_26(ip, 1, op, parm);  IPPE(ip); OPPE(op += 26*4/sizeof(op[0]));\
}

#define BITBLK128V32_27(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 7)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 25);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+ 6, iv),  2));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 23);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 21);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 26);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+19, iv),  1));\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 19);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 24);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+25, iv),  3));\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 17);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 22);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv),  5)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_27(ip,  op, parm) {\
  BITBLK128V32_27(ip, 0, op, parm);  IPPE(ip); OPPE(op += 27*4/sizeof(op[0]));\
}

#define BITBLK128V32_28(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 1, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 2, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 3, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 4, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 5, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*8+ 6, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 24);\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*8+ 7, iv),  4)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_28(ip,  op, parm) {\
  BITBLK128V32_28(ip, 0, op, parm);\
  BITBLK128V32_28(ip, 1, op, parm);\
  BITBLK128V32_28(ip, 2, op, parm);\
  BITBLK128V32_28(ip, 3, op, parm);  IPPE(ip); OPPE(op += 28*4/sizeof(op[0]));\
}

#define BITBLK128V32_29(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 21);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 24);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 5)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 27);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+10, iv),  2));\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 19);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 22);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 7)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 25);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 4)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 28);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+21, iv),  1));\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 17);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 23);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 26);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv),  3)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_29(ip,  op, parm) {\
  BITBLK128V32_29(ip, 0, op, parm);  IPPE(ip); OPPE(op += 29*4/sizeof(op[0]));\
}

#define BITBLK128V32_30(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*16+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+10, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*16+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+11, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 22);\
  VI32(ip, i*16+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+12, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 24);\
  VI32(ip, i*16+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+13, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 26);\
  VI32(ip, i*16+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*16+14, iv), 4)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 28);\
  VI32(ip, i*16+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*16+15, iv),  2)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_30(ip,  op, parm) {\
  BITBLK128V32_30(ip, 0, op, parm);\
  BITBLK128V32_30(ip, 1, op, parm);  IPPE(ip); OPPE(op += 30*4/sizeof(op[0]));\
}

#define BITBLK128V32_31(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 31)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 30)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 29)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 27)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 26)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 25)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 7);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 23)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 9);\
  VI32(ip, i*32+10, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+10, iv), 22)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 10);\
  VI32(ip, i*32+11, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+11, iv), 21)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 11);\
  VI32(ip, i*32+12, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+12, iv), 20)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 12);\
  VI32(ip, i*32+13, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+13, iv), 19)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 13);\
  VI32(ip, i*32+14, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+14, iv), 18)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 14);\
  VI32(ip, i*32+15, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+15, iv), 17)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 15);\
  VI32(ip, i*32+16, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+17, iv), 15)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 17);\
  VI32(ip, i*32+18, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+18, iv), 14)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 18);\
  VI32(ip, i*32+19, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+19, iv), 13)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 19);\
  VI32(ip, i*32+20, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+20, iv), 12)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 20);\
  VI32(ip, i*32+21, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+21, iv), 11)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 21);\
  VI32(ip, i*32+22, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+22, iv), 10)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 22);\
  VI32(ip, i*32+23, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+23, iv), 9)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 23);\
  VI32(ip, i*32+24, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+24, iv), 8)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 24);\
  VI32(ip, i*32+25, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+25, iv), 7)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 25);\
  VI32(ip, i*32+26, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+26, iv), 6)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 26);\
  VI32(ip, i*32+27, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+27, iv), 5)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 27);\
  VI32(ip, i*32+28, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+28, iv), 4)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 28);\
  VI32(ip, i*32+29, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+29, iv), 3)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 29);\
  VI32(ip, i*32+30, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(iv = IP32(ip, i*32+30, iv), 2)); _mm_storeu_si128(op++, ov); ov =  mm_srli_epi32(iv, 30);\
  VI32(ip, i*32+31, iv, parm); ov = _mm_or_si128(ov,  mm_slli_epi32(     IP32(ip, i*32+31, iv),  1)); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_31(ip,  op, parm) {\
  BITBLK128V32_31(ip, 0, op, parm);  IPPE(ip); OPPE(op += 31*4/sizeof(op[0]));\
}

#define BITBLK128V32_32(ip, i, op, parm) { __m128i ov,iv;\
  VI32(ip, i*1+ 0, iv, parm); ov =                                      IP32(ip, i*1+ 0, iv); _mm_storeu_si128((__m128i *)op++, ov);\
}

#define BITPACK128V32_32(ip,  op, parm) {\
  BITBLK128V32_32(ip, 0, op, parm);\
  BITBLK128V32_32(ip, 1, op, parm);\
  BITBLK128V32_32(ip, 2, op, parm);\
  BITBLK128V32_32(ip, 3, op, parm);\
  BITBLK128V32_32(ip, 4, op, parm);\
  BITBLK128V32_32(ip, 5, op, parm);\
  BITBLK128V32_32(ip, 6, op, parm);\
  BITBLK128V32_32(ip, 7, op, parm);\
  BITBLK128V32_32(ip, 8, op, parm);\
  BITBLK128V32_32(ip, 9, op, parm);\
  BITBLK128V32_32(ip, 10, op, parm);\
  BITBLK128V32_32(ip, 11, op, parm);\
  BITBLK128V32_32(ip, 12, op, parm);\
  BITBLK128V32_32(ip, 13, op, parm);\
  BITBLK128V32_32(ip, 14, op, parm);\
  BITBLK128V32_32(ip, 15, op, parm);\
  BITBLK128V32_32(ip, 16, op, parm);\
  BITBLK128V32_32(ip, 17, op, parm);\
  BITBLK128V32_32(ip, 18, op, parm);\
  BITBLK128V32_32(ip, 19, op, parm);\
  BITBLK128V32_32(ip, 20, op, parm);\
  BITBLK128V32_32(ip, 21, op, parm);\
  BITBLK128V32_32(ip, 22, op, parm);\
  BITBLK128V32_32(ip, 23, op, parm);\
  BITBLK128V32_32(ip, 24, op, parm);\
  BITBLK128V32_32(ip, 25, op, parm);\
  BITBLK128V32_32(ip, 26, op, parm);\
  BITBLK128V32_32(ip, 27, op, parm);\
  BITBLK128V32_32(ip, 28, op, parm);\
  BITBLK128V32_32(ip, 29, op, parm);\
  BITBLK128V32_32(ip, 30, op, parm);\
  BITBLK128V32_32(ip, 31, op, parm);  IPPE(ip); OPPE(op += 32*4/sizeof(op[0]));\
}

#define BITBLK256V32_1(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv),  1));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv),  2));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv),  3));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv),  5));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv),  6));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv),  7));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv),  9));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv), 10));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv), 11));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv), 12));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv), 13));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv), 14));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv), 15));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv), 17));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv), 18));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv), 19));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv), 20));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv), 21));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv), 22));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv), 23));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv), 24));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv), 25));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv), 26));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv), 27));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv), 28));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv), 29));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv), 30));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 31)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_1(ip,  op, parm) {\
  BITBLK256V32_1(ip, 0, op, parm);  IPPE(ip); OPPE(op += 1*4/sizeof(op[0]));\
}

#define BITBLK256V32_2(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 1, iv),  2));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 2, iv),  4));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 3, iv),  6));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 4, iv),  8));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 5, iv), 10));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 6, iv), 12));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 7, iv), 14));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 9, iv), 18));\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+10, iv), 20));\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+11, iv), 22));\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+12, iv), 24));\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+13, iv), 26));\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+14, iv), 28));\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv), 30)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_2(ip,  op, parm) {\
  BITBLK256V32_2(ip, 0, op, parm);\
  BITBLK256V32_2(ip, 1, op, parm);  IPPE(ip); OPPE(op += 2*4/sizeof(op[0]));\
}

#define BITBLK256V32_3(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv),  3));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv),  6));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv),  9));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv), 12));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv), 15));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv), 18));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv), 21));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv), 24));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv), 27));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv),  1));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv),  7));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv), 10));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv), 13));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv), 19));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv), 22));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv), 25));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv), 28));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv),  2));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv),  5));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv), 11));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv), 14));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv), 17));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv), 20));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv), 23));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv), 26));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 29)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_3(ip,  op, parm) {\
  BITBLK256V32_3(ip, 0, op, parm);  IPPE(ip); OPPE(op += 3*4/sizeof(op[0]));\
}

#define BITBLK256V32_4(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 1, iv),  4));\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 2, iv),  8));\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 3, iv), 12));\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 4, iv), 16));\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 5, iv), 20));\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 6, iv), 24));\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 7, iv), 28)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_4(ip,  op, parm) {\
  BITBLK256V32_4(ip, 0, op, parm);\
  BITBLK256V32_4(ip, 1, op, parm);\
  BITBLK256V32_4(ip, 2, op, parm);\
  BITBLK256V32_4(ip, 3, op, parm);  IPPE(ip); OPPE(op += 4*4/sizeof(op[0]));\
}

#define BITBLK256V32_5(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv),  5));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv), 10));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv), 15));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv), 20));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv), 25));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv),  3));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv), 13));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv), 18));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv), 23));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv),  1));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv),  6));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv), 11));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv), 21));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv), 26));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv),  4));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv),  9));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv), 14));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv), 19));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv), 24));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv),  2));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv),  7));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv), 12));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv), 17));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv), 22));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 27)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_5(ip,  op, parm) {\
  BITBLK256V32_5(ip, 0, op, parm);  IPPE(ip); OPPE(op += 5*4/sizeof(op[0]));\
}

#define BITBLK256V32_6(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 1, iv),  6));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 2, iv), 12));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 3, iv), 18));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 4, iv), 24));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 6, iv),  4));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 7, iv), 10));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 9, iv), 22));\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+10, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+11, iv),  2));\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+12, iv),  8));\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+13, iv), 14));\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+14, iv), 20));\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv), 26)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_6(ip,  op, parm) {\
  BITBLK256V32_6(ip, 0, op, parm);\
  BITBLK256V32_6(ip, 1, op, parm);  IPPE(ip); OPPE(op += 6*4/sizeof(op[0]));\
}

#define BITBLK256V32_7(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv),  7));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv), 14));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv), 21));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv),  3));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv), 10));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv), 17));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv), 24));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv),  6));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv), 13));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv), 20));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv),  2));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv),  9));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv), 23));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv),  5));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv), 12));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv), 19));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv),  1));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv), 15));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv), 22));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv),  4));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv), 11));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv), 18));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 25)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_7(ip,  op, parm) {\
  BITBLK256V32_7(ip, 0, op, parm);  IPPE(ip); OPPE(op += 7*4/sizeof(op[0]));\
}

#define BITBLK256V32_8(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*4+ 0, iv, parm); ov =                                      IP32(ip, i*4+ 0, iv);\
  VI32(ip, i*4+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*4+ 1, iv),  8));\
  VI32(ip, i*4+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*4+ 2, iv), 16));\
  VI32(ip, i*4+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*4+ 3, iv), 24)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_8(ip,  op, parm) {\
  BITBLK256V32_8(ip, 0, op, parm);\
  BITBLK256V32_8(ip, 1, op, parm);\
  BITBLK256V32_8(ip, 2, op, parm);\
  BITBLK256V32_8(ip, 3, op, parm);\
  BITBLK256V32_8(ip, 4, op, parm);\
  BITBLK256V32_8(ip, 5, op, parm);\
  BITBLK256V32_8(ip, 6, op, parm);\
  BITBLK256V32_8(ip, 7, op, parm);  IPPE(ip); OPPE(op += 8*4/sizeof(op[0]));\
}

#define BITBLK256V32_9(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv),  9));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv), 18));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv), 13));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv), 22));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv), 17));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv),  3));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv), 12));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv), 21));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv),  7));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv),  2));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv), 11));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv), 20));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv),  6));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv), 15));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv),  1));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv), 10));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv), 19));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv),  5));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv), 14));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 23)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_9(ip,  op, parm) {\
  BITBLK256V32_9(ip, 0, op, parm);  IPPE(ip); OPPE(op += 9*4/sizeof(op[0]));\
}

#define BITBLK256V32_10(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 1, iv), 10));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 2, iv), 20));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 4, iv),  8));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 5, iv), 18));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 7, iv),  6));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+10, iv),  4));\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+11, iv), 14));\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+12, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+13, iv),  2));\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+14, iv), 12));\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv), 22)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_10(ip,  op, parm) {\
  BITBLK256V32_10(ip, 0, op, parm);\
  BITBLK256V32_10(ip, 1, op, parm);  IPPE(ip); OPPE(op += 10*4/sizeof(op[0]));\
}

#define BITBLK256V32_11(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv), 11));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv),  1));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv), 12));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv),  2));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv), 13));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv),  3));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv), 14));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv), 15));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv),  5));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv),  6));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv), 17));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv),  7));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv), 18));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv), 19));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv),  9));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv), 20));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv), 10));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 21)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_11(ip,  op, parm) {\
  BITBLK256V32_11(ip, 0, op, parm);  IPPE(ip); OPPE(op += 11*4/sizeof(op[0]));\
}

#define BITBLK256V32_12(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 1, iv), 12));\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 2, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 3, iv),  4));\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 4, iv), 16));\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 5, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 6, iv),  8));\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 7, iv), 20)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_12(ip,  op, parm) {\
  BITBLK256V32_12(ip, 0, op, parm);\
  BITBLK256V32_12(ip, 1, op, parm);\
  BITBLK256V32_12(ip, 2, op, parm);\
  BITBLK256V32_12(ip, 3, op, parm);  IPPE(ip); OPPE(op += 12*4/sizeof(op[0]));\
}

#define BITBLK256V32_13(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv), 13));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv),  7));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv),  1));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv), 14));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv),  2));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv), 15));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv),  9));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv),  3));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv), 10));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv),  4));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv), 17));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv), 11));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv),  5));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv), 18));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv), 12));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv),  6));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 19)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_13(ip,  op, parm) {\
  BITBLK256V32_13(ip, 0, op, parm);  IPPE(ip); OPPE(op += 13*4/sizeof(op[0]));\
}

#define BITBLK256V32_14(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 1, iv), 14));\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 3, iv), 10));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 5, iv),  6));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 7, iv),  2));\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 8, iv), 16));\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+10, iv), 12));\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+11, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+12, iv),  8));\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+13, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+14, iv),  4));\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv), 18)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_14(ip,  op, parm) {\
  BITBLK256V32_14(ip, 0, op, parm);\
  BITBLK256V32_14(ip, 1, op, parm);  IPPE(ip); OPPE(op += 14*4/sizeof(op[0]));\
}

#define BITBLK256V32_15(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 1, iv), 15));\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv), 13));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv), 11));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv),  9));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv),  7));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv),  5));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv),  3));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+15, iv),  1));\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+16, iv), 16));\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv), 14));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv), 12));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv), 10));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv),  6));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv),  4));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+30, iv),  2));\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 17)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_15(ip,  op, parm) {\
  BITBLK256V32_15(ip, 0, op, parm);  IPPE(ip); OPPE(op += 15*4/sizeof(op[0]));\
}

#define BITBLK256V32_16(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*2+ 0, iv, parm); ov =                                      IP32(ip, i*2+ 0, iv);\
  VI32(ip, i*2+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*2+ 1, iv), 16)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_16(ip,  op, parm) {\
  BITBLK256V32_16(ip, 0, op, parm);\
  BITBLK256V32_16(ip, 1, op, parm);\
  BITBLK256V32_16(ip, 2, op, parm);\
  BITBLK256V32_16(ip, 3, op, parm);\
  BITBLK256V32_16(ip, 4, op, parm);\
  BITBLK256V32_16(ip, 5, op, parm);\
  BITBLK256V32_16(ip, 6, op, parm);\
  BITBLK256V32_16(ip, 7, op, parm);\
  BITBLK256V32_16(ip, 8, op, parm);\
  BITBLK256V32_16(ip, 9, op, parm);\
  BITBLK256V32_16(ip, 10, op, parm);\
  BITBLK256V32_16(ip, 11, op, parm);\
  BITBLK256V32_16(ip, 12, op, parm);\
  BITBLK256V32_16(ip, 13, op, parm);\
  BITBLK256V32_16(ip, 14, op, parm);\
  BITBLK256V32_16(ip, 15, op, parm);  IPPE(ip); OPPE(op += 16*4/sizeof(op[0]));\
}

#define BITBLK256V32_17(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv),  2));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv),  6));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv), 10));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv), 12));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv), 14));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv),  1));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv),  3));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv),  5));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv),  7));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv),  9));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv), 11));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv), 13));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 15)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_17(ip,  op, parm) {\
  BITBLK256V32_17(ip, 0, op, parm);  IPPE(ip); OPPE(op += 17*4/sizeof(op[0]));\
}

#define BITBLK256V32_18(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 2, iv),  4));\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 4, iv),  8));\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 6, iv), 12));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 9, iv),  2));\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+10, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+11, iv),  6));\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+12, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+13, iv), 10));\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+14, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv), 14)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_18(ip,  op, parm) {\
  BITBLK256V32_18(ip, 0, op, parm);\
  BITBLK256V32_18(ip, 1, op, parm);  IPPE(ip); OPPE(op += 18*4/sizeof(op[0]));\
}

#define BITBLK256V32_19(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv),  6));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv), 12));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv),  5));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv), 11));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv), 10));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv),  3));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv),  9));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 15)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 17);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv),  2));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv),  1));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv),  7));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 13)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_19(ip,  op, parm) {\
  BITBLK256V32_19(ip, 0, op, parm);  IPPE(ip); OPPE(op += 19*4/sizeof(op[0]));\
}

#define BITBLK256V32_20(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 1, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 2, iv),  8));\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 3, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 4, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 5, iv),  4));\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 6, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 7, iv), 12)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_20(ip,  op, parm) {\
  BITBLK256V32_20(ip, 0, op, parm);\
  BITBLK256V32_20(ip, 1, op, parm);\
  BITBLK256V32_20(ip, 2, op, parm);\
  BITBLK256V32_20(ip, 3, op, parm);  IPPE(ip); OPPE(op += 20*4/sizeof(op[0]));\
}

#define BITBLK256V32_21(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 2, iv), 10));\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 5, iv),  9));\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 8, iv),  8));\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+11, iv),  7));\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv),  6));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv),  5));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 15)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 17);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+20, iv),  4));\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+23, iv),  3));\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 13)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 19);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+26, iv),  2));\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+29, iv),  1));\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv), 11)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_21(ip,  op, parm) {\
  BITBLK256V32_21(ip, 0, op, parm);  IPPE(ip); OPPE(op += 21*4/sizeof(op[0]));\
}

#define BITBLK256V32_22(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 3, iv),  2));\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 6, iv),  4));\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 9, iv),  6));\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+10, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+11, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+12, iv),  8));\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+13, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+14, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv), 10)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_22(ip,  op, parm) {\
  BITBLK256V32_22(ip, 0, op, parm);\
  BITBLK256V32_22(ip, 1, op, parm);  IPPE(ip); OPPE(op += 22*4/sizeof(op[0]));\
}

#define BITBLK256V32_23(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 3, iv),  5));\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 10)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 22);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 7, iv),  1));\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 15)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 17);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv),  6));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 11)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 21);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+14, iv),  2));\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+17, iv),  7));\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv),  3));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+24, iv),  8));\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 13)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 19);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+28, iv),  4));\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv),  9)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_23(ip,  op, parm) {\
  BITBLK256V32_23(ip, 0, op, parm);  IPPE(ip); OPPE(op += 23*4/sizeof(op[0]));\
}

#define BITBLK256V32_24(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*4+ 0, iv, parm); ov =                                      IP32(ip, i*4+ 0, iv);\
  VI32(ip, i*4+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*4+ 1, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*4+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*4+ 2, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*4+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*4+ 3, iv),  8)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_24(ip,  op, parm) {\
  BITBLK256V32_24(ip, 0, op, parm);\
  BITBLK256V32_24(ip, 1, op, parm);\
  BITBLK256V32_24(ip, 2, op, parm);\
  BITBLK256V32_24(ip, 3, op, parm);\
  BITBLK256V32_24(ip, 4, op, parm);\
  BITBLK256V32_24(ip, 5, op, parm);\
  BITBLK256V32_24(ip, 6, op, parm);\
  BITBLK256V32_24(ip, 7, op, parm);  IPPE(ip); OPPE(op += 24*4/sizeof(op[0]));\
}

#define BITBLK256V32_25(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 11)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 21);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 4, iv),  4));\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 15)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 17);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 8)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 24);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 9, iv),  1));\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+13, iv),  5));\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 9)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 23);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+18, iv),  2));\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 13)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 19);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+22, iv),  6));\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 10)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 22);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+27, iv),  3));\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv),  7)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_25(ip,  op, parm) {\
  BITBLK256V32_25(ip, 0, op, parm);  IPPE(ip); OPPE(op += 25*4/sizeof(op[0]));\
}

#define BITBLK256V32_26(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 8)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 24);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+ 5, iv),  2));\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 10)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 22);\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+10, iv),  4));\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+11, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+12, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+13, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+14, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv),  6)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_26(ip,  op, parm) {\
  BITBLK256V32_26(ip, 0, op, parm);\
  BITBLK256V32_26(ip, 1, op, parm);  IPPE(ip); OPPE(op += 26*4/sizeof(op[0]));\
}

#define BITBLK256V32_27(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 7)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 25);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+ 6, iv),  2));\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 9)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 23);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+12, iv),  4));\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 11)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 21);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 6)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 26);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+19, iv),  1));\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 13)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 19);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 8)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 24);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+25, iv),  3));\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 15)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 17);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 10)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 22);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv),  5)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_27(ip,  op, parm) {\
  BITBLK256V32_27(ip, 0, op, parm);  IPPE(ip); OPPE(op += 27*4/sizeof(op[0]));\
}

#define BITBLK256V32_28(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*8+ 0, iv, parm); ov =                                      IP32(ip, i*8+ 0, iv);\
  VI32(ip, i*8+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 1, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*8+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 2, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*8+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 3, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*8+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 4, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*8+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 5, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*8+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*8+ 6, iv), 8)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 24);\
  VI32(ip, i*8+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*8+ 7, iv),  4)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_28(ip,  op, parm) {\
  BITBLK256V32_28(ip, 0, op, parm);\
  BITBLK256V32_28(ip, 1, op, parm);\
  BITBLK256V32_28(ip, 2, op, parm);\
  BITBLK256V32_28(ip, 3, op, parm);  IPPE(ip); OPPE(op += 28*4/sizeof(op[0]));\
}

#define BITBLK256V32_29(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 11)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 21);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 8)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 24);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 5)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 27);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+10, iv),  2));\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 13)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 19);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 10)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 22);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 7)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 25);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 4)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 28);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+21, iv),  1));\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 15)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 17);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 9)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 23);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 6)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 26);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv),  3)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_29(ip,  op, parm) {\
  BITBLK256V32_29(ip, 0, op, parm);  IPPE(ip); OPPE(op += 29*4/sizeof(op[0]));\
}

#define BITBLK256V32_30(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*16+ 0, iv, parm); ov =                                      IP32(ip, i*16+ 0, iv);\
  VI32(ip, i*16+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 1, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*16+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 2, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*16+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 3, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*16+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 4, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*16+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 5, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*16+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 6, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*16+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 7, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*16+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 8, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*16+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+ 9, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*16+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+10, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*16+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+11, iv), 10)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 22);\
  VI32(ip, i*16+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+12, iv), 8)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 24);\
  VI32(ip, i*16+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+13, iv), 6)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 26);\
  VI32(ip, i*16+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*16+14, iv), 4)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 28);\
  VI32(ip, i*16+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*16+15, iv),  2)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_30(ip,  op, parm) {\
  BITBLK256V32_30(ip, 0, op, parm);\
  BITBLK256V32_30(ip, 1, op, parm);  IPPE(ip); OPPE(op += 30*4/sizeof(op[0]));\
}

#define BITBLK256V32_31(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*32+ 0, iv, parm); ov =                                      IP32(ip, i*32+ 0, iv);\
  VI32(ip, i*32+ 1, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 1, iv), 31)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 1);\
  VI32(ip, i*32+ 2, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 2, iv), 30)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 2);\
  VI32(ip, i*32+ 3, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 3, iv), 29)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 3);\
  VI32(ip, i*32+ 4, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 4, iv), 28)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 4);\
  VI32(ip, i*32+ 5, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 5, iv), 27)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 5);\
  VI32(ip, i*32+ 6, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 6, iv), 26)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 6);\
  VI32(ip, i*32+ 7, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 7, iv), 25)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 7);\
  VI32(ip, i*32+ 8, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 8, iv), 24)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 8);\
  VI32(ip, i*32+ 9, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+ 9, iv), 23)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 9);\
  VI32(ip, i*32+10, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+10, iv), 22)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 10);\
  VI32(ip, i*32+11, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+11, iv), 21)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 11);\
  VI32(ip, i*32+12, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+12, iv), 20)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 12);\
  VI32(ip, i*32+13, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+13, iv), 19)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 13);\
  VI32(ip, i*32+14, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+14, iv), 18)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 14);\
  VI32(ip, i*32+15, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+15, iv), 17)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 15);\
  VI32(ip, i*32+16, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+16, iv), 16)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 16);\
  VI32(ip, i*32+17, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+17, iv), 15)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 17);\
  VI32(ip, i*32+18, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+18, iv), 14)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 18);\
  VI32(ip, i*32+19, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+19, iv), 13)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 19);\
  VI32(ip, i*32+20, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+20, iv), 12)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 20);\
  VI32(ip, i*32+21, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+21, iv), 11)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 21);\
  VI32(ip, i*32+22, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+22, iv), 10)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 22);\
  VI32(ip, i*32+23, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+23, iv), 9)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 23);\
  VI32(ip, i*32+24, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+24, iv), 8)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 24);\
  VI32(ip, i*32+25, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+25, iv), 7)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 25);\
  VI32(ip, i*32+26, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+26, iv), 6)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 26);\
  VI32(ip, i*32+27, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+27, iv), 5)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 27);\
  VI32(ip, i*32+28, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+28, iv), 4)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 28);\
  VI32(ip, i*32+29, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+29, iv), 3)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 29);\
  VI32(ip, i*32+30, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(iv = IP32(ip, i*32+30, iv), 2)); _mm256_storeu_si256(op++, ov); ov = _mm256_srli_epi32(iv, 30);\
  VI32(ip, i*32+31, iv, parm); ov = _mm256_or_si256(ov, _mm256_slli_epi32(     IP32(ip, i*32+31, iv),  1)); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_31(ip,  op, parm) {\
  BITBLK256V32_31(ip, 0, op, parm);  IPPE(ip); OPPE(op += 31*4/sizeof(op[0]));\
}

#define BITBLK256V32_32(ip, i, op, parm) { __m256i ov,iv;\
  VI32(ip, i*1+ 0, iv, parm); ov =                                      IP32(ip, i*1+ 0, iv); _mm256_storeu_si256((__m128i *)op++, ov);\
}

#define BITPACK256V32_32(ip,  op, parm) {\
  BITBLK256V32_32(ip, 0, op, parm);\
  BITBLK256V32_32(ip, 1, op, parm);\
  BITBLK256V32_32(ip, 2, op, parm);\
  BITBLK256V32_32(ip, 3, op, parm);\
  BITBLK256V32_32(ip, 4, op, parm);\
  BITBLK256V32_32(ip, 5, op, parm);\
  BITBLK256V32_32(ip, 6, op, parm);\
  BITBLK256V32_32(ip, 7, op, parm);\
  BITBLK256V32_32(ip, 8, op, parm);\
  BITBLK256V32_32(ip, 9, op, parm);\
  BITBLK256V32_32(ip, 10, op, parm);\
  BITBLK256V32_32(ip, 11, op, parm);\
  BITBLK256V32_32(ip, 12, op, parm);\
  BITBLK256V32_32(ip, 13, op, parm);\
  BITBLK256V32_32(ip, 14, op, parm);\
  BITBLK256V32_32(ip, 15, op, parm);\
  BITBLK256V32_32(ip, 16, op, parm);\
  BITBLK256V32_32(ip, 17, op, parm);\
  BITBLK256V32_32(ip, 18, op, parm);\
  BITBLK256V32_32(ip, 19, op, parm);\
  BITBLK256V32_32(ip, 20, op, parm);\
  BITBLK256V32_32(ip, 21, op, parm);\
  BITBLK256V32_32(ip, 22, op, parm);\
  BITBLK256V32_32(ip, 23, op, parm);\
  BITBLK256V32_32(ip, 24, op, parm);\
  BITBLK256V32_32(ip, 25, op, parm);\
  BITBLK256V32_32(ip, 26, op, parm);\
  BITBLK256V32_32(ip, 27, op, parm);\
  BITBLK256V32_32(ip, 28, op, parm);\
  BITBLK256V32_32(ip, 29, op, parm);\
  BITBLK256V32_32(ip, 30, op, parm);\
  BITBLK256V32_32(ip, 31, op, parm);  IPPE(ip); OPPE(op += 32*4/sizeof(op[0]));\
}

//#include "bitpack_0.h"
#define BITPACK128V16(_ip_, _nbits_, _op_, __parm) { __m128i *_ip=(__m128i *)_ip_,*_op=(__m128i *)_op_;\
  switch(_nbits_) {\
    case  0:                                           break;\
    case  1:{  BITPACK128V16_1( _ip, _op, __parm); } break;\
    case  2:{  BITPACK128V16_2( _ip, _op, __parm); } break;\
    case  3:{  BITPACK128V16_3( _ip, _op, __parm); } break;\
    case  4:{  BITPACK128V16_4( _ip, _op, __parm); } break;\
    case  5:{  BITPACK128V16_5( _ip, _op, __parm); } break;\
    case  6:{  BITPACK128V16_6( _ip, _op, __parm); } break;\
    case  7:{  BITPACK128V16_7( _ip, _op, __parm); } break;\
    case  8:{  BITPACK128V16_8( _ip, _op, __parm); } break;\
    case  9:{  BITPACK128V16_9( _ip, _op, __parm); } break;\
    case 10:{  BITPACK128V16_10(_ip, _op, __parm); } break;\
    case 11:{  BITPACK128V16_11(_ip, _op, __parm); } break;\
    case 12:{  BITPACK128V16_12(_ip, _op, __parm); } break;\
    case 13:{  BITPACK128V16_13(_ip, _op, __parm); } break;\
    case 14:{  BITPACK128V16_14(_ip, _op, __parm); } break;\
    case 15:{  BITPACK128V16_15(_ip, _op, __parm); } break;\
    case 16:{  BITPACK128V16_16(_ip, _op, __parm); } break;\
  }\
}

#define BITPACK128V32(_ip_, _nbits_, _op_, __parm) { __m128i *_ip=(__m128i *)_ip_,*_op=(__m128i *)_op_;\
  switch(_nbits_) {\
    case  0:                                           break;\
    case  1:{  BITPACK128V32_1( _ip, _op, __parm); } break;\
    case  2:{  BITPACK128V32_2( _ip, _op, __parm); } break;\
    case  3:{  BITPACK128V32_3( _ip, _op, __parm); } break;\
    case  4:{  BITPACK128V32_4( _ip, _op, __parm); } break;\
    case  5:{  BITPACK128V32_5( _ip, _op, __parm); } break;\
    case  6:{  BITPACK128V32_6( _ip, _op, __parm); } break;\
    case  7:{  BITPACK128V32_7( _ip, _op, __parm); } break;\
    case  8:{  BITPACK128V32_8( _ip, _op, __parm); } break;\
    case  9:{  BITPACK128V32_9( _ip, _op, __parm); } break;\
    case 10:{  BITPACK128V32_10(_ip, _op, __parm); } break;\
    case 11:{  BITPACK128V32_11(_ip, _op, __parm); } break;\
    case 12:{  BITPACK128V32_12(_ip, _op, __parm); } break;\
    case 13:{  BITPACK128V32_13(_ip, _op, __parm); } break;\
    case 14:{  BITPACK128V32_14(_ip, _op, __parm); } break;\
    case 15:{  BITPACK128V32_15(_ip, _op, __parm); } break;\
    case 16:{  BITPACK128V32_16(_ip, _op, __parm); } break;\
    case 17:{  BITPACK128V32_17(_ip, _op, __parm); } break;\
    case 18:{  BITPACK128V32_18(_ip, _op, __parm); } break;\
    case 19:{  BITPACK128V32_19(_ip, _op, __parm); } break;\
    case 20:{  BITPACK128V32_20(_ip, _op, __parm); } break;\
    case 21:{  BITPACK128V32_21(_ip, _op, __parm); } break;\
    case 22:{  BITPACK128V32_22(_ip, _op, __parm); } break;\
    case 23:{  BITPACK128V32_23(_ip, _op, __parm); } break;\
    case 24:{  BITPACK128V32_24(_ip, _op, __parm); } break;\
    case 25:{  BITPACK128V32_25(_ip, _op, __parm); } break;\
    case 26:{  BITPACK128V32_26(_ip, _op, __parm); } break;\
    case 27:{  BITPACK128V32_27(_ip, _op, __parm); } break;\
    case 28:{  BITPACK128V32_28(_ip, _op, __parm); } break;\
    case 29:{  BITPACK128V32_29(_ip, _op, __parm); } break;\
    case 30:{  BITPACK128V32_30(_ip, _op, __parm); } break;\
    case 31:{  BITPACK128V32_31(_ip, _op, __parm); } break;\
    case 32:{  BITPACK128V32_32(_ip, _op, __parm); } break;\
  }\
}

#define BITPACK256V32(_ip_, _nbits_, _op_, __parm) { __m256i *_ip=(__m256i *)_ip_,*_op=(__m256i *)_op_;\
  switch(_nbits_) {\
    case  0:                                           break;\
    case  1:{  BITPACK256V32_1( _ip, _op, __parm); } break;\
    case  2:{  BITPACK256V32_2( _ip, _op, __parm); } break;\
    case  3:{  BITPACK256V32_3( _ip, _op, __parm); } break;\
    case  4:{  BITPACK256V32_4( _ip, _op, __parm); } break;\
    case  5:{  BITPACK256V32_5( _ip, _op, __parm); } break;\
    case  6:{  BITPACK256V32_6( _ip, _op, __parm); } break;\
    case  7:{  BITPACK256V32_7( _ip, _op, __parm); } break;\
    case  8:{  BITPACK256V32_8( _ip, _op, __parm); } break;\
    case  9:{  BITPACK256V32_9( _ip, _op, __parm); } break;\
    case 10:{  BITPACK256V32_10(_ip, _op, __parm); } break;\
    case 11:{  BITPACK256V32_11(_ip, _op, __parm); } break;\
    case 12:{  BITPACK256V32_12(_ip, _op, __parm); } break;\
    case 13:{  BITPACK256V32_13(_ip, _op, __parm); } break;\
    case 14:{  BITPACK256V32_14(_ip, _op, __parm); } break;\
    case 15:{  BITPACK256V32_15(_ip, _op, __parm); } break;\
    case 16:{  BITPACK256V32_16(_ip, _op, __parm); } break;\
    case 17:{  BITPACK256V32_17(_ip, _op, __parm); } break;\
    case 18:{  BITPACK256V32_18(_ip, _op, __parm); } break;\
    case 19:{  BITPACK256V32_19(_ip, _op, __parm); } break;\
    case 20:{  BITPACK256V32_20(_ip, _op, __parm); } break;\
    case 21:{  BITPACK256V32_21(_ip, _op, __parm); } break;\
    case 22:{  BITPACK256V32_22(_ip, _op, __parm); } break;\
    case 23:{  BITPACK256V32_23(_ip, _op, __parm); } break;\
    case 24:{  BITPACK256V32_24(_ip, _op, __parm); } break;\
    case 25:{  BITPACK256V32_25(_ip, _op, __parm); } break;\
    case 26:{  BITPACK256V32_26(_ip, _op, __parm); } break;\
    case 27:{  BITPACK256V32_27(_ip, _op, __parm); } break;\
    case 28:{  BITPACK256V32_28(_ip, _op, __parm); } break;\
    case 29:{  BITPACK256V32_29(_ip, _op, __parm); } break;\
    case 30:{  BITPACK256V32_30(_ip, _op, __parm); } break;\
    case 31:{  BITPACK256V32_31(_ip, _op, __parm); } break;\
    case 32:{  BITPACK256V32_32(_ip, _op, __parm); } break;\
  }\
}

