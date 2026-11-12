// A number as text, exactly as the language says: the shortest digits that read back as the same number (the method of
// Steele and White as put by Burger and Dybvig: whole-number arithmetic on long numbers, no approximation), then laid out
// as plain digits, a decimal fraction, or with an exponent, by where the point falls.
// Long numbers here are 24 limbs of 64 bits, lowest first (1536 bits: enough for any double's digits).
    .equ BN, 192
// bn_small: the long number at x0 becomes the small number x1. Uses x9.
bn_small:
    mov     x9, #1
1:  str     xzr, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #24
    b.lo    1b
    str     x1, [x0]
    ret
// bn_times: the long number at x0 times the small number x1, in place. Uses x9-x13.
bn_times:
    mov     x9, #0
    mov     x10, #0
1:  ldr     x11, [x0, x9, lsl #3]
    mul     x12, x11, x1
    umulh   x13, x11, x1
    adds    x12, x12, x10
    adc     x10, x13, xzr
    str     x12, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #24
    b.lo    1b
    ret
// bn_shift: the long number at x0 times 2 to the power x1 (0 to 1200), in place. Uses x9-x14.
bn_shift:
    lsr     x9, x1, #6                  // whole limbs
    and     x10, x1, #63                // and bits
    mov     x11, #23
1:  subs    x12, x11, x9                // from the top down: limb i takes from limb i - whole and the one below it
    mov     x13, #0
    b.lt    3f
    ldr     x13, [x0, x12, lsl #3]
    lsl     x13, x13, x10
    cbz     x10, 3f
    subs    x12, x12, #1
    b.lt    3f
    ldr     x14, [x0, x12, lsl #3]
    neg     x12, x10
    lsr     x14, x14, x12
    orr     x13, x13, x14
3:  str     x13, [x0, x11, lsl #3]
    subs    x11, x11, #1
    b.ge    1b
    ret
// bn_add: the long number at x0 gains the one at x1. Uses x9-x12.
bn_add:
    mov     x9, #0
    adds    x10, xzr, xzr
1:  ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    adcs    x10, x10, x11
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x9, #24
    cbnz    x12, 1b
    ret
// bn_less: the long number at x0 loses the one at x1 (which is not larger). Uses x9-x12.
bn_less:
    mov     x9, #0
    cmp     x9, x9
1:  ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    sbcs    x10, x10, x11
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x9, #24
    cbnz    x12, 1b
    ret
// bn_order: the long numbers at x0 and x1 compared -> flags as after "cmp first, second" for unsigned numbers. Uses x9-x11.
bn_order:
    mov     x9, #24
1:  sub     x9, x9, #1
    ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    cmp     x10, x11
    b.ne    2f
    cbnz    x9, 1b
2:  ret

    // the frame of num_text
    .equ N_R, 16
    .equ N_S, N_R + BN
    .equ N_UP, N_S + BN
    .equ N_DOWN, N_UP + BN
    .equ N_T, N_DOWN + BN
    .equ N_DIGITS, N_T + BN
    .equ N_OUT, N_DIGITS + 32
    .equ N_KEPT, N_OUT + 48
    .equ N_FRAME, N_KEPT + 64
    .macro  BNP reg, off
    add     \reg, sp, #\off
    .endm
// num_text: the number d0 as a string value -> x0 (0 if the world is full)
num_text:
    sub     sp, sp, #N_FRAME
    stp     x29, x30, [sp]
    BNP     x29, N_KEPT
    stp     x20, x21, [x29]
    stp     x22, x23, [x29, #16]
    stp     x24, x25, [x29, #32]
    stp     x26, x27, [x29, #48]
    fmov    x20, d0
    fcmp    d0, d0
    b.vc    1f
    adr     x0, n_nan
    mov     x1, #3
    b       n_make
1:  BNP     x26, N_OUT                  // x26: where the text is being written
    tbz     x20, #63, 2f
    and     x20, x20, #0x7fffffffffffffff
    fmov    d1, x20
    fcmp    d1, #0.0
    b.eq    2f                          // minus zero prints as 0
    mov     w9, #'-'
    strb    w9, [x26], #1
2:  ldr     x9, =0x7ff0000000000000
    cmp     x20, x9
    b.ne    3f
    adr     x9, n_inf
    ldr     x10, [x9]
    str     x10, [x26], #8
    b       n_finish
3:  cbnz    x20, 4f
    mov     w9, #'0'
    strb    w9, [x26], #1
    b       n_finish
4:  ubfx    x21, x20, #52, #11          // the number is f times 2 to the e
    and     x20, x20, #0xfffffffffffff
    cbz     x21, 5f
    orr     x20, x20, #0x10000000000000
    sub     x21, x21, #1075
    b       6f
5:  mov     x21, #-1074
6:  clz     x9, x20                     // roughly which power of ten: from how many bits the number has
    mov     x10, #64
    sub     x10, x10, x9
    add     x10, x10, x21               // bits before the point (may be negative)
    sub     x10, x10, #1
    scvtf   d1, x10
    ldr     x9, =0x3fd34413509f79ff     // log of 2 to base 10
    fmov    d2, x9
    fmul    d1, d1, d2
    ldr     x9, =0x3ddb7cdfd9d7bdbb     // a hair less, so the guess is never too high
    fmov    d2, x9
    fsub    d1, d1, d2
    fcvtps  x22, d1                     // x22: the guessed power of ten k (the value is 0.digits times 10 to the k)
    mov     x9, #0x10000000000000
    cmp     x20, x9
    cset    w23, eq                     // x23: is f the smallest for its exponent (then the gap below is half the gap above)
    mov     x9, #-1074
    cmp     x21, x9
    csel    w23, wzr, w23, eq
    and     w24, w20, #1
    eor     w24, w24, #1                // x24: f even, so the ends of its range round to it
    BNP     x0, N_R                     // r / s is the number; "up" and "down" are half the gaps to its neighbours, on the same scale
    mov     x1, x20
    bl      bn_small
    BNP     x0, N_S
    mov     x1, #1
    bl      bn_small
    BNP     x0, N_UP
    mov     x1, #1
    bl      bn_small
    BNP     x0, N_DOWN
    mov     x1, #1
    bl      bn_small
    add     w25, w23, #1                // one more doubling everywhere when the gap below is the smaller
    cmp     x21, #0
    b.lt    7f
    BNP     x0, N_R
    add     x1, x21, x25
    bl      bn_shift
    BNP     x0, N_S
    mov     x1, x25
    bl      bn_shift
    BNP     x0, N_UP
    add     x1, x21, x23
    bl      bn_shift
    BNP     x0, N_DOWN
    mov     x1, x21
    bl      bn_shift
    b       8f
7:  BNP     x0, N_R
    mov     x1, x25
    bl      bn_shift
    BNP     x0, N_S
    neg     x1, x21
    add     x1, x1, x25
    bl      bn_shift
    BNP     x0, N_UP
    mov     x1, x23
    bl      bn_shift
8:  mov     x27, x22                    // scale by ten to the k: s if k is positive, the others if negative
    cmp     x27, #0
    b.eq    11f
    b.lt    10f
9:  BNP     x0, N_S
    mov     x1, #10
    bl      bn_times
    subs    x27, x27, #1
    b.ne    9b
    b       11f
10: BNP     x0, N_R
    mov     x1, #10
    bl      bn_times
    BNP     x0, N_UP
    mov     x1, #10
    bl      bn_times
    BNP     x0, N_DOWN
    mov     x1, #10
    bl      bn_times
    adds    x27, x27, #1
    b.ne    10b
11: bl      n_high                      // is the guess one too low? (r + up reaches s)
    b.hs    12f
    BNP     x0, N_R                     // no: bring the first digit up
    mov     x1, #10
    bl      bn_times
    BNP     x0, N_UP
    mov     x1, #10
    bl      bn_times
    BNP     x0, N_DOWN
    mov     x1, #10
    bl      bn_times
    b       13f
12: add     x22, x22, #1
13: mov     x27, #0                     // digits made
n_digit:
    mov     w25, #0                     // the digit: how many times s goes into r
14: BNP     x0, N_R
    BNP     x1, N_S
    bl      bn_order
    b.lo    15f
    BNP     x0, N_R
    BNP     x1, N_S
    bl      bn_less
    add     w25, w25, #1
    b       14b
15: BNP     x0, N_R                     // may we stop: is what is left within the gap below (then this digit will do)...
    BNP     x1, N_DOWN
    bl      bn_order
    cset    w9, lo
    cset    w10, ls
    cmp     w24, #0
    csel    w23, w10, w9, ne
    bl      n_high                      // ...or within the gap above (then the next digit up will do)
    cset    w9, hs
    orr     w10, w23, w9
    cbnz    w10, 16f
    add     w25, w25, #'0'
    BNP     x9, N_DIGITS
    strb    w25, [x9, x27]
    add     x27, x27, #1
    BNP     x0, N_R
    mov     x1, #10
    bl      bn_times
    BNP     x0, N_UP
    mov     x1, #10
    bl      bn_times
    BNP     x0, N_DOWN
    mov     x1, #10
    bl      bn_times
    b       n_digit
16: cbz     w9, 18f                     // the last digit: this one, the next up, or whichever is nearer when both would do
    cbz     w23, 17f
    BNP     x0, N_T
    BNP     x1, N_R
    mov     x9, #0
19: ldr     x10, [x1, x9, lsl #3]
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #24
    b.lo    19b
    mov     x1, #1
    bl      bn_shift
    BNP     x0, N_T
    BNP     x1, N_S
    bl      bn_order
    b.lo    18f
17: add     w25, w25, #1
18: add     w25, w25, #'0'
    BNP     x9, N_DIGITS
    strb    w25, [x9, x27]
    add     x27, x27, #1
    // the digits are x27 long and the value is 0.digits times ten to the x22. Laid out by where the point falls.
    BNP     x9, N_DIGITS
    cmp     x22, #21
    b.gt    n_exp
    cmp     x22, x27
    b.lt    21f
    mov     x10, #0                     // whole: the digits, then zeros
20: ldrb    w11, [x9, x10]
    strb    w11, [x26], #1
    add     x10, x10, #1
    cmp     x10, x27
    b.lo    20b
    mov     w11, #'0'
    sub     x10, x22, x27
22: cbz     x10, n_finish
    strb    w11, [x26], #1
    sub     x10, x10, #1
    b       22b
21: cmp     x22, #0
    b.le    24f
    mov     x10, #0                     // a point among the digits
23: cmp     x10, x22
    b.ne    25f
    mov     w11, #'.'
    strb    w11, [x26], #1
25: ldrb    w11, [x9, x10]
    strb    w11, [x26], #1
    add     x10, x10, #1
    cmp     x10, x27
    b.lo    23b
    b       n_finish
24: cmn     x22, #5
    b.lt    n_exp
    mov     w11, #'0'                   // a small fraction: 0. then zeros then the digits
    strb    w11, [x26], #1
    mov     w12, #'.'
    strb    w12, [x26], #1
    neg     x10, x22
26: cbz     x10, 27f
    strb    w11, [x26], #1
    sub     x10, x10, #1
    b       26b
27: mov     x10, #0
28: ldrb    w11, [x9, x10]
    strb    w11, [x26], #1
    add     x10, x10, #1
    cmp     x10, x27
    b.lo    28b
    b       n_finish
n_exp:                                  // very large or very small: one digit, a point, the rest, e, the power
    ldrb    w11, [x9]
    strb    w11, [x26], #1
    cmp     x27, #1
    b.eq    30f
    mov     w11, #'.'
    strb    w11, [x26], #1
    mov     x10, #1
29: ldrb    w11, [x9, x10]
    strb    w11, [x26], #1
    add     x10, x10, #1
    cmp     x10, x27
    b.lo    29b
30: mov     w11, #'e'
    strb    w11, [x26], #1
    sub     x10, x22, #1
    mov     w11, #'+'
    cmp     x10, #0
    b.ge    31f
    mov     w11, #'-'
    neg     x10, x10
31: strb    w11, [x26], #1
    mov     x11, #100
    cmp     x10, #100
    b.lo    32f
    udiv    x12, x10, x11
    msub    x10, x12, x11, x10
    add     w12, w12, #'0'
    strb    w12, [x26], #1
    mov     x11, #10
    udiv    x12, x10, x11
    msub    x10, x12, x11, x10
    add     w12, w12, #'0'
    strb    w12, [x26], #1
    b       33f
32: cmp     x10, #10
    b.lo    33f
    mov     x11, #10
    udiv    x12, x10, x11
    msub    x10, x12, x11, x10
    add     w12, w12, #'0'
    strb    w12, [x26], #1
33: add     w10, w10, #'0'
    strb    w10, [x26], #1
n_finish:
    BNP     x0, N_OUT
    sub     x1, x26, x0
n_make:
    bl      w_string
    BNP     x29, N_KEPT
    ldp     x20, x21, [x29]
    ldp     x22, x23, [x29, #16]
    ldp     x24, x25, [x29, #32]
    ldp     x26, x27, [x29, #48]
    ldp     x29, x30, [sp]
    add     sp, sp, #N_FRAME
    ret
// n_high: does r + up reach s (pass it, when the range's ends do not round to the number) -> flags: hs if so
n_high:
    mov     x15, x30
    add     x0, sp, #N_T
    add     x1, sp, #N_R
    mov     x9, #0
1:  ldr     x10, [x1, x9, lsl #3]
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #24
    b.lo    1b
    add     x1, sp, #N_UP
    bl      bn_add
    add     x0, sp, #N_T
    add     x1, sp, #N_S
    bl      bn_order
    cset    w9, hs
    cset    w10, hi
    cmp     w24, #0
    csel    w9, w9, w10, ne
    cmp     w9, #1
    ret     x15
n_nan:  .ascii "NaN"
    .balign 8
n_inf:  .ascii "Infinity"
    .ltorg
