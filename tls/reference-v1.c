/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint8_t head[64]; uint8_t b[320]; } small;              /* a block of this piece's own, to hand to another piece */
#define TRANSCRIPT 32768
#define RECORD 16384
typedef struct {
    uint32_t version, stage, out_len, plain_len; uint64_t size; uint32_t used, unverified, alert, certificate_at, certificate_len, reserved[7];   /* 64 bytes the host may read */
    uint8_t secret[32], c_hs[32], s_hs[32], master[32], rkey[32], wkey[32], riv[12], wiv[12]; uint64_t rseq, wseq; uint32_t tn, hn, pad[2];
    uint8_t transcript_head[64], transcript[TRANSCRIPT], hs[TRANSCRIPT], in_head[64], in[RECORD + 512], out_head[64], out[RECORD + 512];
} state;
enum { NEW = 0, HELLO_SENT = 1, KEYS = 2, CONNECTED = 3, CLOSED = 4, FAILED = 5 };
static void head(uint8_t *h, uint64_t n) { for (int i = 0; i < 64; i++) h[i] = 0; h[0] = 2; uint64_t z = 64 + n; for (int i = 0; i < 8; i++) h[16 + i] = (uint8_t)(z >> (8 * i)); }
static void put(small *s, const uint8_t *d, uint64_t n) { head(s->head, n); for (uint64_t i = 0; i < n && i < 320; i++) s->b[i] = d[i]; }
static int64_t on(void *const *table, int slot, void *out, const int16_t *nums, int64_t n, void **mine) { return ((trough_block)table[slot])(out, nums, n, 0, (void *const *)mine); }
/* 32-byte answers of the hash piece, with this piece's own blocks at handles 1 to 3 of a table of its own */
static int hash_transcript(void *const *table, state *st, uint8_t *out32) { void *mine[512]; small o; head(o.head, 320); head(st->transcript_head, st->tn); mine[257] = st->transcript_head; int16_t q[1] = {1};
    if (on(table, SLOT_HASH_SHA256, &o, q, 1, mine) != 32) return 0; for (int i = 0; i < 32; i++) out32[i] = o.b[i]; return 1; }
static int hmac(void *const *table, const uint8_t *key, const uint8_t *msg, uint64_t n, uint8_t *out32) { void *mine[512]; small o, k, m; head(o.head, 320); put(&k, key, 32); put(&m, msg, n); mine[257] = &k; mine[258] = &m; int16_t q[2] = {1, 2};
    if (on(table, SLOT_HASH_HMAC_SHA256, &o, q, 2, mine) != 32) return 0; for (int i = 0; i < 32; i++) out32[i] = o.b[i]; return 1; }
static int expand(void *const *table, const uint8_t *secret, const char *label, const uint8_t *ctx, uint64_t cn, int want, uint8_t *out) { void *mine[512]; small o, s, l, c; head(o.head, 320); put(&s, secret, 32);
    uint64_t ln = 0; while (label[ln]) ln++; put(&l, (const uint8_t *)label, ln); put(&c, ctx, cn); mine[257] = &s; mine[258] = &l; mine[259] = &c; int16_t q[4] = {1, 2, 3, (int16_t)want};
    if (on(table, SLOT_HASH_EXPAND_LABEL, &o, q, 4, mine) != want) return 0; for (int i = 0; i < want; i++) out[i] = o.b[i]; return 1; }
