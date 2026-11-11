// inflate, written by hand (ARM64). The meaning is inflate/intent.md; the recorded checks are the judge, and they also compare
// what is left in the output when unpacking fails part-way, so the order of reads and writes follows the description exactly.
// Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// The bit reader: x19 bytes, x20 how many, x21 next byte, w22 bits held, w23 how many held, w24 how many of those are padding
// (the input ran out), w25 set once padding has been used. Output: x26 bytes, x27 room, x28 written.
    .arch armv8-a+crc
    .text
    .global size
    .global unpack
    .equ OFFS, 96
    .equ CL, 128
    .equ LENGTHS, 152
    .equ LIT, 472
    .equ DIST, 2104
    .equ CODES, 3736
    .equ VARS, 5376                     // input block (8), gzip?, stated length, last block?, nlen, ndist, one kept value
    .equ V_INPUT, VARS
    .equ V_GZIP, VARS + 8
    .equ V_STATED, VARS + 12
    .equ V_LAST, VARS + 16
    .equ V_NLEN, VARS + 20
    .equ V_NDIST, VARS + 24
    .equ V_KEPT, VARS + 28
    .equ FRAME, 5440
    .equ H_SYMBOL, 32
    .equ H_FAST, 608

    .macro  FILL need                   // hold at least this many bits; past the end of the input, zeros count as padding
1:  cmp     w23, \need
    b.ge    3f
    cmp     x21, x20
    b.lo    2f
    add     w24, w24, #8
    add     w23, w23, #8
    b       1b
2:  ldrb    w5, [x19, x21]
    add     x21, x21, #1
    lsl     w5, w5, w23
    orr     w22, w22, w5
    add     w23, w23, #8
    b       1b
3:
    .endm
    .macro  TAKE count                  // use up bits; using padding marks the stream as bad
    lsr     w22, w22, \count
    sub     w23, w23, \count
    cmp     w23, w24
    csinc   w25, w25, wzr, ge
    .endm

// getbits: w0 how many (0-16) -> w0 their value. Uses w5, w6, w7.
getbits:
    cbz     w0, 9f
    mov     w6, w0
    FILL    w6
    mov     w7, #1
    lsl     w7, w7, w6
    sub     w7, w7, #1
    and     w0, w22, w7
    TAKE    w6
9:  ret

// build: x0 a code table, x1 the lengths, w2 how many. Uses x5-x15 and the 16 offsets in the frame.
build:
    mov     x5, #0
