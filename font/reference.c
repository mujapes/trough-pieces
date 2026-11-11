/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint32_t version, width, height, stride; uint64_t size; } surface;
typedef struct { const uint8_t *d; uint64_t n; int bad; uint32_t cmap4, loca, glyf, hmtx, upm, glyphs, hmetrics; int long_loca; uint32_t gpos, kern_lookup[8]; int kerns; } font;
static uint32_t u8(font *f, uint64_t at) { if (at >= f->n) { f->bad = 1; return 0; } return f->d[at]; }
static uint32_t u16(font *f, uint64_t at) { if (at + 2 > f->n) { f->bad = 1; return 0; } return ((uint32_t)f->d[at] << 8) | f->d[at + 1]; }
static int32_t i16(font *f, uint64_t at) { return (int16_t)u16(f, at); }
static uint32_t u32(font *f, uint64_t at) { if (at + 4 > f->n) { f->bad = 1; return 0; } return ((uint32_t)f->d[at] << 24) | ((uint32_t)f->d[at + 1] << 16) | ((uint32_t)f->d[at + 2] << 8) | f->d[at + 3]; }
static int64_t floor_div(int64_t a, int64_t b) { int64_t q = a / b; if ((a % b != 0) && ((a < 0) != (b < 0))) q--; return q; }
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
/* --- kerning: the font's own table of pairs that should sit closer or further apart (GPOS, feature "kern", pair adjustment) ---
 * These readers give 0 past the end instead of refusing the font: a font with a damaged kerning table is still a font. */
