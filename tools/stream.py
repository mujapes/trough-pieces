#!/usr/bin/env python3
"""The code stream (RELOAD.md): one growing file of sealed records of machine code.
  stream.py append <piece> <variant>   admit a build (it must replay the piece's recorded checks) and append it as a record
  stream.py follow [--once]            take every record not yet taken: the reload piece judges it; a good one becomes the live
                                       piece (sealed pair, way back kept, roll-back guard started), exactly as promote.sh does
  stream.py list                       what the stream holds
The stream is out/code.stream; how far the follower has got is out/code.stream.taken."""
import sys,os,struct,hashlib,subprocess,time
P=os.path.dirname(os.path.abspath(__file__))+'/../'; O=P+'out/'; S=O+'code.stream'; T='/tmp/stream/'; os.makedirs(T,exist_ok=True)
def record(name,entries,code):
    body=b'TRPC'+struct.pack('<IIII',64+len(name)+len(entries)+len(code),len(name),len(entries),len(code))+bytes(12)+name+entries+code
    return body+hashlib.sha256(body).digest()
def judge(at,which=None,room=1200000):
    line='%sout/reload record %x 20\n'%(P,at) if which is None else '%sout/reload part %x 20 %d\n'%(P,at,which)
    cmds='@file 20 %s\n@block 30 2 %d\n@target 30\n@output 30\n%s'%(S,room,line)
    r=subprocess.run([O+'render',O[:-1],'1','1',T+'o'],input=cmds.encode(),capture_output=True); a=int(r.stdout.decode().strip().split('->')[-1]); return a if which is None else (open(T+'o','rb').read()[:a] if a>=0 else None)
def taken(): return int(open(S+'.taken').read()) if os.path.exists(S+'.taken') else 0
def append(piece,variant):
    stem=O+piece+'.'+variant
    c=subprocess.run([O+'vectors','check',stem,O+piece+'.piece',O+piece+'.vectors'],capture_output=True).stdout.decode().strip().split('\n')[-1]
    if 'PASSES' not in c: print('not admitted:',c); return 1
    rec=record(piece.encode(),open(stem+'.entries','rb').read(),open(stem+'.bin','rb').read())
    with open(S,'ab') as f: f.write(rec); f.flush(); os.fsync(f.fileno())
    print('appended %s (%s): %d bytes at %d'%(piece,variant,len(rec),os.path.getsize(S)-len(rec))); return 0
def take(at,n):
    name=judge(at,0).decode(); entries=judge(at,1); code=judge(at,2); began=time.time()
    if os.path.exists(O+name+'.bin') and open(O+name+'.bin','rb').read()!=code:
        for kind in ('bin','entries','live'):
            if os.path.exists(O+name+'.'+kind): open(O+name+'.prev.'+kind,'wb').write(open(O+name+'.'+kind,'rb').read())
    try: os.remove(O+name+'.pair')
    except FileNotFoundError: pass
    for kind,data in (('entries',entries),('bin',code)): open(O+name+'.'+kind+'.tmp','wb').write(data); os.replace(O+name+'.'+kind+'.tmp',O+name+'.'+kind)
    open(O+name+'.pair.tmp','w').write('%s %s\n'%(hashlib.sha256(code).hexdigest(),hashlib.sha256(entries).hexdigest())); os.replace(O+name+'.pair.tmp',O+name+'.pair')
    open(O+name+'.live','w').write('stream@%d\n'%at); open(O+'history.log','a').write('%s %s taken from the stream at %d, %d bytes\n'%(time.strftime('%Y-%m-%dT%H:%M:%S'),name,at,len(code)))
    subprocess.Popen(['python3',P+'tools/guard.py',name],stdout=open(O+name+'.guard.log','w'),stderr=subprocess.STDOUT,start_new_session=True)
    print('took %s from %d: %d bytes of code in place %.0f ms after reading the record'%(name,at,len(code),(time.time()-began)*1e3))
def follow(once):
    while True:
        at=taken(); size=os.path.getsize(S) if os.path.exists(S) else 0
        while at<size:
            n=judge(at)
            if n==0: break                                   # still being written
            if n<0: print('REFUSED the record at %d (answer %d); the follower stops here until the stream is repaired'%(at,n)); return 1
            take(at,n); at+=n; open(S+'.taken','w').write(str(at))
        if once: return 0
        time.sleep(0.05)
def listing():
    at=0; size=os.path.getsize(S) if os.path.exists(S) else 0
    while at<size:
        n=judge(at)
        if n<=0: print('%d: %s'%(at,'still arriving' if n==0 else 'REFUSED')); break
        print('%d: %s, %d bytes of code%s'%(at,judge(at,0).decode(),len(judge(at,2)),'' if at<taken() else '  (not yet taken)')); at+=n
if __name__=='__main__':
    cmd=sys.argv[1] if len(sys.argv)>1 else ''
    sys.exit(append(sys.argv[2],sys.argv[3]) if cmd=='append' else follow('--once' in sys.argv) if cmd=='follow' else listing() if cmd=='list' else print(__doc__))
