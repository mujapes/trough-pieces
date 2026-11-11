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
def K(val):
    if val>=0: A('    mov     w16, #%d'%val)
    else: A('    mov     w16, #-%d'%(-val))
    A('    dup     v25.4s, w16')
# The same arithmetic on four values at once. Inputs s0..s7 in v0..v7; results: X0..X3 in v16..v19, T0..T3 in v7, v5, v3, v1.
# Uses v20-v25, w16, and v0, v2, v4, v6.
A('    .macro  VKERNEL')
K(F(0.5411961)); A('    add     v20.4s, v2.4s, v6.4s'); A('    mul     v20.4s, v20.4s, v25.4s')
K(F(-1.847759065)); A('    mov     v21.16b, v20.16b'); A('    mla     v21.4s, v6.4s, v25.4s')
K(F(0.765366865)); A('    mov     v22.16b, v20.16b'); A('    mla     v22.4s, v2.4s, v25.4s')
A('    add     v23.4s, v0.4s, v4.4s'); A('    shl     v23.4s, v23.4s, #12'); A('    sub     v24.4s, v0.4s, v4.4s'); A('    shl     v24.4s, v24.4s, #12')
A('    add     v16.4s, v23.4s, v22.4s'); A('    sub     v19.4s, v23.4s, v22.4s'); A('    add     v17.4s, v24.4s, v21.4s'); A('    sub     v18.4s, v24.4s, v21.4s')
A('    add     v0.4s, v7.4s, v3.4s'); A('    add     v2.4s, v5.4s, v1.4s'); A('    add     v4.4s, v7.4s, v1.4s'); A('    add     v6.4s, v5.4s, v3.4s')
K(F(1.175875602)); A('    add     v20.4s, v0.4s, v2.4s'); A('    mul     v20.4s, v20.4s, v25.4s')
for r,c in (('v7',0.298631336),('v5',2.053119869),('v3',3.072711026),('v1',1.501321110)): K(F(c)); A('    mul     %s.4s, %s.4s, v25.4s'%(r,r))
K(F(-0.899976223)); A('    mov     v21.16b, v20.16b'); A('    mla     v21.4s, v4.4s, v25.4s')
K(F(-2.562915447)); A('    mov     v22.16b, v20.16b'); A('    mla     v22.4s, v6.4s, v25.4s')
K(F(-1.961570560)); A('    mul     v0.4s, v0.4s, v25.4s')
K(F(-0.390180644)); A('    mul     v2.4s, v2.4s, v25.4s')
A('    add     v1.4s, v1.4s, v21.4s'); A('    add     v1.4s, v1.4s, v2.4s')
A('    add     v3.4s, v3.4s, v22.4s'); A('    add     v3.4s, v3.4s, v0.4s')
A('    add     v5.4s, v5.4s, v22.4s'); A('    add     v5.4s, v5.4s, v2.4s')
A('    add     v7.4s, v7.4s, v21.4s'); A('    add     v7.4s, v7.4s, v0.4s')
A('    .endm')
src=open(here+'impl.body.S').read().replace('@EQU@\n',eq).replace('@KERNEL@\n','\n'.join(L)+'\n')
open(here+'impl.S','w').write(src); print('frame',frame,[F(c) for c in (0.5411961,-1.847759065,1.175875602)])
