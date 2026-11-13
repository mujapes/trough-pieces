// script, written by hand (ARM64): Trough's own JavaScript engine. The meaning and the plan are script/intent.md.
// This file: the words (stage 1). Entries: x0 block, x1 numbers (16-bit), x2 how many, x3 argument, x4 call table. Calls nothing.
// While words are being read: x20 the text, x21 how long, x22 where we are, w23 the word's kind, w24 its id (which keyword or
// punctuation), x25 where it starts, x26 how long it is, w27 whether a line ended before it, w28 whether a slash here would
// begin a pattern, d8 a number's value.
// Kinds: 0 the end, 1 name, 2 keyword, 3 number, 4 string, 5 template, 6 punctuation, 7 pattern, 8 a number meant as a big
// integer (ends in n), 9 something that is not a word of the language.
    .equ K_END, 0
    .equ K_NAME, 1
    .equ K_KEYWORD, 2
    .equ K_NUMBER, 3
    .equ K_STRING, 4
    .equ K_TEMPLATE, 5
    .equ K_PUNCT, 6
    .equ K_PATTERN, 7
    .equ K_BIGINT, 8
    .equ K_BAD, 9
// CH: the byte at x22 + \ahead -> \reg, or 0 past the end
    .macro  CH reg, ahead=0
    add     x9, x22, #\ahead
    mov     \reg, #0
    cmp     x9, x21
    b.hs    90f
    ldrb    \reg, [x20, x9]
90:
    .endm
// is_name_part: can the byte w0 be inside a name -> flags: eq if so. (Letters, digits, $ and _; and any byte of a character
// beyond ASCII, which is taken as a letter for now.) Uses w9.
    .macro  NAMEPART reg, no
    cmp     \reg, #0x80
    b.hs    91f
    orr     w9, \reg, #0x20
    sub     w9, w9, #'a'
    cmp     w9, #25
    b.ls    91f
    sub     w9, \reg, #'0'
    cmp     w9, #9
    b.ls    91f
    cmp     \reg, #'$'
    b.eq    91f
    cmp     \reg, #'_'
    b.ne    \no
91:
    .endm
// next_word: reads the next word at x22 into w23-w27 and d8; moves x22 past it. Uses x0-x17.
next_word:
    mov     w27, #0
w_space:                                // what is between words: spaces, line ends, comments
    cmp     x22, x21
    b.hs    w_end
    ldrb    w0, [x20, x22]
    cmp     w0, #' '
    b.eq    1f
    cmp     w0, #9
    b.eq    1f
    cmp     w0, #11
    b.eq    1f
    cmp     w0, #12
    b.eq    1f
    cmp     w0, #10
    b.eq    2f
    cmp     w0, #13
    b.eq    2f
    cmp     w0, #0xc2                   // no-break space
    b.ne    3f
    CH      w1, 1
    cmp     w1, #0xa0
    b.ne    w_word
    add     x22, x22, #2
    b       w_space
3:  cmp     w0, #0xe2                   // the two line separators beyond ASCII
    b.ne    4f
    CH      w1, 1
    cmp     w1, #0x80
    b.ne    w_word
    CH      w1, 2
    and     w2, w1, #0xfe
    cmp     w2, #0xa8
    b.ne    w_word
    add     x22, x22, #3
    mov     w27, #1
    b       w_space
4:  cmp     w0, #'/'
    b.ne    w_word
    CH      w1, 1
    cmp     w1, #'/'
    b.ne    6f
5:  cmp     x22, x21                    // to the end of the line
    b.hs    w_end
    ldrb    w0, [x20, x22]
    cmp     w0, #10
    b.eq    w_space
    cmp     w0, #13
    b.eq    w_space
    add     x22, x22, #1
    b       5b
6:  cmp     w1, #'*'
    b.ne    w_word
    add     x22, x22, #2
7:  cmp     x22, x21                    // to the closing star and slash; a line end inside counts as one
    b.hs    w_end
    ldrb    w0, [x20, x22]
    add     x22, x22, #1
    cmp     w0, #10
    csinc   w27, w27, wzr, ne
    cmp     w0, #'*'
    b.ne    7b
    CH      w1
    cmp     w1, #'/'
    b.ne    7b
    add     x22, x22, #1
    b       w_space
