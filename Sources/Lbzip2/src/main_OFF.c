/*-
  main.c -- main module

  Copyright (C) 2011, 2012, 2014 Mikolaj Izdebski
  Copyright (C) 2008, 2009, 2010 Laszlo Ersek

  This file is part of lbzip2.

  lbzip2 is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  lbzip2 is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with lbzip2.  If not, see <http://www.gnu.org/licenses/>.
*/



#include "common.h"
#include <stdio.h>              /* vfprintf() */


#include "main.h"               /* pname */


void *
xmalloc(size_t n)
{
  void *p = malloc(n);
  if (!p)
      fprintf(stderr, "Insufficient memory to complete operation.");
  return p;
}
