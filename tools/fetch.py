#!/usr/bin/env python3
"""fetch.py <address> <out.png> [text size]: an address in, a picture of the page out, every step done by the pieces on the bench.
The only things done here are the host's: looking the site's name up, owning the socket (inside tlsbench for https), and keeping files.
url resolve/part/port -> http request -> tls (with trust, Android's roots) -> http status/header/body -> inflate -> page -> picture."""
import sys,subprocess,socket,os,time
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/fetch/'; os.makedirs(T,exist_ok=True)
def call(cmds,w=1,h=1,out='o'):
    r=subprocess.run([P+'out/render',P+'out',str(w),str(h),T+out],input=cmds.encode(),capture_output=True); return [int(l.split('->')[1]) for l in r.stdout.decode().strip().split('\n') if '->' in l]
def text(entry_line,room=3000):
    a=call('@surface 30 %d 1\n@target 30\n@output 30\n%s'%((room+3)//4,entry_line)); return None if not a or a[-1]<0 else open(T+'o','rb').read()[:a[-1]]
address=sys.argv[1]; log=[]; started=time.time()
for hop in range(6):
    open(T+'address','w').write(address); open(T+'self','w').write(address)
    address=text('@file 20 %saddress\n@file 21 %sself\n%sout/url.ref resolve 0 20 21\n'%(T,T,P)).decode(); open(T+'address','w').write(address)       # resolved against itself: the normal form
    site=text('@file 20 %saddress\n%sout/url.ref part 0 20 1\n'%(T,P)); scheme=text('@file 20 %saddress\n%sout/url.ref part 0 20 0\n'%(T,P)); port=call('@file 20 %saddress\n%sout/url.ref port 0 20\n'%(T,P))[-1]
    req=text('@file 20 %saddress\n%sout/http.ref request 0 20\n'%(T,P)); assert site and req and port>0,(site,port)
    site=site.decode().strip('[]'); open(T+'request','wb').write(req); ip=socket.getaddrinfo(site,port,socket.AF_INET)[0][4][0]
    if scheme==b'https':
        env=dict(os.environ,TLS_ROOTS=P+'out/android-roots.der',TLS_BODY=T+'reply',TLS_REQUEST=T+'request'); r=subprocess.run([P+'out/tlsbench',P+'out',ip,str(port),site],capture_output=True,env=env,timeout=40).stdout.decode()
        if 'CHECKED' not in r: log.append('%s: connection refused by our own check or failed: %s'%(site,[l for l in r.split('\n') if 'REFUSED' in l or 'closed' in l or 'failed' in l][:1])); break
        secure='verified secure connection'
    else:
        s=socket.create_connection((ip,port),timeout=20); s.sendall(req); data=b''
        while True:
            d=s.recv(65536)
            if not d: break
            data+=d
        open(T+'reply','wb').write(data); secure='plain connection'
    size=os.path.getsize(T+'reply'); status=call('@file 20 %sreply\n%sout/http.ref status 0 20\n'%(T,P))[-1]; log.append('%s -> %d, %d bytes, %s'%(address,status,size,secure))
    if status in (301,302,303,307,308):
        loc=text('@file 20 %sreply\n%sout/http.ref header 0 20 %s\n'%(T,P,' '.join(str(ord(c)) for c in 'location')))
        if not loc: break
        open(T+'loc','wb').write(loc.strip()); address=text('@file 20 %saddress\n@file 21 %sloc\n%sout/url.ref resolve 0 20 21\n'%(T,T,P)).decode(); continue
    break
room=max(4*size,200000)*6
cmds='@file 20 %sreply\n@block 21 2 %d\n@target 21\n%sout/http.ref packed 0 20\n%sout/http.ref body 0 20\n@resize 21 last\n'%(T,room,P,P)
packed=call(cmds)[0]; page_handle=21
if packed==1: cmds+='@block 22 2 %d\n@target 22\n%sout/inflate.ref unpack 0 21\n@resize 22 last\n'%(room,P); page_handle=22
# A picture rather than a page? Then our own decoder for its kind turns it into pixels, and the image piece scales it to fit.
body_cmds=cmds; call(body_cmds+'@output %d\n'%page_handle,1,1,'body'); body=open(T+'body','rb').read(); kind='png' if body[:8]==b'\x89PNG\r\n\x1a\n' else 'jpeg' if body[:2]==b'\xff\xd8' else 'gif' if body[:4]==b'GIF8' else None
if kind:
    ask='%sout/%s.ref size 0 %d\n'%(P,kind,page_handle); wh=call(body_cmds+ask)[-1]
    if wh<0: log.append('a %s our decoder cannot read'%kind); print('\n'.join(log)); sys.exit(1)
    iw,ih=wh>>16,wh&65535; W=720; H=max(1,min(1400,ih*W//iw)) if iw>W else ih; W2=W if iw>W else iw
    dec='%sout/%s.ref decode 0 %d 25%s\n'%(P,kind,page_handle,' 0' if kind=='gif' else '')
    t0=time.time(); ans=call(body_cmds+'@surface 24 %d %d\n@block 25 5 %d\n@target 24\n%s@target main\n%sout/paint.ref clear ffffffff\n%sout/image.ref %s 0 24 0 0 %d %d\n'%(iw,ih,64+max(iw*ih*8+ih*8+70000,20480+5*iw*ih+4096),dec,P,P,'smooth' if iw>W2 else 'blit',W2,H),W2,H,'page.rgba')
    log.append('%s picture %d x %d, decoded by our own %s piece (answer %d), %s; %.1f s in all'%(kind.upper(),iw,ih,kind,ans[-3],'shrunk to %d wide by the image piece'%W2 if iw>W2 else 'shown at its own size',time.time()-started))
    subprocess.run(['python3',P+'tools/rgba_png.py',T+'page.rgba',str(W2),str(H),sys.argv[2]]); print('\n'.join(log)); sys.exit(0)
size_px=int(sys.argv[3]) if len(sys.argv)>3 else 26; W,H=720,1100
cmds+='@file 23 %sout/font.fixture\n@target main\n%sout/paint.ref clear ffffffff\n%sout/page.ref render 0 %d 23 %d 0\n'%(P,P,P,page_handle,size_px)
ans=call(cmds,W,H,'page.rgba'); log.append('unpacked: %s; body %d bytes%s; page piece answered %d; %.1f s in all'%('yes' if packed==1 else 'no',ans[1],' -> %d'%ans[2] if packed==1 else '',ans[-1],time.time()-started))
subprocess.run(['python3',P+'tools/rgba_png.py',T+'page.rgba',str(W),str(H),sys.argv[2],'560'])
print('\n'.join(log))
