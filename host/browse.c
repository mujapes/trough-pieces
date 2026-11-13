/* The browser's host: everything a piece cannot do for itself, and nothing else.
 *   browse <pieces out dir> <address> <out.png> [text size] [scroll] [width] [height]
 * It looks the site's name up, owns the socket and the clock, keeps the blocks, and writes the finished picture as a PNG. Every
 * decision about the page is a piece's: url (resolve, part, port), http (request, status, header, packed, body), tls with trust
 * (the roots this phone trusts), inflate, then page with font, or png / jpeg / gif with image. The pieces are the live ones
 * (<out dir>/<piece>.bin), found through slots.txt. Written in C by the user's instruction of 2026-11-12: driving the pieces
 * from inside the app was stopped by a safety check, so that function is covered here. */
#include "../loader/piece.h"
#include <arpa/inet.h>
#include <netdb.h>
#include <stdint.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static __thread void *table[512]; static void *sockets[256]; static piece loaded[64]; static char stems[64][256]; static int count; static const char *dir;
static piece *get(const char *name) { char stem[600]; snprintf(stem, sizeof stem, "%s/%s", dir, name); for (int i = 0; i < count; i++) if (!strcmp(stems[i], stem)) return &loaded[i];
    if (count >= 64 || piece_load(&loaded[count], stem)) { fprintf(stderr, "cannot load piece %s\n", stem); exit(3); } strncpy(stems[count], stem, 255); return &loaded[count++]; }
static entry5 entry(const char *piece_name, const char *name) { entry5 e = (entry5)piece_entry(get(piece_name), name); if (!e) { fprintf(stderr, "no entry %s in %s\n", name, piece_name); exit(3); } return e; }
static uint8_t *block(uint32_t kind, size_t n) { uint8_t *b = calloc(1, 64 + n + 16); if (!b) exit(4); uint64_t z = 64 + n; memcpy(b, &kind, 4); memcpy(b + 16, &z, 8); return b; }
static void resize(uint8_t *b, size_t n) { uint64_t z = 64 + n; memcpy(b + 16, &z, 8); }
static size_t length(const uint8_t *b) { uint64_t z; memcpy(&z, b + 16, 8); return (size_t)z - 64; }
static uint8_t *text_block(const char *s, size_t n) { uint8_t *b = block(2, n); memcpy(b + 64, s, n); return b; }
static uint8_t *surface(uint32_t version, uint32_t w, uint32_t h, uint32_t per) { uint64_t z = 64 + (uint64_t)w * h * per; uint8_t *b = calloc(1, z + 16); if (!b) exit(4); uint32_t head[4] = {version, w, h, w * per}; memcpy(b, head, 16); memcpy(b + 16, &z, 8); return b; }
/* handles 20 and up are the host's to hand out */
static void at(int handle, void *b) { table[256 + handle] = b; }
/* the collector's free total: walks the free list (gc.S); a block ends at the next start bit or the top */
static unsigned long long free_total(const uint8_t *w, int *count) { uint64_t h0 = *(uint64_t *)(w + 600), top = *(uint64_t *)(w + 208); const uint64_t *bits = (const uint64_t *)(w + *(uint64_t *)(w + 608)); unsigned long long sum = 0; *count = 0;
    for (uint64_t d = *(uint64_t *)(w + 640); d; d = *(uint64_t *)(w + d)) { uint64_t b = (d - h0) / 8 + 1, tb = (top - h0) / 8; while (b < tb && !(bits[b >> 6] >> (b & 63) & 1)) b++; sum += h0 + b * 8 - d; ++*count; } return sum; }
/* held blocks by size (powers of two), and the 8 biggest: for finding what a page world keeps */
static void held_sizes(const uint8_t *w) { uint64_t h0 = *(uint64_t *)(w + 600), top = *(uint64_t *)(w + 208), fr = *(uint64_t *)(w + 640); const uint64_t *bits = (const uint64_t *)(w + *(uint64_t *)(w + 608)); unsigned long long n[40] = {0}, by[40] = {0}, big[8] = {0}, bigat[8] = {0}; uint64_t tb = (top - h0) / 8, b = 0;
    while (b < tb) { uint64_t e = b + 1; while (e < tb && !(bits[e >> 6] >> (e & 63) & 1)) e++; uint64_t d = h0 + b * 8, sz = (e - b) * 8; if (d == fr) fr = *(uint64_t *)(w + d); else { int k = 63 - __builtin_clzll(sz); n[k]++; by[k] += sz; for (int j = 0; j < 8; j++) if (sz > big[j]) { for (int m = 7; m > j; m--) { big[m] = big[m-1]; bigat[m] = bigat[m-1]; } big[j] = sz; bigat[j] = d; break; } } b = e; }
    for (int k = 0; k < 40; k++) if (n[k]) fprintf(stderr, "  held %8llu blocks of %llu+ bytes: %llu\n", n[k], 1ull << k, by[k]);
    for (int j = 0; j < 8; j++) if (big[j]) { const uint8_t *q = w + bigat[j]; fprintf(stderr, "  big %llu at %llu: ", big[j], bigat[j]); for (int i = 0; i < 48; i++) fputc(q[i] >= 32 && q[i] < 127 ? q[i] : '.', stderr); fputc('\n', stderr); } }
static double now_ms(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
/* --- a PNG, stored without compression: the picture is for a card on the screen, not for keeping --- */
static uint32_t crc_table[256];
static uint32_t crc(uint32_t c, const uint8_t *d, size_t n) { c = ~c; for (size_t i = 0; i < n; i++) c = crc_table[(c ^ d[i]) & 255] ^ (c >> 8); return ~c; }
static void chunk(FILE *f, const char *tag, const uint8_t *d, uint32_t n) { uint8_t h[8] = {(uint8_t)(n >> 24), (uint8_t)(n >> 16), (uint8_t)(n >> 8), (uint8_t)n, (uint8_t)tag[0], (uint8_t)tag[1], (uint8_t)tag[2], (uint8_t)tag[3]};
    fwrite(h, 1, 8, f); if (n) fwrite(d, 1, n, f); uint32_t c = crc(crc(0, h + 4, 4), d, n); uint8_t t[4] = {(uint8_t)(c >> 24), (uint8_t)(c >> 16), (uint8_t)(c >> 8), (uint8_t)c}; fwrite(t, 1, 4, f); }
static int write_png(const char *path, const uint8_t *rgba, uint32_t w, uint32_t h) {
    for (uint32_t i = 0; i < 256; i++) { uint32_t c = i; for (int k = 0; k < 8; k++) c = (c & 1) ? 0xedb88320u ^ (c >> 1) : c >> 1; crc_table[i] = c; }
    size_t row = 1 + 4 * (size_t)w, raw = row * h, blocks = (raw + 65534) / 65535, total = 2 + raw + 5 * blocks + 4; uint8_t *z = malloc(total), *p = z; if (!z) return 0;
    *p++ = 0x78; *p++ = 0x01; uint32_t a = 1, b = 0; size_t done = 0;
    uint8_t *lines = malloc(raw); if (!lines) return 0; for (uint32_t y = 0; y < h; y++) { lines[y * row] = 0; memcpy(lines + y * row + 1, rgba + 4 * (size_t)w * y, 4 * (size_t)w); }
    for (size_t i = 0; i < raw; i++) { a = (a + lines[i]) % 65521; b = (b + a) % 65521; }
    while (done < raw) { size_t n = raw - done > 65535 ? 65535 : raw - done; *p++ = done + n == raw; *p++ = (uint8_t)n; *p++ = (uint8_t)(n >> 8); *p++ = (uint8_t)~n; *p++ = (uint8_t)(~n >> 8); memcpy(p, lines + done, n); p += n; done += n; }
    *p++ = (uint8_t)(b >> 8); *p++ = (uint8_t)b; *p++ = (uint8_t)(a >> 8); *p++ = (uint8_t)a;
    FILE *f = fopen(path, "wb"); if (!f) return 0; fwrite("\x89PNG\r\n\x1a\n", 1, 8, f);
    uint8_t ihdr[13] = {(uint8_t)(w >> 24), (uint8_t)(w >> 16), (uint8_t)(w >> 8), (uint8_t)w, (uint8_t)(h >> 24), (uint8_t)(h >> 16), (uint8_t)(h >> 8), (uint8_t)h, 8, 6, 0, 0, 0};
    chunk(f, "IHDR", ihdr, 13); chunk(f, "IDAT", z, (uint32_t)(p - z)); chunk(f, "IEND", 0, 0); fclose(f); free(z); free(lines); return 1; }
/* --- the connection: the host's part is the socket; who the server is and every byte's meaning are the tls piece's --- */
static int connect_to(const char *site, int port, char *why, size_t room) {
    struct addrinfo hints, *found = 0; memset(&hints, 0, sizeof hints); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM; char p[16]; snprintf(p, sizeof p, "%d", port);
    if (getaddrinfo(site, p, &hints, &found) || !found) { snprintf(why, room, "no such site: %s", site); return -1; }
    int s = socket(AF_INET, SOCK_STREAM, 0); struct timeval limit = {20, 0}; setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &limit, sizeof limit); setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &limit, sizeof limit);
    if (connect(s, found->ai_addr, found->ai_addrlen)) { snprintf(why, room, "cannot reach %s", site); close(s); freeaddrinfo(found); return -1; } freeaddrinfo(found); return s; }
