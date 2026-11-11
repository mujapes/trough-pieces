"""Makes two forged sessions from the captured one, each sealed again under the session's own handshake key so that everything
decrypts and exactly one thing is wrong: out/tls-badproof.fixture (one bit of the server's proof, Finished) and
out/tls-badsig.fixture (one bit of the server's signature, CertificateVerify). A handshake that accepts either is broken.
The key is derived here independently of the piece, from the seed and the captured hello."""
import hashlib,hmac,struct
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey,X25519PublicKey
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305
from cryptography.hazmat.primitives import serialization as S
O='/data/user/0/t.t/files/work/trough-lab/pieces/out/tls-'; seed=open(O+'seed.fixture','rb').read(); srv=open(O+'server.fixture','rb').read(); name=open(O+'name.fixture','rb').read()
priv=X25519PrivateKey.from_private_bytes(seed[32:64]); pub=priv.public_key().public_bytes(S.Encoding.Raw,S.PublicFormat.Raw)
ext=b'\0\0'+struct.pack('>HHBH',len(name)+5,len(name)+3,0,len(name))+name+bytes([0,43,0,3,2,3,4, 0,10,0,4,0,2,0,29, 0,13,0,8,0,6,4,3,5,3,8,4, 0,51,0,38,0,36,0,29,0,32])+pub
body=b'\x03\x03'+seed[:32]+b'\x20'+seed[64:96]+b'\0\x04\x13\x03\x13\x01\x01\0'+struct.pack('>H',len(ext))+ext; ch=b'\x01'+struct.pack('>I',len(body))[1:]+body   # both ciphers offered; this session's server chose ChaCha20
recs=[]; at=0
while at+5<=len(srv): ln=struct.unpack('>H',srv[at+3:at+5])[0]; recs.append([srv[at],srv[at:at+5],srv[at+5:at+5+ln]]); at+=5+ln
sh=recs[0][2]; assert recs[0][0]==22 and sh[0]==2
i=4+2+32; i+=1+sh[i]; i+=3; end=i+2+struct.unpack('>H',sh[i:i+2])[0]; i+=2; theirs=None
while i<end:
    t,l=struct.unpack('>HH',sh[i:i+4]); i+=4
    if t==51: theirs=sh[i+4:i+36]
    i+=l
shared=priv.exchange(X25519PublicKey.from_public_bytes(theirs)); H=lambda d:hashlib.sha256(d).digest(); HM=lambda k,d:hmac.new(k,d,hashlib.sha256).digest()
def label(secret,lab,ctx,L): info=struct.pack('>H',L)+bytes([6+len(lab)])+b'tls13 '+lab+bytes([len(ctx)])+ctx; return HM(secret,info+b'\x01')[:L]
early=HM(bytes(32),bytes(32)); hs=HM(label(early,b'derived',H(b''),32),shared); s_hs=label(hs,b's hs traffic',H(ch+sh),32); key=label(s_hs,b'key',b'',32); iv=label(s_hs,b'iv',b'',12)
# open the handshake records, find the two messages in the stream they carry
plain=[]; seq=0; stream=b''; where=[]                                    # where[k] = (record index, offset in that record's plaintext) of stream byte k
for r,(kind,head,data) in enumerate(recs):
    if kind!=23: continue
    nonce=bytes(a^b for a,b in zip(iv,bytes(4)+struct.pack('>Q',seq)))
    try: p=bytearray(ChaCha20Poly1305(key).decrypt(nonce,data,head))
    except Exception: break                                               # the records after the proof are under other keys
    j=len(p)-1
    while p[j]==0: j-=1
    assert p[j]==22; plain.append((r,seq,p)); where+=[(len(plain)-1,k) for k in range(j)]; stream+=bytes(p[:j]); seq+=1
at=0; found={}
while at+4<=len(stream): t=stream[at]; l=int.from_bytes(stream[at+1:at+4],'big'); found[t]=(at,l); at+=4+l
assert 15 in found and 20 in found, found
def forge(out,stream_pos):
    b=bytearray(srv); pi,off=where[stream_pos]; r,sq,p=plain[pi]; q=bytearray(p); q[off]^=1; kind,head,data=recs[r]
    sealed=ChaCha20Poly1305(key).encrypt(bytes(a^b for a,b in zip(iv,bytes(4)+struct.pack('>Q',sq))),bytes(q),head)
    start=sum(5+len(x[2]) for x in recs[:r]); b[start+5:start+5+len(data)]=sealed; open(O+out+'.fixture','wb').write(bytes(b))
forge('badproof',found[20][0]+4+31); forge('badsig',found[15][0]+4+found[15][1]-1)
print('forged: proof and signature; handshake messages seen:',sorted(found),'in',len(plain),'records')
# A server that shows no certificate at all: its settings, then straight to a proof that is correct for that shorter conversation.
# Everything decrypts and the proof matches; nothing says who the server is. This must be refused when roots are given.
ee_at,ee_len=found[8]; ee=stream[ee_at:ee_at+4+ee_len]; fk=label(s_hs,b'finished',b'',32); fin=b'\x14\0\0\x20'+HM(fk,H(ch+sh+ee))
first=next(i for i,r in enumerate(recs) if r[0]==23); body=ee+fin+b'\x16'; head=b'\x17\x03\x03'+struct.pack('>H',len(body)+16)
anon=b''.join(h+d for k,h,d in recs[:first])+head+ChaCha20Poly1305(key).encrypt(bytes(a^b for a,b in zip(iv,bytes(12))),body,head)
open(O+'nocert.fixture','wb').write(anon); print('forged: a session with no certificate,',len(anon),'bytes')
