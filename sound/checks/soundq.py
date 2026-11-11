import math,struct,subprocess
B='/data/user/0/t.t/files/work/trough-lab/pieces/out/'
def tone(freqs,rate,secs=1.0,amp=12000): return [int(round(sum(amp*math.sin(2*math.pi*f*i/rate) for f in freqs))) for i in range(int(rate*secs))]
def power_at(s,f,rate):
    c=sum(v*math.cos(2*math.pi*f*i/rate) for i,v in enumerate(s)); q=sum(v*math.sin(2*math.pi*f*i/rate) for i,v in enumerate(s)); return 2*(c*c+q*q)/len(s)**2
def run(entry,s,rin,rout):
    open('/tmp/flactest/t.raw','wb').write(struct.pack('<%dh'%len(s),*s))
    r=subprocess.run([B+'soundbench',B+'sound.ref',entry,'/tmp/flactest/t.raw','/tmp/flactest/u.raw',str(rin//25),'1',str(rout//25),'1','256'],capture_output=True,text=True)
    d=open('/tmp/flactest/u.raw','rb').read(); return list(struct.unpack('<%dh'%(len(d)//2),d))
def db(x): return 10*math.log10(max(x,1e-12))
for name,f,rin,rout in [('1 kHz up',1000,44100,48000),('10 kHz up',10000,44100,48000),('18 kHz up',18000,44100,48000),('5 kHz down to half',5000,44100,22050),('10 kHz 48 to 44.1',10000,48000,44100)]:
    for e in ('convert','resample'):
        o=run(e,tone([f],rin),rin,rout); o=o[2000:-2000]; total=sum(v*v for v in o)/len(o); sig=power_at(o,f,rout); print('%-20s %-9s tone %.2f dB of input, everything else %.1f dB below it'%(name,e,db(sig/(12000**2/2)),db(sig/max(total-sig,1e-9))))
for e in ('convert','resample'):
    o=run(e,tone([15000],44100),44100,22050)[2000:-2000]; print('15 kHz into 22.05 kHz (cannot be kept; folds to 7.05 kHz)',e,'false tone at %.1f dB of the input'%db(power_at(o,7050,22050)/(12000**2/2)))
