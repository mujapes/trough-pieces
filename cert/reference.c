/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { const uint8_t *p; uint64_t n; } span;                  /* a run of bytes inside the certificate */
/* One item of DER: a tag, a length, the contents. Takes it off the front of `from`; `whole` gets tag and length too. 0 if malformed. */
static int item(span *from, uint32_t *tag, span *inside, span *whole) {
    if (from->n < 2) return 0; const uint8_t *p = from->p; uint64_t len = p[1], head = 2; *tag = p[0]; if ((p[0] & 31) == 31) return 0;
    if (len & 0x80) { uint32_t count = (uint32_t)(len & 0x7f); if (count < 1 || count > 3 || from->n < 2 + count) return 0; len = 0; for (uint32_t i = 0; i < count; i++) len = (len << 8) | p[2 + i]; head = 2 + count; if (len < 128) return 0; }
    if (from->n < head + len) return 0; inside->p = p + head; inside->n = len; if (whole) { whole->p = p; whole->n = head + len; } from->p += head + len; from->n -= head + len; return 1;
}
static int is(span s, const uint8_t *oid, uint64_t n) { if (s.n != n) return 0; for (uint64_t i = 0; i < n; i++) if (s.p[i] != oid[i]) return 0; return 1; }
typedef struct { span tbs, signature, r, s, key_a, key_b, issuer, subject, names, serial; int sig_kind, key_kind, ca, path, usage, has_usage, strange, version; int64_t from, until; } cert;
enum { SIG_RSA_SHA256 = 1, SIG_RSA_SHA384 = 2, SIG_RSA_SHA512 = 3, SIG_ECDSA_SHA256 = 4, SIG_ECDSA_SHA384 = 5, SIG_ECDSA_SHA512 = 6, KEY_RSA = 1, KEY_P256 = 2, KEY_P384 = 3 };
static const uint8_t RSA_[8] = {0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01}, EC_SIG[7] = {0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03}, EC_KEY[7] = {0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01},
                     P256[8] = {0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07}, P384[5] = {0x2b, 0x81, 0x04, 0x00, 0x22};
static int sig_kind(span alg) { span oid, rest = alg; uint32_t tag; if (!item(&rest, &tag, &oid, 0) || tag != 6) return 0;
    if (oid.n == 9 && is((span){oid.p, 8}, RSA_, 8)) return oid.p[8] == 11 ? SIG_RSA_SHA256 : oid.p[8] == 12 ? SIG_RSA_SHA384 : oid.p[8] == 13 ? SIG_RSA_SHA512 : 0;
    if (oid.n == 8 && is((span){oid.p, 7}, EC_SIG, 7)) return oid.p[7] == 2 ? SIG_ECDSA_SHA256 : oid.p[7] == 3 ? SIG_ECDSA_SHA384 : oid.p[7] == 4 ? SIG_ECDSA_SHA512 : 0; return 0; }
