/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
typedef struct { uint8_t count[17]; uint8_t symbol[256]; int present; } huff;
typedef struct { int h, v, q, dc, ac, pred; uint32_t pw, ph; uint64_t at; } comp;
typedef struct { const uint8_t *d; uint64_t n, pos; int bad; uint32_t width, height; int comps, hmax, vmax, restart; uint16_t quant[4][64]; huff dc[4], ac[4]; comp c[3];
                 uint32_t bits; int have; int marker; uint64_t scan; } jpg;
static const uint8_t zigzag[64] = {0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63};
static uint32_t rd8(jpg *j, uint64_t at) { if (at >= j->n) { j->bad = 1; return 0; } return j->d[at]; }
static uint32_t rd16(jpg *j, uint64_t at) { return (rd8(j, at) << 8) | rd8(j, at + 1); }
/* Read the headers: tables, the frame, and where the compressed scan starts. Baseline only. */
static int open_jpg(jpg *j, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 4) return 0;
    j->d = b->bytes; j->n = b->size - 64; j->bad = 0; j->width = 0; j->comps = 0; j->restart = 0; j->scan = 0;
    for (int i = 0; i < 4; i++) { j->dc[i].present = 0; j->ac[i].present = 0; }
    if (rd16(j, 0) != 0xffd8) return 0;
    for (uint64_t at = 2; at + 4 <= j->n && !j->bad; ) {
        if (rd8(j, at) != 0xff) return 0; uint32_t m = rd8(j, at + 1); if (m == 0xff) { at++; continue; }
        uint32_t len = rd16(j, at + 2); if (len < 2 || at + 2 + len > j->n) return 0; uint64_t body = at + 4, end = at + 2 + len;
        if (m == 0xdb) { for (uint64_t q = body; q < end; ) { uint32_t pq = rd8(j, q) >> 4, tq = rd8(j, q) & 15; if (tq > 3 || pq > 1) return 0; q++;
                for (int i = 0; i < 64; i++) { j->quant[tq][i] = (uint16_t)(pq ? rd16(j, q) : rd8(j, q)); q += pq ? 2 : 1; } } }
        else if (m == 0xc4) { for (uint64_t q = body; q < end; ) { uint32_t tc = rd8(j, q) >> 4, th = rd8(j, q) & 15; if (tc > 1 || th > 3) return 0; q++; huff *h = tc ? &j->ac[th] : &j->dc[th];
                int total = 0; h->count[0] = 0; for (int i = 1; i <= 16; i++) { h->count[i] = (uint8_t)rd8(j, q++); total += h->count[i]; } if (total > 256) return 0;
                for (int i = 0; i < total; i++) h->symbol[i] = (uint8_t)rd8(j, q++); h->present = 1; } }
        else if (m == 0xc0) { if (rd8(j, body) != 8) return 0; j->height = rd16(j, body + 1); j->width = rd16(j, body + 3); j->comps = (int)rd8(j, body + 5); if (j->comps != 1 && j->comps != 3) return 0;
            j->hmax = j->vmax = 1; for (int i = 0; i < j->comps; i++) { uint32_t hv = rd8(j, body + 7 + 3 * i); j->c[i].h = (int)(hv >> 4); j->c[i].v = (int)(hv & 15); j->c[i].q = (int)rd8(j, body + 8 + 3 * i);
                if (j->c[i].h < 1 || j->c[i].h > 2 || j->c[i].v < 1 || j->c[i].v > 2 || j->c[i].q > 3) return 0; if (j->c[i].h > j->hmax) j->hmax = j->c[i].h; if (j->c[i].v > j->vmax) j->vmax = j->c[i].v; } }
        else if (m == 0xc1 || m == 0xc2 || (m >= 0xc5 && m <= 0xcf && m != 0xc8)) return 0;      /* progressive, lossless, arithmetic: not read */
        else if (m == 0xdd) j->restart = (int)rd16(j, body);
        else if (m == 0xda) { if (!j->comps || (int)rd8(j, body) != j->comps) return 0; for (int i = 0; i < j->comps; i++) { uint32_t t = rd8(j, body + 2 + 2 * i); j->c[i].dc = (int)(t >> 4); j->c[i].ac = (int)(t & 15); if (j->c[i].dc > 3 || j->c[i].ac > 3 || !j->dc[j->c[i].dc].present || !j->ac[j->c[i].ac].present) return 0; }
            j->scan = end; break; }
        at = end; }
    if (j->bad || !j->scan || !j->width || !j->height || j->width > 16384 || j->height > 16384) return 0;
    if (j->comps == 3 && (j->c[1].h != 1 || j->c[1].v != 1 || j->c[2].h != 1 || j->c[2].v != 1)) return 0;   /* colour planes at the base rate only */
    return 1;
}
static int bit(jpg *j) {
    if (!j->have) { uint32_t byte = 0; if (!j->marker && j->pos < j->n) { byte = j->d[j->pos++]; if (byte == 0xff) { uint32_t next = j->pos < j->n ? j->d[j->pos] : 0xd9; if (next == 0) j->pos++; else { j->marker = 1; j->pos--; byte = 0; } } }
        j->bits = byte; j->have = 8; }
    j->have--; return (int)((j->bits >> j->have) & 1);
}
static int receive(jpg *j, int s) { int v = 0; for (int i = 0; i < s; i++) v = (v << 1) | bit(j); return v; }
static int extend(int v, int s) { return s && v < (1 << (s - 1)) ? v - (1 << s) + 1 : v; }
static int symbol(jpg *j, const huff *h) { int code = 0, first = 0, index = 0;
    for (int len = 1; len <= 16; len++) { code |= bit(j); int count = h->count[len]; if (code - first < count) return h->symbol[index + (code - first)]; index += count; first = (first + count) << 1; code <<= 1; }
    j->bad = 1; return 0; }
