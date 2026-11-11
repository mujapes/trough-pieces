/* Time any entry that takes files at handles and writes a small answer.   callbench <piece stem> <entry> <file>...   (handles 20, 21, ...) */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(int argc, char **argv) { static void *table[512]; piece p; if (argc < 4 || piece_load(&p, argv[1])) return 2; int16_t q[16]; int n = 0;
    for (int i = 3; i < argc && n < 16; i++, n++) { FILE *in = fopen(argv[i], "rb"); if (!in) return 1; fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET);
        uint8_t *b = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t z = 64 + (uint64_t)len; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); if (fread(b + 64, 1, (size_t)len, in) != (size_t)len) return 1; fclose(in); table[256 + 20 + n] = b; q[n] = (int16_t)(20 + n); }
    uint8_t *out = calloc(1, 64 + 4096); uint32_t kind = 2; uint64_t z = 64 + 4096; memcpy(out, &kind, 4); memcpy(out + 16, &z, 8); entry5 e = (entry5)piece_entry(&p, argv[2]); if (!e) return 2;
    long long answer = 0; double best = 1e9; for (int r = 0; r < 9; r++) { double t = now(); for (int k = 0; k < 20; k++) answer = e(out, q, n, 0, table); t = (now() - t) / 20; if (t < best) best = t; }
    printf("%s %s -> %lld in %.1f microseconds (%.0f a second)\n", argv[1], argv[2], answer, best * 1e6, 1 / best); return 0; }
