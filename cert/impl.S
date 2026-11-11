// cert, written by hand (ARM64): reads an X.509 certificate in DER. The meaning is cert/intent.md; the recorded checks are the judge.
// Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// A "run" is an address and a length, sixteen bytes in the frame. x19 points at the frame's runs and facts for the whole entry.
// Every length is checked against what is left before a byte is read; no load reaches past the end of a run.
    .text
    .global number
    .global bytes
    .global covers
    // runs being walked
    .equ S_ALL, 0
    .equ S_OUTER, 16
    .equ S_TBS, 32
    .equ S_ALG, 48
    .equ S_V, 64
    .equ S_W, 80
    .equ S_KEY, 96
    .equ S_LIST, 112
    .equ S_EXT, 128
    .equ S_VALUE, 144
    .equ S_KALG, 160
    // parts handed out by "bytes", in the order of its second number
    .equ C_TBS, 176
    .equ C_SIG, 192
    .equ C_R, 208
    .equ C_S, 224
    .equ C_KA, 240
    .equ C_KB, 256
    .equ C_ISS, 272
    .equ C_SUB, 288
    .equ C_SERIAL, 304
    .equ C_NAMES, 320
    // facts handed out by "number", eight bytes each, in the order of its second number (0 to 8)
    .equ N, 336
    .equ BASE, 112
    .equ FRAME, 528

