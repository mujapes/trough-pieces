#!/usr/bin/env python3
"""Draws paired bars with the paint and font pieces.   show_bars.py out.png "Title" "unit" "first name" "second name" label:a:b ...
Each row shows two bars (first in blue-grey, second in green) scaled to the largest value, with the numbers written beside them."""
import sys,subprocess,zlib,struct
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; out,title,unit,na,nb=sys.argv[1:6]; rows=[(r.split(':')[0],float(r.split(':')[1]),float(r.split(':')[2])) for r in sys.argv[6:]]
W=720; H=118+len(rows)*58+10; top=max(max(a,b) for _,a,b in rows); span=300
text=lambda colour,size,x,y,s:'%sout/font.ref draw %08x 20 %d %d %d %s\n'%(P,colour,size,x,y,' '.join(str(ord(c)) for c in s))
rect=lambda colour,x,y,w,h:'%sout/paint.ref fill_rect %s %d %d %d %d\n'%(P,colour,x,y,max(2,w),h)
cmd='@file 20 %sout/font.fixture\n%sout/paint.ref clear ff2b1a12\n'%(P,P)+rect('ff3d2a1e',0,0,W,64)+text(0xffffffff,28,20,43,title)
cmd+=rect('ffa08a78',20,80,18,18)+text(0xffe8f1ee,19,46,96,na)+rect('ff62b06a',300,80,18,18)+text(0xffe8f1ee,19,326,96,nb)
for i,(label,a,b) in enumerate(rows):
    y=118+i*58; cmd+=text(0xffe8f1ee,21,20,y+30,label[:20])+rect('ffa08a78',250,y+2,int(a/top*span),20)+rect('ff62b06a',250,y+26,int(b/top*span),20)
    cmd+=text(0xffc8c0b8,18,258+int(a/top*span),y+19,'%.1f %s'%(a,unit))+text(0xffb8e8c0,18,258+int(b/top*span),y+43,'%.1f %s'%(b,unit))
subprocess.run([P+'out/render',P+'out',str(W),str(H),'/tmp/bars.rgba'],input=cmd.encode(),capture_output=True)
raw=open('/tmp/bars.rgba','rb').read(); rowsb=b''.join(b'\0'+raw[i*W*4:(i+1)*W*4] for i in range(H)); chunk=lambda t,d:struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d))
open(out,'wb').write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rowsb,6))+chunk(b'IEND',b''))
