/* The meaning of the piece, written the obvious way. This is also its implementation. */
#include <stdint.h>
static int64_t in(const int16_t *x, int64_t n, int i) { return i < n ? x[i] : 0; }
int64_t skip_ahead(const int16_t *x, int64_t n, int64_t unused) { (void)unused; return in(x, n, 0) + 70 * in(x, n, 1) >= 6000; }
int64_t duck_volume(const int16_t *x, int64_t n, int64_t unused) { (void)unused;
    int64_t percent = n >= 3 ? x[2] : -1; if (percent < 0) percent = 10; if (percent > 100) percent = 100;
    return in(x, n, 0) != 0 && in(x, n, 1) != 0 ? percent * 10 : 1000; }
int64_t filler_wait(const int16_t *x, int64_t n, int64_t unused) { (void)unused; return in(x, n, 0) <= 0 ? 8000 : 25000; }
int64_t points_wait(const int16_t *x, int64_t n, int64_t unused) { (void)x; (void)n; (void)unused; return 1500; }
int64_t join_wait(const int16_t *x, int64_t n, int64_t unused) { (void)unused; return in(x, n, 0) <= 5 ? 5000 : 3500; }
