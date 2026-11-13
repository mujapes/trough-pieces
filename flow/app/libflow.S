// libflow, written by hand (ARM64) [by Opus]: the whole of the new Trough's fixed code, installed once. NativeActivity loads it.
// It only owns what Android hands an app (the window, the input queue, the frame clock) and passes all of it to one verb,
// `boot`, every frame. Everything else is written live: boot is read from /sdcard/Android/media/t.flow/boot.bin when that
// file changes, appended to the arena through the write view and called through the run view from the next frame on.
//
// boot(x0 ctx). ctx (see C_*): the window's pixels, stride, height, width; the state block (16 MB, read+write, kept for the
// process's life: the field and everything verbs keep); frame count and time; the arena's two views and its top (verbs may
// write verbs); dlsym (any system function, by name); the activity (for the soft keyboard); the input ring (256 events of
// 16 bytes, C_HEAD counts every event ever put: kind 1 touch (action, x, y as floats), kind 2 key (action, keycode)).
//
// The net without signals (Android's runtime owns them): a new boot is marked in boot.try before its first frame and the
// mark removed after 120 good frames. If the app starts and finds the mark for the boot.bin that is there now, that boot
// crashed it: it is skipped and the built-in boot runs instead.
    .equ ROOM, 4194304
    .equ STATE, 16777216
    .equ C_PIX, 0
    .equ C_STRIDE, 8
    .equ C_H, 16
    .equ C_W, 24
    .equ C_STATE, 32
    .equ C_FRAME, 40
    .equ C_TIME, 48
    .equ C_WV, 56
    .equ C_RV, 64
    .equ C_TOP, 72
    .equ C_DLSYM, 80
    .equ C_ACT, 88
    .equ C_RING, 96
    .equ C_HEAD, 104
    .equ C_BOOT, 112
    .equ C_SEEN, 120
    .equ C_WIN, 128
    .equ C_QUEUE, 136
    .equ C_POSTED, 144
    .equ C_GOOD, 152
    .equ C_TRY, 160
    .equ C_RINGDATA, 256
    .text
    .global ANativeActivity_onCreate
