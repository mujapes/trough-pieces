// reload, written by hand (ARM64): the judge of one record of the code stream. The meaning is reload/intent.md; the recorded
// checks are the judge of this piece. Entries: x0 block (working room), x1 numbers (16-bit), x2 how many, x3 argument (where the
// record starts in the stream), x4 call table. Calls the hash piece (socket 14) with a table of its own.
// Through an entry: x19 the block, x20 the stream's bytes, x21 how many, x22 the record's start, x23 the real table,
// x24 the record's total length, x25 name length, x26 entries length, x27 code length.
    .text
    .global record
    .global part
    .equ DIGEST, 96                     // a block of this piece's own for the hash's answer: 64-byte head, 64 bytes
    .equ Q, 224
    .equ KEPT, 240                      // three values kept across calls
    .equ MINE, 272
    .equ FRAME, 272 + 4096
// judge: the record at x22 in the stream -> x0 its total length, 0, -1 or -2 (as intent.md says for "record")
judge:
    str     x30, [sp, #(KEPT + 16)]
    add     x9, x22, #32                // the fixed part must be there before anything is believed
    cmp     x22, x21
    b.hi    j_wait
    cmp     x9, x21
    b.hi    j_wait
    add     x10, x20, x22
    ldr     w11, [x10]
    ldr     w12, =0x43505254            // "TRPC"
    cmp     w11, w12
    b.ne    j_bad
    ldr     w24, [x10, #4]
    ldr     w25, [x10, #8]
    ldr     w26, [x10, #12]
    ldr     w27, [x10, #16]
    ldr     w11, [x10, #20]
    ldr     x12, [x10, #24]
    orr     x11, x11, x12
    cbnz    x11, j_bad
    sub     w11, w25, #1                // name 1 to 40, entries 1 to 4096, code 4 to 1048576 and whole instructions
    cmp     w11, #39
    b.hi    j_bad
    sub     w11, w26, #1
    cmp     w11, #4095
    b.hi    j_bad
    sub     w11, w27, #4
    mov     w12, #(1048576 - 4)
    cmp     w11, w12
    b.hi    j_bad
    tst     w27, #3
    b.ne    j_bad
    add     x11, x25, x26
    add     x11, x11, x27
    add     x11, x11, #64
    cmp     x11, x24
    b.ne    j_bad
    add     x11, x22, x24               // is all of it here yet?
    cmp     x11, x21
    b.hi    j_wait
    mov     x11, #0                     // the name: a to z, 0 to 9, -
1:  add     x12, x10, #32
    ldrb    w12, [x12, x11]
    sub     w13, w12, #'a'
    cmp     w13, #25
    b.ls    2f
    sub     w13, w12, #'0'
    cmp     w13, #9
    b.ls    2f
    cmp     w12, #'-'
    b.ne    j_bad
2:  add     x11, x11, #1
    cmp     x11, x25
    b.lo    1b
    ldr     x11, [x19, #16]             // the working room must hold the sealed bytes
    sub     x12, x24, #32
    add     x13, x12, #64
    cmp     x11, x13
    b.lo    j_small
    stp     xzr, xzr, [x19]             // the block becomes a plain block holding exactly the sealed bytes
    stp     xzr, xzr, [x19, #16]
    stp     xzr, xzr, [x19, #32]
    stp     xzr, xzr, [x19, #48]
    mov     w14, #2
    str     w14, [x19]
    str     x13, [x19, #16]
    add     x14, x19, #64
    mov     x15, #0
3:  ldrb    w16, [x10, x15]
    strb    w16, [x14, x15]
    add     x15, x15, #1
    cmp     x15, x12
    b.lo    3b
    add     x0, sp, #DIGEST             // its SHA-256, by the hash piece
    stp     xzr, xzr, [x0]
    stp     xzr, xzr, [x0, #16]
    stp     xzr, xzr, [x0, #32]
    stp     xzr, xzr, [x0, #48]
    mov     w14, #2
    str     w14, [x0]
    mov     x14, #128
    str     x14, [x0, #16]
    add     x9, sp, #MINE
    mov     x14, #0
4:  ldr     x15, [x23, x14, lsl #3]     // a table of this piece's own: the real sockets, and one handle
    cmp     x14, #256
    csel    x15, x15, xzr, lo
    str     x15, [x9, x14, lsl #3]
    add     x14, x14, #1
    cmp     x14, #512
    b.lo    4b
    str     x19, [x9, #(257 * 8)]
    mov     w14, #1
    strh    w14, [sp, #Q]
    add     x1, sp, #Q
    mov     x2, #1
    mov     x3, #0
    mov     x4, x9
    ldr     x9, [x23, #(14 * 8)]
    blr     x9
    cmp     x0, #32
    b.ne    j_bad
    add     x11, x22, x24
    add     x11, x20, x11
    sub     x11, x11, #32               // the seal written in the record
    add     x12, sp, #(DIGEST + 64)
    ldp     x13, x14, [x11]
    ldp     x15, x16, [x12]
    eor     x13, x13, x15
    eor     x14, x14, x16
    orr     x13, x13, x14
    ldp     x14, x15, [x11, #16]
    ldp     x16, x17, [x12, #16]
    eor     x14, x14, x16
    eor     x15, x15, x17
    orr     x13, x13, x14
    orr     x13, x13, x15
    cbnz    x13, j_bad
    mov     x0, x24
    b       j_out
j_wait:
    mov     x0, #0
    b       j_out
j_small:
    mov     x0, #-2
    b       j_out
j_bad:
    mov     x0, #-1
j_out:
    ldr     x30, [sp, #(KEPT + 16)]
    ret
    .ltorg

    .macro  ENTER
    sub     sp, sp, #4064
    sub     sp, sp, #(FRAME - 4064)
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, x0
    mov     x22, x3
    mov     x23, x4
    mov     x28, x1
    mov     x29, x2
    mov     x20, #0                     // the stream: a plain block, not the working room
    cmp     x2, #1
    b.lt    80f
    ldrsh   x9, [x1]
    cmp     x9, #0
    b.lt    80f
    cmp     x9, #255
    b.gt    80f
    add     x9, x9, #256
    ldr     x9, [x4, x9, lsl #3]
    cbz     x9, 80f
    ldr     w10, [x9]
    cmp     w10, #2
    b.ne    80f
    ldr     x21, [x9, #16]
    cmp     x21, #64
    b.lo    80f
    sub     x21, x21, #64
    add     x20, x9, #64
80:
    .endm
    .macro  LEAVE
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #4064
    add     sp, sp, #(FRAME - 4064)
    ret
    .endm
record:
    ENTER
    cbz     x20, 1f
    sub     x9, x20, #64
    cmp     x9, x19
    b.eq    2f
    ldr     x9, [x19, #16]
    cmp     x9, #64
    b.lo    2f
    bl      judge
    b       3f
1:  mov     x0, #-1
    b       3f
2:  mov     x0, #-2
3:  LEAVE
part:
    ENTER
    cbz     x20, p_bad
    sub     x9, x20, #64
    cmp     x9, x19
    b.eq    p_bad
    ldr     x9, [x19, #16]
    cmp     x9, #64
    b.lo    p_bad
    cmp     x29, #2
    b.lt    p_bad
    ldrsh   x28, [x28, #2]              // which part
    cmp     x28, #2
    b.hi    p_bad
    ldr     x9, [x19, #16]              // the room, before the judging uses the block
    str     x9, [sp, #KEPT]
    bl      judge
    cmp     x0, #0
    b.le    p_bad
    ldr     x9, [sp, #KEPT]              // the block again as it was given: plain bytes of its real size
    stp     xzr, xzr, [x19]
    stp     xzr, xzr, [x19, #16]
    stp     xzr, xzr, [x19, #32]
    stp     xzr, xzr, [x19, #48]
    mov     w10, #2
    str     w10, [x19]
    str     x9, [x19, #16]
    add     x10, x20, x22
    add     x10, x10, #32               // the name
    mov     x11, x25
    cbz     x28, 1f
    add     x10, x10, x25               // the entries list
    mov     x11, x26
    cmp     x28, #1
    b.eq    1f
    add     x10, x10, x26               // the code
    mov     x11, x27
1:  sub     x9, x9, #64
    cmp     x11, x9
    b.hi    p_bad
    add     x12, x19, #64
    mov     x13, #0
2:  ldrb    w14, [x10, x13]
    strb    w14, [x12, x13]
    add     x13, x13, #1
    cmp     x13, x11
    b.lo    2b
    mov     x0, x11
    b       p_out
p_bad:
    mov     x0, #-1
p_out:
    LEAVE
