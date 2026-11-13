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
    cmp     x9, #59
    b.eq    m_resume
    cmp     x9, #29
    b.eq    m_fapply
    cmp     x9, #49                     // 49-51 take an array only (join: one with no objects in it): anything else
    b.lo    0f                          // goes to the prelude's function for it instead, by a turn of the call
    cmp     x9, #51
    b.hi    0f
    lsr     x8, x11, #48
    mov     w7, #T_OBJECT
    cmp     w8, w7
    b.ne    5f
    and     x8, x11, #0xffffffffffff
    add     x8, x19, x8
    ldr     x7, [x8]
    cmp     x7, #4
    b.ne    5f
    cmp     x9, #49
    b.ne    0f
    ldr     w7, [x8, #A_LEN]
    ldr     x8, [x8, #A_ITEMS]
    add     x8, x19, x8
6:  cbz     x7, 0f
    sub     x7, x7, #1
    ldr     x10, [x8, x7, lsl #3]
    lsr     x10, x10, #48
    mov     w14, #T_OBJECT
    cmp     w10, w14
    b.ne    6b
5:  sub     x8, x9, #49
    add     x8, x19, x8, lsl #3
    ldr     x8, [x8, #W_FALLBACK]
    cbz     x8, 0f
    str     x8, [x1, #-8]
    b       m_call
0:
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
m_tonum:                                // the same where a number is wanted: valueOf first, then toString
    mov     x7, #1
    b       0f
m_toprim:                               // (for +: first the object's own '@@toPrimitive', which a Date has; then as for a number)
    mov     x7, #2
0:  sub     x21, x21, #1
    and     x6, x5, #0xffffffffffff
    ldr     x6, [x19, x6]
    cmp     x6, #3
    b.ne    5f
1:  stp     x4, x5, [sp, #-32]!
    stp     x7, x8, [sp, #16]
    mov     x0, x5
    ldr     x1, [x19, #W_K_TOSTRING]
    ldr     x2, [x19, #W_K_VALUEOF]
    ldr     x3, [x19, #W_K_TOPRIM]
    cmp     x7, #1
    csel    x1, x1, x2, lo
    csel    x1, x1, x3, ls
    bl      o_get
    ldp     x7, x8, [sp, #16]
    ldp     x4, x5, [sp], #32
    TAGIS   x0, T_OBJECT
    b.ne    4f
    and     x6, x0, #0xffffffffffff
    ldr     x6, [x19, x6]
    cmp     x6, #1
    b.ne    4f
    sub     x12, x22, x4, lsl #3
    mov     x11, x5
    PUSH    x0
    mov     x1, x22
    mov     x0, #0
    add     x13, x4, #2
    b       m_call
4:  subs    x7, x7, #1                  // not a function: the next of the three is tried
    b.ge    1b
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
2:  cmp     x9, #8
    b.lo    21f
    cmp     x9, #13
    b.hi    4f
    cmp     x9, #11
    b.lo    22f
    ldr     x1, [sp, #24]               // -12, -13, -14: the prelude's three functions for kept calls
    ldr     x10, [x1, #8]
    cmp     x9, #13
    b.ne    23f
    str     x10, [x19, #W_GENFN3]
    b       n_undef
23: add     x9, x19, x9, lsl #3
    str     x10, [x9, #(W_GENFN - 88)]
    b       n_undef
22:
    ldr     x1, [sp, #24]
    ldr     x10, [x1, #8]
    add     x9, x19, x9, lsl #3
    str     x10, [x9, #(W_FALLBACK - 64)]
    b       n_undef
21: cmp     x9, #7
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
// 60 the program asks its host for something: the request (text) joins what the program has printed, W_WANT says where it
// begins, and the machine stops as if out of steps; the host reads it with `text`, answers with `text` (second number 1)
// and calls run again. 61 the answer (undefined if none was given), taken once.
n_host:
    NIN
    ldr     x1, [sp, #24]
    ldr     x0, [x1]
    bl      v_text
    cbz     x0, n_full
    ldr     x9, [x19, #W_OUT_LEN]
    add     x9, x9, #1
    str     x9, [x19, #W_WANT]
    str     xzr, [x19, #W_ANSWER]
    bl      w_outs
    mov     x25, #1
    b       n_undef
// 62: the global object (globalThis): made once; objects.S makes its properties the global variables
n_global:
    NIN
    ldr     x0, [x19, #W_GOBJ]
    cbnz    x0, 1f
    mov     x0, #32
    mov     x1, #3
    bl      o_make
    cbz     x0, n_full
    str     x0, [x19, #W_GOBJ]
1:  mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    NOUT
// 63: (object, name, getter, setter): the property becomes that pair (either may be undefined)
n_defacc:
    NIN
    ldr     x1, [sp, #24]
    ldr     x0, [x1]
    lsr     x9, x0, #48
    mov     w10, #T_OBJECT
    cmp     w9, w10
    b.ne    n_undef
    ldr     x0, [x1, #8]
    bl      v_text
    cbz     x0, n_full
    str     x0, [sp, #40]
    mov     x0, #16
    bl      w_alloc
    cbz     x0, n_full
    add     x9, x19, x0
    ldr     x1, [sp, #24]
    ldp     x10, x11, [x1, #16]
    stp     x10, x11, [x9]
    mov     x16, #(T_ACC << 48)
    orr     x2, x0, x16
    ldr     x0, [x1]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x1, [sp, #40]
    bl      o_put
    cbz     x0, n_full
    b       n_undef
// 64: what an object inherits from (null for anything else). 65: (object, an object or null): it inherits from that now
// 67 (getter, setter): a proxy (kind 7). Any property read or written on it reaches the getter or setter, which find the
// name with 68. 32: the getter, 40: the setter (the pair a T_ACC value points at)
n_proxy:
    stp     x30, x1, [sp, #-16]!
    mov     x0, #48
    bl      w_alloc
    ldp     x30, x1, [sp], #16
    cbz     x0, n_full
    add     x9, x19, x0
    mov     x10, #7
    VAL     x11, T_NULL
    stp     x10, x11, [x9]
    stp     xzr, xzr, [x9, #16]
    ldp     x10, x11, [x1]
    stp     x10, x11, [x9, #32]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    ret
n_pkey:
    ldr     x0, [x19, #W_PKEY]
    ret
n_getproto:
    ldr     x0, [x1]
    lsr     x9, x0, #48
    mov     w10, #T_OBJECT
    cmp     w9, w10
    b.ne    1f
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x0, [x0, #O_PROTO]
    ret
1:  VAL     x0, T_NULL
    ret
n_setproto:
    ldp     x0, x2, [x1]
    lsr     x9, x0, #48
    mov     w10, #T_OBJECT
    cmp     w9, w10
    b.ne    1f
    lsr     x9, x2, #48
    cmp     w9, w10
    b.eq    2f
    mov     w10, #T_NULL
    cmp     w9, w10
    b.ne    1f
2:  and     x9, x0, #0xffffffffffff
    add     x9, x19, x9
    str     x2, [x9, #O_PROTO]
1:  ret
n_reply:
    ldr     x0, [x19, #W_ANSWER]
    str     xzr, [x19, #W_ANSWER]
    cbnz    x0, 1f
    VAL     x0, T_UNDEF
1:  ret
// 66: an error is being made here: where the statement last begun is becomes the place errors are reported at, and is
// given back as line * 2^32 + column (a number)
n_markerr:
    ldr     x9, [x19, #W_POS]
    str     x9, [x19, #W_ERR_LINE]
    lsr     x10, x9, #32
    and     x9, x9, #0xffffffff
    orr     x9, x10, x9, lsl #32
    ucvtf   d0, x9
    fmov    x0, d0
    ret
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
// 49 join. m_native has seen that `this` is an array with no object in it. Two passes: a copy of the array has each item
// made text (0 for undefined and null) while the units are counted, then one string of that size is filled.
// Beyond the frame: 0 how far, 8 units in all, 16 whether any is wide; 64 the copy, 72 the text between.
n_join:
    NIN
    sub     sp, sp, #32
    ldr     x1, [sp, #56]
    ldr     x0, [x1]
    TAGIS   x0, T_UNDEF
    b.ne    1f
    mov     w0, #','
    bl      w_unit
    b       2f
1:  bl      v_text
2:  cbz     x0, n_full
    str     x0, [sp, #72]
    ldr     x9, [sp, #64]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     w1, [x9, #A_LEN]
    ldr     x0, [x9, #A_ITEMS]
    add     x0, x19, x0
    bl      a_from
    cbz     x0, n_full
    str     x0, [sp, #64]
    stp     xzr, xzr, [sp]
    str     xzr, [sp, #16]
3:  ldr     x9, [sp, #64]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     w12, [x9, #A_LEN]
    ldr     x11, [sp]
    cmp     x11, x12
    b.hs    6f
    ldr     x13, [x9, #A_ITEMS]
    add     x13, x19, x13
    ldr     x0, [x13, x11, lsl #3]
    lsr     x14, x0, #48
    mov     w15, #T_UNDEF
    cmp     w14, w15
    b.eq    4f
    mov     w15, #T_NULL
    cmp     w14, w15
    b.eq    4f
    bl      v_text
    cbz     x0, n_full
    b       5f
4:  mov     x0, #0
5:  ldr     x9, [sp, #64]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     x13, [x9, #A_ITEMS]
    add     x13, x19, x13
    ldr     x11, [sp]
    str     x0, [x13, x11, lsl #3]
    add     x11, x11, #1
    str     x11, [sp]
    cbz     x0, 3b
    and     x0, x0, #0xffffffffffff
    ldr     x10, [x19, x0]
    ldp     x14, x15, [sp, #8]
    add     x14, x14, w10, uxtw
    orr     x15, x15, x10, lsr #32
    stp     x14, x15, [sp, #8]
    b       3b
6:  ldr     x5, [sp, #72]
    and     x5, x5, #0xffffffffffff
    ldr     x4, [x19, x5]
    ldp     x14, x6, [sp, #8]
    cbz     x12, 7f
    sub     x9, x12, #1
    and     x10, x4, #0xffffffff
    madd    x14, x9, x10, x14
    orr     x6, x6, x4, lsr #32
7:  and     x6, x6, #1
    stp     x14, x6, [sp, #8]
    lsl     x0, x14, x6
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, n_full
    mov     x7, x0
    ldp     x14, x6, [sp, #8]
    add     x8, x19, x0
    orr     x9, x14, x6, lsl #32
    str     x9, [x8], #8
    ldr     x9, [sp, #64]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     w16, [x9, #A_LEN]
    ldr     x17, [x9, #A_ITEMS]
    add     x17, x19, x17
    ldr     x5, [sp, #72]
    and     x5, x5, #0xffffffffffff
    add     x5, x19, x5
    ldr     x4, [x5], #8
    mov     x15, #0
8:  cmp     x15, x16
    b.hs    9f
    cbz     x15, 81f
    mov     x10, x5
    and     x13, x4, #0xffffffff
    lsr     x12, x4, #32
    and     x12, x12, #1
    bl      s_copy
81: ldr     x0, [x17, x15, lsl #3]
    add     x15, x15, #1
    cbz     x0, 8b
    and     x0, x0, #0xffffffffffff
    add     x10, x19, x0
    ldr     x9, [x10], #8
    and     x13, x9, #0xffffffff
    lsr     x12, x9, #32
    and     x12, x12, #1
    bl      s_copy
    b       8b
9:  orr     x0, x7, #(T_STRING << 48)
    add     sp, sp, #32
    NOUT
// 50 indexOf (of an array): the same bits are the same value unless they are the number that is not one; other pairs go
// to v_strict
n_aindexof:
    NIN
    ARGNUM  1
    fcvtzs  x11, d0
    bl      n_arr
    ldr     w12, [x9, #A_LEN]
    cmp     x11, #0
    b.ge    1f
    adds    x11, x11, x12
    csel    x11, xzr, x11, mi
1:  str     x11, [sp, #40]
    bl      n_arr
    ldr     w12, [x9, #A_LEN]
    ldr     x11, [sp, #40]
    cmp     x11, x12
    b.hs    8f
    ldr     x13, [x9, #A_ITEMS]
    add     x13, x19, x13
    ldr     x0, [x13, x11, lsl #3]
    ldr     x1, [sp, #24]
    ldr     x1, [x1]
    cmp     x0, x1
    b.ne    2f
    lsr     x14, x0, #48
    mov     w15, #T_UNDEF
    cmp     w14, w15
    b.hs    7f
    fmov    d0, x0
    fcmp    d0, d0
    b.vc    7f
    b       3f
2:  bl      v_strict
    cbnz    w0, 7f
3:  ldr     x11, [sp, #40]
    add     x11, x11, #1
    b       1b
7:  ldr     x11, [sp, #40]
    scvtf   d0, x11
    b       n_num
8:  fmov    d0, #-1.0
    b       n_num
// 51 slice (of an array)
n_aslice:
    NIN
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
2:  mov     x11, x10
    ldr     x12, [sp, #40]
    bl      n_arr
    ldr     w13, [x9, #A_LEN]
    cmp     x12, #0
    b.ge    3f
    adds    x12, x12, x13
    csel    x12, xzr, x12, mi
3:  cmp     x12, x13
    csel    x12, x13, x12, gt
    cmp     x11, #0
    b.ge    4f
    adds    x11, x11, x13
    csel    x11, xzr, x11, mi
4:  cmp     x11, x13
    csel    x11, x13, x11, gt
    subs    x1, x11, x12
    csel    x1, xzr, x1, lt
    ldr     x0, [x9, #A_ITEMS]
    add     x0, x19, x0
    add     x0, x0, x12, lsl #3
    bl      a_from
    cbz     x0, n_full
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
// 69 __compile [by Opus]: (text) the text, one function expression in parentheses, is translated now, while the program runs,
// after the instructions already there -> the function, whose scope is the global one (as `new Function` makes). A text that
// does not translate throws its SyntaxError. The translator uses x20-x28 for itself: they are the machine's, kept here.
n_compile:
    NIN
    ldr     x1, [sp, #24]
    ldr     x0, [x1]
    bl      v_text
    cbz     x0, n_full
    and     x9, x0, #0xffffffffffff
    add     x9, x19, x9
    ldr     x10, [x9], #8
    mov     x12, #0                     // [by Opus] text past ASCII is made UTF-8 first (the reader reads UTF-8), in a block kept at 88
    lsr     x2, x10, #32
    and     x10, x10, #0xffffffff
    cbnz    x2, 2f
    mov     x3, #0
1:  cmp     x3, x10
    b.hs    3f
    ldrb    w4, [x9, x3]
    add     x3, x3, #1
    cmp     w4, #0x80
    b.lo    1b
2:  stp     x9, x10, [sp, #-16]!
    add     x0, x10, x10, lsl #1
    add     x0, x0, #8
    bl      w_alloc
    ldp     x1, x11, [sp], #16
    cbz     x0, n_full
    mov     x12, x0
    ldr     x2, [x1, #-8]
    lsr     x2, x2, #32
    mov     x0, x1
    mov     x1, x11
    add     x11, x11, x11, lsl #1
    add     x9, x19, x12
    mov     x10, #0
    str     x12, [sp, #-16]!
    bl      w_enc
    ldr     x12, [sp], #16
    add     x9, x19, x12
3:  stp     x19, x20, [sp, #-96]!
    str     x12, [sp, #88]
    stp     x21, x22, [sp, #16]
    stp     x23, x24, [sp, #32]
    stp     x25, x26, [sp, #48]
    stp     x27, x28, [sp, #64]
    ldr     w11, [x19, #W_STATE]
    str     x11, [sp, #80]
    add     x0, x22, #64                // names kept above the values in use
    mov     x20, x9
    mov     x21, x10
    bl      c_fragment
    ldr     x11, [sp, #80]
    str     w11, [x19, #W_STATE]
    ldp     x21, x22, [sp, #16]
    ldp     x23, x24, [sp, #32]
    ldp     x25, x26, [sp, #48]
    ldp     x27, x28, [sp, #64]
    ldp     x19, x20, [sp], #96
    cmn     x0, #1
    b.eq    7f
    mov     x4, x0
    mov     x0, #64
    mov     x1, #1
    bl      o_make
    cbz     x0, n_full
    add     x9, x19, x0
    and     x1, x4, #0xffffffffffff
    stp     x1, xzr, [x9, #F_PLAN]
    VAL     x10, T_UNDEF
    str     x10, [x9, #F_THIS]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    NOUT
7:  ldr     x0, [x19, #W_ERR]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x1, [x0], #8
    and     x1, x1, #0xffffffff
    b       n_fail
8:  adr     x0, n_m_wide
    mov     x1, #(n_m_wide_end - n_m_wide)
    b       n_fail
n_m_wide:   .ascii "SyntaxError: new Function with text beyond one byte per unit is not made yet"
n_m_wide_end:
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
    .word   n_join - n_table, n_aindexof - n_table, n_aslice - n_table, n_rxcompile - n_table, n_rxexec - n_table
    .word   n_now - n_table, n_dayfrom - n_table, n_civil - n_table, n_setclock - n_table, n_setwake - n_table, n_undef - n_table
    .word   n_host - n_table, n_reply - n_table, n_global - n_table
    .word   n_defacc - n_table, n_getproto - n_table, n_setproto - n_table, n_markerr - n_table
    .word   n_proxy - n_table, n_pkey - n_table, n_compile - n_table
    .equ    N_COUNT, 70
    .ltorg
