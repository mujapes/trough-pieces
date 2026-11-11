/* Record and replay a piece's checks (VECTORS.md).
 *   vectors record <reference stem> <manifest> <out.vectors>
 *   vectors check  <stem> <manifest> <file.vectors>          exit 0 if every record matches */
#include "piece.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef struct { uint32_t h[5]; uint64_t n; uint8_t buf[64]; int fill; } sha1;
static uint32_t rol(uint32_t v, int s) { return (v << s) | (v >> (32 - s)); }
static void sha1_block(sha1 *c, const uint8_t *p) {
    uint32_t w[80], a = c->h[0], b = c->h[1], cc = c->h[2], d = c->h[3], e = c->h[4];
    for (int i = 0; i < 16; i++) w[i] = (uint32_t)p[4*i] << 24 | (uint32_t)p[4*i+1] << 16 | (uint32_t)p[4*i+2] << 8 | p[4*i+3];
    for (int i = 16; i < 80; i++) w[i] = rol(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
    for (int i = 0; i < 80; i++) { uint32_t f, k;
        if (i < 20) { f = (b & cc) | (~b & d); k = 0x5A827999; } else if (i < 40) { f = b ^ cc ^ d; k = 0x6ED9EBA1; }
        else if (i < 60) { f = (b & cc) | (b & d) | (cc & d); k = 0x8F1BBCDC; } else { f = b ^ cc ^ d; k = 0xCA62C1D6; }
        uint32_t t = rol(a, 5) + f + e + k + w[i]; e = d; d = cc; cc = rol(b, 30); b = a; a = t; }
    c->h[0] += a; c->h[1] += b; c->h[2] += cc; c->h[3] += d; c->h[4] += e;
}
static void sha1_of(const uint8_t *p, size_t n, uint8_t out[20]) {
    sha1 c = {{0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0}, 0, {0}, 0}; size_t i = 0;
    for (; i + 64 <= n; i += 64) sha1_block(&c, p + i);
    uint8_t last[128] = {0}; size_t rest = n - i; memcpy(last, p + i, rest); last[rest] = 0x80;
    size_t total = rest < 56 ? 64 : 128; uint64_t bits = (uint64_t)n * 8;
    for (int k = 0; k < 8; k++) last[total - 1 - k] = (uint8_t)(bits >> (8 * k));
    sha1_block(&c, last); if (total == 128) sha1_block(&c, last + 64);
    for (int k = 0; k < 5; k++) { out[4*k] = c.h[k] >> 24; out[4*k+1] = c.h[k] >> 16; out[4*k+2] = c.h[k] >> 8; out[4*k+3] = c.h[k]; }
}
typedef struct { int state; int entries; char name[8][32]; long lo[8], hi[8]; int surface_w, surface_h, text_style, path_style, image_style, font_style; char fixture[256];
    /* format 2 (VECTORS.md): what sits at which handle, and how each entry's numbers are made */
    int mask_target, state_target, fingerprint_all; int holds; struct { int handle, type, w, h, kind; long bytes; char name[128]; } hold[16];
    struct { int fields, lo, hi; struct { int type; long a, b; long list[8]; int n; } field[24]; } recipe[8]; int recipes; } manifest;
enum { HOLD_FILE = 1, HOLD_SURFACE, HOLD_MASK, HOLD_BLOCK, HOLD_PICTURE };
enum { F_PICK = 1, F_RANGE, F_FIXED, F_CHARS, F_RAW };
static int read_manifest(const char *path, manifest *m) {
    FILE *f = fopen(path, "r"); if (!f) return -1; char word[64]; memset(m, 0, sizeof *m);
    while (fscanf(f, "%63s", word) == 1) {
        if (!strcmp(word, "state")) { if (fscanf(f, "%d", &m->state) != 1) return -1; }
        else if (!strcmp(word, "entry") && m->entries < 8) { if (fscanf(f, "%31s %ld %ld", m->name[m->entries], &m->lo[m->entries], &m->hi[m->entries]) != 3) return -1; m->entries++; }
        else if (!strcmp(word, "surface")) { if (fscanf(f, "%d %d", &m->surface_w, &m->surface_h) != 2) return -1; }   /* the state block is a picture of this size */
        else if (!strcmp(word, "style")) { char kind[32]; if (fscanf(f, "%31s", kind) != 1) return -1; m->text_style = !strcmp(kind, "text"); m->path_style = !strcmp(kind, "path"); m->image_style = !strcmp(kind, "image"); m->font_style = !strcmp(kind, "font"); }
        else if (!strcmp(word, "fixture")) { if (fscanf(f, "%255s", m->fixture) != 1) return -1; }   /* a file to hold at handle 0 while the checks run */   /* numbers after the first two are character codes */
        else if (!strcmp(word, "target")) { char kind[32]; if (fscanf(f, "%31s", kind) != 1) return -1;
            if (!strcmp(kind, "state")) { if (fscanf(f, "%d", &m->state) != 1) return -1; m->state_target = 1; }      /* a state block: fresh means all zero, then entry 0 (migrate) */
            else { if (fscanf(f, "%d %d", &m->surface_w, &m->surface_h) != 2) return -1; m->mask_target = !strcmp(kind, "mask"); } }
        else if (!strcmp(word, "fingerprint")) { char what[32]; if (fscanf(f, "%31s", what) != 1) return -1; m->fingerprint_all = !strcmp(what, "all"); }   /* format 3 */
        else if (!strcmp(word, "hold") && m->holds < 16) { char kind[32]; int h; if (fscanf(f, "%d %31s", &h, kind) != 2 || h < 0 || h > 15) return -1; int k = m->holds++; m->hold[k].handle = h;
            if (!strcmp(kind, "file")) { m->hold[k].type = HOLD_FILE; if (fscanf(f, "%127s", m->hold[k].name) != 1) return -1; }
            else if (!strcmp(kind, "surface") || !strcmp(kind, "mask")) { m->hold[k].type = kind[0] == 's' ? HOLD_SURFACE : HOLD_MASK; if (fscanf(f, "%d %d", &m->hold[k].w, &m->hold[k].h) != 2) return -1; }
            else if (!strcmp(kind, "block")) { m->hold[k].type = HOLD_BLOCK; if (fscanf(f, "%d %ld", &m->hold[k].kind, &m->hold[k].bytes) != 2) return -1; }
            else if (!strcmp(kind, "picture")) m->hold[k].type = HOLD_PICTURE; else return -1; }
        else if (!strcmp(word, "numbers")) {            /* numbers <entry name> <lowest count> <highest count> <field> ... ; the last field repeats */
            char name[32]; int e = -1, lo, hi; if (fscanf(f, "%31s %d %d", name, &lo, &hi) != 3) return -1; for (int i = 0; i < m->entries; i++) if (!strcmp(m->name[i], name)) e = i; if (e < 0 || lo < 0 || hi < lo || hi > 4000) return -1;
            m->recipe[e].lo = lo; m->recipe[e].hi = hi; m->recipes++; char rest[1024]; if (!fgets(rest, sizeof rest, f)) rest[0] = 0;
            for (char *tok = strtok(rest, " \t\n"); tok && m->recipe[e].fields < 24; tok = strtok(0, " \t\n")) { int k = m->recipe[e].fields++; char *colon = strchr(tok, ':'); if (colon) *colon++ = 0;
                if (!strcmp(tok, "pick")) { m->recipe[e].field[k].type = F_PICK; for (char *v = colon; v && *v && m->recipe[e].field[k].n < 8; ) { m->recipe[e].field[k].list[m->recipe[e].field[k].n++] = strtol(v, &v, 10); if (*v == ',') v++; if (*v && m->recipe[e].field[k].n == 8) return -1; }   /* more than eight choices is refused, not quietly cut short: the app's checker would read them all and disagree */
                    if (!m->recipe[e].field[k].n) return -1; }
                else if (!strcmp(tok, "range")) { m->recipe[e].field[k].type = F_RANGE; char *v = colon; if (!v) return -1; m->recipe[e].field[k].a = strtol(v, &v, 10); if (*v != ':') return -1; m->recipe[e].field[k].b = strtol(v + 1, 0, 10); if (m->recipe[e].field[k].b < m->recipe[e].field[k].a) return -1; }
                else if (!strcmp(tok, "fixed")) { m->recipe[e].field[k].type = F_FIXED; m->recipe[e].field[k].a = colon ? strtol(colon, 0, 10) : 0; }
                else if (!strcmp(tok, "chars")) m->recipe[e].field[k].type = F_CHARS;
                else if (!strcmp(tok, "raw")) { m->recipe[e].field[k].type = F_RAW; m->recipe[e].field[k].a = colon ? strtol(colon, 0, 10) : 100; }
                else return -1; }
            if (!m->recipe[e].fields) return -1; }
        else if (!strcmp(word, "needs")) { int socket; if (fscanf(f, "%d", &socket) != 1) return -1; }   /* sockets it calls through: the host's concern */
        else return -1;
    }
    fclose(f);
    if (m->surface_w && m->state != 64 + (m->mask_target ? 1 : 4) * m->surface_w * m->surface_h) return -1;
    return m->entries > 0 && (m->state == 0 || (m->state >= 64 && m->state <= (1 << 24))) ? 0 : -1;
}
static int16_t samples[70000];
static void *table[512];
/* A new, empty picture of the manifest's size, exactly as the host makes one (paint/intent.md). */
static void fresh_surface(const manifest *m, uint8_t *state) {
    memset(state, 0, m->state); if (m->state_target) return;
    uint32_t head[4] = {m->mask_target ? 4u : 1u, (uint32_t)m->surface_w, (uint32_t)m->surface_h, (m->mask_target ? 1u : 4u) * (uint32_t)m->surface_w}; uint64_t size = (uint64_t)m->state;
    memcpy(state, head, 16); memcpy(state + 16, &size, 8);
}
/* Flag 16: the numbers after the first two are turned into character codes 20..134, so most are printable and some are not. */
static void as_text(uint32_t count) { for (uint32_t i = 2; i < count; i++) samples[i] = (int16_t)(20 + ((int32_t)samples[i] + 32768) % 115); }
/* Flag 32: the first number becomes the point count of one outline using the rest: (count - 1) / 2. */
static void as_path(uint32_t count) { if (count >= 1) samples[0] = (int16_t)((count - 1) / 2); }
/* Flag 64: handle 0 holds the standard test picture, and the first number (the handle asked for) becomes 0,
 * or 1 (an empty handle) when it was a multiple of 5. The picture is 24 by 16: at column x, row y the bytes are
 * red (37x + 11y) mod 256, green (5x + 53y) mod 256, blue (7xy + 3) mod 256, and alpha 0 when x + y is a
 * multiple of 5, otherwise 128 when x mod 7 is 3, otherwise 255. */
static uint8_t test_picture[64 + 24 * 16 * 4];
static void as_image(uint32_t count) {
    if (!test_picture[0]) { uint32_t head[4] = {1, 24, 16, 96}; uint64_t size = sizeof test_picture; memcpy(test_picture, head, 16); memcpy(test_picture + 16, &size, 8);
        for (int y = 0; y < 16; y++) for (int x = 0; x < 24; x++) { uint8_t *q = test_picture + 64 + (y * 24 + x) * 4;
            q[0] = (uint8_t)(37 * x + 11 * y); q[1] = (uint8_t)(5 * x + 53 * y); q[2] = (uint8_t)(7 * x * y + 3); q[3] = (x + y) % 5 == 0 ? 0 : x % 7 == 3 ? 128 : 255; } }
    table[256] = test_picture; table[257] = 0;
    if (count >= 1) samples[0] = (int16_t)(samples[0] % 5 == 0 ? 1 : 0);
}
/* Flag 128: the manifest's fixture file is at handle 0 as a block of bytes, handle 1 is empty, the first number
 * (the handle asked for) becomes 0, or 1 when it was a multiple of 5, and every number from the fifth on becomes a
 * character code as for flag 16. */
static uint8_t *fixture_block; static char fixture_dir[512];
static int as_fixture(const manifest *m, uint32_t count) {
    if (!fixture_block) { char path[800]; snprintf(path, sizeof path, "%s/%s", fixture_dir, m->fixture); FILE *in = fopen(path, "rb"); if (!in) return -1;
        fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET); fixture_block = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t size = 64 + (uint64_t)len;
        memcpy(fixture_block, &kind, 4); memcpy(fixture_block + 16, &size, 8); if (fread(fixture_block + 64, 1, (size_t)len, in) != (size_t)len) return -1; fclose(in); }
    table[256] = fixture_block; table[257] = 0;
    if (count >= 1) samples[0] = (int16_t)(samples[0] % 5 == 0 ? 1 : 0);
    for (uint32_t i = 4; i < count; i++) samples[i] = (int16_t)(20 + ((int32_t)samples[i] + 32768) % 115);
    return 0;
}
/* Format 2. Numbers from a recipe: one stream of values seed' = seed * 1103515245 + 12345, each use taking
 * (seed' >> 8); first the count (lowest + value mod (highest - lowest + 1)), then one value per number. */
