"""Makes the trust piece's recorded-check fixtures: a made-up root and authorities (nobody has a real authority's key), one good
chain and one certificate for each way a chain can be wrong, plus handshake signatures by three kinds of key. Writes out/trust.piece.
The checks replay with the times recorded here, so they keep passing after these certificates expire."""
import time,datetime,glob,subprocess
from cryptography import x509
from cryptography.hazmat.primitives.asymmetric import ec,rsa,padding
from cryptography.hazmat.primitives import hashes, serialization as S
from cryptography.x509.oid import NameOID
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; O=P+'out/trust-'; der=lambda c:c.public_bytes(S.Encoding.DER); d=datetime.datetime.now(datetime.timezone.utc); N=lambda s:x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,s)])
def make(subject,issuer,pub,signer,ca=None,path=None,names=None,usage=None,days=(-1,9),serial=[10]):
    serial[0]+=1; b=x509.CertificateBuilder().subject_name(N(subject)).issuer_name(N(issuer)).public_key(pub).serial_number(serial[0]).not_valid_before(d+datetime.timedelta(days=days[0])).not_valid_after(d+datetime.timedelta(days=days[1]))
    if ca is not None: b=b.add_extension(x509.BasicConstraints(ca=ca,path_length=path if ca else None),True)
    if names: b=b.add_extension(x509.SubjectAlternativeName([x509.DNSName(x) for x in names]),False)
    if usage is not None: b=b.add_extension(x509.KeyUsage(digital_signature=usage=='sign',content_commitment=False,key_encipherment=False,data_encipherment=False,key_agreement=False,key_cert_sign=usage=='certs',crl_sign=False,encipher_only=False,decipher_only=False),True)
    return b.sign(signer,hashes.SHA384() if isinstance(signer,ec.EllipticCurvePrivateKey) and signer.curve.name=='secp384r1' else hashes.SHA256())
kr=rsa.generate_private_key(public_exponent=65537,key_size=2048); k1=ec.generate_private_key(ec.SECP384R1()); k2=ec.generate_private_key(ec.SECP256R1()); kl=ec.generate_private_key(ec.SECP256R1()); kq=rsa.generate_private_key(public_exponent=65537,key_size=2048)
root=make('Made Root','Made Root',kr.public_key(),kr,ca=True,days=(-1,5))   # shorter than the rest, so some recorded times find the root itself out of date
content=b' '*64+b'TLS 1.3, server CertificateVerify\0'+bytes(range(32))
f={'name':b'made.test',
 'roots':der(root)+b''.join(der(x509.load_pem_x509_certificate(open(p,'rb').read())) for p in sorted(glob.glob('/system/etc/security/cacerts/*'))[:3]),
 'leaf':der(make('site','Mid Two',kl.public_key(),k2,ca=False,names=['made.test','*.made.test'],usage='sign')),
 'mid2':der(make('Mid Two','Mid One',k2.public_key(),k1,ca=True,path=0)),
 'mid1':der(make('Mid One','Made Root',k1.public_key(),kr,ca=True,path=1,usage='certs')),
 'plain2':der(make('Mid Two','Mid One',k2.public_key(),k1,ca=False)),                       # the right key and name, but not marked as an authority
 'nosign2':der(make('Mid Two','Mid One',k2.public_key(),k1,ca=True,usage='sign')),          # an authority whose key may not sign certificates
 'old2':der(make('Mid Two','Mid One',k2.public_key(),k1,ca=True,days=(-9,-5))),             # an authority that expired (before any recorded time)
 'short1':der(make('Mid One','Made Root',k1.public_key(),kr,ca=True,path=0)),               # allows no authority beneath it, yet one is
 'forgedleaf':der(make('site','Mid Two',kl.public_key(),kl,names=['made.test'])),           # names Mid Two as issuer; signed by someone else (ECDSA)
 'rsaforged':der(make('site','Made Root',kq.public_key(),kq,names=['made.test'])),          # names the root as issuer; signed by someone else (RSA). Its own RSA key signs the handshake below.
 'content':content,'ecsig':kl.sign(content,ec.ECDSA(hashes.SHA256())),'p384sig':k1.sign(content,ec.ECDSA(hashes.SHA384())),'rsasig':kq.sign(content,padding.PSS(mgf=padding.MGF1(hashes.SHA256()),salt_length=32),hashes.SHA256())}
hs=[0,2,3,4,5,6,7,8,9,10,11,12,13,14,15]; H=dict(zip(f,hs)); assert len(f)==15
for nm,v in f.items(): open(O+nm+'.fixture','wb').write(v)
g=lambda *a:','.join(str(H[x]) if x in H else x for x in a); now=int(time.time())
open(P+'out/trust.piece','w').write("state 128\ntarget mask 8 8\n"+"".join("hold %d file trust-%s.fixture\n"%(h,nm) for nm,h in H.items())+"entry chain %d %d\nentry signed_handshake 0 0\n"%(now-3*86400,now+12*86400)+
 "numbers chain 3 5 pick:%s pick:%s pick:%s pick:%s pick:%s\n"%(g('name','name','name','name','name','name','content','1'),g('roots','roots','roots','roots','roots','roots','roots','name'),g('leaf','leaf','leaf','leaf','forgedleaf','rsaforged','mid2','1'),g('mid2','mid2','plain2','nosign2','old2','mid1','leaf','1'),g('mid1','mid1','mid1','mid1','short1','short1','mid2','1'))+
 "numbers signed_handshake 4 4 pick:%s pick:1027,1027,2052,2052,1283,1283,0,2053 pick:%s pick:%s\n"%(g('leaf','leaf','rsaforged','rsaforged','mid1','mid1','mid2','1'),g('content','content','content','content','content','content','name','1'),g('ecsig','ecsig','rsasig','rsasig','p384sig','p384sig','content','rsasig'))+"".join("needs %d\n"%k for k in (14,21,22,23,24,25,26,27,28)))
def run(cmds): return [int(l.split('->')[1]) for l in subprocess.run([P+'out/render',P+'out','1','1','/tmp/ct/o'],input=(''.join('@file %d %s%s.fixture\n'%(20+H[nm],O,nm) for nm in f)+cmds).encode(),capture_output=True).stdout.decode().strip().split('\n') if '->' in l]
c=lambda *names:'%sout/trust.ref chain %x %s\n'%(P,now,' '.join(str(20+H[x]) for x in names))
print('chains (want 1 -4 -4 -3 -4 -5 -5 -2 1):',run(c('name','roots','leaf','mid2','mid1')+c('name','roots','leaf','plain2','mid1')+c('name','roots','leaf','nosign2','mid1')+c('name','roots','leaf','old2','mid1')+c('name','roots','leaf','mid2','short1')+c('name','roots','forgedleaf','mid2','mid1')+c('name','roots','rsaforged')+c('content','roots','leaf','mid2','mid1')+c('name','roots','leaf','mid1','mid2')))
s=lambda cert,scheme,sig:'%sout/trust.ref signed_handshake 0 %d %d %d %d\n'%(P,20+H[cert],scheme,20+H['content'],20+H[sig])
print('handshake signatures (want 1 1 1, then none of them 1):',run(s('leaf',0x0403,'ecsig')+s('rsaforged',0x0804,'rsasig')+s('mid1',0x0503,'p384sig')+s('leaf',0x0403,'p384sig')+s('mid2',0x0403,'ecsig')+s('rsaforged',0x0804,'ecsig')+s('leaf',0x0503,'ecsig')+s('mid1',0x0403,'p384sig')))
