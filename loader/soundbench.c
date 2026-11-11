/* Call the sound piece on raw 16-bit files.   soundbench <stem> convert <in.raw> <out.raw> rin cin rout cout vol
 *                                             soundbench <stem> mix <base.raw> <add.raw> <out.raw> vol start    (rates in units of 25 Hz) */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static uint8_t *blockof(const char *path, uint32_t kind, size_t room) { size_t len = room; FILE *in = path ? fopen(path, "rb") : 0; if (in) { fseek(in, 0, SEEK_END); len = (size_t)ftell(in); fseek(in, 0, SEEK_SET); }
    uint8_t *b = calloc(1, 64 + len); uint64_t z = 64 + len; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); if (in) { if (fread(b + 64, 1, len, in) != len) return 0; fclose(in); } return b; }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(int argc, char **argv) { static void *table[512]; piece p; if (argc < 8 || piece_load(&p, argv[1])) return 2; long long made; uint8_t *out; const char *to;
    if (!strcmp(argv[2], "convert") || !strcmp(argv[2], "resample")) { uint8_t *src = blockof(argv[3], 2, 0); uint64_t z; memcpy(&z, src + 16, 8); table[256 + 20] = src; out = blockof(0, 2, (size_t)((z - 64) * 2 * (uint64_t)atoi(argv[7]) / (uint64_t)atoi(argv[5]) * 2 + 64)); to = argv[4];
        int16_t q[6] = {20, (int16_t)atoi(argv[5]), (int16_t)atoi(argv[6]), (int16_t)atoi(argv[7]), (int16_t)atoi(argv[8]), (int16_t)atoi(argv[9])}; double best = 1e18;
        for (int r = 0; r < 5; r++) { double t = now(); made = ((entry5)piece_entry(&p, argv[2]))(out, q, 6, 0, table); t = now() - t; if (t < best) best = t; } printf("%lld samples in %.2f ms\n", made, best); }
    else { out = blockof(argv[3], 2, 0); table[256 + 20] = blockof(argv[4], 2, 0); to = argv[5]; long start = atol(argv[7]); int16_t q[4] = {20, (int16_t)atoi(argv[6]), (int16_t)(start % 32768), (int16_t)(start / 32768)};
        made = ((entry5)piece_entry(&p, "mix"))(out, q, 4, 0, table); printf("%lld samples\n", made); uint64_t z; memcpy(&z, out + 16, 8); made = (long long)(z - 64) / 2; }
    if (made < 0) return 1; FILE *o = fopen(to, "wb"); fwrite(out + 64, 2, (size_t)made, o); fclose(o); return 0; }
