// aesgcm, written by hand (ARM64). AES-GCM (NIST SP 800-38D), 16- or 32-byte key. The meaning is aesgcm/intent.md; the recorded
// checks are the judge. The cipher round and the tag's multiplication are the processor's own instructions; nothing is indexed by a
// secret. The repeated rounds were spelled out by a few lines of script; this file is the source.
// Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Kept through an entry: x19 key, x20 nonce, x21 extra bytes, x22 how many, x23 message or sealed bytes, x24 how many, x25 output
// bytes, x26 rounds (10 or 14), x27 the output block, x28 key bytes. v16-v30 the round keys, v8 zero, v9 the fold constant,
// v10 the tag's multiplier, v11 the tag's running value (both with bits turned round in each byte), v12 nonce and counter.
    .arch armv8-a+crypto
    .text
    .global seal
    .global open
    .equ TMP, 160
    .equ W, 176
    .equ FRAME, 416

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

// gather: the four blocks and the first refusals. x0 = 0 if refused. Leaves block addresses in x19, x20, x21, x23.
gather:
    mov     x17, x30
    mov     x27, x0
    mov     x6, x0
    mov     x5, #0
    bl      bytes_at
    cbz     x0, 9f
    mov     x19, x0
    mov     x5, #1
    bl      bytes_at
    cbz     x0, 9f
    mov     x20, x0
    mov     x5, #2
    bl      bytes_at
    cbz     x0, 9f
    mov     x21, x0
    mov     x5, #3
    bl      bytes_at
    cbz     x0, 9f
    mov     x23, x0
    ldr     x28, [x19, #16]
    sub     x28, x28, #64
    cmp     x28, #16
    b.eq    1f
    cmp     x28, #32
    b.ne    8f
1:  ldr     x7, [x20, #16]
    cmp     x7, #76
    b.ne    8f
    ldr     x7, [x27, #16]
    cmp     x7, #64
    b.lo    8f
    ldr     x22, [x21, #16]
    sub     x22, x22, #64
    add     x19, x19, #64
    add     x20, x20, #64
    add     x21, x21, #64
    add     x25, x27, #64
    mov     x0, #1
    ret     x17
8:  mov     x0, #0
9:  ret     x17

// sub_word: w10 through the cipher's substitution, by the instruction itself (v8 is zero)
    .macro  SUBW
    dup     v0.4s, w10
    aese    v0.16b, v8.16b
    mov     w10, v0.s[0]
    .endm
// keys: the round keys from the key at x19 (x28 bytes), into the frame and then v16-v30; also v8, v9, v12
keys:
    movi    v8.16b, #0
    mov     x5, #0x87
    dup     v9.2d, x5
    ldr     x5, [x20]
    ldr     w6, [x20, #8]
    mov     v12.d[0], x5
    mov     v12.s[2], w6
    lsr     x13, x28, #2                // words in the key
    add     x26, x13, #6                // rounds
    add     x9, x26, #1
    lsl     x9, x9, #2                  // words wanted
    add     x8, sp, #W
    mov     x5, #0
1:  ldr     w10, [x19, x5, lsl #2]
    str     w10, [x8, x5, lsl #2]
    add     x5, x5, #1
    cmp     x5, x13
    b.lo    1b
    mov     x6, #0
    mov     w7, #1
2:  sub     x11, x5, #1
    ldr     w10, [x8, x11, lsl #2]
    cbnz    x6, 3f
    ror     w10, w10, #8
    SUBW
    eor     w10, w10, w7
    lsl     w7, w7, #1
    mov     w12, #0x11b
    eor     w12, w7, w12
    tst     w7, #0x100
    csel    w7, w12, w7, ne
    b       4f
3:  cmp     x13, #8
    ccmp    x6, #4, #0, eq
    b.ne    4f
    SUBW
4:  sub     x11, x5, x13
    ldr     w12, [x8, x11, lsl #2]
    eor     w10, w10, w12
    str     w10, [x8, x5, lsl #2]
    add     x5, x5, #1
    add     x6, x6, #1
    cmp     x6, x13
    csel    x6, xzr, x6, eq
    cmp     x5, x9
    b.lo    2b
    ld1     {v16.16b-v19.16b}, [x8], #64
    ld1     {v20.16b-v23.16b}, [x8], #64
    ld1     {v24.16b-v27.16b}, [x8], #64
    ld1     {v28.16b-v30.16b}, [x8]
    ret

// aes1: v0 through the cipher
aes1:
    aese    v0.16b, v16.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v17.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v18.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v19.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v20.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v21.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v22.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v23.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v24.16b
    aesmc   v0.16b, v0.16b
    tbz     x26, #2, a1_short
    aese    v0.16b, v25.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v26.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v27.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v28.16b
    aesmc   v0.16b, v0.16b
    aese    v0.16b, v29.16b
    eor     v0.16b, v0.16b, v30.16b
    b       a1_done
a1_short:
    aese    v0.16b, v25.16b
    eor     v0.16b, v0.16b, v26.16b
a1_done:
    ret

// COUNTER: nonce and the counter in w9 plus a small number, as a block
    .macro  COUNTER v, plus
    add     w5, w9, #\plus
    rev     w5, w5
    mov     v\v\().16b, v12.16b
    mov     v\v\().s[3], w5
    .endm
// crypt: x24 bytes at x23 against the stream, to x25; four blocks in step while there are four
crypt:
    mov     x15, x30
    mov     x10, x23
    mov     x11, x25
    mov     x12, x24
    mov     w9, #2
c_four:
    cmp     x12, #64
    b.lo    c_one
    COUNTER 0, 0
    COUNTER 1, 1
    COUNTER 2, 2
    COUNTER 3, 3
    aese    v0.16b, v16.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v16.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v16.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v16.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v17.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v17.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v17.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v17.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v18.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v18.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v18.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v18.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v19.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v19.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v19.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v19.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v20.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v20.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v20.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v20.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v21.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v21.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v21.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v21.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v22.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v22.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v22.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v22.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v23.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v23.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v23.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v23.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v24.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v24.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v24.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v24.16b
    aesmc   v3.16b, v3.16b
    tbz     x26, #2, c4_short
    aese    v0.16b, v25.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v25.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v25.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v25.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v26.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v26.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v26.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v26.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v27.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v27.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v27.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v27.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v28.16b
    aesmc   v0.16b, v0.16b
    aese    v1.16b, v28.16b
    aesmc   v1.16b, v1.16b
    aese    v2.16b, v28.16b
    aesmc   v2.16b, v2.16b
    aese    v3.16b, v28.16b
    aesmc   v3.16b, v3.16b
    aese    v0.16b, v29.16b
    eor     v0.16b, v0.16b, v30.16b
    aese    v1.16b, v29.16b
    eor     v1.16b, v1.16b, v30.16b
    aese    v2.16b, v29.16b
    eor     v2.16b, v2.16b, v30.16b
    aese    v3.16b, v29.16b
    eor     v3.16b, v3.16b, v30.16b
    b       c4_done
c4_short:
    aese    v0.16b, v25.16b
    eor     v0.16b, v0.16b, v26.16b
    aese    v1.16b, v25.16b
    eor     v1.16b, v1.16b, v26.16b
    aese    v2.16b, v25.16b
    eor     v2.16b, v2.16b, v26.16b
    aese    v3.16b, v25.16b
    eor     v3.16b, v3.16b, v26.16b
c4_done:
    ld1     {v4.16b-v7.16b}, [x10], #64
    eor     v0.16b, v0.16b, v4.16b
    eor     v1.16b, v1.16b, v5.16b
    eor     v2.16b, v2.16b, v6.16b
    eor     v3.16b, v3.16b, v7.16b
    st1     {v0.16b-v3.16b}, [x11], #64
    add     w9, w9, #4
    sub     x12, x12, #64
    b       c_four
c_one:
    cmp     x12, #16
    b.lo    c_tail
    COUNTER 0, 0
    bl      aes1
    ld1     {v4.16b}, [x10], #16
    eor     v0.16b, v0.16b, v4.16b
    st1     {v0.16b}, [x11], #16
    add     w9, w9, #1
    sub     x12, x12, #16
    b       c_one
c_tail:
    cbz     x12, 9f
    COUNTER 0, 0
    bl      aes1
    str     q0, [sp, #TMP]
    add     x7, sp, #TMP
    mov     x5, #0
1:  ldrb    w6, [x10, x5]
    ldrb    w8, [x7, x5]
    eor     w6, w6, w8
    strb    w6, [x11, x5]
    add     x5, x5, #1
    cmp     x5, x12
    b.lo    1b
9:  ret     x15

// gmul: v11 = v0 times the multiplier v10, in the tag's field: a carry-less 128 by 128 multiplication, then the upper half folded
// back by x^128 = x^7 + x^2 + x + 1. Uses v1-v5.
gmul:
    pmull   v1.1q, v0.1d, v10.1d
    pmull2  v2.1q, v0.2d, v10.2d
    ext     v3.16b, v10.16b, v10.16b, #8
    pmull   v4.1q, v0.1d, v3.1d
    pmull2  v5.1q, v0.2d, v3.2d
    eor     v4.16b, v4.16b, v5.16b
    ext     v5.16b, v8.16b, v4.16b, #8
    eor     v1.16b, v1.16b, v5.16b
    ext     v5.16b, v4.16b, v8.16b, #8
    eor     v2.16b, v2.16b, v5.16b
    pmull2  v3.1q, v2.2d, v9.2d
    ext     v5.16b, v8.16b, v3.16b, #8
    eor     v1.16b, v1.16b, v5.16b
    ext     v5.16b, v3.16b, v8.16b, #8
    eor     v2.16b, v2.16b, v5.16b
    pmull   v3.1q, v2.1d, v9.1d
    eor     v11.16b, v1.16b, v3.16b
    ret
// absorb: x1 bytes at x0 into the running value, the last block filled out with zeros
absorb:
    mov     x16, x30
1:  cmp     x1, #16
    b.lo    2f
    ld1     {v0.16b}, [x0], #16
    rbit    v0.16b, v0.16b
    eor     v0.16b, v0.16b, v11.16b
    bl      gmul
    sub     x1, x1, #16
    b       1b
2:  cbz     x1, 9f
    stp     xzr, xzr, [sp, #TMP]
    add     x6, sp, #TMP
    mov     x5, #0
3:  ldrb    w7, [x0, x5]
    strb    w7, [x6, x5]
    add     x5, x5, #1
    cmp     x5, x1
    b.lo    3b
    ldr     q0, [sp, #TMP]
    rbit    v0.16b, v0.16b
    eor     v0.16b, v0.16b, v11.16b
    bl      gmul
9:  ret     x16
// tag_of: the tag over the extra bytes and the x24 locked bytes at x0 -> v0
tag_of:
    mov     x14, x30
    mov     x13, x0
    movi    v0.16b, #0
    bl      aes1
    rbit    v10.16b, v0.16b
    movi    v11.16b, #0
    mov     x0, x21
    mov     x1, x22
    bl      absorb
    mov     x0, x13
    mov     x1, x24
    bl      absorb
    lsl     x5, x22, #3
    rev     x5, x5
    lsl     x6, x24, #3
    rev     x6, x6
    stp     x5, x6, [sp, #TMP]
    ldr     q0, [sp, #TMP]
    rbit    v0.16b, v0.16b
    eor     v0.16b, v0.16b, v11.16b
    bl      gmul
    mov     w9, #1
    COUNTER 0, 0
    bl      aes1
    rbit    v1.16b, v11.16b
    eor     v0.16b, v0.16b, v1.16b
    ret     x14

    .macro  ENTER
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    stp     d8, d9, [sp, #96]
    stp     d10, d11, [sp, #112]
    stp     d12, d13, [sp, #128]
    .endm
    .macro  LEAVE
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     d8, d9, [sp, #96]
    ldp     d10, d11, [sp, #112]
    ldp     d12, d13, [sp, #128]
    add     sp, sp, #FRAME
    ret
    .endm

seal:
    ENTER
    bl      gather
    cbz     x0, s_fail
    ldr     x24, [x23, #16]
    sub     x24, x24, #64
    add     x23, x23, #64
    ldr     x7, [x27, #16]
    sub     x7, x7, #64
    add     x8, x24, #16
    cmp     x7, x8
    b.lo    s_fail
    bl      keys
    bl      crypt
    mov     x0, x25
    bl      tag_of
    add     x5, x25, x24
    st1     {v0.16b}, [x5]
    add     x0, x24, #16
    b       s_out
s_fail:
    mov     x0, #-1
s_out:
    LEAVE

open:
    ENTER
    bl      gather
    cbz     x0, o_fail
    ldr     x24, [x23, #16]
    cmp     x24, #80
    b.lo    o_fail
    sub     x24, x24, #80
    add     x23, x23, #64
    ldr     x7, [x27, #16]
    sub     x7, x7, #64
    cmp     x7, x24
    b.lo    o_fail
    bl      keys
    mov     x0, x23
    bl      tag_of
    add     x5, x23, x24
    ld1     {v1.16b}, [x5]
    eor     v0.16b, v0.16b, v1.16b      // every byte is compared; no stopping at the first difference
    umaxv   b0, v0.16b
    fmov    w5, s0
    cbnz    w5, o_fail
    bl      crypt
    mov     x0, x24
    b       o_out
o_fail:
    mov     x0, #-1
o_out:
    LEAVE