1:  strh    wzr, [x0, x5, lsl #1]
    add     x5, x5, #1
    cmp     x5, #16
    b.lo    1b
    mov     x5, #0
2:  cmp     w5, w2                      // how many codes of each length
    b.ge    3f
    ldrb    w6, [x1, x5]
    ldrh    w7, [x0, x6, lsl #1]
    add     w7, w7, #1
    strh    w7, [x0, x6, lsl #1]
    add     x5, x5, #1
    b       2b
3:  strh    wzr, [x0]
    add     x8, sp, #OFFS
    strh    wzr, [x8, #2]
    mov     x5, #1
4:  ldrh    w6, [x8, x5, lsl #1]        // where each length's symbols start
    ldrh    w7, [x0, x5, lsl #1]
    add     w6, w6, w7
    add     x9, x5, #1
    strh    w6, [x8, x9, lsl #1]
    mov     x5, x9
    cmp     x5, #15
    b.lo    4b
    add     x9, x0, #H_SYMBOL
    mov     x5, #0
5:  cmp     w5, w2
    b.ge    6f
    ldrb    w6, [x1, x5]
    cbz     w6, 51f
    ldrh    w7, [x8, x6, lsl #1]
    strh    w5, [x9, x7, lsl #1]
    add     w7, w7, #1
    strh    w7, [x8, x6, lsl #1]
51: add     x5, x5, #1
    b       5b
6:  add     x10, x0, #H_FAST            // the quick table: every 9-bit pattern that starts with a short code
    mov     x5, #0
7:  strh    wzr, [x10, x5, lsl #1]
    add     x5, x5, #1
    cmp     x5, #512
    b.lo    7b
    mov     w11, #0                     // code
    mov     w12, #0                     // index
    mov     w13, #1                     // length
8:  ldrh    w14, [x0, x13, lsl #1]
    mov     w15, #0
81: cmp     w15, w14
    b.ge    84f
    rbit    w5, w11                     // the code's bits, first bit lowest
    mov     w6, #32
    sub     w6, w6, w13
    lsr     w5, w5, w6
    ldrh    w7, [x9, x12, lsl #1]
    orr     w7, w7, w13, lsl #9
    mov     w6, #1
    lsl     w6, w6, w13
82: cmp     w5, #512
    b.ge    83f
    strh    w7, [x10, x5, lsl #1]
    add     w5, w5, w6
    b       82b
83: add     w11, w11, #1
    add     w12, w12, #1
    add     w15, w15, #1
    b       81b
84: lsl     w11, w11, #1
    add     w13, w13, #1
    cmp     w13, #9
    b.le    8b
    ret

// decode: x0 a code table -> w0 the next symbol, or -1. Uses w5-w12, x16.
decode:
    mov     x16, x30
    mov     w8, #15
    FILL    w8
    and     w8, w22, #511
    add     x9, x0, #H_FAST
    ldrh    w8, [x9, x8, lsl #1]
    cbz     w8, d_slow
    lsr     w9, w8, #9
    TAKE    w9
    and     w0, w8, #511
    cmp     w25, #0
    csinv   w0, w0, wzr, eq
    ret     x16
d_slow:                                 // a long code: one bit at a time
    mov     x12, x0
    mov     w8, #0                      // code
    mov     w9, #0                      // first
    mov     w10, #0                     // index
    mov     w11, #1                     // length
1:  mov     w0, #1
    bl      getbits
    orr     w8, w8, w0
    ldrh    w5, [x12, x11, lsl #1]
    sub     w6, w8, w5
    cmp     w6, w9
    b.ge    2f
    sub     w6, w8, w9
    add     w6, w6, w10
    add     x7, x12, #H_SYMBOL
    ldrh    w0, [x7, w6, sxtw #1]
    ret     x16
2:  add     w10, w10, w5
    add     w9, w9, w5
    lsl     w9, w9, #1
    lsl     w8, w8, #1
    cbnz    w25, 3f
    add     w11, w11, #1
    cmp     w11, #15
    b.le    1b
    mov     w25, #1
3:  mov     w0, #-1
    ret     x16

// locate: x0 the input block (or 0) -> w0 1 if usable, the reader set up, w13 1 for gzip, w14 the length gzip states. Uses x5-x9.
locate:
    cbz     x0, l_no
    ldr     w5, [x0]
    cmp     w5, #2
    b.ne    l_no
    ldr     x5, [x0, #16]
    cmp     x5, #(64 + 2)
    b.lo    l_no
    add     x19, x0, #64
    sub     x20, x5, #64
    mov     x21, #0
    mov     w13, #0
    mov     w14, #0
    ldrb    w6, [x19]
    ldrb    w7, [x19, #1]
    cmp     x20, #18
    b.lo    l_zlib
    cmp     w6, #0x1f
    b.ne    l_zlib
    cmp     w7, #0x8b
    b.ne    l_zlib
    ldrb    w5, [x19, #2]
    cmp     w5, #8
    b.ne    l_no
    ldrb    w8, [x19, #3]               // which optional parts the header has
    mov     x21, #10
    tbz     w8, #2, 1f
    add     x5, x21, #2
    cmp     x5, x20
    b.hi    l_no
    ldrb    w5, [x19, x21]
    add     x9, x21, #1
    ldrb    w9, [x19, x9]
    orr     x5, x5, x9, lsl #8
    add     x21, x21, x5
    add     x21, x21, #2
1:  tbz     w8, #3, 3f
2:  cmp     x21, x20
    b.hs    21f
    ldrb    w5, [x19, x21]
    cbz     w5, 21f
    add     x21, x21, #1
    b       2b
21: add     x21, x21, #1
3:  tbz     w8, #4, 5f
4:  cmp     x21, x20
    b.hs    41f
    ldrb    w5, [x19, x21]
    cbz     w5, 41f
    add     x21, x21, #1
    b       4b
41: add     x21, x21, #1
5:  tbz     w8, #1, 6f
    add     x21, x21, #2
6:  add     x5, x21, #8
    cmp     x5, x20
    b.hi    l_no
    mov     w13, #1
    sub     x5, x20, #4
    ldr     w14, [x19, x5]              // the stated length, lowest byte first
    sub     x20, x20, #8
    b       l_yes
l_zlib:
    and     w5, w6, #15
    cmp     w5, #8
    b.ne    l_yes
    lsl     w5, w6, #8
    orr     w5, w5, w7
    mov     w8, #31
    udiv    w9, w5, w8
    msub    w9, w9, w8, w5
    cbnz    w9, l_yes
    tbnz    w7, #5, l_yes
    mov     x21, #2
l_yes:
    mov     w22, #0
    mov     w23, #0
    mov     w24, #0
    mov     w25, #0
    mov     w0, #1
    ret
l_no:
    mov     w0, #0
    ret

    .macro  enter
    sub     sp, sp, #4096
    sub     sp, sp, #(FRAME - 4096)
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    .endm
    .macro  leave
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #4096
    add     sp, sp, #(FRAME - 4096)
    ret
    .endm
// the block at the handle in the first number, or 0
    .macro  FIRST
    mov     x0, #0
    cmp     x2, #1
    b.lt    1f
    ldrsh   x5, [x1]
    cmp     x5, #0
    b.lt    1f
    cmp     x5, #255
    b.gt    1f
    add     x5, x5, #256
    ldr     x0, [x4, x5, lsl #3]
1:
    .endm

size:
    enter
    FIRST
    bl      locate
    cbz     w0, 2f
    cbz     w13, 2f
    mov     w0, w14
    b       3f
2:  mov     x0, #-1
3:  leave

unpack:
    enter
    mov     x26, x0                     // the output block for now
    FIRST
    mov     x15, x0                     // the input block
    bl      locate
    cbz     w0, u_fail
    cmp     x26, x15
    b.eq    u_fail
    ldr     x5, [x26, #16]
    cmp     x5, #64
    b.lo    u_fail
    sub     x27, x5, #64
    add     x26, x26, #64
    mov     x28, #0
    str     x15, [sp, #V_INPUT]
    b       u_begin
u_fail:
    mov     x0, #-1
    leave

// --- the deflate stream ----------------------------------------------------------------------------------------------------------
u_begin:
    str     w13, [sp, #V_GZIP]
    str     w14, [sp, #V_STATED]
b_block:
    mov     w0, #1
    bl      getbits
    str     w0, [sp, #V_LAST]
    mov     w0, #2
    bl      getbits
    cbnz    w25, u_fail
    cbz     w0, b_stored
    cmp     w0, #3
    b.eq    u_fail
    cmp     w0, #1
    b.ne    b_dynamic
    add     x1, sp, #LENGTHS            // the fixed codes
    mov     x5, #0
1:  mov     w6, #8
    cmp     x5, #144
    b.lo    2f
    mov     w6, #9
    cmp     x5, #256
    b.lo    2f
    mov     w6, #7
    cmp     x5, #280
    b.lo    2f
    mov     w6, #8
2:  strb    w6, [x1, x5]
    add     x5, x5, #1
    cmp     x5, #288
    b.lo    1b
    add     x0, sp, #LIT
    mov     w2, #288
    bl      build
    add     x1, sp, #LENGTHS
    mov     x5, #0
    mov     w6, #5
3:  strb    w6, [x1, x5]
    add     x5, x5, #1
    cmp     x5, #30
    b.lo    3b
    add     x0, sp, #DIST
    mov     w2, #30
    bl      build
    b       b_codes
b_stored:
    and     w5, w23, #7                 // to a byte boundary, then a length, its complement, and that many bytes as they are
    TAKE    w5
    mov     w0, #16
    bl      getbits
    mov     w10, w0
    mov     w0, #16
    bl      getbits
    cbnz    w25, u_fail
    mov     w5, #0xffff
    eor     w5, w10, w5
    cmp     w5, w0
    b.ne    u_fail
    mov     w11, #0
1:  cmp     w11, w10
    b.hs    2f
    cmp     x28, x27
    b.hs    u_fail
    mov     w0, #8
    bl      getbits
    strb    w0, [x26, x28]
    add     x28, x28, #1
    add     w11, w11, #1
    b       1b
2:  cbnz    w25, u_fail
    b       b_next
b_dynamic:
    mov     w0, #5                      // the block describes its own codes
    bl      getbits
    add     w10, w0, #257               // literal and length codes
    mov     w0, #5
    bl      getbits
    add     w11, w0, #1                 // distance codes
    mov     w0, #4
    bl      getbits
    add     w12, w0, #4                 // code-length codes
    cmp     w10, #286
    b.gt    u_fail
    cmp     w11, #30
    b.gt    u_fail
    add     x13, sp, #CL
    mov     x5, #0
1:  strb    wzr, [x13, x5]
    add     x5, x5, #1
    cmp     x5, #19
    b.lo    1b
    mov     w14, #0
2:  cmp     w14, w12
    b.ge    3f
    mov     w0, #3
    bl      getbits
    adr     x5, t_order
    ldrb    w5, [x5, w14, uxtw]
    add     x13, sp, #CL
    strb    w0, [x13, x5]
    add     w14, w14, #1
    b       2b
3:  str     w10, [sp, #V_NLEN]
    str     w11, [sp, #V_NDIST]
    add     x0, sp, #CODES
    add     x1, sp, #CL
    mov     w2, #19
    bl      build
    mov     w14, #0                     // i
4:  ldr     w10, [sp, #V_NLEN]
    ldr     w11, [sp, #V_NDIST]
    add     w15, w10, w11
    cmp     w14, w15
    b.ge    8f
    add     x0, sp, #CODES
    str     w14, [sp, #V_KEPT]
    bl      decode
    ldr     w14, [sp, #V_KEPT]
    cmp     w0, #0
    b.lt    u_fail
    add     x13, sp, #LENGTHS
    cmp     w0, #16
    b.ge    5f
    strb    w0, [x13, w14, uxtw]
    add     w14, w14, #1
    b       4b
5:  mov     w12, #0                     // the value to repeat
    b.ne    6f
    cbz     w14, u_fail                 // 16: the previous length again, 3 to 6 times
    sub     w5, w14, #1
    ldrb    w12, [x13, w5, uxtw]
    mov     w0, #2
    bl      getbits
    add     w11, w0, #3
    b       7f
6:  cmp     w0, #17
    b.ne    61f
    mov     w0, #3                      // 17: zero, 3 to 10 times
    bl      getbits
    add     w11, w0, #3
    b       7f
61: mov     w0, #7                      // 18: zero, 11 to 138 times
    bl      getbits
    add     w11, w0, #11
7:  ldr     w5, [sp, #V_NLEN]
    ldr     w6, [sp, #V_NDIST]
    add     w5, w5, w6
    add     w6, w14, w11
    cmp     w6, w5
    b.gt    u_fail
    add     x13, sp, #LENGTHS
71: cbz     w11, 4b
    strb    w12, [x13, w14, uxtw]
    add     w14, w14, #1
    sub     w11, w11, #1
    b       71b
8:  add     x0, sp, #LIT
    add     x1, sp, #LENGTHS
    ldr     w2, [sp, #V_NLEN]
    bl      build
    add     x0, sp, #DIST
    add     x1, sp, #LENGTHS
    ldr     w5, [sp, #V_NLEN]
    add     x1, x1, x5
    ldr     w2, [sp, #V_NDIST]
    bl      build
b_codes:                                // literals, lengths with distances, until the end-of-block code
    add     x0, sp, #LIT
    bl      decode
    cmp     w0, #0
    b.lt    u_fail
    cbnz    w25, u_fail
    cmp     w0, #256
    b.ge    1f
    cmp     x28, x27
    b.hs    u_fail
    strb    w0, [x26, x28]
    add     x28, x28, #1
    b       b_codes
1:  b.eq    b_next
    sub     w10, w0, #257
    cmp     w10, #29
    b.ge    u_fail
    adr     x5, t_lext
    ldrb    w0, [x5, w10, uxtw]
    bl      getbits
    adr     x5, t_lbase
    ldrh    w5, [x5, w10, uxtw #1]
    add     w10, w5, w0                 // how many bytes to copy
    add     x0, sp, #DIST
    str     w10, [sp, #V_KEPT]
    bl      decode
    ldr     w10, [sp, #V_KEPT]
    cmp     w0, #0
    b.lt    u_fail
    cmp     w0, #30
    b.ge    u_fail
    mov     w11, w0
    adr     x5, t_dext
    ldrb    w0, [x5, w11, uxtw]
    bl      getbits
    adr     x5, t_dbase
    ldrh    w5, [x5, w11, uxtw #1]
    add     w11, w5, w0                 // how far back
    cbnz    w25, u_fail
    cmp     x11, x28
    b.hi    u_fail
    add     x5, x28, x10
    cmp     x5, x27
    b.hi    u_fail
    sub     x5, x28, x11
2:  cbz     w10, b_codes                // byte by byte: the copy may overlap what it is writing
    ldrb    w6, [x26, x5]
    strb    w6, [x26, x28]
    add     x5, x5, #1
    add     x28, x28, #1
    sub     w10, w10, #1
    b       2b
b_next:
    ldr     w5, [sp, #V_LAST]
    cbz     w5, b_block
    cbnz    w25, u_fail

// --- the checksum at the end -----------------------------------------------------------------------------------------------------
    ldr     w13, [sp, #V_GZIP]
    ldr     w14, [sp, #V_STATED]
    ldr     x15, [sp, #V_INPUT]
    cbz     w13, u_zlib
    cmp     w28, w14                    // gzip: the stated length, then a CRC-32 of what was unpacked
    b.ne    u_fail
    ldr     x5, [x15, #16]
    sub     x5, x5, #64
    add     x6, x15, #64
    sub     x5, x5, #8
    ldr     w7, [x6, x5]
    mov     w8, #-1
    mov     x9, #0
1:  cmp     x9, x28
    b.hs    2f
    ldrb    w10, [x26, x9]
    crc32b  w8, w8, w10
    add     x9, x9, #1
    b       1b
2:  mvn     w8, w8
    cmp     w8, w7
    b.ne    u_fail
    b       u_done
u_zlib:
    cmp     x21, #2                     // zlib (it had the two-byte header): an Adler-32, highest byte first, right after the data
    b.lo    u_done
    add     x6, x15, #64
    ldrb    w7, [x6]
    ldrb    w8, [x6, #1]
    and     w5, w7, #15
    cmp     w5, #8
    b.ne    u_done
    lsl     w5, w7, #8
    orr     w5, w5, w8
    mov     w9, #31
    udiv    w10, w5, w9
    msub    w10, w10, w9, w5
    cbnz    w10, u_done
    tbnz    w8, #5, u_done
    sub     w5, w23, w24                // whole bytes still held and not used
    mov     w9, #8
    sdiv    w5, w5, w9
    sub     x9, x21, w5, sxtw
    add     x10, x9, #4
    ldr     x5, [x15, #16]
    sub     x5, x5, #64
    cmp     x10, x5
    b.hi    u_fail
    mov     w10, #1                     // a
    mov     w11, #0                     // b
    mov     w12, #65521
    mov     x5, #0
3:  cmp     x5, x28
    b.hs    4f
    ldrb    w7, [x26, x5]
    add     w10, w10, w7
    cmp     w10, w12
    b.lo    31f
    sub     w10, w10, w12
31: add     w11, w11, w10
    cmp     w11, w12
    b.lo    32f
    sub     w11, w11, w12
32: add     x5, x5, #1
    b       3b
4:  orr     w10, w10, w11, lsl #16
    ldr     w7, [x6, x9]
    rev     w7, w7
    cmp     w7, w10
    b.ne    u_fail
u_done:
    mov     x0, x28
    leave

    .balign 2
t_lbase: .hword 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258
t_dbase: .hword 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577
t_lext:  .byte 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0
t_dext:  .byte 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13
t_order: .byte 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
    .balign 4
