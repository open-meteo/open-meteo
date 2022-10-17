#ifndef _CHELPER_
#define _CHELPER_

#include <stddef.h>

void windirectionFast(const size_t num_points, const float* ys, const float* xs, float* out);


void display_mallinfo2(void);

void chelper_malloc_trim(void);

#endif // _CHELPER_
