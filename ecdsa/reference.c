/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
#include "curves.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef unsigned __int128 u128;
#define LIMBS 6                                                          /* up to 384 bits */
typedef struct { uint64_t n[LIMBS], r2[LIMBS], one[LIMBS], inv; int k; } field;   /* arithmetic modulo n, in Montgomery's form */
typedef struct { uint64_t v[LIMBS]; } num;
static int ge(const uint64_t *a, const uint64_t *b, int k) { for (int i = k - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] > b[i]; return 1; }
static int zero(const uint64_t *a, int k) { uint64_t any = 0; for (int i = 0; i < k; i++) any |= a[i]; return !any; }
static uint64_t take(uint64_t *a, const uint64_t *b, int k) { uint64_t borrow = 0; for (int i = 0; i < k; i++) { u128 d = (u128)a[i] - b[i] - borrow; a[i] = (uint64_t)d; borrow = (uint64_t)(d >> 64) & 1; } return borrow; }
static num mul(const field *m, num a, num b) { uint64_t t[LIMBS + 2]; int k = m->k; for (int i = 0; i < k + 2; i++) t[i] = 0;
    for (int i = 0; i < k; i++) { u128 c = 0; for (int j = 0; j < k; j++) { c += (u128)a.v[j] * b.v[i] + t[j]; t[j] = (uint64_t)c; c >>= 64; } c += t[k]; t[k] = (uint64_t)c; t[k + 1] = (uint64_t)(c >> 64);
        uint64_t q = t[0] * m->inv; c = (u128)q * m->n[0] + t[0]; c >>= 64; for (int j = 1; j < k; j++) { c += (u128)q * m->n[j] + t[j]; t[j - 1] = (uint64_t)c; c >>= 64; }
        c += t[k]; t[k - 1] = (uint64_t)c; t[k] = t[k + 1] + (uint64_t)(c >> 64); }
    if (t[k] || ge(t, m->n, k)) take(t, m->n, k); num r; for (int i = 0; i < LIMBS; i++) r.v[i] = i < k ? t[i] : 0; return r; }
static num add(const field *m, num a, num b) { uint64_t carry = 0; for (int i = 0; i < m->k; i++) { u128 s = (u128)a.v[i] + b.v[i] + carry; a.v[i] = (uint64_t)s; carry = (uint64_t)(s >> 64); } if (carry || ge(a.v, m->n, m->k)) take(a.v, m->n, m->k); return a; }
static num sub(const field *m, num a, num b) { if (take(a.v, b.v, m->k)) { uint64_t carry = 0; for (int i = 0; i < m->k; i++) { u128 s = (u128)a.v[i] + m->n[i] + carry; a.v[i] = (uint64_t)s; carry = (uint64_t)(s >> 64); } } return a; }
static num load(const uint8_t *d, uint64_t n, int k, int *fits) { num r; for (int i = 0; i < LIMBS; i++) r.v[i] = 0;
    for (uint64_t i = 0; i < n; i++) { uint64_t place = n - 1 - i; if (place / 8 >= (uint64_t)k) { if (d[i]) *fits = 0; continue; } r.v[place / 8] |= (uint64_t)d[i] << (8 * (place % 8)); } return r; }
static void setup(field *m, const uint8_t *modulus, int bytes) { int fits = 1; m->k = bytes / 8; num n = load(modulus, (uint64_t)bytes, m->k, &fits); for (int i = 0; i < LIMBS; i++) m->n[i] = n.v[i];
    uint64_t inv = 1; for (int i = 0; i < 6; i++) inv *= 2 - m->n[0] * inv; m->inv = 0 - inv; uint64_t r[LIMBS] = {1};
    for (int i = 0; i < 128 * m->k; i++) { uint64_t top = r[m->k - 1] >> 63; for (int j = m->k - 1; j > 0; j--) r[j] = (r[j] << 1) | (r[j - 1] >> 63); r[0] <<= 1; if (top || ge(r, m->n, m->k)) take(r, m->n, m->k);
        if (i == 64 * m->k - 1) for (int j = 0; j < LIMBS; j++) m->one[j] = j < m->k ? r[j] : 0; }
    for (int j = 0; j < LIMBS; j++) m->r2[j] = j < m->k ? r[j] : 0; }
static num enter(const field *m, num a) { num r2; for (int i = 0; i < LIMBS; i++) r2.v[i] = m->r2[i]; return mul(m, a, r2); }
static num leave(const field *m, num a) { num one = {{1}}; return mul(m, a, one); }
static num inverse(const field *m, num a) {                              /* a to the power n - 2 (n is prime) */
    uint64_t e[LIMBS]; for (int i = 0; i < LIMBS; i++) e[i] = m->n[i]; uint64_t two[LIMBS] = {2}; take(e, two, m->k);
    num r; for (int i = 0; i < LIMBS; i++) r.v[i] = m->one[i]; for (int i = 64 * m->k - 1; i >= 0; i--) { r = mul(m, r, r); if ((e[i / 64] >> (i % 64)) & 1) r = mul(m, r, a); } return r; }
