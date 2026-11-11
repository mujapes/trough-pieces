/* The meaning of the piece, written the obvious way. Tests compare every implementation against this. */
#include <stdint.h>
int64_t energy(const int16_t *x, int64_t n) { int64_t s = 0; for (int64_t i = 0; i < n; i++) s += (int32_t)x[i] * x[i]; return s; }
int64_t climbs(const int16_t *x, int64_t n, int64_t thr) { int64_t c = 0; for (int64_t i = 1; i < n; i++) c += (x[i-1] <= thr) & (x[i] > thr); return c; }
