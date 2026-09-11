#ifndef MARS_BUFFER_MEMORY_PROBE_H
#define MARS_BUFFER_MEMORY_PROBE_H
#include "moonbit_runtime.h"
void *mars_probe_malloc(size_t size);
void mars_probe_free(void *ptr);
void mars_probe_begin(int32_t scenario, int32_t iterations);
void mars_probe_checkpoint(void);
void mars_probe_end(void);
#undef MOONBIT_MALLOC_RAW
#undef MOONBIT_FREE_RAW
#define MOONBIT_MALLOC_RAW mars_probe_malloc
#define MOONBIT_FREE_RAW mars_probe_free
#endif
