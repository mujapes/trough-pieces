/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { const uint8_t *d; uint64_t n, headers, body; int code; } reply;
static int lower(int c) { return c >= 'A' && c <= 'Z' ? c + 32 : c; }
static int open_reply(reply *r, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 12) return 0;
    r->d = b->bytes; r->n = b->size - 64; const uint8_t *d = r->d;
    if (!(d[0] == 'H' && d[1] == 'T' && d[2] == 'T' && d[3] == 'P' && d[4] == '/' && d[5] == '1' && d[6] == '.' && (d[7] == '0' || d[7] == '1') && d[8] == ' ')) return 0;
    if (d[9] < '1' || d[9] > '9' || d[10] < '0' || d[10] > '9' || d[11] < '0' || d[11] > '9') return 0;
    r->code = (d[9] - '0') * 100 + (d[10] - '0') * 10 + (d[11] - '0');
    uint64_t i = 12; while (i < r->n && d[i] != '\n') i++; if (i >= r->n) return 0; r->headers = i + 1;
    for (i = r->headers; i < r->n; ) {                          /* an empty line ends the headers */
        if (d[i] == '\n') { r->body = i + 1; return 1; }
        if (d[i] == '\r' && i + 1 < r->n && d[i + 1] == '\n') { r->body = i + 2; return 1; }
        while (i < r->n && d[i] != '\n') i++; i++; }
    return 0;
}
/* The value of a header: where it starts and how long it is. name is in lower case. */
static int find(const reply *r, const char *name, const int16_t *codes, int64_t count, uint64_t *at, uint64_t *len) {
    const uint8_t *d = r->d;
    for (uint64_t i = r->headers; i < r->body; ) { uint64_t end = i; while (end < r->body && d[end] != '\n') end++;
        uint64_t k = 0; int same = 1;
        if (name) { for (; name[k]; k++) if (i + k >= end || lower(d[i + k]) != name[k]) { same = 0; break; } }
        else { for (; (int64_t)k < count; k++) if (i + k >= end || lower(d[i + k]) != lower(codes[k])) { same = 0; break; } if (count <= 0) same = 0; }
        if (same && i + k < end && d[i + k] == ':') { uint64_t a = i + k + 1, z = end; while (a < z && (d[a] == ' ' || d[a] == '\t')) a++; while (z > a && (d[z - 1] == ' ' || d[z - 1] == '\t' || d[z - 1] == '\r')) z--; *at = a; *len = z - a; return 1; }
        i = end + 1; }
    return 0;
}
static int has(const reply *r, uint64_t at, uint64_t len, const char *word) {       /* does the value contain this word, any case? */
    uint64_t w = 0; while (word[w]) w++;
    for (uint64_t i = 0; i + w <= len; i++) { uint64_t k = 0; while (k < w && lower(r->d[at + i + k]) == word[k]) k++; if (k == w) return 1; }
    return 0;
}
int64_t status(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)out; (void)a;
    reply r; return open_reply(&r, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1)) ? r.code : -1; }
int64_t header(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    reply r; const block *in = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1); if (!open_reply(&r, in) || (const block *)out == in || out->size < 64) return -1;
    uint64_t at, len; if (!find(&r, 0, p + 1, n - 1, &at, &len) || len > out->size - 64) return -1;
    for (uint64_t i = 0; i < len; i++) ((uint8_t *)out)[64 + i] = r.d[at + i]; return (int64_t)len; }
int64_t body(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    reply r; const block *in = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1); if (!open_reply(&r, in) || (const block *)out == in || out->size < 64) return -1;
    uint8_t *o = (uint8_t *)out + 64; uint64_t room = out->size - 64, made = 0, at, len, i = r.body;
    if (find(&r, "transfer-encoding", 0, 0, &at, &len) && has(&r, at, len, "chunked")) {
        for (;;) { uint64_t size = 0; int digits = 0;
            while (i < r.n) { int c = r.d[i], v = c >= '0' && c <= '9' ? c - '0' : lower(c) >= 'a' && lower(c) <= 'f' ? lower(c) - 'a' + 10 : -1; if (v < 0) break; size = size * 16 + (uint64_t)v; digits++; i++; if (size > (1u << 30)) return -1; }
            if (!digits) return -1; while (i < r.n && r.d[i] != '\n') i++; if (i >= r.n) return -1; i++;      /* the rest of the size line */
            if (!size) return (int64_t)made;
            if (i + size > r.n || made + size > room) return -1; for (uint64_t k = 0; k < size; k++) o[made++] = r.d[i++];
            if (i < r.n && r.d[i] == '\r') i++; if (i >= r.n || r.d[i] != '\n') return -1; i++; }
    }
    uint64_t take = r.n - i;
    if (find(&r, "content-length", 0, 0, &at, &len)) { uint64_t v = 0; if (!len) return -1; for (uint64_t k = 0; k < len; k++) { int c = r.d[at + k]; if (c < '0' || c > '9') return -1; v = v * 10 + (uint64_t)(c - '0'); if (v > (1u << 30)) return -1; }
        if (v > take) return -1; take = v; }
    if (take > room) return -1; for (uint64_t k = 0; k < take; k++) o[k] = r.d[i + k]; return (int64_t)take;
}
int64_t packed(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)out; (void)a;
    reply r; if (!open_reply(&r, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1;
    uint64_t at, len; return find(&r, "content-encoding", 0, 0, &at, &len) && has(&r, at, len, "gzip") ? 1 : 0; }
