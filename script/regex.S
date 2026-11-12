// Regular expressions (stage 6). Two built-ins: 52 translates a pattern's text into a program of 16-bit words, kept as a
// wide string; 53 runs such a program over a text from a given place and answers the array of where each group began and
// ended (-1: it took no part), or null. The RegExp object and the string methods are in prelude.js, on these two.
// The program: words 0-3 are how many groups (the whole match is group 0), how many marks, the flags (1 i, 2 m, 4 s),
// and nothing; then instructions, one word each, some followed by words of their own. A jump's word is a distance in
// words from the word after it.
    .equ RX_MATCH, 0                    // the whole pattern has matched
    .equ RX_CHAR, 1                     // + the unit that must come next (folded already if case is ignored)
    .equ RX_ANY, 2                      // any unit but the end of a line
    .equ RX_ANYNL, 3                    // any unit at all
    .equ RX_CLASS, 4                    // + how many pairs, then the pairs (lowest, highest): the unit must be in one
    .equ RX_NCLASS, 5                   // the same: in none
    .equ RX_SPLIT, 6                    // + distance: go on, and come back to the distance if that fails
    .equ RX_SPLITJ, 7                   // + distance: go to the distance, and come back to here if that fails
    .equ RX_JMP, 8                      // + distance
    .equ RX_SAVE, 9                     // + which place of a group (2k its start, 2k + 1 its end): it is here
    .equ RX_BOL, 10
    .equ RX_EOL, 11
    .equ RX_WORDB, 12
    .equ RX_NWORDB, 13
    .equ RX_BACKREF, 14                 // + which group: what it matched must come again
    .equ RX_LOOK, 15                    // + distance to what follows: the instructions between must match from here
    .equ RX_NLOOK, 16                   // the same: must not
    .equ RX_LOOKEND, 17
    .equ RX_MARK, 18                    // + which mark: a repeat's turn begins here
    .equ RX_CHKADV, 19                  // + which mark: the turn must have taken something, or the repeat would never end
    .equ RX_CLEAR, 20                   // + first group, + past the last: they forget what they matched (a repeat's new turn)
    .equ RX_MAXW, 16384                 // the longest program, in words
    .equ W_RXSTACK, 464                 // the block of places to come back to (one, kept and reused; 0: not yet)
    .equ W_RXSIZE, 472                  // its size in bytes
