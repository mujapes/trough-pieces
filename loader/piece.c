#define _GNU_SOURCE
#include "piece.h"
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
static double now_us(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1e6+t.tv_nsec*1e-3;}
int piece_load(piece *p, const char *stem) {
    char path[512]; double t0 = now_us(); memset(p, 0, sizeof *p);
    snprintf(path, sizeof path, "%s.bin", stem);
    FILE *f = fopen(path, "rb"); if (!f) return -1;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    if (n <= 0 || n > (1 << 20)) { fclose(f); return -2; }
    long page = sysconf(_SC_PAGESIZE); size_t size = (size_t)((n + page - 1) / page * page);
    /* The code must end up runnable and not writable. Android decides which routes an app may use, so three
     * are tried, strictest first:
     *  1. private memory, written then switched to executable (sometimes refused on this phone);
     *  2. an in-memory file (memfd), written then mapped read+execute;
     *  3. the piece's own file mapped read+execute, which is how every shared library here is loaded. */
    void *m = MAP_FAILED; p->how = "";
    void *w = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (w != MAP_FAILED) {
        if (fread(w, 1, (size_t)n, f) == (size_t)n && mprotect(w, size, PROT_READ | PROT_EXEC) == 0) { m = w; p->how = "private memory"; }
        else munmap(w, size);
    }
    if (m == MAP_FAILED) {
        int fd = memfd_create("trough-piece", MFD_CLOEXEC);
        if (fd >= 0) {
            char buf[4096]; size_t got; int ok = 1; fseek(f, 0, SEEK_SET);
            while ((got = fread(buf, 1, sizeof buf, f)) > 0) if (write(fd, buf, got) != (ssize_t)got) { ok = 0; break; }
            if (ok) { void *x = mmap(NULL, size, PROT_READ | PROT_EXEC, MAP_PRIVATE, fd, 0); if (x != MAP_FAILED) { m = x; p->how = "in-memory file"; } }
            close(fd);
        }
    }
    if (m == MAP_FAILED) {
        void *x = mmap(NULL, size, PROT_READ | PROT_EXEC, MAP_PRIVATE, fileno(f), 0);
        if (x != MAP_FAILED) { m = x; p->how = "its own file"; }
    }
    fclose(f);
    if (m == MAP_FAILED) return -5;
    __builtin___clear_cache((char *)m, (char *)m + n);
    snprintf(path, sizeof path, "%s.entries", stem);
    f = fopen(path, "r"); if (!f) { munmap(m, size); return -6; }
    long off;
    while (p->count < 8 && fscanf(f, "%31s %ld", p->names[p->count], &off) == 2) {
        if (off < 0 || off >= n || (off & 3)) { fclose(f); munmap(m, size); return -7; }
        p->entry[p->count++] = (char *)m + off;
    }
    fclose(f);
    p->base = m; p->size = size; p->load_us = now_us() - t0;
    return 0;
}
void *piece_entry(const piece *p, const char *name) {
    for (int i = 0; i < p->count; i++) if (!strcmp(p->names[i], name)) return p->entry[i];
    return NULL;
}
