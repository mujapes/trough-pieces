/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
static int32_t get(const uint8_t *p, uint64_t i) { return (int16_t)(uint16_t)(p[2 * i] | (p[2 * i + 1] << 8)); }
static void put(uint8_t *p, uint64_t i, int32_t v) { p[2 * i] = (uint8_t)v; p[2 * i + 1] = (uint8_t)(v >> 8); }
static int64_t floordiv(int64_t a, int64_t b) { int64_t q = a / b; return (a % b != 0 && a < 0) ? q - 1 : q; }   /* b > 0 */
int64_t convert(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    if (n < 6) return -1; const block *src = (const block *)TROUGH_BLOCK(table, p[0]); int64_t rin = p[1], cin = p[2], rout = p[3], cout = p[4], vol = p[5];
    if (!src || src->kind != 2 || src->size < 64 || (const block *)out == src || out->size < 64) return -1;
    if (rin < 1 || rin > 7680 || rout < 1 || rout > 7680 || cin < 1 || cin > 2 || cout < 1 || cout > 2 || vol < 0 || vol > 256) return -1;
    uint64_t frames = (src->size - 64) / 2 / (uint64_t)cin, want = frames * (uint64_t)rout / (uint64_t)rin, room = (out->size - 64) / 2 / (uint64_t)cout; if (want > room) want = room;
    uint8_t *o = (uint8_t *)out + 64;
    for (uint64_t i = 0; i < want; i++) { uint64_t pos = i * (uint64_t)rin, k = pos / (uint64_t)rout; int64_t r = (int64_t)(pos % (uint64_t)rout); uint64_t k1 = k + 1 < frames ? k + 1 : k; int64_t v[2];
        for (int c = 0; c < cin; c++) v[c] = floordiv((int64_t)get(src->bytes, k * (uint64_t)cin + (uint64_t)c) * (rout - r) + (int64_t)get(src->bytes, k1 * (uint64_t)cin + (uint64_t)c) * r + rout / 2, rout);
        if (cin == 1 && cout == 2) v[1] = v[0]; else if (cin == 2 && cout == 1) v[0] = floordiv(v[0] + v[1], 2);
        for (int c = 0; c < cout; c++) put(o, i * (uint64_t)cout + (uint64_t)c, (int32_t)floordiv(v[c] * vol, 256)); }
    return (int64_t)(want * (uint64_t)cout);
}
int64_t mix(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    if (n < 4) return -1; const block *src = (const block *)TROUGH_BLOCK(table, p[0]); int64_t vol = p[1];
    if (!src || src->kind != 2 || src->size < 64 || (const block *)out == src || out->size < 64 || vol < 0 || vol > 256 || p[2] < 0 || p[3] < 0) return -1;
    uint64_t start = (uint64_t)p[2] + 32768ull * (uint64_t)p[3], have = (src->size - 64) / 2, room = (out->size - 64) / 2; if (start >= room) return 0; if (have > room - start) have = room - start;
    uint8_t *o = (uint8_t *)out + 64;
    for (uint64_t i = 0; i < have; i++) { int64_t v = get(o, start + i) + floordiv((int64_t)get(src->bytes, i) * vol, 256); put(o, start + i, (int32_t)(v > 32767 ? 32767 : v < -32768 ? -32768 : v)); }
    return (int64_t)have;
}
