#ifdef __linux__
// These must precede system headers to expose GNU range writeback with 64-bit offsets.
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#define _FILE_OFFSET_BITS 64
#include <fcntl.h>
#include "OmFileIOC.h"

int om_request_writeback(int fd, int64_t offset, int64_t count) {
    return sync_file_range(fd, (off_t)offset, (off_t)count, SYNC_FILE_RANGE_WRITE);
}
#endif
