# patterns.py out/script.asm [cases.json ...]: regular expressions against node. A case is [pattern, flags, text]; exec's
# answer (where, each group, lastIndex) or the fact of a SyntaxError must be the same. Run with python3 -I.
import sys,os,json,subprocess
here=os.path.dirname(os.path.abspath(__file__))
exec(open(here+'/run.py').read().split('\ndef ref')[0].replace("os.path.dirname(os.path.abspath(__file__))","here"))
cases=[]
for f in (sys.argv[2:] or [here+'/patterns.json']): cases+=json.load(open(f))
bad=0
for at in range(0,len(cases),100):
    part=cases[at:at+100]
    js='var C=%s;\nfor(var i=0;i<C.length;i++){var o;try{var re=new RegExp(C[i][0],C[i][1]),r=re.exec(C[i][2]);o=r===null?"null":r.index+":"+r.length+":"+r.join("|")+":"+re.lastIndex}catch(e){o=e instanceof SyntaxError?"SyntaxError":"error "+e}console.log(o)}\n'%json.dumps(part)
    p='/tmp/patterns.js'; open(p,'w').write(js)
    out,err,res=ours(p); got=out.split('\n'); want=subprocess.run(['node',p],capture_output=True).stdout.decode().split('\n')
    if err: print('error',err)
    for c,g,w in zip(part,got+['']*len(part),want):
        if g!=w:
            bad+=1
            if bad<13: print('wrong',json.dumps(c),'ours',g[:50],'node',w[:50])
print(len(cases),'patterns,',bad,'wrong')
