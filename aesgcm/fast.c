/* reference.c with the cipher and the field multiplication done by the processor's instructions. The live implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
/* AES and the GCM multiplication with the processor's own instructions (ARMv8 "aes" and "pmull", present on every core of this
 * phone): no table is indexed by a secret byte anywhere, so time does not depend on keys or data. */
#pragma GCC target("+aes")
#include <arm_neon.h>
typedef struct { uint8x16_t round[15]; int rounds; } aes;
static uint32_t sub_word(uint32_t w) { return vgetq_lane_u32(vreinterpretq_u32_u8(vaeseq_u8(vreinterpretq_u8_u32(vdupq_n_u32(w)), vdupq_n_u8(0))), 0); }   /* the substitution, by the instruction itself */
static void aes_key(aes *a, const uint8_t *key, int bytes) {
    int nk = bytes / 4; a->rounds = nk + 6; uint32_t w[60], rcon = 1;                                                    /* words held little-endian, as the bytes lie */
    for (int i = 0; i < nk; i++) w[i] = (uint32_t)key[4 * i] | ((uint32_t)key[4 * i + 1] << 8) | ((uint32_t)key[4 * i + 2] << 16) | ((uint32_t)key[4 * i + 3] << 24);
    for (int i = nk; i < 4 * (a->rounds + 1); i++) { uint32_t t = w[i - 1];
        if (i % nk == 0) { t = sub_word((t >> 8) | (t << 24)) ^ rcon; rcon = (rcon << 1) ^ ((rcon >> 7) * 0x11b); }
        else if (nk > 6 && i % nk == 4) t = sub_word(t);
        w[i] = w[i - nk] ^ t; }
    for (int r = 0; r <= a->rounds; r++) a->round[r] = vreinterpretq_u8_u32(vld1q_u32(w + 4 * r));
}
static void aes_block(const aes *a, const uint8_t *in, uint8_t *out) {
    uint8x16_t s = vld1q_u8(in); for (int r = 0; r < a->rounds - 1; r++) s = vaesmcq_u8(vaeseq_u8(s, a->round[r]));
    vst1q_u8(out, veorq_u8(vaeseq_u8(s, a->round[a->rounds - 1]), a->round[a->rounds]));
}
/* y = (y xor block) times H. Bits are turned round within each byte so the field's lowest power sits in the lowest bit; then it is
 * a carry-less 128 by 128 multiplication and a fold of the upper half back by x^128 = x^7 + x^2 + x + 1. */
