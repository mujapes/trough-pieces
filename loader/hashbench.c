/* How fast is a hash?   hashbench <piece stem> <entry> <megabytes> */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(int argc, char **argv) { static void *table[512]; piece p; if (argc != 4 || piece_load(&p, argv[1])) return 2; size_t n = (size_t)atoi(argv[3]) << 20;
    uint8_t *src = malloc(64 + n), *out = calloc(1, 128); uint32_t kind = 2; uint64_t z = 64 + n; memset(src, 0, 64); memcpy(src, &kind, 4); memcpy(src + 16, &z, 8); for (size_t i = 0; i < n; i++) src[64 + i] = (uint8_t)(i * 131 + (i >> 8));
    z = 128; memcpy(out, &kind, 4); memcpy(out + 16, &z, 8); table[256 + 20] = src; int16_t q[2] = {20, 20}; entry5 e = (entry5)piece_entry(&p, argv[2]); if (!e) return 2; double best = 1e9;
    for (int r = 0; r < 7; r++) { double t = now(); e(out, q, 2, 0, table); t = now() - t; if (t < best) best = t; }
    printf("%s %s: %.0f MB a second (", argv[1], argv[2], (double)n / 1048576.0 / best); for (int i = 0; i < 6; i++) printf("%02x", out[64 + i]); printf("...)\n"); return 0; }
