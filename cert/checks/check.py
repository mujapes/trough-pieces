import subprocess,sys,glob,os,calendar
from cryptography import x509
from cryptography.hazmat.primitives import serialization as S, hashes
from cryptography.hazmat.primitives.asymmetric import rsa,ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/ct/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/cert.ref'
def number(path,which):
    cmd='@file 20 %s\n'%path+''.join('%s%s number 0 20 %d\n'%(P,stem,w) for w in which)
    return [int(l.split('->')[1]) for l in subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True).stdout.decode().strip().split('\n') if '->' in l]
def take(path,which):
    cmd='@file 20 %s\n@surface 30 2000 1\n@target 30\n@output 30\n%s%s bytes 0 20 %d\n'%(path,P,stem,which)
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True); a=int(r.stdout.decode().strip().split('->')[-1]); return None if a<0 else open(T+'o','rb').read()[:a]
def covers(path,name):
    open(T+'name','wb').write(name.encode()); return int(subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=('@file 20 %s\n@file 21 %sname\n%s%s covers 0 20 21\n'%(path,T,P,stem)).encode(),capture_output=True).stdout.decode().strip().split('->')[-1])
SIG={'1.2.840.113549.1.1.11':1,'1.2.840.113549.1.1.12':2,'1.2.840.113549.1.1.13':3,'1.2.840.10045.4.3.2':4,'1.2.840.10045.4.3.3':5,'1.2.840.10045.4.3.4':6}
strip=lambda b:b.lstrip(b'\0') or b'\0'; I=lambda v:v.to_bytes((v.bit_length()+7)//8 or 1,'big')
files=sorted(glob.glob('/system/etc/security/cacerts/*'))+sorted(glob.glob(T+'site-*.pem')); bad=0; n=0; skipped=0; kinds={}
for f in files:
    c=x509.load_pem_x509_certificate(open(f,'rb').read()); der=c.public_bytes(S.Encoding.DER); open(T+'c.der','wb').write(der); n+=1; why=[]
    pk=c.public_key(); kk=1 if isinstance(pk,rsa.RSAPublicKey) else (2 if isinstance(pk,ec.EllipticCurvePublicKey) and pk.curve.name=='secp256r1' else 3 if isinstance(pk,ec.EllipticCurvePublicKey) and pk.curve.name=='secp384r1' else 0)
    sk=SIG.get(c.signature_algorithm_oid.dotted_string,0); kinds[(sk,kk)]=kinds.get((sk,kk),0)+1
    try: bc=c.extensions.get_extension_for_class(x509.BasicConstraints).value; ca,pl=int(bc.ca),(-1 if bc.path_length is None else bc.path_length)
    except x509.ExtensionNotFound: ca,pl=0,-1
    try:
        ku=c.extensions.get_extension_for_class(x509.KeyUsage).value; u=(ku.digital_signature<<7)|(ku.content_commitment<<6)|(ku.key_encipherment<<5)|(ku.data_encipherment<<4)|(ku.key_agreement<<3)|(ku.key_cert_sign<<2)|(ku.crl_sign<<1)
        if ku.key_agreement: u|=ku.encipher_only|(ku.decipher_only<<15)
    except x509.ExtensionNotFound: u=-1
    want=[sk,kk,ca,calendar.timegm(c.not_valid_before_utc.timetuple()),calendar.timegm(c.not_valid_after_utc.timetuple()),pl,u,None,c.version.value+1,int(c.issuer==c.subject)]
    got=number(T+'c.der',range(10))
    if len(got)!=10: bad+=1; print('UNREADABLE',os.path.basename(f),got[:2]); continue
    for i,(w,g) in enumerate(zip(want,got)):
        if w is not None and w!=g: why.append(('number',i,w,g))
    if take(T+'c.der',0)!=c.tbs_certificate_bytes: why.append('tbs')
    if take(T+'c.der',6)!=c.issuer.public_bytes(): why.append('issuer')
    if take(T+'c.der',7)!=c.subject.public_bytes(): why.append('subject')
    if kk==1:
        if strip(take(T+'c.der',4))!=I(pk.public_numbers().n) or strip(take(T+'c.der',5))!=I(pk.public_numbers().e): why.append('rsa key')
    elif kk:
        L=32 if kk==2 else 48
        if take(T+'c.der',4)!=pk.public_numbers().x.to_bytes(L,'big') or take(T+'c.der',5)!=pk.public_numbers().y.to_bytes(L,'big'): why.append('ec key')
    if sk in (1,2,3):
        if take(T+'c.der',1)!=c.signature: why.append('signature')
    elif sk:
        r,s=decode_dss_signature(c.signature)
        if strip(take(T+'c.der',2))!=I(r) or strip(take(T+'c.der',3))!=I(s): why.append('r,s')
    try: names=c.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName)
    except x509.ExtensionNotFound: names=[]
    for nm in names[:4]:
        probe=nm.replace('*','www') if nm.startswith('*.') else nm
        if covers(T+'c.der',probe.upper())!=1: why.append(('should cover',probe))
        if nm.startswith('*.') and covers(T+'c.der','a.b.'+nm[2:])!=0: why.append(('wildcard covers two labels',nm))
        if nm.startswith('*.') and nm[2:] not in names and '*.'+nm[2:].split('.',1)[1] not in names and covers(T+'c.der',nm[2:])!=0: why.append(('wildcard covers bare domain',nm))
    if covers(T+'c.der','not-this-site.invalid')!=0: why.append('covers a stranger')
    if why: bad+=1; print('DIFF',os.path.basename(f),why[:3])
print(n,'certificates,',bad,'with a difference; (signature kind, key kind) -> count:',sorted(kinds.items()))
