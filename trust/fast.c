/* reference.c with one shortcut: a root is looked at properly only if its name, found directly in its bytes, is the issuer's. Same answers. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint8_t head[64]; uint8_t b[8192]; } big;              /* blocks of this piece's own, to hand to other pieces */
typedef struct { uint8_t head[64]; uint8_t b[704]; } mid;
static void head(uint8_t *h, uint64_t n) { for (int i = 0; i < 64; i++) h[i] = 0; h[0] = 2; uint64_t z = 64 + n; for (int i = 0; i < 8; i++) h[16 + i] = (uint8_t)(z >> (8 * i)); }
/* A table of our own to hand a callee: the callee's sockets must be the real ones (rsa calls hash through its table; with a bare
 * table that call went to whatever the stack held), and handles 1 and up are ours to fill. */
#define OWN(mine) void *mine[512]; for (int socket_ = 0; socket_ < 256; socket_++) mine[socket_] = table[socket_];
static int64_t fact(void *const *table, const void *cert, int which) { OWN(mine) mine[257] = (void *)cert; int16_t q[2] = {1, (int16_t)which}; return ((trough_block)table[SLOT_CERT_NUMBER])(0, q, 2, 0, (void *const *)mine); }
/* A part of a certificate into one of our blocks, which then holds exactly that part. -1 if absent or too long. */
static int64_t part(void *const *table, const void *cert, int which, uint8_t *blk, uint64_t room) { OWN(mine) mine[257] = (void *)cert; int16_t q[2] = {1, (int16_t)which}; head(blk, room);
    int64_t n = ((trough_block)table[SLOT_CERT_BYTES])(blk, q, 2, 0, (void *const *)mine); if (n >= 0) head(blk, (uint64_t)n); return n; }
static int digest(void *const *table, int bytes, const void *of, mid *out) { OWN(mine) mine[257] = (void *)of; int16_t q[1] = {1}; head(out->head, 704);
    if (((trough_block)table[bytes == 32 ? SLOT_HASH_SHA256 : bytes == 48 ? SLOT_HASH_SHA384 : SLOT_HASH_SHA512])(out, q, 1, 0, (void *const *)mine) != bytes) return 0; head(out->head, (uint64_t)bytes); return 1; }
static int same(const uint8_t *a, const uint8_t *b) { uint64_t n = 0; for (int i = 0; i < 8; i++) n |= (uint64_t)a[16 + i] << (8 * i); for (uint64_t i = 16; i < 24; i++) if (a[i] != b[i]) return 0; for (uint64_t i = 64; i < n; i++) if (a[i] != b[i]) return 0; return 1; }   /* two of our blocks hold the same bytes */
/* Is the digest signed, by the key in `signer`, with this signature? how: 1 RSA PKCS1, 2 RSA PSS, 3 ECDSA. 1 yes, 0 no, -1 cannot tell. */
static int64_t check(void *const *table, const void *signer, int how, mid *dg, const void *sig_a, const void *sig_b) { OWN(mine) mid ka, kb; int64_t key = fact(table, signer, 1);
    if (part(table, signer, 4, ka.head, 704) < 0 || part(table, signer, 5, kb.head, 704) < 0) return -1; mine[257] = &ka; mine[258] = &kb; mine[259] = (void *)sig_a; mine[260] = (void *)sig_b; mine[261] = dg;
    if (how <= 2) { if (key != 1) return 0; int16_t q[4] = {1, 2, 3, 5}; return ((trough_block)table[how == 1 ? SLOT_RSA_VERIFY_PKCS1 : SLOT_RSA_VERIFY_PSS])(0, q, 4, 0, (void *const *)mine); }
    if (key != 2 && key != 3) return 0; int16_t q[6] = {(int16_t)(key == 2 ? 256 : 384), 1, 2, 3, 4, 5}; return ((trough_block)table[SLOT_ECDSA_VERIFY])(0, q, 6, 0, (void *const *)mine); }
