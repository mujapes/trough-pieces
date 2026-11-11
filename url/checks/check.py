import subprocess,random,sys
from urllib.parse import urljoin,urlsplit
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; T='/tmp/ur/'; stem=sys.argv[1] if len(sys.argv)>1 else 'out/url.ref'; random.seed(2)
def resolve_all(pairs):
    out=[]
    for k in range(0,len(pairs),40):
        res=[]
        for i,(b,r) in enumerate(pairs[k:k+40]):
            open(T+'b','wb').write(b.encode()); open(T+'r','wb').write(r.encode())
            run=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=('@surface 30 700 1\n@target 30\n@output 30\n@file 20 %sb\n@file 21 %sr\n%s%s resolve 0 20 21\n'%(T,T,P,stem)).encode(),capture_output=True)
            a=int(run.stdout.decode().strip().split('->')[-1]); res.append(None if a<0 else open(T+'o','rb').read()[:a].decode('latin1'))
        out+=res
    return out
base='http://a/b/c/d;p?q'
rfc={"g:h":"g:h","g":"http://a/b/c/g","./g":"http://a/b/c/g","g/":"http://a/b/c/g/","/g":"http://a/g","//g":"http://g","?y":"http://a/b/c/d;p?y","g?y":"http://a/b/c/g?y","#s":"http://a/b/c/d;p?q#s","g#s":"http://a/b/c/g#s","g?y#s":"http://a/b/c/g?y#s",";x":"http://a/b/c/;x","g;x":"http://a/b/c/g;x","g;x?y#s":"http://a/b/c/g;x?y#s","":"http://a/b/c/d;p?q",".":"http://a/b/c/","./":"http://a/b/c/","..":"http://a/b/","../":"http://a/b/","../g":"http://a/b/g","../..":"http://a/","../../":"http://a/","../../g":"http://a/g",
 "../../../g":"http://a/g","../../../../g":"http://a/g","/./g":"http://a/g","/../g":"http://a/g","g.":"http://a/b/c/g.",".g":"http://a/b/c/.g","g..":"http://a/b/c/g..","..g":"http://a/b/c/..g","./../g":"http://a/b/g","./g/.":"http://a/b/c/g/","g/./h":"http://a/b/c/g/h","g/../h":"http://a/b/c/h","g;x=1/./y":"http://a/b/c/g;x=1/y","g;x=1/../y":"http://a/b/c/y","g?y/./x":"http://a/b/c/g?y/./x","g?y/../x":"http://a/b/c/g?y/../x","g#s/./x":"http://a/b/c/g#s/./x","g#s/../x":"http://a/b/c/g#s/../x","http:g":"http:g"}
got=resolve_all([(base,r) for r in rfc]); bad=[(r,w,g) for (r,w),g in zip(rfc.items(),got) if w!=g]
print('the standard\'s own table:',len(rfc),'examples,',len(bad),'wrong',bad[:4])
bases=['https://example.com','https://example.com/','https://example.com/a/b/c.html?x=1#top','http://user@host.test:8080/dir/','https://h/a/b/../c/./d','https://[2001:db8::1]:444/x/y','https://example.com/a/b?q=/../z']
segs=['a','b','..','.','c.html','d e','%7Euser','','x;y','..','.']; pairs=[]
for _ in range(3000):
    b=random.choice(bases); k=random.random()
    if k<0.1: r=random.choice(['https://other.test/p','//cdn.test/lib.js','mailto:someone','HTTP://UP.test/A'])
    else:
        r=('/' if random.random()<0.3 else '')+'/'.join(random.choice(segs) for _ in range(random.randint(0,5)))
        if random.random()<0.3: r+='?'+random.choice(['q=1','','a=/../b','x=y&z'])
        if random.random()<0.3: r+='#'+random.choice(['frag','','a/../b'])
    pairs.append((b,r))
# Python's library differs from the standard in two known ways, which this piece does not copy: it drops a "?" or "#" with nothing
# after it, and it squeezes "//" inside a path. With those two habits applied to our answers, the rest must agree exactly.
import re
def pythonish(u):
    if u is None: return u
    head,sep,frag=u.partition('#'); 
    if sep and not frag: u=head
    head,sep,frag=u.partition('#'); pre,q,query=head.partition('?')
    if q and not query: head=pre
    m=re.match(r'([a-z][a-z0-9+.-]*:(?://[^/?#]*)?)([^?#]*)(.*)',head,re.S)
    if m: path=m.group(2); lead=path.startswith('/'); parts=[x for x in path.split('/')]; kept=[x for i,x in enumerate(parts) if x!='' or i in (0,len(parts)-1)]; head=m.group(1)+'/'.join(kept)+m.group(3)
    return head+(sep+frag if sep and frag else '')
def lowered(u):
    m=re.match(r'([A-Za-z][A-Za-z0-9+.-]*:)(//[^/?#]*)?(.*)',u,re.S)
    if not m: return u
    auth=m.group(2) or ''; user,at,host=auth.rpartition('@'); return m.group(1).lower()+(user+at+host.lower())+m.group(3)
got=resolve_all(pairs); strict=sum(1 for (b,r),g in zip(pairs,got) if lowered(urljoin(b,r))!=g); diff=[(b,r,pythonish(lowered(urljoin(b,r))),pythonish(g)) for (b,r),g in zip(pairs,got) if pythonish(lowered(urljoin(b,r)))!=pythonish(g)]
print(len(pairs),'random links: identical to Python\'s library on',len(pairs)-strict,'; allowing for its two known habits, different on',len(diff)); [print('  ',d) for d in diff[:6]]
# parts and ports
cases=['https://example.com/a/b?x=1#f','http://user:pw@Host.Test:8080/p','https://[2001:db8::1]:444/x','https://example.com','http://example.com:80','https://example.com?q','ftp://files.test/x','https://example.com:99999/','//nohost','mailto:a@b.test']
cmd=''
for i,u in enumerate(cases):
    open(T+'u%d'%i,'wb').write(u.encode()); cmd+='@file 20 %su%d\n@surface 30 300 1\n@target 30\n%s%s port 0 20\n'%(T,i,P,stem)
ports=[int(l.split('->')[1]) for l in subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmd.encode(),capture_output=True).stdout.decode().strip().split('\n') if '->' in l]
print('ports:',dict(zip(cases,ports)))
def part(u,w):
    open(T+'u','wb').write(u.encode()); r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=('@surface 30 300 1\n@target 30\n@output 30\n@file 20 %su\n%s%s part 0 20 %d\n'%(T,P,stem,w)).encode(),capture_output=True); a=int(r.stdout.decode().strip().split('->')[-1]); return None if a<0 else open(T+'o','rb').read()[:a].decode()
for u in cases[:4]: print('  ',u,'->',[part(u,w) for w in range(6)])
