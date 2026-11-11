#ifndef _CHELPER_
#define _CHELPER_

#include <stddef.h>
#include <stdint.h>

#ifdef __linux__
/// Start range writeback without waiting for completion. Returns -1 and sets errno on failure.
int om_request_writeback(int fd, int64_t offset, int64_t count);
#endif

void windirectionFast(const size_t num_points, const float* ys, const float* xs, float* out);


/*void display_mallinfo2(void);

void chelper_malloc_trim(void);*/

#endif // _CHELPER_
