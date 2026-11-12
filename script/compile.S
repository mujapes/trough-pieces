// The translator: the program's words become instructions for the machine, in one pass, nothing kept as a tree. Expressions by
// precedence climbing; jumps are written with room for their distance and filled in when the place is known.
// While it works: x19 the world, x20-x28 and d8 the word reader's (the current word is always read already), x29 this
// translator's own frame, set once by c_compile and never moved: an error anywhere drops the stack back to it.
// Stage 2: names are all globals (no block scope yet); functions, objects, arrays and templates are refused as not yet made.
    .equ F_LOOP, 16                     // the innermost loop's record (on the stack: outer record, breaks, continues), or 0
    .equ F_CODE, 24                     // where the instructions go (an address, for this call only)
    .equ F_LEN, 32                      // how many bytes are written
    .equ F_CAP, 40
    .equ F_LV, 48                       // where a plain read of a name was just written (it may be assigned to), or -1
    .equ F_DEPTH, 56                    // how deep the nesting is
    .equ F_FUNC, 64                     // the function being translated: its record (on the stack), or 0 at the top level
    .equ F_NTOP, 72                     // names of variables, 16 bytes each (where in the text, how long), kept during
    .equ F_TRY, 96                      // the innermost try's record (on the stack: outer record, 1 while its finally is still to come, the chain of jumps to its finally, the loop and the function it is in), or 0
    .equ F_PTOP, 80                     // translation in the machine's idle stack; from its other end, declared functions waiting
    .equ C_DEEPEST, 400
    // a function's record
    .equ R_PARENT, 0
    .equ R_NAMES, 8                     // its names (parameters first), and how many
    .equ R_COUNT, 16
    .equ R_FLAGS, 24                    // 1: it has inner functions, so its variables live in the heap
    .equ R_PARAMS, 32
    .equ R_START, 40
// ISP, ISK: is the current word this punctuation / this keyword; goes to \no if not
    .macro  ISP id, no
    cmp     w23, #K_PUNCT
    b.ne    \no
    cmp     w24, #\id
    b.ne    \no
    .endm
    .macro  ISK id, no
    cmp     w23, #K_KEYWORD
    b.ne    \no
    cmp     w24, #\id
    b.ne    \no
    .endm