static void ghash_block(uint8_t *y, const uint8_t *h, const uint8_t *x, uint64_t n) {
    uint8_t padded[16]; for (int i = 0; i < 16; i++) padded[i] = (uint8_t)(y[i] ^ ((uint64_t)i < n ? x[i] : 0));
    uint64x2_t a = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(padded))), b = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(h)));
    poly64_t a0 = (poly64_t)vgetq_lane_u64(a, 0), a1 = (poly64_t)vgetq_lane_u64(a, 1), b0 = (poly64_t)vgetq_lane_u64(b, 0), b1 = (poly64_t)vgetq_lane_u64(b, 1);
    uint64x2_t lo = vreinterpretq_u64_p128(vmull_p64(a0, b0)), hi = vreinterpretq_u64_p128(vmull_p64(a1, b1)), mid = veorq_u64(vreinterpretq_u64_p128(vmull_p64(a0, b1)), vreinterpretq_u64_p128(vmull_p64(a1, b0)));
    uint64_t r0 = vgetq_lane_u64(lo, 0), r1 = vgetq_lane_u64(lo, 1) ^ vgetq_lane_u64(mid, 0), r2 = vgetq_lane_u64(hi, 0) ^ vgetq_lane_u64(mid, 1), r3 = vgetq_lane_u64(hi, 1);
    uint64x2_t u = vreinterpretq_u64_p128(vmull_p64((poly64_t)r3, (poly64_t)0x87)); r1 ^= vgetq_lane_u64(u, 0); r2 ^= vgetq_lane_u64(u, 1);
    uint64x2_t v = vreinterpretq_u64_p128(vmull_p64((poly64_t)r2, (poly64_t)0x87)); r0 ^= vgetq_lane_u64(v, 0); r1 ^= vgetq_lane_u64(v, 1);
    vst1q_u8(y, vrbitq_u8(vreinterpretq_u8_u64(vcombine_u64(vcreate_u64(r0), vcreate_u64(r1)))));
}
static void counter_block(const uint8_t *nonce, uint32_t count, uint8_t *b) { for (int i = 0; i < 12; i++) b[i] = nonce[i]; b[12] = (uint8_t)(count >> 24); b[13] = (uint8_t)(count >> 16); b[14] = (uint8_t)(count >> 8); b[15] = (uint8_t)count; }
static inline uint8x16_t aes_vec(const aes *a, uint8x16_t s) { for (int r = 0; r < a->rounds - 1; r++) s = vaesmcq_u8(vaeseq_u8(s, a->round[r])); return veorq_u8(vaeseq_u8(s, a->round[a->rounds - 1]), a->round[a->rounds]); }
static inline uint8x16_t counter_vec(uint8x16_t base, uint32_t count) { return vreinterpretq_u8_u32(vsetq_lane_u32(__builtin_bswap32(count), vreinterpretq_u32_u8(base), 3)); }
static void crypt(const aes *a, const uint8_t *nonce, const uint8_t *in, uint8_t *out, uint64_t n) { uint8_t b[16], ks[16]; uint32_t count = 2; uint64_t at = 0; counter_block(nonce, 0, b); uint8x16_t base = vld1q_u8(b);
    for (; at + 64 <= n; at += 64, count += 4) {                                                                       /* four blocks in step: the processor works on them at once */
        uint8x16_t s0 = veorq_u8(counter_vec(base, count), a->round[0]), s1 = veorq_u8(counter_vec(base, count + 1), a->round[0]), s2 = veorq_u8(counter_vec(base, count + 2), a->round[0]), s3 = veorq_u8(counter_vec(base, count + 3), a->round[0]);
        for (int r = 1; r < a->rounds; r++) { s0 = veorq_u8(vaesmcq_u8(vaeseq_u8(s0, vdupq_n_u8(0))), a->round[r]); s1 = veorq_u8(vaesmcq_u8(vaeseq_u8(s1, vdupq_n_u8(0))), a->round[r]); s2 = veorq_u8(vaesmcq_u8(vaeseq_u8(s2, vdupq_n_u8(0))), a->round[r]); s3 = veorq_u8(vaesmcq_u8(vaeseq_u8(s3, vdupq_n_u8(0))), a->round[r]); }
        s0 = veorq_u8(vaeseq_u8(s0, vdupq_n_u8(0)), a->round[a->rounds]); s1 = veorq_u8(vaeseq_u8(s1, vdupq_n_u8(0)), a->round[a->rounds]); s2 = veorq_u8(vaeseq_u8(s2, vdupq_n_u8(0)), a->round[a->rounds]); s3 = veorq_u8(vaeseq_u8(s3, vdupq_n_u8(0)), a->round[a->rounds]);
        vst1q_u8(out + at, veorq_u8(vld1q_u8(in + at), s0)); vst1q_u8(out + at + 16, veorq_u8(vld1q_u8(in + at + 16), s1)); vst1q_u8(out + at + 32, veorq_u8(vld1q_u8(in + at + 32), s2)); vst1q_u8(out + at + 48, veorq_u8(vld1q_u8(in + at + 48), s3)); }
    for (; at + 16 <= n; at += 16, count++) vst1q_u8(out + at, veorq_u8(vld1q_u8(in + at), aes_vec(a, counter_vec(base, count))));
    if (at < n) { counter_block(nonce, count, b); aes_block(a, b, ks); for (uint64_t i = 0; at + i < n; i++) out[at + i] = in[at + i] ^ ks[i]; } }
static inline uint64x2_t field_times(uint64x2_t a, uint64x2_t b) {
    poly64_t a0 = (poly64_t)vgetq_lane_u64(a, 0), a1 = (poly64_t)vgetq_lane_u64(a, 1), b0 = (poly64_t)vgetq_lane_u64(b, 0), b1 = (poly64_t)vgetq_lane_u64(b, 1);
    uint64x2_t lo = vreinterpretq_u64_p128(vmull_p64(a0, b0)), hi = vreinterpretq_u64_p128(vmull_p64(a1, b1)), mid = veorq_u64(vreinterpretq_u64_p128(vmull_p64(a0, b1)), vreinterpretq_u64_p128(vmull_p64(a1, b0)));
    uint64_t r0 = vgetq_lane_u64(lo, 0), r1 = vgetq_lane_u64(lo, 1) ^ vgetq_lane_u64(mid, 0), r2 = vgetq_lane_u64(hi, 0) ^ vgetq_lane_u64(mid, 1), r3 = vgetq_lane_u64(hi, 1);
    uint64x2_t u = vreinterpretq_u64_p128(vmull_p64((poly64_t)r3, (poly64_t)0x87)); r1 ^= vgetq_lane_u64(u, 0); r2 ^= vgetq_lane_u64(u, 1);
    uint64x2_t v = vreinterpretq_u64_p128(vmull_p64((poly64_t)r2, (poly64_t)0x87)); r0 ^= vgetq_lane_u64(v, 0); r1 ^= vgetq_lane_u64(v, 1); return vcombine_u64(vcreate_u64(r0), vcreate_u64(r1)); }
