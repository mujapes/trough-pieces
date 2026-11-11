// charset, written by hand (ARM64). The meaning is charset/intent.md; the recorded checks are the judge.
// Every entry: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table. Only scratch registers are used; no stack.
    .text
    .global to_utf8
    .global named
// --- to_utf8 -------------------------------------------------------------------------------------------------------------------
// after set-up: x1 source bytes, x2 how many, x10 output, x11 bytes written, x12 room, w13 set when the output is full
to_utf8:
    mov     x16, x30
    cmp     x2, #1
    b.lt    fail
    ldrsh   x5, [x1]
    cmp     x5, #0
    b.lt    fail
    cmp     x5, #255
    b.gt    fail
    add     x5, x5, #256
    ldr     x6, [x4, x5, lsl #3]        // the source block
    cbz     x6, fail
    ldr     w7, [x6]
    cmp     w7, #2                      // plain bytes?
    b.ne    fail
    ldr     x7, [x6, #16]
    cmp     x7, #64
    b.lo    fail
    cmp     x6, x0
    b.eq    fail
    ldr     x8, [x0, #16]
    cmp     x8, #64
    b.lo    fail
    mov     x17, #0
    cmp     x2, #2
    b.lt    1f
    ldrsh   x17, [x1, #2]               // which encoding
1:  cmp     x17, #1
    b.lt    fail
    cmp     x17, #4
    b.gt    fail
    add     x1, x6, #64
    sub     x2, x7, #64
    add     x10, x0, #64
    mov     x11, #0
    sub     x12, x8, #64
    mov     w13, #0
    cmp     x17, #1
    b.eq    utf8
    cmp     x17, #2
    b.eq    windows
    b       utf16
done:
    cbnz    w13, fail
    mov     x0, x11
    ret     x16
fail:
    mov     x0, #-1
    ret     x16
// one character (w9) out as UTF-8; uses x14, x15
emit:
    cmp     w9, #0x80
    b.hs    2f
    add     x14, x11, #1
    cmp     x14, x12
    b.hi    full
    strb    w9, [x10, x11]
    mov     x11, x14
    ret
2:  cmp     w9, #0x800
    b.hs    3f
    add     x14, x11, #2
    cmp     x14, x12
    b.hi    full
    lsr     w15, w9, #6
    orr     w15, w15, #0xc0
    strb    w15, [x10, x11]
    add     x11, x11, #1
    b       last
3:  mov     w15, #0x10000
    cmp     w9, w15
    b.hs    4f
    add     x14, x11, #3
    cmp     x14, x12
    b.hi    full
    lsr     w15, w9, #12
    orr     w15, w15, #0xe0
    strb    w15, [x10, x11]
    add     x11, x11, #1
    b       middle
4:  add     x14, x11, #4
    cmp     x14, x12
    b.hi    full
    lsr     w15, w9, #18
    orr     w15, w15, #0xf0
    strb    w15, [x10, x11]
    add     x11, x11, #1
    lsr     w15, w9, #12
    and     w15, w15, #63
    orr     w15, w15, #0x80
    strb    w15, [x10, x11]
    add     x11, x11, #1
middle:
    lsr     w15, w9, #6
    and     w15, w15, #63
    orr     w15, w15, #0x80
    strb    w15, [x10, x11]
    add     x11, x11, #1
last:
    and     w15, w9, #63
    orr     w15, w15, #0x80
    strb    w15, [x10, x11]
    add     x11, x11, #1
    ret
full:
    mov     w13, #1
    ret
// UTF-8 in: each stretch that cannot belong to a well-formed character becomes one U+FFFD
utf8:
    cmp     x2, #3
    b.lo    1f
    ldrb    w5, [x1]
    cmp     w5, #0xef
    b.ne    1f
    ldrb    w5, [x1, #1]
    cmp     w5, #0xbb
    b.ne    1f
    ldrb    w5, [x1, #2]
    cmp     w5, #0xbf
    b.ne    1f
    add     x1, x1, #3                  // a byte-order mark is dropped
    sub     x2, x2, #3
1:  mov     x5, #0                      // i
u_next:
    cmp     x5, x2
    b.hs    done
    cbnz    w13, done
    ldrb    w6, [x1, x5]                // the lead byte
    cmp     w6, #0x80
    b.hs    2f
u_plain:                                // plain letters go straight across, as many as there are in a row
    cmp     x11, x12
    b.hs    u_full
    strb    w6, [x10, x11]
    add     x11, x11, #1
    add     x5, x5, #1
    cmp     x5, x2
    b.hs    done
    ldrb    w6, [x1, x5]
    cmp     w6, #0x80
    b.lo    u_plain
    b       2f
u_full:
    mov     w13, #1
    b       done
2:  cmp     w6, #0xc2
    b.lo    u_bad
    cmp     w6, #0xdf
    b.hi    3f
    mov     w7, #1                      // how many more bytes it needs
    and     w8, w6, #0x1f
    b       4f
3:  cmp     w6, #0xef
    b.hi    5f
    mov     w7, #2
    and     w8, w6, #0x0f
    b       4f
5:  cmp     w6, #0xf4
    b.hi    u_bad
    mov     w7, #3
    and     w8, w6, #0x07
4:  mov     w3, #0x80                   // the second byte's allowed range rules out overlong forms, surrogates, values past the end
    mov     w17, #0xbf
    mov     w14, #0xa0
    cmp     w6, #0xe0
    csel    w3, w14, w3, eq
    mov     w14, #0x90
    cmp     w6, #0xf0
    csel    w3, w14, w3, eq
    mov     w14, #0x9f
    cmp     w6, #0xed
    csel    w17, w14, w17, eq
    mov     w14, #0x8f
    cmp     w6, #0xf4
    csel    w17, w14, w17, eq
    mov     w0, #0                      // continuation bytes taken
    add     x4, x5, #1                  // j
6:  cmp     w0, w7
    b.hs    7f
    cmp     x4, x2
    b.hs    7f
    ldrb    w14, [x1, x4]
    cmp     w14, w3
    b.lo    7f
    cmp     w14, w17
    b.hi    7f
    lsl     w8, w8, #6
    and     w15, w14, #63
    orr     w8, w8, w15
    add     w0, w0, #1
    add     x4, x4, #1
    mov     w3, #0x80                   // after the first, the ordinary range
    mov     w17, #0xbf
    b       6b
7:  mov     w9, #0xfffd
    cmp     w0, w7
    csel    w9, w8, w9, eq
    mov     x5, x4
    bl      emit
    b       u_next
u_bad:
    mov     w9, #0xfffd
    bl      emit
    add     x5, x5, #1
    b       u_next
// windows-1252: the lower half is itself, the upper half comes from the table
windows:
    adr     x6, table_1252
    mov     x5, #0
1:  cmp     x5, x2
    b.hs    done
    cbnz    w13, done
    ldrb    w9, [x1, x5]
    cmp     w9, #128
    b.lo    2f
    sub     w9, w9, #128
    ldrh    w9, [x6, w9, uxtw #1]
2:  bl      emit
    add     x5, x5, #1
    b       1b
// UTF-16, either byte order (w3 = 1 for big-endian)
utf16:
    cmp     x17, #4
    cset    w3, eq
    cmp     x2, #2
    b.lo    2f
    ldrb    w5, [x1]
    ldrb    w6, [x1, #1]
    mov     w7, #0xff
    mov     w8, #0xfe
    cmp     w3, #0
    csel    w14, w8, w7, ne             // the mark's first byte: fe if big-endian, ff if not
    csel    w15, w7, w8, ne
    cmp     w5, w14
    b.ne    2f
    cmp     w6, w15
    b.ne    2f
    add     x1, x1, #2
    sub     x2, x2, #2
2:  mov     x5, #0
w_next:
    add     x6, x5, #1
    cmp     x6, x2
    b.hs    w_tail
    cbnz    w13, done
    ldrb    w7, [x1, x5]
    ldrb    w8, [x1, x6]
    cbz     w3, 3f
    orr     w7, w8, w7, lsl #8
    b       4f
3:  orr     w7, w7, w8, lsl #8
4:  mov     w14, #0xd800
    sub     w14, w7, w14                // 0..0x3ff: first of a pair; 0x400..0x7ff: second without a first
    cmp     w14, #0x400
    b.lo    w_high
    cmp     w14, #0x800
    b.lo    w_stray
    mov     w9, w7
    bl      emit
    add     x5, x5, #2
    b       w_next
w_stray:
    mov     w9, #0xfffd
    bl      emit
    add     x5, x5, #2
    b       w_next
w_high:
    add     x6, x5, #3
    cmp     x6, x2
    b.hs    w_cut                       // the text ends inside the pair: one mark for the lot
    add     x6, x5, #2
    ldrb    w8, [x1, x6]
    add     x6, x5, #3
    ldrb    w15, [x1, x6]
    cbz     w3, 5f
    orr     w8, w15, w8, lsl #8
    b       6f
5:  orr     w8, w8, w15, lsl #8
6:  mov     w15, #0xdc00
    sub     w15, w8, w15
    cmp     w15, #0x400
    b.hs    w_stray                     // not its partner: a mark, and the next unit is read afresh
    add     w9, w15, w14, lsl #10
    add     w9, w9, #0x10000
    bl      emit
    add     x5, x5, #4
    b       w_next
w_cut:
    mov     w9, #0xfffd
    bl      emit
    b       done
w_tail:
    cmp     x5, x2
    b.hs    done
    cbnz    w13, done
    mov     w9, #0xfffd                 // one odd byte left over
    bl      emit
    b       done
// --- named ---------------------------------------------------------------------------------------------------------------------
named:
    cmp     x2, #1
    b.lt    n_fail
    ldrsh   x5, [x1]
    cmp     x5, #0
    b.lt    n_fail
    cmp     x5, #255
    b.gt    n_fail
    add     x5, x5, #256
    ldr     x6, [x4, x5, lsl #3]
    cbz     x6, n_fail
    ldr     w7, [x6]
    cmp     w7, #2
    b.ne    n_fail
    ldr     x7, [x6, #16]
    cmp     x7, #64
    b.lo    n_fail
    add     x1, x6, #64                 // the label
    sub     x2, x7, #64
1:  cbz     x2, 3f                      // spaces and quotes off the front
    ldrb    w5, [x1]
    cmp     w5, #' '
    b.eq    2f
    cmp     w5, #9
    b.eq    2f
    cmp     w5, #10
    b.eq    2f
    cmp     w5, #13
    b.eq    2f
    cmp     w5, #'"'
    b.eq    2f
    cmp     w5, #39
    b.ne    3f
2:  add     x1, x1, #1
    sub     x2, x2, #1
    b       1b
3:  cbz     x2, 5f                      // and off the back, a semicolon too
    sub     x6, x2, #1
    ldrb    w5, [x1, x6]
    cmp     w5, #' '
    b.eq    4f
    cmp     w5, #9
    b.eq    4f
    cmp     w5, #10
    b.eq    4f
    cmp     w5, #13
    b.eq    4f
    cmp     w5, #'"'
    b.eq    4f
    cmp     w5, #39
    b.eq    4f
    cmp     w5, #';'
    b.ne    5f
4:  sub     x2, x2, #1
    b       3b
5:  adr     x6, labels                  // each: its answer, its length, its letters
6:  ldrb    w7, [x6]
    cbz     w7, n_none
    ldrb    w8, [x6, #1]
    cmp     x8, x2
    b.ne    8f
    mov     x9, #0
7:  cmp     x9, x8
    b.hs    n_found
    ldrb    w10, [x1, x9]
    sub     w11, w10, #'A'
    cmp     w11, #26
    b.hs    9f
    add     w10, w10, #32               // capitals count as small letters
9:  add     x12, x6, #2
    ldrb    w11, [x12, x9]
    cmp     w10, w11
    b.ne    8f
    add     x9, x9, #1
    b       7b
8:  add     x6, x6, x8
    add     x6, x6, #2
    b       6b
n_found:
    mov     x0, x7
    ret
n_none:
    mov     x0, #0
    ret
n_fail:
    mov     x0, #-1
    ret
    .balign 2
table_1252:
    .hword 8364, 129, 8218, 402, 8222, 8230, 8224, 8225, 710, 8240, 352, 8249, 338, 141, 381, 143
    .hword 144, 8216, 8217, 8220, 8221, 8226, 8211, 8212, 732, 8482, 353, 8250, 339, 157, 382, 376
    .hword 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175
    .hword 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191
    .hword 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207
    .hword 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223
    .hword 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239
    .hword 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255
labels:
    .byte 1, 5
    .ascii "utf-8"
    .byte 1, 4
    .ascii "utf8"
    .byte 1, 17
    .ascii "unicode-1-1-utf-8"
    .byte 2, 12
    .ascii "windows-1252"
    .byte 2, 6
    .ascii "cp1252"
    .byte 2, 8
    .ascii "x-cp1252"
    .byte 2, 10
    .ascii "iso-8859-1"
    .byte 2, 9
    .ascii "iso8859-1"
    .byte 2, 10
    .ascii "iso_8859-1"
    .byte 2, 6
    .ascii "latin1"
    .byte 2, 2
    .ascii "l1"
    .byte 2, 5
    .ascii "ascii"
    .byte 2, 8
    .ascii "us-ascii"
    .byte 2, 5
    .ascii "cp819"
    .byte 2, 6
    .ascii "ibm819"
    .byte 3, 8
    .ascii "utf-16le"
    .byte 3, 6
    .ascii "utf-16"
    .byte 3, 5
    .ascii "ucs-2"
    .byte 3, 7
    .ascii "unicode"
    .byte 4, 8
    .ascii "utf-16be"
    .byte 0
    .balign 4