// item: takes one box (kind, length, contents) off the front of the run at x0. -> x0 1 or 0, w1 its kind, x2 and x3 its contents,
// x4 and x5 the whole box. Uses x6-x11.
item:
    ldp     x6, x7, [x0]
    cmp     x7, #2
    b.lo    9f
    ldrb    w1, [x6]
    and     w8, w1, #31
    cmp     w8, #31
    b.eq    9f
    ldrb    w3, [x6, #1]
    mov     x8, #2
    tbz     w3, #7, 2f
    and     x9, x3, #0x7f
    cbz     x9, 9f
    cmp     x9, #3
    b.hi    9f
    add     x8, x9, #2
    cmp     x7, x8
    b.lo    9f
    mov     x3, #0
    mov     x10, #2
1:  ldrb    w11, [x6, x10]
    orr     x3, x11, x3, lsl #8
    add     x10, x10, #1
    cmp     x10, x8
    b.lo    1b
    cmp     x3, #128
    b.lo    9f
2:  add     x9, x8, x3
    cmp     x7, x9
    b.lo    9f
    add     x2, x6, x8
    mov     x4, x6
    mov     x5, x9
    add     x6, x6, x9
    sub     x7, x7, x9
    stp     x6, x7, [x0]
    mov     x0, #1
    ret
9:  mov     x0, #0
    ret
// integer: a whole number off the front of the run at x0, not empty -> x0 1 or 0, x2 and x3 its bytes. Uses x12 as well.
integer:
    mov     x12, x30
    bl      item
    cbz     x0, 9f
    cmp     w1, #2
    b.ne    8f
    cbnz    x3, 9f
8:  mov     x0, #0
9:  ret     x12

// when: a date (kind w1, bytes x2, count x3) -> x0 seconds since the start of 1970, or -1. Uses x4-x14.
    .macro  TWO dst, off
    ldrb    w6, [x2, #\off]
    sub     w6, w6, #48
    cmp     w6, #9
    cset    w8, hi
    orr     w4, w4, w8
    ldrb    w7, [x2, #(\off + 1)]
    sub     w7, w7, #48
    cmp     w7, #9
    cset    w8, hi
    orr     w4, w4, w8
    mov     w8, #10
    madd    \dst, w6, w8, w7
    .endm
when:
    mov     w4, #0
    cmp     w1, #0x17
    b.ne    1f
    cmp     x3, #13
    b.ne    9f
    TWO     w9, 0
    mov     w6, #2000
    mov     w7, #1900
    cmp     w9, #50
    csel    w6, w6, w7, lo
    add     w9, w9, w6
    add     x2, x2, #2
    b       2f
1:  cmp     w1, #0x18
    b.ne    9f
    cmp     x3, #15
    b.ne    9f
    TWO     w9, 0
    TWO     w10, 2
    mov     w6, #100
    madd    w9, w9, w6, w10
    add     x2, x2, #4
2:  TWO     w10, 0
    TWO     w11, 2
    TWO     w12, 4
    TWO     w13, 6
    TWO     w14, 8
    cbnz    w4, 9f
    ldrb    w6, [x2, #10]
    cmp     w6, #'Z'
    b.ne    9f
    cbz     w10, 9f
    cmp     w10, #12
    b.hi    9f
    cbz     w11, 9f
    cmp     w11, #31
    b.hi    9f
    cmp     w12, #23
    b.hi    9f
    cmp     w13, #59
    b.hi    9f
    cmp     w14, #60
    b.hi    9f
    cmp     w9, #1970
    b.lo    9f
    cmp     w10, #2                     // the year is taken to start in March, so the odd month comes last
    cset    w6, ls
    sub     w9, w9, w6                  // y
    mov     w6, #400
    udiv    w7, w9, w6                  // era
    msub    w8, w7, w6, w9              // year of era
    mov     w6, #9
    mov     w5, #-3
    cmp     w10, #2
    csel    w6, w5, w6, hi
    add     w10, w10, w6
    mov     w6, #153
    mul     w10, w10, w6
    add     w10, w10, #2
    mov     w6, #5
    udiv    w10, w10, w6
    add     w10, w10, w11
    sub     w10, w10, #1                // day of year
    mov     w6, #365
    mul     w5, w8, w6
    add     w5, w5, w8, lsr #2
    mov     w6, #100
    udiv    w6, w8, w6
    sub     w5, w5, w6
    add     w5, w5, w10                 // day of era
    ldr     w6, =146097
    umaddl  x5, w7, w6, x5
    ldr     x6, =719468
    sub     x5, x5, x6
    ldr     x6, =86400
    mul     x5, x5, x6
    mov     w6, #3600
    umaddl  x5, w12, w6, x5
    mov     w6, #60
    umaddl  x5, w13, w6, x5
    add     x0, x5, x14
    ret
9:  mov     x0, #-1
    ret

    .macro  ITEM off
    add     x0, x19, #\off
    bl      item
    cbz     x0, r_fail
    .endm
    .macro  INT off
    add     x0, x19, #\off
    bl      integer
    cbz     x0, r_fail
    .endm
    .macro  TAG t
    cmp     w1, #\t
    b.ne    r_fail
    .endm
    .macro  PUT off
    stp     x2, x3, [x19, #\off]
    .endm
    .macro  PUTW off
    stp     x4, x5, [x19, #\off]
    .endm
    .macro  EMPTY off
    ldr     x6, [x19, #(\off + 8)]
    cbnz    x6, r_fail
    .endm
    .macro  COPY from, to
    ldp     x6, x7, [x19, #\from]
    stp     x6, x7, [x19, #\to]
    .endm
// read_cert: the certificate in the block x0 (or 0) into the frame at x19 -> x0 1 or 0. Uses x20-x26 and everything below.
read_cert:
    mov     x20, x30
    cbz     x0, r_fail
    ldr     w1, [x0]
    cmp     w1, #2
    b.ne    r_fail
    ldr     x1, [x0, #16]
    cmp     x1, #80
    b.lo    r_fail
    add     x2, x0, #64
    sub     x3, x1, #64
    PUT     S_ALL
    ITEM    S_ALL
    TAG     0x30
    EMPTY   S_ALL
    PUT     S_OUTER
    ITEM    S_OUTER                     // the signed part
    TAG     0x30
    PUT     S_TBS
    PUTW    C_TBS
    ITEM    S_OUTER                     // how it is signed
    TAG     0x30
    PUT     S_ALG
    ITEM    S_OUTER                     // the signature
    TAG     3
    EMPTY   S_OUTER
    cmp     x3, #2
    b.lo    r_fail
    ldrb    w6, [x2]
    cbnz    w6, r_fail
    add     x2, x2, #1
    sub     x3, x3, #1
    PUT     C_SIG
    COPY    S_ALG, S_V
    mov     x21, #0
    add     x0, x19, #S_V
    bl      item
    cbz     x0, sk_done
    cmp     w1, #6
    b.ne    sk_done
    cmp     x3, #9
    b.ne    sk_ec
    ldr     x6, [x2]
    ldr     x7, =0x01010df78648862a
    cmp     x6, x7
    b.ne    sk_done
    ldrb    w8, [x2, #8]
    sub     w8, w8, #10
    cmp     w8, #1
    b.lo    sk_done
    cmp     w8, #3
    b.hi    sk_done
    mov     w21, w8
    b       sk_done
sk_ec:
    cmp     x3, #8
    b.ne    sk_done
    ldr     x6, [x2]
    and     x6, x6, #0x00ffffffffffffff
    ldr     x7, =0x0003043dce48862a
    cmp     x6, x7
    b.ne    sk_done
    ldrb    w8, [x2, #7]
    add     w8, w8, #2
    cmp     w8, #4
    b.lo    sk_done
    cmp     w8, #6
    b.hi    sk_done
    mov     w21, w8
sk_done:
    str     x21, [x19, #N]
    stp     xzr, xzr, [x19, #C_R]
    stp     xzr, xzr, [x19, #C_S]
    cmp     x21, #4
    b.lo    no_pair
    COPY    C_SIG, S_V
    ITEM    S_V
    TAG     0x30
    EMPTY   S_V
    PUT     S_W
    INT     S_W
    PUT     C_R
    INT     S_W
    PUT     C_S
    EMPTY   S_W
no_pair:
    mov     x22, #1                     // version
    ldp     x6, x7, [x19, #S_TBS]
    cbz     x7, no_version
    ldrb    w8, [x6]
    cmp     w8, #0xa0
    b.ne    no_version
    ITEM    S_TBS
    PUT     S_V
    INT     S_V
    cmp     x3, #1
    b.ne    r_fail
    ldrb    w22, [x2]
    add     w22, w22, #1
no_version:
    str     x22, [x19, #(N + 64)]
    INT     S_TBS
    PUT     C_SERIAL
    ITEM    S_TBS                       // the signature kind again: it must be the same bytes as outside
    TAG     0x30
    ldp     x6, x7, [x19, #S_ALG]
    cmp     x3, x7
    b.ne    r_fail
    mov     x8, #0
1:  cmp     x8, x3
    b.hs    2f
    ldrb    w9, [x2, x8]
    ldrb    w10, [x6, x8]
    cmp     w9, w10
    b.ne    r_fail
    add     x8, x8, #1
    b       1b
2:  ITEM    S_TBS
    TAG     0x30
    PUTW    C_ISS
    ITEM    S_TBS
    TAG     0x30
    PUT     S_V
    ITEM    S_V
    bl      when
    str     x0, [x19, #(N + 24)]
    ITEM    S_V
    EMPTY   S_V
    bl      when
    str     x0, [x19, #(N + 32)]
    tbnz    x0, #63, r_fail
    ldr     x0, [x19, #(N + 24)]
    tbnz    x0, #63, r_fail
    ITEM    S_TBS
    TAG     0x30
    PUTW    C_SUB
    ITEM    S_TBS                       // the key, with its kind
    TAG     0x30
    PUT     S_V
    ITEM    S_V
    TAG     0x30
    PUT     S_KALG
    ITEM    S_V
    TAG     3
    EMPTY   S_V
    cmp     x3, #2
    b.lo    r_fail
    ldrb    w6, [x2]
    cbnz    w6, r_fail
    add     x2, x2, #1
    sub     x3, x3, #1
    PUT     S_KEY
    str     xzr, [x19, #(N + 8)]
    stp     xzr, xzr, [x19, #C_KA]
    stp     xzr, xzr, [x19, #C_KB]
    ITEM    S_KALG
    TAG     6
    cmp     x3, #9
    b.ne    key_ec
    ldr     x6, [x2]
    ldr     x7, =0x01010df78648862a
    cmp     x6, x7
    b.ne    key_done
    ldrb    w8, [x2, #8]
    cmp     w8, #1
    b.ne    key_done
    ITEM    S_KEY
    TAG     0x30
    EMPTY   S_KEY
    PUT     S_W
    INT     S_W
    PUT     C_KA
    INT     S_W
    PUT     C_KB
    EMPTY   S_W
    mov     x6, #1
    str     x6, [x19, #(N + 8)]
    b       key_done
key_ec:
    cmp     x3, #7
    b.ne    key_done
    ldr     w6, [x2]
    ldur    w7, [x2, #3]
    orr     x6, x6, x7, lsl #24
    ldr     x7, =0x0001023dce48862a
    cmp     x6, x7
    b.ne    key_done
    ITEM    S_KALG
    TAG     6
    mov     x8, #0                      // the size of one coordinate, if the curve is known
    cmp     x3, #8
    b.ne    1f
    ldr     x6, [x2]
    ldr     x7, =0x0701033dce48862a
    cmp     x6, x7
    b.ne    key_done
    mov     x8, #32
    b       2f
1:  cmp     x3, #5
    b.ne    key_done
    ldr     w6, [x2]
    ldr     w7, =0x0004812b
    cmp     w6, w7
    b.ne    key_done
    ldrb    w6, [x2, #4]
    cmp     w6, #0x22
    b.ne    key_done
    mov     x8, #48
2:  ldp     x6, x7, [x19, #S_KEY]
    add     x9, x8, x8
    add     x9, x9, #1
    cmp     x7, x9
    b.ne    key_done
    ldrb    w9, [x6]
    cmp     w9, #4
    b.ne    key_done
    add     x6, x6, #1
    stp     x6, x8, [x19, #C_KA]
    add     x6, x6, x8
    stp     x6, x8, [x19, #C_KB]
    mov     x6, #2
    cmp     x8, #32
    cinc    x6, x6, ne
    str     x6, [x19, #(N + 8)]
key_done:
    mov     x6, #-1
    str     xzr, [x19, #(N + 16)]
    str     x6, [x19, #(N + 40)]
    str     x6, [x19, #(N + 48)]
    str     xzr, [x19, #(N + 56)]
    stp     xzr, xzr, [x19, #C_NAMES]
rest:                                   // whatever else is in the signed part; only the extensions matter
    ldr     x6, [x19, #(S_TBS + 8)]
    cbz     x6, r_good
    ITEM    S_TBS
    cmp     w1, #0xa3
    b.ne    rest
    cmp     x22, #3
    b.ne    r_fail
    PUT     S_V
    ITEM    S_V
    TAG     0x30
    EMPTY   S_V
    PUT     S_LIST
each:
    ldr     x6, [x19, #(S_LIST + 8)]
    cbz     x6, rest
    ITEM    S_LIST
    TAG     0x30
    PUT     S_EXT
    ITEM    S_EXT
    TAG     6
    mov     x23, x2
    mov     x24, x3
    ITEM    S_EXT
    mov     x25, #0                     // critical?
    cmp     w1, #1
    b.ne    1f
    cmp     x3, #1
    b.ne    r_fail
    ldrb    w6, [x2]
    cmp     w6, #0
    cset    x25, ne
    ITEM    S_EXT
1:  TAG     4
    EMPTY   S_EXT
    PUT     S_VALUE
    mov     x26, #0
    cmp     x24, #3
    b.ne    2f
    ldrb    w6, [x23]
    cmp     w6, #0x55
    b.ne    2f
    ldrb    w6, [x23, #1]
    cmp     w6, #0x1d
    b.ne    2f
    ldrb    w26, [x23, #2]
2:  cmp     x26, #19
    b.eq    e_basic
    cmp     x26, #15
    b.eq    e_usage
    cmp     x26, #17
    b.eq    e_names
    cmp     x26, #37
    b.eq    each
    cmp     x26, #32
    b.eq    each
    cmp     x26, #14
    b.eq    each
    cmp     x26, #35
    b.eq    each
    cmp     x26, #31
    b.eq    each
    cbz     x25, each
    mov     x6, #1
    str     x6, [x19, #(N + 56)]
    b       each
e_basic:
    ITEM    S_VALUE
    TAG     0x30
    PUT     S_W
    cbz     x3, each
    ldrb    w6, [x2]
    cmp     w6, #1
    b.ne    1f
    ITEM    S_W
    cmp     x3, #1
    b.ne    r_fail
    ldrb    w6, [x2]
    cmp     w6, #0
    cset    x6, ne
    str     x6, [x19, #(N + 16)]
1:  ldr     x6, [x19, #(S_W + 8)]
    cbz     x6, each
    INT     S_W
    cmp     x3, #2
    b.hi    r_fail
    ldrb    w6, [x2]
    cmp     x3, #1
    b.eq    2f
    ldrb    w7, [x2, #1]
    orr     w6, w7, w6, lsl #8
2:  str     x6, [x19, #(N + 40)]
    b       each
e_usage:
    ITEM    S_VALUE
    TAG     3
    cmp     x3, #2
    b.lo    r_fail
    ldrb    w6, [x2, #1]
    b.eq    1f
    ldrb    w7, [x2, #2]
    orr     w6, w6, w7, lsl #8
1:  str     x6, [x19, #(N + 48)]
    b       each
e_names:
    ITEM    S_VALUE
    TAG     0x30
    PUT     C_NAMES
    b       each
r_good:
    mov     x0, #1
    ret     x20
r_fail:
    mov     x0, #0
    ret     x20
    .ltorg

    .macro  ENTER
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    stp     x2, x4, [sp, #96]
    add     x19, sp, #BASE
    mov     x27, x0
    mov     x28, x1
    .endm
    .macro  LEAVE
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #FRAME
    ret
    .endm
// block_at: the block at the handle in number x5 (numbers x28; count and table in the frame) -> x0, or 0. Uses x6, x7.
block_at:
    ldp     x6, x7, [sp, #96]
    mov     x0, #0
    cmp     x6, x5
    b.le    9f
    ldrsh   x6, [x28, x5, lsl #1]
    cmp     x6, #0
    b.lt    9f
    cmp     x6, #255
    b.gt    9f
    add     x6, x6, #256
    ldr     x0, [x7, x6, lsl #3]
9:  ret
// which: the second number, or -1 -> x5
    .macro  WHICH
    ldr     x6, [sp, #96]
    mov     x5, #-1
    cmp     x6, #1
    b.le    66f
    ldrsh   x5, [x28, #2]
66:
    .endm

number:
    ENTER
    mov     x5, #0
    bl      block_at
    bl      read_cert
    cbz     x0, n_fail
    WHICH
    cmp     x5, #0
    b.lt    n_fail
    cmp     x5, #8
    b.hi    1f
    add     x6, x19, #N
    ldr     x0, [x6, x5, lsl #3]
    b       n_out
1:  cmp     x5, #9
    b.ne    n_fail
    ldp     x6, x7, [x19, #C_ISS]       // issuer and subject the same bytes?
    ldp     x8, x9, [x19, #C_SUB]
    mov     x0, #0
    cmp     x7, x9
    b.ne    n_out
    mov     x10, #0
2:  cmp     x10, x7
    b.hs    3f
    ldrb    w11, [x6, x10]
    ldrb    w12, [x8, x10]
    cmp     w11, w12
    b.ne    n_out
    add     x10, x10, #1
    b       2b
3:  mov     x0, #1
    b       n_out
n_fail:
    mov     x0, #-1
n_out:
    LEAVE

bytes:
    ENTER
    mov     x5, #0
    bl      block_at
    cmp     x0, x27
    b.eq    b_fail
    ldr     x6, [x27, #16]
    cmp     x6, #64
    b.lo    b_fail
    bl      read_cert
    cbz     x0, b_fail
    WHICH
    cmp     x5, #0
    b.lt    b_fail
    cmp     x5, #8
    b.hi    b_fail
    add     x6, x19, #C_TBS
    add     x6, x6, x5, lsl #4
    ldp     x6, x7, [x6]
    cbz     x6, b_fail
    ldr     x8, [x27, #16]
    add     x9, x7, #64
    cmp     x8, x9
    b.lo    b_fail
    add     x8, x27, #64
    mov     x9, #0
1:  cmp     x9, x7
    b.hs    2f
    ldrb    w10, [x6, x9]
    strb    w10, [x8, x9]
    add     x9, x9, #1
    b       1b
2:  mov     x0, x7
    b       b_out
b_fail:
    mov     x0, #-1
b_out:
    LEAVE

// same: x2 bytes at x0 and at x1 alike, letters in either case -> x0 1 or 0. Uses x3-x6.
same:
    mov     x3, #0
1:  cmp     x3, x2
    b.hs    3f
    ldrb    w4, [x0, x3]
    ldrb    w5, [x1, x3]
    sub     w6, w4, #'A'
    cmp     w6, #25
    b.hi    2f
    add     w4, w4, #32
2:  sub     w6, w5, #'A'
    cmp     w6, #25
    b.hi    2f
    add     w5, w5, #32
2:  cmp     w4, w5
    b.ne    4f
    add     x3, x3, #1
    b       1b
3:  mov     x0, #1
    ret
4:  mov     x0, #0
    ret

covers:
    ENTER
    mov     x5, #0
    bl      block_at
    bl      read_cert
    cbz     x0, c_fail
    mov     x5, #1
    bl      block_at
    cbz     x0, c_fail
    ldr     w6, [x0]
    cmp     w6, #2
    b.ne    c_fail
    ldr     x22, [x0, #16]
    cmp     x22, #64
    b.ls    c_fail
    cmp     x22, #(64 + 253)
    b.hi    c_fail
    add     x21, x0, #64                // the site name and its length, without a last dot
    sub     x22, x22, #64
    sub     x6, x22, #1
    ldrb    w7, [x21, x6]
    cmp     w7, #'.'
    csel    x22, x6, x22, eq
    COPY    C_NAMES, S_LIST
c_each:
    ldr     x6, [x19, #(S_LIST + 8)]
    cbz     x6, c_no
    add     x0, x19, #S_LIST
    bl      item
    cbz     x0, c_fail
    cmp     w1, #0x82
    b.ne    c_each
    cbz     x3, c_each
    mov     x23, x2
    mov     x24, x3
    cmp     x24, x22
    b.ne    1f
    mov     x0, x23
    mov     x1, x21
    mov     x2, x22
    bl      same
    cbnz    x0, c_yes
1:  cmp     x24, #2                     // "*.something" covers exactly one more label
    b.ls    c_each
    ldrb    w6, [x23]
    cmp     w6, #'*'
    b.ne    c_each
    ldrb    w6, [x23, #1]
    cmp     w6, #'.'
    b.ne    c_each
    mov     x25, #0
2:  cmp     x25, x22
    b.hs    3f
    ldrb    w6, [x21, x25]
    cmp     w6, #'.'
    b.eq    3f
    add     x25, x25, #1
    b       2b
3:  cbz     x25, c_each
    cmp     x25, x22
    b.hs    c_each
    sub     x2, x22, x25
    sub     x6, x24, #1
    cmp     x2, x6
    b.ne    c_each
    add     x0, x23, #1
    add     x1, x21, x25
    bl      same
    cbz     x0, c_each
c_yes:
    mov     x0, #1
    b       c_out
c_no:
    mov     x0, #0
    b       c_out
c_fail:
    mov     x0, #-1
c_out:
    LEAVE
