/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint32_t version, width, height, stride; uint64_t size; } surface;
typedef struct { const uint8_t *d; uint64_t n; int bad; uint32_t cmap4, loca, glyf, hmtx, upm, glyphs, hmetrics; int long_loca; } font;
static uint32_t u8(font *f, uint64_t at) { if (at >= f->n) { f->bad = 1; return 0; } return f->d[at]; }
static uint32_t u16(font *f, uint64_t at) { if (at + 2 > f->n) { f->bad = 1; return 0; } return ((uint32_t)f->d[at] << 8) | f->d[at + 1]; }
static int32_t i16(font *f, uint64_t at) { return (int16_t)u16(f, at); }
static uint32_t u32(font *f, uint64_t at) { if (at + 4 > f->n) { f->bad = 1; return 0; } return ((uint32_t)f->d[at] << 24) | ((uint32_t)f->d[at + 1] << 16) | ((uint32_t)f->d[at + 2] << 8) | f->d[at + 3]; }
static int64_t floor_div(int64_t a, int64_t b) { int64_t q = a / b; if ((a % b != 0) && ((a < 0) != (b < 0))) q--; return q; }
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
static int open_font(font *f, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 12) return 0;
    f->d = b->bytes; f->n = b->size - 64; f->bad = 0;
    uint32_t count = u16(f, 4), cmap = 0, head = 0, hhea = 0, maxp = 0; f->loca = f->glyf = f->hmtx = 0; if (count > 64) count = 64;
    for (uint32_t i = 0; i < count; i++) { uint32_t tag = u32(f, 12 + 16 * i), off = u32(f, 12 + 16 * i + 8);
        if (tag == 0x636d6170) cmap = off; else if (tag == 0x6c6f6361) f->loca = off; else if (tag == 0x676c7966) f->glyf = off; else if (tag == 0x686d7478) f->hmtx = off;
        else if (tag == 0x68656164) head = off; else if (tag == 0x68686561) hhea = off; else if (tag == 0x6d617870) maxp = off; }
    if (!cmap || !f->loca || !f->glyf || !f->hmtx || !head || !hhea || !maxp) return 0;
    f->upm = u16(f, head + 18); f->long_loca = i16(f, head + 50) != 0; f->glyphs = u16(f, maxp + 4); f->hmetrics = u16(f, hhea + 34);
    if (f->upm < 16 || f->upm > 16384 || !f->hmetrics || !f->glyphs) return 0;
    uint32_t subs = u16(f, cmap + 2); if (subs > 32) subs = 32; f->cmap4 = 0;
    for (uint32_t i = 0; i < subs && !f->cmap4; i++) { uint32_t plat = u16(f, cmap + 4 + 8 * i), enc = u16(f, cmap + 6 + 8 * i), off = u32(f, cmap + 8 + 8 * i);
        if (u16(f, (uint64_t)cmap + off) == 4 && ((plat == 3 && enc == 1) || plat == 0)) f->cmap4 = cmap + off; }
    return f->cmap4 && !f->bad;
}
static uint32_t glyph_of(font *f, uint32_t code) {
    uint32_t segs = u16(f, f->cmap4 + 6) / 2; if (segs > 4096) segs = 4096;
    uint64_t ends = (uint64_t)f->cmap4 + 14, starts = ends + 2 * segs + 2, deltas = starts + 2 * segs, ranges = deltas + 2 * segs;
    for (uint32_t i = 0; i < segs; i++) { uint32_t end = u16(f, ends + 2 * i); if (code > end) continue;
        uint32_t start = u16(f, starts + 2 * i); if (code < start) return 0;
        uint32_t ro = u16(f, ranges + 2 * i), delta = u16(f, deltas + 2 * i); if (!ro) return (code + delta) & 0xffff;
        uint32_t g = u16(f, ranges + 2 * i + ro + 2 * (uint64_t)(code - start)); return g ? (g + delta) & 0xffff : 0; }
    return 0;
}
static int glyph_span(font *f, uint32_t g, uint32_t *start, uint32_t *end) {
    if (g >= f->glyphs) return 0;
    if (f->long_loca) { *start = u32(f, (uint64_t)f->loca + 4 * g); *end = u32(f, (uint64_t)f->loca + 4 * g + 4); }
    else { *start = 2 * u16(f, (uint64_t)f->loca + 2 * g); *end = 2 * u16(f, (uint64_t)f->loca + 2 * g + 2); }
    return *end > *start && !f->bad;
}
typedef struct { int16_t out[2400]; int used; } shape;
/* One simple glyph's outlines, scaled and placed, appended to the shape. Font units (dx, dy) are added first. */
static void simple(font *f, uint32_t start, int32_t dx, int32_t dy, int64_t size16, int64_t pen16, int64_t base16, shape *sh) {
    uint64_t p = (uint64_t)f->glyf + start; int32_t nc = i16(f, p); if (nc <= 0 || nc > 64) return; p += 10;
    uint32_t ends[64]; for (int i = 0; i < nc; i++) ends[i] = u16(f, p + 2 * i); p += 2 * (uint64_t)nc;
    uint32_t total = ends[nc - 1] + 1; if (total > 600) return; p += 2 + u16(f, p);
    uint8_t flags[600]; int32_t xs[600], ys[600];
    for (uint32_t i = 0; i < total;) { uint32_t fl = u8(f, p++); flags[i++] = (uint8_t)fl; if (fl & 8) { uint32_t rep = u8(f, p++); while (rep-- && i < total) flags[i++] = (uint8_t)fl; } }
    int32_t v = 0; for (uint32_t i = 0; i < total; i++) { if (flags[i] & 2) { int32_t d = (int32_t)u8(f, p++); v += (flags[i] & 16) ? d : -d; } else if (!(flags[i] & 16)) { v += i16(f, p); p += 2; } xs[i] = v; }
    v = 0; for (uint32_t i = 0; i < total; i++) { if (flags[i] & 4) { int32_t d = (int32_t)u8(f, p++); v += (flags[i] & 32) ? d : -d; } else if (!(flags[i] & 32)) { v += i16(f, p); p += 2; } ys[i] = v; }
    if (f->bad) return;
    uint32_t first = 0;
    for (int c = 0; c < nc; c++) {
        uint32_t last = ends[c]; if (last < first || last >= total) return; uint32_t n = last - first + 1;
        /* scaled points, with the implied midpoints made explicit */
        int32_t px[1200], py[1200]; uint8_t on[1200]; uint32_t m = 0;
        for (uint32_t i = 0; i < n; i++) { uint32_t a = first + i, b = first + (i + 1) % n;
            int32_t ax = (int32_t)(pen16 + floor_div((int64_t)(xs[a] + dx) * size16 + f->upm / 2, f->upm)), ay = (int32_t)(base16 - floor_div((int64_t)(ys[a] + dy) * size16 + f->upm / 2, f->upm));
            px[m] = ax; py[m] = ay; on[m] = flags[a] & 1; m++;
            if (!(flags[a] & 1) && !(flags[b] & 1)) {
                int32_t bx = (int32_t)(pen16 + floor_div((int64_t)(xs[b] + dx) * size16 + f->upm / 2, f->upm)), by = (int32_t)(base16 - floor_div((int64_t)(ys[b] + dy) * size16 + f->upm / 2, f->upm));
                px[m] = (int32_t)floor_div((int64_t)ax + bx, 2); py[m] = (int32_t)floor_div((int64_t)ay + by, 2); on[m] = 1; m++; } }
        first = last + 1;
        uint32_t s0 = 0; while (s0 < m && !on[s0]) s0++; if (s0 == m) continue;
        int16_t pts[2 * 256]; int count = 0, ok = 1; int32_t cx = px[s0], cy = py[s0];
        #define PUT(X, Y) do { if ((X) < -32767 || (X) > 32767 || (Y) < -32767 || (Y) > 32767 || count >= 256) ok = 0; else { pts[2 * count] = (int16_t)(X); pts[2 * count + 1] = (int16_t)(Y); count++; } } while (0)
        PUT(cx, cy);
        for (uint32_t i = 1; i <= m && ok; ) { uint32_t a = (s0 + i) % m;
            if (on[a]) { if (i < m) PUT(px[a], py[a]); cx = px[a]; cy = py[a]; i++; }
            else { uint32_t b = (s0 + i + 1) % m; int32_t ex = px[b], ey = py[b];
                for (int k = 1; k <= 4 && ok; k++) { int32_t qx = (int32_t)floor_div((int64_t)(4 - k) * (4 - k) * cx + 2 * k * (4 - k) * (int64_t)px[a] + (int64_t)k * k * ex + 8, 16), qy = (int32_t)floor_div((int64_t)(4 - k) * (4 - k) * cy + 2 * k * (4 - k) * (int64_t)py[a] + (int64_t)k * k * ey + 8, 16);
                    if (!(k == 4 && i + 1 >= m)) PUT(qx, qy); }
                cx = ex; cy = ey; i += 2; } }
        #undef PUT
        if (!ok || count < 2 || sh->used + 1 + 2 * count > 2400) continue;
        sh->out[sh->used++] = (int16_t)count; for (int i = 0; i < 2 * count; i++) sh->out[sh->used++] = pts[i];
    }
}
static void outline(font *f, uint32_t g, int64_t size16, int64_t pen16, int64_t base16, shape *sh) {
    uint32_t start, end; if (!glyph_span(f, g, &start, &end)) return;
    int32_t nc = i16(f, (uint64_t)f->glyf + start);
    if (nc >= 0) { simple(f, start, 0, 0, size16, pen16, base16, sh); return; }
    uint64_t p = (uint64_t)f->glyf + start + 10;
    for (int part = 0; part < 16 && !f->bad; part++) { uint32_t fl = u16(f, p), child = u16(f, p + 2); p += 4; int32_t dx = 0, dy = 0;
        if (fl & 1) { dx = i16(f, p); dy = i16(f, p + 2); p += 4; } else { dx = (int8_t)u8(f, p); dy = (int8_t)u8(f, p + 1); p += 2; }
        if (!(fl & 2)) { dx = 0; dy = 0; }
        if (fl & 8) p += 2; else if (fl & 0x40) p += 4; else if (fl & 0x80) p += 8;
        uint32_t cs, ce; if (glyph_span(f, child, &cs, &ce) && i16(f, (uint64_t)f->glyf + cs) > 0) simple(f, cs, dx, dy, size16, pen16, base16, sh);
        if (!(fl & 0x20)) break; }
}
static int64_t run(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table, int paint) {
    font f; if (!open_font(&f, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : 0))) return -1;
    int64_t size = n > 1 ? p[1] : 0; if (size < 4 || size > 1000) return -1;
    int64_t size16 = size * 16, pen16 = paint ? (n > 2 ? p[2] : 0) * 16 : 0, base16 = paint ? (n > 3 ? p[3] : 0) * 16 : 0, begin = pen16;
    for (int64_t k = paint ? 4 : 2; k < n; k++) { int32_t code = p[k]; if (code < 0) continue;
        uint32_t g = glyph_of(&f, (uint32_t)code); if (f.bad) return -1;
        if (paint) { shape sh; sh.used = 0; outline(&f, g, size16, pen16, base16, &sh); if (f.bad) return -1;
            if (sh.used) TROUGH_ON(table, SLOT_FILL_FILL_PATH, s, sh.out, sh.used, colour); }
        uint32_t adv = u16(&f, (uint64_t)f.hmtx + 4 * (uint64_t)(g < f.hmetrics ? g : f.hmetrics - 1)); if (f.bad) return -1;
        pen16 += floor_div((int64_t)adv * size16 + f.upm / 2, f.upm); }
    return paint ? pen16 : pen16 - begin;
}
int64_t draw(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table) { return run(s, p, n, colour, table, 1); }
int64_t measure(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused; return run(s, p, n, 0, table, 0); }
