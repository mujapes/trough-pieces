/* PROTOTYPE (bench only): fill plus cover_path, which writes ink amounts into a mask (a surface-shaped block
 * with one byte per pixel: bytes per row equal to the width) for the font piece's letter cache.
 * A faster implementation of the fill piece: same answers as reference.c, pixel for pixel, reached by adding
 * whole runs between crossings instead of testing every sample. The recorded checks are what prove "same". */
#include <stdint.h>
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
static int64_t floor_div(int64_t a, int64_t b) { int64_t q = a / b; if ((a % b != 0) && ((a < 0) != (b < 0))) q--; return q; }
int64_t fill_path(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table) { (void)table;
    /* Well formed? Also gather the edges and the bounds. */
    static const int unused_guard = 0; (void)unused_guard;
    int32_t ex0[1024], ey0[1024], ex1[1024], ey1[1024]; int edges = 0, outlines = 0; int64_t at = 0;
    int32_t top = 32767, bottom = -32768, left = 32767, right = -32768;
    while (at < n) {
        int count = p[at]; if (count < 2 || count > 256 || at + 1 + 2 * (int64_t)count > n || edges + count > 1024) return -1;
        const int16_t *q = p + at + 1;
        for (int i = 0; i < count; i++) { int j = (i + 1) % count;
            ex0[edges] = q[2 * i]; ey0[edges] = q[2 * i + 1]; ex1[edges] = q[2 * j]; ey1[edges] = q[2 * j + 1]; edges++;
            if (q[2 * i] < left) left = q[2 * i]; if (q[2 * i] > right) right = q[2 * i]; if (q[2 * i + 1] < top) top = q[2 * i + 1]; if (q[2 * i + 1] > bottom) bottom = q[2 * i + 1]; }
        at += 1 + 2 * (int64_t)count; outlines++;
    }
    if (!outlines) return -1;
    int32_t w = (int32_t)s->width, h = (int32_t)s->height;
    int32_t row0 = (int32_t)floor_div(top, 16), row1 = (int32_t)floor_div(bottom, 16), col0 = (int32_t)floor_div(left, 16), col1 = (int32_t)floor_div(right, 16);
    if (row0 < 0) row0 = 0; if (row1 > h - 1) row1 = h - 1; if (col0 < 0) col0 = 0; if (col1 > w - 1) col1 = w - 1;
    if (row0 > row1 || col0 > col1) return 0;
    uint32_t src[4] = { (uint32_t)colour & 255, ((uint32_t)colour >> 8) & 255, ((uint32_t)colour >> 16) & 255, 255 }, alpha = ((uint32_t)colour >> 24) & 255;
    int64_t inked = 0; int span = col1 - col0 + 1;
    for (int32_t row = row0; row <= row1; row++) {
        uint8_t tally[16384]; for (int i = 0; i < span; i++) tally[i] = 0;
        for (int sub = 0; sub < 4; sub++) {
            int32_t Y = row * 16 + 2 + 4 * sub; int32_t cx[1024]; int8_t cw[1024]; int crossings = 0;
            for (int e = 0; e < edges; e++) {
                int dir = (ey0[e] <= Y && Y < ey1[e]) ? 1 : (ey1[e] <= Y && Y < ey0[e]) ? -1 : 0; if (!dir) continue;
                int32_t x = ex0[e] + (int32_t)floor_div((int64_t)(Y - ey0[e]) * (ex1[e] - ex0[e]), ey1[e] - ey0[e]);
                int k = crossings++; while (k > 0 && cx[k - 1] > x) { cx[k] = cx[k - 1]; cw[k] = cw[k - 1]; k--; }      /* stable insertion: equal x keeps edge order */
                cx[k] = x; cw[k] = (int8_t)dir;
            }
            /* Between two neighbouring crossings every sample has the same answer, so whole runs are added at once.
             * Sample number j sits at position 4j + 2; the samples with cx[k] <= position < cx[k+1] are inside when
             * the count after crossing k is not zero: exactly the rule in the description, reached from the edges. */
            int wind = 0; int32_t lo = 4 * col0, hi = 4 * (col1 + 1);
            for (int k = 0; k + 1 < crossings; k++) {
                wind += cw[k]; if (!wind) continue;
                int32_t j0 = (int32_t)floor_div((int64_t)cx[k] - 2 + 3, 4), j1 = (int32_t)floor_div((int64_t)cx[k + 1] - 2 + 3, 4);
                if (j0 < lo) j0 = lo; if (j1 > hi) j1 = hi; if (j0 >= j1) continue;
                int32_t pa = (j0 >> 2) - col0, pb = ((j1 - 1) >> 2) - col0;
                if (pa == pb) { tally[pa] = (uint8_t)(tally[pa] + (j1 - j0)); continue; }
                tally[pa] = (uint8_t)(tally[pa] + 4 - (j0 & 3));
                for (int32_t q = pa + 1; q < pb; q++) tally[q] = (uint8_t)(tally[q] + 4);
                tally[pb] = (uint8_t)(tally[pb] + ((j1 - 1) & 3) + 1);
            }
        }
        for (int32_t col = col0; col <= col1; col++) { uint32_t t = tally[col - col0]; if (!t) continue;
            uint32_t i = (t * 255 + 8) / 16, a = (i * alpha + 127) / 255; uint8_t *d = s->pixels + (uint64_t)row * s->stride + (uint64_t)col * 4;
            for (int c = 0; c < 4; c++) d[c] = (uint8_t)((src[c] * a + d[c] * (255 - a) + 127) / 255);
            inked++; }
    }
    return inked;
}

