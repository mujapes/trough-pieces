// dom, written by hand (ARM64). The meaning is dom/intent.md.
// Entries: x0 the tree block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Inside ask: x19 tree, x20 where the answer grows, x21 its limit, x22/x23 the rest of the request and its end,
// x29 where the answer began, x28 the stack to fall back to when a request is refused. x24-x27 belong to whoever is running.
    .text
    .global begin
    .global ask
    .equ TREE, 9
    .equ T_NODES, 64
    .equ T_BYTES, 68
    .equ T_CUR, 72
    .equ HDR, 96
    .equ REC, 48
    .equ N_KIND, 0
    .equ N_PARENT, 4
    .equ N_FIRST, 8
    .equ N_LAST, 12
    .equ N_PREV, 16
    .equ N_NEXT, 20
    .equ N_NAME, 24
    .equ N_NLEN, 28
    .equ N_TEXT, 32
    .equ N_TLEN, 36
    .equ N_ATTR, 40

.macro RECA dst, idx                    // the record's address; uses x17
    mov     w17, #REC
    umaddl  \dst, \idx, w17, x19
    add     \dst, \dst, #HDR
.endm
.macro PUTB reg                         // one byte of answer
    cmp     x20, x21
    b.hs    full
    strb    \reg, [x20], #1
