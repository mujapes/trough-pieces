/* Prototype timing: text through the letter cache against text filled every time.
 *   cachebench <font stem> <fill stem> <cover stem> <font file> <out.rgba>   (writes a 720 x 200 picture)
 * fill and cover are separate pieces now (they were one prototype when this was written, and the old form crashed). */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec * 1e-9; }
typedef int64_t (*fn)(void *, const int16_t *, int64_t, int64_t, void *);
static uint8_t *header(size_t size, uint32_t kind, uint32_t w, uint32_t h, uint32_t stride) { uint8_t *b = calloc(1, size); uint32_t head[4] = {kind, w, h, stride}; uint64_t z = size; memcpy(b, head, 16); memcpy(b + 16, &z, 8); return b; }
int main(int argc, char **argv) {
    if (argc != 6) return 2; static void *table[512]; piece font, fill, cover;
    if (piece_load(&font, argv[1]) || piece_load(&fill, argv[2]) || piece_load(&cover, argv[3])) { printf("load failed\n"); return 1; }
    table[7] = piece_entry(&fill, "fill_path"); table[10] = piece_entry(&cover, "cover_path"); if (!table[7] || !table[10]) { printf("fill_path or cover_path missing\n"); return 1; }
    FILE *in = fopen(argv[4], "rb"); if (!in) return 1; fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET);
    uint8_t *fb = header(64 + (size_t)len, 2, 0, 0, 0); if (fread(fb + 64, 1, (size_t)len, in) != (size_t)len) return 1; table[256 + 3] = fb;
    table[256 + 4] = header(1 << 20, 3, 0, 0, 0);                              /* the cache: one megabyte */
    table[256 + 5] = header(64 + 256 * 256, 4, 256, 256, 256);                 /* scratch mask */
    int W = 720, H = 200; uint8_t *s = header(64 + (size_t)W * H * 4, 1, (uint32_t)W, (uint32_t)H, 4u * (uint32_t)W); memset(s + 64, 255, (size_t)W * H * 4);
    const char *text = "The quick brown fox jumps over the lazy dog, 0123456789 times."; fn draw = (fn)piece_entry(&font, "draw"), cached = (fn)piece_entry(&font, "draw_cached");
    static const int sizes[3] = {16, 32, 96}; volatile int64_t sink = 0; int y = 0;
    for (int k = 0; k < 3; k++) { int n = 0; int16_t a[4 + 80], b[6 + 80]; while (text[n] && (k < 2 || n < 12)) { a[4 + n] = text[n]; b[6 + n] = text[n]; n++; }
        y += sizes[k] + 6; a[0] = 3; a[1] = (int16_t)sizes[k]; a[2] = 8; a[3] = (int16_t)y; b[0] = 3; b[1] = 4; b[2] = 5; b[3] = (int16_t)sizes[k]; b[4] = 8; b[5] = (int16_t)(y + (k < 2 ? sizes[k] + 4 : 0));
        int reps = k == 0 ? 300 : k == 1 ? 150 : 60; double plain = 1e9, fast = 1e9;
        if (k < 2) { for (int t = 0; t < 5; t++) { double t0 = now(); for (int r = 0; r < reps; r++) sink += draw(s, a, 4 + n, 0xff202020, table); double d = (now() - t0) / reps; if (d < plain) plain = d; } }
        else { for (int t = 0; t < 5; t++) { double t0 = now(); for (int r = 0; r < reps; r++) sink += draw(s, a, 4 + n, 0xff202020, table); double d = (now() - t0) / reps; if (d < plain) plain = d; } b[5] = (int16_t)(y + 0); }
        double first = now(); sink += cached(s, b, 6 + n, 0xffa03010, table); first = now() - first;
        for (int t = 0; t < 5; t++) { double t0 = now(); for (int r = 0; r < reps; r++) sink += cached(s, b, 6 + n, 0xffa03010, table); double d = (now() - t0) / reps; if (d < fast) fast = d; }
        if (k < 2) y += sizes[k] + 4;
        printf("%2d px: filled every time %.1f, from the cache %.2f microseconds a character (%.0fx); first use %.0f microseconds for the line\n", sizes[k], plain * 1e6 / n, fast * 1e6 / n, plain / fast, first * 1e6); }
    uint32_t used; memcpy(&used, (uint8_t *)table[256 + 4] + 68, 4); printf("ink stored: %u bytes\n", used);
    FILE *out = fopen(argv[5], "wb"); fwrite(s + 64, 1, (size_t)W * H * 4, out); fclose(out); return 0;
}
