// The entries. x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
    .macro  ENTER
    stp     x29, x30, [sp, #-112]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    stp     d8, d9, [sp, #96]
    mov     x19, x0
    .endm
    .macro  LEAVE
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     d8, d9, [sp, #96]
    ldp     x29, x30, [sp], #112
    ret
    .endm
// begin: makes the block a fresh world -> 1, or -1
begin:
    ENTER
    bl      w_begin
    LEAVE
// numtext: for the test bench: the number whose 64 bits are the argument, as text, joined to the world's printed text with a
// line end (the block becomes a fresh world first if it is not one yet) -> the text's length, or -1
numtext:
    ENTER
    mov     x20, x3
    ldr     w9, [x19, #W_MAGIC]
    ldr     w10, =0x534a5254
    cmp     w9, w10
    b.eq    1f
    bl      w_begin
    tbnz    x0, #63, 9f
1:  fmov    d0, x20
    bl      num_text
    cbz     x0, 8f
    STRV    x0, x0, x1
    mov     x20, x1
    bl      w_out
    adr     x0, e_newline
    mov     x1, #1
    bl      w_out
    mov     x0, x20
    b       9f
8:  mov     x0, #-1
9:  LEAVE
e_newline: .byte 10
    .balign 4
// e_handle: the block for the handle in the first number -> x9, or 0. Uses x10.
e_handle:
    mov     x9, #0
    cmp     x2, #1
    b.lt    1f
    ldrsh   x10, [x1]
    cmp     x10, #0
    b.lt    1f
    cmp     x10, #255
    b.gt    1f
    add     x10, x10, #256
    ldr     x9, [x4, x10, lsl #3]
1:  ret
// e_world: the same, and it must be a world that has begun -> x9, or 0
e_world:
    mov     x15, x30
    bl      e_handle
    cbz     x9, 1f
    ldr     w10, [x9]
    cmp     w10, #6
    b.ne    2f
    ldr     w10, [x9, #W_MAGIC]
    ldr     w11, =0x534a5254
    cmp     w10, w11
    b.eq    1f
2:  mov     x9, #0
1:  ret     x15
// load: the text at the handle in the first number is copied into the world and translated -> 1, or -1 (see error)
load:
    ENTER
    ldr     w9, [x19, #W_MAGIC]
    ldr     w10, =0x534a5254
    cmp     w9, w10
    b.ne    8f
    bl      e_handle
    cbz     x9, 8f
    cmp     x9, x19
    b.eq    8f
    ldr     w10, [x9]
    cmp     w10, #2
    b.ne    8f
    ldr     x21, [x9, #16]
    cmp     x21, #64
    b.lo    8f
    sub     x21, x21, #64
    add     x20, x9, #64
    mov     x0, x21
    bl      w_alloc
    cbz     x0, 8f
    stp     x0, x21, [x19, #W_SRC]
    add     x9, x19, x0
    mov     x10, #0
1:  cmp     x10, x21
    b.hs    2f
    ldrb    w11, [x20, x10]
    strb    w11, [x9, x10]
    add     x10, x10, #1
    b       1b
2:  mov     x20, x9
    bl      c_compile
    b       9f
8:  mov     x0, #-1
9:  LEAVE
// run: runs the loaded program for at most the argument's steps -> 0 finished, 1 out of steps (call again), -1 it went wrong
run:
    ENTER
    mov     x25, x3
    ldr     w9, [x19, #W_MAGIC]
    ldr     w10, =0x534a5254
    cmp     w9, w10
    b.ne    8f
    ldr     w9, [x19, #W_STATE]
    mov     x0, #0
    cmp     w9, #2
    b.eq    9f
    cmp     w9, #1
    b.ne    8f
    bl      m_run
    b       9f
8:  mov     x0, #-1
9:  LEAVE
// text: what the program at the handle has printed since last asked, into this block from byte 64 -> how many bytes, or -1
text:
    ENTER
    bl      e_world
    cbz     x9, 8f
    ldr     x10, [x19, #16]
    subs    x10, x10, #64
    b.lo    8f
    ldp     x11, x12, [x9, #W_OUT]
    cmp     x12, x10
    csel    x12, x10, x12, hi
    add     x11, x9, x11
    add     x13, x19, #64
    mov     x14, #0
1:  cmp     x14, x12
    b.hs    2f
    ldrb    w15, [x11, x14]
    strb    w15, [x13, x14]
    add     x14, x14, #1
    b       1b
2:  str     xzr, [x9, #W_OUT_LEN]
    mov     x0, x12
    b       9f
8:  mov     x0, #-1
9:  LEAVE
// clock: the host gives the time: the argument's low 48 bits are the milliseconds since 1970, its top 16 the minutes local
// time is ahead of universal time (signed) -> 1, or -1 if the block is not a world
clock:
    ENTER
    ldr     w9, [x19, #W_MAGIC]
    ldr     w10, =0x534a5254
    cmp     w9, w10
    b.ne    8f
    cbnz    x3, 1f                      // argument 0 asks instead: when is the program's next timer due (milliseconds since
    ldr     d0, [x19, #W_WAKE]          //   1970) -> that, or -1 if it has none. The host then gives the time
    fcvtzs  x0, d0                      //   and calls run: a finished program runs what is due.                 
    cmp     x0, #0                      //   (A piece has room for eight entries, so this shares one.)
    csinv   x0, x0, xzr, gt
    b       9f
1:  and     x9, x3, #0xffffffffffff
    ucvtf   d0, x9
    str     d0, [x19, #W_CLOCK]
    asr     x9, x3, #48
    mov     w10, #1
    str     w9, [x19, #W_TZ]
    str     w10, [x19, #(W_TZ + 4)]
    ldr     w9, [x19, #W_STATE]         // a program that has finished is set at its ending again: the next `run` runs
    cmp     w9, #2                      //   whatever timers are due by the new time
    b.ne    2f
    ldr     x9, [x19, #W_JOBS_PC]
    str     x9, [x19, #W_PC]
    str     w10, [x19, #W_STATE]
2:
    mov     x0, #1
    b       9f
8:  mov     x0, #-1
9:  LEAVE
// error: the last error of the world at the handle, as "message (line L, column C)", into this block from byte 64
// -> how many bytes (0 if there is none), or -1
error:
    ENTER
    bl      e_world
    cbz     x9, 8f
    ldr     x0, [x9, #W_ERR]
    lsr     x10, x0, #48
    mov     w11, #T_STRING
    cmp     w10, w11
    mov     x12, #0
    b.ne    7f
    and     x0, x0, #0xffffffffffff
    add     x11, x9, x0
    ldr     x12, [x11], #8
    ldr     x10, [x19, #16]
    add     x13, x12, #64 + 48
    cmp     x13, x10
    b.hi    8f
    add     x13, x19, #64
1:  cbz     x12, 2f
    ldrb    w14, [x11], #1
    strb    w14, [x13], #1
    sub     x12, x12, #1
    b       1b
2:  adr     x0, e_line
    mov     x1, #(e_column - e_line)
    bl      e_put
    ldr     w0, [x9, #W_ERR_LINE]
    bl      e_dec
    adr     x0, e_column
    mov     x1, #(e_close - e_column)
    bl      e_put
    ldr     w0, [x9, #W_ERR_COL]
    bl      e_dec
    mov     w14, #')'
    strb    w14, [x13], #1
    add     x12, x19, #64
    sub     x12, x13, x12
7:  mov     x0, x12
    b       9f
8:  mov     x0, #-1
9:  LEAVE
e_put:                                  // the x1 bytes at x0 go to x13
1:  cbz     x1, 2f
    ldrb    w14, [x0], #1
    strb    w14, [x13], #1
    sub     x1, x1, #1
    b       1b
2:  ret
e_dec:                                  // the whole number w0 in decimal goes to x13. Uses x14-x17, x1.
    mov     w14, #10
    mov     x15, #0
    mov     x16, #0
1:  udiv    w17, w0, w14
    msub    w1, w17, w14, w0
    add     w1, w1, #'0'
    orr     x15, x1, x15, lsl #8
    add     x16, x16, #1
    mov     w0, w17
    cbz     w0, 2f
    cmp     x16, #8
    b.lo    1b
2:  strb    w15, [x13], #1
    lsr     x15, x15, #8
    subs    x16, x16, #1
    b.ne    2b
    ret
e_line:   .ascii " (line "
e_column: .ascii ", column "
e_close:
    .balign 4
    .ltorg
