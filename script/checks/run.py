#!/usr/bin/env python3
"""run.py <stem> [folder]: every small program in the folder (default: programs/ beside this file) through our engine and through
the reference engines on the bench (qjs, node); what each prints must be the same text. -v shows our output for one file."""
import sys,os,struct,subprocess,glob,re
P=os.path.dirname(os.path.abspath(__file__))+'/../../'; stem=os.path.abspath(sys.argv[1]); T='/tmp/scriptcheck/'; os.makedirs(T,exist_ok=True)
def ours(path):
    cmds='@file 20 %s\n@block 30 6 1200000\n@target 30\n@output 30\n%s begin 0\n%s load 0 20\n%s run 5f5e100\n'%(path,stem,stem,stem)
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'w'],input=cmds.encode(),capture_output=True); res=[l.split('->')[-1].strip() for l in r.stdout.decode().strip().split('\n') if '->' in l]
    d=open(T+'w','rb').read(); q=lambda at: struct.unpack('<Q',d[at-64:at-56])[0]
    out=d[q(144)-64:q(144)-64+q(152)].decode('utf8','replace'); err=''
    e=q(224)
    if e>>48==0xfffc: a=(e&0xffffffffffff)-64; n=struct.unpack('<Q',d[a:a+8])[0]; err=d[a+8:a+8+n].decode()+' (line %d, column %d)'%struct.unpack('<II',d[232-64:240-64])
    return out,err,res
def ref(cmd,path):
    r=subprocess.run(cmd+[path],capture_output=True,timeout=60); t=r.stdout.decode('utf8','replace')
    # node's console shows a negative zero as -0, which is its console's habit and not the language's text for it ("0")
    return re.sub(r'(?<![\w.+-])-0(?![\w.])','0',t) if cmd[0]=='node' else t
files=sorted(glob.glob((sys.argv[2] if len(sys.argv)>2 and sys.argv[2]!='-v' else os.path.dirname(os.path.abspath(__file__))+'/programs')+'/*.js')) if not (len(sys.argv)>2 and sys.argv[2].endswith('.js')) else [sys.argv[2]]
wrong=0; lines=0
for f in files:
    o,e,res=ours(f); n=ref(['node'],f); q=ref(['qjs'],f); lines+=n.count('\n')
    if '-v' in sys.argv: print(o,e,res)
    if o==n and n!=q: print('note %s: ours and node agree, this qjs differs'%os.path.basename(f))
    elif o!=n or n!=q:
        wrong+=1; ol,nl,ql=o.split('\n'),n.split('\n'),q.split('\n')
        k=next((i for i in range(max(len(ol),len(nl))) if (ol[i:i+1]!=nl[i:i+1])),-1)
        ow,nw=(ol[k:k+1] or [''])[0].split(' '),(nl[k:k+1] or [''])[0].split(' '); j=next((i for i in range(max(len(ow),len(nw))) if ow[i:i+1]!=nw[i:i+1]),0)
        print('%s line %d item %d: ours %s wanted %s%s %s'%(os.path.basename(f),k+1,j+1,' '.join(ow[j:j+1])[:40],' '.join(nw[j:j+1])[:40],'' if n==q else ' (references disagree)',e))
print('%d programs, %d lines of output, %d wrong'%(len(files),lines,wrong)); sys.exit(1 if wrong or not files else 0)