static int send_all(int s, const uint8_t *d, size_t n) { while (n) { ssize_t w = write(s, d, n); if (w <= 0) return 0; d += w; n -= (size_t)w; } return 1; }
/* Asks for the page over a secure connection. The reply (kind 2 block, grown as needed) or 0, with the reason in why. */
static uint8_t *secure_fetch(const char *site, int port, const uint8_t *request, const uint8_t *roots, char *why, size_t room) {
    int s = connect_to(site, port, why, room); if (s < 0) return 0;
    entry5 migrate = entry("tls", "migrate"), begin = entry("tls", "begin"), feed = entry("tls", "feed"), send_ = entry("tls", "send");
    uint8_t *state = calloc(1, 1 << 18), *seed = block(2, 96), *name = text_block(site, strlen(site)), *in = block(2, 1 << 18), *out = block(2, 1 << 17), *plain = block(2, 1 << 18);
    size_t cap = 1 << 20, got_all = 0; uint8_t *reply = block(2, cap); FILE *r = fopen("/dev/urandom", "rb"); if (!r || fread(seed + 64, 1, 96, r) != 96) { snprintf(why, room, "no random bytes"); return 0; } fclose(r);
    at(20, seed); at(21, name); at(22, out); at(23, in); at(24, plain); at(25, (void *)request); at(26, (void *)roots);
    migrate(state, 0, 0, 0, table); int16_t q[4] = {20, 21, 22, 0}; long long made = begin(state, q, 4, 0, table); if (made < 0 || !send_all(s, out + 64, (size_t)made)) { snprintf(why, room, "could not start the secure connection"); close(s); return 0; }
    size_t have = 0; int asked = 0; uint32_t *st = (uint32_t *)state; long long clock_now = (long long)time(0);
    for (;;) { ssize_t got = read(s, in + 64 + have, (1 << 18) - have); if (got <= 0) break; have += (size_t)got; resize(in, have);
        int16_t fq[4] = {23, 22, 24, 26}; long long stage = feed(state, fq, 4, clock_now, table); uint32_t used = st[6], send_len = st[2], plain_len = st[3];
        if (stage < 0) { snprintf(why, room, "REFUSED by our own check: alert %u, trust answer %d (-2 name, -3 dates, -4 not allowed, -5 no trusted root, -6 handshake signature)", st[8], (int)st[11]); close(s); return 0; }
        if (send_len && !send_all(s, out + 64, send_len)) break;
        memmove(in + 64, in + 64 + used, have - used); have -= used;
        if (plain_len) { if (got_all + plain_len > cap) { while (got_all + plain_len > cap) cap *= 2; uint8_t *bigger = block(2, cap); memcpy(bigger + 64, reply + 64, got_all); free(reply); reply = bigger; } memcpy(reply + 64 + got_all, plain + 64, plain_len); got_all += plain_len; }
        if (stage == 3 && !asked) { asked = 1; if (st[7]) { snprintf(why, room, "the server's certificate was not checked: refusing"); close(s); return 0; }
            int16_t sq[2] = {25, 22}; long long n = send_(state, sq, 2, 0, table); if (n < 0 || !send_all(s, out + 64, (size_t)n)) break; }
        if (stage == 4) break; }
    close(s); free(state); if (!asked || !got_all) { snprintf(why, room, asked ? "the server sent nothing back" : "the secure connection did not complete"); return 0; } resize(reply, got_all); return reply; }
static uint8_t *plain_fetch(const char *site, int port, const uint8_t *request, char *why, size_t room) {
    int s = connect_to(site, port, why, room); if (s < 0) return 0; if (!send_all(s, request + 64, length(request))) { close(s); snprintf(why, room, "could not send"); return 0; }
    size_t cap = 1 << 20, n = 0; uint8_t *reply = block(2, cap); for (;;) { if (n == cap) { cap *= 2; uint8_t *bigger = block(2, cap); memcpy(bigger + 64, reply + 64, n); free(reply); reply = bigger; } ssize_t got = read(s, reply + 64 + n, cap - n); if (got <= 0) break; n += (size_t)got; }
    close(s); if (!n) { snprintf(why, room, "the server sent nothing back"); return 0; } resize(reply, n); return reply; }
/* Calls an entry that writes text into a block; the block then holds exactly that text. 0 if the entry said no. */
static uint8_t *made_text(entry5 e, const int16_t *q, int n, size_t room) { uint8_t *b = block(2, room); long long len = e(b, q, n, 0, table); if (len < 0) { free(b); return 0; } resize(b, (size_t)len); return b; }
static uint8_t *file_block(const char *path) { FILE *f = fopen(path, "rb"); if (!f) { fprintf(stderr, "cannot read %s\n", path); exit(3); } fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET); uint8_t *b = block(2, (size_t)n); if (fread(b + 64, 1, (size_t)n, f) != (size_t)n) exit(3); fclose(f); return b; }
/* A prompt to a language model: browse <out dir> --ask <key file> <model> <prompt file> [most tokens]
 * The llm piece writes the request and reads the answer; tls with trust carries it; http takes the reply out of its chunks. */
static int ask(int argc, char **argv, const uint8_t *roots) {
    if (argc < 6) { fprintf(stderr, "browse <pieces out dir> --ask <key file> <model> <prompt file> [most tokens]\n"); return 2; }
    uint8_t *key = file_block(argv[3]), *model = text_block(argv[4], strlen(argv[4])), *prompt = file_block(argv[5]); long long most = argc > 6 ? atoll(argv[6]) : 1024; double started = now_ms();
    size_t kn = length(key); while (kn && (key[64 + kn - 1] == '\n' || key[64 + kn - 1] == '\r' || key[64 + kn - 1] == ' ')) kn--; resize(key, kn);   /* a key file usually ends in a line break */
    at(40, key); at(41, model); at(42, prompt); int16_t q[3] = {40, 41, 42}; uint8_t *request = block(2, length(prompt) * 6 + 2048); long long rn = entry("llm", "request")(request, q, 3, most, table);
    if (rn < 0) { printf("the llm piece would not write that request (key, model name, prompt or token count not acceptable)\n"); return 1; } resize(request, (size_t)rn);
    char why[400] = ""; uint8_t *reply = secure_fetch("api.anthropic.com", 443, request, roots, why, sizeof why); if (!reply) { printf("api.anthropic.com: %s\n", why); return 1; }
    at(43, reply); int16_t qr[1] = {43}; long long status = entry("http", "status")(0, qr, 1, 0, table); uint8_t *body = block(2, length(reply) + 64); long long bn = entry("http", "body")(body, qr, 1, 0, table);
    if (bn < 0) { printf("status %lld; the reply's body could not be read (%zu bytes came)\n", status, length(reply)); return 1; } resize(body, (size_t)bn);
    at(44, body); int16_t qb[1] = {44}; uint8_t *words = block(2, (size_t)bn + 64); long long wn = entry("llm", "text")(words, qb, 1, 0, table), stopped = entry("llm", "stopped")(0, qb, 1, 0, table);
    printf("status %lld, %zu bytes back over a verified secure connection in %.0f ms; the llm piece says: %s; %lld bytes of words\n", status, length(reply), now_ms() - started, stopped == 1 ? "finished" : stopped == 2 ? "the server reported an error" : "not finished", wn);
    if (wn > 0) { fwrite(words + 64, 1, (size_t)wn, stdout); printf("\n"); } else if (stopped != 1) printf("%.*s\n", bn > 300 ? 300 : (int)bn, body + 64);
    return stopped == 1 ? 0 : 1; }
