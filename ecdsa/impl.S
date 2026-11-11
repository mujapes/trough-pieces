// ecdsa, written by hand (ARM64): checks ECDSA signatures on P-256 and P-384. The meaning is ecdsa/intent.md; the recorded checks
// are the judge. Laid out by tools/ecdsa_asm.py (frame offsets, constants, and the point formulas' three-operand lines).
// Entry: x0 block (unused), x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Numbers are 64-bit limbs, lowest first, 4 or 6 of them, in 48-byte places in the frame. Through the entry: x19 the frame, x20 the
// call table, x21 how many limbs, x22 the field in use (modulus, 2^(128 limbs), 2^(64 limbs), minus one over the modulus),
// x23 the curve's bytes. x24-x28 are free for the routines: x25 and x26 point at the points being worked on.
    .text
    .global verify
    .equ BX, 96
    .equ BY, 104
    .equ BR, 112
    .equ BS, 120
    .equ BD, 128
    .equ IDX, 136
    .equ FP, 144
    .equ FN, 304
    .equ T, 464
    .equ E, 528
    .equ NX, 576
    .equ NY, 624
    .equ NR, 672
    .equ NS, 720
    .equ NZ, 768
    .equ CB, 816
    .equ MX, 864
    .equ MY, 912
    .equ THREE, 960
    .equ L, 1008
    .equ RT, 1056
    .equ W, 1104
    .equ U1, 1152
    .equ U2, 1200
    .equ PLAIN1, 1248
    .equ A1, 1296
    .equ A2, 1344
    .equ A3, 1392
    .equ A4, 1440
    .equ A5, 1488
    .equ A6, 1536
    .equ A7, 1584
    .equ A8, 1632
    .equ ZI, 1680
    .equ AX, 1728
    .equ G, 1776
    .equ Q, 1936
    .equ BOTH, 2096
    .equ R, 2256
    .equ FRAME, 2416

// ge: is the number at x0 at least the number at x1 -> x0 1 or 0. Uses x9-x11.
ge:
    mov     x9, x21
1:  sub     x9, x9, #1
    ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    cmp     x10, x11
    b.ne    2f
    cbnz    x9, 1b
    mov     x0, #1
    ret
2:  cset    x0, hi
    ret
// take: the number at x0 less the number at x1, in place. Uses x9-x12.
take:
    mov     x9, #0
    cmp     x9, x9
1:  ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    sbcs    x10, x10, x11
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 1b
    ret
// zero: is the number at x0 zero -> x0 1 or 0. Uses x9-x11.
zero:
    mov     x9, #0
    mov     x10, #0
