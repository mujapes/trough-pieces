// home, written by hand (ARM64): arranges the home screen and asks the paint and text pieces to draw it. The meaning is
// home/intent.md; the recorded checks are the judge. Entries: x0 surface, x1 numbers (16-bit), x2 how many, x3 argument, x4 table.
// Through render and hit: x19 the surface, x20 the table, w21 width, w22 height, x23 calls made, w24 the pressed tile, x25 a counter,
// w26, w27, w28 a tile's left, top and size; x29 the frame (the numbers handed on are built at Q in it). Whole-number arithmetic is 32-bit and divisions round towards zero, as the meaning says.
    .text
    .global check
    .global render
    .global hit
    .equ Q, 96
    .equ CLOCK, 176
    .equ FRAME, 192
check:
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
// tile: where tile w0 is -> w26 left, w27 top, w28 size. Uses x9-x12.
tile:
    mov     w9, #4
    sdiv    w9, w21, w9                 // column
    mov     w10, #7
    sdiv    w10, w22, w10
    sub     w11, w22, #76
    sub     w11, w11, w10
    mov     w10, #4
    sdiv    w11, w11, w10               // step
    lsl     w28, w9, #1
    mov     w10, #3
    sdiv    w28, w28, w10
    and     w12, w0, #3
    mul     w26, w12, w9
    sub     w12, w9, w28
    mov     w10, #2
    sdiv    w12, w12, w10
    add     w26, w26, w12
    lsr     w12, w0, #2
    mul     w27, w12, w11
    add     w27, w27, #64
    ret
