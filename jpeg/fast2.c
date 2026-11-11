/* A faster implementation of the jpeg piece: the same pixels as reference.c, reached with a lookup table for the
 * compressed codes, a shortcut for squares that are flat, and a colour loop without divisions. The recorded
 * checks are what prove "same". */
#include <stdint.h>
#include <arm_neon.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
typedef struct { uint8_t count[17]; uint8_t symbol[256]; int present; uint16_t fast[512]; } huff;   /* fast: for the next 9 bits, (length << 8) | symbol, or 0 when the code is longer */
typedef struct { int h, v, q, dc, ac, pred, id; uint32_t pw, ph; uint64_t at; } comp;
typedef struct { const uint8_t *d; uint64_t n, pos; int bad; uint32_t width, height; int comps, hmax, vmax, restart, progressive; uint16_t quant[4][64]; huff dc[4], ac[4]; comp c[3];
                 uint32_t bits; int have; int marker; uint64_t scan; } jpg;
static const uint8_t zigzag[64] = {0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63};
static uint32_t rd8(jpg *j, uint64_t at) { if (at >= j->n) { j->bad = 1; return 0; } return j->d[at]; }
static uint32_t rd16(jpg *j, uint64_t at) { return (rd8(j, at) << 8) | rd8(j, at + 1); }
/* Read the headers: tables, the frame, and where the compressed scan starts. Baseline only. */
static int open_jpg(jpg *j, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 4) return 0;
    j->d = b->bytes; j->n = b->size - 64; j->bad = 0; j->width = 0; j->comps = 0; j->restart = 0; j->scan = 0; j->progressive = 0;
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
        else if (m == 0xc0 || m == 0xc2) { j->progressive = m == 0xc2; if (rd8(j, body) != 8) return 0; j->height = rd16(j, body + 1); j->width = rd16(j, body + 3); j->comps = (int)rd8(j, body + 5); if (j->comps != 1 && j->comps != 3) return 0;
            j->hmax = j->vmax = 1; for (int i = 0; i < j->comps; i++) { uint32_t hv = rd8(j, body + 7 + 3 * i); j->c[i].id = (int)rd8(j, body + 6 + 3 * i); j->c[i].h = (int)(hv >> 4); j->c[i].v = (int)(hv & 15); j->c[i].q = (int)rd8(j, body + 8 + 3 * i);
                if (j->c[i].h < 1 || j->c[i].h > 2 || j->c[i].v < 1 || j->c[i].v > 2 || j->c[i].q > 3) return 0; if (j->c[i].h > j->hmax) j->hmax = j->c[i].h; if (j->c[i].v > j->vmax) j->vmax = j->c[i].v; } }
        else if (m == 0xc1 || (m >= 0xc5 && m <= 0xcf && m != 0xc8)) return 0;      /* extended, lossless, arithmetic: not read */
        else if (m == 0xdd) j->restart = (int)rd16(j, body);
        else if (m == 0xda && j->progressive) { if (!j->comps) return 0; j->scan = at; break; }
        else if (m == 0xda) { if (!j->comps || (int)rd8(j, body) != j->comps) return 0; for (int i = 0; i < j->comps; i++) { uint32_t t = rd8(j, body + 2 + 2 * i); j->c[i].dc = (int)(t >> 4); j->c[i].ac = (int)(t & 15); if (j->c[i].dc > 3 || j->c[i].ac > 3 || !j->dc[j->c[i].dc].present || !j->ac[j->c[i].ac].present) return 0; }
            j->scan = end; break; }
        at = end; }
    if (j->bad || !j->scan || !j->width || !j->height || j->width > 16384 || j->height > 16384) return 0;
    if (j->comps == 3 && (j->c[1].h != 1 || j->c[1].v != 1 || j->c[2].h != 1 || j->c[2].v != 1)) return 0;   /* colour planes at the base rate only */
    return 1;
}
/* The same stream of bits as reference.c reads one at a time, kept 25 or more ahead in a 32-bit window. */
static void fill(jpg *j) {
    while (j->have <= 24) { uint32_t byte = 0; if (!j->marker && j->pos < j->n) { byte = j->d[j->pos++]; if (byte == 0xff) { uint32_t next = j->pos < j->n ? j->d[j->pos] : 0xd9; if (next == 0) j->pos++; else { j->marker = 1; j->pos--; byte = 0; } } }
        j->bits |= byte << (24 - j->have); j->have += 8; }
}
static int receive(jpg *j, int s) { if (!s) return 0; fill(j); int v = (int)(j->bits >> (32 - s)); j->bits <<= s; j->have -= s; return v; }
static int bit(jpg *j) { return receive(j, 1); }
static void prepare(huff *h) {
    for (int i = 0; i < 512; i++) h->fast[i] = 0; int code = 0, index = 0;
    for (int len = 1; len <= 9; len++) { for (int k = 0; k < h->count[len]; k++) { int first = code << (9 - len); for (int f = 0; f < (1 << (9 - len)); f++) h->fast[first + f] = (uint16_t)((len << 8) | h->symbol[index]); code++; index++; } code <<= 1; }
}
static int extend(int v, int s) { return s && v < (1 << (s - 1)) ? v - (1 << s) + 1 : v; }
static int slow_symbol(jpg *j, const huff *h);
static int symbol(jpg *j, const huff *h) { fill(j); uint32_t e = h->fast[j->bits >> 23]; if (e) { int len = (int)(e >> 8); j->bits <<= len; j->have -= len; return (int)(e & 255); } return slow_symbol(j, h); }
static int slow_symbol(jpg *j, const huff *h) { int code = 0, first = 0, index = 0;
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
static inline void idct4(int32x4_t s0, int32x4_t s1, int32x4_t s2, int32x4_t s3, int32x4_t s4, int32x4_t s5, int32x4_t s6, int32x4_t s7,
                         int32x4_t *X0, int32x4_t *X1, int32x4_t *X2, int32x4_t *X3, int32x4_t *T0, int32x4_t *T1, int32x4_t *T2, int32x4_t *T3) {
    int32x4_t t0, t1, t2, t3, p1, p2, p3, p4, p5;
    p2 = s2; p3 = s6; p1 = vmulq_n_s32(vaddq_s32(p2, p3), F(0.5411961f)); t2 = vaddq_s32(p1, vmulq_n_s32(p3, F(-1.847759065f))); t3 = vaddq_s32(p1, vmulq_n_s32(p2, F(0.765366865f)));
    p2 = s0; p3 = s4; t0 = vshlq_n_s32(vaddq_s32(p2, p3), 12); t1 = vshlq_n_s32(vsubq_s32(p2, p3), 12);
    *X0 = vaddq_s32(t0, t3); *X3 = vsubq_s32(t0, t3); *X1 = vaddq_s32(t1, t2); *X2 = vsubq_s32(t1, t2);
    t0 = s7; t1 = s5; t2 = s3; t3 = s1; p3 = vaddq_s32(t0, t2); p4 = vaddq_s32(t1, t3); p1 = vaddq_s32(t0, t3); p2 = vaddq_s32(t1, t2); p5 = vmulq_n_s32(vaddq_s32(p3, p4), F(1.175875602f));
    t0 = vmulq_n_s32(t0, F(0.298631336f)); t1 = vmulq_n_s32(t1, F(2.053119869f)); t2 = vmulq_n_s32(t2, F(3.072711026f)); t3 = vmulq_n_s32(t3, F(1.501321110f));
    p1 = vaddq_s32(p5, vmulq_n_s32(p1, F(-0.899976223f))); p2 = vaddq_s32(p5, vmulq_n_s32(p2, F(-2.562915447f))); p3 = vmulq_n_s32(p3, F(-1.961570560f)); p4 = vmulq_n_s32(p4, F(-0.390180644f));
    *T3 = vaddq_s32(t3, vaddq_s32(p1, p4)); *T2 = vaddq_s32(t2, vaddq_s32(p2, p3)); *T1 = vaddq_s32(t1, vaddq_s32(p2, p4)); *T0 = vaddq_s32(t0, vaddq_s32(p1, p3));
}
/* Four rows of four become four columns of four. */
static inline void turn(int32x4_t a0, int32x4_t a1, int32x4_t a2, int32x4_t a3, int32x4_t *c) {
    int32x4x2_t t01 = vtrnq_s32(a0, a1), t23 = vtrnq_s32(a2, a3);
    c[0] = vcombine_s32(vget_low_s32(t01.val[0]), vget_low_s32(t23.val[0])); c[1] = vcombine_s32(vget_low_s32(t01.val[1]), vget_low_s32(t23.val[1]));
    c[2] = vcombine_s32(vget_high_s32(t01.val[0]), vget_high_s32(t23.val[0])); c[3] = vcombine_s32(vget_high_s32(t01.val[1]), vget_high_s32(t23.val[1]));
}
static void idct(const int32_t *in, uint8_t *out, uint32_t stride, int flat) {
    if (flat) {     /* every other coefficient is zero: both passes reduce to one value, computed exactly as the full method would */
        int32_t col = (in[0] * 4096 + 512) >> 10; uint8_t value = clamp((col * 4096 + 65536 + (128 << 17)) >> 17);
        for (int r = 0; r < 8; r++) { uint8_t *o = out + (uint64_t)r * stride; for (int c = 0; c < 8; c++) o[c] = value; } return; }
    /* The same arithmetic as reference.c, four values at a time: 32-bit lanes, the same constants, the same order of
     * additions and shifts, so the result is the same number for number. Columns first (two halves of four columns),
     * then rows (four rows at a time, turned so each lane is a row). */
    int32x4_t rowv[8][2];
    for (int half = 0; half < 2; half++) { const int32_t *d = in + 4 * half; int32x4_t x0, x1, x2, x3, t0, t1, t2, t3, bias = vdupq_n_s32(512);
        idct4(vld1q_s32(d), vld1q_s32(d + 8), vld1q_s32(d + 16), vld1q_s32(d + 24), vld1q_s32(d + 32), vld1q_s32(d + 40), vld1q_s32(d + 48), vld1q_s32(d + 56), &x0, &x1, &x2, &x3, &t0, &t1, &t2, &t3);
        x0 = vaddq_s32(x0, bias); x1 = vaddq_s32(x1, bias); x2 = vaddq_s32(x2, bias); x3 = vaddq_s32(x3, bias);
        rowv[0][half] = vshrq_n_s32(vaddq_s32(x0, t3), 10); rowv[7][half] = vshrq_n_s32(vsubq_s32(x0, t3), 10); rowv[1][half] = vshrq_n_s32(vaddq_s32(x1, t2), 10); rowv[6][half] = vshrq_n_s32(vsubq_s32(x1, t2), 10);
        rowv[2][half] = vshrq_n_s32(vaddq_s32(x2, t1), 10); rowv[5][half] = vshrq_n_s32(vsubq_s32(x2, t1), 10); rowv[3][half] = vshrq_n_s32(vaddq_s32(x3, t0), 10); rowv[4][half] = vshrq_n_s32(vsubq_s32(x3, t0), 10); }
    for (int group = 0; group < 2; group++) { int r = 4 * group; int32x4_t c[8], x0, x1, x2, x3, t0, t1, t2, t3, bias = vdupq_n_s32(65536 + (128 << 17)), o[8];
        turn(rowv[r][0], rowv[r + 1][0], rowv[r + 2][0], rowv[r + 3][0], c); turn(rowv[r][1], rowv[r + 1][1], rowv[r + 2][1], rowv[r + 3][1], c + 4);
        idct4(c[0], c[1], c[2], c[3], c[4], c[5], c[6], c[7], &x0, &x1, &x2, &x3, &t0, &t1, &t2, &t3);
        x0 = vaddq_s32(x0, bias); x1 = vaddq_s32(x1, bias); x2 = vaddq_s32(x2, bias); x3 = vaddq_s32(x3, bias);
        o[0] = vshrq_n_s32(vaddq_s32(x0, t3), 17); o[7] = vshrq_n_s32(vsubq_s32(x0, t3), 17); o[1] = vshrq_n_s32(vaddq_s32(x1, t2), 17); o[6] = vshrq_n_s32(vsubq_s32(x1, t2), 17);
        o[2] = vshrq_n_s32(vaddq_s32(x2, t1), 17); o[5] = vshrq_n_s32(vsubq_s32(x2, t1), 17); o[3] = vshrq_n_s32(vaddq_s32(x3, t0), 17); o[4] = vshrq_n_s32(vsubq_s32(x3, t0), 17);
        int32x4_t lo[4], hi[4]; turn(o[0], o[1], o[2], o[3], lo); turn(o[4], o[5], o[6], o[7], hi);
        for (int k = 0; k < 4; k++) vst1_u8(out + (uint64_t)(r + k) * stride, vqmovun_s16(vcombine_s16(vqmovn_s32(lo[k]), vqmovn_s32(hi[k])))); }     /* held to 0-255, eight pixels at once */
}
#define IDCT(in, out, stride) idct(in, out, stride, 0)
#define PREPARE(h) prepare(h)
#include "progressive.h"
int64_t size(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)s; (void)a;
    jpg j; if (!open_jpg(&j, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1; return (int64_t)j.width * 65536 + j.height; }
int64_t decode(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    jpg j; if (!open_jpg(&j, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1;
    block *scratch = (block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); if (!scratch || scratch->kind != 5 || scratch->size < 64) return -1;
    uint32_t mw = 8u * (uint32_t)j.hmax, mh = 8u * (uint32_t)j.vmax, mx = (j.width + mw - 1) / mw, my = (j.height + mh - 1) / mh; uint64_t need = 0;
    for (int i = 0; i < j.comps; i++) { j.c[i].pw = mx * 8u * (uint32_t)j.c[i].h; j.c[i].ph = my * 8u * (uint32_t)j.c[i].v; j.c[i].at = need; need += (uint64_t)j.c[i].pw * j.c[i].ph; j.c[i].pred = 0; }
    if (scratch->size - 64 < need) return -1;
    uint8_t *plane = scratch->bytes; j.pos = j.scan; j.have = 0; j.bits = 0; j.marker = 0; uint32_t done = 0;
    for (int i = 0; i < 4; i++) { if (j.dc[i].present) prepare(&j.dc[i]); if (j.ac[i].present) prepare(&j.ac[i]); }
    if (j.progressive) { if (!progressive(&j, scratch, need, mx, my)) return -1; }
    else for (uint32_t row = 0; row < my; row++) for (uint32_t col = 0; col < mx; col++) {
        if (j.restart && done && done % (uint32_t)j.restart == 0) {          /* a restart point: skip to the marker, start the predictions again */
            j.have = 0; j.bits = 0; if (j.marker) { j.pos += 2; j.marker = 0; } else { while (j.pos + 1 < j.n && !(j.d[j.pos] == 0xff && j.d[j.pos + 1] >= 0xd0 && j.d[j.pos + 1] <= 0xd7)) j.pos++; j.pos += 2; }
            for (int i = 0; i < j.comps; i++) j.c[i].pred = 0; }
        for (int i = 0; i < j.comps; i++) for (int by = 0; by < j.c[i].v; by++) for (int bx = 0; bx < j.c[i].h; bx++) {
            int32_t coef[64]; for (int k = 0; k < 64; k++) coef[k] = 0; const uint16_t *q = j.quant[j.c[i].q]; int flat = 1;
            int t = symbol(&j, &j.dc[j.c[i].dc]); if (t > 11) j.bad = 1; j.c[i].pred += extend(receive(&j, t), t); coef[0] = j.c[i].pred * q[0];
            for (int k = 1; k < 64 && !j.bad; ) { int rs = symbol(&j, &j.ac[j.c[i].ac]), r = rs >> 4, sz = rs & 15;
                if (!sz) { if (r == 15) { k += 16; continue; } break; }
                k += r; if (k > 63) { j.bad = 1; break; } coef[zigzag[k]] = extend(receive(&j, sz), sz) * q[k]; if (coef[zigzag[k]]) flat = 0; k++; }
            if (j.bad) return -1;
            idct(coef, plane + j.c[i].at + (uint64_t)(row * (uint32_t)j.c[i].v + (uint32_t)by) * 8 * j.c[i].pw + (uint64_t)(col * (uint32_t)j.c[i].h + (uint32_t)bx) * 8, j.c[i].pw, flat); }
        done++; }
    int64_t written = 0; int xs = j.hmax == 2, ys = j.vmax == 2, lx = j.c[0].h == j.hmax ? 0 : 1, ly = j.c[0].v == j.vmax ? 0 : 1;   /* shifts in place of the divisions */
    uint32_t wide = j.width < s->width ? j.width : s->width;
    for (uint32_t y = 0; y < j.height && y < s->height; y++) {
        uint8_t *d = s->pixels + (uint64_t)y * s->stride; const uint8_t *py = plane + j.c[0].at + (uint64_t)(y >> ly) * j.c[0].pw;
        if (j.comps == 1) { for (uint32_t x = 0; x < wide; x++, d += 4) { uint8_t Y = py[x >> lx]; d[0] = d[1] = d[2] = Y; d[3] = 255; } }
        else { const uint8_t *pb = plane + j.c[1].at + (uint64_t)(y >> ys) * j.c[1].pw, *pr = plane + j.c[2].at + (uint64_t)(y >> ys) * j.c[2].pw;
            for (uint32_t x = 0; x < wide; x++, d += 4) { int32_t Y = py[x >> lx], cb = pb[x >> xs] - 128, cr = pr[x >> xs] - 128;
                d[0] = clamp(((Y << 16) + 91881 * cr + 32768) >> 16); d[1] = clamp(((Y << 16) - 22554 * cb - 46802 * cr + 32768) >> 16); d[2] = clamp(((Y << 16) + 116130 * cb + 32768) >> 16); d[3] = 255; } }
        written += wide; }
    return written;
}
