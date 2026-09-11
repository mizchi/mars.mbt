// Exact requested-byte accounting for the single-threaded send benchmark.
// Bookkeeping uses static storage and is excluded from the reported heap.
// Compile this file WITHOUT probe.h's allocator override.
#include "moonbit_runtime.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SLOTS 32768
#define TOMBSTONE ((void *)(uintptr_t)1)
static struct { void *ptr; size_t size; } entries[SLOTS];
static int active, scenario, iterations;
static uint64_t allocs, bytes, live, peak, sink_peak, blocked_live, max_alloc, live_objects;

int32_t mars_probe_consume(const uint8_t *data) { return data[0]; }

static size_t slot_for(void *ptr) {
  return (((uintptr_t)ptr >> 4) * UINT64_C(11400714819323198485)) & (SLOTS - 1);
}

void *mars_probe_malloc(size_t size) {
  void *ptr = MOONBIT_MALLOC_RAW(size);
  if (!active || !ptr) return ptr;
  size_t slot = slot_for(ptr);
  for (size_t i = 0; i < SLOTS; i++, slot = (slot + 1) & (SLOTS - 1)) {
    if (!entries[slot].ptr || entries[slot].ptr == TOMBSTONE) {
      entries[slot].ptr = ptr;
      entries[slot].size = size;
      allocs++;
      bytes += size;
      live += size;
      live_objects++;
      if (live > peak) peak = live;
      if (size > max_alloc) max_alloc = size;
      return ptr;
    }
  }
  fprintf(stderr, "allocation tracker full\n");
  abort();
}

void mars_probe_free(void *ptr) {
  if (active && ptr) {
    size_t slot = slot_for(ptr);
    for (size_t i = 0; i < SLOTS; i++, slot = (slot + 1) & (SLOTS - 1)) {
      if (!entries[slot].ptr) break;
      if (entries[slot].ptr == ptr) {
        live -= entries[slot].size;
        live_objects--;
        entries[slot].ptr = TOMBSTONE;
        break;
      }
    }
  }
  MOONBIT_FREE_RAW(ptr);
}

void mars_probe_begin(int32_t next_scenario, int32_t next_iterations) {
  memset(entries, 0, sizeof(entries));
  scenario = next_scenario;
  iterations = next_iterations;
  allocs = bytes = live = peak = sink_peak = blocked_live = max_alloc = live_objects = 0;
  active = 1;
}

void mars_probe_checkpoint(void) {
  if (live > sink_peak) sink_peak = live;
}

void mars_probe_blocked(void) { blocked_live = live; }

void mars_probe_end(void) {
  active = 0;
  printf("BUFFER_MEMORY {\"scenario\":%d,\"iterations\":%d,"
         "\"allocations\":%llu,\"allocated_bytes\":%llu,"
         "\"peak_live_bytes\":%llu,\"sink_peak_live_bytes\":%llu,"
         "\"blocked_live_bytes\":%llu,"
         "\"live_bytes_at_end\":%llu,\"live_objects_at_end\":%llu,"
         "\"largest_allocation\":%llu}\n",
         scenario, iterations, (unsigned long long)allocs,
         (unsigned long long)bytes, (unsigned long long)peak,
         (unsigned long long)sink_peak, (unsigned long long)blocked_live,
         (unsigned long long)live,
         (unsigned long long)live_objects, (unsigned long long)max_alloc);
}
