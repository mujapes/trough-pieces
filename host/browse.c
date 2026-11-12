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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
typedef long long (*entry5)(void *, const int16_t *, long long, long long, void *const *);
static void *table[512]; static piece loaded[64]; static char stems[64][256]; static int count; static const char *dir;
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
int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "browse <pieces out dir> <address> <out.png> [text size] [scroll] [width] [height]\n"); return 2; }
    dir = argv[1]; int size_px = argc > 4 ? atoi(argv[4]) : 26, scroll = argc > 5 ? atoi(argv[5]) : 0; uint32_t W = argc > 6 ? (uint32_t)atoi(argv[6]) : 720, H = argc > 7 ? (uint32_t)atoi(argv[7]) : 1280; double started = now_ms();
    char path[600]; snprintf(path, sizeof path, "%s/../slots.txt", dir); FILE *f = fopen(path, "r"); if (!f) { fprintf(stderr, "no slots.txt\n"); return 3; }
    char line[256]; while (fgets(line, sizeof line, f)) { int slot; char name[64], en[64]; if (line[0] == '#' || sscanf(line, "%d %63s %63s", &slot, name, en) != 3) continue; if (slot >= 0 && slot < 256) table[slot] = piece_entry(get(name), en); } fclose(f);
    snprintf(path, sizeof path, "%s/android-roots.der", dir); uint8_t *roots = file_block(path); snprintf(path, sizeof path, "%s/font.fixture", dir); uint8_t *font = file_block(path);
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
        printf("%.*s -> %lld, %zu bytes, %s; body %lld bytes%s; page is %lld dots tall; %.0f ms in all\n", (int)length(address), address + 64, status, got, secure, bn, packed == 1 ? " after unpacking" : "", answer, now_ms() - started); }
    if (!write_png(argv[3], screen + 64, W, H)) { printf("could not write %s\n", argv[3]); return 1; }
    return 0; }
