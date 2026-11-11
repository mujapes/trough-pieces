#!/usr/bin/env python3
"""Writes jpeg/impl.S from jpeg/impl.body.S. The assembly is written by hand; this script lays out the frame and spells out the
one-dimensional transform (the "slow integer" method) with its constants worked out exactly as the meaning's F() does."""
import os,struct
here=os.path.dirname(os.path.abspath(__file__))+'/../jpeg/'
f32=lambda x: struct.unpack('f',struct.pack('f',x))[0]
def F(x):
    v=f32(f32(x)*f32(4096.0))+0.5      # float times int stays float; adding 0.5 makes it double; the cast cuts towards zero
    return int(v)
off={}; at=96
def room(name,size,align=8):
    global at; at=(at+align-1)//align*align; off[name]=at; at+=size
for n in ['WIDTH','HEIGHT','COMPS','HMAX','VMAX','RESTART','PROG','LM']: room(n,4,4)
room('SCAN',8); room('C0',48*3); room('QUANT',512); room('HUFF',8*280)
for n in ['SURF','SCRATCH','NEEDP','PLANE','IDCT_LR','CO','P_END','P_AT','P_BODY','ONE','TMP','TMP2','BLK','CAT0','CAT1','CAT2']: room(n,8)
for n in ['MX','MY','ROW','COL','DONE','CI','BY','BX','STRIDE','NS','CIDX0','CIDX1','CIDX2','SS','SE','AH','AL','EOB','BW','BH','TOTAL','NN','SCANS','K','I2']: room(n,4,4)
room('COEF',256); room('VBUF',256); room('TABS',8*1024)
frame=(at+15)//16*16
eq=''.join('    .equ %s, %d\n'%kv for kv in off.items())+'    .equ FRAME, %d\n'%frame
L=[]; A=L.append
def K(reg,val):
    if val>=0: A('    mov     %s, #%d'%(reg,val))
    else: A('    mov     %s, #-%d'%(reg,-val))
# inputs s0..s7 in w0..w7; results: X0..X3 in w8..w11, T0..T3 in w7, w5, w3, w1. Uses w12-w17 and w0, w2, w4, w6.
A('    .macro  KERNEL')
K('w17',F(0.5411961)); A('    add     w12, w2, w6'); A('    mul     w12, w12, w17')
K('w17',F(-1.847759065)); A('    madd    w13, w6, w17, w12')
K('w17',F(0.765366865)); A('    madd    w14, w2, w17, w12')
A('    add     w15, w0, w4'); A('    lsl     w15, w15, #12'); A('    sub     w16, w0, w4'); A('    lsl     w16, w16, #12')
A('    add     w8, w15, w14'); A('    sub     w11, w15, w14'); A('    add     w9, w16, w13'); A('    sub     w10, w16, w13')
A('    add     w0, w7, w3'); A('    add     w2, w5, w1'); A('    add     w4, w7, w1'); A('    add     w6, w5, w3')
K('w17',F(1.175875602)); A('    add     w12, w0, w2'); A('    mul     w12, w12, w17')
for r,c in (('w7',0.298631336),('w5',2.053119869),('w3',3.072711026),('w1',1.501321110)): K('w17',F(c)); A('    mul     %s, %s, w17'%(r,r))
K('w17',F(-0.899976223)); A('    madd    w4, w4, w17, w12')
K('w17',F(-2.562915447)); A('    madd    w6, w6, w17, w12')
K('w17',F(-1.961570560)); A('    mul     w0, w0, w17')
K('w17',F(-0.390180644)); A('    mul     w2, w2, w17')
A('    add     w1, w1, w4'); A('    add     w1, w1, w2')
A('    add     w3, w3, w6'); A('    add     w3, w3, w0')
A('    add     w5, w5, w6'); A('    add     w5, w5, w2')
A('    add     w7, w7, w4'); A('    add     w7, w7, w0')
A('    .endm')
src=open(here+'impl.body.S').read().replace('@EQU@\n',eq).replace('@KERNEL@\n','\n'.join(L)+'\n')
open(here+'impl.S','w').write(src); print('frame',frame,[F(c) for c in (0.5411961,-1.847759065,1.175875602)])
