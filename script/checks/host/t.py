import subprocess
P='/data/user/0/t.t/files/work/trough-lab/pieces/'; st=P+'out/script.asm'
cmds='@block 30 6 1200000\n@block 40 2 4000\n@file 20 /tmp/h/a.js\n@file 21 /tmp/h/ans.txt\n@target 30\n%s begin 0\n%s load 0 20\n%s run 5f5e100\n'%(st,st,st)
for i in range(2): cmds+='@target 40\n%s text 0 30\n@target 21\n%s text 0 30 1\n@target 30\n%s run 5f5e100\n'%(st,st,st)
cmds+='@target 40\n@output 40\n%s text 0 30\n'%st
r=subprocess.run([P+'out/render',P+'out','1','1','/tmp/h/w'],input=cmds.encode(),capture_output=True)
print(r.stdout.decode()[-600:], r.stderr.decode()[-300:]); print(open('/tmp/h/w','rb').read()[:80])
