// png, written by hand (ARM64): reads PNG pictures. The meaning is png/intent.md; the recorded checks are the judge.
// Entries: x0 surface (four bytes a dot), x1 numbers (16-bit): the file's handle and a scratch block's; x2 how many; x4 call table.
// Calls nothing. Laid out by tools/png_asm.py (the frame's offsets only); the source is png/impl.body.S.
// The compressed data, through an entry: x19 the frame, x20 the file's bytes, x21 how many, x22 where the next compressed byte is,
// x23 how many are left in this IDAT chunk, x24 bits already taken from the file and not yet used (lowest first), x25 how many,
// x26 set once the data has run out or cannot be followed, x27 where the unpacked bytes go, x28 how many have been made.
    .arch armv8-a+crc
    .text
    .global check
    .global size
    .global decode
@EQU@
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
// BE32: the four bytes at \at of the file, most significant first -> \reg (the caller has made sure they are there)
    .macro  BE32 reg, at
    ldr     \reg, [x20, \at]
    rev     \reg, \reg
    .endm
// open_png: the file in the block x0 (or 0) -> x0 1 or 0. Every chunk's checksum is verified. Uses x9-x17.
open_png:
    cbz     x0, o_no
    ldr     w9, [x0]
    cmp     w9, #2
    b.ne    o_no
    ldr     x21, [x0, #16]
    cmp     x21, #(64 + 33)
    b.lo    o_no
    sub     x21, x21, #64
    add     x20, x0, #64
    ldr     x9, [x20]
    ldr     x10, =0x0a1a0a0d474e5089
    cmp     x9, x10
    b.ne    o_no
    str     xzr, [x19, #PLTE]
    str     xzr, [x19, #PLTE_N]
    str     xzr, [x19, #TRNS]
    str     xzr, [x19, #TRNS_N]
    str     xzr, [x19, #FIRST]
    str     wzr, [x19, #WIDTH]
    mov     x9, #8
o_chunk:
    add     x10, x9, #12
    cmp     x10, x21
    b.hi    o_done
    BE32    w11, x9                     // its length
    add     x12, x9, #4
    BE32    w13, x12                    // its kind
    add     x14, x9, #8                 // its contents
    add     x15, x14, x11
    add     x16, x15, #4
    cmp     x16, x21
    b.hi    o_no
    add     x12, x20, x12               // the checksum over kind and contents
    add     x16, x11, #4
    mov     w17, #-1
1:  cmp     x16, #8
    b.lo    2f
    ldr     x10, [x12], #8
    crc32x  w17, w17, x10
    sub     x16, x16, #8
    b       1b
2:  cbz     x16, 3f
    ldrb    w10, [x12], #1
    crc32b  w17, w17, w10
    sub     x16, x16, #1
    b       2b
3:  mvn     w17, w17
    BE32    w10, x15
    cmp     w10, w17
    b.ne    o_no
    ldr     w10, =0x49484452            // IHDR
    cmp     w13, w10
    b.ne    4f
    cmp     w11, #13
    b.lo    o_no
    BE32    w10, x14
    str     w10, [x19, #WIDTH]
    add     x12, x14, #4
    BE32    w10, x12
    str     w10, [x19, #HEIGHT]
    add     x12, x20, x14
    ldrb    w10, [x12, #10]
    cbnz    w10, o_no
    ldrb    w10, [x12, #11]
    cbnz    w10, o_no
    ldrb    w10, [x12, #12]
    cmp     w10, #1
    b.hi    o_no
    str     w10, [x19, #INTERLACE]
    ldrb    w10, [x12, #9]
    str     w10, [x19, #TYPE]
    ldrb    w10, [x12, #8]
    str     w10, [x19, #DEPTH]
    b       o_next
4:  ldr     w10, =0x504c5445            // PLTE
    cmp     w13, w10
    b.ne    5f
    str     x14, [x19, #PLTE]
    mov     w10, #3
    udiv    w10, w11, w10
    str     x10, [x19, #PLTE_N]
    b       o_next
5:  ldr     w10, =0x74524e53            // tRNS
    cmp     w13, w10
    b.ne    6f
    str     x14, [x19, #TRNS]
    str     x11, [x19, #TRNS_N]
    b       o_next
6:  ldr     w10, =0x49444154            // IDAT
    cmp     w13, w10
    b.ne    7f
    ldr     x10, [x19, #FIRST]
    cbnz    x10, o_next
    str     x9, [x19, #FIRST]
    b       o_next
7:  ldr     w10, =0x49454e44            // IEND
    cmp     w13, w10
    b.eq    o_done
o_next:
    add     x9, x15, #4
    b       o_chunk
o_done:
    ldr     w9, [x19, #WIDTH]
    cbz     w9, o_no
    cmp     w9, #16384
    b.hi    o_no
    ldr     w9, [x19, #HEIGHT]
    cbz     w9, o_no
    cmp     w9, #16384
    b.hi    o_no
    ldr     x9, [x19, #FIRST]
    cbz     x9, o_no
    ldr     w10, [x19, #TYPE]
    ldr     w11, [x19, #DEPTH]
    mov     w12, #1                     // values to a dot
    cbz     w10, 1f
    cmp     w10, #3
    b.eq    1f
    mov     w12, #3
    cmp     w10, #2
    b.eq    1f
    mov     w12, #2
    cmp     w10, #4
    b.eq    1f
    mov     w12, #4
    cmp     w10, #6
    b.ne    o_no
1:  str     w12, [x19, #CHANNELS]
    cmp     w10, #3
    b.ne    2f
    ldr     x12, [x19, #PLTE_N]
    cbz     x12, o_no
2:  cmp     w11, #8
    b.eq    4f
    cmp     w11, #16
    b.ne    3f
    cmp     w10, #3
    b.eq    o_no
    b       4f
3:  cmp     w11, #1
    b.eq    5f
    cmp     w11, #2
    b.eq    5f
    cmp     w11, #4
    b.ne    o_no
5:  cbz     w10, 4f
    cmp     w10, #3
    b.ne    o_no
4:  add     x22, x9, #8
    BE32    w23, x9
    mov     x24, #0
    mov     x25, #0
    mov     x26, #0
    mov     x0, #1
    ret
o_no:
    mov     x0, #0
    ret
    .ltorg

// next_byte: the next byte of compressed data, stepping from one IDAT chunk to the next -> w0. Uses x9-x12.
next_byte:
1:  cbnz    x23, 3f
    add     x9, x22, #4
    add     x10, x9, #12
    cmp     x10, x21
    b.hi    2f
    add     x10, x9, #4
    BE32    w11, x10
    ldr     w12, =0x49444154
    cmp     w11, w12
    b.ne    2f
    BE32    w23, x9
    add     x22, x9, #8
    add     x10, x22, x23
    add     x10, x10, #4
    cmp     x10, x21
    b.ls    1b
    mov     x23, #0
2:  mov     x26, #1
    mov     w0, #0
    ret
3:  sub     x23, x23, #1
    ldrb    w0, [x20, x22]
    add     x22, x22, #1
    ret
// bits: the next w0 bits (0 to 16), lowest first -> w0. Uses x13, x17 as well.
bits:
    mov     x17, x30
    mov     w13, w0
1:  cmp     w25, w13
    b.ge    2f
    bl      next_byte
    lsl     x0, x0, x25
    orr     x24, x24, x0
    add     w25, w25, #8
    b       1b
2:  mov     x0, #1
    lsl     x0, x0, x13
    sub     x0, x0, #1
    and     x0, x24, x0
    lsr     x24, x24, x13
    sub     w25, w25, w13
    ret     x17
// build: Huffman codes from the w2 code lengths at x1: how many codes there are of each length and the symbols in order, at x0,
// and at x3 a table of 2^w4 entries answering every code of up to w4 bits at once (entry: symbol * 16 + length; 0 for longer
// codes, which are then followed bit by bit). Uses x5-x17.
build:
    mov     x5, #0
1:  strh    wzr, [x0, x5, lsl #1]
    add     x5, x5, #1
    cmp     x5, #16
    b.lo    1b
    mov     x5, #0
2:  cmp     w5, w2
    b.hs    3f
    ldrb    w6, [x1, x5]
    ldrh    w7, [x0, x6, lsl #1]
    add     w7, w7, #1
    strh    w7, [x0, x6, lsl #1]
    add     x5, x5, #1
    b       2b
3:  strh    wzr, [x0]
    add     x8, x19, #OFFS
    strh    wzr, [x8, #2]
    mov     x5, #1
4:  ldrh    w6, [x8, x5, lsl #1]
    ldrh    w7, [x0, x5, lsl #1]
    add     w6, w6, w7
    add     x5, x5, #1
    strh    w6, [x8, x5, lsl #1]
    cmp     x5, #15
    b.lo    4b
    add     x9, x0, #32                 // the symbols, shortest codes first
    mov     x5, #0
5:  cmp     w5, w2
    b.hs    6f
    ldrb    w6, [x1, x5]
    cbz     w6, 7f
    ldrh    w7, [x8, x6, lsl #1]
    strh    w5, [x9, x7, lsl #1]
    add     w7, w7, #1
    strh    w7, [x8, x6, lsl #1]
7:  add     x5, x5, #1
    b       5b
6:  mov     x10, #1
    lsl     x10, x10, x4                // the table's size
    mov     x5, #0
8:  strh    wzr, [x3, x5, lsl #1]
    add     x5, x5, #1
    cmp     x5, x10
    b.lo    8b
    mov     w11, #0                     // the first code of this length
    mov     w12, #0                     // how many symbols have shorter codes
    mov     w5, #1                      // the length
9:  cmp     w5, w4
    b.hi    13f
    ldrh    w13, [x0, x5, lsl #1]
    mov     w14, #0
10: cmp     w14, w13
    b.hs    12f
    add     w15, w11, w14               // this symbol's code, if the length has room for it
    lsr     w16, w15, w5
    cbnz    w16, 11f
    rbit    w15, w15
    mov     w16, #32
    sub     w16, w16, w5
    lsr     w15, w15, w16               // as it arrives: first bit lowest
    ldrh    w16, [x3, x15, lsl #1]
    cbnz    w16, 11f                    // a shorter code already answers these bits
    add     w16, w12, w14
    ldrh    w16, [x9, x16, lsl #1]
    orr     w16, w5, w16, lsl #4
    mov     w17, #1
    lsl     w17, w17, w5
14: strh    w16, [x3, x15, lsl #1]
    add     w15, w15, w17
    cmp     x15, x10
    b.lo    14b
11: add     w14, w14, #1
    b       10b
12: add     w11, w11, w13
    lsl     w11, w11, #1
    add     w12, w12, w13
    add     w5, w5, #1
    b       9b
13: ret
// decode_symbol: the next symbol under the codes at x0, whose table of 2^w2 entries is at x1 -> w0, or -1.
// Uses x3-x8, x14-x16 and what next_byte uses.
decode_symbol:
    mov     x16, x30
    cbnz    x26, d_slow
1:  cmp     w25, #56                    // take what this chunk still holds, without stepping to the next
    b.hi    2f
    cbz     x23, 2f
    ldrb    w3, [x20, x22]
    add     x22, x22, #1
    sub     x23, x23, #1
    lsl     x3, x3, x25
    orr     x24, x24, x3
    add     w25, w25, #8
    b       1b
2:  mov     x3, #1
    lsl     x3, x3, x2
    sub     x3, x3, #1
    and     x3, x24, x3
    ldrh    w3, [x1, x3, lsl #1]
    cbz     w3, d_slow
    and     w4, w3, #15
    cmp     w4, w25
    b.hi    d_slow
    lsr     x24, x24, x4
    sub     w25, w25, w4
    lsr     w0, w3, #4
    ret     x16
d_slow:                                 // bit by bit, taking a byte from the file only when a bit is needed
    mov     x8, x0
    mov     w3, #0                      // the code so far
    mov     w4, #0                      // the first code of this length
    mov     w5, #0                      // how many symbols have shorter codes
    mov     w6, #1
3:  cbnz    w25, 4f
    bl      next_byte
    mov     x24, x0
    mov     w25, #8
4:  and     w7, w24, #1
    lsr     x24, x24, #1
    sub     w25, w25, #1
    orr     w3, w3, w7
    ldrh    w7, [x8, x6, lsl #1]
    sub     w14, w3, w7
    cmp     w14, w4
    b.ge    5f
    sub     w14, w3, w4
    add     w14, w14, w5
    add     x15, x8, #32
    ldrh    w0, [x15, w14, sxtw #1]
    ret     x16
5:  add     w5, w5, w7
    add     w4, w4, w7
    lsl     w4, w4, #1
    lsl     w3, w3, #1
    cbnz    x26, 6f
    add     w6, w6, #1
    cmp     w6, #15
    b.ls    3b
    mov     x26, #1
6:  mov     w0, #-1
    ret     x16

// inflate: unpacks the compressed data to x27, at most ROOM bytes -> x0 how many were made, or -1
    .macro  BITS n
    mov     w0, #\n
    bl      bits
    .endm
// NB: the next whole byte, from the bits in hand if a whole byte is there, else from the file -> w0
    .macro  NB
    cmp     w25, #8
    b.lo    80f
    and     w0, w24, #255
    lsr     x24, x24, #8
    sub     w25, w25, #8
    b       81f
80: bl      next_byte
81:
    .endm
    .macro  DECODE h, tab, tabbits
    add     x0, x19, #\h
    add     x1, x19, #\tab
    mov     w2, #\tabbits
    bl      decode_symbol
    .endm
    .macro  BUILD h, lengths, n, tab, tabbits
    add     x0, x19, #\h
    add     x1, x19, #\lengths
    mov     w2, \n
    add     x3, x19, #\tab
    mov     w4, #\tabbits
    bl      build
    .endm
inflate:
    stp     x29, x30, [sp, #-16]!
    mov     x28, #0
    BITS    16                          // the two zlib header bytes
i_block:
    BITS    1
    str     w0, [x19, #LAST]
    BITS    2
    cbnz    x26, i_no
    cbnz    w0, i_coded
    and     w9, w25, #7                 // stored plainly: from the next whole byte, a length, its complement, the bytes
    lsr     x24, x24, x9
    sub     w25, w25, w9
    NB
    mov     w29, w0
    NB
    orr     w29, w29, w0, lsl #8
    NB
    NB
1:  cbz     w29, 2f
    ldr     x9, [x19, #ROOM]
    cmp     x28, x9
    b.hs    i_no
    NB
    strb    w0, [x27, x28]
    add     x28, x28, #1
    sub     w29, w29, #1
    b       1b
2:  cbnz    x26, i_no
    b       i_more
i_coded:
    cmp     w0, #3
    b.eq    i_no
    cmp     w0, #1
    b.ne    i_dynamic
    add     x9, x19, #LENGTHS           // the fixed codes
    mov     x10, #0
1:  mov     w11, #8
    cmp     x10, #144
    b.lo    2f
    mov     w11, #9
    cmp     x10, #256
    b.lo    2f
    mov     w11, #7
    cmp     x10, #280
    b.lo    2f
    mov     w11, #8
2:  strb    w11, [x9, x10]
    add     x10, x10, #1
    cmp     x10, #288
    b.lo    1b
    BUILD   LIT, LENGTHS, #288, LTAB, 9
    add     x9, x19, #LENGTHS
    mov     x10, #0
    mov     w11, #5
3:  strb    w11, [x9, x10]
    add     x10, x10, #1
    cmp     x10, #30
    b.lo    3b
    BUILD   DIST, LENGTHS, #30, DTAB, 9
    b       i_symbols
i_dynamic:                              // codes of this block's own, their lengths themselves coded
    BITS    5
    add     w0, w0, #257
    str     w0, [x19, #NLEN]
    BITS    5
    add     w0, w0, #1
    str     w0, [x19, #NDIST]
    BITS    4
    add     w29, w0, #4
    ldr     w9, [x19, #NLEN]
    ldr     w10, [x19, #NDIST]
    cmp     w9, #286
    b.hi    i_no
    cmp     w10, #30
    b.hi    i_no
    add     w9, w9, w10
    str     w9, [x19, #TOTAL]
    add     x9, x19, #CL
    stp     xzr, xzr, [x9]
    str     xzr, [x9, #16]
    str     xzr, [x19, #TMPA]
1:  ldr     x9, [x19, #TMPA]
    cmp     w9, w29
    b.hs    2f
    BITS    3
    ldr     x9, [x19, #TMPA]
    adr     x10, i_order
    ldrb    w10, [x10, x9]
    add     x11, x19, #CL
    strb    w0, [x11, x10]
    add     x9, x9, #1
    str     x9, [x19, #TMPA]
    b       1b
2:  BUILD   CODES, CL, #19, CTAB, 7
    mov     w29, #0                     // how many lengths are known
3:  ldr     w9, [x19, #TOTAL]
    cmp     w29, w9
    b.ge    7f
    DECODE  CODES, CTAB, 7
    tbnz    w0, #31, i_no
    cmp     w0, #16
    b.hs    4f
    add     x9, x19, #LENGTHS
    strb    w0, [x9, w29, sxtw]
    add     w29, w29, #1
    b       3b
4:  str     xzr, [x19, #TMPB]           // a run: of the length before, or of zeros
    b.ne    5f
    cbz     w29, i_no
    add     x9, x19, #LENGTHS
    sub     w10, w29, #1
    ldrb    w10, [x9, w10, sxtw]
    str     x10, [x19, #TMPB]
    BITS    2
    add     w0, w0, #3
    b       6f
5:  cmp     w0, #17
    b.ne    8f
    BITS    3
    add     w0, w0, #3
    b       6f
8:  BITS    7
    add     w0, w0, #11
6:  ldr     w9, [x19, #TOTAL]
    add     w10, w29, w0
    cmp     w10, w9
    b.gt    i_no
    ldr     x11, [x19, #TMPB]
    add     x9, x19, #LENGTHS
9:  cbz     w0, 3b
    strb    w11, [x9, w29, sxtw]
    add     w29, w29, #1
    sub     w0, w0, #1
    b       9b
7:  ldr     w9, [x19, #NLEN]
    BUILD   LIT, LENGTHS, w9, LTAB, 9
    ldr     w9, [x19, #NLEN]
    add     x0, x19, #DIST
    add     x1, x19, #LENGTHS
    add     x1, x1, x9
    ldr     w2, [x19, #NDIST]
    add     x3, x19, #DTAB
    mov     w4, #9
    bl      build
i_symbols:
    DECODE  LIT, LTAB, 9
    tbnz    w0, #31, i_no
    cbnz    x26, i_no
    cmp     w0, #256
    b.hs    1f
    ldr     x9, [x19, #ROOM]
    cmp     x28, x9
    b.hs    i_no
    strb    w0, [x27, x28]
    add     x28, x28, #1
    b       i_symbols
1:  b.eq    i_more
    sub     w29, w0, #257               // a copy of bytes made earlier: how long, how far back
    cmp     w29, #29
    b.hs    i_no
    adr     x9, i_lext
    ldrb    w0, [x9, x29]
    bl      bits
    adr     x9, i_lbase
    ldrh    w9, [x9, x29, lsl #1]
    add     w29, w9, w0
    DECODE  DIST, DTAB, 9
    tbnz    w0, #31, i_no
    cmp     w0, #30
    b.hs    i_no
    str     x0, [x19, #TMPA]
    adr     x9, i_dext
    ldrb    w0, [x9, x0]
    bl      bits
    ldr     x10, [x19, #TMPA]
    adr     x9, i_dbase
    ldrh    w9, [x9, x10, lsl #1]
    add     x9, x9, x0
    cmp     x9, x28
    b.hi    i_no
    add     x10, x28, x29
    ldr     x11, [x19, #ROOM]
    cmp     x10, x11
    b.hi    i_no
    add     x11, x27, x28
    sub     x12, x11, x9
    mov     x28, x10
2:  ldrb    w13, [x12], #1
    strb    w13, [x11], #1
    subs    w29, w29, #1
    b.ne    2b
    b       i_symbols
i_more:
    ldr     w9, [x19, #LAST]
    cbz     w9, i_block
    cbnz    x26, i_no
    mov     x0, x28
    b       i_out
i_no:
    mov     x0, #-1
i_out:
    ldp     x29, x30, [sp], #16
    ret
i_lbase: .hword 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
i_dbase: .hword 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
i_lext:  .byte 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
i_dext:  .byte 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
i_order: .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
    .balign 4

    .macro  ENTER
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, sp
    str     x0, [x19, #SURF]
    .endm
    .macro  LEAVE
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #FRAME
    ret
    .endm
// BLOCK: the block at the handle in number \i (numbers x1, count x2, table x4) -> x0, or 0
    .macro  BLOCK i
    mov     x0, #0
    cmp     x2, #\i
    b.le    60f
    ldrsh   x9, [x1, #(\i * 2)]
    cmp     x9, #0
    b.lt    60f
    cmp     x9, #255
    b.gt    60f
    add     x9, x9, #256
    ldr     x0, [x4, x9, lsl #3]
60:
    .endm
size:
    ENTER
    BLOCK   0
    bl      open_png
    cbz     x0, 1f
    ldr     w9, [x19, #WIDTH]
    ldr     w10, [x19, #HEIGHT]
    add     x0, x10, x9, lsl #16
    b       2f
1:  mov     x0, #-1
2:  LEAVE

// emit: dot x1 of the row at x0, whatever the file's depth and kind, as red, green, blue, alpha at x2 -> w0 1, or 0. Uses x3-x17.
emit:
    ldr     w7, [x19, #DEPTH]
    ldr     w8, [x19, #CHANNELS]
    ldr     w9, [x19, #TYPE]
    mov     w3, #0
    mov     w4, #0
    mov     w5, #0
    mov     w6, #0
    cmp     w7, #8
    b.ne    2f
    mul     x10, x1, x8
    add     x10, x0, x10
    ldrb    w3, [x10]
    cmp     w8, #2
    b.lo    4f
    ldrb    w4, [x10, #1]
    b.eq    4f
    ldrb    w5, [x10, #2]
    cmp     w8, #4
    b.lo    4f
    ldrb    w6, [x10, #3]
    b       4f
2:  cmp     w7, #16
    b.ne    3f
    mul     x10, x1, x8
    add     x10, x0, x10, lsl #1
    ldrh    w3, [x10]
    rev16   w3, w3
    cmp     w8, #2
    b.lo    4f
    ldrh    w4, [x10, #2]
    rev16   w4, w4
    b.eq    4f
    ldrh    w5, [x10, #4]
    rev16   w5, w5
    cmp     w8, #4
    b.lo    4f
    ldrh    w6, [x10, #6]
    rev16   w6, w6
    b       4f
3:  mul     x10, x1, x7                 // fewer than eight bits a dot, packed from the high end of each byte
    lsr     x11, x10, #3
    ldrb    w3, [x0, x11]
    and     w10, w10, #7
    mov     w11, #8
    sub     w11, w11, w7
    sub     w11, w11, w10
    lsr     w3, w3, w11
    mov     w11, #1
    lsl     w11, w11, w7
    sub     w11, w11, #1
    and     w3, w3, w11
4:  cmp     w9, #3
    b.ne    5f
    ldr     x10, [x19, #PLTE_N]         // a colour from the file's own list
    cmp     x3, x10
    b.hs    e_no
    add     x11, x3, x3, lsl #1
    ldr     x10, [x19, #PLTE]
    add     x11, x11, x10
    add     x10, x11, #3
    cmp     x10, x21
    b.hi    e_no
    add     x11, x20, x11
    ldrb    w10, [x11]
    strb    w10, [x2]
    ldrb    w10, [x11, #1]
    strb    w10, [x2, #1]
    ldrb    w10, [x11, #2]
    strb    w10, [x2, #2]
    mov     w10, #255
    ldr     x11, [x19, #TRNS_N]
    cmp     x3, x11
    b.hs    1f
    ldr     x11, [x19, #TRNS]
    add     x11, x11, x3
    ldrb    w10, [x20, x11]
1:  strb    w10, [x2, #3]
    mov     w0, #1
    ret
5:  mov     w12, w3                     // the values scaled to eight bits (the unscaled ones are kept for the clear-colour test)
    mov     w13, w4
    mov     w14, w5
    mov     w15, w6
    cmp     w7, #8
    b.eq    7f
    cmp     w7, #16
    b.ne    6f
    lsr     w12, w3, #8
    lsr     w13, w4, #8
    lsr     w14, w5, #8
    lsr     w15, w6, #8
    b       7f
6:  mov     w10, #1
    lsl     w10, w10, w7
    sub     w10, w10, #1
    mov     w11, #255
    mul     w12, w3, w11
    udiv    w12, w12, w10
    mov     w13, #0
    mov     w14, #0
    mov     w15, #0
7:  ldr     x16, [x19, #TRNS_N]
    ldr     x17, [x19, #TRNS]
    add     x17, x20, x17
    cmp     w9, #6
    b.ne    8f
    strb    w12, [x2]
    strb    w13, [x2, #1]
    strb    w14, [x2, #2]
    strb    w15, [x2, #3]
    mov     w0, #1
    ret
8:  cmp     w9, #2
    b.ne    10f
    strb    w12, [x2]
    strb    w13, [x2, #1]
    strb    w14, [x2, #2]
    mov     w10, #255
    cmp     x16, #6
    b.lo    9f
    ldrh    w11, [x17]
    rev16   w11, w11
    cmp     w11, w3
    b.ne    9f
    ldrh    w11, [x17, #2]
    rev16   w11, w11
    cmp     w11, w4
    b.ne    9f
    ldrh    w11, [x17, #4]
    rev16   w11, w11
    cmp     w11, w5
    b.ne    9f
    mov     w10, #0
9:  strb    w10, [x2, #3]
    mov     w0, #1
    ret
10: strb    w12, [x2]
    strb    w12, [x2, #1]
    strb    w12, [x2, #2]
    cbnz    w9, 12f
    mov     w10, #255                   // grey, perhaps with one grey that is clear
    cmp     x16, #2
    b.lo    11f
    ldrh    w11, [x17]
    rev16   w11, w11
    cmp     w11, w3
    b.ne    11f
    mov     w10, #0
11: strb    w10, [x2, #3]
    mov     w0, #1
    ret
12: strb    w13, [x2, #3]               // grey with its own alpha
    mov     w0, #1
    ret
e_no:
    mov     w0, #0
    ret

// pass: where pass PASS of the picture sits -> X0, Y0, DX, DY, PW, PH, ROWLEN in the frame; x0 1, or 0 if the pass is empty
pass:
    ldr     x9, [x19, #PASS]
    mov     x10, #0
    mov     x11, #0
    mov     x12, #1
    mov     x13, #1
    ldr     w14, [x19, #INTERLACE]
    cbz     w14, 1f
    adr     x14, p_x0
    ldrb    w10, [x14, x9]
    adr     x14, p_y0
    ldrb    w11, [x14, x9]
    adr     x14, p_dx
    ldrb    w12, [x14, x9]
    adr     x14, p_dy
    ldrb    w13, [x14, x9]
1:  str     x10, [x19, #X0]
    str     x11, [x19, #Y0]
    str     x12, [x19, #DX]
    str     x13, [x19, #DY]
    ldr     w14, [x19, #WIDTH]
    ldr     w15, [x19, #HEIGHT]
    cmp     x14, x10
    b.ls    2f
    cmp     x15, x11
    b.ls    2f
    add     x14, x14, x12
    sub     x14, x14, #1
    sub     x14, x14, x10
    udiv    x14, x14, x12
    str     x14, [x19, #PW]
    add     x15, x15, x13
    sub     x15, x15, #1
    sub     x15, x15, x11
    udiv    x15, x15, x13
    str     x15, [x19, #PH]
    ldr     x9, [x19, #BITSPER]
    mul     x14, x14, x9
    add     x14, x14, #7
    lsr     x14, x14, #3
    add     x14, x14, #1
    str     x14, [x19, #ROWLEN]
    mov     x0, #1
    ret
2:  mov     x0, #0
    ret
p_x0:   .byte 0, 4, 0, 2, 0, 1, 0
p_y0:   .byte 0, 0, 4, 0, 2, 0, 1
p_dx:   .byte 8, 8, 4, 4, 2, 2, 1
p_dy:   .byte 8, 8, 8, 4, 4, 2, 2
    .balign 4

decode:
    ENTER
    mov     x29, x1
    mov     x28, x2
    mov     x27, x4
    BLOCK   0
    bl      open_png
    cbz     x0, c_bad
    mov     x1, x29
    mov     x2, x28
    mov     x4, x27
    BLOCK   1
    cbz     x0, c_bad
    ldr     w9, [x0]
    cmp     w9, #5
    b.ne    c_bad
    ldr     x9, [x0, #16]
    cmp     x9, #64
    b.lo    c_bad
    sub     x9, x9, #64
    str     x9, [x19, #TMPC]            // the scratch block's room
    add     x27, x0, #64
    str     x27, [x19, #RAW]
    ldr     w9, [x19, #CHANNELS]
    ldr     w10, [x19, #DEPTH]
    mul     x9, x9, x10
    str     x9, [x19, #BITSPER]
    lsr     x10, x9, #3
    mov     x11, #1
    cmp     x9, #8
    csel    x10, x10, x11, hs
    str     x10, [x19, #BPP]
    str     xzr, [x19, #NEEDT]          // how many bytes the unpacked rows of every pass come to
    str     xzr, [x19, #PASS]
1:  bl      pass
    cbz     x0, 2f
    ldr     x9, [x19, #PH]
    ldr     x10, [x19, #ROWLEN]
    ldr     x11, [x19, #NEEDT]
    madd    x11, x9, x10, x11
    str     x11, [x19, #NEEDT]
2:  ldr     x9, [x19, #PASS]
    add     x9, x9, #1
    str     x9, [x19, #PASS]
    ldr     w10, [x19, #INTERLACE]
    cbz     w10, 3f
    cmp     x9, #7
    b.lo    1b
3:  ldr     x9, [x19, #NEEDT]
    ldr     x10, [x19, #TMPC]
    cmp     x10, x9
    b.lo    c_bad
    str     x9, [x19, #ROOM]
    bl      inflate
    ldr     x9, [x19, #NEEDT]
    cmp     x0, x9
    b.ne    c_bad
    str     xzr, [x19, #WRITTEN]
    str     xzr, [x19, #PASS]
c_pass:
    bl      pass
    cbz     x0, c_pass_next
    str     xzr, [x19, #R]
c_row:
    ldr     x9, [x19, #R]
    ldr     x10, [x19, #PH]
    cmp     x9, x10
    b.hs    c_pass_end
    ldr     x3, [x19, #ROWLEN]
    ldr     x0, [x19, #RAW]
    madd    x0, x9, x3, x0
    add     x0, x0, #1                  // this row's bytes; x1 the row above's, or 0
    mov     x1, #0
    cbz     x9, 1f
    sub     x1, x0, x3
1:  ldurb   w5, [x0, #-1]               // how the row was stored: as differences from its neighbours
    cmp     w5, #4
    b.hi    c_bad
    sub     x3, x3, #1
    ldr     x4, [x19, #BPP]
    cbz     w5, c_filtered
    mov     x2, #0
2:  cmp     x2, x3
    b.hs    c_filtered
    mov     w6, #0                      // left
    mov     w7, #0                      // above
    mov     w8, #0                      // above and to the left
    cmp     x2, x4
    b.lo    3f
    sub     x9, x2, x4
    ldrb    w6, [x0, x9]
    cbz     x1, 3f
    ldrb    w8, [x1, x9]
3:  cbz     x1, 4f
    ldrb    w7, [x1, x2]
4:  cmp     w5, #2
    b.lo    7f                          // 1: the left one (w6)
    b.ne    5f
    mov     w6, w7                      // 2: the one above
    b       7f
5:  cmp     w5, #3
    b.ne    6f
    add     w6, w6, w7                  // 3: their average
    lsr     w6, w6, #1
    b       7f
6:  sub     w9, w7, w8                  // 4: whichever of the three is nearest to left + above - corner
    sub     w10, w6, w8
    add     w11, w9, w10
    cmp     w9, #0
    cneg    w9, w9, lt
    cmp     w10, #0
    cneg    w10, w10, lt
    cmp     w11, #0
    cneg    w11, w11, lt
    cmp     w9, w10
    ccmp    w9, w11, #0, le
    b.le    7f
    cmp     w10, w11
    csel    w6, w7, w8, le
7:  ldrb    w9, [x0, x2]
    add     w9, w9, w6
    strb    w9, [x0, x2]
    add     x2, x2, #1
    b       2b
c_filtered:
    ldr     x9, [x19, #R]
    ldr     x10, [x19, #DY]
    ldr     x11, [x19, #Y0]
    madd    x9, x9, x10, x11            // the row of the picture this is
    ldr     x12, [x19, #SURF]
    ldr     w10, [x12, #8]
    cmp     x9, x10
    b.hs    c_row_next
    ldr     w10, [x12, #12]
    mul     x9, x9, x10
    add     x9, x9, x12
    add     x25, x9, #64                // its start on the surface
    mov     x24, x0                     // the row's bytes
    mov     x23, #0                     // the dot within the pass
    ldr     w9, [x19, #DEPTH]           // the two commonest kinds of picture go straight across, without the general routine
    cmp     w9, #8
    b.ne    c_dot
    ldr     w9, [x19, #TYPE]
    cmp     w9, #6
    b.eq    c_rgba
    cmp     w9, #2
    b.ne    c_dot
    ldr     x9, [x19, #TRNS_N]
    cmp     x9, #6
    b.hs    c_dot
c_rgb:
    mov     x15, #3
    b       1f
c_rgba:
    mov     x15, #4
1:  ldr     x9, [x19, #PW]
    ldr     x10, [x19, #DX]
    ldr     x11, [x19, #X0]
    ldr     x12, [x19, #SURF]
    ldr     w12, [x12, #4]
    ldr     x13, [x19, #WRITTEN]
2:  cmp     x23, x9
    b.hs    3f
    madd    x16, x23, x10, x11
    cmp     x16, x12
    b.hs    3f
    cmp     x15, #4
    b.ne    5f
    ldr     w17, [x24]
    b       4f
5:  ldrh    w17, [x24]                  // three bytes exactly: nothing is read past the row
    ldrb    w14, [x24, #2]
    orr     w17, w17, w14, lsl #16
    orr     w17, w17, #0xff000000
4:  add     x24, x24, x15
    str     w17, [x25, x16, lsl #2]
    add     x13, x13, #1
    add     x23, x23, #1
    b       2b
3:  str     x13, [x19, #WRITTEN]
    b       c_row_next
c_dot:
    ldr     x9, [x19, #PW]
    cmp     x23, x9
    b.hs    c_row_next
    ldr     x9, [x19, #DX]
    ldr     x10, [x19, #X0]
    madd    x9, x23, x9, x10
    ldr     x12, [x19, #SURF]
    ldr     w10, [x12, #4]
    cmp     x9, x10
    b.hs    c_row_next
    mov     x0, x24
    mov     x1, x23
    add     x2, x25, x9, lsl #2
    bl      emit
    cbz     w0, c_bad
    ldr     x9, [x19, #WRITTEN]
    add     x9, x9, #1
    str     x9, [x19, #WRITTEN]
    add     x23, x23, #1
    b       c_dot
c_row_next:
    ldr     x9, [x19, #R]
    add     x9, x9, #1
    str     x9, [x19, #R]
    b       c_row
c_pass_end:
    ldr     x9, [x19, #PH]
    ldr     x10, [x19, #ROWLEN]
    ldr     x11, [x19, #RAW]
    madd    x11, x9, x10, x11
    str     x11, [x19, #RAW]
c_pass_next:
    ldr     x9, [x19, #PASS]
    add     x9, x9, #1
    str     x9, [x19, #PASS]
    ldr     w10, [x19, #INTERLACE]
    cbz     w10, c_done
    cmp     x9, #7
    b.lo    c_pass
c_done:
    ldr     x0, [x19, #WRITTEN]
    b       c_out
c_bad:
    mov     x0, #-1
c_out:
    LEAVE
    .ltorg
