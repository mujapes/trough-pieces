/* bench driver for the dom piece: each line of stdin is one request (\n written as backslash n); prints the answer or the refusal. */
#include "../../loader/piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static void *table[512];
static uint8_t *block(uint32_t kind, size_t n) { uint8_t *b = calloc(1, 64 + n + 16); uint64_t z = 64 + n; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); return b; }
int main(int argc, char **argv) { piece p; if (piece_load(&p, argv[1])) return 3; entry5 begin = (entry5)piece_entry(&p, "begin"), ask = (entry5)piece_entry(&p, "ask");
    size_t room = argc > 2 ? (size_t)atol(argv[2]) : 1 << 20; uint8_t *tree = block(9, room), *req = block(2, 1 << 20), *ans = block(2, 1 << 20); table[256 + 41] = req; table[256 + 42] = ans; int16_t q[2] = {41, 42};
    printf("begin %lld\n", begin(tree, 0, 0, 0, table)); char line[65536];
    while (fgets(line, sizeof line, stdin)) { size_t n = strlen(line); if (n && line[n - 1] == '\n') n--; size_t m = 0; for (size_t i = 0; i < n; i++) { if (line[i] == '\\' && line[i + 1] == 'n') { req[64 + m++] = '\n'; i++; } else req[64 + m++] = (uint8_t)line[i]; }
        uint64_t z = 64 + m; memcpy(req + 16, &z, 8); long long r = ask(tree, q, 2, 0, table); if (r < 0) printf("%.20s => refused %lld\n", line[0] ? line : "", r); else printf("%.*s => [%.*s]\n", n > 20 ? 20 : (int)n, line, (int)r, ans + 64); }
    return 0; }
