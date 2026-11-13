// The world: everything a running program has, in one block the host owns (kind 6). Nothing in it is an address: every
// reference is a distance from the block's start, so a world can be moved, saved, or handed to a new build of this piece.
// x19 is the world's start wherever this file's routines are used.
    // the head (512 bytes). Places and counts are 64-bit.
    .equ W_MAGIC, 64                    // "TRJS" and the layout's version
    .equ W_CODE, 72                     // the instructions: where, how many bytes are written, room
    .equ W_CODE_LEN, 80
    .equ W_CODE_CAP, 88
    .equ W_CONST, 96                    // constants, 8 bytes each: where, how many, room
    .equ W_CONST_N, 104
    .equ W_CONST_CAP, 112
    .equ W_GLOB, 120                    // global variables, 16 bytes each (name, value): where, how many, room
    .equ W_GLOB_N, 128
    .equ W_GLOB_CAP, 136
    .equ W_OUT, 144                     // what the program has printed: where, how much, room
    .equ W_OUT_LEN, 152
    .equ W_OUT_CAP, 160
    .equ W_STACK, 168                   // the machine's stack of values: where it starts, where it ends
    .equ W_STACK_END, 176
    .equ W_SP, 184                      // the machine as it stands: stack top, next instruction, state
    .equ W_PC, 192
    .equ W_STATE, 200                   // 0 fresh, 1 loaded, 2 finished, 3 stopped on an error
    .equ W_HEAP, 208                    // strings and objects: the next free place, and the end
    .equ W_HEAP_END, 216
    .equ W_ERR, 224                     // the last error: its text (a string value), line, column
    .equ W_ERR_LINE, 232
    .equ W_ERR_COL, 236
    .equ W_SRC, 240                     // the program's text, kept in the world: where, how long
    .equ W_SRC_LEN, 248
    .equ W_FP, 256                      // the machine inside a call: the call's record on the stack (0: not in one),
    .equ W_LOCALS, 264                  // where the running function's variables are,
    .equ W_ENV, 272                     // and the scope its inner functions will remember
    .equ W_K_LENGTH, 280                // names the machine itself knows, as string values (made when first run)
    .equ W_K_PROTOTYPE, 288
    .equ W_K_CONSTRUCTOR, 296
    .equ W_NGLOB, 312                   // the library's way in (see lib.S): which global holds the maker of built-in functions, plus one;
    .equ W_NNAME, 320                   // its name while the opening lines are translated; the empty name it has afterwards
    .equ W_NEMPTY, 328
    .equ W_PROTOS, 336                  // six object values (0: not yet): what plain objects, arrays, functions, strings, numbers and booleans inherit from
    .equ W_NSP, 384                     // while a built-in routine runs: the processor's stack as the machine left it
    .equ W_OWNONLY, 392                 // not 0: m_keylist gives the value's own names only
    .equ W_RNG, 400                     // Math.random's state
    .equ W_K_TOSTRING, 408
    .equ W_JWIDE, 416                   // JSON.parse: 1 if the text it is reading has two bytes a unit
    .equ W_ITERFN, 424                  // the prelude's function that turns anything loopable into an array (0: not yet)
    .equ W_FALLBACK, 432                // three functions of the prelude: join, indexOf, slice in the language, for what built-ins 49-51 do not take
    .equ W_K_TOPRIM, 504                // the text "@@toPrimitive"
    .equ W_K_VALUEOF, 496               // the text "valueOf"
    .equ W_K_FULL, 456                  // the text of the error for a full world, made at the start while there is room
    .equ W_GENFN, 528                   // two functions of the prelude: what makes a generator of a holder, what drives an async function
    .equ W_WANT, 544                    // not 0: the program asks its host for something: one more than where the request begins in what it has printed
    .equ W_GOBJ, 560                    // the global object, whose properties are the global variables themselves (0: not made yet)
    .equ W_ANSWER, 552                  // the host's answer, a string value (0: none)
    .equ W_HANDLER, 304                 // the newest try still open: where its record on the stack ends (0: none)
    // values: a number is itself; anything else has these top 16 bits and a payload below
    .equ T_UNDEF, 0xfff9
    .equ T_NULL, 0xfffa
    .equ T_BOOL, 0xfffb
    .equ T_STRING, 0xfffc
    .equ T_OBJECT, 0xfffd
    .equ T_HOLE, 0xffff                 // only ever a global's value: nothing has declared it or stored to it yet
    .equ T_ACC, 0xfffe                  // only ever a property's value: where its getter and setter are (two values)
