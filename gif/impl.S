// gif, written by hand (ARM64): reads GIF pictures, still or moving. The meaning is gif/intent.md; the recorded checks are the judge.
// Entries: x0 surface (four bytes a dot), x1 numbers (16-bit), x2 how many, x3 argument, x4 call table. Calls nothing.
// Through an entry: x19 the frame, x20 the file's bytes, x21 how many, x22 where we are in it, x23 the frame description being
// read; in decode also x24 the frame number, x25 the one wanted, x26 the scratch block, x27 the surface, x28 the picture's area.
    .text
    .global check
    .global size
    .global frames
    .global delay
    .global decode
    // the picture: (bytes and count are x20, x21) 16 first frame, 24 width, 28 height, 32 shared colours, 40 how many
    .equ G, 136
    // a frame: colours, data, how many colours, left, top, width, height, delay, what becomes of it, interlaced, clear colour
    .equ F, 240
    .equ BF, 184
    .equ T, 0
    .equ DATA, 8
    .equ TN, 16
    .equ FX, 20
    .equ FY, 24
    .equ FW, 28
    .equ FH, 32
    .equ DELAY, 36
    .equ DISP, 40
    .equ INTL, 44
    .equ CLR, 48
    .equ CW, 96
    .equ CH, 100
    .equ HAD, 104
    .equ KW, 108
    .equ KH, 112
    .equ SAVED, 120
    .equ INDEX, 128
    .equ FRAME, 304
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
// open_gif: the file in the block x0 (or 0) -> x0 1 or 0; fills G, x20, x21. Uses x9-x12.
open_gif:
    cbz     x0, 9f
    ldr     w9, [x0]
    cmp     w9, #2
    b.ne    9f
    ldr     x21, [x0, #16]
    cmp     x21, #(64 + 13)
    b.lo    9f
    sub     x21, x21, #64
    add     x20, x0, #64
    ldr     w9, [x20]
    ldr     w10, =0x38464947            // "GIF8"
    cmp     w9, w10
    b.ne    9f
    ldrb    w9, [x20, #4]
    cmp     w9, #'7'
    b.eq    1f
    cmp     w9, #'9'
    b.ne    9f
1:  ldrb    w9, [x20, #5]
    cmp     w9, #'a'
    b.ne    9f
    ldrh    w9, [x20, #6]
    ldrh    w10, [x20, #8]
    stp     w9, w10, [x19, #(G + 24)]
    str     xzr, [x19, #(G + 32)]
    str     wzr, [x19, #(G + 40)]
    mov     x11, #13
    ldrb    w12, [x20, #10]
    tbz     w12, #7, 2f
    str     x11, [x19, #(G + 32)]
    and     w12, w12, #7
    mov     w11, #2
    lsl     w11, w11, w12
    str     w11, [x19, #(G + 40)]
    add     x11, x11, x11, lsl #1
    add     x11, x11, #13
2:  str     x11, [x19, #(G + 16)]
    cbz     w9, 9f
    cbz     w10, 9f
    cmp     w9, #16384
    b.hi    9f
    cmp     w10, #16384
    b.hi    9f
    cmp     x11, x21
    b.hi    9f
    mov     x0, #1
    ret
9:  mov     x0, #0
    ret
// skip_blocks: steps x22 over a run of sub-blocks (a length byte and that many bytes, ended by a zero length) -> x0 1, or 0 if
// the file runs out. Uses x9.
skip_blocks:
1:  cmp     x22, x21
    b.hs    2f
    ldrb    w9, [x20, x22]
    add     x22, x22, x9
    add     x22, x22, #1
    cbnz    w9, 1b
    cmp     x22, x21
    cset    x0, ls
    ret
2:  mov     x0, #0
    ret
// next_frame: reads the next frame's description at x22 into x23 and leaves x22 after its data -> x0 1, or 0 at the end of the
// file or where it cannot be followed. Uses x9-x12, x17.
next_frame:
    mov     x17, x30
    str     wzr, [x23, #DELAY]
    str     wzr, [x23, #DISP]
    mov     w9, #-1
    str     w9, [x23, #CLR]
n_loop:
    cmp     x22, x21
    b.hs    n_no
    ldrb    w9, [x20, x22]
    add     x22, x22, #1
    cmp     w9, #0x21
    b.ne    n_image
    cmp     x22, x21
    b.hs    n_no
    ldrb    w9, [x20, x22]
    add     x22, x22, #1
    cmp     w9, #0xf9                   // how the next frame is shown
    b.ne    1f
    add     x10, x22, #5
    cmp     x10, x21
    b.hs    1f
    add     x10, x20, x22
    ldrb    w9, [x10]
    cmp     w9, #4
    b.ne    1f
    ldrb    w9, [x10, #1]
    ubfx    w11, w9, #2, #3
    str     w11, [x23, #DISP]
    ldrb    w11, [x10, #2]
    ldrb    w12, [x10, #3]
    orr     w11, w11, w12, lsl #8
    str     w11, [x23, #DELAY]
    ldrb    w11, [x10, #4]
    mov     w12, #-1
    tst     w9, #1
    csel    w11, w11, w12, ne
    str     w11, [x23, #CLR]
1:  bl      skip_blocks
    cbz     x0, n_no
    b       n_loop
n_image:
    cmp     w9, #0x2c
    b.ne    n_no
    add     x10, x22, #9
    cmp     x10, x21
    b.hi    n_no
    add     x10, x20, x22
    ldrh    w9, [x10]
    str     w9, [x23, #FX]
    ldrh    w9, [x10, #2]
    str     w9, [x23, #FY]
    ldrh    w9, [x10, #4]
    str     w9, [x23, #FW]
    ldrh    w9, [x10, #6]
    str     w9, [x23, #FH]
    ldrb    w9, [x10, #8]
    ubfx    w11, w9, #6, #1
    str     w11, [x23, #INTL]
    add     x22, x22, #9
    ldr     x11, [x19, #(G + 32)]
    str     x11, [x23, #T]
    ldr     w11, [x19, #(G + 40)]
    str     w11, [x23, #TN]
    tbz     w9, #7, 2f
    str     x22, [x23, #T]              // colours of its own
    and     w9, w9, #7
    mov     w11, #2
    lsl     w11, w11, w9
    str     w11, [x23, #TN]
    add     x11, x11, x11, lsl #1
    add     x22, x22, x11
2:  cmp     x22, x21
    b.hs    n_no
    str     x22, [x23, #DATA]
    add     x22, x22, #1
    bl      skip_blocks
    ret     x17
n_no:
    mov     x0, #0
    ret     x17

    .macro  ENTER
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, sp
    mov     x27, x0
    mov     x24, x1
    mov     x25, x2
    mov     x26, x4
    add     x23, x19, #F
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
// BLOCK: the block at the handle in number \i (numbers x24, count x25, table x26) -> x0, or 0
    .macro  BLOCK i
    mov     x0, #0
    cmp     x25, #\i
    b.le    60f
    ldrsh   x9, [x24, #(\i * 2)]
    cmp     x9, #0
    b.lt    60f
    cmp     x9, #255
    b.gt    60f
    add     x9, x9, #256
    ldr     x0, [x26, x9, lsl #3]
60:
    .endm
size:
    ENTER
    BLOCK   0
    bl      open_gif
    cbz     x0, 1f
    ldp     w9, w10, [x19, #(G + 24)]
    add     x0, x10, x9, lsl #16
    b       2f
1:  mov     x0, #-1
2:  LEAVE
frames:
    ENTER
    BLOCK   0
    bl      open_gif
    cbz     x0, 2f
    ldr     x22, [x19, #(G + 16)]
    mov     x28, #0
1:  bl      next_frame
    cbz     x0, 3f
    add     x28, x28, #1
    b       1b
3:  mov     x0, x28
    b       4f
2:  mov     x0, #-1
4:  LEAVE
delay:
    ENTER
    BLOCK   0
    bl      open_gif
    cbz     x0, 2f
    mov     x28, #0
    cmp     x25, #1
    b.le    1f
    ldrsh   x28, [x24, #2]
    tbnz    x28, #63, 2f
1:  ldr     x22, [x19, #(G + 16)]
    mov     x24, #0
3:  bl      next_frame
    cbz     x0, 2f
    cmp     x24, x28
    b.eq    4f
    add     x24, x24, #1
    b       3b
4:  ldr     w0, [x23, #DELAY]
    b       5f
2:  mov     x0, #-1
5:  LEAVE

// unpack: one frame's LZW data into x1 colour numbers at x0; x2 the prefixes (16-bit), x3 the suffixes, x4 the stack -> x0 1 or 0
unpack:
    stp     x23, x24, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    ldr     x5, [x19, #(F + DATA)]
    ldrb    w6, [x20, x5]               // the smallest code width
    add     x5, x5, #1
    sub     w9, w6, #1
    cmp     w9, #10
    b.hi    u_no
    mov     w7, #1
    lsl     w7, w7, w6                  // the code that clears the dictionary
    add     w8, w7, #1                  // the code that ends the data
    add     w9, w6, #1                  // the width of a code now
    add     w10, w7, #2                 // the next code to be made
    mov     w11, #0                     // bits waiting
    mov     w12, #0                     // bytes left in this sub-block
    mov     w13, #0                     // how many bits are waiting
    mov     w14, #-1                    // the code before
    mov     w15, #0                     // the first colour of the string before
    mov     x16, #0                     // colours made
    mov     w17, #0
    mov     w23, #0xffff
1:  cmp     w17, w7
    b.hs    u_loop
    strh    w23, [x2, x17, lsl #1]
    strb    w17, [x3, x17]
    add     w17, w17, #1
    b       1b
u_loop:
    cmp     x16, x1
    b.hs    u_yes
u_fill:
    cmp     w13, w9
    b.ge    2f
    cbnz    w12, 1f
    cmp     x5, x21
    b.hs    u_no
    ldrb    w12, [x20, x5]
    add     x5, x5, #1
    cbz     w12, u_no
1:  cmp     x5, x21
    b.hs    u_no
    ldrb    w23, [x20, x5]
    add     x5, x5, #1
    lsl     w23, w23, w13
    orr     w11, w11, w23
    add     w13, w13, #8
    sub     w12, w12, #1
    b       u_fill
2:  mov     w23, #1
    lsl     w23, w23, w9
    sub     w23, w23, #1
    and     w28, w11, w23               // the code
    lsr     w11, w11, w9
    sub     w13, w13, w9
    cmp     w28, w7
    b.ne    3f
    add     w9, w6, #1
    add     w10, w7, #2
    mov     w14, #-1
    b       u_loop
3:  cmp     w28, w8
    b.eq    u_no
    mov     w17, w28                    // walking back through the dictionary, colours onto the stack
    mov     w27, #0
    tbz     w14, #31, 4f
    cmp     w28, w7
    b.hs    u_no
    b       5f
4:  cmp     w28, w10
    b.lo    5f
    b.ne    u_no
    cmp     w10, #4096
    b.hs    u_no
    strb    w15, [x4, x27]
    add     w27, w27, #1
    mov     w17, w14
5:  cmp     w17, w7
    b.lo    6f
    cmp     w17, #4096
    b.hs    u_no
    cmp     w27, #4096
    b.hs    u_no
    ldrb    w23, [x3, x17]
    strb    w23, [x4, x27]
    add     w27, w27, #1
    ldrh    w17, [x2, x17, lsl #1]
    b       5b
6:  mov     w15, w17
    strb    w17, [x4, x27]
    add     w27, w27, #1
7:  cbz     w27, 8f
    cmp     x16, x1
    b.hs    8f
    sub     w27, w27, #1
    ldrb    w23, [x4, x27]
    strb    w23, [x0, x16]
    add     x16, x16, #1
    b       7b
8:  tbnz    w14, #31, 9f
    cmp     w10, #4096
    b.hs    9f
    strh    w14, [x2, x10, lsl #1]
    strb    w15, [x3, x10]
    add     w10, w10, #1
    mov     w23, #1
    lsl     w23, w23, w9
    cmp     w10, w23
    b.ne    9f
    cmp     w9, #12
    b.hs    9f
    add     w9, w9, #1
9:  mov     w14, w28
    b       u_loop
u_yes:
    mov     x0, #1
    b       u_out
u_no:
    mov     x0, #0
u_out:
    ldp     x27, x28, [sp, #16]
    ldp     x23, x24, [sp], #32
    ret

// region: over the rectangle w0, w1 (left, top), w2, w3 (width, height), kept to the part of the picture on the surface:
// x4 = 0 clears the dots, 1 puts back the saved ones, 2 saves them. Uses x5-x16.
region:
    ldp     w5, w6, [x19, #CW]
    add     w3, w1, w3                  // one past the last row
    lsl     w7, w5, #2
    add     w8, w0, w2
    lsl     w8, w8, #2
    cmp     w8, w7
    csel    w8, w7, w8, hi              // one past the last byte of a row
    lsl     w0, w0, #2
    ldr     w9, [x27, #12]
    ldr     w10, [x19, #(G + 24)]
    ldr     x11, [x19, #SAVED]
1:  cmp     w1, w3
    b.hs    9f
    cmp     w1, w6
    b.hs    9f
    umull   x12, w1, w9
    add     x12, x12, x27
    add     x12, x12, #64               // the surface's row
    umull   x13, w1, w10
    add     x13, x11, x13, lsl #2       // the saved row
    mov     w14, w0
2:  cmp     w14, w8
    b.hs    5f
    cbnz    x4, 3f
    strb    wzr, [x12, x14]
    b       4f
3:  cmp     x4, #1
    b.ne    6f
    ldrb    w15, [x13, x14]
    strb    w15, [x12, x14]
    b       4f
6:  ldrb    w15, [x12, x14]
    strb    w15, [x13, x14]
4:  add     w14, w14, #1
    b       2b
5:  add     w1, w1, #1
    b       1b
9:  ret

decode:
    ENTER
    BLOCK   0
    bl      open_gif
    cbz     x0, d_bad
    BLOCK   1
    cbz     x0, d_bad
    ldr     w9, [x0]
    cmp     w9, #5
    b.ne    d_bad
    mov     x9, #0
    cmp     x25, #2
    b.le    1f
    ldrsh   x9, [x24, #4]
    tbnz    x9, #63, d_bad
1:  mov     x25, x9                     // the frame wanted
    mov     x26, x0
    ldp     w9, w10, [x19, #(G + 24)]
    umull   x28, w9, w10                // the picture's area
    add     x11, x28, x28, lsl #2
    mov     x12, #(64 + 20480)
    add     x11, x11, x12
    ldr     x12, [x26, #16]
    cmp     x12, x11
    b.lo    d_bad
    mov     x11, #(64 + 20480)
    add     x11, x26, x11
    str     x11, [x19, #INDEX]
    add     x11, x11, x28
    str     x11, [x19, #SAVED]
    ldp     w11, w12, [x27, #4]
    cmp     w9, w11
    csel    w9, w9, w11, lo
    cmp     w10, w12
    csel    w10, w10, w12, lo
    stp     w9, w10, [x19, #CW]
    str     wzr, [x19, #HAD]
    mov     w0, #0                      // the picture's part of the surface starts clear
    mov     w1, #0
    mov     w2, w9
    mov     w3, w10
    mov     x4, #0
    bl      region
    ldr     x22, [x19, #(G + 16)]
    mov     x24, #0
d_frame:
    cmp     x24, x25
    b.gt    d_done
    bl      next_frame
    cbz     x0, d_bad
    ldp     w9, w10, [x19, #(G + 24)]   // the frame's rectangle, kept inside the picture
    ldp     w11, w12, [x23, #FX]
    cmp     w11, w9
    csel    w11, w9, w11, hi
    cmp     w12, w10
    csel    w12, w10, w12, hi
    stp     w11, w12, [x23, #FX]
    ldp     w13, w14, [x23, #FW]
    add     w15, w11, w13
    sub     w16, w9, w11
    cmp     w15, w9
    csel    w13, w16, w13, hi
    add     w15, w12, w14
    sub     w16, w10, w12
    cmp     w15, w10
    csel    w14, w16, w14, hi
    stp     w13, w14, [x19, #KW]
    ldr     w9, [x19, #HAD]             // what becomes of the frame before
    cbz     w9, 2f
    ldr     w9, [x19, #(BF + DISP)]
    mov     x4, #0
    cmp     w9, #2
    b.eq    1f
    mov     x4, #1
    cmp     w9, #3
    b.ne    2f
1:  ldp     w0, w1, [x19, #(BF + FX)]
    ldp     w2, w3, [x19, #(BF + FW)]
    bl      region
2:  ldr     w9, [x23, #DISP]
    cmp     w9, #3
    b.ne    3f
    ldp     w0, w1, [x23, #FX]          // this frame will be undone: keep what is under it
    ldp     w2, w3, [x19, #KW]
    mov     x4, #2
    bl      region
3:  ldp     w9, w10, [x23, #FW]
    cbz     w9, d_drawn
    cbz     w10, d_drawn
    umull   x1, w9, w10
    cmp     x1, x28
    b.hi    d_bad
    ldr     x0, [x19, #INDEX]
    add     x2, x26, #64
    add     x3, x2, #8192
    add     x4, x2, #12288
    bl      unpack
    cbz     x0, d_bad
    mov     w8, #0                      // which unpacked row comes next
    mov     w5, #0                      // the pass
d_pass:
    ldr     w9, [x23, #INTL]
    mov     w6, #0
    mov     w7, #1
    cbz     w9, 4f
    adr     x10, d_first
    ldrb    w6, [x10, x5]
    adr     x10, d_apart
    ldrb    w7, [x10, x5]
4:  ldr     w9, [x23, #FH]
    cmp     w6, w9
    b.hs    d_pass_done
    ldr     w9, [x19, #KH]
    cmp     w6, w9
    b.hs    d_row_next
    ldr     w9, [x23, #FY]
    add     w9, w9, w6
    ldr     w10, [x19, #CH]
    cmp     w9, w10
    b.hs    d_row_next
    ldr     w10, [x27, #12]
    umull   x15, w9, w10
    add     x15, x15, x27
    add     x15, x15, #64
    ldr     w10, [x23, #FX]
    add     x15, x15, x10, lsl #2       // where this row starts on the surface
    ldr     w11, [x19, #CW]
    subs    w11, w11, w10
    csel    w11, wzr, w11, lo
    ldr     w12, [x19, #KW]
    cmp     w11, w12
    csel    w11, w12, w11, hi           // how many dots of it
    ldr     w9, [x23, #FW]
    umull   x9, w8, w9
    ldr     x10, [x19, #INDEX]
    add     x9, x10, x9                 // its colour numbers
    ldr     w12, [x23, #CLR]
    ldr     w13, [x23, #TN]
    ldr     x14, [x23, #T]
    mov     w10, #0
5:  cmp     w10, w11
    b.hs    d_row_next
    ldrb    w16, [x9, x10]
    cmp     w16, w12
    b.eq    6f
    cmp     w16, w13
    b.hs    d_bad
    add     x17, x16, x16, lsl #1
    add     x17, x17, x14
    add     x0, x17, #3
    cmp     x0, x21
    b.hi    d_bad
    add     x17, x20, x17
    add     x0, x15, x10, lsl #2
    ldrb    w1, [x17]
    strb    w1, [x0]
    ldrb    w1, [x17, #1]
    strb    w1, [x0, #1]
    ldrb    w1, [x17, #2]
    strb    w1, [x0, #2]
    mov     w1, #255
    strb    w1, [x0, #3]
6:  add     w10, w10, #1
    b       5b
d_row_next:
    add     w6, w6, w7
    add     w8, w8, #1
    b       4b
d_pass_done:
    add     w5, w5, #1
    ldr     w9, [x23, #INTL]
    cbz     w9, d_drawn
    cmp     w5, #4
    b.lo    d_pass
d_drawn:
    mov     x9, #0                      // this frame becomes the frame before
7:  ldr     x10, [x23, x9, lsl #3]
    add     x11, x19, #BF
    str     x10, [x11, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #7
    b.lo    7b
    ldp     w9, w10, [x19, #KW]
    stp     w9, w10, [x19, #(BF + FW)]
    mov     w9, #1
    str     w9, [x19, #HAD]
    add     x24, x24, #1
    b       d_frame
d_done:
    ldp     w9, w10, [x19, #CW]
    umull   x0, w9, w10
    b       d_out
d_bad:
    mov     x0, #-1
d_out:
    LEAVE
    .ltorg
d_first:
    .byte   0, 4, 2, 1
d_apart:
    .byte   8, 8, 4, 2
