// jpeg, written by hand (ARM64): reads JPEG photographs, baseline and progressive. The meaning is jpeg/intent.md; the recorded
// checks are the judge. Entries: x0 surface (four bytes a dot), x1 numbers (16-bit): the file's handle and a scratch block's;
// x2 how many; x4 call table. Calls nothing. Laid out by tools/jpeg_asm.py (the frame's offsets and the transform's constants);
// the source is jpeg/impl.body.S.
// Through an entry: x19 the frame, x20 the file's bytes, x21 how many, x22 where the next compressed byte is, x23 bits taken from
// the file and not yet used (the next one highest), w24 how many, w25 set when a marker has been met (no more bits are taken),
// w26 set once the file cannot be followed. LM in the frame says the marker has also been reached by the bits used.
    .text
    .global check
    .global size
    .global decode
    .equ WIDTH, 96
    .equ HEIGHT, 100
    .equ COMPS, 104
    .equ HMAX, 108
    .equ VMAX, 112
    .equ RESTART, 116
    .equ PROG, 120
    .equ LM, 124
    .equ SCAN, 128
    .equ C0, 136
    .equ QUANT, 280
    .equ HUFF, 792
    .equ SURF, 3032
    .equ SCRATCH, 3040
    .equ NEEDP, 3048
    .equ PLANE, 3056
    .equ IDCT_LR, 3064
    .equ CO, 3072
    .equ P_END, 3080
    .equ P_AT, 3088
    .equ P_BODY, 3096
    .equ ONE, 3104
    .equ TMP, 3112
    .equ TMP2, 3120
    .equ BLK, 3128
    .equ CAT0, 3136
    .equ CAT1, 3144
    .equ CAT2, 3152
    .equ MX, 3160
    .equ MY, 3164
    .equ ROW, 3168
    .equ COL, 3172
    .equ DONE, 3176
    .equ CI, 3180
    .equ BY, 3184
    .equ BX, 3188
    .equ STRIDE, 3192
    .equ NS, 3196
    .equ CIDX0, 3200
    .equ CIDX1, 3204
    .equ CIDX2, 3208
    .equ SS, 3212
    .equ SE, 3216
    .equ AH, 3220
    .equ AL, 3224
    .equ EOB, 3228
    .equ BW, 3232
    .equ BH, 3236
    .equ TOTAL, 3240
    .equ NN, 3244
    .equ SCANS, 3248
    .equ K, 3252
    .equ I2, 3256
    .equ COEF, 3264
    .equ VBUF, 3520
    .equ TABS, 3776
    .equ FRAME, 11968
    // a component: how many squares across and down in each unit, its tables, its running first value, where its plane is
    .equ C_H, 0
    .equ C_V, 4
    .equ C_Q, 8
    .equ C_DC, 12
    .equ C_AC, 16
    .equ C_PRED, 20
    .equ C_ID, 24
    .equ C_PW, 28
    .equ C_PH, 32
    .equ C_AT, 40
    // a set of codes: how many of each length (1 to 16), the symbols in order, whether the file gave it
    .equ H_SYMBOL, 17
    .equ H_PRESENT, 276
    .macro  ADDR reg, off
    mov     \reg, #\off
    add     \reg, x19, \reg
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
// rd8: the file's byte at x0 -> w0; past the end it is 0 and the file is marked as not followable. Touches nothing else.
rd8:
    cmp     x0, x21
    b.hs    1f
    ldrb    w0, [x20, x0]
    ret
1:  mov     w26, #1
    mov     w0, #0
    ret
// rd16: the two bytes at x0, the first the higher -> w0. Uses x15, x16, x17.
rd16:
    mov     x16, x30
    mov     x15, x0
    bl      rd8
    lsl     w17, w0, #8
    add     x0, x15, #1
    bl      rd8
    orr     w0, w0, w17
    ret     x16
// build_tab: for the codes at x0, a table at x1 answering any code of up to nine bits at once: for each nine bits, the meaning's
// own bit by bit search is run here once (entry: symbol * 16 + length, or 0 if it needs more bits). Uses x2-x12.
build_tab:
    mov     x2, #0
1:  mov     w3, #0                      // the code so far
    mov     w4, #0                      // the first code of this length
    mov     w5, #0                      // how many symbols have shorter codes
    mov     w6, #1
    mov     w12, #0
2:  mov     w7, #9
    sub     w7, w7, w6
    lsr     w7, w2, w7
    and     w7, w7, #1
    orr     w3, w3, w7
    ldrb    w8, [x0, x6]
    sub     w9, w3, w4
    cmp     w9, w8
    b.ge    3f
    add     w9, w9, w5
    add     x10, x0, #H_SYMBOL
    ldrb    w12, [x10, w9, sxtw]
    orr     w12, w6, w12, lsl #4
    b       4f
3:  add     w5, w5, w8
    add     w4, w4, w8
    lsl     w4, w4, #1
    lsl     w3, w3, #1
    add     w6, w6, #1
    cmp     w6, #9
    b.ls    2b
