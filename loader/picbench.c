/* How fast, and to what result, does a picture decoder decode a file?   picbench <piece stem> <file>
 * Prints the answer, the best time of 5, and a checksum of the surface, so two builds can be compared on real files. */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(int argc, char **argv) { static void *table[512]; piece p; if (argc != 3 || piece_load(&p, argv[1])) return 2; FILE *in = fopen(argv[2], "rb"); if (!in) return 1; fseek(in, 0, SEEK_END); size_t n = (size_t)ftell(in); fseek(in, 0, SEEK_SET);
    uint8_t *src = calloc(1, 64 + n); uint32_t kind = 2; uint64_t z = 64 + n; memcpy(src, &kind, 4); memcpy(src + 16, &z, 8); if (fread(src + 64, 1, n, in) != n) return 1; table[256 + 20] = src;
    int16_t q[2] = {20, 21}; long long wh = ((entry5)piece_entry(&p, "size"))(0, q, 1, 0, table); if (wh < 0) { printf("%s: not readable\n", argv[2]); return 0; } uint32_t w = (uint32_t)(wh >> 16), h = (uint32_t)(wh & 65535);
    size_t room = 64 + 20480 + 24ull * w * h + 4096 * (size_t)h + (1 << 20); uint8_t *scratch = calloc(1, room); kind = 5; z = room; memcpy(scratch, &kind, 4); memcpy(scratch + 16, &z, 8); table[256 + 21] = scratch;
    uint64_t ssize = 64 + 4ull * w * h; uint32_t *s = calloc(1, ssize); s[0] = 1; s[1] = w; s[2] = h; s[3] = 4 * w; memcpy(s + 4, &ssize, 8);
    entry5 e = (entry5)piece_entry(&p, "decode"); long long ans = 0; double best = 1e9; for (int r = 0; r < 5; r++) { double t = now(); ans = e(s, q, 2, 0, table); t = now() - t; if (t < best) best = t; }
    uint64_t sum = 1469598103934665603ull; for (uint64_t i = 64; i < ssize; i++) sum = (sum ^ ((uint8_t *)s)[i]) * 1099511628211ull;
    printf("%s %ux%u -> %lld in %.2f ms, surface %016llx\n", argv[1], w, h, ans, best * 1e3, (unsigned long long)sum); return 0; }
