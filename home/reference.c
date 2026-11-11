/* The meaning of the piece, written the obvious way. This is also today's implementation. */
#include <stdint.h>
#include "../slots.h"
typedef struct { uint32_t version, width, height, stride; uint64_t size; } surface;
static const char names[16][8] = {"Trough", "Music", "Video", "Maps", "Browser", "Voice", "Files", "Pieces", "Reddit", "Notes", "Camera", "Games", "Clock", "Mail", "Photos", "Phone"};
static const uint32_t colours[8] = {0xff5a9cf0, 0xff6bcf7f, 0xfff0b45a, 0xffd66fb0, 0xff5ad0d8, 0xffe07a5a, 0xff9f8cf0, 0xffc8d05a};
static const char title[] = "Home, made of pieces";
int64_t check(surface *s, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)p; (void)n; (void)a; (void)table;
    return s->version == 1 && s->width >= 1 && s->width <= 16384 && s->height >= 1 && s->height <= 16384
        && s->stride == 4 * s->width && s->size == 64 + (uint64_t)s->stride * s->height; }
static void tile(const surface *s, int i, int *x, int *y, int *size) {
    int w = (int)s->width, h = (int)s->height, column = w / 4, step = (h - 64 - h / 7 - 12) / 4;
    *size = column * 2 / 3; *x = (i % 4) * column + (column - *size) / 2; *y = 64 + (i / 4) * step;
}
static int64_t rect(surface *s, void *const *table, int x, int y, int w, int h, uint32_t colour) {
    int16_t q[4] = {(int16_t)x, (int16_t)y, (int16_t)w, (int16_t)h}; TROUGH_ON(table, SLOT_PAINT_FILL_RECT, s, q, 4, colour); return 1; }
static int64_t words(surface *s, void *const *table, int x, int y, const char *text, int centred, uint32_t colour) {
    int16_t q[40]; int n = 0; while (text[n] && n < 38) { q[2 + n] = text[n]; n++; }
    if (centred) x -= (int)TROUGH_ON(table, SLOT_TEXT_MEASURE, s, q + 2, n, 0) / 2;
    q[0] = (int16_t)x; q[1] = (int16_t)y; TROUGH_ON(table, SLOT_TEXT_DRAW, s, q, n + 2, colour); return centred ? 2 : 1; }
int64_t render(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused;
    int pressed = n > 0 ? p[0] : -1, hour = n > 1 ? p[1] : 0, minute = n > 2 ? p[2] : 0, w = (int)s->width, h = (int)s->height; int64_t calls = 0;
    hour = ((hour % 24) + 24) % 24; minute = ((minute % 60) + 60) % 60;
    TROUGH_ON(table, SLOT_PAINT_CLEAR, s, 0, 0, 0xff1a1410); calls++;
    calls += rect(s, table, 0, 0, w, 28, 0xff2b221c);
    char clock[6]; int c = 0; if (hour >= 10) clock[c++] = (char)('0' + hour / 10); clock[c++] = (char)('0' + hour % 10); clock[c++] = ':';
    clock[c++] = (char)('0' + minute / 10); clock[c++] = (char)('0' + minute % 10); clock[c] = 0;
    calls += words(s, table, 12, 3, clock, 0, 0xffd8d0c8);
    calls += words(s, table, w / 2, 34, title, 1, 0xff8a8078);
    for (int i = 0; i < 16; i++) {
        int x, y, size; tile(s, i, &x, &y, &size);
        calls += rect(s, table, x + 3, y + 4, size, size, 0xff0e0b09);                       /* shadow */
        if (i == pressed) calls += rect(s, table, x - 3, y - 3, size + 6, size + 6, 0xfff0ece8);   /* frame of a pressed tile */
        calls += rect(s, table, x, y, size, size, colours[i % 8]);
        calls += words(s, table, x + size / 2, y + size + 4, names[i], 1, 0xffc8c0b8);
    }
    int dock = h / 9, top = h - 12 - dock, inner = dock * 3 / 4, gap = (w - 32 - 4 * inner) / 5;
    calls += rect(s, table, 16, top, w - 32, dock, 0xff2b221c);
    for (int i = 0; i < 4; i++) calls += rect(s, table, 16 + gap + i * (inner + gap), top + (dock - inner) / 2, inner, inner, colours[(i + 3) % 8]);
    return calls;
}
int64_t hit(surface *s, const int16_t *p, int64_t n, int64_t unused, void *const *table) { (void)unused; (void)table;
    int px = n > 0 ? p[0] : 0, py = n > 1 ? p[1] : 0;
    for (int i = 0; i < 16; i++) { int x, y, size; tile(s, i, &x, &y, &size); if (px >= x && px < x + size && py >= y && py < y + size) return i; }
    return -1;
}