static uint32_t g16(const font *f, uint64_t at) { return at + 2 <= f->n ? ((uint32_t)f->d[at] << 8) | f->d[at + 1] : 0; }
static uint32_t g32(const font *f, uint64_t at) { return (g16(f, at) << 16) | g16(f, at + 2); }
static int bits_set(uint32_t v) { int c = 0; for (; v; v >>= 1) c += (int)(v & 1); return c; }
static void find_kerning(font *f) {
    if (!f->gpos) return; uint64_t features = (uint64_t)f->gpos + g16(f, (uint64_t)f->gpos + 6), lookups = (uint64_t)f->gpos + g16(f, (uint64_t)f->gpos + 8);
    uint32_t count = g16(f, features), total = g16(f, lookups), index[8]; if (count > 512) count = 512;
    for (uint32_t i = 0; i < count; i++) { if (g32(f, features + 2 + 6 * (uint64_t)i) != 0x6b65726e) continue; uint64_t ft = features + g16(f, features + 6 + 6 * (uint64_t)i); uint32_t uses = g16(f, ft + 2); if (uses > 64) uses = 64;
        for (uint32_t k = 0; k < uses; k++) { uint32_t li = g16(f, ft + 4 + 2 * (uint64_t)k); if (li >= total) continue; int at = 0, known = 0;
            for (int j = 0; j < f->kerns; j++) { if (index[j] == li) known = 1; if (index[j] < li) at = j + 1; }
            if (known || f->kerns >= 8) continue;
            for (int j = f->kerns; j > at; j--) index[j] = index[j - 1]; index[at] = li; f->kerns++; } }      /* kept in the font's own order of lookups */
    for (int j = 0; j < f->kerns; j++) f->kern_lookup[j] = (uint32_t)(lookups + g16(f, lookups + 2 + 2 * (uint64_t)index[j]));
}
static int covered(const font *f, uint64_t cov, uint32_t g) {           /* the glyph's place in a coverage list, or -1 */
    uint32_t format = g16(f, cov), count = g16(f, cov + 2);
    if (format == 1) { uint32_t lo = 0, hi = count; while (lo < hi) { uint32_t mid = (lo + hi) / 2, v = g16(f, cov + 4 + 2 * (uint64_t)mid); if (v == g) return (int)mid; if (v < g) lo = mid + 1; else hi = mid; } return -1; }
    if (format == 2) { uint32_t lo = 0, hi = count; while (lo < hi) { uint32_t mid = (lo + hi) / 2; uint64_t r = cov + 4 + 6 * (uint64_t)mid; uint32_t a = g16(f, r), b = g16(f, r + 2);
            if (g < a) hi = mid; else if (g > b) lo = mid + 1; else return (int)(g16(f, r + 4) + g - a); } return -1; }
    return -1;
}
static uint32_t class_of(const font *f, uint64_t cd, uint32_t g) {
    uint32_t format = g16(f, cd);
    if (format == 1) { uint32_t start = g16(f, cd + 2), count = g16(f, cd + 4); return g >= start && g - start < count ? g16(f, cd + 6 + 2 * (uint64_t)(g - start)) : 0; }
    if (format == 2) { uint32_t lo = 0, hi = g16(f, cd + 2); while (lo < hi) { uint32_t mid = (lo + hi) / 2; uint64_t r = cd + 4 + 6 * (uint64_t)mid; uint32_t a = g16(f, r), b = g16(f, r + 2);
            if (g < a) hi = mid; else if (g > b) lo = mid + 1; else return g16(f, r + 4); } }
    return 0;
}
/* How much closer (negative) or further apart two neighbouring glyphs sit, in the font's units. */
static int32_t kern_units(const font *f, uint32_t left, uint32_t right) {
    int32_t total = 0;
    for (int j = 0; j < f->kerns; j++) { uint64_t L = f->kern_lookup[j]; uint32_t type = g16(f, L), subs = g16(f, L + 4); if (subs > 256) subs = 256;
        for (uint32_t s = 0; s < subs; s++) { uint64_t st = L + g16(f, L + 6 + 2 * (uint64_t)s); uint32_t t = type;
            if (t == 9) { if (g16(f, st) != 1) continue; t = g16(f, st + 2); st += g32(f, st + 4); }
            if (t != 2) continue;
            uint32_t format = g16(f, st), vf1 = g16(f, st + 4), vf2 = g16(f, st + 6); int place = covered(f, st + g16(f, st + 2), left); if (place < 0) continue;
            uint32_t len1 = 2 * (uint32_t)bits_set(vf1), len2 = 2 * (uint32_t)bits_set(vf2), xadv = 2 * (uint32_t)bits_set(vf1 & 3);
            if (format == 1) { if ((uint32_t)place >= g16(f, st + 8)) continue; uint64_t set = st + g16(f, st + 10 + 2 * (uint64_t)place); uint32_t lo = 0, hi = g16(f, set), each = 2 + len1 + len2; int found = 0;
                while (lo < hi) { uint32_t mid = (lo + hi) / 2, v = g16(f, set + 2 + (uint64_t)mid * each); if (v == right) { if (vf1 & 4) total += (int16_t)g16(f, set + 2 + (uint64_t)mid * each + 2 + xadv); found = 1; break; } if (v < right) lo = mid + 1; else hi = mid; }
                if (found) break; }
            else if (format == 2) { uint32_t n1 = g16(f, st + 12), n2 = g16(f, st + 14), c1 = class_of(f, st + g16(f, st + 8), left), c2 = class_of(f, st + g16(f, st + 10), right); if (c1 >= n1 || c2 >= n2) continue;
                if (vf1 & 4) total += (int16_t)g16(f, st + 16 + ((uint64_t)c1 * n2 + c2) * (len1 + len2) + xadv); break; } } }
    return total;
}
static int open_font(font *f, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 12) return 0;
    f->d = b->bytes; f->n = b->size - 64; f->bad = 0;
    uint32_t count = u16(f, 4), cmap = 0, head = 0, hhea = 0, maxp = 0; f->loca = f->glyf = f->hmtx = 0; f->gpos = 0; f->kerns = 0; if (count > 64) count = 64;
    for (uint32_t i = 0; i < count; i++) { uint32_t tag = u32(f, 12 + 16 * i), off = u32(f, 12 + 16 * i + 8);
        if (tag == 0x636d6170) cmap = off; else if (tag == 0x6c6f6361) f->loca = off; else if (tag == 0x676c7966) f->glyf = off; else if (tag == 0x686d7478) f->hmtx = off;
        else if (tag == 0x47504f53) f->gpos = off;
        else if (tag == 0x68656164) head = off; else if (tag == 0x68686561) hhea = off; else if (tag == 0x6d617870) maxp = off; }
    if (!cmap || !f->loca || !f->glyf || !f->hmtx || !head || !hhea || !maxp) return 0;
    f->upm = u16(f, head + 18); f->long_loca = i16(f, head + 50) != 0; f->glyphs = u16(f, maxp + 4); f->hmetrics = u16(f, hhea + 34);
    if (f->upm < 16 || f->upm > 16384 || !f->hmetrics || !f->glyphs) return 0;
    uint32_t subs = u16(f, cmap + 2); if (subs > 32) subs = 32; f->cmap4 = 0;
    for (uint32_t i = 0; i < subs && !f->cmap4; i++) { uint32_t plat = u16(f, cmap + 4 + 8 * i), enc = u16(f, cmap + 6 + 8 * i), off = u32(f, cmap + 8 + 8 * i);
        if (u16(f, (uint64_t)cmap + off) == 4 && ((plat == 3 && enc == 1) || plat == 0)) f->cmap4 = cmap + off; }
    if (f->cmap4 && !f->bad) find_kerning(f);
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
    int64_t before = -1;
    for (int64_t k = paint ? 4 : 2; k < n; k++) { int32_t code = p[k]; if (code < 0) continue;
        uint32_t g = glyph_of(&f, (uint32_t)code); if (f.bad) return -1;
        if (before >= 0) pen16 += floor_div((int64_t)kern_units(&f, (uint32_t)before, g) * size16 + f.upm / 2, f.upm); before = g;
        if (paint) { shape sh; sh.used = 0; outline(&f, g, size16, pen16, base16, &sh); if (f.bad) return -1;
            if (sh.used) TROUGH_ON(table, SLOT_FILL_FILL_PATH, s, sh.out, sh.used, colour); }
        uint32_t adv = u16(&f, (uint64_t)f.hmtx + 4 * (uint64_t)(g < f.hmetrics ? g : f.hmetrics - 1)); if (f.bad) return -1;
        pen16 += floor_div((int64_t)adv * size16 + f.upm / 2, f.upm); }
    return paint ? pen16 : pen16 - begin;
}
int64_t draw(surface *s, const int16_t *p, int64_t n, int64_t colour, void *const *table) { return run(s, p, n, colour, table, 1); }
int64_t measure(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused; return run(s, p, n, 0, table, 0); }
/* --- the letter cache ---
 * Cache block (kind 3): after the 64-byte header, u32 slot count (1024) and u32 bytes of ink used; then 1024
 * slots of 16 bytes: u32 key, i16 left, i16 top, u16 width, u16 height, u32 offset of the ink; then the ink.
 * Scratch block: a mask (surface-shaped, one byte per pixel) the fill piece writes one letter's ink into. */
