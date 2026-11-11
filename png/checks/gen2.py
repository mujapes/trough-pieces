import random,subprocess,struct,sys,os
random.seed(9); P='/data/user/0/t.t/files/work/trough-lab/pieces/'
def pnm(name,kind,w,h,maxv,ch,fn):
    b=bytearray()
    for y in range(h):
        for x in range(w):
            for c in range(ch):
                v=fn(x,y,c)%(maxv+1); b+= struct.pack('>H',v) if maxv>255 else bytes([v])
    open(name,'wb').write(b'%s %d %d %d\n'%(kind,w,h,maxv)+bytes(b))
def smooth(maxv): return lambda x,y,c:(x*7+y*13+c*50+random.randint(0,3))*maxv//400
def noisy(maxv): return lambda x,y,c:random.randint(0,maxv)
def few(x,y,c): return [(10,200,30),(250,250,0),(0,0,0),(90,90,200),(255,0,255)][(x//3+y//2)%5][c]
def pam_rgba(data):
    head,body=data.split(b'ENDHDR\n',1); f=dict(l.split(None,1) for l in head.decode().split('\n')[1:] if ' ' in l and not l.startswith('#'))
    w,h,d,mv=int(f['WIDTH']),int(f['HEIGHT']),int(f['DEPTH']),int(f['MAXVAL']); n=w*h*d
    v=struct.unpack('>%dH'%n,body[:2*n]) if mv>255 else body[:n]
    sc=(lambda x:x>>8) if mv==65535 else (lambda x:x*255//mv); o=bytearray()
    for i in range(w*h):
        t=[sc(x) for x in v[i*d:(i+1)*d]]
        o+=bytes(t if d==4 else [t[0],t[0],t[0],t[1]] if d==2 else t+[255] if d==3 else [t[0]]*3+[255])
    return w,h,bytes(o)
cases=[]
for (w,h) in [(5,3),(40,31)]:
    for il in ('','-interlace'):
        for c in [('trns',b'P6',255,3,few,il,'-force -transparent =rgb:fa/fa/00'),('gtrns',b'P5',255,1,lambda x,y,c:(x//2)*40,il,'-force -transparent =rgb:28/28/28'),('rgba16',b'P6',65535,3,smooth(65535),il,'alpha16'),('ga8',b'P5',255,1,smooth(255),il,'alpha'),('pal2',b'P5',3,1,noisy(3),il,'-palette pal.ppm')]: cases.append(c+((w,h),))
bad=0; n=0; kinds={}
for name,kind,maxv,ch,fn,il,extra,(w,h) in cases:
    pnm('s.pnm',kind,w,h,maxv,ch,fn); args=['pnmtopng']+([il] if il else [])
    if extra=='alpha': pnm('a.pgm',b'P5',w,h,255,1,noisy(255)); args+=['-alpha','a.pgm']
    elif extra=='alpha16': pnm('a.pgm',b'P5',w,h,65535,1,noisy(65535)); args+=['-alpha','a.pgm']
    elif extra: args+=extra.split()
    r=subprocess.run(args+['s.pnm'],capture_output=True)
    if r.returncode or not r.stdout: print('encode failed',name,extra,r.stderr[:80]); continue
    open('t.png','wb').write(r.stdout); ihdr=r.stdout[16:29]; key=(ihdr[9],ihdr[8],ihdr[12]); kinds[key]=kinds.get(key,0)+1
    ew,eh,want=pam_rgba(subprocess.run(['pngtopam','-alphapam','t.png'],capture_output=True).stdout)
    for v in ('ref','fast3'):
        cmd='@file 20 t.png\n@block 21 5 400000\n%sout/png.%s decode 0 20 21\n'%(P,v)
        o=subprocess.run([P+'out/render',P+'out',str(w),str(h),'o.rgba'],input=cmd.encode(),capture_output=True).stdout.decode().strip().split('\n')[-1]
        got=open('o.rgba','rb').read(); n+=1
        if got!=want: bad+=1; print('DIFF',v,name,il,extra,w,h,key,o, next((i for i in range(min(len(got),len(want))) if got[i]!=want[i]),None))
print(n,'decodes',bad,'different'); print('colour type, depth, interlace -> files:',sorted(kinds.items()))
