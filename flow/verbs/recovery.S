// recovery, Trough OS's first layer: a boot verb for the Flow app, written by hand (ARM64) [by Opus]. boot(x0 ctx).
// A console (the state's text, kept across verbs) above our own keyboard. A line sent with > is a command:
//   help, ls, cat NAME, write NAME TEXT, rm NAME, load NAME (makes NAME the running verb), or anything else: sent to
//   Claude (appended to typed.txt). Claude's replies arrive in reply.txt: shown in the console, then the file removed.
// Files are the app's folder /sdcard/Android/media/t.flow/. A drag scrolls with a glide; new lines scroll into view.
    .equ C_PIX, 0
    .equ C_STRIDE, 8
    .equ C_H, 16
    .equ C_W, 24
    .equ C_STATE, 32
    .equ C_FRAME, 40
    .equ C_RING, 96
    .equ C_HEAD, 104
    .equ T_VAL, 0                       // state: scroll shown (f64)
    .equ T_TGT, 8                       //        scroll target (f64)
    .equ T_SEEN, 16                     //        events taken (u32)
    .equ T_LASTY, 24                    //        the finger's last row (f32)
    .equ T_LEN, 32                      //        text length
    .equ T_TEXT, 4096                   //        the text, at most 16384 bytes
    .equ T_DOWNY, 28                    //        where the finger went down (f32)
    .equ T_MOVED, 40                    //        how far it has moved since (f32)
    .equ T_TLEN, 48                     //        typed so far
    .equ T_TYPED, 2048                  //        the line being typed, at most 1000
    .equ T_KBTOP, 56                    //        the keyboard's top row on screen
    .equ T_CAPS, 64                     //        shift: the next letter a capital
    .equ T_GLOW, 128                    //        each key's glow, 40 f32, 1 when pressed, fading
    .equ T_FOLLOW, 72                   //        new lines came: scroll to the end
    .equ T_INIT, 76                     //        the greeting has been shown
    .equ T_PATH, 3072                   //        a file's path being made
    .equ T_TMP, 24576                   //        room for reading a file, 16384 bytes
    .equ C_WV, 56
    .equ C_RV, 64
    .equ C_TOP, 72
    .equ C_BOOT, 112
    .equ MAXCON, 16000
    .equ KH, 130
    .equ C_DLSYM, 80
    .equ C_ACT, 88
    .equ GW, 24
    .equ GH, 48
    .equ LINE, 56
    .text
    .global recovery