typedef struct { num x, y, z; int nowhere; } point;                     /* x/z^2, y/z^3; "nowhere" is the point at infinity */
static point twice(const field *f, point p) { if (p.nowhere || zero(p.y.v, f->k)) { p.nowhere = 1; return p; }
    num delta = mul(f, p.z, p.z), gamma = mul(f, p.y, p.y), beta = mul(f, p.x, gamma), t = mul(f, sub(f, p.x, delta), add(f, p.x, delta)), alpha = add(f, add(f, t, t), t), b4 = add(f, beta, beta); b4 = add(f, b4, b4);
    point r; r.nowhere = 0; r.x = sub(f, mul(f, alpha, alpha), add(f, b4, b4)); num yz = add(f, p.y, p.z); r.z = sub(f, sub(f, mul(f, yz, yz), gamma), delta);
    num g2 = mul(f, gamma, gamma), g8 = add(f, g2, g2); g8 = add(f, g8, g8); g8 = add(f, g8, g8); r.y = sub(f, mul(f, alpha, sub(f, b4, r.x)), g8); return r; }
static point plus(const field *f, point p, point q) { if (p.nowhere) return q; if (q.nowhere) return p;
    num z1 = mul(f, p.z, p.z), z2 = mul(f, q.z, q.z), u1 = mul(f, p.x, z2), u2 = mul(f, q.x, z1), s1 = mul(f, mul(f, p.y, q.z), z2), s2 = mul(f, mul(f, q.y, p.z), z1), h = sub(f, u2, u1), r = sub(f, s2, s1);
    if (zero(h.v, f->k)) { if (zero(r.v, f->k)) return twice(f, p); p.nowhere = 1; return p; }
    num hh = mul(f, h, h), hhh = mul(f, h, hh), v = mul(f, u1, hh); point o; o.nowhere = 0; o.x = sub(f, sub(f, mul(f, r, r), hhh), add(f, v, v)); o.y = sub(f, mul(f, r, sub(f, v, o.x)), mul(f, s1, hhh)); o.z = mul(f, mul(f, p.z, q.z), h); return o; }
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which) { const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size > 64 && b->size <= 64 + 80 ? b : 0; }
int64_t verify(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    int curve = n > 0 ? p[0] : 0; if (curve != 256 && curve != 384) return -1; int bytes = curve / 8;
    const block *bx = bytes_at(table, p, n, 1), *by = bytes_at(table, p, n, 2), *br = bytes_at(table, p, n, 3), *bs = bytes_at(table, p, n, 4), *bd = bytes_at(table, p, n, 5); if (!bx || !by || !br || !bs || !bd) return -1;
    field fp, fn; setup(&fp, curve == 256 ? P256_p : P384_p, bytes); setup(&fn, curve == 256 ? P256_n : P384_n, bytes); int k = fp.k, fits = 1;
    num x = load(bx->bytes, bx->size - 64, k, &fits), y = load(by->bytes, by->size - 64, k, &fits), r = load(br->bytes, br->size - 64, k, &fits), s = load(bs->bytes, bs->size - 64, k, &fits);
    if (!fits || ge(x.v, fp.n, k) || ge(y.v, fp.n, k)) return -1;
    if (zero(r.v, k) || zero(s.v, k) || ge(r.v, fn.n, k) || ge(s.v, fn.n, k)) return 0;                                 /* r and s must each be from 1 to n - 1 */
    int ok = 1; num b = enter(&fp, load(curve == 256 ? P256_b : P384_b, (uint64_t)bytes, k, &ok)), gx = enter(&fp, load(curve == 256 ? P256_gx : P384_gx, (uint64_t)bytes, k, &ok)), gy = enter(&fp, load(curve == 256 ? P256_gy : P384_gy, (uint64_t)bytes, k, &ok));
    num mx = enter(&fp, x), my = enter(&fp, y), three; for (int i = 0; i < LIMBS; i++) three.v[i] = fp.one[i]; three = add(&fp, add(&fp, three, three), three);
    num left = mul(&fp, my, my), right = add(&fp, sub(&fp, mul(&fp, mul(&fp, mx, mx), mx), mul(&fp, three, mx)), b); for (int i = 0; i < k; i++) if (left.v[i] != right.v[i]) return -1;   /* the key is not a point on the curve */
    uint64_t dn = bd->size - 64; if (dn > (uint64_t)bytes) dn = (uint64_t)bytes; num z = load(bd->bytes, dn, k, &ok); if (ge(z.v, fn.n, k)) take(z.v, fn.n, k);                                 /* the digest's leftmost bytes, as a number */
    num w = inverse(&fn, enter(&fn, s)), u1 = leave(&fn, mul(&fn, enter(&fn, z), w)), u2 = leave(&fn, mul(&fn, enter(&fn, r), w));
    point G, Q, both, R; G.x = gx; G.y = gy; G.nowhere = 0; Q.x = mx; Q.y = my; Q.nowhere = 0; for (int i = 0; i < LIMBS; i++) G.z.v[i] = Q.z.v[i] = fp.one[i]; both = plus(&fp, G, Q); R.nowhere = 1; R.x = R.y = R.z = G.z;
    for (int i = 64 * k - 1; i >= 0; i--) { R = twice(&fp, R); int g = (int)((u1.v[i / 64] >> (i % 64)) & 1), q = (int)((u2.v[i / 64] >> (i % 64)) & 1); if (g && q) R = plus(&fp, R, both); else if (g) R = plus(&fp, R, G); else if (q) R = plus(&fp, R, Q); }
    if (R.nowhere) return 0;
    num zi = inverse(&fp, R.z), ax = leave(&fp, mul(&fp, R.x, mul(&fp, zi, zi))); if (ge(ax.v, fn.n, k)) take(ax.v, fn.n, k);
    for (int i = 0; i < k; i++) if (ax.v[i] != r.v[i]) return 0; return 1;
}
