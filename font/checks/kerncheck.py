import subprocess,random
from fontTools.ttLib import TTFont
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; f=TTFont(P+'out/font.fixture'); cmap=f.getBestCmap(); order=f.getGlyphOrder(); hm=f['hmtx']; upm=f['head'].unitsPerEm
g=f['GPOS'].table; idx=sorted({i for fr in g.FeatureList.FeatureRecord if fr.FeatureTag=='kern' for i in fr.Feature.LookupListIndex})
def kern(a,b):
    t=0
    for i in idx:
        for st in g.LookupList.Lookup[i].SubTable:
            if type(st).__name__=='ExtensionPos': st=st.ExtSubTable
            if type(st).__name__!='PairPos' or a not in st.Coverage.glyphs: continue
            if st.Format==1:
                rec=[r for r in st.PairSet[st.Coverage.glyphs.index(a)].PairValueRecord if r.SecondGlyph==b]
                if rec: t+=(rec[0].Value1.XAdvance or 0) if rec[0].Value1 is not None else 0; break
            else:
                c1=st.ClassDef1.classDefs.get(a,0); c2=st.ClassDef2.classDefs.get(b,0); v=st.Class1Record[c1].Class2Record[c2].Value1; t+=(getattr(v,'XAdvance',0) or 0) if v is not None else 0; break
    return t
codes=[c for c in cmap if c<0x2000 and c<32767]; random.seed(1); common=[ord(c) for c in 'AVTWYLPFoeaynrv.,-"\' ctfTo']
cases=[]
for _ in range(3000):
    n=random.randint(1,12); s=[random.choice(common if random.random()<0.7 else codes) for _ in range(n)]; cases.append((random.choice([9,12,16,18,24,37,64,200]),s))
cmd='@file 20 %sout/font.fixture\n'%P+''.join('%sout/font.ref measure 0 20 %d %s\n'%(P,size,' '.join(map(str,s))) for size,s in cases)
out=subprocess.run([P+'out/render',P+'out','8','8','/tmp/k.rgba'],input=cmd.encode(),capture_output=True).stdout.decode().strip().split('\n')
got=[int(l.split('->')[1]) for l in out if 'measure' in l]; bad=0; kerned=0
for (size,s),gv in zip(cases,got):
    names=[cmap[c] for c in s]; pen=0
    for i,nm in enumerate(names):
        if i: k=kern(names[i-1],nm); kerned+= k!=0; pen+=(k*size*16+upm//2)//upm
        pen+=(hm[nm][0]*size*16+upm//2)//upm
    if pen!=gv: bad+=1; (bad<6) and print('DIFF',size,''.join(map(chr,s)),pen,gv)
print(len(got),'strings',bad,'different;',kerned,'kerned pairs among them; AV at 100px:',kern('A','V')*100/upm,'px')
