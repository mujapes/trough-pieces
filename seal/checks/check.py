import subprocess,random,sys
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/sl/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/seal.ref'; random.seed(12)
def call(entry,key,nonce,extra,body,room):
    for name,d in (('k',key),('n',nonce),('e',extra),('b',body)): open(T+name,'wb').write(d)
    w=max(1,(room+3)//4); cmd='@surface 30 %d 1\n@target 30\n@output 30\n@resize 30 %d\n@file 20 %sk\n@file 21 %sn\n@file 22 %se\n@file 23 %sb\n%s%s %s 0 20 21 22 23\n'%(w,room,T,T,T,T,P,stem,entry)
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True); ans=int(r.stdout.decode().strip().split('->')[-1]); return ans,open(T+'o','rb').read()
bad=0; n=0
lens=[0,1,15,16,17,31,32,33,63,64,65,127,128,129,255,256,1000,4096,16384]+[random.randint(0,3000) for _ in range(40)]
for ln in lens:
    key=random.randbytes(32); nonce=random.randbytes(12); extra=random.randbytes(random.choice([0,1,5,13,16,17,40])); msg=random.randbytes(ln); want=ChaCha20Poly1305(key).encrypt(nonce,msg,extra)
    a,got=call('seal',key,nonce,extra,msg,ln+16); n+=1
    if a!=ln+16 or got[:a]!=want: bad+=1; print('DIFF seal',ln,a)
    a,got=call('open',key,nonce,extra,want,ln+16); n+=1
    if a!=ln or got[:ln]!=msg: bad+=1; print('DIFF open',ln,a)
    t=bytearray(want); t[random.randrange(len(t))]^=1<<random.randrange(8); a,got=call('open',key,nonce,extra,bytes(t),ln+16); n+=1
    if a!=-1 or any(got): bad+=1; print('DIFF tampered accepted or wrote',ln,a)
    if extra:
        a,got=call('open',key,nonce,extra[:-1]+bytes([extra[-1]^1]),want,ln+16); n+=1
        if a!=-1: bad+=1; print('DIFF changed extra accepted',ln)
# refusals: wrong key or nonce size, too little room, sealed shorter than a tag
k=random.randbytes(32); no=random.randbytes(12); m=b'hello world'
for what,args in (('short key',(k[:31],no,b'',m,64)),('long nonce',(k,no+b'x',b'',m,64)),('no room',(k,no,b'',m,len(m)+15))):
    a,_=call('seal',*args); n+=1
    if a!=-1: bad+=1; print('DIFF not refused:',what,a)
a,_=call('open',k,no,b'',b'123456789012345',64); n+=1
if a!=-1: bad+=1; print('DIFF short sealed accepted')
# RFC 8439 section 2.8.2
key=bytes(range(0x80,0xa0)); nonce=bytes.fromhex('070000004041424344454647'); aad=bytes.fromhex('50515253c0c1c2c3c4c5c6c7'); pt=b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
a,got=call('seal',key,nonce,aad,pt,len(pt)+16); print('RFC 8439 tag ->',got[len(pt):a].hex()=='1ae10b594f09e26a7e902ecbd0600691', 'first bytes ->',got[:8].hex()=='d31a8d34648e60db')
print(n,'calls,',bad,'wrong')
