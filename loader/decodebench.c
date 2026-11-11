/* How long does decoding an image take?   decodebench <piece stem> <image file> <width> <height> */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
typedef int64_t (*fn)(void *, const int16_t *, int64_t, int64_t, void *);
int main(int argc, char **argv) {
    if (argc != 5) return 2; static void *table[512]; piece p; if (piece_load(&p, argv[1])) { printf("load failed\n"); return 1; }
    FILE *in = fopen(argv[2], "rb"); if (!in) return 1; fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET);
    uint8_t *fb = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t fs = 64 + (uint64_t)len; memcpy(fb, &kind, 4); memcpy(fb + 16, &fs, 8); if (fread(fb + 64, 1, (size_t)len, in) != (size_t)len) return 1; table[256 + 4] = fb;
    size_t ss = 64 + (8u << 20); uint8_t *sc = calloc(1, ss); kind = 5; fs = ss; memcpy(sc, &kind, 4); memcpy(sc + 16, &fs, 8); table[256 + 6] = sc;
    int W = atoi(argv[3]), H = atoi(argv[4]); size_t size = 64 + (size_t)W * H * 4; uint8_t *s = calloc(1, size); uint32_t head[4] = {1, (uint32_t)W, (uint32_t)H, 4u * (uint32_t)W}; uint64_t z = size; memcpy(s, head, 16); memcpy(s + 16, &z, 8);
    fn decode = (fn)piece_entry(&p, "decode"); int16_t q[2] = {4, 6}; double best = 1e9; volatile int64_t sink = 0; int64_t got = 0;
    for (int t = 0; t < 7; t++) { double a = now(); for (int r = 0; r < 10; r++) sink += got = decode(s, q, 2, 0, table); double d = (now() - a) / 10; if (d < best) best = d; }
    unsigned long sum = 0; for (size_t i = 64; i < size; i++) sum = sum * 31 + s[i];
    printf("%s: %lld pixels in %.2f ms, %.1f ns a pixel (picture checksum %lx)\n", argv[1], (long long)got, best * 1e3, best * 1e9 / (W * H), sum);
    return 0;
}
