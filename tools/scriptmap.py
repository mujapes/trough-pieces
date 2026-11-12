#!/usr/bin/env python3
"""scriptmap.py: writes script/MAP.md, a short map of the script engine for a fresh reader: every routine and macro with the
first line said about it, the instruction numbers, and the punctuation numbers. Read MAP.md before opening the .S files."""
import re,os
D=os.path.dirname(os.path.abspath(__file__))+'/../script/'; out=['# script: the map (made by tools/scriptmap.py; do not edit)\n']
for f in ['world.S','lex.S','values.S','strings.S','num.S','compile.S','machine.S','objects.S','entries.S']:
    L=open(D+f).read().split('\n'); out.append('\n## %s (%d lines)\n%s'%(f,len(L),' '.join(l[3:] for l in L[:6] if l.startswith('// '))[:700]))
    for i,l in enumerate(L):
        m=re.match(r'([a-z][a-z_0-9]*):\s*(?://\s*(.*))?$',l) or re.match(r'\s+\.macro\s+(\S+)(.*)',l)
        if not m: continue
        say=(m.group(2) or '').strip() if not l.lstrip().startswith('.macro') else 'macro'+m.group(2)
        j=i-1; above=[]
        while j>=0 and L[j].startswith('//'): above.insert(0,L[j][2:].strip()); j-=1
        if above: say=(' '.join(above))[:260]
        if say or f in('compile.S','machine.S','objects.S'): out.append('- %d `%s` %s'%(i+1,m.group(1),say))
m=open(D+'machine.S').read(); out.append('\n## Instructions\n'+' '.join('%s=%s'%(a[3:],b) for a,b in re.findall(r'\.equ (OP_\w+), (\d+)',m)))
t=open(D+'lex.S').read(); t=t[t.index('t_punct:'):]; out.append('\n## Punctuation numbers\n'+' '.join('%d `%s`'%(k,v) for k,v in enumerate(re.findall(r'\.ascii\s+"((?:[^"\\]|\\.)*)"',t))))
open(D+'MAP.md','w').write('\n'.join(out)+'\n'); print(len(out),'lines')
