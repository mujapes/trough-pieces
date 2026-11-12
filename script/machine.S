// The machine: runs the instructions the translator wrote. A stack machine: values go on a stack in the world; each instruction
// is one byte, some followed by a small number (low byte first). While it runs: x19 the world, x21 the next instruction,
// x22 the stack's top (the next free place), x23 the constants, x24 the globals, x25 steps left, x26 the stack's end.
    .equ OP_HALT, 0
    .equ OP_CONST, 1                    // + 16 bits: which constant
    .equ OP_UNDEF, 2
    .equ OP_NULL, 3
    .equ OP_TRUE, 4
    .equ OP_FALSE, 5
    .equ OP_GETG, 6                     // + 16 bits: which global
    .equ OP_SETG, 7                     // + 16 bits; the value stays on the stack
    .equ OP_POP, 8
    .equ OP_DUP, 9
    .equ OP_ADD, 10
    .equ OP_SUB, 11
    .equ OP_MUL, 12
    .equ OP_DIV, 13
    .equ OP_MOD, 14
    .equ OP_POW, 15
    .equ OP_NEG, 16
    .equ OP_PLUS, 17
    .equ OP_NOT, 18
    .equ OP_BITNOT, 19
    .equ OP_TYPEOF, 20
    .equ OP_LT, 21
    .equ OP_GT, 22
    .equ OP_LE, 23
    .equ OP_GE, 24
    .equ OP_EQ, 25
    .equ OP_NE, 26
    .equ OP_SEQ, 27
    .equ OP_SNE, 28
    .equ OP_BAND, 29
    .equ OP_BOR, 30
    .equ OP_BXOR, 31
    .equ OP_SHL, 32
    .equ OP_SHR, 33
    .equ OP_USHR, 34
    .equ OP_JMP, 35                     // + 32 bits: how far, from the instruction after
    .equ OP_JF, 36                      // takes the value; jumps if it counts as no
    .equ OP_JT, 37
    .equ OP_JFK, 38                     // jumps if no, keeping the value; otherwise takes it (for &&)
    .equ OP_JTK, 39                     // (for ||)
    .equ OP_JNK, 40                     // jumps keeping the value unless it is null or undefined, which it takes (for ??)
    .equ OP_PRINT, 41                   // + 8 bits: how many values to print as a line; leaves undefined
    .equ OP_VOID, 42
    .equ OP_COUNT, 43
// v_text: the value x0 as a string value -> x0 (0 if the world is full)
v_text:
    ISNUM   x0
    b.hs    1f
    fmov    d0, x0
    b       num_text
1:  mov     w16, #T_STRING
    cmp     w17, w16
    b.ne    2f
    ret
