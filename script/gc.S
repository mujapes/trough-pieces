// The garbage collector (plan: intent.md, "Garbage collector plan"). Conservative and non-moving: any word anywhere that could
// be a reference keeps the block it lands in. Blocks have no heads: a bitmap says where each block starts (one bit per 8 bytes of
// heap, from W_HEAP0); a block ends where the next starts, or at the top (W_HEAP). Bits above the top are always 0.
// Free blocks are on one list (W_FREE): each one's first word is the next (a distance; 0 ends the list).
    .equ W_NBASE, 592                   // the processor's stack where the entry began (the collector looks at everything below it)
    .equ W_HEAP0, 600                   // where the heap starts
    .equ W_BITS, 608                    // the start bitmap (a distance)
    .equ W_MARKS, 616                   // the mark bitmap
    .equ W_MSTK, 624                    // the mark stack and how many entries it has room for
    .equ W_MSCAP, 632
    .equ W_FREE, 640                    // the free list
    .equ W_GCS, 648                     // how many collections so far

// g_setbit / g_clrbit: bitmap at distance x1, bit x0. Uses x9-x11.
g_setbit:
    add     x9, x19, x1
    lsr     x10, x0, #6
    ldr     x11, [x9, x10, lsl #3]
    mov     x12, #1
    lsl     x12, x12, x0
    orr     x11, x11, x12
    str     x11, [x9, x10, lsl #3]
    ret
g_clrbit:
    add     x9, x19, x1
    lsr     x10, x0, #6
    ldr     x11, [x9, x10, lsl #3]
    mov     x12, #1
    lsl     x12, x12, x0
    bic     x11, x11, x12
    str     x11, [x9, x10, lsl #3]
    ret
// g_next: the first start bit at or after bit x0, below bit x1 -> x0 (x1 if none). Uses x9-x12.
g_next:
    ldr     x9, [x19, #W_BITS]
    add     x9, x19, x9
1:  cmp     x0, x1
    b.hs    8f
    lsr     x10, x0, #6
    ldr     x11, [x9, x10, lsl #3]
    and     x12, x0, #63
    lsr     x11, x11, x12
    cbz     x11, 2f
    rbit    x11, x11
    clz     x11, x11
    add     x0, x0, x11
    cmp     x0, x1
    csel    x0, x0, x1, lo
    ret
2:  orr     x0, x0, #63
    add     x0, x0, #1
    b       1b
8:  mov     x0, x1
    ret
// g_find: the block holding heap distance x0 -> x0 its bit (-1 if x0 is not in the heap below the top). Uses x9-x13.
g_find:
    ldr     x9, [x19, #W_HEAP0]
    ldr     x10, [x19, #W_HEAP]
    cmp     x0, x9
    b.lo    9f
    cmp     x0, x10
    b.hs    9f
    sub     x0, x0, x9
    lsr     x0, x0, #3
    ldr     x9, [x19, #W_BITS]
    add     x9, x19, x9
    lsr     x10, x0, #6
    and     x11, x0, #63
    ldr     x12, [x9, x10, lsl #3]
    mov     x13, #-1
    eor     x11, x11, #63
    lsr     x13, x13, x11               // bits 0 .. (x0 & 63)
    and     x12, x12, x13
1:  cbnz    x12, 2f
    cbz     x10, 9f
    sub     x10, x10, #1
    ldr     x12, [x9, x10, lsl #3]
    b       1b
2:  clz     x12, x12
    mov     x0, #63
    sub     x0, x0, x12
    add     x0, x0, x10, lsl #6
    ret
9:  mov     x0, #-1
    ret
// g_cand: the word x0, as a value's payload and as an address, marks the block it lands in. Uses x0-x16.
g_cand:
    mov     x16, x30
    mov     x15, x0
    and     x0, x0, #0xffffffffffff
    bl      g_try
    sub     x0, x15, x19
    mov     x30, x16
    // fall through
// g_try: heap distance x0: its block is marked and pushed if it was not marked. Uses x0, x9-x14.
g_try:
    mov     x14, x30
    bl      g_find
    mov     x30, x14
    tbnz    x0, #63, 9f
    ldr     x9, [x19, #W_MARKS]
    add     x9, x19, x9
    lsr     x10, x0, #6
    ldr     x11, [x9, x10, lsl #3]
    mov     x12, #1
    lsl     x12, x12, x0
    tst     x11, x12
    b.ne    9f
    orr     x11, x11, x12
    str     x11, [x9, x10, lsl #3]
    ldr     x10, [x19, #W_MSCAP]
    ldr     x9, [x19, #W_MSTK]          // push (a full stack: the block stays marked, and a rescan finds its contents)
    cmp     x24, x10
    b.hs    8f
    add     x9, x19, x9
    str     x0, [x9, x24, lsl #3]
    add     x24, x24, #1
9:  ret
8:  mov     x25, #1
    ret
// g_range: every word from x0 to x1 (addresses) is a candidate. Uses x0-x18.
g_range:
    mov     x18, x30
    mov     x17, x0
1:  cmp     x17, x1
    b.hs    9f
    ldr     x0, [x17], #8
    stp     x1, xzr, [sp, #-16]!
    bl      g_cand
    ldp     x1, xzr, [sp], #16
    b       1b
9:  mov     x30, x18
    ret
// g_block: the words of the block at bit x0. Uses x0-x18.
g_block:
    mov     x26, x30
    ldr     x9, [x19, #W_HEAP0]
    add     x27, x9, x0, lsl #3         // its start (a distance)
    add     x0, x0, #1
    ldr     x1, [x19, #W_HEAP]
    sub     x1, x1, x9
    lsr     x1, x1, #3
    bl      g_next
    ldr     x9, [x19, #W_HEAP0]
    add     x1, x9, x0, lsl #3
    add     x1, x19, x1
    add     x0, x19, x27
    bl      g_range
    mov     x30, x26
    ret
// g_drain: scans what is on the mark stack until it is empty. Uses x0-x18, x26, x27.
g_drain:
    mov     x28, x30
1:  cbz     x24, 9f
    sub     x24, x24, #1
    ldr     x9, [x19, #W_MSTK]
    add     x9, x19, x9
    ldr     x0, [x9, x24, lsl #3]
    bl      g_block
    b       1b
9:  mov     x30, x28
    ret

// gc_collect: marks from the roots, then sweeps the unmarked blocks onto the free list. Called by w_alloc with every register
// saved on the processor's stack below W_NBASE (so they are roots too). Uses x0-x18, x20-x28.
gc_collect:
    stp     x29, x30, [sp, #-16]!
    mov     x24, #0                     // the mark stack's depth
    mov     x25, #0                     // 1: it overflowed
    ldr     x9, [x19, #W_GCS]
    add     x9, x9, #1
    str     x9, [x19, #W_GCS]
    ldr     x0, [x19, #W_MARKS]         // all marks off (only up to the top: the rest are 0 already)
    add     x0, x19, x0
    ldr     x1, [x19, #W_HEAP]
    ldr     x9, [x19, #W_HEAP0]
    sub     x1, x1, x9
    lsr     x1, x1, #6                  // bytes of bitmap below the top, rounded up to words
    add     x1, x1, #8
1:  str     xzr, [x0], #8
    subs    x1, x1, #8
    b.hi    1b
    str     xzr, [x19, #W_FREE]
    // the roots: the header, the constants, the globals, the machine's stack, the processor's stack
    add     x0, x19, #64
    add     x1, x19, #656
    bl      g_range
    bl      g_drain
    ldp     x0, x1, [x19, #W_CONST]
    add     x0, x19, x0
    add     x1, x0, x1, lsl #3
    bl      g_range
    bl      g_drain
    ldp     x0, x1, [x19, #W_GLOB]
    add     x0, x19, x0
    add     x1, x0, x1, lsl #4
    bl      g_range
    bl      g_drain
    ldr     x0, [x19, #W_STACK]
    add     x0, x19, x0
    ldr     x1, [x19, #W_SP]
    add     x1, x19, x1
    bl      g_range
    bl      g_drain
    mov     x0, sp
    ldr     x1, [x19, #W_NBASE]
    cmp     x1, x0
    b.ls    2f
    bl      g_range
    bl      g_drain
2:  cbz     x25, 4f                     // the stack overflowed: every marked block is scanned again until nothing new is marked
    mov     x25, #0
    mov     x20, #0
    ldr     x21, [x19, #W_HEAP]
    ldr     x9, [x19, #W_HEAP0]
    sub     x21, x21, x9
    lsr     x21, x21, #3
3:  mov     x0, x20
    mov     x1, x21
    bl      g_next
    cmp     x0, x21
    b.hs    2b
    mov     x20, x0
    ldr     x9, [x19, #W_MARKS]
    add     x9, x19, x9
    lsr     x10, x0, #6
    ldr     x11, [x9, x10, lsl #3]
    lsr     x11, x11, x0
    tbz     x11, #0, 31f
    bl      g_block
    bl      g_drain
31: add     x20, x20, #1
    b       3b
4:  // the sweep: runs of unmarked blocks become one free block each; a run that reaches the top lowers the top
    mov     x20, #0                     // the bit being looked at
    ldr     x21, [x19, #W_HEAP]
    ldr     x9, [x19, #W_HEAP0]
    sub     x21, x21, x9
    lsr     x21, x21, #3                // the top's bit
    mov     x22, #-1                    // the free run's first bit (-1: none open)
    add     x23, x19, #W_FREE           // where the next free block's distance goes (the list is kept in heap order)
5:  mov     x0, x20
    mov     x1, x21
    bl      g_next
    cmp     x0, x21
    b.hs    7f
    mov     x20, x0
    ldr     x9, [x19, #W_MARKS]
    add     x9, x19, x9
    lsr     x10, x0, #6
    ldr     x11, [x9, x10, lsl #3]
    lsr     x11, x11, x0
    tbnz    x11, #0, 6f
    tbz     x22, #63, 51f               // unmarked: a run begins, or this block joins the one open
    mov     x22, x20
    b       52f
51: ldr     x1, [x19, #W_BITS]
    bl      g_clrbit
52: add     x20, x20, #1
    b       5b
6:  tbnz    x22, #63, 52b               // marked: an open run ends here
    ldr     x9, [x19, #W_HEAP0]
    add     x9, x9, x22, lsl #3
    str     x9, [x23]
    add     x23, x19, x9
    str     xzr, [x23]
    mov     x22, #-1
    b       52b
7:  tbnz    x22, #63, 8f                // a run open at the top: the top comes down to it
    mov     x0, x22
    ldr     x1, [x19, #W_BITS]
    bl      g_clrbit
    ldr     x9, [x19, #W_HEAP0]
    add     x9, x9, x22, lsl #3
    str     x9, [x19, #W_HEAP]
8:  str     xzr, [x23]
    ldp     x29, x30, [sp], #16
    ret

// g_fit: a free block of at least x0 bytes (a multiple of 8) is taken off the list and zeroed -> x0 its distance, or 0.
// Uses x0-x18.
g_fit:
    mov     x18, x30
    mov     x17, x0
    add     x16, x19, #W_FREE           // where the distance of the block being looked at is kept
1:  ldr     x15, [x16]
    cbz     x15, 9f
    ldr     x9, [x19, #W_HEAP0]
    sub     x0, x15, x9
    lsr     x0, x0, #3
    add     x0, x0, #1
    ldr     x1, [x19, #W_HEAP]
    sub     x1, x1, x9
    lsr     x1, x1, #3
    bl      g_next
    ldr     x9, [x19, #W_HEAP0]
    add     x14, x9, x0, lsl #3         // its end
    sub     x13, x14, x15               // its size
    cmp     x13, x17
    b.hs    2f
    add     x16, x19, x15
    b       1b
2:  add     x12, x19, x15
    ldr     x11, [x12]                  // the next
    sub     x13, x13, x17
    cbz     x13, 3f
    add     x10, x15, x17               // the rest stays free, in this one's place on the list
    str     x10, [x16]
    add     x9, x19, x10
    str     x11, [x9]
    ldr     x9, [x19, #W_HEAP0]
    sub     x0, x10, x9
    lsr     x0, x0, #3
    ldr     x1, [x19, #W_BITS]
    bl      g_setbit
    b       4f
3:  str     x11, [x16]
4:  add     x12, x19, x15
    mov     x9, x17
5:  str     xzr, [x12], #8
    subs    x9, x9, #8
    b.hi    5b
    mov     x0, x15
    mov     x30, x18
    ret
9:  mov     x0, #0
    mov     x30, x18
    ret

// w_cut: the top comes down to x1, and every start bit from distance x0 up to the old top is cleared (for the translator's own
// handling of the newest block: giving back unused room, undoing a block). Uses x9-x13.
w_cut:
    ldr     x13, [x19, #W_HEAP]
    str     x1, [x19, #W_HEAP]
    ldr     x9, [x19, #W_HEAP0]
    ldr     x10, [x19, #W_BITS]
    add     x10, x19, x10
    sub     x0, x0, x9
    lsr     x0, x0, #3
    sub     x13, x13, x9
    lsr     x13, x13, #3
1:  cmp     x0, x13
    b.hs    9f
    lsr     x11, x0, #6
    ldr     x12, [x10, x11, lsl #3]
    mov     x9, #1
    lsl     x9, x9, x0
    bic     x12, x12, x9
    str     x12, [x10, x11, lsl #3]
    add     x0, x0, #1
    b       1b
9:  ret
