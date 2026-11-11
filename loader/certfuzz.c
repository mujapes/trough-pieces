/* Damaged certificates must be refused or read, never crash.   certfuzz <piece stem> <cert.der> <rounds>
 * Each round copies the certificate to the very end of a page whose successor is unreadable, so a read past the end faults. */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
int main(int argc, char **argv) { static void *table[512]; piece p; if (argc != 4 || piece_load(&p, argv[1])) return 2; FILE *in = fopen(argv[2], "rb"); static uint8_t orig[8192]; size_t len = fread(orig, 1, sizeof orig, in); fclose(in);
    entry5 number = (entry5)piece_entry(&p, "number"), bytes = (entry5)piece_entry(&p, "bytes"), covers = (entry5)piece_entry(&p, "covers");
    uint8_t *arena = mmap(0, 4 * 4096, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0); mprotect(arena + 3 * 4096, 4096, PROT_NONE);
    uint8_t *out = calloc(1, 64 + 8192), *name = calloc(1, 64 + 16); uint32_t kind = 2; uint64_t z = 64 + 8192; memcpy(out, &kind, 4); memcpy(out + 16, &z, 8); z = 64 + 11; memcpy(name, &kind, 4); memcpy(name + 16, &z, 8); memcpy(name + 64, "example.com", 11); table[256 + 21] = name;
    uint32_t seed = 12345; long rounds = atol(argv[3]), read = 0, refused = 0; long long sum = 0;
#define RND (seed = seed * 1664525u + 1013904223u, seed >> 8)
    for (long r = 0; r < rounds; r++) { uint8_t work[8192]; memcpy(work, orig, len); size_t n = len; int how = (int)(RND % 4);
        if (how == 0) n = RND % (len + 1); else for (int k = 0, flips = 1 + (int)(RND % (how == 1 ? 1 : how == 2 ? 4 : 30)); k < flips; k++) work[RND % len] = (how == 3 && RND % 2) ? (uint8_t)RND : (uint8_t)(work[RND % len] ^ (1u << (RND % 8)));
        uint8_t *b = arena + 3 * 4096 - (64 + n); memset(b, 0, 64); z = 64 + n; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); memcpy(b + 64, work, n); table[256 + 20] = b;
        int16_t q[2] = {20, 0}; long long first = number(0, q, 2, 0, table); if (first < 0) refused++; else read++;
        for (int w = 0; w < 10; w++) { q[1] = (int16_t)w; sum += number(0, q, 2, 0, table); sum += bytes(out, q, 2, 0, table); } q[1] = 21; sum += covers(0, q, 2, 0, table); }
    printf("%ld damaged certificates: %ld refused, %ld still readable, no crash (%lld)\n", rounds, refused, read, sum); return 0; }
