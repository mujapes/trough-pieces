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
// q_expp: e to the power of the pair (d0, d1), within 746 either way -> the pair (d0, d1) and x11: the answer is the pair
// times 2^x11. Uses x9-x12, d0-d7, d16-d24.
q_expp:
    str     x30, [sp, #-16]!
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
    ldr     x30, [sp], #16
    ret
// q_scale: the pair (d0, d1) times 2^x11 -> d0, rounded once (in two steps, the second a fused one). Uses x9, x10, d16, d17.
q_scale:
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
    ret
// dd_sqrt: the square root of the pair (d0, d1), not below zero -> the pair. Uses d16-d19.
dd_sqrt:
    fcmp    d0, #0.0
    b.eq    9f
    fsqrt   d16, d0
    fmul    d17, d16, d16
    fnmsub  d18, d16, d16, d17
    fsub    d19, d0, d17
    fsub    d19, d19, d18
    fadd    d19, d19, d1
    fadd    d17, d16, d16
    fdiv    d19, d19, d17
    fadd    d0, d16, d19
    fsub    d17, d0, d16
    fsub    d1, d19, d17
9:  ret
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
    bl      q_expp
    bl      q_scale
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
// The arc functions. k_atan: the arc tangent of 0/8, 1/8, ... 8/8 as pairs.
    .balign 8
k_atan:
    .quad 0x0000000000000000, 0x0000000000000000
    .quad 0x3fbfd5ba9aac2f6e, 0xbc4cd37686760c17
    .quad 0x3fcf5b75f92c80dd, 0x3c68ab6e3cf7afbd
    .quad 0x3fd6f61941e4def1, 0xbc7c63aae6f6e918
    .quad 0x3fddac670561bb4f, 0x3c7a2b7f222f65e2
    .quad 0x3fe1e00babdefeb4, 0xbc5928df287a668f
    .quad 0x3fe4978fa3269ee1, 0x3c72419a87f2a458
    .quad 0x3fe700a7c5784634, 0xbc78c34d25aadef6
    .quad 0x3fe921fb54442d18, 0x3c81a62633145c07
// q_atan2: the angle of the point whose height is the pair Y (d0, d1) and whose distance along is the pair X (d2, d3), both
// finite and not both nought -> the pair (d0, d1), from minus pi to pi. The smaller (without signs) over the larger is t,
// from 0 to 1; c is the nearest eighth to t and u = (t - c) / (1 + t c), at most a sixteenth; the angle of u is
// u(1 - u^2/3 + u^4/5 - ...) to u^30, and the table gives the angle of c. Then pi/2 less it if the two were changed over,
// pi less that if X was below nought, and Y's sign. Uses x9, x10, x12-x15, d0-d3, d16-d29.
q_atan2:
    str     x30, [sp, #-16]!
    fmov    x14, d0
    fmov    x15, d2
    tbz     x14, #63, 1f
    fneg    d0, d0
    fneg    d1, d1
1:  tbz     x15, #63, 2f
    fneg    d2, d2
    fneg    d3, d3
2:  mov     x13, #0
    fcmp    d0, d2
    b.le    3f
    mov     x13, #1
    fmov    d16, d0
    fmov    d0, d2
    fmov    d2, d16
    fmov    d16, d1
    fmov    d1, d3
    fmov    d3, d16
3:  bl      dd_div
    fmov    d21, d0
    fmov    d22, d1
    fmov    d16, #8.0
    fmul    d16, d0, d16
    fcvtas  x10, d16
    cbz     x10, 4f
    scvtf   d29, x10
    fmov    d16, #0.125
    fmul    d29, d29, d16
    fmov    d2, d29
    movi    d3, #0
    bl      dd_mul
    fmov    d2, #1.0
    movi    d3, #0
    bl      dd_add
    fmov    d27, d0
    fmov    d28, d1
    fmov    d0, d21
    fmov    d1, d22
    fneg    d2, d29
    movi    d3, #0
    bl      dd_add
    fmov    d2, d27
    fmov    d3, d28
    bl      dd_div
4:  fmov    d23, d0
    fmov    d24, d1
    fmov    d2, d0
    fmov    d3, d1
    bl      dd_mul
    fmov    d25, d0
    fmov    d26, d1
    mov     x12, #31
    fmov    d0, #1.0
    movi    d1, #0
    scvtf   d2, x12
    movi    d3, #0
    bl      dd_div
5:  sub     x12, x12, #2
    fmov    d2, d25
    fmov    d3, d26
    bl      dd_mul
    fneg    d27, d0
    fneg    d28, d1
    fmov    d0, #1.0
    movi    d1, #0
    scvtf   d2, x12
    movi    d3, #0
    bl      dd_div
    fmov    d2, d27
    fmov    d3, d28
    bl      dd_add
    cmp     x12, #1
    b.hi    5b
    fmov    d2, d23
    fmov    d3, d24
    bl      dd_mul
    adr     x9, k_atan
    add     x9, x9, x10, lsl #4
    ldp     d2, d3, [x9]
    bl      dd_add
    cbz     x13, 6f
    fneg    d2, d0
    fneg    d3, d1
    adr     x9, k_pio2
    ldp     d0, d1, [x9]
    bl      dd_add
6:  tbz     x15, #63, 7f
    fneg    d2, d0
    fneg    d3, d1
    adr     x9, k_pio2
    ldp     d0, d1, [x9]
    fadd    d0, d0, d0
    fadd    d1, d1, d1
    bl      dd_add
7:  tbz     x14, #63, 8f
    fneg    d0, d0
    fneg    d1, d1
8:  ldr     x30, [sp], #16
    ret
// 31 atan, 32 atan2, 33 asin, 34 acos
n_atan:
    NIN
    ARGNUM  0
    fcmp    d0, #0.0
    b.vs    n_num
    b.eq    n_num
    fmov    d2, #1.0
    fabs    d4, d0
    mov     x9, #0x7ff0000000000000
    fmov    d6, x9
    fcmp    d4, d6
    b.ne    1f
    fmov    x9, d0                      // endless: a quarter turn, by the point (1, 0) stood on end
    fmov    d0, #1.0
    movi    d2, #0
    tbz     x9, #63, 1f
    fneg    d0, d0
1:  movi    d1, #0
    movi    d3, #0
    bl      q_atan2
    fadd    d0, d0, d1
    b       n_num
n_atan2:
    NIN
    ARGNUM  0
    str     d0, [sp, #40]
    ARGNUM  1
    fmov    d2, d0
    ldr     d0, [sp, #40]
    fcmp    d0, d2
    b.vs    9f
    fabs    d4, d0
    fabs    d5, d2
    mov     x9, #0x7ff0000000000000
    fmov    d6, x9
    fcmp    d4, d6
    b.eq    1f
    fcmp    d5, d6
    b.ne    3f
1:  fmov    d7, #1.0                    // one of them endless: an endless one counts as 1 and the other as nought
    movi    d16, #0
    fcmp    d4, d6
    fcsel   d4, d7, d16, eq
    fcmp    d5, d6
    fcsel   d5, d7, d16, eq
    fmov    x9, d0
    fmov    x10, d4
    and     x9, x9, #0x8000000000000000
    orr     x10, x10, x9
    fmov    d0, x10
    fmov    x9, d2
    fmov    x10, d5
    and     x9, x9, #0x8000000000000000
    orr     x10, x10, x9
    fmov    d2, x10
3:  fcmp    d0, #0.0
    b.ne    5f
    fmov    x9, d2                      // no height: nought itself (its sign kept) forwards, pi with its sign backwards
    tbz     x9, #63, n_num
    ldr     d1, k_pio2
    fadd    d1, d1, d1
    fmov    x9, d0
    fmov    d0, d1
    tbz     x9, #63, n_num
    fneg    d0, d0
    b       n_num
5:  movi    d1, #0
    movi    d3, #0
    bl      q_atan2
    fadd    d0, d0, d1
    b       n_num
9:  mov     x0, #0x7ff8000000000000
    NOUT
n_asin:
    mov     x2, #0
    b       1f
n_acos:
    mov     x2, #1
1:  NIN
    str     x2, [sp, #40]
    ARGNUM  0
    fabs    d4, d0
    fmov    d5, #1.0
    fcmp    d4, d5
    b.hi    9b
    ldr     x2, [sp, #40]
    cbnz    x2, 2f
    fcmp    d0, #0.0
    b.eq    n_num
2:  fmov    d30, d0                     // the root of (1 - x)(1 + x) is the other side of the triangle
    fmov    d0, #1.0
    movi    d1, #0
    fneg    d2, d30
    movi    d3, #0
    bl      dd_add
    fmov    d27, d0
    fmov    d28, d1
    fmov    d0, #1.0
    movi    d1, #0
    fmov    d2, d30
    movi    d3, #0
    bl      dd_add
    fmov    d2, d27
    fmov    d3, d28
    bl      dd_mul
    bl      dd_sqrt
    ldr     x2, [sp, #40]
    cbnz    x2, 3f
    fmov    d2, d0
    fmov    d3, d1
    fmov    d0, d30
    movi    d1, #0
    b       4f
3:  fmov    d2, d30
    movi    d3, #0
4:  bl      q_atan2
    fadd    d0, d0, d1
    b       n_num
// 35 expm1: below a thirty-second by its own series x(1 + x/2(1 + x/3(...))), otherwise e^x as a pair less one
n_expm1:
    NIN
    ARGNUM  0
    fcmp    d0, #0.0
    b.vs    n_num
    b.eq    n_num
    fabs    d4, d0
    mov     x9, #0x3fa0000000000000
    fmov    d5, x9
    fcmp    d4, d5
    b.hs    3f
    fmov    d23, d0
    movi    d24, #0
    fmov    d0, #1.0
    movi    d1, #0
    mov     x12, #16
1:  fmov    d2, d23
    fmov    d3, d24
    bl      dd_mul
    scvtf   d2, x12
    movi    d3, #0
    bl      dd_div
    fmov    d2, #1.0
    movi    d3, #0
    bl      dd_add
    sub     x12, x12, #1
    cmp     x12, #1
    b.hi    1b
    fmov    d2, d23
    fmov    d3, d24
    bl      dd_mul
    fadd    d0, d0, d1
    b       n_num
3:  mov     x9, #709
    scvtf   d5, x9
    fcmp    d0, d5
    b.le    4f
    movi    d1, #0
    bl      q_exp
    b       n_num
4:  mov     x9, #-50
    scvtf   d5, x9
    fcmp    d0, d5
    b.ge    5f
    fmov    d0, #-1.0
    b       n_num
5:  movi    d1, #0
    bl      q_expp
    add     x9, x11, #1023
    lsl     x9, x9, #52
    fmov    d16, x9
    fmul    d0, d0, d16
    fmul    d1, d1, d16
    fmov    d2, #-1.0
    movi    d3, #0
    bl      dd_add
    fadd    d0, d0, d1
    b       n_num
// q_log1pp: the logarithm of 1 + w, w the pair (d0, d1) above -1 and finite -> the pair. u = 1 + w as the machine rounds
// it and c what that lost (exactly, with w's second half); the answer is ln u + d - d^2/2, d = c / u.
// Uses what q_log does, and d29-d31.
q_log1pp:
    str     x30, [sp, #-16]!
    fmov    d31, d1
    fmov    d16, #1.0
    fadd    d29, d0, d16
    fsub    d17, d29, d16
    fsub    d18, d29, d17
    fsub    d18, d16, d18
    fsub    d17, d0, d17
    fadd    d30, d18, d17
    fmov    d0, d29
    bl      q_log
    fmov    d27, d0
    fmov    d28, d1
    fmov    d0, d30
    movi    d1, #0
    fmov    d2, d31
    movi    d3, #0
    bl      dd_add
    fmov    d2, d29
    movi    d3, #0
    bl      dd_div
    fmul    d16, d0, d0
    fmov    d17, #0.5
    fmsub   d1, d16, d17, d1
    fmov    d2, d27
    fmov    d3, d28
    bl      dd_add
    ldr     x30, [sp], #16
    ret
// 36 log1p
n_log1p:
    NIN
    ARGNUM  0
    fcmp    d0, #0.0
    b.vs    n_num
    b.eq    n_num
    fmov    d16, #-1.0
    fcmp    d0, d16
    b.lt    n_notnum
    b.eq    1f
    mov     x9, #0x7ff0000000000000
    fmov    d16, x9
    fcmp    d0, d16
    b.eq    n_num
    movi    d1, #0
    bl      q_log1pp
    fadd    d0, d0, d1
    b       n_num
1:  mov     x0, #0xfff0000000000000
    NOUT
n_notnum:
    mov     x0, #0x7ff8000000000000
    NOUT
// 43 asinh, 44 acosh, 45 atanh, all by q_log1pp: asinh a = log1p(a + a^2 / (1 + root(a^2 + 1))); acosh x =
// log1p(t + root(t (x + 1))), t = x - 1; atanh a = log1p(2a / (1 - a)) / 2. Past 2^60 the first two are ln a + ln 2.
n_asinh:
    mov     x2, #0
    b       1f
n_acosh:
    mov     x2, #1
    b       1f
n_atanh:
    mov     x2, #2
1:  NIN
    str     x2, [sp, #40]
    ARGNUM  0
    ldr     x2, [sp, #40]
    fcmp    d0, d0
    b.vs    n_num
    fmov    x14, d0
    fabs    d7, d0
    mov     x9, #0x7ff0000000000000
    fmov    d5, x9
    cmp     x2, #1
    b.eq    4f
    b.hi    6f
    fcmp    d7, #0.0
    b.eq    n_num
    fcmp    d7, d5
    b.eq    n_num
    mov     x9, #0x43b0000000000000
    fmov    d16, x9
    fcmp    d7, d16
    b.hi    3f
    fmul    d0, d7, d7
    fnmsub  d1, d7, d7, d0
    fmov    d21, d0
    fmov    d22, d1
    fmov    d2, #1.0
    movi    d3, #0
    bl      dd_add
    bl      dd_sqrt
    fmov    d2, #1.0
    movi    d3, #0
    bl      dd_add
    fmov    d2, d0
    fmov    d3, d1
    fmov    d0, d21
    fmov    d1, d22
    bl      dd_div
    fmov    d2, d7
    movi    d3, #0
    bl      dd_add
    bl      q_log1pp
    b       8f
3:  fmov    d0, d7
    bl      q_log
    adr     x9, k_ln2
    ldp     d2, d3, [x9, #8]
    bl      dd_add
    b       8f
4:  fmov    d16, #1.0
    fcmp    d0, d16
    b.lt    n_notnum
    b.ne    41f
    movi    d0, #0
    b       n_num
41: fcmp    d0, d5
    b.eq    n_num
    mov     x9, #0x43b0000000000000
    fmov    d16, x9
    fcmp    d7, d16
    b.hi    3b
    fmov    d0, d7
    movi    d1, #0
    fmov    d2, #-1.0
    movi    d3, #0
    bl      dd_add
    fmov    d21, d0
    fmov    d22, d1
    fmov    d0, d7
    movi    d1, #0
    fmov    d2, #1.0
    movi    d3, #0
    bl      dd_add
    fmov    d2, d21
    fmov    d3, d22
    bl      dd_mul
    bl      dd_sqrt
    fmov    d2, d21
    fmov    d3, d22
    bl      dd_add
    bl      q_log1pp
    b       8f
6:  fmov    d16, #1.0
    fcmp    d7, d16
    b.hi    n_notnum
    b.ne    61f
    fmov    d0, d5
    movi    d1, #0
    b       8f
61: fcmp    d7, #0.0
    b.eq    n_num
    fmov    d0, #1.0
    movi    d1, #0
    fneg    d2, d7
    movi    d3, #0
    bl      dd_add
    fmov    d2, d0
    fmov    d3, d1
    fadd    d0, d7, d7
    movi    d1, #0
    bl      dd_div
    bl      q_log1pp
    fmov    d16, #0.5
    fmul    d0, d0, d16
    fmul    d1, d1, d16
8:  fadd    d0, d0, d1
    tbz     x14, #63, n_num
    fneg    d0, d0
    b       n_num
// 46 fround, 47 clz32, 48 imul
n_fround:
    NIN
    ARGNUM  0
    fcvt    s0, d0
    fcvt    d0, s0
    b       n_num
n_clz32:
    NIN
    ARGNUM  0
    bl      v_int32
    clz     w0, w0
    ucvtf   d0, w0
    b       n_num
n_imul:
    NIN
    ARGNUM  0
    bl      v_int32
    str     x0, [sp, #40]
    ARGNUM  1
    bl      v_int32
    ldr     x9, [sp, #40]
    mul     w0, w0, w9
    scvtf   d0, w0
    b       n_num
// 37 sinh, 38 cosh, 39 tanh. Below a half, sinh and tanh go by the sine's and cosine's series with the square's sign
// turned; otherwise by E = e^|x| as a pair: (E - 1/E) / 2, (E + 1/E) / 2, and the first over the second. Past 40 the 1/E
// is too small to tell.
n_sinh:
    mov     x2, #0
    b       1f
n_cosh:
    mov     x2, #1
    b       1f
n_tanh:
    mov     x2, #2
1:  NIN
    str     x2, [sp, #40]
    ARGNUM  0
    ldr     x2, [sp, #40]
    fcmp    d0, #0.0
    b.vs    n_num
    b.ne    2f
    cmp     x2, #1
    b.ne    n_num
    fmov    d0, #1.0
    b       n_num
2:  fmov    x14, d0
    mov     x15, x2
    fabs    d29, d0
    fmov    d16, #0.5
    fcmp    d29, d16
    b.hs    5f
    cmp     x15, #1
    b.eq    6f
    fmul    d0, d29, d29
    fnmsub  d1, d29, d29, d0
    fneg    d23, d0
    fneg    d24, d1
    mov     x13, #1
    bl      q_ser
    fmov    d2, d29
    movi    d3, #0
    bl      dd_mul
    cmp     x15, #2
    b.ne    8f
    fmov    d30, d0
    fmov    d31, d1
    mov     x13, #0
    bl      q_ser
    fmov    d2, d0
    fmov    d3, d1
    fmov    d0, d30
    fmov    d1, d31
    bl      dd_div
    b       8f
5:  mov     x9, #40
    scvtf   d16, x9
    fcmp    d29, d16
    b.ls    6f
    cmp     x15, #2
    b.ne    51f
    fmov    d0, #1.0
    movi    d1, #0
    b       8f
51: mov     x9, #711
    scvtf   d16, x9
    fcmp    d29, d16
    b.ls    52f
    mov     x9, #0x7ff0000000000000
    fmov    d0, x9
    movi    d1, #0
    b       8f
52: fmov    d0, d29
    movi    d1, #0
    bl      q_expp
    sub     x11, x11, #1
    bl      q_scale
    movi    d1, #0
    b       8f
6:  fmov    d0, d29
    movi    d1, #0
    bl      q_expp
    add     x9, x11, #1023
    lsl     x9, x9, #52
    fmov    d16, x9
    fmul    d0, d0, d16
    fmul    d1, d1, d16
    fmov    d30, d0
    fmov    d31, d1
    fmov    d2, d0
    fmov    d3, d1
    fmov    d0, #1.0
    movi    d1, #0
    bl      dd_div
    fmov    d27, d0
    fmov    d28, d1
    cmp     x15, #1
    b.eq    7f
    fneg    d2, d0
    fneg    d3, d1
    fmov    d0, d30
    fmov    d1, d31
    bl      dd_add
    cbz     x15, 71f
    fmov    d25, d0
    fmov    d26, d1
    fmov    d0, d30
    fmov    d1, d31
    fmov    d2, d27
    fmov    d3, d28
    bl      dd_add
    fmov    d2, d0
    fmov    d3, d1
    fmov    d0, d25
    fmov    d1, d26
    bl      dd_div
    b       8f
7:  fmov    d2, d30
    fmov    d3, d31
    bl      dd_add
71: fmov    d16, #0.5
    fmul    d0, d0, d16
    fmul    d1, d1, d16
8:  fadd    d0, d0, d1
    cmp     x15, #1
    b.eq    n_num
    tbz     x14, #63, n_num
    fneg    d0, d0
    b       n_num
// 40 cbrt: e to a third of the logarithm, in pairs throughout, so that whole cube roots come out whole
n_cbrt:
    NIN
    ARGNUM  0
    fsub    d16, d0, d0
    fcmp    d16, #0.0
    b.ne    n_num
    fcmp    d0, #0.0
    b.eq    n_num
    fmov    x14, d0
    fabs    d0, d0
    bl      q_log
    fmov    d2, #3.0
    movi    d3, #0
    bl      dd_div
    bl      q_expp
    bl      q_scale
    tbz     x14, #63, n_num
    fneg    d0, d0
    b       n_num
// 41 hypot: the root of the sum of the squares of however many numbers. Each is made a number where it lies; the endless
// wins over not a number; all are scaled by 2^-600 or 2^600 when the largest is far from 1, squared exactly as pairs,
// summed, rooted, scaled back and rounded once.
n_hypot:
    NIN
    str     xzr, [sp, #40]
1:  ldr     x9, [sp, #40]
    ldr     x10, [sp, #16]
    cmp     x9, x10
    b.hs    2f
    ldr     x1, [sp, #24]
    ldr     x0, [x1, x9, lsl #3]
    bl      v_number
    ldr     x9, [sp, #40]
    ldr     x1, [sp, #24]
    str     d0, [x1, x9, lsl #3]
    add     x9, x9, #1
    str     x9, [sp, #40]
    b       1b
2:  ldr     x1, [sp, #24]
    movi    d4, #0
    mov     x12, #0
    mov     x9, #0
3:  cmp     x9, x10
    b.hs    4f
    ldr     d0, [x1, x9, lsl #3]
    add     x9, x9, #1
    fabs    d0, d0
    fcmp    d0, d0
    b.vc    31f
    mov     x12, #1
    b       3b
31: fmax    d4, d4, d0
    b       3b
4:  fmov    d0, d4
    mov     x9, #0x7ff0000000000000
    fmov    d6, x9
    fcmp    d4, d6
    b.eq    n_num
    cbnz    x12, 9f
    fcmp    d4, #0.0
    b.eq    n_num
    fmov    x13, d4
    lsr     x13, x13, #52
    mov     x11, #0
    fmov    d5, #1.0
    cmp     x13, #(1023 + 500)
    b.ls    5f
    mov     x11, #600
    mov     x14, #(1023 - 600)
    b       55f
5:  cmp     x13, #(1023 - 500)
    b.hs    6f
    mov     x11, #-600
    mov     x14, #(1023 + 600)
55: lsl     x14, x14, #52
    fmov    d5, x14
6:  movi    d0, #0
    movi    d1, #0
    mov     x9, #0
7:  cmp     x9, x10
    b.hs    8f
    ldr     d2, [x1, x9, lsl #3]
    add     x9, x9, #1
    fmul    d2, d2, d5
    fmul    d21, d2, d2
    fnmsub  d3, d2, d2, d21
    fmov    d2, d21
    bl      dd_add
    b       7b
8:  bl      dd_sqrt
    bl      q_scale
    b       n_num
9:  mov     x0, #0x7ff8000000000000
    NOUT
