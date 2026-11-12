// Text. A string in the heap is one word, then its units: the word's low 32 bits say how many units, bit 32 whether they
// are wide. A unit is one of the language's 16-bit code units. Text with no unit past 255 keeps one byte a unit; any other
// keeps two (wide), and a string is wide only if it needs to be: so two strings with the same text are the same bytes.
// u_next: the UTF-8 character at x11 (text ends at x12) -> w13, x11 moved past it. A byte that does not fit the encoding
// stands for itself. Uses x13-x17.
u_next:
    ldrb    w13, [x11], #1
    cmp     w13, #0xc0
    b.lo    9f
    sub     x14, x12, x11
    cmp     w13, #0xe0
    b.hs    2f
    cmp     x14, #1
    b.lt    9f
    ldrb    w15, [x11]
    and     w16, w15, #0xc0
    cmp     w16, #0x80
    b.ne    9f
    add     x11, x11, #1
    and     w13, w13, #0x1f
    and     w15, w15, #0x3f
    orr     w13, w15, w13, lsl #6
    ret
2:  cmp     w13, #0xf0
    b.hs    4f
    cmp     x14, #2
    b.lt    9f
    ldrb    w15, [x11]
    ldrb    w16, [x11, #1]
    and     w17, w15, #0xc0
    cmp     w17, #0x80
    b.ne    9f
    and     w17, w16, #0xc0
    cmp     w17, #0x80
    b.ne    9f
    add     x11, x11, #2
    and     w13, w13, #0xf
    and     w15, w15, #0x3f
    and     w16, w16, #0x3f
    orr     w13, w15, w13, lsl #6
    orr     w13, w16, w13, lsl #6
    ret
4:  cmp     w13, #0xf8
    b.hs    9f
    cmp     x14, #3
    b.lt    9f
    ldrb    w15, [x11]
    and     w17, w15, #0xc0
    cmp     w17, #0x80
    b.ne    9f
    ldrb    w16, [x11, #1]
    ldrb    w17, [x11, #2]
    add     x11, x11, #3
    and     w13, w13, #7
    and     w15, w15, #0x3f
    and     w16, w16, #0x3f
    and     w17, w17, #0x3f
    orr     w13, w15, w13, lsl #6
    orr     w13, w16, w13, lsl #6
    orr     w13, w17, w13, lsl #6
9:  ret
// w_text: a string value for the x1 bytes of UTF-8 at x0 -> x0, or 0 if the world is full. A character past 0xffff becomes
// its pair of units. Uses x0-x17.
w_text:
    stp     x29, x30, [sp, #-48]!
    stp     x0, x1, [sp, #16]
    mov     x11, x0
    add     x12, x0, x1
    mov     x2, #0
    mov     w3, #0
1:  cmp     x11, x12
    b.hs    2f
    bl      u_next
    cmp     w13, #0x10000
    b.lo    11f
    add     x2, x2, #1
    mov     w13, #0xd800
11: add     x2, x2, #1
    cmp     w13, w3
    csel    w3, w13, w3, hi
    b       1b
2:  cmp     w3, #255
    cset    x4, hi
    stp     x2, x4, [sp, #32]
    lsl     x0, x2, x4
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, 9f
    ldp     x2, x4, [sp, #32]
    add     x5, x19, x0
    orr     x6, x2, x4, lsl #32
    str     x6, [x5], #8
    ldp     x11, x1, [sp, #16]
    add     x12, x11, x1
3:  cmp     x11, x12
    b.hs    8f
    bl      u_next
    cbnz    x4, 31f
    strb    w13, [x5], #1
    b       3b
31: cmp     w13, #0x10000
    b.lo    4f
    sub     w13, w13, #0x10000
    lsr     w6, w13, #10
    mov     w7, #0xd800
    add     w6, w6, w7
    strh    w6, [x5], #2
    and     w13, w13, #0x3ff
    mov     w7, #0xdc00
    add     w13, w13, w7
4:  strh    w13, [x5], #2
    b       3b
8:  orr     x0, x0, #(T_STRING << 48)
9:  ldp     x29, x30, [sp], #48
    ret
// w_unit: a string value of the one unit w0 -> x0, or 0 if the world is full. Uses x9-x13.
w_unit:
    mov     x13, x30
    mov     w12, w0
    mov     x0, #10
    bl      w_alloc
    cbz     x0, 9f
    add     x9, x19, x0
    cmp     w12, #255
    cset    x10, hi
    lsl     x10, x10, #32
    orr     x10, x10, #1
    str     x10, [x9]
    strh    w12, [x9, #8]
    orr     x0, x0, #(T_STRING << 48)
9:  ret     x13
// s_copy: x13 units from x10 (wide if x12) to x8 (wide if x6); x8 is left after them. Uses x10, x13, x14.
s_copy:
1:  cbz     x13, 9f
    cbz     x12, 2f
    ldrh    w14, [x10], #2
    b       3f
2:  ldrb    w14, [x10], #1
3:  cbz     x6, 4f
    strh    w14, [x8], #2
    b       5f
4:  strb    w14, [x8], #1
5:  sub     x13, x13, #1
    b       1b
9:  ret
// w_outs: the string value x0 joins what the program has printed, as UTF-8 (a pair of units is one character; half a pair
// alone is printed as the replacement character; what does not fit is dropped). Uses x0-x12.
w_outs:
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x1, [x0], #8
    lsr     x2, x1, #32
    and     x1, x1, #0xffffffff
    ldp     x9, x10, [x19, #W_OUT]
    ldr     x11, [x19, #W_OUT_CAP]
    add     x9, x19, x9
    mov     x3, #0
1:  cmp     x3, x1
    b.hs    8f
    cbz     x2, 2f
    ldrh    w4, [x0, x3, lsl #1]
    b       3f
2:  ldrb    w4, [x0, x3]
3:  add     x3, x3, #1
    lsr     w5, w4, #10
    cmp     w5, #0x36
    b.ne    4f
    cmp     x3, x1
    b.hs    35f
    ldrh    w6, [x0, x3, lsl #1]
    lsr     w7, w6, #10
    cmp     w7, #0x37
    b.ne    35f
    add     x3, x3, #1
    and     w4, w4, #0x3ff
    and     w6, w6, #0x3ff
    orr     w4, w6, w4, lsl #10
    add     w4, w4, #0x10000
    b       5f
35: mov     w4, #0xfffd
    b       5f
4:  cmp     w5, #0x37
    b.ne    5f
    mov     w4, #0xfffd
5:  add     x12, x10, #4
    cmp     x12, x11
    b.hi    8f
    add     x12, x9, x10
    cmp     w4, #0x80
    b.hs    6f
    strb    w4, [x12]
    add     x10, x10, #1
    b       1b
6:  cmp     w4, #0x800
    b.hs    7f
    lsr     w5, w4, #6
    orr     w5, w5, #0xc0
    strb    w5, [x12]
    and     w5, w4, #0x3f
    orr     w5, w5, #0x80
    strb    w5, [x12, #1]
    add     x10, x10, #2
    b       1b
7:  cmp     w4, #0x10000
    b.hs    71f
    lsr     w5, w4, #12
    orr     w5, w5, #0xe0
    strb    w5, [x12]
    ubfx    w5, w4, #6, #6
    orr     w5, w5, #0x80
    strb    w5, [x12, #1]
    and     w5, w4, #0x3f
    orr     w5, w5, #0x80
    strb    w5, [x12, #2]
    add     x10, x10, #3
    b       1b
71: lsr     w5, w4, #18
    orr     w5, w5, #0xf0
    strb    w5, [x12]
    ubfx    w5, w4, #12, #6
    orr     w5, w5, #0x80
    strb    w5, [x12, #1]
    ubfx    w5, w4, #6, #6
    orr     w5, w5, #0x80
    strb    w5, [x12, #2]
    and     w5, w4, #0x3f
    orr     w5, w5, #0x80
    strb    w5, [x12, #3]
    add     x10, x10, #4
    b       1b
8:  str     x10, [x19, #W_OUT_LEN]
    ret
