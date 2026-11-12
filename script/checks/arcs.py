# arcs.py out/script.asm [n] [seed]: atan, atan2, asin, acos, expm1, log1p, sinh, cosh, tanh, cbrt, hypot against mpmath at
# 2000 bits: every answer must be the correctly rounded one. Run with python3 -I.
import sys,random,math,os,mpmath,subprocess
mpmath.mp.prec=2000
here=os.path.dirname(os.path.abspath(__file__))
exec(open(here+'/run.py').read().split('\ndef ref')[0])
n=int(sys.argv[2]) if len(sys.argv)>2 else 40
random.seed(int(sys.argv[3]) if len(sys.argv)>3 else 7); M=mpmath.mpf
big=lambda lo,hi: math.ldexp(random.random()+0.5,random.randint(lo,hi))*random.choice([1,-1])
def rnd(v):
    f=float(v)
    return f
cases=[]
def add(f,args,e): cases.append(('Math.%s(%s)'%(f,','.join(repr(a) for a in args)),e))
for i in range(n):
    for x in (random.uniform(-3,3),big(-60,60),big(-1070,1023),random.choice([k/8 for k in range(1,9)])+random.uniform(-1e-9,1e-9)):
        add('atan',[x],mpmath.atan(M(x))); add('cbrt',[x],mpmath.cbrt(abs(M(x)))*(1 if x>0 else -1))
    for x in (random.uniform(-1,1),big(-60,-1),big(-1070,-1),random.choice([1,-1])*(1-math.ldexp(random.random(),-random.randint(1,50)))):
        add('asin',[x],mpmath.asin(M(x))); add('acos',[x],mpmath.acos(M(x)))
    for x in (random.uniform(-1,1),random.uniform(-40,40),random.uniform(-708,708),big(-60,-1),big(-1070,-60)):
        add('expm1',[x],mpmath.expm1(M(x))); add('sinh',[x],mpmath.sinh(M(x))); add('cosh',[x],mpmath.cosh(M(x))); add('tanh',[x],mpmath.tanh(M(x)))
    for x in (random.uniform(-1,3),abs(big(-60,60)),abs(big(-1070,1023)),-1+math.ldexp(random.random(),-random.randint(0,52)),big(-60,-1)):
        add('log1p',[x],mpmath.log(1+M(x)))
    for y,x in ((random.uniform(-3,3),random.uniform(-3,3)),(big(-500,500),big(-500,500)),(big(-1070,1023),big(-1070,1023))):
        add('atan2',[y,x],mpmath.atan2(M(y),M(x))); add('hypot',[y,x],mpmath.sqrt(M(y)**2+M(x)**2))
    v=[big(-30,30) for k in range(random.randint(3,5))]; add('hypot',v,mpmath.sqrt(sum(M(a)**2 for a in v)))
add('cbrt',[27.0],3); add('cbrt',[-8.0],-2); add('hypot',[3.0,4.0],5); add('hypot',[1e308,1e308],M(1e308)*mpmath.sqrt(2)); add('hypot',[5e-324,5e-324],M(5e-324)*mpmath.sqrt(2))
add('sinh',[710.0],mpmath.sinh(710)); add('cosh',[-710.4],mpmath.cosh(M(-710.4))); add('expm1',[709.7],mpmath.expm1(M(709.7)))
fixed=['Math.atan(1/0)','Math.atan(-1/0)','1/Math.atan(-0)','1/Math.asin(-0)','1/Math.acos(1)','Math.acos(-1)','Math.asin(1)','Math.asin(-1)','Math.asin(1.0000001)','Math.acos(0/0)',
 '1/Math.expm1(-0)','Math.expm1(-1/0)','Math.expm1(1/0)','Math.expm1(710)','1/Math.log1p(-0)','Math.log1p(-1)','Math.log1p(-1.1)','Math.log1p(1/0)','1/Math.sinh(-0)','Math.sinh(-1/0)','Math.sinh(711)','Math.cosh(-0)','Math.cosh(-1/0)','Math.cosh(800)',
 '1/Math.tanh(-0)','Math.tanh(1/0)','Math.tanh(-1/0)','Math.tanh(50)','1/Math.cbrt(-0)','Math.cbrt(-1/0)','Math.cbrt(0/0)','Math.hypot()','Math.hypot(-3)','Math.hypot(0/0,1/0)','Math.hypot(0/0,1)','1/Math.hypot(-0,0)','Math.hypot(1e308,1e308,1e308,1e308)','Math.hypot("3","4")']
for y in ('0','-0','1','-1','1/0','-1/0','0/0'):
    for x in ('0','-0','1','-1','1/0','-1/0','0/0'): fixed.append('1/Math.atan2(%s,%s)'%(y,x)); fixed.append('Math.atan2(%s,%s)'%(y,x))
bad=0; tot=0
for at in range(0,len(cases),500):
    part=cases[at:at+500]; last=at+500>=len(cases); extra=fixed if last else []
    p='/tmp/arcs.js'; open(p,'w').write(''.join('console.log(%s);\n'%c for c,_ in part)+''.join('console.log(%s);\n'%c for c in extra))
    out,err,res=ours(p); got=out.split('\n')
    if err: print('error',err)
    for (c,e),g in zip(part,got):
        tot+=1
        if g=='' or float(g)!=float(e):
            bad+=1
            if bad<9: print('wrong',c,'ours',g,'exact',repr(float(e)))
    if last:
        nd=subprocess.run(['node','-e',''.join('console.log(%s);'%c for c in fixed)],capture_output=True).stdout.decode().split('\n')
        for c,g,w in zip(fixed,got[len(part):],nd):
            if g!=w and not (g=='0' and w=='-0'): print('fixed',c,'ours',g,'node',w)
print(tot,'arc and hyperbolic values,',bad,'wrong')
