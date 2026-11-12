#!/usr/bin/env python3
"""guard.py <piece>: watches one promotion and undoes it if it goes badly. Started by promote.sh.
A promotion is on trial until the running app has taken the new code (its status names the new size) and has then stayed alive
for SETTLE seconds. If the app's process changes during the trial (it died), or the app says it will not run the new code, the
previous sealed pair is put back, seal removed first and written last, exactly as a promotion does. One line goes to out/history.log.
Environment, for testing: GUARD_STATUS, GUARD_RUNTIME (the two files read), GUARD_SETTLE, GUARD_WAIT (seconds)."""
import sys,os,json,time,hashlib,shutil,subprocess
P=os.path.dirname(os.path.abspath(__file__))+'/../out/'; piece=sys.argv[1]; H='/data/user/0/t.t/files/home/.trough/'
status_file=os.environ.get('GUARD_STATUS',H+'pieces-status.json'); runtime_file=os.environ.get('GUARD_RUNTIME',H+'ui-runtime.json')
settle=float(os.environ.get('GUARD_SETTLE','20')); wait=float(os.environ.get('GUARD_WAIT','90'))
def pid():
    try: return json.load(open(runtime_file)).get('pid')
    except Exception: return None
def said():
    try:
        for p in json.load(open(status_file))['pieces']:
            if p['name']==piece: return p
    except Exception: pass
    return None
def log(line):
    open(P+'history.log','a').write('%s %s %s\n'%(time.strftime('%Y-%m-%dT%H:%M:%S'),piece,line)); print(line)
def back(why):
    if not (os.path.exists(P+piece+'.prev.bin') and os.path.exists(P+piece+'.prev.entries')): log('trial FAILED (%s) and there is no earlier build to go back to'%why); return 2
    try: os.remove(P+piece+'.pair')
    except FileNotFoundError: pass
    for kind in ('entries','bin'): shutil.copyfile(P+piece+'.prev.'+kind,P+piece+'.'+kind+'.tmp'); os.replace(P+piece+'.'+kind+'.tmp',P+piece+'.'+kind)
    seal='%s %s\n'%(hashlib.sha256(open(P+piece+'.bin','rb').read()).hexdigest(),hashlib.sha256(open(P+piece+'.entries','rb').read()).hexdigest())
    open(P+piece+'.pair.tmp','w').write(seal); os.replace(P+piece+'.pair.tmp',P+piece+'.pair')
    if os.path.exists(P+piece+'.prev.live'): shutil.copyfile(P+piece+'.prev.live',P+piece+'.live')
    log('ROLLED BACK to %s: %s'%(open(P+piece+'.live').read().strip() if os.path.exists(P+piece+'.live') else 'the build before',why))
    subprocess.run([H+'../.local/bin/trough-show','Rolled back %s by itself: %s'%(piece,why)],capture_output=True); return 1
size=os.path.getsize(P+piece+'.bin'); born=pid(); started=time.time(); taken=None
if born is None: log('trial not watched: the app is not running; the new build stays'); sys.exit(0)
while time.time()-started<wait:
    time.sleep(1)
    if pid()!=born: sys.exit(back('the app died within %.0f s of taking the new build'%(time.time()-started)))
    s=said()
    if s and not s.get('live',True) and taken is None and time.time()-started>8 and 'not a sealed pair' not in s.get('said',''): sys.exit(back('the app would not run it: '+s.get('said','')[:120]))
    if s and taken is None and ('%d bytes'%size) in s.get('said',''): taken=time.time()
    if taken and time.time()-taken>=settle:
        for kind in ('trial',): 
            try: os.remove(P+piece+'.'+kind)
            except FileNotFoundError: pass
        log('settled: the app took it and stayed up %.0f s'%settle); sys.exit(0)
log('trial ended without the app taking the new build (asleep or busy); it stays, unwatched'); sys.exit(0)
