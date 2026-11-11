/* reference.c with a quicker way to the one constant the arithmetic needs. Everything else is the same text. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef unsigned __int128 u128;
#define LIMBS 64                                                         /* up to 4096 bits */
typedef struct { uint64_t n[LIMBS], r2[LIMBS], inv; int k; } modulus;
static int ge(const uint64_t *a, const uint64_t *b, int k) { for (int i = k - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] > b[i]; return 1; }
static void take(uint64_t *a, const uint64_t *b, int k) { uint64_t borrow = 0; for (int i = 0; i < k; i++) { u128 d = (u128)a[i] - b[i] - borrow; a[i] = (uint64_t)d; borrow = (uint64_t)(d >> 64) & 1; } }
/* a × b / 2^(64k) modulo n (Montgomery's product): the form in which repeated multiplication needs no division. */
static void product(const modulus *m, const uint64_t *a, const uint64_t *b, uint64_t *out) {
    uint64_t t[LIMBS + 2]; int k = m->k; for (int i = 0; i < k + 2; i++) t[i] = 0;
    for (int i = 0; i < k; i++) { u128 c = 0; for (int j = 0; j < k; j++) { c += (u128)a[j] * b[i] + t[j]; t[j] = (uint64_t)c; c >>= 64; } c += t[k]; t[k] = (uint64_t)c; t[k + 1] = (uint64_t)(c >> 64);
        uint64_t q = t[0] * m->inv; c = (u128)q * m->n[0] + t[0]; c >>= 64; for (int j = 1; j < k; j++) { c += (u128)q * m->n[j] + t[j]; t[j - 1] = (uint64_t)c; c >>= 64; }
        c += t[k]; t[k - 1] = (uint64_t)c; t[k] = t[k + 1] + (uint64_t)(c >> 64); }
    if (t[k] || ge(t, m->n, k)) take(t, m->n, k); for (int i = 0; i < k; i++) out[i] = t[i];
}
static int load(uint64_t *out, const block *b, int k) {                  /* big-endian bytes into k limbs; 0 if it does not fit */
    uint64_t n = b->size - 64; for (int i = 0; i < k; i++) out[i] = 0;
    for (uint64_t i = 0; i < n; i++) { uint64_t place = n - 1 - i; uint8_t v = b->bytes[i]; if (place / 8 >= (uint64_t)k) { if (v) return 0; continue; } out[place / 8] |= (uint64_t)v << (8 * (place % 8)); }
    return 1;
}
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which) { const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size > 64 ? b : 0; }
/* signature ^ exponent modulo the key's modulus, as bytes the length of the modulus. Returns that length, or 0 if the inputs are not a usable key and signature. */
static int recover(void *const *table, const int16_t *p, int64_t count, uint8_t *em, int *bits) {
    const block *nb = bytes_at(table, p, count, 0), *eb = bytes_at(table, p, count, 1), *sb = bytes_at(table, p, count, 2); if (!nb || !eb || !sb) return 0;
    uint64_t nn = nb->size - 64, skip = 0; while (skip < nn && !nb->bytes[skip]) skip++; nn -= skip; if (nn < 128 || nn > 512 || sb->size - 64 != nn || eb->size - 64 > 4) return 0;      /* 1024 to 4096 bits */
    modulus m; m.k = (int)((nn + 7) / 8); if (!load(m.n, nb, m.k) || !(m.n[0] & 1)) return 0;
    uint64_t s[LIMBS], e = 0; if (!load(s, sb, m.k) || ge(s, m.n, m.k)) return 0; for (uint64_t i = 0; i < eb->size - 64; i++) e = (e << 8) | eb->bytes[i]; if (e < 3 || !(e & 1)) return 0;
    uint64_t inv = 1; for (int i = 0; i < 6; i++) inv *= 2 - m.n[0] * inv; m.inv = 0 - inv;                         /* -1 / n modulo 2^64 */
    /* 2^(128k) modulo n without thousands of doublings: 2^(64k) mod n is found by a few doublings from the highest power of two
     * below n; then, in Montgomery's form, 2 is raised to the power 64k by squaring (a dozen products). */
    { uint64_t r[LIMBS]; int bits = 64 * m.k; while (!((m.n[(bits - 1) / 64] >> ((bits - 1) % 64)) & 1)) bits--; for (int i = 0; i < m.k; i++) r[i] = 0; r[(bits - 1) / 64] = 1ull << ((bits - 1) % 64);
#define TWICE(x) { uint64_t top = x[m.k - 1] >> 63; for (int j = m.k - 1; j > 0; j--) x[j] = (x[j] << 1) | (x[j - 1] >> 63); x[0] <<= 1; if (top || ge(x, m.n, m.k)) take(x, m.n, m.k); }
      for (int i = bits - 1; i < 64 * m.k; i++) TWICE(r)                                                              /* r = 2^(64k) mod n: "one" in Montgomery's form */
      TWICE(r) int e2 = 64 * m.k, top = 30; while (!((e2 >> top) & 1)) top--;                                          /* r = "two" */
      for (int i = top - 1; i >= 0; i--) { product(&m, r, r, r); if ((e2 >> i) & 1) TWICE(r) }
      for (int i = 0; i < m.k; i++) m.r2[i] = r[i]; }
    uint64_t base[LIMBS], acc[LIMBS], one[LIMBS]; product(&m, s, m.r2, base); for (int i = 0; i < m.k; i++) { acc[i] = base[i]; one[i] = 0; } one[0] = 1;
    int top = 63; while (!((e >> top) & 1)) top--; for (int i = top - 1; i >= 0; i--) { product(&m, acc, acc, acc); if ((e >> i) & 1) product(&m, acc, base, acc); }
    product(&m, acc, one, acc);
    for (uint64_t i = 0; i < nn; i++) { uint64_t place = nn - 1 - i; em[i] = (uint8_t)(acc[place / 8] >> (8 * (place % 8))); }
    int b = (int)nn * 8; uint8_t first = nb->bytes[skip]; while (!(first & 0x80)) { first = (uint8_t)(first << 1); b--; } *bits = b; return (int)nn;
}
/* PKCS #1 v1.5: the recovered bytes must be exactly 00 01 FF...FF 00, the hash's label, the digest. */
int64_t verify_pkcs1(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    const block *digest = bytes_at(table, p, n, 3); if (!digest) return -1; uint64_t dn = digest->size - 64; if (dn != 32 && dn != 48 && dn != 64) return -1;
    uint8_t em[512]; int bits, len = recover(table, p, n, em, &bits); if (!len) return -1;
    static const uint8_t label[19] = {0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20};   /* "SHA-256, 32 bytes"; the others differ in three places */
    if ((uint64_t)len < 3 + 8 + 19 + dn) return 0; uint32_t differ = em[0] | (em[1] ^ 1); int pad = len - 3 - 19 - (int)dn;
    for (int i = 0; i < pad; i++) differ |= em[2 + i] ^ 0xff; differ |= em[2 + pad];
    for (int i = 0; i < 19; i++) { uint8_t want = label[i]; if (i == 1) want = (uint8_t)(0x11 + dn); if (i == 14) want = dn == 32 ? 1 : dn == 48 ? 2 : 3; if (i == 18) want = (uint8_t)dn; differ |= em[3 + pad + i] ^ want; }
    for (uint64_t i = 0; i < dn; i++) differ |= em[3 + pad + 19 + i] ^ digest->bytes[i];
    return differ ? 0 : 1;
}
static int sha256_of(void *const *table, const uint8_t *d, uint64_t n, uint8_t *out) { struct { uint8_t head[64]; uint8_t b[128]; } in, o; void *mine[512];
    for (int i = 0; i < 64; i++) in.head[i] = o.head[i] = 0; in.head[0] = o.head[0] = 2; in.head[16] = (uint8_t)(64 + n); o.head[16] = 192; for (uint64_t i = 0; i < n; i++) in.b[i] = d[i];
    mine[257] = &in; int16_t q[1] = {1}; if (((trough_block)table[SLOT_HASH_SHA256])(&o, q, 1, 0, (void *const *)mine) != 32) return 0; for (int i = 0; i < 32; i++) out[i] = o.b[i]; return 1; }
