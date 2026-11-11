import subprocess,random,sys
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey,X25519PublicKey
from cryptography.hazmat.primitives import serialization as S
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/ex/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/exchange.ref'; random.seed(77)
def batch(jobs):
    """jobs: (entry, secret, point or None) -> list of (answer, 32 bytes). One process, one output block per job."""
    cmd=''; 
    for i,(e,s,pt) in enumerate(jobs):
        open(T+'s%d'%i,'wb').write(s); cmd+='@file 20 %ss%d\n'%(T,i)
        if pt is not None: open(T+'p%d'%i,'wb').write(pt); cmd+='@file 21 %sp%d\n'%(T,i)
        cmd+='@surface %d 8 1\n@target %d\n%s%s %s 0 20%s\n'%(30+i,30+i,P,stem,e,' 21' if pt is not None else '')
    res=[]
    # the bench writes one block per run, so run once per job for the bytes but share the files
    for i,(e,s,pt) in enumerate(jobs):
        c='@file 20 %ss%d\n'%(T,i)+('@file 21 %sp%d\n'%(T,i) if pt is not None else '')+'@surface 30 8 1\n@target 30\n@output 30\n%s%s %s 0 20%s\n'%(P,stem,e,' 21' if pt is not None else '')
        r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=c.encode(),capture_output=True); res.append((int(r.stdout.decode().strip().split('->')[-1]),open(T+'o','rb').read()))
    return res
raw=lambda k:k.public_bytes(S.Encoding.Raw,S.PublicFormat.Raw)
jobs=[]; want=[]
for i in range(150):
    s=random.randbytes(32); o=random.randbytes(32)
    if i%10==0: s=bytes([random.choice([0,255])]*32)
    if i%7==0: o=o[:31]+bytes([o[31]|0x80])          # top bit set: must be ignored
    k=X25519PrivateKey.from_private_bytes(s); jobs.append(('public',s,None)); want.append(raw(k.public_key()))
    try: w=k.exchange(X25519PublicKey.from_public_bytes(o))
    except Exception: w=None
    jobs.append(('shared',s,o)); want.append(w)
got=batch(jobs); bad=0
for (e,s,pt),(a,b),w in zip(jobs,got,want):
    ok=(a==32 and b==w) if w is not None else (a==-1 and not any(b))
    if not ok: bad+=1; print('DIFF',e,a,b.hex()[:16],None if w is None else w.hex()[:16])
print(len(jobs),'calls,',bad,'wrong')
# RFC 7748 section 5.2 and 6.1, and the points that give zero for every secret
v=batch([('shared',bytes.fromhex('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4'),bytes.fromhex('e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c')),
         ('public',bytes.fromhex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a'),None),
         ('shared',bytes.fromhex('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a'),bytes.fromhex('de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f')),
         ('shared',random.randbytes(32),bytes(32)),('shared',random.randbytes(32),bytes([1])+bytes(31)),('shared',random.randbytes(32),bytes.fromhex('ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f')),
         ('shared',random.randbytes(32),bytes.fromhex('e0eb7a7c3b41b8ae1656e3faf19fc46ada098deb9c32b1fd866205165f49b800'))])
print('RFC 7748 vector ->',v[0][1].hex()=='c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552','| Alice public ->',v[1][1].hex()=='8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a','| shared ->',v[2][1].hex()=='4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742')
print('zero-giving points refused ->',[a for a,_ in v[3:]])
