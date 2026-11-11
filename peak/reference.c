/* The meaning of the piece, written the obvious way. */
#include <stdint.h>
int64_t peak(const int16_t *x, int64_t n, int64_t unused) { (void)unused; int64_t m = 0; for (int64_t i = 0; i < n; i++) { int64_t a = x[i] < 0 ? -(int64_t)x[i] : x[i]; if (a > m) m = a; } return m; }
