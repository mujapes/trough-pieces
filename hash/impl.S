// hash, written by hand (ARM64). The meaning is hash/intent.md; the recorded checks are the judge.
// Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// SHA-256 uses the processor's own instructions; SHA-384 and SHA-512 are plain 64-bit arithmetic. The round constants below are
// computed from their definition (fractional parts of cube and square roots of the first primes) when this file is generated.
    .arch armv8-a+crypto
    .text
    .global sha256
    .global hmac_sha256
    .global expand_label
    .global sha384
    .global sha512

// bytes_at: the plain-bytes block at the handle in number w5, unless it is the block x6 -> x0 (0 if not usable). Uses x7, x8.
bytes_at:
    mov     x0, #0
    cmp     x2, x5
    b.le    9f
    ldrsh   x7, [x1, x5, lsl #1]
    cmp     x7, #0
    b.lt    9f
    cmp     x7, #255
    b.gt    9f
    add     x7, x7, #256
    ldr     x7, [x4, x7, lsl #3]
    cbz     x7, 9f
    ldr     w8, [x7]
    cmp     w8, #2
    b.ne    9f
    ldr     x8, [x7, #16]
    cmp     x8, #64
    b.lo    9f
    cmp     x7, x6
    b.eq    9f
    mov     x0, x7
9:  ret

// --- SHA-256 ---------------------------------------------------------------------------------------------------------------------
// a running hash: 0 the eight words, 32 a block being filled, 96 bytes taken so far, 104 how full the block is, 112 scratch
// rounds2: x5 the eight words, x6 one 64-byte block. Uses x7, v0-v7, v16-v19.
rounds2:
    ld1     {v0.4s, v1.4s}, [x5]
    mov     v18.16b, v0.16b
    mov     v19.16b, v1.16b
    ld1     {v4.16b, v5.16b, v6.16b, v7.16b}, [x6]
    rev32   v4.16b, v4.16b
    rev32   v5.16b, v5.16b
    rev32   v6.16b, v6.16b
    rev32   v7.16b, v7.16b
    adr     x7, k256
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v4.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v4.4s, v5.4s
    sha256su1 v4.4s, v6.4s, v7.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v5.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v5.4s, v6.4s
    sha256su1 v5.4s, v7.4s, v4.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v6.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v6.4s, v7.4s
    sha256su1 v6.4s, v4.4s, v5.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v7.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v7.4s, v4.4s
    sha256su1 v7.4s, v5.4s, v6.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v4.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v4.4s, v5.4s
    sha256su1 v4.4s, v6.4s, v7.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v5.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v5.4s, v6.4s
    sha256su1 v5.4s, v7.4s, v4.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v6.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v6.4s, v7.4s
    sha256su1 v6.4s, v4.4s, v5.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v7.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v7.4s, v4.4s
    sha256su1 v7.4s, v5.4s, v6.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v4.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v4.4s, v5.4s
    sha256su1 v4.4s, v6.4s, v7.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v5.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v5.4s, v6.4s
    sha256su1 v5.4s, v7.4s, v4.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v6.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v6.4s, v7.4s
    sha256su1 v6.4s, v4.4s, v5.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v7.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    sha256su0 v7.4s, v4.4s
    sha256su1 v7.4s, v5.4s, v6.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v4.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v5.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v6.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    ld1     {v16.4s}, [x7], #16
    add     v16.4s, v16.4s, v7.4s
    mov     v17.16b, v0.16b
    sha256h q0, q1, v16.4s
    sha256h2 q1, q17, v16.4s
    add     v0.4s, v0.4s, v18.4s
    add     v1.4s, v1.4s, v19.4s
    st1     {v0.4s, v1.4s}, [x5]
    ret
// begin2: x0 a running hash
begin2:
    adr     x5, i256
    ldp     x6, x7, [x5]
    stp     x6, x7, [x0]
    ldp     x6, x7, [x5, #16]
    stp     x6, x7, [x0, #16]
    str     xzr, [x0, #96]
    str     wzr, [x0, #104]
    ret
// add2: x0 a running hash, x1 bytes, x2 how many. Keeps x0. Uses x1-x3, x5-x7, x17 and what rounds2 uses.
add2:
    mov     x17, x30
    ldr     x5, [x0, #96]
    add     x5, x5, x2
    str     x5, [x0, #96]
    ldr     w3, [x0, #104]
1:  cbz     x2, 4f
    cbnz    w3, 2f
    cmp     x2, #64
    b.lo    2f
    mov     x5, x0                      // a whole block straight from the input
    mov     x6, x1
    bl      rounds2
    add     x1, x1, #64
    sub     x2, x2, #64
    b       1b
2:  ldrb    w5, [x1], #1
    add     x6, x0, #32
    strb    w5, [x6, x3]
    add     w3, w3, #1
    sub     x2, x2, #1
    cmp     w3, #64
    b.ne    1b
    mov     x5, x0
    add     x6, x0, #32
    bl      rounds2
    mov     w3, #0
    b       1b
4:  str     w3, [x0, #104]
    ret     x17
// finish2: x0 a running hash, x1 where the 32 bytes go. Uses x14-x16 and what add2 uses.
finish2:
    mov     x16, x30
    mov     x15, x1
    ldr     x14, [x0, #96]
    lsl     x14, x14, #3                // the length in bits, taken before the padding
    mov     w5, #0x80
    strb    w5, [x0, #112]
    add     x1, x0, #112
    mov     x2, #1
    bl      add2
1:  ldr     w5, [x0, #104]
    cmp     w5, #56
    b.eq    2f
    strb    wzr, [x0, #112]
    add     x1, x0, #112
    mov     x2, #1
    bl      add2
    b       1b
2:  rev     x14, x14
    str     x14, [x0, #112]
    add     x1, x0, #112
    mov     x2, #8
    bl      add2
    mov     x5, #0
3:  ldr     w6, [x0, x5, lsl #2]
    rev     w6, w6
    str     w6, [x15, x5, lsl #2]
    add     x5, x5, #1
    cmp     x5, #8
    b.lo    3b
    ret     x16

// frame of the three SHA-256 entries: 0 saved registers (96), 96 a running hash (128), 224 key block, 288 inner pad, 352 outer pad,
// 416 T, 448 inner digest, 480 the label information (528), 1008 round number and the like
    .equ CTX, 96
    .equ KEY, 224
    .equ IPAD, 288
    .equ OPAD, 352
    .equ TT, 416
    .equ INNER, 448
    .equ INFO, 480
    .equ FRAME, 1056
    .macro  enter
    sub     sp, sp, #FRAME
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
    add     sp, sp, #FRAME
    ret
    .endm

sha256:
    enter
    mov     x19, x0
    mov     x6, x0
    mov     x5, #0
    bl      bytes_at
    cbz     x0, 1f
    ldr     x5, [x19, #16]
    cmp     x5, #96
    b.lo    1f
    mov     x20, x0
    add     x0, sp, #CTX
    bl      begin2
    add     x1, x20, #64
    ldr     x2, [x20, #16]
    sub     x2, x2, #64
    bl      add2
    add     x1, x19, #64
    bl      finish2
    mov     x0, #32
    b       2f
1:  mov     x0, #-1
2:  leave

// keyed: the key (x0 bytes, x1 how many) into the key block, zero-filled, hashed first if longer than 64; then both pads. Uses x20-x22.
keyed:
    mov     x22, x30
    mov     x20, x0
    mov     x21, x1
    stp     xzr, xzr, [sp, #KEY]
    stp     xzr, xzr, [sp, #KEY + 16]
    stp     xzr, xzr, [sp, #KEY + 32]
    stp     xzr, xzr, [sp, #KEY + 48]
    cmp     x21, #64
    b.ls    1f
    add     x0, sp, #CTX
    bl      begin2
    mov     x1, x20
    mov     x2, x21
    bl      add2
    add     x1, sp, #KEY
    bl      finish2
    b       3f
1:  mov     x5, #0
    add     x6, sp, #KEY
2:  cmp     x5, x21
    b.hs    3f
    ldrb    w7, [x20, x5]
    strb    w7, [x6, x5]
    add     x5, x5, #1
    b       2b
3:  mov     x5, #0
    add     x6, sp, #KEY
    add     x7, sp, #IPAD
    add     x8, sp, #OPAD
    mov     w11, #0x36
    mov     w12, #0x5c
4:  ldrb    w9, [x6, x5]
    eor     w10, w9, w11
    strb    w10, [x7, x5]
    eor     w10, w9, w12
    strb    w10, [x8, x5]
    add     x5, x5, #1
    cmp     x5, #64
    b.lo    4b
    ret     x22

hmac_sha256:
    enter
    mov     x19, x0
    mov     x6, x0
    mov     x5, #0
    bl      bytes_at
    cbz     x0, 1f
    mov     x23, x0                     // key block
    mov     x5, #1
    bl      bytes_at
    cbz     x0, 1f
    mov     x24, x0                     // message block
    ldr     x5, [x19, #16]
    cmp     x5, #96
    b.lo    1f
    add     x0, x23, #64
    ldr     x1, [x23, #16]
    sub     x1, x1, #64
    bl      keyed
    add     x0, sp, #CTX                // inner: the inner pad, then the message
    bl      begin2
    add     x1, sp, #IPAD
    mov     x2, #64
    bl      add2
    add     x1, x24, #64
    ldr     x2, [x24, #16]
    sub     x2, x2, #64
    bl      add2
    add     x1, sp, #INNER
    bl      finish2
    add     x0, sp, #CTX                // outer: the outer pad, then the inner result
    bl      begin2
    add     x1, sp, #OPAD
    mov     x2, #64
    bl      add2
    add     x1, sp, #INNER
    mov     x2, #32
    bl      add2
    add     x1, x19, #64
    bl      finish2
    mov     x0, #32
    b       2f
1:  mov     x0, #-1
2:  leave

// expand_label: x23 secret, x24 label, x25 context blocks; w26 how many bytes wanted; x27 the information's length; x28 written
expand_label:
    enter
    mov     x19, x0
    mov     x6, x0
    mov     x5, #0
    bl      bytes_at
    cbz     x0, x_fail
    mov     x23, x0
    mov     x5, #1
    bl      bytes_at
    cbz     x0, x_fail
    mov     x24, x0
    mov     x5, #2
    bl      bytes_at
    cbz     x0, x_fail
    mov     x25, x0
    mov     x26, #0
    cmp     x2, #4
    b.lt    1f
    ldrsh   x26, [x1, #6]
1:  cmp     x26, #1
    b.lt    x_fail
    cmp     x26, #255
    b.gt    x_fail
    ldr     x5, [x19, #16]
    add     x6, x26, #64
    cmp     x5, x6
    b.lo    x_fail
    ldr     x9, [x24, #16]
    sub     x9, x9, #64                 // label length
    cmp     x9, #249
    b.hi    x_fail
    ldr     x10, [x25, #16]
    sub     x10, x10, #64               // context length
    cmp     x10, #255
    b.hi    x_fail
    add     x11, sp, #INFO              // the information: length wanted, "tls13 " and the label, the context
    lsr     w5, w26, #8
    strb    w5, [x11]
    strb    w26, [x11, #1]
    add     w5, w9, #6
    strb    w5, [x11, #2]
    mov     x27, #3
    adr     x6, t_tls13
    mov     x5, #0
2:  ldrb    w7, [x6, x5]
    strb    w7, [x11, x27]
    add     x27, x27, #1
    add     x5, x5, #1
    cmp     x5, #6
    b.lo    2b
    mov     x5, #0
3:  cmp     x5, x9
    b.hs    4f
    add     x6, x24, #64
    ldrb    w7, [x6, x5]
    strb    w7, [x11, x27]
    add     x27, x27, #1
    add     x5, x5, #1
    b       3b
4:  strb    w10, [x11, x27]
    add     x27, x27, #1
    mov     x5, #0
5:  cmp     x5, x10
    b.hs    6f
    add     x6, x25, #64
    ldrb    w7, [x6, x5]
    strb    w7, [x11, x27]
    add     x27, x27, #1
    add     x5, x5, #1
    b       5b
6:  add     x0, x23, #64
    ldr     x1, [x23, #16]
    sub     x1, x1, #64
    bl      keyed
    mov     x28, #0                     // written
    mov     w24, #1                     // round
7:  add     x0, sp, #CTX                // T(i) = HMAC(secret, T(i-1) | information | i)
    bl      begin2
    add     x1, sp, #IPAD
    mov     x2, #64
    bl      add2
    cmp     w24, #1
    b.eq    8f
    add     x1, sp, #TT
    mov     x2, #32
    bl      add2
8:  add     x1, sp, #INFO
    mov     x2, x27
    bl      add2
    strb    w24, [sp, #1008]
    add     x1, sp, #1008
    mov     x2, #1
    bl      add2
    add     x1, sp, #INNER
    bl      finish2
    add     x0, sp, #CTX
    bl      begin2
    add     x1, sp, #OPAD
    mov     x2, #64
    bl      add2
    add     x1, sp, #INNER
    mov     x2, #32
    bl      add2
    add     x1, sp, #TT
    bl      finish2
    mov     x5, #0
    add     x6, sp, #TT
    add     x7, x19, #64
9:  cmp     x5, #32
    b.hs    91f
    cmp     x28, x26
    b.hs    91f
    ldrb    w8, [x6, x5]
    strb    w8, [x7, x28]
    add     x28, x28, #1
    add     x5, x5, #1
    b       9b
91: add     w24, w24, #1
    cmp     x28, x26
    b.lo    7b
    mov     x0, x26
    b       x_out
x_fail:
    mov     x0, #-1
x_out:
    leave

// --- SHA-512 and SHA-384 ---------------------------------------------------------------------------------------------------------
// a running hash: 0 the eight words, 64 a block being filled, 192 bytes taken, 200 how full, 208 scratch (16)
// rounds5: x5 the eight words, x6 one 128-byte block. Keeps x0-x3 and x16, x17.
rounds5:
    sub     sp, sp, #672
    str     x1, [sp, #640]
    str     x2, [sp, #648]
    str     x3, [sp, #656]
    mov     x1, #0
1:  ldr     x7, [x6, x1, lsl #3]        // the block as sixteen words, highest byte first
    rev     x7, x7
    str     x7, [sp, x1, lsl #3]
    add     x1, x1, #1
    cmp     x1, #16
    b.lo    1b
2:  sub     x2, x1, #15                 // the other sixty-four, each from four earlier ones
    ldr     x7, [sp, x2, lsl #3]
    ror     x3, x7, #1
    eor     x3, x3, x7, ror #8
    eor     x3, x3, x7, lsr #7
    sub     x2, x1, #2
    ldr     x7, [sp, x2, lsl #3]
    ror     x4, x7, #19
    eor     x4, x4, x7, ror #61
    eor     x4, x4, x7, lsr #6
    add     x3, x3, x4
    sub     x2, x1, #16
    ldr     x7, [sp, x2, lsl #3]
    add     x3, x3, x7
    sub     x2, x1, #7
    ldr     x7, [sp, x2, lsl #3]
    add     x3, x3, x7
    str     x3, [sp, x1, lsl #3]
    add     x1, x1, #1
    cmp     x1, #80
    b.lo    2b
    ldp     x8, x9, [x5]
    ldp     x10, x11, [x5, #16]
    ldp     x12, x13, [x5, #32]
    ldp     x14, x15, [x5, #48]
    adr     x2, k512
    mov     x1, #0
3:  ror     x4, x12, #14                // eighty rounds
    eor     x4, x4, x12, ror #18
    eor     x4, x4, x12, ror #41
    add     x4, x4, x15
    and     x7, x12, x13
    bic     x3, x14, x12
    eor     x7, x7, x3
    add     x4, x4, x7
    ldr     x7, [x2, x1, lsl #3]
    add     x4, x4, x7
    ldr     x7, [sp, x1, lsl #3]
    add     x4, x4, x7                  // t1
    ror     x7, x8, #28
    eor     x7, x7, x8, ror #34
    eor     x7, x7, x8, ror #39
    and     x3, x8, x9
    and     x6, x8, x10
    eor     x3, x3, x6
    and     x6, x9, x10
    eor     x3, x3, x6
    add     x7, x7, x3                  // t2
    mov     x15, x14
    mov     x14, x13
    mov     x13, x12
    add     x12, x11, x4
    mov     x11, x10
    mov     x10, x9
    mov     x9, x8
    add     x8, x4, x7
    add     x1, x1, #1
    cmp     x1, #80
    b.lo    3b
    ldp     x3, x4, [x5]
    add     x3, x3, x8
    add     x4, x4, x9
    stp     x3, x4, [x5]
    ldp     x3, x4, [x5, #16]
    add     x3, x3, x10
    add     x4, x4, x11
    stp     x3, x4, [x5, #16]
    ldp     x3, x4, [x5, #32]
    add     x3, x3, x12
    add     x4, x4, x13
    stp     x3, x4, [x5, #32]
    ldp     x3, x4, [x5, #48]
    add     x3, x3, x14
    add     x4, x4, x15
    stp     x3, x4, [x5, #48]
    ldr     x1, [sp, #640]
    ldr     x2, [sp, #648]
    ldr     x3, [sp, #656]
    add     sp, sp, #672
    ret
// add5: x0 a running hash, x1 bytes, x2 how many. Keeps x0.
add5:
    mov     x17, x30
    ldr     x5, [x0, #192]
    add     x5, x5, x2
    str     x5, [x0, #192]
    ldr     w3, [x0, #200]
1:  cbz     x2, 4f
    cbnz    w3, 2f
    cmp     x2, #128
    b.lo    2f
    mov     x5, x0
    mov     x6, x1
    bl      rounds5
    add     x1, x1, #128
    sub     x2, x2, #128
    b       1b
2:  ldrb    w5, [x1], #1
    add     x6, x0, #64
    strb    w5, [x6, x3]
    add     w3, w3, #1
    sub     x2, x2, #1
    cmp     w3, #128
    b.ne    1b
    mov     x5, x0
    add     x6, x0, #64
    bl      rounds5
    mov     w3, #0
    b       1b
4:  str     w3, [x0, #200]
    ret     x17
// long_hash: the shared body. x0 output block, x1 numbers, x2 how many, x4 table; x9 the starting words, w10 how many bytes to give.
long_hash:
    sub     sp, sp, #288
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x19, x0
    mov     x21, x9
    mov     x22, x10
    mov     x6, x0
    mov     x5, #0
    bl      bytes_at
    cbz     x0, l_fail
    mov     x20, x0
    ldr     x5, [x19, #16]
    add     x6, x22, #64
    cmp     x5, x6
    b.lo    l_fail
    add     x0, sp, #48                 // the running hash
    mov     x5, #0
1:  ldr     x6, [x21, x5, lsl #3]
    str     x6, [x0, x5, lsl #3]
    add     x5, x5, #1
    cmp     x5, #8
    b.lo    1b
    str     xzr, [x0, #192]
    str     wzr, [x0, #200]
    add     x1, x20, #64
    ldr     x2, [x20, #16]
    sub     x2, x2, #64
    bl      add5
    ldr     x14, [x0, #192]
    lsl     x14, x14, #3
    str     x14, [sp, #272]             // the length in bits, kept in the frame: the rounds use every scratch register
    mov     w5, #0x80
    strb    w5, [x0, #208]
    add     x1, x0, #208
    mov     x2, #1
    bl      add5
2:  ldr     w5, [x0, #200]
    cmp     w5, #112
    b.eq    3f
    strb    wzr, [x0, #208]
    add     x1, x0, #208
    mov     x2, #1
    bl      add5
    b       2b
3:  ldr     x14, [sp, #272]
    rev     x14, x14                    // sixteen bytes of length: the high eight are zero
    str     xzr, [x0, #208]
    str     x14, [x0, #216]
    add     x1, x0, #208
    mov     x2, #16
    bl      add5
    mov     x5, #0                      // the words out, highest byte first, as many bytes as asked
    add     x7, x19, #64
4:  cmp     x5, x22
    b.hs    5f
    lsr     x6, x5, #3
    ldr     x6, [x0, x6, lsl #3]
    rev     x6, x6
    and     x8, x5, #7
    lsl     x8, x8, #3
    lsr     x6, x6, x8
    strb    w6, [x7, x5]
    add     x5, x5, #1
    b       4b
5:  mov     x0, x22
    b       l_out
l_fail:
    mov     x0, #-1
l_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    add     sp, sp, #288
    ret
sha512:
    adr     x9, i512
    mov     x10, #64
    b       long_hash
sha384:
    adr     x9, i384
    mov     x10, #48
    b       long_hash

t_tls13: .ascii "tls13 "
    .balign 8
i256:
    .word 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
k256:
    .word 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
    .word 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
    .word 0xe49b69c1, 0xefbe4786, 0xfc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
    .word 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x6ca6351, 0x14292967
    .word 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
    .word 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
    .word 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
    .word 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
i512:
    .quad 0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1
    .quad 0x510e527fade682d1, 0x9b05688c2b3e6c1f, 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179
i384:
    .quad 0xcbbb9d5dc1059ed8, 0x629a292a367cd507, 0x9159015a3070dd17, 0x152fecd8f70e5939
    .quad 0x67332667ffc00b31, 0x8eb44a8768581511, 0xdb0c2e0d64f98fa7, 0x47b5481dbefa4fa4
k512:
    .quad 0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc
    .quad 0x3956c25bf348b538, 0x59f111f1b605d019, 0x923f82a4af194f9b, 0xab1c5ed5da6d8118
    .quad 0xd807aa98a3030242, 0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2
    .quad 0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235, 0xc19bf174cf692694
    .quad 0xe49b69c19ef14ad2, 0xefbe4786384f25e3, 0xfc19dc68b8cd5b5, 0x240ca1cc77ac9c65
    .quad 0x2de92c6f592b0275, 0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5
    .quad 0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f, 0xbf597fc7beef0ee4
    .quad 0xc6e00bf33da88fc2, 0xd5a79147930aa725, 0x6ca6351e003826f, 0x142929670a0e6e70
    .quad 0x27b70a8546d22ffc, 0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df
    .quad 0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6, 0x92722c851482353b
    .quad 0xa2bfe8a14cf10364, 0xa81a664bbc423001, 0xc24b8b70d0f89791, 0xc76c51a30654be30
    .quad 0xd192e819d6ef5218, 0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8
    .quad 0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8
    .quad 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb, 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3
    .quad 0x748f82ee5defb2fc, 0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec
    .quad 0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915, 0xc67178f2e372532b
    .quad 0xca273eceea26619c, 0xd186b8c721c0c207, 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178
    .quad 0x6f067aa72176fba, 0xa637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b
    .quad 0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c
    .quad 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a, 0x5fcb6fab3ad6faec, 0x6c44198c4a475817
    .balign 4
