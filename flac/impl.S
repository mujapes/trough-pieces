// flac, written by hand (ARM64): reads FLAC, lossless sound. The meaning is flac/intent.md; the recorded checks are the judge.
// Entries: x0 block (the sound made), x1 numbers (16-bit), x2 how many, x3 argument, x4 call table. Calls nothing.
// The reader, through an entry: x19 the frame, x20 the file's bytes, x21 how many, x22 the byte we are in, w23 the bit within it
// (0 the highest), w24 set once the file has run out. In decode: x25 the samples of the channel being read, w26 samples in the block,
// x27 where the sound goes, x28 samples made.
    .text
    .global info
    .global decode
    .equ RATE, 96
    .equ CHANNELS, 100
    .equ BPS, 104
    .equ MAXB, 108
    .equ TOTAL, 112
    .equ AUDIO, 120
    .equ START, 128
    .equ ASSIGN, 136
    .equ CH, 152
    .equ CHAN0, 160
    .equ CHAN1, 168
    .equ ROOM, 176
    .equ CRC8, 192
    .equ CRC16, 448
    .equ FRAME, 960
// take: the next w0 bits (0 to 32), highest first -> w0. When that many bits remain they are read bytes at a time; at the very end
// of the file one at a time, so that running out leaves the reader exactly where the meaning says. Uses x9-x12.
take:
    add     w9, w23, w0                 // bits from the start of this byte to the end of what is wanted
    add     w10, w9, #7
    lsr     w10, w10, #3                // bytes that touches
    add     x11, x22, x10
    cmp     x11, x21
    b.hi    t_slow
    mov     x11, #0
    mov     x12, #0
5:  cmp     w12, w10
    b.hs    4f
    add     x9, x22, x12
    ldrb    w9, [x20, x9]
    orr     x11, x9, x11, lsl #8
    add     x12, x12, #1
    b       5b
4:  add     w9, w23, w0
    lsl     w12, w10, #3
    sub     w12, w12, w9
    lsr     x11, x11, x12
    mov     x12, #1
    lsl     x12, x12, x0
    sub     x12, x12, #1
    and     x11, x11, x12
    add     x22, x22, x9, lsr #3
    and     w23, w9, #7
    mov     w0, w11
    ret
t_slow:
    mov     w9, w0
    mov     w0, #0
1:  cbz     w9, 3f
    cmp     x22, x21
    b.lo    2f
    mov     w24, #1
    mov     w0, #0
    ret
2:  ldrb    w10, [x20, x22]
    mov     w11, #7
    sub     w11, w11, w23
    lsr     w10, w10, w11
    and     w10, w10, #1
    orr     w0, w10, w0, lsl #1
    add     w23, w23, #1
    sub     w9, w9, #1
    cmp     w23, #8
    b.ne    1b
    mov     w23, #0
    add     x22, x22, #1
    b       1b
3:  ret
// take_signed: the next w0 bits (fewer than 32) as a two's complement number -> w0. Uses x13, x16 as well.
take_signed:
    cbz     w0, 9f
    mov     x16, x30
    mov     w13, w0
    bl      take
    sub     w9, w13, #1
    lsr     w10, w0, w9
    cbz     w10, 1f
    mov     w10, #1
    lsl     w10, w10, w13
    sub     w0, w0, w10
1:  ret     x16
9:  ret
// unary: how many zero bits come before the next one bit -> w0. Uses x14, x15 as well.
unary:
    mov     x15, x30
    mov     w14, #0
1:  cbnz    w24, 2f
    mov     w0, #1
    bl      take
    cbnz    w0, 2f
    add     w14, w14, #1
    mov     w9, #0x400000
    cmp     w14, w9
    b.ls    1b
    mov     w24, #1
2:  mov     w0, w14
    ret     x15

