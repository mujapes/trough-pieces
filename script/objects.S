// Objects, arrays and functions in the heap, and the instructions that work on them (stage 4, first part).
// Every one begins the same way: 0 its kind (1 function, 3 plain object, 4 array), 8 its prototype (an object value, or null),
// 16 where its own properties are (pairs: name, a string value; value), 24 how many (32 bits) and room for how many (32 bits).
// Then, a function: 32 its plan, 40 the scope it remembers, 48 the `this` it was made under (used by arrows).
// An array: 32 where its items are, 40 how many (32 bits) and room for how many (32 bits). An item never written reads undefined.
// Properties are searched in order, by text (the same string value is seen at once); shapes are to replace this search.
// These routines use x0-x17 only.
    .equ O_PROTO, 8
    .equ O_PROPS, 16
    .equ O_CNT, 24
    .equ O_CAP, 28
    .equ F_PLAN, 32
    .equ F_SCOPE, 40
    .equ F_THIS, 48
    .equ F_HOME, 56                     // a method's home: the object it was written in (0 if none)
    .equ A_ITEMS, 32
    .equ A_LEN, 40
    .equ A_CAP, 44
// o_keyeq: are the string values x1 and x2 the same text -> flags: eq if so. Uses x3-x8.
o_keyeq:
    cmp     x1, x2
    b.eq    9f
    and     x3, x1, #0xffffffffffff
    add     x3, x19, x3
    ldr     x4, [x3], #8
    and     x5, x2, #0xffffffffffff
    add     x5, x19, x5
    ldr     x6, [x5], #8
    cmp     x4, x6
    b.ne    9f
    lsr     x7, x4, #32                 // how many bytes: the units, twice over if they are wide
    and     x4, x4, #0xffffffff
    lsl     x4, x4, x7
1:  cbz     x4, 8f
    sub     x4, x4, #1
    ldrb    w7, [x3, x4]
    ldrb    w8, [x5, x4]
    cmp     w7, w8
    b.eq    1b
9:  ret
8:  cmp     x0, x0
    ret
