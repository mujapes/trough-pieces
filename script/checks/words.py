#!/usr/bin/env python3
"""words.py <stem>: stage 1 against a separate statement of the same rules, on scripts full of the awkward cases; numbers are also
compared with what Python reads the same literal as."""
import sys,os,re,struct,subprocess
P=os.path.dirname(os.path.abspath(__file__))+'/../../'; stem=os.path.abspath(sys.argv[1]); T='/tmp/scriptcheck/'; os.makedirs(T,exist_ok=True)
L=open(P+'script/words.txt').read().split('\n'); KW=L[1].split(); PU=L[3].split()
def ours(src):
    open(T+'s','wb').write(src); cmds='@file 20 %ss\n@block 30 2 %d\n@target 30\n@output 30\n%s tokens 0 20\n'%(T,24*len(src)+400,stem)
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmds.encode(),capture_output=True); a=int(r.stdout.decode().strip().split('->')[-1]); d=open(T+'o','rb').read()[:max(a,0)]
    return [struct.unpack('<BBHIIId',d[i:i+24])[:5]+(struct.unpack('<d',d[i+16:i+24])[0],) for i in range(0,len(d),24)]
name=lambda c: c>=0x80 or chr(c).isalnum() or c in b'$_'
def theirs(s):
    out=[]; i=0; n=len(s); rx=True
    while True:
        nl=0
        while i<n:
            c=s[i]
            if c in b' \t\x0b\x0c': i+=1
            elif c in b'\n\r': i+=1; nl=1
            elif s[i:i+2]==b'\xc2\xa0': i+=2
            elif s[i:i+3] in (b'\xe2\x80\xa8',b'\xe2\x80\xa9'): i+=3; nl=1
            elif s[i:i+2]==b'//':
                while i<n and s[i] not in b'\n\r': i+=1
            elif s[i:i+2]==b'/*':
                j=s.find(b'*/',i+2)
                if j<0:
                    if b'\n' in s[i:]: nl=1
                    i=n
                else:
                    if b'\n' in s[i:j]: nl=1
                    i=j+2
            else: break
        if i>=n: out.append((0,nl,0,i,0,0.0)); return out
        st=i; c=s[i]
        if name(c) and not chr(c).isdigit():
            while i<n and name(s[i]): i+=1
            w=s[st:i].decode('latin1')
            if w in KW: k=KW.index(w); out.append((2,nl,k,st,i-st,0.0)); rx=not (KW[k] in ('this','super') or k>=40)
            else: out.append((1,nl,0,st,i-st,0.0)); rx=False
            continue
        if chr(c).isdigit() or (c==ord('.') and i+1<n and chr(s[i+1]).isdigit()):
            m=re.match(rb'0[xX][0-9a-fA-F_]+|0[oO][0-7_]+|0[bB][01_]+',s[i:])
            if m: v=float(int(m.group(0).replace(b'_',b'').decode(),0)); i+=len(m.group(0))
            else:
                m=re.match(rb'(?:[0-9_]*\.?[0-9_]*)(?:[eE][+-]?[0-9]+)?',s[i:]); t=m.group(0)
                # a second point ends the number
                m2=re.match(rb'[0-9_]*(?:\.[0-9_]*)?(?:[eE][+-]?[0-9]+)?',s[i:]); t=m2.group(0); v=float(t.replace(b'_',b'').decode() if t.replace(b'_',b'') not in (b'.',) else '0'); i+=len(t)
            kind=3
            if i<n and s[i]==ord('n'): i+=1; kind=8
            elif i<n and name(s[i]): i+=1; out.append((9,nl,0,st,i-st,0.0)); rx=True; continue
            out.append((kind,nl,0,st,i-st,v if kind==3 else 0.0)); rx=False; continue
        if c in b'"\'':
            i+=1; bad=False
            while True:
                if i>=n: bad=True; break
                d=s[i]; i+=1
                if d==c: break
                if d in b'\n\r': bad=True; break
                if d==ord('\\'):
                    if i>=n: bad=True; break
                    e=s[i]; i+=1
                    if e==13 and i<n and s[i]==10: i+=1
            out.append((9 if bad else 4,nl,0,st,i-st,0.0)); rx=bad; continue
        if c==ord('`'):
            i+=1; depth=0; q=0; bad=False
            while True:
                if i>=n: bad=True; break
                d=s[i]; i+=1
                if d==ord('\\'): i+=1; continue
                if q:
                    if d==q: q=0
                    continue
                if depth:
                    if d in b'"\'': q=d
                    elif d==ord('{'): depth+=1
                    elif d==ord('}'): depth-=1
                    continue
                if d==ord('`'): break
                if d==ord('$') and i<n and s[i]==ord('{'): i+=1; depth=1
            if bad: i=min(i,n)
            out.append((9 if bad else 5,nl,0,st,i-st,0.0)); rx=bad; continue
        if c==ord('/') and rx:
            i+=1; cls=False; bad=False
            while True:
                if i>=n: bad=True; break
                d=s[i]; i+=1
                if d==10: bad=True; break
                if d==ord('\\'): i+=1; continue
                if d==ord('['): cls=True
                elif d==ord(']'): cls=False
                elif d==ord('/') and not cls: break
            if bad: i=min(i,n); out.append((9,nl,0,st,i-st,0.0)); rx=True; continue
            while i<n and name(s[i]): i+=1
            out.append((7,nl,0,st,i-st,0.0)); rx=False; continue
        for k,p in enumerate(PU):
            pb=p.encode()
            if s[i:i+len(pb)]==pb and not (k==19 and i+2<n and chr(s[i+2]).isdigit()):
                i+=len(pb); out.append((6,nl,k,st,len(pb),0.0)); rx=k not in (36,38); break
        else: i+=1; out.append((9,nl,0,st,1,0.0)); rx=True
