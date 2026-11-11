/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
typedef struct { const uint8_t *d; uint64_t n, first; uint32_t width, height; uint64_t global; uint32_t global_n; } gif;
typedef struct { uint64_t table, data; uint32_t table_n, x, y, w, h, delay, dispose, interlaced; int clear; } frame;
static int open_gif(gif *g, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 13) return 0; g->d = b->bytes; g->n = b->size - 64;
    if (g->d[0] != 'G' || g->d[1] != 'I' || g->d[2] != 'F' || g->d[3] != '8' || (g->d[4] != '7' && g->d[4] != '9') || g->d[5] != 'a') return 0;
    g->width = g->d[6] | ((uint32_t)g->d[7] << 8); g->height = g->d[8] | ((uint32_t)g->d[9] << 8); g->global = 0; g->global_n = 0; g->first = 13;
    if (g->d[10] & 0x80) { g->global = 13; g->global_n = 2u << (g->d[10] & 7); g->first = 13 + 3ull * g->global_n; }
    return g->width && g->height && g->width <= 16384 && g->height <= 16384 && g->first <= g->n;
}
/* Steps over a run of sub-blocks (each a length byte and that many bytes, ended by a zero length). 0 if the file runs out. */
static int skip_blocks(const gif *g, uint64_t *at) { for (;;) { if (*at >= g->n) return 0; uint32_t len = g->d[*at]; *at += 1 + len; if (!len) return *at <= g->n; } }
/* Reads the next frame's description starting at *at and leaves *at after its data. 0 at the end of the file or where it cannot be followed. */
static int next_frame(const gif *g, uint64_t *at, frame *f) {
    f->delay = 0; f->dispose = 0; f->clear = -1;
    for (;;) { if (*at >= g->n) return 0; uint32_t kind = g->d[(*at)++];
        if (kind == 0x21) { if (*at >= g->n) return 0; uint32_t label = g->d[(*at)++];
            if (label == 0xf9 && *at + 5 < g->n && g->d[*at] == 4) { uint32_t flags = g->d[*at + 1]; f->dispose = (flags >> 2) & 7; f->delay = g->d[*at + 2] | ((uint32_t)g->d[*at + 3] << 8); f->clear = (flags & 1) ? (int)g->d[*at + 4] : -1; }
            if (!skip_blocks(g, at)) return 0; }
        else if (kind == 0x2c) { if (*at + 9 > g->n) return 0; const uint8_t *q = g->d + *at; f->x = q[0] | ((uint32_t)q[1] << 8); f->y = q[2] | ((uint32_t)q[3] << 8); f->w = q[4] | ((uint32_t)q[5] << 8); f->h = q[6] | ((uint32_t)q[7] << 8);
            f->interlaced = (q[8] >> 6) & 1; *at += 9; f->table = g->global; f->table_n = g->global_n;
            if (q[8] & 0x80) { f->table = *at; f->table_n = 2u << (q[8] & 7); *at += 3ull * f->table_n; }
            if (*at >= g->n) return 0; f->data = *at; (*at)++; return skip_blocks(g, at); }
        else return 0; }
}
int64_t size(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)s; (void)a;
    gif g; if (!open_gif(&g, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1; return (int64_t)g.width * 65536 + g.height; }
int64_t frames(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)s; (void)a;
    gif g; if (!open_gif(&g, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1; uint64_t at = g.first; frame f; int64_t count = 0; while (next_frame(&g, &at, &f)) count++; return count; }
int64_t delay(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)s; (void)a;
    gif g; if (!open_gif(&g, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1; int64_t want = n > 1 ? p[1] : 0; if (want < 0) return -1;
    uint64_t at = g.first; frame f; for (int64_t i = 0; next_frame(&g, &at, &f); i++) if (i == want) return f.delay; return -1; }
/* Unpacks one frame's LZW data into w × h colour numbers. */
static int unpack(const gif *g, const frame *f, uint8_t *out, uint64_t want, uint16_t *prefix, uint8_t *suffix, uint8_t *stack) {
    uint64_t at = f->data; uint32_t min = g->d[at++]; if (min < 1 || min > 11) return 0;
    uint32_t clear = 1u << min, stop = clear + 1, width = min + 1, next = clear + 2, bits = 0, left = 0; int have = 0, prev = -1; uint32_t first = 0; uint64_t made = 0;
    for (uint32_t i = 0; i < clear && i < 4096; i++) { prefix[i] = 0xffff; suffix[i] = (uint8_t)i; }
    while (made < want) {
        while (have < (int)width) { if (!left) { if (at >= g->n) return 0; left = g->d[at++]; if (!left) return 0; } if (at >= g->n) return 0; bits |= (uint32_t)g->d[at++] << have; have += 8; left--; }
        uint32_t code = bits & ((1u << width) - 1); bits >>= width; have -= (int)width;
        if (code == clear) { width = min + 1; next = clear + 2; prev = -1; continue; }
        if (code == stop) return 0;
        uint32_t walk = code; int depth = 0;
        if (prev < 0) { if (code >= clear) return 0; }
        else if (code >= next) { if (code != next || next >= 4096) return 0; stack[depth++] = (uint8_t)first; walk = (uint32_t)prev; }
        while (walk >= clear) { if (walk >= 4096 || depth >= 4096) return 0; stack[depth++] = suffix[walk]; walk = prefix[walk]; }
        first = walk; stack[depth++] = (uint8_t)walk;
        while (depth && made < want) out[made++] = stack[--depth];
        if (prev >= 0 && next < 4096) { prefix[next] = (uint16_t)prev; suffix[next] = (uint8_t)first; next++; if (next == (1u << width) && width < 12) width++; }
        prev = (int)code; }
    return 1;
}
int64_t decode(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    gif g; if (!open_gif(&g, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1;
    block *scratch = (block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); int64_t want = n > 2 ? p[2] : 0; if (!scratch || scratch->kind != 5 || want < 0) return -1;
    uint64_t area = (uint64_t)g.width * g.height; if (scratch->size < 64 + 20480 + 5 * area) return -1;
    uint16_t *prefix = (uint16_t *)(void *)scratch->bytes; uint8_t *suffix = scratch->bytes + 8192, *stack = scratch->bytes + 12288, *index = scratch->bytes + 20480, *saved = index + area;
    uint32_t cw = g.width < s->width ? g.width : s->width, ch = g.height < s->height ? g.height : s->height;
    for (uint32_t y = 0; y < ch; y++) for (uint32_t x = 0; x < 4 * cw; x++) s->pixels[(uint64_t)y * s->stride + x] = 0;
    uint64_t at = g.first; frame f, before; int had = 0;
    for (int64_t i = 0; i <= want; i++) {
        if (!next_frame(&g, &at, &f)) return -1;
        if (f.x > g.width) f.x = g.width; if (f.y > g.height) f.y = g.height; uint32_t fw = f.w, fh = f.h; if (f.x + fw > g.width) fw = g.width - f.x; if (f.y + fh > g.height) fh = g.height - f.y;
        if (had && before.dispose == 2) { for (uint32_t y = before.y; y < before.y + before.h && y < ch; y++) for (uint32_t x = before.x; x < before.x + before.w && x < cw; x++) { uint8_t *d = s->pixels + (uint64_t)y * s->stride + 4ull * x; d[0] = d[1] = d[2] = d[3] = 0; } }
        else if (had && before.dispose == 3) { for (uint32_t y = before.y; y < before.y + before.h && y < ch; y++) for (uint32_t x = 4 * before.x; x < 4 * (before.x + before.w) && x < 4 * cw; x++) s->pixels[(uint64_t)y * s->stride + x] = saved[(uint64_t)y * g.width * 4 + x]; }
        if (f.dispose == 3) for (uint32_t y = f.y; y < f.y + fh && y < ch; y++) for (uint32_t x = 4 * f.x; x < 4 * (f.x + fw) && x < 4 * cw; x++) saved[(uint64_t)y * g.width * 4 + x] = s->pixels[(uint64_t)y * s->stride + x];
        if (f.w && f.h) { if ((uint64_t)f.w * f.h > area || !unpack(&g, &f, index, (uint64_t)f.w * f.h, prefix, suffix, stack)) return -1;
            uint32_t row = 0;
            for (int pass = 0; pass < (f.interlaced ? 4 : 1); pass++) { uint32_t y0 = f.interlaced ? (pass == 0 ? 0 : pass == 1 ? 4 : pass == 2 ? 2 : 1) : 0, dy = f.interlaced ? (pass == 0 ? 8 : pass == 1 ? 8 : pass == 2 ? 4 : 2) : 1;
                for (uint32_t y = y0; y < f.h; y += dy, row++) { if (y >= fh || f.y + y >= ch) continue; const uint8_t *q = index + (uint64_t)row * f.w;
                    for (uint32_t x = 0; x < fw && f.x + x < cw; x++) { uint32_t k = q[x]; if ((int)k == f.clear) continue; if (k >= f.table_n || f.table + 3ull * k + 3 > g.n) return -1;
                        uint8_t *d = s->pixels + (uint64_t)(f.y + y) * s->stride + 4ull * (f.x + x); d[0] = g.d[f.table + 3 * k]; d[1] = g.d[f.table + 3 * k + 1]; d[2] = g.d[f.table + 3 * k + 2]; d[3] = 255; } } } }
        before = f; before.w = fw; before.h = fh; had = 1; }
    return (int64_t)cw * ch;
}
