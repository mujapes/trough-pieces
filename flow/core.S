// core, written by hand (ARM64), no C library [by Opus]: the Flow memory straight from the kernel.
// flowcore <code file>: one memfd mapped twice (write view, run view), the file's code appended through the write view,
// a cell pointed at it in the run view, and the verb run as flow's step on a field until it rests. Prints the frames taken
// and exits 0 if every value landed exactly on its target. Only system calls; nothing linked.
    .equ ROOM, 1048576
    .text
    .global _start
_start:
    ldr     x0, [sp]                    // argc
    cmp     x0, #2
    b.lt    bad
    ldr     x20, [sp, #16]              // argv[1]
    adr     x0, name                    // memfd_create("flow", 0)
    mov     x1, #0
    mov     x8, #279
    svc     #0
    tbnz    x0, #63, bad
    mov     x21, x0
    mov     x1, #ROOM                   // ftruncate
    mov     x8, #46
    svc     #0
    cbnz    x0, bad
    mov     x0, #0                      // write view: mmap(0, ROOM, RW, SHARED, fd, 0)
    mov     x1, #ROOM
    mov     x2, #3
    mov     x3, #1
    mov     x4, x21
    mov     x5, #0
    mov     x8, #222
    svc     #0
    tbnz    x0, #63, bad
    mov     x22, x0
    mov     x0, #0                      // run view: read + execute
    mov     x1, #ROOM
    mov     x2, #5
    mov     x3, #1
    mov     x4, x21
    mov     x5, #0
    mov     x8, #222
    svc     #0
    tbnz    x0, #63, bad
    mov     x23, x0
    mov     x0, #-100                   // openat(AT_FDCWD, path, O_RDONLY)
    mov     x1, x20
    mov     x2, #0
    mov     x8, #56
    svc     #0
    tbnz    x0, #63, bad
    mov     x24, x0
    mov     x25, #0                     // read the code straight into the write view
1:  mov     x0, x24
    add     x1, x22, x25
    mov     x2, #65536
    mov     x8, #63
    svc     #0
    tbnz    x0, #63, bad
    add     x25, x25, x0
    cbnz    x0, 1b
    cbz     x25, bad
    mov     x0, x23                     // the run view's copy of those bytes: make the instruction cache see them
    add     x1, x23, x25
2:  dc      cvau, x0
    ic      ivau, x0
    add     x0, x0, #64
    cmp     x0, x1
    b.lo    2b
    dsb     ish
    isb
    adr     x9, cell
    stlr    x23, [x9]                   // the cell now holds the verb
    mov     x26, #0                     // frames
3:  adr     x0, field
    mov     x1, #0
    mov     x2, #0
    mov     x3, #6554
    adr     x4, cell
    ldar    x9, [x4]
    blr     x9
    cbz     x0, 4f
    add     x26, x26, #1
    cmp     x26, #1000
    b.lo    3b
    b       bad
4:  adr     x9, field                   // landed exactly: values equal targets bit for bit
    ldr     w10, [x9], #8
5:  cbz     w10, 6f
    ldp     x11, x12, [x9], #16
    cmp     x11, x12
    b.ne    bad
    sub     w10, w10, #1
    b       5b
6:  adr     x1, out + 15                // frames as digits, then a new line
    mov     w2, #10
    strb    w2, [x1]
    mov     x3, #10
7:  udiv    x4, x26, x3
    msub    x5, x4, x3, x26
    add     w5, w5, #'0'
    strb    w5, [x1, #-1]!
    mov     x26, x4
    cbnz    x26, 7b
    mov     x0, #1
    adr     x2, out + 16
    sub     x2, x2, x1
    mov     x8, #64
    svc     #0
    mov     x0, #0
    b       9f
bad:
    mov     x0, #1
9:  mov     x8, #93
    svc     #0
name: .asciz "flow"
    .data
    .balign 16
cell:  .quad 0
field: .word 3, 0
       .double 0, 100, 50, 50, 1e6, -2.5
out:   .space 16
