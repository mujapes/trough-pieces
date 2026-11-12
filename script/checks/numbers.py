#!/usr/bin/env python3
"""numbers.py <stem>: the number printer against Python's (the same shortest-digits rule), laid out as the language lays numbers out."""
import sys,os,struct,subprocess,random,math
P=os.path.dirname(os.path.abspath(__file__))+'/../../'; stem=os.path.abspath(sys.argv[1]); T='/tmp/scriptcheck/'; os.makedirs(T,exist_ok=True)
def js(v):
    if v!=v: return 'NaN'
    if v in (float('inf'),float('-inf')): return 'Infinity' if v>0 else '-Infinity'
    if v==0: return '0'
    s='-' if v<0 else ''; v=abs(v); r=repr(v)
    if 'e' in r: m,e=r.split('e'); e=int(e)
    else: m,e=r,0
    if '.' in m: i,f=m.split('.')
    else: i,f=m,''
    digits=(i+f).lstrip('0'); n=len(i.lstrip('0'))+e if i.strip('0') else e-(len(f)-len(f.lstrip('0')))
    digits=digits.rstrip('0') or '0'; k=len(digits)
    if k<=n<=21: return s+digits+'0'*(n-k)
    if 0<n<=21: return s+digits[:n]+'.'+digits[n:]
    if -6<n<=0: return s+'0.'+'0'*(-n)+digits
    return s+digits[0]+('.'+digits[1:] if k>1 else '')+'e'+('+' if n-1>=0 else '-')+str(abs(n-1))
random.seed(11)
vals=[0.0,-0.0,1.0,-1.0,0.1,0.2,0.1+0.2,1/3,2/3,100.0,1e21,1e22,123456789012345680000.0,1.5e300,5e-324,2.2250738585072014e-308,1.7976931348623157e308,float('inf'),float('-inf'),float('nan'),0.000001,0.0000001,123.456,1e-7,9007199254740993.0,4.35,0.5,1e100,255.0,3.14159,-2.5e-5,1e20,123456789.0,0.1+0.7,4.9e-324*3,2**53,2**-1074*2**52]
vals+=[struct.unpack('<d',struct.pack('<Q',random.getrandbits(64)))[0] for _ in range(1500)]
vals+=[random.randint(-10**6,10**6)/random.choice([1,10,100,1000,7,3]) for _ in range(800)]
vals+=[float(random.randint(0,10**random.randint(1,22))) for _ in range(300)]
vals=[v for v in vals]
cmds='@block 30 6 1200000\n@target 30\n@output 30\n'+''.join('%s numtext %x\n'%(stem,struct.unpack('<Q',struct.pack('<d',v))[0]) for v in vals)
r=subprocess.run([P+'out/render',P+'out','1','1',T+'w'],input=cmds.encode(),capture_output=True); d=open(T+'w','rb').read()
# the output file is the block without its 64-byte head, so a place in the world is 64 less in the file
out_at,out_len=struct.unpack('<QQ',d[144-64:160-64]); got=d[out_at-64:out_at-64+out_len].decode().split('\n')[:-1]
wrong=0
for v,g in zip(vals,got):
    if g!=js(v):
        wrong+=1
        if wrong<=6: print(repr(v),'ours',g,'wanted',js(v))
print('%d numbers, %d printed, %d wrong'%(len(vals),len(got),wrong)); sys.exit(1 if wrong or len(got)!=len(vals) else 0)
