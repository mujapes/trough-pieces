#!/usr/bin/env python3
"""check.py <stem>: the reload piece on streams made here: good records at several places, every cut of a record (must say "wait"),
and every single damaged byte of a small record (must refuse), plus what each part comes back as."""
import sys,os,struct,hashlib,subprocess,random
P=os.path.dirname(os.path.abspath(__file__))+'/../../'; stem=os.path.abspath(sys.argv[1]); T='/tmp/reloadcheck/'; os.makedirs(T,exist_ok=True)
def record(name,entries,code):
    body=b'TRPC'+struct.pack('<IIII',64+len(name)+len(entries)+len(code),len(name),len(entries),len(code))+bytes(12)+name+entries+code
    return body+hashlib.sha256(body).digest()
def call(stream,line,room=70000):
    open(T+'s','wb').write(stream); cmds='@file 20 %ss\n@block 30 2 %d\n@target 30\n@output 30\n%s %s\n'%(T,room,stem,line)
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmds.encode(),capture_output=True); a=int(r.stdout.decode().strip().split('->')[-1]); return a,(open(T+'o','rb').read()[:a] if a>=0 else b'')
random.seed(5); n=wrong=0
def expect(got,want,what):
    global n,wrong; n+=1
    if got!=want: wrong+=1; print(what,'->',got,'wanted',want)
a=record(b'peak',b'peak 0\n',bytes(random.randrange(256) for _ in range(108))); b=record(b'sound-measures',b'energy 0\nclimbs 64\n',bytes(random.randrange(256) for _ in range(280)))
s=a+b
expect(call(s,'record 0 20')[0],len(a),'first record'); expect(call(s,'record %x 20'%len(a))[0],len(b),'second record'); expect(call(s,'record %x 20'%len(s))[0],0,'nothing there yet'); expect(call(s,'record %x 20'%(len(s)+5))[0],0,'past the end')
expect(call(s,'part 0 20 0')[1],b'peak','name'); expect(call(s,'part 0 20 1')[1],b'peak 0\n','entries'); expect(call(s,'part 0 20 2')[1],a[32+4+7:-32],'code'); expect(call(s,'part %x 20 0'%len(a))[1],b'sound-measures','second name'); expect(call(s,'part 0 20 3')[0],-1,'no fourth part')
for cut in range(1,len(a)): expect(call(a[:cut],'record 0 20')[0],0 if a[:min(cut,4)]==b'TRPC'[:min(cut,4)] or cut<32 else -1,'cut at %d'%cut)
for i in range(len(a)):
    d=bytearray(a); d[i]^=1+random.randrange(255); got=call(bytes(d),'record 0 20')[0]
    # a damaged length may make the record look unfinished (wait) but never good
    expect(got in (-1,0) and not (got==0 and not 4<=i<20),True,'damaged byte %d gave %d'%(i,got)); expect(call(bytes(d),'part 0 20 2')[0],-1,'part of a damaged record, byte %d'%i)
for bad,why in ((record(b'Peak',b'e 0\n',bytes(8)),'capital in name'),(record(b'',b'e 0\n',bytes(8)),'no name'),(record(b'p',b'',bytes(8)),'no entries'),(record(b'p',b'e 0\n',bytes(6)),'half an instruction'),(record(b'p',b'e 0\n',b''),'no code'),(record(b'p'*41,b'e 0\n',bytes(8)),'long name')): expect(call(bad,'record 0 20')[0],-1,why)
expect(call(a,'record 0 20',room=len(a)-40)[0],-2,'working room too small')
print('%d calls, %d wrong'%(n,wrong)); sys.exit(1 if wrong else 0)