ANativeActivity_onCreate:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    adrp    x19, ctx
    add     x19, x19, :lo12:ctx
    str     x0, [x19, #C_ACT]
    ldr     x9, [x0]                    // callbacks
    adr     x10, on_window
    str     x10, [x9, #56]
    adr     x10, on_window_gone
    str     x10, [x9, #80]
    adr     x10, on_queue
    str     x10, [x9, #88]
    adr     x10, on_queue_gone
    str     x10, [x9, #96]
    ldr     x10, [x19, #C_RV]
    cbnz    x10, 1f                     // the arena and the state outlive the activity: made once per process
    bl      arena
    adr     x10, boot_default
    str     x10, [x19, #C_BOOT]
    adrp    x10, :got:dlsym
    ldr     x10, [x10, :got_lo12:dlsym]
    str     x10, [x19, #C_DLSYM]
    add     x10, x19, #C_RINGDATA
    str     x10, [x19, #C_RING]
    add     x10, x19, #C_TRY + 8         // C_TOP holds where the arena's top is kept
    str     x10, [x19, #C_TOP]
    bl      skip_crashed
1:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// arena: memfd seen twice; the state block: plain read+write memory. System calls only.
arena:
    adr     x0, mname
    mov     x1, #0
    mov     x8, #279
    svc     #0
    tbnz    x0, #63, 9f
    mov     x11, x0
    mov     x1, #ROOM
    mov     x8, #46
    svc     #0
    mov     x0, #0
    mov     x1, #ROOM
    mov     x2, #3
    mov     x3, #1
    mov     x4, x11
    mov     x5, #0
    mov     x8, #222
    svc     #0
    tbnz    x0, #63, 9f
    str     x0, [x19, #C_WV]
    mov     x0, #0
    mov     x1, #ROOM
    mov     x2, #5
    mov     x3, #1
    mov     x4, x11
    mov     x5, #0
    mov     x8, #222
    svc     #0
    tbnz    x0, #63, 9f
    str     x0, [x19, #C_RV]
    mov     x0, x11
    mov     x8, #57
    svc     #0
    mov     x0, #0                      // state: anonymous, private
    mov     x1, #STATE
    mov     x2, #3
    mov     x3, #0x22
    mov     x4, #-1
    mov     x5, #0
    mov     x8, #222
    svc     #0
    tbnz    x0, #63, 9f
    str     x0, [x19, #C_STATE]
9:  ret

// skip_crashed: boot.try holds the key (size ^ mtime ns) of a boot that had not yet run 120 frames. If boot.bin still has
// that key, it crashed the app: C_SEEN takes the key so `look` will not load it.
skip_crashed:
    stp     x29, x30, [sp, #-192]!
    mov     x29, sp
    stp     x20, x21, [sp, #16]
    str     x22, [sp, #48]
    bl      boot_key
    mov     x20, x0
    mov     x0, #-100
    adr     x1, tname
    mov     x2, #0
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 9f
    mov     x21, x0
    add     x1, sp, #32
    mov     x2, #8
    mov     x8, #63
    svc     #0
    mov     x22, x0
    mov     x0, x21
    mov     x8, #57
    svc     #0
    cmp     x22, #8
    b.ne    9f
    ldr     x9, [sp, #32]
    cmp     x9, x20
    b.ne    9f
    str     x20, [x19, #C_SEEN]
9:  ldp     x20, x21, [sp, #16]
    ldr     x22, [sp, #48]
    ldp     x29, x30, [sp], #192
    ret

// boot_key -> x0: size ^ mtime ns of boot.bin, 0 if it is not there
boot_key:
    mov     x0, #-100
    adr     x1, sname
    sub     sp, sp, #160
    mov     x2, sp
    mov     x3, #0
    mov     x8, #79                     // newfstatat
    svc     #0
    mov     x9, x0
    ldr     x10, [sp, #48]
    ldr     x11, [sp, #96]
    add     sp, sp, #160
    mov     x0, #0
    tbnz    x9, #63, 9f
    eor     x0, x10, x11
9:  ret

on_window:                              // (activity, window)
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    adrp    x19, ctx
    add     x19, x19, :lo12:ctx
    str     x1, [x19, #C_WIN]
    mov     x0, x1
    mov     w1, #0
    mov     w2, #0
    mov     w3, #1                      // RGBA 8888
    bl      ANativeWindow_setBuffersGeometry
    ldr     w9, [x19, #C_POSTED]
    cbnz    w9, 1f
    mov     w9, #1
    str     w9, [x19, #C_POSTED]
    bl      post
1:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
on_window_gone:
    adrp    x9, ctx
    add     x9, x9, :lo12:ctx
    str     xzr, [x9, #C_WIN]
    ret

post:
    stp     x29, x30, [sp, #-16]!
    bl      AChoreographer_getInstance
    adr     x1, frame
    mov     x2, #0
    bl      AChoreographer_postFrameCallback64
    ldp     x29, x30, [sp], #16
    ret

frame:                                  // (time ns, data)
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    adrp    x19, ctx
    add     x19, x19, :lo12:ctx
    str     x0, [x19, #C_TIME]
    ldr     x9, [x19, #C_FRAME]
    add     x9, x9, #1
    str     x9, [x19, #C_FRAME]
    mov     x10, #30
    udiv    x11, x9, x10
    msub    x11, x11, x10, x9
    cbnz    x11, 1f
    bl      look
1:  ldr     x9, [x19, #C_GOOD]          // a new boot that has run 120 frames is trusted: its mark goes
    cbz     x9, 2f
    sub     x9, x9, #1
    str     x9, [x19, #C_GOOD]
    cbnz    x9, 2f
    mov     x0, #-100
    adr     x1, tname
    mov     x2, #0
    mov     x8, #35                     // unlinkat
    svc     #0
2:  ldr     x0, [x19, #C_WIN]
    cbz     x0, 8f
    add     x1, sp, #40                 // ANativeWindow_Buffer: width, height, stride, format, bits
    mov     x2, #0
    bl      ANativeWindow_lock
    cbnz    w0, 8f
    ldr     x9, [sp, #56]
    str     x9, [x19, #C_PIX]
    ldrsw   x9, [sp, #48]
    str     x9, [x19, #C_STRIDE]
    ldrsw   x9, [sp, #44]
    str     x9, [x19, #C_H]
    ldrsw   x9, [sp, #40]
    str     x9, [x19, #C_W]
    mov     x0, x19
    add     x9, x19, #C_BOOT
    ldar    x9, [x9]
    blr     x9
    ldr     x0, [x19, #C_WIN]
    bl      ANativeWindow_unlockAndPost
8:  bl      post
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// look: boot.bin changed? Mark it in boot.try, append its code through the write view, flip the boot cell.
look:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x20, x21, [sp, #16]
    stp     x22, x23, [sp, #32]
    bl      boot_key
    cbz     x0, 9f
    ldr     x9, [x19, #C_SEEN]
    cmp     x0, x9
    b.eq    9f
    str     x0, [x19, #C_SEEN]
    str     x0, [sp, #48]
    mov     x0, #-100
    adr     x1, sname
    mov     x2, #0
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 9f
    mov     x20, x0
    ldr     x9, [x19, #C_TOP]
    ldr     x21, [x9]                   // the arena's top
    ldr     x22, [x19, #C_WV]
    add     x22, x22, x21
    mov     x23, #0
1:  mov     x0, x20                     // read it all, straight into the write view
    add     x1, x22, x23
    mov     x2, #ROOM
    sub     x2, x2, x21
    sub     x2, x2, x23
    cbz     x2, 7f
    mov     x8, #63
    svc     #0
    tbnz    x0, #63, 7f
    add     x23, x23, x0
    cbnz    x0, 1b
    mov     x0, x20
    mov     x8, #57
    svc     #0
    cbz     x23, 9f
    tst     x23, #3
    b.ne    9f
    mov     x0, #-100                   // the mark first: if this boot kills the app, the next start skips it
    adr     x1, tname
    mov     x2, #0x241                  // write, create, truncate
    mov     x3, #0x1b6
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 9f
    mov     x20, x0
    add     x1, sp, #48
    mov     x2, #8
    mov     x8, #64
    svc     #0
    mov     x0, x20
    mov     x8, #57
    svc     #0
    ldr     x14, [x19, #C_RV]
    add     x14, x14, x21
    add     x15, x14, x23
    mov     x16, x14
2:  dc      cvau, x16
    ic      ivau, x16
    add     x16, x16, #64
    cmp     x16, x15
    b.lo    2b
    dsb     ish
    isb
    add     x12, x21, x23
    add     x12, x12, #15
    and     x12, x12, #~15
    ldr     x9, [x19, #C_TOP]
    str     x12, [x9]
    mov     x9, #120
    str     x9, [x19, #C_GOOD]
    add     x16, x19, #C_BOOT
    stlr    x14, [x16]                  // live at the next frame
    b       9f
7:  mov     x0, x20
    mov     x8, #57
    svc     #0
9:  ldp     x22, x23, [sp, #32]
    ldp     x20, x21, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

// the boot until the stream brings another: the band follows the last touch by morphing; dark blue elsewhere
boot_default:
    ldr     x1, [x0, #C_STATE]          // state: f64 value, f64 target of the band's row
    ldr     w9, [x0, #C_HEAD]
    cbz     w9, 1f
    sub     w9, w9, #1
    and     w9, w9, #255
    ldr     x10, [x0, #C_RING]
    add     x10, x10, x9, lsl #4
    ldr     w11, [x10]
    cmp     w11, #1
    b.ne    1f
    ldr     s0, [x10, #12]
    fcvt    d0, s0
    str     d0, [x1, #8]
1:  ldp     d0, d1, [x1]
    fsub    d2, d1, d0
    ldr     x9, =0x3fc999999999999a     // a fifth of the way
    fmov    d3, x9
    fmadd   d0, d2, d3, d0
    str     d0, [x1]
    fcvtzs  x9, d0
    sub     x10, x9, #40
    add     x11, x9, #40
    ldr     x2, [x0, #C_STRIDE]
    ldr     x3, [x0, #C_H]
    ldr     x4, [x0, #C_W]
    ldr     x5, [x0, #C_PIX]
    mov     w12, #0x2010
    movk    w12, #0xff18, lsl #16
    mov     w13, #0xc040
    movk    w13, #0xff40, lsl #16
    mov     x14, #0
2:  cmp     x14, x3
    b.hs    9f
    cmp     x14, x10
    ccmp    x14, x11, #0, ge
    csel    w15, w13, w12, lt
    mul     x16, x14, x2
    add     x16, x5, x16, lsl #2
    mov     x17, #0
3:  cmp     x17, x4
    b.hs    4f
    str     w15, [x16, x17, lsl #2]
    add     x17, x17, #1
    b       3b
4:  add     x14, x14, #1
    b       2b
9:  ret

on_queue:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    adrp    x19, ctx
    add     x19, x19, :lo12:ctx
    str     x1, [x19, #C_QUEUE]
    mov     x0, #0
    bl      ALooper_forThread
    mov     x1, x0
    ldr     x0, [x19, #C_QUEUE]
    mov     w2, #1
    adr     x3, on_input
    mov     x4, #0
    bl      AInputQueue_attachLooper
    ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
on_queue_gone:
    stp     x29, x30, [sp, #-16]!
    mov     x0, x1
    bl      AInputQueue_detachLooper
    adrp    x9, ctx
    add     x9, x9, :lo12:ctx
    str     xzr, [x9, #C_QUEUE]
    ldp     x29, x30, [sp], #16
    ret

// on_input: every event goes into the ring for the verbs. Keys are reported handled, so the system does not act on them
// (except back, left to the system so the app can be left).
on_input:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #48]
    adrp    x19, ctx
    add     x19, x19, :lo12:ctx
1:  ldr     x0, [x19, #C_QUEUE]
    cbz     x0, 9f
    add     x1, sp, #32
    bl      AInputQueue_getEvent
    tbnz    w0, #31, 9f
    ldr     x0, [x19, #C_QUEUE]
    ldr     x1, [sp, #32]
    bl      AInputQueue_preDispatchEvent
    cbnz    w0, 1b
    ldr     w9, [x19, #C_HEAD]          // the slot for this event
    and     w9, w9, #255
    ldr     x21, [x19, #C_RING]
    add     x21, x21, x9, lsl #4
    ldr     x0, [sp, #32]
    bl      AInputEvent_getType
    mov     w20, #0
    cmp     w0, #2
    b.ne    2f
    mov     w9, #1                      // touch: action, x, y
    str     w9, [x21]
    ldr     x0, [sp, #32]
    bl      AMotionEvent_getAction
    str     w0, [x21, #4]
    ldr     x0, [sp, #32]
    mov     x1, #0
    bl      AMotionEvent_getX
    str     s0, [x21, #8]
    ldr     x0, [sp, #32]
    mov     x1, #0
    bl      AMotionEvent_getY
    str     s0, [x21, #12]
    mov     w20, #1
    b       3f
2:  cmp     w0, #1
    b.ne    4f
    mov     w9, #2                      // key: action, keycode, meta state
    str     w9, [x21]
    ldr     x0, [sp, #32]
    bl      AKeyEvent_getAction
    str     w0, [x21, #4]
    ldr     x0, [sp, #32]
    bl      AKeyEvent_getKeyCode
    str     w0, [x21, #8]
    mov     w22, w0
    ldr     x0, [sp, #32]
    bl      AKeyEvent_getMetaState
    str     w0, [x21, #12]
    cmp     w22, #4                     // back: the system's
    cset    w20, ne
3:  dmb     ish
    ldr     w9, [x19, #C_HEAD]
    add     w9, w9, #1
    str     w9, [x19, #C_HEAD]
4:  ldr     x0, [x19, #C_QUEUE]
    ldr     x1, [sp, #32]
    mov     w2, w20
    bl      AInputQueue_finishEvent
    b       1b
9:  mov     w0, #1
    ldp     x21, x22, [sp, #48]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

mname: .asciz "flow"
sname: .asciz "/sdcard/Android/media/t.flow/boot.bin"
tname: .asciz "/sdcard/Android/media/t.flow/boot.try"
    .bss
    .balign 16
ctx: .space 256 + 4096
