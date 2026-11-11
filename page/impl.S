// page, written by hand (ARM64): lays out a page of marked-up text and asks the font piece to draw it. The meaning is
// page/intent.md; the recorded checks are the judge. Entries: x0 surface, x1 numbers (16-bit): the page's handle, the font's handle,
// the text size, how far it is scrolled, and optionally a glyph cache and its scratch surface; x2 how many; x4 call table.
// Through render: x19 the layout (in the frame), x20 the page's bytes, x21 how many, x22 where we are; x23-x28 serve a tag.
    .text
    .global check
    .global render
    // the layout
    .equ S, 0
    .equ TABLE, 8
    .equ FONT, 16
    .equ BASE, 20
    .equ SCROLL, 24
    .equ WIDTH, 28
    .equ HEIGHT, 32
    .equ CACHE, 36
    .equ SCRATCH, 40
    .equ SIZE, 44
    .equ LINK, 48
    .equ Y, 56
    .equ PENDING, 64
    .equ LINE_N, 72
    .equ LINE_W, 80
    .equ LINKS, 88
    .equ WORD_N, 92
    .equ SPACE, 96
    .equ LINK_FROM, 104
    .equ WORD, 264
    .equ LINE, 432
    .equ QBUF, 1240
    .equ SP3, 2056
    .equ FRAME, 2160
