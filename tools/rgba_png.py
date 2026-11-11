#!/usr/bin/env python3
"""rgba_png.py in.rgba width height out.png [keep_height]: a raw picture from the bench as a PNG (optionally only its top part)."""
import sys,zlib,struct
src,w,h,out=sys.argv[1],int(sys.argv[2]),int(sys.argv[3]),sys.argv[4]; keep=int(sys.argv[5]) if len(sys.argv)>5 else h
raw=open(src,'rb').read(); rows=b''.join(b'\0'+raw[i*w*4:(i+1)*w*4] for i in range(keep))
chunk=lambda t,d:struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d))
open(out,'wb').write(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,keep,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(rows,6))+chunk(b'IEND',b''))