/* Gets what an address leads to: the reply's body, unpacked, as a block (0 with the reason in why). Follows redirects. */
static long long last_status;   /* the status of the reply fetch_body last read */
static char extra_header[512];   /* [by Opus] one header line (with its CRLF) the next fetch adds, or empty */
static uint8_t *fetch_body(const char *where, const uint8_t *roots, char *why, size_t room_why) {
    entry5 resolve = entry("url", "resolve"), part = entry("url", "part"), port_of = entry("url", "port"), request_of = entry("http", "request"), status_of = entry("http", "status"), header = entry("http", "header"), packed_of = entry("http", "packed"), body_of = entry("http", "body"), unpack = entry("inflate", "unpack");
    uint8_t *address = text_block(where, strlen(where)), *reply = 0;
    for (int hop = 0; hop < 6 && !reply; hop++) {
        at(30, address); at(31, address); int16_t q2[2] = {30, 31}; uint8_t *normal = made_text(resolve, q2, 2, length(address) + 64); if (!normal) { snprintf(why, room_why, "not an address we can follow"); return 0; } address = normal; at(30, address);
        int16_t qs[2] = {30, 1}, qc[2] = {30, 0}, q1[1] = {30}; uint8_t *site = made_text(part, qs, 2, 300), *scheme = made_text(part, qc, 2, 16), *request = made_text(request_of, q1, 1, 8192); long long port = port_of(0, q1, 1, 0, table);
        if (!site || !scheme || !request || port <= 0) { snprintf(why, room_why, "not an address we can follow"); return 0; }
        if (extra_header[0] && request) { size_t rl = length(request), en = strlen(extra_header); if (rl >= 4 && !memcmp(request + 64 + rl - 4, "\r\n\r\n", 4)) { uint8_t *r2 = block(2, rl + en); memcpy(r2 + 64, request + 64, rl - 2); memcpy(r2 + 64 + rl - 2, extra_header, en); memcpy(r2 + 64 + rl - 2 + en, "\r\n", 2); resize(r2, rl + en); free(request); request = r2; } }
        char host[300]; size_t hn = length(site); memcpy(host, site + 64, hn); host[hn] = 0; if (host[0] == '[' && hn > 1) { memmove(host, host + 1, hn - 2); host[hn - 2] = 0; }
        int https = length(scheme) == 5 && !memcmp(scheme + 64, "https", 5);
        reply = https ? secure_fetch(host, (int)port, request, roots, why, room_why) : plain_fetch(host, (int)port, request, why, room_why); if (!reply) return 0;
        at(32, reply); int16_t qr[1] = {32}; long long status = status_of(0, qr, 1, 0, table); last_status = status;
        if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) { int16_t ql[9] = {32, 'l', 'o', 'c', 'a', 't', 'i', 'o', 'n'}; uint8_t *to = made_text(header, ql, 9, 4096); if (!to) { snprintf(why, room_why, "a redirect to nowhere"); return 0; }
            at(31, to); int16_t qn[2] = {30, 31}; uint8_t *next = made_text(resolve, qn, 2, 8192); if (!next) { snprintf(why, room_why, "a redirect we cannot follow"); return 0; } address = next; reply = 0; } }
    if (!reply) { snprintf(why, room_why, "too many redirects"); return 0; }
    size_t got = length(reply), room = (got * 4 > 200000 ? got * 4 : 200000) * 6; int16_t qr[1] = {32}; long long packed = packed_of(0, qr, 1, 0, table); uint8_t *body = block(2, room); long long bn = body_of(body, qr, 1, 0, table);
    if (bn < 0) { snprintf(why, room_why, "the reply's body could not be read"); return 0; } resize(body, (size_t)bn);
    if (packed == 1) { at(33, body); int16_t qb[1] = {33}; uint8_t *plain = block(2, room); long long un = unpack(plain, qb, 1, 0, table); if (un < 0) { snprintf(why, room_why, "the packed body could not be unpacked"); return 0; } resize(plain, (size_t)un); body = plain; }
    return body; }
/* --- scripts: the page's <script> elements, each run in one world of our own engine (the script piece), in page order. A script
 * reaches the page through `document`, written in the language over the engine's one way of asking its host: document.write's text
 * takes the script element's place in the page, so it is read like any other part. The host's part: finding the elements, fetching
 * the ones named by src, the clock, and answering what is asked. No tree of the page yet: that is the dom piece, to come. --- */
/* what scripts see as document, window and the rest is written in the language: dom/document.js, kept beside the pieces */
static uint8_t *read_whole(const char *name) { char path[700]; snprintf(path, sizeof path, "%s/%s", dir, name); FILE *f = fopen(path, "rb"); if (!f) return 0; fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    uint8_t *b = block(2, (size_t)n); if (fread(b + 64, 1, (size_t)n, f) != (size_t)n) { fclose(f); free(b); return 0; } fclose(f); return b; }
static int same_word(const uint8_t *p, const uint8_t *end, const char *w) { size_t n = strlen(w); if ((size_t)(end - p) < n) return 0; for (size_t i = 0; i < n; i++) if ((p[i] | 32) != (uint8_t)w[i] && p[i] != (uint8_t)w[i]) return 0; return 1; }
/* an attribute's value inside a tag's text (name="v", name='v', name=v) -> its length, the value at *v; -1 if it is not there */
static long attribute(const uint8_t *tag, const uint8_t *end, const char *name, const uint8_t **v) { size_t n = strlen(name);
    for (const uint8_t *p = tag; p + n < end; p++) { if (!(p[-1] == ' ' || p[-1] == '\n' || p[-1] == '\t' || p[-1] == '\r') || !same_word(p, end, name)) continue; const uint8_t *q = p + n; while (q < end && (*q == ' ' || *q == '\n')) q++;
        if (q >= end || *q != '=') { if (q >= end || *q == ' ' || *q == '>' ) { *v = q; return 0; } continue; } q++; while (q < end && (*q == ' ' || *q == '\n')) q++; if (q >= end) return -1;
        if (*q == '"' || *q == '\'') { const uint8_t *c = memchr(q + 1, *q, (size_t)(end - q - 1)); if (!c) return -1; *v = q + 1; return c - q - 1; }
        const uint8_t *c = q; while (c < end && *c != ' ' && *c != '>' && *c != '\n') c++; *v = q; return c - q; }
    return -1; }
typedef struct { uint8_t *world, *out, *answer, *tree, *req; size_t answer_room, req_room; char title[512]; int dead, full, ran, failed, fetched, modules; const uint8_t *roots; char which[24]; long long zone; } scripts;
/* one request to the page's tree (the dom piece); the answer is in s->answer from byte 64, its length returned (negative: refused) */
static long long tree_ask(scripts *s, const uint8_t *q, size_t n) { if (n > s->req_room) return -2; memcpy(s->req + 64, q, n); resize(s->req, n); resize(s->answer, s->answer_room); at(42, s->req); at(43, s->answer); int16_t h[2] = {42, 43};
    return entry("dom.asm", "ask")(s->tree, h, 2, 0, table); }