static uint32_t recipe_numbers(const manifest *m, int e, uint32_t seed) {
    #define NEXT() (seed = seed * 1103515245u + 12345u, seed >> 8)
    uint32_t count = (uint32_t)m->recipe[e].lo + NEXT() % (uint32_t)(m->recipe[e].hi - m->recipe[e].lo + 1);
    for (uint32_t i = 0; i < count; i++) { int k = (int)i < m->recipe[e].fields ? (int)i : m->recipe[e].fields - 1; uint32_t v = NEXT(); long out;
        switch (m->recipe[e].field[k].type) {
            case F_PICK: out = m->recipe[e].field[k].list[v % (uint32_t)m->recipe[e].field[k].n]; break;
            case F_RANGE: out = m->recipe[e].field[k].a + (long)(v % (uint32_t)(m->recipe[e].field[k].b - m->recipe[e].field[k].a + 1)); break;
            case F_FIXED: out = m->recipe[e].field[k].a; break;
            case F_CHARS: out = 20 + (long)(v % 115); break;
            default: out = (long)(v % (uint32_t)(2 * m->recipe[e].field[k].a + 1)) - m->recipe[e].field[k].a; }
        samples[i] = (int16_t)out; }
    #undef NEXT
    return count;
}
static uint8_t *held[16]; static char hold_dir[512];
/* Format 2. Everything the manifest holds, made new: files read once, the rest zeroed with the right header. */
static int fresh_holds(const manifest *m) {
    for (int k = 0; k < m->holds; k++) { int h = m->hold[k].handle; size_t size = 0; uint32_t head[4] = {0, 0, 0, 0};
        if (m->hold[k].type == HOLD_FILE) { if (!held[k]) { char path[800]; snprintf(path, sizeof path, "%s/%s", hold_dir, m->hold[k].name); FILE *in = fopen(path, "rb"); if (!in) return -1;
                fseek(in, 0, SEEK_END); long len = ftell(in); fseek(in, 0, SEEK_SET); held[k] = calloc(1, 64 + (size_t)len); uint32_t kind = 2; uint64_t z = 64 + (uint64_t)len; memcpy(held[k], &kind, 4); memcpy(held[k] + 16, &z, 8);
                if (fread(held[k] + 64, 1, (size_t)len, in) != (size_t)len) return -1; fclose(in); }
            table[256 + h] = held[k]; continue; }
        if (m->hold[k].type == HOLD_PICTURE) { samples[0] = 0; as_image(0); table[256 + h] = test_picture; if (h != 1) table[257] = 0; continue; }
        if (m->hold[k].type == HOLD_SURFACE) { size = 64 + 4u * (size_t)m->hold[k].w * m->hold[k].h; head[0] = 1; head[1] = (uint32_t)m->hold[k].w; head[2] = (uint32_t)m->hold[k].h; head[3] = 4u * (uint32_t)m->hold[k].w; }
        else if (m->hold[k].type == HOLD_MASK) { size = 64 + (size_t)m->hold[k].w * m->hold[k].h; head[0] = 4; head[1] = (uint32_t)m->hold[k].w; head[2] = (uint32_t)m->hold[k].h; head[3] = (uint32_t)m->hold[k].w; }
        else { size = (size_t)m->hold[k].bytes; head[0] = (uint32_t)m->hold[k].kind; }
        if (size < 64) return -1; if (!held[k]) held[k] = malloc(size); memset(held[k], 0, size); uint64_t z = size; memcpy(held[k], head, 16); memcpy(held[k] + 16, &z, 8); table[256 + h] = held[k]; }
    return 0;
}
/* Format 3 fingerprints the target and then every held block a piece could have written (pictures, masks, other
 * blocks; not files or the test picture), in manifest order: SHA-1 of their SHA-1s laid end to end. Format 2
 * fingerprints the target alone. */
