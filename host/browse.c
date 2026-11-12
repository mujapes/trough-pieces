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
static uint8_t *fetch_body(const char *where, const uint8_t *roots, char *why, size_t room_why) {
    entry5 resolve = entry("url", "resolve"), part = entry("url", "part"), port_of = entry("url", "port"), request_of = entry("http", "request"), status_of = entry("http", "status"), header = entry("http", "header"), packed_of = entry("http", "packed"), body_of = entry("http", "body"), unpack = entry("inflate", "unpack");
    uint8_t *address = text_block(where, strlen(where)), *reply = 0;
    for (int hop = 0; hop < 6 && !reply; hop++) {
        at(30, address); at(31, address); int16_t q2[2] = {30, 31}; uint8_t *normal = made_text(resolve, q2, 2, length(address) + 64); if (!normal) { snprintf(why, room_why, "not an address we can follow"); return 0; } address = normal; at(30, address);
        int16_t qs[2] = {30, 1}, qc[2] = {30, 0}, q1[1] = {30}; uint8_t *site = made_text(part, qs, 2, 300), *scheme = made_text(part, qc, 2, 16), *request = made_text(request_of, q1, 1, 8192); long long port = port_of(0, q1, 1, 0, table);
        if (!site || !scheme || !request || port <= 0) { snprintf(why, room_why, "not an address we can follow"); return 0; }
        char host[300]; size_t hn = length(site); memcpy(host, site + 64, hn); host[hn] = 0; if (host[0] == '[' && hn > 1) { memmove(host, host + 1, hn - 2); host[hn - 2] = 0; }
        int https = length(scheme) == 5 && !memcmp(scheme + 64, "https", 5);
        reply = https ? secure_fetch(host, (int)port, request, roots, why, room_why) : plain_fetch(host, (int)port, request, why, room_why); if (!reply) return 0;
        at(32, reply); int16_t qr[1] = {32}; long long status = status_of(0, qr, 1, 0, table);
        if (status == 301 || status == 302 || status == 303 || status == 307 || status == 308) { int16_t ql[9] = {32, 'l', 'o', 'c', 'a', 't', 'i', 'o', 'n'}; uint8_t *to = made_text(header, ql, 9, 4096); if (!to) { snprintf(why, room_why, "a redirect to nowhere"); return 0; }
            at(31, to); int16_t qn[2] = {30, 31}; uint8_t *next = made_text(resolve, qn, 2, 8192); if (!next) { snprintf(why, room_why, "a redirect we cannot follow"); return 0; } address = next; reply = 0; } }
    if (!reply) { snprintf(why, room_why, "too many redirects"); return 0; }
    size_t got = length(reply), room = (got * 4 > 200000 ? got * 4 : 200000) * 6; int16_t qr[1] = {32}; long long packed = packed_of(0, qr, 1, 0, table); uint8_t *body = block(2, room); long long bn = body_of(body, qr, 1, 0, table);
    if (bn < 0) { snprintf(why, room_why, "the reply's body could not be read"); return 0; } resize(body, (size_t)bn);
    if (packed == 1) { at(33, body); int16_t qb[1] = {33}; uint8_t *plain = block(2, room); long long un = unpack(plain, qb, 1, 0, table); if (un < 0) { snprintf(why, room_why, "the packed body could not be unpacked"); return 0; } resize(plain, (size_t)un); body = plain; }
    return body; }
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
static int serve(int argc, char **argv, const uint8_t *roots, uint8_t *font) {
    if (argc < 7) { fprintf(stderr, "browse <pieces out dir> --serve <picture file> <events file> <width> <height> [address]\n"); return 2; }
    uint32_t W = (uint32_t)atoi(argv[5]), H = (uint32_t)atoi(argv[6]); if (W < 16 || H < 16 || W > 4096 || H > 4096) return 2; size_t bytes = 64 + 4ull * W * H;
    int fd = open(argv[3], O_RDWR | O_CREAT, 0600); if (fd < 0 || ftruncate(fd, (off_t)bytes)) { fprintf(stderr, "cannot make the picture file\n"); return 1; }
    uint8_t *screen = mmap(0, bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0); if (screen == MAP_FAILED) return 1; uint64_t z = bytes, counter = 0; uint32_t head[4] = {1, W, H, 4 * W}; memset(screen, 0, 64); memcpy(screen, head, 16); memcpy(screen + 16, &z, 8);
    FILE *ev = fopen(argv[4], "a+"); if (!ev) return 1; fseek(ev, 0, SEEK_END); long read_to = ftell(ev);
    char why[400] = "", address[2048]; snprintf(address, sizeof address, "%s", argc > 7 ? argv[7] : "https://example.com/"); uint8_t *body = 0; long long tall = 0, scroll = 0; int size_px = 30, dirty = 1, fresh = 1, down = 0, last_y = 0, down_x = 0, down_y = 0, moved = 0, depth = 0; enum { BAR = 44 }; static char before[16][2048]; entry5 rect = entry("paint", "fill_rect"), words = entry("font", "draw"); enum { TILE = 1024, KEPT = 24, PICS = 32 }; static pic pics[PICS]; int pic_n = 0; static uint8_t *strip[KEPT]; static long long strip_at[KEPT]; static unsigned long strip_used[KEPT], tick; for (int i = 0; i < KEPT; i++) strip_at[i] = -1; entry5 render = entry("page", "render"), clear = entry("paint", "clear");
    for (;;) {
        if (fresh) { fresh = 0; for (int i = 0; i < KEPT; i++) strip_at[i] = -1; double t = now_ms(); body = fetch_body(address, roots, why, sizeof why); scroll = 0; dirty = 1; printf("%s: %s (%.0f ms)\n", address, body ? "open" : why, now_ms() - t); fflush(stdout);
            for (int i = 0; i < pic_n; i++) { free(pics[i].ready); pics[i].ready = 0; } pic_n = 0;
            if (body) { at(34, body); at(35, font); uint8_t *list = block(2, 65536); int16_t qq[4] = {34, 35, (int16_t)size_px, (int16_t)W}; long long ln = entry("page", "pictures")(list, qq, 4, 0, table);
                for (long long o = 0; o + 20 <= ln && pic_n < PICS; ) { uint32_t f[5]; memcpy(f, list + 64 + o, 20); if (f[4] < sizeof pics[0].src && f[2] && f[3]) { pic *p = &pics[pic_n++]; p->x = f[0]; p->y = f[1]; p->w = f[2]; p->h = f[3]; size_t k = 0; for (uint32_t i = 0; i < f[4]; i++) { char c = (char)list[64 + o + 20 + i]; p->src[k++] = c; if (c == '&' && i + 4 < f[4] && !memcmp(list + 64 + o + 21 + i, "amp;", 4)) i += 4; } p->src[k] = 0; p->state = 0; p->ready = 0; } o += 20 + ((f[4] + 3) & ~3u); }
                free(list); printf("%d pictures to fetch\n", pic_n); fflush(stdout); }
            if (!body) { char sorry[600]; int n = snprintf(sorry, sizeof sorry, "<h2>This page could not be opened</h2><p>%s</p><p>%s</p>", address, why); body = text_block(sorry, (size_t)n); } }
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
              int n = 4, room_chars = (int)(W - 60) / 9; const char *shown = address; if (!strncmp(shown, "https://", 8)) shown += 8; t[1] = 15; t[2] = 48; t[3] = 28; for (int i = 0; shown[i] && i < room_chars && n < 150; i++) t[n++] = (int16_t)(unsigned char)shown[i]; words(screen, t, n, 0xff505860ll, table); }
            counter++; memcpy(screen + 24, &counter, 8); if (drawn || now_ms() - t > 8) { printf("shown at %lld of %lld in %.1f ms (%d strips drawn by the pieces)\n", scroll, tall, now_ms() - t, drawn); fflush(stdout); } }
        struct stat st; if (fstat(fileno(ev), &st) == 0 && st.st_size > read_to) { fseek(ev, read_to, SEEK_SET); char line[2100];
            while (fgets(line, sizeof line, ev)) { size_t n = strlen(line); if (!n || line[n - 1] != '\n') break; read_to += (long)n; line[n - 1] = 0; int x, y;
                if (line[0] == 'd' && sscanf(line + 1, "%d %d", &x, &y) == 2) { down = 1; last_y = y; down_x = x; down_y = y; moved = 0; }
                else if (line[0] == 'm' && down && sscanf(line + 1, "%d %d", &x, &y) == 2) { moved += abs(y - last_y) + abs(x - down_x) / 4; long long limit = tall + BAR > (long long)H ? tall + BAR - H : 0, to = scroll - (y - last_y); if (to < 0) to = 0; if (to > limit) to = limit; last_y = y; if (to != scroll) { scroll = to; dirty = 1; } }
                else if (line[0] == 'u') { if (down && moved < 12 && down_y < BAR) { if (down_x < 64 && depth) { snprintf(address, sizeof address, "%s", before[--depth]); fresh = 1; printf("back to %s\n", address); fflush(stdout); } }
                    else if (down && moved < 12) {   /* a tap: is there a link under it? The page piece says; the url piece works out where it leads */
                        at(34, body); at(35, font); int16_t ql[8] = {34, 35, (int16_t)size_px, (int16_t)((scroll > 32000 ? 32000 : scroll) - BAR), (int16_t)down_x, (int16_t)down_y, (int16_t)W, (int16_t)H}; uint8_t *href = block(2, 4096); long long hn = entry("page", "link")(href, ql, 8, 0, table);
                        if (hn > 0) { { /* an address written in a page spells & as &amp; (to become the page piece's job) */ size_t o = 0; for (long long i = 0; i < hn; i++) { href[64 + o++] = href[64 + i]; if (href[64 + i] == '&' && i + 4 < hn && !memcmp(href + 64 + i + 1, "amp;", 4)) i += 4; } hn = (long long)o; } resize(href, (size_t)hn); uint8_t *base = text_block(address, strlen(address)); at(30, base); at(31, href); int16_t qn[2] = {30, 31}; uint8_t *next = made_text(entry("url", "resolve"), qn, 2, 8192);
                            if (next && length(next) < sizeof address) { if (depth == 16) { memmove(before[0], before[1], 15 * sizeof before[0]); depth = 15; } snprintf(before[depth++], sizeof before[0], "%s", address); memcpy(address, next + 64, length(next)); address[length(next)] = 0; fresh = 1; printf("tap at %d %d: link to %s\n", down_x, down_y, address); } else printf("tap at %d %d: a link the address piece cannot follow\n", down_x, down_y); }
                        else printf("tap at %d %d: no link there\n", down_x, down_y); fflush(stdout); } down = 0; }
                else if (line[0] == 'o' && line[1] == ' ') { if (depth == 16) { memmove(before[0], before[1], 15 * sizeof before[0]); depth = 15; } snprintf(before[depth++], sizeof before[0], "%s", address); snprintf(address, sizeof address, "%s", line + 2); fresh = 1; }
                else if (line[0] == 'g' && sscanf(line + 1, "%d", &y) == 1) { long long limit = tall + BAR > (long long)H ? tall + BAR - H : 0; scroll = y < 0 ? 0 : y > limit ? limit : y; dirty = 1; }   /* go to that row of the page */
                else if (line[0] == 'q') return 0; } }
        else if (st.st_size < read_to) read_to = 0;
        if (!dirty && !fresh) { int todo = -1; for (int i = 0; i < pic_n && todo < 0; i++) if (pics[i].state == 0) todo = i;
            if (todo >= 0) { double t = now_ms(); pic *p = &pics[todo]; p->state = get_picture(p, address, roots) ? 1 : 2; printf("picture %d of %d (%u x %u at row %u) %s in %.0f ms: %.80s\n", todo + 1, pic_n, p->w, p->h, p->y, p->state == 1 ? "ready" : "could not be shown", now_ms() - t, p->src); fflush(stdout);
                if (p->state == 1) { for (int i = 0; i < KEPT; i++) if (strip_at[i] >= 0 && (long long)p->y < (strip_at[i] + 1) * TILE && (long long)p->y + p->h > strip_at[i] * TILE) strip_at[i] = -1; dirty = 1; } }
            else usleep(4000); } } }
int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "browse <pieces out dir> <address> <out.png> [text size] [scroll] [width] [height]\n   or: browse <pieces out dir> --ask <key file> <model> <prompt file> [most tokens]\n"); return 2; }
    dir = argv[1]; int size_px = argc > 4 ? atoi(argv[4]) : 26, scroll = argc > 5 ? atoi(argv[5]) : 0; uint32_t W = argc > 6 ? (uint32_t)atoi(argv[6]) : 720, H = argc > 7 ? (uint32_t)atoi(argv[7]) : 1280; double started = now_ms();
    char path[600]; snprintf(path, sizeof path, "%s/../slots.txt", dir); FILE *f = fopen(path, "r"); if (!f) { fprintf(stderr, "no slots.txt\n"); return 3; }
    char line[256]; while (fgets(line, sizeof line, f)) { int slot; char name[64], en[64]; if (line[0] == '#' || sscanf(line, "%d %63s %63s", &slot, name, en) != 3) continue; if (slot >= 0 && slot < 256) table[slot] = piece_entry(get(name), en); } fclose(f);
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
