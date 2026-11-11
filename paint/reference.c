/* The meaning of the piece, written the obvious way. */
#include <stdint.h>
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint32_t pixels[]; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
int64_t clear(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table) { (void)p; (void)n; (void)table;
    int64_t total = (int64_t)s->width * s->height; for (int64_t i = 0; i < total; i++) s->pixels[i] = (uint32_t)colour; return total; }
int64_t fill_rect(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table) { (void)table;
    int64_t x = n > 0 ? p[0] : 0, y = n > 1 ? p[1] : 0, w = n > 2 ? p[2] : 0, h = n > 3 ? p[3] : 0;
    int64_t x1 = x + w, y1 = y + h; if (x < 0) x = 0; if (y < 0) y = 0; if (x1 > s->width) x1 = s->width; if (y1 > s->height) y1 = s->height;
    if (x1 <= x || y1 <= y) return 0;
    for (int64_t row = y; row < y1; row++) for (int64_t col = x; col < x1; col++) s->pixels[row * s->width + col] = (uint32_t)colour;
    return (x1 - x) * (y1 - y); }