static void fingerprint(const manifest *m, const uint8_t *state, int all, uint8_t out[20]) {
    if (!all) { sha1_of(state, m->state, out); return; }
    uint8_t parts[20 * 17]; int n = 0; sha1_of(state, m->state, parts); n = 1;
    for (int k = 0; k < m->holds; k++) { if (m->hold[k].type == HOLD_FILE || m->hold[k].type == HOLD_PICTURE || !held[k]) continue;
        uint64_t size; memcpy(&size, held[k] + 16, 8); sha1_of(held[k], (size_t)size, parts + 20 * n); n++; }
    sha1_of(parts, (size_t)(20 * n), out);
}
static void generate(uint32_t seed, uint32_t span, uint32_t count) { for (uint32_t i = 0; i < count; i++) { seed = seed * 1103515245u + 12345u; samples[i] = (int16_t)((int32_t)((seed >> 8) % (2 * span + 1)) - (int32_t)span); } }
/* The call table (slots.txt). On the bench every socket points at the reference build of its piece, so a piece
 * that calls others is recorded and checked against known-good neighbours. */
static piece neighbours[64]; static int neighbour_count;
static void fill_table(const char *out_dir) {
    char path[600]; snprintf(path, sizeof path, "%s/../slots.txt", out_dir); FILE *f = fopen(path, "r"); if (!f) return;
    char line[256]; while (fgets(line, sizeof line, f)) { int slot; char name[64], entry[64]; if (line[0] == '#' || sscanf(line, "%d %63s %63s", &slot, name, entry) != 3 || slot < 0 || slot >= 512) continue;
        snprintf(path, sizeof path, "%s/%s.ref", out_dir, name); piece *p = 0;
        for (int i = 0; i < neighbour_count; i++) if (!strcmp(neighbours[i].names[7], name)) p = &neighbours[i];
        if (!p && neighbour_count < 64) { p = &neighbours[neighbour_count]; if (piece_load(p, path)) continue; strncpy(p->names[7], name, 31); neighbour_count++; }
        if (p) table[slot] = piece_entry(p, entry); }
    fclose(f);
}
static int64_t call(const manifest *m, void *entry, uint8_t *state, int with_samples, uint32_t count, int64_t arg) {
    if (m->state) return ((int64_t (*)(void *, const int16_t *, int64_t, int64_t, void *))entry)(state, with_samples ? samples : 0, with_samples ? count : 0, arg, table);
    return ((int64_t (*)(const int16_t *, int64_t, int64_t, void *))entry)(samples, count, arg, table);
}
static void put32(FILE *f, uint32_t v) { fputc(v, f); fputc(v >> 8, f); fputc(v >> 16, f); fputc(v >> 24, f); }
static void put64(FILE *f, uint64_t v) { put32(f, (uint32_t)v); put32(f, (uint32_t)(v >> 32)); }
static uint32_t get32(FILE *f) { uint32_t v = fgetc(f); v |= (uint32_t)fgetc(f) << 8; v |= (uint32_t)fgetc(f) << 16; v |= (uint32_t)fgetc(f) << 24; return v; }
static uint64_t get64(FILE *f) { uint64_t v = get32(f); return v | (uint64_t)get32(f) << 32; }
static unsigned rs = 20261111; static unsigned rnd(void) { rs = rs * 1103515245u + 12345u; return rs >> 8; }
static long records;
static void record(FILE *f, const manifest *m, void **entry, uint8_t *state, int e, int flags, uint32_t count, uint32_t span, int64_t arg, const uint8_t *explicit_state) {
    uint32_t seed = rnd() * 2654435761u + (uint32_t)records;
    if (flags & 2) memset(state, 0, m->state);
    if (flags & 4) memcpy(state, explicit_state, m->state);
    if (flags & 8) fresh_surface(m, state);
    if (flags & 1) generate(seed, span, count);
    if (flags & 16) as_text(count);
    if (flags & 32) as_path(count);
    if (flags & 64) as_image(count);
    if ((flags & 128) && as_fixture(m, count)) { fprintf(stderr, "cannot read the fixture\n"); exit(2); }
    int64_t result = call(m, entry[e], state, flags & 1, count, arg);
    fputc(e, f); fputc(flags, f); fputc(0, f); fputc(0, f); put32(f, count); put32(f, seed); put32(f, span); put64(f, (uint64_t)arg); put64(f, (uint64_t)result);
    if (flags & 4) fwrite(explicit_state, 1, m->state, f);
    if (m->state) { uint8_t digest[20]; sha1_of(state, m->state, digest); fwrite(digest, 1, 20, f); }
    records++;
}
int main(int argc, char **argv) {
    if (argc != 5) { fprintf(stderr, "usage: vectors record|check <stem> <manifest> <vectors>\n"); return 2; }
    manifest m; if (read_manifest(argv[3], &m)) { fprintf(stderr, "bad manifest %s\n", argv[3]); return 2; }
    if (!strcmp(argv[1], "record") && m.entries < 2 && !m.recipes) {   /* recording only: replaying such a file (peak has one) is fine, and this guard once refused that too */ fprintf(stderr, "a piece with one entry needs a numbers line (the older recording forms pick among entries 1 and up)\n"); return 2; }
    { char dir[512]; strncpy(dir, argv[3], sizeof dir - 1); dir[sizeof dir - 1] = 0; char *slash = strrchr(dir, '/'); if (slash) *slash = 0; else strcpy(dir, "."); fill_table(dir); strcpy(fixture_dir, dir); strcpy(hold_dir, dir); }
    piece p; if (piece_load(&p, argv[2])) { fprintf(stderr, "cannot load %s\n", argv[2]); return 2; }
    void *entry[8]; for (int i = 0; i < m.entries; i++) if (!(entry[i] = piece_entry(&p, m.name[i]))) { fprintf(stderr, "%s lacks entry %s\n", argv[2], m.name[i]); return 1; }
    uint8_t *state = calloc(1, m.state ? m.state : 1);
    if (!strcmp(argv[1], "record")) {
        /* Written beside the real name and moved into place when complete: the running app watches this file and
         * must never see half of it (it did, 2026-11-11, and said "no checks recorded" until the write finished). */
        static char part[1100]; snprintf(part, sizeof part, "%s.part", argv[4]);
        FILE *f = fopen(part, "wb"); if (!f) return 2;
        if (m.recipes) {                                             /* format 2: runs that start fresh and then build on each other */
            fwrite(m.fingerprint_all ? "TRPIECE3" : "TRPIECE2", 1, 8, f); put32(f, 0); if (!m.state || (!m.surface_w && !m.state_target)) { fprintf(stderr, "format 2 needs a target\n"); return 2; }
            int special = !strcmp(m.name[0], "check") || !strcmp(m.name[0], "migrate");
            for (int trial = 0; trial < 40; trial++) for (int step = 0; step <= 150; step++) {
                /* Entry 0 is called once at the start of each run and never again only when it is the piece's check or migrate. An ordinary first
                 * entry (hash's sha256, sound's convert, trust's chain) used to get those 40 calls and no more: found 2026-11-11 when deliberate
                 * breaks in trust's chain passed. It now takes its turn with the others. */
                int e = special ? (step == 0 || m.entries < 2 ? 0 : 1 + (int)(rnd() % (unsigned)(m.entries - 1))) : (int)(rnd() % (unsigned)m.entries), flags = step == 0 ? 24 : 0; uint32_t seed = rnd() * 2654435761u + (uint32_t)records;
                if (flags & 8) fresh_surface(&m, state); if ((flags & 16) && fresh_holds(&m)) { fprintf(stderr, "cannot set up what the manifest holds\n"); return 2; }
                uint32_t count = m.recipe[e].fields ? recipe_numbers(&m, e, seed) : 0; int64_t arg = (int64_t)(((uint64_t)rnd() << 16) ^ rnd()); if (m.hi[e] > m.lo[e]) arg = m.lo[e] + (int64_t)((uint64_t)arg % (uint64_t)(m.hi[e] - m.lo[e] + 1));   /* an entry line with a range (trust's chain: the time) is honoured */
                int64_t result = call(&m, entry[e], state, 1, count, arg);
                fputc(e, f); fputc(flags, f); fputc(0, f); fputc(0, f); put32(f, seed); put64(f, (uint64_t)arg); put64(f, (uint64_t)result);
                uint8_t digest[20]; fingerprint(&m, state, m.fingerprint_all, digest); fwrite(digest, 1, 20, f); records++; }
            fseek(f, 8, SEEK_SET); put32(f, (uint32_t)records); fclose(f); if (rename(part, argv[4])) return 2; printf("recorded %ld checks from %s (format %d)\n", records, argv[2], m.fingerprint_all ? 3 : 2); return 0; }
        fwrite("TRPIECE1", 1, 8, f); put32(f, 0);
        if (!m.state) {
            static const int edge[] = {32767, 0, 1};                                   /* span 32767 reaches both extremes */
            for (int e = 0; e < m.entries; e++) {
                for (int k = 0; k < 3; k++) for (uint32_t n = 0; n <= 70; n++) record(f, &m, entry, state, e, 1, n, edge[k], m.lo[e] + (long)(rnd() % (unsigned long)(m.hi[e] - m.lo[e] + 1)), 0);
                for (int t = 0; t < 4000; t++) record(f, &m, entry, state, e, 1, rnd() % 6, t % 7 == 0 ? 1 : t % 3 == 0 ? 120 : 3000, m.lo[e] + (long)(rnd() % (unsigned long)(m.hi[e] - m.lo[e] + 1)), 0);   /* short lists of small numbers: flags, percents, counts */
                for (int t = 0; t < 3000; t++) { uint32_t n = t < 2400 ? rnd() % 300 : rnd() % 70000, span = rnd() % 32768;
                    record(f, &m, entry, state, e, 1, n, span, m.lo[e] + (long)(rnd() % (unsigned long)(m.hi[e] - m.lo[e] + 1)), 0); }
            }
        } else if (m.surface_w) {
            uint8_t *odd = calloc(1, m.state); uint32_t v;
            for (int k = 0; k < 6; k++) { fresh_surface(&m, odd);                                                    /* headers that must be refused */
                if (k == 0) { v = 2; memcpy(odd, &v, 4); } if (k == 1) { v = 0; memcpy(odd + 4, &v, 4); } if (k == 2) { v = 20000; memcpy(odd + 8, &v, 4); }
                if (k == 3) { v = 4u * m.surface_w + 4; memcpy(odd + 12, &v, 4); } if (k == 4) { uint64_t z = (uint64_t)m.state + 4; memcpy(odd + 16, &z, 8); } if (k == 5) memset(odd, 0, 64);
                record(f, &m, entry, state, 0, 4, 0, 0, 0, odd); }
            for (int trial = 0; trial < 40; trial++) {
                record(f, &m, entry, state, 0, 8, 0, 0, 0, 0);                                                        /* a fresh picture must be accepted */
                for (int step = 0; step < 150; step++) {                                                              /* rectangles on, across and far off the edges */
                    int e = 1 + (int)(rnd() % (unsigned)(m.entries - 1)); uint32_t span = rnd() % 4 == 0 ? 400 : rnd() % 9 == 0 ? 32767 : 90;
                    if (m.text_style) record(f, &m, entry, state, e, 17, rnd() % 5 == 0 ? rnd() % 3 : 2 + rnd() % 26, rnd() % 6 == 0 ? 2000 : 150, (int64_t)(((uint64_t)rnd() << 16) ^ rnd()), 0);
                    else if (m.font_style) record(f, &m, entry, state, e, 129, rnd() % 5 == 0 ? rnd() % 4 : 4 + rnd() % 14, rnd() % 6 == 0 ? 2000 : 150, (int64_t)(((uint64_t)rnd() << 16) ^ rnd()), 0);   /* random strings at random sizes and places; some sizes invalid; sometimes an empty handle */
                    else if (m.image_style) record(f, &m, entry, state, e, 65, rnd() % 8, rnd() % 5 == 0 ? 400 : 70, 0, 0);   /* the test picture on, across and off the edges, at many sizes; sometimes an empty handle */
                    else if (m.path_style) record(f, &m, entry, state, e, rnd() % 8 == 0 ? 1 : 33, rnd() % 6 == 0 ? rnd() % 9 : 5 + 2 * (rnd() % 11), rnd() % 7 == 0 ? 3000 : 600, (int64_t)(((uint64_t)rnd() << 16) ^ rnd()), 0);   /* mostly one random outline, crossing itself and the edges; some malformed */
                    else record(f, &m, entry, state, e, 1, rnd() % 7, span, (int64_t)(((uint64_t)rnd() << 16) ^ rnd()), 0); }
            }
        } else {
            uint8_t *odd = calloc(1, m.state);
            memset(odd, 0, m.state); odd[0] = 99; record(f, &m, entry, state, 0, 4, 0, 0, 0, odd);                 /* an unknown layout must be refused and left alone */
            for (int v = 1; v < 8; v++) { memset(odd, 0x5a, m.state); memset(odd, 0, 64); odd[0] = (uint8_t)v;       /* every earlier layout: what it learned must survive */
                double a = 0.0375, b = 0.0625; int64_t c = 4242; memcpy(odd + 8, &a, 8); memcpy(odd + 16, &b, 8); memcpy(odd + 24, &c, 8);
                record(f, &m, entry, state, 0, 4, 0, 0, 0, odd); }
            for (int trial = 0; trial < 60; trial++) {
                record(f, &m, entry, state, 0, 2, 0, 0, 0, 0);                                                        /* fresh block through migrate */
                uint32_t loud = 1 + rnd() % 30000;
                for (int block = 0; block < 200; block++) {
                    if (rnd() % 23 == 0) loud = 1 + rnd() % 32767;
                    uint32_t n = rnd() % 11 == 0 ? rnd() % 40 : 1597 + rnd() % 7, span = rnd() % 5 == 0 ? loud : 1 + loud / (1 + rnd() % 40);
                    int e = 1 + (int)(rnd() % (unsigned)(m.entries - 1));
                    record(f, &m, entry, state, e, 1, n, span, m.lo[e] + (long)(rnd() % (unsigned long)(m.hi[e] - m.lo[e] + 1)), 0);
                }
            }
        }
        fseek(f, 8, SEEK_SET); put32(f, (uint32_t)records); fclose(f); if (rename(part, argv[4])) return 2;
        printf("recorded %ld checks from %s\n", records, argv[2]); return 0;
    }
    FILE *f = fopen(argv[4], "rb"); char magic[8]; if (!f || fread(magic, 1, 8, f) != 8) { fprintf(stderr, "bad vectors file\n"); return 2; }
    if (!memcmp(magic, "TRPIECE2", 8) || !memcmp(magic, "TRPIECE3", 8)) {
        int all = magic[7] == '3'; uint32_t total2 = get32(f);
        for (uint32_t r = 0; r < total2; r++) { int e = fgetc(f), flags = fgetc(f); fgetc(f); fgetc(f); uint32_t seed = get32(f); int64_t arg = (int64_t)get64(f), want = (int64_t)get64(f); uint8_t expect[20], digest[20];
            if (e < 0 || e >= m.entries || fread(expect, 1, 20, f) != 20) { printf("%s: FAILS (bad record %u)\n", argv[2], r); return 1; }
            if (flags & 8) fresh_surface(&m, state); if ((flags & 16) && fresh_holds(&m)) { fprintf(stderr, "cannot set up what the manifest holds\n"); return 2; }
            uint32_t count = m.recipe[e].fields ? recipe_numbers(&m, e, seed) : 0;
            int64_t got = call(&m, entry[e], state, 1, count, arg);
            if (got != want) { printf("%s: FAILS (record %u, entry %s: wrong answer)\n", argv[2], r, m.name[e]); return 1; }
            fingerprint(&m, state, all, digest); if (memcmp(digest, expect, 20)) { printf("%s: FAILS (record %u, entry %s: what it left behind differs)\n", argv[2], r, m.name[e]); return 1; } }
        printf("%s: PASSES (%u recorded checks, format %d)\n", argv[2], total2, all ? 3 : 2); return 0; }
    if (memcmp(magic, "TRPIECE1", 8)) { fprintf(stderr, "bad vectors file\n"); return 2; }
    uint32_t total = get32(f); uint8_t *explicit_state = calloc(1, m.state ? m.state : 1);
    for (uint32_t r = 0; r < total; r++) {
        int e = fgetc(f), flags = fgetc(f); fgetc(f); fgetc(f); uint32_t count = get32(f), seed = get32(f), span = get32(f); int64_t arg = (int64_t)get64(f), want = (int64_t)get64(f);
        if (e < 0 || e >= m.entries || count > 70000) { printf("%s: FAILS (bad record %u)\n", argv[2], r); return 1; }
        if (flags & 4) { if (fread(explicit_state, 1, m.state, f) != (size_t)m.state) return 2; memcpy(state, explicit_state, m.state); }
        if (flags & 2) memset(state, 0, m.state);
        if (flags & 8) fresh_surface(&m, state);
        if (flags & 1) generate(seed, span, count);
        if (flags & 16) as_text(count);
        if (flags & 32) as_path(count);
        if (flags & 64) as_image(count);
        if ((flags & 128) && as_fixture(&m, count)) { fprintf(stderr, "cannot read the fixture\n"); return 2; }
        int64_t got = call(&m, entry[e], state, flags & 1, count, arg);
        if (got != want) { printf("%s: FAILS (record %u, entry %s: wrong answer)\n", argv[2], r, m.name[e]); return 1; }
        if (m.state) { uint8_t digest[20], expect[20]; if (fread(expect, 1, 20, f) != 20) return 2; sha1_of(state, m.state, digest);
            if (memcmp(digest, expect, 20)) { printf("%s: FAILS (record %u, entry %s: state differs)\n", argv[2], r, m.name[e]); return 1; } }
    }
    printf("%s: PASSES (%u recorded checks)\n", argv[2], total); return 0;
}
