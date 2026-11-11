import subprocess,random,sys,hashlib
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature,Prehashed
from cryptography.hazmat.primitives import hashes
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/ec/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/ecdsa.ref'; random.seed(6)
N={256:0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551,384:0xffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf581a0db248b0a77aecec196accc52973}
def ask(jobs):
    cmd=''
    for i,(curve,x,y,r,s,d) in enumerate(jobs):
        for nm,v in (('x',x),('y',y),('r',r),('s',s),('d',d)): open(T+'%s%d'%(nm,i),'wb').write(v)
        cmd+=''.join('@file %d %s%s%d\n'%(20+j,T,nm,i) for j,nm in enumerate('xyrsd'))+'%s%s verify 0 %d 20 21 22 23 24\n'%(P,stem,curve)
    out=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True).stdout.decode()
    return [int(l.split('->')[1]) for l in out.strip().split('\n') if '->' in l]
B=lambda v,L:v.to_bytes(L,'big'); jobs=[]; want=[]; H={32:(hashes.SHA256(),hashlib.sha256),48:(hashes.SHA384(),hashlib.sha384),64:(hashes.SHA512(),hashlib.sha512)}
for bits,curve in ((256,ec.SECP256R1()),(384,ec.SECP384R1())):
    L=bits//8
    for t in range(40):
        key=ec.derive_private_key(random.randrange(1,N[bits]) if t>2 else [1,2,N[bits]-1][t],curve); pub=key.public_key().public_numbers(); msg=random.randbytes(random.randint(0,200)); dn=random.choice([32,48,64]) if t%3 else L
        dig=H[dn][1](msg).digest(); r,s=decode_dss_signature(key.sign(dig,ec.ECDSA(Prehashed(H[dn][0])))); x,y=B(pub.x,L),B(pub.y,L)
        jobs.append((bits,x,y,B(r,L),B(s,L),dig)); want.append(1)
        jobs.append((bits,b'\0'+x,y,B(r,L).lstrip(b'\0') or b'\0',b'\0'+B(s,L),dig)); want.append(1)             # leading zeros added or dropped, as certificates store them
        jobs.append((bits,x,y,B(r,L),B(N[bits]-s,L),dig)); want.append(1)                                        # the mirror signature is also valid
        jobs.append((bits,x,y,B(r,L),B(s,L),H[dn][1](msg+b'!').digest())); want.append(0)
        jobs.append((bits,x,y,B((r+1)%N[bits] or 1,L),B(s,L),dig)); want.append(0)
        jobs.append((bits,x,y,B(r,L),B(s^(1<<random.randrange(bits-2)),L),dig)); want.append(0)
        o=ec.derive_private_key(random.randrange(1,N[bits]),curve).public_key().public_numbers(); jobs.append((bits,B(o.x,L),B(o.y,L),B(r,L),B(s,L),dig)); want.append(0)   # someone else's key
        jobs.append((bits,x,B(pub.y^1,L),B(r,L),B(s,L),dig)); want.append(-1)                                     # not a point on the curve
        jobs.append((bits,x,y,B(0,L),B(s,L),dig)); want.append(0); jobs.append((bits,x,y,B(r,L),B(N[bits],L),dig)); want.append(0); jobs.append((bits,x,y,B(N[bits],L),B(s,L),dig)); want.append(0)
    jobs.append((bits+1,x,y,B(r,L),B(s,L),dig)); want.append(-1)
got=ask(jobs); bad=[(j[0],w,g) for j,w,g in zip(jobs,want,got) if w!=g]
print(len(got),'of',len(jobs),'answers;',len(bad),'wrong',bad[:6],'; valid accepted:',sum(1 for w,g in zip(want,got) if w==1 and g==1),'of',want.count(1))
