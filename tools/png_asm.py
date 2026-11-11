#!/usr/bin/env python3
"""Writes png/impl.S. The assembly is written by hand; this script only lays out the frame."""
import os
here=os.path.dirname(os.path.abspath(__file__))+'/../png/'
off={}; at=96
def room(name,size,align=8):
    global at; at=(at+align-1)//align*align; off[name]=at; at+=size
for n in ['WIDTH','HEIGHT','TYPE','CHANNELS','DEPTH','INTERLACE','LAST','NLEN','NDIST','TOTAL']: room(n,4,4)
for n in ['PLTE','PLTE_N','TRNS','TRNS_N','FIRST','ROOM','PASS','RAW','ROWLEN','PW','PH','X0','Y0','DX','DY','BPP','BITSPER','WRITTEN','R','SURF','NEEDT','TMPA','TMPB','TMPC']: room(n,8)
room('LENGTHS',320); room('CL',24); room('LIT',32+576); room('DIST',32+64); room('CODES',32+40); room('OFFS',32)
room('LTAB',1024); room('DTAB',1024); room('CTAB',256)
frame=(at+15)//16*16
eq=''.join('    .equ %s, %d\n'%kv for kv in off.items())+'    .equ FRAME, %d\n'%frame
src=open(here+'impl.body.S').read().replace('@EQU@\n',eq)
open(here+'impl.S','w').write(src); print('frame',frame)