int64_t cover_path(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table) { (void)table; (void)colour;
    /* Well formed? Also gather the edges and the bounds. */
    static const int unused_guard = 0; (void)unused_guard;
    int32_t ex0[1024], ey0[1024], ex1[1024], ey1[1024]; int edges = 0, outlines = 0; int64_t at = 0;
    int32_t top = 32767, bottom = -32768, left = 32767, right = -32768;
    while (at < n) {
        int count = p[at]; if (count < 2 || count > 256 || at + 1 + 2 * (int64_t)count > n || edges + count > 1024) return -1;
        const int16_t *q = p + at + 1;
        for (int i = 0; i < count; i++) { int j = (i + 1) % count;
            ex0[edges] = q[2 * i]; ey0[edges] = q[2 * i + 1]; ex1[edges] = q[2 * j]; ey1[edges] = q[2 * j + 1]; edges++;
            if (q[2 * i] < left) left = q[2 * i]; if (q[2 * i] > right) right = q[2 * i]; if (q[2 * i + 1] < top) top = q[2 * i + 1]; if (q[2 * i + 1] > bottom) bottom = q[2 * i + 1]; }
        at += 1 + 2 * (int64_t)count; outlines++;
    }
    if (!outlines) return -1;
    int32_t w = (int32_t)s->width, h = (int32_t)s->height;
    int32_t row0 = (int32_t)floor_div(top, 16), row1 = (int32_t)floor_div(bottom, 16), col0 = (int32_t)floor_div(left, 16), col1 = (int32_t)floor_div(right, 16);
    if (row0 < 0) row0 = 0; if (row1 > h - 1) row1 = h - 1; if (col0 < 0) col0 = 0; if (col1 > w - 1) col1 = w - 1;
    if (row0 > row1 || col0 > col1) return 0;

    int64_t inked = 0; int span = col1 - col0 + 1;
    for (int32_t row = row0; row <= row1; row++) {
        uint8_t tally[16384]; for (int i = 0; i < span; i++) tally[i] = 0;
        for (int sub = 0; sub < 4; sub++) {
            int32_t Y = row * 16 + 2 + 4 * sub; int32_t cx[1024]; int8_t cw[1024]; int crossings = 0;
            for (int e = 0; e < edges; e++) {
                int dir = (ey0[e] <= Y && Y < ey1[e]) ? 1 : (ey1[e] <= Y && Y < ey0[e]) ? -1 : 0; if (!dir) continue;
                int32_t x = ex0[e] + (int32_t)floor_div((int64_t)(Y - ey0[e]) * (ex1[e] - ex0[e]), ey1[e] - ey0[e]);
                int k = crossings++; while (k > 0 && cx[k - 1] > x) { cx[k] = cx[k - 1]; cw[k] = cw[k - 1]; k--; }      /* stable insertion: equal x keeps edge order */
                cx[k] = x; cw[k] = (int8_t)dir;
            }
            /* Between two neighbouring crossings every sample has the same answer, so whole runs are added at once.
             * Sample number j sits at position 4j + 2; the samples with cx[k] <= position < cx[k+1] are inside when
             * the count after crossing k is not zero: exactly the rule in the description, reached from the edges. */
            int wind = 0; int32_t lo = 4 * col0, hi = 4 * (col1 + 1);
            for (int k = 0; k + 1 < crossings; k++) {
                wind += cw[k]; if (!wind) continue;
                int32_t j0 = (int32_t)floor_div((int64_t)cx[k] - 2 + 3, 4), j1 = (int32_t)floor_div((int64_t)cx[k + 1] - 2 + 3, 4);
                if (j0 < lo) j0 = lo; if (j1 > hi) j1 = hi; if (j0 >= j1) continue;
                int32_t pa = (j0 >> 2) - col0, pb = ((j1 - 1) >> 2) - col0;
                if (pa == pb) { tally[pa] = (uint8_t)(tally[pa] + (j1 - j0)); continue; }
                tally[pa] = (uint8_t)(tally[pa] + 4 - (j0 & 3));
                for (int32_t q = pa + 1; q < pb; q++) tally[q] = (uint8_t)(tally[q] + 4);
                tally[pb] = (uint8_t)(tally[pb] + ((j1 - 1) & 3) + 1);
            }
        }
        for (int32_t col = col0; col <= col1; col++) { uint32_t t = tally[col - col0]; if (!t) continue;
            s->pixels[(uint64_t)row * s->stride + (uint64_t)col] = (uint8_t)((t * 255 + 8) / 16);   /* a mask: one byte of ink per pixel */
            inked++; }
    }
    return inked;
}
