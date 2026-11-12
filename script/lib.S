// The library (stage 6): what the language has built in. Two halves. The routines here are the built-ins written in machine
// code; script/prelude.js (taken into compile.S as it stands, and translated before every program) gives them their names
// and writes the rest in the language itself: everything that calls a function it was handed (map, sort, ...) and whatever
// has not been written here yet. A routine moves from there to here by getting a number in n_table.
// A built-in function is a function whose plan has flag 32 and, where the instructions' start would be, its number.
// m_call hands over to m_native. The routine is called with w0 how many arguments, x1 where they are (at least four places
// can be read: missing ones are undefined), x11 `this`; it answers in x0 and may use x0-x17, d0-d7. It cannot call back
// into the language. Out of room: b n_full. An error: x0, x1 the text ("Name: message"), b n_fail. Both from any depth.
m_native:
    ldr     x9, [x4, #8]
    cmp     x9, #28
    b.eq    m_fcall
    cmp     x9, #29
    b.eq    m_fapply
    add     x8, x1, #32
    cmp     x8, x26
    b.hi    m_deep
    VAL     x7, T_UNDEF
    add     x9, x1, x0, lsl #3
1:  cmp     x9, x8
    b.hs    2f
    str     x7, [x9], #8
    b       1b
2:  ldr     x9, [x4, #8]
    cmp     x9, #N_COUNT
    b.hs    m_wrong
    adr     x10, n_table
    ldrsw   x9, [x10, x9, lsl #2]
    add     x10, x10, x9
    stp     x12, x13, [sp, #-16]!
    mov     x9, sp
    str     x9, [x19, #W_NSP]
    blr     x10
    ldp     x12, x13, [sp], #16
// m_answer: a call's answer x0 goes to its place x12. A call of kind x13 3 or 4 was an object's toString, made by m_toprim
// for the top value or the one under it: the answer (the usual text if it is itself an object) takes the object's place
// and the stack is as it was, for the instruction to run again.
m_answer:
    cmp     x13, #3
    b.hs    1f
    str     x0, [x12]
    add     x22, x12, #8
    NEXT
1:  cmp     x13, #5
    b.eq    3f
    TAGIS   x0, T_OBJECT
    b.ne    2f
    mov     x4, x12
    mov     x5, x13
    LIT     s_objtext, s_end
    cbz     x0, m_full
    mov     x12, x4
    mov     x13, x5
2:  str     x0, [x12]
    sub     x13, x13, #2
    add     x22, x12, x13, lsl #3
    NEXT
3:  str     x0, [x12]
    add     x22, x12, #8
    NEXT
// m_drain: from an instruction of x6 bytes that wants an array to go through and met, on top, something else: the
// prelude's function (W_ITERFN) is called with it (call kind 5), its answer takes the value's place and the instruction
// runs again.
m_drain:
    ldr     x4, [x19, #W_ITERFN]
    cbz     x4, 1f
    sub     x21, x21, x6
    ldr     x0, [x22, #-8]
    sub     x12, x22, #8
    VAL     x11, T_UNDEF
    PUSH    x4
    mov     x1, x22
    PUSH    x0
    mov     x0, #1
    mov     x13, #5
    b       m_call
1:  adr     x0, e_noiter
    mov     x1, #(e_noiter_end - e_noiter)
    b       m_fail
// m_toprim: from an instruction of one byte that met an object where it wants text or a number: x5 the object, x4 1 if it
// is the top value, 2 if the one under. A plain object with a toString that is a function has it called, and the
// instruction runs again with the answer in the object's place; any other object becomes its usual text at once.
m_toprim:
    sub     x21, x21, #1
    and     x6, x5, #0xffffffffffff
    ldr     x6, [x19, x6]
    cmp     x6, #3
    b.ne    5f
    stp     x4, x5, [sp, #-16]!
    mov     x0, x5
    ldr     x1, [x19, #W_K_TOSTRING]
    bl      o_get
    ldp     x4, x5, [sp], #16
    TAGIS   x0, T_OBJECT
    b.ne    5f
    and     x6, x0, #0xffffffffffff
    ldr     x6, [x19, x6]
    cmp     x6, #1
    b.ne    5f
    sub     x12, x22, x4, lsl #3
    mov     x11, x5
    PUSH    x0
    mov     x1, x22
    mov     x0, #0
    add     x13, x4, #2
    b       m_call
5:  str     x4, [sp, #-16]!
    mov     x0, x5
    bl      v_text
    ldr     x4, [sp], #16
    cbz     x0, m_full
    sub     x12, x22, x4, lsl #3
    str     x0, [x12]
    NEXT
// 28 call, 29 apply (of a function): not routines but turns of the call itself: `this` is the function to call, the first
// argument its `this`; the rest (call) or the items of the second, an array (apply), are its arguments.
m_fcall:
    str     x11, [x1, #-8]
    VAL     x11, T_UNDEF
    cbz     x0, m_call
    ldr     x11, [x1]
    sub     x0, x0, #1
    mov     x8, #0
1:  cmp     x8, x0
    b.hs    2f
    add     x9, x1, x8, lsl #3
    ldr     x10, [x9, #8]
    str     x10, [x9]
    add     x8, x8, #1
    b       1b
2:  add     x22, x1, x0, lsl #3
    b       m_call
m_fapply:
    str     x11, [x1, #-8]
    VAL     x11, T_UNDEF
    mov     x5, #0
    cbz     x0, 9f
    ldr     x11, [x1]
    cmp     x0, #2
    b.lo    9f
    ldr     x6, [x1, #8]
    TAGIS   x6, T_OBJECT
    b.ne    9f
    and     x6, x6, #0xffffffffffff
    add     x6, x19, x6
    ldr     x7, [x6]
    cmp     x7, #4
    b.ne    9f
    ldr     w5, [x6, #A_LEN]
    ldr     x7, [x6, #A_ITEMS]
    add     x7, x19, x7
    add     x8, x1, x5, lsl #3
    add     x8, x8, #64
    cmp     x8, x26
    b.hi    m_deep
    mov     x8, #0
1:  cmp     x8, x5
    b.hs    9f
    ldr     x9, [x7, x8, lsl #3]
    str     x9, [x1, x8, lsl #3]
    add     x8, x8, #1
    b       1b
9:  add     x22, x1, x5, lsl #3
    mov     x0, x5
    b       m_call
n_full:
    ldr     x9, [x19, #W_NSP]
    add     sp, x9, #16
    b       m_full
n_fail:
    ldr     x9, [x19, #W_NSP]
    add     sp, x9, #16
    b       m_fail
// n_function: a built-in function for the routine numbered x0 -> x0 the value, or 0 if the world is full
n_function:
    stp     x29, x30, [sp, #-32]!
    str     x0, [sp, #16]
    mov     x0, #40
    mov     x1, #2
    bl      o_make
    cbz     x0, 9f
    add     x9, x19, x0
    ldr     x10, [sp, #16]
    str     x10, [x9, #8]
    str     xzr, [x9, #16]
    mov     x10, #32
    str     x10, [x9, #24]
    str     xzr, [x9, #32]
    str     x0, [sp, #24]
    mov     x0, #64
    mov     x1, #1
    bl      o_make
    cbz     x0, 9f
    add     x9, x19, x0
    ldr     x10, [sp, #24]
    str     x10, [x9, #F_PLAN]
    str     xzr, [x9, #F_SCOPE]
    VAL     x10, T_UNDEF
    str     x10, [x9, #F_THIS]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
9:  ldp     x29, x30, [sp], #32
    ret
// Inside a routine: NIN keeps how many arguments (16), where (24) and `this` (32); 40 is free. ARGNUM: argument \n as a
// number -> d0. THISSTR: `this` as a string value -> x0 and kept at 32. n_num, n_bool: the answer d0, or w0 as true or false.
    .macro  NIN
    stp     x29, x30, [sp, #-48]!
    stp     x0, x1, [sp, #16]
    str     x11, [sp, #32]
    .endm
    .macro  NOUT
    ldp     x29, x30, [sp], #48
    ret
    .endm
    .macro  ARGNUM n
    ldr     x1, [sp, #24]
    ldr     x0, [x1, #(8 * \n)]
    bl      v_number
    .endm
    .macro  THISSTR
    ldr     x0, [sp, #32]
    bl      v_text
    cbz     x0, n_full
    str     x0, [sp, #32]
    .endm
    .macro  MATH1 name, ins
\name:
    NIN
    ARGNUM  0
    \ins    d0, d0
    b       n_num
    .endm
n_num:
    fmov    x0, d0
    NOUT
n_bool:
    and     x0, x0, #1
    mov     x9, #(T_BOOL << 48)
    orr     x0, x0, x9
    NOUT
n_undef:
    VAL     x0, T_UNDEF
    NOUT
// 0, __n: with a number from 0 up, a built-in function for that routine; with -1 to -6 and an object, that object is what
// plain objects, arrays, functions, strings, numbers, booleans inherit from; with -7, none of them inherits anything yet.
n_maker:
    NIN
    ARGNUM  0
    fcvtzs  x9, d0
    tbnz    x9, #63, 1f
    mov     x0, x9
    bl      n_function
    cbz     x0, n_full
    NOUT
1:  mvn     x9, x9
    add     x11, x19, #W_PROTOS
    cmp     x9, #6
    b.hs    2f
    ldr     x1, [sp, #24]
    ldr     x10, [x1, #8]
    str     x10, [x11, x9, lsl #3]
    cmp     x9, #2
    b.ne    n_undef
    ldr     x11, [x19, #W_GLOB]         // functions: the ones declared at the top were made before this was said,
    add     x11, x19, x11               // and are all among the globals: they inherit now
    ldr     x12, [x19, #W_GLOB_N]
3:  cbz     x12, n_undef
    ldr     x13, [x11, #8]
    add     x11, x11, #16
    sub     x12, x12, #1
    lsr     x14, x13, #48
    mov     w16, #T_OBJECT
    cmp     w14, w16
    b.ne    3b
    and     x13, x13, #0xffffffffffff
    add     x13, x19, x13
    ldr     x14, [x13]
    cmp     x14, #1
    b.ne    3b
    ldr     x14, [x13, #O_PROTO]
    lsr     x14, x14, #48
    mov     w16, #T_NULL
    cmp     w14, w16
    b.ne    3b
    str     x10, [x13, #O_PROTO]
    b       3b
2:  cmp     x9, #7
    b.ne    4f
    ldr     x1, [sp, #24]
    ldr     x10, [x1, #8]
    str     x10, [x19, #W_ITERFN]
    b       n_undef
4:  stp     xzr, xzr, [x11]
    stp     xzr, xzr, [x11, #16]
    stp     xzr, xzr, [x11, #32]
    b       n_undef
// 42: a number that is an object's alone for as long as the world lasts (where it lies); Map and Set tell objects apart by it
n_ident:
    ldr     x9, [x1]
    and     x9, x9, #0xffffffffffff
    ucvtf   d0, x9
    fmov    x0, d0
    ret
// Math. 1 floor, 2 ceil, 3 abs, 4 sqrt, 6 trunc: one instruction each on this processor.
    MATH1   n_floor, frintm
    MATH1   n_ceil, frintp
    MATH1   n_abs, fabs
    MATH1   n_sqrt, fsqrt
    MATH1   n_trunc, frintz
// 5 round: to the nearest whole number, halves upward; a zero keeps the number's sign
n_round:
    NIN
    ARGNUM  0
    frintm  d1, d0
    fsub    d2, d0, d1
    fmov    d3, #0.5
    fcmp    d2, d3
    b.lt    1f
    fmov    d3, #1.0
    fadd    d1, d1, d3
1:  fmov    x0, d1
    fcmp    d1, #0.0
    b.ne    2f
    fmov    x9, d0
    and     x9, x9, #0x8000000000000000
    orr     x0, x0, x9
2:  NOUT
// 7 sign
n_sign:
    NIN
    ARGNUM  0
    fcmp    d0, #0.0
    b.vs    n_num
    b.eq    n_num
    fmov    d1, #1.0
    fmov    d2, #-1.0
    fcsel   d0, d1, d2, gt
    b       n_num
// 8 min, 9 max: of all the arguments; not a number if any is not
n_min:
    mov     x9, #0x7ff0000000000000
    mov     x10, #0
    b       1f
n_max:
    mov     x9, #0xfff0000000000000
    mov     x10, #1
1:  NIN
    str     x9, [sp, #32]
    str     x10, [sp, #40]
2:  ldr     x9, [sp, #16]
    cbz     x9, 8f
    sub     x9, x9, #1
    str     x9, [sp, #16]
    ldr     x1, [sp, #24]
    ldr     x0, [x1], #8
    str     x1, [sp, #24]
    bl      v_number
    ldr     d1, [sp, #32]
    ldr     x9, [sp, #40]
    cbnz    x9, 3f
    fmin    d1, d1, d0
    b       4f
3:  fmax    d1, d1, d0
4:  str     d1, [sp, #32]
    b       2b
8:  ldr     x0, [sp, #32]
    NOUT
// n_arr: `this` must be an array -> x9 where it is. Uses x10, x16.
n_arr:
    ldr     x9, [sp, #32]
    lsr     x10, x9, #48
    mov     w16, #T_OBJECT
    cmp     w10, w16
    b.ne    9f
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     x10, [x9]
    cmp     x10, #4
    b.ne    9f
    ret
9:  adr     x0, e_notarr
    mov     x1, #(e_notarr_end - e_notarr)
    b       n_fail
e_notarr: .ascii "TypeError: not an array"
e_notarr_end:
    .balign 4
// 10 push: each argument becomes the array's new last item -> its length
n_push:
    NIN
1:  ldr     x9, [sp, #16]
    cbz     x9, 2f
    sub     x9, x9, #1
    str     x9, [sp, #16]
    bl      n_arr
    mov     x0, x9
    ldr     w1, [x9, #A_LEN]
    ldr     x10, [sp, #24]
    ldr     x2, [x10], #8
    str     x10, [sp, #24]
    bl      a_set
    cbz     x0, n_full
    b       1b
2:  bl      n_arr
    ldr     w0, [x9, #A_LEN]
    ucvtf   d0, x0
    b       n_num
// 11 pop: the array loses its last item -> it
n_pop:
    NIN
    bl      n_arr
    ldr     w10, [x9, #A_LEN]
    cbz     w10, n_undef
    sub     w10, w10, #1
    str     w10, [x9, #A_LEN]
    ldr     x11, [x9, #A_ITEMS]
    add     x11, x19, x11
    ldr     x0, [x11, x10, lsl #3]
    NOUT
// 12 Array.isArray
n_isarray:
    NIN
    ldr     x0, [x1]
    mov     x9, #0
    TAGIS   x0, T_OBJECT
    b.ne    1f
    and     x0, x0, #0xffffffffffff
    ldr     x10, [x19, x0]
    cmp     x10, #4
    cset    x9, eq
1:  mov     x0, x9
    b       n_bool
// 13 Object.keys: the value's own names, as an array of strings
n_keys:
    NIN
    ldr     x0, [x1]
    TAGIS   x0, T_OBJECT
    b.eq    1f
    mov     x1, #0
    bl      a_from
    b       2f
1:  mov     x9, #1
    str     x9, [x19, #W_OWNONLY]
    bl      m_keylist
    str     xzr, [x19, #W_OWNONLY]
2:  cbz     x0, n_full
    NOUT
// 14 hasOwnProperty (an object's named properties only, so far: not an array's items or length)
n_hasown:
    NIN
    ldr     x0, [x1]
    bl      v_text
    cbz     x0, n_full
    mov     x1, x0
    ldr     x0, [sp, #32]
    mov     x2, #0
    TAGIS   x0, T_OBJECT
    b.ne    1f
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    bl      o_find
1:  cmp     x2, #0
    cset    x0, ne
    b       n_bool
// 15 charCodeAt: the unit at that place, or not a number
n_charcode:
    NIN
    THISSTR
    ARGNUM  0
    fcvtzs  x9, d0
    ldr     x0, [sp, #32]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x10, [x0], #8
    and     x11, x10, #0xffffffff
    cmp     x9, x11
    b.hs    3f
    tbnz    x10, #32, 1f
    ldrb    w0, [x0, x9]
    b       2f
1:  ldrh    w0, [x0, x9, lsl #1]
2:  ucvtf   d0, w0
    b       n_num
3:  mov     x0, #0x7ff8000000000000
    NOUT
// 16: a string of the one unit given (String.fromCharCode is built on it)
n_fromcc:
    NIN
    ARGNUM  0
    bl      v_int32
    and     w0, w0, #0xffff
    bl      w_unit
    cbz     x0, n_full
    NOUT
// 17 substring: the units from one place up to another (either order; each held within the string). Wide only if it must be.
n_substring:
    NIN
    THISSTR
    ARGNUM  0
    fcvtzs  x9, d0
    str     x9, [sp, #40]
    ldr     x1, [sp, #24]
    ldr     x0, [x1, #8]
    mov     x10, #0x7fffffff
    TAGIS   x0, T_UNDEF
    b.eq    2f
    bl      v_number
    fcvtzs  x10, d0
2:  ldr     x9, [sp, #40]
    ldr     x0, [sp, #32]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x11, [x0], #8
    and     x12, x11, #0xffffffff
    lsr     x11, x11, #32
    and     x11, x11, #1
    cmp     x9, #0
    csel    x9, xzr, x9, lt
    cmp     x9, x12
    csel    x9, x12, x9, gt
    cmp     x10, #0
    csel    x10, xzr, x10, lt
    cmp     x10, x12
    csel    x10, x12, x10, gt
    cmp     x9, x10
    b.le    3f
    mov     x13, x9
    mov     x9, x10
    mov     x10, x13
3:  sub     x13, x10, x9
    cmp     x13, x12
    b.ne    4f
    ldr     x0, [sp, #32]
    NOUT
4:  lsl     x9, x9, x11
    add     x14, x0, x9
    mov     x6, #0
    cbz     x11, 6f
    mov     x15, #0
5:  cmp     x15, x13
    b.hs    6f
    ldrh    w16, [x14, x15, lsl #1]
    add     x15, x15, #1
    cmp     w16, #255
    b.ls    5b
    mov     x6, #1
6:  lsl     x0, x13, x6
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, n_full
    add     x8, x19, x0
    lsl     x9, x6, #32
    orr     x9, x9, x13
    str     x9, [x8], #8
    mov     x10, x14
    mov     x12, x11
    bl      s_copy
    orr     x0, x0, #(T_STRING << 48)
    NOUT
// 18 toUpperCase, 19 toLowerCase: English and western European letters, so far (not ÿ, ß, µ, nor anything past 255)
n_upper:
    mov     x2, #'a'
    b       1f
n_lower:
    mov     x2, #'A'
1:  NIN
    str     x2, [sp, #40]
    THISSTR
    and     x0, x0, #0xffffffffffff
    add     x14, x19, x0
    ldr     x11, [x14], #8
    and     x13, x11, #0xffffffff
    lsr     x12, x11, #32
    and     x12, x12, #1
    lsl     x0, x13, x12
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, n_full
    add     x8, x19, x0
    str     x11, [x8], #8
    ldr     x2, [sp, #40]
    mov     x15, #0
1:  cmp     x15, x13
    b.hs    9f
    cbz     x12, 2f
    ldrh    w16, [x14, x15, lsl #1]
    b       3f
2:  ldrb    w16, [x14, x15]
3:  sub     w17, w16, w2
    cmp     w17, #26
    b.lo    31f
    sub     w17, w17, #0x7f             // the accented letters of western Europe, 0xc0-0xde and 0xe0-0xfe, but not the
    cmp     w17, #31                    // multiplication and division signs among them
    b.hs    4f
    cmp     w17, #23
    b.eq    4f
31: eor     w16, w16, #32
4:  cbz     x12, 5f
    strh    w16, [x8, x15, lsl #1]
    b       6f
5:  strb    w16, [x8, x15]
6:  add     x15, x15, #1
    b       1b
9:  orr     x0, x0, #(T_STRING << 48)
    NOUT
    .balign 4
n_table:
    .word   n_maker - n_table, n_floor - n_table, n_ceil - n_table, n_abs - n_table, n_sqrt - n_table, n_round - n_table
    .word   n_trunc - n_table, n_sign - n_table, n_min - n_table, n_max - n_table, n_push - n_table, n_pop - n_table
    .word   n_isarray - n_table, n_keys - n_table, n_hasown - n_table, n_charcode - n_table, n_fromcc - n_table
    .word   n_substring - n_table, n_upper - n_table, n_lower - n_table, n_mexp - n_table, n_log - n_table
    .word   n_log2 - n_table, n_log10 - n_table, n_random - n_table, n_sin - n_table, n_cos - n_table, n_tan - n_table
    .word   n_undef - n_table, n_undef - n_table, n_jparse - n_table
    .word   n_atan - n_table, n_atan2 - n_table, n_asin - n_table, n_acos - n_table, n_expm1 - n_table, n_log1p - n_table
    .word   n_sinh - n_table, n_cosh - n_table, n_tanh - n_table, n_cbrt - n_table, n_hypot - n_table, n_ident - n_table
    .word   n_asinh - n_table, n_acosh - n_table, n_atanh - n_table, n_fround - n_table, n_clz32 - n_table, n_imul - n_table
    .equ    N_COUNT, 49
    .ltorg
