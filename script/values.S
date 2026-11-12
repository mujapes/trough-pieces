// Values and their conversions, as the language defines them. x19 is the world. These routines use x0-x17 and d0-d3 only.
// ISNUM: is the value in \reg a number -> flags: lo if so. Uses x17.
    .macro  ISNUM reg
    lsr     x17, \reg, #48
    mov     w16, #T_UNDEF
    cmp     w17, w16
    .endm
// TAGIS: has the value in \reg this tag -> flags: eq if so. Uses x17.
    .macro  TAGIS reg, tag
    lsr     x17, \reg, #48
    mov     w16, #\tag
    cmp     w17, w16
    .endm
// STRV: where a string value's bytes are and how many -> \ptr, \len (the value in \reg, which may be \ptr)
    .macro  STRV reg, ptr, len
    and     \ptr, \reg, #0xffffffffffff
    add     \ptr, x19, \ptr
    ldr     \len, [\ptr], #8
    .endm
// LIT: a string value for fixed text between two labels -> x0 (0 if the world is full)
    .macro  LIT from, to
    adr     x0, \from
    mov     x1, #(\to - \from)
    bl      w_string
    .endm
// v_truthy: does the value x0 count as yes -> w0 1 or 0
v_truthy:
    ISNUM   x0
    b.hs    1f
    fmov    d0, x0                      // a number: no for zero and for not-a-number
    fcmp    d0, #0.0
    cset    w0, ne
    csel    w0, wzr, w0, vs
    ret
1:  mov     w16, #T_BOOL
    cmp     w17, w16
    b.ne    2f
    and     w0, w0, #1
    ret
2:  mov     w16, #T_STRING
    cmp     w17, w16
    b.ne    3f
    STRV    x0, x1, x2
    cmp     x2, #0
    cset    w0, ne
    ret
3:  mov     w16, #T_OBJECT
    cmp     w17, w16
    cset    w0, eq                      // undefined and null are no; an object is yes
    ret
// v_number: the value x0 as a number -> d0
v_number:
    ISNUM   x0
    b.hs    1f
    fmov    d0, x0
    ret
1:  mov     w16, #T_BOOL
    cmp     w17, w16
    b.ne    2f
    and     x0, x0, #1
    ucvtf   d0, x0
    ret
2:  mov     w16, #T_NULL
    cmp     w17, w16
    b.ne    3f
    movi    d0, #0
    ret
3:  mov     w16, #T_STRING
    cmp     w17, w16
    b.eq    v_text_number
    ldr     x0, =0x7ff8000000000000     // undefined, an object: not a number
    fmov    d0, x0
    ret
// v_text_number: the string value x0 read as a number, by the language's rules for text: spaces at either end do not count,
// nothing at all is zero, a base prefix is allowed, Infinity is a word; anything else that is not wholly a number is not one.
v_text_number:
    STRV    x0, x1, x2
    add     x2, x1, x2                  // x1 where we are, x2 the end
1:  cmp     x1, x2                      // spaces before
    b.hs    t_zero
    ldrb    w3, [x1]
    cmp     w3, #' '
    b.eq    2f
    sub     w4, w3, #9
    cmp     w4, #4
    b.hi    3f
2:  add     x1, x1, #1
    b       1b
