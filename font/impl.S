// font, written by hand (ARM64): reads a TrueType font, draws and measures text with it. The meaning is font/intent.md; the
// recorded checks are the judge. Entries: x0 surface, x1 numbers (16-bit), x2 how many, x3 the colour, x4 call table.
// Outlines are filled by the fill piece (socket 7); cached letters get their ink from the cover piece (socket 10).
// Through an entry: x19 the frame, x20 the font's bytes, x21 how many, w22 set once the font cannot be followed.
    .text
    .global check
    .global draw
    .global measure
    .global draw_cached
    // what the font says of itself
    .equ CMAP4, 96
    .equ LOCA, 100
    .equ GLYF, 104
    .equ HMTX, 108
    .equ UPM, 112
    .equ GLYPHS, 116
    .equ HMETRICS, 120
    .equ LONGLOCA, 124
    .equ GPOS, 128
    .equ KERNS, 132
    .equ KLOOK, 136
    .equ KINDEX, 168
    // the run of text
    .equ S, 200
    .equ P, 208
    .equ N, 216
    .equ COLOUR, 224
    .equ TABLE, 232
    .equ PAINT, 240
    .equ SIZE16, 248
    .equ PEN16, 256
    .equ BASE16, 264
    .equ BEGIN, 272
    .equ BEFORE, 280
    .equ K, 288
    .equ G, 296
    .equ SH_USED, 300
    .equ O_P, 304
    .equ O_PART, 312
    .equ O_FL, 316
    .equ O_DX, 320
    .equ O_DY, 324
    .equ S_FIRST, 348
    .equ S_C, 352
    .equ S_NC, 356
    .equ S_TOTAL, 360
    .equ S_PEN, 384
    .equ S_BASE, 392
    .equ CACHE, 408
    .equ MASK, 416
    .equ ROOM, 424
    .equ ALPHA, 432
    .equ KEY, 436
    .equ FOUND, 440
    .equ EMPTY, 448
    .equ PX0, 456
    .equ BASE, 464
    .equ SIZE, 472
    .equ T_LEFT, 480
    .equ T_TOP, 484
    .equ T_W, 488
    .equ T_H, 492
    .equ KL, 496
    .equ KR, 500
    .equ KTYPE, 504
    .equ ENDS, 512
    .equ FLAGS, 768
    .equ XS, 1376
    .equ YS, 3776
    .equ PX, 6176
    .equ PY, 10976
    .equ ON, 15776
    .equ PTS, 16976
    .equ SHAPE, 18000
    .equ FRAME, 22800
    .macro  ADDR reg, off
    mov     \reg, #\off
    add     \reg, x19, \reg
    .endm
    // Readers. U8, U16, U32: past the end the answer is 0 and the font is marked as not followable. G16: past the end it is 0
    // and nothing else (a font with a damaged spacing table is still a font). \at is an x register, not x16; uses x16.
    .macro  U8 dst, at
    cmp     \at, x21
    b.hs    91f
    ldrb    \dst, [x20, \at]
    b       92f
91: mov     \dst, #0
    mov     w22, #1
92:
    .endm
    .macro  U16 dst, at
    add     x16, \at, #2
    cmp     x16, x21
    b.hi    91f
    ldrh    \dst, [x20, \at]
    rev16   \dst, \dst
    b       92f
91: mov     \dst, #0
    mov     w22, #1
92:
    .endm
    .macro  U32 dst, at
    add     x16, \at, #4
    cmp     x16, x21
    b.hi    91f
    ldr     \dst, [x20, \at]
    rev     \dst, \dst
    b       92f
91: mov     \dst, #0
    mov     w22, #1
92:
    .endm
    .macro  G16 dst, at
    add     x16, \at, #2
    cmp     x16, x21
    b.hi    91f
    ldrh    \dst, [x20, \at]
    rev16   \dst, \dst
    b       92f