1:  add     x22, x22, #1
    b       w_space
2:  add     x22, x22, #1
    mov     w27, #1
    b       w_space
w_end:
    mov     w23, #K_END
    mov     w24, #0
    mov     x25, x22
    mov     x26, #0
    ret
w_word:
    mov     x25, x22
    mov     w24, #0
    NAMEPART w0, w_not_name
    sub     w9, w0, #'0'
    cmp     w9, #9
    b.ls    w_number
1:  add     x22, x22, #1                // a name, or a keyword
    cmp     x22, x21
    b.hs    2f
    ldrb    w0, [x20, x22]
    NAMEPART w0, 2f
    b       1b
2:  sub     x26, x22, x25
    mov     w23, #K_NAME
    mov     w28, #0
    adr     x1, t_keywords              // is it one of the keywords?
    mov     w2, #0
3:  ldrb    w3, [x1]
    cbz     w3, 9f
    cmp     x3, x26
    b.ne    5f
    mov     x4, #0
4:  add     x5, x1, x4
    ldrb    w5, [x5, #1]
    add     x6, x25, x4
    ldrb    w6, [x20, x6]
    cmp     w5, w6
    b.ne    5f
    add     x4, x4, #1
    cmp     x4, x26
    b.lo    4b
    mov     w23, #K_KEYWORD
    mov     w24, w2
    mov     w28, #1                     // after most keywords a slash begins a pattern; not after this, super, null, true, false
    cmp     w2, #24                     // (this)
    b.eq    8f
    cmp     w2, #22                     // (super)
    b.eq    8f
    cmp     w2, #40
    b.lo    9f
8:  mov     w28, #0
9:  ret
5:  add     x1, x1, x3
    add     x1, x1, #1
    add     w2, w2, #1
    b       3b
w_not_name:
    cmp     w0, #'.'
    b.ne    1f
    CH      w1, 1
    sub     w9, w1, #'0'
    cmp     w9, #9
    b.ls    w_number
1:  cmp     w0, #'"'
    b.eq    w_quoted
    cmp     w0, #39
    b.eq    w_quoted
    cmp     w0, #'`'
    b.eq    w_template
    cmp     w0, #'/'
    b.ne    w_punct
    cbz     w28, w_punct
    add     x22, x22, #1                // a pattern: to the closing slash, which does not count inside [ ] or after a backslash
    mov     w2, #0
1:  cmp     x22, x21
    b.hs    w_bad
    ldrb    w0, [x20, x22]
    add     x22, x22, #1
    cmp     w0, #10
    b.eq    w_bad
    cmp     w0, #'\\'
    b.ne    2f
    add     x22, x22, #1
    b       1b
2:  cmp     w0, #'['
    csinc   w2, w2, wzr, ne
    cmp     w0, #']'
    csel    w2, wzr, w2, eq
    cmp     w0, #'/'
    b.ne    1b
    cbnz    w2, 1b
3:  cmp     x22, x21                    // and its flags
    b.hs    4f
    ldrb    w0, [x20, x22]
    NAMEPART w0, 4f
    add     x22, x22, #1
    b       3b
4:  mov     w23, #K_PATTERN
    sub     x26, x22, x25
    mov     w28, #0
    ret
w_punct:
    adr     x1, t_punct                 // punctuation: the longest that fits
    mov     w2, #0
1:  ldrb    w3, [x1]
    cbz     w3, w_bad_one
    add     x4, x22, x3
    cmp     x4, x21
    b.hi    3f
    mov     x4, #0
2:  add     x5, x1, x4
    ldrb    w5, [x5, #1]
    add     x6, x22, x4
    ldrb    w6, [x20, x6]
    cmp     w5, w6
    b.ne    3f
    add     x4, x4, #1
    cmp     x4, x3
    b.lo    2b
    cmp     w2, #19                     // "?." is not that when a digit follows: then it is ? and a number
    b.ne    4f
    CH      w5, 2
    sub     w5, w5, #'0'
    cmp     w5, #9
    b.ls    3f
4:  add     x22, x22, x3
    mov     x26, x3
    mov     w23, #K_PUNCT
    mov     w24, w2
    sub     w5, w2, #20                 // ++ and -- leave it as it was (after a value they follow it, and a slash divides)
    cmp     w5, #1
    b.ls    6f
    mov     w28, #1                     // after punctuation a slash begins a pattern, except after ) and ]
    cmp     w2, #36
    b.eq    5f
    cmp     w2, #38
    b.ne    6f
5:  mov     w28, #0
6:  ret
3:  add     x1, x1, x3
    add     x1, x1, #1
    add     w2, w2, #1
    b       1b
w_bad_one:
    add     x22, x22, #1
w_bad:
    cmp     x22, x21                    // (a backslash may have stepped one past the end)
    csel    x22, x21, x22, hi
    mov     w23, #K_BAD
    sub     x26, x22, x25
    mov     w28, #1
    ret
w_quoted:                               // a string: to the same quote, a backslash taking what follows with it
    mov     w2, w0
    add     x22, x22, #1
1:  cmp     x22, x21
    b.hs    w_bad
    ldrb    w0, [x20, x22]
    add     x22, x22, #1
    cmp     w0, w2
    b.eq    3f
    cmp     w0, #10
    b.eq    w_bad
    cmp     w0, #13
    b.eq    w_bad
    cmp     w0, #'\\'
    b.ne    1b
    cmp     x22, x21
    b.hs    w_bad
    ldrb    w0, [x20, x22]
    add     x22, x22, #1
    cmp     w0, #13                     // a backslash before a line end joins the lines; CR LF is one line end
    b.ne    1b
    CH      w1
    cmp     w1, #10
    cinc    x22, x22, eq
    b       1b
3:  mov     w23, #K_STRING
    sub     x26, x22, x25
    mov     w28, #0
    ret
w_template:                             // a template: to the closing backtick; ${ ... } inside may hold anything, strings and
    add     x22, x22, #1                // templates of its own included: for each template entered from inside a ${ },
    mov     x2, #-1                     // how deep in braces that ${ } was waits on the stack (under them all: -1)
    str     x2, [sp, #-16]!
    mov     w2, #0                      // how deep in braces (0: in the template's own text)
    mov     w3, #0                      // inside a quoted string within ${ }: its quote, or 0
1:  cmp     x22, x21
    b.lo    10f
11: ldr     x1, [sp], #16
    cmn     x1, #1
    b.ne    11b
    b       w_bad
10: ldrb    w0, [x20, x22]
    add     x22, x22, #1
    cmp     w0, #'\\'
    b.ne    2f
    add     x22, x22, #1
    b       1b
2:  cbz     w3, 3f
    cmp     w0, w3
    csel    w3, wzr, w3, eq
    b       1b
3:  cbz     w2, 5f
    cmp     w0, #'"'
    b.eq    4f
    cmp     w0, #39
    b.eq    4f
    cmp     w0, #'`'
    b.ne    31f
    str     x2, [sp, #-16]!
    mov     w2, #0
    b       1b
31: cmp     w0, #'{'
    cinc    w2, w2, eq
    cmp     w0, #'}'
    b.ne    1b
    sub     w2, w2, #1
    b       1b
4:  mov     w3, w0
    b       1b
5:  cmp     w0, #'`'
    b.ne    51f
    ldr     x2, [sp], #16               // this template is over: back in the ${ } it stood in, or done
    cmn     x2, #1
    b.eq    6f
    b       1b
51: cmp     w0, #'$'
    b.ne    1b
    CH      w1
    cmp     w1, #'{'
    b.ne    1b
    add     x22, x22, #1
    mov     w2, #1
    b       1b
6:  mov     w23, #K_TEMPLATE
    sub     x26, x22, x25
    mov     w28, #0
    ret
w_number:
    mov     w23, #K_NUMBER
    mov     w28, #0
    cmp     w0, #'0'
    b.ne    n_decimal
    CH      w1, 1
    orr     w1, w1, #0x20
    mov     w2, #16
    cmp     w1, #'x'
    b.eq    1f
    mov     w2, #8
    cmp     w1, #'o'
    b.eq    1f
    mov     w2, #2
    cmp     w1, #'b'
    b.ne    n_decimal
1:  add     x22, x22, #2                // another base: each digit in turn
    ucvtf   d1, w2
    movi    d8, #0
    mov     w4, #0
2:  cmp     x22, x21
    b.hs    4f
    ldrb    w0, [x20, x22]
    cmp     w0, #'_'
    b.eq    3f
    sub     w5, w0, #'0'
    cmp     w5, #9
    b.ls    5f
    orr     w5, w0, #0x20
    sub     w5, w5, #'a'
    cmp     w5, #5
    b.hi    4f
    add     w5, w5, #10
5:  cmp     w5, w2
    b.hs    4f
    ucvtf   d2, w5
    fmadd   d8, d8, d1, d2
    add     w4, w4, #1
3:  add     x22, x22, #1
    b       2b
4:  cbz     w4, w_bad
    b       n_done
n_decimal:
    mov     w12, #0                     // the power of ten that is written out after an e, if any
    mov     x1, #0                      // the digits as a whole number (the first 19), and the power of ten to apply
    mov     w2, #0
    mov     w3, #0                      // digits taken
    mov     w4, #0                      // past the point?
1:  cmp     x22, x21
    b.hs    5f
    ldrb    w0, [x20, x22]
    cmp     w0, #'_'
    b.eq    4f
    cmp     w0, #'.'
    b.ne    2f
    cbnz    w4, 5f
    mov     w4, #1
    b       4f
2:  sub     w5, w0, #'0'
    cmp     w5, #9
    b.hi    5f
    cmp     w3, #19
    b.hs    3f
    mov     x6, #10
    madd    x1, x1, x6, x5
    cbz     x1, 6f                      // leading zeros are not digits taken
    add     w3, w3, #1
6:  sub     w2, w2, w4
    b       4f
3:  eor     w6, w4, #1                  // too many digits to hold: only their place counts
    add     w2, w2, w6
4:  add     x22, x22, #1
    b       1b
5:  orr     w5, w0, #0x20               // an exponent?
    cmp     w5, #'e'
    b.ne    9f
    cmp     x22, x21
    b.hs    9f
    CH      w5, 1
    mov     w6, #0
    mov     x7, #1
    cmp     w5, #'-'
    cset    w6, eq
    cinc    x7, x7, eq
    cmp     w5, #'+'
    cinc    x7, x7, eq
    add     x9, x22, x7
    cmp     x9, x21
    b.hs    9f
    ldrb    w5, [x20, x9]
    sub     w5, w5, #'0'
    cmp     w5, #9
    b.hi    9f
    mov     x22, x9
    mov     w10, #0
7:  cmp     x22, x21
    b.hs    8f
    ldrb    w5, [x20, x22]
    sub     w5, w5, #'0'
    cmp     w5, #9
    b.hi    8f
    mov     w11, #10
    madd    w10, w10, w11, w5
    mov     w11, #10000
    cmp     w10, w11
    csel    w10, w11, w10, hi
    add     x22, x22, #1
    b       7b
8:  cmp     w6, #0
    cneg    w10, w10, ne
    mov     w12, w10
    add     w2, w2, w10
9:  ucvtf   d8, x1                      // the digits times ten to that power. Exact when the power is within 22 either way and
    cbz     x1, n_done                  // the digits fit 53 bits; anything else is worked out in long arithmetic (n_exact)
    cmp     w3, #19
    b.hs    12f
    lsr     x5, x1, #53
    cbnz    x5, 12f
    cmp     w2, #22
    b.gt    12f
    cmn     w2, #22
    b.ge    13f
12: mov     x11, x30
    bl      n_exact
    mov     x30, x11
    b       n_done
13: adr     x5, t_pow10
10: cmp     w2, #0
    b.eq    n_done
    b.lt    11f
    mov     w6, #22
    cmp     w2, w6
    csel    w6, w2, w6, lt
    ldr     d1, [x5, w6, sxtw #3]
    fmul    d8, d8, d1
    sub     w2, w2, w6
    b       10b
11: neg     w6, w2
    mov     w7, #22
    cmp     w6, w7
    csel    w6, w6, w7, lt
    ldr     d1, [x5, w6, sxtw #3]
    fdiv    d8, d8, d1
    add     w2, w2, w6
    b       10b
n_done:
    CH      w0                          // n after it: a big integer
    cmp     w0, #'n'
    b.ne    1f
    add     x22, x22, #1
    mov     w23, #K_BIGINT
    b       2f
1:  NAMEPART w0, 2f                     // a name may not follow a number directly
    b       w_bad_one
2:  sub     x26, x22, x25
    ret
// n_exact: the decimal number in the text from x25 to x22, with w12 the power written after its e, as the nearest double
// (ties to the even one) -> d8. The digits become one long whole number in 32-bit limbs on the stack (the first 800 that
// count; whether anything follows them is all that can matter). A power above zero multiplies it by ten that many times.
// A power below zero: it is moved up 4 bits for each ten plus 64 and divided by ten that many times, keeping whether
// anything was ever left over; floor division done in steps is the same as done at once. Then the top 53 bits are taken
// (fewer below the ordinary range) and rounded by the next bit and the left-overs. Uses x0-x10, x12-x17; not x11.
n_exact:
    sub     sp, sp, #1136
    mov     x13, sp
    mov     x14, #0                     // limbs in use
    mov     x15, #0                     // anything left over?
    mov     w16, w12                    // the power of ten
    mov     w3, #0
    mov     w4, #0
    mov     x17, x25
1:  cmp     x17, x22
    b.hs    5f
    ldrb    w0, [x20, x17]
    add     x17, x17, #1
    cmp     w0, #'_'
    b.eq    1b
    cmp     w0, #'.'
    b.ne    2f
    mov     w4, #1
    b       1b
2:  sub     w5, w0, #'0'
    cmp     w5, #9
    b.hi    5f
    cmp     w3, #800
    b.hs    3f
    sub     w16, w16, w4
    cbnz    w3, 21f
    cbz     w5, 1b
21: add     w3, w3, #1
    mov     x6, #0
    mov     x7, x5
    mov     x8, #10
22: cmp     x6, x14
    b.hs    23f
    ldr     w9, [x13, x6, lsl #2]
    madd    x7, x9, x8, x7
    str     w7, [x13, x6, lsl #2]
    lsr     x7, x7, #32
    add     x6, x6, #1
    b       22b
23: cbz     x7, 1b
    str     w7, [x13, x14, lsl #2]
    add     x14, x14, #1
    b       1b
3:  orr     x15, x15, x5
    eor     w6, w4, #1
    add     w16, w16, w6
    b       1b
5:  cbz     x14, n_ex_zero
    cmp     w16, #0
    b.lt    6f
    cmp     w16, #310
    b.gt    n_ex_inf
    mov     w3, w16
    mov     x8, #10
51: cbz     w3, 52f
    mov     x6, #0
    mov     x7, #0
53: ldr     w9, [x13, x6, lsl #2]
    madd    x7, x9, x8, x7
    str     w7, [x13, x6, lsl #2]
    lsr     x7, x7, #32
    add     x6, x6, #1
    cmp     x6, x14
    b.lo    53b
    cbz     x7, 54f
    str     w7, [x13, x14, lsl #2]
    add     x14, x14, #1
54: sub     w3, w3, #1
    b       51b
52: mov     w16, #0
    b       7f
6:  neg     w16, w16                    // how many times to divide by ten
    cmp     w16, #1140
    b.hi    n_ex_zero
7:  lsl     w12, w16, #2
    add     w12, w12, #64               // how many bits it is moved up
    and     w1, w12, #31
    lsr     w2, w12, #5
    cbz     w1, 72f
    mov     x6, #0
    mov     x7, #0
71: ldr     w9, [x13, x6, lsl #2]
    lsl     x9, x9, x1
    orr     x9, x9, x7
    str     w9, [x13, x6, lsl #2]
    lsr     x7, x9, #32
    add     x6, x6, #1
    cmp     x6, x14
    b.lo    71b
    cbz     x7, 72f
    str     w7, [x13, x14, lsl #2]
    add     x14, x14, #1
72: mov     x6, x14
73: sub     x6, x6, #1
    ldr     w9, [x13, x6, lsl #2]
    add     x7, x6, x2
    str     w9, [x13, x7, lsl #2]
    cbnz    x6, 73b
    mov     x6, #0
74: str     wzr, [x13, x6, lsl #2]
    add     x6, x6, #1
    cmp     x6, x2
    b.lo    74b
    add     x14, x14, x2
    mov     x8, #10
8:  cbz     w16, 9f
    mov     x6, x14
    mov     x7, #0
81: sub     x6, x6, #1
    ldr     w9, [x13, x6, lsl #2]
    orr     x9, x9, x7, lsl #32
    udiv    x10, x9, x8
    msub    x7, x10, x8, x9
    str     w10, [x13, x6, lsl #2]
    cbnz    x6, 81b
    orr     x15, x15, x7
    sub     x6, x14, #1
    ldr     w9, [x13, x6, lsl #2]
    cbnz    w9, 82f
    mov     x14, x6
82: sub     w16, w16, #1
    b       8b
9:  sub     x6, x14, #1                 // how many bits long it is
    ldr     w9, [x13, x6, lsl #2]
    clz     w10, w9
    mov     w7, #32
    sub     w10, w7, w10
    add     w10, w10, w6, lsl #5
    sub     w0, w10, #53                // how many low bits are dropped: all but 53, or more below the ordinary range
    sub     w1, w12, #1074
    cmp     w0, w1
    csel    w0, w1, w0, lt
    lsr     w2, w0, #5
    and     w3, w0, #31
    mov     x4, #0
    cmp     x2, x14
    b.hs    91f
    ldr     w4, [x13, x2, lsl #2]
91: add     x5, x2, #1
    cmp     x5, x14
    b.hs    92f
    ldr     w6, [x13, x5, lsl #2]
    orr     x4, x4, x6, lsl #32
92: lsr     x4, x4, x3
    cbz     w3, 93f
    add     x5, x2, #2
    cmp     x5, x14
    b.hs    93f
    ldr     w6, [x13, x5, lsl #2]
    mov     w7, #64
    sub     w7, w7, w3
    lsl     x6, x6, x7
    orr     x4, x4, x6
93: sub     w0, w0, #1                  // the bit just below, and whether anything lies below that
    lsr     w2, w0, #5
    and     w3, w0, #31
    mov     x5, #0
    cmp     x2, x14
    csel    x7, x14, x2, hi
    b.hs    95f
    ldr     w6, [x13, x2, lsl #2]
    lsr     x5, x6, x3
    and     x5, x5, #1
    mov     x9, #1
    lsl     x9, x9, x3
    sub     x9, x9, #1
    and     x6, x6, x9
    orr     x15, x15, x6
95: mov     x6, #0
96: cmp     x6, x7
    b.hs    97f
    ldr     w9, [x13, x6, lsl #2]
    orr     x15, x15, x9
    add     x6, x6, #1
    b       96b
97: cbz     x5, 98f
    and     x9, x4, #1
    orr     x9, x9, x15
    cbz     x9, 98f
    add     x4, x4, #1
98: add     w0, w0, #1
    sub     w0, w0, w12
    add     w0, w0, #1074               // the exponent field less one; the top digit adds the one (or not, below the range)
    add     x4, x4, x0, lsl #52
    lsr     x9, x4, #52
    cmp     x9, #0x7ff
    b.hs    n_ex_inf
    fmov    d8, x4
    b       n_ex_out
n_ex_inf:
    ldr     x4, =0x7ff0000000000000
    fmov    d8, x4
    b       n_ex_out
n_ex_zero:
    fmov    d8, xzr
n_ex_out:
    add     sp, sp, #1136
    ret
    .ltorg
    .balign 8
t_pow10:
    .quad   0x3ff0000000000000
    .quad   0x4024000000000000
    .quad   0x4059000000000000
    .quad   0x408f400000000000
    .quad   0x40c3880000000000
    .quad   0x40f86a0000000000
    .quad   0x412e848000000000
    .quad   0x416312d000000000
    .quad   0x4197d78400000000
    .quad   0x41cdcd6500000000
    .quad   0x4202a05f20000000
    .quad   0x42374876e8000000
    .quad   0x426d1a94a2000000
    .quad   0x42a2309ce5400000
    .quad   0x42d6bcc41e900000
    .quad   0x430c6bf526340000
    .quad   0x4341c37937e08000
    .quad   0x4376345785d8a000
    .quad   0x43abc16d674ec800
    .quad   0x43e158e460913d00
    .quad   0x4415af1d78b58c40
    .quad   0x444b1ae4d6e2ef50
    .quad   0x4480f0cf064dd592
t_keywords:
    .byte   5
    .ascii  "break"
    .byte   4
    .ascii  "case"
    .byte   5
    .ascii  "catch"
    .byte   5
    .ascii  "class"
    .byte   5
    .ascii  "const"
    .byte   8
    .ascii  "continue"
    .byte   8
    .ascii  "debugger"
    .byte   7
    .ascii  "default"
    .byte   6
    .ascii  "delete"
    .byte   2
    .ascii  "do"
    .byte   4
    .ascii  "else"
    .byte   6
    .ascii  "export"
    .byte   7
    .ascii  "extends"
    .byte   7
    .ascii  "finally"
    .byte   3
    .ascii  "for"
    .byte   8
    .ascii  "function"
    .byte   2
    .ascii  "if"
    .byte   6
    .ascii  "import"
    .byte   2
    .ascii  "in"
    .byte   10
    .ascii  "instanceof"
    .byte   3
    .ascii  "new"
    .byte   6
    .ascii  "return"
    .byte   5
    .ascii  "super"
    .byte   6
    .ascii  "switch"
    .byte   4
    .ascii  "this"
    .byte   5
    .ascii  "throw"
    .byte   3
    .ascii  "try"
    .byte   6
    .ascii  "typeof"
    .byte   3
    .ascii  "var"
    .byte   4
    .ascii  "void"
    .byte   5
    .ascii  "while"
    .byte   4
    .ascii  "with"
    .byte   5
    .ascii  "yield"
    .byte   3
    .ascii  "let"
    .byte   6
    .ascii  "static"
    .byte   5
    .ascii  "async"
    .byte   5
    .ascii  "await"
    .byte   2
    .ascii  "of"
    .byte   3
    .ascii  "get"
    .byte   3
    .ascii  "set"
    .byte   4
    .ascii  "null"
    .byte   4
    .ascii  "true"
    .byte   5
    .ascii  "false"
    .byte   0
t_punct:
    .byte   4
    .ascii  ">>>="
    .byte   3
    .ascii  "..."
    .byte   3
    .ascii  "==="
    .byte   3
    .ascii  "!=="
    .byte   3
    .ascii  "**="
    .byte   3
    .ascii  "<<="
    .byte   3
    .ascii  ">>="
    .byte   3
    .ascii  ">>>"
    .byte   3
    .ascii  "&&="
    .byte   3
    .ascii  "||="
    .byte   3
    .ascii  "??="
    .byte   2
    .ascii  "=>"
    .byte   2
    .ascii  "=="
    .byte   2
    .ascii  "!="
    .byte   2
    .ascii  "<="
    .byte   2
    .ascii  ">="
    .byte   2
    .ascii  "&&"
    .byte   2
    .ascii  "||"
    .byte   2
    .ascii  "??"
    .byte   2
    .ascii  "?."
    .byte   2
    .ascii  "++"
    .byte   2
    .ascii  "--"
    .byte   2
    .ascii  "+="
    .byte   2
    .ascii  "-="
    .byte   2
    .ascii  "*="
    .byte   2
    .ascii  "/="
    .byte   2
    .ascii  "%="
    .byte   2
    .ascii  "&="
    .byte   2
    .ascii  "|="
    .byte   2
    .ascii  "^="
    .byte   2
    .ascii  "<<"
    .byte   2
    .ascii  ">>"
    .byte   2
    .ascii  "**"
    .byte   1
    .ascii  "{"
    .byte   1
    .ascii  "}"
    .byte   1
    .ascii  "("
    .byte   1
    .ascii  ")"
    .byte   1
    .ascii  "["
    .byte   1
    .ascii  "]"
    .byte   1
    .ascii  ";"
    .byte   1
    .ascii  ","
    .byte   1
    .ascii  "<"
    .byte   1
    .ascii  ">"
    .byte   1
    .ascii  "+"
    .byte   1
    .ascii  "-"
    .byte   1
    .ascii  "*"
    .byte   1
    .ascii  "/"
    .byte   1
    .ascii  "%"
    .byte   1
    .ascii  "&"
    .byte   1
    .ascii  "|"
    .byte   1
    .ascii  "^"
    .byte   1
    .ascii  "!"
    .byte   1
    .ascii  "~"
    .byte   1
    .ascii  "?"
    .byte   1
    .ascii  ":"
    .byte   1
    .ascii  "="
    .byte   1
    .ascii  "."
    .byte   1
    .ascii  "@"
    .byte   1
    .ascii  "#"
    .byte   0
    .balign 4

