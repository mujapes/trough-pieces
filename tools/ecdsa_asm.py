#!/usr/bin/env python3
"""Writes ecdsa/impl.S. The assembly below is written by hand; this script only lays out the frame, spells the curve constants out
of curves.h and expands the three-operand lines of the point formulas."""
import re,os
here=os.path.dirname(os.path.abspath(__file__))+'/../ecdsa/'
consts={m.group(1):[int(v) for v in m.group(2).split(',')] for m in re.finditer(r'(P\d+_\w+)\[\d+\] = \{([^}]*)\}',open(here+'curves.h').read())}
off={}; at=96
def room(name,size):
    global at; off[name]=at; at+=size
for n in ['BX','BY','BR','BS','BD','IDX']: room(n,8)
for n in ['FP','FN']: room(n,160)
for n in ['T']: room(n,64)
nums=['E','NX','NY','NR','NS','NZ','CB','MX','MY','THREE','L','RT','W','U1','U2','PLAIN1','A1','A2','A3','A4','A5','A6','A7','A8','ZI','AX']
for n in nums: room(n,48)
for n in ['G','Q','BOTH','R']: room(n,160)
frame=(at+15)//16*16
L=[]; A=L.append
def addr(reg,spec):
    # spec: frame name, or P.x / Q.y style (x25 / x26 based)
    if '.' in spec:
        b,f=spec.split('.'); base={'P':'x25','Q':'x26'}[b]; o={'x':0,'y':48,'z':96}[f]
        A('    add     %s, %s, #%d'%(reg,base,o)) if o else A('    mov     %s, %s'%(reg,base))
    else: A('    add     %s, x19, #%s'%(reg,spec))
def op(fn,d,a,b):
    addr('x0',d); addr('x1',a); addr('x2',b); A('    bl      '+fn)
def seq(text):
    for line in text.strip().split('\n'):
        d,rest=[s.strip() for s in line.split('=')]; m=re.match(r'(\S+) ([*+-]) (\S+)',rest)
        op({'*':'fmul','+':'fadd','-':'fsub'}[m.group(2)],d,m.group(1),m.group(3))
A('''// ecdsa, written by hand (ARM64): checks ECDSA signatures on P-256 and P-384. The meaning is ecdsa/intent.md; the recorded checks
// are the judge. Laid out by tools/ecdsa_asm.py (frame offsets, constants, and the point formulas' three-operand lines).
// Entry: x0 block (unused), x1 numbers (16-bit), x2 how many, x3 argument, x4 call table.
// Numbers are 64-bit limbs, lowest first, 4 or 6 of them, in 48-byte places in the frame. Through the entry: x19 the frame, x20 the
// call table, x21 how many limbs, x22 the field in use (modulus, 2^(128 limbs), 2^(64 limbs), minus one over the modulus),
// x23 the curve's bytes. x24-x28 are free for the routines: x25 and x26 point at the points being worked on.
    .text
    .global verify''')
