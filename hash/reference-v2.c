/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
static const uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 };
typedef struct { uint32_t h[8]; uint8_t buf[64]; uint64_t total; uint32_t fill; } sha;
static uint32_t ror(uint32_t v, int s) { return (v >> s) | (v << (32 - s)); }
static void rounds(uint32_t *h, const uint8_t *p) {
    uint32_t w[64], a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (int i = 0; i < 16; i++) w[i] = ((uint32_t)p[4 * i] << 24) | ((uint32_t)p[4 * i + 1] << 16) | ((uint32_t)p[4 * i + 2] << 8) | p[4 * i + 3];
    for (int i = 16; i < 64; i++) w[i] = w[i - 16] + (ror(w[i - 15], 7) ^ ror(w[i - 15], 18) ^ (w[i - 15] >> 3)) + w[i - 7] + (ror(w[i - 2], 17) ^ ror(w[i - 2], 19) ^ (w[i - 2] >> 10));
    for (int i = 0; i < 64; i++) { uint32_t t1 = hh + (ror(e, 6) ^ ror(e, 11) ^ ror(e, 25)) + ((e & f) ^ (~e & g)) + K[i] + w[i], t2 = (ror(a, 2) ^ ror(a, 13) ^ ror(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
        hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2; }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
}
static void begin(sha *s) { static const uint32_t start[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19}; for (int i = 0; i < 8; i++) s->h[i] = start[i]; s->total = 0; s->fill = 0; }
static void add(sha *s, const uint8_t *p, uint64_t n) { s->total += n;
    while (n) { if (!s->fill && n >= 64) { rounds(s->h, p); p += 64; n -= 64; continue; }
        s->buf[s->fill++] = *p++; n--; if (s->fill == 64) { rounds(s->h, s->buf); s->fill = 0; } } }
static void finish(sha *s, uint8_t *out) { uint64_t bits = s->total * 8; uint8_t pad = 0x80; add(s, &pad, 1); pad = 0; while (s->fill != 56) add(s, &pad, 1);
    uint8_t len[8]; for (int i = 0; i < 8; i++) len[i] = (uint8_t)(bits >> (56 - 8 * i)); add(s, len, 8);
    for (int i = 0; i < 8; i++) { out[4 * i] = (uint8_t)(s->h[i] >> 24); out[4 * i + 1] = (uint8_t)(s->h[i] >> 16); out[4 * i + 2] = (uint8_t)(s->h[i] >> 8); out[4 * i + 3] = (uint8_t)s->h[i]; } }
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which, const block *out) {
    const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size >= 64 && b != out ? b : 0; }
int64_t sha256(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *src = bytes_at(table, p, n, 0, out); if (!src || out->size < 96) return -1;
    sha s; uint8_t digest[32]; begin(&s); add(&s, src->bytes, src->size - 64); finish(&s, digest); for (int i = 0; i < 32; i++) out->bytes[i] = digest[i]; return 32;
}
int64_t hmac_sha256(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *key = bytes_at(table, p, n, 0, out), *msg = bytes_at(table, p, n, 1, out); if (!key || !msg || out->size < 96) return -1;
    uint8_t k[64], pad[64], inner[32], digest[32]; uint64_t kn = key->size - 64; sha s; for (int i = 0; i < 64; i++) k[i] = 0;
    if (kn > 64) { begin(&s); add(&s, key->bytes, kn); finish(&s, k); } else for (uint64_t i = 0; i < kn; i++) k[i] = key->bytes[i];
    for (int i = 0; i < 64; i++) pad[i] = k[i] ^ 0x36; begin(&s); add(&s, pad, 64); add(&s, msg->bytes, msg->size - 64); finish(&s, inner);
    for (int i = 0; i < 64; i++) pad[i] = k[i] ^ 0x5c; begin(&s); add(&s, pad, 64); add(&s, inner, 32); finish(&s, digest);
    for (int i = 0; i < 32; i++) out->bytes[i] = digest[i]; return 32;
}
/* HKDF-Expand-Label of TLS 1.3 (RFC 8446 section 7.1): a named key of the wanted length out of a secret. */
int64_t expand_label(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *secret = bytes_at(table, p, n, 0, out), *label = bytes_at(table, p, n, 1, out), *context = bytes_at(table, p, n, 2, out); int64_t want = n > 3 ? p[3] : 0;
    if (!secret || !label || !context || want < 1 || want > 255 || out->size < 64 + (uint64_t)want) return -1;
    uint64_t sn = secret->size - 64, ln = label->size - 64, cn = context->size - 64; if (ln > 249 || cn > 255) return -1;
    uint8_t info[2 + 1 + 6 + 249 + 1 + 255], k[64], ipad[64], opad[64], t[32], inner[32]; uint32_t in = 0; static const char prefix[6] = {'t', 'l', 's', '1', '3', ' '};
    info[in++] = (uint8_t)(want >> 8); info[in++] = (uint8_t)want; info[in++] = (uint8_t)(6 + ln); for (int i = 0; i < 6; i++) info[in++] = (uint8_t)prefix[i];
    for (uint64_t i = 0; i < ln; i++) info[in++] = label->bytes[i]; info[in++] = (uint8_t)cn; for (uint64_t i = 0; i < cn; i++) info[in++] = context->bytes[i];
    sha s; for (int i = 0; i < 64; i++) k[i] = 0; if (sn > 64) { begin(&s); add(&s, secret->bytes, sn); finish(&s, k); } else for (uint64_t i = 0; i < sn; i++) k[i] = secret->bytes[i];
    for (int i = 0; i < 64; i++) { ipad[i] = k[i] ^ 0x36; opad[i] = k[i] ^ 0x5c; }
    int64_t made = 0; uint8_t result[255];
    for (uint8_t round = 1; made < want; round++) {                      /* T(i) = HMAC(secret, T(i-1) | info | i) */
        begin(&s); add(&s, ipad, 64); if (round > 1) add(&s, t, 32); add(&s, info, in); add(&s, &round, 1); finish(&s, inner);
        begin(&s); add(&s, opad, 64); add(&s, inner, 32); finish(&s, t);
        for (int i = 0; i < 32 && made < want; i++) result[made++] = t[i]; }
    for (int64_t i = 0; i < want; i++) out->bytes[i] = result[i]; return want;
}
