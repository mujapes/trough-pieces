var a=Array(3);console.log(a.length,0 in a,a[0],JSON.stringify(a),a.join("-"));
var b=[1,,3];console.log(1 in b,b.length,Object.keys(b).join(),[...b].length);
var c=[1,2,3];delete c[1];console.log(1 in c,c.length,c[1]);
var n=0;b.forEach(function(){n++});console.log(n,b.map(function(x){return x*2}).join(),b.filter(function(){return true}).length);
for(var k in b)console.log("k",k);for(var v of b)console.log("v",v);
console.log(Array(3).concat("x").map(function(s){return s.length}).length, b.reduce(function(s,x){return s+x}), b.some(function(x){return x===undefined}), b.every(function(x){return x!==undefined}));
var d=[];d[3]=1;console.log(0 in d,d.length);var e=[1];e.length=4;console.log(3 in e,String(e));var f=Array.prototype.map.call("ab",function(x){return x+x});console.log(f.join());
var [p,q,r]=b;console.log(p,q,r);console.log(Math.max.apply(null,[1,,2]));
