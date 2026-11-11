// url, written by hand (ARM64). The meaning is url/intent.md; the recorded checks are the judge.
// Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// An address taken apart is five parts of 24 bytes each (pointer, length, present): scheme, authority, path, query, fragment.
    .text
    .global resolve
    .global part
    .global port
    .equ SCHEME, 0
    .equ AUTH, 24
    .equ PATH, 48
    .equ QUERY, 72
    .equ FRAG, 96
    .equ LONGEST, 2000

// text_at: x1 numbers, x2 how many, x4 table, w5 which number, x6 the output block (or 0) -> x0 the block or 0. Uses x7, x8.
text_at:
    mov     x0, #0
    cmp     x2, x5
    b.le    9f
    ldrsh   x7, [x1, x5, lsl #1]
    cmp     x7, #0
    b.lt    9f
    cmp     x7, #255
    b.gt    9f
    add     x7, x7, #256
    ldr     x7, [x4, x7, lsl #3]
    cbz     x7, 9f
    ldr     w8, [x7]
    cmp     w8, #2
    b.ne    9f
    ldr     x8, [x7, #16]
    cmp     x8, #64
    b.lo    9f
    cmp     x8, #(64 + LONGEST)
    b.hi    9f
    cmp     x7, x6
    b.eq    9f
    mov     x0, x7
9:  ret

// split: x0 bytes, x1 how many, x2 where the five parts go. Uses x3-x9.
split:
    mov     x3, #0
1:  str     xzr, [x2, x3, lsl #3]
    add     x3, x3, #1
    cmp     x3, #15
    b.lo    1b
    mov     x3, #0                      // at
    cbz     x1, s_auth
    ldrb    w4, [x0]
    orr     w5, w4, #32
    sub     w5, w5, #'a'
    cmp     w5, #26
    b.hs    s_auth                      // a scheme starts with a letter
    mov     x5, #1
2:  cmp     x5, x1
    b.hs    s_auth                      // ran out before a colon: no scheme
    ldrb    w4, [x0, x5]
    orr     w6, w4, #32
    sub     w6, w6, #'a'
    cmp     w6, #26
    b.lo    3f
    sub     w6, w4, #'0'
    cmp     w6, #10
    b.lo    3f
    cmp     w4, #'+'
    b.eq    3f
    cmp     w4, #'-'
    b.eq    3f
    cmp     w4, #'.'
    b.ne    4f
3:  add     x5, x5, #1
    b       2b
4:  cmp     w4, #':'
    b.ne    s_auth
    str     x0, [x2, #SCHEME]
    str     x5, [x2, #SCHEME + 8]
    mov     x6, #1
    str     x6, [x2, #SCHEME + 16]
    add     x3, x5, #1
s_auth:
    add     x5, x3, #1
    cmp     x5, x1
    b.hs    s_path
    ldrb    w4, [x0, x3]
    cmp     w4, #'/'
    b.ne    s_path
    ldrb    w4, [x0, x5]
    cmp     w4, #'/'
    b.ne    s_path
    add     x3, x3, #2
    mov     x5, x3
5:  cmp     x5, x1
    b.hs    6f
    ldrb    w4, [x0, x5]
    cmp     w4, #'/'
    b.eq    6f
    cmp     w4, #'?'
    b.eq    6f
    cmp     w4, #'#'
    b.eq    6f
    add     x5, x5, #1
    b       5b
6:  add     x6, x0, x3
    str     x6, [x2, #AUTH]
    sub     x6, x5, x3
    str     x6, [x2, #AUTH + 8]
    mov     x6, #1
    str     x6, [x2, #AUTH + 16]
    mov     x3, x5
s_path:
    mov     x5, x3
7:  cmp     x5, x1
    b.hs    8f
    ldrb    w4, [x0, x5]
    cmp     w4, #'?'
    b.eq    8f
    cmp     w4, #'#'
    b.eq    8f
    add     x5, x5, #1
    b       7b
8:  add     x6, x0, x3
    str     x6, [x2, #PATH]
    sub     x6, x5, x3
    str     x6, [x2, #PATH + 8]
    mov     x6, #1
    str     x6, [x2, #PATH + 16]
    mov     x3, x5
    cmp     x3, x1
    b.hs    s_done
    ldrb    w4, [x0, x3]
    cmp     w4, #'?'
    b.ne    s_frag
    add     x3, x3, #1
    mov     x5, x3
1:  cmp     x5, x1
    b.hs    2f
    ldrb    w4, [x0, x5]
    cmp     w4, #'#'
    b.eq    2f
    add     x5, x5, #1
    b       1b
2:  add     x6, x0, x3
    str     x6, [x2, #QUERY]
    sub     x6, x5, x3
    str     x6, [x2, #QUERY + 8]
    mov     x6, #1
    str     x6, [x2, #QUERY + 16]
    mov     x3, x5
s_frag:
    cmp     x3, x1
    b.hs    s_done
    ldrb    w4, [x0, x3]
    cmp     w4, #'#'
    b.ne    s_done
    add     x6, x0, x3
    add     x6, x6, #1
    str     x6, [x2, #FRAG]
    sub     x6, x1, x3
    sub     x6, x6, #1
    str     x6, [x2, #FRAG + 8]
    mov     x6, #1
    str     x6, [x2, #FRAG + 16]
s_done:
    ret

// undot: x0 path bytes (changed in place), x1 how many -> x0 the new length. Uses x2-x9. (RFC 3986 section 5.2.4)
undot:
    mov     x2, #0                      // in
    mov     x3, #0                      // out
u_top:
    cmp     x2, x1
    b.hs    u_end
    sub     x4, x1, x2                  // how much is left
    add     x5, x0, x2
    ldrb    w6, [x5]
    mov     w7, #0
    mov     w8, #0
    mov     w9, #0
    cmp     x4, #2
    b.lo    1f
    ldrb    w7, [x5, #1]
    cmp     x4, #3
    b.lo    1f
    ldrb    w8, [x5, #2]
    cmp     x4, #4
    b.lo    1f
    ldrb    w9, [x5, #3]
1:  cmp     w6, #'.'
    b.ne    u_slash
    // starts with a dot
    cmp     x4, #1
    b.eq    u_all                       // "." alone
    cmp     w7, #'/'
    b.ne    2f
    add     x2, x2, #2                  // "./"
    b       u_top
2:  cmp     w7, #'.'
    b.ne    u_copy
    cmp     x4, #2
    b.eq    u_all                       // ".." alone
    cmp     w8, #'/'
    b.ne    u_copy
    add     x2, x2, #3                  // "../"
    b       u_top
u_all:
    mov     x2, x1
    b       u_top
u_slash:
    cmp     w6, #'/'
    b.ne    u_copy
    cmp     x4, #2
    b.lo    u_copy
    cmp     w7, #'.'
    b.ne    u_copy
    cmp     x4, #2
    b.ne    3f
    add     x2, x2, #1                  // "/." at the end becomes "/"
    mov     w6, #'/'
    strb    w6, [x0, x2]
    b       u_top
3:  cmp     w8, #'/'
    b.ne    4f
    add     x2, x2, #2                  // "/./"
    b       u_top
4:  cmp     w8, #'.'
    b.ne    u_copy
    cmp     x4, #3
    b.ne    5f
    add     x2, x2, #2                  // "/.." at the end: up one, and a "/" remains
    mov     w6, #'/'
    strb    w6, [x0, x2]
    b       u_up
5:  cmp     w9, #'/'
    b.ne    u_copy
    add     x2, x2, #3                  // "/../": up one
u_up:
    cbz     x3, u_top
    sub     x5, x3, #1
    ldrb    w6, [x0, x5]
    cmp     w6, #'/'
    b.eq    6f
    mov     x3, x5
    b       u_up
6:  mov     x3, x5
    b       u_top
u_copy:                                 // an ordinary step: its leading "/" if it has one, then up to the next "/"
    ldrb    w6, [x0, x2]
    cmp     w6, #'/'
    b.ne    7f
    strb    w6, [x0, x3]
    add     x3, x3, #1
    add     x2, x2, #1
7:  cmp     x2, x1
    b.hs    u_top
    ldrb    w6, [x0, x2]
    cmp     w6, #'/'
    b.eq    u_top
    strb    w6, [x0, x3]
    add     x3, x3, #1
    add     x2, x2, #1
    b       7b
u_end:
    mov     x0, x3
    ret

// --- resolve ---------------------------------------------------------------------------------------------------------------------
// frame: 0 saved registers (64), 64 the base's parts (120), 184 the reference's parts (120), 304 the path being built (4016)
    .equ BASE, 64
    .equ REF, 184
    .equ BUILT, 304
    .equ FRAME, 4320
resolve:
    sub     sp, sp, #4096               // the frame, in two steps: one instruction cannot name 4320
    sub     sp, sp, #(FRAME - 4096)
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     x19, x0                     // the output block
    mov     x6, x0
    mov     w5, #0
    bl      text_at
    cbz     x0, r_fail
    mov     x20, x0                     // base block
    mov     w5, #1
    bl      text_at
    cbz     x0, r_fail
    mov     x21, x0                     // reference block
    ldr     x7, [x19, #16]
    cmp     x7, #64
    b.lo    r_fail
    add     x0, x20, #64
    ldr     x1, [x20, #16]
    sub     x1, x1, #64
    add     x2, sp, #BASE
    bl      split
    add     x0, x21, #64
    ldr     x1, [x21, #16]
    sub     x1, x1, #64
    add     x2, sp, #REF
    bl      split
    ldr     x7, [sp, #BASE + SCHEME + 16]
    cbz     x7, r_fail                  // the base must have a scheme
    add     x21, sp, #BUILT             // the path
    mov     x20, #0                     // its length
    add     x22, sp, #BASE + SCHEME     // which scheme, authority and query the answer takes
    add     x23, sp, #BASE + AUTH
    add     x24, sp, #REF + QUERY
    ldr     x7, [sp, #REF + SCHEME + 16]
    cbz     x7, 1f
    add     x22, sp, #REF + SCHEME      // a reference with its own scheme stands alone
    add     x23, sp, #REF + AUTH
    b       r_take_ref
1:  ldr     x7, [sp, #REF + AUTH + 16]
    cbz     x7, 2f
    add     x23, sp, #REF + AUTH
    b       r_take_ref
2:  ldr     x7, [sp, #REF + PATH + 8]
    cbnz    x7, 3f
    ldr     x0, [sp, #BASE + PATH]      // an empty path: the base's, and the base's query unless the reference has one
    ldr     x1, [sp, #BASE + PATH + 8]
    bl      r_append
    ldr     x7, [sp, #REF + QUERY + 16]
    cbnz    x7, r_built
    add     x24, sp, #BASE + QUERY
    b       r_built
3:  ldr     x7, [sp, #REF + PATH]
    ldrb    w7, [x7]
    cmp     w7, #'/'
    b.eq    r_take_ref
    ldr     x7, [sp, #BASE + AUTH + 16] // a relative path: the base's path up to its last "/", then the reference's
    ldr     x8, [sp, #BASE + PATH + 8]
    cbz     x7, 4f
    cbnz    x8, 4f
    mov     w7, #'/'
    strb    w7, [x21]
    mov     x20, #1
    b       r_take_ref
4:  ldr     x0, [sp, #BASE + PATH]
5:  cbz     x8, 6f
    sub     x9, x8, #1
    ldrb    w7, [x0, x9]
    cmp     w7, #'/'
    b.eq    6f
    mov     x8, x9
    b       5b
6:  mov     x1, x8
    bl      r_append
r_take_ref:
    ldr     x0, [sp, #REF + PATH]
    ldr     x1, [sp, #REF + PATH + 8]
    bl      r_append
    mov     x0, x21
    mov     x1, x20
    bl      undot
    mov     x20, x0
r_built:
    ldr     x7, [x22, #8]               // how long the answer is
    add     x7, x7, #1
    ldr     x8, [x23, #16]
    cbz     x8, 1f
    ldr     x8, [x23, #8]
    add     x7, x7, x8
    add     x7, x7, #2
1:  add     x7, x7, x20
    ldr     x8, [x24, #16]
    cbz     x8, 2f
    ldr     x8, [x24, #8]
    add     x7, x7, x8
    add     x7, x7, #1
2:  ldr     x8, [sp, #REF + FRAG + 16]
    cbz     x8, 3f
    ldr     x8, [sp, #REF + FRAG + 8]
    add     x7, x7, x8
    add     x7, x7, #1
3:  ldr     x8, [x19, #16]
    sub     x8, x8, #64
    cmp     x8, x7
    b.lo    r_fail
    add     x10, x19, #64               // write it out
    mov     x11, #0
    ldr     x0, [x22]
    ldr     x1, [x22, #8]
    mov     x2, #0
4:  cmp     x2, x1                      // the scheme, in small letters
    b.hs    5f
    ldrb    w7, [x0, x2]
    sub     w8, w7, #'A'
    cmp     w8, #26
    b.hs    41f
    add     w7, w7, #32
41: strb    w7, [x10, x11]
    add     x11, x11, #1
    add     x2, x2, #1
    b       4b
5:  mov     w7, #':'
    strb    w7, [x10, x11]
    add     x11, x11, #1
    ldr     x7, [x23, #16]
    cbz     x7, 9f
    mov     w7, #'/'
    strb    w7, [x10, x11]
    add     x11, x11, #1
    strb    w7, [x10, x11]
    add     x11, x11, #1
    ldr     x0, [x23]
    ldr     x1, [x23, #8]
    mov     x3, #0                      // where the site starts: after the last "@"
    mov     x2, #0
6:  cmp     x2, x1
    b.hs    7f
    ldrb    w7, [x0, x2]
    add     x2, x2, #1
    cmp     w7, #'@'
    csel    x3, x2, x3, eq
    b       6b
7:  mov     x2, #0
8:  cmp     x2, x1
    b.hs    9f
    ldrb    w7, [x0, x2]
    cmp     x2, x3
    b.lo    81f                         // anything before the "@" is left as it is
    sub     w8, w7, #'A'
    cmp     w8, #26
    b.hs    81f
    add     w7, w7, #32
81: strb    w7, [x10, x11]
    add     x11, x11, #1
    add     x2, x2, #1
    b       8b
9:  mov     x0, x21
    mov     x1, x20
    bl      r_copy
    ldr     x7, [x24, #16]
    cbz     x7, 1f
    mov     w7, #'?'
    strb    w7, [x10, x11]
    add     x11, x11, #1
    ldr     x0, [x24]
    ldr     x1, [x24, #8]
    bl      r_copy
1:  ldr     x7, [sp, #REF + FRAG + 16]
    cbz     x7, 2f
    mov     w7, #'#'
    strb    w7, [x10, x11]
    add     x11, x11, #1
    ldr     x0, [sp, #REF + FRAG]
    ldr     x1, [sp, #REF + FRAG + 8]
    bl      r_copy
2:  mov     x0, x11
    b       r_out
r_fail:
    mov     x0, #-1
r_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    add     sp, sp, #4096
    add     sp, sp, #(FRAME - 4096)
    ret
// r_append: x0 bytes, x1 how many, onto the path (x21, length x20). Uses x7, x8.
r_append:
    mov     x7, #0
1:  cmp     x7, x1
    b.hs    2f
    ldrb    w8, [x0, x7]
    strb    w8, [x21, x20]
    add     x20, x20, #1
    add     x7, x7, #1
    b       1b
2:  ret
// r_copy: x0 bytes, x1 how many, onto the output (x10, position x11). Uses x7, x8.
r_copy:
    mov     x7, #0
1:  cmp     x7, x1
    b.hs    2f
    ldrb    w8, [x0, x7]
    strb    w8, [x10, x11]
    add     x11, x11, #1
    add     x7, x7, #1
    b       1b
2:  ret

// site: x0 authority bytes, x1 how many -> x0 site bytes, x1 how many, x2 port bytes (0 if none), x3 how many. Uses x4-x7.
site:
    mov     x4, #0                      // from: after the last "@"
    mov     x5, #0
1:  cmp     x5, x1
    b.hs    2f
    ldrb    w6, [x0, x5]
    add     x5, x5, #1
    cmp     w6, #'@'
    csel    x4, x5, x4, eq
    b       1b
2:  mov     x5, x4                      // end
    cmp     x4, x1
    b.hs    6f
    ldrb    w6, [x0, x4]
    cmp     w6, #'['
    b.ne    4f
3:  cmp     x5, x1                      // an address in square brackets keeps them
    b.hs    6f
    ldrb    w6, [x0, x5]
    add     x5, x5, #1
    cmp     w6, #']'
    b.ne    3b
    b       6f
4:  cmp     x5, x1
    b.hs    6f
    ldrb    w6, [x0, x5]
    cmp     w6, #':'
    b.eq    6f
    add     x5, x5, #1
    b       4b
6:  mov     x2, #0
    mov     x3, #0
    cmp     x5, x1
    b.hs    7f
    ldrb    w6, [x0, x5]
    cmp     w6, #':'
    b.ne    7f
    add     x2, x0, x5
    add     x2, x2, #1
    sub     x3, x1, x5
    sub     x3, x3, #1
7:  add     x0, x0, x4
    sub     x1, x5, x4
    ret

// --- part ------------------------------------------------------------------------------------------------------------------------
    .equ PFRAME, 160
part:
    sub     sp, sp, #PFRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    mov     x19, x0
    mov     x6, x0
    mov     w5, #0
    bl      text_at
    cbz     x0, p_fail
    ldr     x7, [x19, #16]
    cmp     x7, #64
    b.lo    p_fail
    mov     x20, #-1                    // which part
    cmp     x2, #2
    b.lt    1f
    ldrsh   x20, [x1, #2]
1:  ldr     x1, [x0, #16]
    sub     x1, x1, #64
    add     x0, x0, #64
    add     x2, sp, #32
    bl      split
    add     x10, x19, #64
    mov     x11, #0
    ldr     x12, [x19, #16]
    sub     x12, x12, #64               // room
    cmp     x20, #5
    b.ne    p_plain
    ldr     x1, [sp, #32 + PATH + 8]    // what to ask the server for: the path ("/" if empty), then "?" and the query
    cmp     x1, #0
    csinc   x7, x1, xzr, ne
    ldr     x8, [sp, #32 + QUERY + 16]
    cbz     x8, 2f
    ldr     x8, [sp, #32 + QUERY + 8]
    add     x7, x7, x8
    add     x7, x7, #1
2:  cmp     x12, x7
    b.lo    p_fail
    cbnz    x1, 3f
    mov     w7, #'/'
    strb    w7, [x10]
    mov     x11, #1
3:  ldr     x0, [sp, #32 + PATH]
    bl      r_copy
    ldr     x8, [sp, #32 + QUERY + 16]
    cbz     x8, p_done
    mov     w7, #'?'
    strb    w7, [x10, x11]
    add     x11, x11, #1
    ldr     x0, [sp, #32 + QUERY]
    ldr     x1, [sp, #32 + QUERY + 8]
    bl      r_copy
    b       p_done
p_plain:
    cmp     x20, #0
    b.lt    p_fail
    cmp     x20, #4
    b.gt    p_fail
    mov     x7, #24
    mul     x7, x20, x7
    add     x7, x7, #32
    add     x7, sp, x7                  // the part asked for
    ldr     x8, [x7, #16]
    cbz     x8, p_fail                  // absent
    ldr     x0, [x7]
    ldr     x1, [x7, #8]
    cmp     x20, #1
    b.ne    4f
    bl      site                        // the site inside the authority
4:  cmp     x12, x1
    b.lo    p_fail
    bl      r_copy
p_done:
    mov     x0, x11
    b       p_out
p_fail:
    mov     x0, #-1
p_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    add     sp, sp, #PFRAME
    ret

// --- port ------------------------------------------------------------------------------------------------------------------------
port:
    sub     sp, sp, #PFRAME
    stp     x29, x30, [sp]
    mov     x6, #0
    mov     w5, #0
    bl      text_at
    cbz     x0, o_fail
    ldr     x1, [x0, #16]
    sub     x1, x1, #64
    add     x0, x0, #64
    add     x2, sp, #32
    bl      split
    ldr     x7, [sp, #32 + AUTH + 16]
    cbz     x7, o_fail
    ldr     x0, [sp, #32 + AUTH]
    ldr     x1, [sp, #32 + AUTH + 8]
    bl      site
    cbz     x2, o_usual
    cbz     x3, o_usual                 // a ":" with nothing after it: the usual port
    mov     x0, #0
    mov     x4, #0
    mov     x8, #65535
1:  cmp     x4, x3
    b.hs    2f
    ldrb    w5, [x2, x4]
    sub     w5, w5, #'0'
    cmp     w5, #10
    b.hs    o_fail
    cmp     x0, x8
    b.hi    o_fail
    mov     x6, #10
    mul     x0, x0, x6
    add     x0, x0, x5
    add     x4, x4, #1
    b       1b
2:  cmp     x0, x8
    b.hi    o_fail
    b       o_out
o_usual:
    ldr     x0, [sp, #32 + SCHEME]
    ldr     x1, [sp, #32 + SCHEME + 8]
    cmp     x1, #4
    b.lo    o_fail
    cmp     x1, #5
    b.hi    o_fail
    ldrb    w5, [x0]                    // "http" in either case, then "s" for the longer one
    orr     w5, w5, #32
    cmp     w5, #'h'
    b.ne    o_fail
    ldrb    w5, [x0, #1]
    orr     w5, w5, #32
    cmp     w5, #'t'
    b.ne    o_fail
    ldrb    w5, [x0, #2]
    orr     w5, w5, #32
    cmp     w5, #'t'
    b.ne    o_fail
    ldrb    w5, [x0, #3]
    orr     w5, w5, #32
    cmp     w5, #'p'
    b.ne    o_fail
    cmp     x1, #4
    b.ne    3f
    mov     x0, #80
    b       o_out
3:  ldrb    w5, [x0, #4]
    orr     w5, w5, #32
    cmp     w5, #'s'
    b.ne    o_fail
    mov     x0, #443
    b       o_out
o_fail:
    mov     x0, #-1
o_out:
    ldp     x29, x30, [sp]
    add     sp, sp, #PFRAME
    ret
