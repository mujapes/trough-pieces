/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef unsigned __int128 u128;
typedef struct { uint64_t v[5]; } fe;                                   /* a number modulo 2^255 - 19, as five 51-bit parts */
#define MASK 0x7ffffffffffffull
static uint64_t load64(const uint8_t *p) { uint64_t v = 0; for (int i = 7; i >= 0; i--) v = (v << 8) | p[i]; return v; }
static fe from_bytes(const uint8_t *s) { fe h; h.v[0] = load64(s) & MASK; h.v[1] = (load64(s + 6) >> 3) & MASK; h.v[2] = (load64(s + 12) >> 6) & MASK; h.v[3] = (load64(s + 19) >> 1) & MASK; h.v[4] = (load64(s + 24) >> 12) & MASK; return h; }
static fe add(fe a, fe b) { for (int i = 0; i < 5; i++) a.v[i] += b.v[i]; return a; }
static fe sub(fe a, fe b) { a.v[0] += 0xfffffffffffdaull - b.v[0]; for (int i = 1; i < 5; i++) a.v[i] += 0xffffffffffffeull - b.v[i]; return a; }   /* adds twice the modulus first, so nothing goes below zero */
static fe carry(u128 t0, u128 t1, u128 t2, u128 t3, u128 t4) { fe r;
    t1 += (uint64_t)(t0 >> 51); r.v[0] = (uint64_t)t0 & MASK; t2 += (uint64_t)(t1 >> 51); r.v[1] = (uint64_t)t1 & MASK; t3 += (uint64_t)(t2 >> 51); r.v[2] = (uint64_t)t2 & MASK;
    t4 += (uint64_t)(t3 >> 51); r.v[3] = (uint64_t)t3 & MASK; uint64_t c = (uint64_t)(t4 >> 51); r.v[4] = (uint64_t)t4 & MASK;
    r.v[0] += c * 19; r.v[1] += r.v[0] >> 51; r.v[0] &= MASK; return r; }
static fe mul(fe a, fe b) {
    u128 a0 = a.v[0], a1 = a.v[1], a2 = a.v[2], a3 = a.v[3], a4 = a.v[4]; uint64_t b0 = b.v[0], b1 = b.v[1], b2 = b.v[2], b3 = b.v[3], b4 = b.v[4], c1 = b1 * 19, c2 = b2 * 19, c3 = b3 * 19, c4 = b4 * 19;
    return carry(a0 * b0 + a1 * c4 + a2 * c3 + a3 * c2 + a4 * c1, a0 * b1 + a1 * b0 + a2 * c4 + a3 * c3 + a4 * c2, a0 * b2 + a1 * b1 + a2 * b0 + a3 * c4 + a4 * c3,
                 a0 * b3 + a1 * b2 + a2 * b1 + a3 * b0 + a4 * c4, a0 * b4 + a1 * b3 + a2 * b2 + a3 * b1 + a4 * b0); }
static fe times(fe a, uint64_t k) { return carry((u128)a.v[0] * k, (u128)a.v[1] * k, (u128)a.v[2] * k, (u128)a.v[3] * k, (u128)a.v[4] * k); }
static void swap_if(fe *a, fe *b, uint64_t yes) { uint64_t m = 0 - yes; for (int i = 0; i < 5; i++) { uint64_t t = (a->v[i] ^ b->v[i]) & m; a->v[i] ^= t; b->v[i] ^= t; } }
static void to_bytes(fe h, uint8_t *out) {
    for (int pass = 0; pass < 2; pass++) { for (int i = 0; i < 4; i++) { h.v[i + 1] += h.v[i] >> 51; h.v[i] &= MASK; } h.v[0] += 19 * (h.v[4] >> 51); h.v[4] &= MASK; }
    uint64_t q = (h.v[0] + 19) >> 51; for (int i = 1; i < 5; i++) q = (h.v[i] + q) >> 51;      /* 1 exactly when h is at or above the modulus */
    h.v[0] += 19 * q; for (int i = 0; i < 4; i++) { h.v[i + 1] += h.v[i] >> 51; h.v[i] &= MASK; } h.v[4] &= MASK;
    uint64_t w[4] = { h.v[0] | (h.v[1] << 51), (h.v[1] >> 13) | (h.v[2] << 38), (h.v[2] >> 26) | (h.v[3] << 25), (h.v[3] >> 39) | (h.v[4] << 12) };
    for (int i = 0; i < 4; i++) for (int k = 0; k < 8; k++) out[8 * i + k] = (uint8_t)(w[i] >> (8 * k));
}
/* The ladder of RFC 7748: 255 identical steps. */
static void x25519(const uint8_t *secret, const uint8_t *point, uint8_t *out) {
    uint8_t k[32]; for (int i = 0; i < 32; i++) k[i] = secret[i]; k[0] &= 248; k[31] &= 127; k[31] |= 64;
    fe x1 = from_bytes(point), x2 = {{1, 0, 0, 0, 0}}, z2 = {{0, 0, 0, 0, 0}}, x3 = x1, z3 = {{1, 0, 0, 0, 0}}; uint64_t swap = 0;
    for (int t = 254; t >= 0; t--) { uint64_t bit = (k[t >> 3] >> (t & 7)) & 1; swap ^= bit; swap_if(&x2, &x3, swap); swap_if(&z2, &z3, swap); swap = bit;
        fe A = add(x2, z2), AA = mul(A, A), B = sub(x2, z2), BB = mul(B, B), E = sub(AA, BB), C = add(x3, z3), D = sub(x3, z3), DA = mul(D, A), CB = mul(C, B), S = add(DA, CB), F = sub(DA, CB);
        x3 = mul(S, S); z3 = mul(x1, mul(F, F)); x2 = mul(AA, BB); z2 = mul(E, add(AA, times(E, 121665))); }
    swap_if(&x2, &x3, swap); swap_if(&z2, &z3, swap);
    fe inv = {{1, 0, 0, 0, 0}};                                          /* z2 to the power 2^255 - 21, which is 1 / z2 */
    for (int t = 254; t >= 0; t--) { inv = mul(inv, inv); if (t >= 8 || ((0xeb >> t) & 1)) inv = mul(inv, z2); }
    to_bytes(mul(x2, inv), out);
}
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which, const block *out) {
    const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size == 64 + 32 && b != out ? b : 0; }
int64_t public(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *secret = bytes_at(table, p, n, 0, out); if (!secret || out->size < 96) return -1;
    uint8_t nine[32] = {9}, r[32]; x25519(secret->bytes, nine, r); for (int i = 0; i < 32; i++) out->bytes[i] = r[i]; return 32;
}
int64_t shared(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *secret = bytes_at(table, p, n, 0, out), *theirs = bytes_at(table, p, n, 1, out); if (!secret || !theirs || out->size < 96) return -1;
    uint8_t r[32]; x25519(secret->bytes, theirs->bytes, r); uint32_t any = 0; for (int i = 0; i < 32; i++) any |= r[i]; if (!any) return -1;
    for (int i = 0; i < 32; i++) out->bytes[i] = r[i]; return 32;
}
