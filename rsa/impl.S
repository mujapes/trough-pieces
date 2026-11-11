// rsa, written by hand (ARM64): checks RSA signatures, PKCS #1 v1.5 and PSS (RFC 8017). The meaning is rsa/intent.md; the recorded
// checks are the judge. Entries: x0 block (unused), x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Long numbers are 64-bit limbs, lowest first, up to 64 of them. Through an entry: x19 the frame, x20 the call table, x21 how
// many limbs, x22 minus one over the modulus (modulo 2^64), x23 the modulus's length in bits, x24 numbers, x25 how many.
    .text
    .global verify_pkcs1
    .global verify_pss
    .equ Q, 96
    .equ M1, 104
    .equ NB, 112
    .equ EB, 120
    .equ SB, 128
    .equ DGB, 136
    .equ SKIP, 144
    .equ WANT, 160
    .equ BUF, 192
    .equ MASK, 272
    .equ INB, 304
    .equ OB, 496
    .equ N, 688
    .equ R2, 1200
    .equ S, 1712
    .equ BASE, 2224
    .equ ACC, 2736
    .equ T, 3248
    .equ EM, 3776
    .equ DB, 4288
    .equ FRAME, 4800
    .macro  ADDR reg, off
    mov     \reg, #\off
    add     \reg, x19, \reg
    .endm

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
    cmp     x9, x9                      // no borrow yet
1:  ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    sbcs    x10, x10, x11
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 1b
    ret
// product: the numbers at x0 and x1 multiplied, divided by 2^(64 limbs), modulo the modulus, to x2 (Montgomery's product: the form
// in which repeated multiplication needs no division). x2 may be x0 or x1. Uses x3-x17.
product:
    mov     x17, x30
    ADDR    x3, T
    ADDR    x4, N
    add     x5, x21, #2
