/* Used only when a compiler insists on calling memcpy, memset or memmove for a copy the source wrote as plain C (gcc 13 does for
 * one struct copy in shell; gcc 14 does not). A piece may refer to nothing outside itself, so the routine comes along inside it. */
#pragma GCC visibility push(hidden)
__attribute__((noinline, optimize("no-tree-loop-distribute-patterns"))) void *memcpy(void *to, const void *from, __SIZE_TYPE__ n) { unsigned char *d = to; const unsigned char *s = from; while (n--) *d++ = *s++; return to; }
__attribute__((noinline, optimize("no-tree-loop-distribute-patterns"))) void *memset(void *to, int v, __SIZE_TYPE__ n) { unsigned char *d = to; while (n--) *d++ = (unsigned char)v; return to; }
__attribute__((noinline, optimize("no-tree-loop-distribute-patterns"))) void *memmove(void *to, const void *from, __SIZE_TYPE__ n) { unsigned char *d = to; const unsigned char *s = from; if (d < s) while (n--) *d++ = *s++; else while (n--) d[n] = s[n]; return to; }
#pragma GCC visibility pop
