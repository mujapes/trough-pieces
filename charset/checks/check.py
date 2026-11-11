import subprocess,random,sys,codecs
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/cs/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/charset.ref'; random.seed(4)
def run(jobs):
    out=[]
    for k in range(0,len(jobs),1):
        data,which=jobs[k]; open(T+'in','wb').write(data); room=len(data)*4+8
        r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=('@surface 30 %d 1\n@target 30\n@output 30\n@file 20 %sin\n%s%s to_utf8 0 20 %d\n'%((room+3)//4,T,P,stem,which)).encode(),capture_output=True)
        a=int(r.stdout.decode().strip().split('->')[-1]); out.append(None if a<0 else open(T+'o','rb').read()[:a])
    return out
def cp1252(b): return ''.join(chr(x) if x<128 else (bytes([x]).decode('cp1252') if x not in (0x81,0x8d,0x8f,0x90,0x9d) else chr(x)) for x in b)
jobs=[]; want=[]
jobs.append((bytes(range(256)),2)); want.append(cp1252(bytes(range(256))).encode())
alphabet=['a','é','€','日','😀',' ','Z','ß','﻿',' ']
for _ in range(400):
    s=''.join(random.choice(alphabet) for _ in range(random.randint(0,30))); b=bytearray(s.encode()); 
    for _ in range(random.choice([0,0,1,2,5])):
        if b: 
            i=random.randrange(len(b)); k=random.random()
            if k<0.4: b[i]=random.randrange(256)
            elif k<0.7: del b[i]
            else: b.insert(i,random.choice([0xc0,0xc1,0xf5,0xff,0x80,0xbf,0xed,0xa0,0xe0,0xf0,0xf4,0x90]))
    b=bytes(b); jobs.append((b,1)); w=b[3:] if b[:3]==b'\xef\xbb\xbf' else b; want.append(w.decode('utf-8','replace').encode())
for _ in range(200):
    b=random.randbytes(random.randint(0,40)); jobs.append((b,1)); w=b[3:] if b[:3]==b'\xef\xbb\xbf' else b; want.append(w.decode('utf-8','replace').encode())
for _ in range(200):
    b=random.randbytes(random.randint(0,60)); jobs.append((b,2)); want.append(cp1252(b).encode())
for big in (0,1):
    for _ in range(200):
        s=''.join(random.choice(alphabet) for _ in range(random.randint(0,20))); b=bytearray(s.encode('utf-16-be' if big else 'utf-16-le'))
        if random.random()<0.5 and b:
            i=random.randrange(len(b)); b[i]=random.choice([0xd8,0xdc,0xdf,0x00,random.randrange(256)])
        if random.random()<0.2: b=b[:-1]
        b=bytes(b); bom=b'\xfe\xff' if big else b'\xff\xfe'; w=b[2:] if b[:2]==bom else b; jobs.append((b,4 if big else 3)); want.append(w.decode('utf-16-be' if big else 'utf-16-le','replace').encode())
got=run(jobs); bad=[(j[1],j[0].hex(),w,g) for j,w,g in zip(jobs,want,got) if w!=g]; kinds={}
for k,*_ in bad: kinds[k]=kinds.get(k,0)+1
print(len(jobs),'conversions,',len(bad),'different',kinds); [print('  ',b[0],b[1][:60],b[2][:40],b[3][:40] if b[3] else None) for b in bad[:5]]
labels={'utf-8':1,' UTF8 ':1,'ISO-8859-1':2,'latin1':2,'windows-1252':2,'"us-ascii"':2,'utf-16':3,'UTF-16BE':4,'koi8-r':0,'':0,'utf-8;':1}
cmd=''
for i,l in enumerate(labels): open(T+'l%d'%i,'w').write(l); cmd+='@file 20 %sl%d\n%s%s named 0 20\n'%(T,i,P,stem)
ans=[int(x.split('->')[1]) for x in subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True).stdout.decode().strip().split('\n') if '->' in x]
print('labels wrong:',[(l,w,a) for (l,w),a in zip(labels.items(),ans) if (w if l else -1)!=a and not (l=='' and a in (0,-1))])
