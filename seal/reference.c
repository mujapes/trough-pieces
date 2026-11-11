/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
static uint32_t le32(const uint8_t *p) { return p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }
static uint32_t rol(uint32_t v, int s) { return (v << s) | (v >> (32 - s)); }
#define QR(a, b, c, d) a += b; d = rol(d ^ a, 16); c += d; b = rol(b ^ c, 12); a += b; d = rol(d ^ a, 8); c += d; b = rol(b ^ c, 7);
/* One 64-byte block of the ChaCha20 stream for this key, nonce and counter. */
static void chacha_block(const uint8_t *key, const uint8_t *nonce, uint32_t counter, uint8_t *out) {
    uint32_t s[16], x[16]; s[0] = 0x61707865; s[1] = 0x3320646e; s[2] = 0x79622d32; s[3] = 0x6b206574;
    for (int i = 0; i < 8; i++) s[4 + i] = le32(key + 4 * i); s[12] = counter; for (int i = 0; i < 3; i++) s[13 + i] = le32(nonce + 4 * i);
    for (int i = 0; i < 16; i++) x[i] = s[i];
    for (int r = 0; r < 10; r++) { QR(x[0], x[4], x[8], x[12]) QR(x[1], x[5], x[9], x[13]) QR(x[2], x[6], x[10], x[14]) QR(x[3], x[7], x[11], x[15])
                                   QR(x[0], x[5], x[10], x[15]) QR(x[1], x[6], x[11], x[12]) QR(x[2], x[7], x[8], x[13]) QR(x[3], x[4], x[9], x[14]) }
    for (int i = 0; i < 16; i++) { uint32_t v = x[i] + s[i]; out[4 * i] = (uint8_t)v; out[4 * i + 1] = (uint8_t)(v >> 8); out[4 * i + 2] = (uint8_t)(v >> 16); out[4 * i + 3] = (uint8_t)(v >> 24); }
}
static void chacha_xor(const uint8_t *key, const uint8_t *nonce, const uint8_t *in, uint8_t *out, uint64_t n) {
    uint8_t ks[64]; uint32_t counter = 1;
    for (uint64_t at = 0; at < n; at += 64, counter++) { chacha_block(key, nonce, counter, ks); for (uint64_t i = 0; i < 64 && at + i < n; i++) out[at + i] = in[at + i] ^ ks[i]; }
}
/* Poly1305: the running value h is kept as five 26-bit parts; each 16-byte block is added in and h multiplied by r, modulo 2^130 - 5. */
typedef struct { uint32_t r[5], h[5]; } poly;
static void poly_begin(poly *p, const uint8_t *key) {
    p->r[0] = le32(key) & 0x3ffffff; p->r[1] = (le32(key + 3) >> 2) & 0x3ffff03; p->r[2] = (le32(key + 6) >> 4) & 0x3ffc0ff; p->r[3] = (le32(key + 9) >> 6) & 0x3f03fff; p->r[4] = (le32(key + 12) >> 8) & 0x00fffff;
    for (int i = 0; i < 5; i++) p->h[i] = 0;
}
static void poly_block(poly *p, const uint8_t *m) {
    uint32_t r0 = p->r[0], r1 = p->r[1], r2 = p->r[2], r3 = p->r[3], r4 = p->r[4], s1 = r1 * 5, s2 = r2 * 5, s3 = r3 * 5, s4 = r4 * 5;
    uint64_t h0 = p->h[0] + (le32(m) & 0x3ffffff), h1 = p->h[1] + ((le32(m + 3) >> 2) & 0x3ffffff), h2 = p->h[2] + ((le32(m + 6) >> 4) & 0x3ffffff), h3 = p->h[3] + ((le32(m + 9) >> 6) & 0x3ffffff), h4 = p->h[4] + ((le32(m + 12) >> 8) | (1u << 24));
    uint64_t d0 = h0 * r0 + h1 * s4 + h2 * s3 + h3 * s2 + h4 * s1, d1 = h0 * r1 + h1 * r0 + h2 * s4 + h3 * s3 + h4 * s2, d2 = h0 * r2 + h1 * r1 + h2 * r0 + h3 * s4 + h4 * s3,
             d3 = h0 * r3 + h1 * r2 + h2 * r1 + h3 * r0 + h4 * s4, d4 = h0 * r4 + h1 * r3 + h2 * r2 + h3 * r1 + h4 * r0, c;
    c = d0 >> 26; d0 &= 0x3ffffff; d1 += c; c = d1 >> 26; d1 &= 0x3ffffff; d2 += c; c = d2 >> 26; d2 &= 0x3ffffff; d3 += c; c = d3 >> 26; d3 &= 0x3ffffff; d4 += c; c = d4 >> 26; d4 &= 0x3ffffff;
    d0 += c * 5; c = d0 >> 26; d0 &= 0x3ffffff; d1 += c;
    p->h[0] = (uint32_t)d0; p->h[1] = (uint32_t)d1; p->h[2] = (uint32_t)d2; p->h[3] = (uint32_t)d3; p->h[4] = (uint32_t)d4;
}
static void poly_run(poly *p, const uint8_t *m, uint64_t n) {          /* whole blocks, the last one padded with zeros */
    for (; n >= 16; m += 16, n -= 16) poly_block(p, m);
    if (n) { uint8_t last[16]; for (int i = 0; i < 16; i++) last[i] = (uint64_t)i < n ? m[i] : 0; poly_block(p, last); }
}
static void poly_finish(poly *p, const uint8_t *key, uint8_t *tag) {
    uint32_t h0 = p->h[0], h1 = p->h[1], h2 = p->h[2], h3 = p->h[3], h4 = p->h[4], c, g0, g1, g2, g3, g4, pick;
    c = h1 >> 26; h1 &= 0x3ffffff; h2 += c; c = h2 >> 26; h2 &= 0x3ffffff; h3 += c; c = h3 >> 26; h3 &= 0x3ffffff; h4 += c; c = h4 >> 26; h4 &= 0x3ffffff; h0 += c * 5; c = h0 >> 26; h0 &= 0x3ffffff; h1 += c;
    g0 = h0 + 5; c = g0 >> 26; g0 &= 0x3ffffff; g1 = h1 + c; c = g1 >> 26; g1 &= 0x3ffffff; g2 = h2 + c; c = g2 >> 26; g2 &= 0x3ffffff; g3 = h3 + c; c = g3 >> 26; g3 &= 0x3ffffff; g4 = h4 + c - (1u << 26);
    pick = (g4 >> 31) - 1;                                               /* all ones if h + 5 reached 2^130, that is if h >= 2^130 - 5 */
    h0 = (h0 & ~pick) | (g0 & pick); h1 = (h1 & ~pick) | (g1 & pick); h2 = (h2 & ~pick) | (g2 & pick); h3 = (h3 & ~pick) | (g3 & pick); h4 = (h4 & ~pick) | (g4 & pick);
    uint32_t w0 = h0 | (h1 << 26), w1 = (h1 >> 6) | (h2 << 20), w2 = (h2 >> 12) | (h3 << 14), w3 = (h3 >> 18) | (h4 << 8); uint64_t f;
    f = (uint64_t)w0 + le32(key + 16); w0 = (uint32_t)f; f = (uint64_t)w1 + le32(key + 20) + (f >> 32); w1 = (uint32_t)f; f = (uint64_t)w2 + le32(key + 24) + (f >> 32); w2 = (uint32_t)f; f = (uint64_t)w3 + le32(key + 28) + (f >> 32); w3 = (uint32_t)f;
    uint32_t w[4] = {w0, w1, w2, w3}; for (int i = 0; i < 4; i++) { tag[4 * i] = (uint8_t)w[i]; tag[4 * i + 1] = (uint8_t)(w[i] >> 8); tag[4 * i + 2] = (uint8_t)(w[i] >> 16); tag[4 * i + 3] = (uint8_t)(w[i] >> 24); }
}
/* The tag over: extra, padded to 16; the locked bytes, padded to 16; then both lengths. */
static void tag_of(const uint8_t *key, const uint8_t *nonce, const uint8_t *extra, uint64_t en, const uint8_t *locked, uint64_t n, uint8_t *tag) {
    uint8_t first[64], lens[16]; chacha_block(key, nonce, 0, first); poly p; poly_begin(&p, first); poly_run(&p, extra, en); poly_run(&p, locked, n);
    for (int i = 0; i < 8; i++) { lens[i] = (uint8_t)(en >> (8 * i)); lens[8 + i] = (uint8_t)(n >> (8 * i)); } poly_block(&p, lens); poly_finish(&p, first, tag);
}
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which, const block *out) {
    const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size >= 64 && b != out ? b : 0; }
