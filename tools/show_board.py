#!/usr/bin/env python3
"""Draws the pieces board with the pieces themselves: every piece, green when its code is live in the app, amber when the app
refused or is waiting, grey when the app has not reported it. Reads ~/.trough/pieces-status.json (written by the app).  show_board.py out.png"""
import sys,json,os,subprocess,zlib,struct,glob,time
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; S='/data/user/0/t.t/files/home/.trough/pieces-status.json'
names=sorted(os.path.basename(f)[:-6] for f in glob.glob(P+'out/*.piece')); st={}; age=None
try: d=json.load(open(S)); st={p['name']:p for p in d['pieces']}; age=time.time()-d['time_ms']/1000
except Exception: pass
cols=3; rows=(len(names)+cols-1)//cols; W=720; H=84+rows*44+46
text=lambda colour,size,x,y,s:'%sout/font.ref draw %08x 20 %d %d %d %s\n'%(P,colour,size,x,y,' '.join(str(ord(c)) for c in s))
live=sum(1 for n in names if st.get(n,{}).get('live'))
cmd='@file 20 %sout/font.fixture\n%sout/paint.ref clear ff2b1a12\n%sout/paint.ref fill_rect ff3d2a1e 0 0 %d 64\n'%(P,P,P,W)+text(0xffffffff,28,20,43,'Pieces live in the app: %d of %d'%(live,len(names)))
for i,n in enumerate(names):
    x=14+(i%cols)*236; y=78+(i//cols)*44; p=st.get(n); colour='ff5a9a62' if p and p.get('live') and not p['said'].startswith('kept') else 'ff3a8fd0' if p else 'ff5a4a40'
    cmd+='%sout/paint.ref fill_rect %s %d %d 224 36\n'%(P,colour,x,y)+text(0xffffffff,20,x+10,y+25,n[:18])
note='as the app reported %s'%('just now' if age is not None and age<90 else '%d min ago'%(age//60) if age is not None else '(no report from the app yet)')
bad=[n for n in names if st.get(n) and (not st[n].get('live') or st[n]['said'].startswith('kept'))]
cmd+=text(0xffb8d8f0,18,20,H-18,(note+('; held back: '+', '.join(bad) if bad else '; green = code running in the app, checked there first'))[:86])
subprocess.run([P+'out/render',P+'out',str(W),str(H),'/tmp/board.rgba'],input=cmd.encode(),capture_output=True)
raw=open('/tmp/board.rgba','rb').read(); rowsb=b''.join(b'\0'+raw[i*W*4:(i+1)*W*4] for i in range(H)); chunk=lambda t,d:struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d))
open(sys.argv[1],'wb').write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rowsb,6))+chunk(b'IEND',b''))
print(len(names),'pieces,',live,'live;',note,'; held back:',bad)
