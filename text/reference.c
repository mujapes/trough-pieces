/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "font18.h"
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
int64_t draw(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table) { (void)table;
    int64_t x = n > 0 ? p[0] : 0, y = n > 1 ? p[1] : 0;
    uint32_t src[4] = { (uint32_t)colour & 255, ((uint32_t)colour >> 8) & 255, ((uint32_t)colour >> 16) & 255, 255 }, alpha = ((uint32_t)colour >> 24) & 255;
    for (int64_t k = 2; k < n; k++) {
        int code = p[k]; if (code < 32 || code > 126) continue;
        int g = code - 32; const unsigned char *ink = font_ink + font_glyph[g].at;
        for (int row = 0; row < font_glyph[g].h; row++) {
            int64_t py = y + font_glyph[g].top + row; if (py < 0 || py >= s->height) continue;
            for (int col = 0; col < font_glyph[g].w; col++) {
                int64_t px = x + font_glyph[g].left + col; if (px < 0 || px >= s->width) continue;
                uint32_t i = ink[row * font_glyph[g].w + col]; if (!i) continue;
                uint32_t a = (i * alpha + 127) / 255; uint8_t *d = s->pixels + py * s->stride + px * 4;
                for (int c = 0; c < 4; c++) d[c] = (uint8_t)((src[c] * a + d[c] * (255 - a) + 127) / 255);
            }
        }
        x += font_glyph[g].advance;
    }
    return x;
}
int64_t measure(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)s; (void)unused; (void)table;
    int64_t width = 0; for (int64_t k = 0; k < n; k++) if (p[k] >= 32 && p[k] <= 126) width += font_glyph[p[k] - 32].advance; return width; }
