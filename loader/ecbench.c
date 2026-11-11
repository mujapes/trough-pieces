#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
int main(int argc, char **argv) { static void *table[512]; piece p; if (piece_load(&p, argv[1])) return 2; int16_t q[6]; q[0] = (int16_t)atoi(argv[2]);
    for (int i = 3; i < 8; i++) { FILE *in = fopen(argv[i], "rb"); fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET); uint8_t *b = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t z = 64 + (uint64_t)len; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); fread(b + 64, 1, (size_t)len, in); fclose(in); table[256 + 20 + i] = b; q[i - 2] = (int16_t)(20 + i); }
    entry5 e = (entry5)piece_entry(&p, "verify"); long long ans = 0; double best = 1e9; for (int r = 0; r < 7; r++) { double t = now(); for (int k = 0; k < 5; k++) ans = e(0, q, 6, 0, table); t = (now() - t) / 5; if (t < best) best = t; }
    printf("P-%s verify -> %lld in %.0f microseconds\n", argv[2], ans, best * 1e6); return 0; }
