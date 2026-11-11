import random,subprocess,struct,os,glob
random.seed(4); P='/data/user/0/t.t/files/work/trough-lab/pieces/'
def sh(args,inp=None): return subprocess.run(args,input=inp,capture_output=True)
def ppm(w,h,fn): return b'P6 %d %d 255\n'%(w,h)+bytes(v for y in range(h) for x in range(w) for v in fn(x,y))
PAL=[(random.randint(0,255),random.randint(0,255),random.randint(0,255)) for _ in range(200)]
def pic(w,h,colours,seed):
    r=random.Random(seed); cs=[PAL[r.randrange(len(PAL))] for _ in range(colours)]; cs[0]=(255,0,255)
    cx,cy=r.randrange(w),r.randrange(h); mode=r.randrange(3)
    def fn(x,y):
        if (x-cx)**2+(y-cy)**2<(min(w,h)//3+1)**2: return cs[0]
        return cs[1+((x//(2+mode))+(y//3)*(1+mode)+ (r.randrange(colours) if mode==2 else 0))%(colours-1)]
    return ppm(w,h,fn)
def gif(w,h,colours,seed,interlace=False,transparent=False):
    args=['pamtogif']+(['-interlace'] if interlace else [])+(['-transparent','=rgb:ff/00/ff'] if transparent else [])
    r=sh(args,pic(w,h,colours,seed)); assert r.stdout, r.stderr; return r.stdout
def pnm_parts(d):
    """header fields then the raw data after exactly one whitespace byte"""
    import re
    m=re.match(rb'(P[456])\s+(\d+)\s+(\d+)\s'+(rb'' if d[:2]==b'P4' else rb'+(\d+)\s'),d); return m.group(1),int(m.group(2)),int(m.group(3)),d[m.end():]
def rgba_of(path,image=None):
    """independent reading of one frame's own patch: giftopnm + its alpha"""
    a=sh(['giftopnm','--alphaout=al.pbm']+(['-image=%d'%image] if image else [])+[path]); kind,w,h,px=pnm_parts(a.stdout)
    if kind==b'P6': rgb=[px[i*3:i*3+3] for i in range(w*h)]
    elif kind==b'P5': rgb=[bytes([v])*3 for v in px[:w*h]]
    else: rb=(w+7)//8; rgb=[(b'\0\0\0' if (px[y*rb+x//8]>>(7-x%8))&1 else b'\xff\xff\xff') for y in range(h) for x in range(w)]
    _,aw,ah,bits=pnm_parts(open('al.pbm','rb').read()); rb=(w+7)//8; o=bytearray()
    for i in range(w*h):
        y,x=divmod(i,w); opaque=not ((bits[y*rb+x//8]>>(7-x%8))&1)
        o+= rgb[i]+b'\xff' if opaque else b'\0\0\0\0'
    return w,h,bytes(o)
def ours(path,frame,w,h,entry='decode'):
    cmd='@file 20 %s\n@block 21 5 4000000\n%sout/gif.ref %s 0 20 21 %d\n'%(path,P,entry,frame)
    r=sh([P+'out/render',P+'out',str(w),str(h),'o.rgba'],cmd.encode()); return r.stdout.decode().strip().split('\n')[-1],open('o.rgba','rb').read()
def ask(path,entry,*nums):
    cmd='@file 20 %s\n%sout/gif.ref %s 0 20 %s\n'%(path,P,entry,' '.join(map(str,nums)))
    return sh([P+'out/render',P+'out','4','4','o2.rgba'],cmd.encode()).stdout.decode().strip().split('\n')[-1]
bad=0; n=0
# stills
for (w,h) in [(1,1),(5,3),(33,17),(120,90),(257,130)]:
    for colours in (2,3,16,200):
        for il in (False,True):
            for tr in (False,True):
                open('s.gif','wb').write(gif(w,h,colours,n,il,tr)); ew,eh,want=rgba_of('s.gif'); ans,got=ours('s.gif',0,w,h); n+=1
                if got!=want: bad+=1; print('DIFF still',w,h,colours,il,tr,ans)
print('stills',n,'different',bad)
# animations: gifsicle assembles; gifsicle --unoptimize --explode gives every frame fully drawn, independently
ab=0; an=0; fr=0
for case in range(24):
    r=random.Random(100+case); W,H=r.choice([(40,30),(64,64),(97,53)]); k=r.randrange(2,7); args=['gifsicle','--logical-screen','%dx%d'%(W,H)]+(['--colors','256'] if 0 else [])
    for i in range(k):
        w,h=(W,H) if i==0 and r.random()<0.7 else (r.randrange(1,W+1),r.randrange(1,H+1)); x,y=r.randrange(0,W-w+1),r.randrange(0,H-h+1)
        open('f%d.gif'%i,'wb').write(gif(w,h,r.choice([2,5,30,120]),case*10+i,r.random()<0.3,r.random()<0.6))
        args+=['--disposal',r.choice(['none','asis','background','previous']),'--delay',str(r.randrange(0,300)),'--position','%d,%d'%(x,y)]+(['--interlace'] if r.random()<0.3 else ['--no-interlace'])+['f%d.gif'%i]
    a=sh(args); assert a.stdout,a.stderr; open('anim.gif','wb').write(a.stdout)
    for old in glob.glob('ex.gif.*'): os.remove(old)
    sh(['gifsicle','--explode','anim.gif','-o','ex.gif'])   # each frame as its own file, so the reader cannot carry settings from one frame to the next
    info=sh(['gifsicle','--info','anim.gif']).stdout.decode(); blocks=info.split('  + image #')[1:]
    import re
    delays=[int(round(float(l.split('delay')[1].split('s')[0])*100)) if 'delay' in l else 0 for l in blocks]
    an+=1; okay=ask('anim.gif','frames')=='frames -> %d'%k and ask('anim.gif','size')=='size -> %d'%(W*65536+H)
    canvas=bytearray(W*H*4); prev=None
    for i in range(k):
        b=blocks[i]; m=re.search(r'(\d+)x(\d+)(?: at (\d+),(\d+))?',b); fw,fh,fx,fy=int(m.group(1)),int(m.group(2)),int(m.group(3) or 0),int(m.group(4) or 0)
        disp='background' if 'disposal background' in b else 'previous' if 'disposal previous' in b else 'none'
        if prev:
            (px_,py_,pw_,ph_,pd,keep)=prev
            for yy in range(py_,py_+ph_):
                if pd=='background': canvas[(yy*W+px_)*4:(yy*W+px_+pw_)*4]=bytes(pw_*4)
                elif pd=='previous': canvas[(yy*W+px_)*4:(yy*W+px_+pw_)*4]=keep[(yy*W+px_)*4:(yy*W+px_+pw_)*4]
        keep=bytes(canvas); gw,gh,patch=rgba_of('ex.gif.%03d'%i); assert (gw,gh)==(fw,fh),(gw,gh,fw,fh)
        for yy in range(fh):
            for xx in range(fw):
                q=patch[(yy*fw+xx)*4:(yy*fw+xx)*4+4]
                if q[3]: canvas[((fy+yy)*W+fx+xx)*4:((fy+yy)*W+fx+xx)*4+4]=q
        prev=(fx,fy,fw,fh,disp,keep); ans,got=ours('anim.gif',i,W,H); fr+=1
        if got!=bytes(canvas) or ask('anim.gif','delay',i)!='delay -> %d'%delays[i]: okay=False; print('DIFF anim',case,'frame',i,ans,disp)
    if not okay: ab+=1
print('animations',an,'frames',fr,'animations with a difference',ab)
