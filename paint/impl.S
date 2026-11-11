// Paint, written directly for ARM64 by the agent. Position independent; calls nothing.
// Surface header: +0 version, +4 width, +8 height, +12 bytes per row, +16 size; pixels from +64.
    .text
    .global check
check:                          // x0 = surface
    ldr w1,[x0]
    cmp w1,#1
    b.ne 9f
    ldr w1,[x0,#4]              // width
    ldr w2,[x0,#8]              // height
    ldr w3,[x0,#12]             // bytes per row
    ldr x4,[x0,#16]             // size
    cbz w1,9f
    cbz w2,9f
    mov w5,#16384
    cmp w1,w5
    b.hi 9f
    cmp w2,w5
    b.hi 9f
    cmp w3,w1,lsl #2
    b.ne 9f
    umull x6,w3,w2
    add x6,x6,#64
    cmp x6,x4
    b.ne 9f
    mov x0,#1
    ret
9:  mov x0,#0
    ret

    .global clear
clear:                          // x0 = surface, x3 = colour
    ldr w1,[x0,#4]
    ldr w2,[x0,#8]
    umull x4,w1,w2              // pixels
    add x5,x0,#64
    mov x6,x4
    dup v0.4s,w3
    cmp x6,#4
    b.lo 2f
1:  str q0,[x5],#16             // four pixels at a time
    sub x6,x6,#4
    cmp x6,#4
    b.hs 1b
2:  cbz x6,4f
3:  str w3,[x5],#4
    subs x6,x6,#1
    b.ne 3b
4:  mov x0,x4
    ret

    .global fill_rect
fill_rect:                      // x0 = surface, x1 = numbers, x2 = how many, x3 = colour
    mov w5,#0                   // x
    mov w6,#0                   // y
    mov w7,#0                   // w
    mov w8,#0                   // h
    cmp x2,#1
    b.lt 1f
    ldrsh w5,[x1]
    cmp x2,#2
    b.lt 1f
    ldrsh w6,[x1,#2]
    cmp x2,#3
    b.lt 1f
    ldrsh w7,[x1,#4]
    cmp x2,#4
    b.lt 1f
    ldrsh w8,[x1,#6]
1:  ldr w9,[x0,#4]              // width
    ldr w10,[x0,#8]             // height
    ldr w11,[x0,#12]            // bytes per row
    add w7,w5,w7                // right edge
    add w8,w6,w8                // bottom edge
    cmp w5,#0
    csel w5,w5,wzr,gt           // clip left and top to 0
    cmp w6,#0
    csel w6,w6,wzr,gt
    cmp w7,w9
    csel w7,w7,w9,lt            // clip right and bottom to the surface
    cmp w8,w10
    csel w8,w8,w10,lt
    subs w12,w7,w5              // columns to paint
    b.le 9f
    subs w13,w8,w6              // rows to paint
    b.le 9f
    umull x14,w6,w11            // top row offset
    add x14,x14,x5,lsl #2
    add x14,x14,#64
    add x14,x0,x14              // first pixel
    dup v0.4s,w3
    mov w15,w13
2:  mov x16,x14
    mov w17,w12
    cmp w17,#4
    b.lo 4f
3:  str q0,[x16],#16
    sub w17,w17,#4
    cmp w17,#4
    b.hs 3b
4:  cbz w17,6f
5:  str w3,[x16],#4
    subs w17,w17,#1
    b.ne 5b
6:  add x14,x14,x11             // next row
    subs w15,w15,#1
    b.ne 2b
    umull x0,w12,w13
    ret
9:  mov x0,#0
    ret
