#!/usr/bin/env python3
"""Draws a progress card with Trough's own pieces (paint for the panels, font for the text, on the bench) and writes it as a PNG.
   show_card.py out.png "Title" "line" "line" ...   A line starting with + is drawn as done (green), - as open (amber), anything else plain."""
import sys,subprocess,zlib,struct
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; out,title,lines=sys.argv[1],sys.argv[2],sys.argv[3:]
W=720; H=96+34*len(lines)+20
def text(colour,size,x,y,s): return '%sout/font.ref draw %08x 20 %d %d %d %s\n'%(P,colour,size,x,y,' '.join(str(ord(c)) for c in s if ord(c)<32767))
cmd='@file 20 %sout/font.fixture\n'%P+'%sout/paint.ref clear ff2b1a12\n'%P+'%sout/paint.ref fill_rect ff3d2a1e 0 0 %d 70\n'%(P,W)+text(0xffffffff,30,24,46,title)
y=104
for l in lines:
    mark,body=(l[0],l[1:].strip()) if l[:1] in '+-' else ('',l)
    if mark: cmd+='%sout/paint.ref fill_rect %s 24 %d 14 14\n'%(P,'ff7ad08a' if mark=='+' else 'ff4ab4f0',y-14)
    cmd+=text(0xffe8f1ee if mark!='-' else 0xffb8d8f0,21,50 if mark else 24,y,body); y+=34
r=subprocess.run([P+'out/render',P+'out',str(W),str(H),'/tmp/card.rgba'],input=cmd.encode(),capture_output=True)
raw=open('/tmp/card.rgba','rb').read(); rows=b''.join(b'\0'+raw[i*W*4:(i+1)*W*4] for i in range(H))
def chunk(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d))
open(out,'wb').write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows,6))+chunk(b'IEND',b''))
print(W,H,len(lines),'lines;',r.stdout.decode().count('->'),'calls')
