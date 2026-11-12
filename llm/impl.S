// llm, written by hand (ARM64): the wire format of a language model's API (Anthropic Messages, streamed). The meaning is
// llm/intent.md; the recorded checks are the judge. Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Calls nothing.
    .text
    .global request
    .global text
    .global stopped
// bytes_at: the plain block at the handle in number x5, not empty -> x0 its bytes, x6 how many (x0 = 0 if not usable). Uses x7.
bytes_at:
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
    ldr     w6, [x7]
    cmp     w6, #2
    b.ne    9f
    ldr     x6, [x7, #16]
    subs    x6, x6, #64
    b.ls    9f
    add     x0, x7, #64
9:  ret
// PUT: the fixed words between two labels go to the request being written at x28
    .macro  PUT from, to
    adr     x9, \from
    mov     x10, #(\to - \from)
70: ldrb    w11, [x9], #1
    strb    w11, [x28], #1
    subs    x10, x10, #1
    b.ne    70b
    .endm
// COPY: x10 bytes at x9 go to x28
    .macro  COPY
71: ldrb    w11, [x9], #1
    strb    w11, [x28], #1
    subs    x10, x10, #1
    b.ne    71b
    .endm
// digits: how many decimal digits x9 has -> x10. Uses x11, x12.
digits:
    mov     x10, #1
    mov     x11, #10
1:  cmp     x9, x11
    b.lo    2f
    add     x10, x10, #1
    mov     x12, #10
    mul     x11, x11, x12
    b       1b
2:  ret
// number: x9 in decimal to x28. Uses x10-x14.
number:
    mov     x13, x30
    bl      digits
    add     x28, x28, x10
    mov     x11, x28
    mov     x12, #10
1:  udiv    x14, x9, x12
    msub    x9, x14, x12, x9
    add     w9, w9, #'0'
    strb    w9, [x11, #-1]!
    mov     x9, x14
    subs    x10, x10, #1
    b.ne    1b
    ret     x13

request:
    stp     x29, x30, [sp, #-96]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x25, x0
    mov     x27, x3
    cmp     x2, #3
    b.lt    q_bad
    mov     x5, #0
    bl      bytes_at
    cbz     x0, q_bad
    mov     x19, x0                     // the key
    mov     x22, x6
    mov     x5, #1
    bl      bytes_at
    cbz     x0, q_bad
    mov     x20, x0                     // the model's name
    mov     x23, x6
    mov     x5, #2
    bl      bytes_at
    cbz     x0, q_bad
    mov     x21, x0                     // the prompt
    mov     x24, x6
    cmp     x22, #300
    b.hi    q_bad
    mov     x9, #0
1:  ldrb    w10, [x19, x9]              // the key: one line of ordinary characters, or nothing is written
    sub     w10, w10, #33
    cmp     w10, #93
    b.hi    q_bad
    add     x9, x9, #1
    cmp     x9, x22
    b.lo    1b
    cmp     x23, #100
    b.hi    q_bad
    mov     x9, #0
2:  ldrb    w10, [x20, x9]              // the model's name: letters, digits, . _ : -
    orr     w11, w10, #0x20
    sub     w11, w11, #'a'
    cmp     w11, #25
    b.ls    3f
    sub     w11, w10, #'0'
    cmp     w11, #10                    // digits, and ':' which follows them
    b.ls    3f
    cmp     w10, #'.'
    b.eq    3f
    cmp     w10, #'_'
    b.eq    3f
    cmp     w10, #'-'
    b.ne    q_bad
3:  add     x9, x9, #1
    cmp     x9, x23
    b.lo    2b
    sub     x9, x27, #1
    mov     x10, #63999
    cmp     x9, x10
    b.hi    q_bad
    mov     x26, #0                     // how long the prompt is once written safely
    mov     x9, #0
4:  ldrb    w10, [x21, x9]
    mov     x11, #2
    cmp     w10, #'"'
    b.eq    5f
    cmp     w10, #'\\'
    b.eq    5f
    cmp     w10, #10
    b.eq    5f
    cmp     w10, #13
    b.eq    5f
    cmp     w10, #9
    b.eq    5f
    mov     x11, #6
    cmp     w10, #32
    b.lo    5f
    mov     x11, #1
5:  add     x26, x26, x11
    add     x9, x9, #1
    cmp     x9, x24
    b.lo    4b
    mov     x9, x27
    bl      digits
    add     x26, x26, x10
    add     x26, x26, x23
    add     x26, x26, #((b_1 - b_0) + (b_2 - b_1) + (b_3 - b_2) + (b_4 - b_3))    // the body's length
    mov     x9, x26
    bl      digits
    add     x10, x10, x26
    add     x10, x10, x22
    add     x10, x10, #((h_1 - h_0) + (h_2 - h_1) + (h_3 - h_2))                  // the whole request's
    ldr     x9, [x25, #16]
    sub     x9, x9, #64
    cmp     x10, x9
    b.hi    q_bad
    mov     x29, x10                    // (x29 is saved above and free here)
    add     x28, x25, #64
    PUT     h_0, h_1
    mov     x9, x19
    mov     x10, x22
    COPY
    PUT     h_1, h_2
    mov     x9, x26
    bl      number
    PUT     h_2, h_3
    PUT     b_0, b_1
    mov     x9, x20
    mov     x10, x23
    COPY
    PUT     b_1, b_2
    mov     x9, x27
    bl      number
    PUT     b_2, b_3
    mov     x9, #0
6:  ldrb    w10, [x21, x9]              // the prompt, as a JSON string
    mov     w11, #'\\'
    cmp     w10, #'"'
    b.eq    7f
    cmp     w10, #'\\'
    b.eq    7f
    mov     w12, #'n'
    cmp     w10, #10
    b.eq    8f
    mov     w12, #'r'
    cmp     w10, #13
    b.eq    8f
    mov     w12, #'t'
    cmp     w10, #9
    b.eq    8f
    cmp     w10, #32
    b.hs    9f
    strb    w11, [x28], #1              // any other control byte: \u00XX
    mov     w12, #'u'
    strb    w12, [x28], #1
    mov     w12, #'0'
    strb    w12, [x28], #1
    strb    w12, [x28], #1
    lsr     w12, w10, #4
    add     w12, w12, #'0'
    strb    w12, [x28], #1
    and     w12, w10, #15
    add     w13, w12, #'0'
    add     w14, w12, #('a' - 10)
    cmp     w12, #10
    csel    w12, w13, w14, lo
    strb    w12, [x28], #1
    b       10f
7:  strb    w11, [x28], #1
    b       9f
8:  strb    w11, [x28], #1
    mov     w10, w12
9:  strb    w10, [x28], #1
10: add     x9, x9, #1
    cmp     x9, x24
    b.lo    6b
    PUT     b_3, b_4
    mov     x0, x29
    b       q_out
q_bad:
    mov     x0, #-1
q_out:
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #96
    ret
h_0: .ascii "POST /v1/messages HTTP/1.1\r\nHost: api.anthropic.com\r\nContent-Type: application/json\r\nX-Api-Key: "
h_1: .ascii "\r\nAnthropic-Version: 2023-06-01\r\nConnection: close\r\nContent-Length: "
h_2: .ascii "\r\n\r\n"
h_3:
b_0: .ascii "{\"model\":\""
b_1: .ascii "\",\"max_tokens\":"
b_2: .ascii ",\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\""
b_3: .ascii "\"}]}"
b_4:
p_delta: .ascii "\"type\":\"text_delta\""
p_delta_end:
p_text: .ascii "\"text\":\""
p_text_end:
p_stop: .ascii "\"type\":\"message_stop\""
p_stop_end:
p_error: .ascii "\"type\":\"error\""
p_error_end:
    .balign 4

// find: the first place at or after x8 where the x3 bytes at x2 appear in the stream (x19, x20 long), stopping before x9
// -> x0 the place, or -1. Uses x10-x14.
find:
    add     x10, x8, x3
1:  cmp     x10, x9
    b.hi    4f
    sub     x11, x10, x3
    mov     x12, #0
2:  add     x13, x11, x12
    ldrb    w13, [x19, x13]
    ldrb    w14, [x2, x12]
    cmp     w13, w14
    b.ne    3f
    add     x12, x12, #1
    cmp     x12, x3
    b.lo    2b
    mov     x0, x11
    ret
3:  add     x10, x10, #1
    b       1b
4:  mov     x0, #-1
    ret
// hex4: the four hex digits at x23 in the stream (which must lie before x20) -> w0 their value, or -1. Uses x10-x12.
hex4:
    add     x10, x23, #4
    cmp     x10, x20
    b.hi    3f
    mov     w0, #0
    mov     x10, #0
1:  add     x11, x23, x10
    ldrb    w11, [x19, x11]
    sub     w12, w11, #'0'
    cmp     w12, #9
    b.ls    2f
    orr     w11, w11, #0x20
    sub     w12, w11, #'a'
    cmp     w12, #5
    b.hi    3f
    add     w12, w12, #10
2:  orr     w0, w12, w0, lsl #4
    add     x10, x10, #1
    cmp     x10, #4
    b.lo    1b
    ret
3:  mov     w0, #-1
    ret

    .macro  ENTER2
    stp     x29, x30, [sp, #-96]!
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x25, x0
    cmp     x2, #1
    b.lt    80f
    mov     x5, #0
    bl      bytes_at
80: mov     x19, x0                     // (0 if there were no numbers: x0 is then the block, so test the count again)
    mov     x20, x6
    cmp     x2, #1
    csel    x19, xzr, x19, lt
    .endm
    .macro  LEAVE2
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #96
    ret
    .endm
// OUT: one byte (w0) of the answer goes to the block, if there is room; else the entry answers -1
    .macro  OUT
    cmp     x28, x27
    b.hs    t_bad
    strb    w0, [x28], #1
    .endm
text:
    ENTER2
    cbz     x19, t_bad
    ldr     x27, [x25, #16]
    cmp     x27, #64
    b.lo    t_bad
    add     x27, x25, x27               // the block's end
    add     x28, x25, #64               // where the words go
    mov     x21, #0                     // where we are in the stream
t_event:
    mov     x8, x21
    mov     x9, x20
    adr     x2, p_delta
    mov     x3, #(p_delta_end - p_delta)
    bl      find
    tbnz    x0, #63, t_done
    add     x21, x0, #(p_delta_end - p_delta)
    mov     x9, x21                     // the line this event is on ends at x9
1:  cmp     x9, x20
    b.hs    2f
    ldrb    w10, [x19, x9]
    cmp     w10, #10
    b.eq    2f
    add     x9, x9, #1
    b       1b
2:  mov     x8, x21
    adr     x2, p_text
    mov     x3, #(p_text_end - p_text)
    bl      find
    tbnz    x0, #63, 3f
    add     x23, x0, #(p_text_end - p_text)
    mov     x22, x28                    // this event's words start here; they are dropped if it turns out cut short
    b       t_char
3:  cmp     x9, x20                     // no text on this line: if the line is whole, on to the next event; else wait for more
    b.hs    t_done
    b       t_event
t_char:
    cmp     x23, x20
    b.hs    t_cut
    ldrb    w0, [x19, x23]
    add     x23, x23, #1
    cmp     w0, #'"'
    b.eq    t_closed
    cmp     w0, #'\\'
    b.eq    t_escape
    OUT
    b       t_char
t_closed:
    mov     x21, x23
    b       t_event
t_escape:
    cmp     x23, x20
    b.hs    t_cut
    ldrb    w10, [x19, x23]
    add     x23, x23, #1
    mov     w0, w10
    cmp     w10, #'"'
    b.eq    4f
    cmp     w10, #'\\'
    b.eq    4f
    cmp     w10, #'/'
    b.eq    4f
    mov     w0, #8
    cmp     w10, #'b'
    b.eq    4f
    mov     w0, #12
    cmp     w10, #'f'
    b.eq    4f
    mov     w0, #10
    cmp     w10, #'n'
    b.eq    4f
    mov     w0, #13
    cmp     w10, #'r'
    b.eq    4f
    mov     w0, #9
    cmp     w10, #'t'
    b.eq    4f
    cmp     w10, #'u'
    b.ne    t_cut
    bl      hex4
    tbnz    w0, #31, t_cut
    add     x23, x23, #4
    mov     w24, w0
    mov     w11, #0xd800
    sub     w10, w24, w11           // the first half of a pair? then the second must follow
    cmp     w10, #0x3ff
    b.hi    5f
    add     x10, x23, #2
    cmp     x10, x20
    b.hi    t_cut
    ldrb    w10, [x19, x23]
    cmp     w10, #'\\'
    b.ne    t_cut
    add     x10, x23, #1
    ldrb    w10, [x19, x10]
    cmp     w10, #'u'
    b.ne    t_cut
    add     x23, x23, #2
    bl      hex4
    tbnz    w0, #31, t_cut
    add     x23, x23, #4
    mov     w11, #0xdc00
    sub     w10, w0, w11
    cmp     w10, #0x3ff
    b.hi    t_cut
    mov     w11, #0xd800
    sub     w24, w24, w11
    add     w24, w10, w24, lsl #10
    add     w24, w24, #0x10000
    b       6f
5:  mov     w11, #0xdc00
    sub     w10, w24, w11               // a second half on its own is malformed
    cmp     w10, #0x3ff
    b.ls    t_cut
6:  cmp     w24, #0x80                  // as UTF-8
    b.hs    7f
    mov     w0, w24
    b       4f
7:  cmp     w24, #0x800
    b.hs    8f
    lsr     w0, w24, #6
    orr     w0, w0, #0xc0
    OUT
    b       11f
8:  cmp     w24, #0x10000
    b.hs    9f
    lsr     w0, w24, #12
    orr     w0, w0, #0xe0
    OUT
    b       10f
9:  lsr     w0, w24, #18
    orr     w0, w0, #0xf0
    OUT
    ubfx    w0, w24, #12, #6
    orr     w0, w0, #0x80
    OUT
10: ubfx    w0, w24, #6, #6
    orr     w0, w0, #0x80
    OUT
11: and     w0, w24, #0x3f
    orr     w0, w0, #0x80
4:  OUT
    b       t_char
t_cut:
    mov     x28, x22                    // nothing of the unfinished event is kept
t_done:
    sub     x0, x28, x25
    sub     x0, x0, #64
    b       t_out
t_bad:
    mov     x0, #-1
t_out:
    LEAVE2

stopped:
    ENTER2
    cbz     x19, s_bad
    mov     x8, #0
    mov     x9, x20
    adr     x2, p_error
    mov     x3, #(p_error_end - p_error)
    bl      find
    mov     x21, #2
    tbz     x0, #63, 1f
    mov     x8, #0
    adr     x2, p_stop
    mov     x3, #(p_stop_end - p_stop)
    bl      find
    mov     x21, #1
    tbz     x0, #63, 1f
    mov     x21, #0
1:  mov     x0, x21
    b       s_out
s_bad:
    mov     x0, #-1
s_out:
    LEAVE2