91: mov     \dst, #0
92:
    .endm
    // SCALE: \v (64-bit, signed) font units as sixteenths of a dot at this size, rounded to nearest -> \v. Uses x15-x17.
    .macro  SCALE v
    ldr     x15, [x19, #SIZE16]
    mul     \v, \v, x15
    ldr     w15, [x19, #UPM]
    add     \v, \v, x15, lsr #1
    sdiv    x16, \v, x15
    msub    x17, x16, x15, \v
    cmp     x17, #0
    cset    x17, lt
    sub     \v, x16, x17
    .endm
check:
    ldr     w9, [x0]
    cmp     w9, #1
    b.ne    9f
    ldr     w10, [x0, #4]
    ldr     w11, [x0, #8]
    ldr     w12, [x0, #12]
    ldr     x13, [x0, #16]
    sub     w14, w10, #1
    cmp     w14, #16384
    b.hs    9f
    sub     w14, w11, #1
    cmp     w14, #16384
    b.hs    9f
    cmp     w12, w10, lsl #2
    b.ne    9f
    umull   x14, w12, w11
    add     x14, x14, #64
    cmp     x13, x14
    b.ne    9f
    mov     x0, #1
    ret
9:  mov     x0, #0
    ret

// ---- spacing between pairs of letters: the font's own table (GPOS, feature "kern", pair adjustment) ----
// find_kerning: which of the font's lookups the "kern" feature uses, at most eight, in the font's own order. Uses x0-x17.
find_kerning:
    ldr     w0, [x19, #GPOS]
    cbz     w0, 9f
    add     x1, x0, #6
    G16     w2, x1
    add     x2, x0, x2                  // the features
    add     x1, x0, #8
    G16     w3, x1
    add     x3, x0, x3                  // the lookups
    G16     w4, x2                      // how many features
    G16     w5, x3                      // how many lookups
    cmp     w4, #512
    mov     w6, #512
    csel    w4, w6, w4, hi
    mov     x6, #0
1:  cmp     w6, w4
    b.hs    7f
    add     x7, x6, x6, lsl #1
    add     x7, x2, x7, lsl #1          // this feature's record, less two
    add     x8, x7, #2
    G16     w9, x8
    add     x8, x7, #4
    G16     w10, x8
    orr     w9, w10, w9, lsl #16
    ldr     w10, =0x6b65726e            // "kern"
    cmp     w9, w10
    b.ne    6f
    add     x8, x7, #6
    G16     w9, x8
    add     x9, x2, x9                  // the feature
    add     x8, x9, #2
    G16     w10, x8                     // how many lookups it uses
    cmp     w10, #64
    mov     w11, #64
    csel    w10, w11, w10, hi
    mov     x11, #0
2:  cmp     w11, w10
    b.hs    6f
    add     x8, x9, #4
    add     x8, x8, x11, lsl #1
    G16     w12, x8                     // one of them
    add     x11, x11, #1
    cmp     w12, w5
    b.hs    2b
    ldr     w13, [x19, #KERNS]
    add     x14, x19, #KINDEX
    mov     w15, #0                     // where it belongs
    mov     w17, #0                     // already there?
    mov     x8, #0
3:  cmp     w8, w13
    b.hs    4f
    ldr     w0, [x14, x8, lsl #2]
    cmp     w0, w12
    csinc   w17, w17, wzr, ne
    add     w1, w8, #1
    csel    w15, w1, w15, lo
    add     x8, x8, #1
    b       3b
4:  cbnz    w17, 2b
    cmp     w13, #8
    b.hs    2b
    mov     w8, w13
5:  cmp     w8, w15
    b.ls    8f
    sub     w0, w8, #1
    ldr     w1, [x14, x0, lsl #2]
    str     w1, [x14, x8, lsl #2]
    mov     w8, w0
    b       5b
8:  str     w12, [x14, x15, lsl #2]
    add     w13, w13, #1
    str     w13, [x19, #KERNS]
    b       2b
6:  add     x6, x6, #1
    b       1b
7:  ldr     w13, [x19, #KERNS]
    mov     x8, #0
10: cmp     w8, w13
    b.hs    9f
    add     x14, x19, #KINDEX
    ldr     w0, [x14, x8, lsl #2]
    add     x1, x3, #2
    add     x1, x1, x0, lsl #1
    G16     w0, x1
    add     w0, w0, w3
    add     x14, x19, #KLOOK
    str     w0, [x14, x8, lsl #2]
    add     x8, x8, #1
    b       10b
9:  ret
    .ltorg
// covered: the glyph w1's place in the coverage list at x0, or -1 -> w0. Uses x2-x8, x16.
covered:
    G16     w2, x0
    add     x3, x0, #2
    G16     w4, x3                      // how many
    mov     w3, #0
    cmp     w2, #1
    b.ne    3f
1:  cmp     w3, w4                      // a sorted list of glyphs
    b.hs    9f
    add     w5, w3, w4
    lsr     w5, w5, #1
    add     x6, x0, #4
    add     x6, x6, x5, lsl #1
    G16     w7, x6
    cmp     w7, w1
    b.ne    2f
    mov     w0, w5
    ret
2:  csinc   w3, w3, w5, hs
    csel    w4, w5, w4, hs
    b       1b
3:  cmp     w2, #2
    b.ne    9f
4:  cmp     w3, w4                      // a sorted list of ranges
    b.hs    9f
    add     w5, w3, w4
    lsr     w5, w5, #1
    add     x6, x5, x5, lsl #1
    add     x6, x0, x6, lsl #1
    add     x6, x6, #4
    G16     w7, x6
    cmp     w1, w7
    b.hs    5f
    mov     w4, w5
    b       4b
5:  add     x8, x6, #2
    G16     w2, x8
    cmp     w1, w2
    b.ls    6f
    add     w3, w5, #1
    b       4b
6:  add     x8, x6, #4
    G16     w2, x8
    add     w0, w2, w1
    sub     w0, w0, w7
    ret
9:  mov     w0, #-1
    ret
// class_of: the class the glyph w1 is in, by the class list at x0 -> w0. Uses x2-x8, x16.
class_of:
    G16     w2, x0
    cmp     w2, #1
    b.ne    2f
    add     x3, x0, #2
    G16     w4, x3                      // first glyph
    add     x3, x0, #4
    G16     w5, x3                      // how many
    cmp     w1, w4
    b.lo    9f
    sub     w6, w1, w4
    cmp     w6, w5
    b.hs    9f
    add     x3, x0, #6
    add     x3, x3, x6, lsl #1
    G16     w0, x3
    ret
2:  cmp     w2, #2
    b.ne    9f
    add     x3, x0, #2
    G16     w4, x3
    mov     w3, #0
3:  cmp     w3, w4
    b.hs    9f
    add     w5, w3, w4
    lsr     w5, w5, #1
    add     x6, x5, x5, lsl #1
    add     x6, x0, x6, lsl #1
    add     x6, x6, #4
    G16     w7, x6
    cmp     w1, w7
    b.hs    4f
    mov     w4, w5
    b       3b
4:  add     x8, x6, #2
    G16     w2, x8
    cmp     w1, w2
    b.ls    5f
    add     w3, w5, #1
    b       3b
5:  add     x8, x6, #4
    G16     w0, x8
    ret
9:  mov     w0, #0
    ret
// COUNT2: twice the number of set bits in \src (16 bits) -> \dst. Uses v0.
    .macro  COUNT2 dst, src
    fmov    s0, \src
    cnt     v0.8b, v0.8b
    addv    b0, v0.8b
    fmov    \dst, s0
    lsl     \dst, \dst, #1
    .endm
// kern_units: how much closer (negative) or further apart the glyphs w0 and w1 sit, in the font's units -> w0
kern_units:
    stp     x29, x30, [sp, #-64]!
    stp     x23, x24, [sp, #16]
    stp     x25, x26, [sp, #32]
    stp     x27, x28, [sp, #48]
    str     w0, [x19, #KL]
    str     w1, [x19, #KR]
    mov     w23, #0                     // the total
    mov     x24, #0                     // which lookup
k_lookup:
    ldr     w9, [x19, #KERNS]
    cmp     w24, w9
    b.ge    k_done
    add     x9, x19, #KLOOK
    ldr     w25, [x9, x24, lsl #2]      // the lookup
    add     x24, x24, #1
    G16     w9, x25
    str     w9, [x19, #KTYPE]
    add     x9, x25, #4
    G16     w27, x9                     // how many subtables
    cmp     w27, #256
    mov     w9, #256
    csel    w27, w9, w27, hi
    mov     x26, #0
k_sub:
    cmp     w26, w27
    b.hs    k_lookup
    add     x9, x25, #6
    add     x9, x9, x26, lsl #1
    add     x26, x26, #1
    G16     w28, x9
    add     x28, x25, x28               // the subtable
    ldr     w10, [x19, #KTYPE]
    cmp     w10, #9
    b.ne    1f
    G16     w9, x28                     // an extension: the real subtable is elsewhere
    cmp     w9, #1
    b.ne    k_sub
    add     x9, x28, #2
    G16     w10, x9
    add     x9, x28, #4
    G16     w11, x9
    add     x9, x28, #6
    G16     w12, x9
    orr     w11, w12, w11, lsl #16
    add     x28, x28, x11
1:  cmp     w10, #2
    b.ne    k_sub
    add     x9, x28, #2
    G16     w0, x9
    add     x0, x28, x0
    ldr     w1, [x19, #KL]
    bl      covered
    tbnz    w0, #31, k_sub
    mov     w29, w0                     // the left glyph's place (x29 is saved above and free here)
    G16     w9, x28                     // format
    add     x10, x28, #4
    G16     w11, x10                    // what is stored for the left glyph of a pair
    add     x10, x28, #6
    G16     w12, x10                    // and for the right
    COUNT2  w13, w11
    COUNT2  w14, w12
    add     w13, w13, w14               // bytes of adjustments a pair
    and     w14, w11, #3
    COUNT2  w14, w14                    // where the advance is among them
    cmp     w9, #1
    b.ne    k_classes
    add     x10, x28, #8
    G16     w15, x10
    cmp     w29, w15
    b.hs    k_sub
    add     x10, x28, #10
    add     x10, x10, x29, lsl #1
    G16     w15, x10
    add     x15, x28, x15               // the pairs that begin with the left glyph, sorted by the right
    G16     w1, x15
    mov     w0, #0
    add     w13, w13, #2
    ldr     w2, [x19, #KR]
2:  cmp     w0, w1
    b.hs    k_sub
    add     w3, w0, w1
    lsr     w3, w3, #1
    umull   x4, w3, w13
    add     x4, x4, x15
    add     x4, x4, #2
    G16     w5, x4
    cmp     w5, w2
    b.eq    3f
    csinc   w0, w0, w3, hs
    csel    w1, w3, w1, hs
    b       2b
3:  tbz     w11, #2, k_lookup
    add     x4, x4, #2
    add     x4, x4, x14
    G16     w5, x4
    add     w23, w23, w5, sxth
    b       k_lookup
k_classes:
    cmp     w9, #2
    b.ne    k_sub
    str     w11, [x19, #O_FL]           // (kept across the two class searches)
    str     w13, [x19, #O_DX]
    str     w14, [x19, #O_DY]
    add     x10, x28, #8
    G16     w0, x10
    add     x0, x28, x0
    ldr     w1, [x19, #KL]
    bl      class_of
    mov     w29, w0
    add     x10, x28, #10
    G16     w0, x10
    add     x0, x28, x0
    ldr     w1, [x19, #KR]
    bl      class_of
    add     x10, x28, #12
    G16     w11, x10
    add     x10, x28, #14
    G16     w12, x10
    cmp     w29, w11
    b.hs    k_sub
    cmp     w0, w12
    b.hs    k_sub
    ldr     w11, [x19, #O_FL]
    tbz     w11, #2, k_lookup
    umull   x10, w29, w12
    add     x10, x10, x0
    ldr     w13, [x19, #O_DX]
    mul     x10, x10, x13
    ldr     w14, [x19, #O_DY]
    add     x10, x10, x14
    add     x10, x10, x28
    add     x10, x10, #16
    G16     w5, x10
    add     w23, w23, w5, sxth
    b       k_lookup
k_done:
    mov     w0, w23
    ldp     x23, x24, [sp, #16]
    ldp     x25, x26, [sp, #32]
    ldp     x27, x28, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret

// open_font: the font in the block x0 (or 0): where its tables are -> x0 1 or 0
open_font:
    str     x30, [x19, #O_P]
    cbz     x0, o_no
    ldr     w9, [x0]
    cmp     w9, #2
    b.ne    o_no
    ldr     x21, [x0, #16]
    cmp     x21, #(64 + 12)
    b.lo    o_no
    sub     x21, x21, #64
    add     x20, x0, #64
    mov     w22, #0
    add     x9, x19, #CMAP4
    mov     x10, #13
1:  str     xzr, [x9], #8               // nothing is known yet
    subs    x10, x10, #1
    b.ne    1b
    mov     x0, #4
    U16     w1, x0
    cmp     w1, #64
    mov     w2, #64
    csel    w1, w2, w1, hi
    mov     w2, #0                      // cmap
    mov     w3, #0                      // head
    mov     w4, #0                      // hhea
    mov     w5, #0                      // maxp
    mov     x6, #0
2:  cmp     w6, w1
    b.hs    4f
    lsl     x7, x6, #4
    add     x7, x7, #12
    U32     w8, x7
    add     x7, x7, #8
    U32     w9, x7
    add     x6, x6, #1
    .macro  TAG value, then
    ldr     w10, =\value
    cmp     w8, w10
    b.ne    93f
    \then
    b       2b
93:
    .endm
    TAG     0x636d6170, "mov w2, w9"
    TAG     0x6c6f6361, "str w9, [x19, #LOCA]"
    TAG     0x676c7966, "str w9, [x19, #GLYF]"
    TAG     0x686d7478, "str w9, [x19, #HMTX]"
    TAG     0x47504f53, "str w9, [x19, #GPOS]"
    TAG     0x68656164, "mov w3, w9"
    TAG     0x68686561, "mov w4, w9"
    TAG     0x6d617870, "mov w5, w9"
    b       2b
4:  cbz     w2, o_no
    cbz     w3, o_no
    cbz     w4, o_no
    cbz     w5, o_no
    ldr     w9, [x19, #LOCA]
    cbz     w9, o_no
    ldr     w9, [x19, #GLYF]
    cbz     w9, o_no
    ldr     w9, [x19, #HMTX]
    cbz     w9, o_no
    add     x7, x3, #18
    U16     w8, x7                      // units to the em
    str     w8, [x19, #UPM]
    add     x7, x3, #50
    U16     w9, x7
    cmp     w9, #0
    cset    w9, ne
    str     w9, [x19, #LONGLOCA]
    add     x7, x5, #4
    U16     w9, x7
    str     w9, [x19, #GLYPHS]
    add     x7, x4, #34
    U16     w10, x7
    str     w10, [x19, #HMETRICS]
    cmp     w8, #16
    b.lo    o_no
    cmp     w8, #16384
    b.hi    o_no
    cbz     w10, o_no
    cbz     w9, o_no
    add     x7, x2, #2
    U16     w1, x7                      // the character maps: the first of the usual kind for the common plane
    cmp     w1, #32
    mov     w9, #32
    csel    w1, w9, w1, hi
    mov     x6, #0
5:  cmp     w6, w1
    b.hs    7f
    add     x7, x2, x6, lsl #3
    add     x6, x6, #1
    add     x8, x7, #4
    U16     w9, x8
    add     x8, x7, #6
    U16     w10, x8
    add     x8, x7, #8
    U32     w11, x8
    add     x8, x2, x11
    U16     w12, x8
    cmp     w12, #4
    b.ne    5b
    cbz     w9, 6f
    cmp     w9, #3
    b.ne    5b
    cmp     w10, #1
    b.ne    5b
6:  add     w8, w2, w11
    str     w8, [x19, #CMAP4]
7:  ldr     w9, [x19, #CMAP4]
    cbz     w9, o_no
    cbnz    w22, o_no
    bl      find_kerning
    ldr     w9, [x19, #CMAP4]
    cbz     w9, o_no
    cbnz    w22, o_no
    mov     x0, #1
    b       o_out
o_no:
    mov     x0, #0
o_out:
    ldr     x30, [x19, #O_P]
    ret
    .ltorg
// glyph_of: which glyph draws the character w0 -> w0 (0: none). Uses x1-x12, x16.
glyph_of:
    ldr     w1, [x19, #CMAP4]
    add     x2, x1, #6
    U16     w3, x2
    lsr     w3, w3, #1                  // how many ranges of characters
    cmp     w3, #4096
    mov     w4, #4096
    csel    w3, w4, w3, hi
    add     x4, x1, #14                 // their ends
    add     x5, x4, x3, lsl #1
    add     x5, x5, #2                  // their starts
    add     x6, x5, x3, lsl #1          // what to add
    add     x7, x6, x3, lsl #1          // or where to look
    mov     x8, #0
1:  cmp     w8, w3
    b.hs    9f
    add     x9, x4, x8, lsl #1
    U16     w10, x9
    cmp     w0, w10
    b.ls    2f
    add     x8, x8, #1
    b       1b
2:  add     x9, x5, x8, lsl #1
    U16     w10, x9
    cmp     w0, w10
    b.lo    9f
    add     x9, x7, x8, lsl #1
    U16     w11, x9
    add     x12, x6, x8, lsl #1
    U16     w12, x12
    cbnz    w11, 3f
    add     w0, w0, w12
    and     w0, w0, #0xffff
    ret
3:  sub     w10, w0, w10
    add     x9, x9, x11
    add     x9, x9, x10, lsl #1
    U16     w0, x9
    cbz     w0, 8f
    add     w0, w0, w12
    and     w0, w0, #0xffff
8:  ret
9:  mov     w0, #0
    ret
// glyph_span: where the glyph w0's outlines are -> w0 1 or 0 (none), w1 the start, w2 the end. Uses x3, x4, x16.
glyph_span:
    ldr     w3, [x19, #GLYPHS]
    cmp     w0, w3
    b.hs    9f
    ldr     w3, [x19, #LOCA]
    ldr     w4, [x19, #LONGLOCA]
    cbz     w4, 1f
    add     x3, x3, x0, lsl #2
    U32     w1, x3
    add     x3, x3, #4
    U32     w2, x3
    b       2f
1:  add     x3, x3, x0, lsl #1
    U16     w1, x3
    add     x3, x3, #2
    U16     w2, x3
    lsl     w1, w1, #1
    lsl     w2, w2, #1
2:  cmp     w2, w1
    b.ls    9f
    cbnz    w22, 9f
    mov     w0, #1
    ret
9:  mov     w0, #0
    ret

// simple: one simple glyph's outlines (at w0 in the glyph table), moved by w1, w2 font units, scaled and placed at S_PEN, S_BASE,
// appended to the shape. A curve's pull becomes four straight steps.
    // SC: font units \v (w) -> sixteenths of a dot (x \dst). Uses x16, x17. x23 the size, x24 units to the em.
    .macro  SC dst, v
    sxtw    x16, \v
    mul     x16, x16, x23
    add     x16, x16, x24, lsr #1
    sdiv    \dst, x16, x24
    msub    x17, \dst, x24, x16
    cmp     x17, #0
    cset    x17, lt
    sub     \dst, \dst, x17
    .endm
    // PUTPT: the point \x, \y (w) joins this outline's points, if it and they still fit. Uses x16, x17. w13 the count, w7 "ok".
    .macro  PUTPT x, y
    mov     w17, #65534
    mov     w16, #32767
    add     w16, \x, w16
    cmp     w16, w17
    b.hi    94f
    mov     w16, #32767
    add     w16, \y, w16
    cmp     w16, w17
    b.hi    94f
    cmp     w13, #256
    b.hs    94f
    add     x16, x6, x13, lsl #2
    strh    \x, [x16]
    strh    \y, [x16, #2]
    add     w13, w13, #1
    b       95f
94: mov     w7, #0
95:
    .endm
simple:
    stp     x23, x24, [sp, #-48]!
    stp     x25, x26, [sp, #16]
    stp     x27, x28, [sp, #32]
    ldr     x23, [x19, #SIZE16]
    ldr     w24, [x19, #UPM]
    ldr     x25, [x19, #S_PEN]
    ldr     x26, [x19, #S_BASE]
    mov     w27, w1
    mov     w28, w2
    ldr     w5, [x19, #GLYF]
    add     x5, x5, x0                  // where we are in the glyph
    U16     w9, x5
    sxth    w9, w9
    cmp     w9, #0
    b.le    s_out
    cmp     w9, #64
    b.gt    s_out
    str     w9, [x19, #S_NC]
    add     x5, x5, #10
    add     x10, x19, #ENDS             // where each outline ends
    mov     x11, #0
1:  U16     w12, x5
    add     x5, x5, #2
    str     w12, [x10, x11, lsl #2]
    add     x11, x11, #1
    cmp     w11, w9
    b.lo    1b
    add     w12, w12, #1                // points in all
    cmp     w12, #600
    b.hi    s_out
    str     w12, [x19, #S_TOTAL]
    U16     w9, x5
    add     x5, x5, x9
    add     x5, x5, #2
    add     x8, x19, #FLAGS             // each point's flags; a flag may say it repeats
    mov     x11, #0
2:  cmp     w11, w12
    b.hs    4f
    U8      w9, x5
    add     x5, x5, #1
    strb    w9, [x8, x11]
    add     x11, x11, #1
    tbz     w9, #3, 2b
    U8      w10, x5
    add     x5, x5, #1
3:  cbz     w10, 2b
    sub     w10, w10, #1
    cmp     w11, w12
    b.hs    2b
    strb    w9, [x8, x11]
    add     x11, x11, #1
    b       3b
4:  .macro  COORDS base, short, same
    ADDR    x6, \base
    mov     w0, #0
    mov     x11, #0
96: cmp     w11, w12
    b.hs    99f
    ldrb    w9, [x8, x11]
    tbz     w9, #\short, 97f
    U8      w10, x5
    add     x5, x5, #1
    tst     w9, #(1 << \same)
    cneg    w10, w10, eq
    add     w0, w0, w10
    b       98f
97: tbnz    w9, #\same, 98f
    U16     w10, x5
    add     x5, x5, #2
    add     w0, w0, w10, sxth
98: str     w0, [x6, x11, lsl #2]
    add     x11, x11, #1
    b       96b
99:
    .endm
    COORDS  XS, 1, 4                    // each point as a step from the one before: one byte, two, or none
    COORDS  YS, 2, 5
    cbnz    w22, s_out
    str     wzr, [x19, #S_FIRST]
    str     wzr, [x19, #S_C]
s_contour:
    ldr     w9, [x19, #S_C]
    ldr     w10, [x19, #S_NC]
    cmp     w9, w10
    b.ge    s_out
    add     x10, x19, #ENDS
    ldr     w10, [x10, x9, lsl #2]      // this outline's last point
    add     w9, w9, #1
    str     w9, [x19, #S_C]
    ldr     w14, [x19, #S_FIRST]
    ldr     w12, [x19, #S_TOTAL]
    cmp     w10, w14
    b.lo    s_out
    cmp     w10, w12
    b.hs    s_out
    sub     w13, w10, w14
    add     w13, w13, #1                // its points
    add     w10, w10, #1
    str     w10, [x19, #S_FIRST]
    ADDR    x6, XS
    ADDR    x7, YS
    add     x8, x19, #FLAGS
    ADDR    x9, PX
    ADDR    x10, PY
    ADDR    x11, ON
    mov     w15, #0                     // scaled points made, with the midpoints two pulls imply made explicit
    mov     w12, #0
1:  cmp     w12, w13
    b.hs    4f
    add     w0, w14, w12                // this point, and the next one round
    add     w1, w12, #1
    cmp     w1, w13
    csel    w1, wzr, w1, eq
    add     w1, w1, w14
    ldr     w2, [x6, x0, lsl #2]
    add     w2, w2, w27
    SC      x2, w2
    add     x2, x25, x2
    ldr     w3, [x7, x0, lsl #2]
    add     w3, w3, w28
    SC      x3, w3
    sub     x3, x26, x3
    str     w2, [x9, x15, lsl #2]
    str     w3, [x10, x15, lsl #2]
    ldrb    w4, [x8, x0]
    and     w4, w4, #1
    strb    w4, [x11, x15]
    add     w15, w15, #1
    cbnz    w4, 3f
    ldrb    w4, [x8, x1]
    tbnz    w4, #0, 3f
    ldr     w4, [x6, x1, lsl #2]
    add     w4, w4, w27
    SC      x4, w4
    add     x4, x25, x4
    add     x2, x4, w2, sxtw
    asr     x2, x2, #1
    str     w2, [x9, x15, lsl #2]
    ldr     w4, [x7, x1, lsl #2]
    add     w4, w4, w28
    SC      x4, w4
    sub     x4, x26, x4
    add     x3, x4, w3, sxtw
    asr     x3, x3, #1
    str     w3, [x10, x15, lsl #2]
    mov     w4, #1
    strb    w4, [x11, x15]
    add     w15, w15, #1
3:  add     w12, w12, #1
    b       1b
4:  mov     w14, #0                     // start from a point that is on the outline
5:  cmp     w14, w15
    b.hs    s_contour
    ldrb    w4, [x11, x14]
    cbnz    w4, 6f
    add     w14, w14, #1
    b       5b
6:  ADDR    x6, PTS
    mov     w13, #0
    mov     w7, #1
    ldr     w0, [x9, x14, lsl #2]       // where the pen is
    ldr     w1, [x10, x14, lsl #2]
    PUTPT   w0, w1
    mov     w12, #1
s_walk:
    cmp     w12, w15
    b.hi    s_keep
    cbz     w7, s_keep
    add     w2, w14, w12
    udiv    w3, w2, w15
    msub    w2, w3, w15, w2             // the point being reached
    ldrb    w3, [x11, x2]
    cbz     w3, 1f
    ldr     w0, [x9, x2, lsl #2]
    ldr     w1, [x10, x2, lsl #2]
    add     w12, w12, #1
    cmp     w12, w15                    // (the last one closes the outline and is not repeated)
    b.hi    s_walk
    PUTPT   w0, w1
    b       s_walk
1:  add     w3, w14, w12                // a pull: four straight steps towards the point after it
    add     w3, w3, #1
    udiv    w4, w3, w15
    msub    w3, w4, w15, w3
    ldr     w4, [x9, x3, lsl #2]        // where the curve ends
    ldr     w5, [x10, x3, lsl #2]
    ldr     w8, [x9, x2, lsl #2]        // the pull
    ldr     w2, [x10, x2, lsl #2]
    mov     w3, #1
2:  cmp     w3, #4
    b.hi    4f
    cbz     w7, 4f
    .macro  STEP dst, from, pull, to
    mov     w16, #4
    sub     w16, w16, w3
    mul     w17, w16, w16
    smull   \dst, w17, \from
    mul     w17, w16, w3
    lsl     w17, w17, #1
    smaddl  \dst, w17, \pull, \dst
    mul     w17, w3, w3
    smaddl  \dst, w17, \to, \dst
    add     \dst, \dst, #8
    asr     \dst, \dst, #4
    .endm
    STEP    x23, w0, w8, w4             // (x23 and x24 are reloaded for each outline's scaling above; here they are free)
    STEP    x24, w1, w2, w5
    cmp     w3, #4
    b.ne    3f
    add     w16, w12, #1
    cmp     w16, w15
    b.hs    5f
3:  PUTPT   w23, w24
5:  add     w3, w3, #1
    b       2b
4:  mov     w0, w4
    mov     w1, w5
    add     w12, w12, #2
    ldr     x23, [x19, #SIZE16]
    ldr     w24, [x19, #UPM]
    ADDR    x8, FLAGS
    b       s_walk
s_keep:
    ldr     x23, [x19, #SIZE16]
    ldr     w24, [x19, #UPM]
    cbz     w7, s_contour
    cmp     w13, #2
    b.lt    s_contour
    ldr     w0, [x19, #SH_USED]
    add     w1, w0, w13, lsl #1
    add     w1, w1, #1
    cmp     w1, #2400
    b.gt    s_contour
    ADDR    x2, SHAPE
    strh    w13, [x2, x0, lsl #1]
    add     w0, w0, #1
    lsl     w3, w13, #1
    mov     x4, #0
7:  ldrh    w5, [x6, x4, lsl #1]
    strh    w5, [x2, x0, lsl #1]
    add     w0, w0, #1
    add     x4, x4, #1
    cmp     w4, w3
    b.lo    7b
    str     w0, [x19, #SH_USED]
    b       s_contour
s_out:
    ldp     x25, x26, [sp, #16]
    ldp     x27, x28, [sp, #32]
    ldp     x23, x24, [sp], #48
    ret

// outline: the glyph w0's outlines, placed at x1, x2 (sixteenths of a dot), appended to the shape. A glyph made of others
// (a letter and its accent, say) is assembled from up to sixteen of them.
outline:
    stp     x29, x30, [sp, #-16]!
    str     x1, [x19, #S_PEN]
    str     x2, [x19, #S_BASE]
    bl      glyph_span
    cbz     w0, t_out
    ldr     w9, [x19, #GLYF]
    add     x9, x9, x1
    U16     w10, x9
    tbnz    w10, #15, 1f
    mov     w0, w1
    mov     w1, #0
    mov     w2, #0
    bl      simple
    b       t_out
1:  add     x9, x9, #10
    str     x9, [x19, #O_P]
    str     wzr, [x19, #O_PART]
t_part:
    ldr     w9, [x19, #O_PART]
    cmp     w9, #16
    b.ge    t_out
    cbnz    w22, t_out
    add     w9, w9, #1
    str     w9, [x19, #O_PART]
    ldr     x9, [x19, #O_P]
    U16     w10, x9                     // how this part is described
    str     w10, [x19, #O_FL]
    add     x11, x9, #2
    U16     w12, x11                    // which glyph it is
    add     x9, x9, #4
    tbz     w10, #0, 2f
    U16     w13, x9
    sxth    w13, w13
    add     x11, x9, #2
    U16     w14, x11
    sxth    w14, w14
    add     x9, x9, #4
    b       3f
2:  U8      w13, x9
    sxtb    w13, w13
    add     x11, x9, #1
    U8      w14, x11
    sxtb    w14, w14
    add     x9, x9, #2
3:  tbnz    w10, #1, 4f
    mov     w13, #0
    mov     w14, #0
4:  tbz     w10, #3, 5f
    add     x9, x9, #2
    b       7f
5:  tbz     w10, #6, 6f
    add     x9, x9, #4
    b       7f
6:  tbz     w10, #7, 7f
    add     x9, x9, #8
7:  str     x9, [x19, #O_P]
    str     w13, [x19, #O_DX]
    str     w14, [x19, #O_DY]
    mov     w0, w12
    bl      glyph_span
    cbz     w0, 8f
    ldr     w9, [x19, #GLYF]
    add     x9, x9, x1
    U16     w10, x9
    sxth    w10, w10
    cmp     w10, #0
    b.le    8f
    mov     w0, w1
    ldr     w1, [x19, #O_DX]
    ldr     w2, [x19, #O_DY]
    bl      simple
8:  ldr     w10, [x19, #O_FL]
    tbnz    w10, #5, t_part
t_out:
    ldp     x29, x30, [sp], #16
    ret

    .macro  ENTER
    mov     x9, #FRAME
    sub     sp, sp, x9
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, sp
    str     x0, [x19, #S]
    str     x1, [x19, #P]
    str     x2, [x19, #N]
    and     x3, x3, #0xffffffff
    str     x3, [x19, #COLOUR]
    str     x4, [x19, #TABLE]
    .endm
    .macro  LEAVE
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    mov     x9, #FRAME
    add     sp, sp, x9
    ret
    .endm
// NUM: number \i of the entry's numbers, or 0 if there are not that many -> \reg (64-bit, signed; not x10). Uses x10.
    .macro  NUM reg, i
    ldr     x10, [x19, #N]
    mov     \reg, #0
    cmp     x10, #\i
    b.le    61f
    ldr     x10, [x19, #P]
    ldrsh   \reg, [x10, #(\i * 2)]
61:
    .endm
// BLOCKOF: the block at the handle x9 (0 to 255), or 0 -> x0. Uses x10.
    .macro  BLOCKOF
    mov     x0, #0
    cmp     x9, #0
    b.lt    62f
    cmp     x9, #255
    b.gt    62f
    add     x9, x9, #256
    ldr     x10, [x19, #TABLE]
    ldr     x0, [x10, x9, lsl #3]
62:
    .endm
// FILL: the shape gathered is filled on the surface in the entry's colour, if there is any of it
    .macro  FILL
    ldr     w2, [x19, #SH_USED]
    cbz     w2, 63f
    ldr     x0, [x19, #S]
    ADDR    x1, SHAPE
    ldr     x3, [x19, #COLOUR]
    ldr     x4, [x19, #TABLE]
    ldr     x9, [x4, #(7 * 8)]
    blr     x9
63:
    .endm
// GLYPH: the glyph for the character w0 -> G; spacing against the glyph before is added to the pen. On a font that cannot be
// followed, goes to \bad.
    .macro  GLYPH bad
    bl      glyph_of
    cbnz    w22, \bad
    str     w0, [x19, #G]
    ldr     x9, [x19, #BEFORE]
    tbnz    x9, #63, 64f
    mov     w1, w0
    mov     w0, w9
    bl      kern_units
    sxtw    x0, w0
    SCALE   x0
    ldr     x9, [x19, #PEN16]
    add     x9, x9, x0
    str     x9, [x19, #PEN16]
64: ldr     w9, [x19, #G]
    str     x9, [x19, #BEFORE]
    .endm
// ADVANCE: the pen moves on by the glyph's width. On a font that cannot be followed, goes to \bad.
    .macro  ADVANCE bad
    ldr     w9, [x19, #G]
    ldr     w10, [x19, #HMETRICS]
    sub     w11, w10, #1
    cmp     w9, w10
    csel    w9, w9, w11, lo
    ldr     w10, [x19, #HMTX]
    add     x10, x10, x9, lsl #2
    U16     w0, x10
    cbnz    w22, \bad
    SCALE   x0
    ldr     x9, [x19, #PEN16]
    add     x9, x9, x0
    str     x9, [x19, #PEN16]
    .endm

// draw: numbers are the font's handle, the size in dots, left, the line the letters stand on, then the characters -> where the
// pen ends, in sixteenths of a dot. measure: the font's handle, the size, the characters -> how wide, in sixteenths.
draw:
    ENTER
    mov     w9, #1
    str     w9, [x19, #PAINT]
    b       run
measure:
    ENTER
    str     wzr, [x19, #PAINT]
    str     xzr, [x19, #COLOUR]
run:
    NUM     x9, 0
    BLOCKOF
    bl      open_font
    cbz     x0, r_bad
    NUM     x11, 1
    cmp     x11, #4
    b.lt    r_bad
    cmp     x11, #1000
    b.gt    r_bad
    lsl     x11, x11, #4
    str     x11, [x19, #SIZE16]
    mov     x12, #0
    mov     x13, #0
    mov     x14, #2
    ldr     w15, [x19, #PAINT]
    cbz     w15, 1f
    NUM     x12, 2
    lsl     x12, x12, #4
    NUM     x13, 3
    lsl     x13, x13, #4
    mov     x14, #4
1:  str     x12, [x19, #PEN16]
    str     x12, [x19, #BEGIN]
    str     x13, [x19, #BASE16]
    str     x14, [x19, #K]
    mov     x9, #-1
    str     x9, [x19, #BEFORE]
r_char:
    ldr     x9, [x19, #K]
    ldr     x10, [x19, #N]
    cmp     x9, x10
    b.ge    r_done
    ldr     x10, [x19, #P]
    ldrsh   w0, [x10, x9, lsl #1]
    add     x9, x9, #1
    str     x9, [x19, #K]
    tbnz    w0, #31, r_char
    GLYPH   r_bad
    ldr     w9, [x19, #PAINT]
    cbz     w9, 2f
    str     wzr, [x19, #SH_USED]
    ldr     w0, [x19, #G]
    ldr     x1, [x19, #PEN16]
    ldr     x2, [x19, #BASE16]
    bl      outline
    cbnz    w22, r_bad
    FILL
2:  ADVANCE r_bad
    b       r_char
r_done:
    ldr     x0, [x19, #PEN16]
    ldr     w9, [x19, #PAINT]
    cbnz    w9, r_out
    ldr     x9, [x19, #BEGIN]
    sub     x0, x0, x9
    b       r_out
r_bad:
    mov     x0, #-1
r_out:
    LEAVE
    .ltorg

// ---- the letter cache ----
// Cache block (kind 3): after its 64-byte head, how many slots (1024) and how many bytes of ink are used; then 1024 slots of 16
// bytes: key, left, top, width, height, where its ink is; then the ink. Scratch: a mask, one byte a dot, the cover piece writes
// one letter's ink into. Numbers: the handles of the font, the cache and the mask, the size, left, the line, then the characters.
    .equ C_SLOTS, 64
    .equ C_USED, 68
    .equ C_TABLE, 72
    .equ C_INK, 16456
draw_cached:
    ENTER
    NUM     x9, 0
    BLOCKOF
    bl      open_font
    cbz     x0, d_bad
    NUM     x9, 1
    BLOCKOF
    mov     x23, x0                     // the cache
    NUM     x9, 2
    BLOCKOF
    mov     x24, x0                     // the mask
    cbz     x23, d_bad
    ldr     w9, [x23]
    cmp     w9, #3
    b.ne    d_bad
    ldr     x9, [x23, #16]
    mov     x10, #(C_INK + 4096)
    cmp     x9, x10
    b.lo    d_bad
    cbz     x24, d_bad
    ldr     w9, [x24]
    cmp     w9, #4
    b.ne    d_bad
    ldr     w10, [x24, #4]
    ldr     w11, [x24, #8]
    cmp     w10, #16
    b.lo    d_bad
    cmp     w11, #16
    b.lo    d_bad
    ldr     w12, [x24, #12]
    cmp     w12, w10
    b.ne    d_bad
    umull   x12, w10, w11
    add     x12, x12, #64
    ldr     x13, [x24, #16]
    cmp     x13, x12
    b.ne    d_bad
    NUM     x11, 3
    cmp     x11, #4
    b.lt    d_bad
    cmp     x11, #1000
    b.gt    d_bad
    str     x11, [x19, #SIZE]
    lsl     x11, x11, #4
    str     x11, [x19, #SIZE16]
    ldr     w9, [x23, #C_SLOTS]
    cmp     w9, #1024
    b.eq    2f
    mov     w9, #1024                   // a fresh cache
    str     w9, [x23, #C_SLOTS]
    str     wzr, [x23, #C_USED]
    add     x9, x23, #C_TABLE
    mov     x10, #1024
1:  str     wzr, [x9], #16
    subs    x10, x10, #1
    b.ne    1b
2:  ldr     x9, [x23, #16]
    mov     x10, #C_INK
    sub     x9, x9, x10
    str     x9, [x19, #ROOM]
    NUM     x11, 4
    lsl     x11, x11, #4
    str     x11, [x19, #PEN16]
    NUM     x11, 5
    str     x11, [x19, #BASE]
    ldr     x9, [x19, #COLOUR]
    lsr     w9, w9, #24
    str     w9, [x19, #ALPHA]
    mov     x9, #6
    str     x9, [x19, #K]
    mov     x9, #-1
    str     x9, [x19, #BEFORE]
d_char:
    ldr     x9, [x19, #K]
    ldr     x10, [x19, #N]
    cmp     x9, x10
    b.ge    d_done
    ldr     x10, [x19, #P]
    ldrsh   w0, [x10, x9, lsl #1]
    add     x9, x9, #1
    str     x9, [x19, #K]
    tbnz    w0, #31, d_char
    GLYPH   d_bad
    ldr     w9, [x19, #G]               // the letter's key: which glyph at which size; and where to look for it first
    ldr     w10, [x19, #SIZE]
    orr     w9, w10, w9, lsl #12
    add     w9, w9, #1
    str     w9, [x19, #KEY]
    ldr     w10, =2654435761
    mul     w10, w9, w10
    lsr     w10, w10, #22
    mov     x25, #0                     // the slot that has it
    mov     x26, #0                     // or the first free one
    mov     w11, #0
1:  cmp     w11, #8
    b.hs    2f
    add     w12, w10, w11
    and     w12, w12, #1023
    add     x12, x23, x12, lsl #4
    add     x12, x12, #C_TABLE
    add     w11, w11, #1
    ldr     w13, [x12]
    cmp     w13, w9
    b.ne    3f
    mov     x25, x12
    b       2f
3:  cbnz    w13, 1b
    cmp     x26, #0
    csel    x26, x12, x26, eq
    b       1b
2:  cbnz    x25, d_have
    cbz     x26, d_have
    str     wzr, [x19, #SH_USED]        // fill this letter once and keep its ink
    ldr     w0, [x19, #G]
    mov     x1, #0
    mov     x2, #0
    bl      outline
    cbnz    w22, d_bad
    ldr     w9, [x19, #SH_USED]
    cbnz    w9, 4f
    ldr     w10, [x19, #KEY]            // a letter with no ink, like a space
    str     w10, [x26]
    str     wzr, [x26, #4]
    str     xzr, [x26, #8]
    mov     x25, x26
    b       d_have
4:  ADDR    x10, SHAPE                  // the box its outlines fill
    mov     w11, #32767
    mov     w12, #32767
    mov     w13, #-32768
    mov     w14, #-32768
    mov     w15, #0
5:  cmp     w15, w9
    b.ge    7f
    ldrsh   w16, [x10, w15, sxtw #1]
    add     w15, w15, #1
6:  cbz     w16, 5b
    ldrsh   w17, [x10, w15, sxtw #1]
    add     w15, w15, #1
    cmp     w17, w11
    csel    w11, w17, w11, lt
    cmp     w17, w13
    csel    w13, w17, w13, gt
    ldrsh   w17, [x10, w15, sxtw #1]
    add     w15, w15, #1
    cmp     w17, w12
    csel    w12, w17, w12, lt
    cmp     w17, w14
    csel    w14, w17, w14, gt
    sub     w16, w16, #1
    b       6b
7:  asr     w11, w11, #4                // left, top, width, height in whole dots
    asr     w12, w12, #4
    asr     w13, w13, #4
    asr     w14, w14, #4
    sub     w13, w13, w11
    add     w13, w13, #1
    sub     w14, w14, w12
    add     w14, w14, #1
    ldr     w16, [x24, #4]
    cmp     w13, w16
    b.gt    d_have
    ldr     w16, [x24, #8]
    cmp     w14, w16
    b.gt    d_have
    ldr     w16, [x23, #C_USED]
    smull   x17, w13, w14
    add     x17, x17, x16
    ldr     x16, [x19, #ROOM]
    cmp     x17, x16
    b.hi    d_have
    str     w11, [x19, #T_LEFT]
    str     w12, [x19, #T_TOP]
    str     w13, [x19, #T_W]
    str     w14, [x19, #T_H]
    lsl     w11, w11, #4                // the outlines move to the mask's corner
    lsl     w12, w12, #4
    mov     w15, #0
8:  cmp     w15, w9
    b.ge    10f
    ldrsh   w16, [x10, w15, sxtw #1]
    add     w15, w15, #1
9:  cbz     w16, 8b
    ldrsh   w17, [x10, w15, sxtw #1]
    sub     w17, w17, w11
    strh    w17, [x10, w15, sxtw #1]
    add     w15, w15, #1
    ldrsh   w17, [x10, w15, sxtw #1]
    sub     w17, w17, w12
    strh    w17, [x10, w15, sxtw #1]
    add     w15, w15, #1
    sub     w16, w16, #1
    b       9b
10: ldr     w15, [x24, #12]             // the mask's part is cleared, the cover piece writes the ink, and it is kept
    add     x16, x24, #64
    mov     w11, #0
11: cmp     w11, w14
    b.ge    13f
    mov     w12, #0
12: strb    wzr, [x16, x12]
    add     w12, w12, #1
    cmp     w12, w13
    b.lt    12b
    add     x16, x16, x15
    add     w11, w11, #1
    b       11b
13: mov     x0, x24
    mov     x1, x10
    mov     w2, w9
    mov     x3, #0
    ldr     x4, [x19, #TABLE]
    ldr     x9, [x4, #(10 * 8)]
    blr     x9
    ldr     w13, [x19, #T_W]
    ldr     w14, [x19, #T_H]
    ldr     w15, [x24, #12]
    add     x16, x24, #64
    ldr     w9, [x23, #C_USED]
    mov     x10, #C_INK
    add     x10, x23, x10
    add     x10, x10, x9
    mov     w11, #0
14: cmp     w11, w14
    b.ge    16f
    mov     w12, #0
15: ldrb    w17, [x16, x12]
    strb    w17, [x10, x12]
    add     w12, w12, #1
    cmp     w12, w13
    b.lt    15b
    add     x16, x16, x15
    add     x10, x10, x13
    add     w11, w11, #1
    b       14b
16: ldr     w10, [x19, #KEY]
    str     w10, [x26]
    ldr     w10, [x19, #T_LEFT]
    strh    w10, [x26, #4]
    ldr     w10, [x19, #T_TOP]
    strh    w10, [x26, #6]
    strh    w13, [x26, #8]
    strh    w14, [x26, #10]
    str     w9, [x26, #12]
    madd    w9, w13, w14, w9
    str     w9, [x23, #C_USED]
    mov     x25, x26
d_have:
    ldr     x27, [x19, #PEN16]          // letters sit on whole dots when they come from the cache
    add     x27, x27, #8
    asr     x27, x27, #4
    cbz     x25, d_slow
    ldr     w9, [x25, #12]
    mov     x10, #C_INK
    add     x10, x23, x10
    add     x10, x10, x9                // its ink
    ldrh    w11, [x25, #8]              // width, height
    ldrh    w12, [x25, #10]
    ldrsh   x13, [x25, #4]
    add     x13, x13, x27               // left on the surface
    ldrsh   x14, [x25, #6]
    ldr     x9, [x19, #BASE]
    add     x14, x14, x9                // top on the surface
    ldr     x0, [x19, #S]
    ldr     w1, [x19, #ALPHA]
    ldr     x2, [x19, #COLOUR]
    mov     w3, #255
    mov     w4, #0
1:  cmp     w4, w12
    b.ge    d_next
    add     x5, x14, x4
    add     w4, w4, #1
    ldr     w6, [x0, #8]
    cmp     x5, #0
    b.lt    4f
    cmp     x5, x6
    b.ge    4f
    ldr     w6, [x0, #12]
    mul     x5, x5, x6
    add     x5, x5, x0
    add     x5, x5, #64                 // this row of dots
    mov     w6, #0
2:  cmp     w6, w11
    b.ge    4f
    add     x7, x13, x6
    ldrb    w8, [x10, x6]
    add     w6, w6, #1
    ldr     w9, [x0, #4]
    cmp     x7, #0
    b.lt    2b
    cmp     x7, x9
    b.ge    2b
    cbz     w8, 2b
    mul     w8, w8, w1
    add     w8, w8, #127
    udiv    w8, w8, w3                  // how much of the colour
    sub     w9, w3, w8                  // how much of what is there
    add     x7, x5, x7, lsl #2
    .macro  BLEND off, shift
    ldrb    w15, [x7, #\off]
    mul     w15, w15, w9
    .if \shift < 24
    ubfx    w16, w2, #\shift, #8
    .else
    mov     w16, #255
    .endif
    madd    w15, w16, w8, w15
    add     w15, w15, #127
    udiv    w15, w15, w3
    strb    w15, [x7, #\off]
    .endm
    BLEND   0, 0
    BLEND   1, 8
    BLEND   2, 16
    BLEND   3, 24
    b       2b
4:  add     x10, x10, x11
    b       1b
d_slow:                                 // no room in the cache: the slow way, on the same whole dot
    str     wzr, [x19, #SH_USED]
    ldr     w0, [x19, #G]
    lsl     x1, x27, #4
    ldr     x2, [x19, #BASE]
    lsl     x2, x2, #4
    bl      outline
    cbnz    w22, d_bad
    FILL
d_next:
    ADVANCE d_bad
    b       d_char
d_done:
    ldr     x0, [x19, #PEN16]
    b       d_out
d_bad:
    mov     x0, #-1
d_out:
    LEAVE
    .ltorg
