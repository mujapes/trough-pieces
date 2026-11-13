#!/usr/bin/env python3
"""mkapk.py OUT.apk libflow.so [by Opus]: the new Trough's APK without Android build tools: our own binary manifest,
the zip, and an APK Signature Scheme v2 signature (RSA 2048, SHA-256) with a key kept at ~/.trough/flow-key.pem."""
import sys,os,struct,zipfile,io,hashlib,datetime
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import rsa,padding
from cryptography import x509
from cryptography.x509.oid import NameOID
A='http://schemas.android.com/apk/res/android'
# ---- binary XML (manifest) ----
def axml(tree):
    strings=[];ids=[]
    def S(s):
        if s not in strings: strings.append(s)
        return strings.index(s)
    # attribute names with resource ids first, in order (the resource map lines up with the first strings)
    def walk(n):
        for (ns,name,rid,v) in n[1]:
            if rid and name not in strings: strings.append(name); ids.append(rid)
        for c in n[2]: walk(c)
    walk(tree); S(A); S('android')
    body=b''
    def attr(ns,name,rid,v):
        nsi=S(A) if ns else 0xffffffff; ni=S(name)
        if isinstance(v,bool): raw=0xffffffff; typ=0x12; data=0xffffffff if v else 0
        elif isinstance(v,int): raw=0xffffffff; typ=0x01 if name=='theme' else 0x11 if name=='configChanges' else 0x10; data=v
        else: raw=S(v); typ=0x03; data=S(v)
        return struct.pack('<IIIHBBI',nsi,ni,raw,8,0,typ,data)
    def node(n):
        nonlocal body
        name,attrs,kids=n
        a=b''.join(attr(*x) for x in attrs)
        body+=struct.pack('<HHIII',0x0102,16,36+len(a),1,0xffffffff)+struct.pack('<IIHHHHHH',0xffffffff,S(name),20,20,len(attrs),0,0,0)+a
        for k in kids: node(k)
        body+=struct.pack('<HHIII',0x0103,16,24,1,0xffffffff)+struct.pack('<II',0xffffffff,S(name))
    for n in [tree]: pass
    # collect all strings first by a dry run
    node(tree); body=b''
    ns_start=struct.pack('<HHIIIII',0x0100,16,24,1,0xffffffff,S('android'),S(A)); node(tree)
    ns_end=struct.pack('<HHIIIII',0x0101,16,24,1,0xffffffff,S('android'),S(A))
    enc=[]; off=[]; pos=0
    for s in strings:
        u=s.encode('utf-16-le'); e=struct.pack('<H',len(s))+u+b'\0\0'; off.append(pos); pos+=len(e); enc.append(e)
    data=b''.join(enc); data+=b'\0'*((-len(data))%4)
    hdr=28+4*len(strings); pool=struct.pack('<HHIIIIII',0x0001,28,hdr+len(data),len(strings),0,0,hdr,0)+b''.join(struct.pack('<I',o) for o in off)+data
    rmap=struct.pack('<HHI',0x0180,8,8+4*len(ids))+b''.join(struct.pack('<I',i) for i in ids)
    x=pool+rmap+ns_start+body+ns_end
    return struct.pack('<HHI',0x0003,8,8+len(x))+x
man=('manifest',[(0,'package',0,'t.flow'),(1,'versionCode',0x0101021b,int(os.environ.get('FLOW_VERSION','1'))),(1,'versionName',0x0101021c,'flow-'+os.environ.get('FLOW_VERSION','1'))],[
  ('uses-sdk',[(1,'minSdkVersion',0x0101020c,29),(1,'targetSdkVersion',0x01010270,33)],[]),
  ('application',[(1,'label',0x01010001,'Flow'),(1,'hasCode',0x0101000c,False),(1,'extractNativeLibs',0x010104ea,True)],[
    ('activity',[(1,'name',0x01010003,'android.app.NativeActivity'),(1,'exported',0x01010010,True),(1,'configChanges',0x0101001f,0x40003fff),(1,'theme',0x01010000,0x0103000a)],[
      ('meta-data',[(1,'name',0x01010003,'android.app.lib_name'),(1,'value',0x01010024,'flow')],[]),
      ('intent-filter',[],[('action',[(1,'name',0x01010003,'android.intent.action.MAIN')],[]),('category',[(1,'name',0x01010003,'android.intent.category.LAUNCHER')],[])])])])])
# theme is a reference, not an int: patched below
def fix_theme(b):
    return b
mx=axml(man)
# ---- zip ----
z=io.BytesIO(); zf=zipfile.ZipFile(z,'w')
def put(name,data,comp):
    i=zipfile.ZipInfo(name,(2008,1,1,0,0,0)); i.compress_type=comp; zf.writestr(i,data)
put('AndroidManifest.xml',mx,zipfile.ZIP_DEFLATED); put('lib/arm64-v8a/libflow.so',open(sys.argv[2],'rb').read(),zipfile.ZIP_DEFLATED); zf.close()
apk=z.getvalue()
eocd=apk.rfind(b'PK\x05\x06'); cd_off=struct.unpack_from('<I',apk,eocd+16)[0]
entries,cd,eo=apk[:cd_off],apk[cd_off:eocd],apk[eocd:]
# ---- key ----
kp=os.path.expanduser('~/.trough/flow-key.pem')
if not os.path.exists(kp):
    k=rsa.generate_private_key(public_exponent=65537,key_size=2048); open(kp,'wb').write(k.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())); os.chmod(kp,0o600)
key=serialization.load_pem_private_key(open(kp,'rb').read(),None)
nm=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'Trough Flow')])
cert=x509.CertificateBuilder().subject_name(nm).issuer_name(nm).public_key(key.public_key()).serial_number(1).not_valid_before(datetime.datetime(2026,1,1)).not_valid_after(datetime.datetime(2056,1,1)).sign(key,hashes.SHA256()).public_bytes(serialization.Encoding.DER)
# ---- v2 ----
def lp(b): return struct.pack('<I',len(b))+b
def chunks(b):
    return [b[i:i+1048576] for i in range(0,len(b),1048576)]
cs=[]
for sec in (entries,cd,eo):
    for c in chunks(sec): cs.append(hashlib.sha256(b'\xa5'+struct.pack('<I',len(c))+c).digest())
top=hashlib.sha256(b'\x5a'+struct.pack('<I',len(cs))+b''.join(cs)).digest()
signed=lp(lp(struct.pack('<I',0x0103)+lp(top)))+lp(lp(cert))+lp(b'')
sig=key.sign(signed,padding.PKCS1v15(),hashes.SHA256())
pub=key.public_key().public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)
signer=lp(signed)+lp(lp(struct.pack('<I',0x0103)+lp(sig)))+lp(pub)
val=lp(lp(signer))
pair=struct.pack('<Q',4+len(val))+struct.pack('<I',0x7109871a)+val
size=len(pair)+8+16
block=struct.pack('<Q',size)+pair+struct.pack('<Q',size)+b'APK Sig Block 42'
eo2=bytearray(eo); struct.pack_into('<I',eo2,16,cd_off+len(block))
open(sys.argv[1],'wb').write(entries+block+cd+bytes(eo2)); print('apk',len(entries)+len(block)+len(cd)+len(eo2),'bytes')
