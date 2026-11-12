// JSON.parse in machine code (stage 6). 30 in n_table. The text is read where it lies in its string: x23 the place, x24
// the end (the machine's own x23 and x24 are put back at the end; m_fail puts them back itself), W_JWIDE whether a unit is
// two bytes. One routine per kind of value, calling each other; values being built are held on the processor's stack.
// Anything the grammar does not allow: SyntaxError. A reviver, if given, is applied in prelude.js.
    .macro  JPEEK                       // the unit at the place -> w0, or -1 at the end. Uses x9.
    mov     w0, #-1
    cmp     x23, x24
    b.hs    991f
    ldr     x9, [x19, #W_JWIDE]
    cbnz    x9, 990f
    ldrb    w0, [x23]
    b       991f
990: ldrh   w0, [x23]
991:
    .endm
    .macro  JADV                        // past it. Uses x9.
    ldr     x9, [x19, #W_JWIDE]
    add     x23, x23, #1
    add     x23, x23, x9
    .endm
n_jparse:
    NIN
    ldr     x0, [x1]
    bl      v_text
    cbz     x0, n_full
    and     x0, x0, #0xffffffffffff
    add     x23, x19, x0
    ldr     x9, [x23], #8
    and     x10, x9, #0xffffffff
    lsr     x9, x9, #32
    and     x9, x9, #1
    str     x9, [x19, #W_JWIDE]
    lsl     x10, x10, x9
    add     x24, x23, x10
    bl      j_value
    str     x0, [sp, #40]
    bl      j_ws
    tbz     w0, #31, j_err
    ldr     x23, [x19, #W_CONST]
    add     x23, x19, x23
    ldr     x24, [x19, #W_GLOB]
    add     x24, x19, x24
    ldr     x0, [sp, #40]
    NOUT
j_err:
    adr     x0, e_json
    mov     x1, #(e_json_end - e_json)
    b       n_fail
e_json: .ascii "SyntaxError: Unexpected token in JSON"
e_json_end:
k_jtrue:  .ascii "true"
k_jfalse: .ascii "false"
k_jnull:  .ascii "null"
    .balign 4
// j_ws: past any spaces and line ends -> w0 the unit now at the place (-1: the end)
j_ws:
1:  JPEEK
    cmp     w0, #32
    b.eq    2f
    cmp     w0, #9
    b.eq    2f
    cmp     w0, #10
    b.eq    2f
    cmp     w0, #13
    b.ne    3f
2:  JADV
    b       1b
3:  ret
// j_word: the x2 letters at x1 must be next
j_word:
1:  JPEEK
    ldrb    w10, [x1], #1
    cmp     w0, w10
    b.ne    j_err
    JADV
    subs    x2, x2, #1
    b.ne    1b
    ret
// j_value: the value at the place -> x0. Its frame: 16 the object or array being filled, 24 a key or how many items.
j_value:
    stp     x29, x30, [sp, #-48]!
    ldr     x9, [x19, #W_NSP]           // nesting is held to what 128 KB of the processor's stack allows
    mov     x10, sp
    sub     x9, x9, x10
    cmp     x9, #0x20000
    b.hi    j_err
    bl      j_ws
    cmp     w0, #'{'
    b.eq    j_obj
    cmp     w0, #'['
    b.eq    j_arr
    cmp     w0, #34
    b.ne    1f
    bl      j_string
    b       j_out
1:  cmp     w0, #'-'
    b.eq    2f
    sub     w10, w0, #'0'
    cmp     w10, #10
    b.hs    3f
2:  bl      j_number
    b       j_out
3:  cmp     w0, #'t'
    b.ne    4f
    adr     x1, k_jtrue
    mov     x2, #4
    bl      j_word
    VAL     x0, T_BOOL
    orr     x0, x0, #1
    b       j_out
4:  cmp     w0, #'f'
    b.ne    5f
    adr     x1, k_jfalse
    mov     x2, #5
    bl      j_word
    VAL     x0, T_BOOL
    b       j_out
5:  cmp     w0, #'n'
    b.ne    j_err
    adr     x1, k_jnull
    mov     x2, #4
    bl      j_word
    VAL     x0, T_NULL
j_out:
    ldp     x29, x30, [sp], #48
    ret
j_obj:
    JADV
    mov     x0, #32
    mov     x1, #3
    bl      o_make
    cbz     x0, n_full
    str     x0, [sp, #16]
    bl      j_ws
    cmp     w0, #'}'
    b.eq    8f
1:  bl      j_ws
    cmp     w0, #34
    b.ne    j_err
    bl      j_string
    str     x0, [sp, #24]
    bl      j_ws
    cmp     w0, #':'
    b.ne    j_err
    JADV
    bl      j_value
    mov     x2, x0
    ldr     x1, [sp, #24]
    ldr     x0, [sp, #16]
    add     x0, x19, x0
    bl      o_put
    cbz     x0, n_full
    bl      j_ws
    cmp     w0, #','
    b.ne    2f
    JADV
    b       1b
2:  cmp     w0, #'}'
    b.ne    j_err
8:  JADV
    ldr     x0, [sp, #16]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    b       j_out
j_arr:
    JADV
    mov     x0, #48
    mov     x1, #4
    bl      o_make
    cbz     x0, n_full
    stp     x0, xzr, [sp, #16]
    bl      j_ws
    cmp     w0, #']'
    b.eq    8f
1:  bl      j_value
    mov     x2, x0
    ldp     x0, x1, [sp, #16]
    add     x9, x1, #1
    str     x9, [sp, #24]
    add     x0, x19, x0
    bl      a_set
    cbz     x0, n_full
    bl      j_ws
    cmp     w0, #','
    b.ne    2f
    JADV
    b       1b
2:  cmp     w0, #']'
    b.ne    j_err
8:  JADV
    ldr     x0, [sp, #16]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    b       j_out
// j_unit: the next unit of a string's text, an escape worked out -> w0, or -1 for the closing quote. Uses x9-x12.
j_unit:
    JPEEK
    tbnz    w0, #31, j_err
    JADV
    cmp     w0, #34
    b.ne    1f
    mov     w0, #-1
    ret
1:  cmp     w0, #32
    b.lo    j_err
    cmp     w0, #92
    b.eq    2f
    ret
2:  JPEEK
    tbnz    w0, #31, j_err
    JADV
    cmp     w0, #34
    b.eq    9f
    cmp     w0, #92
    b.eq    9f
    cmp     w0, #'/'
    b.eq    9f
    mov     w10, #8
    cmp     w0, #'b'
    b.eq    8f
    mov     w10, #12
    cmp     w0, #'f'
    b.eq    8f
    mov     w10, #10
    cmp     w0, #'n'
    b.eq    8f
    mov     w10, #13
    cmp     w0, #'r'
    b.eq    8f
    mov     w10, #9
    cmp     w0, #'t'
    b.eq    8f
    cmp     w0, #'u'
    b.ne    j_err
    mov     w10, #0
    mov     w11, #4
3:  JPEEK
    tbnz    w0, #31, j_err
    JADV
    sub     w12, w0, #'0'
    cmp     w12, #10
    b.lo    4f
    orr     w0, w0, #32
    sub     w12, w0, #'a'
    cmp     w12, #6
    b.hs    j_err
    add     w12, w12, #10
4:  add     w10, w12, w10, lsl #4
    subs    w11, w11, #1
    b.ne    3b
8:  mov     w0, w10
9:  ret
// j_string: the string whose opening quote is at the place -> x0 its value. Read twice: once to count its units and see
// whether any is past 255, once to fill it.
j_string:
    str     x30, [sp, #-16]!
    JADV
    mov     x15, x23
    mov     x13, #0
    mov     x14, #0
1:  bl      j_unit
    tbnz    w0, #31, 2f
    add     x13, x13, #1
    cmp     w0, #255
    csinc   x14, x14, xzr, ls
    b       1b
2:  mov     x23, x15
    lsl     x0, x13, x14
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, n_full
    mov     x16, x0
    add     x15, x19, x0
    lsl     x9, x14, #32
    orr     x9, x9, x13
    str     x9, [x15], #8
3:  bl      j_unit
    tbnz    w0, #31, 4f
    cbz     x14, 31f
    strh    w0, [x15], #2
    b       3b
31: strb    w0, [x15], #1
    b       3b
4:  orr     x0, x16, #(T_STRING << 48)
    ldr     x30, [sp], #16
    ret
// j_number: the number at the place -> x0. Up to fifteen digits with nothing after them are a whole number, exact as it
// stands; anything else is checked against the grammar and read by v_text_number.
j_number:
    str     x30, [sp, #-16]!
    mov     x15, x23
    mov     x16, #0
    mov     x13, #0
    mov     x14, #0
    JPEEK
    cmp     w0, #'-'
    b.ne    1f
    mov     x16, #1
    JADV
    JPEEK
1:  sub     w10, w0, #'0'
    cmp     w10, #10
    b.hs    j_err
    cbnz    w10, 21f
    mov     x14, #1
    JADV
    JPEEK
    b       3f
21: sub     w10, w0, #'0'
    cmp     w10, #10
    b.hs    3f
    cmp     x14, #18
    b.hs    22f
    mov     x11, #10
    madd    x13, x13, x11, x10
22: add     x14, x14, #1
    JADV
    JPEEK
    b       21b
3:  cmp     w0, #'.'
    b.eq    5f
    orr     w10, w0, #32
    cmp     w10, #'e'
    b.eq    6f
    cmp     x14, #15
    b.hi    7f
    scvtf   d0, x13
    cbz     x16, 4f
    fneg    d0, d0
4:  fmov    x0, d0
    ldr     x30, [sp], #16
    ret
5:  JADV
    JPEEK
    sub     w10, w0, #'0'
    cmp     w10, #10
    b.hs    j_err
51: JADV
    JPEEK
    sub     w10, w0, #'0'
    cmp     w10, #10
    b.lo    51b
    orr     w10, w0, #32
    cmp     w10, #'e'
    b.ne    7f
6:  JADV
    JPEEK
    cmp     w0, #'+'
    b.eq    61f
    cmp     w0, #'-'
    b.ne    62f
61: JADV
    JPEEK
62: sub     w10, w0, #'0'
    cmp     w10, #10
    b.hs    j_err
63: JADV
    JPEEK
    sub     w10, w0, #'0'
    cmp     w10, #10
    b.lo    63b
7:  ldr     x12, [x19, #W_JWIDE]
    sub     x13, x23, x15
    lsr     x13, x13, x12
    add     x0, x13, #8
    bl      w_alloc
    cbz     x0, n_full
    mov     x16, x0
    add     x8, x19, x0
    str     x13, [x8], #8
    mov     x10, x15
    mov     x6, #0
    bl      s_copy
    orr     x0, x16, #(T_STRING << 48)
    bl      v_text_number
    fmov    x0, d0
    ldr     x30, [sp], #16
    ret
