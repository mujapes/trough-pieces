/* How fast is a text conversion?   convbench <piece stem> <file> <encoding number> */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(int argc, char **argv) { static void *table[512]; piece p; if (argc != 4 || piece_load(&p, argv[1])) return 2; FILE *in = fopen(argv[2], "rb"); fseek(in, 0, SEEK_END); size_t n = (size_t)ftell(in); fseek(in, 0, SEEK_SET);
    uint8_t *src = calloc(1, 64 + n), *out = calloc(1, 64 + (getenv("ROOM") ? (size_t)atol(getenv("ROOM")) : 4 * n + 16)); uint32_t kind = 2; uint64_t z = 64 + n; memcpy(src, &kind, 4); memcpy(src + 16, &z, 8); if (fread(src + 64, 1, n, in) != n) return 1; z = 64 + (getenv("ROOM") ? (size_t)atol(getenv("ROOM")) : 4 * n + 16); memcpy(out, &kind, 4); memcpy(out + 16, &z, 8);
    table[256 + 20] = src; int16_t q[2] = {20, (int16_t)atoi(argv[3])}; entry5 e = (entry5)piece_entry(&p, getenv("ENTRY") ? getenv("ENTRY") : "to_utf8"); long long made = 0; double best = 1e9;
    for (int r = 0; r < 9; r++) { double t = now(); made = e(out, q, 2, 0, table); t = now() - t; if (t < best) best = t; }
    unsigned long long sum = 0; for (long long i = 0; i < made; i++) sum = sum * 31 + out[64 + i]; printf("%.0f MB a second (%lld bytes out, checksum %llx)\n", (double)n / 1048576.0 / best, made, sum); return 0; }
