/* Tests for the listen-step piece: bit-identical state against the reference over long runs, migration,
 * and (with two builds) state carried across swaps mid-run. Usage: test <stem> [<other stem>] */
#include "../loader/piece.h"
#include <stdint.h>
#include <stdio.h>
#include <string.h>
typedef struct { uint32_t version, pad; double floor, level; int64_t blocks, fine_pos; uint8_t reserved[24]; double fine[50]; uint8_t rest[48]; } state;
#define BYTES 512
#define CURRENT 2
int64_t ref_migrate(state *); int64_t ref_step(state *, const int16_t *, int64_t, int64_t);
typedef struct { int64_t (*migrate)(state *); int64_t (*step)(state *, const int16_t *, int64_t, int64_t); } impl;
static unsigned seed = 9001; static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static int16_t x[4000];
static void fill(int n, int loudness) { for (int i = 0; i < n; i++) x[i] = (int16_t)((int)(rnd() % (unsigned)(2 * loudness + 1)) - loudness); }
static long run(const impl *a, const impl *b, int swap_every, const char **why) {
    long checks = 0;
    for (int trial = 0; trial < 300; trial++) {
        state got, want; memset(&got, 0, sizeof got); memset(&want, 0, sizeof want);
        const impl *m = a; if (m->migrate(&got) != CURRENT || ref_migrate(&want) != CURRENT || memcmp(&got, &want, BYTES)) { *why = "fresh state differs"; return -1; }
        int loudness = 1 + (int)(rnd() % 30000);
        for (int block = 0; block < 400; block++) {
            if (b && swap_every && block % swap_every == swap_every - 1) { m = m == a ? b : a; if (m->migrate(&got) != CURRENT) { *why = "migrate refused live state"; return -1; } }
            if (rnd() % 23 == 0) loudness = 1 + (int)(rnd() % 32767);                  /* the room changes */
            int n = rnd() % 11 == 0 ? (int)(rnd() % 40) : 1600 + (int)(rnd() % 7) - 3; long flags = rnd() % 4;
            fill(n, rnd() % 5 == 0 ? loudness : 1 + loudness / (1 + (int)(rnd() % 40)));
            int64_t r1 = m->step(&got, x, n, flags), r2 = ref_step(&want, x, n, flags);
            if (r1 != r2) { *why = "loud answer differs"; return -1; }
            if (memcmp(&got, &want, BYTES)) { *why = "state differs"; return -1; }
            checks += 2;
        }
    }
    return checks;
}
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    piece p[2]; impl m[2]; int count = argc > 2 ? 2 : 1; const char *why = "";
    for (int i = 0; i < count; i++) {
        int err = piece_load(&p[i], argv[1 + i]); if (err) { printf("load %s failed: %d\n", argv[1 + i], err); return 1; }
        m[i].migrate = (int64_t (*)(state *))piece_entry(&p[i], "migrate");
        m[i].step = (int64_t (*)(state *, const int16_t *, int64_t, int64_t))piece_entry(&p[i], "step");
        if (!m[i].migrate || !m[i].step) { printf("%s lacks an entry\n", argv[1 + i]); return 1; }
        state s; memset(&s, 0, sizeof s); s.version = CURRENT; s.floor = 0.25; s.level = 0.5; s.blocks = 77; s.fine_pos = 123; s.fine[7] = 0.125; state before = s;
        if (m[i].migrate(&s) != CURRENT || memcmp(&s, &before, BYTES)) { printf("%s: FAILS (migrate altered a current state)\n", argv[1 + i]); return 1; }
        memset(&s, 0, sizeof s); s.version = 99; before = s;
        if (m[i].migrate(&s) != 0 || memcmp(&s, &before, BYTES)) { printf("%s: FAILS (migrate accepted an unknown version)\n", argv[1 + i]); return 1; }
        memset(&s, 0xAB, sizeof s); s.version = 1; s.pad = 0; s.floor = 0.0375; s.level = 0.0625; s.blocks = 4242;   /* a used version 1 block: junk beyond its 64 bytes */
        if (m[i].migrate(&s) != CURRENT || s.version != CURRENT || s.floor != 0.0375 || s.level != 0.0625 || s.blocks != 4242 || s.fine_pos != 0) { printf("%s: FAILS (version 1 state not carried over)\n", argv[1 + i]); return 1; }
        for (int k = 0; k < 50; k++) if (s.fine[k] != 0) { printf("%s: FAILS (new fields not cleared on migration)\n", argv[1 + i]); return 1; }
        long checks = run(&m[i], NULL, 0, &why);
        printf("%s: loaded in %.0f microseconds through %s, %s (%ld checks%s%s)\n", argv[1 + i], p[i].load_us, p[i].how, checks > 0 ? "PASSES" : "FAILS", checks, checks > 0 ? "" : ": ", why);
        if (checks <= 0) return 1;
    }
    if (count < 2) return 0;
    long checks = run(&m[0], &m[1], 7, &why);
    printf("swapping every 7 blocks with the state carried across: %s (%ld checks%s%s)\n", checks > 0 ? "PASSES" : "FAILS", checks, checks > 0 ? "" : ": ", why);
    return checks > 0 ? 0 : 1;
}
