import subprocess,struct,sys,os
D=os.path.dirname(os.path.abspath(__file__))+'/'
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; st=P+'out/script.asm'
cmds='@block 30 6 1200000\n@target 30\n@output 30\n%s begin 0\n'%st
for i,f in enumerate('abcde'): cmds+='@file %d %s%s.js\n%s load 0 %d\n%s run 5f5e100\n'%(20+i,D,f,st,20+i,st)
r=subprocess.run([P+'out/render',P+'out','1','1','/tmp/ap/w'],input=cmds.encode(),capture_output=True)
print([l.split('->')[-1].strip() for l in r.stdout.decode().strip().split('\n') if '->' in l])
d=open('/tmp/ap/w','rb').read(); q=lambda at: struct.unpack('<Q',d[at-64:at-56])[0]
print(d[q(144)-64:q(144)-64+q(152)].decode())