samples=[b'var x = 1 + 2.5e3 / 4;\nlet y=x>>>=2?.5:0x1F_ff;', b'a = b / c / d; e = /[/]\\//gi.test(s) // comment\n/* multi\nline */ f=g\n++h', b'const s = "he said \\"hi\\"\\\n next" + \'it\\\'s\' ;', b'`tpl ${ a + `in ${"}"} ner` } end` ?? x?.y ?.[0] ; z ? .5 : 1', b'if (x) /re/.exec(y); else x = y /2/ z; return /=/; a=/=/', b'0 00 0.0 .5 5. 1e10 1E-7 123456789012345678901234567890 0.000001 1_000 0b101 0o17 9007199254740993 123n 1.5e308 5e-324 3x', b'function f(a,b=2,...r){return a**b===8&&!r||void 0}\nclass A extends B{#p=1;static get x(){}}', b'x\n/* c */ y \xe2\x80\xa8 z \xc2\xa0 w', b'a=>({...b}); c??=d; e&&=f; g||=h; i>>>j; k<<=l; m!==n', b'"unterminated\nnext', b'/* never closed', b'caf\xc3\xa9 = \xcf\x80 * $r_2 ; this/2; null/2; x.of/2 ; }/re/; )/2', b'']
import random; random.seed(3)
alphabet=[b'a',b' ',b'/',b'*',b'"',b"'",b'`',b'\n',b'1',b'.',b'e',b'+',b'=',b'{',b'}',b'(',b')',b'[',b']',b'\\',b'$',b'?',b'x',b'0',b'n',b'<',b'>',b'&',b'|',b'!',b';',b'-',b'_',b'this',b'return']
samples+=[b''.join(random.choice(alphabet) for _ in range(random.randint(1,60))) for _ in range(400)]
wrong=0; words=0
for s in samples:
    a=ours(s); b=theirs(s); words+=len(b)
    same=len(a)==len(b) and all(x[:5]==y[:5] and (x[5]==y[5] or (y[0]==3 and abs(x[5]-y[5])<=abs(y[5])*3e-16)) for x,y in zip(a,b))
    exact=all(x[5]==y[5] for x,y in zip(a,b)) if len(a)==len(b) else False
    if not same:
        wrong+=1
        if wrong<=4:
            print('DIFFERS on',s[:70]); 
            for x,y in zip(a,b):
                if x!=y: print('  ours',x,'theirs',y); break
            if len(a)!=len(b): print('  word counts',len(a),len(b))
    elif not exact: print('note: a number within one unit in the last place but not exact, in',s[:60])
print('%d scripts, %d words, %d scripts wrong'%(len(samples),words,wrong)); sys.exit(1 if wrong else 0)