1:  ldr     x11, [x0, x9, lsl #3]
    orr     x10, x10, x11
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    1b
    cmp     x10, #0
    cset    x0, eq
    ret
// copy: the number at x1 to x0. Uses x9, x10.
copy:
    mov     x9, #0
1:  ldr     x10, [x1, x9, lsl #3]
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    1b
    ret

// fmul: x0 = x1 times x2, divided by 2^(64 limbs), modulo the field's modulus (Montgomery's product), spelled out for four limbs
// and for six with the running value in registers and no branch on any value. Uses x3-x17.
fmul:
    cmp     x21, #4
    b.ne    fmul6
fmul4:
    mov     x3, #0
    mov     x4, #0
    mov     x5, #0
    mov     x6, #0
    mov     x7, #0
    mov     x8, #0
    ldr     x9, [x2, #0]
    ldr     x13, [x1, #0]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x3, x3, x11
    adc     x10, x12, xzr
    ldr     x13, [x1, #8]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x4, x4, x11
    adc     x12, x12, xzr
    adds    x4, x4, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #16]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x5, x5, x11
    adc     x12, x12, xzr
    adds    x5, x5, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #24]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x6, x6, x11
    adc     x12, x12, xzr
    adds    x6, x6, x10
    adc     x10, x12, xzr
    adds    x7, x7, x10
    cset    x8, cs
    ldr     x13, [x22, #144]
    mul     x14, x3, x13
    ldr     x13, [x22]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x3
    adc     x10, x12, xzr
    ldr     x13, [x22, #8]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x4
    adc     x12, x12, xzr
    adds    x3, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #16]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x5
    adc     x12, x12, xzr
    adds    x4, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #24]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x6
    adc     x12, x12, xzr
    adds    x5, x11, x10
    adc     x10, x12, xzr
    adds    x6, x7, x10
    adc     x7, x8, xzr
    ldr     x9, [x2, #8]
    ldr     x13, [x1, #0]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x3, x3, x11
    adc     x10, x12, xzr
    ldr     x13, [x1, #8]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x4, x4, x11
    adc     x12, x12, xzr
    adds    x4, x4, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #16]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x5, x5, x11
    adc     x12, x12, xzr
    adds    x5, x5, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #24]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x6, x6, x11
    adc     x12, x12, xzr
    adds    x6, x6, x10
    adc     x10, x12, xzr
    adds    x7, x7, x10
    cset    x8, cs
    ldr     x13, [x22, #144]
    mul     x14, x3, x13
    ldr     x13, [x22]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x3
    adc     x10, x12, xzr
    ldr     x13, [x22, #8]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x4
    adc     x12, x12, xzr
    adds    x3, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #16]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x5
    adc     x12, x12, xzr
    adds    x4, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #24]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x6
    adc     x12, x12, xzr
    adds    x5, x11, x10
    adc     x10, x12, xzr
    adds    x6, x7, x10
    adc     x7, x8, xzr
    ldr     x9, [x2, #16]
    ldr     x13, [x1, #0]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x3, x3, x11
    adc     x10, x12, xzr
    ldr     x13, [x1, #8]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x4, x4, x11
    adc     x12, x12, xzr
    adds    x4, x4, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #16]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x5, x5, x11
    adc     x12, x12, xzr
    adds    x5, x5, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #24]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x6, x6, x11
    adc     x12, x12, xzr
    adds    x6, x6, x10
    adc     x10, x12, xzr
    adds    x7, x7, x10
    cset    x8, cs
    ldr     x13, [x22, #144]
    mul     x14, x3, x13
    ldr     x13, [x22]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x3
    adc     x10, x12, xzr
    ldr     x13, [x22, #8]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x4
    adc     x12, x12, xzr
    adds    x3, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #16]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x5
    adc     x12, x12, xzr
    adds    x4, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #24]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x6
    adc     x12, x12, xzr
    adds    x5, x11, x10
    adc     x10, x12, xzr
    adds    x6, x7, x10
    adc     x7, x8, xzr
    ldr     x9, [x2, #24]
    ldr     x13, [x1, #0]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x3, x3, x11
    adc     x10, x12, xzr
    ldr     x13, [x1, #8]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x4, x4, x11
    adc     x12, x12, xzr
    adds    x4, x4, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #16]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x5, x5, x11
    adc     x12, x12, xzr
    adds    x5, x5, x10
    adc     x10, x12, xzr
    ldr     x13, [x1, #24]
    mul     x11, x13, x9
    umulh   x12, x13, x9
    adds    x6, x6, x11
    adc     x12, x12, xzr
    adds    x6, x6, x10
    adc     x10, x12, xzr
    adds    x7, x7, x10
    cset    x8, cs
    ldr     x13, [x22, #144]
    mul     x14, x3, x13
    ldr     x13, [x22]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x3
    adc     x10, x12, xzr
    ldr     x13, [x22, #8]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x4
    adc     x12, x12, xzr
    adds    x3, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #16]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x5
    adc     x12, x12, xzr
    adds    x4, x11, x10
    adc     x10, x12, xzr
    ldr     x13, [x22, #24]
    mul     x11, x14, x13
    umulh   x12, x14, x13
    adds    x11, x11, x6
    adc     x12, x12, xzr
    adds    x5, x11, x10
    adc     x10, x12, xzr
    adds    x6, x7, x10
    adc     x7, x8, xzr
    ldr     x17, [x22, #0]
    subs    x9, x3, x17
    ldr     x17, [x22, #8]
    sbcs    x10, x4, x17
    ldr     x17, [x22, #16]
    sbcs    x11, x5, x17
    ldr     x17, [x22, #24]
    sbcs    x12, x6, x17
    sbcs    x17, x7, xzr
    csel    x3, x9, x3, cs
    csel    x4, x10, x4, cs
    csel    x5, x11, x5, cs
    csel    x6, x12, x6, cs
    stp     x3, x4, [x0, #0]
    stp     x5, x6, [x0, #16]
    ret
fmul6:
    mov     x3, #0
    mov     x4, #0
    mov     x5, #0
    mov     x6, #0
    mov     x7, #0
    mov     x8, #0
    mov     x9, #0
    mov     x10, #0
    ldr     x11, [x2, #0]
    ldr     x15, [x1, #0]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x3, x3, x13
    adc     x12, x14, xzr
    ldr     x15, [x1, #8]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x4, x4, x13
    adc     x14, x14, xzr
    adds    x4, x4, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #16]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x5, x5, x13
    adc     x14, x14, xzr
    adds    x5, x5, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #24]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x6, x6, x13
    adc     x14, x14, xzr
    adds    x6, x6, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #32]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x7, x7, x13
    adc     x14, x14, xzr
    adds    x7, x7, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #40]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x8, x8, x13
    adc     x14, x14, xzr
    adds    x8, x8, x12
    adc     x12, x14, xzr
    adds    x9, x9, x12
    cset    x10, cs
    ldr     x15, [x22, #144]
    mul     x16, x3, x15
    ldr     x15, [x22]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x3
    adc     x12, x14, xzr
    ldr     x15, [x22, #8]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x4
    adc     x14, x14, xzr
    adds    x3, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #16]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x5
    adc     x14, x14, xzr
    adds    x4, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #24]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x6
    adc     x14, x14, xzr
    adds    x5, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #32]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x7
    adc     x14, x14, xzr
    adds    x6, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #40]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x8
    adc     x14, x14, xzr
    adds    x7, x13, x12
    adc     x12, x14, xzr
    adds    x8, x9, x12
    adc     x9, x10, xzr
    ldr     x11, [x2, #8]
    ldr     x15, [x1, #0]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x3, x3, x13
    adc     x12, x14, xzr
    ldr     x15, [x1, #8]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x4, x4, x13
    adc     x14, x14, xzr
    adds    x4, x4, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #16]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x5, x5, x13
    adc     x14, x14, xzr
    adds    x5, x5, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #24]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x6, x6, x13
    adc     x14, x14, xzr
    adds    x6, x6, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #32]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x7, x7, x13
    adc     x14, x14, xzr
    adds    x7, x7, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #40]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x8, x8, x13
    adc     x14, x14, xzr
    adds    x8, x8, x12
    adc     x12, x14, xzr
    adds    x9, x9, x12
    cset    x10, cs
    ldr     x15, [x22, #144]
    mul     x16, x3, x15
    ldr     x15, [x22]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x3
    adc     x12, x14, xzr
    ldr     x15, [x22, #8]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x4
    adc     x14, x14, xzr
    adds    x3, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #16]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x5
    adc     x14, x14, xzr
    adds    x4, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #24]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x6
    adc     x14, x14, xzr
    adds    x5, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #32]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x7
    adc     x14, x14, xzr
    adds    x6, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #40]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x8
    adc     x14, x14, xzr
    adds    x7, x13, x12
    adc     x12, x14, xzr
    adds    x8, x9, x12
    adc     x9, x10, xzr
    ldr     x11, [x2, #16]
    ldr     x15, [x1, #0]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x3, x3, x13
    adc     x12, x14, xzr
    ldr     x15, [x1, #8]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x4, x4, x13
    adc     x14, x14, xzr
    adds    x4, x4, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #16]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x5, x5, x13
    adc     x14, x14, xzr
    adds    x5, x5, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #24]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x6, x6, x13
    adc     x14, x14, xzr
    adds    x6, x6, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #32]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x7, x7, x13
    adc     x14, x14, xzr
    adds    x7, x7, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #40]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x8, x8, x13
    adc     x14, x14, xzr
    adds    x8, x8, x12
    adc     x12, x14, xzr
    adds    x9, x9, x12
    cset    x10, cs
    ldr     x15, [x22, #144]
    mul     x16, x3, x15
    ldr     x15, [x22]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x3
    adc     x12, x14, xzr
    ldr     x15, [x22, #8]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x4
    adc     x14, x14, xzr
    adds    x3, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #16]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x5
    adc     x14, x14, xzr
    adds    x4, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #24]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x6
    adc     x14, x14, xzr
    adds    x5, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #32]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x7
    adc     x14, x14, xzr
    adds    x6, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #40]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x8
    adc     x14, x14, xzr
    adds    x7, x13, x12
    adc     x12, x14, xzr
    adds    x8, x9, x12
    adc     x9, x10, xzr
    ldr     x11, [x2, #24]
    ldr     x15, [x1, #0]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x3, x3, x13
    adc     x12, x14, xzr
    ldr     x15, [x1, #8]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x4, x4, x13
    adc     x14, x14, xzr
    adds    x4, x4, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #16]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x5, x5, x13
    adc     x14, x14, xzr
    adds    x5, x5, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #24]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x6, x6, x13
    adc     x14, x14, xzr
    adds    x6, x6, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #32]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x7, x7, x13
    adc     x14, x14, xzr
    adds    x7, x7, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #40]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x8, x8, x13
    adc     x14, x14, xzr
    adds    x8, x8, x12
    adc     x12, x14, xzr
    adds    x9, x9, x12
    cset    x10, cs
    ldr     x15, [x22, #144]
    mul     x16, x3, x15
    ldr     x15, [x22]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x3
    adc     x12, x14, xzr
    ldr     x15, [x22, #8]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x4
    adc     x14, x14, xzr
    adds    x3, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #16]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x5
    adc     x14, x14, xzr
    adds    x4, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #24]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x6
    adc     x14, x14, xzr
    adds    x5, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #32]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x7
    adc     x14, x14, xzr
    adds    x6, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #40]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x8
    adc     x14, x14, xzr
    adds    x7, x13, x12
    adc     x12, x14, xzr
    adds    x8, x9, x12
    adc     x9, x10, xzr
    ldr     x11, [x2, #32]
    ldr     x15, [x1, #0]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x3, x3, x13
    adc     x12, x14, xzr
    ldr     x15, [x1, #8]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x4, x4, x13
    adc     x14, x14, xzr
    adds    x4, x4, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #16]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x5, x5, x13
    adc     x14, x14, xzr
    adds    x5, x5, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #24]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x6, x6, x13
    adc     x14, x14, xzr
    adds    x6, x6, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #32]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x7, x7, x13
    adc     x14, x14, xzr
    adds    x7, x7, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #40]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x8, x8, x13
    adc     x14, x14, xzr
    adds    x8, x8, x12
    adc     x12, x14, xzr
    adds    x9, x9, x12
    cset    x10, cs
    ldr     x15, [x22, #144]
    mul     x16, x3, x15
    ldr     x15, [x22]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x3
    adc     x12, x14, xzr
    ldr     x15, [x22, #8]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x4
    adc     x14, x14, xzr
    adds    x3, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #16]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x5
    adc     x14, x14, xzr
    adds    x4, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #24]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x6
    adc     x14, x14, xzr
    adds    x5, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #32]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x7
    adc     x14, x14, xzr
    adds    x6, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #40]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x8
    adc     x14, x14, xzr
    adds    x7, x13, x12
    adc     x12, x14, xzr
    adds    x8, x9, x12
    adc     x9, x10, xzr
    ldr     x11, [x2, #40]
    ldr     x15, [x1, #0]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x3, x3, x13
    adc     x12, x14, xzr
    ldr     x15, [x1, #8]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x4, x4, x13
    adc     x14, x14, xzr
    adds    x4, x4, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #16]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x5, x5, x13
    adc     x14, x14, xzr
    adds    x5, x5, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #24]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x6, x6, x13
    adc     x14, x14, xzr
    adds    x6, x6, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #32]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x7, x7, x13
    adc     x14, x14, xzr
    adds    x7, x7, x12
    adc     x12, x14, xzr
    ldr     x15, [x1, #40]
    mul     x13, x15, x11
    umulh   x14, x15, x11
    adds    x8, x8, x13
    adc     x14, x14, xzr
    adds    x8, x8, x12
    adc     x12, x14, xzr
    adds    x9, x9, x12
    cset    x10, cs
    ldr     x15, [x22, #144]
    mul     x16, x3, x15
    ldr     x15, [x22]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x3
    adc     x12, x14, xzr
    ldr     x15, [x22, #8]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x4
    adc     x14, x14, xzr
    adds    x3, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #16]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x5
    adc     x14, x14, xzr
    adds    x4, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #24]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x6
    adc     x14, x14, xzr
    adds    x5, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #32]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x7
    adc     x14, x14, xzr
    adds    x6, x13, x12
    adc     x12, x14, xzr
    ldr     x15, [x22, #40]
    mul     x13, x16, x15
    umulh   x14, x16, x15
    adds    x13, x13, x8
    adc     x14, x14, xzr
    adds    x7, x13, x12
    adc     x12, x14, xzr
    adds    x8, x9, x12
    adc     x9, x10, xzr
    ldr     x17, [x22, #0]
    subs    x11, x3, x17
    ldr     x17, [x22, #8]
    sbcs    x12, x4, x17
    ldr     x17, [x22, #16]
    sbcs    x13, x5, x17
    ldr     x17, [x22, #24]
    sbcs    x14, x6, x17
    ldr     x17, [x22, #32]
    sbcs    x15, x7, x17
    ldr     x17, [x22, #40]
    sbcs    x16, x8, x17
    sbcs    x17, x9, xzr
    csel    x3, x11, x3, cs
    csel    x4, x12, x4, cs
    csel    x5, x13, x5, cs
    csel    x6, x14, x6, cs
    csel    x7, x15, x7, cs
    csel    x8, x16, x8, cs
    stp     x3, x4, [x0, #0]
    stp     x5, x6, [x0, #16]
    stp     x7, x8, [x0, #32]
    ret
// fadd: x0 = x1 + x2 modulo the field's modulus; fsub: x0 = x1 - x2. Spelled out for four limbs and for six, no branch on any
// value. Use x3-x16.
fadd:
    cmp     x21, #4
    b.ne    fadd6
fadd4:
    ldr     x3, [x1, #0]
    ldr     x15, [x2, #0]
    adds    x3, x3, x15
    ldr     x4, [x1, #8]
    ldr     x15, [x2, #8]
    adcs    x4, x4, x15
    ldr     x5, [x1, #16]
    ldr     x15, [x2, #16]
    adcs    x5, x5, x15
    ldr     x6, [x1, #24]
    ldr     x15, [x2, #24]
    adcs    x6, x6, x15
    cset    x16, cs
    ldr     x15, [x22, #0]
    subs    x9, x3, x15
    ldr     x15, [x22, #8]
    sbcs    x10, x4, x15
    ldr     x15, [x22, #16]
    sbcs    x11, x5, x15
    ldr     x15, [x22, #24]
    sbcs    x12, x6, x15
    sbcs    x16, x16, xzr
    csel    x3, x9, x3, cs
    csel    x4, x10, x4, cs
    csel    x5, x11, x5, cs
    csel    x6, x12, x6, cs
    stp     x3, x4, [x0, #0]
    stp     x5, x6, [x0, #16]
    ret
fadd6:
    ldr     x3, [x1, #0]
    ldr     x15, [x2, #0]
    adds    x3, x3, x15
    ldr     x4, [x1, #8]
    ldr     x15, [x2, #8]
    adcs    x4, x4, x15
    ldr     x5, [x1, #16]
    ldr     x15, [x2, #16]
    adcs    x5, x5, x15
    ldr     x6, [x1, #24]
    ldr     x15, [x2, #24]
    adcs    x6, x6, x15
    ldr     x7, [x1, #32]
    ldr     x15, [x2, #32]
    adcs    x7, x7, x15
    ldr     x8, [x1, #40]
    ldr     x15, [x2, #40]
    adcs    x8, x8, x15
    cset    x16, cs
    ldr     x15, [x22, #0]
    subs    x9, x3, x15
    ldr     x15, [x22, #8]
    sbcs    x10, x4, x15
    ldr     x15, [x22, #16]
    sbcs    x11, x5, x15
    ldr     x15, [x22, #24]
    sbcs    x12, x6, x15
    ldr     x15, [x22, #32]
    sbcs    x13, x7, x15
    ldr     x15, [x22, #40]
    sbcs    x14, x8, x15
    sbcs    x16, x16, xzr
    csel    x3, x9, x3, cs
    csel    x4, x10, x4, cs
    csel    x5, x11, x5, cs
    csel    x6, x12, x6, cs
    csel    x7, x13, x7, cs
    csel    x8, x14, x8, cs
    stp     x3, x4, [x0, #0]
    stp     x5, x6, [x0, #16]
    stp     x7, x8, [x0, #32]
    ret
fsub:
    cmp     x21, #4
    b.ne    fsub6
fsub4:
    ldr     x3, [x1, #0]
    ldr     x15, [x2, #0]
    subs    x3, x3, x15
    ldr     x4, [x1, #8]
    ldr     x15, [x2, #8]
    sbcs    x4, x4, x15
    ldr     x5, [x1, #16]
    ldr     x15, [x2, #16]
    sbcs    x5, x5, x15
    ldr     x6, [x1, #24]
    ldr     x15, [x2, #24]
    sbcs    x6, x6, x15
    csetm   x16, cc
    ldr     x15, [x22, #0]
    and     x15, x15, x16
    adds    x3, x3, x15
    ldr     x15, [x22, #8]
    and     x15, x15, x16
    adcs    x4, x4, x15
    ldr     x15, [x22, #16]
    and     x15, x15, x16
    adcs    x5, x5, x15
    ldr     x15, [x22, #24]
    and     x15, x15, x16
    adcs    x6, x6, x15
    stp     x3, x4, [x0, #0]
    stp     x5, x6, [x0, #16]
    ret
fsub6:
    ldr     x3, [x1, #0]
    ldr     x15, [x2, #0]
    subs    x3, x3, x15
    ldr     x4, [x1, #8]
    ldr     x15, [x2, #8]
    sbcs    x4, x4, x15
    ldr     x5, [x1, #16]
    ldr     x15, [x2, #16]
    sbcs    x5, x5, x15
    ldr     x6, [x1, #24]
    ldr     x15, [x2, #24]
    sbcs    x6, x6, x15
    ldr     x7, [x1, #32]
    ldr     x15, [x2, #32]
    sbcs    x7, x7, x15
    ldr     x8, [x1, #40]
    ldr     x15, [x2, #40]
    sbcs    x8, x8, x15
    csetm   x16, cc
    ldr     x15, [x22, #0]
    and     x15, x15, x16
    adds    x3, x3, x15
    ldr     x15, [x22, #8]
    and     x15, x15, x16
    adcs    x4, x4, x15
    ldr     x15, [x22, #16]
    and     x15, x15, x16
    adcs    x5, x5, x15
    ldr     x15, [x22, #24]
    and     x15, x15, x16
    adcs    x6, x6, x15
    ldr     x15, [x22, #32]
    and     x15, x15, x16
    adcs    x7, x7, x15
    ldr     x15, [x22, #40]
    and     x15, x15, x16
    adcs    x8, x8, x15
    stp     x3, x4, [x0, #0]
    stp     x5, x6, [x0, #16]
    stp     x7, x8, [x0, #32]
    ret

// load: the x2 bytes at x1 (most significant first) as a number at x0 -> x0 1, or 0 if it does not fit. Uses x9-x14.
load:
    mov     x9, #0
1:  str     xzr, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    1b
    mov     x9, #0
2:  cmp     x9, x2
    b.hs    5f
    ldrb    w11, [x1, x9]
    sub     x12, x2, x9
    sub     x12, x12, #1
    add     x9, x9, #1
    lsr     x13, x12, #3
    cmp     x13, x21
    b.lo    3f
    cbz     w11, 2b
    mov     x0, #0
    ret
3:  and     x12, x12, #7
    lsl     x12, x12, #3
    lsl     x11, x11, x12
    ldr     x14, [x0, x13, lsl #3]
    orr     x14, x14, x11
    str     x14, [x0, x13, lsl #3]
    b       2b
5:  mov     x0, #1
    ret
// setup: the field at x22 from the modulus's bytes at x0. Both moduli of both curves have their top bit set, so 2^(64 limbs)
// modulo the modulus is simply its negative; 2^(128 limbs) follows by doubling. Uses x24.
setup:
    stp     x29, x30, [sp, #-16]!
    mov     x1, x0
    mov     x0, x22
    mov     x2, x23
    bl      load
    ldr     x9, [x22]
    mov     x10, #1
    mov     x11, #6
1:  mul     x12, x9, x10
    mov     x13, #2
    sub     x13, x13, x12
    mul     x10, x10, x13
    subs    x11, x11, #1
    b.ne    1b
    neg     x10, x10
    str     x10, [x22, #144]
    add     x13, x22, #96
    add     x14, x22, #48
    mov     x9, #0
    cmp     x9, x9
2:  ldr     x11, [x22, x9, lsl #3]
    sbcs    x10, xzr, x11
    str     x10, [x13, x9, lsl #3]
    str     x10, [x14, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 2b
    lsl     x24, x21, #6
3:  add     x0, x22, #48
    mov     x1, x0
    mov     x2, x0
    bl      fadd
    subs    x24, x24, #1
    b.ne    3b
    ldp     x29, x30, [sp], #16
    ret
// inverse: x0 = one over x1 in the field, as x1 to the power of the modulus less two (the modulus is prime). x0 is not x1.
// Uses x24, x27, x28.
inverse:
    stp     x29, x30, [sp, #-16]!
    mov     x27, x0
    mov     x28, x1
    add     x0, x19, #E
    mov     x1, x22
    bl      copy
    add     x13, x19, #E
    ldr     x10, [x13]
    subs    x10, x10, #2
    str     x10, [x13]
    mov     x9, #1
1:  ldr     x10, [x13, x9, lsl #3]
    sbcs    x10, x10, xzr
    str     x10, [x13, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 1b
    mov     x0, x27
    add     x1, x22, #96
    bl      copy
    lsl     x24, x21, #6
2:  subs    x24, x24, #1
    b.mi    3f
    mov     x0, x27
    mov     x1, x27
    mov     x2, x27
    bl      fmul
    add     x13, x19, #E
    lsr     x9, x24, #6
    ldr     x10, [x13, x9, lsl #3]
    lsr     x10, x10, x24
    tbz     x10, #0, 2b
    mov     x0, x27
    mov     x1, x27
    mov     x2, x28
    bl      fmul
    b       2b
3:  ldp     x29, x30, [sp], #16
    ret
// twice: the point at x0 doubled, in place. A point is x, y, z (the true point being x/z^2, y/z^3) and a mark for "nowhere".
twice:
    stp     x29, x30, [sp, #-32]!
    str     x25, [sp, #16]
    mov     x25, x0
    ldr     x9, [x25, #144]
    cbnz    x9, t_nowhere
    add     x0, x25, #48
    bl      zero
    cbnz    x0, t_nowhere
    add     x0, x19, #A1
    add     x1, x25, #96
    add     x2, x25, #96
    bl      fmul
    add     x0, x19, #A2
    add     x1, x25, #48
    add     x2, x25, #48
    bl      fmul
    add     x0, x19, #A3
    mov     x1, x25
    add     x2, x19, #A2
    bl      fmul
    add     x0, x19, #A4
    mov     x1, x25
    add     x2, x19, #A1
    bl      fsub
    add     x0, x19, #A5
    mov     x1, x25
    add     x2, x19, #A1
    bl      fadd
    add     x0, x19, #A4
    add     x1, x19, #A4
    add     x2, x19, #A5
    bl      fmul
    add     x0, x19, #A6
    add     x1, x19, #A4
    add     x2, x19, #A4
    bl      fadd
    add     x0, x19, #A6
    add     x1, x19, #A6
    add     x2, x19, #A4
    bl      fadd
    add     x0, x19, #A3
    add     x1, x19, #A3
    add     x2, x19, #A3
    bl      fadd
    add     x0, x19, #A3
    add     x1, x19, #A3
    add     x2, x19, #A3
    bl      fadd
    add     x0, x19, #A5
    add     x1, x25, #48
    add     x2, x25, #96
    bl      fadd
    add     x0, x19, #A5
    add     x1, x19, #A5
    add     x2, x19, #A5
    bl      fmul
    add     x0, x19, #A5
    add     x1, x19, #A5
    add     x2, x19, #A2
    bl      fsub
    add     x0, x25, #96
    add     x1, x19, #A5
    add     x2, x19, #A1
    bl      fsub
    mov     x0, x25
    add     x1, x19, #A6
    add     x2, x19, #A6
    bl      fmul
    add     x0, x19, #A4
    add     x1, x19, #A3
    add     x2, x19, #A3
    bl      fadd
    mov     x0, x25
    mov     x1, x25
    add     x2, x19, #A4
    bl      fsub
    add     x0, x19, #A2
    add     x1, x19, #A2
    add     x2, x19, #A2
    bl      fmul
    add     x0, x19, #A2
    add     x1, x19, #A2
    add     x2, x19, #A2
    bl      fadd
    add     x0, x19, #A2
    add     x1, x19, #A2
    add     x2, x19, #A2
    bl      fadd
    add     x0, x19, #A2
    add     x1, x19, #A2
    add     x2, x19, #A2
    bl      fadd
    add     x0, x19, #A4
    add     x1, x19, #A3
    mov     x2, x25
    bl      fsub
    add     x0, x19, #A4
    add     x1, x19, #A6
    add     x2, x19, #A4
    bl      fmul
    add     x0, x25, #48
    add     x1, x19, #A4
    add     x2, x19, #A2
    bl      fsub
    b       t_out
t_nowhere:
    mov     x9, #1
    str     x9, [x25, #144]
t_out:
    ldr     x25, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// plus: the point at x0 becomes itself plus the point at x1
plus:
    stp     x29, x30, [sp, #-32]!
    stp     x25, x26, [sp, #16]
    mov     x25, x0
    mov     x26, x1
    ldr     x9, [x26, #144]
    cbnz    x9, p_out
    ldr     x9, [x25, #144]
    cbz     x9, 2f
    mov     x9, #0                      // nowhere plus a point is that point
1:  ldr     x10, [x26, x9, lsl #3]
    str     x10, [x25, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #19
    b.lo    1b
    b       p_out
2:
    add     x0, x19, #A1
    add     x1, x25, #96
    add     x2, x25, #96
    bl      fmul
    add     x0, x19, #A2
    add     x1, x26, #96
    add     x2, x26, #96
    bl      fmul
    add     x0, x19, #A3
    mov     x1, x25
    add     x2, x19, #A2
    bl      fmul
    add     x0, x19, #A4
    mov     x1, x26
    add     x2, x19, #A1
    bl      fmul
    add     x0, x19, #A5
    add     x1, x25, #48
    add     x2, x26, #96
    bl      fmul
    add     x0, x19, #A5
    add     x1, x19, #A5
    add     x2, x19, #A2
    bl      fmul
    add     x0, x19, #A6
    add     x1, x26, #48
    add     x2, x25, #96
    bl      fmul
    add     x0, x19, #A6
    add     x1, x19, #A6
    add     x2, x19, #A1
    bl      fmul
    add     x0, x19, #A7
    add     x1, x19, #A4
    add     x2, x19, #A3
    bl      fsub
    add     x0, x19, #A8
    add     x1, x19, #A6
    add     x2, x19, #A5
    bl      fsub
    add     x0, x19, #A7
    bl      zero
    cbz     x0, 4f
    add     x0, x19, #A8
    bl      zero
    cbz     x0, 3f
    mov     x0, x25                     // the same point twice
    bl      twice
    b       p_out
3:  mov     x9, #1                      // a point plus its mirror image
    str     x9, [x25, #144]
    b       p_out
4:
    add     x0, x19, #A1
    add     x1, x19, #A7
    add     x2, x19, #A7
    bl      fmul
    add     x0, x19, #A2
    add     x1, x19, #A7
    add     x2, x19, #A1
    bl      fmul
    add     x0, x19, #A4
    add     x1, x19, #A3
    add     x2, x19, #A1
    bl      fmul
    add     x0, x25, #96
    add     x1, x25, #96
    add     x2, x26, #96
    bl      fmul
    add     x0, x25, #96
    add     x1, x25, #96
    add     x2, x19, #A7
    bl      fmul
    mov     x0, x25
    add     x1, x19, #A8
    add     x2, x19, #A8
    bl      fmul
    mov     x0, x25
    mov     x1, x25
    add     x2, x19, #A2
    bl      fsub
    add     x0, x19, #A3
    add     x1, x19, #A4
    add     x2, x19, #A4
    bl      fadd
    mov     x0, x25
    mov     x1, x25
    add     x2, x19, #A3
    bl      fsub
    add     x0, x19, #A3
    add     x1, x19, #A4
    mov     x2, x25
    bl      fsub
    add     x0, x19, #A3
    add     x1, x19, #A8
    add     x2, x19, #A3
    bl      fmul
    add     x0, x19, #A5
    add     x1, x19, #A5
    add     x2, x19, #A2
    bl      fmul
    add     x0, x25, #48
    add     x1, x19, #A3
    add     x2, x19, #A5
    bl      fsub
p_out:
    ldp     x25, x26, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// bytes_at: the plain block of 1 to 80 bytes at the handle in number x0 (numbers x24, count x25) -> x0, or 0. Uses x9.
bytes_at:
    cmp     x25, x0
    b.le    8f
    ldrsh   x9, [x24, x0, lsl #1]
    cmp     x9, #0
    b.lt    8f
    cmp     x9, #255
    b.gt    8f
    add     x9, x9, #256
    ldr     x0, [x20, x9, lsl #3]
    cbz     x0, 9f
    ldr     w9, [x0]
    cmp     w9, #2
    b.ne    8f
    ldr     x9, [x0, #16]
    cmp     x9, #64
    b.ls    8f
    cmp     x9, #(64 + 80)
    b.ls    9f
8:  mov     x0, #0
9:  ret

    .macro  LOADB dst, blk, fail
    ldr     x1, [x19, #\blk]
    ldr     x2, [x1, #16]
    sub     x2, x2, #64
    add     x1, x1, #64
    add     x0, x19, #\dst
    bl      load
    cbz     x0, \fail
    .endm
    .macro  CONST dst, name
    adr     x1, c256_\name
    adr     x9, c384_\name
    cmp     x23, #32
    csel    x1, x1, x9, eq
    mov     x2, x23
    add     x0, x19, #\dst
    bl      load
    .endm
    .macro  GE a, b
    add     x0, x19, #\a
    add     x1, x19, #\b
    bl      ge
    .endm
verify:
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, sp
    mov     x20, x4
    mov     x24, x1
    mov     x25, x2
    cmp     x25, #0
    b.le    v_unusable
    ldrsh   x9, [x24]
    mov     x23, #32
    cmp     x9, #256
    b.eq    1f
    mov     x23, #48
    cmp     x9, #384
    b.ne    v_unusable
1:  lsr     x21, x23, #3
    mov     x0, #1
    bl      bytes_at
    cbz     x0, v_unusable
    str     x0, [x19, #BX]
    mov     x0, #2
    bl      bytes_at
    cbz     x0, v_unusable
    str     x0, [x19, #BY]
    mov     x0, #3
    bl      bytes_at
    cbz     x0, v_unusable
    str     x0, [x19, #BR]
    mov     x0, #4
    bl      bytes_at
    cbz     x0, v_unusable
    str     x0, [x19, #BS]
    mov     x0, #5
    bl      bytes_at
    cbz     x0, v_unusable
    str     x0, [x19, #BD]
    add     x22, x19, #FN
    adr     x0, c256_n
    adr     x9, c384_n
    cmp     x23, #32
    csel    x0, x0, x9, eq
    bl      setup
    add     x22, x19, #FP
    adr     x0, c256_p
    adr     x9, c384_p
    cmp     x23, #32
    csel    x0, x0, x9, eq
    bl      setup
    LOADB   NX, BX, v_unusable
    LOADB   NY, BY, v_unusable
    LOADB   NR, BR, v_unusable
    LOADB   NS, BS, v_unusable
    GE      NX, FP
    cbnz    x0, v_unusable
    GE      NY, FP
    cbnz    x0, v_unusable
    add     x0, x19, #NR                // r and s must each be from 1 to the order less 1
    bl      zero
    cbnz    x0, v_no
    add     x0, x19, #NS
    bl      zero
    cbnz    x0, v_no
    GE      NR, FN
    cbnz    x0, v_no
    GE      NS, FN
    cbnz    x0, v_no
    CONST   CB, b
    CONST   A1, gx
    CONST   A2, gy
    add     x0, x19, #PLAIN1
    add     x1, x19, #NX
    bl      copy
    add     x0, x19, #PLAIN1
    mov     x1, x0
    mov     x2, #0
    bl      load                        // no bytes: zero
    mov     x9, #1
    str     x9, [x19, #PLAIN1]
    .macro  ENTERF dst, src
    add     x0, x19, #\dst
    add     x1, x19, #\src
    add     x2, x22, #48
    bl      fmul
    .endm
    .macro  LEAVEF dst, src
    add     x0, x19, #\dst
    add     x1, x19, #\src
    add     x2, x19, #PLAIN1
    bl      fmul
    .endm
    ENTERF  CB, CB
    ENTERF  G, A1                       // the curve's own point
    ENTERF  G + 48, A2
    ENTERF  Q, NX                       // the key
    ENTERF  Q + 48, NY
    add     x0, x19, #(G + 96)
    add     x1, x22, #96
    bl      copy
    add     x0, x19, #(Q + 96)
    add     x1, x22, #96
    bl      copy
    str     xzr, [x19, #(G + 144)]
    str     xzr, [x19, #(Q + 144)]
    add     x0, x19, #THREE
    add     x1, x22, #96
    mov     x2, x1
    bl      fadd
    add     x0, x19, #THREE
    mov     x1, x0
    add     x2, x22, #96
    bl      fadd
    add     x25, x19, #Q                // is the key a point on the curve: y^2 = x^3 - 3x + b
    add     x0, x19, #L
    add     x1, x25, #48
    add     x2, x25, #48
    bl      fmul
    add     x0, x19, #RT
    mov     x1, x25
    mov     x2, x25
    bl      fmul
    add     x0, x19, #RT
    add     x1, x19, #RT
    mov     x2, x25
    bl      fmul
    add     x0, x19, #A3
    add     x1, x19, #THREE
    mov     x2, x25
    bl      fmul
    add     x0, x19, #RT
    add     x1, x19, #RT
    add     x2, x19, #A3
    bl      fsub
    add     x0, x19, #RT
    add     x1, x19, #RT
    add     x2, x19, #CB
    bl      fadd
    mov     x9, #0
2:  add     x10, x19, #L
    add     x11, x19, #RT
    ldr     x10, [x10, x9, lsl #3]
    ldr     x11, [x11, x9, lsl #3]
    cmp     x10, x11
    b.ne    v_unusable
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    2b
    ldr     x1, [x19, #BD]              // the digest's leftmost bytes, as a number below the order
    ldr     x2, [x1, #16]
    sub     x2, x2, #64
    cmp     x2, x23
    csel    x2, x23, x2, hi
    add     x1, x1, #64
    add     x0, x19, #NZ
    bl      load
    GE      NZ, FN
    cbz     x0, 3f
    add     x0, x19, #NZ
    add     x1, x19, #FN
    bl      take
3:  add     x22, x19, #FN               // u1 = digest / s and u2 = r / s, modulo the order
    ENTERF  A1, NS
    add     x0, x19, #W
    add     x1, x19, #A1
    bl      inverse
    ENTERF  A1, NZ
    add     x0, x19, #A1
    mov     x1, x0
    add     x2, x19, #W
    bl      fmul
    LEAVEF  U1, A1
    ENTERF  A1, NR
    add     x0, x19, #A1
    mov     x1, x0
    add     x2, x19, #W
    bl      fmul
    LEAVEF  U2, A1
    add     x22, x19, #FP
    mov     x9, #0                      // BOTH = the curve's point plus the key
4:  add     x10, x19, #G
    add     x11, x19, #BOTH
    ldr     x10, [x10, x9, lsl #3]
    str     x10, [x11, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #19
    b.lo    4b
    add     x0, x19, #BOTH
    add     x1, x19, #Q
    bl      plus
    mov     x9, #1                      // u1 times the curve's point plus u2 times the key, both at once from the top bit down
    str     x9, [x19, #(R + 144)]
    lsl     x24, x21, #6
5:  subs    x24, x24, #1
    b.mi    7f
    add     x0, x19, #R
    bl      twice
    lsr     x9, x24, #6
    add     x10, x19, #U1
    add     x11, x19, #U2
    ldr     x10, [x10, x9, lsl #3]
    ldr     x11, [x11, x9, lsl #3]
    lsr     x10, x10, x24
    lsr     x11, x11, x24
    and     x10, x10, #1
    and     x11, x11, #1
    orr     x9, x10, x11, lsl #1
    cbz     x9, 5b
    add     x1, x19, #G
    add     x12, x19, #Q
    add     x13, x19, #BOTH
    cmp     x9, #2
    csel    x1, x12, x1, eq
    cmp     x9, #3
    csel    x1, x13, x1, eq
    add     x0, x19, #R
    bl      plus
    b       5b
7:  ldr     x9, [x19, #(R + 144)]
    cbnz    x9, v_no
    add     x0, x19, #ZI                // its true x, as a plain number below the order, must be r
    add     x1, x19, #(R + 96)
    bl      inverse
    add     x0, x19, #A1
    add     x1, x19, #ZI
    mov     x2, x1
    bl      fmul
    add     x0, x19, #A1
    add     x1, x19, #R
    mov     x2, x0
    bl      fmul
    LEAVEF  AX, A1
    GE      AX, FN
    cbz     x0, 8f
    add     x0, x19, #AX
    add     x1, x19, #FN
    bl      take
8:  mov     x9, #0
9:  add     x10, x19, #AX
    add     x11, x19, #NR
    ldr     x10, [x10, x9, lsl #3]
    ldr     x11, [x11, x9, lsl #3]
    cmp     x10, x11
    b.ne    v_no
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    9b
    mov     x0, #1
    b       v_out
v_no:
    mov     x0, #0
    b       v_out
v_unusable:
    mov     x0, #-1
v_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #FRAME
    ret
c256_p: .byte 255, 255, 255, 255, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255
c256_n: .byte 255, 255, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255, 188, 230, 250, 173, 167, 23, 158, 132, 243, 185, 202, 194, 252, 99, 37, 81
c256_b: .byte 90, 198, 53, 216, 170, 58, 147, 231, 179, 235, 189, 85, 118, 152, 134, 188, 101, 29, 6, 176, 204, 83, 176, 246, 59, 206, 60, 62, 39, 210, 96, 75
c256_gx: .byte 107, 23, 209, 242, 225, 44, 66, 71, 248, 188, 230, 229, 99, 164, 64, 242, 119, 3, 125, 129, 45, 235, 51, 160, 244, 161, 57, 69, 216, 152, 194, 150
c256_gy: .byte 79, 227, 66, 226, 254, 26, 127, 155, 142, 231, 235, 74, 124, 15, 158, 22, 43, 206, 51, 87, 107, 49, 94, 206, 203, 182, 64, 104, 55, 191, 81, 245
c384_p: .byte 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 254, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255
c384_n: .byte 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 199, 99, 77, 129, 244, 55, 45, 223, 88, 26, 13, 178, 72, 176, 167, 122, 236, 236, 25, 106, 204, 197, 41, 115
c384_b: .byte 179, 49, 47, 167, 226, 62, 231, 228, 152, 142, 5, 107, 227, 248, 45, 25, 24, 29, 156, 110, 254, 129, 65, 18, 3, 20, 8, 143, 80, 19, 135, 90, 198, 86, 57, 141, 138, 46, 209, 157, 42, 133, 200, 237, 211, 236, 42, 239
c384_gx: .byte 170, 135, 202, 34, 190, 139, 5, 55, 142, 177, 199, 30, 243, 32, 173, 116, 110, 29, 59, 98, 139, 167, 155, 152, 89, 247, 65, 224, 130, 84, 42, 56, 85, 2, 242, 93, 191, 85, 41, 108, 58, 84, 94, 56, 114, 118, 10, 183
c384_gy: .byte 54, 23, 222, 74, 150, 38, 44, 111, 93, 158, 152, 191, 146, 146, 220, 41, 248, 244, 29, 189, 40, 154, 20, 124, 233, 218, 49, 19, 181, 240, 184, 192, 10, 96, 177, 206, 29, 126, 129, 157, 122, 67, 29, 124, 144, 234, 14, 95
    .balign 4