// The matcher. x1 the next instruction, x2 the text, x3 its units, x4 where we are, x5 whether the text is wide, x6 the
// flags, x7 the groups' places (marks lie below them), x8 the top of the places to come back to, x9 their floor for
// this run, x10 their limit, x17 steps left. An entry is two words: an instruction and a place, or (bit 0 set) a slot
// and the value it had. Uses x0, x11-x16 besides.
    .macro  RXUNIT reg, at
    cbz     x5, 98f
    ldrh    \reg, [x2, \at, lsl #1]
    b       99f
98: ldrb    \reg, [x2, \at]
99:
    .endm
    .macro  RXFOLD r, t                 // capitals of English and of western Europe to small letters
    sub     \t, \r, #'A'
    cmp     \t, #25
    b.hi    97f
    add     \r, \r, #32
    b       96f
97: sub     \t, \r, #0xc0
    cmp     \t, #30
    b.hi    96f
    cmp     \r, #0xd7
    b.eq    96f
    add     \r, \r, #32
96:
    .endm
    .macro  RXLT r, t                   // flags eq if the unit ends a line
    cmp     \r, #10
    b.eq    94f
    cmp     \r, #13
    b.eq    94f
    mov     \t, #0x2028
    sub     \t, \r, \t
    cmp     \t, #1
    b.hi    93f
    cmp     \t, \t
    b       94f
93: cmp     \r, #10
94:
    .endm
    .macro  RXPUSH a, b
    cmp     x8, x10
    b.lo    95f
    bl      rx_grow
95: stp     \a, \b, [x8], #16
    .endm
rx_loop:
    str     x30, [sp, #-16]!
rx_next:
    subs    x17, x17, #1
    b.eq    rx_toolong
    ldrh    w11, [x1], #2
    adr     x12, rx_tab
    ldrsw   x11, [x12, x11, lsl #2]
    add     x12, x12, x11
    br      x12
rx_tab:
    .word   rx_match - rx_tab, rx_char - rx_tab, rx_any - rx_tab, rx_anynl - rx_tab, rx_class - rx_tab, rx_nclass - rx_tab
    .word   rx_split - rx_tab, rx_splitj - rx_tab, rx_jmp - rx_tab, rx_save - rx_tab, rx_bol - rx_tab, rx_eol - rx_tab
    .word   rx_wordb - rx_tab, rx_nwordb - rx_tab, rx_backref - rx_tab, rx_look - rx_tab, rx_nlook - rx_tab
    .word   rx_match - rx_tab, rx_mark - rx_tab, rx_chkadv - rx_tab, rx_clear - rx_tab
rx_match:
    mov     w0, #1
    ldr     x30, [sp], #16
    ret
rx_fail:
    cmp     x8, x9
    b.ls    1f
    ldp     x11, x12, [x8, #-16]!
    tbz     x11, #0, 2f
    and     x11, x11, #0xfffffffffffffffe
    str     x12, [x11]
    b       rx_fail
2:  mov     x1, x11
    mov     x4, x12
    b       rx_next
1:  mov     w0, #0
    ldr     x30, [sp], #16
    ret
rx_char:
    ldrh    w12, [x1], #2
    cmp     x4, x3
    b.hs    rx_fail
    RXUNIT  w11, x4
    tbz     x6, #0, 1f
    RXFOLD  w11, w15
1:  cmp     w11, w12
    b.ne    rx_fail
    add     x4, x4, #1
    b       rx_next
rx_any:
    cmp     x4, x3
    b.hs    rx_fail
    RXUNIT  w11, x4
    RXLT    w11, w12
    b.eq    rx_fail
    add     x4, x4, #1
    b       rx_next
rx_anynl:
    cmp     x4, x3
    b.hs    rx_fail
    add     x4, x4, #1
    b       rx_next
rx_class:
    mov     x13, #0
    b       1f
rx_nclass:
    mov     x13, #1
1:  ldrh    w12, [x1], #2
    add     x16, x1, x12, lsl #2
    cmp     x4, x3
    b.hs    rx_fail
    RXUNIT  w11, x4
    mov     w12, w11
    mov     w15, w11
    tbz     x6, #0, 2f
    RXFOLD  w12, w0                     // case ignored: the unit, its small letter and its capital are all tried
    sub     w0, w11, #'a'
    cmp     w0, #25
    b.hi    21f
    sub     w15, w11, #32
    b       2f
21: sub     w0, w11, #0xe0
    cmp     w0, #30
    b.hi    2f
    cmp     w11, #0xf7
    b.eq    2f
    sub     w15, w11, #32
2:  cmp     x1, x16
    b.hs    4f
    ldrh    w0, [x1], #2
    ldrh    w14, [x1], #2
    cmp     w11, w0
    ccmp    w11, w14, #2, hs
    b.ls    3f
    cmp     w12, w0
    ccmp    w12, w14, #2, hs
    b.ls    3f
    cmp     w15, w0
    ccmp    w15, w14, #2, hs
    b.hi    2b
3:  mov     x1, x16
    cbnz    x13, rx_fail
    add     x4, x4, #1
    b       rx_next
4:  cbz     x13, rx_fail
    add     x4, x4, #1
    b       rx_next
rx_split:
    ldrsh   x12, [x1], #2
    add     x12, x1, x12, lsl #1
    RXPUSH  x12, x4
    b       rx_next
rx_splitj:
    ldrsh   x12, [x1], #2
    RXPUSH  x1, x4
    add     x1, x1, x12, lsl #1
    b       rx_next
rx_jmp:
    ldrsh   x12, [x1], #2
    add     x1, x1, x12, lsl #1
    b       rx_next
rx_save:
    ldrh    w12, [x1], #2
    add     x12, x7, x12, lsl #3
1:  ldr     x11, [x12]
    orr     x0, x12, #1
    RXPUSH  x0, x11
    str     x4, [x12]
    b       rx_next
rx_mark:
    ldrh    w12, [x1], #2
    sub     x12, x7, x12, lsl #3
    sub     x12, x12, #8
    b       1b
rx_chkadv:
    ldrh    w12, [x1], #2
    sub     x12, x7, x12, lsl #3
    ldr     x11, [x12, #-8]
    cmp     x11, x4
    b.eq    rx_fail
    b       rx_next
rx_clear:
    ldrh    w12, [x1], #2
    ldrh    w16, [x1], #2
    add     x12, x7, x12, lsl #4
    add     x16, x7, x16, lsl #4
1:  cmp     x12, x16
    b.hs    rx_next
    ldr     x11, [x12]
    cmn     x11, #1
    b.eq    2f
    orr     x0, x12, #1
    RXPUSH  x0, x11
    mov     x11, #-1
    str     x11, [x12]
2:  add     x12, x12, #8
    b       1b
rx_bol:
    cbz     x4, rx_next
    tbz     x6, #1, rx_fail
    sub     x12, x4, #1
    RXUNIT  w11, x12
    RXLT    w11, w12
    b.eq    rx_next
    b       rx_fail
rx_eol:
    cmp     x4, x3
    b.hs    rx_next
    tbz     x6, #1, rx_fail
    RXUNIT  w11, x4
    RXLT    w11, w12
    b.eq    rx_next
    b       rx_fail
rx_wordb:
    mov     x13, #0
    b       1f
rx_nwordb:
    mov     x13, #1
1:  mov     w15, #0
    cbz     x4, 2f
    sub     x12, x4, #1
    RXUNIT  w11, x12
    bl      rx_isw
    mov     w15, w11
2:  mov     w11, #0
    cmp     x4, x3
    b.hs    3f
    RXUNIT  w11, x4
    bl      rx_isw
3:  eor     w11, w11, w15
    eor     w11, w11, w13
    cbz     w11, rx_fail
    b       rx_next
// rx_isw: is the unit w11 a letter of a word (English letters, digits, the low line) -> w11 1 or 0. Uses w12.
rx_isw:
    sub     w12, w11, #'0'
    cmp     w12, #9
    b.ls    1f
    orr     w12, w11, #32
    sub     w12, w12, #'a'
    cmp     w12, #25
    b.ls    1f
    cmp     w11, #'_'
    b.eq    1f
    mov     w11, #0
    ret
1:  mov     w11, #1
    ret
rx_backref:
    ldrh    w12, [x1], #2
    add     x12, x7, x12, lsl #4
    ldp     x11, x12, [x12]
    tbnz    x11, #63, rx_next
    tbnz    x12, #63, rx_next
    sub     x12, x12, x11               // how many units; x11 where they are
    add     x0, x4, x12
    cmp     x0, x3
    b.hi    rx_fail
1:  cbz     x12, rx_next
    RXUNIT  w14, x11
    RXUNIT  w15, x4
    tbz     x6, #0, 2f
    RXFOLD  w14, w0
    RXFOLD  w15, w0
2:  cmp     w14, w15
    b.ne    rx_fail
    add     x11, x11, #1
    add     x4, x4, #1
    sub     x12, x12, #1
    b       1b
// Looking ahead: the matcher runs inside itself over the instructions up to RX_LOOKEND, with the places to come back to
// floored at their present top. If it matched and that was wanted, only the entries that put groups back are kept
// (so that a later failure still undoes them); if it matched and was not wanted, everything it did is undone.
rx_look:
    mov     x0, #0
    b       1f
rx_nlook:
    mov     x0, #1
1:  ldrsh   x12, [x1], #2
    add     x12, x1, x12, lsl #1
    ldr     x14, [x19, #W_RXSTACK]
    add     x14, x19, x14
    sub     x11, x9, x14
    stp     x12, x4, [sp, #-32]!
    stp     x11, x0, [sp, #16]
    mov     x9, x8
    bl      rx_loop
    ldp     x11, x15, [sp, #16]
    cbz     w0, 5f
    cbnz    x15, 3f
    mov     x12, x9                     // matched and wanted: keep the undoing entries only
    mov     x14, x9
2:  cmp     x12, x8
    b.hs    21f
    ldp     x0, x16, [x12], #16
    tbz     x0, #0, 2b
    stp     x0, x16, [x14], #16
    b       2b
21: mov     x8, x14
    mov     w0, #1
    b       5f
3:  cmp     x8, x9                      // matched and not wanted: undo it all
    b.ls    4f
    ldp     x0, x16, [x8, #-16]!
    tbz     x0, #0, 3b
    and     x0, x0, #0xfffffffffffffffe
    str     x16, [x0]
    b       3b
4:  mov     w0, #1
5:  ldr     x14, [x19, #W_RXSTACK]
    add     x14, x19, x14
    add     x9, x14, x11
    ldp     x1, x4, [sp], #32
    eor     w0, w0, w15                 // go on if it matched and was wanted, or did not and was not
    cbz     w0, rx_fail
    b       rx_next
// rx_grow: the block of places to come back to is full: one of twice the size takes its place (the old one is not given
// back before stage 7). x8, x9, x10 move with it; nothing else changes.
rx_grow:
    stp     x29, x30, [sp, #-96]!
    stp     x0, x1, [sp, #16]
    stp     x2, x3, [sp, #32]
    stp     x11, x12, [sp, #48]
    ldr     x11, [x19, #W_RXSTACK]
    add     x11, x19, x11
    add     x11, x11, #8
    sub     x8, x8, x11
    sub     x9, x9, x11
    stp     x8, x9, [sp, #64]
    ldr     x0, [x19, #W_RXSIZE]
    lsl     x0, x0, #1
    str     x0, [sp, #80]
    cmp     x0, #(8 << 20)
    b.hi    rx_toodeep
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, n_full
    ldr     x1, [x19, #W_RXSTACK]
    add     x1, x19, x1
    add     x1, x1, #8
    ldr     x2, [sp, #80]
    str     x0, [x19, #W_RXSTACK]
    str     x2, [x19, #W_RXSIZE]
    add     x0, x19, x0
    str     x2, [x0], #8
    ldp     x8, x9, [sp, #64]
    mov     x3, #0
1:  cmp     x3, x8
    b.hs    2f
    ldr     x11, [x1, x3]
    str     x11, [x0, x3]
    add     x3, x3, #8
    b       1b
2:  add     x10, x0, x2
    add     x8, x0, x8
    add     x9, x0, x9
    ldp     x0, x1, [sp, #16]
    ldp     x2, x3, [sp, #32]
    ldp     x11, x12, [sp, #48]
    ldp     x29, x30, [sp], #96
    ret
rx_toolong:
    adr     x0, e_rxlong
    mov     x1, #(e_rxdeep - e_rxlong)
    b       n_fail
rx_toodeep:
    adr     x0, e_rxdeep
    mov     x1, #(e_rxbad - e_rxdeep)
    b       n_fail
e_rxlong: .ascii "InternalError: the regular expression took too many steps"
e_rxdeep: .ascii "InternalError: the regular expression went too deep"
e_rxbad:  .ascii "SyntaxError: Invalid regular expression"
e_rxbig:  .ascii "SyntaxError: the regular expression is too large"
e_rxnot:  .ascii "SyntaxError: looking behind is not made yet"
e_rxflag: .ascii "SyntaxError: Invalid regular expression flags"
e_rxend:
    .balign 4
// 53: (program, text, where to begin, sticky) -> the array of the groups' places, or null. Tries each place from the
// given one on (only the given one if sticky).
n_rxexec:
    NIN
    mov     x29, sp
    ARGNUM  2
    fcvtzs  x9, d0
    str     x9, [x29, #40]
    ARGNUM  3
    fcvtzs  x9, d0
    str     x9, [x29, #32]
    ldr     x9, [x19, #W_RXSTACK]
    cbnz    x9, 1f
    mov     x0, #(16384 + 8)
    bl      w_alloc
    cbz     x0, n_full
    str     x0, [x19, #W_RXSTACK]
    mov     x9, #16384
    str     x9, [x19, #W_RXSIZE]
    str     x9, [x19, x0]
1:  ldr     x1, [x29, #24]
    ldr     x0, [x1]
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    add     x0, x0, #8                  // the program's words
    ldrh    w11, [x0]
    ldrh    w12, [x0, #2]
    ldrh    w6, [x0, #4]
    add     x13, x12, x11, lsl #1       // slots: the marks, then two for each group
    add     x13, x13, #1
    and     x13, x13, #0xfffffffffffffffe
    sub     sp, sp, x13, lsl #3
    add     x7, sp, x12, lsl #3
    ldr     x2, [x1, #8]
    and     x2, x2, #0xffffffffffff
    add     x2, x19, x2
    ldr     x3, [x2], #8
    lsr     x5, x3, #32
    and     x5, x5, #1
    and     x3, x3, #0xffffffff
    ldr     x9, [x19, #W_RXSTACK]
    add     x9, x19, x9
    add     x9, x9, #8
    ldr     x10, [x19, #W_RXSIZE]
    add     x10, x9, x10
    mov     x17, #(64 << 20)
2:  ldr     x4, [x29, #40]
    cmp     x4, x3
    b.hi    8f
    mov     x11, sp
    mov     x12, #-1
3:  cmp     x11, x29
    b.hs    4f
    str     x12, [x11], #8
    b       3b
4:  ldr     x1, [x29, #24]
    ldr     x1, [x1]
    and     x1, x1, #0xffffffffffff
    add     x1, x19, x1
    add     x1, x1, #16
    mov     x8, x9
    bl      rx_loop
    cbnz    w0, 6f
    ldr     x11, [x29, #32]
    cbnz    x11, 8f
    ldr     x4, [x29, #40]
    add     x4, x4, #1
    str     x4, [x29, #40]
    b       2b
6:  ldr     x1, [x29, #24]
    ldr     x1, [x1]
    and     x1, x1, #0xffffffffffff
    add     x1, x19, x1
    ldrh    w1, [x1, #8]
    lsl     x1, x1, #1
    mov     x11, #0
7:  cmp     x11, x1
    b.hs    71f
    ldr     x12, [x7, x11, lsl #3]
    scvtf   d0, x12
    str     d0, [x7, x11, lsl #3]
    add     x11, x11, #1
    b       7b
71: mov     x0, x7
    bl      a_from
    cbz     x0, n_full
    mov     sp, x29
    NOUT
8:  mov     sp, x29
    VAL     x0, T_NULL
    NOUT
// The translator. x20 the pattern's units, x21 how many, x22 where we are, x23 whether they are wide; x24 the program
// being written (on the processor's stack), x25 how many words so far, x26 the next group's number, x27 the next
// mark's, x28 the flags. The machine's own x20-x28 are kept below x29 and put back on every way out.
    .macro  RXAT at                     // the pattern's unit at \at -> w0, -1 past the end
    mov     w0, #-1
    cmp     \at, x21
    b.hs    99f
    cbz     x23, 98f
    ldrh    w0, [x20, \at, lsl #1]
    b       99f
98: ldrb    w0, [x20, \at]
99:
    .endm
    .macro  RXPEEK
    RXAT    x22
    .endm
    .macro  RXE reg
    strh    \reg, [x24, x25, lsl #1]
    add     x25, x25, #1
    cmp     x25, #RX_MAXW
    b.hs    rxc_big
    .endm
    .macro  RXEI value
    mov     w8, #\value
    RXE     w8
    .endm
// 52: (pattern, flags) -> the program, as a string value
n_rxcompile:
    NIN
    mov     x29, sp
    sub     sp, sp, #80
    stp     x20, x21, [x29, #-80]
    stp     x22, x23, [x29, #-64]
    stp     x24, x25, [x29, #-48]
    stp     x26, x27, [x29, #-32]
    str     x28, [x29, #-16]
    ldr     x1, [x29, #24]
    ldr     x0, [x1, #8]                // the flags: i, m, s matter here; g, y, u, d are the object's business
    and     x0, x0, #0xffffffffffff
    add     x0, x19, x0
    ldr     x9, [x0], #8
    and     x9, x9, #0xffffffff
    mov     x28, #0
1:  cbz     x9, 3f
    ldrb    w10, [x0], #1
    sub     x9, x9, #1
    mov     w11, #1
    cmp     w10, #'i'
    b.eq    2f
    mov     w11, #2
    cmp     w10, #'m'
    b.eq    2f
    mov     w11, #4
    cmp     w10, #'s'
    b.eq    2f
    mov     w11, #0
    cmp     w10, #'g'
    b.eq    2f
    cmp     w10, #'y'
    b.eq    2f
    cmp     w10, #'u'
    b.eq    2f
    cmp     w10, #'d'
    b.ne    rxc_flags
2:  orr     x28, x28, x11
    b       1b
3:  ldr     x20, [x1]
    and     x20, x20, #0xffffffffffff
    add     x20, x19, x20
    ldr     x21, [x20], #8
    lsr     x23, x21, #32
    and     x23, x23, #1
    and     x21, x21, #0xffffffff
    mov     x22, #0
    sub     sp, sp, #36864
    mov     x24, sp
    mov     x25, #4
    mov     x26, #1
    mov     x27, #0
    str     xzr, [x24]
    mov     x9, #0                      // how many groups the pattern has, counted first: \N past that is an old character code
1:  RXPEEK
    cmn     w0, #1
    b.eq    6f
    add     x22, x22, #1
    cmp     w0, #'\\'
    b.ne    2f
    add     x22, x22, #1
    b       1b
2:  cmp     w0, #'['
    b.ne    4f
3:  RXPEEK
    cmn     w0, #1
    b.eq    6f
    add     x22, x22, #1
    cmp     w0, #']'
    b.eq    1b
    cmp     w0, #'\\'
    b.ne    3b
    add     x22, x22, #1
    b       3b
4:  cmp     w0, #'('
    b.ne    1b
    RXPEEK
    cmp     w0, #'?'
    b.ne    5f
    add     x10, x22, #1
    RXAT    x10
    cmp     w0, #'<'
    b.ne    1b
    add     x10, x22, #2
    RXAT    x10
    cmp     w0, #'='
    b.eq    1b
    cmp     w0, #'!'
    b.eq    1b
5:  add     x9, x9, #1
    b       1b
6:  strh    w9, [x24, #4]
    mov     x22, #0
    RXEI    RX_SAVE
    RXEI    0
    bl      rxc_alt
    cmp     x22, x21
    b.ne    rxc_bad
    RXEI    RX_SAVE
    RXEI    1
    RXEI    RX_MATCH
    strh    w26, [x24]
    strh    w27, [x24, #2]
    strh    w28, [x24, #4]
    strh    wzr, [x24, #6]
    lsl     x0, x25, #1
    add     x0, x0, #8
    bl      w_alloc
    cbz     x0, rxc_full
    add     x8, x19, x0
    mov     x9, #(1 << 32)
    orr     x9, x9, x25
    str     x9, [x8], #8
    mov     x9, #0
4:  cmp     x9, x25
    b.hs    5f
    ldrh    w10, [x24, x9, lsl #1]
    strh    w10, [x8, x9, lsl #1]
    add     x9, x9, #1
    b       4b
5:  orr     x0, x0, #(T_STRING << 48)
    bl      rxc_back
    mov     sp, x29
    NOUT
rxc_back:
    ldp     x20, x21, [x29, #-80]
    ldp     x22, x23, [x29, #-64]
    ldp     x24, x25, [x29, #-48]
    ldp     x26, x27, [x29, #-32]
    ldr     x28, [x29, #-16]
    ret
rxc_full:
    bl      rxc_back
    b       n_full
rxc_flags:
    adr     x0, e_rxflag
    mov     x1, #(e_rxend - e_rxflag)
    b       1f
rxc_notyet:
    adr     x0, e_rxnot
    mov     x1, #(e_rxflag - e_rxnot)
    b       1f
rxc_big:
    adr     x0, e_rxbig
    mov     x1, #(e_rxnot - e_rxbig)
    b       1f
rxc_bad:
    adr     x0, e_rxbad
    mov     x1, #(e_rxbig - e_rxbad)
1:  bl      rxc_back
    b       n_fail
// rxc_alt: alternatives, up to a ) or the end. Each | puts a split before the alternative just read and a jump after
// it; the jumps are chained through their own words until the end is known.
rxc_alt:
    sub     sp, sp, #32
    str     x30, [sp]
    str     x25, [sp, #8]
    mov     x9, #0xffff
    str     x9, [sp, #16]
1:  bl      rxc_seq
    RXPEEK
    cmp     w0, #'|'
    b.ne    5f
    add     x22, x22, #1
    ldr     x9, [sp, #8]                // two words open up where the alternative began
    mov     x10, x25
2:  cmp     x10, x9
    b.ls    3f
    sub     x10, x10, #1
    ldrh    w11, [x24, x10, lsl #1]
    add     x12, x10, #2
    strh    w11, [x24, x12, lsl #1]
    b       2b
3:  add     x25, x25, #2
    cmp     x25, #RX_MAXW
    b.hs    rxc_big
    mov     w11, #RX_SPLIT
    strh    w11, [x24, x9, lsl #1]
    add     x10, x9, #1
    sub     x11, x25, x9                // to past the jump about to be written
    strh    w11, [x24, x10, lsl #1]
    RXEI    RX_JMP
    ldr     x9, [sp, #16]
    str     x25, [sp, #16]
    RXE     w9
    str     x25, [sp, #8]
    b       1b
5:  ldr     x9, [sp, #16]
    mov     w12, #0xffff
6:  cmp     w9, w12
    b.eq    7f
    ldrh    w10, [x24, x9, lsl #1]
    sub     x11, x25, x9
    sub     x11, x11, #1
    strh    w11, [x24, x9, lsl #1]
    mov     w9, w10
    b       6b
7:  ldr     x30, [sp]
    add     sp, sp, #32
    ret
rxc_seq:
    str     x30, [sp, #-16]!
1:  RXPEEK
    cmn     w0, #1
    b.eq    9f
    cmp     w0, #'|'
    b.eq    9f
    cmp     w0, #')'
    b.eq    9f
    bl      rxc_term
    b       1b
9:  ldr     x30, [sp], #16
    ret
rxc_close:
    RXPEEK
    cmp     w0, #')'
    b.ne    rxc_bad
    add     x22, x22, #1
    ret
// rxc_term: one thing and the repeat after it, if any. Frame: 0 the way back, 8 where its instructions begin, 16 whether
// it could match nothing (a group, a look, a back reference), 24-40 for whoever needs them.
rxc_term:
    sub     sp, sp, #64
    str     x30, [sp]
    str     x25, [sp, #8]
    str     xzr, [sp, #16]
    str     x26, [sp, #48]
    RXPEEK
    add     x22, x22, #1
    cmp     w0, #'^'
    b.ne    1f
    RXEI    RX_BOL
    b       90f
1:  cmp     w0, #'$'
    b.ne    2f
    RXEI    RX_EOL
    b       90f
2:  cmp     w0, #'.'
    b.ne    3f
    mov     w9, #RX_ANY
    mov     w10, #RX_ANYNL
    tst     x28, #4
    csel    w9, w10, w9, ne
    RXE     w9
    b       50f
3:  cmp     w0, #'('
    b.eq    10f
    cmp     w0, #'['
    b.eq    20f
    cmp     w0, #'\\'
    b.eq    30f
    cmp     w0, #'*'
    b.eq    rxc_bad
    cmp     w0, #'+'
    b.eq    rxc_bad
    cmp     w0, #'?'
    b.eq    rxc_bad
5:  tbz     x28, #0, 6f
    RXFOLD  w0, w9
6:  RXEI    RX_CHAR
    RXE     w0
    b       50f
// a group
10: ldrh    w9, [x24, #6]               // how deep (kept in the program's fourth word meanwhile)
    add     w9, w9, #1
    strh    w9, [x24, #6]
    cmp     w9, #200
    b.hi    rxc_big
    mov     x9, #1
    str     x9, [sp, #16]
    RXPEEK
    cmp     w0, #'?'
    b.ne    14f
    add     x22, x22, #1
    RXPEEK
    add     x22, x22, #1
    cmp     w0, #':'
    b.eq    13f
    mov     w10, #RX_LOOK
    cmp     w0, #'='
    b.eq    12f
    mov     w10, #RX_NLOOK
    cmp     w0, #'!'
    b.eq    12f
    cmp     w0, #'<'
    b.ne    rxc_bad
    RXPEEK
    cmp     w0, #'='
    b.eq    rxc_notyet
    cmp     w0, #'!'
    b.eq    rxc_notyet
11: RXPEEK                              // a name: passed over for now
    cmn     w0, #1
    b.eq    rxc_bad
    add     x22, x22, #1
    cmp     w0, #'>'
    b.ne    11b
    b       14f
12: RXE     w10
    str     x25, [sp, #24]
    RXEI    0
    bl      rxc_alt
    bl      rxc_close
    RXEI    RX_LOOKEND
    ldr     x9, [sp, #24]
    sub     x10, x25, x9
    sub     x10, x10, #1
    strh    w10, [x24, x9, lsl #1]
    b       19f
13: bl      rxc_alt
    bl      rxc_close
    b       19f
14: str     x26, [sp, #24]
    lsl     x10, x26, #1
    add     x26, x26, #1
    cmp     x26, #1000
    b.hi    rxc_big
    RXEI    RX_SAVE
    RXE     w10
    bl      rxc_alt
    bl      rxc_close
    ldr     x10, [sp, #24]
    lsl     x10, x10, #1
    add     x10, x10, #1
    RXEI    RX_SAVE
    RXE     w10
19: ldrh    w9, [x24, #6]
    sub     w9, w9, #1
    strh    w9, [x24, #6]
    b       50f
// a class: 24 where its count goes, 32 the count, 40 the lower end of a range
20: mov     w10, #RX_CLASS
    RXPEEK
    cmp     w0, #'^'
    b.ne    21f
    add     x22, x22, #1
    mov     w10, #RX_NCLASS
21: RXE     w10
    str     x25, [sp, #24]
    RXEI    0
    str     xzr, [sp, #32]
22: RXPEEK
    cmn     w0, #1
    b.eq    rxc_bad
    add     x22, x22, #1
    cmp     w0, #']'
    b.eq    28f
    bl      rxc_classatom
    cmn     w0, #1
    b.ne    23f
    ldr     x9, [sp, #32]
    add     x9, x9, x11
    str     x9, [sp, #32]
    b       22b
23: str     x0, [sp, #40]
    RXPEEK
    cmp     w0, #'-'
    b.ne    26f
    add     x9, x22, #1
    RXAT    x9
    cmn     w0, #1
    b.eq    26f
    cmp     w0, #']'
    b.eq    26f
    add     x22, x22, #2
    bl      rxc_classatom
    cmn     w0, #1
    b.ne    24f
    ldr     x9, [sp, #32]               // a-\d: the letter, the dash, and the class
    add     x9, x9, x11
    add     x9, x9, #2
    str     x9, [sp, #32]
    ldr     x0, [sp, #40]
    RXE     w0
    RXE     w0
    RXEI    '-'
    RXEI    '-'
    b       22b
24: ldr     x9, [sp, #40]
    cmp     w9, w0
    b.hi    rxc_bad
    RXE     w9
    RXE     w0
    b       27f
26: ldr     x0, [sp, #40]
    RXE     w0
    RXE     w0
27: ldr     x9, [sp, #32]
    add     x9, x9, #1
    str     x9, [sp, #32]
    b       22b
28: ldr     x9, [sp, #24]
    ldr     x10, [sp, #32]
    strh    w10, [x24, x9, lsl #1]
    b       50f
// after a backslash
30: RXPEEK
    cmn     w0, #1
    b.eq    rxc_bad
    add     x22, x22, #1
    cmp     w0, #'b'
    b.ne    31f
    RXEI    RX_WORDB
    b       90f
31: cmp     w0, #'B'
    b.ne    32f
    RXEI    RX_NWORDB
    b       90f
32: bl      rxc_whichclass
    cbz     x12, 33f
    RXEI    RX_CLASS
    ldrh    w9, [x12]
    RXE     w9
    bl      rxc_table
    b       50f
33: sub     w9, w0, #'1'
    cmp     w9, #8
    b.hi    35f
    add     x10, x9, #1                 // \1 to \999: a group again, if the pattern has that many
    mov     x12, x22
34: RXPEEK
    sub     w9, w0, #'0'
    cmp     w9, #9
    b.hi    341f
    cmp     x10, #99
    b.hi    341f
    add     x22, x22, #1
    mov     x11, #10
    madd    x10, x10, x11, x9
    b       34b
341: ldrh   w9, [x24, #4]
    cmp     w10, w9
    b.hi    342f
    RXEI    RX_BACKREF
    RXE     w10
    mov     x9, #1
    str     x9, [sp, #16]
    b       50f
342: mov    x22, x12                    // not a group: 8 and 9 are themselves, the rest a code in base eight
    sub     x10, x22, #1
    RXAT    x10
    sub     w10, w0, #'0'
    cmp     w10, #7
    b.hi    5b
343: RXPEEK
    sub     w9, w0, #'0'
    cmp     w9, #7
    b.hi    344f
    add     w11, w9, w10, lsl #3
    cmp     w11, #255
    b.hi    344f
    mov     w10, w11
    add     x22, x22, #1
    b       343b
344: mov    w0, w10
    b       5b
35: bl      rxc_escchar
    b       5b
// the repeat, if one follows: 24 least, 32 most (-1: no end), 40 lazy
50: RXPEEK
    mov     x9, #0
    mov     x10, #-1
    cmp     w0, #'*'
    b.eq    55f
    mov     x9, #1
    cmp     w0, #'+'
    b.eq    55f
    mov     x9, #0
    mov     x10, #1
    cmp     w0, #'?'
    b.eq    55f
    cmp     w0, #'{'
    b.ne    90f
    mov     x12, x22                    // {n}, {n,}, {n,m}; anything else leaves the brace an ordinary character
    add     x22, x22, #1
    bl      rxc_digits
    cbz     x11, 59f
    mov     x9, x10
    RXPEEK
    cmp     w0, #'}'
    b.eq    54f
    cmp     w0, #','
    b.ne    59f
    add     x22, x22, #1
    RXPEEK
    mov     x10, #-1
    cmp     w0, #'}'
    b.eq    54f
    stp     x9, x12, [sp, #24]
    bl      rxc_digits
    ldp     x9, x12, [sp, #24]
    cbz     x11, 59f
    RXPEEK
    cmp     w0, #'}'
    b.ne    59f
    cmp     x10, x9
    b.lo    rxc_bad
54:
55: add     x22, x22, #1
    mov     x17, #0
    RXPEEK
    cmp     w0, #'?'
    b.ne    56f
    add     x22, x22, #1
    mov     x17, #1
56: mov     x15, x9
    mov     x16, x10
    ldr     x9, [sp, #8]
    sub     x13, x25, x9                // how many words the thing is
    ldr     x12, [sp, #16]
    ldr     x6, [sp, #48]               // the groups inside it forget their match at each turn, if it can have more than one
    mov     x5, x26
    cmp     x5, x6
    cset    x7, hi
    cmp     x16, #1
    csel    x7, xzr, x7, eq
    add     x4, x7, x7, lsl #1
    add     x4, x4, x13                 // its words with that
    mov     x11, sp
    lsl     x10, x13, #1
    add     x10, x10, #15
    and     x10, x10, #0xfffffffffffffff0
    sub     sp, sp, x10
    mov     x14, #0
57: cmp     x14, x13                    // kept aside, then written out as often as wanted
    b.hs    58f
    add     x10, x9, x14
    ldrh    w8, [x24, x10, lsl #1]
    strh    w8, [sp, x14, lsl #1]
    add     x14, x14, #1
    b       57b
58: mov     x25, x9
    mov     x10, x15
60: cbz     x10, 61f
    bl      rxc_copy
    sub     x10, x10, #1
    b       60b
61: cmn     x16, #1
    b.ne    65f
    add     x10, x4, #2                 // no end: split out, [mark] the thing [it moved?], jump back
    cbz     x12, 62f
    add     x10, x10, #4
62: mov     w9, #RX_SPLIT
    mov     w8, #RX_SPLITJ
    cmp     x17, #0
    csel    w9, w8, w9, ne
    RXE     w9
    RXE     w10
    cbz     x12, 63f
    RXEI    RX_MARK
    RXE     w27
63: bl      rxc_copy
    cbz     x12, 64f
    RXEI    RX_CHKADV
    RXE     w27
    add     x27, x27, #1
64: RXEI    RX_JMP
    add     x10, x10, #2
    neg     x10, x10
    RXE     w10
    b       69f
65: sub     x10, x16, x15               // so many more times at most, each of them free to be left out
66: cbz     x10, 69f
    mov     w9, #RX_SPLIT
    mov     w8, #RX_SPLITJ
    cmp     x17, #0
    csel    w9, w8, w9, ne
    RXE     w9
    add     x14, x4, #2
    mul     x14, x14, x10
    sub     x14, x14, #2
    cmp     x14, #28672
    b.hi    rxc_big
    RXE     w14
    bl      rxc_copy
    sub     x10, x10, #1
    b       66b
69: mov     sp, x11
    b       90f
59: mov     x22, x12
90: ldr     x30, [sp]
    add     sp, sp, #64
    ret
// rxc_copy: the x13 words kept at sp join the program. Uses x14, w8.
rxc_copy:
    cbz     x7, 0f
    RXEI    RX_CLEAR
    RXE     w6
    RXE     w5
0:  mov     x14, #0
1:  cmp     x14, x13
    b.hs    2f
    ldrh    w8, [sp, x14, lsl #1]
    RXE     w8
    add     x14, x14, #1
    b       1b
2:  ret
// rxc_digits: a whole number in the pattern -> x10 the number (at most 1000), x11 how many digits. Uses w0.
rxc_digits:
    mov     x10, #0
    mov     x11, #0
1:  RXPEEK
    sub     w0, w0, #'0'
    cmp     w0, #9
    b.hi    2f
    add     x22, x22, #1
    add     x11, x11, #1
    mov     x8, #10
    madd    x10, x10, x8, x0
    cmp     x10, #1000
    b.hi    rxc_big
    b       1b
2:  ret
// rxc_whichclass: is w0 one of d D w W s S -> x12 its table, or 0
rxc_whichclass:
    adr     x12, k_rxd
    cmp     w0, #'d'
    b.eq    1f
    adr     x12, k_rxnd
    cmp     w0, #'D'
    b.eq    1f
    adr     x12, k_rxw
    cmp     w0, #'w'
    b.eq    1f
    adr     x12, k_rxnw
    cmp     w0, #'W'
    b.eq    1f
    adr     x12, k_rxs
    cmp     w0, #'s'
    b.eq    1f
    adr     x12, k_rxns
    cmp     w0, #'S'
    b.eq    1f
    mov     x12, #0
1:  ret
// rxc_table: the pairs of the table x12 join the program -> x11 how many, w0 -1. Uses w8, x9.
rxc_table:
    ldrh    w11, [x12], #2
    lsl     x9, x11, #1
1:  cbz     x9, 2f
    ldrh    w8, [x12], #2
    RXE     w8
    sub     x9, x9, #1
    b       1b
2:  mov     w0, #-1
    ret
// rxc_classatom: inside a class, w0 the unit just read -> w0 the unit it stands for, or -1 if it was a class of its own
// (\d and so on), whose pairs have joined the program, x11 of them.
rxc_classatom:
    cmp     w0, #'\\'
    b.ne    9f
    RXPEEK
    cmn     w0, #1
    b.eq    rxc_bad
    add     x22, x22, #1
    cmp     w0, #'b'
    b.ne    1f
    mov     w0, #8
    ret
1:  mov     x13, x30
    bl      rxc_whichclass
    mov     x30, x13
    cbnz    x12, rxc_table
    b       rxc_escchar
9:  ret
// rxc_escchar: w0 the unit after a backslash -> the unit meant. Uses x9-x12.
rxc_escchar:
    mov     w9, #10
    cmp     w0, #'n'
    b.eq    8f
    mov     w9, #13
    cmp     w0, #'r'
    b.eq    8f
    mov     w9, #9
    cmp     w0, #'t'
    b.eq    8f
    mov     w9, #12
    cmp     w0, #'f'
    b.eq    8f
    mov     w9, #11
    cmp     w0, #'v'
    b.eq    8f
    mov     w9, #0
    cmp     w0, #'0'
    b.eq    8f
    mov     x10, #2
    cmp     w0, #'x'
    b.eq    2f
    mov     x10, #4
    cmp     w0, #'u'
    b.eq    2f
    cmp     w0, #'c'
    b.ne    9f
    mov     w11, w0
    RXPEEK
    orr     w9, w0, #32
    sub     w9, w9, #'a'
    cmp     w9, #25
    csel    w0, w11, w0, hi
    b.hi    9f
    add     x22, x22, #1
    and     w0, w0, #31
    ret
2:  mov     w11, w0                     // two or four hex digits, or else the letter itself
    mov     x12, x22
    mov     w9, #0
3:  RXPEEK
    sub     w0, w0, #'0'
    cmp     w0, #9
    b.ls    4f
    add     w0, w0, #'0'
    orr     w0, w0, #32
    sub     w0, w0, #'a'
    cmp     w0, #5
    b.hi    5f
    add     w0, w0, #10
4:  add     w9, w0, w9, lsl #4
    add     x22, x22, #1
    subs    x10, x10, #1
    b.ne    3b
8:  mov     w0, w9
9:  ret
5:  mov     x22, x12
    mov     w0, w11
    ret
    .balign 2
k_rxd:  .hword 1, 0x30, 0x39
k_rxnd: .hword 2, 0, 0x2f, 0x3a, 0xffff
k_rxw:  .hword 4, 0x30, 0x39, 0x41, 0x5a, 0x5f, 0x5f, 0x61, 0x7a
k_rxnw: .hword 5, 0, 0x2f, 0x3a, 0x40, 0x5b, 0x5e, 0x60, 0x60, 0x7b, 0xffff
k_rxs:  .hword 10, 9, 13, 0x20, 0x20, 0xa0, 0xa0, 0x1680, 0x1680, 0x2000, 0x200a, 0x2028, 0x2029, 0x202f, 0x202f
        .hword 0x205f, 0x205f, 0x3000, 0x3000, 0xfeff, 0xfeff
k_rxns: .hword 11, 0, 8, 14, 0x1f, 0x21, 0x9f, 0xa1, 0x167f, 0x1681, 0x1fff, 0x200b, 0x2027, 0x202a, 0x202e
        .hword 0x2030, 0x205e, 0x2060, 0x2fff, 0x3001, 0xfefe, 0xff00, 0xffff
    .balign 4
