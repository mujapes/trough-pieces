/* reference.c with the arithmetic compiled separately for each curve (4 limbs for P-256, 6 for P-384). Same text otherwise: ecdsa/core.h. */
#include <stdint.h>
#include "../slots.h"
#include "curves.h"
typedef struct { uint32_t kind, a, b, c; uint64_t size; uint8_t reserved[40]; uint8_t bytes[]; } block;
typedef unsigned __int128 u128;
#define K 4
#define N(x) x##_256
#include "core.h"
#undef K
#undef N
#define K 6
#define N(x) x##_384
#include "core.h"
#undef K
#undef N
static const block *bytes_at(void *const *table, const int16_t *p, int64_t n, int which) { const block *b = (const block *)TROUGH_BLOCK(table, n > which ? p[which] : -1); return b && b->kind == 2 && b->size > 64 && b->size <= 64 + 80 ? b : 0; }
int64_t verify(block *unused, const int16_t *p, int64_t n, int64_t a, void *const *table) { (void)unused; (void)a;
    int curve = n > 0 ? p[0] : 0; if (curve != 256 && curve != 384) return -1; int bytes = curve / 8;
    const block *bx = bytes_at(table, p, n, 1), *by = bytes_at(table, p, n, 2), *br = bytes_at(table, p, n, 3), *bs = bytes_at(table, p, n, 4), *bd = bytes_at(table, p, n, 5); if (!bx || !by || !br || !bs || !bd) return -1;
    return curve == 256 ? verify_one_256(curve, bytes, bx, by, br, bs, bd) : verify_one_384(curve, bytes, bx, by, br, bs, bd);
}