2:  stp     x29, x30, [sp, #-16]!
    mov     w16, #T_UNDEF
    cmp     w17, w16
    b.ne    3f
    LIT     s_undefined, s_null
    b       9f
3:  mov     w16, #T_NULL
    cmp     w17, w16
    b.ne    4f
    LIT     s_null, s_true
    b       9f
4:  mov     w16, #T_BOOL
    cmp     w17, w16
    b.ne    6f
    tbz     x0, #0, 5f
    LIT     s_true, s_false
    b       9f
5:  LIT     s_false, s_number
    b       9f
6:  LIT     s_objtext, s_end
9:  ldp     x29, x30, [sp], #16
    ret
s_undefined: .ascii "undefined"
s_null:      .ascii "null"
s_true:      .ascii "true"
s_false:     .ascii "false"
s_number:    .ascii "number"
s_string:    .ascii "string"
s_boolean:   .ascii "boolean"
s_object:    .ascii "object"
s_objtext:   .ascii "[object Object]"
s_end:
    .balign 4
// v_join: the two string values x0 and x1 as one string -> x0 (0 if the world is full)
v_join:
    stp     x29, x30, [sp, #-32]!
    stp     x0, x1, [sp, #16]
    STRV    x0, x2, x3
    STRV    x1, x4, x5
    add     x0, x3, x5
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, 9f
    ldp     x2, x4, [sp, #16]
    STRV    x2, x2, x3
    STRV    x4, x4, x5
    add     x6, x19, x0
    add     x7, x3, x5
    str     x7, [x6], #8
    cbz     x3, 2f
1:  ldrb    w7, [x2], #1
    strb    w7, [x6], #1
    subs    x3, x3, #1
    b.ne    1b
2:  cbz     x5, 4f
3:  ldrb    w7, [x4], #1
    strb    w7, [x6], #1
    subs    x5, x5, #1
    b.ne    3b
4:  orr     x0, x0, #(T_STRING << 48)
9:  ldp     x29, x30, [sp], #32
    ret
// v_int32: the number d0 as the language's 32-bit whole number (wrapping round) -> w0
v_int32:
    fabs    d1, d0
    ldr     x0, =0x43e0000000000000     // 2 to the 63: beyond it (and not-a-number) counts as 0 here
    fmov    d2, x0
    fcmp    d1, d2
    mov     w0, #0
    b.pl    1f                          // not below (or unordered)
    fcvtzs  x0, d0
1:  ret
    .ltorg

// m_run: runs until the program ends, the steps run out, or it goes wrong -> x0 0, 1 or -1
    .macro  PUSH reg
    cmp     x22, x26
    b.hs    m_deep
    str     \reg, [x22], #8
    .endm
    .macro  POP reg
    ldr     \reg, [x22, #-8]!
    .endm
    .macro  NEXT
    b       m_next
    .endm
m_run:
    stp     x29, x30, [sp, #-16]!
    ldr     x21, [x19, #W_PC]
    ldr     x9, [x19, #W_CODE]
    add     x21, x19, x21
    add     x21, x21, x9
    ldr     x22, [x19, #W_SP]
    add     x22, x19, x22
    ldr     x23, [x19, #W_CONST]
    add     x23, x19, x23
    ldr     x24, [x19, #W_GLOB]
    add     x24, x19, x24
    ldr     x26, [x19, #W_STACK_END]
    add     x26, x19, x26
m_next:
    subs    x25, x25, #1
    b.lt    m_pause
    ldrb    w0, [x21], #1
    cmp     w0, #OP_COUNT
    b.hs    m_wrong
    adr     x1, m_table
    ldrsw   x2, [x1, x0, lsl #2]
    add     x1, x1, x2
    br      x1
m_pause:
    mov     x0, #1
    b       m_leave
m_halt:
    mov     w9, #2
    str     w9, [x19, #W_STATE]
    mov     x0, #0
    sub     x21, x21, #1
m_leave:
    ldr     x9, [x19, #W_CODE]
    add     x9, x19, x9
    sub     x9, x21, x9
    str     x9, [x19, #W_PC]
    sub     x9, x22, x19
    str     x9, [x19, #W_SP]
    ldp     x29, x30, [sp], #16
    ret
m_deep:
    adr     x0, e_deep
    mov     x1, #(e_full - e_deep)
    b       m_fail
m_full:
    adr     x0, e_full
    mov     x1, #(e_wrong - e_full)
    b       m_fail
m_wrong:
    adr     x0, e_wrong
    mov     x1, #(e_wrong_end - e_wrong)
m_fail:
    bl      w_string
    str     x0, [x19, #W_ERR]
    mov     w9, #3
    str     w9, [x19, #W_STATE]
    mov     x0, #-1
    b       m_leave
e_deep:  .ascii "RangeError: the stack is full"
e_full:  .ascii "RangeError: the world is full"
e_wrong: .ascii "InternalError: an instruction the machine does not know"
e_wrong_end:
    .balign 4
    .macro  U16 reg
    ldrh    \reg, [x21], #2
    .endm
i_const:
    U16     w0
    ldr     x0, [x23, x0, lsl #3]
    PUSH    x0
    NEXT
i_undef:
    VAL     x0, T_UNDEF
    PUSH    x0
    NEXT
i_null:
    VAL     x0, T_NULL
    PUSH    x0
    NEXT
i_true:
    VAL     x0, T_BOOL
    orr     x0, x0, #1
    PUSH    x0
    NEXT
i_false:
    VAL     x0, T_BOOL
    PUSH    x0
    NEXT
i_getg:
    U16     w0
    add     x1, x24, x0, lsl #4
    ldr     x0, [x1, #8]
    PUSH    x0
    NEXT
i_setg:
    U16     w0
    add     x1, x24, x0, lsl #4
    ldr     x0, [x22, #-8]
    str     x0, [x1, #8]
    NEXT
i_pop:
    sub     x22, x22, #8
    NEXT
i_dup:
    ldr     x0, [x22, #-8]
    PUSH    x0
    NEXT
i_void:
    VAL     x0, T_UNDEF
    str     x0, [x22, #-8]
    NEXT
// TWO: the top two values as numbers -> d1 (the lower, left) and d0 (the top, right); the stack loses one place
    .macro  TWO
    ldp     x0, x1, [x22, #-16]
    lsr     x2, x0, #48
    lsr     x3, x1, #48
    mov     w16, #T_UNDEF
    cmp     w2, w16
    ccmp    w3, w16, #2, lo
    b.hs    80f
    fmov    d1, x0
    fmov    d0, x1
    b       81f
80: bl      m_two_slow
81: sub     x22, x22, #8
    .endm
    .macro  RESULT
    str     d0, [x22, #-8]
    NEXT
    .endm
m_two_slow:                             // not both numbers: each is made one, by the language's rules
    stp     x29, x30, [sp, #-32]!
    ldr     x0, [x22, #-16]
    bl      v_number
    str     d0, [sp, #16]
    ldr     x0, [x22, #-8]
    bl      v_number
    ldr     d1, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
i_add:
    ldp     x0, x1, [x22, #-16]
    lsr     x2, x0, #48
    lsr     x3, x1, #48
    mov     w16, #T_UNDEF
    cmp     w2, w16
    ccmp    w3, w16, #2, lo
    b.hs    1f
    fmov    d1, x0
    fmov    d0, x1
    fadd    d0, d1, d0
    sub     x22, x22, #8
    RESULT
1:  mov     w16, #T_STRING              // text on either side: both become text and are joined
    cmp     w2, w16
    ccmp    w3, w16, #4, ne
    b.eq    2f
    bl      m_two_slow
    fadd    d0, d1, d0
    sub     x22, x22, #8
    RESULT
2:  bl      v_text
    cbz     x0, m_full
    str     x0, [x22, #-16]
    ldr     x0, [x22, #-8]
    bl      v_text
    cbz     x0, m_full
    mov     x1, x0
    ldr     x0, [x22, #-16]
    bl      v_join
    cbz     x0, m_full
    sub     x22, x22, #8
    str     x0, [x22, #-8]
    NEXT
i_sub:
    TWO
    fsub    d0, d1, d0
    RESULT
i_mul:
    TWO
    fmul    d0, d1, d0
    RESULT
i_div:
    TWO
    fdiv    d0, d1, d0
    RESULT
i_mod:                                  // the remainder, exact, with the sign of the left side
    TWO
    fabs    d2, d1
    fabs    d3, d0
    ldr     x0, =0x7ff0000000000000
    fmov    d4, x0
    fcmp    d2, d4                      // left infinite or not a number, or right zero or not a number: not a number
    b.pl    8f
    fcmp    d3, #0.0
    b.eq    8f
    b.vs    8f
    fcmp    d3, d4                      // right infinite: the left side itself
    b.eq    7f
    fcmp    d2, d3
    b.mi    7f                          // left smaller: itself
    fdiv    d5, d2, d3
    frintz  d5, d5
    fmsub   d6, d5, d3, d2              // left - whole * right, in one exact step
    fcmp    d6, #0.0
    b.pl    1f
    fadd    d6, d6, d3                  // the quotient had rounded up
1:  fcmp    d6, d3
    b.mi    2f
    fsub    d6, d6, d3
2:  fmov    x0, d1                      // the sign of the left side
    fmov    x1, d6
    and     x0, x0, #0x8000000000000000
    orr     x1, x1, x0
    fmov    d0, x1
    RESULT
7:  fmov    d0, d1
    RESULT
8:  ldr     x0, =0x7ff8000000000000
    fmov    d0, x0
    RESULT
i_pow:                                  // whole powers by repeated squaring; others are to come with the Math library
    TWO
    frintz  d2, d0
    fcmp    d2, d0
    b.ne    8f
    fabs    d3, d0
    fcvtzu  x0, d3
    mov     x1, #1024
    cmp     x0, x1
    csel    x0, x1, x0, hi
    fmov    d4, #1.0
    fmov    d5, d1
1:  cbz     x0, 3f
    tbz     x0, #0, 2f
    fmul    d4, d4, d5
2:  fmul    d5, d5, d5
    lsr     x0, x0, #1
    b       1b
3:  fcmp    d0, #0.0
    b.pl    4f
    fmov    d5, #1.0
    fdiv    d4, d5, d4
4:  fmov    d0, d4
    RESULT
8:  ldr     x0, =0x7ff8000000000000
    fmov    d0, x0
    RESULT
i_neg:
    ldr     x0, [x22, #-8]
    bl      v_number
    fneg    d0, d0
    RESULT
i_plus:
    ldr     x0, [x22, #-8]
    bl      v_number
    RESULT
i_not:
    ldr     x0, [x22, #-8]
    bl      v_truthy
    eor     w0, w0, #1
    b       m_bool
i_bitnot:
    ldr     x0, [x22, #-8]
    bl      v_number
    bl      v_int32
    mvn     w0, w0
    scvtf   d0, w0
    RESULT
i_typeof:
    ldr     x0, [x22, #-8]
    ISNUM   x0
    b.hs    1f
    LIT     s_number, s_string
    b       9f
1:  mov     w16, #T_STRING
    cmp     w17, w16
    b.ne    2f
    LIT     s_string, s_boolean
    b       9f
2:  mov     w16, #T_BOOL
    cmp     w17, w16
    b.ne    3f
    LIT     s_boolean, s_object
    b       9f
3:  mov     w16, #T_UNDEF
    cmp     w17, w16
    b.ne    4f
    LIT     s_undefined, s_null
    b       9f
4:  LIT     s_object, s_objtext         // null too: the language's oldest mistake, kept
9:  cbz     x0, m_full
    str     x0, [x22, #-8]
    NEXT
// m_bool: the top of the stack becomes true or false by w0
m_bool:
    and     x0, x0, #1
    mov     x16, #(T_BOOL << 48)
    orr     x0, x0, x16
    str     x0, [x22, #-8]
    NEXT
// ORDER: the top two compared: text against text by its characters, anything else as numbers. -> flags as after comparing
// left with right (unordered if a not-a-number is involved); the stack loses one place.
    .macro  ORDER
    ldp     x0, x1, [x22, #-16]
    bl      m_order
    sub     x22, x22, #8
    .endm
m_order:
    lsr     x2, x0, #48
    lsr     x3, x1, #48
    mov     w16, #T_STRING
    cmp     w2, w16
    ccmp    w3, w16, #0, eq
    b.eq    1f
    mov     x15, x30
    bl      m_two_slow
    fcmp    d1, d0
    ret     x15
1:  STRV    x0, x2, x3
    STRV    x1, x4, x5
    mov     x6, #0
2:  cmp     x6, x3
    b.hs    3f
    cmp     x6, x5
    b.hs    4f
    ldrb    w7, [x2, x6]
    ldrb    w8, [x4, x6]
    add     x6, x6, #1
    cmp     w7, w8
    b.eq    2b
    ret
3:  cmp     x3, x5                      // the left ran out: less unless they are the same length
    ret
4:  cmp     x3, x5
    ret
i_lt:
    ORDER
    cset    w0, mi
    b       m_bool
i_gt:
    ORDER
    cset    w0, gt
    b       m_bool
i_le:
    ORDER
    cset    w0, ls
    b       m_bool
i_ge:
    ORDER
    cset    w0, ge
    b       m_bool
i_eq:
    ldp     x0, x1, [x22, #-16]
    bl      v_loose
    sub     x22, x22, #8
    b       m_bool
i_ne:
    ldp     x0, x1, [x22, #-16]
    bl      v_loose
    sub     x22, x22, #8
    eor     w0, w0, #1
    b       m_bool
i_seq:
    ldp     x0, x1, [x22, #-16]
    bl      v_strict
    sub     x22, x22, #8
    b       m_bool
i_sne:
    ldp     x0, x1, [x22, #-16]
    bl      v_strict
    sub     x22, x22, #8
    eor     w0, w0, #1
    b       m_bool
// BITS: the top two as 32-bit whole numbers -> w1 (left), w0 (right); the stack loses one place
    .macro  BITS
    TWO
    fmov    d8, d1
    bl      v_int32
    mov     w9, w0
    fmov    d0, d8
    bl      v_int32
    mov     w1, w0
    mov     w0, w9
    .endm
i_band:
    BITS
    and     w0, w1, w0
    scvtf   d0, w0
    RESULT
i_bor:
    BITS
    orr     w0, w1, w0
    scvtf   d0, w0
    RESULT
i_bxor:
    BITS
    eor     w0, w1, w0
    scvtf   d0, w0
    RESULT
i_shl:
    BITS
    lsl     w0, w1, w0
    scvtf   d0, w0
    RESULT
i_shr:
    BITS
    asr     w0, w1, w0
    scvtf   d0, w0
    RESULT
i_ushr:
    BITS
    lsr     w0, w1, w0
    ucvtf   d0, w0
    RESULT
    .macro  FAR reg
    ldrsw   \reg, [x21], #4
    .endm
i_jmp:
    FAR     x0
    add     x21, x21, x0
    NEXT
i_jf:
    POP     x0
    bl      v_truthy
    FAR     x1
    cbnz    w0, m_next
    add     x21, x21, x1
    NEXT
i_jt:
    POP     x0
    bl      v_truthy
    FAR     x1
    cbz     w0, m_next
    add     x21, x21, x1
    NEXT
i_jfk:
    ldr     x0, [x22, #-8]
    bl      v_truthy
    FAR     x1
    cbz     w0, 1f
    sub     x22, x22, #8
    NEXT
1:  add     x21, x21, x1
    NEXT
i_jtk:
    ldr     x0, [x22, #-8]
    bl      v_truthy
    FAR     x1
    cbnz    w0, 1f
    sub     x22, x22, #8
    NEXT
1:  add     x21, x21, x1
    NEXT
i_jnk:
    ldr     x0, [x22, #-8]
    FAR     x1
    lsr     x2, x0, #48
    mov     w16, #T_UNDEF
    sub     w2, w2, w16
    cmp     w2, #1                      // undefined or null
    b.hi    1f
    sub     x22, x22, #8
    NEXT
1:  add     x21, x21, x1
    NEXT
i_print:                                // a line of the values' texts, a space between
    ldrb    w27, [x21], #1
    sub     x28, x22, x27, lsl #3       // the first of them
    mov     x22, x28
    mov     w20, #0
1:  cmp     w20, w27
    b.hs    3f
    cbz     w20, 2f
    adr     x0, p_space
    mov     x1, #1
    bl      w_out
2:  ldr     x0, [x28, x20, lsl #3]
    bl      v_text
    cbz     x0, m_full
    STRV    x0, x0, x1
    bl      w_out
    add     w20, w20, #1
    b       1b
3:  adr     x0, p_line
    mov     x1, #1
    bl      w_out
    VAL     x0, T_UNDEF
    PUSH    x0
    NEXT
p_space: .byte ' '
p_line:  .byte 10
    .balign 4
m_table:
    .word   m_halt - m_table, i_const - m_table, i_undef - m_table, i_null - m_table, i_true - m_table, i_false - m_table
    .word   i_getg - m_table, i_setg - m_table, i_pop - m_table, i_dup - m_table
    .word   i_add - m_table, i_sub - m_table, i_mul - m_table, i_div - m_table, i_mod - m_table, i_pow - m_table
    .word   i_neg - m_table, i_plus - m_table, i_not - m_table, i_bitnot - m_table, i_typeof - m_table
    .word   i_lt - m_table, i_gt - m_table, i_le - m_table, i_ge - m_table, i_eq - m_table, i_ne - m_table, i_seq - m_table, i_sne - m_table
    .word   i_band - m_table, i_bor - m_table, i_bxor - m_table, i_shl - m_table, i_shr - m_table, i_ushr - m_table
    .word   i_jmp - m_table, i_jf - m_table, i_jt - m_table, i_jfk - m_table, i_jtk - m_table, i_jnk - m_table, i_print - m_table, i_void - m_table
    .ltorg