/* Did `parent` sign `child`? The child must name the parent as its issuer, and its signature must verify under the parent's key. */
static int signed_by(void *const *table, const void *child, const void *parent) {
    mid issuer, subject, dg, sa, sb; big tbs; if (part(table, child, 6, issuer.head, 704) < 0 || part(table, parent, 7, subject.head, 704) < 0 || !same(issuer.head, subject.head)) return 0;
    int64_t kind = fact(table, child, 0); if (kind < 1 || kind > 6 || part(table, child, 0, tbs.head, 8192) < 0 || !digest(table, kind == 1 || kind == 4 ? 32 : kind == 2 || kind == 5 ? 48 : 64, &tbs, &dg)) return 0;
    if (kind <= 3) { if (part(table, child, 1, sa.head, 704) < 0) return 0; return check(table, parent, 1, &dg, &sa, &sa) == 1; }
    if (part(table, child, 2, sa.head, 704) < 0 || part(table, child, 3, sb.head, 704) < 0) return 0; return check(table, parent, 3, &dg, &sa, &sb) == 1; }
/* One DER item at p (n bytes left): its whole length, or 0 if it cannot be followed. */
static uint64_t whole(const uint8_t *p, uint64_t n, uint64_t *headlen) { if (n < 2) return 0; uint64_t len = p[1], h = 2; if (len & 0x80) { uint64_t c = len & 0x7f; if (c < 1 || c > 3 || n < 2 + c) return 0; len = 0; for (uint64_t i = 0; i < c; i++) len = (len << 8) | p[2 + i]; h = 2 + c; } if (h + len > n) return 0; *headlen = h; return h + len; }
/* Could this root be the one named? 0 only when its subject was found and differs from the wanted name (one of our blocks). 1 otherwise. */
static int maybe_named(const uint8_t *r, uint64_t n, const uint8_t *wanted) {
    uint64_t h, w = whole(r, n, &h); if (!w) return 1; const uint8_t *p = r + h; uint64_t left = w - h; w = whole(p, left, &h); if (!w || p[0] != 0x30) return 1; p += h; left = w - h;      /* into the signed part */
    if (left && p[0] == 0xa0) { w = whole(p, left, &h); if (!w) return 1; p += w; left -= w; }                                                                                         /* version */
    for (int skip = 0; skip < 4; skip++) { w = whole(p, left, &h); if (!w) return 1; p += w; left -= w; }                                                                               /* serial, signature kind, issuer, dates */
    w = whole(p, left, &h); if (!w || p[0] != 0x30) return 1; uint64_t want = 0; for (int i = 0; i < 8; i++) want |= (uint64_t)wanted[16 + i] << (8 * i); want -= 64;
    if (w != want) return 0; for (uint64_t i = 0; i < w; i++) if (p[i] != wanted[64 + i]) return 0; return 1; }
static int in_date(void *const *table, const void *cert, int64_t now) { int64_t from = fact(table, cert, 3), until = fact(table, cert, 4); return from >= 0 && until >= 0 && now >= from && now <= until; }
/* The chain: leaf first, then whatever else the server sent. Reasons for no: -2 the name is not covered, -3 a certificate is out of date,
 * -4 a certificate is used for something it does not allow (or carries a rule we cannot follow), -5 no path to a trusted root. -1: unusable input. */
