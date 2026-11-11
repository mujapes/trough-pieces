/* The arithmetic of ecdsa/reference.c with the number of 64-bit limbs fixed at K, so the loops unroll, and with the final sum taken
 * two bits at a time. Included once for each curve. Edited by hand since it was first written out of reference.c. */
#define field N(field)
#define num N(num)
#define point N(point)
#define ge N(ge)
#define zero N(zero)
#define take N(take)
#define mul N(mul)
#define add N(add)
#define sub N(sub)
#define load N(load)
#define setup N(setup)
#define enter N(enter)
#define leave N(leave)
#define inverse N(inverse)
#define twice N(twice)
#define plus N(plus)
#define verify_one N(verify_one)
typedef struct { uint64_t n[K], r2[K], one[K], inv; int k; } field;   /* arithmetic modulo n, in Montgomery's form */
typedef struct { uint64_t v[K]; } num;
static int ge(const uint64_t *a, const uint64_t *b, int k) { for (int i = k - 1; i >= 0; i--) if (a[i] != b[i]) return a[i] > b[i]; return 1; }
static int zero(const uint64_t *a, int k) { uint64_t any = 0; for (int i = 0; i < k; i++) any |= a[i]; return !any; }
static uint64_t take(uint64_t *a, const uint64_t *b, int k) { uint64_t borrow = 0; for (int i = 0; i < k; i++) { u128 d = (u128)a[i] - b[i] - borrow; a[i] = (uint64_t)d; borrow = (uint64_t)(d >> 64) & 1; } return borrow; }
static num mul(const field *m, num a, num b) { num r; MONT(r.v, a.v, b.v, m->n, m->inv); return r; }   /* hand-written multiplication: ecdsa/mont_asm.h */
static num add(const field *m, num a, num b) { uint64_t carry = 0; for (int i = 0; i < K; i++) { u128 s = (u128)a.v[i] + b.v[i] + carry; a.v[i] = (uint64_t)s; carry = (uint64_t)(s >> 64); } if (carry || ge(a.v, m->n, K)) take(a.v, m->n, K); return a; }
static num sub(const field *m, num a, num b) { if (take(a.v, b.v, K)) { uint64_t carry = 0; for (int i = 0; i < K; i++) { u128 s = (u128)a.v[i] + m->n[i] + carry; a.v[i] = (uint64_t)s; carry = (uint64_t)(s >> 64); } } return a; }
static num load(const uint8_t *d, uint64_t n, int k, int *fits) { num r; for (int i = 0; i < K; i++) r.v[i] = 0;
    for (uint64_t i = 0; i < n; i++) { uint64_t place = n - 1 - i; if (place / 8 >= (uint64_t)k) { if (d[i]) *fits = 0; continue; } r.v[place / 8] |= (uint64_t)d[i] << (8 * (place % 8)); } return r; }
static void setup(field *m, const uint8_t *modulus, int bytes) { int fits = 1;  num n = load(modulus, (uint64_t)bytes, K, &fits); for (int i = 0; i < K; i++) m->n[i] = n.v[i];
    uint64_t inv = 1; for (int i = 0; i < 6; i++) inv *= 2 - m->n[0] * inv; m->inv = 0 - inv; uint64_t r[K] = {1};
    for (int i = 0; i < 128 * K; i++) { uint64_t top = r[K - 1] >> 63; for (int j = K - 1; j > 0; j--) r[j] = (r[j] << 1) | (r[j - 1] >> 63); r[0] <<= 1; if (top || ge(r, m->n, K)) take(r, m->n, K);
        if (i == 64 * K - 1) for (int j = 0; j < K; j++) m->one[j] = j < K ? r[j] : 0; }
    for (int j = 0; j < K; j++) m->r2[j] = j < K ? r[j] : 0; }
static num enter(const field *m, num a) { num r2; for (int i = 0; i < K; i++) r2.v[i] = m->r2[i]; return mul(m, a, r2); }
static num leave(const field *m, num a) { num one = {{1}}; return mul(m, a, one); }
static num inverse(const field *m, num a) {                              /* a to the power n - 2 (n is prime) */
    uint64_t e[K]; for (int i = 0; i < K; i++) e[i] = m->n[i]; uint64_t two[K] = {2}; take(e, two, K);
    num r; for (int i = 0; i < K; i++) r.v[i] = m->one[i]; for (int i = 64 * K - 1; i >= 0; i--) { r = mul(m, r, r); if ((e[i / 64] >> (i % 64)) & 1) r = mul(m, r, a); } return r; }
typedef struct { num x, y, z; int nowhere; } point;                     /* x/z^2, y/z^3; "nowhere" is the point at infinity */
static point twice(const field *f, point p) { if (p.nowhere || zero(p.y.v, K)) { p.nowhere = 1; return p; }
    num delta = mul(f, p.z, p.z), gamma = mul(f, p.y, p.y), beta = mul(f, p.x, gamma), t = mul(f, sub(f, p.x, delta), add(f, p.x, delta)), alpha = add(f, add(f, t, t), t), b4 = add(f, beta, beta); b4 = add(f, b4, b4);
    point r; r.nowhere = 0; r.x = sub(f, mul(f, alpha, alpha), add(f, b4, b4)); num yz = add(f, p.y, p.z); r.z = sub(f, sub(f, mul(f, yz, yz), gamma), delta);
    num g2 = mul(f, gamma, gamma), g8 = add(f, g2, g2); g8 = add(f, g8, g8); g8 = add(f, g8, g8); r.y = sub(f, mul(f, alpha, sub(f, b4, r.x)), g8); return r; }