static long long tree_askf(scripts *s, const char *what, int node, const char *rest) { char q[200]; int n = snprintf(q, sizeof q, "%s%d%s", what, node, rest); return tree_ask(s, (const uint8_t *)q, (size_t)n); }
/* one script's text through the engine; what it asks about the page goes straight through to the tree */
static void run_script(scripts *s, const uint8_t *text, size_t n, const char *address) {
    entry5 load = entry("script.asm", "load"), run = entry("script.asm", "run"), text_of = entry("script.asm", "text"), error = entry("script.asm", "error");
    uint8_t *swapped = 0; { const char *sw = getenv("TROUGH_SWAP"); if (sw && text) { char path[600]; snprintf(path, sizeof path, "%s/swap-%d.js", sw, s->ran + 1); swapped = access(path, R_OK) ? 0 : file_block(path); if (swapped) { text = swapped + 64; n = length(swapped); fprintf(stderr, "script %d swapped for %s\n", s->ran + 1, path); } } }   /* a changed copy of a script in its place, for finding faults */
    uint8_t *source = text ? text_block((const char *)text, n) : 0; at(41, source); int16_t qs[1] = {41}, qw[2] = {40, 1};   /* no text: the world is only run again (its timers that are due) */
    if (text && load(s->world, qs, 1, 0, table) < 0) { uint8_t *e = made_text(error, qw, 1, 600); fprintf(stderr, "script: %.*s\n", e ? (int)length(e) : 0, e ? (char *)e + 64 : ""); free(e); free(source); s->failed++;
        const char *keep = getenv("TROUGH_KEEP_FAILED"); if (keep) { char path[600]; snprintf(path, sizeof path, "%s/failed-%d.js", keep, s->failed); FILE *f = fopen(path, "wb"); if (f) { fwrite(text, 1, n, f); fclose(f); } }   /* for finding what the engine lacks */
        return; }
    free(source); s->ran++;
    { const char *all = getenv("TROUGH_KEEP_ALL"); if (all && text) { char path[600]; snprintf(path, sizeof path, "%s/ran-%d-t%d.js", all, s->ran, (int)(*(uint64_t *)(s->world + 800) & 255)); FILE *f = fopen(path, "wb"); if (f) { fwrite(text, 1, n, f); fclose(f); } } }   /* every script, for finding where a run-time error really was */
    long long asks = 0;
    for (int turn = 0; turn < 200000; turn++) {
        long long r = run(s->world, 0, 0, 20000000, table), t = text_of(s->out, qw, 1, 0, table); size_t bytes = t < 0 ? 0 : (size_t)(t & 0xffffffff), want = t < 0 ? 0 : (size_t)(t >> 32); const uint8_t *o = s->out + 64;
        size_t said = want ? want - 1 : bytes; if (said) fprintf(stderr, "console: %.*s", (int)said, o);
        if (want) { const uint8_t *q = o + want - 1; size_t qn = bytes - (want - 1); const char *a = ""; size_t an = 0;
            if (qn && q[0] == 'd') { if (++asks < 50000000) turn--;   /* [by Opus] a question to the tree is not a turn of running: big pages ask hundreds of thousands */ long long got = tree_ask(s, q + 1, qn - 1); if (got < 0) { memcpy(s->answer + 64, "\x01" "E", 2); got = 2; } resize(s->answer, (size_t)got); text_of(s->answer, qw, 2, 0, table); continue; }
            else if (qn && q[0] == 'T') { size_t k = qn - 1 < sizeof s->title - 1 ? qn - 1 : sizeof s->title - 1; memcpy(s->title, q + 1, k); s->title[k] = 0; }
            else if (qn && q[0] == 'l') { a = address; an = strlen(a); }
            else if (qn > 1 && (q[0] == 'f' || q[0] == 'M')) {   /* f: the page asks for an address (GET only): "1" and the body, or "0" and why not; 16 a page at most.
                 * M base NEWLINE specifier: a module's text, the specifier resolved against base: "1", the address, a line end, the text; 300 modules at most */
                int mod = q[0] == 'M'; const char *bs = address; size_t bl = strlen(address), ro = 1; char bb[2048];
                if (mod) { const uint8_t *nl = memchr(q + 1, '\n', qn - 1); if (nl && (size_t)(nl - q - 1) < sizeof bb) { bl = (size_t)(nl - q - 1); memcpy(bb, q + 1, bl); bb[bl] = 0; if (bl) bs = bb; else bl = strlen(address); ro = (size_t)(nl - q) + 1; } }
                size_t rn = qn - ro; extra_header[0] = 0; if (!mod) { const uint8_t *nl = memchr(q + ro, '\n', rn); if (nl) { size_t en = qn - (size_t)(nl + 1 - q); if (en > 8 && en < sizeof extra_header - 3 && !memcmp(nl + 1, "accept: ", 8)) { memcpy(extra_header, nl + 1, en); memcpy(extra_header + en, "\r\n", 3); } rn = (size_t)(nl - q) - ro; } }   /* [by Opus] the page's Accept */
                char where[2048] = "", why[300] = ""; uint8_t *base = text_block(bs, bl), *rel = text_block((const char *)q + ro, rn); at(30, base); at(31, rel); int16_t q2[2] = {30, 31};
                uint8_t *full = made_text(entry("url", "resolve"), q2, 2, bl + qn + 64); if (full && length(full) < sizeof where) { memcpy(where, full + 64, length(full)); where[length(full)] = 0; }
                uint8_t *got = 0; if (!where[0]) snprintf(why, sizeof why, "not an address we can follow"); else if (!mod && s->fetched >= 16) snprintf(why, sizeof why, "too many requests from one page"); else if (mod && s->modules >= 300) snprintf(why, sizeof why, "too many modules"); else { if (mod) s->modules++; else s->fetched++; got = fetch_body(where, s->roots, why, sizeof why); }
                char st[2100]; if (mod) snprintf(st, sizeof st, "1%s\n", where); else snprintf(st, sizeof st, "1%03d", (int)(last_status >= 100 && last_status <= 999 ? last_status : 200));
                size_t gn = got ? length(got) : strlen(why), head = got ? strlen(st) : 1; if (gn > s->answer_room - head) gn = s->answer_room - head;
                memcpy(s->answer + 64, got ? st : "0", head); memcpy(s->answer + 64 + head, got ? (const char *)got + 64 : why, gn); gn += head - 1;
                fprintf(stderr, "fetch %s: %s\n", where[0] ? where : "?", got ? "came" : why); free(got); free(base); free(rel); free(full); resize(s->answer, gn + 1); text_of(s->answer, qw, 2, 0, table); continue; }
            memcpy(s->answer + 64, a, an); resize(s->answer, an); text_of(s->answer, qw, 2, 0, table); continue; }
        if (r == 0) return;
        if (r < 0) { uint8_t *e = made_text(error, qw, 1, 600); { const uint8_t *w = s->world; uint64_t tn = *(uint64_t *)(w + 664); if (e && tn > 1) { fprintf(stderr, "script: trail"); for (uint64_t j = 0; j < tn && j < 16; j++) { uint64_t v = *(uint64_t *)(w + 672 + 8 * j); fprintf(stderr, " t%u:%u:%u", (unsigned)(v >> 24 & 255), (unsigned)(v & 0xffffff), (unsigned)(v >> 32)); } fputc('\n', stderr); } }
            if (getenv("TROUGH_BADCALL")) { uint64_t b = *(uint64_t *)(s->world + 824); fprintf(stderr, "badcall at %llu, collections %llu:", (unsigned long long)b, (unsigned long long)*(uint64_t *)(s->world + 648)); if (b) for (int k = 0; k < 12; k++) fprintf(stderr, " %016llx", (unsigned long long)((uint64_t *)(s->world + b))[k]); fprintf(stderr, "\n"); }   /* [by Opus] */
            fprintf(stderr, "script: %.*s%s\n", e ? (int)length(e) : 0, e ? (char *)e + 64 : "", getenv("TROUGH_KEEP_ALL") ? (snprintf(s->which, sizeof s->which, " [ran-%d]", s->ran), s->which) : ""); if (e && memmem(e + 64, length(e), "world is full", 13)) { s->dead = 1; s->full = 1; fprintf(stderr, "script: the page's world is full; its scripts stop here\n"); } free(e); s->failed++;
            const char *keep = getenv("TROUGH_KEEP_FAILED"); if (keep && text) { char path[600]; snprintf(path, sizeof path, "%s/failed-%d.js", keep, s->failed); FILE *f = fopen(path, "wb"); if (f) { fwrite(text, 1, n, f); fclose(f); } }
            return; } }
    fprintf(stderr, "script: stopped after too many steps; no more scripts run on this page\n"); s->dead = 1; s->failed++; }
static uint8_t *fetch_body(const char *where, const uint8_t *roots, char *why, size_t room_why);
/* the page's text with its scripts run. The page is read into a tree (the dom piece); each script element, in page order, runs in one
 * world of our own engine and reaches the tree through `document`; the tree written back out is the page that gets drawn. The same
 * block comes back if there is no script, or the tree or the document object cannot be had. */
