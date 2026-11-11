/* The meaning of the piece. Table lookup for the codes from the start (the png piece showed bit-at-a-time is slow). */
#include <stdint.h>
#include "../slots.h"
#include "../crc32_table.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { const uint8_t *d; uint64_t n, at; uint32_t bits; int have, padded, bad; } reader;
static void fill(reader *g, int need) { while (g->have < need) { if (g->at >= g->n) g->padded += 8; else g->bits |= (uint32_t)g->d[g->at++] << g->have; g->have += 8; } }
static void take(reader *g, int n) { g->bits >>= n; g->have -= n; if (g->have < g->padded) g->bad = 1; }
static uint32_t bits(reader *g, int need) { if (!need) return 0; fill(g, need); uint32_t v = g->bits & ((1u << need) - 1); take(g, need); return v; }
typedef struct { uint16_t count[16], symbol[288], fast[512]; } huffman;
static void build(huffman *h, const uint8_t *lengths, int n) {
    for (int i = 0; i < 16; i++) h->count[i] = 0; for (int i = 0; i < n; i++) h->count[lengths[i]]++; h->count[0] = 0;
    uint16_t offs[16]; offs[1] = 0; for (int i = 1; i < 15; i++) offs[i + 1] = (uint16_t)(offs[i] + h->count[i]);
    for (int i = 0; i < n; i++) if (lengths[i]) h->symbol[offs[lengths[i]]++] = (uint16_t)i;
    for (int i = 0; i < 512; i++) h->fast[i] = 0; int code = 0, index = 0;
    for (int len = 1; len <= 9; len++) { for (int k = 0; k < h->count[len]; k++) { int rev = 0; for (int b = 0; b < len; b++) if (code & (1 << b)) rev |= 1 << (len - 1 - b);
            for (int f = rev; f < 512; f += 1 << len) h->fast[f] = (uint16_t)((len << 9) | h->symbol[index]); code++; index++; } code <<= 1; }
}
static int decode_symbol(reader *g, const huffman *h) {
    fill(g, 15); uint32_t e = h->fast[g->bits & 511]; if (e) { take(g, (int)(e >> 9)); return g->bad ? -1 : (int)(e & 511); }
    int code = 0, first = 0, index = 0;
    for (int len = 1; len <= 15; len++) { code |= (int)bits(g, 1); int count = h->count[len]; if (code - count < first) return h->symbol[index + (code - first)];
        index += count; first += count; first <<= 1; code <<= 1; if (g->bad) return -1; }
    g->bad = 1; return -1;
}
static int64_t deflate(reader *g, uint8_t *out, uint64_t room) {
    static const uint16_t lbase[29] = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258};
    static const uint8_t lext[29] = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0};
    static const uint16_t dbase[30] = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577};
    static const uint8_t dext[30] = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13};
    static const uint8_t order[19] = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15};
    uint64_t made = 0; int last;
    do { last = (int)bits(g, 1); int kind = (int)bits(g, 2); if (g->bad) return -1;
        if (kind == 0) { take(g, g->have & 7); uint32_t len = bits(g, 16), not_len = bits(g, 16); if (g->bad || (len ^ 0xffff) != not_len) return -1;
            for (uint32_t i = 0; i < len; i++) { if (made >= room) return -1; out[made++] = (uint8_t)bits(g, 8); } if (g->bad) return -1; continue; }
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
            uint64_t back = dbase[ds] + bits(g, dext[ds]); if (g->bad || back > made || made + len > room) return -1;
            for (uint32_t i = 0; i < len; i++) { out[made] = out[made - back]; made++; } }
    } while (!last);
    return g->bad ? -1 : (int64_t)made;
}
/* Where the deflate data starts, and for gzip the length it states. Returns 0 if the block cannot be used. */
static int locate(const block *b, reader *g, int *gzip, uint32_t *stated) {
    if (!b || b->kind != 2 || b->size < 64 + 2) return 0;
    const uint8_t *d = b->bytes; uint64_t n = b->size - 64, at = 0; *gzip = 0; *stated = 0;
    if (n >= 18 && d[0] == 0x1f && d[1] == 0x8b) { if (d[2] != 8) return 0; uint32_t flags = d[3]; at = 10;
        if (flags & 4) { if (at + 2 > n) return 0; at += 2 + (d[at] | ((uint64_t)d[at + 1] << 8)); }
        if (flags & 8) { while (at < n && d[at]) at++; at++; }
        if (flags & 16) { while (at < n && d[at]) at++; at++; }
        if (flags & 2) at += 2;
        if (at + 8 > n) return 0; *gzip = 1; *stated = d[n - 4] | ((uint32_t)d[n - 3] << 8) | ((uint32_t)d[n - 2] << 16) | ((uint32_t)d[n - 1] << 24); n -= 8; }
    else if ((d[0] & 15) == 8 && (((uint32_t)d[0] << 8) | d[1]) % 31 == 0 && !(d[1] & 32)) at = 2;      /* zlib */
    g->d = d; g->n = n; g->at = at; g->bits = 0; g->have = 0; g->padded = 0; g->bad = 0; return 1;
}
int64_t size(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)out; (void)a;
    reader g; int gzip; uint32_t stated; if (!locate((const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1), &g, &gzip, &stated) || !gzip) return -1; return (int64_t)stated; }
int64_t unpack(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    reader g; int gzip; uint32_t stated; const block *in = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1);
    if (!locate(in, &g, &gzip, &stated) || (const block *)out == in || out->size < 64) return -1;
    uint8_t *o = (uint8_t *)out + 64; int64_t made = deflate(&g, o, out->size - 64);
    if (made < 0 || (gzip && (uint32_t)made != stated)) return -1;
    const uint8_t *d = in->bytes; uint64_t len = in->size - 64;
    if (gzip) {                                                   /* gzip ends with a CRC-32 of what was unpacked, then its length */
        uint32_t want = d[len - 8] | ((uint32_t)d[len - 7] << 8) | ((uint32_t)d[len - 6] << 16) | ((uint32_t)d[len - 5] << 24);
        if (crc32_of(o, (uint64_t)made) != want) return -1; }
    else if (g.at >= 2 && (d[0] & 15) == 8 && (((uint32_t)d[0] << 8) | d[1]) % 31 == 0 && !(d[1] & 32)) {      /* zlib ends with an Adler-32, most significant byte first */
        uint64_t end = g.at - (uint64_t)((g.have - g.padded) / 8); if (end + 4 > len) return -1;
        uint32_t a = 1, b = 0; for (int64_t k = 0; k < made; k++) { a = (a + o[k]) % 65521; b = (b + a) % 65521; }
        if (((b << 16) | a) != (((uint32_t)d[end] << 24) | ((uint32_t)d[end + 1] << 16) | ((uint32_t)d[end + 2] << 8) | d[end + 3])) return -1; }
    return made;
}