static int two_digits(const uint8_t *p, int *ok) { if (p[0] < '0' || p[0] > '9' || p[1] < '0' || p[1] > '9') *ok = 0; return (p[0] - '0') * 10 + (p[1] - '0'); }
static int64_t when(uint32_t tag, span t) {                             /* seconds since the start of 1970, or -1 */
    int ok = 1, year; const uint8_t *p = t.p; if (tag == 0x17 && t.n == 13) { year = two_digits(p, &ok); year += year < 50 ? 2000 : 1900; p += 2; } else if (tag == 0x18 && t.n == 15) { year = two_digits(p, &ok) * 100 + two_digits(p + 2, &ok); p += 4; } else return -1;
    int month = two_digits(p, &ok), day = two_digits(p + 2, &ok), hour = two_digits(p + 4, &ok), minute = two_digits(p + 6, &ok), second = two_digits(p + 8, &ok);
    if (!ok || p[10] != 'Z' || month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 || second > 60 || year < 1970) return -1;
    int64_t y = year - (month <= 2), era = y / 400, yoe = y - era * 400, doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1, doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return (era * 146097 + doe - 719468) * 86400 + hour * 3600 + minute * 60 + second;
}
static int integer(span *from, span *value) { uint32_t tag; if (!item(from, &tag, value, 0) || tag != 2 || !value->n) return 0; return 1; }
static int read_cert(cert *c, const block *b) {
    if (!b || b->kind != 2 || b->size < 64 + 16) return 0; span all = {b->bytes, b->size - 64}, outer, tbs, alg, sig, x, y; uint32_t tag;
    if (!item(&all, &tag, &outer, 0) || tag != 0x30 || all.n) return 0;
    if (!item(&outer, &tag, &tbs, &c->tbs) || tag != 0x30 || !item(&outer, &tag, &alg, 0) || tag != 0x30 || !item(&outer, &tag, &sig, 0) || tag != 3 || outer.n || sig.n < 2 || sig.p[0]) return 0;
    c->sig_kind = sig_kind(alg); c->signature = (span){sig.p + 1, sig.n - 1}; c->r = c->s = (span){0, 0};
    if (c->sig_kind >= SIG_ECDSA_SHA256) { span pair = c->signature, in; if (!item(&pair, &tag, &in, 0) || tag != 0x30 || pair.n || !integer(&in, &c->r) || !integer(&in, &c->s) || in.n) return 0; }
    c->version = 1; x = tbs; if (x.n && x.p[0] == 0xa0) { span v, n; if (!item(&tbs, &tag, &v, 0) || !integer(&v, &n) || n.n != 1) return 0; c->version = n.p[0] + 1; }
    span inner_alg, validity, spki, t; if (!integer(&tbs, &c->serial) || !item(&tbs, &tag, &inner_alg, 0) || tag != 0x30) return 0;
    if (inner_alg.n != alg.n) return 0; for (uint64_t i = 0; i < alg.n; i++) if (inner_alg.p[i] != alg.p[i]) return 0;                 /* the signed part must name the same signature kind as the outside */
    if (!item(&tbs, &tag, &x, &c->issuer) || tag != 0x30 || !item(&tbs, &tag, &validity, 0) || tag != 0x30) return 0;
    if (!item(&validity, &tag, &t, 0)) return 0; c->from = when(tag, t); if (!item(&validity, &tag, &t, 0) || validity.n) return 0; c->until = when(tag, t); if (c->from < 0 || c->until < 0) return 0;
    if (!item(&tbs, &tag, &x, &c->subject) || tag != 0x30 || !item(&tbs, &tag, &spki, 0) || tag != 0x30) return 0;
    span key_alg, key, oid, params; if (!item(&spki, &tag, &key_alg, 0) || tag != 0x30 || !item(&spki, &tag, &key, 0) || tag != 3 || spki.n || key.n < 2 || key.p[0]) return 0; key.p++; key.n--;
    c->key_kind = 0; c->key_a = c->key_b = (span){0, 0}; if (!item(&key_alg, &tag, &oid, 0) || tag != 6) return 0;
    if (oid.n == 9 && is((span){oid.p, 8}, RSA_, 8) && oid.p[8] == 1) { span seq; if (!item(&key, &tag, &seq, 0) || tag != 0x30 || key.n || !integer(&seq, &c->key_a) || !integer(&seq, &c->key_b) || seq.n) return 0; c->key_kind = KEY_RSA; }
    else if (is(oid, EC_KEY, 7)) { if (!item(&key_alg, &tag, &params, 0) || tag != 6) return 0; int size = is(params, P256, 8) ? 32 : is(params, P384, 5) ? 48 : 0;
        if (size && key.n == 1 + 2 * (uint64_t)size && key.p[0] == 4) { c->key_kind = size == 32 ? KEY_P256 : KEY_P384; c->key_a = (span){key.p + 1, (uint64_t)size}; c->key_b = (span){key.p + 1 + size, (uint64_t)size}; } }
    c->ca = 0; c->path = -1; c->usage = 0; c->has_usage = 0; c->strange = 0; c->names = (span){0, 0};
    while (tbs.n) { span part; if (!item(&tbs, &tag, &part, 0)) return 0; if (tag != 0xa3) continue; span list, ext; if (c->version != 3 || !item(&part, &tag, &list, 0) || tag != 0x30 || part.n) return 0;
        while (list.n) { span id, value; int critical = 0; if (!item(&list, &tag, &ext, 0) || tag != 0x30 || !item(&ext, &tag, &id, 0) || tag != 6 || !item(&ext, &tag, &value, 0)) return 0;
            if (tag == 1) { if (value.n != 1) return 0; critical = value.p[0] != 0; if (!item(&ext, &tag, &value, 0)) return 0; } if (tag != 4 || ext.n) return 0;
            int which = id.n == 3 && id.p[0] == 0x55 && id.p[1] == 0x1d ? id.p[2] : 0;
            if (which == 19) { span bc, flag; if (!item(&value, &tag, &bc, 0) || tag != 0x30) return 0; if (bc.n && bc.p[0] == 1) { if (!item(&bc, &tag, &flag, 0) || flag.n != 1) return 0; c->ca = flag.p[0] != 0; }
                if (bc.n) { span len; if (!integer(&bc, &len) || len.n > 2) return 0; c->path = len.n == 1 ? len.p[0] : (len.p[0] << 8) | len.p[1]; } }
            else if (which == 15) { span bits; if (!item(&value, &tag, &bits, 0) || tag != 3 || bits.n < 2) return 0; c->has_usage = 1; c->usage = bits.p[1] | (bits.n > 2 ? bits.p[2] << 8 : 0); }
            else if (which == 17) { if (!item(&value, &tag, &c->names, 0) || tag != 0x30) return 0; }
            else if (which == 37 || which == 32 || which == 14 || which == 35 || which == 31) { }                                          /* purposes, policies, key identifiers, revocation addresses: read by others or not at all */
            else if (critical) c->strange = 1; } }
    return 1;
}
static int put(block *out, span s) { if (!s.p || out->size < 64 + s.n) return -1; for (uint64_t i = 0; i < s.n; i++) out->bytes[i] = s.p[i]; return (int)s.n; }
int64_t number(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    cert c; if (!read_cert(&c, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1))) return -1;
    switch (n > 1 ? p[1] : -1) { case 0: return c.sig_kind; case 1: return c.key_kind; case 2: return c.ca; case 3: return c.from; case 4: return c.until; case 5: return c.path; case 6: return c.has_usage ? c.usage : -1; case 7: return c.strange; case 8: return c.version;
        case 9: { if (c.issuer.n != c.subject.n) return 0; for (uint64_t i = 0; i < c.issuer.n; i++) if (c.issuer.p[i] != c.subject.p[i]) return 0; return 1; } }
    return -1;
}
int64_t bytes(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *b = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1); cert c; if ((const block *)out == b || out->size < 64 || !read_cert(&c, b)) return -1;
    switch (n > 1 ? p[1] : -1) { case 0: return put(out, c.tbs); case 1: return put(out, c.signature); case 2: return put(out, c.r); case 3: return put(out, c.s); case 4: return put(out, c.key_a); case 5: return put(out, c.key_b);
        case 6: return put(out, c.issuer); case 7: return put(out, c.subject); case 8: return put(out, c.serial); }
    return -1;
}
static uint8_t lower(uint8_t ch) { return ch >= 'A' && ch <= 'Z' ? (uint8_t)(ch + 32) : ch; }
static int same(const uint8_t *a, const uint8_t *b, uint64_t n) { for (uint64_t i = 0; i < n; i++) if (lower(a[i]) != lower(b[i])) return 0; return 1; }
/* Does the certificate cover this site name? Only its list of DNS names counts. "*.example.com" covers exactly one more label. */
int64_t covers(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    cert c; const block *name = (const block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); if (!read_cert(&c, (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1)) || !name || name->kind != 2 || name->size <= 64 || name->size > 64 + 253) return -1;
    const uint8_t *h = name->bytes; uint64_t hn = name->size - 64; if (h[hn - 1] == '.') hn--; span list = c.names, entry; uint32_t tag;
    while (list.n) { if (!item(&list, &tag, &entry, 0)) return -1; if (tag != 0x82 || !entry.n) continue;
        if (entry.n == hn && same(entry.p, h, hn)) return 1;
        if (entry.n > 2 && entry.p[0] == '*' && entry.p[1] == '.') { uint64_t dot = 0; while (dot < hn && h[dot] != '.') dot++; if (dot > 0 && dot < hn && hn - dot == entry.n - 1 && same(entry.p + 1, h + dot, hn - dot)) return 1; } }
    return 0;
}
