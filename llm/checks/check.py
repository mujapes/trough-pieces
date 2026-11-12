#!/usr/bin/env python3
"""check.py <stem>: the llm piece against a separate statement of the same rules (Python's own JSON for the escaping), on fixed and
random prompts, on event streams cut at every length, and on what must be refused."""
import sys,subprocess,os,json,random
P=os.path.dirname(os.path.abspath(__file__))+'/../../'; stem=os.path.abspath(sys.argv[1]); T='/tmp/llmcheck/'; os.makedirs(T,exist_ok=True)
def call(files,line,room=70000):
    cmds=''.join('@file %d %s\n'%(20+i,f) for i,f in enumerate(files))+'@block 30 2 %d\n@target 30\n@output 30\n%s %s\n'%(room,stem,line)
    r=subprocess.run([P+'out/render',P+'out','1','1',T+'o'],input=cmds.encode(),capture_output=True); a=int(r.stdout.decode().strip().split('->')[-1]); return a,(open(T+'o','rb').read()[:a] if a>=0 else b'')
def put(name,data): open(T+name,'wb').write(data); return T+name
random.seed(7); wrong=0; n=0
def want_request(key,model,prompt,mx):
    body=b'{"model":"'+model+b'","max_tokens":'+str(mx).encode()+b',"stream":true,"messages":[{"role":"user","content":"'
    for c in prompt: body+= {34:b'\\"',92:b'\\\\',10:b'\\n',13:b'\\r',9:b'\\t'}.get(c, b'\\u%04x'%c if c<32 else bytes([c]))
    body+=b'"}]}'
    return b'POST /v1/messages HTTP/1.1\r\nHost: api.anthropic.com\r\nContent-Type: application/json\r\nX-Api-Key: '+key+b'\r\nAnthropic-Version: 2023-06-01\r\nConnection: close\r\nContent-Length: '+str(len(body)).encode()+b'\r\n\r\n'+body
key=b'sk-test-0123456789abcdefABCDEF_-'; model=b'claude-opus-5-5'
prompts=[b'Hello', 'Say "hi"\n\tback\\slash café \U0001F600'.encode(), bytes(range(1,128)), b'x'*5000]+[bytes(random.choice(b'ab "\\\n\r\t\x01\x1f\x7f\xc3\xa9') for _ in range(random.randint(1,60))) for _ in range(60)]
for pr in prompts:
    for mx in (1,1024,64000):
        a,out=call([put('k',key),put('m',model),put('p',pr)],'request %x 20 21 22'%mx); w=want_request(key,model,pr,mx); n+=1
        if out!=w: wrong+=1; print('request differs for',pr[:30],mx,a,len(w))
        else:
            try: valid=pr.decode('utf-8')
            except UnicodeDecodeError: valid=None
            if valid is not None and json.loads(out.split(b'\r\n\r\n',1)[1])['messages'][0]['content']!=valid: wrong+=1; print('a JSON reader does not get the prompt back',pr[:30])
for bad,why in (([put('k',b'bad key'),put('m',model),put('p',b'x')],'space in key'),([put('k',b'a\r\nX: y'),put('m',model),put('p',b'x')],'line break in key'),([put('k',key),put('m',b'mo del'),put('p',b'x')],'space in model'),([put('k',key),put('m',b'm"x'),put('p',b'x')],'quote in model'),([put('k',b'k'*301),put('m',model),put('p',b'x')],'long key')):
    a,_=call(bad,'request 400 20 21 22'); n+=1
    if a!=-1: wrong+=1; print('not refused:',why,a)
for mx in (0,64001):
    a,_=call([put('k',key),put('m',model),put('p',b'x')],'request %x 20 21 22'%mx); n+=1
    if a!=-1: wrong+=1; print('max tokens not refused',mx)
a,_=call([put('k',key),put('m',model),put('p',b'x'*100)],'request 400 20 21 22',room=200); n+=1
if a!=-1: wrong+=1; print('too small a block not refused')
# the event stream, as the API documents it
def stream(parts,stop=True):
    s='event: message_start\ndata: {"type":"message_start","message":{"id":"msg_1","type":"message","role":"assistant","content":[],"model":"m","usage":{"input_tokens":3,"output_tokens":1}}}\n\nevent: content_block_start\ndata: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}\n\nevent: ping\ndata: {"type": "ping"}\n\n'
    for t in parts: s+='event: content_block_delta\ndata: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":%s}}\n\n'%json.dumps(t)
    if stop: s+='event: content_block_stop\ndata: {"type":"content_block_stop","index":0}\n\nevent: message_delta\ndata: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":9}}\n\nevent: message_stop\ndata: {"type":"message_stop"}\n\n'
    return s.encode()
parts=['Hello',', wor','ld! "quoted" \\ back/slash\n\ttab ','café 中文 ','\U0001F600 done.','\x01\x7f']
full=stream(parts); whole=''.join(parts).encode()
a,out=call([put('s',full)],'text 0 20'); n+=1
if out!=whole: wrong+=1; print('text differs on the whole stream',a,len(whole))
import re
def model_text(data):
    out=b''; i=0
    while True:
        j=data.find(b'"type":"text_delta"',i)
        if j<0: return out
        j+=19; e=data.find(b'\n',j); line_end=e if e>=0 else len(data); k=data.find(b'"text":"',j,line_end)
        if k<0:
            if e<0: return out
            i=j; continue
        k+=8; m=re.compile(rb'(?:[^"\\]|\\.)*"').match(data,k)
        if not m: return out
        try: out+=json.loads(b'"'+data[k:m.end()]).encode('utf-8')
        except Exception: return out
        i=m.end()
for cut in list(range(0,len(full),7))+[len(full)-1]:
    a,out=call([put('s',full[:cut])],'text 0 20') if cut else (0,b''); n+=1
    if cut and out!=model_text(full[:cut]): wrong+=1; print('text differs at cut',cut,out[-20:],model_text(full[:cut])[-20:])
for data,want in ((full,1),(stream(parts,False),0),(stream(['x'],False)+b'event: error\ndata: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}\n\n',2),(full+b'data: {"type":"error"}\n',2)):
    a,_=call([put('s',data)],'stopped 0 20'); n+=1
    if a!=want: wrong+=1; print('stopped says',a,'wanted',want)
a,_=call([put('s',full)],'text 0 20',room=64); n+=1
if a!=-1: wrong+=1; print('words that do not fit were not refused')
print('%d calls, %d wrong'%(n,wrong)); sys.exit(1 if wrong else 0)