for k,v in off.items(): A('    .equ %s, %d'%(k,v))
A('    .equ FRAME, %d'%frame)
A('''
// ge: is the number at x0 at least the number at x1 -> x0 1 or 0. Uses x9-x11.
ge:
    mov     x9, x21
1:  sub     x9, x9, #1
    ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    cmp     x10, x11
    b.ne    2f
    cbnz    x9, 1b
    mov     x0, #1
    ret
2:  cset    x0, hi
    ret
// take: the number at x0 less the number at x1, in place. Uses x9-x12.
take:
    mov     x9, #0
    cmp     x9, x9
1:  ldr     x10, [x0, x9, lsl #3]
    ldr     x11, [x1, x9, lsl #3]
    sbcs    x10, x10, x11
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 1b
    ret
// zero: is the number at x0 zero -> x0 1 or 0. Uses x9-x11.
zero:
    mov     x9, #0
    mov     x10, #0
1:  ldr     x11, [x0, x9, lsl #3]
    orr     x10, x10, x11
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    1b
    cmp     x10, #0
    cset    x0, eq
    ret
// copy: the number at x1 to x0. Uses x9, x10.
copy:
    mov     x9, #0
1:  ldr     x10, [x1, x9, lsl #3]
    str     x10, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    1b
    ret
''')
def fmul_k(k):
    t=['x%d'%(3+i) for i in range(k+2)]; bi,c,lo,hi,tmp,q=['x%d'%(3+k+2+i) for i in range(6)] if k==4 else ['x11','x12','x13','x14','x15','x16']
    A('fmul%d:'%k)
    for r in t: A('    mov     %s, #0'%r)
    for i in range(k):
        A('    ldr     %s, [x2, #%d]'%(bi,8*i)); 
        for jj in range(k):
            A('    ldr     %s, [x1, #%d]'%(tmp,8*jj)); A('    mul     %s, %s, %s'%(lo,tmp,bi)); A('    umulh   %s, %s, %s'%(hi,tmp,bi))
            A('    adds    %s, %s, %s'%(t[jj],t[jj],lo))
            if jj==0: A('    adc     %s, %s, xzr'%(c,hi))
            else: A('    adc     %s, %s, xzr'%(hi,hi)); A('    adds    %s, %s, %s'%(t[jj],t[jj],c)); A('    adc     %s, %s, xzr'%(c,hi))
        A('    adds    %s, %s, %s'%(t[k],t[k],c)); A('    cset    %s, cs'%t[k+1])
        A('    ldr     %s, [x22, #144]'%tmp); A('    mul     %s, %s, %s'%(q,t[0],tmp))
        A('    ldr     %s, [x22]'%tmp); A('    mul     %s, %s, %s'%(lo,q,tmp)); A('    umulh   %s, %s, %s'%(hi,q,tmp)); A('    adds    %s, %s, %s'%(lo,lo,t[0])); A('    adc     %s, %s, xzr'%(c,hi))
        for jj in range(1,k):
            A('    ldr     %s, [x22, #%d]'%(tmp,8*jj)); A('    mul     %s, %s, %s'%(lo,q,tmp)); A('    umulh   %s, %s, %s'%(hi,q,tmp))
            A('    adds    %s, %s, %s'%(lo,lo,t[jj])); A('    adc     %s, %s, xzr'%(hi,hi)); A('    adds    %s, %s, %s'%(t[jj-1],lo,c)); A('    adc     %s, %s, xzr'%(c,hi))
        A('    adds    %s, %s, %s'%(t[k-1],t[k],c)); A('    adc     %s, %s, xzr'%(t[k],t[k+1]))
    s_=[bi,c,lo,hi,tmp,q][:k]
    for jj in range(k):
        A('    ldr     x17, [x22, #%d]'%(8*jj)); A('    %s    %s, %s, x17'%('subs' if jj==0 else 'sbcs',s_[jj],t[jj]))
    A('    sbcs    x17, %s, xzr'%t[k])
    for jj in range(k): A('    csel    %s, %s, %s, cs'%(t[jj],s_[jj],t[jj]))
    for jj in range(0,k,2): A('    stp     %s, %s, [x0, #%d]'%(t[jj],t[jj+1],8*jj))
    A('    ret')
A("""// fmul: x0 = x1 times x2, divided by 2^(64 limbs), modulo the field's modulus (Montgomery's product), spelled out for four limbs
// and for six with the running value in registers and no branch on any value. Uses x3-x17.
fmul:
    cmp     x21, #4
    b.ne    fmul6""")
fmul_k(4); fmul_k(6)
def fadd_k(k):
    t=['x%d'%(3+i) for i in range(k)]; u=['x%d'%(9+i) for i in range(k)]
    A('fadd%d:'%k)
    for jj in range(k):
        A('    ldr     %s, [x1, #%d]'%(t[jj],8*jj)); A('    ldr     x15, [x2, #%d]'%(8*jj)); A('    %s    %s, %s, x15'%('adds' if jj==0 else 'adcs',t[jj],t[jj]))
    A('    cset    x16, cs')
    for jj in range(k):
        A('    ldr     x15, [x22, #%d]'%(8*jj)); A('    %s    %s, %s, x15'%('subs' if jj==0 else 'sbcs',u[jj],t[jj]))
    A('    sbcs    x16, x16, xzr')
    for jj in range(k): A('    csel    %s, %s, %s, cs'%(t[jj],u[jj],t[jj]))
    for jj in range(0,k,2): A('    stp     %s, %s, [x0, #%d]'%(t[jj],t[jj+1],8*jj))
    A('    ret')