// rect: a filled rectangle w0, w1 (left, top), w2, w3 (width, height) in the colour x4
rect:
    stp     x29, x30, [sp, #-16]!
    strh    w0, [x29, #Q]
    strh    w1, [x29, #(Q + 2)]
    strh    w2, [x29, #(Q + 4)]
    strh    w3, [x29, #(Q + 6)]
    mov     x3, x4
    mov     x0, x19
    add     x1, x29, #Q
    mov     x2, #4
    mov     x4, x20
    ldr     x9, [x20, #(4 * 8)]
    blr     x9
    add     x23, x23, #1
    ldp     x29, x30, [sp], #16
    ret
// words: the text at x2 (ending in a zero byte, at most 38 letters) at w0, w1, centred on w0 if w3 is set, in the colour x4
words:
    stp     x29, x30, [sp, #-64]!
    stp     x0, x1, [sp, #16]
    stp     x3, x4, [sp, #32]
    add     x10, x29, #(Q + 4)
    mov     x11, #0
1:  ldrb    w12, [x2, x11]
    cbz     w12, 2f
    cmp     x11, #38
    b.hs    2f
    strh    w12, [x10, x11, lsl #1]
    add     x11, x11, #1
    b       1b
2:  str     x11, [sp, #48]
    cbz     w3, 3f
    mov     x0, x19
    mov     x1, x10
    mov     x2, x11
    mov     x3, #0
    mov     x4, x20
    ldr     x9, [x20, #(6 * 8)]
    blr     x9
    mov     w9, #2
    sdiv    w0, w0, w9
    ldr     w10, [sp, #16]
    sub     w10, w10, w0
    str     w10, [sp, #16]
    add     x23, x23, #1
3:  ldr     w10, [sp, #16]
    ldr     w11, [sp, #24]
    add     x1, x29, #Q
    strh    w10, [x1]
    strh    w11, [x1, #2]
    ldr     x2, [sp, #48]
    add     x2, x2, #2
    ldr     x3, [sp, #40]
    mov     x0, x19
    mov     x4, x20
    ldr     x9, [x20, #(5 * 8)]
    blr     x9
    add     x23, x23, #1
    ldp     x29, x30, [sp], #64
    ret

    .macro  ENTER
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x29, sp
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
    .macro  RECT x, y, w, h, colour
    mov     w0, \x
    mov     w1, \y
    mov     w2, \w
    mov     w3, \h
    ldr     w4, =\colour
    bl      rect
    .endm
// wrap: w0 into 0 to w1 - 1, whatever its sign
wrap:
    sdiv    w9, w0, w1
    msub    w0, w9, w1, w0
    add     w0, w0, w1
    sdiv    w9, w0, w1
    msub    w0, w9, w1, w0
    ret
render:
    ENTER
    mov     x19, x0
    mov     x20, x4
    ldr     w21, [x19, #4]
    ldr     w22, [x19, #8]
    mov     w24, #-1
    mov     w25, #0                     // hour
    mov     w26, #0                     // minute
    cmp     x2, #0
    b.le    1f
    ldrsh   w24, [x1]
    cmp     x2, #1
    b.le    1f
    ldrsh   w25, [x1, #2]
    cmp     x2, #2
    b.le    1f
    ldrsh   w26, [x1, #4]
1:  mov     w0, w25
    mov     w1, #24
    bl      wrap
    mov     w25, w0
    mov     w0, w26
    mov     w1, #60
    bl      wrap
    mov     w26, w0
    add     x10, x29, #CLOCK            // the clock's letters
    mov     w11, #10
    udiv    w12, w25, w11
    msub    w13, w12, w11, w25
    cbz     w12, 2f
    add     w12, w12, #'0'
    strb    w12, [x10], #1
2:  add     w13, w13, #'0'
    strb    w13, [x10], #1
    mov     w13, #':'
    strb    w13, [x10], #1
    udiv    w12, w26, w11
    msub    w13, w12, w11, w26
    add     w12, w12, #'0'
    strb    w12, [x10], #1
    add     w13, w13, #'0'
    strb    w13, [x10], #1
    strb    wzr, [x10]
    mov     x0, x19                     // the background
    mov     x1, #0
    mov     x2, #0
    ldr     w3, =0xff1a1410
    mov     x4, x20
    ldr     x9, [x20, #(3 * 8)]
    blr     x9
    mov     x23, #1
    RECT    #0, #0, w21, #28, 0xff2b221c
    mov     w0, #12
    mov     w1, #3
    add     x2, x29, #CLOCK
    mov     w3, #0
    ldr     w4, =0xffd8d0c8
    bl      words
    mov     w9, #2
    sdiv    w0, w21, w9
    mov     w1, #34
    adr     x2, r_title
    mov     w3, #1
    ldr     w4, =0xff8a8078
    bl      words
    mov     x25, #0
3:  mov     w0, w25
    bl      tile
    add     w0, w26, #3                 // its shadow
    add     w1, w27, #4
    mov     w2, w28
    mov     w3, w28
    ldr     w4, =0xff0e0b09
    bl      rect
    cmp     w25, w24
    b.ne    4f
    sub     w0, w26, #3                 // the frame of a pressed tile
    sub     w1, w27, #3
    add     w2, w28, #6
    add     w3, w28, #6
    ldr     w4, =0xfff0ece8
    bl      rect
4:  adr     x9, r_colours
    and     x10, x25, #7
    ldr     w4, [x9, x10, lsl #2]
    mov     w0, w26
    mov     w1, w27
    mov     w2, w28
    mov     w3, w28
    bl      rect
    mov     w9, #2
    sdiv    w9, w28, w9
    add     w0, w26, w9
    add     w1, w27, w28
    add     w1, w1, #4
    adr     x2, r_names
    add     x2, x2, x25, lsl #3
    mov     w3, #1
    ldr     w4, =0xffc8c0b8
    bl      words
    add     x25, x25, #1
    cmp     x25, #16
    b.lo    3b
    mov     w9, #9                      // the dock
    sdiv    w26, w22, w9                // its height
    sub     w27, w22, #12
    sub     w27, w27, w26               // its top
    add     w28, w26, w26, lsl #1
    mov     w9, #4
    sdiv    w28, w28, w9                // the size of a thing in it
    sub     w24, w21, #32
    sub     w24, w24, w28, lsl #2
    mov     w9, #5
    sdiv    w24, w24, w9                // the gap between them
    mov     w0, #16
    mov     w1, w27
    sub     w2, w21, #32
    mov     w3, w26
    ldr     w4, =0xff2b221c
    bl      rect
    sub     w9, w26, w28
    mov     w10, #2
    sdiv    w9, w9, w10
    add     w27, w27, w9
    mov     x25, #0
5:  add     w9, w28, w24
    mul     w9, w9, w25
    add     w0, w9, #16
    add     w0, w0, w24
    mov     w1, w27
    mov     w2, w28
    mov     w3, w28
    adr     x9, r_colours
    add     x10, x25, #3
    and     x10, x10, #7
    ldr     w4, [x9, x10, lsl #2]
    bl      rect
    add     x25, x25, #1
    cmp     x25, #4
    b.lo    5b
    mov     x0, x23
    LEAVE
    .ltorg
r_title:
    .asciz  "Home, made of pieces"
    .balign 8
r_names:
    .ascii  "Trough"
    .zero   2
    .ascii  "Music"
    .zero   3
    .ascii  "Video"
    .zero   3
    .ascii  "Maps"
    .zero   4
    .ascii  "Browser"
    .zero   1
    .ascii  "Voice"
    .zero   3
    .ascii  "Files"
    .zero   3
    .ascii  "Pieces"
    .zero   2
    .ascii  "Reddit"
    .zero   2
    .ascii  "Notes"
    .zero   3
    .ascii  "Camera"
    .zero   2
    .ascii  "Games"
    .zero   3
    .ascii  "Clock"
    .zero   3
    .ascii  "Mail"
    .zero   4
    .ascii  "Photos"
    .zero   2
    .ascii  "Phone"
    .zero   3
r_colours:
    .word   0xff5a9cf0, 0xff6bcf7f, 0xfff0b45a, 0xffd66fb0, 0xff5ad0d8, 0xffe07a5a, 0xff9f8cf0, 0xffc8d05a

hit:
    ENTER
    mov     x19, x0
    ldr     w21, [x19, #4]
    ldr     w22, [x19, #8]
    mov     w23, #0
    mov     w24, #0
    cmp     x2, #0
    b.le    1f
    ldrsh   w23, [x1]                   // where the finger is
    cmp     x2, #1
    b.le    1f
    ldrsh   w24, [x1, #2]
1:  mov     x25, #0
2:  mov     w0, w25
    bl      tile
    cmp     w23, w26
    b.lt    3f
    add     w9, w26, w28
    cmp     w23, w9
    b.ge    3f
    cmp     w24, w27
    b.lt    3f
    add     w9, w27, w28
    cmp     w24, w9
    b.ge    3f
    mov     x0, x25
    b       4f
3:  add     x25, x25, #1
    cmp     x25, #16
    b.lo    2b
    mov     x0, #-1
4:  LEAVE