// o_find: the object at the address x0, its own property named x1 -> x2 where its value is (an address), or 0. Uses x2-x13.
o_find:
    mov     x13, x30
    ldr     x9, [x0, #O_PROPS]
    add     x9, x19, x9
    ldr     w10, [x0, #O_CNT]
    add     x11, x9, x10, lsl #4
1:  cmp     x9, x11
    b.hs    7f
    ldr     x2, [x9]
    bl      o_keyeq
    b.eq    8f
    add     x9, x9, #16
    b       1b
7:  mov     x2, #0
    ret     x13
8:  add     x2, x9, #8
    ret     x13
// o_get: the object value x0, its property named x1, looked for in it and then along its prototypes -> x0 (undefined if nowhere)
o_get:
    mov     x14, x30
1:  and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    bl      o_find
    cbnz    x2, 8f
    ldr     x0, [x0, #O_PROTO]
    lsr     x3, x0, #48
    mov     w4, #T_OBJECT
    cmp     w3, w4
    b.eq    1b
    VAL     x0, T_UNDEF
    ret     x14
8:  ldr     x0, [x2]
    ret     x14
// o_put: the object at the address x0 gets x2 as its own property named x1 -> x0 not 0, or 0 if the world is full
o_put:
    stp     x29, x30, [sp, #-48]!
    stp     x0, x1, [sp, #16]
    str     x2, [sp, #32]
    bl      o_find
    cbz     x2, 1f
    ldr     x3, [sp, #32]
    str     x3, [x2]
    b       9f
1:  ldp     w10, w11, [x0, #O_CNT]
    cmp     w10, w11
    b.lo    4f
    lsl     w12, w11, #1                // no room: twice the room (4 to begin with), the pairs copied over
    mov     w3, #4
    cmp     w11, #0
    csel    w12, w3, w12, eq
    str     w12, [sp, #40]
    lsl     x0, x12, #4
    bl      w_alloc
    cbz     x0, 9f
    ldr     x1, [sp, #16]
    ldr     x3, [x1, #O_PROPS]
    add     x3, x19, x3
    ldr     w10, [x1, #O_CNT]
    add     x4, x19, x0
    lsl     x5, x10, #1
2:  cbz     x5, 3f
    ldr     x6, [x3], #8
    str     x6, [x4], #8
    sub     x5, x5, #1
    b       2b
3:  str     x0, [x1, #O_PROPS]
    ldr     w12, [sp, #40]
    str     w12, [x1, #O_CAP]
    mov     x0, x1
4:  ldr     x3, [x0, #O_PROPS]
    add     x3, x19, x3
    ldr     w10, [x0, #O_CNT]
    add     x3, x3, x10, lsl #4
    ldp     x1, x2, [sp, #24]
    stp     x1, x2, [x3]
    add     w10, w10, #1
    str     w10, [x0, #O_CNT]
9:  ldp     x29, x30, [sp], #48
    ret
// o_make: a new object of x0 bytes and the kind x1, with no prototype and nothing in it -> x0 where (0 if the world is full)
o_make:
    mov     x12, x30
    mov     x11, x0
    mov     x14, x1
    bl      w_alloc
    cbz     x0, 9f
    add     x9, x19, x0
    mov     x10, #0
1:  str     xzr, [x9, x10]
    add     x10, x10, #8
    cmp     x10, x11
    b.lo    1b
    str     x14, [x9]
    VAL     x10, T_NULL                 // what it inherits from, by its kind, once the library has said (see lib.S)
    cmp     x14, #3
    b.eq    2f
    cmp     x14, #4
    b.eq    3f
    cmp     x14, #1
    b.ne    5f
    ldr     x11, [x19, #(W_PROTOS + 16)]
    b       4f
2:  ldr     x11, [x19, #W_PROTOS]
    b       4f
3:  ldr     x11, [x19, #(W_PROTOS + 8)]
4:  cbz     x11, 5f
    mov     x10, x11
5:  str     x10, [x9, #O_PROTO]
9:  ret     x12
// a_set: the array at the address x0 gets x2 as its item number x1; it grows as needed -> x0 not 0, or 0 if there is no room
// (an item number of sixteen million or more is refused for now)
a_set:
    stp     x29, x30, [sp, #-48]!
    stp     x0, x1, [sp, #16]
    str     x2, [sp, #32]
    ldr     w4, [x0, #A_CAP]
    cmp     x1, x4
    b.lo    4f
    mov     x5, #0x1000000
    cmp     x1, x5
    b.hs    8f
    add     x5, x1, #1
    lsl     x6, x4, #1
    cmp     x5, x6
    csel    x5, x6, x5, lo
    mov     x6, #8
    cmp     x5, x6
    csel    x5, x6, x5, lo
    str     x5, [sp, #40]
    lsl     x0, x5, #3
    bl      w_alloc
    cbz     x0, 9f
    ldr     x1, [sp, #16]
    ldr     x6, [x1, #A_ITEMS]
    add     x6, x19, x6
    ldr     w3, [x1, #A_LEN]
    add     x7, x19, x0
    mov     x8, #0
2:  cmp     x8, x3
    b.hs    3f
    ldr     x9, [x6, x8, lsl #3]
    str     x9, [x7, x8, lsl #3]
    add     x8, x8, #1
    b       2b
3:  str     x0, [x1, #A_ITEMS]
    ldr     x5, [sp, #40]
    str     w5, [x1, #A_CAP]
    mov     x0, x1
    ldr     x1, [sp, #24]
4:  ldr     w3, [x0, #A_LEN]
    ldr     x6, [x0, #A_ITEMS]
    add     x6, x19, x6
    VAL     x7, T_UNDEF
5:  cmp     x3, x1
    b.hs    6f
    str     x7, [x6, x3, lsl #3]
    add     x3, x3, #1
    b       5b
6:  ldr     x2, [sp, #32]
    str     x2, [x6, x1, lsl #3]
    ldr     w3, [x0, #A_LEN]
    cmp     x1, x3
    b.lo    9f
    add     x3, x1, #1
    str     w3, [x0, #A_LEN]
    b       9f
8:  mov     x0, #0
9:  ldp     x29, x30, [sp], #48
    ret
// m_keys: the names the machine itself knows (length, prototype, constructor) are made once, in the world's head
m_keys:
    str     x30, [sp, #-16]!
    LIT     k_length, k_prototype
    str     x0, [x19, #W_K_LENGTH]
    LIT     k_prototype, k_constructor
    str     x0, [x19, #W_K_PROTOTYPE]
    LIT     k_constructor, k_tostring
    str     x0, [x19, #W_K_CONSTRUCTOR]
    LIT     k_tostring, k_end
    str     x0, [x19, #W_K_TOSTRING]
    LIT     k_valueof, k_toprim
    str     x0, [x19, #W_K_VALUEOF]
    LIT     k_toprim, k_toprim_end
    str     x0, [x19, #W_K_TOPRIM]
    ldr     x0, [x19, #W_K_VALUEOF]
    str     x0, [x19, #W_K_VALUEOF]
    LIT     e_full, e_wrong
    str     x0, [x19, #W_K_FULL]
    ldr     x30, [sp], #16
    ret
k_length:      .ascii "length"
k_prototype:   .ascii "prototype"
k_constructor: .ascii "constructor"
k_tostring:    .ascii "toString"
k_end:
k_valueof:     .ascii "valueOf"
k_toprim:      .ascii "@@toPrimitive"
k_toprim_end:
e_noprops: .ascii "TypeError: Cannot read properties of undefined or null"
e_noprops_end:
    .balign 4
m_noprops:
    adr     x0, e_noprops
    mov     x1, #(e_noprops_end - e_noprops)
    b       m_fail
// m_fnproto: the function value x0, its `prototype` property (made the first time it is asked for: an object whose
// `constructor` is the function) -> x0 the value, or 0 if the world is full
m_fnproto:
    stp     x29, x30, [sp, #-32]!
    and     x0, x0, #0xffffffffffff
    str     x0, [sp, #16]
    add     x0, x19, x0
    ldr     x1, [x19, #W_K_PROTOTYPE]
    bl      o_find
    cbz     x2, 1f
    ldr     x0, [x2]
    b       9f
1:  mov     x0, #32
    mov     x1, #3
    bl      o_make
    cbz     x0, 9f
    str     x0, [sp, #24]
    add     x0, x19, x0
    ldr     x1, [x19, #W_K_CONSTRUCTOR]
    ldr     x2, [sp, #16]
    mov     x16, #(T_OBJECT << 48)
    orr     x2, x2, x16
    bl      o_put
    cbz     x0, 9f
    ldr     x0, [sp, #16]
    add     x0, x19, x0
    ldr     x1, [x19, #W_K_PROTOTYPE]
    ldr     x2, [sp, #24]
    mov     x16, #(T_OBJECT << 48)
    orr     x2, x2, x16
    bl      o_put
    cbz     x0, 9f
    ldr     x0, [sp, #24]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
9:  ldp     x29, x30, [sp], #32
    ret
// m_getprop: the value x0, its property named x1 (a string value) -> x0. An array's and a string's length are worked out here.
m_getprop:
    stp     x29, x30, [sp, #-32]!
    stp     x0, x1, [sp, #16]
    lsr     x9, x0, #48
    mov     w10, #T_OBJECT
    cmp     w9, w10
    b.ne    5f
    and     x9, x0, #0xffffffffffff
    ldr     x9, [x19, x9]
    cmp     x9, #4
    b.ne    2f
    ldr     x2, [x19, #W_K_LENGTH]
    bl      o_keyeq
    b.ne    4f
    ldr     x0, [sp, #16]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w0, [x0, #A_LEN]
    ucvtf   d0, x0
    fmov    x0, d0
    b       9f
2:  cmp     x9, #1
    b.ne    4f
    ldr     x2, [x19, #W_K_PROTOTYPE]
    bl      o_keyeq
    b.ne    4f
    ldr     x0, [sp, #16]
    bl      m_fnproto
    cbnz    x0, 9f
    ldp     x29, x30, [sp], #32
    b       m_full
4:  ldp     x0, x1, [sp, #16]
    bl      o_get
    b       9f
5:  mov     w10, #T_STRING
    cmp     w9, w10
    b.ne    6f
    ldr     x2, [x19, #W_K_LENGTH]
    bl      o_keyeq
    b.ne    7f
    ldr     x0, [sp, #16]
    STRV    x0, x0, x1
    ucvtf   d0, x1
    fmov    x0, d0
    b       9f
6:  mov     w10, #T_UNDEF
    sub     w9, w9, w10
    cmp     w9, #1
    b.hi    7f
    ldp     x29, x30, [sp], #32
    b       m_noprops
7:  ldr     x0, [sp, #16]               // a string, number or boolean: what the library gave its kind
    lsr     x9, x0, #48
    mov     x2, #(W_PROTOS + 24)
    mov     w10, #T_STRING
    cmp     w9, w10
    b.eq    71f
    mov     x2, #(W_PROTOS + 40)
    mov     w10, #T_BOOL
    cmp     w9, w10
    b.eq    71f
    mov     x2, #(W_PROTOS + 32)
    mov     w10, #T_UNDEF
    cmp     w9, w10
    b.hs    72f
71: ldr     x0, [x19, x2]
    cbz     x0, 72f
    ldr     x1, [sp, #24]
    bl      o_get
    b       9f
72: VAL     x0, T_UNDEF
9:  ldp     x29, x30, [sp], #32
    ret
// m_setprop: the value x0 gets x2 as its property named x1. Setting an array's length cuts it or fills it out.
m_setprop:
    stp     x29, x30, [sp, #-48]!
    stp     x0, x1, [sp, #16]
    str     x2, [sp, #32]
    lsr     x9, x0, #48
    mov     w10, #T_OBJECT
    cmp     w9, w10
    b.ne    5f
    and     x9, x0, #0xffffffffffff
    ldr     x9, [x19, x9]
    cmp     x9, #4
    b.ne    4f
    ldr     x2, [x19, #W_K_LENGTH]
    bl      o_keyeq
    b.ne    4f
    ldr     x0, [sp, #32]
    bl      v_number
    fcvtzu  x1, d0
    ldr     x0, [sp, #16]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w3, [x0, #A_LEN]
    cmp     x1, x3
    b.hi    3f
    str     w1, [x0, #A_LEN]
    b       9f
3:  sub     x1, x1, #1
    VAL     x2, T_UNDEF
    bl      a_set
    cbz     x0, 8f
    b       9f
4:  ldp     x0, x1, [sp, #16]           // its own property is stored to; without one, a setter along the prototypes is
    and     x0, x0, #0xffffffffffff     // looked for before a new property is made. A setter is handed back in x0.
    add     x0, x19, x0
    str     x0, [sp, #40]
    bl      o_find
    cbz     x2, 42f
    ldr     x3, [x2]
    TAGIS   x3, T_ACC
    b.eq    45f
    ldr     x3, [sp, #32]
    str     x3, [x2]
    b       9f
42: ldr     x0, [x0, #O_PROTO]
    TAGIS   x0, T_OBJECT
    b.ne    44f
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    bl      o_find
    cbz     x2, 42b
    ldr     x3, [x2]
    TAGIS   x3, T_ACC
    b.eq    45f
44: ldr     x0, [sp, #40]
    ldr     x1, [sp, #24]
    ldr     x2, [sp, #32]
    bl      o_put
    cbz     x0, 8f
    b       9f
45: mov     x0, x3
    b       91f
5:  mov     w10, #T_UNDEF
    sub     w9, w9, w10
    cmp     w9, #1
    b.hi    9f
    ldp     x29, x30, [sp], #48
    b       m_noprops
8:  ldp     x29, x30, [sp], #48
    b       m_full
9:  mov     x0, #0
91: ldp     x29, x30, [sp], #48
    ret
// m_index: is the key x1 a whole number that can be an item's number -> w3 1 and x2 the number, or w3 0. Uses x16, x17, d0, d1.
m_index:
    mov     w3, #0
    ISNUM   x1
    b.hs    9f
    fmov    d0, x1
    fcvtzu  x2, d0
    ucvtf   d1, x2
    fcmp    d0, d1
    cset    w3, eq
    ret
9:  mov     w16, #T_STRING              // text that is a whole number as it would be printed ("7", not "07"), to nine digits
    cmp     w17, w16
    b.ne    8f
    and     x16, x1, #0xffffffffffff
    add     x16, x19, x16
    ldr     x17, [x16], #8
    sub     x2, x17, #1
    cmp     x2, #9
    b.hs    8f
    mov     x2, #0
    ldrb    w3, [x16]
    cmp     w3, #'0'
    b.ne    1f
    cmp     x17, #1
    b.ne    8f
1:  ldrb    w3, [x16], #1
    sub     w3, w3, #'0'
    cmp     w3, #10
    b.hs    8f
    add     x2, x2, x2, lsl #2
    add     x2, x3, x2, lsl #1
    subs    x17, x17, #1
    b.ne    1b
    mov     w3, #1
    ret
8:  mov     w3, #0
    ret
// m_this: the `this` of the running call -> x0 (undefined outside any call)
m_this:
    VAL     x0, T_UNDEF
    cmp     x20, x19
    b.eq    9f
    ldr     x0, [x20, #40]
9:  ret

i_object:
    mov     x0, #32
    mov     x1, #3
    bl      o_make
    cbz     x0, m_full
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
    PUSH    x0
    NEXT
i_array:                                // + 16 bits: how many values on the stack become its items
    mov     x0, #48
    mov     x1, #4
    bl      o_make
    cbz     x0, m_full
    U16     w5
    mov     x4, x0
    cbz     w5, 3f
    lsl     x0, x5, #3
    bl      w_alloc
    cbz     x0, m_full
    add     x6, x19, x4
    str     x0, [x6, #A_ITEMS]
    stp     w5, w5, [x6, #A_LEN]
    add     x7, x19, x0
    sub     x22, x22, x5, lsl #3
    mov     x8, #0
1:  ldr     x9, [x22, x8, lsl #3]
    str     x9, [x7, x8, lsl #3]
    add     x8, x8, #1
    cmp     x8, x5
    b.lo    1b
3:  mov     x16, #(T_OBJECT << 48)
    orr     x0, x4, x16
    PUSH    x0
    NEXT
i_getp:                                 // + 16 bits: the name (a constant). object -> value
    U16     w1
    ldr     x1, [x23, x1, lsl #3]
    ldr     x0, [x22, #-8]
    bl      m_getprop
    TAGIS   x0, T_ACC
    b.eq    1f
    str     x0, [x22, #-8]
    NEXT
1:  ldr     x11, [x22, #-8]
    sub     x12, x22, #8
// m_getter: the property read was a getter and setter (x0): the getter is called with x11 as `this`, its answer to go to x12
// (the stack ends there meanwhile)
m_getter:
    and     x0, x0, #0xffffffffffff
    ldr     x2, [x19, x0]
    TAGIS   x2, T_OBJECT
    b.eq    1f
    VAL     x0, T_UNDEF
    str     x0, [x12], #8
    mov     x22, x12
    NEXT
1:  add     x22, x12, #8
    PUSH    x2
    mov     x1, x22
    mov     x0, #0
    mov     x13, #0
    b       m_call
// m_setter: the property stored to has a setter (in x0's pair): on the stack the object and the value; the setter is called
// with the value, its answer dropped, and the value is what stays
m_setter:
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x2, [x0, #8]
    ldp     x11, x3, [x22, #-16]
    str     x3, [x22, #-16]
    TAGIS   x2, T_OBJECT
    b.eq    1f
    sub     x22, x22, #8
    NEXT
1:  str     x2, [x22, #-8]
    sub     x12, x22, #8
    PUSH    x3
    sub     x1, x22, #8
    mov     x0, #1
    mov     x13, #2
    b       m_call
i_extends:                              // parent, class -> class: the class inherits from the parent, its prototype from the parent's
    ldp     x0, x1, [x22, #-16]
    TAGIS   x0, T_OBJECT
    b.ne    m_notfn
    and     x2, x1, #0xffffffffffff
    add     x2, x19, x2
    str     x0, [x2, #O_PROTO]
    bl      m_fnproto
    cbz     x0, m_full
    str     x0, [sp, #-16]!
    ldr     x0, [x22, #-8]
    bl      m_fnproto
    ldr     x3, [sp], #16
    cbz     x0, m_full
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    str     x3, [x0, #O_PROTO]
    ldr     x1, [x22, #-8]
    sub     x22, x22, #8
    str     x1, [x22, #-8]
    NEXT
i_home:
    ldr     x0, [x22, #-8]
    ldr     x1, [x22, #-24]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    str     x1, [x0, #F_HOME]
    NEXT
i_super:
    U16     w5
    ldr     x0, [x20, #48]
    and     x1, x0, #0xffffffffffff
    add     x1, x19, x1
    mov     w6, #0xffff
    cmp     w5, w6
    b.ne    1f
    ldr     x0, [x1, #O_PROTO]
    b       8f
1:  ldr     x0, [x1, #F_HOME]
    TAGIS   x0, T_OBJECT
    b.ne    7f
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x0, [x0, #O_PROTO]
    TAGIS   x0, T_OBJECT
    b.ne    7f
    ldr     x1, [x23, x5, lsl #3]
    bl      m_getprop
    TAGIS   x0, T_ACC
    b.ne    8f
7:  VAL     x0, T_UNDEF
8:  PUSH    x0
    NEXT
i_defacc:                               // + 8 bits: 0 a getter, 1 a setter. object, key, function -> object
    ldr     x0, [x22, #-16]
    bl      v_text
    cbz     x0, m_full
    str     x0, [x22, #-16]
    mov     x1, x0
    ldr     x0, [x22, #-24]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    bl      o_find
    cbz     x2, 1f
    ldr     x3, [x2]
    TAGIS   x3, T_ACC
    b.eq    2f
1:  mov     x0, #16
    bl      w_alloc
    cbz     x0, m_full
    add     x9, x19, x0
    VAL     x10, T_UNDEF
    stp     x10, x10, [x9]
    mov     x16, #(T_ACC << 48)
    orr     x2, x0, x16
    str     x2, [sp, #-16]!
    ldr     x0, [x22, #-24]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x1, [x22, #-16]
    bl      o_put
    ldr     x3, [sp], #16
    cbz     x0, m_full
2:  and     x3, x3, #0xffffffffffff
    add     x3, x19, x3
    ldrb    w9, [x21], #1
    ldr     x4, [x22, #-8]
    str     x4, [x3, x9, lsl #3]
    sub     x22, x22, #16
    NEXT
i_setp:                                 // object, value -> value
    U16     w1
    ldr     x1, [x23, x1, lsl #3]
    ldp     x0, x2, [x22, #-16]
    bl      m_setprop
    cbnz    x0, m_setter
    ldr     x0, [x22, #-8]
    sub     x22, x22, #8
    str     x0, [x22, #-8]
    NEXT
i_initp:                                // object, value -> object (a literal being filled)
    U16     w1
    ldr     x1, [x23, x1, lsl #3]
    ldp     x0, x2, [x22, #-16]
    bl      m_setprop
    sub     x22, x22, #8
    NEXT
i_gete:                                 // object, key -> value. i_getek: object, key -> object, value (a method about to be called)
i_getek:
    ldp     x0, x1, [x22, #-16]
    bl      m_index
    cbz     w3, 5f
    lsr     x4, x0, #48
    mov     w5, #T_OBJECT
    cmp     w4, w5
    b.ne    3f
    and     x6, x0, #0xffffffffffff
    add     x6, x19, x6
    ldr     x7, [x6]
    cmp     x7, #4
    b.ne    5f
    ldr     w7, [x6, #A_LEN]
    cmp     x2, x7
    b.hs    4f
    ldr     x6, [x6, #A_ITEMS]
    add     x6, x19, x6
    ldr     x0, [x6, x2, lsl #3]
    b       8f
3:  mov     w5, #T_STRING
    cmp     w4, w5
    b.ne    5f
    and     x6, x0, #0xffffffffffff
    add     x6, x19, x6
    ldr     x7, [x6], #8
    lsr     x8, x7, #32
    and     x7, x7, #0xffffffff
    cmp     x2, x7
    b.hs    4f
    cbz     x8, 31f
    ldrh    w0, [x6, x2, lsl #1]
    b       32f
31: ldrb    w0, [x6, x2]
32: bl      w_unit
    cbz     x0, m_full
    b       8f
4:  VAL     x0, T_UNDEF
    b       8f
5:  ldr     x0, [x22, #-8]
    bl      v_text
    cbz     x0, m_full
    mov     x1, x0
    ldr     x0, [x22, #-16]
    bl      m_getprop
    TAGIS   x0, T_ACC
    b.ne    8f
    ldrb    w9, [x21, #-1]
    cmp     w9, #OP_GETEK
    b.eq    6f
    sub     x22, x22, #8
    ldr     x11, [x22, #-8]
    b       7f
6:  ldr     x11, [x22, #-16]
7:  sub     x12, x22, #8
    b       m_getter
8:  ldrb    w9, [x21, #-1]
    cmp     w9, #OP_GETEK
    b.eq    9f
    sub     x22, x22, #8
9:  str     x0, [x22, #-8]
    NEXT
i_sete:                                 // object, key, value -> value. i_inite: -> object
i_inite:
    ldp     x0, x1, [x22, #-24]
    bl      m_index
    cbz     w3, 5f
    lsr     x4, x0, #48
    mov     w5, #T_OBJECT
    cmp     w4, w5
    b.ne    5f
    and     x6, x0, #0xffffffffffff
    add     x6, x19, x6
    ldr     x7, [x6]
    cmp     x7, #4
    b.ne    5f
    mov     x0, x6
    mov     x1, x2
    ldr     x2, [x22, #-8]
    bl      a_set
    cbz     x0, m_full
    b       8f
5:  ldr     x0, [x22, #-16]
    bl      v_text
    cbz     x0, m_full
    mov     x1, x0
    ldr     x0, [x22, #-24]
    ldr     x2, [x22, #-8]
    bl      m_setprop
    cbz     x0, 8f
    ldrb    w9, [x21, #-1]
    cmp     w9, #OP_INITE
    b.eq    8f
    ldr     x9, [x22, #-24]
    ldr     x3, [x22, #-8]
    sub     x22, x22, #8
    stp     x9, x3, [x22, #-16]
    b       m_setter
8:  ldr     x0, [x22, #-8]
    sub     x22, x22, #16
    ldrb    w9, [x21, #-1]
    cmp     w9, #OP_INITE
    b.eq    m_next
    str     x0, [x22, #-8]
    NEXT
i_this:
    bl      m_this
    PUSH    x0
    NEXT
i_swap:
    ldp     x0, x1, [x22, #-16]
    stp     x1, x0, [x22, #-16]
    NEXT
i_rot:                                  // a, b, c -> c, a, b
    ldp     x0, x1, [x22, #-24]
    ldr     x2, [x22, #-8]
    stp     x2, x0, [x22, #-24]
    str     x1, [x22, #-8]
    NEXT
i_pick:                                 // + 8 bits: a copy of the value that many below the top
    ldrb    w0, [x21], #1
    add     x0, x0, #1
    sub     x1, x22, x0, lsl #3
    ldr     x0, [x1]
    PUSH    x0
    NEXT
i_dup2:
    ldp     x0, x1, [x22, #-16]
    PUSH    x0
    PUSH    x1
    NEXT
i_callm:                                // + 8 bits: how many arguments; under them the function, and under it the object it is called on
    ldrb    w0, [x21], #1
m_callm_n:
    sub     x1, x22, x0, lsl #3
    ldr     x11, [x1, #-16]
    sub     x12, x1, #16
    mov     x13, #0
    b       m_call
i_new:                                  // + 8 bits: how many arguments; under them the function. A new object is its `this`,
    ldrb    w0, [x21], #1               // and the answer unless the function answers with an object of its own.
m_new_n:
    sub     x1, x22, x0, lsl #3
    stp     x0, xzr, [sp, #-16]!        // kept: how many arguments, the prototype
    ldr     x0, [x1, #-8]
    TAGIS   x0, T_OBJECT
    b.ne    9f
    and     x2, x0, #0xffffffffffff
    ldr     x2, [x19, x2]
    cmp     x2, #1
    b.ne    9f
    bl      m_fnproto
    cbz     x0, 8f
    str     x0, [sp, #8]
    mov     x0, #32
    mov     x1, #3
    bl      o_make
    ldp     x3, x2, [sp], #16
    cbz     x0, m_full
    add     x9, x19, x0
    TAGIS   x2, T_OBJECT
    b.ne    1f
    str     x2, [x9, #O_PROTO]
1:  mov     x16, #(T_OBJECT << 48)
    orr     x11, x0, x16
    mov     x0, x3
    sub     x1, x22, x0, lsl #3
    sub     x12, x1, #8
    mov     x13, #1
    b       m_call
8:  add     sp, sp, #16
    b       m_full
9:  add     sp, sp, #16
    b       m_notfn
i_append:                               // array, value -> array, the value its new last item
    POP     x2
    ldr     x0, [x22, #-8]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w1, [x0, #A_LEN]
    bl      a_set
    cbz     x0, m_full
    NEXT
i_spread:                               // array, array or string -> array, each item of the second added to the first
    ldr     x0, [x22, #-8]
    TAGIS   x0, T_STRING
    b.ne    1f
    bl      m_chars
    cbz     x0, m_full
    str     x0, [x22, #-8]
1:  TAGIS   x0, T_OBJECT
    b.ne    8f
    and     x1, x0, #0xffffffffffff
    ldr     x1, [x19, x1]
    cmp     x1, #4
    b.ne    8f
    str     xzr, [sp, #-16]!            // which item is next
2:  ldp     x0, x5, [x22, #-16]
    and     x5, x5, #0xffffffffffff
    add     x5, x19, x5
    ldr     x3, [sp]
    ldr     w4, [x5, #A_LEN]
    cmp     x3, x4
    b.hs    3f
    add     x4, x3, #1
    str     x4, [sp]
    ldr     x5, [x5, #A_ITEMS]
    add     x5, x19, x5
    ldr     x2, [x5, x3, lsl #3]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w1, [x0, #A_LEN]
    bl      a_set
    cbnz    x0, 2b
    add     sp, sp, #16
    b       m_full
3:  add     sp, sp, #16
    sub     x22, x22, #8
    NEXT
8:  mov     x6, #1
    b       m_drain
i_tail:                                 // + 16 bits: from which item. array or string -> a new array of the items from there on
    U16     w5
    ldr     x0, [x22, #-8]
    TAGIS   x0, T_STRING
    b.ne    1f
    str     x5, [sp, #-16]!
    bl      m_chars
    ldr     x5, [sp], #16
    cbz     x0, m_full
1:  TAGIS   x0, T_OBJECT
    b.ne    8f
    and     x1, x0, #0xffffffffffff
    add     x1, x19, x1
    ldr     x2, [x1]
    cmp     x2, #4
    b.ne    8f
    ldr     w2, [x1, #A_LEN]
    ldr     x3, [x1, #A_ITEMS]
    add     x3, x19, x3
    cmp     x5, x2
    csel    x5, x2, x5, hi
    add     x0, x3, x5, lsl #3
    sub     x1, x2, x5
    bl      a_from
    cbz     x0, m_full
    str     x0, [x22, #-8]
    NEXT
8:  mov     x6, #3
    b       m_drain
i_apply:                                // + 8 bits: which call. The array on top is taken apart into the call's arguments
    ldrb    w9, [x21], #1
    POP     x0
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w4, [x0, #A_LEN]
    add     x5, x22, x4, lsl #3
    add     x5, x5, #8
    cmp     x5, x26
    b.hi    m_deep
    ldr     x5, [x0, #A_ITEMS]
    add     x5, x19, x5
    mov     x6, #0
1:  cmp     x6, x4
    b.hs    2f
    ldr     x7, [x5, x6, lsl #3]
    str     x7, [x22], #8
    add     x6, x6, #1
    b       1b
2:  mov     x0, x4
    cbz     w9, m_call_n
    cmp     w9, #2
    b.lo    m_callm_n
    b.eq    m_new_n
    b       m_print_n

// m_plan: the function under the arguments at x1, looked at again -> x2 it, x4 its plan, w5 parameters, w6 variables, x9 flags
m_plan:
    ldr     x2, [x1, #-8]
    and     x2, x2, #0xffffffffffff
    add     x2, x19, x2
    ldr     x4, [x2, #F_PLAN]
    add     x4, x19, x4
    ldr     w5, [x4, #16]
    ldr     w6, [x4, #20]
    ldr     x9, [x4, #24]
    ret
// a_from: a new array of the x1 values at the address x0 -> x0 the array value, or 0 if the world is full. Uses x0-x14, x16.
a_from:
    stp     x29, x30, [sp, #-32]!
    stp     x0, x1, [sp, #16]
    mov     x0, #48
    mov     x1, #4
    bl      o_make
    cbz     x0, 9f
    mov     x4, x0
    ldp     x8, x5, [sp, #16]
    cbz     x5, 3f
    lsl     x0, x5, #3
    bl      w_alloc
    cbz     x0, 9f
    add     x6, x19, x4
    str     x0, [x6, #A_ITEMS]
    stp     w5, w5, [x6, #A_LEN]
    add     x7, x19, x0
    mov     x3, #0
1:  ldr     x9, [x8, x3, lsl #3]
    str     x9, [x7, x3, lsl #3]
    add     x3, x3, #1
    cmp     x3, x5
    b.lo    1b
3:  mov     x16, #(T_OBJECT << 48)
    orr     x0, x4, x16
9:  ldp     x29, x30, [sp], #32
    ret
// a_text: the array value x0 as text: its items' texts with commas between (undefined and null give nothing) -> x0, 0 if full.
// (An array that holds itself is not guarded against yet.)
a_text:
    stp     x29, x30, [sp, #-48]!
    str     x0, [sp, #16]
    str     xzr, [sp, #24]
    adr     x0, k_end
    mov     x1, #0
    bl      w_string
    cbz     x0, 9f
    str     x0, [sp, #32]
1:  ldr     x0, [sp, #16]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w1, [x0, #A_LEN]
    ldr     x2, [sp, #24]
    cmp     x2, x1
    b.hs    8f
    cbz     x2, 2f
    adr     x0, k_comma
    mov     x1, #1
    bl      w_string
    cbz     x0, 9f
    mov     x1, x0
    ldr     x0, [sp, #32]
    bl      v_join
    cbz     x0, 9f
    str     x0, [sp, #32]
2:  ldr     x0, [sp, #16]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x1, [x0, #A_ITEMS]
    add     x1, x19, x1
    ldr     x2, [sp, #24]
    ldr     x0, [x1, x2, lsl #3]
    add     x2, x2, #1
    str     x2, [sp, #24]
    lsr     x3, x0, #48
    mov     w4, #T_UNDEF
    sub     w3, w3, w4
    cmp     w3, #1
    b.ls    1b
    bl      v_text
    cbz     x0, 9f
    mov     x1, x0
    ldr     x0, [sp, #32]
    bl      v_join
    cbz     x0, 9f
    str     x0, [sp, #32]
    b       1b
8:  ldr     x0, [sp, #32]
9:  ldp     x29, x30, [sp], #48
    ret
k_comma: .byte ','
    .balign 4
// m_delprop: the value x0 loses its own property named x1, if it has it; the ones after it keep their order
m_delprop:
    mov     x15, x30
    TAGIS   x0, T_OBJECT
    b.ne    9f
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    bl      o_find
    cbz     x2, 9f
    sub     x2, x2, #8
    ldr     x3, [x0, #O_PROPS]
    add     x3, x19, x3
    ldr     w4, [x0, #O_CNT]
    add     x3, x3, x4, lsl #4
    sub     w4, w4, #1
    str     w4, [x0, #O_CNT]
1:  add     x5, x2, #16
    cmp     x5, x3
    b.hs    9f
    ldp     x6, x7, [x5]
    stp     x6, x7, [x2]
    mov     x2, x5
    b       1b
9:  ret     x15
i_in:                                   // key, object -> is it a property of the object, or of its prototypes
    ldp     x1, x0, [x22, #-16]
    TAGIS   x0, T_OBJECT
    b.ne    m_noprops
    bl      m_index
    and     x6, x0, #0xffffffffffff
    add     x6, x19, x6
    cbz     w3, 5f
    ldr     x7, [x6]
    cmp     x7, #4
    b.ne    5f
    ldr     w7, [x6, #A_LEN]
    cmp     x2, x7
    cset    w0, lo
    b       8f
5:  ldr     x0, [x22, #-16]
    bl      v_text
    cbz     x0, m_full
    mov     x1, x0
    ldr     x0, [x22, #-8]
6:  and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    bl      o_find
    cbnz    x2, 7f
    ldr     x0, [x0, #O_PROTO]
    TAGIS   x0, T_OBJECT
    b.eq    6b
    mov     w0, #0
    b       8f
7:  mov     w0, #1
8:  sub     x22, x22, #8
    b       m_bool
i_instof:                               // value, function -> is the function's prototype among the value's prototypes
    ldr     x0, [x22, #-8]
    TAGIS   x0, T_OBJECT
    b.ne    m_notfn
    and     x2, x0, #0xffffffffffff
    ldr     x2, [x19, x2]
    cmp     x2, #1
    b.ne    m_notfn
    bl      m_fnproto
    cbz     x0, m_full
    ldr     x4, [x22, #-16]
    mov     w5, #0
1:  TAGIS   x4, T_OBJECT
    b.ne    8f
    and     x4, x4, #0xffffffffffff
    add     x4, x19, x4
    ldr     x4, [x4, #O_PROTO]
    cmp     x4, x0
    b.ne    1b
    mov     w5, #1
8:  mov     w0, w5
    sub     x22, x22, #8
    b       m_bool
i_delp:                                 // + 16 bits: the name. object -> true
    U16     w1
    ldr     x1, [x23, x1, lsl #3]
    ldr     x0, [x22, #-8]
    bl      m_delprop
    mov     w0, #1
    b       m_bool
i_dele:                                 // object, key -> true (an array's item becomes undefined)
    ldp     x0, x1, [x22, #-16]
    bl      m_index
    cbz     w3, 5f
    TAGIS   x0, T_OBJECT
    b.ne    8f
    and     x6, x0, #0xffffffffffff
    add     x6, x19, x6
    ldr     x7, [x6]
    cmp     x7, #4
    b.ne    5f
    ldr     w7, [x6, #A_LEN]
    cmp     x2, x7
    b.hs    8f
    ldr     x6, [x6, #A_ITEMS]
    add     x6, x19, x6
    VAL     x7, T_UNDEF
    str     x7, [x6, x2, lsl #3]
    b       8f
5:  ldr     x0, [x22, #-8]
    bl      v_text
    cbz     x0, m_full
    mov     x1, x0
    ldr     x0, [x22, #-16]
    bl      m_delprop
8:  sub     x22, x22, #8
    mov     w0, #1
    b       m_bool

// Loops over keys and items. The loop keeps two values on the stack: an array (of the keys, or the thing looped over itself)
// and how far it has got. OP_KEYS and OP_ITER make the first from the value given; OP_FORNEXT takes the next item or leaves.
// k_add: the value x0 joins the end of the array at the distance x1 -> x0 not 0, or 0 if there is no room
k_add:
    mov     x2, x0
    add     x0, x19, x1
    ldr     w1, [x0, #A_LEN]
    b       a_set
// m_keylist: the names a for..in loop goes through for the value x0, as an array of strings -> x0, or 0 if the world is full.
// An array's item numbers first, then its own properties in the order they were made, then its prototypes' (none twice).
// (Not right yet: whole-number names of a plain object should come first, in order; `constructor` on a prototype is left
// out by name, until properties can be marked as not listed.) Kept: 16 the list, 24 the object, 32 how far, 40 past the first?
m_keylist:
    stp     x29, x30, [sp, #-64]!
    str     x0, [sp, #24]
    stp     xzr, xzr, [sp, #32]
    mov     x0, #48
    mov     x1, #4
    bl      o_make
    cbz     x0, 9f
    str     x0, [sp, #16]
    ldr     x0, [sp, #24]
    TAGIS   x0, T_OBJECT
    b.ne    8f
    and     x0, x0, #0xffffffffffff
    ldr     x1, [x19, x0]
    cmp     x1, #4
    b.ne    3f
1:  ldr     x0, [sp, #24]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w1, [x0, #A_LEN]
    ldr     x2, [sp, #32]
    cmp     x2, x1
    b.hs    2f
    ucvtf   d0, x2
    add     x2, x2, #1
    str     x2, [sp, #32]
    bl      num_text
    cbz     x0, 9f
    ldr     x1, [sp, #16]
    bl      k_add
    cbz     x0, 9f
    b       1b
2:  str     xzr, [sp, #32]
3:  ldr     x0, [sp, #24]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w1, [x0, #O_CNT]
    ldr     x2, [sp, #32]
    cmp     x2, x1
    b.hs    6f
    ldr     x3, [x0, #O_PROPS]
    add     x3, x19, x3
    add     x3, x3, x2, lsl #4
    ldr     x1, [x3]
    add     x2, x2, #1
    str     x2, [sp, #32]
    ldr     x4, [sp, #40]
    cbz     x4, 4f
    ldr     x2, [x19, #W_K_CONSTRUCTOR]
    bl      o_keyeq
    b.eq    3b
4:  ldr     x9, [sp, #16]
    add     x9, x19, x9
    ldr     w10, [x9, #A_LEN]
    ldr     x9, [x9, #A_ITEMS]
    add     x9, x19, x9
    mov     x11, #0
5:  cmp     x11, x10
    b.hs    51f
    ldr     x2, [x9, x11, lsl #3]
    add     x11, x11, #1
    bl      o_keyeq
    b.eq    3b
    b       5b
51: mov     x0, x1
    ldr     x1, [sp, #16]
    bl      k_add
    cbz     x0, 9f
    b       3b
6:  ldr     x0, [sp, #24]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x0, [x0, #O_PROTO]
    str     x0, [sp, #24]
    mov     x1, #1
    str     x1, [sp, #40]
    str     xzr, [sp, #32]
    ldr     x16, [x19, #W_OWNONLY]      // the library's own objects are not gone through, nor anything inherited when only
    cbnz    x16, 8f                     // the value's own names are wanted
    add     x15, x19, #W_PROTOS
    add     x16, x15, #48
61: ldr     x17, [x15], #8
    cmp     x17, x0
    b.eq    8f
    cmp     x15, x16
    b.lo    61b
    TAGIS   x0, T_OBJECT
    b.eq    3b
8:  ldr     x0, [sp, #16]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
9:  ldp     x29, x30, [sp], #64
    ret
// m_chars: the string value x0 as an array of its characters, each a string -> x0, or 0 if the world is full
// (bytes for now: a character outside ASCII comes apart, until strings are kept as the language's units)
m_chars:
    stp     x29, x30, [sp, #-48]!
    str     x0, [sp, #16]
    str     xzr, [sp, #24]
    mov     x0, #48
    mov     x1, #4
    bl      o_make
    cbz     x0, 9f
    str     x0, [sp, #32]
    ldr     x1, [sp, #16]
    STRV    x1, x1, x2
    cbz     x2, 8f
    lsl     x0, x2, #3
    bl      w_alloc
    cbz     x0, 9f
    ldr     x4, [sp, #32]
    add     x4, x19, x4
    str     x0, [x4, #A_ITEMS]
    ldr     x1, [sp, #16]
    STRV    x1, x1, x2
    str     w2, [x4, #A_CAP]
1:  ldr     x1, [sp, #16]
    STRV    x1, x1, x2
    ldr     x3, [sp, #24]
    cmp     x3, x2
    b.hs    8f
    ldr     x4, [sp, #16]
    and     x4, x4, #0xffffffffffff
    ldr     x4, [x19, x4]
    lsr     x4, x4, #32
    cbz     x4, 11f
    ldrh    w0, [x1, x3, lsl #1]
    b       12f
11: ldrb    w0, [x1, x3]
12: bl      w_unit
    cbz     x0, 9f
    ldr     x4, [sp, #32]
    add     x4, x19, x4
    ldr     x5, [x4, #A_ITEMS]
    add     x5, x19, x5
    ldr     x3, [sp, #24]
    str     x0, [x5, x3, lsl #3]
    add     x3, x3, #1
    str     x3, [sp, #24]
    str     w3, [x4, #A_LEN]
    b       1b
8:  ldr     x0, [sp, #32]
    mov     x16, #(T_OBJECT << 48)
    orr     x0, x0, x16
9:  ldp     x29, x30, [sp], #48
    ret
e_noiter: .ascii "TypeError: the value is not iterable"
e_noiter_end:
    .balign 4
i_keys:                                 // value -> the array of names to loop over
    ldr     x0, [x22, #-8]
    bl      m_keylist
    cbz     x0, m_full
    str     x0, [x22, #-8]
    NEXT
i_iter:                                 // value -> the array to loop over: an array is itself, a string gives its characters
    ldr     x0, [x22, #-8]
    TAGIS   x0, T_STRING
    b.ne    1f
    bl      m_chars
    cbz     x0, m_full
    str     x0, [x22, #-8]
    NEXT
1:  TAGIS   x0, T_OBJECT
    b.ne    2f
    and     x1, x0, #0xffffffffffff
    ldr     x1, [x19, x1]
    cmp     x1, #4
    b.eq    m_next
2:  mov     x6, #1
    b       m_drain
i_fornext:                              // + 32 bits: how far to jump when there are no more. array, place -> array, place + 1, item
    FAR     x1
    ldp     x0, x2, [x22, #-16]
    fmov    d0, x2
    fcvtzu  x3, d0
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     w4, [x0, #A_LEN]
    cmp     x3, x4
    b.lo    1f
    add     x21, x21, x1
    NEXT
1:  ldr     x0, [x0, #A_ITEMS]
    add     x0, x19, x0
    ldr     x0, [x0, x3, lsl #3]
    add     x3, x3, #1
    ucvtf   d0, x3
    str     d0, [x22, #-8]
    PUSH    x0
    NEXT