def fsub_k(k):
    t=['x%d'%(3+i) for i in range(k)]
    A('fsub%d:'%k)
    for jj in range(k):
        A('    ldr     %s, [x1, #%d]'%(t[jj],8*jj)); A('    ldr     x15, [x2, #%d]'%(8*jj)); A('    %s    %s, %s, x15'%('subs' if jj==0 else 'sbcs',t[jj],t[jj]))
    A('    csetm   x16, cc')
    for jj in range(k):
        A('    ldr     x15, [x22, #%d]'%(8*jj)); A('    and     x15, x15, x16'); A('    %s    %s, %s, x15'%('adds' if jj==0 else 'adcs',t[jj],t[jj]))
    for jj in range(0,k,2): A('    stp     %s, %s, [x0, #%d]'%(t[jj],t[jj+1],8*jj))
    A('    ret')
A("""// fadd: x0 = x1 + x2 modulo the field's modulus; fsub: x0 = x1 - x2. Spelled out for four limbs and for six, no branch on any
// value. Use x3-x16.
fadd:
    cmp     x21, #4
    b.ne    fadd6""")
fadd_k(4); fadd_k(6)
A("""fsub:
    cmp     x21, #4
    b.ne    fsub6""")
fsub_k(4); fsub_k(6)
A('''
// load: the x2 bytes at x1 (most significant first) as a number at x0 -> x0 1, or 0 if it does not fit. Uses x9-x14.
load:
    mov     x9, #0
1:  str     xzr, [x0, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    1b
    mov     x9, #0
2:  cmp     x9, x2
    b.hs    5f
    ldrb    w11, [x1, x9]
    sub     x12, x2, x9
    sub     x12, x12, #1
    add     x9, x9, #1
    lsr     x13, x12, #3
    cmp     x13, x21
    b.lo    3f
    cbz     w11, 2b
    mov     x0, #0
    ret
3:  and     x12, x12, #7
    lsl     x12, x12, #3
    lsl     x11, x11, x12
    ldr     x14, [x0, x13, lsl #3]
    orr     x14, x14, x11
    str     x14, [x0, x13, lsl #3]
    b       2b
5:  mov     x0, #1
    ret
// setup: the field at x22 from the modulus's bytes at x0. Both moduli of both curves have their top bit set, so 2^(64 limbs)
// modulo the modulus is simply its negative; 2^(128 limbs) follows by doubling. Uses x24.
setup:
    stp     x29, x30, [sp, #-16]!
    mov     x1, x0
    mov     x0, x22
    mov     x2, x23
    bl      load
    ldr     x9, [x22]
    mov     x10, #1
    mov     x11, #6
1:  mul     x12, x9, x10
    mov     x13, #2
    sub     x13, x13, x12
    mul     x10, x10, x13
    subs    x11, x11, #1
    b.ne    1b
    neg     x10, x10
    str     x10, [x22, #144]
    add     x13, x22, #96
    add     x14, x22, #48
    mov     x9, #0
    cmp     x9, x9
2:  ldr     x11, [x22, x9, lsl #3]
    sbcs    x10, xzr, x11
    str     x10, [x13, x9, lsl #3]
    str     x10, [x14, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 2b
    lsl     x24, x21, #6
3:  add     x0, x22, #48
    mov     x1, x0
    mov     x2, x0
    bl      fadd
    subs    x24, x24, #1
    b.ne    3b
    ldp     x29, x30, [sp], #16
    ret
// inverse: x0 = one over x1 in the field, as x1 to the power of the modulus less two (the modulus is prime). x0 is not x1.
// Uses x24, x27, x28.
inverse:
    stp     x29, x30, [sp, #-16]!
    mov     x27, x0
    mov     x28, x1
    add     x0, x19, #E
    mov     x1, x22
    bl      copy
    add     x13, x19, #E
    ldr     x10, [x13]
    subs    x10, x10, #2
    str     x10, [x13]
    mov     x9, #1
1:  ldr     x10, [x13, x9, lsl #3]
    sbcs    x10, x10, xzr
    str     x10, [x13, x9, lsl #3]
    add     x9, x9, #1
    sub     x12, x21, x9
    cbnz    x12, 1b
    mov     x0, x27
    add     x1, x22, #96
    bl      copy
    lsl     x24, x21, #6
2:  subs    x24, x24, #1
    b.mi    3f
    mov     x0, x27
    mov     x1, x27
    mov     x2, x27
    bl      fmul
    add     x13, x19, #E
    lsr     x9, x24, #6
    ldr     x10, [x13, x9, lsl #3]
    lsr     x10, x10, x24
    tbz     x10, #0, 2b
    mov     x0, x27
    mov     x1, x27
    mov     x2, x28
    bl      fmul
    b       2b
3:  ldp     x29, x30, [sp], #16
    ret
// twice: the point at x0 doubled, in place. A point is x, y, z (the true point being x/z^2, y/z^3) and a mark for "nowhere".
twice:
    stp     x29, x30, [sp, #-32]!
    str     x25, [sp, #16]
    mov     x25, x0
    ldr     x9, [x25, #144]
    cbnz    x9, t_nowhere
    add     x0, x25, #48
    bl      zero
    cbnz    x0, t_nowhere''')
