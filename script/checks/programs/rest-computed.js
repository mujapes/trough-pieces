var k='b', s=Symbol('s');
var {[k]:x, a, ...r} = {a:1,b:2,c:3,[s]:4}; console.log(x, a, JSON.stringify(r));
var f=(e,_)=>{let{[_]:r,...n}=e;return n}; console.log(JSON.stringify(f({sources:1,alt:2,w:3},"sources")));
var {[s]:q, ...t} = {[s]:5, z:6}; console.log(q, JSON.stringify(t));
function g({a:{[k]:i, ...j}, ...m}){return i+JSON.stringify(j)+JSON.stringify(m)} console.log(g({a:{b:7,c:8},d:9}));
var k=2;var {[k]:two, ...u} = {2:"x", 3:"y"}; console.log(two)