.endm
.macro HANDLE dst, off                  // a block of bytes at the handle numbered at x1 + off; uses x9
    ldrsh   x9, [x1, #\off]
    cmp     x9, #255
    b.hi    bad
    add     x9, x9, #256
    ldr     \dst, [x4, x9, lsl #3]
    cbz     \dst, bad
    ldr     w9, [\dst]
    cmp     w9, #2
    b.ne    bad
    ldr     x9, [\dst, #16]
    cmp     x9, #64
    b.lo    bad
.endm
.macro W s                              // one word of a list
    .byte   2f - 1f
1:  .ascii  "\s"
2:
.endm

begin:
    ldr     w9, [x0]
    cmp     w9, #TREE
    b.ne    9f
    ldr     x9, [x0, #16]
    mov     x10, #0x10000
    cmp     x9, x10
    b.lo    9f
    mov     x10, #0x7fffffff
    cmp     x9, x10
    b.hi    9f
    mov     w10, #2
    str     w10, [x0, #T_NODES]
    str     w9, [x0, #T_BYTES]
    str     wzr, [x0, #T_CUR]
    add     x10, x0, #HDR
    stp     xzr, xzr, [x10]
    stp     xzr, xzr, [x10, #16]
    stp     xzr, xzr, [x10, #32]
    stp     xzr, xzr, [x10, #48]
    stp     xzr, xzr, [x10, #64]
    stp     xzr, xzr, [x10, #80]
    mov     w9, #9
    str     w9, [x10, #(REC + N_KIND)]
    mov     x0, #0
    ret
9:  mov     x0, #-1
    ret

full:
    mov     sp, x28
    mov     x0, #-2
    b       leave
bad:
    mov     sp, x28
    mov     x0, #-1
leave:
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #96
    ret

// ---- room ----
// alloc_node: w0 kind -> w0 its number, x1 its record. Uses x9-x11, x17.
alloc_node:
    ldr     w9, [x19, #T_NODES]
    ldr     w10, [x19, #T_BYTES]
    add     w11, w9, #1
    mov     w17, #REC
    umull   x11, w11, w17
    add     x11, x11, #HDR
    cmp     x11, x10
    b.hi    full
    add     w11, w9, #1
    str     w11, [x19, #T_NODES]
    RECA    x1, w9
    stp     xzr, xzr, [x1]
    stp     xzr, xzr, [x1, #16]
    stp     xzr, xzr, [x1, #32]
    str     w0, [x1, #N_KIND]
    mov     w0, w9
    ret
// alloc_bytes: x0 how many -> x0 their offset. Uses x9-x11, x17.
alloc_bytes:
    ldr     w9, [x19, #T_NODES]
    ldr     w10, [x19, #T_BYTES]
    mov     w17, #REC
    umull   x9, w9, w17
    add     x9, x9, #HDR
    sub     x11, x10, x9
    cmp     x0, x11
    b.hi    full
    sub     x0, x10, x0
    str     w0, [x19, #T_BYTES]
    ret
// store: x0 bytes, x1 how many, w2 how (0 as they are, 1 in small letters, 2 decoded) -> w0 offset, x1 length kept.
// Uses x0-x17 except x13 on the way in... (callers keep nothing in x0-x17).
store:
    stp     x29, x30, [sp, #-16]!
    mov     x12, x0
    mov     x13, x1
    mov     w14, w2
    mov     x0, x1
    bl      alloc_bytes
    add     x15, x19, x0
    cmp     w14, #2
    b.eq    5f
    mov     x16, #0
1:  cmp     x16, x13
    b.hs    3f
    ldrb    w9, [x12, x16]
    cbz     w14, 2f
    sub     w10, w9, #'A'
    cmp     w10, #26
    b.hs    2f
    orr     w9, w9, #32
2:  strb    w9, [x15, x16]
    add     x16, x16, #1
    b       1b
3:  mov     x1, x13
    ldp     x29, x30, [sp], #16
    ret
5:  mov     x16, x0
    mov     x0, x12
    mov     x1, x13
    mov     x2, x15
    bl      decode
    mov     x1, x0
    mov     x0, x16
    ldp     x29, x30, [sp], #16
    ret

// decode: x0 text, x1 how many, x2 where to -> x0 how many written (never more than read). Uses x0-x11.
decode:
    add     x3, x0, x1
    mov     x4, x2
d_loop:
    cmp     x0, x3
    b.hs    d_done
    ldrb    w5, [x0]
    cmp     w5, #'&'
    b.eq    d_amp
d_copy:
    strb    w5, [x4], #1
    add     x0, x0, #1
    b       d_loop
d_amp:
    sub     x6, x3, x0
    cmp     x6, #3
    b.lo    d_copy
    ldrb    w7, [x0, #1]
    cmp     w7, #'#'
    b.eq    d_num
    adr     x8, refs
d_try:
    ldrb    w9, [x8]
    cbz     w9, d_copy
    cmp     x6, x9
    b.lo    d_next
    mov     x10, #1
d_cmp:
    cmp     x10, x9
    b.hs    d_hit
    add     x11, x8, x10
    ldrb    w11, [x11, #1]
    ldrb    w7, [x0, x10]
    cmp     w7, w11
    b.ne    d_next
    add     x10, x10, #1
    b       d_cmp
d_next:
    add     x8, x8, x9
    add     x8, x8, #4
    b       d_try
d_hit:
    add     x8, x8, x9
    ldrb    w10, [x8, #1]
    ldrb    w11, [x8, #2]
    strb    w11, [x4], #1
    cmp     w10, #2
    b.lo    1f
    ldrb    w11, [x8, #3]
    strb    w11, [x4], #1
1:  add     x0, x0, x9
    b       d_loop
d_num:
    add     x8, x0, #2
    mov     w9, #0                      // the number
    mov     w10, #0                     // its digits
    mov     w11, #10
    ldrb    w7, [x8]
    orr     w7, w7, #32
    cmp     w7, #'x'
    b.ne    1f
    mov     w11, #16
    add     x8, x8, #1
1:  cmp     x8, x3
    b.hs    d_copy
    ldrb    w7, [x8]
    cmp     w7, #';'
    b.eq    4f
    sub     w6, w7, #'0'
    cmp     w6, #10
    b.lo    3f
    cmp     w11, #16
    b.ne    d_copy
    orr     w6, w7, #32
    sub     w6, w6, #'a'
    cmp     w6, #6
    b.hs    d_copy
    add     w6, w6, #10
3:  mul     w9, w9, w11
    add     w9, w9, w6
    add     w10, w10, #1
    cmp     w10, #8
    b.hi    d_copy
    add     x8, x8, #1
    b       1b
4:  cbz     w10, d_copy
    cbz     w9, d_copy
    mov     w6, #0xffff
    movk    w6, #0x10, lsl #16
    cmp     w9, w6
    b.hi    d_copy
    add     x0, x8, #1
    cmp     w9, #0x80
    b.hs    5f
    strb    w9, [x4], #1
    b       d_loop
5:  cmp     w9, #0x800
    b.hs    6f
    lsr     w6, w9, #6
    orr     w6, w6, #0xc0
    strb    w6, [x4], #1
    b       8f
6:  cmp     w9, #0x10000
    b.hs    7f
    lsr     w6, w9, #12
    orr     w6, w6, #0xe0
    strb    w6, [x4], #1
    b       9f
7:  lsr     w6, w9, #18
    orr     w6, w6, #0xf0
    strb    w6, [x4], #1
    lsr     w6, w9, #12
    and     w6, w6, #0x3f
    orr     w6, w6, #0x80
    strb    w6, [x4], #1
9:  lsr     w6, w9, #6
    and     w6, w6, #0x3f
    orr     w6, w6, #0x80
    strb    w6, [x4], #1
8:  and     w6, w9, #0x3f
    orr     w6, w6, #0x80
    strb    w6, [x4], #1
    b       d_loop
d_done:
    sub     x0, x4, x2
    ret

// ---- the answer ----
// put_bytes: x0 bytes, x1 how many. Uses x9.
put_bytes:
    sub     x9, x21, x20
    cmp     x1, x9
    b.hi    full
1:  cbz     x1, 2f
    ldrb    w9, [x0], #1
    strb    w9, [x20], #1
    sub     x1, x1, #1
    b       1b
2:  ret
// put_name: x1 a record. put_value: its text.
put_name:
    ldr     w0, [x1, #N_NAME]
    add     x0, x19, x0
    ldr     w1, [x1, #N_NLEN]
    b       put_bytes
put_value:
    ldr     w0, [x1, #N_TEXT]
    add     x0, x19, x0
    ldr     w1, [x1, #N_TLEN]
    b       put_bytes
// put_num: w0 in decimal. Uses x9-x13.
put_num:
    sub     sp, sp, #16
    add     x9, sp, #16
    mov     x10, x9
    mov     w11, #10
1:  udiv    w12, w0, w11
    msub    w13, w12, w11, w0
    add     w13, w13, #'0'
    strb    w13, [x10, #-1]!
    mov     w0, w12
    cbnz    w0, 1b
    sub     x1, x9, x10
    sub     x11, x21, x20
    cmp     x1, x11
    b.hi    full
2:  ldrb    w11, [x10], #1
    strb    w11, [x20], #1
    subs    x1, x1, #1
    b.ne    2b
    add     sp, sp, #16
    ret
// sep: a space, unless the answer is still empty
sep:
    cmp     x20, x29
    b.eq    1f
    mov     w9, #' '
    PUTB    w9
1:  ret
// put_escaped: x0 text, x1 how many, w2 nonzero inside an attribute's quotes. Uses x9-x11.
put_escaped:
    add     x1, x0, x1
pe_loop:
    cmp     x0, x1
    b.hs    pe_done
    ldrb    w9, [x0], #1
    adr     x10, esc_amp
    cmp     w9, #'&'
    b.eq    pe_str
    adr     x10, esc_lt
    cmp     w9, #'<'
    b.eq    pe_str
    adr     x10, esc_gt
    cmp     w9, #'>'
    b.eq    pe_str
    cmp     w9, #'"'
    b.ne    1f
    adr     x10, esc_quot
    cbnz    w2, pe_str
1:  cmp     w9, #0xc2
    b.ne    2f
    cmp     x0, x1
    b.hs    2f
    ldrb    w11, [x0]
    cmp     w11, #0xa0
    b.ne    2f
    add     x0, x0, #1
    adr     x10, esc_nbsp
    b       pe_str
2:  PUTB    w9
    b       pe_loop
pe_str:
    ldrb    w9, [x10], #1
    cbz     w9, pe_loop
    PUTB    w9
    b       pe_str
pe_done:
    ret

// ---- comparing ----
// eq_lower: x0, x1 a kept name; x2, x3 a name in any letters -> w0 1 if the same. Uses x9-x12.
eq_lower:
    cmp     x1, x3
    b.ne    8f
    mov     x9, #0
1:  cmp     x9, x1
    b.hs    7f
    ldrb    w10, [x0, x9]
    ldrb    w11, [x2, x9]
    sub     w12, w11, #'A'
    cmp     w12, #26
    b.hs    2f
    orr     w11, w11, #32
2:  cmp     w10, w11
    b.ne    8f
    add     x9, x9, #1
    b       1b
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret
// eq_bytes: the same, letter for letter. Uses x9-x11.
eq_bytes:
    cmp     x1, x3
    b.ne    8f
    mov     x9, #0
1:  cmp     x9, x1
    b.hs    7f
    ldrb    w10, [x0, x9]
    ldrb    w11, [x2, x9]
    cmp     w10, w11
    b.ne    8f
    add     x9, x9, #1
    b       1b
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret
// has_word: x0, x1 a class value; x2, x3 one word -> w0 1 if it is among the value's words. Uses x9-x14.
has_word:
    cbz     x3, 8f
    add     x1, x0, x1
1:  cmp     x0, x1
    b.hs    8f
    ldrb    w9, [x0]
    cmp     w9, #' '
    b.hi    2f
    add     x0, x0, #1
    b       1b
2:  mov     x10, x0
3:  cmp     x0, x1
    b.hs    4f
    ldrb    w9, [x0]
    cmp     w9, #' '
    b.ls    4f
    add     x0, x0, #1
    b       3b
4:  sub     x11, x0, x10
    cmp     x11, x3
    b.ne    1b
    mov     x12, #0
5:  cmp     x12, x3
    b.hs    7f
    ldrb    w13, [x10, x12]
    ldrb    w14, [x2, x12]
    cmp     w13, w14
    b.ne    1b
    add     x12, x12, #1
    b       5b
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret
// in_list: x0, x1 a kept name; x2 a list of words -> w0 1 if it is there. Uses x9-x12.
in_list:
1:  ldrb    w9, [x2], #1
    cbz     w9, 8f
    cmp     x9, x1
    b.ne    3f
    mov     x10, #0
2:  cmp     x10, x1
    b.hs    7f
    ldrb    w11, [x2, x10]
    ldrb    w12, [x0, x10]
    cmp     w11, w12
    b.ne    3f
    add     x10, x10, #1
    b       2b
3:  add     x2, x2, x9
    b       1b
7:  mov     w0, #1
    ret
8:  mov     w0, #0
    ret
// node_in_list: w0 a node, x2 a list -> w0 1 if its name is there. Uses x1, x9-x12, x17.
node_in_list:
    RECA    x1, w0
    ldr     w0, [x1, #N_NAME]
    add     x0, x19, x0
    ldr     w1, [x1, #N_NLEN]
    b       in_list
// find_attr: w0 an element, x2, x3 a name in any letters -> w0 the attribute (0: none), x1 its record,
// w4 the attribute before it (or the last one, when not found). Uses x5-x7, x9-x12, x17.
find_attr:
    stp     x29, x30, [sp, #-16]!
    RECA    x5, w0
    ldr     w6, [x5, #N_ATTR]
    mov     w4, #0
1:  cbz     w6, 9f
    RECA    x7, w6
    ldr     w0, [x7, #N_NAME]
    add     x0, x19, x0
    ldr     w1, [x7, #N_NLEN]
    bl      eq_lower
    cbnz    w0, 8f
    mov     w4, w6
    ldr     w6, [x7, #N_NEXT]
    b       1b
8:  mov     x1, x7
9:  mov     w0, w6
    ldp     x29, x30, [sp], #16
    ret

// ---- the links ----
// detach: w0 a node, taken out of its parent. Uses x1-x6, x17.
detach:
    RECA    x1, w0
    ldr     w2, [x1, #N_PARENT]
    cbz     w2, 9f
    ldr     w3, [x1, #N_PREV]
    ldr     w4, [x1, #N_NEXT]
    RECA    x5, w2
    cbz     w3, 1f
    RECA    x6, w3
    str     w4, [x6, #N_NEXT]
    b       2f
1:  str     w4, [x5, #N_FIRST]
2:  cbz     w4, 3f
    RECA    x6, w4
    str     w3, [x6, #N_PREV]
    b       4f
3:  str     w3, [x5, #N_LAST]
4:  str     wzr, [x1, #N_PARENT]
    str     wzr, [x1, #N_PREV]
    str     wzr, [x1, #N_NEXT]
9:  ret
// insert: w0 parent, w1 child, w2 the child it goes before (0: last). Uses x0-x7, x17.
insert:
    stp     x29, x30, [sp, #-32]!
    stp     w0, w1, [sp, #16]
    str     w2, [sp, #24]
    mov     w0, w1
    bl      detach
    ldp     w0, w1, [sp, #16]
    ldr     w2, [sp, #24]
    RECA    x3, w0
    RECA    x4, w1
    str     w0, [x4, #N_PARENT]
    cbnz    w2, 5f
    ldr     w5, [x3, #N_LAST]
    str     w5, [x4, #N_PREV]
    str     wzr, [x4, #N_NEXT]
    cbz     w5, 1f
    RECA    x6, w5
    str     w1, [x6, #N_NEXT]
    b       2f
1:  str     w1, [x3, #N_FIRST]
2:  str     w1, [x3, #N_LAST]
    b       9f
5:  RECA    x6, w2
    ldr     w5, [x6, #N_PREV]
    str     w2, [x4, #N_NEXT]
    str     w5, [x4, #N_PREV]
    str     w1, [x6, #N_PREV]
    cbz     w5, 6f
    RECA    x7, w5
    str     w1, [x7, #N_NEXT]
    b       9f
6:  str     w1, [x3, #N_FIRST]
9:  ldp     x29, x30, [sp], #32
    ret
// next_in: w0 a node, w1 the node the walk began at -> w0 the next node in page order under it (0: no more). Uses x2, x3, x17.
next_in:
    RECA    x2, w0
    ldr     w3, [x2, #N_FIRST]
    cbnz    w3, 8f
1:  cmp     w0, w1
    b.eq    7f
    ldr     w3, [x2, #N_NEXT]
    cbnz    w3, 8f
    ldr     w0, [x2, #N_PARENT]
    cbz     w0, 7f
    RECA    x2, w0
    b       1b
7:  mov     w0, #0
    ret
8:  mov     w0, w3
    ret
// clear: w0 a node whose children are all let go. Uses x1-x3, x17.
clear:
    RECA    x1, w0
    ldr     w2, [x1, #N_FIRST]
    str     wzr, [x1, #N_FIRST]
    str     wzr, [x1, #N_LAST]
1:  cbz     w2, 9f
    RECA    x3, w2
    ldr     w2, [x3, #N_NEXT]
    str     wzr, [x3, #N_PARENT]
    str     wzr, [x3, #N_PREV]
    str     wzr, [x3, #N_NEXT]
    b       1b
9:  ret
// check_node: w0 a number from a request -> x1 its record; refused unless it is a node of the tree. Uses x9, x17.
check_node:
    cbz     w0, bad
    ldr     w9, [x19, #T_NODES]
    cmp     w0, w9
    b.hs    bad
    RECA    x1, w0
    ldr     w9, [x1, #N_KIND]
    cmp     w9, #2
    b.eq    bad
    ret
// get_num: the decimal number at x22 (0 if none), then one space passed over. Uses x9, x10.
get_num:
    mov     w0, #0
    mov     w10, #10
1:  cmp     x22, x23
    b.hs    3f
    ldrb    w9, [x22]
    sub     w9, w9, #'0'
    cmp     w9, #10
    b.hs    2f
    madd    w0, w0, w10, w9
    add     x22, x22, #1
    b       1b
2:  ldrb    w9, [x22]
    cmp     w9, #' '
    b.ne    3f
    add     x22, x22, #1
3:  ret

// ---- writing a node out as HTML: w0 the node, w1 nonzero to write the node itself as well as what is inside ----
ser:
    stp     x29, x30, [sp, #-48]!
    stp     x24, x25, [sp, #16]
    stp     x26, x27, [sp, #32]
    mov     w25, w0
    mov     w26, w1
    mov     w24, w0
    cbnz    w26, s_open
    RECA    x1, w24
    ldr     w24, [x1, #N_FIRST]
    cbz     w24, s_done
s_open:
    RECA    x27, w24
    ldr     w9, [x27, #N_KIND]
    cmp     w9, #3
    b.eq    s_text
    cmp     w9, #8
    b.eq    s_comment
    cmp     w9, #1
    b.ne    s_kids
    mov     w9, #'<'
    PUTB    w9
    mov     x1, x27
    bl      put_name
    ldr     w0, [x27, #N_ATTR]
s_attr:
    cbz     w0, s_attr_done
    RECA    x27, w0
    mov     w9, #' '
    PUTB    w9
    mov     x1, x27
    bl      put_name
    mov     w9, #'='
    PUTB    w9
    mov     w9, #'"'
    PUTB    w9
    ldr     w0, [x27, #N_TEXT]
    add     x0, x19, x0
    ldr     w1, [x27, #N_TLEN]
    mov     w2, #1
    bl      put_escaped
    mov     w9, #'"'
    PUTB    w9
    ldr     w0, [x27, #N_NEXT]
    b       s_attr
s_attr_done:
    mov     w9, #'>'
    PUTB    w9
    mov     w0, w24
    adr     x2, voids
    bl      node_in_list
    cbnz    w0, s_after
s_kids:
    RECA    x27, w24
    ldr     w9, [x27, #N_FIRST]
    cbz     w9, s_close
    mov     w24, w9
    b       s_open
s_text:
    ldr     w0, [x27, #N_PARENT]
    cbz     w0, 1f
    adr     x2, raws
    bl      node_in_list
    cbz     w0, 1f
    mov     x1, x27
    bl      put_value
    b       s_after
1:  ldr     w0, [x27, #N_TEXT]
    add     x0, x19, x0
    ldr     w1, [x27, #N_TLEN]
    mov     w2, #0
    bl      put_escaped
    b       s_after
s_comment:
    adr     x0, c_open
    mov     x1, #4
    bl      put_bytes
    mov     x1, x27
    bl      put_value
    adr     x0, c_close
    mov     x1, #3
    bl      put_bytes
    b       s_after
s_close:
    RECA    x27, w24
    ldr     w9, [x27, #N_KIND]
    cmp     w9, #1
    b.ne    s_after
    mov     w9, #'<'
    PUTB    w9
    mov     w9, #'/'
    PUTB    w9
    mov     x1, x27
    bl      put_name
    mov     w9, #'>'
    PUTB    w9
s_after:
    cmp     w24, w25
    b.eq    s_done
    RECA    x27, w24
    ldr     w9, [x27, #N_NEXT]
    cbz     w9, 1f
    mov     w24, w9
    b       s_open
1:  ldr     w24, [x27, #N_PARENT]
    cbz     w24, s_done
    cmp     w24, w25
    b.ne    s_close
    cbnz    w26, s_close
s_done:
    ldp     x24, x25, [sp, #16]
    ldp     x26, x27, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret

// text_content: w0 a node: the text of every text node in it, in order (a comment asked for itself gives its own)
text_content:
    stp     x29, x30, [sp, #-32]!
    stp     x24, x25, [sp, #16]
    mov     w25, w0
    mov     w24, w0
1:  RECA    x1, w24
    ldr     w9, [x1, #N_KIND]
    cmp     w9, #3
    b.eq    2f
    cmp     w24, w25
    b.ne    3f
    cmp     w9, #8
    b.ne    3f
2:  bl      put_value
3:  mov     w0, w24
    mov     w1, w25
    bl      next_in
    mov     w24, w0
    cbnz    w24, 1b
    ldp     x24, x25, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// add_text: x0 text, x1 how many, w2 how kept, w3 kind: a new node, put last under w26
add_text:
    stp     x29, x30, [sp, #-32]!
    str     w3, [sp, #16]
    bl      store
    stp     w0, w1, [sp, #20]
    ldr     w0, [sp, #16]
    bl      alloc_node
    ldp     w9, w10, [sp, #20]
    str     w9, [x1, #N_TEXT]
    str     w10, [x1, #N_TLEN]
    mov     w1, w0
    mov     w0, w26
    mov     w2, #0
    bl      insert
    ldp     x29, x30, [sp], #32
    ret

// name_end: x10 -> the first of: the end (x25), a space, '>', '/', or the byte in w11. Uses x9.
name_end:
1:  cmp     x10, x25
    b.hs    2f
    ldrb    w9, [x10]
    cmp     w9, #' '
    b.ls    2f
    cmp     w9, #'>'
    b.eq    2f
    cmp     w9, #'/'
    b.eq    2f
    cmp     w9, w11
    b.eq    2f
    add     x10, x10, #1
    b       1b
2:  ret

// ---- reading HTML: w0 the node the text's nodes go under, x1 the text, x2 its end ----
// x24 where the reading is, x25 the end, w26 the open element, w27 the node it all goes under.
// On the stack: 48 the element being opened, 52 its last attribute, 56 to 72 for the step in hand.
parse:
    stp     x29, x30, [sp, #-80]!
    stp     x24, x25, [sp, #16]
    stp     x26, x27, [sp, #32]
    mov     w27, w0
    mov     w26, w0
    mov     x24, x1
    mov     x25, x2
p_loop:
    cmp     x24, x25
    b.hs    p_done
    mov     x0, x24                     // text runs to the next '<' that begins a tag
1:  cmp     x0, x25
    b.hs    3f
    ldrb    w9, [x0]
    cmp     w9, #'<'
    b.ne    2f
    add     x10, x0, #1
    cmp     x10, x25
    b.hs    2f
    ldrb    w9, [x10]
    cmp     w9, #'/'
    b.eq    3f
    cmp     w9, #'!'
    b.eq    3f
    cmp     w9, #'?'
    b.eq    3f
    orr     w9, w9, #32
    sub     w9, w9, #'a'
    cmp     w9, #26
    b.lo    3f
2:  add     x0, x0, #1
    b       1b
3:  cmp     x0, x24
    b.eq    4f
    mov     x10, x0
    sub     x1, x0, x24
    mov     x0, x24
    mov     x24, x10
    mov     w2, #2
    mov     w3, #3
    bl      add_text
4:  cmp     x24, x25
    b.hs    p_done
    ldrb    w9, [x24, #1]
    cmp     w9, #'!'
    b.eq    p_bang
    cmp     w9, #'?'
    b.eq    p_skip
    cmp     w9, #'/'
    b.eq    p_end_tag
    b       p_open
p_skip:                                 // to just past the next '>'
    cmp     x24, x25
    b.hs    p_done
    ldrb    w9, [x24], #1
    cmp     w9, #'>'
    b.ne    p_skip
    b       p_loop
p_bang:
    add     x0, x24, #4
    cmp     x0, x25
    b.hi    p_skip
    ldrb    w9, [x24, #2]
    cmp     w9, #'-'
    b.ne    p_skip
    ldrb    w9, [x24, #3]
    cmp     w9, #'-'
    b.ne    p_skip
    mov     x10, x0                     // a comment: to "-->"
1:  add     x11, x10, #3
    cmp     x11, x25
    b.hi    3f
    ldrb    w9, [x10]
    cmp     w9, #'-'
    b.ne    2f
    ldrb    w9, [x10, #1]
    cmp     w9, #'-'
    b.ne    2f
    ldrb    w9, [x10, #2]
    cmp     w9, #'>'
    b.eq    4f
2:  add     x10, x10, #1
    b       1b
3:  mov     x10, x25
    mov     x11, x25
4:  mov     x24, x11
    sub     x1, x10, x0
    mov     w2, #0
    mov     w3, #8
    bl      add_text
    b       p_loop
p_end_tag:
    add     x10, x24, #2
    str     x10, [sp, #48]
    mov     w11, #'>'
    bl      name_end
    mov     x24, x10
    ldr     x0, [sp, #48]
    sub     x10, x10, x0
    str     x10, [sp, #56]
    mov     w13, w26
1:  cmp     w13, w27
    b.eq    p_skip                      // nothing of that name is open: dropped
    cbz     w13, p_skip
    RECA    x14, w13
    ldr     w0, [x14, #N_NAME]
    add     x0, x19, x0
    ldr     w1, [x14, #N_NLEN]
    ldr     x2, [sp, #48]
    ldr     x3, [sp, #56]
    bl      eq_lower
    cbnz    w0, 2f
    ldr     w13, [x14, #N_PARENT]
    b       1b
2:  ldr     w26, [x14, #N_PARENT]
    b       p_skip
p_open:
    add     x10, x24, #1
    mov     w11, #'>'
    bl      name_end
    add     x0, x24, #1
    sub     x1, x10, x0
    mov     x24, x10
    mov     w2, #1
    bl      store
    stp     w0, w1, [sp, #56]
    mov     w0, #1
    bl      alloc_node
    ldp     w9, w10, [sp, #56]
    str     w9, [x1, #N_NAME]
    str     w10, [x1, #N_NLEN]
    str     w0, [sp, #48]
    str     wzr, [sp, #52]
    cmp     w26, w27                    // a second li (and the like) straight inside the first ends the first
    b.eq    3f
    RECA    x14, w26
    ldr     w0, [x14, #N_NAME]
    add     x0, x19, x0
    ldr     w1, [x14, #N_NLEN]
    add     x2, x19, x9
    mov     x3, x10
    bl      eq_bytes
    cbz     w0, 3f
    ldr     w0, [sp, #48]
    adr     x2, selfend
    bl      node_in_list
    cbz     w0, 3f
    RECA    x14, w26
    ldr     w26, [x14, #N_PARENT]
3:  mov     w0, w26
    ldr     w1, [sp, #48]
    mov     w2, #0
    bl      insert
p_attrs:
    cmp     x24, x25
    b.hs    p_done
    ldrb    w9, [x24]
    cmp     w9, #'>'
    b.eq    p_tag_done
    cmp     w9, #' '
    b.ls    1f
    cmp     w9, #'/'
    b.eq    1f
    cmp     w9, #'='
    b.ne    2f
1:  add     x24, x24, #1
    b       p_attrs
2:  mov     x10, x24
    mov     w11, #'='
    bl      name_end
    mov     x0, x24
    sub     x1, x10, x24
    mov     x24, x10
    mov     w2, #1
    bl      store
    stp     w0, w1, [sp, #56]
    mov     w0, #2
    bl      alloc_node
    ldp     w9, w10, [sp, #56]
    str     w9, [x1, #N_NAME]
    str     w10, [x1, #N_NLEN]
    str     w0, [sp, #56]               // the attribute, for its value
    ldr     w9, [sp, #52]
    str     w0, [sp, #52]
    cbnz    w9, 3f
    ldr     w9, [sp, #48]
    RECA    x10, w9
    str     w0, [x10, #N_ATTR]
    b       pa_eq
3:  RECA    x10, w9
    str     w0, [x10, #N_NEXT]
pa_eq:
    cmp     x24, x25
    b.hs    p_done
    ldrb    w9, [x24]
    cmp     w9, #' '
    b.hi    1f
    add     x24, x24, #1
    b       pa_eq
1:  cmp     w9, #'='
    b.ne    p_attrs                     // a name alone
    add     x24, x24, #1
pa_val:
    cmp     x24, x25
    b.hs    p_done
    ldrb    w9, [x24]
    cmp     w9, #' '
    b.hi    1f
    add     x24, x24, #1
    b       pa_val
1:  cmp     w9, #'"'
    b.eq    pa_quoted
    cmp     w9, #39
    b.eq    pa_quoted
    mov     x0, x24                     // bare: to a space or '>'
    mov     x10, x24
2:  cmp     x10, x25
    b.hs    3f
    ldrb    w11, [x10]
    cmp     w11, #' '
    b.ls    3f
    cmp     w11, #'>'
    b.eq    3f
    add     x10, x10, #1
    b       2b
3:  mov     x24, x10
    b       pa_keep
pa_quoted:
    add     x0, x24, #1
    mov     x10, x0
1:  cmp     x10, x25
    b.hs    2f
    ldrb    w11, [x10]
    cmp     w11, w9
    b.eq    3f
    add     x10, x10, #1
    b       1b
2:  mov     x24, x10
    b       pa_keep
3:  add     x24, x10, #1
pa_keep:
    sub     x1, x10, x0
    mov     w2, #2
    bl      store
    ldr     w9, [sp, #56]
    RECA    x10, w9
    str     w0, [x10, #N_TEXT]
    str     w1, [x10, #N_TLEN]
    b       p_attrs
p_tag_done:
    add     x24, x24, #1
    ldr     w0, [sp, #48]
    adr     x2, voids
    bl      node_in_list
    cbnz    w0, p_loop
    ldr     w0, [sp, #48]
    adr     x2, raws
    bl      node_in_list
    mov     w13, #0
    cbnz    w0, p_raw
    ldr     w0, [sp, #48]
    adr     x2, plains
    bl      node_in_list
    mov     w13, #2
    cbnz    w0, p_raw
    ldr     w26, [sp, #48]
    b       p_loop
p_raw:                                  // everything up to this element's own closing tag is its text
    str     w13, [sp, #64]
    ldr     w9, [sp, #48]
    RECA    x14, w9
    ldr     w15, [x14, #N_NAME]
    add     x15, x19, x15
    ldr     w16, [x14, #N_NLEN]
    mov     x13, x24
1:  add     x9, x13, #2
    add     x9, x9, x16
    cmp     x9, x25
    b.hi    3f
    ldrb    w9, [x13]
    cmp     w9, #'<'
    b.ne    2f
    ldrb    w9, [x13, #1]
    cmp     w9, #'/'
    b.ne    2f
    mov     x0, x15
    mov     x1, x16
    add     x2, x13, #2
    mov     x3, x16
    bl      eq_lower
    cbnz    w0, 4f
2:  add     x13, x13, #1
    b       1b
3:  mov     x13, x25
4:  mov     x0, x24
    sub     x1, x13, x24
    mov     x24, x13
    cbz     x1, p_skip
    ldr     w2, [sp, #64]
    mov     w3, #3
    str     w26, [sp, #68]
    ldr     w26, [sp, #48]
    bl      add_text
    ldr     w26, [sp, #68]
    b       p_skip
p_done:
    ldp     x24, x25, [sp, #16]
    ldp     x26, x27, [sp, #32]
    ldp     x29, x30, [sp], #80
    ret

// ---- ask ----
ask:
    stp     x29, x30, [sp, #-96]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x28, sp
    mov     x19, x0
    cbz     x19, bad
    ldr     w9, [x19]
    cmp     w9, #TREE
    b.ne    bad
    ldr     w9, [x19, #T_NODES]
    cmp     w9, #2
    b.lo    bad
    cmp     x2, #2
    b.lt    bad
    HANDLE  x10, 0
    add     x22, x10, #64
    add     x23, x10, x9
    HANDLE  x11, 2
    cmp     x11, x10
    b.eq    bad
    add     x20, x11, #64
    add     x21, x11, x9
    mov     x29, x20
    cmp     x22, x23
    b.hs    bad
    ldrb    w24, [x22], #1
    bl      get_num
    mov     w25, w0
    cmp     w24, #'c'
    b.eq    o_create
    cmp     w24, #'x'
    b.eq    o_text_new
    cmp     w24, #'i'
    b.eq    o_id
    cmp     w24, #'w'
    b.eq    o_write
    cmp     w24, #'S'
    b.eq    o_cur
    cmp     w24, #'C'
    b.eq    o_set_cur
    mov     w0, w25
    bl      check_node
    mov     x26, x1                     // the node's record
    mov     w9, #N_PARENT
    cmp     w24, #'p'
    b.eq    o_field
    mov     w9, #N_FIRST
    cmp     w24, #'f'
    b.eq    o_field
    mov     w9, #N_LAST
    cmp     w24, #'l'
    b.eq    o_field
    mov     w9, #N_NEXT
    cmp     w24, #'N'
    b.eq    o_field
    mov     w9, #N_PREV
    cmp     w24, #'P'
    b.eq    o_field
    mov     w9, #N_KIND
    cmp     w24, #'k'
    b.eq    o_field
    cmp     w24, #'n'
    b.eq    o_name
    cmp     w24, #'g'
    b.eq    o_get
    cmp     w24, #'s'
    b.eq    o_set
    cmp     w24, #'u'
    b.eq    o_unset
    cmp     w24, #'t'
    b.eq    o_textc
    cmp     w24, #'T'
    b.eq    o_text_set
    mov     w1, #0
    cmp     w24, #'h'
    b.eq    o_ser
    mov     w1, #1
    cmp     w24, #'o'
    b.eq    o_ser
    cmp     w24, #'H'
    b.eq    o_inner_set
    cmp     w24, #'a'
    b.eq    o_append
    cmp     w24, #'b'
    b.eq    o_before
    cmp     w24, #'r'
    b.eq    o_remove
    mov     w27, #0
    cmp     w24, #'L'
    b.eq    o_list
    mov     w27, #1
    cmp     w24, #'E'
    b.eq    o_list
    cmp     w24, #'q'
    b.eq    o_query
    b       bad
done:
    sub     x0, x20, x29
    b       leave

o_field:
    ldr     w0, [x26, x9]
    bl      put_num
    b       done
o_name:
    ldr     w9, [x26, #N_KIND]
    cmp     w9, #1
    b.ne    1f
    mov     x1, x26
    bl      put_name
    b       done
1:  adr     x0, n_text
    mov     x1, #5
    cmp     w9, #3
    b.eq    2f
    adr     x0, n_comment
    mov     x1, #8
    cmp     w9, #8
    b.eq    2f
    adr     x0, n_document
    mov     x1, #9
2:  bl      put_bytes
    b       done
o_get:
    mov     w0, w25
    mov     x2, x22
    sub     x3, x23, x22
    bl      find_attr
    cbnz    w0, 1f
    mov     w9, #'0'
    PUTB    w9
    b       done
1:  mov     w9, #'1'
    PUTB    w9
    bl      put_value
    b       done
o_set:
    ldr     w9, [x26, #N_KIND]
    cmp     w9, #1
    b.ne    bad
    mov     x10, x22                    // the name ends at the first space
1:  cmp     x10, x23
    b.hs    2f
    ldrb    w9, [x10]
    cmp     w9, #' '
    b.eq    2f
    add     x10, x10, #1
    b       1b
2:  cmp     x10, x22
    b.eq    bad
    mov     x27, x10
    mov     w0, w25
    mov     x2, x22
    sub     x3, x27, x22
    bl      find_attr
    cbnz    w0, 4f
    mov     w24, w4                     // the last attribute there is
    mov     x0, x22
    sub     x1, x27, x22
    mov     w2, #1
    bl      store
    stp     w0, w1, [sp, #-16]!
    mov     w0, #2
    bl      alloc_node
    ldp     w9, w10, [sp], #16
    str     w9, [x1, #N_NAME]
    str     w10, [x1, #N_NLEN]
    cbnz    w24, 3f
    str     w0, [x26, #N_ATTR]
    b       4f
3:  RECA    x10, w24
    str     w0, [x10, #N_NEXT]
4:  mov     x26, x1                     // the attribute's record
    add     x0, x27, #1
    cmp     x0, x23
    b.ls    5f
    mov     x0, x23
5:  sub     x1, x23, x0
    mov     w2, #0
    bl      store
    str     w0, [x26, #N_TEXT]
    str     w1, [x26, #N_TLEN]
    b       done
o_unset:
    mov     w0, w25
    mov     x2, x22
    sub     x3, x23, x22
    bl      find_attr
    cbz     w0, done
    ldr     w9, [x1, #N_NEXT]
    cbnz    w4, 1f
    str     w9, [x26, #N_ATTR]
    b       done
1:  RECA    x10, w4
    str     w9, [x10, #N_NEXT]
    b       done
o_textc:
    mov     w0, w25
    bl      text_content
    b       done
o_text_set:
    ldr     w9, [x26, #N_KIND]
    cmp     w9, #1
    b.eq    1f
    cmp     w9, #9
    b.eq    done
    mov     x0, x22
    sub     x1, x23, x22
    mov     w2, #0
    bl      store
    str     w0, [x26, #N_TEXT]
    str     w1, [x26, #N_TLEN]
    b       done
1:  mov     w0, w25
    bl      clear
    cmp     x22, x23
    b.hs    done
    mov     x0, x22
    sub     x1, x23, x22
    mov     w2, #0
    mov     w3, #3
    mov     w26, w25
    bl      add_text
    b       done
o_ser:
    mov     w0, w25
    bl      ser
    b       done
o_inner_set:
    ldr     w9, [x26, #N_KIND]
    cmp     w9, #3
    b.eq    bad
    cmp     w9, #8
    b.eq    bad
    mov     w0, w25
    bl      clear
    mov     w0, w25
    mov     x1, x22
    mov     x2, x23
    bl      parse
    b       done
o_create:
    cmp     x22, x23
    b.hs    bad
    mov     x0, x22
    sub     x1, x23, x22
    mov     w2, #1
    bl      store
    stp     w0, w1, [sp, #-16]!
    mov     w0, #1
    bl      alloc_node
    ldp     w9, w10, [sp], #16
    str     w9, [x1, #N_NAME]
    str     w10, [x1, #N_NLEN]
    bl      put_num
    b       done
o_text_new:
    mov     x0, x22
    sub     x1, x23, x22
    mov     w2, #0
    bl      store
    stp     w0, w1, [sp, #-16]!
    mov     w0, #3
    bl      alloc_node
    ldp     w9, w10, [sp], #16
    str     w9, [x1, #N_TEXT]
    str     w10, [x1, #N_TLEN]
    bl      put_num
    b       done
o_id:
    mov     w24, #1
1:  mov     w0, w24
    mov     w1, #1
    bl      next_in
    mov     w24, w0
    cbz     w24, 3f
    RECA    x1, w24
    ldr     w9, [x1, #N_KIND]
    cmp     w9, #1
    b.ne    1b
    mov     w0, w24
    adr     x2, w_id
    mov     x3, #2
    bl      find_attr
    cbz     w0, 1b
    ldr     w0, [x1, #N_TEXT]
    add     x0, x19, x0
    ldr     w1, [x1, #N_TLEN]
    mov     x2, x22
    sub     x3, x23, x22
    bl      eq_bytes
    cbz     w0, 1b
3:  mov     w0, w24
    bl      put_num
    b       done
o_write:
    ldr     w24, [x19, #T_CUR]
    cbz     w24, done
    ldr     w9, [x19, #T_NODES]
    cmp     w24, w9
    b.hs    done
    RECA    x1, w24
    ldr     w25, [x1, #N_PARENT]
    cbz     w25, done
    mov     w0, #1
    bl      alloc_node                  // a holder to read into
    mov     w26, w0
    mov     x1, x22
    mov     x2, x23
    bl      parse
1:  RECA    x1, w26
    ldr     w1, [x1, #N_FIRST]
    cbz     w1, done
    mov     w0, w25
    mov     w2, w24
    bl      insert
    b       1b
o_cur:
    ldr     w0, [x19, #T_CUR]
    bl      put_num
    b       done
o_set_cur:
    str     w25, [x19, #T_CUR]
    b       done
o_append:
    bl      get_num
    mov     w27, w0
    mov     w24, #0
    b       o_put
o_before:
    bl      get_num
    mov     w27, w0
    bl      get_num
    mov     w24, w0
o_put:                                  // w25 parent, w27 child, w24 the child it goes before (0: last)
    ldr     w9, [x26, #N_KIND]
    cmp     w9, #3
    b.eq    bad
    cmp     w9, #8
    b.eq    bad
    mov     w0, w27
    bl      check_node
    ldr     w9, [x1, #N_KIND]
    cmp     w9, #9
    b.eq    bad
    cbz     w24, 1f
    cmp     w24, w27
    b.eq    done
    mov     w0, w24
    bl      check_node
    ldr     w9, [x1, #N_PARENT]
    cmp     w9, w25
    b.ne    bad
1:  mov     w9, w25                     // the child may not be the parent, nor stand above it
2:  cmp     w9, w27
    b.eq    bad
    RECA    x1, w9
    ldr     w9, [x1, #N_PARENT]
    cbnz    w9, 2b
    mov     w0, w25
    mov     w1, w27
    mov     w2, w24
    bl      insert
    b       done
o_remove:
    mov     w0, w25
    bl      detach
    b       done
o_list:
    ldr     w24, [x26, #N_FIRST]
1:  cbz     w24, done
    RECA    x26, w24
    cbz     w27, 2f
    ldr     w9, [x26, #N_KIND]
    cmp     w9, #1
    b.ne    3f
2:  bl      sep
    mov     w0, w24
    bl      put_num
3:  ldr     w24, [x26, #N_NEXT]
    b       1b
o_query:
    cmp     x22, x23
    b.hs    bad
    ldrb    w27, [x22]                  // its first byte says which kind
    mov     w24, w25
q_next:
    mov     w0, w24
    mov     w1, w25
    bl      next_in
    mov     w24, w0
    cbz     w24, done
    RECA    x26, w24
    ldr     w9, [x26, #N_KIND]
    cmp     w9, #1
    b.ne    q_next
    cmp     w27, #'*'
    b.eq    q_yes
    cmp     w27, #'#'
    b.eq    q_id
    cmp     w27, #'.'
    b.eq    q_class
    ldr     w0, [x26, #N_NAME]
    add     x0, x19, x0
    ldr     w1, [x26, #N_NLEN]
    mov     x2, x22
    sub     x3, x23, x22
    bl      eq_lower
    cbz     w0, q_next
q_yes:
    bl      sep
    mov     w0, w24
    bl      put_num
    b       q_next
q_id:
    mov     w0, w24
    adr     x2, w_id
    mov     x3, #2
    bl      find_attr
    cbz     w0, q_next
    ldr     w0, [x1, #N_TEXT]
    add     x0, x19, x0
    ldr     w1, [x1, #N_TLEN]
    add     x2, x22, #1
    sub     x3, x23, x2
    bl      eq_bytes
    cbz     w0, q_next
    b       q_yes
q_class:
    mov     w0, w24
    adr     x2, w_class
    mov     x3, #5
    bl      find_attr
    cbz     w0, q_next
    ldr     w0, [x1, #N_TEXT]
    add     x0, x19, x0
    ldr     w1, [x1, #N_TLEN]
    add     x2, x22, #1
    sub     x3, x23, x2
    bl      has_word
    cbz     w0, q_next
    b       q_yes

// ---- words ----
refs:                                   // length, the reference, how many bytes it stands for, the bytes (two places)
    .byte   5
    .ascii  "&amp;"
    .byte   1, '&', 0
    .byte   4
    .ascii  "&lt;"
    .byte   1, '<', 0
    .byte   4
    .ascii  "&gt;"
    .byte   1, '>', 0
    .byte   6
    .ascii  "&quot;"
    .byte   1, '"', 0
    .byte   6
    .ascii  "&apos;"
    .byte   1, 39, 0
    .byte   6
    .ascii  "&nbsp;"
    .byte   2, 0xc2, 0xa0
    .byte   0
esc_amp:    .asciz "&amp;"
esc_lt:     .asciz "&lt;"
esc_gt:     .asciz "&gt;"
esc_quot:   .asciz "&quot;"
esc_nbsp:   .asciz "&nbsp;"
c_open:     .ascii "<!--"
c_close:    .ascii "-->"
n_text:     .ascii "#text"
n_comment:  .ascii "#comment"
n_document: .ascii "#document"
w_id:       .ascii "id"
w_class:    .ascii "class"
voids:
    W area
    W base
    W br
    W col
    W embed
    W hr
    W img
    W input
    W link
    W meta
    W param
    W source
    W track
    W wbr
    .byte 0
raws:
    W script
    W style
    .byte 0
plains:
    W title
    W textarea
    .byte 0
selfend:
    W li
    W p
    W option
    W tr
    W td
    W th
    W dt
    W dd
    .byte 0
    .balign 4