3:  ldrb    w3, [x2, #-1]               // spaces after
    cmp     w3, #' '
    b.eq    4f
    sub     w4, w3, #9
    cmp     w4, #4
    b.hi    5f
4:  sub     x2, x2, #1
    b       3b
5:  mov     w5, #0                      // negative?
    mov     w14, #0                     // any sign at all?
    ldrb    w3, [x1]
    cmp     w3, #'-'
    cset    w5, eq
    b.eq    6f
    cmp     w3, #'+'
    b.ne    7f
6:  add     x1, x1, #1
    mov     w14, #1
    cmp     x1, x2
    b.hs    t_nan
7:  ldrb    w3, [x1]
    cmp     w3, #'I'
    b.ne    8f
    sub     x4, x2, x1
    cmp     x4, #8
    b.ne    t_nan
    ldr     x4, [x1]
    ldr     x6, =0x7974696e69666e49     // "Infinity"
    cmp     x4, x6
    b.ne    t_nan
    ldr     x0, =0x7ff0000000000000
    fmov    d0, x0
    b       t_sign
8:  cmp     w3, #'0'                    // a base prefix (never with a sign)
    b.ne    t_decimal
    add     x4, x1, #2
    cmp     x4, x2
    b.hi    t_decimal
    ldrb    w4, [x1, #1]
    orr     w4, w4, #0x20
    mov     w6, #16
    cmp     w4, #'x'
    b.eq    9f
    mov     w6, #8
    cmp     w4, #'o'
    b.eq    9f
    mov     w6, #2
    cmp     w4, #'b'
    b.ne    t_decimal
9:  cbnz    w14, t_nan                  // a sign before a base prefix is not a number
add     x1, x1, #2
    cmp     x1, x2
    b.hs    t_nan
    ucvtf   d1, w6
    movi    d0, #0
12: cmp     x1, x2
    b.hs    t_done
    ldrb    w3, [x1], #1
    sub     w4, w3, #'0'
    cmp     w4, #9
    b.ls    13f
    orr     w4, w3, #0x20
    sub     w4, w4, #'a'
    cmp     w4, #5
    b.hi    t_nan
    add     w4, w4, #10
13: cmp     w4, w6
    b.hs    t_nan
    ucvtf   d2, w4
    fmadd   d0, d0, d1, d2
    b       12b
t_decimal:
    mov     x6, #0                      // digits (the first 19), the power of ten, digits seen, past the point
    mov     w7, #0
    mov     w8, #0
    mov     w9, #0
    mov     w10, #0                     // any digit at all
1:  cmp     x1, x2
    b.hs    5f
    ldrb    w3, [x1]
    cmp     w3, #'.'
    b.ne    2f
    cbnz    w9, t_nan
    mov     w9, #1
    b       4f
2:  sub     w4, w3, #'0'
    cmp     w4, #9
    b.hi    5f
    mov     w10, #1
    cmp     w8, #19
    b.hs    3f
    mov     x11, #10
    madd    x6, x6, x11, x4
    cbz     x6, 14f
    add     w8, w8, #1
14: sub     w7, w7, w9
    b       4f
3:  eor     w11, w9, #1
    add     w7, w7, w11
4:  add     x1, x1, #1
    b       1b
5:  cbz     w10, t_nan
    cmp     x1, x2
    b.hs    8f
    orr     w4, w3, #0x20
    cmp     w4, #'e'
    b.ne    t_nan
    add     x1, x1, #1
    cmp     x1, x2
    b.hs    t_nan
    mov     w11, #0
    ldrb    w3, [x1]
    cmp     w3, #'-'
    cset    w11, eq
    b.eq    6f
    cmp     w3, #'+'
    b.ne    15f
6:  add     x1, x1, #1
15: cmp     x1, x2
    b.hs    t_nan
    mov     w12, #0
7:  cmp     x1, x2
    b.hs    16f
    ldrb    w3, [x1], #1
    sub     w4, w3, #'0'
    cmp     w4, #9
    b.hi    t_nan
    mov     w13, #10
    madd    w12, w12, w13, w4
    mov     w13, #10000
    cmp     w12, w13
    csel    w12, w13, w12, hi
    b       7b
16: cmp     w11, #0
    cneg    w12, w12, ne
    add     w7, w7, w12
8:  ucvtf   d0, x6
    cbz     x6, t_sign
    adr     x4, t_pow10
9:  cmp     w7, #0
    b.eq    t_sign
    b.lt    10f
    mov     w11, #22
    cmp     w7, w11
    csel    w11, w7, w11, lt
    ldr     d1, [x4, w11, sxtw #3]
    fmul    d0, d0, d1
    sub     w7, w7, w11
    b       9b
10: neg     w11, w7
    mov     w12, #22
    cmp     w11, w12
    csel    w11, w11, w12, lt
    ldr     d1, [x4, w11, sxtw #3]
    fdiv    d0, d0, d1
    add     w7, w7, w11
    b       9b
t_sign:
    cbz     w5, t_done
    fneg    d0, d0
t_done:
    ret
t_zero:
    movi    d0, #0
    ret
t_nan:
    ldr     x0, =0x7ff8000000000000
    fmov    d0, x0
    ret
    .ltorg
// v_same_text: are the two string values x0 and x1 the same text -> w0 1 or 0
v_same_text:
    STRV    x0, x2, x3
    STRV    x1, x4, x5
    mov     w0, #0
    cmp     x3, x5
    b.ne    2f
    mov     x6, #0
1:  cmp     x6, x3
    b.hs    3f
    ldrb    w7, [x2, x6]
    ldrb    w8, [x4, x6]
    add     x6, x6, #1
    cmp     w7, w8
    b.eq    1b
2:  ret
3:  mov     w0, #1
    ret
// v_strict: are the values x0 and x1 the same without any conversion (===) -> w0 1 or 0
v_strict:
    ISNUM   x0
    b.hs    1f
    mov     x2, x17
    ISNUM   x1
    b.hs    9f
    fmov    d0, x0                      // two numbers: by value (not-a-number equals nothing; the two zeros are equal)
    fmov    d1, x1
    fcmp    d0, d1
    cset    w0, eq
    ret
1:  lsr     x2, x0, #48
    lsr     x3, x1, #48
    cmp     x2, x3
    b.ne    9f
    mov     w16, #T_STRING
    cmp     w2, w16
    b.eq    v_same_text
    cmp     x0, x1
    cset    w0, eq
    ret
9:  mov     w0, #0
    ret
// v_loose: are the values x0 and x1 the same after the language's conversions (==) -> w0 1 or 0
v_loose:
    stp     x29, x30, [sp, #-48]!
    stp     x0, x1, [sp, #16]
    lsr     x2, x0, #48
    lsr     x3, x1, #48
    mov     w16, #T_UNDEF
    cmp     w2, w16
    csel    w4, w16, w2, lo             // numbers of every pattern count as one kind
    cmp     w3, w16
    csel    w5, w16, w3, lo
    sub     w4, w4, w16                 // 0 number or undefined... (told apart below), 1 null, 2 boolean, 3 string, 4 object
    sub     w5, w5, w16
    cmp     w2, w16
    cset    w6, lo                      // is the first a number
    cmp     w3, w16
    cset    w7, lo
    cmp     w6, w7
    b.ne    3f
    cbnz    w6, 1f
    cmp     w2, w3
    b.eq    1f
    orr     w8, w4, w5                  // different kinds, neither a number: undefined and null equal each other only
    cmp     w8, #1
    b.eq    8f
    b       3f
1:  ldp     x0, x1, [sp, #16]           // the same kind: as ===
    bl      v_strict
    b       9f
3:  cmp     w6, #0                      // undefined or null against anything else: no
    ccmp    w4, #1, #2, eq
    b.ls    7f
    cmp     w7, #0
    ccmp    w5, #1, #2, eq
    b.ls    7f
    ldr     x0, [sp, #16]               // otherwise both become numbers (booleans and text alike) and are compared
    bl      v_number
    str     d0, [sp, #32]
    ldr     x0, [sp, #24]
    bl      v_number
    ldr     d1, [sp, #32]
    fcmp    d0, d1
    cset    w0, eq
    b       9f
7:  mov     w0, #0
    b       9f
8:  mov     w0, #1
9:  ldp     x29, x30, [sp], #48
    ret