seq('''A1 = P.z * P.z
A2 = P.y * P.y
A3 = P.x * A2
A4 = P.x - A1
A5 = P.x + A1
A4 = A4 * A5
A6 = A4 + A4
A6 = A6 + A4
A3 = A3 + A3
A3 = A3 + A3
A5 = P.y + P.z
A5 = A5 * A5
A5 = A5 - A2
P.z = A5 - A1
P.x = A6 * A6
A4 = A3 + A3
P.x = P.x - A4
A2 = A2 * A2
A2 = A2 + A2
A2 = A2 + A2
A2 = A2 + A2
A4 = A3 - P.x
A4 = A6 * A4
P.y = A4 - A2''')
A('''    b       t_out
t_nowhere:
    mov     x9, #1
    str     x9, [x25, #144]
t_out:
    ldr     x25, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// plus: the point at x0 becomes itself plus the point at x1
plus:
    stp     x29, x30, [sp, #-32]!
    stp     x25, x26, [sp, #16]
    mov     x25, x0
    mov     x26, x1
    ldr     x9, [x26, #144]
    cbnz    x9, p_out
    ldr     x9, [x25, #144]
    cbz     x9, 2f
    mov     x9, #0                      // nowhere plus a point is that point
1:  ldr     x10, [x26, x9, lsl #3]
    str     x10, [x25, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #19
    b.lo    1b
    b       p_out
2:''')
seq('''A1 = P.z * P.z
A2 = Q.z * Q.z
A3 = P.x * A2
A4 = Q.x * A1
A5 = P.y * Q.z
A5 = A5 * A2
A6 = Q.y * P.z
A6 = A6 * A1
A7 = A4 - A3
A8 = A6 - A5''')
A('''    add     x0, x19, #A7
    bl      zero
    cbz     x0, 4f
    add     x0, x19, #A8
    bl      zero
    cbz     x0, 3f
    mov     x0, x25                     // the same point twice
    bl      twice
    b       p_out
3:  mov     x9, #1                      // a point plus its mirror image
    str     x9, [x25, #144]
    b       p_out
4:''')
seq('''A1 = A7 * A7
A2 = A7 * A1
A4 = A3 * A1
P.z = P.z * Q.z
P.z = P.z * A7
P.x = A8 * A8
P.x = P.x - A2
A3 = A4 + A4
P.x = P.x - A3
A3 = A4 - P.x
A3 = A8 * A3
A5 = A5 * A2
P.y = A3 - A5''')
A('''p_out:
    ldp     x25, x26, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret
// bytes_at: the plain block of 1 to 80 bytes at the handle in number x0 (numbers x24, count x25) -> x0, or 0. Uses x9.
bytes_at:
    cmp     x25, x0
    b.le    8f
    ldrsh   x9, [x24, x0, lsl #1]
    cmp     x9, #0
    b.lt    8f
    cmp     x9, #255
    b.gt    8f
    add     x9, x9, #256
    ldr     x0, [x20, x9, lsl #3]
    cbz     x0, 9f
    ldr     w9, [x0]
    cmp     w9, #2
    b.ne    8f
    ldr     x9, [x0, #16]
    cmp     x9, #64
    b.ls    8f
    cmp     x9, #(64 + 80)
    b.ls    9f
8:  mov     x0, #0
9:  ret

    .macro  LOADB dst, blk, fail
    ldr     x1, [x19, #\\blk]
    ldr     x2, [x1, #16]
    sub     x2, x2, #64
    add     x1, x1, #64
    add     x0, x19, #\\dst
    bl      load
    cbz     x0, \\fail
    .endm
    .macro  CONST dst, name
    adr     x1, c256_\\name
    adr     x9, c384_\\name
    cmp     x23, #32
    csel    x1, x1, x9, eq
    mov     x2, x23
    add     x0, x19, #\\dst
    bl      load
    .endm
    .macro  GE a, b
    add     x0, x19, #\\a
    add     x1, x19, #\\b
    bl      ge
    .endm
verify:
    sub     sp, sp, #FRAME
    stp     x29, x30, [sp]
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, sp
    mov     x20, x4
    mov     x24, x1
    mov     x25, x2
    cmp     x25, #0
    b.le    v_unusable
    ldrsh   x9, [x24]
    mov     x23, #32
    cmp     x9, #256
    b.eq    1f
    mov     x23, #48
    cmp     x9, #384
    b.ne    v_unusable
1:  lsr     x21, x23, #3''')
for i,n in enumerate(['BX','BY','BR','BS','BD']):
    A('    mov     x0, #%d\n    bl      bytes_at\n    cbz     x0, v_unusable\n    str     x0, [x19, #%s]'%(i+1,n))
