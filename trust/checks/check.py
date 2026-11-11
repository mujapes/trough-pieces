import subprocess,sys,glob,os,time,datetime
from cryptography import x509
from cryptography.x509.verification import PolicyBuilder,Store
from cryptography.hazmat.primitives import serialization as S
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/ct/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/trust.ref'
rootcerts=[x509.load_pem_x509_certificate(open(f,'rb').read()) for f in sorted(glob.glob('/system/etc/security/cacerts/*'))]; der=lambda c:c.public_bytes(S.Encoding.DER)
open(T+'roots.der','wb').write(b''.join(der(c) for c in rootcerts))   # (the recorded checks' own small root list, out/trust-roots.fixture, is made by fixtures.py and must not be touched here)
sites={}
for f in sorted(glob.glob(T+'site-*.pem')): h=os.path.basename(f)[5:].rsplit('-',1)[0]; sites.setdefault(h,[]).append(x509.load_pem_x509_certificate(open(f,'rb').read()))
def ours(name,chain,now,roots='roots.der'):
    open(T+'nm','wb').write(name.encode()); cmd='@file 20 %snm\n@file 21 %s%s\n'%(T,T,roots)
    for i,c in enumerate(chain): open(T+'ch%d'%i,'wb').write(c if isinstance(c,bytes) else der(c)); cmd+='@file %d %sch%d\n'%(22+i,T,i)
    cmd+='%s%s chain %x 20 21 %s\n'%(P,stem,now,' '.join(str(22+i) for i in range(len(chain))))
    return int(subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True).stdout.decode().strip().split('->')[-1])
def oracle(name,chain,now):
    try: PolicyBuilder().store(Store(rootcerts)).time(datetime.datetime.fromtimestamp(now,datetime.timezone.utc)).build_server_verifier(x509.DNSName(name)).verify(chain[0],chain[1:]); return 1
    except Exception as e: return 0
now=int(time.time()); bad=0; n=0; t0=time.time()
def case(what,name,chain,when,expect=None):
    global bad,n
    g=ours(name,chain,when); n+=1
    try: o=oracle(name,[c for c in chain],when) if not any(isinstance(c,bytes) for c in chain) else 0
    except Exception: o=0
    want=o if expect is None else expect
    if (g==1)!=(want==1): bad+=1; print('DIFF',what,name,'ours',g,'oracle',o)
    return g
names=list(sites)
for h,ch in sites.items():
    other=names[(names.index(h)+1)%len(names)]
    print('%-20s %d sent -> %2d | wrong name %2d | 5 years on %2d | 5 years back %2d | no helpers %2d | other site\'s helpers %2d | leaf altered %2d | reversed %2d'%(h,len(ch),
        case('good',h,ch,now),case('wrong name','evil.example',ch,now),case('future',h,ch,now+5*365*86400),case('past',h,ch,now-5*365*86400),case('leaf alone',h,ch[:1],now),
        case('wrong helpers',h,ch[:1]+sites[other][1:],now),case('altered',h,[der(ch[0])[:-9]+bytes([der(ch[0])[-9]^1])+der(ch[0])[-8:]]+ch[1:],now,0),case('reversed',h,ch[:1]+ch[1:][::-1],now)))
