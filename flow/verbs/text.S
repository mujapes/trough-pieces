// text, a boot verb for the Flow app, written by hand (ARM64) [by Opus]. boot(x0 ctx), ctx as in app/libflow.S.
// Shows /sdcard/Android/media/t.flow/text.txt (read again every 30 frames) in a font carried inside this verb (24x48,
// printable ASCII). A drag scrolls: the finger moves the scroll's target, the shown scroll glides after it.
    .equ C_PIX, 0
    .equ C_STRIDE, 8
    .equ C_H, 16
    .equ C_W, 24
    .equ C_STATE, 32
    .equ C_FRAME, 40
    .equ C_RING, 96
    .equ C_HEAD, 104
    .equ T_VAL, 0                       // state: scroll shown (f64)
    .equ T_TGT, 8                       //        scroll target (f64)
    .equ T_SEEN, 16                     //        events taken (u32)
    .equ T_LASTY, 24                    //        the finger's last row (f32)
    .equ T_LEN, 32                      //        text length
    .equ T_TEXT, 4096                   //        the text, at most 16384 bytes
    .equ GW, 24
    .equ GH, 48
    .equ LINE, 56
    .text
    .global text
text:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, x0
    ldr     x20, [x19, #C_STATE]
    // 1. the text, every 30 frames
    ldr     x9, [x19, #C_FRAME]
    mov     x10, #30
    udiv    x11, x9, x10
    msub    x11, x11, x10, x9
    cbnz    x11, 2f
    mov     x0, #-100
    adr     x1, tpath
    mov     x2, #0
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 2f
    mov     x21, x0
    add     x1, x20, #T_TEXT
    mov     x2, #16384
    mov     x8, #63
    svc     #0
    cmp     x0, #0
    csel    x0, xzr, x0, lt
    str     x0, [x20, #T_LEN]
    mov     x0, x21
    mov     x8, #57
    svc     #0
2:  // 2. touches since last frame
    ldr     w21, [x20, #T_SEEN]
    ldr     w22, [x19, #C_HEAD]
    ldr     x23, [x19, #C_RING]
3:  cmp     w21, w22
    b.eq    5f
    and     w9, w21, #255
    add     x9, x23, x9, lsl #4
    add     w21, w21, #1
    ldr     w10, [x9]
    cmp     w10, #1
    b.ne    3b
    ldr     w10, [x9, #4]
    and     w10, w10, #0xff
    ldr     s0, [x9, #12]
    cmp     w10, #2
    b.ne    4f
    ldr     s1, [x20, #T_LASTY]         // moved: the target moves by the finger's distance
    fsub    s1, s1, s0
    fcvt    d1, s1
    ldr     d2, [x20, #T_TGT]
    fadd    d2, d2, d1
    fmov    d3, xzr
    fmax    d2, d2, d3
    str     d2, [x20, #T_TGT]
4:  str     s0, [x20, #T_LASTY]
    b       3b
5:  str     w21, [x20, #T_SEEN]
    ldp     d0, d1, [x20, #T_VAL]       // 3. the glide: a third of the way each frame
    fsub    d2, d1, d0
    fmov    d3, #3.0
    fdiv    d2, d2, d3
    fadd    d0, d0, d2
    str     d0, [x20, #T_VAL]
    fcvtzs  x24, d0                     // scroll in rows
    // 4. clear
    ldr     x25, [x19, #C_PIX]
    ldr     x26, [x19, #C_STRIDE]
    ldr     x27, [x19, #C_H]
    ldr     x28, [x19, #C_W]
    mov     w9, #0x1810
    movk    w9, #0xff20, lsl #16
    mul     x10, x26, x27
    mov     x11, #0
6:  cmp     x11, x10
    b.hs    7f
    str     w9, [x25, x11, lsl #2]
    add     x11, x11, #1
    b       6b
7:  // 5. the text: x21 index, x22 length, x23 column, x9.. line
    mov     x21, #0
    ldr     x22, [x20, #T_LEN]
    mov     x23, #0
    mov     x6, #0                      // line
    sub     x7, x28, #48
    mov     x10, #GW
    udiv    x7, x7, x10                 // columns
    cbz     x7, 9f
8:  cmp     x21, x22
    b.hs    9f
    add     x10, x20, #T_TEXT
    ldrb    w0, [x10, x21]
    add     x21, x21, #1
    cmp     w0, #10
    b.ne    81f
    mov     x23, #0
    add     x6, x6, #1
    b       8b
81: cmp     x23, x7
    b.lo    82f
    mov     x23, #0
    add     x6, x6, #1
82: sub     w0, w0, #32
    cmp     w0, #94
    b.hi    84f                         // not printable: a space
    mov     x10, #LINE                  // the glyph's top row on screen
    mov     x11, #80
    madd    x11, x6, x10, x11
    sub     x11, x11, x24
    add     x12, x11, #GH
    cmp     x12, #0
    b.le    84f
    cmp     x11, x27
    b.ge    84f
    mov     x10, #GW                    // its left
    mov     x13, #24
    madd    x13, x23, x10, x13
    adr     x14, font                   // the glyph: 48 rows of 3 bytes
    mov     x10, #(GH * 3)
    madd    x14, x0, x10, x14
    mov     w15, #0xe8e0
    movk    w15, #0xfff0, lsl #16
    mov     x16, #0                     // row
83: cmp     x16, #GH
    b.hs    84f
    add     x17, x11, x16
    cmp     x17, #0
    b.lt    86f
    cmp     x17, x27
    b.ge    84f
    ldrb    w1, [x14]
    ldrb    w2, [x14, #1]
    ldrb    w3, [x14, #2]
    orr     w1, w1, w2, lsl #8
    orr     w1, w1, w3, lsl #16
    madd    x2, x17, x26, x13           // the row's first dot
    add     x2, x25, x2, lsl #2
    mov     x3, #0
85: cbz     w1, 86f
    tbz     w1, #0, 87f
    str     w15, [x2, x3, lsl #2]
87: lsr     w1, w1, #1
    add     x3, x3, #1
    b       85b
86: add     x14, x14, #3
    add     x16, x16, #1
    b       83b
84: add     x23, x23, #1
    b       8b
9:  ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #112
    ret
tpath: .asciz "/sdcard/Android/media/t.flow/text.txt"
    .balign 4
font: .incbin "font24x48.bin"
