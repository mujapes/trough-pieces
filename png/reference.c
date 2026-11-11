/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
#include "../crc32_table.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint32_t version, width, height, stride; uint64_t size; uint8_t reserved[40]; uint8_t pixels[]; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
/* --- the file: chunks, and the compressed stream that runs through its IDAT chunks --- */
typedef struct { const uint8_t *d; uint64_t n; uint32_t width, height, type, channels, depth, interlace; uint64_t plte, plte_n, trns, trns_n, first_idat;
                 uint64_t at, left; uint32_t bits; int have; int bad; } png;
static uint32_t be32(const uint8_t *d, uint64_t n, uint64_t at) { if (at + 4 > n) return 0; return ((uint32_t)d[at] << 24) | ((uint32_t)d[at + 1] << 16) | ((uint32_t)d[at + 2] << 8) | d[at + 3]; }
static int open_png(png *g, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 33) return 0;
    g->d = b->bytes; g->n = b->size - 64;
    static const uint8_t magic[8] = {137, 80, 78, 71, 13, 10, 26, 10}; for (int i = 0; i < 8; i++) if (g->d[i] != magic[i]) return 0;
    g->plte = g->plte_n = g->trns = g->trns_n = g->first_idat = 0; g->width = 0;
    for (uint64_t at = 8; at + 12 <= g->n; ) { uint32_t len = be32(g->d, g->n, at), tag = be32(g->d, g->n, at + 4); uint64_t body = at + 8; if (body + len + 4 > g->n) return 0;
        if (crc32_of(g->d + at + 4, 4 + (uint64_t)len) != be32(g->d, g->n, body + len)) return 0;      /* every chunk carries a checksum of its type and contents: damage is refused here */
        if (tag == 0x49484452) { if (len < 13) return 0; g->width = be32(g->d, g->n, body); g->height = be32(g->d, g->n, body + 4);
            if (g->d[body + 10] != 0 || g->d[body + 11] != 0 || g->d[body + 12] > 1) return 0; g->type = g->d[body + 9]; g->depth = g->d[body + 8]; g->interlace = g->d[body + 12]; }
        else if (tag == 0x504c5445) { g->plte = body; g->plte_n = len / 3; }
        else if (tag == 0x74524e53) { g->trns = body; g->trns_n = len; }
        else if (tag == 0x49444154 && !g->first_idat) g->first_idat = at;
        else if (tag == 0x49454e44) break;
        at = body + len + 4; }
    if (!g->width || !g->height || g->width > 16384 || g->height > 16384 || !g->first_idat) return 0;
    g->channels = g->type == 0 ? 1 : g->type == 2 ? 3 : g->type == 3 ? 1 : g->type == 4 ? 2 : g->type == 6 ? 4 : 0;
    if (!g->channels || (g->type == 3 && !g->plte_n)) return 0;
    if (!(g->depth == 8 || (g->depth == 16 && g->type != 3) || ((g->depth == 1 || g->depth == 2 || g->depth == 4) && (g->type == 0 || g->type == 3)))) return 0;
    g->at = g->first_idat + 8; g->left = be32(g->d, g->n, g->first_idat); g->bits = 0; g->have = 0; g->bad = 0; return 1;
}
static uint32_t next_byte(png *g) {                 /* the next byte of compressed data, stepping from one IDAT chunk to the next */
    while (!g->left) { uint64_t next = g->at + 4; if (next + 12 > g->n || be32(g->d, g->n, next + 4) != 0x49444154) { g->bad = 1; return 0; }
        g->left = be32(g->d, g->n, next); g->at = next + 8; if (g->at + g->left + 4 > g->n) { g->bad = 1; g->left = 0; return 0; } }
    g->left--; return g->d[g->at++];
}
static uint32_t bits(png *g, int need) { while (g->have < need) { g->bits |= next_byte(g) << g->have; g->have += 8; } uint32_t v = g->bits & ((1u << need) - 1); g->bits >>= need; g->have -= need; return need ? v : 0; }
/* --- inflate: Huffman codes described by how many codes there are of each length, and the symbols in order --- */
typedef struct { uint16_t count[16], symbol[288]; } huffman;
static void build(huffman *h, const uint8_t *lengths, int n) {
    for (int i = 0; i < 16; i++) h->count[i] = 0; for (int i = 0; i < n; i++) h->count[lengths[i]]++; h->count[0] = 0;
    uint16_t offs[16]; offs[1] = 0; for (int i = 1; i < 15; i++) offs[i + 1] = (uint16_t)(offs[i] + h->count[i]);
    for (int i = 0; i < n; i++) if (lengths[i]) h->symbol[offs[lengths[i]]++] = (uint16_t)i;
}
static int decode_symbol(png *g, const huffman *h) {
    int code = 0, first = 0, index = 0;
    for (int len = 1; len <= 15; len++) { code |= (int)bits(g, 1); int count = h->count[len]; if (code - count < first) return h->symbol[index + (code - first)];
        index += count; first += count; first <<= 1; code <<= 1; if (g->bad) return -1; }
    g->bad = 1; return -1;
}
static int64_t inflate(png *g, uint8_t *out, uint64_t room) {
    static const uint16_t lbase[29] = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258};
    static const uint8_t lext[29] = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0};
    static const uint16_t dbase[30] = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577};
    static const uint8_t dext[30] = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13};
    static const uint8_t order[19] = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15};
    bits(g, 16);                                                 /* the two zlib header bytes */
    uint64_t made = 0; int last;
    do { last = (int)bits(g, 1); int kind = (int)bits(g, 2); if (g->bad) return -1;
        if (kind == 0) { g->bits = 0; g->have = 0; uint32_t len = next_byte(g); len |= next_byte(g) << 8; next_byte(g); next_byte(g);
            for (uint32_t i = 0; i < len; i++) { if (made >= room) return -1; out[made++] = (uint8_t)next_byte(g); } if (g->bad) return -1; continue; }
        if (kind == 3) return -1;
        huffman lit, dist; uint8_t lengths[320];
        if (kind == 1) { for (int i = 0; i < 144; i++) lengths[i] = 8; for (int i = 144; i < 256; i++) lengths[i] = 9; for (int i = 256; i < 280; i++) lengths[i] = 7; for (int i = 280; i < 288; i++) lengths[i] = 8;
            build(&lit, lengths, 288); for (int i = 0; i < 30; i++) lengths[i] = 5; build(&dist, lengths, 30); }
        else { int nlen = (int)bits(g, 5) + 257, ndist = (int)bits(g, 5) + 1, ncode = (int)bits(g, 4) + 4; if (nlen > 286 || ndist > 30) return -1;
            uint8_t cl[19]; for (int i = 0; i < 19; i++) cl[i] = 0; for (int i = 0; i < ncode; i++) cl[order[i]] = (uint8_t)bits(g, 3);
            huffman codes; build(&codes, cl, 19); int i = 0;
            while (i < nlen + ndist) { int sym = decode_symbol(g, &codes); if (sym < 0) return -1;
                if (sym < 16) lengths[i++] = (uint8_t)sym;
                else { int rep, val = 0; if (sym == 16) { if (!i) return -1; val = lengths[i - 1]; rep = 3 + (int)bits(g, 2); } else if (sym == 17) rep = 3 + (int)bits(g, 3); else rep = 11 + (int)bits(g, 7);
                    if (i + rep > nlen + ndist) return -1; while (rep--) lengths[i++] = (uint8_t)val; } }
            build(&lit, lengths, nlen); build(&dist, lengths + nlen, ndist); }
        for (;;) { int sym = decode_symbol(g, &lit); if (sym < 0 || g->bad) return -1;
            if (sym < 256) { if (made >= room) return -1; out[made++] = (uint8_t)sym; continue; }
            if (sym == 256) break; sym -= 257; if (sym >= 29) return -1;
            uint32_t len = lbase[sym] + bits(g, lext[sym]); int ds = decode_symbol(g, &dist); if (ds < 0 || ds >= 30) return -1;
            uint64_t back = dbase[ds] + bits(g, dext[ds]); if (back > made || made + len > room) return -1;
            for (uint32_t i = 0; i < len; i++) { out[made] = out[made - back]; made++; } }
    } while (!last);
    return g->bad ? -1 : (int64_t)made;
}
int64_t size(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)s; (void)a;
    png g; if (!open_png(&g, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1; return (int64_t)g.width * 65536 + g.height; }
/* One pixel of a row, whatever the file's depth and kind, as red, green, blue, alpha. */
static inline int emit(const png *g, const uint8_t *cur, uint64_t i, uint8_t *d) {
    uint32_t v[4] = {0, 0, 0, 0}, depth = g->depth;
    if (depth == 8) { const uint8_t *q = cur + i * g->channels; for (uint32_t c = 0; c < g->channels; c++) v[c] = q[c]; }
    else if (depth == 16) { const uint8_t *q = cur + i * g->channels * 2; for (uint32_t c = 0; c < g->channels; c++) v[c] = ((uint32_t)q[2 * c] << 8) | q[2 * c + 1]; }
    else v[0] = (uint32_t)(cur[(i * depth) >> 3] >> (8 - depth - ((i * depth) & 7))) & ((1u << depth) - 1);
    if (g->type == 3) { uint32_t k = v[0]; if (k >= g->plte_n || g->plte + 3 * (uint64_t)k + 3 > g->n) return 0; d[0] = g->d[g->plte + 3 * k]; d[1] = g->d[g->plte + 3 * k + 1]; d[2] = g->d[g->plte + 3 * k + 2]; d[3] = k < g->trns_n ? g->d[g->trns + k] : 255; return 1; }
    uint32_t t[4]; for (int c = 0; c < 4; c++) t[c] = depth == 16 ? v[c] >> 8 : depth == 8 ? v[c] : v[c] * 255 / ((1u << depth) - 1);
    if (g->type == 6) { d[0] = (uint8_t)t[0]; d[1] = (uint8_t)t[1]; d[2] = (uint8_t)t[2]; d[3] = (uint8_t)t[3]; }
    else if (g->type == 2) { d[0] = (uint8_t)t[0]; d[1] = (uint8_t)t[1]; d[2] = (uint8_t)t[2]; d[3] = 255;
        if (g->trns_n >= 6 && v[0] == (((uint32_t)g->d[g->trns] << 8) | g->d[g->trns + 1]) && v[1] == (((uint32_t)g->d[g->trns + 2] << 8) | g->d[g->trns + 3]) && v[2] == (((uint32_t)g->d[g->trns + 4] << 8) | g->d[g->trns + 5])) d[3] = 0; }
    else if (g->type == 0) { d[0] = d[1] = d[2] = (uint8_t)t[0]; d[3] = (g->trns_n >= 2 && v[0] == (((uint32_t)g->d[g->trns] << 8) | g->d[g->trns + 1])) ? 0 : 255; }
    else { d[0] = d[1] = d[2] = (uint8_t)t[0]; d[3] = (uint8_t)t[1]; }
    return 1;
}
int64_t decode(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    png g; if (!open_png(&g, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1;
    block *scratch = (block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); if (!scratch || scratch->kind != 5 || scratch->size < 64) return -1;
    /* An interlaced file holds seven smaller pictures (every 8th pixel first, then the gaps); otherwise one. */
    static const uint8_t px0[7] = {0, 4, 0, 2, 0, 1, 0}, py0[7] = {0, 0, 4, 0, 2, 0, 1}, pdx[7] = {8, 8, 4, 4, 2, 2, 1}, pdy[7] = {8, 8, 8, 4, 4, 2, 2};
    uint64_t bitsper = (uint64_t)g.channels * g.depth, bpp = bitsper >= 8 ? bitsper / 8 : 1, need = 0; int passes = g.interlace ? 7 : 1;
    for (int k = 0; k < passes; k++) { uint64_t x0 = g.interlace ? px0[k] : 0, y0 = g.interlace ? py0[k] : 0, dx = g.interlace ? pdx[k] : 1, dy = g.interlace ? pdy[k] : 1;
        uint64_t pw = (g.width + dx - 1 - x0) / dx, ph = (g.height + dy - 1 - y0) / dy; if (g.width <= x0 || g.height <= y0) continue; need += ph * (1 + (pw * bitsper + 7) / 8); }
    if (scratch->size - 64 < need) return -1;
    uint8_t *raw = scratch->bytes; if (inflate(&g, raw, need) != (int64_t)need) return -1;
    int64_t written = 0;
    for (int k = 0; k < passes; k++) { uint64_t x0 = g.interlace ? px0[k] : 0, y0 = g.interlace ? py0[k] : 0, dx = g.interlace ? pdx[k] : 1, dy = g.interlace ? pdy[k] : 1;
        if (g.width <= x0 || g.height <= y0) continue; uint64_t pw = (g.width + dx - 1 - x0) / dx, ph = (g.height + dy - 1 - y0) / dy, row = 1 + (pw * bitsper + 7) / 8;
        for (uint64_t r = 0; r < ph; r++) { uint8_t *cur = raw + r * row + 1, *up = r ? cur - row : 0; uint32_t filter = cur[-1]; if (filter > 4) return -1;
        for (uint64_t i = 0; i < row - 1; i++) { uint32_t left = i >= bpp ? cur[i - bpp] : 0, above = up ? up[i] : 0, corner = (up && i >= bpp) ? up[i - bpp] : 0, add = 0;
                if (filter == 1) add = left; else if (filter == 2) add = above; else if (filter == 3) add = (left + above) / 2;
                else if (filter == 4) { int32_t pa = (int32_t)above - (int32_t)corner, pb = (int32_t)left - (int32_t)corner, pc = pa + pb; if (pa < 0) pa = -pa; if (pb < 0) pb = -pb; if (pc < 0) pc = -pc;
                    add = (pa <= pb && pa <= pc) ? left : (pb <= pc) ? above : corner; }
                cur[i] = (uint8_t)(cur[i] + add); }
        uint64_t y = y0 + r * dy; if (y >= s->height) continue;
            for (uint64_t i = 0; i < pw; i++) { uint64_t x = x0 + i * dx; if (x >= s->width) break; if (!emit(&g, cur, i, s->pixels + y * s->stride + x * 4)) return -1; written++; } }
        raw += ph * row; }
    return written;
}