A('''    add     x22, x19, #FN
    adr     x0, c256_n
    adr     x9, c384_n
    cmp     x23, #32
    csel    x0, x0, x9, eq
    bl      setup
    add     x22, x19, #FP
    adr     x0, c256_p
    adr     x9, c384_p
    cmp     x23, #32
    csel    x0, x0, x9, eq
    bl      setup
    LOADB   NX, BX, v_unusable
    LOADB   NY, BY, v_unusable
    LOADB   NR, BR, v_unusable
    LOADB   NS, BS, v_unusable
    GE      NX, FP
    cbnz    x0, v_unusable
    GE      NY, FP
    cbnz    x0, v_unusable
    add     x0, x19, #NR                // r and s must each be from 1 to the order less 1
    bl      zero
    cbnz    x0, v_no
    add     x0, x19, #NS
    bl      zero
    cbnz    x0, v_no
    GE      NR, FN
    cbnz    x0, v_no
    GE      NS, FN
    cbnz    x0, v_no
    CONST   CB, b
    CONST   A1, gx
    CONST   A2, gy
    add     x0, x19, #PLAIN1
    add     x1, x19, #NX
    bl      copy
    add     x0, x19, #PLAIN1
    mov     x1, x0
    mov     x2, #0
    bl      load                        // no bytes: zero
    mov     x9, #1
    str     x9, [x19, #PLAIN1]
    .macro  ENTERF dst, src
    add     x0, x19, #\\dst
    add     x1, x19, #\\src
    add     x2, x22, #48
    bl      fmul
    .endm
    .macro  LEAVEF dst, src
    add     x0, x19, #\\dst
    add     x1, x19, #\\src
    add     x2, x19, #PLAIN1
    bl      fmul
    .endm
    ENTERF  CB, CB
    ENTERF  G, A1                       // the curve's own point
    ENTERF  G + 48, A2
    ENTERF  Q, NX                       // the key
    ENTERF  Q + 48, NY
    add     x0, x19, #(G + 96)
    add     x1, x22, #96
    bl      copy
    add     x0, x19, #(Q + 96)
    add     x1, x22, #96
    bl      copy
    str     xzr, [x19, #(G + 144)]
    str     xzr, [x19, #(Q + 144)]
    add     x0, x19, #THREE
    add     x1, x22, #96
    mov     x2, x1
    bl      fadd
    add     x0, x19, #THREE
    mov     x1, x0
    add     x2, x22, #96
    bl      fadd
    add     x25, x19, #Q                // is the key a point on the curve: y^2 = x^3 - 3x + b''')
