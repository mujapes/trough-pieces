/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t version, magic; int32_t width, height, screen, pressed, hour, minute, opened; int64_t events; uint8_t rest[468]; } state;
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; } picture;
#define MAGIC 0x4c454853u            /* S H E L */
int64_t migrate(state *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    if (s->version == 1 && s->magic == MAGIC) return 1;
    const uint8_t *b = (const uint8_t *)s; for (int i = 0; i < 512; i++) if (b[i]) return 0;
    s->version = 1; s->magic = MAGIC; s->pressed = -1; return 1;
}
static int tile_at(const state *s, int x, int y, void *const *table) {
    if (s->width < 16 || s->height < 16) return -1;
    picture shape = {1, (uint32_t)s->width, (uint32_t)s->height, 4u * (uint32_t)s->width, 64 + 4ull * (uint32_t)s->width * (uint32_t)s->height, {0}};   /* home hit only reads the size */
    int16_t q[2] = {(int16_t)x, (int16_t)y}; return (int)TROUGH_ON(table, SLOT_HOME_HIT, &shape, q, 2, 0);
}
int64_t event(state *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    if (s->version != 1 || s->magic != MAGIC) return 0;
    int kind = n > 0 ? p[0] : 0, x = n > 1 ? p[1] : 0, y = n > 2 ? p[2] : 0, hour = n > 3 ? p[3] : 0, minute = n > 4 ? p[4] : 0;
    state was = *s; s->events++;
    if (kind == 1 || kind == 2) { if (s->screen == 0) s->pressed = tile_at(s, x, y, table); else if (kind == 1) s->pressed = (s->width >= 16 && y >= 0 && y < 28 && x >= 0 && x < s->width) ? -2 : -1; }
    else if (kind == 3) { if (s->screen == 0 && s->pressed >= 0) { s->opened = s->pressed; s->screen = 1; } else if (s->screen == 1 && s->pressed == -2) s->screen = 0; s->pressed = -1; }
    else if (kind == 4) { s->hour = ((hour % 24) + 24) % 24; s->minute = ((minute % 60) + 60) % 60; }
    else if (kind == 5) { if (x >= 16 && x <= 4096 && y >= 16 && y <= 4096) { s->width = x; s->height = y; } }
    return was.screen != s->screen || was.pressed != s->pressed || was.hour != s->hour || was.minute != s->minute || was.width != s->width || was.height != s->height;
}
static int64_t words(void *pic, void *const *table, int x, int y, const char *text, int centred, uint32_t colour) {
    int16_t q[40]; int n = 0; while (text[n] && n < 38) { q[2 + n] = text[n]; n++; }
    if (centred) x -= (int)TROUGH_ON(table, SLOT_TEXT_MEASURE, pic, q + 2, n, 0) / 2;
    q[0] = (int16_t)x; q[1] = (int16_t)y; TROUGH_ON(table, SLOT_TEXT_DRAW, pic, q, n + 2, colour); return centred ? 2 : 1;
}
int64_t render(state *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    picture *pic = (picture *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1);
    if (s->version != 1 || s->magic != MAGIC || !pic || pic->version != 1 || pic->width < 1 || pic->width > 16384 || pic->height < 1 || pic->height > 16384
        || pic->stride != 4 * pic->width || pic->size != 64 + (uint64_t)pic->stride * pic->height) return -1;
    if (s->screen == 0) { int16_t q[3] = {(int16_t)s->pressed, (int16_t)s->hour, (int16_t)s->minute}; return TROUGH_ON(table, SLOT_HOME_RENDER, pic, q, 3, 0); }
    int w = (int)pic->width, h = (int)pic->height; int64_t calls = 0;
    TROUGH_ON(table, SLOT_PAINT_CLEAR, pic, 0, 0, 0xff14100c); calls++;
    { int16_t q[4] = {0, 0, (int16_t)w, 28}; TROUGH_ON(table, SLOT_PAINT_FILL_RECT, pic, q, 4, s->pressed == -2 ? 0xff4a3c32 : 0xff2b221c); calls++; }
    calls += words(pic, table, 12, 3, "< Home", 0, 0xffd8d0c8);
    char line[24] = "Opened tile "; int at = 12, tile = s->opened < 0 ? 0 : s->opened % 100; if (tile >= 10) line[at++] = (char)('0' + tile / 10); line[at++] = (char)('0' + tile % 10); line[at] = 0;
    calls += words(pic, table, w / 2, h / 2 - 11, line, 1, 0xfff0ece8);
    calls += words(pic, table, w / 2, h / 2 + 16, "an app would go here", 1, 0xff8a8078);
    return calls;
}
