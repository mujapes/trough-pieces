// constructs real sites stopped on, second round (unit 22)
function tag(s,...v){return s.join('|')+'#'+v.join(',')+'#'+s.length}
var o={t:tag,css(s,a){return this===o?s[0]+a+s[1]:'bad'}};
console.log(tag`a${1}b${2+3}`, tag``, tag`${7}`, o.css`x${1}y`, (e=>tag`p${e}`)(4));
var c=(s,...v)=>s.join("|")+v.join(",");
console.log(c`a ${(e=>c`
 it{ "s ${e} don't } ${`{${e}`} `)(1)} b`, c`x${"`"}y${{a:`}`}.a}`);
var p={a:null,b:0,c:5},k='z',n=0,f=()=>(n++,9);
p.a??=3; p.b||=4; p.c&&=6; p[k]??=f(); p[k]??=f(); p.c||=f();
console.log(p.a,p.b,p.c,p.z,n,(p.q??=1)+(p['q']&&=2),JSON.stringify(p));
var {a,b:bb=5,...r}={a:1,z:2,y:3}; function g({x,...n},[q,{w,...m}]){return JSON.stringify([x,n,q,w,m])}
var h=({k:t=[],...n})=>t.length+JSON.stringify(n), u; ({a,...u}={a:9,b:8});
let {data:{d:e,...w}}={data:{d:1,e:2}}; var {...all}={h:1};
console.log(a,bb,JSON.stringify(r),g({x:1,y:2,z:3},[4,{w:5,s:6}]),h({k:[1],j:2}),JSON.stringify(u),e,JSON.stringify(w),all.h);
class A { x = 1; y; static s = 7; ['k'+1] = 2; h = () => this.x + 1; m() { return this.x } static t(){return 3} get g(){return 5} }
class B extends A { z = this.x + 10; w = 4 }
class C extends B { q; constructor(a){ var p=a*2; super(); this.r = this.z + p } v = 9 }
class D { n = 3; constructor(k){ this.o = this.n + k } }
var xa=new A, xb=new B, xc=new C(2), xd=new D(1), xh=xa.h;
console.log(xa.x,xa.y,'y' in xa,A.s,xa.k1,xh(),xa.m(),A.t(),xa.g,xb.z,xb.w,xb.x,xc.r,xc.v,'q' in xc,xc.h(),xd.o,Object.keys(xc).join());
class J{static n=1;static{this.ev=[this.n+1]; let q=5; J.z=()=>q}a=2;static{J.y=this.ev.length}static k=J.n+7;m(){return this.a}}
console.log(J.ev[0],J.z(),J.y,J.k,new J().m(),Object.keys(new J).join());
var out=[]; l1:{ out.push(1); for(var i=0;i<5;i++){ if(i==2) break l1; if(i==1) continue; out.push('i'+i); } out.push('no'); }
l2: if(out.length){ let q=5; try{ out.push(q); break l2; } finally { out.push('fin') } out.push('no2') }
l3: for(var j=0;j<3;j++){ l4:{ if(j==1) break l4; if(j==2) break l3; out.push('j'+j); for(;;){ break } switch(j){case 0: break; } } out.push('t'+j) }
console.log(out.join());
function f1(){ let a=1; { let b=2; var h=()=>b; return arguments[0]+h()+a } } function f2(x){ if(x){ let y=x; return (()=>y+arguments[1])() } }
function f3(){ var f=()=>{ return arguments[0]+1 }; return f(9) } function f4(){ return function(){ return arguments.length }(1,2,3) }
console.log(f1(5),f2(1,2),f3(1),f4());
function* gen(){let e=0;{yield (()=>e)(); e=2} return e} console.log([...gen()].join());
var wo={},wm=new WeakMap([[wo,1]]),ws=new WeakSet; ws.add(wo); console.log(wm.get(wo),ws.has(wo),wm.has(ws));
var s1=async()=>{let e=!1;try{await Promise.resolve(1).then(()=>{e=!0})}catch(r){let t=`x${r}`;e=!1}return e}; s1().then(v=>console.log('await in a block',v));
try{throw Error("x")}catch(e){console.log(e instanceof Error, e.message, String(e))}
var t=TypeError("y"); console.log(t instanceof TypeError, t instanceof Error, t.message, RangeError("z").name, String(new RangeError("q")));
class MyErr extends Error{constructor(m){super(m);this.name="MyErr"}} var m=new MyErr("w"); console.log(m instanceof MyErr, m instanceof Error, m.message, String(m), m.constructor===MyErr);
try{null.x}catch(e){console.log(e instanceof TypeError, e.constructor===TypeError, e.name)}
try{undefinedThing}catch(e){console.log(e instanceof ReferenceError,e.name)}
var c=new Error("a",{cause:5}); console.log(c.cause, typeof Error.prototype.toString, TypeError.prototype.constructor===TypeError);
console.log(new Error().message === "", Error("").toString());
(()=>{ console.log(typeof hx); async function hx(){return 1} function hu(){} var he; console.log(typeof he, typeof hu) })();
(function(){ var r=[]; function z(){ return ge.a } async function x(){} let gy=2; var ge={a:7}; r.push(z(), typeof x, gy); console.log(r.join()) })();
var c=function(e,n){return function(){try{return e(1)}catch(e){throw e}}}; console.log(c(x=>x+1)()); function g(e){ try{ return e*2 }catch(e){ return -1 } } console.log(g(4)); var h=function(){ var e=5; try{ return e }catch(e){} }; console.log(h())
var r=[]; function kc(){ let a=1; try{ throw 2 }catch(e){ let b=e+a; r.push(()=>b+e) } return r[0]() } console.log(kc());
for(var i=0;i<3;i++){ try{ if(i==1) throw i; }catch(q){ continue } r.push('i'+i) } console.log(r.length);
function mc(){ try{ throw 'x' }catch(e){ return e+'!' }finally{ r.push('f') } } console.log(mc(), r.length);
try{ try{ throw 1 }catch(e){ throw e+1 } }catch(e){ console.log('outer',e) }
var fs=[]; for(let j=0;j<2;j++){ try{ throw j }catch(e){ fs.push(()=>e) } } console.log(fs[0](),fs[1]());
try{ throw {p:3} }catch({p}){ console.log(p) }
var a=Symbol('q'),b=Symbol('q'),o={};o[a]=1;o[b]=2;
console.log(typeof a, a!==b, o[a], o[b], String(a), Object(a) instanceof Symbol, Object(a).description, Symbol.for('x')===Symbol.for('x'), typeof Symbol.iterator);
console.log([...new Set([1,2])].length, Array.from(new Map([[1,2]])).length, String(Symbol.iterator), typeof String(Symbol()));
var it={[Symbol.iterator](){var i=0;return {next(){return {done:i>2,value:i++}}}}}; console.log([...it].join(), Array.from(it,x=>x*2).join(), Array.from({length:2,0:'a',1:'b'}).join(), Array.from('hé').length, Array.of(7,8).join());
var km="m",q={[km](x){return x+1},*[km+"g"](){yield 1;yield 2},async [km+"a"](){return 3},["p"]:4}; console.log(q.m(1),[...q.mg()].join(),q.p); q.ma().then(v=>console.log(v));
var t=Object.prototype.toString; console.log(t.call(function(){}), t.call([]), t.call(1), t.call("s"), t.call(true), t.call(new Date(0)), t.call(/a/), t.call({}), t.call(new Map), t.call(Symbol()), t.call(Promise.resolve()), t.call(new Error("x")), t.call(JSON), t.call(Math), String({}), t.call(new Set))
