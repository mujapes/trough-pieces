/* The meaning of the piece (layout version 2; third implementation), written the obvious way.
 * It no longer measures sound itself: loudness and peak come from the sound-measures and peak pieces, reached
 * through the call table it is handed. Whatever is behind those sockets can be swapped without touching this. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t version, pad; double floor, level; int64_t blocks, fine_pos; uint8_t reserved[24]; double fine[50]; uint8_t rest[48]; } state;
int64_t migrate(state *s, const int16_t *unused_samples, int64_t unused_count, int64_t unused_argument, void *const *table) {
    (void)unused_samples; (void)unused_count; (void)unused_argument; (void)table;
    if (s->version == 2) return 2;
    if (s->version == 0) { s->pad = 0; s->floor = 0.004; s->level = 0; s->blocks = 0; }
    else if (s->version != 1) return 0;
    /* From version 1 everything learned is kept; only the fields that are new in version 2 are cleared. */
    s->version = 2; s->fine_pos = 0;
    for (int i = 0; i < 24; i++) s->reserved[i] = 0;
    for (int i = 0; i < 50; i++) s->fine[i] = 0;
    for (int i = 0; i < 48; i++) s->rest[i] = 0;
    return 2;
}
int64_t step(state *s, const int16_t *x, int64_t n, int64_t flags, void *const *table) {
    double level = __builtin_sqrt((double)TROUGH_CALL(table, SLOT_SOUND_MEASURES_ENERGY, x, n, 0) / (double)(n > 1 ? n : 1)) / 32768.0;
    double rise = (flags & 2) ? 0.003 : 0.01;
    double floor = level < s->floor ? s->floor * 0.5 + level * 0.5 : s->floor * (1 - rise) + level * rise;
    if (floor < 0.0005) floor = 0.0005;
    s->floor = floor; s->level = level; s->blocks++;
    double bar = floor * 3.5 > 0.012 ? floor * 3.5 : 0.012;
    if (flags & 1) bar = bar * 1.6;
    int64_t answer = level > bar;
    if (flags & 2) for (int64_t from = 0; from + 320 <= n; from += 320)
        s->fine[s->fine_pos++ % 50] = __builtin_sqrt((double)TROUGH_CALL(table, SLOT_SOUND_MEASURES_ENERGY, x + from, 320, 0) / 320.0) / 32768.0;
    double top = 0; for (int i = 0; i < 50; i++) if (s->fine[i] > top) top = s->fine[i];
    int climbs = 0; double mark = top * 0.35;
    for (int i = 1; i < 50; i++) { double was = s->fine[(s->fine_pos + i - 1) % 50], is = s->fine[(s->fine_pos + i) % 50]; if (was <= mark && is > mark) climbs++; }
    if (climbs >= 2) answer |= 2;
    if (TROUGH_CALL(table, SLOT_PEAK_PEAK, x, n, 0) >= 32700) answer |= 4;   /* the microphone hit its ceiling in this block */
    return answer;
}
