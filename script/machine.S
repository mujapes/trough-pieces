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
    .equ OP_GETL, 43                    // + 16 bits: which of the running function's variables
    .equ OP_SETL, 44
    .equ OP_GETUP, 45                   // + 8 bits: how many scopes out, + 16 bits: which variable there
    .equ OP_SETUP, 46
    .equ OP_CLOSURE, 47                 // + 16 bits: which constant (a function's plan): a function that remembers this scope
    .equ OP_CALL, 48                    // + 8 bits: how many arguments; under them on the stack, the function
    .equ OP_RET, 49                     // the top value is the call's answer
    .equ OP_CALLEE, 50                  // the function that is running
    .equ OP_OBJECT, 51                  // the instructions from here to OP_DUP2 are described in objects.S
    .equ OP_ARRAY, 52
    .equ OP_GETP, 53
    .equ OP_SETP, 54
    .equ OP_GETE, 55
    .equ OP_SETE, 56
    .equ OP_INITP, 57
    .equ OP_INITE, 58
    .equ OP_GETEK, 59
    .equ OP_CALLM, 60
    .equ OP_NEW, 61
    .equ OP_THIS, 62
    .equ OP_SWAP, 63
    .equ OP_ROT, 64
    .equ OP_PICK, 65
    .equ OP_DUP2, 66
    .equ OP_IN, 67
    .equ OP_INSTOF, 68
    .equ OP_DELP, 69
    .equ OP_DELE, 70
    .equ OP_KEYS, 71
    .equ OP_ITER, 72
    .equ OP_FORNEXT, 73
    .equ OP_APPEND, 74                  // array, value -> array with the value added at its end
    .equ OP_SPREAD, 75                  // array, array or string -> array with each of its items added
    .equ OP_APPLY, 76                   // + 8 bits: which call (0 plain, 1 on an object, 2 new, 3 print); the array on top is its arguments
    .equ OP_TAIL, 77                    // + 16 bits: from which item. array or string -> a new array of the items from there on
    .equ OP_DEFACC, 78                  // + 8 bits: 0 a getter, 1 a setter. object, key, function -> object
    .equ OP_EXTENDS, 79                 // parent, class -> class, its chains linked to the parent's
    .equ OP_HOME, 80                    // object, key, function: the function remembers the object as its home (for super)
    .equ OP_SUPER, 81                   // + 16 bits: a name: that property, looked for from the home's prototype on; 0xffff: the parent class
    .equ OP_TRY, 82                     // + 32 bits: where a throw lands. Five places go on the stack: that, the call's record, variables and scope, the try before
    .equ OP_ENDTRY, 83                  // the newest try is over: its record goes (and anything above it)
    .equ OP_ENDTRYK, 84                 // the same, keeping the top value
    .equ OP_THROW, 85                   // the top value is thrown
    .equ OP_GOSUB, 86                   // + 32 bits: goes there, leaving on the stack where to come back to (a finally)
    .equ OP_RETSUB, 87                  // comes back
    .equ OP_GETGQ, 88                   // + 16 bits: a global read that does not mind the name never having been declared (typeof)
    .equ OP_SCOPE, 89                   // + 16 bits: how many variables: a block's own scope begins, inside the one before
    .equ OP_UNSCOPE, 90                 // and ends
    .equ OP_COPYSCOPE, 91               // + 16 bits: how many: the scope is exchanged for a copy of itself (a loop's next turn)
    .equ OP_CONSTGET, 92                // + 16 bits (not used): stands where a const would be read to be assigned to: undefined
    .equ OP_CONSTERR, 93                // + 16 bits (not used): the assignment itself: TypeError
    .equ OP_GENSNAP, 94                 // + 8 bits (0 a generator, 1 an async function), then OP_RET: the call as it stands is kept aside, and what the prelude makes of it is the call's answer
    .equ OP_YIELD, 95                   // value -> (when resumed) the value sent in: the call is kept aside again and the value is the resuming call's answer
    .equ OP_LINE, 96                    // + 32 bits line, 32 bits column: where in the text the statement that follows began (kept for an error)
    .equ OP_SUPERTHIS, 97               // [by Opus] after super(..): the answer, if an object, becomes this call's `this` (stays on the stack)
    .equ OP_TOTEXT, 98                  // [by Opus] value -> the same, but an object becomes a primitive by toString first (a template's value)
    .equ OP_COUNT, 99
// In the heap, an object begins with its kind: 1 a function (then: its plan, the scope it remembers), 2 a function's plan
// (then: where its instructions start, parameters (32 bits) and variables in all (32 bits), flags (1: its variables live in
// the heap because inner functions may keep them), its name).
// A call's record on the stack, eight places: where to go back to, the caller's variables, scope and record, where the
// answer goes, the call's `this`, the function itself, and whether it was called by `new`. While running: x20 the record, x27 the variables, x28 the scope.
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
6:  and     x1, x0, #0xffffffffffff
    ldr     x1, [x19, x1]
    cmp     x1, #4
    b.ne    61f
    bl      a_text                      // an array: its items' texts, commas between
    b       9f
61: LIT     s_objtext, s_end
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
s_symbol:    .ascii "symbol"
s_symbol_end:
s_bigint:    .ascii "bigint"
s_bigint_end:
    .balign 4
