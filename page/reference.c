/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef struct { uint32_t version, width, height, stride; uint64_t size; } surface;
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
typedef struct {
    surface *s; void *const *table; int font, base, scroll; int32_t width, height; int cache, scratch;   /* cache < 0: draw without one */
    int size, link;                                  /* current text size; inside a link */
    int64_t y, pending;                              /* top of the next line; space owed before the next block's first line */
    int16_t line[4 + 400]; int line_n; int64_t line_w16; int line_link_from[40], line_links;   /* codes on the line; starts and ends of link runs */
    int16_t word[2 + 80]; int word_n; int word_link;
    int space16; int started;                        /* a line has begun in this block */
} lay;
static int64_t measure(lay *L, int16_t *numbers, int count) { numbers[0] = (int16_t)L->font; numbers[1] = (int16_t)L->size; return TROUGH_ON(L->table, SLOT_FONT_MEASURE, L->s, numbers, count + 2, 0); }
static void flush_line(lay *L) {
    if (!L->line_n) return;
    L->y += L->pending; L->pending = 0;
    int64_t top = L->y - L->scroll, baseline = top + L->size;
    if (top < L->height && top + 2 * L->size > 0) {
        /* draw run by run so link text can be blue; the pen position carries from one run to the next */
        int from = 0; int64_t pen16 = 8 * 16;
        for (int r = 0; r <= L->line_links; r++) { int to = r < L->line_links ? L->line_link_from[r] : L->line_n; if (to > from) {
                int16_t q[6 + 400]; int at = 0, start = (int)(pen16 / 16); q[at++] = (int16_t)L->font;
                if (L->cache >= 0) { q[at++] = (int16_t)L->cache; q[at++] = (int16_t)L->scratch; }
                q[at++] = (int16_t)L->size; q[at++] = (int16_t)start; q[at++] = (int16_t)baseline;
                for (int i = from; i < to; i++) q[at++] = L->line[4 + i];
                int64_t end = TROUGH_ON(L->table, L->cache >= 0 ? SLOT_FONT_DRAW_CACHED : SLOT_FONT_DRAW, L->s, q, at, (r & 1) ? 0xffcc5500 : 0xff202020);
                if (end >= 0) pen16 = pen16 + (end - (int64_t)start * 16); }
            from = to; }
    }
    L->y += L->size * 5 / 4; L->line_n = 0; L->line_w16 = 0; L->line_links = 0; L->started = 1;
    if (L->link) L->line_link_from[L->line_links++] = 0;        /* a link continues onto the new line */
}
static void end_word(lay *L) {
    if (!L->word_n) return;
    int64_t w16 = measure(L, L->word, L->word_n); if (w16 < 0) w16 = 0;
    int64_t room16 = ((int64_t)L->width - 16) * 16;
    if (L->line_n && L->line_w16 + L->space16 + w16 > room16) flush_line(L);
    if (L->line_n && L->line_n < 399) { L->line[4 + L->line_n++] = 32; L->line_w16 += L->space16; }
    for (int i = 0; i < L->word_n && L->line_n < 400; i++) L->line[4 + L->line_n++] = L->word[2 + i];
    L->line_w16 += w16; L->word_n = 0;
}
static void set_link(lay *L, int on) { if (on == L->link) return; end_word(L); if (L->line_links < 40) L->line_link_from[L->line_links++] = L->line_n + (L->line_n ? 1 : 0) > 400 ? 400 : L->line_n; L->link = on; }
static void begin_block(lay *L, int size, int64_t space) {
    end_word(L); flush_line(L);
    if (space > L->pending) L->pending = space;
    L->size = size; int16_t sp[3]; sp[2] = 32; L->space16 = (int)measure(L, sp, 1); if (L->space16 < 0) L->space16 = 0; L->started = 0;
}
static int name_is(const uint8_t *d, uint64_t n, uint64_t at, uint64_t len, const char *name) {
    uint64_t i = 0; for (; name[i]; i++) { if (i >= len || at + i >= n) return 0; uint8_t c = d[at + i]; if (c >= 'A' && c <= 'Z') c = (uint8_t)(c + 32); if (c != (uint8_t)name[i]) return 0; }
    return i == len;
}
int64_t render(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused;
    const block *doc = (const block *)TROUGH_BLOCK(table, n > 0 ? p[0] : 0), *fnt = (const block *)TROUGH_BLOCK(table, n > 1 ? p[1] : 0);
    int base = n > 2 ? p[2] : 0; if (!doc || !fnt || doc->kind != 2 || fnt->kind != 2 || doc->size < 64 || base < 6 || base > 200) return -1;
    const uint8_t *d = doc->bytes; uint64_t len = doc->size - 64;
    lay L; L.s = s; L.table = table; L.font = p[1]; L.base = base; L.scroll = n > 3 ? p[3] : 0; L.width = (int32_t)s->width; L.height = (int32_t)s->height;
    { const block *cb = (const block *)TROUGH_BLOCK(table, n > 4 ? p[4] : -1); const surface *mb = (const surface *)TROUGH_BLOCK(table, n > 5 ? p[5] : -1);
      int usable = n > 5 && cb && cb->kind == 3 && mb && mb->version == 4; L.cache = usable ? p[4] : -1; L.scratch = usable ? p[5] : -1; }
    L.size = base; L.link = 0; L.y = 8; L.pending = 0; L.line_n = 0; L.line_w16 = 0; L.line_links = 0; L.word_n = 0; L.started = 0;
    { int16_t sp[3]; sp[2] = 32; L.space16 = (int)measure(&L, sp, 1); if (L.space16 < 0) return -1; }
    TROUGH_ON(table, SLOT_PAINT_CLEAR, s, 0, 0, 0xffffffff);
    static const char skipped[6][9] = {"head", "script", "style", "title", "noscript", "svg"};   /* arrays of characters, not of addresses: a piece must run wherever it is put */
    for (uint64_t i = 0; i < len; ) {
        uint8_t c = d[i];
        if (c == '<') {
            if (i + 3 < len && d[i + 1] == '!' && d[i + 2] == '-' && d[i + 3] == '-') { i += 4; while (i + 2 < len && !(d[i] == '-' && d[i + 1] == '-' && d[i + 2] == '>')) i++; i += 3; continue; }
            uint64_t j = i + 1; int closing = 0; if (j < len && d[j] == '/') { closing = 1; j++; }
            uint64_t name = j; while (j < len && ((d[j] >= 'a' && d[j] <= 'z') || (d[j] >= 'A' && d[j] <= 'Z') || (d[j] >= '0' && d[j] <= '9'))) j++;
            uint64_t name_len = j - name; while (j < len && d[j] != '>') j++; uint64_t after = j < len ? j + 1 : len;
            if (!name_len) { i = after; continue; }
            int skip = 0; for (int k = 0; k < 6 && !closing; k++) if (name_is(d, len, name, name_len, skipped[k])) skip = k + 1;
            if (skip) {                                           /* jump to the matching closing tag */
                const char *want = skipped[skip - 1]; uint64_t q = after; int found = 0;
                while (q + 2 < len && !found) { if (d[q] == '<' && d[q + 1] == '/') { uint64_t e = q + 2; while (e < len && d[e] != '>' && d[e] != ' ') e++; if (name_is(d, len, q + 2, e - (q + 2), want)) { while (e < len && d[e] != '>') e++; q = e + 1; found = 1; break; } } q++; }
                i = found ? q : len; continue; }
            if (name_is(d, len, name, name_len, "br")) { end_word(&L); if (L.line_n) flush_line(&L); else { L.y += L.pending + L.size * 5 / 4; L.pending = 0; } }
            else if (name_is(d, len, name, name_len, "a")) set_link(&L, !closing);
            else {
                int heading = name_len == 2 && (d[name] == 'h' || d[name] == 'H') && d[name + 1] >= '1' && d[name + 1] <= '6' ? d[name + 1] - '0' : 0;
                static const char blocks[22][12] = {"p", "div", "section", "article", "header", "footer", "main", "ul", "ol", "blockquote", "tr", "li", "body", "html", "table", "nav", "form", "pre", "dl", "dt", "dd", "hr"};
                int kind = 0; for (int k = 0; k < 22; k++) if (name_is(d, len, name, name_len, blocks[k])) kind = k + 1;
                if (heading || kind) {
                    static const int num[7] = {0, 32, 24, 187, 16, 133, 107};                 /* sixteenths of the text size */
                    int size = heading ? (heading == 3 ? base * 117 / 100 : base * num[heading] / 16) : base; if (size < 4) size = 4;
                    int own = closing ? L.size : size;
                    int64_t space = heading == 1 ? own * 67 / 100 : heading == 2 ? own * 83 / 100 : (heading || kind == 1) ? own : 0;
                    begin_block(&L, closing ? base : size, space);
                    if (!closing && kind == 12) { L.word[2] = 8226; L.word_n = 1; end_word(&L); }   /* a bullet */
                } }
            i = after; continue;
        }
        int32_t code = c; uint64_t used = 1;
        if (c == '&') {
            uint64_t j = i + 1; while (j < len && j < i + 10 && d[j] != ';' && d[j] != ' ' && d[j] != '<') j++;
            if (j < len && d[j] == ';') { uint64_t nl = j - (i + 1);
                if (name_is(d, len, i + 1, nl, "amp")) code = '&'; else if (name_is(d, len, i + 1, nl, "lt")) code = '<'; else if (name_is(d, len, i + 1, nl, "gt")) code = '>';
                else if (name_is(d, len, i + 1, nl, "quot")) code = '"'; else if (name_is(d, len, i + 1, nl, "apos")) code = 39; else if (name_is(d, len, i + 1, nl, "nbsp")) code = 160;
                else if (nl >= 2 && d[i + 1] == '#') { int32_t v = 0; for (uint64_t k = i + 2; k < j; k++) { if (d[k] < '0' || d[k] > '9') { v = -1; break; } v = v * 10 + (d[k] - '0'); if (v > 0x10ffff) { v = -1; break; } } code = v > 0 ? v : '?'; }
                else code = -1;
                if (code >= 0) used = j - i + 1; else code = '&'; }
        } else if (c >= 0xc0) {
            int extra = c >= 0xf0 ? 3 : c >= 0xe0 ? 2 : 1; int32_t v = c & (0x3f >> extra); uint64_t k = 1;
            for (; k <= (uint64_t)extra && i + k < len && (d[i + k] & 0xc0) == 0x80; k++) v = (v << 6) | (d[i + k] & 0x3f);
            if (k == (uint64_t)extra + 1) { code = v; used = k; } else code = '?';
        } else if (c >= 0x80) code = '?';
        i += used;
        if (code == ' ' || code == '\n' || code == '\t' || code == '\r' || code == 12) { end_word(&L); continue; }
        if (code > 32767) code = '?';
        if (L.word_n >= 80) end_word(&L);
        L.word[2 + L.word_n++] = (int16_t)code;
    }
    end_word(&L); flush_line(&L);
    return L.y + 8;
}
