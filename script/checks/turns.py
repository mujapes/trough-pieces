# turns.py out/script.asm [n] [seed]: sin, cos, tan against mpmath at 2000 bits: every answer must be the correctly rounded
# one. Angles of every size, and ones chosen close to multiples of pi/2. Run with python3 -I.
import sys,random,math,os,mpmath,subprocess
mpmath.mp.prec=2000
here=os.path.dirname(os.path.abspath(__file__))
exec(open(here+'/run.py').read().split('\ndef ref')[0])
n=int(sys.argv[2]) if len(sys.argv)>2 else 300
random.seed(int(sys.argv[3]) if len(sys.argv)>3 else 7); xs=[]
for i in range(n):
    xs.append(random.uniform(-7,7)); xs.append(math.ldexp(random.random()+0.5,random.randint(-40,1023))*random.choice([1,-1]))
    xs.append(float(mpmath.pi/2*random.randint(1,10**random.randint(1,15))))
xs+=[0.7853981633974483,0.7853981633974484,1.5707963267948966,3.141592653589793,6.283185307179586,1e22,5e-324,1e-300,1.7976931348623157e308,6381956970095103*2.0**797,-1e-8]
cases=[('Math.%s(%r)'%(f,x),getattr(mpmath,f)(mpmath.mpf(x))) for x in xs for f in('sin','cos','tan')]
fixed=['Math.sin(0)','1/Math.sin(-0)','1/Math.tan(-0)','Math.cos(0)','Math.sin(1/0)','Math.cos(-1/0)','Math.tan(0/0)']
p='/tmp/turns.js'; open(p,'w').write(''.join('console.log(%s);\n'%c for c,_ in cases+[(c,0) for c in fixed]))
out,err,res=ours(p); got=out.split('\n')
if err: print('error',err)
bad=0
for (c,e),g in zip(cases,got):
    if g=='' or float(g)!=float(e):
        bad+=1
        if bad<6: print('wrong',c,'ours',g,'exact',repr(float(e)))
print(len(cases),'turn values,',bad,'wrong')
nd=subprocess.run(['node','-e',''.join('console.log(%s);'%c for c in fixed)],capture_output=True).stdout.decode().split('\n')
for c,g,w in zip(fixed,got[len(cases):],nd):
    if g!=w: print('fixed',c,'ours',g,'node',w)
