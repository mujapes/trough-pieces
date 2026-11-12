// Dates: the calendar's arithmetic (built-ins 54 to 56). The Date object, its reading of text and its writing are in prelude.js,
// on these. The clock is what the host last gave through the entry `clock` (W_CLOCK, milliseconds since 1970 as a number;
// W_TZ, the minutes the local time is ahead of universal time).
    .equ W_CLOCK, 480
    .equ W_TZ, 488
// 54 now(which): 0 the clock, anything else the minutes ahead
n_now:
    NIN
    ARGNUM  0
    fcvtzs  x0, d0
    ldr     d0, [x19, #W_CLOCK]
    cbz     x0, n_num
    ldr     x9, [x19, #W_TZ]
    scvtf   d0, x9
    b       n_num
// 55 (year, month from 0; whole numbers, the month any size) -> the days from 1 January 1970 to the first of that month.
// By the 400-year turn of 146097 days, the year taken as beginning in March.
n_dayfrom:
    NIN
    ARGNUM  0
    fcvtms  x0, d0
    str     x0, [sp, #40]
    ARGNUM  1
    fcvtms  x1, d0
    ldr     x0, [sp, #40]
    mov     x9, #12
    sdiv    x2, x1, x9
    msub    x3, x2, x9, x1
    cmp     x3, #0
    b.ge    1f
    add     x3, x3, #12
    sub     x2, x2, #1
1:  add     x0, x0, x2
    cmp     x3, #2
    b.ge    2f
    sub     x0, x0, #1
    add     x3, x3, #12
2:  sub     x3, x3, #2                  // the month counted from March
    mov     x9, #400
    sdiv    x4, x0, x9
    msub    x5, x4, x9, x0
    cmp     x5, #0
    b.ge    3f
    add     x5, x5, #400
    sub     x4, x4, #1
3:  mov     x9, #153                    // x4 which turn, x5 the year within it
    mul     x6, x3, x9
    add     x6, x6, #2
    mov     x9, #5
    udiv    x6, x6, x9
    mov     x9, #365
    mul     x7, x5, x9
    add     x7, x7, x5, lsr #2
    mov     x9, #100
    udiv    x8, x5, x9
    sub     x7, x7, x8
    add     x7, x7, x6
    ldr     x9, =146097
    madd    x7, x4, x9, x7
    ldr     x9, =719468
    sub     x7, x7, x9
    scvtf   d0, x7
    b       n_num
// 56 (days from 1 January 1970) -> (year * 12 + month from 0) * 32 + day of the month
n_civil:
    NIN
    ARGNUM  0
    fcvtms  x0, d0
    ldr     x9, =719468
    add     x0, x0, x9
    ldr     x9, =146097
    sdiv    x1, x0, x9
    msub    x2, x1, x9, x0
    cmp     x2, #0
    b.ge    1f
    add     x2, x2, x9
    sub     x1, x1, #1
1:  mov     x9, #1460                   // x1 which turn, x2 the day within it
    udiv    x3, x2, x9
    sub     x4, x2, x3
    ldr     x9, =36524
    udiv    x3, x2, x9
    add     x4, x4, x3
    ldr     x9, =146096
    udiv    x3, x2, x9
    sub     x4, x4, x3
    mov     x9, #365
    udiv    x4, x4, x9                  // the year within the turn
    mul     x5, x4, x9
    add     x5, x5, x4, lsr #2
    mov     x9, #100
    udiv    x3, x4, x9
    sub     x5, x5, x3
    sub     x5, x2, x5                  // the day within the year (from 1 March)
    mov     x9, #5
    mul     x6, x5, x9
    add     x6, x6, #2
    mov     x9, #153
    udiv    x6, x6, x9                  // the month from March
    mul     x7, x6, x9
    add     x7, x7, #2
    mov     x9, #5
    udiv    x7, x7, x9
    sub     x7, x5, x7
    add     x7, x7, #1
    mov     x9, #400
    madd    x4, x1, x9, x4
    cmp     x6, #10
    b.lt    2f
    sub     x6, x6, #12
    add     x4, x4, #1
2:  add     x6, x6, #2
    mov     x9, #12
    madd    x4, x4, x9, x6
    lsl     x4, x4, #5
    add     x4, x4, x7
    scvtf   d0, x4
    b       n_num
    .ltorg
