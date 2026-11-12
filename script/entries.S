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