# a certificate nobody vouched for, an empty root list, and each root presented as a site
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from cryptography.x509.oid import NameOID
k=ec.generate_private_key(ec.SECP256R1()); nm=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'self.test')]); d=datetime.datetime.now(datetime.timezone.utc)
selfsigned=x509.CertificateBuilder().subject_name(nm).issuer_name(nm).public_key(k.public_key()).serial_number(7).not_valid_before(d-datetime.timedelta(days=1)).not_valid_after(d+datetime.timedelta(days=9)).add_extension(x509.SubjectAlternativeName([x509.DNSName('self.test')]),False).sign(k,hashes.SHA256())
print('self-signed stranger ->',case('self-signed','self.test',[selfsigned],now,0))
# a leaf signed by a non-authority: the example.com leaf's key cannot be used (we do not have it), so forge with our own pair: leaf2 "issued" by a certificate that is not allowed to sign
ca=x509.CertificateBuilder().subject_name(nm).issuer_name(nm).public_key(k.public_key()).serial_number(8).not_valid_before(d-datetime.timedelta(days=1)).not_valid_after(d+datetime.timedelta(days=9)).add_extension(x509.BasicConstraints(ca=False,path_length=None),True).sign(k,hashes.SHA256())
k2=ec.generate_private_key(ec.SECP256R1()); leaf2=x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'victim.test')])).issuer_name(nm).public_key(k2.public_key()).serial_number(9).not_valid_before(d-datetime.timedelta(days=1)).not_valid_after(d+datetime.timedelta(days=9)).add_extension(x509.SubjectAlternativeName([x509.DNSName('victim.test')]),False).sign(k,hashes.SHA256())
open(T+'oneroot.der','wb').write(der(ca)); g=ours('victim.test',[leaf2],now,'oneroot.der'); print('leaf signed directly by a trusted root (root list of one, made here) ->',g)
open(T+'noroots.der','wb').write(b''); print('empty root list ->',ours(names[0],sites[names[0]],now,'noroots.der'))
print(n,'cases compared with the independent verifier,',bad,'disagreements; %.1f s'%(time.time()-t0))
# permissions: made-up authorities under a made-up root (a root list of one), since nobody has a real authority's key
def make(subject,issuer_name,pub,signer,ca=None,path=None,names=None,usage=None,days=(-1,9)):
    b=x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,subject)])).issuer_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,issuer_name)])).public_key(pub).serial_number(abs(hash(subject))%10**9+1).not_valid_before(d+datetime.timedelta(days=days[0])).not_valid_after(d+datetime.timedelta(days=days[1]))
    if ca is not None: b=b.add_extension(x509.BasicConstraints(ca=ca,path_length=path if ca else None),True)
    if names: b=b.add_extension(x509.SubjectAlternativeName([x509.DNSName(x) for x in names]),False)
    if usage is not None: b=b.add_extension(x509.KeyUsage(digital_signature=usage=='sign',content_commitment=False,key_encipherment=usage=='encipher',data_encipherment=False,key_agreement=False,key_cert_sign=usage=='certs',crl_sign=False,encipher_only=False,decipher_only=False),True)
    return b.sign(signer,hashes.SHA256())
from cryptography.hazmat.primitives.asymmetric import rsa as RSA
kr=RSA.generate_private_key(public_exponent=65537,key_size=2048); k1=ec.generate_private_key(ec.SECP384R1()); k2=ec.generate_private_key(ec.SECP256R1()); kl=ec.generate_private_key(ec.SECP256R1())
root=make('Made Root','Made Root',kr.public_key(),kr,ca=True); open(T+'made.der','wb').write(der(root))
good1=make('Mid One','Made Root',k1.public_key(),kr,ca=True,path=1,usage='certs'); good2=make('Mid Two','Mid One',k2.public_key(),k1,ca=True,path=0); leaf=make('site','Mid Two',kl.public_key(),k2,ca=False,names=['made.test','*.made.test'],usage='sign')
tests=[('three-deep chain, RSA root, P-384 and P-256 authorities',[leaf,good2,good1],1),
 ('authority not marked as one',[make('site','Plain',kl.public_key(),k2,names=['made.test']),make('Plain','Made Root',k2.public_key(),kr,ca=False)],-4),
 ('authority with no marking at all',[make('site','Bare',kl.public_key(),k2,names=['made.test']),make('Bare','Made Root',k2.public_key(),kr)],-4),
 ('authority whose key may not sign certificates',[make('site','NoSign',kl.public_key(),k2,names=['made.test']),make('NoSign','Made Root',k2.public_key(),kr,ca=True,usage='sign')],-4),
 ('one authority too many under a limit of none',[make('site','Deep',kl.public_key(),k2,names=['made.test']),make('Deep','Short',k2.public_key(),k1,ca=True),make('Short','Made Root',k1.public_key(),kr,ca=True,path=0)],-4),
 ('expired authority',[make('site','Old',kl.public_key(),k2,names=['made.test']),make('Old','Made Root',k2.public_key(),kr,ca=True,days=(-9,-2))],-3),
 ('leaf not yet valid',[make('site','Mid Two',kl.public_key(),k2,names=['made.test'],days=(2,9)),good2,good1],-3),
 ('leaf whose key may not sign',[make('site','Mid Two',kl.public_key(),k2,names=['made.test'],usage='encipher'),good2,good1],-4),
 ('leaf signed by the wrong key',[make('site','Mid Two',kl.public_key(),kl,names=['made.test']),good2,good1],-5)]
wrong=0
for what,ch,want in tests:
    g=ours('made.test',ch,now,'made.der'); wrong+= g!=want; print('%-58s -> %2d%s'%(what,g,'' if g==want else '   EXPECTED %d'%want))
print('wildcard name ->',ours('www.made.test',[leaf,good2,good1],now,'made.der'),'| two labels under the wildcard ->',ours('a.b.made.test',[leaf,good2,good1],now,'made.der'))
print('permission cases wrong:',wrong)
import pickle; pickle.dump({'root':der(root),'leaf':der(leaf),'mid2':der(good2),'mid1':der(good1),'plainleaf':der(tests[1][1][0]),'plain':der(tests[1][1][1])},open(T+'made.pickle','wb'))
