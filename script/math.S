// The curved functions of Math (stage 6), and powers that are not whole. Worked in pairs: a pair is a double and a second,
// much smaller double that says by how much the first misses, about 105 bits between them; the fused multiply-add gives a
// product's miss exactly. The answer is the pair rounded once, so it is the correctly rounded one except where the true
// value lies within about 2^-90 of halfway between two doubles (not proved absent; none met in the checks).
// dd_mul, dd_add, dd_div: the pair A (d0, d1) with the pair B (d2, d3) -> A. Use d16-d20 and nothing else.
dd_mul:
    fmul    d16, d0, d2
    fnmsub  d17, d0, d2, d16
    fmadd   d17, d0, d3, d17
    fmadd   d17, d1, d2, d17
    fadd    d0, d16, d17
    fsub    d18, d0, d16
    fsub    d1, d17, d18
    ret
dd_add:
    fadd    d16, d0, d2
    fsub    d17, d16, d0
    fsub    d18, d16, d17
    fsub    d18, d0, d18
    fsub    d19, d2, d17
    fadd    d18, d18, d19
    fadd    d19, d1, d3
    fsub    d17, d19, d1
    fsub    d20, d19, d17
    fsub    d20, d1, d20
    fsub    d17, d3, d17
    fadd    d20, d20, d17
    fadd    d18, d18, d19
    fadd    d0, d16, d18
    fsub    d17, d0, d16
    fsub    d18, d18, d17
    fadd    d18, d18, d20
    fadd    d17, d0, d18
    fsub    d19, d17, d0
    fsub    d1, d18, d19
    fmov    d0, d17
    ret
dd_div:
    fdiv    d16, d0, d2
    fmul    d17, d16, d2
    fnmsub  d18, d16, d2, d17
    fsub    d19, d0, d17
    fsub    d19, d19, d18
    fadd    d19, d19, d1
    fmsub   d19, d16, d3, d19
    fdiv    d19, d19, d2
    fadd    d0, d16, d19
    fsub    d17, d0, d16
    fsub    d1, d19, d17
    ret
    .balign 8
k_ln2:  .quad 0x3ff71547652b82fe            // 1 / ln 2; then ln 2 in three parts
        .quad 0x3fe62e42fefa39ef, 0x3c7abc9e3b39803f, 0x3907b57a079a1934
