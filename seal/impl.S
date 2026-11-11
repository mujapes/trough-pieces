// seal, written by hand (ARM64). ChaCha20-Poly1305 (RFC 8439). The meaning is seal/intent.md; the recorded checks are the judge.
// Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Kept through an entry: x19 key, x20 nonce, x21 extra bytes, x22 how many, x23 message or sealed bytes, x24 how many, x25 output bytes.
// The tag's running value is x26, x27, x28 (130 bits); its multiplier is x9, x10 and x11 = x10 + x10 / 4.
    .text
    .global seal
    .global open
    .equ KS, 96
    .equ TMP, 160
    .equ PAD, 176
    .equ LENS, 192
    .equ TAG, 208
    .equ FRAME, 224

// bytes_at: the plain-bytes block at the handle in number x5, unless it is the block x6 -> x0 (0 if not usable). Uses x7, x8.
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

// block: 64 bytes of the stream for the counter in w16, written to the frame. The sixteen words live in w0-w15: ten double rounds,
// written out rather than looped. Uses x0-x17.
block:
    mov     w0, #0x7865
    movk    w0, #0x6170, lsl #16
    mov     w1, #0x646e
    movk    w1, #0x3320, lsl #16
    mov     w2, #0x2d32
    movk    w2, #0x7962, lsl #16
    mov     w3, #0x6574
    movk    w3, #0x6b20, lsl #16
    ldr     w4, [x19, #0]
    ldr     w5, [x19, #4]
    ldr     w6, [x19, #8]
    ldr     w7, [x19, #12]
    ldr     w8, [x19, #16]
    ldr     w9, [x19, #20]
    ldr     w10, [x19, #24]
    ldr     w11, [x19, #28]
    mov     w12, w16
    ldr     w13, [x20, #0]
    ldr     w14, [x20, #4]
    ldr     w15, [x20, #8]
    .rept   10
    add     w0, w0, w4
    eor     w12, w12, w0
    ror     w12, w12, #16
    add     w8, w8, w12
    eor     w4, w4, w8
    ror     w4, w4, #20
    add     w0, w0, w4
    eor     w12, w12, w0
    ror     w12, w12, #24
    add     w8, w8, w12
    eor     w4, w4, w8
    ror     w4, w4, #25
    add     w1, w1, w5
    eor     w13, w13, w1
    ror     w13, w13, #16
    add     w9, w9, w13
    eor     w5, w5, w9
    ror     w5, w5, #20
    add     w1, w1, w5
    eor     w13, w13, w1
    ror     w13, w13, #24
    add     w9, w9, w13
    eor     w5, w5, w9
    ror     w5, w5, #25
    add     w2, w2, w6
    eor     w14, w14, w2
    ror     w14, w14, #16
    add     w10, w10, w14
    eor     w6, w6, w10
    ror     w6, w6, #20
    add     w2, w2, w6
    eor     w14, w14, w2
    ror     w14, w14, #24
    add     w10, w10, w14
    eor     w6, w6, w10
    ror     w6, w6, #25
    add     w3, w3, w7
    eor     w15, w15, w3
    ror     w15, w15, #16
    add     w11, w11, w15
    eor     w7, w7, w11
    ror     w7, w7, #20
    add     w3, w3, w7
    eor     w15, w15, w3
    ror     w15, w15, #24
    add     w11, w11, w15
    eor     w7, w7, w11
    ror     w7, w7, #25
    add     w0, w0, w5
    eor     w15, w15, w0
    ror     w15, w15, #16
    add     w10, w10, w15
    eor     w5, w5, w10
    ror     w5, w5, #20
    add     w0, w0, w5
    eor     w15, w15, w0
    ror     w15, w15, #24
    add     w10, w10, w15
    eor     w5, w5, w10
    ror     w5, w5, #25
    add     w1, w1, w6
    eor     w12, w12, w1
    ror     w12, w12, #16
    add     w11, w11, w12
    eor     w6, w6, w11
    ror     w6, w6, #20
    add     w1, w1, w6
    eor     w12, w12, w1
    ror     w12, w12, #24
    add     w11, w11, w12
    eor     w6, w6, w11
    ror     w6, w6, #25
    add     w2, w2, w7
    eor     w13, w13, w2
    ror     w13, w13, #16
    add     w8, w8, w13
    eor     w7, w7, w8
    ror     w7, w7, #20
    add     w2, w2, w7
    eor     w13, w13, w2
    ror     w13, w13, #24
    add     w8, w8, w13
    eor     w7, w7, w8
    ror     w7, w7, #25
    add     w3, w3, w4
    eor     w14, w14, w3
    ror     w14, w14, #16
    add     w9, w9, w14
    eor     w4, w4, w9
    ror     w4, w4, #20
    add     w3, w3, w4
    eor     w14, w14, w3
    ror     w14, w14, #24
    add     w9, w9, w14
    eor     w4, w4, w9
    ror     w4, w4, #25
    .endr
    mov     w17, #0x7865
    movk    w17, #0x6170, lsl #16
    add     w0, w0, w17
    mov     w17, #0x646e
    movk    w17, #0x3320, lsl #16
    add     w1, w1, w17
    mov     w17, #0x2d32
    movk    w17, #0x7962, lsl #16
    add     w2, w2, w17
    mov     w17, #0x6574
    movk    w17, #0x6b20, lsl #16
    add     w3, w3, w17
    ldr     w17, [x19, #0]
    add     w4, w4, w17
    ldr     w17, [x19, #4]
    add     w5, w5, w17
    ldr     w17, [x19, #8]
    add     w6, w6, w17
    ldr     w17, [x19, #12]
    add     w7, w7, w17
    ldr     w17, [x19, #16]
    add     w8, w8, w17
    ldr     w17, [x19, #20]
    add     w9, w9, w17
    ldr     w17, [x19, #24]
    add     w10, w10, w17
    ldr     w17, [x19, #28]
    add     w11, w11, w17
    add     w12, w12, w16
    ldr     w17, [x20, #0]
    add     w13, w13, w17
    ldr     w17, [x20, #4]
    add     w14, w14, w17
    ldr     w17, [x20, #8]
    add     w15, w15, w17
    stp     w0, w1, [sp, #KS + 0]
    stp     w2, w3, [sp, #KS + 8]
    stp     w4, w5, [sp, #KS + 16]
    stp     w6, w7, [sp, #KS + 24]
    stp     w8, w9, [sp, #KS + 32]
    stp     w10, w11, [sp, #KS + 40]
    stp     w12, w13, [sp, #KS + 48]
    stp     w14, w15, [sp, #KS + 56]
    ret
// stream: x23 bytes (x24 of them) combined with the stream into x25, counter starting at 1. Its place and counter are kept in the frame.
stream:
    str     x30, [sp, #FRAME + 8]
    str     xzr, [sp, #TMP]
    mov     w16, #1
    str     w16, [sp, #TMP + 8]
1:  ldr     x14, [sp, #TMP]
    cmp     x14, x24
    b.hs    4f
    ldr     w16, [sp, #TMP + 8]
    bl      block
    ldr     x14, [sp, #TMP]
    sub     x15, x24, x14
    add     x13, sp, #KS
    cmp     x15, #64
    b.lo    2f
    ld1     {v0.16b, v1.16b, v2.16b, v3.16b}, [x13]     // a whole block at once
    add     x5, x23, x14
    ld1     {v4.16b, v5.16b, v6.16b, v7.16b}, [x5]
    eor     v4.16b, v4.16b, v0.16b
    eor     v5.16b, v5.16b, v1.16b
    eor     v6.16b, v6.16b, v2.16b
    eor     v7.16b, v7.16b, v3.16b
    add     x5, x25, x14
    st1     {v4.16b, v5.16b, v6.16b, v7.16b}, [x5]
    b       3f
2:  mov     x16, #0
21: cmp     x16, x15
    b.hs    3f
    add     x5, x14, x16
    ldrb    w6, [x23, x5]
    ldrb    w7, [x13, x16]
    eor     w6, w6, w7
    strb    w6, [x25, x5]
    add     x16, x16, #1
    b       21b
3:  add     x14, x14, #64
    str     x14, [sp, #TMP]
    ldr     w16, [sp, #TMP + 8]
    add     w16, w16, #1
    str     w16, [sp, #TMP + 8]
    b       1b
4:  ldr     x30, [sp, #FRAME + 8]
    ret

// absorb: one 16-byte block at x0 into the tag's running value. Uses x1-x8.
absorb:
    ldp     x1, x2, [x0]
    mov     x3, #1
    adds    x26, x26, x1
    adcs    x27, x27, x2
    adc     x28, x28, x3
    mul     x3, x26, x9                 // (h0, h1, h2) times (r0, r1), folding 2^130 back as 5
    umulh   x4, x26, x9
    mul     x5, x27, x11
    umulh   x6, x27, x11
    adds    x3, x3, x5
    adc     x4, x4, x6
    mul     x5, x26, x10
    umulh   x6, x26, x10
    mul     x7, x27, x9
    umulh   x8, x27, x9
    adds    x5, x5, x7
    adc     x6, x6, x8
    mul     x7, x28, x11
    adds    x5, x5, x7
    adc     x6, x6, xzr
    mul     x28, x28, x9
    adds    x5, x5, x4
    adc     x6, x6, xzr
    mov     x26, x3
    mov     x27, x5
    add     x28, x28, x6
    and     x1, x28, #-4
    add     x1, x1, x28, lsr #2
    and     x28, x28, #3
    adds    x26, x26, x1
    adcs    x27, x27, xzr
    adc     x28, x28, xzr
    ret
// absorb_run: x0 bytes, x1 how many, in 16-byte blocks, the last one zero-filled. Uses x12-x16 and what absorb uses.
absorb_run:
    mov     x16, x30
    mov     x12, x0
    mov     x13, x1
1:  cmp     x13, #16
    b.lo    2f
    mov     x0, x12
    bl      absorb
    add     x12, x12, #16
    sub     x13, x13, #16
    b       1b
2:  cbz     x13, 4f
    stp     xzr, xzr, [sp, #PAD]
    add     x14, sp, #PAD
    mov     x15, #0
3:  ldrb    w1, [x12, x15]
    strb    w1, [x14, x15]
    add     x15, x15, #1
    cmp     x15, x13
    b.lo    3b
    mov     x0, x14
    bl      absorb
4:  ret     x16
// tag_of: the 16-byte tag over the extra bytes and x0 locked bytes (x1 of them), written to the frame. Uses nearly everything scratch.
tag_of:
    str     x30, [sp, #FRAME]           // its own slot at the top of the frame
    stp     x0, x1, [sp, #LENS]
    mov     w16, #0
    bl      block                       // block 0 of the stream is the tag's key
    ldp     x9, x10, [sp, #KS]
    ldr     x5, =0x0ffffffc0fffffff
    and     x9, x9, x5
    ldr     x5, =0x0ffffffc0ffffffc
    and     x10, x10, x5
    add     x11, x10, x10, lsr #2
    mov     x26, #0
    mov     x27, #0
    mov     x28, #0
    mov     x0, x21
    mov     x1, x22
    bl      absorb_run
    ldp     x0, x1, [sp, #LENS]
    bl      absorb_run
    ldr     x1, [sp, #LENS + 8]
    str     x22, [sp, #LENS]            // both lengths, lowest byte first
    str     x1, [sp, #LENS + 8]
    add     x0, sp, #LENS
    bl      absorb
    adds    x1, x26, #5                 // if the value plus 5 reaches 2^130, that is the reduced value
    adcs    x2, x27, xzr
    adc     x3, x28, xzr
    lsr     x3, x3, #2
    cmp     x3, #0
    csel    x26, x1, x26, ne
    csel    x27, x2, x27, ne
    ldp     x1, x2, [sp, #KS + 16]      // plus the second half of the key
    adds    x26, x26, x1
    adc     x27, x27, x2
    stp     x26, x27, [sp, #TAG]
    ldr     x30, [sp, #FRAME]
    ret

    .macro  enter
    sub     sp, sp, #FRAME + 16
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
    add     sp, sp, #FRAME + 16
    ret
    .endm
// handles: key, nonce, extra, body into x19-x24 from the four numbers; x25 the output block. Jumps to the label given if anything is wrong.
    .macro  HANDLES fail
    mov     x25, x0
    mov     x6, x0
    mov     x5, #0
    bl      bytes_at
    cbz     x0, \fail
    ldr     x7, [x0, #16]
    cmp     x7, #(64 + 32)
    b.ne    \fail
    add     x19, x0, #64
    mov     x5, #1
    bl      bytes_at
    cbz     x0, \fail
    ldr     x7, [x0, #16]
    cmp     x7, #(64 + 12)
    b.ne    \fail
    add     x20, x0, #64
    mov     x5, #2
    bl      bytes_at
    cbz     x0, \fail
    add     x21, x0, #64
    ldr     x22, [x0, #16]
    sub     x22, x22, #64
    mov     x5, #3
    bl      bytes_at
    cbz     x0, \fail
    add     x23, x0, #64
    ldr     x24, [x0, #16]
    sub     x24, x24, #64
    ldr     x7, [x25, #16]
    cmp     x7, #64
    b.lo    \fail
    .endm

seal:
    enter
    HANDLES s_fail
    ldr     x7, [x25, #16]
    sub     x7, x7, #64
    add     x8, x24, #16
    cmp     x7, x8
    b.lo    s_fail
    add     x25, x25, #64
    bl      stream                      // lock the message into the output
    mov     x0, x25
    mov     x1, x24
    bl      tag_of                      // then the tag over what was locked
    ldp     x5, x6, [sp, #TAG]
    add     x7, x25, x24
    stp     x5, x6, [x7]
    add     x0, x24, #16
    b       s_out
s_fail:
    mov     x0, #-1
s_out:
    leave

open:
    enter
    HANDLES o_fail
    cmp     x24, #16
    b.lo    o_fail
    sub     x24, x24, #16               // the message's length without its tag
    ldr     x7, [x25, #16]
    sub     x7, x7, #64
    cmp     x7, x24
    b.lo    o_fail
    add     x25, x25, #64
    mov     x0, x23
    mov     x1, x24
    bl      tag_of                      // the tag is checked before anything is unlocked or written
    ldp     x5, x6, [sp, #TAG]
    add     x7, x23, x24
    ldp     x8, x9, [x7]
    eor     x5, x5, x8                  // every bit compared, no early exit
    eor     x6, x6, x9
    orr     x5, x5, x6
    cbnz    x5, o_fail
    bl      stream
    mov     x0, x24
    b       o_out
o_fail:
    mov     x0, #-1
o_out:
    leave

t_sigma: .ascii "expand 32-byte k"
    .balign 4
