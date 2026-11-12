#ifndef OM_FILE_IO_C_H
#define OM_FILE_IO_C_H

#include <stdint.h>

#ifdef __linux__
/// Start range writeback without waiting for completion. Returns -1 and sets errno on failure.
int om_request_writeback(int fd, int64_t offset, int64_t count);
#endif

#endif
