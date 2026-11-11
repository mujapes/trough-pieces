/* Drive the tls piece against a real server.   tlsbench <out dir> <host ip> <port> <server name> [request path]
 * The host's part: the socket, the random seed, and passing bytes back and forth. Everything else is the pieces. */
#include "piece.h"
#include <arpa/inet.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static void *table[512]; static piece loaded[64]; static char stems[64][256]; static int count;
static piece *get(const char *stem) { for (int i = 0; i < count; i++) if (!strcmp(stems[i], stem)) return &loaded[i]; if (count >= 64 || piece_load(&loaded[count], stem)) return 0; strncpy(stems[count], stem, 255); return &loaded[count++]; }
static uint8_t *bytes(uint32_t kind, size_t n) { uint8_t *b = calloc(1, 64 + n); uint64_t z = 64 + n; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); return b; }
static void resize(uint8_t *b, size_t n) { uint64_t z = 64 + n; memcpy(b + 16, &z, 8); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(int argc, char **argv) {
    if (argc < 5) return 2; char path[600]; snprintf(path, sizeof path, "%s/../slots.txt", argv[1]); FILE *f = fopen(path, "r"); if (!f) return 2;
    char line[256]; while (fgets(line, sizeof line, f)) { int slot; char name[64], entry[64]; if (line[0] == '#' || sscanf(line, "%d %63s %63s", &slot, name, entry) != 3) continue;
        snprintf(path, sizeof path, "%s/%s.ref", argv[1], name); piece *p = get(path); if (p && slot >= 0 && slot < 256) table[slot] = piece_entry(p, entry); } fclose(f);
    snprintf(path, sizeof path, "%s/tls.%s", argv[1], getenv("TLS_VARIANT") ? getenv("TLS_VARIANT") : "ref"); piece *tls = get(path); if (!tls) { printf("cannot load tls\n"); return 1; }
    entry5 migrate = (entry5)piece_entry(tls, "migrate"), begin = (entry5)piece_entry(tls, "begin"), feed = (entry5)piece_entry(tls, "feed"), send_ = (entry5)piece_entry(tls, "send");
    uint8_t *state = calloc(1, 1 << 18), *seed = bytes(2, 96), *name = bytes(2, strlen(argv[4])), *in = bytes(2, 1 << 18), *out = bytes(2, 1 << 17), *plain = bytes(2, 1 << 18), *request = bytes(2, 600);
    FILE *r = fopen("/dev/urandom", "rb"); if (!r || fread(seed + 64, 1, 96, r) != 96) return 1; fclose(r); memcpy(name + 64, argv[4], strlen(argv[4]));
    table[256 + 20] = seed; table[256 + 21] = name; table[256 + 22] = out; table[256 + 23] = in; table[256 + 24] = plain; table[256 + 25] = request;
    /* The roots this phone trusts, one after another, and the time: with them the piece checks who the server is. Without TLS_ROOTS it does not. */
    const char *rootfile = getenv("TLS_ROOTS"); int with_roots = 0; if (rootfile) { FILE *rf = fopen(rootfile, "rb"); if (!rf) { printf("cannot read roots\n"); return 1; } fseek(rf, 0, SEEK_END); long rl = ftell(rf); fseek(rf, 0, SEEK_SET); uint8_t *rb = bytes(2, (size_t)rl); if (fread(rb + 64, 1, (size_t)rl, rf) != (size_t)rl) return 1; fclose(rf); table[256 + 26] = rb; with_roots = 1; }
    const char *bodyfile = getenv("TLS_BODY"); FILE *body = bodyfile ? fopen(bodyfile, "wb") : 0; long long clock_now = getenv("TLS_TIME") ? atoll(getenv("TLS_TIME")) : (long long)time(0);
    int s = socket(AF_INET, SOCK_STREAM, 0); struct sockaddr_in to; memset(&to, 0, sizeof to); to.sin_family = AF_INET; to.sin_port = htons((uint16_t)atoi(argv[3])); inet_pton(AF_INET, argv[2], &to.sin_addr);
    double t0 = now(); if (connect(s, (struct sockaddr *)&to, sizeof to)) { printf("cannot connect\n"); return 1; } double t1 = now();
    migrate(state, 0, 0, 0, table); int16_t q[4] = {20, 21, 22, (int16_t)(getenv("TLS_CIPHERS") ? atoi(getenv("TLS_CIPHERS")) : 0)}; long long made = begin(state, q, 4, 0, table);   /* TLS_CIPHERS: 0 offer both, 1 ChaCha20 only, 2 AES-128-GCM only */ printf("begin -> %lld bytes of hello\n", made); if (made < 0) return 1;
    if (write(s, out + 64, (size_t)made) != made) return 1;
    const char *save = getenv("TLS_SAVE"); FILE *cap = 0; if (save) { snprintf(path, sizeof path, "%s-seed.fixture", save); FILE *o = fopen(path, "wb"); fwrite(seed + 64, 1, 96, o); fclose(o); snprintf(path, sizeof path, "%s-server.fixture", save); cap = fopen(path, "wb"); }   /* a session kept for replay as a recorded check */
    size_t have = 0, total = 0; int asked = 0; uint32_t *st = (uint32_t *)state; double crypto = 0;
    for (;;) { ssize_t got = read(s, in + 64 + have, (1 << 18) - have); if (got <= 0) { printf("server closed the connection\n"); break; } if (cap) { fwrite(in + 64 + have, 1, (size_t)got, cap); fflush(cap); } have += (size_t)got; resize(in, have);
        int16_t fq[4] = {23, 22, 24, 26}; double c0 = now(); long long stage = feed(state, fq, with_roots ? 4 : 3, clock_now, table); crypto += now() - c0; uint32_t used = st[6], send_len = st[2], plain_len = st[3];
        if (stage < 0) { printf("REFUSED: stage %u, alert %u, trust answer %d (-2 name, -3 dates, -4 not allowed, -5 no trusted root, -6 handshake signature)\n", st[1], st[8], (int)st[11]); return 1; }
        if (send_len && write(s, out + 64, send_len) != (ssize_t)send_len) return 1;
        memmove(in + 64, in + 64 + used, have - used); have -= used;
        if (plain_len && body) fwrite(plain + 64, 1, plain_len, body);
        if (plain_len) { if (!total) printf("--- first plain bytes from the server ---\n%.*s\n---\n", plain_len > 300 ? 300 : (int)plain_len, plain + 64); total += plain_len; }
        if (stage == 3 && !asked) { asked = 1; printf("handshake complete %.1f ms after connecting (%.2f ms of it inside the pieces); certificate %u bytes, cipher %s, %s\n", now() - t1, crypto, st[10], st[12] == 2 ? "AES-128-GCM" : "ChaCha20-Poly1305", st[7] ? "NOT checked" : "CHECKED: chain leads to a trusted root, name matches, server signed the handshake");
            int len = snprintf((char *)request + 64, 600, "GET %s HTTP/1.0\r\nHost: %s\r\n\r\n", argc > 5 ? argv[5] : "/", argv[4]); if (getenv("TLS_REQUEST")) { FILE *rq = fopen(getenv("TLS_REQUEST"), "rb"); if (!rq) return 1; request = bytes(2, 8192); table[256 + 25] = request; len = (int)fread(request + 64, 1, 8192, rq); fclose(rq); }   /* the request the http piece wrote */ resize(request, (size_t)len); int16_t sq[2] = {25, 22}; long long n = send_(state, sq, 2, 0, table); if (n < 0 || write(s, out + 64, (size_t)n) != n) return 1; }
        if (stage == 4) { printf("server said goodbye\n"); break; } }
    if (body) fclose(body); printf("plain bytes received: %zu (connect took %.1f ms)\n", total, t1 - t0); close(s); return total ? 0 : 1; }
