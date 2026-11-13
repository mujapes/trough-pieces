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
    .equ W_POS, 568                     // line and column (32 bits each) of the statement last begun (OP_LINE)
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
    .equ W_K_TOPRIM, 504                // the key Symbol.toPrimitive ("\001Symbol.toPrimitive")
    .equ W_K_VALUEOF, 496               // the text "valueOf"
    .equ W_K_FULL, 456                  // the text of the error for a full world, made at the start while there is room
    .equ W_PKEY, 656                    // the name a proxy's trap was reached for (read by the prelude's trap through __n(68))
    .equ W_LAST, 584                    // where the newest block made at the top starts (0: the newest came from the free list)
    .equ W_GENFN3, 576                  // the prelude's driver of an async generator (OP_GENSNAP 2)
    .equ W_GENFN, 528                   // two functions of the prelude: what makes a generator of a holder, what drives an async function
    .equ W_WANT, 544                    // not 0: the program asks its host for something: one more than where the request begins in what it has printed
    .equ W_TRAILN, 664                  // the call trail of the last error made: how many places (machine.S m_trail)
    .equ W_TRAIL, 672                   // and the places, 16 at most, each line * 2^32 + column; the first where it was made
    .equ W_TEXTNO, 800
    .equ W_STRESS, 808                  // [by Opus] collection stress (set by a host for finding faults): collect every this many bytes
    .equ W_STRESS_END, 816              //   and the heap's real end (W_HEAP_END is kept just above the top meanwhile)
                                        // W_TEXTNO: how many texts have been translated (c_compile, c_fragment): a place's line
                                        // carries the number of its text (8 bits) above its 24 bits (c_pos)
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
    mov     x12, #96                    // [by Opus] (to 832)
1:  str     xzr, [x11], #8
    subs    x12, x12, #1
    b.ne    1b
    ldr     w11, =0x534a5254
    str     w11, [x19, #W_MAGIC]
    mov     w11, #1
    str     w11, [x19, #(W_MAGIC + 4)]
    mov     x11, #832                   // [by Opus] 824 W_BADCALL, 808 W_STRESS, 816 W_STRESS_END. The header: 808 bytes (800 W_TEXTNO, 576: W_GENFN3, 584 W_LAST, 592-655 the collector's, gc.S, 656 W_PKEY, 664 W_TRAILN, 672-799 W_TRAIL)
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
    str     x11, [x19, #W_HEAP0]        // the collector's room at the heap's end: start bits, marks, the mark stack, a 64th each
    sub     x10, x9, x11
    lsr     x10, x10, #6
    add     x10, x10, #16
    and     x10, x10, #-8
    sub     x9, x9, x10
    str     x9, [x19, #W_MSTK]
    lsr     x12, x10, #3
    str     x12, [x19, #W_MSCAP]
    sub     x9, x9, x10
    str     x9, [x19, #W_MARKS]
    sub     x9, x9, x10
    str     x9, [x19, #W_BITS]
    add     x12, x19, x9
    lsl     x13, x10, #1
2:  str     xzr, [x12], #8
    subs    x13, x13, #8
    b.hi    2b
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
    b.hi    w_slow
    str     x0, [x19, #W_HEAP]
    str     x9, [x19, #W_LAST]
    stp     x11, x12, [sp, #-16]!       // its start bit
    ldr     x10, [x19, #W_HEAP0]
    sub     x10, x9, x10
    lsr     x10, x10, #3
    ldr     x11, [x19, #W_BITS]
    add     x11, x19, x11
    lsr     x0, x10, #6
    ldr     x12, [x11, x0, lsl #3]
    mov     x0, #1
    lsl     x0, x0, x10
    orr     x12, x12, x0
    lsr     x10, x10, #6
    str     x12, [x11, x10, lsl #3]
    ldp     x11, x12, [sp], #16
    mov     x0, x9
    ret
// w_slow: no room at the top: a free block that fits; else a collection, then the top again, then a free block again.
// Every register is kept on the processor's stack, where the collector sees them as roots.
w_slow:
    sub     x0, x0, x9
    cmp     x0, #8
    mov     x9, #8
    csel    x0, x0, x9, hs
    sub     sp, sp, #256
    stp     x0, x1, [sp]
    stp     x2, x3, [sp, #16]
    stp     x4, x5, [sp, #32]
    stp     x6, x7, [sp, #48]
    stp     x8, x11, [sp, #64]
    stp     x12, x13, [sp, #80]
    stp     x14, x15, [sp, #96]
    stp     x16, x17, [sp, #112]
    stp     x18, x20, [sp, #128]
    stp     x21, x22, [sp, #144]
    stp     x23, x24, [sp, #160]
    stp     x25, x26, [sp, #176]
    stp     x27, x28, [sp, #192]
    stp     x29, x30, [sp, #208]
    ldr     x9, [x19, #W_STRESS]
    cbnz    x9, 6f
    bl      g_fit
    str     xzr, [x19, #W_LAST]
    cbnz    x0, 8f
6:  bl      gc_collect
    ldr     x9, [x19, #W_STRESS]        // stress: the end again just above the top (never past the real one)
    cbz     x9, 61f
    ldr     x10, [x19, #W_STRESS_END]
    ldr     x11, [x19, #W_HEAP]
    add     x11, x11, x9
    ldr     x9, [sp]                    //   plus room for what is wanted now
    add     x11, x11, x9
    cmp     x11, x10
    csel    x11, x11, x10, lo
    str     x11, [x19, #W_HEAP_END]
61:
    ldr     x0, [sp]
    ldp     x9, x10, [x19, #W_HEAP]
    add     x11, x9, x0
    cmp     x11, x10
    b.hi    7f
    str     x11, [x19, #W_HEAP]
    str     x9, [x19, #W_LAST]
    str     x9, [sp, #240]
    ldr     x10, [x19, #W_HEAP0]
    sub     x0, x9, x10
    lsr     x0, x0, #3
    ldr     x1, [x19, #W_BITS]
    bl      g_setbit
    ldr     x0, [sp, #240]
    b       8f
7:  ldr     x0, [sp]
    bl      g_fit
    str     xzr, [x19, #W_LAST]
8:  ldr     x1, [sp, #8]
    ldp     x2, x3, [sp, #16]
    ldp     x4, x5, [sp, #32]
    ldp     x6, x7, [sp, #48]
    ldp     x8, x11, [sp, #64]
    ldp     x12, x13, [sp, #80]
    ldp     x14, x15, [sp, #96]
    ldp     x16, x17, [sp, #112]
    ldp     x18, x20, [sp, #128]
    ldp     x21, x22, [sp, #144]
    ldp     x23, x24, [sp, #160]
    ldp     x25, x26, [sp, #176]
    ldp     x27, x28, [sp, #192]
    ldp     x29, x30, [sp, #208]
    add     sp, sp, #256
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
