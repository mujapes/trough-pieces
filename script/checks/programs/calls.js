function who(a,b){return this.n+':'+a+':'+b}
var o={n:'o'},p={n:'p'};
console.log(who.call(o,1,2),who.apply(p,[3,4]),who.call(o),who.apply(o),who.apply(o,[]));
var b=who.bind(p,'x');console.log(b('y'),b());
console.log(Math.max.apply(null,[3,9,2]),[].slice.call([1,2,3],1).join(),Array.prototype.map.call([1,2],function(x){return x*2}).join());
function sum(){var t=0;for(var i=0;i<arguments.length;i++)t+=arguments[i];return t}
console.log(sum.apply(null,[1,2,3,4,5,6,7,8,9,10]),sum.call(null));
var e=new Error('boom');console.log(''+e,'<'+e+'>',e+1,1+e,String(new TypeError('t')),`t:${e}`);
var q={toString:function(){return 'Q'}};console.log(q+q,q+1,'a'+q,[q,q].length,String(q));
console.log({}+'',''+{},({}).toString(),{}+1);
class V{constructor(x){this.x=x}toString(){return 'V('+this.x+')'}}
console.log('v='+new V(3),new V(1)+new V(2));
var s='';s+=q;s+=new V(7);console.log(s);
try{(1).call()}catch(x){console.log(x.name)}
try{null.f()}catch(x){console.log((''+x).slice(0,10))}
console.log(typeof who.call,typeof who.bind,who instanceof Function,(function(){return this+1}).call(5));
