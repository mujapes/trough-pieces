// trust, written by hand (ARM64): is the site's certificate trusted, and did its key sign the handshake. The meaning is
// trust/intent.md; the recorded checks are the judge. It decides by asking other pieces through sockets: cert (23-25), hash (14, 21,
// 22), rsa (26, 27), ecdsa (28). Entries: x0 block (unused), x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Through an entry: x19 the frame, x20 the real call table, x21 the time now. The frame holds one call table of this piece's own
// (the real sockets, copied once, and handles 1 to 5 filled before each call) and the blocks handed to other pieces.
    .text
    .global chain
    .global signed_handshake
    .equ Q, 96
    .equ LEN, 112
    .equ IDX, 120
    .equ SENT, 128
    .equ USED, 192
    .equ ROOTS, 200
    .equ MINE, 208
    .equ M1, MINE + 257 * 8
    .equ M2, MINE + 258 * 8
    .equ M3, MINE + 259 * 8
    .equ M4, MINE + 260 * 8
    .equ M5, MINE + 261 * 8
    .equ CI, 4304
    .equ CS, 5072
    .equ SI, 5840
    .equ SS, 6608
    .equ DG, 7376
    .equ SA, 8144
    .equ SB, 8912
    .equ KA, 9680
    .equ KB, 10448
    .equ TBS, 11216
    .equ ROOT, 19472
    .equ FRAME, 27728
    .macro  ADDR reg, off
    mov     \reg, #\off
    add     \reg, x19, \reg
    .endm
    .macro  SOCKET slot
    ADDR    x4, MINE
    ldr     x9, [x20, #(\slot * 8)]
    blr     x9
    .endm

// head: makes the 64 bytes at x0 the head of a plain block holding x1 bytes. Uses x2.
head:
    stp     xzr, xzr, [x0]
    stp     xzr, xzr, [x0, #16]
    stp     xzr, xzr, [x0, #32]
    stp     xzr, xzr, [x0, #48]
    mov     w2, #2
    str     w2, [x0]
    add     x2, x1, #64
    str     x2, [x0, #16]
    ret
// fact: fact x1 of the certificate x0 -> x0
fact:
    stp     x29, x30, [sp, #-16]!
    str     x0, [x19, #M1]
    mov     w9, #1
    strh    w9, [x19, #Q]
    strh    w1, [x19, #(Q + 2)]
    mov     x0, #0
    add     x1, x19, #Q
    mov     x2, #2
    mov     x3, #0
    SOCKET  23
    ldp     x29, x30, [sp], #16
    ret
// part: part x1 of the certificate x0 into the block x2 (room x3), which then holds exactly that part -> x0 its length, or less than 0
part:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    mov     x27, x2
    str     x0, [x19, #M1]
    mov     w9, #1
    strh    w9, [x19, #Q]
    strh    w1, [x19, #(Q + 2)]
    mov     x0, x27
    mov     x1, x3
    bl      head
    mov     x0, x27
    add     x1, x19, #Q
    mov     x2, #2
    mov     x3, #0
    SOCKET  24
    mov     x28, x0
    tbnz    x0, #63, 1f
    mov     x0, x27
    mov     x1, x28
    bl      head
1:  mov     x0, x28
    ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// digest: the x0-byte digest (32, 48 or 64) of the block x1 into the block x2 -> x0 1 or 0
digest:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    mov     x28, x0
    mov     x27, x2
    str     x1, [x19, #M1]
    mov     w9, #1
    strh    w9, [x19, #Q]
    mov     x0, x27
    mov     x1, #704
    bl      head
    mov     x9, #(14 * 8)
    cmp     x28, #32
    b.eq    1f
    mov     x9, #(21 * 8)
    cmp     x28, #48
    b.eq    1f
    mov     x9, #(22 * 8)
1:  ldr     x9, [x20, x9]
    mov     x0, x27
    add     x1, x19, #Q
    mov     x2, #1
    mov     x3, #0
    ADDR    x4, MINE
    blr     x9
    cmp     x0, x28
    b.ne    2f
    mov     x0, x27
    mov     x1, x28
    bl      head
    mov     x0, #1
    b       3f
2:  mov     x0, #0
3:  ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// same: do two of our blocks hold the same bytes -> x0 1 or 0. Uses x2-x6.
same:
    ldr     x2, [x0, #16]
    ldr     x3, [x1, #16]
    cmp     x2, x3
    b.ne    2f
    mov     x4, #64
1:  cmp     x4, x2
    b.hs    3f
    ldrb    w5, [x0, x4]
    ldrb    w6, [x1, x4]
    add     x4, x4, #1
    cmp     w5, w6
    b.eq    1b
2:  mov     x0, #0
    ret
3:  mov     x0, #1
    ret
// check: is the digest x2 signed by the key of the certificate x0, the signature being x3 (and x4)? x1 says how: 1 RSA the older
// way, 2 RSA-PSS, 3 ECDSA. -> x0 1 yes, 0 no, -1 cannot tell
check:
    stp     x29, x30, [sp, #-64]!
    stp     x23, x24, [sp, #16]
    stp     x25, x26, [sp, #32]
    stp     x27, x28, [sp, #48]
    mov     x24, x0
    mov     x25, x1
    mov     x26, x2
    mov     x27, x3
    mov     x28, x4
    mov     x1, #1
    bl      fact
    mov     x23, x0
    mov     x0, x24
    mov     x1, #4
    ADDR    x2, KA
    mov     x3, #704
    bl      part
    tbnz    x0, #63, k_cannot
    mov     x0, x24
    mov     x1, #5
    ADDR    x2, KB
    mov     x3, #704
    bl      part
    tbnz    x0, #63, k_cannot
    ADDR    x9, KA
    str     x9, [x19, #M1]
    ADDR    x9, KB
    str     x9, [x19, #M2]
    str     x27, [x19, #M3]
    str     x28, [x19, #M4]
    str     x26, [x19, #M5]
    mov     x0, #0
    add     x1, x19, #Q
    mov     x3, #0
    cmp     x25, #2
    b.hi    k_ec
    cmp     x23, #1
    b.ne    k_no
    mov     w9, #1
    strh    w9, [x19, #Q]
    mov     w9, #2
    strh    w9, [x19, #(Q + 2)]
    mov     w9, #3
    strh    w9, [x19, #(Q + 4)]
    mov     w9, #5
    strh    w9, [x19, #(Q + 6)]
    mov     x2, #4
    cmp     x25, #1
    b.ne    1f
    SOCKET  26
    b       k_out
1:  SOCKET  27
    b       k_out
k_ec:
    mov     w9, #256
    cmp     x23, #2
    b.eq    2f
    mov     w9, #384
    cmp     x23, #3
    b.ne    k_no
2:  strh    w9, [x19, #Q]
    mov     w9, #1
    strh    w9, [x19, #(Q + 2)]
    mov     w9, #2
    strh    w9, [x19, #(Q + 4)]
    mov     w9, #3
    strh    w9, [x19, #(Q + 6)]
    mov     w9, #4
    strh    w9, [x19, #(Q + 8)]
    mov     w9, #5
    strh    w9, [x19, #(Q + 10)]
    mov     x2, #6
    SOCKET  28
    b       k_out
k_no:
    mov     x0, #0
    b       k_out
k_cannot:
    mov     x0, #-1
k_out:
    ldp     x23, x24, [sp, #16]
    ldp     x25, x26, [sp, #32]
    ldp     x27, x28, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret
// signed_by: did the certificate x1 sign the certificate x0? The child must name the parent as its issuer, and its signature must
// verify under the parent's key. -> x0 1 or 0
    .macro  PART cert, which, blk, room, fail
    mov     x0, \cert
    mov     x1, #\which
    ADDR    x2, \blk
    mov     x3, #\room
    bl      part
    tbnz    x0, #63, \fail
    .endm
signed_by:
    stp     x29, x30, [sp, #-48]!
    stp     x25, x26, [sp, #16]
    stp     x27, x28, [sp, #32]
    mov     x27, x0
    mov     x28, x1
    PART    x27, 6, SI, 704, s_no
    PART    x28, 7, SS, 704, s_no
    ADDR    x0, SI
    ADDR    x1, SS
    bl      same
    cbz     x0, s_no
    mov     x0, x27
    mov     x1, #0
    bl      fact
    mov     x26, x0
    cmp     x26, #1
    b.lt    s_no
    cmp     x26, #6
    b.gt    s_no
    PART    x27, 0, TBS, 8192, s_no
    mov     x0, #32
    cmp     x26, #1
    b.eq    1f
    cmp     x26, #4
    b.eq    1f
    mov     x0, #48
    cmp     x26, #2
    b.eq    1f
    cmp     x26, #5
    b.eq    1f
    mov     x0, #64
1:  ADDR    x1, TBS
    ADDR    x2, DG
    bl      digest
    cbz     x0, s_no
    cmp     x26, #3
    b.gt    2f
    PART    x27, 1, SA, 704, s_no
    mov     x0, x28
    mov     x1, #1
    ADDR    x2, DG
    ADDR    x3, SA
    mov     x4, x3
    bl      check
    b       3f
2:  PART    x27, 2, SA, 704, s_no
    PART    x27, 3, SB, 704, s_no
    mov     x0, x28
    mov     x1, #3
    ADDR    x2, DG
    ADDR    x3, SA
    ADDR    x4, SB
    bl      check
3:  cmp     x0, #1
    cset    x0, eq
    b       s_out
s_no:
    mov     x0, #0
s_out:
    ldp     x25, x26, [sp, #16]
    ldp     x27, x28, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret
// in_date: is the certificate x0 in date at the time x21 -> x0 1 or 0
in_date:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    mov     x27, x0
    mov     x1, #3
    bl      fact
    mov     x28, x0
    mov     x0, x27
    mov     x1, #4
    bl      fact
    mov     x1, x0
    mov     x0, #0
    tbnz    x28, #63, 1f
    tbnz    x1, #63, 1f
    cmp     x21, x28
    b.lt    1f
    cmp     x21, x1
    b.gt    1f
    mov     x0, #1
1:  ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// block_of: the block at the handle x0 on the real table, or 0
block_of:
    cmp     x0, #0
    b.lt    1f
    cmp     x0, #255
    b.gt    1f
    add     x0, x0, #256
    ldr     x0, [x20, x0, lsl #3]
    ret
1:  mov     x0, #0
    ret

    .macro  ENTER
    mov     x9, #FRAME
    sub     sp, sp, x9
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, sp
    mov     x20, x4
    mov     x21, x3
    mov     x22, x1
    mov     x23, x2
    ADDR    x9, MINE                    // this piece's own table: the real sockets, and no handles yet
    mov     x10, #0
77: ldr     x11, [x20, x10, lsl #3]
    cmp     x10, #256
    csel    x11, x11, xzr, lo
    str     x11, [x9, x10, lsl #3]
    add     x10, x10, #1
    cmp     x10, #512
    b.lo    77b
    .endm
    .macro  LEAVE
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    mov     x9, #FRAME
    add     sp, sp, x9
    ret
    .endm
    .macro  FACT cert, which
    mov     x0, \cert
    mov     x1, #\which
    bl      fact
    .endm

chain:
    ENTER
    cmp     x23, #3
    b.lt    c_unusable
    cmp     x23, #10
    b.gt    c_unusable
    ldrsh   x0, [x22]
    bl      block_of
    cbz     x0, c_unusable
    mov     x24, x0                     // the site name
    ldrsh   x0, [x22, #2]
    bl      block_of
    cbz     x0, c_unusable
    mov     x25, x0                     // the roots
    ldr     w9, [x25]
    cmp     w9, #2
    b.ne    c_unusable
    ldr     x9, [x25, #16]
    cmp     x9, #64
    b.lo    c_unusable
    str     x25, [x19, #ROOTS]
    sub     x23, x23, #2                // how many certificates were sent
    mov     x26, #0
1:  add     x9, x26, #2
    ldrsh   x0, [x22, x9, lsl #1]
    bl      block_of
    cbz     x0, c_unusable
    add     x9, x19, #SENT
    str     x0, [x9, x26, lsl #3]
    mov     x1, #8
    bl      fact
    tbnz    x0, #63, c_unusable
    add     x26, x26, #1
    cmp     x26, x23
    b.lt    1b
    mov     x9, #1
    str     x9, [x19, #USED]            // eight marks, the first one set
    ldr     x22, [x19, #SENT]           // from here x22 is the site's own certificate
    str     x22, [x19, #M1]
    str     x24, [x19, #M2]
    mov     w9, #1
    strh    w9, [x19, #Q]
    mov     w9, #2
    strh    w9, [x19, #(Q + 2)]
    mov     x0, #0
    add     x1, x19, #Q
    mov     x2, #2
    mov     x3, #0
    SOCKET  25
    tbnz    x0, #63, c_unusable
    cbz     x0, c_name
    mov     x0, x22
    bl      in_date
    cbz     x0, c_date
    FACT    x22, 7
    cbnz    x0, c_use
    FACT    x22, 6
    tbnz    x0, #63, 2f
    tbz     x0, #7, c_use
2:  mov     x24, x22                    // the certificate whose signer is being looked for
    mov     x25, #0                     // how many authorities are beneath the next one
    mov     x26, #0                     // steps taken
c_step:
    PART    x24, 6, CI, 704, c_unusable
    ldr     x27, [x19, #ROOTS]
    ldr     x28, [x27, #16]
    sub     x28, x28, #64
    add     x27, x27, #64
c_root:                                 // a trusted root that signed it ends the search
    cmp     x28, #4
    b.ls    c_sent
    ldrb    w9, [x27]
    cmp     w9, #0x30
    b.ne    c_sent
    ldrb    w9, [x27, #1]
    cmp     w9, #0x80
    b.hs    1f
    add     x10, x9, #2
    b       3f
1:  cmp     w9, #0x81
    b.ne    2f
    ldrb    w10, [x27, #2]
    add     x10, x10, #3
    b       3f
2:  cmp     w9, #0x82
    b.ne    c_sent
    ldrb    w10, [x27, #2]
    ldrb    w11, [x27, #3]
    orr     x10, x11, x10, lsl #8
    add     x10, x10, #4
3:  cmp     x10, x28
    b.hi    c_sent
    str     x10, [x19, #LEN]
    cmp     x10, #8192
    b.hi    c_root_next
    ADDR    x0, ROOT
    mov     x1, x10
    bl      head
    ADDR    x0, ROOT
    add     x0, x0, #64
    ldr     x10, [x19, #LEN]
    mov     x11, #0
4:  ldrb    w12, [x27, x11]
    strb    w12, [x0, x11]
    add     x11, x11, #1
    cmp     x11, x10
    b.lo    4b
    ADDR    x22, ROOT
    PART    x22, 7, CS, 704, c_root_next
    ADDR    x0, CI
    ADDR    x1, CS
    bl      same
    cbz     x0, c_root_next
    mov     x0, x22
    bl      in_date
    cbz     x0, c_root_next
    FACT    x22, 5                      // a root's own limit on authorities beneath it
    tbnz    x0, #63, 5f
    cmp     x0, x25
    b.lt    c_root_next
5:  mov     x0, x24
    mov     x1, x22
    bl      signed_by
    cbnz    x0, c_yes
c_root_next:
    ldr     x10, [x19, #LEN]
    add     x27, x27, x10
    sub     x28, x28, x10
    b       c_root
c_sent:                                 // otherwise one of the certificates sent must have signed it, and must be allowed to
    mov     x27, #1
1:  cmp     x27, x23
    b.ge    c_path
    add     x9, x19, #USED
    ldrb    w9, [x9, x27]
    cbnz    w9, 2f
    add     x9, x19, #SENT
    ldr     x1, [x9, x27, lsl #3]
    mov     x0, x24
    bl      signed_by
    cbnz    x0, 3f
2:  add     x27, x27, #1
    b       1b
3:  add     x9, x19, #USED
    mov     w10, #1
    strb    w10, [x9, x27]
    add     x9, x19, #SENT
    ldr     x27, [x9, x27, lsl #3]      // the one above
    mov     x0, x27
    bl      in_date
    cbz     x0, c_date
    FACT    x27, 2
    cmp     x0, #1
    b.ne    c_use
    FACT    x27, 7
    cbnz    x0, c_use
    FACT    x27, 6
    tbnz    x0, #63, 4f
    tbz     x0, #2, c_use
4:  FACT    x27, 5
    tbnz    x0, #63, 5f
    cmp     x0, x25
    b.lt    c_use
5:  add     x25, x25, #1
    mov     x24, x27
    add     x26, x26, #1
    cmp     x26, #8
    b.lt    c_step
c_path:
    mov     x0, #-5
    b       c_out
c_yes:
    mov     x0, #1
    b       c_out
c_name:
    mov     x0, #-2
    b       c_out
c_date:
    mov     x0, #-3
    b       c_out
c_use:
    mov     x0, #-4
    b       c_out
c_unusable:
    mov     x0, #-1
c_out:
    LEAVE

signed_handshake:
    ENTER
    mov     x0, #-1
    cmp     x23, #0
    b.le    1f
    ldrsh   x0, [x22]
1:  bl      block_of
    cbz     x0, h_unusable
    mov     x24, x0                     // the certificate
    mov     x25, #0
    cmp     x23, #1
    b.le    2f
    ldrsh   x25, [x22, #2]              // the scheme
2:  mov     x0, #-1
    cmp     x23, #2
    b.le    3f
    ldrsh   x0, [x22, #4]
3:  bl      block_of
    cbz     x0, h_unusable
    mov     x26, x0                     // what was signed
    ldr     w9, [x26]
    cmp     w9, #2
    b.ne    h_unusable
    mov     x0, #-1
    cmp     x23, #3
    b.le    4f
    ldrsh   x0, [x22, #6]
4:  bl      block_of
    cbz     x0, h_unusable
    mov     x27, x0                     // the signature
    ldr     w9, [x27]
    cmp     w9, #2
    b.ne    h_unusable
    ldr     x28, [x27, #16]
    cmp     x28, #64
    b.ls    h_unusable
    cmp     x28, #(64 + 600)
    b.hi    h_unusable
    sub     x28, x28, #64
    FACT    x24, 1
    tbnz    x0, #63, h_unusable
    mov     x23, x0                     // the kind of key
    cmp     x25, #0x0804
    b.ne    h_ec
    cmp     x23, #1
    b.ne    h_no
    mov     x0, #32
    mov     x1, x26
    ADDR    x2, DG
    bl      digest
    cbz     x0, h_unusable
    mov     x0, x24
    mov     x1, #2
    ADDR    x2, DG
    mov     x3, x27
    mov     x4, x27
    bl      check
    b       h_out
h_ec:
    mov     x0, #32
    cmp     x25, #0x0403
    b.ne    1f
    cmp     x23, #2
    b.eq    2f
    b       h_no
1:  mov     x0, #48
    cmp     x25, #0x0503
    b.ne    h_unusable
    cmp     x23, #3
    b.ne    h_no
2:  mov     x1, x26
    ADDR    x2, DG
    bl      digest
    cbz     x0, h_unusable
    add     x26, x27, #64               // the signature's bytes: a box holding two whole numbers
    cmp     x28, #8
    b.lo    h_no
    ldrb    w9, [x26]
    cmp     w9, #0x30
    b.ne    h_no
    ldrb    w9, [x26, #1]
    mov     x22, #2                     // where we are in it
    tbz     w9, #7, 3f
    cmp     w9, #0x81
    b.ne    h_no
    mov     x22, #3
    ldrb    w9, [x26, #2]
    add     x9, x9, #3
    b       4f
3:  add     x9, x9, #2
4:  cmp     x9, x28
    b.ne    h_no
    ADDR    x25, SA
5:  add     x9, x22, #2
    cmp     x9, x28
    b.hi    h_no
    ldrb    w10, [x26, x22]
    cmp     w10, #2
    b.ne    h_no
    add     x10, x22, #1
    ldrb    w1, [x26, x10]
    mov     x22, x9
    cbz     x1, h_no
    cmp     x1, #80
    b.hi    h_no
    add     x9, x22, x1
    cmp     x9, x28
    b.hi    h_no
    mov     x0, x25
    bl      head
    add     x10, x25, #64
    add     x11, x26, x22
    mov     x12, #0
6:  ldrb    w13, [x11, x12]
    strb    w13, [x10, x12]
    add     x12, x12, #1
    cmp     x12, x1
    b.lo    6b
    add     x22, x22, x1
    ADDR    x9, SB
    cmp     x25, x9
    b.eq    7f
    mov     x25, x9
    b       5b
7:  cmp     x22, x28
    b.ne    h_no
    mov     x0, x24
    mov     x1, #3
    ADDR    x2, DG
    ADDR    x3, SA
    ADDR    x4, SB
    bl      check
    b       h_out
h_no:
    mov     x0, #0
    b       h_out
h_unusable:
    mov     x0, #-1
h_out:
    LEAVE