static point plus(const field *f, point p, point q) { if (p.nowhere) return q; if (q.nowhere) return p;
    num z1 = mul(f, p.z, p.z), z2 = mul(f, q.z, q.z), u1 = mul(f, p.x, z2), u2 = mul(f, q.x, z1), s1 = mul(f, mul(f, p.y, q.z), z2), s2 = mul(f, mul(f, q.y, p.z), z1), h = sub(f, u2, u1), r = sub(f, s2, s1);
    if (zero(h.v, K)) { if (zero(r.v, K)) return twice(f, p); p.nowhere = 1; return p; }
    num hh = mul(f, h, h), hhh = mul(f, h, hh), v = mul(f, u1, hh); point o; o.nowhere = 0; o.x = sub(f, sub(f, mul(f, r, r), hhh), add(f, v, v)); o.y = sub(f, mul(f, r, sub(f, v, o.x)), mul(f, s1, hhh)); o.z = mul(f, mul(f, p.z, q.z), h); return o; }
static int64_t verify_one(int curve, int bytes, const block *bx, const block *by, const block *br, const block *bs, const block *bd) {
    field fp, fn; setup(&fp, curve == 256 ? P256_p : P384_p, bytes); setup(&fn, curve == 256 ? P256_n : P384_n, bytes); int k = K, fits = 1;
    num x = load(bx->bytes, bx->size - 64, k, &fits), y = load(by->bytes, by->size - 64, k, &fits), r = load(br->bytes, br->size - 64, k, &fits), s = load(bs->bytes, bs->size - 64, k, &fits);
    if (!fits || ge(x.v, fp.n, k) || ge(y.v, fp.n, k)) return -1;
    if (zero(r.v, k) || zero(s.v, k) || ge(r.v, fn.n, k) || ge(s.v, fn.n, k)) return 0;                                 /* r and s must each be from 1 to n - 1 */
    int ok = 1; num b = enter(&fp, load(curve == 256 ? P256_b : P384_b, (uint64_t)bytes, k, &ok)), gx = enter(&fp, load(curve == 256 ? P256_gx : P384_gx, (uint64_t)bytes, k, &ok)), gy = enter(&fp, load(curve == 256 ? P256_gy : P384_gy, (uint64_t)bytes, k, &ok));
    num mx = enter(&fp, x), my = enter(&fp, y), three; for (int i = 0; i < K; i++) three.v[i] = fp.one[i]; three = add(&fp, add(&fp, three, three), three);
    num left = mul(&fp, my, my), right = add(&fp, sub(&fp, mul(&fp, mul(&fp, mx, mx), mx), mul(&fp, three, mx)), b); for (int i = 0; i < k; i++) if (left.v[i] != right.v[i]) return -1;   /* the key is not a point on the curve */
    uint64_t dn = bd->size - 64; if (dn > (uint64_t)bytes) dn = (uint64_t)bytes; num z = load(bd->bytes, dn, k, &ok); if (ge(z.v, fn.n, k)) take(z.v, fn.n, k);                                 /* the digest's leftmost bytes, as a number */
    num w = inverse(&fn, enter(&fn, s)), u1 = leave(&fn, mul(&fn, enter(&fn, z), w)), u2 = leave(&fn, mul(&fn, enter(&fn, r), w));
    point G, Q, both, R; G.x = gx; G.y = gy; G.nowhere = 0; Q.x = mx; Q.y = my; Q.nowhere = 0; for (int i = 0; i < K; i++) G.z.v[i] = Q.z.v[i] = fp.one[i]; both = plus(&fp, G, Q); R.nowhere = 1; R.x = R.y = R.z = G.z;
    /* Two bits of each number per step (this is where fast.c departs from reference.c's one bit): a table of iG + jQ for i, j from 0
     * to 3, then two doublings and at most one addition for every pair of bits. Same sum, about a third fewer additions. */
    point T[4][4]; T[0][0] = R; T[1][0] = G; T[2][0] = twice(&fp, G); T[3][0] = plus(&fp, T[2][0], G); T[0][1] = Q; T[0][2] = twice(&fp, Q); T[0][3] = plus(&fp, T[0][2], Q);
    for (int a = 1; a < 4; a++) for (int b = 1; b < 4; b++) T[a][b] = plus(&fp, T[a][0], T[0][b]);
    for (int i = 64 * k - 2; i >= 0; i -= 2) { R = twice(&fp, twice(&fp, R)); int g = (int)((u1.v[i / 64] >> (i % 64)) & 3), q = (int)((u2.v[i / 64] >> (i % 64)) & 3); if (g || q) R = plus(&fp, R, T[g][q]); }
    if (R.nowhere) return 0;
    num zi = inverse(&fp, R.z), ax = leave(&fp, mul(&fp, R.x, mul(&fp, zi, zi))); if (ge(ax.v, fn.n, k)) take(ax.v, fn.n, k);
    for (int i = 0; i < k; i++) if (ax.v[i] != r.v[i]) return 0; return 1;
}
#undef field
#undef num
#undef point
#undef ge
#undef zero
#undef take
#undef mul
#undef add
#undef sub
#undef load
#undef setup
#undef enter
#undef leave
#undef inverse
#undef twice
#undef plus
#undef verify_one
