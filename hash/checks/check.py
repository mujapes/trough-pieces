import hashlib,hmac,subprocess,random,os
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; random.seed(8); T='/tmp/hs/'
import sys; stem=sys.argv[1] if len(sys.argv)>1 else 'out/hash.ref'
lens=list(range(0,200))+[255,256,257,1000,4095,4096,4097,65537,1000003]; files=[]
for i,n in enumerate(lens): d=random.randbytes(n); open(T+'m%d'%i,'wb').write(d); files.append(d)
def run(cmds):
    out=[]
    for c in cmds:
        r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=('@surface 30 8 1\n@target 30\n@output 30\n'+c).encode(),capture_output=True); out.append(open(T+'o','rb').read())
    return out
bad=0
for i,d in enumerate(files):
    got=run(['@file 20 %sm%d\n%s%s sha256 0 20\n'%(T,i,P,stem)])[0]
    if got!=hashlib.sha256(d).digest(): bad+=1; print('DIFF sha',len(d))
print(len(files),'sha256 inputs,',bad,'different'); bad=0; n=0
for ki in [0,1,20,32,63,64,65,100,131,203]:
    for mi in [0,1,50,55,56,64,119,150,201,204,206]:
        got=run(['@file 20 %sm%d\n@file 21 %sm%d\n%s%s hmac_sha256 0 20 21\n'%(T,ki,T,mi,P,stem)])[0]; n+=1
        if got!=hmac.new(files[ki],files[mi],hashlib.sha256).digest(): bad+=1; print('DIFF hmac',len(files[ki]),len(files[mi]))
print(n,'hmac cases,',bad,'different')
# published vectors
open(T+'abc','wb').write(b'abc'); print('abc ->',run(['@file 20 %sabc\n%s%s sha256 0 20\n'%(T,P,stem)])[0].hex()=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')
open(T+'k','wb').write(b'\x0b'*20); open(T+'d','wb').write(b'Hi There'); print('RFC 4231 case 1 ->',run(['@file 20 %sk\n@file 21 %sd\n%s%s hmac_sha256 0 20 21\n'%(T,T,P,stem)])[0].hex()=='b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7')
# key derivation: against the cryptography library's HKDF, and the worked example of RFC 8448
from cryptography.hazmat.primitives.kdf.hkdf import HKDFExpand
from cryptography.hazmat.primitives import hashes
def expand(secret,label,ctx,L):
    for nm,d in (('s',secret),('l',label),('c',ctx)): open(T+nm,'wb').write(d)
    w=(L+3)//4
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=('@surface 30 %d 1\n@target 30\n@output 30\n@file 20 %ss\n@file 21 %sl\n@file 22 %sc\n%s%s expand_label 0 20 21 22 %d\n'%(w,T,T,T,P,stem,L)).encode(),capture_output=True)
    return int(r.stdout.decode().strip().split('->')[-1]),open(T+'o','rb').read()[:L]
bad=0; n=0
for _ in range(120):
    secret=random.randbytes(random.choice([32,32,32,0,1,64,65,100])); label=random.randbytes(random.choice([0,1,3,7,12,249])); ctx=random.randbytes(random.choice([0,32,32,1,255])); L=random.choice([1,12,16,32,32,33,48,64,65,255])
    info=L.to_bytes(2,'big')+bytes([6+len(label)])+b'tls13 '+label+bytes([len(ctx)])+ctx; want=HKDFExpand(hashes.SHA256(),L,info).derive(secret); a,got=expand(secret,label,ctx,L); n+=1
    if a!=L or got!=want: bad+=1; print('DIFF expand',len(secret),len(label),len(ctx),L,a)
print(n,'expand_label cases,',bad,'different')
open(T+'z','wb').write(bytes(32)); early=run(['@file 20 %sz\n@file 21 %sz\n%s%s hmac_sha256 0 20 21\n'%(T,T,P,stem)])[0]
print('RFC 8448 early secret ->',early.hex()=='33ad0a1c607ec03b09e6cd9893680ce210adf300aa1f2660e1b22e10f170f92a')
a,d=expand(early,b'derived',hashlib.sha256(b'').digest(),32); print('RFC 8448 derived secret ->',d.hex()=='6f2615a108c702c5678f54fc9dbab69716c076189c48250cebeac3576c3611ba',d.hex()[:16])
# the longer hashes
bad=0
for i,d in enumerate(files):
    for entry,fn,w in (('sha384',hashlib.sha384,12),('sha512',hashlib.sha512,16)):
        r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=('@surface 30 %d 1\n@target 30\n@output 30\n@file 20 %sm%d\n%s%s %s 0 20\n'%(w,T,i,P,stem,entry)).encode(),capture_output=True)
        if open(T+'o','rb').read()!=fn(d).digest(): bad+=1; print('DIFF',entry,len(d))
print(2*len(files),'sha384 and sha512 answers,',bad,'different')