1:  sub     x5, x5, #1
    str     xzr, [x3, x5, lsl #3]
    cbnz    x5, 1b
p_i:
    ldr     x7, [x1, x5, lsl #3]
    mov     x8, #0
    mov     x6, #0
p_j:
    ldr     x9, [x0, x6, lsl #3]
    mul     x10, x9, x7
    umulh   x11, x9, x7
    ldr     x12, [x3, x6, lsl #3]
    adds    x10, x10, x12
    adc     x11, x11, xzr
    adds    x10, x10, x8
    adc     x8, x11, xzr
    str     x10, [x3, x6, lsl #3]
    add     x6, x6, #1
    cmp     x6, x21
    b.lo    p_j
    ldr     x12, [x3, x21, lsl #3]
    adds    x12, x12, x8
    str     x12, [x3, x21, lsl #3]
    cset    x13, cs                     // the limb above the top
    ldr     x9, [x3]
    mul     x12, x9, x22                // the multiple of the modulus that clears the lowest limb
    ldr     x10, [x4]
    mul     x11, x12, x10
    umulh   x8, x12, x10
    adds    x11, x11, x9
    adc     x8, x8, xzr
    mov     x6, #1
p_r:
    ldr     x10, [x4, x6, lsl #3]
    mul     x11, x12, x10
    umulh   x14, x12, x10
    ldr     x9, [x3, x6, lsl #3]
    adds    x11, x11, x9
    adc     x14, x14, xzr
    adds    x11, x11, x8
    adc     x8, x14, xzr
    sub     x15, x6, #1
    str     x11, [x3, x15, lsl #3]
    add     x6, x6, #1
    cmp     x6, x21
    b.lo    p_r
    ldr     x9, [x3, x21, lsl #3]
    adds    x9, x9, x8
    adc     x13, x13, xzr
    sub     x15, x21, #1
    str     x9, [x3, x15, lsl #3]
    str     x13, [x3, x21, lsl #3]
    add     x5, x5, #1
    cmp     x5, x21
    b.lo    p_i
    cbnz    x13, 2f
    mov     x0, x3
    mov     x1, x4
    bl      ge
    cbz     x0, 3f
2:  ADDR    x0, T
    ADDR    x1, N
    bl      take
3:  ADDR    x3, T
    mov     x5, #0
4:  ldr     x9, [x3, x5, lsl #3]
    str     x9, [x2, x5, lsl #3]
    add     x5, x5, #1
    cmp     x5, x21
    b.lo    4b
    ret     x17
// load: the bytes of the block x1 (most significant first) as a number at x0 -> x0 1, or 0 if it does not fit. Uses x9-x15.
load:
    mov     x9, #0
1:  str     xzr, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    1b
    ldr     x10, [x1, #16]
    sub     x10, x10, #64               // how many bytes
    add     x1, x1, #64
    mov     x9, #0
2:  cmp     x9, x10
    b.hs    5f
    ldrb    w11, [x1, x9]
    sub     x12, x10, x9
    sub     x12, x12, #1                // its place, counted from the low end
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
// bytes_at: the plain block, not empty, at the handle in number x0 -> x0, or 0. Uses x9.
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
    b.hi    9f
8:  mov     x0, #0
9:  ret

// recover: signature to the power of the exponent, modulo the key's modulus, as bytes at EM the length of the modulus -> x0 that
// length (and x23 the modulus's length in bits), or 0 if the numbers are not a usable key and signature. Uses x24-x28 freely.
recover:
    stp     x29, x30, [sp, #-16]!
    mov     x0, #0
    bl      bytes_at
    cbz     x0, r_no
    str     x0, [x19, #NB]
    mov     x0, #1
    bl      bytes_at
    cbz     x0, r_no
    str     x0, [x19, #EB]
    mov     x0, #2
    bl      bytes_at
    cbz     x0, r_no
    str     x0, [x19, #SB]
    ldr     x9, [x19, #NB]
    ldr     x26, [x9, #16]
    sub     x26, x26, #64               // the modulus's bytes, less any leading zeros
    add     x9, x9, #64
    mov     x10, #0
1:  cmp     x10, x26
    b.hs    2f
    ldrb    w11, [x9, x10]
    cbnz    w11, 2f
    add     x10, x10, #1
    b       1b
2:  str     x10, [x19, #SKIP]
    sub     x26, x26, x10
    cmp     x26, #128                   // 1024 to 4096 bits
    b.lo    r_no
    cmp     x26, #512
    b.hi    r_no
    ldr     x9, [x19, #SB]
    ldr     x9, [x9, #16]
    sub     x9, x9, #64
    cmp     x9, x26
    b.ne    r_no
    ldr     x9, [x19, #EB]
    ldr     x27, [x9, #16]
    sub     x27, x27, #64               // the exponent's bytes
    cmp     x27, #4
    b.hi    r_no
    add     x21, x26, #7
    lsr     x21, x21, #3
    ADDR    x0, N
    ldr     x1, [x19, #NB]
    bl      load
    cbz     x0, r_no
    ldr     x9, [x19, #N]
    tbz     x9, #0, r_no
    ADDR    x0, S
    ldr     x1, [x19, #SB]
    bl      load
    cbz     x0, r_no
    ADDR    x0, S
    ADDR    x1, N
    bl      ge
    cbnz    x0, r_no
    ldr     x9, [x19, #EB]
    add     x9, x9, #64
    mov     x28, #0                     // the exponent
    mov     x10, #0
3:  ldrb    w11, [x9, x10]
    orr     x28, x11, x28, lsl #8
    add     x10, x10, #1
    cmp     x10, x27
    b.lo    3b
    cmp     x28, #3
    b.lo    r_no
    tbz     x28, #0, r_no
    ldr     x9, [x19, #N]               // minus one over the modulus, modulo 2^64
    mov     x22, #1
    mov     x10, #6
4:  mul     x11, x9, x22
    mov     x12, #2
    sub     x12, x12, x11
    mul     x22, x22, x12
    subs    x10, x10, #1
    b.ne    4b
    neg     x22, x22
    ADDR    x25, R2                     // 2^(128 limbs) modulo the modulus, by doubling
    mov     x9, #0
5:  str     xzr, [x25, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    5b
    mov     x9, #1
    str     x9, [x25]
    lsl     x24, x21, #7
6:  sub     x9, x21, #1
    ldr     x10, [x25, x9, lsl #3]
    lsr     x15, x10, #63
    mov     x9, #0
    adds    x10, xzr, xzr               // no carry yet
7:  ldr     x10, [x25, x9, lsl #3]
    adcs    x10, x10, x10
    str     x10, [x25, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 7b
    cbnz    x15, 8f
    mov     x0, x25
    ADDR    x1, N
    bl      ge
    cbz     x0, 9f
8:  mov     x0, x25
    ADDR    x1, N
    bl      take
9:  subs    x24, x24, #1
    b.ne    6b
    ADDR    x0, S
    mov     x1, x25
    ADDR    x2, BASE
    bl      product
    ADDR    x9, BASE
    ADDR    x10, ACC
    mov     x11, #0
1:  ldr     x12, [x9, x11, lsl #3]
    str     x12, [x10, x11, lsl #3]
    add     x11, x11, #1
    cmp     x11, x21
    b.lo    1b
    clz     x9, x28
    mov     x24, #63
    sub     x24, x24, x9                // the exponent's top bit
2:  subs    x24, x24, #1
    b.mi    3f
    ADDR    x0, ACC
    mov     x1, x0
    mov     x2, x0
    bl      product
    lsr     x9, x28, x24
    tbz     x9, #0, 2b
    ADDR    x0, ACC
    ADDR    x1, BASE
    mov     x2, x0
    bl      product
    b       2b
3:  ADDR    x9, S                       // out of Montgomery's form: multiply by plain one
    mov     x11, #0
4:  str     xzr, [x9, x11, lsl #3]
    add     x11, x11, #1
    cmp     x11, x21
    b.lo    4b
    mov     x10, #1
    str     x10, [x9]
    ADDR    x0, ACC
    ADDR    x1, S
    mov     x2, x0
    bl      product
    ADDR    x9, ACC
    ADDR    x10, EM
    mov     x11, #0
5:  sub     x12, x26, x11
    sub     x12, x12, #1
    ldrb    w13, [x9, x12]
    strb    w13, [x10, x11]
    add     x11, x11, #1
    cmp     x11, x26
    b.lo    5b
    ldr     x9, [x19, #NB]
    ldr     x10, [x19, #SKIP]
    add     x9, x9, #64
    ldrb    w9, [x9, x10]
    clz     w9, w9
    sub     w9, w9, #24
    lsl     x23, x26, #3
    sub     x23, x23, x9
    mov     x0, x26
    b       r_out
r_no:
    mov     x0, #0
r_out:
    ldp     x29, x30, [sp], #16
    ret

    .macro  ENTER
    sub     sp, sp, #4096
    sub     sp, sp, #(FRAME - 4096)
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
    .endm
    .macro  LEAVE
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

// PKCS #1 v1.5: the recovered bytes must be exactly 00 01 FF...FF 00, the hash's label, the digest.
verify_pkcs1:
    ENTER
    mov     x0, #3
    bl      bytes_at
    cbz     x0, v_unusable
    str     x0, [x19, #DGB]
    ldr     x9, [x0, #16]
    sub     x9, x9, #64
    cmp     x9, #32
    b.eq    1f
    cmp     x9, #48
    b.eq    1f
    cmp     x9, #64
    b.ne    v_unusable
1:  bl      recover
    cbz     x0, v_unusable
    mov     x26, x0                     // how many bytes were recovered
    ldr     x27, [x19, #DGB]
    ldr     x28, [x27, #16]
    sub     x28, x28, #64               // the digest's length
    add     x27, x27, #64
    add     x9, x28, #30
    cmp     x26, x9
    b.lo    v_no
    adr     x9, v_label                 // the label for this digest: "SHA-256, 32 bytes", the others differing in three places
    add     x10, x19, #WANT
    mov     x11, #0
2:  ldrb    w12, [x9, x11]
    strb    w12, [x10, x11]
    add     x11, x11, #1
    cmp     x11, #19
    b.lo    2b
    add     w12, w28, #0x11
    strb    w12, [x10, #1]
    lsr     w12, w28, #4
    sub     w12, w12, #1                // 32, 48, 64 -> 1, 2, 3
    strb    w12, [x10, #14]
    strb    w28, [x10, #18]
    ADDR    x13, EM
    ldrb    w14, [x13]                  // every difference is gathered; none ends the comparison early
    ldrb    w15, [x13, #1]
    eor     w15, w15, #1
    orr     w14, w14, w15
    sub     x16, x26, #22
    sub     x16, x16, x28               // how many FF bytes
    add     x13, x13, #2
    mov     x11, #0
3:  cmp     x11, x16
    b.hs    4f
    ldrb    w15, [x13, x11]
    eor     w15, w15, #0xff
    orr     w14, w14, w15
    add     x11, x11, #1
    b       3b
4:  add     x13, x13, x16
    ldrb    w15, [x13], #1
    orr     w14, w14, w15
    mov     x11, #0
5:  ldrb    w15, [x13, x11]
    ldrb    w12, [x10, x11]
    eor     w15, w15, w12
    orr     w14, w14, w15
    add     x11, x11, #1
    cmp     x11, #19
    b.lo    5b
    add     x13, x13, #19
    mov     x11, #0
6:  ldrb    w15, [x13, x11]
    ldrb    w12, [x27, x11]
    eor     w15, w15, w12
    orr     w14, w14, w15
    add     x11, x11, #1
    cmp     x11, x28
    b.lo    6b
    cmp     w14, #0
    cset    x0, eq
    b       v_out
v_no:
    mov     x0, #0
    b       v_out
v_unusable:
    mov     x0, #-1
v_out:
    LEAVE
v_label:
    .byte   0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0x04, 0x20
    .balign 4

// sha256_of: the SHA-256 of the x1 bytes at x0 (at most 128), to MASK -> x0 1 or 0. Asks the hashing piece through its socket,
// handing it a table in which only handle 1 is real: the hashing piece calls nothing and reads no other handle.
sha256_of:
    stp     x29, x30, [sp, #-16]!
    add     x9, x19, #INB
    add     x10, x19, #OB
    mov     x11, #0
1:  str     xzr, [x9, x11, lsl #3]
    str     xzr, [x10, x11, lsl #3]
    add     x11, x11, #1
    cmp     x11, #8
    b.lo    1b
    mov     w11, #2
    str     w11, [x9]
    str     w11, [x10]
    add     x11, x1, #64
    str     x11, [x9, #16]
    mov     x11, #192
    str     x11, [x10, #16]
    add     x9, x9, #64
    mov     x11, #0
2:  ldrb    w12, [x0, x11]
    strb    w12, [x9, x11]
    add     x11, x11, #1
    cmp     x11, x1
    b.lo    2b
    add     x9, x19, #INB
    str     x9, [x19, #M1]
    mov     w9, #1
    strh    w9, [x19, #Q]
    add     x0, x19, #OB
    add     x1, x19, #Q
    mov     x2, #1
    mov     x3, #0
    add     x4, x19, #M1
    sub     x4, x4, #(257 * 8)
    ldr     x9, [x20, #(14 * 8)]
    blr     x9
    cmp     x0, #32
    b.ne    3f
    add     x11, x19, #OB
    ldp     x9, x10, [x11, #64]
    stp     x9, x10, [x19, #MASK]
    ldp     x9, x10, [x11, #80]
    stp     x9, x10, [x19, #(MASK + 16)]
    mov     x0, #1
    b       4f
3:  mov     x0, #0
4:  ldp     x29, x30, [sp], #16
    ret

// PSS with SHA-256 and a 32-byte salt, the form TLS 1.3 uses for a server's own signature (RFC 8017 section 9.1.2).
verify_pss:
    ENTER
    mov     x0, #3
    bl      bytes_at
    cbz     x0, s_unusable
    ldr     x9, [x0, #16]
    cmp     x9, #96
    b.ne    s_unusable
    str     x0, [x19, #DGB]
    bl      recover
    cbz     x0, s_unusable
    ADDR    x26, EM                     // x26 the encoded message, x27 its length
    sub     x9, x23, #1                 // its length in bits
    add     x27, x9, #7
    lsr     x27, x27, #3
    cmp     x27, x0
    b.hs    1f
    ldrb    w10, [x26]
    cbnz    w10, s_no
    add     x26, x26, #1
1:  cmp     x27, #66
    b.lo    s_no
    sub     x10, x27, #1
    ldrb    w10, [x26, x10]
    cmp     w10, #0xbc
    b.ne    s_no
    lsl     x10, x27, #3
    sub     x10, x10, x9                // bits of the first byte that must be clear
    str     x10, [x19, #SKIP]
    sub     x27, x27, #33               // from here x27 is the masked part's length, x24 the hash that follows it
    add     x24, x26, x27
    mov     x28, #0                     // how much of the mask has been made
    mov     x25, #0                     // the counter
2:  cmp     x28, x27
    b.hs    5f
    ldp     x9, x10, [x24]
    stp     x9, x10, [x19, #BUF]
    ldp     x9, x10, [x24, #16]
    stp     x9, x10, [x19, #(BUF + 16)]
    rev     w9, w25
    str     w9, [x19, #(BUF + 32)]
    add     x0, x19, #BUF
    mov     x1, #36
    bl      sha256_of
    cbz     x0, s_unusable
    ADDR    x9, DB
    add     x10, x19, #MASK
    mov     x11, #0
3:  cmp     x28, x27
    b.hs    4f
    ldrb    w12, [x26, x28]
    ldrb    w13, [x10, x11]
    eor     w12, w12, w13
    strb    w12, [x9, x28]
    add     x28, x28, #1
    add     x11, x11, #1
    cmp     x11, #32
    b.lo    3b
4:  add     x25, x25, #1
    b       2b
5:  ldr     x10, [x19, #SKIP]
    ADDR    x9, DB
    cbz     x10, 6f
    ldrb    w11, [x26]
    mov     w12, #8
    sub     w12, w12, w10
    lsr     w11, w11, w12
    cbnz    w11, s_no
6:  mov     w11, #0xff
    lsr     w11, w11, w10
    ldrb    w12, [x9]
    and     w12, w12, w11
    strb    w12, [x9]
    mov     w28, #0                     // every difference is gathered
    sub     x13, x27, #33
    mov     x11, #0
7:  cmp     x11, x13
    b.hs    8f
    ldrb    w12, [x9, x11]
    orr     w28, w28, w12
    add     x11, x11, #1
    b       7b
8:  ldrb    w12, [x9, x13]
    eor     w12, w12, #1
    orr     w28, w28, w12
    str     xzr, [x19, #BUF]            // eight zeros, the digest, the salt
    ldr     x10, [x19, #DGB]
    ldp     x11, x12, [x10, #64]
    stp     x11, x12, [x19, #(BUF + 8)]
    ldp     x11, x12, [x10, #80]
    stp     x11, x12, [x19, #(BUF + 24)]
    add     x9, x9, x27
    sub     x9, x9, #32
    ldp     x11, x12, [x9]
    stp     x11, x12, [x19, #(BUF + 40)]
    ldp     x11, x12, [x9, #16]
    stp     x11, x12, [x19, #(BUF + 56)]
    add     x0, x19, #BUF
    mov     x1, #72
    bl      sha256_of
    cbz     x0, s_unusable
    add     x10, x19, #MASK
    mov     x11, #0
9:  ldrb    w12, [x10, x11]
    ldrb    w13, [x24, x11]
    eor     w12, w12, w13
    orr     w28, w28, w12
    add     x11, x11, #1
    cmp     x11, #32
    b.lo    9b
    cmp     w28, #0
    cset    x0, eq
    b       s_out
s_no:
    mov     x0, #0
    b       s_out
s_unusable:
    mov     x0, #-1
s_out:
    LEAVE
