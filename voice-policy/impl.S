// voice-policy, written by hand (ARM64). The meaning is voice-policy/intent.md; the recorded checks are the judge.
// A piece without state: x0 numbers (16-bit), x1 how many, x2 unused. A number that is not given counts as zero.
    .text
    .global skip_ahead
    .global duck_volume
    .global filler_wait
    .global points_wait
    .global join_wait
    .macro  NUM reg, i
    mov     \reg, #0
    cmp     x1, #\i
    b.le    55f
    ldrsh   \reg, [x0, #(\i * 2)]
55:
    .endm
skip_ahead:                             // waited long enough for the words queued: number 0 plus 70 for each of number 1, at least 6000
    NUM     x3, 0
    NUM     x4, 1
    mov     x5, #70
    madd    x3, x4, x5, x3
    mov     x5, #6000
    cmp     x3, x5
    cset    x0, ge
    ret
duck_volume:                            // while speaking over playing media: the given percent (10 if not given, at most 100), in thousandths
    mov     x5, #-1
    cmp     x1, #3
    b.lt    1f
    ldrsh   x5, [x0, #4]
1:  mov     x6, #10
    cmp     x5, #0
    csel    x5, x6, x5, lt
    mov     x6, #100
    cmp     x5, x6
    csel    x5, x6, x5, gt
    NUM     x3, 0
    NUM     x4, 1
    mov     x6, #10
    mul     x5, x5, x6
    mov     x6, #1000
    cmp     x3, #0
    ccmp    x4, #0, #4, ne
    csel    x0, x5, x6, ne
    ret
filler_wait:
    NUM     x3, 0
    mov     x4, #8000
    mov     x5, #25000
    cmp     x3, #0
    csel    x0, x4, x5, le
    ret
points_wait:
    mov     x0, #1500
    ret
join_wait:
    NUM     x3, 0
    mov     x4, #5000
    mov     x5, #3500
    cmp     x3, #5
    csel    x0, x4, x5, le
    ret
