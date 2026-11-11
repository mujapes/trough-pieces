/* Tests for the sound-measures piece, and the live-swap trial. Usage: test <stem> [<other stem>] */
#include "../loader/piece.h"
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
int64_t ref_energy(const int16_t *, int64_t); int64_t ref_climbs(const int16_t *, int64_t, int64_t);
typedef struct { int64_t (*energy)(const int16_t *, int64_t); int64_t (*climbs)(const int16_t *, int64_t, int64_t); } impl;
static unsigned seed = 4242; static unsigned rnd(void) { seed = seed * 1103515245u + 12345u; return seed >> 8; }
static double now_ns(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1e9+t.tv_nsec;}

/* What correct means: identical to the reference on edge cases and on many random inputs. */
static int passes(const impl *m, long *cases) {
    static int16_t x[70000]; long n_cases = 0;
    static const int16_t edge[] = {-32768, 32767, 0, -1, 1};
    for (int e = 0; e < 5; e++) for (int n = 0; n <= 70000; n += (n < 70 ? 1 : 3331)) {       /* extremes at every length shape */
        for (int i = 0; i < n; i++) x[i] = edge[e];
        if (m->energy(x, n) != ref_energy(x, n)) return 0;
        for (int t = 0; t < 5; t++) if (m->climbs(x, n, edge[t]) != ref_climbs(x, n, edge[t])) return 0;
        n_cases += 6;
    }
    for (int t = 0; t < 40000; t++) {
        int n = t < 30000 ? (int)(rnd() % 300) : (int)(rnd() % 70000); int span = 1 + (int)(rnd() % 65535);
        for (int i = 0; i < n; i++) x[i] = (int16_t)((int)(rnd() % (unsigned)span) - span / 2);
        int thr = (int)(rnd() % 65536) - 32768; int shift = (int)(rnd() % 8);                 /* unaligned starts too */
        if (shift > n) shift = 0;
        if (m->energy(x + shift, n - shift) != ref_energy(x + shift, n - shift)) return 0;
        if (m->climbs(x + shift, n - shift, thr) != ref_climbs(x + shift, n - shift, thr)) return 0;
        n_cases += 2;
    }
    *cases = n_cases; return 1;
}

static _Atomic(impl *) current; static atomic_int stop; static atomic_long calls, wrong;
static int16_t block[1600]; static int64_t want_energy, want_climbs;
static void *caller(void *unused) { (void)unused;
    while (!atomic_load(&stop)) {
        impl *m = atomic_load(&current);                       /* one read: this call uses one implementation throughout */
        if (m->energy(block, 1600) != want_energy || m->climbs(block, 1600, 0) != want_climbs) atomic_fetch_add(&wrong, 1);
        atomic_fetch_add(&calls, 1);
    }
    return NULL;
}
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    piece p[2]; impl m[2]; int count = argc > 2 ? 2 : 1;
    for (int i = 0; i < count; i++) {
        int err = piece_load(&p[i], argv[1 + i]); if (err) { printf("load %s failed: %d\n", argv[1 + i], err); return 1; }
        m[i].energy = (int64_t (*)(const int16_t *, int64_t))piece_entry(&p[i], "energy");
        m[i].climbs = (int64_t (*)(const int16_t *, int64_t, int64_t))piece_entry(&p[i], "climbs");
        if (!m[i].energy || !m[i].climbs) { printf("%s lacks an entry\n", argv[1 + i]); return 1; }
        long cases = 0; double t0 = now_ns(); int ok = passes(&m[i], &cases);
        printf("%s: loaded in %.0f microseconds through %s, %s (%ld checks, %.2f s)\n", argv[1 + i], p[i].load_us, p[i].how, ok ? "PASSES" : "FAILS", cases, (now_ns() - t0) / 1e9);
        if (!ok) return 1;                                       /* a failing implementation never becomes current */
    }
    if (count < 2) return 0;
    for (int i = 0; i < 1600; i++) block[i] = (int16_t)(rnd() % 2001 - 1000);
    want_energy = ref_energy(block, 1600); want_climbs = ref_climbs(block, 1600, 0);
    atomic_store(&current, &m[0]);
    pthread_t thread[2]; for (int i = 0; i < 2; i++) pthread_create(&thread[i], NULL, caller, NULL);
    double worst = 0, total = 0; int swaps = 200000;
    for (int s = 0; s < swaps; s++) {
        double t0 = now_ns(); atomic_store(&current, &m[(s + 1) & 1]); double d = now_ns() - t0;
        total += d; if (d > worst) worst = d;
        if ((s & 1023) == 0) { struct timespec nap = {0, 20000}; nanosleep(&nap, NULL); }
    }
    atomic_store(&stop, 1); for (int i = 0; i < 2; i++) pthread_join(thread[i], NULL);
    printf("live swap: %d swaps while two threads made %ld calls; wrong answers: %ld\n", swaps, atomic_load(&calls), atomic_load(&wrong));
    printf("swap time: average %.0f nanoseconds, worst %.0f nanoseconds\n", total / swaps, worst);
    return atomic_load(&wrong) ? 1 : 0;
}
