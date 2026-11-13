"""Print the instructions our engine translated a program into: python3 -I dis.py ENGINE file.js [from [to]].
Opcode names and operand sizes are read from the .S sources (the '+ N bits' notes), so the listing follows the engine."""
import sys,os,re,struct,subprocess
H=os.path.dirname(os.path.abspath(__file__)); S=H+'/..'; P=S+'/../'
names={};bits={}
src=''.join(open(f).read() for f in [S+'/'+n for n in os.listdir(S) if n.endswith('.S')])
for m in re.finditer(r'\.equ OP_(\w+), (\d+)([^\n]*)',src):
    n=int(m.group(2)); names[n]=m.group(1); b=re.findall(r'\+ (\d+) bits',m.group(3)); bits[n]=sum(map(int,b)) if b else None
def handler_bytes(nm):
    m=re.search(r'\ni_%s:(.*?)(?=\ni_\w+:|\Z)'%nm.lower(),src,re.S)
    if not m: return None
    c=re.match(r'[^\n]*?\+ (\d+) bits',m.group(1))
    if c: return int(c.group(1))
    t=0
    for line in m.group(1).split('\n'):
        line=line.split('//')[0]
        if '.macro' in line or 'RESULT' in line: break
        if re.search(r'\bFAR\b',line): t+=4
        if re.match(r'\s*U16\b',line): t+=2
        if re.match(r'\s*U8\b',line): t+=1
        r=re.search(r'\[x21\], #(\d+)',line)
        if r: t+=int(r.group(1))
        if re.match(r'\s*(b|b\.\w+|cbz|cbnz|tbz|tbnz|ret|NEXT)\b',line): break
    return t*8
for n,nm in names.items():
    h=handler_bytes(nm)
    if bits[n] is None: bits[n]=h or 0
stem=os.path.abspath(sys.argv[1]); T='/tmp/scriptdis/'; os.makedirs(T,exist_ok=True)
def code_of(path):
    cmds='@file 20 %s\n@block 30 6 1200000\n@target 30\n@output 30\n%s begin 0\n%s load 0 20\n'%(os.path.abspath(path),stem,stem)
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'w'],input=cmds.encode(),capture_output=True)
    d=open(T+'w','rb').read(); q=lambda at: struct.unpack('<Q',d[at-64:at-56])[0]
    return d[q(72)-64:q(72)-64+q(80)]
open(T+'empty.js','w').write('')
code=code_of(sys.argv[2]); lo=int(sys.argv[3]) if len(sys.argv)>3 else 0; hi=int(sys.argv[4]) if len(sys.argv)>4 else len(code)
i=0
while i<len(code):
    op=code[i]; b=bits.get(op,0)//8; arg=int.from_bytes(code[i+1:i+1+b],'little',signed=(names.get(op,'') in ('JMP','JF','JT','FORNEXT') or b==4)) if b else None
    if lo<=i<hi: print('%6d %-10s %s'%(i,names.get(op,'?%d'%op),'' if arg is None else (arg if not (names.get(op,'').startswith('J') or names.get(op,'')=='FORNEXT') else '%d -> %d'%(arg,i+1+arg))))
    i+=1+b
