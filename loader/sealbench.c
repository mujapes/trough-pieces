/* How fast is sealing?   sealbench <piece stem> <megabytes> */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
static uint8_t *bytes(size_t n) { uint8_t *b = calloc(1, 64 + n); uint32_t kind = 2; uint64_t z = 64 + n; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); for (size_t i = 0; i < n; i++) b[64 + i] = (uint8_t)(i * 131 + (i >> 8) + n); return b; }
int main(int argc, char **argv) { static void *table[512]; piece p; if (argc != 3 || piece_load(&p, argv[1])) return 2; size_t n = (size_t)atoi(argv[2]) << 20;
    table[256 + 20] = bytes(32); table[256 + 21] = bytes(12); table[256 + 22] = bytes(13); table[256 + 23] = bytes(n); uint8_t *out = bytes(n + 16), *back = bytes(n); int16_t q[4] = {20, 21, 22, 23};
    entry5 seal = (entry5)piece_entry(&p, "seal"), open = (entry5)piece_entry(&p, "open"); double a = 1e9, b = 1e9; long long made = 0, got = 0;
    for (int r = 0; r < 5; r++) { double t = now(); made = seal(out, q, 4, 0, table); t = now() - t; if (t < a) a = t; }
    table[256 + 24] = out; q[3] = 24; for (int r = 0; r < 5; r++) { double t = now(); got = open(back, q, 4, 0, table); t = now() - t; if (t < b) b = t; }
    printf("%s: seal %.0f MB a second, open %.0f MB a second (%lld, %lld, round trip %s)\n", argv[1], (double)n / 1048576.0 / a, (double)n / 1048576.0 / b, made, got, memcmp(back + 64, (uint8_t *)table[256 + 23] + 64, n) ? "WRONG" : "same"); return 0; }
