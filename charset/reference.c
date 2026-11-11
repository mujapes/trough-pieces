/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
#include "cp1252.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
enum { UTF8 = 1, WINDOWS_1252 = 2, UTF16LE = 3, UTF16BE = 4 };
typedef struct { uint8_t *o; uint64_t at, room; int full; } writer;
static void emit(writer *w, uint32_t c) {                                /* one code point, as UTF-8 */
    uint8_t b[4]; int n; if (c < 0x80) { b[0] = (uint8_t)c; n = 1; } else if (c < 0x800) { b[0] = (uint8_t)(0xc0 | (c >> 6)); b[1] = (uint8_t)(0x80 | (c & 63)); n = 2; }
    else if (c < 0x10000) { b[0] = (uint8_t)(0xe0 | (c >> 12)); b[1] = (uint8_t)(0x80 | ((c >> 6) & 63)); b[2] = (uint8_t)(0x80 | (c & 63)); n = 3; }
    else { b[0] = (uint8_t)(0xf0 | (c >> 18)); b[1] = (uint8_t)(0x80 | ((c >> 12) & 63)); b[2] = (uint8_t)(0x80 | ((c >> 6) & 63)); b[3] = (uint8_t)(0x80 | (c & 63)); n = 4; }
    if (w->at + (uint64_t)n > w->room) { w->full = 1; return; } for (int i = 0; i < n; i++) w->o[w->at++] = b[i];
}
/* UTF-8 in, valid UTF-8 out: every stretch that cannot be part of a well-formed character becomes one U+FFFD, taking the longest
 * start of a character that could still have been completed (the Unicode "maximal subpart" rule, which browsers follow). */
static void from_utf8(writer *w, const uint8_t *s, uint64_t n) {
    for (uint64_t i = 0; i < n && !w->full; ) { uint8_t c = s[i]; if (c < 0x80) { emit(w, c); i++; continue; }
        int need = c >= 0xc2 && c <= 0xdf ? 1 : c >= 0xe0 && c <= 0xef ? 2 : c >= 0xf0 && c <= 0xf4 ? 3 : 0; if (!need) { emit(w, 0xfffd); i++; continue; }
        uint8_t lo = 0x80, hi = 0xbf; if (c == 0xe0) lo = 0xa0; else if (c == 0xed) hi = 0x9f; else if (c == 0xf0) lo = 0x90; else if (c == 0xf4) hi = 0x8f;       /* the second byte's range rules out overlong forms, surrogates and values past the end */
        uint32_t v = need == 1 ? c & 0x1f : need == 2 ? c & 0x0f : c & 0x07; int got = 0; uint64_t j = i + 1;
        for (; got < need && j < n; got++, j++) { uint8_t t = s[j]; if (t < (got ? 0x80 : lo) || t > (got ? 0xbf : hi)) break; v = (v << 6) | (t & 63); }
        if (got == need) emit(w, v); else emit(w, 0xfffd); i = j; }
}
static void from_utf16(writer *w, const uint8_t *s, uint64_t n, int big) {
    uint64_t i = 0; for (; i + 1 < n && !w->full; i += 2) { uint32_t u = big ? ((uint32_t)s[i] << 8) | s[i + 1] : ((uint32_t)s[i + 1] << 8) | s[i];
        if (u >= 0xd800 && u <= 0xdbff) { uint32_t v = 0; if (i + 3 < n) v = big ? ((uint32_t)s[i + 2] << 8) | s[i + 3] : ((uint32_t)s[i + 3] << 8) | s[i + 2];
            if (i + 3 < n && v >= 0xdc00 && v <= 0xdfff) { emit(w, 0x10000 + ((u - 0xd800) << 10) + (v - 0xdc00)); i += 2; }
            else if (i + 3 >= n) { emit(w, 0xfffd); return; }          /* the text ends inside a pair (with or without one stray byte after it): one mark for the lot */
            else emit(w, 0xfffd); }
        else if (u >= 0xdc00 && u <= 0xdfff) emit(w, 0xfffd); else emit(w, u); }
    if (i < n && !w->full) emit(w, 0xfffd);                              /* an odd byte left over */
}
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which, const block *out) { const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size >= 64 && b != out ? b : 0; }
/* Text in one of the encodings, out as UTF-8. A byte-order mark at the start is dropped. */
int64_t to_utf8(block *out, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)a;
    const block *src = bytes_at(table, p, n, 0, out); int which = n > 1 ? p[1] : 0; if (!src || out->size < 64 || which < UTF8 || which > UTF16BE) return -1;
    const uint8_t *s = src->bytes; uint64_t len = src->size - 64; writer w = {out->bytes, 0, out->size - 64, 0};
    if (which == UTF8) { if (len >= 3 && s[0] == 0xef && s[1] == 0xbb && s[2] == 0xbf) { s += 3; len -= 3; } from_utf8(&w, s, len); }
    else if (which == WINDOWS_1252) for (uint64_t i = 0; i < len && !w.full; i++) emit(&w, s[i] < 128 ? s[i] : cp1252[s[i] - 128]);
    else { int big = which == UTF16BE; if (len >= 2 && s[0] == (big ? 0xfe : 0xff) && s[1] == (big ? 0xff : 0xfe)) { s += 2; len -= 2; } from_utf16(&w, s, len, big); }
    return w.full ? -1 : (int64_t)w.at;
}
static int same(const uint8_t *s, uint64_t n, const char *word) { uint64_t i = 0; for (; word[i]; i++) if (i >= n || (s[i] | (s[i] >= 'A' && s[i] <= 'Z' ? 32 : 0)) != (uint8_t)word[i]) return 0; return i == n; }
/* Which encoding a label means (from a Content-Type header or a page's own declaration), as browsers read labels. 0 if unknown. */
int64_t named(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    const block *b = bytes_at(table, p, n, 0, 0); if (!b) return -1; const uint8_t *s = b->bytes; uint64_t len = b->size - 64;
    while (len && (s[0] == ' ' || s[0] == '\t' || s[0] == '\n' || s[0] == '\r' || s[0] == '"' || s[0] == '\'')) { s++; len--; } while (len && (s[len - 1] == ' ' || s[len - 1] == '\t' || s[len - 1] == '\n' || s[len - 1] == '\r' || s[len - 1] == '"' || s[len - 1] == '\'' || s[len - 1] == ';')) len--;
    if (same(s, len, "utf-8") || same(s, len, "utf8") || same(s, len, "unicode-1-1-utf-8")) return UTF8;
    if (same(s, len, "windows-1252") || same(s, len, "cp1252") || same(s, len, "x-cp1252") || same(s, len, "iso-8859-1") || same(s, len, "iso8859-1") || same(s, len, "iso_8859-1") || same(s, len, "latin1") || same(s, len, "l1") || same(s, len, "ascii") || same(s, len, "us-ascii") || same(s, len, "cp819") || same(s, len, "ibm819")) return WINDOWS_1252;
    if (same(s, len, "utf-16le") || same(s, len, "utf-16") || same(s, len, "ucs-2") || same(s, len, "unicode")) return UTF16LE;
    if (same(s, len, "utf-16be")) return UTF16BE;
    return 0;
}
