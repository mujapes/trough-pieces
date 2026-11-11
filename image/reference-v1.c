/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } surface;
static int sound(const surface *s) { return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table; return sound(s); }
static int over(uint8_t *d, const uint8_t *src) {
    uint32_t a = src[3]; if (!a) return 0;
    for (int c = 0; c < 4; c++) { uint32_t S = c == 3 ? 255 : src[c]; d[c] = (uint8_t)((S * a + d[c] * (255 - a) + 127) / 255); }
    return 1;
}
static const surface *source(const surface *dst, const int16_t *p, int64_t n, void *const *table) {
    const surface *src = (const surface *)TROUGH_BLOCK(table, n > 0 ? p[0] : 0);
    return src && src != dst && sound(src) ? src : 0;
}
int64_t blit(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused;
    const surface *src = source(s, p, n, table); if (!src) return -1;
    int64_t x = n > 1 ? p[1] : 0, y = n > 2 ? p[2] : 0, touched = 0;
    for (int64_t r = 0; r < src->height; r++) { int64_t py = y + r; if (py < 0 || py >= s->height) continue;
        for (int64_t c = 0; c < src->width; c++) { int64_t px = x + c; if (px < 0 || px >= s->width) continue;
            touched += over(s->pixels + py * s->stride + px * 4, src->pixels + r * src->stride + c * 4); } }
    return touched;
}
int64_t scale(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused;
    const surface *src = source(s, p, n, table); if (!src) return -1;
    int64_t x = n > 1 ? p[1] : 0, y = n > 2 ? p[2] : 0, w = n > 3 ? p[3] : 0, h = n > 4 ? p[4] : 0, touched = 0;
    if (w <= 0 || h <= 0) return 0;
    for (int64_t r = 0; r < h; r++) { int64_t py = y + r; if (py < 0 || py >= s->height) continue; int64_t sr = (2 * r + 1) * src->height / (2 * h);
        for (int64_t c = 0; c < w; c++) { int64_t px = x + c; if (px < 0 || px >= s->width) continue; int64_t sc = (2 * c + 1) * src->width / (2 * w);
            touched += over(s->pixels + py * s->stride + px * 4, src->pixels + sr * src->stride + sc * 4); } }
    return touched;
}