// v_join: the two string values x0 and x1 as one string -> x0 (0 if the world is full)
v_join:
    stp     x29, x30, [sp, #-32]!
    stp     x0, x1, [sp, #16]
    and     x2, x0, #0xffffffffffff
    ldr     x2, [x19, x2]
    and     x4, x1, #0xffffffffffff
    ldr     x4, [x19, x4]
    and     x3, x2, #0xffffffff
    and     x5, x4, #0xffffffff
    orr     x6, x2, x4
    lsr     x6, x6, #32                 // wide if either is
    add     x7, x3, x5
    lsl     x0, x7, x6
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, 9f
    add     x8, x19, x0
    orr     x9, x7, x6, lsl #32
    str     x9, [x8], #8
    ldp     x10, x11, [sp, #16]
    and     x10, x10, #0xffffffffffff
    add     x10, x19, x10
    add     x10, x10, #8
    lsr     x12, x2, #32
    mov     x13, x3
    bl      s_copy
    and     x10, x11, #0xffffffffffff
    add     x10, x19, x10
    add     x10, x10, #8
    lsr     x12, x4, #32
    mov     x13, x5
    bl      s_copy
    orr     x0, x0, #(T_STRING << 48)
9:  ldp     x29, x30, [sp], #32
    ret
// v_int32: the number d0 as the language's 32-bit whole number (wrapping round) -> w0
v_int32:
    fabs    d1, d0
    ldr     x0, =0x43e0000000000000     // 2 to the 63: below it the plain conversion is exact
    fmov    d2, x0
    fcmp    d1, d2
    b.pl    1f                          // not below (or not a number)
    fcvtzs  x0, d0
    ret
1:  fmov    x1, d0                      // huge: the low 32 bits of the whole number, worked out from the number's own bits
    ubfx    x2, x1, #52, #11
    mov     w0, #0
    cmp     x2, #0x7ff                  // infinite or not a number: 0
    b.eq    2f
    sub     x2, x2, #1075               // how far the 53 digits are moved up
    cmp     x2, #32
    b.hs    2f                          // all of them above the low 32
    and     x3, x1, #0xfffffffffffff
    orr     x3, x3, #0x10000000000000
    lsl     x3, x3, x2
    cmp     x1, #0
    cneg    w0, w3, lt
2:  ret
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
    ldp     x20, x27, [x19, #W_FP]
    add     x20, x19, x20
    add     x27, x19, x27
    ldr     x28, [x19, #W_ENV]
    ldr     x9, [x19, #W_K_LENGTH]
    cbnz    x9, m_next
    bl      m_keys
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
    sub     x9, x20, x19
    sub     x10, x27, x19
    stp     x9, x10, [x19, #W_FP]
    str     x28, [x19, #W_ENV]
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
// m_notfn_v: the value x2 was called: the error says what kind of value it was ("TypeError: undefined is not a function").
// m_notfn_o: the same for an object that is not a function.
m_notfn_o:
    sub     x9, x2, x19                 // [by Opus] where the called object lies, kept for a host's fault finding (W_BADCALL)
    str     x9, [x19, #824]
    adr     x0, e_nf_object
    mov     x1, #(e_nf_end - e_nf_object)
    b       m_fail
m_notfn_v:
    lsr     x3, x2, #48
    adr     x0, e_nf_number
    mov     x1, #(e_nf_undef - e_nf_number)
    mov     w16, #T_UNDEF
    cmp     w3, w16
    b.lo    m_fail
    adr     x0, e_nf_undef
    mov     x1, #(e_nf_null - e_nf_undef)
    b.eq    m_fail
    adr     x0, e_nf_null
    mov     x1, #(e_nf_bool - e_nf_null)
    mov     w16, #T_NULL
    cmp     w3, w16
    b.eq    m_fail
    adr     x0, e_nf_bool
    mov     x1, #(e_nf_string - e_nf_bool)
    mov     w16, #T_BOOL
    cmp     w3, w16
    b.eq    m_fail
    adr     x0, e_nf_string
    mov     x1, #(e_nf_object - e_nf_string)
    mov     w16, #T_STRING
    cmp     w3, w16
    b.eq    m_fail
    b       m_notfn
e_nf_number: .ascii "TypeError: a number is not a function"
e_nf_undef:  .ascii "TypeError: undefined is not a function"
e_nf_null:   .ascii "TypeError: null is not a function"
e_nf_bool:   .ascii "TypeError: a boolean is not a function"
e_nf_string: .ascii "TypeError: a string is not a function"
e_nf_object: .ascii "TypeError: an object is not a function"
e_nf_end:
    .balign 4
m_notfn:
    adr     x0, e_notfn
    mov     x1, #(e_notfn_end - e_notfn)
    b       m_fail
m_wrong:
    adr     x0, e_wrong
    mov     x1, #(e_wrong_end - e_wrong)
// m_fail: the machine's own error, given as "Name: message" (x0, x1 bytes). Inside a try it is thrown as an object of that
// class (looked up among the globals by name; the text itself if there is none); otherwise the program stops with it.
m_fail:
    ldr     x9, [x19, #W_POS]           // where it happened: the statement last begun
    str     x9, [x19, #W_ERR_LINE]
    bl      m_trail
    ldr     x9, [x19, #W_HANDLER]
    cbz     x9, m_fatal
    mov     x23, x0
    mov     x24, x1
    mov     x9, #0
1:  cmp     x9, x24
    b.hs    7f
    ldrb    w10, [x23, x9]
    cmp     w10, #':'
    b.eq    2f
    add     x9, x9, #1
    b       1b
2:  str     x9, [sp, #-16]!
    add     x9, x9, #2
    add     x0, x23, x9
    sub     x1, x24, x9
    bl      w_string
    ldr     x1, [sp], #16
    cbz     x0, 7f
    str     x0, [sp, #-16]!
    mov     x0, x23
    bl      w_string
    ldr     x1, [sp], #16
    cbnz    x0, m_raise
7:  mov     x0, x23
    mov     x1, x24
    bl      w_string
    cbnz    x0, 8f
    adr     x0, e_full
    mov     x1, #(e_wrong - e_full)
    b       m_fatal
// m_trail: the call trail is kept (W_TRAIL): where the statement last begun is, then where each call record still open was
// called from, newest first, 16 at most. Uses x9-x12 only (callable with anything else live, from m_fail and from lib.S).
m_trail:
    ldr     x9, [x19, #W_POS]
    str     x9, [x19, #W_TRAIL]
    mov     x10, #1
    mov     x11, x20
1:  cmp     x10, #16
    b.hs    9f
    sub     x12, x11, x19               // a record is above the world's header and below the stack's top
    cmp     x12, #800
    b.lo    9f
    cmp     x11, x22
    b.hs    9f
    ldr     x9, [x11, #56]
    ubfx    x12, x9, #4, #20
    cbz     x12, 9f
    and     x9, x9, #0xffffffffff000000
    orr     x12, x12, x9
    add     x9, x19, #W_TRAIL
    str     x12, [x9, x10, lsl #3]
    add     x10, x10, #1
    ldr     x12, [x11, #24]             // the record of the call around it
    add     x12, x19, x12
    cmp     x12, x11
    b.hs    9f
    mov     x11, x12
    b       1b
9:  str     x10, [x19, #W_TRAILN]
    ret
// m_raise: an error of the class named x0 with the message x1 (string values) is thrown: an object whose prototype is that
// class's (the class is looked up among the globals; the message alone is thrown if it is not there)
m_raise:
    bl      m_trail                     // (x30 is not needed here: m_raise ends by throwing)
    stp     x0, x1, [sp, #-32]!         // 0 the name then the prototype, 8 the message, 16 the object
    mov     x1, x0
    ldr     x10, [x19, #W_GLOB]
    add     x10, x19, x10
    ldr     x11, [x19, #W_GLOB_N]
3:  cbz     x11, 6f
    ldr     x2, [x10]
    bl      o_keyeq
    b.eq    4f
    add     x10, x10, #16
    sub     x11, x11, #1
    b       3b
4:  ldr     x0, [x10, #8]
    lsr     x9, x0, #48
    mov     w16, #T_OBJECT
    cmp     w9, w16
    b.ne    6f
    and     x9, x0, #0xffffffffffff
    ldr     x9, [x19, x9]
    cmp     x9, #1
    b.ne    6f
    bl      m_fnproto
    cbz     x0, 6f
    str     x0, [sp]
    mov     x0, #32
    mov     x1, #3
    bl      o_make
    cbz     x0, 6f
    str     x0, [sp, #16]
    ldr     x9, [sp]
    add     x10, x19, x0
    str     x9, [x10, #O_PROTO]
    LIT     k_message, k_colon
    cbz     x0, 6f
    mov     x1, x0
    ldr     x2, [sp, #8]
    ldr     x0, [sp, #16]
    add     x0, x19, x0
    bl      o_put
    cbz     x0, 6f
    ldr     x0, [sp, #16]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    add     sp, sp, #32
    b       8f
6:  ldr     x0, [sp, #8]
    add     sp, sp, #32
8:  ldr     x23, [x19, #W_CONST]
    add     x23, x19, x23
    ldr     x24, [x19, #W_GLOB]
    add     x24, x19, x24
// m_throw: the value x0 is thrown: the newest try's record says where to go on and what the machine was like there
m_throw:
    ldr     x9, [x19, #W_HANDLER]
    cbz     x9, m_uncaught
    add     x9, x19, x9
    ldp     x10, x11, [x9, #-40]
    ldp     x12, x28, [x9, #-24]
    ldr     x13, [x9, #-8]
    str     x13, [x19, #W_HANDLER]
    sub     x22, x9, #40
    add     x20, x19, x11
    add     x27, x19, x12
    ldr     x9, [x19, #W_CODE]
    add     x21, x19, x9
    add     x21, x21, x10
    str     x0, [x22], #8
    NEXT
// nothing caught it: the program stops; the error's text is "Uncaught " and the value (an error object as Name: message)
m_uncaught:
    mov     x23, x0
    TAGIS   x0, T_OBJECT
    b.ne    2f
    LIT     k_name, k_message
    cbz     x0, 2f
    mov     x1, x0
    mov     x0, x23
    bl      o_get
    TAGIS   x0, T_STRING
    b.ne    2f
    mov     x24, x0
    LIT     k_colon, k_uncaught
    cbz     x0, 2f
    mov     x1, x0
    mov     x0, x24
    bl      v_join
    cbz     x0, 2f
    mov     x24, x0
    LIT     k_message, k_colon
    cbz     x0, 2f
    mov     x1, x0
    mov     x0, x23
    bl      o_get
    bl      v_text
    cbz     x0, 2f
    mov     x1, x0
    mov     x0, x24
    bl      v_join
    b       3f
2:  mov     x0, x23
    bl      v_text
3:  mov     x24, x0
    LIT     k_uncaught, k_uncaught_end
    mov     x1, x24
    cbz     x0, 4f
    cbz     x1, 4f
    bl      v_join
4:  str     x0, [x19, #W_ERR]
    mov     w9, #3
    str     w9, [x19, #W_STATE]
    mov     x0, #-1
    b       m_leave
k_name:     .ascii "name"
k_message:  .ascii "message"
k_colon:    .ascii ": "
k_uncaught: .ascii "Uncaught "
k_uncaught_end:
    .balign 4
i_try:
    ldrsw   x0, [x21], #4
    add     x0, x21, x0
    ldr     x9, [x19, #W_CODE]
    add     x9, x19, x9
    sub     x0, x0, x9
    add     x9, x22, #40
    cmp     x9, x26
    b.hi    m_deep
    sub     x10, x20, x19
    stp     x0, x10, [x22]
    sub     x10, x27, x19
    stp     x10, x28, [x22, #16]
    ldr     x10, [x19, #W_HANDLER]
    str     x10, [x22, #32]
    mov     x22, x9
    sub     x9, x9, x19
    str     x9, [x19, #W_HANDLER]
    NEXT
i_endtry:
    ldr     x9, [x19, #W_HANDLER]
    add     x9, x19, x9
    ldr     x10, [x9, #-8]
    str     x10, [x19, #W_HANDLER]
    sub     x22, x9, #40
    NEXT
i_endtryk:
    ldr     x0, [x22, #-8]
    ldr     x9, [x19, #W_HANDLER]
    add     x9, x19, x9
    ldr     x10, [x9, #-8]
    str     x10, [x19, #W_HANDLER]
    sub     x22, x9, #40
    str     x0, [x22], #8
    NEXT
i_throw:                                // (an object keeps the place it was made at, so a rethrow reports the cause)
    ldr     x0, [x22, #-8]
    TAGIS   x0, T_OBJECT
    b.eq    1f
    ldr     x9, [x19, #W_POS]
    str     x9, [x19, #W_ERR_LINE]
1:  POP     x0
    b       m_throw
i_gosub:
    ldrsw   x0, [x21], #4
    ldr     x9, [x19, #W_CODE]
    add     x9, x19, x9
    sub     x9, x21, x9
    add     x21, x21, x0
    PUSH    x9
    NEXT
i_retsub:
    POP     x9
    ldr     x10, [x19, #W_CODE]
    add     x21, x19, x10
    add     x21, x21, x9
    NEXT
m_fatal:
    bl      w_string
    cbnz    x0, 1f
    ldr     x0, [x19, #W_K_FULL]        // no room even for the error's text: the one made at the start
1:  str     x0, [x19, #W_ERR]
    mov     w9, #3
    str     w9, [x19, #W_STATE]
    mov     x0, #-1
    b       m_leave
e_deep:  .ascii "RangeError: the stack is full"
e_full:  .ascii "RangeError: the world is full"
e_wrong: .ascii "InternalError: an instruction the machine does not know"
e_wrong_end:
e_notfn: .ascii "TypeError: not a function"
e_notfn_end:
s_function: .ascii "function"
s_function_end:
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
    lsr     x9, x0, #48
    mov     w10, #T_HOLE
    cmp     w9, w10
    b.eq    1f
    PUSH    x0
    NEXT
1:  ldr     x23, [x1]                   // a name nothing ever declared or stored to
    LIT     e_notdef, e_notdef_end
    cbz     x0, m_full
    mov     x1, x0
    mov     x0, x23
    bl      v_join
    cbz     x0, m_full
    mov     x23, x0
    LIT     e_referr, e_notdef
    cbz     x0, m_full
    mov     x1, x23
    b       m_raise
e_referr: .ascii "ReferenceError"
e_notdef: .ascii " is not defined"
e_notdef_end:
    .balign 4
i_scope:
    U16     w4
    add     x0, x4, #1
    lsl     x0, x0, #3
    bl      w_alloc
    cbz     x0, m_full
    add     x9, x19, x0
    str     x28, [x9], #8
    VAL     x10, T_UNDEF
1:  cbz     x4, 2f
    str     x10, [x9], #8
    sub     x4, x4, #1
    b       1b
2:  mov     x28, x0
    NEXT
i_unscope:
    ldr     x28, [x19, x28]
    NEXT
i_copyscope:
    U16     w4
    add     x0, x4, #1
    lsl     x0, x0, #3
    bl      w_alloc
    cbz     x0, m_full
    add     x9, x19, x0
    add     x10, x19, x28
    add     x4, x4, #1
1:  ldr     x11, [x10], #8
    str     x11, [x9], #8
    subs    x4, x4, #1
    b.ne    1b
    mov     x28, x0
    NEXT
i_constget:
    add     x21, x21, #2
    VAL     x0, T_UNDEF
    PUSH    x0
    NEXT
i_consterr:
    adr     x0, e_const
    mov     x1, #(e_const_end - e_const)
    b       m_fail
e_const: .ascii "TypeError: Assignment to constant variable."
e_const_end:
    .balign 4
i_getgq:                                // the same read under typeof, where such a name is just undefined
    U16     w0
    add     x1, x24, x0, lsl #4
    ldr     x0, [x1, #8]
    lsr     x9, x0, #48
    mov     w10, #T_HOLE
    cmp     w9, w10
    b.ne    1f
    VAL     x0, T_UNDEF
1:  PUSH    x0
    NEXT
i_setg:
    U16     w0
    add     x1, x24, x0, lsl #4
    ldr     x0, [x22, #-8]
    str     x0, [x1, #8]
    NEXT
i_line:
    ldr     x0, [x21], #8
    str     x0, [x19, #W_POS]
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
    ldp     x0, x1, [x22, #-16]         // (an object first by its own valueOf or toString: the instruction runs again)
    mov     w16, #T_OBJECT
    mov     x4, #1
    mov     x5, x1
    lsr     x2, x1, #48
    cmp     w2, w16
    b.eq    m_tonum
    mov     x4, #2
    mov     x5, x0
    lsr     x2, x0, #48
    cmp     w2, w16
    b.eq    m_tonum
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
1:  mov     w16, #T_OBJECT              // an object on either side first becomes text, by its own toString if it has one
    mov     x4, #1
    cmp     w3, w16
    csel    x5, x1, x0, eq
    b.eq    m_toprim
    mov     x4, #2
    cmp     w2, w16
    b.eq    m_toprim
    mov     w16, #T_STRING              // text on either side: both become text and are joined
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
    ldr     x0, =0x4340000000000000     // a quotient of 2 to the 53 or more cannot be held whole: long division instead
    fmov    d7, x0
    fcmp    d5, d7
    b.lt    3f
    bl      m_fmod
    b       2f
3:  frintz  d5, d5
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
// m_fmod: the remainder of d2 by d3 (both above zero and finite, d2 not the smaller) -> d6, exact whatever their sizes:
// the digits of one are taken from the other a binary place at a time. Uses x0-x6.
m_fmod:
    fmov    x0, d2
    fmov    x1, d3
    ubfx    x2, x0, #52, #11
    ubfx    x3, x1, #52, #11
    and     x4, x0, #0xfffffffffffff
    and     x5, x1, #0xfffffffffffff
    cbz     x2, 1f
    orr     x4, x4, #0x10000000000000
    b       2f
1:  mov     x2, #1                      // below the smallest ordinary number: its digits are moved up to the usual place
11: tbnz    x4, #52, 2f
    lsl     x4, x4, #1
    sub     x2, x2, #1
    b       11b
2:  cbz     x3, 3f
    orr     x5, x5, #0x10000000000000
    b       4f
3:  mov     x3, #1
31: tbnz    x5, #52, 4f
    lsl     x5, x5, #1
    sub     x3, x3, #1
    b       31b
4:  cmp     x2, x3
    b.le    6f
    cmp     x4, x5
    b.lo    5f
    sub     x4, x4, x5
5:  lsl     x4, x4, #1
    sub     x2, x2, #1
    b       4b
6:  cmp     x4, x5
    b.lo    7f
    sub     x4, x4, x5
7:  cbz     x4, 9f
8:  tbnz    x4, #52, 10f
    cmp     x3, #1
    b.le    12f
    lsl     x4, x4, #1
    sub     x3, x3, #1
    b       8b
10: cmp     x3, #1
    b.lt    12f
    and     x4, x4, #0xfffffffffffff
    orr     x4, x4, x3, lsl #52
    fmov    d6, x4
    ret
12: mov     x6, #1                      // the answer is below the smallest ordinary number
    sub     x6, x6, x3
    lsr     x4, x4, x6
    fmov    d6, x4
    ret
9:  fmov    d6, xzr
    ret
i_pow:                                  // whole powers by repeated squaring; others are to come with the Math library
    TWO
    frintz  d2, d0
    fcmp    d2, d0
    b.ne    8f
    fabs    d3, d0
    ldr     x0, =0x43e0000000000000     // 2 to the 63 and beyond: every such number is even, and as good as endless
    fmov    d6, x0
    fcmp    d3, d6
    mov     x0, #0x4000000000000000
    b.lt    1f
    ldr     x1, =0x7ff0000000000000     // 1 or -1 to an infinite power is not a number
    fmov    d6, x1
    fcmp    d3, d6
    b.ne    2f
    fabs    d6, d1
    fmov    d7, #1.0
    fcmp    d6, d7
    b.eq    8f
    b       2f
1:  fcvtzu  x0, d3
2:  mov     x6, x0
    ldr     x1, =0x7ff0000000000000
    fmov    d21, x1
    fmov    d5, d1
    fmov    d16, xzr
    bl      m_powloop
    fcmp    d0, #0.0
    b.pl    4f
    fmov    d7, #1.0
    fabs    d6, d4
    fcmp    d6, d21
    b.eq    3f
    fdiv    d6, d7, d4                  // one over the pair: the quotient, put right by what it leaves over
    fabs    d3, d6
    fcmp    d3, d21
    b.eq    5f
    fmsub   d3, d4, d6, d7
    fmsub   d3, d17, d6, d3
    fmadd   d6, d3, d6, d6
5:  fmov    d4, d6
    b       4f
3:  fdiv    d5, d7, d1                  // the power went past the largest number: the reciprocal's powers reach the smallest
    fmsub   d16, d5, d1, d7
    fmul    d16, d16, d5
    fabs    d3, d16                     // (an infinite base leaves no sensible miss: none)
    fcmp    d3, d21
    b.lo    6f
    fmov    d16, xzr
6:  mov     x0, x6
    bl      m_powloop
4:  fmov    d0, d4
    RESULT
8:  fmov    d6, #0.5                    // the power one half is the square root, which the processor has exactly;
    fcmp    d0, d6                      // every other power that is not whole waits for logarithms (the Math library)
    b.ne    81f
    fabs    d0, d1
    ldr     x0, =0x7ff0000000000000
    fmov    d6, x0
    fcmp    d0, d6
    b.eq    82f
    fsqrt   d0, d1
    fabs    d0, d0
82: RESULT
81: b       m_powfrac                   // any other power that is not whole: math.S
// PAIRMUL: the pair (\ah, \al) times the pair (\bh, \bl) -> (\ah, \al). A pair is a double and the small amount by which it
// misses the true value; the fused multiply-add gives a product's own miss exactly. d21 holds infinity. Uses d18-d20.
    .macro  PAIRMUL ah, al, bh, bl
    fmul    d18, \ah, \bh
    fabs    d20, d18
    fcmp    d20, d21
    b.hs    69f
    fcmp    d18, #0.0                   // (a zero keeps its sign only if nothing is added to it)
    b.ne    70f
69: fmov    \ah, d18
    fmov    \al, xzr
    b       71f
70: fnmsub  d19, \ah, \bh, d18
    fmadd   d19, \ah, \bl, d19
    fmadd   d19, \al, \bh, d19
    fadd    \ah, d18, d19
    fsub    d20, \ah, d18
    fsub    \al, d19, d20
71:
    .endm
m_powloop:                              // the pair (d5, d16) to the whole power x0 -> the pair (d4, d17)
    fmov    d4, #1.0
    fmov    d17, xzr
1:  cbz     x0, 3f
    tbz     x0, #0, 2f
    PAIRMUL d4, d17, d5, d16
2:  lsr     x0, x0, #1
    cbz     x0, 3f
    PAIRMUL d5, d16, d5, d16
    b       1b
3:  ret
i_neg:
    ldr     x0, [x22, #-8]
    mov     w16, #T_OBJECT
    mov     x4, #1
    mov     x5, x0
    lsr     x2, x0, #48
    cmp     w2, w16
    b.eq    m_tonum
    bl      v_number
    fneg    d0, d0
    RESULT
i_plus:
    ldr     x0, [x22, #-8]
    mov     w16, #T_OBJECT
    mov     x4, #1
    mov     x5, x0
    lsr     x2, x0, #48
    cmp     w2, w16
    b.eq    m_tonum
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
i_totext:
    ldr     x5, [x22, #-8]
    lsr     x2, x5, #48
    mov     w16, #T_OBJECT
    cmp     w2, w16
    b.ne    m_next
    mov     x4, #1
    b       m_totext
i_typeof:
    ldr     x0, [x22, #-8]
    ISNUM   x0
    b.hs    1f
    LIT     s_number, s_string
    b       9f
1:  mov     w16, #T_STRING
    cmp     w17, w16
    b.ne    2f
    STRV    x0, x1, x2                  // a string whose first unit is 1 is a symbol (see prelude.js, Symbol)
    cbz     x2, 11f
    ldr     x3, [x1, #-8]
    lsr     x3, x3, #32
    cbnz    x3, 11f
    ldrb    w3, [x1]
    cmp     w3, #1
    b.ne    11f
    LIT     s_symbol, s_symbol_end
    b       9f
11: LIT     s_string, s_boolean
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
4:  mov     w16, #T_OBJECT
    cmp     w17, w16
    b.ne    5f
    and     x1, x0, #0xffffffffffff
    ldr     x1, [x19, x1]
    cmp     x1, #1
    b.eq    52f
    ldr     x2, [x19, #W_BIGPROTO]
    cbz     x2, 5f
    and     x1, x0, #0xffffffffffff
    add     x1, x19, x1
    ldr     x1, [x1, #8]
    cmp     x1, x2
    b.eq    51f
    b       5f
52: LIT     s_function, s_function_end
    b       9f
51: LIT     s_bigint, s_bigint_end      // [by Opus] an object whose prototype is BigInt's (n 74 names it)
    b       9f
5:  LIT     s_object, s_objtext         // null too: the language's oldest mistake, kept
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
1:  and     x2, x0, #0xffffffffffff
    add     x2, x19, x2
    ldr     x3, [x2], #8
    and     x4, x1, #0xffffffffffff
    add     x4, x19, x4
    ldr     x5, [x4], #8
    lsr     x8, x3, #32
    lsr     x9, x5, #32
    and     x3, x3, #0xffffffff
    and     x5, x5, #0xffffffff
    mov     x6, #0
2:  cmp     x6, x3
    b.hs    3f
    cmp     x6, x5
    b.hs    3f
    cbz     x8, 21f
    ldrh    w7, [x2, x6, lsl #1]
    b       22f
21: ldrb    w7, [x2, x6]
22: cbz     x9, 23f
    ldrh    w10, [x4, x6, lsl #1]
    b       24f
23: ldrb    w10, [x4, x6]
24: add     x6, x6, #1
    cmp     w7, w10
    b.eq    2b
    ret
3:  cmp     x3, x5                      // one ran out: the shorter is less
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
    .macro  LOOSEOBJ                    // [by Opus] == with an object on one side only, and no undefined or null on the other:
    lsr     x2, x0, #48                 //   the object becomes a primitive first (m_toprim; the instruction runs again)
    lsr     x3, x1, #48
    mov     w16, #T_OBJECT
    cmp     w2, w16
    cset    w6, eq
    cmp     w3, w16
    cset    w7, eq
    cmp     w6, w7
    b.eq    77f
    cbz     w6, 76f
    mov     w16, #T_UNDEF
    cmp     w3, w16
    b.eq    77f
    mov     w16, #T_NULL
    cmp     w3, w16
    b.eq    77f
    mov     x4, #2
    mov     x5, x0
    b       m_toprim
76: mov     w16, #T_UNDEF
    cmp     w2, w16
    b.eq    77f
    mov     w16, #T_NULL
    cmp     w2, w16
    b.eq    77f
    mov     x4, #1
    mov     x5, x1
    b       m_toprim
77:
    .endm
i_eq:
    ldp     x0, x1, [x22, #-16]
    LOOSEOBJ
    bl      v_loose
    sub     x22, x22, #8
    b       m_bool
i_ne:
    ldp     x0, x1, [x22, #-16]
    LOOSEOBJ
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
    ldrb    w0, [x21], #1
m_print_n:
    sub     x1, x22, x0, lsl #3
    stp     x1, x22, [sp, #-32]!        // the next value to print, where they end, and the first
    str     x1, [sp, #16]
1:  ldp     x1, x2, [sp]
    cmp     x1, x2
    b.hs    3f
    add     x3, x1, #8
    str     x3, [sp]
    ldr     x3, [sp, #16]
    cmp     x1, x3
    b.eq    2f
    adr     x0, p_space
    mov     x1, #1
    bl      w_out
    ldr     x1, [sp]
    sub     x1, x1, #8
2:  ldr     x0, [x1]
    bl      v_text
    cbz     x0, 4f
    bl      w_outs
    b       1b
3:  ldr     x22, [sp, #16]
    add     sp, sp, #32
    adr     x0, p_line
    mov     x1, #1
    bl      w_out
    VAL     x0, T_UNDEF
    PUSH    x0
    NEXT
4:  add     sp, sp, #32
    b       m_full
i_getl:
    U16     w0
    ldr     x0, [x27, x0, lsl #3]
    PUSH    x0
    NEXT
i_setl:
    U16     w0
    ldr     x1, [x22, #-8]
    str     x1, [x27, x0, lsl #3]
    NEXT
// UPVAR: the place of a variable some scopes out -> x2 (its address); its number in x0
    .macro  UPVAR
    ldrb    w1, [x21], #1
    U16     w0
    mov     x2, x28
60: cbz     w1, 61f
    ldr     x2, [x19, x2]
    sub     w1, w1, #1
    b       60b
61: add     x2, x19, x2
    add     x2, x2, #8
    add     x2, x2, x0, lsl #3
    .endm
i_getup:
    UPVAR
    ldr     x0, [x2]
    PUSH    x0
    NEXT
i_setup:
    UPVAR
    ldr     x1, [x22, #-8]
    str     x1, [x2]
    NEXT
i_closure:
    U16     w0
    ldr     x1, [x23, x0, lsl #3]
    mov     x4, x1
    mov     x0, #64
    mov     x1, #1
    bl      o_make
    cbz     x0, m_full
    add     x9, x19, x0
    mov     x1, x4
    and     x1, x1, #0xffffffffffff
    stp     x1, x28, [x9, #F_PLAN]
    bl      m_this
    str     x0, [x9, #F_THIS]
    sub     x0, x9, x19
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    PUSH    x0
    NEXT
i_callee:
    ldr     x0, [x20, #48]
    PUSH    x0
    NEXT
i_call:
    ldrb    w0, [x21], #1               // how many arguments
m_call_n:
    sub     x1, x22, x0, lsl #3         // the first of them: where the function's variables begin
    VAL     x11, T_UNDEF
    sub     x12, x1, #8
    mov     x13, #0
m_call:                                 // w0 arguments from x1 on, the function under them; x11 this, x12 where the answer goes, x13 by `new`?
    ldr     x2, [x1, #-8]
    lsr     x3, x2, #48
    mov     w16, #T_OBJECT
    cmp     w3, w16
    b.ne    m_notfn_v
    and     x2, x2, #0xffffffffffff
    add     x2, x19, x2
    ldr     x3, [x2]
    cmp     x3, #1
    b.ne    m_notfn_o
    ldr     x4, [x2, #F_PLAN]
    add     x4, x19, x4                 // its plan
    ldr     w5, [x4, #16]
    ldr     w6, [x4, #20]
    ldr     x9, [x4, #24]
    tbnz    x9, #5, m_native            // a built-in routine (lib.S)
    tbz     x9, #4, 88f                 // a class written without a constructor: the call goes on to the parent class,
    ldr     x3, [x2, #O_PROTO]          // or, with none, is over at once
    lsr     x4, x3, #48
    mov     w16, #T_OBJECT
    cmp     w4, w16
    b.ne    89f
    and     x4, x3, #0xffffffffffff
    ldr     x4, [x19, x4]
    cmp     x4, #1
    b.ne    89f
    str     x3, [x1, #-8]
    b       m_call
89: VAL     x0, T_UNDEF
    cmp     x13, #1
    csel    x0, x11, x0, eq
    str     x0, [x12]
    add     x22, x12, #8
    NEXT
88: tbz     x9, #1, 0f
    ldr     x11, [x2, #F_THIS]          // an arrow: the `this` it was made under
0:  tbz     x9, #3, 30f                 // it uses `arguments`: all of them, as an array, kept for its variable
    stp     x1, x11, [sp, #-32]!
    stp     x12, x13, [sp, #16]
    mov     x17, x0
    mov     x0, x1
    mov     x1, x17
    bl      a_from
    mov     x15, x0
    ldp     x1, x11, [sp]
    ldp     x12, x13, [sp, #16]
    add     sp, sp, #32
    cbz     x15, m_full
    mov     x0, x17
    bl      m_plan
30: tbz     x9, #2, 20f                 // its last parameter gathers the rest: the arguments from there on become an array
    sub     x7, x5, #1
    add     x8, x1, x7, lsl #3
    add     x10, x8, #16
    cmp     x10, x26
    b.hi    m_deep
    VAL     x10, T_UNDEF
21: cmp     x22, x8
    b.hs    22f
    str     x10, [x22], #8
    b       21b
22: stp     x1, x11, [sp, #-48]!
    stp     x12, x13, [sp, #16]
    stp     x8, x15, [sp, #32]
    mov     x0, x8
    sub     x1, x22, x8
    lsr     x1, x1, #3
    bl      a_from
    mov     x3, x0
    ldp     x1, x11, [sp]
    ldp     x12, x13, [sp, #16]
    ldp     x8, x15, [sp, #32]
    add     sp, sp, #48
    cbz     x3, m_full
    str     x3, [x8]
    add     x22, x8, #8
    bl      m_plan
    mov     x0, x5
20:
    cmp     x0, x5                      // arguments beyond the parameters are dropped;
    b.ls    1f
    add     x22, x1, x5, lsl #3
1:  VAL     x7, T_UNDEF                 // missing ones, and the other variables, begin undefined
    add     x8, x1, x6, lsl #3
    add     x9, x8, #64
    cmp     x9, x26
    b.hi    m_deep
2:  cmp     x22, x8
    b.hs    3f
    str     x7, [x22], #8
    b       2b
3:  ldr     x9, [x4, #24]
    tbz     x9, #3, 31f
    lsr     x9, x9, #16
    str     x15, [x1, x9, lsl #3]
31: ldr     x9, [x19, #W_CODE]          // the record
    add     x9, x19, x9
    sub     x9, x21, x9
    sub     x10, x27, x19
    stp     x9, x10, [x22]
    sub     x9, x20, x19
    stp     x28, x9, [x22, #16]
    sub     x9, x12, x19
    stp     x9, x11, [x22, #32]
    ldr     x9, [x1, #-8]
    ldr     x16, [x19, #W_POS]          // word 7: the call's kind (4 bits), where the caller was: line (20 bits), its text's
    and     x17, x16, #0xfffff          //   number (8 bits, in place), column (32 bits)
    and     x16, x16, #0xffffffffff000000
    orr     x16, x16, x17, lsl #4
    orr     x16, x16, x13
    stp     x9, x16, [x22, #48]
    mov     x20, x22
    add     x22, x22, #64
    mov     x27, x1
    ldr     x28, [x2, #F_SCOPE]         // the scope the function remembered
    ldr     x9, [x4, #24]
    tbz     x9, #0, 5f
    add     x0, x6, #1                  // its variables live in the heap: a new scope, linked to the remembered one
    lsl     x0, x0, #3
    bl      w_alloc
    cbz     x0, m_full
    add     x9, x19, x0
    str     x28, [x9], #8
    mov     x28, x0
    mov     x10, #0
4:  cmp     x10, x6
    b.hs    41f
    ldr     x7, [x1, x10, lsl #3]
    str     x7, [x9, x10, lsl #3]
    add     x10, x10, #1
    b       4b
41: mov     x27, x9
5:  ldr     x9, [x4, #8]
    ldr     x10, [x19, #W_CODE]
    add     x21, x19, x10
    add     x21, x21, x9
    NEXT
i_ret:
    ldr     x0, [x22, #-8]
    ldr     x13, [x20, #56]             // 1: called by new; 2: a setter, whose answer is dropped
    and     x13, x13, #0xf
    cbz     x13, 1f
    cmp     x13, #2
    b.hs    1f
    TAGIS   x0, T_OBJECT
    b.eq    1f
    ldr     x0, [x20, #40]
1:
m_ret_x0:                               // (i_yield comes in here: x0 the answer, x13 the call's kind)
    ldr     x9, [x20, #56]              // the caller's place becomes the place errors are reported at again
    ubfx    x10, x9, #4, #20
    cbz     x10, 6f
    and     x9, x9, #0xffffffffff000000
    orr     x10, x10, x9
    str     x10, [x19, #W_POS]
6:
    ldp     x9, x10, [x20]
    ldp     x28, x11, [x20, #16]
    ldr     x12, [x20, #32]
    add     x27, x19, x10
    add     x20, x19, x11
    add     x22, x19, x12
    ldr     x10, [x19, #W_CODE]
    add     x21, x19, x10
    add     x21, x21, x9
    cmp     x13, #2
    b.eq    2f
    b.hi    3f
    str     x0, [x22], #8
2:  NEXT
3:  mov     x12, x22                    // 3, 4: the call was an object's toString, made in the middle of an instruction
    b       m_answer
// Kept calls (generators, async functions). A call that stops in the middle is copied off the stack into an array, the
// snapshot: its variables, its record, whatever its instructions had on the stack (open try records among them), then seven
// plain numbers: how many variables, where its variables live if in the heap (0: on the stack), its scope, the instruction
// to go on at, its newest open try (measured from its variables; 0: none), where its variables were on the stack, and 1 if
// it has not started. The prelude holds it in a two-item array, the holder: the snapshot, and a mark the machine sets to 1
// at each yield (so the prelude can tell a yield from the end). While a kept call runs, the holder lies just under its variables.
// m_snap: the running call (down to x22) -> x0 its snapshot (0: the world is full); x15 the seventh number. The call's own
// try records leave the chain of open ones.
m_snap:
    stp     x29, x30, [sp, #-16]!
    ldr     x9, [x20, #48]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     x9, [x9, #F_PLAN]
    add     x9, x19, x9
    ldr     w6, [x9, #20]
    sub     x1, x20, x6, lsl #3
    add     x9, x22, #96
    cmp     x9, x26
    b.ls    0f
    ldp     x29, x30, [sp], #16
    b       m_deep
0:  sub     x10, x1, x19
    sub     x11, x27, x19
    cmp     x27, x1
    csel    x11, xzr, x11, eq
    ldr     x12, [x19, #W_CODE]
    add     x12, x19, x12
    sub     x12, x21, x12
    add     x12, x12, x15               // (a fresh one goes on after the OP_RET that follows)
    ldr     x13, [x19, #W_HANDLER]
    mov     x14, #0
    cmp     x13, x10
    b.ls    2f
    sub     x14, x13, x10
1:  add     x9, x19, x13
    ldr     x13, [x9, #-8]
    cmp     x13, x10
    b.hi    1b
    str     x13, [x19, #W_HANDLER]
2:  stp     x6, x11, [x22]
    stp     x28, x12, [x22, #16]
    stp     x14, x10, [x22, #32]
    str     x15, [x22, #48]
    mov     x0, x1
    add     x1, x22, #56
    sub     x1, x1, x0
    lsr     x1, x1, #3
    bl      a_from
    ldp     x29, x30, [sp], #16
    ret
i_gensnap:
    ldrb    w14, [x21], #1
    str     x14, [sp, #-16]!
    mov     x15, #1
    bl      m_snap
    ldr     x14, [sp], #16
    cbz     x0, m_full
    stp     x0, xzr, [x22]              // the holder
    str     x14, [sp, #-16]!
    mov     x0, x22
    mov     x1, #2
    bl      a_from
    ldr     x14, [sp], #16
    cbz     x0, m_full
    add     x9, x19, x14, lsl #3
    ldr     x9, [x9, #W_GENFN]
    cmp     x14, #2                     // 2: an async generator
    b.ne    1f
    ldr     x9, [x19, #W_GENFN3]
1:  stp     x9, x0, [x22], #16
    mov     x0, #1
    b       m_call_n
i_yield:
    ldr     x0, [x22, #-8]!
    str     x0, [sp, #-16]!
    mov     x15, #0
    bl      m_snap
    ldr     x14, [sp], #16
    cbz     x0, m_full
    ldr     x9, [x20, #48]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     x9, [x9, #F_PLAN]
    add     x9, x19, x9
    ldr     w6, [x9, #20]
    sub     x1, x20, x6, lsl #3
    ldr     x9, [x1, #-8]               // the holder
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     x9, [x9, #A_ITEMS]
    add     x9, x19, x9
    mov     x10, #0x3ff0000000000000
    stp     x0, x10, [x9]
    mov     x0, x14
    ldr     x13, [x20, #56]
    and     x13, x13, #0xf
    b       m_ret_x0
// m_resume: built-in 59, a turn of the call itself: (holder, null or not, value). The kept call is put back on the stack
// where the arguments were (the holder stays under it), its record made to answer this call, its try records moved to
// where they now lie and joined to the open ones. Then it goes on: with the value as its yield's answer (null), or with
// the value thrown where it stopped (anything else).
m_resume:
    ldr     x14, [x1, #8]
    ldr     x15, [x1, #16]
    ldr     x9, [x1]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     x9, [x9, #A_ITEMS]
    add     x9, x19, x9
    ldr     x9, [x9]
    and     x9, x9, #0xffffffffffff
    add     x9, x19, x9
    ldr     w5, [x9, #A_LEN]
    ldr     x9, [x9, #A_ITEMS]
    add     x9, x19, x9
    sub     x5, x5, #7
    add     x2, x1, #8
    add     x10, x2, x5, lsl #3
    add     x10, x10, #64
    cmp     x10, x26
    b.hi    m_deep
    mov     x3, #0
1:  ldr     x10, [x9, x3, lsl #3]
    str     x10, [x2, x3, lsl #3]
    add     x3, x3, #1
    cmp     x3, x5
    b.lo    1b
    add     x9, x9, x5, lsl #3
    ldp     x6, x7, [x9]
    ldp     x8, x10, [x9, #16]
    ldp     x16, x17, [x9, #32]
    ldr     x4, [x9, #48]
    add     x3, x2, x6, lsl #3
    ldr     x9, [x19, #W_CODE]
    add     x9, x19, x9
    sub     x0, x21, x9
    add     x21, x9, x10
    sub     x10, x27, x19
    stp     x0, x10, [x3]
    sub     x10, x20, x19
    stp     x28, x10, [x3, #16]
    sub     x10, x12, x19
    str     x10, [x3, #32]
    str     x13, [x3, #56]
    mov     x20, x3
    add     x22, x2, x5, lsl #3
    mov     x28, x8
    add     x27, x19, x7
    cmp     x7, #0
    csel    x27, x2, x27, eq
    cbz     x16, 5f
    sub     x9, x2, x19
    sub     x10, x9, x17
    add     x16, x9, x16
    ldr     x12, [x19, #W_HANDLER]
    str     x16, [x19, #W_HANDLER]
3:  add     x11, x19, x16
    ldr     x0, [x11, #-32]
    add     x0, x0, x10
    str     x0, [x11, #-32]
    ldr     x0, [x11, #-24]
    cmp     x0, x17
    csel    x0, x9, x0, eq
    str     x0, [x11, #-24]
    ldr     x0, [x11, #-8]
    cmp     x0, x17
    b.ls    4f
    add     x16, x0, x10
    str     x16, [x11, #-8]
    b       3b
4:  str     x12, [x11, #-8]
5:  TAGIS   x14, T_NULL
    b.ne    7f
    cbnz    x4, 6f
    str     x15, [x22], #8
6:  NEXT
7:  mov     x0, x15
    b       m_throw
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
    .word   i_getl - m_table, i_setl - m_table, i_getup - m_table, i_setup - m_table, i_closure - m_table, i_call - m_table, i_ret - m_table, i_callee - m_table
    .word   i_object - m_table, i_array - m_table, i_getp - m_table, i_setp - m_table, i_gete - m_table, i_sete - m_table
    .word   i_initp - m_table, i_inite - m_table, i_getek - m_table, i_callm - m_table, i_new - m_table, i_this - m_table
    .word   i_swap - m_table, i_rot - m_table, i_pick - m_table, i_dup2 - m_table
    .word   i_in - m_table, i_instof - m_table, i_delp - m_table, i_dele - m_table
    .word   i_keys - m_table, i_iter - m_table, i_fornext - m_table
    .word   i_append - m_table, i_spread - m_table, i_apply - m_table, i_tail - m_table, i_defacc - m_table, i_extends - m_table, i_home - m_table, i_super - m_table
    .word   i_try - m_table, i_endtry - m_table, i_endtryk - m_table, i_throw - m_table, i_gosub - m_table, i_retsub - m_table, i_getgq - m_table
    .word   i_scope - m_table, i_unscope - m_table, i_copyscope - m_table, i_constget - m_table, i_consterr - m_table
    .word   i_gensnap - m_table, i_yield - m_table, i_line - m_table, i_superthis - m_table, i_totext - m_table
    .ltorg