seq('''L = P.y * P.y
RT = P.x * P.x
RT = RT * P.x
A3 = THREE * P.x
RT = RT - A3
RT = RT + CB''')
A('''    mov     x9, #0
2:  add     x10, x19, #L
    add     x11, x19, #RT
    ldr     x10, [x10, x9, lsl #3]
    ldr     x11, [x11, x9, lsl #3]
    cmp     x10, x11
    b.ne    v_unusable
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    2b
    ldr     x1, [x19, #BD]              // the digest's leftmost bytes, as a number below the order
    ldr     x2, [x1, #16]
    sub     x2, x2, #64
    cmp     x2, x23
    csel    x2, x23, x2, hi
    add     x1, x1, #64
    add     x0, x19, #NZ
    bl      load
    GE      NZ, FN
    cbz     x0, 3f
    add     x0, x19, #NZ
    add     x1, x19, #FN
    bl      take
3:  add     x22, x19, #FN               // u1 = digest / s and u2 = r / s, modulo the order
    ENTERF  A1, NS
    add     x0, x19, #W
    add     x1, x19, #A1
    bl      inverse
    ENTERF  A1, NZ
    add     x0, x19, #A1
    mov     x1, x0
    add     x2, x19, #W
    bl      fmul
    LEAVEF  U1, A1
    ENTERF  A1, NR
    add     x0, x19, #A1
    mov     x1, x0
    add     x2, x19, #W
    bl      fmul
    LEAVEF  U2, A1
    add     x22, x19, #FP
    mov     x9, #0                      // BOTH = the curve's point plus the key
4:  add     x10, x19, #G
    add     x11, x19, #BOTH
    ldr     x10, [x10, x9, lsl #3]
    str     x10, [x11, x9, lsl #3]
    add     x9, x9, #1
    cmp     x9, #19
    b.lo    4b
    add     x0, x19, #BOTH
    add     x1, x19, #Q
    bl      plus
    mov     x9, #1                      // u1 times the curve's point plus u2 times the key, both at once from the top bit down
    str     x9, [x19, #(R + 144)]
    lsl     x24, x21, #6
5:  subs    x24, x24, #1
    b.mi    7f
    add     x0, x19, #R
    bl      twice
    lsr     x9, x24, #6
    add     x10, x19, #U1
    add     x11, x19, #U2
    ldr     x10, [x10, x9, lsl #3]
    ldr     x11, [x11, x9, lsl #3]
    lsr     x10, x10, x24
    lsr     x11, x11, x24
    and     x10, x10, #1
    and     x11, x11, #1
    orr     x9, x10, x11, lsl #1
    cbz     x9, 5b
    add     x1, x19, #G
    add     x12, x19, #Q
    add     x13, x19, #BOTH
    cmp     x9, #2
    csel    x1, x12, x1, eq
    cmp     x9, #3
    csel    x1, x13, x1, eq
    add     x0, x19, #R
    bl      plus
    b       5b
7:  ldr     x9, [x19, #(R + 144)]
    cbnz    x9, v_no
    add     x0, x19, #ZI                // its true x, as a plain number below the order, must be r
    add     x1, x19, #(R + 96)
    bl      inverse
    add     x0, x19, #A1
    add     x1, x19, #ZI
    mov     x2, x1
    bl      fmul
    add     x0, x19, #A1
    add     x1, x19, #R
    mov     x2, x0
    bl      fmul
    LEAVEF  AX, A1
    GE      AX, FN
    cbz     x0, 8f
    add     x0, x19, #AX
    add     x1, x19, #FN
    bl      take
8:  mov     x9, #0
9:  add     x10, x19, #AX
    add     x11, x19, #NR
    ldr     x10, [x10, x9, lsl #3]
    ldr     x11, [x11, x9, lsl #3]
    cmp     x10, x11
    b.ne    v_no
    add     x9, x9, #1
    cmp     x9, x21
    b.lo    9b
    mov     x0, #1
    b       v_out
v_no:
    mov     x0, #0
    b       v_out
v_unusable:
    mov     x0, #-1
v_out:
    ldp     x29, x30, [sp]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    add     sp, sp, #FRAME
    ret''')
for c in ('256','384'):
    for n in ('p','n','b','gx','gy'): A('c%s_%s: .byte %s'%(c,n,', '.join(str(v) for v in consts['P%s_%s'%(c,n)])))
A('    .balign 4')
open(here+'impl.S','w').write('\n'.join(L)+'\n'); print('frame',frame)