static uint8_t clamp(int32_t v) { return (uint8_t)(v < 0 ? 0 : v > 255 ? 255 : v); }
#define F(x) ((int32_t)((x) * 4096 + 0.5))
/* The inverse transform of one 8 by 8 square, in whole numbers (the widely used "slow integer" method). */
#define IDCT_1D(s0, s1, s2, s3, s4, s5, s6, s7) \
    int32_t t0, t1, t2, t3, p1, p2, p3, p4, p5, x0, x1, x2, x3; \
    p2 = s2; p3 = s6; p1 = (p2 + p3) * F(0.5411961f); t2 = p1 + p3 * F(-1.847759065f); t3 = p1 + p2 * F(0.765366865f); \
    p2 = s0; p3 = s4; t0 = (p2 + p3) * 4096; t1 = (p2 - p3) * 4096; x0 = t0 + t3; x3 = t0 - t3; x1 = t1 + t2; x2 = t1 - t2; \
    t0 = s7; t1 = s5; t2 = s3; t3 = s1; p3 = t0 + t2; p4 = t1 + t3; p1 = t0 + t3; p2 = t1 + t2; p5 = (p3 + p4) * F(1.175875602f); \
    t0 = t0 * F(0.298631336f); t1 = t1 * F(2.053119869f); t2 = t2 * F(3.072711026f); t3 = t3 * F(1.501321110f); \
    p1 = p5 + p1 * F(-0.899976223f); p2 = p5 + p2 * F(-2.562915447f); p3 = p3 * F(-1.961570560f); p4 = p4 * F(-0.390180644f); \
    t3 += p1 + p4; t2 += p2 + p3; t1 += p2 + p4; t0 += p1 + p3;
