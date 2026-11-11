/* How long does a line of text take? Font piece -> fill piece -> surface, on the bench.
 *   textbench <font stem> <fill stem> <font file> */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
typedef int64_t (*fn)(void *, const int16_t *, int64_t, int64_t, void *);
static int64_t nothing(void *s, const int16_t *p, int64_t n, int64_t c, void *t) { (void)s; (void)p; (void)n; (void)c; (void)t; return 0; }
int main(int argc, char **argv) {
    if (argc != 4) return 2; static void *table[512]; piece font, fill;
    int none = !strcmp(argv[2], "none");                       /* "none": the font piece alone, with a fill that does nothing */
    if (piece_load(&font, argv[1]) || (!none && piece_load(&fill, argv[2]))) { printf("load failed\n"); return 1; }
    table[7] = none ? (void *)nothing : piece_entry(&fill, "fill_path");
    FILE *in = fopen(argv[3], "rb"); if (!in) return 1; fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET);
    uint8_t *fb = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t fs = 64 + (uint64_t)len; memcpy(fb, &kind, 4); memcpy(fb + 16, &fs, 8); if (fread(fb + 64, 1, (size_t)len, in) != (size_t)len) return 1; table[256 + 3] = fb;
    int W = 1080, H = 400; size_t size = 64 + (size_t)W * H * 4; uint8_t *s = calloc(1, size); uint32_t head[4] = {1, (uint32_t)W, (uint32_t)H, 4u * (uint32_t)W}; uint64_t z = size; memcpy(s, head, 16); memcpy(s + 16, &z, 8);
    const char *text = "The quick brown fox jumps over the lazy dog, 0123456789 times."; fn draw = (fn)piece_entry(&font, "draw");
    static const int sizes[3] = {16, 32, 96}; volatile int64_t sink = 0;
    for (int k = 0; k < 3; k++) { int16_t q[4 + 80]; int n = 0; q[0] = 3; q[1] = (int16_t)sizes[k]; q[2] = 10; q[3] = (int16_t)(sizes[k] + 20); while (text[n] && (k < 2 || n < 14)) { q[4 + n] = text[n]; n++; }
        double best = 1e9; int reps = k == 0 ? 200 : k == 1 ? 100 : 40;
        for (int t = 0; t < 5; t++) { double a = now(); for (int r = 0; r < reps; r++) sink += draw(s, q, 4 + n, 0xff202020, table); double d = (now() - a) / reps; if (d < best) best = d; }
        printf("%2d characters at %2d pixels: %.0f microseconds a line, %.1f microseconds a character\n", n, sizes[k], best * 1e6, best * 1e6 / n); }
    return 0;
}