int64_t chain(block *unused, const int16_t *p, int64_t n, int64_t now, void *const *table) { (void)unused;
    const block *name = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1), *roots = (const block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); if (n < 3 || n > 2 + 8 || !name || !roots || roots->kind != 2 || roots->size < 64) return -1;
    const void *sent[8]; int count = (int)n - 2, used[8] = {1}; for (int i = 0; i < count; i++) { sent[i] = TROUGH_BLOCK(table, p[2 + i]); if (!sent[i] || fact(table, sent[i], 8) < 0) return -1; }
    { OWN(mine) mine[257] = (void *)sent[0]; mine[258] = (void *)name; int16_t q[2] = {1, 2}; int64_t c = ((trough_block)table[SLOT_CERT_COVERS])(0, q, 2, 0, (void *const *)mine); if (c < 0) return -1; if (!c) return -2; }
    if (!in_date(table, sent[0], now)) return -3; if (fact(table, sent[0], 7) != 0) return -4; { int64_t use = fact(table, sent[0], 6); if (use >= 0 && !(use & 0x80)) return -4; }
    const void *current = sent[0]; int below = 0;
    for (int depth = 0; depth < 8; depth++) {
        /* a trusted root that signed the current certificate ends the search */
        mid issuer, subject; big root; if (part(table, current, 6, issuer.head, 704) < 0) return -1; const uint8_t *r = roots->bytes; uint64_t left = roots->size - 64;
        while (left > 4) { uint64_t len; if (r[0] != 0x30) break; if (r[1] < 0x80) len = 2 + r[1]; else if (r[1] == 0x81) len = 3 + (uint64_t)r[2]; else if (r[1] == 0x82) len = 4 + (((uint64_t)r[2] << 8) | r[3]); else break; if (len > left) break;
            /* Most roots are not the issuer. Find the root's name in its bytes directly and compare before doing anything else with it:
             * only a root whose name matches (or whose bytes this quick walk cannot follow) gets the full treatment below. */
            if (len <= 8192 && maybe_named(r, len, issuer.head)) { head(root.head, len); for (uint64_t i = 0; i < len; i++) root.b[i] = r[i];
                if (part(table, &root, 7, subject.head, 704) >= 0 && same(issuer.head, subject.head) && in_date(table, &root, now) && signed_by(table, current, &root)) return 1; }
            r += len; left -= len; }
        /* otherwise one of the certificates the server sent must have signed it, and must be allowed to */
        int next = -1; for (int i = 1; i < count && next < 0; i++) if (!used[i] && signed_by(table, current, sent[i])) next = i; if (next < 0) return -5; used[next] = 1; const void *up = sent[next];
        if (!in_date(table, up, now)) return -3; if (fact(table, up, 2) != 1 || fact(table, up, 7) != 0) return -4; { int64_t use = fact(table, up, 6); if (use >= 0 && !(use & 0x04)) return -4; }
        { int64_t most = fact(table, up, 5); if (most >= 0 && most < below) return -4; } below++; current = up; }
    return -5;
}
/* The server's own signature over the handshake so far (TLS 1.3 CertificateVerify). scheme: 0x0804 RSA-PSS with SHA-256, 0x0403 ECDSA P-256 with SHA-256, 0x0503 ECDSA P-384 with SHA-384. */
int64_t signed_handshake(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    const void *cert = TROUGH_BLOCK(table, n > 0 ? p[0] : -1); int scheme = n > 1 ? p[1] : 0; const block *content = (const block *)TROUGH_BLOCK(table, n > 2 ? p[2] : -1), *sig = (const block *)TROUGH_BLOCK(table, n > 3 ? p[3] : -1);
    if (!cert || !content || content->kind != 2 || !sig || sig->kind != 2 || sig->size <= 64 || sig->size > 64 + 600) return -1; int64_t key = fact(table, cert, 1); if (key < 0) return -1; mid dg;
    if (scheme == 0x0804) { if (key != 1 || !digest(table, 32, content, &dg)) return key != 1 ? 0 : -1; return check(table, cert, 2, &dg, sig, sig); }
    if ((scheme == 0x0403 && key == 2) || (scheme == 0x0503 && key == 3)) { if (!digest(table, key == 2 ? 32 : 48, content, &dg)) return -1;
        const uint8_t *d = sig->bytes; uint64_t dn = sig->size - 64, at = 2; mid r, s; if (dn < 8 || d[0] != 0x30) return 0; if (d[1] & 0x80) { if (d[1] != 0x81) return 0; at = 3; if ((uint64_t)d[2] + 3 != dn) return 0; } else if ((uint64_t)d[1] + 2 != dn) return 0;
        mid *both[2] = {&r, &s}; for (int k = 0; k < 2; k++) { if (at + 2 > dn || d[at] != 2) return 0; uint64_t len = d[at + 1]; at += 2; if (!len || len > 80 || at + len > dn) return 0; head(both[k]->head, len); for (uint64_t i = 0; i < len; i++) both[k]->b[i] = d[at + i]; at += len; }
        if (at != dn) return 0; return check(table, cert, 3, &dg, &r, &s); }
    return scheme == 0x0403 || scheme == 0x0503 ? 0 : -1;
}
