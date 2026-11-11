// cover, written by hand (ARM64): how much of each dot a shape covers, for smooth edges. The meaning is cover/intent.md; the
// recorded checks are the judge. Entries: x0 surface (one byte a dot), x1 numbers (16-bit), x2 how many, x3 argument, x4 table.
// Calls nothing. Positions are in sixteenths of a dot; each dot has 4 by 4 sample points; the winding rule is non-zero.
// The frame holds the edges (four 32-bit lists of 1024), one scan line's crossings and their directions, and one row of tallies.
    .text
    .global check
    .global cover_path
    .equ FRAME, 37984
check:
    ldr     w9, [x0]
    cmp     w9, #4
    b.ne    9f
    ldr     w10, [x0, #4]
    ldr     w11, [x0, #8]
    ldr     w12, [x0, #12]
    ldr     x13, [x0, #16]
    sub     w14, w10, #1
    cmp     w14, #16384
    b.hs    9f
    sub     w14, w11, #1
    cmp     w14, #16384
    b.hs    9f
    cmp     w12, w10
    b.ne    9f
    umull   x14, w12, w11
    add     x14, x14, #64
    cmp     x13, x14
    b.ne    9f
    mov     x0, #1
    ret
9:  mov     x0, #0
    ret

cover_path:
    mov     x9, #FRAME
    sub     sp, sp, x9
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, x0
    add     x20, sp, #96                // the edges: x0 here, y0 at +4096, x1 at +8192, y1 at +12288
    mov     x9, #0                      // where we are in the numbers
    mov     w21, #0                     // edges
    mov     w10, #0                     // outlines
    mov     w11, #32767                 // top
    mov     w12, #-32768                // bottom
    mov     w13, #32767                 // left
    mov     w14, #-32768                // right
p_loop:                                 // well formed? gather the edges and the bounds
    cmp     x9, x2
    b.ge    p_done
    ldrsh   w15, [x1, x9, lsl #1]       // points in this outline
    cmp     w15, #2
    b.lt    c_bad
    cmp     w15, #256
    b.gt    c_bad
    add     x16, x9, #1
    add     x16, x16, w15, uxtw #1
    cmp     x16, x2
    b.gt    c_bad
    add     w17, w21, w15
    cmp     w17, #1024
    b.gt    c_bad
    add     x3, x1, x9, lsl #1
    add     x3, x3, #2
    mov     w4, #0
e_loop:
    add     w5, w4, #1
    cmp     w5, w15
    csel    w5, wzr, w5, eq             // the next point, the first again after the last
    lsl     w6, w4, #1
    ldrsh   w7, [x3, x6, lsl #1]
    add     w6, w6, #1
    ldrsh   w8, [x3, x6, lsl #1]
    lsl     w6, w5, #1
    ldrsh   w22, [x3, x6, lsl #1]
    add     w6, w6, #1
    ldrsh   w23, [x3, x6, lsl #1]
    add     x24, x20, x21, lsl #2
    str     w7, [x24]
    str     w8, [x24, #4096]
    str     w22, [x24, #8192]
    str     w23, [x24, #12288]
    add     w21, w21, #1
    cmp     w7, w13
    csel    w13, w7, w13, lt
    cmp     w7, w14
    csel    w14, w7, w14, gt
    cmp     w8, w11
    csel    w11, w8, w11, lt
    cmp     w8, w12
    csel    w12, w8, w12, gt
    add     w4, w4, #1
    cmp     w4, w15
    b.lt    e_loop
    mov     x9, x16
    add     w10, w10, #1
    b       p_loop
p_done:
    cbz     w10, c_bad
    ldr     w3, [x19, #4]
    ldr     w4, [x19, #8]
    asr     w22, w11, #4                // first and last row, first and last column, kept inside the surface
    asr     w23, w12, #4
    asr     w24, w13, #4
    asr     w25, w14, #4
    cmp     w22, #0
    csel    w22, wzr, w22, lt
    sub     w5, w4, #1
    cmp     w23, w5
    csel    w23, w5, w23, gt
    cmp     w24, #0
    csel    w24, wzr, w24, lt
    sub     w5, w3, #1
    cmp     w25, w5
    csel    w25, w5, w25, gt
    cmp     w22, w23
    b.gt    c_none
    cmp     w24, w25
    b.gt    c_none
    sub     w26, w25, w24
    add     w26, w26, #1                // dots across
    mov     x27, #0                     // dots inked
    mov     x5, #16384
    add     x5, x20, x5                 // crossings
    add     x6, x5, #4096               // their directions
    add     x7, x6, #1024               // the row's tallies
row_loop:
    mov     x9, #0
1:  strb    wzr, [x7, x9]
    add     x9, x9, #1
    cmp     w9, w26
    b.lt    1b
    mov     w28, #0
sub_loop:                               // four scan lines to a row
    lsl     w11, w22, #4
    add     w11, w11, #2
    add     w11, w11, w28, lsl #2
    mov     w9, #0
    mov     x10, #0
edge:
    cmp     w10, w21
    b.ge    edges_done
    add     x12, x20, x10, lsl #2
    add     x10, x10, #1
    ldr     w13, [x12, #4096]
    ldr     w14, [x12, #12288]
    cmp     w13, w11
    b.gt    2f
    cmp     w11, w14
    b.ge    2f
    mov     w15, #1                     // crossed going down
    b       3f
2:  cmp     w14, w11
    b.gt    edge
    cmp     w11, w13
    b.ge    edge
    mov     w15, #-1                    // crossed going up
3:  ldr     w16, [x12]
    ldr     w17, [x12, #8192]
    sub     w0, w11, w13
    sub     w1, w17, w16
    smull   x0, w0, w1
    sub     w1, w14, w13
    sxtw    x1, w1
    sdiv    x2, x0, x1                  // divided rounding down, not towards zero
    msub    x3, x2, x1, x0
    cbz     x3, 4f
    eor     x3, x0, x1
    tbz     x3, #63, 4f
    sub     x2, x2, #1
4:  add     w16, w16, w2                // where it crosses
    mov     w0, w9                      // put in order of position; equal positions keep the order of their edges
    add     w9, w9, #1
5:  cbz     w0, 6f
    sub     w1, w0, #1
    ldr     w2, [x5, w1, uxtw #2]
    cmp     w2, w16
    b.le    6f
    str     w2, [x5, w0, uxtw #2]
    ldrb    w3, [x6, w1, uxtw]
    strb    w3, [x6, w0, uxtw]
    mov     w0, w1
    b       5b
6:  str     w16, [x5, w0, uxtw #2]
    strb    w15, [x6, w0, uxtw]
    b       edge
edges_done:
    mov     w12, #0                     // the winding count
    lsl     w13, w24, #2
    add     w14, w25, #1
    lsl     w14, w14, #2
    mov     w10, #0
run:                                    // between two neighbouring crossings every sample has the same answer
    add     w0, w10, #1
    cmp     w0, w9
    b.ge    runs_done
    ldrsb   w1, [x6, w10, uxtw]
    add     w12, w12, w1
    ldrsw   x2, [x5, w10, uxtw #2]
    ldrsw   x3, [x5, w0, uxtw #2]
    mov     w10, w0
    cbz     w12, run
    add     x2, x2, #1
    asr     x2, x2, #2                  // first sample inside
    add     x3, x3, #1
    asr     x3, x3, #2                  // first sample past it
    cmp     w2, w13
    csel    w2, w13, w2, lt
    cmp     w3, w14
    csel    w3, w14, w3, gt
    cmp     w2, w3
    b.ge    run
    asr     w15, w2, #2
    sub     w15, w15, w24
    sub     w16, w3, #1
    asr     w17, w16, #2
    sub     w17, w17, w24
    cmp     w15, w17
    b.ne    7f
    ldrb    w0, [x7, w15, sxtw]
    add     w0, w0, w3
    sub     w0, w0, w2
    strb    w0, [x7, w15, sxtw]
    b       run
7:  ldrb    w0, [x7, w15, sxtw]
    and     w1, w2, #3
    add     w0, w0, #4
    sub     w0, w0, w1
    strb    w0, [x7, w15, sxtw]
    add     w15, w15, #1
8:  cmp     w15, w17
    b.ge    9f
    ldrb    w0, [x7, w15, sxtw]
    add     w0, w0, #4
    strb    w0, [x7, w15, sxtw]
    add     w15, w15, #1
    b       8b
9:  ldrb    w0, [x7, w17, sxtw]
    and     w1, w16, #3
    add     w0, w0, w1
    add     w0, w0, #1
    strb    w0, [x7, w17, sxtw]
    b       run
runs_done:
    add     w28, w28, #1
    cmp     w28, #4
    b.lt    sub_loop
    ldr     w0, [x19, #12]              // the tallies become ink: sixteen samples are full
    umull   x0, w22, w0
    add     x0, x0, x19
    add     x0, x0, #64
    add     x0, x0, w24, sxtw
    mov     w1, #0
1:  ldrb    w2, [x7, w1, uxtw]
    cbz     w2, 2f
    mov     w3, #255
    mul     w2, w2, w3
    add     w2, w2, #8
    lsr     w2, w2, #4
    strb    w2, [x0, w1, uxtw]
    add     x27, x27, #1
2:  add     w1, w1, #1
    cmp     w1, w26
    b.lt    1b
    add     w22, w22, #1
    cmp     w22, w23
    b.le    row_loop
    mov     x0, x27
    b       c_out
c_none:
    mov     x0, #0
    b       c_out
c_bad:
    mov     x0, #-1
c_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    mov     x9, #FRAME
    add     sp, sp, x9
    ret
