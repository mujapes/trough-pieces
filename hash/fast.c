/* reference.c with the rounds done by the processor's SHA-256 instructions. Everything else is the same text. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
static const uint32_t K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 };
typedef struct { uint32_t h[8]; uint8_t buf[64]; uint64_t total; uint32_t fill; } sha;
/* The same 64 rounds with the processor's own SHA-256 instructions (every ARMv8 phone core since 2015 has them;
 * checked present on the Pixel 7a). Four rounds an instruction pair, message schedule in two more. */
#pragma GCC target("+sha2")
#include <arm_neon.h>
static void rounds(uint32_t *h, const uint8_t *p) {
    uint32x4_t abcd = vld1q_u32(h), efgh = vld1q_u32(h + 4), a0 = abcd, e0 = efgh, m[4];
    for (int i = 0; i < 4; i++) m[i] = vreinterpretq_u32_u8(vrev32q_u8(vld1q_u8(p + 16 * i)));
    for (int i = 0; i < 16; i++) { uint32x4_t wk = vaddq_u32(m[i & 3], vld1q_u32(K + 4 * i)), was = abcd;
        abcd = vsha256hq_u32(abcd, efgh, wk); efgh = vsha256h2q_u32(efgh, was, wk);
        if (i < 12) m[i & 3] = vsha256su1q_u32(vsha256su0q_u32(m[i & 3], m[(i + 1) & 3]), m[(i + 2) & 3], m[(i + 3) & 3]); }
    vst1q_u32(h, vaddq_u32(abcd, a0)); vst1q_u32(h + 4, vaddq_u32(efgh, e0));
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
/* --- SHA-512 and SHA-384 (FIPS 180-4): the same construction with 64-bit words, 128-byte blocks and 80 rounds --- */
static const uint64_t K5[80] = {
    0x428a2f98d728ae22ull, 0x7137449123ef65cdull, 0xb5c0fbcfec4d3b2full, 0xe9b5dba58189dbbcull,
    0x3956c25bf348b538ull, 0x59f111f1b605d019ull, 0x923f82a4af194f9bull, 0xab1c5ed5da6d8118ull,
    0xd807aa98a3030242ull, 0x12835b0145706fbeull, 0x243185be4ee4b28cull, 0x550c7dc3d5ffb4e2ull,
    0x72be5d74f27b896full, 0x80deb1fe3b1696b1ull, 0x9bdc06a725c71235ull, 0xc19bf174cf692694ull,
    0xe49b69c19ef14ad2ull, 0xefbe4786384f25e3ull, 0x0fc19dc68b8cd5b5ull, 0x240ca1cc77ac9c65ull,
    0x2de92c6f592b0275ull, 0x4a7484aa6ea6e483ull, 0x5cb0a9dcbd41fbd4ull, 0x76f988da831153b5ull,
    0x983e5152ee66dfabull, 0xa831c66d2db43210ull, 0xb00327c898fb213full, 0xbf597fc7beef0ee4ull,
    0xc6e00bf33da88fc2ull, 0xd5a79147930aa725ull, 0x06ca6351e003826full, 0x142929670a0e6e70ull,
    0x27b70a8546d22ffcull, 0x2e1b21385c26c926ull, 0x4d2c6dfc5ac42aedull, 0x53380d139d95b3dfull,
    0x650a73548baf63deull, 0x766a0abb3c77b2a8ull, 0x81c2c92e47edaee6ull, 0x92722c851482353bull,
    0xa2bfe8a14cf10364ull, 0xa81a664bbc423001ull, 0xc24b8b70d0f89791ull, 0xc76c51a30654be30ull,
    0xd192e819d6ef5218ull, 0xd69906245565a910ull, 0xf40e35855771202aull, 0x106aa07032bbd1b8ull,
    0x19a4c116b8d2d0c8ull, 0x1e376c085141ab53ull, 0x2748774cdf8eeb99ull, 0x34b0bcb5e19b48a8ull,
    0x391c0cb3c5c95a63ull, 0x4ed8aa4ae3418acbull, 0x5b9cca4f7763e373ull, 0x682e6ff3d6b2b8a3ull,
    0x748f82ee5defb2fcull, 0x78a5636f43172f60ull, 0x84c87814a1f0ab72ull, 0x8cc702081a6439ecull,
    0x90befffa23631e28ull, 0xa4506cebde82bde9ull, 0xbef9a3f7b2c67915ull, 0xc67178f2e372532bull,
    0xca273eceea26619cull, 0xd186b8c721c0c207ull, 0xeada7dd6cde0eb1eull, 0xf57d4f7fee6ed178ull,
    0x06f067aa72176fbaull, 0x0a637dc5a2c898a6ull, 0x113f9804bef90daeull, 0x1b710b35131c471bull,
    0x28db77f523047d84ull, 0x32caab7b40c72493ull, 0x3c9ebe0a15c9bebcull, 0x431d67c49c100d4cull,
    0x4cc5d4becb3e42b6ull, 0x597f299cfc657e2aull, 0x5fcb6fab3ad6faecull, 0x6c44198c4a475817ull,
};
typedef struct { uint64_t h[8]; uint8_t buf[128]; uint64_t total; uint32_t fill; } sha5;
static uint64_t ror5(uint64_t v, int s) { return (v >> s) | (v << (64 - s)); }
static void rounds5(uint64_t *h, const uint8_t *p) {
    uint64_t w[80], a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (int i = 0; i < 16; i++) { uint64_t v = 0; for (int k = 0; k < 8; k++) v = (v << 8) | p[8 * i + k]; w[i] = v; }
    for (int i = 16; i < 80; i++) w[i] = w[i - 16] + (ror5(w[i - 15], 1) ^ ror5(w[i - 15], 8) ^ (w[i - 15] >> 7)) + w[i - 7] + (ror5(w[i - 2], 19) ^ ror5(w[i - 2], 61) ^ (w[i - 2] >> 6));
    for (int i = 0; i < 80; i++) { uint64_t t1 = hh + (ror5(e, 14) ^ ror5(e, 18) ^ ror5(e, 41)) + ((e & f) ^ (~e & g)) + K5[i] + w[i], t2 = (ror5(a, 28) ^ ror5(a, 34) ^ ror5(a, 39)) + ((a & b) ^ (a & c) ^ (b & c));
        hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2; }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
}
static void add5(sha5 *s, const uint8_t *p, uint64_t n) { s->total += n;
    while (n) { if (!s->fill && n >= 128) { rounds5(s->h, p); p += 128; n -= 128; continue; }
        s->buf[s->fill++] = *p++; n--; if (s->fill == 128) { rounds5(s->h, s->buf); s->fill = 0; } } }
static int64_t long_hash(block *out, const int16_t *p, int64_t n, void *const *table, const uint64_t *start, int bytes) {
    const block *src = bytes_at(table, p, n, 0, out); if (!src || out->size < 64 + (uint64_t)bytes) return -1;
    sha5 s; for (int i = 0; i < 8; i++) s.h[i] = start[i]; s.total = 0; s.fill = 0; add5(&s, src->bytes, src->size - 64);
    uint64_t bits = s.total * 8; uint8_t pad = 0x80; add5(&s, &pad, 1); pad = 0; while (s.fill != 112) add5(&s, &pad, 1);
    uint8_t len[16] = {0}; for (int i = 0; i < 8; i++) len[8 + i] = (uint8_t)(bits >> (56 - 8 * i)); add5(&s, len, 16);
    for (int i = 0; i < bytes; i++) out->bytes[i] = (uint8_t)(s.h[i / 8] >> (56 - 8 * (i % 8))); return bytes;
}
int64_t sha512(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    static const uint64_t start[8] = {0x6a09e667f3bcc908ull, 0xbb67ae8584caa73bull, 0x3c6ef372fe94f82bull, 0xa54ff53a5f1d36f1ull, 0x510e527fade682d1ull, 0x9b05688c2b3e6c1full, 0x1f83d9abfb41bd6bull, 0x5be0cd19137e2179ull};
    return long_hash(out, p, n, table, start, 64); }
int64_t sha384(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    static const uint64_t start[8] = {0xcbbb9d5dc1059ed8ull, 0x629a292a367cd507ull, 0x9159015a3070dd17ull, 0x152fecd8f70e5939ull, 0x67332667ffc00b31ull, 0x8eb44a8768581511ull, 0xdb0c2e0d64f98fa7ull, 0x47b5481dbefa4fa4ull};
    return long_hash(out, p, n, table, start, 48); }
