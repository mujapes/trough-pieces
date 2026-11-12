var m=new Map([[1,'a'],['1','b']]);var o={},f=function(){};
m.set(o,'obj').set(f,'fn').set(NaN,'nan').set(-0,'zero').set(null,'nul').set(undefined,'und').set(true,'t');
console.log(m.size,m.get(1),m.get('1'),m.get(o),m.get({}),m.get(f),m.get(NaN),m.get(0),m.get(null),m.get(undefined),m.get(true),m.has('true'));
console.log(m.delete(o),m.delete(o),m.size);
for(var e of m)console.log(typeof e[0],typeof e[0]==='function'?'f':String(e[0]),e[1]);
for(const [k,v] of m.entries())console.log(k===f?'f':k,v);
console.log([...m.keys()].length,[...m.values()].join(','));
var s=new Set([3,1,3,2,1]);s.add('x').add(3);console.log(s.size,[...s].join(' '),s.has(2),s.has(4));s.delete(1);
for(let x of s)console.log(x);
s.forEach(function(a,b,c){console.log(a,b,c===s)});m.forEach(function(v,k){console.log('fe',typeof k,v)});
var it={};it[Symbol.iterator]=function(){var i=0;return{next:function(){return i<3?{value:i++*10,done:false}:{value:undefined,done:true}}}};
for(var q of it)console.log('it',q);console.log([...it].join('+'),Array.isArray([...new Set('hello')]),[...new Set('hello')].join(''));
var a=['p','q'];for(var [i,v] of a.entries())console.log(i,v);var ai=a[Symbol.iterator]();console.log(ai.next().value,ai.next().value,ai.next().done);
var [h1,h2]=new Set([7,8]);console.log(h1,h2);
try{for(var z of 5){}}catch(e){console.log(e instanceof TypeError)}
try{for(var z of {}){}}catch(e){console.log(e instanceof TypeError)}
var big=new Map();for(var i=0;i<2000;i++)big.set('k'+i,i);for(i=0;i<2000;i+=2)big.delete('k'+i);var t=0;big.forEach(function(v){t+=v});console.log(big.size,t,big.get('k1999'),big.get('k1998'));
s.clear();m.clear();console.log(s.size,m.size,m.get(1),new Map().size,new Set().has(undefined));
