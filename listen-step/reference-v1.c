/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
typedef struct { uint32_t version, pad; double floor, level; int64_t blocks; uint8_t reserved[32]; } state;
int64_t migrate(state *s) {
    if (s->version == 1) return 1;
    if (s->version != 0) return 0;
    s->version = 1; s->pad = 0; s->floor = 0.004; s->level = 0; s->blocks = 0;
    for (int i = 0; i < 32; i++) s->reserved[i] = 0;
    return 1;
}
int64_t step(state *s, const int16_t *x, int64_t n, int64_t flags) {
    int64_t energy = 0;
    for (int64_t i = 0; i < n; i++) energy += (int32_t)x[i] * x[i];
    double level = __builtin_sqrt((double)energy / (double)(n > 1 ? n : 1)) / 32768.0;
    double rise = (flags & 2) ? 0.003 : 0.01;
    double floor = level < s->floor ? s->floor * 0.5 + level * 0.5 : s->floor * (1 - rise) + level * rise;
    if (floor < 0.0005) floor = 0.0005;
    s->floor = floor; s->level = level; s->blocks++;
    double bar = floor * 3.5 > 0.012 ? floor * 3.5 : 0.012;
    if (flags & 1) bar = bar * 1.6;
    return level > bar;
}
