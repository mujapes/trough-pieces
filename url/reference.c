/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { const uint8_t *p; uint64_t n; int there; } part_;       /* a run of the address; "there" tells an empty part from a missing one */
typedef struct { part_ scheme, authority, path, query, fragment; } address;
#define LONGEST 2000
static uint8_t lower(uint8_t c) { return c >= 'A' && c <= 'Z' ? (uint8_t)(c + 32) : c; }
static int letter(uint8_t c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'); }
/* scheme ":" ["//" authority] path ["?" query] ["#" fragment]  (RFC 3986, appendix B) */
static void split(address *a, const uint8_t *s, uint64_t n) {
    uint64_t at = 0, i = 0; a->scheme = a->authority = a->query = a->fragment = (part_){0, 0, 0};
    if (n && letter(s[0])) { for (i = 1; i < n && (letter(s[i]) || (s[i] >= '0' && s[i] <= '9') || s[i] == '+' || s[i] == '-' || s[i] == '.'); i++) { } if (i < n && s[i] == ':') { a->scheme = (part_){s, i, 1}; at = i + 1; } }
    if (at + 1 < n && s[at] == '/' && s[at + 1] == '/') { at += 2; for (i = at; i < n && s[i] != '/' && s[i] != '?' && s[i] != '#'; i++) { } a->authority = (part_){s + at, i - at, 1}; at = i; }
    for (i = at; i < n && s[i] != '?' && s[i] != '#'; i++) { } a->path = (part_){s + at, i - at, 1}; at = i;
    if (at < n && s[at] == '?') { at++; for (i = at; i < n && s[i] != '#'; i++) { } a->query = (part_){s + at, i - at, 1}; at = i; }
    if (at < n && s[at] == '#') a->fragment = (part_){s + at + 1, n - at - 1, 1};
}
/* Takes "." and ".." steps out of a path, in place (RFC 3986 section 5.2.4). Returns the new length. */
static uint64_t undot(uint8_t *p, uint64_t n) {
    uint64_t in = 0, out = 0;
    while (in < n) {
        if (n - in >= 3 && p[in] == '.' && p[in + 1] == '.' && p[in + 2] == '/') in += 3;
        else if (n - in >= 2 && p[in] == '.' && p[in + 1] == '/') in += 2;
        else if (n - in >= 3 && p[in] == '/' && p[in + 1] == '.' && p[in + 2] == '/') in += 2;
        else if (n - in == 2 && p[in] == '/' && p[in + 1] == '.') { in += 1; p[in] = '/'; }
        else if ((n - in >= 4 && p[in] == '/' && p[in + 1] == '.' && p[in + 2] == '.' && p[in + 3] == '/') || (n - in == 3 && p[in] == '/' && p[in + 1] == '.' && p[in + 2] == '.')) {
            if (n - in == 3) { in += 2; p[in] = '/'; } else in += 3; while (out && p[out - 1] != '/') out--; if (out) out--; }
        else if ((n - in == 1 && p[in] == '.') || (n - in == 2 && p[in] == '.' && p[in + 1] == '.')) in = n;
        else { if (p[in] == '/') p[out++] = p[in++]; while (in < n && p[in] != '/') p[out++] = p[in++]; }
    }
    return out;
}
static const block *text_at(void *const *table, const int16_t *p, int64_t n, int which, const block *out) { const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size >= 64 && b->size <= 64 + LONGEST && b != out ? b : 0; }
/* Where a link points: the reference as found on a page, against the address of the page it was found on (RFC 3986 section 5.2). */
int64_t resolve(block *out, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused;
    const block *bb = text_at(table, p, n, 0, out), *rb = text_at(table, p, n, 1, out); if (!bb || !rb || out->size < 64) return -1;
    address B, R; split(&B, bb->bytes, bb->size - 64); split(&R, rb->bytes, rb->size - 64); if (!B.scheme.there) return -1;
    uint8_t path[2 * LONGEST + 2]; uint64_t pn = 0; part_ scheme = B.scheme, authority = B.authority, query = R.query;
    if (R.scheme.there) { scheme = R.scheme; authority = R.authority; for (uint64_t i = 0; i < R.path.n; i++) path[pn++] = R.path.p[i]; pn = undot(path, pn); }
    else if (R.authority.there) { authority = R.authority; for (uint64_t i = 0; i < R.path.n; i++) path[pn++] = R.path.p[i]; pn = undot(path, pn); }
    else if (!R.path.n) { for (uint64_t i = 0; i < B.path.n; i++) path[pn++] = B.path.p[i]; if (!R.query.there) query = B.query; }
    else { if (R.path.p[0] != '/') { if (B.authority.there && !B.path.n) path[pn++] = '/'; else { uint64_t keep = B.path.n; while (keep && B.path.p[keep - 1] != '/') keep--; for (uint64_t i = 0; i < keep; i++) path[pn++] = B.path.p[i]; } }
        for (uint64_t i = 0; i < R.path.n; i++) path[pn++] = R.path.p[i]; pn = undot(path, pn); }
    uint64_t total = scheme.n + 1 + (authority.there ? 2 + authority.n : 0) + pn + (query.there ? 1 + query.n : 0) + (R.fragment.there ? 1 + R.fragment.n : 0); if (out->size - 64 < total) return -1;
    /* The scheme and the site are written in small letters, whatever the page used: they mean the same in either case, and what
     * connects and what compares addresses should see one form. Anything before an @ in the authority is left as it is. */
    uint8_t *o = out->bytes; uint64_t at = 0; for (uint64_t i = 0; i < scheme.n; i++) o[at++] = lower(scheme.p[i]); o[at++] = ':';
    if (authority.there) { o[at++] = '/'; o[at++] = '/'; uint64_t user = 0; for (uint64_t i = 0; i < authority.n; i++) if (authority.p[i] == '@') user = i + 1; for (uint64_t i = 0; i < authority.n; i++) o[at++] = i < user ? authority.p[i] : lower(authority.p[i]); }
    for (uint64_t i = 0; i < pn; i++) o[at++] = path[i]; if (query.there) { o[at++] = '?'; for (uint64_t i = 0; i < query.n; i++) o[at++] = query.p[i]; } if (R.fragment.there) { o[at++] = '#'; for (uint64_t i = 0; i < R.fragment.n; i++) o[at++] = R.fragment.p[i]; }
    return (int64_t)at;
}
/* The site inside an authority: after any "user@", before any ":port"; an address in square brackets keeps them. */
static part_ site(part_ authority, part_ *port) { const uint8_t *s = authority.p; uint64_t n = authority.n, from = 0; *port = (part_){0, 0, 0}; for (uint64_t i = 0; i < n; i++) if (s[i] == '@') from = i + 1;
    uint64_t end = n; if (from < n && s[from] == '[') { end = from; while (end < n && s[end] != ']') end++; if (end < n) end++; } else { end = from; while (end < n && s[end] != ':') end++; }
    if (end < n && s[end] == ':') *port = (part_){s + end + 1, n - end - 1, 1}; return (part_){s + from, end - from, 1}; }
/* A part of an address, copied out: 0 scheme, 1 site, 2 path, 3 query, 4 fragment, 5 what to ask the server for (path, "/" if empty, then "?query"). */
int64_t part(block *out, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused;
    const block *b = text_at(table, p, n, 0, out); if (!b || out->size < 64) return -1; address a; split(&a, b->bytes, b->size - 64); part_ port, want; int which = n > 1 ? p[1] : -1; uint64_t at = 0; uint8_t *o = out->bytes;
    if (which == 5) { uint64_t total = (a.path.n ? a.path.n : 1) + (a.query.there ? 1 + a.query.n : 0); if (out->size - 64 < total) return -1; if (!a.path.n) o[at++] = '/'; for (uint64_t i = 0; i < a.path.n; i++) o[at++] = a.path.p[i];
        if (a.query.there) { o[at++] = '?'; for (uint64_t i = 0; i < a.query.n; i++) o[at++] = a.query.p[i]; } return (int64_t)at; }
    want = which == 0 ? a.scheme : which == 1 ? (a.authority.there ? site(a.authority, &port) : a.authority) : which == 2 ? a.path : which == 3 ? a.query : which == 4 ? a.fragment : (part_){0, 0, 0};
    if (which < 0 || which > 4 || !want.there || out->size - 64 < want.n) return -1; for (uint64_t i = 0; i < want.n; i++) o[i] = want.p[i]; return (int64_t)want.n;
}
/* The port to connect to: the one written in the address, else 443 for https and 80 for http. -1 if there is none to be had. */
int64_t port(block *unused, const int16_t *p, int64_t n, int64_t a_, void *const *table) { (void)unused; (void)a_;
    const block *b = text_at(table, p, n, 0, 0); if (!b) return -1; address a; split(&a, b->bytes, b->size - 64); if (!a.authority.there) return -1; part_ port; site(a.authority, &port);
    if (port.there && port.n) { int64_t v = 0; for (uint64_t i = 0; i < port.n; i++) { if (port.p[i] < '0' || port.p[i] > '9' || v > 65535) return -1; v = v * 10 + (port.p[i] - '0'); } return v <= 65535 ? v : -1; }
    const uint8_t *s = a.scheme.p; if (a.scheme.n == 5 && (s[0] | 32) == 'h' && (s[1] | 32) == 't' && (s[2] | 32) == 't' && (s[3] | 32) == 'p' && (s[4] | 32) == 's') return 443;
    if (a.scheme.n == 4 && (s[0] | 32) == 'h' && (s[1] | 32) == 't' && (s[2] | 32) == 't' && (s[3] | 32) == 'p') return 80; return -1;
}