// open_flac: the file in the block x0 (or 0) -> x0 1 or 0; sets the reader and what the file says of itself. Uses x9-x13.
open_flac:
    cbz     x0, o_no
    ldr     w9, [x0]
    cmp     w9, #2
    b.ne    o_no
    ldr     x21, [x0, #16]
    cmp     x21, #(64 + 42)
    b.lo    o_no
    sub     x21, x21, #64
    add     x20, x0, #64
    mov     x22, #4
    mov     w23, #0
    mov     w24, #0
    str     wzr, [x19, #RATE]
    ldr     w9, [x20]
    ldr     w10, =0x43614c66            // "fLaC"
    cmp     w9, w10
    b.ne    o_no
1:  add     x9, x22, #4
    cmp     x9, x21
    b.hi    o_no
    add     x10, x20, x22
    ldrb    w11, [x10]                  // kind of this part, and whether it is the last
    ldrb    w12, [x10, #1]
    ldrb    w13, [x10, #2]
    orr     w12, w13, w12, lsl #8
    ldrb    w13, [x10, #3]
    orr     w12, w13, w12, lsl #8       // its length
    add     x13, x9, x12
    cmp     x13, x21
    b.hi    o_no
    tst     w11, #127
    b.ne    2f
    cmp     w12, #34
    b.lo    o_no
    add     x10, x20, x9                // the part that describes the sound
    ldrh    w12, [x10, #2]
    rev16   w12, w12
    str     w12, [x19, #MAXB]
    ldr     w12, [x10, #10]
    rev     w12, w12                    // bytes 10 to 13: 20 bits of rate, 3 of channels, 5 of sample size, 4 of the total
    lsr     w9, w12, #12
    str     w9, [x19, #RATE]
    ubfx    w9, w12, #9, #3
    add     w9, w9, #1
    str     w9, [x19, #CHANNELS]
    ubfx    w9, w12, #4, #5
    add     w9, w9, #1
    str     w9, [x19, #BPS]
    and     x12, x12, #15
    ldr     w9, [x10, #14]
    rev     w9, w9
    orr     x12, x9, x12, lsl #32
    str     x12, [x19, #TOTAL]
2:  mov     x22, x13
    tbz     w11, #7, 1b
    str     x22, [x19, #AUDIO]
    ldr     w9, [x19, #RATE]
    cbz     w9, o_no
    ldr     w9, [x19, #MAXB]
    cmp     w9, #16
    b.lo    o_no
    mov     x0, #1
    ret
o_no:
    mov     x0, #0
    ret

    .macro  ENTER
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, sp
    mov     x27, x0
    mov     x25, x1
    mov     x26, x2
    mov     x28, x4
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
// BLOCK: the block at the handle in number \i (numbers x25, count x26, table x28) -> x0, or 0
    .macro  BLOCK i
    mov     x0, #0
    cmp     x26, #\i
    b.le    60f
    ldrsh   x9, [x25, #(\i * 2)]
    cmp     x9, #0
    b.lt    60f
    cmp     x9, #255
    b.gt    60f
    add     x9, x9, #256
    ldr     x0, [x28, x9, lsl #3]
60:
    .endm
info:
    ENTER
    BLOCK   0
    bl      open_flac
    cbz     x0, 5f
    mov     x9, #0
    cmp     x26, #1
    b.le    1f
    ldrsh   x9, [x25, #2]
1:  cmp     x9, #3
    b.hi    5f
    ldr     w0, [x19, #RATE]
    cbz     x9, 6f
    ldr     w0, [x19, #CHANNELS]
    cmp     x9, #1
    b.eq    6f
    ldr     w0, [x19, #BPS]
    cmp     x9, #2
    b.eq    6f
    ldr     x0, [x19, #TOTAL]
    b       6f
5:  mov     x0, #-1
6:  LEAVE

// residual: the corrections for the samples after the first w0 of the block, in their coded form -> w0 1 or 0
    .equ R_ORDER, 32
    .equ R_PBITS, 36
    .equ R_ESC, 40
    .equ R_PARTS, 44
    .equ R_PART, 48
    .equ R_PORDER, 52
    .equ R_K, 56
    .equ R_RAW, 60
residual:
    stp     x29, x30, [sp, #-64]!
    stp     x27, x28, [sp, #16]
    str     w0, [sp, #R_ORDER]
    mov     w27, w0                     // which sample comes next
    mov     w0, #2
    bl      take
    str     w0, [sp, #R_PBITS]          // (the method, for a moment)
    mov     w0, #4
    bl      take
    str     w0, [sp, #R_PORDER]
    ldr     w9, [sp, #R_PBITS]
    cmp     w9, #1
    b.hi    r_no
    mov     w10, #4
    mov     w11, #15
    cbz     w9, 1f
    mov     w10, #5
    mov     w11, #31
1:  str     w10, [sp, #R_PBITS]
    str     w11, [sp, #R_ESC]
    mov     w9, #1
    lsl     w9, w9, w0
    str     w9, [sp, #R_PARTS]
    lsr     w10, w26, w0
    ldr     w11, [sp, #R_ORDER]
    cmp     w10, w11
    b.lo    2f
    sub     w9, w9, #1
    tst     w26, w9
    b.eq    3f
2:  cbnz    w0, r_no
3:  str     wzr, [sp, #R_PART]
r_part:
    ldr     w9, [sp, #R_PART]
    ldr     w10, [sp, #R_PARTS]
    cmp     w9, w10
    b.hs    r_end
    ldr     w10, [sp, #R_PORDER]
    lsr     w28, w26, w10               // how many corrections in this part
    cbnz    w9, 1f
    ldr     w10, [sp, #R_ORDER]
    sub     w28, w28, w10
1:  ldr     w0, [sp, #R_PBITS]
    bl      take
    str     w0, [sp, #R_K]
    add     w9, w27, w28
    cmp     w9, w26
    b.hi    r_no
    ldr     w9, [sp, #R_ESC]
    cmp     w0, w9
    b.ne    r_rice
    mov     w0, #5                      // this part is stored plainly, so many bits a correction
    bl      take
    str     w0, [sp, #R_RAW]
2:  cbz     w28, r_part_done
    ldr     w0, [sp, #R_RAW]
    bl      take_signed
    str     w0, [x25, x27, lsl #2]
    add     w27, w27, #1
    sub     w28, w28, #1
    b       2b
r_rice:
3:  cbz     w28, r_part_done
    bl      unary
    ldr     w9, [sp, #R_K]
    lsl     w29, w0, w9                 // (x29 is saved above and free here)
    cbz     w9, 4f
    mov     w0, w9
    bl      take
    orr     w29, w29, w0
4:  lsr     w9, w29, #1                 // an even number is a correction upward, an odd one downward
    and     w10, w29, #1
    neg     w10, w10
    eor     w9, w9, w10
    str     w9, [x25, x27, lsl #2]
    add     w27, w27, #1
    sub     w28, w28, #1
    b       3b
r_part_done:
    cbnz    w24, r_no
    ldr     w9, [sp, #R_PART]
    add     w9, w9, #1
    str     w9, [sp, #R_PART]
    b       r_part
r_end:
    cmp     w27, w26
    cset    w0, eq
    b       r_out
r_no:
    mov     w0, #0
r_out:
    ldp     x27, x28, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// subframe: one channel's block of w26 samples, each w0 bits, to x25 -> w0 1 or 0
    .equ S_BPS, 32
    .equ S_TYPE, 36
    .equ S_WASTED, 40
    .equ S_ORDER, 44
    .equ S_SHIFT, 48
    .equ S_PREC, 52
    .equ S_COEF, 64
    .equ S_FRAME, 192
subframe:
    sub     sp, sp, #S_FRAME
    stp     x29, x30, [sp]
    stp     x27, x28, [sp, #16]
    str     w0, [sp, #S_BPS]
    mov     w0, #1
    bl      take
    cbnz    w0, s_no
    mov     w0, #6
    bl      take
    str     w0, [sp, #S_TYPE]
    str     wzr, [sp, #S_WASTED]
    mov     w0, #1
    bl      take
    cbz     w0, 1f
    bl      unary
    add     w0, w0, #1
    str     w0, [sp, #S_WASTED]
1:  ldr     w9, [sp, #S_WASTED]
    ldr     w10, [sp, #S_BPS]
    cmp     w9, w10
    b.ge    s_no
    sub     w10, w10, w9
    str     w10, [sp, #S_BPS]
    ldr     w9, [sp, #S_TYPE]
    cbnz    w9, 3f
    mov     w0, w10                     // one value for the whole block
    bl      take_signed
    mov     w27, #0
2:  cmp     w27, w26
    b.hs    s_wasted
    str     w0, [x25, x27, lsl #2]
    add     w27, w27, #1
    b       2b
3:  cmp     w9, #1
    b.ne    5f
    mov     w27, #0                     // every sample stored plainly
4:  cmp     w27, w26
    b.hs    s_wasted
    ldr     w0, [sp, #S_BPS]
    bl      take_signed
    str     w0, [x25, x27, lsl #2]
    add     w27, w27, #1
    b       4b
5:  cmp     w9, #8
    b.lo    s_no
    cmp     w9, #12
    b.hi    s_lpc
    sub     w9, w9, #8                  // one of five fixed predictions
    str     w9, [sp, #S_ORDER]
    bl      s_warm
    cbz     w0, s_no
    ldr     w0, [sp, #S_ORDER]
    bl      residual
    cbz     w0, s_no
    ldr     w9, [sp, #S_ORDER]
    mov     w27, w9
6:  cmp     w27, w26
    b.hs    s_wasted
    add     x10, x25, x27, lsl #2
    mov     x11, #0
    cbz     w9, 7f
    ldrsw   x11, [x10, #-4]
    cmp     w9, #1
    b.eq    7f
    ldrsw   x12, [x10, #-8]
    lsl     x11, x11, #1
    sub     x11, x11, x12               // 2a - b
    cmp     w9, #2
    b.eq    7f
    ldrsw   x13, [x10, #-4]
    ldrsw   x14, [x10, #-12]
    sub     x11, x13, x12
    add     x11, x11, x11, lsl #1
    add     x11, x11, x14               // 3a - 3b + c
    cmp     w9, #3
    b.eq    7f
    ldrsw   x15, [x10, #-16]
    add     x11, x13, x14
    lsl     x11, x11, #2
    add     x16, x12, x12, lsl #1
    sub     x11, x11, x16, lsl #1
    sub     x11, x11, x15               // 4a - 6b + 4c - d
7:  ldr     w12, [x10]
    add     w12, w12, w11
    str     w12, [x10]
    add     w27, w27, #1
    b       6b
s_lpc:
    cmp     w9, #32
    b.lo    s_no
    and     w9, w9, #31                 // a prediction from weights the file gives
    add     w9, w9, #1
    str     w9, [sp, #S_ORDER]
    bl      s_warm
    cbz     w0, s_no
    mov     w0, #4
    bl      take
    add     w0, w0, #1
    cmp     w0, #16
    b.eq    s_no
    str     w0, [sp, #S_PREC]
    mov     w0, #5
    bl      take_signed
    tbnz    w0, #31, s_no
    str     w0, [sp, #S_SHIFT]
    mov     w27, #0
8:  ldr     w9, [sp, #S_ORDER]
    cmp     w27, w9
    b.hs    9f
    ldr     w0, [sp, #S_PREC]
    bl      take_signed
    add     x9, sp, #S_COEF
    str     w0, [x9, x27, lsl #2]
    add     w27, w27, #1
    b       8b
9:  ldr     w0, [sp, #S_ORDER]
    bl      residual
    cbz     w0, s_no
    ldr     w9, [sp, #S_ORDER]
    ldr     w13, [sp, #S_SHIFT]
    add     x14, sp, #S_COEF
    mov     w27, w9
10: cmp     w27, w26
    b.hs    s_wasted
    add     x10, x25, x27, lsl #2
    mov     x11, #0
    mov     x12, #0
11: ldrsw   x15, [x14, x12, lsl #2]
    sub     x16, x10, x12, lsl #2
    ldrsw   x16, [x16, #-4]
    madd    x11, x15, x16, x11
    add     x12, x12, #1
    cmp     w12, w9
    b.lo    11b
    asr     x11, x11, x13
    ldr     w12, [x10]
    add     w12, w12, w11
    str     w12, [x10]
    add     w27, w27, #1
    b       10b
s_wasted:
    ldr     w9, [sp, #S_WASTED]         // low bits that were all zero in this block, put back
    cbz     w9, 13f
    mov     w27, #0
12: cmp     w27, w26
    b.hs    13f
    ldr     w10, [x25, x27, lsl #2]
    lsl     w10, w10, w9
    str     w10, [x25, x27, lsl #2]
    add     w27, w27, #1
    b       12b
13: cmp     w24, #0
    cset    w0, eq
    b       s_out
s_no:
    mov     w0, #0
s_out:
    ldp     x29, x30, [sp]
    ldp     x27, x28, [sp, #16]
    add     sp, sp, #S_FRAME
    ret
// s_warm: the first samples of the block, stored plainly, as many as the prediction looks back -> w0 0 if that is more than
// the block. Reached only from subframe, whose frame it reads; keeps its return address in x28.
s_warm:
    mov     x28, x30
    ldr     w9, [sp, #S_ORDER]
    cmp     w9, w26
    b.hi    2f
    mov     w27, #0
1:  ldr     w9, [sp, #S_ORDER]
    cmp     w27, w9
    b.hs    3f
    ldr     w0, [sp, #S_BPS]
    bl      take_signed
    str     w0, [x25, x27, lsl #2]
    add     w27, w27, #1
    b       1b
2:  mov     w0, #0
    ret     x28
3:  mov     w0, #1
    ret     x28

decode:
    ENTER
    BLOCK   0
    mov     x29, x0
    bl      open_flac
    cbz     x0, d_bad
    cmp     x29, x27
    b.eq    d_bad
    ldr     x9, [x27, #16]
    cmp     x9, #64
    b.lo    d_bad
    BLOCK   1
    cbz     x0, d_bad
    ldr     w9, [x0]
    cmp     w9, #5
    b.ne    d_bad
    cmp     x0, x27
    b.eq    d_bad
    ldr     w9, [x19, #BPS]
    cmp     w9, #16
    b.ne    d_bad
    ldr     w9, [x19, #CHANNELS]
    cmp     w9, #2
    b.hi    d_bad
    ldr     w10, [x19, #MAXB]
    umull   x11, w10, w9
    lsl     x11, x11, #3
    add     x11, x11, #64
    ldr     x12, [x0, #16]
    cmp     x12, x11
    b.lo    d_bad
    add     x0, x0, #64
    str     x0, [x19, #CHAN0]
    add     x0, x0, x10, lsl #2
    str     x0, [x19, #CHAN1]
    ldr     x9, [x27, #16]
    sub     x9, x9, #64
    lsr     x9, x9, #1
    str     x9, [x19, #ROOM]
    add     x27, x27, #64
    mov     x28, #0
    add     x10, x19, #CRC8             // the two checksum tables
    add     x11, x19, #CRC16
    mov     w12, #0
1:  mov     w13, w12
    lsl     w14, w12, #8
    mov     w15, #8
2:  lsl     w13, w13, #1
    tbz     w13, #8, 3f
    eor     w13, w13, #7
3:  and     w13, w13, #0xff
    lsl     w14, w14, #1
    tbz     w14, #16, 4f
    mov     w16, #0x8005
    eor     w14, w14, w16
4:  and     w14, w14, #0xffff
    subs    w15, w15, #1
    b.ne    2b
    strb    w13, [x10, x12]
    strh    w14, [x11, x12, lsl #1]
    add     w12, w12, #1
    cmp     w12, #256
    b.lo    1b
    ldr     x22, [x19, #AUDIO]
    mov     w23, #0
d_block:
    add     x9, x22, #2
    cmp     x9, x21
    b.hi    d_done
    str     x22, [x19, #START]
    mov     w0, #14
    bl      take
    mov     w9, #0x3ffe
    cmp     w0, w9
    b.ne    d_bad
    mov     w0, #2
    bl      take
    mov     w0, #4
    bl      take
    mov     w26, w0                     // the block size's code, for now
    mov     w0, #4
    bl      take
    mov     w25, w0                     // the rate's code
    mov     w0, #4
    bl      take
    str     w0, [x19, #ASSIGN]
    mov     w0, #3
    bl      take
    mov     w29, w0                     // the sample size's code
    mov     w0, #1
    bl      take
    cbnz    w0, d_bad
    mov     w0, #8
    bl      take
    mov     w9, #0                      // the block's number follows in 1 to 7 bytes; only its length matters here
    cmp     w0, #0x80
    b.lo    2f
    mov     w9, #1
    cmp     w0, #0xe0
    b.lo    2f
    mov     w9, #2
    cmp     w0, #0xf0
    b.lo    2f
    mov     w9, #3
    cmp     w0, #0xf8
    b.lo    2f
    mov     w9, #4
    cmp     w0, #0xfc
    b.lo    2f
    mov     w9, #5
    cmp     w0, #0xfe
    b.lo    2f
    mov     w9, #6
2:  str     w9, [x19, #CH]
1:  ldr     w9, [x19, #CH]
    cbz     w9, 3f
    sub     w9, w9, #1
    str     w9, [x19, #CH]
    mov     w0, #8
    bl      take
    b       1b
3:  mov     w9, w26
    mov     w26, #0
    cbz     w9, 6f
    mov     w26, #192
    cmp     w9, #1
    b.eq    6f
    cmp     w9, #5
    b.hi    4f
    sub     w10, w9, #2
    mov     w26, #576
    lsl     w26, w26, w10
    b       6f
4:  cmp     w9, #7
    b.hi    5f
    mov     w0, #8
    cmp     w9, #6
    b.eq    1f
    mov     w0, #16
1:  bl      take
    add     w26, w0, #1
    b       6f
5:  sub     w10, w9, #8
    mov     w26, #256
    lsl     w26, w26, w10
6:  cmp     w25, #12
    b.lo    8f
    b.ne    7f
    mov     w0, #8
    bl      take
    b       8f
7:  cmp     w25, #15
    b.eq    d_bad
    mov     w0, #16
    bl      take
8:  cbnz    w24, d_bad
    cbz     w26, d_bad
    ldr     w9, [x19, #MAXB]
    cmp     w26, w9
    b.hi    d_bad
    cbz     w29, 1f
    cmp     w29, #4
    b.ne    d_bad
1:  ldr     w9, [x19, #ASSIGN]
    ldr     w10, [x19, #CHANNELS]
    cmp     w9, #10
    b.hi    d_bad
    cmp     w9, #8
    b.hs    2f
    add     w11, w9, #1
    cmp     w11, w10
    b.ne    d_bad
    b       3f
2:  cmp     w10, #2
    b.ne    d_bad
3:  ldr     x9, [x19, #START]           // the header's checksum
    add     x10, x19, #CRC8
    mov     w11, #0
4:  cmp     x9, x22
    b.hs    5f
    ldrb    w12, [x20, x9]
    eor     w11, w11, w12
    ldrb    w11, [x10, x11]
    add     x9, x9, #1
    b       4b
5:  mov     w25, w11
    mov     w0, #8
    bl      take
    cmp     w0, w25
    b.ne    d_bad
    str     wzr, [x19, #CH]
d_channel:
    ldr     w9, [x19, #CH]
    ldr     w10, [x19, #CHANNELS]
    cmp     w9, w10
    b.hs    d_tail
    ldr     w11, [x19, #ASSIGN]         // the channel holding a difference has one more bit
    mov     w0, #16
    cmp     w11, #9
    b.eq    1f
    cmp     w11, #8
    ccmp    w11, #10, #4, ne
    b.ne    2f
    cbz     w9, 2f
    mov     w0, #17
    b       2f
1:  cbnz    w9, 2f
    mov     w0, #17
2:  ldr     x25, [x19, #CHAN0]
    cbz     w9, 3f
    ldr     x25, [x19, #CHAN1]
3:  bl      subframe
    cbz     w0, d_bad
    ldr     w9, [x19, #CH]
    add     w9, w9, #1
    str     w9, [x19, #CH]
    b       d_channel
d_tail:
    cbz     w23, 1f
    mov     w23, #0
    add     x22, x22, #1
1:  ldr     x9, [x19, #START]           // the whole block's checksum
    add     x10, x19, #CRC16
    mov     w11, #0
2:  cmp     x9, x22
    b.hs    3f
    ldrb    w12, [x20, x9]
    eor     w12, w12, w11, lsr #8
    ldrh    w12, [x10, x12, lsl #1]
    eor     w11, w12, w11, lsl #8
    and     w11, w11, #0xffff
    add     x9, x9, #1
    b       2b
3:  add     x9, x22, #2
    cmp     x9, x21
    b.hi    d_bad
    ldrh    w12, [x20, x22]
    rev16   w12, w12
    cmp     w12, w11
    b.ne    d_bad
    mov     x22, x9
    ldr     w10, [x19, #CHANNELS]
    umull   x9, w26, w10
    add     x9, x9, x28
    ldr     x11, [x19, #ROOM]
    cmp     x9, x11
    b.hi    d_bad
    ldr     x9, [x19, #CHAN0]
    ldr     x11, [x19, #CHAN1]
    ldr     w12, [x19, #ASSIGN]
    mov     w13, #0
d_sample:
    cmp     w13, w26
    b.hs    d_block
    ldr     w14, [x9, x13, lsl #2]
    cmp     w10, #1
    b.eq    4f
    ldr     w15, [x11, x13, lsl #2]
    cmp     w12, #8
    b.ne    1f
    sub     w15, w14, w15               // left, and left less right
    b       3f
1:  cmp     w12, #9
    b.ne    2f
    add     w14, w14, w15               // left less right, and right
    b       3f
2:  cmp     w12, #10
    b.ne    3f
    and     w16, w15, #1                // the middle, and left less right
    orr     w16, w16, w14, lsl #1
    add     w14, w16, w15
    asr     w14, w14, #1
    sub     w15, w16, w15
    asr     w15, w15, #1
3:  strh    w14, [x27, x28, lsl #1]
    add     x28, x28, #1
    strh    w15, [x27, x28, lsl #1]
    add     x28, x28, #1
    add     w13, w13, #1
    b       d_sample
4:  strh    w14, [x27, x28, lsl #1]
    add     x28, x28, #1
    add     w13, w13, #1
    b       d_sample
d_done:
    mov     x0, x28
    b       d_out
d_bad:
    mov     x0, #-1
d_out:
    LEAVE
