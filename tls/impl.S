// tls, written by hand (ARM64): a TLS 1.3 client, as a state machine. The meaning is tls/intent.md; the recorded checks are the
// judge, and they compare every byte of the state after every call. Entries: x0 the state, x1 numbers (16-bit), x2 how many,
// x3 argument, x4 call table. It decides nothing by arithmetic of its own: hash (sockets 14-16), seal (17, 18), exchange (19, 20),
// trust (29, 30) and aesgcm (34, 35) do that. Through an entry: x19 the state, x20 the real call table, x21 the frame, which holds
// one call table of this piece's own (the real sockets, copied once) and the blocks handed to other pieces.
    .text
    .global migrate
    .global begin
    .global feed
    .global send
    .global reset
    // the state, as its description lays it out
    .equ ST_stage, 4
    .equ ST_out_len, 8
    .equ ST_plain_len, 12
    .equ ST_size, 16
    .equ ST_used, 24
    .equ ST_unverified, 28
    .equ ST_alert, 32
    .equ ST_certificate_at, 36
    .equ ST_certificate_len, 40
    .equ ST_trust, 44
    .equ ST_suite, 48
    .equ ST_offer, 52
    .equ ST_secret, 72
    .equ ST_c_hs, 104
    .equ ST_s_hs, 136
    .equ ST_master, 168
    .equ ST_rkey, 200
    .equ ST_wkey, 232
    .equ ST_riv, 264
    .equ ST_wiv, 276
    .equ ST_rseq, 288
    .equ ST_wseq, 296
    .equ ST_tn, 304
    .equ ST_hn, 308
    .equ ST_name_len, 312
    .equ ST_certs, 316
    .equ ST_cert_at, 320
    .equ ST_cert_len, 352
    .equ ST_name, 384
    .equ ST_transcript_head, 640
    .equ ST_transcript, 704
    .equ ST_hs, 33472
    .equ ST_in_head, 66240
    .equ ST_in, 66304
    .equ ST_out_head, 83200
    .equ ST_out, 83264
    .equ ST_SIZE, 100160
    .equ TRANSCRIPT, 32768
    .equ RECORD, 16384
    // the frame
    .equ Q, 96
    .equ NO, 120
    .equ F_LEN, 192
    .equ F_BN, 196
    .equ F_BODY, 200
    .equ ZEROS, 208
    .equ EARLY, 240
    .equ EMPTY, 272
    .equ DERIVED, 304
    .equ HSK, 336
    .equ TH, 368
    .equ FK, 400
    .equ WANT, 432
    .equ MINE36, 464
    .equ CAP, 504
    .equ SAP, 536
    .equ H5, 568
    .equ SM_O, 576
    .equ SM_A, 960
    .equ SM_B, 1344
    .equ SM_C, 1728
    .equ SM_SH, 2112
    .equ CONTENT, 2496
    .equ SIG, 3264
    .equ MINE, 4032
    .equ M1, MINE + 257 * 8
    .equ M2, MINE + 258 * 8
    .equ M3, MINE + 259 * 8
    .equ M4, MINE + 260 * 8
    .equ FRAME, 8128
    // ST: the address of a part of the state
    .macro  ST reg, off
    ldr     \reg, =\off
    add     \reg, x19, \reg
    .endm
    // SOCKET: calls another piece: x0 its block, x2 how many numbers (they are at Q); the argument is 0
    .macro  SOCKET slot
    add     x1, x21, #Q
    mov     x3, #0
    add     x4, x21, #MINE
    ldr     x9, [x20, #(\slot * 8)]
    blr     x9
    .endm
    .macro  SETQ i, value
    mov     w9, #\value
    strh    w9, [x21, #(Q + 2 * \i)]
    .endm
    .macro  COPY32 to, from
    ldp     x15, x16, [\from]
    stp     x15, x16, [\to]
    ldp     x15, x16, [\from, #16]
    stp     x15, x16, [\to, #16]
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
// put: the block of this piece's own at x0 comes to hold the x2 bytes at x1 (the first 320 of them). Uses x10-x12, x17.
put:
    mov     x17, x30
    mov     x10, x1
    mov     x11, x2
    mov     x1, x2
    bl      head
    cmp     x11, #320
    mov     x12, #320
    csel    x11, x12, x11, hi
    add     x0, x0, #64
    cbz     x11, 2f
1:  ldrb    w12, [x10], #1
    strb    w12, [x0], #1
    subs    x11, x11, #1
    b.ne    1b
2:  ret     x17
// hash_transcript: the SHA-256 of everything said so far, to x0 -> x0 1 or 0
hash_transcript:
    stp     x29, x30, [sp, #-32]!
    str     x28, [sp, #16]
    mov     x28, x0
    add     x0, x21, #SM_O
    mov     x1, #320
    bl      head
    add     x0, x19, #ST_transcript_head
    ldr     w1, [x19, #ST_tn]
    bl      head
    add     x9, x19, #ST_transcript_head
    str     x9, [x21, #M1]
    SETQ    0, 1
    add     x0, x21, #SM_O
    mov     x2, #1
    SOCKET  14
    cmp     x0, #32
    b.ne    1f
    add     x11, x21, #(SM_O + 64)
    COPY32  x28, x11
    mov     x0, #1
    b       2f
1:  mov     x0, #0
2:  ldr     x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// hmac: the keyed hash of the x2 bytes at x1 under the 32-byte key at x0, to x3 -> x0 1 or 0
hmac:
    stp     x29, x30, [sp, #-48]!
    stp     x25, x26, [sp, #16]
    stp     x27, x28, [sp, #32]
    mov     x25, x0
    mov     x26, x1
    mov     x27, x2
    mov     x28, x3
    add     x0, x21, #SM_O
    mov     x1, #320
    bl      head
    add     x0, x21, #SM_A
    mov     x1, x25
    mov     x2, #32
    bl      put
    add     x0, x21, #SM_B
    mov     x1, x26
    mov     x2, x27
    bl      put
    add     x9, x21, #SM_A
    str     x9, [x21, #M1]
    add     x9, x21, #SM_B
    str     x9, [x21, #M2]
    SETQ    0, 1
    SETQ    1, 2
    add     x0, x21, #SM_O
    mov     x2, #2
    SOCKET  15
    cmp     x0, #32
    b.ne    1f
    add     x11, x21, #(SM_O + 64)
    COPY32  x28, x11
    mov     x0, #1
    b       2f
1:  mov     x0, #0
2:  ldp     x25, x26, [sp, #16]
    ldp     x27, x28, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret
// expand: x4 bytes derived from the 32-byte secret at x0 under the label at x1 (ending in a zero byte) and the x3 bytes of
// context at x2, to x5 -> x0 1 or 0
expand:
    stp     x29, x30, [sp, #-64]!
    stp     x24, x25, [sp, #16]
    stp     x26, x27, [sp, #32]
    str     x28, [sp, #48]
    mov     x24, x1
    mov     x25, x2
    mov     x26, x3
    mov     x27, x4
    mov     x28, x5
    mov     x13, x0
    add     x0, x21, #SM_O
    mov     x1, #320
    bl      head
    add     x0, x21, #SM_A
    mov     x1, x13
    mov     x2, #32
    bl      put
    mov     x2, #0
1:  ldrb    w9, [x24, x2]
    cbz     w9, 2f
    add     x2, x2, #1
    b       1b
2:  add     x0, x21, #SM_B
    mov     x1, x24
    bl      put
    add     x0, x21, #SM_C
    mov     x1, x25
    mov     x2, x26
    bl      put
    add     x9, x21, #SM_A
    str     x9, [x21, #M1]
    add     x9, x21, #SM_B
    str     x9, [x21, #M2]
    add     x9, x21, #SM_C
    str     x9, [x21, #M3]
    SETQ    0, 1
    SETQ    1, 2
    SETQ    2, 3
    strh    w27, [x21, #(Q + 6)]
    add     x0, x21, #SM_O
    mov     x2, #4
    SOCKET  16
    cmp     x0, x27
    b.ne    4f
    add     x11, x21, #(SM_O + 64)
    mov     x9, #0
3:  cmp     x9, x27
    b.ge    5f
    ldrb    w10, [x11, x9]
    strb    w10, [x28, x9]
    add     x9, x9, #1
    b       3b
5:  mov     x0, #1
    b       6f
4:  mov     x0, #0
6:  ldp     x24, x25, [sp, #16]
    ldp     x26, x27, [sp, #32]
    ldr     x28, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret
// traffic: the key (to x1) and the iv (to x2) for one direction, from its secret at x0 -> x0 1 or 0
traffic:
    stp     x29, x30, [sp, #-32]!
    stp     x27, x28, [sp, #16]
    mov     x27, x0
    mov     x28, x2
    mov     x5, x1
    adr     x1, l_key
    mov     x2, #0
    mov     x3, #0
    mov     x4, #32
    ldr     w9, [x19, #ST_suite]
    cmp     w9, #2
    mov     x10, #16
    csel    x4, x10, x4, eq
    bl      expand
    cbz     x0, 1f
    mov     x0, x27
    adr     x1, l_iv
    mov     x2, #0
    mov     x3, #0
    mov     x4, #12
    mov     x5, x28
    bl      expand
1:  ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// crypt: one record sealed (w0 = 1) or opened (0) in the state's working blocks: x1 the key, x2 the iv, x3 the record count
// (folded into the iv's end to make the nonce), x4 the record's five-byte header, x5 how many bytes are in the state's "in"
crypt:
    stp     x29, x30, [sp, #-48]!
    stp     x25, x26, [sp, #16]
    stp     x27, x28, [sp, #32]
    mov     x25, x0
    mov     x26, x5
    mov     x27, x4
    ldr     x9, [x2]
    ldr     w10, [x2, #8]
    str     x9, [x21, #NO]
    str     w10, [x21, #(NO + 8)]
    ldur    x9, [x21, #(NO + 4)]
    rev     x10, x3
    eor     x9, x9, x10
    stur    x9, [x21, #(NO + 4)]
    add     x0, x21, #SM_A
    mov     x2, #32
    ldr     w9, [x19, #ST_suite]
    cmp     w9, #2
    mov     x10, #16
    csel    x2, x10, x2, eq
    bl      put
    add     x0, x21, #SM_B
    add     x1, x21, #NO
    mov     x2, #12
    bl      put
    add     x0, x21, #SM_C
    mov     x1, x27
    mov     x2, #5
    bl      put
    ST      x0, ST_in_head
    mov     x28, x0
    mov     x1, x26
    bl      head
    ST      x0, ST_out_head
    mov     x1, #(RECORD + 512)
    bl      head
    add     x9, x21, #SM_A
    str     x9, [x21, #M1]
    add     x9, x21, #SM_B
    str     x9, [x21, #M2]
    add     x9, x21, #SM_C
    str     x9, [x21, #M3]
    str     x28, [x21, #M4]
    SETQ    0, 1
    SETQ    1, 2
    SETQ    2, 3
    SETQ    3, 4
    ldr     w9, [x19, #ST_suite]        // which piece: by the cipher the server chose, and the direction
    mov     x10, #(18 * 8)
    mov     x11, #(17 * 8)
    cmp     x25, #0
    csel    x10, x11, x10, ne
    mov     x11, #(35 * 8)
    mov     x12, #(34 * 8)
    csel    x11, x12, x11, ne
    cmp     w9, #2
    csel    x10, x11, x10, eq
    ldr     x9, [x20, x10]
    ST      x0, ST_out_head
    add     x1, x21, #Q
    mov     x2, #4
    mov     x3, #0
    add     x4, x21, #MINE
    blr     x9
    ldp     x25, x26, [sp, #16]
    ldp     x27, x28, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret
// add_transcript: the x1 bytes at x0 join everything said so far -> x0 1, or 0 if there is no room. Uses x9-x12.
add_transcript:
    ldr     w9, [x19, #ST_tn]
    add     x10, x9, x1
    cmp     x10, #TRANSCRIPT
    b.hi    3f
    add     x11, x19, #ST_transcript
    add     x11, x11, x9
    cbz     x1, 2f
1:  ldrb    w12, [x0], #1
    strb    w12, [x11], #1
    subs    x1, x1, #1
    b.ne    1b
2:  str     w10, [x19, #ST_tn]
    mov     x0, #1
    ret
3:  mov     x0, #0
    ret
// fresh: the state as a new one
fresh:
    mov     x9, x0
    mov     x10, #(ST_SIZE / 8)
1:  str     xzr, [x9], #8
    subs    x10, x10, #1
    b.ne    1b
    mov     w9, #1
    str     w9, [x0]
    ldr     x9, =ST_SIZE
    str     x9, [x0, #ST_size]
    mov     x0, #1
    ret
migrate:
    b       fresh
reset:                                  // start over on the same block, for a new connection
    b       fresh

    .macro  ENTER
    sub     sp, sp, #4064
    sub     sp, sp, #(FRAME - 4064)
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, x0
    mov     x20, x4
    mov     x21, sp
    add     x9, x21, #MINE              // this piece's own table: the real sockets, and no handles yet
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
    add     sp, sp, #4064
    add     sp, sp, #(FRAME - 4064)
    ret
    .endm
// BLOCK: the block at the handle in number \i (numbers x1, count x2) -> \reg, or 0. Uses x9.
    .macro  BLOCK reg, i
    mov     \reg, #0
    cmp     x2, #\i
    b.le    60f
    ldrsh   x9, [x1, #(\i * 2)]
    cmp     x9, #0
    b.lt    60f
    cmp     x9, #255
    b.gt    60f
    add     x9, x9, #256
    ldr     \reg, [x20, x9, lsl #3]
60:
    .endm
    .macro  FAIL why, exit
    mov     w9, #5
    str     w9, [x19, #ST_stage]
    mov     w9, #\why
    str     w9, [x19, #ST_alert]
    mov     x0, #-1
    b       \exit
    .endm
    // PUTB: one byte of the greeting, at its running position x25 in x26
    .macro  PUTB value
    mov     w9, #\value
    strb    w9, [x26, x25]
    add     x25, x25, #1
    .endm
    .macro  PUTR reg
    strb    \reg, [x26, x25]
    add     x25, x25, #1
    .endm

// begin: the opening message. Numbers: the seed's handle (96 fresh random bytes: 32 for the hello, 32 the exchange secret, 32 a
// session label), the site name's, where the bytes to send go, and optionally which ciphers to offer.
begin:
    ENTER
    BLOCK   x22, 0
    BLOCK   x23, 1
    BLOCK   x24, 2
    mov     x28, #0
    cmp     x2, #3
    b.le    1f
    ldrsh   x28, [x1, #6]
1:  ldr     w9, [x19]
    cmp     w9, #1
    b.ne    b_bad
    ldr     w9, [x19, #ST_stage]
    cbnz    w9, b_bad
    cbz     x22, b_bad
    ldr     w9, [x22]
    cmp     w9, #2
    b.ne    b_bad
    ldr     x9, [x22, #16]
    cmp     x9, #(64 + 96)
    b.ne    b_bad
    cbz     x23, b_bad
    ldr     w9, [x23]
    cmp     w9, #2
    b.ne    b_bad
    ldr     x27, [x23, #16]
    cmp     x27, #65
    b.lo    b_bad
    cmp     x27, #(64 + 253)
    b.hi    b_bad
    cbz     x24, b_bad
    ldr     w9, [x24]
    cmp     w9, #2
    b.eq    2f
    cmp     w9, #5
    b.ne    b_bad
2:  ldr     x9, [x24, #16]
    cmp     x9, #(64 + 512)
    b.lo    b_bad
    sub     x27, x27, #64               // the name's length
    add     x9, x22, #(64 + 32)
    add     x10, x19, #ST_secret
    COPY32  x10, x9
    str     w27, [x19, #ST_name_len]
    add     x10, x19, #ST_name
    mov     x11, #0
3:  add     x12, x23, #64
    ldrb    w12, [x12, x11]
    strb    w12, [x10, x11]
    add     x11, x11, #1
    cmp     x11, x27
    b.lo    3b
    add     x0, x21, #SM_O              // our half of the exchange, from the secret
    mov     x1, #320
    bl      head
    add     x0, x21, #SM_A
    add     x1, x19, #ST_secret
    mov     x2, #32
    bl      put
    add     x9, x21, #SM_A
    str     x9, [x21, #M1]
    SETQ    0, 1
    add     x0, x21, #SM_O
    mov     x2, #1
    SOCKET  19
    cmp     x0, #32
    b.eq    4f
    FAIL    1, b_out
4:  add     x26, x19, #ST_transcript    // the greeting is the first thing said
    mov     x25, #4
    PUTB    3
    PUTB    3
    mov     x11, #0
5:  add     x12, x22, #64
    ldrb    w12, [x12, x11]
    PUTR    w12
    add     x11, x11, #1
    cmp     x11, #32
    b.lo    5b
    PUTB    32
    mov     x11, #0
6:  add     x12, x22, #(64 + 64)
    ldrb    w12, [x12, x11]
    PUTR    w12
    add     x11, x11, #1
    cmp     x11, #32
    b.lo    6b
    cmp     x28, #0                     // 0 both ciphers, 1 only ChaCha20-Poly1305, 2 only AES-128-GCM
    b.lt    b_bad
    cmp     x28, #2
    b.gt    b_bad
    PUTB    0
    mov     w9, #4
    mov     w10, #2
    cmp     x28, #0
    csel    w9, w10, w9, ne
    PUTR    w9
    cmp     x28, #2
    b.eq    7f
    PUTB    0x13
    PUTB    0x03
7:  cmp     x28, #1
    b.eq    8f
    PUTB    0x13
    PUTB    0x01
8:  PUTB    1
    PUTB    0
    str     w28, [x19, #ST_offer]
    mov     x28, x25                    // where the extensions' length goes
    add     x25, x25, #2
    PUTB    0                           // the name asked for
    PUTB    0
    add     x10, x27, #5
    lsr     w9, w10, #8
    PUTR    w9
    PUTR    w10
    add     x10, x27, #3
    lsr     w9, w10, #8
    PUTR    w9
    PUTR    w10
    PUTB    0
    lsr     w9, w27, #8
    PUTR    w9
    PUTR    w27
    mov     x11, #0
9:  add     x12, x23, #64
    ldrb    w12, [x12, x11]
    PUTR    w12
    add     x11, x11, #1
    cmp     x11, x27
    b.lo    9b
    adr     x10, l_fixed                // TLS 1.3; X25519; signature kinds; our key share
    mov     x11, #0
10: ldrb    w12, [x10, x11]
    PUTR    w12
    add     x11, x11, #1
    cmp     x11, #37
    b.lo    10b
    add     x10, x21, #(SM_O + 64)
    mov     x11, #0
11: ldrb    w12, [x10, x11]
    PUTR    w12
    add     x11, x11, #1
    cmp     x11, #32
    b.lo    11b
    sub     x10, x25, x28
    sub     x10, x10, #2
    lsr     w9, w10, #8
    strb    w9, [x26, x28]
    add     x28, x28, #1
    strb    w10, [x26, x28]
    mov     w9, #1
    strb    w9, [x26]
    strb    wzr, [x26, #1]
    sub     x10, x25, #4
    lsr     w9, w10, #8
    strb    w9, [x26, #2]
    strb    w10, [x26, #3]
    str     w25, [x19, #ST_tn]
    add     x10, x24, #64               // and it goes out as one record
    mov     w9, #22
    strb    w9, [x10]
    mov     w9, #3
    strb    w9, [x10, #1]
    mov     w9, #1
    strb    w9, [x10, #2]
    lsr     w9, w25, #8
    strb    w9, [x10, #3]
    strb    w25, [x10, #4]
    add     x10, x10, #5
    mov     x11, #0
12: ldrb    w12, [x26, x11]
    strb    w12, [x10, x11]
    add     x11, x11, #1
    cmp     x11, x25
    b.lo    12b
    mov     w9, #1
    str     w9, [x19, #ST_stage]
    str     w9, [x19, #ST_unverified]
    add     x0, x25, #5
    str     w0, [x19, #ST_out_len]
    b       b_out
b_bad:
    mov     x0, #-1
b_out:
    LEAVE
    .ltorg
l_key:      .asciz "key"
l_iv:       .asciz "iv"
l_derived:  .asciz "derived"
l_c_hs:     .asciz "c hs traffic"
l_s_hs:     .asciz "s hs traffic"
l_c_ap:     .asciz "c ap traffic"
l_s_ap:     .asciz "s ap traffic"
l_finished: .asciz "finished"
l_said:     .ascii "TLS 1.3, server CertificateVerify"
l_fixed:    .byte 0, 43, 0, 3, 2, 3, 4,   0, 10, 0, 4, 0, 2, 0, 29,   0, 13, 0, 8, 0, 6, 4, 3, 5, 3, 8, 4,   0, 51, 0, 38, 0, 36, 0, 29, 0, 32
    .balign 4

    .macro  PUSH7
    stp     x29, x30, [sp, #-80]!
    stp     x22, x23, [sp, #16]
    stp     x24, x25, [sp, #32]
    stp     x26, x27, [sp, #48]
    str     x28, [sp, #64]
    .endm
    .macro  POP7
    ldp     x22, x23, [sp, #16]
    ldp     x24, x25, [sp, #32]
    ldp     x26, x27, [sp, #48]
    ldr     x28, [sp, #64]
    ldp     x29, x30, [sp], #80
    ret
    .endm
    // EXPAND: secret, label, context (or 0), its length, how many bytes, where to -> on failure goes to \fail
    .macro  EXPAND secret_base, secret_off, label, ctx_off, cn, want, out_base, out_off, fail
    add     x0, \secret_base, #\secret_off
    adr     x1, \label
    .if \cn
    add     x2, x21, #\ctx_off
    .else
    mov     x2, #0
    .endif
    mov     x3, #\cn
    mov     x4, #\want
    add     x5, \out_base, #\out_off
    bl      expand
    cbz     x0, \fail
    .endm
    .macro  HMAC key_base, key_off, msg_base, msg_off, out_base, out_off, fail
    add     x0, \key_base, #\key_off
    add     x1, \msg_base, #\msg_off
    mov     x2, #32
    add     x3, \out_base, #\out_off
    bl      hmac
    cbz     x0, \fail
    .endm
    .macro  HASH off, fail
    add     x0, x21, #\off
    bl      hash_transcript
    cbz     x0, \fail
    .endm
// server_hello: the server's first message (x0, w1 bytes): its half of the exchange. From it and ours, the keys for the rest of
// the handshake -> x0 1 or 0
server_hello:
    PUSH7
    mov     x22, x0
    mov     w23, w1
    cmp     w23, #39
    b.lo    h_no
    ldrb    w9, [x22]
    cmp     w9, #2
    b.ne    h_no
    ldur    x9, [x22, #6]               // a request to start over with other settings: not handled
    ldr     x10, =0x11619ae574ad21cf
    cmp     x9, x10
    b.eq    h_no
    ldrb    w24, [x22, #38]             // the session label comes back; step over it
    add     w24, w24, #39
    add     w9, w24, #5
    cmp     w9, w23
    b.hi    h_no
    add     x10, x22, x24
    ldrb    w9, [x10]
    cmp     w9, #0x13
    b.ne    h_no
    ldrb    w11, [x10, #2]
    cbnz    w11, h_no
    ldrb    w9, [x10, #1]
    mov     w11, #1
    cmp     w9, #0x03
    b.eq    1f
    mov     w11, #2
    cmp     w9, #0x01
    b.ne    h_no
1:  str     w11, [x19, #ST_suite]
    ldr     w9, [x19, #ST_offer]        // the server must pick one we offered
    cbz     w9, 2f
    cmp     w9, w11
    b.ne    h_no
2:  add     w24, w24, #3
    add     x10, x22, x24
    ldrh    w25, [x10]
    rev16   w25, w25
    add     w24, w24, #2
    add     w25, w25, w24               // where its extensions end
    cmp     w25, w23
    b.hi    h_no
    mov     x26, #0                     // their half of the exchange, when found
    mov     x27, #0                     // whether it said TLS 1.3
3:  add     w9, w24, #4
    cmp     w9, w25
    b.hi    6f
    add     x10, x22, x24
    ldrh    w11, [x10]
    rev16   w11, w11
    ldrh    w12, [x10, #2]
    rev16   w12, w12
    mov     w24, w9
    add     w9, w24, w12
    cmp     w9, w25
    b.hi    h_no
    add     x10, x22, x24
    cmp     w11, #43
    b.ne    4f
    cmp     w12, #2
    b.ne    4f
    ldrh    w13, [x10]
    cmp     w13, #0x0403
    b.ne    4f
    mov     x27, #1
4:  cmp     w11, #51
    b.ne    5f
    cmp     w12, #36
    b.ne    5f
    ldr     w13, [x10]
    ldr     w14, =0x20001d00
    cmp     w13, w14
    b.ne    5f
    add     x26, x10, #4
5:  add     w24, w24, w12
    b       3b
6:  cbz     x27, h_no
    cbz     x26, h_no
    mov     x0, x22
    mov     w1, w23
    bl      add_transcript
    cbz     x0, h_no
    add     x0, x21, #SM_SH             // the shared secret, from our secret and their half
    mov     x1, #320
    bl      head
    add     x0, x21, #SM_A
    add     x1, x19, #ST_secret
    mov     x2, #32
    bl      put
    add     x0, x21, #SM_B
    mov     x1, x26
    mov     x2, #32
    bl      put
    add     x9, x21, #SM_A
    str     x9, [x21, #M1]
    add     x9, x21, #SM_B
    str     x9, [x21, #M2]
    SETQ    0, 1
    SETQ    1, 2
    add     x0, x21, #SM_SH
    mov     x2, #2
    SOCKET  20
    cmp     x0, #32
    b.ne    h_no
    stp     xzr, xzr, [x21, #ZEROS]
    stp     xzr, xzr, [x21, #(ZEROS + 16)]
    ldr     w28, [x19, #ST_tn]          // the hash of nothing, which the schedule uses as a label's context
    str     wzr, [x19, #ST_tn]
    HASH    EMPTY, h_no
    str     w28, [x19, #ST_tn]
    HMAC    x21, ZEROS, x21, ZEROS, x21, EARLY, h_no
    EXPAND  x21, EARLY, l_derived, EMPTY, 32, 32, x21, DERIVED, h_no
    HMAC    x21, DERIVED, x21, (SM_SH + 64), x21, HSK, h_no
    HASH    TH, h_no
    EXPAND  x21, HSK, l_c_hs, TH, 32, 32, x19, ST_c_hs, h_no
    EXPAND  x21, HSK, l_s_hs, TH, 32, 32, x19, ST_s_hs, h_no
    EXPAND  x21, HSK, l_derived, EMPTY, 32, 32, x21, DERIVED, h_no
    HMAC    x21, DERIVED, x21, ZEROS, x19, ST_master, h_no
    stp     xzr, xzr, [x19, #ST_secret]
    stp     xzr, xzr, [x19, #(ST_secret + 16)]
    add     x0, x19, #ST_s_hs
    add     x1, x19, #ST_rkey
    add     x2, x19, #ST_riv
    bl      traffic
    cbz     x0, h_no
    add     x0, x19, #ST_c_hs
    add     x1, x19, #ST_wkey
    add     x2, x19, #ST_wiv
    bl      traffic
    cbz     x0, h_no
    stp     xzr, xzr, [x19, #ST_rseq]
    mov     w9, #2
    str     w9, [x19, #ST_stage]
    mov     x0, #1
    b       h_out
h_no:
    mov     x0, #0
h_out:
    POP7
    .ltorg

// send_record: seals the w2 bytes at x1 as one record of inner kind w3 onto the bytes to send in the block x0 -> x0 1 or 0
send_record:
    PUSH7
    mov     x25, x0
    mov     w26, w2
    cmp     w26, #RECORD
    b.hi    r_no
    ldr     x9, [x25, #16]
    sub     x9, x9, #64
    ldr     w10, [x19, #ST_out_len]
    add     x10, x10, x26
    add     x10, x10, #22
    cmp     x9, x10
    b.lo    r_no
    add     w10, w26, #17               // the record's header, which is sealed in with it
    mov     w9, #23
    strb    w9, [x21, #H5]
    mov     w9, #3
    strb    w9, [x21, #(H5 + 1)]
    strb    w9, [x21, #(H5 + 2)]
    lsr     w9, w10, #8
    strb    w9, [x21, #(H5 + 3)]
    strb    w10, [x21, #(H5 + 4)]
    ST      x11, ST_in
    mov     x12, #0
1:  cmp     w12, w26
    b.hs    2f
    ldrb    w9, [x1, x12]
    strb    w9, [x11, x12]
    add     x12, x12, #1
    b       1b
2:  strb    w3, [x11, x26]
    mov     w0, #1
    add     x1, x19, #ST_wkey
    add     x2, x19, #ST_wiv
    ldr     x3, [x19, #ST_wseq]
    add     x9, x3, #1
    str     x9, [x19, #ST_wseq]
    add     x4, x21, #H5
    add     x5, x26, #1
    bl      crypt
    add     x9, x26, #17
    cmp     x0, x9
    b.ne    r_no
    ldr     w10, [x19, #ST_out_len]
    add     x11, x25, #64
    add     x11, x11, x10
    ldr     w12, [x21, #H5]
    str     w12, [x11]
    ldrb    w12, [x21, #(H5 + 4)]
    strb    w12, [x11, #4]
    add     x11, x11, #5
    ST      x12, ST_out
    mov     x13, #0
3:  ldrb    w14, [x12, x13]
    strb    w14, [x11, x13]
    add     x13, x13, #1
    cmp     x13, x9
    b.lo    3b
    add     w10, w10, w9
    add     w10, w10, #5
    str     w10, [x19, #ST_out_len]
    mov     x0, #1
    b       r_out
r_no:
    mov     x0, #0
r_out:
    POP7
    .ltorg

// BE24: three bytes at \at, most significant first -> \reg. Uses w16.
    .macro  BE24 reg, at
    ldrb    \reg, [\at]
    ldrb    w16, [\at, #1]
    orr     \reg, w16, \reg, lsl #8
    ldrb    w16, [\at, #2]
    orr     \reg, w16, \reg, lsl #8
    .endm
// certificate_list: the server's certificates, as it listed them in the message at x0 (w1 bytes): where each one lies in
// everything said so far, the message starting at w2 -> x0 1 or 0. Uses x9-x16.
certificate_list:
    cmp     w1, #8
    b.lo    9f
    ldrb    w9, [x0, #4]
    cbnz    w9, 9f
    add     x10, x0, #5
    BE24    w11, x10
    add     w11, w11, #8                // where the list ends
    cmp     w11, w1
    b.ne    9f
    str     wzr, [x19, #ST_certs]
    mov     w12, #8
1:  cmp     w12, w11
    b.hs    4f
    add     w9, w12, #3
    cmp     w9, w11
    b.hi    9f
    add     x10, x0, x12
    BE24    w13, x10
    mov     w12, w9
    cbz     w13, 9f
    add     w9, w12, w13
    add     w9, w9, #2
    cmp     w9, w11
    b.hi    9f
    ldr     w14, [x19, #ST_certs]
    cmp     w14, #8
    b.hs    2f
    add     x15, x19, #ST_cert_at
    add     w9, w2, w12
    str     w9, [x15, x14, lsl #2]
    add     x15, x19, #ST_cert_len
    str     w13, [x15, x14, lsl #2]
    add     w14, w14, #1
    str     w14, [x19, #ST_certs]
2:  add     w12, w12, w13
    add     x10, x0, x12
    ldrh    w9, [x10]
    rev16   w9, w9
    add     w12, w12, #2
    add     w12, w12, w9
    cmp     w12, w11
    b.hi    9f
    b       1b
4:  ldr     w9, [x19, #ST_certs]
    cmp     w9, #0
    cset    x0, ne
    ret
9:  mov     x0, #0
    ret

// who: is this who we asked for? The chain must lead to a trusted root (the block x2) for our name at the time x3, and the server
// must have signed the handshake so far with the certificate's key: its signature is the message at x0 (w1 bytes). Both are the
// trust piece's to decide. -> x0 1 yes; anything else no (the state's "trust" says why)
who:
    PUSH7
    mov     x22, x0
    mov     w23, w1
    mov     x24, x2
    mov     x25, x3
    cmp     w23, #8
    b.lo    w_no
    ldr     w9, [x19, #ST_certs]
    cbz     w9, w_no
    ldrh    w26, [x22, #4]
    rev16   w26, w26                    // the kind of signature
    ldrh    w27, [x22, #6]
    rev16   w27, w27                    // its length
    add     w9, w27, #8
    cmp     w9, w23
    b.ne    w_no
    cmp     w27, #600
    b.hi    w_no
    add     x0, x21, #SM_SH
    add     x1, x19, #ST_name
    ldr     w2, [x19, #ST_name_len]
    bl      put
    add     x9, x21, #SM_SH
    str     x9, [x21, #M1]
    str     x24, [x21, #M2]
    SETQ    0, 1
    SETQ    1, 2
    mov     x28, #0                     // the certificates become blocks, one after another, in the state's working room
    mov     x24, #0
1:  ldr     w9, [x19, #ST_certs]
    cmp     w24, w9
    b.hs    3f
    add     x10, x19, #ST_cert_len
    ldr     w1, [x10, x24, lsl #2]
    add     x9, x1, #64
    add     x10, x28, x9
    ldr     x11, =(64 + RECORD + 512 + 64 + RECORD + 512)
    cmp     x10, x11
    b.hi    w_no
    ST      x0, ST_in_head
    add     x0, x0, x28
    add     x9, x9, #7
    and     x9, x9, #-8
    add     x28, x28, x9
    mov     x10, #M3
    add     x10, x21, x10
    str     x0, [x10, x24, lsl #3]
    add     w9, w24, #3
    add     x10, x21, #(Q + 4)
    strh    w9, [x10, x24, lsl #1]
    bl      head
    add     x10, x19, #ST_cert_at
    ldr     w10, [x10, x24, lsl #2]
    add     x11, x19, #ST_cert_len
    ldr     w11, [x11, x24, lsl #2]
    add     x10, x10, x19
    add     x10, x10, #ST_transcript
    add     x0, x0, #64
    cbz     w11, 4f
2:  ldrb    w12, [x10], #1
    strb    w12, [x0], #1
    subs    w11, w11, #1
    b.ne    2b
4:  add     x24, x24, #1
    b       1b
3:  mov     x0, #0
    add     x1, x21, #Q
    ldr     w2, [x19, #ST_certs]
    add     x2, x2, #2
    mov     x3, x25
    add     x4, x21, #MINE
    ldr     x9, [x20, #(29 * 8)]
    blr     x9
    str     w0, [x19, #ST_trust]
    cmp     w0, #1
    b.ne    w_no
    HASH    TH, w_no
    add     x10, x21, #(CONTENT + 64)   // what the server signed: 64 spaces, a fixed sentence, a zero, the hash of everything so far
    ldr     x9, =0x2020202020202020
    mov     x11, #0
5:  str     x9, [x10, x11, lsl #3]
    add     x11, x11, #1
    cmp     x11, #8
    b.lo    5b
    adr     x12, l_said
    mov     x11, #0
6:  ldrb    w9, [x12, x11]
    add     x13, x10, #64
    strb    w9, [x13, x11]
    add     x11, x11, #1
    cmp     x11, #33
    b.lo    6b
    strb    wzr, [x10, #97]
    add     x13, x10, #98
    add     x12, x21, #TH
    COPY32  x13, x12
    add     x0, x21, #CONTENT
    mov     x1, #130
    bl      head
    add     x0, x21, #SIG
    mov     x1, x27
    bl      head
    add     x10, x21, #(SIG + 64)
    mov     x11, #0
7:  cmp     w11, w27
    b.hs    8f
    add     x12, x22, #8
    ldrb    w9, [x12, x11]
    strb    w9, [x10, x11]
    add     x11, x11, #1
    b       7b
8:  add     x9, x21, #CONTENT
    str     x9, [x21, #(MINE + 267 * 8)]
    add     x9, x21, #SIG
    str     x9, [x21, #(MINE + 268 * 8)]
    SETQ    0, 3
    strh    w26, [x21, #(Q + 2)]
    SETQ    2, 11
    SETQ    3, 12
    mov     x0, #0
    mov     x2, #4
    SOCKET  30
    cmp     x0, #1
    b.eq    9f
    mov     w9, #-6
    str     w9, [x19, #ST_trust]
    b       w_no
9:  mov     x0, #1
    b       w_out
w_no:
    mov     x0, #0
w_out:
    POP7
    .ltorg

// handshake_messages: the server's messages after its hello, as they complete: its settings, its certificate, its signature, its
// proof. x0 the block for what we send back, x1 the trusted roots (or 0), x2 the time -> x0 1 or 0
handshake_messages:
    PUSH7
    mov     x22, x0
    mov     x23, x1
    mov     x24, x2
    ST      x27, ST_hs
m_loop:
    ldr     w9, [x19, #ST_hn]
    cmp     w9, #4
    b.lo    m_yes
    add     x10, x27, #1
    BE24    w25, x10                    // this message's length, and its kind
    ldrb    w26, [x27]
    add     w10, w25, #4
    cmp     w10, #TRANSCRIPT
    b.hi    m_no
    cmp     w9, w10
    b.lo    m_yes
    ldr     w9, [x19, #ST_stage]
    cmp     w9, #2
    b.ne    m_pass
    cmp     w26, #20
    b.ne    m_other
    cbz     x23, 1f                     // its proof. None is accepted from a server whose certificate did not check out.
    ldr     w9, [x19, #ST_unverified]
    cbnz    w9, m_no
1:  cmp     w25, #32
    b.ne    m_no
    EXPAND  x19, ST_s_hs, l_finished, 0, 0, 32, x21, FK, m_no
    HASH    TH, m_no
    HMAC    x21, FK, x21, TH, x21, WANT, m_no
    ldp     x9, x10, [x21, #WANT]
    add     x14, x27, #4
    ldp     x11, x12, [x14]
    eor     x9, x9, x11
    eor     x10, x10, x12
    orr     x9, x9, x10
    ldp     x10, x11, [x21, #(WANT + 16)]
    ldp     x12, x13, [x14, #16]
    eor     x10, x10, x12
    eor     x11, x11, x13
    orr     x9, x9, x10
    orr     x9, x9, x11
    cbnz    x9, m_no                    // the server did not arrive at our keys
    mov     x0, x27
    mov     x1, #36
    bl      add_transcript
    cbz     x0, m_no
    HASH    TH, m_no
    mov     x9, #20                     // our own proof
    movk    x9, #0x2000, lsl #16
    str     x9, [x21, #MINE36]
    stp     xzr, xzr, [x21, #(MINE36 + 8)]
    stp     xzr, xzr, [x21, #(MINE36 + 24)]
    EXPAND  x19, ST_c_hs, l_finished, 0, 0, 32, x21, FK, m_no
    HMAC    x21, FK, x21, TH, x21, (MINE36 + 4), m_no
    mov     x0, x22
    add     x1, x21, #MINE36
    mov     w2, #36
    mov     w3, #22
    bl      send_record
    cbz     x0, m_no
    EXPAND  x19, ST_master, l_c_ap, TH, 32, 32, x21, CAP, m_no
    EXPAND  x19, ST_master, l_s_ap, TH, 32, 32, x21, SAP, m_no
    add     x0, x21, #SAP
    add     x1, x19, #ST_rkey
    add     x2, x19, #ST_riv
    bl      traffic
    cbz     x0, m_no
    add     x0, x21, #CAP
    add     x1, x19, #ST_wkey
    add     x2, x19, #ST_wiv
    bl      traffic
    cbz     x0, m_no
    stp     xzr, xzr, [x19, #ST_rseq]
    mov     w9, #3
    str     w9, [x19, #ST_stage]
    b       m_pass
m_other:
    cmp     w26, #11
    b.ne    2f
    ldr     w2, [x19, #ST_tn]           // its certificates
    str     w2, [x19, #ST_certificate_at]
    add     w1, w25, #4
    str     w1, [x19, #ST_certificate_len]
    mov     x0, x27
    bl      certificate_list
    cbz     x0, m_no
2:  cmp     w26, #15
    b.ne    3f
    cbz     x23, 3f
    mov     x0, x27                     // its signature over the handshake
    add     w1, w25, #4
    mov     x2, x23
    mov     x3, x24
    bl      who
    cbz     x0, m_no
    str     wzr, [x19, #ST_unverified]
3:  cmp     w26, #8
    b.eq    4f
    cmp     w26, #11
    b.eq    4f
    cmp     w26, #15
    b.eq    4f
    cmp     w26, #13
    b.ne    m_no
4:  mov     x0, x27
    add     w1, w25, #4
    bl      add_transcript
    cbz     x0, m_no
m_pass:                                 // the message is done with; what follows it moves down
    add     w10, w25, #4
    ldr     w9, [x19, #ST_hn]
    mov     w11, w10
5:  cmp     w11, w9
    b.hs    6f
    ldrb    w12, [x27, x11]
    sub     w13, w11, w10
    strb    w12, [x27, x13]
    add     w11, w11, #1
    b       5b
6:  sub     w9, w9, w10
    str     w9, [x19, #ST_hn]
    b       m_loop
m_yes:
    mov     x0, #1
    b       m_out
m_no:
    mov     x0, #0
m_out:
    POP7
    .ltorg

// feed: bytes from the server. Numbers: the handles of the bytes, of where what we send back goes, of where plain data goes, and
// optionally of the trusted roots; the argument is the time. Takes whole records; the state says how much was used.
feed:
    ENTER
    mov     x28, x3
    BLOCK   x22, 0
    BLOCK   x23, 1
    BLOCK   x24, 2
    BLOCK   x25, 3
    cbz     x25, 1f
    ldr     w9, [x25]
    cmp     w9, #2
    b.ne    f_bad
    ldr     x9, [x25, #16]
    cmp     x9, #64
    b.lo    f_bad
1:  ldr     w9, [x19]
    cmp     w9, #1
    b.ne    f_bad
    cbz     x22, f_bad
    ldr     w9, [x22]
    cmp     w9, #2
    b.ne    f_bad
    ldr     x27, [x22, #16]
    cmp     x27, #64
    b.lo    f_bad
    cbz     x23, f_bad
    ldr     x9, [x23, #16]
    cmp     x9, #(64 + 512)
    b.lo    f_bad
    cbz     x24, f_bad
    ldr     x9, [x24, #16]
    cmp     x9, #64
    b.lo    f_bad
    cmp     x23, x24
    b.eq    f_bad
    ldr     w9, [x19, #ST_stage]
    cbz     w9, f_bad
    cmp     w9, #4
    b.lo    2f
    b.ne    f_bad
    mov     x0, #4
    b       f_out
2:  sub     x27, x27, #64               // how many bytes came
    mov     x26, #0                     // how many are used
    str     wzr, [x19, #ST_out_len]
    str     wzr, [x19, #ST_plain_len]
f_record:
    add     x9, x26, #5
    cmp     x9, x27
    b.hi    f_end
    ldr     w9, [x19, #ST_stage]
    cmp     w9, #4
    b.hs    f_end
    add     x10, x22, #64
    add     x10, x10, x26               // this record
    ldrb    w11, [x10]                  // its kind
    ldrh    w12, [x10, #3]
    rev16   w12, w12                    // its length
    mov     w9, #(RECORD + 256)
    cmp     w12, w9
    b.ls    1f
    FAIL    22, f_out
1:  add     x9, x26, #5
    add     x9, x9, x12
    cmp     x9, x27
    b.hi    f_end
    str     w12, [x21, #F_LEN]
    add     x13, x10, #5
    str     x13, [x21, #F_BODY]
    str     w12, [x21, #F_BN]
    cmp     w11, #20                    // a leftover of older versions, sent for old network boxes
    b.eq    f_next
    cmp     w11, #23
    b.ne    4f
    ldr     w9, [x19, #ST_stage]        // a sealed record: opened with the keys for reading
    cmp     w9, #2
    b.lo    2f
    cmp     w12, #17
    b.hs    3f
2:  FAIL    10, f_out
3:  ST      x14, ST_in
    mov     x15, #0
5:  ldrb    w9, [x13, x15]
    strb    w9, [x14, x15]
    add     x15, x15, #1
    cmp     w15, w12
    b.lo    5b
    mov     w0, #0
    add     x1, x19, #ST_rkey
    add     x2, x19, #ST_riv
    ldr     x3, [x19, #ST_rseq]
    add     x9, x3, #1
    str     x9, [x19, #ST_rseq]
    mov     x4, x10
    mov     x5, x12
    bl      crypt
    cmp     x0, #1
    b.ge    6f
    FAIL    20, f_out                   // altered on the way, or not our keys
6:  ST      x13, ST_out                 // inside: the data, its true kind, then zeros
7:  cbz     w0, 8f
    sub     w9, w0, #1
    ldrb    w10, [x13, x9]
    cbnz    w10, 8f
    mov     w0, w9
    b       7b
8:  cbnz    w0, 9f
    FAIL    10, f_out
9:  sub     w0, w0, #1
    ldrb    w11, [x13, x0]
    str     w0, [x21, #F_BN]
    str     x13, [x21, #F_BODY]
    b       f_inner
4:  ldr     w9, [x19, #ST_stage]
    cmp     w9, #2
    b.lo    f_inner
    cmp     w11, #21
    b.eq    f_inner
    FAIL    10, f_out
f_inner:
    ldr     w12, [x21, #F_BN]
    ldr     x13, [x21, #F_BODY]
    cmp     w11, #22
    b.ne    f_data
    ldr     w9, [x19, #ST_stage]        // part of the handshake
    cmp     w9, #1
    b.ne    2f
    cmp     w12, #4
    b.lo    1f
    add     x10, x13, #1
    BE24    w9, x10
    add     w9, w9, #4
    cmp     w9, w12
    b.ne    1f
    mov     x0, x13
    mov     w1, w12
    bl      server_hello
    cbnz    x0, f_next
1:  FAIL    40, f_out
2:  ldr     w9, [x19, #ST_hn]
    add     w10, w9, w12
    cmp     w10, #TRANSCRIPT
    b.ls    3f
    FAIL    22, f_out
3:  ST      x14, ST_hs
    add     x14, x14, x9
    mov     x15, #0
4:  cmp     w15, w12
    b.hs    5f
    ldrb    w9, [x13, x15]
    strb    w9, [x14, x15]
    add     x15, x15, #1
    b       4b
5:  str     w10, [x19, #ST_hn]
    mov     x0, x23
    mov     x1, x25
    mov     x2, x28
    bl      handshake_messages
    cbnz    x0, f_next
    ldr     w9, [x19, #ST_trust]        // refused: over who the server is, or over the handshake itself
    mov     w10, #51
    cbz     w9, 6f
    cmp     w9, #1
    b.eq    6f
    mov     w10, #42
6:  mov     w9, #5
    str     w9, [x19, #ST_stage]
    str     w10, [x19, #ST_alert]
    mov     x0, #-1
    b       f_out
f_data:
    cmp     w11, #23
    b.ne    f_alert
    ldr     w9, [x19, #ST_stage]        // plain data, once connected
    cmp     w9, #3
    b.ne    1f
    ldr     x9, [x24, #16]
    sub     x9, x9, #64
    ldr     w10, [x19, #ST_plain_len]
    add     x11, x10, x12
    cmp     x9, x11
    b.hs    2f
1:  FAIL    22, f_out
2:  add     x14, x24, #64
    add     x14, x14, x10
    mov     x15, #0
3:  cmp     w15, w12
    b.hs    4f
    ldrb    w9, [x13, x15]
    strb    w9, [x14, x15]
    add     x15, x15, #1
    b       3b
4:  str     w11, [x19, #ST_plain_len]
    b       f_next
f_alert:
    cmp     w11, #21
    b.eq    1f
    FAIL    10, f_out
1:  mov     w9, #0                      // the other side is closing, or complaining
    mov     w10, #5
    cmp     w12, #1
    b.ls    2f
    ldrb    w9, [x13, #1]
    cbnz    w9, 2f
    mov     w10, #4
2:  str     w9, [x19, #ST_alert]
    str     w10, [x19, #ST_stage]
f_next:
    ldr     w12, [x21, #F_LEN]
    add     x26, x26, x12
    add     x26, x26, #5
    b       f_record
f_end:
    str     w26, [x19, #ST_used]
    ldr     w0, [x19, #ST_stage]
    cmp     w0, #5
    b.ne    f_out
f_bad:
    mov     x0, #-1
f_out:
    LEAVE
    .ltorg

// send: plain data to the server, sealed into records. Numbers: the handles of the data and of where the bytes to send go.
send:
    ENTER
    BLOCK   x22, 0
    BLOCK   x23, 1
    ldr     w9, [x19]
    cmp     w9, #1
    b.ne    s_bad
    ldr     w9, [x19, #ST_stage]
    cmp     w9, #3
    b.ne    s_bad
    cbz     x22, s_bad
    ldr     w9, [x22]
    cmp     w9, #2
    b.ne    s_bad
    ldr     x24, [x22, #16]
    cmp     x24, #64
    b.lo    s_bad
    cbz     x23, s_bad
    ldr     x9, [x23, #16]
    cmp     x9, #64
    b.lo    s_bad
    cmp     x22, x23
    b.eq    s_bad
    sub     x24, x24, #64
    str     wzr, [x19, #ST_out_len]
    mov     x25, #0
1:  cmp     x25, x24
    b.hs    2f
    sub     x26, x24, x25
    mov     x9, #RECORD
    cmp     x26, x9
    csel    x26, x9, x26, hi
    mov     x0, x23
    add     x1, x22, #64
    add     x1, x1, x25
    mov     w2, w26
    mov     w3, #23
    bl      send_record
    cbz     x0, s_bad
    add     x25, x25, x26
    b       1b
2:  ldr     w0, [x19, #ST_out_len]
    b       s_out
s_bad:
    mov     x0, #-1
s_out:
    LEAVE
    .ltorg
