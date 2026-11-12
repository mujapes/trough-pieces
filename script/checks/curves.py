# curves.py out/script.asm [n]: exp, log, log2, log10 and fractional powers against exact arithmetic (decimal, 60 digits):
# every answer must be the correctly rounded one. Prints the count wrong and the first few.
import sys,random,math,os
from decimal import Decimal as D,getcontext
getcontext().prec=60
here=os.path.dirname(os.path.abspath(__file__))
src=open(here+'/run.py').read().split('\ndef ref')[0]; sys.argv=[sys.argv[0],sys.argv[1]]+sys.argv[2:]; exec(src)
n=int(sys.argv[2]) if len(sys.argv)>2 else 400
random.seed(int(sys.argv[3]) if len(sys.argv)>3 else 7); cases=[]
def rnd(lo,hi): return random.uniform(lo,hi)
def big(): return math.ldexp(random.random()+0.5,random.randint(-1070,1020))
for i in range(n):
    x=rnd(-745,709) if i%2 else rnd(-2,2); cases.append(('Math.exp(%r)'%x,D(x).exp()))
    x=big() if i%2 else rnd(0.5,2); L=D(x).ln(); cases.append(('Math.log(%r)'%x,L)); cases.append(('Math.log2(%r)'%x,L/D(2).ln())); cases.append(('Math.log10(%r)'%x,L/D(10).ln()))
    x=rnd(0,50) if i%2 else big(); y=rnd(-3,3) if i%2 else rnd(-0.6,0.6); cases.append(('Math.pow(%r,%r)'%(x,y),(D(y)*D(x).ln()).exp()))
fixed=['Math.exp(0)','Math.exp(1)','Math.exp(-1/0)','Math.exp(1/0)','Math.exp(710)','Math.exp(-745.2)','Math.exp(-750)','Math.exp(0/0)','Math.log(0)','Math.log(-1)','Math.log(1)','Math.log(1/0)','Math.log(5e-324)','Math.log2(8)','Math.log2(1024)','Math.log10(1000)','Math.log10(1e-5)','Math.log2(0)',
 '4**0.5','8**(1/3)','2**0.5','(-8)**(1/3)','0**0.5','0**-0.5','(1/0)**-0.5','(1/0)**0.5','(0/0)**0.5','2**(0/0)','1e-320**0.5','0.5**1074.5','1e308**1.0001','10**-323.5','Math.random()<1','typeof Math.random()']
p='/tmp/curves.js'; open(p,'w').write(''.join('console.log(%s);\n'%c for c,_ in cases)+''.join('console.log(%s);\n'%c for c in fixed))
out,err,res=ours(p); got=out.split('\n')
if err: print('error',err)
bad=0
for (c,e),g in zip(cases,got):
    try: w=float(e)
    except OverflowError: w=math.inf
    if float(g)!=w:
        bad+=1
        if bad<6: print('wrong',c,'ours',g,'exact',repr(w))
print(len(cases),'curve values,',bad,'wrong')
import subprocess
nd=subprocess.run(['node','-e',''.join('console.log(%s);'%c for c in fixed[:-2])],capture_output=True).stdout.decode().split('\n')
for c,g,w in zip(fixed,got[len(cases):],nd):
    if g!=w: print('fixed',c,'ours',g,'node',w)
print('fixed tail:',got[len(cases)+len(fixed)-2:len(cases)+len(fixed)])
