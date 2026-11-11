import sys,struct,subprocess,random
B='/data/user/0/t.t/files/work/trough-lab/pieces/out/'
def rd(p): d=open(p,'rb').read(); return list(struct.unpack('<%dh'%(len(d)//2),d))
def conv(s,rin,cin,rout,cout,vol):
    F=len(s)//cin; W=F*rout//rin; o=[]
    for i in range(W):
        k,r=divmod(i*rin,rout); k1=k+1 if k+1<F else k
        v=[(s[k*cin+c]*(rout-r)+s[k1*cin+c]*r+rout//2)//rout for c in range(cin)]
        if cin==1 and cout==2: v=[v[0],v[0]]
        elif cin==2 and cout==1: v=[(v[0]+v[1])//2]
        o+=[x*vol//256 for x in v]
    return o
random.seed(3); bad=0; n=0
for case in [(1764,2,1920,2,256),(1764,2,1920,2,90),(1920,2,1764,2,256),(1764,2,882,1,200),(441,2,1920,2,256),(1764,2,1764,1,256),(1764,2,1764,2,256),(7680,2,1,2,256),(320,2,7680,1,255)]+[(random.randint(1,7680),2,random.randint(1,7680),random.randint(1,2),random.randint(0,256)) for _ in range(12)]:
    r=subprocess.run([B+'soundbench',B+'sound.ref','convert','/tmp/flactest/clip.raw','/tmp/flactest/c.raw']+[str(x) for x in case],capture_output=True,text=True)
    got=rd('/tmp/flactest/c.raw'); want=conv(rd('/tmp/flactest/clip.raw'),*case); n+=1
    if got!=want: bad+=1; print('DIFF',case,len(got),len(want))
    elif n<=3: print('same',case,r.stdout.strip())
# mono source
for case in [(1920,1,1764,2,256),(640,1,1920,1,128)]:
    subprocess.run([B+'soundbench',B+'sound.ref','convert','/tmp/flactest/monoclip.raw','/tmp/flactest/c.raw']+[str(x) for x in case]); n+=1
    if rd('/tmp/flactest/c.raw')!=conv(rd('/tmp/flactest/monoclip.raw'),*case): bad+=1; print('DIFF',case)
base=rd('/tmp/flactest/clip.raw'); add=rd('/tmp/flactest/loud.raw')
for vol,start in [(256,0),(100,777),(256,40001),(0,5)]:
    subprocess.run([B+'soundbench',B+'sound.ref','mix','/tmp/flactest/clip.raw','/tmp/flactest/loud.raw','/tmp/flactest/c.raw',str(vol),str(start)],capture_output=True); want=base[:]; n+=1
    for i,x in enumerate(add):
        if start+i<len(want): want[start+i]=max(-32768,min(32767,want[start+i]+x*vol//256))
    if rd('/tmp/flactest/c.raw')!=want: bad+=1; print('DIFF mix',vol,start)
print(n,'cases',bad,'different')
# resample, modelled from the intent (kernel table read from the header text)
import re
K=[int(x) for x in re.findall(r'-?\d+',open(B+'../sound/kernel.h').read().split('{',1)[1])]
def resample(s,rin,cin,rout,cout,vol):
    F=len(s)//cin; W=F*rout//rin; wide=max(rin,rout); o=[]
    for i in range(W):
        pos=i*rin; acc=[0]*cin; wt=0
        for j in range((pos-8*wide)//rout+1,(pos+8*wide)//rout+1):
            at=abs(j*rout-pos)*256//wide
            if at>2048: continue
            k=min(max(j,0),F-1); wt+=K[at]
            for c in range(cin): acc[c]+=K[at]*s[k*cin+c]
        v=[max(-32768,min(32767,(a+wt//2)//wt)) if wt>0 else 0 for a in acc]
        if cin==1 and cout==2: v=[v[0],v[0]]
        elif cin==2 and cout==1: v=[(v[0]+v[1])//2]
        o+=[x*vol//256 for x in v]
    return o
open('/tmp/flactest/small.raw','wb').write(open('/tmp/flactest/clip.raw','rb').read()[:16000]); bad=0; n=0
for case in [(1764,2,1920,2,256),(1920,2,1764,2,256),(1764,2,882,1,200),(441,2,1920,2,256),(1764,2,1764,2,256),(7680,2,1,2,256),(320,2,7680,1,255),(1764,2,320,2,256)]+[(random.randint(1,7680),2,random.randint(1,7680),random.randint(1,2),random.randint(0,256)) for _ in range(10)]:
    subprocess.run([B+'soundbench',B+'sound.ref','resample','/tmp/flactest/small.raw','/tmp/flactest/c.raw']+[str(x) for x in case],capture_output=True)
    n+=1
    if rd('/tmp/flactest/c.raw')!=resample(rd('/tmp/flactest/small.raw'),*case): bad+=1; print('DIFF resample',case)
print('resample',n,'cases',bad,'different')
