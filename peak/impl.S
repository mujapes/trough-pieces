// Peak, written directly for ARM64 by the agent. Position independent; calls nothing.
    .text
    .global peak
peak:                           // x0 = samples, x1 = count
    movi v16.4s,#0
    mov w5,#0
    cmp x1,#8
    b.lt 2f
1:  ldr q0,[x0],#16             // eight samples
    sshll v1.4s,v0.4h,#0        // widened first: the absolute value of -32768 does not fit in 16 bits
    sshll2 v2.4s,v0.8h,#0
    abs v1.4s,v1.4s
    abs v2.4s,v2.4s
    umax v16.4s,v16.4s,v1.4s
    umax v16.4s,v16.4s,v2.4s
    sub x1,x1,#8
    cmp x1,#8
    b.ge 1b
2:  umaxv s0,v16.4s
    fmov w6,s0
    cbz x1,4f
3:  ldrsh w4,[x0],#2            // the last few, one at a time
    cmp w4,#0
    cneg w4,w4,lt
    cmp w4,w5
    csel w5,w4,w5,gt
    subs x1,x1,#1
    b.ne 3b
4:  cmp w6,w5
    csel w0,w6,w5,hi
    ret
