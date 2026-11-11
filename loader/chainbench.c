/* Time the trust piece's chain check inside one process.   chainbench <out dir> <trust variant> <name> <roots.der> <cert.der>...
 * Sockets are filled from the reference builds (slots.txt), except trust's own, which come from the variant named. */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static void *table[512]; static piece loaded[64]; static char stems[64][256]; static int count;
static piece *get(const char *stem) { for (int i = 0; i < count; i++) if (!strcmp(stems[i], stem)) return &loaded[i]; if (count >= 64 || piece_load(&loaded[count], stem)) return 0; strncpy(stems[count], stem, 255); return &loaded[count++]; }
static uint8_t *file(const char *path, const char *text) { size_t n = text ? strlen(text) : 0; FILE *in = text ? 0 : fopen(path, "rb"); if (!text) { if (!in) return 0; fseek(in, 0, SEEK_END); n = (size_t)ftell(in); fseek(in, 0, SEEK_SET); }
    uint8_t *b = calloc(1, 64 + n); uint32_t kind = 2; uint64_t z = 64 + n; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); if (text) memcpy(b + 64, text, n); else { if (fread(b + 64, 1, n, in) != n) return 0; fclose(in); } return b; }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(int argc, char **argv) { if (argc < 6) return 2; char path[600]; snprintf(path, sizeof path, "%s/../slots.txt", argv[1]); FILE *f = fopen(path, "r"); if (!f) return 2;
    char line[256]; while (fgets(line, sizeof line, f)) { int slot; char name[64], entry[64]; if (line[0] == '#' || sscanf(line, "%d %63s %63s", &slot, name, entry) != 3) continue;
        snprintf(path, sizeof path, "%s/%s.%s", argv[1], name, !strcmp(name, "trust") ? argv[2] : "ref"); piece *p = get(path); if (p && slot >= 0 && slot < 256) table[slot] = piece_entry(p, entry); } fclose(f);
    int16_t q[10] = {20, 21}; int n = 2; table[256 + 20] = file(0, argv[3]); table[256 + 21] = file(argv[4], 0); for (int i = 5; i < argc && n < 10; i++, n++) { table[256 + 20 + n] = file(argv[i], 0); q[n] = (int16_t)(20 + n); if (!table[256 + 20 + n]) return 1; }
    entry5 chain = (entry5)table[29]; if (!chain || !table[256 + 21]) return 1; long long answer = 0; double best = 1e9; long long when = getenv("CHAIN_TIME") ? atoll(getenv("CHAIN_TIME")) : (long long)time(0);
    for (int r = 0; r < 9; r++) { double t = now(); for (int k = 0; k < 10; k++) answer = chain(0, q, n, when, table); t = (now() - t) / 10; if (t < best) best = t; }
    printf("%lld %.3f\n", answer, best); return 0; }
