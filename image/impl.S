// image, written by hand (ARM64): puts one picture onto another: copied, picked dot by dot, shrunk by averaging, or enlarged by
// blending. The meaning is image/intent.md; the recorded checks are the judge.
// Entries: x0 surface (four bytes a dot), x1 numbers (16-bit): the source's handle, left, top, width, height; x2 how many; x4 table.
// Through an entry: x19 the surface, x20 the source, x21 left, x22 top, x23 width, x24 height, x25 dots touched, x26 the row,
// x27 the column, x28 the start of the surface's row. Calls nothing.
    .text
    .global check
    .global blit
    .global scale
    .global smooth
    .global stretch
    .equ MIX, 96
    .equ FRAME, 112
// sound: is x0 a well-formed surface -> x0 1 or 0. Uses x9-x14.
sound:
    ldr     w9, [x0]
    cmp     w9, #1
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
    cmp     w12, w10, lsl #2
    b.ne    9f
    umull   x14, w12, w11
    add     x14, x14, #64
    cmp     x13, x14
    b.ne    9f
    mov     x0, #1
    ret
9:  mov     x0, #0
    ret
check:
    b       sound
// over: the dot at x1 over the dot at x0, by its own alpha; counted in x25 if it had any. Uses x9-x13.
over:
    ldrb    w9, [x1, #3]
    cbz     w9, 9f
    mov     w10, #255
    sub     w11, w10, w9
    .macro  CHANNEL off
    ldrb    w12, [x0, #\off]
    mul     w12, w12, w11
    .if \off < 3
    ldrb    w13, [x1, #\off]
    .else
    mov     w13, #255
    .endif
    madd    w12, w13, w9, w12
    add     w12, w12, #127
    udiv    w12, w12, w10
    strb    w12, [x0, #\off]
    .endm
    CHANNEL 0
    CHANNEL 1
    CHANNEL 2
    CHANNEL 3
    add     x25, x25, #1
9:  ret
// begin: the frame, the source (x20, 0 if there is no usable one) and the numbers
    .macro  ENTER
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, x0
    mov     x21, #0
    mov     x22, #0
    mov     x23, #0
    mov     x24, #0
    mov     x25, #0
    mov     x9, #0
    cmp     x2, #0
    b.le    70f
    ldrsh   x9, [x1]
    cmp     x2, #1
    b.le    70f
    ldrsh   x21, [x1, #2]
    cmp     x2, #2
    b.le    70f
    ldrsh   x22, [x1, #4]
    cmp     x2, #3
    b.le    70f
    ldrsh   x23, [x1, #6]
    cmp     x2, #4
    b.le    70f
    ldrsh   x24, [x1, #8]
70: mov     x20, #0
    cmp     x9, #0
    b.lt    71f
    cmp     x9, #255
    b.gt    71f
    add     x9, x9, #256
    ldr     x20, [x4, x9, lsl #3]
    cbz     x20, 71f
    cmp     x20, x19
    csel    x20, xzr, x20, eq
    cbz     x20, 71f
    mov     x0, x20
    bl      sound
    cmp     x0, #0
    csel    x20, xzr, x20, eq
71:
    .endm
    .macro  LEAVE
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #FRAME
    ret
    .endm
// ROW: the surface's row for the picture's row x26 -> x28 its start, or on to \skip if it is off the surface
    .macro  ROW skip
    add     x9, x22, x26
    ldr     w10, [x19, #8]
    cmp     x9, #0
    b.lt    \skip
    cmp     x9, x10
    b.ge    \skip
    ldr     w10, [x19, #12]
    mul     x28, x9, x10
    add     x28, x28, x19
    add     x28, x28, #64
    .endm
// DOT: the surface's dot for the picture's column x27 -> x0, or on to \skip if it is off the surface
    .macro  DOT skip
    add     x9, x21, x27
    ldr     w10, [x19, #4]
    cmp     x9, #0
    b.lt    \skip
    cmp     x9, x10
    b.ge    \skip
    add     x0, x28, x9, lsl #2
    .endm

blit:
    ENTER
    cbz     x20, b_bad
    mov     x26, #0
b_row:
    ldr     w9, [x20, #8]
    cmp     x26, x9
    b.ge    b_done
    ROW     b_next
    ldr     w9, [x20, #12]
    mul     x14, x26, x9
    add     x14, x14, x20
    add     x14, x14, #64
    mov     x27, #0
b_col:
    ldr     w9, [x20, #4]
    cmp     x27, x9
    b.ge    b_next
    DOT     1f
    add     x1, x14, x27, lsl #2
    bl      over
1:  add     x27, x27, #1
    b       b_col
b_next:
    add     x26, x26, #1
    b       b_row
b_done:
    mov     x0, x25
    b       b_out
b_bad:
    mov     x0, #-1
b_out:
    LEAVE

scale:
    ENTER
    cbz     x20, s_bad
    cmp     x23, #0
    b.le    s_done
    cmp     x24, #0
    b.le    s_done
    mov     x26, #0
s_row:
    cmp     x26, x24
    b.ge    s_done
    ROW     s_next
    lsl     x9, x26, #1
    add     x9, x9, #1
    ldr     w10, [x20, #8]
    mul     x9, x9, x10
    lsl     x10, x24, #1
    sdiv    x9, x9, x10                 // the source row this row comes from
    ldr     w10, [x20, #12]
    mul     x14, x9, x10
    add     x14, x14, x20
    add     x14, x14, #64
    mov     x27, #0
s_col:
    cmp     x27, x23
    b.ge    s_next
    DOT     1f
    lsl     x9, x27, #1
    add     x9, x9, #1
    ldr     w10, [x20, #4]
    mul     x9, x9, x10
    lsl     x10, x23, #1
    sdiv    x9, x9, x10
    add     x1, x14, x9, lsl #2
    bl      over
1:  add     x27, x27, #1
    b       s_col
s_next:
    add     x26, x26, #1
    b       s_row
s_done:
    mov     x0, x25
    b       s_out
s_bad:
    mov     x0, #-1
s_out:
    LEAVE

smooth:
    ENTER
    cbz     x20, m_bad
    cmp     x23, #0
    b.le    m_done
    cmp     x24, #0
    b.le    m_done
    mov     x26, #0
m_row:
    cmp     x26, x24
    b.ge    m_done
    ROW     m_next
    mov     x27, #0
m_col:
    cmp     x27, x23
    b.ge    m_next
    DOT     m_skip
    mov     w2, #0                      // sixteen source dots, each weighed by how solid it is
    mov     w3, #0
    mov     w4, #0
    mov     w5, #0
    mov     x14, #0
1:  lsl     x6, x26, #3
    add     x6, x6, x14, lsl #1
    add     x6, x6, #1
    ldr     w7, [x20, #8]
    mul     x6, x6, x7
    lsl     x8, x24, #3
    sdiv    x6, x6, x8
    ldr     w7, [x20, #12]
    mul     x16, x6, x7
    add     x16, x16, x20
    add     x16, x16, #64
    mov     x15, #0
2:  lsl     x7, x27, #3
    add     x7, x7, x15, lsl #1
    add     x7, x7, #1
    ldr     w8, [x20, #4]
    mul     x7, x7, x8
    lsl     x8, x23, #3
    sdiv    x7, x7, x8
    add     x7, x16, x7, lsl #2
    ldrb    w9, [x7, #3]
    ldrb    w10, [x7]
    ldrb    w11, [x7, #1]
    ldrb    w12, [x7, #2]
    madd    w2, w10, w9, w2
    madd    w3, w11, w9, w3
    madd    w4, w12, w9, w4
    add     w5, w5, w9
    add     x15, x15, #1
    cmp     x15, #4
    b.lo    2b
    add     x14, x14, #1
    cmp     x14, #4
    b.lo    1b
    cbz     w5, m_skip
    lsr     w9, w5, #1
    add     w2, w2, w9
    udiv    w2, w2, w5
    add     w3, w3, w9
    udiv    w3, w3, w5
    add     w4, w4, w9
    udiv    w4, w4, w5
    add     w5, w5, #8
    lsr     w5, w5, #4
    strb    w2, [sp, #MIX]
    strb    w3, [sp, #(MIX + 1)]
    strb    w4, [sp, #(MIX + 2)]
    strb    w5, [sp, #(MIX + 3)]
    add     x1, sp, #MIX
    bl      over
m_skip:
    add     x27, x27, #1
    b       m_col
m_next:
    add     x26, x26, #1
    b       m_row
m_done:
    mov     x0, x25
    b       m_out
m_bad:
    mov     x0, #-1
m_out:
    LEAVE

// AROUND: for output position \pos of \count, over a source \size long: the place it comes from in 256ths, kept on the source
// -> \first the dot before it, \frac how far past that dot, \second the dot after (the same dot at the far edge). Uses x9-x11.
    .macro  AROUND pos, count, size, first, frac, second
    lsl     x9, \pos, #1
    add     x9, x9, #1
    mul     x9, x9, \size
    lsl     x9, x9, #8
    lsl     x10, \count, #1
    sdiv    x9, x9, x10
    sub     x9, x9, #128
    cmp     x9, #0
    csel    x9, xzr, x9, lt
    sub     x10, \size, #1
    lsl     x10, x10, #8
    cmp     x9, x10
    csel    x9, x10, x9, gt
    asr     \first, x9, #8
    and     \frac, x9, #255
    add     x10, \first, #1
    cmp     x10, \size
    csel    \second, x10, \first, lt
    .endm
// GATHER: the source dot at \at with weight \weight into the sums x5, x6, x7 and the solidity x8. Uses x9-x11.
    .macro  GATHER at, weight
    ldrb    w9, [\at, #3]
    mul     x9, x9, \weight
    add     x8, x8, x9
    ldrb    w10, [\at]
    madd    x5, x9, x10, x5
    ldrb    w10, [\at, #1]
    madd    x6, x9, x10, x6
    ldrb    w10, [\at, #2]
    madd    x7, x9, x10, x7
    .endm
stretch:
    ENTER
    cbz     x20, t_bad
    cmp     x23, #0
    b.le    t_done
    cmp     x24, #0
    b.le    t_done
    mov     x26, #0
t_row:
    cmp     x26, x24
    b.ge    t_done
    ROW     t_next
    ldr     w12, [x20, #8]
    AROUND  x26, x24, x12, x15, x14, x16
    ldr     w9, [x20, #12]
    mul     x15, x15, x9
    add     x15, x15, x20
    add     x15, x15, #64               // the source row before, and x16 the row after; x14 how far between them
    mul     x16, x16, x9
    add     x16, x16, x20
    add     x16, x16, #64
    mov     x27, #0
t_col:
    cmp     x27, x23
    b.ge    t_next
    DOT     t_skip
    ldr     w12, [x20, #4]
    AROUND  x27, x23, x12, x2, x3, x4
    mov     x5, #0
    mov     x6, #0
    mov     x7, #0
    mov     x8, #0
    mov     x12, #256
    sub     x13, x12, x3                // 256 - across
    sub     x17, x12, x14               // 256 - down
    add     x1, x15, x2, lsl #2
    mul     x12, x13, x17
    GATHER  x1, x12
    add     x1, x15, x4, lsl #2
    mul     x12, x3, x17
    GATHER  x1, x12
    add     x1, x16, x2, lsl #2
    mul     x12, x13, x14
    GATHER  x1, x12
    add     x1, x16, x4, lsl #2
    mul     x12, x3, x14
    GATHER  x1, x12
    cbz     x8, t_skip
    lsr     x9, x8, #1
    add     x5, x5, x9
    udiv    x5, x5, x8
    add     x6, x6, x9
    udiv    x6, x6, x8
    add     x7, x7, x9
    udiv    x7, x7, x8
    add     x8, x8, #32768
    lsr     x8, x8, #16
    ands    w8, w8, #255
    b.eq    t_skip
    strb    w5, [sp, #MIX]
    strb    w6, [sp, #(MIX + 1)]
    strb    w7, [sp, #(MIX + 2)]
    strb    w8, [sp, #(MIX + 3)]
    add     x1, sp, #MIX
    bl      over
t_skip:
    add     x27, x27, #1
    b       t_col
t_next:
    add     x26, x26, #1
    b       t_row
t_done:
    mov     x0, x25
    b       t_out
t_bad:
    mov     x0, #-1
t_out:
    LEAVE