static uint8_t *scripts_page(scripts *s, const char *address);
static void scripts_free(scripts *s) { if (!s) return; free(s->world); free(s->out); free(s->answer); free(s->tree); free(s->req); free(s); }
static uint8_t *with_scripts(uint8_t *body, const char *address, const uint8_t *roots, int *ran, int *failed, scripts **keep) {
    const uint8_t *d = body + 64, *end = d + length(body); size_t n = length(body); scripts s; memset(&s, 0, sizeof s); s.roots = roots; *ran = *failed = 0;
    if (end - d > 8 && (!memcmp(d, "\x89PNG", 4) || (d[0] == 0xff && d[1] == 0xd8) || !memcmp(d, "GIF8", 4))) return body;
    int any = 0; for (const uint8_t *p = d; p + 8 < end && !any; p++) if (p[0] == '<' && same_word(p + 1, end, "script")) any = 1; if (!any) return body;
    uint8_t *opening = read_whole("document.js"); if (!opening) { fprintf(stderr, "no document.js beside the pieces: scripts not run\n"); return body; }
    s.answer_room = 6 * n + (2u << 20); s.req_room = n + (1u << 20) + 16; s.tree = block(9, 16 * n + (8u << 20)); s.req = block(2, s.req_room); s.answer = block(2, s.answer_room);
    uint8_t *first = malloc(n + 3); if (!first) exit(4); memcpy(first, "H1 ", 3); memcpy(first + 3, d, n);
    if (entry("dom.asm", "begin")(s.tree, 0, 0, 0, table) < 0 || tree_ask(&s, first, n + 3) < 0) { free(first); free(opening); free(s.tree); free(s.req); free(s.answer); return body; } free(first);
    s.world = block(6, (getenv("TROUGH_WORLD_MB") ? (unsigned)atoi(getenv("TROUGH_WORLD_MB")) : 96u) << 20); s.out = block(2, 1u << 20); at(40, s.world); entry("script.asm", "begin")(s.world, 0, 0, 0, table); { const char *st = getenv("TROUGH_GC_STRESS"); if (st && atol(st) > 0) { uint64_t *w = (uint64_t *)s.world; w[808/8] = (uint64_t)atol(st); w[816/8] = w[216/8]; w[216/8] = w[208/8] + w[808/8] < w[216/8] ? w[208/8] + w[808/8] : w[216/8]; } }   /* [by Opus] collect every N bytes, for finding collector faults */
    struct timeval tv; gettimeofday(&tv, 0); time_t now = tv.tv_sec; struct tm lt; localtime_r(&now, &lt); long long ms = (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
    entry("script.asm", "clock")(s.world, 0, 0, (long long)(((unsigned long long)(uint16_t)(int16_t)(lt.tm_gmtoff / 60) << 48) | ((unsigned long long)ms & 0xffffffffffffull)), table);
    run_script(&s, opening + 64, length(opening), address); free(opening); if (s.failed) s.dead = 1; s.ran = 0;
    /* the script elements are asked for again after each round: a script may have added more (loaders do). When a round finds none new, the page has loaded. */
    int *seen = 0, seen_n = 0, fired = 0, modules = 0;
    int pumps = 0; long long zone = (long long)((unsigned long long)(uint16_t)(int16_t)(lt.tm_gmtoff / 60) << 48);
    for (int round = 0; round < 400 && !s.dead; round++) { long long ln = tree_ask(&s, (const uint8_t *)"q1 script", 9); if (ln < 0) break; char *list = malloc((size_t)ln + 1); if (!list) exit(4); memcpy(list, s.answer + 64, (size_t)ln); list[ln] = 0; int fresh = 0;
        for (char *at_ = list; *at_ && !s.dead && seen_n < 400; ) { int node = (int)strtol(at_, &at_, 10); if (!node) break; int old = 0; for (int i = 0; i < seen_n; i++) if (seen[i] == node) old = 1; if (old) continue;
            long long tn = tree_askf(&s, "g", node, " type"); const char *v = (const char *)s.answer + 65; int module = tn == 7 && same_word((const uint8_t *)v, s.answer + 64 + tn, "module");
            if (module && !modules) continue;   /* modules are deferred: they run after the classic scripts, in document order */
            seen = realloc(seen, (size_t)(seen_n + 1) * sizeof *seen); if (!seen) exit(4); seen[seen_n++] = node; fresh++; tree_askf(&s, "C", node, "");
            int ours = module || tn <= 1 || (tn >= 11 && same_word((const uint8_t *)v + tn - 11, s.answer + 64 + tn, "javascript")); if (!ours) continue;   /* not data */
            long long sn = tree_askf(&s, "g", node, " src") - 1;
            if (sn > 0 && module) { char call[2200]; int k = snprintf(call, sizeof call, "__module(\""); for (long long i = 0; i < sn && k < 2150; i++) { char c = v[i]; if (c == '"' || c == '\\') call[k++] = '\\'; call[k++] = c; } k += snprintf(call + k, sizeof call - k, "\")");
                run_script(&s, (const uint8_t *)call, (size_t)k, address); continue; }
            if (sn > 0) { uint8_t *base = text_block(address, strlen(address)), *rel = text_block(v, (size_t)sn); at(30, base); at(31, rel); int16_t q2[2] = {30, 31}; uint8_t *full = made_text(entry("url", "resolve"), q2, 2, strlen(address) + (size_t)sn + 64);
                char where[2048] = "", why[300] = "", after[64]; if (full && length(full) < sizeof where) { memcpy(where, full + 64, length(full)); where[length(full)] = 0; } uint8_t *got = where[0] ? fetch_body(where, roots, why, sizeof why) : 0;
                if (got) { size_t i = 0, gn = length(got); while (i < gn && got[64 + i] <= ' ') i++; if (i < gn && got[64 + i] == '<') { free(got); got = 0; snprintf(why, sizeof why, "a page came back, not a script"); } }   /* an error page is not a program */
                if (got) { run_script(&s, got + 64, length(got), address); free(got); } else { fprintf(stderr, "script %.*s: %s\n", (int)length(rel), rel + 64, why[0] ? why : "not an address we can follow"); s.failed++; } free(base); free(rel); free(full);
                if (!s.dead) { int kept = s.ran, bad = s.failed; int k = snprintf(after, sizeof after, "__loaded(%d,%d)", node, got ? 1 : 0); run_script(&s, (const uint8_t *)after, (size_t)k, address); s.ran = kept; s.failed = bad; } }
            else { long long tx = tree_askf(&s, "t", node, ""); if (tx > 0) { uint8_t *copy = malloc((size_t)tx); if (!copy) exit(4); memcpy(copy, s.answer + 64, (size_t)tx); run_script(&s, copy, (size_t)tx, address); free(copy); } } }
        free(list); if (fresh) continue; if (!modules) { modules = 1; continue; }
        if (fired) {   /* the page is loaded: its timers run, each at its own time (the clock is moved to it, three seconds ahead at most), and what they add is run above */
            long long wake = entry("script.asm", "clock")(s.world, 0, 0, 0, table); if (wake < 0 || wake > ms + 3000 || pumps++ >= 300) break;
            entry("script.asm", "clock")(s.world, 0, 0, zone | (wake & 0xffffffffffffll), table); int kept = s.ran; run_script(&s, 0, 0, address); s.ran = kept; continue; }
        fired = 1; tree_ask(&s, (const uint8_t *)"C0", 2); int before = s.ran; if (!s.dead) run_script(&s, (const uint8_t *)"__fire()", 8, address); s.ran = before; }
    free(seen);
    long long pn = tree_ask(&s, (const uint8_t *)"h1", 2); uint8_t *fresh = body; if (pn >= 0) { fresh = text_block((const char *)s.answer + 64, (size_t)pn); free(body); }
    *ran = s.ran; *failed = s.failed; if (keep && !s.dead) { *keep = malloc(sizeof s); if (*keep) { **keep = s; (*keep)->zone = zone; uint8_t *m = scripts_page(*keep, address); if (m) { free(fresh); fresh = m; } return fresh; } }
    free(s.world); free(s.out); free(s.answer); free(s.tree); free(s.req); return fresh; }
/* the page as drawn: elements the page listens to for clicks hold a link "trough-node:N" around their content (only in this copy) */
static uint8_t *scripts_page(scripts *s, const char *address) {
    int kept = s->ran, bad = s->failed; run_script(s, (const uint8_t *)"__mark(1)", 9, address); long long pn = tree_ask(s, (const uint8_t *)"h1", 2);
    uint8_t *t = pn < 0 ? 0 : text_block((const char *)s->answer + 64, (size_t)pn); run_script(s, (const uint8_t *)"__mark(0)", 9, address); s->ran = kept; s->failed = bad; if (!t) return 0;
    const char *mk = "data-trough-click=\""; size_t mn = strlen(mk), n = length(t); const char *d = (const char *)t + 64; char *o = malloc(2 * n + 64); if (!o) exit(4); size_t on = 0, i = 0; int found = 0;
    char *closers[64]; size_t close_at[64]; int cn = 0;   /* where each mark's </a> goes, found ahead by counting the same tag */
    for (; i < n; i++) {
        for (int c = 0; c < cn; c++) if (close_at[c] == i) { memcpy(o + on, "</a>", 4); on += 4; }
        o[on++] = d[i];
        if (d[i] == '>' ) { size_t b = i; while (b > 0 && d[b] != '<') b--; const char *m = memmem(d + b, i - b, mk, mn);
            if (m && cn < 64 && d[b + 1] != '/') { int node = atoi(m + mn); size_t tl = 0; while (b + 1 + tl < i && d[b + 1 + tl] > ' ' && d[b + 1 + tl] != '>') tl++;
                int depth = 1; size_t j = i + 1; for (; j + tl + 2 < n; j++) if (d[j] == '<') { if (d[j + 1] == '/' && !strncasecmp(d + j + 2, d + b + 1, tl) && !isalnum((unsigned char)d[j + 2 + tl])) { if (!--depth) break; } else if (!strncasecmp(d + j + 1, d + b + 1, tl) && !isalnum((unsigned char)d[j + 1 + tl])) depth++; }
                if (j + tl + 2 < n) { on += (size_t)sprintf(o + on, "<a href=\"trough-node:%d\">", node); close_at[cn] = j; closers[cn++] = 0; found++; } } } }
    (void)closers; uint8_t *r = text_block(o, on); free(o); free(t);
    { const char *keep = getenv("TROUGH_KEEP_PAGE"); if (keep) { FILE *f = fopen(keep, "wb"); if (f) { fwrite(r + 64, 1, length(r), f); fclose(f); } fprintf(stderr, "drawn page: %d clickable\n", found); } }
    return r; }
/* the live screen's page world: its timers that are due by the real clock are run; a fresh page text if the tree changed, else 0 */
static uint8_t *scripts_tick(scripts *s, const char *address, int force) {
    if (!s || s->dead) return 0; struct timeval tv; gettimeofday(&tv, 0); long long ms = (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
    long long wake = entry("script.asm", "clock")(s->world, 0, 0, 0, table); int due = wake >= 0 && wake <= ms; if (!due && !force) return 0;
    if (due) { entry("script.asm", "clock")(s->world, 0, 0, s->zone | (ms & 0xffffffffffffll), table); tree_ask(s, (const uint8_t *)"C0", 2); int kept = s->ran; run_script(s, 0, 0, address); s->ran = kept; }
    return scripts_page(s, address); }
/* The live screen: browse <out dir> --serve <picture file> <events file> <width> <height> [address]
 * The picture file is a surface as the pieces know it (64-byte head, then the dots) that the app maps and shows; bytes 24-31 of
 * the head are a counter this host raises after every redraw. The events file gets one line per event from the app:
 * "d x y" finger down, "m x y" moved, "u" lifted, "o address" open that address. A drag scrolls. */
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
typedef struct { uint32_t x, y, w, h; char src[1024]; int state; uint8_t *ready; } pic;   /* state: 0 to fetch, 1 ready, 2 could not be shown */
/* One picture of the page: fetched, decoded by our own piece for its kind, and scaled by the image piece to the room the page gave it. */
static int get_picture(pic *p, const char *page_address, const uint8_t *roots) {
    char why[200] = ""; uint8_t *base = text_block(page_address, strlen(page_address)), *ref = text_block(p->src, strlen(p->src)); at(30, base); at(31, ref); int16_t qn[2] = {30, 31}; uint8_t *where = made_text(entry("url", "resolve"), qn, 2, 8192); if (!where) return 0;
    char address[2048]; if (length(where) >= sizeof address) return 0; memcpy(address, where + 64, length(where)); address[length(where)] = 0;
    uint8_t *body = fetch_body(address, roots, why, sizeof why); if (!body) return 0; size_t bn = length(body); const uint8_t *d = body + 64;
    const char *kind = bn > 8 && !memcmp(d, "\x89PNG\r\n\x1a\n", 8) ? "png" : bn > 2 && d[0] == 0xff && d[1] == 0xd8 ? "jpeg" : bn > 4 && !memcmp(d, "GIF8", 4) ? "gif" : 0; if (!kind) { free(body); return 0; }
    at(36, body); int16_t qp[3] = {36, 38, 0}; long long wh = entry(kind, "size")(0, qp, 1, 0, table); if (wh < 0) { free(body); return 0; } uint32_t iw = (uint32_t)(wh >> 16), ih = (uint32_t)(wh & 65535); if ((uint64_t)iw * ih > 6000000) { free(body); return 0; }
    uint8_t *whole = surface(1, iw, ih, 4), *scratch = block(5, 64 + 24ull * iw * ih + 8ull * ih + 70000 + 20480); at(37, whole); at(38, scratch);
    long long ok = entry(kind, "decode")(whole, qp, !strcmp(kind, "gif") ? 3 : 2, 0, table); free(scratch); free(body); if (ok < 0) { free(whole); return 0; }
    p->ready = surface(1, p->w, p->h, 4); entry("paint", "clear")(p->ready, 0, 0, 0xffffffffll, table); int16_t qi[5] = {37, 0, 0, (int16_t)p->w, (int16_t)p->h}; entry("image", iw > p->w ? "smooth" : iw < p->w ? "stretch" : "blit")(p->ready, qi, iw == p->w && ih == p->h ? 3 : 5, 0, table); free(whole); return 1; }
/* A page's pictures are fetched by a thread of their own, one after another, so touches are never kept waiting. The thread has its
 * own handles (the table is per thread) and the same sockets. When the page is left, whoever lets go last frees the job. */
typedef struct { pic p[32]; int n; char address[2048]; const uint8_t *roots; volatile int cancel; int owner; } job;
static void job_free(job *j) { for (int i = 0; i < j->n; i++) free(j->p[i].ready); free(j); }
static void *picture_worker(void *arg) { job *j = arg; memcpy(table, sockets, sizeof sockets);
    for (int i = 0; i < j->n && !j->cancel; i++) { pic got = j->p[i]; int ok = get_picture(&got, j->address, j->roots); j->p[i].ready = got.ready; __atomic_store_n(&j->p[i].state, ok ? 1 : 2, __ATOMIC_SEQ_CST); }
    if (__atomic_exchange_n(&j->owner, 2, __ATOMIC_SEQ_CST) == 1) job_free(j); return 0; }
static void job_leave(job *j) { if (!j) return; j->cancel = 1; if (__atomic_exchange_n(&j->owner, 1, __ATOMIC_SEQ_CST) == 2) job_free(j); }
static int serve(int argc, char **argv, const uint8_t *roots, uint8_t *font) {
    if (argc < 7) { fprintf(stderr, "browse <pieces out dir> --serve <picture file> <events file> <width> <height> [address]\n"); return 2; }
    uint32_t W = (uint32_t)atoi(argv[5]), H = (uint32_t)atoi(argv[6]); if (W < 16 || H < 16 || W > 4096 || H > 4096) return 2; size_t bytes = 64 + 4ull * W * H;
    int fd = open(argv[3], O_RDWR | O_CREAT, 0600); if (fd < 0 || ftruncate(fd, (off_t)bytes)) { fprintf(stderr, "cannot make the picture file\n"); return 1; }
    uint8_t *screen = mmap(0, bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0); if (screen == MAP_FAILED) return 1; uint64_t z = bytes, counter = 0; uint32_t head[4] = {1, W, H, 4 * W}; memset(screen, 0, 64); memcpy(screen, head, 16); memcpy(screen + 16, &z, 8);
    FILE *ev = fopen(argv[4], "a+"); if (!ev) return 1; fseek(ev, 0, SEEK_END); long read_to = ftell(ev);
    char why[400] = "", address[2048]; snprintf(address, sizeof address, "%s", argc > 7 ? argv[7] : "https://example.com/"); uint8_t *body = 0; long long tall = 0, scroll = 0; int size_px = 17, dirty = 1, fresh = 1, down = 0, last_y = 0, down_x = 0, down_y = 0, moved = 0, depth = 0, editing = 0; char typed[512] = ""; enum { BAR = 44 }; static char before[16][2048]; entry5 rect = entry("paint", "fill_rect"), words = entry("font", "draw"); enum { TILE = 1024, KEPT = 24, PICS = 32 }; job *now = 0; scripts *live = 0; double ticked = 0, refilled = -1e9; int tapped = 0; static int applied[PICS]; pic *pics = 0; int pic_n = 0;
    { const char *need[][2] = {{"url","resolve"},{"url","part"},{"url","port"},{"http","request"},{"http","status"},{"http","header"},{"http","packed"},{"http","body"},{"inflate","unpack"},{"tls","feed"},{"png","decode"},{"jpeg","decode"},{"gif","decode"},{"image","blit"},{"image","smooth"},{"image","stretch"},{"paint","clear"},{"page","pictures"},{"page","link"}}; for (size_t i = 0; i < sizeof need / sizeof need[0]; i++) entry(need[i][0], need[i][1]); }   /* every piece is loaded before a second thread exists */ static uint8_t *strip[KEPT]; static long long strip_at[KEPT]; static unsigned long strip_used[KEPT], tick; for (int i = 0; i < KEPT; i++) strip_at[i] = -1; entry5 render = entry("page", "render"), clear = entry("paint", "clear");
    for (;;) {
        if (fresh) { fresh = 0; for (int i = 0; i < KEPT; i++) strip_at[i] = -1; double t = now_ms(); body = fetch_body(address, roots, why, sizeof why); if (body) { int ran, failed; scripts_free(live); live = 0; body = with_scripts(body, address, roots, &ran, &failed, &live); } scroll = 0; dirty = 1; printf("%s: %s (%.0f ms)\n", address, body ? "open" : why, now_ms() - t); fflush(stdout);
            job_leave(now); now = 0; pics = 0; pic_n = 0; memset(applied, 0, sizeof applied);
            if (body) { at(34, body); at(35, font); uint8_t *list = block(2, 65536); int16_t qq[4] = {34, 35, (int16_t)size_px, (int16_t)W}; long long ln = entry("page", "pictures")(list, qq, 4, 0, table);
                now = calloc(1, sizeof *now); pics = now->p; snprintf(now->address, sizeof now->address, "%s", address); now->roots = roots;
                for (long long o = 0; o + 20 <= ln && pic_n < PICS; ) { uint32_t f[5]; memcpy(f, list + 64 + o, 20); if (f[4] < sizeof pics[0].src && f[2] && f[3]) { pic *p = &pics[pic_n++]; p->x = f[0]; p->y = f[1]; p->w = f[2]; p->h = f[3]; size_t k = 0; for (uint32_t i = 0; i < f[4]; i++) { char c = (char)list[64 + o + 20 + i]; p->src[k++] = c; if (c == '&' && i + 4 < f[4] && !memcmp(list + 64 + o + 21 + i, "amp;", 4)) i += 4; } p->src[k] = 0; p->state = 0; p->ready = 0; } o += 20 + ((f[4] + 3) & ~3u); }
                free(list); now->n = pic_n; printf("%d pictures to fetch\n", pic_n); fflush(stdout); pthread_t th; if (pic_n && !pthread_create(&th, 0, picture_worker, now)) pthread_detach(th); else { free(now); now = 0; pics = 0; pic_n = 0; } }
            if (!body) { char sorry[600]; int n = snprintf(sorry, sizeof sorry, "<h2>This page could not be opened</h2><p>%s</p><p>%s</p>", address, why); body = text_block(sorry, (size_t)n); } }
        /* a page world that filled up is started again (at most once a minute): its scripts stopping froze the live screen for an hour (2026-11-13) */
        if (live && live->full && now_ms() - refilled > 60000) { refilled = now_ms(); fresh = 1; fprintf(stderr, "the page's world filled up: opening the page again\n"); continue; }
        if (live && body && now_ms() - ticked > 200) { ticked = now_ms(); uint8_t *changed = scripts_tick(live, address, tapped); tapped = 0;   /* the page keeps running: timers on the real clock */
            if (changed && (length(changed) != length(body) || memcmp(changed + 64, body + 64, length(body)))) { free(body); body = changed; for (int i = 0; i < KEPT; i++) strip_at[i] = -1; dirty = 1; printf("the page changed itself\n"); fflush(stdout); } else free(changed); }
        if (dirty) { dirty = 0; int drawn = 0; double t = now_ms(); at(34, body); at(35, font); memcpy(&counter, screen + 24, 8); { /* the page shows from row (scroll - BAR) of its own height; each strip of TILE rows is drawn by the pieces once and kept */
              long long first = scroll - BAR; size_t rowbytes = 4 * (size_t)W;
              for (uint32_t y = 0; y < H; ) { long long row = first + y; uint32_t run;
                  if (row < 0) { run = (uint32_t)(-row) < H - y ? (uint32_t)(-row) : H - y; memset(screen + 64 + y * rowbytes, 255, run * rowbytes); y += run; continue; }
                  long long which = row / TILE; int found = -1, oldest = 0; for (int i = 0; i < KEPT; i++) { if (strip_at[i] == which) found = i; if (strip_used[i] < strip_used[oldest]) oldest = i; }
                  if (found < 0) { found = oldest; if (!strip[found]) strip[found] = surface(1, W, TILE, 4); strip_at[found] = which; clear(strip[found], 0, 0, 0xffffffffll, table); int16_t q[4] = {34, 35, (int16_t)size_px, (int16_t)(which * TILE > 32000 ? 32000 : which * TILE)}; tall = render(strip[found], q, 4, 0, table); drawn++;
                      for (int i = 0; i < pic_n; i++) if (pics[i].state == 1 && (long long)pics[i].y < (which + 1) * TILE && (long long)pics[i].y + pics[i].h > which * TILE) { at(39, pics[i].ready); int16_t qb[3] = {39, (int16_t)pics[i].x, (int16_t)((long long)pics[i].y - which * TILE)}; entry("image", "blit")(strip[found], qb, 3, 0, table); } }
                  strip_used[found] = ++tick; uint32_t in = (uint32_t)(row - which * TILE); run = TILE - in < H - y ? TILE - in : H - y; memcpy(screen + 64 + y * rowbytes, strip[found] + 64 + in * rowbytes, run * rowbytes); y += run; } }
            { /* the bar across the top, drawn by the paint and font pieces: a back arrow when there is somewhere to go back to, and the address */
              int16_t r[4] = {0, 0, (int16_t)W, BAR}; rect(screen, r, 4, 0xffe8ecf0ll, table); int16_t l[4] = {0, BAR - 1, (int16_t)W, 1}; rect(screen, l, 4, 0xffc0c8d0ll, table);
              int16_t t[160] = {35, 18, 12, 30, '<'}; if (depth) words(screen, t, 5, 0xff202020ll, table);
              int n = 4, room_chars = (int)(W - 60) / 9; char line_now[600]; const char *shown = address; if (!strncmp(shown, "https://", 8)) shown += 8; if (editing) { snprintf(line_now, sizeof line_now, "%s|", typed); shown = line_now; int over = (int)strlen(shown) - room_chars; if (over > 0) shown += over; } t[1] = 15; t[2] = 48; t[3] = 28; for (int i = 0; shown[i] && i < room_chars && n < 150; i++) t[n++] = (int16_t)(unsigned char)shown[i]; words(screen, t, n, editing ? 0xff101010ll : 0xff505860ll, table); screen[32] = (uint8_t)editing; }   /* byte 32 of the head: the host wants the keyboard */
            counter++; memcpy(screen + 24, &counter, 8); if (drawn || now_ms() - t > 8) { printf("shown at %lld of %lld in %.1f ms (%d strips drawn by the pieces)\n", scroll, tall, now_ms() - t, drawn); fflush(stdout); } }
        struct stat st; if (fstat(fileno(ev), &st) == 0 && st.st_size > read_to) { fseek(ev, read_to, SEEK_SET); char line[2100];
            while (fgets(line, sizeof line, ev)) { size_t n = strlen(line); if (!n || line[n - 1] != '\n') break; read_to += (long)n; line[n - 1] = 0; int x, y;
                if (line[0] == 'd' && sscanf(line + 1, "%d %d", &x, &y) == 2) { down = 1; last_y = y; down_x = x; down_y = y; moved = 0; }
                else if (line[0] == 'm' && down && sscanf(line + 1, "%d %d", &x, &y) == 2) { moved += abs(y - last_y) + abs(x - down_x) / 4; long long limit = tall + BAR > (long long)H ? tall + BAR - H : 0, to = scroll - (y - last_y); if (to < 0) to = 0; if (to > limit) to = limit; last_y = y; if (to != scroll) { scroll = to; dirty = 1; } }
                else if (line[0] == 'u') { if (down && moved < 12 && down_y < BAR) { if (down_x < 64 && depth) { snprintf(address, sizeof address, "%s", before[--depth]); fresh = 1; printf("back to %s\n", address); fflush(stdout); } else if (down_x >= 64) { editing = !editing; typed[0] = 0; dirty = 1; } }
                    else if (down && moved < 12) {   /* a tap: is there a link under it? The page piece says; the url piece works out where it leads */
                        at(34, body); at(35, font); int16_t ql[8] = {34, 35, (int16_t)size_px, (int16_t)((scroll > 32000 ? 32000 : scroll) - BAR), (int16_t)down_x, (int16_t)down_y, (int16_t)W, (int16_t)H}; uint8_t *href = block(2, 4096); long long hn = entry("page", "link")(href, ql, 8, 0, table);
                        if (live && hn > 12 && !memcmp(href + 64, "trough-node:", 12)) { char c[48]; int k = snprintf(c, sizeof c, "__tap(%d)", atoi((const char *)href + 76)); int kept = live->ran; run_script(live, (const uint8_t *)c, (size_t)k, address); live->ran = kept; tapped = 1; ticked = 0; printf("tap at %d %d: the page's own click (%s)\n", down_x, down_y, c); hn = -1; }
                        if (hn > 0) { { /* an address written in a page spells & as &amp; (to become the page piece's job) */ size_t o = 0; for (long long i = 0; i < hn; i++) { href[64 + o++] = href[64 + i]; if (href[64 + i] == '&' && i + 4 < hn && !memcmp(href + 64 + i + 1, "amp;", 4)) i += 4; } hn = (long long)o; } resize(href, (size_t)hn); uint8_t *base = text_block(address, strlen(address)); at(30, base); at(31, href); int16_t qn[2] = {30, 31}; uint8_t *next = made_text(entry("url", "resolve"), qn, 2, 8192);
                            if (next && length(next) < sizeof address) { if (depth == 16) { memmove(before[0], before[1], 15 * sizeof before[0]); depth = 15; } snprintf(before[depth++], sizeof before[0], "%s", address); memcpy(address, next + 64, length(next)); address[length(next)] = 0; fresh = 1; printf("tap at %d %d: link to %s\n", down_x, down_y, address); } else printf("tap at %d %d: a link the address piece cannot follow\n", down_x, down_y); }
                        else if (hn != -1) printf("tap at %d %d: no link there\n", down_x, down_y); fflush(stdout); } down = 0; }
                else if (line[0] == 'o' && line[1] == ' ') { if (depth == 16) { memmove(before[0], before[1], 15 * sizeof before[0]); depth = 15; } snprintf(before[depth++], sizeof before[0], "%s", address); snprintf(address, sizeof address, "%s", line + 2); fresh = 1; }
                else if (line[0] == 'g' && sscanf(line + 1, "%d", &y) == 1) { long long limit = tall + BAR > (long long)H ? tall + BAR - H : 0; scroll = y < 0 ? 0 : y > limit ? limit : y; dirty = 1; }   /* go to that row of the page */
                else if (line[0] == 'k' && sscanf(line + 1, "%d", &x) == 1) {   /* a key: typed into the line. Enter opens an address, or searches for anything else */
                    size_t n = strlen(typed); if (!editing) { editing = 1; n = 0; typed[0] = 0; }
                    if (x == 8) { if (n) typed[n - 1] = 0; }
                    else if (x == 10 || x == 13) { editing = 0; while (n && typed[n - 1] == ' ') typed[--n] = 0;
                        if (n) { int is_address = !strchr(typed, ' ') && (strchr(typed, '.') || !strncmp(typed, "http", 4)); char to[2048];
                            if (is_address) snprintf(to, sizeof to, "%s%s", strstr(typed, "://") ? "" : "https://", typed);
                            else { size_t o = (size_t)snprintf(to, sizeof to, "https://html.duckduckgo.com/html/?q="); for (size_t i = 0; i < n && o + 4 < sizeof to; i++) { unsigned char c = (unsigned char)typed[i]; if ((c >= '0' && c <= '9') || ((c | 32) >= 'a' && (c | 32) <= 'z') || c == '-' || c == '.' || c == '_') to[o++] = (char)c; else if (c == ' ') to[o++] = '+'; else o += (size_t)snprintf(to + o, 4, "%%%02X", c); } to[o] = 0; }
                            if (depth == 16) { memmove(before[0], before[1], 15 * sizeof before[0]); depth = 15; } snprintf(before[depth++], sizeof before[0], "%s", address); snprintf(address, sizeof address, "%s", to); fresh = 1; printf("typed: %s -> %s\n", typed, address); fflush(stdout); } }
                    else if (x >= 32 && x < 127 && n + 1 < sizeof typed) { typed[n] = (char)x; typed[n + 1] = 0; }
                    dirty = 1; }
                else if (line[0] == 'q') return 0; } }
        else if (st.st_size < read_to) read_to = 0;
        for (int i = 0; i < pic_n; i++) if (!applied[i] && __atomic_load_n(&pics[i].state, __ATOMIC_SEQ_CST)) { applied[i] = 1;   /* a picture has arrived (or failed): the strips it sits in are drawn again */
            if (pics[i].state == 1) { for (int k = 0; k < KEPT; k++) if (strip_at[k] >= 0 && (long long)pics[i].y < (strip_at[k] + 1) * TILE && (long long)pics[i].y + pics[i].h > strip_at[k] * TILE) strip_at[k] = -1; dirty = 1; } }
        if (!dirty && !fresh) usleep(4000); } }
int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "browse <pieces out dir> <address> <out.png> [text size] [scroll] [width] [height]\n   or: browse <pieces out dir> --ask <key file> <model> <prompt file> [most tokens]\n"); return 2; }
    dir = argv[1]; int size_px = argc > 4 ? atoi(argv[4]) : 26, scroll = argc > 5 ? atoi(argv[5]) : 0; uint32_t W = argc > 6 ? (uint32_t)atoi(argv[6]) : 720, H = argc > 7 ? (uint32_t)atoi(argv[7]) : 1280; double started = now_ms();
    char path[600]; snprintf(path, sizeof path, "%s/../slots.txt", dir); FILE *f = fopen(path, "r"); if (!f) { fprintf(stderr, "no slots.txt\n"); return 3; }
    char line[256]; while (fgets(line, sizeof line, f)) { int slot; char name[64], en[64]; if (line[0] == '#' || sscanf(line, "%d %63s %63s", &slot, name, en) != 3) continue; if (slot >= 0 && slot < 256) table[slot] = piece_entry(get(name), en); } fclose(f); memcpy(sockets, table, sizeof sockets);
    snprintf(path, sizeof path, "%s/android-roots.der", dir); uint8_t *roots = file_block(path); if (argc > 2 && !strcmp(argv[2], "--ask")) return ask(argc, argv, roots); if (argc > 2 && !strcmp(argv[2], "--serve")) { snprintf(path, sizeof path, "%s/font.fixture", dir); return serve(argc, argv, roots, file_block(path)); } snprintf(path, sizeof path, "%s/font.fixture", dir); uint8_t *font = file_block(path);
    entry5 resolve = entry("url", "resolve"), part = entry("url", "part"), port_of = entry("url", "port"), request_of = entry("http", "request"), status_of = entry("http", "status"), header = entry("http", "header"), packed_of = entry("http", "packed"), body_of = entry("http", "body"), unpack = entry("inflate", "unpack");
    uint8_t *address = text_block(argv[2], strlen(argv[2])), *reply = 0; char why[400] = ""; const char *secure = ""; long long status = -1;
    for (int hop = 0; hop < 6; hop++) {
        at(30, address); at(31, address); int16_t q2[2] = {30, 31}; uint8_t *normal = made_text(resolve, q2, 2, length(address) + 64); if (!normal) { snprintf(why, sizeof why, "not an address we can follow"); break; } address = normal; at(30, address);
        int16_t qs[2] = {30, 1}, qc[2] = {30, 0}, q1[1] = {30}; uint8_t *site = made_text(part, qs, 2, 300), *scheme = made_text(part, qc, 2, 16), *request = made_text(request_of, q1, 1, 8192); long long port = port_of(0, q1, 1, 0, table);
        if (!site || !scheme || !request || port <= 0) { snprintf(why, sizeof why, "not an address we can follow"); break; }
        char host[300]; size_t hn = length(site); memcpy(host, site + 64, hn); host[hn] = 0; if (host[0] == '[' && hn > 1) { memmove(host, host + 1, hn - 2); host[hn - 2] = 0; }
        int https = length(scheme) == 5 && !memcmp(scheme + 64, "https", 5); secure = https ? "verified secure connection" : "plain connection";
        reply = https ? secure_fetch(host, (int)port, request, roots, why, sizeof why) : plain_fetch(host, (int)port, request, why, sizeof why); if (!reply) break;
        at(32, reply); int16_t qr[1] = {32}; status = status_of(0, qr, 1, 0, table);
        if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) { int16_t ql[9] = {32, 'l', 'o', 'c', 'a', 't', 'i', 'o', 'n'}; uint8_t *where = made_text(header, ql, 9, 4096); if (!where) break;
            at(31, where); int16_t qn[2] = {30, 31}; uint8_t *next = made_text(resolve, qn, 2, 8192); if (!next) break; address = next; reply = 0; continue; }
        break; }
    if (!reply) { printf("%.*s: %s\n", (int)length(address), address + 64, why[0] ? why : "too many redirects"); return 1; }
    size_t got = length(reply), room = (got * 4 > 200000 ? got * 4 : 200000) * 6; int16_t qr[1] = {32}; long long packed = packed_of(0, qr, 1, 0, table); uint8_t *body = block(2, room); long long bn = body_of(body, qr, 1, 0, table);
    if (bn < 0) { printf("%.*s -> %lld, %zu bytes, %s; the reply's body could not be read\n", (int)length(address), address + 64, status, got, secure); return 1; } resize(body, (size_t)bn);
    if (packed == 1) { at(33, body); int16_t qb[1] = {33}; uint8_t *plain = block(2, room); long long un = unpack(plain, qb, 1, 0, table); if (un < 0) { printf("the packed body could not be unpacked\n"); return 1; } resize(plain, (size_t)un); body = plain; bn = un; }
    int ran = 0, failed = 0; { char where[2048]; snprintf(where, sizeof where, "%.*s", (int)length(address), address + 64); const char *tk = getenv("TROUGH_TICKS"); scripts *kept = 0; body = with_scripts(body, where, roots, &ran, &failed, tk ? &kept : 0); bn = (long long)length(body);
        if (tk && kept) { int n = atoi(tk); for (int i = 0; i <= n; i++) { if (i % 25 == 0) { fprintf(stderr, "[%.0f ms] ", now_ms()); const uint8_t *w = kept->world; int fc; fprintf(stderr, "tick %d: free %llu in %d, gcs %llu, heap %llu of %llu, code %llu of %llu, dead %d\n", i, free_total(w, &fc), fc, (unsigned long long)*(uint64_t *)(w + 648), (unsigned long long)*(uint64_t *)(w + 208), (unsigned long long)*(uint64_t *)(w + 216), (unsigned long long)*(uint64_t *)(w + 80), (unsigned long long)*(uint64_t *)(w + 88), kept->dead); if (i == 0) { fprintf(stderr, "  heap0 %llu\n", (unsigned long long)*(uint64_t *)(w + 600)); held_sizes(w); } }
            if (i < n) { usleep(200000); uint8_t *t = scripts_tick(kept, where, i % 5 == 0); free(t); } } } }
    at(34, body); at(35, font); const uint8_t *d = body + 64; const char *kind = bn > 8 && !memcmp(d, "\x89PNG\r\n\x1a\n", 8) ? "png" : bn > 2 && d[0] == 0xff && d[1] == 0xd8 ? "jpeg" : bn > 4 && !memcmp(d, "GIF8", 4) ? "gif" : 0;
    uint8_t *screen; long long answer;
    if (kind) {   /* a picture rather than a page: our own decoder for its kind, then the image piece fits it to the screen's width */
        int16_t qp[3] = {34, 37, 0}; long long wh = entry(kind, "size")(0, qp, 1, 0, table); if (wh < 0) { printf("a %s our decoder cannot read\n", kind); return 1; } uint32_t iw = (uint32_t)(wh >> 16), ih = (uint32_t)(wh & 65535);
        uint8_t *picture = surface(1, iw, ih, 4), *scratch = block(5, 64 + 24ull * iw * ih + 8ull * ih + 70000 + 20480); at(36, picture); at(37, scratch);
        answer = entry(kind, "decode")(picture, qp, !strcmp(kind, "gif") ? 3 : 2, 0, table); if (answer < 0) { printf("a %s our decoder cannot read\n", kind); return 1; }
        uint32_t w2 = iw > W ? W : iw, h2 = iw > W ? (uint32_t)((uint64_t)ih * W / iw) : ih; if (h2 < 1) h2 = 1; if (h2 > 4096) h2 = 4096; W = w2; H = h2; screen = surface(1, W, H, 4);
        entry("paint", "clear")(screen, 0, 0, 0xffffffffll, table); int16_t qi[5] = {36, 0, 0, (int16_t)W, (int16_t)H}; entry("image", iw > W ? "smooth" : "blit")(screen, qi, 5, 0, table);
        printf("%.*s -> %lld, %zu bytes, %s; %s picture %u x %u decoded by our own piece; %.0f ms in all\n", (int)length(address), address + 64, status, got, secure, kind, iw, ih, now_ms() - started); }
    else { screen = surface(1, W, H, 4); entry("paint", "clear")(screen, 0, 0, 0xffffffffll, table); int16_t qg[4] = {34, 35, (int16_t)size_px, (int16_t)scroll}; answer = entry("page", "render")(screen, qg, 4, 0, table);
        printf("%.*s -> %lld, %zu bytes, %s; body %lld bytes%s; %d scripts run, %d failed; page is %lld dots tall; %.0f ms in all\n", (int)length(address), address + 64, status, got, secure, bn, packed == 1 ? " after unpacking" : "", ran, failed, answer, now_ms() - started); }
    if (!write_png(argv[3], screen + 64, W, H)) { printf("could not write %s\n", argv[3]); return 1; }
    return 0; }