static void idct(const int32_t *in, uint8_t *out, uint32_t stride) {
    int32_t v[64];
    for (int i = 0; i < 8; i++) { const int32_t *d = in + i; IDCT_1D(d[0], d[8], d[16], d[24], d[32], d[40], d[48], d[56])
        x0 += 512; x1 += 512; x2 += 512; x3 += 512;
        v[i] = (x0 + t3) >> 10; v[i + 56] = (x0 - t3) >> 10; v[i + 8] = (x1 + t2) >> 10; v[i + 48] = (x1 - t2) >> 10; v[i + 16] = (x2 + t1) >> 10; v[i + 40] = (x2 - t1) >> 10; v[i + 24] = (x3 + t0) >> 10; v[i + 32] = (x3 - t0) >> 10; }
    for (int i = 0; i < 8; i++) { const int32_t *d = v + 8 * i; uint8_t *o = out + (uint64_t)i * stride; IDCT_1D(d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7])
        x0 += 65536 + (128 << 17); x1 += 65536 + (128 << 17); x2 += 65536 + (128 << 17); x3 += 65536 + (128 << 17);
        o[0] = clamp((x0 + t3) >> 17); o[7] = clamp((x0 - t3) >> 17); o[1] = clamp((x1 + t2) >> 17); o[6] = clamp((x1 - t2) >> 17); o[2] = clamp((x2 + t1) >> 17); o[5] = clamp((x2 - t1) >> 17); o[3] = clamp((x3 + t0) >> 17); o[4] = clamp((x3 - t0) >> 17); }
}
int64_t size(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)s; (void)a;
    jpg j; if (!open_jpg(&j, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1; return (int64_t)j.width * 65536 + j.height; }
int64_t decode(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    jpg j; if (!open_jpg(&j, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1;
    block *scratch = (block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); if (!scratch || scratch->kind != 5 || scratch->size < 64) return -1;
    uint32_t mw = 8u * (uint32_t)j.hmax, mh = 8u * (uint32_t)j.vmax, mx = (j.width + mw - 1) / mw, my = (j.height + mh - 1) / mh; uint64_t need = 0;
    for (int i = 0; i < j.comps; i++) { j.c[i].pw = mx * 8u * (uint32_t)j.c[i].h; j.c[i].ph = my * 8u * (uint32_t)j.c[i].v; j.c[i].at = need; need += (uint64_t)j.c[i].pw * j.c[i].ph; j.c[i].pred = 0; }
    if (scratch->size - 64 < need) return -1;
    uint8_t *plane = scratch->bytes; j.pos = j.scan; j.have = 0; j.marker = 0; uint32_t done = 0;
    for (uint32_t row = 0; row < my; row++) for (uint32_t col = 0; col < mx; col++) {
        if (j.restart && done && done % (uint32_t)j.restart == 0) {          /* a restart point: skip to the marker, start the predictions again */
            j.have = 0; if (j.marker) { j.pos += 2; j.marker = 0; } else { while (j.pos + 1 < j.n && !(j.d[j.pos] == 0xff && j.d[j.pos + 1] >= 0xd0 && j.d[j.pos + 1] <= 0xd7)) j.pos++; j.pos += 2; }
            for (int i = 0; i < j.comps; i++) j.c[i].pred = 0; }
        for (int i = 0; i < j.comps; i++) for (int by = 0; by < j.c[i].v; by++) for (int bx = 0; bx < j.c[i].h; bx++) {
            int32_t coef[64]; for (int k = 0; k < 64; k++) coef[k] = 0; const uint16_t *q = j.quant[j.c[i].q];
            int t = symbol(&j, &j.dc[j.c[i].dc]); if (t > 11) j.bad = 1; j.c[i].pred += extend(receive(&j, t), t); coef[0] = j.c[i].pred * q[0];
            for (int k = 1; k < 64 && !j.bad; ) { int rs = symbol(&j, &j.ac[j.c[i].ac]), r = rs >> 4, sz = rs & 15;
                if (!sz) { if (r == 15) { k += 16; continue; } break; }
                k += r; if (k > 63) { j.bad = 1; break; } coef[zigzag[k]] = extend(receive(&j, sz), sz) * q[k]; k++; }
            if (j.bad) return -1;
            idct(coef, plane + j.c[i].at + (uint64_t)(row * (uint32_t)j.c[i].v + (uint32_t)by) * 8 * j.c[i].pw + (uint64_t)(col * (uint32_t)j.c[i].h + (uint32_t)bx) * 8, j.c[i].pw); }
        done++; }
    int64_t written = 0;
    for (uint32_t y = 0; y < j.height && y < s->height; y++) for (uint32_t x = 0; x < j.width && x < s->width; x++) {
        uint8_t *d = s->pixels + (uint64_t)y * s->stride + (uint64_t)x * 4; int32_t Y = plane[j.c[0].at + (uint64_t)(y * (uint32_t)j.c[0].v / (uint32_t)j.vmax) * j.c[0].pw + x * (uint32_t)j.c[0].h / (uint32_t)j.hmax];
        if (j.comps == 1) { d[0] = d[1] = d[2] = (uint8_t)Y; }
        else { int32_t cb = plane[j.c[1].at + (uint64_t)(y / (uint32_t)j.vmax) * j.c[1].pw + x / (uint32_t)j.hmax] - 128, cr = plane[j.c[2].at + (uint64_t)(y / (uint32_t)j.vmax) * j.c[2].pw + x / (uint32_t)j.hmax] - 128;
            d[0] = clamp(((Y << 16) + 91881 * cr + 32768) >> 16); d[1] = clamp(((Y << 16) - 22554 * cb - 46802 * cr + 32768) >> 16); d[2] = clamp(((Y << 16) + 116130 * cb + 32768) >> 16); }
        d[3] = 255; written++; }
    return written;
}
