// flow, written by hand (ARM64) [by Opus]: the field. Meaning: intent.md.
// step(x0 field, x1 -, x2 -, x3 rate (0-65536 per frame), x4 table) -> how many values are still moving.
// Field: u32 count at 0, u32 spare, then count pairs of doubles (value, target) from byte 8.
    .text
    .global step
step:
    ldr     w9, [x0]
    add     x10, x0, #8
    scvtf   d2, x3
    mov     x11, #0x3ef0000000000000    // 1/65536
    fmov    d3, x11
    fmul    d2, d2, d3                  // the share of the distance covered this frame
    mov     x11, #0x3e00000000000000    // close enough to be there: about 4.7e-10
    fmov    d4, x11
    mov     x0, #0
1:  cbz     w9, 9f
    ldp     d0, d1, [x10]
    fsub    d5, d1, d0
    fabs    d6, d5
    fcmp    d6, d4
    b.ls    2f
    fmadd   d0, d5, d2, d0
    add     x0, x0, #1
    b       3f
2:  fmov    d0, d1                      // arrived: exactly the target, so no endless creep
3:  str     d0, [x10], #16
    sub     w9, w9, #1
    b       1b
9:  ret
