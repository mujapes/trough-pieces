// tokens: for the test bench: every word of the text at the handle in the first number, as records in the block from byte 64:
// kind (1 byte), line end before (1), id (2), start (4), length (4), 4 unused, the number's value (8). -> how many bytes, or -1.
tokens:
    stp     x29, x30, [sp, #-112]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    str     d8, [sp, #96]
    mov     x19, x0
    cmp     x2, #1
    b.lt    t_bad
    ldrsh   x9, [x1]
    cmp     x9, #0
    b.lt    t_bad
    cmp     x9, #255
    b.gt    t_bad
    add     x9, x9, #256
    ldr     x9, [x4, x9, lsl #3]
    cbz     x9, t_bad
    ldr     w10, [x9]
    cmp     w10, #2
    b.ne    t_bad
    cmp     x9, x19
    b.eq    t_bad
    ldr     x21, [x9, #16]
    cmp     x21, #64
    b.lo    t_bad
    sub     x21, x21, #64
    add     x20, x9, #64
    mov     x22, #0
    mov     w28, #1
    ldr     x29, [x19, #16]
    add     x29, x19, x29               // the block's end
    add     x19, x19, #64
    mov     x30, x19                    // (kept: where the records began)
    str     x30, [sp, #104]
1:  bl      next_word
    add     x9, x19, #24
    cmp     x9, x29
    b.hi    t_bad
    strb    w23, [x19]
    strb    w27, [x19, #1]
    strh    w24, [x19, #2]
    str     w25, [x19, #4]
    str     w26, [x19, #8]
    str     wzr, [x19, #12]
    fmov    x9, d8
    cmp     w23, #K_NUMBER
    csel    x9, x9, xzr, eq
    str     x9, [x19, #16]
    add     x19, x19, #24
    cbnz    w23, 1b
    ldr     x30, [sp, #104]
    sub     x0, x19, x30
    b       t_out
t_bad:
    mov     x0, #-1
t_out:
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldr     d8, [sp, #96]
    ldp     x29, x30, [sp], #112
    ret
