// http, written by hand (ARM64). The meaning is http/intent.md; the recorded checks are the judge.
// Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// While a reply is open: x19 its bytes, x20 how many, x21 where the headers start, x22 where the body starts, w23 the status code.
    .text
    .global status
    .global header
    .global body
    .global packed
    .global request

// first_block: the block at the handle in the first number, or 0. x1 numbers, x2 how many, x4 table -> x0. Uses x5.
first_block:
    mov     x0, #0
    cmp     x2, #1
    b.lt    1f
    ldrsh   x5, [x1]
    cmp     x5, #0
    b.lt    1f
    cmp     x5, #255
    b.gt    1f
    add     x5, x5, #256
    ldr     x0, [x4, x5, lsl #3]
1:  ret

// open_reply: x0 block (or 0) -> w0 1 if it is a reply this piece reads, and x19-x23 set. Uses x5-x9.
open_reply:
    cbz     x0, o_no
    ldr     w5, [x0]
    cmp     w5, #2
    b.ne    o_no
    ldr     x5, [x0, #16]
    cmp     x5, #(64 + 12)
    b.lo    o_no
    add     x19, x0, #64
    sub     x20, x5, #64
    adr     x6, t_http                  // "HTTP/1."
    mov     x7, #0
1:  ldrb    w8, [x19, x7]
    ldrb    w9, [x6, x7]
    cmp     w8, w9
    b.ne    o_no
    add     x7, x7, #1
    cmp     x7, #7
    b.lo    1b
    ldrb    w8, [x19, #7]
    sub     w8, w8, #'0'
    cmp     w8, #1
    b.hi    o_no
    ldrb    w8, [x19, #8]
    cmp     w8, #' '
    b.ne    o_no
    ldrb    w5, [x19, #9]               // three digits, the first not zero
    sub     w5, w5, #'0'
    cbz     w5, o_no
    cmp     w5, #9
    b.hi    o_no
    ldrb    w6, [x19, #10]
    sub     w6, w6, #'0'
    cmp     w6, #9
    b.hi    o_no
    ldrb    w7, [x19, #11]
    sub     w7, w7, #'0'
    cmp     w7, #9
    b.hi    o_no
    mov     w8, #100
    mul     w23, w5, w8
    mov     w8, #10
    madd    w23, w6, w8, w23
    add     w23, w23, w7
    mov     x5, #12                     // to the end of the status line
2:  cmp     x5, x20
    b.hs    o_no
    ldrb    w6, [x19, x5]
    cmp     w6, #10
    b.eq    3f
    add     x5, x5, #1
    b       2b
3:  add     x21, x5, #1
    mov     x5, x21
4:  cmp     x5, x20                     // an empty line ends the headers
    b.hs    o_no
    ldrb    w6, [x19, x5]
    cmp     w6, #10
    b.ne    5f
    add     x22, x5, #1
    b       o_yes
5:  cmp     w6, #13
    b.ne    6f
    add     x7, x5, #1
    cmp     x7, x20
    b.hs    6f
    ldrb    w8, [x19, x7]
    cmp     w8, #10
    b.ne    6f
    add     x22, x5, #2
    b       o_yes
6:  cmp     x5, x20
    b.hs    7f
    ldrb    w6, [x19, x5]
    cmp     w6, #10
    b.eq    7f
    add     x5, x5, #1
    b       6b
7:  add     x5, x5, #1
    b       4b
o_yes:
    mov     w0, #1
    ret
o_no:
    mov     w0, #0
    ret

// find: a header's value. x0 its name in small letters ending with 0, or 0 to use x1 codes (16-bit), x2 how many.
// -> w0 1 if found, x10 where the value starts, x11 how long. Uses x5-x9, x12.
find:
    mov     x5, x21
f_line:
    cmp     x5, x22
    b.hs    f_no
    mov     x6, x5                      // the end of this line
1:  cmp     x6, x22
    b.hs    2f
    ldrb    w7, [x19, x6]
    cmp     w7, #10
    b.eq    2f
    add     x6, x6, #1
    b       1b
2:  mov     x7, #0
    cbz     x0, f_codes
3:  ldrb    w8, [x0, x7]
    cbz     w8, f_colon
    add     x9, x5, x7
    cmp     x9, x6
    b.hs    f_next
    ldrb    w12, [x19, x9]
    sub     w9, w12, #'A'
    cmp     w9, #26
    b.hs    4f
    add     w12, w12, #32
4:  cmp     w12, w8
    b.ne    f_next
    add     x7, x7, #1
    b       3b
f_codes:
    cmp     x2, #0
    b.le    f_next
5:  cmp     x7, x2
    b.ge    f_colon
    add     x9, x5, x7
    cmp     x9, x6
    b.hs    f_next
    ldrb    w12, [x19, x9]
    sub     w9, w12, #'A'
    cmp     w9, #26
    b.hs    6f
    add     w12, w12, #32
6:  ldrsh   w8, [x1, x7, lsl #1]
    sub     w9, w8, #'A'
    cmp     w9, #26
    b.hs    7f
    add     w8, w8, #32
7:  cmp     w12, w8
    b.ne    f_next
    add     x7, x7, #1
    b       5b
f_colon:
    add     x9, x5, x7
    cmp     x9, x6
    b.hs    f_next
    ldrb    w12, [x19, x9]
    cmp     w12, #':'
    b.ne    f_next
    add     x10, x9, #1                 // spaces off both ends of the value
    mov     x11, x6
8:  cmp     x10, x11
    b.hs    9f
    ldrb    w12, [x19, x10]
    cmp     w12, #' '
    b.eq    81f
    cmp     w12, #9
    b.ne    9f
81: add     x10, x10, #1
    b       8b
9:  cmp     x11, x10
    b.ls    92f
    sub     x9, x11, #1
    ldrb    w12, [x19, x9]
    cmp     w12, #' '
    b.eq    91f
    cmp     w12, #9
    b.eq    91f
    cmp     w12, #13
    b.ne    92f
91: mov     x11, x9
    b       9b
92: sub     x11, x11, x10
    mov     w0, #1
    ret
f_next:
    add     x5, x6, #1
    b       f_line
f_no:
    mov     w0, #0
    ret

// has: does the value (x10, x11) contain the word at x0 (small letters, ends with 0), in any case? -> w0. Uses x5-x9, x12.
has:
    mov     x5, #0                      // the word's length
1:  ldrb    w6, [x0, x5]
    cbz     w6, 2f
    add     x5, x5, #1
    b       1b
2:  mov     x6, #0                      // i
3:  add     x7, x6, x5
    cmp     x7, x11
    b.hi    h_no
    mov     x7, #0                      // k
4:  cmp     x7, x5
    b.hs    h_yes
    add     x8, x10, x6
    add     x8, x8, x7
    ldrb    w9, [x19, x8]
    sub     w12, w9, #'A'
    cmp     w12, #26
    b.hs    5f
    add     w9, w9, #32
5:  ldrb    w12, [x0, x7]
    cmp     w9, w12
    b.ne    6f
    add     x7, x7, #1
    b       4b
6:  add     x6, x6, #1
    b       3b
h_yes:
    mov     w0, #1
    ret
h_no:
    mov     w0, #0
    ret

// every entry keeps x19-x24 and the return address here
    .macro  enter
    stp     x29, x30, [sp, #-64]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    .endm
    .macro  leave
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret
    .endm

status:
    enter
    bl      first_block
    bl      open_reply
    cbz     w0, 1f
    mov     w0, w23
    b       2f
1:  mov     x0, #-1
2:  leave

packed:
    enter
    bl      first_block
    bl      open_reply
    cbz     w0, 1f
    adr     x0, t_content_encoding
    bl      find
    cbz     w0, 2f
    adr     x0, t_gzip
    bl      has
    b       2f
1:  mov     x0, #-1
    b       3f
2:  and     x0, x0, #1
3:  leave

header:
    enter
    mov     x24, x0                     // the output block
    bl      first_block
    cmp     x0, x24
    b.eq    1f
    bl      open_reply
    cbz     w0, 1f
    ldr     x5, [x24, #16]
    cmp     x5, #64
    b.lo    1f
    mov     x0, #0                      // the name is in the numbers after the handle
    add     x1, x1, #2
    sub     x2, x2, #1
    bl      find
    cbz     w0, 1f
    ldr     x5, [x24, #16]
    sub     x5, x5, #64
    cmp     x11, x5
    b.hi    1f
    add     x6, x24, #64
    mov     x7, #0
2:  cmp     x7, x11
    b.hs    3f
    add     x8, x10, x7
    ldrb    w9, [x19, x8]
    strb    w9, [x6, x7]
    add     x7, x7, #1
    b       2b
3:  mov     x0, x11
    b       4f
1:  mov     x0, #-1
4:  leave

// body: x24 output, x13 output bytes, x14 room, x15 made, x16 i
body:
    enter
    mov     x24, x0
    bl      first_block
    cmp     x0, x24
    b.eq    b_fail
    bl      open_reply
    cbz     w0, b_fail
    ldr     x5, [x24, #16]
    cmp     x5, #64
    b.lo    b_fail
    add     x13, x24, #64
    sub     x14, x5, #64
    mov     x15, #0
    mov     x16, x22
    adr     x0, t_transfer_encoding
    bl      find
    cbz     w0, b_plain
    adr     x0, t_chunked
    bl      has
    cbz     w0, b_plain
b_chunk:                                // a size in hexadecimal, a line end, that many bytes, a line end; size 0 ends it
    mov     x5, #0                      // size
    mov     w6, #0                      // digits seen
1:  cmp     x16, x20
    b.hs    3f
    ldrb    w7, [x19, x16]
    sub     w8, w7, #'0'
    cmp     w8, #10
    b.lo    2f
    orr     w8, w7, #32
    sub     w8, w8, #'a'
    cmp     w8, #6
    b.hs    3f
    add     w8, w8, #10
    sub     w9, w7, #'A'                // only letters: "`" to "f" with bit 5 forced must have been a letter
    cmp     w9, #6
    b.lo    2f
    sub     w9, w7, #'a'
    cmp     w9, #6
    b.hs    3f
2:  lsl     x5, x5, #4
    add     x5, x5, x8
    add     w6, w6, #1
    add     x16, x16, #1
    mov     x9, #(1 << 30)
    cmp     x5, x9
    b.hi    b_fail
    b       1b
3:  cbz     w6, b_fail
4:  cmp     x16, x20                    // the rest of the size line
    b.hs    b_fail
    ldrb    w7, [x19, x16]
    add     x16, x16, #1
    cmp     w7, #10
    b.ne    4b
    cbz     x5, b_made
    add     x7, x16, x5
    cmp     x7, x20
    b.hi    b_fail
    add     x7, x15, x5
    cmp     x7, x14
    b.hi    b_fail
5:  cbz     x5, 6f
    ldrb    w7, [x19, x16]
    strb    w7, [x13, x15]
    add     x16, x16, #1
    add     x15, x15, #1
    sub     x5, x5, #1
    b       5b
6:  cmp     x16, x20
    b.hs    b_fail
    ldrb    w7, [x19, x16]
    cmp     w7, #13
    b.ne    7f
    add     x16, x16, #1
    cmp     x16, x20
    b.hs    b_fail
    ldrb    w7, [x19, x16]
7:  cmp     w7, #10
    b.ne    b_fail
    add     x16, x16, #1
    b       b_chunk
b_plain:
    sub     x24, x20, x16               // what is there to take (x24 is free now: the output is in x13)
    adr     x0, t_content_length
    bl      find
    cbz     w0, 3f
    cbz     x11, b_fail
    mov     x5, #0
    mov     x6, #0
1:  cmp     x6, x11
    b.hs    2f
    add     x7, x10, x6
    ldrb    w7, [x19, x7]
    sub     w7, w7, #'0'
    cmp     w7, #9
    b.hi    b_fail
    mov     x8, #10
    mul     x5, x5, x8
    add     x5, x5, x7
    mov     x9, #(1 << 30)
    cmp     x5, x9
    b.hi    b_fail
    add     x6, x6, #1
    b       1b
2:  cmp     x5, x24
    b.hi    b_fail
    mov     x24, x5
3:  cmp     x24, x14
    b.hi    b_fail
    mov     x5, #0
4:  cmp     x5, x24
    b.hs    5f
    add     x7, x16, x5
    ldrb    w7, [x19, x7]
    strb    w7, [x13, x5]
    add     x5, x5, #1
    b       4b
5:  mov     x0, x24
    b       b_out
b_made:
    mov     x0, x15
    b       b_out
b_fail:
    mov     x0, #-1
b_out:
    leave

// --- request ---------------------------------------------------------------------------------------------------------------------
// frame: 0 saved registers (96), 96 numbers, 112 three lengths, 144 a table of our own (4096), 4240 three blocks of 2168
// x24 output block, x25 the three blocks, x26 output bytes, x27 written, x28 room, x21 the real table
    .equ RFRAME, 10752
    .equ OWN, 144
    .equ EACH, 2168
request:
    sub     sp, sp, #8192
    sub     sp, sp, #(RFRAME - 8192)
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x24, x0
    mov     x21, x4
    bl      first_block                 // the address
    cbz     x0, q_fail
    ldr     w5, [x0]
    cmp     w5, #2
    b.ne    q_fail
    cmp     x0, x24
    b.eq    q_fail
    ldr     x5, [x24, #16]
    cmp     x5, #64
    b.lo    q_fail
    add     x22, sp, #OWN               // a table of our own: the real sockets, the address at handle 1
    mov     x5, #0
1:  ldr     x6, [x21, x5, lsl #3]
    str     x6, [x22, x5, lsl #3]
    add     x5, x5, #1
    cmp     x5, #256
    b.lo    1b
    str     x0, [x22, #(257 * 8)]
    add     x25, sp, #4096
    add     x25, x25, #(OWN)
    mov     x19, #0                     // which of the three: the site, what to ask for, the scheme
2:  mov     x5, #EACH
    mul     x5, x19, x5
    add     x20, x25, x5                // this block
    mov     x5, #0
3:  str     xzr, [x20, x5, lsl #3]
    add     x5, x5, #1
    cmp     x5, #8
    b.lo    3b
    mov     w5, #2
    str     w5, [x20]
    mov     x5, #(64 + 2100)
    str     x5, [x20, #16]
    mov     w5, #1
    strh    w5, [sp, #96]
    adr     x6, t_which
    ldrb    w5, [x6, x19]
    strh    w5, [sp, #98]
    mov     x0, x20
    add     x1, sp, #96
    mov     x2, #2
    mov     x3, #0
    mov     x4, x22
    ldr     x5, [x21, #(32 * 8)]        // url part
    blr     x5
    cmp     x0, #1
    b.lt    q_fail
    add     x5, sp, #112
    str     x0, [x5, x19, lsl #3]
    add     x19, x19, #1
    cmp     x19, #3
    b.lo    2b
    mov     w5, #1
    strh    w5, [sp, #96]
    mov     x0, #0
    add     x1, sp, #96
    mov     x2, #1
    mov     x3, #0
    mov     x4, x22
    ldr     x5, [x21, #(33 * 8)]        // url port
    blr     x5
    cmp     x0, #1
    b.lt    q_fail
    mov     x23, x0                     // the port
    add     x26, x24, #64
    mov     x27, #0
    ldr     x28, [x24, #16]
    sub     x28, x28, #64
    adr     x0, t_get
    bl      say
    add     x0, x25, #(EACH + 64)       // what to ask for, as it is; a space or control character is refused, not sent
    ldr     x1, [sp, #120]
    mov     w2, #0
    bl      say_bytes
    adr     x0, t_host
    bl      say
    add     x0, x25, #64                // the site, in small letters
    ldr     x1, [sp, #112]
    mov     w2, #1
    bl      say_bytes
    ldr     x5, [sp, #128]              // the port only when it is not the usual one for the scheme
    mov     x6, #80
    mov     x7, #443
    cmp     x5, #5
    csel    x6, x7, x6, eq
    cmp     x23, x6
    b.eq    6f
    mov     x5, x23                     // its digits, last first, onto the numbers area
    mov     x6, #0
    add     x7, sp, #96
4:  mov     x8, #10
    udiv    x9, x5, x8
    msub    x10, x9, x8, x5
    add     w10, w10, #'0'
    strb    w10, [x7, x6]
    add     x6, x6, #1
    mov     x5, x9
    cbnz    x5, 4b
    add     x8, x27, #1
    add     x8, x8, x6
    cmp     x8, x28
    b.hi    q_fail
    mov     w8, #':'
    strb    w8, [x26, x27]
    add     x27, x27, #1
5:  sub     x6, x6, #1
    ldrb    w8, [x7, x6]
    strb    w8, [x26, x27]
    add     x27, x27, #1
    cbnz    x6, 5b
6:  adr     x0, t_rest
    bl      say
    mov     x0, x27
    b       q_out
q_fail:
    mov     x0, #-1
q_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #8192
    add     sp, sp, #(RFRAME - 8192)
    ret
// say: the text at x0 (ends with 0) onto the output; no room is a failure. Uses x5.
say:
1:  ldrb    w5, [x0], #1
    cbz     w5, 2f
    cmp     x27, x28
    b.hs    q_fail
    strb    w5, [x26, x27]
    add     x27, x27, #1
    b       1b
2:  ret
// say_bytes: x1 bytes at x0 onto the output, in small letters if w2; anything at or below a space, or 127, is a failure. Uses x5, x6, x7.
say_bytes:
    mov     x5, #0
1:  cmp     x5, x1
    b.hs    3f
    cmp     x27, x28
    b.hs    q_fail
    ldrb    w6, [x0, x5]
    cmp     w6, #33
    b.lo    q_fail
    cmp     w6, #127
    b.eq    q_fail
    cbz     w2, 2f
    sub     w7, w6, #'A'
    cmp     w7, #26
    b.hs    2f
    add     w6, w6, #32
2:  strb    w6, [x26, x27]
    add     x27, x27, #1
    add     x5, x5, #1
    b       1b
3:  ret

t_http:              .ascii "HTTP/1."
t_which:             .byte 1, 5, 0
t_content_encoding:  .asciz "content-encoding"
t_gzip:              .asciz "gzip"
t_transfer_encoding: .asciz "transfer-encoding"
t_chunked:           .asciz "chunked"
t_content_length:    .asciz "content-length"
t_get:               .asciz "GET "
t_host:              .asciz " HTTP/1.1\r\nHost: "
t_rest:              .asciz "\r\nUser-Agent: Trough/0.1\r\nAccept: text/html,*/*;q=0.8\r\nAccept-Encoding: gzip\r\nConnection: close\r\n\r\n"
    .balign 4
