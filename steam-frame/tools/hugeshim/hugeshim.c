// LD_PRELOAD shim: asks the kernel for transparent huge pages on large anonymous private mappings
// (Cemu's guest RAM reservations), since THP is opt-in ("madvise") on this system.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>

#define MIN_SIZE (64UL << 20)

void* mmap(void* addr, size_t len, int prot, int flags, int fd, off_t off) {
    static void* (*real_mmap)(void*, size_t, int, int, int, off_t);
    if (!real_mmap) real_mmap = dlsym(RTLD_NEXT, "mmap");
    void* p = real_mmap(addr, len, prot, flags, fd, off);
    if (p != MAP_FAILED && len >= MIN_SIZE && (flags & MAP_ANONYMOUS) && (flags & MAP_PRIVATE)) {
        int r = madvise(p, len, MADV_HUGEPAGE);
        if (getenv("HUGESHIM_LOG")) fprintf(stderr, "[hugeshim] %p +%zu MB -> %d\n", p, len >> 20, r);
    }
    return p;
}
void* mmap64(void* addr, size_t len, int prot, int flags, int fd, off_t off) __attribute__((alias("mmap")));
