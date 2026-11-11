// listen-step, written by hand (ARM64): is this block of microphone sound voice. The meaning is listen-step/intent.md; the recorded
// checks are the judge. Entries: x0 state (512 bytes), x1 samples (16-bit), x2 how many, x3 flags, x4 call table.
// Loudness and peak come from other pieces through sockets 0 and 2, called as (samples, how many, 0, table).
// Fractions are IEEE doubles, each operation rounded on its own, in the order the meaning states them.
// State: 0 version, 8 floor, 16 level, 24 blocks, 32 place in the fine history, 64 fifty fine levels.
    .text
    .global migrate
    .global step
    .equ HALF, 0x3fe0000000000000
    .equ RISE_SLOW, 0x3f689374bc6a7efa
    .equ RISE_FAST, 0x3f847ae147ae147b
    .equ KEEP_SLOW, 0x3fefe76c8b439581
    .equ KEEP_FAST, 0x3fefae147ae147ae
    .equ LOW, 0x3f40624dd2f1a9fc
    .equ X35, 0x400c000000000000
    .equ BAR, 0x3f889374bc6a7efa
    .equ X16, 0x3ff999999999999a
    .equ D320, 0x4074000000000000
    .equ MARK, 0x3fd6666666666666
    .equ FRESH, 0x3f70624dd2f1a9fc
    .equ SCALE, 0x3f00000000000000
    .macro  CONST d, name
    ldr     x9, =\name
    fmov    \d, x9
    .endm
migrate:
    ldr     w9, [x0]
    cmp     w9, #2
    b.eq    3f
    cbnz    w9, 1f
    str     wzr, [x0, #4]               // never used: a fresh one
    ldr     x10, =FRESH
    stp     x10, xzr, [x0, #8]
    str     xzr, [x0, #24]
    b       2f
1:  cmp     w9, #1
    b.eq    2f
    mov     x0, #0
    ret
2:  mov     w9, #2
    str     w9, [x0]
    add     x10, x0, #32                // everything new in this layout, cleared
    mov     x11, #60
4:  str     xzr, [x10], #8
    subs    x11, x11, #1
    b.ne    4b
3:  mov     x0, #2
    ret

// loudness: of the x1 samples at x0, as a fraction of full scale, x1 counted as d0 -> d0
    .macro  LOUDNESS
    mov     x2, #0
    mov     x3, x23
    ldr     x9, [x23]
    blr     x9
    scvtf   d0, x0
    .endm
step:
    stp     x29, x30, [sp, #-112]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     d8, d9, [sp, #80]
    stp     d10, d11, [sp, #96]
    mov     x19, x0
    mov     x20, x1
    mov     x21, x2
    mov     x22, x3
    mov     x23, x4
    mov     x0, x20
    mov     x1, x21
    LOUDNESS
    mov     x9, #1
    cmp     x21, #1
    csel    x9, x21, x9, gt
    scvtf   d1, x9
    fdiv    d0, d0, d1
    fsqrt   d0, d0
    CONST   d10, SCALE
    fmul    d8, d0, d10                 // d8 the level of this block
    ldr     d1, [x19, #8]               // the floor: falls quickly to a quieter block, rises slowly to a louder one
    fcmp    d8, d1
    b.mi    1f
    CONST   d2, KEEP_FAST
    CONST   d3, RISE_FAST
    tbz     x22, #1, 2f
    CONST   d2, KEEP_SLOW
    CONST   d3, RISE_SLOW
    b       2f
1:  CONST   d2, HALF
    fmov    d3, d2
2:  fmul    d1, d1, d2
    fmul    d3, d8, d3
    fadd    d1, d1, d3
    CONST   d2, LOW
    fcmp    d1, d2
    b.pl    3f
    fmov    d1, d2
3:  stp     d1, d8, [x19, #8]
    ldr     x9, [x19, #24]
    add     x9, x9, #1
    str     x9, [x19, #24]
    CONST   d2, X35                     // the bar a block must clear to count as voice
    fmul    d1, d1, d2
    CONST   d2, BAR
    fcmp    d1, d2
    b.gt    4f
    fmov    d1, d2
4:  tbz     x22, #0, 5f
    CONST   d2, X16
    fmul    d1, d1, d2
5:  fcmp    d8, d1
    cset    x24, gt
    tbz     x22, #1, 7f
    mov     x25, #0                     // while recording: the fine history, one level for every 320 samples
6:  add     x9, x25, #320
    cmp     x9, x21
    b.gt    7f
    add     x0, x20, x25, lsl #1
    mov     x1, #320
    LOUDNESS
    CONST   d1, D320
    fdiv    d0, d0, d1
    fsqrt   d0, d0
    fmul    d0, d0, d10
    ldr     x9, [x19, #32]
    add     x10, x9, #1
    str     x10, [x19, #32]
    mov     x10, #50
    sdiv    x11, x9, x10
    msub    x9, x11, x10, x9
    add     x10, x19, #64
    str     d0, [x10, x9, lsl #3]
    add     x25, x25, #320
    b       6b
7:  movi    d0, #0                      // the rhythm of speech: the level climbing past a third of its top at least twice
    add     x10, x19, #64
    mov     x9, #0
8:  ldr     d1, [x10, x9, lsl #3]
    fcmp    d1, d0
    b.le    9f
    fmov    d0, d1
9:  add     x9, x9, #1
    cmp     x9, #50
    b.lo    8b
    CONST   d1, MARK
    fmul    d0, d0, d1
    ldr     x12, [x19, #32]
    mov     x13, #50
    mov     x14, #0                     // climbs
    mov     x9, #1
10: add     x11, x12, x9
    sub     x15, x11, #1
    sdiv    x16, x15, x13
    msub    x15, x16, x13, x15
    sdiv    x16, x11, x13
    msub    x11, x16, x13, x11
    ldr     d1, [x10, x15, lsl #3]
    ldr     d2, [x10, x11, lsl #3]
    fcmp    d1, d0
    b.hi    11f
    fcmp    d2, d0
    b.le    11f
    add     x14, x14, #1
11: add     x9, x9, #1
    cmp     x9, #50
    b.lo    10b
    cmp     x14, #2
    b.lt    12f
    orr     x24, x24, #2
12: mov     x0, x20
    mov     x1, x21
    mov     x2, #0
    mov     x3, x23
    ldr     x9, [x23, #16]
    blr     x9
    mov     x9, #32700
    cmp     x0, x9
    b.lt    13f
    orr     x24, x24, #4                // the microphone hit its ceiling in this block
13: mov     x0, x24
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     d8, d9, [sp, #80]
    ldp     d10, d11, [sp, #96]
    ldp     x29, x30, [sp], #112
    ret