// VAL: a tagged value with no payload -> \reg
    .macro  VAL reg, tag
    mov     \reg, #(\tag << 48)
    .endm
// w_begin: makes the block at x19 a fresh world -> x0 1, or -1 if it is not a world block or is under a megabyte.
// The room is shared out by size: an eighth for instructions, a thirty-second each for constants and globals, a sixteenth
// each for printed text and the stack, the rest for strings and objects.
w_begin:
    ldr     w9, [x19]
    cmp     w9, #6
    b.ne    9f
    ldr     x9, [x19, #16]
    mov     x10, #0x100000
    cmp     x9, x10
    b.lo    9f
    add     x11, x19, #64
    mov     x12, #64
1:  str     xzr, [x11], #8
    subs    x12, x12, #1
    b.ne    1b
    ldr     w11, =0x534a5254
    str     w11, [x19, #W_MAGIC]
    mov     w11, #1
    str     w11, [x19, #(W_MAGIC + 4)]
    mov     x11, #576
    lsr     x12, x9, #3
    and     x12, x12, #-16
    stp     x11, xzr, [x19, #W_CODE]
    str     x12, [x19, #W_CODE_CAP]
    add     x11, x11, x12
    lsr     x12, x9, #5
    and     x12, x12, #-16
    lsr     x13, x12, #3
    stp     x11, xzr, [x19, #W_CONST]
    str     x13, [x19, #W_CONST_CAP]
    add     x11, x11, x12
    lsr     x13, x12, #4
    stp     x11, xzr, [x19, #W_GLOB]
    str     x13, [x19, #W_GLOB_CAP]
    add     x11, x11, x12
    lsr     x12, x9, #4
    and     x12, x12, #-16
    stp     x11, xzr, [x19, #W_OUT]
    str     x12, [x19, #W_OUT_CAP]
    add     x11, x11, x12
    str     x11, [x19, #W_STACK]
    str     x11, [x19, #W_SP]
    add     x11, x11, x12
    str     x11, [x19, #W_STACK_END]
    stp     x11, x9, [x19, #W_HEAP]
    mov     x0, #1
    ret
9:  mov     x0, #-1
    ret
// w_alloc: x0 bytes of the heap (rounded up to 8) -> x0 where (a distance from the world's start), or 0 if the world is full.
// Uses x9, x10.
w_alloc:
    add     x0, x0, #7
    and     x0, x0, #-8
    ldp     x9, x10, [x19, #W_HEAP]
    add     x0, x9, x0
    cmp     x0, x10
    b.hi    1f
    str     x0, [x19, #W_HEAP]
    mov     x0, x9
    ret
1:  mov     x0, #0
    ret
// w_string: a string value holding the x1 bytes at x0 -> x0 the value, or 0 if the world is full. A string in the heap is its
// length (8 bytes), then its bytes. Uses x9-x13.
w_string:
    mov     x13, x30
    mov     x11, x0
    mov     x12, x1
    add     x0, x1, #8
    bl      w_alloc
    cbz     x0, 2f
    add     x9, x19, x0
    str     x12, [x9], #8
    mov     x10, #0
    cbz     x12, 3f
1:  ldrb    w1, [x11, x10]
    strb    w1, [x9, x10]
    add     x10, x10, #1
    cmp     x10, x12
    b.lo    1b
3:  orr     x0, x0, #(T_STRING << 48)
2:  ret     x13
// w_out: the x1 bytes at x0 join what the program has printed (what does not fit is dropped). Uses x9-x12.
w_out:
    ldp     x9, x10, [x19, #W_OUT]
    ldr     x11, [x19, #W_OUT_CAP]
    add     x9, x19, x9
1:  cbz     x1, 2f
    cmp     x10, x11
    b.hs    2f
    ldrb    w12, [x0], #1
    strb    w12, [x9, x10]
    add     x10, x10, #1
    sub     x1, x1, #1
    b       1b
2:  str     x10, [x19, #W_OUT_LEN]
    ret