typedef struct { uint32_t key; int16_t left, top; uint16_t w, h; uint32_t at; } slot;
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint32_t slots, used; slot table[1024]; uint8_t ink[]; } cache;
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } mask;
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } picture;
int64_t draw_cached(surface *s0, const int16_t *p, int64_t n, int64_t colour, void *const *table) {
    picture *s = (picture *)s0;
    font f; if (!open_font(&f, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : 0))) return -1;
    cache *C = (cache *)TROUGH_BLOCK(table, n > 1 ? p[1] : 0); mask *M = (mask *)TROUGH_BLOCK(table, n > 2 ? p[2] : 0);
    if (!C || C->kind != 3 || C->size < sizeof(cache) + 4096 || !M || M->version != 4 || M->width < 16 || M->height < 16 || M->stride != M->width || M->size != 64 + (uint64_t)M->width * M->height) return -1;
    int64_t size = n > 3 ? p[3] : 0; if (size < 4 || size > 1000) return -1;
    if (C->slots != 1024) { C->slots = 1024; C->used = 0; for (int i = 0; i < 1024; i++) C->table[i].key = 0; }     /* a fresh cache */
    uint64_t room = C->size - sizeof(cache);
    int64_t size16 = size * 16, pen16 = (n > 4 ? p[4] : 0) * 16, base = n > 5 ? p[5] : 0;
    uint32_t src[4] = { (uint32_t)colour & 255, ((uint32_t)colour >> 8) & 255, ((uint32_t)colour >> 16) & 255, 255 }, alpha = ((uint32_t)colour >> 24) & 255;
    int64_t before = -1;
    for (int64_t k = 6; k < n; k++) { int32_t code = p[k]; if (code < 0) continue;
        uint32_t g = glyph_of(&f, (uint32_t)code); if (f.bad) return -1;
        if (before >= 0) pen16 += floor_div((int64_t)kern_units(&f, (uint32_t)before, g) * size16 + f.upm / 2, f.upm); before = g;
        uint32_t key = ((g << 12) | (uint32_t)size) + 1, h = (key * 2654435761u) >> 22; slot *found = 0, *empty = 0;
        for (int probe = 0; probe < 8 && !found; probe++) { slot *q = &C->table[(h + probe) & 1023]; if (q->key == key) found = q; else if (!q->key && !empty) empty = q; }
        if (!found && empty) {                                           /* fill this letter once and keep its ink */
            shape sh; sh.used = 0; outline(&f, g, size16, 0, 0, &sh); if (f.bad) return -1;
            int32_t minx = 32767, miny = 32767, maxx = -32768, maxy = -32768;
            for (int at = 0; at < sh.used; ) { int count = sh.out[at]; for (int i = 0; i < count; i++) { int32_t x = sh.out[at + 1 + 2 * i], y = sh.out[at + 2 + 2 * i]; if (x < minx) minx = x; if (x > maxx) maxx = x; if (y < miny) miny = y; if (y > maxy) maxy = y; } at += 1 + 2 * count; }
            if (!sh.used) { empty->key = key; empty->w = empty->h = 0; empty->left = empty->top = 0; empty->at = 0; found = empty; }
            else { int32_t left = (int32_t)floor_div(minx, 16), top = (int32_t)floor_div(miny, 16), w = (int32_t)floor_div(maxx, 16) - left + 1, hgt = (int32_t)floor_div(maxy, 16) - top + 1;
                if (w <= (int32_t)M->width && hgt <= (int32_t)M->height && (uint64_t)C->used + (uint64_t)w * hgt <= room) {
                    for (int at = 0; at < sh.used; ) { int count = sh.out[at]; for (int i = 0; i < count; i++) { sh.out[at + 1 + 2 * i] = (int16_t)(sh.out[at + 1 + 2 * i] - left * 16); sh.out[at + 2 + 2 * i] = (int16_t)(sh.out[at + 2 + 2 * i] - top * 16); } at += 1 + 2 * count; }
                    for (int32_t r = 0; r < hgt; r++) for (int32_t c = 0; c < w; c++) M->pixels[r * M->stride + c] = 0;
                    TROUGH_ON(table, SLOT_COVER_COVER_PATH, M, sh.out, sh.used, 0);
                    for (int32_t r = 0; r < hgt; r++) for (int32_t c = 0; c < w; c++) C->ink[C->used + r * w + c] = M->pixels[r * M->stride + c];
                    empty->key = key; empty->left = (int16_t)left; empty->top = (int16_t)top; empty->w = (uint16_t)w; empty->h = (uint16_t)hgt; empty->at = C->used; C->used += (uint32_t)(w * hgt); found = empty; } } }
        int64_t px0 = floor_div(pen16 + 8, 16);                          /* letters sit on whole pixels when they come from the cache */
        if (found) { const uint8_t *ink = C->ink + found->at;
            for (int32_t r = 0; r < found->h; r++) { int64_t py = base + found->top + r; if (py < 0 || py >= s->height) continue;
                for (int32_t c = 0; c < found->w; c++) { int64_t px = px0 + found->left + c; if (px < 0 || px >= s->width) continue;
                    uint32_t i = ink[r * found->w + c]; if (!i) continue; uint32_t a = (i * alpha + 127) / 255; uint8_t *d = s->pixels + py * s->stride + px * 4;
                    for (int ch = 0; ch < 4; ch++) d[ch] = (uint8_t)((src[ch] * a + d[ch] * (255 - a) + 127) / 255); } } }
        else { shape sh; sh.used = 0; outline(&f, g, size16, px0 * 16, base * 16, &sh); if (f.bad) return -1; if (sh.used) TROUGH_ON(table, SLOT_FILL_FILL_PATH, s0, sh.out, sh.used, colour); }   /* no room: the slow way */
        uint32_t adv = u16(&f, (uint64_t)f.hmtx + 4 * (uint64_t)(g < f.hmetrics ? g : f.hmetrics - 1)); if (f.bad) return -1;
        pen16 += floor_div((int64_t)adv * size16 + f.upm / 2, f.upm); }
    return pen16;
}