/* PSS with SHA-256 and a 32-byte salt, the form TLS 1.3 uses for a server's own signature (RFC 8017 section 9.1.2). */
int64_t verify_pss(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    const block *digest = bytes_at(table, p, n, 3); if (!digest || digest->size != 64 + 32) return -1;
    uint8_t em[512], *e = em; int bits, len = recover(table, p, n, em, &bits); if (!len) return -1;
    int embits = bits - 1, emlen = (embits + 7) / 8; if (emlen < len) { if (e[0]) return 0; e++; } if (emlen < 32 + 32 + 2 || e[emlen - 1] != 0xbc) return 0;
    int dblen = emlen - 33; const uint8_t *h = e + dblen; uint8_t db[512], buf[72], mask[32];
    for (int at = 0, counter = 0; at < dblen; counter++) { for (int i = 0; i < 32; i++) buf[i] = h[i]; buf[32] = 0; buf[33] = 0; buf[34] = (uint8_t)(counter >> 8); buf[35] = (uint8_t)counter; if (!sha256_of(table, buf, 36, mask)) return -1;
        for (int i = 0; i < 32 && at < dblen; i++, at++) db[at] = e[at] ^ mask[i]; }
    int spare = 8 * emlen - embits; if (e[0] >> (8 - spare) && spare) return 0; db[0] &= (uint8_t)(0xff >> spare);
    uint32_t differ = 0; for (int i = 0; i < dblen - 33; i++) differ |= db[i]; differ |= db[dblen - 33] ^ 1;
    for (int i = 0; i < 8; i++) buf[i] = 0; for (int i = 0; i < 32; i++) { buf[8 + i] = digest->bytes[i]; buf[40 + i] = db[dblen - 32 + i]; } if (!sha256_of(table, buf, 72, mask)) return -1;
    for (int i = 0; i < 32; i++) differ |= mask[i] ^ h[i];
    return differ ? 0 : 1;
}