check:
    ldr     w9, [x0]
    cmp     w9, #1
    b.ne    9f
    ldr     w10, [x0, #4]
    ldr     w11, [x0, #8]
    ldr     w12, [x0, #12]
    ldr     x13, [x0, #16]
    sub     w14, w10, #1
    cmp     w14, #16384
    b.hs    9f
    sub     w14, w11, #1
    cmp     w14, #16384
    b.hs    9f
    cmp     w12, w10, lsl #2
    b.ne    9f
    umull   x14, w12, w11
    add     x14, x14, #64
    cmp     x13, x14
    b.ne    9f
    mov     x0, #1
    ret
9:  mov     x0, #0
    ret
// measure: how wide the w1 letters at x0 + 4 are, in sixteenths of a dot (the two numbers before them are filled in here) -> x0
measure:
    stp     x29, x30, [sp, #-16]!
    ldr     w9, [x19, #FONT]
    strh    w9, [x0]
    ldr     w9, [x19, #SIZE]
    strh    w9, [x0, #2]
    add     w2, w1, #2
    mov     x1, x0
    ldr     x0, [x19, #S]
    mov     x3, #0
    ldr     x4, [x19, #TABLE]
    ldr     x9, [x4, #(9 * 8)]
    blr     x9
    ldp     x29, x30, [sp], #16
    ret
// flush_line: draws the line gathered so far, if it shows, and moves down to the next
flush_line:
    stp     x29, x30, [sp, #-48]!
    stp     x25, x26, [sp, #16]
    stp     x27, x28, [sp, #32]
    ldr     w9, [x19, #LINE_N]
    cbz     w9, f_out
    ldp     x9, x10, [x19, #Y]
    add     x9, x9, x10
    str     x9, [x19, #Y]
    str     xzr, [x19, #PENDING]
    ldrsw   x10, [x19, #SCROLL]
    sub     x9, x9, x10                 // the line's top on the surface
    ldrsw   x10, [x19, #SIZE]
    add     x28, x9, x10                // where the letters stand
    ldrsw   x11, [x19, #HEIGHT]
    cmp     x9, x11
    b.ge    f_down
    add     x9, x9, x10, lsl #1
    cmp     x9, #0
    b.le    f_down
    mov     w26, #0                     // drawn run by run so link text can be another colour; the pen carries on
    mov     x27, #128
    mov     w25, #0
f_run:
    ldr     w9, [x19, #LINKS]
    cmp     w25, w9
    b.gt    f_down
    ldr     w10, [x19, #LINE_N]
    b.eq    1f
    add     x10, x19, #LINK_FROM
    ldr     w10, [x10, x25, lsl #2]
1:  cmp     w10, w26
    b.le    f_next
    add     x1, x19, #QBUF
    mov     x11, #16
    sdiv    x12, x27, x11
    sxtw    x12, w12                    // where this run starts, in whole dots
    mov     x2, #0
    ldr     w9, [x19, #FONT]
    strh    w9, [x1, x2, lsl #1]
    add     x2, x2, #1
    ldr     w9, [x19, #CACHE]
    tbnz    w9, #31, 2f
    strh    w9, [x1, x2, lsl #1]
    add     x2, x2, #1
    ldr     w9, [x19, #SCRATCH]
    strh    w9, [x1, x2, lsl #1]
    add     x2, x2, #1
2:  ldr     w9, [x19, #SIZE]
    strh    w9, [x1, x2, lsl #1]
    add     x2, x2, #1
    strh    w12, [x1, x2, lsl #1]
    add     x2, x2, #1
    strh    w28, [x1, x2, lsl #1]
    add     x2, x2, #1
    add     x13, x19, #LINE
    add     x13, x13, #8
    mov     w14, w26
3:  cmp     w14, w10
    b.ge    4f
    ldrh    w15, [x13, x14, lsl #1]
    strh    w15, [x1, x2, lsl #1]
    add     x2, x2, #1
    add     w14, w14, #1
    b       3b
4:  mov     w26, w10
    mov     x29, x27                    // (x29 is saved above and free here: the pen as it was)
    sub     x27, x27, x12, lsl #4
    ldr     w3, =0xff202020
    ldr     w9, =0xffcc5500
    tst     w25, #1
    csel    w3, w9, w3, ne
    ldr     x0, [x19, #S]
    ldr     x4, [x19, #TABLE]
    ldr     w9, [x19, #CACHE]
    mov     x10, #(8 * 8)
    mov     x11, #(11 * 8)
    tst     w9, #0x80000000
    csel    x10, x11, x10, eq
    ldr     x9, [x4, x10]
    blr     x9
    add     x27, x27, x0                // the pen moves to where the run ended,
    cmp     x0, #0
    csel    x27, x29, x27, lt           // unless the font piece refused
    add     w25, w25, #1
    b       f_run
f_next:
    mov     w26, w10
    add     w25, w25, #1
    b       f_run
f_down:
    ldr     w9, [x19, #SIZE]
    add     w9, w9, w9, lsl #2
    mov     w10, #4
    sdiv    w9, w9, w10
    ldr     x10, [x19, #Y]
    add     x10, x10, w9, sxtw
    str     x10, [x19, #Y]
    str     wzr, [x19, #LINE_N]
    str     xzr, [x19, #LINE_W]
    str     wzr, [x19, #LINKS]
    ldr     w9, [x19, #LINK]
    cbz     w9, f_out
    str     wzr, [x19, #LINK_FROM]      // a link continues onto the new line
    mov     w9, #1
    str     w9, [x19, #LINKS]
f_out:
    ldp     x25, x26, [sp, #16]
    ldp     x27, x28, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret
// end_word: the word gathered so far goes onto the line, or onto a new line if it does not fit
end_word:
    stp     x29, x30, [sp, #-32]!
    str     x28, [sp, #16]
    ldr     w1, [x19, #WORD_N]
    cbz     w1, e_out
    add     x0, x19, #WORD
    bl      measure
    cmp     x0, #0
    csel    x28, xzr, x0, lt
    ldr     w9, [x19, #LINE_N]
    cbz     w9, 1f
    ldrsw   x10, [x19, #WIDTH]
    sub     x10, x10, #16
    lsl     x10, x10, #4
    ldr     x11, [x19, #LINE_W]
    ldrsw   x12, [x19, #SPACE]
    add     x11, x11, x12
    add     x11, x11, x28
    cmp     x11, x10
    b.le    1f
    bl      flush_line
1:  ldr     w9, [x19, #LINE_N]
    add     x13, x19, #LINE
    add     x13, x13, #8
    cbz     w9, 2f
    cmp     w9, #399
    b.ge    2f
    mov     w10, #32
    strh    w10, [x13, x9, lsl #1]
    add     w9, w9, #1
    ldr     x11, [x19, #LINE_W]
    ldrsw   x12, [x19, #SPACE]
    add     x11, x11, x12
    str     x11, [x19, #LINE_W]
2:  ldr     w10, [x19, #WORD_N]
    add     x14, x19, #WORD
    add     x14, x14, #4
    mov     w11, #0
3:  cmp     w11, w10
    b.ge    4f
    cmp     w9, #400
    b.ge    4f
    ldrh    w12, [x14, x11, lsl #1]
    strh    w12, [x13, x9, lsl #1]
    add     w9, w9, #1
    add     w11, w11, #1
    b       3b
4:  str     w9, [x19, #LINE_N]
    ldr     x11, [x19, #LINE_W]
    add     x11, x11, x28
    str     x11, [x19, #LINE_W]
    str     wzr, [x19, #WORD_N]
e_out:
    ldr     x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// set_link: link text begins (w0 = 1) or ends (0) here
set_link:
    ldr     w9, [x19, #LINK]
    cmp     w0, w9
    b.eq    9f
    stp     x29, x30, [sp, #-32]!
    str     w0, [sp, #16]
    bl      end_word
    ldr     w9, [x19, #LINKS]
    cmp     w9, #40
    b.ge    1f
    ldr     w10, [x19, #LINE_N]
    add     x11, x19, #LINK_FROM
    str     w10, [x11, x9, lsl #2]
    add     w9, w9, #1
    str     w9, [x19, #LINKS]
1:  ldr     w0, [sp, #16]
    str     w0, [x19, #LINK]
    ldp     x29, x30, [sp], #32
9:  ret
// begin_block: a new block of text in size w0, with at least x1 dots of space before its first line
begin_block:
    stp     x29, x30, [sp, #-32]!
    stp     x0, x1, [sp, #16]
    bl      end_word
    bl      flush_line
    ldp     x0, x1, [sp, #16]
    ldr     x9, [x19, #PENDING]
    cmp     x1, x9
    csel    x9, x1, x9, gt
    str     x9, [x19, #PENDING]
    str     w0, [x19, #SIZE]
    add     x0, x19, #SP3
    mov     w9, #32
    strh    w9, [x0, #4]
    mov     w1, #1
    bl      measure
    cmp     w0, #0
    csel    w0, wzr, w0, lt
    str     w0, [x19, #SPACE]
    ldp     x29, x30, [sp], #32
    ret
// name_is: are the x1 bytes of the page at x0 the name at x2 (which ends in a zero byte), letters in either case -> x0 1 or 0
name_is:
    mov     x9, #0
1:  ldrb    w10, [x2, x9]
    cbz     w10, 3f
    cmp     x9, x1
    b.hs    2f
    add     x11, x0, x9
    cmp     x11, x21
    b.hs    2f
    ldrb    w11, [x20, x11]
    sub     w12, w11, #'A'
    cmp     w12, #25
    b.hi    4f
    add     w11, w11, #32
4:  cmp     w11, w10
    b.ne    2f
    add     x9, x9, #1
    b       1b
2:  mov     x0, #0
    ret
3:  cmp     x9, x1
    cset    x0, eq
    ret
// IS: is the tag's name (x23, x24) the name at the label -> flags: ne if so
    .macro  IS label
    mov     x0, x23
    mov     x1, x24
    adr     x2, \label
    bl      name_is
    cmp     x0, #0
    .endm
// BLOCK: the block at the handle in number \i, or at handle \else if there are not that many numbers -> x0, or 0. p is x27, n x28.
    .macro  BLOCK i, else
    mov     x9, #\else
    cmp     x28, #\i
    b.le    60f
    ldrsh   x9, [x27, #(\i * 2)]
60: mov     x0, #0
    cmp     x9, #0
    b.lt    61f
    cmp     x9, #255
    b.gt    61f
    add     x9, x9, #256
    ldr     x0, [x4, x9, lsl #3]
61:
    .endm

render:
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    add     x19, sp, #96
    mov     x27, x1
    mov     x28, x2
    str     x0, [x19, #S]
    str     x4, [x19, #TABLE]
    BLOCK   0, 0
    mov     x20, x0
    BLOCK   1, 0
    mov     x10, x0
    mov     w11, #0
    cmp     x28, #2
    b.le    1f
    ldrsh   w11, [x27, #4]
1:  cbz     x20, r_bad
    cbz     x10, r_bad
    ldr     w9, [x20]
    cmp     w9, #2
    b.ne    r_bad
    ldr     w9, [x10]
    cmp     w9, #2
    b.ne    r_bad
    ldr     x21, [x20, #16]
    cmp     x21, #64
    b.lo    r_bad
    cmp     w11, #6
    b.lt    r_bad
    cmp     w11, #200
    b.gt    r_bad
    sub     x21, x21, #64
    add     x20, x20, #64
    ldrsh   w9, [x27, #2]
    str     w9, [x19, #FONT]
    str     w11, [x19, #BASE]
    str     w11, [x19, #SIZE]
    mov     w9, #0
    cmp     x28, #3
    b.le    2f
    ldrsh   w9, [x27, #6]
2:  str     w9, [x19, #SCROLL]
    ldr     x0, [x19, #S]
    ldr     w9, [x0, #4]
    str     w9, [x19, #WIDTH]
    ldr     w9, [x0, #8]
    str     w9, [x19, #HEIGHT]
    mov     w12, #-1                    // a glyph cache and its scratch surface, if both were given and are what they should be
    mov     w13, #-1
    BLOCK   4, -1
    mov     x10, x0
    BLOCK   5, -1
    cmp     x28, #5
    b.le    3f
    cbz     x10, 3f
    cbz     x0, 3f
    ldr     w9, [x10]
    cmp     w9, #3
    b.ne    3f
    ldr     w9, [x0]
    cmp     w9, #4
    b.ne    3f
    ldrsh   w12, [x27, #8]
    ldrsh   w13, [x27, #10]
3:  str     w12, [x19, #CACHE]
    str     w13, [x19, #SCRATCH]
    str     wzr, [x19, #LINK]
    mov     x9, #8
    str     x9, [x19, #Y]
    str     xzr, [x19, #PENDING]
    str     wzr, [x19, #LINE_N]
    str     xzr, [x19, #LINE_W]
    str     wzr, [x19, #LINKS]
    str     wzr, [x19, #WORD_N]
    add     x0, x19, #SP3
    mov     w9, #32
    strh    w9, [x0, #4]
    mov     w1, #1
    bl      measure
    tbnz    w0, #31, r_bad
    str     w0, [x19, #SPACE]
    ldr     x0, [x19, #S]               // a white page
    mov     x1, #0
    mov     x2, #0
    mov     w3, #-1
    ldr     x4, [x19, #TABLE]
    ldr     x9, [x4, #(3 * 8)]
    blr     x9
    mov     x22, #0
r_loop:
    cmp     x22, x21
    b.hs    r_end
    ldrb    w9, [x20, x22]
    cmp     w9, #'<'
    b.ne    r_text
    add     x10, x22, #3                // a comment runs to its own ending
    cmp     x10, x21
    b.hs    1f
    add     x10, x20, x22
    ldrb    w11, [x10, #1]
    cmp     w11, #'!'
    b.ne    1f
    ldrb    w11, [x10, #2]
    cmp     w11, #'-'
    b.ne    1f
    ldrb    w11, [x10, #3]
    cmp     w11, #'-'
    b.ne    1f
    add     x22, x22, #4
2:  add     x10, x22, #2
    cmp     x10, x21
    b.hs    3f
    add     x10, x20, x22
    ldrb    w11, [x10]
    cmp     w11, #'-'
    b.ne    4f
    ldrb    w11, [x10, #1]
    cmp     w11, #'-'
    b.ne    4f
    ldrb    w11, [x10, #2]
    cmp     w11, #'>'
    b.eq    3f
4:  add     x22, x22, #1
    b       2b
3:  add     x22, x22, #3
    b       r_loop
1:  add     x10, x22, #1                // a tag: is it a closing one, what is its name, where does it end
    mov     x25, #0
    cmp     x10, x21
    b.hs    2f
    ldrb    w11, [x20, x10]
    cmp     w11, #'/'
    b.ne    2f
    mov     x25, #1
    add     x10, x10, #1
2:  mov     x23, x10
3:  cmp     x10, x21
    b.hs    5f
    ldrb    w11, [x20, x10]
    orr     w12, w11, #0x20
    sub     w12, w12, #'a'
    cmp     w12, #25
    b.ls    4f
    sub     w12, w11, #'0'
    cmp     w12, #9
    b.hi    5f
4:  add     x10, x10, #1
    b       3b
5:  sub     x24, x10, x23
6:  cmp     x10, x21
    b.hs    7f
    ldrb    w11, [x20, x10]
    cmp     w11, #'>'
    b.eq    7f
    add     x10, x10, #1
    b       6b
7:  add     x26, x10, #1
    cmp     x10, x21
    csel    x26, x26, x21, lo
    cbz     x24, r_after
    cbnz    x25, r_known
    mov     x28, #0                     // parts of a page that are not for reading are jumped over whole
    mov     x27, #0
8:  adr     x2, t_skipped
    add     x9, x27, x27, lsl #3
    add     x2, x2, x9
    mov     x0, x23
    mov     x1, x24
    bl      name_is
    cbz     x0, 9f
    add     x28, x27, #1
9:  add     x27, x27, #1
    cmp     x27, #6
    b.lo    8b
    cbz     x28, r_known
    sub     x28, x28, #1
    add     x28, x28, x28, lsl #3
    adr     x9, t_skipped
    add     x28, x9, x28                // the name whose closing tag is looked for
    mov     x27, x26
s_look:
    add     x9, x27, #2
    cmp     x9, x21
    b.hs    s_none
    add     x10, x20, x27
    ldrb    w11, [x10]
    cmp     w11, #'<'
    b.ne    s_on
    ldrb    w11, [x10, #1]
    cmp     w11, #'/'
    b.ne    s_on
    mov     x10, x9
1:  cmp     x10, x21
    b.hs    2f
    ldrb    w11, [x20, x10]
    cmp     w11, #'>'
    b.eq    2f
    cmp     w11, #' '
    b.eq    2f
    add     x10, x10, #1
    b       1b
2:  mov     x26, x10
    mov     x0, x9
    sub     x1, x10, x9
    mov     x2, x28
    bl      name_is
    cbz     x0, s_on
3:  cmp     x26, x21
    b.hs    4f
    ldrb    w11, [x20, x26]
    cmp     w11, #'>'
    b.eq    4f
    add     x26, x26, #1
    b       3b
4:  add     x22, x26, #1
    b       r_loop
s_on:
    add     x27, x27, #1
    b       s_look
s_none:
    mov     x22, x21
    b       r_loop
r_known:
    IS      t_br
    b.eq    1f
    bl      end_word
    ldr     w9, [x19, #LINE_N]
    cbz     w9, 2f
    bl      flush_line
    b       r_after
2:  ldr     w9, [x19, #SIZE]            // a break with nothing on the line: an empty line
    add     w9, w9, w9, lsl #2
    mov     w10, #4
    sdiv    w9, w9, w10
    ldp     x10, x11, [x19, #Y]
    add     x10, x10, x11
    add     x10, x10, w9, sxtw
    stp     x10, xzr, [x19, #Y]
    b       r_after
1:  IS      t_a
    b.eq    1f
    eor     w0, w25, #1
    bl      set_link
    b       r_after
1:  mov     x27, #0                     // a heading's level, or 0
    cmp     x24, #2
    b.ne    2f
    ldrb    w9, [x20, x23]
    orr     w9, w9, #0x20
    cmp     w9, #'h'
    b.ne    2f
    add     x9, x23, #1
    ldrb    w9, [x20, x9]
    sub     w9, w9, #'0'
    sub     w10, w9, #1
    cmp     w10, #5
    b.hi    2f
    mov     x27, x9
2:  mov     x28, #0                     // which kind of block, or 0
    str     xzr, [x19, #SP3]
3:  ldr     x9, [x19, #SP3]
    cmp     x9, #22
    b.hs    4f
    add     x10, x9, #1
    str     x10, [x19, #SP3]
    adr     x2, t_blocks
    add     x10, x9, x9, lsl #1
    add     x2, x2, x10, lsl #2
    mov     x0, x23
    mov     x1, x24
    bl      name_is
    cbz     x0, 3b
    ldr     x28, [x19, #SP3]
    b       3b
4:  orr     x9, x27, x28
    cbz     x9, r_after
    ldr     w10, [x19, #BASE]
    mov     w11, w10                    // the text size of this block
    cbz     x27, 6f
    cmp     x27, #3
    b.ne    5f
    mov     w12, #117
    mul     w11, w10, w12
    mov     w12, #100
    sdiv    w11, w11, w12
    b       6f
5:  adr     x12, t_num
    ldr     w12, [x12, x27, lsl #2]
    mul     w11, w10, w12
    mov     w12, #16
    sdiv    w11, w11, w12
6:  cmp     w11, #4
    mov     w12, #4
    csel    w11, w12, w11, lt
    mov     w13, w11                    // the size the space before it is reckoned from
    cbz     x25, 7f
    ldr     w13, [x19, #SIZE]
7:  mov     w12, #100
    mov     x1, #0
    cmp     x27, #1
    b.ne    8f
    mov     w14, #67
    mul     w1, w13, w14
    sdiv    w1, w1, w12
    b       10f
8:  cmp     x27, #2
    b.ne    9f
    mov     w14, #83
    mul     w1, w13, w14
    sdiv    w1, w1, w12
    b       10f
9:  cbnz    x27, 11f
    cmp     x28, #1
    b.ne    12f
11: mov     w1, w13
10: sxtw    x1, w1
12: mov     w0, w11
    cbz     x25, 13f
    mov     w0, w10
13: bl      begin_block
    cbnz    x25, r_after
    cmp     x28, #12
    b.ne    r_after
    mov     w9, #8226                   // a list item starts with a bullet
    strh    w9, [x19, #(WORD + 4)]
    mov     w9, #1
    str     w9, [x19, #WORD_N]
    bl      end_word
r_after:
    mov     x22, x26
    b       r_loop

r_text:                                 // a letter: w9 the byte, x27 its code, x28 how many bytes it took
    mov     x27, x9
    mov     x28, #1
    cmp     w9, #'&'
    b.ne    r_utf
    add     x10, x22, #1
    add     x11, x22, #10
1:  cmp     x10, x21
    b.hs    r_have
    cmp     x10, x11
    b.hs    2f
    ldrb    w12, [x20, x10]
    cmp     w12, #';'
    b.eq    2f
    cmp     w12, #' '
    b.eq    2f
    cmp     w12, #'<'
    b.eq    2f
    add     x10, x10, #1
    b       1b
2:  ldrb    w12, [x20, x10]
    cmp     w12, #';'
    b.ne    r_have
    add     x23, x22, #1
    sub     x24, x10, x23
    mov     x26, x10
    .macro  NAMED label, code
    IS      \label
    mov     x27, #\code
    b.ne    r_named
    .endm
    NAMED   t_amp, '&'
    NAMED   t_lt, '<'
    NAMED   t_gt, '>'
    NAMED   t_quot, '"'
    NAMED   t_apos, 39
    NAMED   t_nbsp, 160
    mov     x27, #'&'
    cmp     x24, #2
    b.lo    r_have
    ldrb    w9, [x20, x23]
    cmp     w9, #'#'
    b.ne    r_have
    mov     w9, #0                      // a letter given by its number
    add     x10, x22, #2
    mov     w13, #10
3:  cmp     x10, x26
    b.hs    5f
    ldrb    w11, [x20, x10]
    sub     w11, w11, #'0'
    cmp     w11, #9
    b.hi    4f
    madd    w9, w9, w13, w11
    mov     w12, #0x10ffff
    cmp     w9, w12
    b.gt    4f
    add     x10, x10, #1
    b       3b
4:  mov     w9, #-1
5:  mov     x27, #'?'
    cmp     w9, #0
    b.le    r_named
    mov     w27, w9
r_named:
    sub     x28, x26, x22
    add     x28, x28, #1
    b       r_have
r_utf:
    cmp     w9, #0x80
    b.lo    r_have
    mov     x27, #'?'
    cmp     w9, #0xc0
    b.lo    r_have
    mov     x10, #1                     // how many bytes follow the first
    cmp     w9, #0xe0
    cinc    x10, x10, hs
    cmp     w9, #0xf0
    cinc    x10, x10, hs
    mov     w11, #0x3f
    lsr     w11, w11, w10
    and     w11, w9, w11
    mov     x12, #1
6:  cmp     x12, x10
    b.hi    7f
    add     x13, x22, x12
    cmp     x13, x21
    b.hs    7f
    ldrb    w13, [x20, x13]
    and     w14, w13, #0xc0
    cmp     w14, #0x80
    b.ne    7f
    and     w13, w13, #0x3f
    orr     w11, w13, w11, lsl #6
    add     x12, x12, #1
    b       6b
7:  add     x10, x10, #1
    cmp     x12, x10
    b.ne    r_have
    mov     w27, w11
    mov     x28, x12
r_have:
    add     x22, x22, x28
    cmp     w27, #' '
    b.eq    8f
    cmp     w27, #10
    b.eq    8f
    cmp     w27, #9
    b.eq    8f
    cmp     w27, #13
    b.eq    8f
    cmp     w27, #12
    b.ne    9f
8:  bl      end_word
    b       r_loop
9:  mov     w9, #32767
    cmp     w27, w9
    mov     w9, #'?'
    csel    w27, w9, w27, gt
    ldr     w9, [x19, #WORD_N]
    cmp     w9, #80
    b.lt    10f
    bl      end_word
10: ldr     w9, [x19, #WORD_N]
    add     x10, x19, #WORD
    add     x10, x10, #4
    strh    w27, [x10, x9, lsl #1]
    add     w9, w9, #1
    str     w9, [x19, #WORD_N]
    b       r_loop
r_end:
    bl      end_word
    bl      flush_line
    ldr     x0, [x19, #Y]
    add     x0, x0, #8
    b       r_out
r_bad:
    mov     x0, #-1
r_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #FRAME
    ret
    .ltorg
t_br:   .asciz "br"
t_a:    .asciz "a"
t_amp:  .asciz "amp"
t_lt:   .asciz "lt"
t_gt:   .asciz "gt"
t_quot: .asciz "quot"
t_apos: .asciz "apos"
t_nbsp: .asciz "nbsp"
    .macro  NAME9 text
1:  .ascii  "\text"
    .zero   9 - (. - 1b)
    .endm
    .macro  NAME12 text
1:  .ascii  "\text"
    .zero   12 - (. - 1b)
    .endm
t_skipped:
    NAME9   head
    NAME9   script
    NAME9   style
    NAME9   title
    NAME9   noscript
    NAME9   svg
t_blocks:
    .irp    name, p, div, section, article, header, footer, main, ul, ol, blockquote, tr, li, body, html, table, nav, form, pre, dl, dt, dd, hr
    NAME12  \name
    .endr
    .balign 4
t_num:
    .word   0, 32, 24, 187, 16, 133, 107