4:  strh    w12, [x1, x2, lsl #1]
    add     x2, x2, #1
    cmp     x2, #512
    b.lo    1b
    ret
// dht: the code tables in the file from x0 up to x1. A table that cannot be read marks the file as not followable.
dht:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    mov     x27, x0
    mov     x28, x1
d_table:
    cmp     x27, x28
    b.hs    d_out
    cbnz    w26, d_out
    mov     x0, x27
    bl      rd8
    add     x27, x27, #1
    lsr     w9, w0, #4
    and     w10, w0, #15
    cmp     w9, #1
    b.hi    d_bad
    cmp     w10, #3
    b.hi    d_bad
    add     w10, w10, w9, lsl #2        // which of the eight sets: four for first values, four for the rest
    mov     w11, #280
    umull   x29, w10, w11
    add     x29, x29, x19
    add     x29, x29, #HUFF             // (x29 is saved above and free here)
    str     w10, [x19, #TMP]
    strb    wzr, [x29]
    mov     w12, #0                     // how many symbols in all
    mov     x13, #1
1:  mov     x0, x27
    bl      rd8
    add     x27, x27, #1
    strb    w0, [x29, x13]
    add     w12, w12, w0
    add     x13, x13, #1
    cmp     x13, #16
    b.ls    1b
    cmp     w12, #256
    b.hi    d_bad
    add     x14, x29, #H_SYMBOL
    mov     x13, #0
2:  cmp     w13, w12
    b.hs    3f
    mov     x0, x27
    bl      rd8
    add     x27, x27, #1
    strb    w0, [x14, x13]
    add     x13, x13, #1
    b       2b
3:  mov     w9, #1
    str     w9, [x29, #H_PRESENT]
    mov     x0, x29
    ldr     w10, [x19, #TMP]
    ADDR    x1, TABS
    add     x1, x1, x10, lsl #10
    bl      build_tab
    b       d_table
d_bad:
    mov     w26, #1
d_out:
    ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// COMP: the address of component \i (a register) -> \reg
    .macro  COMP reg, i
    add     \reg, \i, \i, lsl #1
    add     \reg, x19, \reg, lsl #4
    add     \reg, \reg, #C0
    .endm
// open_jpg: the headers of the file in the block x0 (or 0): tables, the frame, and where the compressed data starts -> x0 1 or 0
open_jpg:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    cbz     x0, o_no
    ldr     w9, [x0]
    cmp     w9, #2
    b.ne    o_no
    ldr     x21, [x0, #16]
    cmp     x21, #(64 + 4)
    b.lo    o_no
    sub     x21, x21, #64
    add     x20, x0, #64
    mov     w26, #0
    add     x9, x19, #WIDTH             // nothing is known yet; tables the file never gives count as zeros
    mov     x10, #((HUFF + 8 * 280 - WIDTH) / 8)
1:  str     xzr, [x9], #8
    subs    x10, x10, #1
    b.ne    1b
    ldrh    w9, [x20]
    mov     w10, #0xd8ff
    cmp     w9, w10
    b.ne    o_no
    mov     x27, #2
o_part:
    add     x9, x27, #4
    cmp     x9, x21
    b.hi    o_done
    cbnz    w26, o_done
    ldrb    w9, [x20, x27]
    cmp     w9, #0xff
    b.ne    o_no
    add     x9, x27, #1
    ldrb    w29, [x20, x9]              // which kind of part
    cmp     w29, #0xff
    b.ne    1f
    add     x27, x27, #1
    b       o_part
1:  add     x9, x27, #2
    ldrh    w10, [x20, x9]
    rev16   w10, w10
    cmp     w10, #2
    b.lo    o_no
    add     x28, x9, x10                // where the part ends
    cmp     x28, x21
    b.hi    o_no
    add     x27, x27, #4                // its contents
    cmp     w29, #0xdb
    b.ne    o_not_q
2:  cmp     x27, x28                    // the tables of step sizes
    b.hs    o_next
    mov     x0, x27
    bl      rd8
    add     x27, x27, #1
    lsr     w9, w0, #4
    and     w10, w0, #15
    cmp     w10, #3
    b.hi    o_no
    cmp     w9, #1
    b.hi    o_no
    add     x11, x19, #QUANT
    add     x11, x11, x10, lsl #7
    mov     x12, #0
3:  mov     x0, x27
    cbz     w9, 4f
    bl      rd16
    add     x27, x27, #2
    b       5f
4:  bl      rd8
    add     x27, x27, #1
5:  strh    w0, [x11, x12, lsl #1]
    add     x12, x12, #1
    cmp     x12, #64
    b.lo    3b
    b       2b
o_not_q:
    cmp     w29, #0xc4
    b.ne    o_not_h
    mov     x0, x27
    mov     x1, x28
    bl      dht
    cbnz    w26, o_no
    b       o_next
o_not_h:
    cmp     w29, #0xc0
    b.eq    1f
    cmp     w29, #0xc2
    b.ne    o_not_f
1:  cmp     w29, #0xc2                  // the frame: its size, and for each component its sampling and step table
    cset    w9, eq
    str     w9, [x19, #PROG]
    mov     x0, x27
    bl      rd8
    cmp     w0, #8
    b.ne    o_no
    add     x0, x27, #1
    bl      rd16
    str     w0, [x19, #HEIGHT]
    add     x0, x27, #3
    bl      rd16
    str     w0, [x19, #WIDTH]
    add     x0, x27, #5
    bl      rd8
    str     w0, [x19, #COMPS]
    cmp     w0, #1
    b.eq    2f
    cmp     w0, #3
    b.ne    o_no
2:  mov     w9, #1
    str     w9, [x19, #HMAX]
    str     w9, [x19, #VMAX]
    mov     x29, #0
3:  ldr     w9, [x19, #COMPS]
    cmp     w29, w9
    b.hs    o_next
    COMP    x12, x29
    add     x13, x29, x29, lsl #1
    add     x13, x13, x27
    add     x0, x13, #7
    bl      rd8
    lsr     w9, w0, #4
    and     w10, w0, #15
    str     w9, [x12, #C_H]
    str     w10, [x12, #C_V]
    add     x0, x13, #6
    bl      rd8
    str     w0, [x12, #C_ID]
    add     x0, x13, #8
    bl      rd8
    str     w0, [x12, #C_Q]
    cmp     w0, #3
    b.hi    o_no
    ldr     w9, [x12, #C_H]
    ldr     w10, [x12, #C_V]
    sub     w11, w9, #1
    cmp     w11, #1
    b.hi    o_no
    sub     w11, w10, #1
    cmp     w11, #1
    b.hi    o_no
    ldr     w11, [x19, #HMAX]
    cmp     w9, w11
    csel    w11, w9, w11, gt
    str     w11, [x19, #HMAX]
    ldr     w11, [x19, #VMAX]
    cmp     w10, w11
    csel    w11, w10, w11, gt
    str     w11, [x19, #VMAX]
    add     x29, x29, #1
    b       3b
o_not_f:
    cmp     w29, #0xc1                  // extended, lossless, arithmetic: not read
    b.eq    o_no
    cmp     w29, #0xc5
    b.lo    1f
    cmp     w29, #0xcf
    b.hi    1f
    cmp     w29, #0xc8
    b.ne    o_no
1:  cmp     w29, #0xdd
    b.ne    2f
    mov     x0, x27
    bl      rd16
    str     w0, [x19, #RESTART]
    b       o_next
2:  cmp     w29, #0xda
    b.ne    o_next
    ldr     w9, [x19, #COMPS]           // the compressed data begins
    cbz     w9, o_no
    ldr     w10, [x19, #PROG]
    cbz     w10, 3f
    sub     x9, x27, #4
    str     x9, [x19, #SCAN]
    b       o_done
3:  mov     x0, x27
    bl      rd8
    ldr     w9, [x19, #COMPS]
    cmp     w0, w9
    b.ne    o_no
    mov     x29, #0
4:  ldr     w9, [x19, #COMPS]
    cmp     w29, w9
    b.hs    5f
    add     x0, x27, #2
    add     x0, x0, x29, lsl #1
    bl      rd8
    COMP    x12, x29
    lsr     w9, w0, #4
    and     w10, w0, #15
    str     w9, [x12, #C_DC]
    str     w10, [x12, #C_AC]
    cmp     w9, #3
    b.hi    o_no
    cmp     w10, #3
    b.hi    o_no
    mov     w11, #280
    umull   x13, w9, w11
    add     x13, x13, x19
    add     x13, x13, #HUFF
    ldr     w13, [x13, #H_PRESENT]
    cbz     w13, o_no
    add     w10, w10, #4
    umull   x13, w10, w11
    add     x13, x13, x19
    add     x13, x13, #HUFF
    ldr     w13, [x13, #H_PRESENT]
    cbz     w13, o_no
    add     x29, x29, #1
    b       4b
5:  str     x28, [x19, #SCAN]
    b       o_done
o_next:
    mov     x27, x28
    b       o_part
o_done:
    cbnz    w26, o_no
    ldr     x9, [x19, #SCAN]
    cbz     x9, o_no
    ldr     w9, [x19, #WIDTH]
    cbz     w9, o_no
    cmp     w9, #16384
    b.hi    o_no
    ldr     w9, [x19, #HEIGHT]
    cbz     w9, o_no
    cmp     w9, #16384
    b.hi    o_no
    ldr     w9, [x19, #COMPS]
    cmp     w9, #3
    b.ne    1f
    ldr     w9, [x19, #(C0 + 48 + C_H)] // colour planes at the base rate only
    ldr     w10, [x19, #(C0 + 48 + C_V)]
    ldr     w11, [x19, #(C0 + 96 + C_H)]
    ldr     w12, [x19, #(C0 + 96 + C_V)]
    and     w9, w9, w10
    and     w9, w9, w11
    and     w9, w9, w12
    orr     w10, w10, w11
    orr     w10, w10, w12
    ldr     w11, [x19, #(C0 + 48 + C_H)]
    orr     w10, w10, w11
    cmp     w10, #1
    b.ne    o_no
1:  mov     x0, #1
    b       o_out
o_no:
    mov     x0, #0
o_out:
    ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
    .ltorg

// refill: takes bytes from the file while there is room, until a marker. A byte of all ones followed by a zero byte is that byte
// alone; followed by anything else it is a marker, and nothing more is taken. Uses x9-x11.
refill:
1:  cmp     w24, #56
    b.hi    9f
    cbnz    w25, 9f
    cmp     x22, x21
    b.hs    9f
    ldrb    w9, [x20, x22]
    add     x22, x22, #1
    cmp     w9, #0xff
    b.ne    3f
    mov     w10, #0xd9
    cmp     x22, x21
    b.hs    2f
    ldrb    w10, [x20, x22]
2:  cbnz    w10, 4f
    add     x22, x22, #1
3:  mov     w11, #56
    sub     w11, w11, w24
    lsl     x9, x9, x11
    orr     x23, x23, x9
    add     w24, w24, #8
    b       1b
4:  mov     w25, #1
    sub     x22, x22, #1
9:  ret
// WANT: makes sure \k bits (a register, at most 16) can be used: real ones if the file has them; past a marker or the end, zeros
    .macro  WANT k
    cmp     w24, \k
    b.hs    70f
    bl      refill
    cmp     w24, \k
    b.hs    70f
    str     w25, [x19, #LM]             // from here the bits are zeros; if a marker stopped them, it has now been reached
    add     w24, w24, #32
70:
    .endm
// getbits: the next w0 bits (0 to 16) as a number -> w0. Uses x12, x16 and what refill uses.
getbits:
    cbz     w0, 9f
    mov     x16, x30
    mov     w12, w0
    WANT    w12
    neg     w9, w12
    lsr     x0, x23, x9
    lsl     x23, x23, x12
    sub     w24, w24, w12
    ret     x16
9:  ret
// symbol: the next symbol under the codes at x0, whose nine-bit table is at x1 -> w0. Uses x2-x8, x12, x17 and what refill uses.
symbol:
    mov     x17, x30
    bl      refill
    lsr     x2, x23, #55
    ldrh    w3, [x1, x2, lsl #1]
    cbz     w3, s_slow
    and     w12, w3, #15
    WANT    w12
    lsl     x23, x23, x12
    sub     w24, w24, w12
    lsr     w0, w3, #4
    ret     x17
s_slow:                                 // a longer code, or none: bit by bit, as the meaning has it
    mov     w3, #0
    mov     w4, #0
    mov     w5, #0
    mov     w6, #1
    mov     w12, #1
1:  WANT    w12
    lsr     x7, x23, #63
    lsl     x23, x23, #1
    sub     w24, w24, #1
    orr     w3, w3, w7
    ldrb    w8, [x0, x6]
    sub     w7, w3, w4
    cmp     w7, w8
    b.ge    2f
    add     w7, w7, w5
    add     x8, x0, #H_SYMBOL
    ldrb    w0, [x8, w7, sxtw]
    ret     x17
2:  add     w5, w5, w8
    add     w4, w4, w8
    lsl     w4, w4, #1
    lsl     w3, w3, #1
    add     w6, w6, #1
    cmp     w6, #16
    b.ls    1b
    mov     w26, #1
    mov     w0, #0
    ret     x17
// EXTEND: the w0 just read with \s bits (a register), as the signed value it stands for -> w0. Uses w9, w10.
    .macro  EXTEND s
    cbz     \s, 71f
    mov     w9, #1
    sub     w10, \s, #1
    lsl     w10, w9, w10
    cmp     w0, w10
    b.ge    71f
    lsl     w9, w9, \s
    sub     w0, w0, w9
    add     w0, w0, #1
71:
    .endm

    .macro  VKERNEL
    mov     w16, #2217
    dup     v25.4s, w16
    add     v20.4s, v2.4s, v6.4s
    mul     v20.4s, v20.4s, v25.4s
    mov     w16, #-7567
    dup     v25.4s, w16
    mov     v21.16b, v20.16b
    mla     v21.4s, v6.4s, v25.4s
    mov     w16, #3135
    dup     v25.4s, w16
    mov     v22.16b, v20.16b
    mla     v22.4s, v2.4s, v25.4s
    add     v23.4s, v0.4s, v4.4s
    shl     v23.4s, v23.4s, #12
    sub     v24.4s, v0.4s, v4.4s
    shl     v24.4s, v24.4s, #12
    add     v16.4s, v23.4s, v22.4s
    sub     v19.4s, v23.4s, v22.4s
    add     v17.4s, v24.4s, v21.4s
    sub     v18.4s, v24.4s, v21.4s
    add     v0.4s, v7.4s, v3.4s
    add     v2.4s, v5.4s, v1.4s
    add     v4.4s, v7.4s, v1.4s
    add     v6.4s, v5.4s, v3.4s
    mov     w16, #4816
    dup     v25.4s, w16
    add     v20.4s, v0.4s, v2.4s
    mul     v20.4s, v20.4s, v25.4s
    mov     w16, #1223
    dup     v25.4s, w16
    mul     v7.4s, v7.4s, v25.4s
    mov     w16, #8410
    dup     v25.4s, w16
    mul     v5.4s, v5.4s, v25.4s
    mov     w16, #12586
    dup     v25.4s, w16
    mul     v3.4s, v3.4s, v25.4s
    mov     w16, #6149
    dup     v25.4s, w16
    mul     v1.4s, v1.4s, v25.4s
    mov     w16, #-3685
    dup     v25.4s, w16
    mov     v21.16b, v20.16b
    mla     v21.4s, v4.4s, v25.4s
    mov     w16, #-10497
    dup     v25.4s, w16
    mov     v22.16b, v20.16b
    mla     v22.4s, v6.4s, v25.4s
    mov     w16, #-8034
    dup     v25.4s, w16
    mul     v0.4s, v0.4s, v25.4s
    mov     w16, #-1597
    dup     v25.4s, w16
    mul     v2.4s, v2.4s, v25.4s
    add     v1.4s, v1.4s, v21.4s
    add     v1.4s, v1.4s, v2.4s
    add     v3.4s, v3.4s, v22.4s
    add     v3.4s, v3.4s, v0.4s
    add     v5.4s, v5.4s, v22.4s
    add     v5.4s, v5.4s, v2.4s
    add     v7.4s, v7.4s, v21.4s
    add     v7.4s, v7.4s, v0.4s
    .endm
// idct: the inverse transform of the 8 by 8 square of 32-bit values at x27, as dots at x28, rows STRIDE apart. Whole numbers,
// the widely used "slow integer" method, four values at a time: the columns in two halves, then the rows four at once (the
// square turned on its side in the registers and turned back as the dots are written). Uses x16, x17, v0-v7, v16-v31.
    // TURN: four registers holding four rows become four registers holding four columns. Uses v28-v31.
    .macro  TURN a, b, c, d
    trn1    v28.4s, \a\().4s, \b\().4s
    trn2    v29.4s, \a\().4s, \b\().4s
    trn1    v30.4s, \c\().4s, \d\().4s
    trn2    v31.4s, \c\().4s, \d\().4s
    trn1    \a\().2d, v28.2d, v30.2d
    trn1    \b\().2d, v29.2d, v31.2d
    trn2    \c\().2d, v28.2d, v30.2d
    trn2    \d\().2d, v29.2d, v31.2d
    .endm
    // RESULT: \x plus or minus \t, with the rounding in v26, shifted down -> \dst
    .macro  COLOUT dst, op, x, t
    \op     \dst\().4s, \x\().4s, \t\().4s
    add     \dst\().4s, \dst\().4s, v26.4s
    sshr    \dst\().4s, \dst\().4s, #10
    .endm
    .macro  ROWOUT dst, op, x, t
    \op     \dst\().4s, \x\().4s, \t\().4s
    add     \dst\().4s, \dst\().4s, v26.4s
    sshr    \dst\().4s, \dst\().4s, #17
    sqxtun  \dst\().4h, \dst\().4s      // squeezed into what a dot can hold: 0 to 255
    uqxtn   \dst\().8b, \dst\().8h
    .endm
    // COLUMNS: four columns of the square (starting \at bytes into each row), transformed in place
    .macro  COLUMNS at
    ldr     q0, [x27, #(0 + \at)]
    ldr     q1, [x27, #(32 + \at)]
    ldr     q2, [x27, #(64 + \at)]
    ldr     q3, [x27, #(96 + \at)]
    ldr     q4, [x27, #(128 + \at)]
    ldr     q5, [x27, #(160 + \at)]
    ldr     q6, [x27, #(192 + \at)]
    ldr     q7, [x27, #(224 + \at)]
    VKERNEL
    COLOUT  v0, add, v16, v1
    COLOUT  v20, sub, v16, v1
    COLOUT  v2, add, v17, v3
    COLOUT  v21, sub, v17, v3
    COLOUT  v4, add, v18, v5
    COLOUT  v22, sub, v18, v5
    COLOUT  v6, add, v19, v7
    COLOUT  v23, sub, v19, v7
    str     q0, [x27, #(0 + \at)]
    str     q2, [x27, #(32 + \at)]
    str     q4, [x27, #(64 + \at)]
    str     q6, [x27, #(96 + \at)]
    str     q23, [x27, #(128 + \at)]
    str     q22, [x27, #(160 + \at)]
    str     q21, [x27, #(192 + \at)]
    str     q20, [x27, #(224 + \at)]
    .endm
    // ROWS: four rows of the square (starting at row \first), transformed and written as dots
    .macro  ROWS first
    ldr     q0, [x27, #(32 * \first)]
    ldr     q1, [x27, #(32 * \first + 32)]
    ldr     q2, [x27, #(32 * \first + 64)]
    ldr     q3, [x27, #(32 * \first + 96)]
    ldr     q4, [x27, #(32 * \first + 16)]
    ldr     q5, [x27, #(32 * \first + 48)]
    ldr     q6, [x27, #(32 * \first + 80)]
    ldr     q7, [x27, #(32 * \first + 112)]
    TURN    v0, v1, v2, v3
    TURN    v4, v5, v6, v7
    VKERNEL
    ROWOUT  v0, add, v16, v1            // dot 0 of each of the four rows; then 7, 1, 6, 2, 5, 3, 4
    ROWOUT  v20, sub, v16, v1
    ROWOUT  v2, add, v17, v3
    ROWOUT  v21, sub, v17, v3
    ROWOUT  v4, add, v18, v5
    ROWOUT  v22, sub, v18, v5
    ROWOUT  v6, add, v19, v7
    ROWOUT  v23, sub, v19, v7
    zip1    v0.8b, v0.8b, v2.8b         // dots 0 and 1 of each row, side by side
    zip1    v4.8b, v4.8b, v6.8b         // dots 2 and 3
    zip1    v0.8h, v0.8h, v4.8h         // dots 0 to 3 of each row
    zip1    v23.8b, v23.8b, v22.8b      // dots 4 and 5
    zip1    v21.8b, v21.8b, v20.8b      // dots 6 and 7
    zip1    v23.8h, v23.8h, v21.8h      // dots 4 to 7 of each row
    ldr     x16, [sp]                   // the distance between rows (the kernel used w16 for its constants)
    st1     {v0.s}[0], [x28]
    add     x17, x28, #4
    st1     {v23.s}[0], [x17]
    add     x28, x28, x16
    st1     {v0.s}[1], [x28]
    add     x17, x28, #4
    st1     {v23.s}[1], [x17]
    add     x28, x28, x16
    st1     {v0.s}[2], [x28]
    add     x17, x28, #4
    st1     {v23.s}[2], [x17]
    add     x28, x28, x16
    st1     {v0.s}[3], [x28]
    add     x17, x28, #4
    st1     {v23.s}[3], [x17]
    add     x28, x28, x16
    .endm
idct:
    mov     w16, #512
    dup     v26.4s, w16
    COLUMNS 0
    COLUMNS 16
    mov     w16, #0x1000000
    add     w16, w16, #0x10000          // rounding, and the 128 that centres the values
    dup     v26.4s, w16
    ldr     w16, [x19, #STRIDE]
    stp     x16, x30, [sp, #-16]!
    ROWS    0
    ROWS    4
    ldp     x16, x30, [sp], #16
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
    mov     x27, x0
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
// HUFFOF: the codes numbered \n (a register; 0-3 for first values, 4-7 for the rest) -> x0, and their table -> x1
    .macro  HUFFOF n
    mov     w10, #280
    umull   x0, \n, w10
    add     x0, x0, x19
    add     x0, x0, #HUFF
    mov     w10, \n
    ADDR    x1, TABS
    add     x1, x1, x10, lsl #10
    .endm
// restart: a restart point: on to the marker, and the bits in hand are dropped
restart:
    ldr     w9, [x19, #LM]
    cbz     w9, 1f
    add     x22, x22, #2
    b       3f
1:  add     x9, x22, #1
    cmp     x9, x21
    b.hs    2f
    ldrb    w10, [x20, x22]
    cmp     w10, #0xff
    b.ne    4f
    ldrb    w10, [x20, x9]
    sub     w10, w10, #0xd0
    cmp     w10, #7
    b.ls    2f
4:  add     x22, x22, #1
    b       1b
2:  add     x22, x22, #2
3:  mov     x23, #0
    mov     w24, #0
    mov     w25, #0
    str     wzr, [x19, #LM]
    ret
size:
    ENTER
    BLOCK   0
    bl      open_jpg
    cbz     x0, 1f
    ldr     w9, [x19, #WIDTH]
    ldr     w10, [x19, #HEIGHT]
    add     x0, x10, x9, lsl #16
    b       2f
1:  mov     x0, #-1
2:  LEAVE

decode:
    ENTER
    str     x27, [x19, #SURF]
    mov     x27, x1
    mov     x28, x2
    mov     x29, x4
    BLOCK   0
    bl      open_jpg
    cbz     x0, c_bad
    mov     x1, x27
    mov     x2, x28
    mov     x4, x29
    BLOCK   1
    cbz     x0, c_bad
    ldr     w9, [x0]
    cmp     w9, #5
    b.ne    c_bad
    ldr     x9, [x0, #16]
    cmp     x9, #64
    b.lo    c_bad
    str     x0, [x19, #SCRATCH]
    ldr     w9, [x19, #HMAX]            // how many units across and down, and where each component's plane goes
    ldr     w10, [x19, #WIDTH]
    lsl     w9, w9, #3
    add     w10, w10, w9
    sub     w10, w10, #1
    udiv    w10, w10, w9
    str     w10, [x19, #MX]
    ldr     w9, [x19, #VMAX]
    ldr     w11, [x19, #HEIGHT]
    lsl     w9, w9, #3
    add     w11, w11, w9
    sub     w11, w11, #1
    udiv    w11, w11, w9
    str     w11, [x19, #MY]
    mov     x12, #0                     // room needed for the planes
    mov     x13, #0
1:  ldr     w9, [x19, #COMPS]
    cmp     w13, w9
    b.hs    2f
    COMP    x14, x13
    ldr     w15, [x14, #C_H]
    mul     w15, w15, w10
    lsl     w15, w15, #3
    str     w15, [x14, #C_PW]
    ldr     w16, [x14, #C_V]
    mul     w16, w16, w11
    lsl     w16, w16, #3
    str     w16, [x14, #C_PH]
    str     x12, [x14, #C_AT]
    umaddl  x12, w15, w16, x12
    str     wzr, [x14, #C_PRED]
    add     x13, x13, #1
    b       1b
2:  str     x12, [x19, #NEEDP]
    ldr     x9, [x0, #16]
    sub     x9, x9, #64
    cmp     x9, x12
    b.lo    c_bad
    add     x9, x0, #64
    str     x9, [x19, #PLANE]
    ldr     x22, [x19, #SCAN]
    mov     x23, #0
    mov     w24, #0
    mov     w25, #0
    str     wzr, [x19, #LM]
    str     wzr, [x19, #DONE]
    ldr     w9, [x19, #PROG]
    cbz     w9, c_baseline
    bl      progressive
    cbz     x0, c_bad
    b       c_colour
c_baseline:
    str     wzr, [x19, #ROW]
c_row:
    ldr     w9, [x19, #ROW]
    ldr     w10, [x19, #MY]
    cmp     w9, w10
    b.hs    c_colour
    str     wzr, [x19, #COL]
c_col:
    ldr     w9, [x19, #COL]
    ldr     w10, [x19, #MX]
    cmp     w9, w10
    b.hs    c_row_next
    ldr     w9, [x19, #RESTART]
    cbz     w9, 2f
    ldr     w10, [x19, #DONE]
    cbz     w10, 2f
    udiv    w11, w10, w9
    msub    w11, w11, w9, w10
    cbnz    w11, 2f
    bl      restart
    str     wzr, [x19, #(C0 + C_PRED)]
    str     wzr, [x19, #(C0 + 48 + C_PRED)]
    str     wzr, [x19, #(C0 + 96 + C_PRED)]
2:  str     wzr, [x19, #CI]
c_comp:
    ldr     w9, [x19, #CI]
    ldr     w10, [x19, #COMPS]
    cmp     w9, w10
    b.hs    c_unit_done
    str     wzr, [x19, #BY]
c_by:
    ldr     w9, [x19, #CI]
    COMP    x28, x9
    ldr     w9, [x19, #BY]
    ldr     w10, [x28, #C_V]
    cmp     w9, w10
    b.ge    c_comp_next
    str     wzr, [x19, #BX]
c_bx:
    ldr     w9, [x19, #BX]
    ldr     w10, [x28, #C_H]
    cmp     w9, w10
    b.ge    c_by_next
    add     x9, x19, #COEF              // one square: its 64 amounts start at zero
    mov     x10, #16
1:  stp     xzr, xzr, [x9], #16
    subs    x10, x10, #1
    b.ne    1b
    ldr     w9, [x28, #C_Q]
    add     x27, x19, #QUANT
    add     x27, x27, x9, lsl #7
    ldr     w9, [x28, #C_DC]            // the first amount is stored as its difference from the square before
    HUFFOF  w9
    bl      symbol
    cmp     w0, #11
    b.hi    c_bad
    mov     w29, w0
    bl      getbits
    EXTEND  w29
    ldr     w9, [x28, #C_PRED]
    add     w9, w9, w0
    str     w9, [x28, #C_PRED]
    ldrh    w10, [x27]
    mul     w9, w9, w10
    str     w9, [x19, #COEF]
    str     wzr, [x19, #I2]             // (whether any other amount turns up)
    mov     x29, #1                     // the rest: runs of zeros and the amounts between them, in zigzag order
2:  cmp     x29, #64
    b.ge    4f
    cbnz    w26, 4f
    ldr     w9, [x28, #C_AC]
    add     w9, w9, #4
    HUFFOF  w9
    bl      symbol
    lsr     w9, w0, #4
    ands    w0, w0, #15
    b.ne    3f
    cmp     w9, #15
    b.ne    4f
    add     x29, x29, #16
    b       2b
3:  add     x29, x29, x9
    cmp     x29, #63
    b.le    5f
    mov     w26, #1
    b       4f
5:  str     w0, [x19, #TMP]
    bl      getbits
    ldr     w11, [x19, #TMP]
    EXTEND  w11
    ldrh    w10, [x27, x29, lsl #1]
    mul     w0, w0, w10
    adr     x10, t_zigzag
    ldrb    w10, [x10, x29]
    add     x11, x19, #COEF
    str     w0, [x11, x10, lsl #2]
    mov     w9, #1
    str     w9, [x19, #I2]
    add     x29, x29, #1
    b       2b
4:  cbnz    w26, c_bad
    ldr     w9, [x28, #C_PW]            // where the square goes in the component's plane
    str     w9, [x19, #STRIDE]
    ldr     w10, [x19, #ROW]
    ldr     w11, [x28, #C_V]
    ldr     w12, [x19, #BY]
    madd    w10, w10, w11, w12
    umull   x10, w10, w9
    lsl     x10, x10, #3
    ldr     w11, [x19, #COL]
    ldr     w12, [x28, #C_H]
    ldr     w13, [x19, #BX]
    madd    w11, w11, w12, w13
    add     x10, x10, x11, lsl #3
    ldr     x11, [x28, #C_AT]
    add     x10, x10, x11
    ldr     x11, [x19, #PLANE]
    add     x28, x11, x10
    ldr     w9, [x19, #I2]
    cbnz    w9, 6f
    ldr     w9, [x19, #COEF]            // a flat square: only its average. The transform would give every dot this value.
    lsl     w9, w9, #12
    add     w9, w9, #512
    asr     w9, w9, #10
    lsl     w9, w9, #12
    mov     w10, #0x1000000
    add     w10, w10, #0x10000
    add     w9, w9, w10
    asr     w9, w9, #17
    cmp     w9, #0
    csel    w9, wzr, w9, lt
    cmp     w9, #255
    mov     w10, #255
    csel    w9, w10, w9, gt
    ldr     x10, =0x0101010101010101
    mul     x9, x9, x10
    ldr     w10, [x19, #STRIDE]
    mov     w11, #8
7:  str     x9, [x28]
    add     x28, x28, x10
    subs    w11, w11, #1
    b.ne    7b
    b       8f
6:  add     x27, x19, #COEF
    bl      idct
8:  ldr     w9, [x19, #CI]
    COMP    x28, x9
    ldr     w9, [x19, #BX]
    add     w9, w9, #1
    str     w9, [x19, #BX]
    b       c_bx
c_by_next:
    ldr     w9, [x19, #BY]
    add     w9, w9, #1
    str     w9, [x19, #BY]
    b       c_by
c_comp_next:
    ldr     w9, [x19, #CI]
    add     w9, w9, #1
    str     w9, [x19, #CI]
    b       c_comp
c_unit_done:
    ldr     w9, [x19, #DONE]
    add     w9, w9, #1
    str     w9, [x19, #DONE]
    ldr     w9, [x19, #COL]
    add     w9, w9, #1
    str     w9, [x19, #COL]
    b       c_col
c_row_next:
    ldr     w9, [x19, #ROW]
    add     w9, w9, #1
    str     w9, [x19, #ROW]
    b       c_row
c_colour:                               // the planes become dots: brightness alone, or brightness and two colour differences
    ldr     x0, [x19, #SURF]
    ldr     x1, [x19, #PLANE]
    ldr     w2, [x19, #HEIGHT]
    ldr     w3, [x0, #8]
    cmp     w2, w3
    csel    w2, w3, w2, hi              // rows to write
    ldr     w3, [x19, #WIDTH]
    ldr     w4, [x0, #4]
    cmp     w3, w4
    csel    w3, w4, w3, hi              // dots in a row
    ldr     w4, [x19, #HMAX]
    ldr     w5, [x19, #VMAX]
    ldr     w6, [x19, #COMPS]
    mov     x7, #0                      // dots written
    mov     w8, #0
c_y:
    cmp     w8, w2
    b.hs    c_done
    ldr     w9, [x0, #12]
    umull   x9, w8, w9
    add     x9, x9, x0
    add     x9, x9, #64                 // the surface's row
    ldr     w10, [x19, #(C0 + C_V)]
    mul     w10, w10, w8
    udiv    w10, w10, w5
    ldr     w11, [x19, #(C0 + C_PW)]
    umull   x10, w10, w11
    ldr     x11, [x19, #(C0 + C_AT)]
    add     x10, x10, x11
    add     x10, x1, x10                // the brightness row
    udiv    w11, w8, w5
    ldr     w12, [x19, #(C0 + 48 + C_PW)]
    umull   x12, w11, w12
    ldr     x13, [x19, #(C0 + 48 + C_AT)]
    add     x12, x12, x13
    add     x12, x1, x12                // the two colour rows
    ldr     w13, [x19, #(C0 + 96 + C_PW)]
    umull   x13, w11, w13
    ldr     x14, [x19, #(C0 + 96 + C_AT)]
    add     x13, x13, x14
    add     x13, x1, x13
    ldr     w14, [x19, #(C0 + C_H)]     // sampling is 1 or 2 each way, so the divisions along a row are shifts
    cmp     w14, w4
    cset    w14, ne
    sub     w30, w4, #1
    mov     w11, #0
    ldr     w16, =91881                 // eight dots at a time while eight remain; the same whole-number arithmetic
    dup     v24.4s, w16
    ldr     w16, =22554
    dup     v25.4s, w16
    ldr     w16, =46802
    dup     v26.4s, w16
    ldr     w16, =116130
    dup     v27.4s, w16
    mov     w16, #32768
    dup     v28.4s, w16
    mov     w16, #128
    dup     v29.8h, w16
    movi    v3.8b, #255
c_x8:
    add     w16, w11, #8
    cmp     w16, w3
    b.hi    c_x
    ldr     d16, [x10, x11]             // brightness
    cmp     w6, #1
    b.ne    1f
    mov     v0.8b, v16.8b
    mov     v1.8b, v16.8b
    mov     v2.8b, v16.8b
    b       3f
1:  lsr     w16, w11, w30
    cbz     w30, 2f
    ldr     s17, [x12, x16]             // colour at half rate: each value serves two dots
    ldr     s18, [x13, x16]
    zip1    v17.8b, v17.8b, v17.8b
    zip1    v18.8b, v18.8b, v18.8b
    b       4f
2:  ldr     d17, [x12, x16]
    ldr     d18, [x13, x16]
4:  uxtl    v16.8h, v16.8b
    uxtl    v17.8h, v17.8b
    uxtl    v18.8h, v18.8b
    sub     v17.8h, v17.8h, v29.8h      // blue difference
    sub     v18.8h, v18.8h, v29.8h      // red difference
    uxtl    v19.4s, v16.4h
    sxtl    v20.4s, v17.4h
    sxtl    v21.4s, v18.4h
    .macro  MIX r, g, b
    shl     v19.4s, v19.4s, #16
    add     v19.4s, v19.4s, v28.4s
    mov     \r\().16b, v19.16b
    mla     \r\().4s, v21.4s, v24.4s
    mov     \g\().16b, v19.16b
    mls     \g\().4s, v20.4s, v25.4s
    mls     \g\().4s, v21.4s, v26.4s
    mov     \b\().16b, v19.16b
    mla     \b\().4s, v20.4s, v27.4s
    sshr    \r\().4s, \r\().4s, #16
    sshr    \g\().4s, \g\().4s, #16
    sshr    \b\().4s, \b\().4s, #16
    sqxtun  \r\().4h, \r\().4s
    sqxtun  \g\().4h, \g\().4s
    sqxtun  \b\().4h, \b\().4s
    .endm
    MIX     v0, v1, v2                  // the first four dots
    uxtl2   v19.4s, v16.8h
    sxtl2   v20.4s, v17.8h
    sxtl2   v21.4s, v18.8h
    MIX     v4, v5, v6                  // the other four
    mov     v0.d[1], v4.d[0]
    mov     v1.d[1], v5.d[0]
    mov     v2.d[1], v6.d[0]
    uqxtn   v0.8b, v0.8h                // squeezed into what a dot can hold
    uqxtn   v1.8b, v1.8h
    uqxtn   v2.8b, v2.8h
3:  add     x16, x9, x11, lsl #2
    st4     {v0.8b-v3.8b}, [x16]
    add     x7, x7, #8
    add     w11, w11, #8
    b       c_x8
c_x:
    cmp     w11, w3
    b.hs    c_y_next
    lsr     w15, w11, w14
    ldrb    w15, [x10, x15]
    cmp     w6, #1
    b.ne    1f
    orr     w15, w15, w15, lsl #8
    orr     w15, w15, w15, lsl #8
    b       2f
1:  lsr     w16, w11, w30
    ldrb    w17, [x12, x16]
    sub     w17, w17, #128              // blue difference
    ldrb    w16, [x13, x16]
    sub     w16, w16, #128              // red difference
    lsl     w15, w15, #16
    add     w15, w15, #32768
    .macro  CHANNEL reg
    asr     \reg, \reg, #16
    cmp     \reg, #0
    csel    \reg, wzr, \reg, lt
    cmp     \reg, #255
    mov     w29, #255
    csel    \reg, w29, \reg, gt
    .endm
    ldr     w29, =91881
    madd    w28, w16, w29, w15
    CHANNEL w28                         // red
    ldr     w29, =22554
    msub    w27, w17, w29, w15
    ldr     w29, =46802
    msub    w27, w16, w29, w27
    CHANNEL w27                         // green
    ldr     w29, =116130
    madd    w15, w17, w29, w15
    CHANNEL w15                         // blue
    orr     w15, w28, w15, lsl #16
    orr     w15, w15, w27, lsl #8
2:  orr     w15, w15, #0xff000000
    str     w15, [x9, x11, lsl #2]
    add     x7, x7, #1
    add     w11, w11, #1
    b       c_x
c_y_next:
    add     w8, w8, #1
    b       c_y
c_done:
    mov     x0, x7
    b       c_out
c_bad:
    mov     x0, #-1
c_out:
    LEAVE
    .ltorg
t_zigzag:
    .byte   0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48, 41, 34, 27, 20, 13, 6, 7, 14, 21, 28
    .byte   35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15, 23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62, 63
    .balign 4

// ---- progressive: the amounts arrive over several scans (a coarse version, then more patterns, then finer values), so they are
// kept as 16-bit numbers in the scratch block after the planes until the last scan, and transformed once ----

// REFINE: the amount at x9 (not zero) gains one finer bit, if the next bit says so and it has not that bit yet. w13 is the bit's worth.
    .macro  REFINE
    mov     x14, x9                     // (reading bits uses x9-x12 and x16)
    mov     w0, #1
    bl      getbits
    ldrsh   w10, [x14]
    cbz     w0, 73f
    tst     w10, w13
    b.ne    73f
    add     w11, w10, w13
    sub     w12, w10, w13
    cmp     w10, #0
    csel    w10, w11, w12, ge
    strh    w10, [x14]
73:
    .endm
// ZZ: the address of the amount at zigzag position x29 of the square x27 -> x9
    .macro  ZZ
    adr     x9, t_zigzag
    ldrb    w9, [x9, x29]
    add     x9, x27, x9, lsl #1
    .endm
// prog_block: one square (x0) of the component x1 in the scan now being read (SS, SE, AH, AL, EOB in the frame)
prog_block:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    mov     x27, x0
    mov     x28, x1
    ldr     w9, [x19, #SS]
    cbnz    w9, b_rest
    ldr     w9, [x19, #AH]              // first amounts: a first pass, or one finer bit
    cbnz    w9, 1f
    ldr     w9, [x28, #C_DC]
    HUFFOF  w9
    bl      symbol
    cmp     w0, #11
    b.ls    2f
    mov     w26, #1
    b       b_out
2:  mov     w29, w0
    bl      getbits
    EXTEND  w29
    ldr     w9, [x28, #C_PRED]
    add     w9, w9, w0
    str     w9, [x28, #C_PRED]
    ldr     w10, [x19, #AL]
    lsl     w9, w9, w10
    strh    w9, [x27]
    b       b_out
1:  mov     w0, #1
    bl      getbits
    cbz     w0, b_out
    ldr     w10, [x19, #AL]
    mov     w9, #1
    lsl     w9, w9, w10
    ldrh    w10, [x27]
    orr     w10, w10, w9
    strh    w10, [x27]
    b       b_out
b_rest:
    ldr     w9, [x19, #AH]
    cbnz    w9, b_refine
    ldr     w9, [x19, #EOB]             // the other amounts, first pass. A count of squares with nothing more may be running.
    cmp     w9, #0
    b.le    1f
    sub     w9, w9, #1
    str     w9, [x19, #EOB]
    b       b_out
1:  ldr     w29, [x19, #SS]
2:  ldr     w9, [x19, #SE]
    cmp     w29, w9
    b.gt    b_out
    cbnz    w26, b_out
    ldr     w9, [x28, #C_AC]
    add     w9, w9, #4
    HUFFOF  w9
    bl      symbol
    lsr     w9, w0, #4
    ands    w0, w0, #15
    b.ne    4f
    cmp     w9, #15
    b.hs    3f
    mov     w10, #1                     // so many squares with nothing more, this one included
    lsl     w10, w10, w9
    sub     w10, w10, #1
    str     w10, [x19, #EOB]
    cbz     w9, b_out
    mov     w0, w9
    bl      getbits
    ldr     w10, [x19, #EOB]
    add     w10, w10, w0
    str     w10, [x19, #EOB]
    b       b_out
3:  add     w29, w29, #16
    b       2b
4:  add     w29, w29, w9
    ldr     w9, [x19, #SE]
    cmp     w29, w9
    b.le    5f
    mov     w26, #1
    b       b_out
5:  str     w0, [x19, #TMP]
    bl      getbits
    ldr     w11, [x19, #TMP]
    EXTEND  w11
    ldr     w10, [x19, #AL]
    lsl     w0, w0, w10
    ZZ
    strh    w0, [x9]
    add     w29, w29, #1
    b       2b
b_refine:                               // the other amounts, one finer bit each
    ldr     w29, [x19, #SS]
    ldr     w9, [x19, #EOB]
    cbnz    w9, b_run
1:  ldr     w9, [x19, #SE]
    cmp     w29, w9
    b.gt    b_run
    cbnz    w26, b_run
    ldr     w9, [x28, #C_AC]
    add     w9, w9, #4
    HUFFOF  w9
    bl      symbol
    lsr     w9, w0, #4                  // how many zero amounts to pass first
    and     w0, w0, #15
    str     w9, [x19, #TMP]
    str     wzr, [x19, #TMP2]           // a new amount to place after them, if any
    cbz     w0, 3f
    cmp     w0, #1
    b.eq    2f
    mov     w26, #1
    b       b_out
2:  mov     w0, #1
    bl      getbits
    ldr     w10, [x19, #AL]
    mov     w9, #1
    lsl     w9, w9, w10
    cmp     w0, #0
    cneg    w9, w9, eq
    str     w9, [x19, #TMP2]
    b       4f
3:  cmp     w9, #15
    b.eq    4f
    mov     w10, #1
    lsl     w10, w10, w9
    str     w10, [x19, #EOB]
    cbz     w9, b_run
    mov     w0, w9
    bl      getbits
    ldr     w10, [x19, #EOB]
    add     w10, w10, w0
    str     w10, [x19, #EOB]
    b       b_run
4:  ldr     w9, [x19, #SE]              // pass over amounts: those already known gain a bit; zeros are counted
    cmp     w29, w9
    b.gt    6f
    ZZ
    ldrsh   w10, [x9]
    cbz     w10, 5f
    ldr     w13, [x19, #AL]
    mov     w10, #1
    lsl     w13, w10, w13
    REFINE
    add     w29, w29, #1
    b       4b
5:  ldr     w10, [x19, #TMP]
    subs    w10, w10, #1
    str     w10, [x19, #TMP]
    b.mi    6f
    add     w29, w29, #1
    b       4b
6:  ldr     w10, [x19, #TMP2]
    cbz     w10, 7f
    ldr     w9, [x19, #SE]
    cmp     w29, w9
    b.le    8f
    mov     w26, #1
    b       b_out
8:  ZZ
    strh    w10, [x9]
7:  add     w29, w29, #1
    b       1b
b_run:
    ldr     w9, [x19, #EOB]
    cmp     w9, #0
    b.le    b_out
1:  ldr     w9, [x19, #SE]
    cmp     w29, w9
    b.gt    3f
    ZZ
    ldrsh   w10, [x9]
    cbz     w10, 2f
    ldr     w13, [x19, #AL]
    mov     w10, #1
    lsl     w13, w10, w13
    REFINE
2:  add     w29, w29, #1
    b       1b
3:  ldr     w9, [x19, #EOB]
    sub     w9, w9, #1
    str     w9, [x19, #EOB]
b_out:
    ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// prog_scan: one scan, its header from x0 to x1 and its data after -> x0 1 or 0
prog_scan:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    mov     x27, x0
    str     x1, [x19, #P_END]
    bl      rd8
    str     w0, [x19, #NS]
    cmp     w0, #1
    b.lt    n_no
    ldr     w9, [x19, #COMPS]
    cmp     w0, w9
    b.gt    n_no
    add     x9, x27, #4
    add     x9, x9, x0, lsl #1
    ldr     x10, [x19, #P_END]
    cmp     x9, x10
    b.hi    n_no
    mov     x28, #0
1:  ldr     w9, [x19, #NS]              // which components, and their code tables
    cmp     w28, w9
    b.hs    4f
    add     x0, x27, #1
    add     x0, x0, x28, lsl #1
    bl      rd8
    mov     w12, w0
    add     x0, x27, #2
    add     x0, x0, x28, lsl #1
    bl      rd8
    mov     w13, #-1
    mov     x14, #0
2:  ldr     w9, [x19, #COMPS]
    cmp     w14, w9
    b.hs    3f
    COMP    x15, x14
    ldr     w9, [x15, #C_ID]
    cmp     w9, w12
    csel    w13, w14, w13, eq
    add     x14, x14, #1
    b       2b
3:  add     x15, x19, #CIDX0
    str     w13, [x15, x28, lsl #2]
    tbnz    w13, #31, n_no
    lsr     w9, w0, #4
    and     w10, w0, #15
    cmp     w9, #3
    b.hi    n_no
    cmp     w10, #3
    b.hi    n_no
    COMP    x15, x13
    str     w9, [x15, #C_DC]
    str     w10, [x15, #C_AC]
    str     wzr, [x15, #C_PRED]
    add     x28, x28, #1
    b       1b
4:  ldr     w28, [x19, #NS]
    add     x28, x27, x28, lsl #1
    add     x0, x28, #1
    bl      rd8
    str     w0, [x19, #SS]
    add     x0, x28, #2
    bl      rd8
    str     w0, [x19, #SE]
    add     x0, x28, #3
    bl      rd8
    lsr     w9, w0, #4
    and     w10, w0, #15
    str     w9, [x19, #AH]
    str     w10, [x19, #AL]
    cbnz    w26, n_no
    ldr     w11, [x19, #SS]
    ldr     w12, [x19, #SE]
    cmp     w11, w12
    b.gt    n_no
    cmp     w12, #63
    b.gt    n_no
    cmp     w10, #13
    b.gt    n_no
    ldr     w13, [x19, #NS]
    cbnz    w11, 5f
    cbnz    w12, n_no
    b       6f
5:  cmp     w13, #1
    b.ne    n_no
6:  mov     x28, #0                     // the tables this scan uses must have been given
7:  ldr     w9, [x19, #NS]
    cmp     w28, w9
    b.hs    10f
    add     x15, x19, #CIDX0
    ldr     w13, [x15, x28, lsl #2]
    COMP    x15, x13
    ldr     w11, [x19, #SS]
    cbnz    w11, 8f
    ldr     w9, [x19, #AH]
    cbnz    w9, 9f
    ldr     w9, [x15, #C_DC]
    b       11f
8:  ldr     w9, [x15, #C_AC]
    add     w9, w9, #4
11: mov     w10, #280
    umull   x9, w9, w10
    add     x9, x9, x19
    add     x9, x9, #HUFF
    ldr     w9, [x9, #H_PRESENT]
    cbz     w9, n_no
9:  add     x28, x28, #1
    b       7b
10: ldr     x22, [x19, #P_END]
    mov     x23, #0
    mov     w24, #0
    mov     w25, #0
    str     wzr, [x19, #LM]
    str     wzr, [x19, #EOB]
    ldr     w13, [x19, #CIDX0]
    COMP    x15, x13
    str     x15, [x19, #ONE]
    ldr     w9, [x19, #WIDTH]           // squares across and down, for a scan of one component
    ldr     w10, [x15, #C_H]
    ldr     w11, [x19, #HMAX]
    madd    w9, w9, w10, w11
    sub     w9, w9, #1
    udiv    w9, w9, w11
    add     w9, w9, #7
    lsr     w9, w9, #3
    str     w9, [x19, #BW]
    ldr     w12, [x19, #HEIGHT]
    ldr     w10, [x15, #C_V]
    ldr     w11, [x19, #VMAX]
    madd    w12, w12, w10, w11
    sub     w12, w12, #1
    udiv    w12, w12, w11
    add     w12, w12, #7
    lsr     w12, w12, #3
    str     w12, [x19, #BH]
    mul     w9, w9, w12
    ldr     w10, [x19, #NS]
    cmp     w10, #1
    b.eq    12f
    ldr     w9, [x19, #MX]
    ldr     w10, [x19, #MY]
    mul     w9, w9, w10
12: str     w9, [x19, #TOTAL]
    str     wzr, [x19, #NN]
n_unit:
    ldr     w9, [x19, #NN]
    ldr     w10, [x19, #TOTAL]
    cmp     w9, w10
    b.hs    n_yes
    ldr     w10, [x19, #RESTART]
    cbz     w10, 3f
    cbz     w9, 3f
    udiv    w11, w9, w10
    msub    w11, w11, w10, w9
    cbnz    w11, 3f
    bl      restart
    mov     x28, #0
1:  ldr     w9, [x19, #NS]
    cmp     w28, w9
    b.hs    2f
    add     x15, x19, #CIDX0
    ldr     w13, [x15, x28, lsl #2]
    COMP    x15, x13
    str     wzr, [x15, #C_PRED]
    add     x28, x28, #1
    b       1b
2:  str     wzr, [x19, #EOB]
3:  ldr     w9, [x19, #NS]
    cmp     w9, #1
    b.ne    n_many
    ldr     x1, [x19, #ONE]             // one component: its squares in rows, as many as the picture needs
    ldr     w9, [x19, #NN]
    ldr     w10, [x19, #BW]
    udiv    w11, w9, w10
    msub    w12, w11, w10, w9
    ldr     w13, [x1, #C_PW]
    lsr     w13, w13, #3
    umaddl  x11, w11, w13, x12
    ldr     w13, [x19, #CIDX0]
    add     x14, x19, #CAT0
    ldr     x14, [x14, x13, lsl #3]
    add     x11, x14, x11, lsl #6
    ldr     x0, [x19, #CO]
    add     x0, x0, x11, lsl #1
    bl      prog_block
    b       n_next
n_many:                                 // several components: unit by unit, each component's squares within it
    str     wzr, [x19, #CI]
4:  ldr     w9, [x19, #CI]
    ldr     w10, [x19, #NS]
    cmp     w9, w10
    b.hs    n_next
    str     wzr, [x19, #BY]
5:  ldr     w9, [x19, #CI]
    add     x15, x19, #CIDX0
    ldr     w28, [x15, x9, lsl #2]
    COMP    x1, x28
    ldr     w9, [x19, #BY]
    ldr     w10, [x1, #C_V]
    cmp     w9, w10
    b.ge    8f
    str     wzr, [x19, #BX]
6:  ldr     w9, [x19, #BX]
    ldr     w10, [x1, #C_H]
    cmp     w9, w10
    b.ge    7f
    ldr     w11, [x19, #NN]
    ldr     w12, [x19, #MX]
    udiv    w13, w11, w12
    msub    w14, w13, w12, w11
    ldr     w15, [x1, #C_V]
    ldr     w16, [x19, #BY]
    madd    w13, w13, w15, w16
    ldr     w15, [x1, #C_PW]
    lsr     w15, w15, #3
    umull   x13, w13, w15
    madd    w14, w14, w10, w9
    add     x13, x13, x14
    add     x14, x19, #CAT0
    ldr     x14, [x14, x28, lsl #3]
    add     x13, x14, x13, lsl #6
    ldr     x0, [x19, #CO]
    add     x0, x0, x13, lsl #1
    bl      prog_block
    ldr     w9, [x19, #CI]
    add     x15, x19, #CIDX0
    ldr     w28, [x15, x9, lsl #2]
    COMP    x1, x28
    ldr     w9, [x19, #BX]
    add     w9, w9, #1
    str     w9, [x19, #BX]
    b       6b
7:  ldr     w9, [x19, #BY]
    add     w9, w9, #1
    str     w9, [x19, #BY]
    b       5b
8:  ldr     w9, [x19, #CI]
    add     w9, w9, #1
    str     w9, [x19, #CI]
    b       4b
n_next:
    cbnz    w26, n_no
    ldr     w9, [x19, #NN]
    add     w9, w9, #1
    str     w9, [x19, #NN]
    b       n_unit
n_yes:
    mov     x0, #1
    b       n_out
n_no:
    mov     x0, #0
n_out:
    ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// progressive: runs every scan, then turns the finished amounts into the planes -> x0 1 or 0
progressive:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    ldr     x9, [x19, #NEEDP]
    add     x9, x9, #7
    and     x9, x9, #-8                 // where the amounts are kept: after the planes
    mov     x10, #0
    mov     x11, #0
1:  ldr     w12, [x19, #COMPS]
    cmp     w11, w12
    b.hs    2f
    add     x13, x19, #CAT0
    str     x10, [x13, x11, lsl #3]
    COMP    x13, x11
    ldr     w14, [x13, #C_PW]
    ldr     w15, [x13, #C_PH]
    lsr     w14, w14, #3
    lsr     w15, w15, #3
    umull   x14, w14, w15
    add     x10, x10, x14, lsl #6
    add     x11, x11, #1
    b       1b
2:  ldr     x12, [x19, #SCRATCH]
    ldr     x13, [x12, #16]
    sub     x13, x13, #64
    add     x14, x9, x10, lsl #1
    cmp     x13, x14
    b.lo    p_no
    add     x12, x12, #64
    add     x12, x12, x9
    str     x12, [x19, #CO]
    cbz     x10, 4f
3:  strh    wzr, [x12], #2
    subs    x10, x10, #1
    b.ne    3b
4:  str     wzr, [x19, #SCANS]
    ldr     x27, [x19, #SCAN]
p_part:
    add     x9, x27, #4
    cmp     x9, x21
    b.hi    p_end
    ldrb    w9, [x20, x27]
    cmp     w9, #0xff
    b.ne    p_no
    add     x9, x27, #1
    ldrb    w29, [x20, x9]
    cmp     w29, #0xff
    b.ne    1f
    add     x27, x27, #1
    b       p_part
1:  cmp     w29, #0xd9
    b.eq    p_end
    add     x9, x27, #2
    ldrh    w10, [x20, x9]
    rev16   w10, w10
    add     x28, x9, x10                // where this part ends
    cmp     w10, #2
    b.lo    p_end
    cmp     x28, x21
    b.hi    p_end
    add     x0, x27, #4
    cmp     w29, #0xc4
    b.ne    2f
    mov     x1, x28
    bl      dht
    cbnz    w26, p_no
    b       p_next
2:  cmp     w29, #0xdd
    b.ne    3f
    bl      rd16
    str     w0, [x19, #RESTART]
    b       p_next
3:  cmp     w29, #0xda
    b.ne    p_next
    mov     x1, x28
    bl      prog_scan
    cbz     x0, p_no
    ldr     w9, [x19, #SCANS]
    add     w9, w9, #1
    str     w9, [x19, #SCANS]
    mov     x27, x28                    // on to the next marker that is not a restart point
4:  add     x9, x27, #1
    cmp     x9, x21
    b.hs    p_part
    ldrb    w10, [x20, x27]
    cmp     w10, #0xff
    b.ne    5f
    ldrb    w10, [x20, x9]
    cbz     w10, 5f
    sub     w10, w10, #0xd0
    cmp     w10, #7
    b.hi    p_part
5:  add     x27, x27, #1
    b       4b
p_next:
    mov     x27, x28
    b       p_part
p_end:
    ldr     w9, [x19, #SCANS]
    cbz     w9, p_no
    str     wzr, [x19, #CI]             // every square: its amounts times the step sizes, transformed into its plane
p_comp:
    ldr     w9, [x19, #CI]
    ldr     w10, [x19, #COMPS]
    cmp     w9, w10
    b.hs    p_yes
    str     wzr, [x19, #BY]
p_by:
    ldr     w9, [x19, #CI]
    COMP    x12, x9
    ldr     w10, [x12, #C_PH]
    lsr     w10, w10, #3
    ldr     w11, [x19, #BY]
    cmp     w11, w10
    b.hs    p_comp_next
    str     wzr, [x19, #BX]
p_bx:
    ldr     w9, [x19, #CI]
    COMP    x12, x9
    ldr     w10, [x12, #C_PW]
    str     w10, [x19, #STRIDE]
    lsr     w13, w10, #3                // squares across
    ldr     w14, [x19, #BX]
    cmp     w14, w13
    b.hs    p_by_next
    ldr     w11, [x19, #BY]
    umaddl  x15, w11, w13, x14
    add     x16, x19, #CAT0
    ldr     x16, [x16, x9, lsl #3]
    add     x15, x16, x15, lsl #6
    ldr     x16, [x19, #CO]
    add     x15, x16, x15, lsl #1       // the square's amounts
    ldr     w16, [x12, #C_Q]
    add     x17, x19, #QUANT
    add     x17, x17, x16, lsl #7
    add     x27, x19, #COEF
    adr     x16, t_zigzag
    mov     x0, #0
1:  ldrb    w1, [x16, x0]
    ldrsh   w2, [x15, x1, lsl #1]
    ldrh    w3, [x17, x0, lsl #1]
    mul     w2, w2, w3
    str     w2, [x27, x1, lsl #2]
    add     x0, x0, #1
    cmp     x0, #64
    b.lo    1b
    umull   x15, w11, w10
    lsl     x15, x15, #3
    add     x15, x15, x14, lsl #3
    ldr     x16, [x12, #C_AT]
    add     x15, x15, x16
    ldr     x16, [x19, #PLANE]
    add     x28, x16, x15
    bl      idct
    ldr     w9, [x19, #BX]
    add     w9, w9, #1
    str     w9, [x19, #BX]
    b       p_bx
p_by_next:
    ldr     w9, [x19, #BY]
    add     w9, w9, #1
    str     w9, [x19, #BY]
    b       p_by
p_comp_next:
    ldr     w9, [x19, #CI]
    add     w9, w9, #1
    str     w9, [x19, #CI]
    b       p_comp
p_yes:
    mov     x0, #1
    b       p_out
p_no:
    mov     x0, #0
p_out:
    ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
