// overlay verb: a bar across the top whose width follows Flow value 2 (x1 = field). x0 = screen surface (64-byte head: width at 32? see below)
    .text
    .global overlay
overlay:
    ldr     w9, [x0, #4]                // width
    ldr     w10, [x0, #8]               // height
    ldr     d0, [x1, #40]               // value 2
    fcvtzs  x11, d0
    cmp     x11, x9
    csel    x11, x9, x11, gt
    cmp     x11, #0
    csel    x11, xzr, x11, lt
    add     x12, x0, #64
    mov     w13, #0xffff
    movk    w13, #0xff80, lsl #16       // colour
    mov     x14, #0                     // rows 0..5
1:  mov     x15, #0
2:  cmp     x15, x11
    b.hs    3f
    madd    x16, x14, x9, x15
    str     w13, [x12, x16, lsl #2]
    add     x15, x15, #1
    b       2b
3:  add     x14, x14, #1
    cmp     x14, #6
    b.lo    1b
    mov     x0, #0
    ret
