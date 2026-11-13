#!/usr/bin/env python3
"""mkpak.py OUT [by Opus]: the pieces recovery needs for the network, in one file a verb loads with one read.
Layout (little-endian u32s): "TPAK", 256 slot offsets (code offset + 1, 0 empty), 4 tls entry offsets + 1
(migrate begin feed send), roots offset, roots length, code size; then the code (each piece 16-aligned), then the roots
(a kind-2 block body: the verb makes the block head). Offsets count from the start of the code."""
import sys,os,struct
D=os.path.dirname(os.path.abspath(__file__))+'/../../'
code=bytearray(); base={}
def piece(name):
    if name in base: return base[name]
    for stem in ('out/%s.live'%name,'out/%s'%name,'out/%s.ref'%name):
        if os.path.exists(D+stem+'.bin'): break
    b=open(D+stem+'.bin','rb').read(); ent={}
    for line in open(D+stem+'.entries'):
        p=line.split()
        if len(p)==2: ent[p[0]]=int(p[1])
    while len(code)%16: code.append(0)
    base[name]=(len(code),ent); code.extend(b); return base[name]
slots=[0]*256
for line in open(D+'slots.txt'):
    if line.startswith('#'): continue
    p=line.split()
    if len(p)>=3 and p[0].isdigit():
        n=int(p[0])
        if n<256:
            try: o,e=piece(p[1]); slots[n]=o+e[p[2]]+1
            except Exception as x: print('skip',p[1],p[2],x)
o,e=piece('tls'); tls=[o+e[k]+1 for k in ('migrate','begin','feed','send')]
roots=open(D+'out/android-roots.der','rb').read()
while len(code)%16: code.append(0)
ro=len(code); code.extend(roots)
head=b'TPAK'+struct.pack('<256I',*slots)+struct.pack('<4I',*tls)+struct.pack('<III',ro,len(roots),len(code))
open(sys.argv[1],'wb').write(head+code); print('pak',len(head)+len(code),'bytes;',len(base),'pieces')
