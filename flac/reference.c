/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { const uint8_t *d; uint64_t n, at; int bit; int bad; uint32_t rate, channels, bps, max_block; uint64_t total, audio; } flac;
static uint32_t take(flac *f, int count) {                  /* most significant bit first */
    uint32_t v = 0; for (int i = 0; i < count; i++) { if (f->at >= f->n) { f->bad = 1; return 0; } v = (v << 1) | ((f->d[f->at] >> (7 - f->bit)) & 1); if (++f->bit == 8) { f->bit = 0; f->at++; } } return v; }
static int32_t take_signed(flac *f, int count) { if (!count) return 0; uint32_t v = take(f, count); return count < 32 && (v >> (count - 1)) ? (int32_t)v - (int32_t)(1u << count) : (int32_t)v; }
static uint32_t unary(flac *f) { uint32_t q = 0; while (!f->bad && !take(f, 1)) { if (++q > (1u << 22)) { f->bad = 1; break; } } return q; }
static int open_flac(flac *f, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 42) return 0;
    f->d = b->bytes; f->n = b->size - 64; f->at = 4; f->bit = 0; f->bad = 0; f->rate = 0;
    if (f->d[0] != 'f' || f->d[1] != 'L' || f->d[2] != 'a' || f->d[3] != 'C') return 0;
    for (;;) { if (f->at + 4 > f->n) return 0; uint32_t head = f->d[f->at], len = ((uint32_t)f->d[f->at + 1] << 16) | ((uint32_t)f->d[f->at + 2] << 8) | f->d[f->at + 3]; uint64_t body = f->at + 4; if (body + len > f->n) return 0;
        if ((head & 127) == 0) { if (len < 34) return 0; const uint8_t *s = f->d + body; f->max_block = ((uint32_t)s[2] << 8) | s[3];
            f->rate = ((uint32_t)s[10] << 12) | ((uint32_t)s[11] << 4) | (s[12] >> 4); f->channels = ((s[12] >> 1) & 7) + 1; f->bps = (((uint32_t)(s[12] & 1)) << 4 | (s[13] >> 4)) + 1;
            f->total = ((uint64_t)(s[13] & 15) << 32) | ((uint64_t)s[14] << 24) | ((uint64_t)s[15] << 16) | ((uint64_t)s[16] << 8) | s[17]; }
        f->at = body + len; if (head & 128) break; }
    f->audio = f->at; return f->rate && f->max_block >= 16;
}
int64_t info(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)out; (void)a;
    flac f; if (!open_flac(&f, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1; int which = n > 1 ? p[1] : 0;
    return which == 0 ? (int64_t)f.rate : which == 1 ? (int64_t)f.channels : which == 2 ? (int64_t)f.bps : which == 3 ? (int64_t)f.total : -1; }
static int residual(flac *f, int32_t *s, uint32_t blocksize, uint32_t order) {
    uint32_t method = take(f, 2), porder = take(f, 4); if (method > 1) return 0; int pbits = method ? 5 : 4; uint32_t escape = method ? 31 : 15, parts = 1u << porder, at = order;
    if ((blocksize >> porder) < order || (blocksize & (parts - 1))) { if (porder) return 0; }
    for (uint32_t part = 0; part < parts; part++) { uint32_t count = (blocksize >> porder) - (part ? 0 : order), k = take(f, pbits);
        if (at + count > blocksize) return 0;
        if (k == escape) { int raw = (int)take(f, 5); for (uint32_t i = 0; i < count; i++) s[at++] = take_signed(f, raw); }
        else for (uint32_t i = 0; i < count; i++) { uint32_t q = unary(f), u = (q << k) | (k ? take(f, (int)k) : 0); s[at++] = (int32_t)(u >> 1) ^ -(int32_t)(u & 1); }
        if (f->bad) return 0; }
    return at == blocksize;
}
static int subframe(flac *f, int32_t *s, uint32_t blocksize, int bps) {
    if (take(f, 1)) return 0; uint32_t type = take(f, 6); int wasted = 0; if (take(f, 1)) wasted = (int)unary(f) + 1; if (wasted >= bps) return 0; bps -= wasted;
    if (type == 0) { int32_t v = take_signed(f, bps); for (uint32_t i = 0; i < blocksize; i++) s[i] = v; }
    else if (type == 1) { for (uint32_t i = 0; i < blocksize; i++) s[i] = take_signed(f, bps); }
    else if (type >= 8 && type <= 12) { uint32_t order = type - 8; if (order > blocksize) return 0; for (uint32_t i = 0; i < order; i++) s[i] = take_signed(f, bps);
        if (!residual(f, s, blocksize, order)) return 0;
        for (uint32_t i = order; i < blocksize; i++) { int64_t pred = order == 0 ? 0 : order == 1 ? s[i - 1] : order == 2 ? 2 * (int64_t)s[i - 1] - s[i - 2] : order == 3 ? 3 * (int64_t)s[i - 1] - 3 * (int64_t)s[i - 2] + s[i - 3] : 4 * (int64_t)s[i - 1] - 6 * (int64_t)s[i - 2] + 4 * (int64_t)s[i - 3] - s[i - 4];
            s[i] = (int32_t)(s[i] + pred); } }
    else if (type >= 32) { uint32_t order = (type & 31) + 1; if (order > blocksize) return 0; for (uint32_t i = 0; i < order; i++) s[i] = take_signed(f, bps);
        int precision = (int)take(f, 4) + 1; if (precision == 16) return 0; int shift = take_signed(f, 5); if (shift < 0) return 0; int32_t coef[32]; for (uint32_t j = 0; j < order; j++) coef[j] = take_signed(f, precision);
        if (!residual(f, s, blocksize, order)) return 0;
        for (uint32_t i = order; i < blocksize; i++) { int64_t sum = 0; for (uint32_t j = 0; j < order; j++) sum += (int64_t)coef[j] * s[i - 1 - j]; s[i] = (int32_t)(s[i] + (sum >> shift)); } }
    else return 0;
    if (wasted) for (uint32_t i = 0; i < blocksize; i++) s[i] = (int32_t)((uint32_t)s[i] << wasted);
    return !f->bad;
}
int64_t decode(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    flac f; const block *in = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1); if (!open_flac(&f, in) || (const block *)out == in || out->size < 64) return -1;
    block *scratch = (block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); if (!scratch || scratch->kind != 5 || (block *)out == scratch) return -1;
    if (f.bps != 16 || f.channels > 2 || scratch->size < 64 + 8ull * f.max_block * f.channels) return -1;
    int32_t *chan[2]; chan[0] = (int32_t *)(void *)scratch->bytes; chan[1] = chan[0] + f.max_block;
    uint8_t *o = (uint8_t *)out + 64; uint64_t room = (out->size - 64) / 2, made = 0;
    uint8_t crc8[256]; uint16_t crc16[256]; for (int i = 0; i < 256; i++) { uint32_t c = (uint32_t)i; for (int k = 0; k < 8; k++) c = (c & 0x80) ? ((c << 1) ^ 0x07) & 0xff : (c << 1) & 0xff; crc8[i] = (uint8_t)c;
        uint32_t w = (uint32_t)i << 8; for (int k = 0; k < 8; k++) w = (w & 0x8000) ? ((w << 1) ^ 0x8005) & 0xffff : (w << 1) & 0xffff; crc16[i] = (uint16_t)w; }
    f.at = f.audio; f.bit = 0;
    while (f.at + 2 <= f.n) { uint64_t start = f.at;
        if (take(&f, 14) != 0x3ffe) return -1; take(&f, 2); uint32_t bcode = take(&f, 4), rcode = take(&f, 4), assign = take(&f, 4), scode = take(&f, 3); if (take(&f, 1)) return -1;
        uint32_t lead = take(&f, 8); int extra = lead < 0x80 ? 0 : lead < 0xe0 ? 1 : lead < 0xf0 ? 2 : lead < 0xf8 ? 3 : lead < 0xfc ? 4 : lead < 0xfe ? 5 : 6; for (int i = 0; i < extra; i++) take(&f, 8);
        uint32_t blocksize = bcode == 1 ? 192 : (bcode >= 2 && bcode <= 5) ? 576u << (bcode - 2) : bcode == 6 ? take(&f, 8) + 1 : bcode == 7 ? take(&f, 16) + 1 : bcode >= 8 ? 256u << (bcode - 8) : 0;
        if (rcode == 12) take(&f, 8); else if (rcode == 13 || rcode == 14) take(&f, 16); else if (rcode == 15) return -1;
        if (f.bad || !blocksize || blocksize > f.max_block || (scode != 0 && scode != 4) || assign > 10 || (assign < 8 && assign + 1 != f.channels) || (assign >= 8 && f.channels != 2)) return -1;
        { uint8_t c = 0; for (uint64_t i = start; i < f.at; i++) c = crc8[c ^ f.d[i]]; if (c != take(&f, 8)) return -1; }
        for (uint32_t ch = 0; ch < f.channels; ch++) { int bps = 16 + ((assign == 8 && ch == 1) || (assign == 9 && ch == 0) || (assign == 10 && ch == 1) ? 1 : 0); if (!subframe(&f, chan[ch], blocksize, bps)) return -1; }
        if (f.bit) { f.bit = 0; f.at++; }
        { uint16_t c = 0; for (uint64_t i = start; i < f.at; i++) c = (uint16_t)((c << 8) ^ crc16[(c >> 8) ^ f.d[i]]); if (f.at + 2 > f.n || c != (((uint32_t)f.d[f.at] << 8) | f.d[f.at + 1])) return -1; f.at += 2; }
        if (made + (uint64_t)blocksize * f.channels > room) return -1;
        for (uint32_t i = 0; i < blocksize; i++) { int32_t l, r = 0;
            if (f.channels == 1) l = chan[0][i];
            else if (assign == 8) { l = chan[0][i]; r = l - chan[1][i]; }
            else if (assign == 9) { r = chan[1][i]; l = chan[0][i] + r; }
            else if (assign == 10) { int32_t side = chan[1][i], mid = (int32_t)(((uint32_t)chan[0][i] << 1) | ((uint32_t)side & 1)); l = (mid + side) >> 1; r = (mid - side) >> 1; }
            else { l = chan[0][i]; r = chan[1][i]; }
            o[2 * made] = (uint8_t)l; o[2 * made + 1] = (uint8_t)(l >> 8); made++;
            if (f.channels == 2) { o[2 * made] = (uint8_t)r; o[2 * made + 1] = (uint8_t)(r >> 8); made++; } }
    }
    return (int64_t)made;
}
