// libflow, written by hand (ARM64) [by Opus]: the whole of the new Trough's own code. Android's NativeActivity loads it.
// Each frame (Choreographer): the field steps, the draw cell paints the window, the stream is looked at every 30 frames.
// A touch writes field value 0's target (the finger's row), so the band follows the finger by morphing.
// Verbs: draw(x0 pixels, x1 field, x2 stride in pixels, x3 height, x4 width) -> ignored. The stream: the file
// /sdcard/Android/media/t.flow/draw.bin, whole code of a draw verb; a new size or time makes it live at the next frame.
    .equ ROOM, 4194304
    .equ S_WV, 0
    .equ S_RV, 8
    .equ S_CELL, 16
    .equ S_WIN, 24
    .equ S_QUEUE, 32
    .equ S_COUNT, 40
    .equ S_SEEN, 48
    .equ S_TOP, 56
    .equ S_POSTED, 64
    .equ S_FIELD, 128
    .text
    .global ANativeActivity_onCreate
ANativeActivity_onCreate:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    adrp    x19, st
    add     x19, x19, :lo12:st
    ldr     x9, [x0]                    // callbacks
    adr     x10, on_window
    str     x10, [x9, #56]              // onNativeWindowCreated
    adr     x10, on_window_gone
    str     x10, [x9, #80]              // onNativeWindowDestroyed
    adr     x10, on_queue
    str     x10, [x9, #88]              // onInputQueueCreated
    adr     x10, on_queue_gone
    str     x10, [x9, #96]              // onInputQueueDestroyed
    ldr     x10, [x19, #S_RV]
    cbnz    x10, 1f                     // the arena outlives the activity: made once per process
    bl      arena
    adr     x10, draw_default
    str     x10, [x19, #S_CELL]
    mov     w10, #1                     // field: one value (the band's row), starting at 400
    str     w10, [x19, #S_FIELD]
    mov     x10, #0x4079000000000000    // 400.0
    str     x10, [x19, #S_FIELD + 8]
    str     x10, [x19, #S_FIELD + 16]
1:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

// arena: memfd seen twice, by system calls
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
    str     x0, [x19, #S_WV]
    mov     x0, #0
    mov     x1, #ROOM
    mov     x2, #5
    mov     x3, #1
    mov     x4, x11
    mov     x5, #0
    mov     x8, #222
    svc     #0
    tbnz    x0, #63, 9f
    str     x0, [x19, #S_RV]
9:  ret

on_window:                              // (activity, window)
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    adrp    x19, st
    add     x19, x19, :lo12:st
    str     x1, [x19, #S_WIN]
    mov     x0, x1
    mov     w1, #0
    mov     w2, #0
    mov     w3, #1                      // RGBA 8888
    bl      ANativeWindow_setBuffersGeometry
    ldr     w9, [x19, #S_POSTED]
    cbnz    w9, 1f
    mov     w9, #1
    str     w9, [x19, #S_POSTED]
    bl      post
1:  ldr     x19, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
on_window_gone:
    adrp    x9, st
    add     x9, x9, :lo12:st
    str     xzr, [x9, #S_WIN]
    ret

post:                                   // the next frame
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
    adrp    x19, st
    add     x19, x19, :lo12:st
    ldr     x9, [x19, #S_COUNT]
    add     x9, x9, #1
    str     x9, [x19, #S_COUNT]
    mov     x10, #30
    udiv    x11, x9, x10
    msub    x11, x11, x10, x9
    cbnz    x11, 1f
    bl      look
1:  add     x0, x19, #S_FIELD           // the field: a fifth of the way each frame
    mov     x3, #13107
    bl      step
    ldr     x0, [x19, #S_WIN]
    cbz     x0, 8f
    add     x1, sp, #40                 // ANativeWindow_Buffer: width, height, stride, format, bits
    mov     x2, #0
    bl      ANativeWindow_lock
    cbnz    w0, 8f
    ldr     x0, [sp, #56]               // bits
    add     x1, x19, #S_FIELD
    ldrsw   x2, [sp, #48]               // stride
    ldrsw   x3, [sp, #44]               // height
    ldrsw   x4, [sp, #40]               // width
    add     x9, x19, #S_CELL
    ldar    x9, [x9]
    blr     x9
    ldr     x0, [x19, #S_WIN]
    bl      ANativeWindow_unlockAndPost
8:  bl      post
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #96
    ret

// look: has the stream file changed (size or time)? Then its code is appended through the write view and the cell flipped.
look:
    stp     x29, x30, [sp, #-176]!
    mov     x29, sp
    stp     x20, x21, [sp, #16]
    mov     x0, #-100
    adr     x1, sname
    mov     x2, #0
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, 9f
    mov     x20, x0
    add     x1, sp, #32                 // struct stat: size at 48, mtime ns at 88..
    mov     x8, #80                     // fstat
    svc     #0
    ldr     x9, [sp, #32 + 48]
    ldr     x10, [sp, #32 + 96]         // mtime nanoseconds
    eor     x10, x10, x9
    ldr     x11, [x19, #S_SEEN]
    cmp     x10, x11
    b.eq    8f
    str     x10, [x19, #S_SEEN]
    cbz     x9, 8f
    tst     x9, #3
    b.ne    8f
    ldr     x21, [x19, #S_TOP]
    add     x12, x21, x9
    mov     x13, #ROOM
    cmp     x12, x13
    b.hi    8f
    mov     x0, x20                     // read it all, straight into the write view
    ldr     x1, [x19, #S_WV]
    add     x1, x1, x21
    mov     x2, x9
    mov     x8, #63
    svc     #0
    cmp     x0, x9
    b.ne    8f
    ldr     x14, [x19, #S_RV]
    add     x14, x14, x21
    add     x15, x14, x9
    mov     x16, x14
2:  dc      cvau, x16
    ic      ivau, x16
    add     x16, x16, #64
    cmp     x16, x15
    b.lo    2b
    dsb     ish
    isb
    add     x12, x21, x9
    add     x12, x12, #15
    and     x12, x12, #~15
    str     x12, [x19, #S_TOP]
    add     x16, x19, #S_CELL
    stlr    x14, [x16]                  // live at the next frame
8:  mov     x0, x20
    mov     x8, #57                     // close
    svc     #0
9:  ldp     x20, x21, [sp, #16]
    ldp     x29, x30, [sp], #176
    ret

// step: flow's field verb (the same as flow/impl.S): x0 field, x3 share of 65536
step:
    ldr     w9, [x0]
    add     x10, x0, #8
    scvtf   d2, x3
    mov     x11, #0x3ef0000000000000
    fmov    d3, x11
    fmul    d2, d2, d3
    mov     x11, #0x3e00000000000000
    fmov    d4, x11
1:  cbz     w9, 9f
    ldp     d0, d1, [x10]
    fsub    d5, d1, d0
    fabs    d6, d5
    fcmp    d6, d4
    b.ls    2f
    fmadd   d0, d5, d2, d0
    b       3f
2:  fmov    d0, d1
3:  str     d0, [x10], #16
    sub     w9, w9, #1
    b       1b
9:  ret

// the draw verb until the stream brings another: dark blue, and a band 80 rows high centred on field value 0
draw_default:
    ldr     d0, [x1, #8]
    fcvtzs  x9, d0
    sub     x10, x9, #40                // band from
    add     x11, x9, #40                // to
    mov     w12, #0x2010
    movk    w12, #0xff18, lsl #16       // ABGR: dark blue
    mov     w13, #0xc040
    movk    w13, #0xff40, lsl #16       // the band: light blue
    mov     x14, #0                     // row
1:  cmp     x14, x3
    b.hs    9f
    cmp     x14, x10
    ccmp    x14, x11, #0, ge
    csel    w15, w13, w12, lt
    mul     x16, x14, x2
    add     x16, x0, x16, lsl #2
    mov     x17, #0
2:  cmp     x17, x4
    b.hs    3f
    str     w15, [x16, x17, lsl #2]
    add     x17, x17, #1
    b       2b
3:  add     x14, x14, #1
    b       1b
9:  ret

on_queue:                               // (activity, queue): input comes through the main looper
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x19, [sp, #16]
    adrp    x19, st
    add     x19, x19, :lo12:st
    str     x1, [x19, #S_QUEUE]
    mov     x0, #0
    bl      ALooper_forThread
    mov     x1, x0
    ldr     x0, [x19, #S_QUEUE]
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
    adrp    x9, st
    add     x9, x9, :lo12:st
    str     xzr, [x9, #S_QUEUE]
    ldp     x29, x30, [sp], #16
    ret

on_input:                               // (fd, events, data) -> 1 keep listening
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    adrp    x19, st
    add     x19, x19, :lo12:st
1:  ldr     x0, [x19, #S_QUEUE]
    cbz     x0, 9f
    add     x1, sp, #32
    bl      AInputQueue_getEvent
    tbnz    w0, #31, 9f
    ldr     x0, [x19, #S_QUEUE]
    ldr     x1, [sp, #32]
    bl      AInputQueue_preDispatchEvent
    cbnz    w0, 1b
    ldr     x0, [sp, #32]
    bl      AInputEvent_getType
    mov     w20, #0
    cmp     w0, #2                      // motion
    b.ne    2f
    ldr     x0, [sp, #32]
    mov     x1, #0
    bl      AMotionEvent_getY
    fcvt    d0, s0
    str     d0, [x19, #S_FIELD + 16]    // the finger's row is value 0's target: the band morphs there
    mov     w20, #1
2:  ldr     x0, [x19, #S_QUEUE]
    ldr     x1, [sp, #32]
    mov     w2, w20
    bl      AInputQueue_finishEvent
    b       1b
9:  mov     w0, #1
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

mname: .asciz "flow"
sname: .asciz "/sdcard/Android/media/t.flow/draw.bin"
    .bss
    .balign 16
st: .space 256
