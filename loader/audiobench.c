/* Decode an audio file with a piece, write the samples, and time it.   audiobench <piece stem> <file> <out.raw> */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(int argc, char **argv) {
    if (argc != 4) return 2; static void *table[512]; piece p; if (piece_load(&p, argv[1])) { printf("cannot load\n"); return 1; }
    FILE *in = fopen(argv[2], "rb"); if (!in) return 1; fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET);
    uint8_t *file = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t z = 64 + (uint64_t)len; memcpy(file, &kind, 4); memcpy(file + 16, &z, 8); if (fread(file + 64, 1, (size_t)len, in) != (size_t)len) return 1; fclose(in);
    size_t ss = 64 + 8u * 65536 * 2; uint8_t *scratch = calloc(1, ss); kind = 5; z = ss; memcpy(scratch, &kind, 4); memcpy(scratch + 16, &z, 8);
    table[256 + 20] = file; table[256 + 21] = scratch; entry5 info = (entry5)piece_entry(&p, "info"), decode = (entry5)piece_entry(&p, "decode");
    int16_t q[2] = {20, 0}; long long fact[4]; for (int i = 0; i < 4; i++) { q[1] = (int16_t)i; fact[i] = info(0, q, 2, 0, table); }
    printf("rate %lld channels %lld bits %lld samples %lld\n", fact[0], fact[1], fact[2], fact[3]); if (fact[0] < 0) return 1;
    size_t os = 64 + (size_t)(fact[3] ? fact[3] : 60ll * 48000) * (size_t)fact[1] * 2; uint8_t *out = calloc(1, os); kind = 2; z = os; memcpy(out, &kind, 4); memcpy(out + 16, &z, 8);
    q[1] = 21; long long made = -1; double best = 1e18; for (int r = 0; r < 5; r++) { double t = now(); made = decode(out, q, 2, 0, table); t = now() - t; if (t < best) best = t; }
    printf("decoded %lld samples in %.2f ms", made, best); if (made > 0) printf(" = %.0fx real time", (double)made / (double)fact[1] / (double)fact[0] * 1000.0 / best); printf("\n");
    if (made > 0) { FILE *o = fopen(argv[3], "wb"); fwrite(out + 64, 2, (size_t)made, o); fclose(o); } return made > 0 ? 0 : 1;
}