static int traffic(void *const *table, const uint8_t *secret, uint8_t *key, uint8_t *iv) { return expand(table, secret, "key", 0, 0, 32, key) && expand(table, secret, "iv", 0, 0, 12, iv); }
/* One record sealed or opened in the state's working blocks. The nonce is the iv with the record count folded into its end. */
static int64_t crypt(void *const *table, state *st, int sealing, const uint8_t *key, const uint8_t *iv, uint64_t seq, const uint8_t *header, uint64_t n) {
    void *mine[512]; small k, nonce, extra; put(&k, key, 32); uint8_t no[12]; for (int i = 0; i < 12; i++) no[i] = iv[i]; for (int i = 0; i < 8; i++) no[11 - i] ^= (uint8_t)(seq >> (8 * i));
    put(&nonce, no, 12); put(&extra, header, 5); head(st->in_head, n); head(st->out_head, RECORD + 512); mine[257] = &k; mine[258] = &nonce; mine[259] = &extra; mine[260] = st->in_head; int16_t q[4] = {1, 2, 3, 4};
    return on(table, sealing ? SLOT_SEAL_SEAL : SLOT_SEAL_OPEN, st->out_head, q, 4, mine);
}
static int add_transcript(state *st, const uint8_t *d, uint64_t n) { if (st->tn + n > TRANSCRIPT) return 0; for (uint64_t i = 0; i < n; i++) st->transcript[st->tn + i] = d[i]; st->tn += (uint32_t)n; return 1; }
static int64_t fail(state *st, uint32_t why) { st->stage = FAILED; st->alert = why; return -1; }
int64_t migrate(state *st, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    uint8_t *b = (uint8_t *)st; for (uint64_t i = 0; i < sizeof(state); i++) b[i] = 0; st->version = 1; st->size = sizeof(state); return 1; }
/* The opening message. seed: 96 fresh random bytes (32 for the hello, 32 the exchange secret, 32 a session label). */
int64_t begin(state *st, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *seed = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1), *name = (const block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1); block *out = (block *)TROUGH_BLOCK(table, n > 2 ? p[2] : -1);
    if (st->version != 1 || st->stage != NEW || !seed || seed->kind != 2 || seed->size != 64 + 96 || !name || name->kind != 2 || name->size < 65 || name->size > 64 + 253 || !out || (out->kind != 2 && out->kind != 5) || out->size < 64 + 512) return -1;
    uint64_t nn = name->size - 64; for (int i = 0; i < 32; i++) st->secret[i] = seed->bytes[32 + i];
    void *mine[512]; small pub, sec; head(pub.head, 320); put(&sec, st->secret, 32); mine[257] = &sec; int16_t q[1] = {1}; if (on(table, SLOT_EXCHANGE_PUBLIC, &pub, q, 1, mine) != 32) return fail(st, 1);
    uint8_t *m = st->transcript; uint32_t at = 4;
    m[at++] = 3; m[at++] = 3; for (int i = 0; i < 32; i++) m[at++] = seed->bytes[i]; m[at++] = 32; for (int i = 0; i < 32; i++) m[at++] = seed->bytes[64 + i];
    m[at++] = 0; m[at++] = 2; m[at++] = 0x13; m[at++] = 0x03; m[at++] = 1; m[at++] = 0;                     /* one cipher: ChaCha20-Poly1305 with SHA-256; no compression */
    uint32_t ext = at; at += 2;
    m[at++] = 0; m[at++] = 0; m[at++] = (uint8_t)((nn + 5) >> 8); m[at++] = (uint8_t)(nn + 5); m[at++] = (uint8_t)((nn + 3) >> 8); m[at++] = (uint8_t)(nn + 3); m[at++] = 0; m[at++] = (uint8_t)(nn >> 8); m[at++] = (uint8_t)nn; for (uint64_t i = 0; i < nn; i++) m[at++] = name->bytes[i];
    static const uint8_t fixed[] = { 0, 43, 0, 3, 2, 3, 4,   0, 10, 0, 4, 0, 2, 0, 29,   0, 13, 0, 16, 0, 14, 4, 3, 8, 4, 4, 1, 5, 3, 8, 5, 8, 6, 8, 7,   0, 51, 0, 38, 0, 36, 0, 29, 0, 32 };   /* TLS 1.3; X25519; signature kinds; our key share */
    for (uint32_t i = 0; i < sizeof fixed; i++) m[at++] = fixed[i]; for (int i = 0; i < 32; i++) m[at++] = pub.b[i];
    m[ext] = (uint8_t)((at - ext - 2) >> 8); m[ext + 1] = (uint8_t)(at - ext - 2); m[0] = 1; m[1] = 0; m[2] = (uint8_t)((at - 4) >> 8); m[3] = (uint8_t)(at - 4); st->tn = at;
    out->bytes[0] = 22; out->bytes[1] = 3; out->bytes[2] = 1; out->bytes[3] = (uint8_t)(at >> 8); out->bytes[4] = (uint8_t)at; for (uint32_t i = 0; i < at; i++) out->bytes[5 + i] = m[i];
    st->stage = HELLO_SENT; st->out_len = at + 5; st->unverified = 1; return at + 5;
}
/* The server's first message: its half of the exchange. From it and ours, the keys for the rest of the handshake. */
static int server_hello(void *const *table, state *st, const uint8_t *m, uint32_t n) {
    static const uint8_t retry[8] = {0xcf, 0x21, 0xad, 0x74, 0xe5, 0x9a, 0x61, 0x11}; uint32_t at = 4; if (n < 4 + 2 + 32 + 1 || m[0] != 2) return 0;
    int again = 1; for (int i = 0; i < 8; i++) if (m[6 + i] != retry[i]) again = 0; if (again) return 0;                 /* a request to start over with other settings: not handled yet */
    at += 2 + 32; uint32_t sid = m[at++]; at += sid; if (at + 3 + 2 > n || m[at] != 0x13 || m[at + 1] != 0x03 || m[at + 2] != 0) return 0; at += 3;
    uint32_t end = at + 2 + (((uint32_t)m[at] << 8) | m[at + 1]); at += 2; if (end > n) return 0; const uint8_t *theirs = 0; int version = 0;
    while (at + 4 <= end) { uint32_t type = ((uint32_t)m[at] << 8) | m[at + 1], len = ((uint32_t)m[at + 2] << 8) | m[at + 3]; at += 4; if (at + len > end) return 0;
        if (type == 43 && len == 2 && m[at] == 3 && m[at + 1] == 4) version = 1;
        if (type == 51 && len == 36 && m[at] == 0 && m[at + 1] == 29 && m[at + 2] == 0 && m[at + 3] == 32) theirs = m + at + 4;
        at += len; }
    if (!version || !theirs || !add_transcript(st, m, n)) return 0;
    void *mine[512]; small shared, sec, pub; head(shared.head, 320); put(&sec, st->secret, 32); put(&pub, theirs, 32); mine[257] = &sec; mine[258] = &pub; int16_t q[2] = {1, 2};
    if (on(table, SLOT_EXCHANGE_SHARED, &shared, q, 2, mine) != 32) return 0;
    uint8_t zeros[32] = {0}, early[32], empty[32], derived[32], hs[32], th[32]; uint32_t keep = st->tn;
    st->tn = 0; if (!hash_transcript(table, st, empty)) return 0; st->tn = keep;                                      /* the hash of nothing, which the schedule uses as a label's context */
    if (!hmac(table, zeros, zeros, 32, early) || !expand(table, early, "derived", empty, 32, 32, derived) || !hmac(table, derived, shared.b, 32, hs) || !hash_transcript(table, st, th)) return 0;
    if (!expand(table, hs, "c hs traffic", th, 32, 32, st->c_hs) || !expand(table, hs, "s hs traffic", th, 32, 32, st->s_hs) || !expand(table, hs, "derived", empty, 32, 32, derived) || !hmac(table, derived, zeros, 32, st->master)) return 0;
    for (int i = 0; i < 32; i++) st->secret[i] = 0;
    if (!traffic(table, st->s_hs, st->rkey, st->riv) || !traffic(table, st->c_hs, st->wkey, st->wiv)) return 0; st->rseq = st->wseq = 0; st->stage = KEYS; return 1;
}
/* Seals one record of the given inner kind into the bytes to send. */
static int send_record(void *const *table, state *st, block *out, const uint8_t *d, uint32_t n, uint8_t kind) {
    if (n > RECORD || out->size - 64 < (uint64_t)st->out_len + 5 + n + 17) return 0; uint8_t h[5] = {23, 3, 3, (uint8_t)((n + 17) >> 8), (uint8_t)(n + 17)};
    for (uint32_t i = 0; i < n; i++) st->in[i] = d[i]; st->in[n] = kind; if (crypt(table, st, 1, st->wkey, st->wiv, st->wseq++, h, n + 1) != (int64_t)n + 17) return 0;
    uint8_t *o = out->bytes + st->out_len; for (int i = 0; i < 5; i++) o[i] = h[i]; for (uint32_t i = 0; i < n + 17; i++) o[5 + i] = st->out[i]; st->out_len += 5 + n + 17; return 1;
}
/* The server's messages after its hello, as they complete: its settings, its certificate, its signature, its proof. */
static int handshake_messages(void *const *table, state *st, block *out) {
    for (;;) { if (st->hn < 4) return 1; uint32_t len = ((uint32_t)st->hs[1] << 16) | ((uint32_t)st->hs[2] << 8) | st->hs[3], type = st->hs[0]; if (len + 4 > TRANSCRIPT) return 0; if (st->hn < len + 4) return 1;
        if (st->stage == KEYS) {
            if (type == 20) { uint8_t fk[32], th[32], want[32]; if (len != 32 || !expand(table, st->s_hs, "finished", 0, 0, 32, fk) || !hash_transcript(table, st, th) || !hmac(table, fk, th, 32, want)) return 0;
                uint32_t differ = 0; for (int i = 0; i < 32; i++) differ |= (uint32_t)(want[i] ^ st->hs[4 + i]); if (differ) return 0;         /* the server did not arrive at our keys */
                if (!add_transcript(st, st->hs, 36) || !hash_transcript(table, st, th)) return 0;
                uint8_t mine[36] = {20, 0, 0, 32}, c_ap[32], s_ap[32]; if (!expand(table, st->c_hs, "finished", 0, 0, 32, fk) || !hmac(table, fk, th, 32, mine + 4) || !send_record(table, st, out, mine, 36, 22)) return 0;
                if (!expand(table, st->master, "c ap traffic", th, 32, 32, c_ap) || !expand(table, st->master, "s ap traffic", th, 32, 32, s_ap) || !traffic(table, s_ap, st->rkey, st->riv) || !traffic(table, c_ap, st->wkey, st->wiv)) return 0;
                st->rseq = st->wseq = 0; st->stage = CONNECTED; }
            else { if (type == 11) { st->certificate_at = st->tn; st->certificate_len = len + 4; }                    /* kept for the checking that does not exist yet */
                if (type != 8 && type != 11 && type != 15 && type != 13) return 0; if (!add_transcript(st, st->hs, len + 4)) return 0; } }
        /* once connected: session tickets and the like are passed over */
        for (uint32_t i = len + 4; i < st->hn; i++) st->hs[i - len - 4] = st->hs[i]; st->hn -= len + 4; }
}
/* Bytes from the server. Takes whole records; says how much it used, what to send back, and what plain data arrived. */
int64_t feed(state *st, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *in = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1); block *out = (block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1), *plain = (block *)TROUGH_BLOCK(table, n > 2 ? p[2] : -1);
    if (st->version != 1 || !in || in->kind != 2 || in->size < 64 || !out || out->size < 64 + 512 || !plain || plain->size < 64 || (void *)out == (void *)plain) return -1;
    if (st->stage == NEW || st->stage >= CLOSED) return st->stage == CLOSED ? CLOSED : -1;
    uint64_t have = in->size - 64, at = 0; st->out_len = 0; st->plain_len = 0;
    while (at + 5 <= have && st->stage < CLOSED) { const uint8_t *r = in->bytes + at; uint32_t kind = r[0], len = ((uint32_t)r[3] << 8) | r[4]; if (len > RECORD + 256) return fail(st, 22); if (at + 5 + len > have) break;
        const uint8_t *body = r + 5; uint32_t inner = kind, bn = len;
        if (kind == 20) { at += 5 + len; continue; }                                                                 /* a leftover of older versions, sent for old network boxes */
        if (kind == 23) { if (st->stage < KEYS || len < 17) return fail(st, 10); for (uint32_t i = 0; i < len; i++) st->in[i] = body[i];
            int64_t got = crypt(table, st, 0, st->rkey, st->riv, st->rseq++, r, len); if (got < 1) return fail(st, 20);                 /* altered on the way, or not our keys */
            bn = (uint32_t)got; while (bn && !st->out[bn - 1]) bn--; if (!bn) return fail(st, 10); inner = st->out[--bn]; body = st->out; }
        else if (st->stage >= KEYS && kind != 21) return fail(st, 10);
        if (inner == 22) { if (st->stage == HELLO_SENT) { if (bn < 4 || (((uint32_t)body[1] << 16) | ((uint32_t)body[2] << 8) | body[3]) + 4 != bn || !server_hello(table, st, body, bn)) return fail(st, 40); }
            else { if (st->hn + bn > TRANSCRIPT) return fail(st, 22); for (uint32_t i = 0; i < bn; i++) st->hs[st->hn + i] = body[i]; st->hn += bn; if (!handshake_messages(table, st, out)) return fail(st, 51); } }
        else if (inner == 23) { if (st->stage != CONNECTED || plain->size - 64 < (uint64_t)st->plain_len + bn) return fail(st, 22); for (uint32_t i = 0; i < bn; i++) plain->bytes[st->plain_len + i] = body[i]; st->plain_len += bn; }
        else if (inner == 21) { st->alert = bn > 1 ? body[1] : 0; st->stage = (bn > 1 && body[1] == 0) ? CLOSED : FAILED; }
        else return fail(st, 10);
        at += 5 + len; }
    st->used = (uint32_t)at; return st->stage == FAILED ? -1 : st->stage;
}
/* Plain data to the server, sealed into records. */
int64_t send(state *st, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *plain = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : -1); block *out = (block *)TROUGH_BLOCK(table, n > 1 ? p[1] : -1);
    if (st->version != 1 || st->stage != CONNECTED || !plain || plain->kind != 2 || plain->size < 64 || !out || out->size < 64 || (const void *)plain == (void *)out) return -1;
    uint64_t total = plain->size - 64; st->out_len = 0;
    for (uint64_t at = 0; at < total; ) { uint32_t part = total - at > RECORD ? RECORD : (uint32_t)(total - at); if (!send_record(table, st, out, plain->bytes + at, part, 23)) return -1; at += part; }
    return st->out_len;
}