// EXPECT: the current word must be this punctuation; steps past it
    .macro  EXPECT id
    ISP     \id, c_unexpected
    bl      next_word
    .endm
    .macro  OP op
    mov     w0, #\op
    bl      c_byte
    .endm
    .macro  NOLV
    mov     x9, #-1
    str     x9, [x29, #F_LV]
    .endm
    .macro  DEEPER
    ldr     x9, [x29, #F_DEPTH]
    add     x9, x9, #1
    str     x9, [x29, #F_DEPTH]
    cmp     x9, #C_DEEPEST
    b.hi    c_toodeep
    .endm
    .macro  SHALLOWER
    ldr     x9, [x29, #F_DEPTH]
    sub     x9, x9, #1
    str     x9, [x29, #F_DEPTH]
    .endm

// c_compile: the text at x20, x21 bytes long, as instructions in the world -> x0 1, or -1 with the error left in the world
c_compile:
    stp     x29, x30, [sp, #-128]!
    mov     x29, sp
    stp     x20, x21, [x29, #104]
    str     xzr, [x29, #F_TRY]
    str     xzr, [x19, #W_HANDLER]
    str     xzr, [x29, #F_LOOP]
    str     xzr, [x29, #88]
    ldr     x9, [x19, #W_CODE]
    add     x9, x19, x9
    str     x9, [x29, #F_CODE]
    ldr     x9, [x19, #W_CODE_CAP]
    stp     xzr, x9, [x29, #F_LEN]
    mov     x9, #-1
    stp     x9, xzr, [x29, #F_LV]
    str     xzr, [x29, #F_FUNC]
    ldr     x9, [x19, #W_STACK]
    add     x9, x19, x9
    ldr     x10, [x19, #W_STACK_END]
    add     x10, x19, x10
    stp     x9, x10, [x29, #F_NTOP]
    mov     w0, #OP_JMP                 // first to the end, where the declared functions are made; then back here
    bl      c_jump
    adr     x20, c_prelude              // first the few lines of the language that make the error classes
    mov     x21, #(c_prelude_end - c_prelude)
    mov     x22, #0
    mov     w28, #1
    bl      next_word
3:  cbz     w23, 4f
    bl      c_stmt
    b       3b
4:  ldp     x20, x21, [x29, #104]
    mov     x22, #0
    mov     w28, #1
    bl      next_word
1:  cbz     w23, 2f
    bl      c_stmt
    b       1b
2:  OP      OP_HALT
    mov     x0, #1
    bl      c_patch
    ldr     x0, [x19, #W_STACK_END]
    add     x0, x19, x0
    bl      c_hoist
    mov     w0, #OP_JMP
    mov     x1, #5
    bl      c_jump_to
    stp     xzr, xzr, [x19, #W_FP]
    str     xzr, [x19, #W_ENV]
    ldr     x9, [x29, #F_LEN]
    str     x9, [x19, #W_CODE_LEN]
    str     xzr, [x19, #W_PC]
    ldr     x9, [x19, #W_STACK]
    str     x9, [x19, #W_SP]
    mov     w9, #1
    str     w9, [x19, #W_STATE]
    mov     x0, #1
c_out:
    ldp     x29, x30, [sp], #128
    ret
c_prelude:
    .ascii "class Error{constructor(m){if(m!==undefined)this.message=\"\"+m}toString(){return this.message===\"\"?this.name:this.name+\": \"+this.message}}"
    .ascii "Error.prototype.name=\"Error\";Error.prototype.message=\"\";"
    .ascii "class TypeError extends Error{}TypeError.prototype.name=\"TypeError\";"
    .ascii "class RangeError extends Error{}RangeError.prototype.name=\"RangeError\";"
    .ascii "class ReferenceError extends Error{}ReferenceError.prototype.name=\"ReferenceError\";"
    .ascii "class SyntaxError extends Error{}SyntaxError.prototype.name=\"SyntaxError\";"
    .ascii "class EvalError extends Error{}EvalError.prototype.name=\"EvalError\";"
    .ascii "class URIError extends Error{}URIError.prototype.name=\"URIError\";"
c_prelude_end:
    .balign 4
// the ways it goes wrong: the message, with the line and column of the word it stopped at
c_unexpected:
    adr     x0, c_m_unexpected
    mov     x1, #(c_m_notyet - c_m_unexpected)
    b       c_fail
c_notyet:
    adr     x0, c_m_notyet
    mov     x1, #(c_m_left - c_m_notyet)
    b       c_fail
c_badleft:
    adr     x0, c_m_left
    mov     x1, #(c_m_loop - c_m_left)
    b       c_fail
c_noloop:
    adr     x0, c_m_loop
    mov     x1, #(c_m_big - c_m_loop)
    b       c_fail
c_toobig:
    adr     x0, c_m_big
    mov     x1, #(c_m_deep - c_m_big)
    b       c_fail
c_toodeep:
    adr     x0, c_m_deep
    mov     x1, #(c_m_full - c_m_deep)
    b       c_fail
c_full:
    adr     x0, c_m_full
    mov     x1, #(c_m_end - c_m_full)
c_fail:
    mov     sp, x29
    bl      w_string
    str     x0, [x19, #W_ERR]
    mov     w9, #1
    mov     w10, #1
    mov     x11, #0
1:  cmp     x11, x25
    b.hs    2f
    cmp     x11, x21
    b.hs    2f
    ldrb    w12, [x20, x11]
    add     x11, x11, #1
    add     w10, w10, #1
    cmp     w12, #10
    b.ne    1b
    add     w9, w9, #1
    mov     w10, #1
    b       1b
2:  str     w9, [x19, #W_ERR_LINE]
    str     w10, [x19, #W_ERR_COL]
    mov     w9, #3
    str     w9, [x19, #W_STATE]
    mov     x0, #-1
    b       c_out
c_m_unexpected: .ascii "SyntaxError: Unexpected token"
c_m_notyet:     .ascii "SyntaxError: this part of the language is not made yet"
c_m_left:       .ascii "SyntaxError: Invalid left-hand side in assignment"
c_m_loop:       .ascii "SyntaxError: break or continue outside a loop"
c_m_big:        .ascii "RangeError: the program is too big"
c_m_deep:       .ascii "RangeError: the program is nested too deeply"
c_m_full:       .ascii "RangeError: the world is full"
c_m_end:
c_w_undefined:  .ascii "undefined"
c_w_nan:        .ascii "NaN"
c_w_infinity:   .ascii "Infinity"
c_w_console:    .ascii "console"
c_w_log:        .ascii "log"
c_w_end:
c_w_arguments:  .ascii "arguments"
c_w_arguments_end:
// for each punctuation (by its id): how tightly it binds as an operator between two values (0: it is not one) and its instruction
c_prec:
    .byte   0, 0,  0, 0,  7, OP_SEQ,  7, OP_SNE,  0, 0,  0, 0,  0, 0,  9, OP_USHR                   // >>>= ... === !== **= <<= >>= >>>
    .byte   0, 0,  0, 0,  0, 0,  0, 0,  7, OP_EQ,  7, OP_NE,  8, OP_LE,  8, OP_GE                   // &&= ||= ??= => == != <= >=
    .byte   3, OP_JFK,  2, OP_JTK,  1, OP_JNK,  0, 0,  0, 0,  0, 0                                  // && || ?? ?. ++ --
    .byte   0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0                                   // += -= *= /= %= &= |= ^=
    .byte   9, OP_SHL,  9, OP_SHR,  12, OP_POW                                                      // << >> **
    .byte   0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0                                   // { } ( ) [ ] ; ,
    .byte   8, OP_LT,  8, OP_GT,  10, OP_ADD,  10, OP_SUB,  11, OP_MUL,  11, OP_DIV,  11, OP_MOD    // < > + - * / %
    .byte   6, OP_BAND,  4, OP_BOR,  5, OP_BXOR                                                     // & | ^
    .byte   0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0,  0, 0                                   // ! ~ ? : = . @ #
// for each punctuation: the instruction it applies when it assigns (0: it does not assign; 255: plain =)
c_asg:
    .byte   OP_USHR, 0, 0, 0, OP_POW, OP_SHL, OP_SHR, 0, OP_JFK, OP_JTK, OP_JNK, 0, 0, 0, 0, 0
    .byte   0, 0, 0, 0, 0, 0, OP_ADD, OP_SUB, OP_MUL, OP_DIV, OP_MOD, OP_BAND, OP_BOR, OP_BXOR, 0, 0
    .byte   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte   0, 0, 0, 0, 0, 0, 0, 255, 0, 0, 0
    .balign 4

// Writing instructions. c_byte: the byte w0 joins them. Uses x9-x11.
c_byte:
    ldp     x9, x10, [x29, #F_LEN]
    cmp     x9, x10
    b.hs    c_toobig
    ldr     x11, [x29, #F_CODE]
    strb    w0, [x11, x9]
    add     x9, x9, #1
    str     x9, [x29, #F_LEN]
    ret
// c_op16: the instruction w0 with the 16-bit number w1. Uses x9-x11, x13, x15.
c_op16:
    mov     x15, x30
    mov     w13, w1
    bl      c_byte
    and     w0, w13, #0xff
    bl      c_byte
    lsr     w0, w13, #8
    and     w0, w0, #0xff
    bl      c_byte
    ret     x15
// c_jump: the jump w0 with its distance left open -> x0 where the distance is to go. Uses x9-x11, x13, x15.
c_jump:
    mov     x15, x30
    bl      c_byte
    ldr     x13, [x29, #F_LEN]
    mov     w0, #0
    bl      c_byte
    bl      c_byte
    bl      c_byte
    bl      c_byte
    mov     x0, x13
    ret     x15
// c_patch: the jump whose distance is at x0 lands here. c_patch_to: lands at x1. Uses x9-x11.
c_patch:
    ldr     x1, [x29, #F_LEN]
c_patch_to:
    sub     x9, x1, x0
    sub     x9, x9, #4
    ldr     x11, [x29, #F_CODE]
    str     w9, [x11, x0]
    ret
// c_jump_to: the jump w0 to the place x1 (already known). Uses x9-x11, x13-x16.
c_jump_to:
    mov     x16, x30
    mov     x14, x1
    bl      c_jump
    mov     x1, x14
    bl      c_patch_to
    ret     x16
// c_chain: the jump w0 joins the chain whose head is at the address x1 (the chain runs through the open distances themselves).
c_chain:
    mov     x16, x30
    mov     x14, x1
    bl      c_jump
    ldr     x9, [x14]
    ldr     x11, [x29, #F_CODE]
    str     w9, [x11, x0]
    str     x0, [x14]
    ret     x16
// c_resolve: every jump of the chain whose head is x0 lands at x1. Uses x9-x13.
c_resolve:
    ldr     x11, [x29, #F_CODE]
1:  cbz     x0, 2f
    ldr     w12, [x11, x0]
    sub     x13, x1, x0
    sub     x13, x13, #4
    str     w13, [x11, x0]
    mov     x0, x12
    b       1b
2:  ret
// c_const: the value x0 as a constant (one already there is used again), and the instruction that brings it. Uses x9-x17.
c_const:
    mov     x17, x30
    bl      c_addconst
    mov     w1, w0
    mov     w0, #OP_CONST
    bl      c_op16
    ret     x17
// c_addconst: the value x0 as a constant -> w0 which. Uses x9-x12.
c_addconst:
    ldr     x9, [x19, #W_CONST_N]
    ldr     x10, [x19, #W_CONST]
    add     x10, x19, x10
    mov     x11, #0
1:  cmp     x11, x9
    b.hs    2f
    ldr     x12, [x10, x11, lsl #3]
    cmp     x12, x0
    b.eq    3f
    add     x11, x11, #1
    b       1b
2:  ldr     x12, [x19, #W_CONST_CAP]
    cmp     x9, x12
    b.hs    c_toobig
    mov     x12, #0xffff
    cmp     x9, x12
    b.hi    c_toobig
    str     x0, [x10, x9, lsl #3]
    add     x12, x9, #1
    str     x12, [x19, #W_CONST_N]
3:  mov     w0, w11
    ret
// c_strconst: the same for the string value x0, which is the newest thing in the heap: if a constant already holds that text,
// it is used and the new copy's room goes back.
c_strconst:
    mov     x17, x30
    and     x2, x0, #0xffffffffffff
    add     x3, x19, x2
    ldr     x4, [x3], #8
    ldr     x9, [x19, #W_CONST_N]
    ldr     x10, [x19, #W_CONST]
    add     x10, x19, x10
    mov     x11, #0
1:  cmp     x11, x9
    b.hs    5f
    ldr     x12, [x10, x11, lsl #3]
    lsr     x13, x12, #48
    mov     w14, #T_STRING
    cmp     w13, w14
    b.ne    4f
    and     x12, x12, #0xffffffffffff
    add     x12, x19, x12
    ldr     x13, [x12], #8
    cmp     x13, x4
    b.ne    4f
    mov     x14, #0
2:  lsr     x5, x4, #32                 // (how many bytes: the units, twice over if wide)
    and     x6, x4, #0xffffffff
    lsl     x6, x6, x5
    cmp     x14, x6
    b.hs    3f
    ldrb    w15, [x12, x14]
    ldrb    w16, [x3, x14]
    add     x14, x14, #1
    cmp     w15, w16
    b.eq    2b
4:  add     x11, x11, #1
    b       1b
3:  str     x2, [x19, #W_HEAP]
    mov     w1, w11
    mov     w0, #OP_CONST
    bl      c_op16
    ret     x17
5:  mov     x30, x17
    b       c_const
// c_is: is the current word exactly the x1 bytes at x0 -> flags: eq if so. Uses x9-x11.
c_is:
    cmp     x26, x1
    b.ne    9f
    add     x9, x20, x25
1:  subs    x1, x1, #1
    b.lt    8f
    ldrb    w10, [x9, x1]
    ldrb    w11, [x0, x1]
    cmp     w10, w11
    b.eq    1b
9:  ret
8:  cmp     x0, x0
    ret
// c_global: the global variable the current word names -> w0 which (made, holding undefined, if it is new)
c_global:
    str     x30, [sp, #-16]!
    ldr     x1, [x19, #W_GLOB]
    add     x1, x19, x1
    ldr     x2, [x19, #W_GLOB_N]
    add     x3, x20, x25
    mov     x4, #0
1:  cmp     x4, x2
    b.hs    5f
    add     x5, x1, x4, lsl #4
    ldr     x5, [x5]
    STRV    x5, x5, x6
    cmp     x6, x26
    b.ne    3f
    mov     x7, #0
2:  cmp     x7, x26
    b.hs    4f
    ldrb    w8, [x5, x7]
    ldrb    w9, [x3, x7]
    add     x7, x7, #1
    cmp     w8, w9
    b.eq    2b
3:  add     x4, x4, #1
    b       1b
4:  mov     x0, x4
    b       9f
5:  ldr     x9, [x19, #W_GLOB_CAP]
    cmp     x2, x9
    b.hs    c_toobig
    mov     x9, #0xffff
    cmp     x2, x9
    b.hs    c_toobig
    mov     x0, x3
    mov     x1, x26
    bl      w_string
    cbz     x0, c_full
    ldr     x1, [x19, #W_GLOB]
    add     x1, x19, x1
    ldr     x2, [x19, #W_GLOB_N]
    add     x5, x1, x2, lsl #4
    VAL     x6, T_HOLE
    stp     x0, x6, [x5]
    add     x9, x2, #1
    str     x9, [x19, #W_GLOB_N]
    mov     x0, x2
9:  ldr     x30, [sp], #16
    ret
// c_lvalue: the variable that was just read by name, to be assigned to -> w0 the reading instruction as written (its bytes);
// anything else is an error. Uses x9, x11, x12.
c_lvalue:
    ldr     x9, [x29, #F_LV]
    cmp     x9, #0
    b.lt    c_badleft
    ldr     x11, [x29, #F_CODE]
    ldr     w0, [x11, x9]
    and     w12, w0, #0xff
    mov     x11, #3
    cmp     w12, #OP_GETE
    b.ne    2f
    mov     x11, #1
    and     w0, w0, #0xff
    b       1f
2:  cmp     w12, #OP_GETUP
    cinc    x11, x11, eq
    b.eq    1f
    and     w0, w0, #0xffffff
1:  add     x11, x9, x11
    ldr     x12, [x29, #F_LEN]
    cmp     x11, x12
    b.ne    c_badleft
    ret
// c_raw: writes the reading instruction w0 (as c_lvalue and c_ref give it). c_store: writes the storing one that matches it.
c_store:
    add     w0, w0, #1
c_raw:
    mov     x16, x30
    mov     w14, w0
    and     w0, w14, #0xff
    bl      c_byte
    and     w9, w14, #0xff
    sub     w9, w9, #OP_GETE
    cmp     w9, #1
    b.ls    1f
    ubfx    w0, w14, #8, #8
    bl      c_byte
    ubfx    w0, w14, #16, #8
    bl      c_byte
    and     w9, w14, #0xff
    sub     w9, w9, #OP_GETUP
    cmp     w9, #1
    b.hi    1f
    lsr     w0, w14, #24
    bl      c_byte
1:  ret     x16
// c_lvdup: before a property (whose reading instruction is w0, just written) is read to be changed and stored again, the
// object (and key) it is read from are doubled, so they are still there for the store. w0 stays. Uses x9-x12, x14, x16.
c_lvdup:
    and     w9, w0, #0xff
    mov     w12, #OP_DUP
    cmp     w9, #OP_GETP
    b.eq    3f
    mov     w12, #OP_DUP2
    cmp     w9, #OP_GETE
    b.eq    3f
    ret
3:  str     x30, [sp, #-16]!
    str     w0, [sp, #8]
    ldr     x9, [x29, #F_LV]
    str     x9, [x29, #F_LEN]
    mov     w0, w12
    bl      c_byte
    ldr     x9, [x29, #F_LEN]
    str     x9, [x29, #F_LV]
    ldr     w0, [sp, #8]
    bl      c_raw
    ldr     w0, [sp, #8]
    ldr     x30, [sp], #16
    ret
// c_keyconst: the string value x0 (the newest thing in the heap) as a constant -> w0 which; nothing is written.
// c_wordconst: the same for the current word's own text.
c_wordconst:
    str     x30, [sp, #-16]!
    add     x0, x20, x25
    mov     x1, x26
    bl      w_text
    cbz     x0, c_full
    b       1f
c_keyconst:
    str     x30, [sp, #-16]!
1:  bl      c_strconst
    ldr     x9, [x29, #F_LEN]
    sub     x9, x9, #3
    str     x9, [x29, #F_LEN]
    ldr     x11, [x29, #F_CODE]
    add     x11, x11, x9
    ldrh    w0, [x11, #1]
    ldr     x30, [sp], #16
    ret
// c_scan_meth: called for each word while a body is read through in advance: a name, brackets, then { is a method written
// short in an object, an inner function like any other. Its state is kept at 88 in the frame. Uses x9-x12.
c_scan_meth:
    ldp     w9, w10, [x29, #88]
    cmp     w9, #2
    b.eq    2f
    cmp     w9, #3
    b.ne    0f
    mov     w9, #0
    cmp     w23, #K_PUNCT
    b.ne    0f
    cmp     w24, #33
    b.ne    0f
    ldr     x11, [x29, #F_FUNC]
    mov     x12, #1
    str     x12, [x11, #R_FLAGS]
    b       8f
0:  cmp     w9, #1
    b.ne    1f
    mov     w9, #0
    cmp     w23, #K_PUNCT
    b.ne    1f
    cmp     w24, #35
    b.ne    1f
    mov     w9, #2
    mov     w10, #1
    b       8f
1:  mov     w9, #0
    cmp     w23, #K_NAME
    b.eq    11f
    cmp     w23, #K_KEYWORD
    b.ne    8f
    cmp     w24, #2                     // not after catch, for, function, if, switch, while, with
    b.eq    8f
    sub     w11, w24, #14
    cmp     w11, #2
    b.ls    8f
    cmp     w24, #23
    b.eq    8f
    sub     w11, w24, #30
    cmp     w11, #1
    b.ls    8f
11: mov     w9, #1
    b       8f
2:  cmp     w23, #K_PUNCT
    b.ne    8f
    cmp     w24, #35
    b.ne    21f
    add     w10, w10, #1
    b       8f
21: cmp     w24, #36
    b.ne    8f
    subs    w10, w10, #1
    b.ne    8f
    mov     w9, #3
8:  stp     w9, w10, [x29, #88]
    ret
// c_declare: the current word as a variable of the function being translated -> w0 its number (made if new). Uses x1-x11.
c_declare:
    ldr     x1, [x29, #F_FUNC]
    ldr     x3, [x1, #R_NAMES]
    ldr     x4, [x1, #R_COUNT]
    mov     x2, #0
1:  cmp     x2, x4
    b.hs    5f
    add     x5, x3, x2, lsl #4
    ldp     x6, x7, [x5]
    cmp     x7, x26
    b.ne    4f
    add     x6, x20, x6
    add     x8, x20, x25
    mov     x9, #0
3:  cmp     x9, x26
    b.hs    6f
    ldrb    w10, [x6, x9]
    ldrb    w11, [x8, x9]
    add     x9, x9, #1
    cmp     w10, w11
    b.eq    3b
4:  add     x2, x2, #1
    b       1b
5:  add     x5, x3, x4, lsl #4
    add     x6, x5, #16
    ldr     x7, [x29, #F_PTOP]
    cmp     x6, x7
    b.hi    c_toobig
    mov     x7, #0xfff0
    cmp     x4, x7
    b.hs    c_toobig
    stp     x25, x26, [x5]
    str     x6, [x29, #F_NTOP]
    add     x4, x4, #1
    str     x4, [x1, #R_COUNT]
6:  mov     x0, x2
    ret
// c_declref: the current word declared where we are (a function's variable, or a global) -> w0 its reading instruction
c_declref:
    str     x30, [sp, #-16]!
    ldr     x1, [x29, #F_FUNC]
    cbz     x1, 1f
    bl      c_declare
    mov     w1, #OP_GETL
    b       2f
1:  bl      c_global
    ldr     x9, [x19, #W_GLOB]          // declared: it holds undefined from the start
    add     x9, x19, x9
    add     x9, x9, x0, lsl #4
    ldr     x10, [x9, #8]
    lsr     x11, x10, #48
    mov     w1, #T_HOLE
    cmp     w11, w1
    b.ne    3f
    VAL     x10, T_UNDEF
    str     x10, [x9, #8]
3:  mov     w1, #OP_GETG
2:  orr     w0, w1, w0, lsl #8
    ldr     x30, [sp], #16
    ret
// c_ref: the variable the current word names, looked for in this function, then each one around it, then the globals
// -> w0 its reading instruction
c_ref:
    ldr     x1, [x29, #F_FUNC]
    mov     w2, #0
    cbz     x1, 7f
1:  ldr     x3, [x1, #R_NAMES]
    ldr     x4, [x1, #R_COUNT]
2:  cbz     x4, 5f
    sub     x4, x4, #1
    add     x5, x3, x4, lsl #4
    ldp     x6, x7, [x5]
    cmp     x7, x26
    b.ne    2b
    add     x6, x20, x6
    add     x8, x20, x25
    mov     x9, #0
3:  cmp     x9, x26
    b.hs    4f
    ldrb    w10, [x6, x9]
    ldrb    w11, [x8, x9]
    add     x9, x9, #1
    cmp     w10, w11
    b.eq    3b
    b       2b
4:  cbnz    w2, 41f
    mov     w0, #OP_GETL
    orr     w0, w0, w4, lsl #8
    ret
41: ldr     x5, [x29, #F_FUNC]          // scopes out: one fewer if this function keeps no scope of its own
    ldr     x5, [x5, #R_FLAGS]
    and     w5, w5, #1
    sub     w2, w2, #1
    add     w2, w2, w5
    cmp     w2, #255
    b.hi    c_toodeep
    mov     w0, #OP_GETUP
    orr     w0, w0, w2, lsl #8
    orr     w0, w0, w4, lsl #16
    ret
5:  ldr     x1, [x1, #R_PARENT]
    add     w2, w2, #1
    cbnz    x1, 1b
7:  str     x30, [sp, #-16]!
    bl      c_global
    mov     w1, #OP_GETG
    orr     w0, w1, w0, lsl #8
    ldr     x30, [sp], #16
    ret
// c_hoist: the declared functions waiting (from the newest back to x0) are made and stored under their names
c_hoist:
    stp     x30, x0, [sp, #-32]!
    sub     x0, x0, #16
1:  ldr     x9, [x29, #F_PTOP]
    cmp     x0, x9
    b.lo    2f
    str     x0, [sp, #16]
    ldr     w1, [x0]
    mov     w0, #OP_CLOSURE
    bl      c_op16
    ldr     x0, [sp, #16]
    ldr     w0, [x0, #8]
    bl      c_store
    OP      OP_POP
    ldr     x0, [sp, #16]
    sub     x0, x0, #16
    b       1b
2:  ldr     x9, [sp, #8]
    str     x9, [x29, #F_PTOP]
    ldr     x30, [sp], #32
    ret
// Looking ahead without moving: the word reader's place is kept and put back.
    .macro  LEXSAVE
    sub     sp, sp, #64
    stp     x22, x25, [sp]
    stp     x26, x23, [sp, #16]
    stp     x24, x27, [sp, #32]
    str     x28, [sp, #48]
    str     d8, [sp, #56]
    .endm
    .macro  LEXBACK
    ldp     x22, x25, [sp]
    ldp     x26, x23, [sp, #16]
    ldp     x24, x27, [sp, #32]
    ldr     x28, [sp, #48]
    ldr     d8, [sp, #56]
    add     sp, sp, #64
    .endm
// c_peek_each: does a for's head begin (var) name in, or (var) name of -> w0 1 for in, 2 for of, 0 for neither
c_peek_each:
    str     x30, [sp, #-16]!
    LEXSAVE
    cmp     w23, #K_KEYWORD
    b.ne    2f
    cmp     w24, #28
    b.eq    1f
    cmp     w24, #33
    b.eq    1f
    cmp     w24, #4
    b.ne    8f
1:  bl      next_word
2:  str     wzr, [sp, #72]
    cmp     w23, #K_PUNCT
    b.ne    21f
    cmp     w24, #33
    b.eq    22f
    cmp     w24, #37
    b.ne    8f
22: bl      c_skip_pattern              // a pattern in the name's place: 4 is added to the answer
    mov     w9, #4
    str     w9, [sp, #72]
    b       24f
21: cmp     w23, #K_NAME
    b.ne    8f
    bl      next_word
24: cmp     w23, #K_KEYWORD
    b.ne    8f
    cmp     w24, #18
    b.eq    6f
    cmp     w24, #37
    b.ne    8f
    mov     w0, #2
    b       7f
6:  mov     w0, #1
7:  ldr     w9, [sp, #72]
    orr     w0, w0, w9
    b       9f
8:  mov     w0, #0
9:  LEXBACK
    ldr     x30, [sp], #16
    ret
// c_peek_name: is the word after the current one => -> flags: eq if so
c_peek_name:
    str     x30, [sp, #-16]!
    LEXSAVE
    bl      next_word
    mov     w0, #0
    cmp     w23, #K_PUNCT
    b.ne    1f
    cmp     w24, #11
    cset    w0, eq
1:  LEXBACK
    ldr     x30, [sp], #16
    cmp     w0, #1
    ret
// c_peek_paren: the current word is ( : is the word after its matching ) => -> flags: eq if so
c_peek_paren:
    str     x30, [sp, #-16]!
    LEXSAVE
    sub     sp, sp, #16
    mov     w9, #1
    str     w9, [sp]
1:  bl      next_word
    mov     w0, #0
    cbz     w23, 3f
    cmp     w23, #K_PUNCT
    b.ne    1b
    sub     w9, w24, #33
    cmp     w9, #5
    b.hi    1b
    ldr     w9, [sp]
    tbz     w24, #0, 2f
    add     w9, w9, #2
2:  sub     w9, w9, #1
    str     w9, [sp]
    cbnz    w9, 1b
    bl      next_word
    mov     w0, #0
    cmp     w23, #K_PUNCT
    b.ne    3f
    cmp     w24, #11
    cset    w0, eq
3:  add     sp, sp, #16
    LEXBACK
    ldr     x30, [sp], #16
    cmp     w0, #1
    ret
// c_scan_expr: an arrow's body that is an expression starts at the current word: does it hold an inner function? If so the
// function being translated is marked. Nothing moves.
c_scan_expr:
    str     x30, [sp, #-16]!
    LEXSAVE
    sub     sp, sp, #16
    str     wzr, [sp]
    str     xzr, [x29, #88]
1:  cbz     w23, 8f
    bl      c_scan_meth
    cmp     w23, #K_KEYWORD
    b.ne    2f
    cmp     w24, #15
    b.eq    7f
    b       6f
2:  cmp     w23, #K_PUNCT
    b.ne    6f
    cmp     w24, #11
    b.eq    7f
    ldr     w10, [sp]
    sub     w9, w24, #33
    cmp     w9, #5
    b.hi    3f
    tbz     w24, #0, 21f
    add     w10, w10, #2
21: subs    w10, w10, #1
    b.lt    8f
    str     w10, [sp]
    b       6f
3:  cbnz    w10, 6f
    cmp     w24, #39
    b.eq    8f
    cmp     w24, #40
    b.eq    8f
6:  bl      next_word
    b       1b
7:  ldr     x9, [x29, #F_FUNC]
    mov     x10, #1
    str     x10, [x9, #R_FLAGS]
8:  add     sp, sp, #16
    LEXBACK
    ldr     x30, [sp], #16
    ret
// c_scan_block: the current word is the { of a function's body. Its words are read through once, to the matching }, to
// learn what the translator must know before it starts: the variables declared in it (var, let, const, and the names of
// functions declared at a statement's start), wherever they are, and whether it holds inner functions (whose own bodies
// are stepped over). Then the reader is put just inside the { again, with the first word read.
// Kept at sp: 0 how deep in braces, 4 the depth of an inner function's body being stepped over (0: not in one),
// 8 an inner function's body is awaited (1: after "function", at the next {; 2: after =>, only if { is next),
// 12 a list of declared names is open (1; 2: the next word is one of them; 3: the next word is a declared function's name),
// 16 how deep in brackets inside that list, 20 whether a statement may start here.
c_scan_block:
    sub     sp, sp, #48
    str     x30, [sp, #40]
    str     x22, [sp, #24]
    str     w28, [sp, #32]
    mov     w9, #1
    stp     w9, wzr, [sp]
    stp     wzr, wzr, [sp, #8]
    stp     wzr, w9, [sp, #16]
    str     xzr, [x29, #88]
1:  bl      next_word
    cbz     w23, 9f
    bl      c_scan_meth
    ldp     w1, w2, [sp]
    ldp     w3, w4, [sp, #8]
    ldp     w5, w6, [sp, #16]
    mov     w7, #0
    cmp     w4, #2                      // a name was awaited and something else came
    b.lo    10f
    cmp     w23, #K_NAME
    b.eq    10f
    cmp     w4, #2
    cset    w4, eq
10: cmp     w23, #K_PUNCT
    b.ne    5f
    cmp     w24, #11
    b.ne    11f
    bl      c_scan_inner
    cbnz    w2, 8f
    mov     w3, #2
    b       8f
11: cmp     w24, #33
    b.ne    13f
    add     w1, w1, #1
    mov     w7, #1
    cbnz    w2, 8f
    cbz     w3, 12f
    mov     w2, w1
    mov     w3, #0
    b       8f
12: cbz     w4, 8f
    add     w5, w5, #1
    b       8f
13: cmp     w3, #2
    csel    w3, wzr, w3, eq
    cmp     w24, #34
    b.ne    14f
    mov     w7, #1
    cmp     w2, w1
    sub     w1, w1, #1
    b.ne    131f
    mov     w2, #0
    b       8f
131: cbz    w1, 9f
    cbnz    w2, 8f
    cbz     w4, 8f
    cbnz    w5, 132f
    mov     w4, #0
    b       8f
132: sub    w5, w5, #1
    b       8f
14: cbnz    w2, 8f
    cmp     w24, #39
    b.ne    15f
    mov     w7, #1
    cbnz    w5, 8f
    mov     w4, #0
    b       8f
15: cbz     w4, 8f
    cmp     w24, #35
    b.eq    16f
    cmp     w24, #37
    b.eq    16f
    cmp     w24, #36
    b.eq    17f
    cmp     w24, #38
    b.eq    17f
    cmp     w24, #40
    b.ne    8f
    cbnz    w5, 8f
    mov     w4, #2
    b       8f
16: add     w5, w5, #1
    b       8f
17: cbz     w5, 18f
    sub     w5, w5, #1
    b       8f
18: mov     w4, #0
    b       8f
5:  cmp     w3, #2
    csel    w3, wzr, w3, eq
    cmp     w23, #K_KEYWORD
    b.ne    6f
    cmp     w24, #15
    b.ne    51f
    bl      c_scan_inner
    cbnz    w2, 8f
    mov     w3, #1
    orr     w6, w6, w27                 // at a statement's start (or a line's): a declaration, and its name is a variable here
    cbz     w6, 8f
    mov     w4, #3
    b       8f
51: cbnz    w2, 8f
    cmp     w24, #28
    b.eq    52f
    cmp     w24, #33
    b.eq    52f
    cmp     w24, #4
    b.ne    53f
52: mov     w4, #2
    mov     w5, #0
    b       8f
53: cmp     w24, #10                    // after else and do a statement starts
    b.eq    54f
    cmp     w24, #9
    b.ne    55f
54: mov     w7, #1
    b       8f
55: cbnz    w5, 8f
    cmp     w24, #18                    // in, of: the list is over
    b.eq    56f
    cmp     w24, #37
    b.ne    8f
56: mov     w4, #0
    b       8f
6:  cmp     w23, #K_NAME
    b.ne    8f
    cbnz    w2, 8f
    cmp     w4, #2
    b.lo    8f
    cset    w4, eq
    stp     w1, w2, [sp]
    stp     w3, w4, [sp, #8]
    stp     w5, w7, [sp, #16]
    bl      c_declare
    b       1b
8:  stp     w1, w2, [sp]
    stp     w3, w4, [sp, #8]
    stp     w5, w7, [sp, #16]
    b       1b
9:  ldr     x22, [sp, #24]
    ldr     w28, [sp, #32]
    bl      next_word
    ldr     x30, [sp, #40]
    add     sp, sp, #48
    ret
c_scan_inner:                           // marks the function being translated as having inner functions. Uses x9, x10.
    ldr     x9, [x29, #F_FUNC]
    mov     x10, #1
    str     x10, [x9, #R_FLAGS]
    ret
// c_function: a function, translated where it stands (jumped over when the program runs through), and its plan made a
// constant. w0 says which kind: 0 after the word "function" in an expression, 1 the same as a declaration (its making waits
// for the scope's start, see c_hoist; nothing is written here), 2 an arrow whose one parameter is the current word, 3 an
// arrow whose parameters start at the current (. For 0, 2 and 3 the function is left on the machine's stack.
// Its frame: 8 the kind; 16-63 the record; 64 the loop outside, 72 the waiting list as it was, 80 and 88 its own name,
// 96 a declaration's variable (its reading instruction), 104 the variable holding itself (a named expression) plus one,
// 112 the jump over it, 120 the jump to its declared functions' making, 128 where the body proper starts.
c_function:
    stp     x30, x0, [sp, #-240]!
    DEEPER
    stp     xzr, xzr, [sp, #224]        // 224: it has pattern parameters (then: how many names its defaults may see); 232: kept
    stp     xzr, xzr, [sp, #208]        // 208: it has defaults; 216: its last parameter gathers the rest (flag 4)
    ldr     x9, [x29, #F_FUNC]
    str     x9, [sp, #16 + R_PARENT]
    ldr     x9, [x29, #F_NTOP]
    str     x9, [sp, #16 + R_NAMES]
    stp     xzr, xzr, [sp, #16 + R_COUNT]
    ldr     x9, [x29, #F_LOOP]
    ldr     x10, [x29, #F_PTOP]
    stp     x9, x10, [sp, #64]
    stp     xzr, xzr, [sp, #80]
    mov     x9, #-1
    stp     x9, xzr, [sp, #96]
    ldr     w9, [sp, #8]
    cmp     w9, #1
    b.hi    2f
    cmp     w23, #K_NAME
    b.ne    1f
    stp     x25, x26, [sp, #80]
    cbz     w9, 11f
    bl      c_declref                   // a declaration's name belongs to the scope outside
    str     x0, [sp, #96]
11: bl      next_word
    b       2f
1:  cbnz    w9, c_unexpected
2:  add     x9, sp, #16
    str     x9, [x29, #F_FUNC]
    str     xzr, [x29, #F_LOOP]
    ldr     w9, [sp, #8]
    cmp     w9, #2
    b.ne    3f
    bl      c_declare
    bl      next_word
    b       5f
3:  EXPECT  35
    stp     x22, x25, [sp, #144]        // the reader's place at the first parameter, for c_defaults
    stp     x26, x23, [sp, #160]
    stp     x24, x27, [sp, #176]
    str     x28, [sp, #192]
    str     d8, [sp, #200]
31: mov     w9, #36
    cmp     w23, #K_PUNCT
    ccmp    w24, w9, #0, eq
    b.eq    4f
    cmp     w23, #K_PUNCT               // ...name: the rest, and it must be the last
    b.ne    34f
    cmp     w24, #1
    b.ne    34f
    bl      next_word
    cmp     w23, #K_NAME
    b.ne    c_notyet
    bl      c_declare
    mov     x9, #4
    str     x9, [sp, #216]
    bl      next_word
    b       32f
34: cmp     w23, #K_PUNCT               // a pattern: a parameter without a name holds the value; the pattern is stepped
    b.ne    341f                        // over now and taken apart by c_defaults
    cmp     w24, #33
    b.eq    342f
    cmp     w24, #37
    b.ne    c_unexpected
342:
    bl      c_hidden
    mov     x9, #1
    str     x9, [sp, #208]
    str     x9, [sp, #224]
    bl      c_skip_pattern
    b       35f
341:
    cmp     w23, #K_NAME
    b.ne    c_unexpected
    bl      c_declare
    bl      next_word
35: ISP     55, 33f                     // a default: stepped over now (noting inner functions), translated by c_defaults
    mov     x9, #1
    str     x9, [sp, #208]
    bl      next_word
    bl      c_scan_expr
    bl      c_skip_default
33: ISP     40, 32f
    bl      next_word
    b       31b
32: ISP     36, c_notyet
4:  bl      next_word
5:  ldr     x9, [sp, #16 + R_COUNT]
    str     x9, [sp, #16 + R_PARAMS]
    ldr     x9, [sp, #224]              // pattern parameters: the names inside them are declared now, after the parameters,
    cbz     x9, 59f                     // by translating the patterns once and throwing the instructions away
    LEXSAVE
    add     x9, sp, #(144 + 64)
    ldp     x22, x25, [x9]
    ldp     x26, x23, [x9, #16]
    ldp     x24, x27, [x9, #32]
    ldr     x28, [x9, #48]
    ldr     d8, [x9, #56]
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #(232 + 64)]
51: cmp     w23, #K_PUNCT
    b.ne    53f
    cmp     w24, #36
    b.eq    58f
    cmp     w24, #1
    b.ne    52f
    bl      next_word
    b       51b
52: cmp     w24, #33
    b.eq    521f
    cmp     w24, #37
    b.ne    53f
521:
    mov     w0, #1
    bl      c_pattern
    b       54f
53: bl      next_word
54: ISP     55, 55f
    bl      next_word
    bl      c_skip_default
55: ISP     40, 58f
    bl      next_word
    b       51b
58: ldr     x9, [sp, #(232 + 64)]
    str     x9, [x29, #F_LEN]
    NOLV
    LEXBACK
    ldr     x9, [sp, #16 + R_COUNT]
    str     x9, [sp, #224]
59:
    ldr     w9, [sp, #8]
    cmp     w9, #2
    b.lo    6f
    cmp     w9, #4                      // (4: a method written short in an object: no arrow)
    b.eq    6f
    EXPECT  11
6:  ldr     w9, [sp, #8]                // a named function expression can call itself by its name
    ldr     x10, [sp, #88]
    cbnz    w9, 61f
    cbz     x10, 61f
    stp     x25, x26, [sp, #128]
    ldp     x25, x26, [sp, #80]
    bl      c_declare
    ldp     x25, x26, [sp, #128]
    ldr     x9, [sp, #16 + R_PARAMS]
    cmp     x0, x9
    b.lo    61f
    add     x0, x0, #1
    str     x0, [sp, #104]
61: mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #112]
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #16 + R_START]
    ISP     33, 8f
    bl      c_scan_block
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #120]
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #128]
    ldr     x9, [sp, #104]
    cbz     x9, 7f
    OP      OP_CALLEE
    ldr     x9, [sp, #104]
    sub     w9, w9, #1
    mov     w0, #OP_SETL
    orr     w0, w0, w9, lsl #8
    bl      c_raw
    OP      OP_POP
7:  ldr     x9, [sp, #208]
    cbz     x9, 70f
    add     x0, sp, #144
    bl      c_defaults
70: mov     w9, #34
    cmp     w23, #K_PUNCT
    ccmp    w24, w9, #0, eq
    b.eq    71f
    cbz     w23, c_unexpected
    bl      c_stmt
    b       70b
71: OP      OP_UNDEF
    OP      OP_RET
    ldr     x0, [sp, #120]
    bl      c_patch
    ldr     x0, [sp, #72]
    bl      c_hoist
    mov     w0, #OP_JMP
    ldr     x1, [sp, #128]
    bl      c_jump_to
    mov     w9, #1
    str     w9, [sp, #12]               // (a body in braces: its } is still the current word)
    b       9f
8:  ldr     w9, [sp, #8]
    sub     w9, w9, #2
    cmp     w9, #1
    b.hi    c_unexpected
    bl      c_scan_expr
    ldr     x9, [sp, #208]
    cbz     x9, 81f
    add     x0, sp, #144
    bl      c_defaults
81: bl      c_assign
    OP      OP_RET
    str     wzr, [sp, #12]
9:  ldr     x0, [sp, #112]
    bl      c_patch
    mov     x0, #40
    bl      w_alloc
    cbz     x0, c_full
    add     x9, x19, x0
    mov     x10, #2
    str     x10, [x9]
    ldr     x10, [sp, #16 + R_START]
    str     x10, [x9, #8]
    ldr     x10, [sp, #16 + R_PARAMS]
    str     w10, [x9, #16]
    ldr     x10, [sp, #16 + R_COUNT]
    str     w10, [x9, #20]
    ldr     x10, [sp, #16 + R_FLAGS]
    ldr     w11, [sp, #8]               // an arrow (flag 2) takes its `this` from where it was made
    sub     w11, w11, #2
    cmp     w11, #1
    b.hi    90f
    orr     x10, x10, #2
90: ldr     x11, [sp, #216]
    orr     x10, x10, x11
    str     x10, [x9, #24]
    VAL     x10, T_UNDEF
    str     x10, [x9, #32]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    ldr     x9, [sp, #16 + R_NAMES]
    str     x9, [x29, #F_NTOP]
    ldr     x9, [sp, #16 + R_PARENT]
    str     x9, [x29, #F_FUNC]
    ldr     x9, [sp, #64]
    str     x9, [x29, #F_LOOP]
    bl      c_addconst
    ldr     w9, [sp, #8]
    cmp     w9, #1
    b.ne    91f
    ldr     x9, [x29, #F_PTOP]          // a declaration: it waits for the scope's start
    sub     x9, x9, #16
    ldr     x10, [x29, #F_NTOP]
    cmp     x9, x10
    b.lo    c_toobig
    ldr     x10, [sp, #96]
    stp     x0, x10, [x9]
    str     x9, [x29, #F_PTOP]
    b       92f
91: mov     w1, w0
    mov     w0, #OP_CLOSURE
    bl      c_op16
92: ldr     w9, [sp, #12]
    cbz     w9, 93f
    bl      next_word
93: NOLV
    SHALLOWER
    ldr     x30, [sp], #240
    ret
// c_skip_default: steps over a parameter's default, from its first word to the , or ) that ends it (left as the current word)
c_skip_default:
    stp     x30, xzr, [sp, #-16]!
1:  cbz     w23, c_unexpected
    cmp     w23, #K_PUNCT
    b.ne    6f
    ldr     w10, [sp, #8]
    sub     w9, w24, #33
    cmp     w9, #5
    b.hi    3f
    tbz     w24, #0, 2f
    add     w10, w10, #1
    b       4f
2:  subs    w10, w10, #1
    b.lt    8f
4:  str     w10, [sp, #8]
    b       6f
3:  cmp     w24, #40
    b.ne    6f
    cbz     w10, 8f
6:  bl      next_word
    b       1b
8:  ldr     x30, [sp], #16
    ret
// c_defaults: the parameters' defaults, translated at the body's start (when it is known where the variables live): the reader
// goes back to the first parameter (its place kept at x0), and for each one with a default: if it holds undefined, the
// default is worked out and stored. Then the reader is put back. Kept at sp+64: 8 the place, 16 the variable, 24 the jump.
c_defaults:
    stp     x30, x0, [sp, #-48]!
    LEXSAVE
    ldr     x9, [x29, #F_FUNC]          // a default sees the parameters, not the body's variables
    ldr     x10, [x9, #R_COUNT]
    str     x10, [sp, #96]
    ldr     x10, [x9, #R_PARAMS]
    ldr     x11, [sp, #72]
    ldr     x11, [x11, #80]             // (with pattern parameters: their names as well)
    cmp     x11, #0
    csel    x10, x11, x10, ne
    str     x10, [x9, #R_COUNT]
    str     xzr, [sp, #104]             // which parameter
    ldr     x9, [sp, #72]
    ldp     x22, x25, [x9]
    ldp     x26, x23, [x9, #16]
    ldp     x24, x27, [x9, #32]
    ldr     x28, [x9, #48]
    ldr     d8, [x9, #56]
1:  cmp     w23, #K_PUNCT
    b.ne    10f
    cmp     w24, #33
    b.eq    11f
    cmp     w24, #37
    b.ne    9f
11: ldr     w9, [sp, #104]              // a pattern: the nameless parameter's value (or its default) is taken apart
    mov     w0, #OP_GETL
    orr     w0, w0, w9, lsl #8
    bl      c_raw
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #88]
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #80]
    mov     w0, #1
    bl      c_pattern
    mov     w0, #OP_JMP
    bl      c_jump
    ldr     x9, [sp, #88]
    str     x0, [sp, #88]
    mov     x0, x9
    bl      c_patch
    ISP     55, 12f
    bl      next_word
    OP      OP_DUP
    OP      OP_UNDEF
    OP      OP_SEQ
    mov     w0, #OP_JF
    ldr     x1, [sp, #80]
    bl      c_jump_to
    OP      OP_POP
    bl      c_assign
12: mov     w0, #OP_JMP
    ldr     x1, [sp, #80]
    bl      c_jump_to
    ldr     x0, [sp, #88]
    bl      c_patch
    OP      OP_POP
    NOLV
    b       3f
10: cmp     w23, #K_NAME
    b.ne    9f
    bl      c_declare
    str     x0, [sp, #80]
    bl      next_word
    ISP     55, 3f
    bl      next_word
    ldr     w9, [sp, #80]
    mov     w0, #OP_GETL
    orr     w0, w0, w9, lsl #8
    bl      c_raw
    OP      OP_UNDEF
    OP      OP_SEQ
    mov     w0, #OP_JF
    bl      c_jump
    str     x0, [sp, #88]
    bl      c_assign
    ldr     w9, [sp, #80]
    mov     w0, #OP_SETL
    orr     w0, w0, w9, lsl #8
    bl      c_raw
    OP      OP_POP
    ldr     x0, [sp, #88]
    bl      c_patch
    NOLV
3:  ldr     x9, [sp, #104]
    add     x9, x9, #1
    str     x9, [sp, #104]
    ISP     40, 9f
    bl      next_word
    b       1b
9:  ldr     x9, [x29, #F_FUNC]
    ldr     x10, [sp, #96]
    str     x10, [x9, #R_COUNT]
    LEXBACK
    ldr     x30, [sp], #48
    ret
// c_string: the quoted string that is the current word, its escapes worked out -> x0 a string value
c_hexv:                                 // the hex digit w6 -> w6 its worth. Uses w7.
    sub     w7, w6, #'0'
    cmp     w7, #9
    b.ls    1f
    orr     w7, w6, #0x20
    sub     w7, w7, #'a'
    cmp     w7, #5
    b.hi    c_unexpected
    add     w7, w7, #10
1:  mov     w6, w7
    ret
c_hex4:                                 // four hex digits at x3 (before x4) -> w5. Uses w6-w8, x16.
    mov     x16, x30
    mov     w5, #0
    mov     w8, #4
1:  cmp     x3, x4
    b.hs    c_unexpected
    ldrb    w6, [x3], #1
    bl      c_hexv
    add     w5, w6, w5, lsl #4
    subs    w8, w8, #1
    b.ne    1b
    ret     x16
c_string:
    str     x30, [sp, #-16]!
    add     x0, x26, #8
    bl      w_alloc
    cbz     x0, c_full
    add     x1, x19, x0
    add     x2, x1, #8                  // where the next byte goes
    add     x3, x20, x25
    add     x4, x3, x26
    sub     x4, x4, #1                  // the closing quote
    add     x3, x3, #1
1:  cmp     x3, x4
    b.hs    8f
    ldrb    w5, [x3], #1
    cmp     w5, #'\\'
    b.eq    2f
10: strb    w5, [x2], #1
    b       1b
2:  cmp     x3, x4
    b.hs    8f
    ldrb    w5, [x3], #1
    adr     x6, c_escapes
3:  ldrb    w7, [x6], #2
    cbz     w7, 4f
    cmp     w7, w5
    b.ne    3b
    ldrb    w5, [x6, #-1]
    b       10b
4:  cmp     w5, #'0'
    b.ne    5f
    mov     w5, #0
    b       10b
5:  cmp     w5, #10                     // a backslash before a line end: the string goes on, nothing is added
    b.eq    1b
    cmp     w5, #13
    b.ne    6f
    cmp     x3, x4
    b.hs    1b
    ldrb    w6, [x3]
    cmp     w6, #10
    cinc    x3, x3, eq
    b       1b
6:  cmp     w5, #0xe2
    b.ne    7f
    add     x6, x3, #2
    cmp     x6, x4
    b.hi    10b
    ldrb    w6, [x3]
    cmp     w6, #0x80
    b.ne    10b
    ldrb    w6, [x3, #1]
    and     w6, w6, #0xfe
    cmp     w6, #0xa8
    b.ne    10b
    add     x3, x3, #2
    b       1b
7:  cmp     w5, #'x'
    b.ne    20f
    cmp     x3, x4
    b.hs    c_unexpected
    ldrb    w6, [x3], #1
    bl      c_hexv
    mov     w5, w6
    cmp     x3, x4
    b.hs    c_unexpected
    ldrb    w6, [x3], #1
    bl      c_hexv
    add     w5, w6, w5, lsl #4
    b       30f
20: cmp     w5, #'u'
    b.ne    10b                         // any other character stands for itself
    cmp     x3, x4
    b.hs    c_unexpected
    ldrb    w6, [x3]
    cmp     w6, #'{'
    b.ne    22f
    add     x3, x3, #1
    mov     w5, #0
21: cmp     x3, x4
    b.hs    c_unexpected
    ldrb    w6, [x3], #1
    cmp     w6, #'}'
    b.eq    30f
    bl      c_hexv
    add     w5, w6, w5, lsl #4
    cmp     w5, #0x110000
    b.hs    c_unexpected
    b       21b
22: bl      c_hex4
    mov     w7, #0xd800                 // the first half of a pair, with its second half right after: one character
    sub     w6, w5, w7
    cmp     w6, #0x3ff
    b.hi    30f
    add     x7, x3, #6
    cmp     x7, x4
    b.hi    30f
    ldrb    w6, [x3]
    cmp     w6, #'\\'
    b.ne    30f
    ldrb    w6, [x3, #1]
    cmp     w6, #'u'
    b.ne    30f
    ldrb    w6, [x3, #2]
    cmp     w6, #'{'
    b.eq    30f
    mov     x17, x3
    mov     w14, w5
    add     x3, x3, #2
    bl      c_hex4
    mov     w7, #0xdc00
    sub     w6, w5, w7
    cmp     w6, #0x3ff
    b.hi    23f
    mov     w7, #0xd800
    sub     w14, w14, w7
    add     w5, w6, w14, lsl #10
    add     w5, w5, #0x10000
    b       30f
23: mov     x3, x17
    mov     w5, w14
30: cmp     w5, #0x80                   // the character w5 as UTF-8
    b.lo    10b
    cmp     w5, #0x800
    b.hs    31f
    lsr     w6, w5, #6
    orr     w6, w6, #0xc0
    strb    w6, [x2], #1
    b       34f
31: cmp     w5, #0x10000
    b.hs    32f
    lsr     w6, w5, #12
    orr     w6, w6, #0xe0
    strb    w6, [x2], #1
    b       33f
32: lsr     w6, w5, #18
    orr     w6, w6, #0xf0
    strb    w6, [x2], #1
    ubfx    w6, w5, #12, #6
    orr     w6, w6, #0x80
    strb    w6, [x2], #1
33: ubfx    w6, w5, #6, #6
    orr     w6, w6, #0x80
    strb    w6, [x2], #1
34: and     w6, w5, #0x3f
    orr     w6, w6, #0x80
    strb    w6, [x2], #1
    b       1b
8:  add     x5, x1, #8
    sub     x5, x2, x5
    str     x5, [x1]
    add     x5, x5, #15                 // the room the escapes did not need goes back
    and     x5, x5, #-8
    add     x5, x0, x5
    str     x5, [x19, #W_HEAP]
    ldr     x5, [x1]                    // so far it is UTF-8; with anything past ASCII in it, it is made again as units
    add     x6, x1, #8                  // (w_text) and moved down over the first copy
    mov     x7, #0
81: cmp     x7, x5
    b.hs    89f
    ldrb    w8, [x6, x7]
    add     x7, x7, #1
    tbz     w8, #7, 81b
    str     x0, [sp, #8]
    mov     x0, x6
    mov     x1, x5
    bl      w_text
    cbz     x0, c_full
    and     x0, x0, #0xffffffffffff
    ldr     x1, [sp, #8]
    ldr     x9, [x19, #W_HEAP]
    sub     x9, x9, x0
    add     x2, x19, x0
    add     x3, x19, x1
    mov     x4, #0
82: cmp     x4, x9
    b.hs    83f
    ldr     x5, [x2, x4]
    str     x5, [x3, x4]
    add     x4, x4, #8
    b       82b
83: add     x9, x1, x9
    str     x9, [x19, #W_HEAP]
    mov     x0, x1
89: orr     x0, x0, #(T_STRING << 48)
    ldr     x30, [sp], #16
    ret
c_escapes:
    .byte   'n', 10, 't', 9, 'r', 13, 'b', 8, 'f', 12, 'v', 11, 0, 0
    .balign 4

// Expressions, loosest first. Each leaves exactly one value on the machine's stack.
// c_expr: with commas
c_expr:
    str     x30, [sp, #-16]!
    bl      c_assign
1:  ISP     40, 9f
    OP      OP_POP
    bl      next_word
    bl      c_assign
    NOLV
    b       1b
9:  ldr     x30, [sp], #16
    ret
// c_assign: an assignment, or anything tighter
c_assign:
    stp     x30, xzr, [sp, #-32]!
    cmp     w23, #K_PUNCT               // [a, b] = v and {a, b} = v: a pattern if an = follows its closing bracket
    b.ne    0f
    cmp     w24, #33
    b.eq    77f
    cmp     w24, #37
    b.ne    0f
77: bl      c_peek_pattern
    b.ne    0f
    mov     w0, #0
    bl      c_destructure
    b       9f
0:  bl      c_cond
    cmp     w23, #K_PUNCT
    b.ne    9f
    adr     x9, c_asg
    ldrb    w10, [x9, x24]
    cbz     w10, 9f
    str     w10, [sp, #12]
    bl      c_lvalue
    str     w0, [sp, #8]
    ldr     w10, [sp, #12]
    cmp     w10, #255
    b.ne    2f
    ldr     x9, [x29, #F_LV]            // plain =: the read that was written is taken back
    str     x9, [x29, #F_LEN]
    bl      next_word
    bl      c_assign
    b       7f
2:  cmp     w10, #OP_JFK
    b.lo    4f
    ldr     w9, [sp, #8]                // (on a property: to come)
    and     w9, w9, #0xff
    sub     w9, w9, #OP_GETP
    cmp     w9, #3
    b.ls    c_notyet
    mov     w0, w10                     // &&= ||= ??=: the right side is worked out, and kept, only if needed
    bl      c_jump
    str     x0, [sp, #16]
    bl      next_word
    bl      c_assign
    ldr     w0, [sp, #8]
    bl      c_store
    ldr     x0, [sp, #16]
    bl      c_patch
    b       8f
4:  ldr     w0, [sp, #8]
    bl      c_lvdup
    bl      next_word
    bl      c_assign
    ldr     w0, [sp, #12]
    bl      c_byte
7:  ldr     w0, [sp, #8]
    bl      c_store
8:  NOLV
9:  ldr     x30, [sp], #32
    ret
// c_cond: a ? b : c
c_cond:
    stp     x30, xzr, [sp, #-32]!
    mov     w0, #1
    bl      c_binary
    ISP     53, 9f
    mov     w0, #OP_JF
    bl      c_jump
    str     x0, [sp, #8]
    bl      next_word
    bl      c_assign
    EXPECT  54
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #16]
    ldr     x0, [sp, #8]
    bl      c_patch
    bl      c_assign
    ldr     x0, [sp, #16]
    bl      c_patch
    NOLV
9:  ldr     x30, [sp], #32
    ret
// c_binary: operators between two values that bind at least as tightly as w0
c_binary:
    stp     x30, x0, [sp, #-32]!
    bl      c_unary
1:  cmp     w23, #K_KEYWORD             // in and instanceof bind as the comparisons do
    b.ne    10f
    mov     w10, #8
    mov     w11, #OP_IN
    cmp     w24, #18
    b.eq    11f
    mov     w11, #OP_INSTOF
    cmp     w24, #19
    b.ne    9f
    b       11f
10: cmp     w23, #K_PUNCT
    b.ne    9f
    adr     x9, c_prec
    add     x9, x9, x24, lsl #1
    ldrb    w10, [x9]
    ldrb    w11, [x9, #1]
    cbz     w10, 9f
11:
    ldr     w12, [sp, #8]
    cmp     w10, w12
    b.lo    9f
    stp     w10, w11, [sp, #16]
    cmp     w10, #3
    b.hi    3f
    mov     w0, w11                     // && || ??: the right side is skipped when the left decides
    bl      c_jump
    str     x0, [sp, #24]
    bl      next_word
    ldr     w0, [sp, #16]
    add     w0, w0, #1
    bl      c_binary
    ldr     x0, [sp, #24]
    bl      c_patch
    NOLV
    b       1b
3:  bl      next_word
    ldr     w0, [sp, #16]
    cmp     w0, #12                     // ** groups from the right
    cinc    w0, w0, ne
    bl      c_binary
    ldr     w0, [sp, #20]
    bl      c_byte
    b       1b
9:  ldr     x30, [sp], #32
    ret
// c_unary: operators before a value
c_unary:
    stp     x30, xzr, [sp, #-32]!
    DEEPER
    cmp     w23, #K_PUNCT
    b.ne    5f
    mov     w0, #OP_NEG
    cmp     w24, #44
    b.eq    1f
    mov     w0, #OP_PLUS
    cmp     w24, #43
    b.eq    1f
    mov     w0, #OP_NOT
    cmp     w24, #51
    b.eq    1f
    mov     w0, #OP_BITNOT
    cmp     w24, #52
    b.eq    1f
    cmp     w24, #20
    b.eq    2f
    cmp     w24, #21
    b.ne    6f
2:  str     w24, [sp, #8]               // ++x, --x: the new value is the result
    bl      next_word
    bl      c_unary
    bl      c_lvalue
    bl      c_lvdup
    str     w0, [sp, #16]
    OP      OP_PLUS
    fmov    d0, #1.0
    fmov    x0, d0
    bl      c_const
    ldr     w9, [sp, #8]
    mov     w0, #OP_ADD
    mov     w10, #OP_SUB
    cmp     w9, #20
    csel    w0, w0, w10, eq
    bl      c_byte
    ldr     w0, [sp, #16]
    bl      c_store
    b       9f
5:  cmp     w23, #K_KEYWORD
    b.ne    6f
    cmp     w24, #8
    b.ne    50f
    bl      next_word                   // delete o.name, delete o[key]: the read just written becomes the removal
    bl      c_unary
    bl      c_lvalue
    ldr     x9, [x29, #F_LV]
    str     x9, [x29, #F_LEN]
    and     w9, w0, #0xff
    cmp     w9, #OP_GETE
    b.eq    51f
    cmp     w9, #OP_GETP
    b.ne    c_notyet
    and     w0, w0, #0xffffff00
    mov     w9, #OP_DELP
    orr     w0, w0, w9
    bl      c_raw
    NOLV
    b       9f
51: OP      OP_DELE
    NOLV
    b       9f
50: mov     w0, #OP_TYPEOF
    cmp     w24, #27
    b.eq    1f
    mov     w0, #OP_VOID
    cmp     w24, #29
    b.ne    6f
1:  str     w0, [sp, #8]
    bl      next_word
    bl      c_unary
    ldr     w9, [sp, #8]                // typeof of a bare global name must not mind its never having been declared
    cmp     w9, #OP_TYPEOF
    b.ne    2f
    ldr     x9, [x29, #F_LV]
    cmn     x9, #1
    b.eq    2f
    ldr     x10, [x29, #F_CODE]
    ldrb    w11, [x10, x9]
    cmp     w11, #OP_GETG
    b.ne    2f
    mov     w11, #OP_GETGQ
    strb    w11, [x10, x9]
2:
    ldr     w0, [sp, #8]
    bl      c_byte
    b       9f
6:  bl      c_postfix
9:  SHALLOWER
    ldr     x30, [sp], #32
    ret
// c_postfix: x++ and x-- (the old value, as a number, is the result)
c_postfix:
    stp     x30, xzr, [sp, #-16]!
    ISK     20, 10f
    bl      c_new
    b       2f
10: bl      c_primary
2:  ISP     35, 20f                     // f(a, b): any number of times; o.m(a) and o[k](a) are calls on o
    bl      c_method
    str     w0, [sp, #12]
    bl      next_word
    bl      c_args
    tbnz    w0, #31, 21f
    str     w0, [sp, #8]
    ldr     w0, [sp, #12]
    bl      c_byte
    ldr     w0, [sp, #8]
    bl      c_byte
    b       22f
21: OP      OP_APPLY                    // some argument was spread: they are in an array
    ldr     w0, [sp, #12]
    cmp     w0, #OP_CALLM
    cset    w0, eq
    bl      c_byte
22: NOLV
    b       2b
20: bl      c_member                    // o.name and o[key]
    cbnz    w0, 2b
5:  cmp     w23, #K_PUNCT
    b.ne    9f
    cmp     w24, #20
    b.eq    1f
    cmp     w24, #21
    b.ne    9f
1:  cbnz    w27, 9f                     // after a line end it belongs to what follows
    bl      c_lvalue
    bl      c_lvdup
    str     w0, [sp, #8]
    OP      OP_PLUS
    ldr     w9, [sp, #8]                // the old value is kept under whatever the store needs
    and     w9, w9, #0xff
    cmp     w9, #OP_GETP
    b.eq    11f
    cmp     w9, #OP_GETE
    b.eq    12f
    OP      OP_DUP
    b       13f
11: OP      OP_SWAP
    OP      OP_PICK
    mov     w0, #1
    bl      c_byte
    b       13f
12: OP      OP_ROT
    OP      OP_PICK
    mov     w0, #2
    bl      c_byte
13:
    fmov    d0, #1.0
    fmov    x0, d0
    bl      c_const
    mov     w0, #OP_ADD
    mov     w10, #OP_SUB
    cmp     w24, #20
    csel    w0, w0, w10, eq
    bl      c_byte
    ldr     w0, [sp, #8]
    bl      c_store
    OP      OP_POP
    bl      next_word
9:  ldr     x30, [sp], #16
    ret
// c_method: a call is about to be written: if what was just read is a property, the object stays under the function to be
// its `this` -> w0 the calling instruction to use
c_method:
    mov     w0, #OP_CALL
    ldr     x9, [x29, #F_LV]
    cmp     x9, #0
    b.lt    9f
    ldr     x11, [x29, #F_CODE]
    ldr     w12, [x11, x9]
    and     w13, w12, #0xff
    ldr     x10, [x29, #F_LEN]
    cmp     w13, #OP_GETP
    b.ne    1f
    add     x14, x9, #3
    cmp     x14, x10
    b.ne    9f
    str     x30, [sp, #-16]!
    str     x9, [x29, #F_LEN]
    and     w12, w12, #0xffffff
    str     w12, [sp, #8]
    OP      OP_DUP
    ldr     w0, [sp, #8]
    bl      c_raw
    ldr     x30, [sp], #16
    mov     w0, #OP_CALLM
    ret
1:  cmp     w13, #OP_GETE
    b.ne    9f
    add     x14, x9, #1
    cmp     x14, x10
    b.ne    9f
    mov     w12, #OP_GETEK
    strb    w12, [x11, x9]
    mov     w0, #OP_CALLM
9:  ret
// c_member: .name or [key] after a value, if that is what comes -> w0 1 if one was taken
c_member:
    cmp     w23, #K_PUNCT
    b.ne    9f
    cmp     w24, #56
    b.eq    1f
    cmp     w24, #37
    b.eq    2f
9:  mov     w0, #0
    ret
1:  str     x30, [sp, #-16]!
    bl      next_word
    cmp     w23, #K_NAME
    b.eq    11f
    cmp     w23, #K_KEYWORD
    b.ne    c_unexpected
11: bl      c_wordconst
    mov     w1, w0
    ldr     x9, [x29, #F_LEN]
    str     x9, [x29, #F_LV]
    mov     w0, #OP_GETP
    bl      c_op16
    bl      next_word
    b       8f
2:  str     x30, [sp, #-16]!
    bl      next_word
    bl      c_expr
    ISP     38, c_unexpected
    ldr     x9, [x29, #F_LEN]
    str     x9, [x29, #F_LV]
    OP      OP_GETE
    bl      next_word
8:  mov     w0, #1
    ldr     x30, [sp], #16
    ret
// c_new: new F(a, b): the function (a value and its properties, no calls), then the arguments if there are any
c_new:
    stp     x30, xzr, [sp, #-16]!
    bl      next_word
    ISK     20, 1f
    bl      c_new
    b       2f
1:  bl      c_primary
2:  bl      c_member
    cbnz    w0, 2b
    ISP     35, 6f
    bl      next_word
    bl      c_args
    tbnz    w0, #31, 7f
    str     w0, [sp, #8]
6:  OP      OP_NEW
    ldr     w0, [sp, #8]
    bl      c_byte
    b       8f
7:  OP      OP_APPLY
    mov     w0, #2
    bl      c_byte
8:  NOLV
    ldr     x30, [sp], #16
    ret
// c_peek_acc: the current word is get or set: does a property's name follow (and not : ( , or }) -> flags: eq if so
c_peek_acc:
    str     x30, [sp, #-16]!
    LEXSAVE
    bl      next_word
    mov     w0, #0
    cbz     w23, 1f
    mov     w0, #1
    cmp     w23, #K_PUNCT
    b.ne    1f
    cmp     w24, #37
    cset    w0, eq
1:  LEXBACK
    ldr     x30, [sp], #16
    cmp     w0, #1
    ret
// c_propkey: a property's name where one is being defined (a word, a string, a number, or [worked out]) -> instructions
// that leave it on the stack; steps past it
c_propkey:
    str     x30, [sp, #-16]!
    cmp     w23, #K_PUNCT
    b.ne    1f
    cmp     w24, #37
    b.ne    c_unexpected
    bl      next_word
    bl      c_assign
    ISP     38, c_unexpected
    b       8f
1:  cmp     w23, #K_NUMBER
    b.ne    2f
    fmov    x0, d8
    bl      c_const
    b       8f
2:  cmp     w23, #K_STRING
    b.ne    3f
    bl      c_string
    bl      c_strconst
    b       8f
3:  cmp     w23, #K_NAME
    b.eq    4f
    cmp     w23, #K_KEYWORD
    b.ne    c_unexpected
4:  bl      c_wordconst
    mov     w1, w0
    mov     w0, #OP_CONST
    bl      c_op16
8:  bl      next_word
    ldr     x30, [sp], #16
    ret
// c_object: { name: value, "text": value, 3: value, [key]: value, name, name(a) { } } -> the object. The } stays the current word.
// Kept: 8 the name's constant, 16 and 24 the name's word, 32 its kind, 40 and 48 the word after it.
c_object:
    stp     x30, xzr, [sp, #-64]!
    DEEPER
    OP      OP_OBJECT
    bl      next_word
1:  cmp     w23, #K_PUNCT
    b.ne    2f
    cmp     w24, #34
    b.eq    9f
    cmp     w24, #37
    b.ne    c_notyet                    // spread: to come
    bl      next_word
    bl      c_assign
    EXPECT  38
    EXPECT  54
    bl      c_assign
    OP      OP_INITE
    b       7f
2:  stp     x25, x26, [sp, #16]
    str     w23, [sp, #32]
    cmp     w23, #K_KEYWORD             // get name() { } and set name(v) { }
    b.ne    20f
    sub     w9, w24, #38
    cmp     w9, #1
    b.hi    20f
    str     w9, [sp, #36]
    bl      c_peek_acc
    b.ne    20f
    bl      next_word
    bl      c_propkey
    mov     w0, #4
    bl      c_function
    OP      OP_DEFACC
    ldr     w0, [sp, #36]
    bl      c_byte
    b       7f
20: cmp     w23, #K_NAME
    b.eq    3f
    cmp     w23, #K_KEYWORD
    b.eq    3f
    cmp     w23, #K_STRING
    b.ne    21f
    bl      c_string
    bl      c_keyconst
    b       4f
21: cmp     w23, #K_NUMBER
    b.ne    c_unexpected
    fmov    x0, d8
    bl      v_text
    cbz     x0, c_full
    bl      c_keyconst
    b       4f
3:  bl      c_wordconst
4:  str     w0, [sp, #8]
    bl      next_word
    ISP     54, 5f
    bl      next_word
    bl      c_assign
    b       6f
5:  ISP     35, 51f
    mov     w0, #4
    bl      c_function
    b       6f
51: ldr     w9, [sp, #32]               // the name alone: the variable of that name
    cmp     w9, #K_NAME
    b.ne    c_notyet                    // (get and set: to come)
    cmp     w23, #K_PUNCT
    b.ne    c_notyet
    stp     x25, x26, [sp, #40]
    ldp     x25, x26, [sp, #16]
    bl      c_ref
    bl      c_raw
    ldp     x25, x26, [sp, #40]
6:  ldr     w1, [sp, #8]
    mov     w0, #OP_INITP
    bl      c_op16
7:  ISP     40, 8f
    bl      next_word
    b       1b
8:  ISP     34, c_unexpected
9:  NOLV
    SHALLOWER
    ldr     x30, [sp], #64
    ret
// c_array: [a, b, c] -> the array. The ] stays the current word.
c_array:
    stp     x30, xzr, [sp, #-16]!
    DEEPER
    bl      next_word
1:  cmp     w23, #K_PUNCT
    b.ne    2f
    cmp     w24, #38
    b.eq    9f
2:  ISP     1, 4f                       // ...v: from the first of these on, the array is made and items are added to it
    ldr     w9, [sp, #12]
    cbnz    w9, 3f
    mov     w0, #OP_ARRAY
    ldr     w1, [sp, #8]
    bl      c_op16
    mov     w9, #1
    str     w9, [sp, #12]
3:  bl      next_word
    bl      c_assign
    OP      OP_SPREAD
    b       6f
4:  bl      c_assign
    ldr     w9, [sp, #12]
    cbz     w9, 5f
    OP      OP_APPEND
    b       6f
5:  ldr     w9, [sp, #8]
    add     w9, w9, #1
    str     w9, [sp, #8]
    mov     w10, #0xffff
    cmp     w9, w10
    b.hs    c_toobig
6:  ISP     40, 8f
    bl      next_word
    b       1b
8:  ISP     38, c_unexpected
9:  ldr     w9, [sp, #12]
    cbnz    w9, 91f
    mov     w0, #OP_ARRAY
    ldr     w1, [sp, #8]
    bl      c_op16
91: NOLV
    SHALLOWER
    ldr     x30, [sp], #16
    ret
// c_args: the arguments of a call, from the word after the ( to past the ) -> w0 how many are on the stack, or -1 if one
// was spread, when they are all in one array instead
c_args:
    stp     x30, xzr, [sp, #-16]!
2:  mov     w9, #36
    cmp     w23, #K_PUNCT
    ccmp    w24, w9, #0, eq
    b.eq    7f
    ISP     1, 4f
    ldr     w9, [sp, #12]
    cbnz    w9, 3f
    mov     w0, #OP_ARRAY
    ldr     w1, [sp, #8]
    bl      c_op16
    mov     w9, #1
    str     w9, [sp, #12]
3:  bl      next_word
    bl      c_assign
    OP      OP_SPREAD
    b       6f
4:  bl      c_assign
    ldr     w9, [sp, #12]
    cbz     w9, 5f
    OP      OP_APPEND
    b       6f
5:  ldr     w9, [sp, #8]
    add     w9, w9, #1
    str     w9, [sp, #8]
    cmp     w9, #255
    b.hi    c_toobig
6:  ISP     40, 7f
    bl      next_word
    b       2b
7:  EXPECT  36
    ldp     w0, w9, [sp, #8]
    cmp     w9, #0
    csinv   w0, w0, wzr, eq
    ldr     x30, [sp], #16
    ret
// c_template: `text ${value} text`: the pieces of text and the values between them, added together from the left. The reader
// gave the whole template as one word; it is sent back in to read each value. (A value is turned to text as + would, which
// differs from the language only for an object with its own way of becoming a number.) Kept: 8 pieces so far, 16 just past
// the closing mark, 24 where this piece of text ends.
c_template:
    stp     x30, xzr, [sp, #-32]!
    DEEPER
    add     x9, x25, x26
    str     x9, [sp, #16]
    add     x10, x25, #1
1:  ldr     x9, [sp, #16]
    sub     x9, x9, #1
    mov     x11, x10
2:  cmp     x11, x9
    b.hs    3f
    ldrb    w12, [x20, x11]
    cmp     w12, #'\\'
    b.ne    21f
    add     x11, x11, #2
    b       2b
21: cmp     w12, #'$'
    b.ne    22f
    add     x13, x11, #1
    cmp     x13, x9
    b.hs    22f
    ldrb    w13, [x20, x13]
    cmp     w13, #'{'
    b.eq    3f
22: add     x11, x11, #1
    b       2b
3:  cmp     x11, x9
    csel    x11, x9, x11, hi
    str     x11, [sp, #24]
    ldr     w12, [sp, #8]
    cmp     x11, x10
    b.ne    31f
    cbnz    w12, 4f                     // (an empty piece is written only if it is the first)
31: sub     x25, x10, #1
    sub     x26, x11, x10
    add     x26, x26, #2
    bl      c_string
    bl      c_strconst
    bl      5f
4:  ldr     x11, [sp, #24]
    ldr     x9, [sp, #16]
    sub     x9, x9, #1
    cmp     x11, x9
    b.hs    8f
    add     x22, x11, #2
    bl      next_word
    bl      c_expr
    ISP     34, c_unexpected
    bl      5f
    mov     x10, x22
    b       1b
5:  ldr     w12, [sp, #8]               // one more piece: added to what is there
    add     w12, w12, #1
    str     w12, [sp, #8]
    cmp     w12, #1
    b.eq    51f
    mov     w0, #OP_ADD
    b       c_byte
51: ret
8:  ldr     x22, [sp, #16]
    NOLV
    SHALLOWER
    ldr     x30, [sp], #32
    ret
// Patterns: [a, , b = 1, ...rest] and {a, b: c, "d": e = 2, [key]: f}, each target a name, a place that can be assigned to, or
// another pattern. w0 says whether names are declared (1: var, let, const, parameters) or only assigned to (0).
// c_destructure: the current word begins a pattern that an = and a value follow: the value is worked out first (the pattern's
// instructions are written before it and reached by jumping back) and is left on the stack.
c_destructure:
    stp     x30, x0, [sp, #-32]!
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #16]
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #24]
    ldr     w0, [sp, #8]
    bl      c_pattern
    mov     w0, #OP_JMP
    bl      c_jump
    ldr     x9, [sp, #16]
    str     x0, [sp, #16]
    mov     x0, x9
    bl      c_patch
    EXPECT  55
    bl      c_assign
    mov     w0, #OP_JMP
    ldr     x1, [sp, #24]
    bl      c_jump_to
    ldr     x0, [sp, #16]
    bl      c_patch
    NOLV
    ldr     x30, [sp], #32
    ret
// c_skip_pattern: from an opening bracket to the word after the one that closes it
c_skip_pattern:
    stp     x30, xzr, [sp, #-16]!
1:  cbz     w23, 8f
    cmp     w23, #K_PUNCT
    b.ne    6f
    sub     w9, w24, #33
    cmp     w9, #5
    b.hi    6f
    ldr     w10, [sp, #8]
    tbz     w24, #0, 2f
    add     w10, w10, #1
    str     w10, [sp, #8]
    b       6f
2:  sub     w10, w10, #1
    str     w10, [sp, #8]
    cbnz    w10, 6f
    bl      next_word
    b       8f
6:  bl      next_word
    b       1b
8:  ldr     x30, [sp], #16
    ret
// c_peek_pattern: is the word after the bracket that closes the current one an = -> flags: eq if so
c_peek_pattern:
    str     x30, [sp, #-16]!
    LEXSAVE
    bl      c_skip_pattern
    mov     w0, #0
    cmp     w23, #K_PUNCT
    b.ne    1f
    cmp     w24, #55
    cset    w0, eq
1:  LEXBACK
    ldr     x30, [sp], #16
    cmp     w0, #1
    ret
// c_hidden: one more variable of the function being translated, with no name (a parameter written as a pattern)
c_hidden:
    ldr     x1, [x29, #F_FUNC]
    ldr     x3, [x1, #R_NAMES]
    ldr     x4, [x1, #R_COUNT]
    add     x5, x3, x4, lsl #4
    add     x6, x5, #16
    ldr     x7, [x29, #F_PTOP]
    cmp     x6, x7
    b.hi    c_toobig
    stp     x25, xzr, [x5]
    str     x6, [x29, #F_NTOP]
    add     x4, x4, #1
    str     x4, [x1, #R_COUNT]
    ret
// c_pattern: the pattern at the current word, applied to the value on the stack (which stays); steps past its closing bracket.
// For each target: what it needs is put on the stack (an object, a key), then the item is fetched from the value under it,
// a default takes the place of undefined, and it is stored. A pattern inside is jumped back to in the same way as above.
// Kept: 8 declare?, 16 the target's reading instruction (-1 a pattern), 20 the key's kind (0 a name constant, 1 a number,
// 2 worked out and on the stack), 24 an object pattern?, 28 which item, 32 the name constant, 36 the rest?, 40 the number,
// 48 and 56 jumps, 64 and 72 a short name's word.
c_pattern:
    stp     x30, x0, [sp, #-80]!
    DEEPER
    cmp     w24, #33
    cset    w9, eq
    stp     w9, wzr, [sp, #24]
    bl      next_word
1:  ldr     w9, [sp, #24]
    mov     w10, #38
    mov     w11, #34
    cmp     w9, #0
    csel    w10, w11, w10, ne
    cmp     w23, #K_PUNCT
    b.ne    2f
    cmp     w24, w10
    b.eq    9f
    cbnz    w9, 2f
    cmp     w24, #40                    // nothing between commas: that item is passed over
    b.ne    2f
    ldr     w9, [sp, #28]
    add     w9, w9, #1
    str     w9, [sp, #28]
    bl      next_word
    b       1b
2:  str     wzr, [sp, #36]
    str     wzr, [sp, #20]
    ISP     1, 20f
    ldr     w9, [sp, #24]
    cbnz    w9, c_notyet                // (the rest of an object: to come)
    mov     w9, #1
    str     w9, [sp, #36]
    bl      next_word
    b       30f
20: ldr     w9, [sp, #24]
    cbz     w9, 30f
    cmp     w23, #K_PUNCT               // an object pattern: first the key
    b.ne    21f
    cmp     w24, #37
    b.ne    c_unexpected
    bl      next_word
    bl      c_assign
    EXPECT  38
    mov     w9, #2
    str     w9, [sp, #20]
    b       25f
21: cmp     w23, #K_STRING
    b.ne    22f
    bl      c_string
    bl      c_keyconst
    str     w0, [sp, #32]
    bl      next_word
    b       25f
22: cmp     w23, #K_NUMBER
    b.ne    23f
    str     d8, [sp, #40]
    mov     w9, #1
    str     w9, [sp, #20]
    bl      next_word
    b       25f
23: cmp     w23, #K_NAME
    b.eq    24f
    cmp     w23, #K_KEYWORD
    b.ne    c_unexpected
24: bl      c_wordconst
    str     w0, [sp, #32]
    stp     x25, x26, [sp, #64]
    bl      next_word
    ISP     54, 26f
    b       251f
25: ISP     54, c_unexpected
251:
    bl      next_word
    b       30f
26: ldp     x9, x10, [sp, #64]          // a name alone is its own target
    stp     x25, x26, [sp, #64]
    mov     x25, x9
    mov     x26, x10
    bl      70f
    str     w0, [sp, #16]
    ldp     x25, x26, [sp, #64]
    b       40f
30: cmp     w23, #K_PUNCT               // the target
    b.ne    31f
    cmp     w24, #33
    b.eq    35f
    cmp     w24, #37
    b.eq    35f
31: ldr     w9, [sp, #8]
    cbz     w9, 32f
    cmp     w23, #K_NAME
    b.eq    311f
    cmp     w23, #K_KEYWORD
    b.ne    c_unexpected
    sub     w9, w24, #33
    cmp     w9, #6
    b.hi    c_unexpected
311:
    bl      c_declref
    str     w0, [sp, #16]
    bl      next_word
    b       40f
32: bl      c_postfix                   // a place to assign to: its reading is taken back, what it reads from stays
    bl      c_lvalue
    str     w0, [sp, #16]
    ldr     x9, [x29, #F_LV]
    str     x9, [x29, #F_LEN]
    NOLV
    b       40f
35: mov     w9, #-1                     // a pattern inside
    str     w9, [sp, #16]
    bl      60f
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #48]
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #56]
    ldr     w0, [sp, #8]
    bl      c_pattern
    mov     w0, #OP_JMP
    bl      c_jump
    ldr     x9, [sp, #48]
    str     x0, [sp, #48]
    mov     x0, x9
    bl      c_patch
    ISP     55, 36f
    bl      next_word
    OP      OP_DUP
    OP      OP_UNDEF
    OP      OP_SEQ
    mov     w0, #OP_JF
    ldr     x1, [sp, #56]
    bl      c_jump_to
    OP      OP_POP
    bl      c_assign
36: mov     w0, #OP_JMP
    ldr     x1, [sp, #56]
    bl      c_jump_to
    ldr     x0, [sp, #48]
    bl      c_patch
    b       50f
40: bl      60f
    ISP     55, 45f
    bl      next_word
    OP      OP_DUP
    OP      OP_UNDEF
    OP      OP_SEQ
    mov     w0, #OP_JF
    bl      c_jump
    str     x0, [sp, #48]
    OP      OP_POP
    bl      c_assign
    ldr     x0, [sp, #48]
    bl      c_patch
45: ldr     w0, [sp, #16]
    bl      c_store
50: OP      OP_POP
    ldr     w9, [sp, #20]
    cmp     w9, #2
    b.ne    51f
    OP      OP_POP
51: NOLV
    ldr     w9, [sp, #28]
    add     w9, w9, #1
    str     w9, [sp, #28]
    ISP     40, 52f
    bl      next_word
    b       1b
52: ldr     w9, [sp, #24]
    mov     w10, #38
    mov     w11, #34
    cmp     w9, #0
    csel    w10, w11, w10, ne
    cmp     w23, #K_PUNCT
    b.ne    c_unexpected
    cmp     w24, w10
    b.ne    c_unexpected
9:  bl      next_word
    NOLV
    SHALLOWER
    ldr     x30, [sp], #80
    ret
60: str     x30, [sp, #-16]!            // the item is fetched: a copy of the value (it lies under what the target put down)
    ldr     w9, [sp, #16 + 20]
    cmp     w9, #2
    cset    w10, eq
    ldr     w9, [sp, #16 + 16]
    and     w9, w9, #0xff
    cmp     w9, #OP_GETP
    cinc    w10, w10, eq
    cmp     w9, #OP_GETE
    b.ne    61f
    add     w10, w10, #2
61: str     w10, [sp, #8]
    OP      OP_PICK
    ldr     w0, [sp, #8]
    bl      c_byte
    ldr     w9, [sp, #16 + 24]
    cbnz    w9, 63f
    ldr     w9, [sp, #16 + 36]
    cbnz    w9, 62f
    ldr     w9, [sp, #16 + 28]
    ucvtf   d0, w9
    fmov    x0, d0
    bl      c_const
    OP      OP_GETE
    b       69f
62: mov     w0, #OP_TAIL
    ldr     w1, [sp, #16 + 28]
    bl      c_op16
    b       69f
63: ldr     w9, [sp, #16 + 20]
    cbnz    w9, 64f
    mov     w0, #OP_GETP
    ldr     w1, [sp, #16 + 32]
    bl      c_op16
    b       69f
64: cmp     w9, #1
    b.ne    65f
    ldr     x0, [sp, #16 + 40]
    bl      c_const
    OP      OP_GETE
    b       69f
65: OP      OP_PICK
    ldr     w0, [sp, #8]
    bl      c_byte
    OP      OP_GETE
69: ldr     x30, [sp], #16
    ret
70: ldr     w9, [sp, #8]
    cbz     w9, c_ref
    b       c_declref
// c_super: super(a, b) calls the parent class on this same object; super.name is the property as the parent's side has it,
// and super.name(a) calls it with `this` unchanged. (Reached from c_primary, whose frame it leaves through.)
c_super:
    bl      next_word
    OP      OP_THIS
    ISP     35, 2f
    mov     w0, #OP_SUPER
    mov     w1, #0xffff
    bl      c_op16
1:  bl      next_word
    bl      c_args
    tbnz    w0, #31, 11f
    str     w0, [sp, #8]
    OP      OP_CALLM
    ldr     w0, [sp, #8]
    bl      c_byte
    b       8f
11: OP      OP_APPLY
    mov     w0, #1
    bl      c_byte
    b       8f
2:  EXPECT  56
    cmp     w23, #K_NAME
    b.eq    3f
    cmp     w23, #K_KEYWORD
    b.ne    c_unexpected
3:  bl      c_wordconst
    mov     w1, w0
    mov     w0, #OP_SUPER
    bl      c_op16
    bl      next_word
    ISP     35, 4f
    b       1b
4:  OP      OP_SWAP
    OP      OP_POP
8:  NOLV
    ldr     x30, [sp], #16
    ret
c_w_constructor: .ascii "constructor"
c_w_prototype:   .ascii "prototype"
c_w_proto_end:
    .balign 4
// c_find_ctor: the current word is the { of a class's body: is there a constructor in it -> flags: eq if so, the reader
// left at the ( after its name (the caller keeps and puts back the reader's place)
c_find_ctor:
    stp     x30, xzr, [sp, #-16]!
1:  cbz     w23, 7f
    cmp     w23, #K_PUNCT
    b.ne    3f
    sub     w9, w24, #33
    cmp     w9, #5
    b.hi    6f
    ldr     w10, [sp, #8]
    tbz     w24, #0, 2f
    add     w10, w10, #1
    str     w10, [sp, #8]
    b       6f
2:  sub     w10, w10, #1
    str     w10, [sp, #8]
    cbz     w10, 7f
    b       6f
3:  cmp     w23, #K_NAME
    b.ne    6f
    ldr     w10, [sp, #8]
    cmp     w10, #1
    b.ne    6f
    adr     x0, c_w_constructor
    mov     x1, #(c_w_prototype - c_w_constructor)
    bl      c_is
    b.ne    6f
    bl      next_word
    ISP     35, 1b
    mov     w0, #1
    b       8f
6:  bl      next_word
    b       1b
7:  mov     w0, #0
8:  ldr     x30, [sp], #16
    cmp     w0, #1
    ret
// c_class: a class, from the word `class` to past its closing }: the class (a function) is left on the stack, and with w0 1
// also stored in the variable of its name. The constructor is found first, wherever it is written (without one: a plan with
// flag 16, which the machine passes on to the parent); then each method is put on the prototype, or on the class if static.
// Kept: 8 a declaration?, 16 the variable, 20 static?, 24 getter or setter (0, 1; -1 neither), 28 extends?
// (Not made: fields, private names, static blocks; a class called without new is not refused.)
c_class:
    stp     x30, x0, [sp, #-48]!
    DEEPER
    bl      next_word
    mov     w9, #-1
    str     w9, [sp, #16]
    str     wzr, [sp, #28]
    cmp     w23, #K_NAME
    b.ne    1f
    ldr     w9, [sp, #8]
    cbz     w9, 0f
    bl      c_declref
    str     w0, [sp, #16]
0:  bl      next_word
1:  ISK     12, 2f
    bl      next_word
    bl      c_postfix
    mov     w9, #1
    str     w9, [sp, #28]
2:  ISP     33, c_unexpected
    LEXSAVE
    bl      c_find_ctor
    b.ne    3f
    mov     w0, #4
    bl      c_function
    LEXBACK
    b       4f
3:  LEXBACK
    mov     x0, #40
    bl      w_alloc
    cbz     x0, c_full
    add     x9, x19, x0
    mov     x10, #2
    str     x10, [x9]
    stp     xzr, xzr, [x9, #8]
    mov     x10, #16
    str     x10, [x9, #24]
    VAL     x10, T_UNDEF
    str     x10, [x9, #32]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    bl      c_addconst
    mov     w1, w0
    mov     w0, #OP_CLOSURE
    bl      c_op16
4:  ldr     w9, [sp, #28]
    cbz     w9, 5f
    OP      OP_EXTENDS
5:  OP      OP_DUP
    adr     x0, c_w_prototype
    mov     x1, #(c_w_proto_end - c_w_prototype)
    bl      w_string
    cbz     x0, c_full
    bl      c_keyconst
    mov     w1, w0
    mov     w0, #OP_GETP
    bl      c_op16
    bl      next_word
6:  cmp     w23, #K_PUNCT
    b.ne    61f
    cmp     w24, #34
    b.eq    9f
    cmp     w24, #39
    b.ne    61f
    bl      next_word
    b       6b
61: cbz     w23, c_unexpected
    mov     w9, #-1
    stp     wzr, w9, [sp, #20]
    ISK     34, 62f
    bl      c_peek_acc
    b.ne    62f
    mov     w9, #1
    str     w9, [sp, #20]
    bl      next_word
62: cmp     w23, #K_KEYWORD
    b.ne    63f
    sub     w9, w24, #38
    cmp     w9, #1
    b.hi    63f
    str     w9, [sp, #32]
    bl      c_peek_acc
    b.ne    63f
    ldr     w9, [sp, #32]
    str     w9, [sp, #24]
    bl      next_word
63: ldr     w9, [sp, #20]
    cbnz    w9, 64f
    ldr     w9, [sp, #24]
    cmn     w9, #1
    b.ne    65f
    cmp     w23, #K_NAME
    b.ne    65f
    adr     x0, c_w_constructor
    mov     x1, #(c_w_prototype - c_w_constructor)
    bl      c_is
    b.ne    65f
    bl      next_word                   // the constructor: translated already
    bl      c_skip_pattern
    bl      c_skip_pattern
    b       6b
64: OP      OP_SWAP
65: bl      c_propkey
    ISP     35, c_notyet
    mov     w0, #4
    bl      c_function
    OP      OP_HOME
    ldr     w9, [sp, #24]
    cmn     w9, #1
    b.ne    66f
    OP      OP_INITE
    b       67f
66: OP      OP_DEFACC
    ldr     w0, [sp, #24]
    bl      c_byte
67: ldr     w9, [sp, #20]
    cbz     w9, 6b
    OP      OP_SWAP
    b       6b
9:  OP      OP_POP
    ldr     w0, [sp, #16]
    cmn     w0, #1
    b.eq    91f
    bl      c_store
91: bl      next_word
    NOLV
    SHALLOWER
    ldr     x30, [sp], #48
    ret
// c_primary: a number, a string, a name, a word that is a value, or an expression in brackets
c_primary:
    stp     x30, xzr, [sp, #-16]!
    NOLV
    cmp     w23, #K_NUMBER
    b.ne    1f
    fmov    x0, d8
    bl      c_const
    b       8f
1:  cmp     w23, #K_STRING
    b.ne    2f
    bl      c_string
    bl      c_strconst
    b       8f
2:  cmp     w23, #K_KEYWORD
    b.ne    3f
    mov     w0, #OP_NULL
    cmp     w24, #40
    b.eq    20f
    mov     w0, #OP_TRUE
    cmp     w24, #41
    b.eq    20f
    mov     w0, #OP_FALSE
    cmp     w24, #42
    b.eq    20f
    mov     w0, #OP_THIS
    cmp     w24, #24
    b.eq    20f
    cmp     w24, #3
    b.ne    21f
    mov     w0, #0
    bl      c_class
    b       9f
21: cmp     w24, #22
    b.eq    c_super
    sub     w9, w24, #33                // let, static, async, await, of, get, set may be plain names
    cmp     w9, #6
    b.ls    40f
    cmp     w24, #15
    b.ne    c_notyet
    bl      next_word
    mov     w0, #0
    bl      c_function
    b       9f
20: bl      c_byte
    b       8f
3:  cmp     w23, #K_PUNCT
    b.ne    4f
    cmp     w24, #35
    b.eq    30f
    cmp     w24, #33
    b.ne    32f
    bl      c_object
    b       8f
32: cmp     w24, #37
    b.ne    c_unexpected
    bl      c_array
    b       8f
30: bl      c_peek_paren                // (a, b) => ...
    b.ne    31f
    mov     w0, #3
    bl      c_function
    b       9f
31: bl      next_word
    bl      c_expr
    EXPECT  36
    b       9f
4:  cmp     w23, #K_NAME
    b.eq    40f
    cmp     w23, #K_TEMPLATE
    b.ne    46f
    bl      c_template
    b       8f
46:
    cmp     w23, #K_PATTERN
    b.eq    c_notyet
    cmp     w23, #K_BIGINT
    b.eq    c_notyet
    b       c_unexpected
40: bl      c_peek_name                 // x => ...
    b.ne    44f
    mov     w0, #2
    bl      c_function
    b       9f
44: adr     x0, c_w_undefined
    mov     x1, #(c_w_nan - c_w_undefined)
    bl      c_is
    b.ne    41f
    OP      OP_UNDEF
    b       8f
41: adr     x0, c_w_nan
    mov     x1, #(c_w_infinity - c_w_nan)
    bl      c_is
    b.ne    42f
    ldr     x0, =0x7ff8000000000000
    bl      c_const
    b       8f
42: adr     x0, c_w_infinity
    mov     x1, #(c_w_console - c_w_infinity)
    bl      c_is
    b.ne    43f
    ldr     x0, =0x7ff0000000000000
    bl      c_const
    b       8f
43: adr     x0, c_w_console
    mov     x1, #(c_w_log - c_w_console)
    bl      c_is
    b.eq    50f
    ldr     x9, [x29, #F_FUNC]          // `arguments` inside a function: a variable of it, filled when it is called
    cbz     x9, 45f
    adr     x0, c_w_arguments
    mov     x1, #(c_w_arguments_end - c_w_arguments)
    bl      c_is
    b.ne    45f
    bl      c_declare
    ldr     x9, [x29, #F_FUNC]
    ldr     x10, [x9, #R_FLAGS]
    tbnz    x10, #3, 45f
    orr     x10, x10, #8
    orr     x10, x10, x0, lsl #16
    str     x10, [x9, #R_FLAGS]
45: bl      c_ref
    ldr     x9, [x29, #F_LEN]
    str     x9, [x29, #F_LV]
    bl      c_raw
8:  bl      next_word
9:  ldr     x30, [sp], #16
    ret
50: bl      next_word                   // console.log(a, b, ...): a line of output
    EXPECT  56
    adr     x0, c_w_log
    mov     x1, #(c_w_end - c_w_log)
    bl      c_is
    b.ne    c_notyet
    bl      next_word
    EXPECT  35
    bl      c_args
    tbnz    w0, #31, 51f
    str     x0, [sp, #8]
    OP      OP_PRINT
    ldr     w0, [sp, #8]
    bl      c_byte
    b       52f
51: OP      OP_APPLY
    mov     w0, #3
    bl      c_byte
52: NOLV
    b       9b
    .ltorg

// Statements. Each leaves the machine's stack as it found it.
// c_var: var, let or const (the current word) and what it declares, up to but not past the end of the statement
c_var:
    stp     x30, xzr, [sp, #-32]!
    str     w24, [sp, #8]
1:  bl      next_word
    cmp     w23, #K_PUNCT
    b.ne    11f
    cmp     w24, #33
    b.eq    12f
    cmp     w24, #37
    b.ne    c_unexpected
12: mov     w0, #1
    bl      c_destructure
    OP      OP_POP
    b       5f
11: cmp     w23, #K_NAME
    b.eq    2f
    cmp     w23, #K_KEYWORD
    b.ne    c_unexpected
    sub     w9, w24, #33
    cmp     w9, #6
    b.hi    c_unexpected
2:  bl      c_declref
    str     w0, [sp, #12]
    bl      next_word
    ISP     55, 3f
    bl      next_word
    bl      c_assign
    b       4f
3:  ldr     w9, [sp, #8]
    cmp     w9, #28                     // var x; leaves what x holds alone
    b.eq    5f
    OP      OP_UNDEF
4:  ldr     w0, [sp, #12]
    bl      c_store
    OP      OP_POP
5:  cmp     w23, #K_PUNCT
    mov     w9, #40
    ccmp    w24, w9, #0, eq
    b.eq    1b
    ldr     x30, [sp], #32
    ret
// c_semi: the end of a statement: a ; or, where the language lets it be left out, a line end, a } or the end of the text
c_semi:
    cmp     w23, #K_PUNCT
    b.ne    1f
    cmp     w24, #39
    b.eq    next_word
    cmp     w24, #34
    b.eq    2f
1:  cbz     w23, 2f
    cbnz    w27, 2f
    b       c_unexpected
2:  ret
    .macro  LOOP_IN
    ldr     x9, [x29, #F_LOOP]
    stp     x9, xzr, [sp, #32]
    str     xzr, [sp, #48]
    add     x9, sp, #32
    str     x9, [x29, #F_LOOP]
    .endm
    .macro  LOOP_OUT
    ldr     x9, [sp, #32]
    str     x9, [x29, #F_LOOP]
    .endm
// c_stmt: one statement. Its frame: 8, 16, 24, 56 for places in the instructions; 32-55 a loop's record.
c_stmt:
    stp     x30, xzr, [sp, #-64]!
    DEEPER
    cmp     w23, #K_PUNCT
    b.ne    s_word
    cmp     w24, #39
    b.ne    1f
    bl      next_word
    b       s_done
1:  cmp     w24, #33
    b.ne    s_expr
    bl      next_word
2:  cmp     w23, #K_PUNCT
    mov     w9, #34
    ccmp    w24, w9, #0, eq
    b.eq    3f
    cbz     w23, c_unexpected
    bl      c_stmt
    b       2b
3:  bl      next_word
    b       s_done
s_word:
    cmp     w23, #K_KEYWORD
    b.ne    s_expr
    cmp     w24, #28
    b.eq    s_var
    cmp     w24, #33
    b.eq    s_var
    cmp     w24, #4
    b.eq    s_var
    cmp     w24, #16
    b.eq    s_if
    cmp     w24, #30
    b.eq    s_while
    cmp     w24, #9
    b.eq    s_do
    cmp     w24, #14
    b.eq    s_for
    cmp     w24, #0
    b.eq    s_break
    cmp     w24, #5
    b.eq    s_continue
    cmp     w24, #21
    b.eq    s_return
    cmp     w24, #26
    b.eq    s_try
    cmp     w24, #25
    b.eq    s_throw
    cmp     w24, #3
    b.ne    1f
    mov     w0, #1
    bl      c_class
    OP      OP_POP
    b       s_done
1:  cmp     w24, #15
    b.ne    s_expr
    bl      next_word
    mov     w0, #1
    bl      c_function
    b       s_done
s_expr:
    bl      c_expr
    OP      OP_POP
    bl      c_semi
    b       s_done
s_var:
    bl      c_var
    bl      c_semi
    b       s_done
s_if:
    bl      next_word
    EXPECT  35
    bl      c_expr
    EXPECT  36
    mov     w0, #OP_JF
    bl      c_jump
    str     x0, [sp, #8]
    bl      c_stmt
    ISK     10, 1f
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #16]
    ldr     x0, [sp, #8]
    bl      c_patch
    bl      next_word
    bl      c_stmt
    ldr     x0, [sp, #16]
    bl      c_patch
    b       s_done
1:  ldr     x0, [sp, #8]
    bl      c_patch
    b       s_done
s_while:
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #8]                // the top, where it goes round to
    bl      next_word
    EXPECT  35
    bl      c_expr
    EXPECT  36
    mov     w0, #OP_JF
    bl      c_jump
    str     x0, [sp, #16]
    LOOP_IN
    bl      c_stmt
    LOOP_OUT
    mov     w0, #OP_JMP
    ldr     x1, [sp, #8]
    bl      c_jump_to
    ldr     x0, [sp, #16]
    bl      c_patch
    ldr     x0, [sp, #48]
    ldr     x1, [sp, #8]
    bl      c_resolve
    ldr     x0, [sp, #40]
    ldr     x1, [x29, #F_LEN]
    bl      c_resolve
    b       s_done
s_do:
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #8]
    bl      next_word
    LOOP_IN
    bl      c_stmt
    LOOP_OUT
    ISK     30, c_unexpected
    ldr     x0, [sp, #48]               // continue goes to the test
    ldr     x1, [x29, #F_LEN]
    bl      c_resolve
    bl      next_word
    EXPECT  35
    bl      c_expr
    ISP     36, c_unexpected
    mov     w0, #OP_JT
    ldr     x1, [sp, #8]
    bl      c_jump_to
    ldr     x0, [sp, #40]
    ldr     x1, [x29, #F_LEN]
    bl      c_resolve
    bl      next_word
    ISP     39, s_done                  // the ; after it may always be left out
    bl      next_word
    b       s_done
s_for:
    bl      next_word
    EXPECT  35
    bl      c_peek_each
    cbnz    w0, s_each
    mov     w9, #39
    cmp     w23, #K_PUNCT
    ccmp    w24, w9, #0, eq
    b.eq    3f
    cmp     w23, #K_KEYWORD
    b.ne    2f
    cmp     w24, #28
    b.eq    1f
    cmp     w24, #33
    b.eq    1f
    cmp     w24, #4
    b.ne    2f
1:  bl      c_var
    b       3f
2:  bl      c_expr
    OP      OP_POP
3:  EXPECT  39
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #8]                // the top: the test
    str     xzr, [sp, #16]              // the test's way out, if there is a test
    mov     w9, #39
    cmp     w23, #K_PUNCT
    ccmp    w24, w9, #0, eq
    b.eq    4f
    bl      c_expr
    mov     w0, #OP_JF
    bl      c_jump
    str     x0, [sp, #16]
4:  EXPECT  39
    ldr     x9, [sp, #8]
    str     x9, [sp, #24]               // where continue goes: the step if there is one, else the top
    mov     w9, #36
    cmp     w23, #K_PUNCT
    ccmp    w24, w9, #0, eq
    b.eq    5f
    mov     w0, #OP_JMP                 // the step is written before the body but runs after it
    bl      c_jump
    str     x0, [sp, #56]
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #24]
    bl      c_expr
    OP      OP_POP
    mov     w0, #OP_JMP
    ldr     x1, [sp, #8]
    bl      c_jump_to
    ldr     x0, [sp, #56]
    bl      c_patch
5:  EXPECT  36
    LOOP_IN
    bl      c_stmt
    LOOP_OUT
    mov     w0, #OP_JMP
    ldr     x1, [sp, #24]
    bl      c_jump_to
    ldr     x0, [sp, #16]
    cbz     x0, 6f
    bl      c_patch
6:  ldr     x0, [sp, #48]
    ldr     x1, [sp, #24]
    bl      c_resolve
    ldr     x0, [sp, #40]
    ldr     x1, [x29, #F_LEN]
    bl      c_resolve
    b       s_done
s_each:                                 // for (name in value), for (name of value): 24 the variable, 56 which (1 in, 2 of)
    str     w0, [sp, #56]
    tbz     w0, #2, 0f
    and     w9, w0, #3                  // a pattern: its instructions are written here and jumped over; each item comes
    str     w9, [sp, #56]               // back to them (28 where they start, 60 the jump out of them)
    mov     w9, #0
    cmp     w23, #K_KEYWORD
    b.ne    77f
    bl      next_word
    mov     w9, #1
77: str     w9, [sp, #28]
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #8]
    ldr     x9, [x29, #F_LEN]
    ldr     w0, [sp, #28]
    str     w9, [sp, #28]
    bl      c_pattern
    OP      OP_POP
    mov     w0, #OP_JMP
    bl      c_jump
    str     w0, [sp, #60]
    ldr     x0, [sp, #8]
    bl      c_patch
    mov     w9, #-1
    str     w9, [sp, #24]
    b       3f
0:  cmp     w23, #K_KEYWORD
    b.ne    1f
    bl      next_word
    bl      c_declref
    b       2f
1:  bl      c_ref
2:  str     w0, [sp, #24]
    bl      next_word
3:  bl      next_word
    bl      c_expr
    EXPECT  36
    ldr     w9, [sp, #56]
    mov     w0, #OP_KEYS
    mov     w10, #OP_ITER
    cmp     w9, #1
    csel    w0, w0, w10, eq
    bl      c_byte
    mov     x0, #0
    bl      c_const
    ldr     x9, [x29, #F_LEN]
    str     x9, [sp, #8]
    mov     w0, #OP_FORNEXT
    bl      c_jump
    str     x0, [sp, #16]
    ldr     w0, [sp, #24]
    cmn     w0, #1
    b.eq    4f
    bl      c_store
    OP      OP_POP
    b       5f
4:  mov     w0, #OP_JMP
    ldr     w1, [sp, #28]
    bl      c_jump_to
    ldr     w0, [sp, #60]
    bl      c_patch
5:
    LOOP_IN
    bl      c_stmt
    LOOP_OUT
    mov     w0, #OP_JMP
    ldr     x1, [sp, #8]
    bl      c_jump_to
    ldr     x0, [sp, #16]
    bl      c_patch
    ldr     x0, [sp, #48]
    ldr     x1, [sp, #8]
    bl      c_resolve
    ldr     x0, [sp, #40]
    ldr     x1, [x29, #F_LEN]
    bl      c_resolve
    OP      OP_POP
    OP      OP_POP
    b       s_done
s_return:
    ldr     x9, [x29, #F_FUNC]
    cbz     x9, c_unexpected
    bl      next_word
    cbz     w23, 1f
    cbnz    w27, 1f
    cmp     w23, #K_PUNCT
    b.ne    2f
    cmp     w24, #39
    b.eq    1f
    cmp     w24, #34
    b.ne    2f
1:  OP      OP_UNDEF
    b       3f
2:  bl      c_expr
3:  mov     w0, #1
    bl      c_try_exits
    OP      OP_RET
    bl      c_semi
    b       s_done
s_break:
    mov     x10, #8
    b       1f
s_continue:
    mov     x10, #16
1:  ldr     x1, [x29, #F_LOOP]
    cbz     x1, c_noloop
    str     x10, [sp, #8]
    mov     w0, #0
    bl      c_try_exits
    ldr     x10, [sp, #8]
    ldr     x1, [x29, #F_LOOP]
    add     x1, x1, x10
    mov     w0, #OP_JMP
    bl      c_chain
    bl      next_word
    cmp     w23, #K_NAME                // a named loop: not made yet
    b.ne    2f
    cbz     w27, c_notyet
2:  bl      c_semi
s_done:
    SHALLOWER
    ldr     x30, [sp], #64
    ret
s_throw:
    bl      next_word
    bl      c_expr
    OP      OP_THROW
    bl      c_semi
    b       s_done
// try { A } catch (e) { B } finally { C } is laid out as: TRY c; A; ENDTRY; JMP n; c: store e; TRY a; B; ENDTRY; JMP n;
// a: GOSUB f; THROW; n: UNDEF; GOSUB f; POP; JMP end; f: C; RETSUB; end. So C is written once and is reached with two places
// on the stack (something pending, where to go back to). Without a catch, c is a. The record (48 bytes under this frame):
// 0 the try around, 8 state, 16 the jumps to f, 24 the loop and 32 the function it is in, 40 whether a catch was seen.
s_try:
    bl      next_word
    ISP     33, c_unexpected
    sub     sp, sp, #48
    ldr     x9, [x29, #F_TRY]
    mov     x10, #1
    stp     x9, x10, [sp]
    ldr     x9, [x29, #F_LOOP]
    stp     xzr, x9, [sp, #16]
    ldr     x9, [x29, #F_FUNC]
    stp     x9, xzr, [sp, #32]
    mov     x9, sp
    str     x9, [x29, #F_TRY]
    str     xzr, [sp, #48 + 24]
    mov     w0, #OP_TRY
    bl      c_jump
    str     x0, [sp, #48 + 8]
    bl      c_stmt
    OP      OP_ENDTRY
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #48 + 16]
    ldr     x0, [sp, #48 + 8]
    bl      c_patch
    ISK     2, 4f
    mov     x9, #1
    str     x9, [sp, #40]
    bl      next_word
    ISP     35, 2f
    bl      next_word
    cmp     w23, #K_NAME
    b.eq    1f
    cmp     w23, #K_PUNCT               // catch ({a, b}) or catch ([a, b]): the pattern takes the thrown value apart
    b.ne    c_unexpected
    cmp     w24, #33
    mov     w9, #37
    ccmp    w24, w9, #4, ne
    b.ne    c_unexpected
    mov     w0, #1
    bl      c_pattern
    EXPECT  36
    b       2f
1:  bl      c_declref
    str     w0, [sp, #48 + 56]
    bl      next_word
    EXPECT  36
    ldr     w0, [sp, #48 + 56]
    bl      c_store
2:  OP      OP_POP
    ISP     33, c_unexpected
    mov     w0, #OP_TRY
    bl      c_jump
    str     x0, [sp, #48 + 8]
    bl      c_stmt
    OP      OP_ENDTRY
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #48 + 24]
    ldr     x0, [sp, #48 + 8]
    bl      c_patch
4:  mov     w0, #OP_GOSUB
    add     x1, sp, #16
    bl      c_chain
    OP      OP_THROW
    ldr     x0, [sp, #48 + 16]
    bl      c_patch
    ldr     x0, [sp, #48 + 24]
    cbz     x0, 5f
    bl      c_patch
5:  OP      OP_UNDEF
    mov     w0, #OP_GOSUB
    add     x1, sp, #16
    bl      c_chain
    OP      OP_POP
    mov     w0, #OP_JMP
    bl      c_jump
    str     x0, [sp, #48 + 8]
    ldr     x0, [sp, #16]
    ldr     x1, [x29, #F_LEN]
    bl      c_resolve
    str     xzr, [sp, #8]
    ISK     13, 6f
    bl      next_word
    ISP     33, c_unexpected
    bl      c_stmt
    b       7f
6:  ldr     x9, [sp, #40]
    cbz     x9, c_unexpected
7:  OP      OP_RETSUB
    ldr     x0, [sp, #48 + 8]
    bl      c_patch
    ldr     x9, [sp]
    str     x9, [x29, #F_TRY]
    add     sp, sp, #48
    b       s_done
// c_try_exits: a return (w0 1, its value on the stack) or a break or continue (w0 0) is about to leave: each try of this
// function it leaves (for a break: those begun inside the loop) is ended and its finally run; inside a finally, the two
// places it was reached with are dropped instead.
c_try_exits:
    stp     x30, x0, [sp, #-32]!
    ldr     x9, [x29, #F_TRY]
1:  str     x9, [sp, #16]
    cbz     x9, 9f
    ldr     x10, [x9, #32]
    ldr     x11, [x29, #F_FUNC]
    cmp     x10, x11
    b.ne    9f
    ldr     x12, [sp, #8]
    cbnz    x12, 2f
    ldr     x10, [x9, #24]
    ldr     x11, [x29, #F_LOOP]
    cmp     x10, x11
    b.ne    9f
2:  ldr     x10, [x9, #8]
    cbz     x10, 5f
    cbnz    x12, 3f
    OP      OP_ENDTRY
    OP      OP_UNDEF
    mov     w0, #OP_GOSUB
    ldr     x1, [sp, #16]
    add     x1, x1, #16
    bl      c_chain
    OP      OP_POP
    b       8f
3:  OP      OP_ENDTRYK
    mov     w0, #OP_GOSUB
    ldr     x1, [sp, #16]
    add     x1, x1, #16
    bl      c_chain
    b       8f
5:  cbnz    x12, 8f
    OP      OP_POP
    OP      OP_POP
8:  ldr     x9, [sp, #16]
    ldr     x9, [x9]
    b       1b
9:  ldr     x30, [sp], #32
    ret
    .ltorg