int64_t seal(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *key = bytes_at(table, p, n, 0, out), *nonce = bytes_at(table, p, n, 1, out), *extra = bytes_at(table, p, n, 2, out), *msg = bytes_at(table, p, n, 3, out);
    if (!key || !nonce || !extra || !msg || key->size != 64 + 32 || nonce->size != 64 + 12 || out->size < 64) return -1;
    uint64_t len = msg->size - 64; if (out->size - 64 < len + 16) return -1;
    chacha_xor(key->bytes, nonce->bytes, msg->bytes, out->bytes, len); tag_of(key->bytes, nonce->bytes, extra->bytes, extra->size - 64, out->bytes, len, out->bytes + len);
    return (int64_t)len + 16;
}
int64_t open(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *key = bytes_at(table, p, n, 0, out), *nonce = bytes_at(table, p, n, 1, out), *extra = bytes_at(table, p, n, 2, out), *in = bytes_at(table, p, n, 3, out);
    if (!key || !nonce || !extra || !in || key->size != 64 + 32 || nonce->size != 64 + 12 || out->size < 64 || in->size < 64 + 16) return -1;
    uint64_t len = in->size - 64 - 16; if (out->size - 64 < len) return -1;
    uint8_t tag[16]; tag_of(key->bytes, nonce->bytes, extra->bytes, extra->size - 64, in->bytes, len, tag);
    uint32_t differ = 0; for (int i = 0; i < 16; i++) differ |= (uint32_t)(tag[i] ^ in->bytes[len + i]); if (differ) return -1;
    chacha_xor(key->bytes, nonce->bytes, in->bytes, out->bytes, len); return (int64_t)len;
}
