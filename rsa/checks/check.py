import subprocess,random,sys,hashlib
from cryptography.hazmat.primitives.asymmetric import rsa,padding
from cryptography.hazmat.primitives import hashes
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/rs/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/rsa.ref'; random.seed(3)
def ask(jobs):
    cmd=''
    for i,(entry,n,e,sig,dig) in enumerate(jobs):
        for nm,d in (('n',n),('e',e),('s',sig),('d',dig)): open(T+'%s%d'%(nm,i),'wb').write(d)
        cmd+='@file 20 %sn%d\n@file 21 %se%d\n@file 22 %ss%d\n@file 23 %sd%d\n%s%s %s 0 20 21 22 23\n'%(T,i,T,i,T,i,T,i,P,stem,entry)
    out=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True).stdout.decode()
    return [int(l.split('->')[1]) for l in out.strip().split('\n') if '->' in l]
jobs=[]; want=[]; H={32:hashes.SHA256(),48:hashes.SHA384(),64:hashes.SHA512()}; hl={32:hashlib.sha256,48:hashlib.sha384,64:hashlib.sha512}
for bits,e in [(1024,65537),(2048,65537),(2048,3),(3072,65537),(4096,65537),(2049,65537),(1032,65537),(2047,65537)]:
    key=rsa.generate_private_key(public_exponent=e,key_size=bits); pub=key.public_key().public_numbers(); nb=pub.n.to_bytes((pub.n.bit_length()+7)//8,'big'); eb=pub.e.to_bytes((pub.e.bit_length()+7)//8,'big')
    for trial in range(4):
        msg=random.randbytes(random.randint(0,300))
        for dn in (32,48,64):
            sig=key.sign(msg,padding.PKCS1v15(),H[dn]); dig=hl[dn](msg).digest(); jobs.append(('verify_pkcs1',nb,eb,sig,dig)); want.append(1)
            bad=bytearray(sig); bad[random.randrange(len(bad))]^=1<<random.randrange(8); jobs.append(('verify_pkcs1',nb,eb,bytes(bad),dig)); want.append(None)   # 0, or -1 if it is no longer below the modulus
            jobs.append(('verify_pkcs1',nb,eb,sig,hl[dn](msg+b'x').digest())); want.append(0)
        sig=key.sign(msg,padding.PSS(mgf=padding.MGF1(hashes.SHA256()),salt_length=32),hashes.SHA256()); dig=hashlib.sha256(msg).digest(); jobs.append(('verify_pss',nb,eb,sig,dig)); want.append(1)
        bad=bytearray(sig); bad[random.randrange(len(bad))]^=1<<random.randrange(8); jobs.append(('verify_pss',nb,eb,bytes(bad),dig)); want.append(None)
        jobs.append(('verify_pss',nb,eb,sig,hashlib.sha256(msg+b'x').digest())); want.append(0)
        jobs.append(('verify_pkcs1',nb,eb,sig,dig)); want.append(0)            # a PSS signature is not a PKCS1 one
        jobs.append(('verify_pkcs1',b'\0'+nb,eb,key.sign(msg,padding.PKCS1v15(),hashes.SHA256()),dig)); want.append(1)   # a leading zero on the modulus, as certificates store it
got=ask(jobs); bad=0
for (j,w,g) in zip(jobs,want,got):
    if (w is None and g not in (0,-1)) or (w is not None and g!=w): bad+=1; print('DIFF',j[0],len(j[1])*8,w,g)
print(len(got),'of',len(jobs),'answers;',bad,'wrong; valid accepted:',sum(1 for w,g in zip(want,got) if w==1 and g==1),'of',want.count(1))