k_ln10: .quad 0x40026bb1bbb55516, 0xbcaf48ad494ea3e9
k_sqrt2: .quad 0x3ff6a09e667f3bcd
// q_exp: e to the power of the pair (d0, d1) -> d0. The power is cut to r = it - k ln 2, r / 512 goes through nine terms
// of the series 1 + r(1 + r/2(1 + r/3(...))), the sum is squared nine times and scaled by 2^k in two steps, the second a
// fused one so that the pair is rounded only once, small results included. Uses x9-x12, d0-d7, d16-d24.
q_exp:
    str     x30, [sp, #-16]!
    fcmp    d0, d0
    b.vs    9f
    mov     x9, #710
    scvtf   d16, x9
    fcmp    d0, d16
    b.gt    7f
    mov     x9, #-746
    scvtf   d16, x9
    fcmp    d0, d16
    b.lt    8f
    adr     x10, k_ln2
    ldp     d4, d5, [x10]
    ldp     d6, d7, [x10, #16]
    fmul    d16, d0, d4
    fcvtas  x11, d16
    scvtf   d22, x11
    fmul    d2, d22, d5
    fnmsub  d3, d22, d5, d2
    fneg    d2, d2
    fneg    d3, d3
    bl      dd_add
    fmul    d2, d22, d6
    fnmsub  d3, d22, d6, d2
    fneg    d2, d2
    fneg    d3, d3
    bl      dd_add
    fmsub   d1, d22, d7, d1
    mov     x9, #0x3f60000000000000
    fmov    d16, x9
    fmul    d23, d0, d16
    fmul    d24, d1, d16
    fmov    d0, #1.0
    movi    d1, #0
    mov     x12, #9
1:  fmov    d2, d23
    fmov    d3, d24
    bl      dd_mul
    scvtf   d2, x12
    movi    d3, #0
    bl      dd_div
    fmov    d2, #1.0
    movi    d3, #0
    bl      dd_add
    subs    x12, x12, #1
    b.ne    1b
    mov     x12, #9
2:  fmov    d2, d0
    fmov    d3, d1
    bl      dd_mul
    subs    x12, x12, #1
    b.ne    2b
    asr     x9, x11, #1
    sub     x10, x11, x9
    add     x9, x9, #1023
    lsl     x9, x9, #52
    fmov    d16, x9
    add     x10, x10, #1023
    lsl     x10, x10, #52
    fmov    d17, x10
    fmul    d0, d0, d16
    fmul    d1, d1, d16
    fmul    d1, d1, d17
    fmadd   d0, d0, d17, d1
9:  ldr     x30, [sp], #16
    ret
7:  mov     x9, #0x7ff0000000000000
    fmov    d0, x9
    b       9b
8:  movi    d0, #0
    b       9b
// q_log: the natural logarithm of d0 (above zero, finite) -> the pair (d0, d1). The number is m 2^e with m between root
// a half and root two; ln m = 2 atanh s, s = (m - 1) / (m + 1), by 22 terms of s(1 + s^2/3 + s^4/5 + ...); then e ln 2 is
// added. Uses x9-x12, d0-d6, d16-d28.
q_log:
    str     x30, [sp, #-16]!
    fmov    x9, d0
    mov     x11, #0
    lsr     x10, x9, #52
    cbnz    x10, 1f
    mov     x10, #0x4350000000000000    // one of the smallest numbers: times 2^54 first
    fmov    d16, x10
    fmul    d0, d0, d16
    fmov    x9, d0
    mov     x11, #-54
1:  lsr     x10, x9, #52
    sub     x10, x10, #1023
    add     x11, x11, x10
    and     x9, x9, #0x000fffffffffffff
    orr     x9, x9, #0x3ff0000000000000
    fmov    d0, x9
    ldr     d16, k_sqrt2
    fcmp    d0, d16
    b.le    2f
    fmov    d16, #0.5
    fmul    d0, d0, d16
    add     x11, x11, #1
2:  fmov    d16, #1.0
    fsub    d21, d0, d16
    fadd    d2, d0, d16
    fsub    d17, d2, d0
    fsub    d18, d2, d17
    fsub    d18, d0, d18
    fsub    d17, d16, d17
    fadd    d3, d18, d17
    fmov    d0, d21
    movi    d1, #0
    bl      dd_div
    fmov    d23, d0
    fmov    d24, d1
    fmov    d2, d0
    fmov    d3, d1
    bl      dd_mul
    fmov    d25, d0
    fmov    d26, d1
    mov     x12, #43
    fmov    d0, #1.0
    movi    d1, #0
    scvtf   d2, x12
    movi    d3, #0
    bl      dd_div
3:  sub     x12, x12, #2
    fmov    d2, d25
    fmov    d3, d26
    bl      dd_mul
    fmov    d27, d0
    fmov    d28, d1
    fmov    d0, #1.0
    movi    d1, #0
    scvtf   d2, x12
    movi    d3, #0
    bl      dd_div
    fmov    d2, d27
    fmov    d3, d28
    bl      dd_add
    cmp     x12, #1
    b.hi    3b
    fmov    d2, d23
    fmov    d3, d24
    bl      dd_mul
    fadd    d0, d0, d0
    fadd    d1, d1, d1
    adr     x10, k_ln2
    ldr     d5, [x10, #8]
    ldr     d6, [x10, #16]
    scvtf   d22, x11
    fmul    d2, d22, d5
    fnmsub  d3, d22, d5, d2
    fmadd   d3, d22, d6, d3
    bl      dd_add
    ldr     x30, [sp], #16
    ret
// q_logs: the same for any number: not a number below zero, endless at zero and at the endless
q_logs:
    movi    d1, #0
    fcmp    d0, #0.0
    b.vs    9f
    b.lt    7f
    b.eq    8f
    mov     x9, #0x7ff0000000000000
    fmov    d16, x9
    fcmp    d0, d16
    b.ne    q_log
9:  ret
7:  mov     x9, #0x7ff8000000000000
    fmov    d0, x9
    ret
8:  mov     x9, #0xfff0000000000000
    fmov    d0, x9
    ret
// m_powfrac: from the power instruction: d1 to the power d0, which is not a whole number (or is not a number)
m_powfrac:
    fcmp    d0, d0
    b.vs    9f
    fcmp    d1, d1
    b.vs    6f
    fcmp    d1, #0.0
    b.lt    7f
    b.ne    1f
    fcmp    d0, #0.0                    // zero: nothing to a power above zero, endless to one below
    movi    d0, #0
    b.gt    9f
    b       8f
1:  mov     x9, #0x7ff0000000000000
    fmov    d16, x9
    fcmp    d1, d16
    b.ne    2f
    fcmp    d0, #0.0
    b.gt    8f
    movi    d0, #0
    b       9f
2:  fmov    d29, d0
    fmov    d0, d1
    bl      q_log
    fmov    d2, d29
    movi    d3, #0
    bl      dd_mul
    bl      q_exp
9:  RESULT
6:  fmov    d0, d1
    RESULT
7:  mov     x9, #0x7ff8000000000000
    fmov    d0, x9
    RESULT
8:  mov     x9, #0x7ff0000000000000
    fmov    d0, x9
    RESULT
// 20 exp, 21 log, 22 log2, 23 log10
n_mexp:
    NIN
    ARGNUM  0
    movi    d1, #0
    bl      q_exp
    b       n_num
n_log:
    NIN
    ARGNUM  0
    bl      q_logs
    fadd    d0, d0, d1
    b       n_num
n_log2:
    adr     x2, k_ln2 + 8
    b       1f
n_log10:
    adr     x2, k_ln10
1:  NIN
    str     x2, [sp, #40]
    ARGNUM  0
    bl      q_logs
    fsub    d16, d0, d0
    fcmp    d16, #0.0
    b.ne    n_num
    ldr     x2, [sp, #40]
    ldp     d2, d3, [x2]
    bl      dd_div
    fadd    d0, d0, d1
    b       n_num
// 24 random: a number from 0 up to but not 1 (xorshift; the same run of numbers in every world until the host gives a seed)
n_random:
    ldr     x9, [x19, #W_RNG]
    cbnz    x9, 1f
    ldr     x9, =0x9e3779b97f4a7c15
1:  eor     x9, x9, x9, lsl #13
    eor     x9, x9, x9, lsr #7
    eor     x9, x9, x9, lsl #17
    str     x9, [x19, #W_RNG]
    lsr     x9, x9, #11
    ucvtf   d0, x9
    mov     x10, #0x3ca0000000000000    // 2^-53
    fmov    d1, x10
    fmul    d0, d0, d1
    fmov    x0, d0
    ret
// Sine, cosine, tangent. k_2opi: 64 noughts, then the first 1280 bits of 2/pi (most significant first), enough for the
// largest double. k_pio2: pi/2 as a pair; k_pio4.
    .balign 8
k_2opi:
    .quad 0x0000000000000000, 0xa2f9836e4e441529, 0xfc2757d1f534ddc0
    .quad 0xdb6295993c439041, 0xfe5163abdebbc561, 0xb7246e3a424dd2e0
    .quad 0x06492eea09d1921c, 0xfe1deb1cb129a73e, 0xe88235f52ebb4484
    .quad 0xe99c7026b45f7e41, 0x3991d639835339f4, 0x9c845f8bbdf9283b
    .quad 0x1ff897ffde05980f, 0xef2f118b5a0a6d1f, 0x6d367ecf27cb09b7
    .quad 0x4f463f669e5fea2d, 0x7527bac7ebe5f17b, 0x3d0739f78a5292ea
    .quad 0x6bfb5fb11f8d5d08, 0x56033046fc7b6bab, 0xf0cfbc209af4361d
k_pio2: .quad 0x3ff921fb54442d18, 0x3c91a62633145c07
k_pio4: .quad 0x3fe921fb54442d18
// q_ser: the series 1 - t/(a b)(1 - t/(c d)(1 - ...)) of fifteen terms, t the pair (d23, d24): with x13 0 the cosine's
// (divisors 1 2, 3 4, ...), with x13 1 the sine's over its angle (2 3, 4 5, ...) -> the pair (d0, d1). Uses x9, x10, x12.
q_ser:
    str     x30, [sp, #-16]!
    fmov    d0, #1.0
    movi    d1, #0
    mov     x12, #15
1:  fmov    d2, d23
    fmov    d3, d24
    bl      dd_mul
    lsl     x9, x12, #1
    add     x9, x9, x13
    sub     x10, x9, #1
    mul     x9, x9, x10
    scvtf   d2, x9
    movi    d3, #0
    bl      dd_div
    fneg    d0, d0
    fneg    d1, d1
    fmov    d2, #1.0
    movi    d3, #0
    bl      dd_add
    subs    x12, x12, #1
    b.ne    1b
    ldr     x30, [sp], #16
    ret
// q_sincos: for the number d0 (finite, not zero), taken without its sign: x11 the quarter turn its angle falls nearest
// (only the low two bits mean anything), and of what is left over, r (within pi/4 either way), the sine as the pair
// (d25, d26) and the cosine as (d27, d28); x14 keeps the number's own bits (its sign). How the angle is cut: the number is
// m 2^e, m a whole number of 53 bits; 256 bits of 2/pi are taken from where they first matter (anything earlier gives
// whole turns), m times them, kept to 256 bits, is the angle in quarter turns with 254 bits after the point. It is
// brought to the nearest quarter, made a pair exactly (53 bits and the next 53), and multiplied by pi/2.
// Uses x0-x17, d0-d3, d16-d31.
q_sincos:
    str     x30, [sp, #-16]!
    fmov    x14, d0
    fabs    d29, d0
    mov     x11, #0
    ldr     d16, k_pio4
    fcmp    d29, d16
    b.hi    1f
    fmov    d0, d29
    movi    d1, #0
    b       8f
1:  fmov    x9, d29
    lsr     x10, x9, #52
    and     x9, x9, #0x000fffffffffffff
    orr     x9, x9, #0x0010000000000000
    sub     x10, x10, #(1075 - 62)
    lsr     x15, x10, #6
    and     x10, x10, #63
    adr     x16, k_2opi
    add     x16, x16, x15, lsl #3
    ldp     x0, x1, [x16]
    ldp     x2, x3, [x16, #16]
    ldr     x4, [x16, #32]
    cbz     x10, 2f
    mov     x17, #64
    sub     x17, x17, x10
    lsl     x0, x0, x10
    lsr     x5, x1, x17
    orr     x0, x0, x5
    lsl     x1, x1, x10
    lsr     x5, x2, x17
    orr     x1, x1, x5
    lsl     x2, x2, x10
    lsr     x5, x3, x17
    orr     x2, x2, x5
    lsl     x3, x3, x10
    lsr     x5, x4, x17
    orr     x3, x3, x5
2:  mul     x4, x9, x3
    umulh   x5, x9, x3
    mul     x6, x9, x2
    umulh   x7, x9, x2
    adds    x6, x6, x5
    adc     x7, x7, xzr
    mul     x5, x9, x1
    umulh   x8, x9, x1
    adds    x5, x5, x7
    adc     x8, x8, xzr
    mul     x7, x9, x0
    add     x7, x7, x8
    lsr     x11, x7, #62
    extr    x7, x7, x5, #62
    extr    x5, x5, x6, #62
    extr    x6, x6, x4, #62
    lsl     x4, x4, #2
    mov     x15, #0
    tbz     x7, #63, 3f
    add     x11, x11, #1                // past half way: the next quarter, and what is left is below it
    mov     x15, #1
    mvn     x4, x4
    mvn     x6, x6
    mvn     x5, x5
    mvn     x7, x7
    adds    x4, x4, #1
    adcs    x6, x6, xzr
    adcs    x5, x5, xzr
    adc     x7, x7, xzr
3:  mov     x16, #0
4:  cbnz    x7, 5f
    mov     x7, x5
    mov     x5, x6
    mov     x6, x4
    mov     x4, #0
    add     x16, x16, #64
    cmp     x16, #256
    b.lo    4b
    movi    d0, #0
    movi    d1, #0
    b       8f
5:  clz     x17, x7
    cbz     x17, 6f
    mov     x8, #64
    sub     x8, x8, x17
    lsl     x7, x7, x17
    lsr     x9, x5, x8
    orr     x7, x7, x9
    lsl     x5, x5, x17
    lsr     x9, x6, x8
    orr     x5, x5, x9
    add     x16, x16, x17
6:  lsr     x9, x7, #11
    ucvtf   d0, x9
    and     x9, x7, #0x7ff
    lsl     x9, x9, #42
    orr     x9, x9, x5, lsr #22
    ucvtf   d1, x9
    mov     x9, #(1023 - 53)
    sub     x9, x9, x16
    lsl     x9, x9, #52
    fmov    d16, x9
    fmul    d0, d0, d16
    mov     x9, #(1023 - 106)
    sub     x9, x9, x16
    lsl     x9, x9, #52
    fmov    d16, x9
    fmul    d1, d1, d16
    cbz     x15, 7f
    fneg    d0, d0
    fneg    d1, d1
7:  adr     x9, k_pio2
    ldp     d2, d3, [x9]
    bl      dd_mul
8:  fmov    d30, d0
    fmov    d31, d1
    fmov    d2, d0
    fmov    d3, d1
    bl      dd_mul
    fmov    d23, d0
    fmov    d24, d1
    mov     x13, #1
    bl      q_ser
    fmov    d2, d30
    fmov    d3, d31
    bl      dd_mul
    fmov    d25, d0
    fmov    d26, d1
    mov     x13, #0
    bl      q_ser
    fmov    d27, d0
    fmov    d28, d1
    ldr     x30, [sp], #16
    ret
// 25 sin, 26 cos, 27 tan
n_sin:
    mov     x2, #0
    b       1f
n_cos:
    mov     x2, #1
    b       1f
n_tan:
    mov     x2, #2
1:  NIN
    str     x2, [sp, #40]
    ARGNUM  0
    fsub    d16, d0, d0
    fcmp    d16, #0.0
    b.ne    9f
    fcmp    d0, #0.0
    b.ne    2f
    ldr     x2, [sp, #40]               // nought: itself, sign and all; its cosine is 1
    cmp     x2, #1
    b.ne    n_num
    fmov    d0, #1.0
    b       n_num
2:  bl      q_sincos
    ldr     x2, [sp, #40]
    cmp     x2, #2
    b.eq    5f
    add     x11, x11, x2                // the cosine is the sine a quarter turn on
    tbnz    x11, #0, 3f
    fadd    d0, d25, d26
    b       4f
3:  fadd    d0, d27, d28
4:  tbz     x11, #1, 41f
    fneg    d0, d0
41: cbnz    x2, n_num
    b       7f
5:  tbnz    x11, #0, 6f
    fmov    d0, d25
    fmov    d1, d26
    fmov    d2, d27
    fmov    d3, d28
    bl      dd_div
    fadd    d0, d0, d1
    b       7f
6:  fmov    d0, d27
    fmov    d1, d28
    fmov    d2, d25
    fmov    d3, d26
    bl      dd_div
    fadd    d0, d0, d1
    fneg    d0, d0
7:  tbz     x14, #63, n_num             // an odd function: the number's sign goes to the answer
    fneg    d0, d0
    b       n_num
9:  mov     x0, #0x7ff8000000000000
    NOUT
    .ltorg
