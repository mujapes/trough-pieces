// shell, written by hand (ARM64). The meaning is shell/intent.md; the recorded checks (which fingerprint the state) are the judge.
// Entries: x0 state, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// State: 0 version, 4 magic, 8 width, 12 height, 16 screen, 20 pressed, 24 hour, 28 minute, 32 opened, 40 events (64-bit).
    .text
    .global migrate
    .global event
    .global render
    .equ MAGIC_LO, 0x4853
    .equ MAGIC_HI, 0x4c45
    .equ WIDTH, 8
    .equ HEIGHT, 12
    .equ SCREEN, 16
    .equ PRESSED, 20
    .equ HOUR, 24
    .equ MINUTE, 28
    .equ OPENED, 32
    .equ EVENTS, 40
// is the state layout 1? leaves the flags "eq" if so. Uses w5, w6.
known:
    ldr     w5, [x0]
    cmp     w5, #1
    b.ne    1f
    ldr     w5, [x0, #4]
    mov     w6, #MAGIC_LO
    movk    w6, #MAGIC_HI, lsl #16
    cmp     w5, w6
1:  ret
migrate:
    mov     x16, x30
    bl      known
    b.eq    3f
    mov     x5, #0
1:  ldr     x6, [x0, x5, lsl #3]        // a block of zeros becomes a fresh state; anything else is left alone
    cbnz    x6, 2f
    add     x5, x5, #1
    cmp     x5, #64
    b.lo    1b
    mov     w5, #1
    str     w5, [x0]
    mov     w5, #MAGIC_LO
    movk    w5, #MAGIC_HI, lsl #16
    str     w5, [x0, #4]
    mov     w5, #-1
    str     w5, [x0, #PRESSED]
    b       3f
2:  mov     x0, #0
    ret     x16
3:  mov     x0, #1
    ret     x16

// --- event -----------------------------------------------------------------------------------------------------------------------
// frame: 0 saved x29 x30, 16 x19 x20, 32 x21 x22, 48 the six values as they were (24 bytes), 80 a picture header for home hit (64), 144 two numbers
event:
    sub     sp, sp, #160
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     x19, x0
    bl      known
    b.ne    e_zero
    mov     w9, #0                      // kind, x, y, hour, minute: missing numbers count as 0
    mov     w10, #0
    mov     w11, #0
    mov     w12, #0
    mov     w13, #0
    cmp     x2, #1
    b.lt    1f
    ldrsh   w9, [x1]
    cmp     x2, #2
    b.lt    1f
    ldrsh   w10, [x1, #2]
    cmp     x2, #3
    b.lt    1f
    ldrsh   w11, [x1, #4]
    cmp     x2, #4
    b.lt    1f
    ldrsh   w12, [x1, #6]
    cmp     x2, #5
    b.lt    1f
    ldrsh   w13, [x1, #8]
1:  ldr     w5, [x19, #SCREEN]          // remember what could change
    str     w5, [sp, #48]
    ldr     w5, [x19, #PRESSED]
    str     w5, [sp, #52]
    ldr     w5, [x19, #HOUR]
    str     w5, [sp, #56]
    ldr     w5, [x19, #MINUTE]
    str     w5, [sp, #60]
    ldr     w5, [x19, #WIDTH]
    str     w5, [sp, #64]
    ldr     w5, [x19, #HEIGHT]
    str     w5, [sp, #68]
    ldr     x5, [x19, #EVENTS]
    add     x5, x5, #1
    str     x5, [x19, #EVENTS]
    cmp     w9, #1
    b.eq    e_touch
    cmp     w9, #2
    b.eq    e_touch
    cmp     w9, #3
    b.eq    e_lift
    cmp     w9, #4
    b.eq    e_clock
    cmp     w9, #5
    b.eq    e_size
    b       e_changed
e_touch:
    ldr     w5, [x19, #SCREEN]
    cbnz    w5, e_back
    ldr     w5, [x19, #WIDTH]           // home: the tile under the finger, asked of the home piece
    ldr     w6, [x19, #HEIGHT]
    mov     w0, #-1
    cmp     w5, #16
    b.lt    2f
    cmp     w6, #16
    b.lt    2f
    mov     w7, #1                      // a picture header that only says the size
    str     w7, [sp, #80]
    str     w5, [sp, #84]
    str     w6, [sp, #88]
    lsl     w7, w5, #2
    str     w7, [sp, #92]
    umull   x7, w5, w6
    lsl     x7, x7, #2
    add     x7, x7, #64
    str     x7, [sp, #96]
    stp     xzr, xzr, [sp, #104]
    stp     xzr, xzr, [sp, #120]
    str     xzr, [sp, #136]
    strh    w10, [sp, #144]
    strh    w11, [sp, #146]
    add     x0, sp, #80
    add     x1, sp, #144
    mov     x2, #2
    mov     x3, #0
    ldr     x5, [x4, #(13 * 8)]         // home hit
    blr     x5
2:  str     w0, [x19, #PRESSED]
    b       e_changed
e_back:
    cmp     w9, #1                      // opened screen: only a finger put down counts, and only in the strip along the top
    b.ne    e_changed
    ldr     w5, [x19, #WIDTH]
    mov     w6, #-1
    cmp     w5, #16
    b.lt    3f
    cmp     w11, #0
    b.lt    3f
    cmp     w11, #28
    b.ge    3f
    cmp     w10, #0
    b.lt    3f
    cmp     w10, w5
    b.ge    3f
    mov     w6, #-2
3:  str     w6, [x19, #PRESSED]
    b       e_changed
e_lift:
    ldr     w5, [x19, #SCREEN]
    ldr     w6, [x19, #PRESSED]
    cbnz    w5, 4f
    cmp     w6, #0
    b.lt    5f
    str     w6, [x19, #OPENED]          // lifted on a tile: it opens
    mov     w7, #1
    str     w7, [x19, #SCREEN]
    b       5f
4:  cmp     w5, #1
    b.ne    5f
    cmn     w6, #2
    b.ne    5f
    str     wzr, [x19, #SCREEN]         // lifted on the back strip: home again
5:  mov     w7, #-1
    str     w7, [x19, #PRESSED]
    b       e_changed
e_clock:
    mov     w5, #24                     // wrapped into 0-23 and 0-59, also for negative numbers
    sdiv    w6, w12, w5
    msub    w6, w6, w5, w12
    add     w6, w6, w5
    sdiv    w7, w6, w5
    msub    w6, w7, w5, w6
    str     w6, [x19, #HOUR]
    mov     w5, #60
    sdiv    w6, w13, w5
    msub    w6, w6, w5, w13
    add     w6, w6, w5
    sdiv    w7, w6, w5
    msub    w6, w7, w5, w6
    str     w6, [x19, #MINUTE]
    b       e_changed
e_size:
    cmp     w10, #16
    b.lt    e_changed
    cmp     w10, #4096
    b.gt    e_changed
    cmp     w11, #16
    b.lt    e_changed
    cmp     w11, #4096
    b.gt    e_changed
    str     w10, [x19, #WIDTH]
    str     w11, [x19, #HEIGHT]
e_changed:
    mov     x0, #0
    ldr     w5, [x19, #SCREEN]
    ldr     w6, [sp, #48]
    cmp     w5, w6
    b.ne    e_one
    ldr     w5, [x19, #PRESSED]
    ldr     w6, [sp, #52]
    cmp     w5, w6
    b.ne    e_one
    ldr     w5, [x19, #HOUR]
    ldr     w6, [sp, #56]
    cmp     w5, w6
    b.ne    e_one
    ldr     w5, [x19, #MINUTE]
    ldr     w6, [sp, #60]
    cmp     w5, w6
    b.ne    e_one
    ldr     w5, [x19, #WIDTH]
    ldr     w6, [sp, #64]
    cmp     w5, w6
    b.ne    e_one
    ldr     w5, [x19, #HEIGHT]
    ldr     w6, [sp, #68]
    cmp     w5, w6
    b.eq    e_out
e_one:
    mov     x0, #1
    b       e_out
e_zero:
    mov     x0, #0
e_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    add     sp, sp, #160
    ret

// --- render ----------------------------------------------------------------------------------------------------------------------
// frame: 0 x29 x30, 16 x19 x20, 32 x21 x22, 48 x23 x24, 64 numbers for the pieces called (40 of them), 144 a line of text
// x19 state, x20 picture, x21 table, x22 width, x23 height
render:
    sub     sp, sp, #176
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     x19, x0
    mov     x21, x4
    mov     x20, #0
    cmp     x2, #1
    b.lt    1f
    ldrsh   x5, [x1]
    cmp     x5, #0
    b.lt    1f
    cmp     x5, #255
    b.gt    1f
    add     x5, x5, #256
    ldr     x20, [x4, x5, lsl #3]
1:  bl      known
    b.ne    r_fail
    cbz     x20, r_fail
    ldr     w5, [x20]
    cmp     w5, #1
    b.ne    r_fail
    ldr     w22, [x20, #4]
    ldr     w23, [x20, #8]
    cbz     w22, r_fail
    cmp     w22, #16384
    b.hi    r_fail
    cbz     w23, r_fail
    cmp     w23, #16384
    b.hi    r_fail
    ldr     w5, [x20, #12]
    lsl     w6, w22, #2
    cmp     w5, w6
    b.ne    r_fail
    umull   x6, w5, w23
    add     x6, x6, #64
    ldr     x7, [x20, #16]
    cmp     x7, x6
    b.ne    r_fail
    ldr     w5, [x19, #SCREEN]
    cbnz    w5, r_opened
    ldr     w5, [x19, #PRESSED]         // home: the home piece draws it
    strh    w5, [sp, #64]
    ldr     w5, [x19, #HOUR]
    strh    w5, [sp, #66]
    ldr     w5, [x19, #MINUTE]
    strh    w5, [sp, #68]
    mov     x0, x20
    add     x1, sp, #64
    mov     x2, #3
    mov     x3, #0
    mov     x4, x21
    ldr     x5, [x21, #(12 * 8)]
    blr     x5
    b       r_out
r_opened:
    mov     x0, x20                     // a dark background
    mov     x1, #0
    mov     x2, #0
    mov     w3, #0x100c
    movk    w3, #0xff14, lsl #16
    mov     x4, x21
    ldr     x5, [x21, #(3 * 8)]
    blr     x5
    strh    wzr, [sp, #64]              // the back strip, lighter while pressed
    strh    wzr, [sp, #66]
    strh    w22, [sp, #68]
    mov     w5, #28
    strh    w5, [sp, #70]
    mov     w3, #0x221c
    movk    w3, #0xff2b, lsl #16
    mov     w6, #0x3c32
    movk    w6, #0xff4a, lsl #16
    ldr     w5, [x19, #PRESSED]
    cmn     w5, #2
    csel    w3, w6, w3, eq
    mov     x0, x20
    add     x1, sp, #64
    mov     x2, #4
    mov     x4, x21
    ldr     x5, [x21, #(4 * 8)]
    blr     x5
    adr     x0, t_home                  // "< Home", at the left
    mov     w1, #12
    mov     w2, #3
    mov     w3, #0
    mov     w6, #0xd0c8
    movk    w6, #0xffd8, lsl #16
    bl      words
    adr     x5, t_opened                // "Opened tile N"
    mov     x6, #0
2:  ldrb    w7, [x5, x6]
    add     x8, sp, #144
    strb    w7, [x8, x6]
    add     x6, x6, #1
    cmp     x6, #12
    b.lo    2b
    ldr     w5, [x19, #OPENED]
    mov     w7, #0
    cmp     w5, #0
    b.lt    3f
    mov     w9, #100
    sdiv    w7, w5, w9
    msub    w7, w7, w9, w5
3:  mov     w9, #10
    udiv    w10, w7, w9
    msub    w11, w10, w9, w7
    cmp     w7, #10
    b.lo    4f
    add     w10, w10, #'0'
    strb    w10, [x8, x6]
    add     x6, x6, #1
4:  add     w11, w11, #'0'
    strb    w11, [x8, x6]
    add     x6, x6, #1
    strb    wzr, [x8, x6]
    add     x0, sp, #144
    lsr     w1, w22, #1
    lsr     w2, w23, #1
    sub     w2, w2, #11
    mov     w3, #1
    mov     w6, #0xece8
    movk    w6, #0xfff0, lsl #16
    bl      words
    adr     x0, t_app                   // "an app would go here"
    lsr     w1, w22, #1
    lsr     w2, w23, #1
    add     w2, w2, #16
    mov     w3, #1
    mov     w6, #0x8078
    movk    w6, #0xff8a, lsl #16
    bl      words
    mov     x0, #7                      // seven drawing calls were made
    b       r_out
r_fail:
    mov     x0, #-1
r_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    add     sp, sp, #176
    ret
// words: x0 text (ends with 0), w1 x, w2 y, w3 centred?, w6 colour. Draws through the text piece. Uses the numbers at sp+64 of render's frame.
words:
    stp     x29, x30, [sp, #-48]!
    stp     x24, x25, [sp, #16]
    stp     x26, x27, [sp, #32]
    mov     w24, w1
    mov     w25, w2
    mov     w26, w6
    mov     x27, #0                     // how many letters
    add     x8, sp, #(48 + 64)
1:  ldrb    w7, [x0, x27]
    cbz     w7, 2f
    cmp     x27, #38
    b.hs    2f
    add     x9, x8, x27, lsl #1
    strh    w7, [x9, #4]
    add     x27, x27, #1
    b       1b
2:  cbz     w3, 3f
    mov     x0, x20                     // centred: half its measured width to the left
    add     x1, sp, #(48 + 64 + 4)
    mov     x2, x27
    mov     x3, #0
    mov     x4, x21
    ldr     x5, [x21, #(6 * 8)]
    blr     x5
    add     w0, w0, w0, lsr #31
    asr     w0, w0, #1
    sub     w24, w24, w0
3:  strh    w24, [sp, #(48 + 64)]
    strh    w25, [sp, #(48 + 66)]
    mov     x0, x20
    add     x1, sp, #(48 + 64)
    add     x2, x27, #2
    mov     w3, w26
    mov     x4, x21
    ldr     x5, [x21, #(5 * 8)]
    blr     x5
    ldp     x24, x25, [sp, #16]
    ldp     x26, x27, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret
t_home:   .asciz "< Home"
t_opened: .ascii "Opened tile "
t_app:    .asciz "an app would go here"
    .balign 4