recovery:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, x0
    ldr     x20, [x19, #C_STATE]
    ldr     w9, [x20, #T_INIT]          // 1. the greeting, once
    cbnz    w9, 1f
    mov     w9, #1
    str     w9, [x20, #T_INIT]
    adr     x1, hello
    mov     x2, #(hello_end - hello)
    bl      con_add
1:  ldr     x9, [x19, #C_FRAME]         //    Claude's replies, every 30 frames
    mov     x10, #30
    udiv    x11, x9, x10
    msub    x11, x11, x10, x9
    cbnz    x11, 2f
    adr     x1, rname
    bl      mkpath
    bl      readfile
    cmp     x0, #0
    b.le    2f
    mov     x2, x0
    add     x1, x20, #T_TMP
    bl      con_add
    adr     x1, rname
    bl      mkpath
    mov     x1, x0
    mov     x0, #-100
    mov     x2, #0
    mov     x8, #35
    svc     #0
2:  // 2. touches since last frame
    ldr     w21, [x20, #T_SEEN]
    ldr     w22, [x19, #C_HEAD]
    ldr     x23, [x19, #C_RING]
3:  cmp     w21, w22
    b.eq    5f
    and     w9, w21, #255
    add     x9, x23, x9, lsl #4
    add     w21, w21, #1
    ldr     w10, [x9]
    cmp     w10, #2
    b.eq    key
    cmp     w10, #1
    b.ne    3b
    ldr     w10, [x9, #4]
    and     w10, w10, #0xff
    ldr     s0, [x9, #12]
    cbnz    w10, 41f
    str     s0, [x20, #T_DOWNY]         // down: nothing moved yet
    str     wzr, [x20, #T_MOVED]
    b       4f
41: cmp     w10, #1
    b.ne    42f
    ldr     s1, [x20, #T_MOVED]         // up: a tap if it hardly moved: the keyboard comes up
    fmov    s2, #20.0
    fcmp    s1, s2
    b.ge    4f
    b       tapkey
42: cmp     w10, #2
    b.ne    4f
    ldr     s1, [x20, #T_LASTY]
    fabd    s1, s1, s0
    ldr     s2, [x20, #T_MOVED]
    fadd    s2, s2, s1
    str     s2, [x20, #T_MOVED]
    ldr     s1, [x20, #T_LASTY]         // moved: the target moves by the finger's distance
    fsub    s1, s1, s0
    fcvt    d1, s1
    ldr     d2, [x20, #T_TGT]
    fadd    d2, d2, d1
    fmov    d3, xzr
    fmax    d2, d2, d3
    str     d2, [x20, #T_TGT]
4:  str     s0, [x20, #T_LASTY]
    b       3b
5:  str     w21, [x20, #T_SEEN]
    b       51f
// key: a key pressed (x9 the event): a letter, digit or mark joins the line; delete takes one off; enter sends the line
key:
    ldr     w10, [x9, #4]
    cbnz    w10, 3b                     // only presses
    ldr     w10, [x9, #8]
    ldr     w11, [x9, #12]
    ldr     x12, [x20, #T_TLEN]
    cmp     w10, #67
    b.ne    1f
    cbz     x12, 3b
    sub     x12, x12, #1
    str     x12, [x20, #T_TLEN]
    b       3b
1:  cmp     w10, #66
    b.eq    send
    mov     w13, #0
    sub     w14, w10, #29               // a-z
    cmp     w14, #25
    b.hi    2f
    add     w13, w14, #'a'
    tst     w11, #1                     // shift
    b.eq    addch
    sub     w13, w13, #32
    b       addch
2:  sub     w14, w10, #7                // 0-9
    cmp     w14, #9
    b.hi    4f
    add     w13, w14, #'0'
    b       addch
4:  adr     x14, marks                  // others by table: keycode, character
5:  ldrb    w15, [x14], #2
    cbz     w15, 3b
    cmp     w15, w10
    b.ne    5b
    ldrb    w13, [x14, #-1]
addch:
    cmp     x12, #1000
    b.hs    3b
    add     x14, x20, #T_TYPED
    strb    w13, [x14, x12]
    add     x12, x12, #1
    str     x12, [x20, #T_TLEN]
    b       3b
// tapkey: a tap (x9 the event) on our own keyboard: which key, its glow, and what it does
tapkey:
    ldr     s3, [x9, #8]
    fcvtzs  x13, s3
    fcvtzs  x14, s0
    ldr     x15, [x20, #T_KBTOP]
    cbz     x15, 3b
    subs    x14, x14, x15
    b.lt    3b
    mov     x16, #KH
    udiv    x14, x14, x16
    cmp     x14, #3
    b.hi    3b
    ldr     x16, [x19, #C_W]
    mov     x17, #10
    mul     x13, x13, x17
    udiv    x13, x13, x16
    cmp     x13, #9
    b.hi    3b
    madd    x12, x14, x17, x13          // the key's number
    add     x16, x20, #T_GLOW
    fmov    s4, #1.0
    str     s4, [x16, x12, lsl #2]
    adr     x16, keys
    ldrb    w13, [x16, x12]
    ldr     x12, [x20, #T_TLEN]
    cmp     w13, #'^'
    b.ne    1f
    ldr     w14, [x20, #T_CAPS]
    eor     w14, w14, #1
    str     w14, [x20, #T_CAPS]
    b       3b
1:  cmp     w13, #'<'
    b.ne    2f
    cbz     x12, 3b
    sub     x12, x12, #1
    str     x12, [x20, #T_TLEN]
    b       3b
2:  cmp     w13, #'>'
    b.eq    send
    ldr     w14, [x20, #T_CAPS]         // capitals for one letter
    cbz     w14, addch
    str     wzr, [x20, #T_CAPS]
    sub     w14, w13, #'a'
    cmp     w14, #25
    b.hi    addch
    sub     w13, w13, #32
    b       addch
send:
    stp     x9, x23, [sp, #96]
    add     x14, x20, #T_TYPED
    strb    wzr, [x14, x12]             // the line, ended by a zero
    str     xzr, [x20, #T_TLEN]
    str     x12, [x20, #80]             // its length, kept across con_add
    adr     x1, arrow
    mov     x2, #2
    bl      con_add
    add     x1, x20, #T_TYPED
    ldr     x2, [x20, #80]
    bl      con_add
    adr     x1, nl
    mov     x2, #1
    bl      con_add
    bl      command
    ldp     x9, x23, [sp, #96]
    b       3b
51:
    ldp     d0, d1, [x20, #T_VAL]       // 3. the glide: a third of the way each frame
    fsub    d2, d1, d0
    fmov    d3, #3.0
    fdiv    d2, d2, d3
    fadd    d0, d0, d2
    str     d0, [x20, #T_VAL]
    fcvtzs  x24, d0                     // scroll in rows
    // 4. clear
    ldr     x25, [x19, #C_PIX]
    ldr     x26, [x19, #C_STRIDE]
    ldr     x27, [x19, #C_H]
    ldr     x28, [x19, #C_W]
    mov     w9, #0x1810
    movk    w9, #0xff20, lsl #16
    mul     x10, x26, x27
    mov     x11, #0
6:  cmp     x11, x10
    b.hs    7f
    str     w9, [x25, x11, lsl #2]
    add     x11, x11, #1
    b       6b
7:  // 5. the text: x21 index, x22 length, x23 column, x9.. line
    mov     x21, #0
    ldr     x22, [x20, #T_LEN]
    mov     x23, #0
    mov     x6, #0                      // line
    sub     x7, x28, #48
    mov     x10, #GW
    udiv    x7, x7, x10                 // columns
    cbz     x7, 9f
8:  cmp     x21, x22
    b.hs    9f
    add     x10, x20, #T_TEXT
    ldrb    w0, [x10, x21]
    add     x21, x21, #1
    cmp     w0, #10
    b.ne    81f
    mov     x23, #0
    add     x6, x6, #1
    b       8b
81: cmp     x23, x7
    b.lo    82f
    mov     x23, #0
    add     x6, x6, #1
82: sub     w0, w0, #32
    cmp     w0, #94
    b.hi    84f                         // not printable: a space
    mov     x10, #LINE                  // the glyph's top row on screen
    mov     x11, #80
    madd    x11, x6, x10, x11
    sub     x11, x11, x24
    add     x12, x11, #GH
    cmp     x12, #0
    b.le    84f
    cmp     x11, x27
    b.ge    84f
    mov     x10, #GW                    // its left
    mov     x13, #24
    madd    x13, x23, x10, x13
    adr     x14, font                   // the glyph: 48 rows of 3 bytes
    mov     x10, #(GH * 3)
    madd    x14, x0, x10, x14
    mov     w15, #0xe8e0
    movk    w15, #0xfff0, lsl #16
    mov     x16, #0                     // row
83: cmp     x16, #GH
    b.hs    84f
    add     x17, x11, x16
    cmp     x17, #0
    b.lt    86f
    cmp     x17, x27
    b.ge    84f
    ldrb    w1, [x14]
    ldrb    w2, [x14, #1]
    ldrb    w3, [x14, #2]
    orr     w1, w1, w2, lsl #8
    orr     w1, w1, w3, lsl #16
    madd    x2, x17, x26, x13           // the row's first dot
    add     x2, x25, x2, lsl #2
    mov     x3, #0
85: cbz     w1, 86f
    tbz     w1, #0, 87f
    str     w15, [x2, x3, lsl #2]
87: lsr     w1, w1, #1
    add     x3, x3, #1
    b       85b
86: add     x14, x14, #3
    add     x16, x16, #1
    b       83b
84: add     x23, x23, #1
    b       8b
9:  ldr     w9, [x20, #T_FOLLOW]        // new lines: the scroll's target becomes the end
    cbz     w9, 93f
    str     wzr, [x20, #T_FOLLOW]
    mov     x10, #LINE
    add     x11, x6, #2
    mul     x11, x11, x10
    add     x11, x11, #80
    ldr     x12, [x20, #T_KBTOP]
    sub     x12, x12, #80
    subs    x11, x11, x12
    csel    x11, xzr, x11, lt
    scvtf   d0, x11
    str     d0, [x20, #T_TGT]
93: bl      keyboard
    ldr     x6, [x20, #T_KBTOP]         // the typed line: "> " then the text then a bar, above the keyboard
    sub     x6, x6, #64
    mov     x23, #0
    adr     x10, prompt
    ldrb    w0, [x10]
    bl      glyph_at
    mov     x23, #1
    mov     w0, #' '
    bl      glyph_at
    ldr     x22, [x20, #T_TLEN]
    mov     x21, #0
91: cmp     x21, x22
    b.hs    92f
    add     x10, x20, #T_TYPED
    ldrb    w0, [x10, x21]
    add     x21, x21, #1
    add     x23, x23, #1
    bl      glyph_at
    b       91b
92: add     x23, x23, #1
    mov     w0, #'_'
    bl      glyph_at
    ldp     x27, x28, [sp, #80]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #112
    ret
// glyph_at(w0 character, x6 top row, x23 column): one character, light, with the screen in x25-x28. Uses x0-x5, x10-x17.
glyph_at:
    mov     x10, #GW
    mov     x13, #24
    madd    x13, x23, x10, x13
// glyph_px(w0 character, x6 top row, x13 left)
glyph_px:
    sub     w0, w0, #32
    cmp     w0, #94
    b.hi    9f
    add     x12, x13, #GW
    cmp     x12, x28
    b.gt    9f
    adr     x14, font
    mov     x10, #(GH * 3)
    madd    x14, x0, x10, x14
    mov     w15, #0xffc0
    movk    w15, #0xff80, lsl #16
    mov     x16, #0
1:  cmp     x16, #GH
    b.hs    9f
    add     x17, x6, x16
    cmp     x17, x27
    b.ge    9f
    ldrb    w1, [x14]
    ldrb    w2, [x14, #1]
    ldrb    w3, [x14, #2]
    orr     w1, w1, w2, lsl #8
    orr     w1, w1, w3, lsl #16
    madd    x2, x17, x26, x13
    add     x2, x25, x2, lsl #2
    mov     x3, #0
2:  cbz     w1, 3f
    tbz     w1, #0, 4f
    str     w15, [x2, x3, lsl #2]
4:  lsr     w1, w1, #1
    add     x3, x3, #1
    b       2b
3:  add     x14, x14, #3
    add     x16, x16, #1
    b       1b
9:  ret
// keyboard: four rows of ten keys at the bottom, each a lighter block whose glow fades a little every frame, with its
// letter in the middle. Uses x0-x5, x10-x18, x21-x24 (the text is drawn before it). Screen in x25-x28.
keyboard:
    stp     x30, x21, [sp, #-16]!
    mov     x10, #(4 * KH + 40)
    sub     x21, x27, x10               // top
    str     x21, [x20, #T_KBTOP]
    mov     x0, #0                      // the keyboard's backing
    mov     x1, x21
    mov     x2, x28
    sub     x3, x27, x21
    mov     w4, #0x1410
    movk    w4, #0xff18, lsl #16
    bl      rect
    mov     x22, #0                     // key number
1:  cmp     x22, #40
    b.hs    9f
    mov     x10, #10
    udiv    x23, x22, x10               // row
    msub    x24, x23, x10, x22          // column
    add     x11, x20, #T_GLOW           // glow: shown, then fades
    ldr     s0, [x11, x22, lsl #2]
    ldr     s1, =0x3f59999a             // 0.85
    fmul    s1, s0, s1
    str     s1, [x11, x22, lsl #2]
    ldr     s2, =0x42c00000             // 96: how much lighter a pressed key is
    fmul    s0, s0, s2
    fcvtzu  w12, s0
    orr     w12, w12, w12, lsl #8
    orr     w12, w12, w12, lsl #8
    and     w12, w12, #0xffffff
    mov     w4, #0x3830
    movk    w4, #0xff40, lsl #16
    add     w4, w4, w12
    udiv    x13, x28, x10               // key width
    mul     x0, x24, x13
    add     x0, x0, #5
    mov     x14, #KH
    madd    x1, x23, x14, x21
    add     x1, x1, #6
    sub     x2, x13, #10
    sub     x3, x14, #12
    stp     x0, x1, [sp, #-16]!
    bl      rect
    ldp     x0, x1, [sp], #16
    adr     x11, keys                   // its letter, a capital under shift
    ldrb    w15, [x11, x22]
    cmp     w15, #' '
    b.eq    2f
    ldr     w16, [x20, #T_CAPS]
    cbz     w16, 3f
    sub     w16, w15, #'a'
    cmp     w16, #25
    b.hi    3f
    sub     w15, w15, #32
3:  udiv    x13, x28, x10
    sub     x13, x13, #GW
    lsr     x13, x13, #1
    add     x13, x13, x0
    sub     x13, x13, #5
    add     x6, x1, #(KH - 12 - GH) / 2
    mov     w0, w15
    bl      glyph_px
2:  add     x22, x22, #1
    b       1b
9:  ldp     x30, x21, [sp], #16
    ret
// rect(x0 left, x1 top, x2 width, x3 height, w4 colour), clipped to the screen in x25-x28. Uses x10-x12, x16-x18.
rect:
    add     x2, x0, x2
    cmp     x2, x28
    csel    x2, x28, x2, gt
    add     x3, x1, x3
    cmp     x3, x27
    csel    x3, x27, x3, gt
1:  cmp     x1, x3
    b.hs    9f
    mul     x16, x1, x26
    add     x16, x25, x16, lsl #2
    mov     x17, x0
2:  cmp     x17, x2
    b.hs    3f
    str     w4, [x16, x17, lsl #2]
    add     x17, x17, #1
    b       2b
3:  add     x1, x1, #1
    b       1b
9:  ret
// con_add(x1 bytes, x2 how many): onto the console's end; the oldest bytes go when it is full. Uses x0-x5, x10-x17.
con_add:
    mov     x3, #MAXCON
    cmp     x2, x3
    csel    x2, x3, x2, hi
    ldr     x4, [x20, #T_LEN]
    add     x5, x4, x2
    subs    x5, x5, x3                  // how many must go
    b.le    2f
    add     x10, x20, #T_TEXT
    add     x11, x10, x5
    sub     x4, x4, x5
    mov     x12, #0
1:  cmp     x12, x4
    b.hs    2f
    ldrb    w13, [x11, x12]
    strb    w13, [x10, x12]
    add     x12, x12, #1
    b       1b
2:  add     x10, x20, #T_TEXT
    add     x10, x10, x4
    mov     x12, #0
3:  cmp     x12, x2
    b.hs    4f
    ldrb    w13, [x1, x12]
    strb    w13, [x10, x12]
    add     x12, x12, #1
    b       3b
4:  add     x4, x4, x2
    str     x4, [x20, #T_LEN]
    mov     w13, #1
    str     w13, [x20, #T_FOLLOW]
    ret
// mkpath(x1 name, ended by a zero or a space) -> x0 the full path at T_PATH, x1 just past the name. Uses x10-x12.
mkpath:
    add     x0, x20, #T_PATH
    adr     x10, folder
    mov     x11, x0
1:  ldrb    w12, [x10], #1
    cbz     w12, 2f
    strb    w12, [x11], #1
    b       1b
2:  ldrb    w12, [x1]
    cbz     w12, 3f
    cmp     w12, #' '
    b.eq    3f
    strb    w12, [x11], #1
    add     x1, x1, #1
    b       2b
3:  strb    wzr, [x11]
    ret
// readfile(x0 path) -> x0 bytes read into T_TMP (at most 16384), or negative. Uses x8, x10-x11.
readfile:
    mov     x1, x0
    mov     x0, #-100
    mov     x2, #0
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 9f
    mov     x10, x0
    add     x1, x20, #T_TMP
    mov     x2, #16384
    mov     x8, #63
    svc     #0
    mov     x11, x0
    mov     x0, x10
    mov     x8, #57
    svc     #0
    mov     x0, x11
9:  ret
// starts(x1 word, x2 its length): flags eq if the typed line starts with it. Uses x10-x13.
starts:
    add     x10, x20, #T_TYPED
    mov     x11, #0
1:  cmp     x11, x2
    b.hs    2f
    ldrb    w12, [x10, x11]
    ldrb    w13, [x1, x11]
    add     x11, x11, #1
    cmp     w12, w13
    b.eq    1b
    ret
2:  cmp     x11, x11
    ret
// command: the typed line (at T_TYPED, ended by a zero) is done.
command:
    stp     x30, x21, [sp, #-32]!
    stp     x22, x23, [sp, #16]
    adr     x1, w_help
    mov     x2, #5
    bl      starts
    b.ne    1f
    adr     x1, helptext
    mov     x2, #(helptext_end - helptext)
    bl      con_add
    b       9f
1:  adr     x1, w_ls
    mov     x2, #3
    bl      starts
    b.eq    c_ls
    adr     x1, w_cat
    mov     x2, #4
    bl      starts
    b.eq    c_cat
    adr     x1, w_rm
    mov     x2, #3
    bl      starts
    b.eq    c_rm
    adr     x1, w_write
    mov     x2, #6
    bl      starts
    b.eq    c_write
    adr     x1, w_load
    mov     x2, #5
    bl      starts
    b.eq    c_load
    adr     x1, opathname               // anything else is for Claude: appended to typed.txt
    bl      mkpath
    mov     x1, x0
    mov     x0, #-100
    mov     x2, #0x441
    mov     x3, #0x1b6
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 8f
    mov     x21, x0
    add     x1, x20, #T_TYPED           // the line and a new line
    mov     x2, #0
2:  ldrb    w10, [x1, x2]
    cbz     w10, 3f
    add     x2, x2, #1
    b       2b
3:  mov     w10, #10
    strb    w10, [x1, x2]
    add     x2, x2, #1
    mov     x8, #64
    svc     #0
    mov     x0, x21
    mov     x8, #57
    svc     #0
    adr     x1, m_sent
    mov     x2, #(m_sent_end - m_sent)
    bl      con_add
    b       9f
8:  adr     x1, m_fail
    mov     x2, #(m_fail_end - m_fail)
    bl      con_add
9:  ldp     x22, x23, [sp, #16]
    ldp     x30, x21, [sp], #32
    ret
c_ls:                                   // the folder's names, one to a line
    adr     x1, empty
    bl      mkpath
    mov     x1, x0
    mov     x0, #-100
    mov     x2, #0x4000                 // a directory
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 8b
    mov     x21, x0
1:  mov     x0, x21
    add     x1, x20, #T_TMP
    mov     x2, #16384
    mov     x8, #61                     // getdents64
    svc     #0
    cmp     x0, #0
    b.le    5f
    add     x22, x20, #T_TMP
    add     x23, x22, x0
2:  cmp     x22, x23
    b.hs    1b
    add     x1, x22, #19                // the name
    ldrb    w10, [x1]
    cmp     w10, #'.'
    b.eq    4f
    mov     x2, #0
3:  ldrb    w10, [x1, x2]
    cbz     w10, 31f
    add     x2, x2, #1
    b       3b
31: bl      con_add
    adr     x1, nl
    mov     x2, #1
    bl      con_add
4:  ldrh    w10, [x22, #16]
    add     x22, x22, x10
    b       2b
5:  mov     x0, x21
    mov     x8, #57
    svc     #0
    b       9b
c_cat:
    add     x1, x20, #(T_TYPED + 4)
    bl      mkpath
    bl      readfile
    tbnz    x0, #63, 8b
    mov     x2, x0
    add     x1, x20, #T_TMP
    bl      con_add
    adr     x1, nl
    mov     x2, #1
    bl      con_add
    b       9b
c_rm:
    add     x1, x20, #(T_TYPED + 3)
    bl      mkpath
    mov     x1, x0
    mov     x0, #-100
    mov     x2, #0
    mov     x8, #35
    svc     #0
    tbnz    x0, #63, 8b
    adr     x1, m_done
    mov     x2, #(m_done_end - m_done)
    bl      con_add
    b       9b
c_write:                                // write NAME TEXT: the file becomes TEXT and a new line
    add     x1, x20, #(T_TYPED + 6)
    bl      mkpath
    ldrb    w10, [x1]
    cbz     w10, 1f
    add     x1, x1, #1
1:  mov     x21, x1
    mov     x1, x0
    mov     x0, #-100
    mov     x2, #0x241
    mov     x3, #0x1b6
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 8b
    mov     x22, x0
    mov     x1, x21
    mov     x2, #0
2:  ldrb    w10, [x1, x2]
    cbz     w10, 3f
    add     x2, x2, #1
    b       2b
3:  mov     w10, #10
    strb    w10, [x1, x2]
    add     x2, x2, #1
    mov     x8, #64
    svc     #0
    mov     x0, x22
    mov     x8, #57
    svc     #0
    adr     x1, m_done
    mov     x2, #(m_done_end - m_done)
    bl      con_add
    b       9b
c_load:                                 // load NAME: its code is appended to the arena and becomes the running verb
    add     x1, x20, #(T_TYPED + 5)
    bl      mkpath
    bl      readfile
    cmp     x0, #4
    b.lt    8b
    tst     x0, #3
    b.ne    8b
    mov     x21, x0
    ldr     x10, [x19, #C_TOP]
    ldr     x11, [x10]                  // the top
    ldr     x12, [x19, #C_WV]
    add     x12, x12, x11
    add     x13, x20, #T_TMP
    mov     x14, #0
1:  ldrb    w15, [x13, x14]
    strb    w15, [x12, x14]
    add     x14, x14, #1
    cmp     x14, x21
    b.lo    1b
    ldr     x12, [x19, #C_RV]
    add     x12, x12, x11
    add     x13, x12, x21
    mov     x14, x12
2:  dc      cvau, x14
    ic      ivau, x14
    add     x14, x14, #64
    cmp     x14, x13
    b.lo    2b
    dsb     ish
    isb
    add     x11, x11, x21
    add     x11, x11, #15
    and     x11, x11, #~15
    ldr     x10, [x19, #C_TOP]
    str     x11, [x10]
    adr     x1, m_loaded
    mov     x2, #(m_loaded_end - m_loaded)
    bl      con_add
    add     x10, x19, #C_BOOT
    stlr    x12, [x10]                  // from the next frame
    b       9b
hello: .ascii "Trough OS recovery\nType help, then > to send.\n"
hello_end:
helptext: .ascii "ls  cat NAME  write NAME TEXT  rm NAME\nload NAME  (runs NAME as the screen)\nanything else goes to Claude\n"
helptext_end:
m_sent: .ascii "sent to Claude\n"
m_sent_end:
m_fail: .ascii "could not do that\n"
m_fail_end:
m_done: .ascii "done\n"
m_done_end:
m_loaded: .ascii "loaded; running it now\n"
m_loaded_end:
arrow: .ascii "> "
nl: .ascii "\n"
w_help: .ascii "help"
    .byte 0
w_ls: .ascii "ls"
    .byte 0
w_cat: .ascii "cat "
w_rm: .ascii "rm "
w_write: .ascii "write "
w_load: .ascii "load "
folder: .asciz "/sdcard/Android/media/t.flow/"
rname: .asciz "reply.txt"
opathname: .asciz "typed.txt"
empty: .byte 0
    .balign 4
keys: .ascii "qwertyuiopasdfghjkl'zxcvbnm,.?^^     <<>"
    .balign 4
opath: .asciz "/sdcard/Android/media/t.flow/typed.txt"
prompt: .ascii "> "
marks: .byte 62, ' ', 56, '.', 55, ',', 76, '/', 69, '-', 70, '=', 74, ';', 75, 39, 77, '@', 0, 0
tpath: .asciz "/sdcard/Android/media/t.flow/text.txt"
    .balign 4
font: .incbin "font24x48.bin"