/* The running value over a stretch of bytes: whole blocks stay in registers, turned round once on the way in. */
static void ghash_run(uint8_t *y, const uint8_t *h, const uint8_t *x, uint64_t n) {
    uint64x2_t hv = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(h))), yv = vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(y))); uint64_t at = 0;
    for (; at + 16 <= n; at += 16) yv = field_times(veorq_u64(yv, vreinterpretq_u64_u8(vrbitq_u8(vld1q_u8(x + at)))), hv);
    vst1q_u8(y, vrbitq_u8(vreinterpretq_u8_u64(yv))); if (at < n) ghash_block(y, h, x + at, n - at); }
static void tag_of(const aes *a, const uint8_t *nonce, const uint8_t *extra, uint64_t en, const uint8_t *locked, uint64_t n, uint8_t *tag) {
    uint8_t h[16], zero[16] = {0}, y[16] = {0}, lens[16], b[16], first[16]; aes_block(a, zero, h);
    ghash_run(y, h, extra, en); ghash_run(y, h, locked, n);
    uint64_t eb = en * 8, nb = n * 8; for (int i = 0; i < 8; i++) { lens[i] = (uint8_t)(eb >> (56 - 8 * i)); lens[8 + i] = (uint8_t)(nb >> (56 - 8 * i)); } ghash_block(y, h, lens, 16);
    counter_block(nonce, 1, b); aes_block(a, b, first); for (int i = 0; i < 16; i++) tag[i] = (uint8_t)(y[i] ^ first[i]);
}
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which, const block *out) {
    const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size >= 64 && b != out ? b : 0; }
int64_t seal(block *out, const int16_t *p, int64_t n, int64_t a_, void *const *table) { (void)a_;
    const block *key = bytes_at(table, p, n, 0, out), *nonce = bytes_at(table, p, n, 1, out), *extra = bytes_at(table, p, n, 2, out), *msg = bytes_at(table, p, n, 3, out);
    if (!key || !nonce || !extra || !msg || (key->size != 64 + 16 && key->size != 64 + 32) || nonce->size != 64 + 12 || out->size < 64) return -1;
    uint64_t len = msg->size - 64; if (out->size - 64 < len + 16) return -1; aes a; aes_key(&a, key->bytes, (int)(key->size - 64));
    crypt(&a, nonce->bytes, msg->bytes, out->bytes, len); tag_of(&a, nonce->bytes, extra->bytes, extra->size - 64, out->bytes, len, out->bytes + len); return (int64_t)len + 16;
}
int64_t open(block *out, const int16_t *p, int64_t n, int64_t a_, void *const *table) { (void)a_;
    const block *key = bytes_at(table, p, n, 0, out), *nonce = bytes_at(table, p, n, 1, out), *extra = bytes_at(table, p, n, 2, out), *in = bytes_at(table, p, n, 3, out);
    if (!key || !nonce || !extra || !in || (key->size != 64 + 16 && key->size != 64 + 32) || nonce->size != 64 + 12 || out->size < 64 || in->size < 64 + 16) return -1;
    uint64_t len = in->size - 64 - 16; if (out->size - 64 < len) return -1; aes a; aes_key(&a, key->bytes, (int)(key->size - 64));
    uint8_t tag[16]; tag_of(&a, nonce->bytes, extra->bytes, extra->size - 64, in->bytes, len, tag); uint32_t differ = 0; for (int i = 0; i < 16; i++) differ |= (uint32_t)(tag[i] ^ in->bytes[len + i]); if (differ) return -1;
    crypt(&a, nonce->bytes, in->bytes, out->bytes, len); return (int64_t)len;
}
