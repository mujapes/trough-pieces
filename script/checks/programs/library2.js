var a=[5,1,4];a.splice(1,1,9,8);console.log(a.join());
console.log([3,1,2].sort().join(),[10,9,1].sort(function(x,y){return x-y}).join());
console.log((0.1).toFixed(20),(1.005).toFixed(2),(2.5).toFixed(0),(-1.5).toFixed(0),(123.456).toFixed(1),(0).toFixed(2),(1e-7).toFixed(3));
console.log(parseInt('0x1f'),parseInt('-12.9'),parseInt('z',36),parseFloat('-1.5e3x'),parseFloat('.5'),parseFloat('x'));
console.log((255).toString(2),(-255).toString(36),(0.5).toString(2));
console.log('a-b-c'.split('-').map(function(s){return s.toUpperCase()}).join('+'),'abc'.padStart(6,'xy'),'  x '.trim().length);
for(var k in {p:1,q:2})console.log(k);for(var j in [7,8])console.log(j);
console.log(Object.keys({a:1,b:2}).length,({}).hasOwnProperty('a'),[1,2] instanceof Array,typeof Math.max,Math.max(),Math.min(1,'0'),Math.round(-0.5),Math.round(2.5),Math.round(-2.5));
console.log(typeof __n,[1,[2,3]].concat(4,[5]).length,'héllo'.toUpperCase(),'abc'.charCodeAt(5),String.fromCharCode(72,105,8364));
try{[].reduce(function(a,b){return a})}catch(e){console.log(e.name,e instanceof TypeError)}
